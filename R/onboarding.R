#### Country / disease onboarding helpers ####

# Valid column types accepted by the DQ pipeline
.VALID_SCHEMA_COL_TYPES <- c("numeric", "character", "categorical", "date")

# ---- disease skeleton templates ----------------------------------------------

.mda_schema_template <- function(country_code, disease) {
  paste0(
    "country: ", country_code, "\n",
    "disease: ", disease, "\n",
    "data_source: programmatic\n",
    "data_type: treatment\n",
    "version: \"1.0\"\n",
    "# time_grain: annual\n",
    "\n",
    "temporal:\n",
    "  year_col: year\n",
    "  period_col: round\n",
    "\n",
    "preprocessing:\n",
    "  - remove_smart_quotes\n",
    "\n",
    "columns:\n",
    "  year:\n",
    "    required: true\n",
    "    type: numeric\n",
    "    aliases: [Year, YEAR, annee]\n",
    "    range: [2000, 2035]\n",
    "\n",
    "  round:\n",
    "    required: true\n",
    "    type: numeric\n",
    "    aliases: [Round, ronda, MDA_round]\n",
    "    range: [1, 10]\n",
    "\n",
    "  # TODO: add geographic unit column (community, district, commune, ...)\n",
    "  # geo_unit:\n",
    "  #   required: true\n",
    "  #   type: character\n",
    "  #   aliases: [community, village, commune]\n",
    "\n",
    "  target_pop:\n",
    "    required: true\n",
    "    type: numeric\n",
    "    aliases: [TargetPop, target_population, pop_cible]\n",
    "\n",
    "  treated:\n",
    "    required: true\n",
    "    type: numeric\n",
    "    aliases: [Treated, people_treated, traites]\n",
    "\n",
    "  coverage_pct:\n",
    "    required: true\n",
    "    type: numeric\n",
    "    aliases: [CoveragePct, coverage, couverture]\n",
    "    range: [0, 150]\n",
    "\n",
    "  # TODO: add drug column if multiple drugs used in same program\n",
    "  # drug:\n",
    "  #   required: false\n",
    "  #   type: categorical\n",
    "  #   allowed_values:\n",
    "  #     - ivermectin\n",
    "  #     - albendazole\n",
    "  #     - praziquantel\n",
    "  #     - mebendazole\n",
    "\n",
    "consistency:\n",
    "  implausible_overcoverage:\n",
    "    lhs: treated\n",
    "    op: \"<=\"\n",
    "    rhs: target_pop\n",
    "    message: \"treated exceeds target_pop (>100% raw coverage)\"\n"
  )
}

.prevalence_schema_template <- function(country_code, disease) {
  paste0(
    "country: ", country_code, "\n",
    "disease: ", disease, "\n",
    "data_source: research\n",
    "data_type: prevalence\n",
    "version: \"1.0\"\n",
    "# time_grain: annual\n",
    "\n",
    "temporal:\n",
    "  year_col: year\n",
    "  period_col: survey_round\n",
    "\n",
    "preprocessing:\n",
    "  - remove_smart_quotes\n",
    "\n",
    "columns:\n",
    "  year:\n",
    "    required: true\n",
    "    type: numeric\n",
    "    aliases: [Year, YEAR]\n",
    "    range: [2000, 2035]\n",
    "\n",
    "  survey_round:\n",
    "    required: true\n",
    "    type: numeric\n",
    "    aliases: [SurveyRound, survey_year, round]\n",
    "    range: [1, 50]\n",
    "\n",
    "  # TODO: add geographic unit column\n",
    "  # geo_unit:\n",
    "  #   required: true\n",
    "  #   type: character\n",
    "\n",
    "  result:\n",
    "    required: true\n",
    "    type: categorical\n",
    "    aliases: [Result, test_result, outcome]\n",
    "    # TODO: add allowed_values for this disease\n",
    "    # allowed_values:\n",
    "    #   - Positive\n",
    "    #   - Negative\n",
    "\n",
    "  survey_type:\n",
    "    required: false\n",
    "    type: categorical\n",
    "    aliases: [SurveyType, method, diagnostic]\n",
    "    # TODO: add allowed_values specific to disease (e.g. Kato-Katz, skin snip)\n",
    "\n",
    "  lat:\n",
    "    required: false\n",
    "    type: numeric\n",
    "    aliases: [latitude, Latitude, GPS_lat]\n",
    "    range: [-90, 90]\n",
    "\n",
    "  lon:\n",
    "    required: false\n",
    "    type: numeric\n",
    "    aliases: [longitude, Longitude, GPS_lon]\n",
    "    range: [-180, 180]\n"
  )
}

