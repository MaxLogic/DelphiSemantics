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
    OwnerDeclaredId: TDelphiSemanticGraphTypeId;
    OwnerScopeId: string;
    OwnerSymbolId: string;
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

  TDelphiSemanticMemberLookupContext = record
    CallerUnitName: string;
    CurrentTypeName: string;
    StaticContext: Boolean;
    InstanceContext: Boolean;
    ArgumentTypeNames: TArray<string>;
  end;

  IDelphiSemanticMemberIdentityIndexData = interface
    ['{32617718-D2C0-4FB7-B8AF-935F8CC3466B}']
    function ResolveDirectMember(const aOwnerTypeName, aMemberName: string):
      TDelphiSemanticMemberLookupResult;
    function ResolveDirectMemberByOwnerId(const aOwnerDeclaredId: TDelphiSemanticGraphTypeId;
      const aMemberName: string): TDelphiSemanticMemberLookupResult;
    function ResolveMember(const aOwnerTypeName, aMemberName: string):
      TDelphiSemanticMemberLookupResult; overload;
    function ResolveMember(const aContext: TDelphiSemanticMemberLookupContext;
      const aOwnerTypeName, aMemberName: string): TDelphiSemanticMemberLookupResult; overload;
  end;

  TDelphiSemanticMemberIdentityIndex = record
  private
    fData: IDelphiSemanticMemberIdentityIndexData;
  public
    function ResolveDirectMember(const aOwnerTypeName, aMemberName: string):
      TDelphiSemanticMemberLookupResult;
    function ResolveDirectMemberByOwnerId(const aOwnerDeclaredId: TDelphiSemanticGraphTypeId;
      const aMemberName: string): TDelphiSemanticMemberLookupResult;
    function ResolveMember(const aOwnerTypeName, aMemberName: string):
      TDelphiSemanticMemberLookupResult; overload;
    function ResolveMember(const aContext: TDelphiSemanticMemberLookupContext;
      const aOwnerTypeName, aMemberName: string): TDelphiSemanticMemberLookupResult; overload;
  end;

  TDelphiSemanticMemberResolver = record
  public
    class function BuildIndex(const aGraph: TDelphiSemanticSemanticGraph;
      const aTypeIndex: TDelphiSemanticTypeIdentityIndex): TDelphiSemanticMemberIdentityIndex;
      static;
  end;

implementation

