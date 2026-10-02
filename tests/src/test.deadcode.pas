unit Test.DeadCode;

interface

uses
  DUnitX.TestFramework,
  DelphiSemantics.Api,
  DelphiSemantics.Cache,
  DelphiSemantics.CompilerProfile,
  DelphiSemantics.DeadCode,
  DelphiSemantics.Index,
  DelphiSemantics.Model,
  DelphiSemantics.Query,
  DelphiSemantics.Snapshot;

type
  [TestFixture]
  TDeadCodeTests = class
  private
    function CandidateHasBlocker(const aReport: TDelphiSemanticDeadCodeReport;
      const aName, aBlocker: string): Boolean;
    function CandidateHasBlockerInUnit(const aReport: TDelphiSemanticDeadCodeReport;
      const aName, aUnitName, aKind, aBlocker: string): Boolean;
    function CandidateStatus(const aReport: TDelphiSemanticDeadCodeReport;
      const aName: string): string;
    function CandidateStatusInUnit(const aReport: TDelphiSemanticDeadCodeReport;
      const aName, aUnitName, aKind: string): string;
    function LoadContext: TDelphiSemanticSymbolQueryContext;
  public
    [Test]
    procedure DeadCodeProfilesParseFormatAndRejectUnknown;
    [Test]
    procedure ReportsConservativeDeadCodeStatuses;
    [Test]
    procedure UnresolvedReferenceBlockersStayInSourceUnit;
    [Test]
    procedure SafetyGuardsUseModelSourceTextAfterDiskChanges;
    [Test]
    procedure SafetyGuardsUseSnapshotSourceTextAfterDiskChanges;
    [Test]
    procedure ReportsDeadCodeFromSnapshotWithoutProjectIndexBuild;
    [Test]
    procedure UnknownReportProfileReturnsDiagnostic;
    [Test]
    procedure SnapshotReferenceCountsMatchModelBackedReport;
    [Test]
    procedure InitializerAndInactiveUsesAreNeverUnused;
    [Test]
    procedure EntryPointUsesAreNeverUnused;
    [Test]
    procedure IncludeDeclaredRoutineIsReportedAtIncludeAndBlocked;
    [Test]
    procedure OverloadedAndShortFormRoutinesUsedElsewhereAreNeverUnused;
    [Test]
    procedure OverloadBodiesWithRespelledHeadersAreNeverUnused;
    [Test]
    procedure UnpairedImplementationOfUsedInterfaceIsBlocked;
    [Test]
    procedure MidLineIncludeRoutinesAreBlocked;
  end;

implementation

uses
  System.Generics.Collections, System.IOUtils, System.StrUtils, System.SysUtils,
  Winapi.Windows,
  DelphiSemantics.ProjectContext, DelphiSemantics.ProjectSession,
  DelphiSemantics.Snapshot.Builder, DelphiSemantics.WithBinding,
  maxLogic.IOUtils,
  Test.Support;

var
  GDeadCodeTempRoot: string;

function DeadCodeTempPath(const aName: string): string;
var
  lGuid: TGUID;
  lGuidText: string;
begin
  if GDeadCodeTempRoot = '' then
  begin
    CreateGUID(lGuid);
    lGuidText := StringReplace(StringReplace(GUIDToString(lGuid), '{', '', [rfReplaceAll]), '}',
      '', [rfReplaceAll]);
    GDeadCodeTempRoot := TPath.GetFullPath(CombinePath([ExtractFilePath(ParamStr(0)),
      'snapshot-deadcode-temp', 'run-' + GetCurrentProcessId.ToString + '-' + lGuidText]));
  end;
  TDirectory.CreateDirectory(GDeadCodeTempRoot);
  Result := TPath.Combine(GDeadCodeTempRoot, aName);
end;

function TDeadCodeTests.CandidateHasBlocker(const aReport: TDelphiSemanticDeadCodeReport;
  const aName, aBlocker: string): Boolean;
var
  lBlocker: string;
  lCandidate: TDelphiSemanticDeadCodeCandidate;
begin
  for lCandidate in aReport.Candidates do
    if SameText(lCandidate.Name, aName) then
      for lBlocker in lCandidate.Blockers do
        if SameText(lBlocker, aBlocker) then
          Exit(True);

  Result := False;
end;

function TDeadCodeTests.CandidateHasBlockerInUnit(const aReport:
  TDelphiSemanticDeadCodeReport; const aName, aUnitName, aKind,
  aBlocker: string): Boolean;
var
  lBlocker: string;
  lCandidate: TDelphiSemanticDeadCodeCandidate;
begin
  for lCandidate in aReport.Candidates do
    if SameText(lCandidate.Name, aName) and SameText(lCandidate.UnitName, aUnitName) and
      SameText(lCandidate.Kind, aKind) then
      for lBlocker in lCandidate.Blockers do
        if SameText(lBlocker, aBlocker) then
          Exit(True);

  Result := False;
end;

function TDeadCodeTests.CandidateStatus(const aReport: TDelphiSemanticDeadCodeReport;
  const aName: string): string;
var
  lCandidate: TDelphiSemanticDeadCodeCandidate;
begin
  for lCandidate in aReport.Candidates do
    if SameText(lCandidate.Name, aName) then
      Exit(lCandidate.Status);

  Result := '';
end;

function TDeadCodeTests.CandidateStatusInUnit(const aReport:
  TDelphiSemanticDeadCodeReport; const aName, aUnitName, aKind: string): string;
var
  lCandidate: TDelphiSemanticDeadCodeCandidate;
begin
  for lCandidate in aReport.Candidates do
    if SameText(lCandidate.Name, aName) and SameText(lCandidate.UnitName, aUnitName) and
      SameText(lCandidate.Kind, aKind) then
      Exit(lCandidate.Status);

  Result := '';
end;

function DescribeCandidates(const aReport: TDelphiSemanticDeadCodeReport): string;
var
  lCandidate: TDelphiSemanticDeadCodeCandidate;
begin
  Result := '';
  for lCandidate in aReport.Candidates do
    Result := Result + lCandidate.Name + '=' + lCandidate.Status + '/' + IntToStr(
      lCandidate.ReferenceCount) + '; ';
end;

function CandidateReferenceCount(const aReport: TDelphiSemanticDeadCodeReport;
  const aName: string): Integer;
