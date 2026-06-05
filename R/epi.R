#### Epidemiological utility functions ####

#### eri_incidence_rate ####

#' Compute incidence rate per population
#'
#' Vectorized incidence rate: `(cases / pop) * multiplier`. Returns `NA` for
#' rows where `pop <= 0` or either argument is `NA`.
#'
#' @param cases `num` Case counts (can be a vector).
#' @param pop `num` Denominator population (same length as `cases`).
#' @param multiplier `num` Rate multiplier. Default `1000` (cases per 1 000).
#' @returns A numeric vector of incidence rates.
#' @examples
#' \dontrun{
#' data |> dplyr::mutate(rate = eri_incidence_rate(n_cases, population))
#' }
#' @export
eri_incidence_rate <- function(cases, pop, multiplier = 1000) {
  if (length(cases) != length(pop)) {
    cli::cli_abort(
      "{.arg cases} and {.arg pop} must have the same length ({length(cases)} vs {length(pop)})."
    )
  }
  rate <- ifelse(is.na(pop) | pop <= 0, NA_real_, (cases / pop) * multiplier)
  as.numeric(rate)
}

#### eri_epiweek_date ####

#' Convert CDC epiweek and year to a Date
#'
#' Returns the first day (Sunday for CDC / Monday for ISO) of the given
#' epiweek in the given year. Consistent behaviour across DR and Haiti datasets.
#'
#' @param year `int` 4-digit year.
#' @param week `int` Epiweek number (1–53).
#' @param week_start `chr` First day of the epidemiological week.
#'   `"Sunday"` (CDC default) or `"Monday"` (ISO).
#' @returns A `Date` vector of the same length as `year` and `week`.
#' @examples
#' \dontrun{
#' eri_epiweek_date(2024, 1)      # first Sunday of epiweek 1, 2024
#' eri_epiweek_date(2024, 1, "Monday")
#' }
#' @export
eri_epiweek_date <- function(year, week, week_start = "Sunday") {
  week_start <- match.arg(week_start, c("Sunday", "Monday"))

  if (any(!is.na(week) & (week < 1L | week > 53L), na.rm = TRUE)) {
    cli::cli_warn("Some {.arg week} values are outside [1, 53]; they will return NA.")
  }

  jan4 <- as.Date(paste0(year, "-01-04"))
  dow_jan4 <- as.integer(format(jan4, "%u"))  # 1 = Monday ... 7 = Sunday

  if (week_start == "Monday") {
    week1_start <- jan4 - (dow_jan4 - 1L)
  } else {
    # CDC Sunday-start: Jan 4 is always in week 1; back to Sunday
    dow_sun <- as.integer(format(jan4, "%w"))  # 0 = Sunday ... 6 = Saturday
    week1_start <- jan4 - dow_sun
  }

  week1_start + (as.integer(week) - 1L) * 7L
}

#### eri_date_to_epiweek ####

#' Convert a Date to a CDC epiweek number
#'
#' Returns the epidemiological week number (1–53) for each date. The inverse of
#' [eri_epiweek_date()]. Uses CDC Sunday-start convention by default (matching
#' DR and Haiti surveillance data); pass `week_start = "Monday"` for ISO weeks.
#'
#' Dates that fall in an epiweek belonging to a different calendar year (e.g.
#' Dec 31 in CDC epiweek 1 of the following year) return the correct week number
#' for that epiweek. Use `lubridate::epiyear()` / `lubridate::isoyear()` to
#' obtain the corresponding epi year when needed.
#'
#' @param date A `Date` vector (or character coercible to Date).
#' @param week_start `chr` `"Sunday"` (CDC default) or `"Monday"` (ISO).
#' @returns An integer vector of epiweek numbers (1–53).
#' @examples
#' \dontrun{
#' eri_date_to_epiweek(as.Date("2024-01-07"))   # 1
#' eri_date_to_epiweek(as.Date("2024-12-29"))   # 52
#'
#' # Add epiweek to a case line list
#' cases |> dplyr::mutate(epiweek = eri_date_to_epiweek(sample_date))
#' }
#' @export
eri_date_to_epiweek <- function(date, week_start = "Sunday") {
  week_start <- match.arg(week_start, c("Sunday", "Monday"))
  date <- as.Date(date)
  if (week_start == "Sunday") {
    as.integer(lubridate::epiweek(date))
  } else {
    as.integer(lubridate::isoweek(date))
  }
}

#### eri_epiweek_range ####

