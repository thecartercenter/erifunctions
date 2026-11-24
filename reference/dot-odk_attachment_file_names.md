# Local file names for downloaded ODK attachments

Stem from the label value (a trailing media extension such as `.jpg`
dropped; other dots, e.g. `3.5`, kept), extension from the attachment
itself (`jpeg` if it has none). The attachment's own stem is appended
when its submission has more than one attachment, or when the name would
otherwise repeat (compared case-insensitively, as Windows/macOS file
systems do). Any name still repeated gets a numeric suffix.

## Usage

``` r
.odk_attachment_file_names(label, att_name, instance_id = NULL)
```

## Arguments

- label:

  `chr` the `image_label` value per attachment row

- att_name:

  `chr` the attachment's ODK file name

- instance_id:

  `chr` the submission each attachment belongs to, or `NULL`
