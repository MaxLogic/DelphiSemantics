unit Test.Refactor.RemoveDeadCode;

interface

uses
  DUnitX.TestFramework,
  DelphiSemantics.Api,
  DelphiSemantics.Cache,
  DelphiSemantics.CompilerProfile,
  DelphiSemantics.Model,
  DelphiSemantics.Query,
  DelphiSemantics.Refactor,
  DelphiSemantics.Snapshot;

type
  [TestFixture]
  TRemoveDeadCodePlannerTests = class
  private
    function BlockerReason(const aPlan: TDelphiSemanticDeadCodeRemovalPlan;
      const aName: string): string;
    function EditAtLine(const aPlan: TDelphiSemanticDeadCodeRemovalPlan;
      const aLine: Integer): TDelphiSemanticTextEdit;
    function HasEditAtLine(const aPlan: TDelphiSemanticDeadCodeRemovalPlan;
      const aLine: Integer): Boolean;
    function LineOf(const aText: string): Integer;
    function LoadContext: TDelphiSemanticSymbolQueryContext;
  public
    [Test]
    procedure AuditProfileDoesNotPlanRemoval;
    [Test]
    procedure ConservativePlansOnlySimpleDefinitelyUnusedEdits;
    [Test]
    procedure ConservativePlansSnapshotBackedRemovalWithoutMutatingSource;
    [Test]
    procedure LegacyStaticPlansImplementationRoutineRemoval;
    [Test]
    procedure UnknownProfileBlocksRemovalWithDiagnostic;
    [Test]
    procedure UnsupportedSyntaxBlocksUnsafeLineDeletion;
    [Test]
    [TestCase('Snapshot, failed syntax tree', 'True,True')]
    [TestCase('Snapshot, verified control', 'True,False')]
    [TestCase('Unit model, failed syntax tree', 'False,True')]
    [TestCase('Unit model, verified control', 'False,False')]
    procedure UnverifiedUnitMembersAreNotDeadCode(const aSnapshot, aFailed: Boolean);
    [Test]
    procedure LegacyStaticNeverRemovesInitializerOrInactiveUses;
  end;

implementation

uses
  System.IOUtils, System.StrUtils, System.SysUtils,
  Winapi.Windows,
  maxLogic.IOUtils,
  DelphiSemantics.DeadCode, DelphiSemantics.ProjectContext, DelphiSemantics.ProjectSession,
  Test.Support;

var
  GRemoveDeadCodeTempRoot: string;

function RemoveDeadCodeTempPath(const aName: string): string;
var
  lGuid: TGUID;
  lGuidText: string;
begin
  if GRemoveDeadCodeTempRoot = '' then
  begin
    CreateGUID(lGuid);
    lGuidText := StringReplace(StringReplace(GUIDToString(lGuid), '{', '', [rfReplaceAll]), '}',
      '', [rfReplaceAll]);
    GRemoveDeadCodeTempRoot := TPath.GetFullPath(CombinePath([ExtractFilePath(ParamStr(0)),
      'snapshot-remove-deadcode-temp', 'run-' + GetCurrentProcessId.ToString + '-' + lGuidText]));
  end;
  TDirectory.CreateDirectory(GRemoveDeadCodeTempRoot);
  Result := TPath.Combine(GRemoveDeadCodeTempRoot, aName);
end;

function TRemoveDeadCodePlannerTests.BlockerReason(
  const aPlan: TDelphiSemanticDeadCodeRemovalPlan; const aName: string): string;
var
  lBlocker: TDelphiSemanticDeadCodeRemovalBlocker;
begin
  for lBlocker in aPlan.Blockers do
    if SameText(lBlocker.Name, aName) then
      Exit(lBlocker.Reason);

  Result := '';
end;

function TRemoveDeadCodePlannerTests.EditAtLine(const aPlan:
  TDelphiSemanticDeadCodeRemovalPlan; const aLine: Integer): TDelphiSemanticTextEdit;
var
  lEdit: TDelphiSemanticTextEdit;
begin
  for lEdit in aPlan.Edits do
    if lEdit.StartLine = aLine then
      Exit(lEdit);

  Result := Default(TDelphiSemanticTextEdit);
