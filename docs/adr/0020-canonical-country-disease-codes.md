# ADR-0020 — Canonical, normalized country and disease codes

- **Status:** Accepted — amends [ADR-0012](0012-source-measure-data-model.md) point 5
- **Date:** 2026-07-14

## Context

The five-axis data model (ADR-0012) validates `data_source`/`data_type`/`format`/`layer` against
`inst/registry/data_model.yaml` (`.eri_check_axis()` — unknown values warn, never block). ADR-0012
point 5's bolded decision names only `data_source`/`data_type` as extensible-by-data; `country`/
`disease` appear only in an illustrative aside ("This country/disease/source/measure doesn't exist
yet" is a normal, expected gap) — never actually wired to a registry or validated. `eri_data_path()`
(`R/dal.R`) built every path segment from `country`/`disease` verbatim, any case, with zero backing.

This is exactly how legacy-cased paths — `uga/LF`, `eth/RB` — were created and silently diverged
from the rest of the data lake (found and fixed in #303; the existing data was migrated by hand).
The actual entry point was `eri_odk_register()` (`R/odk_registry.R`), which hard-validated
`country` against a local `.KNOWN_COUNTRY_CODES` constant (case-sensitive membership — an
uppercase typo already errored, just unhelpfully) but had **no check at all** on `disease`. A
second, independent `.KNOWN_DISEASES` constant lived in `R/wizard.R`, used only to populate the
interactive picker's suggestions — never validated against, and free to drift from the first list.

## Decision

Amend ADR-0012 point 5 so its stated philosophy actually governs `country`/`disease`, not just
`data_source`/`data_type`:

1. **`inst/registry/data_model.yaml` gains `countries:`/`diseases:` sections**, same shape and
   same non-blocking philosophy as `data_sources:`/`data_types:`. Includes `atlantis` (the
   synthetic training sandbox, already a real `country_code` elsewhere in the package) and `rblf`
   (the transitional combined RB+LF programmatic code, retired at the hsp-mal Phase-3 cutover) —
   both real, intentional, existing usages that must not start warning spuriously.
2. **`.eri_normalize_geo_axis()` (`R/data_model.R`)**: lowercase + trim, then soft-warn via the
   existing `.eri_check_axis()` if the normalized value isn't in the registry. Returns the
   normalized value. Wired into `eri_data_path()` — the shared chokepoint nearly every write in the
   package routes through — so a path is always built from the canonical form regardless of input
   casing.
3. **Every governed pipeline entry point that also hand-builds a *sibling* path** — a log directory
   built separately from the `staged_dir`/`processed_dir`/`raw_dir` that `eri_data_path()` computes,
   in the same function call — **normalizes `country`/`disease` once, at its own top, before either
   path is built.** `eri_data_path()` normalizing its own internal copy is not enough on its own:
   R is pass-by-value, so that normalization never reaches a caller's own `country`/`disease`
   locals used elsewhere in the same call. Without this, `eri_approve("UGA", "LF", ...)` would
   promote data to `uga/lf/.../processed/` (via `eri_data_path()`) while logging the operation to
   `UGA/LF/.../logs/` (via hand-built `paste()`) — the exact #303 failure class, one hop away, still
   reachable through the package's own most-used entry points. Fixed in: `eri_approve()`,
   `eri_stage()`, `eri_ingest()`, `.eri_dq_log_write()` (which never called `eri_data_path()` at
   all), `eri_split_cmr()`, `eri_stage_cmr()`, `eri_approve_cmr()`.
4. **`eri_odk_register()`** — the actual point where a human first types a country/disease —
   normalizes both before validating. `country` keeps its hard abort, now against a
   **production-only** list (`.eri_known_countries(include_sandbox = FALSE)`) that excludes
   `atlantis` — ODK registration never offered the training sandbox before this registry was
   unified, and it already has its own sandbox convention (the `uga`/`demo` namespace), so nothing
   about that should change. `disease` gets the same soft warn as everywhere else (diseases can
   legitimately expand as new programs launch, so blocking would fight ADR-0012's own philosophy).
   The wizard's ODK country picker (`R/wizard.R`, `.eri_flow_odk()`) uses the same production-only
   list, so it never *offers* `atlantis` as a choice a DA would then have rejected anyway.
5. **`.KNOWN_COUNTRY_CODES`/`.KNOWN_DISEASES`, two independent hardcoded lists that could already
   drift from each other, are removed.** `.eri_known_countries()`/`.eri_known_diseases()` read the
   one registry instead — `R/wizard.R`'s picker, `R/odk_registry.R`'s validation, and
   `eri_data_path()`'s normalization now share a single source of truth by construction, not by
   convention.

## Consequences

- **Easier:** a case typo (`"UGA"`, `"LF"`) is silently corrected instead of either erroring
  (country, previously) or drifting into a permanent, differently-cased path (disease,
  previously) — the specific failure mode #303 was, including in the sibling-log-path form
  (point 3 above) that isn't visible just from reading `eri_data_path()`'s own diff.
- **Easier:** `eri_data_model()` (the package's own "what do I know about?" introspection command)
  now shows `country`/`disease` alongside the other three axes, instead of omitting two of the
  five.
- **Harder / accepted:** normalization only fires for code paths that actually call
  `.eri_normalize_geo_axis()`/`eri_data_path()`/`eri_odk_register()`. A pure *read* lookup keyed on
  `country`/`disease` (`load_cmr_schema()`, `load_dq_schema()`'s legacy stem form) is untouched —
  a case mismatch there fails loudly (file/schema not found) rather than silently diverging, which
  is a different and lower-severity failure mode than the one this ADR targets, so it's left alone.
  A caller reading an already-normalized *stored* value (`eri_odk_sync()`'s log path, sourced from
  a registry entry `eri_odk_register()` already normalized at write time) is safe by construction,
  not because it re-normalizes itself.
- **Not doing:** making `country`/`disease` a closed/hard-validated set like `layer` in the general
  case. Both remain extensible-by-data per ADR-0012 point 5 — a genuinely new country or disease is
  still a data change (add a registry entry), not a core-code edit, and a warn (not an abort) is
  what keeps that true for `eri_data_path()`'s general chokepoint. `eri_odk_register()`'s
  country hard-abort is the one deliberate exception, unchanged from before this ADR except for
  case-insensitivity and the `atlantis` exclusion.

## References

- ADR-0012 point 5 — the extensible-by-data decision this amends to actually cover `country`/
  `disease`.
- ADR-0010 / ADR-0019 — the ODK repeat-group set model and its zero-row-parent amendment; unrelated
  axis, same amend-in-place / registry-and-chokepoint conventions.
- Issue #303 / PR #304 / PR #305 — the `LF`/`RB` legacy-casing bug this prevents from recurring.
- Issue #306 / PR #307 — this ADR's own implementation.
