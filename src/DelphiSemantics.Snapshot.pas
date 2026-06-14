unit DelphiSemantics.Snapshot;

interface

uses
  System.Generics.Collections,
  MaxLogic.FastList;

type
  TSemanticStringId = Cardinal;
  TSemanticUnitId = Cardinal;
  TSemanticSymbolId = Cardinal;
  TSemanticWithId = Cardinal;
  TSemanticReferenceId = Cardinal;

  TSemanticSymbolRef = record
    UnitId: TSemanticUnitId;
    SymbolId: TSemanticSymbolId;
  end;

  TSemanticReferenceRef = record
    UnitId: TSemanticUnitId;
    ReferenceId: TSemanticReferenceId;
  end;

  TSemanticSymbolFact = record
    Id: TSemanticSymbolId;
    UnitId: TSemanticUnitId;
    NameId: TSemanticStringId;
    OwnerTypeId: TSemanticStringId;
    TypeId: TSemanticStringId;
    RoutineId: TSemanticStringId;
    KindId: TSemanticStringId;
    SectionKindId: TSemanticStringId;
    SourceKindId: TSemanticStringId;
    VisibilityId: TSemanticStringId;
    SignatureId: TSemanticStringId;
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
    TargetUnitId: TSemanticUnitId;
    TargetSymbolId: TSemanticSymbolId;
    NameId: TSemanticStringId;
    ReceiverTypeId: TSemanticStringId;
    TypeId: TSemanticStringId;
    RoutineId: TSemanticStringId;
    SectionKindId: TSemanticStringId;
    SourceKindId: TSemanticStringId;
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
    fFrozen: Boolean;
    fIdByText: TDictionary<string, TSemanticStringId>;
    fTextById: TSimpleList<string>;
    procedure CheckMutable;
    function GetCount: Cardinal;
    procedure Freeze;
  public
    constructor Create; overload;
    constructor Create(const aCaseSensitive: Boolean); overload;
    destructor Destroy; override;
    function Intern(const aText: string): TSemanticStringId;
    function TextOf(const aId: TSemanticStringId): string;
    function TryFindId(const aText: string; out aId: TSemanticStringId): Boolean;
    property Count: Cardinal read GetCount;
  end;

  TUnitSnapshot = class
  private
    fFileNameId: TSemanticStringId;
    fFrozen: Boolean;
    fReferences: TSimpleList<TSemanticReferenceFact>;
    fReferencesByWithId: TSortedList<TSemanticWithId, TSemanticReferenceId>;
    fSymbols: TSimpleList<TSemanticSymbolFact>;
    fUnitId: TSemanticUnitId;
    fUnitNameId: TSemanticStringId;
    fWithBySourceLine: TSortedList<Integer, TSemanticWithId>;
    fWithStatements: TSimpleList<TSemanticWithStatementFact>;
    function GetReferenceCount: Integer;
    function GetSymbolCount: Integer;
    function GetWithStatementCount: Integer;
    procedure CheckMutable;
    procedure Freeze;
  public
    constructor Create(const aUnitId: TSemanticUnitId); overload;
    constructor Create(const aUnitId: TSemanticUnitId; const aFileNameId,
      aUnitNameId: TSemanticStringId); overload;
    destructor Destroy; override;
    function AddReference(const aReference: TSemanticReferenceFact): TSemanticReferenceId;
    function AddSymbol(const aSymbol: TSemanticSymbolFact): TSemanticSymbolId;
    function AddWithStatement(const aWith: TSemanticWithStatementFact): TSemanticWithId;
    function ReferenceById(const aId: TSemanticReferenceId): TSemanticReferenceFact;
    function ReferenceIdByWithIndex(const aIndex: Integer): TSemanticReferenceId;
    function SymbolById(const aId: TSemanticSymbolId): TSemanticSymbolFact;
    function TryFindInnermostWithStatementAtLine(const aLine: Integer;
      out aWithId: TSemanticWithId): Boolean;
    function TryReferencesForWith(const aWithId: TSemanticWithId; out aLowIndex,
      aHighIndex: Integer): Boolean;
    function TryWithStatementsAtLine(const aLine: Integer; out aLowIndex,
      aHighIndex: Integer): Boolean;
    function WithIdBySourceLineIndex(const aIndex: Integer): TSemanticWithId;
    function WithStatementById(const aId: TSemanticWithId): TSemanticWithStatementFact;
    property FileNameId: TSemanticStringId read fFileNameId;
    property ReferenceCount: Integer read GetReferenceCount;
    property SymbolCount: Integer read GetSymbolCount;
    property UnitId: TSemanticUnitId read fUnitId;
    property UnitNameId: TSemanticStringId read fUnitNameId;
    property WithStatementCount: Integer read GetWithStatementCount;
  end;

  TDelphiProjectSnapshot = class;

  IDelphiProjectSnapshotRef = interface
    ['{980333F0-4BEE-4689-904C-9E00C487326A}']
    function Snapshot: TDelphiProjectSnapshot;
  end;

  TDelphiProjectSnapshotBuilder = class
  private
    fExactStrings: TSemanticStringPool;
    fExtensions: TObjectDictionary<string, TObject>;
    fStrings: TSemanticStringPool;
    fUnits: TObjectList<TUnitSnapshot>;
    function GetUnitCount: Integer;
  public
    constructor Create;
    destructor Destroy; override;
    procedure AddUnit(const aUnit: TUnitSnapshot);
    function Build: TDelphiProjectSnapshot;
    procedure SetExtensionOwned(const aName: string; const aExtension: TObject);
    property ExactStrings: TSemanticStringPool read fExactStrings;
    property Strings: TSemanticStringPool read fStrings;
    property UnitCount: Integer read GetUnitCount;
  end;

  TDelphiProjectSnapshot = class
  private
    fExactStrings: TSemanticStringPool;
    fExtensions: TObjectDictionary<string, TObject>;
    fMemberCandidatesByOwnerAndName: TSortedList<UInt64, TSemanticSymbolRef>;
    fMembersByOwnerAndName: TDictionary<UInt64, TSemanticSymbolRef>;
    fReferencesByFileAndLine: TSortedList<UInt64, TSemanticReferenceRef>;
    fReferencesByName: TSortedList<TSemanticStringId, TSemanticReferenceRef>;
    fReferencesBySymbol: TSortedList<UInt64, TSemanticReferenceRef>;
    fRoutineMethodEquivalentsByOwnerAndName: TSortedList<UInt64, TSemanticSymbolRef>;
    fStrings: TSemanticStringPool;
    fSymbolsByFileAndLine: TSortedList<UInt64, TSemanticSymbolRef>;
    fSymbolsByName: TSortedList<TSemanticStringId, TSemanticSymbolRef>;
    fTypesByName: TSortedList<TSemanticStringId, TSemanticSymbolRef>;
    fUnitByFileName: TDictionary<string, TSemanticUnitId>;
    fUnits: TObjectList<TUnitSnapshot>;
    fUnitsById: TDictionary<TSemanticUnitId, TUnitSnapshot>;
    function GetExactStringCount: Cardinal;
    function GetStringCount: Cardinal;
    constructor Create(const aStrings, aExactStrings: TSemanticStringPool;
      const aUnits: TObjectList<TUnitSnapshot>;
      var aExtensions: TObjectDictionary<string, TObject>);
    procedure FreezeUnits(const aUnits: TObjectList<TUnitSnapshot>);
    function GetUnitCount: Integer;
    procedure BuildIndexes(const aStrings: TSemanticStringPool;
      const aUnits: TObjectList<TUnitSnapshot>);
  public
    destructor Destroy; override;
    function ExactTextOf(const aId: TSemanticStringId): string;
    function MemberRefByOwnerAndNameIndex(const aIndex: Integer): TSemanticSymbolRef;
    function ReferenceRefByNameIndex(const aIndex: Integer): TSemanticReferenceRef;
    function ReferenceRefBySymbolIndex(const aIndex: Integer): TSemanticReferenceRef;
    function RoutineMethodEquivalentRefByIndex(const aIndex: Integer): TSemanticSymbolRef;
    function SymbolRefByNameIndex(const aIndex: Integer): TSemanticSymbolRef;
    function TextOf(const aId: TSemanticStringId): string;
    function TryGetExtension(const aName: string; out aExtension: TObject): Boolean;
    function UnitByIndex(const aIndex: Integer): TUnitSnapshot;
    function TryFindMember(const aOwnerTypeId, aNameId: TSemanticStringId;
      out aSymbolRef: TSemanticSymbolRef): Boolean;
    function TryFindMembers(const aOwnerTypeId, aNameId: TSemanticStringId;
      out aLowIndex, aHighIndex: Integer): Boolean;
    function TryFindStringId(const aText: string; out aId: TSemanticStringId): Boolean;
    function TryFindUnitByFileName(const aFileName: string;
      out aUnitId: TSemanticUnitId): Boolean;
    function TryFindUnitById(const aUnitId: TSemanticUnitId; out aUnit: TUnitSnapshot):
      Boolean;
    function TryReferencesByName(const aNameId: TSemanticStringId; out aLowIndex,
      aHighIndex: Integer): Boolean;
    function TryReferencesForSymbol(const aSymbolRef: TSemanticSymbolRef; out aLowIndex,
      aHighIndex: Integer): Boolean;
    function TryRoutineMethodEquivalents(const aSymbol: TSemanticSymbolFact; out aLowIndex,
      aHighIndex: Integer): Boolean;
    function TryReferenceAt(const aFileName: string; const aLine, aColumn: Integer;
      out aReferenceRef: TSemanticReferenceRef): Boolean;
    function TrySymbolsByName(const aNameId: TSemanticStringId; out aLowIndex,
      aHighIndex: Integer): Boolean;
    function TrySymbolAt(const aFileName: string; const aLine, aColumn: Integer;
      out aSymbolRef: TSemanticSymbolRef): Boolean;
    function TryTypesByName(const aNameId: TSemanticStringId; out aLowIndex,
      aHighIndex: Integer): Boolean;
    function TypeRefByNameIndex(const aIndex: Integer): TSemanticSymbolRef;
    property ExactStringCount: Cardinal read GetExactStringCount;
    property StringCount: Cardinal read GetStringCount;
    property UnitCount: Integer read GetUnitCount;
  end;

