# Test runner

Build the existing test executable as Win64 Debug before running it. The
sharded wrapper requires Windows PowerShell 7 and defaults to four processes:

```powershell
& 'C:\Program Files\PowerShell\7\pwsh.exe' -NoProfile -File tests\run-shards.ps1 `
  -LogRoot F:\dev-artifacts\runs\DelphiSemantics\<owned-run>\logs `
  -OutputRoot F:\dev-artifacts\runs\DelphiSemantics\<short-owned-run>
```

`-ExecutablePath` selects an existing binary, `-ShardCount` changes concurrency,
and `-TimeoutSeconds` sets each shard's deadline (default 900 seconds). Each
process has separate TEMP/TMP, `DS_TEST_OUTPUT_ROOT`, logs and NUnit XML. The
executable stays in `tests\bin` so repository and fixture discovery are unchanged.
Unset `DS_TEST_OUTPUT_ROOT` preserves the serial runner's existing output location.
Under an override, stale cleanup requires a suite allocation marker bound to the
exact run directory; matching foreign directory names do not grant deletion authority.
The complete generated shard output root must fit in 89 characters because native
fixture compilers and SQLite still encounter Windows path limits. The wrapper
rejects a longer root before launching tests. Logs can use a longer separate root.

Use `-Run Test.ProjectContext` for a fixture prefix. `-RunList <path>` accepts
one exact binary-enumerated full case selector per line. Names containing spaces
or commas are literal; do not split or quote individual names. The wrapper sets
`DS_TEST_RUNLIST_LITERAL=1` for its child processes so DUnitX does not interpret
commas as expression separators. Direct DUnitX command-line behavior is unchanged.

The binary exports its default roster when `DS_TEST_LIST_PATH` is set. The
wrapper excludes MaxTdbProof explicitly, partitions individual cases with
deterministic longest-first balancing, and validates both each shard's identities
and the aggregate roster. `scripts/case-durations.json` contains per-case seconds
from DS revision `510a420`, recorded on 2026-10-29 in the DS-764 serial baseline.
The full native compiler comparison uses its 2026-11-06 Win64 Debug measurement
of 3151.264 seconds after the conditional-code corpus expansion. Unknown cases
receive a 0.1-second planning weight. Weights affect placement only.

Exit 0 requires nonempty, complete, unique execution with zero failures, errors,
leaks and ignored tests. Exit 1 reports failed or corrupt evidence; exit 124
reports a timeout and terminates the shard process tree. Each child starts suspended
and joins a runner-owned kill-on-close Windows job before it resumes. Descendants
still alive when a shard exits cause failure; their names, PIDs and command lines
are retained in its status, and the job terminates them. Native exits, command,
CWD, binary SHA256 and wall time are retained in each process's `status.json`.
`aggregate.json`, `cases.json`, the roster, plan, selections and raw logs remain
under the unique log run directory. Generated output remains under the reported
`ownedOutputRoot`; the caller owns its cleanup after collecting proof.

For a serial comparison, run the same binary with `--xmlfile:<owned-path>` and
the same default category selection. Compare XML cases by fixture name plus case
name, rejecting duplicate, missing or extra identities and changed `result` or
`executed` values. Retain both binary hashes, native exits and wall times. The
wrapper's `Read-DsCaseResult` and `Compare-DsIdentity` helpers can be dot sourced
for this developer check. Existing failing cases remain failures in both runs.

The runner's synthetic process and evidence regression tests require Windows
PowerShell 7.3 or newer, Pester 3.4, and the Windows .NET Framework C# compiler.
Run them from the repository root; they compile their own stand-in executable,
allocate and clean unique OS temporary directories, and need no Delphi build:

```powershell
Invoke-Pester .\tests\run-shards.Tests.ps1
Invoke-ScriptAnalyzer -Path .\tests\run-shards.ps1
Invoke-ScriptAnalyzer -Path .\tests\run-shards.Tests.ps1
```

These tests cover deterministic balancing, literal comma-bearing case names,
success and failure evidence, ignored tests, leaks, duplicate/missing/extra
identities, detached descendants, timeout cleanup, and the path-budget refusal.

