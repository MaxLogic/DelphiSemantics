unit Test.Refactor.Rename;

interface

uses
  DUnitX.TestFramework,
  DelphiSemantics.Api,
  DelphiSemantics.Cache,
  DelphiSemantics.CompilerProfile,
  DelphiSemantics.Index,
  DelphiSemantics.Model,
  DelphiSemantics.Query,
  DelphiSemantics.Refactor,
  DelphiSemantics.Snapshot;

type
  [TestFixture]
  TRenamePlannerTests = class
  private
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
    procedure RenamePlanContractDeclaresStaleEditGuards;
    [Test]
    procedure PlansRenameWithOneProjectIndexBuild;
    [Test]
    procedure PlansRenameFromSnapshotWithoutProjectIndexBuild;
    [Test]
    procedure SkipsRoutineScopedVarShadowFromSnapshotContext;
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

  // DS-652/DAK-392: a rename plan holds every reference DelphiSemantics can prove, and a
  // same-name occurrence it cannot classify makes the plan incomplete instead of planned.
  [TestFixture]
  TRenameCompletenessTests = class
  public
    [Test]
    procedure PlansQualifiedMemberReferencesInConsumerUnit;
    [Test]
    procedure PlansSelfAndInheritedMemberReferencesInDescendantUnit;
    [Test]
    procedure BindsWithBodyNamesToSelectorMembers;
    [Test]
    procedure PlansProgramMainBlockReferences;
    [Test]
    procedure PlansProgramGlobalDeclaredAfterRoutineWithSameNamedLocal;
    [Test]
    procedure ListsInjectedConflictingFacts;
    [Test]
    procedure PositionResolvesLocalNotEnclosingRoutine;
    [Test]
    procedure PlansGlobalWhoseNameIsALocalElsewhere;
    [Test]
    [TestCase('Class constant Limit', 'True')]
    [TestCase('No member named Limit', 'False')]
    procedure ListsWithBodyNameThatMayBeAnUnmodelledMember(const aHasConstant: Boolean);
    [Test]
    [TestCase('Ancestor outside the project', 'True')]
    [TestCase('Implicit TObject ancestor', 'False')]
    procedure ListsMethodNameThatMayBeAnUnprovenAncestorMember(const aRtlAncestor: Boolean);
    [Test]
    [TestCase('Member from an include file', 'include')]
    [TestCase('Member in a conditional branch', 'conditional')]
    [TestCase('Ancestor with an include file', 'ancestor-include')]
    [TestCase('I/O checking switch is not an include', 'switch')]
    procedure ListsWithBodyNameHiddenFromTheDeclarationText(const aShape: string);
    [Test]
    [TestCase('Class reference selector', 'class-of')]
    [TestCase('Forward-declared class selector control', 'forward')]
    procedure ListsWithBodyNameOfUndelimitedSelectorType(const aShape: string);
    [Test]
    procedure ListsUnresolvedOverloadCallsAndRefusesPlan;
    [Test]
    procedure ListsReferencesInAstFailedConsumerUnit;
    [Test]
    procedure VerifiedClassVariableControlPlansFully;
    [Test]
    [TestCase('Virtual base and override', 'True')]
    [TestCase('Static methods control', 'False')]
    procedure ListsPossibleOverridesOfVirtualMethods(const aVirtual: Boolean);
  end;

implementation

uses
  System.Generics.Collections, System.IOUtils, System.StrUtils, System.SysUtils,
  Winapi.Windows,
  maxLogic.IOUtils,
  DelphiSemantics.Model.Text, DelphiSemantics.ProjectContext, DelphiSemantics.ProjectSession,
  DelphiSemantics.Snapshot.Builder, DelphiSemantics.Usage, DelphiSemantics.WithBinding,
  Test.Support;

var
  GRenameTempRoot: string;

function RenameTempPath(const aName: string): string;
var
  lGuid: TGUID;
  lGuidText: string;
begin
  if GRenameTempRoot = '' then
  begin
    CreateGUID(lGuid);
    lGuidText := StringReplace(StringReplace(GUIDToString(lGuid), '{', '', [rfReplaceAll]), '}',
      '', [rfReplaceAll]);
    GRenameTempRoot := TPath.GetFullPath(CombinePath([ExtractFilePath(ParamStr(0)),
      'snapshot-rename-temp', 'run-' + GetCurrentProcessId.ToString + '-' + lGuidText]));
  end;
  TDirectory.CreateDirectory(GRenameTempRoot);
  Result := TPath.Combine(GRenameTempRoot, aName);
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
  Result := FixturePath('Rename', aFileName);
end;

function TRenamePlannerTests.RenameUnblockFixturePath(const aFileName: string): string;
begin
  Result := FixturePath('RenameUnblock', aFileName);
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
    lModelOptions.SourceFileName := FixturePath('SymbolQuery', 'SymbolQueryUnit.pas');
    lModelOptions.ProjectContextApplied := True;
    Result.UnitModel := lCache.GetOrExtractUnitModel(lModelOptions);

    Result.CompilerProfile := TDelphiSemanticCompilerProfileBuilder.FromCachedSources(lCache,
      [FixturePath('SymbolQuery', 'SymbolQueryRtlUnit.pas')]);
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
  Assert.AreEqual(3, Integer(Length(lPlan.Edits)));
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

procedure TRenamePlannerTests.RenamePlanContractDeclaresStaleEditGuards;
var
  lContext: TDelphiSemanticSymbolQueryContext;
  lEdit: TDelphiSemanticTextEdit;
  lPlan: TDelphiSemanticRenamePlan;
begin
  lContext := LoadRenameContext;

  lPlan := TDelphiSemanticRenamePlanner.PlanRename(lContext, 'GlobalQueryValue',
    'RenamedGlobalQueryValue');

  Assert.AreEqual('planned', lPlan.Status, lPlan.Diagnostic);
  Assert.IsNotEmpty(lPlan.ContextFingerprint,
    'Rename plans must carry semantic provenance for stale-plan diagnostics.');
  Assert.IsNotEmpty(lPlan.BaselineSemanticModelVersion,
    'Rename plans must carry the semantic model version used to produce edits.');
  Assert.IsTrue(Length(lPlan.RequiredVerification) >= 3,
    'Rename plans must declare source and context verification requirements.');
  for lEdit in lPlan.Edits do
  begin
    Assert.IsNotEmpty(lEdit.ExpectedFileHash,
      'Rename text edits must carry the source file hash expected at apply time.');
    Assert.AreEqual('GlobalQueryValue', lEdit.ExpectedSourceText,
      'Rename text edits must carry the source span expected at apply time.');
  end;
end;

procedure TRenamePlannerTests.PlansRenameWithOneProjectIndexBuild;
var
  lContext: TDelphiSemanticSymbolQueryContext;
  lPlan: TDelphiSemanticRenamePlan;
begin
  lContext := LoadContext;

  lPlan := TDelphiSemanticRenamePlanner.PlanRename(lContext, 'GlobalQueryValue',
    'RenamedGlobalQueryValue');

  Assert.AreEqual('planned', lPlan.Status);
  Assert.AreEqual(1, lPlan.IndexMetrics.BuildInvocationCount);
end;

procedure TRenamePlannerTests.PlansRenameFromSnapshotWithoutProjectIndexBuild;
var
  lBuilder: TDelphiProjectSnapshotBuilder;
  lContext: TDelphiSemanticSymbolQueryContext;
  lFileName: string;
  lNameId: TSemanticStringId;
  lPlan: TDelphiSemanticRenamePlan;
  lProject: TDelphiProjectSnapshot;
  lReference: TSemanticReferenceFact;
  lRootPath: string;
  lSymbol: TSemanticSymbolFact;
  lSymbolId: TSemanticSymbolId;
  lUnit: TUnitSnapshot;