var
  lCandidate: TDelphiSemanticDeadCodeCandidate;
begin
  for lCandidate in aReport.Candidates do
    if SameText(lCandidate.Name, aName) then
      Exit(lCandidate.ReferenceCount);

  Result := -1;
end;

// DS-653 review: UMain.GLimit is used only by `PLimit: PInteger = @GLimit` and CLimit only by
// `CDouble = CLimit * 2`, both after a routine. Removing GLimit still compiles because
// UOther.GLimit then takes over, so the program would print 99 instead of 10. GHidden is used
// only in inactive code, which no reference fact covers.
procedure TDeadCodeTests.InitializerAndInactiveUsesAreNeverUnused;
var
  lCacheMetrics: TDelphiSemanticCacheMetrics;
  lContext: TDelphiSemanticSymbolQueryContext;
  lExtractionMilliseconds: Int64;
  lOptions: TDelphiSemanticOptions;
  lReport: TDelphiSemanticDeadCodeReport;
  lRootPath: string;
  lSessionResult: TDelphiSemanticProjectSessionResult;
begin
  lRootPath := DeadCodeTempPath('initializer-uses');
  TDirectory.Copy(FixturePath('DeadCodeInitializers', ''), lRootPath);
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := TPath.Combine(lRootPath, 'P.dproj');
  lSessionResult := TDelphiSemanticProjectSession.Open(lOptions);
  Assert.IsTrue(lSessionResult.Success);
  try
    lContext := lSessionResult.Session.BuildSnapshotSymbolQueryContext(lCacheMetrics,
      lExtractionMilliseconds);
    try
      lReport := TDelphiSemanticDeadCodeReporter.Report(lContext, 'legacy-static');
      Assert.AreNotEqual('definitely-unused', CandidateStatusInUnit(lReport, 'GLimit', 'UMain',
        'var'), DescribeCandidates(lReport));
      Assert.AreNotEqual('definitely-unused', CandidateStatusInUnit(lReport, 'CLimit', 'UMain',
        'const'), DescribeCandidates(lReport));
      Assert.AreEqual('blocked', CandidateStatusInUnit(lReport, 'GHidden', 'UMain', 'var'),
        DescribeCandidates(lReport));
      Assert.IsTrue(CandidateHasBlockerInUnit(lReport, 'GHidden', 'UMain', 'var',
        'unclassified-occurrence'), DescribeCandidates(lReport));
      // Control: GOther is used in a body, so it is no candidate at all.
      Assert.AreEqual('', CandidateStatusInUnit(lReport, 'GOther', 'UMain', 'var'),
        DescribeCandidates(lReport));
    finally
      // Release the session-owned snapshot before the session.
      lContext := Default(TDelphiSemanticSymbolQueryContext);
    end;
  finally
    lSessionResult.Session.Free;
  end;
end;

function CandidateInUnit(const aReport: TDelphiSemanticDeadCodeReport;
  const aName, aUnitName: string; out aCandidate: TDelphiSemanticDeadCodeCandidate): Boolean;
var
  lCandidate: TDelphiSemanticDeadCodeCandidate;
begin
  for lCandidate in aReport.Candidates do
    if SameText(lCandidate.Name, aName) and SameText(lCandidate.UnitName, aUnitName) then
    begin
      aCandidate := lCandidate;
      Exit(True);
    end;
  aCandidate := Default(TDelphiSemanticDeadCodeCandidate);
  Result := False;
end;

function EntryPointsReport(const aFolder: string): TDelphiSemanticDeadCodeReport;
var
  lCacheMetrics: TDelphiSemanticCacheMetrics;
  lContext: TDelphiSemanticSymbolQueryContext;
  lExtractionMilliseconds: Int64;
  lOptions: TDelphiSemanticOptions;
  lRootPath: string;
  lSessionResult: TDelphiSemanticProjectSessionResult;
begin
  lRootPath := DeadCodeTempPath(aFolder);
  TDirectory.Copy(FixturePath('DeadCodeEntryPoints', ''), lRootPath);
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := TPath.Combine(lRootPath, 'P.dproj');
  lSessionResult := TDelphiSemanticProjectSession.Open(lOptions);
  Assert.IsTrue(lSessionResult.Success);
  try
    lContext := lSessionResult.Session.BuildSnapshotSymbolQueryContext(lCacheMetrics,
      lExtractionMilliseconds);
    try
      Result := TDelphiSemanticDeadCodeReporter.Report(lContext, 'legacy-static');
    finally
      // Release the session-owned snapshot before the session.
      lContext := Default(TDelphiSemanticSymbolQueryContext);
    end;
  finally
    lSessionResult.Session.Free;
  end;
end;

// DS-660: a call from the program main block or from another unit's initialization or
// finalization block binds the interface declaration; its implementation is used as well.
procedure TDeadCodeTests.EntryPointUsesAreNeverUnused;
var
  lCandidate: TDelphiSemanticDeadCodeCandidate;
  lControlReported: Boolean;
  lReport: TDelphiSemanticDeadCodeReport;
begin
  lReport := EntryPointsReport('entry-points');
  Assert.IsFalse(CandidateInUnit(lReport, 'Value', 'UEntry', lCandidate),
    'Value is used by the main block: ' + DescribeCandidates(lReport));
  Assert.IsFalse(CandidateInUnit(lReport, 'InitUsed', 'UEntry', lCandidate),
    'InitUsed is used by an initialization block: ' + DescribeCandidates(lReport));
  Assert.IsFalse(CandidateInUnit(lReport, 'FinalUsed', 'UEntry', lCandidate),
    'FinalUsed is used by a finalization block: ' + DescribeCandidates(lReport));
  // Control: the unused implementation of NeverUsed is still reported.
  lControlReported := False;
  for lCandidate in lReport.Candidates do
    if SameText(lCandidate.Name, 'NeverUsed') and SameText(lCandidate.UnitName, 'UEntry') and
      SameText(lCandidate.Status, 'definitely-unused') then
      lControlReported := True;
  Assert.IsTrue(lControlReported, DescribeCandidates(lReport));
end;

