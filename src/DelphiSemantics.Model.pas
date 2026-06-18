unit DelphiSemantics.Model;

interface

type
  TDelphiSemanticModelOptions = record
    SourceFileName: string;
    Defines: TArray<string>;
    SearchPaths: TArray<string>;
    ProjectContextApplied: Boolean;
    SkipBodyAnalysis: Boolean;
    SkipReferenceExtraction: Boolean;
    WithStatementsOnly: Boolean;
  end;

  TDelphiSemanticModelDiagnostic = record
    Code: string;
    Message: string;
    FileName: string;
    Line: Integer;
  end;

  TDelphiSemanticDeclaration = record
    Name: string;
    Kind: string;
    TypeName: string;
    BaseTypeName: string;
    HelperTargetName: string;
    SectionKind: string;
    Line: Integer;
    Column: Integer;
    Offset: Integer;
    EndOffset: Integer;
  end;

  TDelphiSemanticMember = record
    OwnerName: string;
    Name: string;
    Kind: string;
    TypeName: string;
    Visibility: string;
    Signature: string;
    IsIndexed: Boolean;
    IsDefault: Boolean;
    Line: Integer;
    Column: Integer;
    Offset: Integer;
    EndOffset: Integer;
  end;

  TDelphiSemanticParameter = record
    RoutineName: string;
    Name: string;
    TypeName: string;
    Modifier: string;
    Line: Integer;
    Column: Integer;
    Offset: Integer;
    EndOffset: Integer;
  end;

  TDelphiSemanticRoutine = record
    Name: string;
    OwnerName: string;
    SectionKind: string;
    Signature: string;
    ReturnType: string;
    Line: Integer;
    Column: Integer;
    Offset: Integer;
    EndOffset: Integer;
    Parameters: TArray<TDelphiSemanticParameter>;
  end;

  TDelphiSemanticLocal = record
    RoutineName: string;
    Name: string;
    Kind: string;
    TypeName: string;
    Line: Integer;
    Column: Integer;
    Offset: Integer;
    EndOffset: Integer;
  end;

  TDelphiSemanticReference = record
    Name: string;
    RoutineName: string;
    Role: string;
    SectionKind: string;
    Line: Integer;
    Column: Integer;
    Offset: Integer;
    EndOffset: Integer;
    EndLine: Integer;
    EndColumn: Integer;
  end;

  TDelphiSemanticWithStatement = record
    Line: Integer;
    Column: Integer;
    EndLine: Integer;
    EndColumn: Integer;
    BodyLine: Integer;
    BodyColumn: Integer;
    BodyEndLine: Integer;
    BodyEndColumn: Integer;
    SelectorText: string;
    SelectorCount: Integer;
    NestingDepth: Integer;
    HasScopedDeclaration: Boolean;
    BodyText: string;
    Text: string;
  end;

  TDelphiSemanticSourceSections = record
    InterfaceOffset: Integer;
    ImplementationOffset: Integer;
    InitializationOffset: Integer;
    FinalizationOffset: Integer;
  end;

  TDelphiSemanticUnitModelMetrics = record
    ReferenceReconciliationFallbackCount: Integer;
    ReferenceReconciliationNameScanCount: Integer;
    ReferenceOccurrenceTableBuildCount: Integer;
  end;

  TDelphiSemanticUnitModel = record
    Success: Boolean;
    FileName: string;
    UnitName: string;
    SourceText: string;
    EncodingName: string;
    LineEndingName: string;
    LineBreak: string;
    SourceSections: TDelphiSemanticSourceSections;
    InterfaceUses: TArray<string>;
    ImplementationUses: TArray<string>;
    Declarations: TArray<TDelphiSemanticDeclaration>;
    Members: TArray<TDelphiSemanticMember>;
    Routines: TArray<TDelphiSemanticRoutine>;
    Locals: TArray<TDelphiSemanticLocal>;
    References: TArray<TDelphiSemanticReference>;
    WithStatements: TArray<TDelphiSemanticWithStatement>;
    Diagnostics: TArray<TDelphiSemanticModelDiagnostic>;
    Metrics: TDelphiSemanticUnitModelMetrics;
  end;

  TDelphiSemanticUnitModelExtractor = record
  public
    class function TypeBlockAnalysisBuildCount: Integer; static;
    class procedure ResetTypeBlockAnalysisBuildCount; static;
    class function ExtractFromFile(const aOptions: TDelphiSemanticModelOptions):
      TDelphiSemanticUnitModel; static;
  end;

implementation

uses
  DelphiSemantics.Model.Extract;

class function TDelphiSemanticUnitModelExtractor.ExtractFromFile(
  const aOptions: TDelphiSemanticModelOptions): TDelphiSemanticUnitModel;
begin
  Result := TDelphiSemanticUnitModelExtractorImpl.ExtractFromFile(aOptions);
end;

class function TDelphiSemanticUnitModelExtractor.TypeBlockAnalysisBuildCount: Integer;
begin
  Result := TDelphiSemanticUnitModelExtractorImpl.TypeBlockAnalysisBuildCount;
end;

class procedure TDelphiSemanticUnitModelExtractor.ResetTypeBlockAnalysisBuildCount;
begin
  TDelphiSemanticUnitModelExtractorImpl.ResetTypeBlockAnalysisBuildCount;
end;

end.
