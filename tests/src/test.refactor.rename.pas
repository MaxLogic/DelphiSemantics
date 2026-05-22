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
    function RenameUnblockFixturePath(const aFileName: string): string;
    function LoadRenameContext: TDelphiSemanticSymbolQueryContext;
    function LoadRenameComplexContext: TDelphiSemanticSymbolQueryContext;
    function LoadRenameForwardCommentContext: TDelphiSemanticSymbolQueryContext;
    function LoadRenameNestedAliasContext: TDelphiSemanticSymbolQueryContext;
    function LoadRenameRoutineContext: TDelphiSemanticSymbolQueryContext;
    function LoadRenameTypeContext: TDelphiSemanticSymbolQueryContext;
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
    [Test]
    procedure PlansRoutineRenameAcrossDeclarationImplementationAndCall;
    [Test]
    procedure PlansRoutineRenameFromHeaderPosition;
    [Test]
    procedure ApiFacadePlansRenameFromHeaderPosition;
    [Test]
    procedure PlansTypeRenameForDeclarationSideReferences;
    [Test]
    procedure PlansClassMethodRenameFromInterfaceHeaderPosition;
    [Test]
    procedure PlansClassMethodRenameFromQualifiedCallPosition;
    [Test]
    procedure PlansFieldRenameFromBodyReferencePosition;
    [Test]
    procedure PlansLocalVariableRenameWithinOwningRoutineOnly;
    [Test]
    procedure PlansForwardRoutineRenameAfterCommentedRecordEndAcrossUnits;
    [Test]
    procedure PlansCrossUnitAliasRenameInsideNestedRoutineLocals;
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

function TRenamePlannerTests.LoadRenameTypeContext: TDelphiSemanticSymbolQueryContext;
var
  lCache: TDelphiSemanticUnitCache;
  lCacheOptions: TDelphiSemanticCacheOptions;
  lModelOptions: TDelphiSemanticModelOptions;
begin
  lCacheOptions := Default(TDelphiSemanticCacheOptions);
  lCacheOptions.CompilerProfileName := 'Delphi-12-Rename-Type-Unblock-v3';
  lCache := TDelphiSemanticUnitCache.Create(lCacheOptions);
  try
    lModelOptions := Default(TDelphiSemanticModelOptions);
    lModelOptions.SourceFileName := RenameUnblockFixturePath('RenameTypeUnit.pas');
    lModelOptions.ProjectContextApplied := True;
    Result.UnitModel := lCache.GetOrExtractUnitModel(lModelOptions);
    Result.CompilerProfile := Default(TDelphiSemanticCompilerProfile);
    Result.IndexedUnitModels := [];
    Result.IndexedUnitSourceKinds := [];
    Result.CacheMetrics := lCache.Metrics;
  finally
    lCache.Free;
  end;
end;

function TRenamePlannerTests.RenameFixturePath(const aFileName: string): string;
begin
  Result := TPath.GetFullPath(CombinePath([ExtractFilePath(ParamStr(0)), '..', 'fixtures',
    'Rename', aFileName]));
end;

function TRenamePlannerTests.RenameUnblockFixturePath(const aFileName: string): string;
begin
  Result := TPath.GetFullPath(CombinePath([ExtractFilePath(ParamStr(0)), '..', 'fixtures',
    'RenameUnblock', aFileName]));
end;

function TRenamePlannerTests.LoadRenameComplexContext: TDelphiSemanticSymbolQueryContext;
var
  lCache: TDelphiSemanticUnitCache;
  lCacheOptions: TDelphiSemanticCacheOptions;
  lModelOptions: TDelphiSemanticModelOptions;
