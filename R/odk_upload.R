#### eri_odk_upload — bulk-create ODK submissions from a tabular extract ####
#
# The inverse of download_odk_form()/eri_odk_sync(): take a table of already-collected
# records and POST each row as a submission to an existing *published* ODK Central form.
# See ADR-0013 for the contract (deterministic instanceID idempotency; columns map by
# field name; repeats reuse the ADR-0010 relational shape; attachments out of scope).

# --- XML helpers --------------------------------------------------------------

# Find-or-create a nested chain of child elements under `node` and set the leaf text.
# `parts` is the element chain relative to `node` (e.g. c("visit", "visit_date")).
#' @keywords internal
.odk_set_leaf <- function(node, parts, value) {
  for (nm in parts) {
    child <- xml2::xml_find_first(node, paste0("./", nm))
    if (inherits(child, "xml_missing")) child <- xml2::xml_add_child(node, nm)
    node <- child
  }
  xml2::xml_text(node) <- if (is.na(value)) "" else as.character(value)
  invisible(node)
}

# Ensure an (intermediate) group chain exists under `node`, returning the deepest node.
#' @keywords internal
.odk_ensure_group <- function(node, parts) {
  for (nm in parts) {
    child <- xml2::xml_find_first(node, paste0("./", nm))
    if (inherits(child, "xml_missing")) child <- xml2::xml_add_child(node, nm)
    node <- child
  }
  node
}

# --- Form schema (live) -------------------------------------------------------

# GET .../forms/{id}/fields -> tibble(name, path, type). The column->element map.
#' @keywords internal
.odk_form_fields <- function(creds, project_id, form_id) {
  enc <- utils::URLencode(form_id)
  resp <- httr::GET(
    url    = paste0(creds$url, "v1/projects/", project_id, "/forms/", enc, "/fields"),
    config = httr::add_headers(Authorization = paste0("Bearer ", creds$auth))
  )
  x <- .odk_check_response(resp, "fetch form fields")
  if (length(x) == 0L)
    cli::cli_abort("Form {.val {form_id}} returned no fields.")
  dplyr::bind_rows(lapply(x, function(f) tibble::tibble(
    name = f$name %||% NA_character_,
    path = f$path %||% NA_character_,
    type = f$type %||% NA_character_
  )))
}

# GET .../forms/{id}.xml -> the XForm. Extract the primary-instance root (name, id,
# version) and a best-effort path -> allowed-values map for inline select choices.
#' @keywords internal
.odk_form_template <- function(creds, project_id, form_id) {
  enc <- utils::URLencode(form_id)
  resp <- httr::GET(
    url    = paste0(creds$url, "v1/projects/", project_id, "/forms/", enc, ".xml"),
    config = httr::add_headers(Authorization = paste0("Bearer ", creds$auth))
  )
  if (httr::http_error(resp))
    cli::cli_abort("fetch form XML failed with HTTP {httr::status_code(resp)}.")
  doc  <- xml2::read_xml(httr::content(resp, as = "text", encoding = "UTF-8"))

  # Primary instance = first <instance> child of <model> (namespace-agnostic xpath).
  inst_root <- xml2::xml_find_first(
    doc, ".//*[local-name()='model']/*[local-name()='instance'][1]/*"
  )
  if (inherits(inst_root, "xml_missing"))
    cli::cli_abort("Could not locate the primary instance in form {.val {form_id}}'s XML.")

  root_name <- xml2::xml_name(inst_root)
  choices   <- .odk_extract_choices(doc)
  # Form-XML refs include the root (`/data/...`); normalize to match the `/fields` paths.
  if (length(choices)) names(choices) <- .odk_norm_path(names(choices), root_name)

  list(
    root_name = root_name,
    id        = xml2::xml_attr(inst_root, "id"),
    version   = xml2::xml_attr(inst_root, "version"),
    choices   = choices
  )
}

# Best-effort: map each select field's path -> its inline option values. Itemsets that
# pull from a secondary instance (external/dataset choices) are skipped (returned absent),
# so validation degrades gracefully for those fields (ADR-0013).
#' @keywords internal
.odk_extract_choices <- function(doc) {
  selects <- xml2::xml_find_all(
    doc, ".//*[local-name()='select1' or local-name()='select']"
  )
  out <- list()
  for (s in selects) {
    ref <- xml2::xml_attr(s, "ref")
    if (is.na(ref)) ref <- xml2::xml_attr(s, "nodeset")
    if (is.na(ref)) next
    items <- xml2::xml_find_all(s, "./*[local-name()='item']/*[local-name()='value']")
    if (length(items) == 0L) next                      # itemset-driven -> skip (external)
    out[[ref]] <- xml2::xml_text(items)
  }
  out
}

