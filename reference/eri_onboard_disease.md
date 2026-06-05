# Scaffold DQ schema YAML files for a new disease program

Generates one skeleton YAML file per `data_type` (e.g. `"mda"`,
`"prevalence"`) following the standard column layout for each type. TODO
comments in the generated files flag fields that must be customised
before the schema is ready for team-wide use.

## Usage

``` r
eri_onboard_disease(
  disease,
  country,
  data_types = c("mda", "prevalence"),
  output_dir = getwd(),
  dry_run = FALSE
)
```

## Arguments

- disease:

  `chr` Short disease code (e.g. `"rb"`, `"schisto"`, `"sth"`).

- country:

  `chr` Country or program code (e.g. `"ug"`, `"global"`).

- data_types:

  `chr` vector Data types to scaffold. Each generates one file.
  Supported values: `"mda"`, `"prevalence"`. Default both.

- output_dir:

  `chr` Directory to write skeleton YAML files into. Default is the
  current working directory.

- dry_run:

  `lgl` If `TRUE`, print a plan but do not write files. Default `FALSE`.

## Value

Invisibly, a character vector of paths written (or `NULL` in dry-run
mode).

## Examples

``` r
if (FALSE) { # \dontrun{
eri_onboard_disease("schisto", "ug", output_dir = "schemas/")
eri_onboard_disease("rb", "ug", data_types = "mda", dry_run = TRUE)
} # }
```