uses
  System.Generics.Collections, System.Generics.Defaults, System.StrUtils, System.SysUtils,
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
    fByOwnerIdAndName: TDictionary<string, TDelphiSemanticMemberIdentityList>;
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
    class function StatusResult(const aStatus, aReasonCode, aReason: string;
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
    function FilterCandidatesByArgumentTypes(
      const aCandidates: TArray<TDelphiSemanticMemberIdentity>;
      const aArgumentTypeNames: TArray<string>): TArray<TDelphiSemanticMemberIdentity>;
    function HasExpandedMember(const aOwnerTypeName, aMemberName: string;
      out aMember: TDelphiSemanticMemberIdentity): Boolean;
    function LookupCandidates(const aOwnerTypeName, aMemberName: string):
      TArray<TDelphiSemanticMemberIdentity>;
    function MemberIsAccessible(const aContext: TDelphiSemanticMemberLookupContext;
      const aMember: TDelphiSemanticMemberIdentity): Boolean;
    function TypeDerivesFrom(const aCurrentTypeName, aOwnerTypeName: string): Boolean;
    function ResolveCandidates(const aContext: TDelphiSemanticMemberLookupContext;
      const aMemberName, aResolvedStatus: string;
      const aCandidates: TArray<TDelphiSemanticMemberIdentity>):
      TDelphiSemanticMemberLookupResult;
    function ResolveOwnerType(const aOwnerTypeName: string; out aIdentity:
      TDelphiSemanticTypeIdentity): Boolean;
  public
    constructor Create(const aGraph: TDelphiSemanticSemanticGraph;
      const aTypeIndex: TDelphiSemanticTypeIdentityIndex);
    destructor Destroy; override;
    function ResolveDirectMember(const aOwnerTypeName, aMemberName: string):
      TDelphiSemanticMemberLookupResult;
    function ResolveDirectMemberByOwnerId(const aOwnerDeclaredId: TDelphiSemanticGraphTypeId;
      const aMemberName: string): TDelphiSemanticMemberLookupResult;
    function ResolveMember(const aOwnerTypeName, aMemberName: string):
      TDelphiSemanticMemberLookupResult; overload;
    function ResolveMember(const aContext: TDelphiSemanticMemberLookupContext;
      const aOwnerTypeName, aMemberName: string): TDelphiSemanticMemberLookupResult; overload;
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

class function TDelphiSemanticMemberIdentityIndexData.StatusResult(const aStatus, aReasonCode,
  aReason: string; const aCandidates: TArray<TDelphiSemanticMemberIdentity>):
  TDelphiSemanticMemberLookupResult;
begin
  Result := Default(TDelphiSemanticMemberLookupResult);
  Result.Found := False;
  Result.Ambiguous := SameText(aStatus, 'ambiguous');
  Result.Status := aStatus;
  Result.ReasonCode := aReasonCode;
  Result.Reason := aReason;
  Result.Candidates := Copy(aCandidates);
end;

constructor TDelphiSemanticMemberIdentityIndexData.Create(
  const aGraph: TDelphiSemanticSemanticGraph;
  const aTypeIndex: TDelphiSemanticTypeIdentityIndex);
var
  lGraphMember: TDelphiSemanticGraphMember;
  lGraphType: TDelphiSemanticGraphType;
  lGraphRoutine: TDelphiSemanticGraphRoutine;
  lPossiblyLocal: Boolean;
  lMember: TDelphiSemanticMemberIdentity;
  lUnit: TDelphiSemanticGraphUnit;
begin
  inherited Create;
  fTypeIndex := aTypeIndex;
  fByOwnerAndName := TDictionary<TDelphiSemanticMemberNameKey,
    TDelphiSemanticMemberIdentityList>.Create(TDelphiSemanticMemberNameKeyComparer.Create);
  fByOwnerIdAndName := TDictionary<string, TDelphiSemanticMemberIdentityList>.Create(
    TFastCaseAwareComparer.OrdinalIgnoreCase);
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
    lMember.OwnerScopeId := lGraphMember.OwnerScopeId;
    lMember.OwnerSymbolId := lGraphMember.OwnerSemanticSymbolId;
    if lMember.OwnerScopeId <> '' then
      for lGraphType in aGraph.Types do
        if SameText(lGraphType.UnitId.Value, lMember.UnitId.Value) and
          SameText(lGraphType.ScopeKind, 'routine') and
          SameText(lGraphType.OwnerScopeId, lMember.OwnerScopeId) and
          SameText(lGraphType.SemanticSymbolId, lMember.OwnerSymbolId) then
        begin
          lMember.OwnerDeclaredId := lGraphType.DeclaredId;
          Break;
        end;
    lMember.Name := lGraphMember.Name;
    lMember.Kind := lGraphMember.Kind;
    lMember.TypeName := lGraphMember.TypeName;
    lMember.Visibility := lGraphMember.Visibility;
    lMember.Signature := lGraphMember.Signature;
    lMember.IsIndexed := lGraphMember.IsIndexed;
    lMember.IsDefault := lGraphMember.IsDefault;
    lMember.SourceRange := lGraphMember.SourceRange;
    lPossiblyLocal := False;
    if lMember.OwnerScopeId = '' then
      for lGraphType in aGraph.Types do
        if SameText(lGraphType.ScopeKind, 'routine') and
          SameText(lGraphType.UnitId.Value, lMember.UnitId.Value) and
          SameText(lGraphType.Name, lMember.OwnerName) and
          (lGraphType.SourceRange.Line <= lMember.SourceRange.Line) then
          for lGraphRoutine in aGraph.Routines do
            if SameText(lGraphRoutine.UnitId.Value, lMember.UnitId.Value) and
              SameText(lGraphRoutine.ScopeId, lGraphType.OwnerScopeId) and
              (lGraphRoutine.SourceRange.EndLine >= lMember.SourceRange.Line) then
              lPossiblyLocal := True;
    if lPossiblyLocal then
      Continue;
    AddMember(lMember);
  end;
end;

destructor TDelphiSemanticMemberIdentityIndexData.Destroy;
var
  lList: TDelphiSemanticMemberIdentityList;
begin
  for lList in fByOwnerAndName.Values do
    lList.Free;
  for lList in fByOwnerIdAndName.Values do
    lList.Free;
  fByOwnerIdAndName.Free;
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

  if aMember.OwnerScopeId <> '' then
  begin
    if (aMember.OwnerDeclaredId.Value = '') or (aMember.OwnerSymbolId = '') then
      Exit;
    if not fByOwnerIdAndName.TryGetValue(aMember.OwnerDeclaredId.Value + #31 +
      aMember.Name, lList) then
    begin
      lList := TDelphiSemanticMemberIdentityList.Create;
      try
        fByOwnerIdAndName.Add(aMember.OwnerDeclaredId.Value + #31 +
          aMember.Name, lList);
      except
        lList.Free;
        raise;
      end;
    end;
    lList.Add(aMember);
    Exit;
  end;

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

function TDelphiSemanticMemberIdentityIndexData.ResolveDirectMemberByOwnerId(
  const aOwnerDeclaredId: TDelphiSemanticGraphTypeId;
  const aMemberName: string): TDelphiSemanticMemberLookupResult;
var
  lList: TDelphiSemanticMemberIdentityList;
begin
  if (aOwnerDeclaredId.Value = '') or not fByOwnerIdAndName.TryGetValue(
    aOwnerDeclaredId.Value + #31 + aMemberName, lList) then
    Exit(UnresolvedResult(aOwnerDeclaredId.Value, aMemberName));
  if lList.Count <> 1 then
    Exit(AmbiguousResult(aOwnerDeclaredId.Value, aMemberName, lList.ToArray));
  if lList[0].IsIndexed or lList[0].IsDefault then
    Exit(UnsupportedResult(aMemberName, lList.ToArray));
  Result := ResolvedResult(lList[0]);
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

function TDelphiSemanticMemberIdentityIndexData.FilterCandidatesByArgumentTypes(
  const aCandidates: TArray<TDelphiSemanticMemberIdentity>;
  const aArgumentTypeNames: TArray<string>): TArray<TDelphiSemanticMemberIdentity>;
var
  lCandidate: TDelphiSemanticMemberIdentity;
  lMatches: TDelphiSemanticMemberIdentityList;
  lNameCount: Integer;
  lNameList: string;
  lParameterList: string;
  lParameterSegment: string;
  lParameters: TArray<string>;
  lParameterTypes: TList<string>;
  s: string;
begin
  if Length(aArgumentTypeNames) = 0 then
    Exit(Copy(aCandidates));

  lMatches := TDelphiSemanticMemberIdentityList.Create;
  lParameterTypes := TList<string>.Create;
  try
    for lCandidate in aCandidates do
    begin
      lParameterTypes.Clear;
      lParameterList := Copy(lCandidate.Signature, Pos('(', lCandidate.Signature) + 1, MaxInt);
      lParameterList := Copy(lParameterList, 1, Pos(')', lParameterList) - 1);
      lParameters := lParameterList.Split([';']);
      for lParameterSegment in lParameters do
      begin
        if Pos(':', lParameterSegment) = 0 then
          Continue;
        lNameList := Trim(Copy(lParameterSegment, 1, Pos(':', lParameterSegment) - 1));
        s := Trim(Copy(lParameterSegment, Pos(':', lParameterSegment) + 1, MaxInt));
        s := StringReplace(s, 'const ', '', [rfIgnoreCase]);
        s := StringReplace(s, 'var ', '', [rfIgnoreCase]);
        s := StringReplace(s, 'out ', '', [rfIgnoreCase]);
        lNameCount := Length(lNameList.Split([',']));
        while lNameCount > 0 do
        begin
          lParameterTypes.Add(s.Trim);
          Dec(lNameCount);
        end;
      end;
      if lParameterTypes.Count = Length(aArgumentTypeNames) then
        if SameText(lParameterTypes[0], aArgumentTypeNames[0]) then
          lMatches.Add(lCandidate);
    end;
    Result := lMatches.ToArray;
  finally
    lParameterTypes.Free;
    lMatches.Free;
  end;
end;

function TDelphiSemanticMemberIdentityIndexData.HasExpandedMember(const aOwnerTypeName,
  aMemberName: string; out aMember: TDelphiSemanticMemberIdentity): Boolean;
var
  lCandidates: TArray<TDelphiSemanticMemberIdentity>;
  lExpandedOwner: TDelphiSemanticTypeIdentity;
  lOwner: TDelphiSemanticTypeIdentity;
begin
  if ResolveOwnerType(aOwnerTypeName, lOwner) then
    for lExpandedOwner in ExpandedOwnerTypes(lOwner) do
    begin
      lCandidates := LookupCandidates(lExpandedOwner.UnitName + '.' + lExpandedOwner.Name,
        aMemberName);
      if Length(lCandidates) > 0 then
      begin
        aMember := lCandidates[0];
        Exit(True);
      end;
    end;

  aMember := Default(TDelphiSemanticMemberIdentity);
  Result := False;
end;

function TDelphiSemanticMemberIdentityIndexData.LookupCandidates(const aOwnerTypeName,
  aMemberName: string): TArray<TDelphiSemanticMemberIdentity>;
begin
  Result := FindCandidates(CandidateOwnerProbes(aOwnerTypeName, aMemberName));
end;

function TDelphiSemanticMemberIdentityIndexData.MemberIsAccessible(
  const aContext: TDelphiSemanticMemberLookupContext;
  const aMember: TDelphiSemanticMemberIdentity): Boolean;
begin
  if SameText(aMember.Visibility, 'strict private') then
    Exit(SameText(aContext.CurrentTypeName, aMember.OwnerName));

  if SameText(aMember.Visibility, 'private') then
    Exit(SameText(aContext.CallerUnitName, aMember.UnitName) or
      SameText(aContext.CurrentTypeName, aMember.OwnerName));

  if SameText(aMember.Visibility, 'strict protected') or SameText(aMember.Visibility, 'protected')
    then
    Exit(TypeDerivesFrom(aContext.CurrentTypeName, aMember.OwnerName));

  Result := True;
end;

function TDelphiSemanticMemberIdentityIndexData.TypeDerivesFrom(const aCurrentTypeName,
  aOwnerTypeName: string): Boolean;
var
  lAncestor: TDelphiSemanticTypeIdentity;
  lCurrent: TDelphiSemanticTypeIdentity;
begin
  if SameText(aCurrentTypeName, aOwnerTypeName) then
    Exit(True);

  if not ResolveOwnerType(aCurrentTypeName, lCurrent) then
    Exit(False);

  for lAncestor in fTypeIndex.FindAncestors(lCurrent) do
    if SameText(lAncestor.Name, aOwnerTypeName) or
      SameText(lAncestor.UnitName + '.' + lAncestor.Name, aOwnerTypeName) then
      Exit(True);

  Result := False;
end;

function TDelphiSemanticMemberIdentityIndexData.ResolveCandidates(
  const aContext: TDelphiSemanticMemberLookupContext; const aMemberName, aResolvedStatus: string;
  const aCandidates: TArray<TDelphiSemanticMemberIdentity>): TDelphiSemanticMemberLookupResult;
var
  lAccessibleCandidates: TDelphiSemanticMemberIdentityList;
  lCandidate: TDelphiSemanticMemberIdentity;
  lCandidates: TArray<TDelphiSemanticMemberIdentity>;
begin
  lAccessibleCandidates := TDelphiSemanticMemberIdentityList.Create;
  try
    for lCandidate in aCandidates do
      if MemberIsAccessible(aContext, lCandidate) then
        lAccessibleCandidates.Add(lCandidate);

    if lAccessibleCandidates.Count = 0 then
      Exit(StatusResult('inaccessible', 'MEMBER_INACCESSIBLE',
        'The member exists but is not accessible from the caller context.', aCandidates));

    lCandidates := FilterCandidatesByArgumentTypes(lAccessibleCandidates.ToArray,
      aContext.ArgumentTypeNames);
  finally
    lAccessibleCandidates.Free;
  end;

  if Length(lCandidates) = 0 then
    Exit(StatusResult('unresolved', 'OVERLOAD_NOT_FOUND',
      'No overload matches the supplied argument context.', nil));

  if Length(lCandidates) > 1 then
  begin
    if SameText(lCandidates[0].Kind, 'method') and (lCandidates[0].Signature <> '') then
      Exit(StatusResult('overloaded', 'MULTIPLE_OVERLOAD_CANDIDATES',
        'Multiple overload candidates require argument context.', lCandidates));
    Exit(AmbiguousResult('', aMemberName, lCandidates));
  end;

  if lCandidates[0].IsIndexed or lCandidates[0].IsDefault then
    Exit(UnsupportedResult(aMemberName, lCandidates));

  Result := ResolvedResult(lCandidates[0]);
  if aResolvedStatus <> '' then
    Result.Status := aResolvedStatus;
end;

function TDelphiSemanticMemberIdentityIndexData.ResolveDirectMember(
  const aOwnerTypeName, aMemberName: string): TDelphiSemanticMemberLookupResult;
var
  lCandidates: TArray<TDelphiSemanticMemberIdentity>;
begin
  lCandidates := LookupCandidates(aOwnerTypeName, aMemberName);
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

function TDelphiSemanticMemberIdentityIndexData.ResolveMember(
  const aContext: TDelphiSemanticMemberLookupContext; const aOwnerTypeName,
  aMemberName: string): TDelphiSemanticMemberLookupResult;
var
  lCandidates: TArray<TDelphiSemanticMemberIdentity>;
  lExpandedOwner: TDelphiSemanticTypeIdentity;
  lHiddenMember: TDelphiSemanticMemberIdentity;
  lOwner: TDelphiSemanticTypeIdentity;
  lStatus: string;
begin
  lCandidates := LookupCandidates(aOwnerTypeName, aMemberName);
  if Length(lCandidates) > 0 then
  begin
    if HasExpandedMember(aOwnerTypeName, aMemberName, lHiddenMember) then
      Exit(StatusResult('hidden', 'MEMBER_HIDES_INHERITED',
        'A direct member hides an inherited or helper-provided member.', lCandidates));
    Exit(ResolveCandidates(aContext, aMemberName, '', lCandidates));
  end;

  if ResolveOwnerType(aOwnerTypeName, lOwner) then
    for lExpandedOwner in ExpandedOwnerTypes(lOwner) do
    begin
      lCandidates := LookupCandidates(lExpandedOwner.UnitName + '.' + lExpandedOwner.Name,
        aMemberName);
      if Length(lCandidates) > 0 then
      begin
        if lExpandedOwner.HelperTargetName <> '' then
          lStatus := 'helper'
        else
          lStatus := 'inherited';
        Exit(ResolveCandidates(aContext, aMemberName, lStatus, lCandidates));
      end;
    end;

  Result := ResolveMember(aOwnerTypeName, aMemberName);
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

function TDelphiSemanticMemberIdentityIndex.ResolveMember(
  const aContext: TDelphiSemanticMemberLookupContext; const aOwnerTypeName,
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

  Result := fData.ResolveMember(aContext, aOwnerTypeName, aMemberName);
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

function TDelphiSemanticMemberIdentityIndex.ResolveDirectMemberByOwnerId(
  const aOwnerDeclaredId: TDelphiSemanticGraphTypeId;
  const aMemberName: string): TDelphiSemanticMemberLookupResult;
begin
  if fData = nil then
  begin
    Result := Default(TDelphiSemanticMemberLookupResult);
    Result.Status := 'unresolved';
    Result.ReasonCode := 'INDEX_NOT_BUILT';
    Result.Reason := 'The member identity index has not been built.';
    Exit;
  end;
  Result := fData.ResolveDirectMemberByOwnerId(aOwnerDeclaredId, aMemberName);
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