# --- Input normalization ------------------------------------------------------

# Resolve `data` to list(parent = <tbl>, children = named list of <tbl> keyed by the
# repeat's relative path). Accepts a file path, a data.frame, or a named list
# (parent first, then "{form_id}-{repeat}" child tables -- the download_odk_form(tables=)
# shape).
#' @keywords internal
.odk_normalize_input <- function(data, form_id) {
  if (is.character(data) && length(data) == 1L) {
    if (!file.exists(data)) cli::cli_abort("File not found: {.path {data}}")
    ext <- tolower(tools::file_ext(data))
    tbl <- if (ext %in% c("xlsx", "xls")) readxl::read_excel(data)
           else readr::read_csv(data, show_col_types = FALSE)
    return(list(parent = tbl, children = list()))
  }
  if (is.data.frame(data)) return(list(parent = data, children = list()))
  if (is.list(data)) {
    if (length(data) == 0L) cli::cli_abort("{.arg data} is an empty list.")
    nms <- names(data)
    if (is.null(nms) || any(!nzchar(nms)))
      cli::cli_abort("A list {.arg data} must be named (parent first, then {.code {{form_id}}-{{repeat}}} tables).")
    parent   <- data[[1L]]
    children <- data[-1L]
    rel <- vapply(names(children), function(n) {
      if (!startsWith(n, paste0(form_id, "-")))
        cli::cli_abort("Child table {.val {n}} must be named {.code {form_id}-<repeat>}.")
      sub(paste0("^", form_id, "-"), "", n)
    }, character(1L))
    names(children) <- rel
    return(list(parent = parent, children = children))
  }
  cli::cli_abort("{.arg data} must be a file path, a data.frame, or a named list of tables.")
}

# Rename columns per a `mapping` (input header -> canonical field-column name), applied to
# the parent and every child table. A rename only fires where the source column is present,
# so the same mapping can be handed every table harmlessly. Returns the renamed input list.
#' @keywords internal
.odk_apply_mapping <- function(input, mapping) {
  if (is.null(mapping) || length(mapping) == 0L) return(input)
  mapping <- unlist(mapping)
  if (is.null(names(mapping)) || any(!nzchar(names(mapping))))
    cli::cli_abort("{.arg mapping} must be named: {.code c(input_header = \"field-column\")}.")

  rename_one <- function(tbl) {
    hit <- intersect(names(mapping), names(tbl))
    if (length(hit)) {
      targets <- unname(mapping[hit])
      collide <- intersect(targets, setdiff(names(tbl), hit))
      if (length(collide))
        cli::cli_warn(c(
          "{.arg mapping} target{?s} {.val {collide}} already exist in the table; the mapped column will duplicate the name.",
          "i" = "Rename or drop the existing column before mapping onto it."
        ))
      names(tbl)[match(hit, names(tbl))] <- targets
    }
    tbl
  }
  used <- intersect(names(mapping), c(names(input$parent), unlist(lapply(input$children, names))))
  if (length(setdiff(names(mapping), used)))
    cli::cli_warn(c(
      "{.arg mapping} source column{?s} {.val {setdiff(names(mapping), used)}} not found in any table.",
      "i" = "Map from the column names as they appear in {.arg data}."
    ))

  input$parent   <- rename_one(input$parent)
  input$children <- lapply(input$children, rename_one)
  input
}

# --- Deterministic instanceID -------------------------------------------------

# uuid:<hash> derived from the key column(s), or the whole row when none given, so a
# re-run re-derives the same id and ODK 409s the duplicate (ADR-0013).
#' @keywords internal
.odk_deterministic_id <- function(row, key_col = NULL) {
  basis <- if (!is.null(key_col)) row[key_col] else row
  paste0("uuid:", rlang::hash(basis))
}

# --- Per-row XML build --------------------------------------------------------

