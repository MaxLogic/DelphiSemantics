unit Test.SemanticGraph;

interface

uses
  DUnitX.TestFramework,
  DelphiSemantics.Model, DelphiSemantics.ProjectContext, DelphiSemantics.SemanticGraph;

type
  [TestFixture]
  TSemanticGraphTests = class
  private
    function ProjectInfo: TDelphiSemanticProjectInfo;
    function SymbolModel(const aUnitName, aFileName: string): TDelphiSemanticUnitModel;
  public
    [Category('Fast')]
    [Test]
    procedure ProjectAndUnitIdsAreStableForSameContextAndSources;
    [Category('Fast')]
    [Test]
    procedure UnitDtosExposeOriginalSourceRanges;
    [Category('Fast')]
    [Test]
    procedure UnitDtosAreReturnedAsCopies;
    [Category('Fast')]
    [Test]
    procedure CanonicalImportsPreserveSpellingAmbiguityAndBuildContext;
    [Test]
    procedure ProjectSessionBuildMetricsReportGraphCounts;
    [Category('Fast')]
    [Test]
    procedure CaptureProofReuseKeepsRawImportsAndInvalidatesChangedEvidence;
    [Category('Fast')]
    [Test]
    procedure CaptureRoutineCandidatesKeepFiltersOrderAndEveryReparentCheck;
    [Category('Fast')]
    [Test]
    procedure CaptureTypeHeadersKeepLexerStateAndConditionalUncertainty;
  end;

implementation

uses
  System.IOUtils, System.SysUtils,
  AutoFree, maxLogic.IOUtils,
  DelphiSemantics.Model.Extract, DelphiSemantics.ProjectSession, DelphiSemantics.Source,
  DelphiSemantics.SourceConditionals,
  Test.Support;


function TSemanticGraphTests.ProjectInfo: TDelphiSemanticProjectInfo;
var
  lOptions: TDelphiSemanticOptions;
  lResult: TDelphiSemanticContextResult;
begin
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := FixturePath('ProjectContext\Basic\BasicProject.dproj');
  lResult := TDelphiSemanticProject.Load(lOptions.ProjectPath, lOptions);
  Assert.IsTrue(lResult.Success);
  Result := lResult.Project;
end;

function TSemanticGraphTests.SymbolModel(const aUnitName, aFileName: string):
  TDelphiSemanticUnitModel;
begin
  Result := Default(TDelphiSemanticUnitModel);
  Result.Success := True;
  Result.UnitName := aUnitName;
  Result.FileName := aFileName;
  SetLength(Result.Declarations, 1);
  Result.Declarations[0].Name := 'TGraphRecord';
  Result.Declarations[0].Kind := 'type';
  Result.Declarations[0].Line := 2;
  Result.Declarations[0].Column := 3;
  Result.Declarations[0].Offset := 10;
  Result.Declarations[0].EndOffset := 23;
end;

procedure TSemanticGraphTests.ProjectAndUnitIdsAreStableForSameContextAndSources;
var
  lFirst: TDelphiSemanticSemanticGraph;
  lProject: TDelphiSemanticProjectInfo;
  lSecond: TDelphiSemanticSemanticGraph;
begin
  lProject := ProjectInfo;
  lFirst := TDelphiSemanticSemanticGraphBuilder.Build(lProject, [
    SymbolModel('BasicProject', lProject.MainSourceFileName)]);
  try
    lSecond := TDelphiSemanticSemanticGraphBuilder.Build(lProject, [
      SymbolModel('BasicProject', lProject.MainSourceFileName)]);
    try
      Assert.AreEqual(lFirst.ProjectId.Value, lSecond.ProjectId.Value);
      Assert.AreEqual(lFirst.Units[0].Id.Value, lSecond.Units[0].Id.Value);
    finally
      lSecond.Free;
    end;
  finally
    lFirst.Free;
  end;
end;

procedure TSemanticGraphTests.UnitDtosExposeOriginalSourceRanges;
var
  lGraph: TDelphiSemanticSemanticGraph;
  lProject: TDelphiSemanticProjectInfo;
  lUnit: TDelphiSemanticGraphUnit;
