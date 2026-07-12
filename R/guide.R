#### eri_guide — an interactive console wizard over the task registry ####
#
# Phase 5 of the docs site & guidance system redesign (docs/roadmap.md's "Docs site & guidance
# system redesign" entry). Walks inst/registry/task_map.yaml the same way eri_dq_review() walks
# the DQ core: cli_h3() + utils::menu() menus (.eri_prompt_menu(), R/dq_review.R), nothing
# persisted, safe to exit and rerun anytime.
#
# The "run guardrail" is mechanical, not a schema field: a task's call is only offered as "Run it
# now" when it parses to a zero-argument call -- the same call string test-task-map.R already
# verifies parses as R. Everything else needs real argument values this wizard has no safe way to
# fabricate, so it can only be shown, with its guide opened for the full walkthrough. Deeper
# argument collection (preflight checks, session memory) is Phase 7 ("wizard depth"), deliberately
# out of scope here.

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
#' Prefer the generated [task-index article](../articles/task-index.html) or [eri_task_map()] when
#' you don't need the back-and-forth of a menu.
#'
#' **Interactive only.** In a script, browse [eri_task_map()] or the task-index article instead.
#'
#' @returns Invisibly, `NULL`. "Run it now" prints its visibly-returned result the same way typing
#'   the call at the console would (so e.g. [get_azure_storage_connection()]'s connection object is
#'   shown, not silently discarded), and a failure is caught and reported rather than crashing the
#'   wizard -- but the result itself is not kept for later use; assign it yourself if you need it
#'   again (`con <- get_azure_storage_connection()`).
#' @examples
#' \dontrun{
#' eri_guide()
#' }
#' @seealso [eri_task_map()] for the non-interactive console version, [eri_dq_review()] for the
#'   same menu-driven wizard pattern applied to DQ triage.
#' @export
eri_guide <- function() {
  if (!rlang::is_interactive()) {
    cli::cli_abort(c(
      "{.fn eri_guide} is interactive-only.",
      "i" = "See the generated task-index article, or call {.fn eri_task_map} for the console version."
    ))
  }

  tree <- .eri_task_map()

  repeat {
    branch_titles <- vapply(tree, function(b) b$title, character(1))
    branch_choice <- .eri_prompt_menu("What are you trying to do?", c(branch_titles, "Exit"))
    if (branch_choice == 0L || branch_choice == length(tree) + 1L) break
    branch <- tree[[branch_choice]]

    repeat {
      leaf_titles <- vapply(branch$children, function(l) l$title, character(1))
      leaf_choice <- .eri_prompt_menu(branch$title, c(leaf_titles, "Back"))
      if (leaf_choice == 0L || leaf_choice == length(branch$children) + 1L) break
      .eri_guide_show_task(branch$children[[leaf_choice]])
    }
  }

  invisible(NULL)
}
