#### Template management ####

.ERI_TEMPLATE_REGISTRY_PATH <- "templates/_registry.yaml"
.ERI_TEMPLATE_AZURE_DIR     <- "templates"

#' @keywords internal
.eri_template_con <- function(data_con) {
  if (!is.null(data_con)) return(data_con)
  suppressMessages(
    get_azure_storage_connection(
      storage_name = Sys.getenv("ERIFUNCTIONS_DATA_STORAGE_NAME", unset = "data")
    )
  )
}

#' @keywords internal
.eri_template_bundled <- function() {
  # Probe via a known file to get the directory -- system.file() on a directory
  # path can return "" in pkgload dev contexts even when the dir exists.
  probe    <- system.file("templates/eri_daily_workflow.qmd", package = "erifunctions")
  tmpl_dir <- if (nchar(probe)) dirname(probe) else ""
  if (!nchar(tmpl_dir) || !dir.exists(tmpl_dir)) return(list())

  files <- list.files(tmpl_dir, full.names = TRUE)
  files <- files[!grepl("_registry\\.yaml$", files)]

  lapply(files, function(f) {
    list(
      name        = tools::file_path_sans_ext(basename(f)),
      description = "(bundled)",
      source      = "bundled",
      filename    = basename(f),
      local_path  = f
    )
  })
}

#' @keywords internal
.eri_template_registry_read <- function(data_con) {
  if (!AzureStor::storage_file_exists(data_con, .ERI_TEMPLATE_REGISTRY_PATH)) {
    return(list(entries = list()))
  }
  tmp <- tempfile(fileext = ".yaml")
  withr::defer(unlink(tmp))
  AzureStor::storage_download(data_con, .ERI_TEMPLATE_REGISTRY_PATH, tmp, overwrite = TRUE)
  reg <- yaml::read_yaml(tmp)
  if (is.null(reg$entries)) reg$entries <- list()
  reg
}

#' @keywords internal
.eri_template_registry_write <- function(registry, data_con) {
  tmp <- tempfile(fileext = ".yaml")
  withr::defer(unlink(tmp))
  yaml::write_yaml(registry, tmp)
  .eri_create_azure_dir(data_con, .ERI_TEMPLATE_AZURE_DIR)
  AzureStor::storage_upload(data_con, tmp, .ERI_TEMPLATE_REGISTRY_PATH)
}

#### eri_template_list ####

#' List available Quarto and R templates
#'
#' Returns a tibble combining bundled package templates (always available offline)
#' with any custom templates registered in the Azure `templates/` directory.
#' Falls back to bundled-only if no Azure connection is available.
#'
#' @param data_con Azure container object for the `data/` blob. If `NULL`, connects automatically.
#'   Pass `NA` to skip Azure and return bundled templates only.
#' @returns A tibble with columns: `name`, `description`, `source` (`"bundled"` or `"azure"`),
#'   `filename`.
#' @examples
#' \dontrun{
#' eri_template_list()
#'
#' # Bundled only (no Azure connection needed)
#' eri_template_list(data_con = NA)
#' }
#' @export
eri_template_list <- function(data_con = NULL) {
  bundled <- .eri_template_bundled()

  azure_entries <- if (identical(data_con, NA)) {
    list()
  } else {
    tryCatch({
      con <- .eri_template_con(data_con)
      reg <- .eri_template_registry_read(con)
      reg$entries
    }, error = function(e) {
      cli::cli_warn("Could not reach Azure template registry -- showing bundled templates only.")
      list()
    })
  }

  all_entries <- c(bundled, azure_entries)

  empty_result <- tibble::tibble(
    name        = character(),
    description = character(),
    source      = character(),
    filename    = character()
  )

  if (length(all_entries) == 0L) {
    cli::cli_inform("No templates found.")
    return(empty_result)
  }

  .na_chr <- function(x) if (is.null(x) || length(x) == 0L) NA_character_ else as.character(x)

  tibble::tibble(
    name        = vapply(all_entries, function(e) .na_chr(e$name),        character(1L)),
    description = vapply(all_entries, function(e) .na_chr(e$description), character(1L)),
    source      = vapply(all_entries, function(e) .na_chr(e$source),      character(1L)),
    filename    = vapply(all_entries, function(e) .na_chr(e$filename),    character(1L))
  )
}

#### eri_template_pull ####

