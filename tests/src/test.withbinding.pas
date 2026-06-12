unit Test.WithBinding;

interface

uses
  DUnitX.TestFramework,
  DelphiSemantics.ProjectSession, DelphiSemantics.WithBinding;

type
  [TestFixture]
  TProjectWithBindingTests = class
  private
    function FixturePath(const aRelativePath: string): string;
    function BindingByUnit(const aFacts: TDelphiSemanticProjectWithBindingFacts;
      const aUnitName: string): TDelphiSemanticWithBinding;
    function HasBindingForUnit(const aFacts: TDelphiSemanticProjectWithBindingFacts;
      const aUnitName: string): Boolean;
    function HasProjectSymbol(const aFacts: TDelphiSemanticProjectWithBindingFacts;
      const aName, aSymbolClass: string): Boolean;
    function HasProjectSymbolSource(const aFacts: TDelphiSemanticProjectWithBindingFacts;
      const aName, aSymbolClass, aSourceKind: string): Boolean;
    function HasLookupSymbol(const aSymbols: TArray<TDelphiSemanticInventorySymbol>;
      const aName, aSymbolClass: string): Boolean;
    function HasReference(const aBinding: TDelphiSemanticWithBinding; const aName,
      aClassification: string): Boolean;
  public
    [Test]
    procedure ProjectSessionBuildsProjectLevelWithBindingFacts;
    [Test]
    procedure ProjectSessionCanSkipGraphForRangeMappedWithBindingFacts;
    [Test]
    procedure ProjectSessionIncludesExplicitAdditionalSourceFiles;
    [Test]
    procedure ProjectSessionLimitsBodyAnalysisToRequestedSourceFiles;
    [Test]
    procedure ProjectSessionBuildsRemoveWithLookupIndex;
    [Test]
    procedure RemoveWithLookupIndexIncludesCompatibilityExternalSymbols;
    [Test]
    procedure BindingReferenceCacheUsesStatementPrefix;
    [Test]
    procedure BindingReferencesUsePrecomputedBodyLineStarts;
    [Test]
    procedure BindProjectSkipsScopeIndexForUnitsWithoutWithStatements;
    [Test]
    procedure BindProjectBuildsScopeIndexOnlyForWithLines;
    [Test]
    procedure BindProjectPreallocatesHotFactLists;
    [Test]
    procedure ReceiverMemberBindingUsesSemanticMemberIndex;
    [Test]
    procedure ReceiverMemberIndexDoesNotWalkVisibleUnitsPerLookup;
  end;

implementation

uses
  System.IOUtils, System.StrUtils, System.SysUtils,
  DelphiSemantics.ProjectContext, maxLogic.IOUtils;

function TProjectWithBindingTests.FixturePath(const aRelativePath: string): string;
begin
  Result := TPath.GetFullPath(TPath.Combine(
    TPath.Combine(ExtractFilePath(ParamStr(0)), '..\fixtures'),
    aRelativePath));
end;

function TProjectWithBindingTests.BindingByUnit(
  const aFacts: TDelphiSemanticProjectWithBindingFacts;
  const aUnitName: string): TDelphiSemanticWithBinding;
var
  lBinding: TDelphiSemanticWithBinding;
begin
  for lBinding in aFacts.Bindings do
    if SameText(lBinding.UnitName, aUnitName) then
      Exit(lBinding);

  Assert.Fail('Missing binding for unit ' + aUnitName);
  Result := Default(TDelphiSemanticWithBinding);
end;

function TProjectWithBindingTests.HasReference(const aBinding: TDelphiSemanticWithBinding;
  const aName, aClassification: string): Boolean;
var
  lReference: TDelphiSemanticBoundReference;
begin
  for lReference in aBinding.References do
    if SameText(lReference.Name, aName) and SameText(lReference.Classification,
      aClassification) then
      Exit(lReference.SemanticId <> '');

  Result := False;
end;

