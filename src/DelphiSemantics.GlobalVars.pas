unit DelphiSemantics.GlobalVars;

interface

uses
  DelphiSemantics.Model;

type
  TDelphiSemanticGlobalDeclaration = record
    Name: string;
    UnitName: string;
    FileName: string;
    OwnerName: string;
    TypeName: string;
    Kind: string;
    SectionKind: string;
    Line: Integer;
    Column: Integer;
  end;

  TDelphiSemanticGlobalUsage = record
    Name: string;
    DeclaringUnitName: string;
    UnitName: string;
    RoutineName: string;
    FileName: string;
    Access: string;
    Line: Integer;
    Column: Integer;
  end;

  TDelphiSemanticGlobalAmbiguity = record
    Name: string;
    UnitName: string;
    RoutineName: string;
    FileName: string;
    Access: string;
    Candidates: string;
    Line: Integer;
    Column: Integer;
  end;

  TDelphiSemanticGlobalDiagnostic = record
    Code: string;
    Message: string;
    FileName: string;
    Line: Integer;
  end;

  TDelphiSemanticGlobalAnalysis = record
    Declarations: TArray<TDelphiSemanticGlobalDeclaration>;
    Usages: TArray<TDelphiSemanticGlobalUsage>;
    Ambiguities: TArray<TDelphiSemanticGlobalAmbiguity>;
    Diagnostics: TArray<TDelphiSemanticGlobalDiagnostic>;
  end;

  TDelphiSemanticGlobalFilterOptions = record
    UnitPattern: string;
    NamePattern: string;
    UnusedOnly: Boolean;
    ReadsOnly: Boolean;
    WritesOnly: Boolean;
  end;

  TDelphiSemanticGlobalAnalyzer = record
  public
    class function AnalyzeUnits(const aModels: TArray<TDelphiSemanticUnitModel>):
      TDelphiSemanticGlobalAnalysis; overload; static;
    class function AnalyzeUnits(const aModels: TArray<TDelphiSemanticUnitModel>;
      const aFilters: TDelphiSemanticGlobalFilterOptions): TDelphiSemanticGlobalAnalysis;
      overload; static;
  end;

implementation

uses
  System.Classes, System.Generics.Collections, System.IOUtils, System.RegularExpressions,
  System.StrUtils, System.SysUtils;

procedure AddDiagnostic(const aDiagnostics: TList<TDelphiSemanticGlobalDiagnostic>;
  const aCode, aMessage, aFileName: string; const aLine: Integer);
var
  lDiagnostic: TDelphiSemanticGlobalDiagnostic;
begin
  lDiagnostic.Code := aCode;
  lDiagnostic.Message := aMessage;
  lDiagnostic.FileName := aFileName;
  lDiagnostic.Line := aLine;
  aDiagnostics.Add(lDiagnostic);
end;

procedure AddModelDiagnostics(const aDiagnostics: TList<TDelphiSemanticGlobalDiagnostic>;
  const aModel: TDelphiSemanticUnitModel);
var
  lDiagnostic: TDelphiSemanticModelDiagnostic;
begin
  if not aModel.Success then
    AddDiagnostic(aDiagnostics, 'MODEL_FAILED', 'Unit model extraction failed.', aModel.FileName,
      0);

  for lDiagnostic in aModel.Diagnostics do
    AddDiagnostic(aDiagnostics, lDiagnostic.Code, lDiagnostic.Message, lDiagnostic.FileName,
      lDiagnostic.Line);
end;

function NormalizeDeclarationKind(const aKind: string): string;
begin
  if SameText(aKind, 'typed-const') then
    Result := 'typedconst'
  else
    Result := LowerCase(aKind);
end;

function IsGlobalDeclarationKind(const aKind: string): Boolean;
begin
  Result := MatchText(NormalizeDeclarationKind(aKind), ['var', 'threadvar', 'typedconst']);
end;

procedure AddGlobalDeclaration(const aDeclarations: TList<TDelphiSemanticGlobalDeclaration>;
  const aName, aUnitName, aFileName, aOwnerName, aTypeName, aKind, aSectionKind: string;
  const aLine, aColumn: Integer);
