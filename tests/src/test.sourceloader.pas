unit Test.SourceLoader;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TSourceLoaderTests = class
  private
    function TempPath(const aName: string): string;
    function ObservationPath(const aName: string): string;
  public
    [Test]
    procedure LoadFileReportsLfLineEndingProvenance;
    [Test]
    procedure LoadFileReportsMixedLineEndingProvenance;
    [Test]
    procedure LoadFileReportsByteContentHash;
    [Test]
    procedure UnitModelCarriesSourceLoaderProvenance;
    [Test]
    procedure SourceContextUsesLoaderLineBreakForMixedSource;
    [Test]
    [Category('RefactoringLightObservations')]
    procedure ExtractionRetainsOriginalSourceAndIncludeBytes;
    [Test]
    [Category('RefactoringLightObservations')]
    procedure EqualIncludeTextRetainsDistinctByteObservations;
    [Test]
    [Category('RefactoringLightObservations')]
    procedure ConflictingObservationsRefuseCombinedEvidence;
    [Test]
    [Category('RefactoringLightObservations')]
    procedure CacheDoesNotStoreModelUnderEarlierSourceObservation;
    [Test]
    [Category('RefactoringLightObservations')]
    procedure PersistedModelsDoNotInventSourceObservations;
    [Test]
    [Category('RefactoringLightObservations')]
    procedure CacheRefreshesEqualTextIncludeByteEvidence;
    [Test]
    [Category('RefactoringLightObservations')]
    procedure ObservationMergeOrderIsDeterministic;
    [Test]
    [Category('RefactoringLightObservations')]
    procedure RepeatedPreprocessDoesNotRetainEarlierObservations;
    [Test]
    [Category('RefactoringLightObservations')]
    procedure FailedLoadDoesNotRetainEarlierObservations;
  end;

implementation

uses
  System.Hash, System.IOUtils, System.SysUtils,
  AutoFree, maxLogic.IOUtils,
  DelphiSemantics.Cache, DelphiSemantics.Cache.Sqlite, DelphiSemantics.Model,
  DelphiSemantics.Preprocess, DelphiSemantics.Source, DelphiSemantics.SourceContext;

var
  GSourceLoaderTempRoot: string;

function TSourceLoaderTests.TempPath(const aName: string): string;
var
  lGuid: TGUID;
  lGuidText: string;
begin
  if GSourceLoaderTempRoot = '' then
  begin
    CreateGUID(lGuid);
    lGuidText := StringReplace(StringReplace(GUIDToString(lGuid), '{', '', [rfReplaceAll]),
      '}', '', [rfReplaceAll]);
    GSourceLoaderTempRoot := TPath.GetFullPath(TPath.Combine(TPath.Combine(
      ExtractFilePath(ParamStr(0)), 'source-loader-temp'), 'run-' + lGuidText));
  end;
  TDirectory.CreateDirectory(GSourceLoaderTempRoot);
  Result := TPath.Combine(GSourceLoaderTempRoot, aName);
end;

procedure WriteUtf8Bytes(const aFileName, aText: string);
begin
  TFile.WriteAllBytes(aFileName, TEncoding.UTF8.GetBytes(aText));
end;

function TSourceLoaderTests.ObservationPath(const aName: string): string;
var
  lGuid: TGUID;
  lRoot: string;
begin
  CreateGUID(lGuid);
  lRoot := TPath.GetFullPath(CombinePath([ExtractFilePath(ParamStr(0)), '..', '.dak',
    'delphiSemanticsTests', 'refactoring-light-observations', 'fixtures', GUIDToString(lGuid)]));
  TDirectory.CreateDirectory(lRoot);
  Result := TPath.Combine(lRoot, aName);
end;

procedure TSourceLoaderTests.ExtractionRetainsOriginalSourceAndIncludeBytes;
var
  lOptions: TDelphiSemanticModelOptions;
  lModel: TDelphiSemanticUnitModel;
  lEvidence: IDelphiSemanticSourceObservations;
  lItem: TDelphiSemanticSourceText;
  lPath, lInclude, lSourceHash, lIncludeHash: string;
