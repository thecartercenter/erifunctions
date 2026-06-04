# DAL - Data Access Layer

#### 1) Utility functions ####

#' Validate connection to Azure
#'
#' Generate token which connects to TCC Azure resources and
#' validates that the individual still has access.
#'
#' @param app_id `str` Application ID. Defaults to `Sys.getenv("ERIFUNCTIONS_APP_ID")`.
#' @param tenant_id `str` ID of the Azure tenant. Defaults to `Sys.getenv("ERIFUNCTIONS_TENANT_ID")`.
#' @param resource_endpoint `str` URL used to connect to the Azure resource.
#' Defaults to `Sys.getenv("ERIFUNCTIONS_RESOURCE_ENDPOINT")`.
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
    tenant_id = Sys.getenv("ERIFUNCTIONS_TENANT_ID"),
    app_id = Sys.getenv("ERIFUNCTIONS_APP_ID"),
    resource_endpoint = Sys.getenv("ERIFUNCTIONS_RESOURCE_ENDPOINT"),
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
      return(azure_io(io = "read", file_loc, azcontainer = azcontainer, ...))
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
        return(readr::read_csv(file_loc))
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
      azure_io(io = "upload", file_loc = file_loc, local_path = obj, azcontainer = azcontainer)
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

  return(NULL)
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
    ...) {

  opts <- c("read", "write", "delete", "delete.dir",
            "list", "exists.dir", "exists.file", "create", "upload")

  if (!io %in% opts) {
    stop("io: must be 'read', 'write', 'exists.dir', 'exists.file','create', 'delete' 'delete.dir' 'list' or 'upload'")
  }

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
        AzureStor::create_storage_dir(azcontainer, file_loc)
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

      return(suppressWarnings(AzureStor::storage_read_csv(azcontainer, file_loc, ...)))

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
eri_read <- function(file_loc, ..., azure = TRUE, azcontainer = NULL) {
  if (azure) .eri_log_session()
  if (azure && is.null(azcontainer)) azcontainer <- suppressMessages(get_azure_storage_connection())
  erifunctions_io("read", file_loc = file_loc, azure = azure, azcontainer = azcontainer, ...)
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
#' Thin wrapper around [erifunctions_io()] for deleting a directory.
#'
#' @inheritParams erifunctions_io
#' @export
eri_dir_delete <- function(file_loc, azure = TRUE, azcontainer = NULL) {
  if (azure) .eri_log_session()
  if (azure && is.null(azcontainer)) azcontainer <- suppressMessages(get_azure_storage_connection())
  erifunctions_io("delete.dir", file_loc = file_loc, azure = azure, azcontainer = azcontainer)
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
#' Constructs a canonical blob storage path following the erifunctions
#' three-layer data model: `{country}/{disease}/{data_type}/{layer}/`.
#' Use this instead of hard-coding path strings to ensure consistency
#' across all pipeline steps.
#'
#' @param country `str` Country code (e.g. `"dr"`, `"ht"`, `"ug"`).
#' @param disease `str` Disease name (e.g. `"malaria"`, `"lf"`, `"oncho"`).
#' @param data_type `str` Data input type: `"surveillance"`, `"cmr"`, or `"odk"`.
#' @param layer `str` Pipeline layer: `"raw"`, `"staged"`, or `"processed"`.
#' @param filename `str` Optional filename to append. If `NULL` (default), returns
#'   the directory path only.
#' @returns A character string with the canonical blob path.
#' @examples
#' eri_data_path("dr", "malaria", "surveillance", "staged")
#' #> "dr/malaria/surveillance/staged"
#'
#' eri_data_path("dr", "malaria", "surveillance", "raw", "2024_dr_malaria.parquet")
#' #> "dr/malaria/surveillance/raw/2024_dr_malaria.parquet"
#' @export
eri_data_path <- function(country, disease, data_type, layer, filename = NULL) {
  valid_types  <- c("surveillance", "cmr", "odk")
  valid_layers <- c("raw", "staged", "processed")

  if (!data_type %in% valid_types) {
    cli::cli_abort(
      "{.arg data_type} must be one of {.val {valid_types}}, not {.val {data_type}}."
    )
  }
  if (!layer %in% valid_layers) {
    cli::cli_abort(
      "{.arg layer} must be one of {.val {valid_layers}}, not {.val {layer}}."
    )
  }

  parts <- c(country, disease, data_type, layer)
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
#' falling back to `Sys.info()[["user"]]` if unset.
#'
#' An operation log capturing every step (including errors) is always written to
#' `{country}/{disease}/{data_type}/logs/` in the data container, regardless of
#' whether the approval succeeds or fails. This log is the primary debugging
#' artifact for pipeline issues.
#'
#' @param country `str` Country code (e.g. `"dr"`, `"ht"`).
#' @param disease `str` Disease name (e.g. `"malaria"`).
#' @param data_type `str` Data input type: `"surveillance"`, `"cmr"`, or `"odk"`.
#' @param period `str` Period string matched against staged filenames (e.g.
#'   `"2024-W01"`, `"2024-01"`). Any staged file whose name contains this string
#'   is promoted.
#' @param azcontainer Azure container object for the `data/` blob, returned by
#'   [get_azure_storage_connection()]. If `NULL` (default), connects automatically
#'   using `ERIFUNCTIONS_DATA_STORAGE_NAME`.
#' @returns Invisibly, a character vector of the promoted file paths in `processed/`.
#' @examples
#' \dontrun{
#' eri_approve("dr", "malaria", "surveillance", "2024-W01")
#' }
#' @export
eri_approve <- function(country, disease, data_type, period, azcontainer = NULL) {
  .eri_log_session()
  if (is.null(azcontainer)) {
    azcontainer <- suppressMessages(
      get_azure_storage_connection(
        storage_name = Sys.getenv("ERIFUNCTIONS_DATA_STORAGE_NAME", "data")
      )
    )
  }

  analyst_id    <- Sys.getenv("ERI_ANALYST_ID", unset = Sys.info()[["user"]])
  staged_dir    <- eri_data_path(country, disease, data_type, "staged")
  processed_dir <- eri_data_path(country, disease, data_type, "processed")
  log_dir       <- paste(c(country, disease, data_type, "logs"), collapse = "/")

  op_log <- list(
    operation  = "eri_approve",
    analyst    = analyst_id,
    started_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    parameters = list(country = country, disease = disease,
                      data_type = data_type, period = period),
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
      AzureStor::storage_download(azcontainer, src_path, tmp_file, overwrite = TRUE)
      AzureStor::storage_upload(azcontainer, tmp_file, dest_path)
      unlink(tmp_file)
      AzureStor::delete_storage_file(azcontainer, src_path, confirm = FALSE)
      moved <- c(moved, dest_path)
      op_log$steps <- .eri_log_step(op_log$steps, "move_file",
                                     src = src_path, dest = dest_path)
      cli::cli_alert_success("Approved: {.path {basename(src_path)}}")
    }

    # Human-readable approval record stored alongside the data
    approval <- list(
      analyst   = analyst_id,
      timestamp = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
      period    = period,
      country   = country,
      disease   = disease,
      data_type = data_type,
      files     = as.list(moved)
    )
    approval_path <- paste0(processed_dir, "/", period, "_approval_log.yaml")
    approval_file <- tempfile(fileext = ".yaml")
    yaml::write_yaml(approval, approval_file)
    AzureStor::storage_upload(azcontainer, approval_file, approval_path)
    unlink(approval_file)
    op_log$steps <- .eri_log_step(op_log$steps, "write_approval_log",
                                   path = approval_path)
    cli::cli_alert_success("Approval log: {.path {approval_path}}")

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
    analyst    = Sys.getenv("ERI_ANALYST_ID", unset = Sys.info()[["user"]]),
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
      AzureStor::storage_download(projects_con, src_path, tmp, overwrite = TRUE)
      AzureStor::storage_upload(data_con, tmp, dest_path)
      unlink(tmp)
      staged <- c(staged, dest_path)
      op_log$steps <- .eri_log_step(op_log$steps, "stage_file",
                                     src = src_path, dest = dest_path)
      cli::cli_alert_success("Staged: {.path {fname}}")
    }

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

#' Ingest a local surveillance file and write cleaned output to both blob targets
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' The primary analyst entry point for surveillance ingestion. Reads a raw local
#' Excel file, runs all DQ checks via [run_dq_checks()], then dual-writes the
#' cleaned parquet output to:
#' 1. `projects/{project_folder}/intermediate/{country_subfolder}/` — mirrors the
#'    GHA pipeline output for side-by-side comparison.
#' 2. `data/{country}/{disease}/surveillance/staged/` — feeds [eri_approve()].
#'
#' DQ flags are printed to the console immediately after checks complete so the
#' analyst can review issues before calling [eri_approve()].
#'
#' @param path `str` Local path to the raw Excel file to ingest.
#' @param country `str` Country code (e.g. `"dr"`, `"ht"`).
#' @param disease `str` Disease name (e.g. `"malaria"`).
#' @param pipeline `str` Registry entry that controls which `project_folder` and
#'   `country_map` are used for the projects blob write. Default `"hsp-mal"`.
#' @param schema Named list returned by [load_dq_schema()]. If `NULL` (default),
#'   auto-loaded for the given country and disease.
#' @param projects_con Azure container object for the `projects` blob. If `NULL`
#'   (default), connects automatically using [get_azure_storage_connection()].
#' @param data_con Azure container object for the `data` blob. If `NULL`
#'   (default), connects using `ERIFUNCTIONS_DATA_STORAGE_NAME`.
#'
#' @returns Invisibly, the `dq_result` object so the analyst can inspect
#'   `$data`, `$log`, and `$flags`.
#' @examples
#' \dontrun{
#' result <- eri_ingest("data/raw/dr_malaria_2024W01.xlsx", "dr", "malaria")
#' result$flags  # review before approving
#' eri_approve("dr", "malaria", "surveillance", "2024W01")
#' }
#' @export
eri_ingest <- function(path, country, disease,
                       pipeline     = "hsp-mal",
                       schema       = NULL,
                       projects_con = NULL,
                       data_con     = NULL) {
  .eri_log_session()

  if (!file.exists(path)) {
    cli::cli_abort("File not found: {.path {path}}")
  }

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

  if (is.null(data_con)) {
    data_con <- suppressMessages(
      get_azure_storage_connection(
        storage_name = Sys.getenv("ERIFUNCTIONS_DATA_STORAGE_NAME", "data")
      )
    )
  }
  if (is.null(projects_con)) {
    projects_con <- suppressMessages(get_azure_storage_connection())
  }

  if (is.null(schema)) {
    schema_country <- .eri_schema_country_map[[country]] %||% country
    schema <- load_dq_schema(schema_country, disease, azcontainer = data_con)
  }

  raw_data <- eri_read(path, azure = FALSE)
  if (is.list(raw_data) && !is.data.frame(raw_data)) {
    raw_data <- raw_data[[1]]
    cli::cli_alert_info("Multi-sheet Excel detected: using first sheet for DQ.")
  }

  result <- run_dq_checks(raw_data, schema)
  dq_report(result)

  fname_parquet <- paste0(tools::file_path_sans_ext(basename(path)), ".parquet")
  staged_dir    <- eri_data_path(country, disease, "surveillance", "staged")
  projects_dir  <- paste0(reg$project_folder, "/intermediate/", subfolder)
  log_dir       <- paste(c(country, disease, "surveillance", "logs"), collapse = "/")

  op_log <- list(
    operation  = "eri_ingest",
    analyst    = Sys.getenv("ERI_ANALYST_ID", unset = Sys.info()[["user"]]),
    started_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    parameters = list(path = path, country = country,
                      disease = disease, pipeline = pipeline),
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
      AzureStor::storage_upload(data_con, parquet_file, data_dest)
    })
    written      <- c(written, data_dest)
    op_log$steps <- .eri_log_step(op_log$steps, "write_data_blob", dest = data_dest)
    cli::cli_alert_success("Staged to data blob: {.path {data_dest}}")

    proj_dest <- paste0(projects_dir, "/", fname_parquet)
    withr::with_tempfile("parquet_file", fileext = ".parquet", {
      arrow::write_parquet(result$data, parquet_file)
      AzureStor::storage_upload(projects_con, parquet_file, proj_dest)
    })
    written      <- c(written, proj_dest)
    op_log$steps <- .eri_log_step(op_log$steps, "write_projects_blob", dest = proj_dest)
    cli::cli_alert_success("Written to projects blob: {.path {proj_dest}}")

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

# Maps short country codes to bundled schema country names
.eri_schema_country_map <- list(
  "dr" = "dominican_republic",
  "ht" = "haiti"
)

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

    analyst  <- Sys.getenv("ERI_ANALYST_ID", unset = Sys.info()[["user"]])
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
    AzureStor::storage_upload(data_con, log_file, log_path)
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
    AzureStor::storage_upload(azcontainer, log_file, log_path)
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
