unit Test.Usage;

interface

uses
  DUnitX.TestFramework,
  DelphiSemantics.Api,
  DelphiSemantics.Cache,
  DelphiSemantics.CompilerProfile,
  DelphiSemantics.Model,
  DelphiSemantics.ProjectContext,
  DelphiSemantics.ProjectSession,
  DelphiSemantics.Query,
  DelphiSemantics.Snapshot,
  DelphiSemantics.Usage;

type
  [TestFixture]
  TUsageTests = class
  private
    function LoadContext: TDelphiSemanticSymbolQueryContext;
  public
    [Test]
    procedure FindsUsagesForSourceLocationAndExplicitName;
    [Test]
    procedure ProjectSessionSnapshotUsagesCarryResolvedReferences;
    [Test]
    procedure SnapshotBackedUsagesReuseProjectSnapshotIndexes;
    [Test]
    procedure BlocksAmbiguousUsageTargets;
  end;

implementation

uses
  System.IOUtils, System.SysUtils,
  Winapi.Windows,
  maxLogic.IOUtils,
  Test.Support;

var
  GUsageTempRoot: string;

function UsageTempPath(const aName: string): string;
var
  lGuid: TGUID;
  lGuidText: string;
begin
  if GUsageTempRoot = '' then
  begin
    CreateGUID(lGuid);
    lGuidText := StringReplace(StringReplace(GUIDToString(lGuid), '{', '', [rfReplaceAll]), '}',
      '', [rfReplaceAll]);
    GUsageTempRoot := TPath.GetFullPath(CombinePath([ExtractFilePath(ParamStr(0)),
      'snapshot-usage-session-temp', 'run-' + GetCurrentProcessId.ToString + '-' + lGuidText]));
  end;
  TDirectory.CreateDirectory(GUsageTempRoot);
  Result := TPath.Combine(GUsageTempRoot, aName);
end;


function TUsageTests.LoadContext: TDelphiSemanticSymbolQueryContext;
var
  lCache: TDelphiSemanticUnitCache;
  lCacheOptions: TDelphiSemanticCacheOptions;
  lModelOptions: TDelphiSemanticModelOptions;
begin
  lCacheOptions := Default(TDelphiSemanticCacheOptions);
  lCacheOptions.CompilerProfileName := 'Delphi-12-Usage';
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

procedure TUsageTests.FindsUsagesForSourceLocationAndExplicitName;
var
  lContext: TDelphiSemanticSymbolQueryContext;
  lResult: TDelphiSemanticUsageResult;
  lUsage: TDelphiSemanticUsage;
  lFoundDeclaration: Boolean;
  lFoundImplementationReference: Boolean;
begin
  lFoundDeclaration := False;
  lFoundImplementationReference := False;
  lContext := LoadContext;

  lResult := TDelphiSemanticApi.FindUsagesAtPosition(lContext,
    FixturePath('SymbolQuery', 'SymbolQueryUnit.pas'), 6, 3);

  Assert.AreEqual('resolved', lResult.Status);
  Assert.AreEqual('TSymbolMapFixture', lResult.Symbol.Name);
  Assert.IsTrue(Length(lResult.Usages) >= 3);

  for lUsage in lResult.Usages do
  begin
    if SameText(lUsage.Role, 'declaration') and SameText(lUsage.SectionKind, 'interface') then
      lFoundDeclaration := True;
    if (lUsage.Line > 20) and SameText(lUsage.SectionKind, 'implementation') then
      lFoundImplementationReference := True;
  end;

  Assert.IsTrue(lFoundDeclaration);
  Assert.IsTrue(lFoundImplementationReference);

  lResult := TDelphiSemanticApi.FindUsagesByName(lContext, 'GlobalQueryValue');

  Assert.AreEqual('resolved', lResult.Status);
  Assert.AreEqual('GlobalQueryValue', lResult.Symbol.Name);
  Assert.IsTrue(Length(lResult.Usages) >= 3);
end;

