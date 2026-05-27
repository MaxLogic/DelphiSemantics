unit DelphiSemantics.Resolve.MemberResolver;

interface

uses
  DelphiSemantics.Resolve.TypeResolver, DelphiSemantics.SemanticGraph;

type
  TDelphiSemanticMemberIdentity = record
    SymbolId: TDelphiSemanticGraphSymbolId;
    UnitId: TDelphiSemanticUnitGraphId;
    UnitName: string;
    OwnerName: string;
    Name: string;
    Kind: string;
    TypeName: string;
    Visibility: string;
    Signature: string;
    IsIndexed: Boolean;
    IsDefault: Boolean;
    SourceRange: TDelphiSemanticSourceRange;
  end;

  TDelphiSemanticMemberLookupResult = record
    Found: Boolean;
    Ambiguous: Boolean;
    Status: string;
    ReasonCode: string;
    Reason: string;
    Member: TDelphiSemanticMemberIdentity;
    Candidates: TArray<TDelphiSemanticMemberIdentity>;
  end;

  IDelphiSemanticMemberIdentityIndexData = interface
    ['{32617718-D2C0-4FB7-B8AF-935F8CC3466B}']
    function ResolveDirectMember(const aOwnerTypeName, aMemberName: string):
      TDelphiSemanticMemberLookupResult;
    function ResolveMember(const aOwnerTypeName, aMemberName: string):
      TDelphiSemanticMemberLookupResult;
  end;

  TDelphiSemanticMemberIdentityIndex = record
  private
    fData: IDelphiSemanticMemberIdentityIndexData;
  public
    function ResolveDirectMember(const aOwnerTypeName, aMemberName: string):
      TDelphiSemanticMemberLookupResult;
    function ResolveMember(const aOwnerTypeName, aMemberName: string):
      TDelphiSemanticMemberLookupResult;
  end;

  TDelphiSemanticMemberResolver = record
  public
    class function BuildIndex(const aGraph: TDelphiSemanticSemanticGraph;
      const aTypeIndex: TDelphiSemanticTypeIdentityIndex): TDelphiSemanticMemberIdentityIndex;
      static;
  end;

implementation

uses
  System.Generics.Collections, System.Generics.Defaults, System.SysUtils,
  MaxLogic.StrUtils;

type
  TDelphiSemanticMemberIdentityList = TList<TDelphiSemanticMemberIdentity>;

  TDelphiSemanticMemberNameKey = record
    UnitId: string;
    OwnerName: string;
    MemberName: string;
  end;

  TDelphiSemanticMemberNameKeyComparer = class(TInterfacedObject,
    IEqualityComparer<TDelphiSemanticMemberNameKey>)
  private
    fStringComparer: IEqualityComparer<string>;
  public
    constructor Create;
    function Equals(const aLeft, aRight: TDelphiSemanticMemberNameKey): Boolean; reintroduce;
    function GetHashCode(const aValue: TDelphiSemanticMemberNameKey): Integer; reintroduce;
  end;

  TDelphiSemanticMemberIdentityIndexData = class(TInterfacedObject,
    IDelphiSemanticMemberIdentityIndexData)
  private
    fByOwnerAndName: TDictionary<TDelphiSemanticMemberNameKey,
      TDelphiSemanticMemberIdentityList>;
    fExpandedByOwnerType: TDictionary<string, TArray<TDelphiSemanticTypeIdentity>>;
    fTypeIndex: TDelphiSemanticTypeIdentityIndex;
    fUnitNamesById: TDictionary<string, string>;
    class function AmbiguousResult(const aOwnerTypeName, aMemberName: string;
      const aCandidates: TArray<TDelphiSemanticMemberIdentity>):
      TDelphiSemanticMemberLookupResult; static;
    class function ResolvedResult(const aMember: TDelphiSemanticMemberIdentity):
      TDelphiSemanticMemberLookupResult; static;
    class function UnresolvedResult(const aOwnerTypeName, aMemberName: string):
      TDelphiSemanticMemberLookupResult; static;
    class function UnsupportedResult(const aMemberName: string;
      const aCandidates: TArray<TDelphiSemanticMemberIdentity>):
      TDelphiSemanticMemberLookupResult; static;
    procedure AddMember(const aMember: TDelphiSemanticMemberIdentity);
    procedure AddIdentityOwnerProbes(const aIdentity: TDelphiSemanticTypeIdentity;
      const aOwnerProbes: TList<TDelphiSemanticMemberNameKey>);
    procedure AddOwnerProbe(const aOwnerUnitId, aOwnerName: string;
      const aOwnerProbes: TList<TDelphiSemanticMemberNameKey>);
    function CandidateOwnerProbes(const aOwnerTypeName, aMemberName: string):
      TArray<TDelphiSemanticMemberNameKey>;
    function FindCandidates(const aOwnerProbes: TArray<TDelphiSemanticMemberNameKey>):
      TArray<TDelphiSemanticMemberIdentity>;
    function ExpandedOwnerTypes(const aOwner: TDelphiSemanticTypeIdentity):
      TArray<TDelphiSemanticTypeIdentity>;
    function ResolveOwnerType(const aOwnerTypeName: string; out aIdentity:
      TDelphiSemanticTypeIdentity): Boolean;
  public
    constructor Create(const aGraph: TDelphiSemanticSemanticGraph;
      const aTypeIndex: TDelphiSemanticTypeIdentityIndex);
    destructor Destroy; override;
    function ResolveDirectMember(const aOwnerTypeName, aMemberName: string):
      TDelphiSemanticMemberLookupResult;
    function ResolveMember(const aOwnerTypeName, aMemberName: string):
      TDelphiSemanticMemberLookupResult;
  end;

