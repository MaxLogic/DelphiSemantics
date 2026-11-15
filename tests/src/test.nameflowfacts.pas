unit Test.NameFlowFacts;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TNameFlowFactsTests = class
  public
    [Test] procedure RepeatedNodeMetadataHasBoundedPersistence;
    [Test] procedure RejectsOversizedFactsEnvelopeBeforeInflation;
    [Test] procedure OversizedSnapshotLeavesNoPartialCacheEntry;
    [Test] procedure PreservesOrderedOperandsAndImmutableChildren;
    [Test] procedure RejectsMissingAndCorruptPersistence;
    [Test] procedure ModelAndSnapshotRoundTripRetainFacts;
    [Test] procedure LeanSymbolModelsRetainFullRuntimeFacts;
    [Test] procedure BudgetStopsBeforePartialGraphPublication;
    [Test] procedure MapsExclusiveEndAtNextCopiedLine;
    [Test] procedure GenuineUnknownSyntaxRemainsIncomplete;
    [Test] procedure IndexAndGenericSpansIncludeDelimiters;
  end;

implementation

uses
  System.IOUtils, System.JSON, System.JSON.Serializers, System.SysUtils,
  Winapi.Windows,
  DelphiAST.Classes, DelphiAST.Consts,
  DelphiSemantics.Model, DelphiSemantics.Model.Json, DelphiSemantics.NameFlow.Extract,
  DelphiSemantics.NameFlow.Facts, DelphiSemantics.Preprocess, DelphiSemantics.Snapshot, DelphiSemantics.Snapshot.Builder,
  DelphiSemantics.Snapshot.Cache.Sqlite, DelphiSemantics.WithBinding,
  Test.Support;

procedure TNameFlowFactsTests.RepeatedNodeMetadataHasBoundedPersistence;
const
  cNodeCount = 4096;
var
  i: Integer;
  lNodes: TArray<TDelphiNameFlowNode>;
  lFacts, lReloaded: IDelphiNameFlowFacts;
  lJson: string;
  lSerializer: TJsonSerializer;
begin
  SetLength(lNodes, cNodeCount);
  for i := 0 to High(lNodes) do
  begin
    lNodes[i].Id := i + 1;
    lNodes[i].ParentId := i;
    if i < High(lNodes) then
      lNodes[i].Children := [i + 2];
    lNodes[i].Kind := TDelphiNameFlowNodeKind.IdentifierValue;
    lNodes[i].SyntaxKind := 'identifier';
    if Odd(i) then
      lNodes[i].Name := 'Quoted"Name'#$00E9
    else
      lNodes[i].Name := 'QUOTED"NAME'#$00E9;
    lNodes[i].Value := 'value'#0#9#13#10;
    lNodes[i].TypeName := 'string';
    lNodes[i].ScopeId := StringOfChar('s', 8192);
    lNodes[i].OwnerType := 'TCaseSensitive';
    lNodes[i].FileName := StringOfChar('p', 240) + '.pas';
    lNodes[i].Line := i + 1;
    lNodes[i].Column := 2;
    lNodes[i].EndLine := i + 1;
    lNodes[i].EndColumn := 12;
    lNodes[i].OutputStartOffset := i * 16 + 1;
    lNodes[i].OutputEndOffset := i * 16 + 11;
    lNodes[i].ExpansionId := '1:exact';
    lNodes[i].SpanKnown := True;
    lNodes[i].ActivityKnown := Odd(i);
    lNodes[i].BodyComplete := not Odd(i);
    SetLength(lNodes[i].Attributes, 1);
    lNodes[i].Attributes[0].Name := 'name';
    lNodes[i].Attributes[0].Value := lNodes[i].Name;
  end;
  lFacts := CreateNameFlowFacts(lNodes, True, True, 'retained-reason');
  lJson := NameFlowFactsToJson(lFacts);
  // Repeated metadata must not multiply into a SQLite-sized row as node count grows.
  Assert.IsTrue(Length(lJson) < 1024 * 1024,
    '4096 nodes sharing metadata must fit in 1 Mi characters, not duplicate 32 Mi of scopes');
  lReloaded := NameFlowFactsFromJson(lJson);
  Assert.IsTrue(lReloaded.Complete, lReloaded.CoverageReason);
  Assert.IsTrue(lReloaded.ConfigurationComplete);
  Assert.AreEqual('retained-reason', lReloaded.CoverageReason);
  Assert.AreEqual(cNodeCount, lReloaded.NodeCount);
  lSerializer := TJsonSerializer.Create;
  try
    for i := 1 to cNodeCount do
      Assert.AreEqual(lSerializer.Serialize<TDelphiNameFlowNode>(lFacts.NodeById(i)),
        lSerializer.Serialize<TDelphiNameFlowNode>(lReloaded.NodeById(i)),
        'Every scalar, ordered child and attribute must survive persistence');
  finally
    lSerializer.Free;
  end;
