unit DelphiSemantics.NameFlow.SdkArtifact;

interface

uses
  DelphiSemantics.NameFlow.SdkEffects;

type
  TNameSdkArtifact = record
    Key, Identity, SourcePin, CompilerPin: string;
    UnitSourceCeiling: Int64;
    Entries: TArray<TNameSdkEffectEntry>;
    Coverage: TArray<TNameSdkSourceCoverage>;
    Statistics: TNameSdkStatistics;
  end;

  TNameSdkArtifactLimits = record
    MaxEntries, MaxSources, MaxEdges: Integer;
  end;

  TNameSdkArtifactStore = record
    class function Save(const aFileName: string; const aArtifact: TNameSdkArtifact;
      out aReason: string): Boolean; static;
    class function TryLoad(const aFileName, aExpectedKey: string;
      const aLimits: TNameSdkArtifactLimits; out aArtifact: TNameSdkArtifact;
      out aReason: string): Boolean; static;
  end;

implementation

uses
  System.Classes, System.Hash, System.IOUtils, System.JSON, System.SysUtils,
  Winapi.Windows,
  AutoFree,
  DelphiSemantics.NameConsumers;

const
  cFormat = 'ds803-sdk-artifact-v1';
  cMaximumFileBytes = 32 * 1024 * 1024;
  cMaximumStringLength = 65536;

function RequiredObject(const aParent: TJSONObject; const aName: string): TJSONObject;
var
  lValue: TJSONValue;
begin
  lValue := aParent.GetValue(aName);
  if not (lValue is TJSONObject) then
    raise EConvertError.Create('Missing artifact object: ' + aName);
  Result := TJSONObject(lValue);
end;

function RequiredArray(const aParent: TJSONObject; const aName: string): TJSONArray;
var
  lValue: TJSONValue;
begin
  lValue := aParent.GetValue(aName);
  if not (lValue is TJSONArray) then
    raise EConvertError.Create('Missing artifact array: ' + aName);
  Result := TJSONArray(lValue);
end;

function RequiredString(const aParent: TJSONObject; const aName: string): string;
var
  lValue: TJSONValue;
begin
  lValue := aParent.GetValue(aName);
  if not (lValue is TJSONString) then
    raise EConvertError.Create('Missing artifact string: ' + aName);
  Result := lValue.Value;
  if Length(Result) > cMaximumStringLength then
    raise EConvertError.Create('Artifact string limit: ' + aName);
end;

function RequiredInteger(const aParent: TJSONObject; const aName: string;
  const aMinimum, aMaximum: Int64): Int64;
var
  lValue: TJSONValue;
begin
  lValue := aParent.GetValue(aName);
  if not (lValue is TJSONNumber) or not TryStrToInt64(lValue.Value, Result) then
    raise EConvertError.Create('Invalid artifact integer: ' + aName);
  if (Result < aMinimum) or (Result > aMaximum) then
    raise EConvertError.Create('Artifact integer limit: ' + aName);
end;

procedure CheckJsonDepth(const aText: string);
var
  c: Char;
  lDepth: Integer;
  lQuoted, lEscaped: Boolean;
begin
  lDepth := 0;
  lQuoted := False;
  lEscaped := False;
  for c in aText do
    if lQuoted then
    begin
      if lEscaped then
        lEscaped := False
      else if c = '\' then
        lEscaped := True
      else if c = '"' then
        lQuoted := False;
    end else if c = '"' then
      lQuoted := True
    else if CharInSet(c, ['{', '[']) then
    begin
      Inc(lDepth);
      if lDepth > 64 then
        raise EConvertError.Create('Artifact JSON depth budget');
    end else if CharInSet(c, ['}', ']']) then
    begin
      Dec(lDepth);
      if lDepth < 0 then
        raise EConvertError.Create('Invalid artifact JSON structure');
    end;
  if lQuoted or (lDepth <> 0) then
    raise EConvertError.Create('Incomplete artifact JSON structure');
end;

function ReadBoundedArtifact(const aFileName: string): string;
var
  g: TGarbos;
  lStream: TFileStream;
  lBytes: TBytes;
  lOffset: Integer;
