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
  if (is.null(azcontainer)) azcontainer <- suppressMessages(get_azure_storage_connection())
  erifunctions_io("upload", obj = local_path, file_loc = file_loc, azure = TRUE, azcontainer = azcontainer)
}

# Private functions ----

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
