# DAL - Data Access Layer

# Defaults for interactive (browser) auth so analysts/Epis configure nothing. None of these
# are secrets: a tenant id and a storage-account URL are non-sensitive identifiers (access is
# gated by AAD + RBAC). The service-principal *secret* is the only credential that must never
# be committed, and it stays in env vars. All three below are overridable via env var.
#
# - app_id: Microsoft's first-party Azure CLI public client -- pre-consented in every tenant
#   and able to get delegated tokens for BOTH Azure Storage (https://storage.azure.com/) and
#   Microsoft Graph (SharePoint/Teams), so one interactive login covers every resource.
# - tenant_id: the TCC ERI (RB/LF/SCH/MAL) Entra tenant.
# - resource_endpoint: the `eridev` ADLS Gen2 (Data Lake) endpoint where the ERI team works.
#   AzureStor auto-detects ADLS from the `dfs.` host; the same account's blob API would be at
#   https://eridev.blob.core.windows.net/ if a blob endpoint is ever needed.
.ERI_DEFAULT_APP_ID            <- "04b07795-8ddb-461a-bbee-02f9e1bf7b46"
.ERI_DEFAULT_TENANT_ID         <- "16decddb-28ac-4bea-8fc9-5844aadea669"
.ERI_DEFAULT_RESOURCE_ENDPOINT <- "https://eridev.dfs.core.windows.net/"

#### 1) Utility functions ####

#' Ensure an Azure directory exists, creating any missing parents.
#'
#' ADLS Gen2 rejects a trailing slash in directory operations (HTTP 400, "the request URI is
#' invalid") and does not reliably create intermediate parents, so we strip trailing slashes and
#' create each level of the path that is missing. On flat blob storage these are cheap no-ops.
#' This is the canonical directory-creation primitive: [azure_io()]'s `"create"` op and every
#' nested-path write site (`research.R`, `artifacts.R`, `catalog.R`, `odk_registry.R`,
#' `onboarding.R`, `cmr.R`, `templates.R`) route through it rather than calling
#' `AzureStor::create_storage_dir()` directly.
#' @param azcontainer Azure container object.
#' @param path `chr` Directory path to ensure exists.
#' @returns The trimmed path (invisibly).
#' @keywords internal
.eri_create_azure_dir <- function(azcontainer, path) {
  parts <- strsplit(sub("/+$", "", path), "/", fixed = TRUE)[[1]]
  parts <- parts[nzchar(parts)]
  for (i in seq_along(parts)) {
    level <- paste(parts[seq_len(i)], collapse = "/")
    if (!AzureStor::storage_dir_exists(azcontainer, level)) {
      AzureStor::create_storage_dir(azcontainer, level)
    }
  }
  invisible(sub("/+$", "", path))
}

#### Blob transfer helpers (clean console output) ####
#
# AzureStor prints its own byte progress bar for every transfer. In a loop (e.g. snapshotting 17
# files) these stack into dozens of anonymous bars that look endless and uninformative to a
# non-developer. These helpers are the single path all uploads/downloads route through: they
# suppress AzureStor's native bar and let us render clean `cli` output instead. The bar is kept
# only for a genuinely large single file (`progress = TRUE`, e.g. the ~100 MB LandScan raster),
# where byte progress reassures the user the transfer is alive.

#' Upload one local file to Azure (native progress bar suppressed unless `progress`).
#' @keywords internal
.eri_blob_write <- function(con, src, dest, progress = FALSE) {
  withr::local_options(azure_storage_progress_bar = isTRUE(progress))
  AzureStor::storage_upload(con, src, dest)
  invisible(dest)
}

#' Download one Azure file to a local path (native progress bar suppressed unless `progress`).
#' @keywords internal
.eri_blob_read <- function(con, src, dest, overwrite = TRUE, progress = FALSE) {
  withr::local_options(azure_storage_progress_bar = isTRUE(progress))
  AzureStor::storage_download(con, src, dest, overwrite = overwrite)
  invisible(dest)
}

#' Transfer many files with a single, informative cli progress bar.
#'
#' Replaces a stack of per-file AzureStor bars with one transient bar that names the current file
#' and shows `i/n`. The caller prints the headline summary afterwards.
#' @param direction `"upload"` (srcs = local paths, dests = Azure paths) or `"download"`
#'   (srcs = Azure paths, dests = local paths).
#' @keywords internal
.eri_blob_transfer_many <- function(con, srcs, dests, direction = c("upload", "download")) {
  direction <- match.arg(direction)
  n <- length(dests)
  if (n == 0L) return(invisible(dests))
  withr::local_options(azure_storage_progress_bar = FALSE)

  verb      <- if (direction == "upload") "Uploading" else "Downloading"
  names_all <- basename(dests)
  cur_name  <- names_all[[1L]]   # referenced by the format; updated each iteration

  cli::cli_progress_bar(
    format = paste0(
      "{cli::pb_spin} ", verb, " {.file {cur_name}} ",
      "{cli::pb_bar} {cli::pb_current}/{cli::pb_total}"
    ),
    total = n, clear = TRUE
  )
  for (i in seq_len(n)) {
    cur_name <- names_all[[i]]
    if (direction == "upload") {
      AzureStor::storage_upload(con, srcs[[i]], dests[[i]])
    } else {
      AzureStor::storage_download(con, srcs[[i]], dests[[i]], overwrite = TRUE)
    }
    cli::cli_progress_update()
  }
  invisible(dests)
}

#' Validate connection to Azure
#'
#' Generate token which connects to TCC Azure resources and
#' validates that the individual still has access.
#'
#' @param app_id `str` Application (client) ID. Defaults to the `ERIFUNCTIONS_APP_ID` env var,
#' or -- when unset -- Microsoft's first-party Azure CLI public client
#' (`"04b07795-8ddb-461a-bbee-02f9e1bf7b46"`), so interactive auth works with no per-user setup.
#' @param tenant_id `str` Azure tenant. Defaults to the `ERIFUNCTIONS_TENANT_ID` env var, or the
#' TCC ERI Entra tenant when unset.
#' @param resource_endpoint `str` Storage endpoint URL. Defaults to the
#' `ERIFUNCTIONS_RESOURCE_ENDPOINT` env var, or the team `eridev` ADLS endpoint when unset.
#' @param storage_name `str` Name of the storage blob.
#' Defaults to `Sys.getenv("ERIFUNCTIONS_STORAGE_NAME")`.
#' @param auth `str` Authorization type defaults to `"authorization_code"`,
#' this can be changed if you have a service principal.
#'
#' Valid values are:`"authorization_code"`, `"device_code"`,
#' `"client_credentials"`, `"resource_owner"`, `"on_behalf_of"`.
#'
#' See **Details** of [AzureAuth::get_azure_token()] for further details.
#' @param creds_yaml_path `str` Path to a YAML credentials file containing service principal
#' credentials (`tcc_azure$client_id`, `tcc_azure$client_secret`). If `NULL` (default) and
#' the environment variables `ERIFUNCTIONS_SP_CLIENT_ID` / `ERIFUNCTIONS_SP_CLIENT_SECRET`
#' are set, those are used automatically. Otherwise falls back to interactive auth via `auth`.
#' @param ... additional parameters passed to [AzureAuth::get_azure_token()].
#' @returns Azure container object
#' @examples
#' \dontrun{
#' azcontainer <- get_azure_storage_connection()
#' }
#'
#' @export
get_azure_storage_connection <- function(
    tenant_id = Sys.getenv("ERIFUNCTIONS_TENANT_ID", unset = .ERI_DEFAULT_TENANT_ID),
    app_id = Sys.getenv("ERIFUNCTIONS_APP_ID", unset = .ERI_DEFAULT_APP_ID),
    resource_endpoint = Sys.getenv("ERIFUNCTIONS_RESOURCE_ENDPOINT", unset = .ERI_DEFAULT_RESOURCE_ENDPOINT),
    storage_name = Sys.getenv("ERIFUNCTIONS_STORAGE_NAME"),
    auth = "authorization_code",
    creds_yaml_path = NULL,
    ...) {

  sp_client_id     <- Sys.getenv("ERIFUNCTIONS_SP_CLIENT_ID")
  sp_client_secret <- Sys.getenv("ERIFUNCTIONS_SP_CLIENT_SECRET")

  if (nchar(sp_client_id) > 0 && nchar(sp_client_secret) > 0) {
    mytoken <- AzureAuth::get_azure_token(
      resource  = "https://storage.azure.com/",
      tenant    = tenant_id,
      app       = sp_client_id,
      auth_type = "client_credentials",
      password  = sp_client_secret
    )
  } else if (!is.null(creds_yaml_path)) {
    creds <- yaml::read_yaml(creds_yaml_path)
    mytoken <- AzureAuth::get_azure_token(
      resource  = "https://storage.azure.com/",
      tenant    = tenant_id,
      app       = creds$tcc_azure$client_id,
      auth_type = "client_credentials",
      password  = creds$tcc_azure$client_secret
    )
  } else {
    mytoken <- AzureAuth::get_azure_token(
      resource  = "https://storage.azure.com/",
      tenant    = tenant_id,
      app       = app_id,
      auth_type = auth
    )
  }

  endptoken <- AzureStor::storage_endpoint(endpoint = resource_endpoint, token = mytoken)
  azcontainer <- AzureStor::storage_container(endptoken, storage_name)

  return(azcontainer)
}

