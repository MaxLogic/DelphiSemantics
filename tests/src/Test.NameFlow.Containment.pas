unit Test.NameFlow.Containment;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TNameFlowContainmentTests = class
  public
    [Test] procedure MissingFactsRefuse;
    [Test] procedure RaiseObservesClassNames;
    [Test] procedure RaiseDoesNotObserveRecordNames;
    [Test] procedure UnboundExecutableCallRefuses;
    [Test] procedure ConstantBindingUsesNearestDeclaration;
    [Test] procedure AcceptedRiskOnlyPromotesWarnableGaps;
    [Test] procedure RiskConsentPreservesHardAndFailedPlans;
    [Test] procedure RiskWarningsChangeFingerprint;
    [Test] procedure RuntimeRiskCategoriesAreExplicit;
    [Test] procedure PositiveConsumerDescriptionsRespectTargetKinds;
    [Test] procedure OpaqueSpellingDoesNotBecomeKnownConsumer;
    [Test] procedure PinnedConsumerFamiliesDescribeNameOrdinals;
    [Test] procedure RiskPromotionPreservesOrdinarySnapshotCollision;
    [Test] procedure KnownConsumerSurvivesUnrelatedReviewedPinMismatch;
    [Test] procedure SetSetPropEnumNameArgumentRemainsHard;
    [Test] procedure UnsupportedQualifiedNameGrammarRemainsHard;
    [Test] procedure CompoundEnumNameGrammarRemainsHard;
    [Test] procedure SimpleQualifiedNameGrammarKeepsPrecision;
    [Test] procedure ExportNameRequiresWholeValueOrUnknown;
    [Test] procedure LeanPrimitiveMatchProvesKnownConsumerBinding;
    [Test] procedure LeanActualWithCaptureRemainsUnknown;
    [Test] procedure ActualWithCaptureDoesNotFoldUnitConstant;
    [Test] procedure SameLineLocalConstantCannotUseOtherInitializer;
    [Test] procedure StandaloneConstantMatchProvesKnownConsumerBinding;
    [Test] procedure StandaloneParameterShadowRemainsUnknown;
    [Test] procedure ActualConstantMatchProvesKnownConsumerBinding;
    [Test] procedure UnshadowedActualConstantKeepsKnownNonmatch;
    [Test] procedure ActualParameterShadowDoesNotFoldOuterConstant;
    [Test] procedure ActualLocalVariableShadowDoesNotFoldOuterConstant;
    [Test] procedure ActualNestedParameterShadowDoesNotFoldOuterConstant;
    [Test] procedure ActualResourceStringValueRemainsUnknown;
    [Test] procedure ActualTypedConstantValueRemainsUnknown;
  end;

implementation

uses
  System.Hash, System.IOUtils, System.StrUtils, System.SysUtils,
  DelphiSemantics.ImportFacts, DelphiSemantics.Model, DelphiSemantics.Query, DelphiSemantics.Refactor, DelphiSemantics.Usage,
  DelphiSemantics.NameConsumers, DelphiSemantics.NameFlow.Containment,
  DelphiSemantics.NameFlow.Facts, DelphiSemantics.NameFlow.SdkEffects, DelphiSemantics.Snapshot,
  DelphiSemantics.Snapshot.Builder, DelphiSemantics.Snapshot.PositionResolver,
  DelphiSemantics.WithBinding,
  Test.Support;

procedure TNameFlowContainmentTests.ConstantBindingUsesNearestDeclaration;
const
  cSource = 'unit UCertified;'#13#10'interface'#13#10'procedure Touch;'#13#10 +
    'implementation'#13#10'uses UNames;'#13#10'const cPre = ''Co'';'#13#10 +
    'procedure Touch;'#13#10'var Name: string;'#13#10'begin'#13#10 +
    '  Name := cPre + ''unt'';'#13#10'end;'#13#10'end.';
var
  lRoot, lFile: string;
  lOptions: TDelphiSemanticModelOptions;
  lModels: TArray<TDelphiSemanticUnitModel>;
  lSnapshot: TDelphiProjectSnapshot;
  lMetrics: TDelphiSnapshotBuilderMetrics;
  lBoundUnit: TUnitSnapshot;
  lBoundSymbol: TSemanticSymbolFact;
begin
  lRoot := CreateTestTempRoot('nameflow-constant-temp');
  lFile := TPath.Combine(lRoot, 'UCertified.pas');
  TFile.WriteAllText(lFile, cSource, TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'UNames.pas'),
    'unit UNames;'#13#10'interface'#13#10'const cPre = ''Xo'';'#13#10 +
    'implementation'#13#10'end.', TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lFile;
  lOptions.SearchPaths := [lRoot];
  SetLength(lModels, 2);
  lModels[0] := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  lOptions.SourceFileName := TPath.Combine(lRoot, 'UNames.pas');
  lModels[1] := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  lSnapshot := BuildProjectSnapshotFromModels(lModels,
    Default(TDelphiSemanticProjectWithBindingFacts), Default(TDelphiSnapshotBuildOptions), lMetrics);
  try
    Assert.IsTrue(TryBindNameFlowConstant(lSnapshot, lFile, 'cPre', 10, 11, lBoundUnit, lBoundSymbol));
    Assert.AreEqual(lFile, lSnapshot.TextOf(lBoundUnit.FileNameId));
    Assert.AreEqual(6, lBoundSymbol.Line,
      'The active local Co declaration wins over imported Xo');
  finally
    lSnapshot.Free;
  end;
end;

function SnapshotWithNode(const aKind: TDelphiNameFlowNodeKind;
  const aSyntax, aName: string): TDelphiProjectSnapshot;
var
  lBuilder: TDelphiProjectSnapshotBuilder;
  lUnit: TUnitSnapshot;
  lNode: TDelphiNameFlowNode;
begin
  lBuilder := TDelphiProjectSnapshotBuilder.Create;
  try
    lUnit := TUnitSnapshot.Create(1, lBuilder.Strings.Intern('unit.pas'),
      lBuilder.Strings.Intern('Unit1'), lBuilder.ExactStrings.Intern('begin Opaque(); end.'));
    lNode := Default(TDelphiNameFlowNode);
    lNode.Id := 1;
    lNode.Kind := aKind;
    lNode.SyntaxKind := aSyntax;
    lNode.Name := aName;
    lNode.FileName := 'unit.pas';
    lNode.Line := 1;
    lNode.Column := 7;
    lNode.SpanKnown := True;
    lNode.ActivityKnown := True;
    lUnit.SetNameFlowFactsJsonId(lBuilder.ExactStrings.Intern(NameFlowFactsToJson(
      CreateNameFlowFacts([lNode], True, True, ''))));
    lBuilder.AddUnit(lUnit);
    Result := lBuilder.Build;
  finally
    lBuilder.Free;
  end;
end;

procedure TNameFlowContainmentTests.MissingFactsRefuse;
var
  lReport: TNameFlowAnalysis;