function TProjectWithBindingTests.HasBindingForUnit(
  const aFacts: TDelphiSemanticProjectWithBindingFacts; const aUnitName: string): Boolean;
var
  lBinding: TDelphiSemanticWithBinding;
begin
  for lBinding in aFacts.Bindings do
    if SameText(lBinding.UnitName, aUnitName) then
      Exit(True);

  Result := False;
end;

function TProjectWithBindingTests.HasProjectSymbol(
  const aFacts: TDelphiSemanticProjectWithBindingFacts; const aName,
  aSymbolClass: string): Boolean;
var
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  for lSymbol in aFacts.Symbols do
    if SameText(lSymbol.Name, aName) and SameText(lSymbol.SymbolClass, aSymbolClass) then
      Exit(True);

  Result := False;
end;

function TProjectWithBindingTests.HasProjectSymbolSource(
  const aFacts: TDelphiSemanticProjectWithBindingFacts; const aName,
  aSymbolClass, aSourceKind: string): Boolean;
var
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  for lSymbol in aFacts.Symbols do
    if SameText(lSymbol.Name, aName) and SameText(lSymbol.SymbolClass, aSymbolClass) and
      SameText(lSymbol.SourceOwnerType, aSourceKind) then
      Exit(True);

  Result := False;
end;

function TProjectWithBindingTests.HasLookupSymbol(
  const aSymbols: TArray<TDelphiSemanticInventorySymbol>; const aName,
  aSymbolClass: string): Boolean;
var
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  for lSymbol in aSymbols do
    if SameText(lSymbol.Name, aName) and SameText(lSymbol.SymbolClass, aSymbolClass) then
      Exit(True);

  Result := False;
end;

procedure TProjectWithBindingTests.ProjectSessionBuildsProjectLevelWithBindingFacts;
var
  lProgramBinding: TDelphiSemanticWithBinding;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lOptions: TDelphiSemanticOptions;
  lResult: TDelphiSemanticProjectSessionResult;
  lUnitBinding: TDelphiSemanticWithBinding;
begin
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := FixturePath('ProjectWithBinding\ProjectWithBinding.dproj');

  lResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lResult.Success);
    lFacts := lResult.Session.BuildWithBindingFacts;

    Assert.AreEqual(lResult.Session.Project.ContextFingerprint, lFacts.ContextFingerprint);
    Assert.IsTrue(lFacts.Metrics.SemanticGraphUsed);
    Assert.IsFalse(lFacts.Metrics.BuildUnitIndexUsed);
    Assert.IsTrue(lFacts.Metrics.ModelExtractionMilliseconds >= 0);
    Assert.AreEqual(2, lFacts.Metrics.UnitCount);
    Assert.AreEqual(3, lFacts.Metrics.BindingCount);
    Assert.AreEqual(3, Integer(Length(lFacts.Bindings)));
    Assert.IsTrue(Length(lFacts.Symbols) > 0,
      'Expected project facts to carry reusable semantic inventory symbols.');
    Assert.IsTrue(HasProjectSymbol(lFacts, 'ProjectWithUnit', 'unit'));
    Assert.IsTrue(HasProjectSymbol(lFacts, 'TProjectWithRecord', 'declaration'));
    Assert.IsTrue(HasProjectSymbol(lFacts, 'Value', 'member'));
    Assert.IsTrue(HasProjectSymbolSource(lFacts, 'SizeOf', 'routine', 'compiler-intrinsic'));
    Assert.IsTrue(HasProjectSymbolSource(lFacts, 'NativeUInt', 'type', 'compiler-intrinsic'));
    Assert.IsTrue(HasProjectSymbolSource(lFacts, 'FreeAndNil', 'routine', 'rtl-source'));
    Assert.IsTrue(HasProjectSymbolSource(lFacts, 'Push', 'routine', 'rtl-source'));
    Assert.IsTrue(HasProjectSymbolSource(lFacts, 'TSearchRec', 'type-member', 'rtl-source'));
    Assert.IsTrue(HasProjectSymbolSource(lFacts, 'Name', 'field', 'rtl-source'));
    Assert.IsTrue(HasProjectSymbolSource(lFacts, 'Message', 'property', 'rtl-source'));
    Assert.IsFalse(HasBindingForUnit(lFacts, 'UnreferencedWithUnit'),
      'Unreferenced .pas files in the project directory must not be scanned as project units.');

    lProgramBinding := BindingByUnit(lFacts, 'ProjectWithBinding');
    Assert.IsNotEmpty(lProgramBinding.SemanticId);
    Assert.AreEqual('with-binding:project-session', lProgramBinding.Provenance);
    Assert.IsFalse(lProgramBinding.HasScopedDeclaration);
    Assert.IsTrue(HasReference(lProgramBinding, 'Value', 'member'));

    lUnitBinding := BindingByUnit(lFacts, 'ProjectWithUnit');
    Assert.IsTrue(HasReference(lUnitBinding, 'Count', 'member'));
    Assert.IsNotEmpty(lUnitBinding.References[0].SemanticId);
    Assert.AreNotEqual(lUnitBinding.SemanticId, lUnitBinding.References[0].SemanticId);
  finally
    lResult.Session.Free;
  end;
