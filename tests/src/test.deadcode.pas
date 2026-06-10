unit Test.DeadCode;

interface

uses
  DUnitX.TestFramework,
  DelphiSemantics.Api,
  DelphiSemantics.Cache,
  DelphiSemantics.CompilerProfile,
  DelphiSemantics.DeadCode,
  DelphiSemantics.Index,
  DelphiSemantics.Model,
  DelphiSemantics.Query,
  DelphiSemantics.Snapshot;

type
  [TestFixture]
  TDeadCodeTests = class
  private
    function CandidateHasBlocker(const aReport: TDelphiSemanticDeadCodeReport;
      const aName, aBlocker: string): Boolean;
    function CandidateStatus(const aReport: TDelphiSemanticDeadCodeReport;
      const aName: string): string;
    function FixturePath(const aFileName: string): string;
    function LoadContext: TDelphiSemanticSymbolQueryContext;
  public
    [Test]
    procedure ReportsConservativeDeadCodeStatuses;
    [Test]
    procedure ReportsDeadCodeFromSnapshotWithoutProjectIndexBuild;
    [Test]
    procedure SnapshotReferenceCountsMatchModelBackedReport;
  end;

implementation

uses
  System.Generics.Collections, System.IOUtils, System.StrUtils, System.SysUtils,
  maxLogic.IOUtils;

function TDeadCodeTests.CandidateHasBlocker(const aReport: TDelphiSemanticDeadCodeReport;
  const aName, aBlocker: string): Boolean;
var
  lBlocker: string;
  lCandidate: TDelphiSemanticDeadCodeCandidate;
begin
  for lCandidate in aReport.Candidates do
    if SameText(lCandidate.Name, aName) then
      for lBlocker in lCandidate.Blockers do
        if SameText(lBlocker, aBlocker) then
          Exit(True);

  Result := False;
end;

function TDeadCodeTests.CandidateStatus(const aReport: TDelphiSemanticDeadCodeReport;
  const aName: string): string;
var
  lCandidate: TDelphiSemanticDeadCodeCandidate;
begin
  for lCandidate in aReport.Candidates do
    if SameText(lCandidate.Name, aName) then
      Exit(lCandidate.Status);

  Result := '';
end;

function DescribeCandidates(const aReport: TDelphiSemanticDeadCodeReport): string;
var
  lCandidate: TDelphiSemanticDeadCodeCandidate;
begin
  Result := '';
  for lCandidate in aReport.Candidates do
    Result := Result + lCandidate.Name + '=' + lCandidate.Status + '/' + IntToStr(
      lCandidate.ReferenceCount) + '; ';
end;

function CandidateReferenceCount(const aReport: TDelphiSemanticDeadCodeReport;
  const aName: string): Integer;
var
  lCandidate: TDelphiSemanticDeadCodeCandidate;
begin
  for lCandidate in aReport.Candidates do
    if SameText(lCandidate.Name, aName) then
      Exit(lCandidate.ReferenceCount);

  Result := -1;
end;

function TDeadCodeTests.FixturePath(const aFileName: string): string;
begin
  Result := TPath.GetFullPath(CombinePath([ExtractFilePath(ParamStr(0)), '..', 'fixtures',
    'DeadCode', aFileName]));
end;

function TDeadCodeTests.LoadContext: TDelphiSemanticSymbolQueryContext;
var
  lCache: TDelphiSemanticUnitCache;
  lCacheOptions: TDelphiSemanticCacheOptions;
  lModelOptions: TDelphiSemanticModelOptions;
begin
  lCacheOptions := Default(TDelphiSemanticCacheOptions);
  lCacheOptions.CompilerProfileName := 'Delphi-12-DeadCode';
  lCache := TDelphiSemanticUnitCache.Create(lCacheOptions);
  try
    lModelOptions := Default(TDelphiSemanticModelOptions);
    lModelOptions.SourceFileName := FixturePath('DeadCodeUnit.pas');
    lModelOptions.ProjectContextApplied := True;
    Result.UnitModel := lCache.GetOrExtractUnitModel(lModelOptions);
    Result.CompilerProfile := TDelphiSemanticCompilerProfileBuilder.FromCachedSources(lCache,
      [FixturePath('DeadCodeOtherUnit.pas')]);
    lModelOptions := Default(TDelphiSemanticModelOptions);
    lModelOptions.SourceFileName := FixturePath('DeadCodeRtlUnit.pas');
    lModelOptions.ProjectContextApplied := True;
    Result.IndexedUnitModels := Result.CompilerProfile.RtlSourceUnitModels +
      [lCache.GetOrExtractUnitModel(lModelOptions)];
    Result.IndexedUnitSourceKinds := ['project-source', 'rtl-source'];
    Result.CacheMetrics := lCache.Metrics;
  finally
    lCache.Free;
  end;
