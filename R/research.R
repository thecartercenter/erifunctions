#### Research project scaffolding ####

.ERI_RESEARCH_AZURE_ROOT <- "research"

#' @keywords internal
.eri_research_con <- function(data_con) {
  if (!is.null(data_con)) return(data_con)
  suppressMessages(
    get_azure_storage_connection(
      storage_name = Sys.getenv("ERIFUNCTIONS_DATA_STORAGE_NAME", unset = "data")
    )
  )
}

#' @keywords internal
.eri_research_yaml_path <- function(path) file.path(path, "research.yaml")

#' @keywords internal
.eri_research_read_manifest <- function(path) {
  yaml_path <- .eri_research_yaml_path(path)
  if (!file.exists(yaml_path)) {
    cli::cli_abort("No {.file research.yaml} found in {.path {path}}. Run {.fn eri_research_init} first.")
  }
  yaml::read_yaml(yaml_path)
}

#' @keywords internal
.eri_research_write_manifest <- function(manifest, path) {
  yaml::write_yaml(manifest, .eri_research_yaml_path(path))
}

#### eri_research_init ####

#' Initialise a new research project
#'
#' Creates the local project scaffold (`data/`, `figs/`, `outputs/` directories plus a
#' `research.yaml` manifest) and the corresponding `research/{project_name}/` directory
#' in the `data/` Azure blob. Run once at the start of a new study.
#'
#' @param project_name `chr` Short identifier for the project (e.g. `"dr_irs_2024"`).
#'   Used as the Azure directory name and the primary key in the manifest.
#' @param country `chr` Country code (e.g. `"dr"`).
#' @param disease `chr` Disease name (e.g. `"malaria"`).
#' @param description `chr` Human-readable description of the research question.
#' @param path `chr` Local directory in which to scaffold the project. Defaults to `getwd()`.
#' @param data_con Azure container object for the `data/` blob. If `NULL`, connects automatically.
#' @param dry_run `lgl` If `TRUE`, print what would be created without writing anything. Default `FALSE`.
#' @returns Path to the `research.yaml` file (invisibly), or `NULL` for `dry_run`.
#' @examples
#' \dontrun{
#' eri_research_init(
#'   project_name = "dr_irs_2024",
#'   country      = "dr",
#'   disease      = "malaria",
#'   description  = "ITS analysis of IRS impact on malaria incidence in Dominican Republic"
#' )
#' }
#' @export
eri_research_init <- function(
    project_name,
    country,
    disease,
    description,
    path     = getwd(),
    data_con = NULL,
    dry_run  = FALSE
) {
  yaml_path <- .eri_research_yaml_path(path)

  if (file.exists(yaml_path)) {
    existing <- yaml::read_yaml(yaml_path)
    if (identical(existing$project_name, project_name)) {
      cli::cli_abort(
        "Project {.val {project_name}} already exists at {.path {path}}. \\
         Use {.fn eri_research_resume} to reconnect."
      )
    }
  }

  azure_path <- paste0(.ERI_RESEARCH_AZURE_ROOT, "/", project_name, "/")
  local_dirs <- file.path(path, c("data", "figs", "outputs"))

  if (dry_run) {
    cli::cli_inform(c(
      "i" = "Dry run -- nothing written.",
      " " = "Would create local dirs: {.path {local_dirs}}",
      " " = "Would write: {.path {yaml_path}}",
      " " = "Would create Azure dir: {.path {azure_path}}"
    ))
    return(invisible(NULL))
  }

  for (d in local_dirs) {
    if (!dir.exists(d)) dir.create(d, recursive = TRUE)
  }

  analyst <- Sys.getenv("ERI_ANALYST_ID", unset = Sys.info()[["user"]])
  manifest <- list(
    project_name   = project_name,
    country        = country,
    disease        = disease,
    description    = description,
    created_at     = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    created_by     = analyst,
    azure_path     = azure_path,
    pulled_data    = list(),
    artifacts_used = list(),
    log            = list(),
    snapshots      = list(),
    outputs        = list(),
    tags           = list()
  )
  .eri_research_write_manifest(manifest, path)

  data_con <- .eri_research_con(data_con)
  .eri_create_azure_dir(data_con, azure_path)

  cli::cli_alert_success(
    "Research project {.val {project_name}} initialised at {.path {path}}."
  )
  cli::cli_inform(c(
    " " = "Local dirs: {.path data/}, {.path figs/}, {.path outputs/}",
    " " = "Manifest:   {.path research.yaml}",
    " " = "Azure:      {.path {azure_path}}"
  ))
  invisible(yaml_path)
}

#### eri_research_resume ####

