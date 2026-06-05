unit DelphiSemantics.Refactor;

interface

uses
  DelphiSemantics.DeadCode, DelphiSemantics.Index, DelphiSemantics.Query, DelphiSemantics.Symbols,
  DelphiSemantics.Usage;

type
  TDelphiSemanticTextEdit = record
    FileName: string;
    Role: string;
    StartLine: Integer;
    StartColumn: Integer;
    EndLine: Integer;
    EndColumn: Integer;
    NewText: string;
  end;

  TDelphiSemanticRenamePlan = record
    Status: string;
    Diagnostic: string;
    Edits: TArray<TDelphiSemanticTextEdit>;
    IndexMetrics: TDelphiSemanticProjectSymbolIndexMetrics;
  end;

  TDelphiSemanticDeadCodeRemovalBlocker = record
    SymbolId: TDelphiSemanticSymbolId;
    Name: string;
    Status: string;
    Reason: string;
  end;

  TDelphiSemanticDeadCodeRemovalPlan = record
    Status: string;
    Diagnostic: string;
    Profile: string;
    Edits: TArray<TDelphiSemanticTextEdit>;
    Blockers: TArray<TDelphiSemanticDeadCodeRemovalBlocker>;
  end;

  TDelphiSemanticRenamePlanner = record
  public
    class function PlanRename(const aContext: TDelphiSemanticSymbolQueryContext;
      const aName, aNewName: string): TDelphiSemanticRenamePlan; static;
    class function PlanRenameAtPosition(const aContext: TDelphiSemanticSymbolQueryContext;
      const aFileName: string; const aLine, aColumn: Integer; const aNewName: string):
      TDelphiSemanticRenamePlan; static;
    class function PlanFunctionResultRefactorAtPosition(
      const aContext: TDelphiSemanticSymbolQueryContext; const aFileName: string;
      const aLine, aColumn: Integer): TDelphiSemanticRenamePlan; static;
    class function PlanDeadCodeRemoval(const aContext: TDelphiSemanticSymbolQueryContext;
      const aProfile: string): TDelphiSemanticDeadCodeRemovalPlan; static;
  end;

implementation

uses
  System.Generics.Collections, System.IOUtils, System.StrUtils, System.SysUtils,
  DelphiSemantics.Model;

function MakeBlockedPlan(const aDiagnostic: string): TDelphiSemanticRenamePlan;
begin
  Result := Default(TDelphiSemanticRenamePlan);
  Result.Status := 'blocked';
  Result.Diagnostic := aDiagnostic;
end;

function IsIdentifierText(const aText: string): Boolean;
var
  c: Char;
begin
  if aText = '' then
    Exit(False);

  if not CharInSet(aText[1], ['A'..'Z', 'a'..'z', '_']) then
    Exit(False);

  for c in aText do
    if not CharInSet(c, ['A'..'Z', 'a'..'z', '0'..'9', '_']) then
      Exit(False);

  Result := not MatchText(aText, ['absolute', 'and', 'array', 'as', 'asm', 'begin', 'case',
    'class', 'const', 'constructor', 'destructor', 'dispinterface', 'div', 'do', 'downto',
    'else', 'end', 'except', 'exports', 'file', 'finalization', 'finally', 'for', 'function',
    'goto', 'if', 'implementation', 'in', 'inherited', 'initialization', 'inline',
    'interface', 'is', 'label', 'library', 'mod', 'nil', 'not', 'object', 'of', 'or', 'out',
    'packed', 'procedure', 'program', 'property', 'raise', 'record', 'repeat', 'resourcestring',
    'set', 'shl', 'shr', 'string', 'then', 'threadvar', 'to', 'try', 'type', 'unit', 'until',
    'uses', 'var', 'while', 'with', 'xor']);
end;

function HasNameCollision(const aIndex: TDelphiSemanticProjectSymbolIndex; const aOriginalName,
  aNewName: string): Boolean;
var
  lSymbol: TDelphiSemanticIndexedSymbol;
begin
  for lSymbol in aIndex.Symbols do
    if SameText(lSymbol.Name, aNewName) and not SameText(lSymbol.Name, aOriginalName) then
      Exit(True);

  Result := False;
end;

function MakeEdit(const aUsage: TDelphiSemanticUsage; const aNewName: string):
  TDelphiSemanticTextEdit;
begin
  Result := Default(TDelphiSemanticTextEdit);
  Result.FileName := aUsage.FileName;
  Result.Role := aUsage.Role;
  Result.StartLine := aUsage.Line;
  Result.StartColumn := aUsage.Column;
  Result.EndLine := aUsage.EndLine;
  Result.EndColumn := aUsage.EndColumn;
  Result.NewText := aNewName;
end;

