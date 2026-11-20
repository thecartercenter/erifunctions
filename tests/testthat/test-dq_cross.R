# Pure-core tests for R/dq_cross.R -- no Azure, no schema loading. `tables`
# mirrors what eri_cmr_dq_report()'s loop already assembles: one entry per
# CMR sheet, with the already-canonicalized (post run_dq_checks()) data.

tbl <- function(sheet, disease, data_type, data) {
  list(sheet = sheet, disease = disease, data_type = data_type, data = data)
}

test_that("a source with no sheets: selects all tables for that (disease, data_type)", {
  tables <- list(
    tbl("RB Treatment", "oncho", "treatment", tibble::tibble(district = c("A", "B"), population = c(100, 200))),
    tbl("LF Treatment", "lf", "treatment", tibble::tibble(district = c("A", "B"), population = c(100, 200)))
  )
  rules <- list(pop_match = list(
    join_key = "district",
    lhs = list(sources = list(list(disease = "oncho", data_type = "treatment", column = "population"))),
    rhs = list(sources = list(list(disease = "lf", data_type = "treatment", column = "population"))),
    op = "=="
  ))
  flags <- .eri_cross_check_run(tables, rules)
  expect_equal(nrow(flags), 0L)
})

test_that("a source with sheets: selects only the named sheets, excluding others of the same measure", {
  tables <- list(
    tbl("CDD Training", "rblf", "training", tibble::tibble(district = "A", tot = 5)),
    tbl("ToT Regional",  "rblf", "training", tibble::tibble(district = "A", tot = 1000)) # would blow up the sum if included
  )
  rules <- list(r = list(
    join_key = "district",
    lhs = list(sources = list(list(disease = "rblf", data_type = "training", column = "tot",
                                   sheets = list("CDD Training")))),
    rhs = list(sources = list(list(disease = "rblf", data_type = "training", column = "tot",
                                   sheets = list("CDD Training")))),
    op = "=="
  ))
  flags <- .eri_cross_check_run(tables, rules)
  expect_equal(nrow(flags), 0L)  # 5 == 5, ToT's 1000 never entered the sum
})

test_that("zero matching tables produces zero flags and only an info message, not a warning", {
  tables <- list(tbl("RB Treatment", "oncho", "treatment", tibble::tibble(district = "A", treated = 10)))
  rules <- list(r = list(
    join_key = "district",
    lhs = list(sources = list(list(disease = "oncho", data_type = "treatment", column = "treated"))),
    rhs = list(sources = list(list(disease = "rblf", data_type = "training", column = "tot",
                                   sheets = list("CDD Training", "CS Training", "HW Training")))),
    op = "same_sign"
  ))
  expect_no_warning(flags <- .eri_cross_check_run(tables, rules))
  expect_equal(nrow(flags), 0L)
})

test_that("a multi-source side binds rows across sources before aggregating", {
  tables <- list(
    tbl("RB Treatment", "oncho", "treatment", tibble::tibble(district = "A", treated = 3)),
    tbl("LF Treatment",  "lf",    "treatment", tibble::tibble(district = "A", treated = 4)),
    tbl("CDD Training",  "rblf",  "training",  tibble::tibble(district = "A", tot = 7))
  )
  rules <- list(r = list(
    join_key = "district",
    lhs = list(agg = "sum", sources = list(
      list(disease = "oncho", data_type = "treatment", column = "treated"),
      list(disease = "lf", data_type = "treatment", column = "treated")
    )),
    rhs = list(agg = "sum", sources = list(list(disease = "rblf", data_type = "training", column = "tot"))),
    op = "=="
  ))
  flags <- .eri_cross_check_run(tables, rules)
  expect_equal(nrow(flags), 0L)  # 3+4 == 7
})