var
  lDeclaration: TDelphiSemanticGlobalDeclaration;
begin
  lDeclaration.Name := aName;
  lDeclaration.UnitName := aUnitName;
  lDeclaration.FileName := aFileName;
  lDeclaration.OwnerName := aOwnerName;
  lDeclaration.TypeName := aTypeName;
  lDeclaration.Kind := NormalizeDeclarationKind(aKind);
  lDeclaration.SectionKind := aSectionKind;
  lDeclaration.Line := aLine;
  lDeclaration.Column := aColumn;
  aDeclarations.Add(lDeclaration);
end;

procedure AddModelDeclarations(const aDeclarations: TList<TDelphiSemanticGlobalDeclaration>;
  const aModel: TDelphiSemanticUnitModel);
var
  lDeclaration: TDelphiSemanticDeclaration;
  lMember: TDelphiSemanticMember;
begin
  for lDeclaration in aModel.Declarations do
    if IsGlobalDeclarationKind(lDeclaration.Kind) then
      AddGlobalDeclaration(aDeclarations, lDeclaration.Name, aModel.UnitName, aModel.FileName, '',
        lDeclaration.TypeName, lDeclaration.Kind, lDeclaration.SectionKind, lDeclaration.Line,
        lDeclaration.Column);

  for lMember in aModel.Members do
    if SameText(lMember.Kind, 'class-var') then
      AddGlobalDeclaration(aDeclarations, lMember.Name, aModel.UnitName, aModel.FileName,
        lMember.OwnerName, lMember.TypeName, 'classvar', 'interface', lMember.Line,
        lMember.Column);
end;

function ContainsUnitName(const aUnitNames: TArray<string>; const aUnitName: string): Boolean;
var
  lUnitName: string;
begin
  for lUnitName in aUnitNames do
    if SameText(lUnitName, aUnitName) then
      Exit(True);

  Result := False;
end;

function IsVisibleDeclaration(const aModel: TDelphiSemanticUnitModel;
  const aDeclaration: TDelphiSemanticGlobalDeclaration): Boolean;
begin
  if SameText(aModel.UnitName, aDeclaration.UnitName) then
    Exit(True);

  Result := SameText(aDeclaration.SectionKind, 'interface') and
    (ContainsUnitName(aModel.InterfaceUses, aDeclaration.UnitName) or
    ContainsUnitName(aModel.ImplementationUses, aDeclaration.UnitName));
end;

function FindRoutineNameForLine(const aModel: TDelphiSemanticUnitModel; const aLine: Integer): string;
var
  lBestLine: Integer;
  lRoutine: TDelphiSemanticRoutine;
begin
  Result := '';
  lBestLine := 0;
  for lRoutine in aModel.Routines do
    if (lRoutine.Line <= aLine) and (lRoutine.Line >= lBestLine) then
    begin
      Result := lRoutine.Name;
      lBestLine := lRoutine.Line;
    end;
end;

function FindRoutineStartLineForLine(const aModel: TDelphiSemanticUnitModel;
  const aLine: Integer): Integer;
var
  lBestLine: Integer;
  lRoutine: TDelphiSemanticRoutine;
begin
  Result := 0;
  lBestLine := 0;
  for lRoutine in aModel.Routines do
    if (lRoutine.Line <= aLine) and (lRoutine.Line >= lBestLine) then
    begin
      Result := lRoutine.Line;
      lBestLine := lRoutine.Line;
    end;
end;

function HasLocalShadow(const aModel: TDelphiSemanticUnitModel; const aRoutineName,
  aName: string; const aRoutineStartLine, aReferenceLine: Integer): Boolean;
var
  lLocal: TDelphiSemanticLocal;
  lParameter: TDelphiSemanticParameter;
  lRoutine: TDelphiSemanticRoutine;
begin
  for lLocal in aModel.Locals do
    if SameText(lLocal.RoutineName, aRoutineName) and SameText(lLocal.Name, aName) and
      (lLocal.Line >= aRoutineStartLine) and (lLocal.Line < aReferenceLine) then
      Exit(True);

  for lRoutine in aModel.Routines do
    if SameText(lRoutine.Name, aRoutineName) and (lRoutine.Line = aRoutineStartLine) then
      for lParameter in lRoutine.Parameters do
        if SameText(lParameter.Name, aName) then
          Exit(True);

  Result := False;