// DS-660 review: Ov(1) and Ov2(5) stay unresolved in the program and in UE, and the short-form
// body "procedure Helper;" shares its name with a nested Helper in Other. None of the called
// routines' bodies may be reported unused; the uncalled Other is the control.
procedure TDeadCodeTests.OverloadedAndShortFormRoutinesUsedElsewhereAreNeverUnused;
var
  lCacheMetrics: TDelphiSemanticCacheMetrics;
  lCandidate: TDelphiSemanticDeadCodeCandidate;
  lContext: TDelphiSemanticSymbolQueryContext;
  lControlReported: Boolean;
  lExtractionMilliseconds: Int64;
  lOptions: TDelphiSemanticOptions;
  lReport: TDelphiSemanticDeadCodeReport;
  lRootPath: string;
  lSessionResult: TDelphiSemanticProjectSessionResult;
begin
  lRootPath := DeadCodeTempPath('overloads');
  TDirectory.Copy(FixturePath('DeadCodeOverloads', ''), lRootPath);
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := TPath.Combine(lRootPath, 'P.dproj');
  lSessionResult := TDelphiSemanticProjectSession.Open(lOptions);
  Assert.IsTrue(lSessionResult.Success);
  try
    lContext := lSessionResult.Session.BuildSnapshotSymbolQueryContext(lCacheMetrics,
      lExtractionMilliseconds);
    try
      lReport := TDelphiSemanticDeadCodeReporter.Report(lContext, 'legacy-static');
    finally
      // Release the session-owned snapshot before the session.
      lContext := Default(TDelphiSemanticSymbolQueryContext);
    end;
  finally
    lSessionResult.Session.Free;
  end;

  lControlReported := False;
  for lCandidate in lReport.Candidates do
  begin
    if not SameText(lCandidate.UnitName, 'UD') or not SameText(lCandidate.Kind, 'routine') then
      Continue;
    // UD line 33 is the nested Helper inside Other; it is unused.
    if MatchText(lCandidate.Name, ['Ov', 'Ov2', 'Lone']) or
      (SameText(lCandidate.Name, 'Helper') and (lCandidate.Line <> 33)) then
      Assert.AreNotEqual('definitely-unused', lCandidate.Status, lCandidate.Name + ':' +
        IntToStr(lCandidate.Line) + ' is called. ' + DescribeCandidates(lReport));
    if SameText(lCandidate.Name, 'Other') and SameText(lCandidate.Status, 'definitely-unused') then
      lControlReported := True;
  end;
  Assert.IsTrue(lControlReported, DescribeCandidates(lReport));
end;

function LegacyStaticReport(const aFixture, aFolder: string): TDelphiSemanticDeadCodeReport;
var
  lCacheMetrics: TDelphiSemanticCacheMetrics;
  lContext: TDelphiSemanticSymbolQueryContext;
  lExtractionMilliseconds: Int64;
  lOptions: TDelphiSemanticOptions;
  lRootPath: string;
  lSessionResult: TDelphiSemanticProjectSessionResult;
begin
  lRootPath := DeadCodeTempPath(aFolder);
  TDirectory.Copy(FixturePath(aFixture, ''), lRootPath);
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := TPath.Combine(lRootPath, 'P.dproj');
  lSessionResult := TDelphiSemanticProjectSession.Open(lOptions);
  Assert.IsTrue(lSessionResult.Success);
  try
    lContext := lSessionResult.Session.BuildSnapshotSymbolQueryContext(lCacheMetrics,
      lExtractionMilliseconds);
    try
      Result := TDelphiSemanticDeadCodeReporter.Report(lContext, 'legacy-static');
    finally
      // Release the session-owned snapshot before the session.
      lContext := Default(TDelphiSemanticSymbolQueryContext);
    end;
  finally
    lSessionResult.Session.Free;
  end;
end;

function CandidateStatusAt(const aReport: TDelphiSemanticDeadCodeReport; const aName: string;
  const aLine: Integer): string;
var
  lCandidate: TDelphiSemanticDeadCodeCandidate;
begin
  for lCandidate in aReport.Candidates do
    if SameText(lCandidate.Name, aName) and (lCandidate.Line = aLine) then
      Exit(lCandidate.Status);
  Result := '';
end;

// DS-660 review round 2: UO line 10 spells the header of Ov4(a, b: Integer) as
// "Ov4(a: Integer; b: Integer)" and line 18 drops Ov6's default value; both are called from UP.
// Lonely (line 26) is the control.
procedure TDeadCodeTests.OverloadBodiesWithRespelledHeadersAreNeverUnused;
var
  lReport: TDelphiSemanticDeadCodeReport;
begin
  lReport := LegacyStaticReport('DeadCodeOverloadHeaders', 'overload-headers');
  // Paired with their interface declarations, the bodies share their references: no candidate.
  Assert.AreEqual('', CandidateStatusAt(lReport, 'Ov4', 10), DescribeCandidates(lReport));
  Assert.AreEqual('', CandidateStatusAt(lReport, 'Ov6', 18), DescribeCandidates(lReport));
  Assert.AreEqual('definitely-unused', CandidateStatusAt(lReport, 'Lonely', 26),
    DescribeCandidates(lReport));
end;

// DS-660 review round 2: a body whose header pairs with no interface declaration must not be
// reported unused while a same-named interface declaration is used. The header of the body on
// UO line 10 is replaced with one that matches nothing.
procedure TDeadCodeTests.UnpairedImplementationOfUsedInterfaceIsBlocked;
var
  i: Integer;
  lContext: TDelphiSemanticSymbolQueryContext;
  lFileName: string;
  lMetrics: TDelphiSnapshotBuilderMetrics;
  lModelOptions: TDelphiSemanticModelOptions;
  lModels: TArray<TDelphiSemanticUnitModel>;
  lOptions: TDelphiSnapshotBuildOptions;
  lReport: TDelphiSemanticDeadCodeReport;
  lRootPath: string;
  lScopedContext: TScopedSnapshotQueryContext;
  lSnapshot: TDelphiProjectSnapshot;
