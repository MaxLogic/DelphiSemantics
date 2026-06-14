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
    EncodingName: string;
  end;

  TDelphiSemanticSourceLoadResult = record
    Success: Boolean;
    Source: TDelphiSemanticSourceText;
    Diagnostics: TArray<TDelphiSemanticSourceDiagnostic>;
  end;

  TDelphiSemanticSourceLoader = record
  public
    class function LoadFile(const aFileName: string): TDelphiSemanticSourceLoadResult; static;
  end;

implementation

uses
  System.Classes, System.IOUtils, System.SysUtils;

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

class function TDelphiSemanticSourceLoader.LoadFile(
  const aFileName: string): TDelphiSemanticSourceLoadResult;
var
  lBytes: TBytes;
  lEncoding: TEncoding;
  lFileName: string;
begin
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
  Result.Success := True;
end;

end.
