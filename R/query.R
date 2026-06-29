#### eri_query — serverless SQL across processed parquet via DuckDB (ADR-0004) ####
#
# Keeps the Azure blob as the system of record (parquet stays canonical) and adds a
# zero-server query layer: attach the relevant processed parquet into an in-process
# DuckDB session and run SQL across them. The catalog (ADR-0002) is the index that says
# which files to attach for a given country/disease/data_type. DuckDB + DBI are optional
# (Suggests) -- analysts who never query don't pay for them.

# Resolve one `tables` entry to a tibble: a data.frame as-is, a local parquet path read
# directly, or a `data/` blob path read via eri_read().
#' @keywords internal
.eri_query_read_one <- function(value, data_con) {
  if (is.data.frame(value)) return(tibble::as_tibble(value))
  if (!is.character(value) || length(value) != 1L)
    cli::cli_abort("Each {.arg tables} entry must be a {.cls data.frame} or a single file path.")
  if (file.exists(value)) return(tibble::as_tibble(arrow::read_parquet(value)))
  eri_read(value, azcontainer = data_con)        # treat as a blob path under data/
}

#' Query processed data with SQL (serverless DuckDB)
#'
#' Run SQL across one or more **processed** datasets without standing up a database
#' or writing a chain of per-file reads. `eri_query()` attaches the relevant
#' parquet into an in-process [DuckDB](https://duckdb.org) session and returns the
#' result as a tibble. The Azure blob stays the system of record (ADR-0004).
#'
#' There are two ways to put data in scope, and they compose:
#'
#' * **Catalog-driven (roll-ups).** Pass any of `country` / `disease` /
#'   `data_source` / `data_type` / `period`; `eri_query()` looks up the matching
#'   **processed** files in the data catalog, reads them, stamps each row with its
#'   `country` / `disease` / `data_source` / `data_type` / `period`, and unions them
#'   into a single table named by `table` (default `"data"`). This makes
#'   cross-country / cross-period aggregation a one-liner:
#'   `SELECT country, SUM(total_cases) FROM data GROUP BY country`.
#' * **Explicit tables (joins).** Pass `tables = list(name = x)` where each `x` is a
#'   data.frame, a local `.parquet` path, or a `data/` blob path. Each is registered
#'   under its name so you can join, e.g. cases to a population table.
#'
#' @param sql `chr` A single SQL statement (DuckDB dialect) referencing the
#'   in-scope table names.
#' @param country,disease,data_source,data_type,period Catalog filters selecting
#'   the **processed** datasets to attach as the `table` view. Any combination;
#'   all `NULL` (default) means "use only `tables`".
#' @param table `chr` Name for the catalog-driven table in SQL (default `"data"`).
#' @param tables Named list of additional tables to register: each entry a
#'   data.frame, a local parquet path, or a `data/` blob path.
#' @param data_con Azure container for the `data/` blob; `NULL` connects
#'   automatically (only when a catalog query or a blob path is actually needed,
#'   so pure data.frame queries stay offline).
#' @return A tibble of the query result.
#' @section Requirements:
#'   Needs the optional `duckdb` and `DBI` packages
#'   (`install.packages(c("duckdb", "DBI"))`). Very large cross-dataset scans are
#'   bounded by local memory / download (ADR-0004).
#' @examples
#' \dontrun{
#' # Cross-country roll-up from the catalog
#' eri_query(
#'   "SELECT country, SUM(total_cases) AS cases FROM data GROUP BY country ORDER BY cases DESC",
#'   disease = "malaria", data_type = "aggregate"
#' )
#'
#' # Join an approved dataset to a population table you supply
#' eri_query(
#'   "SELECT d.adm1, SUM(d.cases) * 1000.0 / p.pop AS rate
#'      FROM data d JOIN pop p USING (adm1) GROUP BY d.adm1, p.pop",
#'   disease = "malaria", data_type = "case", tables = list(pop = pop_df)
#' )
#' }
#' @export
eri_query <- function(sql,
                      country     = NULL,
                      disease     = NULL,
                      data_source = NULL,
                      data_type   = NULL,
                      period      = NULL,
                      table       = "data",
                      tables      = NULL,
                      data_con    = NULL) {
  rlang::check_installed(c("duckdb", "DBI"), reason = "for `eri_query()` (the DuckDB query layer).")
  if (!is.character(sql) || length(sql) != 1L)
    cli::cli_abort("{.arg sql} must be a single SQL string.")

  has_filter <- !is.null(country) || !is.null(disease) || !is.null(data_source) ||
    !is.null(data_type) || !is.null(period)
  if (!has_filter && is.null(tables))
    cli::cli_abort(c(
      "Nothing to query.",
      "i" = "Pass catalog filters (e.g. {.arg disease}, {.arg data_type}) and/or {.arg tables}."
    ))

  # Resolve an Azure connection only if we actually touch the blob (keeps df-only offline).
  needs_azure <- has_filter ||
    (!is.null(tables) && any(vapply(
      tables, function(v) is.character(v) && length(v) == 1L && !file.exists(v), logical(1)
    )))
  if (needs_azure && is.null(data_con))
    data_con <- suppressMessages(get_azure_storage_connection(storage_name = "data"))

  con <- DBI::dbConnect(duckdb::duckdb())
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  registered <- character(0)

  if (has_filter) {
    cat_rows <- eri_catalog_query(
      country = country, disease = disease, data_source = data_source,
      data_type = data_type, layer = "processed", period = period, data_con = data_con
    )
    if (nrow(cat_rows) == 0L)
      cli::cli_abort(c(
        "No processed datasets in the catalog match those filters.",
        "i" = "Check {.fn eri_catalog_query} with the same filters."
      ))
    prov <- c("country", "disease", "data_source", "data_type", "period")
    frames <- lapply(seq_len(nrow(cat_rows)), function(i) {
      df <- .eri_query_read_one(cat_rows$path[i], data_con)
      for (col in prov) df[[col]] <- cat_rows[[col]][i]   # stamp provenance for roll-ups
      df
    })
    duckdb::duckdb_register(con, table, dplyr::bind_rows(frames))
    registered <- c(registered, table)
  }

  if (!is.null(tables)) {
    if (is.null(names(tables)) || any(!nzchar(names(tables))))
      cli::cli_abort("{.arg tables} must be a named list (SQL table name -> data.frame or path).")
    for (nm in names(tables)) {
      duckdb::duckdb_register(con, nm, .eri_query_read_one(tables[[nm]], data_con))
      registered <- c(registered, nm)
    }
  }

  cli::cli_inform(c("i" = "Querying {length(registered)} table{?s}: {.val {registered}}."))
  out <- tibble::as_tibble(DBI::dbGetQuery(con, sql))
  cli::cli_alert_success("Returned {nrow(out)} row{?s}.")
  out
}
