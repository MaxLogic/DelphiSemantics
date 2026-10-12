unit DelphiSemantics.SourceConditionals;

interface

type
  // Internal, source-coordinate activity evidence; no compiler values are inferred.
  TDelphiSemanticSourceActivity = (saInactive, saActive, saUnknown);

  TDelphiSemanticActivitySpan = record
    FileName: string;
    SourceText: string;
    StartOffset: Integer;
    EndOffset: Integer;
    Activity: TDelphiSemanticSourceActivity;
  end;

  TDelphiSemanticSourceConditionals = record
  public
    class function UnavailableActivity: string; static;
    class function EncodeActivity(const aSource, aFileName: string;
      const aSpans: TArray<TDelphiSemanticActivitySpan>): string; static;
    class function SourceForScan(const aSource, aEvidence: string): string; static;
    class function UnknownAtOffset(const aSource, aEvidence: string;
      const aOffset: Integer): Boolean; static;
    class function RangeIsKnownActive(const aSource, aEvidence: string;
      const aStartOffset, aEndOffset: Integer): Boolean; static;
    class function UnknownAtPosition(const aSource, aEvidence: string;
      const aLine, aColumn: Integer): Boolean; static;
    class function InsideInactiveNeverConditionalRegion(const aLines: TArray<string>;
      const aStartLine, aLine: Integer): Boolean; static;
    class function LineHasConditionalDirective(const aLineText: string): Boolean; overload; static;
    class function LineHasConditionalDirective(const aLines: TArray<string>;
      const aLine: Integer): Boolean; overload; static;
  end;

implementation

uses
  System.StrUtils, System.SysUtils;

const
  // Stored in the existing exact-text pool. Plain evidence retains its original bytes.
  cActivityPrefix = #1'DS-ACTIVITY-1:';

class function TDelphiSemanticSourceConditionals.UnavailableActivity: string;
begin
  // A malformed-length marker means no source offset is proven active or inactive.
  // We retain this state in the existing evidence slot on both cold and warm models.
  Result := cActivityPrefix;
end;

class function TDelphiSemanticSourceConditionals.EncodeActivity(const aSource,
  aFileName: string; const aSpans: TArray<TDelphiSemanticActivitySpan>): string;
var
  i: Integer;
  lSpan: TDelphiSemanticActivitySpan;
  lState: Char;
