unit DelphiSemantics.WithBinding.Inventory;

interface

uses
  System.Generics.Collections,
  DelphiSemantics.Model, DelphiSemantics.WithBinding;

type
  TDelphiSemanticWithBindingInventory = record
  public
    class function BuildInventorySymbols(const aModel: TDelphiSemanticUnitModel):
      TArray<TDelphiSemanticInventorySymbol>; static;
    class function ExpandInventorySymbols(const aSymbols: TArray<TDelphiSemanticInventorySymbol>):
      TArray<TDelphiSemanticInventorySymbol>; static;
    class procedure AddCompilerProfileCompatibilitySymbols(
      const aSymbols: TList<TDelphiSemanticInventorySymbol>); static;
    class procedure AddProjectExternalUnitSymbols(const aModels: TArray<TDelphiSemanticUnitModel>;
      const aSymbols: TList<TDelphiSemanticInventorySymbol>); static;
  end;

implementation

uses
  System.Character, System.Classes, System.RegularExpressions, System.StrUtils, System.SysUtils,
  MaxLogic.StrUtils, SimpleParser.Lexer, SimpleParser.Lexer.Types,
  DelphiSemantics.CompilerProfile, DelphiSemantics.Resolve.TypeResolver;

type
  TRelatedInventoryMemberRelation = record
    SourceOwnerType: string;
    TargetOwnerType: string;
    TargetOwnerUnitName: string;
    TargetOwnerFileName: string;
    TargetOwnerSectionKind: string;
    TargetOwnerLine: Integer;
    TargetOwnerColumn: Integer;
    IsHelper: Boolean;
  end;

procedure AddInventorySymbol(const aSymbols: TList<TDelphiSemanticInventorySymbol>;
  const aSymbol: TDelphiSemanticInventorySymbol);
begin
  if aSymbol.Name <> '' then
    aSymbols.Add(aSymbol);
end;

function InventoryMaskTrivia(const aText: string; const aMaskRoutineParameters: Boolean): string;
var
  i: Integer;
  lLexer: TmwBasePasLex;
  lDepth: Integer;
  lInSignature, lClassPrefix: Boolean;
  lMask: Boolean;
  lStart: Integer;
  lToken: string;