end;

procedure TProjectWithBindingTests.ProjectSessionCanSkipGraphForRangeMappedWithBindingFacts;
var
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lOptions: TDelphiSemanticOptions;
  lProgramBinding: TDelphiSemanticWithBinding;
  lResult: TDelphiSemanticProjectSessionResult;
begin
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := FixturePath('ProjectWithBinding\ProjectWithBinding.dproj');
  lOptions.SkipWithBindingSemanticGraph := True;

  lResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lResult.Success);
    lFacts := lResult.Session.BuildWithBindingFacts;

    Assert.IsFalse(lFacts.Metrics.SemanticGraphUsed);
    Assert.AreEqual(3, lFacts.Metrics.BindingCount);
    lProgramBinding := BindingByUnit(lFacts, 'ProjectWithBinding');
    Assert.AreEqual('with-binding:model', lProgramBinding.Provenance);
    Assert.IsNotEmpty(lProgramBinding.SemanticId);
    Assert.IsTrue(HasReference(lProgramBinding, 'Value', 'member'));
  finally
    lResult.Session.Free;
  end;
end;

procedure TProjectWithBindingTests.ProjectSessionIncludesExplicitAdditionalSourceFiles;
var
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lOptions: TDelphiSemanticOptions;
  lResult: TDelphiSemanticProjectSessionResult;
begin
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := FixturePath('ProjectWithBinding\ProjectWithBinding.dproj');
  lOptions.AdditionalSourceFileNames := [
    FixturePath('ProjectWithBinding\UnreferencedWithUnit.pas')];

  lResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lResult.Success);
    lFacts := lResult.Session.BuildWithBindingFacts;

    Assert.IsTrue(HasBindingForUnit(lFacts, 'UnreferencedWithUnit'),
      'Explicit additional source files must participate in project semantic facts.');
    Assert.IsTrue(HasProjectSymbol(lFacts, 'TUnreferencedRecord', 'declaration'),
      'Explicit additional source files must contribute semantic inventory symbols.');
  finally
    lResult.Session.Free;
  end;
end;

procedure TProjectWithBindingTests.ProjectSessionLimitsBodyAnalysisToRequestedSourceFiles;
var
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lOptions: TDelphiSemanticOptions;
  lResult: TDelphiSemanticProjectSessionResult;
