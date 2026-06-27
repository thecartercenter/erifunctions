#### Tests for the data-addressing model registry (ADR-0012) ####

test_that(".eri_data_model loads the bundled registry with the expected axes", {
  m <- .eri_data_model()
  expect_true(all(c("data_sources", "data_types", "formats", "layers") %in% names(m)))
  expect_true(all(c("surveillance", "programmatic", "odk") %in% names(m$data_sources)))
  expect_true(all(c("case", "aggregate", "treatment", "tas") %in% names(m$data_types)))
  expect_equal(m$layers, c("raw", "staged", "processed"))
})

test_that(".eri_check_axis warns only for unknown values", {
  expect_silent(.eri_check_axis("data_source", "surveillance", c("surveillance", "odk")))
  expect_warning(.eri_check_axis("data_source", "nope", c("surveillance", "odk")), "Unknown")
})

test_that("eri_data_model() prints and returns the registry invisibly", {
  expect_invisible(out <- eri_data_model())
  expect_type(out, "list")
  expect_true("data_sources" %in% names(out))
})
