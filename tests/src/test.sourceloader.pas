unit Test.SourceLoader;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TSourceLoaderTests = class
  private
    function TempPath(const aName: string): string;
  public
    [Test]
    procedure LoadFileReportsLfLineEndingProvenance;
    [Test]
    procedure LoadFileReportsMixedLineEndingProvenance;
    [Test]
    procedure UnitModelCarriesSourceLoaderProvenance;
    [Test]
    procedure SourceContextUsesLoaderLineBreakForMixedSource;
  end;

implementation

uses
  System.IOUtils, System.SysUtils,
  DelphiSemantics.Model, DelphiSemantics.Source, DelphiSemantics.SourceContext;

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
