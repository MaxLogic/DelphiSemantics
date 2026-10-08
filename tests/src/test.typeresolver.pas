unit Test.TypeResolver;

interface

uses
  DUnitX.TestFramework,
  DelphiSemantics.Model, DelphiSemantics.ProjectContext,
  DelphiSemantics.Resolve.TypeResolver, DelphiSemantics.SemanticGraph;

type
  [TestFixture]
  TTypeResolverTests = class
  private
    function Graph: TDelphiSemanticSemanticGraph;
    function ProjectInfo: TDelphiSemanticProjectInfo;
    function UnitModel(const aUnitName: string): TDelphiSemanticUnitModel;
  public
    [Test]
    procedure ResolvesSimpleQualifiedAndVisibleTypeNames;
    [Test]
    procedure PreservesDeclaredCanonicalAndUnderlyingAliasIdentities;
    [Test]
    procedure ReportsAmbiguousSimpleNames;
    [Test]
    procedure FindsAncestorTypeChain;
    [Test]
    procedure ContextFreeLookupsExcludeRoutineLocalTypes;
    [Test]
    procedure ScopedLookupSelectsNearestDeclarationAndRefusesBrokenChains;
    [Test]
    procedure SourceBackedInterfaceBodyPairsPreserveScopedLocalIdentity;
    [Test]
    procedure OpenArrayAndGenericHeadersKeepAstSignatureEvidence;
    [Test]
    procedure HeaderBodyPairsIgnoreOnlyWhitespaceDifferences;
  end;

implementation

uses
  System.IOUtils, System.SysUtils,
  DelphiSemantics.Model.Extract, DelphiSemantics.Model.Json,
  Test.Support;

function TTypeResolverTests.Graph: TDelphiSemanticSemanticGraph;
begin
  Result := TDelphiSemanticSemanticGraphBuilder.Build(ProjectInfo, [UnitModel('TypeUnitA'),
    UnitModel('TypeUnitB'), UnitModel('TypeUnitC')]);
end;

function TTypeResolverTests.ProjectInfo: TDelphiSemanticProjectInfo;
begin
  Result := Default(TDelphiSemanticProjectInfo);
  Result.ProjectName := 'TypeResolverProject';
  Result.ContextFingerprint := 'type-resolver-context';
end;

function TTypeResolverTests.UnitModel(const aUnitName: string): TDelphiSemanticUnitModel;
begin
  Result := Default(TDelphiSemanticUnitModel);
  Result.Success := True;
  Result.UnitName := aUnitName;
  Result.FileName := aUnitName + '.pas';

  if aUnitName = 'TypeUnitA' then
  begin
    SetLength(Result.Declarations, 5);
    Result.Declarations[0].Name := 'TBase';
    Result.Declarations[0].Kind := 'type';
    Result.Declarations[0].TypeName := 'class';
    Result.Declarations[0].SectionKind := 'interface';
    Result.Declarations[0].Line := 4;
    Result.Declarations[0].Column := 3;
    Result.Declarations[1].Name := 'TChild';
    Result.Declarations[1].Kind := 'type';
    Result.Declarations[1].TypeName := 'class';
    Result.Declarations[1].BaseTypeName := 'TBase';
    Result.Declarations[1].SectionKind := 'interface';
    Result.Declarations[1].Line := 5;
    Result.Declarations[1].Column := 3;
    Result.Declarations[2].Name := 'TAlias';
    Result.Declarations[2].Kind := 'type-alias';
    Result.Declarations[2].TypeName := 'TChild';
    Result.Declarations[2].SectionKind := 'interface';
    Result.Declarations[2].Line := 6;
    Result.Declarations[2].Column := 3;
    Result.Declarations[3].Name := 'TShared';
    Result.Declarations[3].Kind := 'type';
    Result.Declarations[3].TypeName := 'record';
    Result.Declarations[3].SectionKind := 'interface';
    Result.Declarations[3].Line := 7;
    Result.Declarations[3].Column := 3;
    Result.Declarations[4].Name := 'TImplOnly';
    Result.Declarations[4].Kind := 'type';
    Result.Declarations[4].TypeName := 'record';
    Result.Declarations[4].SectionKind := 'implementation';
    Result.Declarations[4].Line := 20;
    Result.Declarations[4].Column := 3;
  end else if aUnitName = 'TypeUnitB' then
  begin
    SetLength(Result.Declarations, 1);
    Result.Declarations[0].Name := 'TShared';
    Result.Declarations[0].Kind := 'type';
    Result.Declarations[0].TypeName := 'record';
    Result.Declarations[0].SectionKind := 'interface';
    Result.Declarations[0].Line := 4;
    Result.Declarations[0].Column := 3;
  end else
  begin
    SetLength(Result.Declarations, 2);
    Result.Declarations[0].Name := 'TExternalOnly';
    Result.Declarations[0].Kind := 'type';
    Result.Declarations[0].TypeName := 'record';
    Result.Declarations[0].SectionKind := 'interface';
    Result.Declarations[0].Line := 4;
    Result.Declarations[0].Column := 3;
    Result.Declarations[1].Name := 'TQualifiedAlias';
    Result.Declarations[1].Kind := 'type-alias';
    Result.Declarations[1].TypeName := 'TypeUnitA.TChild';
    Result.Declarations[1].SectionKind := 'interface';
    Result.Declarations[1].Line := 5;
    Result.Declarations[1].Column := 3;
  end;
end;

procedure TTypeResolverTests.FindsAncestorTypeChain;
var
  lAncestors: TArray<TDelphiSemanticTypeIdentity>;
  lGraph: TDelphiSemanticSemanticGraph;
  lIndex: TDelphiSemanticTypeIdentityIndex;
  lResult: TDelphiSemanticTypeLookupResult;
