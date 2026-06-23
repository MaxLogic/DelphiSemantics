# proprietary fixture semantic workflow benchmark baseline

Started: `2026-05-22T22:01:02.0880861+02:00`
Completed: `2026-05-22T22:39:08.3866608+02:00`
DAK: `F:\projects\MaxLogic\DelphiAiKit\bin\DelphiAIKit.exe`
Project: `F:\projects\MaxLogic\DelphiAiKit\tests\fixtures\test-projects\<proprietary-fixture>\src\<fixture>.dpr`

| Feature | Benchmark | Exit | Seconds | Result count |
|---|---|---:|---:|---:|
| with-removal | remove-with-scan-all | 0 | 0.891 | 667 |
| with-removal | remove-with-plan-all | 0 | 410.906 | 208 |
| dead-code-detection | dead-code-legacy-static | 0 | 436.509 | 3875 |
| find-usages | find-usages-allfiles | 0 | 270.496 | 4 |
| find-usages | find-usages-sourcevarrecptr | 0 | 268.301 | 5 |
| rename | rename-dry-run-allfiles | 0 | 456.400 | 4 |
| rename | rename-dry-run-sourcevarrecptr | 0 | 440.672 | 5 |

Notes: all commands are report-only or dry-run; the proprietary fixture is not modified.