begin
  lReport := AnalyzeNameFlowSnapshot(nil, TNameEffectTargetKind.Member, nil);
  Assert.AreEqual(1, Integer(Length(lReport.Gaps)));
  Assert.AreEqual('runtime-name-flow-coverage-unproved', lReport.Gaps[0].Reason);
end;

procedure TNameFlowContainmentTests.RaiseObservesClassNames;
var
  lSnapshot: TDelphiProjectSnapshot;
  lReport: TNameFlowAnalysis;
begin
  lSnapshot := SnapshotWithNode(TDelphiNameFlowNodeKind.RaiseValue, 'raise', '');
  try
    lReport := AnalyzeNameFlowSnapshot(lSnapshot, TNameEffectTargetKind.ClassType, nil);
    Assert.AreEqual(1, lReport.Statistics.LanguageRoots);
    Assert.AreEqual('runtime-name-metadata-consumer', lReport.Gaps[0].Reason);
  finally
    lSnapshot.Free;
  end;
end;

procedure TNameFlowContainmentTests.RaiseDoesNotObserveRecordNames;
var
  lSnapshot: TDelphiProjectSnapshot;
  lReport: TNameFlowAnalysis;
begin
  lSnapshot := SnapshotWithNode(TDelphiNameFlowNodeKind.RaiseValue, 'raise', '');
  try
    lReport := AnalyzeNameFlowSnapshot(lSnapshot, TNameEffectTargetKind.OtherType, nil);
    Assert.AreEqual(0, Integer(Length(lReport.Gaps)));
  finally
    lSnapshot.Free;
  end;
end;

procedure TNameFlowContainmentTests.UnboundExecutableCallRefuses;
var
  lSnapshot: TDelphiProjectSnapshot;
  lReport: TNameFlowAnalysis;
begin
  lSnapshot := SnapshotWithNode(TDelphiNameFlowNodeKind.Call, 'call', 'Opaque');
  try
    lReport := AnalyzeNameFlowSnapshot(lSnapshot, TNameEffectTargetKind.Member, nil);
    Assert.AreEqual(1, lReport.Statistics.UnboundCalls);
    Assert.AreEqual('runtime-name-call-effect-unproved', lReport.Gaps[0].Reason);
  finally
    lSnapshot.Free;
  end;
end;

function RuntimePolicyPlan: TDelphiSemanticRenamePlan;
begin
  Result := Default(TDelphiSemanticRenamePlan);
  Result.Status := 'incomplete';
  SetLength(Result.Edits, 1);
  Result.Edits[0].ExpectedSourceText := 'OldName';
  Result.Edits[0].NewText := 'NewName';
  SetLength(Result.UnresolvedReferences, 1);
  Result.UnresolvedReferences[0].Reason := 'runtime-name-call-effect-unproved';
end;

procedure TNameFlowContainmentTests.AcceptedRiskOnlyPromotesWarnableGaps;
var
  lPlan: TDelphiSemanticRenamePlan;
  lContext: TDelphiSemanticSymbolQueryContext;
begin
  lContext := Default(TDelphiSemanticSymbolQueryContext);
  lPlan := RuntimePolicyPlan;
  ApplyRenameRuntimeNameRiskPolicy(lContext, False, lPlan);
  Assert.AreEqual('incomplete', lPlan.Status);
  Assert.AreEqual(1, Integer(Length(lPlan.UnresolvedReferences)));
  lPlan := RuntimePolicyPlan;
  ApplyRenameRuntimeNameRiskPolicy(lContext, True, lPlan);
  Assert.AreEqual('planned', lPlan.Status);
  Assert.IsTrue(lPlan.AcceptRuntimeNameRisk);
  Assert.AreEqual(0, Integer(Length(lPlan.UnresolvedReferences)));
  Assert.AreEqual(1, Integer(Length(lPlan.RuntimeNameWarnings)));
  Assert.IsNotEmpty(lPlan.ContextFingerprint);
  Assert.IsTrue(Length(lPlan.RequiredVerification) > 0);
end;

procedure TNameFlowContainmentTests.RiskConsentPreservesHardAndFailedPlans;
var
  lPlan: TDelphiSemanticRenamePlan;
  lContext: TDelphiSemanticSymbolQueryContext;
  lReason, lStatus: string;
begin
  lContext := Default(TDelphiSemanticSymbolQueryContext);
  for lReason in ['string-name-consumer', 'rtti-string-name-consumer',
    'declared-name-consumer', 'runtime-name-known-consumer-unknown',
    'runtime-name-known-consumer-match', 'ds800-binding-unproved', 'include-file-not-found'] do
  begin
    lPlan := RuntimePolicyPlan;
    SetLength(lPlan.UnresolvedReferences, 2);
    lPlan.UnresolvedReferences[1].Reason := lReason;
    ApplyRenameRuntimeNameRiskPolicy(lContext, True, lPlan);
    Assert.AreEqual('incomplete', lPlan.Status, lReason);
    Assert.AreEqual(1, Integer(Length(lPlan.UnresolvedReferences)), lReason);
    Assert.AreEqual(lReason, lPlan.UnresolvedReferences[0].Reason);
    Assert.IsEmpty(lPlan.ContextFingerprint);
  end;
  for lStatus in ['blocked', 'failed'] do
  begin
    lPlan := RuntimePolicyPlan;
    lPlan.Status := lStatus;
    lPlan.Diagnostic := lStatus + ': independent refusal';
    SetLength(lPlan.UnresolvedReferences, 2);
    lPlan.UnresolvedReferences[1].Reason := 'independent-hard-refusal';
    ApplyRenameRuntimeNameRiskPolicy(lContext, False, lPlan);
    Assert.AreEqual(2, Integer(Length(lPlan.UnresolvedReferences)));
    Assert.AreEqual(0, Integer(Length(lPlan.RuntimeNameWarnings)));
    ApplyRenameRuntimeNameRiskPolicy(lContext, True, lPlan);
    Assert.IsTrue(lPlan.AcceptRuntimeNameRisk);
    Assert.AreEqual(lStatus, lPlan.Status);
    Assert.AreEqual(lStatus + ': independent refusal', lPlan.Diagnostic);
    Assert.AreEqual(1, Integer(Length(lPlan.UnresolvedReferences)));
    Assert.AreEqual('independent-hard-refusal', lPlan.UnresolvedReferences[0].Reason);
    Assert.AreEqual(1, Integer(Length(lPlan.RuntimeNameWarnings)));
    Assert.AreEqual('runtime-name-call-effect-unproved', lPlan.RuntimeNameWarnings[0].Reason);
    Assert.AreEqual(1, Integer(Length(lPlan.Edits)));
    Assert.AreEqual('NewName', lPlan.Edits[0].NewText);
    Assert.IsEmpty(lPlan.ContextFingerprint);
    Assert.AreEqual(0, Integer(Length(lPlan.RequiredVerification)));
    ApplyRenameRuntimeNameRiskPolicy(lContext, True, lPlan);
    Assert.AreEqual(lStatus, lPlan.Status);
    Assert.AreEqual(1, Integer(Length(lPlan.UnresolvedReferences)));
    Assert.AreEqual(1, Integer(Length(lPlan.RuntimeNameWarnings)));
    Assert.IsEmpty(lPlan.ContextFingerprint);
    ApplyRenameRuntimeNameRiskPolicy(lContext, False, lPlan);
    Assert.AreEqual(lStatus, lPlan.Status);
    Assert.IsFalse(lPlan.AcceptRuntimeNameRisk);
    Assert.AreEqual(2, Integer(Length(lPlan.UnresolvedReferences)));
    Assert.AreEqual(0, Integer(Length(lPlan.RuntimeNameWarnings)));
    Assert.IsEmpty(lPlan.ContextFingerprint);
  end;