function EditAlreadyPlanned(const aEdits: TList<TDelphiSemanticTextEdit>;
  const aEdit: TDelphiSemanticTextEdit): Boolean;
var
  lEdit: TDelphiSemanticTextEdit;
begin
  for lEdit in aEdits do
    if SameText(lEdit.FileName, aEdit.FileName) and (lEdit.StartLine = aEdit.StartLine) and
      (lEdit.StartColumn = aEdit.StartColumn) and (lEdit.EndLine = aEdit.EndLine) and
      (lEdit.EndColumn = aEdit.EndColumn) then
      Exit(True);
  Result := False;
end;

function MakeRemovalBlocker(const aCandidate: TDelphiSemanticDeadCodeCandidate;
  const aReason: string): TDelphiSemanticDeadCodeRemovalBlocker;
begin
  Result := Default(TDelphiSemanticDeadCodeRemovalBlocker);
  Result.SymbolId := aCandidate.SymbolId;
  Result.Name := aCandidate.Name;
  Result.Status := aCandidate.Status;
  Result.Reason := aReason;
end;

function IsDataCandidate(const aCandidate: TDelphiSemanticDeadCodeCandidate): Boolean;
begin
  Result := SameText(aCandidate.Kind, 'var') or SameText(aCandidate.Kind, 'const') or
    SameText(aCandidate.Kind, 'typed-const') or SameText(aCandidate.Kind, 'resourcestring');
end;

function IsDeclarationSectionHeader(const aText: string): Boolean;
begin
  Result := MatchText(Trim(aText), ['const', 'resourcestring', 'threadvar', 'var']);
end;

function IsDeclarationBoundary(const aText: string): Boolean;
var
  lText: string;
begin
  lText := Trim(aText);
  Result := (lText = '') or IsDeclarationSectionHeader(lText) or StartsText('procedure ', lText) or
    StartsText('function ', lText) or StartsText('constructor ', lText) or
    StartsText('destructor ', lText) or StartsText('class procedure ', lText) or
    StartsText('class function ', lText) or StartsText('class operator ', lText) or
    StartsText('operator ', lText) or SameText(lText, 'type') or SameText(lText, 'label') or
    SameText(lText, 'exports') or SameText(lText, 'implementation') or
    SameText(lText, 'initialization') or SameText(lText, 'finalization') or
    SameText(lText, 'end.');
end;

function IsIgnorableDeclarationLine(const aText: string): Boolean;
var
  lText: string;
begin
  lText := Trim(aText);
  Result := (lText = '') or StartsText('//', lText) or StartsText('{', lText) or
    StartsText('(*', lText) or StartsText('{$', lText);
end;

function IsParseableDeclarationLine(const aText: string): Boolean;
var
  lEqualsPos: Integer;
  lPrefix: string;
  lSeparatorPos: Integer;
begin
  lPrefix := '';
  lSeparatorPos := Pos(':', aText);
  lEqualsPos := Pos('=', aText);
  if (lEqualsPos > 0) and ((lSeparatorPos = 0) or (lEqualsPos < lSeparatorPos)) then
    lSeparatorPos := lEqualsPos;

  if lSeparatorPos <= 1 then
    Exit(False);

  lPrefix := Trim(Copy(aText, 1, lSeparatorPos - 1));
  Result := (lPrefix <> '') and CharInSet(lPrefix[1], ['A'..'Z', 'a'..'z', '_']) and
    (Pos('(', lPrefix) = 0) and (Pos(')', lPrefix) = 0) and (Pos('.', lPrefix) = 0) and
    not ContainsText(lPrefix, ' procedure') and not ContainsText(lPrefix, ' function') and
    not ContainsText(lPrefix, ' operator');
end;

function DataSectionKeepsAnotherDeclaration(const aLines: TArray<string>;
  const aLine: Integer): Boolean;
var
  i: Integer;
  lText: string;
begin
  Result := False;
  for i := aLine - 2 downto 0 do
  begin
    lText := Trim(aLines[i]);
    if IsDeclarationSectionHeader(lText) or IsDeclarationBoundary(lText) then
      Break;
    if IsIgnorableDeclarationLine(lText) then
      Continue;
    if IsParseableDeclarationLine(lText) then
      Exit(True);
    Exit(False);
  end;

  for i := aLine to High(aLines) do
  begin
    lText := Trim(aLines[i]);
    if IsDeclarationSectionHeader(lText) or IsDeclarationBoundary(lText) then
      Exit(False);
    if IsIgnorableDeclarationLine(lText) then
      Continue;
    if IsParseableDeclarationLine(lText) then
      Exit(True);
    Exit(False);
  end;
end;

function MakeRemovalEdit(const aCandidate: TDelphiSemanticDeadCodeCandidate;
  const aEndLine: Integer): TDelphiSemanticTextEdit;
