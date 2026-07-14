# ADR-0020 — Canonical, normalized country and disease codes

- **Status:** Accepted
- **Date:** 2026-07-14

## Context

The five-axis data model (ADR-0012) validates `data_source`/`data_type`/`format`/`layer` against
`inst/registry/data_model.yaml` (`.eri_check_axis()` — unknown values warn, never block). ADR-0012
point 5 states the same extensible-by-data philosophy for `country`/`disease` in spirit ("This
country/disease/source/measure doesn't exist yet" is a normal, expected gap) — but it was never
actually wired up. `eri_data_path()` (`R/dal.R`) built every path segment from `country`/`disease`
verbatim, any case, with zero registry backing.

This is exactly how legacy-cased paths — `uga/LF`, `eth/RB` — were created and silently diverged
from the rest of the data lake (found and fixed in #303; the existing data was migrated by hand).
The actual entry point was `eri_odk_register()` (`R/odk_registry.R`), which hard-validated
`country` against a local `.KNOWN_COUNTRY_CODES` constant (case-sensitive membership — an
uppercase typo already errored, just unhelpfully) but had **no check at all** on `disease`. A
second, independent `.KNOWN_DISEASES` constant lived in `R/wizard.R`, used only to populate the
interactive picker's suggestions — never validated against, and free to drift from the first list.

## Decision

Extend the ADR-0012 registry pattern to `country` and `disease`, completing what point 5 already
called for:

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
3. **`eri_odk_register()`** — the actual point where a human first types a country/disease —
   normalizes both before validating. `country` keeps its hard abort (a small, curated,
   organizationally-fixed set); `disease` gets the same soft warn as everywhere else (diseases can
   legitimately expand as new programs launch, so blocking would fight ADR-0012's own philosophy).
4. **`.KNOWN_COUNTRY_CODES`/`.KNOWN_DISEASES`, two independent hardcoded lists that could already
   drift from each other, are removed.** `.eri_known_countries()`/`.eri_known_diseases()` read the
   one registry instead — `R/wizard.R`'s picker, `R/odk_registry.R`'s validation, and
   `eri_data_path()`'s normalization now share a single source of truth by construction, not by
   convention.

## Consequences

- **Easier:** a case typo (`"UGA"`, `"LF"`) is silently corrected instead of either erroring
  (country, previously) or drifting into a permanent, differently-cased path (disease,
  previously) — the specific failure mode #303 was.
- **Easier:** `eri_data_model()` (the package's own "what do I know about?" introspection command)
  now shows `country`/`disease` alongside the other three axes, instead of omitting two of the
  five.
- **Harder / accepted:** `country`/`disease` normalization only fires for callers that go through
  `eri_data_path()` or `eri_odk_register()`. A caller that hand-builds a path by string
  concatenation (as `eri_odk_sync()`'s log-path write already did, reading `disease` straight from
  a — now-normalized-at-write-time — registry entry) is unaffected by this ADR directly; it inherits
  correctness because the *stored* value is now canonical, not because every consumer re-normalizes.
  A future hand-built path from an *unnormalized* source would still need to route through
  `eri_data_path()` to get this protection.
- **Not doing:** making `country`/`disease` a closed/hard-validated set like `layer`. Both remain
  extensible-by-data per ADR-0012 point 5 — a genuinely new country or disease is still a data
  change (add a registry entry), not a core-code edit, and a warn (not an abort) is what keeps that
  true for `eri_data_path()`'s general chokepoint.

## References

- ADR-0012 point 5 — the extensible-by-data philosophy this completes for `country`/`disease`.
- ADR-0010 / ADR-0019 — the ODK repeat-group set model and its zero-row-parent amendment; unrelated
  axis, same registry-and-chokepoint pattern.
- Issue #303 / PR #304 / PR #305 — the `LF`/`RB` legacy-casing bug this prevents from recurring.