begin
  lPath := ObservationPath('Observed.pas');
  lInclude := TPath.Combine(ExtractFilePath(lPath), 'Observed.inc');
  WriteUtf8Bytes(lPath, 'unit Observed; interface {$I Observed.inc} implementation end.');
  WriteUtf8Bytes(lInclude, 'type TObserved = Integer;');
  lSourceHash := THashSHA2.GetHashStringFromFile(lPath);
  lIncludeHash := THashSHA2.GetHashStringFromFile(lInclude);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lPath;
  lOptions.ProjectContextApplied := True;
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions, lEvidence);
  Assert.IsTrue(lModel.Success);
  Assert.IsNotNull(lEvidence);
  Assert.AreEqual(2, lEvidence.Count);
  WriteUtf8Bytes(lPath, 'unit Replaced; interface implementation end.');
  WriteUtf8Bytes(lInclude, 'type TReplaced = String;');
  Assert.IsTrue(lEvidence.TryFind(lPath, lItem));
  Assert.AreEqual(lSourceHash, lItem.ContentHash);
  Assert.AreEqual(lModel.SourceText, lItem.Text);
  lItem.Text := 'caller mutation';
  Assert.IsTrue(lEvidence.TryFind(lPath, lItem));
  Assert.AreEqual(lModel.SourceText, lItem.Text);
  Assert.IsTrue(lEvidence.TryFind(lInclude, lItem));
  Assert.AreEqual(lIncludeHash, lItem.ContentHash);
  Assert.AreEqual('type TObserved = Integer;', lItem.Text);
end;

procedure TSourceLoaderTests.EqualIncludeTextRetainsDistinctByteObservations;
var
  lOptions: TDelphiSemanticModelOptions;
  lBefore, lAfter: TDelphiSemanticUnitModel;
  lFirst, lSecond: TDelphiSemanticSourceText;
  lPath, lInclude: string;
begin
  lPath := ObservationPath('ByteIdentity.pas');
  lInclude := TPath.Combine(ExtractFilePath(lPath), 'ByteIdentity.inc');
  WriteUtf8Bytes(lPath, 'unit ByteIdentity; interface {$I ByteIdentity.inc} implementation end.');
  WriteUtf8Bytes(lInclude, 'type TObserved = Integer;');
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lPath;
  lOptions.ProjectContextApplied := True;
  lBefore := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  TFile.WriteAllText(lInclude, 'type TObserved = Integer;', TEncoding.Unicode);
  lAfter := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lBefore.Success and lAfter.Success);
  Assert.IsNotNull(lBefore.SourceObservations);
  Assert.IsNotNull(lAfter.SourceObservations);
  Assert.IsTrue(lBefore.SourceObservations.TryFind(lInclude, lFirst));
  Assert.IsTrue(lAfter.SourceObservations.TryFind(lInclude, lSecond));
  Assert.AreEqual(lFirst.Text, lSecond.Text);
  Assert.AreNotEqual(lFirst.ContentHash, lSecond.ContentHash);
end;

procedure TSourceLoaderTests.ConflictingObservationsRefuseCombinedEvidence;
var
  lFirst, lSecond: TDelphiSemanticSourceLoadResult;
  lCombined: IDelphiSemanticSourceObservations;
  lPath, lError: string;
begin
  lPath := ObservationPath('Conflict.pas');
  WriteUtf8Bytes(lPath, 'first');
  lFirst := TDelphiSemanticSourceLoader.LoadFile(lPath);
  WriteUtf8Bytes(lPath, 'second');
  lSecond := TDelphiSemanticSourceLoader.LoadFile(UpperCase(lPath));
  Assert.IsTrue(lFirst.Success and lSecond.Success);
  Assert.IsTrue(TDelphiSemanticSourceEvidence.TryMerge(lFirst.SourceObservations,
    lFirst.SourceObservations, lCombined, lError), lError);
  Assert.AreEqual(1, lCombined.Count);
  Assert.IsFalse(TDelphiSemanticSourceEvidence.TryMerge(lFirst.SourceObservations,
    lSecond.SourceObservations, lCombined, lError));
  Assert.IsNull(lCombined);
  Assert.AreEqual('source.conflicting-observations', lError);