function MemberKey(const aOwnerTypeId, aNameId: Cardinal): UInt64; inline;
function BorrowProjectSnapshot(const aSnapshot: TDelphiProjectSnapshot):
  IDelphiProjectSnapshotRef;
function SnapshotPublicSymbolKind(const aKind: string): string;

implementation

uses
  System.Generics.Defaults, System.SysUtils,
  MaxLogic.StrUtils;

const
  cSemanticSymbolKindAlias = 'alias';
  cSemanticSymbolKindClass = 'class';
  cSemanticSymbolKindEnum = 'enum';
  cSemanticSymbolKindInterface = 'interface';
  cSemanticSymbolKindObject = 'object';
  cSemanticSymbolKindRecord = 'record';
  cSemanticSymbolKindType = 'type';

type
  TBorrowedProjectSnapshotRef = class(TInterfacedObject, IDelphiProjectSnapshotRef)
  private
    fSnapshot: TDelphiProjectSnapshot;
  public
    constructor Create(const aSnapshot: TDelphiProjectSnapshot);
    function Snapshot: TDelphiProjectSnapshot;
  end;

function MakeReferenceRef(const aUnitId: TSemanticUnitId;
  const aReferenceId: TSemanticReferenceId): TSemanticReferenceRef; inline;
begin
  Result.UnitId := aUnitId;
  Result.ReferenceId := aReferenceId;
