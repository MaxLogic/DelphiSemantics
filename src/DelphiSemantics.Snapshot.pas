unit DelphiSemantics.Snapshot;

interface

uses
  System.Generics.Collections, MaxLogic.FastList;

type
  TSemanticStringId = Cardinal;
  TSemanticUnitId = Cardinal;
  TSemanticSymbolId = Cardinal;
  TSemanticWithId = Cardinal;
  TSemanticReferenceId = Cardinal;

  TSemanticSymbolFact = record
    Id: TSemanticSymbolId;
    UnitId: TSemanticUnitId;
    NameId: TSemanticStringId;
    OwnerTypeId: TSemanticStringId;
    TypeId: TSemanticStringId;
    RoutineId: TSemanticStringId;
    KindId: TSemanticStringId;
    Flags: Cardinal;
    Line: Integer;
    Column: Integer;
    EndLine: Integer;
    EndColumn: Integer;
  end;

  TSemanticWithStatementFact = record
    Id: TSemanticWithId;
    UnitId: TSemanticUnitId;
    RoutineId: TSemanticStringId;
    SelectorStartLine: Integer;
    SelectorStartColumn: Integer;
    BodyStartLine: Integer;
    BodyStartColumn: Integer;
    BodyEndLine: Integer;
    BodyEndColumn: Integer;
    Flags: Cardinal;
  end;

  TSemanticReferenceFact = record
    Id: TSemanticReferenceId;
    UnitId: TSemanticUnitId;
    WithId: TSemanticWithId;
    NameId: TSemanticStringId;
    ReceiverTypeId: TSemanticStringId;
    TypeId: TSemanticStringId;
    ClassificationId: TSemanticStringId;
    LookupSourceId: TSemanticStringId;
    ReasonId: TSemanticStringId;
    Line: Integer;
    Column: Integer;
    EndLine: Integer;
    EndColumn: Integer;
  end;

  TSemanticStringPool = class
  private
    fIdByText: TDictionary<string, TSemanticStringId>;
    fTextById: TSimpleList<string>;
    function GetCount: Cardinal;
  public
    constructor Create;
    destructor Destroy; override;
    function Intern(const aText: string): TSemanticStringId;
    function TextOf(const aId: TSemanticStringId): string;
    property Count: Cardinal read GetCount;
  end;

  TUnitSnapshot = class
  private
    fReferences: TSimpleList<TSemanticReferenceFact>;
    fReferencesByWithId: TSortedList<TSemanticWithId, TSemanticReferenceId>;
    fSymbols: TSimpleList<TSemanticSymbolFact>;
    fUnitId: TSemanticUnitId;
    fWithBySourceLine: TSortedList<Integer, TSemanticWithId>;
    fWithStatements: TSimpleList<TSemanticWithStatementFact>;
    function GetReferenceCount: Integer;
    function GetSymbolCount: Integer;
    function GetWithStatementCount: Integer;
  public
    constructor Create(const aUnitId: TSemanticUnitId);
    destructor Destroy; override;
    function AddReference(const aReference: TSemanticReferenceFact): TSemanticReferenceId;
    function AddSymbol(const aSymbol: TSemanticSymbolFact): TSemanticSymbolId;
    function AddWithStatement(const aWith: TSemanticWithStatementFact): TSemanticWithId;
    function ReferenceById(const aId: TSemanticReferenceId): TSemanticReferenceFact;
    function ReferenceIdByWithIndex(const aIndex: Integer): TSemanticReferenceId;
    function SymbolById(const aId: TSemanticSymbolId): TSemanticSymbolFact;
    function TryReferencesForWith(const aWithId: TSemanticWithId; out aLowIndex,
      aHighIndex: Integer): Boolean;
    function TryWithStatementsAtLine(const aLine: Integer; out aLowIndex,
      aHighIndex: Integer): Boolean;
    function WithIdBySourceLineIndex(const aIndex: Integer): TSemanticWithId;
    function WithStatementById(const aId: TSemanticWithId): TSemanticWithStatementFact;
    property ReferenceCount: Integer read GetReferenceCount;
    property SymbolCount: Integer read GetSymbolCount;
    property UnitId: TSemanticUnitId read fUnitId;
    property WithStatementCount: Integer read GetWithStatementCount;
  end;

function MemberKey(const aOwnerTypeId, aNameId: Cardinal): UInt64; inline;

implementation

uses
  MaxLogic.StrUtils;

function MemberKey(const aOwnerTypeId, aNameId: Cardinal): UInt64;
begin
  Result := (UInt64(aOwnerTypeId) shl 32) or UInt64(aNameId);
end;

constructor TSemanticStringPool.Create;
begin
  inherited;
  try
    fTextById := TSimpleList<string>.Create;
    fTextById.add('');
    fIdByText := TDictionary<string, TSemanticStringId>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
    fIdByText.Add('', 0);
  except
    fIdByText.Free;
    fTextById.Free;
    raise;
  end;
end;

destructor TSemanticStringPool.Destroy;
begin
  fIdByText.Free;
  fTextById.Free;
  inherited;
end;

function TSemanticStringPool.GetCount: Cardinal;
begin
  Result := Cardinal(fTextById.Count - 1);
end;

function TSemanticStringPool.Intern(const aText: string): TSemanticStringId;
begin
  if aText = '' then
    Exit(0);

  if fIdByText.TryGetValue(aText, Result) then
    Exit;

  Result := Cardinal(fTextById.Count);
  fTextById.add(aText);
  fIdByText.Add(aText, Result);