begin
  lGraph := Graph;
  try
    lIndex := TDelphiSemanticTypeResolver.BuildIndex(lGraph);
    lResult := lIndex.ResolveQualifiedName('TypeUnitA.TChild');
    Assert.IsTrue(lResult.Found, lResult.Reason);

    lAncestors := lIndex.FindAncestors(lResult.Identity);

    Assert.AreEqual(1, Integer(Length(lAncestors)));
    Assert.AreEqual('TBase', lAncestors[0].Name);

    lResult := lIndex.ResolveQualifiedName('TypeUnitC.TQualifiedAlias');
    Assert.IsTrue(lResult.Found, lResult.Reason);
    lAncestors := lIndex.FindAncestors(lResult.Identity);

    Assert.AreEqual(2, Integer(Length(lAncestors)));
    Assert.AreEqual('TChild', lAncestors[0].Name);
    Assert.AreEqual('TBase', lAncestors[1].Name);
  finally
    lGraph.Free;
  end;
end;

procedure TTypeResolverTests.ContextFreeLookupsExcludeRoutineLocalTypes;
var
  lGraph: TDelphiSemanticSemanticGraph;
  lIdentity: TDelphiSemanticTypeIdentity;
  lIndex: TDelphiSemanticTypeIdentityIndex;
  lModel: TDelphiSemanticUnitModel;
  lResult: TDelphiSemanticTypeLookupResult;
  lTypes: TArray<TDelphiSemanticGraphType>;
begin
  // This isolates legacy lookup behavior from the separate source extraction control.
  lModel := UnitModel('TypeUnitA');
  SetLength(lModel.Declarations, 6);
  lModel.Declarations[5].Name := 'TLocal';
  lModel.Declarations[5].Kind := 'type';
  lModel.Declarations[5].TypeName := 'record';
  lModel.Declarations[5].SectionKind := 'implementation';
  lModel.Declarations[5].ScopeKind := 'routine';
  lModel.Declarations[5].OwnerScopeId := 'typeunita|run()';
  lModel.Declarations[5].SymbolId := 'typeunita|run()|type|tlocal';
  lModel.Declarations[5].Line := 31;
  lModel.Declarations[5].Column := 3;
  lGraph := TDelphiSemanticSemanticGraphBuilder.Build(ProjectInfo, [lModel]);
  try
    lTypes := lGraph.Types;
    Assert.AreEqual(6, Integer(Length(lTypes)));
    lIndex := TDelphiSemanticTypeResolver.BuildIndex(lGraph);
    Assert.IsTrue(lIndex.FindByDeclaredId(lTypes[5].DeclaredId, lIdentity),
      'An exact local ID stays addressable to contextual consumers.');
    Assert.AreEqual('TLocal', lIdentity.Name);
    lResult := lIndex.ResolveSimpleName('TLocal');
    Assert.IsFalse(lResult.Found, 'Unit-level simple lookup must exclude locals.');
    lResult := lIndex.ResolveQualifiedName('TypeUnitA.TLocal');
    Assert.IsFalse(lResult.Found, 'Qualified unit lookup must exclude locals.');
    lResult := lIndex.ResolveVisibleName('TLocal', 'TypeUnitA', [], 'implementation');
    Assert.IsFalse(lResult.Found, 'Unit-visible lookup must exclude locals.');
  finally
    lGraph.Free;
  end;
end;

procedure TTypeResolverTests.SourceBackedInterfaceBodyPairsPreserveScopedLocalIdentity;
const
  cMalformedSignatures: array[0..2] of string = (
    '(aValue: string)',
    '(aValue: Integer; aOther: Integer)',
    '(var aValue: Integer)');
var
  lBodyCount: Integer;
  lDeclaration: TDelphiSemanticDeclaration;
  lGuid: TGUID;
  lGraph: TDelphiSemanticSemanticGraph;
  lGraphPairCount: Integer;
  lGraphRoutine: TDelphiSemanticGraphRoutine;
  lHeaderCount: Integer;
  lIndex: TDelphiSemanticTypeIdentityIndex;
  lInner: TDelphiSemanticRoutine;
  lInvalidGraph: TDelphiSemanticSemanticGraph;
  lInvalidIndex: TDelphiSemanticTypeIdentityIndex;
  lInvalidPairCount: Integer;
  lMalformedModel: TDelphiSemanticUnitModel;
  lMalformedSignature: string;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lOuterDeclaration: TDelphiSemanticDeclaration;
  lPath: string;
  lResult: TDelphiSemanticTypeLookupResult;
  lRoutine: TDelphiSemanticRoutine;
  lRunLocalBody, lRunLocalHeader: TDelphiSemanticRoutine;
  lRunNestedBody, lRunNestedHeader: TDelphiSemanticRoutine;
  lSource: string;
  lTypeCount: Integer;
