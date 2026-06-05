# Archive an artifact (soft-delete)

Sets `archived: true` on the registry entry. The file is preserved in
Azure but will no longer appear in
[`eri_artifact_list()`](https://thecartercenter.github.io/erifunctions/reference/eri_artifact_list.md)
by default and cannot be pulled.

## Usage

``` r
eri_artifact_archive(name, data_con = NULL)
```

## Arguments

- name:

  `chr` Artifact name to archive.

- data_con:

  Azure container object for the `data/` blob. If `NULL`, connects
  automatically.

## Value

`NULL` invisibly.

## Examples

``` r
if (FALSE) { # \dontrun{
eri_artifact_archive("dr_irs_2022")
} # }
```
