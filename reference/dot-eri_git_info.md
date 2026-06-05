# Capture git provenance for a local analysis directory

Returns the HEAD commit, branch, origin remote, and a dirty-working-tree
flag for the git repository at `path`. All fields are `NA` when `git` is
unavailable or `path` is not inside a work tree.

## Usage

``` r
.eri_git_info(path)
```

## Arguments

- path:

  `chr` Directory to inspect.

## Value

A list with `sha`, `branch`, `remote`, `dirty`.