end;

function ReadSourceLine(const aFileName: string; const aLine: Integer): string;
var
  lLines: TArray<string>;
begin
  Result := '';
  if (aFileName = '') or (aLine <= 0) or not TFile.Exists(aFileName) then
    Exit;

  lLines := TFile.ReadAllLines(aFileName);
  if aLine <= Length(lLines) then
    Result := lLines[aLine - 1];
end;

function IsIdentifierChar(const aValue: Char): Boolean;
begin
  Result := CharInSet(aValue, ['A'..'Z', 'a'..'z', '0'..'9', '_']);
end;

function IsWordAt(const aText, aName: string; const aIndex: Integer): Boolean;
var
  lAfter: Integer;
begin
  lAfter := aIndex + Length(aName);
  Result := ((aIndex = 1) or not IsIdentifierChar(aText[aIndex - 1])) and
    ((lAfter > Length(aText)) or not IsIdentifierChar(aText[lAfter]));
end;

procedure DetectNameSides(const aLine, aName: string; const aAssignPos: Integer;
  var aBeforeAssign, aAfterAssign: Boolean);
var
  lIndex: Integer;
  lLine: string;
  lName: string;
begin
  lLine := LowerCase(aLine);
  lName := LowerCase(aName);
  lIndex := Pos(lName, lLine);
  while lIndex > 0 do
  begin
    if IsWordAt(lLine, lName, lIndex) then
    begin
      if lIndex < aAssignPos then
        aBeforeAssign := True
      else
        aAfterAssign := True;
    end;
    lIndex := Pos(lName, lLine, lIndex + Length(lName));
  end;
end;

function DetectAccess(const aLine, aName: string): string;
var
  lAfterAssign: Boolean;
  lAssignPos: Integer;
  lBeforeAssign: Boolean;
begin
  if TRegEx.IsMatch(aLine, '\b(?:Inc|Dec)\s*\(\s*(?:[A-Za-z_][A-Za-z0-9_]*\.)*' +
    TRegEx.Escape(aName) + '\b', [roIgnoreCase]) then
    Exit('readwrite');

  lAssignPos := Pos(':=', aLine);
  if lAssignPos = 0 then
    Exit('read');

  lBeforeAssign := False;
  lAfterAssign := False;
  DetectNameSides(aLine, aName, lAssignPos, lBeforeAssign, lAfterAssign);
  if lBeforeAssign and lAfterAssign then
    Result := 'readwrite'
  else if lBeforeAssign then
    Result := 'write'
  else
    Result := 'read';
end;

function UsageKey(const aUnitName, aRoutineName, aName: string; const aLine: Integer): string;
begin
  Result := LowerCase(aUnitName) + '|' + LowerCase(aRoutineName) + '|' + LowerCase(aName) + '|' +
    IntToStr(aLine);
end;

function BuildCandidateText(const aCandidates: TList<TDelphiSemanticGlobalDeclaration>): string;
var
  i: Integer;
begin
  Result := '';
  for i := 0 to Pred(aCandidates.Count) do
  begin
    if Result <> '' then
      Result := Result + '; ';
    Result := Result + aCandidates[i].UnitName + '.' + aCandidates[i].Name;
  end;
end;

function MatchesWildcard(const aValue, aPattern: string): Boolean;
var
  lPattern: string;
begin
  if (aPattern = '') or SameText(aPattern, '*') then
    Exit(True);

  lPattern := TRegEx.Escape(aPattern);
  lPattern := StringReplace(lPattern, '\*', '.*', [rfReplaceAll]);
  lPattern := StringReplace(lPattern, '\?', '.', [rfReplaceAll]);
  Result := TRegEx.IsMatch(aValue, '^' + lPattern + '$', [roIgnoreCase]);
end;

function AccessMatchesFilters(const aAccess: string;
  const aFilters: TDelphiSemanticGlobalFilterOptions): Boolean;
