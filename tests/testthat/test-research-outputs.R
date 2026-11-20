#### Tests for research output management ####

.base_manifest <- function(project_name = "test_proj") {
  list(
    project_name   = project_name,
    country        = "dr",
    disease        = "malaria",
    description    = "test",
    created_at     = "2026-06-04T00:00:00Z",
    created_by     = "test.user",
    azure_path     = paste0("research/", project_name, "/"),
    pulled_data    = list(),
    artifacts_used = list(),
    log            = list(),
    snapshots      = list(),
    outputs        = list()
  )
}

.write_manifest <- function(tmp, project_name = "test_proj") {
  yaml::write_yaml(.base_manifest(project_name), file.path(tmp, "research.yaml"))
}

# --- eri_research_upload_figure -----------------------------------------------

test_that("eri_research_upload_figure errors when file not found", {
  tmp <- withr::local_tempdir()
  .write_manifest(tmp)
  expect_error(
    eri_research_upload_figure("/nonexistent/fig.png", path = tmp),
    "not found"
  )
})

test_that("eri_research_upload_figure errors when research.yaml absent", {
  tmp <- withr::local_tempdir()
  fig <- tempfile(tmpdir = tmp, fileext = ".png")
  writeLines("x", fig)
  expect_error(
    eri_research_upload_figure(fig, path = tmp),
    "research.yaml"
  )
})

test_that("eri_research_upload_figure uploads file and records in research.yaml", {
  tmp <- withr::local_tempdir()
  .write_manifest(tmp)
  fig <- file.path(tmp, "its_model.png")
  writeLines("png_data", fig)

  uploaded_to <- character(0)

  local_mocked_bindings(
    get_azure_storage_connection = function(...) "mock_con",
    .package = "erifunctions"
  )
  local_mocked_bindings(
    storage_dir_exists = function(...) TRUE,
    storage_file_exists = function(...) FALSE,
    create_storage_dir = function(...) invisible(NULL),
    storage_upload     = function(con, src, dest, ...) {
      uploaded_to <<- c(uploaded_to, dest)
      invisible(NULL)
    },
    .package = "AzureStor"
  )

  result <- eri_research_upload_figure(fig, caption = "ITS model", path = tmp)

  expect_match(result, "outputs/figs/its_model.png")
  expect_true(any(grepl("its_model.png", uploaded_to)))

  updated <- yaml::read_yaml(file.path(tmp, "research.yaml"))
  expect_equal(length(updated$outputs), 1L)
  expect_equal(updated$outputs[[1L]]$type,     "figure")
  expect_equal(updated$outputs[[1L]]$filename,  "its_model.png")
  expect_equal(updated$outputs[[1L]]$caption,   "ITS model")
  expect_true(nchar(updated$outputs[[1L]]$uploaded_at) > 0L)
})

test_that("eri_research_upload_figure stores NA caption when none supplied", {
  tmp <- withr::local_tempdir()
  .write_manifest(tmp)
  fig <- file.path(tmp, "fig.png")
  writeLines("x", fig)

  local_mocked_bindings(
    get_azure_storage_connection = function(...) "mock_con",
    .package = "erifunctions"
  )
  local_mocked_bindings(
    storage_dir_exists = function(...) TRUE,
    storage_file_exists = function(...) FALSE,
    create_storage_dir = function(...) invisible(NULL),
    storage_upload     = function(...) invisible(NULL),
    .package = "AzureStor"
  )

  eri_research_upload_figure(fig, path = tmp)
  updated <- yaml::read_yaml(file.path(tmp, "research.yaml"))
  expect_true(is.na(updated$outputs[[1L]]$caption))
})

# --- eri_research_upload_output -----------------------------------------------

test_that("eri_research_upload_output errors when research.yaml absent", {
  tmp <- withr::local_tempdir()
  expect_error(
    eri_research_upload_output(list(a = 1), "model.qs2", path = tmp),
    "research.yaml"
  )
})

