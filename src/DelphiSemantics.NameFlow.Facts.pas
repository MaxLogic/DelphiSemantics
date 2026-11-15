unit DelphiSemantics.NameFlow.Facts;

{$SCOPEDENUMS ON}

interface

type
  TDelphiNameFlowNodeKind = (Syntax, Routine, Formal, ResultValue, Definition, Assignment,
    Call, PotentialCall, PropertyAccess, RaiseValue, LiteralValue, IdentifierValue, Operation, Unknown);

  TDelphiNameFlowAttribute = record
    Name, Value: string;
  end;

  TDelphiNameFlowNode = record
    Id, ParentId: Integer;
    Children: TArray<Integer>;
    Attributes: TArray<TDelphiNameFlowAttribute>;
    Kind: TDelphiNameFlowNodeKind;
    SyntaxKind, Name, Value, TypeName, ScopeId, OwnerType, FileName: string;
    // Physical UTF-16 coordinates; end is exclusive. Zero means unavailable.
    Line, Column, EndLine, EndColumn: Integer;
    // One-based, exclusive-end offsets in the exact expanded parser input.
    OutputStartOffset, OutputEndOffset: Integer;
    ExpansionId: string;
    SpanKnown, ActivityKnown, BodyComplete: Boolean;
  end;

  IDelphiNameFlowFacts = interface
    ['{FD0A1B0F-76DD-4AF8-BBB1-E9130904A16F}']
    function NodeCount: Integer;
    function NodeById(const aId: Integer): TDelphiNameFlowNode;
    function GetComplete: Boolean;
    function GetConfigurationComplete: Boolean;
    function GetCoverageReason: string;
    // Complete syntax capture never asserts complete call binding or effects.
    property Complete: Boolean read GetComplete;
    property ConfigurationComplete: Boolean read GetConfigurationComplete;
    property CoverageReason: string read GetCoverageReason;
  end;

function CreateNameFlowFacts(const aNodes: TArray<TDelphiNameFlowNode>;
  const aComplete, aConfigurationComplete: Boolean; const aReason: string): IDelphiNameFlowFacts;
function NameFlowFactsToJson(const aFacts: IDelphiNameFlowFacts): string;
function NameFlowFactsFromJson(const aJson: string): IDelphiNameFlowFacts;

{$IFDEF DS_PROJECT_SESSION_TEST_SUPPORT}
type
  TDelphiNameFlowWorkKind = (Extract, Map, Serialize);
procedure ResetNameFlowWorkForTest;
procedure RecordNameFlowWorkForTest(const aKind: TDelphiNameFlowWorkKind);
function NameFlowWorkCountForTest(const aKind: TDelphiNameFlowWorkKind): Int64;
{$ENDIF}

implementation

uses
  System.Classes, System.Generics.Collections, System.Generics.Defaults, System.Hash, System.JSON.Serializers,
  System.NetEncoding, System.SyncObjs, System.SysUtils, System.ZLib,
  AutoFree;

{$IFDEF DS_PROJECT_SESSION_TEST_SUPPORT}
var
  gNameFlowWorkForTest: array[TDelphiNameFlowWorkKind] of Int64;

procedure ResetNameFlowWorkForTest;
var
  lKind: TDelphiNameFlowWorkKind;
begin
  for lKind := Low(TDelphiNameFlowWorkKind) to High(TDelphiNameFlowWorkKind) do
    TInterlocked.Exchange(gNameFlowWorkForTest[lKind], 0);
end;

procedure RecordNameFlowWorkForTest(const aKind: TDelphiNameFlowWorkKind);
begin
  TInterlocked.Increment(gNameFlowWorkForTest[aKind]);
end;

function NameFlowWorkCountForTest(const aKind: TDelphiNameFlowWorkKind): Int64;
begin
  Result := TInterlocked.Read(gNameFlowWorkForTest[aKind]);
end;
{$ENDIF}

