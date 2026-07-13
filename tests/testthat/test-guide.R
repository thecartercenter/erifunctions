#### Tests for eri_guide() (deprecated, narrowed to a static lookup -- Phase C.3) ####

test_that("eri_guide() warns deprecation and points at eri_do()/eri_task_map()", {
  expect_warning(eri_guide("learn_vocabulary"), "eri_do\\(\\)")
})

test_that("eri_guide(task_id=) shows that task's call/guide/reference and nothing else", {
  suppressWarnings({
    expect_message(eri_guide("learn_vocabulary"), "Run:")
  })
})

test_that("eri_guide(task_id=) errors clearly for an unknown id", {
  suppressWarnings(expect_error(eri_guide("not_a_real_task_id"), "No task with id"))
})

test_that("eri_guide() with no argument falls through to eri_task_map()'s static listing", {
  ran <- FALSE
  local_mocked_bindings(
    eri_task_map = function() { ran <<- TRUE; invisible(NULL) },
    .package = "erifunctions"
  )
  suppressWarnings(expect_invisible(eri_guide()))
  expect_true(ran)
})
