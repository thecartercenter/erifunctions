# Working with ODK Central: connect, monitor, and pull form data (for data analysts)

**ODK Central** is where field data is born — survey teams collect
submissions on phones, and they land on an ODK Central server. This is a
hands-on walkthrough for a **Data Analyst (DA)** of the whole loop:
connect to ODK Central, stand up a form, **monitor** it, **manage** who
collects on it, and **pull** its submissions into the governed Carter
Center data system.

So you can practise safely, you will create a **make-believe form** in a
sandbox **`test` project** on your ODK Central server, submit a few fake
records, and work the loop end-to-end — then the final [**Clean
up**](#clean-up) section removes everything you created.

> **What you need to follow along.** Unlike the other guides, this one
> talks to a live **ODK Central** server, so you need an ODK Central
> account and access to a project you can experiment in. If you do not,
> read along — the steps are the same against any server.

## The golden rule

> **ODK Central is the front door; `erifunctions` brings the data
> through it into one governed pipeline.** You **register** a form (the
> registry is the team’s record of which forms are tracked), **sync**
> its submissions into `{country}/{disease}/research/raw/`, and from
> there it flows through the same `raw → staged → processed` lifecycle —
> with
> [`eri_approve()`](https://thecartercenter.github.io/erifunctions/reference/eri_approve.md)
> as the human gate — as every other dataset.
>
> **Where ODK lands.** Under the [source ≠ measure model
> (ADR-0012)](https://github.com/thecartercenter/erifunctions/blob/main/docs/adr/0012-source-measure-data-model.md),
> ODK is the **`research`** channel’s collection *format*
> (`format: odk`), so
> [`eri_odk_sync()`](https://thecartercenter.github.io/erifunctions/reference/eri_odk_sync.md)
> writes to the `research` source. Its measure (`tas`, `prevalence`, …)
> is **optional** and assigned later, when you clean the form into a
> final dataset — which is why these paths carry no measure level yet.

flowchart TD A\["Field teams collect on phones"\] --\> B\["ODK Central
server"\] B --\> C\["init_odk_connection()"\] C --\> D\["Register the
form (registry)"\] D --\> E\["Monitor + manage collectors"\] E --\>
F\["eri_odk_sync() -\> research/raw/"\] F --\> G\["DQ -\> staged/"\] G
--\> H\["eri_approve() -\> processed/"\] H --\> Z\["Clean up the
sandbox"\]

## Before you start

1.  **R and RStudio** installed.

2.  **The package:**

    ``` r

    install.packages("remotes")
    remotes::install_github("thecartercenter/erifunctions")
    ```

3.  **ODK Central credentials.** Store them once in your `.Renviron` so
    they never end up in your scripts. Open it with
    `usethis::edit_r_environ()`, add three lines, then **save and
    restart R**:

        ODK_URL=https://your-odk-server.org/
        ODK_USER=you@example.org
        ODK_PASS=your-password

    Everything below reads these automatically — you never type your
    password into a script.

4.  **Azure access** is zero-config: the first command that needs it
    opens your browser to sign in (see
    [`?get_azure_storage_connection`](https://thecartercenter.github.io/erifunctions/reference/get_azure_storage_connection.md)).

One comfort setting — leave verbosity at its default `"full"` for this
walkthrough (that is the step-by-step output shown below):

``` r

library(erifunctions)
# eri_verbosity("quiet")   # later, to trim to headlines + warnings only
```

## 1. Begin — create your practice form

> **Heads up — this first step happens in your browser, not in R.**
> Creating the `test` project, uploading the form, and submitting
> practice entries are all done in the ODK Central **web interface**.
> `erifunctions` takes over from *Connect* (below) once there is data on
> the server.

### Put a form on the server

The package ships a tiny practice form — a mock vector-surveillance
“river prospection” survey. Find it on your machine and upload it to a
**`test`** project in ODK Central:

``` r

system.file("extdata", "odk-test-form.xlsx", package = "erifunctions")
#> "…/erifunctions/extdata/odk-test-form.xlsx"
```

In the ODK Central web interface: open (or create) a **`test`** project
▸ **New** ▸ **Form** ▸ upload that `.xlsx` ▸ **Publish**. Then submit
**2–3 fake entries**: on the form page click **Submit** (the Enketo web
form), fill in made-up values, and send. Now there is data to work with.

### Connect

``` r

con <- init_odk_connection()
#> ✔ Connected to <https://your-odk-server.org/>. Session expires 2026-06-26T20:00:45.542Z.
```

[`init_odk_connection()`](https://thecartercenter.github.io/erifunctions/reference/init_odk_connection.md)
reads `ODK_URL` / `ODK_USER` / `ODK_PASS` from your `.Renviron`, signs
in, and returns a session you pass to the other functions as `con =`.

### Find your project and form

You refer to forms by a **project id** (a number) and a **form id** (a
string). Discover them:

``` r

list_odk_projects(con = con)
#> # A tibble: 3 × 3
#>   project_id project   description
#>        <int> <chr>     <chr>
#> 1          5 Uganda    NA
#> 2          7 Training  NA
#> 3         11 testing   NA            # ← your sandbox project (your ids will differ)
```

``` r

list_odk_forms(con = con, project_id = 11)
#> # A tibble: 1 × 2
#>   xmlFormId                  name
#>   <chr>                      <chr>
#> 1 eri_test_river_prospection ERI Test — River Prospection
```

So our sandbox is **project `11`**, form
**`eri_test_river_prospection`**. Keep those handy:

``` r

project_id <- 11
form_id    <- "eri_test_river_prospection"
```

## 2. Manage the form

### Monitor submissions

[`eri_survey_status()`](https://thecartercenter.github.io/erifunctions/reference/eri_survey_status.md)
is your at-a-glance health check — how many submissions, the most recent
one, and recent activity:

``` r

eri_survey_status(project_id = project_id, form_id = form_id, con = con)
#> ── Survey Status (1 form) ──────────────────────────────
#> • eri_test_river_prospection [open] - 3 total, last: 2026-06-25T19:57:33.690Z
```

It prints a one-line summary, but it is really a tibble — store it to
see the full metrics (7- and 30-day counts, open/closed state):

``` r

st <- eri_survey_status(project_id = project_id, form_id = form_id, con = con)
as.data.frame(st)
#>   project_id project_name                    form_id                    form_name           server_url status total_submissions   last_submission_at submissions_7d submissions_30d
#> 1         11      testing eri_test_river_prospection ERI Test — River Prospection https://your-odk… open                 3 2026-06-25T19:57:33.690Z              3               3
```

Called with just `project_id` it reports **every** form in the project;
with neither argument, every form on every project you can see — handy
for a Monday-morning sweep across all your surveys.

### Manage who collects: app users

Field staff collect through **app users** — per-project data-collection
accounts. You can create one and assign it to a form straight from R.
(These calls change your live project; we remove the demo user in [Clean
up](#clean-up).)

``` r

# Create an app user (a data collector) in the project.
new_user <- update_odk_app_user_role(
  action     = "create",
  con        = con,
  project_id = project_id,
  actor_name = "Demo Collector"
)
new_user
#> $actor_name
#> [1] "Demo Collector"
#> $actor_id
#> [1] 250
#> $project_id
#> [1] 11
```

``` r

# Give that user access to our form. role_id 2 is ODK's "App User" data-collection role.
update_odk_app_user_role(
  action     = "assign",
  con        = con,
  project_id = project_id,
  form_id    = form_id,
  role_id    = 2,
  actor_id   = new_user$actor_id
)
#> [1] TRUE
```

Check the form’s assignments — your new collector should be listed:

``` r

list_odk_form_users(con = con, project_id = project_id, form_id = form_id)
```

### Managing a whole team at once

Don’t click through 40 collectors one at a time. Put the actions in a
CSV with columns `project_id, form_id, action, actor_name` (action is
`create`, `assign`, or `remove`) and hand it to
[`eri_odk_bulk_users()`](https://thecartercenter.github.io/erifunctions/reference/eri_odk_bulk_users.md).
Always run it once with `dry_run = TRUE` first — it validates **every**
row against the live server and reports *all* problems together before
changing anything:

``` r

eri_odk_bulk_users("collectors.csv", con = con, dry_run = TRUE)
#> ℹ Fetching project/form metadata for pre-flight...
#> ✔ Pre-flight passed. 2 rows to process.
#> ℹ Dry run -- no changes will be made.
#>   [1] assign "Jane Fieldworker" on eri_test_river_prospection (project 11)
#>   [2] create "John Fieldworker" on eri_test_river_prospection (project 11)
```

## 3. Pull the data into the governed pipeline

This is where ODK meets the rest of the system. We use a sandbox
**country/disease** so it is easy to clean up: `country = "uga"`,
`disease = "demo"`. (ODK registration requires a real ERI country code —
`uga`, `ht`, `eth`, … — but the disease is free text, so `demo` keeps
this clearly a practice run.)

### Register the form

Registering records the form in the shared **ODK registry**
(`odk/registry.yaml`) — the team’s single source of truth for which
forms are tracked, and which country/disease each one feeds.

> **The registry is shared and team-visible.** Your registration lands
> in the **same** `odk/registry.yaml` as everyone’s real forms. For a
> real form, [Clean up](#clean-up)’s
> [`eri_odk_deregister()`](https://thecartercenter.github.io/erifunctions/reference/eri_odk_deregister.md)
> is a **soft-delete** (`active: false`) that preserves the audit trail
> — so a practice entry would linger (inactive) rather than vanishing.
> For **sandbox** work, use an obviously-fake `project_id`/`country`,
> and tear the entry down completely with
> [`eri_odk_purge()`](https://thecartercenter.github.io/erifunctions/reference/eri_odk_purge.md)
> (a hard-delete) so no practice rows are left behind in the shared
> registry.

``` r

data_con <- get_azure_storage_connection(storage_name = "data")

eri_odk_register(
  project_id = project_id,
  form_id    = form_id,
  country    = "uga",
  disease    = "demo",
  server_url = "https://your-odk-server.org/",
  data_con   = data_con
)
#> ✔ Registered "eri_test_river_prospection" (uga/demo) on <https://your-odk-server.org/>.

eri_odk_list_registered(data_con = data_con)
#> ℹ 1 registered form.
#> # A tibble: 1 × 9
#>   server_url               project_id form_id                    form_display_name … country disease added_by  added_at   last_synced
#>   <chr>                         <int> <chr>                      <chr>                <chr>   <chr>   <chr>     <chr>      <chr>
#> 1 https://your-odk-server…         11 eri_test_river_prospection ERI Test — River …   uga     demo    your.name 2026-06-26 NA
```

### Sync the submissions

[`eri_odk_sync()`](https://thecartercenter.github.io/erifunctions/reference/eri_odk_sync.md)
downloads every submission and writes it as a typed Parquet file into
the **raw** layer, then stamps the registry with the sync time:

``` r

eri_odk_sync(project_id = project_id, form_id = form_id, con = con, data_con = data_con)
#> ℹ Downloading submissions for "eri_test_river_prospection" (uga/demo)...
#> ℹ Downloaded 3 records from "eri_test_river_prospection".
#> ✔ Synced 3 records from "eri_test_river_prospection" to uga/demo/research/raw/eri_test_river_prospection.parquet.
```

Read it back to see what landed. ODK expands the form fields plus its
own system columns (note the `gps` geopoint is split into
latitude/longitude/altitude/accuracy):

``` r

raw <- eri_read("uga/demo/research/raw/eri_test_river_prospection.parquet", azcontainer = data_con)
names(raw)
#>  [1] "SubmissionDate"   "start"            "end"              "today"
#>  [5] "site_name"        "prospection_date" "river_stage"      "blackfly_count"
#>  [9] "gps-Latitude"     "gps-Longitude"    "gps-Altitude"     "gps-Accuracy"
#> [13] "collector"        "meta-instanceID"  "KEY"              "SubmitterID"
#> [17] "SubmitterName"    "AttachmentsPresent" "AttachmentsExpected" "Status"
#> [21] "ReviewState"      "DeviceID"         "Edits"            "FormVersion"
```

This practice form is **flat** — one row per submission — so it lands as
a single table in one Parquet. Most real forms have *repeat groups* and
come down as several tables; [section 4](#repeat-groups) shows how to
pull and sync those.

### Quality-check, stage, and approve

From here the ODK data flows through the **exact same pipeline** as a
surveillance extract. Quality- check it against a schema with
[`run_dq_checks()`](https://thecartercenter.github.io/erifunctions/reference/run_dq_checks.md)
(the **[surveillance ingest
guide](https://thecartercenter.github.io/erifunctions/articles/da-ingest-guide.md)**
walks through authoring a schema and reading the flags), write the
cleaned result to `staged/`, then **approve** it into the canonical
`processed/` layer:

``` r

# (After any DQ checks.) Stage the data under a reporting period.
staged_path <- eri_data_path("uga", "demo", "research", "staged",
                             "eri_test_river_prospection_2026-06.parquet")
eri_write(raw, staged_path, azcontainer = data_con)
```

``` r

# Channel-level approve (no measure yet); pass data_type = once you assign one.
eri_approve("uga", "demo", "research", "2026-06", azcontainer = data_con)
#> ℹ Approving the channel-level (no-measure) form; the catalog entry's data_type will be NA.
#>   Pass data_type (e.g. "case", "aggregate", "treatment") to record a measure (ADR-0012).
#> ✔ Catalog: registered eri_test_river_prospection_2026-06.parquet.
#> ✔ Approved: eri_test_river_prospection_2026-06.parquet
#> ✔ Approval log: uga/demo/research/processed/2026-06_approval_log.yaml
#> ── ✔ Approved "2026-06" ─────────────────────────────────
#> Dataset: uga / demo / research
#> Files: 1 moved to processed
#> Approver: your.name
#> Location: uga/demo/research/processed
```

Your ODK submissions are now canonical, discoverable in the catalog like
any other approved dataset:

``` r

eri_catalog_query(country = "uga", disease = "demo", data_con = data_con)
#> # A tibble: 1 × 13
#>   path                              country disease data_source data_type layer …
#>   <chr>                             <chr>   <chr>   <chr>       <chr>     <chr>
#> 1 uga/demo/research/processed/eri…  uga     demo    research    NA        proces…
```

## 4. Forms with repeat groups

The form above was deliberately simple — one row per submission, one
table. Most real ODK forms have **repeat groups**: a section the
enumerator fills in *more than once per submission* — several larvae
sampled at one site, several household members in one visit, several
nets given to one household. ODK Central exports each repeat group as
its **own table**, so a form with one repeat comes down as **two**
tables:

- a **parent** table — one row per submission (named `{form_id}`), and
- a **child** table — one row per repeat instance (named
  `{form_id}-{repeat_name}`), linked back to its parent by a
  `PARENT_KEY` column whose value matches the parent row’s `KEY`.

`erifunctions` captures all of them — nothing is silently dropped.

### Upload the repeat practice form

A second bundled XLSForm has a repeated `larva_sample` group (blackfly
species + larva count) under each river-prospection site:

``` r

repeat_xlsx <- system.file("extdata", "odk-test-form-repeat.xlsx", package = "erifunctions")
```

Upload it to your `test` project exactly as before (**New ▸ Form**, then
publish). Submit two or three entries — and for each one, use the **＋
Add** button inside the *Larva sample* group to record **two or three
samples** before sending. Those extra samples are what populate the
child table.

### Pull every table

Pass `tables = TRUE` to
[`download_odk_form()`](https://thecartercenter.github.io/erifunctions/reference/download_odk_form.md)
to get **all** of the form’s tables back as a named list instead of just
the parent:

``` r

repeat_form_id <- "eri_test_river_repeat"

tabs <- download_odk_form(project_id = project_id, form_id = repeat_form_id,
                          con = con, tables = TRUE)
#> ✔ Connected to <https://your-odk-server.org/>. Session expires 2026-06-28T02:21:49Z.
#> ℹ Downloaded 2 tables from "eri_test_river_repeat":
#> • "eri_test_river_repeat": 3 records
#> • "eri_test_river_repeat-larva_sample": 7 records

names(tabs)
#> [1] "eri_test_river_repeat"              "eri_test_river_repeat-larva_sample"
```

The **parent** table holds one row per submission — the site fields plus
ODK’s system columns, including the `KEY` that uniquely identifies each
submission:

``` r

names(tabs[["eri_test_river_repeat"]])
#>  [1] "SubmissionDate"     "start"               "end"                 "today"
#>  [5] "site_name"          "prospection_date"    "river_stage"         "collector"
#>  [9] "meta-instanceID"    "KEY"                 "SubmitterID"         "SubmitterName"
#> [13] "AttachmentsPresent" "AttachmentsExpected" "Status"              "ReviewState"
#> [17] "DeviceID"           "Edits"               "FormVersion"
```

The **child** table holds one row per larva sample. Its `PARENT_KEY`
points back to the parent’s `KEY`:

``` r

tabs[["eri_test_river_repeat-larva_sample"]]
#> # A tibble: 7 × 4
#>   species    larva_count PARENT_KEY                                KEY
#>   <chr>            <dbl> <chr>                                     <chr>
#> 1 s_neavei             3 uuid:b3ce44d7-6666-4889-91dc-7f0f3bc426ee uuid:b3ce44d7-6666-4889-91dc-7f0…
#> 2 s_neavei             3 uuid:5e70e2a3-382a-4269-838c-e3dbd14e3dbe uuid:5e70e2a3-382a-4269-838c-e3d…
#> 3 s_damnosum           4 uuid:5e70e2a3-382a-4269-838c-e3dbd14e3dbe uuid:5e70e2a3-382a-4269-838c-e3d…
#> 4 other                4 uuid:5e70e2a3-382a-4269-838c-e3dbd14e3dbe uuid:5e70e2a3-382a-4269-838c-e3d…
#> 5 s_damnosum           3 uuid:621e3b01-4825-43c5-9cf3-1ac734eb0426 uuid:621e3b01-4825-43c5-9cf3-1ac…
#> 6 other                3 uuid:621e3b01-4825-43c5-9cf3-1ac734eb0426 uuid:621e3b01-4825-43c5-9cf3-1ac…
#> 7 s_neavei             3 uuid:621e3b01-4825-43c5-9cf3-1ac734eb0426 uuid:621e3b01-4825-43c5-9cf3-1ac…
```

Here three submissions produced seven samples — submission `5e70e2a3…`
was sampled three times, `621e3b01…` three times, and `b3ce44d7…` once.

### Sync writes one Parquet per table

[`eri_odk_sync()`](https://thecartercenter.github.io/erifunctions/reference/eri_odk_sync.md)
handles repeat forms automatically. Register the form first (just as in
[section 3](#pull)), then sync — it writes **each** table to its own
Parquet in the `raw/` layer:

``` r

eri_odk_sync(project_id = project_id, form_id = repeat_form_id, con = con, data_con = data_con)
#> ℹ Downloading submissions for "eri_test_river_repeat" (uga/demo)...
#> ℹ Downloaded 2 tables from "eri_test_river_repeat":
#> • "eri_test_river_repeat": 3 records
#> • "eri_test_river_repeat-larva_sample": 7 records
#> ✔ Synced "eri_test_river_repeat": 3 submissions + 1 repeat table to 'uga/demo/research/raw/'.
```

You now have two files in `raw/` — a flat form would have left exactly
one:

    uga/demo/research/raw/eri_test_river_repeat.parquet                # parent: 3 submissions
    uga/demo/research/raw/eri_test_river_repeat-larva_sample.parquet   # child:  7 samples

### Rejoin them for analysis

The tables are kept separate on purpose — that is the faithful, lossless
shape of the data. When you want one flat table (one row per sample,
carrying its site context), join the child to the parent on `PARENT_KEY`
= `KEY`:

``` r

parent  <- eri_read("uga/demo/research/raw/eri_test_river_repeat.parquet", azcontainer = data_con)
samples <- eri_read("uga/demo/research/raw/eri_test_river_repeat-larva_sample.parquet",
                    azcontainer = data_con)

flat <- dplyr::left_join(
  samples,
  dplyr::select(parent, KEY, site_name, prospection_date, river_stage),
  by = c("PARENT_KEY" = "KEY")
)
flat
#> # A tibble: 7 × 7
#>   species    larva_count PARENT_KEY                     KEY   site_name prospection_date river_stage
#>   <chr>            <dbl> <chr>                          <chr> <chr>     <date>           <chr>
#> 1 s_neavei             3 uuid:b3ce44d7-6666-4889-91dc-… uuid… ds        2026-06-09       medium
#> 2 s_neavei             3 uuid:5e70e2a3-382a-4269-838c-… uuid… ld        2026-06-08       medium
#> 3 s_damnosum           4 uuid:5e70e2a3-382a-4269-838c-… uuid… ld        2026-06-08       medium
#> 4 other                4 uuid:5e70e2a3-382a-4269-838c-… uuid… ld        2026-06-08       medium
#> 5 s_damnosum           3 uuid:621e3b01-4825-43c5-9cf3-… uuid… a         2026-06-25       medium
#> 6 other                3 uuid:621e3b01-4825-43c5-9cf3-… uuid… a         2026-06-25       medium
#> 7 s_neavei             3 uuid:621e3b01-4825-43c5-9cf3-… uuid… a         2026-06-25       medium
```

Each table then flows through the same quality-check → stage →
**approve** gate as any other extract. Approve the parent and its
repeats together so they stay in step.

## 5. Backfilling records into a form

Everything so far moved data **out of** ODK Central. Sometimes you need
the other direction: a stack of records that already exist — collected
on **paper**, or living in an **old spreadsheet** — that you want to
land in ODK Central so they sit alongside the field submissions and flow
through the same pipeline.
[`eri_odk_upload()`](https://thecartercenter.github.io/erifunctions/reference/eri_odk_upload.md)
does exactly that: it reads a table and **creates one submission per
row** on an existing **published** form.

It is the mirror image of a download: columns are matched to form fields
**by name**, using the same flattening you saw above — a field nested in
a `visit` group is the column `visit-date`, and repeat groups are
supplied as the same `{form_id}-{repeat}` child tables linked by
`PARENT_KEY`. So a `download_odk_form(tables = TRUE)` result is itself a
valid input — **download and upload round-trip.**

Say you have a few historical river-prospection records to backfill.
Build (or read) a table whose columns match the form’s fields:

``` r

backfill <- data.frame(
  site_name       = c("Old Ford", "Bend Camp"),
  prospection_date = c("2025-11-03", "2025-11-04"),
  river_stage     = c("low", "medium"),
  blackfly_count  = c(12L, 7L),
  collector       = c("paper-archive", "paper-archive"),
  record_id       = c("hist-001", "hist-002")    # a stable key we'll hash for the instanceID
)
```

**Always dry-run first.** `dry_run = TRUE` validates the table against
the live form — unknown columns, required fields, value types (dates,
numbers, geopoints), and select-value choice lists — and sends
**nothing**:

``` r

eri_odk_upload(backfill, project_id = project_id, form_id = form_id,
               con = con, key_col = "record_id", dry_run = TRUE)
#> ✔ Validation clean: all columns map to form fields.
#> ℹ `dry_run` is on -- no submissions were sent.
#> # A tibble: 0 × 4
#> # ℹ 4 variables: table <chr>, column <chr>, row <int>, issue <chr>
```

A non-empty tibble tells you exactly which cell to fix
(e.g. `river_stage` value `"purple"` → *“value(s) not in the choice
list”*). Once it is clean, drop `dry_run` to send them:

``` r

eri_odk_upload(backfill, project_id = project_id, form_id = form_id,
               con = con, key_col = "record_id")
#> ✔ Validation clean: all columns map to form fields.
#> ✔ Uploaded to "eri_test_river_prospection": 2 created, 0 already present.
#> # A tibble: 2 × 4
#>   instance_id                           status  http_status message
#>   <chr>                                 <chr>         <int> <chr>
#> 1 uuid:682c06225e8949547e6c34a6b6834ee4 created         200 NA
#> 2 uuid:80a4e16d30398e85e78b4c18799a63ab created         200 NA
```

The `instanceID` of each submission is **derived deterministically**
from `key_col` (here `record_id`). That makes the upload **safe to
re-run**: the second time, ODK Central recognises the same ids and
rejects them, so nothing is duplicated —

``` r

eri_odk_upload(backfill, project_id = project_id, form_id = form_id,
               con = con, key_col = "record_id")
#> ✔ Uploaded to "eri_test_river_prospection": 0 created, 2 already present.
```

— and if you fix a couple of rows and run again, only those change while
the rest skip. A bad row never aborts the batch: it comes back as
`failed` (with the server’s message) while its neighbours load.

### Headers that don’t match the form

A paper or legacy spreadsheet rarely uses the form’s exact column names.
Rather than editing the source file, pass a **`mapping`** —
`c(your_header = "field-column", …)` — and
[`eri_odk_upload()`](https://thecartercenter.github.io/erifunctions/reference/eri_odk_upload.md)
renames the columns before it validates:

``` r

paper <- data.frame(
  village   = c("Old Ford", "Bend Camp"),
  date_seen = c("2025-11-03", "2025-11-04"),
  stage     = c("low", "medium"),
  flies     = c(12L, 7L),
  recorder  = c("paper-archive", "paper-archive"),
  rec       = c("hist-101", "hist-102")
)

eri_odk_upload(paper, project_id = project_id, form_id = form_id, con = con,
               mapping = c(village = "site_name", date_seen = "prospection_date",
                           stage = "river_stage", flies = "blackfly_count",
                           recorder = "collector"),
               key_col = "rec", dry_run = TRUE)
#> ✔ Validation clean: all columns map to form fields.
#> ℹ `dry_run` is on -- no submissions were sent.
#> # A tibble: 0 × 4
#> # ℹ 4 variables: table <chr>, column <chr>, row <int>, issue <chr>
```

Map only the columns that differ — anything already matching a field is
left alone — then drop `dry_run` to send. The targets are the same
flattened field-column names (`group-field`).

> **Forms with repeats.** Pass the same named-list shape you got from
> `download_odk_form(tables = TRUE)` — the parent table first, then each
> `{form_id}-{repeat}` child table with a `PARENT_KEY` column linking to
> the parent’s `KEY`.
> [`eri_odk_upload()`](https://thecartercenter.github.io/erifunctions/reference/eri_odk_upload.md)
> rebuilds the nested submission and attaches each repeat to the right
> parent.

> **Two limits to know.** The form must be **published** (you can’t
> backfill into a draft), and **attachments can’t be sent at creation**
> — that is an ODK Central API constraint, so photos/GPS traces are out
> of scope for the upload.

## 6. Clean up

Practice run done — remove everything you created so you leave no trace.

``` r

# Remove the demo collector from ODK Central (revoke its form access, then delete the account).
update_odk_app_user_role(action = "revoke", con = con, project_id = project_id,
                         form_id = form_id, role_id = 2, actor_id = new_user$actor_id)
update_odk_app_user_role(action = "delete", con = con, project_id = project_id,
                         actor_id = new_user$actor_id)
```

``` r

# This was a sandbox, so PURGE the registry entry (hard-delete) to leave no trace.
# For a real form you'd use eri_odk_deregister() instead, which soft-deletes
# (active: false) and keeps the sync history for audit.
eri_odk_purge(project_id = project_id, form_id = form_id,
              server_url = "https://your-odk-server.org/", data_con = data_con)
#> ✔ Purged 1 registry entry for "eri_test_river_prospection" (project 11).

# If you also tried the repeat form in section 4, purge it too.
eri_odk_purge(project_id = project_id, form_id = "eri_test_river_repeat",
              server_url = "https://your-odk-server.org/", data_con = data_con)
#> ✔ Purged 1 registry entry for "eri_test_river_repeat" (project 11).
```

``` r

# Delete the whole uga/demo sandbox namespace (raw + staged + processed + logs).
# eri_dir_delete() removes it recursively — the in-package path, no Storage Explorer.
eri_dir_delete("uga/demo", azcontainer = data_con)
```

Finally, in the ODK Central web interface, delete the test form (Form ▸
⋯ ▸ Delete) from your `test` project if you want it gone there too.

> **Deregister vs purge.** For a **real** form,
> [`eri_odk_deregister()`](https://thecartercenter.github.io/erifunctions/reference/eri_odk_deregister.md)
> *soft*-deletes — it flips the registry entry to `active: false` rather
> than erasing it, so the record of what was once tracked (and its sync
> history) survives for audit; the inactive entry is harmless and won’t
> show up in
> [`eri_odk_list_registered()`](https://thecartercenter.github.io/erifunctions/reference/eri_odk_list_registered.md).
> We used
> **[`eri_odk_purge()`](https://thecartercenter.github.io/erifunctions/reference/eri_odk_purge.md)**
> above because this was a sandbox: it *hard*-deletes the entry (active
> or already-inactive) so the shared registry is left exactly as we
> found it.

> **Why we could delete freely here:** the form and its submissions are
> invented. **Real ODK forms and field submissions are never deleted
> casually** — they are the primary record of work done in the field.
> The discipline this guide builds — register, sync to `raw/`,
> quality-check, and approve through the human gate — is what keeps that
> real data trustworthy.

## What’s next

You have run the full ODK loop: connect, monitor, manage collectors,
sync to the governed pipeline, and approve into the canonical layer.

- **Incremental sync** (only the new/edited submissions, rather than
  re-downloading everything) is on the roadmap (Phase 4) — the registry
  already reserves a `last_cursor` for it.
- **Backfilling the other direction** — pushing a CSV/Excel table of
  historical records *into* a form — is
  [`eri_odk_upload()`](https://thecartercenter.github.io/erifunctions/reference/eri_odk_upload.md),
  shown in section 5 above.
- **Attachments** (photos, GPS traces) come down with
  [`download_form_attachments()`](https://thecartercenter.github.io/erifunctions/reference/download_form_attachments.md).
- For the full data-quality and approval mechanics, see the
  [surveillance ingest
  guide](https://thecartercenter.github.io/erifunctions/articles/da-ingest-guide.md);
  for the whole menu of functions, the
  [reference](https://thecartercenter.github.io/erifunctions/reference/index.md).
  The [guide
  index](https://github.com/thecartercenter/erifunctions/blob/main/docs/guides.md)
  tracks what exists and what is coming.