begin
  lCacheOptions := Default(TDelphiSemanticCacheOptions);
  lCacheOptions.CompilerProfileName := 'Delphi-12-Rename-Complex-v2';
  lCache := TDelphiSemanticUnitCache.Create(lCacheOptions);
  try
    lModelOptions := Default(TDelphiSemanticModelOptions);
    lModelOptions.SourceFileName := RenameUnblockFixturePath('RenameComplexUnit.pas');
    lModelOptions.ProjectContextApplied := True;
    Result.UnitModel := lCache.GetOrExtractUnitModel(lModelOptions);
    Result.CompilerProfile := Default(TDelphiSemanticCompilerProfile);
    Result.IndexedUnitModels := [];
    Result.IndexedUnitSourceKinds := [];
    Result.CacheMetrics := lCache.Metrics;
  finally
    lCache.Free;
  end;
end;

function TRenamePlannerTests.LoadRenameForwardCommentContext:
  TDelphiSemanticSymbolQueryContext;
var
  lCache: TDelphiSemanticUnitCache;
  lCacheOptions: TDelphiSemanticCacheOptions;
  lModelOptions: TDelphiSemanticModelOptions;
begin
  lCacheOptions := Default(TDelphiSemanticCacheOptions);
  lCacheOptions.CompilerProfileName := 'Delphi-12-Rename-Forward-Comment-v1';
  lCache := TDelphiSemanticUnitCache.Create(lCacheOptions);
  try
    lModelOptions := Default(TDelphiSemanticModelOptions);
    lModelOptions.SourceFileName := RenameUnblockFixturePath(
      'RenameForwardCommentProviderUnit.pas');
    lModelOptions.ProjectContextApplied := True;
    Result.UnitModel := lCache.GetOrExtractUnitModel(lModelOptions);
    Result.CompilerProfile := TDelphiSemanticCompilerProfileBuilder.FromCachedSources(lCache,
      [RenameUnblockFixturePath('RenameForwardCommentConsumerUnit.pas')]);
    Result.IndexedUnitModels := Result.CompilerProfile.RtlSourceUnitModels;
    Result.IndexedUnitSourceKinds := ['project-source'];
    Result.CacheMetrics := lCache.Metrics;
  finally
    lCache.Free;
  end;
end;

function TRenamePlannerTests.LoadRenameNestedAliasContext: TDelphiSemanticSymbolQueryContext;
var
  lCache: TDelphiSemanticUnitCache;
  lCacheOptions: TDelphiSemanticCacheOptions;
  lModelOptions: TDelphiSemanticModelOptions;
begin
  lCacheOptions := Default(TDelphiSemanticCacheOptions);
  lCacheOptions.CompilerProfileName := 'Delphi-12-Rename-Nested-Alias-v1';
  lCache := TDelphiSemanticUnitCache.Create(lCacheOptions);
  try
    lModelOptions := Default(TDelphiSemanticModelOptions);
    lModelOptions.SourceFileName := RenameUnblockFixturePath('RenameAliasProviderUnit.pas');
    lModelOptions.ProjectContextApplied := True;
    Result.UnitModel := lCache.GetOrExtractUnitModel(lModelOptions);
    Result.CompilerProfile := TDelphiSemanticCompilerProfileBuilder.FromCachedSources(lCache,
      [RenameUnblockFixturePath('RenameAliasConsumerUnit.pas')]);
    Result.IndexedUnitModels := Result.CompilerProfile.RtlSourceUnitModels;
    Result.IndexedUnitSourceKinds := ['project-source'];
    Result.CacheMetrics := lCache.Metrics;
  finally
    lCache.Free;
  end;
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

function TRenamePlannerTests.LoadRenameRoutineContext: TDelphiSemanticSymbolQueryContext;
var
  lCache: TDelphiSemanticUnitCache;
  lCacheOptions: TDelphiSemanticCacheOptions;
  lModelOptions: TDelphiSemanticModelOptions;