# Build one submission instance (as an XML string) from a parent row + its repeat child
# rows. `colmap`/`child_colmaps` give column -> relative element-path-parts.
#' @keywords internal
.odk_build_instance <- function(tmpl, parent_row, colmap, child_rows, child_colmaps, instance_id) {
  doc  <- xml2::xml_new_root(tmpl$root_name)
  root <- xml2::xml_root(doc)
  if (!is.na(tmpl$id))      xml2::xml_set_attr(root, "id", tmpl$id)
  if (!is.na(tmpl$version)) xml2::xml_set_attr(root, "version", tmpl$version)

  # Non-repeat leaves from the parent row.
  for (col in names(colmap)) {
    if (!col %in% names(parent_row)) next
    .odk_set_leaf(root, colmap[[col]], parent_row[[col]])
  }

  # Repeat groups: one container element per child row, leaves set within it.
  for (rep_rel in names(child_rows)) {
    rows  <- child_rows[[rep_rel]]
    cmap  <- child_colmaps[[rep_rel]]
    parts <- strsplit(rep_rel, "/", fixed = TRUE)[[1L]]
    parent_parts <- parts[-length(parts)]
    leaf_name    <- parts[length(parts)]
    container_parent <- if (length(parent_parts)) .odk_ensure_group(root, parent_parts) else root
    for (i in seq_len(nrow(rows))) {
      rep_node <- xml2::xml_add_child(container_parent, leaf_name)
      for (col in names(cmap)) {
        if (!col %in% names(rows)) next
        .odk_set_leaf(rep_node, cmap[[col]], rows[[col]][[i]])
      }
    }
  }

  .odk_set_leaf(root, c("meta", "instanceID"), instance_id)
  as.character(doc)
}

# --- Validation ---------------------------------------------------------------

# Normalize an ODK node path to a single convention: relative to the instance root, with
# the root element name stripped. ODK Central's `/fields` endpoint returns paths *without*
# the root (e.g. `/site_name`), while form-XML `ref`/`nodeset` attributes include it
# (`/data/site_name`); normalizing both to `/site_name` lets them line up. Idempotent.
#' @keywords internal
.odk_norm_path <- function(path, root_name) {
  sub(paste0("^/", root_name, "/"), "/", path)
}

# Build column -> relative-path map from the fields list (leaf fields only). The expected
# column name is the dash-joined relative path under the root (download convention).
#' @keywords internal
.odk_colmap <- function(fields, root_name, under = NULL) {
  # Exclude container nodes: groups are "structure", repeats are "repeat" -- neither is a
  # leaf that takes a value (repeat *leaves* live under the repeat and are kept).
  leaves <- fields[!fields$type %in% c("structure", "repeat") & !is.na(fields$path), ]
  # Repeat-group node paths (normalized). Leaves beneath these belong to the repeat's own
  # child table, never the parent, so the parent map (under = NULL) drops them.
  repeat_paths <- .odk_norm_path(
    fields$path[fields$type %in% "repeat" & !is.na(fields$path)], root_name
  )
  prefix <- paste0("/", if (!is.null(under)) paste0(under, "/") else "")
  map <- list()
  for (i in seq_len(nrow(leaves))) {
    p <- .odk_norm_path(leaves$path[i], root_name)
    if (!startsWith(p, prefix)) next
    if (is.null(under) && length(repeat_paths) &&
        any(startsWith(p, paste0(repeat_paths, "/")))) next   # repeat descendant -> child only
    rel <- substr(p, nchar(prefix) + 1L, nchar(p))
    if (!nzchar(rel)) next
    col <- gsub("/", "-", rel)
    map[[col]] <- strsplit(rel, "/", fixed = TRUE)[[1L]]
  }
  map
}

