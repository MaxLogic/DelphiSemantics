unit Test.Refactor.Rename;

interface

uses
  DUnitX.TestFramework,
  DelphiSemantics.Api,
  DelphiSemantics.Cache,
  DelphiSemantics.CompilerProfile,
  DelphiSemantics.Model,
  DelphiSemantics.Query,
  DelphiSemantics.Refactor;

type
  [TestFixture]
  TRenamePlannerTests = class
  private
    function FixturePath(const aFileName: string): string;
    function LoadContext: TDelphiSemanticSymbolQueryContext;
    function RenameFixturePath(const aFileName: string): string;
    function LoadRenameContext: TDelphiSemanticSymbolQueryContext;
  public
    [Test]
    procedure PlansProjectWideRenameForUnambiguousSymbol;
    [Test]
    procedure BlocksCaseInsensitiveCollision;
    [Test]
    procedure BlocksLocalMemberAndUnitCollisions;
    [Test]
    procedure BlocksNonProjectUsage;
    [Test]
    procedure PlansCaseInsensitiveTargetAndReferencesAcrossUnits;
    [Test]
    procedure BlocksReservedWordRename;
    [Test]
    procedure ApiFacadePlansRename;
  end;

implementation

uses
  System.IOUtils, System.StrUtils, System.SysUtils,
  maxLogic.IOUtils;

function TRenamePlannerTests.FixturePath(const aFileName: string): string;
begin
  Result := TPath.GetFullPath(CombinePath([ExtractFilePath(ParamStr(0)), '..', 'fixtures',
    'SymbolQuery', aFileName]));
end;

function TRenamePlannerTests.RenameFixturePath(const aFileName: string): string;
begin
  Result := TPath.GetFullPath(CombinePath([ExtractFilePath(ParamStr(0)), '..', 'fixtures',
    'Rename', aFileName]));
end;

function TRenamePlannerTests.LoadContext: TDelphiSemanticSymbolQueryContext;
var
  lCache: TDelphiSemanticUnitCache;
  lCacheOptions: TDelphiSemanticCacheOptions;
  lModelOptions: TDelphiSemanticModelOptions;
begin
  lCacheOptions := Default(TDelphiSemanticCacheOptions);
  lCacheOptions.CompilerProfileName := 'Delphi-12-Rename';
  lCache := TDelphiSemanticUnitCache.Create(lCacheOptions);
  try
    lModelOptions := Default(TDelphiSemanticModelOptions);
    lModelOptions.SourceFileName := FixturePath('SymbolQueryUnit.pas');
    lModelOptions.ProjectContextApplied := True;
    Result.UnitModel := lCache.GetOrExtractUnitModel(lModelOptions);

    Result.CompilerProfile := TDelphiSemanticCompilerProfileBuilder.FromCachedSources(lCache,
      [FixturePath('SymbolQueryRtlUnit.pas')]);
    Result.IndexedUnitModels := Result.CompilerProfile.RtlSourceUnitModels;
    Result.CacheMetrics := lCache.Metrics;
  finally
    lCache.Free;
  end;
end;

function TRenamePlannerTests.LoadRenameContext: TDelphiSemanticSymbolQueryContext;
var
  lCache: TDelphiSemanticUnitCache;
  lCacheOptions: TDelphiSemanticCacheOptions;
  lModelOptions: TDelphiSemanticModelOptions;
begin
  lCacheOptions := Default(TDelphiSemanticCacheOptions);
  lCacheOptions.CompilerProfileName := 'Delphi-12-Rename-Shadow';
  lCache := TDelphiSemanticUnitCache.Create(lCacheOptions);
  try
    lModelOptions := Default(TDelphiSemanticModelOptions);
    lModelOptions.SourceFileName := RenameFixturePath('RenameUnit.pas');
    lModelOptions.ProjectContextApplied := True;
    Result.UnitModel := lCache.GetOrExtractUnitModel(lModelOptions);
    Result.CompilerProfile := TDelphiSemanticCompilerProfileBuilder.FromCachedSources(lCache,
      [RenameFixturePath('RenameConsumerUnit.pas')]);
    Result.IndexedUnitModels := Result.CompilerProfile.RtlSourceUnitModels;
    Result.IndexedUnitSourceKinds := ['project-source'];
    Result.CacheMetrics := lCache.Metrics;
  finally
    lCache.Free;
  end;