begin
  lCacheOptions := Default(TDelphiSemanticCacheOptions);
  lCacheOptions.CompilerProfileName := 'Delphi-12-Rename-Routine-Unblock-v3';
  lCache := TDelphiSemanticUnitCache.Create(lCacheOptions);
  try
    lModelOptions := Default(TDelphiSemanticModelOptions);
    lModelOptions.SourceFileName := RenameUnblockFixturePath('RenameRoutineUnit.pas');
    lModelOptions.ProjectContextApplied := True;
    Result.UnitModel := lCache.GetOrExtractUnitModel(lModelOptions);
    Result.CompilerProfile := TDelphiSemanticCompilerProfileBuilder.FromCachedSources(lCache,
      [RenameUnblockFixturePath('RenameRoutineConsumerUnit.pas')]);
    Result.IndexedUnitModels := Result.CompilerProfile.RtlSourceUnitModels;
    Result.IndexedUnitSourceKinds := ['project-source'];
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

procedure TRenamePlannerTests.PlansRoutineRenameAcrossDeclarationImplementationAndCall;
var
  lContext: TDelphiSemanticSymbolQueryContext;
  lEdit: TDelphiSemanticTextEdit;
  lFoundCall: Boolean;
  lFoundDeclaration: Boolean;
  lFoundImplementation: Boolean;
  lPlan: TDelphiSemanticRenamePlan;
begin
  lFoundCall := False;
  lFoundDeclaration := False;
  lFoundImplementation := False;
  lContext := LoadRenameRoutineContext;

  lPlan := TDelphiSemanticRenamePlanner.PlanRename(lContext, 'RoutineTarget',
    'RenamedRoutineTarget');

  Assert.AreEqual('planned', lPlan.Status, lPlan.Diagnostic);
  Assert.AreEqual(3, Length(lPlan.Edits));
  for lEdit in lPlan.Edits do
  begin
    Assert.AreEqual('RenamedRoutineTarget', lEdit.NewText);
    if ContainsText(lEdit.FileName, 'RenameRoutineUnit.pas') and (lEdit.StartLine = 8) then
    begin
      Assert.AreEqual(10, lEdit.StartColumn, 'Expected interface header edit at routine identifier.');
      lFoundDeclaration := True
    end
    else if ContainsText(lEdit.FileName, 'RenameRoutineUnit.pas') and (lEdit.StartLine = 12) then
    begin
      Assert.AreEqual(10, lEdit.StartColumn, 'Expected implementation header edit at routine identifier.');
      lFoundImplementation := True
    end
    else if ContainsText(lEdit.FileName, 'RenameRoutineConsumerUnit.pas') and
      (lEdit.StartLine = 12) then
      lFoundCall := True
    else
      Assert.Fail('Unexpected edit: ' + lEdit.FileName + ':' + IntToStr(lEdit.StartLine));
  end;

  Assert.IsTrue(lFoundDeclaration, 'Expected routine interface declaration edit.');
  Assert.IsTrue(lFoundImplementation, 'Expected routine implementation header edit.');
  Assert.IsTrue(lFoundCall, 'Expected cross-unit routine call edit.');
end;

procedure TRenamePlannerTests.PlansRoutineRenameFromHeaderPosition;
var
  lContext: TDelphiSemanticSymbolQueryContext;
  lEdit: TDelphiSemanticTextEdit;
  lFoundImplementation: Boolean;
  lPlan: TDelphiSemanticRenamePlan;
begin
  lFoundImplementation := False;
  lContext := LoadRenameRoutineContext;

  lPlan := TDelphiSemanticRenamePlanner.PlanRenameAtPosition(lContext,
    RenameUnblockFixturePath('RenameRoutineUnit.pas'), 12, 10, 'RenamedRoutineTarget');

  Assert.AreEqual('planned', lPlan.Status, lPlan.Diagnostic);
  Assert.AreEqual(3, Length(lPlan.Edits));
  for lEdit in lPlan.Edits do
    if ContainsText(lEdit.FileName, 'RenameRoutineUnit.pas') and (lEdit.StartLine = 12) then
      lFoundImplementation := True;
  Assert.IsTrue(lFoundImplementation, 'Expected implementation header edit from header position.');
