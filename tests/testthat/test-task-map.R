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

test_that("every `call:` template represents every required argument of its own function", {
  # A parseable call can still omit a REQUIRED argument (no default) and just look abbreviated --
  # this caught two real cases: start_project's eri_research_init(project_name) dropped 3 required
  # args, and population_totals's eri_spatial_pop(boundaries) used the wrong name entirely (real
  # param is `shapefile`). Optional args (with a default) may still be omitted, per the registry's
  # own documented convention -- only required ones are checked here.
  tree <- .eri_task_map()
  for (branch in tree) {
    for (leaf in branch$children) {
      call_expr <- str2lang(leaf$call)
      fn_name   <- as.character(call_expr[[1]])
      # Positional arg tokens as written in the call template (not match.arg'd -- this is
      # illustrative text a user reads, not something actually invoked).
      call_arg_syms <- vapply(as.list(call_expr)[-1], function(a) as.character(a), character(1))

      fn <- get(fn_name, envir = asNamespace("erifunctions"))
      f  <- formals(fn)
      required <- setdiff(
        names(f)[vapply(f, function(d) identical(d, quote(expr = )), logical(1))],
        "..."  # dots are never spelled out in a call template
      )

      missing <- setdiff(required, call_arg_syms)
      expect_length(missing, 0L)
      if (length(missing) > 0) {
        cli::cli_inform("{leaf$id}: {.fn {fn_name}} call is missing required arg(s) {.val {missing}}")
      }
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

test_that("every `epilogue_after:` value is in that same leaf's own `reference:` list", {
  # The runtime hook (.eri_task_epilogue()) is only ever called FROM the function it names, so an
  # epilogue_after value the task doesn't even claim to touch would be a self-contradiction.
  tree <- .eri_task_map()
  for (branch in tree) {
    for (leaf in branch$children) {
      if (!is.null(leaf$epilogue_after)) {
        expect_true(leaf$epilogue_after %in% leaf$reference, info = leaf$id)
      }
    }
  }
})

test_that("every leaf with `epilogue_after:` also has a `next:` to point to", {
  tree <- .eri_task_map()
  for (branch in tree) {
    for (leaf in branch$children) {
      if (!is.null(leaf$epilogue_after)) {
        expect_true(length(leaf[["next"]]) > 0L, info = leaf$id)
      }
    }
  }
})

test_that("no two leaves hook the same `epilogue_after:` function", {
  tree <- .eri_task_map()
  hooks <- unlist(lapply(tree, function(b) {
    Filter(Negate(is.null), lapply(b$children, function(l) l$epilogue_after))
  }))
  expect_equal(anyDuplicated(hooks), 0L)
})

test_that(".eri_task_flatten produces one row per leaf with the expected columns", {
  tree <- .eri_task_map()
  n_leaves <- sum(vapply(tree, function(b) length(b$children), integer(1)))
  flat <- .eri_task_flatten(tree)
  expect_equal(nrow(flat), n_leaves)
  expect_true(all(
    c("branch", "id", "title", "role", "call", "guide", "reference", "next_ids", "epilogue_after") %in%
      names(flat)
  ))
})

test_that("eri_task_map() prints and returns the flattened registry invisibly", {
  expect_invisible(out <- eri_task_map())
  expect_s3_class(out, "data.frame")
  expect_true(all(c("id", "title", "call") %in% names(out)))
})

test_that(".eri_task_epilogue prints the real registered next-step hint for a real hook", {
  # eri_spatial_reconcile's epilogue_after -> next: join_map ("Join points to admin units and map
  # them"), cross-checked against the actual registry rather than a hardcoded expectation, so this
  # test can't drift out of sync with the YAML.
  tree <- .eri_task_map()
  flat <- .eri_task_flatten(tree)
  hit  <- flat[!is.na(flat$epilogue_after) & flat$epilogue_after == "eri_spatial_reconcile", , drop = FALSE]
  expect_equal(nrow(hit), 1L)
  nxt <- flat[flat$id == hit$next_ids[[1]], , drop = FALSE]

  expect_message(.eri_task_epilogue("eri_spatial_reconcile"), nxt$title[[1]], fixed = TRUE)
})

test_that(".eri_task_epilogue is silent for a function with no registered hook", {
  expect_no_message(.eri_task_epilogue("not_a_real_hook"))
})

test_that(".eri_task_epilogue respects quiet verbosity like any other narration", {
  withr::local_options(erifunctions.verbosity = "quiet")
  expect_no_message(.eri_task_epilogue("eri_spatial_reconcile"))
})
