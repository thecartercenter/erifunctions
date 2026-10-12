# Resolve the ambient connection for the general-purpose DAL verbs, warning if it isn't the `data` container

Used by the 9 verb-named wrappers
([`eri_read()`](https://thecartercenter.github.io/erifunctions/reference/eri_read.md),
[`eri_write()`](https://thecartercenter.github.io/erifunctions/reference/eri_write.md),
[`eri_list()`](https://thecartercenter.github.io/erifunctions/reference/eri_list.md),
[`eri_file_exists()`](https://thecartercenter.github.io/erifunctions/reference/eri_file_exists.md),
[`eri_dir_exists()`](https://thecartercenter.github.io/erifunctions/reference/eri_dir_exists.md),
[`eri_dir_create()`](https://thecartercenter.github.io/erifunctions/reference/eri_dir_create.md),
[`eri_delete()`](https://thecartercenter.github.io/erifunctions/reference/eri_delete.md),
[`eri_dir_delete()`](https://thecartercenter.github.io/erifunctions/reference/eri_dir_delete.md),
[`eri_upload()`](https://thecartercenter.github.io/erifunctions/reference/eri_upload.md))
– NOT by
[`erifunctions_io()`](https://thecartercenter.github.io/erifunctions/reference/erifunctions_io.md)
or
[`azure_io()`](https://thecartercenter.github.io/erifunctions/reference/azure_io.md)
themselves when called directly, which keep their own unwarned
ambient-connect default argument (see their own `@param azcontainer`
docs).

## Usage

``` r
.eri_dal_verb_connect(azcontainer)
```

## Details

Unlike almost every other subsystem in this package (catalog, artifacts,
feedback, logs, odk_registry, cmr, dq, cutover – all of which explicitly
pass
`storage_name = Sys.getenv("ERIFUNCTIONS_DATA_STORAGE_NAME", unset = "data")`),
the verb-named DAL wrappers below call
[`get_azure_storage_connection()`](https://thecartercenter.github.io/erifunctions/reference/get_azure_storage_connection.md)
with no `storage_name` at all, which resolves the *other*, legacy env
var (`ERIFUNCTIONS_STORAGE_NAME`) and lands on whatever that happens to
be set to – often the `projects` container, not `data`, where most
production data actually lives. That produced a real false negative:
[`eri_file_exists()`](https://thecartercenter.github.io/erifunctions/reference/eri_file_exists.md)
answered `FALSE` immediately after a real upload, because it was asking
the wrong container (#331).

Whether the default itself should change to `data` is an open decision
(#331, CLAUDE.md) – not made here. This only makes the mismatch loud
instead of silent, so a caller relying on the ambient connection finds
out before a false negative (or an unintended write) looks like success.
