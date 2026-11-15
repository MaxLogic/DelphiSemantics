# DelphiSemantics

DelphiSemantics uses `DelphiAST` to index Delphi symbols and resolve names
across a project. Refactoring tools use its scope and lookup data for
remove-with, definition search, and reference search.

Remove-with builds core semantic models without runtime-name facts. Rename and
runtime-name analysis request a separate, facts-bearing cache capability; a
core-only row never satisfies that request. Missing facts are rebuilt or produce
`NAME_FLOW_FACTS_REQUIRED`, never an empty consumer result. Unit cache epoch
81407 invalidates the previous rows; parser/proof identities are unchanged.

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

## SDK declaration absence

SDK declaration absence hash-pins the SDK source tree and compiler executable.
SDK DCUs are trusted by location inside the certified installation, restricted
to the selected platform's default-language `lib/<platform>/{debug,release}`
folders and a unique paired source. DCU bytes are not checked against a reviewed
hash manifest. The first selected DCU hash detects changes during the command;
it does not authenticate pre-existing DCU bytes or the non-selected sibling.
Project-listed candidates and additional source copies deny the absence proof.

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

Fixtures allocate per-run roots as `tests\bin\<name>-temp\run-<PID>-<GUID>`. Each test
process deletes its own roots when it exits. At startup it also removes roots whose
owner process has exited; a live owner's root is never touched. To keep the roots of a failed
run for inspection, set `DS_KEEP_TEST_TEMP=1`. The roots of that failed run then get a
`.keep` marker file, and later sweeps skip any root that has one. Delete a kept root by
hand when you no longer need it.
Legacy `run-<GUID>` roots that carry no PID are never swept; remove them by hand.

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

WITH binding and planning default to 1,000,000 admitted inventory records across
the project and expansion. Exceeding that limit raises a native
`WITH_INVENTORY_BUDGET_EXCEEDED` refusal naming the limit, the record at which
it was exceeded, and incomplete coverage. The project total is not measured;
the threshold crossing does not identify a sufficient override;
API remove-with results are blocked and contain no partial plan. Set the
remove-with request option `RecordLimit` (or session `WithInventoryRecordLimit`)
to a positive count to override it; zero selects the default. Cache replay obeys
the current request budget without changing cache identity or storage formats.
Memory grows with the override. The default uses a 4 KiB per-record planning
estimate (3.81 GiB): a measured 576-byte Win64 record plus resident copies, list
capacity, strings, keys and indexes. This is not a hard byte cap; long strings
and the rest of the project require additional memory. DAK exposes the override
as `--with-inventory-record-limit <positive N>`.

Name-flow facts use per-unit exact string pooling and compressed binary storage.
The raw encoding is bounded at 256 MiB; a larger payload refuses with
`NAME_FLOW_FACTS_STORAGE_LIMIT` instead of returning partial facts. SQLite
model or snapshot text entries above 256 Mi characters are not persisted. Their
complete in-memory facts remain usable, and later commands recompute them.
Older semantic caches rebuild after this storage change.

Production inventories store class members once per provider rather than
projecting `current-class-member` copies for every routine. The virtual lookup
reconstructs the same ordered records on request, including the existing
project-wide routine-name matches and same-unit/file inheritance and helper
rules. Locals, parameters and routine entries remain eager; zero-WITH units
remain providers. The explicit full-inventory builder remains a budgeted legacy
API and test oracle.

The budget counts stored records, including compatibility additions and
expansion, and remains a safety net. On the prepared 60-model MaxTdb Win32
capture, the compact admission peak is 28,130 records (2.813% of the default);
28,129 refuses. The earlier eager DAK-491 capture peaked at 54,876 records.
These are admission peaks for their recorded inputs, not final-array counts
or universal project totals. The KFZ 1,135-model capture admits 658,868 before
expansion and stores 590,078 afterwards; full-command capture proofs still
require separate time and memory measurement.

Compact payloads use `combined-remove-with-facts-v2`,
`project-session-remove-with-facts-v107` and `project-session-snapshot-v202`.
Older semantic caches rebuild. No physical SQLite schema migration is needed.
Virtual lookups are rebuilt from validated models on load; missing model
context refuses a virtual query with `CURRENT_CLASS_CONTEXT_UNAVAILABLE`
instead of claiming member absence.

For streamed WITH planning-symbol rows, `SnapshotSqlReadMilliseconds` now times
query `Open` only. Subsequent row fetches run in the iteration/decoding loop
outside that counter; this counter no longer includes a preceding `FetchAll`
for these rows. Other queries retain their existing timing boundaries. Compare
this metric across versions only with that change in scope accounted for.
