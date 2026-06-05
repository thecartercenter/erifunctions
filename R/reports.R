#' Carter Center brand colour palette
#'
#' Returns a named character vector of the Carter Center colour palette derived
#' from the ERI programme proceedings slide deck. Use these values for manual
#' colour assignment in ggplot2 scales or table formatting.
#'
#' @return Named character vector of length 7.
#' @export
#'
#' @examples
#' eri_brand_colors()
#' eri_brand_colors()[["navy"]]
eri_brand_colors <- function() {
  c(
    navy       = "#44546A",
    blue       = "#4472C4",
    orange     = "#ED7D31",
    gold       = "#FFC000",
    green      = "#70AD47",
    light_blue = "#5B9BD5",
    gray       = "#A5A5A5"
  )
}

#' ERI-branded ggplot2 theme
#'
#' Extends `eri_plot_theme("epicurve")` with Carter Center font and colour
#' conventions: Calibri-like base (falls back gracefully if unavailable),
#' `#44546A` axis titles, and a clean panel suitable for reports.
#'
#' @param base_size Numeric; base font size in points (default `11`).
#'
#' @return A `ggplot2` theme object.
#' @export
#'
#' @examples
#' \dontrun{
#' ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)) +
#'   ggplot2::geom_point() +
#'   eri_brand_ggplot_theme()
#' }
eri_brand_ggplot_theme <- function(base_size = 11) {
  navy <- "#44546A"
  ggplot2::theme_bw(base_size = base_size) +
    ggplot2::theme(
      text             = ggplot2::element_text(family = "sans"),
      plot.title       = ggplot2::element_text(face = "bold", colour = navy,
                                               hjust = 0, size = base_size + 2),
      plot.subtitle    = ggplot2::element_text(colour = navy, hjust = 0,
                                               size = base_size),
      axis.title       = ggplot2::element_text(colour = navy, face = "bold"),
      axis.text        = ggplot2::element_text(colour = "grey30"),
      axis.text.x      = ggplot2::element_text(angle = 45, hjust = 1),
      panel.grid.minor = ggplot2::element_blank(),
      panel.border     = ggplot2::element_rect(colour = "grey70"),
      legend.title     = ggplot2::element_text(face = "bold", colour = navy),
      strip.background = ggplot2::element_rect(fill = navy),
      strip.text       = ggplot2::element_text(colour = "white", face = "bold")
    )
}

#' ERI-branded formatted table
#'
#' Wraps a data frame in a [flextable::flextable()] styled with Carter Center
#' branding: navy (`#44546A`) bold header, alternating row shading, Calibri
#' font, and an optional footnote. The result is usable directly in Excel (via
#' `openxlsx2`), HTML (via [flextable::save_as_html()]), and PPTX (via
#' `officer`).
#'
#' @param data A data frame or tibble.
#' @param title Optional character string; displayed as a bold caption above
#'   the table.
#' @param footnote Optional character string; displayed as small italic text
#'   below the table.
#' @param highlight_cols Optional named list mapping column names to hex fill
#'   colours for conditional highlighting of entire columns. Example:
#'   `list(pct = "#FFC000")`.
#' @param col_widths Optional named numeric vector mapping column names to
#'   widths in inches. Unspecified columns are auto-sized.
#'
#' @return A `flextable` object.
#' @export
#'
#' @examples
#' df <- tibble::tibble(country = c("DR", "Haiti"), cases = c(120L, 340L))
#' eri_table(df, title = "Malaria cases by country")
eri_table <- function(data,
                      title          = NULL,
                      footnote       = NULL,
                      highlight_cols = NULL,
                      col_widths     = NULL) {
  if (!requireNamespace("flextable", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg flextable} is required. Install with {.code install.packages('flextable')}.")
  }

  navy  <- "#44546A"
  strip <- "#E7E6E6"

  ft <- flextable::flextable(as.data.frame(data))

  # Header style
  ft <- flextable::bold(ft, part = "header")
  ft <- flextable::color(ft, color = "white", part = "header")
  ft <- flextable::bg(ft, bg = navy, part = "header")
  ft <- flextable::fontsize(ft, size = 11, part = "header")

  # Body style
  ft <- flextable::fontsize(ft, size = 10, part = "body")
  ft <- flextable::font(ft, fontname = "Calibri", part = "all")

  # Alternating row shading
  n_rows <- nrow(data)
  if (n_rows >= 2L) {
    even_rows <- seq(2L, n_rows, by = 2L)
    ft <- flextable::bg(ft, i = even_rows, bg = strip, part = "body")
  }

  # Column highlighting
  if (!is.null(highlight_cols)) {
    for (col in names(highlight_cols)) {
      if (col %in% names(data)) {
        ft <- flextable::bg(ft, j = col, bg = highlight_cols[[col]], part = "body")
      }
    }
  }

  # Borders
  border_outer <- officer::fp_border(color = navy, width = 1.5)
  border_inner <- officer::fp_border(color = "grey80", width = 0.5)
  ft <- flextable::border_outer(ft, border = border_outer, part = "all")
  ft <- flextable::border_inner_h(ft, border = border_inner, part = "body")
  ft <- flextable::border_inner_v(ft, border = border_inner, part = "all")

  # Column widths
  if (!is.null(col_widths)) {
    for (col in names(col_widths)) {
      if (col %in% names(data)) {
        ft <- flextable::width(ft, j = col, width = col_widths[[col]])
      }
    }
  }

  ft <- flextable::autofit(ft)

  # Caption
  if (!is.null(title)) {
    ft <- flextable::set_caption(ft, caption = title)
  }

  # Footnote
  if (!is.null(footnote)) {
    ft <- flextable::add_footer_lines(ft, values = footnote)
    ft <- flextable::fontsize(ft, size = 8, part = "footer")
    ft <- flextable::italic(ft, part = "footer")
    ft <- flextable::color(ft, color = "grey40", part = "footer")
  }

  ft
}