begin
  lRootPath := DeadCodeTempPath('unpaired-implementation');
  TDirectory.Copy(FixturePath('DeadCodeOverloadHeaders', ''), lRootPath);
  lModels := [];
  for lFileName in ['P.dpr', 'UO.pas', 'UP.pas'] do
  begin
    lModelOptions := Default(TDelphiSemanticModelOptions);
    lModelOptions.SourceFileName := TPath.Combine(lRootPath, lFileName);
    lModelOptions.ProjectContextApplied := True;
    lModels := lModels + [TDelphiSemanticUnitModelExtractor.ExtractFromFile(lModelOptions)];
  end;
  for i := 0 to High(lModels[1].Routines) do
    if SameText(lModels[1].Routines[i].Name, 'Ov4') and (lModels[1].Routines[i].Line = 10) then
      lModels[1].Routines[i].Signature := '(z: TNoSuchType)';

  lOptions := Default(TDelphiSnapshotBuildOptions);
  lOptions.ResolveReferenceTargets := True;
  lOptions.WorkerCount := 1;
  lSnapshot := BuildProjectSnapshotFromModels(lModels,
    Default(TDelphiSemanticProjectWithBindingFacts), lOptions, lMetrics);
  lScopedContext := TScopedSnapshotQueryContext.Create(lSnapshot);
  try
    lContext := lScopedContext.Context;
    lReport := TDelphiSemanticDeadCodeReporter.Report(lContext, 'legacy-static');
    Assert.AreEqual('blocked', CandidateStatusAt(lReport, 'Ov4', 10), DescribeCandidates(lReport));
    Assert.IsTrue(CandidateHasBlocker(lReport, 'Ov4', 'unpaired-implementation'),
      DescribeCandidates(lReport));
    Assert.AreEqual('definitely-unused', CandidateStatusAt(lReport, 'Lonely', 26),
      DescribeCandidates(lReport));
  finally
    lScopedContext.Free;
    lSnapshot.Free;
  end;
end;

// DS-659 review round 2: dead.inc is included on a line with a comment, so its routines sit on
// the directive (UM line 9) of the unit file.
procedure TDeadCodeTests.MidLineIncludeRoutinesAreBlocked;
var
  lReport: TDelphiSemanticDeadCodeReport;
begin
  lReport := LegacyStaticReport('DeadCodeMidLineIncludes', 'mid-line-includes');
  Assert.AreEqual('blocked', CandidateStatusAt(lReport, 'DeadTwo', 9), DescribeCandidates(lReport));
  Assert.IsTrue(CandidateHasBlockerInUnit(lReport, 'DeadTwo', 'UM', 'routine',
    'declared-in-include'), DescribeCandidates(lReport));
end;

// DS-659: a routine declared in an include file is reported at that file and never removed.
procedure TDeadCodeTests.IncludeDeclaredRoutineIsReportedAtIncludeAndBlocked;
var
  lCandidate: TDelphiSemanticDeadCodeCandidate;
  lReport: TDelphiSemanticDeadCodeReport;
begin
  lReport := EntryPointsReport('include-declaration');
  Assert.IsTrue(CandidateInUnit(lReport, 'IncludedUnused', 'UEntry', lCandidate),
    DescribeCandidates(lReport));
  Assert.AreEqual('entry.inc', LowerCase(ExtractFileName(lCandidate.FileName)));
  Assert.AreEqual(1, lCandidate.Line);
  Assert.AreEqual(10, lCandidate.Column);
  Assert.AreEqual('blocked', lCandidate.Status, DescribeCandidates(lReport));
  Assert.IsTrue(CandidateHasBlockerInUnit(lReport, 'IncludedUnused', 'UEntry', 'routine',
    'declared-in-include'), DescribeCandidates(lReport));
end;

procedure TDeadCodeTests.DeadCodeProfilesParseFormatAndRejectUnknown;
var
  lProfile: TDelphiSemanticDeadCodeSafetyProfile;
begin
  Assert.IsTrue(TDelphiSemanticDeadCodeProfiles.TryParse('legacy-static', lProfile));
  Assert.AreEqual(TDelphiSemanticDeadCodeSafetyProfile.dcspLegacyStatic, lProfile);
  Assert.AreEqual('legacy-static', TDelphiSemanticDeadCodeProfiles.ToName(lProfile));
  Assert.AreEqual('audit',
    TDelphiSemanticDeadCodeProfiles.ToName(TDelphiSemanticDeadCodeProfiles.DefaultReportProfile));
  Assert.AreEqual('conservative',
    TDelphiSemanticDeadCodeProfiles.ToName(
    TDelphiSemanticDeadCodeProfiles.DefaultRemovalProfile));
  Assert.AreEqual('audit, conservative, or legacy-static',
    TDelphiSemanticDeadCodeProfiles.AllowedNamesText);
  Assert.IsFalse(TDelphiSemanticDeadCodeProfiles.TryParse('typo', lProfile));
  Assert.AreEqual('Invalid dead-code profile: typo (expected audit, conservative, or legacy-static).',
    TDelphiSemanticDeadCodeProfiles.InvalidProfileDiagnostic('typo'));
end;


function TDeadCodeTests.LoadContext: TDelphiSemanticSymbolQueryContext;
var
  lCache: TDelphiSemanticUnitCache;
  lCacheOptions: TDelphiSemanticCacheOptions;
  lModelOptions: TDelphiSemanticModelOptions;
begin
  lCacheOptions := Default(TDelphiSemanticCacheOptions);
  lCacheOptions.CompilerProfileName := 'Delphi-12-DeadCode';
  lCache := TDelphiSemanticUnitCache.Create(lCacheOptions);
  try
    lModelOptions := Default(TDelphiSemanticModelOptions);
    lModelOptions.SourceFileName := FixturePath('DeadCode', 'DeadCodeUnit.pas');
    lModelOptions.ProjectContextApplied := True;
    Result.UnitModel := lCache.GetOrExtractUnitModel(lModelOptions);
    Result.CompilerProfile := TDelphiSemanticCompilerProfileBuilder.FromCachedSources(lCache,
      [FixturePath('DeadCode', 'DeadCodeOtherUnit.pas')]);
    lModelOptions := Default(TDelphiSemanticModelOptions);
    lModelOptions.SourceFileName := FixturePath('DeadCode', 'DeadCodeRtlUnit.pas');
    lModelOptions.ProjectContextApplied := True;
    Result.IndexedUnitModels := Result.CompilerProfile.RtlSourceUnitModels +
      [lCache.GetOrExtractUnitModel(lModelOptions)];
    Result.IndexedUnitSourceKinds := ['project-source', 'rtl-source'];
    Result.CacheMetrics := lCache.Metrics;
  finally
    lCache.Free;
  end;