end;

function MakeSymbolRef(const aUnitId: TSemanticUnitId;
  const aSymbolId: TSemanticSymbolId): TSemanticSymbolRef; inline;
begin
  Result.UnitId := aUnitId;
  Result.SymbolId := aSymbolId;
end;

function MemberKey(const aOwnerTypeId, aNameId: Cardinal): UInt64;
begin
  Result := (UInt64(aOwnerTypeId) shl 32) or UInt64(aNameId);
end;

function SnapshotPublicSymbolKind(const aKind: string): string;
begin
  if SameText(aKind, cSemanticSymbolKindAlias) then
    Exit('type-alias');

  Result := aKind;
end;

function SymbolRefKey(const aUnitId: TSemanticUnitId; const aSymbolId: TSemanticSymbolId): UInt64; inline;
begin
  Result := (UInt64(aUnitId) shl 32) or UInt64(aSymbolId);
end;

function SymbolIsRoutineMethodEquivalentCandidate(const aStrings: TSemanticStringPool;
  const aSymbol: TSemanticSymbolFact): Boolean;
var
  lKind: string;
begin
  if (aSymbol.OwnerTypeId = 0) or (aSymbol.NameId = 0) then
    Exit(False);

  lKind := aStrings.TextOf(aSymbol.KindId);
  Result := SameText(lKind, 'routine') or SameText(lKind, 'method');
end;

constructor TBorrowedProjectSnapshotRef.Create(const aSnapshot: TDelphiProjectSnapshot);
begin
  inherited Create;
  fSnapshot := aSnapshot;
end;

function TBorrowedProjectSnapshotRef.Snapshot: TDelphiProjectSnapshot;
begin
  Result := fSnapshot;
end;

function BorrowProjectSnapshot(const aSnapshot: TDelphiProjectSnapshot):
  IDelphiProjectSnapshotRef;
begin
  if aSnapshot = nil then
    Exit(nil);

  Result := TBorrowedProjectSnapshotRef.Create(aSnapshot);
end;

function SymbolRefKeyOf(const aSymbolRef: TSemanticSymbolRef): UInt64; inline;
begin
  Result := SymbolRefKey(aSymbolRef.UnitId, aSymbolRef.SymbolId);
end;

function SourceLineKey(const aFileNameId: TSemanticStringId; const aLine: Integer): UInt64; inline;
begin
  Result := (UInt64(aFileNameId) shl 32) or UInt64(Cardinal(aLine));
end;

function SymbolKindIsType(const aStrings: TSemanticStringPool;
  const aKindId: TSemanticStringId): Boolean;
var
  lKind: string;
begin
  lKind := aStrings.TextOf(aKindId);
  Result := SameText(lKind, cSemanticSymbolKindType)
    or SameText(lKind, cSemanticSymbolKindAlias)
    or SameText(lKind, cSemanticSymbolKindClass)
    or SameText(lKind, cSemanticSymbolKindRecord)
    or SameText(lKind, cSemanticSymbolKindInterface)
    or SameText(lKind, cSemanticSymbolKindObject)
    or SameText(lKind, cSemanticSymbolKindEnum);
