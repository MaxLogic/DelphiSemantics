# DelphiSemantics API

`DelphiSemantics.Api` is the small facade intended for DAK and later tool
integrations. It keeps callers on one stable unit for common project and
semantic-index workflows while the lower-level units remain available for
focused tests and internal implementation.

## Stable Facade

- `TDelphiSemanticApiOptions` configures project loading, source loading,
  project context, cache behavior, and later opt-in LSP enrichment.
- `TDelphiSemanticApi.LoadProjectContext` loads `.dproj` or `.dpr` metadata
  through the project-context implementation.
- `TDelphiSemanticApi.BuildUnitIndex` builds or loads one cache-backed unit
  model and returns with-binding and remove-with inventory DTOs.
- `TDelphiSemanticApi.FindUsagesByName` and
  `TDelphiSemanticApi.FindUsagesAtPosition` return project-scoped usage DTOs
  from a caller-supplied symbol query context.
- `TDelphiSemanticApi.PlanRename` returns dry-run text edits for a
  project-scoped rename; callers own file transactions, backups, rollback,
  and user-facing apply policy.
- `TDelphiSemanticUnitIndex` returns DTO records only: model, bindings,
  inventory, cache metrics, and cache diagnostics.

## Cache Policy

The default cache is in-memory. Set
`TDelphiSemanticApiOptions.Cache.SqliteCacheFileName` to a non-empty path when a
caller wants persistent SQLite-backed reuse.

## LSP Enrichment

`UseLspEnrichment` is an explicit opt-in boundary, but LSP enrichment is
currently unsupported in this DelphiSemantics build. Setting the flag returns
the warning diagnostic `lsp.enrichment.unsupported`; leaving it false keeps the
semantic-model-only behavior and emits no LSP diagnostic. The reusable LSP unit
still owns settings JSON construction and result normalization helpers for a
later adapter, but no production path performs enrichment today.

## Remove-With Planning

`TDelphiSemanticRemoveWithApi.PlanRemoveWith` is the stable primary planning
route. It is generic best-effort planning for any Delphi project: every
discovered `with` statement is represented in the result as either planned or
skipped. The facade-owned DTO includes operation status, diagnostics, required
verification, a complete statement ledger, candidate edits, and skipped
statements. `Statements` has one row for every discovered `with` statement with
`planned` or `skipped` status, stable reason fields, source range, semantic ID,
and `CoveredByStatementId` when a nested statement is rewritten as part of a
parent replacement. `SkippedStatements` mirrors the skipped ledger rows for
report consumers that only need unresolved statements. It does not expose final
statement DTOs, rewrite recipes, parity helpers, or planner internals.

Specific projects and fixtures can be used as dogfood evidence, but they must
not become production profiles, filename/line behavior selectors, or fixed-count
correctness gates for the planner.

`TDelphiSemanticRemoveWithCompatibilityApi.BuildProjectWithBindingFactsResult`
is the failure-aware fact-build entry point. It returns `Success`, structured
diagnostics, facts, and metrics so production callers can decide how to handle
project/session failures.

`TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWith` returns the full
internal planner record for DAK parity and migration workflows that still need
final statement DTOs or rewrite recipe data.

The legacy `BuildProjectWithBindingFacts` overloads are compatibility-only.
They raise an exception containing the diagnostic codes when fact building
fails, instead of returning default facts that could be mistaken for a valid
empty result. New callers should use `BuildProjectWithBindingFactsResult`.

## Boundary

DelphiSemantics owns project metadata, source loading, preprocessing, cache
identity, semantic unit models, symbol queries, usage resolution, rename edit
planning, resolver behavior, and with-binding classification. DAK keeps CLI
orchestration, source rewrite, apply, rollback, verification, and user-facing
telemetry.
