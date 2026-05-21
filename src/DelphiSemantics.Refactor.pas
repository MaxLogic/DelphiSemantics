unit DelphiSemantics.Refactor;

interface

uses
  DelphiSemantics.Query, DelphiSemantics.Usage;

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

  TDelphiSemanticRenamePlanner = record
  public
    class function PlanRename(const aContext: TDelphiSemanticSymbolQueryContext;
      const aName, aNewName: string): TDelphiSemanticRenamePlan; static;
  end;

implementation

uses
  System.Generics.Collections, System.IOUtils, System.StrUtils, System.SysUtils,
  DelphiSemantics.Index, DelphiSemantics.Model, DelphiSemantics.Symbols;

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

end.
