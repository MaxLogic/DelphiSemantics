unit DelphiSemantics.Snapshot.OccurrenceCodec;

interface

uses
  System.SysUtils;

const
  cPhysicalReferenceColumnCount = 13;
  cPhysicalSymbolColumnCount = 23;

type
  ESnapshotOccurrenceCodec = class(EInvalidOpException);

// Flat row-major scratch values; counts belong to the unit header, not the BLOB.
// Semantic record validation and pool membership remain the caller's duty.
function EncodeOccurrenceValues(const aValues: TArray<Int64>; const aColumnCount: Integer): TBytes;
function DecodeOccurrenceValues(const aPayload: TBytes; const aRecordCount: Int64;
  const aColumnCount: Integer): TArray<Int64>;

implementation

const
  cOccurrenceFormat = 1;

type
  TOccurrencePredictors = array[0..cPhysicalSymbolColumnCount - 1] of Int64;

procedure CheckColumnCount(const aColumnCount: Integer);
begin
  if (aColumnCount <> 1) and (aColumnCount <> cPhysicalReferenceColumnCount) and
    (aColumnCount <> cPhysicalSymbolColumnCount) then
    raise ESnapshotOccurrenceCodec.Create('SNAPSHOT_OCCURRENCE_COLUMNS_INVALID');
end;

function CheckedDelta(const aCurrent, aPrevious: Int64): Int64;
begin
  if ((aPrevious > 0) and (aCurrent < Low(Int64) + aPrevious)) or
    ((aPrevious < 0) and (aCurrent > High(Int64) + aPrevious)) then
    raise ESnapshotOccurrenceCodec.Create('SNAPSHOT_OCCURRENCE_DELTA_OVERFLOW');
  Result := aCurrent - aPrevious;
end;

function CheckedPredictor(const aPrevious, aDelta: Int64): Int64;
begin
  if ((aDelta > 0) and (aPrevious > High(Int64) - aDelta)) or
    ((aDelta < 0) and (aPrevious < Low(Int64) - aDelta)) then
    raise ESnapshotOccurrenceCodec.Create('SNAPSHOT_OCCURRENCE_PREDICTOR_OVERFLOW');
  Result := aPrevious + aDelta;
end;

function ReadVarUInt(const aPayload: TBytes; var aPosition: NativeInt): UInt64;
var
  b: Byte;
  i: Integer;
begin
  Result := 0;
  for i := 0 to 9 do
  begin
    if aPosition >= Length(aPayload) then
      raise ESnapshotOccurrenceCodec.Create('SNAPSHOT_OCCURRENCE_TRUNCATED');
    b := aPayload[aPosition];
    Inc(aPosition);
    // Byte ten has one payload bit and cannot continue. Check before shifting.
    if (i = 9) and ((b and $FE) <> 0) then
      raise ESnapshotOccurrenceCodec.Create('SNAPSHOT_OCCURRENCE_VARINT_OVERFLOW');
    Result := Result or (UInt64(b and $7F) shl (i * 7));
    if (b and $80) = 0 then
    begin
      if (i > 0) and ((b and $7F) = 0) then
        raise ESnapshotOccurrenceCodec.Create('SNAPSHOT_OCCURRENCE_VARINT_NONMINIMAL');
      Exit;
    end;
  end;
  raise ESnapshotOccurrenceCodec.Create('SNAPSHOT_OCCURRENCE_VARINT_OVERFLOW');
end;

function EncodeOccurrenceValues(const aValues: TArray<Int64>; const aColumnCount: Integer): TBytes;
var
  lColumn: Integer;
  lDelta: Int64;
  lEncoded: UInt64;
  lIndex, lPosition: NativeInt;
  lPrevious: TOccurrencePredictors;
begin
  CheckColumnCount(aColumnCount);
  if (Length(aValues) mod aColumnCount) <> 0 then
    raise ESnapshotOccurrenceCodec.Create('SNAPSHOT_OCCURRENCE_COLUMNS_INCOMPLETE');
  if Length(aValues) > (High(NativeInt) - 1) div 10 then
    raise ESnapshotOccurrenceCodec.Create('SNAPSHOT_OCCURRENCE_PAYLOAD_UNADDRESSABLE');
  SetLength(Result, 1 + Length(aValues) * 10);
  Result[0] := cOccurrenceFormat;
  lPosition := 1;
  lPrevious := Default(TOccurrencePredictors);
  for lIndex := 0 to High(aValues) do
  begin
    lColumn := Integer(lIndex mod aColumnCount);
    lDelta := CheckedDelta(aValues[lIndex], lPrevious[lColumn]);
    lPrevious[lColumn] := aValues[lIndex];
    if lDelta >= 0 then
      lEncoded := UInt64(lDelta) shl 1
    else
      // Adding one before negation also handles Low(Int64) without overflow.
      lEncoded := (UInt64(-(lDelta + 1)) shl 1) or 1;
    repeat
      Result[lPosition] := Byte(lEncoded and $7F);
      lEncoded := lEncoded shr 7;
      if lEncoded <> 0 then
        Result[lPosition] := Result[lPosition] or $80;
      Inc(lPosition);
    until lEncoded = 0;
  end;
  SetLength(Result, lPosition);
end;

function DecodeOccurrenceValues(const aPayload: TBytes; const aRecordCount: Int64;
  const aColumnCount: Integer): TArray<Int64>;
var
  lByteCount, lValueCount: Int64;
  lColumn: Integer;
  lDelta: Int64;
  lEncoded: UInt64;
  lIndex, lPosition: NativeInt;
  lPrevious: TOccurrencePredictors;
begin
  Result := nil;
  CheckColumnCount(aColumnCount);
  if (aRecordCount < 0) or (aRecordCount > MaxInt) then
    raise ESnapshotOccurrenceCodec.Create('SNAPSHOT_OCCURRENCE_COUNT_INVALID');
  if Length(aPayload) = 0 then
    raise ESnapshotOccurrenceCodec.Create('SNAPSHOT_OCCURRENCE_FORMAT_MISSING');
  if aPayload[0] <> cOccurrenceFormat then
    raise ESnapshotOccurrenceCodec.Create('SNAPSHOT_OCCURRENCE_FORMAT_UNKNOWN');
  // Count <= MaxInt and columns <= 23 establish that these Int64 products fit.
  lValueCount := aRecordCount * aColumnCount;
  lByteCount := Length(aPayload) - 1;
  if (lValueCount > High(NativeInt) div SizeOf(Int64)) or
    (lByteCount < lValueCount) or (lByteCount > lValueCount * 10) then
    raise ESnapshotOccurrenceCodec.Create('SNAPSHOT_OCCURRENCE_PAYLOAD_SIZE_INVALID');
  SetLength(Result, NativeInt(lValueCount));
  lPrevious := Default(TOccurrencePredictors);
  lPosition := 1;
  for lIndex := 0 to High(Result) do
  begin
    lEncoded := ReadVarUInt(aPayload, lPosition);
    if (lEncoded and 1) = 0 then
      lDelta := Int64(lEncoded shr 1)
    else
      lDelta := -Int64(lEncoded shr 1) - 1;
    lColumn := Integer(lIndex mod aColumnCount);
    Result[lIndex] := CheckedPredictor(lPrevious[lColumn], lDelta);
    lPrevious[lColumn] := Result[lIndex];
  end;
  if lPosition <> Length(aPayload) then
    raise ESnapshotOccurrenceCodec.Create('SNAPSHOT_OCCURRENCE_TRAILING_BYTES');
end;

end.
