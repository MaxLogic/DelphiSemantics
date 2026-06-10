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
    function FixturePath(const aFileName: string): string;
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
    procedure UnsupportedSyntaxBlocksUnsafeLineDeletion;
  end;

implementation

uses
  System.IOUtils, System.StrUtils, System.SysUtils,
  maxLogic.IOUtils;

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

function TRemoveDeadCodePlannerTests.FixturePath(const aFileName: string): string;
begin
  Result := TPath.GetFullPath(CombinePath([ExtractFilePath(ParamStr(0)), '..', 'fixtures',
    'DeadCode', aFileName]));
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
  lLines := TFile.ReadAllLines(FixturePath('DeadCodeUnit.pas'));
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
    lModelOptions.SourceFileName := FixturePath('DeadCodeUnit.pas');
    lModelOptions.ProjectContextApplied := True;
    Result.UnitModel := lCache.GetOrExtractUnitModel(lModelOptions);
    Result.CompilerProfile := TDelphiSemanticCompilerProfileBuilder.FromCachedSources(lCache,
      [FixturePath('DeadCodeOtherUnit.pas')]);
    lModelOptions := Default(TDelphiSemanticModelOptions);
    lModelOptions.SourceFileName := FixturePath('DeadCodeRtlUnit.pas');
    lModelOptions.ProjectContextApplied := True;
    Result.IndexedUnitModels := Result.CompilerProfile.RtlSourceUnitModels +
      [lCache.GetOrExtractUnitModel(lModelOptions)];
    Result.IndexedUnitSourceKinds := ['project-source', 'rtl-source'];
    Result.CacheMetrics := lCache.Metrics;
  finally
    lCache.Free;
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
  lFileName := FixturePath('DeadCodeUnit.pas');
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
    lRootPath := TPath.GetFullPath(TPath.Combine(ExtractFilePath(ParamStr(0)),
      'snapshot-remove-deadcode-temp'));
    if TDirectory.Exists(lRootPath) then
      TDirectory.Delete(lRootPath, True);
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
    if (lRootPath <> '') and TDirectory.Exists(lRootPath) then
      TDirectory.Delete(lRootPath, True);
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
  Assert.AreEqual(FixturePath('DeadCodeUnit.pas'), lEdit.FileName);
  Assert.AreEqual('remove-dead-code', lEdit.Role);
  Assert.AreEqual(LineOf('MaybeDynamicHook'), lEdit.StartLine);
  Assert.AreEqual(1, lEdit.StartColumn);
  Assert.AreEqual(LineOf('MaybeDynamicHook') + 4, lEdit.EndLine);
  Assert.AreEqual(1, lEdit.EndColumn);
  Assert.AreEqual('', lEdit.NewText);
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