end;

function SymbolContainsPosition(const aSymbol: TSemanticSymbolFact; const aLine,
  aColumn: Integer): Boolean;
begin
  Result := False;
  if (aLine <= 0) or (aColumn <= 0) then
    Exit;
  if (aSymbol.Line <= 0) or (aSymbol.Column <= 0) then
    Exit;
  if aLine < aSymbol.Line then
    Exit;
  if (aLine = aSymbol.Line) and (aColumn < aSymbol.Column) then
    Exit;
  if aSymbol.EndLine <= 0 then
    Exit(aLine = aSymbol.Line);
  if aLine > aSymbol.EndLine then
    Exit;
  if (aLine = aSymbol.EndLine) and (aSymbol.EndColumn > 0) and (aColumn > aSymbol.EndColumn) then
    Exit;

  Result := True;
end;

constructor TSemanticStringPool.Create;
begin
  Create(False);
end;

constructor TSemanticStringPool.Create(const aCaseSensitive: Boolean);
begin
  inherited Create;
  try
    fTextById := TSimpleList<string>.Create;
    fTextById.add('');
    if aCaseSensitive then
      fIdByText := TDictionary<string, TSemanticStringId>.Create()
    else
      fIdByText := TDictionary<string, TSemanticStringId>.Create(
        TFastCaseAwareComparer.OrdinalIgnoreCase);
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

procedure TSemanticStringPool.CheckMutable;
begin
  if fFrozen then
    raise Exception.Create('Cannot mutate a frozen semantic string pool.');
end;

procedure TSemanticStringPool.Freeze;
begin
  fFrozen := True;
end;

function TSemanticStringPool.GetCount: Cardinal;
begin
  Result := Cardinal(fTextById.Count - 1);
end;

function TSemanticStringPool.Intern(const aText: string): TSemanticStringId;
begin
  CheckMutable;

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

function TSemanticStringPool.TryFindId(const aText: string;
  out aId: TSemanticStringId): Boolean;
begin
  Result := fIdByText.TryGetValue(aText, aId);
end;

procedure TUnitSnapshot.CheckMutable;
begin
  if fFrozen then
    raise Exception.Create('Cannot mutate a frozen unit snapshot.');
end;

constructor TUnitSnapshot.Create(const aUnitId: TSemanticUnitId);
begin
  Create(aUnitId, 0, 0);
end;

constructor TUnitSnapshot.Create(const aUnitId: TSemanticUnitId; const aFileNameId,
  aUnitNameId: TSemanticStringId);
begin
  inherited Create;
  fUnitId := aUnitId;
  fFileNameId := aFileNameId;
  fUnitNameId := aUnitNameId;
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
  CheckMutable;

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
  CheckMutable;

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
  CheckMutable;

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

procedure TUnitSnapshot.Freeze;
begin
  fFrozen := True;
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

function TUnitSnapshot.TryFindInnermostWithStatementAtLine(const aLine: Integer;
  out aWithId: TSemanticWithId): Boolean;
var
  i: Integer;
  lBestRange: Integer;
  lBestStartLine: Integer;
  lCandidateRange: Integer;
  lCandidateStartLine: Integer;
  lCandidateEndLine: Integer;
  lCandidateWithId: TSemanticWithId;
  lHighIndex: Integer;
  lLowIndex: Integer;
  lWith: TSemanticWithStatementFact;
begin
  Result := False;
  aWithId := 0;
  if not TryWithStatementsAtLine(aLine, lLowIndex, lHighIndex) then
    Exit;

  lBestRange := MaxInt;
  lBestStartLine := 0;
  for i := lLowIndex to lHighIndex do
  begin
    lCandidateWithId := WithIdBySourceLineIndex(i);
    lWith := WithStatementById(lCandidateWithId);
    lCandidateStartLine := lWith.BodyStartLine;
    if lCandidateStartLine <= 0 then
      lCandidateStartLine := lWith.SelectorStartLine;
    lCandidateEndLine := lWith.BodyEndLine;
    if lCandidateEndLine < lCandidateStartLine then
      lCandidateEndLine := lCandidateStartLine;
    lCandidateRange := lCandidateEndLine - lCandidateStartLine;

    if (not Result) or (lCandidateRange < lBestRange) or
      ((lCandidateRange = lBestRange) and (lCandidateStartLine > lBestStartLine)) or
      ((lCandidateRange = lBestRange) and (lCandidateStartLine = lBestStartLine) and
      (lCandidateWithId > aWithId)) then
    begin
      Result := True;
      aWithId := lCandidateWithId;
      lBestRange := lCandidateRange;
      lBestStartLine := lCandidateStartLine;
    end;
  end;
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