begin
  Result := Default(TDelphiSemanticTextEdit);
  Result.FileName := aCandidate.FileName;
  Result.Role := 'remove-dead-code';
  Result.StartLine := aCandidate.Line;
  Result.StartColumn := 1;
  Result.EndLine := aEndLine;
  Result.EndColumn := 1;
  Result.NewText := '';
end;

function TryPlanDataRemoval(const aCandidate: TDelphiSemanticDeadCodeCandidate;
  out aEdit: TDelphiSemanticTextEdit): Boolean;
var
  lColonPos: Integer;
  lDeclarationPrefix: string;
  lLineText: string;
  lLines: TArray<string>;
begin
  aEdit := Default(TDelphiSemanticTextEdit);
  if (aCandidate.FileName = '') or (aCandidate.Line <= 0) or
    not TFile.Exists(aCandidate.FileName) then
    Exit(False);

  lLines := TFile.ReadAllLines(aCandidate.FileName);
  if (aCandidate.Line > Length(lLines)) or not ContainsText(lLines[aCandidate.Line - 1],
    aCandidate.Name) then
    Exit(False);

  lLineText := Trim(lLines[aCandidate.Line - 1]);
  if not StartsText(aCandidate.Name, lLineText) then
    Exit(False);
  lColonPos := Pos(':', lLineText);
  if lColonPos <= 0 then
    Exit(False);
  lDeclarationPrefix := Trim(Copy(lLineText, 1, lColonPos - 1));
  if not SameText(lDeclarationPrefix, aCandidate.Name) then
    Exit(False);
  if not DataSectionKeepsAnotherDeclaration(lLines, aCandidate.Line) then
    Exit(False);

  aEdit := MakeRemovalEdit(aCandidate, aCandidate.Line + 1);
  Result := True;
end;

function TryPlanRoutineRemoval(const aCandidate: TDelphiSemanticDeadCodeCandidate;
  out aEdit: TDelphiSemanticTextEdit): Boolean;
var
  i: Integer;
  lLines: TArray<string>;
  lNextLine: Integer;
begin
  aEdit := Default(TDelphiSemanticTextEdit);
  if (aCandidate.FileName = '') or (aCandidate.Line <= 0) or
    not TFile.Exists(aCandidate.FileName) then
    Exit(False);

  lLines := TFile.ReadAllLines(aCandidate.FileName);
  if (aCandidate.Line > Length(lLines)) or not ContainsText(lLines[aCandidate.Line - 1],
    aCandidate.Name) then
    Exit(False);

  if (aCandidate.Line + 1) > Length(lLines) then
    Exit(False);
  if not SameText(Trim(lLines[aCandidate.Line]), 'begin') then
    Exit(False);
  if (aCandidate.Line + 2) > Length(lLines) then
    Exit(False);
  if not SameText(Trim(lLines[aCandidate.Line + 1]), 'end;') then
    Exit(False);

  lNextLine := aCandidate.Line + 3;
  i := aCandidate.Line + 2;
  if (i <= High(lLines)) and (Trim(lLines[i]) = '') then
    Inc(lNextLine);

  aEdit := MakeRemovalEdit(aCandidate, lNextLine);
  Result := True;
end;

function TryPlanDeadCodeRemovalEdit(const aCandidate: TDelphiSemanticDeadCodeCandidate;
  out aEdit: TDelphiSemanticTextEdit; out aBlockerReason: string): Boolean;
begin
  aBlockerReason := '';
  if aCandidate.OwnerName <> '' then
  begin
    aBlockerReason := 'unsupported-owned-member';
    Exit(False);
  end;

  if IsDataCandidate(aCandidate) then
    Exit(TryPlanDataRemoval(aCandidate, aEdit));

  if SameText(aCandidate.Kind, 'routine') then
    Exit(TryPlanRoutineRemoval(aCandidate, aEdit));

  aBlockerReason := 'unsupported-syntax';
  Result := False;
end;

function IsProjectUsage(const aUsage: TDelphiSemanticUsage): Boolean;
begin
  Result := SameText(aUsage.SourceKind, 'project-source');
end;

function SameFileName(const aLeft, aRight: string): Boolean;
begin
  if (aLeft = '') or (aRight = '') then
    Exit(False);
  try
    Result := SameText(TPath.GetFullPath(aLeft), TPath.GetFullPath(aRight));
  except
    Result := SameText(aLeft, aRight);
  end;
end;

function TryFindUsageModel(const aContext: TDelphiSemanticSymbolQueryContext;
  const aUsage: TDelphiSemanticUsage; out aModel: TDelphiSemanticUnitModel): Boolean;
var
  lModel: TDelphiSemanticUnitModel;
