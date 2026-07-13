#### Tests for eri_guide() and its internal helpers ####
#
# scripted() (the interactive-menu mocking helper) lives in helper-scripted.R, shared with
# test-dq_review.R.

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

#### Phase 7: deep links (eri_guide(task_id=)) ####

test_that("eri_guide(task_id=) jumps straight to a task's detail screen", {
  withr::local_options(rlang_interactive = TRUE)
  shown <- NULL
  local_mocked_bindings(
    .eri_guide_show_task = function(leaf) { shown <<- leaf$id; invisible(NULL) },
    .package = "erifunctions"
  )
  expect_invisible(eri_guide("learn_vocabulary"))
  expect_equal(shown, "learn_vocabulary")
})

test_that("eri_guide(task_id=) errors clearly for an unknown id", {
  withr::local_options(rlang_interactive = TRUE)
  expect_error(eri_guide("not_a_real_task_id"), "No task with id")
})

#### Phase 7: session memory (resume the last-visited category) ####

test_that(".eri_guide_resolve_branch_choice handles exit/cancel, resume, and plain selection", {
  tree   <- list(list(id = "a"), list(id = "b"), list(id = "c"))
  resume <- list(id = "b")

  # No resume option present: choices are c(a, b, c, "Exit").
  expect_null(.eri_guide_resolve_branch_choice(0L, tree, NULL))
  expect_null(.eri_guide_resolve_branch_choice(4L, tree, NULL))
  expect_equal(.eri_guide_resolve_branch_choice(1L, tree, NULL)$id, "a")
  expect_equal(.eri_guide_resolve_branch_choice(3L, tree, NULL)$id, "c")

  # Resume option present: choices are c("Continue in b", a, b, c, "Exit") -- every real branch
  # index shifts by one.
  expect_null(.eri_guide_resolve_branch_choice(0L, tree, resume))
  expect_null(.eri_guide_resolve_branch_choice(5L, tree, resume))
  expect_equal(.eri_guide_resolve_branch_choice(1L, tree, resume)$id, "b")
  expect_equal(.eri_guide_resolve_branch_choice(2L, tree, resume)$id, "a")
  expect_equal(.eri_guide_resolve_branch_choice(4L, tree, resume)$id, "c")
})

test_that("eri_guide offers to resume the last-visited category after visiting one", {
  withr::local_options(rlang_interactive = TRUE, erifunctions.guide_last_branch = NULL)
  tree <- .eri_task_map()
  first_branch_title <- tree[[1]]$title

  # First invocation: navigate into the first category, back out, exit -- no resume option should
  # be offered on the VERY FIRST top-menu display (nothing visited this session yet). A resume
  # option legitimately appears on the SECOND top-menu display within this same call (after
  # backing out of the leaf menu), since picking the category already recorded it as
  # last-visited -- so this only checks the first display, not every one.
  seen_top_menu  <- 0L
  next_response  <- scripted(list(1L, 0L, 0L))
  local_mocked_bindings(
    .eri_prompt_menu = function(title, choices) {
      if (identical(title, "What are you trying to do?")) {
        seen_top_menu <<- seen_top_menu + 1L
        if (seen_top_menu == 1L) expect_false(any(grepl("^Continue in", choices)))
      }
      next_response()
    },
    .package = "erifunctions"
  )
  eri_guide()

  # Second invocation: the top menu should now offer to resume that category first.
  local_mocked_bindings(
    .eri_prompt_menu = function(title, choices) {
      expect_match(choices[[1]], sprintf('Continue in "%s"', first_branch_title), fixed = TRUE)
      0L
    },
    .package = "erifunctions"
  )
  eri_guide()
})

test_that("picking the resume option lands directly in the remembered category", {
  withr::local_options(rlang_interactive = TRUE, erifunctions.guide_last_branch = NULL)
  tree <- .eri_task_map()

  local_mocked_bindings(.eri_prompt_menu = scripted(list(1L, 0L, 0L)), .package = "erifunctions")
  eri_guide()  # records tree[[1]]$id as the last-visited branch

  leaf_menu_title   <- NULL
  visited_leaf_menu <- FALSE
  local_mocked_bindings(
    .eri_prompt_menu = function(title, choices) {
      if (identical(title, "What are you trying to do?")) {
        # "Continue in ..." the first time; once we've already seen the leaf menu, exit --
        # otherwise this would pick "Continue" forever, since backing out of the leaf menu only
        # returns to THIS top-level menu, not out of eri_guide()'s own loop.
        return(if (!visited_leaf_menu) 1L else 0L)
      }
      leaf_menu_title   <<- title
      visited_leaf_menu <<- TRUE
      0L  # back out of the leaf menu
    },
    .package = "erifunctions"
  )
  eri_guide()
  expect_equal(leaf_menu_title, tree[[1]]$title)
})
