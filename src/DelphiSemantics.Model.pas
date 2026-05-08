unit DelphiSemantics.Model;

interface

type
  TDelphiSemanticModelOptions = record
    SourceFileName: string;
    Defines: TArray<string>;
    SearchPaths: TArray<string>;
    ProjectContextApplied: Boolean;
  end;

  TDelphiSemanticModelDiagnostic = record
    Code: string;
    Message: string;
    FileName: string;
    Line: Integer;
  end;

  TDelphiSemanticDeclaration = record
    Name: string;
    Kind: string;
    TypeName: string;
    SectionKind: string;
    Line: Integer;
    Column: Integer;
  end;

  TDelphiSemanticMember = record
    OwnerName: string;
    Name: string;
    Kind: string;
    TypeName: string;
    Visibility: string;
    Line: Integer;
    Column: Integer;
  end;

  TDelphiSemanticParameter = record
    RoutineName: string;
    Name: string;
    TypeName: string;
    Modifier: string;
  end;

  TDelphiSemanticRoutine = record
    Name: string;
    OwnerName: string;
    SectionKind: string;
    Signature: string;
    ReturnType: string;
    Line: Integer;
    Column: Integer;
    Parameters: TArray<TDelphiSemanticParameter>;
  end;

  TDelphiSemanticLocal = record
    RoutineName: string;
    Name: string;
    Kind: string;
    TypeName: string;
    Line: Integer;
    Column: Integer;
  end;

  TDelphiSemanticReference = record
    Name: string;
    Line: Integer;
    Column: Integer;
  end;

  TDelphiSemanticWithStatement = record
    Line: Integer;
    Column: Integer;
    EndLine: Integer;
    EndColumn: Integer;
    SelectorText: string;
    Text: string;
  end;

  TDelphiSemanticUnitModel = record
    Success: Boolean;
    FileName: string;
    UnitName: string;
    EncodingName: string;
    InterfaceUses: TArray<string>;
    ImplementationUses: TArray<string>;
    Declarations: TArray<TDelphiSemanticDeclaration>;
    Members: TArray<TDelphiSemanticMember>;
    Routines: TArray<TDelphiSemanticRoutine>;
    Locals: TArray<TDelphiSemanticLocal>;
    References: TArray<TDelphiSemanticReference>;
    WithStatements: TArray<TDelphiSemanticWithStatement>;
    Diagnostics: TArray<TDelphiSemanticModelDiagnostic>;
  end;

  TDelphiSemanticUnitModelExtractor = record
  public
    class function ExtractFromFile(const aOptions: TDelphiSemanticModelOptions):
      TDelphiSemanticUnitModel; static;
  end;

implementation

uses
  System.Classes, System.Generics.Collections, System.IOUtils, System.RegularExpressions,
  System.StrUtils, System.SysUtils,
  DelphiSemantics.Preprocess, DelphiSemantics.Source;

procedure AddDiagnostic(const aDiagnostics: TList<TDelphiSemanticModelDiagnostic>;
  const aCode, aMessage, aFileName: string; const aLine: Integer);
var
  lDiagnostic: TDelphiSemanticModelDiagnostic;
begin
  lDiagnostic.Code := aCode;
  lDiagnostic.Message := aMessage;
  lDiagnostic.FileName := aFileName;
  lDiagnostic.Line := aLine;
  aDiagnostics.Add(lDiagnostic);
end;

procedure AddSourceDiagnostics(const aDiagnostics: TList<TDelphiSemanticModelDiagnostic>;
  const aSourceDiagnostics: TArray<TDelphiSemanticSourceDiagnostic>);
var
  lDiagnostic: TDelphiSemanticSourceDiagnostic;
begin
  for lDiagnostic in aSourceDiagnostics do
    AddDiagnostic(aDiagnostics, lDiagnostic.Code, lDiagnostic.Message, lDiagnostic.FileName, 0);
end;

procedure AddPreprocessDiagnostics(const aDiagnostics: TList<TDelphiSemanticModelDiagnostic>;
  const aPreprocessDiagnostics: TArray<TDelphiSemanticPreprocessDiagnostic>);
var
  lDiagnostic: TDelphiSemanticPreprocessDiagnostic;
begin
  for lDiagnostic in aPreprocessDiagnostics do
    AddDiagnostic(aDiagnostics, lDiagnostic.Code, lDiagnostic.Message, lDiagnostic.FileName,
      lDiagnostic.Line);
end;

function LineOfOffset(const aText: string; const aOffset: Integer): Integer;
var
  i: Integer;
begin
  Result := 1;
  for i := 1 to aOffset do
    if aText[i] = #10 then
      Inc(Result);
end;

function ColumnOfOffset(const aText: string; const aOffset: Integer): Integer;
var
  i: Integer;