constructor TDelphiProjectSnapshotBuilder.Create;
begin
  inherited;
  try
    fStrings := TSemanticStringPool.Create;
    fExactStrings := TSemanticStringPool.Create(True);
    fUnits := TObjectList<TUnitSnapshot>.Create(True);
    fExtensions := TObjectDictionary<string, TObject>.Create([doOwnsValues],
      TFastCaseAwareComparer.Ordinal);
  except
    fExtensions.Free;
    fUnits.Free;
    fExactStrings.Free;
    fStrings.Free;
    raise;
  end;
end;

destructor TDelphiProjectSnapshotBuilder.Destroy;
begin
  fExtensions.Free;
  fUnits.Free;
  fExactStrings.Free;
  fStrings.Free;
  inherited;
end;

procedure TDelphiProjectSnapshotBuilder.AddUnit(const aUnit: TUnitSnapshot);
begin
  fUnits.Add(aUnit);
end;

function TDelphiProjectSnapshotBuilder.Build: TDelphiProjectSnapshot;
var
  lNewExactStrings: TSemanticStringPool;
  lNewExtensions: TObjectDictionary<string, TObject>;
  lNewStrings: TSemanticStringPool;
  lNewUnits: TObjectList<TUnitSnapshot>;
begin
  lNewStrings := TSemanticStringPool.Create;
  try
    lNewExactStrings := TSemanticStringPool.Create(True);
    try
      lNewExtensions := TObjectDictionary<string, TObject>.Create([doOwnsValues],
        TFastCaseAwareComparer.Ordinal);
      try
        lNewUnits := TObjectList<TUnitSnapshot>.Create(True);
        try
          Result := TDelphiProjectSnapshot.Create(fStrings, fExactStrings, fUnits,
            fExtensions);
          fStrings := lNewStrings;
          fExactStrings := lNewExactStrings;
          fUnits := lNewUnits;
          fExtensions := lNewExtensions;
          lNewExtensions := nil;
        except
          lNewUnits.Free;
          raise;
        end;
      except
        lNewExtensions.Free;
        raise;
      end;
    except
      lNewExactStrings.Free;
      raise;
    end;
  except
    lNewStrings.Free;
    raise;
  end;
end;

function TDelphiProjectSnapshotBuilder.GetUnitCount: Integer;
begin
  if fUnits = nil then
    Exit(0);

  Result := fUnits.Count;
end;

procedure TDelphiProjectSnapshotBuilder.SetExtensionOwned(const aName: string;
  const aExtension: TObject);
begin
  if Trim(aName) = '' then
    raise Exception.Create('Snapshot extension name must not be empty.');

  if fExtensions.ContainsKey(aName) then
    fExtensions.Remove(aName);
  if aExtension <> nil then
    fExtensions.Add(aName, aExtension);
end;

constructor TDelphiProjectSnapshot.Create(const aStrings,
  aExactStrings: TSemanticStringPool;
  const aUnits: TObjectList<TUnitSnapshot>;
  var aExtensions: TObjectDictionary<string, TObject>);
begin
  inherited Create;
  try
    if aExtensions <> nil then
    begin
      fExtensions := aExtensions;
      aExtensions := nil;
    end else begin
      fExtensions := TObjectDictionary<string, TObject>.Create([doOwnsValues],
        TFastCaseAwareComparer.Ordinal);
    end;
    fUnitsById := TDictionary<TSemanticUnitId, TUnitSnapshot>.Create;
    fUnitByFileName := TDictionary<string, TSemanticUnitId>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
    fMembersByOwnerAndName := TDictionary<UInt64, TSemanticSymbolRef>.Create;
    fMemberCandidatesByOwnerAndName := TSortedList<UInt64, TSemanticSymbolRef>.Create;
    fReferencesByFileAndLine := TSortedList<UInt64, TSemanticReferenceRef>.Create;
    fReferencesByName := TSortedList<TSemanticStringId, TSemanticReferenceRef>.Create;
    fReferencesBySymbol := TSortedList<UInt64, TSemanticReferenceRef>.Create;
    fRoutineMethodEquivalentsByOwnerAndName := TSortedList<UInt64, TSemanticSymbolRef>.Create;
    fSymbolsByFileAndLine := TSortedList<UInt64, TSemanticSymbolRef>.Create;
    fSymbolsByName := TSortedList<TSemanticStringId, TSemanticSymbolRef>.Create;
    fTypesByName := TSortedList<TSemanticStringId, TSemanticSymbolRef>.Create;
    BuildIndexes(aStrings, aUnits);
    aStrings.Freeze;
    aExactStrings.Freeze;
    FreezeUnits(aUnits);
    fStrings := aStrings;
    fExactStrings := aExactStrings;
    fUnits := aUnits;
  except
    fTypesByName.Free;
    fSymbolsByName.Free;
    fSymbolsByFileAndLine.Free;
    fReferencesBySymbol.Free;
    fReferencesByName.Free;
    fReferencesByFileAndLine.Free;
    fRoutineMethodEquivalentsByOwnerAndName.Free;
    fMemberCandidatesByOwnerAndName.Free;
    fMembersByOwnerAndName.Free;
    fUnitByFileName.Free;
    fUnitsById.Free;
    fExtensions.Free;
    raise;
  end;