begin
  Result := True;
  if aFilters.ReadsOnly then
    Result := SameText(aAccess, 'read') or SameText(aAccess, 'readwrite');
  if Result and aFilters.WritesOnly then
    Result := SameText(aAccess, 'write') or SameText(aAccess, 'readwrite');
end;

function DeclarationMatchesFilters(const aDeclaration: TDelphiSemanticGlobalDeclaration;
  const aFilters: TDelphiSemanticGlobalFilterOptions): Boolean;
begin
  Result := MatchesWildcard(aDeclaration.UnitName, aFilters.UnitPattern) and
    MatchesWildcard(aDeclaration.Name, aFilters.NamePattern);
end;

function UsageMatchesFilters(const aUsage: TDelphiSemanticGlobalUsage;
  const aFilters: TDelphiSemanticGlobalFilterOptions): Boolean;
begin
  Result := MatchesWildcard(aUsage.DeclaringUnitName, aFilters.UnitPattern) and
    MatchesWildcard(aUsage.Name, aFilters.NamePattern) and AccessMatchesFilters(aUsage.Access,
    aFilters);
end;

function AmbiguityMatchesFilters(const aAmbiguity: TDelphiSemanticGlobalAmbiguity;
  const aFilters: TDelphiSemanticGlobalFilterOptions): Boolean;
begin
  Result := MatchesWildcard(aAmbiguity.UnitName, aFilters.UnitPattern) and
    MatchesWildcard(aAmbiguity.Name, aFilters.NamePattern) and AccessMatchesFilters(
    aAmbiguity.Access, aFilters);
end;

function IsDeclarationUsed(const aAnalysis: TDelphiSemanticGlobalAnalysis;
  const aDeclaration: TDelphiSemanticGlobalDeclaration): Boolean;
var
  lUsage: TDelphiSemanticGlobalUsage;
begin
  for lUsage in aAnalysis.Usages do
    if SameText(lUsage.Name, aDeclaration.Name) and
      SameText(lUsage.DeclaringUnitName, aDeclaration.UnitName) then
      Exit(True);

  Result := False;
end;

function DeclarationHasMatchingAccess(const aAnalysis: TDelphiSemanticGlobalAnalysis;
  const aDeclaration: TDelphiSemanticGlobalDeclaration;
  const aFilters: TDelphiSemanticGlobalFilterOptions): Boolean;
var
  lAmbiguity: TDelphiSemanticGlobalAmbiguity;
  lCandidate: string;
  lUsage: TDelphiSemanticGlobalUsage;
begin
  if not aFilters.ReadsOnly and not aFilters.WritesOnly then
    Exit(True);

  for lUsage in aAnalysis.Usages do
    if SameText(lUsage.Name, aDeclaration.Name) and
      SameText(lUsage.DeclaringUnitName, aDeclaration.UnitName) and
      AccessMatchesFilters(lUsage.Access, aFilters) then
      Exit(True);

  lCandidate := aDeclaration.UnitName + '.' + aDeclaration.Name;
  for lAmbiguity in aAnalysis.Ambiguities do
    if ContainsText(lAmbiguity.Candidates, lCandidate) and AccessMatchesFilters(
      lAmbiguity.Access, aFilters) then
      Exit(True);

  Result := False;
end;

function ApplyFilters(const aAnalysis: TDelphiSemanticGlobalAnalysis;
  const aFilters: TDelphiSemanticGlobalFilterOptions): TDelphiSemanticGlobalAnalysis;
var
  lAmbiguities: TList<TDelphiSemanticGlobalAmbiguity>;
  lAmbiguity: TDelphiSemanticGlobalAmbiguity;
  lDeclaration: TDelphiSemanticGlobalDeclaration;
  lDeclarations: TList<TDelphiSemanticGlobalDeclaration>;
  lUsage: TDelphiSemanticGlobalUsage;
  lUsages: TList<TDelphiSemanticGlobalUsage>;