end;

procedure TDeadCodeTests.ReportsConservativeDeadCodeStatuses;
var
  lContext: TDelphiSemanticSymbolQueryContext;
  lReport: TDelphiSemanticDeadCodeReport;
begin
  lContext := LoadContext;

  lReport := TDelphiSemanticApi.ReportDeadCode(lContext, 'audit');

  Assert.AreEqual('audit', lReport.Profile);
  Assert.AreEqual('definitely-unused', CandidateStatus(lReport, 'StaticUnusedValue'));
  Assert.AreEqual('maybe-unused', CandidateStatus(lReport, 'MaybeDynamicHook'));
  Assert.AreEqual('externally-visible', CandidateStatus(lReport, 'TExternallyVisibleType'));
  Assert.AreEqual('blocked', CandidateStatus(lReport, 'Button1Click'), 'Button1Click');
  Assert.AreEqual('blocked', CandidateStatus(lReport, 'ExportedHook'), 'ExportedHook ' +
    DescribeCandidates(lReport));
  Assert.AreEqual('blocked', CandidateStatus(lReport, 'InitializedHook'), 'InitializedHook');
  Assert.AreEqual('blocked', CandidateStatus(lReport, 'MessageHandler'), 'MessageHandler');
  Assert.AreEqual('blocked', CandidateStatus(lReport, 'AmbiguousGlobal'), 'AmbiguousGlobal');
  Assert.AreEqual('blocked', CandidateStatus(lReport, 'MissingExternalSymbol'), 'MissingExternalSymbol');
  Assert.AreEqual('blocked', CandidateStatus(lReport, 'ExternalOnlySymbol'), 'ExternalOnlySymbol');
  Assert.AreEqual('', CandidateStatus(lReport, 'UsedGlobalValue'));
  Assert.IsTrue(CandidateHasBlocker(lReport, 'Button1Click', 'published-or-dfm-handler'));
  Assert.IsTrue(CandidateHasBlocker(lReport, 'ExportedHook', 'exported-symbol'));
  Assert.IsTrue(CandidateHasBlocker(lReport, 'InitializedHook', 'initialization-hook'));
  Assert.IsTrue(CandidateHasBlocker(lReport, 'MessageHandler', 'message-method'));
  Assert.IsTrue(CandidateHasBlocker(lReport, 'AmbiguousGlobal', 'ambiguous-reference'));
  Assert.IsTrue(CandidateHasBlocker(lReport, 'MissingExternalSymbol', 'unresolved-reference'));
  Assert.IsTrue(CandidateHasBlocker(lReport, 'ExternalOnlySymbol', 'unresolved-reference'));
end;

procedure TDeadCodeTests.UnresolvedReferenceBlockersStayInSourceUnit;
var
  lContext: TDelphiSemanticSymbolQueryContext;
  lDeclaration: TDelphiSemanticDeclaration;
  lReference: TDelphiSemanticReference;
  lReport: TDelphiSemanticDeadCodeReport;
  lUnresolvedUnit: TDelphiSemanticUnitModel;
  lUnusedUnit: TDelphiSemanticUnitModel;
begin
  lUnresolvedUnit := Default(TDelphiSemanticUnitModel);
  lUnresolvedUnit.Success := True;
  lUnresolvedUnit.UnitName := 'UnresolvedUseUnit';
  lUnresolvedUnit.FileName := DeadCodeTempPath('unresolved-reference-use.pas');
  lUnresolvedUnit.SourceText :=
    'unit UnresolvedUseUnit;' + sLineBreak +
    'interface' + sLineBreak +
    'implementation' + sLineBreak +
    'procedure Touch;' + sLineBreak +
    'begin' + sLineBreak +
    '  SharedHook := 1;' + sLineBreak +
    'end;' + sLineBreak +
    'end.';
  lReference := Default(TDelphiSemanticReference);
  lReference.Name := 'SharedHook';
  lReference.SectionKind := 'implementation';
  lReference.Line := 6;
  lReference.Column := 3;
  lReference.EndLine := 6;
  lReference.EndColumn := 12;
  lUnresolvedUnit.References := [lReference];

  lUnusedUnit := Default(TDelphiSemanticUnitModel);
  lUnusedUnit.Success := True;
  lUnusedUnit.UnitName := 'UnusedHookUnit';
  lUnusedUnit.FileName := DeadCodeTempPath('unresolved-reference-unused.pas');
  lUnusedUnit.SourceText :=
    'unit UnusedHookUnit;' + sLineBreak +
    'interface' + sLineBreak +
    'implementation' + sLineBreak +
    'var' + sLineBreak +
    '  SharedHook: Integer;' + sLineBreak +
    'end.';
  lDeclaration := Default(TDelphiSemanticDeclaration);
  lDeclaration.Name := 'SharedHook';
  lDeclaration.Kind := 'var';
  lDeclaration.SectionKind := 'implementation';
  lDeclaration.Line := 5;
  lDeclaration.Column := 3;
  lUnusedUnit.Declarations := [lDeclaration];

  lContext := Default(TDelphiSemanticSymbolQueryContext);
  lContext.UnitModel := lUnresolvedUnit;
  lContext.IndexedUnitModels := [lUnusedUnit];
  lContext.IndexedUnitSourceKinds := ['project-source'];

  lReport := TDelphiSemanticApi.ReportDeadCode(lContext, 'audit');

  Assert.AreEqual('definitely-unused', CandidateStatusInUnit(lReport, 'SharedHook',
    'UnusedHookUnit', 'var'), DescribeCandidates(lReport));
  Assert.IsFalse(CandidateHasBlockerInUnit(lReport, 'SharedHook', 'UnusedHookUnit', 'var',
    'unresolved-reference'), DescribeCandidates(lReport));
  Assert.AreEqual('blocked', CandidateStatusInUnit(lReport, 'SharedHook',
    'UnresolvedUseUnit', 'unresolved-reference'), DescribeCandidates(lReport));
  Assert.IsTrue(CandidateHasBlockerInUnit(lReport, 'SharedHook', 'UnresolvedUseUnit',
    'unresolved-reference', 'unresolved-reference'), DescribeCandidates(lReport));
end;