# Reconcile columns against the schema + best-effort type/choice checks. Returns a tibble
# of issues (zero rows = clean). `meta`, `KEY`, `PARENT_KEY` columns are ignored.
#' @keywords internal
.odk_validate_upload <- function(parent, children, fields, tmpl, colmap, child_colmaps,
                                 key_col = NULL) {
  issues <- list()
  add <- function(table, column, row, issue)
    issues[[length(issues) + 1L]] <<- tibble::tibble(
      table = table, column = column, row = row, issue = issue
    )

  # ODK Central system columns from a download export, plus the caller's key column(s):
  # a key column is used only to seed the instanceID and need not be a form field.
  ignorable <- c("KEY", "PARENT_KEY", "meta-instanceID", "instanceID", "SubmissionDate",
                 "SubmitterID", "SubmitterName", "AttachmentsPresent", "AttachmentsExpected",
                 "Status", "ReviewState", "DeviceID", "Edits", "FormVersion", key_col)

  # Unknown parent columns.
  for (col in setdiff(names(parent), c(names(colmap), ignorable)))
    add("parent", col, NA_integer_, "column does not match any form field")

  # Missing required fields are reported by ODK at POST; here we surface unmapped columns
  # and best-effort type/choice problems on mapped ones. Keys are normalized (root stripped)
  # so the field-type and choice lookups line up regardless of ODK's path convention.
  type_of <- stats::setNames(fields$type, .odk_norm_path(fields$path, tmpl$root_name))
  choices <- tmpl$choices

  check_cell <- function(tbl_name, col, parts, value, rowi, under = NULL) {
    if (is.na(value) || !nzchar(as.character(value))) return(invisible())
    path <- paste0("/", if (!is.null(under)) paste0(under, "/") else "",
                   paste(parts, collapse = "/"))
    ty <- type_of[[path]]
    if (!is.null(ty)) {
      if (ty %in% c("int") && is.na(suppressWarnings(as.integer(value))))
        add(tbl_name, col, rowi, "not coercible to an integer")
      else if (ty %in% c("decimal") && is.na(suppressWarnings(as.numeric(value))))
        add(tbl_name, col, rowi, "not coercible to a number")
      else if (ty %in% c("date") &&
               is.na(tryCatch(as.Date(as.character(value), format = "%Y-%m-%d"),
                              error = function(e) NA)))
        add(tbl_name, col, rowi, "not a parseable date (expected YYYY-MM-DD)")
      else if (ty %in% c("geopoint") &&
               !grepl("^-?[0-9.]+ -?[0-9.]+( -?[0-9.]+){0,2}$", trimws(as.character(value))))
        add(tbl_name, col, rowi, "not a 'lat lon [alt] [acc]' geopoint")
    }
    allowed <- choices[[path]]
    if (!is.null(allowed)) {
      vals <- strsplit(trimws(as.character(value)), "\\s+")[[1L]]   # select_multiple = space-sep
      bad  <- setdiff(vals, allowed)
      if (length(bad))
        add(tbl_name, col, rowi, paste0("value(s) not in the choice list: ", paste(bad, collapse = ", ")))
    }
    invisible()
  }

  for (col in intersect(names(parent), names(colmap)))
    for (r in seq_len(nrow(parent)))
      check_cell("parent", col, colmap[[col]], parent[[col]][[r]], r)

  for (rep_rel in names(children)) {
    ch   <- children[[rep_rel]]
    cmap <- child_colmaps[[rep_rel]]
    for (col in setdiff(names(ch), c(names(cmap), ignorable)))
      add(paste0("repeat:", rep_rel), col, NA_integer_, "column does not match any field in the repeat")
    for (col in intersect(names(ch), names(cmap)))
      for (r in seq_len(nrow(ch)))
        check_cell(paste0("repeat:", rep_rel), col, cmap[[col]], ch[[col]][[r]], r, under = rep_rel)
  }

  if (length(issues)) dplyr::bind_rows(issues)
  else tibble::tibble(table = character(), column = character(),
                      row = integer(), issue = character())
}

# --- POST one submission ------------------------------------------------------

# Returns list(status, http). Never aborts: 409 (already present) -> "skipped".
#' @keywords internal
.odk_post_submission <- function(creds, project_id, form_id, xml) {
  enc  <- utils::URLencode(form_id)
  resp <- httr::POST(
    url    = paste0(creds$url, "v1/projects/", project_id, "/forms/", enc, "/submissions"),
    config = httr::add_headers(Authorization = paste0("Bearer ", creds$auth)),
    body   = xml,
    httr::content_type("application/xml")
  )
  code <- httr::status_code(resp)
  if (code %in% c(200L, 201L)) list(status = "created", http = code, message = NA_character_)
  else if (code == 409L)      list(status = "skipped", http = code, message = "instanceID already exists")
  else {
    msg <- tryCatch(httr::content(resp, as = "text", encoding = "UTF-8"), error = function(e) "")
    list(status = "failed", http = code, message = substr(msg, 1, 300))
  }
}

