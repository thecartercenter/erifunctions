#### dq_export.R — hand off a DQ flag report as a self-contained file ####

#' Export a DQ flag report to HTML or markdown
#'
#' Renders a DQ flags tibble -- either the raw `flags` from [run_dq_checks()]
#' (`column`/`value`/`issue`, one dataset) or the richer per-CMR-measure
#' tibble from [eri_cmr_dq_report()] (adds `sheet`, `excel_row`, `status`,
#' `note`) -- to a self-contained file. This is the artifact a DA hands back
#' to a data source or pastes into an email/Teams thread once DQ checks have
#' been reviewed, replacing ad hoc [eri_table()] calls with one consistent
#' format. Deliberately hand-rolled rather than routed through
#' [eri_report_html()] (which hard-requires a working Quarto install): see
#' `R/reports_lite.R` for the shared page shell/CSS this shares with
#' [eri_feedback_report()].
#'
#' @param flags `tibble` A flags tibble -- must have `column`, `value`,
#'   `issue` columns at minimum. `sheet` groups rows into sections (omitted if
#'   absent -- everything renders as one table); `excel_row`/`row` labels the
#'   row (whichever is present, `excel_row` preferred); `status` and `note`
#'   are shown when present.
#' @param file `chr` or `NULL` Output path. If `NULL`, writes
#'   `dq-report-<country>-<period>-<date>.<ext>` (falling back to just the
#'   date if `country`/`period` are `NULL`) in the working directory.
#' @param format `chr` `"html"` (default, self-contained, prints cleanly to
#'   PDF from a browser) or `"md"` (GitHub-flavoured markdown).
#' @param country `str` or `NULL` Country code, used only to label the report
#'   and default the output filename.
#' @param period `str` or `NULL` Reporting period, used only to label the
#'   report and default the output filename.
#' @returns The output file path (invisibly).
#' @examples
#' \dontrun{
#' schema <- load_dq_schema("dr", "malaria", "surveillance", "aggregate")
#' res    <- run_dq_checks(extract, schema)
#' eri_dq_export(res$flags, country = "dr")
#'
#' flags <- eri_cmr_dq_report("sdn", "202605")
#' eri_dq_export(flags, country = "sdn", period = "202605")
#' }
#' @seealso [eri_cmr_dq_report()] / [run_dq_checks()] to generate `flags`,
#'   [eri_dq_review()] for the interactive triage wrapper that calls this to
#'   print its report.
#' @export
eri_dq_export <- function(flags, file = NULL, format = c("html", "md"),
                          country = NULL, period = NULL) {
  format <- match.arg(format)
  if (!is.data.frame(flags)) cli::cli_abort("{.arg flags} must be a data frame (as returned by {.fn eri_cmr_dq_report} or {.fn run_dq_checks}).")
  required <- c("column", "value", "issue")
  missing_cols <- setdiff(required, names(flags))
  if (length(missing_cols) > 0L) {
    cli::cli_abort("{.arg flags} is missing column{?s} {.field {missing_cols}}.")
  }

  ext <- if (format == "html") "html" else "md"
  if (is.null(file)) {
    label <- paste(c(country, period), collapse = "-")
    stem  <- if (nzchar(label)) paste0("dq-report-", label, "-", format(Sys.Date()))
             else paste0("dq-report-", format(Sys.Date()))
    file  <- file.path(getwd(), paste0(stem, ".", ext))
  }

  content <- if (format == "html") {
    .eri_dq_export_render_html(flags, country, period)
  } else {
    .eri_dq_export_render_md(flags, country, period)
  }
  writeLines(content, file, useBytes = TRUE)

  n_open <- .eri_dq_export_n_open(flags)
  cli::cli_alert_success(
    "DQ report ({nrow(flags)} flag{?s} · {n_open} open) written to {.path {file}}."
  )
  invisible(file)
}

#' @keywords internal
.eri_dq_export_title <- function(country, period) {
  label <- paste(c(country, period), collapse = " · ")
  if (nzchar(label)) paste0("DQ flag report — ", label) else "DQ flag report"
}

#' @keywords internal
.eri_dq_export_n_open <- function(flags) {
  if (nrow(flags) == 0L) return(0L)
  if (!"status" %in% names(flags)) return(nrow(flags))
  sum(flags$status == "open")
}

# Picks the row-identity column to display: excel_row (the real Excel row,
# preferred when present) or row (the raw run_dq_checks() index), whichever
# the tibble actually has.
#' @keywords internal
.eri_dq_export_row_col <- function(flags) {
  if ("excel_row" %in% names(flags)) "excel_row"
  else if ("row" %in% names(flags)) "row"
  else NA_character_
}

# A missing required column (.dq_check_required() in R/dq.R) flags with
# row/value = NA -- render that as the same "--" placeholder every other NA
# (note, status) gets, not the literal string "NA".
#' @keywords internal
.eri_dq_export_html_cell <- function(x, esc) if (is.na(x)) "—" else esc(x)

# HTML renderer ----------------------------------------------------------------