begin
  lProject := ProjectInfo;
  lGraph := TDelphiSemanticSemanticGraphBuilder.Build(lProject, [
    SymbolModel('BasicProject', lProject.MainSourceFileName)]);
  try
    Assert.IsTrue(lGraph.FindUnitByName('BasicProject', lUnit));
    Assert.AreEqual(lProject.MainSourceFileName, lUnit.SourceRange.FileName);
    Assert.AreEqual(0, lUnit.SourceRange.Line);
    Assert.AreEqual(0, lUnit.SourceRange.Column);
  finally
    lGraph.Free;
  end;
end;

procedure TSemanticGraphTests.UnitDtosAreReturnedAsCopies;
var
  lGraph: TDelphiSemanticSemanticGraph;
  lProject: TDelphiSemanticProjectInfo;
  lUnit: TDelphiSemanticGraphUnit;
  lUnits: TArray<TDelphiSemanticGraphUnit>;
begin
  lProject := ProjectInfo;
  lGraph := TDelphiSemanticSemanticGraphBuilder.Build(lProject, [
    SymbolModel('BasicProject', lProject.MainSourceFileName)]);
  try
    lUnits := lGraph.Units;
    lUnits[0].UnitName := 'MutatedUnit';

    Assert.IsTrue(lGraph.FindUnitByName('BasicProject', lUnit));
    Assert.AreEqual('BasicProject', lUnit.UnitName);
  finally
    lGraph.Free;
  end;
end;

procedure TSemanticGraphTests.CanonicalImportsPreserveSpellingAmbiguityAndBuildContext;
var
  lGraph: TDelphiSemanticSemanticGraph;
  lImporter, lAlpha, lBeta, lDuplicate: TDelphiSemanticUnitModel;
  lProject: TDelphiSemanticProjectInfo;

  procedure CheckImports(const aModels: TArray<TDelphiSemanticUnitModel>;
    const aExpectedAlias: string);
  var
    lUnit: TDelphiSemanticGraphUnit;
  begin
    lGraph := TDelphiSemanticSemanticGraphBuilder.Build(lProject, aModels);
    try
      Assert.IsTrue(lGraph.FindUnitByName('Importer', lUnit));
      Assert.AreEqual<Integer>(4, Length(lUnit.InterfaceImports));
      Assert.AreEqual('Unindexed', lUnit.InterfaceImports[0]);
      Assert.AreEqual('unindexed', lUnit.InterfaceImports[1]);
      Assert.AreEqual(aExpectedAlias, lUnit.InterfaceImports[2]);
      Assert.AreEqual(aExpectedAlias, lUnit.InterfaceImports[3]);
    finally
      lGraph.Free;
    end;
  end;

begin
  lProject := ProjectInfo;
  lImporter := SymbolModel('Importer', 'Importer.pas');
  lImporter.DependencyFacts.Known := True;
  lImporter.DependencyFacts.InterfaceImports := ['Unindexed', 'unindexed', 'AliasUnit', 'AliasUnit'];
  lAlpha := SymbolModel('Alpha', 'Alpha.pas');
  lBeta := SymbolModel('Beta', 'Beta.pas');
  lProject.UnitAliases := ['AliasUnit=Alpha'];
  CheckImports([lImporter, lAlpha, lBeta], 'Alpha');
  lProject.UnitAliases := ['AliasUnit=Beta'];
  CheckImports([lImporter, lAlpha, lBeta], 'Beta');
  lDuplicate := SymbolModel('Beta', 'OtherBeta.pas');
  CheckImports([lImporter, lAlpha, lBeta, lDuplicate], 'AliasUnit');
  CheckImports([lImporter, lAlpha, lBeta], 'Beta');
end;

procedure TSemanticGraphTests.ProjectSessionBuildMetricsReportGraphCounts;
var
  lGraphResult: TDelphiSemanticSemanticGraphBuildResult;
  lOptions: TDelphiSemanticOptions;
  lResult: TDelphiSemanticProjectSessionResult;