end;

procedure TDeadCodeTests.ReportsConservativeDeadCodeStatuses;
var
  lContext: TDelphiSemanticSymbolQueryContext;
  lReport: TDelphiSemanticDeadCodeReport;
begin
  lContext := LoadContext;

  lReport := TDelphiSemanticApi.ReportDeadCode(lContext, 'audit');

  Assert.AreEqual('audit', lReport.Profile);
  Assert.AreEqual('definitely-unused', CandidateStatus(lReport, 'StaticUnusedValue'));
  Assert.AreEqual('maybe-unused', CandidateStatus(lReport, 'MaybeDynamicHook'));
  Assert.AreEqual('externally-visible', CandidateStatus(lReport, 'TExternallyVisibleType'));
  Assert.AreEqual('blocked', CandidateStatus(lReport, 'Button1Click'), 'Button1Click');
  Assert.AreEqual('blocked', CandidateStatus(lReport, 'ExportedHook'), 'ExportedHook ' +
    DescribeCandidates(lReport));
  Assert.AreEqual('blocked', CandidateStatus(lReport, 'InitializedHook'), 'InitializedHook');
  Assert.AreEqual('blocked', CandidateStatus(lReport, 'MessageHandler'), 'MessageHandler');
  Assert.AreEqual('blocked', CandidateStatus(lReport, 'AmbiguousGlobal'), 'AmbiguousGlobal');
  Assert.AreEqual('blocked', CandidateStatus(lReport, 'MissingExternalSymbol'), 'MissingExternalSymbol');
  Assert.AreEqual('blocked', CandidateStatus(lReport, 'ExternalOnlySymbol'), 'ExternalOnlySymbol');
  Assert.AreEqual('', CandidateStatus(lReport, 'UsedGlobalValue'));
  Assert.IsTrue(CandidateHasBlocker(lReport, 'Button1Click', 'published-or-dfm-handler'));
  Assert.IsTrue(CandidateHasBlocker(lReport, 'ExportedHook', 'exported-symbol'));
  Assert.IsTrue(CandidateHasBlocker(lReport, 'InitializedHook', 'initialization-hook'));
  Assert.IsTrue(CandidateHasBlocker(lReport, 'MessageHandler', 'message-method'));
  Assert.IsTrue(CandidateHasBlocker(lReport, 'AmbiguousGlobal', 'ambiguous-reference'));
  Assert.IsTrue(CandidateHasBlocker(lReport, 'MissingExternalSymbol', 'unresolved-reference'));
  Assert.IsTrue(CandidateHasBlocker(lReport, 'ExternalOnlySymbol', 'unresolved-reference'));
end;

procedure TDeadCodeTests.ReportsDeadCodeFromSnapshotWithoutProjectIndexBuild;
var
  lBefore: string;
  lBuilder: TDelphiProjectSnapshotBuilder;
  lContext: TDelphiSemanticSymbolQueryContext;
  lFileName: string;
  lNameId: TSemanticStringId;
  lProject: TDelphiProjectSnapshot;
  lReport: TDelphiSemanticDeadCodeReport;
  lRootPath: string;
  lSymbol: TSemanticSymbolFact;
  lUnit: TUnitSnapshot;