#' Filter data to an epiweek range
#'
#' Returns rows of `data` whose year + epiweek falls within the inclusive range
#' `[start_year/start_week, end_year/end_week]`. Handles cross-year ranges
#' (e.g. week 40/2023 through week 10/2024) correctly.
#'
#' @param data A data frame or tibble.
#' @param year_col `chr` Name of the column containing the 4-digit year.
#' @param week_col `chr` Name of the column containing the epiweek number (1–53).
#' @param start_year `int` Start epi year (inclusive).
#' @param start_week `int` Start epiweek number (inclusive).
#' @param end_year `int` End epi year (inclusive).
#' @param end_week `int` End epiweek number (inclusive).
#' @returns A filtered tibble.
#' @examples
#' \dontrun{
#' # Keep weeks 40/2023 through 10/2024
#' eri_epiweek_range(weekly_data, "year", "epiweek",
#'                    start_year = 2023, start_week = 40,
#'                    end_year   = 2024, end_week   = 10)
#' }
#' @export
eri_epiweek_range <- function(data, year_col, week_col,
                               start_year, start_week,
                               end_year, end_week) {
  if (!year_col %in% names(data)) {
    cli::cli_abort("{.arg year_col} {.val {year_col}} not found in data.")
  }
  if (!week_col %in% names(data)) {
    cli::cli_abort("{.arg week_col} {.val {week_col}} not found in data.")
  }
  composite   <- as.integer(data[[year_col]]) * 100L + as.integer(data[[week_col]])
  start_key   <- as.integer(start_year) * 100L + as.integer(start_week)
  end_key     <- as.integer(end_year)   * 100L + as.integer(end_week)
  data[!is.na(composite) & composite >= start_key & composite <= end_key, , drop = FALSE]
}

#### eri_study_week ####

#' Calculate study week relative to an index date
#'
#' Returns the integer number of weeks between a data row's epiweek and an
#' `index_date`. Positive values are after the index, negative are before.
#' Week 1 is the week containing `index_date`.
#'
#' Based on `calc_sweek()` from `dr_irs.R`.
#'
#' @param year `int` Year column.
#' @param week `int` Epiweek column.
#' @param index_date `Date` The reference / treatment date.
#' @param week_start `chr` First day of the epidemiological week.
#'   `"Sunday"` (CDC default) or `"Monday"`.
#' @returns An integer vector of study weeks (can be negative for pre-index periods).
#' @examples
#' \dontrun{
#' data |> dplyr::mutate(sweek = eri_study_week(year, epiweek, as.Date("2020-01-05")))
#' }
#' @export
eri_study_week <- function(year, week, index_date, week_start = "Sunday") {
  if (!inherits(index_date, "Date")) {
    cli::cli_abort("{.arg index_date} must be a Date object.")
  }
  row_date <- eri_epiweek_date(year, week, week_start = week_start)
  as.integer(floor(as.numeric(row_date - index_date) / 7))
}

#### eri_epidemic_curve ####

#' Standard epidemic curve
#'
#' Aggregates case data by time period and returns a bar-chart epidemic curve
#' ggplot with `eri_plot_theme("epicurve")` applied. Optionally group by a
#' categorical column or facet by a second grouping.
#'
#' @param data A data frame with a date/date-like column and an optional count column.
#' @param date_col `chr` Column containing the case date or epiweek-start date.
#'   Passed through [lubridate::floor_date()] to bin by `period`.
#' @param count_col `chr` Column holding counts. If `NULL`, each row is one case
#'   (count = 1).
#' @param group_col `chr` or `NULL`. If supplied, bars are stacked/filled by this column.
#' @param period `chr` Aggregation period: `"week"`, `"month"`, or `"year"`.
#'   Default `"week"`.
#' @param facet_col `chr` or `NULL`. If supplied, the plot is faceted by this column.
#' @param title `chr` Plot title. Default `NULL`.
#' @returns A ggplot object.
#' @examples
#' \dontrun{
#' eri_epidemic_curve(case_data, date_col = "sample_date", count_col = "n",
#'                    group_col = "country", period = "month",
#'                    title = "Hispaniola malaria cases")
#' }
#' @export
eri_epidemic_curve <- function(data, date_col, count_col = NULL,
                                group_col = NULL, period = "week",
                                facet_col = NULL, title = NULL) {
  period <- match.arg(period, c("week", "month", "year"))

  if (!date_col %in% names(data)) {
    cli::cli_abort("{.arg date_col} {.val {date_col}} not found in data.")
  }
  if (!is.null(count_col) && !count_col %in% names(data)) {
    cli::cli_abort("{.arg count_col} {.val {count_col}} not found in data.")
  }
  if (!is.null(group_col) && !group_col %in% names(data)) {
    cli::cli_abort("{.arg group_col} {.val {group_col}} not found in data.")
  }
  if (!is.null(facet_col) && !facet_col %in% names(data)) {
    cli::cli_abort("{.arg facet_col} {.val {facet_col}} not found in data.")
  }

  data <- tibble::as_tibble(data)
  data[[date_col]] <- as.Date(data[[date_col]])

  floored_col <- ".eri_period"
  data[[floored_col]] <- lubridate::floor_date(data[[date_col]], unit = period)

  grp_cols <- c(floored_col, group_col %||% character(0))

  if (!is.null(count_col)) {
    agg <- data |>
      dplyr::group_by(dplyr::across(dplyr::all_of(c(grp_cols, facet_col %||% character(0))))) |>
      dplyr::summarise(
        .n = sum(.data[[count_col]], na.rm = TRUE),
        .groups = "drop"
      )
  } else {
    agg <- data |>
      dplyr::group_by(dplyr::across(dplyr::all_of(c(grp_cols, facet_col %||% character(0))))) |>
      dplyr::summarise(.n = dplyr::n(), .groups = "drop")
  }

  p <- ggplot2::ggplot(agg)

  if (!is.null(group_col)) {
    p <- p + ggplot2::geom_col(
      ggplot2::aes(
        x    = .data[[floored_col]],
        y    = .data$.n,
        fill = .data[[group_col]]
      )
    )
  } else {
    p <- p + ggplot2::geom_col(
      ggplot2::aes(x = .data[[floored_col]], y = .data$.n),
      fill = "#2d6a4f"
    )
  }

  x_label <- switch(period,
    "week"  = "Epiweek",
    "month" = "Month",
    "year"  = "Year"
  )

  epi_theme <- ggplot2::theme_bw() +
    ggplot2::theme(
      axis.text.x      = ggplot2::element_text(angle = 45, hjust = 1),
      plot.title       = ggplot2::element_text(hjust = 0.5, face = "bold"),
      panel.grid.minor = ggplot2::element_blank()
    )

  p <- p +
    ggplot2::labs(title = title, x = x_label, y = "Cases", fill = group_col) +
    epi_theme

  if (!is.null(facet_col)) {
    p <- p + ggplot2::facet_wrap(~ .data[[facet_col]])
  }

  p
}

