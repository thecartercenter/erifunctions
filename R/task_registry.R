#### Task registry (docs site & guidance system redesign, phase 3) ####

# Read the bundled task registry: a tree of common DA/Epi tasks grouped by
# intent, each leaf naming a representative call, the guide that walks it end
# to end (if any), and the reference functions it touches. Shared source for
# the generated task-index article, and future guidance tooling (eri_guide()).
#' @keywords internal
.eri_task_map <- function() {
  path <- system.file("registry/task_map.yaml", package = "erifunctions")
  if (!nzchar(path)) {
    cli::cli_abort("Bundled task registry not found (registry/task_map.yaml).")
  }
  yaml::read_yaml(path)
}

# Flatten the task tree into one row per leaf task, carrying the branch title
# along for grouping. Branch nodes (those with `children`) are never rows
# themselves -- only leaves are runnable tasks.
#' @keywords internal
.eri_task_flatten <- function(tree = .eri_task_map()) {
  rows <- lapply(tree, function(branch) {
    do.call(rbind, lapply(branch$children, function(leaf) {
      data.frame(
        branch    = branch$title,
        id        = leaf$id,
        title     = leaf$title,
        role      = leaf$role,
        call      = leaf$call,
        guide     = if (is.null(leaf$guide)) NA_character_ else leaf$guide,
        reference = I(list(leaf$reference)),
        next_ids  = I(list(leaf[["next"]])),
        epilogue_after = if (is.null(leaf$epilogue_after)) NA_character_ else leaf$epilogue_after,
        stringsAsFactors = FALSE
      )
    }))
  })
  do.call(rbind, rows)
}

# Prints a one-line "what's next" hint sourced from the registry's own `next:` field, for the
# handful of tasks where a single call is the unambiguous completion point (a leaf's
# `epilogue_after:`, R/guide.R's phase-5 zero-arg check has no bearing here -- this fires
# regardless of a task's argument shape, since the CALLER already ran it successfully).
# Gated at "full" verbosity like any other narration (.eri_say_info(), R/console.R) and never
# lets a lookup problem surface as an error -- this is pure narration, not part of the actual
# operation that just succeeded.
#' @keywords internal
.eri_task_epilogue <- function(fn_name) {
  tryCatch({
    flat <- .eri_task_flatten()
    hit  <- flat[!is.na(flat$epilogue_after) & flat$epilogue_after == fn_name, , drop = FALSE]
    if (nrow(hit) == 0L) return(invisible(NULL))

    # [[1]] assumes exactly one match -- enforced by test-task-map.R's "no two leaves hook the
    # same epilogue_after" check, since a second match's next_ids would otherwise be silently
    # ignored rather than merged or erred.
    next_ids <- hit$next_ids[[1]]
    for (nid in next_ids) {
      nxt <- flat[flat$id == nid, , drop = FALSE]
      if (nrow(nxt) == 0L) next
      .eri_say_info("Next: {.strong {nxt$title[[1]]}} -- {.code {nxt$call[[1]]}}")
    }
    invisible(NULL)
  }, error = function(e) invisible(NULL))
}

# Finds the branch with the given id anywhere in the tree, or NULL if `id` is NULL/unmatched.
# Used by eri_guide()'s session-memory resume lookup (R/guide.R, phase 7).
#' @keywords internal
.eri_task_find_branch <- function(id, tree = .eri_task_map()) {
  Find(function(b) identical(b$id, id), tree)
}

# Finds the leaf with the given id anywhere in the tree, or NULL if `id` is NULL/unmatched. Used by
# eri_guide(task_id = )'s deep-link path (R/guide.R, phase 7).
#' @keywords internal
.eri_task_find_leaf <- function(id, tree = .eri_task_map()) {
  for (branch in tree) {
    hit <- Find(function(l) identical(l$id, id), branch$children)
    if (!is.null(hit)) return(hit)
  }
  NULL
}

#' Show the task registry: what are you trying to do?
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Prints (and returns invisibly) the task registry: a tree of common DA/Epi
#' tasks grouped by intent, each naming a representative call, the guide that
#' walks it end to end (if any), and the reference functions it touches. This
#' is the shared source the generated [task index
#' article](../articles/task-index.html) reads from
#' (`inst/registry/task_map.yaml`).
#'
#' @returns Invisibly, a data frame with one row per task: `branch`, `id`,
#'   `title`, `role`, `call`, `guide`, `reference` (list-column), `next_ids`
#'   (list-column).
#' @examples
#' eri_task_map()
#' @export
eri_task_map <- function() {
  tree <- .eri_task_map()

  cli::cli_h1("Task registry: what are you trying to do?")
  for (branch in tree) {
    cli::cli_h2(branch$title)
    for (leaf in branch$children) {
      bullet <- if (is.null(leaf$guide)) {
        "{.strong {leaf$title}} -- {.code {leaf$call}}"
      } else {
        "{.strong {leaf$title}} -- {.code {leaf$call}} (guide: {.val {leaf$guide}})"
      }
      cli::cli_bullets(c("*" = bullet))
    }
  }

  invisible(.eri_task_flatten(tree))
}
