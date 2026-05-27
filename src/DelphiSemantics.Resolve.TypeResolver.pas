unit DelphiSemantics.Resolve.TypeResolver;

interface

uses
  DelphiSemantics.SemanticGraph;

type
  TDelphiSemanticTypeIdentity = record
    UnitId: TDelphiSemanticUnitGraphId;
    UnitName: string;
    Name: string;
    Kind: string;
    DeclaredId: TDelphiSemanticGraphTypeId;
    CanonicalId: TDelphiSemanticGraphTypeId;
    UnderlyingId: TDelphiSemanticGraphTypeId;
    CanonicalName: string;
    UnderlyingName: string;
    BaseTypeName: string;
    HelperTargetName: string;
    SectionKind: string;
    SourceRange: TDelphiSemanticSourceRange;
  end;

  TDelphiSemanticTypeLookupResult = record
    Found: Boolean;
    Ambiguous: Boolean;
    Status: string;
    ReasonCode: string;
    Reason: string;
    Identity: TDelphiSemanticTypeIdentity;
    Candidates: TArray<TDelphiSemanticTypeIdentity>;
  end;

  IDelphiSemanticTypeIdentityIndexData = interface
    ['{B6C3E987-C5DD-4BE9-A55E-A9E80172CF68}']
    function FindByCanonicalId(const aId: TDelphiSemanticGraphTypeId):
      TArray<TDelphiSemanticTypeIdentity>;
    function FindByDeclaredId(const aId: TDelphiSemanticGraphTypeId; out aIdentity:
      TDelphiSemanticTypeIdentity): Boolean;
    function FindByUnderlyingId(const aId: TDelphiSemanticGraphTypeId):
      TArray<TDelphiSemanticTypeIdentity>;
    function FindAncestors(const aIdentity: TDelphiSemanticTypeIdentity):
      TArray<TDelphiSemanticTypeIdentity>;
    function FindHelpersForTarget(const aTargetTypeName: string):
      TArray<TDelphiSemanticTypeIdentity>;
    function ResolveQualifiedName(const aName: string): TDelphiSemanticTypeLookupResult;
    function ResolveSimpleName(const aName: string): TDelphiSemanticTypeLookupResult;
    function ResolveVisibleName(const aName, aCurrentUnitName: string;
      const aVisibleUnitNames: TArray<string>; const aSectionKind: string):
      TDelphiSemanticTypeLookupResult;
  end;

  TDelphiSemanticTypeIdentityIndex = record
  private
    fData: IDelphiSemanticTypeIdentityIndexData;
  public
    function FindByCanonicalId(const aId: TDelphiSemanticGraphTypeId):
      TArray<TDelphiSemanticTypeIdentity>;
    function FindByDeclaredId(const aId: TDelphiSemanticGraphTypeId; out aIdentity:
      TDelphiSemanticTypeIdentity): Boolean;
    function FindByUnderlyingId(const aId: TDelphiSemanticGraphTypeId):
      TArray<TDelphiSemanticTypeIdentity>;
    function FindAncestors(const aIdentity: TDelphiSemanticTypeIdentity):
      TArray<TDelphiSemanticTypeIdentity>;
    function FindHelpersForTarget(const aTargetTypeName: string):
      TArray<TDelphiSemanticTypeIdentity>;
    function ResolveQualifiedName(const aName: string): TDelphiSemanticTypeLookupResult;
    function ResolveSimpleName(const aName: string): TDelphiSemanticTypeLookupResult;
    function ResolveVisibleName(const aName, aCurrentUnitName: string;
      const aVisibleUnitNames: TArray<string>; const aSectionKind: string = 'interface'):
      TDelphiSemanticTypeLookupResult;
  end;

  TDelphiSemanticTypeResolver = record
  public
    class function BuildIndex(const aGraph: TDelphiSemanticSemanticGraph):
      TDelphiSemanticTypeIdentityIndex; static;
  end;

implementation

uses
  System.Generics.Collections, System.Hash, System.SysUtils,
  MaxLogic.StrUtils;