end;

procedure TNameFlowFactsTests.RejectsOversizedFactsEnvelopeBeforeInflation;
var
  lNode: TDelphiNameFlowNode;
  lFacts: IDelphiNameFlowFacts;
  lJson: TJSONObject;
  lPair: TJSONPair;
begin
  lNode := Default(TDelphiNameFlowNode);
  lNode.Id := 1;
  lNode.SyntaxKind := 'unit';
  lFacts := CreateNameFlowFacts([lNode], True, True, '');
  lJson := TJSONObject.ParseJSONValue(NameFlowFactsToJson(lFacts)) as TJSONObject;
  try
    lPair := lJson.RemovePair('PayloadBytes');
    lPair.Free;
    lJson.AddPair('PayloadBytes', TJSONNumber.Create(High(Integer)));
    Assert.IsFalse(NameFlowFactsFromJson(lJson.ToJSON).Complete,
      'Reject an oversized declared payload before allocating or inflating it');
  finally
    lJson.Free;
  end;
end;

procedure TNameFlowFactsTests.OversizedSnapshotLeavesNoPartialCacheEntry;
var
  lPrevious, lFileName, lFactsJson: string;
  lOptions: TDelphiSemanticModelOptions;
  lModel: TDelphiSemanticUnitModel;
  lSnapshot, lReloaded: TDelphiProjectSnapshot;
  lMetrics: TDelphiSnapshotBuilderMetrics;
  lIdentity: TDelphiSemanticSnapshotCacheIdentity;
  lCache: TDelphiSemanticSnapshotSqliteCache;
begin
  lPrevious := GetEnvironmentVariable('DS_TEST_SNAPSHOT_TEXT_CHARACTER_LIMIT');
  SetEnvironmentVariable('DS_TEST_SNAPSHOT_TEXT_CHARACTER_LIMIT', '128');
  try
    lFileName := TPath.Combine(CreateTestTempRoot('nameflow-large-temp'), 'LargeFacts.pas');
    TFile.WriteAllText(lFileName, 'unit LargeFacts; interface implementation end.', TEncoding.ASCII);
    lOptions := Default(TDelphiSemanticModelOptions);
    lOptions.SourceFileName := lFileName;
    lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
    lFactsJson := NameFlowFactsToJson(lModel.NameFlowFacts);
    Assert.IsTrue(Length(lFactsJson) > 128, 'Synthetic facts exceed the reduced storage limit');
    lSnapshot := BuildProjectSnapshotFromModels([lModel],
      Default(TDelphiSemanticProjectWithBindingFacts), Default(TDelphiSnapshotBuildOptions), lMetrics);
    lIdentity := Default(TDelphiSemanticSnapshotCacheIdentity);
    lIdentity.CacheKey := 'oversized-name-flow-facts';
    lIdentity.IdentityKey := lIdentity.CacheKey;
    lIdentity.SourceFileName := lFileName;
    lIdentity.FileHash := 'file';
    lIdentity.ContextHash := 'context';
    lIdentity.IncludeGraphHash := 'includes';
    lIdentity.SchemaVersion := 'oversized-fixture';
    lCache := TDelphiSemanticSnapshotSqliteCache.Create(TPath.ChangeExtension(lFileName, '.sqlite3'));
    lReloaded := nil;
    try
      lCache.StoreUnitFromSnapshot(lIdentity, lSnapshot, 0);
      Assert.AreEqual('snapshot-cache-entry-too-large', lCache.LastInvalidationReason);
      Assert.AreEqual(lFactsJson,
        lSnapshot.ExactTextOf(lSnapshot.UnitByIndex(0).NameFlowFactsJsonId),
        'Persistence fallback never removes or truncates runtime facts');
      Assert.IsFalse(lCache.TryLoadUnit(lIdentity, lReloaded),
        'An oversized snapshot is recomputed, never published as a partial cache hit');
    finally
      lReloaded.Free;
      lCache.Free;
      lSnapshot.Free;
    end;
  finally
    SetEnvironmentVariable('DS_TEST_SNAPSHOT_TEXT_CHARACTER_LIMIT', PChar(lPrevious));
  end;
