unit Test.ProjectSession;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TProjectSessionTests = class
  private
    function FixturePath(const aRelativePath: string): string;
  public
    [Test]
    procedure ApiFacadeOpensProjectSessionFromProjectFileName;
    [Test]
    procedure EmptyProjectPathReturnsStructuredSessionDiagnostic;
    [Test]
    procedure OpensProjectSessionThroughExistingProjectContext;
    [Test]
    procedure ProjectSessionBuildsSnapshotFromExtractedModels;
    [Test]
    procedure ProjectSessionAssociatesNestedWithReferencesWithInnermostSnapshotFact;
    [Test]
    procedure PersistentProjectFactsCacheReusesUnchangedWithBindingFacts;
    [Test]
    procedure InvalidProjectReturnsStructuredSessionDiagnostic;
  end;

implementation

uses
  System.IOUtils,
  System.SysUtils,
  DelphiSemantics.Api,
  DelphiSemantics.Model,
  DelphiSemantics.ProjectContext,
  DelphiSemantics.ProjectSession,
  DelphiSemantics.Snapshot;

function TProjectSessionTests.FixturePath(const aRelativePath: string): string;
begin
  Result := TPath.GetFullPath(TPath.Combine(
    TPath.Combine(ExtractFilePath(ParamStr(0)), '..\fixtures'),
    aRelativePath));
end;

procedure TProjectSessionTests.ApiFacadeOpensProjectSessionFromProjectFileName;
var
  lOptions: TDelphiSemanticApiOptions;
  lResult: TDelphiSemanticProjectSessionResult;
begin
  lOptions := Default(TDelphiSemanticApiOptions);
  lOptions.ProjectFileName := FixturePath('ProjectContext\Basic\BasicProject.dproj');

  lResult := TDelphiSemanticApi.OpenProjectSession(lOptions);
  try
    Assert.IsTrue(lResult.Success);
    Assert.AreEqual(psOpen, lResult.Status);
    Assert.IsNotNull(lResult.Session);
    Assert.AreEqual('BasicProject', lResult.Session.Project.ProjectName);
  finally
    lResult.Session.Free;
  end;
end;

procedure TProjectSessionTests.EmptyProjectPathReturnsStructuredSessionDiagnostic;
var
  lOptions: TDelphiSemanticOptions;
  lResult: TDelphiSemanticProjectSessionResult;
begin
  lOptions := Default(TDelphiSemanticOptions);

  lResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsFalse(lResult.Success);
    Assert.AreEqual(psInvalidProject, lResult.Status);
    Assert.AreEqual('project-context', lResult.Provenance);
    Assert.IsNull(lResult.Session);
    Assert.AreEqual(1, Integer(Length(lResult.Diagnostics)));
    Assert.AreEqual('PROJECT_FILE_NOT_SPECIFIED', lResult.Diagnostics[0].Code);
    Assert.AreEqual(dsError, lResult.Diagnostics[0].Severity);
  finally
    lResult.Session.Free;
  end;
end;

procedure TProjectSessionTests.OpensProjectSessionThroughExistingProjectContext;
var
  lOptions: TDelphiSemanticOptions;
  lResult: TDelphiSemanticProjectSessionResult;
begin
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := FixturePath('ProjectContext\Basic\BasicProject.dproj');
  lOptions.Configuration := 'Debug';
  lOptions.Platform := 'Win32';

  lResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lResult.Success);
    Assert.AreEqual(psOpen, lResult.Status);
    Assert.AreEqual('project-context', lResult.Provenance);
    Assert.IsNotNull(lResult.Session);
    Assert.AreEqual(lOptions.ProjectPath, lResult.Session.Options.ProjectPath);
    Assert.AreEqual('BasicProject', lResult.Session.Project.ProjectName);
    Assert.AreEqual('Debug', lResult.Session.Project.Configuration);
    Assert.AreEqual('Win32', lResult.Session.Project.Platform);
  finally
    lResult.Session.Free;
  end;
end;

procedure TProjectSessionTests.ProjectSessionBuildsSnapshotFromExtractedModels;
var
  lExpectedReferenceCount: Integer;
  lExpectedSymbolCount: Integer;
  lExpectedWithStatementCount: Integer;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lHighIndex: Integer;
  lLowIndex: Integer;
  lMemberNameId: TSemanticStringId;
  lMetrics: TDelphiSemanticProjectSnapshotBuildMetrics;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticOptions;
  lResult: TDelphiSemanticProjectSessionResult;
  lRoutine: TDelphiSemanticRoutine;
  lSnapshot: TDelphiProjectSnapshot;
  lSymbolRef: TSemanticSymbolRef;
  lTypeNameId: TSemanticStringId;
  lUnitId: TSemanticUnitId;