begin
  lAmbiguities := nil;
  lDeclarations := nil;
  lUsages := nil;
  try
    lDeclarations := TList<TDelphiSemanticGlobalDeclaration>.Create;
    lUsages := TList<TDelphiSemanticGlobalUsage>.Create;
    lAmbiguities := TList<TDelphiSemanticGlobalAmbiguity>.Create;

    for lUsage in aAnalysis.Usages do
      if UsageMatchesFilters(lUsage, aFilters) and not aFilters.UnusedOnly then
        lUsages.Add(lUsage);

    for lAmbiguity in aAnalysis.Ambiguities do
      if AmbiguityMatchesFilters(lAmbiguity, aFilters) and not aFilters.UnusedOnly then
        lAmbiguities.Add(lAmbiguity);

    for lDeclaration in aAnalysis.Declarations do
      if DeclarationMatchesFilters(lDeclaration, aFilters) and
        DeclarationHasMatchingAccess(aAnalysis, lDeclaration, aFilters) and
        (not aFilters.UnusedOnly or not IsDeclarationUsed(aAnalysis, lDeclaration)) then
        lDeclarations.Add(lDeclaration);

    Result.Declarations := lDeclarations.ToArray;
    Result.Usages := lUsages.ToArray;
    Result.Ambiguities := lAmbiguities.ToArray;
    Result.Diagnostics := aAnalysis.Diagnostics;
  finally
    lAmbiguities.Free;
    lUsages.Free;
    lDeclarations.Free;
  end;
end;

procedure AddUsage(const aUsages: TList<TDelphiSemanticGlobalUsage>;
  const aDeclaration: TDelphiSemanticGlobalDeclaration; const aModel: TDelphiSemanticUnitModel;
  const aRoutineName, aAccess: string; const aReference: TDelphiSemanticReference);
var
  lUsage: TDelphiSemanticGlobalUsage;
begin
  lUsage.Name := aDeclaration.Name;
  lUsage.DeclaringUnitName := aDeclaration.UnitName;
  lUsage.UnitName := aModel.UnitName;
  lUsage.RoutineName := aRoutineName;
  lUsage.FileName := aModel.FileName;
  lUsage.Access := aAccess;
  lUsage.Line := aReference.Line;
  lUsage.Column := aReference.Column;
  aUsages.Add(lUsage);
end;

procedure AddAmbiguity(const aAmbiguities: TList<TDelphiSemanticGlobalAmbiguity>;
  const aCandidates: TList<TDelphiSemanticGlobalDeclaration>; const aModel: TDelphiSemanticUnitModel;
  const aRoutineName, aAccess: string; const aReference: TDelphiSemanticReference);
var
  lAmbiguity: TDelphiSemanticGlobalAmbiguity;
begin
  lAmbiguity.Name := aReference.Name;
  lAmbiguity.UnitName := aModel.UnitName;
  lAmbiguity.RoutineName := aRoutineName;
  lAmbiguity.FileName := aModel.FileName;
  lAmbiguity.Access := aAccess;
  lAmbiguity.Candidates := BuildCandidateText(aCandidates);
  lAmbiguity.Line := aReference.Line;
  lAmbiguity.Column := aReference.Column;
  aAmbiguities.Add(lAmbiguity);
end;

procedure FindCandidates(const aDeclarations: TList<TDelphiSemanticGlobalDeclaration>;
  const aModel: TDelphiSemanticUnitModel; const aName: string;
  const aCandidates: TList<TDelphiSemanticGlobalDeclaration>);
var
  lDeclaration: TDelphiSemanticGlobalDeclaration;
begin
  for lDeclaration in aDeclarations do
    if SameText(lDeclaration.Name, aName) and IsVisibleDeclaration(aModel, lDeclaration) then
      aCandidates.Add(lDeclaration);
end;

procedure AnalyzeModelUsages(const aDeclarations: TList<TDelphiSemanticGlobalDeclaration>;
  const aUsages: TList<TDelphiSemanticGlobalUsage>;
  const aAmbiguities: TList<TDelphiSemanticGlobalAmbiguity>; const aSeenUsages: TDictionary<string,
  Boolean>; const aModel: TDelphiSemanticUnitModel);
