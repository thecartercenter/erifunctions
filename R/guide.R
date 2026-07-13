#### eri_guide — deprecated, narrowed to a static lookup (Phase C.3 of the interactive-wizard course correction) ####
#
# eri_guide() used to be a menu-driven console wizard over inst/registry/task_map.yaml (Phase 5+7 of
# the docs-site redesign). The interactive-wizard consult (docs/design/interactive-wizard-consult.md
# section 2/3.9) assessed it against eri_do(): it could only ever RUN 4 of ~32 tasks (the
# zero-argument ones); everything else it could just *describe*, which the vignettes already do.
# Once eri_do() exists as the executor, a menu-driven front door that mostly can't act is worse than
# either (a) the executor, for the tasks it covers, or (b) a plain lookup, for browsing. The consult
# offered two options: delete outright, or narrow to a non-menu `eri_guide(task_id)` lookup. This
# takes the narrower path rather than deleting the exported name outright -- eri_guide() is a real,
# already-shipped tool DAs may have muscle memory or scripts referencing; removing the export
# entirely mid-transition would turn a design decision into a breaking surprise. `.Deprecated()`
# points every caller at eri_do() (to act) or eri_task_map() (to browse) and the function keeps doing
# something useful -- lookup, not a dead end.
#
# Deleted with the menu wizard: `.eri_guide_zero_arg()` (the "is this safe to run" test),
# `.eri_guide_show_task()` (the menu-driven task detail screen with "run it now"),
# `.eri_guide_last_branch_id()`/`.eri_guide_set_last_branch_id()` (session memory of the last-browsed
# category), `.eri_guide_resolve_branch_choice()` (menu index arithmetic). None of these have a
# purpose once there's no menu to drive.

#' Look up a task's call and guide (deprecated; use [eri_do()] or [eri_task_map()])
#'
#' @description
#' `r lifecycle::badge("deprecated")`
#'
#' `eri_guide()` used to be a menu-driven console wizard. It's deprecated in favor of two sharper
#' tools: [eri_do()], which actually *runs* the CMR/ingest/ODK/onboarding pipelines through a guided
#' console flow, and [eri_task_map()] (or the generated task-index article), which browses every
#' task's representative call, guide, and reference functions as a static list. `eri_guide()` never
#' had "run it now" for more than 4 of ~32 tasks -- for anything else it could only describe, which is
#' what the vignettes and [eri_task_map()] already do, without a menu to navigate.
#'
#' This function is kept, narrowed, rather than removed outright: pass a `task_id` and it still shows
#' that task's call, guide, and reference functions (no menu); called with no argument, it prints the
#' full [eri_task_map()] listing instead of opening an interactive browser.
#'
#' @param task_id `chr` or `NULL` A task id to show (see [eri_task_map()]'s `id` column, or the
#'   generated task-index article, for valid ids). `NULL` (default) prints the full task list instead.
#' @returns Invisibly, `NULL`.
#' @examples
#' \dontrun{
#' eri_guide("check_cmr")  # show one task's call/guide/reference, no menu
#' eri_guide()             # equivalent to eri_task_map()
#' }
#' @seealso [eri_do()] for the guided pipeline wizard that replaced this, [eri_task_map()] for the
#'   full static listing.
#' @export
eri_guide <- function(task_id = NULL) {
  .Deprecated("eri_do", package = "erifunctions",
              msg = paste(
                "eri_guide() is deprecated. Use eri_do() to run a pipeline through a guided console",
                "flow, or eri_task_map() to browse every task's call/guide/reference."
              ))

  if (is.null(task_id)) {
    eri_task_map()
    return(invisible(NULL))
  }

  leaf <- .eri_task_find_leaf(task_id, .eri_task_map())
  if (is.null(leaf)) {
    cli::cli_abort(c(
      "No task with id {.val {task_id}} in the registry.",
      "i" = "Call {.fn eri_task_map} to see valid ids."
    ))
  }

  cli::cli_h2(leaf$title)
  cli::cli_bullets(c("*" = "Run: {.code {leaf$call}}"))
  if (!is.null(leaf$guide)) {
    cli::cli_bullets(c("*" = "Guide: {.val {leaf$guide}}"))
  }
  if (length(leaf$reference) > 0L) {
    cli::cli_bullets(c("*" = "Reference: {.fn {leaf$reference}}"))
  }

  invisible(NULL)
}