begin
  GC(lStream, TFileStream.Create(aFileName, fmOpenRead or fmShareDenyWrite), g);
  if (lStream.Size <= 0) or (lStream.Size > cMaximumFileBytes) then
    raise EConvertError.Create('Artifact file byte budget');
  SetLength(lBytes, Integer(lStream.Size));
  lStream.ReadBuffer(lBytes[0], Length(lBytes));
  lOffset := 0;
  if (Length(lBytes) >= 3) and (lBytes[0] = $EF) and (lBytes[1] = $BB) and (lBytes[2] = $BF) then
    lOffset := 3;
  Result := TEncoding.UTF8.GetString(lBytes, lOffset, Length(lBytes) - lOffset);
end;

procedure FlushArtifactFile(const aFileName: string);
var
  lHandle: THandle;
begin
  lHandle := CreateFile(PChar(aFileName), GENERIC_WRITE, FILE_SHARE_READ, nil,
    OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0);
  if lHandle = INVALID_HANDLE_VALUE then
    RaiseLastOSError;
  try
    if not FlushFileBuffers(lHandle) then
      RaiseLastOSError;
  finally
    CloseHandle(lHandle);
  end;
end;

procedure AddInteger(const aParent: TJSONObject; const aName: string; const aValue: Int64);
begin
  aParent.AddPair(aName, TJSONNumber.Create(aValue));
end;

function EncodeStatistics(const aStats: TNameSdkStatistics): TJSONObject;
begin
  Result := TJSONObject.Create;
  AddInteger(Result, 'sources', aStats.SourceCount);
  AddInteger(Result, 'routines', aStats.RoutineCount);
  AddInteger(Result, 'passive', aStats.PassiveCount);
  AddInteger(Result, 'opaque', aStats.OpaqueCount);
  AddInteger(Result, 'metadata', aStats.MetadataCount);
  AddInteger(Result, 'producers', aStats.ProducerCount);
  AddInteger(Result, 'stores', aStats.StoreCount);
  AddInteger(Result, 'callbacks', aStats.CallbackCount);
  AddInteger(Result, 'workItems', aStats.FixedPointPasses);
  AddInteger(Result, 'sourceBytes', aStats.SourceBytes);
  AddInteger(Result, 'factNodes', aStats.FactNodes);
  AddInteger(Result, 'edges', aStats.CandidateEdges);
  AddInteger(Result, 'requested', aStats.RequestedSourceCount);
  AddInteger(Result, 'covered', aStats.CoveredSourceCount);
  AddInteger(Result, 'skipped', aStats.SkippedSourceCount);
end;

function DecodeStatistics(const aObject: TJSONObject; const aLimits: TNameSdkArtifactLimits): TNameSdkStatistics;
begin
  if aObject.Count <> 15 then
    raise EConvertError.Create('Incomplete artifact statistics');
  Result := Default(TNameSdkStatistics);
  Result.SourceCount := RequiredInteger(aObject, 'sources', 0, aLimits.MaxSources);
  Result.RoutineCount := RequiredInteger(aObject, 'routines', 0, aLimits.MaxEntries);
  Result.PassiveCount := RequiredInteger(aObject, 'passive', 0, aLimits.MaxEntries);
  Result.OpaqueCount := RequiredInteger(aObject, 'opaque', 0, aLimits.MaxEntries);
  Result.MetadataCount := RequiredInteger(aObject, 'metadata', 0, aLimits.MaxEntries);
  Result.ProducerCount := RequiredInteger(aObject, 'producers', 0, aLimits.MaxEntries);
  Result.StoreCount := RequiredInteger(aObject, 'stores', 0, aLimits.MaxEntries);
  Result.CallbackCount := RequiredInteger(aObject, 'callbacks', 0, aLimits.MaxEntries);
  Result.FixedPointPasses := RequiredInteger(aObject, 'workItems', 0, MaxInt);
  Result.SourceBytes := RequiredInteger(aObject, 'sourceBytes', 0, High(Int64));
  Result.FactNodes := RequiredInteger(aObject, 'factNodes', 0, MaxInt);
  Result.CandidateEdges := RequiredInteger(aObject, 'edges', 0, aLimits.MaxEdges);
  Result.RequestedSourceCount := RequiredInteger(aObject, 'requested', 0, aLimits.MaxSources);
  Result.CoveredSourceCount := RequiredInteger(aObject, 'covered', 0, aLimits.MaxSources);
  Result.SkippedSourceCount := RequiredInteger(aObject, 'skipped', 0, aLimits.MaxSources);
end;

