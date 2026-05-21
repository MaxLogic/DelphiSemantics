# Changelog

## [Unreleased]

### Added
- Optional semantic search facade with syntax-only match labeling, resolved
  symbol filtering, and declaration kind/owner/scope/unit filters.
- Dead-code removal edit planner with profile-gated dry-run text edits and
  blockers for audit mode or unsupported deletion shapes.
- Conservative dead-code report API with audit safety profile, blocked-risk
  diagnostics, and tests for dynamic Delphi risk shapes.
- Project rename edit planner API with dry-run edit ranges, API facade support,
  project-source guarding, collision blocking, and cross-unit case-insensitive coverage.
- Project symbol/reference index API with per-snapshot symbol IDs plus conservative
  resolved, ambiguous, and unresolved reference diagnostics.
- Project find-usages API for source-position and symbol-name queries, including
  ambiguous-target blocking and section-aware usage rows.
- Repo-root `run-migration-gate.bat` wrapper for the DelphiSemantics/DAK/maxTdb migration gate,
  with documented sequential DAK RemoveWith execution and `DAK_TEST_OUTPUT_ROOT` isolation guidance.
- Migration gate script and documentation for the DelphiSemantics suite, DAK remove-with suite,
  and cloned maxTdb apply smoke.
- Stable `DelphiSemantics.Api` facade for project-context loading, cache-backed unit indexing,
  with-binding inventory, cache metrics, and DAK integration.
- DAK obsolete GlobalVars and RemoveWith parser snapshots are backed up under `_obselete` and excluded from normal compilation.
- DAK GlobalVars now consumes the DelphiSemantics global analysis API and rebuilds legacy cache schema entries through the new analyzer.
- Global variable semantic analysis API for reusable declarations, usages, ambiguity reporting, access classification, local shadowing, and semantic filters.
- DAK semantic consumers now use DelphiSemantics adapters for remove-with bindings, SymbolMap extraction, dependency graphs, and global-vars declaration extraction.
- Remove-with inventory now exposes DAK planner-compatible symbol facts and source-owner expansion for DAK migration.
- DAK project/test integration reference to DelphiSemantics with a compile-time wrapper proof.
- LSP boundary helpers for lifecycle state, URI/path normalization, location links, hover payloads, position conversion, hierarchical symbol flattening/filtering, explicit error results, and LSP provenance.
- Dependency graph API with project/external/unresolved nodes, interface/implementation edges, cycle components, hotspot ranking, and exact focus neighborhoods.
- With-binder planning metadata for binding status, skip reasons, lookup-source counts, intrinsic/external call classification, scoped declarations, and unresolved reason codes.
- Remove-with resolver inventory coverage for enum values, typed constants, implementation globals, interface inheritance, overloaded members, and nested-routine `with` selector scopes.
- With-discovery model coverage for selector counts, body ranges, nesting depth, scoped declarations, UTF-8 BOM coordinates, and inactive conditional branches.
- Symbol query API and DAK SymbolMap query coverage for definition lookup, source-position lookup, member/intrinsic/RTL search, token references, and cache/profile status.
- Cache/profile migration coverage for compiler-profile cache keys, equivalent-context reuse, intrinsic resolver rows, stale SQLite profile repair, and cached source-available RTL indexing.
- Optional LSP enrichment boundary with explicit opt-in and provenance for `lsp` and `semantic-model` results.
- Semantic with-binder API for selector type binding and member/lexical/external/ambiguous/unresolved/unsupported reference classification.
- Level 3 semantic resolver support for helpers, inheritance, compiler/RTL intrinsics, and indexed source units.
- Level 2 semantic resolver support for aliases, arrays, pointers, indexed/default properties, nested scopes, and ambiguity.
- Level 1 semantic resolver for lexical symbols, unit declarations, direct members, and explicit unsupported outcomes.
- Optional SQLite-backed semantic unit-model cache with persistent reuse and deterministic rebuild diagnostics.
- In-memory semantic unit-model cache with hit/miss/invalidation metrics and source/context/include/version cache keys.
- DAK SymbolMap unit-model fixture coverage, including member signatures, indexed/default properties, visibility, and identifier metadata.
- Source-context lookup and diagnostic candidate extraction migrated from DAK.
- Source loading and unit-model extraction for Delphi semantic analysis, including deterministic Windows-1252 fallback, declaration/member/routine/local/reference extraction, diagnostics, and `with` ranges.

### Changed
- Migration gate now reports dominant runtime phases explicitly, uses a sequential DAK RemoveWith gate
  profile to avoid duplicate maxTdb/proprietary coverage, and hard-blocks unsafe parallel DAK shards.
- DAK RemoveWith now rewrites safe scoped-declaration `with` bodies while preserving inline locals,
  exception variables, and generic type names; cloned maxTdb apply now verifies at 505 removals with
  zero `scoped-declaration-in-with-body` and zero `symbol-not-found` skips.
- DAK RemoveWith tests can isolate process temp/output roots with `DAK_TEST_OUTPUT_ROOT` for explicit
  parallel-filter proof runs while the migration gate remains sequential by default.
- RTL source-root compiler profiles now use a fast DelphiSemantics-owned interface extractor
  that preserves routines, types, members, enum values, constants, variables, and resourcestrings
  without invoking the full unit-model cache/parser path.
- Semantic cache identity now includes source timestamps in addition to content hashes, and
  the public API selects the SQLite cache when `SqliteCacheFileName` is configured.