# Required top-level keys in a surveillance DQ schema
.REQUIRED_SCHEMA_KEYS <- c("country", "disease", "columns", "temporal")

# Required keys inside the temporal block
.REQUIRED_TEMPORAL_KEYS <- c("year_col", "period_col")

# ---- internal helpers --------------------------------------------------------

.onboarding_create_azure_dirs <- function(country_code, disease, data_con,
                                           data_types = "surveillance") {
  layers <- c("raw", "staged", "processed")
  created <- character(0)

  for (dt in data_types) {
    for (layer in layers) {
      dir_path <- paste(country_code, disease, dt, layer, sep = "/")
      if (!AzureStor::storage_dir_exists(data_con, dir_path)) {
        # ADLS-safe: create the leaf and any missing parents (e.g. country/, disease/, dt/).
        .eri_create_azure_dir(data_con, dir_path)
        created <- c(created, dir_path)
      }
    }
  }
  created
}

.onboarding_resolve_con <- function(data_con) {
  if (!is.null(data_con)) return(data_con)
  suppressMessages(
    get_azure_storage_connection(
      storage_name = Sys.getenv("ERIFUNCTIONS_DATA_STORAGE_NAME", unset = "data")
    )
  )
}

# Build surveillance schema YAML content as a string with guiding comments.
.surveillance_schema_template <- function(country_code, country_name, disease, language,
                                          data_type = "aggregate") {
  paste0(
    "country: ", country_code, "\n",
    "disease: ", disease, "\n",
    "data_source: surveillance\n",
    "data_type: ", data_type, "\n",
    "language: ", language, "\n",
    "# time_grain: weekly   # or: monthly\n",
    "# aggregation: case    # or: count\n",
    "# expected_sheet: Sheet1\n",
    "\n",
    "admin:\n",
    "  # Column names in YOUR data for administrative units:\n",
    "  admin1_col: Admin1\n",
    "  admin2_col: Admin2\n",
    "  # Paths to shapefiles bundled in the package (add to inst/spatial/):\n",
    "  admin1_spatial: spatial/", country_code, "/", country_code, "_admin1.shp\n",
    "  admin2_spatial: spatial/", country_code, "/", country_code, "_admin2.shp\n",
    "  admin1_name_field: adm1_name\n",
    "\n",
    "temporal:\n",
    "  year_col: Year\n",
    "  period_col: EpiWeek    # or Month, etc.\n",
    "  # date_col: SampleDate\n",
    "  max_gap: 2\n",
    "\n",
    "preprocessing:\n",
    "  - remove_smart_quotes\n",
    "  - drop_rows_missing_year\n",
    "\n",
    "columns:\n",
    "  Year:\n",
    "    required: true\n",
    "    type: numeric\n",
    "    aliases: [year, YEAR, Year]\n",
    "    range: [2000, 2035]\n",
    "\n",
    "  EpiWeek:\n",
    "    required: true\n",
    "    type: numeric\n",
    "    aliases: [week, Week, epi_week, EpiWeek]\n",
    "    range: [1, 53]\n",
    "\n",
    "  Admin1:\n",
    "    required: true\n",
    "    type: categorical\n",
    "    aliases: [admin1, province, Province]\n",
    "    # TODO: add allowed_values (list of valid admin1 names)\n",
    "    # allowed_values:\n",
    "    #   - Province Name 1\n",
    "    #   - Province Name 2\n",
    "\n",
    "  Admin2:\n",
    "    required: true\n",
    "    type: character\n",
    "    aliases: [admin2, district, District]\n",
    "\n",
    "  # TODO: add your disease-specific columns here\n",
    "  # CasesConfirmed:\n",
    "  #   required: false\n",
    "  #   type: numeric\n",
    "  #   aliases: [cases_confirmed, confirmed]\n",
    "  #   range: [0, 1000000]\n",
    "\n",
    "consistency:\n",
    "  # TODO: add cross-field rules here\n",
    "  # positives_le_tested:\n",
    "  #   lhs: CasesConfirmed\n",
    "  #   op: \"<=\"\n",
    "  #   rhs: CasesTested\n",
    "  #   message: \"Confirmed cases exceed tested\"\n"
  )
}

