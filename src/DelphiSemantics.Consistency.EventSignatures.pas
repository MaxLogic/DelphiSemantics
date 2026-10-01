unit DelphiSemantics.Consistency.EventSignatures;

interface

uses
  DelphiSemantics.Model, DelphiSemantics.Resolve.TypeResolver;

type
  TDelphiSemanticEventComparison = record
    Status: string;
    Reason: string;
  end;

  TDelphiSemanticEventSignatureComparer = record
    class function CompareInContext(const aEvent, aHandler: TDelphiSemanticProcedureSignature;
      const aEventUnit, aHandlerUnit: string; const aModels: TArray<TDelphiSemanticUnitModel>;
      const aTypes: TDelphiSemanticTypeIdentityIndex): TDelphiSemanticEventComparison; static;
    class function Compare(const aEvent, aHandler: TDelphiSemanticProcedureSignature;
      const aEventUnit, aHandlerUnit: string; const aEventUses, aHandlerUses: TArray<string>;
      const aTypes: TDelphiSemanticTypeIdentityIndex): TDelphiSemanticEventComparison; static;
  end;

implementation

uses
  System.SysUtils,
  DelphiSemantics.Consistency.Types;

type
  TSignatureContext = record
    SourceBacked: Boolean;
    EventUnit, HandlerUnit: string;
    EventUses, HandlerUses: TArray<string>;
    Models: TArray<TDelphiSemanticUnitModel>;
    Types: TDelphiSemanticTypeIdentityIndex;
  end;

function ResolveSignatureType(const aName, aUnit: string; const aUses: TArray<string>;
  const aTypes: TDelphiSemanticTypeIdentityIndex): TDelphiSemanticTypeLookupResult;
var
  lUnit: string;
  lVisible: Boolean;
begin
  if Pos('.', aName) = 0 then
    Exit(aTypes.ResolveVisibleName(aName, aUnit, aUses));
  Result := aTypes.ResolveQualifiedName(aName);
  if not Result.Found then
    Exit;
  lVisible := SameText(Result.Identity.UnitName, aUnit);
  for lUnit in aUses do
    lVisible := lVisible or (SameText(lUnit, Result.Identity.UnitName) and
      SameText(Result.Identity.SectionKind, 'interface'));
  if not lVisible then
    Result := Default(TDelphiSemanticTypeLookupResult);
end;

function SourceTypeIdentity(const aName, aUnit: string; const aContext: TSignatureContext): string;
var
  lType: TDelphiSemanticConsistencyType;
begin
  Result := '';
  lType := TDelphiSemanticConsistencyTypeResolver.Resolve(aContext.Models, aContext.Types,
    aName, aUnit);
  if not lType.Known then
    Exit;
  // Procedural/structured parameter compatibility needs its own compiler-backed contract.
  if SameText(aContext.Models[lType.ModelIndex].Declarations[lType.DeclarationIndex].Kind,
    'type') then
    Result := lType.Identity.DeclaredId.Value;
end;

function CompareSourceTypes(const aEventType, aHandlerType: string;
  const aContext: TSignatureContext): string;
var
  lEventId, lHandlerId: string;
begin
  lEventId := SourceTypeIdentity(aEventType, aContext.EventUnit, aContext);
  lHandlerId := SourceTypeIdentity(aHandlerType, aContext.HandlerUnit, aContext);
  if (lEventId = '') or (lHandlerId = '') then
    Exit('unknown');
  if lEventId = lHandlerId then
    Result := 'match'
  else
    Result := 'mismatch';
end;

function CompareType(const aEventType, aHandlerType: string;
  const aContext: TSignatureContext): string;
var
  lEventType: TDelphiSemanticTypeLookupResult;
  lHandlerType: TDelphiSemanticTypeLookupResult;
begin
  if aContext.SourceBacked then
    Exit(CompareSourceTypes(aEventType, aHandlerType, aContext));
  lEventType := ResolveSignatureType(aEventType, aContext.EventUnit, aContext.EventUses,
    aContext.Types);
  lHandlerType := ResolveSignatureType(aHandlerType, aContext.HandlerUnit, aContext.HandlerUses,
    aContext.Types);
  if not lEventType.Found or lEventType.Ambiguous or not lHandlerType.Found or
    lHandlerType.Ambiguous or (lEventType.Identity.DeclaredId.Value = '') or
    (lHandlerType.Identity.DeclaredId.Value = '') then
    Exit('unknown');
  if SameText(lEventType.Identity.Kind, 'type-alias') or
    SameText(lHandlerType.Identity.Kind, 'type-alias') then
    Exit('unknown');
  if lEventType.Identity.DeclaredId.Value = lHandlerType.Identity.DeclaredId.Value then
    Result := 'match'
  else
    Result := 'mismatch';
