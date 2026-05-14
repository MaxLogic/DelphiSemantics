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
- `TDelphiSemanticUnitIndex` returns DTO records only: model, bindings,
  inventory, cache metrics, and cache diagnostics.

## Cache Policy

The default cache is in-memory. Set
`TDelphiSemanticApiOptions.Cache.SqliteCacheFileName` to a non-empty path when a
caller wants persistent SQLite-backed reuse.

## Boundary

DelphiSemantics owns project metadata, source loading, preprocessing, cache
identity, semantic unit models, symbol queries, resolver behavior, and
with-binding classification. DAK keeps CLI orchestration, planning, source
rewrite, apply, rollback, verification, and user-facing telemetry.
