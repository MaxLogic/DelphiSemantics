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
multiple units. Stop automated refactoring when results are ambiguous or
unresolved.

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

Review dead-code findings before deciding whether to delete code.

Expected report statuses:

- `definitely-unused`: candidate for manual review.
- `maybe-unused`: conservative warning, do not remove automatically.
- `externally-visible`: keep unless the project boundary is proven closed.
- `blocked`: dynamic or unsupported shape; keep until manually inspected.

Review RTTI, DFM event handlers, published members, exports, message methods,
resourcestrings, initialization/finalization hooks, registration calls, package
boundaries, and external callers before deleting anything.

Removal apply mode requires explicit maintainer approval for the current run.
Keep report-only behavior as the default.

## Uses-move proof under development

T-628 is incomplete. The uses planner still returns
'uses.move-post-edit-revalidation-required' for move candidates; do not treat
that classification as permission to edit.

The snapshot's context-evidence extension retains the selected main-source path, ordered dependency facts and
the original extracted reference records. Its constructor and getters copy the
arrays, so evidence survives session disposal and caller mutation. These are
inputs to the pending alternate-binding proof, not a declaration that every
Delphi expression has been resolved. Check analysis scope, extraction flags,
diagnostics and unknown bindings before relying on them.

'ResolveSnapshotReferenceTargets' reuses the snapshot builder's resolver with
caller-supplied import lists and reference records. Results follow reference
array order; zero symbol/unit IDs represent unresolved targets. This low-level
entry point resolves simple imported-unit qualifiers and refuses unavailable,
ambiguous, potentially shadowed or unsupported receivers. It does not validate
evidence provenance or certify complete lookup, helper/operator behavior,
arbitrary qualified expressions, or source edits. A caller must
not infer safe movement merely because two partial target arrays match.

'CompareSnapshotImportBindings' compares concrete unit/symbol identities before
and after replacing import lists. It reports preserved bindings, concrete target
changes, or incomplete evidence. A missing snapshot, an empty reference set,
or any unresolved target prevents a complete result; matching unknown targets
never count as preservation. ReferenceCount counts the known pairs examined.
Complete applies only to the supplied reference array, not to project coverage
or edit authorization. The caller still must establish extraction completeness,
source provenance, supported lookup semantics and unchanged initialization order.

The current single-import move candidate now runs this comparison from retained
context evidence. Unknown or changed bindings produce a refusal. The resolver
associates an implicit function Result with its enclosing routine identity.
Successful binding comparison is followed by an explicit dependency traversal from
the captured executable root. Missing or cyclic reachable imports refuse the
candidate. Matching explicit order still produces a blocked candidate until
implicit runtime/package behavior and the remaining semantic checks are complete.

Project-context identity version 3 includes effective package controls and raw
compiler switches: DCC_UsePackage, UsePackages, DCC_EnabledPackages, _UsePackage,
and DCC_AdditionalSwitches. Unknown values or conditions on these inputs remain
semantic diagnostics. Known optional link controls start empty, as in MSBuild;
explicit supplied values remain effective. Raw values are hashed without case folding. Their presence
in context identity prevents reuse across changed settings; it does not certify
package initialization order or interpret arbitrary compiler switches. Context-derived
semantic IDs change with this identity version; regenerate saved plans.
The context-evidence extension also retains these five effective values in
`CompilerLinkProperties`, independently of the session and returned arrays.
Move analysis currently refuses active package flags or `_UsePackage`, unknown
package-enable values, and nonempty raw compiler switches with explicit reasons.
An inactive `DCC_UsePackage` list does not by itself enable runtime packages.
This check only establishes eligibility for the package-free order analysis;
it does not certify implicit runtime order or enable an automatic move.

Snapshot reference indexing preserves global routine ownership separately from
local/parameter ownership. Snapshot cache identity version 10 invalidates older
entries after this correction; the unit-model parser identity is unchanged.

The pure unit-order analyzer compares explicit source dependency traversal.
It rejects missing, unknown, duplicate and cyclic inputs. Its Known result
does not establish complete compiler roots, implicit runtime dependencies,
package effects or preserved reference bindings. Both baseline and edited
programs can compile while their initialization order differs.

## Agent Checklist

- Prefer semantic commands over raw grep for declarations, references, rename,
  and dead-code review.
- Run dry-run/report commands first.
- Save JSON output when reviewing large projects.
- Apply only to writable repos or temp clones.
- Rebuild after apply-mode changes.
- Record ambiguous or blocked results as review findings instead of forcing an
  edit.
