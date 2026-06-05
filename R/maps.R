#### ERI mapping functions ####

#### eri_map_choropleth ####

#' Choropleth map from a shapefile and data frame
#'
#' Joins `fill_data` to `shapefile` by `admin_col`, applies `eri_plot_theme("map")`,
#' and returns a ggplot. The fill variable can be continuous or discrete; pass a
#' `scale_fill_*` layer to customise.
#'
#' @param shapefile An `sf` polygon object (e.g. from `eri_spatial_load()`).
#' @param fill_data A data frame with the values to map.
#' @param fill_col `chr` Column in `fill_data` used for fill aesthetics.
#' @param admin_col `chr` Column present in BOTH `shapefile` and `fill_data`
#'   used to join them (e.g. `"adm2_name"`).
#' @param title `chr` Map title. Default `NULL` (no title).
#' @param fill_label `chr` Legend title. Default `NULL` (uses `fill_col`).
#' @param scale_bar `lgl` Add a ggspatial scale bar? Default `TRUE`.
#' @param north_arrow `lgl` Add a ggspatial north arrow? Default `TRUE`.
#' @returns A ggplot object.
#' @examples
#' \dontrun{
#' communes <- eri_spatial_load("ht", level = 2)
#' eri_map_choropleth(
#'   communes, case_summary,
#'   fill_col  = "n_cases",
#'   admin_col = "adm2_name",
#'   title     = "Haiti malaria cases 2024"
#' )
#' }
#' @export
eri_map_choropleth <- function(shapefile, fill_data, fill_col, admin_col,
                                title = NULL, fill_label = NULL,
                                scale_bar = TRUE, north_arrow = TRUE) {
  if (!admin_col %in% names(shapefile)) {
    cli::cli_abort(
      "{.arg admin_col} {.val {admin_col}} not found in shapefile columns: {.val {names(shapefile)}}."
    )
  }
  if (!admin_col %in% names(fill_data)) {
    cli::cli_abort(
      "{.arg admin_col} {.val {admin_col}} not found in fill_data columns: {.val {names(fill_data)}}."
    )
  }
  if (!fill_col %in% names(fill_data)) {
    cli::cli_abort(
      "{.arg fill_col} {.val {fill_col}} not found in fill_data columns: {.val {names(fill_data)}}."
    )
  }

  joined <- dplyr::left_join(
    shapefile,
    fill_data,
    by = admin_col
  )

  p <- ggplot2::ggplot(joined) +
    ggplot2::geom_sf(ggplot2::aes(fill = .data[[fill_col]]), color = "white", linewidth = 0.2) +
    ggplot2::labs(
      title = title,
      fill  = fill_label %||% fill_col
    ) +
    eri_plot_theme("map")

  if (scale_bar) {
    p <- p + ggspatial::annotation_scale(location = "bl", width_hint = 0.3)
  }
  if (north_arrow) {
    p <- p + ggspatial::annotation_north_arrow(
      location = "tl",
      style    = ggspatial::north_arrow_fancy_orienteering(
        fill      = c("grey80", "white"),
        line_col  = "grey30",
        text_col  = "grey30"
      ),
      height = ggplot2::unit(1, "cm"),
      width  = ggplot2::unit(1, "cm")
    )
  }

  p
}

#### eri_map_incidence ####

