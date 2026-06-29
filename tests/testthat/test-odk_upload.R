#### Tests for eri_odk_upload — bulk submission backfill ####

# --- fixtures -----------------------------------------------------------------

# A small XLSForm-style form: a flat field, a group, a select, and a repeat group
# (larva_sample) with its own select + integer.
fixture_form_xml <- function() {
  '<h:html xmlns:h="http://www.w3.org/1999/xhtml"
           xmlns="http://www.w3.org/2002/xforms"
           xmlns:jr="http://openrosa.org/javarosa">
    <h:head>
      <h:title>rivertest</h:title>
      <model>
        <instance>
          <data id="rivertest" version="3">
            <site_name/>
            <visit>
              <visit_date/>
              <river_stage/>
            </visit>
            <larva_sample jr:template="">
              <species/>
              <larva_count/>
            </larva_sample>
            <meta><instanceID/></meta>
          </data>
        </instance>
      </model>
    </h:head>
    <h:body>
      <select1 ref="/data/visit/river_stage">
        <item><label>Low</label><value>low</value></item>
        <item><label>Medium</label><value>medium</value></item>
        <item><label>High</label><value>high</value></item>
      </select1>
      <repeat nodeset="/data/larva_sample">
        <select1 ref="/data/larva_sample/species">
          <item><label>Anopheles</label><value>anopheles</value></item>
          <item><label>Culex</label><value>culex</value></item>
        </select1>
        <input ref="/data/larva_sample/larva_count"/>
      </repeat>
    </h:body>
  </h:html>'
}

fixture_fields <- function() {
  tibble::tribble(
    ~name,         ~path,                          ~type,
    "site_name",   "/data/site_name",              "string",
    "visit",       "/data/visit",                  "structure",
    "visit_date",  "/data/visit/visit_date",       "date",
    "river_stage", "/data/visit/river_stage",      "string",
    "larva_sample","/data/larva_sample",           "structure",
    "species",     "/data/larva_sample/species",   "string",
    "larva_count", "/data/larva_sample/larva_count","int",
    "meta",        "/data/meta",                   "structure",
    "instanceID",  "/data/meta/instanceID",        "string"
  )
}

# tmpl as .odk_form_template() would return it (parsed from fixture_form_xml()).
fixture_tmpl <- function() {
  doc <- xml2::read_xml(fixture_form_xml())
  list(
    root_name = "data",
    id        = "rivertest",
    version   = "3",
    choices   = erifunctions:::.odk_extract_choices(doc)
  )
}

# --- .odk_extract_choices -----------------------------------------------------

test_that(".odk_extract_choices reads inline select option values by ref", {
  ch <- erifunctions:::.odk_extract_choices(xml2::read_xml(fixture_form_xml()))
  expect_equal(ch[["/data/visit/river_stage"]], c("low", "medium", "high"))
  expect_equal(ch[["/data/larva_sample/species"]], c("anopheles", "culex"))
})

# --- .odk_deterministic_id ----------------------------------------------------

test_that(".odk_deterministic_id is stable and content-sensitive", {
  row <- tibble::tibble(KEY = "k1", site_name = "S1")
  id1 <- erifunctions:::.odk_deterministic_id(row)
  id2 <- erifunctions:::.odk_deterministic_id(row)
  expect_identical(id1, id2)                       # deterministic
  expect_match(id1, "^uuid:")

  row2 <- tibble::tibble(KEY = "k2", site_name = "S1")
  expect_false(identical(id1, erifunctions:::.odk_deterministic_id(row2)))

  # key_col isolates identity: same key -> same id despite other columns changing
  a <- tibble::tibble(KEY = "k1", site_name = "S1")
  b <- tibble::tibble(KEY = "k1", site_name = "DIFFERENT")
  expect_identical(
    erifunctions:::.odk_deterministic_id(a, "KEY"),
    erifunctions:::.odk_deterministic_id(b, "KEY")
  )
})

# --- .odk_normalize_input -----------------------------------------------------

test_that(".odk_normalize_input handles data.frame, list, and bad inputs", {
  df <- tibble::tibble(site_name = "S1")
  flat <- erifunctions:::.odk_normalize_input(df, "rivertest")
  expect_equal(flat$parent, df)
  expect_length(flat$children, 0L)

  lst <- list(
    rivertest = tibble::tibble(KEY = "a", site_name = "S1"),
    `rivertest-larva_sample` = tibble::tibble(PARENT_KEY = "a", species = "anopheles")
  )
  norm <- erifunctions:::.odk_normalize_input(lst, "rivertest")
  expect_named(norm$children, "larva_sample")     # form-prefix stripped to the repeat rel

  expect_error(
    erifunctions:::.odk_normalize_input(
      list(p = tibble::tibble(x = 1), wrongname = tibble::tibble(y = 2)), "rivertest"
    ),
    "rivertest-"
  )
})