end;

procedure TRenamePlannerTests.ApiFacadePlansRenameFromHeaderPosition;
var
  lContext: TDelphiSemanticSymbolQueryContext;
  lPlan: DelphiSemantics.Api.TDelphiSemanticRenamePlan;
begin
  lContext := LoadRenameRoutineContext;

  lPlan := TDelphiSemanticApi.PlanRenameAtPosition(lContext,
    RenameUnblockFixturePath('RenameRoutineUnit.pas'), 8, 10, 'RenamedRoutineTarget');

  Assert.AreEqual('planned', lPlan.Status, lPlan.Diagnostic);
  Assert.AreEqual(3, Length(lPlan.Edits));
end;

procedure TRenamePlannerTests.PlansTypeRenameForDeclarationSideReferences;
var
  lContext: TDelphiSemanticSymbolQueryContext;
  lEdit: TDelphiSemanticTextEdit;
  lLine16Count: Integer;
  lLine17Count: Integer;
  lLine21Count: Integer;
  lLine23Count: Integer;
  lLine27Count: Integer;
  lLine29Count: Integer;
  lLine6Count: Integer;
  lLine9Count: Integer;
  lLine10Count: Integer;
  lLine11Count: Integer;
  lLine13Count: Integer;
  lPlan: TDelphiSemanticRenamePlan;
begin
  lLine6Count := 0;
  lLine9Count := 0;
  lLine10Count := 0;
  lLine11Count := 0;
  lLine13Count := 0;
  lLine16Count := 0;
  lLine17Count := 0;
  lLine21Count := 0;
  lLine23Count := 0;
  lLine27Count := 0;
  lLine29Count := 0;
  lContext := LoadRenameTypeContext;

  lPlan := TDelphiSemanticRenamePlanner.PlanRename(lContext, 'TSharedType',
    'TRenamedSharedType');

  Assert.AreEqual('planned', lPlan.Status, lPlan.Diagnostic);
  Assert.AreEqual(15, Length(lPlan.Edits));
  for lEdit in lPlan.Edits do
  begin
    Assert.AreEqual('TRenamedSharedType', lEdit.NewText);
    Assert.IsTrue(ContainsText(lEdit.FileName, 'RenameTypeUnit.pas'));
    case lEdit.StartLine of
      6:
      begin
        Assert.AreEqual(3, lEdit.StartColumn);
        Inc(lLine6Count);
      end;
      9:
      begin
        Assert.AreEqual(19, lEdit.StartColumn);
        Inc(lLine9Count);
      end;
      10:
      begin
        Assert.AreEqual(19, lEdit.StartColumn);
        Inc(lLine10Count);
      end;
      11:
      begin
        Assert.AreEqual(28, lEdit.StartColumn);
        Inc(lLine11Count);
      end;
      13:
      begin
        Assert.AreEqual(12, lEdit.StartColumn);
        Inc(lLine13Count);
      end;
      16:
      begin
        Assert.IsTrue((lEdit.StartColumn = 39) or (lEdit.StartColumn = 53),
          'Expected distinct class method parameter/return columns.');
        Inc(lLine16Count);
      end;
      17:
      begin
        Assert.IsTrue((lEdit.StartColumn = 29) or (lEdit.StartColumn = 43),
          'Expected distinct indexed property parameter/type columns.');
        Inc(lLine17Count);
      end;
      21:
      begin
        Assert.AreEqual(18, lEdit.StartColumn);
        Inc(lLine21Count);
      end;
      23:
      begin
        Assert.IsTrue((lEdit.StartColumn = 30) or (lEdit.StartColumn = 44),
          'Expected distinct interface parameter/return columns.');
        Inc(lLine23Count);
      end;
      27:
      begin
        Assert.IsTrue((lEdit.StartColumn = 30) or (lEdit.StartColumn = 44),
          'Expected distinct implementation parameter/return columns.');
        Inc(lLine27Count);
      end;
      29:
      begin
        Assert.AreEqual(12, lEdit.StartColumn);
        Inc(lLine29Count);
      end;
    else
      Assert.Fail('Unexpected type rename edit line: ' + IntToStr(lEdit.StartLine));
    end;
  end;

  Assert.AreEqual(1, lLine6Count, 'Expected type declaration edit.');
  Assert.AreEqual(1, lLine9Count, 'Expected pointer alias type reference edit.');
  Assert.AreEqual(1, lLine10Count, 'Expected plain alias type reference edit.');
  Assert.AreEqual(1, lLine11Count, 'Expected array alias type reference edit.');
  Assert.AreEqual(1, lLine13Count, 'Expected record field type reference edit.');
  Assert.AreEqual(2, lLine16Count, 'Expected class method parameter and return type edits.');
  Assert.AreEqual(2, lLine17Count, 'Expected indexed property parameter and value type edits.');
  Assert.AreEqual(1, lLine21Count, 'Expected global variable type reference edit.');
  Assert.AreEqual(2, lLine23Count, 'Expected interface parameter and return type edits.');
  Assert.AreEqual(2, lLine27Count, 'Expected implementation parameter and return type edits.');
  Assert.AreEqual(1, lLine29Count, 'Expected local variable type reference edit.');