end;

procedure TRenamePlannerTests.PlansProjectWideRenameForUnambiguousSymbol;
var
  lContext: TDelphiSemanticSymbolQueryContext;
  lEdit: TDelphiSemanticTextEdit;
  lLine12Count: Integer;
  lLine18Count: Integer;
  lLine19Count: Integer;
  lLine28Count: Integer;
  lConsumerLine12Count: Integer;
  lFoundDeclaration: Boolean;
  lFoundReference: Boolean;
  lPlan: TDelphiSemanticRenamePlan;
begin
  lFoundDeclaration := False;
  lFoundReference := False;
  lLine12Count := 0;
  lLine18Count := 0;
  lLine19Count := 0;
  lLine28Count := 0;
  lConsumerLine12Count := 0;
  lContext := LoadRenameContext;

  lPlan := TDelphiSemanticRenamePlanner.PlanRename(lContext, 'GlobalQueryValue',
    'RenamedGlobalQueryValue');

  Assert.AreEqual('planned', lPlan.Status);
  Assert.AreEqual(3, Length(lPlan.Edits));
  for lEdit in lPlan.Edits do
  begin
    Assert.AreEqual('RenamedGlobalQueryValue', lEdit.NewText);
    Assert.IsTrue(lEdit.StartLine > 0);
    Assert.IsTrue(lEdit.StartColumn > 0);
    Assert.IsTrue(lEdit.EndLine > 0);
    Assert.IsTrue(lEdit.EndColumn >= lEdit.StartColumn);
    if SameText(lEdit.Role, 'declaration') then
      lFoundDeclaration := True
    else if SameText(lEdit.Role, 'reference') then
      lFoundReference := True;
    if (lEdit.StartLine = 12) and ContainsText(lEdit.FileName, 'RenameUnit.pas') then
      Inc(lLine12Count)
    else if (lEdit.StartLine = 18) and ContainsText(lEdit.FileName, 'RenameUnit.pas') then
      Inc(lLine18Count)
    else if (lEdit.StartLine = 19) and ContainsText(lEdit.FileName, 'RenameUnit.pas') then
      Inc(lLine19Count)
    else if (lEdit.StartLine = 28) and ContainsText(lEdit.FileName, 'RenameUnit.pas') then
      Inc(lLine28Count)
    else if (lEdit.StartLine = 12) and ContainsText(lEdit.FileName, 'RenameConsumerUnit.pas') then
      Inc(lConsumerLine12Count)
    else
      Assert.Fail('Unexpected edit: ' + lEdit.FileName + ':' + IntToStr(lEdit.StartLine));
  end;

  Assert.IsTrue(lFoundDeclaration);
  Assert.IsTrue(lFoundReference);
  Assert.AreEqual(1, lLine12Count);
  Assert.AreEqual(0, lLine18Count);
  Assert.AreEqual(1, lLine19Count);
  Assert.AreEqual(0, lLine28Count);
  Assert.AreEqual(1, lConsumerLine12Count);
end;

procedure TRenamePlannerTests.BlocksCaseInsensitiveCollision;
var
  lContext: TDelphiSemanticSymbolQueryContext;
  lPlan: TDelphiSemanticRenamePlan;
begin
  lContext := LoadContext;

  lPlan := TDelphiSemanticRenamePlanner.PlanRename(lContext, 'GlobalQueryValue',
    'TSYMBOLMAPFIXTURE');

  Assert.AreEqual('blocked', lPlan.Status);
  Assert.IsTrue(ContainsText(lPlan.Diagnostic, 'collision'));
  Assert.AreEqual(0, Length(lPlan.Edits));
end;

