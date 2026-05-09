# Changelog

## [Unreleased]

### Added
- Level 3 semantic resolver support for helpers, inheritance, compiler/RTL intrinsics, and indexed source units.
- Level 2 semantic resolver support for aliases, arrays, pointers, indexed/default properties, nested scopes, and ambiguity.
- Level 1 semantic resolver for lexical symbols, unit declarations, direct members, and explicit unsupported outcomes.
- Optional SQLite-backed semantic unit-model cache with persistent reuse and deterministic rebuild diagnostics.
- In-memory semantic unit-model cache with hit/miss/invalidation metrics and source/context/include/version cache keys.
- DAK SymbolMap unit-model fixture coverage, including member signatures, indexed/default properties, visibility, and identifier metadata.
- Source-context lookup and diagnostic candidate extraction migrated from DAK.
- Source loading and unit-model extraction for Delphi semantic analysis, including deterministic Windows-1252 fallback, declaration/member/routine/local/reference extraction, diagnostics, and `with` ranges.