end;

procedure TNameFlowFactsTests.PreservesOrderedOperandsAndImmutableChildren;
var
  lRoot, lLeft, lRight: TSyntaxNode;
  lFacts, lReloaded: IDelphiNameFlowFacts;
  lNode: TDelphiNameFlowNode;
begin
  lRoot := TSyntaxNode.Create(ntAdd);
  try
    lRoot.Line := 1;
    lRoot.Col := 1;
    lLeft := lRoot.AddChild(ntIdentifier);
    lLeft.Line := 1;
    lLeft.Col := 1;
    lLeft.SetAttribute(anName, 's');
    lRight := lRoot.AddChild(ntLiteral);
    lRight.Line := 1;
    lRight.Col := 3;
    lFacts := ExtractNameFlowFacts(lRoot, 'unit.pas', 's+1', True, True, '');
    Assert.AreEqual(3, lFacts.NodeCount);
    lNode := lFacts.NodeById(1);
    Assert.AreEqual(2, Integer(Length(lNode.Children)));
    Assert.AreEqual(2, lNode.Children[0]);
    lNode.Children[0] := 99;
    Assert.AreEqual(2, lFacts.NodeById(1).Children[0]);
    Assert.AreEqual(1, lFacts.NodeById(2).ParentId);
    lReloaded := NameFlowFactsFromJson(NameFlowFactsToJson(lFacts));
    Assert.AreEqual(NameFlowFactsToJson(lFacts), NameFlowFactsToJson(lReloaded));
  finally
    lRoot.Free;
  end;
end;

procedure TNameFlowFactsTests.RejectsMissingAndCorruptPersistence;
begin
  Assert.IsFalse(NameFlowFactsFromJson('').Complete);
  Assert.IsFalse(NameFlowFactsFromJson('{}').Complete);
  Assert.IsFalse(NameFlowFactsFromJson('{bad').Complete);
  Assert.IsFalse(NameFlowFactsFromJson('{"Version":1,"Complete":true,"Nodes":[]}').Complete);
end;

procedure TNameFlowFactsTests.ModelAndSnapshotRoundTripRetainFacts;
var
  lFileName: string;
  lOptions: TDelphiSemanticModelOptions;
  lModel, lReloaded: TDelphiSemanticUnitModel;
  lSnapshot: TDelphiProjectSnapshot;
  lBuildMetrics: TDelphiSnapshotBuilderMetrics;
  lCache: TDelphiSemanticSnapshotSqliteCache;
  lIdentity: TDelphiSemanticSnapshotCacheIdentity;
  lWarmSnapshot: TDelphiProjectSnapshot;
  lFacts: IDelphiNameFlowFacts;
  lNode: TDelphiNameFlowNode;
  i, lCalls, lRaises, lFormals, lAdds: Integer;