begin
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := FixturePath('ProjectWithBinding\ProjectWithBinding.dproj');
  lOptions.AdditionalSourceFileNames := [
    FixturePath('ProjectWithBinding\UnreferencedWithUnit.pas')];
  lOptions.BodyAnalysisSourceFileNames := [
    FixturePath('ProjectWithBinding\ProjectWithBinding.dpr'),
    FixturePath('ProjectWithBinding\ProjectWithUnit.pas')];

  lResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lResult.Success);
    lFacts := lResult.Session.BuildWithBindingFacts;

    Assert.IsFalse(HasBindingForUnit(lFacts, 'UnreferencedWithUnit'),
      'Sources outside the body-analysis set must not contribute with bindings.');
    Assert.IsTrue(HasProjectSymbol(lFacts, 'TUnreferencedRecord', 'declaration'),
      'Sources outside the body-analysis set must still contribute declarations.');
  finally
    lResult.Session.Free;
  end;
end;

procedure TProjectWithBindingTests.ProjectSessionBuildsRemoveWithLookupIndex;
var
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lLocalSymbol: TDelphiSemanticInventorySymbol;
  lOptions: TDelphiSemanticOptions;
  lResult: TDelphiSemanticProjectSessionResult;
begin
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := FixturePath('ProjectWithBinding\ProjectWithBinding.dproj');

  lResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lResult.Success);
    lFacts := lResult.Session.BuildWithBindingFacts;

    Assert.IsTrue(lFacts.LookupIndex.IsAvailable);
    Assert.IsTrue(HasLookupSymbol(lFacts.LookupIndex.FindMembersByOwnerAndName(
      'TProjectWithRecord', 'Value'), 'Value', 'member'));
    Assert.IsTrue(HasLookupSymbol(lFacts.LookupIndex.FindMembersByOwnerAndName(
      'tprojectwithrecord', 'value'), 'Value', 'member'));
    Assert.IsTrue(lFacts.LookupIndex.FindRoutineSymbol('TouchProjectUnitRecord',
      'aValue', lLocalSymbol));
    Assert.AreEqual('parameter', lLocalSymbol.SymbolClass);
    Assert.IsTrue(lFacts.LookupIndex.FindRoutineSymbol('TouchProjectUnitRecord',
      'lRecord', lLocalSymbol));
    Assert.AreEqual('local', lLocalSymbol.SymbolClass);
    Assert.IsTrue(lFacts.LookupIndex.FindRoutineSymbol('TProjectUnitScope.Run',
      'lScopedRecord', lLocalSymbol));
    Assert.AreEqual('local', lLocalSymbol.SymbolClass);
    Assert.IsTrue(lFacts.LookupIndex.FindRoutineSymbol('Run', 'lScopedRecord',
      lLocalSymbol));
    Assert.AreEqual('local', lLocalSymbol.SymbolClass);
    Assert.AreEqual('TProjectWithRecord', lFacts.LookupIndex.PointerTargetType(
      'PProjectWithRecord'));
    Assert.AreEqual('TProjectWithRecord', lFacts.LookupIndex.PointerTargetType(
      'pprojectwithrecord'));
    Assert.IsTrue(HasLookupSymbol(lFacts.LookupIndex.FindDeclarationOrTypeAliasByName(
      'TProjectWithRecord'), 'TProjectWithRecord', 'declaration'));
    Assert.IsTrue(HasLookupSymbol(lFacts.LookupIndex.FindDeclarationOrTypeAliasByName(
      'tprojectwithrecord'), 'TProjectWithRecord', 'declaration'));
    Assert.IsTrue(HasLookupSymbol(lFacts.LookupIndex.FindUnitOrGlobalByName(
      'ProjectWithUnit'), 'ProjectWithUnit', 'unit'));
    Assert.IsTrue(HasLookupSymbol(lFacts.LookupIndex.FindUnitOrGlobalByName(
      'projectwithunit'), 'ProjectWithUnit', 'unit'));
    Assert.IsTrue(HasLookupSymbol(lFacts.LookupIndex.FindSymbolsByName(
      'ProjectWithUnit'), 'ProjectWithUnit', 'unit'));
    Assert.IsTrue(HasLookupSymbol(lFacts.LookupIndex.FindSymbolsByOwnerType(
      'TProjectWithRecord'), 'Value', 'member'));
    Assert.IsTrue(lFacts.LookupIndex.Metrics.BuildMilliseconds >= 0);
  finally
    lResult.Session.Free;
  end;