# Build CMR schema YAML content as a string with guiding comments.
.cmr_schema_template <- function(country_code, country_name, language) {
  template_name <- if (language == "fr") "french_cmr" else "english_cmr"
  paste0(
    "country: ", country_name, "\n",
    "country_code: ", country_code, "\n",
    "language: ", language, "\n",
    "template: ", template_name, "\n",
    "\n",
    "# List the sheets present in this country's CMR Excel file.\n",
    "# field_code_prefix must match the #tag_ prefix used in row 1 of each sheet.\n",
    "# required_fields lists the #tag_field codes that must be present.\n",
    "sheets:\n",
    "  # TODO: uncomment and complete the sheets relevant to this country's programs:\n",
    "\n",
    "  # RB Treatment:\n",
    "  #   field_code_prefix: \"#rbtrt_\"\n",
    "  #   required_fields:\n",
    "  #     - \"#rbtrt_year\"\n",
    "  #     - \"#rbtrt_month\"\n",
    "  #     - \"#rbtrt_adm1\"\n",
    "  #     - \"#rbtrt_adm2\"\n",
    "  #     - \"#rbtrt_target\"\n",
    "  #     - \"#rbtrt_treated\"\n",
    "\n",
    "  # LF Treatment:\n",
    "  #   field_code_prefix: \"#lftrt_\"\n",
    "  #   required_fields:\n",
    "  #     - \"#lftrt_year\"\n",
    "  #     - \"#lftrt_month\"\n",
    "  #     - \"#lftrt_adm1\"\n",
    "  #     - \"#lftrt_adm2\"\n",
    "  #     - \"#lftrt_target\"\n",
    "  #     - \"#lftrt_treated\"\n",
    "\n",
    "  # SCH Treatment:\n",
    "  #   field_code_prefix: \"#schtrt_\"\n",
    "  #   required_fields:\n",
    "  #     - \"#schtrt_year\"\n",
    "  #     - \"#schtrt_month\"\n",
    "  #     - \"#schtrt_adm1\"\n",
    "  #     - \"#schtrt_adm2\"\n",
    "  #     - \"#schtrt_target\"\n",
    "  #     - \"#schtrt_treated\"\n",
    "\n",
    "  # CDD Training:\n",
    "  #   field_code_prefix: \"#cddtrn_\"\n",
    "  #   required_fields:\n",
    "  #     - \"#cddtrn_year\"\n",
    "  #     - \"#cddtrn_month\"\n",
    "  #     - \"#cddtrn_adm1\"\n",
    "  #     - \"#cddtrn_adm2\"\n",
    "  #     - \"#cddtrn_target\"\n",
    "  #     - \"#cddtrn_trained\"\n"
  )
}

#### eri_onboard_disease ####

