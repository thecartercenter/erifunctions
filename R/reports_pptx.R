#' Create an ERI-branded PowerPoint presentation
#'
#' Loads the Carter Center branded PPTX template bundled with the package and
#' returns an [officer::read_pptx()] object. Use the returned object with
#' `eri_pptx_add_*()` functions to build up the presentation slide by slide,
#' then write to disk with [eri_pptx_save()].
#'
#' @param template Optional character path to a custom `.pptx` template.
#'   Defaults to the bundled Carter Center template
#'   (`inst/templates/eri_template.pptx`).
#'
#' @return An `officer` rpptx object.
#' @export
#'
#' @examples
#' \dontrun{
#' pptx <- eri_pptx_create()
#' pptx <- eri_pptx_add_title(pptx, "Hispaniola Malaria 2024",
#'                             subtitle = "Annual Programme Report")
#' pptx <- eri_pptx_add_table(pptx, summary_df, title = "Case summary")
#' eri_pptx_save(pptx, "outputs/malaria_report.pptx")
#' }
eri_pptx_create <- function(template = NULL) {
  if (!requireNamespace("officer", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg officer} is required. Install with {.code install.packages('officer')}.")
  }
  if (is.null(template)) {
    template <- system.file("templates/eri_template.pptx", package = "erifunctions")
    if (!nzchar(template)) {
      cli::cli_abort("Bundled template {.path inst/templates/eri_template.pptx} not found.")
    }
  } else {
    if (!file.exists(template)) {
      cli::cli_abort("Template file not found: {.path {template}}")
    }
  }
  officer::read_pptx(template)
}

#' Add a title slide to an ERI PowerPoint
#'
#' Adds a slide using the "Title Slide" layout from the loaded template.
#'
#' @param pptx An `officer` rpptx object from [eri_pptx_create()].
#' @param title Character; main title text.
#' @param subtitle Optional character; subtitle text.
#'
#' @return The updated rpptx object.
#' @export
#'
#' @examples
#' \dontrun{
#' pptx <- eri_pptx_create() |>
#'   eri_pptx_add_title("Hispaniola Malaria 2024", subtitle = "Annual Report")
#' }
eri_pptx_add_title <- function(pptx, title, subtitle = NULL) {
  layout <- .eri_pptx_find_layout(pptx, c("Title Slide", "Title slide", "title slide"))
  pptx <- officer::add_slide(pptx, layout = layout, master = .eri_pptx_master(pptx))
  pptx <- officer::ph_with(pptx, value = title,
                            location = officer::ph_location_type(type = "ctrTitle"))
  if (!is.null(subtitle)) {
    pptx <- tryCatch(
      officer::ph_with(pptx, value = subtitle,
                       location = officer::ph_location_type(type = "subTitle")),
      error = function(e) pptx
    )
  }
  pptx
}

#' Add a section divider slide to an ERI PowerPoint
#'
#' @param pptx An `officer` rpptx object.
#' @param title Character; section title text.
#'
#' @return The updated rpptx object.
#' @export
eri_pptx_add_section <- function(pptx, title) {
  layout <- .eri_pptx_find_layout(pptx, c("Section Header", "section header",
                                           "Title Only", "Blank"))
  pptx <- officer::add_slide(pptx, layout = layout, master = .eri_pptx_master(pptx))
  tryCatch(
    officer::ph_with(pptx, value = title,
                     location = officer::ph_location_type(type = "title")),
    error = function(e) pptx
  )
}

#' Add a data table slide to an ERI PowerPoint
#'
#' Renders a data frame as an [eri_table()] flextable on a new slide.
#'
#' @param pptx An `officer` rpptx object.
#' @param data A data frame or tibble to display.
#' @param title Optional character; slide title.
#' @param footnote Optional character; passed to [eri_table()].
#'
#' @return The updated rpptx object.
#' @export
eri_pptx_add_table <- function(pptx, data, title = NULL, footnote = NULL) {
  layout <- .eri_pptx_find_layout(pptx, c("Title and Content", "Title, Content",
                                           "Two Content", "Blank"))
  pptx <- officer::add_slide(pptx, layout = layout, master = .eri_pptx_master(pptx))

  if (!is.null(title)) {
    pptx <- tryCatch(
      officer::ph_with(pptx, value = title,
                       location = officer::ph_location_type(type = "title")),
      error = function(e) pptx
    )
  }

  ft <- eri_table(data, footnote = footnote)
  pptx <- officer::ph_with(pptx, value = ft,
                            location = officer::ph_location_type(type = "body"))
  pptx
}

#' Add a ggplot figure slide to an ERI PowerPoint
#'
#' Saves the ggplot as a temporary PNG and inserts it onto a new slide.
#'
#' @param pptx An `officer` rpptx object.
#' @param plot A `ggplot` object.
#' @param title Optional character; slide title.
#' @param width Figure width in inches (default `8`).
#' @param height Figure height in inches (default `5`).
#' @param dpi Resolution in DPI (default `150`).
#'
#' @return The updated rpptx object.
#' @export
eri_pptx_add_plot <- function(pptx, plot, title = NULL,
                               width = 8, height = 5, dpi = 150) {
  layout <- .eri_pptx_find_layout(pptx, c("Title and Content", "Title, Content",
                                           "Blank"))
  pptx <- officer::add_slide(pptx, layout = layout, master = .eri_pptx_master(pptx))

  if (!is.null(title)) {
    pptx <- tryCatch(
      officer::ph_with(pptx, value = title,
                       location = officer::ph_location_type(type = "title")),
      error = function(e) pptx
    )
  }

  tmp <- tempfile(fileext = ".png")
  withr::defer(unlink(tmp))
  ggplot2::ggsave(tmp, plot = plot, width = width, height = height, dpi = dpi)

  pptx <- officer::ph_with(
    pptx,
    value    = officer::external_img(tmp, width = width, height = height),
    location = officer::ph_location_type(type = "body")
  )
  pptx
}

#' Save an ERI PowerPoint to disk
#'
#' @param pptx An `officer` rpptx object.
#' @param path Character; output file path (should end in `.pptx`).
#'
#' @return `path` invisibly.
#' @export
#'
#' @examples
#' \dontrun{
#' eri_pptx_save(pptx, "outputs/malaria_report.pptx")
#' }
eri_pptx_save <- function(pptx, path) {
  dir.create(dirname(path), showWarnings = FALSE, recursive = TRUE)
  print(pptx, target = path)
  cli::cli_alert_success("Presentation saved to {.path {path}}")
  invisible(path)
}

# --- internal helpers ---------------------------------------------------------

.eri_pptx_master <- function(pptx) {
  masters <- officer::layout_summary(pptx)$master
  if (length(masters) == 0L) return("Office Theme")
  masters[[1L]]
}

.eri_pptx_find_layout <- function(pptx, candidates) {
  available <- officer::layout_summary(pptx)$layout
  for (cand in candidates) {
    if (cand %in% available) return(cand)
  }
  available[[1L]]
}
