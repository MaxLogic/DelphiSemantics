unit DelphiSemantics.Model.Text;

interface

function NormalizeRoutineSignature(const aSignature: string): string;
function IsIdentifierStart(const aChar: Char): Boolean;
function IsIdentifierChar(const aChar: Char): Boolean;
function IsMemberAccessDot(const aText: string; const aIndex: Integer): Boolean;
function IsWordAt(const aText: string; const aOffset: Integer; const aWord: string): Boolean; overload;
function IsWordAt(const aText, aWord: string; const aIndex: Integer): Boolean; overload;
function TextContainsIdentifier(const aText, aIdentifier: string): Boolean;
procedure SkipPascalStringLiteral(const aText: string; var aIndex: Integer);
function NextRawStringLiteral(const aText: string; var aOffset: Integer;
  out aValue: string; out aStart: Integer): Boolean; overload;
function NextRawStringLiteral(const aText: string; var aOffset: Integer;
  out aValue: string; out aStart: Integer; const aCodeOnly: Boolean): Boolean; overload;
function HasPublishedTypeInfoSwitch(const aRaw: string): Boolean;
function HasRuntimeNameConsumerCode(const aCode: string): Boolean;
function DirectiveNameExpressions(const aRaw: string): TArray<string>;
function ImplicitExternalNameReason(const aCode, aName: string): string;
function SanitizeCodeText(const aText: string): string;
function FindSectionKeywordOffset(const aText, aKeyword: string): Integer;
function TrySplitTopLevelCommaList(const aText: string; out aParts: TArray<string>): Boolean;
function TryParsePointerCastName(const aText: string; out aName: string): Boolean;

implementation

uses
  System.Generics.Collections, System.RegularExpressions, System.StrUtils, System.SysUtils,
  AutoFree, SimpleParser.Lexer, SimpleParser.Lexer.Types;

type
  TCommaListLexer = class(TmwBasePasLex)
  private
    fFailed: Boolean;
    procedure HandleMessage(aSender: TObject; const aKind: TMessageEventType;
      const aMessage: string; x, y: Integer);
  end;

// DS-713: escaped identifiers and trivia cannot introduce a source section.
function FindSectionKeywordOffset(const aText, aKeyword: string): Integer;
var
  lKind: TptTokenKind;
  lLexer: TmwBasePasLex;
begin
  Result := 0;
  if SameText(aKeyword, 'interface') then
    lKind := ptInterface
  else if SameText(aKeyword, 'implementation') then
    lKind := ptImplementation
  else if SameText(aKeyword, 'initialization') then
    lKind := ptInitialization
  else if SameText(aKeyword, 'finalization') then
    lKind := ptFinalization
  else
    Exit;
  lLexer := TmwBasePasLex.Create;
  try
    lLexer.UseDefines := False;
    lLexer.Origin := aText;
    while lLexer.TokenID <> ptNull do
    begin
      if lLexer.TokenID = lKind then
        Exit(lLexer.TokenPos + 1);
      lLexer.Next;
    end;
  finally
    lLexer.Free;
  end;
end;


// These syntax-only checks grant refusal authority, never a binding or edit.
function HasPublishedTypeInfoSwitch(const aRaw: string): Boolean;
var
  lMatch: TMatch;
  lSwitch: string;
begin
  Result := False;
  for lMatch in TRegEx.Matches(aRaw, '\{\$([^}]*)\}', [roIgnoreCase]) do
    for lSwitch in lMatch.Groups[1].Value.Split([',']) do
      if SameText(lSwitch.Trim, 'M+') or SameText(lSwitch.Trim, 'TYPEINFO ON') then
        Exit(True);
  for lMatch in TRegEx.Matches(aRaw, '\(\*\$([\s\S]*?)\*\)', [roIgnoreCase]) do
    for lSwitch in lMatch.Groups[1].Value.Split([',']) do
      if SameText(lSwitch.Trim, 'M+') or SameText(lSwitch.Trim, 'TYPEINFO ON') then
        Exit(True);
end;