#### 2) I/O dispatcher ####

#' erifunctions i/o handler
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Manages read/write/list/create/delete functions for erifunctions. This function
#' is adapted from [tidypolis_io](https://github.com/nish-kishore/tidypolis/blob/4e2f75e5ee3205b84c5b78f4b1776e2270e1f9ec/R/dal.R#L15).
#'
#' For a more ergonomic interface with tab-completion and per-operation help pages,
#' consider the verb-named wrappers: [eri_read()], [eri_write()], [eri_list()],
#' [eri_file_exists()], [eri_dir_exists()], [eri_dir_create()], [eri_delete()],
#' [eri_dir_delete()].
#'
#' @param obj `str` Object to be loaded into Azure
#' @param io `str` The type of operation to use. Valid values include:
#' - `"read"`: reads data from the specified `file_path`.
#' - `"write"`: writes data to the specified `file_path`.
#' - `"list"`: lists the files in the specified `file_path`.
#' - `"exists.dir"`: determines whether a directory is present.
#' - `"exists.file"`: determines whether a file is present.
#' - `"create.dir"`: creates a directory to the specified `file_path`.
#' - `"delete"`: deletes a file in the specified `file_path`.
#' - `"delete.dir"`: deletes a folder in the specified `file_path.`
#' @param file_loc `str` Path of file.
#' @param azure `logical` Whether the function should interact with the TCC Azure environment.
#' Defaults to `TRUE`, otherwise, interacts with files locally.
#' @param azcontainer `Azure container` A container object returned by
#' [get_azure_storage_connection()].
#' @param full_names `logical` If `io="list"`, include the full reference path. Default `TRUE`.
#' @param progress `logical` Show AzureStor's byte progress bar for the transfer. Default `FALSE`
#'   (suppressed; erifunctions renders its own output). Set `TRUE` for a large single read/upload.
#' @param ... Optional parameters that work with [readr::read_delim()] or [readxl::read_excel()].
#' @returns Conditional on `io`. If `io` is `"read"`, then it will return a tibble. If `io` is
#' `"list"`, it will return a list of file names. Otherwise, the function will return `NULL`.
#' `exists.dir` and `exists.file` will return a `logical`.
#'
#' @examples
#' \dontrun{
#' df <- erifunctions_io("read", file_loc = "df1.csv")
#' df2 <- erifunctions_io("read", file_loc = "df2.xlsx", sheet = 1, skip = 2)
#' list_of_df <- list(df_1 = df, df_2 = df)
#' erifunctions_io("write", file_loc = "Data/test/df.csv", obj = df)
#' erifunctions_io("write", file_loc = "Data/test/df.xlsx", obj = list_of_df)
#' erifunctions_io("exists.dir", "Data/nonexistentfolder")
#' erifunctions_io("exists.file", file_loc = "Data/test/df1.csv")
#' erifunctions_io("create.dir", "Data/nonexistentfolder")
#' erifunctions_io("list")
#' }
#'
#' @export
erifunctions_io <- function(
    io,
    file_loc = "",
    obj = NULL,
    azure = TRUE,
    azcontainer = suppressMessages(get_azure_storage_connection()),
    full_names = TRUE,
    progress = FALSE,
    ...) {

  opts <- c("read", "write", "upload", "delete", "delete.dir", "list", "exists.dir", "exists.file", "create.dir")

  if (!io %in% opts) {
    stop("io: must be 'read', 'write', 'upload', 'delete', 'delete.dir', 'create.dir', 'exists.dir', 'exists.file' or 'list'")
  }

  if (io == "write" && is.null(obj)) {
    stop("Need to supply an object to be written")
  }

  if (io == "list") {
    if (azure) {
      out <- azure_io(io = "list", file_loc, azcontainer = azcontainer)

      if (full_names) {
        return(out)
      } else {
        return(out |> dplyr::mutate(name = basename(name)))
      }
    } else {
      files <- list.files(file_loc, full.names = TRUE)

      get_file_info <- function(file) {
        file.info(file) |>
          dplyr::as_tibble() |>
          dplyr::select(size, isdir, lastModified = mtime) |>
          dplyr::mutate(
            name = file,
            lastModified = lubridate::as_datetime(lastModified)
          ) |>
          dplyr::select(name, size, isdir, lastModified)
      }

      files <- lapply(files, \(x) get_file_info(x)) |>
        dplyr::bind_rows()

      if (full_names) {
        return(files)
      } else {
        return(files |> dplyr::mutate(name = basename(name)))
      }
    }
  }

  if (io == "exists.dir") {
    if (azure) {
      return(azure_io("exists.dir", file_loc, azcontainer = azcontainer))
    } else {
      return(dir.exists(file_loc))
    }
  }

  if (io == "exists.file") {
    if (azure) {
      return(azure_io(io = "exists.file", file_loc, azcontainer = azcontainer))
    } else {
      return(file.exists(file_loc))
    }
  }

  if (io == "read") {
    if (azure) {
      return(azure_io(io = "read", file_loc, azcontainer = azcontainer, progress = progress, ...))
    } else {
      if (!grepl(".rds$|.rda$|.csv$|.xlsx$|.xls$|.parquet$|.qs2$|.tif$", file_loc)) {
        stop("At the moment only 'rds' 'rda' 'csv' 'xlsx' 'xls' 'parquet', 'qs2', and 'tif' are supported for reading.")
      }

      if (endsWith(file_loc, ".rds")) {
        return(readr::read_rds(file_loc))
      } else if (endsWith(file_loc, ".rda")) {
        obj_names <- load(file_loc, envir = globalenv())
        cli::cli_alert_success("RDA object loaded to the global environment:")
        cli::cli_li(obj_names)
        return(invisible())
      } else if (endsWith(file_loc, ".csv")) {
        return(readr::read_csv(file_loc, show_col_types = FALSE))
      } else if (endsWith(file_loc, ".qs2")) {
        return(qs2::qs_read(file_loc))
      } else if (endsWith(file_loc, ".xlsx") || endsWith(file_loc, ".xls")) {
        return(read_excel_from_azure(src = file_loc, ...))
      } else if (endsWith(file_loc, ".parquet")) {
        return(arrow::read_parquet(file_loc))
      } else if (endsWith(file_loc, ".tif")) {
        if (!requireNamespace("terra", quietly = TRUE)) stop("Package 'terra' must be installed to read .tif files.")
        return(terra::rast(file_loc))
      }
    }
  }

  if (io == "write") {
    if (azure) {
      azure_io(io = "write", file_loc = file_loc, obj = obj, azcontainer = azcontainer, ...)
    } else {
      if (!grepl(".rds$|.rda$|.csv$|.xlsx$|.xls$|.png$|.jpg$|.jpeg$|.pdf$|.svg$|.parquet$|.qs2$", file_loc)) {
        stop("At the moment only 'rds' 'rda' 'csv' 'xlsx', 'xls' 'parquet', 'qs2', 'png', 'jpg', 'jpeg', 'pdf', and 'svg' are supported for writing.")
      } else if (endsWith(file_loc, ".rds")) {
        readr::write_rds(x = obj, file = file_loc)
      } else if (endsWith(file_loc, ".rda")) {
        temp_env <- new.env(parent = emptyenv())
        temp_env[["obj"]] <- obj
        save(list = "obj", envir = temp_env, file = file_loc)
      } else if (endsWith(file_loc, ".csv")) {
        readr::write_csv(x = obj, file = file_loc)
      } else if (endsWith(file_loc, ".qs2")) {
        qs2::qs_save(obj, file_loc)
      } else if (endsWith(file_loc, ".xlsx") || endsWith(file_loc, ".xls")) {
        writexl::write_xlsx(obj, path = file_loc)
      } else if (endsWith(file_loc, ".parquet")) {
        gc()
        arrow::write_parquet(obj, sink = file_loc)
      } else if (grepl("\\.png$|\\.jpg$|\\.jpeg$|\\.pdf$|\\.svg$", file_loc)) {
        ggplot2::ggsave(filename = file_loc, plot = obj, ...)
      }
    }
  }

  if (io == "upload") {
    if (azure) {
      azure_io(io = "upload", file_loc = file_loc, local_path = obj, azcontainer = azcontainer,
               progress = progress)
    } else {
      stop("'upload' io is only valid when azure = TRUE.")
    }
  }

  if (io == "delete") {
    if (azure) {
      azure_io("delete", file_loc = file_loc, force_delete = TRUE, azcontainer = azcontainer)
    } else {
      file.remove(file_loc)
    }
  }

  if (io == "create.dir") {
    if (azure) {
      azure_io(io = "create", file_loc = file_loc, azcontainer = azcontainer)
    } else {
      if (dir.exists(file_loc)) {
        cli::cli_alert_info("Directory already exists.")
      } else {
        dir.create(file_loc)
      }
    }
  }

  if (io == "delete.dir") {
    if (azure) {
      azure_io(io = "delete.dir", force_delete = TRUE, azcontainer = azcontainer, file_loc = file_loc)
    } else {
      unlink(file_loc, recursive = TRUE, force = TRUE)
    }
  }

  # Side-effecting ops (write/upload/delete/create.dir/delete.dir) fall through to
  # here; return invisibly so they don't print a stray `NULL` in scripts/Rscript.
  return(invisible(NULL))
}