var
  lAccess: string;
  lCandidates: TList<TDelphiSemanticGlobalDeclaration>;
  lKey: string;
  lLine: string;
  lReference: TDelphiSemanticReference;
  lRoutineName: string;
  lRoutineStartLine: Integer;
begin
  lCandidates := TList<TDelphiSemanticGlobalDeclaration>.Create;
  try
    for lReference in aModel.References do
    begin
      lRoutineName := FindRoutineNameForLine(aModel, lReference.Line);
      if lRoutineName = '' then
        Continue;

      lRoutineStartLine := FindRoutineStartLineForLine(aModel, lReference.Line);
      if HasLocalShadow(aModel, lRoutineName, lReference.Name, lRoutineStartLine,
        lReference.Line) then
        Continue;

      lKey := UsageKey(aModel.UnitName, lRoutineName, lReference.Name, lReference.Line);
      if aSeenUsages.ContainsKey(lKey) then
        Continue;

      lCandidates.Clear;
      FindCandidates(aDeclarations, aModel, lReference.Name, lCandidates);
      if lCandidates.Count = 0 then
        Continue;

      lLine := ReadSourceLine(aModel.FileName, lReference.Line);
      lAccess := DetectAccess(lLine, lReference.Name);
      if lCandidates.Count = 1 then
        AddUsage(aUsages, lCandidates[0], aModel, lRoutineName, lAccess, lReference)
      else
        AddAmbiguity(aAmbiguities, lCandidates, aModel, lRoutineName, lAccess, lReference);
      aSeenUsages.Add(lKey, True);
    end;
  finally
    lCandidates.Free;
  end;
end;

class function TDelphiSemanticGlobalAnalyzer.AnalyzeUnits(
  const aModels: TArray<TDelphiSemanticUnitModel>): TDelphiSemanticGlobalAnalysis;
var
  lFilters: TDelphiSemanticGlobalFilterOptions;
begin
  lFilters := Default(TDelphiSemanticGlobalFilterOptions);
  Result := AnalyzeUnits(aModels, lFilters);
end;

class function TDelphiSemanticGlobalAnalyzer.AnalyzeUnits(
  const aModels: TArray<TDelphiSemanticUnitModel>;
  const aFilters: TDelphiSemanticGlobalFilterOptions): TDelphiSemanticGlobalAnalysis;
var
  lAmbiguities: TList<TDelphiSemanticGlobalAmbiguity>;
  lDeclarations: TList<TDelphiSemanticGlobalDeclaration>;
  lDiagnostics: TList<TDelphiSemanticGlobalDiagnostic>;
  lModel: TDelphiSemanticUnitModel;
  lSeenUsages: TDictionary<string, Boolean>;
  lUsages: TList<TDelphiSemanticGlobalUsage>;
begin
  lAmbiguities := nil;
  lDeclarations := nil;
  lDiagnostics := nil;
  lSeenUsages := nil;
  lUsages := nil;
  try
    lDeclarations := TList<TDelphiSemanticGlobalDeclaration>.Create;
    lUsages := TList<TDelphiSemanticGlobalUsage>.Create;
    lAmbiguities := TList<TDelphiSemanticGlobalAmbiguity>.Create;
    lDiagnostics := TList<TDelphiSemanticGlobalDiagnostic>.Create;
    lSeenUsages := TDictionary<string, Boolean>.Create;

    for lModel in aModels do
    begin
      AddModelDiagnostics(lDiagnostics, lModel);
      AddModelDeclarations(lDeclarations, lModel);
    end;

    for lModel in aModels do
      AnalyzeModelUsages(lDeclarations, lUsages, lAmbiguities, lSeenUsages, lModel);

    Result.Declarations := lDeclarations.ToArray;
    Result.Usages := lUsages.ToArray;
    Result.Ambiguities := lAmbiguities.ToArray;
    Result.Diagnostics := lDiagnostics.ToArray;
    Result := ApplyFilters(Result, aFilters);
  finally
    lSeenUsages.Free;
    lDiagnostics.Free;
    lAmbiguities.Free;
    lUsages.Free;
    lDeclarations.Free;
  end;
end;

end.