type
  TDelphiSemanticTypeIdentityList = TList<TDelphiSemanticTypeIdentity>;

  TDelphiSemanticTypeIdentityIndexData = class(TInterfacedObject,
    IDelphiSemanticTypeIdentityIndexData)
  private
    fByCanonicalId: TDictionary<string, TDelphiSemanticTypeIdentityList>;
    fByDeclaredId: TDictionary<string, TDelphiSemanticTypeIdentity>;
    fByQualifiedName: TDictionary<string, TDelphiSemanticTypeIdentity>;
    fHelpersByTargetName: TDictionary<string, TDelphiSemanticTypeIdentityList>;
    fBySimpleName: TDictionary<string, TDelphiSemanticTypeIdentityList>;
    fByUnderlyingId: TDictionary<string, TDelphiSemanticTypeIdentityList>;
    fUnitNamesById: TDictionary<string, string>;
    class procedure AddToMap(const aMap: TDictionary<string, TDelphiSemanticTypeIdentityList>;
      const aKey: string; const aIdentity: TDelphiSemanticTypeIdentity); static;
    class function AmbiguousResult(const aName: string;
      const aCandidates: TArray<TDelphiSemanticTypeIdentity>): TDelphiSemanticTypeLookupResult;
      static;
    class function ResolvedResult(const aIdentity: TDelphiSemanticTypeIdentity):
      TDelphiSemanticTypeLookupResult; static;
    class function UnresolvedResult(const aName, aReasonCode, aReason: string):
      TDelphiSemanticTypeLookupResult; static;
    procedure AddIdentity(const aIdentity: TDelphiSemanticTypeIdentity);
    procedure AddHelperTargetKeys(const aIdentity: TDelphiSemanticTypeIdentity);
    function SameUnitOrInterfaceVisible(const aIdentity: TDelphiSemanticTypeIdentity;
      const aCurrentUnitName, aSectionKind: string): Boolean;
    function TryResolveAliasTarget(const aIdentity: TDelphiSemanticTypeIdentity;
      out aTarget: TDelphiSemanticTypeIdentity): Boolean;
    function ResolveUnderlyingName(const aIdentity: TDelphiSemanticTypeIdentity): string;
  public
    constructor Create(const aGraph: TDelphiSemanticSemanticGraph);
    destructor Destroy; override;
    function FindByCanonicalId(const aId: TDelphiSemanticGraphTypeId):
      TArray<TDelphiSemanticTypeIdentity>;
    function FindByDeclaredId(const aId: TDelphiSemanticGraphTypeId; out aIdentity:
      TDelphiSemanticTypeIdentity): Boolean;
    function FindByUnderlyingId(const aId: TDelphiSemanticGraphTypeId):
      TArray<TDelphiSemanticTypeIdentity>;
    function FindAncestors(const aIdentity: TDelphiSemanticTypeIdentity):
      TArray<TDelphiSemanticTypeIdentity>;
    function FindHelpersForTarget(const aTargetTypeName: string):
      TArray<TDelphiSemanticTypeIdentity>;
    function ResolveQualifiedName(const aName: string): TDelphiSemanticTypeLookupResult;
    function ResolveSimpleName(const aName: string): TDelphiSemanticTypeLookupResult;
    function ResolveVisibleName(const aName, aCurrentUnitName: string;
      const aVisibleUnitNames: TArray<string>; const aSectionKind: string):
      TDelphiSemanticTypeLookupResult;
  end;

function VisibleUnitSet(const aUnitNames: TArray<string>): TDictionary<string, Byte>;
var
  lUnitName: string;
begin
  Result := TDictionary<string, Byte>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
  for lUnitName in aUnitNames do
    if lUnitName <> '' then
      Result.AddOrSetValue(lUnitName, 0);
end;

function StableTypeId(const aUnitId: TDelphiSemanticUnitGraphId; const aRole,
  aName: string): TDelphiSemanticGraphTypeId;
begin
  Result.Value := THashSHA2.GetHashString('type|' + aUnitId.Value + '|' +
    LowerCase(aRole) + '|' + LowerCase(aName));
