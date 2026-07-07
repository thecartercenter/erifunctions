#### Concurrency-safe metadata store (ADR-0002) ####
#
# The catalog, the ODK registry and the artifact registry are each a single YAML
# blob updated by read-modify-write. Two analysts updating the same blob at once
# would both read the old version, and the slower writer would silently clobber
# the faster one's entry. `.eri_yaml_update()` makes those writes optimistic-
# concurrent: it reads the blob *with its ETag*, applies the caller's `mutate`,
# and writes back **conditionally** (`If-Match: <etag>`, or `If-None-Match: *`
# for a first create). If the blob changed underneath us the conditional write
# fails with HTTP 412; we re-read, re-apply `mutate` to the *fresh* data, and
# retry — so neither writer's entry is lost. See ADR-0002.

# The conditional metadata ops below use blob-API semantics — `x-ms-blob-type:
# BlockBlob` with an `If-Match`/`If-None-Match` PUT of the whole body. The ADLS
# Gen2 **dfs** endpoint (the package default) rejects that shape with HTTP 400
# ("An HTTP header that's mandatory for this request is not specified") and writes
# nothing; the same account's **blob** endpoint serves the identical files and
# supports these ops natively (create/conditional-update/412-on-stale). So the
# versioned read *and* the conditional write route through the blob endpoint,
# derived in-place from the passed container (dfs host -> blob host, same token
# and filesystem). A container that is already blob-backed — or any test double
# that isn't a real ADLS filesystem — is returned unchanged. See ADR-0016.
#' @keywords internal
.eri_blob_metadata_con <- function(con) {
  if (!inherits(con, "adls_filesystem")) return(con)
  ep      <- con$endpoint
  blob_ep <- AzureStor::blob_endpoint(
    sub("\\.dfs\\.", ".blob.", ep$url),
    token = ep$token, key = ep$key, sas = ep$sas
  )
  AzureStor::storage_container(blob_ep, con$name)
}

# Read a YAML blob together with its ETag in a single GET.
# Returns list(data = <parsed yaml or `default`>, etag = <chr or NULL>).
# A missing blob yields the default and a NULL etag (signals "create").
#' @keywords internal
.eri_yaml_read_versioned <- function(con, path, default = list()) {
  con  <- .eri_blob_metadata_con(con)
  resp <- AzureStor::do_container_op(
    con, path, http_verb = "GET", http_status_handler = "pass"
  )
  status <- resp$status_code
  if (identical(status, 404L)) {
    return(list(data = default, etag = NULL))
  }
  if (status >= 300L) {
    # Re-issue with the default ("stop") handler so AzureStor raises its own
    # informative error for anything other than a clean read or a 404.
    AzureStor::do_container_op(con, path, http_verb = "GET")
  }

  txt <- rawToChar(resp$content)
  Encoding(txt) <- "UTF-8"
  data <- yaml::yaml.load(txt)
  if (is.null(data)) data <- default

  etag <- resp$headers[["etag"]]
  list(data = data, etag = if (!is.null(etag) && nzchar(etag)) etag else NULL)
}

# Conditionally write a YAML blob. `etag = NULL` means "create only if absent"
# (`If-None-Match: *`); a non-NULL etag means "update only if unchanged"
# (`If-Match: <etag>`). Returns TRUE on success, FALSE on a 412/409 conflict
# (the caller re-reads and retries); any other error is raised.
#' @keywords internal
.eri_yaml_write_conditional <- function(con, path, data, etag) {
  tmp <- tempfile(fileext = ".yaml")
  on.exit(unlink(tmp))
  yaml::write_yaml(data, tmp)
  # Ensure the parent directory on the ADLS container (where the rest of the
  # package reads/writes); the conditional PUT itself goes to the blob endpoint.
  .eri_create_azure_dir(con, dirname(path))
  blob_con <- .eri_blob_metadata_con(con)

  body    <- readBin(tmp, "raw", n = file.info(tmp)$size)
  headers <- list(
    `x-ms-blob-type` = "BlockBlob",
    `content-type`   = "application/x-yaml"
  )
  if (is.null(etag)) {
    headers[["If-None-Match"]] <- "*"
  } else {
    headers[["If-Match"]] <- etag
  }

  resp <- AzureStor::do_container_op(
    blob_con, path, headers = headers, body = body,
    http_verb = "PUT", http_status_handler = "pass"
  )
  status <- resp$status_code
  if (identical(status, 412L) || identical(status, 409L)) return(FALSE)
  if (status >= 300L) {
    # Re-issue with the "stop" handler to surface the real storage error.
    AzureStor::do_container_op(
      blob_con, path, headers = headers, body = body, http_verb = "PUT"
    )
  }
  TRUE
}

# Atomic read-modify-write of a YAML metadata blob (ADR-0002).
# `mutate(list) -> list` is applied to the freshly-read blob on every attempt,
# so a retry after a conflict re-applies the change on top of the other writer's
# committed version. Aborts after `retries` losing races.
#' @keywords internal
.eri_yaml_update <- function(con, path, mutate, default = list(), retries = 5L) {
  for (attempt in seq_len(retries + 1L)) {
    current  <- .eri_yaml_read_versioned(con, path, default = default)
    new_data <- mutate(current$data)
    if (isTRUE(.eri_yaml_write_conditional(con, path, new_data, current$etag))) {
      return(invisible(new_data))
    }
    # Lost the race; brief jittered backoff, then re-read and re-apply.
    Sys.sleep(stats::runif(1L, 0.05, 0.20) * attempt)
  }
  cli::cli_abort(c(
    "Could not update {.path {path}} after {retries} concurrent-write retries.",
    "i" = "Another process is updating it repeatedly; please try again."
  ))
}
