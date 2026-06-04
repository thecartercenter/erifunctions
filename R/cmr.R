# CMR - Monthly Report ingestion

#' Read and parse a CMR monthly report Excel file
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Reads a single sheet from a Carter Center RBLF monthly report template,
#' using the machine-readable field code row (row 5 of the template) as column
#' names. Field codes (e.g. `#rbtrt_year`, `#rbtrt_adm1`) are consistent across
#' all country templates regardless of language, so the same function parses
#' both English and French templates.
#'
#' ## Template structure assumed
#' | Row | Content |
#' |-----|---------|
#' | 1 | Sheet title |
#' | 2 | Empty spacer |
#' | 3 | Group headers (Location / Targets / Month columns) |
#' | 4 | Human-readable column names |
#' | 5 | Machine-readable field codes — **parsing anchor** |
#' | 6+ | Data |
#'
#' @param path `str` Local path to the CMR Excel file.
#' @param sheet `str` or `int` Sheet name or 1-based index to read.
#' @param country `str` or `NULL` Optional country code (e.g. `"ug"`, `"et"`)
#'   added as the first column. Default `NULL`.
#'
#' @returns A tibble with field-code column names and data from row 6 onward.
#'   All-NA spacer rows are dropped. If `country` is supplied it is prepended
#'   as a `country` column.
#' @examples
#' \dontrun{
#' df <- eri_ingest_cmr("data/uga_2024_01.xlsx", sheet = "RB Treatment", country = "ug")
#' }
#' @export
eri_ingest_cmr <- function(path, sheet, country = NULL) {
  if (!file.exists(path)) {
    cli::cli_abort("File not found: {.path {path}}")
  }

  raw <- readxl::read_excel(path, sheet = sheet, skip = 4,
                             col_names = TRUE, .name_repair = "minimal")

  field_cols <- names(raw)[startsWith(names(raw), "#")]

  if (length(field_cols) == 0) {
    cli::cli_abort(c(
      "No field code columns found in sheet {.val {sheet}} of {.path {basename(path)}}.",
      "i" = "Row 5 of the template should contain machine-readable codes starting with {.code #} (e.g. {.code #rbtrt_year}).",
      "i" = "Check that {.arg sheet} is correct and the template has not been modified."
    ))
  }

  df <- raw[, field_cols, drop = FALSE]

  all_na <- apply(df, 1, function(r) all(is.na(r)))
  df <- tibble::as_tibble(df[!all_na, , drop = FALSE])

  if (!is.null(country)) {
    df <- tibble::add_column(df, country = country, .before = 1)
  }

  cli::cli_alert_success(
    "CMR sheet {.val {sheet}}: {nrow(df)} data row{?s}, {length(field_cols)} field code{?s}."
  )

  df
}