procedure TDeadCodeTests.SafetyGuardsUseModelSourceTextAfterDiskChanges;
var
  lContext: TDelphiSemanticSymbolQueryContext;
  lModelOptions: TDelphiSemanticModelOptions;
  lMutatedSource: string;
  lPath: string;
  lReport: TDelphiSemanticDeadCodeReport;
  lSource: string;
begin
  lPath := DeadCodeTempPath('dead-code-model-source-text.pas');
  lSource :=
    'unit DeadCodeModelSourceTextUnit;' + sLineBreak +
    'interface' + sLineBreak +
    'implementation' + sLineBreak +
    'procedure WindowHook(var Msg: Integer); message 1024;' + sLineBreak +
    'begin' + sLineBreak +
    'end;' + sLineBreak +
    'procedure ExportedHook;' + sLineBreak +
    'begin' + sLineBreak +
    'end;' + sLineBreak +
    'procedure InitializedHook;' + sLineBreak +
    'begin' + sLineBreak +
    'end;' + sLineBreak +
    'procedure FinalizedHook;' + sLineBreak +
    'begin' + sLineBreak +
    'end;' + sLineBreak +
    'exports' + sLineBreak +
    '  ExportedHook;' + sLineBreak +
    'initialization' + sLineBreak +
    '  InitializedHook;' + sLineBreak +
    'finalization' + sLineBreak +
    '  FinalizedHook;' + sLineBreak +
    'end.';
  TFile.WriteAllText(lPath, lSource, TEncoding.UTF8);

  lModelOptions := Default(TDelphiSemanticModelOptions);
  lModelOptions.SourceFileName := lPath;
  lModelOptions.ProjectContextApplied := True;
  lContext := Default(TDelphiSemanticSymbolQueryContext);
  lContext.UnitModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lModelOptions);
  Assert.IsTrue(lContext.UnitModel.Success);

  lMutatedSource := StringReplace(lSource, ' message 1024', '', []);
  lMutatedSource := StringReplace(lMutatedSource,
    'exports' + sLineBreak + '  ExportedHook;' + sLineBreak +
    'initialization' + sLineBreak + '  InitializedHook;' + sLineBreak +
    'finalization' + sLineBreak + '  FinalizedHook;' + sLineBreak, '', []);
  TFile.WriteAllText(lPath, lMutatedSource, TEncoding.UTF8);

  lReport := TDelphiSemanticApi.ReportDeadCode(lContext, 'audit');

  Assert.IsTrue(CandidateHasBlocker(lReport, 'WindowHook', 'message-method'),
    'Message method safety should use model SourceText, not a disk reread.');
  Assert.IsTrue(CandidateHasBlocker(lReport, 'ExportedHook', 'exported-symbol'),
    'Export safety should use model SourceText, not a disk reread.');
  Assert.IsTrue(CandidateHasBlocker(lReport, 'InitializedHook', 'initialization-hook'),
    'Initialization/finalization safety should use model SourceText, not a disk reread.');
  Assert.IsTrue(CandidateHasBlocker(lReport, 'FinalizedHook', 'initialization-hook'),
    'Finalization safety should use model SourceText, not a disk reread.');
end;

procedure TDeadCodeTests.SafetyGuardsUseSnapshotSourceTextAfterDiskChanges;
var
  lBuildOptions: TDelphiSnapshotBuildOptions;
  lContext: TDelphiSemanticSymbolQueryContext;
  lMetrics: TDelphiSnapshotBuilderMetrics;
  lModelOptions: TDelphiSemanticModelOptions;
  lMutatedSource: string;
  lPath: string;
  lRemoveWithFacts: TDelphiSemanticProjectWithBindingFacts;
  lReport: TDelphiSemanticDeadCodeReport;
  lScopedContext: TScopedSnapshotQueryContext;
  lSnapshot: TDelphiProjectSnapshot;
  lSnapshotContext: TDelphiSemanticSymbolQueryContext;
  lSource: string;
begin
  lPath := DeadCodeTempPath('dead-code-snapshot-source-text.pas');
  lSource :=
    'unit DeadCodeSnapshotSourceTextUnit;' + sLineBreak +
    'interface' + sLineBreak +
    'implementation' + sLineBreak +
    'procedure WindowHook(var Msg: Integer); message 1024;' + sLineBreak +
    'begin' + sLineBreak +
    'end;' + sLineBreak +
    'procedure ExportedHook;' + sLineBreak +
    'begin' + sLineBreak +
    'end;' + sLineBreak +
    'procedure InitializedHook;' + sLineBreak +
    'begin' + sLineBreak +
    'end;' + sLineBreak +
    'procedure FinalizedHook;' + sLineBreak +
    'begin' + sLineBreak +
    'end;' + sLineBreak +
    'exports' + sLineBreak +
    '  ExportedHook;' + sLineBreak +
    'initialization' + sLineBreak +
    '  InitializedHook;' + sLineBreak +
    'finalization' + sLineBreak +
    '  FinalizedHook;' + sLineBreak +
    'end.';
  TFile.WriteAllText(lPath, lSource, TEncoding.UTF8);

  lModelOptions := Default(TDelphiSemanticModelOptions);
  lModelOptions.SourceFileName := lPath;
  lModelOptions.ProjectContextApplied := True;
  lContext := Default(TDelphiSemanticSymbolQueryContext);
  lContext.UnitModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lModelOptions);
  Assert.IsTrue(lContext.UnitModel.Success);

  lBuildOptions := Default(TDelphiSnapshotBuildOptions);
  lRemoveWithFacts := Default(TDelphiSemanticProjectWithBindingFacts);
  lSnapshot := BuildProjectSnapshotFromModels([lContext.UnitModel], lRemoveWithFacts,
    lBuildOptions, lMetrics);
  lScopedContext := nil;
  try
    lMutatedSource := StringReplace(lSource, ' message 1024', '', []);
    lMutatedSource := StringReplace(lMutatedSource,
      'exports' + sLineBreak + '  ExportedHook;' + sLineBreak +
      'initialization' + sLineBreak + '  InitializedHook;' + sLineBreak +
      'finalization' + sLineBreak + '  FinalizedHook;' + sLineBreak, '', []);
    TFile.WriteAllText(lPath, lMutatedSource, TEncoding.UTF8);

    lScopedContext := TScopedSnapshotQueryContext.Create(lSnapshot);
    lSnapshotContext := lScopedContext.Context;

    lReport := TDelphiSemanticApi.ReportDeadCode(lSnapshotContext, 'audit');

    Assert.IsTrue(CandidateHasBlocker(lReport, 'WindowHook', 'message-method'),
      'Message method safety should use snapshot SourceText, not a disk reread.');
    Assert.IsTrue(CandidateHasBlocker(lReport, 'ExportedHook', 'exported-symbol'),
      'Export safety should use snapshot SourceText, not a disk reread.');
    Assert.IsTrue(CandidateHasBlocker(lReport, 'InitializedHook', 'initialization-hook'),
      'Initialization/finalization safety should use snapshot SourceText, not a disk reread.');
    Assert.IsTrue(CandidateHasBlocker(lReport, 'FinalizedHook', 'initialization-hook'),
      'Finalization safety should use snapshot SourceText, not a disk reread.');
  finally
    lScopedContext.Free;
    lSnapshot.Free;
  end;