#' Copy a template to a local destination
#'
#' Copies a named template -- bundled or Azure-hosted -- to `dest`. Bundled templates
#' are copied directly from the package installation. Azure templates are downloaded
#' from `templates/{filename}` in the `data/` blob.
#'
#' @param name `chr` Template name as shown by [eri_template_list()] (without extension).
#' @param dest `chr` Local directory to copy the template into. Defaults to `getwd()`.
#' @param data_con Azure container object for the `data/` blob. If `NULL`, connects automatically.
#' @returns Local path to the copied template (invisibly).
#' @examples
#' \dontrun{
#' eri_template_pull("eri_daily_workflow")
#' eri_template_pull("eri_research_workflow")
#' }
#' @export
eri_template_pull <- function(name, dest = getwd(), data_con = NULL) {
  bundled <- .eri_template_bundled()
  bundled_match <- Filter(function(e) identical(e$name, name), bundled)

  if (length(bundled_match) > 0L) {
    entry     <- bundled_match[[1L]]
    local_out <- file.path(dest, entry$filename)
    file.copy(entry$local_path, local_out, overwrite = TRUE)
    cli::cli_alert_success("Template {.file {entry$filename}} copied to {.path {dest}}.")
    return(invisible(local_out))
  }

  # Try Azure
  con <- .eri_template_con(data_con)
  reg <- .eri_template_registry_read(con)

  azure_match <- Filter(function(e) identical(e$name, name), reg$entries)
  if (length(azure_match) == 0L) {
    cli::cli_abort(
      "Template {.val {name}} not found. Run {.fn eri_template_list} to see available templates."
    )
  }

  entry     <- azure_match[[1L]]
  az_path   <- paste0(.ERI_TEMPLATE_AZURE_DIR, "/", entry$filename)
  local_out <- file.path(dest, entry$filename)
  AzureStor::storage_download(con, az_path, local_out, overwrite = TRUE)

  cli::cli_alert_success("Template {.file {entry$filename}} downloaded to {.path {dest}}.")
  invisible(local_out)
}

#### eri_template_upload ####

#' Upload a custom template to Azure
#'
#' Uploads a local `.qmd` or `.R` template file to `templates/` in the `data/` Azure
#' blob and registers it in `templates/_registry.yaml`. Once uploaded, the template
#' is available to all team members via [eri_template_pull()].
#'
#' @param local_path `chr` Path to the local template file.
#' @param name `chr` Short identifier for the template (without extension, e.g. `"eri_research_workflow"`).
#'   Must not collide with any bundled template name.
#' @param description `chr` Human-readable description of what this template is for.
#' @param data_con Azure container object for the `data/` blob. If `NULL`, connects automatically.
#' @returns The Azure path the template was uploaded to (invisibly).
#' @examples
#' \dontrun{
#' eri_template_upload(
#'   "templates/eri_research_workflow.qmd",
#'   name        = "eri_research_workflow",
#'   description = "Standard epidemiologist research workflow"
#' )
#' }
#' @export
eri_template_upload <- function(local_path, name, description, data_con = NULL) {
  if (!file.exists(local_path)) {
    cli::cli_abort("File not found: {.path {local_path}}")
  }

  ext <- tools::file_ext(local_path)
  if (!ext %in% c("qmd", "R", "r", "Rmd", "rmd")) {
    cli::cli_abort("Only .qmd, .R, and .Rmd templates are supported.")
  }

  bundled <- .eri_template_bundled()
  if (any(vapply(bundled, function(e) identical(e$name, name), logical(1L)))) {
    cli::cli_abort(
      "Template name {.val {name}} conflicts with a bundled template. Choose a different name."
    )
  }

  con      <- .eri_template_con(data_con)
  analyst  <- Sys.getenv("ERI_ANALYST_ID", unset = Sys.info()[["user"]])
  filename <- basename(local_path)
  az_path  <- paste0(.ERI_TEMPLATE_AZURE_DIR, "/", filename)

  .eri_create_azure_dir(con, .ERI_TEMPLATE_AZURE_DIR)
  AzureStor::storage_upload(con, local_path, az_path)

  entry <- list(
    name        = name,
    description = description,
    source      = "azure",
    filename    = filename,
    uploaded_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    uploaded_by = analyst
  )

  reg <- .eri_template_registry_read(con)
  existing <- vapply(reg$entries, function(e) identical(e$name, name), logical(1L))
  if (any(existing)) {
    reg$entries[[which(existing)[[1L]]]] <- entry
  } else {
    reg$entries <- c(reg$entries, list(entry))
  }
  .eri_template_registry_write(reg, con)

  cli::cli_alert_success(
    "Template {.val {name}} uploaded to {.path {az_path}}."
  )
  invisible(az_path)
}