begin
  lBuilder := TDelphiProjectSnapshotBuilder.Create;
  lProject := nil;
  lRootPath := '';
  try
    lRootPath := RenameTempPath('snapshot-rename');
    TDirectory.CreateDirectory(lRootPath);
    lFileName := TPath.Combine(lRootPath, 'SnapshotRenameUnit.pas');
    TFile.WriteAllText(lFileName, 'unit SnapshotRenameUnit;' + sLineBreak +
      'interface' + sLineBreak + 'var' + sLineBreak +
      '  SnapshotRenameValue: Integer;' + sLineBreak + 'implementation' + sLineBreak +
      'procedure Touch;' + sLineBreak + 'begin' + sLineBreak +
      '  SnapshotRenameValue := 1;' + sLineBreak + 'end;' + sLineBreak + 'end.',
      TEncoding.UTF8);

    lNameId := lBuilder.Strings.Intern('SnapshotRenameValue');
    lUnit := TUnitSnapshot.Create(1, lBuilder.Strings.Intern(lFileName),
      lBuilder.Strings.Intern('SnapshotRenameUnit'));
    try
      lSymbol := Default(TSemanticSymbolFact);
      lSymbol.NameId := lNameId;
      lSymbol.KindId := lBuilder.Strings.Intern('var');
      lSymbol.SectionKindId := lBuilder.Strings.Intern('implementation');
      lSymbol.SourceKindId := lBuilder.Strings.Intern('project-source');
      lSymbol.Line := 4;
      lSymbol.Column := 3;
      lSymbol.EndLine := 4;
      lSymbol.EndColumn := 21;
      lSymbolId := lUnit.AddSymbol(lSymbol);

      lReference := Default(TSemanticReferenceFact);
      lReference.NameId := lNameId;
      lReference.TargetUnitId := lUnit.UnitId;
      lReference.TargetSymbolId := lSymbolId;
      lReference.RoutineId := lBuilder.Strings.Intern('Touch');
      lReference.SectionKindId := lBuilder.Strings.Intern('implementation');
      lReference.SourceKindId := lBuilder.Strings.Intern('project-source');
      lReference.Line := 8;
      lReference.Column := 3;
      lReference.EndLine := 8;
      lReference.EndColumn := 21;
      lUnit.AddReference(lReference);

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

    lPlan := TDelphiSemanticRenamePlanner.PlanRename(lContext, 'SnapshotRenameValue',
      'SnapshotRenamedValue');

    Assert.AreEqual('planned', lPlan.Status, lPlan.Diagnostic);
    Assert.AreEqual(2, Integer(Length(lPlan.Edits)));
    Assert.AreEqual(0, lPlan.IndexMetrics.BuildInvocationCount);
    Assert.IsNotEmpty(lPlan.ContextFingerprint);
    Assert.AreEqual('project-snapshot-v1', lPlan.BaselineSemanticModelVersion);
    Assert.AreEqual('SnapshotRenameValue', lPlan.Edits[0].ExpectedSourceText);
    Assert.IsNotEmpty(lPlan.Edits[0].ExpectedFileHash);
  finally
    lContext.ProjectSnapshot := nil;
    lProject.Free;
  end;
end;

procedure TRenamePlannerTests.SkipsRoutineScopedVarShadowFromSnapshotContext;
var
  lBuilder: TDelphiProjectSnapshotBuilder;
  lContext: TDelphiSemanticSymbolQueryContext;
  lFileName: string;
  lNameId: TSemanticStringId;
  lPlan: TDelphiSemanticRenamePlan;
  lProject: TDelphiProjectSnapshot;
  lReference: TSemanticReferenceFact;
  lRootPath: string;
  lRoutineId: TSemanticStringId;
  lShadow: TSemanticSymbolFact;
  lSymbol: TSemanticSymbolFact;
  lSymbolId: TSemanticSymbolId;
  lUnit: TUnitSnapshot;
begin
  lBuilder := TDelphiProjectSnapshotBuilder.Create;
  lProject := nil;
  lRootPath := '';
  try
    lRootPath := RenameTempPath('snapshot-rename-shadow');
    TDirectory.CreateDirectory(lRootPath);
    lFileName := TPath.Combine(lRootPath, 'SnapshotRenameShadowUnit.pas');
    TFile.WriteAllText(lFileName, 'unit SnapshotRenameShadowUnit;' + sLineBreak +
      'interface' + sLineBreak + 'var' + sLineBreak +
      '  SnapshotShadowValue: Integer;' + sLineBreak + 'implementation' + sLineBreak +
      'procedure Touch;' + sLineBreak + 'var' + sLineBreak +
      '  SnapshotShadowValue: Integer;' + sLineBreak + 'begin' + sLineBreak +
      '  SnapshotShadowValue := 1;' + sLineBreak + 'end;' + sLineBreak + 'end.',
      TEncoding.UTF8);

    lNameId := lBuilder.Strings.Intern('SnapshotShadowValue');
    lRoutineId := lBuilder.Strings.Intern('Touch');
    lUnit := TUnitSnapshot.Create(1, lBuilder.Strings.Intern(lFileName),
      lBuilder.Strings.Intern('SnapshotRenameShadowUnit'));
    try
      lSymbol := Default(TSemanticSymbolFact);
      lSymbol.NameId := lNameId;
      lSymbol.KindId := lBuilder.Strings.Intern('var');
      lSymbol.SectionKindId := lBuilder.Strings.Intern('implementation');
      lSymbol.SourceKindId := lBuilder.Strings.Intern('project-source');
      lSymbol.Line := 4;
      lSymbol.Column := 3;
      lSymbol.EndLine := 4;
      lSymbol.EndColumn := 21;
      lSymbolId := lUnit.AddSymbol(lSymbol);

      lShadow := Default(TSemanticSymbolFact);
      lShadow.NameId := lNameId;
      lShadow.KindId := lBuilder.Strings.Intern('var');
      lShadow.RoutineId := lRoutineId;
      lShadow.SectionKindId := lBuilder.Strings.Intern('implementation');
      lShadow.SourceKindId := lBuilder.Strings.Intern('project-source');
      lShadow.Line := 8;
      lShadow.Column := 3;
      lShadow.EndLine := 8;
      lShadow.EndColumn := 21;
      lUnit.AddSymbol(lShadow);

      lReference := Default(TSemanticReferenceFact);
      lReference.NameId := lNameId;
      lReference.TargetUnitId := lUnit.UnitId;
      lReference.TargetSymbolId := lSymbolId;
      lReference.RoutineId := lRoutineId;
      lReference.SectionKindId := lBuilder.Strings.Intern('implementation');
      lReference.SourceKindId := lBuilder.Strings.Intern('project-source');
      lReference.Line := 10;
      lReference.Column := 3;
      lReference.EndLine := 10;
      lReference.EndColumn := 21;
      lUnit.AddReference(lReference);

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

    lPlan := TDelphiSemanticRenamePlanner.PlanRename(lContext, 'SnapshotShadowValue',
      'SnapshotRenamedValue');

    Assert.AreEqual('planned', lPlan.Status, lPlan.Diagnostic);
    Assert.AreEqual(1, Integer(Length(lPlan.Edits)),
      'The routine-scoped var should shadow the global inside Touch.');
    Assert.AreEqual(4, lPlan.Edits[0].StartLine);
    Assert.AreEqual(0, lPlan.IndexMetrics.BuildInvocationCount);
  finally
    lContext.ProjectSnapshot := nil;
    lProject.Free;
  end;
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
  Assert.AreEqual(0, Integer(Length(lPlan.Edits)));
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
  Assert.AreEqual(0, Integer(Length(lPlan.Edits)));
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
  Assert.AreEqual(3, Integer(Length(lPlan.Edits)));
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
  Assert.AreEqual(0, Integer(Length(lPlan.Edits)));
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
  Assert.AreEqual(3, Integer(Length(lPlan.Edits)));
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
  Assert.AreEqual(3, Integer(Length(lPlan.Edits)));
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
  Assert.AreEqual(3, Integer(Length(lPlan.Edits)));
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
  Assert.AreEqual(3, Integer(Length(lPlan.Edits)));
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
  Assert.AreEqual(15, Integer(Length(lPlan.Edits)));
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
        Assert.AreEqual(18, lEdit.StartColumn);
        Inc(lLine9Count);
      end;
      10:
      begin
        Assert.AreEqual(18, lEdit.StartColumn);
        Inc(lLine10Count);
      end;
      11:
      begin
        Assert.AreEqual(27, lEdit.StartColumn);
        Inc(lLine11Count);
      end;
      13:
      begin
        Assert.AreEqual(11, lEdit.StartColumn);
        Inc(lLine13Count);
      end;
      16:
      begin
        Assert.IsTrue((lEdit.StartColumn = 38) or (lEdit.StartColumn = 52),
          'Expected distinct class method parameter/return columns.');
        Inc(lLine16Count);
      end;
      17:
      begin
        Assert.IsTrue((lEdit.StartColumn = 28) or (lEdit.StartColumn = 42),
          'Expected distinct indexed property parameter/type columns.');
        Inc(lLine17Count);
      end;
      21:
      begin
        Assert.AreEqual(17, lEdit.StartColumn);
        Inc(lLine21Count);
      end;
      23:
      begin
        Assert.IsTrue((lEdit.StartColumn = 29) or (lEdit.StartColumn = 43),
          'Expected distinct interface parameter/return columns.');
        Inc(lLine23Count);
      end;
      27:
      begin
        Assert.IsTrue((lEdit.StartColumn = 29) or (lEdit.StartColumn = 43),
          'Expected distinct implementation parameter/return columns.');
        Inc(lLine27Count);
      end;
      29:
      begin
        Assert.AreEqual(11, lEdit.StartColumn);
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
  Assert.AreEqual(3, Integer(Length(lPlan.Edits)));
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
  Assert.AreEqual(3, Integer(Length(lPlan.Edits)));
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
  Assert.AreEqual(2, Integer(Length(lPlan.Edits)));
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
  Assert.AreEqual(4, Integer(Length(lPlan.Edits)));
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
  Assert.AreEqual(4, Integer(Length(lPlan.Edits)));
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
  Assert.AreEqual(2, Integer(Length(lPlan.Edits)));
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