end;

destructor TDelphiProjectSnapshot.Destroy;
begin
  fTypesByName.Free;
  fSymbolsByName.Free;
  fSymbolsByFileAndLine.Free;
  fReferencesBySymbol.Free;
  fReferencesByName.Free;
  fReferencesByFileAndLine.Free;
  fRoutineMethodEquivalentsByOwnerAndName.Free;
  fMemberCandidatesByOwnerAndName.Free;
  fMembersByOwnerAndName.Free;
  fUnitByFileName.Free;
  fUnitsById.Free;
  fExtensions.Free;
  fUnits.Free;
  fExactStrings.Free;
  fStrings.Free;
  inherited;
end;

function TDelphiProjectSnapshot.ExactTextOf(const aId: TSemanticStringId): string;
begin
  Result := fExactStrings.TextOf(aId);
end;

function TDelphiProjectSnapshot.GetExactStringCount: Cardinal;
begin
  if fExactStrings = nil then
    Exit(0);

  Result := fExactStrings.Count;
end;

procedure TDelphiProjectSnapshot.BuildIndexes(const aStrings: TSemanticStringPool;
  const aUnits: TObjectList<TUnitSnapshot>);
var
  i: Integer;
  lEndLine: Integer;
  lFileName: string;
  lLine: Integer;
  lMemberKey: UInt64;
  lReference: TSemanticReferenceFact;
  lReferenceIndex: Integer;
  lReferenceRef: TSemanticReferenceRef;
  lStartLine: Integer;
  lSymbol: TSemanticSymbolFact;
  lSymbolIndex: Integer;
  lSymbolRef: TSemanticSymbolRef;
  lUnit: TUnitSnapshot;
begin
  for i := 0 to aUnits.Count - 1 do
  begin
    lUnit := aUnits[i];
    fUnitsById.AddOrSetValue(lUnit.UnitId, lUnit);

    lFileName := aStrings.TextOf(lUnit.FileNameId);
    if lFileName <> '' then
      fUnitByFileName.AddOrSetValue(lFileName, lUnit.UnitId);

    for lSymbolIndex := 1 to lUnit.SymbolCount do
    begin
      lSymbol := lUnit.SymbolById(TSemanticSymbolId(lSymbolIndex));
      lSymbolRef := MakeSymbolRef(lUnit.UnitId, lSymbol.Id);

      lStartLine := lSymbol.Line;
      lEndLine := lSymbol.EndLine;
      if lEndLine < lStartLine then
        lEndLine := lStartLine;
      if (lUnit.FileNameId <> 0) and (lStartLine > 0) then
        for lLine := lStartLine to lEndLine do
        begin
          fSymbolsByFileAndLine.Insert(fSymbolsByFileAndLine.Count, lSymbolRef,
            SourceLineKey(lUnit.FileNameId, lLine));
        end;

      if lSymbol.NameId <> 0 then
      begin
        fSymbolsByName.Insert(fSymbolsByName.Count, lSymbolRef, lSymbol.NameId);
        if SymbolKindIsType(aStrings, lSymbol.KindId) then
          fTypesByName.Insert(fTypesByName.Count, lSymbolRef, lSymbol.NameId);
      end;

      if (lSymbol.OwnerTypeId <> 0) and (lSymbol.NameId <> 0) then
      begin
        lMemberKey := MemberKey(lSymbol.OwnerTypeId, lSymbol.NameId);
        if not fMembersByOwnerAndName.ContainsKey(lMemberKey) then
          fMembersByOwnerAndName.Add(lMemberKey, lSymbolRef);
        fMemberCandidatesByOwnerAndName.Insert(fMemberCandidatesByOwnerAndName.Count,
          lSymbolRef, lMemberKey);
      end;
      if SymbolIsRoutineMethodEquivalentCandidate(aStrings, lSymbol) then
        fRoutineMethodEquivalentsByOwnerAndName.Insert(
          fRoutineMethodEquivalentsByOwnerAndName.Count, lSymbolRef,
          MemberKey(lSymbol.OwnerTypeId, lSymbol.NameId));
    end;

    for lReferenceIndex := 1 to lUnit.ReferenceCount do
    begin
      lReference := lUnit.ReferenceById(TSemanticReferenceId(lReferenceIndex));
      lReferenceRef := MakeReferenceRef(lUnit.UnitId, lReference.Id);
      lStartLine := lReference.Line;
      lEndLine := lReference.EndLine;
      if lEndLine < lStartLine then
        lEndLine := lStartLine;
      if (lUnit.FileNameId <> 0) and (lStartLine > 0) then
        for lLine := lStartLine to lEndLine do
        begin
          fReferencesByFileAndLine.Insert(fReferencesByFileAndLine.Count,
            lReferenceRef, SourceLineKey(lUnit.FileNameId, lLine));
        end;
      if lReference.NameId <> 0 then
        fReferencesByName.Insert(fReferencesByName.Count,
          lReferenceRef, lReference.NameId);
      if (lReference.TargetUnitId <> 0) and (lReference.TargetSymbolId <> 0) then
      begin
        fReferencesBySymbol.Insert(fReferencesBySymbol.Count,
          lReferenceRef, SymbolRefKey(lReference.TargetUnitId, lReference.TargetSymbolId));
      end;
    end;
  end;

  fMemberCandidatesByOwnerAndName.sort;
  fReferencesByFileAndLine.sort;
  fReferencesByName.sort;
  fReferencesBySymbol.sort;
  fRoutineMethodEquivalentsByOwnerAndName.sort;
  fSymbolsByFileAndLine.sort;
  fSymbolsByName.sort;
  fTypesByName.sort;