begin
  lFileName := TPath.Combine(CreateTestTempRoot('nameflow-facts-temp'), 'FlowFacts.pas');
  TFile.WriteAllText(lFileName, 'unit FlowFacts;'#13#10'interface'#13#10'implementation'#13#10 +
    'function Work(const s: string): Integer;'#13#10 +
    'begin Result := Length(s)+1; Work(s); raise; end;'#13#10'end.', TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lFileName;
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);
  Assert.IsNotNull(lModel.NameFlowFacts);
  Assert.IsTrue(lModel.NameFlowFacts.NodeCount > 0);
  Assert.IsTrue(lModel.NameFlowFacts.Complete, lModel.NameFlowFacts.CoverageReason);
  lCalls := 0;
  lRaises := 0;
  lFormals := 0;
  lAdds := 0;
  for i := 1 to lModel.NameFlowFacts.NodeCount do
  begin
    lNode := lModel.NameFlowFacts.NodeById(i);
    if lNode.SyntaxKind = 'call' then
    begin
      Inc(lCalls);
      if (Length(lNode.Children) = 2) and
        (lModel.NameFlowFacts.NodeById(lNode.Children[0]).Name = 'Length') then
      begin
        Assert.AreEqual(17, lNode.Column);
        Assert.AreEqual(26, lNode.EndColumn, 'Call span includes its closing parenthesis');
      end;
    end;
    if lNode.SyntaxKind = 'raise' then Inc(lRaises);
    if lNode.SyntaxKind = 'parameter' then Inc(lFormals);
    if lNode.SyntaxKind = 'add' then
    begin
      Inc(lAdds);
      Assert.AreEqual(17, lNode.Column, 'Binary expression starts at the first operand');
      Assert.AreEqual(28, lNode.EndColumn, 'Binary expression ends after its last operand');
    end;
  end;
  Assert.IsTrue(lCalls >= 2);
  Assert.AreEqual(1, lRaises);
  Assert.AreEqual(1, lFormals);
  Assert.AreEqual(1, lAdds, 'Length(s)+1 retains one complete numeric expression');
  lReloaded := JsonToModel(ModelToJson(lModel));
  Assert.AreEqual(NameFlowFactsToJson(lModel.NameFlowFacts), NameFlowFactsToJson(lReloaded.NameFlowFacts));
  lSnapshot := BuildProjectSnapshotFromModels([lReloaded],
    Default(TDelphiSemanticProjectWithBindingFacts), Default(TDelphiSnapshotBuildOptions), lBuildMetrics);
  try
    lFacts := NameFlowFactsFromJson(lSnapshot.ExactTextOf(lSnapshot.UnitByIndex(0).NameFlowFactsJsonId));
    Assert.AreEqual(NameFlowFactsToJson(lModel.NameFlowFacts), NameFlowFactsToJson(lFacts));
    lIdentity := Default(TDelphiSemanticSnapshotCacheIdentity);
    lIdentity.CacheKey := 'nameflow-facts-202';
    lIdentity.IdentityKey := 'nameflow-facts-202';
    lIdentity.SourceFileName := lFileName;
    lIdentity.FileHash := 'fixture-file-hash';
    lIdentity.ContextHash := 'fixture-context-hash';
    lIdentity.IncludeGraphHash := 'fixture-include-hash';
    lIdentity.SchemaVersion := 'nameflow-facts-202';
    lCache := TDelphiSemanticSnapshotSqliteCache.Create(TPath.ChangeExtension(lFileName, '.sqlite3'));
    try
      lCache.StoreUnitFromSnapshot(lIdentity, lSnapshot, 0);
    finally
      lCache.Free;
    end;
    lCache := TDelphiSemanticSnapshotSqliteCache.Create(TPath.ChangeExtension(lFileName, '.sqlite3'));
    lWarmSnapshot := nil;
    try
      Assert.IsTrue(lCache.TryLoadUnit(lIdentity, lWarmSnapshot));
      lFacts := NameFlowFactsFromJson(lWarmSnapshot.ExactTextOf(lWarmSnapshot.UnitByIndex(0).NameFlowFactsJsonId));
      Assert.AreEqual(NameFlowFactsToJson(lModel.NameFlowFacts), NameFlowFactsToJson(lFacts));
    finally
      lWarmSnapshot.Free;
      lCache.Free;
    end;
  finally
    lSnapshot.Free;
  end;
