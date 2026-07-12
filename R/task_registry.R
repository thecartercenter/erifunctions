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
        stringsAsFactors = FALSE
      )
    }))
  })
  do.call(rbind, rows)
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