constructor TDelphiSemanticMemberNameKeyComparer.Create;
begin
  inherited Create;
  fStringComparer := TFastCaseAwareComparer.OrdinalIgnoreCase;
end;

function TDelphiSemanticMemberNameKeyComparer.Equals(
  const aLeft, aRight: TDelphiSemanticMemberNameKey): Boolean;
begin
  Result := fStringComparer.Equals(aLeft.UnitId, aRight.UnitId) and
    fStringComparer.Equals(aLeft.OwnerName, aRight.OwnerName) and
    fStringComparer.Equals(aLeft.MemberName, aRight.MemberName);
end;

function TDelphiSemanticMemberNameKeyComparer.GetHashCode(
  const aValue: TDelphiSemanticMemberNameKey): Integer;
begin
  Result := fStringComparer.GetHashCode(aValue.UnitId) xor
    (fStringComparer.GetHashCode(aValue.OwnerName) shl 1) xor
    (fStringComparer.GetHashCode(aValue.MemberName) shl 2);
end;

class function TDelphiSemanticMemberIdentityIndexData.AmbiguousResult(
  const aOwnerTypeName, aMemberName: string;
  const aCandidates: TArray<TDelphiSemanticMemberIdentity>): TDelphiSemanticMemberLookupResult;
begin
  Result := Default(TDelphiSemanticMemberLookupResult);
  Result.Found := False;
  Result.Ambiguous := True;
  Result.Status := 'ambiguous';
  Result.ReasonCode := 'MULTIPLE_DIRECT_MEMBER_CANDIDATES';
  Result.Reason := 'Multiple direct members named "' + aMemberName + '" were found on ' +
    aOwnerTypeName + '.';
  Result.Candidates := Copy(aCandidates);
end;

class function TDelphiSemanticMemberIdentityIndexData.ResolvedResult(
  const aMember: TDelphiSemanticMemberIdentity): TDelphiSemanticMemberLookupResult;
begin
  Result := Default(TDelphiSemanticMemberLookupResult);
  Result.Found := True;
  Result.Status := 'resolved';
  Result.Member := aMember;
  Result.Candidates := [aMember];
end;

class function TDelphiSemanticMemberIdentityIndexData.UnresolvedResult(
  const aOwnerTypeName, aMemberName: string): TDelphiSemanticMemberLookupResult;
begin
  Result := Default(TDelphiSemanticMemberLookupResult);
  Result.Found := False;
  Result.Status := 'unresolved';
  Result.ReasonCode := 'DIRECT_MEMBER_NOT_FOUND';
  Result.Reason := 'No direct member named "' + aMemberName + '" was found on ' +
    aOwnerTypeName + '.';
end;

class function TDelphiSemanticMemberIdentityIndexData.UnsupportedResult(
  const aMemberName: string; const aCandidates: TArray<TDelphiSemanticMemberIdentity>):
  TDelphiSemanticMemberLookupResult;
begin
  Result := Default(TDelphiSemanticMemberLookupResult);
  Result.Found := False;
  Result.Status := 'unsupported';
  Result.ReasonCode := 'INDEXED_DEFAULT_MEMBER_UNSUPPORTED';
  Result.Reason := 'Indexed/default member "' + aMemberName +
    '" requires selector context.';
  Result.Candidates := Copy(aCandidates);