end;

procedure TRenamePlannerTests.PlansClassMethodRenameFromInterfaceHeaderPosition;
var
  lContext: TDelphiSemanticSymbolQueryContext;
  lEdit: TDelphiSemanticTextEdit;
  lFoundCall: Boolean;
  lFoundImplementation: Boolean;
  lFoundInterface: Boolean;
  lPlan: TDelphiSemanticRenamePlan;
begin
  lFoundCall := False;
  lFoundImplementation := False;
  lFoundInterface := False;
  lContext := LoadRenameComplexContext;

  lPlan := TDelphiSemanticRenamePlanner.PlanRenameAtPosition(lContext,
    RenameUnblockFixturePath('RenameComplexUnit.pas'), 12, 14, 'RunTask');

  Assert.AreEqual('planned', lPlan.Status, lPlan.Diagnostic);
  Assert.AreEqual(3, Length(lPlan.Edits));
  for lEdit in lPlan.Edits do
  begin
    Assert.AreEqual('RunTask', lEdit.NewText);
    Assert.IsTrue(ContainsText(lEdit.FileName, 'RenameComplexUnit.pas'));
    if lEdit.StartLine = 12 then
    begin
      Assert.AreEqual(14, lEdit.StartColumn);
      lFoundInterface := True
    end else if lEdit.StartLine = 21 then
    begin
      Assert.AreEqual(18, lEdit.StartColumn);
      lFoundImplementation := True
    end else if lEdit.StartLine = 43 then
      lFoundCall := True
    else
      Assert.Fail('Unexpected class method rename edit line: ' + IntToStr(lEdit.StartLine));
  end;

  Assert.IsTrue(lFoundInterface, 'Expected interface method declaration edit.');
  Assert.IsTrue(lFoundImplementation, 'Expected implementation method header edit.');
  Assert.IsTrue(lFoundCall, 'Expected qualified instance method call edit.');
end;

procedure TRenamePlannerTests.PlansClassMethodRenameFromQualifiedCallPosition;
var
  lContext: TDelphiSemanticSymbolQueryContext;
  lEdit: TDelphiSemanticTextEdit;
  lFoundCall: Boolean;
  lPlan: TDelphiSemanticRenamePlan;