#' Scaffold DQ schema YAML files for a new disease program
#'
#' Generates one skeleton YAML file per `data_type` (e.g. `"mda"`,
#' `"prevalence"`) following the standard column layout for each type.
#' TODO comments in the generated files flag fields that must be customised
#' before the schema is ready for team-wide use.
#'
#' @param disease `chr` Short disease code (e.g. `"rb"`, `"schisto"`, `"sth"`).
#' @param country `chr` Country or program code (e.g. `"ug"`, `"global"`).
#' @param data_types `chr` vector Data types to scaffold. Each generates one
#'   file. Supported values: `"mda"`, `"prevalence"`. Default both.
#' @param output_dir `chr` Directory to write skeleton YAML files into.
#'   Default is the current working directory.
#' @param dry_run `lgl` If `TRUE`, print a plan but do not write files.
#'   Default `FALSE`.
#' @returns Invisibly, a character vector of paths written (or `NULL` in
#'   dry-run mode).
#' @examples
#' \dontrun{
#' eri_onboard_disease("schisto", "ug", output_dir = "schemas/")
#' eri_onboard_disease("rb", "ug", data_types = "mda", dry_run = TRUE)
#' }
#' @export
eri_onboard_disease <- function(disease,
                                 country,
                                 data_types  = c("mda", "prevalence"),
                                 output_dir  = getwd(),
                                 dry_run     = FALSE) {
  disease    <- tolower(trimws(disease))
  country    <- tolower(trimws(country))
  data_types <- match.arg(data_types, c("mda", "prevalence"), several.ok = TRUE)

  # ADR-0012 identity: the user-facing kind maps to (data_source, data_type).
  kind_map   <- list(mda        = c("programmatic", "treatment"),
                     prevalence = c("research",     "prevalence"))
  file_names <- vapply(data_types, function(k) {
    m <- kind_map[[k]]
    paste0(country, "_", disease, "_", m[[1L]], "_", m[[2L]], ".yaml")
  }, character(1L))
  file_paths <- file.path(output_dir, file_names)

  if (dry_run) {
    cli::cli_inform(c(
      "i" = "Dry run -- nothing will be written.",
      " " = "Would write:"
    ))
    for (fp in file_paths) cli::cli_inform("    {.path {fp}}")
    return(invisible(NULL))
  }

  written <- character(0)
  for (i in seq_along(data_types)) {
    dt      <- data_types[[i]]
    content <- switch(dt,
      mda        = .mda_schema_template(country, disease),
      prevalence = .prevalence_schema_template(country, disease)
    )
    writeLines(content, file_paths[[i]])
    cli::cli_alert_success("Schema skeleton written to {.path {file_paths[[i]]}}.")
    written <- c(written, file_paths[[i]])
  }

  cli::cli_inform(c(
    "i" = "Next steps:",
    " " = "1. Open each file and fill in the TODO sections.",
    " " = "2. Run {.run eri_schema_validate('<path>')} to check your edits.",
    " " = "3. Submit via pull request to {.path inst/schemas/}."
  ))

  invisible(written)
}

#### eri_onboard_country ####