end;

procedure TSourceLoaderTests.CacheDoesNotStoreModelUnderEarlierSourceObservation;
var
  g: TGarbos;
  lCache: TDelphiSemanticUnitCache;
  lOptions: TDelphiSemanticModelOptions;
  lFirst, lSecond: TDelphiSemanticUnitCacheAccessResult;
  lItem: TDelphiSemanticSourceText;
  lPath, lOriginal, lChanged, lChangedHash: string;
begin
  g := Default(TGarbos);
  lPath := ObservationPath('CacheRace.pas');
  lOriginal := 'unit Original; interface implementation end.';
  lChanged := 'unit Changed; interface implementation end.';
  WriteUtf8Bytes(lPath, lOriginal);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lPath;
  lOptions.ProjectContextApplied := True;
  GC(lCache, TDelphiSemanticUnitCache.Create(Default(TDelphiSemanticCacheOptions)), g);
  lFirst := lCache.GetOrBuildUnitModelWithStatus(lOptions,
    function(const aOptions: TDelphiSemanticModelOptions): TDelphiSemanticUnitModel
    begin
      WriteUtf8Bytes(aOptions.SourceFileName, lChanged);
      lChangedHash := THashSHA2.GetHashStringFromFile(aOptions.SourceFileName);
      Result := TDelphiSemanticUnitModelExtractor.ExtractFromFile(aOptions);
    end);
  Assert.AreEqual('Changed', lFirst.Model.UnitName);
  Assert.IsNotNull(lFirst.Model.SourceObservations);
  Assert.IsTrue(lFirst.Model.SourceObservations.TryFind(lPath, lItem));
  Assert.AreEqual(lChangedHash, lItem.ContentHash);
  Assert.AreNotEqual(lFirst.Identity.FileHash, lItem.ContentHash);
  WriteUtf8Bytes(lPath, lOriginal);
  lSecond := lCache.GetOrExtractUnitModelWithStatus(lOptions);
  Assert.IsFalse(lSecond.CacheHit, 'A model must not be cached under bytes observed before extraction.');
  Assert.AreEqual('Original', lSecond.Model.UnitName);
end;

procedure TSourceLoaderTests.PersistedModelsDoNotInventSourceObservations;
var
  g: TGarbos;
  lCache: TDelphiSemanticSqliteUnitCache;
  lCacheOptions: TDelphiSemanticCacheOptions;
  lOptions: TDelphiSemanticModelOptions;
  lFirst, lSecond: TDelphiSemanticUnitCacheAccessResult;
  lPath: string;
begin
  g := Default(TGarbos);
  lPath := ObservationPath('Persisted.pas');
  WriteUtf8Bytes(lPath, 'unit Persisted; interface implementation end.');
  lCacheOptions := Default(TDelphiSemanticCacheOptions);
  lCacheOptions.SqliteCacheFileName := TPath.Combine(ExtractFilePath(lPath), 'models.sqlite3');
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lPath;
  lOptions.ProjectContextApplied := True;
  GC(lCache, TDelphiSemanticSqliteUnitCache.Create(lCacheOptions), g);
  lFirst := lCache.GetOrExtractUnitModelWithStatus(lOptions);
  Assert.IsNotNull(lFirst.Model.SourceObservations);
  g.Clear;
  GC(lCache, TDelphiSemanticSqliteUnitCache.Create(lCacheOptions), g);
  lSecond := lCache.GetOrExtractUnitModelWithStatus(lOptions);
  Assert.IsTrue(lSecond.CacheHit);
  Assert.IsNull(lSecond.Model.SourceObservations,
    'A legacy serialized model has no co-produced observation evidence.');
end;

procedure TSourceLoaderTests.CacheRefreshesEqualTextIncludeByteEvidence;
var
  g: TGarbos;
  lCache: TDelphiSemanticUnitCache;
  lOptions: TDelphiSemanticModelOptions;
  lFirst, lSecond: TDelphiSemanticUnitCacheAccessResult;
  lBefore, lAfter: TDelphiSemanticSourceText;
  lPath, lInclude: string;
