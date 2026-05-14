# DelphiSemantics

DelphiSemantics is a project-scoped semantic layer for Delphi source analysis.
It sits above `DelphiAST` and provides project-wide symbol indexing, scope
resolution, and lookup data for refactoring tools such as remove-with,
definition search, and reference search.

## Goals

- Parse Delphi units with `DelphiAST`.
- Build a reusable project model over all parsed units.
- Resolve identifiers across routine, type, helper, and project scopes.
- Expose a stable semantic API that multiple tools can reuse.

## Layout

- `lib/DelphiAST` - parser submodule.
- `lib/MaxLogicFoundation` - shared utility submodule.
- `src/` - semantic index and resolver implementation.
- `tests/` - focused regression and fixture tests.

## Smoke Tests

- [maxTdb remove-with smoke](docs/smoke-tests.md#maxtdb-remove-with-smoke)
  documents the clone-based DAK verification command. It must never run apply
  mode against the original read-only fixture.
