# Show the data-addressing model: known sources, measures and formats

**\[experimental\]**

Prints (and returns invisibly) the registry of known values for the
five-axis canonical path
`data/{country}/{disease}/{data_source}/{data_type}/{layer}/`
(ADR-0012): the `country` codes, `disease` codes, `data_source`
channels, `data_type` measures, input `format`s, and pipeline `layer`s.
New countries/sources/measures are added to the registry by onboarding;
an unregistered value warns rather than errors. `country`/`disease` are
also normalized to lowercase wherever a path is built (ADR-0020).

## Usage

``` r
eri_data_model()
```

## Value

Invisibly, the registry as a named list.

## Examples

``` r
eri_data_model()
#> 
#> ── Data-addressing model (ADR-0012) ────────────────────────────────────────────
#> Path: data/{country}/{disease}/{data_source}/{data_type}/{layer}/
#> 
#> ── country ──
#> 
#> • dr -- Dominican Republic
#> • ht -- Haiti
#> • eth -- Ethiopia
#> • nga -- Nigeria
#> • sdn -- Sudan
#> • ssd -- South Sudan
#> • uga -- Uganda
#> • mad -- Madagascar
#> • tcd -- Chad
#> • atlantis -- (training sandbox) Synthetic country for teaching/testing; not a
#>   real ERI program.
#> 
#> ── disease ──
#> 
#> • malaria -- Malaria
#> • oncho -- Onchocerciasis (river blindness)
#> • lf -- Lymphatic filariasis
#> • sch -- Schistosomiasis
#> • sth -- Soil-transmitted helminths
#> • rblf -- (transitional) Combined RB+LF programmatic code; retired at the
#>   hsp-mal Phase-3 cutover.
#> 
#> ── data_source (channel / how the data arrives) ──
#> 
#> • surveillance -- Direct disease-output feed (e.g. a Ministry-of-Health
#>   surveillance system).
#> • programmatic -- Programmatic activity/coverage data (country-team CMR, MoH
#>   MDA feeds); spans diseases.
#> • research -- Research surveys/studies (household or community level);
#>   DA-managed, flexible measure.
#> • cmr -- (transitional, legacy reads only) Old CMR source token; new CMR writes
#>   use `programmatic` + format: cmr.
#> • odk -- (transitional, legacy reads only) Old ODK source token; new ODK writes
#>   use `research` + format: odk.
#> 
#> ── data_type (the measure / what it captures) ──
#> 
#> • case -- Individual case records (one row per patient).
#> • aggregate -- Aggregated counts (one row per place/period).
#> • treatment -- MDA / treatment coverage (target & treated).
#> • mmdp -- Morbidity management & disability prevention (e.g. LF
#>   hydrocele/lymphoedema).
#> • training -- Programmatic training activity (CDD / CS / MMDP).
#> • survey -- Programmatic survey (examined / positive).
#> • tas -- Transmission assessment survey (LF).
#> • prevalence -- Prevalence survey (e.g. Kato-Katz, skin snip).
#> • entomology -- Vector / entomological surveillance (e.g. larval prospection).
#> 
#> ── format (input shape of a programmatic source) ──
#> 
#> • cmr -- Country Monitoring Report Excel template (a programmatic input
#>   format).
#> • moh_feed -- A direct Ministry-of-Health data feed (a programmatic input
#>   format that is not a CMR).
#> • odk -- ODK Central survey instrument (a research collection format).
#> 
#> ── layer ──
#> 
#> "raw", "staged", and "processed"
```
