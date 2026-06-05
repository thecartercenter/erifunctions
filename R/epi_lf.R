#### LF-specific analysis functions ####

#### eri_lf_pooled_prev ####

#' Pooled prevalence estimator for LF antigen surveys
#'
#' Implements the standard formula for estimating individual prevalence from
#' pooled test results: `1 - ((1 - npos/npool)^(1/pool_size))`.
#'
#' When `by` is supplied the function returns one prevalence estimate per group
#' (weighted mean of pool-level estimates, weighted by pool count). Matches the
#' formula in `pooled_prev.R`.
#'
#' @param npos `num` Number of positive pools.
#' @param npool `num` Total number of pools tested.
#' @param pool_size `num` Number of individuals per pool.
#' @param by `chr` vector or `NULL`. Column name(s) in the enclosing data frame
#'   (for use inside `dplyr::mutate()`) or a plain numeric vector equal in
#'   length to `npos`. When `NULL` (default), returns a single scalar.
#' @returns A numeric scalar (ungrouped) or a tibble with `by` columns plus
#'   `pooled_prev` (grouped).
#' @examples
#' \dontrun{
#' # Scalar
#' eri_lf_pooled_prev(npos = 3, npool = 100, pool_size = 5)
#'
#' # Grouped tibble
#' tas_data |>
#'   dplyr::group_by(commune) |>
#'   dplyr::summarise(
#'     npos      = sum(fts_result == "Positive"),
#'     npool     = dplyr::n(),
#'     pool_size = mean(pool_size)
#'   ) |>
#'   dplyr::mutate(prev = eri_lf_pooled_prev(npos, npool, pool_size))
#' }
#' @export
eri_lf_pooled_prev <- function(npos, npool, pool_size, by = NULL) {
  if (any(npool <= 0, na.rm = TRUE)) {
    cli::cli_abort("{.arg npool} must be > 0 for all rows.")
  }
  if (any(pool_size <= 0, na.rm = TRUE)) {
    cli::cli_abort("{.arg pool_size} must be > 0 for all rows.")
  }
  if (any(npos > npool, na.rm = TRUE)) {
    cli::cli_warn("{.arg npos} exceeds {.arg npool} for some rows; those will return NA.")
  }

  prev <- 1 - ((1 - (npos / npool)) ^ (1 / pool_size))
  prev[npos > npool] <- NA_real_
  prev[npos == 0] <- 0

  if (!is.null(by)) {
    cli::cli_abort(
      c(
        "{.arg by} is not supported in scalar mode.",
        "i" = "Use {.fn dplyr::group_by} + {.fn dplyr::summarise} then call {.fn eri_lf_pooled_prev} per group."
      )
    )
  }

  as.numeric(prev)
}

#### eri_lf_program_levels ####

#' Standard LF programme status levels
#'
#' Returns the canonical ordered character vector of WHO/GPELF LF elimination
#' status levels. Use with `factor(status_col, levels = eri_lf_program_levels())`
#' to ensure correct ordering in tables and maps.
#'
#' @returns A character vector of length 5.
#' @examples
#' \dontrun{
#' data |>
#'   dplyr::mutate(status = factor(status, levels = eri_lf_program_levels()))
#' }
#' @export
eri_lf_program_levels <- function() {
  c(
    "Non-endemic",
    "MDA not started",
    "MDA started",
    "PTS (Passed TAS-1)",
    "PTS (Passed TAS-3)"
  )
}

#### eri_lf_tas_summary ####