begin
  g := Default(TGarbos);
  lPath := ObservationPath('ByteCache.pas');
  lInclude := TPath.Combine(ExtractFilePath(lPath), 'ByteCache.inc');
  WriteUtf8Bytes(lPath, 'unit ByteCache; interface {$I ByteCache.inc} implementation end.');
  WriteUtf8Bytes(lInclude, 'type TObserved = Integer;');
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lPath;
  lOptions.ProjectContextApplied := True;
  GC(lCache, TDelphiSemanticUnitCache.Create(Default(TDelphiSemanticCacheOptions)), g);
  lFirst := lCache.GetOrExtractUnitModelWithStatus(lOptions);
  Assert.IsTrue(lFirst.Model.SourceObservations.TryFind(lInclude, lBefore));
  TFile.WriteAllText(lInclude, 'type TObserved = Integer;', TEncoding.Unicode);
  lSecond := lCache.GetOrExtractUnitModelWithStatus(lOptions);
  Assert.AreEqual(lFirst.Identity.UnitCacheKey, lSecond.Identity.UnitCacheKey,
    'The legacy key hashes decoded include text.');
  Assert.IsFalse(lSecond.CacheHit, 'Byte evidence must refresh even when decoded text is unchanged.');
  Assert.IsTrue(lSecond.Model.SourceObservations.TryFind(lInclude, lAfter));
  Assert.AreEqual(lBefore.Text, lAfter.Text);
  Assert.AreNotEqual(lBefore.ContentHash, lAfter.ContentHash);
  Assert.AreEqual(THashSHA2.GetHashStringFromFile(lInclude), lAfter.ContentHash);
end;

procedure TSourceLoaderTests.ObservationMergeOrderIsDeterministic;
var
  lFirst, lSecond: TDelphiSemanticSourceLoadResult;
  lForward, lReverse: IDelphiSemanticSourceObservations;
  lPath, lOtherPath, lError: string;
begin
  lPath := ObservationPath('A.pas');
  lOtherPath := TPath.Combine(ExtractFilePath(lPath), 'B.pas');
  WriteUtf8Bytes(lPath, 'first');
  WriteUtf8Bytes(lOtherPath, 'second');
  lFirst := TDelphiSemanticSourceLoader.LoadFile(lPath);
  lSecond := TDelphiSemanticSourceLoader.LoadFile(lOtherPath);
  Assert.IsTrue(TDelphiSemanticSourceEvidence.TryMerge(lFirst.SourceObservations,
    lSecond.SourceObservations, lForward, lError), lError);
  Assert.IsTrue(TDelphiSemanticSourceEvidence.TryMerge(lSecond.SourceObservations,
    lFirst.SourceObservations, lReverse, lError), lError);
  Assert.AreEqual(lForward.Items[0].FileName, lReverse.Items[0].FileName);
  Assert.AreEqual(lForward.Items[1].FileName, lReverse.Items[1].FileName);
  Assert.AreEqual(lPath, lForward.Items[0].FileName);
end;

procedure TSourceLoaderTests.RepeatedPreprocessDoesNotRetainEarlierObservations;
var
  lOptions: TDelphiSemanticPreprocessOptions;
  lResult: TDelphiSemanticPreprocessResult;
  lPath: string;
begin
  lPath := ObservationPath('Repeated.pas');
  WriteUtf8Bytes(lPath, 'unit Repeated; interface implementation end.');
  lOptions := Default(TDelphiSemanticPreprocessOptions);
  lOptions.SourceFileName := lPath;
  lResult := TDelphiSemanticPreprocessor.PreprocessFile(lOptions);
  Assert.IsTrue(lResult.Success);
  Assert.IsNotNull(lResult.SourceObservations);
  lOptions.SourceText := 'unit Supplied; interface implementation end.';
  lResult := TDelphiSemanticPreprocessor.PreprocessFile(lOptions);
  Assert.IsTrue(lResult.Success);
  Assert.IsNull(lResult.SourceObservations,
    'Supplied text has no byte read and cannot inherit previous evidence.');
end;

procedure TSourceLoaderTests.FailedLoadDoesNotRetainEarlierObservations;
var
  lResult: TDelphiSemanticSourceLoadResult;
  lPath: string;
