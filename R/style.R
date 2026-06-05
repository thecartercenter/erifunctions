#### ERI visual style system ####

#### eri_color_scheme ####

#' ERI standard colour schemes
#'
#' Returns a named character vector of hex colours for a given programme or
#' purpose. Designed to be passed directly to `scale_fill_manual(values = ...)`.
#'
#' @param type `chr` Scheme name. One of:
#'   - `"malaria.incidence"` — white / light-green / yellow / red (0, <1, 1–10, >=10 per 1 000)
#'   - `"lf.status"` — 5-level LF programme status (Non-endemic → PTS TAS-3)
#'   - `"oncho.status"` — 5-level OEPA oncho status (Non-endemic → Verified free)
#'   - `"activities"` — Completed (green) / Not completed (red)
#'   - `"dq.flag"` — pass (grey) / warning (orange) / fail (red)
#' @returns A named character vector of hex colour codes. Names are the
#'   category labels; values are hex colours.
#' @examples
#' \dontrun{
#' ggplot(...) +
#'   geom_sf(aes(fill = incidence_class)) +
#'   scale_fill_manual(values = eri_color_scheme("malaria.incidence"))
#' }
#' @export
eri_color_scheme <- function(type) {
  schemes <- list(
    "malaria.incidence" = c(
      "0"     = "#FFFFFF",
      "<1"    = "#95d5b2",
      "1-10"  = "#f9c74f",
      ">=10"  = "#d62828"
    ),
    "lf.status" = c(
      "Non-endemic"         = "#FFFFFF",
      "MDA not started"     = "#e63946",
      "MDA started"         = "#f4a261",
      "PTS (Passed TAS-1)"  = "#90be6d",
      "PTS (Passed TAS-3)"  = "#2d6a4f"
    ),
    "oncho.status" = c(
      "Non-endemic"                      = "#FFFFFF",
      "Under surveillance"               = "#caf0f8",
      "MDA ongoing"                      = "#f4a261",
      "MDA stopped - under surveillance" = "#90be6d",
      "Verified free of transmission"    = "#2d6a4f"
    ),
    "activities" = c(
      "Completed"     = "#52b788",
      "Not completed" = "#e63946"
    ),
    "dq.flag" = c(
      "pass"    = "#adb5bd",
      "warning" = "#f4a261",
      "fail"    = "#e63946"
    )
  )

  if (!type %in% names(schemes)) {
    cli::cli_abort(c(
      "Unknown colour scheme type: {.val {type}}",
      "i" = "Available types: {.val {names(schemes)}}"
    ))
  }
  schemes[[type]]
}

#### eri_plot_theme ####

#' ERI standard ggplot2 themes
#'
#' Returns a [ggplot2::theme()] object for a given output type. Add to any
#' ggplot with `+`.
#'
#' @param type `chr` Theme name. One of:
#'   - `"map"` — `theme_void()` with legend inside a bordered box, centred bold title.
#'   - `"epicurve"` — `theme_bw()` with 45-degree x-axis tick labels.
#'   - `"map.inset"` — `theme_void()` with a black panel border (for reference insets).
#' @returns A `ggplot2::theme` object.
#' @examples
#' \dontrun{
#' ggplot(...) + geom_sf() + eri_plot_theme("map")
#' ggplot(...) + geom_col() + eri_plot_theme("epicurve")
#' }
#' @export
eri_plot_theme <- function(type = "map") {
  valid <- c("map", "epicurve", "map.inset")
  if (!type %in% valid) {
    cli::cli_abort(c(
      "Unknown theme type: {.val {type}}",
      "i" = "Available types: {.val {valid}}"
    ))
  }

  switch(type,
    "map" = ggplot2::theme_void() +
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
      ),
    "epicurve" = ggplot2::theme_bw() +
      ggplot2::theme(
        axis.text.x  = ggplot2::element_text(angle = 45, hjust = 1),
        plot.title   = ggplot2::element_text(hjust = 0.5, face = "bold"),
        panel.grid.minor = ggplot2::element_blank()
      ),
    "map.inset" = ggplot2::theme_void() +
      ggplot2::theme(
        panel.border = ggplot2::element_rect(color = "black", fill = NA, linewidth = 0.8)
      )
  )
}
