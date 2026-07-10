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

test_that("eri_ingest_cmr returns tibble with field code columns plus excel_row", {
  tmp <- withr::local_tempfile(fileext = ".xlsx")
  make_cmr_xlsx(tmp)
  out <- eri_ingest_cmr(tmp, sheet = "RB Treatment")
  expect_s3_class(out, "tbl_df")
  expect_true(all(startsWith(setdiff(names(out), "excel_row"), "#")))
  expect_equal(ncol(out), 4L)  # 3 field codes + excel_row
})

test_that("eri_ingest_cmr's excel_row points at the real workbook row (data starts at row 6)", {
  tmp <- withr::local_tempfile(fileext = ".xlsx")
  make_cmr_xlsx(tmp,
    field_codes = c("#rbtrt_year", "#rbtrt_adm1"),
    data_rows   = list(c("2024", "North"), c("2025", "South"))
  )
  out <- eri_ingest_cmr(tmp, sheet = "RB Treatment")
  expect_equal(out$excel_row, c(6L, 7L))
})

test_that("eri_ingest_cmr's excel_row survives dropped all-NA spacer rows correctly", {
  tmp <- withr::local_tempfile(fileext = ".xlsx")
  make_cmr_xlsx(tmp,
    field_codes = c("#rbtrt_year", "#rbtrt_adm1"),
    data_rows   = list(c("2024", "North"), c(NA, NA), c("2025", "South"))
  )
  out <- eri_ingest_cmr(tmp, sheet = "RB Treatment")
  # the NA spacer row (would-be excel_row 7) is dropped, so row 2's real
  # position (excel_row 8) is preserved rather than being renumbered to 7
  expect_equal(out$excel_row, c(6L, 8L))
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
  expect_true(all(startsWith(setdiff(names(out), "excel_row"), "#")))
})