test_that("sum aggregates multiple rows (e.g. multiple treatment_round rows) per key", {
  tables <- list(
    tbl("RB Treatment", "oncho", "treatment",
        tibble::tibble(district = c("A", "A", "A"), treated = c(10, 20, 0))),
    tbl("LF Treatment", "lf", "treatment", tibble::tibble(district = "A", treated = 30))
  )
  rules <- list(r = list(
    join_key = "district",
    lhs = list(agg = "sum", sources = list(list(disease = "oncho", data_type = "treatment", column = "treated"))),
    rhs = list(agg = "sum", sources = list(list(disease = "lf", data_type = "treatment", column = "treated"))),
    op = "=="
  ))
  flags <- .eri_cross_check_run(tables, rules)
  expect_equal(nrow(flags), 0L)  # 10+20+0 == 30
})

test_that("sum returns NA (key skipped, not zero) when every value for a key is NA", {
  tables <- list(
    tbl("RB Treatment", "oncho", "treatment", tibble::tibble(district = "A", treated = NA_real_)),
    tbl("LF Treatment", "lf", "treatment", tibble::tibble(district = "A", treated = 0))
  )
  rules <- list(r = list(
    join_key = "district",
    lhs = list(agg = "sum", sources = list(list(disease = "oncho", data_type = "treatment", column = "treated"))),
    rhs = list(agg = "sum", sources = list(list(disease = "lf", data_type = "treatment", column = "treated"))),
    op = "same_sign"
  ))
  flags <- .eri_cross_check_run(tables, rules)
  expect_equal(nrow(flags), 0L)  # lhs is NA (no data), not 0 -- not "applicable", never compared
})

test_that("unique returns the single value when constant across rows", {
  tables <- list(
    tbl("RB Treatment", "oncho", "treatment",
        tibble::tibble(district = c("A", "A"), population = c(500, 500))),
    tbl("LF Treatment", "lf", "treatment", tibble::tibble(district = "A", population = 500))
  )
  rules <- list(r = list(
    join_key = "district",
    lhs = list(agg = "unique", sources = list(list(disease = "oncho", data_type = "treatment", column = "population"))),
    rhs = list(agg = "unique", sources = list(list(disease = "lf", data_type = "treatment", column = "population"))),
    op = "=="
  ))
  flags <- .eri_cross_check_run(tables, rules)
  expect_equal(nrow(flags), 0L)
})

test_that("unique with two distinct values flags a within-sheet inconsistency and excludes the key from comparison", {
  tables <- list(
    tbl("RB Treatment", "oncho", "treatment",
        tibble::tibble(district = c("A", "A"), population = c(500, 600))),
    tbl("LF Treatment", "lf", "treatment", tibble::tibble(district = "A", population = 500))
  )
  rules <- list(r = list(
    join_key = "district",
    lhs = list(agg = "unique", sources = list(list(disease = "oncho", data_type = "treatment", column = "population"))),
    rhs = list(agg = "unique", sources = list(list(disease = "lf", data_type = "treatment", column = "population"))),
    op = "=="
  ))
  flags <- .eri_cross_check_run(tables, rules)
  expect_equal(nrow(flags), 1L)
  expect_match(flags$issue, "not constant", fixed = TRUE)
  # NOT a population-mismatch flag -- the inconsistency itself is the only flag
  expect_false(any(grepl("cross_consistency \\[r\\]: district mismatch", flags$issue)))
})

test_that("max/min/mean/n produce expected scalars", {
  data_a <- tibble::tibble(district = c("A", "A", "A"), treated = c(1, 5, 9))

  # lhs reads oncho (data_a); rhs reads a different disease (lf) holding just
  # the expected constant, so the two sides never cross-contaminate.
  run_agg <- function(agg, expected) {
    tables <- list(
      tbl("S", "oncho", "treatment", data_a),
      tbl("S2", "lf", "treatment", tibble::tibble(district = "A", treated = expected))
    )
    rules <- list(r = list(
      join_key = "district",
      lhs = list(agg = agg, sources = list(list(disease = "oncho", data_type = "treatment", column = "treated"))),
      rhs = list(sources = list(list(disease = "lf", data_type = "treatment", column = "treated"))),
      op = "=="
    ))
    .eri_cross_check_run(tables, rules)
  }
  expect_equal(nrow(run_agg("max", 9)), 0L)
  expect_equal(nrow(run_agg("min", 1)), 0L)
  expect_equal(nrow(run_agg("mean", 5)), 0L)
  expect_equal(nrow(run_agg("n", 3)), 0L)  # 3 non-NA rows for district A
})