end;

procedure TProjectWithBindingTests.RemoveWithLookupIndexIncludesCompatibilityExternalSymbols;
var
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lLocalSymbol: TDelphiSemanticInventorySymbol;
  lLookupIndex: TDelphiSemanticRemoveWithLookupIndex;
  lOptions: TDelphiSemanticOptions;
  lResult: TDelphiSemanticProjectSessionResult;
  lSymbols: TArray<TDelphiSemanticInventorySymbol>;
begin
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := FixturePath('ProjectWithBinding\ProjectWithBinding.dproj');

  lResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lResult.Success);
    lFacts := lResult.Session.BuildWithBindingFacts;

    SetLength(lSymbols, 8);
    lSymbols[0] := Default(TDelphiSemanticInventorySymbol);
    lSymbols[0].Name := 'TCompatibilityType';
    lSymbols[0].SymbolClass := 'external';
    lSymbols[0].Kind := 'external';
    lSymbols[0].TypeName := 'TCompatibilityType';

    lSymbols[1] := Default(TDelphiSemanticInventorySymbol);
    lSymbols[1].Name := 'Compatibility.Unit';
    lSymbols[1].SymbolClass := 'external';
    lSymbols[1].Kind := 'external';
    lSymbols[1].UnitName := 'ProjectWithBinding';

    lSymbols[2] := Default(TDelphiSemanticInventorySymbol);
    lSymbols[2].Name := 'Compatibility.Unit.Sub';
    lSymbols[2].SymbolClass := 'unit';
    lSymbols[2].Kind := 'unit';
    lSymbols[2].UnitName := 'Compatibility.Unit.Sub';

    lSymbols[3] := Default(TDelphiSemanticInventorySymbol);
    lSymbols[3].Name := 'PCompatibilityType';
    lSymbols[3].SymbolClass := 'type-member';
    lSymbols[3].Kind := 'type-member';
    lSymbols[3].TypeName := '^TCompatibilityType';

    lSymbols[4] := Default(TDelphiSemanticInventorySymbol);
    lSymbols[4].Name := 'NestedMember';
    lSymbols[4].SymbolClass := 'current-class-member';
    lSymbols[4].Kind := 'current-class-member';
    lSymbols[4].TypeName := 'TCompatibilityType';
    lSymbols[4].RoutineName := 'TCompatibilityScope.Run';

    lSymbols[5] := Default(TDelphiSemanticInventorySymbol);
    lSymbols[5].Name := 'CompatibilityMember';
    lSymbols[5].SymbolClass := 'field';
    lSymbols[5].Kind := 'field';
    lSymbols[5].TypeName := 'Integer';
    lSymbols[5].OwnerType := 'TCompatibilityType';

    lSymbols[6] := Default(TDelphiSemanticInventorySymbol);
    lSymbols[6].Name := 'PointerValue';
    lSymbols[6].SymbolClass := 'member';
    lSymbols[6].Kind := 'field';
    lSymbols[6].TypeName := '^TCompatibilityType';
    lSymbols[6].OwnerType := 'TCompatibilityType';

    lSymbols[7] := Default(TDelphiSemanticInventorySymbol);
    lSymbols[7].Name := 'ExpandedExternalMember';
    lSymbols[7].SymbolClass := 'field';
    lSymbols[7].Kind := 'field';
    lSymbols[7].TypeName := 'TExpandedExternalType';
    lSymbols[7].OwnerType := 'TCompatibilityType';

    lSymbols := TDelphiSemanticWithBinder.ExpandInventorySymbols(lSymbols);
    lLookupIndex := TDelphiSemanticRemoveWithLookupIndex.Build(lFacts.UnitModels, lSymbols);

    Assert.IsTrue(HasLookupSymbol(lLookupIndex.FindDeclarationOrTypeAliasByName(
      'tcompatibilitytype'), 'TCompatibilityType', 'external'));
    Assert.IsTrue(HasLookupSymbol(lLookupIndex.FindDeclarationOrTypeAliasByName(
      'texpandedexternaltype'), 'TExpandedExternalType', 'external'));
    Assert.IsTrue(HasLookupSymbol(lLookupIndex.FindUnitOrGlobalByName(
      'compatibility.unit'), 'Compatibility.Unit', 'external'));
    Assert.IsTrue(HasLookupSymbol(lLookupIndex.FindUnitOrGlobalByPrefix(
      'compatibility'), 'Compatibility.Unit', 'external'));
    Assert.IsTrue(HasLookupSymbol(lLookupIndex.FindUnitOrGlobalByPrefix(
      'compatibility.unit'), 'Compatibility.Unit.Sub', 'unit'));
    Assert.IsTrue(HasLookupSymbol(lLookupIndex.FindMembersByOwnerAndName(
      'TCompatibilityType', 'CompatibilityMember'), 'CompatibilityMember', 'field'));
    Assert.AreEqual('TCompatibilityType', lLookupIndex.PointerTargetType(
      'pcompatibilitytype'));
    Assert.AreEqual('', lLookupIndex.PointerTargetType('PointerValue'));
    Assert.IsFalse(lLookupIndex.FindRoutineSymbol('Run', 'NestedMember', lLocalSymbol),
      'Current-class members are member facts, not routine local/parameter facts.');
  finally
    lResult.Session.Free;
  end;
