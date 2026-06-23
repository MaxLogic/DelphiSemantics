# ADR-0001: DAK and DelphiSemantics Migration Boundary

Status: Accepted

Date: 2026-05-15

## Context

DAK started as both a command-line toolset and the owner of project metadata,
symbol indexing, resolver behavior, and remove-with rewrite planning. That
coupling made the remove-with migration fragile because semantic behavior was
split across DAK command code and reusable semantic code.

DelphiSemantics now exists as the reusable project-scoped semantic layer for DAK
and later Delphi tools. The migration needs a stable boundary so DAK can keep
its command behavior while all generic semantic work moves to one library.

## Decision

DelphiSemantics owns reusable semantic behavior:

- project metadata and compiler context resolution for `.dproj`, `.dpr`,
  `.optset`, defines, unit search paths, unit scopes, aliases, library paths,
  and RTL source profiles
- source loading, preprocessing, include graph tracking, and inactive
  conditional handling
- semantic unit models, declaration extraction, symbol queries, resolver
  behavior, and with-binding classification
- semantic remove-with planning, primary remove-with API DTOs, compatibility
  final DTOs, and parity helpers used by DAK migration workflows
- cache identity, invalidation, in-memory cache behavior, and optional SQLite
  cache behavior selected by `SqliteCacheFileName`
- optional LSP enrichment boundaries when semantic-model provenance remains
  authoritative by default

DAK owns command-specific orchestration:

- CLI parsing, command dispatch, progress output, JSON/report formatting, and
  user-facing telemetry
- remove-with source rewrite generation, transaction/apply logic, rollback,
  post-removal verification, and command-specific reporting
- build/analyze command orchestration and tool-specific report rendering
- compatibility adapters needed while DAK command code consumes
  DelphiSemantics APIs

Project metadata stays in DelphiSemantics for now. Correct semantic results
depend on the active project context, especially defines, search paths, unit
scopes, aliases, compiler profile, and RTL source availability. Splitting that
into a third `delphi-project-metadata` project now would add coordination cost
without a current consumer that needs metadata without semantic behavior.

## Consequences

- DAK must not rebuild generic resolver, project metadata, cache, or
  preprocessing logic as a competing source of truth.
- DAK may keep thin adapters where command code needs DAK-specific DTOs or
  legacy public unit names.
- Future semantic hardening should add tests and behavior in DelphiSemantics
  first, then update DAK adapters only where orchestration requires it.
- A third metadata-only project remains deferred until another consumer needs
  project metadata without semantic dependencies.

## References

- `spec.md` sections: Goals, Non-Goals, Key Decisions, DAK Migration Manifest.
- `docs/api.md` boundary and cache policy.
- `TASKS.md` migration tasks T-063 through T-074.
