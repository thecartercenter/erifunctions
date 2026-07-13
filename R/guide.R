#### eri_guide — an interactive console wizard over the task registry ####
#
# Phase 5 (MVP) + phase 7 (wizard depth) of the docs site & guidance system redesign
# (docs/roadmap.md's "Docs site & guidance system redesign" entry). Walks
# inst/registry/task_map.yaml the same way eri_dq_review() walks the DQ core: cli_h3() +
# utils::menu() menus (.eri_prompt_menu(), R/dq_review.R), nothing persisted to disk, safe to exit
# and rerun anytime.
#
# The "run guardrail" is mechanical, not a schema field: a task's call is only offered as "Run it
# now" when it parses to a zero-argument call -- the same call string test-task-map.R already
# verifies parses as R. Everything else needs real argument values this wizard has no safe way to
# fabricate, so it can only be shown, with its guide opened for the full walkthrough. Real
# per-function argument collection (so more tasks could be run from the wizard) stays out of
# scope -- most leaves' calls mix simple strings with real R objects (a data frame, an sf
# shapefile) a console prompt can't safely fabricate, and guessing which is which per function
# risks silently passing the wrong thing. "Run it now"'s existing tryCatch-and-report (below) is
# the guardrail against a live call failing; a more elaborate preflight (checking specific env
# vars/state per task) would need new schema fields for uncertain benefit over that.
#
# Phase 7 additions: session memory (.eri_guide_last_branch_id()/.eri_guide_set_last_branch_id(),
# an options()-based session-state convention matching R/console.R's verbosity, not a new
# package-env pattern) offers to resume the last-visited category; a task id deep link
# (eri_guide(task_id = )) jumps straight to one task's detail screen via .eri_task_find_leaf()
# (R/task_registry.R).

# TRUE only for a call with no arguments at all, e.g. "eri_data_model()" -- not "eri_query(sql)"
# even though `sql` has no default here, since the registry's own call templates never encode
# defaults, only the shape of a representative invocation.
#' @keywords internal
.eri_guide_zero_arg <- function(call) {
  length(as.list(str2lang(call))) == 1L
}

# One task's detail screen: what it does, its call, its guide, its reference functions, and (only
# when safe) the option to run it or open the guide right now.
#' @keywords internal
.eri_guide_show_task <- function(leaf) {
  cli::cli_h2(leaf$title)
  cli::cli_bullets(c("*" = "Run: {.code {leaf$call}}"))
  if (!is.null(leaf$guide)) {
    cli::cli_bullets(c("*" = "Guide: {.val {leaf$guide}}"))
  }
  if (length(leaf$reference) > 0L) {
    cli::cli_bullets(c("*" = "Reference: {.fn {leaf$reference}}"))
  }

  options <- character(0)
  if (.eri_guide_zero_arg(leaf$call)) options <- c(options, "Run it now")
  if (!is.null(leaf$guide)) options <- c(options, "Open the guide")
  options <- c(options, "Back")

  repeat {
    choice <- .eri_prompt_menu("What next?", options)
    picked <- if (choice == 0L) "Back" else options[[choice]]

    if (picked == "Run it now") {
      tryCatch(
        {
          # withVisible() so a visibly-returned result (e.g. get_azure_storage_connection()'s
          # container) prints here exactly as it would at the console top level, while a call
          # that already prints its own output via cli:: (eri_data_model()) or returns
          # invisibly doesn't print twice.
          result <- withVisible(eval(str2lang(leaf$call)))
          if (isTRUE(result$visible)) print(result$value)
        },
        error = function(e) cli::cli_alert_warning("That call failed: {conditionMessage(e)}")
      )
    } else if (picked == "Open the guide") {
      tryCatch(
        print(utils::vignette(leaf$guide, package = "erifunctions")),
        error = function(e) cli::cli_alert_warning("Could not open the guide: {conditionMessage(e)}")
      )
    } else {
      break
    }
  }
  invisible(NULL)
}

# Session memory of which category the wizard last visited, so re-invoking eri_guide() can offer
# to resume there instead of always starting from the top. Uses the same getOption()/options()
# session-state convention as R/console.R's verbosity (not a new package-env pattern) -- resets
# with a fresh R session, the right lifetime for "where was I browsing," nothing worth persisting
# to disk.
#' @keywords internal
.eri_guide_last_branch_id <- function() getOption("erifunctions.guide_last_branch", default = NULL)

