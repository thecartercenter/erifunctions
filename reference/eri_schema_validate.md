# Validate a local DQ schema YAML file

Reads a surveillance schema YAML and checks it for structural problems:
missing required sections, invalid column types, and temporal or
consistency rules referencing unknown columns. Returns a tidy tibble of
issues.

## Usage

``` r
eri_schema_validate(schema_path)
```

## Arguments

- schema_path:

  `chr` Path to a local YAML schema file.

## Value

A tibble with columns `issue_type`, `field`, `message`. An empty tibble
(0 rows) means the schema is valid. Prints a summary via cli.

## Examples

``` r
if (FALSE) { # \dontrun{
# Validate a schema you just generated
eri_schema_validate("uga_oncho_schema.yaml")

# Validate a bundled schema
eri_schema_validate(system.file("schemas/dominican_republic_malaria.yaml",
                                 package = "erifunctions"))
} # }
```
