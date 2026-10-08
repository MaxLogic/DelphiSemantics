# DelphiSemantics

DelphiSemantics uses `DelphiAST` to index Delphi symbols and resolve names
across a project. Refactoring tools use its scope and lookup data for
remove-with, definition search, and reference search.

## Goals

- Parse Delphi units with `DelphiAST`.
- Build a reusable project model over all parsed units.
- Resolve identifiers across routine, type, helper, and project scopes.
- Expose a stable semantic API that multiple tools can reuse.

## Dead-Code Reports

Review dead-code findings before deleting code. The `definitely-unused`,
`maybe-unused`, `externally-visible`, and `blocked` classifications do not
guarantee that removal preserves behavior, especially around RTTI, DFM event
handlers, exports, message methods,
initialization/finalization hooks, registration calls, package boundaries, and
external callers.

## Semantic Refactoring

Use DAK for project-scoped semantic refactoring commands. Start with dry-run
commands and review the report before applying source changes.

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

Semantic refactoring requires source that parses and compiles. Broken code
can leave the project model incomplete or unreliable.

Any source-changing consumer of DelphiSemantics should compile the project
before applying edits, refuse apply mode when the baseline compile fails,
compile again after edits, and roll back the edit transaction if the post-edit
compile fails. DAK is the current orchestration layer for that gate. Dry-run
analysis can still help investigate broken code. The compile gate must pass
before applying edits.

Agent workflow guidance lives in
[`docs/semantic-refactoring-agents.md`](docs/semantic-refactoring-agents.md).

## API Boundary

The in-progress read-only event comparison APIs and their limitations are
described in [Consistency facts](docs/consistency-facts.md).
The initial class declaration/implementation comparison API and its unfinished
edit-planning boundaries are described in [Signature alignment](docs/signature-alignment.md).

DelphiSemantics owns project/compiler context, semantic models, resolver
behavior, with-binding classification, semantic remove-with planning, the
primary remove-with DTO, and compatibility final DTOs. DAK owns command
orchestration, source rewrite, apply/rollback, verification, reporting, and
operator-facing telemetry.

Remove-with planning attempts rewrites in any Delphi project. It reports each
discovered `with` statement as planned or skipped, with stable reason fields. Project
fixtures provide integration evidence; they do not define production modes or
fixed-count contracts.

## Layout

- `lib/DelphiAST` - parser submodule.
- `lib/MaxLogicFoundation` - shared utility submodule.
- `src/` - semantic index and resolver implementation.
- `tests/` - focused regression and fixture tests.

## Smoke Tests

Build the Win64 Debug test runner directly through DAK from this repository root:

```powershell
& 'F:\projects\MaxLogic\DelphiAiKit\bin\DelphiAIKit.exe' build --project tests\delphiSemanticsTests.dproj --delphi 23.0 --platform Win64 --config Debug --ai
```

The migration gate uses the same native build command with explicit platforms
and private per-run output directories for its three projects.

The Windows source-context cache tests use precise file timestamps and real
symbolic links. Their test filesystem must retain 100 ns timestamp differences;
link creation requires Windows Developer Mode or the symbolic-link privilege.

The separate `MaxTdbProof` category directly selects the sibling DAK
`tests/fixtures/test-projects/maxTdb` fixture; it does not read
`DAK_MAXTDB_FIXTURE`. Its Foundation, JEDI and FastMM search paths must use the
pinned DAK-local copies. Search paths contribute to semantic identities, so
fixture relocation requires explicit identity review while preserving body,
range, replacement and ordering assertions. The DAK
[performance report](../DelphiAiKit/docs/remove-with-performance.md) records the
current isolation and retained-producer comparison.

- [proprietary fixture remove-with smoke](docs/smoke-tests.md#proprietary-fixture-remove-with-smoke)
  documents the clone-based DAK verification command. It must never run apply
  mode against the original read-only fixture.
- [migration gate](docs/migration-gate.md) runs DelphiSemantics tests, DAK
  remove-with tests, and the cloned proprietary fixture smoke in the migration proof order.
  Use `run-migration-gate.bat --skip-build` for the repo-root Windows wrapper.
