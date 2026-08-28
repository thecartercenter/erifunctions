# ADR-0025 — Legacy mirror filename: `{period}_{upload_date}_{3-letter country code}`

- **Status:** Accepted
- **Date:** 2026-08-27

## Context

[ADR-0021](0021-mirror-filename-period-leading.md) settled the legacy mirror filename on
`{period}_{country}_{timestamp}.ext` (e.g. `202607_uga_20260715T162702Z.xlsx`) -- period leading,
confirmed with "the product owner" during the July 2026 pilot-session prep.

Zack, who owns the legacy contractor pipeline that actually reads this raw-drop location, reported
(`eri_feedback` #8, Emalee, 2026-07-27) that his pipeline wasn't picking up the most recent file.
His pipeline's real, stated requirement: `YYYYMM` (report period) `_YYYYMMDD` (upload date)
`_{3-letter country code}` -- a different field order (country last, not second), a date-only
upload stamp rather than a full `HHMMSS` timestamp, and the 3-letter country code specifically, not
whatever code the wizard happens to use internally.

ADR-0021's "confirmed with the product owner" was Nishant's own best understanding of the
convention at the time, not a check against Zack's pipeline directly -- this ADR corrects that
convention against the actual downstream consumer, once someone who owns that consumer weighed in.

A related, smaller issue surfaced while fixing this: for every rb-expansion country up to now
(eth/nga/sdn/ssd/uga/mad/tcd/bra/ven), the wizard-facing country code and the raw-drop subfolder
name are identical, so using the wizard code verbatim in the filename never looked wrong. `ht`
(issue #329, `country_map["ht"] = "hti"`) is the first exception -- the folder is `hti`, and the
old code would have written `..._ht_...` into it, inconsistent with the folder itself and short of
Zack's stated 3-letter requirement.

## Decision

The mirror upload's generated filename is now `{period}_{upload_YYYYMMDD}_{COUNTRY}.ext` (e.g.
`202607_20260827_HTI.xlsx`), using `toupper(mirror$subfolder)` -- the same `country_map` subfolder
lookup `eri_stage_cmr()`'s `src_base` and `.eri_derive_cmr_destination()` already use (R/dal.R) --
rather than the wizard-facing `country` code. This supersedes ADR-0021's field order and precision;
ADR-0021's underlying reasoning (a generated name, not `basename(path)` verbatim, and period should
lead something) is otherwise superseded in full by this decision, since Zack's own convention
doesn't put the period-leading rule ADR-0021 generalized from anywhere except first position, which
this format keeps.

## Consequences

- **Easier:** the legacy pipeline can now actually find the most recent file per Zack's own stated
  parsing convention -- the actual purpose of writing to this location at all.
- **Harder / accepted:** dropping the `HHMMSS` component means two mirror uploads of the same
  country/period on the same calendar day produce the same filename. The second overwrites the
  first -- handled by the existing overwrite-with-warning path (`eri_split_cmr()` already warns
  "Overwriting existing legacy raw file" before any write in this function), not a new failure
  mode, and matches what Zack's format literally asks for (one file per country/period/day).
- **Not doing:** touching `eri_stage_cmr()`'s own filenames (unchanged from ADR-0021's note --
  it copies `basename()` of whatever the legacy `projects` blob already has verbatim).

## References

- Supersedes [ADR-0021](0021-mirror-filename-period-leading.md)'s filename format (field order and
  timestamp precision); ADR-0021's period-leading rationale is subsumed, not contradicted.
- `eri_feedback` #8 (Emalee, 2026-07-27), relaying Zack's stated format requirement.
- Issue #336 / PR #337.
- `R/cmr.R`'s `eri_split_cmr()`, the `mirror_pipeline` branch.
