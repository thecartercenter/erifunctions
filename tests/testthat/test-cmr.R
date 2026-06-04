#### Shared fixture helper ####

# Creates a CMR-structured Excel file matching the template layout:
#   File row 1  : junk column names (writexl header)  — skipped by skip=4
#   File rows 2-4: junk data rows                      — skipped by skip=4
#   File row 5  : field codes                          — becomes column names
#   File rows 6+: actual data
make_cmr_xlsx <- function(path,
                           sheet_name  = "RB Treatment",
                           field_codes = c("#rbtrt_year", "#rbtrt_adm1", "#rbtrt_target"),
                           data_rows   = list(c("2024", "North", "1000"),
                                              c("2024", "South", "2000")),
                           extra_cols  = NULL) {
  n <- length(field_codes)
  col_nms <- paste0("V", seq_len(n))

  make_row <- function(...) setNames(as.data.frame(matrix(c(...), nrow = 1)), col_nms)

  junk  <- do.call(rbind, replicate(3, make_row(rep(NA_character_, n)), simplify = FALSE))
  codes <- make_row(field_codes)
  data  <- do.call(rbind, lapply(data_rows, function(r) make_row(r)))

  sheet_df <- rbind(junk, codes, data)

  # Extra non-field columns (simulate merged group header columns)
  if (!is.null(extra_cols)) {
    for (ec in extra_cols) {
      sheet_df[[ec]] <- NA_character_
    }
  }

  writexl::write_xlsx(setNames(list(sheet_df), sheet_name), path)
  invisible(path)
}

#### Tests for eri_ingest_cmr ####

test_that("eri_ingest_cmr returns tibble with field code columns", {
  tmp <- withr::local_tempfile(fileext = ".xlsx")
  make_cmr_xlsx(tmp)
  out <- eri_ingest_cmr(tmp, sheet = "RB Treatment")
  expect_s3_class(out, "tbl_df")
  expect_true(all(startsWith(names(out), "#")))
  expect_equal(ncol(out), 3L)
})

test_that("eri_ingest_cmr reads correct data values", {
  tmp <- withr::local_tempfile(fileext = ".xlsx")
  make_cmr_xlsx(tmp,
    field_codes = c("#rbtrt_year", "#rbtrt_adm1"),
    data_rows   = list(c("2024", "North"), c("2025", "South"))
  )
  out <- eri_ingest_cmr(tmp, sheet = "RB Treatment")
  expect_equal(nrow(out), 2L)
  expect_equal(out[["#rbtrt_year"]], c("2024", "2025"))
  expect_equal(out[["#rbtrt_adm1"]], c("North", "South"))
})

test_that("eri_ingest_cmr drops all-NA spacer rows", {
  tmp <- withr::local_tempfile(fileext = ".xlsx")
  make_cmr_xlsx(tmp,
    field_codes = c("#rbtrt_year", "#rbtrt_adm1"),
    data_rows   = list(c("2024", "North"), c(NA, NA), c("2025", "South"))
  )
  out <- eri_ingest_cmr(tmp, sheet = "RB Treatment")
  expect_equal(nrow(out), 2L)
})

test_that("eri_ingest_cmr adds country column when supplied", {
  tmp <- withr::local_tempfile(fileext = ".xlsx")
  make_cmr_xlsx(tmp)
  out <- eri_ingest_cmr(tmp, sheet = "RB Treatment", country = "ug")
  expect_true("country" %in% names(out))
  expect_equal(out$country[1], "ug")
  expect_equal(names(out)[1], "country")
})

test_that("eri_ingest_cmr works with sheet by index", {
  tmp <- withr::local_tempfile(fileext = ".xlsx")
  make_cmr_xlsx(tmp, sheet_name = "RB Treatment")
  out <- eri_ingest_cmr(tmp, sheet = 1L)
  expect_s3_class(out, "tbl_df")
  expect_gt(nrow(out), 0L)
})

test_that("eri_ingest_cmr errors clearly when file not found", {
  expect_error(
    eri_ingest_cmr("nonexistent/path/file.xlsx", sheet = "Sheet1"),
    "File not found"
  )
})

test_that("eri_ingest_cmr errors when no field code row present", {
  tmp <- withr::local_tempfile(fileext = ".xlsx")
  # Write a plain sheet with no # codes at all
  writexl::write_xlsx(
    list("Sheet1" = tibble::tibble(Year = 2024L, Province = "North")),
    tmp
  )
  expect_error(
    eri_ingest_cmr(tmp, sheet = "Sheet1"),
    "No field code columns"
  )
})

test_that("eri_ingest_cmr ignores non-field-code columns (merged header cols)", {
  tmp <- withr::local_tempfile(fileext = ".xlsx")
  make_cmr_xlsx(tmp,
    field_codes = c("#rbtrt_year", "#rbtrt_adm1"),
    data_rows   = list(c("2024", "North")),
    extra_cols  = c("GroupHeader", "AnotherHeader")
  )
  out <- eri_ingest_cmr(tmp, sheet = "RB Treatment")
  expect_false(any(c("GroupHeader", "AnotherHeader") %in% names(out)))
  expect_true(all(startsWith(names(out), "#")))
})

test_that("eri_ingest_cmr parses French template identically (same field codes)", {
  tmp_en <- withr::local_tempfile(fileext = ".xlsx")
  tmp_fr <- withr::local_tempfile(fileext = ".xlsx")

  codes <- c("#rbtrt_year", "#rbtrt_adm1", "#rbtrt_target")
  make_cmr_xlsx(tmp_en, sheet_name = "RB Treatment",   field_codes = codes,
                data_rows = list(c("2024", "North", "500")))
  make_cmr_xlsx(tmp_fr, sheet_name = "Oncho Traitement", field_codes = codes,
                data_rows = list(c("2024", "Nord", "500")))

  en <- eri_ingest_cmr(tmp_en, sheet = "RB Treatment")
  fr <- eri_ingest_cmr(tmp_fr, sheet = "Oncho Traitement")

  expect_equal(names(en), names(fr))
  expect_equal(en[["#rbtrt_year"]], fr[["#rbtrt_year"]])
})
