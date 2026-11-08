unit Test.SymbolQuery;

interface

uses
  DUnitX.TestFramework,
  DelphiSemantics.Api,
  DelphiSemantics.Cache,
  DelphiSemantics.CompilerProfile,
  DelphiSemantics.Index,
  DelphiSemantics.Model,
  DelphiSemantics.Query,
  DelphiSemantics.Snapshot,
  DelphiSemantics.Snapshot.PositionResolver,
  DelphiSemantics.Symbols;

type
  [TestFixture]
  TSymbolQueryTests = class
  private
    function LoadContext: TDelphiSemanticSymbolQueryContext;
  public
    [Test]
    [TestCase('Direct', 'False')]
    [TestCase('Snapshot', 'True')]
    procedure SharedIncludePositionDoesNotChooseAnArbitraryUnit(const aSnapshot: Boolean);
    [Test]
    [TestCase('Direct', 'False')]
    [TestCase('Snapshot', 'True')]
    procedure UnverifiedRootWitnessDoesNotPublishLegacyCoordinates(const aSnapshot: Boolean);
    [Test]
    [TestCase('Direct', 'False')]
    [TestCase('Snapshot', 'True')]
    procedure NestedMixedLineQueriesUseCapturedOrigins(const aSnapshot: Boolean);
    [Test]
    [TestCase('Direct', 'False')]
    [TestCase('Snapshot', 'True')]
    procedure MissingCapturedIncludeCannotUseCurrentDisk(const aSnapshot: Boolean);
    [Test]
    [TestCase('Direct', 'False')]
    [TestCase('Snapshot', 'True')]
    procedure UnknownReferencePositionHasNoEndpoint(const aSnapshot: Boolean);
    [Test]
    [TestCase('Unknown position direct', 'False,unknown,0,0')]
    [TestCase('Unknown position snapshot', 'True,unknown,0,0')]
    [TestCase('Local direct', 'False,lValue,7,3')]
    [TestCase('Local snapshot', 'True,lValue,7,3')]
    [TestCase('Declaration direct', 'False,TIncluded,2,3')]
    [TestCase('Member direct', 'False,Value,3,5')]
    [TestCase('Routine direct', 'False,IncludedRun,5,11')]
    [TestCase('Reference direct', 'False,reference,9,3')]
    [TestCase('Declaration snapshot', 'True,TIncluded,2,3')]
    [TestCase('Member snapshot', 'True,Value,3,5')]
    [TestCase('Routine snapshot', 'True,IncludedRun,5,11')]
    [TestCase('Reference snapshot', 'True,reference,9,3')]
    procedure IncludeResultsKeepPhysicalOrigins(const aSnapshot: Boolean;
      const aName: string; const aLine, aColumn: Integer);
    [Category('Fast')]
    [Test]
    procedure FindsProjectDefinitionByPositionAndName;
    [Category('Fast')]
    [Test]
    procedure SearchesProjectMembersRtlSourceAndIntrinsics;
    [Category('Fast')]
    [Test]
    procedure DescribesOwnedMembersAndIntrinsics;
    [Category('Fast')]
    [Test]
    procedure FindsTokenReferencesInProjectScope;
    [Category('Fast')]
    [Test]
    procedure LimitsTokenReferenceResults;
    [Category('Fast')]
    [Test]
    procedure ResolvesCoreSymbolKindsWithoutShellingOut;
    [Category('Fast')]
    [Test]
    procedure ResolvesSourcePositionAndReportsCacheStatus;
    [Category('Fast')]
    [Test]
    procedure ResolvesPositionFromCapturedModelSourceAfterDiskEdit;
    [Category('Fast')]
    [Test]
    procedure CacheStatusExposesProfileKeyAndCacheFileName;
    [Category('Fast')]
    [Test]
    procedure SearchMatchesSubstringsAndReturnsRanges;
    [Category('Fast')]
    [Test]
    procedure SnapshotBackedQueriesUseProjectSnapshotIndexes;
    [Category('Fast')]
    [Test]
    procedure SnapshotPositionLookupUsesSharedResolver;
    [Category('Fast')]
    [Test]
    procedure SnapshotPositionResolverFallsBackWhenReferenceTargetIsStale;
    [Category('Fast')]
    [Test]
    procedure TokenReferencesExposeMetadata;
    [Category('Fast')]
    [Test]
    procedure VisibleUnitScopesIncludeProjectAndRtlModels;
    [Category('Fast')]
    [Test]
    procedure IndexedProjectUnitsKeepSourceKindAndRoutineSearch;
    [Category('Fast')]
    [Test]
    procedure BuildsProjectSymbolIndexWithResolvedAmbiguousAndUnresolvedReferences;
    [Category('Fast')]
    [Test]
    procedure OverloadedRoutineLocalReferenceStaysUnresolvedWithoutRoutineIdentity;
    [Category('Fast')]
    [Test]
    procedure ProjectSymbolIndexResolvesReferencesWithoutSymbolScans;
    [Category('Fast')]
    [Test]
    procedure ProjectSymbolIndexUsesCaseInsensitiveLookupMaps;
    [Category('Fast')]
    [Test]
    procedure SnapshotProjectionHelpersLiveInQuerySupport;
    [Category('Fast')]
    [Test]
    procedure LegacyModelIndexingLivesInCompatibilityAdapter;
  end;

implementation

uses
  System.Classes, System.IOUtils, System.StrUtils, System.SysUtils,
  Winapi.Windows,
  maxLogic.IOUtils,
  DelphiSemantics.Snapshot.Builder, DelphiSemantics.WithBinding,
  Test.Support;

var
  GSymbolQueryTempRoot: string;

function SymbolQueryTempPath(const aName: string): string;
begin
  if GSymbolQueryTempRoot = '' then
  begin
    GSymbolQueryTempRoot := CreateTestTempRoot('snapshot-query-temp');
  end;
  TDirectory.CreateDirectory(GSymbolQueryTempRoot);
  Result := TPath.Combine(GSymbolQueryTempRoot, aName);
end;


function TSymbolQueryTests.LoadContext: TDelphiSemanticSymbolQueryContext;
var
  lCache: TDelphiSemanticUnitCache;
  lCacheOptions: TDelphiSemanticCacheOptions;
  lModelOptions: TDelphiSemanticModelOptions;
begin
  lCacheOptions := Default(TDelphiSemanticCacheOptions);
  lCacheOptions.CompilerProfileName := 'Delphi-12-SymbolQuery';
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

procedure TSymbolQueryTests.FindsProjectDefinitionByPositionAndName;
var
  lContext: TDelphiSemanticSymbolQueryContext;
  lResult: TDelphiSemanticSymbolQueryResult;
begin
  lContext := LoadContext;

  lResult := TDelphiSemanticSymbolQuery.FindDefinitionByName(lContext, 'TDeclarationRecord');

  Assert.IsTrue(lResult.Found);
  Assert.AreEqual('TDeclarationRecord', lResult.Name);
  Assert.AreEqual('type', lResult.Kind);
  Assert.AreEqual('semantic-model', lResult.Provenance);
  Assert.AreEqual(FixturePath('SymbolQuery', 'SymbolQueryUnit.pas'), lResult.FileName);

  lResult := TDelphiSemanticSymbolQuery.FindDefinitionAtPosition(lContext,
    FixturePath('SymbolQuery', 'SymbolQueryUnit.pas'), 32, 13);

  Assert.IsTrue(lResult.Found);
  Assert.AreEqual('TSymbolMapFixture', lResult.Name);
  Assert.AreEqual('type', lResult.Kind);

  lResult := TDelphiSemanticSymbolQuery.FindDefinitionAtPosition(lContext,
    FixturePath('SymbolQuery', 'SymbolQueryUnit.pas'), 1, 1);

  Assert.IsTrue(lResult.Found);
  Assert.AreEqual('SymbolQueryUnit', lResult.Name);
  Assert.AreEqual('unit', lResult.Kind);
  Assert.AreEqual('project-source', lResult.SourceKind);
end;

procedure TSymbolQueryTests.SearchesProjectMembersRtlSourceAndIntrinsics;
var
  lContext: TDelphiSemanticSymbolQueryContext;
  lResults: TArray<TDelphiSemanticSymbolQueryResult>;
begin
  lContext := LoadContext;

  lResults := TDelphiSemanticSymbolQuery.Search(lContext, 'Enabled', 10);

  Assert.AreEqual(1, Integer(Length(lResults)));
  Assert.AreEqual('Enabled', lResults[0].Name);
  Assert.AreEqual('property', lResults[0].Kind);
  Assert.AreEqual('TSymbolMapFixture', lResults[0].OwnerName);

  lResults := TDelphiSemanticSymbolQuery.Search(lContext, 'TSystemFixture', 10);

  Assert.AreEqual(1, Integer(Length(lResults)));
  Assert.AreEqual('rtl-source', lResults[0].SourceKind);
  Assert.AreEqual('SymbolQueryRtlUnit', lResults[0].OwnerName);

  lResults := TDelphiSemanticSymbolQuery.Search(lContext, 'Length', 10);

  Assert.AreEqual(1, Integer(Length(lResults)));
  Assert.AreEqual('intrinsic-routine', lResults[0].Kind);
  Assert.AreEqual('compiler-profile', lResults[0].SourceKind);
end;

procedure TSymbolQueryTests.DescribesOwnedMembersAndIntrinsics;
var
  lContext: TDelphiSemanticSymbolQueryContext;
  lResult: TDelphiSemanticSymbolQueryResult;
begin
  lContext := LoadContext;

  lResult := TDelphiSemanticSymbolQuery.DescribeOwnedMember(lContext, 'TSymbolMapFixture',
    'Name');

  Assert.IsTrue(lResult.Found);
  Assert.AreEqual('Name: string', lResult.Description);

  lResult := TDelphiSemanticSymbolQuery.FindDefinitionByName(lContext, 'Length');

  Assert.IsTrue(lResult.Found);
  Assert.AreEqual('Length: Integer', lResult.Description);