begin
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := FixturePath('ProjectWithBinding\ProjectWithBinding.dproj');

  lResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lResult.Success);
    lFacts := lResult.Session.BuildWithBindingFacts;

    lExpectedReferenceCount := 0;
    lExpectedSymbolCount := 0;
    lExpectedWithStatementCount := 0;
    for lModel in lFacts.UnitModels do
    begin
      Inc(lExpectedReferenceCount, Length(lModel.References));
      Inc(lExpectedSymbolCount, Length(lModel.Declarations) + Length(lModel.Members) +
        Length(lModel.Routines) + Length(lModel.Locals));
      Inc(lExpectedWithStatementCount, Length(lModel.WithStatements));
      for lRoutine in lModel.Routines do
        Inc(lExpectedSymbolCount, Length(lRoutine.Parameters));
    end;

    lSnapshot := lResult.Session.BuildSnapshot;
    try
      lMetrics := lResult.Session.LastSnapshotBuildMetrics;
      Assert.AreEqual(Length(lFacts.UnitModels), lSnapshot.UnitCount);
      Assert.AreEqual(lSnapshot.UnitCount, lMetrics.UnitCount);
      Assert.AreEqual(lExpectedSymbolCount, lMetrics.SymbolCount);
      Assert.AreEqual(lExpectedReferenceCount, lMetrics.ReferenceCount);
      Assert.AreEqual(lExpectedWithStatementCount, lMetrics.WithStatementCount);
      Assert.AreEqual(Length(lFacts.Bindings), lMetrics.WithStatementCount);
      Assert.IsTrue(lMetrics.BuildMilliseconds >= 0);

      Assert.IsTrue(lSnapshot.TryFindUnitByFileName(
        FixturePath('ProjectWithBinding\ProjectWithBinding.dpr'), lUnitId));
      Assert.AreEqual(1, Integer(lUnitId));

      Assert.IsTrue(lSnapshot.TryFindStringId('TProjectWithRecord', lTypeNameId));
      Assert.IsTrue(lSnapshot.TryTypesByName(lTypeNameId, lLowIndex, lHighIndex));
      Assert.IsTrue(lSnapshot.TryFindStringId('Value', lMemberNameId));
      Assert.IsTrue(lSnapshot.TryFindMember(lTypeNameId, lMemberNameId, lSymbolRef));
      Assert.AreEqual(1, Integer(lSymbolRef.UnitId));
    finally
      lSnapshot.Free;
    end;
  finally
    lResult.Session.Free;
  end;
end;

procedure TProjectSessionTests.ProjectSessionAssociatesNestedWithReferencesWithInnermostSnapshotFact;
var
  i: Integer;
  lFoundInnerReference: Boolean;
  lHighIndex: Integer;
  lInnerWithId: TSemanticWithId;
  lLowIndex: Integer;
  lOptions: TDelphiSemanticOptions;
  lReference: TSemanticReferenceFact;
  lResult: TDelphiSemanticProjectSessionResult;
  lSnapshot: TDelphiProjectSnapshot;
  lUnit: TUnitSnapshot;
  lUnitId: TSemanticUnitId;
  lWith: TSemanticWithStatementFact;
begin
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := FixturePath('WithDiscovery\WithDiscoveryProject.dproj');

  lResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lResult.Success);
    lSnapshot := lResult.Session.BuildSnapshot;
    try
      Assert.IsTrue(lSnapshot.TryFindUnitByFileName(
        FixturePath('WithDiscovery\WithDiscoveryUnit.pas'), lUnitId));
      Assert.IsTrue(lSnapshot.TryFindUnitById(lUnitId, lUnit));

      lInnerWithId := 0;
      for i := 1 to lUnit.WithStatementCount do
      begin
        lWith := lUnit.WithStatementById(TSemanticWithId(i));
        if lWith.SelectorStartLine = 30 then
          lInnerWithId := lWith.Id;
      end;
      Assert.IsTrue(lInnerWithId <> 0, 'Expected nested inner with statement at line 30.');
      Assert.IsTrue(lUnit.TryReferencesForWith(lInnerWithId, lLowIndex, lHighIndex));

      lFoundInnerReference := False;
      for i := lLowIndex to lHighIndex do
      begin
        lReference := lUnit.ReferenceById(lUnit.ReferenceIdByWithIndex(i));
        if (lReference.Line = 31) and SameText(lSnapshot.TextOf(lReference.NameId), 'Value') then
          lFoundInnerReference := True;
      end;
      Assert.IsTrue(lFoundInnerReference,
        'Expected the inner with statement to own its body reference.');
    finally
      lSnapshot.Free;
    end;
  finally
    lResult.Session.Free;
  end;