procedure TUsageTests.ProjectSessionSnapshotUsagesCarryResolvedReferences;
var
  lContext: TDelphiSemanticSymbolQueryContext;
  lDprPath: string;
  lDprojPath: string;
  lFoundDeclaration: Boolean;
  lFoundReference: Boolean;
  lOptions: TDelphiSemanticOptions;
  lResult: TDelphiSemanticUsageResult;
  lRootPath: string;
  lSessionResult: TDelphiSemanticProjectSessionResult;
  lSnapshot: TDelphiProjectSnapshot;
  lUnitPath: string;
  lUsage: TDelphiSemanticUsage;
begin
  lRootPath := UsageTempPath('snapshot-usage-session');
  TDirectory.CreateDirectory(lRootPath);

  lDprPath := TPath.Combine(lRootPath, 'SnapshotUsageProject.dpr');
  lDprojPath := TPath.Combine(lRootPath, 'SnapshotUsageProject.dproj');
  lUnitPath := TPath.Combine(lRootPath, 'SnapshotUsageUnit.pas');
  TFile.WriteAllText(lDprPath, 'program SnapshotUsageProject;' + sLineBreak +
    'uses SnapshotUsageUnit;' + sLineBreak + 'begin' + sLineBreak + 'end.',
    TEncoding.UTF8);
  TFile.WriteAllText(lUnitPath, 'unit SnapshotUsageUnit;' + sLineBreak +
    'interface' + sLineBreak + 'var' + sLineBreak +
    '  SnapshotUsageProjectValue: Integer;' + sLineBreak + 'implementation' +
    sLineBreak + 'procedure Touch;' + sLineBreak + 'begin' + sLineBreak +
    '  SnapshotUsageProjectValue := 1;' + sLineBreak + 'end;' + sLineBreak +
    'end.', TEncoding.UTF8);
  TFile.WriteAllText(lDprojPath,
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' +
    sLineBreak + '  <PropertyGroup>' + sLineBreak +
    '    <ProjectGuid>{5E7CC978-CFB1-4669-8269-B73B2782AA77}</ProjectGuid>' +
    sLineBreak + '    <MainSource>SnapshotUsageProject.dpr</MainSource>' +
    sLineBreak + '  </PropertyGroup>' + sLineBreak + '  <ItemGroup>' +
    sLineBreak + '    <DCCReference Include="SnapshotUsageUnit.pas"/>' +
    sLineBreak + '  </ItemGroup>' + sLineBreak + '</Project>', TEncoding.UTF8);

  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := lDprojPath;

  try
    lSessionResult := TDelphiSemanticProjectSession.Open(lOptions);
    try
      Assert.IsTrue(lSessionResult.Success);
      lSnapshot := lSessionResult.Session.BuildSnapshot;
      try
        lContext := Default(TDelphiSemanticSymbolQueryContext);
        lContext.ProjectSnapshot := BorrowProjectSnapshot(lSnapshot);

        lResult := TDelphiSemanticUsageFinder.FindUsagesByName(lContext,
          'SnapshotUsageProjectValue');

        Assert.AreEqual('resolved', lResult.Status);
        Assert.AreEqual('SnapshotUsageProjectValue', lResult.Symbol.Name);
        Assert.AreEqual(0, lResult.IndexMetrics.BuildInvocationCount);

        lFoundDeclaration := False;
        lFoundReference := False;
        for lUsage in lResult.Usages do
        begin
          if SameText(lUsage.Role, 'declaration') then
            lFoundDeclaration := True;
          if not SameText(lUsage.Role, 'declaration') then
            lFoundReference := True;
        end;

        Assert.IsTrue(lFoundDeclaration);
        Assert.IsTrue(lFoundReference,
          'Expected the real session-built snapshot to carry a target-resolved project reference.');
      finally
        lSnapshot.Free;
      end;
    finally
      lSessionResult.Session.Free;
    end;
  finally
  end;
end;

