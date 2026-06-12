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

`UseLspEnrichment` is an explicit opt-in boundary. Until a DelphiSemantics-owned
LSP enrichment adapter is wired into the facade, project-context loading returns
the warning diagnostic `lsp.enrichment.not-implemented` when the flag is set.
Leaving the flag false keeps the semantic-model-only behavior and emits no LSP
diagnostic.

## Boundary

DelphiSemantics owns project metadata, source loading, preprocessing, cache
identity, semantic unit models, symbol queries, usage resolution, rename edit
planning, resolver behavior, and with-binding classification. DAK keeps CLI
orchestration, source rewrite, apply, rollback, verification, and user-facing
telemetry.
