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
    FileName: string;
    Line: Integer;
    Column: Integer;
  end;

  TDelphiSemanticIndexedReference = record
    Name: string;
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
