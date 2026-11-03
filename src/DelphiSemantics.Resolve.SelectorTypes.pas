unit DelphiSemantics.Resolve.SelectorTypes;

interface

uses
  DelphiSemantics.Model, DelphiSemantics.Resolve;

function VisibleSelectorModels(const aModel: TDelphiSemanticUnitModel;
  const aContext: TDelphiSemanticResolveContext): TArray<TDelphiSemanticUnitModel>;
function TryResolveSelectorType(const aContext: TDelphiSemanticResolveContext;
  var aCurrentModel: TDelphiSemanticUnitModel; var aSectionKind: string;
  var aTypeName: string): Boolean; overload;
function TryApplyDereferencePostfix(const aContext: TDelphiSemanticResolveContext;
  var aCurrentModel: TDelphiSemanticUnitModel; var aSectionKind, aTypeName: string): Boolean;
function TryApplySelectorPostfix(const aContext: TDelphiSemanticResolveContext;
  var aCurrentModel: TDelphiSemanticUnitModel; var aSectionKind: string;
  const aTypeName: string;
  const aIndexed, aDereferenced, aIndexBeforeDereference: Boolean;
  out aResultTypeName: string): Boolean;
function ParseSelectorToken(const aToken: string; out aName: string; out aIndexed,
  aDereferenced, aIndexBeforeDereference: Boolean): Boolean;
function TryFindSelectorTypeDeclaration(const aModel: TDelphiSemanticUnitModel;
  const aSectionKind, aName: string; out aDeclaration: TDelphiSemanticDeclaration): Boolean;

// Shared syntax normalization only; this performs no visibility lookup.
function NormalizeTypeReference(const aTypeName: string): string;

implementation

uses
  System.StrUtils, System.SysUtils,
  DelphiSemantics.SourceConditionals;

type
  TSelectorAliasTrail = array[0..15] of string;

function IsImplementationLikeSection(const aSectionKind: string): Boolean;
begin
  Result := MatchText(aSectionKind, ['implementation', 'initialization', 'finalization']);
end;

function IsVisibleSection(const aContextSection, aSymbolSection: string): Boolean;
begin
  Result := SameText(aSymbolSection, 'interface') or IsImplementationLikeSection(aContextSection);
end;