end;

procedure TDelphiProjectSnapshot.FreezeUnits(const aUnits: TObjectList<TUnitSnapshot>);
var
  i: Integer;
begin
  for i := 0 to aUnits.Count - 1 do
  begin
    aUnits[i].Freeze;
  end;
end;

function TDelphiProjectSnapshot.GetUnitCount: Integer;
begin
  if fUnits = nil then
    Exit(0);

  Result := fUnits.Count;
end;

function TDelphiProjectSnapshot.GetStringCount: Cardinal;
begin
  if fStrings = nil then
    Exit(0);

  Result := fStrings.Count;
end;

function TDelphiProjectSnapshot.MemberRefByOwnerAndNameIndex(
  const aIndex: Integer): TSemanticSymbolRef;
begin
  Result := fMemberCandidatesByOwnerAndName[aIndex];
end;

function TDelphiProjectSnapshot.ReferenceRefByNameIndex(
  const aIndex: Integer): TSemanticReferenceRef;
begin
  Result := fReferencesByName[aIndex];
end;

function TDelphiProjectSnapshot.ReferenceRefBySymbolIndex(
  const aIndex: Integer): TSemanticReferenceRef;
begin
  Result := fReferencesBySymbol[aIndex];
end;

function TDelphiProjectSnapshot.RoutineMethodEquivalentRefByIndex(
  const aIndex: Integer): TSemanticSymbolRef;
begin
  Result := fRoutineMethodEquivalentsByOwnerAndName[aIndex];
end;

function TDelphiProjectSnapshot.SymbolRefByNameIndex(const aIndex: Integer): TSemanticSymbolRef;
begin
  Result := fSymbolsByName[aIndex];
end;

function TDelphiProjectSnapshot.TextOf(const aId: TSemanticStringId): string;
begin
  Result := fStrings.TextOf(aId);
end;

function TDelphiProjectSnapshot.TryGetExtension(const aName: string;
  out aExtension: TObject): Boolean;
begin
  Result := fExtensions.TryGetValue(aName, aExtension);
end;

function TDelphiProjectSnapshot.UnitByIndex(const aIndex: Integer): TUnitSnapshot;
begin
  Result := fUnits[aIndex];
end;

function TDelphiProjectSnapshot.TryFindMember(const aOwnerTypeId,
  aNameId: TSemanticStringId; out aSymbolRef: TSemanticSymbolRef): Boolean;
begin
  Result := fMembersByOwnerAndName.TryGetValue(MemberKey(aOwnerTypeId, aNameId), aSymbolRef);
end;

function TDelphiProjectSnapshot.TryFindMembers(const aOwnerTypeId,
  aNameId: TSemanticStringId; out aLowIndex, aHighIndex: Integer): Boolean;
begin
  Result := fMemberCandidatesByOwnerAndName.FindMinMaxIndex(MemberKey(aOwnerTypeId, aNameId),
    aLowIndex, aHighIndex);
end;

function TDelphiProjectSnapshot.TryFindStringId(const aText: string;
  out aId: TSemanticStringId): Boolean;
begin
  Result := fStrings.TryFindId(aText, aId);
end;

function TDelphiProjectSnapshot.TryFindUnitByFileName(const aFileName: string;
  out aUnitId: TSemanticUnitId): Boolean;
begin
  Result := fUnitByFileName.TryGetValue(aFileName, aUnitId);
end;

function TDelphiProjectSnapshot.TryFindUnitById(const aUnitId: TSemanticUnitId;
  out aUnit: TUnitSnapshot): Boolean;
begin
  Result := fUnitsById.TryGetValue(aUnitId, aUnit);
end;

function TDelphiProjectSnapshot.TryReferencesByName(const aNameId: TSemanticStringId;
  out aLowIndex, aHighIndex: Integer): Boolean;
begin
  Result := fReferencesByName.FindMinMaxIndex(aNameId, aLowIndex, aHighIndex);
end;

function TDelphiProjectSnapshot.TryReferencesForSymbol(const aSymbolRef: TSemanticSymbolRef;
  out aLowIndex, aHighIndex: Integer): Boolean;