end;

procedure TDeadCodeTests.UnknownReportProfileReturnsDiagnostic;
var
  lReport: TDelphiSemanticDeadCodeReport;
begin
  lReport := TDelphiSemanticApi.ReportDeadCode(LoadContext, 'typo');

  Assert.AreEqual('typo', lReport.Profile);
  Assert.AreEqual('Invalid dead-code profile: typo (expected audit, conservative, or legacy-static).',
    lReport.Diagnostic);
  Assert.AreEqual(0, Integer(Length(lReport.Candidates)));
end;

procedure TDeadCodeTests.ReportsDeadCodeFromSnapshotWithoutProjectIndexBuild;
var
  lBefore: string;
  lBuilder: TDelphiProjectSnapshotBuilder;
  lContext: TDelphiSemanticSymbolQueryContext;
  lFileName: string;
  lNameId: TSemanticStringId;
  lProject: TDelphiProjectSnapshot;
  lReport: TDelphiSemanticDeadCodeReport;
  lRootPath: string;
  lScopedContext: TScopedSnapshotQueryContext;
  lSymbol: TSemanticSymbolFact;
  lUnit: TUnitSnapshot;
begin
  lBuilder := TDelphiProjectSnapshotBuilder.Create;
  lProject := nil;
  lRootPath := '';
  try
    lRootPath := DeadCodeTempPath('snapshot-report');
    TDirectory.CreateDirectory(lRootPath);
    lFileName := TPath.Combine(lRootPath, 'SnapshotDeadCodeUnit.pas');
    TFile.WriteAllText(lFileName, 'unit SnapshotDeadCodeUnit;' + sLineBreak +
      'interface' + sLineBreak + 'implementation' + sLineBreak + 'var' +
      sLineBreak + '  SnapshotUnusedValue: Integer;' + sLineBreak + 'end.',
      TEncoding.UTF8);
    lBefore := TFile.ReadAllText(lFileName);

    lNameId := lBuilder.Strings.Intern('SnapshotUnusedValue');
    lUnit := TUnitSnapshot.Create(1, lBuilder.Strings.Intern(lFileName),
      lBuilder.Strings.Intern('SnapshotDeadCodeUnit'));
    try
      lSymbol := Default(TSemanticSymbolFact);
      lSymbol.NameId := lNameId;
      lSymbol.KindId := lBuilder.Strings.Intern('var');
      lSymbol.SectionKindId := lBuilder.Strings.Intern('implementation');
      lSymbol.SourceKindId := lBuilder.Strings.Intern('project-source');
      lSymbol.Line := 5;
      lSymbol.Column := 3;
      lSymbol.EndLine := 5;
      lSymbol.EndColumn := 21;
      lUnit.AddSymbol(lSymbol);

      lBuilder.AddUnit(lUnit);
      lUnit := nil;
    finally
      lUnit.Free;
    end;

    lProject := lBuilder.Build;
  finally
    lBuilder.Free;
  end;

  lScopedContext := TScopedSnapshotQueryContext.Create(lProject);
  try
    lContext := lScopedContext.Context;

    lReport := TDelphiSemanticApi.ReportDeadCode(lContext, 'audit');

    Assert.AreEqual('audit', lReport.Profile);
    Assert.AreEqual('definitely-unused', CandidateStatus(lReport, 'SnapshotUnusedValue'));
    Assert.AreEqual(0, lReport.IndexMetrics.BuildInvocationCount);
    Assert.AreEqual(lBefore, TFile.ReadAllText(lFileName));
  finally
    lScopedContext.Free;
    lProject.Free;
  end;
end;

procedure TDeadCodeTests.SnapshotReferenceCountsMatchModelBackedReport;
var
  lBuilder: TDelphiProjectSnapshotBuilder;
  lContext: TDelphiSemanticSymbolQueryContext;
  lDeclaration: TDelphiSemanticDeclaration;
  lDeclarations: TArray<TDelphiSemanticDeclaration>;
  lFileName: string;
  lIndex: TDelphiSemanticProjectSymbolIndex;
  lMap: TDictionary<string, TSemanticSymbolRef>;
  lModelReport: TDelphiSemanticDeadCodeReport;
  lNameId: TSemanticStringId;
  lProject: TDelphiProjectSnapshot;
  lReference: TDelphiSemanticReference;
  lScopedSnapshotContext: TScopedSnapshotQueryContext;
  lSnapshotContext: TDelphiSemanticSymbolQueryContext;
  lSnapshotReference: TSemanticReferenceFact;
  lSnapshotReport: TDelphiSemanticDeadCodeReport;
  lSnapshotSymbol: TSemanticSymbolFact;
  lSource: string;
  lSymbol: TDelphiSemanticIndexedSymbol;
  lSymbolRef: TSemanticSymbolRef;
  lTargetRef: TSemanticSymbolRef;
  lUnit: TUnitSnapshot;