# --- .odk_build_instance ------------------------------------------------------

test_that(".odk_build_instance nests groups, duplicates repeats, and sets instanceID", {
  tmpl   <- fixture_tmpl()
  fields <- fixture_fields()
  colmap <- erifunctions:::.odk_colmap(fields, "data")
  ccmap  <- list(larva_sample = erifunctions:::.odk_colmap(fields, "data", under = "larva_sample"))

  parent <- tibble::tibble(
    site_name = "S1", `visit-visit_date` = "2026-06-01", `visit-river_stage` = "low"
  )
  child  <- tibble::tibble(species = c("anopheles", "culex"), larva_count = c(3L, 1L))

  xml <- erifunctions:::.odk_build_instance(
    tmpl, parent[1, ], colmap,
    child_rows = list(larva_sample = child), child_colmaps = ccmap,
    instance_id = "uuid:abc"
  )
  doc <- xml2::read_xml(xml)

  expect_equal(xml2::xml_attr(xml2::xml_root(doc), "id"), "rivertest")
  expect_equal(xml2::xml_attr(xml2::xml_root(doc), "version"), "3")
  expect_equal(xml2::xml_text(xml2::xml_find_first(doc, "/data/site_name")), "S1")
  expect_equal(xml2::xml_text(xml2::xml_find_first(doc, "/data/visit/visit_date")), "2026-06-01")
  expect_equal(xml2::xml_text(xml2::xml_find_first(doc, "/data/meta/instanceID")), "uuid:abc")

  # two repeat instances, in order
  larvae <- xml2::xml_find_all(doc, "/data/larva_sample")
  expect_length(larvae, 2L)
  expect_equal(xml2::xml_text(xml2::xml_find_first(larvae[[1]], "./species")), "anopheles")
  expect_equal(xml2::xml_text(xml2::xml_find_first(larvae[[2]], "./larva_count")), "1")
})

# --- .odk_validate_upload -----------------------------------------------------

test_that(".odk_validate_upload flags unknown columns, bad types, and choices", {
  tmpl   <- fixture_tmpl()
  fields <- fixture_fields()
  colmap <- erifunctions:::.odk_colmap(fields, "data")
  ccmap  <- list(larva_sample = erifunctions:::.odk_colmap(fields, "data", under = "larva_sample"))

  parent <- tibble::tibble(
    site_name           = "S1",
    `visit-visit_date`  = "not-a-date",
    `visit-river_stage` = "purple",      # not in choice list
    nonsense_col        = "x"            # unknown column
  )
  child <- tibble::tibble(species = "anopheles", larva_count = "three")  # bad int

  prob <- erifunctions:::.odk_validate_upload(
    parent, list(larva_sample = child), fields, tmpl, colmap, ccmap
  )

  expect_true(any(prob$column == "nonsense_col"))
  expect_true(any(grepl("date", prob$issue)))
  expect_true(any(grepl("choice list", prob$issue)))
  expect_true(any(grepl("integer", prob$issue)))
})

test_that(".odk_validate_upload is clean on conforming data and skips external choices", {
  tmpl   <- fixture_tmpl()
  tmpl$choices <- list()                 # simulate external/dataset choices (none extractable)
  fields <- fixture_fields()
  colmap <- erifunctions:::.odk_colmap(fields, "data")

  parent <- tibble::tibble(
    site_name = "S1", `visit-visit_date` = "2026-06-01", `visit-river_stage` = "anything",
    KEY = "a"          # KEY is ignorable, not an unknown column
  )
  prob <- erifunctions:::.odk_validate_upload(parent, list(), fields, tmpl, colmap, list())
  expect_equal(nrow(prob), 0L)
})

test_that(".odk_validate_upload ignores the key column and ODK system columns", {
  tmpl   <- fixture_tmpl()
  fields <- fixture_fields()
  colmap <- erifunctions:::.odk_colmap(fields, "data")

  # record_id is a synthetic key (not a form field); FormVersion is a download system column.
  parent <- tibble::tibble(
    site_name = "S1", `visit-river_stage` = "low",
    record_id = "hist-001", FormVersion = "3"
  )
  prob <- erifunctions:::.odk_validate_upload(
    parent, list(), fields, tmpl, colmap, list(), key_col = "record_id"
  )
  expect_equal(nrow(prob), 0L)
})

