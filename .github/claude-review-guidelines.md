# Claude PR review guidelines

These are the criteria the automated reviewer (`.github/workflows/claude-review.yaml`) uses.
Edit this file to tune the review — it is version-controlled on purpose, the same way the
[ADRs](../docs/adr/) are, so the review standard evolves with the project.

## What this review is (and isn't)

- **Is:** an *advisory*, independent check that a change fits the project's design and
  conventions. The reviewer did not write the code and should read the canon fresh each time.
- **Isn't:** a correctness/test gate. R-CMD-check and pkgdown CI own pass/fail; do not
  re-litigate those here. Never approve or merge — a human makes the final call. Raise
  questions directly in the review when something is ambiguous.

## Read first (the canon)

1. `CLAUDE.md` — conventions + the "global vs local solution" guardrail.
2. `docs/roadmap.md` — the V2 phases and what each is (and isn't) meant to deliver.
3. `docs/adr/` — the accepted architecture decisions.

## Review checklist

1. **Reuse over re-implementation.** Does the change re-implement something that already
   exists (`azure_io()`, `eri_read()`/`eri_write()`, `eri_data_path()`, the DQ/catalog/
   research machinery)? Flag duplication; point at the existing helper.
2. **Global vs local solution.** If the problem is general (other countries/diseases/users
   would hit it), is it solved generally — or is a one-off buried in a single workflow?
3. **ADR alignment.** Does anything contradict an accepted ADR? Common ones:
   - ADR-0002: metadata-store writes must be concurrency-safe (ETag/optimistic), not naive
     read-modify-write.
   - ADR-0003: approver/actor identity comes from the verified token, not a self-declared env var.
   - ADR-0005: pull-then-process; provenance recorded at the pull entry points — analytic
     helpers shouldn't fetch implicitly.
   - ADR-0006: research/analysis code lives in separate repos, **not** in the package source.
   If a change *intentionally* revisits a decision, it should add/supersede an ADR in the
   same PR — flag if it doesn't.
4. **Conventions** (from CLAUDE.md): exported `eri_*` / internal `.eri_*`; `cli::cli_*` for
   user-facing messages; roxygen with `@examples` (live calls in `\dontrun{}`); one domain
   per file in `R/`; `NAMESPACE`/`man/` regenerated when exports/roxygen change.
5. **User-first.** Users are Data Analysts and Epidemiologists, not developers — is the
   public surface clear, documented, and hard to misuse?
6. **Docs in sync.** If the change alters the plan or a decision, are `docs/roadmap.md` /
   the ADRs updated in the same PR?

## How to respond

Post one PR review. Use inline comments where you can point at a specific line. Request
changes only for clear violations; otherwise comment. Keep it concise and cite the specific
doc/section (e.g. "ADR-0006") so the maintainer can act quickly.
