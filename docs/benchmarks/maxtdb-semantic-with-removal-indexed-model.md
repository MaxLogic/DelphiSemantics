# maxTdb semantic workflow benchmark baseline

Started: `2026-05-26T21:43:46.7607341+02:00`
Completed: `2026-05-26T21:46:25.3668999+02:00`
DAK: `F:\projects\MaxLogic\DelphiAiKit\bin\DelphiAIKit.exe`
Project: `F:\projects\MaxLogic\DelphiAiKit\tests\fixtures\test-projects\maxTdb\src\maxtdb.dpr`
Machine: `PAWEL3`
DelphiSemantics SHA: `9d32d3c8b6e4aca09ab2cfa200cf6a13de7c45d0`
DAK SHA: `966743bcd8fb34c8954dff9e60dd9fbdc8170613`
Warm target: `10.000` seconds
Cache directory: `F:\projects\MaxLogic\DelphiSemantics\.dak\benchmarks\maxtdb-semantic\with-removal-indexed-model\semantic-cache`

| Feature | Benchmark | Cache mode | Runs | Status | Exit | Median seconds | Target seconds | Target status | Min | Max | Result count | Cache hits | Cache misses | Reference fallbacks |
|---|---|---|---:|---|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|
| with-removal | remove-with-plan-all | cold | 1 | passed | 0 | 150.437 |  |  | 150.437 | 150.437 | 208 |  |  |  |

Planner phase metrics for the cold run:

| Phase | Milliseconds |
|---|---:|
| total | 149806 |
| project model | 431 |
| discovery | 79 |
| symbol inventory | 95760 |
| symbol map bridge | 14299 |
| resolver | 19059 |
| planner | 20174 |
| output serialization | 120 |

Planner counters: project units `1`, parsed units `71`, project problems `3`, with statements `667`, symbols `67887`, classifications `15605`, planned edits `208`, skipped statements `426`.

Notes: all commands are report-only or dry-run; the maxTdb fixture is not modified.