begin
  Result := fReferencesBySymbol.FindMinMaxIndex(SymbolRefKeyOf(aSymbolRef), aLowIndex, aHighIndex);
end;

function TDelphiProjectSnapshot.TryRoutineMethodEquivalents(
  const aSymbol: TSemanticSymbolFact; out aLowIndex, aHighIndex: Integer): Boolean;
begin
  if (aSymbol.OwnerTypeId = 0) or (aSymbol.NameId = 0) then
    Exit(False);

  Result := fRoutineMethodEquivalentsByOwnerAndName.FindMinMaxIndex(
    MemberKey(aSymbol.OwnerTypeId, aSymbol.NameId), aLowIndex, aHighIndex);
end;

function TDelphiProjectSnapshot.TryReferenceAt(const aFileName: string; const aLine,
  aColumn: Integer; out aReferenceRef: TSemanticReferenceRef): Boolean;
var
  i: Integer;
  lEndColumn: Integer;
  lEndLine: Integer;
  lHighIndex: Integer;
  lLowIndex: Integer;
  lReference: TSemanticReferenceFact;
  lReferenceRef: TSemanticReferenceRef;
  lUnit: TUnitSnapshot;
  lUnitId: TSemanticUnitId;
begin
  Result := False;
  aReferenceRef := Default(TSemanticReferenceRef);
  if (aLine <= 0) or (aColumn <= 0) then
    Exit;
  if not TryFindUnitByFileName(aFileName, lUnitId) then
    Exit;
  if not fUnitsById.TryGetValue(lUnitId, lUnit) then
    Exit;

  if not fReferencesByFileAndLine.FindMinMaxIndex(SourceLineKey(lUnit.FileNameId, aLine),
    lLowIndex, lHighIndex) then
    Exit;

  for i := lLowIndex to lHighIndex do
  begin
    lReferenceRef := fReferencesByFileAndLine[i];
    if lReferenceRef.UnitId <> lUnitId then
      Continue;
    lReference := lUnit.ReferenceById(lReferenceRef.ReferenceId);
    if (lReference.Line <= 0) or (lReference.Column <= 0) then
      Continue;
    if aLine < lReference.Line then
      Continue;
    if (aLine = lReference.Line) and (aColumn < lReference.Column) then
      Continue;

    lEndLine := lReference.EndLine;
    if lEndLine <= 0 then
      lEndLine := lReference.Line;
    if aLine > lEndLine then
      Continue;

    lEndColumn := lReference.EndColumn;
    if lEndColumn <= 0 then
      lEndColumn := lReference.Column + Length(fStrings.TextOf(lReference.NameId)) - 1;
    if (aLine = lEndLine) and (lEndColumn > 0) and (aColumn > lEndColumn) then
      Continue;

    aReferenceRef := MakeReferenceRef(lUnit.UnitId, lReference.Id);
    Exit(True);
  end;
end;

function TDelphiProjectSnapshot.TrySymbolsByName(const aNameId: TSemanticStringId;
  out aLowIndex, aHighIndex: Integer): Boolean;
begin
  Result := fSymbolsByName.FindMinMaxIndex(aNameId, aLowIndex, aHighIndex);
end;

function TDelphiProjectSnapshot.TrySymbolAt(const aFileName: string; const aLine,
  aColumn: Integer; out aSymbolRef: TSemanticSymbolRef): Boolean;
var
  i: Integer;
  lHighIndex: Integer;
  lLowIndex: Integer;
  lSymbol: TSemanticSymbolFact;
  lSymbolRef: TSemanticSymbolRef;
  lUnit: TUnitSnapshot;
  lUnitId: TSemanticUnitId;
begin
  Result := False;
  if not TryFindUnitByFileName(aFileName, lUnitId) then
    Exit;
  if not fUnitsById.TryGetValue(lUnitId, lUnit) then
    Exit;

  if not fSymbolsByFileAndLine.FindMinMaxIndex(SourceLineKey(lUnit.FileNameId, aLine),
    lLowIndex, lHighIndex) then
    Exit;

  for i := lLowIndex to lHighIndex do
  begin
    lSymbolRef := fSymbolsByFileAndLine[i];
    if not fUnitsById.TryGetValue(lSymbolRef.UnitId, lUnit) then
      Continue;
    lSymbol := lUnit.SymbolById(lSymbolRef.SymbolId);
    if SymbolContainsPosition(lSymbol, aLine, aColumn) then
    begin
      aSymbolRef := lSymbolRef;
      Exit(True);
    end;
  end;
end;

function TDelphiProjectSnapshot.TryTypesByName(const aNameId: TSemanticStringId;
  out aLowIndex, aHighIndex: Integer): Boolean;
begin
  Result := fTypesByName.FindMinMaxIndex(aNameId, aLowIndex, aHighIndex);
end;

function TDelphiProjectSnapshot.TypeRefByNameIndex(const aIndex: Integer): TSemanticSymbolRef;
begin
  Result := fTypesByName[aIndex];
end;

end.
