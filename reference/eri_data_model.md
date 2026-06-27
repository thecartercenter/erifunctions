# Show the data-addressing model: known sources, measures and formats

**\[experimental\]**

Prints (and returns invisibly) the registry of known values for the
five-axis canonical path
`data/{country}/{disease}/{data_source}/{data_type}/{layer}/`
(ADR-0012): the `data_source` channels, the `data_type` measures, the
input `format`s, and the pipeline `layer`s. New sources/measures are
added to the registry by onboarding; an unregistered value warns rather
than errors.

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
#> ── data_source (channel / how the data arrives) ──
#> 
#> • surveillance -- Direct disease-output feed (e.g. a Ministry-of-Health
#>   surveillance system).
#> • programmatic -- Programmatic activity/coverage data (country-team CMR, MoH
#>   MDA feeds); spans diseases.
#> • research -- Research surveys/studies (household or community level);
#>   DA-managed, flexible measure.
#> • cmr -- (transitional) Legacy CMR source token; migrating to `programmatic` +
#>   format: cmr.
#> • odk -- (transitional) Legacy ODK source token; migrating to `research` +
#>   format: odk.
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