type
  TNameFlowEnvelope = record
    Version, PayloadBytes: Integer;
    Digest, Payload: string;
  end;

  TStoredNameFlowFacts = record
    Flags: Integer;
    CoverageReason: string;
    Strings: TArray<string>;
    Nodes: TArray<TArray<Integer>>;
  end;

  TDelphiNameFlowFacts = class(TInterfacedObject, IDelphiNameFlowFacts)
  private
    fNodes: TArray<TDelphiNameFlowNode>;
    fComplete, fConfigurationComplete: Boolean;
    fCoverageReason: string;
  public
    constructor Create(const aNodes: TArray<TDelphiNameFlowNode>;
      const aComplete, aConfigurationComplete: Boolean; const aReason: string);
    function NodeCount: Integer;
    function NodeById(const aId: Integer): TDelphiNameFlowNode;
    function GetComplete: Boolean;
    function GetConfigurationComplete: Boolean;
    function GetCoverageReason: string;
  end;

function CopyNode(const aNode: TDelphiNameFlowNode): TDelphiNameFlowNode;
begin
  Result := aNode;
  Result.Children := Copy(aNode.Children);
  Result.Attributes := Copy(aNode.Attributes);
end;

constructor TDelphiNameFlowFacts.Create(const aNodes: TArray<TDelphiNameFlowNode>;
  const aComplete, aConfigurationComplete: Boolean; const aReason: string);
var
  i: Integer;
begin
  inherited Create;
  SetLength(fNodes, Length(aNodes));
  for i := 0 to High(aNodes) do
    fNodes[i] := CopyNode(aNodes[i]);
  fComplete := aComplete and (Length(aNodes) > 0);
  fConfigurationComplete := aConfigurationComplete;
  fCoverageReason := aReason;
  if not fComplete and (fCoverageReason = '') then
    fCoverageReason := 'name-flow-facts-missing';
end;

function TDelphiNameFlowFacts.NodeCount: Integer;
begin
  Result := Length(fNodes);
end;

function TDelphiNameFlowFacts.NodeById(const aId: Integer): TDelphiNameFlowNode;
begin
  if (aId < 1) or (aId > Length(fNodes)) then
    raise EArgumentOutOfRangeException.Create('Name-flow fact ID out of range');
  Result := CopyNode(fNodes[aId - 1]);
end;

function TDelphiNameFlowFacts.GetComplete: Boolean;
begin
  Result := fComplete;
end;

function TDelphiNameFlowFacts.GetConfigurationComplete: Boolean;
begin
  Result := fConfigurationComplete;
end;

function TDelphiNameFlowFacts.GetCoverageReason: string;
begin
  Result := fCoverageReason;
end;

function CreateNameFlowFacts(const aNodes: TArray<TDelphiNameFlowNode>;
  const aComplete, aConfigurationComplete: Boolean; const aReason: string): IDelphiNameFlowFacts;
begin
  Result := TDelphiNameFlowFacts.Create(aNodes, aComplete, aConfigurationComplete, aReason);
end;

const
  cNameFlowStorageVersion = 81406;
  cStoredNodeHeaderLength = 20;
  cMaximumFactsPayloadBytes = 256 * 1024 * 1024;
  cMaximumEncodedFactsCharacters = ((cMaximumFactsPayloadBytes +
    cMaximumFactsPayloadBytes div 1000 + 66) div 3) * 4;

function InternFactString(const aText: string; const aIds: TDictionary<string, Integer>;
  const aStrings: TList<string>): Integer;
begin
  if aIds.TryGetValue(aText, Result) then
    Exit;
  Result := aStrings.Count;
  aStrings.Add(aText);
  aIds.Add(aText, Result);
end;

function PackFactNode(const aNode: TDelphiNameFlowNode;
  const aIds: TDictionary<string, Integer>; const aStrings: TList<string>): TArray<Integer>;
var
  i, lOffset: Integer;
