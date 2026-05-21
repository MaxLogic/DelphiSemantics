# Semantic Refactoring Agent Guide

Use project-scoped semantic commands when the task depends on Delphi symbol
identity across units. Text search is still useful for inspection, but it cannot
decide which declaration a reference resolves to.

## Find Usages

Start with `find-usages` before rename, dead-code review, or manual cleanup.

```powershell
Set-Location F:\projects\MaxLogic\DelphiAiKit
bin\DelphiAIKit.exe find-usages --project F:\path\to\App.dproj --symbol TFoo
bin\DelphiAIKit.exe find-usages --project F:\path\to\App.dproj --file F:\path\to\Unit1.pas --line 42 --col 17 --format json
```

Use symbol-position lookup when a name is overloaded, shadowed, or repeated in
multiple units. Treat ambiguous or unresolved results as blockers for automated
refactoring.

## Rename

`rename` is dry-run by default.

```powershell
Set-Location F:\projects\MaxLogic\DelphiAiKit
bin\DelphiAIKit.exe rename --project F:\path\to\App.dproj --symbol TFoo --new-name TBetterFoo --format json
```

Review the edit plan before apply. Only use `--apply` after checking that the
project is writable, backed up by DAK transaction artifacts, and free of known
dynamic reference risks.

```powershell
bin\DelphiAIKit.exe rename --project F:\path\to\App.dproj --symbol TFoo --new-name TBetterFoo --apply --format json
```

Do not apply rename directly to read-only fixtures or external projects. Clone
fixtures to a temp workspace before any apply-mode test.

## Dead-Code Reports

Dead-code findings are review evidence, not automatic deletion proof.

Expected report statuses:

- `definitely-unused`: candidate for manual review.
- `maybe-unused`: conservative warning, do not remove automatically.
- `externally-visible`: keep unless the project boundary is proven closed.
- `blocked`: dynamic or unsupported shape; keep until manually inspected.

Review RTTI, DFM event handlers, published members, exports, message methods,
resourcestrings, initialization/finalization hooks, registration calls, package
boundaries, and external callers before deleting anything.

Removal apply mode is not approved unless the maintainer explicitly approves it
for the current run. Keep report-only behavior as the default.

## Agent Checklist

- Prefer semantic commands over raw grep for declarations, references, rename,
  and dead-code review.
- Run dry-run/report commands first.
- Save JSON output when reviewing large projects.
- Apply only to writable repos or temp clones.
- Rebuild after apply-mode changes.
- Record ambiguous or blocked results as review findings instead of forcing an
  edit.
