unit DelphiSemantics.Consistency.EventBindings;

interface

uses
  DelphiSemantics.Model, DelphiSemantics.Resolve.TypeResolver;

type
  TDelphiSemanticEventBinding = record
    UnitName: string;
    FormClassName: string;
    ComponentClassName: string;
    EventName: string;
    HandlerName: string;
  end;

  TDelphiSemanticEventEvidence = record
    UnitName: string;
    FileName: string;
    OwnerName: string;
    Name: string;
    Line: Integer;
    Column: Integer;
  end;

  TDelphiSemanticEventBindingResult = record
    Status: string;
    Reason: string;
    EventProperty: TDelphiSemanticEventEvidence;
    EventType: TDelphiSemanticEventEvidence;
    Handler: TDelphiSemanticEventEvidence;
  end;

  TDelphiSemanticClassAncestry = record
    Classes: TArray<TDelphiSemanticTypeIdentity>;
    Complete: Boolean;
    Reason: string;
  end;

  TDelphiSemanticEventBindingResolver = record
    class function ResolveInContext(const aModels: TArray<TDelphiSemanticUnitModel>;
      const aTypes: TDelphiSemanticTypeIdentityIndex; const aBinding: TDelphiSemanticEventBinding;
      const aComponentUnitName: string): TDelphiSemanticEventBindingResult; static;
    class function InspectClassAncestry(const aModels: TArray<TDelphiSemanticUnitModel>;
      const aTypes: TDelphiSemanticTypeIdentityIndex; const aUnitName, aClassName: string):
      TDelphiSemanticClassAncestry; static;
    class function Resolve(const aModels: TArray<TDelphiSemanticUnitModel>;
      const aTypes: TDelphiSemanticTypeIdentityIndex;
      const aBinding: TDelphiSemanticEventBinding): TDelphiSemanticEventBindingResult; static;
  end;

implementation

uses
  System.SysUtils,
  DelphiSemantics.Consistency.EventSignatures, DelphiSemantics.Consistency.Types;




type
  TEventMemberLookup = (emUnknown, emFound, emMissing);

  TResolvedEventType = record
    ModelIndex: Integer;
    Declaration: TDelphiSemanticDeclaration;
  end;

function IsOrdinaryPropertyType(const aDeclaration: TDelphiSemanticDeclaration): Boolean;
begin
  Result := SameText(aDeclaration.Kind, 'type') and
    SameText(aDeclaration.DeclarationRole, 'declaration') and
    (SameText(aDeclaration.TypeName, 'enum') or SameText(aDeclaration.TypeName, 'class') or
    SameText(aDeclaration.TypeName, 'record') or SameText(aDeclaration.TypeName, 'interface'));
end;
function IsEventProperty(const aDeclaration: TDelphiSemanticDeclaration;
  var aResult: TDelphiSemanticEventBindingResult): Boolean;
begin
  Result := False;
  if IsOrdinaryPropertyType(aDeclaration) then
  begin
    aResult.Status := 'not-event';
    aResult.Reason := 'binding.property-not-event';
    Exit;
  end;
  Result := aDeclaration.ProcedureSignature.Known;
end;
function FindCompleteModelIndex(const aModels: TArray<TDelphiSemanticUnitModel>;
  const aUnit: string): Integer;
begin
  Result := TDelphiSemanticConsistencyTypeResolver.FindCompleteModelIndex(aModels, aUnit);
end;

function ResolveVisibleType(const aModels: TArray<TDelphiSemanticUnitModel>;
  const aTypes: TDelphiSemanticTypeIdentityIndex; const aName: string;
  const aModel: Integer): TDelphiSemanticTypeLookupResult;
var
  lUnit: string;
  lVisible: Boolean;
begin
  if Pos('.', aName) = 0 then
    Exit(aTypes.ResolveVisibleName(aName, aModels[aModel].UnitName, aModels[aModel].InterfaceUses));
  Result := aTypes.ResolveQualifiedName(aName);
  if not Result.Found then
    Exit;
  lVisible := SameText(Result.Identity.UnitName, aModels[aModel].UnitName);
  for lUnit in aModels[aModel].InterfaceUses do
    lVisible := lVisible or (SameText(lUnit, Result.Identity.UnitName) and
      SameText(Result.Identity.SectionKind, 'interface'));
  if not lVisible then
    Result := Default(TDelphiSemanticTypeLookupResult);
end;

function HasCompleteClassDeclaration(const aModel: TDelphiSemanticUnitModel;
  const aName: string): Boolean;
var
  i, lDeclaration: Integer;