end;

procedure TSymbolQueryTests.FindsTokenReferencesInProjectScope;
var
  lContext: TDelphiSemanticSymbolQueryContext;
  lReferences: TArray<TDelphiSemanticSymbolReferenceResult>;
begin
  lContext := LoadContext;

  lReferences := TDelphiSemanticSymbolQuery.FindTokenReferences(lContext,
    'TSymbolMapFixture', 10);

  Assert.IsTrue(Length(lReferences) >= 2);
  Assert.AreEqual('token-name-match', lReferences[0].Confidence);
  Assert.AreEqual('project-source', lReferences[0].SourceKind);
  Assert.AreEqual(FixturePath('SymbolQuery', 'SymbolQueryUnit.pas'), lReferences[0].FileName);
end;

procedure TSymbolQueryTests.SearchMatchesSubstringsAndReturnsRanges;
var
  lContext: TDelphiSemanticSymbolQueryContext;
  lFoundProjectType: Boolean;
  lFoundRtlType: Boolean;
  lResult: TDelphiSemanticSymbolQueryResult;
  lResults: TArray<TDelphiSemanticSymbolQueryResult>;
begin
  lFoundProjectType := False;
  lFoundRtlType := False;
  lContext := LoadContext;

  lResults := TDelphiSemanticSymbolQuery.Search(lContext, 'Fixture', 10);

  for lResult in lResults do
  begin
    if SameText(lResult.Name, 'TSymbolMapFixture') then
    begin
      lFoundProjectType := True;
      Assert.AreEqual('SymbolQueryUnit', lResult.UnitName);
      Assert.IsTrue(lResult.EndLine >= lResult.Line);
      Assert.IsTrue(lResult.EndColumn >= lResult.Column);
    end else if SameText(lResult.Name, 'TSystemFixture') then
    begin
      lFoundRtlType := True;
      Assert.AreEqual('rtl-source', lResult.SourceKind);
      Assert.AreEqual('SymbolQueryRtlUnit', lResult.UnitName);
    end;
  end;

  Assert.IsTrue(lFoundProjectType);
  Assert.IsTrue(lFoundRtlType);
end;

procedure TSymbolQueryTests.SnapshotBackedQueriesUseProjectSnapshotIndexes;
var
  lBuilder: TDelphiProjectSnapshotBuilder;
  lContext: TDelphiSemanticSymbolQueryContext;
  lFileName: string;
  lFileNameId: TSemanticStringId;
  lAliasSymbol: TSemanticSymbolFact;
  lKindId: TSemanticStringId;
  lLocalSymbol: TSemanticSymbolFact;
  lLocalSymbolId: TSemanticSymbolId;
  lNameId: TSemanticStringId;
  lIndex: TDelphiSemanticProjectSymbolIndex;
  lProject: TDelphiProjectSnapshot;
  lReference: TSemanticReferenceFact;
  lReferences: TArray<TDelphiSemanticSymbolReferenceResult>;
  lResult: TDelphiSemanticSymbolQueryResult;
  lResults: TArray<TDelphiSemanticSymbolQueryResult>;
  lRootPath: string;
  lRoutineLocals: TArray<TDelphiSemanticIndexedSymbol>;
  lRoutineNameId: TSemanticStringId;
  lRoutineSymbol: TSemanticSymbolFact;
  lRoutineSymbols: TArray<TDelphiSemanticIndexedSymbol>;
  lScopedContext: TScopedSnapshotQueryContext;
  lScopes: TArray<TDelphiSemanticUnitModel>;
  lSectionKindId: TSemanticStringId;
  lSourceKindId: TSemanticStringId;
  lSiblingUnit: TUnitSnapshot;
  lSymbol: TSemanticSymbolFact;
  lUnit: TUnitSnapshot;
  lUnitNameId: TSemanticStringId;
begin
  lBuilder := TDelphiProjectSnapshotBuilder.Create;
  lProject := nil;
  lRootPath := '';
  try
    lRootPath := SymbolQueryTempPath('snapshot-query');
    TDirectory.CreateDirectory(lRootPath);
    lFileName := TPath.Combine(lRootPath, 'SnapshotQueryUnit.pas');
    TFile.WriteAllText(lFileName, 'unit SnapshotQueryUnit;' + sLineBreak +
      'interface' + sLineBreak + '  SnapshotOnlyValue: Integer;' + sLineBreak +
      'implementation' + sLineBreak + 'procedure Touch;' + sLineBreak + 'var' +
      sLineBreak + '  SnapshotOnlyValue: Integer;' + sLineBreak + 'begin' +
      sLineBreak + '      SnapshotOnlyValue := 1;' + sLineBreak + 'end;' +
      sLineBreak + 'end.', TEncoding.UTF8);

    lFileNameId := lBuilder.Strings.Intern(lFileName);
    lUnitNameId := lBuilder.Strings.Intern('SnapshotQueryUnit');
    lNameId := lBuilder.Strings.Intern('SnapshotOnlyValue');
    lKindId := lBuilder.Strings.Intern('var');
    lRoutineNameId := lBuilder.Strings.Intern('Touch');
    lSectionKindId := lBuilder.Strings.Intern('interface');
    lSourceKindId := lBuilder.Strings.Intern('snapshot-source');

    lUnit := TUnitSnapshot.Create(1, lFileNameId, lUnitNameId);
    try
      lSymbol := Default(TSemanticSymbolFact);
      lSymbol.NameId := lNameId;
      lSymbol.KindId := lKindId;
      lSymbol.SectionKindId := lSectionKindId;
      lSymbol.SourceKindId := lSourceKindId;
      lSymbol.Line := 3;
      lSymbol.Column := 3;
      lSymbol.EndLine := 3;
      lSymbol.EndColumn := 19;
      lUnit.AddSymbol(lSymbol);

      lAliasSymbol := Default(TSemanticSymbolFact);
      lAliasSymbol.NameId := lBuilder.Strings.Intern('SnapshotAlias');
      lAliasSymbol.KindId := lBuilder.Strings.Intern('alias');
      lAliasSymbol.SectionKindId := lSectionKindId;
      lAliasSymbol.SourceKindId := lSourceKindId;
      lAliasSymbol.Line := 4;
      lAliasSymbol.Column := 3;
      lAliasSymbol.EndLine := 4;
      lAliasSymbol.EndColumn := 15;
      lUnit.AddSymbol(lAliasSymbol);

      lRoutineSymbol := Default(TSemanticSymbolFact);
      lRoutineSymbol.NameId := lRoutineNameId;
      lRoutineSymbol.KindId := lBuilder.Strings.Intern('routine');
      lRoutineSymbol.SectionKindId := lBuilder.Strings.Intern('implementation');
      lRoutineSymbol.SourceKindId := lSourceKindId;
      lRoutineSymbol.Line := 5;
      lRoutineSymbol.Column := 11;
      lRoutineSymbol.EndLine := 5;
      lRoutineSymbol.EndColumn := 15;
      lUnit.AddSymbol(lRoutineSymbol);

      lLocalSymbol := Default(TSemanticSymbolFact);
      lLocalSymbol.NameId := lNameId;
      lLocalSymbol.KindId := lBuilder.Strings.Intern('local');
      lLocalSymbol.RoutineId := lRoutineNameId;
      lLocalSymbol.SectionKindId := lBuilder.Strings.Intern('implementation');
      lLocalSymbol.SourceKindId := lSourceKindId;
      lLocalSymbol.Line := 7;
      lLocalSymbol.Column := 3;
      lLocalSymbol.EndLine := 7;
      lLocalSymbol.EndColumn := 19;
      lLocalSymbolId := lUnit.AddSymbol(lLocalSymbol);

      lReference := Default(TSemanticReferenceFact);
      lReference.NameId := lNameId;
      lReference.TargetUnitId := lUnit.UnitId;
      lReference.TargetSymbolId := lLocalSymbolId;
      lReference.ClassificationId := lBuilder.Strings.Intern('read');
      lReference.RoutineId := lRoutineNameId;
      lReference.SectionKindId := lBuilder.Strings.Intern('implementation');
      lReference.SourceKindId := lSourceKindId;
      lReference.Line := 9;
      lReference.Column := 7;
      lReference.EndLine := 9;
      lReference.EndColumn := 23;
      lUnit.AddReference(lReference);

      lBuilder.AddUnit(lUnit);
      lUnit := nil;
    finally
      lUnit.Free;
    end;

    lSiblingUnit := TUnitSnapshot.Create(2,
      lBuilder.Strings.Intern(TPath.Combine(lRootPath, 'SnapshotOtherUnit.pas')),
      lBuilder.Strings.Intern('SnapshotOtherUnit'));
    try
      lBuilder.AddUnit(lSiblingUnit);
      lSiblingUnit := nil;
    finally
      lSiblingUnit.Free;
    end;
    lProject := lBuilder.Build;
  finally
    lBuilder.Free;
  end;

  lScopedContext := TScopedSnapshotQueryContext.Create(lProject);
  try
    lContext := lScopedContext.Context;

    lIndex := TDelphiSemanticApi.BuildProjectSymbolIndex(lContext);

    Assert.AreEqual(0, lIndex.Metrics.BuildInvocationCount);
    Assert.AreEqual(6, Integer(Length(lIndex.Symbols)));
    Assert.AreEqual(1, Integer(Length(lIndex.References)));
    lRoutineSymbols := lIndex.FindSymbolsByName('Touch');
    Assert.AreEqual(1, Integer(Length(lRoutineSymbols)));
    lRoutineLocals := lIndex.FindLocalSymbolsByRoutineIdAndName(lRoutineSymbols[0].Id,
      'SnapshotOnlyValue');
    Assert.AreEqual(1, Integer(Length(lRoutineLocals)));
    Assert.AreEqual('Touch', lRoutineLocals[0].OwnerName);
    lScopes := lIndex.FindVisibleUnitScopes('SnapshotQueryUnit', 'interface');
    Assert.AreEqual(1, Integer(Length(lScopes)));
    Assert.AreEqual('SnapshotQueryUnit', lScopes[0].UnitName);

    lResult := TDelphiSemanticSymbolQuery.FindDefinitionByName(lContext,
      'SnapshotOnlyValue');

    Assert.IsTrue(lResult.Found);
    Assert.AreEqual('SnapshotOnlyValue', lResult.Name);
    Assert.AreEqual('var', lResult.Kind);
    Assert.AreEqual('SnapshotQueryUnit', lResult.UnitName);
    Assert.AreEqual('interface', lResult.SectionKind);
    Assert.AreEqual('snapshot-source', lResult.SourceKind);
    Assert.AreEqual(lFileName, lResult.FileName);

    lResult := TDelphiSemanticSymbolQuery.FindDefinitionByName(lContext, 'SnapshotAlias');

    Assert.IsTrue(lResult.Found);
    Assert.AreEqual('type-alias', lResult.Kind);

    lResult := TDelphiSemanticSymbolQuery.FindDefinitionAtPosition(lContext, lFileName, 9,
      10);

    Assert.IsTrue(lResult.Found);
    Assert.AreEqual('SnapshotOnlyValue', lResult.Name);
    Assert.AreEqual(7, lResult.Line,
      'Expected snapshot position lookup to follow the reference target, not a global name fallback.');

    lResults := TDelphiSemanticSymbolQuery.SearchAllMatches(lContext, 'SnapshotOnly', 10);

    Assert.AreEqual(1, Integer(Length(lResults)));
    Assert.AreEqual('SnapshotOnlyValue', lResults[0].Name);

    lReferences := TDelphiSemanticSymbolQuery.FindTokenReferences(lContext,
      'SnapshotOnlyValue', 10);

    Assert.AreEqual(1, Integer(Length(lReferences)));
    Assert.AreEqual('SnapshotOnlyValue', lReferences[0].Name);
    Assert.AreEqual('read', lReferences[0].Role);
    Assert.AreEqual('snapshot-source', lReferences[0].SourceKind);
  finally
    lScopedContext.Free;
    lProject.Free;
  end;
