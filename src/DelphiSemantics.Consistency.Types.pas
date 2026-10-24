unit DelphiSemantics.Consistency.Types;

interface

uses
  DelphiSemantics.Model, DelphiSemantics.Resolve.TypeResolver;

type
  TDelphiSemanticConsistencyType = record
    Known: Boolean;
    ModelIndex: Integer;
    DeclarationIndex: Integer;
    Identity: TDelphiSemanticTypeIdentity;
  end;

  TDelphiSemanticConsistencyTypeResolver = record
    class function FindCompleteModelIndex(const aModels: TArray<TDelphiSemanticUnitModel>;
      const aUnit: string): Integer; static;
    class function HasCompleteTypeDeclaration(const aModel: TDelphiSemanticUnitModel;
      const aDeclaration: Integer): Boolean; static;
    class function Resolve(const aModels: TArray<TDelphiSemanticUnitModel>;
      const aTypes: TDelphiSemanticTypeIdentityIndex; const aName, aUnit: string):
      TDelphiSemanticConsistencyType; static;
  end;

implementation

uses
  System.Generics.Collections, System.RegularExpressions, System.StrUtils, System.SysUtils;

function IncompleteMemberOwner(const aModel: TDelphiSemanticUnitModel;
  const aDiagnostic: TDelphiSemanticModelDiagnostic): Integer;
var
  i, lOffset: Integer;
  lDeclaration: TDelphiSemanticDeclaration;
  lFileName, lName: string;
begin
  Result := -1;
  if not SameText(aDiagnostic.Code, 'MEMBERS_INCOMPLETE') or
    (aDiagnostic.FileName = '') or (aDiagnostic.Line < 1) then
    Exit;
  for i := 0 to High(aModel.Declarations) do
  begin
    lDeclaration := aModel.Declarations[i];
    lFileName := lDeclaration.FileName;
    if lFileName = '' then
      lFileName := aModel.FileName;
    if not SameText(lFileName, aDiagnostic.FileName) or
      (lDeclaration.Line <> aDiagnostic.Line) or
      not SameText(lDeclaration.Kind, 'type') or
      not SameText(lDeclaration.DeclarationRole, 'declaration') or
      not MatchText(lDeclaration.TypeName, ['class', 'record', 'interface']) then
      Continue;
    // DS-648: a line shared by multiple possible owners cannot isolate a diagnostic.
    if Result >= 0 then
      Exit(-1);
    lName := Copy(lDeclaration.Name, LastDelimiter('.', lDeclaration.Name) + 1, MaxInt);
    lOffset := lDeclaration.Offset;
    if (lOffset > 0) and (lOffset <= Length(aModel.SourceText)) and
      (aModel.SourceText[lOffset] = '&') then
      Inc(lOffset);
    if not SameText(lFileName, aModel.FileName) or (lName = '') or (lOffset < 1) or
      not SameText(Copy(aModel.SourceText, lOffset, Length(lName)), lName) then
      Exit(-1);
    Result := i;
  end;
end;

class function TDelphiSemanticConsistencyTypeResolver.HasCompleteTypeDeclaration(
  const aModel: TDelphiSemanticUnitModel; const aDeclaration: Integer): Boolean;
var
  lDiagnostic: TDelphiSemanticModelDiagnostic;
  lOwner: Integer;
begin
  Result := False;
  if not aModel.Success or not SameText(aModel.ScopeModelStatus, 'ast') or
    (aModel.RejectedDeclarationCount <> 0) or
    (aDeclaration < 0) or (aDeclaration > High(aModel.Declarations)) then
    Exit;
  for lDiagnostic in aModel.Diagnostics do
  begin
    lOwner := IncompleteMemberOwner(aModel, lDiagnostic);
    if (lOwner < 0) or (lOwner = aDeclaration) then
      Exit;
  end;
  Result := True;
end;

class function TDelphiSemanticConsistencyTypeResolver.FindCompleteModelIndex(
  const aModels: TArray<TDelphiSemanticUnitModel>; const aUnit: string): Integer;
var
  i: Integer;
  lDiagnostic: TDelphiSemanticModelDiagnostic;
begin
  Result := -1;
  for i := 0 to High(aModels) do
    if SameText(aModels[i].UnitName, aUnit) then
    begin
      if (Result >= 0) or not aModels[i].Success or
        not SameText(aModels[i].ScopeModelStatus, 'ast') or
        (aModels[i].RejectedDeclarationCount <> 0) then
        Exit(-1);
      // Keep unit-wide uncertainty blocking; only uniquely owned member gaps are local.
      for lDiagnostic in aModels[i].Diagnostics do
        if IncompleteMemberOwner(aModels[i], lDiagnostic) < 0 then
          Exit(-1);
      Result := i;
    end;
end;

function ResolveVisibleType(const aModel: TDelphiSemanticUnitModel;
  const aTypes: TDelphiSemanticTypeIdentityIndex; const aName: string):
  TDelphiSemanticTypeLookupResult;
var
  lUnit: string;
  lVisible: Boolean;