end;


function TRemoveDeadCodePlannerTests.HasEditAtLine(
  const aPlan: TDelphiSemanticDeadCodeRemovalPlan; const aLine: Integer): Boolean;
begin
  Result := EditAtLine(aPlan, aLine).FileName <> '';
end;

function TRemoveDeadCodePlannerTests.LineOf(const aText: string): Integer;
var
  i: Integer;
  lLines: TArray<string>;
begin
  lLines := TFile.ReadAllLines(FixturePath('DeadCode', 'DeadCodeUnit.pas'));
  for i := 0 to High(lLines) do
    if ContainsText(lLines[i], aText) then
      Exit(i + 1);

  Result := 0;
end;

function TRemoveDeadCodePlannerTests.LoadContext: TDelphiSemanticSymbolQueryContext;
var
  lCache: TDelphiSemanticUnitCache;
  lCacheOptions: TDelphiSemanticCacheOptions;
  lModelOptions: TDelphiSemanticModelOptions;
begin
  lCacheOptions := Default(TDelphiSemanticCacheOptions);
  lCacheOptions.CompilerProfileName := 'Delphi-12-RemoveDeadCode';
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

// UProv compiles, but the syntax tree builder rejects the one-character deprecation message, so
// FUnused is only an unverified fallback member. A zero reference count proves nothing there.
procedure TRemoveDeadCodePlannerTests.UnverifiedUnitMembersAreNotDeadCode(const aSnapshot,
  aFailed: Boolean);
var
  lCacheMetrics: TDelphiSemanticCacheMetrics;
  lCandidate: TDelphiSemanticDeadCodeCandidate;
  lContext: TDelphiSemanticSymbolQueryContext;
  lDeprecation: string;
  lExtractionMilliseconds: Int64;
  lFound: Boolean;
  lModelOptions: TDelphiSemanticModelOptions;
  lOptions: TDelphiSemanticOptions;
  lProfile: string;
  lReport: TDelphiSemanticDeadCodeReport;
  lRootPath: string;
  lSessionResult: TDelphiSemanticProjectSessionResult;
  lUnitPath: string;
begin
  lRootPath := RemoveDeadCodeTempPath('unverified-' + BoolToStr(aSnapshot, True) + '-' +
    BoolToStr(aFailed, True));
  TDirectory.CreateDirectory(lRootPath);
  lUnitPath := TPath.Combine(lRootPath, 'UProv.pas');
  lDeprecation := '';
  if aFailed then
    lDeprecation := ' deprecated ''z'';';
  TFile.WriteAllText(lUnitPath, 'unit UProv;'#13#10'interface'#13#10'type'#13#10 +
    '  TA = class'#13#10'  private'#13#10'    FUnused: Integer;'#13#10'  public'#13#10 +
    '    FCounter: Integer;'#13#10'    procedure Y;' + lDeprecation + #13#10'  end;'#13#10 +
    'implementation'#13#10'procedure TA.Y;'#13#10'begin'#13#10'  FCounter := 1;'#13#10 +
    'end;'#13#10'end.'#13#10, TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRootPath, 'Prov.dpr'),
    'program Prov;'#13#10'uses UProv;'#13#10'begin'#13#10'end.', TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRootPath, 'Prov.dproj'),
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003"><PropertyGroup>' +
    '<MainSource>Prov.dpr</MainSource></PropertyGroup><ItemGroup>' +
    '<DCCReference Include="UProv.pas"/></ItemGroup></Project>', TEncoding.ASCII);

  lSessionResult := Default(TDelphiSemanticProjectSessionResult);
  if aSnapshot then
  begin
    lOptions := Default(TDelphiSemanticOptions);
    lOptions.ProjectPath := TPath.Combine(lRootPath, 'Prov.dproj');
    lSessionResult := TDelphiSemanticProjectSession.Open(lOptions);
    Assert.IsTrue(lSessionResult.Success);
    lContext := lSessionResult.Session.BuildSnapshotSymbolQueryContext(lCacheMetrics,
      lExtractionMilliseconds);
  end else
  begin
    lContext := Default(TDelphiSemanticSymbolQueryContext);
    lModelOptions := Default(TDelphiSemanticModelOptions);
    lModelOptions.SourceFileName := lUnitPath;
    lModelOptions.ProjectContextApplied := True;
    lContext.UnitModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lModelOptions);
  end;
  try
    for lProfile in TArray<string>.Create('legacy-static', 'conservative') do
    begin
      lReport := TDelphiSemanticDeadCodeReporter.Report(lContext, lProfile);
      lFound := False;
      for lCandidate in lReport.Candidates do
        if SameText(lCandidate.Name, 'FUnused') then
        begin
          lFound := True;
          if aFailed then
          begin
            Assert.AreEqual('blocked', lCandidate.Status, lProfile);
            Assert.AreEqual('unverified-scope-facts', lCandidate.Reason, lProfile);
            Assert.IsTrue(MatchText('unverified-scope-facts', lCandidate.Blockers), lProfile);
          end else
            Assert.AreEqual('definitely-unused', lCandidate.Status, lProfile);
        end;
      Assert.IsTrue(lFound, 'The private field must stay visible as a candidate: ' + lProfile);
    end;
  finally
    lContext.ProjectSnapshot := nil;
    lSessionResult.Session.Free;
  end;