end;

procedure TNameFlowContainmentTests.RiskWarningsChangeFingerprint;
var
  lFirst, lSecond: TDelphiSemanticRenamePlan;
  lContext: TDelphiSemanticSymbolQueryContext;
  lFingerprint: string;
begin
  lContext := Default(TDelphiSemanticSymbolQueryContext);
  lFirst := RuntimePolicyPlan;
  lSecond := lFirst;
  lSecond.UnresolvedReferences := Copy(lFirst.UnresolvedReferences);
  lSecond.UnresolvedReferences[0].Reason := 'runtime-name-metadata-consumer';
  ApplyRenameRuntimeNameRiskPolicy(lContext, True, lFirst);
  ApplyRenameRuntimeNameRiskPolicy(lContext, True, lSecond);
  Assert.AreNotEqual(lFirst.ContextFingerprint, lSecond.ContextFingerprint);
  lFingerprint := lFirst.ContextFingerprint;
  ApplyRenameRuntimeNameRiskPolicy(lContext, True, lFirst);
  Assert.AreEqual(lFingerprint, lFirst.ContextFingerprint, 'Policy is idempotent');
  ApplyRenameRuntimeNameRiskPolicy(lContext, False, lFirst);
  Assert.AreEqual('incomplete', lFirst.Status, 'Consent withdrawal restores refusal');
  Assert.AreEqual(1, Integer(Length(lFirst.UnresolvedReferences)));
end;

procedure TNameFlowContainmentTests.RuntimeRiskCategoriesAreExplicit;
var
  lReason: string;
begin
  for lReason in ['runtime-name-metadata-consumer', 'runtime-name-value-unproved',
    'runtime-name-call-effect-unproved', 'runtime-name-flow-configuration-unproved',
    'runtime-name-flow-coverage-unproved', 'runtime-name-flow-budget-exceeded',
    'string-constant-value-unproved'] do
    Assert.IsNotEmpty(RuntimeNameRiskCategory(lReason), lReason);
  Assert.IsEmpty(RuntimeNameRiskCategory('runtime-name-known-consumer-unknown'));
  Assert.IsEmpty(RuntimeNameRiskCategory('new-unreviewed-reason'));
end;

procedure TNameFlowContainmentTests.PositiveConsumerDescriptionsRespectTargetKinds;
var
  lEffect: TNameSdkEffect;
begin
  Assert.IsTrue(PositivePrimitiveNameConsumer('System.Rtti.TRttiType.GetField', lEffect));
  Assert.AreEqual(1, lEffect.Precision.FormalOrdinal);
  Assert.IsTrue(TNameEffectTargetKind.Member in lEffect.Targets);
  Assert.IsFalse(TNameEffectTargetKind.ClassType in lEffect.Targets);
  Assert.IsFalse(PositivePrimitiveNameConsumer('System.TObject.ClassName', lEffect),
    'A producer alone has no known name argument');
  Assert.IsFalse(PositivePrimitiveNameConsumer('UCustom.TRttiType.GetField', lEffect),
    'A same-spelled project method is not an SDK consumer');
end;

procedure TNameFlowContainmentTests.OpaqueSpellingDoesNotBecomeKnownConsumer;
var
  lSnapshot: TDelphiProjectSnapshot;
  lReport: TNameFlowAnalysis;
  lGap: TDelphiSemanticUsage;
begin
  lSnapshot := SnapshotWithNode(TDelphiNameFlowNodeKind.Call, 'call', 'GetField');
  try
    lReport := AnalyzeNameFlowSnapshot(lSnapshot, TNameEffectTargetKind.Member, nil,
      ['Count', 'Amount']);
    for lGap in lReport.Gaps do
      Assert.IsFalse(lGap.Reason.StartsWith('runtime-name-known-consumer-'),
        'Unbound spelling never supplies a hard consumer identity');
  finally
    lSnapshot.Free;
  end;
end;

procedure TNameFlowContainmentTests.PinnedConsumerFamiliesDescribeNameOrdinals;
var
  lEffect: TNameSdkEffect;
  lName: string;
begin
  for lName in ['System.Classes.GetClass', 'System.Classes.FindClass',
    'System.Classes.TComponent.FindComponent', 'System.TObject.MethodAddress',
    'System.TObject.FieldAddress', 'System.TObject.ClassNameIs'] do
  begin
    Assert.IsTrue(PositivePrimitiveNameConsumer(lName, lEffect), lName);
    Assert.AreEqual(1, lEffect.Precision.FormalOrdinal, lName);
  end;
  for lName in ['GetPropInfo', 'IsPublishedProp', 'GetPropValue', 'SetPropValue',
    'GetOrdProp', 'SetOrdProp', 'GetStrProp', 'SetStrProp', 'GetMethodProp', 'SetMethodProp'] do
  begin
    Assert.IsTrue(PositivePrimitiveNameConsumer('System.TypInfo.' + lName, lEffect), lName);
    Assert.AreEqual(2, lEffect.Precision.FormalOrdinal, lName);
    Assert.IsTrue(TNameEffectTargetKind.Member in lEffect.Targets, lName);
    Assert.IsFalse(TNameEffectTargetKind.ClassType in lEffect.Targets, lName);
  end;
  Assert.IsTrue(PositivePrimitiveNameConsumer('Winapi.Windows.GetProcAddress', lEffect));
  Assert.AreEqual(2, lEffect.Precision.FormalOrdinal);
  Assert.IsTrue(TNameEffectTargetKind.Routine in lEffect.Targets);
  Assert.IsFalse(PositivePrimitiveNameConsumer('UCustom.GetPropValue', lEffect));
end;

procedure TNameFlowContainmentTests.RiskPromotionPreservesOrdinarySnapshotCollision;
var
  lBuilder: TDelphiProjectSnapshotBuilder;
  lUnit: TUnitSnapshot;
  lSymbol: TSemanticSymbolFact;
  lSnapshot: TDelphiProjectSnapshot;
  lContext: TDelphiSemanticSymbolQueryContext;
  lPlan: TDelphiSemanticRenamePlan;
