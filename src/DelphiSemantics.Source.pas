unit DelphiSemantics.Source;

interface

uses
  System.Generics.Collections;

type
  TDelphiSemanticSourceDiagnostic = record
    Code: string;
    Message: string;
    FileName: string;
  end;

  TDelphiSemanticSourceText = record
    FileName: string;
    Text: string;
    ContentHash: string;
    Role: string;
    EncodingName: string;
    LineEndingName: string;
    LineBreak: string;
  end;

  IDelphiSemanticSourceObservations = interface
    ['{BA062585-D84D-49B0-8A9F-D181E24259F6}']
    function GetCount: Integer;
    function GetItem(const aIndex: Integer): TDelphiSemanticSourceText;
    function TryFind(const aFileName: string; out aSource: TDelphiSemanticSourceText): Boolean;
    property Count: Integer read GetCount;
    property Items[const aIndex: Integer]: TDelphiSemanticSourceText read GetItem;
  end;

  // One merge rule for incremental owners and pairwise TryMerge. A failed
  // addition poisons the owner so caught exceptions cannot publish partial state.
  TDelphiSemanticSourceAccumulator = class
  private
    fFirst, fFrozen: IDelphiSemanticSourceObservations;
    fItems: TList<TDelphiSemanticSourceText>;
    fKnown: TDictionary<string, TDelphiSemanticSourceText>;
    fSeeded, fFailed, fRecheckNormalizedPaths: Boolean;
    fError: string;
    fMaterializationCount: Integer;
    function AddItems(const aSources: IDelphiSemanticSourceObservations; out aError: string): Boolean;
    procedure RequireUsable;
  public
    constructor Create;
    destructor Destroy; override;
    function TryAdd(const aSources: IDelphiSemanticSourceObservations; out aError: string): Boolean;
    function Freeze: IDelphiSemanticSourceObservations;
    function TryFind(const aFileName: string; out aSource: TDelphiSemanticSourceText): Boolean;
    property MaterializationCount: Integer read fMaterializationCount;
  end;

  TDelphiSemanticSourceEvidence = record
  public
    class function UnitDirectoryObservation(const aDirectory: string;
      out aFileNames: TArray<string>): TDelphiSemanticSourceText; static;
    class function FromItems(const aItems: TArray<TDelphiSemanticSourceText>):
      IDelphiSemanticSourceObservations; static;
    class function WithRole(const aSources: IDelphiSemanticSourceObservations;
      const aRole: string): IDelphiSemanticSourceObservations; static;
    class function TryMerge(const aLeft, aRight: IDelphiSemanticSourceObservations;
      out aCombined: IDelphiSemanticSourceObservations; out aError: string): Boolean; static;
  end;

  TDelphiSemanticSourceLoadResult = record
    Success: Boolean;
    Source: TDelphiSemanticSourceText;
    SourceObservations: IDelphiSemanticSourceObservations;
    Diagnostics: TArray<TDelphiSemanticSourceDiagnostic>;
  end;

  TDelphiSemanticSourceLoader = record
  public
    class function LoadFile(const aFileName: string): TDelphiSemanticSourceLoadResult; static;
  end;

// Empty filenames are the legacy spelling of an owning-unit fact, never a
// reason to replace a nonempty physical include origin.
function FactSourceFileName(const aUnitFileName, aFactFileName: string): string;
function SourcePositionKnown(const aLine, aColumn: Integer): Boolean;

implementation

uses
  System.Classes, System.Generics.Defaults, System.Hash,
  System.IOUtils, System.Masks, System.SysUtils,
  AutoFree, MaxLogic.StrUtils;

type
  TSourceObservations = class(TInterfacedObject, IDelphiSemanticSourceObservations)
  private
    fItems: TArray<TDelphiSemanticSourceText>;
    fItemIndex: TDictionary<string, Integer>;
  public
    constructor Create(const aItems: TArray<TDelphiSemanticSourceText>);
    destructor Destroy; override;
    function GetCount: Integer;
    function GetItem(const aIndex: Integer): TDelphiSemanticSourceText;
    function TryFind(const aFileName: string; out aSource: TDelphiSemanticSourceText): Boolean;
  end;

function FactSourceFileName(const aUnitFileName, aFactFileName: string): string;
begin
  Result := aFactFileName;
  if Result = '' then
    Result := aUnitFileName;
end;

function SourcePositionKnown(const aLine, aColumn: Integer): Boolean;
begin
  Result := (aLine > 0) and (aColumn > 0);