test_that("== flags a genuine mismatch and passes on equality", {
  tables <- list(
    tbl("RB Treatment", "oncho", "treatment", tibble::tibble(district = "A", population = 500)),
    tbl("LF Treatment", "lf", "treatment", tibble::tibble(district = "A", population = 450))
  )
  rules <- list(r = list(
    join_key = "district",
    lhs = list(sources = list(list(disease = "oncho", data_type = "treatment", column = "population"))),
    rhs = list(sources = list(list(disease = "lf", data_type = "treatment", column = "population"))),
    op = "=="
  ))
  flags <- .eri_cross_check_run(tables, rules)
  expect_equal(nrow(flags), 1L)
  expect_equal(flags$value, "A")
  expect_equal(flags$column, "district")
})

test_that("tolerance suppresses a within-tolerance difference", {
  tables <- list(
    tbl("RB Treatment", "oncho", "treatment", tibble::tibble(district = "A", population = 500)),
    tbl("LF Treatment", "lf", "treatment", tibble::tibble(district = "A", population = 501))
  )
  rules <- list(r = list(
    join_key = "district",
    lhs = list(sources = list(list(disease = "oncho", data_type = "treatment", column = "population"))),
    rhs = list(sources = list(list(disease = "lf", data_type = "treatment", column = "population"))),
    op = "==", tolerance = 1
  ))
  flags <- .eri_cross_check_run(tables, rules)
  expect_equal(nrow(flags), 0L)
})

test_that("same_sign covers all four combinations (Emalee's rules 2 and 3)", {
  mk <- function(treated_val, tot_val) {
    list(
      tbl("RB Treatment", "oncho", "treatment", tibble::tibble(district = "A", treated = treated_val)),
      tbl("LF Treatment", "lf", "treatment", tibble::tibble(district = "A", treated = 0)),
      tbl("CDD Training", "rblf", "training", tibble::tibble(district = "A", tot = tot_val))
    )
  }
  rules <- list(r = list(
    join_key = "district",
    lhs = list(agg = "sum", missing_as = 0, sources = list(
      list(disease = "oncho", data_type = "treatment", column = "treated"),
      list(disease = "lf", data_type = "treatment", column = "treated")
    )),
    rhs = list(agg = "sum", missing_as = 0, sources = list(
      list(disease = "rblf", data_type = "training", column = "tot", sheets = list("CDD Training"))
    )),
    op = "same_sign"
  ))
  expect_equal(nrow(.eri_cross_check_run(mk(10, 5), rules)), 0L)  # both >0
  expect_equal(nrow(.eri_cross_check_run(mk(0, 0), rules)), 0L)   # both ==0
  expect_equal(nrow(.eri_cross_check_run(mk(10, 0), rules)), 1L)  # treatment>0, training==0
  expect_equal(nrow(.eri_cross_check_run(mk(0, 5), rules)), 1L)   # treatment==0, training>0
})

test_that("<=, >=, and != behave as their symbols", {
  mk_tables <- function(l, r) list(
    tbl("A", "oncho", "treatment", tibble::tibble(district = "A", treated = l)),
    tbl("B", "lf", "treatment", tibble::tibble(district = "A", treated = r))
  )
  rule <- function(op) list(r = list(
    join_key = "district",
    lhs = list(sources = list(list(disease = "oncho", data_type = "treatment", column = "treated"))),
    rhs = list(sources = list(list(disease = "lf", data_type = "treatment", column = "treated"))),
    op = op
  ))
  expect_equal(nrow(.eri_cross_check_run(mk_tables(5, 10), rule("<="))), 0L)
  expect_equal(nrow(.eri_cross_check_run(mk_tables(10, 5), rule("<="))), 1L)
  expect_equal(nrow(.eri_cross_check_run(mk_tables(10, 5), rule(">="))), 0L)
  # "!=" asserts the two sides MUST differ: equal values violate it (flagged),
  # genuinely different values satisfy it (not flagged).
  expect_equal(nrow(.eri_cross_check_run(mk_tables(5, 5), rule("!="))), 1L)
  expect_equal(nrow(.eri_cross_check_run(mk_tables(5, 6), rule("!="))), 0L)
})

