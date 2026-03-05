#Helper functions for interaction with ODK Central


#' Initialize/test ODK connection
#' @description
#' Have a user prompt to enter username and password and then
#' save the resulting token to be used for this session
#' @param url `chr` Target URL for the ODK Central API
#' @param user `chr` Username
#' @param pass `chr` Password
#' @param testing `bool` Should results be evaluated for testing
#' @param verbose `bool` Should the function return character with information
#' or a boolean vector verifying connection
#' @return `chr`/`bool` Verbose response or a T/F
#' @export
init_odk_connection <- function(
    url = yaml::read_yaml(here::here("sandbox/keys.yaml"))$odk$url,
    user = yaml::read_yaml(here::here("sandbox/keys.yaml"))$odk$name,
    pass = yaml::read_yaml(here::here("sandbox/keys.yaml"))$odk$pass,
    testing = FALSE,
    verbose = TRUE
){

  if(testing){
    x <- httr::GET(
      url = "https://api.ipify.org/?format=json"
    )

    x <- httr::content(x)

    Sys.setenv("ODK_TOKEN" = x$ip)
  }else{
    x <- httr::POST(
      url = httr::modify_url(url, path = glue::glue("v1/sessions")),
      body = list(
        "email" = user,
        "password" = pass
      ),
      encode = "json"
    )

    x <- httr::content(x)

    Sys.setenv("ODK_TOKEN" = x$token)
    Sys.setenv("ODK_CSRF" = x$csrf)
    Sys.setenv("ODK_URL" = url)
  }

  if(verbose){
    cli::cli_alert_info(paste0("Your session has been validated at ", x$createdAt,
                               " and will remain active until ", x$expiresAt,
                               ". Your ODK session token has been cached and will
                             remain active until you restart this R session"))

  }else{
    return(!Sys.getenv("ODK_TOKEN") == "")
  }
}

#' List ODK projects
#' @description
#' Given verified access, list all projects the user can access
#' @param url `chr` Target URL for the ODK Central API
#' @param auth `chr` Authorization token to access URL
#' @param testing `bool` T/F if you want to just verify that the API if working
#' @returns `tibble` Output of all projects from API call
#' @export
list_odk_projects <- function(
    url = Sys.getenv("ODK_URL"),
    auth = Sys.getenv("ODK_TOKEN"),
    testing = FALSE
){

  if(testing){
    (httr::GET(
      url = httr::modify_url(url, path = glue::glue("v1/example2"))
    ) |>
      httr::content())$code
  }else{
    x <- httr::GET(
      url = httr::modify_url(url, path = glue::glue("v1/projects")),
      config = httr::add_headers(
        "Authorization" = paste0("Bearer ", auth),
        "forms" = "true"
      )
    )

    x <- httr::content(x)

    out <- lapply(1:length(x), function(i){
      tibble::tibble(
        "project_id" = x[[i]]$id,
        "project" = x[[i]]$name,
        "description" = x[[i]]$description
      )
    }) |> dplyr::bind_rows()

    return(out)
  }
}

#' List ODK forms
#' @description
#' Given verified access and a project id, list all forms under a project
#' @param url `chr` Target URL for the ODK Central API
#' @param auth `chr` Authorization token to access URL
#' @param project_id `int` Project id from `list_odk_projects()`
#' @param testing `bool` T/F if you want to just verify that the API if working
#' @returns `tibble` Output of all forms within a project from API call
#' @export
list_odk_forms <- function(
    url = Sys.getenv("ODK_URL"),
    auth = Sys.getenv("ODK_TOKEN"),
    project_id,
    testing = FALSE
){

  if(testing){
    (httr::GET(
      url = httr::modify_url(url, path = glue::glue("v1/example2"))
    ) |>
      httr::content())$code
  }else{
    x <- httr::GET(
      url = paste0(url, "v1/projects/",project_id,"/forms"),
      config = httr::add_headers(
        "Authorization" = paste0("Bearer ", auth)
      )
    )

    x <- httr::content(x)

    out <- lapply(1:length(x), function(i){
      x[[i]] |> unlist() |> t() |>  tibble::as_tibble()
    }) |> dplyr::bind_rows() |>
      dplyr::select("xmlFormId", "name")

    return(out)
  }
}

#' Download ODK form data
#' @description
#' Given verified access, project id and form ID, download all data from an
#' ODK form
#' @param url `chr` Target URL for the ODK Central API
#' @param auth `chr` Authorization token to access URL
#' @param project_id `int` Project id from `list_odk_projects()`
#' @param form_id `chr` From id from `list_odk_forms()`
#' @param testing `bool` T/F if you want to just verify that the API if working
#' @returns `tibble` Download of all data from an ODK form
#' @importFrom utils unzip
#' @export
download_odk_form <- function(
    url = Sys.getenv("ODK_URL"),
    auth = Sys.getenv("ODK_TOKEN"),
    project_id,
    form_id,
    testing = FALSE
){

  form_id <- URLencode(form_id)

  if(testing){
    (httr::GET(
      url = httr::modify_url(url, path = glue::glue("v1/example2"))
    ) |>
      httr::content())$code
  }else{
    tmp_file <- tempfile(fileext = ".csv.zip")

    x <- httr::GET(
      url = paste0(url, "v1/projects/",project_id,
                   "/forms/",form_id,"/submissions.csv.zip"),
      config = httr::add_headers(
        "Authorization" = paste0("Bearer ", auth)
      ),
      httr::write_disk(tmp_file, overwrite = T)
    )

    unzip(tmp_file, exdir = tempdir())

    out <- readr::read_csv(paste0(tempdir(),"/",form_id,".csv"))

    return(out)
  }
}

#' List all users in ODK
#' @description
#' Given verified access list all users
#' @param url `chr` Target URL for the ODK Central API
#' @param auth `chr` Authorization token to access URL
#' @param project_id `int` The project id for which you want to identify users
#' @param testing `bool` T/F if you want to just verify that the API if working
#' @returns `tibble` Output of all app-users in the project
#' @export
list_all_odk_app_users <- function(
    url = Sys.getenv("ODK_URL"),
    auth = Sys.getenv("ODK_TOKEN"),
    project_id,
    testing = FALSE
){

  if(testing){
    (httr::GET(
      url = httr::modify_url(url, path = glue::glue("v1/example2"))
    ) |>
      httr::content())$code
  }else{
    x <- httr::GET(
      url = paste0(url, "v1/projects/",project_id,"/app-users/"),
      config = httr::add_headers(
        "Authorization" = paste0("Bearer ", auth)
      )
    )

    x <- httr::content(x)

    out <- lapply(1:length(x), function(i){
      x[[i]] |> unlist() |> t() |>  tibble::as_tibble()
    }) |> dplyr::bind_rows()

    return(out)
  }
}

#' See all users who have access to a form
#' @description
#' Given verified access list all users
#' @param url `chr` Target URL for the ODK Central API
#' @param auth `chr` Authorization token to access URL
#' @param project_id `int` The project id for which you want to identify users
#' @param form_id `chr` The form id for which we want to identify users
#' @param testing `bool` T/F if you want to just verify that the API if working
#' @returns `tibble` Output of all form users and roles within a given form
#' @export
list_odk_form_users <- function(
    url = Sys.getenv("ODK_URL"),
    auth = Sys.getenv("ODK_TOKEN"),
    project_id,
    form_id,
    testing = FALSE
){

  form_id <- URLencode(form_id)

  if(testing){
    (httr::GET(
      url = httr::modify_url(url, path = glue::glue("v1/example2"))
    ) |>
      httr::content())$code
  }else{
    x <- httr::GET(
      url = paste0(url, "v1/projects/",project_id,"/forms/",form_id,"/assignments"),
      config = httr::add_headers(
        "Authorization" = paste0("Bearer ", auth)
      )
    )

    x <- httr::content(x)

    out <- lapply(1:length(x), function(i){
      x[[i]] |> unlist() |> t() |>  tibble::as_tibble()
    }) |> dplyr::bind_rows()

    return(out)
  }
}

#' Create/Delete/Assign/Un-assign app users
#' @description
#' Given an action, project id, form id, role id and actor id,
#' update the access that a specific app user is provided
#' @param action `chr` 'create': Create a general app-user;
#' 'delete': Delete an app-user;
#' 'assign': Assign an app-user a role within a specific form
#' 'revoke': Revoke an app-user role within a specific form
#' assign, revoke
#' @param project_id `int` The project id for which you want to identify users
#' @param form_id `chr` The form id for which you want to identify users
#' @param actor_name `chr` The display name of the actor to be updated
#' @param role_id `int` The role id which you want to assign, usually 2
#' @param actor_id `int` The actor id to be deleted
#' @param testing `bool` T/F if you want to just verify that the API if working
#' @param url `chr` Target URL for the ODK Central API
#' @param auth `chr` Authorization token to access URL
#' @export
update_odk_app_user_role <- function(
    action,
    project_id,
    form_id = NULL,
    actor_name = NULL,
    role_id = NULL,
    actor_id = NULL,
    testing = FALSE,
    url = Sys.getenv("ODK_URL"),
    auth = Sys.getenv("ODK_TOKEN")
){

  form_id <- URLencode(form_id)

  if(!action %in% c("create", "delete", "assign", "revoke")){
    stop("Action must be 'create', 'delete', 'assign' or 'revoke'")
  }

  if(action == "create" & is.null(actor_name)){
    stop("An 'actor_name' is necessary to create an app-user")
  }

  if(action == "delete" & is.null(actor_id)){
    stop("An 'actor_id' is necessary to delete an app-user")
  }

  if(action %in% c("assign", "revoke") & is.null(form_id)){
    stop("A 'form_id' must be specified to assign or revoke access")
  }

  if(action %in% c("assign", "revoke") & is.null(role_id)){
    stop("A 'role_id' must be specified to assign or revoke access")
  }

  if(action %in% c("assign", "revoke") & is.null(actor_id)){
    stop("An 'actor_id' is necessary to assign or evoke permissions.")
  }

  if(testing){
    (httr::GET(
      url = httr::modify_url(url, path = glue::glue("v1/example2"))
    ) |>
      httr::content())$code
    stop()
  }

  if(action == "create"){
    x <- httr::POST(
      url = paste0(url,"v1/projects/",project_id,"/app-users"),
      config = httr::add_headers(
        "Authorization" = paste0("Bearer ", auth)
      ),
      body = list(
        "displayName" = actor_name
      ),
      encode = "json"
    ) |> httr::content()

    return(
      list(
        "actor_name" = x$displayName,
        "actor_id" = x$id,
        "project_id" = x$projectId
      )
    )
  }

  if(action == "delete"){
    x <- httr::DELETE(
      url = paste0(url,"v1/projects/",project_id,"/app-users/", actor_id),
      config = httr::add_headers(
        "Authorization" = paste0("Bearer ", auth)
      )
    ) |> httr::content()

    if("success" %in% names(x)){
      return(x$success)
    }else{
      return(F)
    }
  }

  if(action == "assign"){
    x <- httr::POST(
      url = paste0(url,"v1/projects/",project_id,"/forms/", form_id,
                   "/assignments/",role_id,"/",actor_id),
      config = httr::add_headers(
        "Authorization" = paste0("Bearer ", auth)
      )
    ) |> httr::content()


    if("success" %in% names(x)){
      return(x$success)
    }else{
      return(F)
    }
  }

  if(action == "revoke"){
    x <- httr::DELETE(
      url = paste0(url,"v1/projects/",project_id,"/forms/", form_id,
                   "/assignments/",role_id,"/",actor_id),
      config = httr::add_headers(
        "Authorization" = paste0("Bearer ", auth)
      )
    ) |> httr::content()


    if("success" %in% names(x)){
      return(x$success)
    }else{
      return(F)
    }
  }

}

#' See all users who have access to a form
#' @description
#' Pull all media attachments from a form
#' @param url `chr` Target URL for the ODK Central API
#' @param auth `chr` Authorization token to access URL
#' @param project_id `int` The project id for which you want to identify attachments
#' @param form_id `chr` The form id for which we want to identify attachments
#' @param folder_loc `chr` The folder in which all images should be dumped out
#' @param condition `chr` The dplyr::filter() command to filter the downloaded data
#' @returns `tibble` Output of all attachment names and their links to the forms
#' @importFrom rlang .data
#' @export
download_form_attachments <- function(
    url = Sys.getenv("ODK_URL"),
    auth = Sys.getenv("ODK_TOKEN"),
    project_id,
    form_id,
    folder_loc,
    condition = NULL
){

  form_id <- URLencode(form_id)

  if(!dir.exists(folder_loc)){
    cli::cli_alert("Folder not found, creating folder.")
    dir.create(folder_loc)
  }

  cli::cli_process_start("Downloading ODK form data")
  form_data <- download_odk_form(project_id = project_id, form_id = form_id) |>
    dplyr::filter(.data$AttachmentsExpected != 0) |>
    dplyr::select("Filter_Paper-fpbarcode", "meta-instanceID",
                  "AttachmentsExpected", "AttachmentsPresent")
  cli::cli_process_done()

  if(!is.null(condition)){
    form_data <- form_data |>
      dplyr::filter({{ condition }})
  }

  cli::cli_process_start("Downloading form attachments list")
  attachments <- lapply(
    1:nrow(form_data), function(i){
      instance_id <- form_data |> dplyr::slice(i) |> dplyr::pull("meta-instanceID")

      list_of_attachments <- httr::GET(
        url = paste0(url, "v1/projects/",project_id,
                     "/forms/",form_id,"/submissions/", instance_id, "/attachments"),
        config = httr::add_headers(
          "Authorization" = paste0("Bearer ", auth))) |>
        httr::content()

      lapply(1:length(list_of_attachments), function(x){
        list_of_attachments[[x]] |>
          unlist() |>
          t() |>
          tibble::as_tibble() |>
          dplyr::mutate(instance_id)
      }
      ) |>
        dplyr::bind_rows()
    }

  ) |>
    dplyr::bind_rows()
  cli::cli_process_done()

  download_dataset <- dplyr::left_join(
    attachments,
    form_data,
    by = c("instance_id" = "meta-instanceID")
  )

  lapply(
    cli::cli_progress_along(1:nrow(download_dataset), "Downloading"), function(i){

      instance_id <- download_dataset |> dplyr::slice(i) |> dplyr::pull("instance_id")
      filename <- download_dataset |> dplyr::slice(i) |> dplyr::pull("name")

      x <- httr::GET(
        url = paste0(url, "v1/projects/",project_id,
                     "/forms/",form_id,"/submissions/", instance_id, "/attachments/", filename),
        config = httr::add_headers(
          "Authorization" = paste0("Bearer ", auth)))

      # Open a file connection in write-binary mode ('wb')
      out_name <- paste0(folder_loc, "/",
                         dplyr::slice(download_dataset, i) |> dplyr::pull("Filter_Paper-fpbarcode"),
                         ".jpeg")
      fid <- file(out_name, "wb")
      # Write the data
      writeBin(x$content, fid)
      # Close the connection
      close(fid)
    }
  )

  return(download_dataset)

}

