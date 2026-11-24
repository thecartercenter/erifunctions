# Percent-encode an ODK form ID for use as one URL path segment

Accepts the raw ID (`"Edo/Ebonyi"`) or one the caller already encoded
(`"Edo%2FEbonyi"`): it decodes first, then encodes reserved characters,
so `/` becomes `%2F` either way and is never double-encoded. The ID is
only decoded when it already contains a `%xx` escape, so a bare `%` is
kept. An ID that genuinely contains a literal `%2F` cannot be addressed.

## Usage

``` r
.odk_enc_form_id(form_id)
```