test_that("eri_ingest_cmr survives a real-world duplicate field code in row 5 without dropping data", {
  # Real defect seen in the RB-expansion CMR template's "RB Ento Surveys" sheet:
  # a field code was typed twice (a copy-paste slip across monthly blocks), which
  # otherwise crashes tibble::as_tibble() with "must not be duplicated" and aborts
  # ingestion of an otherwise-valid sheet.
  tmp <- withr::local_tempfile(fileext = ".xlsx")
  make_cmr_xlsx(tmp,
    field_codes = c("#rb_ento_surv_year", "#rb_ento_surv_otz", "#rb_ento_surv_otz"),
    data_rows   = list(c("2026", "ZoneA", "ZoneA-dup"), c("2026", "ZoneB", "ZoneB-dup"))
  )
  expect_warning(
    out <- eri_ingest_cmr(tmp, sheet = "RB Treatment"),
    "duplicate field code"
  )
  expect_equal(nrow(out), 2L)
  expect_true(all(c("#rb_ento_surv_otz", "#rb_ento_surv_otz__1") %in% names(out)))
  expect_equal(out[["#rb_ento_surv_otz"]], c("ZoneA", "ZoneB"))
  expect_equal(out[["#rb_ento_surv_otz__1"]], c("ZoneA-dup", "ZoneB-dup"))
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

test_that("eri_split_cmr scaffolds a starter schema template for an unknown country", {
  tmp <- withr::local_tempfile(fileext = ".xlsx")
  make_cmr_xlsx(tmp)
  wd <- withr::local_tempdir()
  withr::local_dir(wd)

  expect_error(
    eri_split_cmr(tmp, "xyz", dry_run = TRUE),
    "starter template"
  )
  expect_true(file.exists(file.path(wd, "xyz_cmr_schema.yaml")))

  # A second failure does not clobber an already-scaffolded (possibly edited) file.
  writeLines("edited-by-analyst", file.path(wd, "xyz_cmr_schema.yaml"))
  expect_error(eri_split_cmr(tmp, "xyz", dry_run = TRUE), "starter template")
  expect_identical(
    readLines(file.path(wd, "xyz_cmr_schema.yaml")),
    "edited-by-analyst"
  )
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

test_that("eri_split_cmr defaults to warning about superseded files, not deleting them", {
  tmp <- withr::local_tempfile(pattern = "202406_fixed", fileext = ".xlsx")
  make_uga_cmr(tmp)

  deleted <- character(0)
  local_mocked_bindings(
    storage_dir_exists  = function(...) TRUE,
    storage_file_exists = function(...) FALSE,
    list_storage_files  = function(container, dir, ...) {
      tibble::tibble(name = paste0(dir, "/202406_report_rb_treatment.parquet"), isdir = FALSE)
    },
    delete_storage_file = function(container, path, ...) { deleted <<- c(deleted, path); invisible(NULL) },
    .package = "AzureStor"
  )
  local_mocked_bindings(
    .eri_blob_write  = function(...) invisible(NULL),
    .eri_write_log   = function(...) invisible(NULL),
    .eri_log_session = function(...) invisible(NULL),
    .package = "erifunctions"
  )

  expect_warning(
    eri_split_cmr(tmp, "uga", data_con = structure(list(), class = "mock"), period = "202406"),
    "look.*superseded"
  )
  expect_length(deleted, 0L)   # nothing removed without opting in
})

test_that("eri_split_cmr(supersede_staged = TRUE) deletes an anchored match but not an unrelated file that merely mentions the period", {
  tmp <- withr::local_tempfile(pattern = "202406_fixed", fileext = ".xlsx")
  make_uga_cmr(tmp)

  deleted <- character(0)
  local_mocked_bindings(
    storage_dir_exists  = function(...) TRUE,
    storage_file_exists = function(...) FALSE,
    list_storage_files  = function(container, dir, ...) {
      tibble::tibble(
        name = paste0(dir, c(
          "/202406_report_rb_treatment.parquet",     # real prior version of THIS period -- should go
          "/other_202406_thing.parquet",             # mentions the digits, but not at the start -- must survive
          "/20240600_unrelated_report.parquet"       # a DIFFERENT, longer period that starts the same way -- must survive
        )),
        isdir = FALSE
      )
    },
    delete_storage_file = function(container, path, ...) { deleted <<- c(deleted, path); invisible(NULL) },
    .package = "AzureStor"
  )
  local_mocked_bindings(
    .eri_blob_write  = function(...) invisible(NULL),
    .eri_write_log   = function(...) invisible(NULL),
    .eri_log_session = function(...) invisible(NULL),
    .package = "erifunctions"
  )

  suppressWarnings(
    eri_split_cmr(tmp, "uga", data_con = structure(list(), class = "mock"),
                 period = "202406", supersede_staged = TRUE)
  )

  expect_true(any(grepl("202406_report_rb_treatment.parquet", deleted, fixed = TRUE)))
  expect_false(any(grepl("other_202406_thing.parquet", deleted, fixed = TRUE)))
  expect_false(any(grepl("20240600_unrelated_report.parquet", deleted, fixed = TRUE)))
  # this run's OWN file (same fbase as `tmp`) must never be in the delete list
  expect_false(any(grepl(tools::file_path_sans_ext(basename(tmp)), deleted, fixed = TRUE)))
})

test_that("eri_split_cmr does not delete anything when period can't be resolved", {
  tmp <- withr::local_tempfile(fileext = ".xlsx")   # no YYYYMM_ prefix, no period passed
  make_uga_cmr(tmp)

  list_called <- FALSE
  local_mocked_bindings(
    storage_dir_exists  = function(...) TRUE,
    storage_file_exists = function(...) FALSE,
    list_storage_files  = function(...) { list_called <<- TRUE; tibble::tibble(name = character(0), isdir = logical(0)) },
    .package = "AzureStor"
  )
  local_mocked_bindings(
    .eri_blob_write  = function(...) invisible(NULL),
    .eri_write_log   = function(...) invisible(NULL),
    .eri_log_session = function(...) invisible(NULL),
    .package = "erifunctions"
  )

  suppressWarnings(
    eri_split_cmr(tmp, "uga", data_con = structure(list(), class = "mock"))
  )
  expect_false(list_called)
})

test_that("eri_split_cmr mirror_pipeline uploads the raw file to the legacy raw-drop location", {
  tmp <- withr::local_tempfile(fileext = ".xlsx")
  make_uga_cmr(tmp)

  mirrored <- character(0)
  local_mocked_bindings(
    storage_dir_exists  = function(...) TRUE,
    storage_file_exists = function(...) FALSE,
    .package = "AzureStor"
  )
  local_mocked_bindings(
    .eri_blob_write  = function(con, src, dest, ...) { mirrored <<- c(mirrored, dest); invisible(NULL) },
    .eri_write_log   = function(...) invisible(NULL),
    .eri_log_session = function(...) invisible(NULL),
    get_azure_storage_connection = function(...) structure(list(), class = "mock"),
    .package = "erifunctions"
  )

  suppressWarnings(
    eri_split_cmr(tmp, "uga", data_con = structure(list(), class = "mock"),
                  mirror_pipeline = "rb-expansion", period = "202406")
  )

  legacy_dest <- mirrored[grepl("raw/filled_templates", mirrored)]
  expect_length(legacy_dest, 1L)
  expect_match(legacy_dest, "^health-rb-country-expansion-dev/raw/filled_templates/uga/202406/")
  # Generated name, not the raw local filename (which can carry characters
  # that break the storage REST call) -- country_period_timestamp.ext.
  expect_match(legacy_dest, "uga_202406_[0-9]{8}T[0-9]{6}Z\\.xlsx$")
  expect_false(grepl(basename(tmp), legacy_dest, fixed = TRUE))
})

test_that("eri_split_cmr mirror_pipeline auto-detects the period from a YYYYMM_ filename", {
  tmp <- withr::local_tempfile(pattern = "202605_report", fileext = ".xlsx")
  make_uga_cmr(tmp)

  mirrored <- character(0)
  local_mocked_bindings(
    storage_dir_exists  = function(...) TRUE,
    storage_file_exists = function(...) FALSE,
    .package = "AzureStor"
  )
  local_mocked_bindings(
    .eri_blob_write  = function(con, src, dest, ...) { mirrored <<- c(mirrored, dest); invisible(NULL) },
    .eri_write_log   = function(...) invisible(NULL),
    .eri_log_session = function(...) invisible(NULL),
    get_azure_storage_connection = function(...) structure(list(), class = "mock"),
    .package = "erifunctions"
  )

  suppressWarnings(
    eri_split_cmr(tmp, "uga", data_con = structure(list(), class = "mock"),
                  mirror_pipeline = "rb-expansion")
  )

  legacy_dest <- mirrored[grepl("raw/filled_templates", mirrored)]
  expect_match(legacy_dest, "/202605/")
})

test_that("eri_split_cmr mirror_pipeline dry_run previews without writing", {
  tmp <- withr::local_tempfile(fileext = ".xlsx")
  make_uga_cmr(tmp)

  expect_message(
    suppressWarnings(
      eri_split_cmr(tmp, "uga", dry_run = TRUE, mirror_pipeline = "rb-expansion", period = "202406")
    ),
    "Would also mirror raw file"
  )
})

test_that("eri_split_cmr mirror_pipeline errors clearly for an unregistered pipeline/country/period", {
  tmp <- withr::local_tempfile(fileext = ".xlsx")
  make_uga_cmr(tmp)

  expect_error(
    eri_split_cmr(tmp, "uga", dry_run = TRUE, mirror_pipeline = "not-a-pipeline"),
    "Unknown pipeline"
  )
  expect_error(
    eri_split_cmr(tmp, "zzz", dry_run = TRUE, mirror_pipeline = "rb-expansion", period = "202406"),
    "not registered for pipeline"
  )
  expect_error(
    eri_split_cmr(tmp, "dr", dry_run = TRUE, mirror_pipeline = "hsp-mal"),
    "no legacy raw-drop location"
  )
  expect_error(
    eri_split_cmr(tmp, "uga", dry_run = TRUE, mirror_pipeline = "rb-expansion"),
    "Could not parse"
  )
})

test_that("eri_split_cmr dry_run alerts clean when nothing was skipped or warned", {
  tmp <- withr::local_tempfile(fileext = ".xlsx")
  make_cmr_xlsx(tmp, sheet_name = "RB Treatment")

  # A schema that routes exactly the one sheet the file has -- the genuinely
  # zero-skip, zero-warning case.
  local_mocked_bindings(
    load_cmr_schema = function(country) list(
      country = country, sheets = list(
        "RB Treatment" = list(field_code_prefix = "#rbtrt_", disease = "oncho",
                              data_type = "treatment", required_fields = "#rbtrt_year")
      )
    ),
    .package = "erifunctions"
  )

  expect_message(
    eri_split_cmr(tmp, "uga", dry_run = TRUE),
    "Dry run clean"
  )
})

test_that("eri_split_cmr dry_run with issues warns instead of claiming clean, and logs for triage", {
  tmp <- withr::local_tempfile(fileext = ".xlsx")
  make_cmr_xlsx(tmp,
    field_codes = c("#rb_ento_surv_year", "#rb_ento_surv_otz", "#rb_ento_surv_otz"),
    sheet_name  = "RB Treatment"
  )

  logged <- list()
  local_mocked_bindings(
    storage_dir_exists = function(...) TRUE,
    .package = "AzureStor"
  )
  local_mocked_bindings(
    .eri_write_log = function(log_list, ...) {
      logged[[length(logged) + 1L]] <<- log_list
      "uga/rblf/cmr/logs/fake_dryrun.yaml"
    },
    get_azure_storage_connection = function(...) structure(list(), class = "mock"),
    .package = "erifunctions"
  )

  expect_warning(
    expect_message(
      eri_split_cmr(tmp, "uga", dry_run = TRUE, data_con = structure(list(), class = "mock")),
      "Dry run found"
    ),
    "duplicate field code"
  )

  expect_length(logged, 1L)
  expect_equal(logged[[1]]$operation, "eri_split_cmr_dryrun")
  expect_equal(logged[[1]]$status, "needs_review")
  expect_true(length(logged[[1]]$warnings) > 0L)
})

test_that("eri_cmr_last_plan reconstructs a plan from the persisted op-log", {
  fake_entry <- list(
    operation = "eri_split_cmr", status = "success",
    plan = list(
      list(sheet = "RB Treatment", disease = "oncho", data_type = "treatment",
          dest = "sdn/oncho/programmatic/treatment/staged/x.parquet", n_rows = 10L),
      list(sheet = "LF Treatment", disease = "lf", data_type = "treatment",
          dest = "sdn/lf/programmatic/treatment/staged/x.parquet", n_rows = 5L)
    )
  )

  local_mocked_bindings(
    eri_logs = function(...) tibble::tibble(
      log_path = "sdn/rblf/cmr/logs/fake.yaml", period = "202605",
      operation = "eri_split_cmr", status = "success"
    ),
    .eri_blob_read = function(con, src, dest, ...) {
      yaml::write_yaml(fake_entry, dest); invisible(dest)
    },
    .package = "erifunctions"
  )

  plan <- eri_cmr_last_plan("sdn", "202605", data_con = structure(list(), class = "mock"))
  expect_s3_class(plan, "tbl_df")
  expect_equal(nrow(plan), 2L)
  expect_setequal(plan$disease, c("oncho", "lf"))
})

test_that("eri_cmr_last_plan errors clearly when nothing is logged for that period", {
  local_mocked_bindings(
    eri_logs = function(...) tibble::tibble(
      log_path = character(0), period = character(0),
      operation = character(0), status = character(0)
    ),
    .package = "erifunctions"
  )
  expect_error(
    eri_cmr_last_plan("sdn", "202605", data_con = structure(list(), class = "mock")),
    "No successful"
  )
})

test_that("eri_approve_cmr blocks and reports when a measure was never DQ-checked", {
  plan <- tibble::tibble(
    sheet = c("RB Treatment", "LF Treatment"), disease = c("oncho", "lf"),
    data_type = c("treatment", "treatment"), dest = c("a", "b"), n_rows = c(1L, 1L)
  )

  local_mocked_bindings(
    eri_logs = function(...) tibble::tibble(
      log_path = character(0), period = character(0),
      status = character(0), handled = logical(0), n_issues = integer(0)
    ),
    .package = "erifunctions"
  )

  result <- eri_approve_cmr("sdn", "202605", plan = plan, data_con = structure(list(), class = "mock"))
  expect_equal(nrow(result), 2L)
  expect_true(all(grepl("never DQ-checked", result$issue)))
})

test_that("eri_approve_cmr blocks on unresolved DQ flags and does not call eri_approve", {
  plan <- tibble::tibble(
    sheet = "RB Treatment", disease = "oncho",
    data_type = "treatment", dest = "a", n_rows = 1L
  )

  approve_called <- FALSE
  local_mocked_bindings(
    eri_logs = function(...) tibble::tibble(
      log_path = "sdn/oncho/programmatic/treatment/logs/x.yaml", period = "202605",
      status = "needs_review", handled = FALSE, n_issues = 3L
    ),
    eri_approve = function(...) { approve_called <<- TRUE },
    .package = "erifunctions"
  )

  result <- eri_approve_cmr("sdn", "202605", plan = plan, data_con = structure(list(), class = "mock"))
  expect_false(approve_called)
  expect_match(result$issue, "3 unresolved DQ flag")
})

test_that("eri_approve_cmr approves every measure once all are clean", {
  plan <- tibble::tibble(
    sheet = c("RB Treatment", "LF Treatment"), disease = c("oncho", "lf"),
    data_type = c("treatment", "treatment"), dest = c("a", "b"), n_rows = c(1L, 1L)
  )

  approved <- list()
  local_mocked_bindings(
    eri_logs = function(...) tibble::tibble(
      log_path = "sdn/x/programmatic/treatment/logs/x.yaml", period = "202605",
      status = "clean", handled = FALSE, n_issues = 0L
    ),
    eri_approve = function(country, disease, data_source, period, data_type = NULL, azcontainer = NULL) {
      approved[[length(approved) + 1L]] <<- list(disease = disease, data_type = data_type)
    },
    .package = "erifunctions"
  )

  result <- eri_approve_cmr("sdn", "202605", plan = plan, data_con = structure(list(), class = "mock"))
  expect_length(approved, 2L)
  expect_equal(nrow(result), 2L)
})

test_that("eri_approve_cmr records a dq_reviewed cross-reference in its own op-log", {
  plan <- tibble::tibble(
    sheet = "RB Treatment", disease = "oncho",
    data_type = "treatment", dest = "a", n_rows = 1L
  )
  logged <- list()
  local_mocked_bindings(
    eri_logs = function(...) tibble::tibble(
      log_path = "sdn/oncho/programmatic/treatment/logs/dq.yaml", period = "202605",
      status = "clean", handled = FALSE, n_issues = 0L
    ),
    eri_approve = function(...) invisible(NULL),
    .eri_write_log = function(log_list, ...) {
      logged[[length(logged) + 1L]] <<- log_list
      "sdn/rblf/cmr/logs/fake_approve_cmr.yaml"
    },
    .package = "erifunctions"
  )

  eri_approve_cmr("sdn", "202605", plan = plan, data_con = structure(list(), class = "mock"))

  expect_length(logged, 1L)
  expect_equal(logged[[1]]$operation, "eri_approve_cmr")
  expect_true("sdn/oncho/programmatic/treatment/logs/dq.yaml" %in% unlist(logged[[1]]$dq_reviewed))
})

test_that("eri_cmr_dq_report combines every measure's flags into one tibble with usable flag_ids", {
  plan <- tibble::tibble(
    sheet = c("RB Treatment", "LF Treatment"), disease = c("oncho", "lf"),
    data_type = c("treatment", "treatment"),
    dest = c("sdn/oncho/programmatic/treatment/staged/a.parquet",
            "sdn/lf/programmatic/treatment/staged/b.parquet"),
    n_rows = c(1L, 1L)
  )

  fake_result <- structure(list(data = tibble::tibble(x = 1), log = tibble::tibble(row = integer()),
                                flags = tibble::tibble(row = 1L, column = "district",
                                                        value = "Bad", issue = "not allowed")),
                           class = "dq_result")

  local_mocked_bindings(
    eri_read = function(...) tibble::tibble(x = 1),
    load_dq_schema = function(...) list(columns = list()),
    run_dq_checks = function(...) fake_result,
    .eri_dq_log_write = function(result, country, disease, data_source, data_type, period, data_con) {
      list(n_flags = 1L, status = "needs_review",
          log_path = paste0(country, "/", disease, "/", data_source, "/", data_type, "/logs/x.yaml"),
          flags = list(list(index = 1, row = 1L, column = "district", value = "Bad",
                            issue = "not allowed", status = "open")))
    },
    .package = "erifunctions"
  )

  flags <- eri_cmr_dq_report("sdn", "202605", plan = plan, data_con = structure(list(), class = "mock"))
  expect_equal(nrow(flags), 2L)
  expect_setequal(flags$disease, c("oncho", "lf"))
  expect_true(all(grepl("::1$", flags$flag_id)))
  expect_true(all(flags$status == "open"))
})

test_that("eri_cmr_dq_report returns a zero-row tibble when every measure is clean", {
  plan <- tibble::tibble(
    sheet = "RB Treatment", disease = "oncho",
    data_type = "treatment", dest = "sdn/oncho/programmatic/treatment/staged/a.parquet",
    n_rows = 1L
  )
  clean_result <- structure(list(data = tibble::tibble(x = 1), log = tibble::tibble(row = integer()),
                                 flags = tibble::tibble(row = integer(), column = character(),
                                                         value = character(), issue = character())),
                            class = "dq_result")

  local_mocked_bindings(
    eri_read = function(...) tibble::tibble(x = 1),
    load_dq_schema = function(...) list(columns = list()),
    run_dq_checks = function(...) clean_result,
    .eri_dq_log_write = function(...) list(n_flags = 0L, status = "clean", log_path = "x.yaml", flags = list()),
    .package = "erifunctions"
  )

  flags <- eri_cmr_dq_report("sdn", "202605", plan = plan, data_con = structure(list(), class = "mock"))
  expect_equal(nrow(flags), 0L)
})

test_that("eri_cmr_dq_report(supersede = TRUE) auto-resolves prior open entries for the same measure/period", {
  plan <- tibble::tibble(
    sheet = "RB Treatment", disease = "oncho",
    data_type = "treatment", dest = "sdn/oncho/programmatic/treatment/staged/a.parquet",
    n_rows = 1L
  )
  clean_result <- structure(list(data = tibble::tibble(x = 1), log = tibble::tibble(row = integer()),
                                 flags = tibble::tibble(row = integer(), column = character(),
                                                         value = character(), issue = character())),
                            class = "dq_result")
  resolved <- character(0)

  local_mocked_bindings(
    eri_read = function(...) tibble::tibble(x = 1),
    load_dq_schema = function(...) list(columns = list()),
    run_dq_checks = function(...) clean_result,
    .eri_dq_log_write = function(...) list(n_flags = 0L, status = "clean",
                                           log_path = "sdn/oncho/programmatic/treatment/logs/new.yaml",
                                           flags = list()),
    eri_logs = function(...) tibble::tibble(
      log_path = c("sdn/oncho/programmatic/treatment/logs/old1.yaml",
                  "sdn/oncho/programmatic/treatment/logs/new.yaml"),  # includes the just-written entry itself
      period = c("202605", "202605")
    ),
    eri_logs_resolve = function(log_path, note = NULL, ...) { resolved <<- c(resolved, log_path); invisible(TRUE) },
    .package = "erifunctions"
  )

  eri_cmr_dq_report("sdn", "202605", plan = plan, data_con = structure(list(), class = "mock"))

  expect_equal(resolved, "sdn/oncho/programmatic/treatment/logs/old1.yaml")  # not the entry just written
})

test_that("eri_cmr_dq_report(supersede = FALSE) leaves prior entries alone", {
  plan <- tibble::tibble(
    sheet = "RB Treatment", disease = "oncho",
    data_type = "treatment", dest = "sdn/oncho/programmatic/treatment/staged/a.parquet",
    n_rows = 1L
  )
  clean_result <- structure(list(data = tibble::tibble(x = 1), log = tibble::tibble(row = integer()),
                                 flags = tibble::tibble(row = integer(), column = character(),
                                                         value = character(), issue = character())),
                            class = "dq_result")
  resolve_called <- FALSE

  local_mocked_bindings(
    eri_read = function(...) tibble::tibble(x = 1),
    load_dq_schema = function(...) list(columns = list()),
    run_dq_checks = function(...) clean_result,
    .eri_dq_log_write = function(...) list(n_flags = 0L, status = "clean",
                                           log_path = "sdn/oncho/programmatic/treatment/logs/new.yaml",
                                           flags = list()),
    eri_logs = function(...) tibble::tibble(
      log_path = "sdn/oncho/programmatic/treatment/logs/old1.yaml", period = "202605"
    ),
    eri_logs_resolve = function(...) { resolve_called <<- TRUE; invisible(TRUE) },
    .package = "erifunctions"
  )

  eri_cmr_dq_report("sdn", "202605", plan = plan, supersede = FALSE, data_con = structure(list(), class = "mock"))

  expect_false(resolve_called)
})

test_that("eri_cmr_dq_report's excel_row survives real run_dq_checks() row-dropping (integration, not mocked)", {
  tmp <- withr::local_tempfile(fileext = ".xlsx")
  make_cmr_xlsx(tmp,
    field_codes = c("#rbtrt_year", "#rbtrt_adm1", "#rbtrt_treated"),
    # row 2 (would-be excel_row 7) is an all-NA spacer, dropped by eri_ingest_cmr;
    # row 3 (excel_row 8) has the out-of-range value that should get flagged.
    data_rows = list(c("2024", "North", "50"), c(NA, NA, NA), c("2024", "South", "999"))
  )
  staged <- eri_ingest_cmr(tmp, sheet = "RB Treatment")
  expect_equal(staged$excel_row, c(6L, 8L))  # sanity-check the ingest side first

  plan <- tibble::tibble(
    sheet = "RB Treatment", disease = "oncho",
    data_type = "treatment", dest = "sdn/oncho/programmatic/treatment/staged/a.parquet", n_rows = 2L
  )
  schema <- list(columns = list(
    year    = list(required = TRUE, type = "numeric", aliases = "#rbtrt_year", range = c(1990, 2035)),
    treated = list(required = TRUE, type = "numeric", aliases = "#rbtrt_treated", range = c(0, 100))
  ))

  local_mocked_bindings(
    eri_read = function(...) staged,
    load_dq_schema = function(...) schema,
    .eri_write_log = function(...) "sdn/oncho/programmatic/treatment/logs/x.yaml",
    .package = "erifunctions"
  )

  flags <- eri_cmr_dq_report("sdn", "202605", plan = plan, data_con = structure(list(), class = "mock"))

  expect_equal(nrow(flags), 1L)
  expect_equal(flags$excel_row, 8L)   # NOT 2 (the post-drop row index) or 7 (pre-drop, wrong row)
})