end;

// DS-653 review: removing UMain.GLimit (used by `@GLimit`) still compiles and changes the
// output from 10 to 99; CLimit is used by a later constant and GHidden only in inactive code.
procedure TRemoveDeadCodePlannerTests.LegacyStaticNeverRemovesInitializerOrInactiveUses;
var
  lCacheMetrics: TDelphiSemanticCacheMetrics;
  lContext: TDelphiSemanticSymbolQueryContext;
  lEdit: TDelphiSemanticTextEdit;
  lEdits: string;
  lExtractionMilliseconds: Int64;
  lOptions: TDelphiSemanticOptions;
  lPlan: TDelphiSemanticDeadCodeRemovalPlan;
  lRootPath: string;
  lSessionResult: TDelphiSemanticProjectSessionResult;
begin
  lRootPath := RemoveDeadCodeTempPath('initializer-uses');
  TDirectory.Copy(FixturePath('DeadCodeInitializers', ''), lRootPath);
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := TPath.Combine(lRootPath, 'P.dproj');
  lSessionResult := TDelphiSemanticProjectSession.Open(lOptions);
  Assert.IsTrue(lSessionResult.Success);
  try
    lContext := lSessionResult.Session.BuildSnapshotSymbolQueryContext(lCacheMetrics,
      lExtractionMilliseconds);
    try
      lPlan := TDelphiSemanticApi.PlanDeadCodeRemoval(lContext, 'legacy-static');
      lEdits := '';
      for lEdit in lPlan.Edits do
        lEdits := lEdits + ExtractFileName(lEdit.FileName) + ':' + lEdit.StartLine.ToString + ' ';
      // UMain.pas lines 20, 23, 26 and 27 declare GLimit, GHidden, CLimit and CDouble.
      Assert.IsFalse(ContainsText(' ' + lEdits, ' UMain.pas:20 '), lEdits);
      Assert.IsFalse(ContainsText(' ' + lEdits, ' UMain.pas:23 '), lEdits);
      Assert.IsFalse(ContainsText(' ' + lEdits, ' UMain.pas:26 '), lEdits);
      Assert.IsFalse(ContainsText(' ' + lEdits, ' UMain.pas:27 '), lEdits);
    finally
      lContext.ProjectSnapshot := nil;
    end;
  finally
    lSessionResult.Session.Free;
  end;
end;

procedure TRemoveDeadCodePlannerTests.AuditProfileDoesNotPlanRemoval;
var
  lPlan: TDelphiSemanticDeadCodeRemovalPlan;
begin
  lPlan := TDelphiSemanticApi.PlanDeadCodeRemoval(LoadContext, 'audit');

  Assert.AreEqual('planned', lPlan.Status);
  Assert.AreEqual('audit', lPlan.Profile);
  Assert.AreEqual(0, Integer(Length(lPlan.Edits)));
  Assert.AreEqual('audit-profile', BlockerReason(lPlan, 'StaticUnusedValue'));