begin
  CreateGUID(lGuid);
  lPath := TPath.Combine(RepoRoot, 'tests\.dak\delphiSemanticsTests\type-resolver-scope-pair\' +
    GUIDToString(lGuid) + '\ScopedPairUnit.pas');
  TDirectory.CreateDirectory(ExtractFilePath(lPath));
  lSource := 'unit ScopedPairUnit;'#13#10 + // 1
    'interface'#13#10 + // 2
    'procedure RunLocal(aValue: Integer);'#13#10 + // 3
    'procedure RunNested(aValue: Integer);'#13#10 + // 4
    'implementation'#13#10 + // 5
    'procedure RunLocal(aValue: Integer);'#13#10 + // 6
    'type TLocal = record LocalOnly: Integer; end;'#13#10 + // 7
    'begin end;'#13#10 + // 8
    'procedure RunNested(aValue: Integer);'#13#10 + // 9
    'type TOuter = record OuterOnly: Integer; end;'#13#10 + // 10
    '  procedure Inner;'#13#10 + // 11
    '  begin end;'#13#10 + // 12
    'begin Inner; end;'#13#10 + // 13
    'end.'#13#10; // 14
  TFile.WriteAllText(lPath, lSource, TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lPath;
  lOptions.ProjectContextApplied := True;
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);
  Assert.AreEqual('ast', lModel.ScopeModelStatus);
  lModel := JsonToModel(ModelToJson(lModel));

  lBodyCount := 0;
  lHeaderCount := 0;
  lInner := Default(TDelphiSemanticRoutine);
  lRunLocalBody := Default(TDelphiSemanticRoutine);
  lRunLocalHeader := Default(TDelphiSemanticRoutine);
  lRunNestedBody := Default(TDelphiSemanticRoutine);
  lRunNestedHeader := Default(TDelphiSemanticRoutine);
  for lRoutine in lModel.Routines do
    if SameText(lRoutine.Name, 'RunLocal') or SameText(lRoutine.Name, 'RunNested') then
    begin
      Assert.IsNotEmpty(lRoutine.ScopeId, 'Both declarations need an AST scope.');
      if SameText(lRoutine.SectionKind, 'interface') then
      begin
        Inc(lHeaderCount);
        if SameText(lRoutine.Name, 'RunLocal') then
          lRunLocalHeader := lRoutine
        else
          lRunNestedHeader := lRoutine;
      end else if SameText(lRoutine.SectionKind, 'implementation') then
      begin
        Inc(lBodyCount);
        if SameText(lRoutine.Name, 'RunLocal') then
          lRunLocalBody := lRoutine
        else
          lRunNestedBody := lRoutine;
      end;
    end else if SameText(lRoutine.Name, 'Inner') then
      lInner := lRoutine;
  Assert.AreEqual(2, lHeaderCount);
  Assert.AreEqual(2, lBodyCount);
  Assert.AreEqual(3, lRunLocalHeader.Line);
  Assert.AreEqual(6, lRunLocalBody.Line);
  Assert.AreEqual(4, lRunNestedHeader.Line);
  Assert.AreEqual(9, lRunNestedBody.Line);
  Assert.AreEqual(lRunLocalHeader.Name, lRunLocalBody.Name);
  Assert.AreEqual(lRunNestedHeader.Name, lRunNestedBody.Name);
  Assert.AreEqual(lRunLocalHeader.Signature, lRunLocalBody.Signature);
  Assert.AreEqual(lRunNestedHeader.Signature, lRunNestedBody.Signature);
  Assert.IsNotEmpty(lRunNestedHeader.Signature);
  Assert.AreEqual(lRunLocalHeader.ScopeId, lRunLocalBody.ScopeId);
  Assert.AreEqual(lRunNestedHeader.ScopeId, lRunNestedBody.ScopeId);
  Assert.AreEqual(lRunLocalHeader.ParentScopeId, lRunLocalBody.ParentScopeId);
  Assert.AreEqual(lRunNestedHeader.ParentScopeId, lRunNestedBody.ParentScopeId);
  Assert.AreEqual('header', lRunLocalHeader.AstScopeKind);
  Assert.AreEqual('body', lRunLocalBody.AstScopeKind);
  Assert.AreEqual('header', lRunNestedHeader.AstScopeKind);
  Assert.AreEqual('body', lRunNestedBody.AstScopeKind);
  Assert.AreEqual('(integer)', lRunNestedHeader.AstSemanticSignature);
  Assert.AreEqual(lRunNestedHeader.AstSemanticSignature,
    lRunNestedBody.AstSemanticSignature);
  Assert.AreEqual(lRunNestedHeader.Signature,
    lRunNestedHeader.AstSourceSignature);
  Assert.AreEqual(lRunNestedBody.Signature,
    lRunNestedBody.AstSourceSignature);
  Assert.IsTrue(lRunNestedHeader.AstSourceSignatureVerified);
  Assert.IsTrue(lRunNestedBody.AstSourceSignatureVerified);
  Assert.AreNotEqual(lRunLocalBody.ScopeId, lRunNestedBody.ScopeId);
  Assert.AreEqual(11, lInner.Line);
  Assert.AreEqual(lRunNestedBody.ScopeId, lInner.ParentScopeId);

  lOuterDeclaration := Default(TDelphiSemanticDeclaration);
  lTypeCount := 0;
  for lDeclaration in lModel.Declarations do
    if SameText(lDeclaration.Name, 'TOuter') and SameText(lDeclaration.Kind, 'type') and
      SameText(lDeclaration.ScopeKind, 'routine') then
    begin
      Inc(lTypeCount);
      lOuterDeclaration := lDeclaration;
    end;
  Assert.AreEqual(1, lTypeCount, 'The source-backed local record must be present.');
  Assert.AreEqual(lRunNestedBody.ScopeId, lOuterDeclaration.OwnerScopeId);
  Assert.IsNotEmpty(lOuterDeclaration.SymbolId);
  Assert.AreEqual(10, lOuterDeclaration.Line);

  // A second implementation body is malformed even when its scope ID matches the real body.
  lMalformedModel := lModel;
  lMalformedModel.Routines := Copy(lModel.Routines);
  SetLength(lMalformedModel.Routines, Length(lMalformedModel.Routines) + 1);
  lMalformedModel.Routines[High(lMalformedModel.Routines)] := lRunNestedBody;
  lInvalidGraph := TDelphiSemanticSemanticGraphBuilder.Build(ProjectInfo, [lMalformedModel]);
  try
    lInvalidPairCount := 0;
    for lGraphRoutine in lInvalidGraph.Routines do
      if SameText(lGraphRoutine.Name, 'RunNested') and
        SameText(lGraphRoutine.ScopeId, lRunNestedBody.ScopeId) then
        Inc(lInvalidPairCount);
    Assert.AreEqual(3, lInvalidPairCount, 'The malformed graph must retain both bodies.');
    lInvalidIndex := TDelphiSemanticTypeResolver.BuildIndex(lInvalidGraph);
    lResult := lInvalidIndex.ResolveScopedName('TOuter', lModel.UnitName, lInner.ScopeId,
      [], 'implementation');
    Assert.IsFalse(lResult.Found, 'A duplicate body cannot establish routine ownership.');
    Assert.AreEqual('CALLER_SCOPE_INVALID', lResult.ReasonCode);
  finally
    lInvalidGraph.Free;
  end;

  // Old model JSON has no AST pair evidence. It must not make a body caller valid.
  lMalformedModel := lModel;
  lMalformedModel.Routines := Copy(lModel.Routines);
  for lBodyCount := 0 to High(lMalformedModel.Routines) do
    if SameText(lMalformedModel.Routines[lBodyCount].Name, 'RunNested') and
      SameText(lMalformedModel.Routines[lBodyCount].SectionKind, 'implementation') then
      lMalformedModel.Routines[lBodyCount].AstScopeKind := '';
  lMalformedModel := JsonToModel(ModelToJson(lMalformedModel));
  lInvalidGraph := TDelphiSemanticSemanticGraphBuilder.Build(ProjectInfo, [lMalformedModel]);
  try
    lInvalidIndex := TDelphiSemanticTypeResolver.BuildIndex(lInvalidGraph);
    lResult := lInvalidIndex.ResolveScopedName('TOuter', lModel.UnitName, lInner.ScopeId,
      [], 'implementation');
    Assert.IsFalse(lResult.Found, 'Missing AST pair evidence cannot establish ownership.');
    Assert.AreEqual('CALLER_SCOPE_INVALID', lResult.ReasonCode);
  finally
    lInvalidGraph.Free;
  end;

  lGraph := TDelphiSemanticSemanticGraphBuilder.Build(ProjectInfo, [lModel]);
  try
    lGraphPairCount := 0;
    for lGraphRoutine in lGraph.Routines do
      if SameText(lGraphRoutine.Name, 'RunNested') and
        SameText(lGraphRoutine.ScopeId, lRunNestedBody.ScopeId) then
      begin
        Inc(lGraphPairCount);
        Assert.AreEqual(lPath, lGraphRoutine.SourceRange.FileName);
        Assert.IsTrue((lGraphRoutine.SourceRange.Line = 4) or
          (lGraphRoutine.SourceRange.Line = 9));
      end;
    Assert.AreEqual(2, lGraphPairCount, 'Graph lookup must retain the header and body.');
    lIndex := TDelphiSemanticTypeResolver.BuildIndex(lGraph);
    lResult := lIndex.ResolveScopedName('TOuter', lModel.UnitName, lInner.ScopeId,
      [], 'implementation');
    Assert.IsTrue(lResult.Found, lResult.ReasonCode + ': ' + lResult.Reason);
    Assert.AreEqual('routine', lResult.Identity.ScopeKind);
    Assert.AreEqual(lRunNestedBody.ScopeId, lResult.Identity.OwnerScopeId);
    Assert.AreEqual(lOuterDeclaration.SymbolId, lResult.Identity.SemanticSymbolId);
    Assert.AreEqual(lPath, lResult.Identity.SourceRange.FileName);
    lResult := lIndex.ResolveScopedName('TLocal', lModel.UnitName, lRunLocalBody.ScopeId,
      [], 'implementation');
    Assert.IsTrue(lResult.Found, lResult.ReasonCode + ': ' + lResult.Reason);
    Assert.AreEqual(lRunLocalBody.ScopeId, lResult.Identity.OwnerScopeId);
  finally
    lGraph.Free;
  end;

  // A persisted lexical header cannot replace the AST parameter contract.
  for lMalformedSignature in cMalformedSignatures do
  begin
    lMalformedModel := lModel;
    lMalformedModel.Routines := Copy(lModel.Routines);
    for lBodyCount := 0 to High(lMalformedModel.Routines) do
      if SameText(lMalformedModel.Routines[lBodyCount].Name, 'RunNested') then
        lMalformedModel.Routines[lBodyCount].Signature := lMalformedSignature;
    lMalformedModel := JsonToModel(ModelToJson(lMalformedModel));
    lInvalidGraph := TDelphiSemanticSemanticGraphBuilder.Build(ProjectInfo, [lMalformedModel]);
    try
      lInvalidIndex := TDelphiSemanticTypeResolver.BuildIndex(lInvalidGraph);
      lResult := lInvalidIndex.ResolveScopedName('TOuter', lModel.UnitName, lInner.ScopeId,
        [], 'implementation');
      Assert.IsFalse(lResult.Found,
        'Conflicting lexical and AST signatures cannot establish routine ownership: ' +
        lMalformedSignature);
      Assert.AreEqual('CALLER_SCOPE_INVALID', lResult.ReasonCode);
    finally
      lInvalidGraph.Free;
    end;
  end;

  // Missing or internally inconsistent AST evidence must also refuse old JSON rows.
  for lBodyCount := 0 to 2 do
  begin
    lMalformedModel := lModel;
    lMalformedModel.Routines := Copy(lModel.Routines);
    for lHeaderCount := 0 to High(lMalformedModel.Routines) do
      if SameText(lMalformedModel.Routines[lHeaderCount].Name, 'RunNested') then
        case lBodyCount of
          0: lMalformedModel.Routines[lHeaderCount].AstSemanticSignature := '';
          1: lMalformedModel.Routines[lHeaderCount].AstSourceSignatureVerified := False;
          2: lMalformedModel.Routines[lHeaderCount].AstSourceSignature :=
            '(aValue: string)';
        end;
    lMalformedModel := JsonToModel(ModelToJson(lMalformedModel));
    lInvalidGraph := TDelphiSemanticSemanticGraphBuilder.Build(ProjectInfo, [lMalformedModel]);
    try
      lInvalidIndex := TDelphiSemanticTypeResolver.BuildIndex(lInvalidGraph);
      lResult := lInvalidIndex.ResolveScopedName('TOuter', lModel.UnitName,
        lInner.ScopeId, [], 'implementation');
      Assert.IsFalse(lResult.Found, 'Incomplete AST signature proof cannot establish ownership.');
      Assert.AreEqual('CALLER_SCOPE_INVALID', lResult.ReasonCode);
    finally
      lInvalidGraph.Free;
    end;
  end;
