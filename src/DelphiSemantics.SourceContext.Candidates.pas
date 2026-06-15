unit DelphiSemantics.SourceContext.Candidates;

interface

type
  TDelphiSemanticSourceContextCandidates = record
  public
    class function TryParseFindingLocationWithColumn(const aFinding: string;
      out aFileToken: string; out aLine, aColumn: Integer): Boolean; static;
    class function TrySelectCandidate(const aFinding: string; const aLines: TArray<string>;
      const aTargetLineIndex: Integer; const aFileToken: string; const aLine,
      aColumn: Integer; out aToken, aEnclosingSymbol, aError: string): Boolean; static;
  end;

implementation

uses
  System.RegularExpressions, System.StrUtils, System.SysUtils;

function IsIdentifierChar(const aChar: Char): Boolean;
begin
  Result := (aChar = '_') or CharInSet(aChar, ['A'..'Z', 'a'..'z', '0'..'9']);
end;

function IsPascalKeyword(const aToken: string): Boolean;
begin
  Result := MatchText(aToken, ['begin', 'class', 'const', 'constructor', 'destructor', 'do',
    'else', 'end', 'except', 'finally', 'for', 'function', 'implementation', 'interface',
    'operator', 'procedure', 'record', 'then', 'try', 'unit']);
end;

function TryExtractIdentifierAtColumn(const aLineText: string; const aColumn: Integer;
  out aToken: string): Boolean;
var
  lIndex: Integer;
  lLeft: Integer;
  lRight: Integer;
begin
  aToken := '';
  if (aLineText = '') or (aColumn <= 0) or (aColumn > Length(aLineText) + 1) then
    Exit(False);

  lIndex := aColumn;
  if lIndex > Length(aLineText) then
    Dec(lIndex);
  if not IsIdentifierChar(aLineText[lIndex]) then
  begin
    if (lIndex > 1) and IsIdentifierChar(aLineText[lIndex - 1]) then
      Dec(lIndex)
    else
      Exit(False);
  end;

  lLeft := lIndex;
  while (lLeft > 1) and IsIdentifierChar(aLineText[lLeft - 1]) do
    Dec(lLeft);

  lRight := lIndex;
  while (lRight < Length(aLineText)) and IsIdentifierChar(aLineText[lRight + 1]) do
    Inc(lRight);

  aToken := Copy(aLineText, lLeft, lRight - lLeft + 1);
  Result := (aToken <> '') and not IsPascalKeyword(aToken);
end;

function TryExtractFirstIdentifierFromLine(const aLineText: string; out aToken: string): Boolean;
var
  lIndex: Integer;
  lStart: Integer;
begin
  aToken := '';
  lIndex := 1;
  while lIndex <= Length(aLineText) do
  begin
    if IsIdentifierChar(aLineText[lIndex]) and not CharInSet(aLineText[lIndex], ['0'..'9']) then
    begin
      lStart := lIndex;
      Inc(lIndex);
      while (lIndex <= Length(aLineText)) and IsIdentifierChar(aLineText[lIndex]) do
        Inc(lIndex);
      aToken := Copy(aLineText, lStart, lIndex - lStart);
      if (aToken <> '') and not IsPascalKeyword(aToken) then
        Exit(True);
    end;
    Inc(lIndex);
  end;
  Result := False;
end;

function TryExtractEnclosingSymbolFromLine(const aLineText: string; out aSymbol: string): Boolean;
var
  lMatch: TMatch;
begin
  aSymbol := '';
  lMatch := TRegEx.Match(aLineText,
    '^\s*(?:class\s+)?(?:procedure|function|constructor|destructor)\s+([A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)*)',
    [roIgnoreCase]);
  if not lMatch.Success then
  begin
    lMatch := TRegEx.Match(aLineText, '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*class\b',
      [roIgnoreCase]);
    if not lMatch.Success then
      Exit(False);
  end;

  aSymbol := lMatch.Groups[1].Value;
  Result := aSymbol <> '';
end;

function TryExtractQuotedIdentifier(const aFinding: string; out aIdentifier: string): Boolean;
var
  lMatch: TMatch;
begin
  aIdentifier := '';
  lMatch := TRegEx.Match(aFinding, '''([A-Za-z_][A-Za-z0-9_]*)''');
  if not lMatch.Success then
    Exit(False);

  aIdentifier := lMatch.Groups[1].Value;
  Result := aIdentifier <> '';
end;

function TryFindIdentifierInContext(const aLines: TArray<string>; const aIdentifier: string;
  out aCandidate: string): Boolean;
var
  lLineText: string;
  lPattern: string;
begin
  aCandidate := '';
  if aIdentifier = '' then
    Exit(False);

  lPattern := '\b' + TRegEx.Escape(aIdentifier) + '\b';
  for lLineText in aLines do
    if TRegEx.IsMatch(lLineText, lPattern) then
    begin
      aCandidate := aIdentifier;
      Exit(True);
    end;

  Result := False;
end;

class function TDelphiSemanticSourceContextCandidates.TryParseFindingLocationWithColumn(
  const aFinding: string; out aFileToken: string; out aLine, aColumn: Integer): Boolean;
var
  lMatch: TMatch;
begin
  aFileToken := '';
  aLine := 0;
  aColumn := 0;
  lMatch := TRegEx.Match(aFinding, '^(.+)\((\d+)(?:,(\d+))?\):');
  if not lMatch.Success then
    Exit(False);

  aFileToken := Trim(lMatch.Groups[1].Value);
  aLine := StrToIntDef(lMatch.Groups[2].Value, 0);
  if lMatch.Groups.Count >= 4 then
    aColumn := StrToIntDef(lMatch.Groups[3].Value, 0);
  Result := (aFileToken <> '') and (aLine > 0) and (aColumn >= 0);
end;

class function TDelphiSemanticSourceContextCandidates.TrySelectCandidate(const aFinding: string;
  const aLines: TArray<string>; const aTargetLineIndex: Integer; const aFileToken: string;
  const aLine, aColumn: Integer; out aToken, aEnclosingSymbol, aError: string): Boolean;
var
  lIndex: Integer;
  lLineText: string;
begin
  aToken := '';
  aEnclosingSymbol := '';
  aError := '';
  if (aTargetLineIndex < 0) or (aTargetLineIndex > High(aLines)) then
  begin
    aError := Format('Could not derive enrichment candidate from %s(%d,%d).',
      [aFileToken, aLine, aColumn]);
    Exit(False);
  end;

  lLineText := aLines[aTargetLineIndex];
  if (aColumn > 0) and TryExtractIdentifierAtColumn(lLineText, aColumn, aToken) then
    Exit(True);
  if TryExtractQuotedIdentifier(aFinding, aToken) and TryFindIdentifierInContext(aLines, aToken,
    aToken) then
    Exit(True);
  if TryExtractFirstIdentifierFromLine(lLineText, aToken) then
    Exit(True);

  lIndex := aTargetLineIndex;
  while lIndex >= 0 do
  begin
    if TryExtractEnclosingSymbolFromLine(aLines[lIndex], aEnclosingSymbol) then
      Exit(True);
    Dec(lIndex);
  end;

  aError := Format('Could not derive enrichment candidate from %s(%d,%d).',
    [aFileToken, aLine, aColumn]);
  Result := False;
end;

end.