end;

procedure TProjectWithBindingTests.BindingReferenceCacheUsesStatementPrefix;
var
  lSourceText: string;
begin
  lSourceText := TFile.ReadAllText(TPath.GetFullPath(TPath.Combine(ExtractFilePath(ParamStr(0)),
    '..\..\src\DelphiSemantics.WithBinding.pas')), TEncoding.UTF8);

  Assert.IsTrue(ContainsText(lSourceText, 'BoundReferenceCachePrefix'),
    'binding should build the shared reference-cache key prefix once per statement');
  Assert.IsTrue(ContainsText(lSourceText, 'ResolveNameCachePrefix'),
    'binding should build the shared resolver-cache key prefix once per statement');
  Assert.IsTrue(ContainsText(lSourceText, 'ReceiverMemberCachePrefix'),
    'binding should build the receiver/member cache key prefix once per statement');
end;

procedure TProjectWithBindingTests.BindingReferencesUsePrecomputedBodyLineStarts;
var
  lBindEnd: Integer;
  lBindSource: string;
  lBindStart: Integer;
  lSourceText: string;
begin
  lSourceText := TFile.ReadAllText(TPath.GetFullPath(TPath.Combine(ExtractFilePath(ParamStr(0)),
    '..\..\src\DelphiSemantics.WithBinding.pas')), TEncoding.UTF8);
  lBindStart := Pos('function BindReferences(', lSourceText);
  lBindEnd := Pos('function StatementContains(', lSourceText);
  Assert.IsTrue((lBindStart > 0) and (lBindEnd > lBindStart),
    'Expected BindReferences implementation section.');

  lBindSource := Copy(lSourceText, lBindStart, lBindEnd - lBindStart);
  Assert.IsTrue(ContainsText(lSourceText, 'BuildBodyLineStarts'),
    'With-binding should build line starts once per body text.');
  Assert.IsTrue(ContainsText(lBindSource, 'lBodyLineStarts := BuildBodyLineStarts(lBodyText)'),
    'BindReferences should precompute body line starts once per statement.');
  Assert.IsTrue(ContainsText(lBindSource,
    'ApplyBodyRange(lReference, aStatement, lTokenStart, Length(lToken), lBodyLineStarts)'),
    'Reference body ranges should use the precomputed line-start table.');
  Assert.IsFalse(ContainsText(lSourceText, 'LineOfOffset(aStatement.BodyText'),
    'ApplyBodyRange must not rescan the body text for every reference line lookup.');
