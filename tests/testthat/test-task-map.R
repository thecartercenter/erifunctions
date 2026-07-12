#### Integrity tests for the task registry (docs site & guidance system, phase 3) ####
#
# The task map is a claim about the package's own API and articles: every
# reference/guide/call/next value it names must be real. These tests make an
# unverifiable claim a test failure, not a stale doc.

.task_map_pkg_root <- function() {
  d <- getwd()
  for (i in 1:6) {
    if (file.exists(file.path(d, "DESCRIPTION"))) return(d)
    d <- dirname(d)
  }
  cli::cli_abort("Could not locate package root (DESCRIPTION not found) from {getwd()}.")
}

test_that(".eri_task_map loads the bundled registry as a non-empty branch tree", {
  tree <- .eri_task_map()
  expect_true(is.list(tree))
  expect_gt(length(tree), 0)
  expect_true(all(vapply(tree, function(b) is.character(b$id) && is.character(b$title), logical(1))))
  expect_true(all(vapply(tree, function(b) is.list(b$children) && length(b$children) > 0, logical(1))))
})

test_that("every leaf task has the required fields", {
  tree <- .eri_task_map()
  for (branch in tree) {
    for (leaf in branch$children) {
      expect_true(is.character(leaf$id) && nzchar(leaf$id), info = paste("branch:", branch$id))
      expect_true(is.character(leaf$title) && nzchar(leaf$title), info = leaf$id)
      expect_true(leaf$role %in% c("da", "epi", "both"), info = leaf$id)
      expect_true(is.character(leaf$call) && nzchar(leaf$call), info = leaf$id)
    }
  }
})

test_that("every leaf task id is unique across the whole tree", {
  tree <- .eri_task_map()
  ids <- unlist(lapply(tree, function(b) vapply(b$children, function(l) l$id, character(1))))
  expect_equal(anyDuplicated(ids), 0L)
})

test_that("every `reference:` entry is a real exported function", {
  tree <- .eri_task_map()
  exported <- getNamespaceExports("erifunctions")
  for (branch in tree) {
    for (leaf in branch$children) {
      unknown <- setdiff(leaf$reference, exported)
      expect_length(unknown, 0L)
      if (length(unknown) > 0) {
        cli::cli_inform("{leaf$id}: unknown reference(s) {.val {unknown}}")
      }
    }
  }
})

test_that("every `guide:` slug matches a real vignettes/*.Rmd file", {
  root <- .task_map_pkg_root()
  slugs <- tools::file_path_sans_ext(list.files(file.path(root, "vignettes"), pattern = "\\.Rmd$"))
  expect_gt(length(slugs), 0)

  tree <- .eri_task_map()
  for (branch in tree) {
    for (leaf in branch$children) {
      if (!is.null(leaf$guide)) {
        expect_true(leaf$guide %in% slugs, info = paste(leaf$id, "->", leaf$guide))
      }
    }
  }
})

test_that("every `call:` template parses as valid R", {
  tree <- .eri_task_map()
  for (branch in tree) {
    for (leaf in branch$children) {
      expect_no_error(parse(text = leaf$call))
    }
  }
})

test_that("every `next:` id resolves to a real task id in the tree", {
  tree <- .eri_task_map()
  ids <- unlist(lapply(tree, function(b) vapply(b$children, function(l) l$id, character(1))))
  for (branch in tree) {
    for (leaf in branch$children) {
      unknown <- setdiff(leaf[["next"]], ids)
      expect_length(unknown, 0L)
    }
  }
})

test_that(".eri_task_flatten produces one row per leaf with the expected columns", {
  tree <- .eri_task_map()
  n_leaves <- sum(vapply(tree, function(b) length(b$children), integer(1)))
  flat <- .eri_task_flatten(tree)
  expect_equal(nrow(flat), n_leaves)
  expect_true(all(c("branch", "id", "title", "role", "call", "guide", "reference", "next_ids") %in% names(flat)))
})

test_that("eri_task_map() prints and returns the flattened registry invisibly", {
  expect_invisible(out <- eri_task_map())
  expect_s3_class(out, "data.frame")
  expect_true(all(c("id", "title", "call") %in% names(out)))
})