end;

procedure TSymbolQueryTests.TokenReferencesExposeMetadata;
var
  i: Integer;
  lContext: TDelphiSemanticSymbolQueryContext;
  lReferences: TArray<TDelphiSemanticSymbolReferenceResult>;
  lReferenceIndex: Integer;
begin
  lContext := LoadContext;
  lReferenceIndex := -1;
  for i := 0 to High(lContext.UnitModel.References) do
    if SameText(lContext.UnitModel.References[i].Name, 'TSymbolMapFixture') then
    begin
      lReferenceIndex := i;
      Break;
    end;
  Assert.IsTrue(lReferenceIndex >= 0, 'Expected fixture reference.');
  lContext.UnitModel.References[lReferenceIndex].Role := 'type-reference';
  lContext.UnitModel.References[lReferenceIndex].SectionKind := 'interface';
  lContext.UnitModel.References[lReferenceIndex].EndLine :=
    lContext.UnitModel.References[lReferenceIndex].Line;
  lContext.UnitModel.References[lReferenceIndex].EndColumn :=
    lContext.UnitModel.References[lReferenceIndex].Column + 18;

  lReferences := TDelphiSemanticSymbolQuery.FindTokenReferences(lContext,
    'TSymbolMapFixture', 1);

  Assert.AreEqual(1, Integer(Length(lReferences)));
  Assert.AreEqual('SymbolQueryUnit', lReferences[0].UnitName);
  Assert.AreEqual('type-reference', lReferences[0].Role);
  Assert.AreEqual('interface', lReferences[0].SectionKind);
  Assert.AreEqual(lContext.UnitModel.References[lReferenceIndex].EndColumn, lReferences[0].EndColumn);
end;

procedure TSymbolQueryTests.SnapshotPositionLookupUsesSharedResolver;
var
  lPositionResolverSourceText: string;
  lQuerySourceText: string;
  lUsageSourceText: string;
begin
  lQuerySourceText := ReadRepoSource('src\DelphiSemantics.Query.pas');
  lPositionResolverSourceText := ReadRepoSource('src\DelphiSemantics.Snapshot.PositionResolver.pas');
  lUsageSourceText := ReadRepoSource('src\DelphiSemantics.Usage.pas');

  Assert.IsTrue(ContainsText(lPositionResolverSourceText, 'TryResolveSnapshotPosition('),
    'Snapshot position resolution must live in one internal resolver unit.');
  Assert.IsTrue(ContainsText(lPositionResolverSourceText,
    'TDelphiSemanticSnapshotPositionResolution'),
    'The shared resolver must return the resolved reference, symbol, and source unit facts.');
  Assert.IsFalse(ContainsText(lQuerySourceText,
    'function TryResolveSnapshotPosition(const aSnapshot'),
    'Query must not expose the internal snapshot position resolver in its public interface.');
  Assert.IsTrue(ContainsText(lQuerySourceText, 'TryResolveSnapshotPosition('),
    'Definition-at-position must delegate to the shared resolver.');
  Assert.IsTrue(ContainsText(lUsageSourceText, 'TryResolveSnapshotPosition('),
    'Usage must delegate snapshot position lookup to the shared resolver.');
  Assert.IsFalse(ContainsText(lUsageSourceText, 'TryFindSnapshotUsageSymbolAtReference'),
    'Usage must not keep a separate reference-first position helper.');
end;

procedure TSymbolQueryTests.SnapshotPositionResolverFallsBackWhenReferenceTargetIsStale;
var
  lBuilder: TDelphiProjectSnapshotBuilder;
  lFileNameId: TSemanticStringId;
  lNameId: TSemanticStringId;
  lProject: TDelphiProjectSnapshot;
  lReference: TSemanticReferenceFact;
  lResolution: TDelphiSemanticSnapshotPositionResolution;
  lSymbol: TSemanticSymbolFact;
  lUnit: TUnitSnapshot;
  lUnitNameId: TSemanticStringId;
begin
  lBuilder := TDelphiProjectSnapshotBuilder.Create;
  try
    lFileNameId := lBuilder.Strings.Intern('StaleTargetUnit.pas');
    lUnitNameId := lBuilder.Strings.Intern('StaleTargetUnit');
    lNameId := lBuilder.Strings.Intern('StaleValue');
    lUnit := TUnitSnapshot.Create(1, lFileNameId, lUnitNameId);

    lSymbol := Default(TSemanticSymbolFact);
    lSymbol.NameId := lNameId;
    lSymbol.Line := 10;
    lSymbol.Column := 3;
    lSymbol.EndLine := 10;
    lSymbol.EndColumn := 12;
    lUnit.AddSymbol(lSymbol);

    lReference := Default(TSemanticReferenceFact);
    lReference.NameId := lNameId;
    lReference.TargetUnitId := 1;
    lReference.TargetSymbolId := 99;
    lReference.Line := 10;
    lReference.Column := 3;
    lReference.EndLine := 10;
    lReference.EndColumn := 12;
    lUnit.AddReference(lReference);

    lBuilder.AddUnit(lUnit);
    lProject := lBuilder.Build;
  finally
    lBuilder.Free;
  end;
  try
    Assert.IsTrue(TryResolveSnapshotPosition(lProject, 'StaleTargetUnit.pas', 10, 5,
      'StaleValue', lResolution));
    Assert.AreEqual('snapshot-position-match', lResolution.Status);
    Assert.AreEqual(1, Integer(lResolution.SymbolRef.SymbolId));
    Assert.IsTrue(lResolution.SymbolFound);
    Assert.IsFalse(lResolution.ReferenceFound,
      'Stale reference target must not short-circuit symbol-at-position fallback.');
  finally
    lProject.Free;
  end;
end;

procedure TSymbolQueryTests.LimitsTokenReferenceResults;
var
  lContext: TDelphiSemanticSymbolQueryContext;
  lReferences: TArray<TDelphiSemanticSymbolReferenceResult>;
begin
  lContext := LoadContext;

  lReferences := TDelphiSemanticSymbolQuery.FindTokenReferences(lContext,
    'TSymbolMapFixture', 1);

  Assert.AreEqual(1, Integer(Length(lReferences)));
end;

procedure TSymbolQueryTests.ResolvesCoreSymbolKindsWithoutShellingOut;
var
  lContext: TDelphiSemanticSymbolQueryContext;
  lResult: TDelphiSemanticSymbolQueryResult;
begin
  lContext := LoadContext;

  lResult := TDelphiSemanticSymbolQuery.FindDefinitionByName(lContext, 'TSymbolMapFixture');
  Assert.AreEqual('type', lResult.Kind);

  lResult := TDelphiSemanticSymbolQuery.DescribeOwnedMember(lContext, 'TSymbolMapFixture',
    'Enabled');
  Assert.AreEqual('property', lResult.Kind);

  lResult := TDelphiSemanticSymbolQuery.FindDefinitionByName(lContext, 'Execute');
  Assert.AreEqual('routine', lResult.Kind);

  lResult := TDelphiSemanticSymbolQuery.FindDefinitionByName(lContext, 'GlobalQueryValue');
  Assert.AreEqual('var', lResult.Kind);

  lResult := TDelphiSemanticSymbolQuery.FindDefinitionByName(lContext, 'TObject');
  Assert.AreEqual('intrinsic-type', lResult.Kind);
end;

procedure TSymbolQueryTests.ResolvesSourcePositionAndReportsCacheStatus;
var
  lContext: TDelphiSemanticSymbolQueryContext;
  lResult: TDelphiSemanticSymbolQueryResult;
  lStatus: TDelphiSemanticSymbolQueryCacheStatus;