begin
  // A fixed scalar header, then ordered children and attribute name/value IDs.
  // Intern exact strings once per unit; never repeat paths/scopes per AST node.
  SetLength(Result, cStoredNodeHeaderLength + Length(aNode.Children) + 2 * Length(aNode.Attributes));
  Result[0] := aNode.Id;
  Result[1] := aNode.ParentId;
  Result[2] := Ord(aNode.Kind);
  Result[3] := InternFactString(aNode.SyntaxKind, aIds, aStrings);
  Result[4] := InternFactString(aNode.Name, aIds, aStrings);
  Result[5] := InternFactString(aNode.Value, aIds, aStrings);
  Result[6] := InternFactString(aNode.TypeName, aIds, aStrings);
  Result[7] := InternFactString(aNode.ScopeId, aIds, aStrings);
  Result[8] := InternFactString(aNode.OwnerType, aIds, aStrings);
  Result[9] := InternFactString(aNode.FileName, aIds, aStrings);
  Result[10] := aNode.Line;
  Result[11] := aNode.Column;
  Result[12] := aNode.EndLine;
  Result[13] := aNode.EndColumn;
  Result[14] := aNode.OutputStartOffset;
  Result[15] := aNode.OutputEndOffset;
  Result[16] := InternFactString(aNode.ExpansionId, aIds, aStrings);
  Result[17] := Ord(aNode.SpanKnown) or (Ord(aNode.ActivityKnown) shl 1) or (Ord(aNode.BodyComplete) shl 2);
  Result[18] := Length(aNode.Children);
  Result[19] := Length(aNode.Attributes);
  lOffset := cStoredNodeHeaderLength;
  for i := 0 to High(aNode.Children) do
  begin
    Result[lOffset] := aNode.Children[i];
    Inc(lOffset);
  end;
  for i := 0 to High(aNode.Attributes) do
  begin
    Result[lOffset] := InternFactString(aNode.Attributes[i].Name, aIds, aStrings);
    Result[lOffset + 1] := InternFactString(aNode.Attributes[i].Value, aIds, aStrings);
    Inc(lOffset, 2);
  end;
end;

function StoredFactString(const aId: Integer; const aStrings: TArray<string>): string;
begin
  if (aId < 0) or (aId >= Length(aStrings)) then
    raise EConvertError.Create('Name-flow string ID out of range');
  Result := aStrings[aId];
end;

function UnpackFactNode(const aRow: TArray<Integer>;
  const aStrings: TArray<string>): TDelphiNameFlowNode;
var
  i, lOffset: Integer;
begin
  Result := Default(TDelphiNameFlowNode);
  if Length(aRow) < cStoredNodeHeaderLength then
    raise EConvertError.Create('Name-flow node header is incomplete');
  if (aRow[2] < 0) or (aRow[2] > Ord(High(TDelphiNameFlowNodeKind))) or
    (aRow[17] < 0) or (aRow[17] > 7) or (aRow[18] < 0) or (aRow[19] < 0) or
    (Int64(cStoredNodeHeaderLength) + aRow[18] + Int64(2) * aRow[19] <> Length(aRow)) then
    raise EConvertError.Create('Name-flow node shape is invalid');
  Result.Id := aRow[0];
  Result.ParentId := aRow[1];
  Result.Kind := TDelphiNameFlowNodeKind(aRow[2]);
  Result.SyntaxKind := StoredFactString(aRow[3], aStrings);
  Result.Name := StoredFactString(aRow[4], aStrings);
  Result.Value := StoredFactString(aRow[5], aStrings);
  Result.TypeName := StoredFactString(aRow[6], aStrings);
  Result.ScopeId := StoredFactString(aRow[7], aStrings);
  Result.OwnerType := StoredFactString(aRow[8], aStrings);
  Result.FileName := StoredFactString(aRow[9], aStrings);
  Result.Line := aRow[10];
  Result.Column := aRow[11];
  Result.EndLine := aRow[12];
  Result.EndColumn := aRow[13];
  Result.OutputStartOffset := aRow[14];
  Result.OutputEndOffset := aRow[15];
  Result.ExpansionId := StoredFactString(aRow[16], aStrings);
  Result.SpanKnown := (aRow[17] and 1) <> 0;
  Result.ActivityKnown := (aRow[17] and 2) <> 0;
  Result.BodyComplete := (aRow[17] and 4) <> 0;
  SetLength(Result.Children, aRow[18]);
  SetLength(Result.Attributes, aRow[19]);
  lOffset := cStoredNodeHeaderLength;
  for i := 0 to High(Result.Children) do
  begin
    Result.Children[i] := aRow[lOffset];
    Inc(lOffset);
  end;
  for i := 0 to High(Result.Attributes) do
  begin
    Result.Attributes[i].Name := StoredFactString(aRow[lOffset], aStrings);
    Result.Attributes[i].Value := StoredFactString(aRow[lOffset + 1], aStrings);
    Inc(lOffset, 2);
  end;