test_that("eri_research_upload_output serializes and uploads R object", {
  tmp <- withr::local_tempdir()
  .write_manifest(tmp)

  uploaded_to <- character(0)

  local_mocked_bindings(
    get_azure_storage_connection = function(...) "mock_con",
    .package = "erifunctions"
  )
  local_mocked_bindings(
    storage_dir_exists = function(...) TRUE,
    storage_file_exists = function(...) FALSE,
    create_storage_dir = function(...) invisible(NULL),
    storage_upload     = function(con, src, dest, ...) {
      uploaded_to <<- c(uploaded_to, dest)
      invisible(NULL)
    },
    .package = "AzureStor"
  )

  result <- eri_research_upload_output(list(coef = 1.5), "its_model.qs2", path = tmp)

  expect_match(result, "outputs/its_model.qs2")
  expect_true(any(grepl("its_model.qs2", uploaded_to)))

  updated <- yaml::read_yaml(file.path(tmp, "research.yaml"))
  expect_equal(length(updated$outputs), 1L)
  expect_equal(updated$outputs[[1L]]$type,    "object")
  expect_equal(updated$outputs[[1L]]$filename, "its_model.qs2")
})

test_that("eri_research_upload_output appends to existing outputs", {
  tmp <- withr::local_tempdir()
  manifest <- .base_manifest()
  manifest$outputs <- list(
    list(type = "figure", filename = "fig.png",
         azure_path = "research/test_proj/outputs/figs/fig.png",
         caption = NA, uploaded_at = "t", uploaded_by = "u")
  )
  yaml::write_yaml(manifest, file.path(tmp, "research.yaml"))

  local_mocked_bindings(
    get_azure_storage_connection = function(...) "mock_con",
    .package = "erifunctions"
  )
  local_mocked_bindings(
    storage_dir_exists = function(...) TRUE,
    storage_file_exists = function(...) FALSE,
    create_storage_dir = function(...) invisible(NULL),
    storage_upload     = function(...) invisible(NULL),
    .package = "AzureStor"
  )

  eri_research_upload_output(list(x = 1), "model.qs2", path = tmp)

  updated <- yaml::read_yaml(file.path(tmp, "research.yaml"))
  expect_equal(length(updated$outputs), 2L)
})

# --- eri_research_snapshot ----------------------------------------------------

test_that("eri_research_snapshot errors when research.yaml absent", {
  tmp <- withr::local_tempdir()
  expect_error(eri_research_snapshot(path = tmp), "research.yaml")
})

test_that("eri_research_snapshot errors when data/ directory absent", {
  tmp <- withr::local_tempdir()
  .write_manifest(tmp)
  expect_error(eri_research_snapshot(path = tmp), "data")
})

test_that("eri_research_snapshot warns and returns NULL when data/ is empty", {
  tmp <- withr::local_tempdir()
  .write_manifest(tmp)
  dir.create(file.path(tmp, "data"))

  local_mocked_bindings(
    get_azure_storage_connection = function(...) "mock_con",
    .package = "erifunctions"
  )

  expect_warning(
    result <- eri_research_snapshot(path = tmp),
    "empty"
  )
  expect_null(result)
})

test_that("eri_research_snapshot uploads data/ contents and records in research.yaml", {
  tmp <- withr::local_tempdir()
  .write_manifest(tmp)
  data_dir <- file.path(tmp, "data")
  dir.create(data_dir)
  writeLines("row1,row2", file.path(data_dir, "surveillance.parquet"))
  writeLines("row1,row2", file.path(data_dir, "cmr.parquet"))

  uploaded_to <- character(0)

  local_mocked_bindings(
    get_azure_storage_connection = function(...) "mock_con",
    .package = "erifunctions"
  )
  local_mocked_bindings(
    storage_upload = function(con, src, dest, ...) {
      uploaded_to <<- c(uploaded_to, dest)
      invisible(NULL)
    },
    .package = "AzureStor"
  )

  result <- eri_research_snapshot(label = "pre-ITS-run", path = tmp)

  expect_match(result, "research/test_proj/snapshots/")
  # data files + _manifest.yaml
  expect_true(any(grepl("surveillance.parquet", uploaded_to)))
  expect_true(any(grepl("cmr.parquet", uploaded_to)))
  expect_true(any(grepl("_manifest.yaml", uploaded_to)))

  updated <- yaml::read_yaml(file.path(tmp, "research.yaml"))
  expect_equal(length(updated$snapshots), 1L)
  expect_equal(updated$snapshots[[1L]]$label,      "pre-ITS-run")
  expect_equal(updated$snapshots[[1L]]$file_count,  2L)
  expect_true(nchar(updated$snapshots[[1L]]$azure_path) > 0L)
})