begin
  Result := StringOfChar('?', Length(aSource));
  for i := 1 to Length(aSource) do
    if CharInSet(aSource[i], [#9, #10, #13, ' ']) then
      Result[i] := 'I';
  for lSpan in aSpans do
    if SameText(lSpan.FileName, aFileName) then
    begin
      if (lSpan.SourceText <> aSource) or (lSpan.StartOffset < 1) or
        (lSpan.EndOffset > Length(aSource) + 1) or
        (lSpan.EndOffset < lSpan.StartOffset) then
        Exit(UnavailableActivity);
      case lSpan.Activity of
        saActive: lState := 'A';
        saUnknown: lState := '?';
      else
        lState := 'I';
      end;
      for i := lSpan.StartOffset to lSpan.EndOffset - 1 do
        Result[i] := lState;
    end;
  Result := cActivityPrefix + Result;
end;

class function TDelphiSemanticSourceConditionals.SourceForScan(const aSource,
  aEvidence: string): string;
var
  i: Integer;
begin
  if StartsStr(cActivityPrefix, aEvidence) then
  begin
    Result := aSource;
    if Length(aEvidence) <> Length(cActivityPrefix) + Length(aSource) then
      Exit;
    for i := 1 to Length(aSource) do
      if (aEvidence[Length(cActivityPrefix) + i] = 'I') and
        not CharInSet(Result[i], [#13, #10]) then
        Result[i] := ' ';
  end else if (aEvidence <> '') and (Length(aEvidence) = Length(aSource)) then
    Result := aEvidence
  else
    Result := aSource;
end;

class function TDelphiSemanticSourceConditionals.UnknownAtOffset(const aSource,
  aEvidence: string; const aOffset: Integer): Boolean;
begin
  Result := False;
  if not StartsStr(cActivityPrefix, aEvidence) then
    Exit;
  if (Length(aEvidence) <> Length(cActivityPrefix) + Length(aSource)) or
    (aOffset < 1) or (aOffset > Length(aSource)) then
    Exit(True);
  Result := not CharInSet(aEvidence[Length(cActivityPrefix) + aOffset], ['A', 'I']);
end;

class function TDelphiSemanticSourceConditionals.RangeIsKnownActive(const aSource,
  aEvidence: string; const aStartOffset, aEndOffset: Integer): Boolean;
var
  i: Integer;
  lLastOffset: Integer;
  lEncoded: Boolean;
begin
  Result := False;
  if (aStartOffset < 1) or (aEndOffset < aStartOffset) or
    (aEndOffset > Length(aSource) + 1) then
    Exit;
  lEncoded := StartsStr(cActivityPrefix, aEvidence);
  if lEncoded and (Length(aEvidence) <> Length(cActivityPrefix) + Length(aSource)) then
    Exit;
  if (not lEncoded) and (aEvidence <> '') and (Length(aEvidence) <> Length(aSource)) then
    Exit;
  // Source ranges carry inclusive end columns. The legacy EOF sentinel has no character.
  lLastOffset := aEndOffset;
  if lLastOffset > Length(aSource) then
    lLastOffset := Length(aSource);
  for i := aStartOffset to lLastOffset do
  begin
    if lEncoded then
    begin
      // Proven inactive spans preserve the base raw-text rewrite behavior.
      // Only unknown or unavailable activity blocks the whole source range.
      if not CharInSet(aEvidence[Length(cActivityPrefix) + i], ['A', 'I']) then
        Exit;
    end else if not CharInSet(aSource[i], [#9, #10, #13, ' ']) and
      (aEvidence <> '') and (aEvidence[i] <> aSource[i]) then
      Exit;
  end;
  Result := True;
end;

class function TDelphiSemanticSourceConditionals.UnknownAtPosition(const aSource,
  aEvidence: string; const aLine, aColumn: Integer): Boolean;
var
  i: Integer;
  lLine: Integer;
  lStart: Integer;
begin
  Result := False;
  if not StartsStr(cActivityPrefix, aEvidence) then
    Exit;
  lLine := 1;
  lStart := 1;
  for i := 1 to Length(aSource) do
  begin
    if lLine = aLine then
      Exit(UnknownAtOffset(aSource, aEvidence, lStart + aColumn - 1));
    if aSource[i] = #10 then
    begin
      Inc(lLine);
      lStart := i + 1;
    end;
  end;
  Result := True;
end;

class function TDelphiSemanticSourceConditionals.InsideInactiveNeverConditionalRegion(
  const aLines: TArray<string>; const aStartLine, aLine: Integer): Boolean;
var
  i: Integer;
  lInactiveDepth: Integer;
  lLineText: string;
begin
  Result := False;
  if (aStartLine <= 0) or (aLine <= 0) then
    Exit;
  lInactiveDepth := 0;
  for i := aStartLine to aLine do
  begin
    if (i <= 0) or (i > Length(aLines)) then
      Continue;
    lLineText := Trim(aLines[i - 1]);
    if StartsText('{$IFDEF NEVER', lLineText) then
      Inc(lInactiveDepth)
    else if StartsText('{$ENDIF', lLineText) and (lInactiveDepth > 0) then
      Dec(lInactiveDepth);
    if (i = aLine) and (lInactiveDepth > 0) then
      Exit(True);
  end;
end;

class function TDelphiSemanticSourceConditionals.LineHasConditionalDirective(
  const aLineText: string): Boolean;
begin
  Result := StartsText('{$IF', Trim(aLineText));
end;

class function TDelphiSemanticSourceConditionals.LineHasConditionalDirective(
  const aLines: TArray<string>; const aLine: Integer): Boolean;
begin
  Result := (aLine > 0) and (aLine <= Length(aLines)) and
    LineHasConditionalDirective(aLines[aLine - 1]);
end;

end.