end;

class procedure TDelphiSemanticTypeIdentityIndexData.AddToMap(
  const aMap: TDictionary<string, TDelphiSemanticTypeIdentityList>; const aKey: string;
  const aIdentity: TDelphiSemanticTypeIdentity);
var
  lList: TDelphiSemanticTypeIdentityList;
begin
  if not aMap.TryGetValue(aKey, lList) then
  begin
    lList := TDelphiSemanticTypeIdentityList.Create;
    try
      aMap.Add(aKey, lList);
    except
      lList.Free;
      raise;
    end;
  end;
  lList.Add(aIdentity);
end;

class function TDelphiSemanticTypeIdentityIndexData.AmbiguousResult(const aName: string;
  const aCandidates: TArray<TDelphiSemanticTypeIdentity>): TDelphiSemanticTypeLookupResult;
begin
  Result := Default(TDelphiSemanticTypeLookupResult);
  Result.Found := False;
  Result.Ambiguous := True;
  Result.Status := 'ambiguous';
  Result.ReasonCode := 'MULTIPLE_TYPE_CANDIDATES';
  Result.Reason := 'Multiple visible type declarations named "' + aName + '" were found.';
  Result.Candidates := Copy(aCandidates);
end;

class function TDelphiSemanticTypeIdentityIndexData.ResolvedResult(
  const aIdentity: TDelphiSemanticTypeIdentity): TDelphiSemanticTypeLookupResult;
begin
  Result := Default(TDelphiSemanticTypeLookupResult);
  Result.Found := True;
  Result.Status := 'resolved';
  Result.Identity := aIdentity;
  Result.Candidates := [aIdentity];
end;

class function TDelphiSemanticTypeIdentityIndexData.UnresolvedResult(const aName,
  aReasonCode, aReason: string): TDelphiSemanticTypeLookupResult;
begin
  Result := Default(TDelphiSemanticTypeLookupResult);
  Result.Found := False;
  Result.Status := 'unresolved';
  Result.ReasonCode := aReasonCode;
  Result.Reason := aReason;
end;

constructor TDelphiSemanticTypeIdentityIndexData.Create(
  const aGraph: TDelphiSemanticSemanticGraph);
var
  lIdentity: TDelphiSemanticTypeIdentity;
  lIdentities: TArray<TDelphiSemanticTypeIdentity>;
  lType: TDelphiSemanticGraphType;
  lUnit: TDelphiSemanticGraphUnit;
  i: Integer;
begin
  inherited Create;
  fByCanonicalId := TDictionary<string, TDelphiSemanticTypeIdentityList>.Create(
    TFastCaseAwareComparer.OrdinalIgnoreCase);
  fByDeclaredId := TDictionary<string, TDelphiSemanticTypeIdentity>.Create(
    TFastCaseAwareComparer.OrdinalIgnoreCase);
  fByQualifiedName := TDictionary<string, TDelphiSemanticTypeIdentity>.Create(
    TFastCaseAwareComparer.OrdinalIgnoreCase);
  fHelpersByTargetName := TDictionary<string, TDelphiSemanticTypeIdentityList>.Create(
    TFastCaseAwareComparer.OrdinalIgnoreCase);
  fBySimpleName := TDictionary<string, TDelphiSemanticTypeIdentityList>.Create(
    TFastCaseAwareComparer.OrdinalIgnoreCase);
  fByUnderlyingId := TDictionary<string, TDelphiSemanticTypeIdentityList>.Create(
    TFastCaseAwareComparer.OrdinalIgnoreCase);
  fUnitNamesById := TDictionary<string, string>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);

  for lUnit in aGraph.Units do
    fUnitNamesById.AddOrSetValue(lUnit.Id.Value, lUnit.UnitName);

  SetLength(lIdentities, Length(aGraph.Types));
  i := 0;
  for lType in aGraph.Types do
  begin
    lIdentity := Default(TDelphiSemanticTypeIdentity);
    lIdentity.UnitId := lType.UnitId;
    fUnitNamesById.TryGetValue(lType.UnitId.Value, lIdentity.UnitName);
    lIdentity.Name := lType.Name;
    lIdentity.Kind := lType.Kind;
    lIdentity.DeclaredId := lType.DeclaredId;
    lIdentity.CanonicalId := lType.CanonicalId;
    lIdentity.UnderlyingId := lType.UnderlyingId;
    lIdentity.CanonicalName := lType.CanonicalName;
    lIdentity.UnderlyingName := lType.UnderlyingName;
    lIdentity.BaseTypeName := lType.BaseTypeName;
    lIdentity.HelperTargetName := lType.HelperTargetName;
    lIdentity.SectionKind := lType.SectionKind;
    lIdentity.SourceRange := lType.SourceRange;
    AddIdentity(lIdentity);
    lIdentities[i] := lIdentity;
    Inc(i);
  end;

  for lIdentity in lIdentities do
    AddHelperTargetKeys(lIdentity);