begin
  lContext := LoadContext;

  lResult := TDelphiSemanticSymbolQuery.FindDefinitionAtPosition(lContext,
    FixturePath('SymbolQuery', 'SymbolQueryUnit.pas'), 36, 3);

  Assert.IsTrue(lResult.Found);
  Assert.AreEqual('GlobalQueryValue', lResult.Name);

  lResult := TDelphiSemanticSymbolQuery.FindDefinitionAtPosition(lContext,
    FixturePath('SymbolQuery', 'SymbolQueryRtlUnit.pas'), 10, 3);

  Assert.IsTrue(lResult.Found);
  Assert.AreEqual('TDeclarationRecord', lResult.Name);
  Assert.AreEqual('rtl-source', lResult.SourceKind);
  Assert.AreEqual(FixturePath('SymbolQuery', 'SymbolQueryRtlUnit.pas'), lResult.FileName);

  lResult := TDelphiSemanticSymbolQuery.FindDefinitionAtPosition(lContext,
    FixturePath('SymbolQuery', 'SymbolQueryUnit.pas'), 39, 3);

  Assert.IsTrue(lResult.Found);
  Assert.AreEqual('Length', lResult.Name);
  Assert.AreEqual('intrinsic-routine', lResult.Kind);
  Assert.AreEqual('compiler-profile', lResult.SourceKind);

  lStatus := TDelphiSemanticSymbolQuery.GetCacheStatus(lContext);

  Assert.AreEqual('in-memory', lStatus.CacheKind);
  Assert.AreEqual(2, lStatus.CacheMisses);
  Assert.AreEqual('Delphi-12-SymbolQuery', lStatus.CompilerProfileName);
  Assert.IsTrue(lStatus.IntrinsicCount >= 47);
  Assert.AreEqual(1, lStatus.RtlSourceUnitCount);
end;

procedure TSymbolQueryTests.ResolvesPositionFromCapturedModelSourceAfterDiskEdit;
var
  lCache: TDelphiSemanticUnitCache;
  lCacheOptions: TDelphiSemanticCacheOptions;
  lContext: TDelphiSemanticSymbolQueryContext;
  lModelOptions: TDelphiSemanticModelOptions;
  lResult: TDelphiSemanticSymbolQueryResult;
  lSourceFileName: string;
  lSourceText: string;
begin
  lSourceFileName := SymbolQueryTempPath('captured-source-position\SymbolQueryUnit.pas');
  TDirectory.CreateDirectory(TPath.GetDirectoryName(lSourceFileName));
  TFile.Copy(FixturePath('SymbolQuery', 'SymbolQueryUnit.pas'), lSourceFileName, True);

  lCacheOptions := Default(TDelphiSemanticCacheOptions);
  lCacheOptions.CompilerProfileName := 'Delphi-12-SymbolQuery-CapturedSource';
  lCache := TDelphiSemanticUnitCache.Create(lCacheOptions);
  try
    lModelOptions := Default(TDelphiSemanticModelOptions);
    lModelOptions.SourceFileName := lSourceFileName;
    lModelOptions.ProjectContextApplied := True;
    lContext.UnitModel := lCache.GetOrExtractUnitModel(lModelOptions);
    lContext.CompilerProfile := TDelphiSemanticCompilerProfileBuilder.FromCachedSources(lCache, []);
    lContext.CacheMetrics := lCache.Metrics;
  finally
    lCache.Free;
  end;

  lSourceText := TFile.ReadAllText(lSourceFileName, TEncoding.UTF8);
  lSourceText := StringReplace(lSourceText, '  lFixture: TSymbolMapFixture;',
    '  lEdited: Integer;', []);
  TFile.WriteAllText(lSourceFileName, lSourceText, TEncoding.UTF8);

  lResult := TDelphiSemanticSymbolQuery.FindDefinitionAtPosition(lContext, lSourceFileName,
    32, 13);

  Assert.IsTrue(lResult.Found);
  Assert.AreEqual('TSymbolMapFixture', lResult.Name);
  Assert.AreEqual('type', lResult.Kind);
end;

procedure TSymbolQueryTests.CacheStatusExposesProfileKeyAndCacheFileName;
var
  lContext: TDelphiSemanticSymbolQueryContext;
  lStatus: TDelphiSemanticSymbolQueryCacheStatus;
begin
  lContext := LoadContext;

  lStatus := TDelphiSemanticSymbolQuery.GetCacheStatus(lContext);

  Assert.AreEqual('', lStatus.CacheFileName);
  Assert.AreEqual('Delphi-12-SymbolQuery', lStatus.CompilerProfileKey);
end;

procedure TSymbolQueryTests.VisibleUnitScopesIncludeProjectAndRtlModels;
var
  lContext: TDelphiSemanticSymbolQueryContext;
  lFoundProject: Boolean;
  lFoundRtl: Boolean;
  lScope: TDelphiSemanticVisibleUnitScope;
  lScopes: TArray<TDelphiSemanticVisibleUnitScope>;
begin
  lFoundProject := False;
  lFoundRtl := False;
  lContext := LoadContext;

  lScopes := TDelphiSemanticSymbolQuery.GetVisibleUnitScopes(lContext);

  for lScope in lScopes do
  begin
    if SameText(lScope.UnitName, 'SymbolQueryUnit') then
    begin
      lFoundProject := True;
      Assert.AreEqual('project-source', lScope.SourceKind);
    end else if SameText(lScope.UnitName, 'SymbolQueryRtlUnit') then
    begin
      lFoundRtl := True;
      Assert.AreEqual('rtl-source', lScope.SourceKind);
    end;
  end;

  Assert.IsTrue(lFoundProject);
  Assert.IsTrue(lFoundRtl);
end;

procedure TSymbolQueryTests.IndexedProjectUnitsKeepSourceKindAndRoutineSearch;
var
  lContext: TDelphiSemanticSymbolQueryContext;
  lFoundScope: Boolean;
  lResult: TDelphiSemanticSymbolQueryResult;
  lResults: TArray<TDelphiSemanticSymbolQueryResult>;
  lScope: TDelphiSemanticVisibleUnitScope;
  lSibling: TDelphiSemanticUnitModel;
begin
  lContext := LoadContext;
  lSibling := Default(TDelphiSemanticUnitModel);
  lSibling.UnitName := 'SymbolQuerySiblingUnit';
  lSibling.FileName := FixturePath('SymbolQuery', 'SymbolQuerySiblingUnit.pas');
  SetLength(lSibling.Declarations, 2);
  lSibling.Declarations[0].Name := 'SiblingExact';
  lSibling.Declarations[0].Kind := 'type';
  lSibling.Declarations[0].Line := 3;
  lSibling.Declarations[0].Column := 3;
  lSibling.Declarations[1].Name := 'SiblingExactExtended';
  lSibling.Declarations[1].Kind := 'type';
  lSibling.Declarations[1].Line := 4;
  lSibling.Declarations[1].Column := 3;
  SetLength(lSibling.Members, 1);
  lSibling.Members[0].OwnerName := 'TSiblingOwner';
  lSibling.Members[0].Name := 'SiblingName';
  lSibling.Members[0].Kind := 'property';
  lSibling.Members[0].TypeName := 'string';
  lSibling.Members[0].Line := 5;
  lSibling.Members[0].Column := 5;
  SetLength(lSibling.Routines, 1);
  lSibling.Routines[0].Name := 'SiblingRoutine';
  lSibling.Routines[0].Signature := 'procedure SiblingRoutine';
  lSibling.Routines[0].Line := 7;
  lSibling.Routines[0].Column := 3;
  lContext.IndexedUnitModels := [lSibling, lContext.IndexedUnitModels[0]];
  lContext.IndexedUnitSourceKinds := ['project-source', 'rtl-source'];

  lFoundScope := False;
  for lScope in TDelphiSemanticSymbolQuery.GetVisibleUnitScopes(lContext) do
    if SameText(lScope.UnitName, 'SymbolQuerySiblingUnit') then
    begin
      lFoundScope := True;
      Assert.AreEqual('project-source', lScope.SourceKind);
    end;

  lResults := TDelphiSemanticSymbolQuery.Search(lContext, 'SiblingRoutine', 10);

  Assert.IsTrue(lFoundScope);
  Assert.AreEqual(1, Integer(Length(lResults)));
  lResult := lResults[0];
  Assert.AreEqual('routine', lResult.Kind);
  Assert.AreEqual('project-source', lResult.SourceKind);
  Assert.AreEqual('procedure SiblingRoutine', lResult.Signature);

  lResult := TDelphiSemanticSymbolQuery.DescribeOwnedMember(lContext, 'TSiblingOwner',
    'SiblingName');

  Assert.IsTrue(lResult.Found);
  Assert.AreEqual('property', lResult.Kind);
  Assert.AreEqual('project-source', lResult.SourceKind);

  lResults := TDelphiSemanticSymbolQuery.SearchAllMatches(lContext, 'SiblingExact', 10);

  Assert.AreEqual(2, Integer(Length(lResults)));
end;

procedure TSymbolQueryTests.BuildsProjectSymbolIndexWithResolvedAmbiguousAndUnresolvedReferences;
var
  lAmbiguous: TDelphiSemanticUnitModel;
  lContext: TDelphiSemanticSymbolQueryContext;
  lHidden: TDelphiSemanticUnitModel;
  lIndex: TDelphiSemanticProjectSymbolIndex;
  lReference: TDelphiSemanticIndexedReference;
  lResolvedFixture: Boolean;
  lResolvedLowerCase: Boolean;
  lSawAmbiguous: Boolean;
  lSawHidden: Boolean;
  lSawImplementationOnly: Boolean;
  lSawUnresolved: Boolean;
  lSymbol: TDelphiSemanticIndexedSymbol;
  lSymbolIds: TStringList;
