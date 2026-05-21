unit Test.DeadCode;

interface

uses
  DUnitX.TestFramework,
  DelphiSemantics.Api,
  DelphiSemantics.Cache,
  DelphiSemantics.CompilerProfile,
  DelphiSemantics.DeadCode,
  DelphiSemantics.Model,
  DelphiSemantics.Query;

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
  end;

implementation

uses
  System.IOUtils, System.StrUtils, System.SysUtils,
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

initialization
  TDUnitX.RegisterTestFixture(TDeadCodeTests);

end.