begin
  lDeclaration := -1;
  for i := 0 to High(aModel.Declarations) do
    if SameText(aModel.Declarations[i].Name, aName) and
      SameText(aModel.Declarations[i].ScopeKind, 'unit') then
    begin
      if (lDeclaration >= 0) or not SameText(aModel.Declarations[i].Kind, 'type') or
        not SameText(aModel.Declarations[i].DeclarationRole, 'declaration') then
        Exit(False);
      lDeclaration := i;
    end;
  Result := TDelphiSemanticConsistencyTypeResolver.HasCompleteTypeDeclaration(
    aModel, lDeclaration);
end;

function TrySourceClass(const aModels: TArray<TDelphiSemanticUnitModel>;
  const aType: TDelphiSemanticTypeLookupResult; out aModel: Integer; out aReason: string): Boolean;
begin
  Result := False;
  aModel := -1;
  aReason := 'ancestry.type-unresolved';
  if not aType.Found or aType.Ambiguous then
    Exit;
  aReason := 'ancestry.class-alias-unsupported';
  if SameText(aType.Identity.Kind, 'type-alias') then
    Exit;
  aReason := 'ancestry.not-source-class';
  if (aType.Identity.DeclaredId.Value = '') or not SameText(aType.Identity.CanonicalName, 'class') then
    Exit;
  aReason := 'ancestry.model-incomplete';
  aModel := FindCompleteModelIndex(aModels, aType.Identity.UnitName);
  if aModel < 0 then
    Exit;
  aReason := 'ancestry.declaration-incomplete';
  if not HasCompleteClassDeclaration(aModels[aModel], aType.Identity.Name) then
    Exit;
  aReason := '';
  Result := True;
end;

class function TDelphiSemanticEventBindingResolver.InspectClassAncestry(
  const aModels: TArray<TDelphiSemanticUnitModel>; const aTypes: TDelphiSemanticTypeIdentityIndex;
  const aUnitName, aClassName: string): TDelphiSemanticClassAncestry;
var
  lCurrent: TDelphiSemanticTypeLookupResult;
  lModel, lOrigin: Integer;
  lPrevious: TDelphiSemanticTypeIdentity;
  lReason: string;
begin
  Result := Default(TDelphiSemanticClassAncestry);
  Result.Reason := 'ancestry.model-incomplete';
  lOrigin := FindCompleteModelIndex(aModels, aUnitName);
  if lOrigin < 0 then
    Exit;
  lCurrent := ResolveVisibleType(aModels, aTypes, aClassName, lOrigin);
  while TrySourceClass(aModels, lCurrent, lModel, lReason) do
  begin
    for lPrevious in Result.Classes do
      if lPrevious.DeclaredId.Value = lCurrent.Identity.DeclaredId.Value then
      begin
        Result.Reason := 'ancestry.cycle';
        Exit;
      end;
    SetLength(Result.Classes, Length(Result.Classes) + 1);
    Result.Classes[High(Result.Classes)] := lCurrent.Identity;
    if lCurrent.Identity.BaseTypeName = '' then
    begin
      Result.Complete := True;
      Result.Reason := 'ancestry.complete';
      Exit;
    end;
    lCurrent := ResolveVisibleType(aModels, aTypes, lCurrent.Identity.BaseTypeName, lModel);
  end;
  Result.Reason := lReason;
end;

class function TDelphiSemanticEventBindingResolver.Resolve(
  const aModels: TArray<TDelphiSemanticUnitModel>;
  const aTypes: TDelphiSemanticTypeIdentityIndex;
  const aBinding: TDelphiSemanticEventBinding): TDelphiSemanticEventBindingResult;
begin
  Result := ResolveInContext(aModels, aTypes, aBinding, aBinding.UnitName);
end;

class function TDelphiSemanticEventBindingResolver.ResolveInContext(
  const aModels: TArray<TDelphiSemanticUnitModel>;
  const aTypes: TDelphiSemanticTypeIdentityIndex;
  const aBinding: TDelphiSemanticEventBinding;
  const aComponentUnitName: string): TDelphiSemanticEventBindingResult;