procedure TUsageTests.SnapshotBackedUsagesReuseProjectSnapshotIndexes;
var
  lAliasReference: TSemanticReferenceFact;
  lAliasResult: TDelphiSemanticUsageResult;
  lAliasSymbol: TSemanticSymbolFact;
  lAliasSymbolId: TSemanticSymbolId;
  lBuilder: TDelphiProjectSnapshotBuilder;
  lContext: TDelphiSemanticSymbolQueryContext;
  lEquivalentCount: Integer;
  lEquivalentRef: TSemanticSymbolRef;
  lEquivalentSymbol: TSemanticSymbolFact;
  lEquivalentUnit: TUnitSnapshot;
  lFileNameId: TSemanticStringId;
  lHighIndex: Integer;
  i: Integer;
  lKindId: TSemanticStringId;
  lLowIndex: Integer;
  lMethodReference: TSemanticReferenceFact;
  lMethodSymbol: TSemanticSymbolFact;
  lMethodSymbolId: TSemanticSymbolId;
  lNameId: TSemanticStringId;
  lNoiseSymbol: TSemanticSymbolFact;
  lNoiseUnit: TUnitSnapshot;
  lOwnerId: TSemanticStringId;
  lPositionResult: TDelphiSemanticUsageResult;
  lProject: TDelphiProjectSnapshot;
  lReference: TSemanticReferenceFact;
  lResult: TDelphiSemanticUsageResult;
  lRoutineReference: TSemanticReferenceFact;
  lRoutineSymbol: TSemanticSymbolFact;
  lRoutineSymbolId: TSemanticSymbolId;
  lSecondResult: TDelphiSemanticUsageResult;
  lSectionKindId: TSemanticStringId;
  lSourceKindId: TSemanticStringId;
  lSymbol: TSemanticSymbolFact;
  lSymbolId: TSemanticSymbolId;
  lTouchNameId: TSemanticStringId;
  lUnit: TUnitSnapshot;
  lUnitNameId: TSemanticStringId;
  lUsage: TDelphiSemanticUsage;
  lFoundDeclaration: Boolean;
  lFoundReference: Boolean;
  lFoundAliasReference: Boolean;
  lFoundMethodDeclaration: Boolean;
  lFoundMethodReference: Boolean;
  lFoundRoutineDeclaration: Boolean;
  lFoundRoutineReference: Boolean;