#' @keywords internal
.eri_dq_export_render_html <- function(flags, country, period) {
  esc <- .eri_html_escape
  gen <- format(Sys.time(), "%Y-%m-%d %H:%M UTC", tz = "UTC")
  title <- .eri_dq_export_title(country, period)

  css <- paste0(
    .eri_org_html_css_base(),
    ".tag{font-size:.74rem;font-weight:700;border-radius:6px;padding:.1rem .4rem;",
    "background:#eef2f7;color:#41617f}",
    ".tag.open{background:#fdeeee;color:#b3261e}",
    ".tag.closed{background:#e7f5ec;color:#00873f}",
    "@media print{body{margin:0;max-width:none} h2{page-break-after:avoid}",
    "table{page-break-inside:auto} tr{page-break-inside:avoid}}"
  )

  n_total <- nrow(flags)
  n_open  <- .eri_dq_export_n_open(flags)
  meta <- paste0(
    "<p class='meta'>Generated ", gen, " · ", n_total, " flag", if (n_total == 1L) "" else "s",
    " · ", n_open, " open</p>"
  )

  if (n_total == 0L) {
    return(.eri_html_page(title, css, paste0(meta, "<p class='empty'>No flags — every measure is clean.</p>")))
  }

  row_col   <- .eri_dq_export_row_col(flags)
  has_row   <- !is.na(row_col)
  has_status <- "status" %in% names(flags)
  has_note   <- "note" %in% names(flags)
  headers <- c(if (has_row) "Row", "Column", "Value", "Issue", if (has_status) "Status", if (has_note) "Note")

  section_table <- function(fs) {
    rows <- vapply(seq_len(nrow(fs)), function(i) {
      cells <- c(
        if (has_row) .eri_html_td(.eri_dq_export_html_cell(fs[[row_col]][i], esc)),
        .eri_html_td(.eri_dq_export_html_cell(fs$column[i], esc)),
        .eri_html_td(.eri_dq_export_html_cell(fs$value[i], esc)),
        .eri_html_td(.eri_dq_export_html_cell(fs$issue[i], esc))
      )
      if (has_status) {
        status <- fs$status[i]
        status_cls <- if (identical(status, "open")) "tag open" else "tag closed"
        cells <- c(cells, .eri_html_td(paste0(
          "<span class='", status_cls, "'>", .eri_dq_export_html_cell(status, esc), "</span>"
        )))
      }
      if (has_note) {
        cells <- c(cells, .eri_html_td(.eri_dq_export_html_cell(fs$note[i], esc)))
      }
      .eri_html_row(cells)
    }, character(1L))
    paste0("<table>", .eri_html_th_row(headers), paste0(rows, collapse = ""), "</table>")
  }

  if ("sheet" %in% names(flags)) {
    sheets <- unique(flags$sheet)
    sections <- vapply(sheets, function(s) {
      fs <- flags[flags$sheet == s, , drop = FALSE]
      paste0("<h2>", esc(s), " (", nrow(fs), ")</h2>", section_table(fs))
    }, character(1L))
    body <- paste0(sections, collapse = "")
  } else {
    body <- section_table(flags)
  }

  .eri_html_page(title, css, paste0(meta, body))
}

# Markdown renderer ------------------------------------------------------------

#' @keywords internal
.eri_dq_export_render_md <- function(flags, country, period) {
  gen   <- format(Sys.time(), "%Y-%m-%d %H:%M UTC", tz = "UTC")
  title <- .eri_dq_export_title(country, period)

  cell <- function(x) {
    if (length(x) == 0L || is.na(x)) return("—")
    x <- as.character(x)
    x <- gsub("\\|", "\\\\|", x); x <- gsub("[\r\n]+", " ", x)
    if (!nzchar(x)) "—" else x
  }

  n_total <- nrow(flags)
  n_open  <- .eri_dq_export_n_open(flags)
  lines <- c(
    paste0("# ", title), "",
    paste0("Generated ", gen, " · ", n_total, " flag", if (n_total == 1L) "" else "s",
           " · ", n_open, " open"), ""
  )

  if (n_total == 0L) {
    return(paste(c(lines, "No flags — every measure is clean."), collapse = "\n"))
  }

  row_col    <- .eri_dq_export_row_col(flags)
  has_row    <- !is.na(row_col)
  has_status <- "status" %in% names(flags)
  has_note   <- "note" %in% names(flags)
  header_cells <- c(if (has_row) "Row", "Column", "Value", "Issue", if (has_status) "Status", if (has_note) "Note")

  section_rows <- function(fs) {
    out <- c(
      paste0("| ", paste(header_cells, collapse = " | "), " |"),
      paste0("| ", paste(rep("---", length(header_cells)), collapse = " | "), " |")
    )
    for (i in seq_len(nrow(fs))) {
      row_cells <- c(if (has_row) cell(fs[[row_col]][i]), cell(fs$column[i]), cell(fs$value[i]), cell(fs$issue[i]))
      if (has_status) row_cells <- c(row_cells, cell(fs$status[i]))
      if (has_note) row_cells <- c(row_cells, cell(fs$note[i]))
      out <- c(out, paste0("| ", paste(row_cells, collapse = " | "), " |"))
    }
    out
  }

  if ("sheet" %in% names(flags)) {
    for (s in unique(flags$sheet)) {
      fs <- flags[flags$sheet == s, , drop = FALSE]
      lines <- c(lines, paste0("## ", s, " (", nrow(fs), ")"), "", section_rows(fs), "")
    }
  } else {
    lines <- c(lines, section_rows(flags), "")
  }

  paste(lines, collapse = "\n")
}