begin
  lBuilder := TDelphiProjectSnapshotBuilder.Create;
  try
    lUnit := TUnitSnapshot.Create(1, lBuilder.Strings.Intern('collision.pas'),
      lBuilder.Strings.Intern('Collision'), lBuilder.ExactStrings.Intern(''));
    lSymbol := Default(TSemanticSymbolFact);
    lSymbol.NameId := lBuilder.Strings.Intern('NewName');
    lSymbol.KindId := lBuilder.Strings.Intern('var');
    lUnit.AddSymbol(lSymbol);
    // No containment-declaration reference exists for this ordinary symbol.
    lBuilder.AddUnit(lUnit);
    lSnapshot := lBuilder.Build;
  finally
    lBuilder.Free;
  end;
  lContext := Default(TDelphiSemanticSymbolQueryContext);
  try
    lContext.ProjectSnapshot := BorrowProjectSnapshot(lSnapshot);
    lPlan := RuntimePolicyPlan;
    ApplyRenameRuntimeNameRiskPolicy(lContext, True, lPlan);
    Assert.AreEqual('blocked', lPlan.Status, lPlan.Diagnostic);
    Assert.IsEmpty(lPlan.ContextFingerprint);
    Assert.AreEqual(0, Integer(Length(lPlan.UnresolvedReferences)));
    Assert.AreEqual(1, Integer(Length(lPlan.RuntimeNameWarnings)));
  finally
    lContext.ProjectSnapshot := nil;
    lSnapshot.Free;
  end;
end;

procedure TNameFlowContainmentTests.KnownConsumerSurvivesUnrelatedReviewedPinMismatch;
var
  lRequest: TNameSdkGenerationRequest;
  lCatalog: TNameSdkCatalog;
  lBuilder: TDelphiProjectSnapshotBuilder;
  lUnit: TUnitSnapshot;
  lSnapshot: TDelphiProjectSnapshot;
  lSymbol: TSemanticSymbolFact;
  lImport: TDelphiSemanticImportFact;
  lNodes: TArray<TDelphiNameFlowNode>;
  lReport: TNameFlowAnalysis;
  lGap: TDelphiSemanticUsage;
  lRoot, lSdkSource: string;
  lFound: Boolean;
  i: Integer;
begin
  lRoot := CreateTestTempRoot('nameflow-reviewed-pin-mismatch-temp');
  lSdkSource := TPath.Combine(GetEnvironmentVariable('ProgramFiles(x86)'),
    'Embarcadero\Studio\23.0\source\rtl\common\System.Rtti.pas');
  Assert.IsTrue(TFile.Exists(lSdkSource), 'The reviewed Delphi23 source is required');
  TFile.Copy(lSdkSource, TPath.Combine(lRoot, 'System.Rtti.pas'));
  lRequest := Default(TNameSdkGenerationRequest);
  lRequest.SdkRoot := lRoot;
  lRequest.CompilerFileName := ParamStr(0);
  lRequest.CompilerVersion := 'test-identity';
  lRequest.Platform := 'Win64';
  lRequest.Configuration := 'Debug';
  lRequest.ExpectedSourceIdentity := StringOfChar('0', 64);
  lRequest.ExpectedCompilerHash := THashSHA2.GetHashStringFromFile(ParamStr(0));
  SetLength(lRequest.UnitOptions, 1);
  lRequest.UnitOptions[0].SourceFileName := TPath.Combine(lRoot, 'System.Rtti.pas');
  lCatalog := TNameSdkCatalog.Create(lRequest);
  try
    lCatalog.Generate;
    Assert.IsFalse(lCatalog.Validated);
    Assert.AreEqual(0, Integer(Length(lCatalog.SourceCoverage)));
    Assert.IsTrue(lCatalog.InputsUnchangedSinceAnalysis);
    lBuilder := TDelphiProjectSnapshotBuilder.Create;
    try
      lUnit := TUnitSnapshot.Create(1, lBuilder.Strings.Intern('probe.pas'),
        lBuilder.Strings.Intern('Probe'), lBuilder.ExactStrings.Intern('begin lContext.FindType(aName); end.'));
      lImport := Default(TDelphiSemanticImportFact);
      lImport.Name := 'System.Rtti';
      lImport.SdkBoundary := True;
      lUnit.SetImportFacts([lImport]);
      lSymbol := Default(TSemanticSymbolFact);
      lSymbol.NameId := lBuilder.Strings.Intern('lContext');
      lSymbol.KindId := lBuilder.Strings.Intern('var');
      lSymbol.TypeId := lBuilder.Strings.Intern('TRttiContext');
      lSymbol.RoutineScopeId := lBuilder.Strings.Intern('probe');
      lSymbol.Line := 1;
      lUnit.AddSymbol(lSymbol);
      SetLength(lNodes, 7);
      for i := 0 to High(lNodes) do
      begin
        lNodes[i].Id := i + 1;
        lNodes[i].FileName := 'probe.pas';
        lNodes[i].Line := 1;
        lNodes[i].Column := i + 1;
        lNodes[i].ScopeId := 'probe';
        lNodes[i].SpanKnown := True;
        lNodes[i].ActivityKnown := True;
      end;
      lNodes[0].Kind := TDelphiNameFlowNodeKind.Call;
      lNodes[0].SyntaxKind := 'call';
      lNodes[0].Children := [2, 5];
      lNodes[1].SyntaxKind := 'dot';
      lNodes[1].ParentId := 1;
      lNodes[1].Children := [3, 4];
      lNodes[2].Kind := TDelphiNameFlowNodeKind.PotentialCall;
      lNodes[2].SyntaxKind := 'identifier';
      lNodes[2].Name := 'lContext';
      lNodes[2].ParentId := 2;
      lNodes[3].Kind := TDelphiNameFlowNodeKind.PotentialCall;
      lNodes[3].SyntaxKind := 'identifier';
      lNodes[3].Name := 'FindType';
      lNodes[3].ParentId := 2;
      lNodes[4].SyntaxKind := 'expressions';
      lNodes[4].ParentId := 1;
      lNodes[4].Children := [6];
      lNodes[5].SyntaxKind := 'expression';
      lNodes[5].ParentId := 5;
      lNodes[5].Children := [7];
      lNodes[6].Kind := TDelphiNameFlowNodeKind.PotentialCall;
      lNodes[6].SyntaxKind := 'identifier';
      lNodes[6].Name := 'aName';
      lNodes[6].ParentId := 6;
      lUnit.SetNameFlowFactsJsonId(lBuilder.ExactStrings.Intern(NameFlowFactsToJson(
        CreateNameFlowFacts(lNodes, True, True, ''))));
      lBuilder.AddUnit(lUnit);
      lSnapshot := lBuilder.Build;
    finally
      lBuilder.Free;
    end;
    try
      lReport := AnalyzeNameFlowSnapshot(lSnapshot, TNameEffectTargetKind.ClassType,
        lCatalog, ['OldName', 'NewName']);
      lFound := False;
      for lGap in lReport.Gaps do
        lFound := lFound or (lGap.Reason = 'runtime-name-known-consumer-unknown');
      Assert.IsTrue(lFound, 'Aggregate pin mismatch must never erase a pinned positive consumer');
    finally
      lSnapshot.Free;
    end;
  finally
    lCatalog.Free;
  end;
end;