end;

procedure TProjectWithBindingTests.BindProjectSkipsScopeIndexForUnitsWithoutWithStatements;
var
  lBindProjectEnd: Integer;
  lBindProjectSource: string;
  lBindProjectStart: Integer;
  lScopeIndexPos: Integer;
  lSourceText: string;
  lWithGuardPos: Integer;
begin
  lSourceText := TFile.ReadAllText(TPath.GetFullPath(TPath.Combine(ExtractFilePath(ParamStr(0)),
    '..\..\src\DelphiSemantics.WithBinding.pas')), TEncoding.UTF8);
  lBindProjectStart := Pos('class function TDelphiSemanticWithBinder.BindProject',
    lSourceText);
  lBindProjectEnd := Pos('class function TDelphiSemanticWithBinder.ExpandInventorySymbols',
    lSourceText);
  Assert.IsTrue((lBindProjectStart > 0) and (lBindProjectEnd > lBindProjectStart),
    'Expected BindProject implementation section.');

  lBindProjectSource := Copy(lSourceText, lBindProjectStart,
    lBindProjectEnd - lBindProjectStart);
  lWithGuardPos := Pos('if Length(lModel.WithStatements) = 0 then',
    lBindProjectSource);
  lScopeIndexPos := Pos('TDelphiSemanticScopeResolver.BuildRoutineScopeIndex(lModel',
    lBindProjectSource);
  Assert.IsTrue((lWithGuardPos > 0) and (lWithGuardPos < lScopeIndexPos),
    'BindProject should not build a routine scope index for units without with statements.');
end;

procedure TProjectWithBindingTests.BindProjectBuildsScopeIndexOnlyForWithLines;
var
  lBindProjectEnd: Integer;
  lBindProjectSource: string;
  lBindProjectStart: Integer;
  lSourceText: string;
begin
  lSourceText := TFile.ReadAllText(TPath.GetFullPath(TPath.Combine(ExtractFilePath(ParamStr(0)),
    '..\..\src\DelphiSemantics.WithBinding.pas')), TEncoding.UTF8);
  lBindProjectStart := Pos('class function TDelphiSemanticWithBinder.BindProject',
    lSourceText);
  lBindProjectEnd := Pos('class function TDelphiSemanticWithBinder.ExpandInventorySymbols',
    lSourceText);
  Assert.IsTrue((lBindProjectStart > 0) and (lBindProjectEnd > lBindProjectStart),
    'Expected BindProject implementation section.');

  lBindProjectSource := Copy(lSourceText, lBindProjectStart,
    lBindProjectEnd - lBindProjectStart);
  Assert.IsTrue(ContainsText(lBindProjectSource,
    'TDelphiSemanticScopeResolver.BuildRoutineScopeIndex(lModel') and
    ContainsText(lBindProjectSource, 'lWithStatementLines'),
    'BindProject should build routine-scope line data only for with-statement lines.');
end;

procedure TProjectWithBindingTests.BindProjectPreallocatesHotFactLists;
var
  lBindProjectEnd: Integer;
  lBindProjectSource: string;
  lBindProjectStart: Integer;
  lSourceText: string;
begin
  lSourceText := TFile.ReadAllText(TPath.GetFullPath(TPath.Combine(ExtractFilePath(ParamStr(0)),
    '..\..\src\DelphiSemantics.WithBinding.pas')), TEncoding.UTF8);
  lBindProjectStart := Pos('class function TDelphiSemanticWithBinder.BindProject',
    lSourceText);
  lBindProjectEnd := Pos('class function TDelphiSemanticWithBinder.ExpandInventorySymbols',
    lSourceText);
  Assert.IsTrue((lBindProjectStart > 0) and (lBindProjectEnd > lBindProjectStart),
    'Expected BindProject implementation section.');

  lBindProjectSource := Copy(lSourceText, lBindProjectStart,
    lBindProjectEnd - lBindProjectStart);
  Assert.IsTrue(ContainsText(lBindProjectSource, 'lBindings.Capacity := lBindingCapacity'),
    'BindProject should preallocate the binding list from with-statement counts.');
  Assert.IsTrue(ContainsText(lBindProjectSource, 'lSymbols.Capacity := lSymbolCapacity'),
    'BindProject should preallocate the inventory symbol list from model symbol counts.');