function HasRuntimeNameConsumerCode(const aCode: string): Boolean;
begin
  Result := TRegEx.IsMatch(aCode,
    '\b(?:FindComponent|MethodAddress|FindClass|GetMethod|GetProperty|GetField|GetFields|FindType|GetType|FieldAddress|' +
    'GetPropValue|SetPropValue|GetPropInfo|IsPublishedProp|(?:Get|Set)\w*Prop)\s*\(' +
    '|\b(?:ClassName|ClassNameIs|QualifiedClassName|UnitName|GetTypeName)\b' +
    '|\b(?:PTypeInfo|TypeInfo)\s*\(', [roIgnoreCase]);
end;

function DirectiveNameExpressions(const aRaw: string): TArray<string>;
var
  lMatch: TMatch;
begin
  Result := nil;
  for lMatch in TRegEx.Matches(aRaw,
    '\{\$\s*(?:IF|ELSEIF)\b([^}]*)\}', [roIgnoreCase]) do
    Result := Result + [SanitizeCodeText(lMatch.Groups[1].Value)];
  for lMatch in TRegEx.Matches(aRaw,
    '\(\*\$\s*(?:IF|ELSEIF)\b([\s\S]*?)\*\)', [roIgnoreCase]) do
    Result := Result + [SanitizeCodeText(lMatch.Groups[1].Value)];
end;

// Follow routine headings and export entries lexically. An explicit import
// name/index is stable; an export index alone does not freeze its public name.
function ImplicitExternalNameReason(const aCode, aName: string): string;
var
  lLexer: TmwBasePasLex;
  lRoutineMatches, lEntryMatches, lExplicit: Boolean;
  lDepth: Integer;
begin
  Result := '';
  // Escaped identifiers keep '&' in lexer tokens; their ABI spelling does not.
  lRoutineMatches := False;
  lDepth := 0;
  lLexer := TmwBasePasLex.Create;
  try
    lLexer.UseDefines := False;
    lLexer.Origin := aCode;
    if lLexer.IsJunk then
      lLexer.NextNoJunk;
    while lLexer.TokenID <> ptNull do
    begin
      if (lDepth = 0) and (lLexer.TokenID in [ptProcedure, ptFunction]) then
      begin
        lLexer.NextNoJunk;
        lRoutineMatches := SameText(lLexer.Token.Replace('&', ''), aName.Replace('&', ''));
        while lLexer.TokenID = ptIdentifier do
        begin
          lLexer.NextNoJunk;
          if lLexer.TokenID <> ptPoint then
            Break;
          lLexer.NextNoJunk;
          lRoutineMatches := SameText(lLexer.Token.Replace('&', ''), aName.Replace('&', ''));
        end;
        Continue;
      end;
      if lLexer.TokenID = ptRoundOpen then
        Inc(lDepth)
      else if lLexer.TokenID = ptRoundClose then
        Dec(lDepth);
      if lLexer.TokenID in [ptBegin, ptEnd, ptImplementation, ptAsm] then
        lRoutineMatches := False;
      if (lLexer.TokenID = ptIdentifier) and (lLexer.ExID = ptExternal) then
      begin
        lExplicit := False;
        lLexer.NextNoJunk;
        while not (lLexer.TokenID in [ptNull, ptSemiColon]) do
        begin
          if (lLexer.TokenID = ptIdentifier) and (lLexer.ExID in [ptName, ptIndex]) then
            lExplicit := True;
          lLexer.NextNoJunk;
        end;
        if lRoutineMatches and not lExplicit then
          Exit('external-pascal-name');
        lRoutineMatches := False;
        Continue;
      end;
      if lLexer.TokenID = ptExports then
      begin
        lLexer.NextNoJunk;
        while not (lLexer.TokenID in [ptNull, ptSemiColon]) do
        begin
          lEntryMatches := SameText(lLexer.Token.Replace('&', ''), aName.Replace('&', ''));
          lExplicit := False;
          while not (lLexer.TokenID in [ptNull, ptSemiColon, ptComma]) do
          begin
            if (lLexer.TokenID = ptIdentifier) and (lLexer.ExID = ptName) then
              lExplicit := True;
            if lLexer.TokenID = ptPoint then
            begin
              lLexer.NextNoJunk;
              lEntryMatches := SameText(lLexer.Token.Replace('&', ''), aName.Replace('&', ''));
              Continue;
            end;
            lLexer.NextNoJunk;
          end;
          if lEntryMatches and not lExplicit then
            Exit('export-pascal-name');
          if lLexer.TokenID = ptComma then
            lLexer.NextNoJunk;
        end;
        Continue;
      end;
      lLexer.NextNoJunk;
    end;
  finally
    lLexer.Free;
  end;
