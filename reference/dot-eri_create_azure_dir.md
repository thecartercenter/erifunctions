# Ensure an Azure directory exists, creating any missing parents.

ADLS Gen2 rejects a trailing slash in directory operations (HTTP 400,
"the request URI is invalid") and does not reliably create intermediate
parents, so we strip trailing slashes and create each level of the path
that is missing. On flat blob storage these are cheap no-ops. This is
the canonical directory-creation primitive:
[`azure_io()`](https://thecartercenter.github.io/erifunctions/reference/azure_io.md)'s
`"create"` op and every nested-path write site (`research.R`,
`artifacts.R`, `catalog.R`, `odk_registry.R`, `onboarding.R`, `cmr.R`,
`templates.R`) route through it rather than calling
[`AzureStor::create_storage_dir()`](https://rdrr.io/pkg/AzureStor/man/generics.html)
directly.

## Usage

``` r
.eri_create_azure_dir(azcontainer, path)
```

## Arguments

- azcontainer:

  Azure container object.

- path:

  `chr` Directory path to ensure exists.

## Value

The trimmed path (invisibly).