begin
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := FixturePath('ProjectContext\Basic\BasicProject.dproj');
  lResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lResult.Success);
    lGraphResult := lResult.Session.BuildSemanticGraphResult;
    try
      Assert.AreEqual(1, lGraphResult.Metrics.UnitCount);
      Assert.AreEqual(0, lGraphResult.Metrics.SymbolCount);
      Assert.IsTrue(lGraphResult.Metrics.BuildMilliseconds >= 0);
      Assert.AreEqual(lGraphResult.Graph.Metrics.UnitCount, lGraphResult.Metrics.UnitCount);
    finally
      lGraphResult.Graph.Free;
    end;
  finally
    lResult.Session.Free;
  end;
end;

procedure TSemanticGraphTests.CaptureProofReuseKeepsRawImportsAndInvalidatesChangedEvidence;
const
  cSource = 'unit CaptureMemo;' + #13#10 +
    'interface' + #13#10 + 'uses AliasUnit;' + #13#10 +
    'type TFirst = record end;' + #13#10 + 'implementation' + #13#10 +
    'procedure Work;' + #13#10 + 'begin end;' + #13#10 + 'end.';
var
  g: TGarbos;
  lOriginal, lRelated: TDelphiSemanticSemanticGraph;
  lProject: TDelphiSemanticProjectInfo;
  lModel, lChanged, lAlpha: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lFileName: string;
  lUnit: TDelphiSemanticGraphUnit;
begin
  lFileName := TPath.Combine(CreateTestTempRoot('graph-capture-memo-temp'), 'CaptureMemo.pas');
  TFile.WriteAllText(lFileName, cSource);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lFileName;
  lOptions.ProjectContextApplied := True;
  lOptions.DefineEvidenceComplete := True;
  lModel := TDelphiSemanticUnitModelExtractorImpl.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success, 'extraction');
  Assert.IsTrue(Length(lModel.Routines) > 0, 'routine extraction: ' + lModel.ScopeModelStatus);
  lProject := ProjectInfo;
  lProject.UnitAliases := ['AliasUnit=Alpha'];
  lAlpha := SymbolModel('Alpha', 'Alpha.pas');
  GC(lOriginal, TDelphiSemanticSemanticGraphBuilder.Build(lProject, [lModel, lAlpha]), g);
  Assert.IsTrue(lOriginal.Units[0].CaptureScopeProof.Known, 'original: ' + lOriginal.Units[0].CaptureScopeProof.Cause);
  Assert.AreEqual('Alpha', lOriginal.Units[0].CaptureScopeProof.Imports[0].InterfaceImports[0]);
  lProject.UnitAliases := nil;
  GC(lRelated, TDelphiSemanticSemanticGraphBuilder.Build(lProject, [lModel], lOriginal), g);
  lUnit := lRelated.Units[0];
  Assert.IsTrue(lUnit.CaptureScopeProof.Known, 'related: ' + lUnit.CaptureScopeProof.Cause);
  Assert.AreEqual('AliasUnit', lUnit.CaptureScopeProof.Imports[0].InterfaceImports[0]);
  // A caller's DTO edits cannot change the private raw proof.
  lUnit.CaptureScopeProof.Imports[0].InterfaceImports[0] := 'Mutated';
  GC(lRelated, TDelphiSemanticSemanticGraphBuilder.Build(lProject, [lModel], lOriginal), g);
  Assert.AreEqual('AliasUnit', lRelated.Units[0].CaptureScopeProof.Imports[0].InterfaceImports[0]);
  lChanged := lModel;
  lChanged.VerifiedActiveSourceText := TDelphiSemanticSourceConditionals.UnavailableActivity;
  GC(lRelated, TDelphiSemanticSemanticGraphBuilder.Build(lProject, [lChanged], lOriginal), g);
  Assert.IsFalse(lRelated.Units[0].CaptureScopeProof.Known, 'activity refusal: ' + lRelated.Units[0].CaptureScopeProof.Cause);
  Assert.AreEqual('capture-model-evidence-missing', lRelated.Units[0].CaptureScopeProof.Cause);
  lChanged := lModel;
  lChanged.SourceSections.ImplementationOffset := 0;
  GC(lRelated, TDelphiSemanticSemanticGraphBuilder.Build(lProject, [lChanged], lOriginal), g);
  Assert.IsFalse(lRelated.Units[0].CaptureExportProof.Known, 'export boundary, interface offset=' + IntToStr(lChanged.SourceSections.InterfaceOffset));
  lChanged := lModel;
  lChanged.SourceObservations := nil;
  GC(lRelated, TDelphiSemanticSemanticGraphBuilder.Build(lProject, [lChanged], lOriginal), g);
  Assert.IsFalse(lRelated.Units[0].CaptureScopeProof.Known, 'observation refusal: ' + lRelated.Units[0].CaptureScopeProof.Cause);
  // Deliberately edit the shared routine array. The stored key snapshots values,
  // so pointer identity alone must never certify the former scope proof.
  for var lFact in lOriginal.Units[0].CaptureScopeProof.Names do
    if SameText(lFact.Name, 'Work') then
    begin
      lModel.Routines[0].Line := lFact.Line;
      lModel.Routines[0].Column := lFact.Column;
      lModel.Routines[0].FileName := lFact.FileName;
      lModel.Routines[0].SectionKind := lFact.SectionKind;
    end;
  lModel.Routines[0].ParentScopeId := 'changed-parent';
  GC(lRelated, TDelphiSemanticSemanticGraphBuilder.Build(lProject, [lModel], lOriginal), g);
  Assert.IsFalse(lRelated.Units[0].CaptureScopeProof.Known, 'routine refusal: ' + lRelated.Units[0].CaptureScopeProof.Cause);
  Assert.AreEqual('capture-scope-reparented', lRelated.Units[0].CaptureScopeProof.Cause);