end;

procedure TNameFlowFactsTests.LeanSymbolModelsRetainFullRuntimeFacts;
var
  lFileName: string;
  lOptions: TDelphiSemanticModelOptions;
  lModel, lFull: TDelphiSemanticUnitModel;
begin
  lFileName := TPath.Combine(CreateTestTempRoot('nameflow-skip-temp'), 'SkipFacts.pas');
  TFile.WriteAllText(lFileName, 'unit SkipFacts; interface implementation procedure Work; begin Work; end; end.', TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lFileName;
  lOptions.SkipBodyAnalysis := True;
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsNotNull(lModel.NameFlowFacts);
  Assert.IsTrue(lModel.NameFlowFacts.Complete, lModel.NameFlowFacts.CoverageReason);
  Assert.IsTrue(lModel.NameFlowFacts.NodeCount > 0,
    'Runtime effects require the full parser tree even when symbol bodies are lean');
  lOptions.SkipBodyAnalysis := False;
  lFull := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lFull.NameFlowFacts.Complete, lFull.NameFlowFacts.CoverageReason);
  Assert.AreEqual(NameFlowFactsToJson(lFull.NameFlowFacts), NameFlowFactsToJson(lModel.NameFlowFacts),
    'Identifier scoping must preserve every ordered runtime-effect fact');
end;

procedure TNameFlowFactsTests.BudgetStopsBeforePartialGraphPublication;
var
  lRoot: TSyntaxNode;
  lFacts: IDelphiNameFlowFacts;
begin
  lRoot := TSyntaxNode.Create(ntAdd);
  try
    lRoot.AddChild(ntIdentifier);
    lRoot.AddChild(ntLiteral);
    lFacts := ExtractNameFlowFacts(lRoot, 'unit.pas', 's+1', True, True, '', 2);
    Assert.IsFalse(lFacts.Complete, 'A three-node tree exceeds the two-node budget');
    Assert.AreEqual(0, lFacts.NodeCount, 'Never publish a partial graph as a complete inventory');
    Assert.AreEqual('name-flow-fact-budget-exceeded', lFacts.CoverageReason);
  finally
    lRoot.Free;
  end;
end;

procedure TNameFlowFactsTests.MapsExclusiveEndAtNextCopiedLine;
var
  lNode: TDelphiNameFlowNode;
  lPreprocess: TDelphiSemanticPreprocessResult;
  lFacts: IDelphiNameFlowFacts;