var
  lOrigin, lEventModel, lHandlerModel: Integer;
  lProperty: TDelphiSemanticMember;
  lHandler: TDelphiSemanticMember;
  lEventType: TResolvedEventType;
  lComparison: TDelphiSemanticEventComparison;

  function ModelIndex(const aUnit: string): Integer;
  begin
    Result := FindCompleteModelIndex(aModels, aUnit);
  end;

  function ResolveType(const aName: string; const aModel: Integer): TDelphiSemanticTypeLookupResult;
  begin
    Result := ResolveVisibleType(aModels, aTypes, aName, aModel);
  end;

  function Evidence(const aModel: Integer; const aOwner, aName: string;
    const aLine, aColumn: Integer): TDelphiSemanticEventEvidence;
  begin
    Result.UnitName := aModels[aModel].UnitName;
    Result.FileName := aModels[aModel].FileName;
    Result.OwnerName := aOwner;
    Result.Name := aName;
    Result.Line := aLine;
    Result.Column := aColumn;
  end;

  function FindEventType: Boolean;
  var
    lType: TDelphiSemanticConsistencyType;
  begin
    lType := TDelphiSemanticConsistencyTypeResolver.Resolve(aModels, aTypes,
      lProperty.TypeName, aModels[lEventModel].UnitName);
    Result := lType.Known;
    if not Result then
      Exit;
    lEventType.ModelIndex := lType.ModelIndex;
    lEventType.Declaration := aModels[lType.ModelIndex].Declarations[lType.DeclarationIndex];
  end;

  function FindMember(const aClass, aName: string; const aOrigin: Integer; const aRoutine: Boolean;
    out aModel: Integer): TEventMemberLookup;
  var
    lCurrent: TDelphiSemanticTypeLookupResult;
    lVisited: TArray<string>;
    lId: string;
    lMember: TDelphiSemanticMember;

    lMatches: Integer;
  begin
    Result := TEventMemberLookup.emUnknown;
    if aOrigin < 0 then
      Exit;
    lCurrent := ResolveType(aClass, aOrigin);
    while lCurrent.Found and not lCurrent.Ambiguous do
    begin
      if (lCurrent.Identity.DeclaredId.Value = '') or
        not SameText(lCurrent.Identity.CanonicalName, 'class') then
        Exit;
      for lId in lVisited do
        if lId = lCurrent.Identity.DeclaredId.Value then
          Exit;
      SetLength(lVisited, Length(lVisited) + 1);
      lVisited[High(lVisited)] := lCurrent.Identity.DeclaredId.Value;
      aModel := ModelIndex(lCurrent.Identity.UnitName);
      if (aModel < 0) or not HasCompleteClassDeclaration(aModels[aModel],
        lCurrent.Identity.Name) then
        Exit;
      lMatches := 0;
      for lMember in aModels[aModel].Members do
        if SameText(lMember.OwnerName, lCurrent.Identity.Name) and
          SameText(lMember.Name, aName) then
        begin
          Inc(lMatches);
          if aRoutine then
            lHandler := lMember
          else
            lProperty := lMember;
        end;
      if lMatches > 0 then
      begin
        if lMatches = 1 then
          Result := TEventMemberLookup.emFound;
        Exit;
      end;
      if lCurrent.Identity.BaseTypeName = '' then
      begin
        // Implicit System.TObject has no published streaming handlers.
        Result := TEventMemberLookup.emMissing;
        Exit;
      end;
      lCurrent := ResolveType(lCurrent.Identity.BaseTypeName, aModel);
    end;
  end;

begin
  Result := Default(TDelphiSemanticEventBindingResult);
  lEventType := Default(TResolvedEventType);
  Result.Status := 'unknown';
  Result.Reason := 'binding.unresolved';
  lOrigin := ModelIndex(aBinding.UnitName);
  if lOrigin < 0 then
    Exit;
  if FindMember(aBinding.ComponentClassName, aBinding.EventName,
    ModelIndex(aComponentUnitName), False, lEventModel) <>
    TEventMemberLookup.emFound then
    Exit;
  Result.EventProperty := Evidence(lEventModel, lProperty.OwnerName, lProperty.Name,
    lProperty.Line, lProperty.Column);
  if not SameText(lProperty.Kind, 'property') or lProperty.IsIndexed or
    not SameText(lProperty.Visibility, 'published') then
    Exit;
  if not FindEventType then
    Exit;
  Result.EventType := Evidence(lEventType.ModelIndex, '', lEventType.Declaration.Name,
    lEventType.Declaration.Line, lEventType.Declaration.Column);
  if not IsEventProperty(lEventType.Declaration, Result) then
    Exit;
  case FindMember(aBinding.FormClassName, aBinding.HandlerName, lOrigin, True, lHandlerModel) of
    TEventMemberLookup.emUnknown:
      Exit;
    TEventMemberLookup.emMissing:
      begin
        Result.Status := 'missing-handler';
        Result.Reason := 'binding.handler-missing';
        Exit;
      end;
    TEventMemberLookup.emFound:
      if not SameText(lHandler.Kind, 'method') or
        not SameText(lHandler.Visibility, 'published') then
        Exit;
  end;
  Result.Handler := Evidence(lHandlerModel, lHandler.OwnerName, lHandler.Name,
    lHandler.Line, lHandler.Column);
  lComparison := TDelphiSemanticEventSignatureComparer.CompareInContext(
    lEventType.Declaration.ProcedureSignature, lHandler.ProcedureSignature,
    aModels[lEventType.ModelIndex].UnitName, aModels[lHandlerModel].UnitName,
    aModels, aTypes);
  Result.Status := lComparison.Status;
  Result.Reason := lComparison.Reason;
end;

end.