end;

procedure TSemanticGraphTests.CaptureRoutineCandidatesKeepFiltersOrderAndEveryReparentCheck;
const
  cSource = 'unit CaptureRoutineIndex;' + #13#10 + 'interface' + #13#10 +
    'implementation' + #13#10 + 'procedure Work;' + #13#10 +
    'var lValue: Integer;' + #13#10 + 'begin end;' + #13#10 + 'end.';
var
  lFact: TDelphiSemanticCaptureNameFact;
  lFound: Boolean;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lProof: TDelphiSemanticCaptureScopeProof;
  lRoutine: TDelphiSemanticRoutine;
  i: Integer;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := TPath.Combine(CreateTestTempRoot('capture-routine-index-temp'), 'CaptureRoutineIndex.pas');
  lOptions.ProjectContextApplied := True;
  lOptions.DefineEvidenceComplete := True;
  TFile.WriteAllText(lOptions.SourceFileName, cSource);
  lModel := TDelphiSemanticUnitModelExtractorImpl.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success, 'extraction');
  Assert.AreEqual<Integer>(1, Length(lModel.Routines));
  lProof := TDelphiSemanticUnitModelExtractorImpl.CaptureScopeProof(lModel, False);
  Assert.IsTrue(lProof.Known, lProof.Cause);
  lRoutine := lModel.Routines[0];
  lFound := False;
  for lFact in lProof.Names do
    if SameText(lFact.Name, 'Work') and (lFact.Kind = 'method') then
    begin
      lRoutine.Line := lFact.Line;
      lRoutine.Column := lFact.Column;
      lRoutine.FileName := lFact.FileName;
      lRoutine.SectionKind := lFact.SectionKind;
      lFound := True;
    end;
  Assert.IsTrue(lFound, 'physical routine declaration');
  SetLength(lModel.Routines, 6);
  for i := 0 to High(lModel.Routines) do
    lModel.Routines[i] := lRoutine;
  lModel.Routines[0].FileName := ''; // The root-file compatibility match remains valid.
  lModel.Routines[1].FileName := 'OtherFile.pas';
  lModel.Routines[1].ScopeId := 'wrong-file';
  Inc(lModel.Routines[2].Column);
  lModel.Routines[2].ScopeId := 'wrong-column';
  lModel.Routines[3].SectionKind := 'interface';
  lModel.Routines[3].ScopeId := 'wrong-section';
  lModel.Routines[4].ScopeId := 'last-valid-scope';
  lModel.Routines[5].FileName := 'OtherFile.pas';
  lModel.Routines[5].ScopeId := 'wrong-final-file';
  lProof := TDelphiSemanticUnitModelExtractorImpl.CaptureScopeProof(lModel, False);
  Assert.IsTrue(lProof.Known, lProof.Cause);
  lFound := False;
  for lFact in lProof.Names do
    if SameText(lFact.Name, 'lValue') then
    begin
      Assert.AreEqual('last-valid-scope', lFact.OwnerScopeId, 'Last valid candidate wins in physical array order.');
      lFound := True;
    end;
  Assert.IsTrue(lFound, 'local declaration uses the selected routine scope');
  // A later valid match cannot hide an earlier matching reparenting refusal.
  lModel.Routines[0].ParentScopeId := 'unexpected-parent';
  lProof := TDelphiSemanticUnitModelExtractorImpl.CaptureScopeProof(lModel, False);
  Assert.IsFalse(lProof.Known);
  Assert.AreEqual('capture-scope-reparented', lProof.Cause);