begin
  if SameFileName(aContext.UnitModel.FileName, aUsage.FileName) then
  begin
    aModel := aContext.UnitModel;
    Exit(True);
  end;

  for lModel in aContext.IndexedUnitModels do
    if SameFileName(lModel.FileName, aUsage.FileName) then
    begin
      aModel := lModel;
      Exit(True);
    end;

  aModel := Default(TDelphiSemanticUnitModel);
  Result := False;
end;

function TryFindModelByFile(const aContext: TDelphiSemanticSymbolQueryContext;
  const aFileName: string; out aModel: TDelphiSemanticUnitModel): Boolean;
var
  lModel: TDelphiSemanticUnitModel;
begin
  if SameFileName(aContext.UnitModel.FileName, aFileName) then
  begin
    aModel := aContext.UnitModel;
    Exit(True);
  end;

  for lModel in aContext.IndexedUnitModels do
    if SameFileName(lModel.FileName, aFileName) then
    begin
      aModel := lModel;
      Exit(True);
    end;

  aModel := Default(TDelphiSemanticUnitModel);
  Result := False;
end;

function UnqualifiedName(const aName: string): string;
var
  lDotPos: Integer;
begin
  lDotPos := LastDelimiter('.', aName);
  if lDotPos > 0 then
    Result := Copy(aName, lDotPos + 1, MaxInt)
  else
    Result := aName;
end;

function PreviousNonSpaceChar(const aText: string; const aColumn: Integer): Char;
var
  i: Integer;