end;

destructor TDelphiSemanticTypeIdentityIndexData.Destroy;
var
  lList: TDelphiSemanticTypeIdentityList;
begin
  for lList in fByCanonicalId.Values do
    lList.Free;
  for lList in fBySimpleName.Values do
    lList.Free;
  for lList in fByUnderlyingId.Values do
    lList.Free;
  fUnitNamesById.Free;
  fByUnderlyingId.Free;
  fBySimpleName.Free;
  fByQualifiedName.Free;
  for lList in fHelpersByTargetName.Values do
    lList.Free;
  fHelpersByTargetName.Free;
  fByDeclaredId.Free;
  fByCanonicalId.Free;
  inherited;
end;

procedure TDelphiSemanticTypeIdentityIndexData.AddIdentity(
  const aIdentity: TDelphiSemanticTypeIdentity);
var
  lIdentity: TDelphiSemanticTypeIdentity;
begin
  lIdentity := aIdentity;
  lIdentity.UnderlyingName := ResolveUnderlyingName(lIdentity);
  lIdentity.UnderlyingId := StableTypeId(lIdentity.UnitId, 'underlying',
    lIdentity.UnderlyingName);
  fByDeclaredId.AddOrSetValue(lIdentity.DeclaredId.Value, lIdentity);
  fByQualifiedName.AddOrSetValue(lIdentity.UnitName + '.' + lIdentity.Name, lIdentity);
  AddToMap(fByCanonicalId, lIdentity.CanonicalId.Value, lIdentity);
  AddToMap(fBySimpleName, lIdentity.Name, lIdentity);
  AddToMap(fByUnderlyingId, lIdentity.UnderlyingId.Value, lIdentity);
end;

procedure TDelphiSemanticTypeIdentityIndexData.AddHelperTargetKeys(
  const aIdentity: TDelphiSemanticTypeIdentity);
var
  lTarget: TDelphiSemanticTypeLookupResult;
begin
  if aIdentity.HelperTargetName = '' then
    Exit;

  AddToMap(fHelpersByTargetName, aIdentity.HelperTargetName, aIdentity);
  lTarget := ResolveQualifiedName(aIdentity.HelperTargetName);
  if not lTarget.Found then
    lTarget := ResolveSimpleName(aIdentity.HelperTargetName);
  if lTarget.Found then
  begin
    AddToMap(fHelpersByTargetName, lTarget.Identity.Name, aIdentity);
    AddToMap(fHelpersByTargetName, lTarget.Identity.UnitName + '.' + lTarget.Identity.Name,
      aIdentity);
    AddToMap(fHelpersByTargetName, lTarget.Identity.CanonicalName, aIdentity);
    AddToMap(fHelpersByTargetName, lTarget.Identity.UnderlyingName, aIdentity);
  end;
end;

function TDelphiSemanticTypeIdentityIndexData.FindAncestors(
  const aIdentity: TDelphiSemanticTypeIdentity): TArray<TDelphiSemanticTypeIdentity>;