begin
  if Pos('.', aName) = 0 then
    Exit(aTypes.ResolveVisibleName(aName, aModel.UnitName,
      aTypes.VisibleUnitNames(aModel.UnitName, 'interface')));
  Result := aTypes.ResolveQualifiedName(aName);
  if not Result.Found then
    Exit;
  lVisible := SameText(Result.Identity.UnitName, aModel.UnitName) and
    SameText(Result.Identity.SectionKind, 'interface');
  for lUnit in aModel.InterfaceUses do
    lVisible := lVisible or (SameText(lUnit, Result.Identity.UnitName) and
      SameText(Result.Identity.SectionKind, 'interface'));
  if not lVisible then
    Result := Default(TDelphiSemanticTypeLookupResult);
end;

function FindDeclarationIndex(const aModel: TDelphiSemanticUnitModel;
  const aIdentity: TDelphiSemanticTypeIdentity): Integer;
var
  i, lCount: Integer;
begin
  Result := -1;
  if (aModel.FileName = '') or not SameText(aModel.FileName, aIdentity.SourceRange.FileName) then
    Exit;
  lCount := 0;
  for i := 0 to High(aModel.Declarations) do
    if SameText(aModel.Declarations[i].Name, aIdentity.Name) and
      SameText(aModel.Declarations[i].ScopeKind, 'unit') then
    begin
      Result := i;
      Inc(lCount);
    end;
  if lCount <> 1 then
    Exit(-1);
  // A name-only graph lookup must not select a nested or superseded declaration.
  if (aModel.Declarations[Result].Offset <> aIdentity.SourceRange.Offset) or
    not SameText(aModel.Declarations[Result].DeclarationRole, 'declaration') then
    Result := -1;
end;

function FindSourceType(const aModels: TArray<TDelphiSemanticUnitModel>;
  const aTypes: TDelphiSemanticTypeIdentityIndex; const aName, aUnit: string):
  TDelphiSemanticConsistencyType;
var
  lModel: Integer;
  lLookup: TDelphiSemanticTypeLookupResult;
begin
  Result := Default(TDelphiSemanticConsistencyType);
  lModel := TDelphiSemanticConsistencyTypeResolver.FindCompleteModelIndex(aModels, aUnit);
  if lModel < 0 then
    Exit;
  lLookup := ResolveVisibleType(aModels[lModel], aTypes, aName);
  if not lLookup.Found or lLookup.Ambiguous or (lLookup.Identity.DeclaredId.Value = '') then
    Exit;
  Result.ModelIndex := TDelphiSemanticConsistencyTypeResolver.FindCompleteModelIndex(
    aModels, lLookup.Identity.UnitName);
  if Result.ModelIndex < 0 then
    Exit;
  Result.DeclarationIndex := FindDeclarationIndex(aModels[Result.ModelIndex], lLookup.Identity);
  if Result.DeclarationIndex < 0 then
    Exit;
  if not TDelphiSemanticConsistencyTypeResolver.HasCompleteTypeDeclaration(
    aModels[Result.ModelIndex], Result.DeclarationIndex) then
    Exit;
  Result.Identity := lLookup.Identity;
  Result.Known := True;
end;

function IsTerminalType(const aDeclaration: TDelphiSemanticDeclaration): Boolean;
begin
  Result := aDeclaration.ProcedureSignature.Known or
    (SameText(aDeclaration.Kind, 'type') and
    MatchText(aDeclaration.TypeName, ['enum', 'class', 'record', 'interface']));
end;

function AliasTarget(const aDeclaration: TDelphiSemanticDeclaration;
  const aIdentity: TDelphiSemanticTypeIdentity; var aDistinctId: string): string;
var
  lMatch: TMatch;
begin
  Result := aDeclaration.TypeName.Trim;
  lMatch := TRegEx.Match(Result, '^type\s+(.+)$', [roIgnoreCase]);
  if lMatch.Success then
  begin
    if aDistinctId = '' then
      aDistinctId := aIdentity.DeclaredId.Value;
    Result := lMatch.Groups[1].Value.Trim;
  end;
end;

class function TDelphiSemanticConsistencyTypeResolver.Resolve(
  const aModels: TArray<TDelphiSemanticUnitModel>;
  const aTypes: TDelphiSemanticTypeIdentityIndex; const aName, aUnit: string):
  TDelphiSemanticConsistencyType;
var
  lName, lUnit, lDistinctId: string;
  lCurrent: TDelphiSemanticConsistencyType;
  lDeclaration: TDelphiSemanticDeclaration;
  lVisited: TList<string>;
begin
  Result := Default(TDelphiSemanticConsistencyType);
  lName := aName;
  lUnit := aUnit;
  lDistinctId := '';
  lVisited := TList<string>.Create;
  try
    while lName <> '' do
    begin
      lCurrent := FindSourceType(aModels, aTypes, lName, lUnit);
      if not lCurrent.Known or lVisited.Contains(lCurrent.Identity.DeclaredId.Value) then
        Exit;
      lVisited.Add(lCurrent.Identity.DeclaredId.Value);
      lDeclaration := aModels[lCurrent.ModelIndex].Declarations[lCurrent.DeclarationIndex];
      if IsTerminalType(lDeclaration) then
      begin
        Result := lCurrent;
        if lDistinctId <> '' then
          Result.Identity.DeclaredId.Value := lDistinctId;
        Exit;
      end;
      if not SameText(lDeclaration.Kind, 'type-alias') then
        Exit;
      lName := AliasTarget(lDeclaration, lCurrent.Identity, lDistinctId);
      lUnit := aModels[lCurrent.ModelIndex].UnitName;
    end;
  finally
    lVisited.Free;
  end;
end;

end.