begin
  lContext := LoadContext;
  lAmbiguous := Default(TDelphiSemanticUnitModel);
  lAmbiguous.UnitName := 'AmbiguousSymbolUnit';
  lAmbiguous.FileName := FixturePath('SymbolQuery', 'AmbiguousSymbolUnit.pas');
  SetLength(lAmbiguous.Declarations, 2);
  lAmbiguous.Declarations[0].Name := 'GlobalQueryValue';
  lAmbiguous.Declarations[0].Kind := 'var';
  lAmbiguous.Declarations[0].SectionKind := 'interface';
  lAmbiguous.Declarations[0].Line := 3;
  lAmbiguous.Declarations[0].Column := 3;
  lAmbiguous.Declarations[1].Name := 'ImplementationOnlyValue';
  lAmbiguous.Declarations[1].Kind := 'var';
  lAmbiguous.Declarations[1].SectionKind := 'implementation';
  lAmbiguous.Declarations[1].Line := 4;
  lAmbiguous.Declarations[1].Column := 3;
  lHidden := Default(TDelphiSemanticUnitModel);
  lHidden.UnitName := 'HiddenSymbolUnit';
  lHidden.FileName := FixturePath('SymbolQuery', 'HiddenSymbolUnit.pas');
  SetLength(lHidden.Declarations, 1);
  lHidden.Declarations[0].Name := 'HiddenUniqueValue';
  lHidden.Declarations[0].Kind := 'var';
  lHidden.Declarations[0].SectionKind := 'interface';
  lHidden.Declarations[0].Line := 4;
  lHidden.Declarations[0].Column := 3;
  lContext.IndexedUnitModels := lContext.IndexedUnitModels + [lAmbiguous, lHidden];
  lContext.IndexedUnitSourceKinds := lContext.IndexedUnitSourceKinds +
    ['project-source', 'project-source'];
  lContext.UnitModel.ImplementationUses := lContext.UnitModel.ImplementationUses +
    ['AmbiguousSymbolUnit'];
  SetLength(lContext.UnitModel.References, Length(lContext.UnitModel.References) + 3);
  lContext.UnitModel.References[High(lContext.UnitModel.References) - 1].Name := 'globalqueryvalue';
  lContext.UnitModel.References[High(lContext.UnitModel.References) - 1].Line := 99;
  lContext.UnitModel.References[High(lContext.UnitModel.References) - 1].Column := 3;
  lContext.UnitModel.References[High(lContext.UnitModel.References)].Name :=
    'HiddenUniqueValue';
  lContext.UnitModel.References[High(lContext.UnitModel.References)].Line := 100;
  lContext.UnitModel.References[High(lContext.UnitModel.References)].Column := 3;
  lContext.UnitModel.References[High(lContext.UnitModel.References) - 2].Name := 'DoesNotExist';
  lContext.UnitModel.References[High(lContext.UnitModel.References) - 2].Line := 101;
  lContext.UnitModel.References[High(lContext.UnitModel.References) - 2].Column := 3;
  lContext.UnitModel.References[High(lContext.UnitModel.References) - 2].SectionKind :=
    'implementation';
  SetLength(lContext.UnitModel.References, Length(lContext.UnitModel.References) + 1);
  lContext.UnitModel.References[High(lContext.UnitModel.References)].Name :=
    'ImplementationOnlyValue';
  lContext.UnitModel.References[High(lContext.UnitModel.References)].Line := 102;
  lContext.UnitModel.References[High(lContext.UnitModel.References)].Column := 3;
  lContext.UnitModel.References[High(lContext.UnitModel.References)].SectionKind :=
    'implementation';
  SetLength(lContext.UnitModel.References, Length(lContext.UnitModel.References) + 1);
  lContext.UnitModel.References[High(lContext.UnitModel.References)].Name := 'Name';
  lContext.UnitModel.References[High(lContext.UnitModel.References)].Line := 103;
  lContext.UnitModel.References[High(lContext.UnitModel.References)].Column := 3;
  lContext.UnitModel.References[High(lContext.UnitModel.References)].SectionKind :=
    'implementation';
  lIndex := TDelphiSemanticApi.BuildProjectSymbolIndex(lContext);

  lSymbolIds := TStringList.Create;
  try
    lSymbolIds.Sorted := True;
    lSymbolIds.Duplicates := dupError;
    for lSymbol in lIndex.Symbols do
    begin
      Assert.AreNotEqual('', lSymbol.Id.Value);
      lSymbolIds.Add(lSymbol.Id.Value);
    end;
  finally
    lSymbolIds.Free;
  end;

  lResolvedFixture := False;
  lResolvedLowerCase := False;
  lSawAmbiguous := False;
  lSawHidden := False;
  lSawImplementationOnly := False;
  lSawUnresolved := False;
  for lReference in lIndex.References do
  begin
    if lReference.Name = 'globalqueryvalue' then
    begin
      lResolvedLowerCase := lReference.Status = 'ambiguous';
      Assert.AreEqual('case-insensitive-name-match', lReference.Confidence);
    end else if SameText(lReference.Name, 'TSymbolMapFixture') and
      (lReference.Status = 'resolved') then
    begin
      lResolvedFixture := True;
      Assert.AreNotEqual('', lReference.SymbolId.Value);
    end else if SameText(lReference.Name, 'GlobalQueryValue') then
    begin
      if lReference.Status = 'ambiguous' then
        lSawAmbiguous := True;
    end else if lReference.Name = 'DoesNotExist' then
    begin
      lSawUnresolved := lReference.Status = 'unresolved';
      Assert.AreEqual('no-candidates', lReference.Confidence);
    end else if lReference.Name = 'HiddenUniqueValue' then
    begin
      lSawHidden := True;
      Assert.AreEqual('unresolved', lReference.Status);
      Assert.AreEqual('no-candidates', lReference.Confidence);
    end else if lReference.Name = 'Name' then
    begin
      Assert.AreEqual('unresolved', lReference.Status);
      Assert.AreEqual('no-candidates', lReference.Confidence);
    end else if lReference.Name = 'ImplementationOnlyValue' then
    begin
      lSawImplementationOnly := True;
      Assert.AreEqual('unresolved', lReference.Status);
      Assert.AreEqual('no-candidates', lReference.Confidence);
    end;
  end;

  Assert.IsTrue(lResolvedFixture, 'Expected a resolved TSymbolMapFixture reference.');
  Assert.IsTrue(lSawAmbiguous, 'Expected an ambiguous GlobalQueryValue reference.');
  Assert.IsTrue(lSawHidden, 'Expected hidden unit reference to stay unresolved.');
  Assert.IsTrue(lSawImplementationOnly,
    'Expected implementation-only cross-unit reference to stay unresolved.');
  Assert.IsTrue(lResolvedLowerCase, 'Expected lower-case reference to match case-insensitively.');
  Assert.IsTrue(lSawUnresolved, 'Expected unresolved reference diagnostic.');
end;

procedure TSymbolQueryTests.OverloadedRoutineLocalReferenceStaysUnresolvedWithoutRoutineIdentity;
var
  lContext: TDelphiSemanticSymbolQueryContext;
  lIndex: TDelphiSemanticProjectSymbolIndex;
  lReference: TDelphiSemanticIndexedReference;
  lSawSharedLocal: Boolean;
begin
  // Low-level index contract: this model-only context intentionally has no project snapshot.
  lContext := Default(TDelphiSemanticSymbolQueryContext);
  lContext.UnitModel.UnitName := 'OverloadedLocalUnit';
  lContext.UnitModel.FileName := FixturePath('SymbolQuery', 'OverloadedLocalUnit.pas');
  SetLength(lContext.UnitModel.Declarations, 1);
  lContext.UnitModel.Declarations[0].Name := 'lShared';
  lContext.UnitModel.Declarations[0].Kind := 'var';
  lContext.UnitModel.Declarations[0].TypeName := 'Integer';
  lContext.UnitModel.Declarations[0].SectionKind := 'interface';
  lContext.UnitModel.Declarations[0].Line := 5;
  lContext.UnitModel.Declarations[0].Column := 3;
  SetLength(lContext.UnitModel.Routines, 2);
  lContext.UnitModel.Routines[0].Name := 'UseValue';
  lContext.UnitModel.Routines[0].SectionKind := 'implementation';
  lContext.UnitModel.Routines[0].Signature := 'procedure UseValue(aValue: Integer)';
  lContext.UnitModel.Routines[0].Line := 10;
  lContext.UnitModel.Routines[0].Column := 11;
  lContext.UnitModel.Routines[1].Name := 'UseValue';
  lContext.UnitModel.Routines[1].SectionKind := 'implementation';
  lContext.UnitModel.Routines[1].Signature := 'procedure UseValue(aValue: string)';
  lContext.UnitModel.Routines[1].Line := 20;
  lContext.UnitModel.Routines[1].Column := 11;
  SetLength(lContext.UnitModel.Locals, 2);
  lContext.UnitModel.Locals[0].RoutineName := 'UseValue';
  lContext.UnitModel.Locals[0].Name := 'lShared';
  lContext.UnitModel.Locals[0].Kind := 'var';
  lContext.UnitModel.Locals[0].TypeName := 'Integer';
  lContext.UnitModel.Locals[0].Line := 12;
  lContext.UnitModel.Locals[0].Column := 3;
  lContext.UnitModel.Locals[1].RoutineName := 'UseValue';
  lContext.UnitModel.Locals[1].Name := 'lShared';
  lContext.UnitModel.Locals[1].Kind := 'var';
  lContext.UnitModel.Locals[1].TypeName := 'Integer';
  lContext.UnitModel.Locals[1].Line := 22;
  lContext.UnitModel.Locals[1].Column := 3;
  SetLength(lContext.UnitModel.References, 1);
  lContext.UnitModel.References[0].Name := 'lShared';
  lContext.UnitModel.References[0].RoutineName := 'UseValue';
  lContext.UnitModel.References[0].SectionKind := 'implementation';
  lContext.UnitModel.References[0].Line := 24;
  lContext.UnitModel.References[0].Column := 3;

  lIndex := TDelphiSemanticApi.BuildProjectSymbolIndex(lContext);

  lSawSharedLocal := False;
  for lReference in lIndex.References do
    if SameText(lReference.Name, 'lShared') then
    begin
      lSawSharedLocal := True;
      Assert.AreEqual('unresolved', lReference.Status);
      Assert.AreEqual(0, Integer(Length(lReference.CandidateSymbolIds)));
    end;

  Assert.IsTrue(lSawSharedLocal);