For a full native proof whose successful artifacts must be retained, set
`DS719_NATIVE_RETAIN_ROOT` to a short caller-owned evidence directory. Each
comparison allocates a unique GUID child, retaining all source, route, compiler
and runtime artifacts outside successful suite cleanup. The explicit
`DS719_NATIVE_ROOT` single-comparison override takes precedence. Unset both
variables for the ordinary disposable fixture lifecycle.

## Fast smoke tier (DS-769)

Run the existing Win64 Debug binary with `--include:Fast` for routine feedback:

```powershell
tests\bin\delphiSemanticsTests.exe --include:Fast --xmlfile:<owned-path>\fast.xml
```

Fast is additive method-level tagging: every parameterized case of a tagged
method runs, and every case remains in the default full suite. Installed Delphi
12 DUnitX applies categories per method, not per TestCase attribute. Keep existing
feature categories in the same comma-separated Category value when adding Fast;
a method category overrides the fixture category.

Select synthetic, small-fixture methods with a cheap complete case set, spread
across the test fixtures. Use measured whole-method costs, not the cheapest case.
The initial selection uses the retained THREADRIPPER baseline at `510a420`:
ordinary methods cost at most 0.2 seconds; WithBinder at most 0.35 seconds;
ProjectSession at most 0.25 seconds; RemoveWithPlan at most 0.05 seconds, plus the
explicit representative methods below. These thresholds guide selection; they
are not assertions inside tests. Whole-process wall time governs acceptance:
three passing runs must have a median of at most 60 seconds on THREADRIPPER.
Re-measure additions and leave headroom for startup, fixture setup and host noise.
Do not budget against expected future performance improvements.

The expensive fixtures retain these route/strategy families (names below are
methods; every case of each named method is included):

| Fixture | Family | Representative method(s) |
| --- | --- | --- |
| WithBinder | Direct qualification, precedence and refusal | SafeBindingsArePlannedDirectReferences; MultipleSelectorsPreferInnermostReceiver; SkipReasonsCoverExternalAndUnresolvedBranches |
| WithBinder | Receiver value members and planning strategies | TypeValueMembersBind; TypeValueMembersPlan; TypeValueSafetyAndSnapshot; PerStrategyDefensesKeepResolvedEvidence |
| WithBinder | Source identity, nested scope and imported helpers | FinalizedLocalAliasesUseTargetMemberIdentities; NestedWithStatementsUseOuterReceiverStack; MalformedImportedHelperFactsFailClosed |
| WithBinder | Cold/warm/snapshot helper facts | UnindexedHelperColdWarmSnapshot; UnindexedHelperCacheAndLostFacts |
| WithBinder | Root-absence provider, public API and fail-closed admission | OptionalRootAbsenceFlowsThroughApiAndBypassesPersistentFacts; RootAbsenceRequiresClosedImportedSource; PublicProviderFingerprintFailureRefuses; AdmissionDiscardsProvisionalTreeAndSiblingReservations |
| RemoveWithPlan | Deterministic DTO and direct rewrite | PlansDeterministicDryRunDtoWithVerificationAndProvenance; FinalDtoMatchesFocusedRewriteCases |
| RemoveWithPlan | Reference, pointer, dependent and indirect capture | FinalDtoCapturesVisibleReceiverType; FinalDtoCapturesPointerReceiverBeforeBodyCall; FinalDtoCapturesDependentReceiverBeforeBodyCall; FinalDtoCapturesIndirectReceiverBeforeBodyCall |
| RemoveWithPlan | Controlled array and pointer-cast capture | FinalDtoCapturesControlledRecordArrayReceiver; FinalDtoCapturesPointerCastReceiverOnce |
| RemoveWithPlan | Temporary-name policy and safety skips | FinalDtoMatchesTempPolicyCollisionRules; FinalDtoPreservesDakFixtureSafetySkips; HelperRefusalSurvivesHandBuiltBinding |
| RemoveWithPlan | Snapshot/facts parity and combined session API | SnapshotPlannerMatchesBindingFactsPlanWithoutProjectFactsSidecar; CombinedApiReturnsFactsAndCanonicalPlanFromOneSession |
| ProjectSession | Publication, accepted/refused profiles and root proof | RequestOwnerSealsEveryModelBeforePublication; RootAbsenceValidatesActualProjectProfile; ProjectSessionInheritedAccessWithoutRootProofRefuses; ProjectSessionInheritedAccessWithRootProofPlans |
| ProjectSession | Cold/warm/invalidation and persistent/no-cache reuse | IdentifierScopedRenameMatchesColdWarmAndInvalidatedCache; TenAlternativePlansReuseOwnedContext; ChangedCompilerContextInvalidatesSnapshotCache |
| ProjectSession | Partial snapshot, included-file drift and parallel/sequential parity | ProjectSessionPartialSnapshotCacheInvalidationMatchesFullRebuildFacts; ProjectSessionSnapshotCacheRebuildsIncludedFileChanges; ProjectSessionParallelSnapshotBuildMatchesSequentialFacts; ProjectSessionParallelRemoveWithPlanMatchesSequentialCounts |
| ProjectSession | Identifier-scoped/full route, typed constants and cross-target graph | IdentifierScopedSessionMatchesForcedFullRename; TypedConstantsRemainQueryableAcrossSnapshotCacheModes; ProjectSessionDependencyGraphUsesLinux64TargetDefines |
| RequestPublication | Owner bypass of persisted facts | OwnerBypassesPersistedWithFacts |

