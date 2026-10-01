unit DelphiSemantics.Source;

interface

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

  TDelphiSemanticSourceEvidence = record
  public
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

implementation

uses
  System.Classes, System.Generics.Collections, System.Generics.Defaults, System.Hash,
  System.IOUtils, System.SysUtils,
  AutoFree, MaxLogic.StrUtils;

type
  TSourceObservations = class(TInterfacedObject, IDelphiSemanticSourceObservations)
  private
    fItems: TArray<TDelphiSemanticSourceText>;
  public
    constructor Create(const aItems: TArray<TDelphiSemanticSourceText>);
    function GetCount: Integer;
    function GetItem(const aIndex: Integer): TDelphiSemanticSourceText;
    function TryFind(const aFileName: string; out aSource: TDelphiSemanticSourceText): Boolean;
  end;

constructor TSourceObservations.Create(const aItems: TArray<TDelphiSemanticSourceText>);
var
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
  lItem: TDelphiSemanticSourceText;
  lFileName: string;
begin
  aSource := Default(TDelphiSemanticSourceText);
  lFileName := TPath.GetFullPath(aFileName);
  for lItem in fItems do
    if TFastCaseAwareComparer.OrdinalIgnoreCase.Equals(lItem.FileName, lFileName) then
    begin
      aSource := lItem;
      Exit(True);
    end;
  Result := False;
end;

class function TDelphiSemanticSourceEvidence.TryMerge(
  const aLeft, aRight: IDelphiSemanticSourceObservations;
  out aCombined: IDelphiSemanticSourceObservations; out aError: string): Boolean;
var
  g: TGarbos;
  i: Integer;
  lItem, lPrevious: TDelphiSemanticSourceText;
  lItems: TList<TDelphiSemanticSourceText>;
  lKnown: TDictionary<string, TDelphiSemanticSourceText>;
  lObservations: IDelphiSemanticSourceObservations;
begin
  aCombined := nil;
  aError := 'source.missing-observations';
  Result := False;
  if (aLeft = nil) or (aRight = nil) then
    Exit;
  g := Default(TGarbos);
  GC(lItems, TList<TDelphiSemanticSourceText>.Create, g);
  GC(lKnown, TDictionary<string, TDelphiSemanticSourceText>.Create(
    TFastCaseAwareComparer.OrdinalIgnoreCase), g);
  for lObservations in [aLeft, aRight] do
    for i := 0 to lObservations.Count - 1 do
    begin
      lItem := lObservations.Items[i];
      lItem.FileName := TPath.GetFullPath(lItem.FileName);
      if lKnown.TryGetValue(lItem.FileName, lPrevious) then
      begin
        if (lPrevious.ContentHash <> lItem.ContentHash) or
          (lPrevious.Text <> lItem.Text) then
        begin
          aError := 'source.conflicting-observations';
          Exit;
        end;
      end else begin
        lKnown.Add(lItem.FileName, lItem);
        lItems.Add(lItem);
      end;
    end;
  aCombined := TSourceObservations.Create(lItems.ToArray);
  aError := '';
  Result := True;
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
