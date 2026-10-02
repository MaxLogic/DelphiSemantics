unit DelphiSemantics.Model;

interface

uses
  DelphiSemantics.Source;

type
  TDelphiSemanticModelOptions = record
    SourceFileName: string;
    Defines: TArray<string>;
    SearchPaths: TArray<string>;
    ProjectContextApplied: Boolean;
    SkipBodyAnalysis: Boolean;
    SkipReferenceExtraction: Boolean;
    WithStatementsOnly: Boolean;
    WritableTypedConstants: Boolean;
  end;

  TDelphiSemanticModelDiagnostic = record
    Code: string;
    Message: string;
    FileName: string;
    Line: Integer;
  end;

  TDelphiSemanticSignatureParameter = record
    Name: string;
    TypeName: string;
    Modifier: string;
  end;

  TDelphiSemanticProcedureSignature = record
    Known: Boolean;
    OfObject: Boolean;
    Kind: string;
    CallingConvention: string;
    ReturnType: string;
    Parameters: TArray<TDelphiSemanticSignatureParameter>;
  end;
  TDelphiSemanticDeclaration = record
    Name: string;
    Kind: string;
    TypeName: string;
    InterfaceGuid: string;
    ProcedureSignature: TDelphiSemanticProcedureSignature;
    IsDispInterface: Boolean;
    BaseTypeName: string;
    HelperTargetName: string;
    SectionKind: string;
    Line: Integer;
    Column: Integer;
    Offset: Integer;
    EndOffset: Integer;
    DeclarationRole: string;
    ScopeKind: string;
    OwnerName: string;
    OwnerScopeId: string;
    SymbolId: string;
    Mutable: Boolean;
    // DS-659: the include file whose text holds this fact; empty for the unit's own source.
    // Line and Column then refer to that file (Line 0: the position is unknown).
    FileName: string;
  end;

  TDelphiSemanticMember = record
    OwnerName: string;
    Name: string;
    Kind: string;
    TypeName: string;
    Visibility: string;
    ProcedureSignature: TDelphiSemanticProcedureSignature;
    Signature: string;
    IsIndexed: Boolean;
    IsDefault: Boolean;
    Line: Integer;
    Column: Integer;
    Offset: Integer;
    EndOffset: Integer;
    // DS-659: the include file whose text holds this fact; empty for the unit's own source.
    // Line and Column then refer to that file (Line 0: the position is unknown).
    FileName: string;
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
    // DS-659: the include file whose text holds this fact; empty for the unit's own source.
    // Line and Column then refer to that file (Line 0: the position is unknown).
    FileName: string;
  end;

  TDelphiSemanticRoutine = record
    Name: string;
    OwnerName: string;
    SectionKind: string;
    Signature: string;
    CallingConvention: string;
    ReturnType: string;
    Line: Integer;
    Column: Integer;
    Offset: Integer;
    EndOffset: Integer;
    EndLine: Integer;
    EndColumn: Integer;
    ScopeId: string;
    ParentScopeId: string;
    ProcedureSignature: TDelphiSemanticProcedureSignature;
    Parameters: TArray<TDelphiSemanticParameter>;
    // DS-659: the include file whose text holds this fact; empty for the unit's own source.
    // Line and Column then refer to that file (Line 0: the position is unknown).
    FileName: string;
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
    RoutineScopeId: string;
    // DS-659: the include file whose text holds this fact; empty for the unit's own source.
    // Line and Column then refer to that file (Line 0: the position is unknown).
    FileName: string;
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
    RoutineScopeId: string;
    // DS-659: the include file whose text holds this fact; empty for the unit's own source.
    // Line and Column then refer to that file (Line 0: the position is unknown).
    FileName: string;
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

  TDelphiSemanticUnitDependencyFacts = record
    Known: Boolean;
    InterfaceImports: TArray<string>;
    ImplementationImports: TArray<string>;
    RootImports: TArray<string>;
    HasInitialization: Boolean;
    HasFinalization: Boolean;
    function Clone: TDelphiSemanticUnitDependencyFacts;
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
    SourceObservations: IDelphiSemanticSourceObservations;
    IncludeFileNames: TArray<string>;
    EncodingName: string;
    LineEndingName: string;
    LineBreak: string;
    SourceSections: TDelphiSemanticSourceSections;
    DependencyFacts: TDelphiSemanticUnitDependencyFacts;
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
    ScopeModelStatus: string;
    ScopeModelVersion: string;
    RejectedDeclarationCount: Integer;
  end;

  TDelphiSemanticUnitModelExtractor = record
  public
    class function TypeBlockAnalysisBuildCount: Integer; static;
    class procedure ResetTypeBlockAnalysisBuildCount; static;
    class function ExtractFromFile(const aOptions: TDelphiSemanticModelOptions):
      TDelphiSemanticUnitModel; overload; static;
    class function ExtractFromFile(const aOptions: TDelphiSemanticModelOptions;
      out aObservations: IDelphiSemanticSourceObservations): TDelphiSemanticUnitModel; overload; static;
  end;

implementation

uses
  DelphiSemantics.Model.Extract;

function TDelphiSemanticUnitDependencyFacts.Clone: TDelphiSemanticUnitDependencyFacts;
begin
  Result := Self;
  Result.InterfaceImports := Copy(InterfaceImports);
  Result.ImplementationImports := Copy(ImplementationImports);
  Result.RootImports := Copy(RootImports);
end;

class function TDelphiSemanticUnitModelExtractor.ExtractFromFile(
  const aOptions: TDelphiSemanticModelOptions): TDelphiSemanticUnitModel;
begin
  Result := TDelphiSemanticUnitModelExtractorImpl.ExtractFromFile(aOptions);
end;

class function TDelphiSemanticUnitModelExtractor.ExtractFromFile(
  const aOptions: TDelphiSemanticModelOptions;
  out aObservations: IDelphiSemanticSourceObservations): TDelphiSemanticUnitModel;
begin
  Result := ExtractFromFile(aOptions);
  aObservations := Result.SourceObservations;
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