# --- eri_odk_upload (orchestration, mocked network) ---------------------------

test_that("eri_odk_upload dry_run validates and POSTs nothing", {
  posted <- 0L
  local_mocked_bindings(
    .odk_form_fields     = function(...) fixture_fields(),
    .odk_form_template   = function(...) fixture_tmpl(),
    .odk_post_submission = function(...) { posted <<- posted + 1L; list(status = "created", http = 201L, message = NA) },
    .package = "erifunctions"
  )

  parent <- tibble::tibble(site_name = "S1", `visit-river_stage` = "low", bad = "x")
  out <- suppressMessages(suppressWarnings(
    eri_odk_upload(parent, project_id = 1L, form_id = "rivertest",
                   url = "https://x/", auth = "tok", dry_run = TRUE)
  ))
  expect_equal(posted, 0L)                          # nothing sent
  expect_true(any(out$column == "bad"))             # validation tibble returned
})

test_that("eri_odk_upload reports per-row outcomes and never aborts the batch", {
  codes <- c(201L, 409L, 400L)
  i <- 0L
  local_mocked_bindings(
    .odk_form_fields     = function(...) fixture_fields(),
    .odk_form_template   = function(...) fixture_tmpl(),
    .odk_post_submission = function(creds, project_id, form_id, xml) {
      i <<- i + 1L
      code <- codes[i]
      if (code %in% c(200L, 201L)) list(status = "created", http = code, message = NA_character_)
      else if (code == 409L)       list(status = "skipped", http = code, message = "dup")
      else                         list(status = "failed",  http = code, message = "bad request")
    },
    .package = "erifunctions"
  )

  parent <- tibble::tibble(
    site_name = c("S1", "S2", "S3"), `visit-river_stage` = c("low", "medium", "high")
  )
  res <- suppressMessages(eri_odk_upload(
    parent, project_id = 1L, form_id = "rivertest", url = "https://x/", auth = "tok"
  ))
  expect_equal(res$status, c("created", "skipped", "failed"))
  expect_equal(res$http_status, c(201L, 409L, 400L))
  expect_true(all(grepl("^uuid:", res$instance_id)))
})

test_that("eri_odk_upload attaches repeat rows to the right parent by PARENT_KEY", {
  captured <- list()
  local_mocked_bindings(
    .odk_form_fields     = function(...) fixture_fields(),
    .odk_form_template   = function(...) fixture_tmpl(),
    .odk_post_submission = function(creds, project_id, form_id, xml) {
      captured[[length(captured) + 1L]] <<- xml
      list(status = "created", http = 201L, message = NA_character_)
    },
    .package = "erifunctions"
  )

  data <- list(
    rivertest = tibble::tibble(KEY = c("a", "b"), site_name = c("S1", "S2")),
    `rivertest-larva_sample` = tibble::tibble(
      PARENT_KEY = c("a", "a", "b"),
      species    = c("anopheles", "culex", "anopheles"),
      larva_count = c(2L, 1L, 5L)
    )
  )
  res <- suppressMessages(eri_odk_upload(
    data, project_id = 1L, form_id = "rivertest", url = "https://x/", auth = "tok", key_col = "KEY"
  ))
  expect_equal(nrow(res), 2L)                                   # one submission per parent

  doc_a <- xml2::read_xml(captured[[1]])
  doc_b <- xml2::read_xml(captured[[2]])
  expect_length(xml2::xml_find_all(doc_a, "/data/larva_sample"), 2L)   # parent a -> 2 repeats
  expect_length(xml2::xml_find_all(doc_b, "/data/larva_sample"), 1L)   # parent b -> 1 repeat
})

test_that("eri_odk_upload errors on empty parent and missing key_col", {
  local_mocked_bindings(
    .odk_form_fields     = function(...) fixture_fields(),
    .odk_form_template   = function(...) fixture_tmpl(),
    .odk_post_submission = function(...) list(status = "created", http = 201L, message = NA),
    .package = "erifunctions"
  )
  expect_error(
    eri_odk_upload(tibble::tibble(site_name = character()), project_id = 1L,
                   form_id = "rivertest", url = "https://x/", auth = "tok"),
    "empty"
  )
  expect_error(
    eri_odk_upload(tibble::tibble(site_name = "S1"), project_id = 1L, form_id = "rivertest",
                   url = "https://x/", auth = "tok", key_col = "NOPE"),
    "key_col"
  )
})
