# Validate connection to Azure

Generate token which connects to TCC Azure resources and validates that
the individual still has access.

## Usage

``` r
get_azure_storage_connection(
  tenant_id = Sys.getenv("ERIFUNCTIONS_TENANT_ID"),
  app_id = Sys.getenv("ERIFUNCTIONS_APP_ID"),
  resource_endpoint = Sys.getenv("ERIFUNCTIONS_RESOURCE_ENDPOINT"),
  storage_name = Sys.getenv("ERIFUNCTIONS_STORAGE_NAME"),
  auth = "authorization_code",
  creds_yaml_path = NULL,
  ...
)
```

## Arguments

- tenant_id:

  `str` ID of the Azure tenant. Defaults to
  `Sys.getenv("ERIFUNCTIONS_TENANT_ID")`.

- app_id:

  `str` Application ID. Defaults to `Sys.getenv("ERIFUNCTIONS_APP_ID")`.

- resource_endpoint:

  `str` URL used to connect to the Azure resource. Defaults to
  `Sys.getenv("ERIFUNCTIONS_RESOURCE_ENDPOINT")`.

- storage_name:

  `str` Name of the storage blob. Defaults to
  `Sys.getenv("ERIFUNCTIONS_STORAGE_NAME")`.

- auth:

  `str` Authorization type defaults to `"authorization_code"`, this can
  be changed if you have a service principal.

  Valid values are:`"authorization_code"`, `"device_code"`,
  `"client_credentials"`, `"resource_owner"`, `"on_behalf_of"`.

  See **Details** of
  [`AzureAuth::get_azure_token()`](https://rdrr.io/pkg/AzureAuth/man/get_azure_token.html)
  for further details.

- creds_yaml_path:

  `str` Path to a YAML credentials file containing service principal
  credentials (`tcc_azure$client_id`, `tcc_azure$client_secret`). If
  `NULL` (default) and the environment variables
  `ERIFUNCTIONS_SP_CLIENT_ID` / `ERIFUNCTIONS_SP_CLIENT_SECRET` are set,
  those are used automatically. Otherwise falls back to interactive auth
  via `auth`.

- ...:

  additional parameters passed to
  [`AzureAuth::get_azure_token()`](https://rdrr.io/pkg/AzureAuth/man/get_azure_token.html).

## Value

Azure container object

## Examples

``` r
if (FALSE) { # \dontrun{
azcontainer <- get_azure_storage_connection()
} # }
```
