#### Tests for eri_guide() and its internal helpers ####

# Returns a function that yields the next element of `responses` on each call,
# ignoring its arguments -- the standard "scripted decision sequence" pattern
# already used for eri_dq_review() (test-dq_review.R), reused here to script
# .eri_prompt_menu() for eri_guide()'s own menu loop.
scripted <- function(responses) {
  i <- 0L
  function(...) {
    i <<- i + 1L
    if (i > length(responses)) stop("scripted responses exhausted at call ", i)
    responses[[i]]
  }
}

test_that("eri_guide refuses to run non-interactively", {
  expect_error(eri_guide(), "interactive-only")
})

test_that(".eri_guide_zero_arg distinguishes zero-argument calls from ones with arguments", {
  expect_true(.eri_guide_zero_arg("eri_data_model()"))
  expect_true(.eri_guide_zero_arg("get_azure_storage_connection()"))
  expect_false(.eri_guide_zero_arg("eri_query(sql)"))
  expect_false(.eri_guide_zero_arg("eri_stage_cmr(country, period)"))
})

test_that("every zero-argument call in the real task registry is genuinely runnable with no args", {
  # Cross-check against the actual bundled registry, not just synthetic examples above --
  # .eri_guide_zero_arg()'s classification is only useful if it agrees with what's really there.
  tree <- .eri_task_map()
  zero_arg_calls <- Filter(
    .eri_guide_zero_arg,
    unlist(lapply(tree, function(b) vapply(b$children, function(l) l$call, character(1))))
  )
  expect_true(length(zero_arg_calls) > 0L)
  expect_true(all(grepl("^\\w+\\(\\)$", zero_arg_calls)))
})

test_that("eri_guide exits cleanly from the top-level menu with no navigation", {
  withr::local_options(rlang_interactive = TRUE)
  local_mocked_bindings(
    .eri_prompt_menu = scripted(list(0L)),  # ESC/cancel at the category menu
    .package = "erifunctions"
  )
  expect_invisible(eri_guide())
})

test_that("eri_guide can navigate into a category, back out, and exit", {
  withr::local_options(rlang_interactive = TRUE)
  local_mocked_bindings(
    .eri_prompt_menu = scripted(list(
      1L,  # pick the first category
      0L,  # back out of the leaf menu
      0L   # exit the category menu
    )),
    .package = "erifunctions"
  )
  expect_invisible(eri_guide())
})

test_that("eri_guide's task screen runs a zero-argument task when selected", {
  withr::local_options(rlang_interactive = TRUE)
  ran <- FALSE
  local_mocked_bindings(eri_data_model = function() { ran <<- TRUE }, .package = "erifunctions")

  tree <- .eri_task_map()
  # learn_vocabulary (get_set_up branch) calls eri_data_model() with no args.
  leaf <- tree[[1]]$children[[which(vapply(tree[[1]]$children, function(l) l$id, character(1)) == "learn_vocabulary")]]
  expect_true(.eri_guide_zero_arg(leaf$call))

  local_mocked_bindings(
    .eri_prompt_menu = scripted(list(1L, 0L)),  # "Run it now", then "Back"
    .package = "erifunctions"
  )
  expect_invisible(.eri_guide_show_task(leaf))
  expect_true(ran)
})

test_that("eri_guide's task screen opens the guide when selected, without erroring", {
  withr::local_options(rlang_interactive = TRUE)
  opened <- NULL
  local_mocked_bindings(
    vignette = function(topic, package) { opened <<- topic; NULL },
    .package = "utils"
  )

  leaf <- list(id = "x", title = "Test task", call = "eri_query(sql)", guide = "da-adhoc-guide", reference = "eri_query")
  local_mocked_bindings(
    .eri_prompt_menu = scripted(list(1L, 0L)),  # "Open the guide" (no "Run it now" -- not zero-arg), then "Back"
    .package = "erifunctions"
  )
  expect_invisible(.eri_guide_show_task(leaf))
  expect_equal(opened, "da-adhoc-guide")
})

test_that("eri_guide's task screen never offers 'Run it now' for a call with arguments, nor 'Open the guide' with no guide", {
  withr::local_options(rlang_interactive = TRUE)
  leaf <- list(id = "x", title = "Test task", call = "eri_query(sql)", guide = NULL, reference = "eri_query")
  local_mocked_bindings(
    .eri_prompt_menu = function(title, choices) {
      expect_false("Run it now" %in% choices)
      expect_false("Open the guide" %in% choices)
      0L
    },
    .package = "erifunctions"
  )
  expect_invisible(.eri_guide_show_task(leaf))
})

test_that("eri_guide's task screen shows the visible result of a successful zero-argument run", {
  withr::local_options(rlang_interactive = TRUE)
  local_mocked_bindings(get_azure_storage_connection = function() "a connection object", .package = "erifunctions")

  leaf <- list(id = "x", title = "Test task", call = "get_azure_storage_connection()", guide = NULL, reference = "get_azure_storage_connection")
  local_mocked_bindings(
    .eri_prompt_menu = scripted(list(1L, 0L)),  # "Run it now", then "Back"
    .package = "erifunctions"
  )
  expect_output(.eri_guide_show_task(leaf), "a connection object")
})

test_that("eri_guide's task screen catches a failing zero-argument run instead of crashing", {
  withr::local_options(rlang_interactive = TRUE)
  local_mocked_bindings(
    get_azure_storage_connection = function() stop("auth cancelled"),
    .package = "erifunctions"
  )

  leaf <- list(id = "x", title = "Test task", call = "get_azure_storage_connection()", guide = NULL, reference = "get_azure_storage_connection")
  local_mocked_bindings(
    .eri_prompt_menu = scripted(list(1L, 0L)),  # "Run it now", then "Back"
    .package = "erifunctions"
  )
  expect_no_error(.eri_guide_show_task(leaf))
})