end;

function TSemanticStringPool.TextOf(const aId: TSemanticStringId): string;
begin
  if aId < Cardinal(fTextById.Count) then
    Result := fTextById[Integer(aId)]
  else
    Result := '';
end;

constructor TUnitSnapshot.Create(const aUnitId: TSemanticUnitId);
begin
  inherited Create;
  fUnitId := aUnitId;
  try
    fSymbols := TSimpleList<TSemanticSymbolFact>.Create;
    fWithStatements := TSimpleList<TSemanticWithStatementFact>.Create;
    fReferences := TSimpleList<TSemanticReferenceFact>.Create;
    fReferencesByWithId := TSortedList<TSemanticWithId, TSemanticReferenceId>.Create;
    fWithBySourceLine := TSortedList<Integer, TSemanticWithId>.Create;
  except
    fWithBySourceLine.Free;
    fReferencesByWithId.Free;
    fReferences.Free;
    fWithStatements.Free;
    fSymbols.Free;
    raise;
  end;
end;

destructor TUnitSnapshot.Destroy;
begin
  fWithBySourceLine.Free;
  fReferencesByWithId.Free;
  fReferences.Free;
  fWithStatements.Free;
  fSymbols.Free;
  inherited;
end;

function TUnitSnapshot.AddReference(
  const aReference: TSemanticReferenceFact): TSemanticReferenceId;
var
  lReference: TSemanticReferenceFact;
begin
  Result := TSemanticReferenceId(fReferences.Count + 1);
  lReference := aReference;
  lReference.Id := Result;
  lReference.UnitId := fUnitId;
  fReferences.add(lReference);

  if lReference.WithId <> 0 then
    fReferencesByWithId.add(Result, lReference.WithId);
end;

function TUnitSnapshot.AddSymbol(const aSymbol: TSemanticSymbolFact): TSemanticSymbolId;
var
  lSymbol: TSemanticSymbolFact;
begin
  Result := TSemanticSymbolId(fSymbols.Count + 1);
  lSymbol := aSymbol;
  lSymbol.Id := Result;
  lSymbol.UnitId := fUnitId;
  fSymbols.add(lSymbol);
end;

function TUnitSnapshot.AddWithStatement(
  const aWith: TSemanticWithStatementFact): TSemanticWithId;
var
  lEndLine: Integer;
  lLine: Integer;
  lStartLine: Integer;
  lWith: TSemanticWithStatementFact;
begin
  Result := TSemanticWithId(fWithStatements.Count + 1);
  lWith := aWith;
  lWith.Id := Result;
  lWith.UnitId := fUnitId;
  fWithStatements.add(lWith);

  lStartLine := lWith.BodyStartLine;
  if lStartLine <= 0 then
    lStartLine := lWith.SelectorStartLine;
  lEndLine := lWith.BodyEndLine;
  if lEndLine < lStartLine then
    lEndLine := lStartLine;

  if lStartLine > 0 then
    for lLine := lStartLine to lEndLine do
    begin
      fWithBySourceLine.add(Result, lLine);
    end;
end;

function TUnitSnapshot.GetReferenceCount: Integer;
begin
  Result := fReferences.Count;
end;

function TUnitSnapshot.GetSymbolCount: Integer;
begin
  Result := fSymbols.Count;
end;

function TUnitSnapshot.GetWithStatementCount: Integer;
begin
  Result := fWithStatements.Count;
end;

function TUnitSnapshot.ReferenceById(
  const aId: TSemanticReferenceId): TSemanticReferenceFact;
begin
  if (aId = 0) or (aId > TSemanticReferenceId(fReferences.Count)) then
    Exit(Default(TSemanticReferenceFact));

  Result := fReferences[Integer(aId) - 1];
end;

function TUnitSnapshot.ReferenceIdByWithIndex(
  const aIndex: Integer): TSemanticReferenceId;
begin
  Result := fReferencesByWithId[aIndex];
end;

function TUnitSnapshot.SymbolById(const aId: TSemanticSymbolId): TSemanticSymbolFact;
begin
  if (aId = 0) or (aId > TSemanticSymbolId(fSymbols.Count)) then
    Exit(Default(TSemanticSymbolFact));

  Result := fSymbols[Integer(aId) - 1];
end;

function TUnitSnapshot.TryReferencesForWith(const aWithId: TSemanticWithId; out aLowIndex,
  aHighIndex: Integer): Boolean;
begin
  Result := fReferencesByWithId.FindMinMaxIndex(aWithId, aLowIndex, aHighIndex);
end;

function TUnitSnapshot.TryWithStatementsAtLine(const aLine: Integer; out aLowIndex,
  aHighIndex: Integer): Boolean;
begin
  if aLine <= 0 then
    Exit(False);

  Result := fWithBySourceLine.FindMinMaxIndex(aLine, aLowIndex, aHighIndex);
end;

function TUnitSnapshot.WithIdBySourceLineIndex(const aIndex: Integer): TSemanticWithId;
begin
  Result := fWithBySourceLine[aIndex];
end;

function TUnitSnapshot.WithStatementById(
  const aId: TSemanticWithId): TSemanticWithStatementFact;
begin
  if (aId = 0) or (aId > TSemanticWithId(fWithStatements.Count)) then
    Exit(Default(TSemanticWithStatementFact));

  Result := fWithStatements[Integer(aId) - 1];
end;

end.
