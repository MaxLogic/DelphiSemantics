# proprietary fixture remove-with planner profile

Date: 2026-05-26

## Benchmark guardrails

| Workflow | Cache | Runs | Median seconds | Count |
|---|---:|---:|---:|---:|
| `remove-with-scan-all` | cold | 3 | 0.710 | 667 |
| `remove-with-scan-all` | warm | 3 | 0.702 | 667 |
| `remove-with-plan-all` | cold | 1 | 220.243 | 208 |

## MaxProfiler result

Profiled command:

```powershell
F:\projects\MaxLogic\DelphiAiKit\bin\DelphiAIKit.exe remove-with --project F:\projects\MaxLogic\DelphiAiKit\tests\fixtures\test-projects\<proprietary-fixture>\src\<fixture>.dpr --all --mode plan --format json
```

The profiled run exited successfully in 383.596s under instrumentation and produced 208 planned edits.

Top self-time methods from `.dak\benchmarks\proprietary-fixture-semantic\with-removal-profile\reports\DelphiAIKit_20260526_193009_DelphiAIKit_report.md`:

| Unit | Method | Calls | Net ms |
|---|---|---:|---:|
| `Dak.RemoveWith.Symbols` | `TRemoveWithSymbolBuilder.AddSymbol` | 80,361 | 95,001 |
| `Dak.RemoveWith.Resolver` | `CanonicalSourceTypeName` | 34,897 | 83,076 |
| `DelphiSemantics.WithBinding` | `ParentRoutineNamesForLine` | 667 | 52,825 |
| `Dak.RemoveWith.Symbols` | `SameLogicalNonRoutineSymbol` | 307,028,879 | 29,451 |
| `Dak.RemoveWith.Planner` | `CanonicalSourceTypeName` | 28,761,490 | 11,769 |
| `Dak.RemoveWith.Resolver` | `FindLexicalParentRoutineName` | 3,306 | 11,216 |
| `Dak.RemoveWith.Planner` | `FindVisibleSelectorTempForMember` | 1,578 | 10,620 |
| `Dak.RemoveWith.Expressions` | `FindLexicalParentRoutineName` | 2,507 | 9,978 |
| `Dak.RemoveWith.Planner` | `PreviousSignificantToken` | 1,564 | 8,038 |
| `DelphiSemantics.WithBinding` | `InventoryOwnerHasOwnMember` | 726 | 7,367 |

## Interpretation

The scan path is already fast. The slow planner path is dominated by in-process repeated scans and canonicalization, not by SQLite cache loading or CLI startup.

Highest-value follow-up slices:

- Add planner phase metrics around inventory build, binding, resolver lookup, rewrite planning, and output serialization.
- Replace symbol inventory dedup scans with hot in-memory dictionary/set indexes.
- Cache canonical source type-name lookups per planner run.
- Cache or index parent-routine lookup by unit/source range.
- Defer smaller token-backtracking improvements until inventory and resolver hotspots are reduced.
