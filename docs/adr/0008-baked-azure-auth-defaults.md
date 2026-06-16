# ADR-0008 — Baked-in Azure auth defaults; interactive AAD auth as the zero-config default

- **Status:** Accepted
- **Date:** 2026-06-16

## Context

`get_azure_storage_connection()` (`R/dal.R`) read `app_id`, `tenant_id`, and `resource_endpoint`
from `ERIFUNCTIONS_*` environment variables with **no defaults**. A new analyst or epidemiologist
therefore had to obtain and set four values before any package call worked, and an empty `app_id`
failed with the opaque `AADSTS900144 (missing client_id)`. This surfaced immediately when driving
the `dr_irs` Epi research workflow: a domain expert (not a developer) cannot get past login.

These values are **not secrets**: a tenant GUID and a storage-account endpoint are discovery
identifiers, and the application/client id is a public client. The only true secret is the
service-principal credential (`ERIFUNCTIONS_SP_CLIENT_SECRET`), used solely for scripted/automated
runs. The roadmap schedules interactive browser auth for Phase 2 ("confirmation of the Azure AD app
registration / RBAC so all DAs/Epis can use interactive browser auth"); an Epi cannot use the
package without it, so the interactive-auth *precondition* is brought forward here. This ADR records
only that enablement — token-derived approver identity (ADR-0003) is still future work.

## Decision

Ship working defaults so interactive (browser) auth needs **zero per-user configuration**, all
overridable via the existing `ERIFUNCTIONS_*` env vars:

- `app_id` defaults to Microsoft's first-party **Azure CLI public client**
  (`04b07795-8ddb-461a-bbee-02f9e1bf7b46`) — pre-consented in every tenant and able to obtain
  delegated tokens for **both** Azure Storage (`https://storage.azure.com/`) and Microsoft Graph
  (SharePoint/Teams), so one sign-in covers every resource the package touches.
- `tenant_id` defaults to the ERI Entra tenant; `resource_endpoint` defaults to the `eridev` ADLS
  Gen2 endpoint (the canonical store the team works in).
- The **service-principal secret stays env-only** — no credential is ever baked into the package.

Authorization remains enforced by **Azure RBAC** on the storage account: a user who lacks access
gets a 403, surfaced by the package, rather than the package gating access itself.

We chose the Azure CLI public client over registering a dedicated ERI app now because it works with
no tenant-admin setup and is already pre-consented. A dedicated ERI app registration (app-specific
consent, conditional-access scoping, branding) remains a possible future change; if adopted it is a
one-line default swap plus this ADR's revision.

## Consequences

- **Easier:** an Epi installs the package and signs in with their normal Carter Center Microsoft
  account — nothing in `.Renviron` is required. Removes the single biggest onboarding wall.
- **Harder / accepted:** the tenant id and `eridev` endpoint are now visible in a public repo. They
  are non-sensitive (RBAC-gated), so this is acceptable; revisit only if the security posture
  changes. The default also ties the package to a Microsoft-owned client id until/unless a dedicated
  ERI app registration replaces it.
- **Not doing:** baking any secret into the package; implementing token-derived identity (ADR-0003,
  still Phase 2). Per-user RBAC on the storage account is an Azure-admin prerequisite, not a package
  change.