#' Incidence choropleth map
#'
#' Joins `case_data` to `shapefile`, computes an incidence rate as
#' `(case_col / pop_col) * multiplier`, categorises it into the standard
#' `"malaria.incidence"` breaks (0 / <1 / 1–10 / >=10), and returns a ggplot
#' with `eri_color_scheme("malaria.incidence")` applied.
#'
#' @param shapefile An `sf` polygon object.
#' @param case_data Data frame with case counts and population.
#' @param case_col `chr` Column with case counts.
#' @param pop_col `chr` Column with denominator population.
#' @param admin_col `chr` Column used to join `case_data` to `shapefile`.
#' @param multiplier `num` Rate multiplier. Default `1000` (cases per 1 000 population).
#' @param title `chr` Map title. Default `NULL`.
#' @param scale_bar `lgl` Add a ggspatial scale bar? Default `TRUE`.
#' @param north_arrow `lgl` Add a ggspatial north arrow? Default `TRUE`.
#' @returns A ggplot object.
#' @examples
#' \dontrun{
#' communes <- eri_spatial_load("ht", level = 2)
#' eri_map_incidence(
#'   communes, annual_cases,
#'   case_col  = "n_cases",
#'   pop_col   = "pop",
#'   admin_col = "adm2_name",
#'   title     = "Haiti malaria incidence per 1 000, 2024"
#' )
#' }
#' @export
eri_map_incidence <- function(shapefile, case_data, case_col, pop_col, admin_col,
                               multiplier = 1000, title = NULL,
                               scale_bar = TRUE, north_arrow = TRUE) {
  for (col in c(case_col, pop_col, admin_col)) {
    if (!col %in% names(case_data)) {
      cli::cli_abort("{.val {col}} not found in case_data.")
    }
  }
  if (!admin_col %in% names(shapefile)) {
    cli::cli_abort(
      "{.arg admin_col} {.val {admin_col}} not found in shapefile."
    )
  }

  joined <- dplyr::left_join(shapefile, case_data, by = admin_col) |>
    dplyr::mutate(
      .eri_rate = .data[[case_col]] / .data[[pop_col]] * multiplier,
      incidence_class = dplyr::case_when(
        is.na(.eri_rate)      ~ NA_character_,
        .eri_rate == 0        ~ "0",
        .eri_rate < 1         ~ "<1",
        .eri_rate < 10        ~ "1-10",
        TRUE                  ~ ">=10"
      ),
      incidence_class = factor(
        .data$incidence_class,
        levels = c("0", "<1", "1-10", ">=10")
      )
    )

  scheme <- eri_color_scheme("malaria.incidence")

  p <- ggplot2::ggplot(joined) +
    ggplot2::geom_sf(
      ggplot2::aes(fill = .data$incidence_class),
      color    = "white",
      linewidth = 0.2
    ) +
    ggplot2::scale_fill_manual(
      values  = scheme,
      na.value = "grey90",
      drop    = FALSE,
      name    = glue::glue("Per {format(multiplier, big.mark = ',')} pop.")
    ) +
    ggplot2::labs(title = title) +
    eri_plot_theme("map")

  if (scale_bar) {
    p <- p + ggspatial::annotation_scale(location = "bl", width_hint = 0.3)
  }
  if (north_arrow) {
    p <- p + ggspatial::annotation_north_arrow(
      location = "tl",
      style    = ggspatial::north_arrow_fancy_orienteering(
        fill      = c("grey80", "white"),
        line_col  = "grey30",
        text_col  = "grey30"
      ),
      height = ggplot2::unit(1, "cm"),
      width  = ggplot2::unit(1, "cm")
    )
  }

  p
}

#### eri_map_points ####

#' Point overlay map
#'
#' Converts `point_data` to an `sf` object using `lat_col` and `lon_col`,
#' overlays it on a base `shapefile`, and returns a ggplot. Rows with `NA`
#' coordinates are dropped with a warning (same as `eri_spatial_join()`).
#'
#' @param shapefile An `sf` polygon object used as the base layer.
#' @param point_data Data frame with coordinate columns.
#' @param lat_col `chr` Latitude column name.
#' @param lon_col `chr` Longitude column name.
#' @param fill_col `chr` Column in `point_data` used for point fill/colour.
#'   `NULL` (default) produces solid points.
#' @param shape_col `chr` Column in `point_data` used for point shape.
#'   `NULL` (default) uses a single shape.
#' @param point_size `num` Point size. Default `2`.
#' @param point_shape `int` Shape number when `shape_col = NULL`. Default `21`
#'   (filled circle with colour border).
#' @param title `chr` Map title. Default `NULL`.
#' @param scale_bar `lgl` Add a ggspatial scale bar? Default `TRUE`.
#' @param north_arrow `lgl` Add a ggspatial north arrow? Default `TRUE`.
#' @returns A ggplot object.
#' @examples
#' \dontrun{
#' communes <- eri_spatial_load("ht", level = 2)
#' eri_map_points(
#'   communes, tas_results,
#'   lat_col   = "lat",
#'   lon_col   = "lon",
#'   fill_col  = "fts_result",
#'   title     = "Haiti LF TAS results 2024"
#' )
#' }
#' @export
eri_map_points <- function(shapefile, point_data, lat_col, lon_col,
                            fill_col = NULL, shape_col = NULL,
                            point_size = 2, point_shape = 21,
                            title = NULL, scale_bar = TRUE, north_arrow = TRUE) {
  for (col in c(lat_col, lon_col)) {
    if (!col %in% names(point_data)) {
      cli::cli_abort("{.val {col}} not found in point_data.")
    }
  }

  point_data <- tibble::as_tibble(point_data)
  n_na <- sum(is.na(point_data[[lat_col]]) | is.na(point_data[[lon_col]]))
  if (n_na > 0L) {
    cli::cli_warn("{n_na} row{?s} with NA coordinate{?s} dropped.")
    point_data <- point_data[!is.na(point_data[[lat_col]]) & !is.na(point_data[[lon_col]]), ]
  }

  pts_sf <- sf::st_as_sf(
    point_data,
    coords = c(lon_col, lat_col),
    crs    = sf::st_crs(shapefile),
    remove = FALSE
  )

  p <- ggplot2::ggplot() +
    ggplot2::geom_sf(data = shapefile, fill = "grey95", color = "grey60", linewidth = 0.2)

  if (!is.null(fill_col) || !is.null(shape_col)) {
    aes_args <- list()
    if (!is.null(fill_col)) {
      if (!fill_col %in% names(point_data)) {
        cli::cli_abort("{.arg fill_col} {.val {fill_col}} not found in point_data.")
      }
      aes_args$fill   <- ggplot2::aes(.data[[fill_col]])$fill
      aes_args$colour <- ggplot2::aes(.data[[fill_col]])$colour
    }
    if (!is.null(shape_col)) {
      if (!shape_col %in% names(point_data)) {
        cli::cli_abort("{.arg shape_col} {.val {shape_col}} not found in point_data.")
      }
    }

    if (!is.null(fill_col) && !is.null(shape_col)) {
      p <- p + ggplot2::geom_sf(
        data = pts_sf,
        ggplot2::aes(fill = .data[[fill_col]], shape = .data[[shape_col]]),
        size = point_size
      )
    } else if (!is.null(fill_col)) {
      p <- p + ggplot2::geom_sf(
        data  = pts_sf,
        ggplot2::aes(fill = .data[[fill_col]]),
        shape = point_shape,
        size  = point_size
      )
    } else {
      p <- p + ggplot2::geom_sf(
        data = pts_sf,
        ggplot2::aes(shape = .data[[shape_col]]),
        size = point_size
      )
    }
  } else {
    p <- p + ggplot2::geom_sf(
      data  = pts_sf,
      shape = point_shape,
      size  = point_size,
      fill  = "#2d6a4f"
    )
  }

  p <- p + ggplot2::labs(title = title) + eri_plot_theme("map")

  if (scale_bar) {
    p <- p + ggspatial::annotation_scale(location = "bl", width_hint = 0.3)
  }
  if (north_arrow) {
    p <- p + ggspatial::annotation_north_arrow(
      location = "tl",
      style    = ggspatial::north_arrow_fancy_orienteering(
        fill      = c("grey80", "white"),
        line_col  = "grey30",
        text_col  = "grey30"
      ),
      height = ggplot2::unit(1, "cm"),
      width  = ggplot2::unit(1, "cm")
    )
  }

  p
}

