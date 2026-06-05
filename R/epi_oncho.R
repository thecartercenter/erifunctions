#' OEPA onchocerciasis program status levels
#'
#' Returns the ordered vector of OEPA oncho program status levels used for
#' plotting and data validation. Levels are ordered from no endemicity to
#' verified elimination.
#'
#' @return Character vector of length 5.
#' @export
#'
#' @examples
#' eri_oncho_program_levels()
eri_oncho_program_levels <- function() {
  c(
    "Non-endemic",
    "Under surveillance",
    "MDA ongoing",
    "MDA stopped - under surveillance",
    "Verified free of transmission"
  )
}

#' Choropleth map of OEPA oncho program status by focus
#'
#' Joins `status_data` to `shapefile` on `eu_col` and produces a filled
#' choropleth using the `oncho.status` colour scheme. The status column is
#' coerced to a factor ordered by `eri_oncho_program_levels()` so the legend
#' always renders in the correct progression.
#'
#' @param shapefile An sf object with one row per evaluation unit.
#' @param status_data A data frame with at least `eu_col` and `status_col`.
#' @param eu_col Name of the evaluation-unit join key in both `shapefile` and
#'   `status_data`.
#' @param status_col Name of the column in `status_data` containing the program
#'   status string.
#' @param title Optional map title.
#' @param scale_bar Logical; add a scale bar via `ggspatial` (default `TRUE`).
#' @param north_arrow Logical; add a north arrow via `ggspatial` (default
#'   `TRUE`).
#'
#' @return A `ggplot` object.
#' @export
#'
#' @examples
#' \dontrun{
#' eri_oncho_status_map(focus_sf, status_df, eu_col = "focus", status_col = "status")
#' }
eri_oncho_status_map <- function(shapefile,
                                  status_data,
                                  eu_col,
                                  status_col,
                                  title = NULL,
                                  scale_bar = TRUE,
                                  north_arrow = TRUE) {
  if (!requireNamespace("sf", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg sf} is required for {.fn eri_oncho_status_map}. Install it with {.code install.packages('sf')}.")
  }
  if (!inherits(shapefile, "sf")) {
    cli::cli_abort("{.arg shapefile} must be an sf object.")
  }
  if (!eu_col %in% names(shapefile)) {
    cli::cli_abort("{.arg eu_col} {.val {eu_col}} not found in {.arg shapefile}.")
  }
  if (!eu_col %in% names(status_data)) {
    cli::cli_abort("{.arg eu_col} {.val {eu_col}} not found in {.arg status_data}.")
  }
  if (!status_col %in% names(status_data)) {
    cli::cli_abort("{.arg status_col} {.val {status_col}} not found in {.arg status_data}.")
  }

  levels_ord <- eri_oncho_program_levels()

  status_data <- status_data
  status_data[[status_col]] <- factor(status_data[[status_col]], levels = levels_ord)

  plot_data <- dplyr::left_join(shapefile, status_data, by = eu_col)

  colors <- c(
    "Non-endemic"                      = "#FFFFFF",
    "Under surveillance"               = "#caf0f8",
    "MDA ongoing"                      = "#f4a261",
    "MDA stopped - under surveillance" = "#90be6d",
    "Verified free of transmission"    = "#2d6a4f"
  )

  p <- ggplot2::ggplot(plot_data) +
    ggplot2::geom_sf(ggplot2::aes(fill = .data[[status_col]]), color = "grey40", linewidth = 0.2) +
    ggplot2::scale_fill_manual(
      values  = colors,
      drop    = FALSE,
      na.value = "grey80",
      name    = "Program Status"
    ) +
    ggplot2::labs(title = title) +
    ggplot2::theme_void() +
    ggplot2::theme(
      plot.title          = ggplot2::element_text(hjust = 0.5, face = "bold", size = 12),
      legend.position     = "inside",
      legend.position.inside = c(0.85, 0.25),
      legend.background   = ggplot2::element_rect(fill = "white", color = "black", linewidth = 0.3),
      legend.margin       = ggplot2::margin(4, 6, 4, 6),
      legend.key.size     = ggplot2::unit(0.45, "cm"),
      legend.text         = ggplot2::element_text(size = 8),
      legend.title        = ggplot2::element_text(size = 8, face = "bold")
    )

  if (scale_bar) {
    if (!requireNamespace("ggspatial", quietly = TRUE)) {
      cli::cli_warn("Package {.pkg ggspatial} needed for scale bar; skipping.")
    } else {
      p <- p + ggspatial::annotation_scale(location = "bl", width_hint = 0.25)
    }
  }

  if (north_arrow) {
    if (!requireNamespace("ggspatial", quietly = TRUE)) {
      cli::cli_warn("Package {.pkg ggspatial} needed for north arrow; skipping.")
    } else {
      p <- p + ggspatial::annotation_north_arrow(
        location = "bl",
        which_north = "true",
        pad_y = ggplot2::unit(0.5, "cm"),
        style = ggspatial::north_arrow_fancy_orienteering()
      )
    }
  }

  p
}