end;

procedure TSymbolQueryTests.ProjectSymbolIndexResolvesReferencesWithoutSymbolScans;
var
  lContext: TDelphiSemanticSymbolQueryContext;
  lIndex: TDelphiSemanticProjectSymbolIndex;
begin
  lContext := LoadContext;

  lIndex := TDelphiSemanticApi.BuildProjectSymbolIndex(lContext);

  Assert.IsTrue(Length(lIndex.References) > 0);
  Assert.AreEqual(0, lIndex.Metrics.ReferenceResolutionSymbolScanCount);
end;

procedure TSymbolQueryTests.ProjectSymbolIndexUsesCaseInsensitiveLookupMaps;
var
  lContext: TDelphiSemanticSymbolQueryContext;
  lIndex: TDelphiSemanticProjectSymbolIndex;
  lModel: TDelphiSemanticUnitModel;
  lParameterLocal: TDelphiSemanticLocal;
  lReference: TDelphiSemanticIndexedReference;
  lReferences: TArray<TDelphiSemanticIndexedReference>;
  lScope: TDelphiSemanticUnitModel;
  lScopes: TArray<TDelphiSemanticUnitModel>;
  lSymbol: TDelphiSemanticIndexedSymbol;
  lSymbols: TArray<TDelphiSemanticIndexedSymbol>;
  lHidden: TDelphiSemanticUnitModel;
  lFoundReference: Boolean;
  lFoundRtlScope: Boolean;
  lSawHiddenScope: Boolean;
begin
  lContext := LoadContext;
  lHidden := Default(TDelphiSemanticUnitModel);
  lHidden.UnitName := 'HiddenSymbolUnit';
  lHidden.FileName := FixturePath('SymbolQuery', 'HiddenSymbolUnit.pas');
  lContext.IndexedUnitModels := lContext.IndexedUnitModels + [lHidden];
  lContext.IndexedUnitSourceKinds := lContext.IndexedUnitSourceKinds + ['project-source'];
  lContext.UnitModel.ImplementationUses := lContext.UnitModel.ImplementationUses +
    ['SymbolQueryRtlUnit'];
  lParameterLocal := Default(TDelphiSemanticLocal);
  lParameterLocal.RoutineName := 'UseSymbols';
  lParameterLocal.Name := 'aInjectedParam';
  lParameterLocal.Kind := 'parameter';
  lParameterLocal.TypeName := 'Integer';
  lParameterLocal.Line := 200;
  lParameterLocal.Column := 7;
  lContext.UnitModel.Locals := lContext.UnitModel.Locals + [lParameterLocal];
  lIndex := TDelphiSemanticApi.BuildProjectSymbolIndex(lContext);

  lSymbols := lIndex.FindTopLevelSymbolsByName('globalqueryvalue');

  Assert.AreEqual(1, Integer(Length(lSymbols)));
  Assert.AreEqual('GlobalQueryValue', lSymbols[0].Name);
  Assert.IsTrue(lIndex.FindSymbolById(lSymbols[0].Id, lSymbol));
  Assert.AreEqual('GlobalQueryValue', lSymbol.Name);
  lReferences := lIndex.FindReferencesBySymbolId(lSymbol.Id);
  Assert.IsTrue(Length(lReferences) > 0);

  lSymbols := lIndex.FindSymbolsByName('tsymbolmapfixture');
  Assert.IsTrue(Length(lSymbols) > 0);
  Assert.AreEqual('TSymbolMapFixture', lSymbols[0].Name);

  lSymbols := lIndex.FindLocalSymbolsByRoutineAndName('usesymbols', 'lfixture');
  Assert.AreEqual(1, Integer(Length(lSymbols)));
  Assert.AreEqual('UseSymbols', lSymbols[0].OwnerName);
  Assert.AreEqual('var', lSymbols[0].Kind);

  lSymbols := lIndex.FindLocalSymbolsByRoutineAndName('usesymbols', 'ainjectedparam');
  Assert.AreEqual(1, Integer(Length(lSymbols)));
  Assert.AreEqual('UseSymbols', lSymbols[0].OwnerName);
  Assert.AreEqual('parameter', lSymbols[0].Kind);

  lSymbols := lIndex.FindMembersByOwnerAndName('tsymbolmapfixture', 'enabled');
  Assert.AreEqual(1, Integer(Length(lSymbols)));
  Assert.AreEqual('TSymbolMapFixture', lSymbols[0].OwnerName);
  Assert.AreEqual('property', lSymbols[0].Kind);

  lReferences := lIndex.FindReferencesByName('tsymbolmapfixture');
  lFoundReference := False;
  for lReference in lReferences do
    if SameText(lReference.Name, 'TSymbolMapFixture') then
      lFoundReference := True;

  Assert.IsTrue(lFoundReference);
  Assert.IsTrue(lIndex.FindUnitModelByName('symbolqueryunit', lModel));
  Assert.AreEqual('SymbolQueryUnit', lModel.UnitName);

  lFoundRtlScope := False;
  lSawHiddenScope := False;
  lScopes := lIndex.FindVisibleUnitScopes('symbolqueryunit', 'implementation');
  Assert.IsTrue(Length(lScopes) >= 2);
  Assert.AreEqual('SymbolQueryUnit', lScopes[0].UnitName);
  for lScope in lScopes do
  begin
    if SameText(lScope.UnitName, 'SymbolQueryRtlUnit') then
      lFoundRtlScope := True;
    if SameText(lScope.UnitName, 'HiddenSymbolUnit') then
      lSawHiddenScope := True;
  end;
  Assert.IsTrue(lFoundRtlScope);
  Assert.IsFalse(lSawHiddenScope);
end;

procedure TSymbolQueryTests.SnapshotProjectionHelpersLiveInQuerySupport;
var
  lIndexSource: string;
  lQuerySource: string;
  lSearchSource: string;
  lSupportSource: string;
  lUsageSource: string;
begin
  lSupportSource := ReadRepoSource('src\DelphiSemantics.Snapshot.QuerySupport.pas');
  lQuerySource := ReadRepoSource('src\DelphiSemantics.Query.pas');
  lUsageSource := ReadRepoSource('src\DelphiSemantics.Usage.pas');
  lSearchSource := ReadRepoSource('src\DelphiSemantics.Search.pas');
  lIndexSource := ReadRepoSource('src\DelphiSemantics.Index.pas');

  Assert.IsTrue(ContainsText(lSupportSource, 'function SnapshotEndLine'),
    'Snapshot end-range projection should be centralized.');
  Assert.IsTrue(ContainsText(lSupportSource, 'function SnapshotIndexedSymbol'),
    'Snapshot indexed-symbol projection should be centralized.');
  Assert.IsTrue(ContainsText(lSupportSource, 'function SnapshotSourceKindForUnit'),
    'Snapshot unit source-kind projection should be centralized.');
  Assert.IsTrue(ContainsText(lSupportSource, 'function SnapshotUnitSymbolId'),
    'Snapshot unit-id projection should be centralized.');

  Assert.IsFalse(ContainsText(lQuerySource, 'function SnapshotEndLine'),
    'Query should delegate snapshot range projection to QuerySupport.');
  Assert.IsFalse(ContainsText(lUsageSource, 'function SnapshotEndLine'),
    'Usage should delegate snapshot range projection to QuerySupport.');
  Assert.IsFalse(ContainsText(lUsageSource, 'function SnapshotIndexedSymbol'),
    'Usage should delegate snapshot symbol projection to QuerySupport.');
  Assert.IsFalse(ContainsText(lSearchSource, 'function SnapshotIndexedSymbol'),
    'Search should delegate snapshot symbol projection to QuerySupport.');
  Assert.IsFalse(ContainsText(lSearchSource, 'function SnapshotUnitSymbolId'),
    'Search should delegate snapshot unit projection to QuerySupport.');
  Assert.IsFalse(ContainsText(lIndexSource, 'function SnapshotUnitSymbolId'),
    'Index should delegate snapshot unit projection to QuerySupport.');
end;

procedure TSymbolQueryTests.LegacyModelIndexingLivesInCompatibilityAdapter;
var
  lAdapterPath: string;
  lAdapterSource: string;
  lIndexSource: string;
begin
  lAdapterPath := RepoSourcePath('src\DelphiSemantics.Index.LegacyModel.pas');
  Assert.IsTrue(TFile.Exists(lAdapterPath),
    'Legacy model-backed indexing should live in an explicit compatibility adapter.');

  lIndexSource := ReadRepoSource('src\DelphiSemantics.Index.pas');
  lAdapterSource := ReadRepoSource('src\DelphiSemantics.Index.LegacyModel.pas');

  Assert.IsTrue(ContainsText(lIndexSource, 'DelphiSemantics.Index.LegacyModel'),
    'Index should delegate model-backed index construction to the compatibility adapter.');
  Assert.IsTrue(ContainsText(lAdapterSource, 'TDelphiSemanticLegacyModelIndexer'),
    'The adapter should expose a focused model-backed indexer.');
  Assert.IsTrue(ContainsText(lAdapterSource, 'BuildSymbols') and
    ContainsText(lAdapterSource, 'BuildReferences'),
    'The adapter should keep legacy model symbol and reference construction together.');
  Assert.IsFalse(ContainsText(lIndexSource, 'procedure AddModelSymbols'),
    'Index should not own model symbol construction.');
  Assert.IsFalse(ContainsText(lIndexSource, 'procedure AddModelReferences'),
    'Index should not own model reference construction.');
  Assert.IsFalse(ContainsText(lIndexSource, 'procedure ResolveReference'),
    'Index should not own legacy model reference resolution.');
  Assert.IsTrue(ContainsText(lIndexSource, 'BuildSnapshotProjectSymbolIndex'),
    'Index should keep the snapshot project-index path separate from the model adapter.');
  Assert.IsFalse(ContainsText(lAdapterSource, 'TDelphiProjectSnapshot'),
    'The legacy model adapter should not own snapshot projection.');
  Assert.IsFalse(ContainsText(lAdapterSource, 'SnapshotIndexedSymbol'),
    'The legacy model adapter should not call snapshot projection helpers.');