#' Resume a research project session
#'
#' Reads `research.yaml` from the project root, re-establishes the Azure connection,
#' and prints a session summary (last pull, last log entry, snapshot count). Call this
#' at the top of each work session instead of re-typing project context.
#'
#' @param path `chr` Local project root (must contain `research.yaml`). Defaults to `getwd()`.
#' @param data_con Azure container object for the `data/` blob. If `NULL`, connects automatically.
#' @returns The manifest list (invisibly).
#' @examples
#' \dontrun{
#' eri_research_resume()
#' }
#' @export
eri_research_resume <- function(path = getwd(), data_con = NULL) {
  manifest <- .eri_research_read_manifest(path)
  data_con <- .eri_research_con(data_con)

  last_pull <- if (length(manifest$pulled_data) > 0L) {
    pulls <- manifest$pulled_data
    utils::tail(vapply(pulls, function(p) rlang::`%||%`(p$pulled_at, ""), character(1L)), 1L)
  } else {
    "none"
  }

  last_log <- if (length(manifest$log) > 0L) {
    entries <- manifest$log
    last    <- entries[[length(entries)]]
    paste0("[", last$timestamp, "] ", last$note)
  } else {
    "no entries"
  }

  n_snapshots <- length(manifest$snapshots)

  cli::cli_inform(c(
    "v" = "Project: {.val {manifest$project_name}} ({manifest$country} / {manifest$disease})",
    " " = "Azure:      {.path {manifest$azure_path}}",
    " " = "Last pull:  {last_pull}",
    " " = "Last log:   {last_log}",
    " " = "Snapshots:  {n_snapshots}"
  ))

  invisible(manifest)
}

#### eri_research_log ####

#' Add an entry to the research lab notebook
#'
#' Appends a timestamped free-text note to the `log` section of `research.yaml`.
#' Use this to record decisions, observations, or status updates during analysis.
#'
#' @param note `chr` The text to log.
#' @param path `chr` Local project root (must contain `research.yaml`). Defaults to `getwd()`.
#' @returns `NULL` invisibly.
#' @examples
#' \dontrun{
#' eri_research_log("Ran ITS model -- negative binomial converged. Saving output.")
#' }
#' @export
eri_research_log <- function(note, path = getwd()) {
  manifest <- .eri_research_read_manifest(path)

  entry <- list(
    timestamp = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    note      = note
  )

  manifest$log <- c(manifest$log, list(entry))
  .eri_research_write_manifest(manifest, path)

  cli::cli_alert_success("Log entry added.")
  invisible(NULL)
}

#### eri_research_list ####

#' List all research projects in Azure
#'
#' Returns a tibble of projects under `research/` in the `data/` Azure blob.
#' Each row reflects what was recorded in the project's `research.yaml` at last upload.
#'
#' @param data_con Azure container object for the `data/` blob. If `NULL`, connects automatically.
#' @returns A tibble with columns: `project_name`, `azure_path`.
#' @examples
#' \dontrun{
#' eri_research_list()
#' }
#' @export
eri_research_list <- function(data_con = NULL) {
  data_con <- .eri_research_con(data_con)

  empty_result <- tibble::tibble(
    project_name = character(),
    azure_path   = character()
  )

  all_files <- tryCatch(
    AzureStor::list_storage_files(data_con, .ERI_RESEARCH_AZURE_ROOT, info = "name"),
    error = function(e) character(0L)
  )

  if (length(all_files) == 0L) {
    cli::cli_inform("No research projects found in Azure.")
    return(empty_result)
  }

  # Each project sits one level deep: research/{project_name}/
  project_dirs <- unique(
    sub(paste0("^", .ERI_RESEARCH_AZURE_ROOT, "/([^/]+).*$"), "\\1", all_files)
  )
  project_dirs <- project_dirs[nchar(project_dirs) > 0L]

  if (length(project_dirs) == 0L) {
    cli::cli_inform("No research projects found in Azure.")
    return(empty_result)
  }

  tibble::tibble(
    project_name = project_dirs,
    azure_path   = paste0(.ERI_RESEARCH_AZURE_ROOT, "/", project_dirs, "/")
  )
}

#### eri_research_pull ####