begin
  lBuilder := TDelphiProjectSnapshotBuilder.Create;
  lProject := nil;
  try
    lFileNameId := lBuilder.Strings.Intern(FixturePath('SymbolQuery', 'SnapshotUsageUnit.pas'));
    lUnitNameId := lBuilder.Strings.Intern('SnapshotUsageUnit');
    lNameId := lBuilder.Strings.Intern('SnapshotUsageValue');
    lKindId := lBuilder.Strings.Intern('var');
    lOwnerId := lBuilder.Strings.Intern('TSnapshotUsage');
    lTouchNameId := lBuilder.Strings.Intern('Touch');
    lSectionKindId := lBuilder.Strings.Intern('interface');
    lSourceKindId := lBuilder.Strings.Intern('snapshot-source');

    lUnit := TUnitSnapshot.Create(1, lFileNameId, lUnitNameId);
    try
      lSymbol := Default(TSemanticSymbolFact);
      lSymbol.NameId := lNameId;
      lSymbol.KindId := lKindId;
      lSymbol.SectionKindId := lSectionKindId;
      lSymbol.SourceKindId := lSourceKindId;
      lSymbol.Line := 4;
      lSymbol.Column := 3;
      lSymbol.EndLine := 4;
      lSymbol.EndColumn := 20;
      lSymbolId := lUnit.AddSymbol(lSymbol);

      lAliasSymbol := Default(TSemanticSymbolFact);
      lAliasSymbol.NameId := lBuilder.Strings.Intern('SnapshotUsageAlias');
      lAliasSymbol.KindId := lBuilder.Strings.Intern('alias');
      lAliasSymbol.SectionKindId := lSectionKindId;
      lAliasSymbol.SourceKindId := lSourceKindId;
      lAliasSymbol.Line := 5;
      lAliasSymbol.Column := 3;
      lAliasSymbol.EndLine := 5;
      lAliasSymbol.EndColumn := 20;
      lAliasSymbolId := lUnit.AddSymbol(lAliasSymbol);

      lMethodSymbol := Default(TSemanticSymbolFact);
      lMethodSymbol.NameId := lTouchNameId;
      lMethodSymbol.OwnerTypeId := lOwnerId;
      lMethodSymbol.KindId := lBuilder.Strings.Intern('method');
      lMethodSymbol.SectionKindId := lSectionKindId;
      lMethodSymbol.SourceKindId := lSourceKindId;
      lMethodSymbol.Line := 6;
      lMethodSymbol.Column := 5;
      lMethodSymbol.EndLine := 6;
      lMethodSymbol.EndColumn := 9;
      lMethodSymbolId := lUnit.AddSymbol(lMethodSymbol);

      lRoutineSymbol := Default(TSemanticSymbolFact);
      lRoutineSymbol.NameId := lTouchNameId;
      lRoutineSymbol.OwnerTypeId := lOwnerId;
      lRoutineSymbol.KindId := lBuilder.Strings.Intern('routine');
      lRoutineSymbol.SectionKindId := lBuilder.Strings.Intern('implementation');
      lRoutineSymbol.SourceKindId := lSourceKindId;
      lRoutineSymbol.Line := 16;
      lRoutineSymbol.Column := 26;
      lRoutineSymbol.EndLine := 16;
      lRoutineSymbol.EndColumn := 30;
      lRoutineSymbolId := lUnit.AddSymbol(lRoutineSymbol);

      lReference := Default(TSemanticReferenceFact);
      lReference.NameId := lNameId;
      lReference.TargetUnitId := lUnit.UnitId;
      lReference.TargetSymbolId := lSymbolId;
      lReference.ClassificationId := lBuilder.Strings.Intern('read');
      lReference.SectionKindId := lBuilder.Strings.Intern('implementation');
      lReference.SourceKindId := lSourceKindId;
      lReference.Line := 12;
      lReference.Column := 5;
      lReference.EndLine := 12;
      lReference.EndColumn := 22;
      lUnit.AddReference(lReference);

      lAliasReference := Default(TSemanticReferenceFact);
      lAliasReference.NameId := lBuilder.Strings.Intern('SnapshotUsageAlias');
      lAliasReference.TargetUnitId := lUnit.UnitId;
      lAliasReference.TargetSymbolId := lAliasSymbolId;
      lAliasReference.ClassificationId := lBuilder.Strings.Intern('type-reference');
      lAliasReference.SectionKindId := lBuilder.Strings.Intern('implementation');
      lAliasReference.SourceKindId := lSourceKindId;
      lAliasReference.Line := 13;
      lAliasReference.Column := 5;
      lAliasReference.EndLine := 13;
      lAliasReference.EndColumn := 22;
      lUnit.AddReference(lAliasReference);

      lMethodReference := Default(TSemanticReferenceFact);
      lMethodReference.NameId := lTouchNameId;
      lMethodReference.TargetUnitId := lUnit.UnitId;
      lMethodReference.TargetSymbolId := lMethodSymbolId;
      lMethodReference.ClassificationId := lBuilder.Strings.Intern('method-reference');
      lMethodReference.SectionKindId := lSectionKindId;
      lMethodReference.SourceKindId := lSourceKindId;
      lMethodReference.Line := 14;
      lMethodReference.Column := 7;
      lMethodReference.EndLine := 14;
      lMethodReference.EndColumn := 11;
      lUnit.AddReference(lMethodReference);

      lRoutineReference := Default(TSemanticReferenceFact);
      lRoutineReference.NameId := lTouchNameId;
      lRoutineReference.TargetUnitId := lUnit.UnitId;
      lRoutineReference.TargetSymbolId := lRoutineSymbolId;
      lRoutineReference.ClassificationId := lBuilder.Strings.Intern('routine-reference');
      lRoutineReference.SectionKindId := lBuilder.Strings.Intern('implementation');
      lRoutineReference.SourceKindId := lSourceKindId;
      lRoutineReference.Line := 18;
      lRoutineReference.Column := 3;
      lRoutineReference.EndLine := 18;
      lRoutineReference.EndColumn := 7;
      lUnit.AddReference(lRoutineReference);

      lBuilder.AddUnit(lUnit);
      lUnit := nil;
    finally
      lUnit.Free;
    end;
    for i := 1 to 20 do
    begin
      lNoiseUnit := TUnitSnapshot.Create(TSemanticUnitId(100 + i),
        lBuilder.Strings.Intern(FixturePath('SymbolQuery', 'SnapshotUsageNoise' + IntToStr(i) + '.pas')),
        lBuilder.Strings.Intern('SnapshotUsageNoise' + IntToStr(i)));
      try
        lNoiseSymbol := Default(TSemanticSymbolFact);
      lNoiseSymbol.NameId := lTouchNameId;
        lNoiseSymbol.OwnerTypeId := lBuilder.Strings.Intern('TOther' + IntToStr(i));
        lNoiseSymbol.KindId := lBuilder.Strings.Intern('method');
        lNoiseSymbol.SectionKindId := lSectionKindId;
        lNoiseSymbol.SourceKindId := lSourceKindId;
        lNoiseSymbol.Line := 3;
        lNoiseSymbol.Column := 5;
        lNoiseUnit.AddSymbol(lNoiseSymbol);
        lBuilder.AddUnit(lNoiseUnit);
        lNoiseUnit := nil;
      finally
        lNoiseUnit.Free;
      end;
    end;
    lProject := lBuilder.Build;
  finally
    lBuilder.Free;
  end;

  try
    lContext := Default(TDelphiSemanticSymbolQueryContext);
    lContext.ProjectSnapshot := BorrowProjectSnapshot(lProject);

    lResult := TDelphiSemanticUsageFinder.FindUsagesByName(lContext, 'SnapshotUsageValue');
    lSecondResult := TDelphiSemanticUsageFinder.FindUsagesByName(lContext,
      'SnapshotUsageValue');
    lAliasResult := TDelphiSemanticUsageFinder.FindUsagesByName(lContext,
      'SnapshotUsageAlias');
    lPositionResult := TDelphiSemanticUsageFinder.FindUsagesAtPosition(lContext,
      FixturePath('SymbolQuery', 'SnapshotUsageUnit.pas'), 16, 28);

    Assert.AreEqual('resolved', lResult.Status);
    Assert.AreEqual('SnapshotUsageValue', lResult.Symbol.Name);
    Assert.AreEqual(0, lResult.IndexMetrics.BuildInvocationCount);
    Assert.AreEqual(0, lSecondResult.IndexMetrics.BuildInvocationCount);
    Assert.AreEqual('resolved', lAliasResult.Status);
    Assert.AreEqual('type-alias', lAliasResult.Symbol.Kind);
    Assert.AreEqual('resolved', lPositionResult.Status);

    Assert.IsTrue(lProject.TryFindUnitById(1, lEquivalentUnit));
    lEquivalentSymbol := lEquivalentUnit.SymbolById(lRoutineSymbolId);
    Assert.IsTrue(lProject.TryRoutineMethodEquivalents(lEquivalentSymbol, lLowIndex,
      lHighIndex));
    lEquivalentCount := 0;
    for i := lLowIndex to lHighIndex do
    begin
      lEquivalentRef := lProject.RoutineMethodEquivalentRefByIndex(i);
      Assert.AreEqual(1, Integer(lEquivalentRef.UnitId));
      Assert.IsTrue(lProject.TryFindUnitById(lEquivalentRef.UnitId, lEquivalentUnit));
      lEquivalentSymbol := lEquivalentUnit.SymbolById(lEquivalentRef.SymbolId);
      Assert.AreEqual(lOwnerId, lEquivalentSymbol.OwnerTypeId);
      Assert.AreEqual(lTouchNameId, lEquivalentSymbol.NameId);
      Inc(lEquivalentCount);
    end;
    Assert.AreEqual(2, lEquivalentCount);

    lFoundDeclaration := False;
    lFoundReference := False;
    lFoundAliasReference := False;
    for lUsage in lResult.Usages do
    begin
      if SameText(lUsage.Role, 'declaration') and SameText(lUsage.SourceKind,
        'snapshot-source') then
        lFoundDeclaration := True;
      if SameText(lUsage.Role, 'read') and SameText(lUsage.SourceKind, 'snapshot-source') then
        lFoundReference := True;
    end;

    Assert.IsTrue(lFoundDeclaration);
    Assert.IsTrue(lFoundReference);

    for lUsage in lAliasResult.Usages do
      if SameText(lUsage.Role, 'type-reference') and SameText(lUsage.SourceKind,
        'snapshot-source') then
        lFoundAliasReference := True;
    Assert.IsTrue(lFoundAliasReference);

    lFoundMethodDeclaration := False;
    lFoundRoutineDeclaration := False;
    lFoundMethodReference := False;
    lFoundRoutineReference := False;
    for lUsage in lPositionResult.Usages do
    begin
      if SameText(lUsage.Role, 'declaration') and (lUsage.Line = 6) then
        lFoundMethodDeclaration := True;
      if SameText(lUsage.Role, 'declaration') and (lUsage.Line = 16) then
        lFoundRoutineDeclaration := True;
      if SameText(lUsage.Role, 'method-reference') then
        lFoundMethodReference := True;
      if SameText(lUsage.Role, 'routine-reference') then
        lFoundRoutineReference := True;
    end;
    Assert.IsTrue(lFoundMethodDeclaration);
    Assert.IsTrue(lFoundRoutineDeclaration);
    Assert.IsTrue(lFoundMethodReference);
    Assert.IsTrue(lFoundRoutineReference);
  finally
    lProject.Free;
  end;