end;

constructor TDelphiSemanticMemberIdentityIndexData.Create(
  const aGraph: TDelphiSemanticSemanticGraph;
  const aTypeIndex: TDelphiSemanticTypeIdentityIndex);
var
  lGraphMember: TDelphiSemanticGraphMember;
  lMember: TDelphiSemanticMemberIdentity;
  lUnit: TDelphiSemanticGraphUnit;
begin
  inherited Create;
  fTypeIndex := aTypeIndex;
  fByOwnerAndName := TDictionary<TDelphiSemanticMemberNameKey,
    TDelphiSemanticMemberIdentityList>.Create(TDelphiSemanticMemberNameKeyComparer.Create);
  fExpandedByOwnerType := TDictionary<string, TArray<TDelphiSemanticTypeIdentity>>.Create(
    TFastCaseAwareComparer.OrdinalIgnoreCase);
  fUnitNamesById := TDictionary<string, string>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);

  for lUnit in aGraph.Units do
    fUnitNamesById.AddOrSetValue(lUnit.Id.Value, lUnit.UnitName);

  for lGraphMember in aGraph.Members do
  begin
    lMember := Default(TDelphiSemanticMemberIdentity);
    lMember.SymbolId := lGraphMember.SymbolId;
    lMember.UnitId := lGraphMember.UnitId;
    fUnitNamesById.TryGetValue(lMember.UnitId.Value, lMember.UnitName);
    lMember.OwnerName := lGraphMember.OwnerName;
    lMember.Name := lGraphMember.Name;
    lMember.Kind := lGraphMember.Kind;
    lMember.TypeName := lGraphMember.TypeName;
    lMember.Visibility := lGraphMember.Visibility;
    lMember.Signature := lGraphMember.Signature;
    lMember.IsIndexed := lGraphMember.IsIndexed;
    lMember.IsDefault := lGraphMember.IsDefault;
    lMember.SourceRange := lGraphMember.SourceRange;
    AddMember(lMember);
  end;
end;

destructor TDelphiSemanticMemberIdentityIndexData.Destroy;
var
  lList: TDelphiSemanticMemberIdentityList;
begin
  for lList in fByOwnerAndName.Values do
    lList.Free;
  fUnitNamesById.Free;
  fExpandedByOwnerType.Free;
  fByOwnerAndName.Free;
  inherited;
end;

procedure TDelphiSemanticMemberIdentityIndexData.AddMember(
  const aMember: TDelphiSemanticMemberIdentity);
var
  lKey: TDelphiSemanticMemberNameKey;
  lList: TDelphiSemanticMemberIdentityList;
begin
  if (aMember.OwnerName = '') or (aMember.Name = '') then
    Exit;

  lKey.UnitId := aMember.UnitId.Value;
  lKey.OwnerName := aMember.OwnerName;
  lKey.MemberName := aMember.Name;
  if not fByOwnerAndName.TryGetValue(lKey, lList) then
  begin
    lList := TDelphiSemanticMemberIdentityList.Create;
    try
      fByOwnerAndName.Add(lKey, lList);
    except
      lList.Free;
      raise;
    end;
  end;
  lList.Add(aMember);

  lKey.UnitId := '';
  if not fByOwnerAndName.TryGetValue(lKey, lList) then
  begin
    lList := TDelphiSemanticMemberIdentityList.Create;
    try
      fByOwnerAndName.Add(lKey, lList);
    except
      lList.Free;
      raise;
    end;
  end;
  lList.Add(aMember);
end;

procedure TDelphiSemanticMemberIdentityIndexData.AddIdentityOwnerProbes(
  const aIdentity: TDelphiSemanticTypeIdentity;
  const aOwnerProbes: TList<TDelphiSemanticMemberNameKey>);
var
  lTarget: TDelphiSemanticTypeLookupResult;
begin
  AddOwnerProbe(aIdentity.UnitId.Value, aIdentity.Name, aOwnerProbes);
  if aIdentity.CanonicalName <> '' then
  begin
    if Pos('.', aIdentity.CanonicalName) > 0 then
    begin
      lTarget := fTypeIndex.ResolveQualifiedName(aIdentity.CanonicalName);
      if lTarget.Found then
        AddIdentityOwnerProbes(lTarget.Identity, aOwnerProbes);
    end else
      AddOwnerProbe(aIdentity.UnitId.Value, aIdentity.CanonicalName, aOwnerProbes);
  end;
  AddOwnerProbe(aIdentity.UnitId.Value, aIdentity.UnderlyingName, aOwnerProbes);