const
  // Line 8 col 5 declares FCounter; line 9 col 15 declares the class var FTotal.
  cCompletenessProvider =
    'unit UProv;'#13#10 + #13#10 + 'interface'#13#10 + #13#10 + 'type'#13#10 +
    '  TA = class'#13#10 + '  public'#13#10 + '    FCounter: Integer;'#13#10 +
    '    class var FTotal: Integer;'#13#10 + '    procedure Bump;'#13#10 + '  end;'#13#10 +
    #13#10 + 'implementation'#13#10 + #13#10 + 'procedure TA.Bump;'#13#10 + 'begin'#13#10 +
    '  Self.FCounter := Self.FCounter + 1;'#13#10 + '  FCounter := FCounter + 1;'#13#10 +
    'end;'#13#10 + #13#10 + 'end.'#13#10;
  cCompletenessProgram =
    'program P;'#13#10 + #13#10 + 'uses'#13#10 + '  UProv in ''UProv.pas'','#13#10 +
    '  UCons in ''UCons.pas'';'#13#10 + #13#10 + 'begin'#13#10 + 'end.'#13#10;

type
  TCompletenessFile = record
    Name: string;
    Text: string;
  end;

function CompletenessFile(const aName, aText: string): TCompletenessFile;
begin
  Result.Name := aName;
  Result.Text := aText;
end;

// Writes P.dpr plus the units into a fresh folder and returns that folder.
function WriteCompletenessProject(const aFolder, aProgramText: string;
  const aUnits: array of TCompletenessFile): string;
var
  lReferences: string;
  lUnit: TCompletenessFile;
begin
  Result := RenameTempPath(aFolder);
  TDirectory.CreateDirectory(Result);
  TFile.WriteAllText(TPath.Combine(Result, 'P.dpr'), aProgramText, TEncoding.ASCII);
  lReferences := '';
  for lUnit in aUnits do
  begin
    TFile.WriteAllText(TPath.Combine(Result, lUnit.Name), lUnit.Text, TEncoding.ASCII);
    lReferences := lReferences + '<DCCReference Include="' + lUnit.Name + '"/>';
  end;
  TFile.WriteAllText(TPath.Combine(Result, 'P.dproj'),
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003"><PropertyGroup>' +
    '<MainSource>P.dpr</MainSource></PropertyGroup><ItemGroup>' + lReferences +
    '</ItemGroup></Project>', TEncoding.ASCII);
end;

function PlanCompletenessRename(const aRoot, aFileName: string; const aLine, aColumn: Integer;
  const aNewName: string): TDelphiSemanticRenamePlan;
var
  lCacheMetrics: TDelphiSemanticCacheMetrics;
  lContext: TDelphiSemanticSymbolQueryContext;
  lExtractionMilliseconds: Int64;
  lOptions: TDelphiSemanticOptions;
  lSessionResult: TDelphiSemanticProjectSessionResult;
begin
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := TPath.Combine(aRoot, 'P.dproj');
  lSessionResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lSessionResult.Success, 'Project session must open.');
    lContext := lSessionResult.Session.BuildSnapshotSymbolQueryContext(lCacheMetrics,
      lExtractionMilliseconds);
    try
      Assert.IsNotNull(lContext.ProjectSnapshot, 'Rename must run on the project snapshot.');
      Result := TDelphiSemanticRenamePlanner.PlanRenameAtPosition(lContext,
        TPath.Combine(aRoot, aFileName), aLine, aColumn, aNewName);
    finally
      lContext.ProjectSnapshot := nil;
    end;
  finally
    lSessionResult.Session.Free;
  end;
end;

function CompletenessKey(const aFileName: string; const aLine, aColumn: Integer): string;
begin
  Result := LowerCase(ExtractFileName(aFileName)) + ':' + aLine.ToString + ':' + aColumn.ToString;
end;

function SortedKeysText(const aKeys: TArray<string>): string;
var
  lKeys: TArray<string>;
begin
  lKeys := Copy(aKeys);
  TArray.Sort<string>(lKeys);
  Result := string.Join(' ', lKeys);
end;

// Every whole-word occurrence of aName in the listed fixture files, as file:line:column.
function OccurrenceKeys(const aRoot: string; const aFileNames: array of string;
  const aName: string): TArray<string>;
var
  lColumn: Integer;
  lFileName: string;
  lLine: Integer;
  lText: string;
  i: Integer;
