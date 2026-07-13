# Look up a task's call and guide (deprecated; use [`eri_do()`](https://thecartercenter.github.io/erifunctions/reference/eri_do.md) or [`eri_task_map()`](https://thecartercenter.github.io/erifunctions/reference/eri_task_map.md))

**\[deprecated\]**

`eri_guide()` used to be a menu-driven console wizard. It's deprecated
in favor of two sharper tools:
[`eri_do()`](https://thecartercenter.github.io/erifunctions/reference/eri_do.md),
which actually *runs* the CMR/ingest/ODK/onboarding pipelines through a
guided console flow, and
[`eri_task_map()`](https://thecartercenter.github.io/erifunctions/reference/eri_task_map.md)
(or the generated task-index article), which browses every task's
representative call, guide, and reference functions as a static list.
`eri_guide()` never had "run it now" for more than 4 of ~32 tasks – for
anything else it could only describe, which is what the vignettes and
[`eri_task_map()`](https://thecartercenter.github.io/erifunctions/reference/eri_task_map.md)
already do, without a menu to navigate.

This function is kept, narrowed, rather than removed outright: pass a
`task_id` and it still shows that task's call, guide, and reference
functions (no menu); called with no argument, it prints the full
[`eri_task_map()`](https://thecartercenter.github.io/erifunctions/reference/eri_task_map.md)
listing instead of opening an interactive browser.

## Usage

``` r
eri_guide(task_id = NULL)
```

## Arguments

- task_id:

  `chr` or `NULL` A task id to show (see
  [`eri_task_map()`](https://thecartercenter.github.io/erifunctions/reference/eri_task_map.md)'s
  `id` column, or the generated task-index article, for valid ids).
  `NULL` (default) prints the full task list instead.

## Value

Invisibly, `NULL`.

## See also

[`eri_do()`](https://thecartercenter.github.io/erifunctions/reference/eri_do.md)
for the guided pipeline wizard that replaced this,
[`eri_task_map()`](https://thecartercenter.github.io/erifunctions/reference/eri_task_map.md)
for the full static listing.

## Examples

``` r
if (FALSE) { # \dontrun{
eri_guide("check_cmr")  # show one task's call/guide/reference, no menu
eri_guide()             # equivalent to eri_task_map()
} # }
```