#' Summarise LF TAS antigen test results
#'
#' Cross-tabulates FTS and RDT results from an individual-level TAS dataset and
#' returns a tidy tibble with one row per FTS/RDT combination. Optionally
#' grouped by a geographic or survey unit column.
#'
#' @param data A data frame of individual TAS results (one row per person).
#' @param fts_col `chr` Column with FTS results (e.g. `"Positive"` / `"Negative"`).
#' @param rdt_col `chr` Column with RDT results (e.g. `"Positive"` / `"Negative"` / `NA`).
#' @param group_col `chr` or `NULL`. If supplied, the summary is produced per
#'   unique value of this column (e.g. `"commune"` or `"eu"`).
#' @returns A tibble with columns `fts_result`, `rdt_result`, `n`, `pct`
#'   (and `group_col` if supplied).
#' @examples
#' \dontrun{
#' eri_lf_tas_summary(tas_data, "fts_result", "rdt_result", group_col = "commune")
#' }
#' @export
eri_lf_tas_summary <- function(data, fts_col, rdt_col, group_col = NULL) {
  data <- tibble::as_tibble(data)

  for (col in c(fts_col, rdt_col)) {
    if (!col %in% names(data)) {
      cli::cli_abort("{.val {col}} not found in data.")
    }
  }
  if (!is.null(group_col) && !group_col %in% names(data)) {
    cli::cli_abort("{.arg group_col} {.val {group_col}} not found in data.")
  }

  grp_cols <- c(group_col %||% character(0), fts_col, rdt_col)

  out <- data |>
    dplyr::rename(fts_result = !!fts_col, rdt_result = !!rdt_col) |>
    dplyr::group_by(
      dplyr::across(dplyr::all_of(
        c(group_col %||% character(0), "fts_result", "rdt_result")
      ))
    ) |>
    dplyr::summarise(n = dplyr::n(), .groups = "drop")

  if (!is.null(group_col)) {
    out <- out |>
      dplyr::group_by(dplyr::across(dplyr::all_of(group_col))) |>
      dplyr::mutate(pct = round(.data$n / sum(.data$n) * 100, 1)) |>
      dplyr::ungroup()
  } else {
    out <- out |>
      dplyr::mutate(pct = round(.data$n / sum(.data$n) * 100, 1))
  }

  out
}

#### eri_lf_status_map ####

#' LF programme status choropleth map
#'
#' Wrapper around `eri_map_choropleth()` that applies the standard
#' `"lf.status"` colour scheme and discrete factor levels from
#' `eri_lf_program_levels()`.
#'
#' Requires `ggplot2` (in Imports). `ggspatial` (Imports) is used for scale
#' bar and north arrow by default; set `scale_bar = FALSE, north_arrow = FALSE`
#' to suppress.
#'
#' @param shapefile An `sf` polygon object.
#' @param status_data A data frame with a status column and a join key.
#' @param eu_col `chr` Column present in BOTH `shapefile` and `status_data`
#'   used to join them (e.g. `"eu"` or `"adm2_name"`).
#' @param status_col `chr` Column in `status_data` with LF programme status
#'   values (should match `eri_lf_program_levels()` entries).
#' @param title `chr` Map title. Default `NULL`.
#' @param scale_bar `lgl` Add ggspatial scale bar? Default `TRUE`.
#' @param north_arrow `lgl` Add ggspatial north arrow? Default `TRUE`.
#' @returns A ggplot object.
#' @examples
#' \dontrun{
#' eu_sf   <- eri_spatial_load("dr", level = 2)
#' eri_lf_status_map(eu_sf, lf_status, "adm2_name", "status",
#'                   title = "DR LF programme status 2024")
#' }
#' @export
eri_lf_status_map <- function(shapefile, status_data, eu_col, status_col,
                               title = NULL, scale_bar = TRUE, north_arrow = TRUE) {
  if (!eu_col %in% names(shapefile)) {
    cli::cli_abort("{.arg eu_col} {.val {eu_col}} not found in shapefile.")
  }
  if (!eu_col %in% names(status_data)) {
    cli::cli_abort("{.arg eu_col} {.val {eu_col}} not found in status_data.")
  }
  if (!status_col %in% names(status_data)) {
    cli::cli_abort("{.arg status_col} {.val {status_col}} not found in status_data.")
  }

  lvls   <- eri_lf_program_levels()
  scheme <- c("#FFFFFF", "#e63946", "#f4a261", "#90be6d", "#2d6a4f")
  names(scheme) <- lvls

  status_data <- tibble::as_tibble(status_data)
  status_data[[status_col]] <- factor(status_data[[status_col]], levels = lvls)

  joined <- dplyr::left_join(shapefile, status_data, by = eu_col)

  p <- ggplot2::ggplot(joined) +
    ggplot2::geom_sf(
      ggplot2::aes(fill = .data[[status_col]]),
      color = "white", linewidth = 0.2
    ) +
    ggplot2::scale_fill_manual(
      values   = scheme,
      na.value = "grey90",
      drop     = FALSE,
      name     = "LF status"
    ) +
    ggplot2::labs(title = title) +
    ggplot2::theme_void() +
    ggplot2::theme(
      plot.title             = ggplot2::element_text(hjust = 0.5, face = "bold", size = 12),
      legend.position        = "inside",
      legend.position.inside = c(0.85, 0.25),
      legend.background      = ggplot2::element_rect(
        fill = "white", color = "black", linewidth = 0.3
      ),
      legend.margin          = ggplot2::margin(4, 6, 4, 6),
      legend.key.size        = ggplot2::unit(0.45, "cm"),
      legend.text            = ggplot2::element_text(size = 8),
      legend.title           = ggplot2::element_text(size = 8, face = "bold")
    )

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