begin
  Result := [];
  for lFileName in aFileNames do
  begin
    lText := SanitizeCodeText(TFile.ReadAllText(TPath.Combine(aRoot, lFileName)));
    lLine := 1;
    lColumn := 1;
    for i := 1 to Length(lText) do
    begin
      if IsWordAt(lText, i, aName) then
        Result := Result + [CompletenessKey(lFileName, lLine, lColumn)];
      if lText[i] = #10 then
      begin
        Inc(lLine);
        lColumn := 1;
      end else if lText[i] <> #13 then
        Inc(lColumn);
    end;
  end;
end;

function OccurrenceKeysExcept(const aKeys, aExcluded: TArray<string>): TArray<string>;
var
  lKey: string;
begin
  Result := [];
  for lKey in aKeys do
    if IndexText(lKey, aExcluded) < 0 then
      Result := Result + [lKey];
end;

function PlanEditKeys(const aPlan: TDelphiSemanticRenamePlan): TArray<string>;
var
  lEdit: TDelphiSemanticTextEdit;
begin
  Result := [];
  for lEdit in aPlan.Edits do
    Result := Result + [CompletenessKey(lEdit.FileName, lEdit.StartLine, lEdit.StartColumn)];
end;

function PlanUnresolvedKeys(const aPlan: TDelphiSemanticRenamePlan): TArray<string>;
var
  lUsage: TDelphiSemanticUsage;
begin
  Result := [];
  for lUsage in aPlan.UnresolvedReferences do
    Result := Result + [CompletenessKey(lUsage.FileName, lUsage.Line, lUsage.Column)];
end;

procedure AssertCompletePlan(const aPlan: TDelphiSemanticRenamePlan;
  const aExpectedKeys: TArray<string>; const aExpectedCount: Integer);
begin
  Assert.AreEqual('planned', aPlan.Status, aPlan.Diagnostic);
  // The literal count guards the occurrence scan itself against an empty or short fixture.
  Assert.AreEqual(aExpectedCount, Integer(Length(aExpectedKeys)), 'Fixture occurrence count');
  Assert.AreEqual(SortedKeysText(aExpectedKeys), SortedKeysText(PlanEditKeys(aPlan)));
  Assert.AreEqual(0, Integer(Length(aPlan.UnresolvedReferences)),
    'A complete plan lists no unresolved references: ' + SortedKeysText(PlanUnresolvedKeys(aPlan)));
end;

procedure TRenameCompletenessTests.PlansQualifiedMemberReferencesInConsumerUnit;
var
  lPlan: TDelphiSemanticRenamePlan;
  lRoot: string;