end;

procedure TTypeResolverTests.HeaderBodyPairsIgnoreOnlyWhitespaceDifferences;
const
  // Each pair is (header, body) source text; only the first one differs by whitespace.
  cMismatches: array[0..3, 0..1] of string = (
    ('(aValue: Integer; aOther: Integer)', '(aValue: Integer; aOth er: Integer)'),
    ('(aValue: Integer; aOther: Integer)', '(aValue: Integer; aOther2: Integer)'),
    ('(aValue: Integer; aOther: Integer)', '(var aValue: Integer; aOther: Integer)'),
    ('(aValue: Integer; aOther: Integer)', '(aValue: Integer; aOther: Integer = 0)'));
var
  i: Integer;
  j: Integer;
  lGraph: TDelphiSemanticSemanticGraph;
  lIndex: TDelphiSemanticTypeIdentityIndex;
  lInner: TDelphiSemanticRoutine;
  lInvalidModel: TDelphiSemanticUnitModel;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lPath: string;
  lResult: TDelphiSemanticTypeLookupResult;
  lRoutine: TDelphiSemanticRoutine;
  lRunBody: TDelphiSemanticRoutine;
  lRunHeader: TDelphiSemanticRoutine;
  lSignature: string;
begin
  lPath := TPath.Combine(RepoRoot, 'tests\.dak\delphiSemanticsTests\type-resolver-scope-pair\' +
    TPath.GetGUIDFileName + '\SpacedPairUnit.pas');
  TDirectory.CreateDirectory(ExtractFilePath(lPath));
  // Like maxTdb DBF2DAT and AppendLokalParameter: the body splits and spaces the
  // header's parameter list differently.
  TFile.WriteAllText(lPath,
    'unit SpacedPairUnit;'#13#10 +
    'interface'#13#10 +
    'function RunNested(aValue: Integer;aOther : Integer ):Integer;'#13#10 +
    'implementation'#13#10 +
    'function RunNested(aValue: Integer;'#13#10 +
    '  aOther: Integer): Integer;'#13#10 +
    'type TOuter = record OuterOnly: Integer; end;'#13#10 +
    '  procedure Inner;'#13#10 +
    '  begin end;'#13#10 +
    'begin Inner; Result := 0; end;'#13#10 +
    'end.'#13#10, TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lPath;
  lOptions.ProjectContextApplied := True;
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);
  Assert.AreEqual('ast', lModel.ScopeModelStatus);
  lModel := JsonToModel(ModelToJson(lModel));
  lInner := Default(TDelphiSemanticRoutine);
  lRunBody := Default(TDelphiSemanticRoutine);
  lRunHeader := Default(TDelphiSemanticRoutine);
  for lRoutine in lModel.Routines do
    if SameText(lRoutine.Name, 'RunNested') and SameText(lRoutine.SectionKind, 'interface') then
      lRunHeader := lRoutine
    else if SameText(lRoutine.Name, 'RunNested') then
      lRunBody := lRoutine
    else if SameText(lRoutine.Name, 'Inner') then
      lInner := lRoutine;
  Assert.IsTrue(lRunHeader.AstSourceSignatureVerified and lRunBody.AstSourceSignatureVerified);
  Assert.AreNotEqual(lRunHeader.AstSourceSignature, lRunBody.AstSourceSignature,
    'The fixture must keep a whitespace-only difference.');
  Assert.AreEqual(lRunHeader.ScopeId, lRunBody.ScopeId);
  Assert.AreEqual(lRunBody.ScopeId, lInner.ParentScopeId);

  lGraph := TDelphiSemanticSemanticGraphBuilder.Build(ProjectInfo, [lModel]);
  try
    lIndex := TDelphiSemanticTypeResolver.BuildIndex(lGraph);
    lResult := lIndex.ResolveScopedName('TOuter', lModel.UnitName, lInner.ScopeId,
      [], 'implementation');
    Assert.IsTrue(lResult.Found, lResult.ReasonCode + ': ' + lResult.Reason);
    Assert.AreEqual('routine', lResult.Identity.ScopeKind);
    Assert.AreEqual(lRunBody.ScopeId, lResult.Identity.OwnerScopeId);
  finally
    lGraph.Free;
  end;

  // A real difference in names, spelling, modifiers or defaults keeps the scope invalid.
  for i := Low(cMismatches) to High(cMismatches) do
  begin
    lInvalidModel := lModel;
    lInvalidModel.Routines := Copy(lModel.Routines);
    for j := 0 to High(lInvalidModel.Routines) do
      if SameText(lInvalidModel.Routines[j].Name, 'RunNested') then
      begin
        if SameText(lInvalidModel.Routines[j].SectionKind, 'interface') then
          lSignature := cMismatches[i, 0]
        else
          lSignature := cMismatches[i, 1];
        lInvalidModel.Routines[j].Signature := lSignature;
        lInvalidModel.Routines[j].AstSourceSignature := lSignature;
      end;
    lInvalidModel := JsonToModel(ModelToJson(lInvalidModel));
    lGraph := TDelphiSemanticSemanticGraphBuilder.Build(ProjectInfo, [lInvalidModel]);
    try
      lIndex := TDelphiSemanticTypeResolver.BuildIndex(lGraph);
      lResult := lIndex.ResolveScopedName('TOuter', lModel.UnitName, lInner.ScopeId,
        [], 'implementation');
      Assert.IsFalse(lResult.Found, 'A real signature mismatch must stay invalid: ' +
        cMismatches[i, 1]);
      Assert.AreEqual('CALLER_SCOPE_INVALID', lResult.ReasonCode);
    finally
      lGraph.Free;
    end;
  end;