begin
  lBuilder := TDelphiProjectSnapshotBuilder.Create;
  lProject := nil;
  lRootPath := '';
  try
    lRootPath := TPath.GetFullPath(TPath.Combine(ExtractFilePath(ParamStr(0)),
      'snapshot-deadcode-temp'));
    if TDirectory.Exists(lRootPath) then
      TDirectory.Delete(lRootPath, True);
    TDirectory.CreateDirectory(lRootPath);
    lFileName := TPath.Combine(lRootPath, 'SnapshotDeadCodeUnit.pas');
    TFile.WriteAllText(lFileName, 'unit SnapshotDeadCodeUnit;' + sLineBreak +
      'interface' + sLineBreak + 'implementation' + sLineBreak + 'var' +
      sLineBreak + '  SnapshotUnusedValue: Integer;' + sLineBreak + 'end.',
      TEncoding.UTF8);
    lBefore := TFile.ReadAllText(lFileName);

    lNameId := lBuilder.Strings.Intern('SnapshotUnusedValue');
    lUnit := TUnitSnapshot.Create(1, lBuilder.Strings.Intern(lFileName),
      lBuilder.Strings.Intern('SnapshotDeadCodeUnit'));
    try
      lSymbol := Default(TSemanticSymbolFact);
      lSymbol.NameId := lNameId;
      lSymbol.KindId := lBuilder.Strings.Intern('var');
      lSymbol.SectionKindId := lBuilder.Strings.Intern('implementation');
      lSymbol.SourceKindId := lBuilder.Strings.Intern('project-source');
      lSymbol.Line := 5;
      lSymbol.Column := 3;
      lSymbol.EndLine := 5;
      lSymbol.EndColumn := 21;
      lUnit.AddSymbol(lSymbol);

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

    lReport := TDelphiSemanticApi.ReportDeadCode(lContext, 'audit');

    Assert.AreEqual('audit', lReport.Profile);
    Assert.AreEqual('definitely-unused', CandidateStatus(lReport, 'SnapshotUnusedValue'));
    Assert.AreEqual(0, lReport.IndexMetrics.BuildInvocationCount);
    Assert.AreEqual(lBefore, TFile.ReadAllText(lFileName));
  finally
    lContext.ProjectSnapshot := nil;
    lProject.Free;
    if (lRootPath <> '') and TDirectory.Exists(lRootPath) then
      TDirectory.Delete(lRootPath, True);
  end;
end;

procedure TDeadCodeTests.SnapshotReferenceCountsMatchModelBackedReport;
var
  lBuilder: TDelphiProjectSnapshotBuilder;
  lContext: TDelphiSemanticSymbolQueryContext;
  lDeclaration: TDelphiSemanticDeclaration;
  lDeclarations: TArray<TDelphiSemanticDeclaration>;
  lFileName: string;
  lIndex: TDelphiSemanticProjectSymbolIndex;
  lMap: TDictionary<string, TSemanticSymbolRef>;
  lModelReport: TDelphiSemanticDeadCodeReport;
  lNameId: TSemanticStringId;
  lProject: TDelphiProjectSnapshot;
  lReference: TDelphiSemanticReference;
  lSnapshotContext: TDelphiSemanticSymbolQueryContext;
  lSnapshotReference: TSemanticReferenceFact;
  lSnapshotReport: TDelphiSemanticDeadCodeReport;
  lSnapshotSymbol: TSemanticSymbolFact;
  lSource: string;
  lSymbol: TDelphiSemanticIndexedSymbol;
  lSymbolRef: TSemanticSymbolRef;
  lTargetRef: TSemanticSymbolRef;
  lUnit: TUnitSnapshot;