#' Scaffold a new country/disease surveillance setup
#'
#' Writes a DQ schema YAML template to your local working directory and
#' creates the three-layer Azure blob directories for the new country/disease.
#' Edit the YAML locally, then submit it to the package via a pull request
#' when it is ready for team-wide use.
#'
#' @param country_code `chr` Short country code (e.g. `"uga"`, `"eth"`).
#' @param country_name `chr` Full country name as it appears in data (e.g. `"Uganda"`).
#' @param disease `chr` Disease code (e.g. `"oncho"`, `"malaria"`, `"lf"`).
#' @param language `chr` Language for schema comments (`"en"` or `"fr"`). Default `"en"`.
#' @param path `chr` Directory to write the schema YAML into. Default is the current
#'   working directory.
#' @param data_con Azure container for the `data/` blob. If `NULL`, connects automatically.
#'   Ignored when `dry_run = TRUE`.
#' @param dry_run `lgl` If `TRUE`, print a plan but do not write files or create Azure
#'   directories. Default `FALSE`.
#' @param data_type `chr` The surveillance measure for the schema identity (ADR-0012),
#'   e.g. `"aggregate"` or `"case"`. Default `"aggregate"`. Sets the schema filename
#'   `{country}_{disease}_surveillance_{data_type}.yaml`.
#' @returns Invisibly, the path to the written schema file (or `NULL` in dry-run mode).
#' @examples
#' \dontrun{
#' eri_onboard_country("uga", "Uganda", "oncho")
#' eri_onboard_country("nga", "Nigeria", "lf", language = "en", dry_run = TRUE)
#' }
#' @export
eri_onboard_country <- function(
    country_code,
    country_name,
    disease,
    language  = "en",
    path      = getwd(),
    data_con  = NULL,
    dry_run   = FALSE,
    data_type = "aggregate"
) {
  country_code <- tolower(trimws(country_code))
  disease      <- tolower(trimws(disease))
  language     <- tolower(trimws(language))

  if (!language %in% c("en", "fr"))
    cli::cli_abort("{.arg language} must be {.val en} or {.val fr}, not {.val {language}}.")

  schema_filename <- paste0(country_code, "_", disease, "_surveillance_", data_type, ".yaml")
  schema_path     <- file.path(path, schema_filename)

  azure_dirs <- c(
    paste(country_code, disease, "surveillance", "raw",       sep = "/"),
    paste(country_code, disease, "surveillance", "staged",    sep = "/"),
    paste(country_code, disease, "surveillance", "processed", sep = "/")
  )

  if (dry_run) {
    cli::cli_inform(c(
      "i" = "Dry run -- nothing will be written or created.",
      " " = "Would write: {.path {schema_path}}",
      " " = "Would create Azure directories:"
    ))
    for (d in azure_dirs) cli::cli_inform("    {.path {d}}")
    return(invisible(NULL))
  }

  yaml_content <- .surveillance_schema_template(country_code, country_name, disease, language, data_type)
  writeLines(yaml_content, schema_path)
  cli::cli_alert_success("Schema template written to {.path {schema_path}}.")

  data_con <- .onboarding_resolve_con(data_con)
  created  <- tryCatch(
    .onboarding_create_azure_dirs(country_code, disease, data_con),
    error = function(e) {
      cli::cli_warn("Could not create Azure directories: {conditionMessage(e)}")
      character(0)
    }
  )

  if (length(created) > 0L) {
    cli::cli_alert_success("Created {length(created)} Azure director{?y/ies}.")
  }

  cli::cli_inform(c(
    "i" = "Next steps:",
    " " = "1. Open {.path {schema_path}} and fill in the TODO sections.",
    " " = "2. Run {.run eri_schema_validate('{schema_path}')} to check your edits.",
    " " = "3. Submit the schema via a pull request to add it to the package:",
    " " = "   {.path inst/schemas/{country_code}_{disease}_surveillance_{data_type}.yaml}",
    " " = "4. Register any ODK forms with {.run eri_odk_register()}.",
    " " = "5. Pin the package version in your project: {.run renv::snapshot()}."
  ))

  invisible(schema_path)
}

#### eri_onboard_cmr ####