end;

procedure TSemanticGraphTests.CaptureTypeHeadersKeepLexerStateAndConditionalUncertainty;
const
  cSource = 'unit CaptureHeaderIndex;' + #13#10 + 'interface' + #13#10 +
    'type TBase = class end;' + #13#10 + '  TAlternative = class end;' + #13#10 +
    '  (* TNoise = class(IncorrectBase); *)' + #13#10 +
    '  THeader = class sealed (' + #13#10 + '{$IFDEF FEATURE}' + #13#10 +
    '    TBase' + #13#10 + '{$ELSE}' + #13#10 + '    TAlternative' + #13#10 +
    '{$ENDIF}' + #13#10 + '  ) end;' + #13#10 +
    '  TRow = record case Kind: Boolean of' + #13#10 +
    '    False: (Ref: TBase); True: (Value: Integer); end;' + #13#10 +
    'implementation' + #13#10 + 'end.';
var
  lFact: TDelphiSemanticCaptureNameFact;
  lHeaderSeen, lRecordSeen: Boolean;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lProof: TDelphiSemanticCaptureScopeProof;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := TPath.Combine(CreateTestTempRoot('capture-header-index-temp'), 'CaptureHeaderIndex.pas');
  lOptions.ProjectContextApplied := True;
  lOptions.DefineEvidenceComplete := True;
  TFile.WriteAllText(lOptions.SourceFileName, cSource);
  lModel := TDelphiSemanticUnitModelExtractorImpl.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success, 'extraction');
  lProof := TDelphiSemanticUnitModelExtractorImpl.CaptureScopeProof(lModel, False);
  Assert.IsTrue(lProof.Known, lProof.Cause);
  lHeaderSeen := False;
  lRecordSeen := False;
  for lFact in lProof.Names do
  begin
    if SameText(lFact.Name, 'THeader') then
    begin
      Assert.IsTrue(lFact.IdentityTextKnown, 'Known conditional ancestor header.');
      Assert.AreEqual<Integer>(1, Length(lFact.IdentityDependencies));
      Assert.AreEqual('TAlternative', lFact.IdentityDependencies[0]);
      lHeaderSeen := True;
    end;
    if SameText(lFact.Name, 'TRow') then
    begin
      Assert.IsTrue(lFact.IdentityTextKnown);
      Assert.AreEqual('record', lFact.IdentitySignature);
      Assert.AreEqual<Integer>(0, Length(lFact.IdentityDependencies), 'Variant fields do not establish nominal identity.');
      lRecordSeen := True;
    end;
  end;
  Assert.IsTrue(lHeaderSeen and lRecordSeen, 'Both nominal type declarations are present.');
  lOptions.DefineEvidenceComplete := False;
  lModel := TDelphiSemanticUnitModelExtractorImpl.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success, 'unknown-activity extraction');
  lProof := TDelphiSemanticUnitModelExtractorImpl.CaptureScopeProof(lModel, False);
  Assert.IsTrue(lProof.Known, lProof.Cause);
  Assert.AreEqual<Integer>(2, lProof.VariantCount);
  lHeaderSeen := False;
  for lFact in lProof.Names do
    if SameText(lFact.Name, 'THeader') then
    begin
      Assert.IsFalse(lFact.IdentityTextKnown, 'An unknown ancestor conditional cannot publish nominal identity.');
      lHeaderSeen := True;
    end;
  Assert.IsTrue(lHeaderSeen);
end;

initialization
  TDUnitX.RegisterTestFixture(TSemanticGraphTests);

end.