begin
  // DS-730: token positions preserve columns, and the lexer carries block-comment state
  // across physical lines. Strings and compiler directives remain source text.
  Result := aText;
  lLexer := TmwBasePasLex.Create;
  try
    lLexer.UseDefines := False;
    lLexer.Origin := aText;
    lDepth := 0;
    lInSignature := False;
    lClassPrefix := False;
    while lLexer.TokenID <> ptNull do
    begin
      lToken := lLexer.Token;
      lMask := (lLexer.TokenID in [ptAnsiComment, ptBorComment, ptSlashesComment]) and
        not StartsText('{$', lToken) and not StartsText('(*$', lToken);
      if aMaskRoutineParameters and not lMask then
      begin
        if lLexer.TokenID in [ptProcedure, ptFunction, ptConstructor, ptDestructor] then
          lInSignature := True;
        if lClassPrefix and (lLexer.TokenID = ptIdentifier) and SameText(lToken, 'operator') then
          lInSignature := True;
        if lInSignature then
        begin
          if lLexer.TokenID = ptRoundOpen then
            Inc(lDepth);
          lMask := lDepth > 0;
          if (lLexer.TokenID = ptRoundClose) and (lDepth > 0) then
            Dec(lDepth);
          if (lLexer.TokenID = ptSemiColon) and (lDepth = 0) then
            lInSignature := False;
        end;
      end;
      if lMask then
      begin
        lStart := lLexer.TokenPos + 1;
        for i := lStart to lStart + Length(lToken) - 1 do
          if not CharInSet(Result[i], [#13, #10]) then
            Result[i] := ' ';
      end;
      if not (lLexer.TokenID in [ptSpace, ptCRLF, ptAnsiComment, ptBorComment, ptSlashesComment]) then
        lClassPrefix := lLexer.TokenID = ptClass;
      lLexer.Next;
    end;
  finally
    lLexer.Free;
  end;
end;

function InventoryCleanLine(const aLine: string): string;
begin
  Result := Trim(InventoryMaskTrivia(aLine, False));
end;

function InventoryIsIdentifierChar(const aValue: Char): Boolean;
begin
  Result := (aValue = '_') or aValue.IsLetterOrDigit;
end;

function InventoryRemoveInlineConditionalBlocks(const aText: string): string;
var
  lEndPos: Integer;
  lStartPos: Integer;
  lUpper: string;
begin
  Result := aText;
  repeat
    lUpper := UpperCase(Result);
    lStartPos := Pos('{$IF', lUpper);
    if lStartPos = 0 then
      Break;
    lEndPos := PosEx('{$ENDIF}', lUpper, lStartPos + 1);
    if lEndPos = 0 then
      Break;
    Delete(Result, lStartPos, lEndPos - lStartPos + Length('{$ENDIF}'));
  until False;

  repeat
    lStartPos := Pos('{$', Result);
    if lStartPos = 0 then
      Break;
    lEndPos := PosEx('}', Result, lStartPos + 1);
    if lEndPos = 0 then
      Break;
    Delete(Result, lStartPos, lEndPos - lStartPos + 1);
  until False;
  Result := Trim(Result);
end;

function InventoryIsTopLevelLine(const aLine: string): Boolean;
begin
  Result := (Trim(aLine) <> '') and (TrimLeft(aLine) = aLine);
end;

function InventoryIsVisibilityLine(const aLine: string): Boolean;
begin
  Result := MatchText(LowerCase(Trim(aLine)), ['private', 'protected', 'public', 'published',
    'strict private', 'strict protected']);
end;

function InventoryIsDirectMemberKind(const aKind: string): Boolean;
begin
  Result := MatchText(aKind, ['field', 'property', 'method', 'constant', 'class-var']);
end;

function InventoryIsRoutineStart(const aLine: string): Boolean;
var
  lText: string;
begin
  lText := LowerCase(Trim(aLine));
  Result := StartsText('procedure ', lText) or StartsText('function ', lText) or
    StartsText('class procedure ', lText) or StartsText('class function ', lText) or
    StartsText('constructor ', lText) or StartsText('destructor ', lText) or
    StartsText('class operator ', lText) or
    StartsText('class constructor ', lText) or StartsText('class destructor ', lText);
end;

function InventoryIsAttributeLine(const aLine: string): Boolean;
begin
  Result := StartsText('[', Trim(aLine));
end;

function InventoryIsConditionalDirectiveLine(const aLine: string): Boolean;
var
  lText: string;
begin
  lText := UpperCase(Trim(aLine));
  Result := StartsText('{$IF', lText) or StartsText('{$ELSE', lText) or
    StartsText('{$ELSEIF', lText) or StartsText('{$ENDIF', lText) or
    StartsText('{$IFEND', lText);
end;

function InventoryIsConditionalStartDirective(const aLine: string): Boolean;
var
  lText: string;
begin
  lText := UpperCase(Trim(aLine));
  Result := StartsText('{$IF', lText) and (not StartsText('{$IFEND', lText));
end;

function InventoryIsConditionalEndDirective(const aLine: string): Boolean;
var
  lText: string;
begin
  lText := UpperCase(Trim(aLine));
  Result := StartsText('{$ENDIF', lText) or StartsText('{$IFEND', lText);
end;

function InventoryIsMultilineDeclarationStart(const aLine: string): Boolean;
var
  lText: string;
begin
  lText := Trim(aLine);
  Result := (Pos(',', lText) > 0) and (Pos(':', lText) = 0) and (Pos(';', lText) = 0) and
    (not InventoryIsRoutineStart(lText));
end;

function InventoryFindColumn(const aLine, aName: string): Integer;
begin
  Result := Pos(aName, aLine);
  if Result = 0 then
    Result := 1;
end;

// Returns the 1-based column of aName as a whole, case-insensitive identifier
// at or after aFromColumn, or 0. A plain Pos would match "Value" inside
// "SetValue" or "i" inside "lList".
function InventoryFindIdentifierColumn(const aLine, aName: string;
  const aFromColumn: Integer): Integer;
var
  lEnd: Integer;
  lLine: string;
  lName: string;
  lPos: Integer;
begin
  Result := 0;
  if (aName = '') or (aFromColumn < 1) then
    Exit;
  lLine := UpperCase(aLine);
  lName := UpperCase(aName);
  lPos := PosEx(lName, lLine, aFromColumn);
  while lPos > 0 do
  begin
    lEnd := lPos + Length(lName);
    if ((lPos = 1) or (not InventoryIsIdentifierChar(aLine[lPos - 1]))) and
      ((lEnd > Length(aLine)) or (not InventoryIsIdentifierChar(aLine[lEnd]))) then
      Exit(lPos);
    lPos := PosEx(lName, lLine, lPos + 1);
  end;
end;

function InventorySimpleTypeName(const aTypeName: string): string;
var
  lDelimiterPos: Integer;
  lTypeName: string;
begin
  lTypeName := Trim(aTypeName);
  if StartsText('^', lTypeName) then
    Delete(lTypeName, 1, 1);
  lDelimiterPos := Pos('<', lTypeName);
  if lDelimiterPos = 0 then
    lDelimiterPos := Pos('[', lTypeName);
  if lDelimiterPos = 0 then
    lDelimiterPos := Pos(' ', lTypeName);
  if lDelimiterPos > 0 then
    lTypeName := Trim(Copy(lTypeName, 1, lDelimiterPos - 1));
  lDelimiterPos := LastDelimiter('.', lTypeName);
  if lDelimiterPos > 0 then
    lTypeName := Copy(lTypeName, lDelimiterPos + 1, MaxInt);
  Result := lTypeName;
end;

function InventoryIsBuiltInTypeName(const aTypeName: string): Boolean;
begin
  Result := MatchText(aTypeName, ['AnsiString', 'Array', 'Boolean', 'Byte',
    'Cardinal', 'Char', 'Currency', 'Date', 'DateTime', 'Double', 'Extended',
    'Integer', 'Int64', 'NativeInt', 'NativeUInt', 'Pointer', 'Real',
    'ShortInt', 'Single', 'SmallInt', 'String', 'UInt64', 'Variant',
    'WideChar', 'WideString', 'Word']);
end;

function InventoryTryDeclaration(const aLine: string; out aNames: TArray<string>;
  out aTypeName: string): Boolean;
var
  lColonPos: Integer;
  lEqualsPos: Integer;
  lLeft: string;
  lLine: string;
  lNames: TList<string>;
  lPart: string;
  lParts: TArray<string>;
  lRawPart: string;
  lRight: string;
  lSemiPos: Integer;
begin
  Result := False;
  SetLength(aNames, 0);
  aTypeName := '';
  lLine := InventoryRemoveInlineConditionalBlocks(aLine);
  lColonPos := Pos(':', lLine);
  if lColonPos = 0 then
    Exit;

  lLeft := Trim(Copy(lLine, 1, lColonPos - 1));
  if (lLeft = '') or InventoryIsRoutineStart(lLeft) or StartsText('property ', LowerCase(lLeft)) then
    Exit;

  lRight := Trim(Copy(lLine, lColonPos + 1, MaxInt));
  lEqualsPos := Pos('=', lRight);
  if lEqualsPos > 0 then
    lRight := Trim(Copy(lRight, 1, lEqualsPos - 1));
  lSemiPos := Pos(';', lRight);
  if lSemiPos > 0 then
    lRight := Trim(Copy(lRight, 1, lSemiPos - 1));
  if lRight = '' then
    Exit;

  lNames := TList<string>.Create;
  try
    lParts := lLeft.Split([',']);
    for lRawPart in lParts do
    begin
      lPart := Trim(lRawPart);
      if not TRegEx.IsMatch(lPart, '^&?[\p{L}_][\p{L}\p{Nd}_]*$') then
        Exit;
      lNames.Add(lPart);
    end;
    aNames := lNames.ToArray;
  finally
    lNames.Free;
  end;
  aTypeName := lRight;
  Result := Length(aNames) > 0;
end;

function InventoryTryConstDeclaration(const aLine: string; out aName: string;
  out aTypeName: string): Boolean;
var
  lColonPos: Integer;
  lEqualsPos: Integer;
begin
  Result := False;
  aName := '';
  aTypeName := '';
  lEqualsPos := Pos('=', aLine);
  if lEqualsPos = 0 then
    Exit;

  lColonPos := Pos(':', aLine);
  if (lColonPos > 0) and (lColonPos < lEqualsPos) then
  begin
    aName := Trim(Copy(aLine, 1, lColonPos - 1));
    aTypeName := Trim(Copy(aLine, lColonPos + 1, lEqualsPos - lColonPos - 1));
  end else
  begin
    aName := Trim(Copy(aLine, 1, lEqualsPos - 1));
    aTypeName := '';
  end;
  Result := aName <> '';
end;

// Splits "A = 1; B: TPoint = (X: 1; Y: 2); C = 'x;y'" at the semicolons that end a declaration,
// ignoring those inside string literals and parentheses or brackets.
function InventorySplitTopLevelDeclarations(const aText: string): TArray<string>;
var
  i: Integer;
  lDepth: Integer;
  lInString: Boolean;
  lParts: TList<string>;
  lStart: Integer;

  procedure AddPart(const aEndExclusive: Integer);
  var
    lPart: string;
  begin
    lPart := Trim(Copy(aText, lStart, aEndExclusive - lStart));
    if lPart <> '' then
      lParts.Add(lPart);
  end;

begin
  lParts := TList<string>.Create;
  try
    lDepth := 0;
    lInString := False;
    lStart := 1;
    for i := 1 to Length(aText) do
    begin
      if aText[i] = '''' then
        lInString := not lInString
      else if lInString then
        Continue
      else if CharInSet(aText[i], ['(', '[']) then
        Inc(lDepth)
      else if CharInSet(aText[i], [')', ']']) and (lDepth > 0) then
        Dec(lDepth)
      else if (aText[i] = ';') and (lDepth = 0) then
      begin
        AddPart(i);
        lStart := i + 1;
      end;
    end;
    AddPart(Length(aText) + 1);
    Result := lParts.ToArray;
  finally
    lParts.Free;
  end;
end;

function InventoryTryEnumValues(const aTypeText: string; out aNames: TArray<string>): Boolean;
var
  i: Integer;
  lClosePos: Integer;
  lEqualsPos: Integer;
  lList: TList<string>;
  lName: string;
  lOpenPos: Integer;
  lPart: string;
  lParts: TArray<string>;
  lPrefix: string;
  lRawPart: string;
  lText: string;
begin
  Result := False;
  SetLength(aNames, 0);
  lText := Trim(aTypeText);
  lEqualsPos := Pos('=', lText);
  lOpenPos := Pos('(', lText);
  lClosePos := PosEx(')', lText, lOpenPos + 1);
  if (lEqualsPos = 0) or (lOpenPos <= lEqualsPos) or (lClosePos <= lOpenPos) then
    Exit;

  lPrefix := Copy(lText, 1, lOpenPos - 1);
  if ContainsText(lPrefix, 'procedure') or ContainsText(lPrefix, 'function') then
    Exit;

  lList := TList<string>.Create;
  try
    lParts := Copy(lText, lOpenPos + 1, lClosePos - lOpenPos - 1).Split([',']);
    for lRawPart in lParts do
    begin
      lPart := Trim(lRawPart);
      lName := '';
      i := 1;
      while (i <= Length(lPart)) and InventoryIsIdentifierChar(lPart[i]) do
      begin
        lName := lName + lPart[i];
        Inc(i);
      end;
      if lName <> '' then
        lList.Add(lName);
    end;
    aNames := lList.ToArray;
    Result := Length(aNames) > 0;
  finally
    lList.Free;
  end;
end;

function InventoryTryPropertyDeclaration(const aLine: string; out aName, aTypeName: string;
  out aIsDefault, aIsIndexed: Boolean; out aIndexParameterCount: Integer): Boolean;
var
  i: Integer;
  lBracketDepth: Integer;
  lIndexText: string;
  lMemberText: string;
  lNameEnd: Integer;
  lPropertyTypeEnd: Integer;
  lTypePos: Integer;
begin
  Result := False;
  aName := '';
  aTypeName := '';
  aIsDefault := False;
  aIsIndexed := False;
  aIndexParameterCount := 0;
  if not StartsText('property ', LowerCase(aLine)) then
    Exit;

  lMemberText := Trim(Copy(aLine, Length('property ') + 1, MaxInt));
  aIsDefault := ContainsText(LowerCase(lMemberText), ' default');
  lBracketDepth := 0;
  lTypePos := 0;
  for i := 1 to Length(lMemberText) do
  begin
    if lMemberText[i] = '[' then
      Inc(lBracketDepth)
    else if (lMemberText[i] = ']') and (lBracketDepth > 0) then
      Dec(lBracketDepth)
    else if (lMemberText[i] = ':') and (lBracketDepth = 0) then
    begin
      lTypePos := i;
      Break;
    end;
  end;

  if lTypePos > 0 then
  begin
    aTypeName := Trim(Copy(lMemberText, lTypePos + 1, MaxInt));
    lPropertyTypeEnd := Pos(' read ', LowerCase(aTypeName));
    if lPropertyTypeEnd = 0 then
      lPropertyTypeEnd := Pos(' write ', LowerCase(aTypeName));
    if lPropertyTypeEnd = 0 then
      lPropertyTypeEnd := Pos(' index ', LowerCase(aTypeName));
    if lPropertyTypeEnd = 0 then
      lPropertyTypeEnd := Pos(' default', LowerCase(aTypeName));
    if lPropertyTypeEnd = 0 then
      lPropertyTypeEnd := Pos(';', aTypeName);
    if lPropertyTypeEnd > 0 then
      aTypeName := Trim(Copy(aTypeName, 1, lPropertyTypeEnd - 1));
    lMemberText := Trim(Copy(lMemberText, 1, lTypePos - 1));
  end;

  lNameEnd := Pos('[', lMemberText);
  if lNameEnd > 0 then
  begin
    aIsIndexed := True;
    lIndexText := Copy(lMemberText, lNameEnd + 1, LastDelimiter(']', lMemberText) - lNameEnd - 1);
    if Trim(lIndexText) <> '' then
      aIndexParameterCount := Length(lIndexText.Split([';']));
  end else
    lNameEnd := Pos(';', lMemberText);

  if lNameEnd > 0 then
    aName := Trim(Copy(lMemberText, 1, lNameEnd - 1))
  else
    aName := Trim(lMemberText);
  Result := aName <> '';
end;

function InventoryTryTypeAlias(const aLine: string; out aName: string;
  out aTypeName: string): Boolean;
var
  lEqualsPos: Integer;
  lRight: string;
  lSemiPos: Integer;
begin
  Result := False;
  aName := '';
  aTypeName := '';
  lEqualsPos := Pos('=', aLine);
  if lEqualsPos = 0 then
    Exit;

  aName := Trim(Copy(aLine, 1, lEqualsPos - 1));
  lRight := Trim(Copy(aLine, lEqualsPos + 1, MaxInt));
  lSemiPos := Pos(';', lRight);
  if lSemiPos > 0 then
    lRight := Trim(Copy(lRight, 1, lSemiPos - 1));

  aTypeName := lRight;
  Result := (aName <> '') and (aTypeName <> '');
end;

function InventoryTryTypeStart(const aLine: string; out aName, aCategory: string): Boolean;
var
  lEqualsPos: Integer;
  lLower: string;
begin
  Result := False;
  aName := '';
  aCategory := 'unknown';
  lEqualsPos := Pos('=', aLine);
  if lEqualsPos = 0 then
    Exit;

  lLower := LowerCase(aLine);
  if (Pos(' record', lLower) = 0) and (Pos(' class', lLower) = 0) and
    (Pos(' interface', lLower) = 0) then
    Exit;

  if Pos(' record', lLower) > 0 then
    aCategory := 'record'
  else if Pos(' interface', lLower) > 0 then
    aCategory := 'interface'
  else if Pos(' class', lLower) > 0 then
    aCategory := 'class';

  aName := Trim(Copy(aLine, 1, lEqualsPos - 1));
  Result := aName <> '';
end;

function InventoryTryVariantTagDeclaration(const aLine: string; out aName,
  aTypeName: string): Boolean;
var
  lColonPos: Integer;
  lOfPos: Integer;
  lRest: string;
  lRestLower: string;
  lText: string;
begin
  Result := False;
  aName := '';
  aTypeName := '';
  lText := Trim(aLine);
  if not StartsText('case ', LowerCase(lText)) then
    Exit;

  lRest := Trim(Copy(lText, Length('case ') + 1, MaxInt));
  lRestLower := LowerCase(lRest);
  lColonPos := Pos(':', lRest);
  lOfPos := Pos(' of', lRestLower);
  if (lColonPos = 0) or (lOfPos = 0) or (lOfPos < lColonPos) then
    Exit;

  aName := Trim(Copy(lRest, 1, lColonPos - 1));
  aTypeName := Trim(Copy(lRest, lColonPos + 1, lOfPos - lColonPos - 1));
  Result := (aName <> '') and (aTypeName <> '');
end;

function InventoryVariantFieldDeclarationLine(const aLine: string): string;
var
  lInnerText: string;
  lOpenPos: Integer;
  lText: string;
begin
  Result := aLine;
  lText := Trim(aLine);
  lOpenPos := Pos('(', lText);
  if (lOpenPos > 1) and (Pos(':', Copy(lText, 1, lOpenPos - 1)) > 0) then
  begin
    lInnerText := Copy(lText, lOpenPos + 1, MaxInt);
    if Pos(':', lInnerText) > 0 then
      lText := Trim(Copy(lText, lOpenPos, MaxInt));
  end;
  if StartsText('(', lText) then
  begin
    lText := Trim(Copy(lText, 2, MaxInt));
    if EndsText(');', lText) then
      Result := Trim(Copy(lText, 1, Length(lText) - 2)) + ';'
    else if EndsText(')', lText) then
      Result := Trim(Copy(lText, 1, Length(lText) - 1)) + ';'
    else
      Result := lText;
  end else if EndsText(');', lText) then
    Result := Trim(Copy(lText, 1, Length(lText) - 2)) + ';';
end;

function InventoryTryTypeRelation(const aLine: string; out aRelatedTypeName: string;
  out aIsHelper: Boolean): Boolean;
var
  lClosePos: Integer;
  lLower: string;
  lRelationPos: Integer;
  lStartPos: Integer;
  lText: string;
begin
  aRelatedTypeName := '';
  aIsHelper := False;
  lText := Trim(aLine);
  lLower := LowerCase(lText);

  lRelationPos := Pos(' helper for ', lLower);
  if lRelationPos > 0 then
  begin
    aIsHelper := True;
    aRelatedTypeName := Trim(Copy(lText, lRelationPos + Length(' helper for '), MaxInt));
    lClosePos := Pos(';', aRelatedTypeName);
    if lClosePos > 0 then
      aRelatedTypeName := Trim(Copy(aRelatedTypeName, 1, lClosePos - 1));
    Exit(aRelatedTypeName <> '');
  end;
  if Pos(' helper(', lLower) > 0 then
  begin
    aIsHelper := True;
    Exit(False);
  end;

  lStartPos := Pos('class(', lLower);
  if lStartPos > 0 then
  begin
    Inc(lStartPos, Length('class('));
    lClosePos := PosEx(')', lText, lStartPos);
    if lClosePos > lStartPos then
      aRelatedTypeName := Trim(Copy(lText, lStartPos, lClosePos - lStartPos));
    lClosePos := Pos(',', aRelatedTypeName);
    if lClosePos > 0 then
      aRelatedTypeName := Trim(Copy(aRelatedTypeName, 1, lClosePos - 1));
  end;
  if aRelatedTypeName = '' then
  begin
    lStartPos := Pos('interface(', lLower);
    if lStartPos > 0 then
    begin
      Inc(lStartPos, Length('interface('));
      lClosePos := PosEx(')', lText, lStartPos);
      if lClosePos > lStartPos then
        aRelatedTypeName := Trim(Copy(lText, lStartPos, lClosePos - lStartPos));
    end;
  end;
  Result := aRelatedTypeName <> '';
end;

function InventoryTryRoutineName(const aLine: string; out aName: string): Boolean;
var
  lNameEnd: Integer;
  lNameStart: Integer;
  lText: string;
begin
  Result := False;
  aName := '';
  lText := Trim(aLine);
  if StartsText('class procedure ', lText) then
    lNameStart := Length('class procedure ') + 1
  else if StartsText('class function ', lText) then
    lNameStart := Length('class function ') + 1
  else if StartsText('procedure ', lText) then
    lNameStart := Length('procedure ') + 1
  else if StartsText('function ', lText) then
    lNameStart := Length('function ') + 1
  else if StartsText('constructor ', lText) then
    lNameStart := Length('constructor ') + 1
  else if StartsText('destructor ', lText) then
    lNameStart := Length('destructor ') + 1
  else
    Exit;

  lNameEnd := lNameStart;
  while lNameEnd <= Length(lText) do
  begin
    if InventoryIsIdentifierChar(lText[lNameEnd]) or (lText[lNameEnd] = '.') then
      Inc(lNameEnd)
    else
      Break;
  end;
  aName := Copy(lText, lNameStart, lNameEnd - lNameStart);
  Result := aName <> '';
end;

function InventoryTryRoutineOwner(const aRoutineName: string; out aOwnerType: string): Boolean;
var
  lDotPos: Integer;
begin
  lDotPos := LastDelimiter('.', aRoutineName);
  Result := lDotPos > 0;
  if Result then
    aOwnerType := Copy(aRoutineName, 1, lDotPos - 1)
  else
    aOwnerType := '';
end;

function InventoryTokenCount(const aText, aToken: string): Integer;
var
  i: Integer;
  lEndPos: Integer;
  lStartPos: Integer;
begin
  Result := 0;
  i := 1;
  while i <= Length(aText) do
  begin
    if not InventoryIsIdentifierChar(aText[i]) then
    begin
      Inc(i);
      Continue;
    end;
    lStartPos := i;
    while (i <= Length(aText)) and InventoryIsIdentifierChar(aText[i]) do
      Inc(i);
    lEndPos := i - 1;
    if SameText(Copy(aText, lStartPos, lEndPos - lStartPos + 1), aToken) then
      Inc(Result);
  end;
end;

function InventoryEndTerminatedBlockOpenCount(const aText: string): Integer;
begin
  Result := InventoryTokenCount(aText, 'begin') + InventoryTokenCount(aText, 'case') +
    InventoryTokenCount(aText, 'try') + InventoryTokenCount(aText, 'asm');
end;

function InventoryFindRoutineEndLine(const aLines: TArray<string>; const aStartIndex: Integer):
  Integer;
var
  i: Integer;
  lDepth: Integer;
  lLine: string;
  lNestedEndLine: Integer;
  lStarted: Boolean;
begin
  Result := 0;
  lDepth := 0;
  lStarted := False;
  i := aStartIndex + 1;
  while i <= High(aLines) do
  begin
    lLine := LowerCase(InventoryCleanLine(aLines[i]));
    if lLine = '' then
    begin
      Inc(i);
      Continue;
    end;
    if not lStarted then
    begin
      if InventoryIsTopLevelLine(aLines[i]) and (InventoryIsRoutineStart(lLine) or
        SameText(lLine, 'implementation') or SameText(lLine, 'interface')) then
        Exit(0);
      if InventoryIsRoutineStart(lLine) then
      begin
        lNestedEndLine := InventoryFindRoutineEndLine(aLines, i);
        if lNestedEndLine > 0 then
        begin
          i := lNestedEndLine;
          Continue;
        end;
      end;
      if (InventoryTokenCount(lLine, 'begin') = 0) and (InventoryTokenCount(lLine, 'asm') = 0) then
      begin
        Inc(i);
        Continue;
      end;
      lStarted := True;
    end;
    Inc(lDepth, InventoryEndTerminatedBlockOpenCount(lLine));
    Dec(lDepth, InventoryTokenCount(lLine, 'end'));
    if lStarted and (lDepth <= 0) then
      Exit(i + 1);
    Inc(i);
  end;
end;

function InventoryCollectDeclarationText(const aLines: TArray<string>; const aStartLine: Integer;
  out aEndLine: Integer): string;
var
  i: Integer;
  j: Integer;
  lLine: string;
  lParenDepth: Integer;
begin
  Result := '';
  aEndLine := aStartLine;
  lParenDepth := 0;
  for i := aStartLine to High(aLines) do
  begin
    aEndLine := i;
    lLine := InventoryCleanLine(aLines[i]);
    if lLine <> '' then
    begin
      if Result <> '' then
        Result := Result + ' ';
      Result := Result + lLine;
      for j := 1 to Length(lLine) do
      begin
        if lLine[j] = '(' then
          Inc(lParenDepth)
        else if (lLine[j] = ')') and (lParenDepth > 0) then
          Dec(lParenDepth);
      end;
    end;
    if (Pos(';', lLine) > 0) and (lParenDepth = 0) then
      Exit;
  end;
end;

function InventoryCollectTypeStartText(const aLines: TArray<string>;
  const aStartLine: Integer; out aEndLine: Integer): string;
var
  i: Integer;
  lLine: string;
  lText: string;
begin
  Result := '';
  aEndLine := aStartLine;
  for i := aStartLine to High(aLines) do
  begin
    lLine := InventoryCleanLine(aLines[i]);
    if lLine <> '' then
    begin
      aEndLine := i;
      if Result <> '' then
        Result := Result + ' ';
      Result := Result + lLine;
      lText := LowerCase(Result);
      if (Pos(' class', lText) > 0) or (Pos(' record', lText) > 0) or
        (Pos(' interface', lText) > 0) or (Pos(';', lLine) > 0) then
        Exit;
    end;
  end;
end;

const
  // Text up to a closing "end" followed only by hint directives.
  cInventoryTrailingHintsPattern = '^(.*\bend)(\s+(deprecated(\s*''(?:[^'']|'''')*'')?|' +
    'platform|library|experimental))+\s*$';

type
  // DS-684: how a class, record or interface header continues after its keyword.
  TInventoryTypeStartShape = (
    itsOpensBody,     // members follow on later lines up to "end;"
    itsComplete,      // "class;", "class(TBase);", "class of TBase;", "class end;"
    itsInlineBody,    // "record X: Integer; end;" with the members on the header line
    itsBodyWithInlineFields, // "record X: Integer;" whose body continues on later lines
    itsUnrecognized); // anything else; the caller fails closed

// Consumes aWord when it is the next whole word of aText.
function InventoryTryConsumeWord(var aText: string; const aWord: string): Boolean;
begin
  Result := StartsText(aWord, aText) and ((Length(aText) = Length(aWord)) or
    (not InventoryIsIdentifierChar(aText[Length(aWord) + 1])));
  if Result then
    aText := Trim(Copy(aText, Length(aWord) + 1, MaxInt));
end;

// Returns aText without a leading optional word such as "packed" or "sealed".
function InventorySkipOptionalWord(const aText, aWord: string): string;
begin
  Result := aText;
  if not InventoryTryConsumeWord(Result, aWord) then
    Result := aText;
end;

// Consumes a leading bracketed list such as a heritage list or an interface GUID.
// Returns False when the list does not close in aText.
function InventoryTryConsumeBracketed(var aText: string; const aOpen, aClose: Char): Boolean;
var
  lClosePos: Integer;
begin
  if (aText = '') or (aText[1] <> aOpen) then
    Exit(True);
  lClosePos := Pos(aClose, aText);
  if lClosePos = 0 then
    Exit(False);
  aText := Trim(Copy(aText, lClosePos + 1, MaxInt));
  Result := True;
end;

// DS-684: a type header may complete on its own line, as in "class(TBase) end;",
// "class;", "class of TBase;" or "record X: Integer; end;". Treating such a header as
// an open body attributed the following unit declarations to that type, so we classify
// the text after the keyword first. aInlineBody receives the members of a one-line body.
function InventoryClassifyTypeStart(const aTypeText: string; out aInlineBody: string):
  TInventoryTypeStartShape;
var
  lBodyLength: Integer;
  lCanForward: Boolean;
  lEndsWithSemicolon: Boolean;
  lEqualsPos: Integer;
  lHintMatch: TMatch;
  lIsInterface: Boolean;
  lText: string;
begin
  aInlineBody := '';
  Result := itsUnrecognized;
  lEqualsPos := Pos('=', aTypeText);
  if lEqualsPos = 0 then
    Exit;
  lText := Trim(Copy(aTypeText, lEqualsPos + 1, MaxInt));
  lText := InventorySkipOptionalWord(lText, 'packed');
  lIsInterface := False;
  if InventoryTryConsumeWord(lText, 'class') then
  begin
    if InventoryTryConsumeWord(lText, 'of') then
    begin
      // A metaclass has no body of its own.
      if EndsText(';', lText) and
        IsValidIdent(Trim(Copy(lText, 1, Length(lText) - 1)), True) then
        Result := itsComplete;
      Exit;
    end;
    lText := InventorySkipOptionalWord(InventorySkipOptionalWord(lText, 'abstract'), 'sealed');
    lCanForward := True;
  end else if InventoryTryConsumeWord(lText, 'record') then
    lCanForward := False
  else if InventoryTryConsumeWord(lText, 'interface') then
  begin
    lCanForward := True;
    lIsInterface := True;
  end else
    Exit;

  // Helpers keep their established multi-line handling; a one-line helper fails closed.
  if InventoryTryConsumeWord(lText, 'helper') then
  begin
    if not (EndsText(' end;', lText) or EndsText(' end', lText)) then
      Result := itsOpensBody;
    Exit;
  end;
  // A heritage list that continues on the next line still opens a body.
  if not InventoryTryConsumeBracketed(lText, '(', ')') then
    Exit(itsOpensBody);
  if lIsInterface and (not InventoryTryConsumeBracketed(lText, '[', ']')) then
    Exit;

  if lText = '' then
    Exit(itsOpensBody);
  if lText = ';' then
  begin
    // "class;" and "interface;" are forward declarations; "class(TBase);" is a complete
    // class without members of its own.
    if lCanForward then
      Result := itsComplete;
    Exit;
  end;
  lEndsWithSemicolon := EndsText(';', lText);
  if lEndsWithSemicolon then
    lText := TrimRight(Copy(lText, 1, Length(lText) - 1));
  // Hint directives may follow the closing "end", as in "end deprecated 'Use X';".
  lHintMatch := TRegEx.Match(lText, cInventoryTrailingHintsPattern, [roIgnoreCase]);
  if lHintMatch.Success then
    lText := lHintMatch.Groups[1].Value;
  lBodyLength := Length(lText) - Length('end');
  if (not EndsText('end', lText)) or
    ((lBodyLength > 0) and InventoryIsIdentifierChar(lText[lBodyLength])) then
  begin
    // Members start on the header line and the body continues to a later "end;".
    // Any other "end" on the header line closes the type there, so an unknown
    // trailer stays unsupported instead of opening a body over the next types.
    if lEndsWithSemicolon and (not TRegEx.IsMatch(lText, '\bend\b', [roIgnoreCase])) then
    begin
      aInlineBody := lText;
      Result := itsBodyWithInlineFields;
    end;
    Exit;
  end;
  aInlineBody := Trim(Copy(lText, 1, lBodyLength));
  if aInlineBody = '' then
    Result := itsComplete
  else
    Result := itsInlineBody;
end;

// Splits a one-line body into plain field declarations. Returns False when any part is
// not a plain field (visibility, routine, property, nested record, variant part), so the
// caller marks the type unsupported instead of guessing its members.
function InventoryTryParseInlineFields(const aInlineBody: string;
  out aFieldNames: TArray<TArray<string>>; out aFieldTypes: TArray<string>): Boolean;
var
  lDeclaration: string;
  lName: string;
  lNames: TArray<string>;
  lRawDeclaration: string;
  lTypeName: string;
begin
  aFieldNames := nil;
  aFieldTypes := nil;
  for lRawDeclaration in aInlineBody.Split([';']) do
  begin
    lDeclaration := Trim(lRawDeclaration);
    if lDeclaration = '' then
      Continue;
    if StartsText('case ', lDeclaration) or
      (not InventoryTryDeclaration(lDeclaration + ';', lNames, lTypeName)) then
      Exit(False);
    for lName in lNames do
      if not IsValidIdent(Trim(lName)) then
        Exit(False);
    if (Pos('(', lTypeName) > 0) or (Pos('=', lTypeName) > 0) or (Pos(':', lTypeName) > 0) or
      (InventorySkipOptionalWord(lTypeName, 'record') <> lTypeName) or
      (InventorySkipOptionalWord(lTypeName, 'packed') <> lTypeName) or
      (InventorySkipOptionalWord(lTypeName, 'class') <> lTypeName) then
      Exit(False);
    SetLength(aFieldNames, Length(aFieldNames) + 1);
    aFieldNames[High(aFieldNames)] := lNames;
    SetLength(aFieldTypes, Length(aFieldTypes) + 1);
    aFieldTypes[High(aFieldTypes)] := lTypeName;
  end;
  Result := Length(aFieldNames) > 0;
end;

function InventoryUnsupportedReasonForTypeStart(const aTypeName, aPendingReason: string;
  const aConditionalDepth: Integer): string;
begin
  if aPendingReason <> '' then
    Exit(aPendingReason);
  if aConditionalDepth > 0 then
    Exit('unsupported-source-model-conditional-region');
  if Pos('<', aTypeName) > 0 then
    Exit('unsupported-source-model-generic-declaration');
  Result := '';
end;

function InventoryFindTypeEndLine(const aLines: TArray<string>; const aStartIndex: Integer):
  Integer;
var
  i: Integer;
  lLine: string;
begin
  Result := aStartIndex + 1;
  for i := aStartIndex + 1 to High(aLines) do
  begin
    lLine := LowerCase(InventoryCleanLine(aLines[i]));
    if SameText(lLine, 'end;') or SameText(lLine, 'end') or StartsText('end ', lLine) then
      Exit(i + 1);
  end;
end;

function InventoryFindIdentifierSource(const aLines: TArray<string>; const aEndIndex: Integer;
  const aName: string; const aFromLine, aFromColumn: Integer; out aLineIndex,
  aColumn: Integer): Boolean;
var
  i: Integer;
  lEndIndex: Integer;
  lFromColumn: Integer;
begin
  Result := False;
  aLineIndex := -1;
  aColumn := 0;
  lEndIndex := aEndIndex;
  if lEndIndex > High(aLines) then
    lEndIndex := High(aLines);
  lFromColumn := aFromColumn;
  for i := aFromLine to lEndIndex do
  begin
    if i >= 0 then
    begin
      aColumn := InventoryFindIdentifierColumn(aLines[i], Trim(aName), lFromColumn);
      if aColumn > 0 then
      begin
        aLineIndex := i;
        Exit(True);
      end;
    end;
    lFromColumn := 1;
  end;
end;

procedure AddDakInventorySymbol(const aSymbols: TList<TDelphiSemanticInventorySymbol>;
  const aName, aTypeName, aOwnerType, aRoutineName, aUnitName, aFileName: string;
  const aLineNumber: Integer; const aLineText, aKind: string;
  const aModifier: string = ''; const aColumn: Integer = 0);
var
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  lSymbol := Default(TDelphiSemanticInventorySymbol);
  lSymbol.Name := aName;
  lSymbol.SymbolClass := aKind;
  lSymbol.Kind := aKind;
  lSymbol.TypeName := aTypeName;
  lSymbol.OwnerName := aOwnerType;
  lSymbol.OwnerType := aOwnerType;
  lSymbol.RoutineName := aRoutineName;
  lSymbol.Modifier := aModifier;
  lSymbol.UnitName := aUnitName;
  lSymbol.FileName := aFileName;
  lSymbol.Line := aLineNumber;
  lSymbol.EndLine := aLineNumber;
  if aColumn > 0 then
    lSymbol.Column := aColumn
  else
    lSymbol.Column := InventoryFindColumn(aLineText, aName);
  lSymbol.EndColumn := lSymbol.Column + Length(aName);
  AddInventorySymbol(aSymbols, lSymbol);
end;

procedure AddDakInventoryTypeSymbol(const aSymbols: TList<TDelphiSemanticInventorySymbol>;
  const aName, aTypeName, aTypeCategory, aUnitName, aFileName: string; const aLineNumber,
  aEndLine: Integer; const aLineText: string);
var
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  lSymbol := Default(TDelphiSemanticInventorySymbol);
  lSymbol.Name := aName;
  lSymbol.SymbolClass := 'type-member';
  lSymbol.Kind := 'type-member';
  lSymbol.TypeName := aTypeName;
  lSymbol.TypeCategory := aTypeCategory;
  lSymbol.UnitName := aUnitName;
  lSymbol.FileName := aFileName;
  lSymbol.Line := aLineNumber;
  lSymbol.EndLine := aEndLine;
  lSymbol.Column := InventoryFindColumn(aLineText, aName);
  lSymbol.EndColumn := lSymbol.Column + Length(aName);
  AddInventorySymbol(aSymbols, lSymbol);
end;

procedure AddDakInventorySymbolsFromSource(const aSymbols: TList<TDelphiSemanticInventorySymbol>;
  const aNames: TArray<string>; const aTypeName, aOwnerType, aRoutineName, aUnitName,
  aFileName: string; const aLines: TArray<string>; const aStartIndex, aEndIndex: Integer;
  var aCursorLine, aCursorColumn: Integer; const aKind: string; const aModifier: string = '');
var
  lColumn: Integer;
  lLineIndex: Integer;
  lLineNumber: Integer;
  lLineText: string;
  lName: string;
begin
  // The cursor walks the declaration in source order, so each name is found
  // after the previous one instead of at its first textual occurrence.
  for lName in aNames do
  begin
    if InventoryFindIdentifierSource(aLines, aEndIndex, lName, aCursorLine, aCursorColumn,
      lLineIndex, lColumn) then
    begin
      lLineNumber := lLineIndex + 1;
      lLineText := aLines[lLineIndex];
      aCursorLine := lLineIndex;
      aCursorColumn := lColumn + Length(Trim(lName));
    end else
    begin
      lColumn := 0;
      lLineNumber := aStartIndex + 1;
      if (aStartIndex >= 0) and (aStartIndex <= High(aLines)) then
        lLineText := aLines[aStartIndex]
      else
        lLineText := lName;
    end;
    AddDakInventorySymbol(aSymbols, lName, aTypeName, aOwnerType, aRoutineName, aUnitName,
      aFileName, lLineNumber, lLineText, aKind, aModifier, lColumn);
  end;
end;

procedure MarkDakTypeUnsupported(const aSymbols: TList<TDelphiSemanticInventorySymbol>;
  const aTypeName, aReason: string);
var
  i: Integer;
  lSymbol: TDelphiSemanticInventorySymbol;
  lTypeName: string;
begin
  if aReason = '' then
    Exit;
  lTypeName := InventorySimpleTypeName(aTypeName);
  for i := 0 to Pred(aSymbols.Count) do
  begin
    lSymbol := aSymbols[i];
    if SameText(lSymbol.SymbolClass, 'type-member') and SameText(lSymbol.Name, lTypeName) then
    begin
      if lSymbol.UnsupportedReason = '' then
      begin
        lSymbol.UnsupportedReason := aReason;
        aSymbols[i] := lSymbol;
      end;
      Exit;
    end;
  end;
end;

procedure AddDakTypedSymbols(const aSymbols: TList<TDelphiSemanticInventorySymbol>;
  const aNames: TArray<string>; const aTypeName, aOwnerType, aRoutineName, aUnitName,
  aFileName: string; const aLineNumber: Integer; const aLineText, aKind: string);
var
  lName: string;
begin
  for lName in aNames do
    AddDakInventorySymbol(aSymbols, lName, aTypeName, aOwnerType, aRoutineName, aUnitName,
      aFileName, aLineNumber, aLineText, aKind);
end;

function InventoryTryAnonymousRecordLocalStart(const aLine: string; out aName,
  aTypeCategory: string): Boolean;
var
  lColonPos: Integer;
  lRest: string;
begin
  Result := False;
  aName := '';
  aTypeCategory := '';
  lColonPos := Pos(':', aLine);
  if lColonPos = 0 then
    Exit;

  aName := Trim(Copy(aLine, 1, lColonPos - 1));
  lRest := LowerCase(Trim(Copy(aLine, lColonPos + 1, MaxInt)));
  if StartsText('packed record', lRest) or StartsText('record', lRest) then
    aTypeCategory := 'record'
  else
    Exit;

  Result := aName <> '';
end;

procedure AddDakInventoryRecordFieldsFromLine(const aSymbols: TList<TDelphiSemanticInventorySymbol>;
  const aLines: TArray<string>; const aLineIndex: Integer; const aOwnerType, aUnitName,
  aFileName: string);
var
  lDeclaration: string;
  lDeclarationParts: TArray<string>;
  lLine: string;
  lMemberName: string;
  lNames: TArray<string>;
  lRawDeclaration: string;
  lTypeName: string;
begin
  lLine := InventoryVariantFieldDeclarationLine(InventoryCleanLine(aLines[aLineIndex]));
  if lLine = '' then
    Exit;
  if InventoryTryVariantTagDeclaration(lLine, lMemberName, lTypeName) then
  begin
    AddDakInventorySymbol(aSymbols, lMemberName, lTypeName, aOwnerType, '', aUnitName,
      aFileName, aLineIndex + 1, aLines[aLineIndex], 'field');
    Exit;
  end;

  lDeclarationParts := lLine.Split([';']);
  for lRawDeclaration in lDeclarationParts do
  begin
    lDeclaration := Trim(lRawDeclaration);
    if lDeclaration = '' then
      Continue;
    if InventoryTryDeclaration(lDeclaration + ';', lNames, lTypeName) then
      AddDakTypedSymbols(aSymbols, lNames, lTypeName, aOwnerType, '', aUnitName, aFileName,
        aLineIndex + 1, aLines[aLineIndex], 'field');
  end;
end;

procedure ParseDakInventoryParams(const aSymbols: TList<TDelphiSemanticInventorySymbol>;
  const aLines: TArray<string>; const aStartIndex: Integer; const aSignature, aRoutineName,
  aUnitName, aFileName: string);
var
  i: Integer;
  lClosePos: Integer;
  lCursorColumn: Integer;
  lCursorLine: Integer;
  lEndIndex: Integer;
  lModifier: string;
  lNames: TArray<string>;
  lOpenPos: Integer;
  lPart: string;
  lParts: TArray<string>;
  lText: string;
  lTypeName: string;
begin
  lOpenPos := Pos('(', aSignature);
  lClosePos := LastDelimiter(')', aSignature);
  if (lOpenPos = 0) or (lClosePos <= lOpenPos) then
    Exit;
  lEndIndex := aStartIndex + 20;
  // Parameter names start after the list's "(" so routine name text such as
  // "SetValue" cannot supply a parameter position.
  lCursorLine := -1;
  lCursorColumn := 0;
  for i := aStartIndex to lEndIndex do
    if (i >= 0) and (i <= High(aLines)) and (Pos('(', aLines[i]) > 0) then
    begin
      lCursorLine := i;
      lCursorColumn := Pos('(', aLines[i]) + 1;
      Break;
    end;
  if lCursorLine < 0 then
    Exit;

  lParts := Copy(aSignature, lOpenPos + 1, lClosePos - lOpenPos - 1).Split([';']);
  for lPart in lParts do
  begin
    lText := Trim(lPart);
    lModifier := '';
    if StartsText('const ', lText) then
    begin
      Delete(lText, 1, Length('const '));
      lModifier := 'const';
    end else if StartsText('var ', lText) then
    begin
      Delete(lText, 1, Length('var '));
      lModifier := 'var';
    end else if StartsText('out ', lText) then
    begin
      Delete(lText, 1, Length('out '));
      lModifier := 'out';
    end;

    if InventoryTryDeclaration(lText, lNames, lTypeName) then
      AddDakInventorySymbolsFromSource(aSymbols, lNames, lTypeName, '', aRoutineName, aUnitName,
        aFileName, aLines, aStartIndex, lEndIndex, lCursorLine, lCursorColumn, 'parameter',
        lModifier)
    else if (lModifier <> '') and (Pos(':', lText) = 0) and (lText <> '') then
    begin
      lNames := lText.Split([',']);
      AddDakInventorySymbolsFromSource(aSymbols, lNames, '', '', aRoutineName, aUnitName,
        aFileName, aLines, aStartIndex, lEndIndex, lCursorLine, lCursorColumn, 'parameter',
        lModifier);
    end;
  end;
end;

// DS-684: adds the plain fields of a one-line type body. The cursor starts at the body
// so a field named like its type or heritage is located at its own source column.
procedure AddDakInventoryInlineFields(const aSymbols: TList<TDelphiSemanticInventorySymbol>;
  const aLines: TArray<string>; const aStartIndex, aEndIndex: Integer;
  const aFieldNames: TArray<TArray<string>>; const aFieldTypes: TArray<string>;
  const aInlineBody, aOwnerType, aUnitName, aFileName: string);
var
  i: Integer;
  lCursorColumn: Integer;
  lCursorLine: Integer;
begin
  lCursorLine := aEndIndex;
  lCursorColumn := Pos(aInlineBody, aLines[aEndIndex]);
  if lCursorColumn = 0 then
  begin
    lCursorLine := aStartIndex;
    lCursorColumn := Pos('=', aLines[aStartIndex]) + 1;
  end;
  for i := 0 to High(aFieldNames) do
    AddDakInventorySymbolsFromSource(aSymbols, aFieldNames[i], aFieldTypes[i], aOwnerType, '',
      aUnitName, aFileName, aLines, aStartIndex, aEndIndex, lCursorLine, lCursorColumn,
      'field');
end;

procedure ParseDakInventoryLocals(const aSymbols: TList<TDelphiSemanticInventorySymbol>;
  const aLines: TArray<string>; const aStartLine: Integer; const aRoutineName, aUnitName,
  aFileName: string);
var
  i: Integer;
  j: Integer;
  lAnonymousEndLine: Integer;
  lConstName: string;
  lCurrentType: string;
  lCursorColumn: Integer;
  lCursorLine: Integer;
  lDeclaration: string;
  lDeclarationLine: Integer;
  lEnumMatch: TMatch;
  lEnumNames: TArray<string>;
  lInType: Boolean;
  lInConst: Boolean;
  lInVar: Boolean;
  lFieldNames: TArray<TArray<string>>;
  lFieldTypes: TArray<string>;
  lInlineBody: string;
  lLine: string;
  lNames: TArray<string>;
  lRawTypeName: string;
  lSkipUntilLine: Integer;
  lSymbol: TDelphiSemanticInventorySymbol;
  lTypeCategory: string;
  lTypeIndex: Integer;
  lTypeOpensBody: Boolean;
  lTypeShape: TInventoryTypeStartShape;
  lTypeText: string;
  lTypeTextEndLine: Integer;
  lTypeName: string;
begin
  lCurrentType := '';
  lDeclaration := '';
  lDeclarationLine := 0;
  lInConst := False;
  lInType := False;
  lInVar := False;
  lSkipUntilLine := 0;
  for i := aStartLine to High(aLines) do
  begin
    if i < lSkipUntilLine then
      Continue;
    lLine := InventoryCleanLine(aLines[i]);
    if SameText(lLine, 'const') then
    begin
      lCurrentType := '';
      lInConst := True;
      lInType := False;
      lInVar := False;
      lDeclaration := '';
      Continue;
    end;
    if SameText(lLine, 'type') then
    begin
      lCurrentType := '';
      lInConst := False;
      lInType := True;
      lInVar := False;
      lDeclaration := '';
      Continue;
    end;
    if SameText(lLine, 'var') then
    begin
      lCurrentType := '';
      lInConst := False;
      lInType := False;
      lInVar := True;
      lDeclaration := '';
      Continue;
    end;
    if SameText(lLine, 'begin') then
      Exit;
    if InventoryIsRoutineStart(lLine) then
    begin
      lSkipUntilLine := InventoryFindRoutineEndLine(aLines, i);
      if lSkipUntilLine = 0 then
        Exit;
      Continue;
    end;
    if StartsText('const ', LowerCase(lLine)) then
    begin
      lInConst := True;
      lInVar := False;
      lLine := Trim(Copy(lLine, Length('const ') + 1, MaxInt));
    end;
    if lInType and (lLine <> '') then
    begin
      if (lCurrentType <> '') and (SameText(lLine, 'end;') or SameText(lLine, 'end')) then
      begin
        lCurrentType := '';
        Continue;
      end;

      if lCurrentType = '' then
      begin
        lTypeText := InventoryCollectTypeStartText(aLines, i, lTypeTextEndLine);
        if InventoryTryTypeStart(lTypeText, lRawTypeName, lTypeCategory) then
        begin
          lCurrentType := InventorySimpleTypeName(lRawTypeName);
          lTypeShape := InventoryClassifyTypeStart(lTypeText, lInlineBody);
          lTypeIndex := aSymbols.Count;
          lTypeOpensBody := (lTypeShape in [itsOpensBody, itsBodyWithInlineFields]) or
            ((lTypeShape = itsUnrecognized) and (not EndsText(';', lTypeText)));
          if lTypeOpensBody then
            AddDakInventoryTypeSymbol(aSymbols, lCurrentType, '', lTypeCategory, aUnitName,
              aFileName, i + 1, InventoryFindTypeEndLine(aLines, i), aLines[i])
          else
            AddDakInventoryTypeSymbol(aSymbols, lCurrentType, '', lTypeCategory, aUnitName,
              aFileName, i + 1, lTypeTextEndLine + 1, aLines[i]);
          if InventoryTryEnumValues(lTypeText, lEnumNames) then
            AddDakTypedSymbols(aSymbols, lEnumNames, lCurrentType, '', aRoutineName, aUnitName,
              aFileName, i + 1, aLines[i], 'constant');
          // DS-684: a one-line declaration has no body to collect; an unrecognized header
          // or inline body fails closed as unsupported.
          if (lTypeShape = itsUnrecognized) or
            ((lTypeShape in [itsInlineBody, itsBodyWithInlineFields]) and
            (not InventoryTryParseInlineFields(lInlineBody, lFieldNames, lFieldTypes))) then
          begin
            if lTypeIndex < aSymbols.Count then
            begin
              lSymbol := aSymbols[lTypeIndex];
              lSymbol.UnsupportedReason := 'unsupported-source-model-type-header';
              aSymbols[lTypeIndex] := lSymbol;
            end;
          end else if lTypeShape in [itsInlineBody, itsBodyWithInlineFields] then
            AddDakInventoryInlineFields(aSymbols, aLines, i, lTypeTextEndLine, lFieldNames,
              lFieldTypes, lInlineBody, lCurrentType, aUnitName, aFileName);
          if not lTypeOpensBody then
          begin
            lCurrentType := '';
            lSkipUntilLine := lTypeTextEndLine + 1;
          end;
        end else if InventoryTryTypeAlias(lTypeText, lCurrentType, lTypeName) then
        begin
          AddDakInventorySymbol(aSymbols, lCurrentType, lTypeName, '', '', aUnitName,
            aFileName, i + 1, aLines[i], 'type-member');
          if InventoryTryEnumValues(lTypeText, lEnumNames) then
            AddDakTypedSymbols(aSymbols, lEnumNames, lCurrentType, '', aRoutineName, aUnitName,
              aFileName, i + 1, aLines[i], 'constant');
        end;
        Continue;
      end;

      AddDakInventoryRecordFieldsFromLine(aSymbols, aLines, i, lCurrentType, aUnitName,
        aFileName);
      Continue;
    end;
    if lInConst and (lLine <> '') and InventoryTryConstDeclaration(lLine, lConstName, lTypeName) then
    begin
      AddDakInventorySymbol(aSymbols, lConstName, lTypeName, '', aRoutineName, aUnitName,
        aFileName, i + 1, aLines[i], 'constant');
      Continue;
    end;
    if lInVar and (lLine <> '') then
    begin
      if InventoryTryAnonymousRecordLocalStart(lLine, lConstName, lTypeCategory) then
      begin
        lTypeName := aRoutineName + '.' + lConstName;
        lAnonymousEndLine := InventoryFindTypeEndLine(aLines, i);
        AddDakInventoryTypeSymbol(aSymbols, lTypeName, '', lTypeCategory, aUnitName,
          aFileName, i + 1, lAnonymousEndLine, aLines[i]);
        AddDakInventorySymbol(aSymbols, lConstName, lTypeName, '', aRoutineName, aUnitName,
          aFileName, i + 1, aLines[i], 'local');
        for j := i + 1 to lAnonymousEndLine - 2 do
          AddDakInventoryRecordFieldsFromLine(aSymbols, aLines, j, lTypeName, aUnitName,
            aFileName);
        lSkipUntilLine := lAnonymousEndLine;
        lDeclaration := '';
        lDeclarationLine := 0;
        Continue;
      end;
      if lDeclaration = '' then
        lDeclarationLine := i + 1;
      if lDeclaration <> '' then
        lDeclaration := lDeclaration + ' ';
      lDeclaration := lDeclaration + lLine;
      if Pos(';', lLine) > 0 then
      begin
        if InventoryTryDeclaration(lDeclaration, lNames, lTypeName) then
        begin
          lCursorLine := lDeclarationLine - 1;
          lCursorColumn := 1;
          AddDakInventorySymbolsFromSource(aSymbols, lNames, lTypeName, '', aRoutineName,
            aUnitName, aFileName, aLines, lDeclarationLine - 1, i, lCursorLine, lCursorColumn,
            'local');
          lEnumMatch := TRegEx.Match(lDeclaration, ':\s*\(([^)]*)\)');
          if lEnumMatch.Success and
            InventoryTryEnumValues('TAnonymousEnum = (' + lEnumMatch.Groups[1].Value + ')', lEnumNames) then
            AddDakTypedSymbols(aSymbols, lEnumNames, lTypeName, '', aRoutineName, aUnitName,
              aFileName, lDeclarationLine, aLines[lDeclarationLine - 1], 'constant');
        end;
        lDeclaration := '';
        lDeclarationLine := 0;
      end;
    end;
  end;
end;

procedure ParseDakInventoryTypeMembers(const aSymbols: TList<TDelphiSemanticInventorySymbol>;
  const aLines: TArray<string>; const aUnitName, aFileName: string);
var
  i: Integer;
  j: Integer;
  lAnonymousEndLine: Integer;
  lCollectedEndLine: Integer;
  lConditionalDepth: Integer;
  lConstName: string;
  lCurrentType: string;
  lCurrentTypeUnsupportedReason: string;
  lDeclaration: string;
  lDeclarationAdded: Boolean;
  lDeclarationParts: TArray<string>;
  lEnumMatch: TMatch;
  lEnumNames: TArray<string>;
  lFieldNames: TArray<TArray<string>>;
  lFieldTypes: TArray<string>;
  lInClassVar: Boolean;
  lInConst: Boolean;
  lInlineBody: string;
  lInlineFieldsParsed: Boolean;
  lInTypeSection: Boolean;
  lLine: string;
  lLower: string;
  lMemberName: string;
  lNames: TArray<string>;
  lPendingUnsupportedReason: string;
  lPropertyIndexed: Boolean;
  lPropertyIndexParameterCount: Integer;
  lPropertyIsDefault: Boolean;
  lPropertyType: string;
  lRawDeclaration: string;
  lRawLine: string;
  lRawTypeName: string;
  lRelatedTypeName: string;
  lSkipUntilLine: Integer;
  lSymbol: TDelphiSemanticInventorySymbol;
  lTypeCategory: string;
  lTypeIsHelper: Boolean;
  lTypeName: string;
  lTypeOpensBody: Boolean;
  lTypeShape: TInventoryTypeStartShape;
  lTypeText: string;
  lTypeTextEndLine: Integer;
begin
  lConditionalDepth := 0;
  lCurrentType := '';
  lCurrentTypeUnsupportedReason := '';
  lInClassVar := False;
  lInConst := False;
  lInTypeSection := False;
  lPendingUnsupportedReason := '';
  lSkipUntilLine := 0;
  for i := 0 to High(aLines) do
  begin
    if i < lSkipUntilLine then
      Continue;
    lRawLine := aLines[i];
    lLine := InventoryCleanLine(lRawLine);
    lLower := LowerCase(lLine);
    if lLine = '' then
      Continue;

    if InventoryIsConditionalDirectiveLine(lLine) then
    begin
      if lCurrentType <> '' then
      begin
        lCurrentTypeUnsupportedReason := 'unsupported-source-model-conditional-region';
        MarkDakTypeUnsupported(aSymbols, lCurrentType, lCurrentTypeUnsupportedReason);
      end else if lInTypeSection and (not InventoryIsConditionalEndDirective(lLine)) then
        lPendingUnsupportedReason := 'unsupported-source-model-conditional-region';

      if InventoryIsConditionalStartDirective(lLine) then
        Inc(lConditionalDepth)
      else if InventoryIsConditionalEndDirective(lLine) and (lConditionalDepth > 0) then
        Dec(lConditionalDepth);
      Continue;
    end;

    if InventoryIsAttributeLine(lLine) then
    begin
      if lCurrentType <> '' then
      begin
        lCurrentTypeUnsupportedReason := 'unsupported-source-model-attribute';
        MarkDakTypeUnsupported(aSymbols, lCurrentType, lCurrentTypeUnsupportedReason);
      end else if lInTypeSection then
        lPendingUnsupportedReason := 'unsupported-source-model-attribute';
      Continue;
    end;

    if (lCurrentType = '') and SameText(lLine, 'type') then
    begin
      lConditionalDepth := 0;
      lInTypeSection := True;
      Continue;
    end;
    if SameText(lLine, 'implementation') or ((lCurrentType = '') and
      (SameText(lLine, 'const') or SameText(lLine, 'var') or SameText(lLine, 'threadvar') or
      InventoryIsRoutineStart(lLine))) then
    begin
      lCurrentType := '';
      lCurrentTypeUnsupportedReason := '';
      lInTypeSection := False;
      lInClassVar := False;
      lInConst := False;
      lPendingUnsupportedReason := '';
      Continue;
    end;

    if lCurrentType = '' then
    begin
      if not lInTypeSection then
        Continue;
      lTypeText := InventoryCollectTypeStartText(aLines, i, lTypeTextEndLine);
      if InventoryTryTypeStart(lTypeText, lRawTypeName, lTypeCategory) then
      begin
        lCurrentType := InventorySimpleTypeName(lRawTypeName);
        lCurrentTypeUnsupportedReason := InventoryUnsupportedReasonForTypeStart(lRawTypeName,
          lPendingUnsupportedReason, lConditionalDepth);
        // DS-684: a one-line declaration has no body to collect; an unrecognized header
        // or inline body fails closed as unsupported.
        lTypeShape := InventoryClassifyTypeStart(lTypeText, lInlineBody);
        lTypeOpensBody := (lTypeShape in [itsOpensBody, itsBodyWithInlineFields]) or
          ((lTypeShape = itsUnrecognized) and (not EndsText(';', lTypeText)));
        lInlineFieldsParsed := (lTypeShape in [itsInlineBody, itsBodyWithInlineFields]) and
          InventoryTryParseInlineFields(lInlineBody, lFieldNames, lFieldTypes);
        if (lCurrentTypeUnsupportedReason = '') and ((lTypeShape = itsUnrecognized) or
          ((lTypeShape in [itsInlineBody, itsBodyWithInlineFields]) and
          (not lInlineFieldsParsed))) then
          lCurrentTypeUnsupportedReason := 'unsupported-source-model-type-header';
        lInClassVar := False;
        lInConst := False;
        InventoryTryTypeRelation(lTypeText, lRelatedTypeName, lTypeIsHelper);
        lSymbol := Default(TDelphiSemanticInventorySymbol);
        lSymbol.Name := lCurrentType;
        lSymbol.SymbolClass := 'type-member';
        lSymbol.Kind := 'type-member';
        lSymbol.RelatedTypeName := lRelatedTypeName;
        lSymbol.IsHelper := lTypeIsHelper;
        lSymbol.TypeCategory := lTypeCategory;
        lSymbol.UnitName := aUnitName;
        lSymbol.FileName := aFileName;
        lSymbol.Line := i + 1;
        if lTypeOpensBody then
          lSymbol.EndLine := InventoryFindTypeEndLine(aLines, i)
        else
          lSymbol.EndLine := lTypeTextEndLine + 1;
        lSymbol.Column := InventoryFindColumn(aLines[i], lCurrentType);
        lSymbol.EndColumn := lSymbol.Column + Length(lCurrentType);
        lSymbol.UnsupportedReason := lCurrentTypeUnsupportedReason;
        AddInventorySymbol(aSymbols, lSymbol);
        if InventoryTryEnumValues(lTypeText, lEnumNames) then
          AddDakTypedSymbols(aSymbols, lEnumNames, lCurrentType, '', '', aUnitName, aFileName,
            i + 1, aLines[i], 'constant');
        lPendingUnsupportedReason := '';
        if lInlineFieldsParsed and (lCurrentTypeUnsupportedReason = '') then
          AddDakInventoryInlineFields(aSymbols, aLines, i, lTypeTextEndLine, lFieldNames,
            lFieldTypes, lInlineBody, lCurrentType, aUnitName, aFileName);
        if not lTypeOpensBody then
        begin
          lCurrentType := '';
          lCurrentTypeUnsupportedReason := '';
          lSkipUntilLine := lTypeTextEndLine + 1;
        end;
      end else if InventoryTryTypeAlias(lTypeText, lMemberName, lTypeName) then
      begin
        AddDakInventorySymbol(aSymbols, lMemberName, lTypeName, '', '', aUnitName, aFileName,
          i + 1, aLines[i], 'type-member');
        lSymbol := aSymbols[Pred(aSymbols.Count)];
        lSymbol.RelatedTypeName := InventorySimpleTypeName(lTypeName);
        aSymbols[Pred(aSymbols.Count)] := lSymbol;
        if InventoryTryEnumValues(lTypeText, lEnumNames) then
          AddDakTypedSymbols(aSymbols, lEnumNames, lMemberName, '', '', aUnitName, aFileName,
            i + 1, aLines[i], 'constant');
        lPendingUnsupportedReason := '';
      end;
      Continue;
    end;

    if SameText(lLine, 'end;') or SameText(lLine, 'end') then
    begin
      lCurrentType := '';
      lCurrentTypeUnsupportedReason := '';
      Continue;
    end;
    if InventoryIsVisibilityLine(lLine) then
      Continue;
    if SameText(lLine, 'type') then
    begin
      lCurrentTypeUnsupportedReason := 'unsupported-source-model-nested-type';
      MarkDakTypeUnsupported(aSymbols, lCurrentType, lCurrentTypeUnsupportedReason);
      Continue;
    end;
    if InventoryIsMultilineDeclarationStart(lLine) then
    begin
      lLine := InventoryCollectDeclarationText(aLines, i, lCollectedEndLine);
      lSkipUntilLine := lCollectedEndLine + 1;
    end;
    if lCurrentTypeUnsupportedReason <> '' then
      Continue;
    if InventoryTryAnonymousRecordLocalStart(lLine, lMemberName, lTypeCategory) then
    begin
      lTypeName := lCurrentType + '.' + lMemberName;
      lAnonymousEndLine := InventoryFindTypeEndLine(aLines, i);
      AddDakInventoryTypeSymbol(aSymbols, lTypeName, '', lTypeCategory, aUnitName,
        aFileName, i + 1, lAnonymousEndLine, aLines[i]);
      AddDakInventorySymbol(aSymbols, lMemberName, lTypeName, lCurrentType, '', aUnitName,
        aFileName, i + 1, aLines[i], 'field');
      for j := i + 1 to lAnonymousEndLine - 2 do
        AddDakInventoryRecordFieldsFromLine(aSymbols, aLines, j, lTypeName, aUnitName,
          aFileName);
      lSkipUntilLine := lAnonymousEndLine;
      Continue;
    end;
    lLine := InventoryVariantFieldDeclarationLine(lLine);
    lLower := LowerCase(lLine);
    if InventoryTryVariantTagDeclaration(lLine, lMemberName, lTypeName) then
    begin
      AddDakInventorySymbol(aSymbols, lMemberName, lTypeName, lCurrentType, '', aUnitName,
        aFileName, i + 1, aLines[i], 'field');
      Continue;
    end;
    if StartsText('class var', lLower) then
    begin
      lInClassVar := True;
      lLine := Trim(Copy(lLine, Length('class var') + 1, MaxInt));
      if lLine = '' then
        Continue;
    end;
    if SameText(lLine, 'const') then
    begin
      lInConst := True;
      lInClassVar := False;
      Continue;
    end;
    if StartsText('const ', lLower) then
    begin
      lInConst := True;
      lLine := Trim(Copy(lLine, Length('const ') + 1, MaxInt));
    end;

    if lInConst and InventoryTryConstDeclaration(lLine, lConstName, lTypeName) then
    begin
      // DS-646: every constant of "const CLo = 1; CHi = 5;" is a member; a missed one would
      // let an outer same-name declaration capture it after the with is removed.
      for lDeclaration in InventorySplitTopLevelDeclarations(lLine) do
        if InventoryTryConstDeclaration(lDeclaration, lConstName, lTypeName) then
          AddDakInventorySymbol(aSymbols, lConstName, lTypeName, lCurrentType, '', aUnitName,
            aFileName, i + 1, aLines[i], 'constant');
      Continue;
    end;

    // DS-646: a class property is a with-member like an instance property.
    if StartsText('class property ', lLower) then
      lLine := Trim(Copy(lLine, Length('class ') + 1, MaxInt));
    if InventoryTryPropertyDeclaration(lLine, lMemberName, lPropertyType, lPropertyIsDefault,
      lPropertyIndexed, lPropertyIndexParameterCount) then
    begin
      lSymbol := Default(TDelphiSemanticInventorySymbol);
      lSymbol.Name := lMemberName;
      lSymbol.SymbolClass := 'property';
      lSymbol.Kind := 'property';
      lSymbol.TypeName := lPropertyType;
      lSymbol.OwnerName := lCurrentType;
      lSymbol.OwnerType := lCurrentType;
      lSymbol.UnitName := aUnitName;
      lSymbol.FileName := aFileName;
      lSymbol.Line := i + 1;
      lSymbol.EndLine := i + 1;
      lSymbol.Column := InventoryFindColumn(aLines[i], lMemberName);
      lSymbol.EndColumn := lSymbol.Column + Length(lMemberName);
      lSymbol.IsDefault := lPropertyIsDefault;
      lSymbol.IsIndexed := lPropertyIndexed;
      lSymbol.IndexParameterCount := lPropertyIndexParameterCount;
      AddInventorySymbol(aSymbols, lSymbol);
      Continue;
    end;

    if InventoryIsRoutineStart(lLine) and InventoryTryRoutineName(lLine, lMemberName) then
    begin
      if Pos('.', lMemberName) > 0 then
        lMemberName := Copy(lMemberName, LastDelimiter('.', lMemberName) + 1, MaxInt);
      lSymbol := Default(TDelphiSemanticInventorySymbol);
      lSymbol.Name := lMemberName;
      lSymbol.SymbolClass := 'method';
      lSymbol.Kind := 'method';
      lSymbol.OwnerName := lCurrentType;
      lSymbol.OwnerType := lCurrentType;
      lSymbol.UnitName := aUnitName;
      lSymbol.FileName := aFileName;
      lSymbol.Line := i + 1;
      lSymbol.EndLine := i + 1;
      lSymbol.Column := InventoryFindColumn(aLines[i], lMemberName);
      lSymbol.EndColumn := lSymbol.Column + Length(lMemberName);
      lSymbol.IsOverride := Pos(' override', lLower) > 0;
      AddInventorySymbol(aSymbols, lSymbol);
      Continue;
    end;

    lDeclarationAdded := False;
    lDeclarationParts := lLine.Split([';']);
    for lRawDeclaration in lDeclarationParts do
    begin
      lDeclaration := Trim(lRawDeclaration);
      if lDeclaration = '' then
        Continue;
      if not InventoryTryDeclaration(lDeclaration + ';', lNames, lTypeName) then
        Continue;

      if lInClassVar then
        AddDakTypedSymbols(aSymbols, lNames, lTypeName, lCurrentType, '', aUnitName, aFileName,
          i + 1, aLines[i], 'class-var')
      else
        AddDakTypedSymbols(aSymbols, lNames, lTypeName, lCurrentType, '', aUnitName, aFileName,
          i + 1, aLines[i], 'field');
      lDeclarationAdded := True;
    end;
    if lDeclarationAdded then
      Continue;

    if InventoryTryDeclaration(lLine, lNames, lTypeName) then
    begin
      if lInClassVar then
        AddDakTypedSymbols(aSymbols, lNames, lTypeName, lCurrentType, '', aUnitName, aFileName,
          i + 1, aLines[i], 'class-var')
      else
        AddDakTypedSymbols(aSymbols, lNames, lTypeName, lCurrentType, '', aUnitName, aFileName,
          i + 1, aLines[i], 'field');
    end;
  end;
end;

procedure ParseDakInventoryUnitGlobals(const aSymbols: TList<TDelphiSemanticInventorySymbol>;
  const aLines: TArray<string>; const aUnitName, aFileName: string);
var
  i: Integer;
  j: Integer;
  lAnonymousEndLine: Integer;
  lConstName: string;
  lDeclaration: string;
  lDeclarationLine: Integer;
  lEnumMatch: TMatch;
  lEnumNames: TArray<string>;
  lInConst: Boolean;
  lInType: Boolean;
  lInVar: Boolean;
  lLine: string;
  lNames: TArray<string>;
  lRawLine: string;
  lRoutineEndLine: Integer;
  lTypeCategory: string;
  lTypeName: string;
begin
  lDeclaration := '';
  lDeclarationLine := 0;
  lInConst := False;
  lInType := False;
  lInVar := False;
  i := 0;
  while i <= High(aLines) do
  begin
    try
      lRawLine := aLines[i];
      lLine := InventoryCleanLine(lRawLine);
      if lLine = '' then
        Continue;

      if SameText(lLine, 'implementation') then
      begin
        lDeclaration := '';
        lDeclarationLine := 0;
        lInType := False;
        lInVar := False;
        lInConst := False;
        Continue;
      end;

      if SameText(lLine, 'type') then
      begin
        lDeclaration := '';
        lDeclarationLine := 0;
        lInType := True;
        lInVar := False;
        lInConst := False;
        Continue;
      end;
      if SameText(lLine, 'var') or SameText(lLine, 'threadvar') then
      begin
        lDeclaration := '';
        lDeclarationLine := 0;
        lInType := False;
        lInVar := True;
        lInConst := False;
        Continue;
      end;
      if SameText(lLine, 'const') then
      begin
        lDeclaration := '';
        lDeclarationLine := 0;
        lInType := False;
        lInConst := True;
        lInVar := False;
        Continue;
      end;

      if InventoryIsConditionalDirectiveLine(lLine) then
        Continue;

      if lInType then
        Continue;

      if InventoryIsRoutineStart(lLine) then
      begin
        lInVar := False;
        lInConst := False;
        lRoutineEndLine := InventoryFindRoutineEndLine(aLines, i);
        if lRoutineEndLine > 0 then
          i := lRoutineEndLine - 1;
        Continue;
      end;

      if lInVar and (lLine <> '') then
      begin
        if (lDeclaration = '') and InventoryTryAnonymousRecordLocalStart(lLine, lConstName,
          lTypeCategory) then
        begin
          lTypeName := aUnitName + '.' + lConstName;
          lAnonymousEndLine := InventoryFindTypeEndLine(aLines, i);
          AddDakInventoryTypeSymbol(aSymbols, lTypeName, '', lTypeCategory, aUnitName,
            aFileName, i + 1, lAnonymousEndLine, aLines[i]);
          AddDakInventorySymbol(aSymbols, lConstName, lTypeName, '', '', aUnitName, aFileName,
            i + 1, aLines[i], 'unit-global');
          for j := i + 1 to lAnonymousEndLine - 2 do
            AddDakInventoryRecordFieldsFromLine(aSymbols, aLines, j, lTypeName, aUnitName,
              aFileName);
          i := lAnonymousEndLine - 1;
          Continue;
        end;

        if lDeclaration = '' then
          lDeclarationLine := i + 1;
        if lDeclaration <> '' then
          lDeclaration := lDeclaration + ' ';
        lDeclaration := lDeclaration + lLine;
        if Pos(';', lLine) > 0 then
        begin
          if InventoryTryDeclaration(lDeclaration, lNames, lTypeName) then
          begin
            AddDakTypedSymbols(aSymbols, lNames, lTypeName, '', '', aUnitName, aFileName,
              lDeclarationLine, aLines[lDeclarationLine - 1], 'unit-global');
            lEnumMatch := TRegEx.Match(lDeclaration, ':\s*\(([^)]*)\)');
            if lEnumMatch.Success and
              InventoryTryEnumValues('TAnonymousEnum = (' + lEnumMatch.Groups[1].Value + ')',
              lEnumNames) then
              AddDakTypedSymbols(aSymbols, lEnumNames, lTypeName, '', '', aUnitName,
                aFileName, lDeclarationLine, aLines[lDeclarationLine - 1], 'constant');
          end;
          lDeclaration := '';
          lDeclarationLine := 0;
        end;
      end else if lInConst and InventoryTryConstDeclaration(lLine, lConstName, lTypeName) then
        AddDakInventorySymbol(aSymbols, lConstName, lTypeName, '', '', aUnitName, aFileName,
          i + 1, aLines[i], 'constant');
    finally
      Inc(i);
    end;
  end;
end;

procedure ParseDakInventoryRoutines(const aSymbols: TList<TDelphiSemanticInventorySymbol>;
  const aLines: TArray<string>; const aUnitName, aFileName: string);
var
  i: Integer;
  lEndLine: Integer;
  lInImplementation: Boolean;
  lInType: Boolean;
  lLine: string;
  lMember: TDelphiSemanticInventorySymbol;
  lMemberCopy: TDelphiSemanticInventorySymbol;
  lMembers: TList<TDelphiSemanticInventorySymbol>;
  lMembersByOwner: TDictionary<string, TList<TDelphiSemanticInventorySymbol>>;
  lOwnerType: string;
  lRawLine: string;
  lRoutineName: string;
  lSignature: string;
  lSymbol: TDelphiSemanticInventorySymbol;
  lTopLevelLine: Boolean;
begin
  lMembersByOwner := TDictionary<string, TList<TDelphiSemanticInventorySymbol>>.Create(
    TFastCaseAwareComparer.OrdinalIgnoreCase);
  lInImplementation := False;
  lInType := False;
  try
    for lMember in aSymbols do
      if (lMember.RoutineName = '') and InventoryIsDirectMemberKind(lMember.SymbolClass) then
      begin
        if not lMembersByOwner.TryGetValue(lMember.OwnerType, lMembers) then
        begin
          lMembers := TList<TDelphiSemanticInventorySymbol>.Create;
          lMembersByOwner.Add(lMember.OwnerType, lMembers);
        end;
        lMembers.Add(lMember);
      end;

    for i := 0 to High(aLines) do
    begin
      lRawLine := aLines[i];
      lLine := InventoryCleanLine(lRawLine);
      if lLine = '' then
        Continue;
      lTopLevelLine := InventoryIsTopLevelLine(lRawLine);
      if lTopLevelLine and SameText(lLine, 'type') then
      begin
        lInType := True;
        Continue;
      end;
      if lTopLevelLine and (SameText(lLine, 'const') or SameText(lLine, 'var') or
        SameText(lLine, 'threadvar') or SameText(lLine, 'implementation')) then
      begin
        lInType := False;
        if SameText(lLine, 'implementation') then
        begin
          lInImplementation := True;
          Continue;
        end;
      end;
      if lInImplementation and lTopLevelLine and InventoryIsRoutineStart(lLine) then
        lInType := False;
      if lInType then
        Continue;

      if (not lTopLevelLine) and (not InventoryIsRoutineStart(lLine)) then
        Continue;
      lSignature := InventoryCollectDeclarationText(aLines, i, lEndLine);
      if not InventoryTryRoutineName(lSignature, lRoutineName) then
        Continue;

      lSymbol := Default(TDelphiSemanticInventorySymbol);
      lSymbol.Name := lRoutineName;
      lSymbol.SymbolClass := 'routine';
      lSymbol.Kind := 'routine';
      lSymbol.UnitName := aUnitName;
      lSymbol.FileName := aFileName;
      lSymbol.Line := i + 1;
      lSymbol.EndLine := InventoryFindRoutineEndLine(aLines, i);
      if lSymbol.EndLine = 0 then
        Continue;
      lSymbol.Column := InventoryFindColumn(aLines[i], lRoutineName);
      lSymbol.EndColumn := lSymbol.Column + Length(lRoutineName);
      AddInventorySymbol(aSymbols, lSymbol);
      ParseDakInventoryParams(aSymbols, aLines, i, lSignature, lRoutineName, aUnitName,
        aFileName);
      ParseDakInventoryLocals(aSymbols, aLines, i + 1, lRoutineName, aUnitName, aFileName);

      if InventoryTryRoutineOwner(lRoutineName, lOwnerType) and
        lMembersByOwner.TryGetValue(lOwnerType, lMembers) then
      begin
        for lMember in lMembers do
        begin
          lMemberCopy := lMember;
          lMemberCopy.SymbolClass := 'current-class-member';
          lMemberCopy.Kind := 'current-class-member';
          lMemberCopy.RoutineName := lRoutineName;
          AddInventorySymbol(aSymbols, lMemberCopy);
        end;
      end;
    end;
  finally
    for lMembers in lMembersByOwner.Values do
      lMembers.Free;
    lMembersByOwner.Free;
  end;
end;

function InventorySourceTextLines(const aSourceText: string): TArray<string>;
var
  lLines: TStringList;
  i: Integer;
begin
  lLines := TStringList.Create;
  try
    lLines.Text := InventoryMaskTrivia(aSourceText, False);
    SetLength(Result, lLines.Count);
    for i := 0 to lLines.Count - 1 do
      Result[i] := lLines[i];
  finally
    lLines.Free;
  end;
end;

procedure AddModelSourceCompatibilitySymbols(
  const aModel: TDelphiSemanticUnitModel; const aSymbols: TList<TDelphiSemanticInventorySymbol>);
var
  lLines: TArray<string>;
begin
  lLines := InventorySourceTextLines(aModel.SourceText);
  ParseDakInventoryTypeMembers(aSymbols,
    InventorySourceTextLines(InventoryMaskTrivia(aModel.SourceText, True)),
    aModel.UnitName, aModel.FileName);
  ParseDakInventoryUnitGlobals(aSymbols, lLines, aModel.UnitName, aModel.FileName);
  ParseDakInventoryRoutines(aSymbols, lLines, aModel.UnitName, aModel.FileName);
end;

procedure AddDakCompatibleInventorySymbols(const aModel: TDelphiSemanticUnitModel;
  const aSymbols: TList<TDelphiSemanticInventorySymbol>);
begin
  AddDakInventorySymbol(aSymbols, aModel.UnitName, '', '', '', aModel.UnitName, aModel.FileName,
    1, aModel.UnitName, 'unit');
  AddModelSourceCompatibilitySymbols(aModel, aSymbols);
end;

function InventorySameSymbol(const aLeft, aRight: TDelphiSemanticInventorySymbol): Boolean;
begin
  Result := SameText(aLeft.SymbolClass, aRight.SymbolClass) and SameText(aLeft.Name, aRight.Name) and
    SameText(aLeft.TypeName, aRight.TypeName) and SameText(aLeft.Modifier, aRight.Modifier) and
    SameText(aLeft.OwnerType, aRight.OwnerType) and SameText(aLeft.SourceOwnerType, aRight.SourceOwnerType) and
    SameText(aLeft.RelatedTypeName, aRight.RelatedTypeName) and
    SameText(aLeft.RoutineName, aRight.RoutineName) and SameText(aLeft.UnitName, aRight.UnitName) and
    SameText(aLeft.RoutineScopeId, aRight.RoutineScopeId) and
    SameText(aLeft.ParentScopeId, aRight.ParentScopeId) and
    SameText(aLeft.OwnerScopeId, aRight.OwnerScopeId) and
    SameText(aLeft.OwnerSymbolId, aRight.OwnerSymbolId) and
    SameText(aLeft.FileName, aRight.FileName) and (aLeft.Line = aRight.Line) and
    (aLeft.Column = aRight.Column) and SameText(aLeft.UnsupportedReason, aRight.UnsupportedReason) and
    SameText(aLeft.AccessOwnerUnitName, aRight.AccessOwnerUnitName) and
    SameText(aLeft.AccessOwnerFileName, aRight.AccessOwnerFileName) and
    SameText(aLeft.AccessOwnerSectionKind, aRight.AccessOwnerSectionKind) and
    (aLeft.AccessOwnerLine = aRight.AccessOwnerLine) and
    (aLeft.AccessOwnerColumn = aRight.AccessOwnerColumn) and
    (aLeft.IsHelper = aRight.IsHelper) and (aLeft.IsOverride = aRight.IsOverride) and
    (aLeft.IsDefault = aRight.IsDefault) and SameText(aLeft.TypeCategory, aRight.TypeCategory);
end;

function InventorySymbolKey(const aSymbol: TDelphiSemanticInventorySymbol): string;
const
  cSeparator = #31;
begin
  Result := aSymbol.SymbolClass + cSeparator + aSymbol.Name + cSeparator +
    aSymbol.TypeName + cSeparator + aSymbol.Modifier + cSeparator +
    aSymbol.OwnerType + cSeparator + aSymbol.SourceOwnerType + cSeparator + aSymbol.RelatedTypeName +
    cSeparator + aSymbol.RoutineName + cSeparator + aSymbol.UnitName +
    cSeparator + aSymbol.FileName + cSeparator + IntToStr(aSymbol.Line) +
    cSeparator + aSymbol.RoutineScopeId + cSeparator + aSymbol.ParentScopeId +
    cSeparator + aSymbol.OwnerScopeId + cSeparator + aSymbol.OwnerSymbolId +
    cSeparator + IntToStr(aSymbol.Column) + cSeparator + aSymbol.UnsupportedReason +
    cSeparator + aSymbol.AccessOwnerUnitName + cSeparator +
    aSymbol.AccessOwnerFileName + cSeparator + aSymbol.AccessOwnerSectionKind +
    cSeparator + IntToStr(aSymbol.AccessOwnerLine) + cSeparator +
    IntToStr(aSymbol.AccessOwnerColumn) +
    cSeparator + IntToStr(Ord(aSymbol.IsHelper)) + cSeparator +
    IntToStr(Ord(aSymbol.IsOverride)) + cSeparator + IntToStr(Ord(aSymbol.IsDefault)) +
    cSeparator + aSymbol.TypeCategory;
end;

function AddExpandedInventorySymbol(const aSymbols: TList<TDelphiSemanticInventorySymbol>;
  const aSymbol: TDelphiSemanticInventorySymbol): Boolean;
var
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  for lSymbol in aSymbols do
    if InventorySameSymbol(lSymbol, aSymbol) then
      Exit(False);

  aSymbols.Add(aSymbol);
  Result := True;
end;

function AddExpandedInventorySymbolWithKeys(const aSymbols: TList<TDelphiSemanticInventorySymbol>;
  const aKeys: TDictionary<string, Byte>; const aSymbol: TDelphiSemanticInventorySymbol): Boolean;
var
  lKey: string;
begin
  lKey := InventorySymbolKey(aSymbol);
  if aKeys.ContainsKey(lKey) then
    Exit(False);

  aKeys.Add(lKey, 1);
  aSymbols.Add(aSymbol);
  Result := True;
end;

function InventoryOwnMemberKey(const aOwnerType, aName: string): string;
const
  cSeparator = #31;
begin
  Result := aOwnerType + cSeparator + aName;
end;

function BuildInventoryOwnMemberKeys(const aSymbols: TList<TDelphiSemanticInventorySymbol>;
  const aSymbolCount: Integer): TDictionary<string, Byte>;
var
  i: Integer;
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  Result := TDictionary<string, Byte>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
  for i := 0 to aSymbolCount - 1 do
  begin
    lSymbol := aSymbols[i];
    if (lSymbol.OwnerType <> '') and (lSymbol.OwnerScopeId = '') and
      (lSymbol.SourceOwnerType = '') and
      InventoryIsDirectMemberKind(lSymbol.SymbolClass) then
      Result.AddOrSetValue(InventoryOwnMemberKey(lSymbol.OwnerType, lSymbol.Name), 1);
  end;
end;

procedure AddRelatedInventoryMemberOwnerIndex(const aMembersByOwner: TDictionary<string,
  TList<TDelphiSemanticInventorySymbol>>; const aOwnerType: string;
  const aSymbol: TDelphiSemanticInventorySymbol);
var
  lMembers: TList<TDelphiSemanticInventorySymbol>;
begin
  if aOwnerType = '' then
    Exit;

  if not aMembersByOwner.TryGetValue(aOwnerType, lMembers) then
  begin
    lMembers := TList<TDelphiSemanticInventorySymbol>.Create;
    aMembersByOwner.Add(aOwnerType, lMembers);
  end;
  lMembers.Add(aSymbol);
end;

procedure QueueRelatedInventoryOwner(const aPendingOwners: TQueue<string>;
  const aQueuedOwners: TDictionary<string, Byte>; const aOwnerType: string);
begin
  if aOwnerType = '' then
    Exit;
  if aQueuedOwners.ContainsKey(aOwnerType) then
    Exit;

  aQueuedOwners.Add(aOwnerType, 1);
  aPendingOwners.Enqueue(aOwnerType);
end;

procedure AddRelatedInventoryMemberRelation(const aRelationsByOwner: TDictionary<string,
  TList<TRelatedInventoryMemberRelation>>; const aRelation:
  TRelatedInventoryMemberRelation);
var
  lRelations: TList<TRelatedInventoryMemberRelation>;
begin
  if (aRelation.SourceOwnerType = '') or (aRelation.TargetOwnerType = '') then
    Exit;

  if not aRelationsByOwner.TryGetValue(aRelation.SourceOwnerType, lRelations) then
  begin
    lRelations := TList<TRelatedInventoryMemberRelation>.Create;
    aRelationsByOwner.Add(aRelation.SourceOwnerType, lRelations);
  end;
  lRelations.Add(aRelation);
end;

function BuildRelatedInventoryMemberRelations(const aSymbols:
  TList<TDelphiSemanticInventorySymbol>; const aSymbolCount: Integer): TDictionary<string,
  TList<TRelatedInventoryMemberRelation>>;
var
  i: Integer;
  lRelation: TRelatedInventoryMemberRelation;
  lTypeSymbol: TDelphiSemanticInventorySymbol;
begin
  Result := TDictionary<string, TList<TRelatedInventoryMemberRelation>>.Create(
    TFastCaseAwareComparer.OrdinalIgnoreCase);
  for i := 0 to aSymbolCount - 1 do
  begin
    lTypeSymbol := aSymbols[i];
    if (not SameText(lTypeSymbol.SymbolClass, 'type-member')) or
      (lTypeSymbol.RelatedTypeName = '') or (lTypeSymbol.UnsupportedReason <> '') then
      Continue;

    lRelation := Default(TRelatedInventoryMemberRelation);
    lRelation.IsHelper := lTypeSymbol.IsHelper;
    if lTypeSymbol.IsHelper then
    begin
      lRelation.SourceOwnerType := lTypeSymbol.Name;
      lRelation.TargetOwnerType := lTypeSymbol.RelatedTypeName;
    end else
    begin
      lRelation.SourceOwnerType := lTypeSymbol.RelatedTypeName;
      lRelation.TargetOwnerType := lTypeSymbol.Name;
      lRelation.TargetOwnerUnitName := lTypeSymbol.UnitName;
      lRelation.TargetOwnerFileName := lTypeSymbol.FileName;
      lRelation.TargetOwnerSectionKind := lTypeSymbol.SectionKind;
      lRelation.TargetOwnerLine := lTypeSymbol.Line;
      lRelation.TargetOwnerColumn := lTypeSymbol.Column;
    end;
    AddRelatedInventoryMemberRelation(Result, lRelation);
  end;
end;

procedure AddRelatedInventoryMemberSymbols(const aSymbols: TList<TDelphiSemanticInventorySymbol>;
  const aKeys: TDictionary<string, Byte>);
var
  i: Integer;
  lMember: TDelphiSemanticInventorySymbol;
  lMemberCount: Integer;
  lMemberPair: TPair<string, TList<TDelphiSemanticInventorySymbol>>;
  lMembers: TList<TDelphiSemanticInventorySymbol>;
  lMembersByOwner: TDictionary<string, TList<TDelphiSemanticInventorySymbol>>;
  lMemberSourceOwnerType: string;
  lOwnMemberKeys: TDictionary<string, Byte>;
  lPendingOwners: TQueue<string>;
  lQueuedOwners: TDictionary<string, Byte>;
  lRelation: TRelatedInventoryMemberRelation;
  lRelationPair: TPair<string, TList<TRelatedInventoryMemberRelation>>;
  lRelations: TList<TRelatedInventoryMemberRelation>;
  lRelationsByOwner: TDictionary<string, TList<TRelatedInventoryMemberRelation>>;
  lSourceOwnerType: string;
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  lMembersByOwner := TDictionary<string, TList<TDelphiSemanticInventorySymbol>>.Create(
    TFastCaseAwareComparer.OrdinalIgnoreCase);
  lOwnMemberKeys := BuildInventoryOwnMemberKeys(aSymbols, aSymbols.Count);
  lPendingOwners := TQueue<string>.Create;
  lQueuedOwners := TDictionary<string, Byte>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
  lRelationsByOwner := BuildRelatedInventoryMemberRelations(aSymbols, aSymbols.Count);
  try
    for i := 0 to aSymbols.Count - 1 do
    begin
      lMember := aSymbols[i];
      if (lMember.RoutineName <> '') or (lMember.OwnerScopeId <> '') or
        (not InventoryIsDirectMemberKind(lMember.SymbolClass)) then
        Continue;
      AddRelatedInventoryMemberOwnerIndex(lMembersByOwner, lMember.OwnerType, lMember);
    end;

    for lRelationPair in lRelationsByOwner do
      if lMembersByOwner.ContainsKey(lRelationPair.Key) then
        QueueRelatedInventoryOwner(lPendingOwners, lQueuedOwners, lRelationPair.Key);

    while lPendingOwners.Count > 0 do
    begin
      lSourceOwnerType := lPendingOwners.Dequeue;
      lQueuedOwners.Remove(lSourceOwnerType);
      if not lRelationsByOwner.TryGetValue(lSourceOwnerType, lRelations) then
        Continue;
      if not lMembersByOwner.TryGetValue(lSourceOwnerType, lMembers) then
        Continue;

      lMemberCount := lMembers.Count;
      for lRelation in lRelations do
        for i := 0 to lMemberCount - 1 do
        begin
          lMember := lMembers[i];
          lSymbol := lMember;
          lSymbol.OwnerName := lRelation.TargetOwnerType;
          lSymbol.OwnerType := lRelation.TargetOwnerType;
          if lRelation.IsHelper then
            lSymbol.SourceOwnerType := lRelation.SourceOwnerType
          else
          begin
            lMemberSourceOwnerType := lMember.SourceOwnerType;
            if lMemberSourceOwnerType = '' then
              lMemberSourceOwnerType := lMember.OwnerType;
            lSymbol.SourceOwnerType := lMemberSourceOwnerType;
            lSymbol.AccessOwnerUnitName := lRelation.TargetOwnerUnitName;
            lSymbol.AccessOwnerFileName := lRelation.TargetOwnerFileName;
            lSymbol.AccessOwnerSectionKind := lRelation.TargetOwnerSectionKind;
            lSymbol.AccessOwnerLine := lRelation.TargetOwnerLine;
            lSymbol.AccessOwnerColumn := lRelation.TargetOwnerColumn;
          end;

          if lOwnMemberKeys.ContainsKey(InventoryOwnMemberKey(lSymbol.OwnerType,
            lSymbol.Name)) then
            Continue;
          if AddExpandedInventorySymbolWithKeys(aSymbols, aKeys, lSymbol) then
          begin
            AddRelatedInventoryMemberOwnerIndex(lMembersByOwner, lSymbol.OwnerType, lSymbol);
            QueueRelatedInventoryOwner(lPendingOwners, lQueuedOwners, lSymbol.OwnerType);
          end;
        end;
    end;
  finally
    for lRelationPair in lRelationsByOwner do
      lRelationPair.Value.Free;
    for lMemberPair in lMembersByOwner do
      lMemberPair.Value.Free;
    lRelationsByOwner.Free;
    lQueuedOwners.Free;
    lPendingOwners.Free;
    lOwnMemberKeys.Free;
    lMembersByOwner.Free;
  end;
end;

procedure AddRelatedInventoryCurrentClassSymbols(const aSymbols: TList<TDelphiSemanticInventorySymbol>;
  const aKeys: TDictionary<string, Byte>);
var
  i: Integer;
  lCurrentMember: TDelphiSemanticInventorySymbol;
  lMember: TDelphiSemanticInventorySymbol;
  lMembers: TList<TDelphiSemanticInventorySymbol>;
  lMembersByOwner: TDictionary<string, TList<TDelphiSemanticInventorySymbol>>;
  lOwnerKey: string;
  lPair: TPair<string, TList<TDelphiSemanticInventorySymbol>>;
  lProjectedContextKey: string;
  lProjectedContextKeys: TDictionary<string, Byte>;
  lSymbol: TDelphiSemanticInventorySymbol;
  lSymbolCount: Integer;
begin
  lSymbolCount := aSymbols.Count;
  lMembersByOwner := TDictionary<string, TList<TDelphiSemanticInventorySymbol>>.Create(
    TFastCaseAwareComparer.OrdinalIgnoreCase);
  lProjectedContextKeys := TDictionary<string, Byte>.Create(
    TFastCaseAwareComparer.OrdinalIgnoreCase);
  try
    for i := 0 to lSymbolCount - 1 do
    begin
      lMember := aSymbols[i];
      if (lMember.OwnerType = '') or (lMember.RoutineName <> '') or
        (lMember.OwnerScopeId <> '') or
        (not InventoryIsDirectMemberKind(lMember.SymbolClass)) then
        Continue;
      lOwnerKey := lMember.UnitName + #31 + lMember.FileName + #31 +
        lMember.OwnerType;
      if not lMembersByOwner.TryGetValue(lOwnerKey, lMembers) then
      begin
        lMembers := TList<TDelphiSemanticInventorySymbol>.Create;
        lMembersByOwner.Add(lOwnerKey, lMembers);
      end;
      lMembers.Add(lMember);
    end;

    for i := 0 to lSymbolCount - 1 do
    begin
      lCurrentMember := aSymbols[i];
      if (not SameText(lCurrentMember.SymbolClass, 'current-class-member')) or
        (lCurrentMember.OwnerType = '') or (lCurrentMember.RoutineName = '') then
        Continue;
      lOwnerKey := lCurrentMember.UnitName + #31 + lCurrentMember.FileName +
        #31 + lCurrentMember.OwnerType;
      lProjectedContextKey := lOwnerKey + #31 + lCurrentMember.RoutineName;
      if lProjectedContextKeys.ContainsKey(lProjectedContextKey) then
        Continue;
      lProjectedContextKeys.Add(lProjectedContextKey, 1);
      if not lMembersByOwner.TryGetValue(lOwnerKey, lMembers) then
        Continue;

      for lMember in lMembers do
      begin
        lSymbol := lMember;
        lSymbol.SymbolClass := 'current-class-member';
        lSymbol.Kind := 'current-class-member';
        lSymbol.RoutineName := lCurrentMember.RoutineName;
        AddExpandedInventorySymbolWithKeys(aSymbols, aKeys, lSymbol);
      end;
    end;
  finally
    for lPair in lMembersByOwner do
      lPair.Value.Free;
    lProjectedContextKeys.Free;
    lMembersByOwner.Free;
  end;
end;

procedure AddExpandedExternalTypeSymbol(const aSymbols: TList<TDelphiSemanticInventorySymbol>;
  const aKeys, aSourceTypes, aExternalTypes: TDictionary<string, Byte>;
  const aTypeName: string);
var
  lSymbol: TDelphiSemanticInventorySymbol;
  lTypeName: string;
begin
  lTypeName := InventorySimpleTypeName(aTypeName);
  if (lTypeName = '') or InventoryIsBuiltInTypeName(lTypeName) then
    Exit;
  if aSourceTypes.ContainsKey(lTypeName) or aExternalTypes.ContainsKey(lTypeName) then
    Exit;

  aExternalTypes.Add(lTypeName, 1);
  lSymbol := Default(TDelphiSemanticInventorySymbol);
  lSymbol.Name := lTypeName;
  lSymbol.SymbolClass := 'external';
  lSymbol.Kind := 'external';
  lSymbol.TypeName := lTypeName;
  AddExpandedInventorySymbolWithKeys(aSymbols, aKeys, lSymbol);
end;

procedure AddExpandedExternalTypeSymbols(const aSymbols: TList<TDelphiSemanticInventorySymbol>;
  const aKeys: TDictionary<string, Byte>);
var
  i: Integer;
  lExternalTypes: TDictionary<string, Byte>;
  lSourceTypes: TDictionary<string, Byte>;
  lSymbol: TDelphiSemanticInventorySymbol;
  lSymbolCount: Integer;
begin
  lSourceTypes := TDictionary<string, Byte>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
  try
    lExternalTypes := TDictionary<string, Byte>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
    try
      for lSymbol in aSymbols do
      begin
        if SameText(lSymbol.SymbolClass, 'type-member') then
          lSourceTypes.AddOrSetValue(lSymbol.Name, 1)
        else if SameText(lSymbol.SymbolClass, 'external') and (lSymbol.TypeName <> '') then
          lExternalTypes.AddOrSetValue(lSymbol.Name, 1);
      end;

      lSymbolCount := aSymbols.Count;
      for i := 0 to lSymbolCount - 1 do
      begin
        lSymbol := aSymbols[i];
        AddExpandedExternalTypeSymbol(aSymbols, aKeys, lSourceTypes, lExternalTypes,
          lSymbol.TypeName);
        AddExpandedExternalTypeSymbol(aSymbols, aKeys, lSourceTypes, lExternalTypes,
          lSymbol.RelatedTypeName);
      end;
    finally
      lExternalTypes.Free;
    end;
  finally
    lSourceTypes.Free;
  end;
end;

function CompilerProfileCompatibilitySourceKind(
  const aIntrinsic: TDelphiSemanticIntrinsicSymbol): string;
begin
  if SameText(aIntrinsic.OwnerName, 'rtl') or
    SameText(aIntrinsic.Kind, 'intrinsic-field') or
    SameText(aIntrinsic.Kind, 'intrinsic-property') then
    Result := 'rtl-source'
  else
    Result := 'compiler-intrinsic';
end;

function CompilerProfileCompatibilityTypeCategory(
  const aIntrinsic: TDelphiSemanticIntrinsicSymbol): string;
begin
  if SameText(aIntrinsic.TypeName, 'record') then
    Result := 'record'
  else if SameText(aIntrinsic.TypeName, 'class') then
    Result := 'class'
  else if SameText(aIntrinsic.TypeName, 'Pointer') or StartsText('^', aIntrinsic.TypeName) then
    Result := 'pointer'
  else if MatchText(aIntrinsic.Name, ['Boolean', 'Byte', 'Char', 'Integer', 'Int32',
    'NativeInt', 'NativeUInt']) then
    Result := 'ordinal'
  else
    Result := '';
end;

procedure AddCompilerProfileCompatibilitySymbol(
  const aSymbols: TList<TDelphiSemanticInventorySymbol>;
  const aIntrinsic: TDelphiSemanticIntrinsicSymbol);
var
  lSymbol: TDelphiSemanticInventorySymbol;
  lSourceKind: string;
begin
  lSourceKind := CompilerProfileCompatibilitySourceKind(aIntrinsic);
  lSymbol := Default(TDelphiSemanticInventorySymbol);
  lSymbol.Name := aIntrinsic.Name;
  lSymbol.TypeName := aIntrinsic.TypeName;
  lSymbol.SourceOwnerType := lSourceKind;
  lSymbol.UnitName := lSourceKind;
  lSymbol.TypeCategory := CompilerProfileCompatibilityTypeCategory(aIntrinsic);
  if SameText(aIntrinsic.Kind, 'intrinsic-routine') then
  begin
    lSymbol.SymbolClass := 'routine';
    lSymbol.Kind := 'routine';
  end else if SameText(aIntrinsic.Kind, 'intrinsic-unit') then
  begin
    lSymbol.SymbolClass := 'unit';
    lSymbol.Kind := 'unit';
  end else if SameText(aIntrinsic.Kind, 'intrinsic-type') then
  begin
    if SameText(lSourceKind, 'rtl-source') then
    begin
      lSymbol.SymbolClass := 'type-member';
      lSymbol.Kind := 'type-member';
    end else
    begin
      lSymbol.SymbolClass := 'type';
      lSymbol.Kind := 'type';
    end;
  end else if SameText(aIntrinsic.Kind, 'intrinsic-field') then
  begin
    lSymbol.SymbolClass := 'field';
    lSymbol.Kind := 'field';
    lSymbol.OwnerName := aIntrinsic.OwnerName;
    lSymbol.OwnerType := aIntrinsic.OwnerName;
  end else if SameText(aIntrinsic.Kind, 'intrinsic-property') then
  begin
    lSymbol.SymbolClass := 'property';
    lSymbol.Kind := 'property';
    lSymbol.OwnerName := aIntrinsic.OwnerName;
    lSymbol.OwnerType := aIntrinsic.OwnerName;
  end else
    Exit;
  AddInventorySymbol(aSymbols, lSymbol);
end;

class procedure TDelphiSemanticWithBindingInventory.AddCompilerProfileCompatibilitySymbols(
  const aSymbols: TList<TDelphiSemanticInventorySymbol>);
var
  lIntrinsic: TDelphiSemanticIntrinsicSymbol;
  lProfile: TDelphiSemanticCompilerProfile;
begin
  lProfile := TDelphiSemanticCompilerProfileBuilder.DefaultProfile('with-binding-compatibility');
  for lIntrinsic in lProfile.IntrinsicSymbols do
    AddCompilerProfileCompatibilitySymbol(aSymbols, lIntrinsic);
end;

procedure AddProjectExternalUsesUnits(const aSymbols: TList<TDelphiSemanticInventorySymbol>;
  const aExistingUnits, aExternalUnits: TDictionary<string, Byte>; const aUnits: TArray<string>;
  const aSourceUnitName, aFileName: string);
var
  lSymbol: TDelphiSemanticInventorySymbol;
  lUnitKey: string;
  lUnitName: string;
  lUsedUnit: string;
begin
  for lUsedUnit in aUnits do
  begin
    lUnitName := Trim(lUsedUnit);
    if lUnitName = '' then
      Continue;

    lUnitKey := aFileName + '|' + lUnitName;
    if aExistingUnits.ContainsKey(lUnitName) or aExternalUnits.ContainsKey(lUnitKey) then
      Continue;

    aExternalUnits.Add(lUnitKey, 1);
    lSymbol := Default(TDelphiSemanticInventorySymbol);
    lSymbol.Name := lUnitName;
    lSymbol.SymbolClass := 'external';
    lSymbol.Kind := 'external';
    lSymbol.UnitName := aSourceUnitName;
    lSymbol.FileName := aFileName;
    AddInventorySymbol(aSymbols, lSymbol);
  end;
end;

class procedure TDelphiSemanticWithBindingInventory.AddProjectExternalUnitSymbols(const aModels: TArray<TDelphiSemanticUnitModel>;
  const aSymbols: TList<TDelphiSemanticInventorySymbol>);
var
  lExistingUnits: TDictionary<string, Byte>;
  lExternalUnits: TDictionary<string, Byte>;
  lModel: TDelphiSemanticUnitModel;
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  lExistingUnits := TDictionary<string, Byte>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
  try
    lExternalUnits := TDictionary<string, Byte>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
    try
      for lSymbol in aSymbols do
      begin
        if SameText(lSymbol.SymbolClass, 'unit') then
          lExistingUnits.AddOrSetValue(lSymbol.Name, 1)
        else if SameText(lSymbol.SymbolClass, 'external') then
          lExternalUnits.AddOrSetValue(lSymbol.FileName + '|' + lSymbol.Name, 1);
      end;

      for lModel in aModels do
      begin
        AddProjectExternalUsesUnits(aSymbols, lExistingUnits, lExternalUnits,
          lModel.InterfaceUses, lModel.UnitName, lModel.FileName);
        AddProjectExternalUsesUnits(aSymbols, lExistingUnits, lExternalUnits,
          lModel.ImplementationUses, lModel.UnitName, lModel.FileName);
      end;
    finally
      lExternalUnits.Free;
    end;
  finally
    lExistingUnits.Free;
  end;
end;

class function TDelphiSemanticWithBindingInventory.ExpandInventorySymbols(
  const aSymbols: TArray<TDelphiSemanticInventorySymbol>): TArray<TDelphiSemanticInventorySymbol>;
var
  lKeys: TDictionary<string, Byte>;
  lSymbol: TDelphiSemanticInventorySymbol;
  lSymbols: TList<TDelphiSemanticInventorySymbol>;
begin
  lKeys := TDictionary<string, Byte>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
  lSymbols := TList<TDelphiSemanticInventorySymbol>.Create;
  try
    for lSymbol in aSymbols do
      AddExpandedInventorySymbolWithKeys(lSymbols, lKeys, lSymbol);
    AddRelatedInventoryMemberSymbols(lSymbols, lKeys);
    AddRelatedInventoryCurrentClassSymbols(lSymbols, lKeys);
    AddExpandedExternalTypeSymbols(lSymbols, lKeys);
    Result := lSymbols.ToArray;
  finally
    lSymbols.Free;
    lKeys.Free;
  end;
end;

function IsVerifiedLexicalRoutineBody(const aModel: TDelphiSemanticUnitModel;
  const aRoutine: TDelphiSemanticRoutine): Boolean;
var
  lCandidate: TDelphiSemanticRoutine;
  lMatchingCount: Integer;
  lOther: TDelphiSemanticRoutine;
  lSourceFileName: string;
  lVerifiedBody: TDelphiSemanticRoutine;
begin
  Result := False;
  if (not SameText(aRoutine.AstScopeKind, 'body')) or
    (aRoutine.ScopeId = '') or (aRoutine.Name = '') then
    Exit;
  lSourceFileName := aRoutine.FileName;
  if lSourceFileName = '' then
    lSourceFileName := aModel.FileName;
  if (lSourceFileName = '') or (aRoutine.Line <= 0) or
    (aRoutine.EndLine < aRoutine.Line) then
    Exit;
  lMatchingCount := 0;
  lOther := Default(TDelphiSemanticRoutine);
  for lCandidate in aModel.Routines do
    if SameText(lCandidate.ScopeId, aRoutine.ScopeId) then
    begin
      Inc(lMatchingCount);
      if (lCandidate.Line <> aRoutine.Line) or
        (lCandidate.Column <> aRoutine.Column) or
        (not SameText(lCandidate.AstScopeKind, aRoutine.AstScopeKind)) then
        lOther := lCandidate;
    end;
  if lMatchingCount = 1 then
    Exit(True);
  if lMatchingCount <> 2 then
    Exit(False);
  Result := TDelphiSemanticTypeResolver.VerifiedRoutineBody(aModel,
    aRoutine, lOther, lVerifiedBody) and
    (lVerifiedBody.Line = aRoutine.Line) and
    (lVerifiedBody.Column = aRoutine.Column);
end;

function InventoryIsRoutineSymbolClass(const aSymbolClass: string): Boolean;
begin
  Result := SameText(aSymbolClass, 'local') or SameText(aSymbolClass, 'parameter');
end;

function InventoryRoutineSymbolPositionKey(const aSymbol: TDelphiSemanticInventorySymbol): string;
const
  cSeparator = #31;
begin
  Result := aSymbol.SymbolClass + cSeparator + aSymbol.FileName + cSeparator +
    IntToStr(aSymbol.Line) + cSeparator + IntToStr(aSymbol.Column) + cSeparator + aSymbol.Name;
end;

function InventoryRoutineSymbolScopeKey(const aSymbol: TDelphiSemanticInventorySymbol;
  const aScopeId: string): string;
const
  cSeparator = #31;
begin
  Result := aSymbol.SymbolClass + cSeparator + aSymbol.FileName + cSeparator + aScopeId +
    cSeparator + Trim(aSymbol.Name);
end;

// Returns the scope of the innermost AST routine whose source range holds the
// line, or '' when no routine of that file encloses it.
function InventoryInnermostRoutineScopeAt(const aModel: TDelphiSemanticUnitModel;
  const aFileName: string; const aLine: Integer): string;
var
  lBestSpan: Integer;
  lRoutine: TDelphiSemanticRoutine;
begin
  Result := '';
  lBestSpan := MaxInt;
  for lRoutine in aModel.Routines do
    if (lRoutine.ScopeId <> '') and (lRoutine.Line <= aLine) and (aLine <= lRoutine.EndLine) and
      ((lRoutine.FileName = '') or SameText(lRoutine.FileName, aFileName)) and
      (lRoutine.EndLine - lRoutine.Line < lBestSpan) then
    begin
      lBestSpan := lRoutine.EndLine - lRoutine.Line;
      Result := lRoutine.ScopeId;
    end;
end;

// Source-text compatibility locals and parameters duplicate AST symbols but
// carry no routine scope. A text twin takes the scope of the AST symbol that
// declares the same name at the same file, line and column. A text twin whose
// position the scanner could not place (for example a name repeated in a
// comment) is redundant when the innermost AST routine enclosing its line
// declares a symbol of the same class and name; we drop it rather than guess a
// scope. Any other text symbol stays scope-less, so a persisted snapshot fails
// closed on reload and the facts are rebuilt from source.
procedure AssignTextInventoryRoutineScopes(const aModel: TDelphiSemanticUnitModel;
  const aSymbols: TList<TDelphiSemanticInventorySymbol>; const aFirstTextIndex: NativeInt);
var
  i: NativeInt;
  lAstScopedNames: TDictionary<string, Byte>;
  lKey: string;
  lScopeId: string;
  lScopes: TDictionary<string, string>;
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  lAstScopedNames := TDictionary<string, Byte>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
  lScopes := TDictionary<string, string>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
  try
    for i := 0 to aFirstTextIndex - 1 do
    begin
      lSymbol := aSymbols[i];
      if (lSymbol.RoutineScopeId = '') or
        (not InventoryIsRoutineSymbolClass(lSymbol.SymbolClass)) then
        Continue;
      lAstScopedNames.AddOrSetValue(InventoryRoutineSymbolScopeKey(lSymbol,
        lSymbol.RoutineScopeId), 1);
      lKey := InventoryRoutineSymbolPositionKey(lSymbol);
      if not lScopes.TryGetValue(lKey, lScopeId) then
        lScopes.Add(lKey, lSymbol.RoutineScopeId)
      else if not SameText(lScopeId, lSymbol.RoutineScopeId) then
        lScopes[lKey] := ''; // Conflicting AST twins: no scope is proven.
    end;
    for i := aSymbols.Count - 1 downto aFirstTextIndex do
    begin
      lSymbol := aSymbols[i];
      if (lSymbol.RoutineScopeId <> '') or
        (not InventoryIsRoutineSymbolClass(lSymbol.SymbolClass)) then
        Continue;
      if lScopes.TryGetValue(InventoryRoutineSymbolPositionKey(lSymbol), lScopeId) and
        (lScopeId <> '') then
      begin
        lSymbol.RoutineScopeId := lScopeId;
        aSymbols[i] := lSymbol;
        Continue;
      end;
      lScopeId := InventoryInnermostRoutineScopeAt(aModel, lSymbol.FileName, lSymbol.Line);
      if (lScopeId <> '') and
        lAstScopedNames.ContainsKey(InventoryRoutineSymbolScopeKey(lSymbol, lScopeId)) then
        aSymbols.Delete(i);
    end;
  finally
    lScopes.Free;
    lAstScopedNames.Free;
  end;
end;

class function TDelphiSemanticWithBindingInventory.BuildInventorySymbols(const aModel: TDelphiSemanticUnitModel):
  TArray<TDelphiSemanticInventorySymbol>;
var
  lDeclaration: TDelphiSemanticDeclaration;
  lFirstTextIndex: NativeInt;
  lLocal: TDelphiSemanticLocal;
  lMember: TDelphiSemanticMember;
  lParameter: TDelphiSemanticParameter;
  lRoutine: TDelphiSemanticRoutine;
  lSymbol: TDelphiSemanticInventorySymbol;
  lSymbolCapacity: Integer;
  lSymbols: TList<TDelphiSemanticInventorySymbol>;
begin
  lSymbols := TList<TDelphiSemanticInventorySymbol>.Create;
  try
    lSymbolCapacity := 1 + Length(aModel.Declarations) + Length(aModel.Members) +
      Length(aModel.Routines) + Length(aModel.Locals);
    for lRoutine in aModel.Routines do
      Inc(lSymbolCapacity, Length(lRoutine.Parameters));
    lSymbols.Capacity := lSymbolCapacity;

    lSymbol := Default(TDelphiSemanticInventorySymbol);
    lSymbol.Name := aModel.UnitName;
    lSymbol.SymbolClass := 'unit';
    lSymbol.Kind := 'unit';
    lSymbol.UnitName := aModel.UnitName;
    lSymbol.FileName := aModel.FileName;
    lSymbol.Line := 1;
    lSymbol.Column := 1;
    AddInventorySymbol(lSymbols, lSymbol);

    for lDeclaration in aModel.Declarations do
    begin
      lSymbol := Default(TDelphiSemanticInventorySymbol);
      lSymbol.Name := lDeclaration.Name;
      lSymbol.SymbolClass := 'declaration';
      lSymbol.Kind := lDeclaration.Kind;
      lSymbol.TypeName := lDeclaration.TypeName;
      lSymbol.OwnerName := aModel.UnitName;
      lSymbol.OwnerType := aModel.UnitName;
      lSymbol.RelatedTypeName := lDeclaration.BaseTypeName;
      if SameText(lDeclaration.Kind, 'type-alias') then
        lSymbol.RelatedTypeName := lDeclaration.TypeName;
      lSymbol.IsHelper := lDeclaration.HelperTargetName <> '';
      if lSymbol.IsHelper then
        lSymbol.RelatedTypeName := lDeclaration.HelperTargetName;
      if SameText(lDeclaration.TypeName, 'record') or SameText(lDeclaration.TypeName, 'class') or
        SameText(lDeclaration.TypeName, 'interface') then
        lSymbol.TypeCategory := lDeclaration.TypeName;
      lSymbol.UnitName := aModel.UnitName;
      lSymbol.FileName := aModel.FileName;
      lSymbol.SectionKind := lDeclaration.SectionKind;
      lSymbol.RoutineScopeId := lDeclaration.OwnerScopeId;
      lSymbol.OwnerScopeId := lDeclaration.OwnerScopeId;
      lSymbol.OwnerSymbolId := lDeclaration.SymbolId;
      lSymbol.Line := lDeclaration.Line;
      lSymbol.Column := lDeclaration.Column;
      lSymbol.EndLine := lDeclaration.Line;
      lSymbol.EndColumn := lDeclaration.Column;
      AddInventorySymbol(lSymbols, lSymbol);
      if (lDeclaration.TypeBodyEndLine > 0) and (lDeclaration.TypeBodyEndColumn > 0) then
      begin
        // DS-721: separate AST metadata, not a member or a public name-span identity.
        // Existing snapshot inventory storage preserves this endpoint without new columns.
        lSymbol.SymbolClass := 'type-body-range';
        lSymbol.Kind := 'type-body-range';
        lSymbol.FileName := lDeclaration.FileName;
        if lSymbol.FileName = '' then
          lSymbol.FileName := aModel.FileName;
        lSymbol.EndLine := lDeclaration.TypeBodyEndLine;
        lSymbol.EndColumn := lDeclaration.TypeBodyEndColumn;
        AddInventorySymbol(lSymbols, lSymbol);
      end;
    end;

    for lMember in aModel.Members do
    begin
      lSymbol := Default(TDelphiSemanticInventorySymbol);
      lSymbol.Name := lMember.Name;
      lSymbol.SymbolClass := 'member';
      lSymbol.Kind := lMember.Kind;
      lSymbol.TypeName := lMember.TypeName;
      lSymbol.OwnerName := lMember.OwnerName;
      lSymbol.OwnerType := lMember.OwnerName;
      lSymbol.OwnerScopeId := lMember.OwnerScopeId;
      lSymbol.OwnerSymbolId := lMember.OwnerSymbolId;
      lSymbol.UnitName := aModel.UnitName;
      lSymbol.FileName := aModel.FileName;
      lSymbol.Line := lMember.Line;
      lSymbol.Column := lMember.Column;
      lSymbol.EndLine := lMember.Line;
      lSymbol.EndColumn := lMember.Column;
      lSymbol.IsDefault := lMember.IsDefault;
      lSymbol.IsIndexed := lMember.IsIndexed;
      if lMember.IsIndexed then
        lSymbol.IndexParameterCount := 1;
      AddInventorySymbol(lSymbols, lSymbol);
      // A routine-owned field has an AST owner even when the compatibility
      // source scanner cannot read an inline record declaration.
      if SameText(lMember.Kind, 'field') and (lMember.OwnerScopeId <> '') and
        (lMember.OwnerSymbolId <> '') and (lMember.FileName = '') and
        (lMember.Line > 0) and (lMember.Column > 0) then
      begin
        lSymbol.SymbolClass := 'field';
        AddInventorySymbol(lSymbols, lSymbol);
      end;
    end;

    for lRoutine in aModel.Routines do
    begin
      lSymbol := Default(TDelphiSemanticInventorySymbol);
      lSymbol.Name := lRoutine.Name;
      // Only an AST-proven body can own lexical declarations. Keep the other
      // declarations in inventory without letting them validate a scope chain.
      if IsVerifiedLexicalRoutineBody(aModel, lRoutine) then
        lSymbol.SymbolClass := 'routine'
      else if SameText(lRoutine.AstScopeKind, 'header') then
        lSymbol.SymbolClass := 'routine-header'
      else
        lSymbol.SymbolClass := 'routine-unverified';
      lSymbol.Kind := 'routine';
      lSymbol.TypeName := lRoutine.ReturnType;
      lSymbol.OwnerName := lRoutine.OwnerName;
      lSymbol.OwnerType := lRoutine.OwnerName;
      lSymbol.UnitName := aModel.UnitName;
      lSymbol.FileName := lRoutine.FileName;
      if lSymbol.FileName = '' then
        lSymbol.FileName := aModel.FileName;
      lSymbol.SectionKind := lRoutine.SectionKind;
      lSymbol.RoutineScopeId := lRoutine.ScopeId;
      lSymbol.ParentScopeId := lRoutine.ParentScopeId;
      lSymbol.Line := lRoutine.Line;
      lSymbol.Column := lRoutine.Column;
      lSymbol.EndLine := lRoutine.Line;
      lSymbol.EndColumn := lRoutine.Column;
      if lRoutine.EndLine > 0 then
      begin
        lSymbol.EndLine := lRoutine.EndLine;
        lSymbol.EndColumn := lRoutine.EndColumn;
      end;
      AddInventorySymbol(lSymbols, lSymbol);

      for lParameter in lRoutine.Parameters do
      begin
        lSymbol := Default(TDelphiSemanticInventorySymbol);
        lSymbol.Name := lParameter.Name;
        lSymbol.SymbolClass := 'parameter';
        lSymbol.Kind := 'parameter';
        lSymbol.TypeName := lParameter.TypeName;
        lSymbol.Modifier := lParameter.Modifier;
        if lRoutine.OwnerName <> '' then
          lSymbol.RoutineName := lRoutine.OwnerName + '.' + lParameter.RoutineName
        else
          lSymbol.RoutineName := lParameter.RoutineName;
        lSymbol.UnitName := aModel.UnitName;
        lSymbol.FileName := aModel.FileName;
        lSymbol.RoutineScopeId := lRoutine.ScopeId;
        lSymbol.Line := lParameter.Line;
        lSymbol.Column := lParameter.Column;
        lSymbol.EndLine := lParameter.Line;
        lSymbol.EndColumn := lParameter.Column;
        AddInventorySymbol(lSymbols, lSymbol);
      end;
    end;

    for lLocal in aModel.Locals do
    begin
      lSymbol := Default(TDelphiSemanticInventorySymbol);
      lSymbol.Name := lLocal.Name;
      lSymbol.SymbolClass := 'local';
      lSymbol.Kind := lLocal.Kind;
      lSymbol.TypeName := lLocal.TypeName;
      lSymbol.RoutineName := lLocal.RoutineName;
      lSymbol.RoutineScopeId := lLocal.RoutineScopeId;
      lSymbol.UnitName := aModel.UnitName;
      lSymbol.FileName := aModel.FileName;
      lSymbol.Line := lLocal.Line;
      lSymbol.Column := lLocal.Column;
      lSymbol.EndLine := lLocal.Line;
      lSymbol.EndColumn := lLocal.Column;
      AddInventorySymbol(lSymbols, lSymbol);
    end;

    lFirstTextIndex := lSymbols.Count;
    AddDakCompatibleInventorySymbols(aModel, lSymbols);
    AssignTextInventoryRoutineScopes(aModel, lSymbols, lFirstTextIndex);
    Result := lSymbols.ToArray;
  finally
    lSymbols.Free;
  end;
end;

end.
