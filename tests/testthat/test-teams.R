#### Tests for eri_teams_send input validation ####

test_that("eri_teams_send errors when no delivery method is configured", {
  withr::with_envvar(
    list(ERIFUNCTIONS_TEAMS_TOKEN = "", ERIFUNCTIONS_TEAMS_WEBHOOK = ""),
    {
      expect_error(
        eri_teams_send("hello"),
        "No Teams delivery method"
      )
    }
  )
})

test_that("eri_teams_send errors when message is not a single string", {
  expect_error(eri_teams_send(c("a", "b")), "length")
  expect_error(eri_teams_send(123),         "character")
})

#### Tests for eri_notify_dq input validation ####

test_that("eri_notify_dq errors when result is not a dq_result", {
  expect_error(
    eri_notify_dq(list(), "dr", "malaria"),
    "dq_result"
  )
})

#### Tests for get_teams_connection ####

test_that("get_teams_connection returns token passed directly", {
  tok <- get_teams_connection(token = "mytoken")
  expect_equal(tok, "mytoken")
})

test_that("get_teams_connection returns env var token when set", {
  withr::with_envvar(list(ERIFUNCTIONS_TEAMS_TOKEN = "env-token"), {
    expect_equal(get_teams_connection(), "env-token")
  })
})

test_that("get_teams_connection returns NULL when no auth configured", {
  withr::with_envvar(
    list(ERIFUNCTIONS_TEAMS_TOKEN = "", ERIFUNCTIONS_APP_ID = "",
         ERIFUNCTIONS_TEAMS_WEBHOOK = ""),
    {
      result <- suppressWarnings(suppressMessages(get_teams_connection()))
      expect_null(result)
    }
  )
})