var
  lAncestor: TDelphiSemanticTypeIdentity;
  lCurrent: TDelphiSemanticTypeIdentity;
  lList: TDelphiSemanticTypeIdentityList;
  lResult: TDelphiSemanticTypeLookupResult;
begin
  lList := TDelphiSemanticTypeIdentityList.Create;
  try
    lCurrent := aIdentity;
    if SameText(lCurrent.Kind, 'type-alias') and TryResolveAliasTarget(lCurrent, lAncestor) then
    begin
      lList.Add(lAncestor);
      lCurrent := lAncestor;
    end;
    while lCurrent.BaseTypeName <> '' do
    begin
      if Pos('.', lCurrent.BaseTypeName) > 0 then
        lResult := ResolveQualifiedName(lCurrent.BaseTypeName)
      else
        lResult := ResolveVisibleName(lCurrent.BaseTypeName, lCurrent.UnitName,
          [lCurrent.UnitName], lCurrent.SectionKind);
      if not lResult.Found then
        lResult := ResolveSimpleName(lCurrent.BaseTypeName);
      if not lResult.Found then
        Break;
      lAncestor := lResult.Identity;
      lList.Add(lAncestor);
      lCurrent := lAncestor;
    end;
    Result := lList.ToArray;
  finally
    lList.Free;
  end;
end;

function TDelphiSemanticTypeIdentityIndexData.FindByCanonicalId(
  const aId: TDelphiSemanticGraphTypeId): TArray<TDelphiSemanticTypeIdentity>;
var
  lList: TDelphiSemanticTypeIdentityList;
begin
  if fByCanonicalId.TryGetValue(aId.Value, lList) then
    Exit(lList.ToArray);

  Result := nil;
end;

function TDelphiSemanticTypeIdentityIndexData.FindByDeclaredId(
  const aId: TDelphiSemanticGraphTypeId; out aIdentity: TDelphiSemanticTypeIdentity): Boolean;
begin
  Result := fByDeclaredId.TryGetValue(aId.Value, aIdentity);
end;

function TDelphiSemanticTypeIdentityIndexData.FindByUnderlyingId(
  const aId: TDelphiSemanticGraphTypeId): TArray<TDelphiSemanticTypeIdentity>;
var
  lList: TDelphiSemanticTypeIdentityList;
begin
  if fByUnderlyingId.TryGetValue(aId.Value, lList) then
    Exit(lList.ToArray);

  Result := nil;
end;

function TDelphiSemanticTypeIdentityIndexData.FindHelpersForTarget(
  const aTargetTypeName: string): TArray<TDelphiSemanticTypeIdentity>;
var
  lList: TDelphiSemanticTypeIdentityList;
begin
  if fHelpersByTargetName.TryGetValue(aTargetTypeName, lList) then
    Exit(lList.ToArray);

  Result := nil;
end;

function TDelphiSemanticTypeIdentityIndexData.ResolveQualifiedName(
  const aName: string): TDelphiSemanticTypeLookupResult;
var
  lIdentity: TDelphiSemanticTypeIdentity;
  lName: string;
begin
  lName := aName.Trim;
  if Pos('.', lName) = 0 then
    Exit(ResolveSimpleName(lName));

  if fByQualifiedName.TryGetValue(lName, lIdentity) then
    Exit(ResolvedResult(lIdentity));

  Result := UnresolvedResult(aName, 'TYPE_NOT_FOUND',
    'No type declaration named "' + aName + '" was found.');
end;

function TDelphiSemanticTypeIdentityIndexData.ResolveSimpleName(
  const aName: string): TDelphiSemanticTypeLookupResult;
var
  lList: TDelphiSemanticTypeIdentityList;
begin
  if not fBySimpleName.TryGetValue(aName, lList) then
    Exit(UnresolvedResult(aName, 'TYPE_NOT_FOUND',
      'No type declaration named "' + aName + '" was found.'));

  if lList.Count = 1 then
    Exit(ResolvedResult(lList[0]));

  Result := AmbiguousResult(aName, lList.ToArray);
end;