function EncodeEntry(const aEntry: TNameSdkEffectEntry): TJSONObject;
var
  lChannel: TNameEffectChannel;
  lTarget: TNameEffectTargetKind;
  lChannels, lTargets: Integer;
  lCalls: TJSONArray;
  lName: string;
begin
  Result := TJSONObject.Create;
  Result.AddPair('id', aEntry.DeclarationId);
  Result.AddPair('qualified', aEntry.QualifiedName);
  Result.AddPair('file', aEntry.FileName);
  Result.AddPair('unit', aEntry.UnitName);
  Result.AddPair('owner', aEntry.OwnerName);
  Result.AddPair('routine', aEntry.RoutineName);
  AddInteger(Result, 'line', aEntry.Line);
  AddInteger(Result, 'column', aEntry.Column);
  AddInteger(Result, 'bodyComplete', Ord(aEntry.BodyComplete));
  lChannels := 0;
  lTargets := 0;
  for lChannel := Low(TNameEffectChannel) to High(TNameEffectChannel) do
    if lChannel in aEntry.Effect.Channels then
      lChannels := lChannels or (1 shl Ord(lChannel));
  for lTarget := Low(TNameEffectTargetKind) to High(TNameEffectTargetKind) do
    if lTarget in aEntry.Effect.Targets then
      lTargets := lTargets or (1 shl Ord(lTarget));
  AddInteger(Result, 'channels', lChannels);
  AddInteger(Result, 'targets', lTargets);
  AddInteger(Result, 'metadataFormal', aEntry.Effect.MetadataFormalOrdinal);
  AddInteger(Result, 'nameFormal', aEntry.Effect.Precision.FormalOrdinal);
  AddInteger(Result, 'grammar', Ord(aEntry.Effect.Precision.Grammar));
  Result.AddPair('reason', aEntry.Effect.Reason);
  lCalls := TJSONArray.Create;
  Result.AddPair('callees', lCalls);
  for lName in aEntry.CalleeNames do
    lCalls.Add(lName);
end;

function DecodeEntry(const aObject: TJSONObject; var aEdgesRemaining: Integer): TNameSdkEffectEntry;
var
  lCalls: TJSONArray;
  lChannel: TNameEffectChannel;
  lTarget: TNameEffectTargetKind;
  i, lChannels, lTargets: Integer;
begin
  if aObject.Count <> 16 then
    raise EConvertError.Create('Incomplete artifact entry');
  Result := Default(TNameSdkEffectEntry);
  Result.DeclarationId := RequiredString(aObject, 'id');
  Result.QualifiedName := RequiredString(aObject, 'qualified');
  Result.FileName := RequiredString(aObject, 'file');
  Result.UnitName := RequiredString(aObject, 'unit');
  Result.OwnerName := RequiredString(aObject, 'owner');
  Result.RoutineName := RequiredString(aObject, 'routine');
  Result.Line := RequiredInteger(aObject, 'line', 0, MaxInt);
  Result.Column := RequiredInteger(aObject, 'column', 0, MaxInt);
  Result.BodyComplete := RequiredInteger(aObject, 'bodyComplete', 0, 1) = 1;
  lChannels := RequiredInteger(aObject, 'channels', 0, (1 shl (Ord(High(TNameEffectChannel)) + 1)) - 1);
  lTargets := RequiredInteger(aObject, 'targets', 0, (1 shl (Ord(High(TNameEffectTargetKind)) + 1)) - 1);
  for lChannel := Low(TNameEffectChannel) to High(TNameEffectChannel) do
    if (lChannels and (1 shl Ord(lChannel))) <> 0 then
      Include(Result.Effect.Channels, lChannel);
  for lTarget := Low(TNameEffectTargetKind) to High(TNameEffectTargetKind) do
    if (lTargets and (1 shl Ord(lTarget))) <> 0 then
      Include(Result.Effect.Targets, lTarget);
  Result.Effect.MetadataFormalOrdinal := RequiredInteger(aObject, 'metadataFormal', -1, 1024);
  Result.Effect.Precision.FormalOrdinal := RequiredInteger(aObject, 'nameFormal', -1, 1024);
  Result.Effect.Precision.Grammar := TNameConsumerGrammar(RequiredInteger(aObject, 'grammar',
    Ord(Low(TNameConsumerGrammar)), Ord(High(TNameConsumerGrammar))));
  Result.Effect.Reason := RequiredString(aObject, 'reason');
  lCalls := RequiredArray(aObject, 'callees');
  if lCalls.Count > aEdgesRemaining then
    raise EConvertError.Create('Artifact callee budget');
  Dec(aEdgesRemaining, lCalls.Count);
  SetLength(Result.CalleeNames, lCalls.Count);
  for i := 0 to lCalls.Count - 1 do
  begin
    if not (lCalls.Items[i] is TJSONString) or (Length(lCalls.Items[i].Value) > cMaximumStringLength) then
      raise EConvertError.Create('Invalid artifact callee');
    Result.CalleeNames[i] := lCalls.Items[i].Value;
  end;
  if (Result.DeclarationId = '') or (Result.QualifiedName = '') or
    (Result.Effect.IsPassive and (not Result.BodyComplete or (Length(Result.CalleeNames) <> 0))) then
    raise EConvertError.Create('Invalid artifact effect completeness');
  if (TNameEffectChannel.Opaque in Result.Effect.Channels) and
    (Result.Effect.Targets <> [Low(TNameEffectTargetKind)..High(TNameEffectTargetKind)]) then
    raise EConvertError.Create('Invalid artifact opaque domain');
