# Promote a research-project boundary to the canonical `/spatial` store

The explicit gate for pushing a boundary you have cleaned in a research
project up to the shared canonical
`data/spatial/{country}/adm{level}.rds`, where other users and studies
pull it. Unlike
[`eri_spatial_upload()`](https://thecartercenter.github.io/erifunctions/reference/eri_spatial_upload.md)
(for brand-new boundaries), `eri_spatial_promote()` is the deliberate
way to *replace* an existing canonical boundary, and it records the
promotion in the project's `research.yaml` for provenance. Replacing an
existing boundary still requires an explicit `overwrite = TRUE` so
shared data is never clobbered by accident, and the prior canonical
version is first archived to `spatial/_archive/<timestamp>/` so a
replacement is reversible. See ADR-0009.

## Usage

``` r
eri_spatial_promote(
  local_path,
  country,
  level,
  overwrite = FALSE,
  path = getwd(),
  data_con = NULL
)
```

## Arguments

- local_path:

  `chr` Path to the local boundary file to promote (typically a cleaned
  copy under the project `data/` directory).

- country:

  `chr` Country code (e.g. `"dr"`, `"ht"`).

- level:

  `int` Admin level (0–4).

- overwrite:

  `lgl` If `TRUE`, replace an existing canonical boundary. Default
  `FALSE`.

- path:

  `chr` Local project root (read for `research.yaml` to record
  provenance). Defaults to
  [`getwd()`](https://rdrr.io/r/base/getwd.html). If no `research.yaml`
  is found, the promotion proceeds but is not recorded (with a warning).

- data_con:

  Azure container object for the `data/` blob. If `NULL`, connects
  automatically.

## Value

The canonical Azure blob path (invisibly).

## Details

The boundary is validated exactly as in
[`eri_spatial_upload()`](https://thecartercenter.github.io/erifunctions/reference/eri_spatial_upload.md)
before promotion.

## Examples

``` r
if (FALSE) { # \dontrun{
# After cleaning a boundary inside a research project, promote it to canonical.
eri_spatial_promote("data/dr_adm3_cleaned.rds", country = "dr", level = 3, overwrite = TRUE)
} # }
```
