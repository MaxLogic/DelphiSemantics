# Migration Gate

Run the final migration gate from PowerShell:

```powershell
Set-Location F:\projects\MaxLogic\DelphiSemantics
.\scripts\run-migration-gate.ps1
```

Or use the repo-root Windows wrapper:

```bat
run-migration-gate.bat --skip-build
```

The gate runs, in order:

1. DelphiSemantics test build.
2. DelphiSemantics DUnitX suite: `tests\bin\delphiSemanticsTests.exe`.
3. DelphiAIKit test build.
4. DelphiAIKit remove-with gate profile, discovered from `TRemoveWith*Tests`
   fixtures and run sequentially.
5. DelphiAIKit CLI build.
6. A cloned maxTdb smoke using `remove-with --mode apply`.

The final summary prints per-phase seconds and a sorted
`Dominant migration gate phases` table so the current bottleneck is explicit.

The default DAK RemoveWith proof uses the `Gate` profile to reduce wall-clock
time while keeping DUnitX execution sequential. The profile excludes
`TRemoveWithProprietaryProjectTests` because the cloned maxTdb smoke covers that
path immediately afterward. Use `--dak-test-profile Full` to include every DAK
RemoveWith fixture in the gate.

Do not manually parallelize the DelphiAIKit remove-with test invocation by
splitting DUnitX filters across multiple `DelphiAIKit.Tests.exe` processes.
Earlier parallel runs caused runtime `217` failures and file-lock errors with
shared outputs, and later attempts still failed even when each process received
an isolated `DAK_TEST_OUTPUT_ROOT`. The failures point to additional shared
state or non-interactive codepage sensitivity, so sequential execution is the
safe default.

The maxTdb smoke never edits the original fixture. By default it copies
`F:\projects\MaxLogic\DelphiAiKit\tests\fixtures\test-projects\maxTdb` to a
unique run-scoped directory under `%TEMP%\delphi-semantics-migration-gate\` and
writes plan/apply JSON reports plus `migration-gate-manifest.json` there. The
manifest records DelphiSemantics and DAK branch, commit, and dirty-state
provenance for the run, plus each proof step's working directory, command,
exit code, elapsed seconds, and stdout/stderr artifact paths.

The gate fails on dirty DelphiSemantics or DAK worktrees by default. Use
`-AllowDirty` only when intentionally collecting local proof before a commit;
the manifest records that opt-out.

When `-WorkRoot` is supplied explicitly, the gate writes directly under that
directory and holds `migration-gate.lock` there for the run. A second gate using
the same explicit root fails instead of racing clone/report cleanup.

Use `-SkipBuild` only when the projects have already been rebuilt and we want a
faster local verification pass.

Wrapper options:

- `--skip-build` maps to `-SkipBuild`.
- `--allow-dirty` maps to `-AllowDirty`.
- `--dak-root <path>` maps to `-DakRoot`.
- `--work-root <path>` maps to `-WorkRoot`.
- `--dak-test-shards <count>` maps to `-DakTestShards`. Only `1` is currently safe.
- `--dak-test-profile <Gate|Full>` maps to `-DakTestProfile`. The default is `Gate`.
- `--delphi-semantics-root <path>` maps to `-DelphiSemanticsRoot`.