end;

// A lookup absence is bounded by the complete immediate PAS/DCU name set.
// Content changes of selected files still have their separate byte witnesses.
class function TDelphiSemanticSourceEvidence.UnitDirectoryObservation(const aDirectory: string;
  out aFileNames: TArray<string>): TDelphiSemanticSourceText;
var
  g: TGarbos;
  i: Integer;
  lDcuMask, lPasMask: TMask;
  lFiles: TArray<string>;
  lIdentity: string;
begin
  Result := Default(TDelphiSemanticSourceText);
  Result.FileName := ExcludeTrailingPathDelimiter(TPath.GetFullPath(aDirectory));
  Result.Role := 'possible-unit-directory';
  aFileNames := nil;
  lIdentity := 'missing';
  if TDirectory.Exists(Result.FileName) then
  begin
    g := Default(TGarbos);
    GC(lPasMask, TMask.Create('*.pas'), g);
    GC(lDcuMask, TMask.Create('*.dcu'), g);
    // '*.*' takes the RTL's match-all fast path. Reuse its exact unit masks
    // across one immediate-directory walk; the sorted witness is unchanged.
    lFiles := TDirectory.GetFiles(Result.FileName, '*.*', TSearchOption.soTopDirectoryOnly,
      function(const aPath: string; const aSearchRec: TSearchRec): Boolean
      begin
        Result := lPasMask.Matches(aSearchRec.Name) or lDcuMask.Matches(aSearchRec.Name);
      end);
    SetLength(aFileNames, Length(lFiles));
    for i := 0 to High(lFiles) do
      aFileNames[i] := LowerCase(ExtractFileName(lFiles[i]));
    TArray.Sort<string>(aFileNames);
    lIdentity := 'present' + #10 + string.Join(#10, aFileNames);
  end;
  Result.ContentHash := THashSHA2.GetHashString(lIdentity);
end;

constructor TSourceObservations.Create(const aItems: TArray<TDelphiSemanticSourceText>);
var
  i: Integer;
  lPathComparer: IComparer<string>;
begin
  inherited Create;
  fItems := Copy(aItems);
  lPathComparer := TStringComparer.Ordinal;
  TArray.Sort<TDelphiSemanticSourceText>(fItems,
    TComparer<TDelphiSemanticSourceText>.Construct(
      function(const aLeft, aRight: TDelphiSemanticSourceText): Integer
      begin
        Result := lPathComparer.Compare(aLeft.FileName,
          aRight.FileName);
      end));
  fItemIndex := TDictionary<string, Integer>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
  // Preserve the first ordinal-sorted observation for case-insensitive duplicates.
  for i := 0 to High(fItems) do
    if not fItemIndex.ContainsKey(fItems[i].FileName) then
      fItemIndex.Add(fItems[i].FileName, i);
end;

destructor TSourceObservations.Destroy;
begin
  fItemIndex.Free;
  inherited;
end;

function TSourceObservations.GetCount: Integer;
begin
  Result := Length(fItems);
end;

function TSourceObservations.GetItem(const aIndex: Integer): TDelphiSemanticSourceText;
begin
  Result := fItems[aIndex];
end;

function TSourceObservations.TryFind(const aFileName: string;
  out aSource: TDelphiSemanticSourceText): Boolean;
var
  lIndex: Integer;
  lFileName: string;
begin
  aSource := Default(TDelphiSemanticSourceText);
  lFileName := TPath.GetFullPath(aFileName);
  Result := fItemIndex.TryGetValue(lFileName, lIndex);
  if Result then
    aSource := fItems[lIndex];
end;

class function TDelphiSemanticSourceEvidence.FromItems(
  const aItems: TArray<TDelphiSemanticSourceText>): IDelphiSemanticSourceObservations;
begin
  Result := TSourceObservations.Create(aItems);
end;

class function TDelphiSemanticSourceEvidence.WithRole(
  const aSources: IDelphiSemanticSourceObservations;
  const aRole: string): IDelphiSemanticSourceObservations;
var
  lItems: TArray<TDelphiSemanticSourceText>;
  i: Integer;
begin
  Result := nil;
  if aSources = nil then
    Exit;
  SetLength(lItems, aSources.Count);
  for i := 0 to aSources.Count - 1 do
  begin
    lItems[i] := aSources.Items[i];
    lItems[i].Role := aRole;
  end;
  Result := TSourceObservations.Create(lItems);
end;

