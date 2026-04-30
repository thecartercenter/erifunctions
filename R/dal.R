# DAL - Data Access Layer

#### 1) Utility functions ####

#' Validate connection to EDAV
#'
#' Generate token which connects to TCC Azure resources and
#' validates that the individual still has access. The current tenant ID
#' is hard coded for TCC RBLF resources.
#'
#' @param app_id `str` Application ID defaults to `"04b07795-8ddb-461a-bbee-02f9e1bf7b46"`,
#' this can be changed if you have a service principal.
#' @param tenant_id `str` ID of the Azure tenant
#' @param storage_endpoint `str` the URL used to connect to the Azure resource
#' @param storage_container `str` the name of the storage blob
#' @param auth `str` Authorization type defaults to `"authorization_code"`,
#' this can be changed if you have a service principal.
#'
#' Valid values are:`"authorization_code"`, `"device_code"`,
#' `"client_credentials"`, `"resource_owner"`, `"on_behalf_of"`.
#'
#' See **Details** of [AzureAuth::get_azure_token()] for further details.
#' @param creds_yaml_path `str` Path to the YAML file in Posit workbench.
#' If `NULL`, the path will be in `"~/credentials/posit_workbench_creds.yaml"`.
#' @param ... additional parameters passed to [AzureAuth::get_azure_token()].
#' @returns Azure container verification
#' @examples
#' \dontrun{
#' azcontainer <- get_azure_storage_connection()
#' }
#'
#' @export
get_azure_storage_connection <- function(
    tenant_id = "16decddb-28ac-4bea-8fc9-5844aadea669",
    app_id = "04b07795-8ddb-461a-bbee-02f9e1bf7b46",
    resource_endpoint = "https://eridev.dfs.core.windows.net/",
    storage_name = "projects",
    auth = "authorization_code",
    creds_yaml_path = NULL,
    ...) {

  if (!is.null(creds_yaml_path)) {
    creds <- yaml::read_yaml(creds_yaml_path)
    mytoken <- AzureAuth::get_azure_token(
      resource = "https://storage.azure.com/",
      tenant = tenant_id,
      app = creds$tcc_azure$client_id,
      auth_type = NULL,
      password = creds$tcc_azure$client_secret
    )
    } else {

      mytoken <- AzureAuth::get_azure_token(
        resource = "https://storage.azure.com/",
        tenant = tenant_id,
        app = app_id,
        auth_type = auth
      )

    }


    endptoken <- AzureStor::storage_endpoint(endpoint = resource_endpoint, token = mytoken)
    azcontainer <- AzureStor::storage_container(endptoken, storage_name)

  return(azcontainer)
}