begin
  lFileName := DeadCodeTempPath('snapshot-deadcode-parity-temp.pas');
  lSource := 'unit SnapshotDeadCodeParityUnit;' + sLineBreak + 'interface' +
    sLineBreak + 'implementation' + sLineBreak + 'var' + sLineBreak +
    '  SnapshotReferencedHook: Integer;' + sLineBreak +
    '  SnapshotUnusedParityValue: Integer;' + sLineBreak + 'initialization' +
    sLineBreak + '  SnapshotReferencedHook := 1;' + sLineBreak + 'end.';
  TFile.WriteAllText(lFileName, lSource, TEncoding.UTF8);
  lProject := nil;
  lScopedSnapshotContext := nil;
  lMap := TDictionary<string, TSemanticSymbolRef>.Create;
  lBuilder := TDelphiProjectSnapshotBuilder.Create;
  try
    // Low-level parity contract: this model-backed context intentionally has no project snapshot.
    lContext := Default(TDelphiSemanticSymbolQueryContext);
    lContext.UnitModel.UnitName := 'SnapshotDeadCodeParityUnit';
    lContext.UnitModel.FileName := lFileName;

    lDeclaration := Default(TDelphiSemanticDeclaration);
    lDeclaration.Name := 'SnapshotReferencedHook';
    lDeclaration.Kind := 'var';
    lDeclaration.SectionKind := 'implementation';
    lDeclaration.Line := 5;
    lDeclaration.Column := 3;
    lDeclarations := [lDeclaration];

    lDeclaration := Default(TDelphiSemanticDeclaration);
    lDeclaration.Name := 'SnapshotUnusedParityValue';
    lDeclaration.Kind := 'var';
    lDeclaration.SectionKind := 'implementation';
    lDeclaration.Line := 6;
    lDeclaration.Column := 3;
    lDeclarations := lDeclarations + [lDeclaration];
    lContext.UnitModel.Declarations := lDeclarations;

    lReference := Default(TDelphiSemanticReference);
    lReference.Name := 'SnapshotReferencedHook';
    lReference.SectionKind := 'implementation';
    lReference.Line := 8;
    lReference.Column := 3;
    lReference.EndLine := 8;
    lReference.EndColumn := 24;
    lContext.UnitModel.References := [lReference];

    lIndex := TDelphiSemanticProjectSymbolIndexer.Build(lContext);
    lModelReport := TDelphiSemanticApi.ReportDeadCode(lContext, 'audit');

    lUnit := TUnitSnapshot.Create(1, lBuilder.Strings.Intern(lFileName),
      lBuilder.Strings.Intern('SnapshotDeadCodeParityUnit'));
    try
      for lSymbol in lIndex.Symbols do
      begin
        if SameText(lSymbol.Kind, 'unit') then
          Continue;
        lSnapshotSymbol := Default(TSemanticSymbolFact);
        lSnapshotSymbol.NameId := lBuilder.Strings.Intern(lSymbol.Name);
        lSnapshotSymbol.KindId := lBuilder.Strings.Intern(lSymbol.Kind);
        lSnapshotSymbol.SectionKindId := lBuilder.Strings.Intern(lSymbol.SectionKind);
        lSnapshotSymbol.SourceKindId := lBuilder.Strings.Intern(lSymbol.SourceKind);
        lSnapshotSymbol.VisibilityId := lBuilder.Strings.Intern(lSymbol.Visibility);
        lSnapshotSymbol.Line := lSymbol.Line;
        lSnapshotSymbol.Column := lSymbol.Column;
        lSnapshotSymbol.EndLine := lSymbol.Line;
        lSnapshotSymbol.EndColumn := lSymbol.Column + Length(lSymbol.Name) - 1;
        lSymbolRef.UnitId := lUnit.UnitId;
        lSymbolRef.SymbolId := lUnit.AddSymbol(lSnapshotSymbol);
        lMap.Add(lSymbol.Id.Value, lSymbolRef);
      end;

      for lReference in lContext.UnitModel.References do
      begin
        lNameId := lBuilder.Strings.Intern(lReference.Name);
        lSnapshotReference := Default(TSemanticReferenceFact);
        lSnapshotReference.NameId := lNameId;
        lSnapshotReference.SectionKindId := lBuilder.Strings.Intern(lReference.SectionKind);
        lSnapshotReference.SourceKindId := lBuilder.Strings.Intern('project-source');
        lSnapshotReference.Line := lReference.Line;
        lSnapshotReference.Column := lReference.Column;
        lSnapshotReference.EndLine := lReference.EndLine;
        lSnapshotReference.EndColumn := lReference.EndColumn;
        for lSymbol in lIndex.Symbols do
          if SameText(lSymbol.Name, lReference.Name) and lMap.TryGetValue(
            lSymbol.Id.Value, lTargetRef) then
          begin
            lSnapshotReference.TargetUnitId := lTargetRef.UnitId;
            lSnapshotReference.TargetSymbolId := lTargetRef.SymbolId;
            Break;
          end;
        lUnit.AddReference(lSnapshotReference);
      end;

      lBuilder.AddUnit(lUnit);
      lUnit := nil;
    finally
      lUnit.Free;
    end;

    lProject := lBuilder.Build;
    lScopedSnapshotContext := TScopedSnapshotQueryContext.Create(lProject);
    lSnapshotContext := lScopedSnapshotContext.Context;
    lSnapshotReport := TDelphiSemanticApi.ReportDeadCode(lSnapshotContext, 'audit');

    Assert.AreEqual(CandidateStatus(lModelReport, 'SnapshotReferencedHook'),
      CandidateStatus(lSnapshotReport, 'SnapshotReferencedHook'));
    Assert.AreEqual(CandidateReferenceCount(lModelReport, 'SnapshotReferencedHook'),
      CandidateReferenceCount(lSnapshotReport, 'SnapshotReferencedHook'));
    Assert.AreEqual(CandidateStatus(lModelReport, 'SnapshotUnusedParityValue'),
      CandidateStatus(lSnapshotReport, 'SnapshotUnusedParityValue'));
    Assert.AreEqual(CandidateReferenceCount(lModelReport, 'SnapshotUnusedParityValue'),
      CandidateReferenceCount(lSnapshotReport, 'SnapshotUnusedParityValue'));
    Assert.AreEqual(0, lSnapshotReport.IndexMetrics.BuildInvocationCount);
  finally
    lScopedSnapshotContext.Free;
    lProject.Free;
    lBuilder.Free;
    lMap.Free;
    if TFile.Exists(lFileName) then
      TFile.Delete(lFileName);
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TDeadCodeTests);

end.