end;

procedure WriteFactsBytes(const aStream: TStream; const aBuffer; const aCount: Integer);
begin
  if (aCount < 0) or (aStream.Size + aCount > cMaximumFactsPayloadBytes) then
    raise EInvalidOpException.Create('NAME_FLOW_FACTS_STORAGE_LIMIT: derived facts exceed the bounded cache payload');
  if aCount > 0 then
    aStream.WriteBuffer(aBuffer, aCount);
end;

procedure WriteFactsInteger(const aStream: TStream; const aValue: Integer);
begin
  WriteFactsBytes(aStream, aValue, SizeOf(aValue));
end;

procedure WriteFactsString(const aStream: TStream; const aValue: string);
begin
  if Length(aValue) > cMaximumFactsPayloadBytes div SizeOf(Char) then
    raise EInvalidOpException.Create('NAME_FLOW_FACTS_STORAGE_LIMIT: derived text exceeds the bounded cache payload');
  WriteFactsInteger(aStream, Length(aValue));
  // Preserve UTF-16 code units exactly, including embedded NULs. The cache epoch
  // defines little-endian 32-bit integers and UTF-16 on supported Delphi targets.
  if aValue <> '' then
    WriteFactsBytes(aStream, PChar(aValue)^, Length(aValue) * SizeOf(Char));
end;

function ReadFactsInteger(const aStream: TStream): Integer;
begin
  if aStream.Size - aStream.Position < SizeOf(Result) then
    raise EConvertError.Create('Name-flow integer is truncated');
  aStream.ReadBuffer(Result, SizeOf(Result));
end;

function ReadFactsCount(const aStream: TStream; const aMinimumItemBytes: Integer): Integer;
begin
  Result := ReadFactsInteger(aStream);
  if (Result < 0) or (Result > (aStream.Size - aStream.Position) div aMinimumItemBytes) then
    raise EConvertError.Create('Name-flow count exceeds the remaining payload');
end;

function ReadFactsString(const aStream: TStream): string;
var
  lLength: Integer;
begin
  lLength := ReadFactsCount(aStream, SizeOf(Char));
  SetLength(Result, lLength);
  if lLength > 0 then
    aStream.ReadBuffer(PChar(Result)^, lLength * SizeOf(Char));
end;

procedure WriteStoredFacts(const aStream: TStream; const aStored: TStoredNameFlowFacts);
var
  lText: string;
  lRow: TArray<Integer>;
begin
  WriteFactsInteger(aStream, cNameFlowStorageVersion);
  WriteFactsInteger(aStream, aStored.Flags);
  WriteFactsString(aStream, aStored.CoverageReason);
  WriteFactsInteger(aStream, Length(aStored.Strings));
  for lText in aStored.Strings do
    WriteFactsString(aStream, lText);
  WriteFactsInteger(aStream, Length(aStored.Nodes));
  for lRow in aStored.Nodes do
  begin
    WriteFactsInteger(aStream, Length(lRow));
    if Length(lRow) > 0 then
      WriteFactsBytes(aStream, lRow[0], Length(lRow) * SizeOf(Integer));
  end;
end;

function ReadStoredFacts(const aStream: TStream): TStoredNameFlowFacts;
var
  i, lLength: Integer;
