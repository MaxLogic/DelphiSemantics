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

## Dead-Code Reports

Dead-code findings are review evidence, not proof that deleting code is always
behavior-preserving. Treat `definitely-unused`, `maybe-unused`,
`externally-visible`, and `blocked` results as an inspection report first,
especially around RTTI, DFM event handlers, exports, message methods,
initialization/finalization hooks, registration calls, package boundaries, and
external callers.

## Semantic Refactoring

Use DAK for project-scoped semantic refactoring commands. Start with dry-run
commands and review the report before allowing any source rewrite.

```powershell
Set-Location F:\projects\MaxLogic\DelphiAiKit
bin\DelphiAIKit.exe find-usages --project F:\path\to\App.dproj --symbol TFoo
bin\DelphiAIKit.exe rename --project F:\path\to\App.dproj --symbol TFoo --new-name TBetterFoo --format json
```

`rename` defaults to dry-run. Use `--apply` only after the edit plan is reviewed
and only on a writable project or temp clone. Dead-code findings remain review
evidence: do not treat `definitely-unused` as automatic deletion approval, and
do not add removal apply mode without explicit maintainer approval.

### Compile Gate For Refactorings

Semantic refactoring assumes the project starts from parseable, compileable
source. Broken code can prevent DelphiSemantics from building a complete and
trustworthy project model.

Any source-changing consumer of DelphiSemantics should compile the project
before applying edits, refuse apply mode when the baseline compile fails,
compile again after edits, and roll back the edit transaction if the post-edit
compile fails. DAK is the current orchestration layer for that gate. Dry-run
analysis may still be useful for investigation, but it is not an apply-safe
proof unless the compile gate has passed.

Agent workflow guidance lives in
[`docs/semantic-refactoring-agents.md`](docs/semantic-refactoring-agents.md).

## Layout

- `lib/DelphiAST` - parser submodule.
- `lib/MaxLogicFoundation` - shared utility submodule.
- `src/` - semantic index and resolver implementation.
- `tests/` - focused regression and fixture tests.

## Smoke Tests

- [maxTdb remove-with smoke](docs/smoke-tests.md#maxtdb-remove-with-smoke)
  documents the clone-based DAK verification command. It must never run apply
  mode against the original read-only fixture.
- [migration gate](docs/migration-gate.md) runs DelphiSemantics tests, DAK
  remove-with tests, and the cloned maxTdb smoke in the migration proof order.
  Use `run-migration-gate.bat --skip-build` for the repo-root Windows wrapper.