test_that("eri_research_snapshot stores NA label when none supplied", {
  tmp <- withr::local_tempdir()
  .write_manifest(tmp)
  data_dir <- file.path(tmp, "data")
  dir.create(data_dir)
  writeLines("x", file.path(data_dir, "file.csv"))

  local_mocked_bindings(
    get_azure_storage_connection = function(...) "mock_con",
    .package = "erifunctions"
  )
  local_mocked_bindings(
    storage_upload = function(...) invisible(NULL),
    .package = "AzureStor"
  )

  eri_research_snapshot(path = tmp)
  updated <- yaml::read_yaml(file.path(tmp, "research.yaml"))
  expect_true(is.na(updated$snapshots[[1L]]$label))
})

# --- #377: subfolders kept, re-uploads archived, tags freeze outputs ----------

# An in-memory blob store: `store` maps Azure path -> file contents.
.local_fake_blobs <- function(store, env = parent.frame()) {
  local_mocked_bindings(get_azure_storage_connection = function(...) "mock_con",
                        .package = "erifunctions", .env = env)
  local_mocked_bindings(
    storage_dir_exists  = function(...) TRUE,
    create_storage_dir  = function(...) invisible(NULL),
    storage_file_exists = function(con, path) exists(path, envir = store, inherits = FALSE),
    storage_upload      = function(con, src, dest, ...) { assign(dest, readLines(src, warn = FALSE), envir = store); invisible(NULL) },
    storage_download    = function(con, src, dest, ...) { writeLines(get(src, envir = store), dest); invisible(NULL) },
    .package = "AzureStor", .env = env
  )
}

.fig <- function(root, rel, content) {
  f <- file.path(root, rel)
  dir.create(dirname(f), recursive = TRUE, showWarnings = FALSE)
  writeLines(content, f)
  f
}

test_that("figures keep their folder, so same-named figures in different folders do not collide (#377)", {
  tmp <- withr::local_tempdir(); .write_manifest(tmp)
  store <- new.env(); .local_fake_blobs(store)
  a <- suppressMessages(eri_research_upload_figure(.fig(tmp, "figs/deck/forest.png", "english"), path = tmp))
  b <- suppressMessages(eri_research_upload_figure(.fig(tmp, "figs/deck/es/forest.png", "spanish"), path = tmp))
  c <- suppressMessages(eri_research_upload_figure(.fig(tmp, "figs/its.png", "flat"), path = tmp))
  expect_equal(a, "research/test_proj/outputs/figs/deck/forest.png")
  expect_equal(b, "research/test_proj/outputs/figs/deck/es/forest.png")
  expect_equal(c, "research/test_proj/outputs/figs/its.png")   # a flat figs/ figure keeps its old place
  expect_equal(get(a, envir = store), "english")
  expect_equal(get(b, envir = store), "spanish")
})

test_that("a figure given by a path relative to the working directory resolves inside the project (#377)", {
  tmp <- withr::local_tempdir(); .write_manifest(tmp)
  store <- new.env(); .local_fake_blobs(store)
  .fig(tmp, "figs/deck/es/forest.png", "x")
  withr::local_dir(tmp)
  res <- suppressMessages(eri_research_upload_figure("figs/deck/es/forest.png", path = "."))
  expect_equal(res, "research/test_proj/outputs/figs/deck/es/forest.png")
})

test_that("a figure outside the project is uploaded by name, with a warning (#377)", {
  tmp <- withr::local_tempdir(); .write_manifest(tmp)
  other <- withr::local_tempdir()
  store <- new.env(); .local_fake_blobs(store)
  expect_warning(
    res <- suppressMessages(eri_research_upload_figure(.fig(other, "sub/plot.png", "x"), path = tmp)),
    "outside the project folder")
  expect_equal(res, "research/test_proj/outputs/figs/plot.png")
})

