# proprietary fixture semantic workflow benchmark baseline

Started: `2026-05-26T21:49:07.8345473+02:00`
Completed: `2026-05-26T21:51:41.1312373+02:00`
DAK: `F:\projects\MaxLogic\DelphiAiKit\bin\DelphiAIKit.exe`
Project: `F:\projects\MaxLogic\DelphiAiKit\tests\fixtures\test-projects\<proprietary-fixture>\src\<fixture>.dpr`
Machine: `PAWEL3`
DelphiSemantics SHA: `65532b4905ca0c94d89ce179b98b5022d81d87bc`
DAK SHA: `d41c95867f6ba7bce5e5418bd1a169af257de47c`
Warm target: `10.000` seconds
Cache directory: `F:\projects\MaxLogic\DelphiSemantics\.dak\benchmarks\proprietary-fixture-semantic\with-removal-planner-cache\semantic-cache`

| Feature | Benchmark | Cache mode | Runs | Status | Exit | Median seconds | Target seconds | Target status | Min | Max | Result count | Cache hits | Cache misses | Reference fallbacks |
|---|---|---|---:|---|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|
| with-removal | remove-with-plan-all | cold | 1 | passed | 0 | 142.738 |  |  | 142.738 | 142.738 | 208 |  |  |  |

Planner phase metrics for the cold run:

| Phase | Milliseconds |
|---|---:|
| total | 142086 |
| project model | 428 |
| discovery | 77 |
| symbol inventory | 93798 |
| symbol map bridge | 14711 |
| resolver | 24048 |
| planner | 9021 |
| output serialization | 118 |

Planner counters: project units `1`, parsed units `71`, project problems `3`, with statements `667`, symbols `67887`, classifications `15605`, planned edits `208`, skipped statements `426`.

Notes: all commands are report-only or dry-run; the proprietary fixture is not modified.