end;

procedure TProjectSessionTests.PersistentProjectFactsCacheReusesUnchangedWithBindingFacts;
var
  lBodyAnalysisProbePath: string;
  lCachePath: string;
  lDprPath: string;
  lDprojPath: string;
  lFirstFacts: TDelphiSemanticProjectWithBindingFacts;
  lFirstResult: TDelphiSemanticProjectSessionResult;
  lFourthFacts: TDelphiSemanticProjectWithBindingFacts;
  lFourthResult: TDelphiSemanticProjectSessionResult;
  lIncludePath: string;
  lOptions: TDelphiSemanticOptions;
  lRootPath: string;
  lSecondFacts: TDelphiSemanticProjectWithBindingFacts;
  lSecondResult: TDelphiSemanticProjectSessionResult;
  lThirdFacts: TDelphiSemanticProjectWithBindingFacts;
  lThirdResult: TDelphiSemanticProjectSessionResult;
  lUnitPath: string;
begin
  lRootPath := TPath.GetFullPath(TPath.Combine(ExtractFilePath(ParamStr(0)),
    'project-session-cache-temp'));
  if TDirectory.Exists(lRootPath) then
    TDirectory.Delete(lRootPath, True);
  TDirectory.CreateDirectory(lRootPath);

  lDprPath := TPath.Combine(lRootPath, 'ProjectFactsCache.dpr');
  lDprojPath := TPath.Combine(lRootPath, 'ProjectFactsCache.dproj');
  lBodyAnalysisProbePath := TPath.Combine(lRootPath, 'BodyAnalysisProbe.pas');
  lIncludePath := TPath.Combine(lRootPath, 'ProjectFactsCache.inc');
  lUnitPath := TPath.Combine(lRootPath, 'ProjectFactsCacheUnit.pas');
  lCachePath := TPath.Combine(TPath.Combine(lRootPath, '.dak'),
    'semantic-cache.sqlite3');

  TFile.WriteAllText(lDprPath, 'program ProjectFactsCache;' + sLineBreak +
    'uses ProjectFactsCacheUnit;' + sLineBreak + 'begin' + sLineBreak + 'end.',
    TEncoding.UTF8);
  TFile.WriteAllText(lDprojPath,
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' +
    sLineBreak + '  <PropertyGroup>' + sLineBreak +
    '    <ProjectGuid>{7103CF49-42A8-4C33-A46C-C4409732D985}</ProjectGuid>' +
    sLineBreak + '    <MainSource>ProjectFactsCache.dpr</MainSource>' +
    sLineBreak + '  </PropertyGroup>' + sLineBreak + '  <ItemGroup>' +
    sLineBreak + '    <DCCReference Include="ProjectFactsCacheUnit.pas"/>' +
    sLineBreak + '  </ItemGroup>' + sLineBreak + '</Project>', TEncoding.UTF8);
  TFile.WriteAllText(lUnitPath, 'unit ProjectFactsCacheUnit;' + sLineBreak +
    'interface' + sLineBreak + 'type' + sLineBreak +
    '  TProjectFactsCacheRecord = record' + sLineBreak + '    Value: Integer;' +
    sLineBreak + '  end;' + sLineBreak + 'procedure UseCacheRecord;' +
    sLineBreak + 'implementation' + sLineBreak + '{$I ProjectFactsCache.inc}' +
    sLineBreak + 'procedure UseCacheRecord;' + sLineBreak + 'var' + sLineBreak +
    '  lRecord: TProjectFactsCacheRecord;' + sLineBreak + 'begin' +
    sLineBreak + '  with lRecord do' + sLineBreak + '    Value := 1;' +
    sLineBreak + 'end;' + sLineBreak + 'end.', TEncoding.UTF8);
  TFile.WriteAllText(lIncludePath, '// include cache probe' + sLineBreak,
    TEncoding.UTF8);
  TFile.WriteAllText(lBodyAnalysisProbePath, 'unit BodyAnalysisProbe;' +
    sLineBreak + 'interface' + sLineBreak + 'implementation' + sLineBreak +
    'end.', TEncoding.UTF8);

  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := lDprojPath;
  lOptions.SqliteCacheFileName := lCachePath;
  lOptions.SkipWithBindingSemanticGraph := True;
  SetLength(lOptions.BodyAnalysisSourceFileNames, 2);
  lOptions.BodyAnalysisSourceFileNames[0] := lUnitPath;
  lOptions.BodyAnalysisSourceFileNames[1] := lBodyAnalysisProbePath;

  lFirstResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lFirstResult.Success);
    lFirstFacts := lFirstResult.Session.BuildWithBindingFacts;
  finally
    lFirstResult.Session.Free;
  end;
  Assert.AreEqual(Int64(0), lFirstFacts.Metrics.ProjectFactsCacheHits);
  Assert.IsTrue(lFirstFacts.Metrics.ProjectFactsCacheMisses > 0);
  Assert.IsTrue(Length(lFirstFacts.Bindings) > 0,
    'Expected fixture to produce with-binding facts.');

  lSecondResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lSecondResult.Success);
    lSecondFacts := lSecondResult.Session.BuildWithBindingFacts;
  finally
    lSecondResult.Session.Free;
  end;
  Assert.IsTrue(lSecondFacts.Metrics.ProjectFactsCacheHits > 0,
    'Expected unchanged project facts to be loaded from the persistent cache.');
  Assert.AreEqual(Length(lFirstFacts.Bindings), Length(lSecondFacts.Bindings));
  Assert.AreEqual(Length(lFirstFacts.Symbols), Length(lSecondFacts.Symbols));
  Assert.AreEqual(lFirstFacts.Bindings[0].SemanticId,
    lSecondFacts.Bindings[0].SemanticId);
  Assert.AreEqual(lFirstFacts.Bindings[0].SelectorText,
    lSecondFacts.Bindings[0].SelectorText);
  Assert.AreEqual(lFirstFacts.Bindings[0].Status, lSecondFacts.Bindings[0].Status);
  Assert.IsTrue(Length(lFirstFacts.Bindings[0].References) > 0,
    'Expected fixture to produce cached binding references.');
  Assert.AreEqual(Length(lFirstFacts.Bindings[0].References),
    Length(lSecondFacts.Bindings[0].References));
  Assert.AreEqual(lFirstFacts.Bindings[0].References[0].Name,
    lSecondFacts.Bindings[0].References[0].Name);
  Assert.AreEqual(lFirstFacts.Bindings[0].References[0].Classification,
    lSecondFacts.Bindings[0].References[0].Classification);

  TFile.AppendAllText(lBodyAnalysisProbePath, sLineBreak +
    '// project facts cache invalidation probe' + sLineBreak, TEncoding.UTF8);
  lThirdResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lThirdResult.Success);
    lThirdFacts := lThirdResult.Session.BuildWithBindingFacts;
  finally
    lThirdResult.Session.Free;
  end;
  Assert.IsTrue(lThirdFacts.Metrics.ProjectFactsCacheInvalidations > 0,
    'Expected changed source to invalidate persistent project facts.');
  Assert.IsTrue(lThirdFacts.Metrics.ProjectFactsCacheMisses > 0,
    'Expected changed source to rebuild persistent project facts.');

  TFile.AppendAllText(lIncludePath, sLineBreak +
    '// project facts include invalidation probe' + sLineBreak, TEncoding.UTF8);
  lFourthResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lFourthResult.Success);
    lFourthFacts := lFourthResult.Session.BuildWithBindingFacts;
  finally
    lFourthResult.Session.Free;
  end;
  Assert.IsTrue(lFourthFacts.Metrics.ProjectFactsCacheInvalidations > 0,
    'Expected changed include to invalidate persistent project facts.');
  Assert.IsTrue(lFourthFacts.Metrics.ProjectFactsCacheMisses > 0,
    'Expected changed include to rebuild persistent project facts.');
end;

procedure TProjectSessionTests.InvalidProjectReturnsStructuredSessionDiagnostic;
var
  lOptions: TDelphiSemanticOptions;
  lResult: TDelphiSemanticProjectSessionResult;
begin
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := FixturePath('ProjectContext\Missing\MissingProject.dproj');

  lResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsFalse(lResult.Success);
    Assert.AreEqual(psInvalidProject, lResult.Status);
    Assert.AreEqual('project-context', lResult.Provenance);
    Assert.IsNull(lResult.Session);
    Assert.AreEqual(1, Integer(Length(lResult.Diagnostics)));
    Assert.AreEqual('PROJECT_FILE_NOT_FOUND', lResult.Diagnostics[0].Code);
    Assert.AreEqual(dsError, lResult.Diagnostics[0].Severity);
  finally
    lResult.Session.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TProjectSessionTests);

end.