test_that("re-uploading a figure archives the previous version and marks the old entry (#377)", {
  tmp <- withr::local_tempdir(); .write_manifest(tmp)
  store <- new.env(); .local_fake_blobs(store)
  f <- .fig(tmp, "figs/forest.png", "v1")
  dest <- suppressMessages(eri_research_upload_figure(f, path = tmp))
  writeLines("v2", f)
  suppressMessages(eri_research_upload_figure(f, path = tmp))

  expect_equal(get(dest, envir = store), "v2")
  archived <- grep("^research/test_proj/outputs/_archive/[0-9]{8}T[0-9]{6}Z/figs/forest[.]png$", ls(store), value = TRUE)
  expect_length(archived, 1L)
  expect_equal(get(archived, envir = store), "v1")

  outs <- yaml::read_yaml(file.path(tmp, "research.yaml"))$outputs
  expect_length(outs, 2L)
  expect_equal(outs[[1L]]$archived_to, archived)
  expect_false(is.null(outs[[1L]]$superseded_at))
  expect_equal(outs[[2L]]$archived_prev, archived)
  expect_null(outs[[2L]]$superseded_at)
})

test_that("re-uploading an R object archives the previous version too (#377)", {
  tmp <- withr::local_tempdir(); .write_manifest(tmp)
  store <- new.env(); .local_fake_blobs(store)
  suppressMessages(eri_research_upload_output(list(v = 1), "model.qs2", path = tmp))
  suppressMessages(eri_research_upload_output(list(v = 2), "model.qs2", path = tmp))
  expect_length(grep("^research/test_proj/outputs/_archive/.*/model[.]qs2$", ls(store)), 1L)
  outs <- yaml::read_yaml(file.path(tmp, "research.yaml"))$outputs
  expect_false(is.null(outs[[1L]]$archived_to))
  expect_false(is.null(outs[[2L]]$archived_prev))
})

test_that("a first upload archives nothing (#377)", {
  tmp <- withr::local_tempdir(); .write_manifest(tmp)
  store <- new.env(); .local_fake_blobs(store)
  suppressMessages(eri_research_upload_figure(.fig(tmp, "figs/a.png", "x"), path = tmp))
  expect_false(any(grepl("_archive", ls(store))))
  expect_null(yaml::read_yaml(file.path(tmp, "research.yaml"))$outputs[[1L]]$archived_prev)
})

test_that("older duplicate entries for one path are all superseded; only the latest gets the archive (#377)", {
  # Manifests written before #377 can list one path twice (the blob was silently overwritten).
  tmp <- withr::local_tempdir()
  m <- .base_manifest()
  p <- "research/test_proj/outputs/figs/forest.png"
  m$outputs <- list(list(type = "figure", filename = "forest.png", azure_path = p, uploaded_at = "2026-07-01T00:00:00Z"),
                    list(type = "figure", filename = "forest.png", azure_path = p, uploaded_at = "2026-07-02T00:00:00Z"))
  yaml::write_yaml(m, file.path(tmp, "research.yaml"))
  store <- new.env(); .local_fake_blobs(store)
  assign(p, "old", envir = store)
  suppressMessages(eri_research_upload_figure(.fig(tmp, "figs/forest.png", "new"), path = tmp))
  outs <- yaml::read_yaml(file.path(tmp, "research.yaml"))$outputs
  expect_false(is.null(outs[[1L]]$superseded_at))
  expect_null(outs[[1L]]$archived_to)        # its blob was overwritten before #377; nothing to point at
  expect_false(is.null(outs[[2L]]$superseded_at))
  expect_false(is.null(outs[[2L]]$archived_to))
})

test_that("freezing outputs for a tag copies only the current version of each path (#377)", {
  m <- .base_manifest()
  p1 <- "research/test_proj/outputs/figs/deck/forest.png"
  p2 <- "research/test_proj/outputs/model.qs2"
  m$outputs <- list(
    list(filename = "forest.png", azure_path = p1, superseded_at = "2026-08-01T00:00:00Z"),
    list(filename = "forest.png", azure_path = p1),
    list(filename = "model.qs2",  azure_path = p2),
    list(filename = "model.qs2",  azure_path = p2)   # pre-#377 duplicate: latest wins
  )
  store <- new.env(); .local_fake_blobs(store)
  assign(p1, "fig", envir = store); assign(p2, "obj", envir = store)
  frozen <- .eri_research_freeze_outputs("mock_con", m, "research/test_proj/tags/v1/")
  expect_length(frozen, 2L)
  expect_equal(vapply(frozen, function(o) o$frozen_path, ""),
               c("research/test_proj/tags/v1/outputs/figs/deck/forest.png",
                 "research/test_proj/tags/v1/outputs/model.qs2"))
  expect_equal(get(frozen[[1L]]$frozen_path, envir = store), "fig")
})

