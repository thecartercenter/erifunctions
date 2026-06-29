# Connections & secrets card

*The four services erifunctions talks to, how you sign in, and the one-liner that proves it works. Full
detail: the [connections guide](https://thecartercenter.github.io/erifunctions/articles/connections-guide.html).*

---

## At a glance

| Service | Connect with | Sign-in | Setup | Verify it works |
|---------|--------------|---------|-------|-----------------|
| **Azure** (the data) | `get_azure_storage_connection("data")` | browser (your CC account) | **none** | `eri_list("", azcontainer = data_con)` |
| **ODK Central** | `init_odk_connection()` | email + password | 3 lines in `.Renviron` | `list_odk_projects(con = con)` |
| **SharePoint** | `eri_sharepoint_connect(site_url)` | browser | site URL only | `eri_sharepoint_list(site, path)` |
| **Teams** (optional) | `get_teams_connection()` | token / webhook | a webhook URL | `eri_teams_send(message = "…")` |

Azure and SharePoint are **zero-config** — your browser opens on first use and the sign-in is remembered
for the session. ODK needs three lines. Teams is optional.

---

## Your `.Renviron` (the only place secrets live)

Open with `usethis::edit_r_environ()`, edit, **then restart R**. Never put secrets in a script or commit
them.

```
# Your identity — appears in every approval/access log. SET THIS FIRST.
ERI_ANALYST_ID=firstname.lastname

# ODK Central
ODK_URL=https://your-odk-server.org/
ODK_USER=you@example.org
ODK_PASS=your-password

# Optional — Teams notifications
# ERIFUNCTIONS_TEAMS_WEBHOOK=https://outlook.office.com/webhook/…
```

> **Set `ERI_ANALYST_ID` before your first governed action** (approve, register, sync). Unset, you are
> recorded as `"<os-user> (unverified)"`. A team/CI run can *require* it with `ERI_REQUIRE_ANALYST_ID=true`.

---

## First-day verify sequence

```r
library(erifunctions)
data_con <- get_azure_storage_connection("data")   # browser opens once
eri_list("", azcontainer = data_con)               # a tibble back = you're in

con <- init_odk_connection()                        # ✔ Connected … session expires …
list_odk_projects(con = con)                        # the projects you can see
```

## When it doesn't work

| Symptom | Meaning | Fix |
|---------|---------|-----|
| Azure `403 Forbidden` | Your account lacks access (RBAC) — **not** a code bug | Ask an ERI admin to grant access |
| `ODK username is required` | `ODK_USER` / `ODK_PASS` unset | Add them to `.Renviron`, **restart R** |
| Browser re-opens unexpectedly | Cached session expired | Sign in again — sessions are per-session |
| Teams device-code blocked | Conditional-access policy | Use an incoming webhook instead |
