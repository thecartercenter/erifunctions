# Write a one-time session access entry to the data/ container

Fires at most once per R session via
`options(erifunctions.session_logged)`. Uses SP credentials directly to
avoid a recursive call through
[`get_azure_storage_connection()`](https://thecartercenter.github.io/erifunctions/reference/get_azure_storage_connection.md).
Fails silently on any error so it never blocks analyst workflow.

## Usage

``` r
.eri_log_session()
```