begin
  lFoundCall := False;
  lContext := LoadRenameComplexContext;

  lPlan := TDelphiSemanticRenamePlanner.PlanRenameAtPosition(lContext,
    RenameUnblockFixturePath('RenameComplexUnit.pas'), 44, 30, 'MakeValue');

  Assert.AreEqual('planned', lPlan.Status, lPlan.Diagnostic);
  Assert.AreEqual(3, Length(lPlan.Edits));
  for lEdit in lPlan.Edits do
  begin
    Assert.AreEqual('MakeValue', lEdit.NewText);
    if lEdit.StartLine = 44 then
      lFoundCall := True;
  end;
  Assert.IsTrue(lFoundCall, 'Expected class-qualified method call edit.');
end;

procedure TRenamePlannerTests.PlansFieldRenameFromBodyReferencePosition;
var
  lContext: TDelphiSemanticSymbolQueryContext;
  lEdit: TDelphiSemanticTextEdit;
  lFoundDeclaration: Boolean;
  lFoundReference: Boolean;
  lPlan: TDelphiSemanticRenamePlan;
begin
  lFoundDeclaration := False;
  lFoundReference := False;
  lContext := LoadRenameComplexContext;

  lPlan := TDelphiSemanticRenamePlanner.PlanRenameAtPosition(lContext,
    RenameUnblockFixturePath('RenameComplexUnit.pas'), 26, 3, 'fLastValue');

  Assert.AreEqual('planned', lPlan.Status, lPlan.Diagnostic);
  Assert.AreEqual(2, Length(lPlan.Edits));
  for lEdit in lPlan.Edits do
  begin
    Assert.AreEqual('fLastValue', lEdit.NewText);
    if lEdit.StartLine = 10 then
      lFoundDeclaration := True
    else if lEdit.StartLine = 26 then
      lFoundReference := True
    else
      Assert.Fail('Unexpected field rename edit line: ' + IntToStr(lEdit.StartLine));
  end;

  Assert.IsTrue(lFoundDeclaration, 'Expected field declaration edit.');
  Assert.IsTrue(lFoundReference, 'Expected field body reference edit.');
end;

procedure TRenamePlannerTests.PlansLocalVariableRenameWithinOwningRoutineOnly;
var
  lContext: TDelphiSemanticSymbolQueryContext;
  lEdit: TDelphiSemanticTextEdit;
  lLine23Count: Integer;
  lLine25Count: Integer;
  lLine26Count: Integer;
  lLine27Count: Integer;
  lPlan: TDelphiSemanticRenamePlan;
begin
  lLine23Count := 0;
  lLine25Count := 0;
  lLine26Count := 0;
  lLine27Count := 0;
  lContext := LoadRenameComplexContext;

  lPlan := TDelphiSemanticRenamePlanner.PlanRenameAtPosition(lContext,
    RenameUnblockFixturePath('RenameComplexUnit.pas'), 25, 4, 'lTaskCounter');

  Assert.AreEqual('planned', lPlan.Status, lPlan.Diagnostic);
  Assert.AreEqual(4, Length(lPlan.Edits));
  for lEdit in lPlan.Edits do
  begin
    Assert.AreEqual('lTaskCounter', lEdit.NewText);
    Assert.IsTrue(ContainsText(lEdit.FileName, 'RenameComplexUnit.pas'));
    case lEdit.StartLine of
      23: Inc(lLine23Count);
      25: Inc(lLine25Count);
      26: Inc(lLine26Count);
      27: Inc(lLine27Count);
      37, 39, 41:
        Assert.Fail('Rename crossed into the same-named local in UseWorker.');
    else
      Assert.Fail('Unexpected local rename edit line: ' + IntToStr(lEdit.StartLine));
    end;
  end;

  Assert.AreEqual(1, lLine23Count, 'Expected local declaration edit.');
  Assert.AreEqual(1, lLine25Count, 'Expected first local assignment edit.');
  Assert.AreEqual(1, lLine26Count, 'Expected field assignment local edit.');
  Assert.AreEqual(1, lLine27Count, 'Expected function result local edit.');
end;