procedure TNameFlowContainmentTests.SetSetPropEnumNameArgumentRemainsHard;
var
  lRequest: TNameSdkGenerationRequest;
  lCatalog: TNameSdkCatalog;
  lBuilder: TDelphiProjectSnapshotBuilder;
  lUnit: TUnitSnapshot;
  lSnapshot: TDelphiProjectSnapshot;
  lImport: TDelphiSemanticImportFact;
  lNodes: TArray<TDelphiNameFlowNode>;
  lReport: TNameFlowAnalysis;
  lPlan: TDelphiSemanticRenamePlan;
  lContext: TDelphiSemanticSymbolQueryContext;
  lRoot, lSdkSource: string;
  lFound: Boolean;
  lGap: TDelphiSemanticUsage;
  i: Integer;
begin
  lRoot := CreateTestTempRoot('nameflow-setsetprop-temp');
  lSdkSource := TPath.Combine(GetEnvironmentVariable('ProgramFiles(x86)'),
    'Embarcadero\Studio\23.0\source\rtl\common\System.TypInfo.pas');
  Assert.IsTrue(TFile.Exists(lSdkSource), 'The reviewed Delphi23 source is required');
  TFile.Copy(lSdkSource, TPath.Combine(lRoot, 'System.TypInfo.pas'));
  lRequest := Default(TNameSdkGenerationRequest);
  lRequest.SdkRoot := lRoot;
  lRequest.CompilerFileName := ParamStr(0);
  lRequest.CompilerVersion := 'test-identity';
  lRequest.Platform := 'Win64';
  lRequest.Configuration := 'Debug';
  lRequest.ExpectedSourceIdentity := StringOfChar('0', 64);
  lRequest.ExpectedCompilerHash := THashSHA2.GetHashStringFromFile(ParamStr(0));
  SetLength(lRequest.UnitOptions, 1);
  lRequest.UnitOptions[0].SourceFileName := TPath.Combine(lRoot, 'System.TypInfo.pas');
  lCatalog := TNameSdkCatalog.Create(lRequest);
  try
    lCatalog.Generate;
    lBuilder := TDelphiProjectSnapshotBuilder.Create;
    try
      lUnit := TUnitSnapshot.Create(1, lBuilder.Strings.Intern('probe.pas'),
        lBuilder.Strings.Intern('Probe'), lBuilder.ExactStrings.Intern('begin TypInfo.SetSetProp(obj, Other, aNames); end.'));
      lImport := Default(TDelphiSemanticImportFact);
      lImport.Name := 'System.TypInfo';
      lImport.SdkBoundary := True;
      lUnit.SetImportFacts([lImport]);
      SetLength(lNodes, 8);
      for i := 0 to High(lNodes) do
      begin
        lNodes[i].Id := i + 1;
        lNodes[i].FileName := 'probe.pas';
        lNodes[i].Line := 1;
        lNodes[i].Column := i + 1;
        lNodes[i].SpanKnown := True;
        lNodes[i].ActivityKnown := True;
      end;
      lNodes[0].Kind := TDelphiNameFlowNodeKind.Call;
      lNodes[0].SyntaxKind := 'call';
      lNodes[0].Children := [2, 3];
      lNodes[1].SyntaxKind := 'dot';
      lNodes[1].ParentId := 1;
      lNodes[1].Children := [4, 5];
      lNodes[2].SyntaxKind := 'expressions';
      lNodes[2].ParentId := 1;
      lNodes[2].Children := [6, 7, 8];
      lNodes[3].Kind := TDelphiNameFlowNodeKind.PotentialCall;
      lNodes[3].SyntaxKind := 'identifier';
      lNodes[3].Name := 'TypInfo';
      lNodes[3].ParentId := 2;
      lNodes[4].Kind := TDelphiNameFlowNodeKind.PotentialCall;
      lNodes[4].SyntaxKind := 'identifier';
      lNodes[4].Name := 'SetSetProp';
      lNodes[4].ParentId := 2;
      lNodes[5].SyntaxKind := 'identifier';
      lNodes[5].Name := 'obj';
      lNodes[5].ParentId := 3;
      lNodes[6].SyntaxKind := 'literal';
      lNodes[6].Value := 'Other';
      lNodes[6].ParentId := 3;
      lNodes[7].SyntaxKind := 'identifier';
      lNodes[7].Name := 'aNames';
      lNodes[7].ParentId := 3;
      lUnit.SetNameFlowFactsJsonId(lBuilder.ExactStrings.Intern(NameFlowFactsToJson(
        CreateNameFlowFacts(lNodes, True, True, ''))));
      lBuilder.AddUnit(lUnit);
      lSnapshot := lBuilder.Build;
    finally
      lBuilder.Free;
    end;
    try
      lReport := AnalyzeNameFlowSnapshot(lSnapshot, TNameEffectTargetKind.EnumElement,
        lCatalog, ['First', 'RenamedFirst']);
      lFound := False;
      for lGap in lReport.Gaps do
        lFound := lFound or (lGap.Reason = 'runtime-name-known-consumer-unknown');
      Assert.IsTrue(lFound, 'SetSetProp consumes the enum set names at formal three');
      lContext := Default(TDelphiSemanticSymbolQueryContext);
      lPlan := RuntimePolicyPlan;
      lPlan.UnresolvedReferences := lReport.Gaps;
      ApplyRenameRuntimeNameRiskPolicy(lContext, True, lPlan);
      Assert.AreEqual('incomplete', lPlan.Status);
      Assert.IsEmpty(lPlan.ContextFingerprint);
    finally
      lSnapshot.Free;
    end;
  finally
    lCatalog.Free;
  end;
end;

function KnownNameValueReport(const aRoutineName, aValue: string;
  const aTargetKind: TNameEffectTargetKind; const aNames: TArray<string>): TNameFlowAnalysis;
var
  lRequest: TNameSdkGenerationRequest;
  lCatalog: TNameSdkCatalog;
  lBuilder: TDelphiProjectSnapshotBuilder;
  lUnit: TUnitSnapshot;
  lSnapshot: TDelphiProjectSnapshot;
  lImport: TDelphiSemanticImportFact;
  lSymbol: TSemanticSymbolFact;
  lNodes: TArray<TDelphiNameFlowNode>;
  lRoot, lSourceName, lSdkSource, lReceiverName: string;
  lOrdinal, lIndex, lExpressionIndex: Integer;
  i: Integer;