function TDelphiSemanticTypeIdentityIndexData.ResolveVisibleName(const aName,
  aCurrentUnitName: string; const aVisibleUnitNames: TArray<string>; const aSectionKind: string):
  TDelphiSemanticTypeLookupResult;
var
  lCandidate: TDelphiSemanticTypeIdentity;
  lCurrentMatches: TDelphiSemanticTypeIdentityList;
  lList: TDelphiSemanticTypeIdentityList;
  lMatches: TDelphiSemanticTypeIdentityList;
  lVisibleUnits: TDictionary<string, Byte>;
begin
  if not fBySimpleName.TryGetValue(aName, lList) then
    Exit(UnresolvedResult(aName, 'TYPE_NOT_FOUND',
      'No visible type declaration named "' + aName + '" was found.'));

  lVisibleUnits := VisibleUnitSet(aVisibleUnitNames);
  if aCurrentUnitName <> '' then
    lVisibleUnits.AddOrSetValue(aCurrentUnitName, 0);
  lCurrentMatches := TDelphiSemanticTypeIdentityList.Create;
  lMatches := TDelphiSemanticTypeIdentityList.Create;
  try
    for lCandidate in lList do
      if lVisibleUnits.ContainsKey(lCandidate.UnitName) and
        SameUnitOrInterfaceVisible(lCandidate, aCurrentUnitName, aSectionKind) then
      begin
        lMatches.Add(lCandidate);
        if SameText(lCandidate.UnitName, aCurrentUnitName) then
          lCurrentMatches.Add(lCandidate);
      end;

    if lCurrentMatches.Count = 1 then
      Exit(ResolvedResult(lCurrentMatches[0]));
    if lCurrentMatches.Count > 1 then
      Exit(AmbiguousResult(aName, lCurrentMatches.ToArray));

    if lMatches.Count = 1 then
      Exit(ResolvedResult(lMatches[0]));
    if lMatches.Count > 1 then
      Exit(AmbiguousResult(aName, lMatches.ToArray));
  finally
    lMatches.Free;
    lCurrentMatches.Free;
    lVisibleUnits.Free;
  end;

  Result := UnresolvedResult(aName, 'TYPE_NOT_VISIBLE',
    'No visible type declaration named "' + aName + '" was found.');
end;

function TDelphiSemanticTypeIdentityIndexData.ResolveUnderlyingName(
  const aIdentity: TDelphiSemanticTypeIdentity): string;
var
  lTarget: TDelphiSemanticTypeIdentity;
begin
  if SameText(aIdentity.Kind, 'type-alias') and TryResolveAliasTarget(aIdentity, lTarget) then
    Exit(ResolveUnderlyingName(lTarget));

  if aIdentity.UnderlyingName <> '' then
    Exit(aIdentity.UnderlyingName);

  Result := aIdentity.CanonicalName;
end;

function TDelphiSemanticTypeIdentityIndexData.SameUnitOrInterfaceVisible(
  const aIdentity: TDelphiSemanticTypeIdentity; const aCurrentUnitName, aSectionKind: string):
  Boolean;
begin
  if SameText(aIdentity.UnitName, aCurrentUnitName) then
    Exit(SameText(aSectionKind, 'implementation') or
      SameText(aIdentity.SectionKind, 'interface'));

  Result := SameText(aIdentity.SectionKind, 'interface');
end;

function TDelphiSemanticTypeIdentityIndexData.TryResolveAliasTarget(
  const aIdentity: TDelphiSemanticTypeIdentity; out aTarget: TDelphiSemanticTypeIdentity):
  Boolean;
var
  lIdentity: TDelphiSemanticTypeIdentity;
  lList: TDelphiSemanticTypeIdentityList;
  lResult: TDelphiSemanticTypeLookupResult;
