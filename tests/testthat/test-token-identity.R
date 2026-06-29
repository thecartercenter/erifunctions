#### Tests for token-derived approver identity (ADR-0003) ####

# A minimal stand-in for an AzureStor container: the AzureAuth token lives at
# con$endpoint$token, which .eri_token_identity() decodes.
fake_con <- function(token = "jwt") list(endpoint = list(token = token))

test_that(".eri_token_identity extracts the verified user claim from the token", {
  local_mocked_bindings(
    decode_jwt = function(token, ...) list(payload = list(upn = "jane.doe@cartercenter.org")),
    .package = "AzureAuth"
  )
  expect_equal(erifunctions:::.eri_token_identity(fake_con()), "jane.doe@cartercenter.org")
})

test_that(".eri_token_identity falls through upn -> preferred_username -> email", {
  local_mocked_bindings(
    decode_jwt = function(token, ...) list(payload = list(preferred_username = "j.doe@cc.org")),
    .package = "AzureAuth"
  )
  expect_equal(erifunctions:::.eri_token_identity(fake_con()), "j.doe@cc.org")
})

test_that(".eri_token_identity returns NULL for a service-principal token (no user claim)", {
  local_mocked_bindings(
    decode_jwt = function(token, ...) list(payload = list(appid = "sp-app", oid = "sp-oid")),
    .package = "AzureAuth"
  )
  expect_null(erifunctions:::.eri_token_identity(fake_con()))
})

test_that(".eri_token_identity is robust to a missing token or a non-list container", {
  expect_null(erifunctions:::.eri_token_identity(list(endpoint = list())))  # no token
  expect_null(erifunctions:::.eri_token_identity(list()))                   # no endpoint
  expect_null(erifunctions:::.eri_token_identity("mock"))                   # atomic -> $ errors -> NULL
})

test_that(".eri_analyst_id prefers the verified token identity over a spoofed ERI_ANALYST_ID", {
  withr::local_envvar(ERI_ANALYST_ID = "someone.else")
  local_mocked_bindings(
    decode_jwt = function(token, ...) list(payload = list(upn = "real.user@cc.org")),
    .package = "AzureAuth"
  )
  expect_equal(erifunctions:::.eri_analyst_id(fake_con()), "real.user@cc.org")
})

test_that(".eri_analyst_id falls back to ERI_ANALYST_ID for a service-principal connection", {
  withr::local_envvar(ERI_ANALYST_ID = "ci.runner")
  local_mocked_bindings(
    decode_jwt = function(token, ...) list(payload = list(appid = "sp")),
    .package = "AzureAuth"
  )
  expect_equal(erifunctions:::.eri_analyst_id(fake_con()), "ci.runner")
})

test_that(".eri_analyst_id() with no connection is unchanged (env var)", {
  withr::local_envvar(ERI_ANALYST_ID = "configured.id")
  expect_equal(erifunctions:::.eri_analyst_id(), "configured.id")
})