begin
  for i := aColumn - 1 downto 1 do
    if not CharInSet(aText[i], [#9, ' ']) then
      Exit(aText[i]);

  Result := #0;
end;

function NextNonSpaceChar(const aText: string; const aColumn: Integer): Char;
var
  i: Integer;
begin
  for i := aColumn + 1 to Length(aText) do
    if not CharInSet(aText[i], [#9, ' ']) then
      Exit(aText[i]);

  Result := #0;
end;

function IsIdentifierChar(const c: Char): Boolean;
begin
  Result := CharInSet(c, ['A'..'Z', 'a'..'z', '0'..'9', '_']);
end;

function SanitizeFunctionResultLine(const aLine: string; var aCommentMode: Integer): string;
var
  i: Integer;
  lInString: Boolean;
  sb: TStringBuilder;
begin
  sb := TStringBuilder.Create(Length(aLine));
  try
    i := 1;
    lInString := False;
    while i <= Length(aLine) do
    begin
      if aCommentMode = 1 then
      begin
        if aLine[i] = '}' then
          aCommentMode := 0;
        sb.Append(' ');
        Inc(i);
      end else if aCommentMode = 2 then
      begin
        if (aLine[i] = '*') and (i < Length(aLine)) and (aLine[i + 1] = ')') then
        begin
          sb.Append(' ');
          sb.Append(' ');
          aCommentMode := 0;
          Inc(i, 2);
        end else begin
          sb.Append(' ');
          Inc(i);
        end;
      end else if lInString then
      begin
        sb.Append(' ');
        if aLine[i] = '''' then
        begin
          if (i < Length(aLine)) and (aLine[i + 1] = '''') then
          begin
            sb.Append(' ');
            Inc(i, 2);
          end else begin
            lInString := False;
            Inc(i);
          end;
        end else
          Inc(i);
      end else if (aLine[i] = '/') and (i < Length(aLine)) and (aLine[i + 1] = '/') then
      begin
        while i <= Length(aLine) do
        begin
          sb.Append(' ');
          Inc(i);
        end;
      end else if aLine[i] = '{' then
      begin
        aCommentMode := 1;
        sb.Append(' ');
        Inc(i);
      end else if (aLine[i] = '(') and (i < Length(aLine)) and (aLine[i + 1] = '*') then
      begin
        aCommentMode := 2;
        sb.Append(' ');
        sb.Append(' ');
        Inc(i, 2);
      end else if aLine[i] = '''' then
      begin
        lInString := True;
        sb.Append(' ');
        Inc(i);
      end else begin
        sb.Append(aLine[i]);
        Inc(i);
      end;
    end;
    Result := sb.ToString;
  finally
    sb.Free;
  end;
end;

function TryTokenAtPosition(const aLineText: string; const aColumn: Integer; out aToken: string;
  out aStartColumn, aEndColumn: Integer): Boolean;
begin
  aToken := '';
  aStartColumn := 0;
  aEndColumn := 0;
  if (aColumn <= 0) or (aColumn > Length(aLineText)) or
    not IsIdentifierChar(aLineText[aColumn]) then
    Exit(False);

  aStartColumn := aColumn;
  while (aStartColumn > 1) and IsIdentifierChar(aLineText[aStartColumn - 1]) do
    Dec(aStartColumn);
  aEndColumn := aColumn;
  while (aEndColumn < Length(aLineText)) and IsIdentifierChar(aLineText[aEndColumn + 1]) do
    Inc(aEndColumn);

  aToken := Copy(aLineText, aStartColumn, aEndColumn - aStartColumn + 1);
  Result := True;
end;

function SanitizedLineAt(const aLines: TArray<string>; const aLine: Integer): string;
var
  i: Integer;
  lCommentMode: Integer;
begin
  Result := '';
  lCommentMode := 0;
  for i := 1 to aLine do
    Result := SanitizeFunctionResultLine(aLines[i - 1], lCommentMode);
end;

function IsRoutineHeaderLine(const aLineText: string): Boolean;
var
  lText: string;
begin
  lText := Trim(aLineText);
  Result := StartsText('function ', lText) or StartsText('procedure ', lText) or
    StartsText('constructor ', lText) or StartsText('destructor ', lText) or
    StartsText('class function ', lText) or StartsText('class procedure ', lText) or
    StartsText('class operator ', lText) or StartsText('operator ', lText);
end;

function CountTokenOnLine(const aLineText, aToken: string): Integer;
var
  lColumn: Integer;
  lEndColumn: Integer;
  lStartColumn: Integer;
  lToken: string;
begin
  Result := 0;
  lColumn := 1;
  while lColumn <= Length(aLineText) do
  begin
    while (lColumn <= Length(aLineText)) and not IsIdentifierChar(aLineText[lColumn]) do
      Inc(lColumn);
    if lColumn > Length(aLineText) then
      Break;
    lStartColumn := lColumn;
    lEndColumn := lColumn;
    while (lEndColumn < Length(aLineText)) and IsIdentifierChar(aLineText[lEndColumn + 1]) do
      Inc(lEndColumn);
    lToken := Copy(aLineText, lStartColumn, lEndColumn - lStartColumn + 1);
    if SameText(lToken, aToken) then
      Inc(Result);
    lColumn := lEndColumn + 1;
  end;
end;

function HasTokenOnLine(const aLineText, aToken: string): Boolean;
begin
  Result := CountTokenOnLine(aLineText, aToken) > 0;
end;

function TryFindBlockEndLine(const aLines: TArray<string>; const aBeginLine: Integer;
  out aEndLine: Integer): Boolean;
var
  i: Integer;
  lCommentMode: Integer;
  lDepth: Integer;
  lLineText: string;
begin
  lDepth := 0;
  lCommentMode := 0;
  for i := aBeginLine to Length(aLines) do
  begin
    lLineText := SanitizeFunctionResultLine(aLines[i - 1], lCommentMode);
    Inc(lDepth, CountTokenOnLine(lLineText, 'begin') + CountTokenOnLine(lLineText, 'try') +
      CountTokenOnLine(lLineText, 'case') + CountTokenOnLine(lLineText, 'asm'));
    Dec(lDepth, CountTokenOnLine(lLineText, 'end'));
    if lDepth <= 0 then
    begin
      aEndLine := i;
      Exit(True);
    end;
  end;

  aEndLine := 0;
  Result := False;
end;

function TryFindRoutineBodySpan(const aLines: TArray<string>; const aRoutine: TDelphiSemanticRoutine;
  out aBodyStartLine, aEndLine: Integer): Boolean;
var
  i: Integer;
  lBodyStartLine: Integer;
  lCommentMode: Integer;
  lLineText: string;
  lNestedEndLine: Integer;
  lNestedRoutine: TDelphiSemanticRoutine;
begin
  i := aRoutine.Line;
  lCommentMode := 0;
  while i <= Length(aLines) do
  begin
    lLineText := SanitizeFunctionResultLine(aLines[i - 1], lCommentMode);
    if (i > aRoutine.Line) and IsRoutineHeaderLine(lLineText) then
    begin
      lNestedRoutine := Default(TDelphiSemanticRoutine);
      lNestedRoutine.Line := i;
      if TryFindRoutineBodySpan(aLines, lNestedRoutine, lBodyStartLine, lNestedEndLine) then
      begin
        i := lNestedEndLine + 1;
        Continue;
      end;
    end;

    if HasTokenOnLine(lLineText, 'begin') then
    begin
      aBodyStartLine := i;
      Result := TryFindBlockEndLine(aLines, i, aEndLine);
      Exit;
    end;
    Inc(i);
  end;

  aBodyStartLine := 0;
  aEndLine := 0;
  Result := False;
end;

function TryFindEnclosingFunctionBodyRoutine(const aModel: TDelphiSemanticUnitModel;
  const aLines: TArray<string>; const aLine: Integer; out aRoutine: TDelphiSemanticRoutine;
  out aBodyStartLine, aEndLine: Integer): Boolean;
var
  lBodyStartLine: Integer;
  lEndLine: Integer;
  lRoutine: TDelphiSemanticRoutine;
begin
  Result := False;
  aRoutine := Default(TDelphiSemanticRoutine);
  aBodyStartLine := 0;
  aEndLine := 0;
  for lRoutine in aModel.Routines do
  begin
    if (lRoutine.ReturnType = '') or (lRoutine.Line > aLine) then
      Continue;
    if not TryFindRoutineBodySpan(aLines, lRoutine, lBodyStartLine, lEndLine) or
      (aLine > lEndLine) or (aLine < lBodyStartLine) then
      Continue;
    if (not Result) or (lRoutine.Line > aRoutine.Line) then
    begin
      aRoutine := lRoutine;
      aBodyStartLine := lBodyStartLine;
      aEndLine := lEndLine;
      Result := True;
    end;
  end;
end;

function IsFunctionResultToken(const aLineText, aRoutineName: string; const aStartColumn,
  aEndColumn: Integer): Boolean;
begin
  Result := SameText(Copy(aLineText, aStartColumn, aEndColumn - aStartColumn + 1),
    UnqualifiedName(aRoutineName)) and
    (PreviousNonSpaceChar(aLineText, aStartColumn) <> '.') and
    (NextNonSpaceChar(aLineText, aEndColumn) <> '(');
end;

function MakeFunctionResultEditFromRange(const aFileName: string; const aLine, aStartColumn,
  aEndColumn: Integer): TDelphiSemanticTextEdit;
begin
  Result := Default(TDelphiSemanticTextEdit);
  Result.FileName := aFileName;
  Result.Role := 'function-result';
  Result.StartLine := aLine;
  Result.StartColumn := aStartColumn;
  Result.EndLine := aLine;
  Result.EndColumn := aEndColumn;
  Result.NewText := 'Result';
end;

function PositionInWithBody(const aModel: TDelphiSemanticUnitModel; const aLine,
  aColumn: Integer): Boolean;
var
  lWithStatement: TDelphiSemanticWithStatement;
begin
  for lWithStatement in aModel.WithStatements do
    if ((aLine > lWithStatement.BodyLine) or
      ((aLine = lWithStatement.BodyLine) and (aColumn >= lWithStatement.BodyColumn))) and
      ((aLine < lWithStatement.BodyEndLine) or
      ((aLine = lWithStatement.BodyEndLine) and (aColumn <= lWithStatement.BodyEndColumn))) then
      Exit(True);

  Result := False;
end;

procedure AddFunctionResultEdits(const aFileName: string; const aLines: TArray<string>;
  const aModel: TDelphiSemanticUnitModel; const aRoutine: TDelphiSemanticRoutine;
  const aBodyStartLine, aEndLine: Integer; const aEdits: TList<TDelphiSemanticTextEdit>);
var
  i: Integer;
  lCommentMode: Integer;
  lEndColumn: Integer;
  lEdit: TDelphiSemanticTextEdit;
  lLineText: string;
  lStartColumn: Integer;
  lToken: string;
begin
  lCommentMode := 0;
  for i := aBodyStartLine to aEndLine do
  begin
    lLineText := SanitizeFunctionResultLine(aLines[i - 1], lCommentMode);
    lStartColumn := 1;
    while lStartColumn <= Length(lLineText) do
    begin
      while (lStartColumn <= Length(lLineText)) and not IsIdentifierChar(lLineText[lStartColumn]) do
        Inc(lStartColumn);
      if lStartColumn > Length(lLineText) then
        Break;
      lEndColumn := lStartColumn;
      while (lEndColumn < Length(lLineText)) and IsIdentifierChar(lLineText[lEndColumn + 1]) do
        Inc(lEndColumn);
      lToken := Copy(lLineText, lStartColumn, lEndColumn - lStartColumn + 1);
      if SameText(lToken, UnqualifiedName(aRoutine.Name)) and
        IsFunctionResultToken(lLineText, aRoutine.Name, lStartColumn, lEndColumn) and
        not PositionInWithBody(aModel, i, lStartColumn) then
      begin
        lEdit := MakeFunctionResultEditFromRange(aFileName, i, lStartColumn, lEndColumn);
        if not EditAlreadyPlanned(aEdits, lEdit) then
          aEdits.Add(lEdit);
      end;
      lStartColumn := lEndColumn + 1;
    end;
  end;
end;

function IsShadowedByLocal(const aContext: TDelphiSemanticSymbolQueryContext;
  const aUsage: TDelphiSemanticUsage): Boolean;
var
  lLocal: TDelphiSemanticLocal;
  lModel: TDelphiSemanticUnitModel;
begin
  if (aUsage.RoutineName = '') or not SameText(aUsage.Role, 'reference') or
    not TryFindUsageModel(aContext, aUsage, lModel) then
    Exit(False);

  for lLocal in lModel.Locals do
    if SameText(lLocal.RoutineName, aUsage.RoutineName) and SameText(lLocal.Name, aUsage.Name) and
      (lLocal.Line < aUsage.Line) then
      Exit(True);

  Result := False;
end;

function BuildRenamePlanFromUsages(const aContext: TDelphiSemanticSymbolQueryContext;
  const aUsageResult: TDelphiSemanticUsageResult; const aNewName: string):
  TDelphiSemanticRenamePlan;
var
  lEdit: TDelphiSemanticTextEdit;
  lEdits: TList<TDelphiSemanticTextEdit>;
  lUsage: TDelphiSemanticUsage;
begin
  if aUsageResult.Status <> 'resolved' then
    Exit(MakeBlockedPlan(aUsageResult.Diagnostic));

  lEdits := TList<TDelphiSemanticTextEdit>.Create;
  try
    for lUsage in aUsageResult.Usages do
    begin
      if not IsProjectUsage(lUsage) then
        Exit(MakeBlockedPlan('Rename contains non-project usage in "' + lUsage.FileName + '".'));
      if (aUsageResult.Symbol.OwnerName = '') and IsShadowedByLocal(aContext, lUsage) then
        Continue;
      if (lUsage.FileName = '') or (lUsage.Line <= 0) or (lUsage.Column <= 0) or
        (lUsage.EndLine <= 0) or (lUsage.EndColumn <= 0) or
        ((lUsage.EndLine = lUsage.Line) and (lUsage.EndColumn < lUsage.Column)) then
        Exit(MakeBlockedPlan('Rename range is missing for usage "' + lUsage.Name + '".'));
      lEdit := MakeEdit(lUsage, aNewName);
      if not EditAlreadyPlanned(lEdits, lEdit) then
        lEdits.Add(lEdit);
    end;

    Result := Default(TDelphiSemanticRenamePlan);
    Result.Status := 'planned';
    Result.Edits := lEdits.ToArray;
  finally
    lEdits.Free;
  end;
end;

class function TDelphiSemanticRenamePlanner.PlanRename(
  const aContext: TDelphiSemanticSymbolQueryContext; const aName, aNewName: string):
  TDelphiSemanticRenamePlan;
var
  lIndex: TDelphiSemanticProjectSymbolIndex;
  lUsageResult: TDelphiSemanticUsageResult;
begin
  if not IsIdentifierText(aNewName) then
    Exit(MakeBlockedPlan('New name is not a valid Delphi identifier.'));

  lIndex := TDelphiSemanticProjectSymbolIndexer.Build(aContext);
  if HasNameCollision(lIndex, aName, aNewName) then
  begin
    Result := MakeBlockedPlan('Rename collision: a visible symbol already uses "' + aNewName + '".');
    Result.IndexMetrics := lIndex.Metrics;
    Exit;
  end;

  lUsageResult := TDelphiSemanticUsageFinder.FindUsagesByName(lIndex, aName);
  Result := BuildRenamePlanFromUsages(aContext, lUsageResult, aNewName);
  Result.IndexMetrics := lIndex.Metrics;
end;

class function TDelphiSemanticRenamePlanner.PlanRenameAtPosition(
  const aContext: TDelphiSemanticSymbolQueryContext; const aFileName: string; const aLine,
  aColumn: Integer; const aNewName: string): TDelphiSemanticRenamePlan;
var
  lIndex: TDelphiSemanticProjectSymbolIndex;
  lUsageResult: TDelphiSemanticUsageResult;
begin
  if not IsIdentifierText(aNewName) then
    Exit(MakeBlockedPlan('New name is not a valid Delphi identifier.'));

  lIndex := TDelphiSemanticProjectSymbolIndexer.Build(aContext);
  lUsageResult := TDelphiSemanticUsageFinder.FindUsagesAtPosition(lIndex, aContext, aFileName,
    aLine, aColumn);
  if lUsageResult.Status <> 'resolved' then
  begin
    Result := MakeBlockedPlan(lUsageResult.Diagnostic);
    Result.IndexMetrics := lIndex.Metrics;
    Exit;
  end;

  if HasNameCollision(lIndex, lUsageResult.Symbol.Name, aNewName) then
  begin
    Result := MakeBlockedPlan('Rename collision: a visible symbol already uses "' + aNewName + '".');
    Result.IndexMetrics := lIndex.Metrics;
    Exit;
  end;

  Result := BuildRenamePlanFromUsages(aContext, lUsageResult, aNewName);
  Result.IndexMetrics := lIndex.Metrics;
end;

class function TDelphiSemanticRenamePlanner.PlanFunctionResultRefactorAtPosition(
  const aContext: TDelphiSemanticSymbolQueryContext; const aFileName: string; const aLine,
  aColumn: Integer): TDelphiSemanticRenamePlan;
var
  lBodyStartLine: Integer;
  lEdits: TList<TDelphiSemanticTextEdit>;
  lEndColumn: Integer;
  lEndLine: Integer;
  lLines: TArray<string>;
  lModel: TDelphiSemanticUnitModel;
  lRoutine: TDelphiSemanticRoutine;
  lSelectedLineText: string;
  lStartColumn: Integer;
  lToken: string;
begin
  if not TryFindModelByFile(aContext, aFileName, lModel) then
    Exit(MakeBlockedPlan('No semantic model found for the requested file.'));
  if (lModel.FileName = '') or not TFile.Exists(lModel.FileName) then
    Exit(MakeBlockedPlan('Source file is not available for function-result planning.'));

  lLines := TFile.ReadAllLines(lModel.FileName);
  if (aLine > 0) and (aLine <= Length(lLines)) then
    lSelectedLineText := SanitizedLineAt(lLines, aLine)
  else
    lSelectedLineText := '';
  if (aLine <= 0) or (aLine > Length(lLines)) or
    not TryTokenAtPosition(lSelectedLineText, aColumn, lToken, lStartColumn, lEndColumn) then
    Exit(MakeBlockedPlan('No function-result identifier found at the requested position.'));
  if not TryFindEnclosingFunctionBodyRoutine(lModel, lLines, aLine, lRoutine, lBodyStartLine,
    lEndLine) then
    Exit(MakeBlockedPlan('Selected identifier is not inside a function routine.'));
  if not SameText(lToken, UnqualifiedName(lRoutine.Name)) then
    Exit(MakeBlockedPlan('Selected identifier is not the enclosing function result name.'));
  if PositionInWithBody(lModel, aLine, lStartColumn) then
    Exit(MakeBlockedPlan('Selected identifier is inside a with-statement body.'));
  if not IsFunctionResultToken(lSelectedLineText, lRoutine.Name, lStartColumn, lEndColumn) then
    Exit(MakeBlockedPlan('Selected identifier is not a function-result assignment or read.'));

  lEdits := TList<TDelphiSemanticTextEdit>.Create;
  try
    AddFunctionResultEdits(lModel.FileName, lLines, lModel, lRoutine, lBodyStartLine, lEndLine,
      lEdits);

    if lEdits.Count = 0 then
      Exit(MakeBlockedPlan('No function-result edits were planned.'));

    Result := Default(TDelphiSemanticRenamePlan);
    Result.Status := 'planned';
    Result.Edits := lEdits.ToArray;
  finally
    lEdits.Free;
  end;
end;

class function TDelphiSemanticRenamePlanner.PlanDeadCodeRemoval(
  const aContext: TDelphiSemanticSymbolQueryContext; const aProfile: string):
  TDelphiSemanticDeadCodeRemovalPlan;
var
  lBlockerReason: string;
  lBlockers: TList<TDelphiSemanticDeadCodeRemovalBlocker>;
  lCandidate: TDelphiSemanticDeadCodeCandidate;
  lEdit: TDelphiSemanticTextEdit;
  lEdits: TList<TDelphiSemanticTextEdit>;
  lProfile: string;
  lReport: TDelphiSemanticDeadCodeReport;
begin
  lProfile := aProfile;
  if lProfile = '' then
    lProfile := 'conservative';

  lReport := TDelphiSemanticDeadCodeReporter.Report(aContext, lProfile);
  lEdits := TList<TDelphiSemanticTextEdit>.Create;
  lBlockers := TList<TDelphiSemanticDeadCodeRemovalBlocker>.Create;
  try
    for lCandidate in lReport.Candidates do
    begin
      if SameText(lProfile, 'audit') then
      begin
        lBlockers.Add(MakeRemovalBlocker(lCandidate, 'audit-profile'));
        Continue;
      end;

      if not SameText(lCandidate.Status, 'definitely-unused') then
      begin
        lBlockers.Add(MakeRemovalBlocker(lCandidate, 'profile-not-allowed'));
        Continue;
      end;

      if TryPlanDeadCodeRemovalEdit(lCandidate, lEdit, lBlockerReason) then
        lEdits.Add(lEdit)
      else
      begin
        if lBlockerReason = '' then
          lBlockerReason := 'unsupported-syntax';
        lBlockers.Add(MakeRemovalBlocker(lCandidate, lBlockerReason));
      end;
    end;

    Result := Default(TDelphiSemanticDeadCodeRemovalPlan);
    Result.Status := 'planned';
    Result.Profile := lProfile;
    Result.Edits := lEdits.ToArray;
    Result.Blockers := lBlockers.ToArray;
  finally
    lBlockers.Free;
    lEdits.Free;
  end;
end;

end.