end;

procedure TTypeResolverTests.OpenArrayAndGenericHeadersKeepAstSignatureEvidence;
var
  lBody: TDelphiSemanticRoutine;
  lGenericBody: TDelphiSemanticRoutine;
  lGenericHeader: TDelphiSemanticRoutine;
  lGraph: TDelphiSemanticSemanticGraph;
  lGuid: TGUID;
  lIndex: TDelphiSemanticTypeIdentityIndex;
  lModel: TDelphiSemanticUnitModel;
  lOpenBody: TDelphiSemanticRoutine;
  lOpenHeader: TDelphiSemanticRoutine;
  lOptions: TDelphiSemanticModelOptions;
  lPath: string;
  lResult: TDelphiSemanticTypeLookupResult;
  lRoutine: TDelphiSemanticRoutine;
  lSource: string;
begin
  CreateGUID(lGuid);
  lPath := TPath.Combine(RepoRoot, 'tests\.dak\delphiSemanticsTests\type-resolver-scope-pair\' +
    GUIDToString(lGuid) + '\SignatureShapes.pas');
  TDirectory.CreateDirectory(ExtractFilePath(lPath));
  lSource := 'unit SignatureShapes;'#13#10 +
    'interface'#13#10 +
    'procedure OpenCase(aValues: array of Integer);'#13#10 +
    'procedure GenericCase(aValues: TArray<Integer>);'#13#10 +
    'implementation'#13#10 +
    'procedure OpenCase(aValues: array of Integer);'#13#10 +
    'type TOpenLocal = record Value: Integer; end;'#13#10 +
    'begin end;'#13#10 +
    'procedure GenericCase(aValues: TArray<Integer>);'#13#10 +
    'type TGenericLocal = record Value: Integer; end;'#13#10 +
    'begin end;'#13#10 +
    'end.'#13#10;
  TFile.WriteAllText(lPath, lSource, TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lPath;
  lOptions.ProjectContextApplied := True;
  lModel := JsonToModel(ModelToJson(
    TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions)));
  Assert.IsTrue(lModel.Success);
  Assert.AreEqual('ast', lModel.ScopeModelStatus);
  lOpenHeader := Default(TDelphiSemanticRoutine);
  lOpenBody := Default(TDelphiSemanticRoutine);
  lGenericHeader := Default(TDelphiSemanticRoutine);
  lGenericBody := Default(TDelphiSemanticRoutine);
  for lRoutine in lModel.Routines do
    if SameText(lRoutine.Name, 'OpenCase') then
    begin
      if SameText(lRoutine.SectionKind, 'interface') then
        lOpenHeader := lRoutine
      else if SameText(lRoutine.SectionKind, 'implementation') then
        lOpenBody := lRoutine;
    end else if SameText(lRoutine.Name, 'GenericCase') then
    begin
      if SameText(lRoutine.SectionKind, 'interface') then
        lGenericHeader := lRoutine
      else if SameText(lRoutine.SectionKind, 'implementation') then
        lGenericBody := lRoutine;
    end;
  Assert.IsTrue(TDelphiSemanticTypeResolver.VerifiedRoutineBody(lModel,
    lOpenHeader, lOpenBody, lBody), 'Open-array pair needs complete AST evidence.');
  Assert.AreEqual(lOpenBody.ScopeId, lBody.ScopeId);
  Assert.IsTrue(TDelphiSemanticTypeResolver.VerifiedRoutineBody(lModel,
    lGenericHeader, lGenericBody, lBody), 'Generic pair needs complete AST evidence.');
  Assert.AreEqual(lGenericBody.ScopeId, lBody.ScopeId);
  Assert.IsTrue(Pos('integer', lOpenBody.AstSemanticSignature) > 0);
  Assert.IsTrue(Pos('integer', lGenericBody.AstSemanticSignature) > 0);
  lGraph := TDelphiSemanticSemanticGraphBuilder.Build(ProjectInfo, [lModel]);
  try
    lIndex := TDelphiSemanticTypeResolver.BuildIndex(lGraph);
    lResult := lIndex.ResolveScopedName('TOpenLocal', lModel.UnitName,
      lOpenBody.ScopeId, [], 'implementation');
    Assert.IsTrue(lResult.Found, lResult.ReasonCode + ': ' + lResult.Reason);
    Assert.AreEqual(lOpenBody.ScopeId, lResult.Identity.OwnerScopeId);
    lResult := lIndex.ResolveScopedName('TGenericLocal', lModel.UnitName,
      lGenericBody.ScopeId, [], 'implementation');
    Assert.IsTrue(lResult.Found, lResult.ReasonCode + ': ' + lResult.Reason);
    Assert.AreEqual(lGenericBody.ScopeId, lResult.Identity.OwnerScopeId);
  finally
    lGraph.Free;
  end;