#' Helper function to read and write key data to the Azure environment
#'
#' The function serves as the primary way to interact with the Azure system from R. It can
#' read, write, create folders, check whether a file or a folder exists, upload files, and list
#' all files in a folder.
#'
#' @param io `str` The type of operation to perform in Azure
#' - `"read"` Read a file from Azure, must be an rds, csv, rda, or xls/xlsx file.
#' - `"write"` Write a file to Azure, must be an rds, csv, rda, or xls/xlsx file. To
#' write an Excel file with multiple sheets, pass a named list containing the tibbles
#' of interest. See examples.
#' - `"exists.dir"` Returns a boolean after checking to see if a folder exists.
#' - `"exists.file"`Returns a boolean after checking to see if a file exists.
#' - `"create"` Creates a folder and all preceding folders.
#' - `"list"` Returns a tibble with all objects in a folder.
#' - `"upload"` Moves a file of any type to Azure
#' - `"delete"` Deletes a file.
#' - `"delete.dir"` Deletes a folder.
#' @param file_loc `str` Location to "read", "write", "exists.dir", "exists.file", "create" or "list".
#' @param obj `robj` Object to be saved, needed for `"write"`. Defaults to `NULL`.
#' @param azcontainer Azure container object returned from [get_azure_storage_connection()].
#' @param force_delete `logical` Use delete io without confirmation prompt. Default `FALSE`.
#' @param progress `logical` Show AzureStor's byte progress bar for the transfer. Default `FALSE`
#'   (suppressed). Set `TRUE` for a large single read/upload that needs visible feedback.
#' @param local_path `str` Local file pathway to upload a file to Azure. Default is `NULL`.
#' This parameter is only required when passing `"upload"` in the `io` parameter.
#' @param ... Optional parameters that work with [readr::read_delim()], [readxl::read_excel()], or [ggplot2::ggsave()].
#' @returns Output dependent on argument passed in the `io` parameter.
#' @examples
#' \dontrun{
#' df <- azure_io("read", file_loc = "df1.csv")
#' df2 <- azure_io("read", file_loc = "df2.xlsx", sheet = 1, skip = 2)
#' list_of_df <- list(df_1 = df, df_2 = df)
#' azure_io("write", file_loc = "Data/test/df.csv", obj = df)
#' azure_io("write", file_loc = "Data/test/df.xlsx", obj = list_of_df)
#' azure_io("exists.dir", "Data/nonexistentfolder")
#' azure_io("exists.file", file_loc = "Data/test/df1.csv")
#' azure_io("create", "Data/nonexistentfolder")
#' azure_io("list")
#' azure_io("upload", file_loc = "Data/test", local_path = "C:/Users/ABC1/Desktop/df2.csv")
#' }
#' @export
azure_io <- function(
    io,
    file_loc = NULL,
    obj = NULL,
    azcontainer = suppressMessages(get_azure_storage_connection()),
    force_delete = FALSE,
    local_path = NULL,
    progress = FALSE,
    ...) {

  opts <- c("read", "write", "delete", "delete.dir",
            "list", "exists.dir", "exists.file", "create", "upload")

  if (!io %in% opts) {
    stop("io: must be 'read', 'write', 'exists.dir', 'exists.file','create', 'delete' 'delete.dir' 'list' or 'upload'")
  }

  # Suppress AzureStor's per-transfer byte bar for everything routed through the dispatcher;
  # erifunctions renders its own clean cli output (see .eri_blob_* helpers). Scoped to this call.
  # `progress = TRUE` opts a transfer back in (e.g. a large single read/upload that needs feedback).
  withr::local_options(azure_storage_progress_bar = isTRUE(progress))

  if (io == "write" && is.null(obj)) {
    stop("Need to supply an object to be written")
  }

  if (io == "upload" && is.null(local_path)) {
    stop("Need to supply file pathway of file to be uploaded")
  }

  if (io == "list") {
    if (!AzureStor::storage_dir_exists(azcontainer, file_loc) && file_loc != "") {
      stop("Directory does not exist")
    }

    return(AzureStor::list_storage_files(azcontainer, file_loc) |>
             dplyr::as_tibble())
  }

  if (io == "exists.dir") {
    return(AzureStor::storage_dir_exists(azcontainer, file_loc))
  }

  if (io == "exists.file") {
    return(AzureStor::storage_file_exists(azcontainer, file_loc))
  }

  if (io == "create") {
    tryCatch(
      {
        .eri_create_azure_dir(azcontainer, file_loc)
        cli::cli_alert_success("Directory created!")
      },
      error = function(e) {
        stop("Directory creation failed")
      }
    )
  }

  if (io == "read") {
    if (!AzureStor::storage_file_exists(azcontainer, file_loc)) {
      stop("File does not exist")
    }

    if (!grepl(".rds$|.rda$|.csv$|.xlsx$|.xls$|.parquet$|.qs2$|.tif$", file_loc)) {
      stop("At the moment only 'rds' 'rda', 'csv', 'xls', 'xlsx' 'parquet', 'qs2', '.tif' are supported for reading.")
    }

    if (endsWith(file_loc, ".rds")) {
      corrupted.rds <- FALSE

      tryCatch(
        {
          return(suppressWarnings(AzureStor::storage_load_rds(azcontainer, file_loc)))
        },
        error = function(e) {
          cli::cli_alert_warning("RDS download from EDAV was corrupted, downloading directly...")
          corrupted.rds <<- TRUE
        }
      )

      if (corrupted.rds) {
        return(
          withr::with_tempfile("dest", {
            AzureStor::storage_download(container = azcontainer, file_loc, dest)
            readRDS(dest)
          }, fileext = ".rds")
        )
      }
    }

    if (endsWith(file_loc, ".csv")) {

      # suppressMessages (rather than show_col_types = FALSE) silences readr's
      # column-spec dump without risking a duplicate-arg clash: storage_read_csv()
      # forwards `...` to readr, so a caller may already pass show_col_types here.
      return(suppressMessages(suppressWarnings(AzureStor::storage_read_csv(azcontainer, file_loc, ...))))

    } else if (endsWith(file_loc, ".rda")) {

      obj_names <- suppressWarnings(AzureStor::storage_load_rdata(azcontainer, file_loc, envir = globalenv()))
      cli::cli_alert_success("RDA object loaded to the global environment:")
      cli::cli_li(obj_names)
      return(invisible())

    } else if (endsWith(file_loc, ".xlsx") || endsWith(file_loc, ".xls")) {

      file_ext <- if (endsWith(file_loc, ".xlsx")) ".xlsx" else ".xls"

      return(
        withr::with_tempfile("excel_file", {
          AzureStor::storage_download(azcontainer, file_loc, excel_file, overwrite = TRUE)
          read_excel_from_azure(src = excel_file, ...)
        }, fileext = file_ext)
      )

    } else if (endsWith(file_loc, ".parquet")) {

      return(
        withr::with_tempfile("parquet_file", {
          AzureStor::storage_download(azcontainer, file_loc, parquet_file, overwrite = TRUE)
          arrow::read_parquet(parquet_file)
        }, fileext = ".parquet")
      )

    } else if (endsWith(file_loc, ".qs2")) {

      return(
        withr::with_tempfile("qs2_file", {
          AzureStor::storage_download(azcontainer, file_loc, qs2_file, overwrite = TRUE)
          qs2::qs_read(qs2_file)
        }, fileext = ".qs2")
      )

    } else if (endsWith(file_loc, ".tif")) {

      if (!requireNamespace("terra", quietly = TRUE)) stop("Package 'terra' must be installed to read .tif files.")
      return(
        withr::with_tempfile("tif_file", {
          AzureStor::storage_download(azcontainer, file_loc, tif_file, overwrite = TRUE)
          terra::rast(tif_file)
        }, fileext = ".tif")
      )

    }
  }

  if (io == "write") {
    if (!grepl(".rds$|.rda$|.csv$|.xlsx$|.xls$|.png$|.jpg$|.jpeg$|.pdf$|.svg$|.parquet$|.qs2$", file_loc)) {
      cli::cli_abort(paste0("Please pass a path including the file name in file_loc.",
                            " (i.e., folder/data.csv)"))
    }

    if (endsWith(file_loc, ".rds")) {
      AzureStor::storage_save_rds(object = obj, container = azcontainer, file = file_loc)
    } else if (endsWith(file_loc, ".rda")) {
      AzureStor::storage_save_rdata(object = obj, container = azcontainer, file = file_loc)
    } else if (endsWith(file_loc, ".csv")) {
      AzureStor::storage_write_csv(object = obj, container = azcontainer, file = file_loc)
    } else if (endsWith(file_loc, ".xlsx") || endsWith(file_loc, ".xls")) {

      file_ext <- if (endsWith(file_loc, ".xlsx")) ".xlsx" else ".xls"

      withr::with_tempfile("excel_file", {
        writexl::write_xlsx(obj, path = excel_file)
        AzureStor::storage_upload(container = azcontainer, dest = file_loc, src = excel_file)
      }, fileext = file_ext)

    } else if (endsWith(file_loc, ".parquet")) {

      withr::with_tempfile("parquet_file", {
        arrow::write_parquet(obj, parquet_file)
        AzureStor::storage_upload(container = azcontainer, dest = file_loc, src = parquet_file)
      }, fileext = ".parquet")

    } else if (endsWith(file_loc, ".qs2")) {

      withr::with_tempfile("qs2_file", {
        qs2::qs_save(obj, qs2_file)
        AzureStor::storage_upload(container = azcontainer, dest = file_loc, src = qs2_file)
      }, fileext = ".qs2")

    } else if ("gg" %in% class(obj)) {

      withr::with_tempfile("gg_file", {
        ggplot2::ggsave(filename = gg_file, plot = obj, ...)
        AzureStor::storage_upload(container = azcontainer, src = gg_file, dest = file_loc)
      }, fileext = paste0(".", tools::file_ext(file_loc)))

    } else if ("flextable" %in% class(obj)) {

      if (!requireNamespace("flextable", quietly = TRUE)) stop("Package 'flextable' must be installed to write flextable objects.")
      withr::with_tempfile("ft_file", {
        flextable::save_as_image(obj, path = ft_file)
        AzureStor::storage_upload(
          container = azcontainer, src = ft_file, dest = file_loc, overwrite = TRUE
        )
      }, fileext = paste0(".", tools::file_ext(basename(file_loc))))

    }
  }

  if (io == "upload") {
    AzureStor::storage_upload(container = azcontainer, dest = file_loc, src = local_path)
  }

  if (io == "delete") {
    if (!AzureStor::storage_file_exists(azcontainer, file_loc)) {
      stop("File does not exist")
    }
    AzureStor::delete_storage_file(azcontainer, file_loc, confirm = !force_delete)
  }

  if (io == "delete.dir") {
    if (!AzureStor::storage_dir_exists(azcontainer, file_loc)) {
      stop("Folder does not exist")
    }
    AzureStor::delete_adls_dir(azcontainer, file_loc, recursive = TRUE, confirm = !force_delete)
    invisible()
  }

}