end;

function EffectiveCallingConvention(const aConvention: string): string;
begin
  if aConvention = '' then
    Result := 'register'
  else
    Result := aConvention;
end;

function CompareSignatures(
  const aEvent, aHandler: TDelphiSemanticProcedureSignature;
  const aContext: TSignatureContext): TDelphiSemanticEventComparison;
var
  i: Integer;
  lTypeStatus: string;
begin
  Result.Status := 'unknown';
  Result.Reason := 'signature.unresolved';
  if not aEvent.Known or not aHandler.Known then
    Exit;
  Result.Reason := 'signature.event-not-method-pointer';
  if not aEvent.OfObject then
    Exit;
  Result.Status := 'mismatch';
  Result.Reason := 'signature.kind';
  if not SameText(aEvent.Kind, aHandler.Kind) then
    Exit;
  Result.Reason := 'signature.calling-convention';
  if not SameText(EffectiveCallingConvention(aEvent.CallingConvention),
    EffectiveCallingConvention(aHandler.CallingConvention)) then
    Exit;
  Result.Reason := 'signature.parameter-count';
  if Length(aEvent.Parameters) <> Length(aHandler.Parameters) then
    Exit;
  for i := 0 to High(aEvent.Parameters) do
  begin
    Result.Reason := 'signature.parameter-mode';
    if not SameText(aEvent.Parameters[i].Modifier, aHandler.Parameters[i].Modifier) then
      Exit;
    lTypeStatus := CompareType(aEvent.Parameters[i].TypeName, aHandler.Parameters[i].TypeName,
      aContext);
    if lTypeStatus <> 'match' then
    begin
      Result.Status := lTypeStatus;
      Result.Reason := 'signature.parameter-type';
      Exit;
    end;
  end;
  if SameText(aEvent.Kind, 'function') then
  begin
    lTypeStatus := CompareType(aEvent.ReturnType, aHandler.ReturnType, aContext);
    if lTypeStatus <> 'match' then
    begin
      Result.Status := lTypeStatus;
      Result.Reason := 'signature.return-type';
      Exit;
    end;
  end;
  Result.Status := 'match';
  Result.Reason := '';
end;

class function TDelphiSemanticEventSignatureComparer.Compare(
  const aEvent, aHandler: TDelphiSemanticProcedureSignature;
  const aEventUnit, aHandlerUnit: string; const aEventUses, aHandlerUses: TArray<string>;
  const aTypes: TDelphiSemanticTypeIdentityIndex): TDelphiSemanticEventComparison;
var
  lContext: TSignatureContext;
begin
  lContext := Default(TSignatureContext);
  lContext.EventUnit := aEventUnit;
  lContext.HandlerUnit := aHandlerUnit;
  lContext.EventUses := aEventUses;
  lContext.HandlerUses := aHandlerUses;
  lContext.Types := aTypes;
  Result := CompareSignatures(aEvent, aHandler, lContext);
end;

class function TDelphiSemanticEventSignatureComparer.CompareInContext(
  const aEvent, aHandler: TDelphiSemanticProcedureSignature;
  const aEventUnit, aHandlerUnit: string; const aModels: TArray<TDelphiSemanticUnitModel>;
  const aTypes: TDelphiSemanticTypeIdentityIndex): TDelphiSemanticEventComparison;
var
  lContext: TSignatureContext;
begin
  if (TDelphiSemanticConsistencyTypeResolver.FindCompleteModelIndex(aModels, aEventUnit) < 0) or
    (TDelphiSemanticConsistencyTypeResolver.FindCompleteModelIndex(aModels, aHandlerUnit) < 0) then
  begin
    Result.Status := 'unknown';
    Result.Reason := 'signature.context-incomplete';
    Exit;
  end;
  lContext := Default(TSignatureContext);
  lContext.SourceBacked := True;
  lContext.EventUnit := aEventUnit;
  lContext.HandlerUnit := aHandlerUnit;
  lContext.Models := aModels;
  lContext.Types := aTypes;
  Result := CompareSignatures(aEvent, aHandler, lContext);
end;

end.