begin
  Result := 1;
  i := aOffset;
  while (i > 1) and not CharInSet(aText[i - 1], [#10, #13]) do
  begin
    Inc(Result);
    Dec(i);
  end;
end;

function SectionForOffset(const aText: string; const aOffset: Integer): string;
var
  lImplementationPos: Integer;
begin
  lImplementationPos := Pos('implementation', LowerCase(aText));
  if (lImplementationPos > 0) and (aOffset > lImplementationPos) then
    Result := 'implementation'
  else
    Result := 'interface';
end;

function MatchGroupValue(const aMatch: TMatch; const aIndex: Integer): string;
begin
  if aIndex < aMatch.Groups.Count then
    Result := aMatch.Groups[aIndex].Value
  else
    Result := '';
end;

function SanitizeCodeText(const aText: string): string;
var
  i: Integer;
  lCommentMode: Integer;
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
      end else if aText[i] = '''' then
      begin
        sb.Append(' ');
        Inc(i);
        while i <= Length(aText) do
        begin
          if CharInSet(aText[i], [#10, #13]) then
            sb.Append(aText[i])
          else
            sb.Append(' ');
          if aText[i] = '''' then
          begin
            if (i < Length(aText)) and (aText[i + 1] = '''') then
            begin
              Inc(i);
              sb.Append(' ');
            end else
              Break;
          end;
          Inc(i);
        end;
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

procedure AddDeclaration(const aDeclarations: TList<TDelphiSemanticDeclaration>;
  const aName, aKind, aTypeName, aSection, aText: string; const aOffset: Integer);
var
  lDeclaration: TDelphiSemanticDeclaration;
begin
  lDeclaration.Name := aName;
  lDeclaration.Kind := aKind;
  lDeclaration.TypeName := aTypeName;
  lDeclaration.SectionKind := aSection;
  lDeclaration.Line := LineOfOffset(aText, aOffset);
  lDeclaration.Column := ColumnOfOffset(aText, aOffset);
  aDeclarations.Add(lDeclaration);
end;

procedure AddMember(const aMembers: TList<TDelphiSemanticMember>; const aOwnerName, aName, aKind,
  aTypeName, aVisibility, aText: string; const aOffset: Integer);
var
  lMember: TDelphiSemanticMember;
begin
  lMember.OwnerName := aOwnerName;
  lMember.Name := aName;
  lMember.Kind := aKind;
  lMember.TypeName := aTypeName;
  lMember.Visibility := aVisibility;
  lMember.Line := LineOfOffset(aText, aOffset);
  lMember.Column := ColumnOfOffset(aText, aOffset);
  aMembers.Add(lMember);
end;

procedure AddLocal(const aLocals: TList<TDelphiSemanticLocal>; const aRoutineName, aName, aKind,
  aTypeName, aText: string; const aOffset: Integer);
var
  lLocal: TDelphiSemanticLocal;
begin
  lLocal.RoutineName := aRoutineName;
  lLocal.Name := aName;
  lLocal.Kind := aKind;
  lLocal.TypeName := aTypeName;
  lLocal.Line := LineOfOffset(aText, aOffset);
  lLocal.Column := ColumnOfOffset(aText, aOffset);
  aLocals.Add(lLocal);
end;

procedure AddReference(const aReferences: TList<TDelphiSemanticReference>; const aName,
  aText: string; const aOffset: Integer);
var
  lReference: TDelphiSemanticReference;
begin
  lReference.Name := aName;
  lReference.Line := LineOfOffset(aText, aOffset);
  lReference.Column := ColumnOfOffset(aText, aOffset);
  aReferences.Add(lReference);
end;

procedure AddUses(const aList: TList<string>; const aUsesText: string);
var
  lPart: string;
begin
  for lPart in aUsesText.Split([',']) do
    if lPart.Trim <> '' then
      aList.Add(lPart.Trim);
end;

procedure ExtractUses(const aText: string; const aInterfaceUses, aImplementationUses: TList<string>);
var
  lImplementationPos: Integer;
  lMatch: TMatch;
  lSection: string;
begin
  lImplementationPos := Pos('implementation', LowerCase(aText));
  lMatch := TRegEx.Match(aText, '\buses\s+(.*?);', [roIgnoreCase, roSingleLine]);
  while lMatch.Success do
  begin
    if (lImplementationPos > 0) and (lMatch.Index + 1 > lImplementationPos) then
      lSection := 'implementation'
    else
      lSection := 'interface';

    if lSection = 'interface' then
      AddUses(aInterfaceUses, lMatch.Groups[1].Value)
    else
      AddUses(aImplementationUses, lMatch.Groups[1].Value);
    lMatch := lMatch.NextMatch;
  end;
end;

function NormalizeTypeName(const aTypeName: string): string;
begin
  Result := aTypeName.Trim;
  if StartsText('(', Result) then
    Result := 'enum'
  else if StartsText('class', Result) or ContainsText(Result, ' class') then
    Result := 'class'
  else if StartsText('record', Result) or ContainsText(Result, ' record') then
    Result := 'record';
end;

procedure ExtractEnumValues(const aText: string; const aDeclarations: TList<TDelphiSemanticDeclaration>;
  const aOwnerName, aEnumText, aSection: string; const aOffset: Integer);
var
  lEnumMatch: TMatch;
  lEnumPart: string;
begin
  lEnumMatch := TRegEx.Match(aEnumText, '\((.*?)\)', [roSingleLine]);
  if not lEnumMatch.Success then
    Exit;

  for lEnumPart in lEnumMatch.Groups[1].Value.Split([',']) do
    if lEnumPart.Trim <> '' then
      AddDeclaration(aDeclarations, lEnumPart.Trim, 'enum-value', aOwnerName, aSection, aText,
        aOffset);
end;

procedure ExtractTypeDeclarations(const aText: string;
  const aDeclarations: TList<TDelphiSemanticDeclaration>);
var
  i: Integer;
  lBlockKind: string;
  lInImplementation: Boolean;
  lInRoutine: Boolean;
  lLine: string;
  lLines: TStringList;
  lMatch: TMatch;
  lName: string;
  lOffset: Integer;
  lSection: string;
  lTypeName: string;
  lTypeDepth: Integer;
begin
  lLines := TStringList.Create;
  try
    lLines.Text := aText;
    lBlockKind := '';
    lInImplementation := False;
    lInRoutine := False;
    lOffset := 0;
    lTypeDepth := 0;
    for i := 0 to Pred(lLines.Count) do
    begin
      lLine := lLines[i].Trim;
      if (lTypeDepth > 0) and SameText(lLine, 'end;') then
      begin
        Dec(lTypeDepth);
      end else if SameText(lLine, 'implementation') then
      begin
        lInImplementation := True;
        lBlockKind := '';
      end else if SameText(lLine, 'interface') then
      begin
        lInImplementation := False;
        lBlockKind := '';
      end else if (lTypeDepth = 0) and
        (StartsText('procedure ', lLine) or StartsText('function ', lLine)) then
      begin
        lBlockKind := '';
        if lInImplementation then
          lInRoutine := True;
      end else if lInRoutine and SameText(lLine, 'end;') then
      begin
        lInRoutine := False;
      end else if not lInRoutine then
      begin
        if SameText(lLine, 'type') then
          lBlockKind := 'type'
        else if SameText(lLine, 'const') or SameText(lLine, 'var') then
          lBlockKind := ''
        else if lBlockKind = 'type' then
        begin
          lMatch := TRegEx.Match(lLine, '^([A-Za-z_][A-Za-z0-9_]*)\s*=\s*([^;\r\n]+)',
            [roIgnoreCase]);
          if lMatch.Success then
          begin
            lName := lMatch.Groups[1].Value;
            lTypeName := NormalizeTypeName(lMatch.Groups[2].Value);
            lSection := SectionForOffset(aText, lOffset + 1);
            if not SameText(lName, 'Result') then
            begin
              if MatchText(lTypeName, ['enum', 'class', 'record']) then
                AddDeclaration(aDeclarations, lName, 'type', lTypeName, lSection, aText,
                  lOffset + 1)
              else
                AddDeclaration(aDeclarations, lName, 'type-alias', lTypeName, lSection, aText,
                  lOffset + 1);
            end;

            if lTypeName = 'enum' then
              ExtractEnumValues(aText, aDeclarations, lName, lMatch.Groups[2].Value, lSection,
                lOffset + 1)
            else if MatchText(lTypeName, ['class', 'record']) and
              not ContainsText(lLine, ' end') then
              Inc(lTypeDepth);
          end;
        end;
      end;
      Inc(lOffset, Length(lLines[i]) + Length(sLineBreak));
    end;
  finally
    lLines.Free;
  end;
end;

procedure ExtractConstVarDeclarations(const aText: string;
  const aDeclarations: TList<TDelphiSemanticDeclaration>);
var
  i: Integer;
  lBlockKind: string;
  lInImplementation: Boolean;
  lInRoutine: Boolean;
  lLine: string;
  lLines: TStringList;
  lMatch: TMatch;
  lOffset: Integer;
  lSection: string;
begin
  lLines := TStringList.Create;
  try
    lLines.Text := aText;
    lBlockKind := '';
    lInImplementation := False;
    lInRoutine := False;
    lOffset := 0;
    for i := 0 to Pred(lLines.Count) do
    begin
      lLine := lLines[i].Trim;
      if SameText(lLine, 'implementation') then
      begin
        lInImplementation := True;
        lBlockKind := '';
      end else if SameText(lLine, 'interface') then
      begin
        lInImplementation := False;
        lBlockKind := '';
      end else if StartsText('procedure ', lLine) or StartsText('function ', lLine) then
      begin
        lBlockKind := '';
        if lInImplementation then
          lInRoutine := True;
      end else if lInRoutine and SameText(lLine, 'end;') then
      begin
        lInRoutine := False;
      end else if not lInRoutine then
      begin
        if SameText(lLine, 'const') then
          lBlockKind := 'const'
        else if SameText(lLine, 'var') then
          lBlockKind := 'var'
        else if SameText(lLine, 'type') then
          lBlockKind := ''
        else if lBlockKind = 'const' then
        begin
          lMatch := TRegEx.Match(lLine, '^([A-Za-z_][A-Za-z0-9_]*)\s*(?::\s*([^=]+?))?\s*=',
            [roIgnoreCase]);
          if lMatch.Success then
          begin
            lSection := SectionForOffset(aText, lOffset + 1);
            AddDeclaration(aDeclarations, lMatch.Groups[1].Value, 'const',
              MatchGroupValue(lMatch, 2).Trim, lSection, aText, lOffset + 1);
          end;
        end else if lBlockKind = 'var' then
        begin
          lMatch := TRegEx.Match(lLine, '^([A-Za-z_][A-Za-z0-9_]*)\s*:\s*([^;]+);',
            [roIgnoreCase]);
          if lMatch.Success then
          begin
            lSection := SectionForOffset(aText, lOffset + 1);
            AddDeclaration(aDeclarations, lMatch.Groups[1].Value, 'var',
              lMatch.Groups[2].Value.Trim, lSection, aText, lOffset + 1);
          end;
        end;
      end;
      Inc(lOffset, Length(lLines[i]) + Length(sLineBreak));
    end;
  finally
    lLines.Free;
  end;
end;

procedure ExtractMembersFromBody(const aText, aOwnerName, aBody: string; const aBodyOffset: Integer;
  const aMembers: TList<TDelphiSemanticMember>);
var
  i: Integer;
  lFieldMatch: TMatch;
  lLine: string;
  lLines: TStringList;
  lMethodMatch: TMatch;
  lOffset: Integer;
  lPropertyMatch: TMatch;
  lVisibility: string;
begin
  lLines := TStringList.Create;
  try
    lLines.Text := aBody;
    lOffset := aBodyOffset;
    lVisibility := '';
    for i := 0 to Pred(lLines.Count) do
    begin
      lLine := lLines[i].Trim;
      if MatchText(lLine, ['private', 'protected', 'public', 'published', 'strict private',
        'strict protected']) then
      begin
        lVisibility := lLine;
      end else if lLine <> '' then
      begin
        lPropertyMatch := TRegEx.Match(lLine, '^property\s+([A-Za-z_][A-Za-z0-9_]*)\s*:\s*([^;]+)',
          [roIgnoreCase]);
        if lPropertyMatch.Success then
        begin
          AddMember(aMembers, aOwnerName, lPropertyMatch.Groups[1].Value, 'property',
            lPropertyMatch.Groups[2].Value.Trim.Split([' '])[0], lVisibility, aText, lOffset + 1);
        end else
        begin
          lMethodMatch := TRegEx.Match(lLine, '^(procedure|function)\s+([A-Za-z_][A-Za-z0-9_]*)',
            [roIgnoreCase]);
          if lMethodMatch.Success then
          begin
            AddMember(aMembers, aOwnerName, lMethodMatch.Groups[2].Value,
              LowerCase(lMethodMatch.Groups[1].Value), '', lVisibility, aText, lOffset + 1);
          end else
          begin
            lFieldMatch := TRegEx.Match(lLine, '^([A-Za-z_][A-Za-z0-9_]*)\s*:\s*([^;]+);',
              [roIgnoreCase]);
            if lFieldMatch.Success then
              AddMember(aMembers, aOwnerName, lFieldMatch.Groups[1].Value, 'field',
                lFieldMatch.Groups[2].Value.Trim, lVisibility, aText, lOffset + 1);
          end;
        end;
      end;
      Inc(lOffset, Length(lLines[i]) + Length(sLineBreak));
    end;
  finally
    lLines.Free;
  end;
end;

procedure ExtractMembers(const aText: string; const aMembers: TList<TDelphiSemanticMember>);
var
  lMatch: TMatch;
begin
  lMatch := TRegEx.Match(aText,
    '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(class|record)\b(.*?)^\s*end\s*;',
    [roIgnoreCase, roMultiLine, roSingleLine]);
  while lMatch.Success do
  begin
    ExtractMembersFromBody(aText, lMatch.Groups[1].Value, lMatch.Groups[3].Value,
      lMatch.Groups[3].Index, aMembers);
    lMatch := lMatch.NextMatch;
  end;
end;

procedure AddRoutineParameter(const aParameters: TList<TDelphiSemanticParameter>;
  const aRoutineName, aName, aTypeName, aModifier: string);
var
  lParameter: TDelphiSemanticParameter;
begin
  lParameter.RoutineName := aRoutineName;
  lParameter.Name := aName;
  lParameter.TypeName := aTypeName;
  lParameter.Modifier := aModifier;
  aParameters.Add(lParameter);
end;

function ParseParameters(const aRoutineName, aParameterText: string):
  TArray<TDelphiSemanticParameter>;
var
  lMatch: TMatch;
  lName: string;
  lNames: string;
  lParameter: string;
  lParameters: TList<TDelphiSemanticParameter>;
  lText: string;
begin
  lParameters := TList<TDelphiSemanticParameter>.Create;
  try
    lText := aParameterText.Trim;
    if (Length(lText) >= 2) and (lText[1] = '(') and (lText[Length(lText)] = ')') then
      lText := Copy(lText, 2, Length(lText) - 2);

    for lParameter in lText.Split([';']) do
    begin
      lMatch := TRegEx.Match(lParameter.Trim,
        '^(?:(const|var|out)\s+)?([A-Za-z_][A-Za-z0-9_,\s]*)\s*:\s*(.+)$',
        [roIgnoreCase]);
      if lMatch.Success then
      begin
        lNames := lMatch.Groups[2].Value;
        for lName in lNames.Split([',']) do
          if lName.Trim <> '' then
            AddRoutineParameter(lParameters, aRoutineName, lName.Trim, lMatch.Groups[3].Value.Trim,
              lMatch.Groups[1].Value.Trim);
      end;
    end;

    Result := lParameters.ToArray;
  finally
    lParameters.Free;
  end;
end;

procedure AddRoutine(const aRoutines: TList<TDelphiSemanticRoutine>; const aName, aOwnerName,
  aSection, aSignature, aReturnType, aText: string; const aOffset: Integer);
var
  lRoutine: TDelphiSemanticRoutine;
begin
  lRoutine.Name := aName;
  lRoutine.OwnerName := aOwnerName;
  lRoutine.SectionKind := aSection;
  lRoutine.Signature := aSignature;
  lRoutine.ReturnType := aReturnType.Trim;
  lRoutine.Line := LineOfOffset(aText, aOffset);
  lRoutine.Column := ColumnOfOffset(aText, aOffset);
  lRoutine.Parameters := ParseParameters(aName, aSignature);
  aRoutines.Add(lRoutine);
end;

function IsOffsetInsideTypeBlock(const aText: string; const aOffset: Integer): Boolean;
var
  i: Integer;
  lBlockKind: string;
  lLine: string;
  lLines: TStringList;
  lOffset: Integer;
  lTypeDepth: Integer;
  lTypeMatch: TMatch;
  lTypeName: string;
begin
  lLines := TStringList.Create;
  try
    lLines.Text := aText;
    lBlockKind := '';
    lOffset := 0;
    lTypeDepth := 0;
    for i := 0 to Pred(lLines.Count) do
    begin
      lLine := lLines[i].Trim;
      if (aOffset >= lOffset + 1) and (aOffset <= lOffset + Length(lLines[i]) + 1) then
        Exit(lTypeDepth > 0);

      if (lTypeDepth > 0) and SameText(lLine, 'end;') then
      begin
        Dec(lTypeDepth);
      end else if SameText(lLine, 'interface') or SameText(lLine, 'implementation') then
      begin
        lBlockKind := '';
        lTypeDepth := 0;
      end else if SameText(lLine, 'type') then
      begin
        lBlockKind := 'type';
      end else if SameText(lLine, 'const') or SameText(lLine, 'var') then
      begin
        lBlockKind := '';
      end else if lBlockKind = 'type' then
      begin
        lTypeMatch := TRegEx.Match(lLine, '^([A-Za-z_][A-Za-z0-9_]*)\s*=\s*([^;\r\n]+)',
          [roIgnoreCase]);
        if lTypeMatch.Success then
        begin
          lTypeName := NormalizeTypeName(lTypeMatch.Groups[2].Value);
          if MatchText(lTypeName, ['class', 'record']) and not ContainsText(lLine, ' end') then
            Inc(lTypeDepth);
        end;
      end;

      Inc(lOffset, Length(lLines[i]) + Length(sLineBreak));
    end;
    Result := False;
  finally
    lLines.Free;
  end;
end;

procedure ExtractRoutines(const aText: string; const aDeclarations: TList<TDelphiSemanticDeclaration>;
  const aRoutines: TList<TDelphiSemanticRoutine>);
var
  lMatch: TMatch;
  lOwnerName: string;
  lPrefix: string;
  lRoutineName: string;
  lSection: string;
begin
  lMatch := TRegEx.Match(aText,
    '^\s*(procedure|function)\s+((?:[A-Za-z_][A-Za-z0-9_]*\.)?)([A-Za-z_][A-Za-z0-9_]*)\s*' +
    '(\([^;\r\n]*\))?\s*(?::\s*([^;\r\n]+))?\s*;',
    [roIgnoreCase, roMultiLine]);
  while lMatch.Success do
  begin
    if IsOffsetInsideTypeBlock(aText, lMatch.Index + 1) then
    begin
      lMatch := lMatch.NextMatch;
      Continue;
    end;

    lPrefix := lMatch.Groups[2].Value;
    lRoutineName := lMatch.Groups[3].Value;
    lOwnerName := lPrefix.Trim;
    if EndsText('.', lOwnerName) then
      lOwnerName := Copy(lOwnerName, 1, Length(lOwnerName) - 1);
    lSection := SectionForOffset(aText, lMatch.Index + 1);
    AddRoutine(aRoutines, lRoutineName, lOwnerName, lSection, MatchGroupValue(lMatch, 4),
      MatchGroupValue(lMatch, 5), aText, lMatch.Index + 1);
    if lOwnerName = '' then
      AddDeclaration(aDeclarations, lRoutineName, 'routine', '', lSection, aText,
        lMatch.Index + 1);
    lMatch := lMatch.NextMatch;
  end;
end;

procedure ExtractLocalsFromRoutine(const aText, aRoutineName, aRoutineText: string;
  const aRoutineOffset: Integer; const aLocals: TList<TDelphiSemanticLocal>);
var
  i: Integer;
  lInVarSection: Boolean;
  lLine: string;
  lLines: TStringList;
  lLocalMatch: TMatch;
  lOffset: Integer;
begin
  lLines := TStringList.Create;
  try
    lLines.Text := aRoutineText;
    lOffset := aRoutineOffset;
    lInVarSection := False;
    for i := 0 to Pred(lLines.Count) do
    begin
      lLine := lLines[i].Trim;
      if SameText(lLine, 'var') then
        lInVarSection := True
      else if SameText(lLine, 'begin') then
        Break
      else if lInVarSection then
      begin
        lLocalMatch := TRegEx.Match(lLine, '^([A-Za-z_][A-Za-z0-9_]*)\s*:\s*([^;]+);',
          [roIgnoreCase]);
        if lLocalMatch.Success then
          AddLocal(aLocals, aRoutineName, lLocalMatch.Groups[1].Value, 'var',
            lLocalMatch.Groups[2].Value.Trim, aText, lOffset + 1);
      end;
      Inc(lOffset, Length(lLines[i]) + Length(sLineBreak));
    end;
  finally
    lLines.Free;
  end;
end;

function IsReferenceKeyword(const aName: string): Boolean;
begin
  Result := MatchText(aName, ['begin', 'case', 'class', 'const', 'do', 'else', 'end', 'for',
    'function', 'if', 'implementation', 'interface', 'not', 'of', 'or', 'procedure', 'program',
    'record', 'repeat', 'then', 'type', 'unit', 'until', 'uses', 'var', 'while', 'with']);
end;

procedure ExtractReferencesFromBody(const aText, aBody: string; const aBodyOffset: Integer;
  const aReferences: TList<TDelphiSemanticReference>);
var
  lCleanBody: string;
  lMatch: TMatch;
begin
  lCleanBody := SanitizeCodeText(aBody);
  lMatch := TRegEx.Match(lCleanBody, '\b[A-Za-z_][A-Za-z0-9_]*\b', [roIgnoreCase]);
  while lMatch.Success do
  begin
    if not IsReferenceKeyword(lMatch.Value) then
      AddReference(aReferences, lMatch.Value, aText, aBodyOffset + lMatch.Index + 1);
    lMatch := lMatch.NextMatch;
  end;
end;

procedure ExtractRoutineBodies(const aText: string; const aLocals: TList<TDelphiSemanticLocal>;
  const aReferences: TList<TDelphiSemanticReference>);
var
  i: Integer;
  lBodyBegin: Integer;
  lBodyOffset: Integer;
  lEndOffset: Integer;
  lMatch: TMatch;
  lNames: TList<string>;
  lRoutineText: string;
  lStarts: TList<Integer>;
begin
  lNames := nil;
  lStarts := nil;
  try
    lNames := TList<string>.Create;
    lStarts := TList<Integer>.Create;
    lMatch := TRegEx.Match(aText,
      '^\s*(?:procedure|function)\s+(?:[A-Za-z_][A-Za-z0-9_]*\.)?([A-Za-z_][A-Za-z0-9_]*)' +
      '[^;]*;',
      [roIgnoreCase, roMultiLine]);
    while lMatch.Success do
    begin
      lNames.Add(lMatch.Groups[1].Value);
      lStarts.Add(lMatch.Index);
      lMatch := lMatch.NextMatch;
    end;

    for i := 0 to Pred(lStarts.Count) do
    begin
      if i < Pred(lStarts.Count) then
        lEndOffset := lStarts[i + 1]
      else
        lEndOffset := Length(aText);

      lRoutineText := Copy(aText, lStarts[i] + 1, lEndOffset - lStarts[i]);
      ExtractLocalsFromRoutine(aText, lNames[i], lRoutineText, lStarts[i], aLocals);
      lBodyBegin := Pos('begin', LowerCase(lRoutineText));
      if lBodyBegin > 0 then
      begin
        lBodyOffset := lStarts[i] + lBodyBegin - 1;
        ExtractReferencesFromBody(aText, Copy(lRoutineText, lBodyBegin, MaxInt), lBodyOffset,
          aReferences);
      end;
    end;
  finally
    lStarts.Free;
    lNames.Free;
  end;
end;

function FindWithStatementEndOffset(const aText: string; const aBodyStartOffset: Integer): Integer;
var
  i: Integer;
  lBlockDepth: Integer;
  lCommentMode: Integer;
  lToken: string;
begin
  Result := aBodyStartOffset;
  if (aBodyStartOffset < 1) or (aBodyStartOffset > Length(aText)) then
    Exit(Length(aText));

  lBlockDepth := 0;
  lCommentMode := 0;
  i := aBodyStartOffset;
  while i <= Length(aText) do
  begin
    if lCommentMode = 1 then
    begin
      if (aText[i] = '*') and (i < Length(aText)) and (aText[i + 1] = ')') then
      begin
        lCommentMode := 0;
        Inc(i);
      end;
    end else if lCommentMode = 2 then
    begin
      if aText[i] = '}' then
        lCommentMode := 0;
    end else if lCommentMode = 3 then
    begin
      if CharInSet(aText[i], [#10, #13]) then
        lCommentMode := 0;
    end else if aText[i] = '''' then
    begin
      Inc(i);
      while i <= Length(aText) do
      begin
        if aText[i] = '''' then
        begin
          if (i < Length(aText)) and (aText[i + 1] = '''') then
            Inc(i)
          else
            Break;
        end;
        Inc(i);
      end;
    end else if (aText[i] = '(') and (i < Length(aText)) and (aText[i + 1] = '*') then
    begin
      lCommentMode := 1;
      Inc(i);
    end else if aText[i] = '{' then
    begin
      lCommentMode := 2;
    end else if (aText[i] = '/') and (i < Length(aText)) and (aText[i + 1] = '/') then
    begin
      lCommentMode := 3;
      Inc(i);
    end else if CharInSet(aText[i], ['A'..'Z', 'a'..'z', '_']) then
    begin
      lToken := '';
      while (i <= Length(aText)) and CharInSet(aText[i], ['A'..'Z', 'a'..'z', '0'..'9', '_']) do
      begin
        lToken := lToken + aText[i];
        Inc(i);
      end;
      Dec(i);
      if SameText(lToken, 'begin') then
      begin
        Inc(lBlockDepth);
      end else if SameText(lToken, 'end') then
      begin
        if lBlockDepth > 0 then
          Dec(lBlockDepth);
        if lBlockDepth = 0 then
        begin
          while (i <= Length(aText)) and (aText[i] <> ';') do
            Inc(i);
          if i <= Length(aText) then
            Exit(i);
          Exit(Length(aText));
        end;
      end;
    end else if (aText[i] = ';') and (lBlockDepth = 0) then
      Exit(i);
    Inc(i);
  end;

  Result := Length(aText);
end;

procedure ExtractWithStatements(const aText: string; const aItems: TList<TDelphiSemanticWithStatement>);
var
  lCleanText: string;
  lEndOffset: Integer;
  lItem: TDelphiSemanticWithStatement;
  lMatch: TMatch;
begin
  lCleanText := SanitizeCodeText(aText);
  lMatch := TRegEx.Match(lCleanText, '\bwith\b\s+(.*?)\s+\bdo\b', [roIgnoreCase, roSingleLine]);
  while lMatch.Success do
  begin
    lEndOffset := FindWithStatementEndOffset(aText, lMatch.Index + lMatch.Length + 1);
    lItem.Line := LineOfOffset(aText, lMatch.Index + 1);
    lItem.Column := ColumnOfOffset(aText, lMatch.Index + 1);
    lItem.EndLine := LineOfOffset(aText, lEndOffset);
    lItem.EndColumn := ColumnOfOffset(aText, lEndOffset);
    lItem.SelectorText := lMatch.Groups[1].Value.Trim;
    lItem.Text := Copy(aText, lMatch.Index + 1, lEndOffset - lMatch.Index);
    aItems.Add(lItem);
    lMatch := lMatch.NextMatch;
  end;
end;

procedure ReconcileDeclarationCoordinates(const aSourceText: string;
  const aDeclarations: TList<TDelphiSemanticDeclaration>);
var
  i: Integer;
  lBestColumn: Integer;
  lBestDistance: Integer;
  lBestLine: Integer;
  lCandidateColumn: Integer;
  lCandidateDistance: Integer;
  lCandidateLine: Integer;
  lDeclaration: TDelphiSemanticDeclaration;
  lMatch: TMatch;
begin
  for i := 0 to Pred(aDeclarations.Count) do
  begin
    lDeclaration := aDeclarations[i];
    lBestColumn := 0;
    lBestDistance := MaxInt;
    lBestLine := 0;
    lMatch := TRegEx.Match(aSourceText, '^\s*' + TRegEx.Escape(lDeclaration.Name) + '\b',
      [roIgnoreCase, roMultiLine]);
    while lMatch.Success do
    begin
      lCandidateLine := LineOfOffset(aSourceText, lMatch.Index + 1);
      lCandidateColumn := ColumnOfOffset(aSourceText, lMatch.Index + 1);
      lCandidateDistance := Abs(lCandidateLine - lDeclaration.Line);
      if lCandidateDistance < lBestDistance then
      begin
        lBestDistance := lCandidateDistance;
        lBestLine := lCandidateLine;
        lBestColumn := lCandidateColumn;
      end;
      lMatch := lMatch.NextMatch;
    end;
    if lBestLine > 0 then
    begin
      lDeclaration.Line := lBestLine;
      lDeclaration.Column := lBestColumn;
      aDeclarations[i] := lDeclaration;
    end;
  end;
end;

procedure ReconcileWithStatementCoordinates(const aSourceText: string;
  const aWithStatements: TList<TDelphiSemanticWithStatement>);
var
  lBestDistance: Integer;
  lBestIndex: Integer;
  lCandidateDistance: Integer;
  i: Integer;
  j: Integer;
  lItem: TDelphiSemanticWithStatement;
  lRootStatements: TList<TDelphiSemanticWithStatement>;
begin
  lRootStatements := TList<TDelphiSemanticWithStatement>.Create;
  try
    ExtractWithStatements(aSourceText, lRootStatements);
    for i := 0 to Pred(aWithStatements.Count) do
    begin
      lItem := aWithStatements[i];
      lBestDistance := MaxInt;
      lBestIndex := -1;
      for j := 0 to Pred(lRootStatements.Count) do
      begin
        if SameText(lRootStatements[j].SelectorText, lItem.SelectorText) then
        begin
          lCandidateDistance := Abs(lRootStatements[j].Line - lItem.Line);
          if lCandidateDistance < lBestDistance then
          begin
            lBestDistance := lCandidateDistance;
            lBestIndex := j;
          end;
        end;
      end;
      if lBestIndex >= 0 then
      begin
        aWithStatements[i] := lRootStatements[lBestIndex];
        lRootStatements.Delete(lBestIndex);
      end;
    end;
  finally
    lRootStatements.Free;
  end;
end;

procedure ReconcileReferencesCoordinates(const aSourceText: string;
  const aReferences: TList<TDelphiSemanticReference>);
var
  i: Integer;
  lBestColumn: Integer;
  lBestDistance: Integer;
  lBestLine: Integer;
  lCandidateColumn: Integer;
  lCandidateDistance: Integer;
  lCandidateLine: Integer;
  lCleanText: string;
  lMatch: TMatch;
  lReference: TDelphiSemanticReference;
begin
  lCleanText := SanitizeCodeText(aSourceText);
  for i := 0 to Pred(aReferences.Count) do
  begin
    lReference := aReferences[i];
    lBestColumn := 0;
    lBestDistance := MaxInt;
    lBestLine := 0;
    lMatch := TRegEx.Match(lCleanText, '\b' + TRegEx.Escape(lReference.Name) + '\b',
      [roIgnoreCase]);
    while lMatch.Success do
    begin
      lCandidateLine := LineOfOffset(lCleanText, lMatch.Index + 1);
      lCandidateColumn := ColumnOfOffset(lCleanText, lMatch.Index + 1);
      lCandidateDistance := Abs(lCandidateLine - lReference.Line);
      if lCandidateDistance < lBestDistance then
      begin
        lBestDistance := lCandidateDistance;
        lBestLine := lCandidateLine;
        lBestColumn := lCandidateColumn;
      end;
      lMatch := lMatch.NextMatch;
    end;
    if lBestLine > 0 then
    begin
      lReference.Line := lBestLine;
      lReference.Column := lBestColumn;
      aReferences[i] := lReference;
    end;
  end;
end;

procedure ReconcileMemberCoordinates(const aSourceText: string;
  const aMembers: TList<TDelphiSemanticMember>);
var
  i: Integer;
  lBestColumn: Integer;
  lBestDistance: Integer;
  lBestLine: Integer;
  lCandidateColumn: Integer;
  lCandidateDistance: Integer;
  lCandidateLine: Integer;
  lCleanText: string;
  lMatch: TMatch;
  lMember: TDelphiSemanticMember;
begin
  lCleanText := SanitizeCodeText(aSourceText);
  for i := 0 to Pred(aMembers.Count) do
  begin
    lMember := aMembers[i];
    lBestColumn := 0;
    lBestDistance := MaxInt;
    lBestLine := 0;
    lMatch := TRegEx.Match(lCleanText, '^\s*' + TRegEx.Escape(lMember.Name) + '\b',
      [roIgnoreCase, roMultiLine]);
    while lMatch.Success do
    begin
      lCandidateLine := LineOfOffset(lCleanText, lMatch.Index + 1);
      lCandidateColumn := ColumnOfOffset(lCleanText, lMatch.Index + 1);
      lCandidateDistance := Abs(lCandidateLine - lMember.Line);
      if lCandidateDistance < lBestDistance then
      begin
        lBestDistance := lCandidateDistance;
        lBestLine := lCandidateLine;
        lBestColumn := lCandidateColumn;
      end;
      lMatch := lMatch.NextMatch;
    end;
    if lBestLine > 0 then
    begin
      lMember.Line := lBestLine;
      lMember.Column := lBestColumn;
      aMembers[i] := lMember;
    end;
  end;
end;

procedure ReconcileRoutineCoordinates(const aSourceText: string;
  const aRoutines: TList<TDelphiSemanticRoutine>);
var
  i: Integer;
  lBestColumn: Integer;
  lBestDistance: Integer;
  lBestLine: Integer;
  lCandidateColumn: Integer;
  lCandidateDistance: Integer;
  lCandidateLine: Integer;
  lCleanText: string;
  lMatch: TMatch;
  lRoutine: TDelphiSemanticRoutine;
begin
  lCleanText := SanitizeCodeText(aSourceText);
  for i := 0 to Pred(aRoutines.Count) do
  begin
    lRoutine := aRoutines[i];
    lBestColumn := 0;
    lBestDistance := MaxInt;
    lBestLine := 0;
    lMatch := TRegEx.Match(lCleanText, '^\s*(procedure|function)\s+(?:[A-Za-z_][A-Za-z0-9_]*\.)?' +
      TRegEx.Escape(lRoutine.Name) + '\b', [roIgnoreCase, roMultiLine]);
    while lMatch.Success do
    begin
      lCandidateLine := LineOfOffset(lCleanText, lMatch.Index + 1);
      lCandidateColumn := ColumnOfOffset(lCleanText, lMatch.Index + 1);
      lCandidateDistance := Abs(lCandidateLine - lRoutine.Line);
      if lCandidateDistance < lBestDistance then
      begin
        lBestDistance := lCandidateDistance;
        lBestLine := lCandidateLine;
        lBestColumn := lCandidateColumn;
      end;
      lMatch := lMatch.NextMatch;
    end;
    if lBestLine > 0 then
    begin
      lRoutine.Line := lBestLine;
      lRoutine.Column := lBestColumn;
      aRoutines[i] := lRoutine;
    end;
  end;
end;

procedure ReconcileLocalCoordinates(const aSourceText: string;
  const aLocals: TList<TDelphiSemanticLocal>);
var
  i: Integer;
  lBestColumn: Integer;
  lBestDistance: Integer;
  lBestLine: Integer;
  lCandidateColumn: Integer;
  lCandidateDistance: Integer;
  lCandidateLine: Integer;
  lCleanText: string;
  lLocal: TDelphiSemanticLocal;
  lMatch: TMatch;
begin
  lCleanText := SanitizeCodeText(aSourceText);
  for i := 0 to Pred(aLocals.Count) do
  begin
    lLocal := aLocals[i];
    lBestColumn := 0;
    lBestDistance := MaxInt;
    lBestLine := 0;
    lMatch := TRegEx.Match(lCleanText, '^\s*' + TRegEx.Escape(lLocal.Name) + '\b\s*:',
      [roIgnoreCase, roMultiLine]);
    while lMatch.Success do
    begin
      lCandidateLine := LineOfOffset(lCleanText, lMatch.Index + 1);
      lCandidateColumn := ColumnOfOffset(lCleanText, lMatch.Index + 1);
      lCandidateDistance := Abs(lCandidateLine - lLocal.Line);
      if lCandidateDistance < lBestDistance then
      begin
        lBestDistance := lCandidateDistance;
        lBestLine := lCandidateLine;
        lBestColumn := lCandidateColumn;
      end;
      lMatch := lMatch.NextMatch;
    end;
    if lBestLine > 0 then
    begin
      lLocal.Line := lBestLine;
      lLocal.Column := lBestColumn;
      aLocals[i] := lLocal;
    end;
  end;
end;

procedure AssignModelArrays(var aModel: TDelphiSemanticUnitModel;
  const aDiagnostics: TList<TDelphiSemanticModelDiagnostic>; const aInterfaceUses,
  aImplementationUses: TList<string>; const aDeclarations: TList<TDelphiSemanticDeclaration>;
  const aMembers: TList<TDelphiSemanticMember>; const aRoutines: TList<TDelphiSemanticRoutine>;
  const aLocals: TList<TDelphiSemanticLocal>; const aReferences: TList<TDelphiSemanticReference>;
  const aWithStatements: TList<TDelphiSemanticWithStatement>);
begin
  aModel.InterfaceUses := aInterfaceUses.ToArray;
  aModel.ImplementationUses := aImplementationUses.ToArray;
  aModel.Declarations := aDeclarations.ToArray;
  aModel.Members := aMembers.ToArray;
  aModel.Routines := aRoutines.ToArray;
  aModel.Locals := aLocals.ToArray;
  aModel.References := aReferences.ToArray;
  aModel.WithStatements := aWithStatements.ToArray;
  aModel.Diagnostics := aDiagnostics.ToArray;
end;

class function TDelphiSemanticUnitModelExtractor.ExtractFromFile(
  const aOptions: TDelphiSemanticModelOptions): TDelphiSemanticUnitModel;
var
  lDeclarations: TList<TDelphiSemanticDeclaration>;
  lDiagnostics: TList<TDelphiSemanticModelDiagnostic>;
  lImplementationUses: TList<string>;
  lInterfaceUses: TList<string>;
  lLocals: TList<TDelphiSemanticLocal>;
  lMatch: TMatch;
  lMembers: TList<TDelphiSemanticMember>;
  lPreprocessOptions: TDelphiSemanticPreprocessOptions;
  lPreprocessResult: TDelphiSemanticPreprocessResult;
  lReferences: TList<TDelphiSemanticReference>;
  lRoutines: TList<TDelphiSemanticRoutine>;
  lSourceResult: TDelphiSemanticSourceLoadResult;
  lText: string;
  lWithStatements: TList<TDelphiSemanticWithStatement>;
begin
  lDiagnostics := nil;
  lInterfaceUses := nil;
  lImplementationUses := nil;
  lDeclarations := nil;
  lMembers := nil;
  lRoutines := nil;
  lLocals := nil;
  lReferences := nil;
  lWithStatements := nil;
  try
    lDiagnostics := TList<TDelphiSemanticModelDiagnostic>.Create;
    lInterfaceUses := TList<string>.Create;
    lImplementationUses := TList<string>.Create;
    lDeclarations := TList<TDelphiSemanticDeclaration>.Create;
    lMembers := TList<TDelphiSemanticMember>.Create;
    lRoutines := TList<TDelphiSemanticRoutine>.Create;
    lLocals := TList<TDelphiSemanticLocal>.Create;
    lReferences := TList<TDelphiSemanticReference>.Create;
    lWithStatements := TList<TDelphiSemanticWithStatement>.Create;

    lSourceResult := TDelphiSemanticSourceLoader.LoadFile(aOptions.SourceFileName);
    Result.Success := lSourceResult.Success;
    Result.FileName := lSourceResult.Source.FileName;
    if not lSourceResult.Success then
    begin
      AddSourceDiagnostics(lDiagnostics, lSourceResult.Diagnostics);
      AssignModelArrays(Result, lDiagnostics, lInterfaceUses, lImplementationUses, lDeclarations,
        lMembers, lRoutines, lLocals, lReferences, lWithStatements);
      Exit;
    end;

    lPreprocessOptions := Default(TDelphiSemanticPreprocessOptions);
    lPreprocessOptions.SourceFileName := aOptions.SourceFileName;
    lPreprocessOptions.SourceText := lSourceResult.Source.Text;
    lPreprocessOptions.Defines := aOptions.Defines;
    lPreprocessOptions.SearchPaths := aOptions.SearchPaths;
    lPreprocessResult := TDelphiSemanticPreprocessor.PreprocessFile(lPreprocessOptions);
    Result.Success := lPreprocessResult.Success;
    AddPreprocessDiagnostics(lDiagnostics, lPreprocessResult.Diagnostics);
    lText := lPreprocessResult.OutputText;
    if lText = '' then
      lText := lSourceResult.Source.Text;

    if not aOptions.ProjectContextApplied then
      AddDiagnostic(lDiagnostics, 'NO_PROJECT_CONTEXT',
        'No full project/compiler context was applied.', aOptions.SourceFileName, 0);

    Result.FileName := lSourceResult.Source.FileName;
    Result.EncodingName := lSourceResult.Source.EncodingName;
    lMatch := TRegEx.Match(lText, '^\s*unit\s+([A-Za-z_][A-Za-z0-9_\.]*)\s*;',
      [roIgnoreCase, roMultiLine]);
    if lMatch.Success then
      Result.UnitName := lMatch.Groups[1].Value;

    ExtractUses(lText, lInterfaceUses, lImplementationUses);
    ExtractTypeDeclarations(lText, lDeclarations);
    ExtractConstVarDeclarations(lText, lDeclarations);
    ExtractMembers(lText, lMembers);
    ExtractRoutines(lText, lDeclarations, lRoutines);
    ExtractRoutineBodies(lText, lLocals, lReferences);
    ExtractWithStatements(lText, lWithStatements);
    ReconcileDeclarationCoordinates(lSourceResult.Source.Text, lDeclarations);
    ReconcileWithStatementCoordinates(lSourceResult.Source.Text, lWithStatements);
    ReconcileReferencesCoordinates(lSourceResult.Source.Text, lReferences);
    ReconcileMemberCoordinates(lSourceResult.Source.Text, lMembers);
    ReconcileRoutineCoordinates(lSourceResult.Source.Text, lRoutines);
    ReconcileLocalCoordinates(lSourceResult.Source.Text, lLocals);

    AssignModelArrays(Result, lDiagnostics, lInterfaceUses, lImplementationUses, lDeclarations,
      lMembers, lRoutines, lLocals, lReferences, lWithStatements);
  finally
    lWithStatements.Free;
    lReferences.Free;
    lLocals.Free;
    lRoutines.Free;
    lMembers.Free;
    lDeclarations.Free;
    lImplementationUses.Free;
    lInterfaceUses.Free;
    lDiagnostics.Free;
  end;
end;

end.
