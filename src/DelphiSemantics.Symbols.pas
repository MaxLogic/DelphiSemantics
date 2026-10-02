unit DelphiSemantics.Symbols;

interface

type
  TDelphiSemanticSymbolId = record
    Value: string;
  end;

  TDelphiSemanticIndexedSymbol = record
    Id: TDelphiSemanticSymbolId;
    Name: string;
    Kind: string;
    OwnerName: string;
    UnitName: string;
    SectionKind: string;
    SourceKind: string;
    Visibility: string;
    Signature: string;
    FileName: string;
    Line: Integer;
    Column: Integer;
    // A routine's own syntax scope id (DS-660); a nested routine's id holds its parent's.
    ScopeId: string;
    // DS-659: the text comes from an include file, so the position is not a declaration in the
    // unit's own text (it is the include file's, or the include directive's).
    FromInclude: Boolean;
  end;

  TDelphiSemanticIndexedReference = record
    Name: string;
    RoutineName: string;
    Status: string;
    SymbolId: TDelphiSemanticSymbolId;
    CandidateSymbolIds: TArray<TDelphiSemanticSymbolId>;
    Confidence: string;
    UnitName: string;
    SectionKind: string;
    SourceKind: string;
    FileName: string;
    Line: Integer;
    Column: Integer;
    EndLine: Integer;
    EndColumn: Integer;
  end;

implementation

end.