end;

procedure TTypeResolverTests.ScopedLookupSelectsNearestDeclarationAndRefusesBrokenChains;
var
  lGraph: TDelphiSemanticSemanticGraph;
  lIndex: TDelphiSemanticTypeIdentityIndex;
  lModel: TDelphiSemanticUnitModel;
  lOuter: TDelphiSemanticTypeLookupResult;
  lInner: TDelphiSemanticTypeLookupResult;
  lInnerPointer: TDelphiSemanticTypeLookupResult;
  lResult: TDelphiSemanticTypeLookupResult;
begin
  lModel := Default(TDelphiSemanticUnitModel);
  lModel.Success := True;
  lModel.UnitName := 'ScopedUnit';
  lModel.FileName := 'ScopedUnit.pas';
  lModel.ScopeModelStatus := 'ast';
  SetLength(lModel.Routines, 4);
  lModel.Routines[0].Name := 'Outer';
  lModel.Routines[0].ScopeId := 'outer';
  lModel.Routines[0].Line := 10;
  lModel.Routines[0].EndLine := 28;
  lModel.Routines[0].Column := 1;
  lModel.Routines[1].Name := 'Inner';
  lModel.Routines[1].ScopeId := 'inner';
  lModel.Routines[1].ParentScopeId := 'outer';
  lModel.Routines[1].Line := 20;
  lModel.Routines[1].EndLine := 25;
  lModel.Routines[1].Column := 3;
  lModel.Routines[2].Name := 'Broken';
  lModel.Routines[2].ScopeId := 'broken';
  lModel.Routines[2].ParentScopeId := 'missing';
  lModel.Routines[2].Line := 30;
  lModel.Routines[2].EndLine := 33;
  lModel.Routines[2].Column := 1;
  lModel.Routines[3].Name := 'Cycle';
  lModel.Routines[3].ScopeId := 'cycle';
  lModel.Routines[3].ParentScopeId := 'cycle';
  lModel.Routines[3].Line := 35;
  lModel.Routines[3].EndLine := 39;
  lModel.Routines[3].Column := 1;
  SetLength(lModel.Declarations, 8);
  lModel.Declarations[0].Name := 'TItem';
  lModel.Declarations[0].Kind := 'type';
  lModel.Declarations[0].TypeName := 'record';
  lModel.Declarations[0].SectionKind := 'implementation';
  lModel.Declarations[0].ScopeKind := 'unit';
  lModel.Declarations[0].Line := 3;
  lModel.Declarations[0].Column := 3;
  lModel.Declarations[1] := lModel.Declarations[0];
  lModel.Declarations[1].ScopeKind := 'routine';
  lModel.Declarations[1].OwnerScopeId := 'outer';
  lModel.Declarations[1].SymbolId := 'outer|type|titem';
  lModel.Declarations[1].Line := 12;
  lModel.Declarations[2] := lModel.Declarations[1];
  lModel.Declarations[2].OwnerScopeId := 'inner';
  lModel.Declarations[2].SymbolId := 'inner|type|titem';
  lModel.Declarations[2].Line := 22;
  lModel.Declarations[3] := lModel.Declarations[1];
  lModel.Declarations[3].Name := 'TPtr';
  lModel.Declarations[3].Kind := 'type-alias';
  lModel.Declarations[3].TypeName := '^TItem';
  lModel.Declarations[3].SymbolId := 'outer|type-alias|tptr';
  lModel.Declarations[3].Line := 13;
  lModel.Declarations[4] := lModel.Declarations[3];
  lModel.Declarations[4].Name := 'TAlias';
  lModel.Declarations[4].TypeName := 'TItem';
  lModel.Declarations[4].SymbolId := 'outer|type-alias|talias';
  lModel.Declarations[4].Line := 14;
  lModel.Declarations[5] := lModel.Declarations[3];
  lModel.Declarations[5].OwnerScopeId := 'inner';
  lModel.Declarations[5].SymbolId := 'inner|type-alias|tptr';
  lModel.Declarations[5].Line := 23;
  lModel.Declarations[6] := lModel.Declarations[2];
  lModel.Declarations[6].Name := 'TUnsupported';
  lModel.Declarations[6].Kind := 'unsupported-local-type';
  lModel.Declarations[6].SymbolId := 'inner|unsupported|tunsupported';
  lModel.Declarations[6].Line := 24;
  lModel.Declarations[7] := lModel.Declarations[1];
  lModel.Declarations[7].OwnerScopeId := 'broken';
  lModel.Declarations[7].SymbolId := 'broken|type|titem';
  lModel.Declarations[7].Line := 32;
  lGraph := TDelphiSemanticSemanticGraphBuilder.Build(ProjectInfo, [lModel]);
  try
    lIndex := TDelphiSemanticTypeResolver.BuildIndex(lGraph);
    lInner := lIndex.ResolveScopedName('TItem', 'ScopedUnit', 'inner', [],
      'implementation');
    Assert.IsTrue(lInner.Found, lInner.Reason);
    Assert.AreEqual('inner', lInner.Identity.OwnerScopeId);
    lOuter := lIndex.ResolveScopedName('TItem', 'ScopedUnit', 'outer', [],
      'implementation');
    Assert.IsTrue(lOuter.Found, lOuter.Reason);
    Assert.AreEqual('outer', lOuter.Identity.OwnerScopeId);
    lResult := lIndex.ResolveScopedName('TAlias', 'ScopedUnit', 'inner', [],
      'implementation');
    Assert.IsTrue(lResult.Found, lResult.Reason);
    Assert.AreEqual(lOuter.Identity.CanonicalId.Value,
      lResult.Identity.CanonicalId.Value,
      'An alias resolves its target at its declaration, not at the caller.');
    Assert.AreNotEqual(lInner.Identity.CanonicalId.Value,
      lResult.Identity.CanonicalId.Value);
    lInnerPointer := lIndex.ResolveScopedName('TPtr', 'ScopedUnit', 'inner', [],
      'implementation');
    Assert.IsTrue(lInnerPointer.Found, lInnerPointer.Reason);
    Assert.AreEqual('inner', lInnerPointer.Identity.OwnerScopeId);
    lResult := lIndex.ResolveScopedName('TPtr', 'ScopedUnit', 'outer', [],
      'implementation');
    Assert.IsTrue(lResult.Found, lResult.Reason);
    Assert.AreNotEqual(lInnerPointer.Identity.CanonicalId.Value,
      lResult.Identity.CanonicalId.Value,
      'Pointer identity includes the declaration-scope pointee.');
    Assert.AreNotEqual(lInner.Identity.CanonicalId.Value,
      lResult.Identity.CanonicalId.Value);
    lResult := lIndex.ResolveScopedName('TItem', 'ScopedUnit', 'broken', [],
      'implementation');
    Assert.IsFalse(lResult.Found, 'Incomplete parent chain cannot fall through to unit type.');
    lResult := lIndex.ResolveScopedName('TItem', 'ScopedUnit', 'unknown', [],
      'implementation');
    Assert.IsFalse(lResult.Found, 'Unknown caller scope cannot see a unit homonym.');
    lResult := lIndex.ResolveScopedName('TItem', 'ScopedUnit', 'cycle', [],
      'implementation');
    Assert.IsFalse(lResult.Found, 'Cyclic parent scope cannot fall back.');
    lResult := lIndex.ResolveScopedName('TUnsupported', 'ScopedUnit', 'inner', [],
      'implementation');
    Assert.IsFalse(lResult.Found, 'Unsupported nearest local type must stop lookup.');
  finally
    lGraph.Free;
  end;