test_that("a key present on only one side, with no missing_as, is never flagged", {
  # The LF-subset case: LF only reports a fraction of oncho's districts.
  tables <- list(
    tbl("RB Treatment", "oncho", "treatment", tibble::tibble(district = c("A", "B"), population = c(500, 700))),
    tbl("LF Treatment", "lf", "treatment", tibble::tibble(district = "A", population = 500))
  )
  rules <- list(r = list(
    join_key = "district",
    lhs = list(sources = list(list(disease = "oncho", data_type = "treatment", column = "population"))),
    rhs = list(sources = list(list(disease = "lf", data_type = "treatment", column = "population"))),
    op = "=="
  ))
  flags <- .eri_cross_check_run(tables, rules)
  expect_equal(nrow(flags), 0L)  # district B (oncho only) is not a mismatch
})

test_that("missing_as on both sides flags a district with treatment but no training row at all", {
  tables <- list(
    tbl("RB Treatment", "oncho", "treatment", tibble::tibble(district = "A", treated = 50)),
    tbl("LF Treatment", "lf", "treatment", tibble::tibble(district = "A", treated = 0)),
    # the CDD Training sheet exists and has real data -- just none for district A
    # specifically, distinct from the "sheet doesn't exist in this workbook at
    # all" case (which correctly skips the whole rule, tested separately above)
    tbl("CDD Training", "rblf", "training", tibble::tibble(district = "B", tot = 20))
  )
  rules <- list(r = list(
    join_key = "district",
    lhs = list(agg = "sum", missing_as = 0, sources = list(
      list(disease = "oncho", data_type = "treatment", column = "treated"),
      list(disease = "lf", data_type = "treatment", column = "treated")
    )),
    rhs = list(agg = "sum", missing_as = 0, sources = list(
      list(disease = "rblf", data_type = "training", column = "tot",
          sheets = list("CDD Training", "CS Training", "HW Training"))
    )),
    op = "same_sign"
  ))
  flags <- .eri_cross_check_run(tables, rules)
  # District A: treatment>0, no training row -> missing_as fills training=0 -> flagged.
  # District B: no treatment row -> missing_as fills treatment=0, but training=20>0 ->
  # ALSO a genuine same_sign violation (the symmetric case), not a bug.
  expect_equal(nrow(flags), 2L)
  expect_setequal(flags$value, c("A", "B"))
})

test_that("NA and whitespace-only join keys are dropped", {
  tables <- list(
    tbl("RB Treatment", "oncho", "treatment",
        tibble::tibble(district = c("A", NA, "  "), population = c(500, 999, 999))),
    tbl("LF Treatment", "lf", "treatment", tibble::tibble(district = "A", population = 500))
  )
  rules <- list(r = list(
    join_key = "district",
    lhs = list(sources = list(list(disease = "oncho", data_type = "treatment", column = "population"))),
    rhs = list(sources = list(list(disease = "lf", data_type = "treatment", column = "population"))),
    op = "=="
  ))
  flags <- .eri_cross_check_run(tables, rules)
  expect_equal(nrow(flags), 0L)
})

test_that("whitespace-padded keys are trimmed and still match", {
  tables <- list(
    tbl("RB Treatment", "oncho", "treatment", tibble::tibble(district = "Jimma ", population = 500)),
    tbl("LF Treatment", "lf", "treatment", tibble::tibble(district = " Jimma", population = 450))
  )
  rules <- list(r = list(
    join_key = "district",
    lhs = list(sources = list(list(disease = "oncho", data_type = "treatment", column = "population"))),
    rhs = list(sources = list(list(disease = "lf", data_type = "treatment", column = "population"))),
    op = "=="
  ))
  flags <- .eri_cross_check_run(tables, rules)
  expect_equal(nrow(flags), 1L)
  expect_equal(flags$value, "Jimma")
})