constructor TDelphiSemanticSourceAccumulator.Create;
begin
  inherited Create;
{$IFDEF MSWINDOWS}
  // Match IOUtils.CheckPathLength: only modern Windows guarantees that a
  // normalized long path can be normalized again without a new exception.
  fRecheckNormalizedPaths := (TOSVersion.Major < 10) or
    ((TOSVersion.Major = 10) and (TOSVersion.Build < 14393));
{$ELSE}
  fRecheckNormalizedPaths := True;
{$ENDIF}
end;

destructor TDelphiSemanticSourceAccumulator.Destroy;
begin
  fKnown.Free;
  fItems.Free;
  inherited Destroy;
end;

procedure TDelphiSemanticSourceAccumulator.RequireUsable;
begin
  if fFailed then
    raise EInvalidOpException.Create(fError);
end;

function TDelphiSemanticSourceAccumulator.AddItems(
  const aSources: IDelphiSemanticSourceObservations; out aError: string): Boolean;
var
  i: Integer;
  lItem, lPrevious: TDelphiSemanticSourceText;
begin
  aError := '';
  for i := 0 to aSources.Count - 1 do
  begin
    lItem := aSources.Items[i];
    lItem.FileName := TPath.GetFullPath(lItem.FileName);
    if fKnown.TryGetValue(lItem.FileName, lPrevious) then
    begin
      if (lPrevious.ContentHash <> lItem.ContentHash) or (lPrevious.Text <> lItem.Text) then
      begin
        aError := 'source.conflicting-observations';
        Exit(False);
      end;
    end else begin
      fKnown.Add(lItem.FileName, lItem);
      fItems.Add(lItem);
    end;
  end;
  Result := True;
end;

function TDelphiSemanticSourceAccumulator.TryAdd(
  const aSources: IDelphiSemanticSourceObservations; out aError: string): Boolean;
var
  lPrevious: IDelphiSemanticSourceObservations;
begin
  aError := '';
  if fFailed then
  begin
    aError := fError;
    Exit(False);
  end;
  Result := True;
  if aSources = nil then
    Exit;
  try
    if not fSeeded then
    begin
      if fFirst = nil then
      begin
        // Do not normalize/deduplicate the lazy first set, even at Freeze.
        fFirst := aSources;
        Exit;
      end;
      fItems := TList<TDelphiSemanticSourceText>.Create;
      fKnown := TDictionary<string, TDelphiSemanticSourceText>.Create(
        TFastCaseAwareComparer.OrdinalIgnoreCase);
      Result := AddItems(fFirst, aError);
      if Result then
        Result := AddItems(aSources, aError);
      fSeeded := True;
      fFirst := nil;
    end else begin
      if fRecheckNormalizedPaths then
      begin
        // Preserve the reference's next-merge exception and ordinal traversal
        // on hosts where GetFullPath is not idempotent on its own output.
        lPrevious := Freeze;
        fKnown.Clear;
        fItems.Clear;
        fFrozen := nil;
        Result := AddItems(lPrevious, aError);
      end;
      if Result then
        Result := AddItems(aSources, aError);
    end;
    fFrozen := nil;
    if not Result then
    begin
      fFailed := True;
      fError := aError;
    end;
  except
    on E: Exception do
    begin
      fFailed := True;
      fError := 'source.accumulation-failed';
      raise;
    end;
  end;
end;

function TDelphiSemanticSourceAccumulator.Freeze: IDelphiSemanticSourceObservations;
begin
  RequireUsable;
  if not fSeeded then
    Exit(fFirst);
  if fFrozen = nil then
  begin
    fFrozen := TDelphiSemanticSourceEvidence.FromItems(fItems.ToArray);
    Inc(fMaterializationCount);
  end;
  Result := fFrozen;
end;

function TDelphiSemanticSourceAccumulator.TryFind(const aFileName: string;
  out aSource: TDelphiSemanticSourceText): Boolean;
begin
  RequireUsable;
  aSource := Default(TDelphiSemanticSourceText);
  if not fSeeded then
    // Keep nil short-circuiting and the first set's ordinal-first lookup.
    Exit((fFirst <> nil) and fFirst.TryFind(aFileName, aSource));
  Result := fKnown.TryGetValue(TPath.GetFullPath(aFileName), aSource);
end;

class function TDelphiSemanticSourceEvidence.TryMerge(
  const aLeft, aRight: IDelphiSemanticSourceObservations;
  out aCombined: IDelphiSemanticSourceObservations; out aError: string): Boolean;