end;

procedure TTypeResolverTests.PreservesDeclaredCanonicalAndUnderlyingAliasIdentities;
var
  lGraph: TDelphiSemanticSemanticGraph;
  lIndex: TDelphiSemanticTypeIdentityIndex;
  lResult: TDelphiSemanticTypeLookupResult;
begin
  lGraph := Graph;
  try
    lIndex := TDelphiSemanticTypeResolver.BuildIndex(lGraph);

    lResult := lIndex.ResolveSimpleName('TAlias');

    Assert.IsTrue(lResult.Found, lResult.Reason);
    Assert.AreEqual('TAlias', lResult.Identity.Name);
    Assert.AreEqual('TChild', lResult.Identity.CanonicalName);
    Assert.AreEqual('class', lResult.Identity.UnderlyingName);
    Assert.AreEqual(lResult.Identity.UnderlyingName,
      lIndex.FindByUnderlyingId(lResult.Identity.UnderlyingId)[0].UnderlyingName);
    Assert.AreNotEqual(lResult.Identity.DeclaredId.Value,
      lResult.Identity.CanonicalId.Value);
    Assert.AreNotEqual(lResult.Identity.CanonicalId.Value,
      lResult.Identity.UnderlyingId.Value);
  finally
    lGraph.Free;
  end;
