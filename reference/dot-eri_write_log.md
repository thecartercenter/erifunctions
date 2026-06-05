# Write a structured operation log YAML to the Azure logs/ directory

Wraps in its own tryCatch so a logging failure never masks the original
error.

## Usage

``` r
.eri_write_log(log_list, azcontainer, log_dir)
```