begin
  lNode := Default(TDelphiNameFlowNode);
  lNode.Id := 1;
  lNode.Kind := TDelphiNameFlowNodeKind.Routine;
  lNode.SyntaxKind := 'method';
  lNode.SpanKnown := True;
  lNode.OutputStartOffset := 1;
  lNode.OutputEndOffset := 7;
  lPreprocess := Default(TDelphiSemanticPreprocessResult);
  lPreprocess.Success := True;
  lPreprocess.ActivityEvidenceAvailable := True;
  SetLength(lPreprocess.CopiedSourceSpans, 2);
  lPreprocess.CopiedSourceSpans[0].OutputStartOffset := 1;
  lPreprocess.CopiedSourceSpans[0].OutputEndOffset := 5;
  lPreprocess.CopiedSourceSpans[0].SourceStartOffset := 1;
  lPreprocess.CopiedSourceSpans[0].FileName := 'unit.pas';
  lPreprocess.CopiedSourceSpans[0].ExpansionId := '1';
  lPreprocess.CopiedSourceSpans[0].SourceText := 'work'#13#10'next';
  lPreprocess.CopiedSourceSpans[0].Line := 1;
  lPreprocess.CopiedSourceSpans[0].Column := 1;
  lPreprocess.CopiedSourceSpans[1] := lPreprocess.CopiedSourceSpans[0];
  lPreprocess.CopiedSourceSpans[1].OutputStartOffset := 7;
  lPreprocess.CopiedSourceSpans[1].OutputEndOffset := 11;
  lPreprocess.CopiedSourceSpans[1].SourceStartOffset := 7;
  lPreprocess.CopiedSourceSpans[1].Line := 2;
  lFacts := MapNameFlowFacts(CreateNameFlowFacts([lNode], True, True, ''),
    'work'#13#10'next', lPreprocess, 0);
  Assert.IsTrue(lFacts.Complete, lFacts.CoverageReason);
  Assert.IsTrue(lFacts.NodeById(1).SpanKnown);
  Assert.AreEqual(2, lFacts.NodeById(1).EndLine);
  Assert.AreEqual(1, lFacts.NodeById(1).EndColumn);
end;

procedure TNameFlowFactsTests.GenuineUnknownSyntaxRemainsIncomplete;
var
  lRoot: TSyntaxNode;
  lFacts: IDelphiNameFlowFacts;
begin
  lRoot := TSyntaxNode.Create(ntUnknown);
  try
    lFacts := ExtractNameFlowFacts(lRoot, 'unit.pas', '', True, True, '');
    Assert.IsFalse(lFacts.Complete);
    Assert.AreEqual('name-flow-syntax-unsupported', lFacts.CoverageReason);
  finally
    lRoot.Free;
  end;
end;

procedure TNameFlowFactsTests.IndexAndGenericSpansIncludeDelimiters;
var
  lOptions: TDelphiSemanticModelOptions;
  lModel: TDelphiSemanticUnitModel;
  lNode: TDelphiNameFlowNode;
  i, lIndexes, lGenericArguments: Integer;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := TPath.Combine(CreateTestTempRoot('nameflow-delimiters-temp'), 'DelimiterFacts.pas');
  TFile.WriteAllText(lOptions.SourceFileName,
    'unit DelimiterFacts;'#13#10'interface'#13#10'implementation'#13#10 +
    'type TBox<T> = class end;'#13#10'procedure Work(const s: string);'#13#10'var x: Char;'#13#10 +
    'begin x := s[1]; TBox<Integer>.Create; Work(s); end;'#13#10'end.', TEncoding.ASCII);
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);
  Assert.IsTrue(lModel.NameFlowFacts.Complete, lModel.NameFlowFacts.CoverageReason);
  lIndexes := 0;
  lGenericArguments := 0;
  for i := 1 to lModel.NameFlowFacts.NodeCount do
  begin
    lNode := lModel.NameFlowFacts.NodeById(i);
    if (lNode.Line = 7) and (lNode.SyntaxKind = 'indexed') then
    begin
      Inc(lIndexes);
      Assert.AreEqual(12, lNode.Column);
      Assert.AreEqual(16, lNode.EndColumn, 'Index span includes its closing square bracket');
    end;
    if (lNode.Line = 7) and (lNode.SyntaxKind = 'typeargs') then
    begin
      Inc(lGenericArguments);
      Assert.AreEqual(22, lNode.Column);
      Assert.AreEqual(31, lNode.EndColumn, 'Generic arguments include the closing angle bracket');
    end;
  end;
  Assert.AreEqual(1, lIndexes);
  Assert.AreEqual(1, lGenericArguments);
end;

initialization
  TDUnitX.RegisterTestFixture(TNameFlowFactsTests);

end.
