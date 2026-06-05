#### Tests for eri_research_tag / .eri_git_info ####

.write_manifest <- function(dir, snapshots = list(), pulled = list(), outputs = list()) {
  manifest <- list(
    project_name   = "dr_irs_2024",
    country        = "dr",
    disease        = "malaria",
    description    = "ITS analysis",
    created_at     = "2026-06-04T00:00:00Z",
    created_by     = "test.user",
    azure_path     = "research/dr_irs_2024/",
    pulled_data    = pulled,
    artifacts_used = list(),
    log            = list(),
    snapshots      = snapshots,
    outputs        = outputs,
    tags           = list()
  )
  yaml::write_yaml(manifest, file.path(dir, "research.yaml"))
}

# git init + commit everything in `dir`, leaving a CLEAN work tree (no reliance on
# the machine's global git identity).
.commit_all <- function(dir) {
  system2("git", c("-C", dir, "init", "-q"))
  system2("git", c("-C", dir, "add", "-A"))
  system2("git", c("-C", dir, "-c", "user.email=t@example.com",
                   "-c", "user.name=Tester", "commit", "-q", "-m", "init"))
}

# Mock Azure; capture each upload's CONTENTS (copied, since the source tempfile is
# unlinked when the function returns) into the reference environment `cap`.
.setup_tag_mocks <- function(cap, file_exists = FALSE) {
  local_mocked_bindings(
    get_azure_storage_connection = function(...) "mock_con",
    .package = "erifunctions", .env = parent.frame()
  )
  local_mocked_bindings(
    storage_file_exists = function(...) file_exists,
    storage_dir_exists  = function(...) FALSE,
    create_storage_dir  = function(...) invisible(NULL),
    storage_upload      = function(container, src, dest, ...) {
      keep <- tempfile(fileext = ".cap")
      file.copy(src, keep)
      assign(dest, keep, envir = cap)
      invisible(NULL)
    },
    .package = "AzureStor", .env = parent.frame()
  )
}

# --- validation ---------------------------------------------------------------

test_that("eri_research_tag rejects an empty or non-scalar label", {
  tmp <- withr::local_tempdir()
  .write_manifest(tmp, snapshots = list(list(label = "s", timestamp = "t",
                                             azure_path = "p", file_count = 1L)))
  expect_error(eri_research_tag("", path = tmp), "non-empty")
  expect_error(eri_research_tag(c("a", "b"), path = tmp), "single non-empty")
})

# --- immutability -------------------------------------------------------------

test_that("eri_research_tag refuses to overwrite an existing tag", {
  tmp <- withr::local_tempdir()
  .write_manifest(tmp, snapshots = list(list(label = "s", timestamp = "t",
                                             azure_path = "p", file_count = 1L)))
  cap <- new.env()
  .setup_tag_mocks(cap, file_exists = TRUE)
  expect_error(eri_research_tag("dup", path = tmp), "already exists")
})

# --- happy path ---------------------------------------------------------------

test_that("eri_research_tag binds latest snapshot + git SHA and records the tag", {
  skip_if(!nzchar(Sys.which("git")), "git not available")
  tmp <- withr::local_tempdir()
  .write_manifest(
    tmp,
    snapshots = list(
      list(label = "old", timestamp = "2026-06-01T00:00:00Z",
           azure_path = "research/dr_irs_2024/snapshots/old/", file_count = 2L),
      list(label = "new", timestamp = "2026-06-05T00:00:00Z",
           azure_path = "research/dr_irs_2024/snapshots/new/", file_count = 3L)
    ),
    pulled  = list(list(source = "processed/dr/malaria", pulled_at = "2026-06-04T00:00:00Z")),
    outputs = list(list(type = "figure", filename = "fig1.png"))
  )
  .commit_all(tmp)  # clean tree, manifest committed

  cap <- new.env()
  .setup_tag_mocks(cap)

  res <- eri_research_tag("submission", description = "Fig 1", path = tmp)

  tag_dest <- "research/dr_irs_2024/tags/submission/_tag.yaml"
  expect_equal(res, tag_dest)
  expect_true(exists(tag_dest, envir = cap, inherits = FALSE))

  tag <- yaml::read_yaml(cap[[tag_dest]])
  expect_equal(tag$label, "submission")
  expect_equal(tag$snapshot$timestamp, "2026-06-05T00:00:00Z")  # latest
  expect_match(tag$code$sha, "^[0-9a-f]{7,40}$")
  expect_false(isTRUE(tag$code$dirty))
  expect_equal(length(tag$inputs), 1L)
  expect_equal(length(tag$outputs), 1L)

  manifest <- yaml::read_yaml(file.path(tmp, "research.yaml"))
  expect_equal(length(manifest$tags), 1L)
  expect_equal(manifest$tags[[1L]]$label, "submission")
})

test_that("eri_research_tag binds a specific snapshot by label", {
  skip_if(!nzchar(Sys.which("git")), "git not available")
  tmp <- withr::local_tempdir()
  .write_manifest(
    tmp,
    snapshots = list(
      list(label = "old", timestamp = "2026-06-01T00:00:00Z",
           azure_path = "p/old/", file_count = 2L),
      list(label = "new", timestamp = "2026-06-05T00:00:00Z",
           azure_path = "p/new/", file_count = 3L)
    )
  )
  .commit_all(tmp)

  cap <- new.env()
  .setup_tag_mocks(cap)

  eri_research_tag("pick-old", snapshot = "old", path = tmp)
  tag <- yaml::read_yaml(cap[["research/dr_irs_2024/tags/pick-old/_tag.yaml"]])
  expect_equal(tag$snapshot$timestamp, "2026-06-01T00:00:00Z")
})

test_that("eri_research_tag auto-creates a snapshot when none exist", {
  skip_if(!nzchar(Sys.which("git")), "git not available")
  tmp <- withr::local_tempdir()
  .write_manifest(tmp, snapshots = list())
  dir.create(file.path(tmp, "data"))
  writeLines("a,b\n1,2", file.path(tmp, "data", "input.csv"))
  .commit_all(tmp)

  cap <- new.env()
  .setup_tag_mocks(cap)

  # Snapshot writes research.yaml mid-call, so the tree is dirty at git-check ->
  # the dirty warning is expected; we only assert the snapshot/tag wiring.
  suppressWarnings(
    expect_message(eri_research_tag("v1", path = tmp), "creating one")
  )

  manifest <- yaml::read_yaml(file.path(tmp, "research.yaml"))
  expect_equal(length(manifest$snapshots), 1L)
  expect_equal(length(manifest$tags), 1L)
  tag <- yaml::read_yaml(cap[["research/dr_irs_2024/tags/v1/_tag.yaml"]])
  expect_equal(tag$snapshot$label, "tag-v1")
})

# --- .eri_git_info ------------------------------------------------------------

test_that(".eri_git_info returns NA fields outside a git work tree", {
  tmp <- withr::local_tempdir()
  info <- .eri_git_info(tmp)
  expect_true(is.na(info$sha))
})

test_that(".eri_git_info reports a clean repo's HEAD", {
  skip_if(!nzchar(Sys.which("git")), "git not available")
  tmp <- withr::local_tempdir()
  writeLines("x <- 1", file.path(tmp, "analysis.R"))
  .commit_all(tmp)
  info <- .eri_git_info(tmp)
  expect_match(info$sha, "^[0-9a-f]{7,40}$")
  expect_false(info$dirty)
})