procedure TRenamePlannerTests.PlansForwardRoutineRenameAfterCommentedRecordEndAcrossUnits;
var
  lContext: TDelphiSemanticSymbolQueryContext;
  lEdit: TDelphiSemanticTextEdit;
  lLine17Count: Integer;
  lLine21Count: Integer;
  lLine23Count: Integer;
  lLine16Count: Integer;
  lPlan: TDelphiSemanticRenamePlan;
begin
  lLine17Count := 0;
  lLine21Count := 0;
  lLine23Count := 0;
  lLine16Count := 0;
  lContext := LoadRenameForwardCommentContext;

  lPlan := TDelphiSemanticRenamePlanner.PlanRename(lContext,
    'ForwardAfterCommentedRecord', 'RenamedForwardAfterCommentedRecord');

  Assert.AreEqual('planned', lPlan.Status, lPlan.Diagnostic);
  Assert.AreEqual(4, Length(lPlan.Edits));
  for lEdit in lPlan.Edits do
  begin
    Assert.AreEqual('RenamedForwardAfterCommentedRecord', lEdit.NewText);
    if ContainsText(lEdit.FileName, 'RenameForwardCommentProviderUnit.pas') then
    begin
      case lEdit.StartLine of
        17: Inc(lLine17Count);
        21: Inc(lLine21Count);
        23: Inc(lLine23Count);
      else
        Assert.Fail('Unexpected provider routine edit line: ' + IntToStr(lEdit.StartLine));
      end;
    end else if ContainsText(lEdit.FileName, 'RenameForwardCommentConsumerUnit.pas') then
    begin
      if lEdit.StartLine = 16 then
        Inc(lLine16Count)
      else
        Assert.Fail('Unexpected consumer routine edit line: ' + IntToStr(lEdit.StartLine));
    end else
      Assert.Fail('Unexpected routine edit file: ' + lEdit.FileName);
  end;

  Assert.AreEqual(1, lLine17Count, 'Expected interface routine declaration edit.');
  Assert.AreEqual(1, lLine21Count, 'Expected implementation routine header edit.');
  Assert.AreEqual(1, lLine23Count, 'Expected function-result assignment edit.');
  Assert.AreEqual(1, lLine16Count, 'Expected cross-unit call edit.');
end;

procedure TRenamePlannerTests.PlansCrossUnitAliasRenameInsideNestedRoutineLocals;
var
  lContext: TDelphiSemanticSymbolQueryContext;
  lEdit: TDelphiSemanticTextEdit;
  lLine9Count: Integer;
  lLine16Count: Integer;
  lPlan: TDelphiSemanticRenamePlan;
begin
  lLine9Count := 0;
  lLine16Count := 0;
  lContext := LoadRenameNestedAliasContext;

  lPlan := TDelphiSemanticRenamePlanner.PlanRename(lContext, 'TSourceAliasPtr',
    'TRenamedSourceAliasPtr');

  Assert.AreEqual('planned', lPlan.Status, lPlan.Diagnostic);
  Assert.AreEqual(2, Length(lPlan.Edits));
  for lEdit in lPlan.Edits do
  begin
    Assert.AreEqual('TRenamedSourceAliasPtr', lEdit.NewText);
    if ContainsText(lEdit.FileName, 'RenameAliasProviderUnit.pas') and
      (lEdit.StartLine = 9) then
      Inc(lLine9Count)
    else if ContainsText(lEdit.FileName, 'RenameAliasConsumerUnit.pas') and
      (lEdit.StartLine = 16) then
      Inc(lLine16Count)
    else
      Assert.Fail('Unexpected alias rename edit: ' + lEdit.FileName + ':' +
        IntToStr(lEdit.StartLine));
  end;

  Assert.AreEqual(1, lLine9Count, 'Expected alias declaration edit.');
  Assert.AreEqual(1, lLine16Count, 'Expected nested routine local type reference edit.');
end;

initialization
  TDUnitX.RegisterTestFixture(TRenamePlannerTests);

end.