end;

procedure TSymbolQueryTests.IncludeResultsKeepPhysicalOrigins(const aSnapshot: Boolean;
  const aName: string; const aLine, aColumn: Integer);
var
  lContext: TDelphiSemanticSymbolQueryContext;
  lMetrics: TDelphiSnapshotBuilderMetrics;
  lOptions: TDelphiSemanticModelOptions;
  lResult: TDelphiSemanticSymbolQueryResult;
  lReferences: TArray<TDelphiSemanticSymbolReferenceResult>;
  lRoot, lInclude: string;
  lSnapshot: TDelphiProjectSnapshot;
  lScopedContext: TScopedSnapshotQueryContext;
begin
  lRoot := CreateTestTempRoot('include-query-probe-temp');
  lInclude := TPath.Combine(lRoot, 'facts.inc');
  TFile.WriteAllText(lInclude,
    'type'#13#10'  TIncluded = record'#13#10'    Value: Integer;'#13#10'  end;'#13#10 +
    'procedure IncludedRun(aValue: Integer);'#13#10'var'#13#10'  lValue: Integer;'#13#10 +
    'begin'#13#10'  lValue := aValue;'#13#10'end;'#13#10, TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'IncludeFactProbe.pas'),
    'unit IncludeFactProbe;'#13#10'interface'#13#10'implementation'#13#10 +
    '{$I facts.inc}'#13#10'end.', TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := TPath.Combine(lRoot, 'IncludeFactProbe.pas');
  lOptions.SearchPaths := [lRoot];
  lOptions.ProjectContextApplied := True;
  lContext := Default(TDelphiSemanticSymbolQueryContext);
  lContext.UnitModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lContext.UnitModel.Success);
  if aName = 'unknown' then
  begin
    Assert.IsTrue(Length(lContext.UnitModel.Declarations) > 0);
    lContext.UnitModel.Declarations[0].Line := 0;
    lContext.UnitModel.Declarations[0].Column := 0;
  end;
  lSnapshot := nil;
  lScopedContext := nil;
  try
    if aSnapshot then
    begin
      lSnapshot := BuildProjectSnapshotFromModels([lContext.UnitModel],
        Default(TDelphiSemanticProjectWithBindingFacts),
        Default(TDelphiSnapshotBuildOptions), lMetrics);
      lScopedContext := TScopedSnapshotQueryContext.Create(lSnapshot);
      lContext.ProjectSnapshot := lScopedContext.Context.ProjectSnapshot;
    end;
    TFile.WriteAllText(lInclude, 'unrelated disk text', TEncoding.ASCII);
    if aName = 'reference' then
    begin
      lReferences := TDelphiSemanticSymbolQuery.FindTokenReferences(lContext, 'lValue', 100);
      Assert.IsTrue(Length(lReferences) > 0);
      for var i := 0 to High(lReferences) do
      begin
        Assert.AreEqual(lInclude, lReferences[i].FileName);
        Assert.AreEqual(aLine, lReferences[i].Line);
        Assert.AreEqual(aColumn, lReferences[i].Column);
      end;
    end else begin
      if aName = 'unknown' then
        lResult := TDelphiSemanticSymbolQuery.FindDefinitionByName(lContext, 'TIncluded')
      else if aName = 'lValue' then
        lResult := TDelphiSemanticSymbolQuery.FindDefinitionAtPosition(lContext, lInclude, 7, 3)
      else
        lResult := TDelphiSemanticSymbolQuery.FindDefinitionByName(lContext, aName);
      Assert.IsTrue(lResult.Found, aName);
      if aName = 'unknown' then
      begin
        Assert.AreEqual(0, lResult.Line);
        Assert.AreEqual(0, lResult.Column);
        Assert.AreEqual(0, lResult.EndColumn, 'Unknown positions cannot acquire a made-up endpoint.');
        Exit;
      end;
      Assert.AreEqual(lInclude, lResult.FileName);
      Assert.AreEqual(aLine, lResult.Line);
      Assert.AreEqual(aColumn, lResult.Column);
    end;
  finally
    lContext.ProjectSnapshot := nil;
    lScopedContext.Free;
    lSnapshot.Free;
  end;
end;

procedure TSymbolQueryTests.UnknownReferencePositionHasNoEndpoint(const aSnapshot: Boolean);
var
  lContext: TDelphiSemanticSymbolQueryContext;
  lSnapshot: TDelphiProjectSnapshot;
  lScopedContext: TScopedSnapshotQueryContext;
  lMetrics: TDelphiSnapshotBuilderMetrics;
  lReferences: TArray<TDelphiSemanticSymbolReferenceResult>;
begin
  lContext := Default(TDelphiSemanticSymbolQueryContext);
  lContext.UnitModel.Success := True;
  lContext.UnitModel.UnitName := 'QUnknown';
  lContext.UnitModel.FileName := TPath.Combine(CreateTestTempRoot('query-unknown-reference-temp'), 'QUnknown.pas');
  SetLength(lContext.UnitModel.References, 1);
  lContext.UnitModel.References[0].Name := 'UnknownRef';
  lSnapshot := nil;
  lScopedContext := nil;
  try
    if aSnapshot then
    begin
      lSnapshot := BuildProjectSnapshotFromModels([lContext.UnitModel],
        Default(TDelphiSemanticProjectWithBindingFacts), Default(TDelphiSnapshotBuildOptions), lMetrics);
      lScopedContext := TScopedSnapshotQueryContext.Create(lSnapshot);
      lContext.ProjectSnapshot := lScopedContext.Context.ProjectSnapshot;
    end;
    lReferences := TDelphiSemanticSymbolQuery.FindTokenReferences(lContext, 'UnknownRef', 10);
    Assert.AreEqual(1, Integer(Length(lReferences)));
    Assert.AreEqual(0, lReferences[0].Line);
    Assert.AreEqual(0, lReferences[0].Column);
    Assert.AreEqual(0, lReferences[0].EndLine);
    Assert.AreEqual(0, lReferences[0].EndColumn);
  finally
    lContext.ProjectSnapshot := nil;
    lScopedContext.Free;
    lSnapshot.Free;
  end;
end;

procedure TSymbolQueryTests.NestedMixedLineQueriesUseCapturedOrigins(const aSnapshot: Boolean);
var
  lContext: TDelphiSemanticSymbolQueryContext;
  lOptions: TDelphiSemanticModelOptions;
  lSnapshot: TDelphiProjectSnapshot;
  lScopedContext: TScopedSnapshotQueryContext;
  lMetrics: TDelphiSnapshotBuilderMetrics;
  lResult: TDelphiSemanticSymbolQueryResult;
  lReferences: TArray<TDelphiSemanticSymbolReferenceResult>;
  lRoot, lUnit, lInclude, lNested: string;
  lIncludedCount, lNestedCount, lRootCount: Integer;