#' Scaffold a new country CMR schema
#'
#' Writes a CMR schema YAML template to your local working directory and
#' optionally creates CMR Azure blob directories for the country. Edit the YAML
#' locally, then submit it to the package via a pull request when ready.
#'
#' @param country_code `chr` Short country code (e.g. `"uga"`).
#' @param country_name `chr` Full country name (e.g. `"Uganda"`).
#' @param language `chr` CMR template language (`"en"` or `"fr"`). Default `"en"`.
#' @param create_dirs `lgl` If `TRUE`, create the canonical CMR Azure directories
#'   `{country_code}/rblf/cmr/{raw,staged,processed}/` in the `data/` blob -- the
#'   location [eri_stage_cmr()] and [eri_approve()] use. CMR for the RB-expansion
#'   programmes is filed under the combined `rblf` code (RB + LF), not per disease.
#'   Default `FALSE`.
#' @param path `chr` Directory to write the schema YAML into. Default is the current
#'   working directory.
#' @param data_con Azure container for the `data/` blob. If `NULL`, connects automatically.
#'   Ignored when `dry_run = TRUE` or `create_dirs = FALSE`.
#' @param dry_run `lgl` If `TRUE`, print a plan but do not write files or create Azure
#'   directories. Default `FALSE`.
#' @returns Invisibly, the path to the written schema file (or `NULL` in dry-run mode).
#' @examples
#' \dontrun{
#' eri_onboard_cmr("uga", "Uganda", create_dirs = TRUE)
#' eri_onboard_cmr("tcd", "Chad", language = "fr", dry_run = TRUE)
#' }
#' @export
eri_onboard_cmr <- function(
    country_code,
    country_name,
    language    = "en",
    create_dirs = FALSE,
    path        = getwd(),
    data_con    = NULL,
    dry_run     = FALSE
) {
  country_code <- tolower(trimws(country_code))
  language     <- tolower(trimws(language))

  if (!language %in% c("en", "fr"))
    cli::cli_abort("{.arg language} must be {.val en} or {.val fr}, not {.val {language}}.")

  schema_filename <- paste0(country_code, "_cmr_schema.yaml")
  schema_path     <- file.path(path, schema_filename)
  cmr_dir         <- paste(country_code, "rblf", "cmr", sep = "/")

  if (dry_run) {
    cli::cli_inform(c(
      "i" = "Dry run -- nothing will be written or created.",
      " " = "Would write: {.path {schema_path}}"
    ))
    if (isTRUE(create_dirs)) {
      for (layer in c("raw", "staged", "processed")) {
        cli::cli_inform("    Would create: {.path {cmr_dir}/{layer}/}")
      }
    }
    return(invisible(NULL))
  }

  yaml_content <- .cmr_schema_template(country_code, country_name, language)
  writeLines(yaml_content, schema_path)
  cli::cli_alert_success("CMR schema template written to {.path {schema_path}}.")

  if (isTRUE(create_dirs)) {
    data_con <- .onboarding_resolve_con(data_con)
    created  <- tryCatch(
      .onboarding_create_azure_dirs(country_code, "rblf", data_con, data_types = "cmr"),
      error = function(e) {
        cli::cli_warn("Could not create CMR directories: {conditionMessage(e)}")
        character(0)
      }
    )
    if (length(created) > 0L) {
      cli::cli_alert_success("CMR Azure directories created under {.path {cmr_dir}/}.")
    }
  }

  cli::cli_inform(c(
    "i" = "Next steps:",
    " " = "1. Open {.path {schema_path}} and uncomment the sheets your country uses.",
    " " = "2. Match {.field field_code_prefix} to the #tag_ row in your CMR Excel file.",
    " " = "3. Submit via pull request to: {.path inst/schemas/cmr/{country_code}.yaml}",
    " " = "4. Test ingestion with {.run eri_ingest_cmr('your_file.xlsx', country = '{country_code}')}."
  ))

  invisible(schema_path)
}

#### eri_schema_validate ####