#### 3) Verb-named wrappers ####

#' Read a file
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Thin wrapper around [erifunctions_io()] for reading files, with a dedicated
#' help page and tab-completable name.
#'
#' @inheritParams erifunctions_io
#' @export
eri_read <- function(file_loc, ..., azure = TRUE, azcontainer = NULL, progress = FALSE) {
  if (azure) .eri_log_session()
  if (azure && is.null(azcontainer)) azcontainer <- suppressMessages(get_azure_storage_connection())
  erifunctions_io("read", file_loc = file_loc, azure = azure, azcontainer = azcontainer,
                  progress = progress, ...)
}

#' Write an object to a file
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Thin wrapper around [erifunctions_io()] for writing files.
#'
#' @inheritParams erifunctions_io
#' @export
eri_write <- function(obj, file_loc, ..., azure = TRUE, azcontainer = NULL) {
  if (azure) .eri_log_session()
  if (azure && is.null(azcontainer)) azcontainer <- suppressMessages(get_azure_storage_connection())
  erifunctions_io("write", obj = obj, file_loc = file_loc, azure = azure, azcontainer = azcontainer, ...)
}

#' List files in a directory
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Thin wrapper around [erifunctions_io()] for listing directory contents.
#'
#' @inheritParams erifunctions_io
#' @export
eri_list <- function(file_loc = "", full_names = TRUE, azure = TRUE, azcontainer = NULL) {
  if (azure) .eri_log_session()
  if (azure && is.null(azcontainer)) azcontainer <- suppressMessages(get_azure_storage_connection())
  erifunctions_io("list", file_loc = file_loc, full_names = full_names, azure = azure, azcontainer = azcontainer)
}

#' Check whether a file exists
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Thin wrapper around [erifunctions_io()] for checking file existence.
#'
#' @inheritParams erifunctions_io
#' @export
eri_file_exists <- function(file_loc, azure = TRUE, azcontainer = NULL) {
  if (azure) .eri_log_session()
  if (azure && is.null(azcontainer)) azcontainer <- suppressMessages(get_azure_storage_connection())
  erifunctions_io("exists.file", file_loc = file_loc, azure = azure, azcontainer = azcontainer)
}

#' Check whether a directory exists
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Thin wrapper around [erifunctions_io()] for checking directory existence.
#'
#' @inheritParams erifunctions_io
#' @export
eri_dir_exists <- function(file_loc, azure = TRUE, azcontainer = NULL) {
  if (azure) .eri_log_session()
  if (azure && is.null(azcontainer)) azcontainer <- suppressMessages(get_azure_storage_connection())
  erifunctions_io("exists.dir", file_loc = file_loc, azure = azure, azcontainer = azcontainer)
}

#' Create a directory
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Thin wrapper around [erifunctions_io()] for creating a directory.
#'
#' @inheritParams erifunctions_io
#' @export
eri_dir_create <- function(file_loc, azure = TRUE, azcontainer = NULL) {
  if (azure) .eri_log_session()
  if (azure && is.null(azcontainer)) azcontainer <- suppressMessages(get_azure_storage_connection())
  erifunctions_io("create.dir", file_loc = file_loc, azure = azure, azcontainer = azcontainer)
}

#' Delete a file
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Thin wrapper around [erifunctions_io()] for deleting a file.
#'
#' @inheritParams erifunctions_io
#' @export
eri_delete <- function(file_loc, azure = TRUE, azcontainer = NULL) {
  if (azure) .eri_log_session()
  if (azure && is.null(azcontainer)) azcontainer <- suppressMessages(get_azure_storage_connection())
  erifunctions_io("delete", file_loc = file_loc, azure = azure, azcontainer = azcontainer)
}

#' Delete a directory
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Thin wrapper around [erifunctions_io()] for deleting a directory. When deleting
#' from the `data/` blob, it also **prunes the data catalog**: any
#' [eri_catalog_query()] entry whose path falls under `file_loc` is removed, so
#' deleting a namespace never leaves dangling rows that [eri_catalog_verify()]
#' would later flag.
#'
#' @inheritParams erifunctions_io
#' @param prune_catalog `lgl` If `TRUE` (default when `azure`), remove catalog
#'   entries under `file_loc` after the delete. Fail-silent: a catalog hiccup
#'   never blocks the delete.
#' @export
eri_dir_delete <- function(file_loc, azure = TRUE, azcontainer = NULL,
                           prune_catalog = azure) {
  if (azure) .eri_log_session()
  if (azure && is.null(azcontainer)) azcontainer <- suppressMessages(get_azure_storage_connection())
  result <- erifunctions_io("delete.dir", file_loc = file_loc, azure = azure,
                            azcontainer = azcontainer)
  if (isTRUE(azure) && isTRUE(prune_catalog)) {
    .eri_prune_catalog_under(file_loc, data_con = azcontainer)
  }
  result
}

# Remove catalog entries whose path falls under `prefix` (e.g. after deleting a
# namespace). Fail-silent so a catalog problem never blocks the directory delete.
#' @keywords internal
.eri_prune_catalog_under <- function(prefix, data_con = NULL) {
  tryCatch({
    entries <- suppressMessages(eri_catalog_query(data_con = data_con))
    if (nrow(entries) == 0L) return(invisible(0L))
    norm <- sub("/+$", "", prefix)
    hit  <- entries$path[entries$path == norm |
                           startsWith(entries$path, paste0(norm, "/"))]
    for (p in hit) suppressMessages(eri_catalog_remove(p, data_con = data_con))
    if (length(hit) > 0L) {
      cli::cli_alert_info("Removed {length(hit)} catalog entr{?y/ies} under {.path {norm}}.")
    }
    invisible(length(hit))
  }, error = function(e) invisible(0L))
}

#' Upload any local file to Azure
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Thin wrapper around [azure_io()] for uploading arbitrary local files to Azure,
#' including binary formats (shapefiles, images, etc.) not handled by [eri_write()].
#'
#' @param local_path `str` Local path to the file to upload.
#' @param file_loc `str` Destination path in Azure (including filename).
#' @param azcontainer Azure container object from [get_azure_storage_connection()].
#' @export
eri_upload <- function(local_path, file_loc, azcontainer = NULL) {
  .eri_log_session()
  if (is.null(azcontainer)) azcontainer <- suppressMessages(get_azure_storage_connection())
  erifunctions_io("upload", obj = local_path, file_loc = file_loc, azure = TRUE, azcontainer = azcontainer)
}

#### 4) Data pipeline helpers ####