test_that("an unknown op warns and skips that rule, while a valid rule in the same block still runs", {
  tables <- list(
    tbl("RB Treatment", "oncho", "treatment", tibble::tibble(district = "A", population = 500)),
    tbl("LF Treatment", "lf", "treatment", tibble::tibble(district = "A", population = 450))
  )
  rules <- list(
    bad = list(join_key = "district",
              lhs = list(sources = list(list(disease = "oncho", data_type = "treatment", column = "population"))),
              rhs = list(sources = list(list(disease = "lf", data_type = "treatment", column = "population"))),
              op = "approx"),
    good = list(join_key = "district",
               lhs = list(sources = list(list(disease = "oncho", data_type = "treatment", column = "population"))),
               rhs = list(sources = list(list(disease = "lf", data_type = "treatment", column = "population"))),
               op = "==")
  )
  expect_warning(flags <- .eri_cross_check_run(tables, rules), "malformed")
  expect_equal(nrow(flags), 1L)
  expect_match(flags$issue, "\\[good\\]")
})

test_that("an unknown agg warns and skips the rule", {
  tables <- list(
    tbl("RB Treatment", "oncho", "treatment", tibble::tibble(district = "A", population = 500)),
    tbl("LF Treatment", "lf", "treatment", tibble::tibble(district = "A", population = 450))
  )
  rules <- list(r = list(
    join_key = "district",
    lhs = list(agg = "median", sources = list(list(disease = "oncho", data_type = "treatment", column = "population"))),
    rhs = list(sources = list(list(disease = "lf", data_type = "treatment", column = "population"))),
    op = "=="
  ))
  expect_warning(flags <- .eri_cross_check_run(tables, rules), "agg")
  expect_equal(nrow(flags), 0L)
})

test_that("a missing join_key/lhs/rhs/sources/column each warn and skip the rule", {
  base <- list(
    join_key = "district",
    lhs = list(sources = list(list(disease = "oncho", data_type = "treatment", column = "population"))),
    rhs = list(sources = list(list(disease = "lf", data_type = "treatment", column = "population"))),
    op = "=="
  )
  variants <- list(
    no_join_key = modifyList(base, list(join_key = NULL)),
    no_lhs      = modifyList(base, list(lhs = NULL)),
    no_rhs      = modifyList(base, list(rhs = NULL)),
    no_op       = modifyList(base, list(op = NULL))
  )
  for (nm in names(variants)) {
    expect_warning(ok <- .eri_cross_validate_rule(nm, variants[[nm]]), "malformed", label = nm)
    expect_false(ok, label = nm)
  }

  # Built explicitly, not via modifyList(): modifyList()'s recursive merge on
  # nested unnamed lists (sources' elements aren't named) doesn't reliably
  # replace a deeply-nested field the way a naive override might suggest.
  no_column <- list(
    join_key = "district",
    lhs = list(sources = list(list(disease = "oncho", data_type = "treatment"))),  # column omitted
    rhs = list(sources = list(list(disease = "lf", data_type = "treatment", column = "population"))),
    op = "=="
  )
  expect_warning(ok <- .eri_cross_validate_rule("no_column", no_column), "malformed")
  expect_false(ok)
})

test_that("a join_key or column absent from a resolved table warns and skips that sheet, no flag", {
  tables <- list(
    tbl("RB Treatment", "oncho", "treatment", tibble::tibble(district = "A", population = 500)), # no `tot`
    tbl("LF Treatment", "lf", "treatment", tibble::tibble(district = "A", population = 450))
  )
  rules <- list(r = list(
    join_key = "district",
    lhs = list(sources = list(list(disease = "oncho", data_type = "treatment", column = "tot"))),  # doesn't exist
    rhs = list(sources = list(list(disease = "lf", data_type = "treatment", column = "population"))),
    op = "=="
  ))
  expect_warning(flags <- .eri_cross_check_run(tables, rules), "no column")
  expect_equal(nrow(flags), 0L)
})

