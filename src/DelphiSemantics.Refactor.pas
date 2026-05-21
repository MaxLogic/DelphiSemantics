unit DelphiSemantics.Refactor;

interface

uses
  DelphiSemantics.DeadCode, DelphiSemantics.Query, DelphiSemantics.Symbols,
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
    class function PlanDeadCodeRemoval(const aContext: TDelphiSemanticSymbolQueryContext;
      const aProfile: string): TDelphiSemanticDeadCodeRemovalPlan; static;
  end;

implementation

uses
  System.Generics.Collections, System.IOUtils, System.StrUtils, System.SysUtils,
  DelphiSemantics.Index, DelphiSemantics.Model;

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

class function TDelphiSemanticRenamePlanner.PlanRename(
  const aContext: TDelphiSemanticSymbolQueryContext; const aName, aNewName: string):
  TDelphiSemanticRenamePlan;
var
  lEdit: TDelphiSemanticTextEdit;
  lEdits: TList<TDelphiSemanticTextEdit>;
  lIndex: TDelphiSemanticProjectSymbolIndex;
  lUsage: TDelphiSemanticUsage;
  lUsageResult: TDelphiSemanticUsageResult;
begin
  if not IsIdentifierText(aNewName) then
    Exit(MakeBlockedPlan('New name is not a valid Delphi identifier.'));

  lIndex := TDelphiSemanticProjectSymbolIndexer.Build(aContext);
  if HasNameCollision(lIndex, aName, aNewName) then
    Exit(MakeBlockedPlan('Rename collision: a visible symbol already uses "' + aNewName + '".'));

  lUsageResult := TDelphiSemanticUsageFinder.FindUsagesByName(aContext, aName);
  if lUsageResult.Status <> 'resolved' then
    Exit(MakeBlockedPlan(lUsageResult.Diagnostic));

  lEdits := TList<TDelphiSemanticTextEdit>.Create;
  try
    for lUsage in lUsageResult.Usages do
    begin
      if not IsProjectUsage(lUsage) then
        Exit(MakeBlockedPlan('Rename contains non-project usage in "' + lUsage.FileName + '".'));
      if IsShadowedByLocal(aContext, lUsage) then
        Continue;
      if (lUsage.FileName = '') or (lUsage.Line <= 0) or (lUsage.Column <= 0) or
        (lUsage.EndLine <= 0) or (lUsage.EndColumn <= 0) or
        ((lUsage.EndLine = lUsage.Line) and (lUsage.EndColumn < lUsage.Column)) then
        Exit(MakeBlockedPlan('Rename range is missing for usage "' + lUsage.Name + '".'));
      lEdit := MakeEdit(lUsage, aNewName);
      lEdits.Add(lEdit);
    end;

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