procedure TRenamePlannerTests.BlocksLocalMemberAndUnitCollisions;
var
  lContext: TDelphiSemanticSymbolQueryContext;
  lPlan: TDelphiSemanticRenamePlan;
begin
  lContext := LoadRenameContext;

  lPlan := TDelphiSemanticRenamePlanner.PlanRename(lContext, 'GlobalQueryValue',
    'ExistingLocalName');
  Assert.AreEqual('blocked', lPlan.Status);
  Assert.IsTrue(ContainsText(lPlan.Diagnostic, 'collision'));

  lPlan := TDelphiSemanticRenamePlanner.PlanRename(lContext, 'GlobalQueryValue',
    'ExistingMember');
  Assert.AreEqual('blocked', lPlan.Status);
  Assert.IsTrue(ContainsText(lPlan.Diagnostic, 'collision'));

  lPlan := TDelphiSemanticRenamePlanner.PlanRename(lContext, 'GlobalQueryValue',
    'RenameConsumerUnit');
  Assert.AreEqual('blocked', lPlan.Status);
  Assert.IsTrue(ContainsText(lPlan.Diagnostic, 'collision'));
end;

procedure TRenamePlannerTests.BlocksNonProjectUsage;
var
  lContext: TDelphiSemanticSymbolQueryContext;
  lPlan: TDelphiSemanticRenamePlan;
begin
  lContext := LoadRenameContext;
  lContext.IndexedUnitSourceKinds := ['rtl-source'];

  lPlan := TDelphiSemanticRenamePlanner.PlanRename(lContext, 'GlobalQueryValue',
    'RenamedGlobalQueryValue');

  Assert.AreEqual('blocked', lPlan.Status);
  Assert.IsTrue(ContainsText(lPlan.Diagnostic, 'non-project usage'));
  Assert.AreEqual(0, Length(lPlan.Edits));
end;

procedure TRenamePlannerTests.PlansCaseInsensitiveTargetAndReferencesAcrossUnits;
var
  lContext: TDelphiSemanticSymbolQueryContext;
  lEdit: TDelphiSemanticTextEdit;
  lFoundConsumerReference: Boolean;
  lPlan: TDelphiSemanticRenamePlan;
begin
  lFoundConsumerReference := False;
  lContext := LoadRenameContext;

  lPlan := TDelphiSemanticRenamePlanner.PlanRename(lContext, 'globalqueryvalue',
    'RenamedGlobalQueryValue');

  Assert.AreEqual('planned', lPlan.Status);
  Assert.AreEqual(3, Length(lPlan.Edits));
  for lEdit in lPlan.Edits do
    if ContainsText(lEdit.FileName, 'RenameConsumerUnit.pas') and
      (lEdit.StartLine = 12) then
      lFoundConsumerReference := True;
  Assert.IsTrue(lFoundConsumerReference);
end;

procedure TRenamePlannerTests.BlocksReservedWordRename;
var
  lContext: TDelphiSemanticSymbolQueryContext;
  lPlan: TDelphiSemanticRenamePlan;
begin
  lContext := LoadContext;

  lPlan := TDelphiSemanticRenamePlanner.PlanRename(lContext, 'GlobalQueryValue', 'class');

  Assert.AreEqual('blocked', lPlan.Status);
  Assert.IsTrue(ContainsText(lPlan.Diagnostic, 'valid Delphi identifier'));
  Assert.AreEqual(0, Length(lPlan.Edits));
end;

procedure TRenamePlannerTests.ApiFacadePlansRename;
var
  lContext: TDelphiSemanticSymbolQueryContext;
  lPlan: DelphiSemantics.Api.TDelphiSemanticRenamePlan;
begin
  lContext := LoadRenameContext;

  lPlan := TDelphiSemanticApi.PlanRename(lContext, 'GlobalQueryValue',
    'RenamedGlobalQueryValue');

  Assert.AreEqual('planned', lPlan.Status);
  Assert.AreEqual(3, Length(lPlan.Edits));
end;

initialization
  TDUnitX.RegisterTestFixture(TRenamePlannerTests);

end.
