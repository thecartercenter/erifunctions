#### Data-addressing model registry (ADR-0012) ####

# Read the bundled data-model registry (the known data_source / data_type / format
# values for the 5-axis path). Kept tiny and read on demand.
#' @keywords internal
.eri_data_model <- function() {
  path <- system.file("registry/data_model.yaml", package = "erifunctions")
  if (!nzchar(path)) {
    cli::cli_abort("Bundled data-model registry not found (registry/data_model.yaml).")
  }
  yaml::read_yaml(path)
}

# Closed set of pipeline layers (raw -> staged -> processed). Layers are a fixed
# vocabulary; sources/measures are extensible.
#' @keywords internal
.eri_layers <- function() c("raw", "staged", "processed")

# Validate an extensible axis value (data_source / data_type / format). Unknown
# values WARN rather than error, so new data is never blocked -- only flagged so
# the analyst registers it (ADR-0012 extensibility).
#' @keywords internal
.eri_check_axis <- function(axis, value, known) {
  if (!value %in% known) {
    cli::cli_warn(c(
      "!" = "Unknown {.arg {axis}} {.val {value}} -- it is not in the data-model registry.",
      "i" = "Known {axis}: {.val {known}}.",
      "i" = "If this is a real new {axis}, register it (onboarding / {.path inst/registry/data_model.yaml})."
    ))
  }
  invisible(value)
}

#' Show the data-addressing model: known sources, measures and formats
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Prints (and returns invisibly) the registry of known values for the five-axis
#' canonical path `data/{country}/{disease}/{data_source}/{data_type}/{layer}/`
#' (ADR-0012): the `data_source` channels, the `data_type` measures, the input
#' `format`s, and the pipeline `layer`s. New sources/measures are added to the
#' registry by onboarding; an unregistered value warns rather than errors.
#'
#' @returns Invisibly, the registry as a named list.
#' @examples
#' eri_data_model()
#' @export
eri_data_model <- function() {
  m <- .eri_data_model()

  cli::cli_h1("Data-addressing model (ADR-0012)")
  cli::cli_text("Path: {.path data/{{country}}/{{disease}}/{{data_source}}/{{data_type}}/{{layer}}/}")

  cli::cli_h2("data_source {.emph (channel / how the data arrives)}")
  for (nm in names(m$data_sources)) cli::cli_bullets(c("*" = "{.strong {nm}} -- {m$data_sources[[nm]]}"))

  cli::cli_h2("data_type {.emph (the measure / what it captures)}")
  for (nm in names(m$data_types)) cli::cli_bullets(c("*" = "{.strong {nm}} -- {m$data_types[[nm]]}"))

  cli::cli_h2("format {.emph (input shape of a programmatic source)}")
  for (nm in names(m$formats)) cli::cli_bullets(c("*" = "{.strong {nm}} -- {m$formats[[nm]]}"))

  cli::cli_h2("layer")
  cli::cli_text("{.val {m$layers}}")

  invisible(m)
}
