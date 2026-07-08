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

test_that("eri_ingest_cmr errors helpfully when the sheet is missing", {
  tmp <- withr::local_tempfile(fileext = ".xlsx")
  make_cmr_xlsx(tmp, sheet_name = "RB Treatment")
  expect_error(eri_ingest_cmr(tmp, sheet = "No Such Sheet"),
               "Sheet .* not found")
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

#### Tests for load_cmr_schema ####

test_that("load_cmr_schema returns a list with expected top-level keys", {
  schema <- load_cmr_schema("uga")
  expect_type(schema, "list")
  expect_true(all(c("country", "country_code", "language", "template", "sheets") %in% names(schema)))
})

test_that("load_cmr_schema returns correct metadata for Uganda", {
  schema <- load_cmr_schema("uga")
  expect_equal(schema$country_code, "uga")
  expect_equal(schema$language, "en")
  expect_equal(schema$template, "english_cmr")
})

test_that("load_cmr_schema Uganda has SCH Treatment but not LF Treatment", {
  schema <- load_cmr_schema("uga")
  sheet_names <- names(schema$sheets)
  expect_true("SCH Treatment" %in% sheet_names)
  expect_false("LF Treatment" %in% sheet_names)
})

test_that("load_cmr_schema Nigeria has both SCH and STH Treatment", {
  schema <- load_cmr_schema("nga")
  sheet_names <- names(schema$sheets)
  expect_true("SCH Treatment" %in% sheet_names)
  expect_true("STH Treatment" %in% sheet_names)
})

test_that("load_cmr_schema Ethiopia has the RB+LF entomology/survey sheets (real template)", {
  schema <- load_cmr_schema("eth")
  sheet_names <- names(schema$sheets)
  # eth is an RB+LF country (no SCH/STH); its oncho entomology lives in the
  # RB Ento Surveys + Field Ento Training sheets, not the old stand-in names.
  expect_true("RB Ento Surveys" %in% sheet_names)
  expect_true("Field Ento Training" %in% sheet_names)
  expect_false("SCH Treatment" %in% sheet_names)
})

#### Tests for the atlantis training sandbox schema (demo) ####

test_that("load_cmr_schema atlantis is a synthetic sandbox mirroring uga routing", {
  schema <- load_cmr_schema("atlantis")
  expect_equal(schema$country_code, "atlantis")
  # Routes the two treatment sheets to the same diseases as uga, so the bundled
  # synthetic workbook can drive the whole pipeline without a real namespace.
  expect_equal(schema$sheets[["RB Treatment"]]$disease, "oncho")
  expect_equal(schema$sheets[["SCH Treatment"]]$disease, "sch")
  expect_equal(schema$sheets[["RB Treatment"]]$field_code_prefix, "#rbtrt_")
})

test_that("load_cmr_schema lists the atlantis sandbox separately from real countries", {
  # A DA who mistypes a real code should not be offered the fictional sandbox as
  # if it were a real reporting country.
  expect_error(load_cmr_schema("zzz"), "Training sandbox")
})

test_that("eri_split_cmr dry_run routes the bundled example under atlantis/", {
  ex <- system.file("extdata", "cmr-example.xlsx", package = "erifunctions")
  skip_if(!nzchar(ex) || !file.exists(ex), "bundled cmr-example.xlsx not available")
  plan <- eri_split_cmr(ex, country = "atlantis", dry_run = TRUE)
  expect_s3_class(plan, "tbl_df")
  expect_true(all(startsWith(plan$dest, "atlantis/")))
  expect_setequal(plan$disease, c("oncho", "sch"))
})

#### Tests for French CMR schemas (issue #29) ####

test_that("load_cmr_schema tcd has correct metadata", {
  schema <- load_cmr_schema("tcd")
  expect_equal(schema$country_code, "tcd")
  expect_equal(schema$language, "fr")
  expect_equal(schema$template, "french_cmr")
})

test_that("load_cmr_schema tcd has sheet_aliases block", {
  schema <- load_cmr_schema("tcd")
  expect_true("sheet_aliases" %in% names(schema))
  expect_equal(schema$sheet_aliases[["rb_treatment"]], "Oncho Traitement")
  expect_equal(schema$sheet_aliases[["lf_treatment"]], "Traitement FL")
})

test_that("load_cmr_schema mad has no rb_treatment alias (LF-only country)", {
  schema <- load_cmr_schema("mad")
  expect_false("rb_treatment" %in% names(schema$sheet_aliases))
  expect_true("lf_treatment" %in% names(schema$sheet_aliases))
  expect_equal(schema$sheet_aliases[["lf_treatment"]], "Traitement FL")
})

test_that("load_cmr_schema mad uses PCMPI FL as lf_mmdp alias", {
  schema <- load_cmr_schema("mad")
  expect_equal(schema$sheet_aliases[["lf_mmdp"]], "PCMPI FL")
})

test_that("load_cmr_schema French schemas: each sheet has field_code_prefix and required_fields", {
  for (country in c("mad", "tcd")) {
    schema <- load_cmr_schema(country)
    for (sheet in names(schema$sheets)) {
      sheet_def <- schema$sheets[[sheet]]
      expect_true("field_code_prefix" %in% names(sheet_def),
                  info = paste(country, sheet, "missing field_code_prefix"))
      expect_true("required_fields" %in% names(sheet_def),
                  info = paste(country, sheet, "missing required_fields"))
      expect_gt(length(sheet_def$required_fields), 0L,
                label = paste(country, sheet, "required_fields empty"))
    }
  }
})

test_that("eri_ingest_cmr resolves slug alias to French sheet name", {
  tmp <- withr::local_tempfile(fileext = ".xlsx")
  make_cmr_xlsx(tmp,
    sheet_name  = "Oncho Traitement",
    field_codes = c("#rbtrt_year", "#rbtrt_adm1", "#rbtrt_treated"),
    data_rows   = list(c("2024", "Logone", "500"))
  )
  out <- eri_ingest_cmr(tmp, sheet = "rb_treatment", country = "tcd")
  expect_s3_class(out, "tbl_df")
  expect_equal(nrow(out), 1L)
  expect_equal(out[["#rbtrt_year"]], "2024")
  expect_equal(out$country, "tcd")
})

test_that("eri_ingest_cmr passes through unrecognised slug unchanged (direct sheet name)", {
  tmp <- withr::local_tempfile(fileext = ".xlsx")
  make_cmr_xlsx(tmp,
    sheet_name  = "Traitement FL",
    field_codes = c("#lftrt_year", "#lftrt_adm1"),
    data_rows   = list(c("2024", "Antananarivo"))
  )
  out <- eri_ingest_cmr(tmp, sheet = "Traitement FL", country = "mad")
  expect_s3_class(out, "tbl_df")
  expect_equal(nrow(out), 1L)
})

test_that("eri_ingest_cmr alias resolution works without country (no alias lookup)", {
  tmp <- withr::local_tempfile(fileext = ".xlsx")
  make_cmr_xlsx(tmp,
    sheet_name  = "Oncho Traitement",
    field_codes = c("#rbtrt_year", "#rbtrt_adm1"),
    data_rows   = list(c("2024", "North"))
  )
  out <- eri_ingest_cmr(tmp, sheet = "Oncho Traitement")
  expect_s3_class(out, "tbl_df")
  expect_equal(nrow(out), 1L)
})

test_that("load_cmr_schema each sheet has field_code_prefix and required_fields", {
  for (country in c("eth", "nga", "sdn", "ssd", "uga")) {
    schema <- load_cmr_schema(country)
    for (sheet in names(schema$sheets)) {
      sheet_def <- schema$sheets[[sheet]]
      expect_true("field_code_prefix" %in% names(sheet_def),
                  info = paste(country, sheet, "missing field_code_prefix"))
      expect_true("required_fields" %in% names(sheet_def),
                  info = paste(country, sheet, "missing required_fields"))
      expect_gt(length(sheet_def$required_fields), 0L,
                label = paste(country, sheet, "required_fields empty"))
    }
  }
})

test_that("load_cmr_schema required_fields all start with #", {
  for (country in c("eth", "nga", "sdn", "ssd", "uga", "mad", "tcd")) {
    schema <- load_cmr_schema(country)
    for (sheet in names(schema$sheets)) {
      fields <- schema$sheets[[sheet]]$required_fields
      expect_true(all(startsWith(fields, "#")),
                  info = paste(country, sheet, "has field codes not starting with #"))
    }
  }
})

test_that("load_cmr_schema errors informatively for unknown country", {
  expect_error(load_cmr_schema("xyz"), "No CMR schema found")
  expect_error(load_cmr_schema("xyz"), "Available")
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

#### Tests for eri_split_cmr ####

# One CMR-layout sheet: 3 junk rows, the field-code row, then data rows.
make_cmr_sheet_df <- function(field_codes, data_rows) {
  n <- length(field_codes); col_nms <- paste0("V", seq_len(n))
  mk <- function(vals) setNames(as.data.frame(matrix(vals, nrow = 1), stringsAsFactors = FALSE), col_nms)
  junk  <- do.call(rbind, replicate(3, mk(rep(NA_character_, n)), simplify = FALSE))
  codes <- mk(field_codes)
  data  <- do.call(rbind, lapply(data_rows, mk))
  rbind(junk, codes, data)
}

# A synthetic Uganda CMR with the three disease-specific treatment/MMDP sheets.
# Each carries a per-row #..._disease program-coverage code (RB/RBLF/RBLFSCH).
make_uga_cmr <- function(path) {
  writexl::write_xlsx(list(
    "RB Treatment" = make_cmr_sheet_df(
      c("#rbtrt_year", "#rbtrt_disease", "#rbtrt_target"),
      list(c("2024", "RBLFSCH", "100"), c("2024", "RB", "200"))),
    "SCH Treatment" = make_cmr_sheet_df(
      c("#schtrt_year", "#schtrt_disease", "#schtrt_target"),
      list(c("2024", "RBLFSCH", "50"))),
    "LF MMDP" = make_cmr_sheet_df(
      c("#lfmmdp_year", "#lfmmdp_disease", "#lfmmdp_hydro_treated"),
      list(c("2024", "RBLF", "10"), c("2024", "RBLFSCH", "5")))
  ), path)
  path
}

test_that("eri_split_cmr routes each sheet to {disease}/programmatic/{measure} (dry run)", {
  tmp <- withr::local_tempfile(fileext = ".xlsx")
  make_uga_cmr(tmp)

  plan <- suppressWarnings(eri_split_cmr(tmp, "uga", dry_run = TRUE))
  expect_s3_class(plan, "tbl_df")

  expect_equal(plan$disease[plan$sheet == "RB Treatment"], "oncho")
  expect_equal(plan$data_type[plan$sheet == "RB Treatment"], "treatment")
  expect_match(plan$dest[plan$sheet == "RB Treatment"],
               "^uga/oncho/programmatic/treatment/staged/")
  expect_equal(plan$disease[plan$sheet == "SCH Treatment"], "sch")
  expect_match(plan$dest[plan$sheet == "SCH Treatment"],
               "^uga/sch/programmatic/treatment/staged/")
  expect_match(plan$dest[plan$sheet == "LF MMDP"],
               "^uga/lf/programmatic/mmdp/staged/")
  # The per-row program code is preserved, not split: RB Treatment keeps both rows.
  expect_equal(plan$n_rows[plan$sheet == "RB Treatment"], 2L)
})

test_that("eri_split_cmr keeps the per-row program code as a column (no disease split)", {
  tmp <- withr::local_tempfile(fileext = ".xlsx")
  make_uga_cmr(tmp)
  # The parsed RB Treatment sheet keeps #rbtrt_disease with RBLFSCH/RB intact.
  rb <- eri_ingest_cmr(tmp, sheet = "RB Treatment", country = "uga")
  expect_true("#rbtrt_disease" %in% names(rb))
  expect_setequal(rb[["#rbtrt_disease"]], c("RBLFSCH", "RB"))
})

test_that("every country's CMR schema routes at least one sheet to a registered measure", {
  measures <- names(erifunctions:::.eri_data_model()$data_types)
  for (country in c("eth", "nga", "sdn", "ssd", "tcd", "mad", "uga")) {
    schema <- load_cmr_schema(country)
    routed <- Filter(function(s) !is.null(s$disease) && !is.null(s$data_type), schema$sheets)
    expect_gt(length(routed), 0L,
              label = paste(country, "has no routable CMR sheets"))
    for (sheet in names(routed)) {
      dt <- routed[[sheet]]$data_type
      expect_true(dt %in% measures,
                  info = paste(country, "/", sheet, "data_type", dt, "is not a registered measure"))
    }
  }
})

test_that("every bundled CMR sheet declares routing keys (no silently-skipped data sheet)", {
  # Bundled CMR schemas only contain data sheets (reference tabs with no field
  # codes are excluded at generation), so every sheet must declare disease +
  # data_type or eri_split_cmr() would silently drop its data.
  for (country in c("eth", "nga", "sdn", "ssd", "tcd", "mad", "uga")) {
    schema <- load_cmr_schema(country)
    for (sheet in names(schema$sheets)) {
      sd <- schema$sheets[[sheet]]
      expect_false(is.null(sd$disease),
                   info = paste(country, "/", sheet, "missing disease routing key"))
      expect_false(is.null(sd$data_type),
                   info = paste(country, "/", sheet, "missing data_type routing key"))
    }
  }
})

test_that("eri_split_cmr summarizes absent sheets in one message (not a deferred pile)", {
  tmp <- withr::local_tempfile(fileext = ".xlsx")
  make_uga_cmr(tmp)  # 3 sheets present; the uga schema routes more, so some are skipped
  # The absent sheets are reported once as an informational summary, not warnings.
  expect_message(eri_split_cmr(tmp, "uga", dry_run = TRUE), "Skipped [0-9]+ sheet")
})

test_that("eri_split_cmr aborts when the workbook has none of the routable sheets", {
  tmp <- withr::local_tempfile(fileext = ".xlsx")
  writexl::write_xlsx(list(
    "Not A CMR Sheet" = make_cmr_sheet_df(c("#foo_year"), list(c("2024")))
  ), tmp)

  expect_error(
    suppressWarnings(eri_split_cmr(tmp, "uga", dry_run = TRUE)),
    "None of the .* routable sheets were found"
  )
})

test_that("eri_stage_cmr(period = NULL) auto-selects the most recent period", {
  calls    <- 0L
  read_src <- NULL
  mock_con <- structure(list(), class = "mock")

  local_mocked_bindings(
    storage_dir_exists  = function(...) TRUE,
    storage_file_exists = function(...) FALSE,
    list_storage_files  = function(container, dir, ...) {
      calls <<- calls + 1L
      if (calls == 1L) {
        # period directories under raw/filled_templates/{country}/ are YYYYMM
        tibble::tibble(name = paste0(dir, c("/202405", "/202406")), isdir = TRUE)
      } else {
        tibble::tibble(name = paste0(dir, "/uga_cmr_", basename(dir), ".xlsx"), isdir = FALSE)
      }
    },
    .package = "AzureStor"
  )
  local_mocked_bindings(
    .eri_blob_read   = function(con, src, dest, ...) { read_src <<- src; file.create(dest); invisible(dest) },
    .eri_blob_write  = function(...) invisible(NULL),
    .eri_write_log   = function(...) invisible(NULL),
    .eri_log_session = function(...) invisible(NULL),
    .eri_analyst_id  = function(...) "tester",
    get_azure_storage_connection = function(...) mock_con,
    .package = "erifunctions"
  )

  expect_message(
    eri_stage_cmr("uga", data_con = mock_con),
    "202406"   # most recent period, picked robustly via max()
  )
  expect_match(read_src, "202406")   # staged from the 202406 source dir
})

test_that("eri_split_cmr writes one parquet per routed sheet to the data blob", {
  tmp <- withr::local_tempfile(fileext = ".xlsx")
  make_uga_cmr(tmp)

  written <- character(0)
  local_mocked_bindings(
    storage_dir_exists  = function(...) TRUE,
    storage_file_exists = function(...) FALSE,
    .package = "AzureStor"
  )
  local_mocked_bindings(
    .eri_blob_write  = function(con, src, dest, ...) { written <<- c(written, dest); invisible(NULL) },
    .eri_write_log   = function(...) invisible(NULL),
    .eri_log_session = function(...) invisible(NULL),
    .package = "erifunctions"
  )

  suppressWarnings(
    eri_split_cmr(tmp, "uga", data_con = structure(list(), class = "mock"))
  )

  expect_length(written, 3L)
  expect_true(any(grepl("^uga/oncho/programmatic/treatment/staged/", written)))
  expect_true(any(grepl("^uga/sch/programmatic/treatment/staged/", written)))
  expect_true(any(grepl("^uga/lf/programmatic/mmdp/staged/", written)))
})