#' Build a canonical blob path in the data/ container
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Constructs a canonical blob storage path following the erifunctions five-axis
#' data model (ADR-0012): `{country}/{disease}/{data_source}/{data_type}/{layer}/`,
#' where `data_source` is the channel (how the data arrives) and `data_type` is the
#' measure (what it captures). Use this instead of hard-coding path strings.
#'
#' The legacy four-axis form `eri_data_path(country, disease, data_source, layer[,
#' filename])` is still accepted during the ADR-0012 migration and builds a
#' measure-less `{country}/{disease}/{data_source}/{layer}/` path — detected because
#' its fourth argument is a `layer` keyword (a `data_type` measure never is).
#'
#' @param country `str` Country code (e.g. `"dr"`, `"ht"`, `"uga"`).
#' @param disease `str` Disease name (e.g. `"malaria"`, `"lf"`, `"oncho"`).
#' @param data_source `str` The channel: `"surveillance"`, `"programmatic"`,
#'   `"research"` (extensible — see [eri_data_model()]; unknown values warn).
#' @param data_type `str` The measure: `"case"`, `"aggregate"`, `"treatment"`,
#'   `"tas"`, ... (extensible; unknown values warn).
#' @param layer `str` Pipeline layer: `"raw"`, `"staged"`, or `"processed"`.
#' @param filename `str` Optional filename to append. If `NULL` (default), returns
#'   the directory path only.
#' @returns A character string with the canonical blob path.
#' @examples
#' eri_data_path("dr", "malaria", "surveillance", "case", "staged")
#' #> "dr/malaria/surveillance/case/staged"
#'
#' eri_data_path("uga", "oncho", "programmatic", "treatment", "raw", "2024_06.parquet")
#' #> "uga/oncho/programmatic/treatment/raw/2024_06.parquet"
#' @export
eri_data_path <- function(country, disease, data_source, data_type, layer, filename = NULL) {
  model         <- .eri_data_model()
  valid_layers  <- .eri_layers()
  known_sources <- names(model$data_sources)

  # Capture which arguments were actually supplied before any reassignment.
  # An explicit NULL `data_type` is treated as "no measure" (the 4-axis form), so
  # callers can pass `data_type` through uniformly during the migration.
  src_missing   <- missing(data_source)
  type_missing  <- missing(data_type) || is.null(data_type)
  layer_missing <- missing(layer)

  # Legacy NAMED form: the old 3rd parameter was *named* `data_type` but held the
  # source, e.g. eri_data_path(country, disease, data_type = "cmr", layer = "staged").
  # If `data_source` is absent and the (old-named) `data_type` holds a known source,
  # remap it; otherwise the source is genuinely missing.
  if (src_missing) {
    if (!type_missing && data_type %in% known_sources) {
      data_source  <- data_type
      type_missing <- TRUE          # the measure is absent in the legacy form
    } else {
      cli::cli_abort(c(
        "{.arg data_source} is required.",
        "i" = "Path form: eri_data_path(country, disease, data_source, data_type, layer)."
      ))
    }
  }

  # Legacy POSITIONAL form: eri_data_path(country, disease, data_source, layer[, filename]).
  # Layers are a closed set and a `data_type` measure is never a layer keyword, so a
  # fourth positional that is a layer means the call omits the measure.
  if (!type_missing && data_type %in% valid_layers) {
    if (!layer_missing) filename <- layer   # the 5th positional was actually the filename
    layer         <- data_type
    layer_missing <- FALSE
    type_missing  <- TRUE
  } else if (layer_missing) {
    cli::cli_abort(c(
      "{.arg layer} is required.",
      "i" = "Path form: eri_data_path(country, disease, data_source, data_type, layer)."
    ))
  }
  data_type <- if (type_missing) NULL else data_type

  if (!layer %in% valid_layers) {
    cli::cli_abort("{.arg layer} must be one of {.val {valid_layers}}, not {.val {layer}}.")
  }
  .eri_check_axis("data_source", data_source, known_sources)
  if (!is.null(data_type)) {
    .eri_check_axis("data_type", data_type, names(model$data_types))
  }

  parts <- c(country, disease, data_source, data_type, layer)
  if (!is.null(filename)) parts <- c(parts, filename)
  paste(parts, collapse = "/")
}

#' Approve staged data and promote it to processed
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' The human approval gate in the three-layer pipeline. Finds all files in the
#' `staged/` directory whose names contain `period`, moves them to `processed/`,
#' and writes a YAML approval log alongside them.
#'
#' Analyst identity is read from the `ERI_ANALYST_ID` environment variable,
#' falling back to `Sys.info()[["user"]]` if it is unset or empty (in which case a
#' one-time warning is emitted so the fallback attribution is not silent).
#'
#' An operation log capturing every step (including errors) is always written to
#' `{country}/{disease}/{data_source}/{data_type}/logs/` in the data container,
#' regardless of whether the approval succeeds or fails. This log is the primary
#' debugging artifact for pipeline issues.
#'
#' @param country `str` Country code (e.g. `"dr"`, `"ht"`).
#' @param disease `str` Disease name (e.g. `"malaria"`).
#' @param data_source `str` The channel the data came through: `"surveillance"`,
#'   `"programmatic"`, or `"research"` (ADR-0012).
#' @param period `str` Period string matched against staged filenames (e.g.
#'   `"2024-W01"`, `"2024-01"`). Any staged file whose name contains this string
#'   is promoted.
#' @param data_type `str` or `NULL` The measure the data captures (e.g. `"case"`,
#'   `"aggregate"`, `"treatment"`, `"tas"`). `NULL` (default) approves the legacy
#'   four-axis path `{country}/{disease}/{data_source}/...` without a measure level,
#'   and the catalog entry's measure is recorded as `NA` — a one-time per-session
#'   note points this out so it is a deliberate choice, not a silent omission.
#' @param azcontainer Azure container object for the `data/` blob, returned by
#'   [get_azure_storage_connection()]. If `NULL` (default), connects automatically
#'   using `ERIFUNCTIONS_DATA_STORAGE_NAME`.
#' @returns Invisibly, a character vector of the promoted file paths in `processed/`.
#' @examples
#' \dontrun{
#' # Four-axis (no measure): {country}/{disease}/{data_source}/...
#' eri_approve("dr", "malaria", "surveillance", "2024-W01")
#'
#' # Five-axis (with measure): {country}/{disease}/{data_source}/{data_type}/...
#' eri_approve("dr", "malaria", "surveillance", "2024-W01", data_type = "case")
#' }
#' @export
eri_approve <- function(country, disease, data_source, period, data_type = NULL, azcontainer = NULL) {
  .eri_log_session()
  .eri_note_no_measure(data_type)
  if (is.null(azcontainer)) {
    azcontainer <- suppressMessages(
      get_azure_storage_connection(
        storage_name = Sys.getenv("ERIFUNCTIONS_DATA_STORAGE_NAME", "data")
      )
    )
  }

  analyst_id    <- .eri_analyst_id()
  staged_dir    <- eri_data_path(country, disease, data_source, data_type, "staged")
  processed_dir <- eri_data_path(country, disease, data_source, data_type, "processed")
  log_dir       <- paste(c(country, disease, data_source, data_type, "logs"), collapse = "/")

  op_log <- list(
    operation  = "eri_approve",
    analyst    = analyst_id,
    started_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    parameters = list(country = country, disease = disease,
                      data_source = data_source, data_type = data_type,
                      period = period),
    status     = "in_progress",
    steps      = list(),
    error      = NULL,
    files      = NULL
  )

  moved     <- character(0)
  had_error <- FALSE
  err_msg   <- NULL

  tryCatch({
    if (!AzureStor::storage_dir_exists(azcontainer, staged_dir)) {
      cli::cli_abort("Staged directory does not exist: {.path {staged_dir}}")
    }
    op_log$steps <- .eri_log_step(op_log$steps, "check_staged_dir",
                                   path = staged_dir)

    all_staged <- AzureStor::list_storage_files(azcontainer, staged_dir) |>
      dplyr::as_tibble()
    matching <- all_staged[grepl(period, all_staged$name, fixed = TRUE), ]

    if (nrow(matching) == 0) {
      cli::cli_abort(
        "No staged files found matching {.val {period}} in {.path {staged_dir}}."
      )
    }
    op_log$steps <- .eri_log_step(op_log$steps, "list_staged_files",
                                   files_found = nrow(matching),
                                   filenames   = as.list(basename(matching$name)))

    if (!AzureStor::storage_dir_exists(azcontainer, processed_dir)) {
      AzureStor::create_storage_dir(azcontainer, processed_dir)
      op_log$steps <- .eri_log_step(op_log$steps, "create_processed_dir",
                                     path = processed_dir)
    }

    for (src_path in matching$name) {
      dest_path <- paste0(processed_dir, "/", basename(src_path))
      tmp_file  <- tempfile()
      .eri_blob_read(azcontainer, src_path, tmp_file)
      .eri_blob_write(azcontainer, tmp_file, dest_path)
      unlink(tmp_file)
      AzureStor::delete_storage_file(azcontainer, src_path, confirm = FALSE)
      moved <- c(moved, dest_path)
      op_log$steps <- .eri_log_step(op_log$steps, "move_file",
                                     src = src_path, dest = dest_path)
      tryCatch(
        eri_catalog_register(
          path        = dest_path,
          country     = country,
          disease     = disease,
          data_source = data_source,
          data_type   = data_type,
          layer       = "processed",
          period      = period,
          data_con    = azcontainer
        ),
        error = function(e) invisible(NULL)
      )
      .eri_say_done("Approved: {.path {basename(src_path)}}")
    }

    # Human-readable approval record stored alongside the data
    approval <- list(
      analyst   = analyst_id,
      timestamp = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
      period      = period,
      country     = country,
      disease     = disease,
      data_source = data_source,
      data_type   = data_type,
      files       = as.list(moved)
    )
    approval_path <- paste0(processed_dir, "/", period, "_approval_log.yaml")
    approval_file <- tempfile(fileext = ".yaml")
    yaml::write_yaml(approval, approval_file)
    .eri_blob_write(azcontainer, approval_file, approval_path)
    unlink(approval_file)
    op_log$steps <- .eri_log_step(op_log$steps, "write_approval_log",
                                   path = approval_path)
    .eri_say_done("Approval log: {.path {approval_path}}")
    .eri_summary("Approved {.val {period}}", c(
      Dataset  = paste(c(country, disease, data_source, data_type), collapse = " / "),
      Files    = sprintf("%d moved to processed", length(moved)),
      Approver = analyst_id,
      Location = processed_dir
    ))

    op_log$status <- "success"
    op_log$files  <- as.list(moved)

  }, error = function(e) {
    had_error <<- TRUE
    err_msg   <<- conditionMessage(e)
  })

  op_log$completed_at <- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  if (had_error) {
    op_log$status <- "error"
    op_log$error  <- err_msg
    op_log$steps  <- .eri_log_step(op_log$steps, "error_caught",
                                    status = "error", message = err_msg)
  }
  .eri_write_log(op_log, azcontainer, log_dir)
  if (had_error) cli::cli_abort(err_msg, call = NULL)
  invisible(moved)
}