Methods containing any known DS-766 environment failure stay outside Fast,
including their passing parameterized cases:

- WithBinder: NamedRootSiteHelperPrecedenceIsPreserved,
  UnindexedSourceTokenEditInvalidatesWarmFacts, TabIncludeEditInvalidatesWarmFacts,
  NamedRootCaptureUsesRootMostDeclaration, RootProofIncludesUseExpandedScope,
  NamedRootPrivateGetterPropertyScopes, RootProofRequiresVerifiedPreprocessScope,
  FailedModelCannotBypassRootAbsenceProof.
- RemoveWithPlan: FinalDtoMatchesMaxTdbTdbUtilsFlipMarkReplacement.
- UnitNameWitness: ProfileFileCandidatesChangeWitnessIdentity,
  DebugDcuPathsAreCandidateLocations, TranslatedPathsRequireLanguage.

MaxTdbProof stays opt-in and outside Fast. After DS-768, UnitNameWitness adds
20 methods (81 cases): the passing SDK/include/alias/identity controls plus
BoundedLookupMatchesFullEnumeration (32 generated layouts),
ComparerClassLookupMatchesFullEnumeration (370 comparer/native-fallback
comparisons), ChangedProfilePathGetsFreshScan and
DirectoryInventoryNoticesAddedAndRemovedCandidates. The four new methods passed
a focused Win64 Debug probe; their whole-case times were 0.198, 0.594, 0.008 and
0.006 seconds respectively on THREADRIPPER. These explicit representatives cover
bounded/full enumeration parity, comparer and native-error fallbacks, fresh
profile scans and immediate add/remove visibility. The three DS-766 methods
listed above remain excluded in full. The two TTestOutputRootTests checks are
declared in the DPR and remain full-suite-only; DS-769 changes attributes in
tests/src only.

Fast is smoke coverage, not acceptance of every method or route. A slice still
runs the owning fixture for every area it touches. Fast never replaces the
complete default suite at batch or final gates.
## Native MaxTdb context

MaxTdbProof and the native FlipMark comparison require
`DELPHISEMANTICS_MAXTDB_FIXTURE_ROOT` to name a fresh, writable MaxTdb fixture
copy containing `src/maxtdb.dproj`. Preserve its native dependency topology,
including the three Foundation units selected by explicit relative DPR paths.
Copying only the MaxTdb folder leaves those paths unresolved and cannot certify
the other sources. Keep DPR/DPROJ/source bytes unchanged when preparing the
topology; use the retained native-fixture recipe for the selected proof run.

The tests capture real Debug/Win64/Delphi 23.0 define and include evidence in
that owned copy. A missing source-applicability witness remains incomplete;
the fixture helper never converts a caller define list into a certificate.
The ordinary sharded runner continues to exclude MaxTdbProof. Run that category
explicitly with the existing test executable and retain its 205-case XML report.