begin
  Result := Default(TStoredNameFlowFacts);
  if ReadFactsInteger(aStream) <> cNameFlowStorageVersion then
    raise EConvertError.Create('Name-flow binary version is unsupported');
  Result.Flags := ReadFactsInteger(aStream);
  if (Result.Flags < 0) or (Result.Flags > 3) then
    raise EConvertError.Create('Name-flow completeness flags are invalid');
  Result.CoverageReason := ReadFactsString(aStream);
  lLength := ReadFactsCount(aStream, SizeOf(Integer));
  SetLength(Result.Strings, lLength);
  for i := 0 to High(Result.Strings) do
    Result.Strings[i] := ReadFactsString(aStream);
  lLength := ReadFactsCount(aStream, (cStoredNodeHeaderLength + 1) * SizeOf(Integer));
  SetLength(Result.Nodes, lLength);
  for i := 0 to High(Result.Nodes) do
  begin
    lLength := ReadFactsCount(aStream, SizeOf(Integer));
    SetLength(Result.Nodes[i], lLength);
    if lLength > 0 then
      aStream.ReadBuffer(Result.Nodes[i][0], lLength * SizeOf(Integer));
  end;
  if aStream.Position <> aStream.Size then
    raise EConvertError.Create('Name-flow binary payload has trailing data');
end;

function NameFlowFactsToJson(const aFacts: IDelphiNameFlowFacts): string;
var
  i: Integer;
  lStored: TStoredNameFlowFacts;
  lEnvelope: TNameFlowEnvelope;
  lIds: TDictionary<string, Integer>;
  lStrings: TList<string>;
  lRaw, lCompressed: TMemoryStream;
  lCompressor: TZCompressionStream;
  lBase64: TBase64Encoding;
  lSerializer: TJsonSerializer;
  g: TGarbos;
begin
{$IFDEF DS_PROJECT_SESSION_TEST_SUPPORT}
  RecordNameFlowWorkForTest(TDelphiNameFlowWorkKind.Serialize);
{$ENDIF}
  lStored := Default(TStoredNameFlowFacts);
  GC(lIds, TDictionary<string, Integer>.Create(TStringComparer.Ordinal), g);
  GC(lStrings, TList<string>.Create, g);
  if aFacts <> nil then
  begin
    lStored.Flags := Ord(aFacts.Complete) or (Ord(aFacts.ConfigurationComplete) shl 1);
    lStored.CoverageReason := aFacts.CoverageReason;
    SetLength(lStored.Nodes, aFacts.NodeCount);
    for i := 1 to aFacts.NodeCount do
      lStored.Nodes[i - 1] := PackFactNode(aFacts.NodeById(i), lIds, lStrings);
  end else
    lStored.CoverageReason := 'name-flow-facts-missing';
  lStored.Strings := lStrings.ToArray;
  GC(lRaw, TMemoryStream.Create, g);
  WriteStoredFacts(lRaw, lStored);
  lEnvelope := Default(TNameFlowEnvelope);
  lEnvelope.Version := cNameFlowStorageVersion;
  lEnvelope.PayloadBytes := Integer(lRaw.Size);
  lRaw.Position := 0;
  // The digest covers every field, including completeness and coverage reason.
  lEnvelope.Digest := THashSHA2.GetHashString(lRaw);
  lRaw.Position := 0;
  GC(lCompressed, TMemoryStream.Create, g);
  lCompressor := TZCompressionStream.Create(lCompressed, zcFastest, 15);
  try
    lCompressor.CopyFrom(lRaw, lRaw.Size);
  finally
    lCompressor.Free;
  end;
  GC(lBase64, TBase64Encoding.Create(0), g);
  lEnvelope.Payload := lBase64.EncodeBytesToString(lCompressed.Memory, Integer(lCompressed.Size));
  GC(lSerializer, TJsonSerializer.Create, g);
  Result := lSerializer.Serialize<TNameFlowEnvelope>(lEnvelope);
end;

function DecodeFactsPayload(const aEnvelope: TNameFlowEnvelope): TStoredNameFlowFacts;
var
  lBytes: TBytes;
  lCompressed: TBytesStream;
  lRaw: TMemoryStream;
  lInflater: TZDecompressionStream;
  lExtra: Byte;
  g: TGarbos;