#' Trigger a registered GitHub Actions pipeline
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Dispatches a `workflow_dispatch` event to a registered GitHub Actions
#' pipeline from R.  Authenticates with a GitHub Personal Access Token stored
#' in the `GITHUB_PAT` environment variable (needs `workflow` scope).
#'
#' ## Registered pipelines
#' | Name | Repository | Workflow |
#' |------|------------|---------|
#' | `hsp-mal` | thecartercenter/health-hsp-malaria | data_ingestion.yml |
#'
#' @param pipeline `str` Registered pipeline name. Currently `"hsp-mal"`.
#' @param country `str` Country code passed as a workflow input (e.g. `"dr"`).
#' @param disease `str` Disease name passed as a workflow input (e.g. `"malaria"`).
#' @param year `int` or `NULL` Optional year passed as a workflow input. Default `NULL`.
#' @param phase `str` Pipeline phase. Default `"prod"`; use `"testing"` for dry runs.
#' @param ref `str` Branch or tag to run the workflow against. Default `"main"`.
#'
#' @returns Invisibly, the URL to the workflow's runs page on GitHub.
#' @examples
#' \dontrun{
#' eri_trigger("hsp-mal", "dr", "malaria", phase = "testing")
#' }
#' @export
eri_trigger <- function(pipeline, country, disease,
                        year = NULL, phase = "prod", ref = "main") {
  pat <- Sys.getenv("GITHUB_PAT")
  if (!nzchar(pat)) {
    cli::cli_abort(c(
      "Missing GitHub Personal Access Token.",
      "i" = "Set {.envvar GITHUB_PAT} to a token with {.val workflow} scope."
    ))
  }

  reg <- .eri_pipeline_registry[[pipeline]]
  if (is.null(reg)) {
    known <- paste(names(.eri_pipeline_registry), collapse = ", ")
    cli::cli_abort(c(
      "Unknown pipeline {.val {pipeline}}.",
      "i" = "Registered pipelines: {known}."
    ))
  }

  inputs <- list(country = country, disease = disease, phase = phase)
  if (!is.null(year)) inputs$year <- as.character(year)

  dispatch_url <- sprintf(
    "https://api.github.com/repos/%s/%s/actions/workflows/%s/dispatches",
    reg$owner, reg$repo, reg$workflow
  )

  resp <- httr::POST(
    dispatch_url,
    httr::add_headers(
      Authorization          = paste("token", pat),
      Accept                 = "application/vnd.github+json",
      `X-GitHub-Api-Version` = "2022-11-28"
    ),
    body   = list(ref = ref, inputs = inputs),
    encode = "json"
  )

  if (httr::status_code(resp) != 204L) {
    httr::stop_for_status(resp, task = paste("trigger pipeline", pipeline))
  }

  run_url <- sprintf(
    "https://github.com/%s/%s/actions/workflows/%s",
    reg$owner, reg$repo, reg$workflow
  )

  cli::cli_alert_success(
    "Pipeline {.val {pipeline}} triggered ({country} / {disease} / phase={phase})."
  )
  cli::cli_alert_info("Runs: {.url {run_url}}")

  invisible(run_url)
}

#' Stage intermediate pipeline output into the data/ blob
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Pulls cleaned files from the `projects` blob's `intermediate/` folder for a
#' registered pipeline and copies them into `data/{country}/{disease}/surveillance/staged/`,
#' ready for analyst review via [eri_approve()].
#'
#' If any destination file already exists in `staged/`, a warning is issued for
#' each collision and the file is overwritten.
#'
#' ## Registered pipelines
#' | Name | Project folder | Countries |
#' |------|---------------|-----------|
#' | `hsp-mal` | health-hsp-malaria-dev | `"dr"`, `"ht"` |
#'
#' @param pipeline `str` Registered pipeline name. Currently `"hsp-mal"`.
#' @param country `str` Country code (e.g. `"dr"`, `"ht"`).
#' @param disease `str` Disease name (e.g. `"malaria"`).
#' @param pattern `str` or `NULL` Optional substring filter applied to filenames
#'   before staging (e.g. `"2026"` to stage only 2026 files). Default `NULL` stages all files.
#' @param overwrite `logical` Controls behaviour when a file already exists in
#'   `staged/`. `FALSE` (default) issues a [cli::cli_warn()] for each collision
#'   before overwriting — useful for interactive review. `TRUE` overwrites
#'   silently — intended for scripted or automated workflows.
#' @param projects_con Azure container object for the `projects` blob. If `NULL`
#'   (default), connects automatically using [get_azure_storage_connection()].
#' @param data_con Azure container object for the `data` blob. If `NULL`
#'   (default), connects using `ERIFUNCTIONS_DATA_STORAGE_NAME`.
#'
#' @returns Invisibly, a character vector of the staged file paths in the `data` blob.
#' @examples
#' \dontrun{
#' eri_stage("hsp-mal", "dr", "malaria")
#' eri_stage("hsp-mal", "ht", "malaria", pattern = "2026")
#' eri_stage("hsp-mal", "dr", "malaria", overwrite = TRUE)  # silent, for scripts
#' }
#' @export
eri_stage <- function(pipeline, country, disease,
                      pattern = NULL,
                      overwrite = FALSE,
                      projects_con = NULL,
                      data_con = NULL) {
  .eri_log_session()

  reg <- .eri_pipeline_registry[[pipeline]]
  if (is.null(reg)) {
    known <- paste(names(.eri_pipeline_registry), collapse = ", ")
    cli::cli_abort(c(
      "Unknown pipeline {.val {pipeline}}.",
      "i" = "Registered pipelines: {known}."
    ))
  }

  subfolder <- reg$country_map[[country]]
  if (is.null(subfolder)) {
    known_countries <- paste(names(reg$country_map), collapse = ", ")
    cli::cli_abort(c(
      "Country {.val {country}} is not registered for pipeline {.val {pipeline}}.",
      "i" = "Registered countries: {known_countries}."
    ))
  }

  if (is.null(projects_con)) {
    projects_con <- suppressMessages(get_azure_storage_connection())
  }
  if (is.null(data_con)) {
    data_con <- suppressMessages(
      get_azure_storage_connection(
        storage_name = Sys.getenv("ERIFUNCTIONS_DATA_STORAGE_NAME", "data")
      )
    )
  }

  src_dir    <- paste0(reg$project_folder, "/intermediate/", subfolder)
  staged_dir <- eri_data_path(country, disease, "surveillance", "staged")
  log_dir    <- paste(c(country, disease, "surveillance", "logs"), collapse = "/")

  op_log <- list(
    operation  = "eri_stage",
    analyst    = .eri_analyst_id(),
    started_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    parameters = list(pipeline = pipeline, country = country,
                      disease = disease, pattern = pattern),
    status     = "in_progress",
    steps      = list(),
    error      = NULL,
    files      = NULL
  )

  staged    <- character(0)
  had_error <- FALSE
  err_msg   <- NULL

  tryCatch({
    if (!AzureStor::storage_dir_exists(projects_con, src_dir)) {
      cli::cli_abort("Source directory not found in projects blob: {.path {src_dir}}")
    }
    op_log$steps <- .eri_log_step(op_log$steps, "check_src_dir", path = src_dir)

    all_files <- AzureStor::list_storage_files(projects_con, src_dir) |>
      dplyr::as_tibble()
    src_files <- all_files[!all_files$isdir, ]

    if (!is.null(pattern)) {
      src_files <- src_files[grepl(pattern, src_files$name, fixed = TRUE), ]
    }

    if (nrow(src_files) == 0) {
      pat_msg <- if (!is.null(pattern)) paste0(" matching pattern '", pattern, "'") else ""
      cli::cli_abort("No files found in {.path {src_dir}}{pat_msg}.")
    }
    op_log$steps <- .eri_log_step(op_log$steps, "list_src_files",
                                   files_found = nrow(src_files),
                                   filenames   = as.list(basename(src_files$name)))

    if (!AzureStor::storage_dir_exists(data_con, staged_dir)) {
      AzureStor::create_storage_dir(data_con, staged_dir)
      op_log$steps <- .eri_log_step(op_log$steps, "create_staged_dir", path = staged_dir)
    }

    for (src_path in src_files$name) {
      fname     <- basename(src_path)
      dest_path <- paste0(staged_dir, "/", fname)

      if (AzureStor::storage_file_exists(data_con, dest_path)) {
        if (!overwrite) {
          cli::cli_warn("Overwriting existing staged file: {.path {fname}}")
        }
        op_log$steps <- .eri_log_step(op_log$steps, "overwrite",
                                       status = "warning", file = dest_path)
      }

      tmp <- tempfile()
      .eri_blob_read(projects_con, src_path, tmp)
      .eri_blob_write(data_con, tmp, dest_path)
      unlink(tmp)
      staged <- c(staged, dest_path)
      op_log$steps <- .eri_log_step(op_log$steps, "stage_file",
                                     src = src_path, dest = dest_path)
      .eri_say_done("Staged: {.path {fname}}")
    }

    .eri_summary("Staged to data blob", c(
      Files    = sprintf("%d", length(staged)),
      Location = if (length(staged)) dirname(staged[[1L]]) else "(none)"
    ))
    op_log$status <- "success"
    op_log$files  <- as.list(staged)

  }, error = function(e) {
    had_error <<- TRUE
    err_msg   <<- conditionMessage(e)
  })

  op_log$completed_at <- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  if (had_error) {
    op_log$status <- "error"
    op_log$error  <- err_msg
    op_log$steps  <- .eri_log_step(op_log$steps, "error_caught",
                                    status = "error", message = err_msg)
  }
  .eri_write_log(op_log, data_con, log_dir)
  if (had_error) cli::cli_abort(err_msg, call = NULL)
  invisible(staged)
}

