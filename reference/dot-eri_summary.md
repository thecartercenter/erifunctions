# Render a titled key/value summary block – the satisfying end-cap of a multi-step operation.

Always shown (it is the result, not chatter), at both verbosity levels.
`title` is glue-style (interpolated in `.envir`); `items` is a named
character vector of already-formatted values (`names` become the
left-hand labels). A green tick is prepended to the title.

## Usage

``` r
.eri_summary(title, items, .envir = parent.frame())
```
