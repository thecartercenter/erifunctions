# Scaffold a new country/disease surveillance setup

Writes a DQ schema YAML template to your local working directory and
creates the three-layer Azure blob directories for the new
country/disease. Edit the YAML locally, then submit it to the package
via a pull request when it is ready for team-wide use.

## Usage

``` r
eri_onboard_country(
  country_code,
  country_name,
  disease,
  language = "en",
  path = getwd(),
  data_con = NULL,
  dry_run = FALSE,
  data_type = "aggregate"
)
```

## Arguments

- country_code:

  `chr` Short country code (e.g. `"uga"`, `"eth"`).

- country_name:

  `chr` Full country name as it appears in data (e.g. `"Uganda"`).

- disease:

  `chr` Disease code (e.g. `"oncho"`, `"malaria"`, `"lf"`).

- language:

  `chr` Language for schema comments (`"en"` or `"fr"`). Default `"en"`.

- path:

  `chr` Directory to write the schema YAML into. Default is the current
  working directory.

- data_con:

  Azure container for the `data/` blob. If `NULL`, connects
  automatically. Ignored when `dry_run = TRUE`.

- dry_run:

  `lgl` If `TRUE`, print a plan but do not write files or create Azure
  directories. Default `FALSE`.

- data_type:

  `chr` The surveillance measure for the schema identity (ADR-0012),
  e.g. `"aggregate"` or `"case"`. Default `"aggregate"`. Sets the schema
  filename `{country}_{disease}_surveillance_{data_type}.yaml`.

## Value

Invisibly, the path to the written schema file (or `NULL` in dry-run
mode).

## Examples

``` r
if (FALSE) { # \dontrun{
eri_onboard_country("uga", "Uganda", "oncho")
eri_onboard_country("nga", "Nigeria", "lf", language = "en", dry_run = TRUE)
} # }
```