begin
  if (aEnvelope.PayloadBytes < 5 * SizeOf(Integer)) or
    (aEnvelope.PayloadBytes > cMaximumFactsPayloadBytes) or
    (Length(aEnvelope.Payload) > cMaximumEncodedFactsCharacters) then
    raise EConvertError.Create('Name-flow envelope exceeds the payload limit');
  lBytes := TNetEncoding.Base64.DecodeStringToBytes(aEnvelope.Payload);
  GC(lCompressed, TBytesStream.Create(lBytes), g);
  GC(lRaw, TMemoryStream.Create, g);
  lRaw.Size := aEnvelope.PayloadBytes;
  GC(lInflater, TZDecompressionStream.Create(lCompressed), g);
  lInflater.ReadBuffer(lRaw.Memory^, aEnvelope.PayloadBytes);
  // Never inflate beyond the declared bound, even for corrupt/hostile cache data.
  if lInflater.Read(lExtra, 1) <> 0 then
    raise EConvertError.Create('Name-flow inflated payload exceeds its declared size');
  lRaw.Position := 0;
  if (aEnvelope.Digest = '') or (aEnvelope.Digest <> THashSHA2.GetHashString(lRaw)) then
    raise EConvertError.Create('Name-flow payload digest is invalid');
  lRaw.Position := 0;
  Result := ReadStoredFacts(lRaw);
end;

function ValidNodes(const aNodes: TArray<TDelphiNameFlowNode>): Boolean;
var
  i, j, lChild: Integer;
  lSeen: TArray<Boolean>;
begin
  Result := False;
  SetLength(lSeen, Length(aNodes));
  for i := 0 to High(aNodes) do
  begin
    if (aNodes[i].Id <> i + 1) or (aNodes[i].SyntaxKind = '') or
      (Ord(aNodes[i].Kind) > Ord(High(TDelphiNameFlowNodeKind))) then
      Exit;
    if (i = 0) and (aNodes[i].ParentId <> 0) then
      Exit;
    if (i > 0) and ((aNodes[i].ParentId < 1) or (aNodes[i].ParentId > i)) then
      Exit;
    for j := 0 to High(aNodes[i].Children) do
    begin
      lChild := aNodes[i].Children[j];
      if (lChild <= i + 1) or (lChild > Length(aNodes)) then
        Exit;
      if lSeen[lChild - 1] or (aNodes[lChild - 1].ParentId <> i + 1) then
        Exit;
      lSeen[lChild - 1] := True;
    end;
  end;
  for i := 1 to High(aNodes) do
    if not lSeen[i] then
      Exit;
  Result := True;
end;

function NameFlowFactsFromJson(const aJson: string): IDelphiNameFlowFacts;
var
  i: Integer;
  lEnvelope: TNameFlowEnvelope;
  lStored: TStoredNameFlowFacts;
  lNodes: TArray<TDelphiNameFlowNode>;
  lSerializer: TJsonSerializer;
  g: TGarbos;
begin
  Result := CreateNameFlowFacts(nil, False, False, 'name-flow-facts-json-unverified');
  if aJson = '' then
    Exit;
  GC(lSerializer, TJsonSerializer.Create, g);
  try
    lEnvelope := lSerializer.Deserialize<TNameFlowEnvelope>(aJson);
    if lEnvelope.Version <> cNameFlowStorageVersion then
      Exit;
    lStored := DecodeFactsPayload(lEnvelope);
    if (Length(lStored.Nodes) = 0) and ((lStored.Flags and 1) <> 0) then
      Exit;
    SetLength(lNodes, Length(lStored.Nodes));
    for i := 0 to High(lNodes) do
      lNodes[i] := UnpackFactNode(lStored.Nodes[i], lStored.Strings);
    if not ValidNodes(lNodes) then
      Exit;
    Result := CreateNameFlowFacts(lNodes, (lStored.Flags and 1) <> 0,
      (lStored.Flags and 2) <> 0, lStored.CoverageReason);
  except
    on e: Exception do
      Result := CreateNameFlowFacts(nil, False, False, 'name-flow-facts-json-unverified:' + e.ClassName);
  end;
end;

end.
