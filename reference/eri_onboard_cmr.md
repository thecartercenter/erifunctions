# Scaffold a new country CMR schema

Writes a CMR schema YAML template to your local working directory and
optionally creates CMR Azure blob directories for the country. Edit the
YAML locally, then submit it to the package via a pull request when
ready.

## Usage

``` r
eri_onboard_cmr(
  country_code,
  country_name,
  language = "en",
  diseases = NULL,
  path = getwd(),
  data_con = NULL,
  dry_run = FALSE
)
```

## Arguments

- country_code:

  `chr` Short country code (e.g. `"uga"`).

- country_name:

  `chr` Full country name (e.g. `"Uganda"`).

- language:

  `chr` CMR template language (`"en"` or `"fr"`). Default `"en"`.

- diseases:

  `chr` vector Disease codes for which to create CMR blob directories.
  If `NULL`, no Azure directories are created.

- path:

  `chr` Directory to write the schema YAML into. Default is the current
  working directory.

- data_con:

  Azure container for the `data/` blob. If `NULL`, connects
  automatically. Ignored when `dry_run = TRUE` or `diseases` is `NULL`.

- dry_run:

  `lgl` If `TRUE`, print a plan but do not write files or create Azure
  directories. Default `FALSE`.

## Value

Invisibly, the path to the written schema file (or `NULL` in dry-run
mode).

## Examples

``` r
if (FALSE) { # \dontrun{
eri_onboard_cmr("uga", "Uganda", diseases = c("oncho", "lf"))
eri_onboard_cmr("tcd", "Chad", language = "fr", dry_run = TRUE)
} # }
```
