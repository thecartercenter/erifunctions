# ADR-0003 — Approver identity from the auth token

- **Status:** Accepted
- **Date:** 2026-06-05

## Context

`eri_approve()` is the human gate that promotes staged data to `processed/`. Its audit value
depends entirely on the recorded identity of the approver being trustworthy.

Today that identity comes from `ERI_ANALYST_ID` (`R/dal.R`), a value the analyst sets in
their own `.Renviron`. It is self-declared and therefore spoofable: anyone can set it to any
string, including someone else's name. The same env var is used across the operation logs
and the catalog `registered_by` field.

## Decision

Derive the authoritative actor identity from the **verified Azure AD token** used for the
connection. Add an internal `.eri_token_identity()` that extracts the verified claim
(`upn` / `preferred_username`) from the AzureAuth token, and use it as `approved_by` in the
approval log and catalog registration.

`ERI_ANALYST_ID` is retained only as a **display fallback** for non-interactive runs under a
service principal (which has no human user claim).

Implemented in **Phase 2**.

## Consequences

- **Easier:** the approval record and access logs reflect who actually authenticated, making
  the gate a real control rather than a convention.
- **Harder:** requires every DA/Epi to authenticate interactively with their own Azure AD
  identity and have RBAC on the storage account (tracked as a Phase 2 input). Service-principal
  runs must explicitly carry an actor label.
- **Not doing:** building a separate user-management system; we lean on Azure AD as the
  identity provider.