begin
  lFileName := TPath.Combine(ExtractFilePath(ParamStr(0)),
    'snapshot-deadcode-parity-temp.pas');
  lSource := 'unit SnapshotDeadCodeParityUnit;' + sLineBreak + 'interface' +
    sLineBreak + 'implementation' + sLineBreak + 'var' + sLineBreak +
    '  SnapshotReferencedHook: Integer;' + sLineBreak +
    '  SnapshotUnusedParityValue: Integer;' + sLineBreak + 'initialization' +
    sLineBreak + '  SnapshotReferencedHook := 1;' + sLineBreak + 'end.';
  TFile.WriteAllText(lFileName, lSource, TEncoding.UTF8);
  lProject := nil;
  lMap := TDictionary<string, TSemanticSymbolRef>.Create;
  lBuilder := TDelphiProjectSnapshotBuilder.Create;
  try
    lContext := Default(TDelphiSemanticSymbolQueryContext);
    lContext.UnitModel.UnitName := 'SnapshotDeadCodeParityUnit';
    lContext.UnitModel.FileName := lFileName;

    lDeclaration := Default(TDelphiSemanticDeclaration);
    lDeclaration.Name := 'SnapshotReferencedHook';
    lDeclaration.Kind := 'var';
    lDeclaration.SectionKind := 'implementation';
    lDeclaration.Line := 5;
    lDeclaration.Column := 3;
    lDeclarations := [lDeclaration];

    lDeclaration := Default(TDelphiSemanticDeclaration);
    lDeclaration.Name := 'SnapshotUnusedParityValue';
    lDeclaration.Kind := 'var';
    lDeclaration.SectionKind := 'implementation';
    lDeclaration.Line := 6;
    lDeclaration.Column := 3;
    lDeclarations := lDeclarations + [lDeclaration];
    lContext.UnitModel.Declarations := lDeclarations;

    lReference := Default(TDelphiSemanticReference);
    lReference.Name := 'SnapshotReferencedHook';
    lReference.SectionKind := 'implementation';
    lReference.Line := 8;
    lReference.Column := 3;
    lReference.EndLine := 8;
    lReference.EndColumn := 24;
    lContext.UnitModel.References := [lReference];

    lIndex := TDelphiSemanticProjectSymbolIndexer.Build(lContext);
    lModelReport := TDelphiSemanticApi.ReportDeadCode(lContext, 'audit');

    lUnit := TUnitSnapshot.Create(1, lBuilder.Strings.Intern(lFileName),
      lBuilder.Strings.Intern('SnapshotDeadCodeParityUnit'));
    try
      for lSymbol in lIndex.Symbols do
      begin
        if SameText(lSymbol.Kind, 'unit') then
          Continue;
        lSnapshotSymbol := Default(TSemanticSymbolFact);
        lSnapshotSymbol.NameId := lBuilder.Strings.Intern(lSymbol.Name);
        lSnapshotSymbol.KindId := lBuilder.Strings.Intern(lSymbol.Kind);
        lSnapshotSymbol.SectionKindId := lBuilder.Strings.Intern(lSymbol.SectionKind);
        lSnapshotSymbol.SourceKindId := lBuilder.Strings.Intern(lSymbol.SourceKind);
        lSnapshotSymbol.VisibilityId := lBuilder.Strings.Intern(lSymbol.Visibility);
        lSnapshotSymbol.Line := lSymbol.Line;
        lSnapshotSymbol.Column := lSymbol.Column;
        lSnapshotSymbol.EndLine := lSymbol.Line;
        lSnapshotSymbol.EndColumn := lSymbol.Column + Length(lSymbol.Name) - 1;
        lSymbolRef.UnitId := lUnit.UnitId;
        lSymbolRef.SymbolId := lUnit.AddSymbol(lSnapshotSymbol);
        lMap.Add(lSymbol.Id.Value, lSymbolRef);
      end;

      for lReference in lContext.UnitModel.References do
      begin
        lNameId := lBuilder.Strings.Intern(lReference.Name);
        lSnapshotReference := Default(TSemanticReferenceFact);
        lSnapshotReference.NameId := lNameId;
        lSnapshotReference.SectionKindId := lBuilder.Strings.Intern(lReference.SectionKind);
        lSnapshotReference.SourceKindId := lBuilder.Strings.Intern('project-source');
        lSnapshotReference.Line := lReference.Line;
        lSnapshotReference.Column := lReference.Column;
        lSnapshotReference.EndLine := lReference.EndLine;
        lSnapshotReference.EndColumn := lReference.EndColumn;
        for lSymbol in lIndex.Symbols do
          if SameText(lSymbol.Name, lReference.Name) and lMap.TryGetValue(
            lSymbol.Id.Value, lTargetRef) then
          begin
            lSnapshotReference.TargetUnitId := lTargetRef.UnitId;
            lSnapshotReference.TargetSymbolId := lTargetRef.SymbolId;
            Break;
          end;
        lUnit.AddReference(lSnapshotReference);
      end;

      lBuilder.AddUnit(lUnit);
      lUnit := nil;
    finally
      lUnit.Free;
    end;

    lProject := lBuilder.Build;
    lSnapshotContext := Default(TDelphiSemanticSymbolQueryContext);
    lSnapshotContext.ProjectSnapshot := BorrowProjectSnapshot(lProject);
    lSnapshotReport := TDelphiSemanticApi.ReportDeadCode(lSnapshotContext, 'audit');

    Assert.AreEqual(CandidateStatus(lModelReport, 'SnapshotReferencedHook'),
      CandidateStatus(lSnapshotReport, 'SnapshotReferencedHook'));
    Assert.AreEqual(CandidateReferenceCount(lModelReport, 'SnapshotReferencedHook'),
      CandidateReferenceCount(lSnapshotReport, 'SnapshotReferencedHook'));
    Assert.AreEqual(CandidateStatus(lModelReport, 'SnapshotUnusedParityValue'),
      CandidateStatus(lSnapshotReport, 'SnapshotUnusedParityValue'));
    Assert.AreEqual(CandidateReferenceCount(lModelReport, 'SnapshotUnusedParityValue'),
      CandidateReferenceCount(lSnapshotReport, 'SnapshotUnusedParityValue'));
    Assert.AreEqual(0, lSnapshotReport.IndexMetrics.BuildInvocationCount);
  finally
    lSnapshotContext.ProjectSnapshot := nil;
    lProject.Free;
    lBuilder.Free;
    lMap.Free;
    if TFile.Exists(lFileName) then
      TFile.Delete(lFileName);
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TDeadCodeTests);

end.
