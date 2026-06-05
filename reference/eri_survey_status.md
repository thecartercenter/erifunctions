# ODK form submission metrics

Returns submission counts and status metadata for one or more ODK
Central forms. The scope is determined by the combination of
`project_id` and `form_id` supplied:

## Usage

``` r
eri_survey_status(project_id = NULL, form_id = NULL, con = NULL)
```

## Arguments

- project_id:

  `int` ODK project ID, or `NULL` for all projects.

- form_id:

  `chr` ODK form ID, or `NULL` for all forms in the project.

- con:

  An `odk_connection` object from
  [`init_odk_connection()`](https://thecartercenter.github.io/erifunctions/reference/init_odk_connection.md),
  or `NULL` to fall back to the `ODK_URL` and `ODK_TOKEN` environment
  variables.

## Value

An S3 object of class
`c("survey_status", "tbl_df", "tbl", "data.frame")` with the following
columns:

- project_id:

  `int` ODK project ID.

- project_name:

  `chr` ODK project display name.

- form_id:

  `chr` ODK form ID.

- form_name:

  `chr` ODK form display name.

- server_url:

  `chr` ODK server URL.

- status:

  `chr` `"open"` or `"closed"`.

- total_submissions:

  `int` All-time submission count.

- last_submission_at:

  `chr` ISO 8601 datetime of most recent submission, or `NA`.

- submissions_7d:

  `int` Submissions in the last 7 days.

- submissions_30d:

  `int` Submissions in the last 30 days.

## Details

- Both `NULL`: all forms across every project visible to the connection.

- `project_id` only: all forms within that project.

- Both supplied: a single form.

Submission counts for the 7-day and 30-day windows are derived by
fetching the full submission list and filtering by `createdAt`.