begin
  lRoot := CreateTestTempRoot('query-physical-nested-temp');
  lUnit := TPath.Combine(lRoot, 'QOrigin.pas');
  lInclude := TPath.Combine(lRoot, 'middle.inc');
  lNested := TPath.Combine(lRoot, 'nested.inc');
  TFile.WriteAllText(lUnit,
    'unit QOrigin;'#13#10'interface'#13#10'implementation'#13#10 +
    'procedure RootRun; var lValue: Integer; begin lValue := 0; end;'#13#10 +
    '{$IFDEF NEVER}{$I inactive.inc}{$ENDIF}'#13#10 +
    '{$I middle.inc} procedure TailRun; begin end;'#13#10'end.', TEncoding.ASCII);
  TFile.WriteAllText(lInclude,
    'procedure IncludedRun;'#13#10'var lValue: Integer;'#13#10 +
    'begin lValue := 1; {$I nested.inc} end;'#13#10, TEncoding.ASCII);
  TFile.WriteAllText(lNested, 'lValue := 2;', TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'inactive.inc'),
    'procedure Ghost; begin end;', TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lUnit;
  lOptions.SearchPaths := [lRoot];
  lOptions.ProjectContextApplied := True;
  lContext := Default(TDelphiSemanticSymbolQueryContext);
  lContext.UnitModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lContext.UnitModel.Success);
  lSnapshot := nil;
  lScopedContext := nil;
  try
    if aSnapshot then
    begin
      lSnapshot := BuildProjectSnapshotFromModels([lContext.UnitModel],
        Default(TDelphiSemanticProjectWithBindingFacts), Default(TDelphiSnapshotBuildOptions), lMetrics);
      lScopedContext := TScopedSnapshotQueryContext.Create(lSnapshot);
      lContext.ProjectSnapshot := lScopedContext.Context.ProjectSnapshot;
      lContext.UnitModel := Default(TDelphiSemanticUnitModel);
    end;
    TFile.WriteAllText(lInclude, 'unrelated disk contents', TEncoding.ASCII);
    TFile.WriteAllText(lNested, 'RootRun;', TEncoding.ASCII);
    lResult := TDelphiSemanticSymbolQuery.FindDefinitionAtPosition(lContext, lInclude, 2, 5);
    Assert.IsTrue(lResult.Found, 'Included local declaration must resolve.');
    Assert.AreEqual(lInclude, lResult.FileName);
    Assert.AreEqual(2, lResult.Line);
    Assert.AreEqual(5, lResult.Column);
    Assert.AreEqual(10, lResult.EndColumn);
    lResult := TDelphiSemanticSymbolQuery.FindDefinitionAtPosition(lContext, lNested, 1, 1);
    Assert.IsTrue(lResult.Found, 'Nested reference must resolve to its captured routine local.');
    Assert.AreEqual(lInclude, lResult.FileName);
    Assert.AreEqual(2, lResult.Line);
    Assert.AreEqual(5, lResult.Column);
    lResult := TDelphiSemanticSymbolQuery.FindDefinitionByName(lContext, 'IncludedRun');
    Assert.AreEqual(lInclude, lResult.FileName);
    Assert.AreEqual(1, lResult.Line);
    Assert.AreEqual(11, lResult.Column);
    Assert.IsFalse(TDelphiSemanticSymbolQuery.FindDefinitionByName(lContext, 'Ghost').Found);
    lIncludedCount := 0;
    lNestedCount := 0;
    lRootCount := 0;
    lReferences := TDelphiSemanticSymbolQuery.FindTokenReferences(lContext, 'lValue', 100);
    for var lReference in lReferences do
      if SameText(lReference.FileName, lInclude) then
      begin
        Inc(lIncludedCount);
        Assert.AreEqual(3, lReference.Line);
        Assert.AreEqual(7, lReference.Column);
      end else if SameText(lReference.FileName, lNested) then
      begin
        Inc(lNestedCount);
        Assert.AreEqual(1, lReference.Line);
        Assert.AreEqual(1, lReference.Column);
      end else if SameText(lReference.FileName, lUnit) then
        Inc(lRootCount);
    Assert.AreEqual(1, lIncludedCount);
    Assert.AreEqual(1, lNestedCount);
    Assert.AreEqual(1, lRootCount);
  finally
    lContext.ProjectSnapshot := nil;
    lScopedContext.Free;
    lSnapshot.Free;
  end;
end;

procedure TSymbolQueryTests.MissingCapturedIncludeCannotUseCurrentDisk(const aSnapshot: Boolean);
var
  lContext: TDelphiSemanticSymbolQueryContext;
  lOptions: TDelphiSemanticModelOptions;
  lSnapshot: TDelphiProjectSnapshot;
  lScopedContext: TScopedSnapshotQueryContext;
  lMetrics: TDelphiSnapshotBuilderMetrics;
  lRoot, lInclude: string;
begin
  lRoot := CreateTestTempRoot('query-no-disk-refill-temp');
  lInclude := TPath.Combine(lRoot, 'captured.inc');
  TFile.WriteAllText(lInclude, 'var IncludedValue: Integer;', TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := TPath.Combine(lRoot, 'QMissing.pas');
  lOptions.SearchPaths := [lRoot];
  lOptions.ProjectContextApplied := True;
  TFile.WriteAllText(lOptions.SourceFileName,
    'unit QMissing; interface {$I captured.inc} implementation end.', TEncoding.ASCII);
  lContext := Default(TDelphiSemanticSymbolQueryContext);
  lContext.UnitModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lContext.UnitModel.Success);
  lContext.UnitModel.SourceObservations := nil;
  lContext.UnitModel.PhysicalSymbolOccurrencesAvailable := False;
  lContext.UnitModel.PhysicalReferenceOccurrencesAvailable := False;
  lContext.UnitModel.PhysicalSymbolOccurrences := nil;
  lContext.UnitModel.PhysicalReferenceOccurrences := nil;
  lSnapshot := nil;
  lScopedContext := nil;
  try
    if aSnapshot then
    begin
      lSnapshot := BuildProjectSnapshotFromModels([lContext.UnitModel],
        Default(TDelphiSemanticProjectWithBindingFacts), Default(TDelphiSnapshotBuildOptions), lMetrics);
      lScopedContext := TScopedSnapshotQueryContext.Create(lSnapshot);
      lContext.ProjectSnapshot := lScopedContext.Context.ProjectSnapshot;
      lContext.UnitModel := Default(TDelphiSemanticUnitModel);
    end;
    Assert.IsFalse(TDelphiSemanticSymbolQuery.FindDefinitionAtPosition(
      lContext, lInclude, 1, 5).Found, 'Missing capture cannot be refilled from disk.');
  finally
    lContext.ProjectSnapshot := nil;
    lScopedContext.Free;
    lSnapshot.Free;
  end;
end;

procedure TSymbolQueryTests.UnverifiedRootWitnessDoesNotPublishLegacyCoordinates(const aSnapshot: Boolean);
var
  lContext: TDelphiSemanticSymbolQueryContext;
  lOptions: TDelphiSemanticModelOptions;
  lSnapshot: TDelphiProjectSnapshot;
  lScopedContext: TScopedSnapshotQueryContext;
  lMetrics: TDelphiSnapshotBuilderMetrics;
  lResult: TDelphiSemanticSymbolQueryResult;
  lRoot: string;
  lChanged: Boolean;
begin
  lRoot := CreateTestTempRoot('query-unverified-root-temp');
  TFile.WriteAllText(TPath.Combine(lRoot, 'facts.inc'), 'var IncludedValue: Integer;', TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := TPath.Combine(lRoot, 'QWitness.pas');
  lOptions.SearchPaths := [lRoot];
  lOptions.ProjectContextApplied := True;
  TFile.WriteAllText(lOptions.SourceFileName,
    'unit QWitness;'#13#10'interface'#13#10'var RootValue: Integer;'#13#10 +
    '{$I facts.inc}'#13#10'implementation end.', TEncoding.ASCII);
  lContext := Default(TDelphiSemanticSymbolQueryContext);
  lContext.UnitModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lContext.UnitModel.Success);
  lChanged := False;
  for var i := 0 to High(lContext.UnitModel.PhysicalSymbolOccurrences) do
    if lContext.UnitModel.PhysicalSymbolOccurrences[i].Name = 'RootValue' then
    begin
      lContext.UnitModel.PhysicalSymbolOccurrences[i].Verified := False;
      lChanged := True;
    end;
  Assert.IsTrue(lChanged);
  lSnapshot := nil;
  lScopedContext := nil;
  try
    if aSnapshot then
    begin
      lSnapshot := BuildProjectSnapshotFromModels([lContext.UnitModel],
        Default(TDelphiSemanticProjectWithBindingFacts), Default(TDelphiSnapshotBuildOptions), lMetrics);
      lScopedContext := TScopedSnapshotQueryContext.Create(lSnapshot);
      lContext.ProjectSnapshot := lScopedContext.Context.ProjectSnapshot;
      lContext.UnitModel := Default(TDelphiSemanticUnitModel);
    end;
    lResult := TDelphiSemanticSymbolQuery.FindDefinitionByName(lContext, 'RootValue');
    Assert.IsTrue(lResult.Found);
    Assert.AreEqual(lOptions.SourceFileName, lResult.FileName);
    Assert.AreEqual(0, lResult.Line);
    Assert.AreEqual(0, lResult.Column);
    Assert.AreEqual(0, lResult.EndLine);
    Assert.AreEqual(0, lResult.EndColumn);
  finally
    lContext.ProjectSnapshot := nil;
    lScopedContext.Free;
    lSnapshot.Free;
  end;
end;

procedure TSymbolQueryTests.SharedIncludePositionDoesNotChooseAnArbitraryUnit(const aSnapshot: Boolean);
var
  lContext: TDelphiSemanticSymbolQueryContext;
  lOptions: TDelphiSemanticModelOptions;
  lSnapshot: TDelphiProjectSnapshot;
  lScopedContext: TScopedSnapshotQueryContext;
  lMetrics: TDelphiSnapshotBuilderMetrics;
  lRoot, lInclude, lName: string;
begin
  lRoot := CreateTestTempRoot('query-shared-include-temp');
  lInclude := TPath.Combine(lRoot, 'shared.inc');
  TFile.WriteAllText(lInclude,
    'procedure Run;'#13#10'var lValue: Integer;'#13#10'begin lValue := 1; end;', TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SearchPaths := [lRoot];
  lOptions.ProjectContextApplied := True;
  lContext := Default(TDelphiSemanticSymbolQueryContext);
  SetLength(lContext.IndexedUnitModels, 2);
  for var i := 0 to 1 do
  begin
    lName := 'QShared' + IntToStr(i);
    lOptions.SourceFileName := TPath.Combine(lRoot, lName + '.pas');
    TFile.WriteAllText(lOptions.SourceFileName,
      'unit ' + lName + ';'#13#10'interface'#13#10'implementation'#13#10 +
      '{$I shared.inc}'#13#10'end.', TEncoding.ASCII);
    lContext.IndexedUnitModels[i] := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
    Assert.IsTrue(lContext.IndexedUnitModels[i].Success);
  end;
  lSnapshot := nil;
  lScopedContext := nil;
  try
    if aSnapshot then
    begin
      lSnapshot := BuildProjectSnapshotFromModels(lContext.IndexedUnitModels,
        Default(TDelphiSemanticProjectWithBindingFacts), Default(TDelphiSnapshotBuildOptions), lMetrics);
      lScopedContext := TScopedSnapshotQueryContext.Create(lSnapshot);
      lContext.ProjectSnapshot := lScopedContext.Context.ProjectSnapshot;
      lContext.IndexedUnitModels := nil;
    end;
    Assert.IsFalse(TDelphiSemanticSymbolQuery.FindDefinitionAtPosition(lContext,
      lInclude, 2, 5).Found, 'One physical position belongs to two distinct unit scopes.');
  finally
    lContext.ProjectSnapshot := nil;
    lScopedContext.Free;
    lSnapshot.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TSymbolQueryTests);

end.