end;

procedure TTypeResolverTests.ReportsAmbiguousSimpleNames;
var
  lGraph: TDelphiSemanticSemanticGraph;
  lIndex: TDelphiSemanticTypeIdentityIndex;
  lResult: TDelphiSemanticTypeLookupResult;
begin
  lGraph := Graph;
  try
    lIndex := TDelphiSemanticTypeResolver.BuildIndex(lGraph);

    lResult := lIndex.ResolveSimpleName('TShared');

    Assert.IsFalse(lResult.Found);
    Assert.IsTrue(lResult.Ambiguous);
    Assert.AreEqual('ambiguous', lResult.Status);
    Assert.AreEqual(2, Integer(Length(lResult.Candidates)));
  finally
    lGraph.Free;
  end;
end;

procedure TTypeResolverTests.ResolvesSimpleQualifiedAndVisibleTypeNames;
var
  lGraph: TDelphiSemanticSemanticGraph;
  lIndex: TDelphiSemanticTypeIdentityIndex;
  lResult: TDelphiSemanticTypeLookupResult;
begin
  lGraph := Graph;
  try
    lIndex := TDelphiSemanticTypeResolver.BuildIndex(lGraph);

    lResult := lIndex.ResolveSimpleName('TBase');
    Assert.IsTrue(lResult.Found, lResult.Reason);
    Assert.AreEqual('TypeUnitA', lResult.Identity.UnitName);

    lResult := lIndex.ResolveQualifiedName('TypeUnitA.TChild');
    Assert.IsTrue(lResult.Found, lResult.Reason);
    Assert.AreEqual('TChild', lResult.Identity.Name);

    lResult := lIndex.ResolveVisibleName('TExternalOnly', 'TypeUnitA',
      ['TypeUnitA', 'TypeUnitC']);
    Assert.IsTrue(lResult.Found, lResult.Reason);
    Assert.AreEqual('TypeUnitC', lResult.Identity.UnitName);

    lResult := lIndex.ResolveVisibleName('TShared', 'TypeUnitA', ['TypeUnitA', 'TypeUnitB']);
    Assert.IsTrue(lResult.Found, lResult.Reason);
    Assert.AreEqual('TypeUnitA', lResult.Identity.UnitName);

    lResult := lIndex.ResolveVisibleName('TImplOnly', 'TypeUnitA', [],
      'implementation');
    Assert.IsTrue(lResult.Found, lResult.Reason);
    Assert.AreEqual('TImplOnly', lResult.Identity.Name);

    lResult := lIndex.ResolveVisibleName('TQualifiedAlias', 'TypeUnitA', ['TypeUnitC']);
    Assert.IsTrue(lResult.Found, lResult.Reason);
    Assert.AreEqual('class', lResult.Identity.UnderlyingName);
  finally
    lGraph.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTypeResolverTests);

end.