begin
  aTarget := Default(TDelphiSemanticTypeIdentity);
  if aIdentity.CanonicalName = '' then
    Exit(False);

  if Pos('.', aIdentity.CanonicalName) > 0 then
  begin
    lResult := ResolveQualifiedName(aIdentity.CanonicalName);
    if lResult.Found then
    begin
      aTarget := lResult.Identity;
      Exit(True);
    end;
    Exit(False);
  end;

  if not fBySimpleName.TryGetValue(aIdentity.CanonicalName, lList) then
    Exit(False);

  if lList.Count = 1 then
  begin
    aTarget := lList[0];
    Exit(True);
  end;

  for lIdentity in lList do
    if SameText(lIdentity.UnitName, aIdentity.UnitName) then
    begin
      aTarget := lIdentity;
      Exit(True);
    end;

  aTarget := Default(TDelphiSemanticTypeIdentity);
  Result := False;
end;

function TDelphiSemanticTypeIdentityIndex.FindAncestors(
  const aIdentity: TDelphiSemanticTypeIdentity): TArray<TDelphiSemanticTypeIdentity>;
begin
  if fData = nil then
    Exit(nil);

  Result := fData.FindAncestors(aIdentity);
end;

function TDelphiSemanticTypeIdentityIndex.FindByCanonicalId(
  const aId: TDelphiSemanticGraphTypeId): TArray<TDelphiSemanticTypeIdentity>;
begin
  if fData = nil then
    Exit(nil);

  Result := fData.FindByCanonicalId(aId);
end;

function TDelphiSemanticTypeIdentityIndex.FindByDeclaredId(
  const aId: TDelphiSemanticGraphTypeId; out aIdentity: TDelphiSemanticTypeIdentity): Boolean;
begin
  if fData = nil then
  begin
    aIdentity := Default(TDelphiSemanticTypeIdentity);
    Exit(False);
  end;

  Result := fData.FindByDeclaredId(aId, aIdentity);
end;

function TDelphiSemanticTypeIdentityIndex.FindByUnderlyingId(
  const aId: TDelphiSemanticGraphTypeId): TArray<TDelphiSemanticTypeIdentity>;
begin
  if fData = nil then
    Exit(nil);

  Result := fData.FindByUnderlyingId(aId);
end;

function TDelphiSemanticTypeIdentityIndex.FindHelpersForTarget(
  const aTargetTypeName: string): TArray<TDelphiSemanticTypeIdentity>;
begin
  if fData = nil then
    Exit(nil);

  Result := fData.FindHelpersForTarget(aTargetTypeName);
end;

function TDelphiSemanticTypeIdentityIndex.ResolveQualifiedName(
  const aName: string): TDelphiSemanticTypeLookupResult;
begin
  if fData = nil then
    Exit(TDelphiSemanticTypeIdentityIndexData.UnresolvedResult(aName, 'INDEX_NOT_BUILT',
      'The type identity index has not been built.'));

  Result := fData.ResolveQualifiedName(aName);
end;

function TDelphiSemanticTypeIdentityIndex.ResolveSimpleName(
  const aName: string): TDelphiSemanticTypeLookupResult;
begin
  if fData = nil then
    Exit(TDelphiSemanticTypeIdentityIndexData.UnresolvedResult(aName, 'INDEX_NOT_BUILT',
      'The type identity index has not been built.'));

  Result := fData.ResolveSimpleName(aName);
end;

function TDelphiSemanticTypeIdentityIndex.ResolveVisibleName(const aName,
  aCurrentUnitName: string; const aVisibleUnitNames: TArray<string>;
  const aSectionKind: string): TDelphiSemanticTypeLookupResult;
begin
  if fData = nil then
    Exit(TDelphiSemanticTypeIdentityIndexData.UnresolvedResult(aName, 'INDEX_NOT_BUILT',
      'The type identity index has not been built.'));

  Result := fData.ResolveVisibleName(aName, aCurrentUnitName, aVisibleUnitNames, aSectionKind);
end;

class function TDelphiSemanticTypeResolver.BuildIndex(
  const aGraph: TDelphiSemanticSemanticGraph): TDelphiSemanticTypeIdentityIndex;
begin
  Result := Default(TDelphiSemanticTypeIdentityIndex);
  Result.fData := TDelphiSemanticTypeIdentityIndexData.Create(aGraph);
end;

end.