test_that("emitted flags have the row/column/value/issue shape with the rule name in the message", {
  tables <- list(
    tbl("RB Treatment", "oncho", "treatment", tibble::tibble(district = "A", population = 500)),
    tbl("LF Treatment", "lf", "treatment", tibble::tibble(district = "A", population = 450))
  )
  rules <- list(rb_lf_pop_match = list(
    join_key = "district",
    lhs = list(sources = list(list(disease = "oncho", data_type = "treatment", column = "population"))),
    rhs = list(sources = list(list(disease = "lf", data_type = "treatment", column = "population"))),
    op = "==", message = "RB/LF population mismatch"
  ))
  flags <- .eri_cross_check_run(tables, rules)
  expect_named(flags, c("row", "column", "value", "issue"))
  expect_true(is.na(flags$row))
  expect_equal(flags$column, "district")
  expect_equal(flags$value, "A")
  expect_match(flags$issue, "^cross_consistency \\[rb_lf_pop_match\\]: RB/LF population mismatch")
})

test_that("an empty or NULL cross_consistency block produces zero flags with no warnings", {
  tables <- list(tbl("RB Treatment", "oncho", "treatment", tibble::tibble(district = "A", population = 500)))
  expect_no_warning(expect_equal(nrow(.eri_cross_check_run(tables, list())), 0L))
  expect_no_warning(expect_equal(nrow(.eri_cross_check_run(tables, NULL)), 0L))
})

test_that("every bundled CMR routing schema's cross_consistency rules are well-formed, and sheets: names are real", {
  schema_dir <- system.file("schemas", "cmr", package = "erifunctions")
  files <- list.files(schema_dir, pattern = "\\.yaml$", full.names = TRUE)
  expect_true(length(files) > 0L)

  checked_any <- FALSE
  for (f in files) {
    schema <- yaml::read_yaml(f)
    rules <- schema$cross_consistency
    if (is.null(rules) || length(rules) == 0L) next
    checked_any <- TRUE
    known_sheets <- names(schema$sheets)

    for (rule_name in names(rules)) {
      expect_true(.eri_cross_validate_rule(rule_name, rules[[rule_name]]),
                 label = paste0(basename(f), "::", rule_name))

      for (side_name in c("lhs", "rhs")) {
        for (src in rules[[rule_name]][[side_name]]$sources) {
          if (!is.null(src$sheets)) {
            bad <- setdiff(unlist(src$sheets), known_sheets)
            expect_length(bad, 0L)  # a typo'd sheet name would silently never match anything
          }
        }
      }
    }
  }
  expect_true(checked_any)  # this test is only meaningful if at least one schema exercises it (eth.yaml)
})

test_that("every cross_consistency source points at a measure the country routes, with real canonical columns (#373)", {
  # Guards the per-country copies of the rules: a source whose (disease, data_type) the
  # country doesn't route, or whose join_key/column its DQ schema doesn't define, would
  # silently skip ("no data") instead of checking anything.
  schema_dir <- system.file("schemas", "cmr", package = "erifunctions")
  checked <- character(0)
  for (f in list.files(schema_dir, pattern = "[.]yaml$", full.names = TRUE)) {
    cmr   <- yaml::read_yaml(f)
    rules <- cmr$cross_consistency
    if (is.null(rules) || length(rules) == 0L) next
    country <- sub("[.]yaml$", "", basename(f))
    checked <- c(checked, country)
    routed  <- unique(vapply(cmr$sheets, function(s) paste(s$disease, s$data_type), character(1)))
    for (rule_name in names(rules)) {
      rule <- rules[[rule_name]]
      for (side in c("lhs", "rhs")) for (src in rule[[side]]$sources) {
        lbl <- paste0(country, "::", rule_name, "::", side, "::", src$disease, "/", src$data_type)
        expect_true(paste(src$disease, src$data_type) %in% routed, label = lbl)
        dq <- suppressMessages(load_dq_schema(country, src$disease, "programmatic", src$data_type, azcontainer = NULL))
        expect_true(all(c(rule$join_key, src$column) %in% names(dq$columns)), label = lbl)
      }
    }
  }
  expect_setequal(checked, c("eth", "nga", "sdn", "ssd", "ht", "mad"))
})