#' Validate a local DQ schema YAML file
#'
#' Reads a surveillance schema YAML and checks it for structural problems:
#' missing required sections, invalid column types, and temporal or consistency
#' rules referencing unknown columns. Returns a tidy tibble of issues.
#'
#' @param schema_path `chr` Path to a local YAML schema file.
#' @returns A tibble with columns `issue_type`, `field`, `message`. An empty tibble
#'   (0 rows) means the schema is valid. Prints a summary via cli.
#' @examples
#' \dontrun{
#' # Validate a schema you just generated
#' eri_schema_validate("uga_oncho_surveillance_aggregate.yaml")
#'
#' # Validate a bundled schema
#' eri_schema_validate(system.file("schemas/dr_malaria_surveillance_aggregate.yaml",
#'                                  package = "erifunctions"))
#' }
#' @export
eri_schema_validate <- function(schema_path) {
  if (!file.exists(schema_path))
    cli::cli_abort("Schema file not found: {.path {schema_path}}")

  schema <- tryCatch(
    yaml::read_yaml(schema_path),
    error = function(e) cli::cli_abort("Could not parse YAML: {conditionMessage(e)}")
  )

  issues     <- list()
  col_names  <- names(schema$columns)

  # Required top-level keys
  for (key in .REQUIRED_SCHEMA_KEYS) {
    if (is.null(schema[[key]])) {
      issues <- c(issues, list(list(
        issue_type = "missing_field",
        field      = key,
        message    = paste0("Required top-level key '", key, "' is absent.")
      )))
    }
  }

  # Temporal block checks
  if (!is.null(schema$temporal)) {
    for (key in .REQUIRED_TEMPORAL_KEYS) {
      if (is.null(schema$temporal[[key]])) {
        issues <- c(issues, list(list(
          issue_type = "missing_field",
          field      = paste0("temporal.", key),
          message    = paste0("Required temporal key '", key, "' is absent.")
        )))
      }
    }
    temporal_refs <- c(schema$temporal$year_col, schema$temporal$period_col,
                       schema$temporal$date_col)
    for (ref in temporal_refs[!is.null(temporal_refs)]) {
      if (!ref %in% col_names) {
        issues <- c(issues, list(list(
          issue_type = "unknown_column_reference",
          field      = paste0("temporal -> ", ref),
          message    = paste0("Temporal references column '", ref,
                              "' which is not defined in 'columns'.")
        )))
      }
    }
  }

  # Column definition checks
  if (!is.null(schema$columns)) {
    for (col in col_names) {
      defn <- schema$columns[[col]]
      if (is.null(defn$required)) {
        issues <- c(issues, list(list(
          issue_type = "missing_field",
          field      = paste0("columns.", col, ".required"),
          message    = paste0("Column '", col, "' is missing the 'required' field.")
        )))
      }
      if (is.null(defn$type)) {
        issues <- c(issues, list(list(
          issue_type = "missing_field",
          field      = paste0("columns.", col, ".type"),
          message    = paste0("Column '", col, "' is missing the 'type' field.")
        )))
      } else if (!defn$type %in% .VALID_SCHEMA_COL_TYPES) {
        valid <- .VALID_SCHEMA_COL_TYPES
        issues <- c(issues, list(list(
          issue_type = "invalid_value",
          field      = paste0("columns.", col, ".type"),
          message    = paste0("Column '", col, "' has invalid type '", defn$type,
                              "'. Valid: ", paste(valid, collapse = ", "), ".")
        )))
      }
      if (!is.null(defn$range_when)) {
        when_col <- defn$range_when$column
        if (is.null(when_col) || !when_col %in% col_names) {
          issues <- c(issues, list(list(
            issue_type = "unknown_column_reference",
            field      = paste0("columns.", col, ".range_when.column"),
            message    = paste0("Column '", col, "'s range_when references unknown column '",
                                when_col %||% "(missing)", "'.")
          )))
        }
        when_op <- defn$range_when$op %||% "=="
        if (!when_op %in% c("<=", ">=", "==", "<", ">", "!=")) {
          issues <- c(issues, list(list(
            issue_type = "invalid_value",
            field      = paste0("columns.", col, ".range_when.op"),
            message    = paste0("Column '", col, "'s range_when has invalid op '", when_op,
                                "'. Valid: <=, >=, ==, <, >, !=.")
          )))
        }
      }
    }
  }

  # Consistency rule checks
  if (!is.null(schema$consistency)) {
    for (rule_name in names(schema$consistency)) {
      rule <- schema$consistency[[rule_name]]
      for (side in c("lhs", "rhs")) {
        val <- rule[[side]]
        if (!is.null(val) && !val %in% col_names) {
          issues <- c(issues, list(list(
            issue_type = "unknown_column_reference",
            field      = paste0("consistency.", rule_name, ".", side),
            message    = paste0("Consistency rule '", rule_name, "' references unknown column '",
                                val, "'.")
          )))
        }
      }
    }
  }

  result <- tibble::tibble(
    issue_type = vapply(issues, `[[`, character(1L), "issue_type"),
    field      = vapply(issues, `[[`, character(1L), "field"),
    message    = vapply(issues, `[[`, character(1L), "message")
  )

  if (nrow(result) == 0L) {
    cli::cli_alert_success("Schema {.path {basename(schema_path)}} is valid.")
  } else {
    cli::cli_warn(c(
      "{nrow(result)} issue{?s} found in {.path {basename(schema_path)}}:",
      stats::setNames(result$message, rep("x", nrow(result)))
    ))
  }

  invisible(result)
}
