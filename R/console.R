#### Console output / verbosity ####
#
# erifunctions narrates what it is doing so that non-developer users (epidemiologists, data
# analysts) can follow along and trust that work is happening. Two levels:
#   "full"  (default) -- per-step confirmations, summaries, and progress on transfers.
#   "quiet"           -- drops the granular play-by-play; keeps headline results, warnings,
#                        errors, and live progress on genuinely long transfers.
#
# Resolution order: the `erifunctions.verbosity` option, then the `ERIFUNCTIONS_VERBOSITY`
# environment variable (handy for CI / non-interactive runs), then the "full" default.

.ERI_VERBOSITY_LEVELS <- c("full", "quiet")

#' Resolve the current console verbosity level.
#' @keywords internal
.eri_verbosity <- function() {
  lvl <- getOption("erifunctions.verbosity", default = NULL)
  if (is.null(lvl)) {
    env <- Sys.getenv("ERIFUNCTIONS_VERBOSITY", unset = "")
    lvl <- if (nzchar(env)) env else "full"
  }
  lvl <- tolower(as.character(lvl)[[1L]])
  if (lvl %in% .ERI_VERBOSITY_LEVELS) lvl else "full"
}

#' Is console output chatty (i.e. not "quiet")?
#' @keywords internal
.eri_chatty <- function() !identical(.eri_verbosity(), "quiet")

#' Control how much erifunctions prints to the console
#'
#' By default erifunctions narrates each step it takes -- confirmations, summaries, and progress
#' bars -- so you can see what it is doing. If you prefer a terser console, switch to `"quiet"`:
#' headline results, warnings, and errors are still shown, but the step-by-step chatter is hidden.
#'
#' Set it for a whole project by adding `options(erifunctions.verbosity = "quiet")` to the
#' project's `.Rprofile`, or for one session by calling this function. The `ERIFUNCTIONS_VERBOSITY`
#' environment variable is also honoured (useful in CI).
#'
#' @param level `chr` Either `"full"` (default; chatty) or `"quiet"` (terse). Omit to read the
#'   current level instead of setting it.
#' @returns The verbosity level, invisibly when setting.
#' @examples
#' eri_verbosity()          # read the current level
#' \dontrun{
#' eri_verbosity("quiet")   # terser console for the rest of the session
#' eri_verbosity("full")    # back to the chatty default
#' }
#' @export
eri_verbosity <- function(level) {
  if (missing(level)) return(.eri_verbosity())
  level <- match.arg(tolower(level), .ERI_VERBOSITY_LEVELS)
  options(erifunctions.verbosity = level)
  cli::cli_alert_info("erifunctions console verbosity set to {.val {level}}.")
  invisible(level)
}

# --- Verbosity-gated cli wrappers -------------------------------------------------
# These emit only at "full" verbosity. Interpolation happens in the caller's frame (.envir), so
# call sites can write `.eri_say_done("Uploaded {n} file{?s}")` exactly like cli::cli_alert_*.
# Use plain cli::cli_* (not these) for headline results, warnings, and errors that must always show.

#' Emit a success confirmation, only at "full" verbosity.
#' @keywords internal
.eri_say_done <- function(..., .envir = parent.frame()) {
  if (.eri_chatty()) cli::cli_alert_success(..., .envir = .envir)
  invisible(NULL)
}

#' Emit an informational line, only at "full" verbosity.
#' @keywords internal
.eri_say_info <- function(..., .envir = parent.frame()) {
  if (.eri_chatty()) cli::cli_alert_info(..., .envir = .envir)
  invisible(NULL)
}

#' Render a titled key/value summary block -- the satisfying end-cap of a multi-step operation.
#'
#' Always shown (it is the result, not chatter), at both verbosity levels. `title` is glue-style
#' (interpolated in `.envir`); `items` is a named character vector of already-formatted values
#' (`names` become the left-hand labels). A green tick is prepended to the title.
#' @keywords internal
.eri_summary <- function(title, items, .envir = parent.frame()) {
  cli::cli_rule(left = paste0("{cli::col_green(cli::symbol$tick)} ", title), .envir = .envir)
  cli::cli_dl(items, .envir = .envir)
  invisible(NULL)
}
