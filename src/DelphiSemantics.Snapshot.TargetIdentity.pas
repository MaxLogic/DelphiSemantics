unit DelphiSemantics.Snapshot.TargetIdentity;

interface

uses
  System.Generics.Collections, System.SysUtils,
  DelphiSemantics.Snapshot;

const
  cSnapshotTargetIdentityExtension = 'snapshot-target-identity-v2';

type
  TSnapshotTargetIdentity = record
    FileName: string;
    SymbolHash: string;
  end;

  // Internal cache lineage: numeric symbol slots are meaningful only in this
  // exact ordered symbol list, belonging to this canonical unit file (DS-794).
  TSnapshotTargetIdentities = class
  private
    fRows: TDictionary<TSemanticUnitId, TSnapshotTargetIdentity>;
    fSymbols: TDictionary<UInt64, TSemanticTargetKey>;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Add(const id: TSemanticUnitId; const aFileName, aSymbolHash: string);
    procedure AddSymbol(const aUnitId: TSemanticUnitId; const aSymbolId: TSemanticSymbolId;
      const aKey: TSemanticTargetKey);
    function TryGetSymbol(const aUnitId: TSemanticUnitId; const aSymbolId: TSemanticSymbolId;
      out aKey: TSemanticTargetKey): Boolean;
    function Encode(out aValueCount: Integer): TBytes;
    class function Decode(const aPayload: TBytes; const aValueCount: Int64;
      const aUnit: TUnitSnapshot; const aFileName: string): TSnapshotTargetIdentities; static;
    function TryGet(const id: TSemanticUnitId; out aIdentity: TSnapshotTargetIdentity): Boolean;
  end;

type
  TSnapshotTargetResolver = class
  private type
    TTargetUnit = class
      Snapshot: TDelphiProjectSnapshot;
      UnitSnapshot: TUnitSnapshot;
      SymbolHash: string;
      SymbolIdsByKey: TDictionary<TSemanticTargetKey, TSemanticSymbolId>;
      destructor Destroy; override;
      function FindSymbol(const aKey: TSemanticTargetKey; out id: TSemanticSymbolId): Boolean;
    end;
  private
    fUnits: TObjectDictionary<string, TTargetUnit>;
  public
    constructor Create(const aSnapshots: TArray<TDelphiProjectSnapshot>);
    destructor Destroy; override;
    function TryResolve(const aIdentities: TSnapshotTargetIdentities;
      const aUnitId: TSemanticUnitId; const aSymbolId: TSemanticSymbolId;
      out aTarget: TSemanticSymbolRef): Boolean;
    function HasFile(const aFile: string): Boolean;
  end;

function CalculateStableTargetSymbolKey(const aStrings: TSemanticStringPool;
  const aSymbol: TSemanticSymbolFact): TSemanticTargetKey;
function CalculateOrderedTargetFingerprint(const aStrings: TSemanticStringPool;
  const aUnit: TUnitSnapshot): string;
function SnapshotTargetIdentities(const aSnapshot: TDelphiProjectSnapshot): TSnapshotTargetIdentities;
function BuildSnapshotTargetIdentities(const aSnapshot: TDelphiProjectSnapshot;
  const aUnit: TUnitSnapshot): TSnapshotTargetIdentities;
function SnapshotSymbolHash(const aSnapshot: TDelphiProjectSnapshot; const aUnit: TUnitSnapshot): string;
function CachedSnapshotTargetsMatch(const aSnapshot: TDelphiProjectSnapshot;
  const aResolver: TSnapshotTargetResolver; const aAllowMissing: Boolean;
  const aCurrentFiles: TArray<string>): Boolean;

implementation

uses
  System.Character, System.Generics.Defaults, System.Hash, System.IOUtils,
  MaxLogic.StrUtils,
  DelphiSemantics.Cache, DelphiSemantics.Snapshot.OccurrenceCodec;

type
  TLineageValueReader = record
    Values: TArray<Int64>;
    Position: Integer;
    function Take(const aMaximum: Int64): Int64;
    function TakeText: string;
    function TakeHash: string;
    function TakeKey: TSemanticTargetKey;
  end;