function IsInlineArrayType(const aTypeName: string): Boolean;
begin
  // The keyword boundary distinguishes array declarations from names such as ArrayRecPtr.
  Result := (Length(aTypeName) > 5) and StartsText('array', aTypeName) and
    CharInSet(aTypeName[6], [' ', #9, #10, #13, '[']);
end;

function NormalizeTypeReference(const aTypeName: string): string;
var
  lLower: string;
  lPos: Integer;
begin
  Result := aTypeName.Trim;
  lLower := LowerCase(Result);
  lPos := Pos(' of ', lLower);
  if IsInlineArrayType(Result) and (lPos > 0) then
    Result := Copy(Result, lPos + 4, MaxInt).Trim;
end;

function UsesSelectorUnit(const aModel: TDelphiSemanticUnitModel;
  const aSectionKind, aUnitName: string): Boolean;
var
  lUsedUnit: string;
begin
  for lUsedUnit in aModel.InterfaceUses do
    if SameText(lUsedUnit, aUnitName) then
      Exit(True);
  if IsImplementationLikeSection(aSectionKind) then
    for lUsedUnit in aModel.ImplementationUses do
      if SameText(lUsedUnit, aUnitName) then
        Exit(True);
  Result := False;
end;

function VisibleSelectorModels(const aModel: TDelphiSemanticUnitModel;
  const aContext: TDelphiSemanticResolveContext): TArray<TDelphiSemanticUnitModel>;
var
  lIndexedModel: TDelphiSemanticUnitModel;
  lLength: Integer;
begin
  Result := nil;
  for lIndexedModel in aContext.IndexedUnitModels do
    if UsesSelectorUnit(aModel, aContext.SectionKind, lIndexedModel.UnitName) then
    begin
      lLength := Length(Result);
      SetLength(Result, lLength + 1);
      Result[lLength] := lIndexedModel;
    end;
end;

function FindSelectorTypeInModel(const aModel: TDelphiSemanticUnitModel;
  const aSectionKind, aName: string; out aDeclaration: TDelphiSemanticDeclaration): Integer;
var
  lDeclaration: TDelphiSemanticDeclaration;
begin
  Result := 0;
  aDeclaration := Default(TDelphiSemanticDeclaration);
  for lDeclaration in aModel.Declarations do
    if SameText(lDeclaration.Name, aName) and
      (SameText(lDeclaration.Kind, 'type') or SameText(lDeclaration.Kind, 'type-alias')) and
      IsVisibleSection(aSectionKind, lDeclaration.SectionKind) and
      ((lDeclaration.ScopeKind = '') or SameText(lDeclaration.ScopeKind, 'unit')) then
    begin
      Inc(Result);
      aDeclaration := lDeclaration;
    end;
end;

function FindVisibleSelectorType(const aContext: TDelphiSemanticResolveContext;
  const aCurrentModel: TDelphiSemanticUnitModel; const aSectionKind, aName: string;
  out aDeclaration: TDelphiSemanticDeclaration;
  out aDeclaringModel: TDelphiSemanticUnitModel): Integer;
var
  lCandidate: TDelphiSemanticDeclaration;
  lCount: Integer;
  lModel: TDelphiSemanticUnitModel;
  lImports: TArray<string>;
  lIndexed: Boolean;
  i: Integer;
begin
  Result := FindSelectorTypeInModel(aCurrentModel, aSectionKind, aName, aDeclaration);
  aDeclaringModel := aCurrentModel;
  if Result > 0 then
    Exit;

  if TDelphiSemanticSourceConditionals.UsesDirectiveUnproved(aCurrentModel.SourceText) then
    Exit(-1);

  for lModel in aContext.IndexedUnitModels do
  begin
    if SameText(lModel.UnitName, aCurrentModel.UnitName) or
      not UsesSelectorUnit(aCurrentModel, aSectionKind, lModel.UnitName) then
      Continue;
    lCount := FindSelectorTypeInModel(lModel, 'interface', aName, lCandidate);
    if lCount > 0 then
    begin
      Inc(Result, lCount);
      aDeclaration := lCandidate;
      aDeclaringModel := lModel;
    end;
  end;
  if Result <> 1 then
    Exit;

  // DS-719: an indexed candidate cannot close a later unknown import.
  // Keep legacy ambiguity/refusals; this check can only reject a resolution.
  lImports := aCurrentModel.InterfaceUses;
  if IsImplementationLikeSection(aSectionKind) then
    lImports := lImports + aCurrentModel.ImplementationUses;
  for i := High(lImports) downto 0 do
  begin
    if SameText(lImports[i], aDeclaringModel.UnitName) then
      Exit;
    lIndexed := False;
    for lModel in aContext.IndexedUnitModels do
      if SameText(lModel.UnitName, lImports[i]) then
      begin
        lIndexed := True;
        Break;
      end;
    if not lIndexed then
      Exit(-1);
  end;
end;

function TryResolveSelectorType(const aContext: TDelphiSemanticResolveContext;
  var aCurrentModel: TDelphiSemanticUnitModel; var aSectionKind: string;
  var aTypeName: string; out aUnproved: Boolean): Boolean; overload;
var
  lDeclaration: TDelphiSemanticDeclaration;
  lDeclaringModel: TDelphiSemanticUnitModel;
  lDepth: Integer;
  lCount: Integer;
  lKey: string;
  lSeen: TSelectorAliasTrail;
  i: Integer;
begin
  aUnproved := False;
  lSeen := Default(TSelectorAliasTrail);
  aTypeName := aTypeName.Trim;
  for lDepth := 0 to High(lSeen) do
  begin
    if (aTypeName = '') then
      Exit(False);
    if (aTypeName[1] = '^') or IsInlineArrayType(aTypeName) then
      Exit(True);
    lKey := LowerCase(aCurrentModel.FileName + '|' + aCurrentModel.UnitName + '|' +
      aSectionKind + '|' + aTypeName);
    for i := 0 to lDepth - 1 do
      if lSeen[i] = lKey then
        Exit(False);
    lSeen[lDepth] := lKey;
    lCount := FindVisibleSelectorType(aContext, aCurrentModel, aSectionKind, aTypeName,
      lDeclaration, lDeclaringModel);
    if lCount <> 1 then
    begin
      aUnproved := lCount < 0;
      Exit(False);
    end;
    aCurrentModel := lDeclaringModel;
    aSectionKind := lDeclaration.SectionKind;
    if not SameText(lDeclaration.Kind, 'type-alias') then
      Exit(True);
    aTypeName := lDeclaration.TypeName.Trim;
  end;
  Result := False;
end;

function TryResolveSelectorType(const aContext: TDelphiSemanticResolveContext;
  var aCurrentModel: TDelphiSemanticUnitModel; var aSectionKind: string;
  var aTypeName: string): Boolean; overload;
var
  lUnproved: Boolean;
begin
  Result := TryResolveSelectorType(aContext, aCurrentModel, aSectionKind,
    aTypeName, lUnproved);
end;

function TryFindDefaultIndexedProperty(const aModel: TDelphiSemanticUnitModel;
  const aOwnerName: string; out aMember: TDelphiSemanticMember): Boolean;
var
  lMember: TDelphiSemanticMember;
begin
  for lMember in aModel.Members do
    if SameText(lMember.OwnerName, aOwnerName) and lMember.IsIndexed and lMember.IsDefault then
    begin
      aMember := lMember;
      Exit(True);
    end;

  aMember := Default(TDelphiSemanticMember);
  Result := False;
end;

function TryApplyDereferencePostfix(const aContext: TDelphiSemanticResolveContext;
  var aCurrentModel: TDelphiSemanticUnitModel; var aSectionKind, aTypeName: string): Boolean;
begin
  if not TryResolveSelectorType(aContext, aCurrentModel, aSectionKind, aTypeName) then
    Exit(False);
  if (aTypeName <> '') and (aTypeName[1] = '^') then
  begin
    aTypeName := Copy(aTypeName, 2, MaxInt).Trim;
    Exit(TryResolveSelectorType(aContext, aCurrentModel, aSectionKind, aTypeName));
  end;

  Result := False;
end;

function TryApplyIndexPostfix(const aContext: TDelphiSemanticResolveContext;
  var aCurrentModel: TDelphiSemanticUnitModel; var aSectionKind, aTypeName: string): Boolean;
var
  lMember: TDelphiSemanticMember;
begin
  if not TryResolveSelectorType(aContext, aCurrentModel, aSectionKind, aTypeName) then
    Exit(False);
  if IsInlineArrayType(aTypeName) then
  begin
    aTypeName := NormalizeTypeReference(aTypeName);
    Exit(TryResolveSelectorType(aContext, aCurrentModel, aSectionKind, aTypeName));
  end;

  if TryFindDefaultIndexedProperty(aCurrentModel, aTypeName, lMember) then
  begin
    aTypeName := lMember.TypeName;
    Exit(TryResolveSelectorType(aContext, aCurrentModel, aSectionKind, aTypeName));
  end;

  Result := False;
end;

function TryApplySelectorPostfix(const aContext: TDelphiSemanticResolveContext;
  var aCurrentModel: TDelphiSemanticUnitModel; var aSectionKind: string;
  const aTypeName: string;
  const aIndexed, aDereferenced, aIndexBeforeDereference: Boolean;
  out aResultTypeName: string): Boolean;
var
  lResolvedModel: TDelphiSemanticUnitModel;
  lResolvedSection: string;
  lResolvedTypeName: string;
  lTypeName: string;
  lUnproved: Boolean;
begin
  aResultTypeName := '';
  lTypeName := aTypeName;
  if aIndexed and aDereferenced and not aIndexBeforeDereference then
  begin
    if not TryApplyDereferencePostfix(aContext, aCurrentModel, aSectionKind, lTypeName) or
      not TryApplyIndexPostfix(aContext, aCurrentModel, aSectionKind, lTypeName) then
      Exit(False);
  end else if aIndexed then
  begin
    if not TryApplyIndexPostfix(aContext, aCurrentModel, aSectionKind, lTypeName) then
      Exit(False);
    if aDereferenced and not TryApplyDereferencePostfix(aContext, aCurrentModel,
      aSectionKind, lTypeName) then
      Exit(False);
  end else if aDereferenced then
  begin
    if not TryApplyDereferencePostfix(aContext, aCurrentModel, aSectionKind, lTypeName) then
      Exit(False);
  end;

  if not (aIndexed or aDereferenced) then
  begin
    // The member is already bound. Its result type can remain unknown until a later member hop.
    lResolvedModel := aCurrentModel;
    lResolvedSection := aSectionKind;
    lResolvedTypeName := lTypeName;
    if TryResolveSelectorType(aContext, lResolvedModel, lResolvedSection,
      lResolvedTypeName, lUnproved) then
    begin
      aCurrentModel := lResolvedModel;
      aSectionKind := lResolvedSection;
      lTypeName := lResolvedTypeName;
    end else if lUnproved then
      Exit(False);
  end;
  aResultTypeName := lTypeName;
  Result := True;
end;

function ParseSelectorToken(const aToken: string; out aName: string; out aIndexed,
  aDereferenced, aIndexBeforeDereference: Boolean): Boolean;
var
  lBracketPos: Integer;
  lDereferencePos: Integer;
begin
  aName := aToken.Trim;
  lBracketPos := Pos('[', aName);
  lDereferencePos := Pos('^', aName);
  aIndexed := lBracketPos > 0;
  aDereferenced := lDereferencePos > 0;
  aIndexBeforeDereference := aIndexed and ((lDereferencePos = 0) or
    (lBracketPos < lDereferencePos));
  if lBracketPos > 0 then
    aName := Copy(aName, 1, lBracketPos - 1).Trim;
  aName := StringReplace(aName, '^', '', [rfReplaceAll]).Trim;
  Result := aName <> '';
end;

function TryFindSelectorTypeDeclaration(const aModel: TDelphiSemanticUnitModel;
  const aSectionKind, aName: string; out aDeclaration: TDelphiSemanticDeclaration): Boolean;
begin
  Result := FindSelectorTypeInModel(aModel, aSectionKind, aName, aDeclaration) = 1;
end;

end.
