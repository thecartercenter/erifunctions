#### Tests for eri_query (serverless DuckDB query layer) ####

skip_if_not_installed("duckdb")
skip_if_not_installed("DBI")

# --- explicit tables (joins / aggregation) ------------------------------------

test_that("eri_query joins explicit data.frame tables", {
  a <- tibble::tibble(id = 1:3, x = c(10, 20, 30))
  b <- tibble::tibble(id = 1:3, y = c("p", "q", "r"))
  out <- suppressMessages(eri_query(
    "SELECT a.id, a.x, b.y FROM a JOIN b USING (id) ORDER BY a.id",
    tables = list(a = a, b = b)
  ))
  expect_s3_class(out, "tbl_df")
  expect_equal(out$x, c(10, 20, 30))
  expect_equal(out$y, c("p", "q", "r"))
})

test_that("eri_query aggregates", {
  d <- tibble::tibble(grp = c("a", "a", "b"), v = c(1, 2, 3))
  out <- suppressMessages(eri_query(
    "SELECT grp, SUM(v) AS s FROM d GROUP BY grp ORDER BY grp", tables = list(d = d)
  ))
  expect_equal(out$grp, c("a", "b"))
  expect_equal(out$s, c(3, 3))
})

test_that("eri_query reads a local parquet path (no Azure)", {
  d <- tibble::tibble(a = 1:2)
  f <- withr::local_tempfile(fileext = ".parquet")
  arrow::write_parquet(d, f)
  out <- suppressMessages(eri_query("SELECT COUNT(*) AS n FROM t", tables = list(t = f)))
  expect_equal(out$n, 2)
})

# --- catalog-driven roll-up ---------------------------------------------------

test_that("eri_query stamps provenance and unions matching processed files", {
  cat_rows <- tibble::tibble(
    path        = c("uga/malaria/surveillance/aggregate/processed/2026-01.parquet",
                    "ht/malaria/surveillance/aggregate/processed/2026-01.parquet"),
    country     = c("uga", "ht"),
    disease     = c("malaria", "malaria"),
    data_source = c("surveillance", "surveillance"),
    data_type   = c("aggregate", "aggregate"),
    period      = c("2026-01", "2026-01")
  )
  local_mocked_bindings(
    eri_catalog_query = function(...) cat_rows,
    .eri_query_read_one = function(value, data_con) {
      if (startsWith(value, "uga/")) tibble::tibble(cases = c(5, 7))
      else                           tibble::tibble(cases = 3)
    },
    get_azure_storage_connection = function(...) "mock_con",
    .package = "erifunctions"
  )

  out <- suppressMessages(eri_query(
    "SELECT country, SUM(cases) AS cases FROM data GROUP BY country ORDER BY country",
    disease = "malaria", data_type = "aggregate"
  ))
  expect_setequal(out$country, c("ht", "uga"))
  expect_equal(out$cases[out$country == "uga"], 12)
  expect_equal(out$cases[out$country == "ht"], 3)
})

test_that("eri_query warns when a provenance column collides with the data", {
  cat_rows <- tibble::tibble(
    path = "uga/malaria/surveillance/aggregate/processed/2026-01.parquet",
    country = "uga", disease = "malaria", data_source = "surveillance",
    data_type = "aggregate", period = "2026-01"
  )
  local_mocked_bindings(
    eri_catalog_query = function(...) cat_rows,
    .eri_query_read_one = function(value, data_con) tibble::tibble(period = "in-file", cases = 1),
    get_azure_storage_connection = function(...) "mock_con",
    .package = "erifunctions"
  )
  expect_warning(
    out <- suppressMessages(eri_query("SELECT period, cases FROM data", disease = "malaria")),
    "Provenance column"
  )
  expect_equal(out$period, "2026-01")   # catalog value wins
})

test_that("eri_query aborts when no processed dataset matches", {
  local_mocked_bindings(
    eri_catalog_query = function(...) tibble::tibble(),
    get_azure_storage_connection = function(...) "mock_con",
    .package = "erifunctions"
  )
  expect_error(
    suppressMessages(eri_query("SELECT * FROM data", disease = "nope")),
    "No processed datasets"
  )
})

# --- input validation ---------------------------------------------------------

test_that("eri_query rejects empty scope, multi-string sql, and unnamed tables", {
  expect_error(eri_query("SELECT 1"), "Nothing to query")
  expect_error(eri_query(c("a", "b"), tables = list(x = tibble::tibble(a = 1))), "single SQL")
  expect_error(
    suppressMessages(eri_query("SELECT * FROM x", tables = list(tibble::tibble(a = 1)))),
    "named list"
  )
})