end;

procedure TCommaListLexer.HandleMessage(aSender: TObject;
  const aKind: TMessageEventType; const aMessage: string; x, y: Integer);
begin
  fFailed := True;
end;

// DS-666: syntax alone does not prove a cast; consumers must resolve this name as a type.
function TryParsePointerCastName(const aText: string; out aName: string): Boolean;
var
  lArgumentEnd: Integer;
  lArgumentStart: Integer;
  lDepth: Integer;
  lLexer: TCommaListLexer;
  lName: string;
  lParts: TArray<string>;
  lText: string;
begin
  Result := False;
  aName := '';
  lText := Trim(aText);
  if (Pos('(', lText) = 0) or not EndsText('^', lText) then
    Exit;
  lLexer := TCommaListLexer.Create;
  try
    lLexer.OnMessage := lLexer.HandleMessage;
    lLexer.UseDefines := False;
    lLexer.Origin := lText;
    if lLexer.TokenID <> ptIdentifier then
      Exit;
    lName := lLexer.Token;
    lLexer.NextNoJunk;
    if lLexer.TokenID <> ptRoundOpen then
      Exit;
    lArgumentStart := lLexer.TokenPos + 2;
    lArgumentEnd := 0;
    lDepth := 1;
    lLexer.NextNoJunk;
    while (lLexer.TokenID <> ptNull) and not lLexer.fFailed and (lDepth > 0) do
    begin
      if lLexer.TokenID = ptRoundOpen then
        Inc(lDepth)
      else if lLexer.TokenID = ptRoundClose then
      begin
        Dec(lDepth);
        if lDepth = 0 then
          lArgumentEnd := lLexer.TokenPos + 1;
      end;
      lLexer.NextNoJunk;
    end;
    if (lDepth <> 0) or lLexer.fFailed or (lLexer.TokenID <> ptPointerSymbol) or
      not TrySplitTopLevelCommaList(Copy(lText, lArgumentStart,
        lArgumentEnd - lArgumentStart), lParts) or (Length(lParts) <> 1) then
      Exit;
    lLexer.NextNoJunk;
    Result := not lLexer.fFailed and (lLexer.TokenID = ptNull);
    if Result then
      aName := lName;
  finally
    lLexer.Free;
  end;
end;

function NormalizeRoutineSignature(const aSignature: string): string;
var
  g: TGarbos;
  lBuilder: TStringBuilder;
  lLexer: TCommaListLexer;
  lToken: string;
