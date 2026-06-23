# DelphiSemantics API

`DelphiSemantics.Api` is the small facade intended for DAK and future tool
integrations. It keeps callers on one stable unit for common project and
semantic-index workflows while the lower-level units remain available for
focused tests and internal implementation.

## Stable Facade

- `TDelphiSemanticApiOptions` configures project loading, source loading,
  project context, cache behavior, and future opt-in LSP enrichment.
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
future adapter, but no production path performs enrichment today.

## Remove-With Compatibility

`TDelphiSemanticRemoveWithApi.PlanRemoveWith` is the stable primary planning
route. It returns a facade-owned plan DTO with operation status, diagnostics,
required verification, candidate edits, and skipped statements. It does not
expose final statement DTOs, rewrite recipes, parity helpers, or planner
internals.

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