test_that("the RB/LF population match tolerates a rounding difference but not a real one (#373)", {
  rule <- yaml::read_yaml(system.file("schemas", "cmr", "nga.yaml", package = "erifunctions"))$cross_consistency
  tables <- list(
    list(sheet = "RB Treatment", disease = "oncho", data_type = "treatment",
         data = tibble::tibble(district = c("A", "B", "C"), population = c(10000.4, 1000, 500), treated = 1)),
    list(sheet = "LF Treatment", disease = "lf", data_type = "treatment",
         data = tibble::tibble(district = c("A", "B", "C"), population = c(10000, 1003, 501), treated = 1))
  )
  flags <- suppressMessages(.eri_cross_check_run(tables, rule["rb_lf_pop_match"]))
  expect_equal(flags$value, c("B", "C"))   # A differs by 0.4 (rounding); B by 3 and C by 1 (real)
})

#### Per-country copies of Ethiopia's rules (#373 review): pin what each one says ####

.cmr_yaml <- function(country) yaml::read_yaml(system.file("schemas", "cmr", paste0(country, ".yaml"), package = "erifunctions"))

# A rule with the per-country parts removed: wording and training sheet names.
.cross_rule_core <- function(rule) {
  rule$description <- NULL
  rule$message     <- NULL
  for (side in c("lhs", "rhs")) {
    rule[[side]]$sources <- lapply(rule[[side]]$sources, function(s) { s$sheets <- NULL; s })
  }
  rule
}

test_that("each country carries exactly the expected cross rules, and they match Ethiopia's (#373)", {
  eth <- .cmr_yaml("eth")$cross_consistency
  expected <- list(
    nga = c("rb_lf_pop_match", "treatment_implies_training"),
    sdn = c("rb_lf_pop_match", "treatment_implies_training"),
    ssd = c("rb_lf_pop_match", "treatment_implies_training"),
    ht  = "treatment_implies_training",
    mad = "treatment_implies_training"
  )
  for (country in names(expected)) {
    rules <- .cmr_yaml(country)$cross_consistency
    expect_setequal(names(rules), expected[[country]])
    for (rule_name in names(rules)) {
      want <- .cross_rule_core(eth[[rule_name]])
      # Haiti and Madagascar have no RB tab: their treatment side is LF only.
      if (country %in% c("ht", "mad")) {
        want$lhs$sources <- Filter(function(s) s$disease != "oncho", want$lhs$sources)
      }
      expect_identical(.cross_rule_core(rules[[rule_name]]), want, label = paste0(country, "::", rule_name))
    }
  }
})

test_that("each country's training sheets are pinned and are routed to the source's own measure (#373)", {
  expected_sheets <- list(
    eth = c("CDD Training", "CS Training", "HW Training"),
    nga = c("CDD Training", "CS Training", "Health Workers Training"),
    sdn = c("CDD Training", "CS Training", "Health Workers Training"),
    ssd = c("CDD Training", "CS Training", "Health Workers Training"),
    ht  = c("CDD Training", "CS Training"),
    mad = c("Formation Distributeurs", "Formation SC", "Formation Travailleurs de Sante")
  )
  for (country in names(expected_sheets)) {
    cmr <- .cmr_yaml(country)
    src <- cmr$cross_consistency$treatment_implies_training$rhs$sources[[1]]
    expect_identical(unlist(src$sheets), expected_sheets[[country]], label = country)
    for (sh in unlist(src$sheets)) {
      # A real sheet routed to a different measure would be silently dropped at run time.
      expect_identical(c(cmr$sheets[[sh]]$disease, cmr$sheets[[sh]]$data_type),
                       c(src$disease, src$data_type), label = paste(country, sh))
    }
  }
})