test_that("an output that cannot be copied is recorded without a frozen_path, with a warning (#377)", {
  m <- .base_manifest()
  m$outputs <- list(list(filename = "gone.png", azure_path = "research/test_proj/outputs/figs/gone.png"))
  store <- new.env(); .local_fake_blobs(store)   # the blob does not exist: download errors
  expect_warning(frozen <- .eri_research_freeze_outputs("mock_con", m, "research/test_proj/tags/v1/"),
                 "Could not copy output")
  expect_null(frozen[[1L]]$frozen_path)
})

test_that("re-uploads within the same second get separate archives, so no version is lost (#377 review)", {
  tmp <- withr::local_tempdir(); .write_manifest(tmp)
  store <- new.env(); .local_fake_blobs(store)
  local_mocked_bindings(Sys.time = function() as.POSIXct("2026-11-20 15:06:25", tz = "UTC"), .package = "base")
  f <- .fig(tmp, "figs/deck/es/forest.png", "v1")
  suppressMessages(eri_research_upload_figure(f, path = tmp))
  writeLines("v2", f); suppressMessages(eri_research_upload_figure(f, path = tmp))
  writeLines("v3", f); suppressMessages(eri_research_upload_figure(f, path = tmp))

  a1 <- "research/test_proj/outputs/_archive/20261120T150625Z/figs/deck/es/forest.png"
  a2 <- "research/test_proj/outputs/_archive/20261120T150625Z-2/figs/deck/es/forest.png"
  expect_equal(get(a1, envir = store), "v1")
  expect_equal(get(a2, envir = store), "v2")
  outs <- yaml::read_yaml(file.path(tmp, "research.yaml"))$outputs
  expect_equal(c(outs[[1L]]$archived_to, outs[[2L]]$archived_to), c(a1, a2))
  expect_equal(outs[[3L]]$archived_prev, a2)
})

test_that("a figure kept under outputs/figs/ locally is not nested twice (#377 review)", {
  tmp <- withr::local_tempdir(); .write_manifest(tmp)
  store <- new.env(); .local_fake_blobs(store)
  res <- suppressMessages(eri_research_upload_figure(.fig(tmp, "outputs/figs/o.png", "x"), path = tmp))
  expect_equal(res, "research/test_proj/outputs/figs/o.png")
})

test_that("uploading a subfolder figure notes an earlier flat upload with the same name (#377 review)", {
  tmp <- withr::local_tempdir()
  m <- .base_manifest()
  m$outputs <- list(list(type = "figure", filename = "forest.png",
                         azure_path = "research/test_proj/outputs/figs/forest.png"))
  yaml::write_yaml(m, file.path(tmp, "research.yaml"))
  store <- new.env(); .local_fake_blobs(store)
  msgs <- testthat::capture_messages(
    eri_research_upload_figure(.fig(tmp, "figs/deck/es/forest.png", "x"), path = tmp))
  expect_true(any(grepl("earlier upload named", msgs, fixed = TRUE)))
  outs <- yaml::read_yaml(file.path(tmp, "research.yaml"))$outputs
  expect_null(outs[[1L]]$superseded_at)   # not superseded: it may be a different figure

  # No note when there is no such flat entry.
  tmp2 <- withr::local_tempdir(); .write_manifest(tmp2)
  msgs2 <- testthat::capture_messages(
    eri_research_upload_figure(.fig(tmp2, "figs/deck/es/forest.png", "x"), path = tmp2))
  expect_false(any(grepl("earlier upload named", msgs2, fixed = TRUE)))
})

test_that("eri_research_status counts each output once, not its archived versions (#377 review)", {
  tmp <- withr::local_tempdir(); .write_manifest(tmp)
  store <- new.env(); .local_fake_blobs(store)
  f <- .fig(tmp, "figs/a.png", "v1")
  suppressMessages(eri_research_upload_figure(f, path = tmp))
  writeLines("v2", f); suppressMessages(eri_research_upload_figure(f, path = tmp))
  msgs <- paste(cli::ansi_strip(testthat::capture_messages(eri_research_status(path = tmp))), collapse = "\n")
  expect_match(msgs, "1 output (+1 earlier version)", fixed = TRUE)
})