function TLineageValueReader.Take(const aMaximum: Int64): Int64;
begin
  if Position >= Length(Values) then
    raise EInvalidOpException.Create('Snapshot target lineage is truncated.');
  Result := Values[Position];
  Inc(Position);
  if (Result < 0) or (Result > aMaximum) then
    raise EInvalidOpException.Create('Snapshot target lineage value is outside its domain.');
end;

function TLineageValueReader.TakeText: string;
var
  i, lCount: Integer;
  lBytes, lRoundTrip: TBytes;
begin
  lCount := Integer(Take(131068));
  if (lCount = 0) or (lCount > Length(Values) - Position) then
    raise EInvalidOpException.Create('Invalid snapshot target filename length.');
  SetLength(lBytes, lCount);
  for i := 0 to lCount - 1 do
    lBytes[i] := Byte(Take(255));
  Result := TEncoding.UTF8.GetString(lBytes);
  lRoundTrip := TEncoding.UTF8.GetBytes(Result);
  if (Length(lRoundTrip) <> lCount) or not CompareMem(@lBytes[0], @lRoundTrip[0], lCount) or
    (Pos(#0, Result) <> 0) or not TPath.IsPathRooted(Result) or
    (Result <> TDelphiSemanticCacheIdentityBuilder.CanonicalPath(Result)) then
    raise EInvalidOpException.Create('Invalid canonical snapshot target filename.');
end;

function TLineageValueReader.TakeHash: string;
const
  cHexDigits = '0123456789abcdef';
var
  i: Integer;
  b: Byte;
begin
  SetLength(Result, 64);
  for i := 0 to 31 do
  begin
    b := Byte(Take(255));
    Result[i * 2 + 1] := cHexDigits[(b shr 4) + 1];
    Result[i * 2 + 2] := cHexDigits[(b and 15) + 1];
  end;
end;

function TLineageValueReader.TakeKey: TSemanticTargetKey;
var
  i: Integer;
begin
  Result := Default(TSemanticTargetKey);
  Result.Available := Take(1) = 1;
  if Result.Available then
    for i := 0 to High(Result.Digest) do
      Result.Digest[i] := Byte(Take(255));
end;

procedure AppendLineageText(const aValues: TList<Int64>; const aText: string);
var
  b: Byte;
  lBytes: TBytes;
begin
  lBytes := TEncoding.UTF8.GetBytes(aText);
  if (Length(lBytes) = 0) or (Length(lBytes) > 131068) then
    raise EInvalidOpException.Create('Invalid snapshot target filename length.');
  aValues.Add(Length(lBytes));
  for b in lBytes do
    aValues.Add(b);
end;

procedure AppendLineageHash(const aValues: TList<Int64>; const aHash: string);
const
  cHexDigits = '0123456789abcdef';
var
  i, lHigh, lLow: Integer;
begin
  if Length(aHash) <> 64 then
    raise EInvalidOpException.Create('Invalid snapshot target fingerprint.');
  for i := 0 to 31 do
  begin
    lHigh := Pos(aHash[i * 2 + 1], cHexDigits) - 1;
    lLow := Pos(aHash[i * 2 + 2], cHexDigits) - 1;
    if (lHigh < 0) or (lLow < 0) then
      raise EInvalidOpException.Create('Invalid snapshot target fingerprint.');
    aValues.Add(lHigh * 16 + lLow);
  end;
end;

function TSnapshotTargetIdentities.Encode(out aValueCount: Integer): TBytes;
var
  b: Byte;
  id: TSemanticUnitId;
  lIdentity: TSnapshotTargetIdentity;
  lKey: TSemanticTargetKey;
  lSlot: UInt64;
  lSlots: TArray<UInt64>;
  lUnitIds: TArray<TSemanticUnitId>;
  lValues: TList<Int64>;
begin
  lUnitIds := fRows.Keys.ToArray;
  TArray.Sort<TSemanticUnitId>(lUnitIds);
  lSlots := fSymbols.Keys.ToArray;
  TArray.Sort<UInt64>(lSlots);
  lValues := TList<Int64>.Create;
  try
    lValues.Add(Length(lUnitIds));
    lValues.Add(Length(lSlots));
    for id in lUnitIds do
    begin
      lIdentity := fRows[id];
      lValues.Add(id);
      AppendLineageText(lValues, lIdentity.FileName);
      AppendLineageHash(lValues, lIdentity.SymbolHash);
    end;
    for lSlot in lSlots do
    begin
      lValues.Add(lSlot shr 32);
      lValues.Add(lSlot and $FFFFFFFF);
      lKey := fSymbols[lSlot];
      lValues.Add(Ord(lKey.Available));
      if lKey.Available then
        for b in lKey.Digest do
          lValues.Add(b);
    end;
    aValueCount := lValues.Count;
    Result := EncodeOccurrenceValues(lValues.ToArray, 1);
  finally
    lValues.Free;
  end;
end;

class function TSnapshotTargetIdentities.Decode(const aPayload: TBytes; const aValueCount: Int64;
  const aUnit: TUnitSnapshot; const aFileName: string): TSnapshotTargetIdentities;
var
  i, lSymbolCount, lUnitCount: Integer;
  id, lPreviousId: TSemanticUnitId;
  lIdentity: TSnapshotTargetIdentity;
  lKey: TSemanticTargetKey;
  lReader: TLineageValueReader;
  lReference: TSemanticReferenceFact;
  lRequiredSymbols: THashSet<UInt64>;
  lRequiredUnits: THashSet<TSemanticUnitId>;
  lSeenFiles: THashSet<string>;
  lSlot, lPreviousSlot: UInt64;
  lSymbolId: TSemanticSymbolId;
begin
  Result := nil;
  lReader.Values := DecodeOccurrenceValues(aPayload, aValueCount, 1);
  lReader.Position := 0;
  lUnitCount := Integer(lReader.Take(Int64(aUnit.ReferenceCount) + 1));
  lSymbolCount := Integer(lReader.Take(aUnit.ReferenceCount));
  if lUnitCount = 0 then
    raise EInvalidOpException.Create('Snapshot target lineage has no self identity.');
  lRequiredUnits := THashSet<TSemanticUnitId>.Create;
  lRequiredSymbols := THashSet<UInt64>.Create;
  lSeenFiles := THashSet<string>.Create(TFastCaseAwareComparer.Ordinal);
  try
    lRequiredUnits.Add(aUnit.UnitId);
    for i := 1 to aUnit.ReferenceCount do
    begin
      lReference := aUnit.ReferenceById(i);
      if (lReference.TargetUnitId = 0) <> (lReference.TargetSymbolId = 0) then
        raise EInvalidOpException.Create('Incomplete snapshot target association.');
      if lReference.TargetUnitId = 0 then
        Continue;
      lRequiredUnits.Add(lReference.TargetUnitId);
      lRequiredSymbols.Add((UInt64(lReference.TargetUnitId) shl 32) or lReference.TargetSymbolId);
    end;
    if (lUnitCount <> lRequiredUnits.Count) or (lSymbolCount <> lRequiredSymbols.Count) then
      raise EInvalidOpException.Create('Snapshot target lineage count mismatch.');
    Result := TSnapshotTargetIdentities.Create;
    try
      lPreviousId := 0;
      for i := 0 to lUnitCount - 1 do
      begin
        id := TSemanticUnitId(lReader.Take(MaxInt));
        if (id <= lPreviousId) or not lRequiredUnits.Contains(id) then
          raise EInvalidOpException.Create('Unknown or unordered snapshot target unit.');
        lPreviousId := id;
        lIdentity.FileName := lReader.TakeText;
        lIdentity.SymbolHash := lReader.TakeHash;
        if not lSeenFiles.Add(lIdentity.FileName) or ((id = aUnit.UnitId) and
          (lIdentity.FileName <> TDelphiSemanticCacheIdentityBuilder.CanonicalPath(aFileName))) then
          raise EInvalidOpException.Create('Snapshot target canonical identity mismatch.');
        Result.Add(id, lIdentity.FileName, lIdentity.SymbolHash);
      end;
      lPreviousSlot := 0;
      for i := 0 to lSymbolCount - 1 do
      begin
        id := TSemanticUnitId(lReader.Take(MaxInt));
        lSymbolId := TSemanticSymbolId(lReader.Take(MaxInt));
        lSlot := (UInt64(id) shl 32) or lSymbolId;
        if (lSlot <= lPreviousSlot) or not lRequiredSymbols.Contains(lSlot) or
          ((id = aUnit.UnitId) and (lSymbolId > Cardinal(aUnit.SymbolCount))) then
          raise EInvalidOpException.Create('Unknown or unordered snapshot target symbol.');
        lPreviousSlot := lSlot;
        lKey := lReader.TakeKey;
        Result.AddSymbol(id, lSymbolId, lKey);
      end;
      if lReader.Position <> Length(lReader.Values) then
        raise EInvalidOpException.Create('Snapshot target lineage has trailing values.');
    except
      FreeAndNil(Result);
      raise;
    end;
  finally
    lSeenFiles.Free;
    lRequiredSymbols.Free;
    lRequiredUnits.Free;
  end;
end;

constructor TSnapshotTargetIdentities.Create;
begin
  inherited;
  fRows := TDictionary<TSemanticUnitId, TSnapshotTargetIdentity>.Create;
  fSymbols := TDictionary<UInt64, TSemanticTargetKey>.Create;
end;

destructor TSnapshotTargetIdentities.Destroy;
begin
  fSymbols.Free;
  fRows.Free;
  inherited;
end;

procedure TSnapshotTargetIdentities.Add(const id: TSemanticUnitId;
  const aFileName, aSymbolHash: string);
var
  lIdentity: TSnapshotTargetIdentity;
begin
  if (id = 0) or (aFileName = '') or (Length(aSymbolHash) <> 64) then
    raise EArgumentException.Create('Invalid snapshot target identity.');
  lIdentity.FileName := TDelphiSemanticCacheIdentityBuilder.CanonicalPath(aFileName);
  lIdentity.SymbolHash := aSymbolHash;
  fRows.Add(id, lIdentity);
end;

function TSnapshotTargetIdentities.TryGet(const id: TSemanticUnitId;
  out aIdentity: TSnapshotTargetIdentity): Boolean;
begin
  Result := fRows.TryGetValue(id, aIdentity);
end;

procedure TSnapshotTargetIdentities.AddSymbol(const aUnitId: TSemanticUnitId;
  const aSymbolId: TSemanticSymbolId; const aKey: TSemanticTargetKey);
begin
  if (aUnitId = 0) or (aSymbolId = 0) then
    raise EArgumentException.Create('Invalid snapshot target symbol slot.');
  fSymbols.Add((UInt64(aUnitId) shl 32) or aSymbolId, aKey);
end;

function TSnapshotTargetIdentities.TryGetSymbol(const aUnitId: TSemanticUnitId;
  const aSymbolId: TSemanticSymbolId; out aKey: TSemanticTargetKey): Boolean;
begin
  Result := fSymbols.TryGetValue((UInt64(aUnitId) shl 32) or aSymbolId, aKey);
end;

// Match the semantic pool's ordinal, per-character case folding. Pool merges
// can retain another spelling without changing a fact's identity (DS-794).
function SnapshotIdentityText(const aText: string): string;
var
  i: Integer;
begin
  Result := aText;
  for i := 1 to Length(Result) do
    Result[i] := Result[i].ToUpper;
end;

// A name alone never establishes identity. Declarations carry an extractor
// identity; other facts can use their captured lexical routine identity. Facts
// without either witness retain only exact-generation numeric-slot evidence.
function CalculateStableTargetSymbolKey(const aStrings: TSemanticStringPool;
  const aSymbol: TSemanticSymbolFact): TSemanticTargetKey;
var
  lText: TStringBuilder;
  lBytes: TBytes;

  procedure AddText(const id: TSemanticStringId);
  var
    s: string;
  begin
    s := SnapshotIdentityText(aStrings.TextOf(id));
    lText.Append(Length(s)).Append(':').Append(s);
  end;

begin
  Result := Default(TSemanticTargetKey);
  if (aSymbol.SemanticSymbolId = 0) and (aSymbol.RoutineScopeId = 0) then
    Exit;
  lText := TStringBuilder.Create;
  try
    lText.Append('semantic-symbol-v2:');
    AddText(aSymbol.SemanticSymbolId);
    AddText(aSymbol.OwnerScopeId);
    AddText(aSymbol.RoutineScopeId);
    AddText(aSymbol.KindId);
    AddText(aSymbol.NameId);
    AddText(aSymbol.OwnerTypeId);
    AddText(aSymbol.SignatureId);
    AddText(aSymbol.SectionKindId);
    AddText(aSymbol.DeclarationRoleId);
    AddText(aSymbol.FileId);
    lBytes := THashSHA2.GetHashBytes(lText.ToString);
    Move(lBytes[0], Result.Digest[0], SizeOf(Result.Digest));
    Result.Available := True;
  finally
    lText.Free;
  end;
end;

function SnapshotTargetIdentities(const aSnapshot: TDelphiProjectSnapshot): TSnapshotTargetIdentities;
var
  lExtension: TObject;
begin
  Result := nil;
  if (aSnapshot <> nil) and aSnapshot.TryGetExtension(cSnapshotTargetIdentityExtension, lExtension) and
    (lExtension is TSnapshotTargetIdentities) then
    Result := TSnapshotTargetIdentities(lExtension);
end;

function CalculateOrderedTargetFingerprint(const aStrings: TSemanticStringPool;
  const aUnit: TUnitSnapshot): string;
var
  lText: TStringBuilder;
  lSymbol: TSemanticSymbolFact;
  lSymbolId: TSemanticSymbolId;

  procedure AddText(const id: TSemanticStringId);
  var
    s: string;
  begin
    s := SnapshotIdentityText(aStrings.TextOf(id));
    lText.Append(Length(s)).Append(':').Append(s);
  end;

begin
  lText := TStringBuilder.Create;
  try
    lText.Append('ordered-symbols-v2:').Append(aUnit.SymbolCount).Append(':');
    for lSymbolId := 1 to TSemanticSymbolId(aUnit.SymbolCount) do
    begin
      lSymbol := aUnit.SymbolById(lSymbolId);
      AddText(lSymbol.NameId);
      AddText(lSymbol.KindId);
      AddText(lSymbol.OwnerTypeId);
      AddText(lSymbol.TypeId);
      AddText(lSymbol.RoutineId);
      AddText(lSymbol.SectionKindId);
      AddText(lSymbol.SourceKindId);
      AddText(lSymbol.VisibilityId);
      AddText(lSymbol.SignatureId);
      AddText(lSymbol.DeclarationRoleId);
      AddText(lSymbol.ScopeKindId);
      AddText(lSymbol.OwnerScopeId);
      AddText(lSymbol.SemanticSymbolId);
      AddText(lSymbol.RoutineScopeId);
      AddText(lSymbol.FileId);
      lText.Append(lSymbol.Flags).Append(':').Append(lSymbol.Line).Append(':')
        .Append(lSymbol.Column).Append(':').Append(lSymbol.EndLine).Append(':')
        .Append(lSymbol.EndColumn).Append(';');
    end;
    Result := THashSHA2.GetHashString(lText.ToString);
  finally
    lText.Free;
  end;
end;
function SnapshotSymbolHash(const aSnapshot: TDelphiProjectSnapshot;
  const aUnit: TUnitSnapshot): string;
begin
  if aSnapshot = nil then
    raise EArgumentNilException.Create('Snapshot is required for target fingerprint.');
  Result := aUnit.OrderedTargetFingerprint;
end;


function BuildSnapshotTargetIdentities(const aSnapshot: TDelphiProjectSnapshot;
  const aUnit: TUnitSnapshot): TSnapshotTargetIdentities;
var
  lReference: TSemanticReferenceFact;
  lReferenceId: TSemanticReferenceId;

  procedure AddTarget(const aUnitId: TSemanticUnitId; const aSymbolId: TSemanticSymbolId);
  var
    lIdentity: TSnapshotTargetIdentity;
    lKey: TSemanticTargetKey;
    lTargetUnit: TUnitSnapshot;
  begin
    if not aSnapshot.TryFindUnitById(aUnitId, lTargetUnit) then
      raise EInvalidOpException.Create('Snapshot target unit is absent.');
    if not Result.TryGet(aUnitId, lIdentity) then
      Result.Add(aUnitId, aSnapshot.TextOf(lTargetUnit.FileNameId), SnapshotSymbolHash(aSnapshot, lTargetUnit));
    if (aSymbolId <> 0) and not Result.TryGetSymbol(aUnitId, aSymbolId, lKey) then
    begin
      if aSymbolId > Cardinal(lTargetUnit.SymbolCount) then
        raise EInvalidOpException.Create('Snapshot target slot is absent.');
      Result.AddSymbol(aUnitId, aSymbolId,
        lTargetUnit.TargetSymbolKeyById(aSymbolId));
    end;
  end;

begin
  Result := TSnapshotTargetIdentities.Create;
  try
    AddTarget(aUnit.UnitId, 0);
    for lReferenceId := 1 to TSemanticReferenceId(aUnit.ReferenceCount) do
    begin
      lReference := aUnit.ReferenceById(lReferenceId);
      if (lReference.TargetUnitId <> 0) and (lReference.TargetSymbolId <> 0) then
        AddTarget(lReference.TargetUnitId, lReference.TargetSymbolId);
    end;
  except
    Result.Free;
    raise;
  end;
end;

destructor TSnapshotTargetResolver.TTargetUnit.Destroy;
begin
  SymbolIdsByKey.Free;
  inherited;
end;

function TSnapshotTargetResolver.TTargetUnit.FindSymbol(const aKey: TSemanticTargetKey;
  out id: TSemanticSymbolId): Boolean;
var
  lKey: TSemanticTargetKey;
  lSymbolId: TSemanticSymbolId;
begin
  if SymbolIdsByKey = nil then
  begin
    SymbolIdsByKey := TDictionary<TSemanticTargetKey, TSemanticSymbolId>.Create;
    for lSymbolId := 1 to TSemanticSymbolId(UnitSnapshot.SymbolCount) do
    begin
      lKey := UnitSnapshot.TargetSymbolKeyById(lSymbolId);
      if not lKey.Available then
        Continue;
      if SymbolIdsByKey.ContainsKey(lKey) then
        SymbolIdsByKey[lKey] := 0
      else
        SymbolIdsByKey.Add(lKey, lSymbolId);
    end;
  end;
  Result := aKey.Available and SymbolIdsByKey.TryGetValue(aKey, id) and (id <> 0);
end;

constructor TSnapshotTargetResolver.Create(const aSnapshots: TArray<TDelphiProjectSnapshot>);
var
  i: Integer;
  lTarget: TTargetUnit;
begin
  inherited Create;
  fUnits := TObjectDictionary<string, TTargetUnit>.Create([doOwnsValues], TFastCaseAwareComparer.Ordinal);
  for i := 0 to High(aSnapshots) do
    if (aSnapshots[i] <> nil) and (aSnapshots[i].UnitCount = 1) then
    begin
      lTarget := TTargetUnit.Create;
      try
        lTarget.Snapshot := aSnapshots[i];
        lTarget.UnitSnapshot := aSnapshots[i].UnitByIndex(0);
        fUnits.Add(TDelphiSemanticCacheIdentityBuilder.CanonicalPath(
          aSnapshots[i].TextOf(lTarget.UnitSnapshot.FileNameId)), lTarget);
        lTarget := nil;
      finally
        lTarget.Free;
      end;
    end;
end;

destructor TSnapshotTargetResolver.Destroy;
begin
  fUnits.Free;
  inherited;
end;

function TSnapshotTargetResolver.HasFile(const aFile: string): Boolean;
begin
  Result := fUnits.ContainsKey(aFile);
end;

function TSnapshotTargetResolver.TryResolve(const aIdentities: TSnapshotTargetIdentities;
  const aUnitId: TSemanticUnitId; const aSymbolId: TSemanticSymbolId;
  out aTarget: TSemanticSymbolRef): Boolean;
var
  lIdentity: TSnapshotTargetIdentity;
  lKey: TSemanticTargetKey;
  lTarget: TTargetUnit;
begin
  aTarget := Default(TSemanticSymbolRef);
  Result := False;
  if (aIdentities = nil) or not aIdentities.TryGet(aUnitId, lIdentity) or
    not fUnits.TryGetValue(lIdentity.FileName, lTarget) then
    Exit;
  if lTarget.SymbolHash = '' then
    lTarget.SymbolHash := SnapshotSymbolHash(lTarget.Snapshot, lTarget.UnitSnapshot);
  aTarget.UnitId := lTarget.UnitSnapshot.UnitId;
  if aSymbolId = 0 then
    Exit(lIdentity.SymbolHash = lTarget.SymbolHash);
  if not aIdentities.TryGetSymbol(aUnitId, aSymbolId, lKey) then
    Exit;
  if (lIdentity.SymbolHash = lTarget.SymbolHash) and
    (aSymbolId <= Cardinal(lTarget.UnitSnapshot.SymbolCount)) then
  begin
    aTarget.SymbolId := aSymbolId;
    Exit(True);
  end;
  Result := lTarget.FindSymbol(lKey, aTarget.SymbolId);
end;

function CachedSnapshotTargetsMatch(const aSnapshot: TDelphiProjectSnapshot;
  const aResolver: TSnapshotTargetResolver; const aAllowMissing: Boolean;
  const aCurrentFiles: TArray<string>): Boolean;
var
  lIdentity: TSnapshotTargetIdentity;
  lIdentities: TSnapshotTargetIdentities;
  lReference: TSemanticReferenceFact;
  lReferenceId: TSemanticReferenceId;
  lTarget: TSemanticSymbolRef;
  lUnit: TUnitSnapshot;

  function Matches(const id: TSemanticUnitId; const aSymbolId: TSemanticSymbolId): Boolean;
  var
    lFile: string;
    lKey: TSemanticTargetKey;
  begin
    Result := aResolver.TryResolve(lIdentities, id, aSymbolId, lTarget);
    if Result or not aAllowMissing then
      Exit;
    if not lIdentities.TryGet(id, lIdentity) or aResolver.HasFile(lIdentity.FileName) or
      ((aSymbolId <> 0) and not lIdentities.TryGetSymbol(id, aSymbolId, lKey)) then
      Exit;
    for lFile in aCurrentFiles do
      if TDelphiSemanticCacheIdentityBuilder.CanonicalPath(lFile) = lIdentity.FileName then
        Exit(True);
  end;

begin
  Result := False;
  lIdentities := SnapshotTargetIdentities(aSnapshot);
  if (aSnapshot = nil) or (aSnapshot.UnitCount <> 1) or (lIdentities = nil) then
    Exit;
  lUnit := aSnapshot.UnitByIndex(0);
  if not lIdentities.TryGet(lUnit.UnitId, lIdentity) or
    (lIdentity.FileName <> TDelphiSemanticCacheIdentityBuilder.CanonicalPath(
      aSnapshot.TextOf(lUnit.FileNameId))) or not Matches(lUnit.UnitId, 0) then
    Exit;
  for lReferenceId := 1 to TSemanticReferenceId(lUnit.ReferenceCount) do
  begin
    lReference := lUnit.ReferenceById(lReferenceId);
    if (lReference.TargetUnitId = 0) <> (lReference.TargetSymbolId = 0) then
      Exit;
    if (lReference.TargetUnitId <> 0) and not Matches(lReference.TargetUnitId, lReference.TargetSymbolId) then
      Exit;
  end;
  Result := True;
end;

end.