end;

procedure TDelphiSemanticMemberIdentityIndexData.AddOwnerProbe(const aOwnerUnitId,
  aOwnerName: string; const aOwnerProbes: TList<TDelphiSemanticMemberNameKey>);
var
  lExistingProbe: TDelphiSemanticMemberNameKey;
  lProbe: TDelphiSemanticMemberNameKey;
begin
  if aOwnerName = '' then
    Exit;

  lProbe.UnitId := aOwnerUnitId;
  lProbe.OwnerName := aOwnerName;
  lProbe.MemberName := '';
  for lExistingProbe in aOwnerProbes do
    if SameText(lExistingProbe.UnitId, lProbe.UnitId) and
      SameText(lExistingProbe.OwnerName, lProbe.OwnerName) then
      Exit;
  aOwnerProbes.Add(lProbe);
end;

function TDelphiSemanticMemberIdentityIndexData.CandidateOwnerProbes(
  const aOwnerTypeName, aMemberName: string): TArray<TDelphiSemanticMemberNameKey>;
var
  lOwnerProbes: TList<TDelphiSemanticMemberNameKey>;
  lResult: TDelphiSemanticTypeLookupResult;
  i: Integer;
begin
  lOwnerProbes := TList<TDelphiSemanticMemberNameKey>.Create;
  try
    lResult := fTypeIndex.ResolveQualifiedName(aOwnerTypeName);
    if not lResult.Found then
      lResult := fTypeIndex.ResolveSimpleName(aOwnerTypeName);
    if lResult.Found then
      AddIdentityOwnerProbes(lResult.Identity, lOwnerProbes);
    AddOwnerProbe('', aOwnerTypeName, lOwnerProbes);
    Result := lOwnerProbes.ToArray;
    for i := 0 to High(Result) do
      Result[i].MemberName := aMemberName;
  finally
    lOwnerProbes.Free;
  end;
end;

function TDelphiSemanticMemberIdentityIndexData.FindCandidates(
  const aOwnerProbes: TArray<TDelphiSemanticMemberNameKey>):
  TArray<TDelphiSemanticMemberIdentity>;
var
  lCandidate: TDelphiSemanticMemberIdentity;
  lList: TDelphiSemanticMemberIdentityList;
  lMatches: TDelphiSemanticMemberIdentityList;
  lOwnerProbe: TDelphiSemanticMemberNameKey;
begin
  lMatches := TDelphiSemanticMemberIdentityList.Create;
  try
    for lOwnerProbe in aOwnerProbes do
    begin
      if fByOwnerAndName.TryGetValue(lOwnerProbe, lList) then
        for lCandidate in lList do
          lMatches.Add(lCandidate);
      if lMatches.Count > 0 then
        Break;
    end;
    Result := lMatches.ToArray;
  finally
    lMatches.Free;
  end;
end;

function TDelphiSemanticMemberIdentityIndexData.ExpandedOwnerTypes(
  const aOwner: TDelphiSemanticTypeIdentity): TArray<TDelphiSemanticTypeIdentity>;
var
  lAncestor: TDelphiSemanticTypeIdentity;
  lHelper: TDelphiSemanticTypeIdentity;
  lList: TList<TDelphiSemanticTypeIdentity>;
begin
  if fExpandedByOwnerType.TryGetValue(aOwner.DeclaredId.Value, Result) then
    Exit(Copy(Result));

  lList := TList<TDelphiSemanticTypeIdentity>.Create;
  try
    for lAncestor in fTypeIndex.FindAncestors(aOwner) do
      lList.Add(lAncestor);
    for lHelper in fTypeIndex.FindHelpersForTarget(aOwner.Name) do
      lList.Add(lHelper);
    for lHelper in fTypeIndex.FindHelpersForTarget(aOwner.UnitName + '.' + aOwner.Name) do
      lList.Add(lHelper);
    for lHelper in fTypeIndex.FindHelpersForTarget(aOwner.CanonicalName) do
      lList.Add(lHelper);
    for lHelper in fTypeIndex.FindHelpersForTarget(aOwner.UnderlyingName) do
      lList.Add(lHelper);
    Result := lList.ToArray;
    fExpandedByOwnerType.AddOrSetValue(aOwner.DeclaredId.Value, Copy(Result));
  finally
    lList.Free;
  end;
