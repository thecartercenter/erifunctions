# Name ODK Central gives a form's CSV inside a submissions export zip

Central names export files with `sanitize-filename(xmlFormId)`, which
drops `/ ? < > \ : * | "` and control characters, and trailing
dots/spaces. Mirror that so the main CSV is found for form IDs
containing those characters.

## Usage

``` r
.odk_export_name(form_id)
```