#### eri_map_inset ####

#' Add an inset reference map to a main map
#'
#' Draws a small reference map showing `country_sf` in grey with `highlight_sf`
#' shaded red, then overlays it on `main_map` at the requested position using
#' [cowplot::ggdraw()]. The inset uses `eri_plot_theme("map.inset")` (void
#' theme with a black border).
#'
#' Requires the `cowplot` package.
#'
#' @param main_map A ggplot object (the primary map).
#' @param country_sf An `sf` object for the country/region outline.
#' @param highlight_sf An `sf` object for the study area to highlight in red.
#' @param position `num` vector of length 4 giving the inset position and size
#'   as fractions of the main map: `c(xmin, ymin, width, height)`. Default
#'   `c(0.65, 0.05, 0.32, 0.38)`.
#' @param highlight_color `chr` Fill colour for the highlighted area.
#'   Default `"#e63946"` (red).
#' @returns A cowplot `ggdraw` object (also a ggplot).
#' @examples
#' \dontrun{
#' haiti <- eri_spatial_load("ht", level = 0)
#' dept  <- eri_spatial_load("ht", level = 1)
#' main  <- eri_map_choropleth(dept, data, "n_cases", "adm1_name")
#' eri_map_inset(main, haiti, dept)
#' }
#' @export
eri_map_inset <- function(main_map, country_sf, highlight_sf,
                           position      = c(0.65, 0.05, 0.32, 0.38),
                           highlight_color = "#e63946") {
  if (!requireNamespace("cowplot", quietly = TRUE)) {
    cli::cli_abort(
      "Package {.pkg cowplot} must be installed to use {.fn eri_map_inset}."
    )
  }

  if (length(position) != 4L) {
    cli::cli_abort("{.arg position} must be a numeric vector of length 4: c(xmin, ymin, width, height).")
  }

  ref_map <- ggplot2::ggplot() +
    ggplot2::geom_sf(data = country_sf,   fill = "grey85", color = "grey50", linewidth = 0.3) +
    ggplot2::geom_sf(data = highlight_sf, fill = highlight_color, color = "grey50", linewidth = 0.2) +
    eri_plot_theme("map.inset")

  cowplot::ggdraw(main_map) +
    cowplot::draw_plot(
      ref_map,
      x      = position[1],
      y      = position[2],
      width  = position[3],
      height = position[4]
    )
}