end;

procedure TProjectWithBindingTests.ReceiverMemberBindingUsesSemanticMemberIndex;
var
  lReceiverMemberEnd: Integer;
  lReceiverMemberStart: Integer;
  lReceiverMemberText: string;
  lSourceFileName: string;
  lSourceText: string;
begin
  lSourceFileName := TPath.GetFullPath(CombinePath([ExtractFilePath(ParamStr(0)), '..',
    '..', 'src', 'DelphiSemantics.WithBinding.pas']));
  lSourceText := TFile.ReadAllText(lSourceFileName, TEncoding.UTF8);
  lReceiverMemberStart := Pos('function ReceiverMemberCacheKey', lSourceText);
  lReceiverMemberEnd := Pos('function AnySelectorUnresolved', lSourceText);
  Assert.IsTrue((lReceiverMemberStart > 0) and (lReceiverMemberEnd > lReceiverMemberStart),
    'Expected receiver-member binding source section.');
  lReceiverMemberText := Copy(lSourceText, lReceiverMemberStart,
    lReceiverMemberEnd - lReceiverMemberStart);

  Assert.IsTrue(ContainsText(lSourceText, 'TDelphiSemanticMemberResolver.BuildIndex'),
    'Receiver/member binding must build an operation-local semantic member index.');
  Assert.IsFalse(ContainsText(lReceiverMemberText, 'for lModel in aProjectModels do'),
    'Receiver/member binding must not scan every project model for each unresolved lookup.');
  Assert.IsFalse(ContainsText(lReceiverMemberText, 'ResolveMemberAtLevel(lModel'),
    'Receiver/member binding must not use project-model resolver fallback for every miss.');
end;

procedure TProjectWithBindingTests.ReceiverMemberIndexDoesNotWalkVisibleUnitsPerLookup;
var
  lIndexEnd: Integer;
  lIndexStart: Integer;
  lIndexText: string;
  lSourceFileName: string;
  lSourceText: string;
begin
  lSourceFileName := TPath.GetFullPath(CombinePath([ExtractFilePath(ParamStr(0)), '..',
    '..', 'src', 'DelphiSemantics.WithBinding.pas']));
  lSourceText := TFile.ReadAllText(lSourceFileName, TEncoding.UTF8);
  lIndexStart := Pos('function TWithBindingProjectMemberIndex.TryResolveDirectMember',
    lSourceText);
  lIndexEnd := Pos('function IsBinderKeyword', lSourceText);
  Assert.IsTrue((lIndexStart > 0) and (lIndexEnd > lIndexStart),
    'Expected receiver-member index lookup source section.');
  lIndexText := Copy(lSourceText, lIndexStart, lIndexEnd - lIndexStart);

  Assert.IsTrue(ContainsText(lSourceText, 'fDirectMembersByContextOwnerName'),
    'Receiver/member binding must precompute current/visible-unit owner-name lookup keys.');
  Assert.IsTrue(ContainsText(lSourceText, 'fSemanticMemberResultsByOwnerName'),
    'Receiver/member binding must cache semantic member-index results by owner and member name.');
  Assert.IsFalse(ContainsText(lIndexText, 'for lUnitName in lVisibleUnits do'),
    'Receiver/member lookup must not walk visible units for each lookup.');
  Assert.IsFalse(ContainsText(lIndexText, 'for lUnitName in fUnitNames do'),
    'Receiver/member lookup must not walk all project units for each lookup.');
end;

initialization
  TDUnitX.RegisterTestFixture(TProjectWithBindingTests);

end.
