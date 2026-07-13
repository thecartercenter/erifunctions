# Find your task and get its call and guide (interactive)

**\[experimental\]**

A console wizard over the task registry
([`eri_task_map()`](https://thecartercenter.github.io/erifunctions/reference/eri_task_map.md)'s
bundled `inst/registry/task_map.yaml`): pick a category, pick a task,
see its representative call, its guide (if any), and the reference
functions it touches. A zero-argument task (e.g.
[`eri_data_model()`](https://thecartercenter.github.io/erifunctions/reference/eri_data_model.md),
[`get_azure_storage_connection()`](https://thecartercenter.github.io/erifunctions/reference/get_azure_storage_connection.md))
can be run right from the menu; everything else – which needs real
argument values this wizard has no safe way to fabricate – can only be
shown, with its guide opened for the full walkthrough.

The wizard remembers the last category you visited this session and
offers to resume there. Pass a task id to jump straight to its detail
screen instead of navigating the menus (see
[`eri_task_map()`](https://thecartercenter.github.io/erifunctions/reference/eri_task_map.md)'s
`id` column, or the generated task-index article, for valid ids).

Prefer the generated [task-index
article](https://thecartercenter.github.io/erifunctions/articles/task-index.md)
or
[`eri_task_map()`](https://thecartercenter.github.io/erifunctions/reference/eri_task_map.md)
when you don't need the back-and-forth of a menu.

**Interactive only.** In a script, browse
[`eri_task_map()`](https://thecartercenter.github.io/erifunctions/reference/eri_task_map.md)
or the task-index article instead.

## Usage

``` r
eri_guide(task_id = NULL)
```

## Arguments

- task_id:

  `chr` or `NULL` A task id to jump straight to its detail screen,
  skipping the category/task menus. `NULL` (default) starts at the
  top-level category menu.

## Value

Invisibly, `NULL`. "Run it now" prints its visibly-returned result the
same way typing the call at the console would (so e.g.
[`get_azure_storage_connection()`](https://thecartercenter.github.io/erifunctions/reference/get_azure_storage_connection.md)'s
connection object is shown, not silently discarded), and a failure is
caught and reported rather than crashing the wizard – but the result
itself is not kept for later use; assign it yourself if you need it
again (`con <- get_azure_storage_connection()`).

## See also

[`eri_task_map()`](https://thecartercenter.github.io/erifunctions/reference/eri_task_map.md)
for the non-interactive console version,
[`eri_dq_review()`](https://thecartercenter.github.io/erifunctions/reference/eri_dq_review.md)
for the same menu-driven wizard pattern applied to DQ triage.

## Examples

``` r
if (FALSE) { # \dontrun{
eri_guide()
eri_guide("check_cmr")  # jump straight to a known task
} # }
```
