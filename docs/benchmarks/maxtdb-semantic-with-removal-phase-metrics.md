# maxTdb semantic workflow benchmark baseline

Started: `2026-05-26T21:24:14.7570930+02:00`
Completed: `2026-05-26T21:27:55.2438515+02:00`
DAK: `F:\projects\MaxLogic\DelphiAiKit\bin\DelphiAIKit.exe`
Project: `F:\projects\MaxLogic\DelphiAiKit\tests\fixtures\test-projects\maxTdb\src\maxtdb.dpr`
Machine: `PAWEL3`
DelphiSemantics SHA: `8f2db40822f980b21cef91225ed45233afd3109c`
DAK SHA: `50e75c2b4ff26870c23247fbc16bc1c99fca0436`
Warm target: `10.000` seconds
Cache directory: `F:\projects\MaxLogic\DelphiSemantics\.dak\benchmarks\maxtdb-semantic\with-removal-phase-metrics\semantic-cache`

| Feature | Benchmark | Cache mode | Runs | Status | Exit | Median seconds | Target seconds | Target status | Min | Max | Result count | Cache hits | Cache misses | Reference fallbacks |
|---|---|---|---:|---|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|
| with-removal | remove-with-plan-all | cold | 1 | passed | 0 | 212.867 |  |  | 212.867 | 212.867 | 208 |  |  |  |

Planner phase metrics for the cold run:

| Phase | Milliseconds |
|---|---:|
| total | 212330 |
| project model | 410 |
| discovery | 77 |
| symbol inventory | 92509 |
| symbol map bridge | 13147 |
| resolver | 88965 |
| planner | 17219 |
| output serialization | 109 |

Planner counters: project units `1`, parsed units `71`, project problems `3`, with statements `667`, symbols `67887`, classifications `15605`, planned edits `208`, skipped statements `426`.

Notes: all commands are report-only or dry-run; the maxTdb fixture is not modified.