end;

class function TNameSdkArtifactStore.Save(const aFileName: string; const aArtifact: TNameSdkArtifact;
  out aReason: string): Boolean;
var
  g: TGarbos;
  lEnvelope, lPayload, lItem: TJSONObject;
  lEntries, lCoverage: TJSONArray;
  lEntry: TNameSdkEffectEntry;
  lSource: TNameSdkSourceCoverage;
  lText, lTempName, lDirectory: string;
begin
  Result := False;
  aReason := '';
  lTempName := '';
  try
    GC(lEnvelope, TJSONObject.Create, g);
    lPayload := TJSONObject.Create;
    lEnvelope.AddPair('format', cFormat);
    lEnvelope.AddPair('payload', lPayload);
    lPayload.AddPair('key', aArtifact.Key);
    lPayload.AddPair('identity', aArtifact.Identity);
    lPayload.AddPair('sourcePin', aArtifact.SourcePin);
    lPayload.AddPair('compilerPin', aArtifact.CompilerPin);
    AddInteger(lPayload, 'unitSourceCeiling', aArtifact.UnitSourceCeiling);
    lPayload.AddPair('statistics', EncodeStatistics(aArtifact.Statistics));
    lEntries := TJSONArray.Create;
    lPayload.AddPair('entries', lEntries);
    for lEntry in aArtifact.Entries do
      lEntries.AddElement(EncodeEntry(lEntry));
    lCoverage := TJSONArray.Create;
    lPayload.AddPair('coverage', lCoverage);
    for lSource in aArtifact.Coverage do
    begin
      lItem := TJSONObject.Create;
      lCoverage.AddElement(lItem);
      lItem.AddPair('file', lSource.FileName);
      lItem.AddPair('reason', lSource.Reason);
      AddInteger(lItem, 'bytes', lSource.ByteCount);
      AddInteger(lItem, 'covered', Ord(lSource.Covered));
    end;
    lEnvelope.AddPair('digest', THashSHA2.GetHashString(lPayload.ToJSON));
    lText := lEnvelope.ToJSON;
    if TEncoding.UTF8.GetByteCount(lText) + 3 > cMaximumFileBytes then
      raise EConvertError.Create('Artifact file byte budget');
    lDirectory := ExtractFilePath(TPath.GetFullPath(aFileName));
    TDirectory.CreateDirectory(lDirectory);
    lTempName := TPath.Combine(lDirectory, '.sdk-' + TGUID.NewGuid.ToString + '.tmp');
    TFile.WriteAllText(lTempName, lText, TEncoding.UTF8);
    FlushArtifactFile(lTempName);
    if not MoveFileEx(PChar(lTempName), PChar(TPath.GetFullPath(aFileName)),
      MOVEFILE_REPLACE_EXISTING or MOVEFILE_WRITE_THROUGH) then
      RaiseLastOSError;
    lTempName := '';
    Result := True;
  except
    on E: Exception do
      aReason := 'sdk-artifact-write-failed: ' + E.ClassName + ': ' + E.Message;
  end;
  if (lTempName <> '') and TFile.Exists(lTempName) then
    if not Winapi.Windows.DeleteFile(PChar(lTempName)) then
      aReason := aReason + '; temporary artifact retained: ' + lTempName;
end;

