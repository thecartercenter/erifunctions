# Transfer many files with a single, informative cli progress bar.

Replaces a stack of per-file AzureStor bars with one transient bar that
names the current file and shows `i/n`. The caller prints the headline
summary afterwards.

## Usage

``` r
.eri_blob_transfer_many(con, srcs, dests, direction = c("upload", "download"))
```

## Arguments

- direction:

  `"upload"` (srcs = local paths, dests = Azure paths) or `"download"`
  (srcs = Azure paths, dests = local paths).