#' Ingest a local data file: DQ-check and stage it
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' The general analyst ingest entry point. Reads a raw local file, runs all DQ
#' checks via [run_dq_checks()], prints the flags, and writes the cleaned parquet
#' to `data/{country}/{disease}/{data_source}/{data_type}/staged/` — feeding
#' [eri_approve()] with the matching measure. It runs on **any** data, including a
#' throwaway sandbox: there is no pipeline-registry or country gate by default.
#'
#' The legacy `projects`-blob dual-write (the hsp-mal cutover comparison) is an
#' **opt-in** mirror: pass `mirror_pipeline = "hsp-mal"` to additionally mirror the
#' cleaned output to `projects/{project_folder}/intermediate/{country_subfolder}/`.
#' This is transitional and removed at the Phase-3 cutover (ADR-0012).
#'
#' @param path `str` Local path to the raw file to ingest.
#' @param country `str` Country code (e.g. `"dr"`, `"ht"`).
#' @param disease `str` Disease name (e.g. `"malaria"`).
#' @param data_source `str` The channel (`"surveillance"`, `"programmatic"`,
#'   `"research"`). Default `"surveillance"`.
#' @param data_type `str` or `NULL` The measure (e.g. `"aggregate"`, `"case"`,
#'   `"treatment"`). Selects the DQ schema **and** is the measure level in the staged
#'   path `.../{data_source}/{data_type}/staged/`. Default `"aggregate"`. Whatever you
#'   pass here, **promote with the same measure** —
#'   `eri_approve(country, disease, data_source, period, data_type = <same>)` — or the
#'   approve will look one level up and find nothing. `NULL` stages channel-level
#'   (four-axis), for the rare measure-less case.
#' @param schema Named list from [load_dq_schema()]. If `NULL` (default), loaded
#'   for `(country, disease, data_source, data_type)`.
#' @param data_con Azure container for the `data` blob. If `NULL` (default),
#'   connects using `ERIFUNCTIONS_DATA_STORAGE_NAME`.
#' @param mirror_pipeline `str` or `NULL` If set (e.g. `"hsp-mal"`), also mirror the
#'   cleaned output to the legacy `projects` blob via that pipeline registry entry.
#'   Default `NULL` (no mirror; sandbox-safe).
#' @param projects_con Azure container for the `projects` blob; used only when
#'   `mirror_pipeline` is set. If `NULL`, connects automatically.
#'
#' @returns Invisibly, the `dq_result` object (`$data`, `$log`, `$flags`).
#' @examples
#' \dontrun{
#' # Default measure is "aggregate", so it stages to
#' # dr/malaria/surveillance/aggregate/staged/ ...
#' result <- eri_ingest("data/raw/dr_malaria_2024W01.xlsx", "dr", "malaria")
#' result$flags  # review before approving
#' # ... and the same measure promotes it:
#' eri_approve("dr", "malaria", "surveillance", "2024W01", data_type = "aggregate")
#' }
#' @export
eri_ingest <- function(path, country, disease,
                       data_source = "surveillance",
                       data_type   = "aggregate",
                       schema      = NULL,
                       data_con    = NULL,
                       mirror_pipeline = NULL,
                       projects_con = NULL) {
  .eri_log_session()

  if (!file.exists(path)) {
    cli::cli_abort("File not found: {.path {path}}")
  }

  # Validate the optional legacy projects-blob mirror up front (fail fast, no I/O).
  mirror <- NULL
  if (!is.null(mirror_pipeline)) {
    reg <- .eri_pipeline_registry[[mirror_pipeline]]
    if (is.null(reg)) {
      cli::cli_abort(c(
        "Unknown pipeline {.val {mirror_pipeline}}.",
        "i" = "Registered pipelines: {paste(names(.eri_pipeline_registry), collapse = ', ')}."
      ))
    }
    subfolder <- reg$country_map[[country]]
    if (is.null(subfolder)) {
      cli::cli_abort(c(
        "Country {.val {country}} is not registered for pipeline {.val {mirror_pipeline}}.",
        "i" = "Registered countries: {paste(names(reg$country_map), collapse = ', ')}."
      ))
    }
    mirror <- list(reg = reg, subfolder = subfolder)
  }

  if (is.null(data_con)) {
    data_con <- suppressMessages(
      get_azure_storage_connection(
        storage_name = Sys.getenv("ERIFUNCTIONS_DATA_STORAGE_NAME", "data")
      )
    )
  }

  if (is.null(schema)) {
    schema <- load_dq_schema(country, disease, data_source, data_type, azcontainer = data_con)
  }

  raw_data <- eri_read(path, azure = FALSE)
  if (is.list(raw_data) && !is.data.frame(raw_data)) {
    raw_data <- raw_data[[1]]
    cli::cli_alert_info("Multi-sheet Excel detected: using first sheet for DQ.")
  }

  result <- run_dq_checks(raw_data, schema)
  dq_report(result)

  fname_parquet <- paste0(tools::file_path_sans_ext(basename(path)), ".parquet")
  # Five-axis staging (ADR-0012): the measure lands in the path, so a later
  # eri_approve(country, disease, data_source, period, data_type) promotes it.
  # c() drops a NULL data_type, so a measure-less ingest stays four-axis.
  staged_dir    <- eri_data_path(country, disease, data_source, data_type, "staged")
  log_dir       <- paste(c(country, disease, data_source, data_type, "logs"), collapse = "/")

  op_log <- list(
    operation  = "eri_ingest",
    analyst    = .eri_analyst_id(),
    started_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    parameters = list(path = path, country = country, disease = disease,
                      data_source = data_source, data_type = data_type,
                      mirror_pipeline = mirror_pipeline),
    status     = "in_progress",
    steps      = list(),
    error      = NULL,
    files      = NULL
  )

  written   <- character(0)
  had_error <- FALSE
  err_msg   <- NULL

  tryCatch({
    if (!AzureStor::storage_dir_exists(data_con, staged_dir)) {
      AzureStor::create_storage_dir(data_con, staged_dir)
      op_log$steps <- .eri_log_step(op_log$steps, "create_staged_dir", path = staged_dir)
    }

    data_dest <- paste0(staged_dir, "/", fname_parquet)
    withr::with_tempfile("parquet_file", fileext = ".parquet", {
      arrow::write_parquet(result$data, parquet_file)
      .eri_blob_write(data_con, parquet_file, data_dest)
    })
    written      <- c(written, data_dest)
    op_log$steps <- .eri_log_step(op_log$steps, "write_data_blob", dest = data_dest)
    .eri_say_done("Staged to data blob: {.path {data_dest}}")

    # Optional legacy projects-blob mirror (transitional; removed at the Phase-3 cutover).
    if (!is.null(mirror)) {
      if (is.null(projects_con)) {
        projects_con <- suppressMessages(get_azure_storage_connection())
      }
      proj_dest <- paste0(mirror$reg$project_folder, "/intermediate/",
                          mirror$subfolder, "/", fname_parquet)
      withr::with_tempfile("parquet_file", fileext = ".parquet", {
        arrow::write_parquet(result$data, parquet_file)
        .eri_blob_write(projects_con, parquet_file, proj_dest)
      })
      written      <- c(written, proj_dest)
      op_log$steps <- .eri_log_step(op_log$steps, "mirror_projects_blob", dest = proj_dest)
      .eri_say_done("Mirrored to projects blob: {.path {proj_dest}}")
    }

    .eri_summary("Ingested to {.path {staged_dir}}", c(
      Rows  = format(nrow(result$data), big.mark = ","),
      Blobs = sprintf("%d written", length(written))
    ))

    # Persist the DQ flags to the log backlog so they are durable and triageable
    # via eri_logs() / eri_logs_resolve(). Never let a logging hiccup break ingest.
    tryCatch(
      eri_dq_log(result, country, disease, data_source, data_type, data_con = data_con),
      error = function(e) cli::cli_alert_warning("Could not log DQ flags: {conditionMessage(e)}")
    )

    op_log$status <- "success"
    op_log$files  <- as.list(written)

  }, error = function(e) {
    had_error <<- TRUE
    err_msg   <<- conditionMessage(e)
  })

  op_log$completed_at <- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  if (had_error) {
    op_log$status <- "error"
    op_log$error  <- err_msg
    op_log$steps  <- .eri_log_step(op_log$steps, "error_caught",
                                    status = "error", message = err_msg)
  }
  .eri_write_log(op_log, data_con, log_dir)
  if (had_error) cli::cli_abort(err_msg, call = NULL)
  invisible(result)
}