end;

function TDelphiSemanticMemberIdentityIndexData.ResolveDirectMember(
  const aOwnerTypeName, aMemberName: string): TDelphiSemanticMemberLookupResult;
var
  lCandidates: TArray<TDelphiSemanticMemberIdentity>;
begin
  lCandidates := FindCandidates(CandidateOwnerProbes(aOwnerTypeName, aMemberName));
  if Length(lCandidates) = 0 then
    Exit(UnresolvedResult(aOwnerTypeName, aMemberName));

  if Length(lCandidates) > 1 then
    Exit(AmbiguousResult(aOwnerTypeName, aMemberName, lCandidates));

  if lCandidates[0].IsIndexed or lCandidates[0].IsDefault then
    Exit(UnsupportedResult(aMemberName, lCandidates));

  Result := ResolvedResult(lCandidates[0]);
end;

function TDelphiSemanticMemberIdentityIndexData.ResolveMember(const aOwnerTypeName,
  aMemberName: string): TDelphiSemanticMemberLookupResult;
var
  lExpandedOwner: TDelphiSemanticTypeIdentity;
  lDirect: TDelphiSemanticMemberLookupResult;
  lOwner: TDelphiSemanticTypeIdentity;
begin
  lDirect := ResolveDirectMember(aOwnerTypeName, aMemberName);
  if lDirect.Found or lDirect.Ambiguous or SameText(lDirect.Status, 'unsupported') then
    Exit(lDirect);

  if ResolveOwnerType(aOwnerTypeName, lOwner) then
  begin
    for lExpandedOwner in ExpandedOwnerTypes(lOwner) do
    begin
      Result := ResolveDirectMember(lExpandedOwner.UnitName + '.' + lExpandedOwner.Name,
        aMemberName);
      if Result.Found then
      begin
        if lExpandedOwner.HelperTargetName <> '' then
          Result.Status := 'helper'
        else
          Result.Status := 'inherited';
        Exit;
      end;
      if Result.Ambiguous or SameText(Result.Status, 'unsupported') then
        Exit;
    end;
  end;

  Result := lDirect;
end;

function TDelphiSemanticMemberIdentityIndexData.ResolveOwnerType(const aOwnerTypeName: string;
  out aIdentity: TDelphiSemanticTypeIdentity): Boolean;
var
  lResult: TDelphiSemanticTypeLookupResult;
begin
  lResult := fTypeIndex.ResolveQualifiedName(aOwnerTypeName);
  if not lResult.Found then
    lResult := fTypeIndex.ResolveSimpleName(aOwnerTypeName);
  if lResult.Found then
  begin
    aIdentity := lResult.Identity;
    Exit(True);
  end;

  aIdentity := Default(TDelphiSemanticTypeIdentity);
  Result := False;
end;

function TDelphiSemanticMemberIdentityIndex.ResolveDirectMember(
  const aOwnerTypeName, aMemberName: string): TDelphiSemanticMemberLookupResult;
begin
  if fData = nil then
  begin
    Result := Default(TDelphiSemanticMemberLookupResult);
    Result.Status := 'unresolved';
    Result.ReasonCode := 'INDEX_NOT_BUILT';
    Result.Reason := 'The member identity index has not been built.';
    Exit;
  end;

  Result := fData.ResolveDirectMember(aOwnerTypeName, aMemberName);
end;

function TDelphiSemanticMemberIdentityIndex.ResolveMember(const aOwnerTypeName,
  aMemberName: string): TDelphiSemanticMemberLookupResult;
begin
  if fData = nil then
  begin
    Result := Default(TDelphiSemanticMemberLookupResult);
    Result.Status := 'unresolved';
    Result.ReasonCode := 'INDEX_NOT_BUILT';
    Result.Reason := 'The member identity index has not been built.';
    Exit;
  end;

  Result := fData.ResolveMember(aOwnerTypeName, aMemberName);
end;

class function TDelphiSemanticMemberResolver.BuildIndex(
  const aGraph: TDelphiSemanticSemanticGraph;
  const aTypeIndex: TDelphiSemanticTypeIdentityIndex): TDelphiSemanticMemberIdentityIndex;
begin
  Result := Default(TDelphiSemanticMemberIdentityIndex);
  Result.fData := TDelphiSemanticMemberIdentityIndexData.Create(aGraph, aTypeIndex);
end;

end.
