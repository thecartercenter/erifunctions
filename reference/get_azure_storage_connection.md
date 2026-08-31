# Validate connection to Azure

Generate token which connects to TCC Azure resources and validates that
the individual still has access.

## Usage

``` r
get_azure_storage_connection(
  tenant_id = Sys.getenv("ERIFUNCTIONS_TENANT_ID", unset = .ERI_DEFAULT_TENANT_ID),
  app_id = Sys.getenv("ERIFUNCTIONS_APP_ID", unset = .ERI_DEFAULT_APP_ID),
  resource_endpoint = Sys.getenv("ERIFUNCTIONS_RESOURCE_ENDPOINT", unset =
    .ERI_DEFAULT_RESOURCE_ENDPOINT),
  storage_name = Sys.getenv("ERIFUNCTIONS_STORAGE_NAME"),
  auth = NULL,
  creds_yaml_path = NULL,
  ...
)
```

## Arguments

- tenant_id:

  `str` Azure tenant. Defaults to the `ERIFUNCTIONS_TENANT_ID` env var,
  or the TCC ERI Entra tenant when unset.

- app_id:

  `str` Application (client) ID. Defaults to the `ERIFUNCTIONS_APP_ID`
  env var, or – when unset – Microsoft's first-party Azure CLI public
  client (`"04b07795-8ddb-461a-bbee-02f9e1bf7b46"`), so interactive auth
  works with no per-user setup.

- resource_endpoint:

  `str` Storage endpoint URL. Defaults to the
  `ERIFUNCTIONS_RESOURCE_ENDPOINT` env var, or the team `eridev` ADLS
  endpoint when unset.

- storage_name:

  `str` Name of the storage blob. Defaults to
  `Sys.getenv("ERIFUNCTIONS_STORAGE_NAME")`.

- auth:

  `str` Authorization type. `NULL` (the default) means *unspecified*:
  ambient service principal credentials are used if present, otherwise
  interactive browser sign-in (`"authorization_code"`), i.e. *you*.

  Valid values are:`"authorization_code"`, `"device_code"`,
  `"client_credentials"`, `"resource_owner"`, `"on_behalf_of"`.

  **Supplying this argument is binding.** If you pass
  `auth = "authorization_code"`, you get interactive sign-in as yourself
  even when service principal credentials are present in the
  environment. Only when `auth` is left `NULL` do ambient service
  principal credentials take over – which is what lets unattended/CI
  contexts authenticate with no code change. See ADR-0028.

  See **Details** of
  [`AzureAuth::get_azure_token()`](https://rdrr.io/pkg/AzureAuth/man/get_azure_token.html)
  for further details.

- creds_yaml_path:

  `str` Path to a YAML credentials file containing service principal
  credentials (`tcc_azure$client_id`, `tcc_azure$client_secret`).
  Supplying it is binding in the same way `auth` is: an explicit
  credentials file outranks the ambient `ERIFUNCTIONS_SP_CLIENT_ID` /
  `ERIFUNCTIONS_SP_CLIENT_SECRET` environment variables. When `NULL`
  (default) those environment variables are used automatically – unless
  `auth` says otherwise.

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