begin
  g := Default(TGarbos);
  GC(lBuilder, TStringBuilder.Create, g);
  GC(lLexer, TCommaListLexer.Create, g);
  lLexer.OnMessage := lLexer.HandleMessage;
  lLexer.UseDefines := False;
  lLexer.Origin := aSignature;
  while (lLexer.TokenID <> ptNull) and not lLexer.fFailed do
  begin
    if not IsTokenIDJunk(lLexer.TokenID) then
    begin
      if lLexer.TokenID in [ptUnknown, ptError] then
        Exit('invalid:' + aSignature);
      lToken := lLexer.Token;
      // Literal contents retain case and spacing; length framing preserves token boundaries.
      if Pos('''', lToken) = 0 then
        lToken := LowerCase(lToken);
      lBuilder.Append(Length(lToken)).Append(':').Append(lToken);
    end;
    lLexer.Next;
  end;
  if lLexer.fFailed then
    Exit('invalid:' + aSignature);
  Result := lBuilder.ToString;
end;

function TrySplitTopLevelCommaList(const aText: string; out aParts: TArray<string>): Boolean;
var
  g: TGarbos;
  lDepth: Integer;
  lHasToken: Boolean;
  lLexer: TCommaListLexer;
  lParts: TList<string>;
  lStack: TArray<TptTokenKind>;
  lStart: Integer;
begin
  Result := False;
  aParts := nil;
  if Pos(#0, aText) > 0 then
    Exit;
  g := Default(TGarbos);
  GC(lLexer, TCommaListLexer.Create, g);
  GC(lParts, TList<string>.Create, g);
  lLexer.OnMessage := lLexer.HandleMessage;
  lLexer.UseDefines := False;
  lLexer.Origin := aText;
  SetLength(lStack, Length(aText));
  lDepth := 0;
  lStart := 1;
  lHasToken := False;
  while (lLexer.TokenID <> ptNull) and not lLexer.fFailed do
  begin
    if not IsTokenIDJunk(lLexer.TokenID) then
    begin
      if lLexer.TokenID in [ptUnknown, ptError] then
        Exit;
      if lLexer.TokenID in [ptRoundOpen, ptSquareOpen] then
      begin
        lStack[lDepth] := lLexer.TokenID;
        Inc(lDepth);
      end else if lLexer.TokenID in [ptRoundClose, ptSquareClose] then
      begin
        if lDepth = 0 then
          Exit;
        Dec(lDepth);
        if ((lLexer.TokenID = ptRoundClose) and (lStack[lDepth] <> ptRoundOpen)) or
          ((lLexer.TokenID = ptSquareClose) and (lStack[lDepth] <> ptSquareOpen)) then
          Exit;
      end else if (lLexer.TokenID = ptComma) and (lDepth = 0) then
      begin
        if not lHasToken then
          Exit;
        lParts.Add(Trim(Copy(aText, lStart, lLexer.TokenPos + 1 - lStart)));
        lStart := lLexer.TokenPos + lLexer.TokenLen + 1;
        lHasToken := False;
        lLexer.Next;
        Continue;
      end;
      lHasToken := True;
    end;
    lLexer.Next;
  end;
  if lLexer.fFailed or (lDepth <> 0) or not lHasToken then
    Exit;
  lParts.Add(Trim(Copy(aText, lStart, MaxInt)));
  aParts := lParts.ToArray;
  Result := True;
end;

function IsIdentifierStart(const aChar: Char): Boolean;
begin
  Result := CharInSet(aChar, ['A'..'Z', 'a'..'z', '_']);
end;

function IsIdentifierChar(const aChar: Char): Boolean;
begin
  Result := IsIdentifierStart(aChar) or CharInSet(aChar, ['0'..'9']);
end;

function IsMemberAccessDot(const aText: string; const aIndex: Integer): Boolean;
begin
  // Either dot of a range separator `..` (subranges, case labels, set and array bounds)
  // is not a member access.
  Result := (aIndex > 0) and (aIndex <= Length(aText)) and (aText[aIndex] = '.') and
    not ((aIndex > 1) and (aText[aIndex - 1] = '.')) and
    not ((aIndex < Length(aText)) and (aText[aIndex + 1] = '.'));
end;

function IsWordAt(const aText: string; const aOffset: Integer; const aWord: string): Boolean; overload;
var
  lAfterOffset: Integer;
begin
  Result := False;
  if (aOffset < 1) or (aWord = '') or (aOffset + Length(aWord) - 1 > Length(aText)) then
    Exit;

  lAfterOffset := aOffset + Length(aWord);
  Result := SameText(Copy(aText, aOffset, Length(aWord)), aWord) and
    ((aOffset = 1) or not IsIdentifierChar(aText[aOffset - 1])) and
    ((lAfterOffset > Length(aText)) or not IsIdentifierChar(aText[lAfterOffset]));
end;

function IsWordAt(const aText, aWord: string; const aIndex: Integer): Boolean; overload;
begin
  Result := IsWordAt(aText, aIndex, aWord);
end;

function TextContainsIdentifier(const aText, aIdentifier: string): Boolean;
var
  lIndex: Integer;
begin
  Result := False;
  if (aText = '') or (aIdentifier = '') then
    Exit;

  lIndex := Pos(aIdentifier, aText);
  while lIndex > 0 do
  begin
    if IsWordAt(aText, lIndex, aIdentifier) then
      Exit(True);
    lIndex := PosEx(aIdentifier, aText, lIndex + 1);
  end;
end;

// Return the first offset after one literal. Delphi 12 multiline delimiters are
// an odd run of at least three quotes immediately followed by a line break.
procedure SkipPascalStringLiteral(const aText: string; var aIndex: Integer);
var
  lOpeningCount, lQuoteCount, lStart: Integer;
begin
  lStart := aIndex;
  while (aIndex <= Length(aText)) and (aText[aIndex] = #39) do
    Inc(aIndex);
  lOpeningCount := aIndex - lStart;
  if (lOpeningCount >= 3) and Odd(lOpeningCount) and
    (aIndex <= Length(aText)) and CharInSet(aText[aIndex], [#10, #13]) then
  begin
    while aIndex <= Length(aText) do
    begin
      if aText[aIndex] <> #39 then
      begin
        Inc(aIndex);
        Continue;
      end;
      lStart := aIndex;
      while (aIndex <= Length(aText)) and (aText[aIndex] = #39) do
        Inc(aIndex);
      lQuoteCount := aIndex - lStart;
      if lQuoteCount = lOpeningCount then
        Exit;
    end;
    Exit;
  end;
  aIndex := lStart + 1;
  while aIndex <= Length(aText) do
  begin
    if aText[aIndex] = #39 then
    begin
      Inc(aIndex);
      if (aIndex > Length(aText)) or (aText[aIndex] <> #39) then
        Exit;
    end;
    Inc(aIndex);
  end;
end;

// Scan raw source conservatively, including comments and inactive arms. Decode
// Delphi literal sequences iteratively: quoted parts, character codes and the
// indentation-stripped Delphi 12 multiline form. No computed expression is run.
function ReadRawStringParts(const aText: string; var aOffset: Integer;
  out aValue: string; out aStart: Integer; const aCodeOnly: Boolean): Boolean;
var
  lBuilder: TStringBuilder;
  lStart, lEnd, lQuotes, lCount, lCode, lNext, lLineStart, lIndent, lBodyEnd: Integer;
  lPart, lLine, lDigits: string;

  procedure SkipTrivia(var aIndex: Integer; const aJoinParts: Boolean = False);
  begin
    while aIndex <= Length(aText) do
    begin
      if CharInSet(aText[aIndex], [#9, #10, #13, #32]) then
        Inc(aIndex)
      else if aCodeOnly and (aText[aIndex] = '{') then
      begin
        // Conditional directives separate alternative literal sequences.
        if aJoinParts and (Copy(aText, aIndex, 2) = '{$') then
          Break;
        Inc(aIndex);
        while (aIndex <= Length(aText)) and (aText[aIndex] <> '}') do
          Inc(aIndex);
        Inc(aIndex);
      end else if aCodeOnly and (Copy(aText, aIndex, 2) = '(*') then
      begin
        if aJoinParts and (Copy(aText, aIndex, 3) = '(*$') then
          Break;
        Inc(aIndex, 2);
        while (aIndex <= Length(aText)) and (Copy(aText, aIndex, 2) <> '*)') do
          Inc(aIndex);
        Inc(aIndex, 2);
      end else if aCodeOnly and (Copy(aText, aIndex, 2) = '//') then
      begin
        Inc(aIndex, 2);
        while (aIndex <= Length(aText)) and not CharInSet(aText[aIndex], [#10, #13]) do
          Inc(aIndex);
      end else
        Break;
    end;
  end;

begin
  Result := False;
  aValue := '';
  aStart := 0;
  while aOffset <= Length(aText) do
  begin
    SkipTrivia(aOffset);
    if (aOffset > Length(aText)) or CharInSet(aText[aOffset], [#39, '#']) then
      Break;
    Inc(aOffset);
  end;
  if aOffset > Length(aText) then
    Exit;
  aStart := aOffset;
  lBuilder := TStringBuilder.Create;
  try
    while aOffset <= Length(aText) do
    begin
      if aText[aOffset] = '#' then
      begin
        Inc(aOffset);
        lStart := aOffset;
        if (aOffset <= Length(aText)) and (aText[aOffset] = '$') then
        begin
          Inc(aOffset);
          while (aOffset <= Length(aText)) and CharInSet(aText[aOffset], ['0'..'9', 'a'..'f', 'A'..'F']) do
            Inc(aOffset);
        end else
          while (aOffset <= Length(aText)) and CharInSet(aText[aOffset], ['0'..'9']) do
            Inc(aOffset);
        lDigits := Copy(aText, lStart, aOffset - lStart);
        if not TryStrToInt(lDigits, lCode) or (lCode < 0) or (lCode > $10FFFF) then
          Break;
        if lCode <= $FFFF then
          lBuilder.Append(Char(lCode))
        else
        begin
          Dec(lCode, $10000);
          lBuilder.Append(Char($D800 + (lCode shr 10)));
          lBuilder.Append(Char($DC00 + (lCode and $3FF)));
        end;
        Result := True;
      end else if aText[aOffset] = #39 then
      begin
        lStart := aOffset;
        lNext := aOffset;
        while (lNext <= Length(aText)) and (aText[lNext] = #39) do
          Inc(lNext);
        lQuotes := lNext - aOffset;
        if (lQuotes >= 3) and Odd(lQuotes) and (lNext <= Length(aText)) and
          CharInSet(aText[lNext], [#10, #13]) then
        begin
          // Opening/closing delimiter lines are not part of the value. The
          // closing indentation is stripped from each content line.
          aOffset := lNext;
          if aText[aOffset] = #13 then
            Inc(aOffset);
          if (aOffset <= Length(aText)) and (aText[aOffset] = #10) then
            Inc(aOffset);
          lStart := aOffset;
          lEnd := PosEx(StringOfChar(#39, lQuotes), aText, aOffset);
          if lEnd = 0 then
          begin
            aOffset := Length(aText) + 1;
            Break;
          end;
          lLineStart := lEnd;
          while (lLineStart > lStart) and not CharInSet(aText[lLineStart - 1], [#10, #13]) do
            Dec(lLineStart);
          lIndent := lEnd - lLineStart;
          lBodyEnd := lLineStart;
          if (lBodyEnd > lStart) and (aText[lBodyEnd - 1] = #10) then
            Dec(lBodyEnd);
          if (lBodyEnd > lStart) and (aText[lBodyEnd - 1] = #13) then
            Dec(lBodyEnd);
          lPart := Copy(aText, lStart, lBodyEnd - lStart);
          lCount := 0;
          for lLine in lPart.Replace(#13#10, #10).Replace(#13, #10).Split([#10]) do
          begin
            if lCount > 0 then
              lBuilder.Append(#13#10);
            lNext := 1;
            while (lNext <= Length(lLine)) and (lNext <= lIndent) and
              CharInSet(lLine[lNext], [#9, #32]) do
              Inc(lNext);
            lBuilder.Append(Copy(lLine, lNext, MaxInt));
            Inc(lCount);
          end;
          aOffset := lEnd + lQuotes;
          Result := True;
        end else begin
          Inc(aOffset);
          while aOffset <= Length(aText) do
          begin
            if aText[aOffset] = #39 then
            begin
              Inc(aOffset);
              if (aOffset > Length(aText)) or (aText[aOffset] <> #39) then
              begin
                Result := True;
                Break;
              end;
            end;
            lBuilder.Append(aText[aOffset]);
            Inc(aOffset);
          end;
        end;
      end else
        Break;
      lNext := aOffset;
      SkipTrivia(lNext, True);
      if (lNext > Length(aText)) or not CharInSet(aText[lNext], [#39, '#']) then
        Break;
      aOffset := lNext;
    end;
    aValue := lBuilder.ToString;
    // Even an invalid raw # fragment must advance without ending the scan.
    Result := True;
  finally
    lBuilder.Free;
  end;
end;

function NextRawStringLiteral(const aText: string; var aOffset: Integer;
  out aValue: string; out aStart: Integer): Boolean;
begin
  Result := NextRawStringLiteral(aText, aOffset, aValue, aStart, False);
end;

function NextRawStringLiteral(const aText: string; var aOffset: Integer;
  out aValue: string; out aStart: Integer; const aCodeOnly: Boolean): Boolean;
var
  lNext: Integer;

  procedure SkipTrivia(var aIndex: Integer);
  begin
    while aIndex <= Length(aText) do
    begin
      if CharInSet(aText[aIndex], [#9, #10, #13, #32]) then
        Inc(aIndex)
      else if aCodeOnly and (aText[aIndex] = '{') and
        (Copy(aText, aIndex, 2) <> '{$') then
      begin
        while (aIndex <= Length(aText)) and (aText[aIndex] <> '}') do
          Inc(aIndex);
        Inc(aIndex);
      end else if aCodeOnly and (Copy(aText, aIndex, 2) = '(*') and
        (Copy(aText, aIndex, 3) <> '(*$') then
      begin
        Inc(aIndex, 2);
        while (aIndex <= Length(aText)) and (Copy(aText, aIndex, 2) <> '*)') do
          Inc(aIndex);
        Inc(aIndex, 2);
      end else if aCodeOnly and (Copy(aText, aIndex, 2) = '//') then
      begin
        while (aIndex <= Length(aText)) and not CharInSet(aText[aIndex], [#10, #13]) do
          Inc(aIndex);
      end else
        Break;
    end;
  end;

  function ReadExpression(var aIndex: Integer; out aResult: string;
    const aDepth: Integer): Boolean;
  var
    lCursor, lPartStart: Integer;
    lPart: string;

    function ReadOperand(var aCursor: Integer; out aOperand: string): Boolean;
    var
      lEnd: Integer;
    begin
      Result := False;
      SkipTrivia(aCursor);
      if (aCursor > Length(aText)) or (aDepth >= 64) then
        Exit;
      if aText[aCursor] = '(' then
      begin
        lEnd := aCursor + 1;
        if not ReadExpression(lEnd, aOperand, aDepth + 1) then
          Exit;
        SkipTrivia(lEnd);
        if (lEnd > Length(aText)) or (aText[lEnd] <> ')') then
          Exit;
        aCursor := lEnd + 1;
        Exit(True);
      end;
      if CharInSet(aText[aCursor], [#39, '#']) then
        Result := ReadRawStringParts(aText, aCursor, aOperand, lPartStart, aCodeOnly);
    end;

  begin
    Result := ReadOperand(aIndex, aResult);
    if not Result then
      Exit;
    while True do
    begin
      lCursor := aIndex;
      SkipTrivia(lCursor);
      if (lCursor > Length(aText)) or (aText[lCursor] <> '+') then
        Break;
      Inc(lCursor);
      if not ReadOperand(lCursor, lPart) then
        Break;
      aResult := aResult + lPart;
      aIndex := lCursor;
    end;
  end;

begin
  Result := False;
  aValue := '';
  aStart := 0;
  while aOffset <= Length(aText) do
  begin
    SkipTrivia(aOffset);
    lNext := aOffset;
    if ReadExpression(lNext, aValue, 0) then
    begin
      aStart := aOffset;
      aOffset := lNext;
      Exit(True);
    end;
    Inc(aOffset);
  end;
end;

function SanitizeCodeText(const aText: string): string;
var
  i: Integer;
  lCommentMode: Integer;
  lLiteralEnd: Integer;
  sb: TStringBuilder;
begin
  sb := TStringBuilder.Create(Length(aText));
  try
    lCommentMode := 0;
    i := 1;
    while i <= Length(aText) do
    begin
      if lCommentMode = 1 then
      begin
        if CharInSet(aText[i], [#10, #13]) then
          sb.Append(aText[i])
        else
          sb.Append(' ');
        if (aText[i] = '*') and (i < Length(aText)) and (aText[i + 1] = ')') then
        begin
          sb.Append(' ');
          Inc(i);
          lCommentMode := 0;
        end;
      end else if lCommentMode = 2 then
      begin
        if CharInSet(aText[i], [#10, #13]) then
          sb.Append(aText[i])
        else
          sb.Append(' ');
        if aText[i] = '}' then
          lCommentMode := 0;
      end else if lCommentMode = 3 then
      begin
        if CharInSet(aText[i], [#10, #13]) then
        begin
          sb.Append(aText[i]);
          lCommentMode := 0;
        end else
          sb.Append(' ');
      end else if aText[i] = #39 then
      begin
        lLiteralEnd := i;
        SkipPascalStringLiteral(aText, lLiteralEnd);
        while i < lLiteralEnd do
        begin
          if CharInSet(aText[i], [#10, #13]) then
            sb.Append(aText[i])
          else
            sb.Append(' ');
          Inc(i);
        end;
        Continue;
      end else if (aText[i] = '(') and (i < Length(aText)) and (aText[i + 1] = '*') then
      begin
        sb.Append(' ');
        sb.Append(' ');
        Inc(i);
        lCommentMode := 1;
      end else if aText[i] = '{' then
      begin
        sb.Append(' ');
        lCommentMode := 2;
      end else if (aText[i] = '/') and (i < Length(aText)) and (aText[i + 1] = '/') then
      begin
        sb.Append(' ');
        sb.Append(' ');
        Inc(i);
        lCommentMode := 3;
      end else
        sb.Append(aText[i]);
      Inc(i);
    end;
    Result := sb.ToString;
  finally
    sb.Free;
  end;
end;

end.