class function TNameSdkArtifactStore.TryLoad(const aFileName, aExpectedKey: string;
  const aLimits: TNameSdkArtifactLimits; out aArtifact: TNameSdkArtifact;
  out aReason: string): Boolean;
var
  g: TGarbos;
  lJson: TJSONValue;
  lEnvelope, lPayload, lItem: TJSONObject;
  lEntries, lCoverage: TJSONArray;
  i, lEdgesRemaining: Integer;
  lText: string;
begin
  Result := False;
  aArtifact := Default(TNameSdkArtifact);
  aReason := '';
  try
    if not TFile.Exists(aFileName) then
    begin
      aReason := 'sdk-artifact-missing';
      Exit;
    end;
    lText := ReadBoundedArtifact(aFileName);
    CheckJsonDepth(lText);
    GC(lJson, TJSONObject.ParseJSONValue(lText), g);
    if not (lJson is TJSONObject) then
      raise EConvertError.Create('Invalid artifact JSON');
    lEnvelope := TJSONObject(lJson);
    if (lEnvelope.Count <> 3) or (RequiredString(lEnvelope, 'format') <> cFormat) then
      raise EConvertError.Create('Invalid artifact format');
    lPayload := RequiredObject(lEnvelope, 'payload');
    if (lPayload.Count <> 8) or
      not SameText(RequiredString(lEnvelope, 'digest'), THashSHA2.GetHashString(lPayload.ToJSON)) then
      raise EConvertError.Create('Artifact digest mismatch');
    aArtifact.Key := RequiredString(lPayload, 'key');
    if aArtifact.Key <> aExpectedKey then
      raise EConvertError.Create('Artifact request/policy mismatch');
    aArtifact.Identity := RequiredString(lPayload, 'identity');
    aArtifact.SourcePin := RequiredString(lPayload, 'sourcePin');
    aArtifact.CompilerPin := RequiredString(lPayload, 'compilerPin');
    aArtifact.UnitSourceCeiling := RequiredInteger(lPayload, 'unitSourceCeiling', 1, High(Int64));
    aArtifact.Statistics := DecodeStatistics(RequiredObject(lPayload, 'statistics'), aLimits);
    lEntries := RequiredArray(lPayload, 'entries');
    lCoverage := RequiredArray(lPayload, 'coverage');
    if (lEntries.Count > aLimits.MaxEntries) or (lCoverage.Count > aLimits.MaxSources) then
      raise EConvertError.Create('Artifact collection budget');
    lEdgesRemaining := aLimits.MaxEdges;
    SetLength(aArtifact.Entries, lEntries.Count);
    for i := 0 to lEntries.Count - 1 do
    begin
      if not (lEntries.Items[i] is TJSONObject) then
        raise EConvertError.Create('Invalid artifact entry object');
      aArtifact.Entries[i] := DecodeEntry(TJSONObject(lEntries.Items[i]), lEdgesRemaining);
    end;
    SetLength(aArtifact.Coverage, lCoverage.Count);
    for i := 0 to lCoverage.Count - 1 do
    begin
      if not (lCoverage.Items[i] is TJSONObject) then
        raise EConvertError.Create('Invalid artifact coverage object');
      lItem := TJSONObject(lCoverage.Items[i]);
      if lItem.Count <> 4 then
        raise EConvertError.Create('Incomplete artifact coverage');
      aArtifact.Coverage[i].FileName := RequiredString(lItem, 'file');
      aArtifact.Coverage[i].Reason := RequiredString(lItem, 'reason');
      aArtifact.Coverage[i].ByteCount := RequiredInteger(lItem, 'bytes', 0, High(Int64));
      aArtifact.Coverage[i].Covered := RequiredInteger(lItem, 'covered', 0, 1) = 1;
    end;
    if (aArtifact.Identity <> aArtifact.Key) or
      (aArtifact.Statistics.RoutineCount <> Length(aArtifact.Entries)) or
      (aArtifact.Statistics.RequestedSourceCount <> Length(aArtifact.Coverage)) or
      (aArtifact.Statistics.CoveredSourceCount + aArtifact.Statistics.SkippedSourceCount <>
        aArtifact.Statistics.RequestedSourceCount) then
      raise EConvertError.Create('Artifact coverage/count mismatch');
    Result := True;
  except
    on E: Exception do
    begin
      aArtifact := Default(TNameSdkArtifact);
      aReason := 'sdk-artifact-invalid: ' + E.ClassName + ': ' + E.Message;
    end;
  end;
end;

end.