#' @keywords internal
.eri_guide_set_last_branch_id <- function(id) options(erifunctions.guide_last_branch = id)

# Resolves a top-level category-menu choice to NULL (exit) or the chosen branch, accounting for
# whether a "Continue in ..." resume option was prepended (which shifts every other index by one).
# Isolated as its own pure function so the index arithmetic is unit-testable independent of the
# interactive loop -- exactly the kind of off-by-one that's easy to get wrong inline.
#' @keywords internal
.eri_guide_resolve_branch_choice <- function(choice, tree, resume_branch) {
  offset <- if (!is.null(resume_branch)) 1L else 0L
  if (choice == 0L || choice == length(tree) + offset + 1L) return(NULL)
  if (!is.null(resume_branch) && choice == 1L) return(resume_branch)
  tree[[choice - offset]]
}

#' Find your task and get its call and guide (interactive)
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' A console wizard over the task registry ([eri_task_map()]'s bundled
#' `inst/registry/task_map.yaml`): pick a category, pick a task, see its representative call, its
#' guide (if any), and the reference functions it touches. A zero-argument task (e.g.
#' [eri_data_model()], [get_azure_storage_connection()]) can be run right from the menu;
#' everything else -- which needs real argument values this wizard has no safe way to fabricate --
#' can only be shown, with its guide opened for the full walkthrough.
#'
#' The wizard remembers the last category you visited this session and offers to resume there.
#' Pass a task id to jump straight to its detail screen instead of navigating the menus (see
#' [eri_task_map()]'s `id` column, or the generated task-index article, for valid ids).
#'
#' Prefer the generated [task-index article](../articles/task-index.html) or [eri_task_map()] when
#' you don't need the back-and-forth of a menu.
#'
#' **Interactive only.** In a script, browse [eri_task_map()] or the task-index article instead.
#'
#' @param task_id `chr` or `NULL` A task id to jump straight to its detail screen, skipping the
#'   category/task menus. `NULL` (default) starts at the top-level category menu.
#' @returns Invisibly, `NULL`. "Run it now" prints its visibly-returned result the same way typing
#'   the call at the console would (so e.g. [get_azure_storage_connection()]'s connection object is
#'   shown, not silently discarded), and a failure is caught and reported rather than crashing the
#'   wizard -- but the result itself is not kept for later use; assign it yourself if you need it
#'   again (`con <- get_azure_storage_connection()`).
#' @examples
#' \dontrun{
#' eri_guide()
#' eri_guide("check_cmr")  # jump straight to a known task
#' }
#' @seealso [eri_task_map()] for the non-interactive console version, [eri_dq_review()] for the
#'   same menu-driven wizard pattern applied to DQ triage.
#' @export
eri_guide <- function(task_id = NULL) {
  if (!rlang::is_interactive()) {
    cli::cli_abort(c(
      "{.fn eri_guide} is interactive-only.",
      "i" = "See the generated task-index article, or call {.fn eri_task_map} for the console version."
    ))
  }

  tree <- .eri_task_map()

  if (!is.null(task_id)) {
    leaf <- .eri_task_find_leaf(task_id, tree)
    if (is.null(leaf)) {
      cli::cli_abort(c(
        "No task with id {.val {task_id}} in the registry.",
        "i" = "Call {.fn eri_task_map} to see valid ids, or {.fn eri_guide} with no argument to browse."
      ))
    }
    .eri_guide_show_task(leaf)
    return(invisible(NULL))
  }

  repeat {
    resume_branch <- .eri_task_find_branch(.eri_guide_last_branch_id(), tree)
    branch_titles <- vapply(tree, function(b) b$title, character(1))
    menu_choices  <- if (!is.null(resume_branch)) {
      c(sprintf('Continue in "%s"', resume_branch$title), branch_titles, "Exit")
    } else {
      c(branch_titles, "Exit")
    }

    branch_choice <- .eri_prompt_menu("What are you trying to do?", menu_choices)
    branch <- .eri_guide_resolve_branch_choice(branch_choice, tree, resume_branch)
    if (is.null(branch)) break

    .eri_guide_set_last_branch_id(branch$id)

    repeat {
      leaf_titles <- vapply(branch$children, function(l) l$title, character(1))
      leaf_choice <- .eri_prompt_menu(branch$title, c(leaf_titles, "Back"))
      if (leaf_choice == 0L || leaf_choice == length(branch$children) + 1L) break
      .eri_guide_show_task(branch$children[[leaf_choice]])
    }
  }

  invisible(NULL)
}