end;

procedure TRemoveDeadCodePlannerTests.ConservativePlansOnlySimpleDefinitelyUnusedEdits;
var
  lBefore: string;
  lEdit: TDelphiSemanticTextEdit;
  lFileName: string;
  lPlan: TDelphiSemanticDeadCodeRemovalPlan;
begin
  lFileName := FixturePath('DeadCode', 'DeadCodeUnit.pas');
  lBefore := TFile.ReadAllText(lFileName);

  lPlan := TDelphiSemanticApi.PlanDeadCodeRemoval(LoadContext, 'conservative');

  Assert.AreEqual('planned', lPlan.Status);
  Assert.AreEqual('conservative', lPlan.Profile);
  lEdit := EditAtLine(lPlan, LineOf('StaticUnusedValue'));
  Assert.AreEqual(lFileName, lEdit.FileName);
  Assert.AreEqual('remove-dead-code', lEdit.Role);
  Assert.AreEqual(LineOf('StaticUnusedValue'), lEdit.StartLine);
  Assert.AreEqual(1, lEdit.StartColumn);
  Assert.AreEqual(LineOf('StaticUnusedValue') + 1, lEdit.EndLine);
  Assert.AreEqual(1, lEdit.EndColumn);
  Assert.AreEqual('', lEdit.NewText);
  Assert.IsFalse(HasEditAtLine(lPlan, LineOf('MaybeDynamicHook')));
  Assert.AreEqual('profile-not-allowed', BlockerReason(lPlan, 'MaybeDynamicHook'));
  Assert.AreEqual('unsupported-owned-member', BlockerReason(lPlan, 'PrivateUnused'));
  Assert.AreEqual(lBefore, TFile.ReadAllText(lFileName));
end;

procedure TRemoveDeadCodePlannerTests.ConservativePlansSnapshotBackedRemovalWithoutMutatingSource;
var
  lBefore: string;
  lBuilder: TDelphiProjectSnapshotBuilder;
  lContext: TDelphiSemanticSymbolQueryContext;
  lFileName: string;
  lNameId: TSemanticStringId;
  lPlan: TDelphiSemanticDeadCodeRemovalPlan;
  lProject: TDelphiProjectSnapshot;
  lRootPath: string;
  lSymbol: TSemanticSymbolFact;
  lUnit: TUnitSnapshot;
begin
  lBuilder := TDelphiProjectSnapshotBuilder.Create;
  lProject := nil;
  lRootPath := '';
  try
    lRootPath := RemoveDeadCodeTempPath('snapshot-remove-deadcode');
    TDirectory.CreateDirectory(lRootPath);
    lFileName := TPath.Combine(lRootPath, 'SnapshotRemoveDeadCodeUnit.pas');
    TFile.WriteAllText(lFileName, 'unit SnapshotRemoveDeadCodeUnit;' + sLineBreak +
      'interface' + sLineBreak + 'implementation' + sLineBreak + 'var' +
      sLineBreak + '  SnapshotRemovalValue: Integer;' + sLineBreak +
      '  SnapshotKeptValue: Integer;' + sLineBreak + 'end.', TEncoding.UTF8);
    lBefore := TFile.ReadAllText(lFileName);

    lNameId := lBuilder.Strings.Intern('SnapshotRemovalValue');
    lUnit := TUnitSnapshot.Create(1, lBuilder.Strings.Intern(lFileName),
      lBuilder.Strings.Intern('SnapshotRemoveDeadCodeUnit'));
    try
      lSymbol := Default(TSemanticSymbolFact);
      lSymbol.NameId := lNameId;
      lSymbol.KindId := lBuilder.Strings.Intern('var');
      lSymbol.SectionKindId := lBuilder.Strings.Intern('implementation');
      lSymbol.SourceKindId := lBuilder.Strings.Intern('project-source');
      lSymbol.Line := 5;
      lSymbol.Column := 3;
      lSymbol.EndLine := 5;
      lSymbol.EndColumn := 22;
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

  try
    lContext := Default(TDelphiSemanticSymbolQueryContext);
    lContext.ProjectSnapshot := BorrowProjectSnapshot(lProject);

    lPlan := TDelphiSemanticApi.PlanDeadCodeRemoval(lContext, 'conservative');

    Assert.AreEqual('planned', lPlan.Status, lPlan.Diagnostic);
    Assert.AreEqual(1, Integer(Length(lPlan.Edits)));
    Assert.AreEqual('remove-dead-code', lPlan.Edits[0].Role);
    Assert.AreEqual(lBefore, TFile.ReadAllText(lFileName));
  finally
    lContext.ProjectSnapshot := nil;
    lProject.Free;
  end;