#' Pull data from Azure into a research project
#'
#' Downloads files from Azure into a local destination and records every pull in
#' `research.yaml` for provenance. Two modes:
#'
#' - **Canonical**: supply `country`, `disease`, and `data_type` to pull from the
#'   standard processed layer (`{country}/{disease}/{data_type}/processed/`).
#' - **Path**: supply `path` to pull any Azure location (e.g. `"data/spatial/dom_admin_boundaries/"`).
#'
#' For non-standard external files not yet in Azure, upload them first with
#' [eri_artifact_upload()], then pull with [eri_artifact_pull()].
#'
#' @param country `chr` or `NULL` Country code (e.g. `"dr"`). Used with `disease` and `data_type`.
#' @param disease `chr` or `NULL` Disease name (e.g. `"malaria"`). Used with `country` and `data_type`.
#' @param data_type `chr` or `NULL` Data type (`"surveillance"`, `"cmr"`, `"odk"`). Used with `country` and `disease`.
#' @param path `chr` or `NULL` Explicit Azure blob path to download from. Mutually exclusive with canonical args.
#' @param dest `chr` or `NULL` Local directory to download files into. Defaults to `data/` inside `getwd()`.
#' @param data_con Azure container object for the `data/` blob. If `NULL`, connects automatically.
#' @returns Character vector of local file paths downloaded (invisibly).
#' @examples
#' \dontrun{
#' # Pull canonical processed surveillance data
#' eri_research_pull(country = "dr", disease = "malaria", data_type = "surveillance")
#'
#' # Pull standard spatial reference files
#' eri_research_pull(path = "spatial/dom_admin_boundaries")
#' }
#' @export
eri_research_pull <- function(
    country   = NULL,
    disease   = NULL,
    data_type = NULL,
    path      = NULL,
    dest      = NULL,
    data_con  = NULL
) {
  has_canonical <- !is.null(country) && !is.null(disease) && !is.null(data_type)
  has_path      <- !is.null(path)

  if (!has_canonical && !has_path) {
    cli::cli_abort(
      "Supply either {.arg country} + {.arg disease} + {.arg data_type}, or {.arg path}."
    )
  }
  if (has_canonical && has_path) {
    cli::cli_abort(
      "Supply either canonical args ({.arg country}/{.arg disease}/{.arg data_type}) or {.arg path}, not both."
    )
  }

  azure_path <- if (has_canonical) {
    paste(country, disease, data_type, "processed", sep = "/")
  } else {
    path
  }

  data_con   <- .eri_research_con(data_con)
  local_dest <- if (!is.null(dest)) dest else file.path(getwd(), "data")
  if (!dir.exists(local_dest)) dir.create(local_dest, recursive = TRUE)

  # A path may point at a single file (e.g. a spatial boundary) or a directory of
  # files. Handle the single-file case directly; otherwise list the directory.
  is_single_file <- isTRUE(tryCatch(
    AzureStor::storage_file_exists(data_con, azure_path),
    error = function(e) FALSE
  ))

  if (is_single_file) {
    file_names <- azure_path
  } else {
    all_names <- tryCatch(
      AzureStor::list_storage_files(data_con, azure_path, info = "name"),
      error = function(e) {
        cli::cli_abort("Could not list {.path {azure_path}}: {conditionMessage(e)}")
      }
    )

    # Keep only files (no trailing slash / no directory entries)
    file_names <- all_names[!grepl("/$", all_names) & nchar(basename(all_names)) > 0L]

    if (length(file_names) == 0L) {
      cli::cli_warn("No files found at {.path {azure_path}}.")
      return(invisible(character(0L)))
    }
  }

  # Update-with-archival (issue #148): if a target file already exists locally, move the prior
  # version into <dest>/_archive/<timestamp>/ before overwriting, so an update is reversible and
  # snapshots/tags can still capture the superseded input.
  target_paths <- file.path(local_dest, basename(file_names))
  existing     <- target_paths[file.exists(target_paths)]
  archived_to  <- NULL
  if (length(existing) > 0L) {
    archived_to <- file.path(local_dest, "_archive", format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC"))
    dir.create(archived_to, recursive = TRUE, showWarnings = FALSE)
    file.rename(existing, file.path(archived_to, basename(existing)))
    cli::cli_alert_info("Archived {length(existing)} prior version{?s} to {.path {archived_to}}.")
  }

  local_paths <- vapply(file_names, function(f) {
    lpath <- file.path(local_dest, basename(f))
    AzureStor::storage_download(data_con, f, lpath, overwrite = TRUE)
    lpath
  }, character(1L), USE.NAMES = FALSE)

  research_yaml <- file.path(getwd(), "research.yaml")
  if (file.exists(research_yaml)) {
    .eri_research_record_pull(azure_path, local_paths, local_dest, research_yaml, archived_to = archived_to)
  }

  cli::cli_alert_success(
    "Pulled {length(local_paths)} file{?s} from {.path {azure_path}} to {.path {local_dest}}."
  )
  invisible(local_paths)
}

#' @keywords internal
.eri_research_record_pull <- function(azure_path, local_paths, local_dest, yaml_path, archived_to = NULL) {
  tryCatch({
    manifest <- yaml::read_yaml(yaml_path)
    if (is.null(manifest$pulled_data)) manifest$pulled_data <- list()

    now <- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
    entry <- list(
      azure_path = azure_path,
      files      = as.list(basename(local_paths)),
      local_dest = local_dest,
      pulled_at  = now
    )
    if (!is.null(archived_to)) entry$archived_prev <- archived_to

    # Dedup (issue #9): a re-pull of the same source REPLACES its record rather than appending a
    # duplicate; carry forward the first-pull time and an update counter for provenance.
    same <- vapply(manifest$pulled_data, function(e) {
      identical(e$azure_path, azure_path) && identical(e$local_dest, local_dest)
    }, logical(1L))
    if (any(same)) {
      prev <- manifest$pulled_data[[which(same)[1L]]]
      entry$first_pulled_at <- rlang::`%||%`(prev$first_pulled_at, prev$pulled_at)
      entry$update_count    <- rlang::`%||%`(prev$update_count, 0L) + 1L
      # Drop ALL existing records for this source (collapses any pre-existing duplicates), then
      # append the single current one.
      manifest$pulled_data <- c(manifest$pulled_data[!same], list(entry))
    } else {
      manifest$pulled_data <- c(manifest$pulled_data, list(entry))
    }
    yaml::write_yaml(manifest, yaml_path)
  }, error = function(e) {
    cli::cli_warn("Could not update research.yaml: {conditionMessage(e)}")
  })
}

#### eri_research_status ####

#' Report the data state of a research project
#'
#' Summarises every input the project depends on -- pulls (with update counts and whether a prior
#' version was archived) and artifacts -- plus the output/snapshot/tag counts and any boundary
#' promotions the project has made to the canonical `/spatial` store, from `research.yaml`.
#' One place to answer "what does this study depend on, and is any of it stale?". With
#' `check_remote = TRUE`, flags inputs whose Azure source is newer than the local copy.
#'
#' @param path `chr` Local project root (must contain `research.yaml`). Defaults to `getwd()`.
#' @param check_remote `lgl` If `TRUE`, compare each pulled input against its Azure source and flag
#'   newer upstream versions (best-effort; needs a connection). Default `FALSE`.
#' @param data_con Azure container for the `data/` blob; used only when `check_remote`. If `NULL`, connects automatically.
#' @returns A tibble of tracked inputs (invisibly).
#' @examples
#' \dontrun{
#' eri_research_status()
#' eri_research_status(check_remote = TRUE)
#' }
#' @export
eri_research_status <- function(path = getwd(), check_remote = FALSE, data_con = NULL) {
  `%||%`   <- rlang::`%||%`
  manifest <- .eri_research_read_manifest(path)
  pulls    <- manifest$pulled_data %||% list()
  arts     <- manifest$artifacts_used %||% list()
  promos   <- manifest$promoted_data %||% list()

  inputs <- tibble::tibble(
    kind      = c(rep("pull", length(pulls)), rep("artifact", length(arts))),
    source    = c(vapply(pulls, function(e) e$azure_path %||% NA_character_, character(1L)),
                  vapply(arts,  function(e) e$azure_path %||% e$name %||% NA_character_, character(1L))),
    pulled_at = c(vapply(pulls, function(e) e$pulled_at %||% NA_character_, character(1L)),
                  vapply(arts,  function(e) e$pulled_at %||% NA_character_, character(1L))),
    updates   = c(vapply(pulls, function(e) as.integer(e$update_count %||% 0L), integer(1L)),
                  rep(NA_integer_, length(arts))),
    archived  = c(vapply(pulls, function(e) !is.null(e$archived_prev), logical(1L)),
                  rep(NA, length(arts)))
  )

  if (isTRUE(check_remote) && length(pulls) > 0L) {
    con <- .eri_research_con(data_con)
    avail <- rep(NA, nrow(inputs))
    for (i in seq_along(pulls)) {
      ap <- pulls[[i]]$azure_path; pat <- pulls[[i]]$pulled_at
      avail[i] <- tryCatch({
        info <- AzureStor::list_storage_files(con, ap, info = "all")
        rm_mtime <- suppressWarnings(max(as.POSIXct(info$lastModified), na.rm = TRUE))
        !is.na(rm_mtime) && rm_mtime > as.POSIXct(pat, tz = "UTC")
      }, error = function(e) NA)
    }
    inputs$update_available <- avail
  }

  cli::cli_h1("Research project: {manifest$project_name} ({manifest$country}/{manifest$disease})")
  cli::cli_inform(c(
    "*" = "{nrow(inputs)} tracked input{?s} ({sum(inputs$kind == 'pull')} pull{?s}, {sum(inputs$kind == 'artifact')} artifact{?s})",
    "*" = "{length(manifest$outputs %||% list())} output{?s}, {length(manifest$snapshots %||% list())} snapshot{?s}, {length(manifest$tags %||% list())} tag{?s}, {length(promos)} promotion{?s}"
  ))
  if (nrow(inputs) > 0L) print(inputs)
  # Promotions are outbound (project -> canonical /spatial), so they are summarised here rather
  # than mixed into the inbound `inputs` table.
  if (length(promos) > 0L) {
    cli::cli_inform("Promotions to canonical:")
    for (p in promos) {
      cli::cli_inform(
        "  {.val {p$country}} adm{p$level} -> {.path {p$azure_path}} ({p$promoted_at}{if (isTRUE(p$replaced)) ', replaced' else ''})"
      )
    }
  }
  invisible(inputs)
}

#### eri_research_upload_figure ####

#' Upload a figure to the research project outputs in Azure
#'
#' Uploads a local figure file to `research/{project_name}/outputs/figs/` in the
#' `data/` Azure blob and records the upload in `research.yaml`.
#'
#' @param local_path `chr` Path to the local figure file (e.g. `"figs/its_model.png"`).
#' @param caption `chr` or `NULL` Optional caption describing the figure.
#' @param path `chr` Local project root (must contain `research.yaml`). Defaults to `getwd()`.
#' @param data_con Azure container object for the `data/` blob. If `NULL`, connects automatically.
#' @returns Azure path the figure was uploaded to (invisibly).
#' @examples
#' \dontrun{
#' eri_research_upload_figure("figs/its_model.png", caption = "ITS model -- DR malaria 2024")
#' }
#' @export
eri_research_upload_figure <- function(
    local_path,
    caption  = NULL,
    path     = getwd(),
    data_con = NULL
) {
  if (!file.exists(local_path)) {
    cli::cli_abort("File not found: {.path {local_path}}")
  }
  manifest  <- .eri_research_read_manifest(path)
  data_con  <- .eri_research_con(data_con)
  analyst   <- Sys.getenv("ERI_ANALYST_ID", unset = Sys.info()[["user"]])

  filename   <- basename(local_path)
  azure_path <- paste0(manifest$azure_path, "outputs/figs/", filename)

  dir_path <- paste0(manifest$azure_path, "outputs/figs")
  .eri_create_azure_dir(data_con, dir_path)
  AzureStor::storage_upload(data_con, local_path, azure_path)

  entry <- list(
    type        = "figure",
    filename    = filename,
    azure_path  = azure_path,
    caption     = if (is.null(caption)) NA_character_ else caption,
    uploaded_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    uploaded_by = analyst
  )
  if (is.null(manifest$outputs)) manifest$outputs <- list()
  manifest$outputs <- c(manifest$outputs, list(entry))
  .eri_research_write_manifest(manifest, path)

  cli::cli_alert_success("Figure {.file {filename}} uploaded to {.path {azure_path}}.")
  invisible(azure_path)
}

#### eri_research_upload_output ####

#' Upload an R object to the research project outputs in Azure
#'
#' Serializes an R object to a `.qs2` file and uploads it to
#' `research/{project_name}/outputs/` in the `data/` Azure blob. Records the upload
#' in `research.yaml`.
#'
#' @param obj R object to serialize and upload.
#' @param filename `chr` Name for the output file (include `.qs2` extension, e.g. `"its_model.qs2"`).
#' @param path `chr` Local project root (must contain `research.yaml`). Defaults to `getwd()`.
#' @param data_con Azure container object for the `data/` blob. If `NULL`, connects automatically.
#' @returns Azure path the object was uploaded to (invisibly).
#' @examples
#' \dontrun{
#' eri_research_upload_output(model_fit, "its_model.qs2")
#' }
#' @export
eri_research_upload_output <- function(
    obj,
    filename,
    path     = getwd(),
    data_con = NULL
) {
  manifest  <- .eri_research_read_manifest(path)
  data_con  <- .eri_research_con(data_con)
  analyst   <- Sys.getenv("ERI_ANALYST_ID", unset = Sys.info()[["user"]])

  tmp <- tempfile(fileext = ".qs2")
  withr::defer(unlink(tmp))
  qs2::qs_save(obj, tmp)

  azure_path <- paste0(manifest$azure_path, "outputs/", filename)
  dir_path   <- paste0(manifest$azure_path, "outputs")
  .eri_create_azure_dir(data_con, dir_path)
  AzureStor::storage_upload(data_con, tmp, azure_path)

  entry <- list(
    type        = "object",
    filename    = filename,
    azure_path  = azure_path,
    uploaded_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    uploaded_by = analyst
  )
  if (is.null(manifest$outputs)) manifest$outputs <- list()
  manifest$outputs <- c(manifest$outputs, list(entry))
  .eri_research_write_manifest(manifest, path)

  cli::cli_alert_success("Output {.file {filename}} uploaded to {.path {azure_path}}.")
  invisible(azure_path)
}

#### eri_research_snapshot ####

#' Snapshot the full research project data directory to Azure
#'
#' Uploads every file in the local `data/` directory to
#' `research/{project_name}/snapshots/{timestamp}/` in the `data/` Azure blob,
#' writes a `_manifest.yaml` alongside listing what was included, and records
#' the snapshot in `research.yaml`.
#'
#' Use this to freeze a reproducible checkpoint of all input data before a major
#' analysis run or before sharing results.
#'
#' @param label `chr` or `NULL` Optional short label for this snapshot (e.g. `"pre-ITS-run"`).
#' @param path `chr` Local project root (must contain `research.yaml` and `data/`). Defaults to `getwd()`.
#' @param data_con Azure container object for the `data/` blob. If `NULL`, connects automatically.
#' @returns Azure snapshot path (invisibly).
#' @examples
#' \dontrun{
#' eri_research_snapshot(label = "pre-ITS-run")
#' }
#' @export
eri_research_snapshot <- function(label = NULL, path = getwd(), data_con = NULL) {
  manifest <- .eri_research_read_manifest(path)
  analyst  <- Sys.getenv("ERI_ANALYST_ID", unset = Sys.info()[["user"]])

  data_dir <- file.path(path, "data")
  if (!dir.exists(data_dir)) {
    cli::cli_abort("No {.path data/} directory found in {.path {path}}. Nothing to snapshot.")
  }

  local_files <- list.files(data_dir, recursive = TRUE, full.names = TRUE)
  if (length(local_files) == 0L) {
    cli::cli_warn("The {.path data/} directory is empty -- snapshot skipped.")
    return(invisible(NULL))
  }

  data_con <- .eri_research_con(data_con)

  timestamp    <- format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")
  snap_path    <- paste0(manifest$azure_path, "snapshots/", timestamp, "/")

  # Upload each file preserving relative path under data/
  rel_paths <- character(length(local_files))
  for (i in seq_along(local_files)) {
    rel      <- sub(paste0("^", normalizePath(data_dir, winslash = "/"), "/?"), "",
                    normalizePath(local_files[[i]], winslash = "/"))
    az_dest  <- paste0(snap_path, rel)
    AzureStor::storage_upload(data_con, local_files[[i]], az_dest)
    rel_paths[[i]] <- rel
  }

  # Write snapshot manifest to Azure
  snap_manifest <- list(
    project_name  = manifest$project_name,
    snapshot_at   = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    created_by    = analyst,
    label         = if (is.null(label)) NA_character_ else label,
    files         = as.list(rel_paths)
  )
  tmp <- tempfile(fileext = ".yaml")
  withr::defer(unlink(tmp))
  yaml::write_yaml(snap_manifest, tmp)
  AzureStor::storage_upload(data_con, tmp, paste0(snap_path, "_manifest.yaml"))

  # Record in research.yaml
  snap_entry <- list(
    timestamp  = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    label      = if (is.null(label)) NA_character_ else label,
    azure_path = snap_path,
    file_count = length(local_files)
  )
  if (is.null(manifest$snapshots)) manifest$snapshots <- list()
  manifest$snapshots <- c(manifest$snapshots, list(snap_entry))
  .eri_research_write_manifest(manifest, path)

  cli::cli_alert_success(
    "Snapshot of {length(local_files)} file{?s} saved to {.path {snap_path}}."
  )
  invisible(snap_path)
}

#### eri_research_tag ####

#' Capture git provenance for a local analysis directory
#'
#' Returns the HEAD commit, branch, origin remote, and a dirty-working-tree flag
#' for the git repository at `path`. All fields are `NA` when `git` is unavailable
#' or `path` is not inside a work tree.
#'
#' @param path `chr` Directory to inspect.
#' @returns A list with `sha`, `branch`, `remote`, `dirty`.
#' @keywords internal
.eri_git_info <- function(path) {
  na_info <- list(sha = NA_character_, branch = NA_character_,
                  remote = NA_character_, dirty = NA)
  if (!nzchar(Sys.which("git"))) return(na_info)

  git_out <- function(args) {
    out <- tryCatch(
      suppressWarnings(system2("git", c("-C", path, args), stdout = TRUE, stderr = FALSE)),
      error = function(e) character(0)
    )
    if (length(out) == 0L) NA_character_ else out[[1L]]
  }

  if (!identical(git_out(c("rev-parse", "--is-inside-work-tree")), "true")) {
    return(na_info)
  }

  status <- tryCatch(
    suppressWarnings(system2("git", c("-C", path, "status", "--porcelain"),
                             stdout = TRUE, stderr = FALSE)),
    error = function(e) character(0)
  )
  list(
    sha    = git_out(c("rev-parse", "HEAD")),
    branch = git_out(c("rev-parse", "--abbrev-ref", "HEAD")),
    remote = git_out(c("config", "--get", "remote.origin.url")),
    dirty  = length(status) > 0L
  )
}

#' Tag a reproducible, citable version of a research project
#'
#' Binds a frozen data snapshot, the analysis code commit (the research project's
#' git SHA), the recorded input provenance, and the output manifest into a single
#' immutable **tag** at `research/{project_name}/tags/{label}/_tag.yaml` in the
#' `data/` Azure blob, and records it in `research.yaml`.
#'
#' A tag answers "what produced this published result?" -- which data
#' ([eri_research_snapshot()]), which code (git commit), which inputs
#' ([eri_research_pull()] / [eri_artifact_pull()] provenance), and which outputs.
#' Because data is bound by a snapshot and code by a commit SHA, a tagged analysis
#' can be reproduced from a citation -- including across data updates, by tagging
#' again after re-pulling refreshed data.
#'
#' If no snapshot exists yet, one is created automatically. Tags are immutable:
#' tagging an already-used label is an error.
#'
#' @param label `chr` Short, unique tag name (e.g. `"lancet-2026-submission"`).
#' @param description `chr` or `NULL` Optional note describing this version.
#' @param snapshot `chr` or `NULL` Which snapshot to bind: a snapshot label or
#'   timestamp already in `research.yaml`. If `NULL`, the most recent snapshot is
#'   used, or a fresh one is created if none exist.
#' @param path `chr` Local project root (must contain `research.yaml`). Defaults to `getwd()`.
#' @param data_con Azure container object for the `data/` blob. If `NULL`, connects automatically.
#' @returns The Azure path of the tag file (invisibly).
#' @examples
#' \dontrun{
#' eri_research_snapshot(label = "final-data")
#' eri_research_tag("lancet-2026-submission", description = "Figures 1-3, Table 2")
#' }
#' @export
eri_research_tag <- function(label, description = NULL, snapshot = NULL,
                             path = getwd(), data_con = NULL) {
  if (missing(label) || !is.character(label) || length(label) != 1L || !nzchar(label)) {
    cli::cli_abort("{.arg label} must be a single non-empty string.")
  }
  manifest <- .eri_research_read_manifest(path)
  analyst  <- Sys.getenv("ERI_ANALYST_ID", unset = Sys.info()[["user"]])
  data_con <- .eri_research_con(data_con)

  tag_dir  <- paste0(manifest$azure_path, "tags/", label, "/")
  tag_file <- paste0(tag_dir, "_tag.yaml")
  # NOTE: this check-then-write is a TOCTOU race -- two sessions tagging the same
  # label concurrently could both pass here. Acceptable for the single-analyst
  # pilot; Phase 2 (ADR-0002) replaces it with a conditional/If-Match upload, which
  # is also what hardens the read-modify-write of the manifest `tags` list below.
  if (AzureStor::storage_file_exists(data_con, tag_file)) {
    cli::cli_abort(c(
      "Tag {.val {label}} already exists for project {.val {manifest$project_name}}.",
      "i" = "Tags are immutable -- choose a new label for a new version."
    ))
  }

  # Capture analysis code provenance BEFORE resolving the snapshot: an auto-created
  # snapshot writes research.yaml into the tree, which would otherwise make a clean
  # checkout look "dirty" and fire a spurious warning.
  git <- .eri_git_info(path)
  if (is.na(git$sha)) {
    cli::cli_warn(c(
      "No git commit found for the analysis at {.path {path}}.",
      "i" = "Research projects should be git repositories (ADR-0006) so the code is pinned."
    ))
  } else if (isTRUE(git$dirty)) {
    cli::cli_warn(c(
      "The analysis repo has uncommitted changes.",
      "i" = "The tag records commit {.val {substr(git$sha, 1L, 8L)}}, but the working tree differs -- commit first for a faithful tag."
    ))
  }

  # Resolve the snapshot to bind (create one if none exist).
  snaps <- if (is.null(manifest$snapshots)) list() else manifest$snapshots
  if (length(snaps) == 0L) {
    cli::cli_inform("No snapshot found -- creating one to bind to this tag.")
    eri_research_snapshot(label = paste0("tag-", label), path = path, data_con = data_con)
    manifest <- .eri_research_read_manifest(path)
    snaps    <- manifest$snapshots
    snap     <- snaps[[length(snaps)]]
  } else if (is.null(snapshot)) {
    snap <- snaps[[length(snaps)]]
  } else {
    hit <- Filter(
      function(s) identical(s$label, snapshot) || identical(s$timestamp, snapshot),
      snaps
    )
    if (length(hit) == 0L) {
      cli::cli_abort("No snapshot matching {.val {snapshot}} in {.file research.yaml}.")
    }
    snap <- hit[[length(hit)]]
  }

  in_prov  <- c(
    if (is.null(manifest$pulled_data))    list() else manifest$pulled_data,
    if (is.null(manifest$artifacts_used)) list() else manifest$artifacts_used
  )
  tag_record <- list(
    label        = label,
    project_name = manifest$project_name,
    tagged_at    = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    tagged_by    = analyst,
    description  = if (is.null(description)) NA_character_ else description,
    snapshot     = list(
      label      = snap$label,
      timestamp  = snap$timestamp,
      azure_path = snap$azure_path,
      file_count = snap$file_count
    ),
    code         = list(sha = git$sha, branch = git$branch,
                        remote = git$remote, dirty = git$dirty),
    inputs       = in_prov,
    outputs      = if (is.null(manifest$outputs)) list() else manifest$outputs
  )

  .eri_create_azure_dir(data_con, tag_dir)
  tmp <- tempfile(fileext = ".yaml")
  withr::defer(unlink(tmp))
  yaml::write_yaml(tag_record, tmp)
  AzureStor::storage_upload(data_con, tmp, tag_file)

  tag_entry <- list(
    label       = label,
    tagged_at   = tag_record$tagged_at,
    azure_path  = tag_dir,
    snapshot_at = snap$timestamp,
    code_sha    = git$sha
  )
  if (is.null(manifest$tags)) manifest$tags <- list()
  manifest$tags <- c(manifest$tags, list(tag_entry))
  .eri_research_write_manifest(manifest, path)

  cli::cli_alert_success(
    "Tagged {.val {label}}: snapshot {.val {snap$timestamp}} + code {.val {if (is.na(git$sha)) 'none' else substr(git$sha, 1L, 8L)}}."
  )
  invisible(tag_file)
}

#### eri_research_scaffold ####

#' Scaffold a new research-project repository
#'
#' Creates a standalone analysis-project skeleton (ADR-0006) at `dest/name/`: a README,
#' an `analysis/` directory seeded with the research-workflow template, a data-safe
#' `.gitignore`, a minimal reproducibility CI workflow, and the standard research scaffold
#' (`data/`, `figs/`, `outputs/`, `research.yaml`) via [eri_research_init()].
#'
#' Each research project is its own git repository that depends on `erifunctions` -- analysis
#' code does not live in the package. After scaffolding, the analyst initialises version
#' control and `renv` (see the generated README), sources data with provenance
#' ([eri_research_pull()] / [eri_spatial_load()]), and freezes citable versions with
#' [eri_research_tag()].
#'
#' @param name `chr` Project name; also the new directory name (e.g. `"dr_irs_2024"`).
#' @param country `chr` Country code (e.g. `"dr"`).
#' @param disease `chr` Disease name (e.g. `"malaria"`).
#' @param description `chr` One-line description of the research question.
#' @param dest `chr` Parent directory in which to create `name/`. Defaults to `getwd()`.
#' @param data_con Azure container object for the `data/` blob. If `NULL`, connects automatically.
#' @returns Path to the created project directory (invisibly).
#' @examples
#' \dontrun{
#' eri_research_scaffold(
#'   "dr_irs_2024", country = "dr", disease = "malaria",
#'   description = "ITS analysis of IRS impact on malaria incidence in the DR",
#'   dest = "~/studies"
#' )
#' }
#' @export
eri_research_scaffold <- function(name, country, disease, description,
                                  dest = getwd(), data_con = NULL) {
  if (missing(name) || !is.character(name) || length(name) != 1L || !nzchar(name)) {
    cli::cli_abort("{.arg name} must be a single non-empty string.")
  }
  if (missing(country) || !is.character(country) || length(country) != 1L || !nzchar(country)) {
    cli::cli_abort("{.arg country} must be a single non-empty string.")
  }
  if (missing(disease) || !is.character(disease) || length(disease) != 1L || !nzchar(disease)) {
    cli::cli_abort("{.arg disease} must be a single non-empty string.")
  }
  if (missing(description) || !is.character(description) || length(description) != 1L || !nzchar(description)) {
    cli::cli_abort("{.arg description} must be a single non-empty string.")
  }
  dest <- sub("[/\\\\]+$", "", dest)   # tolerate a trailing slash so we don't build `dest//name`
  repo_dir <- file.path(dest, name)
  if (dir.exists(repo_dir) && length(list.files(repo_dir, all.files = TRUE, no.. = TRUE)) > 0L) {
    cli::cli_abort("{.path {repo_dir}} already exists and is not empty.")
  }
  dir.create(file.path(repo_dir, "analysis"), recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(repo_dir, ".github", "workflows"), recursive = TRUE, showWarnings = FALSE)

  # Seed analysis/ with the bundled research-workflow template.
  tmpl <- system.file("templates/eri_research_workflow.qmd", package = "erifunctions")
  if (nzchar(tmpl)) {
    file.copy(tmpl, file.path(repo_dir, "analysis", "workflow.qmd"), overwrite = TRUE)
  }

  writeLines(c(
    paste0("# ", name),
    "",
    paste0(description, " (", country, " / ", disease, ")."),
    "",
    "Research project built on [erifunctions](https://github.com/thecartercenter/erifunctions).",
    "Each study is its own repository depending on the package (ADR-0006).",
    "",
    "## Setup",
    "",
    "This study is its own version-controlled repository (ADR-0006):",
    "",
    "```sh",
    "git init",
    "```",
    "",
    "```r",
    "install.packages(\"renv\")",
    "renv::init()",
    "renv::install(\"thecartercenter/erifunctions\")",
    "renv::snapshot()   # commit renv.lock -- this also activates the CI reproducibility check",
    "```",
    "",
    "Then configure Azure credentials in `.Renviron` (see the erifunctions README).",
    "",
    "## Structure",
    "",
    "- `analysis/` -- analysis code; start from `analysis/workflow.qmd`.",
    "- `data/` -- inputs sourced via erifunctions (`eri_research_pull()`,",
    "  `eri_spatial_load(cache = TRUE)`). **Gitignored** -- never commit data.",
    "- `figs/`, `outputs/` -- results; upload with `eri_research_upload_*()`. Gitignored.",
    "- `research.yaml` -- provenance manifest / lab notebook.",
    "",
    "## Reproducibility",
    "",
    "Source data through erifunctions so provenance lands in `research.yaml`, then freeze a",
    "citable version with `eri_research_tag()`. Commit `renv.lock` so the package versions are",
    "pinned. Do **not** commit `data/`."
  ), file.path(repo_dir, "README.md"))

  writeLines(c(
    "# Data must never be committed (Carter Center data policy)",
    "data/",
    "outputs/",
    "figs/",
    "",
    "# R session / credentials",
    ".Rproj.user/",
    ".Rhistory",
    ".RData",
    ".Renviron",
    "",
    "# renv: keep renv.lock + renv/activate.R, ignore the local library",
    "renv/library/",
    "renv/local/",
    "renv/cellar/",
    "renv/staging/"
  ), file.path(repo_dir, ".gitignore"))

  writeLines(c(
    "# Reproducibility check: once renv.lock is committed, restore it and confirm erifunctions",
    "# loads. Inert (passes) until a lockfile exists. Does NOT run the analysis (that needs",
    "# Azure credentials + data).",
    "on: [push, pull_request]",
    "name: reproducibility-check",
    "jobs:",
    "  renv:",
    "    runs-on: ubuntu-latest",
    "    steps:",
    "      - uses: actions/checkout@v5",
    "      - id: lock",
    "        run: |",
    "          if [ -f renv.lock ]; then echo \"present=true\" >> \"$GITHUB_OUTPUT\"; else echo \"present=false\" >> \"$GITHUB_OUTPUT\"; fi",
    "      - if: steps.lock.outputs.present == 'true'",
    "        uses: r-lib/actions/setup-r@v2",
    "      - if: steps.lock.outputs.present == 'true'",
    "        uses: r-lib/actions/setup-renv@v2",
    "      - if: steps.lock.outputs.present == 'true'",
    "        name: erifunctions loads from the pinned environment",
    "        run: Rscript -e 'library(erifunctions); cat(\"environment OK\\n\")'",
    "      - if: steps.lock.outputs.present != 'true'",
    "        run: echo 'No renv.lock yet -- run renv::init()/renv::snapshot() and commit it to enable this check.'"
  ), file.path(repo_dir, ".github", "workflows", "ci.yaml"))

  # Standard research scaffold (data/figs/outputs + research.yaml + Azure dir). If init fails
  # (e.g. Azure creds), make the partial-scaffold state and recovery path explicit.
  tryCatch(
    eri_research_init(name, country, disease, description, path = repo_dir, data_con = data_con),
    error = function(e) {
      cli::cli_abort(c(
        "Repo skeleton created at {.path {repo_dir}}, but research-project init failed: {conditionMessage(e)}",
        "i" = "Fix the cause (often Azure auth/RBAC), then either finish in place by running {.fn eri_research_init} from the project dir, or start clean: {.code unlink('{repo_dir}', recursive = TRUE)} then re-run {.fn eri_research_scaffold}."
      ))
    }
  )

  cli::cli_alert_success("Scaffolded research project {.val {name}} at {.path {repo_dir}}.")
  cli::cli_inform(c(
    " " = "Next: {.code cd {name}}, then {.code git init} and {.code renv::init()} (see README)."
  ))
  invisible(repo_dir)
}