#### eri_case_summary ####

#' Summarise case data by grouping columns
#'
#' Aggregates a case data frame by `group_cols`, optionally filtering to a date
#' range. If `count_col` is `NULL` (case-level data), counts rows. If `count_col`
#' is specified (pre-aggregated data), sums that column.
#'
#' @param data A data frame or tibble of case records.
#' @param group_cols `chr` vector of columns to group by (e.g. `c("country", "year")`).
#' @param start `Date` or `NULL`. If supplied, keeps rows where `date_col >= start`.
#' @param end `Date` or `NULL`. If supplied, keeps rows where `date_col <= end`.
#' @param date_col `chr` or `NULL`. Required when `start` or `end` is specified.
#'   The column to filter on.
#' @param count_col `chr` or `NULL`. If `NULL`, counts rows. If a column name,
#'   sums that column.
#' @returns A tibble with `group_cols` plus a `n_cases` column.
#' @examples
#' \dontrun{
#' eri_case_summary(
#'   case_data,
#'   group_cols = c("country", "year"),
#'   start      = as.Date("2024-01-01"),
#'   end        = as.Date("2024-12-31"),
#'   date_col   = "sample_date"
#' )
#' }
#' @export
eri_case_summary <- function(data, group_cols, start = NULL, end = NULL,
                              date_col = NULL, count_col = NULL) {
  data <- tibble::as_tibble(data)

  missing <- setdiff(group_cols, names(data))
  if (length(missing) > 0L) {
    cli::cli_abort("Column{?s} {.val {missing}} not found in data.")
  }

  if ((!is.null(start) || !is.null(end)) && is.null(date_col)) {
    cli::cli_abort("{.arg date_col} is required when {.arg start} or {.arg end} is supplied.")
  }

  if (!is.null(date_col) && !date_col %in% names(data)) {
    cli::cli_abort("{.arg date_col} {.val {date_col}} not found in data.")
  }

  if (!is.null(date_col)) {
    data[[date_col]] <- as.Date(data[[date_col]])
    if (!is.null(start)) data <- data[!is.na(data[[date_col]]) & data[[date_col]] >= as.Date(start), ]
    if (!is.null(end))   data <- data[!is.na(data[[date_col]]) & data[[date_col]] <= as.Date(end), ]
  }

  if (!is.null(count_col) && !count_col %in% names(data)) {
    cli::cli_abort("{.arg count_col} {.val {count_col}} not found in data.")
  }

  if (!is.null(count_col)) {
    data |>
      dplyr::group_by(dplyr::across(dplyr::all_of(group_cols))) |>
      dplyr::summarise(n_cases = sum(.data[[count_col]], na.rm = TRUE), .groups = "drop")
  } else {
    data |>
      dplyr::group_by(dplyr::across(dplyr::all_of(group_cols))) |>
      dplyr::summarise(n_cases = dplyr::n(), .groups = "drop")
  }
}