end;

procedure TRemoveDeadCodePlannerTests.LegacyStaticPlansImplementationRoutineRemoval;
var
  lEdit: TDelphiSemanticTextEdit;
  lPlan: TDelphiSemanticDeadCodeRemovalPlan;
begin
  lPlan := TDelphiSemanticApi.PlanDeadCodeRemoval(LoadContext, 'legacy-static');

  Assert.AreEqual('planned', lPlan.Status);
  Assert.AreEqual('legacy-static', lPlan.Profile);
  lEdit := EditAtLine(lPlan, LineOf('MaybeDynamicHook'));
  Assert.AreEqual(FixturePath('DeadCode', 'DeadCodeUnit.pas'), lEdit.FileName);
  Assert.AreEqual('remove-dead-code', lEdit.Role);
  Assert.AreEqual(LineOf('MaybeDynamicHook'), lEdit.StartLine);
  Assert.AreEqual(1, lEdit.StartColumn);
  Assert.AreEqual(LineOf('MaybeDynamicHook') + 4, lEdit.EndLine);
  Assert.AreEqual(1, lEdit.EndColumn);
  Assert.AreEqual('', lEdit.NewText);
end;

procedure TRemoveDeadCodePlannerTests.UnknownProfileBlocksRemovalWithDiagnostic;
var
  lPlan: TDelphiSemanticDeadCodeRemovalPlan;
begin
  lPlan := TDelphiSemanticApi.PlanDeadCodeRemoval(LoadContext, 'typo');

  Assert.AreEqual('blocked', lPlan.Status);
  Assert.AreEqual('typo', lPlan.Profile);
  Assert.AreEqual('Invalid dead-code profile: typo (expected audit, conservative, or legacy-static).',
    lPlan.Diagnostic);
  Assert.AreEqual(0, Integer(Length(lPlan.Edits)));
end;

procedure TRemoveDeadCodePlannerTests.UnsupportedSyntaxBlocksUnsafeLineDeletion;
var
  lPlan: TDelphiSemanticDeadCodeRemovalPlan;
begin
  lPlan := TDelphiSemanticApi.PlanDeadCodeRemoval(LoadContext, 'legacy-static');

  Assert.IsFalse(HasEditAtLine(lPlan, LineOf('CommaUnusedValue')));
  Assert.AreEqual('unsupported-syntax', BlockerReason(lPlan, 'CommaUnusedValue'));
  Assert.IsFalse(HasEditAtLine(lPlan, LineOf('LoneVarValue')));
  Assert.AreEqual('unsupported-syntax', BlockerReason(lPlan, 'LoneVarValue'));
  Assert.IsFalse(HasEditAtLine(lPlan, LineOf('CommentLoneValue')));
  Assert.AreEqual('unsupported-syntax', BlockerReason(lPlan, 'CommentLoneValue'));
  Assert.IsFalse(HasEditAtLine(lPlan, LineOf('ClassBoundaryValue')));
  Assert.AreEqual('unsupported-syntax', BlockerReason(lPlan, 'ClassBoundaryValue'));
  Assert.IsFalse(HasEditAtLine(lPlan, LineOf('ComplexLegacyHook')));
  Assert.AreEqual('unsupported-syntax', BlockerReason(lPlan, 'ComplexLegacyHook'));
end;

initialization
  TDUnitX.RegisterTestFixture(TRemoveDeadCodePlannerTests);

end.