# Private functions ----

# Internal registry: pipeline name -> owner/repo/workflow_id/project_folder/country_map
.eri_pipeline_registry <- list(
  "hsp-mal" = list(
    owner          = "thecartercenter",
    repo           = "health-hsp-malaria",
    workflow       = "data_ingestion.yml",
    project_folder = "health-hsp-malaria-dev",
    country_map    = list(
      "dr" = "dom",
      "ht" = "hti"
    )
  ),
  "rb-expansion" = list(
    project_folder = "health-rb-country-expansion-dev",
    country_map    = list(
      "eth" = "eth",
      "nga" = "nga",
      "sdn" = "sdn",
      "ssd" = "ssd",
      "uga" = "uga",
      "mad" = "mad",
      "tcd" = "tcd"
    )
  )
)

#' Resolve the analyst identity for governed actions and audit logs
#'
#' Returns `ERI_ANALYST_ID` when set. When it is not, falls back to the operating
#' system username and warns **once per R session** (via
#' `options(erifunctions.warned_analyst_id)`) so the analyst knows the shared
#' audit trail will be stamped with that fallback rather than their identity.
#' @keywords internal
.eri_analyst_id <- function() {
  id <- Sys.getenv("ERI_ANALYST_ID", unset = "")
  if (nzchar(id)) return(id)

  fallback <- Sys.info()[["user"]]
  if (!isTRUE(getOption("erifunctions.warned_analyst_id"))) {
    options(erifunctions.warned_analyst_id = TRUE)
    cli::cli_warn(c(
      "!" = "{.envvar ERI_ANALYST_ID} is not set; governed actions will be logged as {.val {fallback}}.",
      "i" = "Set it in your {.file .Renviron} so approvals and logs carry your analyst identity."
    ))
  }
  fallback
}

#' Signpost the four-axis (no-measure) approval form
#'
#' When `eri_approve()` runs without a `data_type`, the dataset is filed and
#' catalogued at the channel level with `data_type = NA` (the measure). That is a
#' legitimate choice for channel-only data (e.g. ODK), but it is indistinguishable
#' from forgetting the measure, so we say so **once per R session** (guarded by
#' `options(erifunctions.noted_no_measure)`) rather than on every call. No-op when a
#' measure is supplied.
#' @keywords internal
.eri_note_no_measure <- function(data_type) {
  if (!is.null(data_type)) return(invisible(NULL))
  if (isTRUE(getOption("erifunctions.noted_no_measure"))) return(invisible(NULL))
  options(erifunctions.noted_no_measure = TRUE)
  cli::cli_inform(c(
    "i" = "Approving the channel-level (no-measure) form; the catalog entry's {.field data_type} will be {.val NA}.",
    " " = "Pass {.arg data_type} (e.g. {.val case}, {.val aggregate}, {.val treatment}) to record a measure (ADR-0012)."
  ))
  invisible(NULL)
}

#' Write a one-time session access entry to the data/ container
#'
#' Fires at most once per R session via `options(erifunctions.session_logged)`.
#' Uses SP credentials directly to avoid a recursive call through
#' `get_azure_storage_connection()`. Fails silently on any error so it never
#' blocks analyst workflow.
#' @keywords internal
.eri_log_session <- function() {
  if (isTRUE(getOption("erifunctions.session_logged"))) return(invisible(NULL))
  options(erifunctions.session_logged = TRUE)

  tryCatch({
    sp_id  <- Sys.getenv("ERIFUNCTIONS_SP_CLIENT_ID")
    sp_sec <- Sys.getenv("ERIFUNCTIONS_SP_CLIENT_SECRET")
    if (nchar(sp_id) == 0 || nchar(sp_sec) == 0) return(invisible(NULL))

    token <- AzureAuth::get_azure_token(
      resource  = "https://storage.azure.com/",
      tenant    = Sys.getenv("ERIFUNCTIONS_TENANT_ID"),
      app       = sp_id,
      auth_type = "client_credentials",
      password  = sp_sec
    )
    data_con <- AzureStor::storage_container(
      AzureStor::storage_endpoint(
        Sys.getenv("ERIFUNCTIONS_RESOURCE_ENDPOINT"), token = token
      ),
      Sys.getenv("ERIFUNCTIONS_DATA_STORAGE_NAME", "data")
    )

    analyst  <- .eri_analyst_id()
    ts_file  <- format(Sys.time(), "%Y%m%d_%H%M%S", tz = "UTC")
    slug     <- gsub("[^A-Za-z0-9]", "_", analyst)
    log_dir  <- "logs/_access"
    log_path <- paste0(log_dir, "/", ts_file, "_", slug, ".yaml")

    entry <- list(
      timestamp   = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
      analyst     = analyst,
      r_version   = as.character(getRversion()),
      pkg_version = as.character(utils::packageVersion("erifunctions")),
      os          = Sys.info()[["sysname"]]
    )

    if (!AzureStor::storage_dir_exists(data_con, log_dir)) {
      AzureStor::create_storage_dir(data_con, log_dir)
    }

    log_file <- tempfile(fileext = ".yaml")
    yaml::write_yaml(entry, log_file)
    .eri_blob_write(data_con, log_file, log_path)
    unlink(log_file)
  }, error = function(e) {
    # Fail silently — session logging must never block analyst workflow
  })
  invisible(NULL)
}

#' Append a timestamped step entry to an operation log's steps list
#' @keywords internal
.eri_log_step <- function(steps, step, status = "success", ...) {
  entry <- c(
    list(step      = step,
         status    = status,
         timestamp = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")),
    list(...)
  )
  c(steps, list(entry))
}

#' Write a structured operation log YAML to the Azure logs/ directory
#'
#' Wraps in its own tryCatch so a logging failure never masks the original error.
#' @keywords internal
.eri_write_log <- function(log_list, azcontainer, log_dir) {
  tryCatch({
    if (!AzureStor::storage_dir_exists(azcontainer, log_dir)) {
      AzureStor::create_storage_dir(azcontainer, log_dir)
    }
    ts       <- format(Sys.time(), "%Y%m%d_%H%M%S", tz = "UTC")
    op       <- if (is.null(log_list$operation)) "op" else log_list$operation
    period   <- log_list$parameters$period
    per_slug <- if (!is.null(period)) gsub("[^A-Za-z0-9_-]", "", period) else ""
    fname    <- paste0(ts, "_", op,
                       if (nchar(per_slug) > 0) paste0("_", per_slug) else "",
                       ".yaml")
    log_path <- paste0(log_dir, "/", fname)
    log_file <- tempfile(fileext = ".yaml")
    yaml::write_yaml(log_list, log_file)
    .eri_blob_write(azcontainer, log_file, log_path)
    unlink(log_file)
    cli::cli_alert_info("Operation log: {.path {log_path}}")
  }, error = function(e) {
    cli::cli_alert_warning("Could not write operation log to Azure: {conditionMessage(e)}")
  })
  invisible(NULL)
}

#' Reads an Excel file from Azure to the R environment
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' This function is an extension of the readxl() that adapts to files with
#' multiple tabs. If there are multiple tabs, each sheet are downloaded into a
#' named list with the corresponding tab name.
#'
#' @details
#' Actually, this function doesn't need to be used on Azure files. It can work
#' with local files as well.
#'
#'
#' @param src `str` Path to the Excel file.
#' @param sheet `int` or `str` Sheet to read. Either a string (the name of a sheet),
#' or an integer (the position of the sheet).
#' Ignored if the sheet is specified via range. If neither argument specifies the sheet,
#' defaults to the first sheet.
#' @param ... Additional parameters of [readxl::read_excel()].
#'
#' @returns `tibble` or `list` A tibble or a list of tibbles containing data from
#' the Excel file.
#' @keywords internal
#'
read_excel_from_azure <- function(src, sheet = NULL, ...) {

  if (!is.null(sheet)) {
    output <- readxl::read_excel(path = src, sheet = sheet, ...)
  } else {
    sheets <- readxl::excel_sheets(src)
    output <- purrr::map(sheets, \(x) readxl::read_excel(path = src, sheet = x, ...))
    names(output) <- sheets
  }

  return(output)
}