end;

procedure TUsageTests.BlocksAmbiguousUsageTargets;
var
  lAmbiguous: TDelphiSemanticUnitModel;
  lContext: TDelphiSemanticSymbolQueryContext;
  lResult: TDelphiSemanticUsageResult;
begin
  lContext := LoadContext;
  lAmbiguous := Default(TDelphiSemanticUnitModel);
  lAmbiguous.UnitName := 'AmbiguousUsageUnit';
  lAmbiguous.FileName := FixturePath('SymbolQuery', 'AmbiguousUsageUnit.pas');
  SetLength(lAmbiguous.Declarations, 1);
  lAmbiguous.Declarations[0].Name := 'GlobalQueryValue';
  lAmbiguous.Declarations[0].Kind := 'var';
  lAmbiguous.Declarations[0].SectionKind := 'interface';
  lAmbiguous.Declarations[0].Line := 3;
  lAmbiguous.Declarations[0].Column := 3;
  lContext.IndexedUnitModels := lContext.IndexedUnitModels + [lAmbiguous];
  lContext.IndexedUnitSourceKinds := lContext.IndexedUnitSourceKinds + ['project-source'];
  lContext.UnitModel.ImplementationUses := lContext.UnitModel.ImplementationUses +
    ['AmbiguousUsageUnit'];

  lResult := TDelphiSemanticUsageFinder.FindUsagesByName(lContext, 'GlobalQueryValue');

  Assert.AreEqual('ambiguous', lResult.Status);
  Assert.IsTrue(lResult.Diagnostic <> '');
  Assert.AreEqual(0, Integer(Length(lResult.Usages)));
end;

initialization
  TDUnitX.RegisterTestFixture(TUsageTests);

end.
