unit DelphiSemantics.WithScan;

interface

uses
  DelphiSemantics.CompilerDefineEvidence, DelphiSemantics.Model;

type
  TDelphiSemanticWithScanOptions = record
    SourceFileName: string;
    Defines: TArray<string>;
    SearchPaths: TArray<string>;
    IncludePaths: TArray<string>;
    CompilerDefineEvidence: IDelphiSemanticCompilerDefineEvidence;
    CompilerDefineRequest: TDelphiSemanticCompilerDefineRequest;
    ProjectContextApplied: Boolean;
  end;

  TDelphiSemanticWithScanResult = record
    Success: Boolean;
    FileName: string;
    UnitName: string;
    ProjectSessionUsed: Boolean;
    WithStatements: TArray<TDelphiSemanticWithStatement>;
    Diagnostics: TArray<TDelphiSemanticModelDiagnostic>;
  end;

  TDelphiSemanticWithScanner = record
  public
    class function ScanFile(const aOptions: TDelphiSemanticWithScanOptions):
      TDelphiSemanticWithScanResult; static;
  end;

implementation

function ModelOptionsFromWithScanOptions(const aOptions: TDelphiSemanticWithScanOptions):
  TDelphiSemanticModelOptions;
begin
  Result := Default(TDelphiSemanticModelOptions);
  Result.SourceFileName := aOptions.SourceFileName;
  Result.Defines := aOptions.Defines;
  Result.SearchPaths := aOptions.SearchPaths;
  Result.IncludePaths := aOptions.IncludePaths;
  Result.CompilerDefineEvidence := aOptions.CompilerDefineEvidence;
  Result.CompilerDefineRequest := aOptions.CompilerDefineRequest;
  Result.ProjectContextApplied := aOptions.ProjectContextApplied;
  Result.WithStatementsOnly := True;
end;

class function TDelphiSemanticWithScanner.ScanFile(
  const aOptions: TDelphiSemanticWithScanOptions): TDelphiSemanticWithScanResult;
var
  lModel: TDelphiSemanticUnitModel;
begin
  Result := Default(TDelphiSemanticWithScanResult);
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(
    ModelOptionsFromWithScanOptions(aOptions));

  // A selected parse is advisory when an alternative can contain more WITHs.
  // Directive spans are the same expansion-aware uncertainty facts as planning.
  Result.Success := lModel.Success and lModel.DirectiveFacts.Scanned and
    (Length(lModel.DirectiveFacts.Spans) = 0);
  Result.FileName := lModel.FileName;
  Result.UnitName := lModel.UnitName;
  Result.ProjectSessionUsed := False;
  Result.WithStatements := lModel.WithStatements;
  Result.Diagnostics := lModel.Diagnostics;
end;

end.