begin
  lRoot := WriteCompletenessProject('completeness-qualified', cCompletenessProgram,
    [CompletenessFile('UProv.pas', cCompletenessProvider), CompletenessFile('UCons.pas',
    'unit UCons;'#13#10'interface'#13#10'procedure Run;'#13#10'implementation'#13#10 +
    'uses'#13#10'  UProv;'#13#10'procedure Run;'#13#10'var'#13#10'  a: TA;'#13#10'begin'#13#10 +
    '  a := TA.Create;'#13#10'  try'#13#10'    a.FCounter := 5;'#13#10 +
    '    WriteLn(a.FCounter);'#13#10'  finally'#13#10'    a.Free;'#13#10'  end;'#13#10 +
    'end;'#13#10'end.'#13#10)]);

  lPlan := PlanCompletenessRename(lRoot, 'UProv.pas', 8, 5, 'FTally');

  AssertCompletePlan(lPlan, OccurrenceKeys(lRoot, ['UProv.pas', 'UCons.pas'], 'FCounter'), 7);
end;

procedure TRenameCompletenessTests.PlansSelfAndInheritedMemberReferencesInDescendantUnit;
var
  lPlan: TDelphiSemanticRenamePlan;
  lRoot: string;
begin
  lRoot := WriteCompletenessProject('completeness-self', cCompletenessProgram,
    [CompletenessFile('UProv.pas', cCompletenessProvider), CompletenessFile('UCons.pas',
    'unit UCons;'#13#10'interface'#13#10'uses'#13#10'  UProv;'#13#10'type'#13#10 +
    '  TB = class(TA)'#13#10'  public'#13#10'    procedure Touch;'#13#10'  end;'#13#10 +
    'implementation'#13#10'procedure TB.Touch;'#13#10'begin'#13#10 +
    '  Self.FCounter := 3;'#13#10'  FCounter := FCounter + 1;'#13#10'end;'#13#10 +
    'end.'#13#10)]);

  lPlan := PlanCompletenessRename(lRoot, 'UProv.pas', 8, 5, 'FTally');

  AssertCompletePlan(lPlan, OccurrenceKeys(lRoot, ['UProv.pas', 'UCons.pas'], 'FCounter'), 8);
end;

// The with body binds FCounter to TA.FCounter, not to the unit-level FCounter of UCons. Renaming
// either symbol must plan exactly its own occurrences.
procedure TRenameCompletenessTests.BindsWithBodyNamesToSelectorMembers;
var
  lAll: TArray<string>;
  lPlan: TDelphiSemanticRenamePlan;
  lRoot: string;
begin
  lRoot := WriteCompletenessProject('completeness-with', cCompletenessProgram,
    [CompletenessFile('UProv.pas', cCompletenessProvider), CompletenessFile('UCons.pas',
    'unit UCons;'#13#10'interface'#13#10'implementation'#13#10 +
    'uses'#13#10'  UProv;'#13#10'var'#13#10'  FCounter: Integer;'#13#10 +
    'procedure Other;'#13#10'begin'#13#10'  FCounter := 7;'#13#10'end;'#13#10 +
    'procedure Run;'#13#10'var'#13#10'  a: TA;'#13#10'begin'#13#10'  a := TA.Create;'#13#10 +
    '  with a do'#13#10'    FCounter := FCounter + 10;'#13#10'  a.Free;'#13#10'end;'#13#10 +
    'end.'#13#10)]);
  lAll := OccurrenceKeys(lRoot, ['UProv.pas', 'UCons.pas'], 'FCounter');

  lPlan := PlanCompletenessRename(lRoot, 'UProv.pas', 8, 5, 'FTally');
  AssertCompletePlan(lPlan, OccurrenceKeysExcept(lAll, ['ucons.pas:7:3', 'ucons.pas:10:3']), 7);

  lPlan := PlanCompletenessRename(lRoot, 'UCons.pas', 7, 3, 'GTally');
  AssertCompletePlan(lPlan, ['ucons.pas:7:3', 'ucons.pas:10:3'], 2);
end;

const
  cProgramGlobalAfterRoutine = 'program P;'#13#10 + #13#10 + // 1-2
    'procedure Touch;'#13#10'var'#13#10'  GValue: Integer;'#13#10 + // 3-5
    'begin'#13#10'  GValue := 2;'#13#10'end;'#13#10 + #13#10 + // 6-9
    'var'#13#10'  GValue: Integer;'#13#10'begin'#13#10'  GValue := 1;'#13#10'end.'#13#10; // 10-14

// DS-653: Touch's body ends at its own "end;", so the global declared after it and its main-block
// use belong to no routine. DS-652 refused both renames while those facts contradicted each other.
procedure TRenameCompletenessTests.PlansProgramGlobalDeclaredAfterRoutineWithSameNamedLocal;
var
  lPlan: TDelphiSemanticRenamePlan;
  lRoot: string;
begin
  lRoot := WriteCompletenessProject('completeness-contradiction', cProgramGlobalAfterRoutine, []);

  lPlan := PlanCompletenessRename(lRoot, 'P.dpr', 11, 3, 'GTally');
  AssertCompletePlan(lPlan, ['p.dpr:11:3', 'p.dpr:13:3'], 2);

  lPlan := PlanCompletenessRename(lRoot, 'P.dpr', 5, 3, 'LTally');
  AssertCompletePlan(lPlan, ['p.dpr:5:3', 'p.dpr:7:3'], 2);
end;

// DS-652 safety net: a reference fact sitting on another symbol's declaration contradicts it, so
// the plan lists that position instead of planning. The source no longer yields such facts, so
// the test injects one where the line scan used to put it.
procedure TRenameCompletenessTests.ListsInjectedConflictingFacts;
var
  lContext: TDelphiSemanticSymbolQueryContext;
  lFileName: string;
  lMetrics: TDelphiSnapshotBuilderMetrics;
  lModel: TDelphiSemanticUnitModel;
  lModelOptions: TDelphiSemanticModelOptions;
  lOptions: TDelphiSnapshotBuildOptions;
  lPlan: TDelphiSemanticRenamePlan;
  lReference: TDelphiSemanticReference;
  lSnapshot: TDelphiProjectSnapshot;
  lUsage: TDelphiSemanticUsage;
  lReasons: string;
begin
  lFileName := TPath.Combine(WriteCompletenessProject('completeness-injected-conflict',
    cProgramGlobalAfterRoutine, []), 'P.dpr');
  lModelOptions := Default(TDelphiSemanticModelOptions);
  lModelOptions.SourceFileName := lFileName;
  lModelOptions.ProjectContextApplied := True;
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lModelOptions);
  Assert.AreEqual('ast', lModel.ScopeModelStatus);
  // A main-block reference to GValue placed on the local declaration at 5:3.
  lReference := Default(TDelphiSemanticReference);
  lReference.Name := 'GValue';
  lReference.Role := 'reference';
  lReference.SectionKind := 'interface';
  lReference.Line := 5;
  lReference.Column := 3;
  lReference.EndLine := 5;
  lReference.EndColumn := 8;
  lModel.References := lModel.References + [lReference];

  lOptions := Default(TDelphiSnapshotBuildOptions);
  lOptions.ResolveReferenceTargets := True;
  lOptions.WorkerCount := 1;
  lSnapshot := BuildProjectSnapshotFromModels([lModel],
    Default(TDelphiSemanticProjectWithBindingFacts), lOptions, lMetrics);
  try
    lContext := Default(TDelphiSemanticSymbolQueryContext);
    lContext.ProjectSnapshot := BorrowProjectSnapshot(lSnapshot);
    lPlan := TDelphiSemanticRenamePlanner.PlanRenameAtPosition(lContext, lFileName, 11, 3,
      'GTally');
    Assert.AreEqual('incomplete', lPlan.Status, lPlan.Diagnostic);
    lReasons := '';
    for lUsage in lPlan.UnresolvedReferences do
      lReasons := lReasons + CompletenessKey(lUsage.FileName, lUsage.Line, lUsage.Column) + '=' +
        lUsage.Reason + ' ';
    Assert.AreEqual('p.dpr:5:3=conflicting-facts ', lReasons);
  finally
    lContext.ProjectSnapshot := nil;
    lSnapshot.Free;
  end;
end;

// Line 10 declares GValue after a program routine; the main block uses it on lines 13 and 15.
procedure TRenameCompletenessTests.PlansProgramMainBlockReferences;
var
  lPlan: TDelphiSemanticRenamePlan;
  lRoot: string;
begin
  lRoot := WriteCompletenessProject('completeness-program',
    'program P;'#13#10 + #13#10 + 'uses'#13#10 + '  UProv in ''UProv.pas'';'#13#10 + #13#10 +
    'procedure Touch;'#13#10'begin'#13#10'end;'#13#10'var'#13#10'  GValue: Integer;'#13#10 +
    '  GObj: TA;'#13#10'begin'#13#10'  GValue := 1;'#13#10'  GObj := TA.Create;'#13#10 +
    '  GObj.FCounter := GValue;'#13#10'  GObj.Free;'#13#10'end.'#13#10,
    [CompletenessFile('UProv.pas', cCompletenessProvider)]);

  lPlan := PlanCompletenessRename(lRoot, 'P.dpr', 10, 3, 'GTally');
  AssertCompletePlan(lPlan, OccurrenceKeys(lRoot, ['P.dpr'], 'GValue'), 3);

  lPlan := PlanCompletenessRename(lRoot, 'UProv.pas', 8, 5, 'FTally');
  AssertCompletePlan(lPlan, OccurrenceKeys(lRoot, ['UProv.pas', 'P.dpr'], 'FCounter'), 6);
end;

// The local GValue on line 8 sits inside Touch's range; resolving that position to Touch would
// rename the routine instead of the local. A position naming no symbol stays refused (DS-652).
procedure TRenameCompletenessTests.PositionResolvesLocalNotEnclosingRoutine;
var
  lPlan: TDelphiSemanticRenamePlan;
  lRoot: string;
begin
  lRoot := WriteCompletenessProject('completeness-enclosing-routine',
    'program P;'#13#10#13#10'var'#13#10'  GValue: Integer;'#13#10#13#10'procedure Touch;'#13#10 +
    'var'#13#10'  GValue: Integer;'#13#10'begin'#13#10'  GValue := 2;'#13#10'end;'#13#10#13#10 +
    'begin'#13#10'  GValue := 1;'#13#10'  Touch;'#13#10'end.'#13#10, []);

  // DS-653: the line index prefers the innermost symbol, so the position names the local.
  lPlan := PlanCompletenessRename(lRoot, 'P.dpr', 8, 3, 'LTally');
  AssertCompletePlan(lPlan, ['p.dpr:8:3', 'p.dpr:10:3'], 2);

  // Whitespace inside Touch's body names no symbol at all.
  lPlan := PlanCompletenessRename(lRoot, 'P.dpr', 10, 1, 'LTally');
  Assert.AreEqual('blocked', lPlan.Status, 'Whitespace must not rename the enclosing routine.');
  Assert.AreEqual(0, Integer(Length(lPlan.Edits)));
end;

// DS-653: the forward header of Work used to own the var section after it, so Work's uses of
// the global Counter bound to a phantom local. Each rename plans exactly its own occurrences.
procedure TRenameCompletenessTests.PlansGlobalWhoseNameIsALocalElsewhere;
var
  lAll: TArray<string>;
  lLocalKeys: TArray<string>;
  lPlan: TDelphiSemanticRenamePlan;
  lRoot: string;
begin
  lRoot := WriteCompletenessProject('completeness-body-bounds',
    'program P;'#13#10 + #13#10 + // 1-2
    'procedure Work; forward;'#13#10 + #13#10 + // 3-4
    'var'#13#10'  Counter: Integer;'#13#10 + #13#10 + // 5-7
    'procedure Helper;'#13#10'var'#13#10'  Counter: Integer;'#13#10 + // 8-10
    'begin'#13#10'  Counter := 5;'#13#10'  WriteLn(Counter);'#13#10'end;'#13#10 + #13#10 + // 11-15
    'procedure Work;'#13#10'begin'#13#10'  Counter := Counter + 1;'#13#10'end;'#13#10 + // 16-19
    #13#10'begin'#13#10'  Counter := 10;'#13#10'  Helper;'#13#10'  Work;'#13#10 + // 20-24
    '  WriteLn(Counter);'#13#10'end.'#13#10, []); // 25-26
  lAll := OccurrenceKeys(lRoot, ['P.dpr'], 'Counter');
  lLocalKeys := ['p.dpr:10:3', 'p.dpr:12:3', 'p.dpr:13:11'];

  lPlan := PlanCompletenessRename(lRoot, 'P.dpr', 6, 3, 'Total');
  AssertCompletePlan(lPlan, OccurrenceKeysExcept(lAll, lLocalKeys), 5);

  lPlan := PlanCompletenessRename(lRoot, 'P.dpr', 22, 3, 'Total');
  AssertCompletePlan(lPlan, OccurrenceKeysExcept(lAll, lLocalKeys), 5);

  lPlan := PlanCompletenessRename(lRoot, 'P.dpr', 10, 3, 'Own');
  AssertCompletePlan(lPlan, lLocalKeys, 3);
end;

// DS-652 review: the model records no class constants, so TA.Limit may own Limit in the with
// body. Renaming the local must list 20:14 instead of editing it; without such a member the
// local plans fully.
procedure TRenameCompletenessTests.ListsWithBodyNameThatMayBeAnUnmodelledMember(
  const aHasConstant: Boolean);
var
  lCacheMetrics: TDelphiSemanticCacheMetrics;
  lConstant: string;
  lContext: TDelphiSemanticSymbolQueryContext;
  lExtractionMilliseconds: Int64;
  lListed: Boolean;
  lOptions: TDelphiSemanticOptions;
  lPlan: TDelphiSemanticRenamePlan;
  lRoot: string;
  lSessionResult: TDelphiSemanticProjectSessionResult;
  lUsage: TDelphiSemanticUsage;
  lUsages: TDelphiSemanticUsageResult;
begin
  lConstant := '';
  if aHasConstant then
    lConstant := '  public const'#13#10'    Limit = 5;'#13#10;
  // UCons line 15 declares the local Limit; line 20 is "    Count := Limit;" in "with a do".
  lRoot := WriteCompletenessProject('completeness-with-constant-' + BoolToStr(aHasConstant, True),
    cCompletenessProgram, [CompletenessFile('UProv.pas', 'unit UProv;'#13#10#13#10 +
    'interface'#13#10#13#10'type'#13#10'  TA = class'#13#10 + lConstant + '  public'#13#10 +
    '    Count: Integer;'#13#10'  end;'#13#10#13#10'implementation'#13#10#13#10'end.'#13#10),
    CompletenessFile('UCons.pas', 'unit UCons;'#13#10#13#10'interface'#13#10#13#10 +
    'procedure Run;'#13#10#13#10'implementation'#13#10#13#10'uses'#13#10'  UProv;'#13#10#13#10 +
    'procedure Run;'#13#10'var'#13#10'  a: TA;'#13#10'  Limit: Integer;'#13#10'begin'#13#10 +
    '  Limit := 100;'#13#10'  a := TA.Create;'#13#10'  with a do'#13#10 +
    '    Count := Limit;'#13#10'  WriteLn(a.Count);'#13#10'end;'#13#10#13#10'end.'#13#10)]);

  lPlan := PlanCompletenessRename(lRoot, 'UCons.pas', 15, 3, 'LimX');

  if not aHasConstant then
  begin
    AssertCompletePlan(lPlan, OccurrenceKeys(lRoot, ['UCons.pas'], 'Limit'), 3);
    Exit;
  end;
  Assert.AreEqual('incomplete', lPlan.Status, lPlan.Diagnostic);
  Assert.AreEqual(SortedKeysText(['ucons.pas:15:3', 'ucons.pas:17:3']),
    SortedKeysText(PlanEditKeys(lPlan)), 'The with-body Limit must not be edited.');
  Assert.AreEqual('ucons.pas:20:14', SortedKeysText(PlanUnresolvedKeys(lPlan)));

  // Find-usages on the name cannot claim the with-body use either.
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := TPath.Combine(lRoot, 'P.dproj');
  lSessionResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    lContext := lSessionResult.Session.BuildSnapshotSymbolQueryContext(lCacheMetrics,
      lExtractionMilliseconds);
    try
      lUsages := TDelphiSemanticUsageFinder.FindUsagesAtPosition(lContext,
        TPath.Combine(lRoot, 'UCons.pas'), 15, 3);
      Assert.AreEqual('resolved', lUsages.Status, lUsages.Diagnostic);
      for lUsage in lUsages.Usages do
        Assert.IsFalse(lUsage.Line = 20, 'The with-body Limit is not a proven usage.');
      lListed := False;
      for lUsage in lUsages.Unresolved do
        lListed := lListed or ((lUsage.Line = 20) and (lUsage.Column = 14));
      Assert.IsTrue(lListed, 'The with-body Limit is listed as unresolved.');
    finally
      lContext.ProjectSnapshot := nil;
    end;
  finally
    lSessionResult.Session.Free;
  end;
end;

// DS-652 review round 2: ti.inc adds "public const ILimit = 7;" to TI, so the with-body ILimit
// binds to TI.ILimit although the unit text never spells it. A conditional branch keeps its
// member in the text; {$I+} is the I/O checking switch and includes nothing, so the local plans.
procedure TRenameCompletenessTests.ListsWithBodyNameHiddenFromTheDeclarationText(
  const aShape: string);
var
  lAncestor: string;
  lBody: string;
  lPlan: TDelphiSemanticRenamePlan;
  lRoot: string;
begin
  lAncestor := '';
  lBody := '{$I ti.inc}';
  if aShape = 'conditional' then
    lBody := '{$IFDEF NEVER_DEFINED}'#13#10'  public const'#13#10'    ILimit = 7;'#13#10'{$ENDIF}'
  else if aShape = 'switch' then
    lBody := '{$I+}';
  if aShape = 'ancestor-include' then
  begin
    lAncestor := '(TBase)';
    lBody := '';
  end;
  // UCons line 15 declares the local ILimit; line 20 is "    Count := ILimit;" in "with i do".
  lRoot := WriteCompletenessProject('completeness-hidden-member-' + aShape, cCompletenessProgram,
    [CompletenessFile('UProv.pas', 'unit UProv;'#13#10#13#10'interface'#13#10#13#10 +
    'type'#13#10'  TBase = class'#13#10'  public'#13#10'{$I ti.inc}'#13#10'  end;'#13#10#13#10 +
    '  TI = class' + lAncestor + #13#10'  public'#13#10'    Count: Integer;'#13#10 + lBody +
    #13#10'  end;'#13#10#13#10'implementation'#13#10#13#10'end.'#13#10),
    CompletenessFile('UCons.pas', 'unit UCons;'#13#10#13#10'interface'#13#10#13#10 +
    'procedure Run;'#13#10#13#10'implementation'#13#10#13#10'uses'#13#10'  UProv;'#13#10#13#10 +
    'procedure Run;'#13#10'var'#13#10'  i: TI;'#13#10'  ILimit: Integer;'#13#10'begin'#13#10 +
    '  ILimit := 200;'#13#10'  i := TI.Create;'#13#10'  with i do'#13#10 +
    '    Count := ILimit;'#13#10'  WriteLn(i.Count);'#13#10'end;'#13#10#13#10'end.'#13#10)]);
  TFile.WriteAllText(TPath.Combine(lRoot, 'ti.inc'), '  public const'#13#10'    ILimit = 7;'#13#10,
    TEncoding.ASCII);

  lPlan := PlanCompletenessRename(lRoot, 'UCons.pas', 15, 3, 'LimX');

  if aShape = 'switch' then
  begin
    AssertCompletePlan(lPlan, OccurrenceKeys(lRoot, ['UCons.pas'], 'ILimit'), 3);
    Exit;
  end;
  Assert.AreEqual('incomplete', lPlan.Status, lPlan.Diagnostic);
  Assert.AreEqual(SortedKeysText(['ucons.pas:15:3', 'ucons.pas:17:3']),
    SortedKeysText(PlanEditKeys(lPlan)), 'The with-body ILimit must not be edited.');
  Assert.AreEqual('ucons.pas:20:14', SortedKeysText(PlanUnresolvedKeys(lPlan)));
end;

// DS-652 review round 4: "with c do X := CVar" over c: TAClass (class of TA) binds CVar to
// TA.CVar. A class reference type has no body the scan can delimit, so the with-body name stays
// unresolved instead of binding the local. A forward declaration before TF's body must not hide
// the body (control).
procedure TRenameCompletenessTests.ListsWithBodyNameOfUndelimitedSelectorType(
  const aShape: string);
var
  lPlan: TDelphiSemanticRenamePlan;
  lRoot: string;
begin
  // UCons line 16 declares the locals CVar (col 3) and FVar (col 9), assigned on lines 18 and
  // 19 (the rename targets); lines 23 and 26 are the with bodies "    X := CVar;" and
  // "    X := FVar;".
  lRoot := WriteCompletenessProject('completeness-undelimited-' + aShape, cCompletenessProgram,
    [CompletenessFile('UProv.pas', 'unit UProv;'#13#10#13#10'interface'#13#10#13#10'type'#13#10 +
    '  TF = class;'#13#10#13#10'  TA = class'#13#10'  public'#13#10 +
    '    class var CVar: Integer;'#13#10'  end;'#13#10#13#10'  TAClass = class of TA;'#13#10 +
    #13#10'  TF = class'#13#10'  public'#13#10'    class var FVar: Integer;'#13#10'  end;'#13#10 +
    #13#10'implementation'#13#10#13#10'end.'#13#10),
    CompletenessFile('UCons.pas', 'unit UCons;'#13#10#13#10'interface'#13#10#13#10 +
    'procedure Run;'#13#10#13#10'implementation'#13#10#13#10'uses'#13#10'  UProv;'#13#10#13#10 +
    'procedure Run;'#13#10'var'#13#10'  c: TAClass;'#13#10'  f: TF;'#13#10 +
    '  CVar, FVar, X: Integer;'#13#10'begin'#13#10'  CVar := 300;'#13#10'  FVar := 400;'#13#10 +
    '  TA.CVar := 3;'#13#10'  c := TA;'#13#10'  with c do'#13#10'    X := CVar;'#13#10 +
    '  f := TF.Create;'#13#10'  with f do'#13#10'    X := FVar;'#13#10'  WriteLn(X);'#13#10 +
    'end;'#13#10#13#10'end.'#13#10)]);

  if aShape = 'class-of' then
  begin
    lPlan := PlanCompletenessRename(lRoot, 'UCons.pas', 18, 3, 'CTally');
    Assert.AreEqual('incomplete', lPlan.Status, lPlan.Diagnostic);
    Assert.AreEqual(SortedKeysText(['ucons.pas:16:3', 'ucons.pas:18:3']),
      SortedKeysText(PlanEditKeys(lPlan)), 'The with-body CVar must not be edited.');
    Assert.AreEqual('ucons.pas:23:10', SortedKeysText(PlanUnresolvedKeys(lPlan)));
  end else
  begin
    // The forward declaration is no type fact of its own, so TF resolves to its full body and
    // the with-body FVar is proven to be TF.FVar: the local plans without it.
    lPlan := PlanCompletenessRename(lRoot, 'UCons.pas', 19, 3, 'FTally');
    AssertCompletePlan(lPlan, ['ucons.pas:16:9', 'ucons.pas:19:3'], 2);
  end;
end;

// DS-652 review: TComponent may declare Name, so WriteLn(Name) in TK.Go is not proven to use
// the global. Renaming the global must list it; with an implicit TObject ancestor it binds.
procedure TRenameCompletenessTests.ListsMethodNameThatMayBeAnUnprovenAncestorMember(
  const aRtlAncestor: Boolean);
var
  lAncestor: string;
  lPlan: TDelphiSemanticRenamePlan;
  lRoot: string;
begin
  lAncestor := '';
  if aRtlAncestor then
    lAncestor := '(TComponent)';
  // UK line 11 declares the global Name; line 15 is "  WriteLn(Name);" in TK.Go.
  lRoot := WriteCompletenessProject('completeness-rtl-ancestor-' + BoolToStr(aRtlAncestor, True),
    'program P;'#13#10'uses'#13#10'  UK in ''UK.pas'';'#13#10'begin'#13#10'end.'#13#10,
    [CompletenessFile('UK.pas', 'unit UK;'#13#10'interface'#13#10'uses'#13#10 +
    '  System.Classes;'#13#10'type'#13#10'  TK = class' + lAncestor + #13#10'  public'#13#10 +
    '    procedure Go;'#13#10'  end;'#13#10'var'#13#10'  Name: string = ''global'';'#13#10 +
    'implementation'#13#10'procedure TK.Go;'#13#10'begin'#13#10'  WriteLn(Name);'#13#10 +
    'end;'#13#10'end.'#13#10)]);

  lPlan := PlanCompletenessRename(lRoot, 'UK.pas', 11, 3, 'GName');

  if not aRtlAncestor then
  begin
    AssertCompletePlan(lPlan, ['uk.pas:11:3', 'uk.pas:15:11'], 2);
    Exit;
  end;
  Assert.AreEqual('incomplete', lPlan.Status, lPlan.Diagnostic);
  Assert.AreEqual('uk.pas:11:3', SortedKeysText(PlanEditKeys(lPlan)),
    'The method-body Name must not be edited.');
  Assert.AreEqual('uk.pas:15:11', SortedKeysText(PlanUnresolvedKeys(lPlan)));
  Assert.AreEqual('unresolved-reference', lPlan.UnresolvedReferences[0].Reason);
end;

// Without argument types the open-array calls on lines 42 and 43 cannot be bound to an overload.
procedure TRenameCompletenessTests.ListsUnresolvedOverloadCallsAndRefusesPlan;
var
  lPlan: TDelphiSemanticRenamePlan;
  lRoot: string;
  lUsage: TDelphiSemanticUsage;
begin
  lRoot := WriteCompletenessProject('completeness-overload',
    'program P;'#13#10'uses'#13#10'  OverloadRange in ''OverloadRange.pas'';'#13#10 +
    'begin'#13#10'  Run(1);'#13#10'end.'#13#10, [CompletenessFile('OverloadRange.pas',
    'unit OverloadRange;'#13#10#13#10'interface'#13#10#13#10'const'#13#10'  cMin = 1;'#13#10 +
    '  cMax = 5;'#13#10#13#10'type'#13#10'  TR = cMin..cMax;'#13#10#13#10 +
    'procedure Add(const A: array of Integer); overload;'#13#10 +
    'procedure Add(const A: array of string); overload;'#13#10 +
    'procedure Put(const A: Integer); overload;'#13#10 +
    'procedure Put(const A: string); overload;'#13#10'procedure Run(X: Integer);'#13#10#13#10 +
    'implementation'#13#10#13#10'procedure Add(const A: array of Integer);'#13#10'begin'#13#10 +
    '  WriteLn(Length(A));'#13#10'end;'#13#10#13#10'procedure Add(const A: array of string);'#13#10 +
    'begin'#13#10'  WriteLn(Length(A));'#13#10'end;'#13#10#13#10 +
    'procedure Put(const A: Integer);'#13#10'begin'#13#10'  WriteLn(A);'#13#10'end;'#13#10#13#10 +
    'procedure Put(const A: string);'#13#10'begin'#13#10'  WriteLn(A);'#13#10'end;'#13#10#13#10 +
    'procedure Run(X: Integer);'#13#10'begin'#13#10'  Add([1, 2]);'#13#10'  Add([''x'']);'#13#10 +
    '  Put(1);'#13#10'  Put(''x'');'#13#10'  case X of'#13#10 +
    '    cMin..cMax: WriteLn(cMax);'#13#10'  end;'#13#10'end;'#13#10#13#10'end.'#13#10)]);

  lPlan := PlanCompletenessRename(lRoot, 'OverloadRange.pas', 12, 11, 'AddInts');

  Assert.AreEqual('incomplete', lPlan.Status, 'Unprovable calls must not yield a planned rename.');
  Assert.IsTrue(ContainsText(lPlan.Diagnostic, '2 same-name'), lPlan.Diagnostic);
  Assert.AreEqual(SortedKeysText(['overloadrange.pas:12:11', 'overloadrange.pas:20:11']),
    SortedKeysText(PlanEditKeys(lPlan)), 'Proven overload declarations stay in the plan.');
  Assert.AreEqual(SortedKeysText(['overloadrange.pas:42:3', 'overloadrange.pas:43:3']),
    SortedKeysText(PlanUnresolvedKeys(lPlan)));
  for lUsage in lPlan.UnresolvedReferences do
  begin
    Assert.AreEqual('unresolved', lUsage.Role);
    Assert.AreEqual('unresolved-reference', lUsage.Reason);
    Assert.AreEqual('Add', lUsage.Name);
    Assert.AreEqual(lUsage.Column + 2, lUsage.EndColumn);
  end;
  Assert.AreEqual('', lPlan.ContextFingerprint, 'An incomplete plan carries no apply fingerprint.');
end;

// UBad compiles, but its syntax tree fails (one-character deprecation message), so its use of
// a.FCounter cannot be proven either way.
procedure TRenameCompletenessTests.ListsReferencesInAstFailedConsumerUnit;
var
  lPlan: TDelphiSemanticRenamePlan;
  lRoot: string;
begin
  lRoot := WriteCompletenessProject('completeness-ast-failed',
    'program P;'#13#10'uses'#13#10'  UProv in ''UProv.pas'','#13#10 +
    '  UBad in ''UBad.pas'';'#13#10'begin'#13#10'end.'#13#10,
    [CompletenessFile('UProv.pas', cCompletenessProvider), CompletenessFile('UBad.pas',
    'unit UBad;'#13#10'interface'#13#10'uses'#13#10'  UProv;'#13#10'type'#13#10 +
    '  TBad = class'#13#10'  public'#13#10'    procedure Y; deprecated ''z'';'#13#10 +
    '  end;'#13#10'procedure UseIt(a: TA);'#13#10'implementation'#13#10 +
    'procedure TBad.Y;'#13#10'begin'#13#10'end;'#13#10'procedure UseIt(a: TA);'#13#10 +
    'begin'#13#10'  a.FCounter := 9;'#13#10'end;'#13#10'end.'#13#10)]);

  lPlan := PlanCompletenessRename(lRoot, 'UProv.pas', 8, 5, 'FTally');

  Assert.AreEqual('incomplete', lPlan.Status, 'An ast-failed consumer must not yield a planned rename.');
  Assert.AreEqual(SortedKeysText(OccurrenceKeys(lRoot, ['UProv.pas'], 'FCounter')),
    SortedKeysText(PlanEditKeys(lPlan)));
  Assert.AreEqual('ubad.pas:17:5', SortedKeysText(PlanUnresolvedKeys(lPlan)));
  Assert.AreEqual('unverified-unit', lPlan.UnresolvedReferences[0].Reason);
end;

procedure TRenameCompletenessTests.VerifiedClassVariableControlPlansFully;
var
  lPlan: TDelphiSemanticRenamePlan;
  lRoot: string;
begin
  lRoot := WriteCompletenessProject('completeness-control', cCompletenessProgram,
    [CompletenessFile('UProv.pas', cCompletenessProvider), CompletenessFile('UCons.pas',
    'unit UCons;'#13#10'interface'#13#10'procedure Run;'#13#10'implementation'#13#10 +
    'uses'#13#10'  UProv;'#13#10'procedure Run;'#13#10'begin'#13#10'  TA.FTotal := 1;'#13#10 +
    '  WriteLn(TA.FTotal);'#13#10'end;'#13#10'end.'#13#10)]);

  lPlan := PlanCompletenessRename(lRoot, 'UProv.pas', 9, 15, 'FSum');

  AssertCompletePlan(lPlan, OccurrenceKeys(lRoot, ['UProv.pas', 'UCons.pas'], 'FTotal'), 3);
end;

// Overrides are not linked to their base method, so renaming a virtual TA.Bump cannot be proven
// complete while TB declares a Bump. Two static methods only hide each other: the control plans.
procedure TRenameCompletenessTests.ListsPossibleOverridesOfVirtualMethods(
  const aVirtual: Boolean);
var
  lBaseDirective: string;
  lDescendantDirective: string;
  lPlan: TDelphiSemanticRenamePlan;
  lRoot: string;
begin
  lBaseDirective := '';
  lDescendantDirective := '';
  if aVirtual then
  begin
    lBaseDirective := ' virtual;';
    lDescendantDirective := ' override;';
  end;
  lRoot := WriteCompletenessProject('completeness-override-' + BoolToStr(aVirtual, True),
    cCompletenessProgram, [CompletenessFile('UProv.pas', StringReplace(cCompletenessProvider,
    '    procedure Bump;', '    procedure Bump;' + lBaseDirective, [])),
    CompletenessFile('UCons.pas', 'unit UCons;'#13#10'interface'#13#10'uses'#13#10 +
    '  UProv;'#13#10'type'#13#10'  TB = class(TA)'#13#10'  public'#13#10 +
    '    procedure Bump;' + lDescendantDirective + #13#10'  end;'#13#10'implementation'#13#10 +
    'procedure TB.Bump;'#13#10'begin'#13#10'end;'#13#10'end.'#13#10)]);

  lPlan := PlanCompletenessRename(lRoot, 'UProv.pas', 10, 15, 'Pump');

  Assert.AreEqual(SortedKeysText(OccurrenceKeys(lRoot, ['UProv.pas'], 'Bump')),
    SortedKeysText(PlanEditKeys(lPlan)), 'Only TA.Bump sites are proven.');
  if aVirtual then
  begin
    Assert.AreEqual('incomplete', lPlan.Status, lPlan.Diagnostic);
    Assert.AreEqual('ucons.pas:8:15', SortedKeysText(PlanUnresolvedKeys(lPlan)));
    Assert.AreEqual('possible-override', lPlan.UnresolvedReferences[0].Reason);
  end else
    AssertCompletePlan(lPlan, OccurrenceKeys(lRoot, ['UProv.pas'], 'Bump'), 2);
end;

initialization
  TDUnitX.RegisterTestFixture(TRenamePlannerTests);
  TDUnitX.RegisterTestFixture(TRenameCompletenessTests);

end.
