# Test helper: in-memory optimistic-concurrency YAML store (ADR-0002).
#
# The metadata writers (catalog / ODK registry / artifact registry) persist
# through `.eri_yaml_update()`, which reads with an ETag and writes conditionally
# via `.eri_yaml_read_versioned()` / `.eri_yaml_write_conditional()`. These
# helpers mock that seam against a plain in-memory list so unit tests can assert
# on the resulting store without touching Azure.

# Create a store backed by `initial` (a list like `list(entries = list())`).
new_yaml_store <- function(initial = list()) {
  st <- new.env(parent = emptyenv())
  st$data         <- initial
  st$etag         <- if (length(initial)) "etag-0" else NULL
  st$writes       <- 0L
  st$conflict_once <- FALSE   # set TRUE to force one losing race
  st
}

# Mock `.eri_yaml_read_versioned` / `.eri_yaml_write_conditional` to read and
# write `store`. Honours `store$conflict_once`: the first conditional write with
# a stale etag fails (returns FALSE) after a *concurrent* writer mutates the
# store, exercising the re-read/re-apply retry path.
local_yaml_store <- function(store, concurrent = NULL, env = parent.frame()) {
  testthat::local_mocked_bindings(
    .eri_yaml_read_versioned = function(con, path, default = list()) {
      d <- if (is.null(store$data) || length(store$data) == 0L) default else store$data
      list(data = d, etag = store$etag)
    },
    .eri_yaml_write_conditional = function(con, path, data, etag) {
      if (isTRUE(store$conflict_once) && identical(etag, store$etag)) {
        store$conflict_once <- FALSE
        if (!is.null(concurrent)) store$data <- concurrent(store$data)
        store$etag <- paste0("etag-", (store$writes <- store$writes + 1L))
        return(FALSE)
      }
      store$data  <- data
      store$writes <- store$writes + 1L
      store$etag  <- paste0("etag-", store$writes)
      TRUE
    },
    .package = "erifunctions",
    .env = env
  )
}
