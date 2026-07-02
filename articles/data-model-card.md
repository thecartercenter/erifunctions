# Data-model decision card: channel vs. measure

*The one concept everything else rests on. If you can answer the four
questions below for a dataset, you can address it, ingest it, and
approve it. Run
[`eri_data_model()`](https://thecartercenter.github.io/erifunctions/reference/eri_data_model.md)
to see the live list of allowed values.*

## A path has five axes

    data / {country} / {disease} / {data_source} / {data_type} / {layer}

Two of them, `data_source` and `data_type`, are the ones people mix up.
They are **independent**:

| Axis | Plain-English question | It is NOT… |
|----|----|----|
| **`data_source`** (the *channel*) | *How did this data reach us?* | not the disease, not the file format |
| **`data_type`** (the *measure*) | *What does each row count?* | not the channel, not derivable from the disease |

**They don’t determine each other.** The same channel carries different
measures, and the same (channel, disease) gives a *different* measure
per country:

- One **CMR** (programmatic) fans out to **7 measures across 3
  diseases** (treatment, MMDP, training, surveys…).
- DR malaria **surveillance** is **`case`** (one row per patient); Haiti
  malaria surveillance is **`aggregate`** (facility × month counts).
  Same source, same disease, different measure.

## Answer these four, in order

1.  **country**: `dr`, `ht`, `eth`, `uga`, `nga`, `sdn`, `ssd`, `tcd`,
    `mad`, `oepa`, …
2.  **disease**: `malaria`, `oncho`, `lf`, `sch`, `sth` (free text;
    lowercase).
3.  **data_source (channel)**: pick one:
    - **`surveillance`**: routine MoH feed (DR/Haiti malaria). Output:
      cases or aggregate counts.
    - **`programmatic`**: country-team activity/coverage data: CMR, or a
      direct MDA feed. Spans diseases (split per disease on ingest).
    - **`research`**: survey instruments launched + monitored via ODK,
      then cleaned into a final analytic dataset (TAS, prevalence,
      entomology).
4.  **data_type (measure)**: what the rows count: `case` · `aggregate` ·
    `treatment` · `mmdp` · `training` · `survey` · `tas` · `prevalence`
    · `entomology`.

&nbsp;

                          ┌─ case            (line-list, one row per patient)
       surveillance ──────┤
                          └─ aggregate       (facility/period counts)

                          ┌─ treatment       (MDA coverage)
       programmatic ──────┼─ mmdp · training
                          └─ survey

                          ┌─ tas
       research (ODK) ────┼─ prevalence
                          └─ entomology

## Worked examples

| You have… | country | disease | data_source | data_type |
|----|----|----|----|----|
| DR malaria line-list | `dr` | `malaria` | `surveillance` | `case` |
| Haiti malaria monthly facility counts | `ht` | `malaria` | `surveillance` | `aggregate` |
| Uganda CMR “RB Treatment” sheet | `uga` | `oncho` | `programmatic` | `treatment` |
| Uganda CMR “LF MMDP” sheet | `uga` | `lf` | `programmatic` | `mmdp` |
| A TAS survey pulled from ODK | `uga` | `lf` | `research` | `tas` |

## Two things that trip people up

- **`format` ≠ `data_source`.** “CMR” and “ODK” are input *formats*,
  recorded in a `format` field, not channels. A CMR is `programmatic`;
  an ODK form is `research`. (The `cmr`/`odk` path tokens you may see in
  older data are transitional and being retired, ADR-0012.)
- **A missing combination is normal.** If
  [`load_dq_schema()`](https://thecartercenter.github.io/erifunctions/reference/load_dq_schema.md)
  /
  [`eri_data_path()`](https://thecartercenter.github.io/erifunctions/reference/eri_data_path.md)
  doesn’t recognise a value, you get a **warning**, not an error, adding
  a new country/disease/source/measure is a *data* change (a schema + a
  registry entry), not a code change. See the [onboarding a new program
  guide](https://thecartercenter.github.io/erifunctions/articles/da-onboard-guide.md).
