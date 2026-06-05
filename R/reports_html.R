#' Render an ERI-branded self-contained HTML report
#'
#' Renders a Quarto template to a single portable `.html` file. No external
#' files are produced — the output is self-contained and can be emailed or
#' shared directly.
#'
#' The report is structured as a series of sections, each optionally containing
#' a heading, free text, a formatted table (via [eri_table()]), and/or a
#' ggplot figure.
#'
#' Requires the `quarto` package and a working Quarto installation
#' (<https://quarto.org>).
#'
#' @param sections Named list of section definitions. Each element must be a
#'   named list with any of:
#'   - `heading` — character; section heading
#'   - `text` — character; narrative paragraph (markdown allowed)
#'   - `table` — data frame to render via [eri_table()]
#'   - `figure` — a `ggplot` object
#'   - `figure_width`, `figure_height` — numeric inches (defaults: 8, 5)
#' @param path Character; output file path (should end in `.html`).
#' @param title Character; report title displayed in the header.
#' @param subtitle Optional character; subtitle displayed below the title.
#' @param author Optional character; displayed in the report header.
#' @param date Optional character; defaults to today's date.
#'
#' @return `path` invisibly.
#' @export
#'
#' @examples
#' \dontrun{
#' eri_report_html(
#'   sections = list(
#'     overview = list(
#'       heading = "Case summary",
#'       text    = "Cases increased in Q3.",
#'       table   = summary_df
#'     ),
#'     trends = list(
#'       heading = "Epidemic curve",
#'       figure  = epicurve_plot
#'     )
#'   ),
#'   path     = "outputs/malaria_report.html",
#'   title    = "Hispaniola Malaria 2024"
#' )
#' }
eri_report_html <- function(sections,
                             path,
                             title    = "ERI Report",
                             subtitle = NULL,
                             author   = NULL,
                             date     = format(Sys.Date(), "%B %d, %Y")) {
  if (!requireNamespace("quarto", quietly = TRUE)) {
    cli::cli_abort(c(
      "Package {.pkg quarto} is required for HTML reports.",
      "i" = "Install with {.code install.packages('quarto')} then ensure Quarto is on your PATH ({.url https://quarto.org})."
    ))
  }

  if (!is.list(sections)) {
    cli::cli_abort("{.arg sections} must be a list of section definitions.")
  }

  # Locate bundled template
  tmpl <- system.file("templates/eri_report.qmd", package = "erifunctions")
  if (!nzchar(tmpl)) {
    cli::cli_abort("Bundled template {.path inst/templates/eri_report.qmd} not found.")
  }

  dir.create(dirname(path), showWarnings = FALSE, recursive = TRUE)

  # Serialise sections: write figures to temp PNGs; convert tables to HTML
  serial <- .eri_serialise_sections(sections)

  # Write serialised sections to a temp RDS for the QMD to read
  params_rds <- tempfile(fileext = ".rds")
  withr::defer(unlink(params_rds))
  saveRDS(serial, params_rds)

  params <- list(
    title      = title,
    subtitle   = subtitle %||% "",
    author     = author   %||% "",
    date       = date,
    params_rds = params_rds
  )

  out_dir  <- dirname(normalizePath(path, mustWork = FALSE))
  out_file <- basename(path)

  quarto::quarto_render(
    input          = tmpl,
    output_file    = out_file,
    output_format  = "html",
    execute_params = params,
    quiet          = TRUE
  )

  # quarto renders into the template dir; move to requested path
  rendered <- file.path(dirname(tmpl), out_file)
  if (file.exists(rendered) && normalizePath(rendered) != normalizePath(path)) {
    file.rename(rendered, path)
  }

  cli::cli_alert_success("HTML report saved to {.path {path}}")
  invisible(path)
}

#' Copy the bundled ERI report Quarto template
#'
#' Copies `inst/templates/eri_report.qmd` to `path` so analysts can
#' customise it for their own projects.
#'
#' @param path Character; destination file path (should end in `.qmd`).
#' @param overwrite Logical; overwrite an existing file (default `FALSE`).
#'
#' @return `path` invisibly.
#' @export
#'
#' @examples
#' \dontrun{
#' eri_report_qmd_template("my_custom_report.qmd")
#' }
eri_report_qmd_template <- function(path, overwrite = FALSE) {
  tmpl <- system.file("templates/eri_report.qmd", package = "erifunctions")
  if (!nzchar(tmpl)) {
    cli::cli_abort("Bundled template {.path inst/templates/eri_report.qmd} not found.")
  }
  if (file.exists(path) && !overwrite) {
    cli::cli_abort(c(
      "{.path {path}} already exists.",
      "i" = "Use {.code overwrite = TRUE} to replace it."
    ))
  }
  file.copy(tmpl, path, overwrite = overwrite)
  cli::cli_alert_success("Template copied to {.path {path}}")
  invisible(path)
}

# --- internal helpers --------------------------------------------------------

.eri_serialise_sections <- function(sections) {
  lapply(sections, function(s) {
    out <- s[intersect(names(s), c("heading", "text", "figure_width", "figure_height"))]

    # Table → HTML fragment
    if (!is.null(s$table)) {
      if (!requireNamespace("flextable", quietly = TRUE)) {
        out$table_html <- "<p><em>flextable not installed; table omitted.</em></p>"
      } else {
        ft  <- eri_table(s$table)
        tmp <- tempfile(fileext = ".html")
        flextable::save_as_html(ft, path = tmp)
        out$table_html <- paste(readLines(tmp, warn = FALSE), collapse = "\n")
        unlink(tmp)
      }
    }

    # Figure → base64 PNG
    if (!is.null(s$figure) && inherits(s$figure, "gg")) {
      w   <- s$figure_width  %||% 8
      h   <- s$figure_height %||% 5
      tmp <- tempfile(fileext = ".png")
      ggplot2::ggsave(tmp, plot = s$figure, width = w, height = h, dpi = 150)
      b64 <- base64enc::base64encode(tmp)
      out$figure_b64 <- paste0("data:image/png;base64,", b64)
      unlink(tmp)
    }

    out
  })
}
