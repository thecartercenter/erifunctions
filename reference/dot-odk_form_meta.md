# Fetch metadata for a single ODK form

Fetch metadata for a single ODK form

## Usage

``` r
.odk_form_meta(creds, project_id, form_id)
```

## Arguments

- creds:

  Named list with `url` and `auth` from
  [`.odk_creds()`](https://thecartercenter.github.io/erifunctions/reference/dot-odk_creds.md).

- project_id:

  Integer project ID.

- form_id:

  Character form ID.

## Value

Parsed list of form metadata.