test_that("every country's population match allows rounding (up to 0.5) and nothing more (#373)", {
  for (country in c("eth", "nga", "sdn", "ssd")) {
    rule <- .cmr_yaml(country)$cross_consistency["rb_lf_pop_match"]
    tables <- list(
      list(sheet = "RB Treatment", disease = "oncho", data_type = "treatment",
           data = tibble::tibble(district = c("A", "B", "C", "D"), population = c(10000.5, 1000, 500, 800))),
      list(sheet = "LF Treatment", disease = "lf", data_type = "treatment",
           data = tibble::tibble(district = c("A", "B", "C"), population = c(10001, 1000.6, 501)))
    )
    flags <- suppressMessages(.eri_cross_check_run(tables, rule))
    # A differs by exactly 0.5 (rounding); B by 0.6 and C by 1 (real); D is on RB only (not flagged).
    expect_equal(flags$value, c("B", "C"), label = country)
  }
})

test_that("Ethiopia's rules, which every other country is compared to, are pinned (#373 review)", {
  eth <- .cmr_yaml("eth")$cross_consistency
  pop <- eth$rb_lf_pop_match
  expect_identical(pop$join_key, "district")
  expect_identical(pop$op, "==")
  expect_identical(pop$tolerance, 0.5)
  expect_identical(c(pop$lhs$agg, pop$rhs$agg), c("unique", "unique"))
  expect_null(pop$lhs$missing_as)   # a district on only one tab is a coverage difference, never flagged
  expect_null(pop$rhs$missing_as)

  trn <- eth$treatment_implies_training
  expect_identical(trn$join_key, "district")
  expect_identical(trn$op, "same_sign")
  expect_identical(c(trn$lhs$agg, trn$rhs$agg), c("sum", "sum"))
  expect_identical(c(trn$lhs$missing_as, trn$rhs$missing_as), c(0L, 0L))   # no training row at all reads as 0

  # What each side reads: treated (not population) against training tot; population on both tabs.
  src <- function(side) lapply(side$sources, function(s) unlist(s[c("disease", "data_type", "column")]))
  expect_identical(src(trn$lhs), list(c(disease = "oncho", data_type = "treatment", column = "treated"),
                                      c(disease = "lf",    data_type = "treatment", column = "treated")))
  expect_identical(src(trn$rhs), list(c(disease = "rblf", data_type = "training", column = "tot")))
  expect_identical(src(pop$lhs), list(c(disease = "oncho", data_type = "treatment", column = "population")))
  expect_identical(src(pop$rhs), list(c(disease = "lf",    data_type = "treatment", column = "population")))
})

test_that("treatment_implies_training: a training tab with no rows counts as zero; an empty total is not checked (#373)", {
  rule <- .cmr_yaml("ht")$cross_consistency["treatment_implies_training"]
  lf <- list(sheet = "LF Treatment", disease = "lf", data_type = "treatment",
             data = tibble::tibble(district = c("D1", "D2"), treated = c(10, 5)))
  training <- function(d) list(sheet = "CDD Training", disease = "rblf", data_type = "training", data = d)

  # Tab present with no rows: treated districts read as zero training and are flagged.
  no_rows <- suppressMessages(.eri_cross_check_run(
    list(lf, training(tibble::tibble(district = character(), tot = numeric()))), rule))
  expect_setequal(no_rows$value, c("D1", "D2"))

  # Districts listed with an empty total: aggregates to NA, so not checked (decided 2026-11-20).
  empty_tot <- suppressMessages(.eri_cross_check_run(
    list(lf, training(tibble::tibble(district = c("D1", "D2"), tot = c(NA_real_, NA_real_)))), rule))
  expect_equal(nrow(empty_tot), 0L)
})
