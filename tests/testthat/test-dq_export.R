#### Tests for eri_dq_export() ####

flags_open <- tibble::tibble(
  sheet = c("RB Treatment", "RB Treatment", "LF Treatment"),
  disease = c("oncho", "oncho", "lf"), data_type = "treatment",
  log_path = "sdn/oncho/programmatic/treatment/logs/dq.yaml",
  flag_id = c("a::1", "a::2", "b::1"),
  row = c(1L, 2L, 1L), excel_row = c(7L, 8L, 12L),
  column = c("district", "value", "district"),
  value = c("Kordofn", "-5", "Kordofn"),
  issue = c("not an allowed value", "negative count", "not an allowed value"),
  status = c("open", "not_important", "open"),
  note = c(NA_character_, "known template quirk", NA_character_)
)

flags_empty <- tibble::tibble(
  sheet = character(0), disease = character(0), data_type = character(0),
  log_path = character(0), flag_id = character(0), row = integer(0),
  excel_row = integer(0), column = character(0), value = character(0),
  issue = character(0), status = character(0), note = character(0)
)

test_that("eri_dq_export validates flags has the required columns", {
  expect_error(eri_dq_export(list(a = 1)), "data frame")
  expect_error(eri_dq_export(tibble::tibble(sheet = "x")), "missing column")
})

test_that("eri_dq_export works on a plain run_dq_checks() flags tibble (no sheet/status/excel_row)", {
  withr::local_dir(withr::local_tempdir())
  plain <- tibble::tibble(
    row = c(3L, 5L), column = c("Age", "EpiWeek"), value = c("200", "60"),
    issue = c("Value outside expected range [0, 120]", "Value outside expected range [1, 53]")
  )

  path <- eri_dq_export(plain, country = "dr")
  html <- paste(readLines(path, warn = FALSE), collapse = "\n")
  expect_match(html, "DQ flag report")
  expect_match(html, "Age")
  expect_match(html, "200")
  expect_no_match(html, "<h2>")  # no `sheet` column -- one flat table, no per-section headers

  md_path <- eri_dq_export(plain, format = "md", country = "dr")
  md <- paste(readLines(md_path, warn = FALSE), collapse = "\n")
  expect_match(md, "\\| Row \\| Column \\| Value \\| Issue \\|")
  expect_no_match(md, "^## ")
})

test_that("eri_dq_export defaults the output path using country/period and writes an html file", {
  withr::local_dir(withr::local_tempdir())
  path <- eri_dq_export(flags_open, country = "sdn", period = "202605")
  expect_true(grepl("dq-report-sdn-202605-.*\\.html$", basename(path)))
  expect_true(file.exists(path))
  html <- paste(readLines(path, warn = FALSE), collapse = "\n")
  expect_match(html, "DQ flag report")
  expect_match(html, "RB Treatment \\(2\\)")
  expect_match(html, "LF Treatment \\(1\\)")
  expect_match(html, "Kordofn")
  expect_match(html, "known template quirk")
})

test_that("eri_dq_export writes markdown with a table per sheet, including the note column", {
  withr::local_dir(withr::local_tempdir())
  path <- eri_dq_export(flags_open, format = "md", country = "sdn", period = "202605")
  expect_true(grepl("\\.md$", path))
  md <- paste(readLines(path, warn = FALSE), collapse = "\n")
  expect_match(md, "^# DQ flag report", fixed = FALSE)
  expect_match(md, "## RB Treatment \\(2\\)")
  expect_match(md, "known template quirk")
  expect_match(md, "—")  # NA note rendered as an em dash placeholder
})

test_that("eri_dq_export reports a clean run without erroring", {
  withr::local_dir(withr::local_tempdir())
  path_html <- eri_dq_export(flags_empty, country = "sdn", period = "202605")
  html <- paste(readLines(path_html, warn = FALSE), collapse = "\n")
  expect_match(html, "every measure is clean")

  path_md <- eri_dq_export(flags_empty, format = "md", country = "sdn", period = "202605")
  md <- paste(readLines(path_md, warn = FALSE), collapse = "\n")
  expect_match(md, "every measure is clean")
})

test_that("eri_dq_export respects an explicit file path and honors a missing note column", {
  withr::local_dir(withr::local_tempdir())
  no_note <- flags_open[, setdiff(names(flags_open), "note")]
  out <- file.path(getwd(), "custom-name.html")
  path <- eri_dq_export(no_note, file = out)
  expect_equal(path, out)
  expect_true(file.exists(out))
})
