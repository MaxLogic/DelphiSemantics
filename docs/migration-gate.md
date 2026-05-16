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
4. DelphiAIKit remove-with suite:
   `tests\DelphiAIKit.Tests.exe --hidebanner --consolemode:quiet -r:Test.RemoveWith`.
5. DelphiAIKit CLI build.
6. A cloned maxTdb smoke using `remove-with --mode apply`.

Do not parallelize the DelphiAIKit remove-with test invocation by splitting
DUnitX filters across multiple `DelphiAIKit.Tests.exe` processes. The DAK test
harness uses shared output/temp locations, and parallel filter runs have caused
runtime `217` failures and file-lock errors.
If a future proof intentionally runs DAK RemoveWith filters in parallel, set a
unique `DAK_TEST_OUTPUT_ROOT` for each `DelphiAIKit.Tests.exe` process first.

The maxTdb smoke never edits the original fixture. It copies
`F:\projects\MaxLogic\DelphiAiKit\tests\fixtures\test-projects\maxTdb` to
`%TEMP%\delphi-semantics-migration-gate\maxTdb` and writes the JSON report to
`%TEMP%\delphi-semantics-migration-gate\maxTdb-remove-with.json`.

Use `-SkipBuild` only when the projects have already been rebuilt and we want a
faster local verification pass.

Wrapper options:

- `--skip-build` maps to `-SkipBuild`.
- `--dak-root <path>` maps to `-DakRoot`.
- `--work-root <path>` maps to `-WorkRoot`.
- `--delphi-semantics-root <path>` maps to `-DelphiSemanticsRoot`.