begin
  lPath := ObservationPath('Loaded.pas');
  WriteUtf8Bytes(lPath, 'unit Loaded; interface implementation end.');
  lResult := TDelphiSemanticSourceLoader.LoadFile(lPath);
  Assert.IsTrue(lResult.Success);
  Assert.IsNotNull(lResult.SourceObservations);
  lResult := TDelphiSemanticSourceLoader.LoadFile(
    TPath.Combine(ExtractFilePath(lPath), 'Missing.pas'));
  Assert.IsFalse(lResult.Success);
  Assert.IsNull(lResult.SourceObservations,
    'A failed read cannot inherit evidence from an earlier successful read.');
end;

procedure TSourceLoaderTests.LoadFileReportsLfLineEndingProvenance;
var
  lPath: string;
  lResult: TDelphiSemanticSourceLoadResult;
begin
  lPath := TempPath('source-loader-lf.pas');
  WriteUtf8Bytes(lPath, 'unit SourceLoaderLf;' + #10 + 'interface' + #10 +
    'implementation' + #10 + 'end.');

  lResult := TDelphiSemanticSourceLoader.LoadFile(lPath);

  Assert.IsTrue(lResult.Success);
  Assert.AreEqual('utf-8', lResult.Source.EncodingName);
  Assert.AreEqual('lf', lResult.Source.LineEndingName);
  Assert.AreEqual(#10, lResult.Source.LineBreak);
end;

procedure TSourceLoaderTests.LoadFileReportsMixedLineEndingProvenance;
var
  lPath: string;
  lResult: TDelphiSemanticSourceLoadResult;
begin
  lPath := TempPath('source-loader-mixed.pas');
  WriteUtf8Bytes(lPath, 'unit SourceLoaderMixed;' + #10 + 'interface' + #13#10 +
    'implementation' + #10 + 'end.');

  lResult := TDelphiSemanticSourceLoader.LoadFile(lPath);

  Assert.IsTrue(lResult.Success);
  Assert.AreEqual('utf-8', lResult.Source.EncodingName);
  Assert.AreEqual('mixed', lResult.Source.LineEndingName);
  Assert.AreEqual(#10, lResult.Source.LineBreak,
    'Mixed source should expose the first observed line break for writers.');
end;

procedure TSourceLoaderTests.LoadFileReportsByteContentHash;
var
  lPath: string;
  lResult: TDelphiSemanticSourceLoadResult;
begin
  lPath := TempPath('source-loader-hash.pas');
  WriteUtf8Bytes(lPath, 'unit SourceLoaderHash;' + #13#10 + 'interface' + #13#10 +
    'implementation' + #13#10 + 'end.');

  lResult := TDelphiSemanticSourceLoader.LoadFile(lPath);

  Assert.IsTrue(lResult.Success);
  Assert.AreEqual(THashSHA2.GetHashStringFromFile(lPath), lResult.Source.ContentHash);
end;

procedure TSourceLoaderTests.UnitModelCarriesSourceLoaderProvenance;
var
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lPath: string;
begin
  lPath := TempPath('source-loader-model.pas');
  WriteUtf8Bytes(lPath, 'unit SourceLoaderModel;' + #10 + 'interface' + #10 +
    'implementation' + #10 + 'end.');
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lPath;
  lOptions.ProjectContextApplied := True;

  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsTrue(lModel.Success);
  Assert.AreEqual('utf-8', lModel.EncodingName);
  Assert.AreEqual('lf', lModel.LineEndingName);
  Assert.AreEqual(#10, lModel.LineBreak);
end;

procedure TSourceLoaderTests.SourceContextUsesLoaderLineBreakForMixedSource;
var
  lCache: TDelphiSemanticSourceContextCache;
  lPath: string;
begin
  lPath := TempPath('source-context-mixed.pas');
  WriteUtf8Bytes(lPath, 'unit SourceContextMixed;' + #10 + 'interface' + #13#10 +
    'implementation' + #10 + 'end.');
  lCache := TDelphiSemanticSourceContextCache.Create;
  try
    Assert.AreEqual(#10, lCache.LineBreakForFile(lPath));
  finally
    lCache.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TSourceLoaderTests);

end.