begin
  lRoot := CreateTestTempRoot('nameflow-consumer-grammar-temp');
  if aRoutineName = 'FindType' then
  begin
    lSourceName := 'System.Rtti';
    lOrdinal := 1;
    lReceiverName := 'lContext';
    lSdkSource := 'rtl\common\System.Rtti.pas';
  end else if aRoutineName = 'GetProcAddress' then
  begin
    lSourceName := 'Winapi.Windows';
    lOrdinal := 2;
    lReceiverName := 'Windows';
    lSdkSource := 'rtl\win\Winapi.Windows.pas';
  end else begin
    lSourceName := 'System.TypInfo';
    lOrdinal := 3;
    lReceiverName := 'TypInfo';
    lSdkSource := 'rtl\common\System.TypInfo.pas';
  end;
  lSdkSource := TPath.Combine(GetEnvironmentVariable('ProgramFiles(x86)'),
    'Embarcadero\Studio\23.0\source\' + lSdkSource);
  Assert.IsTrue(TFile.Exists(lSdkSource), 'The reviewed Delphi23 source is required');
  TFile.Copy(lSdkSource, TPath.Combine(lRoot, lSourceName + '.pas'));
  lRequest := Default(TNameSdkGenerationRequest);
  lRequest.SdkRoot := lRoot;
  lRequest.CompilerFileName := ParamStr(0);
  lRequest.CompilerVersion := 'test-identity';
  lRequest.Platform := 'Win64';
  lRequest.Configuration := 'Debug';
  lRequest.ExpectedSourceIdentity := StringOfChar('0', 64);
  lRequest.ExpectedCompilerHash := THashSHA2.GetHashStringFromFile(ParamStr(0));
  SetLength(lRequest.UnitOptions, 1);
  lRequest.UnitOptions[0].SourceFileName := TPath.Combine(lRoot, lSourceName + '.pas');
  lCatalog := TNameSdkCatalog.Create(lRequest);
  try
    lCatalog.Generate;
    lBuilder := TDelphiProjectSnapshotBuilder.Create;
    try
      lUnit := TUnitSnapshot.Create(1, lBuilder.Strings.Intern('probe.pas'),
        lBuilder.Strings.Intern('Probe'), lBuilder.ExactStrings.Intern('begin KnownConsumer(Name); end.'));
      lImport := Default(TDelphiSemanticImportFact);
      lImport.Name := lSourceName;
      lImport.SdkBoundary := True;
      lUnit.SetImportFacts([lImport]);
      if aRoutineName = 'FindType' then
      begin
        lSymbol := Default(TSemanticSymbolFact);
        lSymbol.NameId := lBuilder.Strings.Intern(lReceiverName);
        lSymbol.KindId := lBuilder.Strings.Intern('var');
        lSymbol.TypeId := lBuilder.Strings.Intern('TRttiContext');
        lSymbol.RoutineScopeId := lBuilder.Strings.Intern('probe');
        lSymbol.Line := 1;
        lUnit.AddSymbol(lSymbol);
      end;
      SetLength(lNodes, 5 + 2 * lOrdinal);
      for i := 0 to High(lNodes) do
      begin
        lNodes[i].Id := i + 1;
        lNodes[i].FileName := 'probe.pas';
        lNodes[i].Line := 1;
        lNodes[i].Column := i + 1;
        lNodes[i].ScopeId := 'probe';
        lNodes[i].SpanKnown := True;
        lNodes[i].ActivityKnown := True;
      end;
      lNodes[0].Kind := TDelphiNameFlowNodeKind.Call;
      lNodes[0].SyntaxKind := 'call';
      lNodes[0].Children := [2, 3];
      lNodes[1].SyntaxKind := 'dot';
      lNodes[1].ParentId := 1;
      lNodes[1].Children := [4, 5];
      lNodes[2].SyntaxKind := 'expressions';
      lNodes[2].ParentId := 1;
      SetLength(lNodes[2].Children, lOrdinal);
      lNodes[3].Kind := TDelphiNameFlowNodeKind.PotentialCall;
      lNodes[3].SyntaxKind := 'identifier';
      lNodes[3].Name := lReceiverName;
      lNodes[3].ParentId := 2;
      lNodes[4].Kind := TDelphiNameFlowNodeKind.PotentialCall;
      lNodes[4].SyntaxKind := 'identifier';
      lNodes[4].Name := aRoutineName;
      lNodes[4].ParentId := 2;
      for lIndex := 0 to lOrdinal - 1 do
      begin
        lExpressionIndex := 5 + 2 * lIndex;
        lNodes[2].Children[lIndex] := lExpressionIndex + 1;
        lNodes[lExpressionIndex].SyntaxKind := 'expression';
        lNodes[lExpressionIndex].ParentId := 3;
        lNodes[lExpressionIndex].Children := [lExpressionIndex + 2];
        lNodes[lExpressionIndex + 1].SyntaxKind := 'literal';
        lNodes[lExpressionIndex + 1].ParentId := lExpressionIndex + 1;
        if lIndex = lOrdinal - 1 then
          lNodes[lExpressionIndex + 1].Value := aValue
        else
          lNodes[lExpressionIndex + 1].Value := 'Other';
      end;
      lUnit.SetNameFlowFactsJsonId(lBuilder.ExactStrings.Intern(NameFlowFactsToJson(
        CreateNameFlowFacts(lNodes, True, True, ''))));
      lBuilder.AddUnit(lUnit);
      lSnapshot := lBuilder.Build;
    finally
      lBuilder.Free;
    end;
    try
      Result := AnalyzeNameFlowSnapshot(lSnapshot, aTargetKind, lCatalog, aNames);
    finally
      lSnapshot.Free;
    end;
  finally
    lCatalog.Free;
  end;
end;

function HasKnownConsumerReason(const aReport: TNameFlowAnalysis; const aReason: string): Boolean;
var
  lGap: TDelphiSemanticUsage;
begin
  Result := False;
  for lGap in aReport.Gaps do
    if lGap.Reason = aReason then
      Exit(True);
end;

procedure TNameFlowContainmentTests.UnsupportedQualifiedNameGrammarRemainsHard;
var
  lReport: TNameFlowAnalysis;
  lValue: string;
begin
  for lValue in ['UCertified.TC<System.Integer>', 'TC<System.Integer>', 'U..TC',
    ' U.TC', '', '.TC', 'U.TC.'] do
  begin
    lReport := KnownNameValueReport('FindType', lValue, TNameEffectTargetKind.ClassType, ['TC', 'TD']);
    Assert.IsTrue(HasKnownConsumerReason(lReport, 'runtime-name-known-consumer-unknown'), lValue);
  end;
end;

procedure TNameFlowContainmentTests.CompoundEnumNameGrammarRemainsHard;
var
  lReport: TNameFlowAnalysis;
  lRoutineName, lValue: string;
begin
  for lRoutineName in ['SetEnumProp', 'SetSetProp'] do
    for lValue in ['First,Other', '[First,Other]', 'Other,RenamedFirst', '[Other,RenamedFirst]'] do
    begin
      lReport := KnownNameValueReport(lRoutineName, lValue,
        TNameEffectTargetKind.EnumElement, ['First', 'RenamedFirst']);
      Assert.IsTrue(HasKnownConsumerReason(lReport, 'runtime-name-known-consumer-unknown'),
        lRoutineName + ': ' + lValue);
    end;
end;

procedure TNameFlowContainmentTests.SimpleQualifiedNameGrammarKeepsPrecision;
var
  lReport: TNameFlowAnalysis;
begin
  lReport := KnownNameValueReport('FindType', 'UCertified.TC',
    TNameEffectTargetKind.ClassType, ['TC', 'TD']);
  Assert.IsTrue(HasKnownConsumerReason(lReport, 'runtime-name-known-consumer-match'));
  lReport := KnownNameValueReport('FindType', 'UCertified.TOther',
    TNameEffectTargetKind.ClassType, ['TC', 'TD']);
  Assert.IsFalse(HasKnownConsumerReason(lReport, 'runtime-name-known-consumer-match'));
  Assert.IsFalse(HasKnownConsumerReason(lReport, 'runtime-name-known-consumer-unknown'));
end;

procedure TNameFlowContainmentTests.ExportNameRequiresWholeValueOrUnknown;
var
  lReport: TNameFlowAnalysis;
begin
  lReport := KnownNameValueReport('GetProcAddress', 'Count',
    TNameEffectTargetKind.Routine, ['Count', 'Tally']);
  Assert.IsTrue(HasKnownConsumerReason(lReport, 'runtime-name-known-consumer-match'));
  lReport := KnownNameValueReport('GetProcAddress', 'Module.Count',
    TNameEffectTargetKind.Routine, ['Count', 'Tally']);
  Assert.IsTrue(HasKnownConsumerReason(lReport, 'runtime-name-known-consumer-unknown'));
  Assert.IsFalse(HasKnownConsumerReason(lReport, 'runtime-name-known-consumer-match'));
  lReport := KnownNameValueReport('GetProcAddress', 'Other',
    TNameEffectTargetKind.Routine, ['Count', 'Tally']);
  Assert.IsTrue(HasKnownConsumerReason(lReport, 'runtime-name-known-consumer-unknown'));
end;

function ActualShadowNameReport(const aScenario: string): TNameFlowAnalysis;
const
  cCall = '  if lContext.GetType(TC).GetField(LookupName) <> nil then'#13#10 +
    '    WriteLn(''found'');'#13#10;
var
  lRoot, lSdkRoot, lSdkSource, lFileName, lSource, lDeclaration, lBody, lCall: string;
  lOptions: TDelphiSemanticModelOptions;
  lModel: TDelphiSemanticUnitModel;
  lModels: TArray<TDelphiSemanticUnitModel>;
  lMetrics: TDelphiSnapshotBuilderMetrics;
  lSnapshot: TDelphiProjectSnapshot;
  lRequest: TNameSdkGenerationRequest;
  lCatalog: TNameSdkCatalog;
begin
  lRoot := CreateTestTempRoot('nameflow-actual-shadow-temp');
  lSdkRoot := TPath.Combine(lRoot, 'sdk');
  lSdkSource := TPath.Combine(lSdkRoot, 'source');
  TDirectory.CreateDirectory(lSdkSource);
  TFile.Copy(TPath.Combine(GetEnvironmentVariable('ProgramFiles(x86)'),
    'Embarcadero\Studio\23.0\source\rtl\common\System.Rtti.pas'),
    TPath.Combine(lSdkSource, 'System.Rtti.pas'));
  if MatchText(aScenario, ['same-line', 'with-lean', 'lean-match']) then
    TFile.Copy(TPath.Combine(GetEnvironmentVariable('ProgramFiles(x86)'),
      'Embarcadero\Studio\23.0\source\rtl\common\System.TypInfo.pas'),
      TPath.Combine(lSdkSource, 'System.TypInfo.pas'));
  lCall := cCall;
  if MatchText(aScenario, ['same-line', 'with-lean', 'lean-match']) then
    lCall := '  if GetPropInfo(TC, LookupName) <> nil then WriteLn(''found'');'#13#10;
  if StartsText('standalone-', aScenario) then
    lCall := '  lContext.GetType(TC).GetField(LookupName);'#13#10;
  lDeclaration := 'const LookupName = ''Other'';'#13#10;
  if MatchText(aScenario, ['match', 'standalone-match', 'lean-match']) then
    lDeclaration := 'const LookupName = ''Count'';'#13#10
  else if aScenario = 'resourcestring' then
    lDeclaration := 'resourcestring LookupName = ''Other'';'#13#10
  else if aScenario = 'typed-const' then
    lDeclaration := 'const LookupName: string = ''Other'';'#13#10;
  if MatchText(aScenario, ['parameter', 'standalone-parameter']) then
    lBody := 'procedure ReadName(const LookupName: string);'#13#10 +
      'var lContext: TRttiContext;'#13#10'begin'#13#10 + lCall + 'end;'#13#10 +
      'procedure Touch;'#13#10'begin'#13#10'  ReadName(ParamStr(1));'#13#10'end;'#13#10
  else if aScenario = 'same-line' then
    lBody := 'procedure First; const LookupName = ''Other''; begin WriteLn(LookupName); end; ' +
      'procedure Touch; const LookupName = ''Count''; var lContext: TRttiContext; begin'#13#10 +
      lCall + 'end;'#13#10
  else if MatchText(aScenario, ['with', 'with-lean']) then
    lBody := 'procedure Touch;'#13#10'var lContext: TRttiContext; lHolder: TNameHolder;'#13#10 +
      'begin'#13#10'  with lHolder do'#13#10'  begin'#13#10 + lCall + '  end;'#13#10'end;'#13#10
  else if aScenario = 'local-var' then
    lBody := 'procedure Touch;'#13#10'var lContext: TRttiContext;'#13#10 +
      '  LookupName: string;'#13#10'begin'#13#10'  LookupName := ParamStr(1);'#13#10 + lCall + 'end;'#13#10
  else if aScenario = 'nested' then
    lBody := 'procedure ReadName(const LookupName: string);'#13#10 +
      '  procedure Inner;'#13#10'  var lContext: TRttiContext;'#13#10'  begin'#13#10 + lCall +
      '  end;'#13#10'begin'#13#10'  Inner;'#13#10'end;'#13#10 +
      'procedure Touch;'#13#10'begin'#13#10'  ReadName(ParamStr(1));'#13#10'end;'#13#10
  else if aScenario = 'typed-const' then
    lBody := 'procedure Touch;'#13#10'var lContext: TRttiContext;'#13#10'begin'#13#10 +
      '  LookupName := ParamStr(1);'#13#10 + lCall + 'end;'#13#10
  else
    lBody := 'procedure Touch;'#13#10'var lContext: TRttiContext;'#13#10'begin'#13#10 + lCall + 'end;'#13#10;
  lSource := 'unit UProbe;'#13#10'interface'#13#10 +
    'type TC = class Count: Integer; end;'#13#10 + lDeclaration +
    'procedure Touch;'#13#10'implementation'#13#10'uses System.Rtti;'#13#10 + lBody + 'end.';
  if MatchText(aScenario, ['same-line', 'with-lean', 'lean-match']) then
    lSource := StringReplace(lSource, 'uses System.Rtti;', 'uses System.Rtti, System.TypInfo;', []);
  if MatchText(aScenario, ['with', 'with-lean']) then
  begin
    lSource := StringReplace(lSource, 'uses System.Rtti', 'uses System.Rtti, UNames', []);
    TFile.WriteAllText(TPath.Combine(lRoot, 'UNames.pas'),
      'unit UNames; interface type TNameHolder = class LookupName: string; end; implementation end.',
      TEncoding.ASCII);
  end;
  lFileName := TPath.Combine(lRoot, 'UProbe.pas');
  TFile.WriteAllText(lFileName, lSource, TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lFileName;
  lOptions.SearchPaths := [lRoot, lSdkSource];
  lOptions.InstalledSdkRoot := lSdkRoot;
  lOptions.ProjectContextApplied := True;
  lOptions.DefineEvidenceComplete := True;
  lOptions.WritableTypedConstants := True;
  lOptions.SkipBodyAnalysis := MatchText(aScenario, ['with-lean', 'lean-match']);
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success, 'The actual shadow fixture must extract successfully: ' + aScenario);
  lModels := [lModel];
  if MatchText(aScenario, ['with', 'with-lean']) then
  begin
    lOptions.SourceFileName := TPath.Combine(lRoot, 'UNames.pas');
    SetLength(lModels, 2);
    lModels[1] := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
    Assert.IsTrue(lModels[1].Success, 'The external WITH holder must extract');
  end;
  lSnapshot := BuildProjectSnapshotFromModels(lModels,
    Default(TDelphiSemanticProjectWithBindingFacts), Default(TDelphiSnapshotBuildOptions), lMetrics);
  lRequest := Default(TNameSdkGenerationRequest);
  lRequest.SdkRoot := lSdkSource;
  lRequest.CompilerFileName := ParamStr(0);
  lRequest.CompilerVersion := 'test-identity';
  lRequest.Platform := 'Win64';
  lRequest.Configuration := 'Debug';
  lRequest.ExpectedSourceIdentity := StringOfChar('0', 64);
  lRequest.ExpectedCompilerHash := THashSHA2.GetHashStringFromFile(ParamStr(0));
  SetLength(lRequest.UnitOptions, 1);
  lRequest.UnitOptions[0].SourceFileName := TPath.Combine(lSdkSource, 'System.Rtti.pas');
  if MatchText(aScenario, ['same-line', 'with-lean', 'lean-match']) then
  begin
    SetLength(lRequest.UnitOptions, 2);
    lRequest.UnitOptions[1].SourceFileName := TPath.Combine(lSdkSource, 'System.TypInfo.pas');
  end;
  lCatalog := TNameSdkCatalog.Create(lRequest);
  try
    lCatalog.Generate;
    Result := AnalyzeNameFlowSnapshot(lSnapshot, TNameEffectTargetKind.Member,
      lCatalog, ['Count', 'Tally']);
  finally
    lCatalog.Free;
    lSnapshot.Free;
  end;
end;

procedure TNameFlowContainmentTests.LeanPrimitiveMatchProvesKnownConsumerBinding;
var
  lReport: TNameFlowAnalysis;
begin
  lReport := ActualShadowNameReport('lean-match');
  Assert.IsTrue(HasKnownConsumerReason(lReport, 'runtime-name-known-consumer-match'));
end;

procedure TNameFlowContainmentTests.LeanActualWithCaptureRemainsUnknown;
var
  lReport: TNameFlowAnalysis;
begin
  lReport := ActualShadowNameReport('with-lean');
  Assert.IsTrue(HasKnownConsumerReason(lReport, 'runtime-name-known-consumer-unknown'));
end;

procedure TNameFlowContainmentTests.ActualWithCaptureDoesNotFoldUnitConstant;
var
  lReport: TNameFlowAnalysis;
begin
  lReport := ActualShadowNameReport('with');
  Assert.IsTrue(HasKnownConsumerReason(lReport, 'runtime-name-known-consumer-unknown'));
end;

procedure TNameFlowContainmentTests.SameLineLocalConstantCannotUseOtherInitializer;
var
  lReport: TNameFlowAnalysis;
begin
  lReport := ActualShadowNameReport('same-line');
  Assert.IsTrue(HasKnownConsumerReason(lReport, 'runtime-name-known-consumer-match') or
    HasKnownConsumerReason(lReport, 'runtime-name-known-consumer-unknown'));
end;

procedure TNameFlowContainmentTests.StandaloneConstantMatchProvesKnownConsumerBinding;
var
  lReport: TNameFlowAnalysis;
begin
  lReport := ActualShadowNameReport('standalone-match');
  Assert.IsTrue(HasKnownConsumerReason(lReport, 'runtime-name-known-consumer-match'));
end;

procedure TNameFlowContainmentTests.StandaloneParameterShadowRemainsUnknown;
var
  lReport: TNameFlowAnalysis;
begin
  lReport := ActualShadowNameReport('standalone-parameter');
  Assert.IsTrue(HasKnownConsumerReason(lReport, 'runtime-name-known-consumer-unknown'));
end;

procedure TNameFlowContainmentTests.ActualConstantMatchProvesKnownConsumerBinding;
var
  lReport: TNameFlowAnalysis;
begin
  lReport := ActualShadowNameReport('match');
  Assert.IsTrue(HasKnownConsumerReason(lReport, 'runtime-name-known-consumer-match'));
end;

procedure TNameFlowContainmentTests.UnshadowedActualConstantKeepsKnownNonmatch;
var
  lReport: TNameFlowAnalysis;
begin
  lReport := ActualShadowNameReport('unshadowed');
  Assert.IsFalse(HasKnownConsumerReason(lReport, 'runtime-name-known-consumer-unknown'));
  Assert.IsFalse(HasKnownConsumerReason(lReport, 'runtime-name-known-consumer-match'));
end;

procedure TNameFlowContainmentTests.ActualParameterShadowDoesNotFoldOuterConstant;
var
  lReport: TNameFlowAnalysis;
begin
  lReport := ActualShadowNameReport('parameter');
  Assert.IsTrue(HasKnownConsumerReason(lReport, 'runtime-name-known-consumer-unknown'));
end;

procedure TNameFlowContainmentTests.ActualLocalVariableShadowDoesNotFoldOuterConstant;
var
  lReport: TNameFlowAnalysis;
begin
  lReport := ActualShadowNameReport('local-var');
  Assert.IsTrue(HasKnownConsumerReason(lReport, 'runtime-name-known-consumer-unknown'));
end;

procedure TNameFlowContainmentTests.ActualNestedParameterShadowDoesNotFoldOuterConstant;
var
  lReport: TNameFlowAnalysis;
begin
  lReport := ActualShadowNameReport('nested');
  Assert.IsTrue(HasKnownConsumerReason(lReport, 'runtime-name-known-consumer-unknown'));
end;

procedure TNameFlowContainmentTests.ActualResourceStringValueRemainsUnknown;
var
  lReport: TNameFlowAnalysis;
begin
  lReport := ActualShadowNameReport('resourcestring');
  Assert.IsTrue(HasKnownConsumerReason(lReport, 'runtime-name-known-consumer-unknown'));
end;

procedure TNameFlowContainmentTests.ActualTypedConstantValueRemainsUnknown;
var
  lReport: TNameFlowAnalysis;
begin
  lReport := ActualShadowNameReport('typed-const');
  Assert.IsTrue(HasKnownConsumerReason(lReport, 'runtime-name-known-consumer-unknown'));
end;

initialization
  TDUnitX.RegisterTestFixture(TNameFlowContainmentTests);

end.
