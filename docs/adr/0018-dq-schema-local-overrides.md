# ADR-0018 — DQ schema local overrides: three-tier resolution, hash-based expiry

- **Status:** Accepted
- **Date:** 2026-07-10

## Context

Phase 3 of the pilot-feedback-driven DQ workflow redesign (design consult with Fable; see the
"DQ workflow redesign" entry under Phase 3 of `docs/roadmap.md` for the full 8-phase plan) needs a
DA to be able to fix a bad DQ schema call locally — a missing alias, a too-narrow allowed-values
list, a range that's wrong for a specific country — without waiting on a package release, and
without that local fix silently going stale or silently winning forever over a maintainer's real
fix.

[`load_dq_schema()`](../../R/dq.R) already resolves a schema in two tiers: the Azure `schemas/`
blob, falling back to the copy bundled with the package. The locked decision from the consult adds
a third, higher-precedence tier — a DA's own local working copy — but raised a real contradiction
that needed resolving before any code could be written:

> "A package update naturally supersedes/overwrites the DA's local copy" is not mechanically true.
> Installing a new package version touches nothing in a user-level directory, and the same decision
> also says the local copy "is the active schema for subsequent reruns until superseded" — as
> written, the override would win *forever*.

The real supersede channel is also not the package bundle at all: `load_dq_schema()` already
prefers the Azure `schemas/` blob over the bundled copy, so "fold a DA's fix in" means *updating the
Azure blob* (effective for every DA within minutes), not cutting a package release (effective at the
next `install_github()`, which could be weeks). Any local-override design that assumes the wrong
supersede channel will retire overrides at the wrong time — or never.

## Decision

**Resolution order, implemented as one resolver inside `load_dq_schema()`** (the guardrail in
CLAUDE.md against solving a general problem in a narrow place): **local override → Azure blob →
bundled**.

1. **Location:** `tools::R_user_dir("erifunctions", "data")/schema_overrides/{stem}.yaml`, with a
   metadata sidecar `{stem}.meta.yaml` — never the working directory. A `./schema_local.yaml`
   convention would break the moment a DA opens a different RStudio project (their reruns silently
   stop seeing the override, re-flagging the exact issue they thought they'd fixed) and would leak
   into git repos and synced folders. `R_user_dir()` is per-user, project-independent, and base R
   (the package already requires R ≥ 4.1).
2. **Sidecar metadata** (`forked_at`, `forked_by`, `base_source` — `"azure"` or `"bundled"` —,
   `base_hash`, `edits`) is what makes staleness detection possible without re-deriving it from the
   override content itself.
3. **Expiry is hash-based, checked on every load, not time-based.** `.eri_dq_schema_resolve()`
   compares the sidecar's `base_hash` against an MD5 of whichever upstream currently resolves (Azure
   if reachable, else bundled). If they still match, the override is live and wins. If they don't —
   the true supersede channel (the Azure blob, or in the rare Azure-unreachable case the bundled
   file) changed since the DA forked — the override is **retired**, not kept and not silently
   discarded: it's renamed to `{stem}.retired-<timestamp>.yaml` (and its sidecar likewise), the
   loader falls through to the current upstream, and the DA is told exactly why
   (`cli_alert_warning`, not a silent fallback) so they know to re-review or re-fork rather than
   assume their earlier fix is still in effect.
4. **Never silent in the other direction either.** Using a live override always emits
   `cli_alert_info` naming the override and its fork date. `run_dq_checks()` carries the resolved
   schema's `$schema_source` (`"local_override"` / `"azure"` / `"bundled"`) and `$schema_hash`
   straight into the returned `dq_result`, and `.eri_dq_log_write()` records both in the permanent
   `dq_flags` envelope — a DQ result produced under a modified schema is always distinguishable, in
   the log, from one produced under the canonical schema. This is load-bearing for the audit trail
   planned in Phase 5 (`eri_audit()`).
5. **Lifecycle API**, all in `R/dq.R`, all offline-testable (no Azure required — a `NULL`
   `azcontainer` checks staleness against only the bundled copy):
   - `eri_dq_schema_path()` — resolves and returns the *active* schema's local file path (same
     three-tier resolution as `load_dq_schema()`, but a path instead of parsed content) — this is
     "schema addressable by its axes" from the original workflow-redesign vision, and what a future
     interactive reviewer would hand to an editor.
   - `eri_dq_schema_edit()` — forks the resolved upstream into the override directory, writing the
     sidecar. Idempotent: calling it again while a live (non-stale) override already exists returns
     that override unchanged rather than clobbering it.
   - `eri_dq_schema_status()` — lists overrides with age and active/stale state. Deliberately
     **read-only**: unlike a real schema load, checking status must never itself retire a stale
     override as a side effect of merely looking.
   - `eri_dq_schema_reset()` — deletes a live override (with a `cli`/`utils::menu()` confirmation in
     interactive sessions only; scripts and CI proceed without asking). Retired overrides
     (`.retired-*`) are left alone — they're a record of what a DA's local changes used to be, not
     something `reset()` is asked to touch.
6. **The legacy two-argument `load_dq_schema(country, key)` form never resolves a local override.**
   Every real caller of that form predates the override feature; keeping overrides keyed to the
   modern ADR-0012 four-axis stem only, with the legacy form passing `allow_override = FALSE`,
   avoids a combined-key alias accidentally shadowing (or being shadowed by) a four-axis override
   for what is conceptually a different identity.

## Consequences

- **Easier:** a DA can fix a bad schema call immediately, keep using the fix across sessions and
  reruns (surviving R restarts, different RStudio projects, machine reboots), and never has to
  wonder whether a maintainer's later fix silently overrode their attention or, conversely, whether
  their own stale local copy is silently masking a schema that's already been fixed upstream.
- **Harder:** one more resolution tier to reason about when a DQ result looks different than
  expected — mitigated by `schema_source`/`schema_hash` always being visible on both the schema
  object and the permanent log entry, and by `eri_dq_schema_status()` being a one-call way to check
  what's live.
- **Not doing (yet):** submitting an override upstream so a maintainer can fold it into the real
  Azure/bundled schema — that's `eri_dq_schema_submit()`, Phase 4 of the same redesign, layered on
  top of `eri_feedback()`'s planned `context`/`attachment` fields. This phase only builds the local
  working-copy lifecycle; nothing here reaches another DA or the canonical schema.
- **Precedent:** the retire-on-hash-mismatch pattern (detect silently-stale local state against its
  recorded origin, retire loudly rather than either keep-forever or silently-discard) is the second
  policy of its kind in this package after [ADR-0017](0017-cmr-staged-file-supersession.md)'s
  supersede-staged-files rule, and is available as a template for any future local-cache-with-a-
  canonical-upstream design.