var
  lAccumulator: TDelphiSemanticSourceAccumulator;
  lError: string;
begin
  aCombined := nil;
  aError := 'source.missing-observations';
  Result := False;
  if (aLeft = nil) or (aRight = nil) then
    Exit;
  lAccumulator := TDelphiSemanticSourceAccumulator.Create;
  try
    if not lAccumulator.TryAdd(aLeft, lError) or not lAccumulator.TryAdd(aRight, lError) then
    begin
      aError := lError;
      Exit;
    end;
    aCombined := lAccumulator.Freeze;
    aError := '';
    Result := True;
  finally
    lAccumulator.Free;
  end;
end;

function HashBytes(const aBytes: TBytes): string;
var
  lHash: THashSHA2;
begin
  lHash := THashSHA2.Create;
  if Length(aBytes) > 0 then
    lHash.Update(aBytes);
  Result := lHash.HashAsString;
end;

function IsUtf8Continuation(const aByte: Byte): Boolean;
begin
  Result := (aByte and $C0) = $80;
end;

function IsValidUtf8(const aBytes: TBytes): Boolean;
var
  i: Integer;
begin
  i := 0;
  while i < Length(aBytes) do
  begin
    if aBytes[i] < $80 then
    begin
      Inc(i);
      Continue;
    end;

    if (aBytes[i] >= $C2) and (aBytes[i] <= $DF) then
    begin
      if (i + 1 >= Length(aBytes)) or not IsUtf8Continuation(aBytes[i + 1]) then
        Exit(False);
      Inc(i, 2);
    end else if aBytes[i] = $E0 then
    begin
      if (i + 2 >= Length(aBytes)) or not (aBytes[i + 1] in [$A0..$BF]) or
        not IsUtf8Continuation(aBytes[i + 2]) then
        Exit(False);
      Inc(i, 3);
    end else if (aBytes[i] >= $E1) and (aBytes[i] <= $EC) then
    begin
      if (i + 2 >= Length(aBytes)) or not IsUtf8Continuation(aBytes[i + 1]) or
        not IsUtf8Continuation(aBytes[i + 2]) then
        Exit(False);
      Inc(i, 3);
    end else if aBytes[i] = $ED then
    begin
      if (i + 2 >= Length(aBytes)) or not (aBytes[i + 1] in [$80..$9F]) or
        not IsUtf8Continuation(aBytes[i + 2]) then
        Exit(False);
      Inc(i, 3);
    end else if (aBytes[i] >= $EE) and (aBytes[i] <= $EF) then
    begin
      if (i + 2 >= Length(aBytes)) or not IsUtf8Continuation(aBytes[i + 1]) or
        not IsUtf8Continuation(aBytes[i + 2]) then
        Exit(False);
      Inc(i, 3);
    end else if aBytes[i] = $F0 then
    begin
      if (i + 3 >= Length(aBytes)) or not (aBytes[i + 1] in [$90..$BF]) or
        not IsUtf8Continuation(aBytes[i + 2]) or not IsUtf8Continuation(aBytes[i + 3]) then
        Exit(False);
      Inc(i, 4);
    end else if (aBytes[i] >= $F1) and (aBytes[i] <= $F3) then
    begin
      if (i + 3 >= Length(aBytes)) or not IsUtf8Continuation(aBytes[i + 1]) or
        not IsUtf8Continuation(aBytes[i + 2]) or not IsUtf8Continuation(aBytes[i + 3]) then
        Exit(False);
      Inc(i, 4);
    end else if aBytes[i] = $F4 then
    begin
      if (i + 3 >= Length(aBytes)) or not (aBytes[i + 1] in [$80..$8F]) or
        not IsUtf8Continuation(aBytes[i + 2]) or not IsUtf8Continuation(aBytes[i + 3]) then
        Exit(False);
      Inc(i, 4);
    end else
      Exit(False);
  end;

  Result := True;
end;

function StartsWithUtf8Bom(const aBytes: TBytes): Boolean;
begin
  Result := (Length(aBytes) >= 3) and (aBytes[0] = $EF) and (aBytes[1] = $BB) and
    (aBytes[2] = $BF);
end;

function StartsWithUtf16LeBom(const aBytes: TBytes): Boolean;
begin
  Result := (Length(aBytes) >= 2) and (aBytes[0] = $FF) and (aBytes[1] = $FE);
end;