# --- Exported entry point -----------------------------------------------------

#' Bulk-create ODK Central submissions from a tabular extract
#'
#' The inverse of [eri_odk_sync()] / [download_odk_form()]: take a table of
#' already-collected records (a paper backfill, a legacy export, or a
#' [download_odk_form()] result) and create them as **submissions** on an
#' existing **published** ODK Central form. One submission is POSTed per row.
#' See ADR-0013 for the design contract.
#'
#' Columns are matched to form fields **by name**, using the same flattening
#' [download_odk_form()] emits: a field at `/data/visit/date` is the column
#' `visit-date`; repeat groups are supplied as separate child tables named
#' `"{form_id}-{repeat}"` and linked to the parent by a `PARENT_KEY` column
#' whose value matches the parent row's `KEY` (ADR-0010). A
#' `download_odk_form(tables = TRUE)` result is therefore a valid `data`
#' argument -- the download/upload round-trips.
#'
#' Each submission's `meta/instanceID` is derived **deterministically** from
#' `key_col` (or the whole row when `key_col` is `NULL`), so re-running the same
#' extract re-derives the same ids and ODK Central rejects the duplicates with
#' HTTP 409 (reported as `skipped`) instead of double-loading.
#'
#' @param data A file path (CSV/Excel, flat forms only), a data.frame, or a
#'   **named list** of tables (parent first, then `"{form_id}-{repeat}"` child
#'   tables) -- the [download_odk_form()]`(tables = TRUE)` shape.
#' @param project_id `int` ODK Central project ID.
#' @param form_id `chr` ODK Central form ID (xmlFormId); the form must be published.
#' @param con An `odk_connection` from [init_odk_connection()], or `NULL` to use
#'   the `ODK_URL` / `ODK_TOKEN` environment variables.
#' @param url,auth `chr` Server URL / bearer token, used when `con = NULL`.
#' @param key_col `chr` Column name(s) whose values seed the deterministic
#'   `instanceID`. `NULL` (default) hashes the whole parent row. To preserve the
#'   original submission identity on a round-trip, pass the id column (e.g. `"KEY"`).
#'   Names refer to the columns *after* any `mapping` is applied.
#' @param mapping Named character vector mapping **input column headers to
#'   field-column names**, for extracts whose headers don't already match the
#'   form (e.g. a paper CSV): `c(village = "site_name", date_seen = "visit-date")`.
#'   Targets use the same `download_odk_form()` flattening (`group-field`). The
#'   rename is applied to the parent and every child table before validation, so
#'   columns you don't list are left as-is. `NULL` (default) maps nothing.
#' @param dry_run `lgl` If `TRUE`, run validation only and POST nothing; returns
#'   the validation-issue tibble.
#' @param data_con Azure container for optional operation logging; `NULL` skips it.
#' @return Invisibly: when `dry_run = TRUE`, the validation tibble
#'   (`table`, `column`, `row`, `issue`); otherwise a per-row outcome tibble
#'   (`instance_id`, `status` in `created`/`skipped`/`failed`, `http_status`,
#'   `message`).
#' @section Limitations:
#'   Attachments cannot be attached at submission creation (an ODK API
#'   constraint) and are out of scope. Choice-list validation is best-effort:
#'   values for fields backed by external/dataset choices are not checked here
#'   and surface as `failed` rows at POST time if invalid. Submission XML is
#'   built without an instance namespace, matching XLSForm-generated forms.
#' @examples
#' \dontrun{
#' con <- init_odk_connection()
#'
#' # Round-trip: pull, correct locally, push back.
#' tabs <- download_odk_form(con = con, project_id = 7,
#'                           form_id = "RiverProspection", tables = TRUE)
#'
#' # Preview validation without sending anything.
#' eri_odk_upload(tabs, project_id = 7, form_id = "RiverProspection",
#'                con = con, key_col = "KEY", dry_run = TRUE)
#'
#' # Create the submissions (re-runs skip already-present rows via HTTP 409).
#' eri_odk_upload(tabs, project_id = 7, form_id = "RiverProspection",
#'                con = con, key_col = "KEY")
#'
#' # A paper CSV whose headers don't match the form: map them. `key_col` names a
#' # column left unmapped (mapping is applied first), so key on `rec`, not `village`.
#' paper <- read.csv("historical_records.csv")   # cols: village, date_seen, stage, rec
#' eri_odk_upload(paper, project_id = 7, form_id = "RiverProspection", con = con,
#'                mapping = c(village = "site_name", date_seen = "prospection_date",
#'                            stage = "river_stage"),
#'                key_col = "rec", dry_run = TRUE)
#' }
#' @export
eri_odk_upload <- function(
    data,
    project_id,
    form_id,
    con      = NULL,
    url      = Sys.getenv("ODK_URL"),
    auth     = Sys.getenv("ODK_TOKEN"),
    key_col  = NULL,
    mapping  = NULL,
    dry_run  = FALSE,
    data_con = NULL
) {
  creds <- .odk_creds(con, url, auth)

  input    <- .odk_apply_mapping(.odk_normalize_input(data, form_id), mapping)
  parent   <- input$parent
  children <- input$children

  if (!is.data.frame(parent) || nrow(parent) == 0L)
    cli::cli_abort("The parent table is empty -- nothing to upload.")
  if (!is.null(key_col) && !all(key_col %in% names(parent)))
    cli::cli_abort("{.arg key_col} {.val {setdiff(key_col, names(parent))}} not found in the parent table.")

  fields <- .odk_form_fields(creds, project_id, form_id)
  tmpl   <- .odk_form_template(creds, project_id, form_id)

  colmap        <- .odk_colmap(fields, tmpl$root_name)
  child_colmaps <- stats::setNames(
    lapply(names(children), function(rel) .odk_colmap(fields, tmpl$root_name, under = rel)),
    names(children)
  )

  problems <- .odk_validate_upload(parent, children, fields, tmpl, colmap, child_colmaps, key_col)

  if (nrow(problems))
    cli::cli_warn("Validation found {nrow(problems)} issue{?s}; inspect the returned tibble.")
  else
    cli::cli_alert_success("Validation clean: all columns map to form fields.")

  if (isTRUE(dry_run)) {
    cli::cli_inform(c("i" = "{.arg dry_run} is on -- no submissions were sent."))
    return(invisible(problems))
  }

  # Build per-parent child-row groups keyed by PARENT_KEY -> parent KEY.
  has_key <- "KEY" %in% names(parent)
  results <- vector("list", nrow(parent))

  for (i in seq_len(nrow(parent))) {
    prow <- parent[i, , drop = FALSE]
    iid  <- .odk_deterministic_id(prow, key_col)

    child_rows <- list()
    for (rel in names(children)) {
      ch <- children[[rel]]
      if (has_key && "PARENT_KEY" %in% names(ch))
        ch <- ch[ch$PARENT_KEY == parent[["KEY"]][[i]], , drop = FALSE]
      else if (nrow(parent) > 1L)
        cli::cli_abort(c(
          "Repeat table {.val {rel}} needs a {.field PARENT_KEY} column linked to the parent's {.field KEY}.",
          "i" = "Provide both columns (the {.fn download_odk_form} shape) to attach repeats correctly."
        ))
      child_rows[[rel]] <- ch
    }

    xml <- .odk_build_instance(tmpl, prow, colmap, child_rows, child_colmaps, iid)
    out <- .odk_post_submission(creds, project_id, form_id, xml)
    results[[i]] <- tibble::tibble(
      instance_id = iid, status = out$status,
      http_status = out$http, message = out$message
    )
  }

  res <- dplyr::bind_rows(results)
  n_ok   <- sum(res$status == "created")
  n_skip <- sum(res$status == "skipped")
  n_fail <- sum(res$status == "failed")

  if (n_fail)
    cli::cli_alert_warning(
      "Uploaded to {.val {form_id}}: {n_ok} created, {n_skip} already present, {n_fail} failed."
    )
  else
    cli::cli_alert_success(
      "Uploaded to {.val {form_id}}: {n_ok} created, {n_skip} already present."
    )

  if (!is.null(data_con)) {
    .eri_write_log(
      list(
        operation   = "eri_odk_upload",
        form_id     = form_id,
        project_id  = as.integer(project_id),
        n_created   = n_ok,
        n_skipped   = n_skip,
        n_failed    = n_fail,
        analyst     = .eri_analyst_id(),
        timestamp   = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
      ),
      data_con,
      "logs/_access"
    )
  }

  invisible(res)
}