function StartsWithUtf16BeBom(const aBytes: TBytes): Boolean;
begin
  Result := (Length(aBytes) >= 2) and (aBytes[0] = $FE) and (aBytes[1] = $FF);
end;

procedure AssignLineEndingProvenance(var aSource: TDelphiSemanticSourceText);
var
  i: Integer;
  lCrCount: Integer;
  lCrlfCount: Integer;
  lFirstLineBreak: string;
  lKindCount: Integer;
  lLfCount: Integer;
begin
  lCrCount := 0;
  lCrlfCount := 0;
  lFirstLineBreak := '';
  lLfCount := 0;
  i := 1;
  while i <= Length(aSource.Text) do
  begin
    if aSource.Text[i] = #13 then
    begin
      if (i < Length(aSource.Text)) and (aSource.Text[i + 1] = #10) then
      begin
        Inc(lCrlfCount);
        if lFirstLineBreak = '' then
          lFirstLineBreak := #13#10;
        Inc(i, 2);
        Continue;
      end;
      Inc(lCrCount);
      if lFirstLineBreak = '' then
        lFirstLineBreak := #13;
    end else if aSource.Text[i] = #10 then
    begin
      Inc(lLfCount);
      if lFirstLineBreak = '' then
        lFirstLineBreak := #10;
    end;
    Inc(i);
  end;

  lKindCount := 0;
  if lCrlfCount > 0 then
    Inc(lKindCount);
  if lLfCount > 0 then
    Inc(lKindCount);
  if lCrCount > 0 then
    Inc(lKindCount);

  if lKindCount = 0 then
  begin
    aSource.LineEndingName := 'none';
    aSource.LineBreak := sLineBreak;
  end else if lKindCount > 1 then
  begin
    aSource.LineEndingName := 'mixed';
    aSource.LineBreak := lFirstLineBreak;
  end else if lCrlfCount > 0 then
  begin
    aSource.LineEndingName := 'crlf';
    aSource.LineBreak := #13#10;
  end else if lLfCount > 0 then
  begin
    aSource.LineEndingName := 'lf';
    aSource.LineBreak := #10;
  end else
  begin
    aSource.LineEndingName := 'cr';
    aSource.LineBreak := #13;
  end;
end;

class function TDelphiSemanticSourceLoader.LoadFile(
  const aFileName: string): TDelphiSemanticSourceLoadResult;
var
  lBytes: TBytes;
  lEncoding: TEncoding;
  lFileName: string;
begin
  Result := Default(TDelphiSemanticSourceLoadResult);
  lFileName := TPath.GetFullPath(aFileName);
  Result.Source.FileName := lFileName;

  if not TFile.Exists(lFileName) then
  begin
    Result.Success := False;
    SetLength(Result.Diagnostics, 1);
    Result.Diagnostics[0].Code := 'SOURCE_FILE_NOT_FOUND';
    Result.Diagnostics[0].Message := 'Source file not found: ' + lFileName;
    Result.Diagnostics[0].FileName := lFileName;
    Exit;
  end;

  lBytes := TFile.ReadAllBytes(lFileName);
  Result.Source.ContentHash := HashBytes(lBytes);
  if StartsWithUtf8Bom(lBytes) then
  begin
    Result.Source.Text := TEncoding.UTF8.GetString(lBytes, 3, Length(lBytes) - 3);
    Result.Source.EncodingName := 'utf-8';
  end else if StartsWithUtf16LeBom(lBytes) then
  begin
    Result.Source.Text := TEncoding.Unicode.GetString(lBytes, 2, Length(lBytes) - 2);
    Result.Source.EncodingName := 'utf-16le';
  end else if StartsWithUtf16BeBom(lBytes) then
  begin
    Result.Source.Text := TEncoding.BigEndianUnicode.GetString(lBytes, 2,
      Length(lBytes) - 2);
    Result.Source.EncodingName := 'utf-16be';
  end else if IsValidUtf8(lBytes) then
  begin
    Result.Source.Text := TEncoding.UTF8.GetString(lBytes);
    Result.Source.EncodingName := 'utf-8';
  end else
  begin
    lEncoding := TEncoding.GetEncoding(1252);
    try
      Result.Source.Text := lEncoding.GetString(lBytes);
    finally
      lEncoding.Free;
    end;
    Result.Source.EncodingName := 'windows-1252';
  end;
  AssignLineEndingProvenance(Result.Source);
  Result.SourceObservations := TSourceObservations.Create([Result.Source]);
  Result.Success := True;
end;

end.
