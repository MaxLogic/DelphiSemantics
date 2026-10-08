unit DelphiSemantics.Resolve.TypeResolver;

interface

uses
  DelphiSemantics.Model, DelphiSemantics.SemanticGraph;

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
    ScopeKind: string;
    OwnerScopeId: string;
    SemanticSymbolId: string;
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
    function ResolveScopedName(const aName, aCurrentUnitName, aCallerScopeId: string;
      const aVisibleUnitNames: TArray<string>; const aSectionKind: string):
      TDelphiSemanticTypeLookupResult;
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
    function ResolveScopedName(const aName, aCurrentUnitName, aCallerScopeId: string;
      const aVisibleUnitNames: TArray<string>; const aSectionKind: string = 'implementation'):
      TDelphiSemanticTypeLookupResult;
    function ResolveVisibleName(const aName, aCurrentUnitName: string;
      const aVisibleUnitNames: TArray<string>; const aSectionKind: string = 'interface'):
      TDelphiSemanticTypeLookupResult;
  end;

  TDelphiSemanticTypeResolver = record
  public
    class function BuildIndex(const aGraph: TDelphiSemanticSemanticGraph):
      TDelphiSemanticTypeIdentityIndex; static;
    class function VerifiedRoutineBody(const aModel: TDelphiSemanticUnitModel;
      const aFirst, aSecond: TDelphiSemanticRoutine;
      out aBody: TDelphiSemanticRoutine): Boolean; static;
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
    fByLocalScopeName: TDictionary<string, TDelphiSemanticTypeIdentityList>;
    fUnsupportedLocalScopeName: TDictionary<string, Byte>;
    fByUnderlyingId: TDictionary<string, TDelphiSemanticTypeIdentityList>;
    fRoutineScopes: TDictionary<string, TDelphiSemanticGraphRoutine>;
    fInvalidScopes: TDictionary<string, Byte>;
    fUnitIdsByName: TDictionary<string, string>;
    fUnitScopeStatus: TDictionary<string, string>;
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
    function TryFinalizeLocalAlias(var aIdentity: TDelphiSemanticTypeIdentity): Boolean;
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
    function ResolveScopedName(const aName, aCurrentUnitName, aCallerScopeId: string;
      const aVisibleUnitNames: TArray<string>; const aSectionKind: string):
      TDelphiSemanticTypeLookupResult;
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

function ScopedKey(const aUnitId, aScopeId: string): string;
begin
  Result := aUnitId + #1 + aScopeId;
end;

function LocalTypeKey(const aUnitId, aScopeId, aName: string): string;
begin
  Result := ScopedKey(aUnitId, aScopeId) + #1 + aName;
end;

function HasMatchingAstScopeIdentity(const aRoutine: TDelphiSemanticGraphRoutine;
  const aUnitName: string): Boolean;
var
  lExpectedPrefix: string;
  lQualifiedName: string;
begin
  Result := False;
  if (aUnitName = '') or (aRoutine.Name = '') or
    (aRoutine.ParentScopeId <> '') or
    (not aRoutine.AstSourceSignatureVerified) or
    (aRoutine.AstSourceSignature <> aRoutine.Signature) or
    (Length(aRoutine.AstSemanticSignature) < 2) or
    (aRoutine.AstSemanticSignature[1] <> '(') or
    (aRoutine.AstSemanticSignature[Length(aRoutine.AstSemanticSignature)] <> ')') then
    Exit;
  lQualifiedName := aRoutine.Name;
  if aRoutine.OwnerName <> '' then
    lQualifiedName := aRoutine.OwnerName + '.' + lQualifiedName;
  // The semantic type tree and lexical source spelling were captured independently
  // at the uniquely matched AST method; neither is inferred from this scope ID.
  lExpectedPrefix := LowerCase(aUnitName) + '|' + LowerCase(lQualifiedName);
  Result := SameText(aRoutine.ScopeId,
    lExpectedPrefix + aRoutine.AstSemanticSignature);
end;

function IsSignatureWordChar(const aChar: Char): Boolean;
begin
  Result := CharInSet(aChar, ['A'..'Z', 'a'..'z', '0'..'9', '_']) or (Ord(aChar) > 127);
end;

// Canonical token text of a source parameter list: whitespace runs (line breaks
// included) are dropped next to punctuation and kept as one space between word
// characters, so only layout differences compare equal. Quoted text stays verbatim;
// a list with comments stays unnormalized because a line break can end a comment.
function NormalizedSignatureText(const aText: string): string;
var
  i: Integer;
  lBuilder: TStringBuilder;
  lInQuote: Boolean;
  lPendingSpace: Boolean;
  c: Char;
begin
  lBuilder := TStringBuilder.Create(Length(aText));
  try
    lInQuote := False;
    lPendingSpace := False;
    for i := 1 to Length(aText) do
    begin
      c := aText[i];
      if lInQuote then
      begin
        lBuilder.Append(c);
        lInQuote := c <> '''';
      end else if c <= ' ' then
        lPendingSpace := lBuilder.Length > 0
      else
      begin
        if (c = '{') or ((i < Length(aText)) and (((c = '/') and (aText[i + 1] = '/')) or
          ((c = '(') and (aText[i + 1] = '*')))) then
          Exit(aText);
        if lPendingSpace and IsSignatureWordChar(c) and
          IsSignatureWordChar(lBuilder.Chars[lBuilder.Length - 1]) then
          lBuilder.Append(' ');
        lPendingSpace := False;
        lBuilder.Append(c);
        lInQuote := c = '''';
      end;
    end;
    Result := lBuilder.ToString;
  finally
    lBuilder.Free;
  end;
end;

function IsVerifiedHeaderBodyPair(const aUnitName: string;
  const aFirst, aSecond: TDelphiSemanticGraphRoutine;
  out aBody: TDelphiSemanticGraphRoutine): Boolean;
var
  lHeader: TDelphiSemanticGraphRoutine;
begin
  aBody := Default(TDelphiSemanticGraphRoutine);
  if SameText(aFirst.AstScopeKind, 'header') and
    SameText(aSecond.AstScopeKind, 'body') then
  begin
    lHeader := aFirst;
    aBody := aSecond;
  end else if SameText(aSecond.AstScopeKind, 'header') and
    SameText(aFirst.AstScopeKind, 'body') then
  begin
    lHeader := aSecond;
    aBody := aFirst;
  end else
    Exit(False);
  // ScopeId includes the AST parameter signature. The other fields prevent an unrelated
  // declaration from borrowing the implementation body's source range.
  Result := (lHeader.UnitId.Value <> '') and
    SameText(lHeader.UnitId.Value, aBody.UnitId.Value) and
    (lHeader.ScopeId <> '') and SameText(lHeader.ScopeId, aBody.ScopeId) and
    SameText(lHeader.ParentScopeId, aBody.ParentScopeId) and
    SameText(lHeader.Name, aBody.Name) and
    SameText(lHeader.OwnerName, aBody.OwnerName) and
    HasMatchingAstScopeIdentity(lHeader, aUnitName) and
    HasMatchingAstScopeIdentity(aBody, aUnitName) and
    SameText(lHeader.AstSemanticSignature, aBody.AstSemanticSignature) and
    (NormalizedSignatureText(lHeader.AstSourceSignature) =
    NormalizedSignatureText(aBody.AstSourceSignature)) and
    SameText(NormalizedSignatureText(lHeader.Signature),
    NormalizedSignatureText(aBody.Signature)) and
    SameText(lHeader.SectionKind, 'interface') and
    SameText(aBody.SectionKind, 'implementation') and
    SameText(lHeader.ReturnType, aBody.ReturnType) and
    (lHeader.ParentScopeId = '') and
    (lHeader.SourceRange.FileName <> '') and (aBody.SourceRange.FileName <> '') and
    (lHeader.SourceRange.Line > 0) and (aBody.SourceRange.Line > 0) and
    (aBody.SourceRange.EndLine >= aBody.SourceRange.Line) and
    ((not SameText(lHeader.SourceRange.FileName, aBody.SourceRange.FileName)) or
    (lHeader.SourceRange.Line < aBody.SourceRange.Line));
end;

class function TDelphiSemanticTypeResolver.VerifiedRoutineBody(
  const aModel: TDelphiSemanticUnitModel;
  const aFirst, aSecond: TDelphiSemanticRoutine;
  out aBody: TDelphiSemanticRoutine): Boolean;
var
  lFirst: TDelphiSemanticGraphRoutine;
  lSecond: TDelphiSemanticGraphRoutine;
  lBody: TDelphiSemanticGraphRoutine;

  function GraphRoutine(const aRoutine: TDelphiSemanticRoutine):
    TDelphiSemanticGraphRoutine;
  begin
    Result := Default(TDelphiSemanticGraphRoutine);
    Result.UnitId.Value := aModel.UnitName;
    Result.Name := aRoutine.Name;
    Result.OwnerName := aRoutine.OwnerName;
    Result.SectionKind := aRoutine.SectionKind;
    Result.Signature := aRoutine.Signature;
    Result.ReturnType := aRoutine.ReturnType;
    Result.ScopeId := aRoutine.ScopeId;
    Result.ParentScopeId := aRoutine.ParentScopeId;
    Result.AstScopeKind := aRoutine.AstScopeKind;
    Result.AstSemanticSignature := aRoutine.AstSemanticSignature;
    Result.AstSourceSignature := aRoutine.AstSourceSignature;
    Result.AstSourceSignatureVerified := aRoutine.AstSourceSignatureVerified;
    Result.SourceRange.FileName := aRoutine.FileName;
    if Result.SourceRange.FileName = '' then
      Result.SourceRange.FileName := aModel.FileName;
    Result.SourceRange.Line := aRoutine.Line;
    Result.SourceRange.Column := aRoutine.Column;
    Result.SourceRange.EndLine := aRoutine.EndLine;
    Result.SourceRange.EndColumn := aRoutine.EndColumn;
  end;

begin
  aBody := Default(TDelphiSemanticRoutine);
  lFirst := GraphRoutine(aFirst);
  lSecond := GraphRoutine(aSecond);
  Result := IsVerifiedHeaderBodyPair(aModel.UnitName, lFirst, lSecond, lBody);
  if Result then
  begin
    if SameText(aFirst.AstScopeKind, 'body') then
      aBody := aFirst
    else
      aBody := aSecond;
    Result := (aBody.Line = lBody.SourceRange.Line) and
      (aBody.Column = lBody.SourceRange.Column) and
      SameText(aBody.ScopeId, lBody.ScopeId);
  end;
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
  lDeclaration: TDelphiSemanticGraphDeclaration;
  lType: TDelphiSemanticGraphType;
  lUnit: TDelphiSemanticGraphUnit;
  lRoutine: TDelphiSemanticGraphRoutine;
  lExisting: TDelphiSemanticGraphRoutine;
  lBody: TDelphiSemanticGraphRoutine;
  lPairedScopes: TDictionary<string, Byte>;
  lScopeKey: string;
  lUnitName: string;
  lPending: TList<TDelphiSemanticTypeIdentity>;
  lProgress: Boolean;
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
  fByLocalScopeName := TDictionary<string, TDelphiSemanticTypeIdentityList>.Create(
    TFastCaseAwareComparer.OrdinalIgnoreCase);
  fUnsupportedLocalScopeName := TDictionary<string, Byte>.Create(
    TFastCaseAwareComparer.OrdinalIgnoreCase);
  fByUnderlyingId := TDictionary<string, TDelphiSemanticTypeIdentityList>.Create(
    TFastCaseAwareComparer.OrdinalIgnoreCase);
  fRoutineScopes := TDictionary<string, TDelphiSemanticGraphRoutine>.Create(
    TFastCaseAwareComparer.OrdinalIgnoreCase);
  fInvalidScopes := TDictionary<string, Byte>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
  fUnitIdsByName := TDictionary<string, string>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
  fUnitScopeStatus := TDictionary<string, string>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
  fUnitNamesById := TDictionary<string, string>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);

  for lUnit in aGraph.Units do
  begin
    fUnitNamesById.AddOrSetValue(lUnit.Id.Value, lUnit.UnitName);
    fUnitIdsByName.AddOrSetValue(lUnit.UnitName, lUnit.Id.Value);
    fUnitScopeStatus.AddOrSetValue(lUnit.Id.Value, lUnit.ScopeModelStatus);
  end;
  lPairedScopes := TDictionary<string, Byte>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
  try
    for lRoutine in aGraph.Routines do
      if lRoutine.ScopeId <> '' then
      begin
        lScopeKey := ScopedKey(lRoutine.UnitId.Value, lRoutine.ScopeId);
        if fRoutineScopes.TryGetValue(lScopeKey, lExisting) then
        begin
          lUnitName := '';
          fUnitNamesById.TryGetValue(lRoutine.UnitId.Value, lUnitName);
          if fInvalidScopes.ContainsKey(lScopeKey) or
            lPairedScopes.ContainsKey(lScopeKey) or
            not IsVerifiedHeaderBodyPair(lUnitName, lExisting, lRoutine,
              lBody) then
            fInvalidScopes.AddOrSetValue(lScopeKey, 0)
          else
          begin
            fRoutineScopes.AddOrSetValue(lScopeKey, lBody);
            lPairedScopes.Add(lScopeKey, 0);
          end;
        end else
          fRoutineScopes.Add(lScopeKey, lRoutine);
      end;
  finally
    lPairedScopes.Free;
  end;
  for lDeclaration in aGraph.Declarations do
    if SameText(lDeclaration.ScopeKind, 'routine') and
      SameText(lDeclaration.Kind, 'unsupported-local-type') and
      (lDeclaration.OwnerScopeId <> '') then
      fUnsupportedLocalScopeName.AddOrSetValue(LocalTypeKey(
        lDeclaration.UnitId.Value, lDeclaration.OwnerScopeId, lDeclaration.Name), 0);

  lPending := TList<TDelphiSemanticTypeIdentity>.Create;
  try
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
    lIdentity.ScopeKind := lType.ScopeKind;
    lIdentity.OwnerScopeId := lType.OwnerScopeId;
    lIdentity.SemanticSymbolId := lType.SemanticSymbolId;
    lIdentity.SourceRange := lType.SourceRange;
    if SameText(lIdentity.ScopeKind, 'routine') and
      SameText(lIdentity.Kind, 'type-alias') then
    begin
      lPending.Add(lIdentity);
      fUnsupportedLocalScopeName.AddOrSetValue(LocalTypeKey(lIdentity.UnitId.Value,
        lIdentity.OwnerScopeId, lIdentity.Name), 0);
    end else
      AddIdentity(lIdentity);
    lIdentities[i] := lIdentity;
    Inc(i);
  end;

  repeat
    lProgress := False;
    i := 0;
    while i < lPending.Count do
    begin
      lIdentity := lPending[i];
      if TryFinalizeLocalAlias(lIdentity) then
      begin
        fUnsupportedLocalScopeName.Remove(LocalTypeKey(lIdentity.UnitId.Value,
          lIdentity.OwnerScopeId, lIdentity.Name));
        AddIdentity(lIdentity);
        lPending.Delete(i);
        lProgress := True;
      end else
        Inc(i);
    end;
  until not lProgress;
  finally
    lPending.Free;
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
  for lList in fByLocalScopeName.Values do
    lList.Free;
  for lList in fByUnderlyingId.Values do
    lList.Free;
  fUnitNamesById.Free;
  fByUnderlyingId.Free;
  fBySimpleName.Free;
  fByLocalScopeName.Free;
  fUnsupportedLocalScopeName.Free;
  fRoutineScopes.Free;
  fInvalidScopes.Free;
  fUnitIdsByName.Free;
  fUnitScopeStatus.Free;
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
  if SameText(lIdentity.ScopeKind, 'routine') and
    ((lIdentity.OwnerScopeId = '') or (lIdentity.SemanticSymbolId = '') or
    (lIdentity.DeclaredId.Value = '') or (lIdentity.CanonicalId.Value = '') or
    (lIdentity.UnderlyingId.Value = '')) then
    Exit;
  if not SameText(lIdentity.ScopeKind, 'routine') then
  begin
    lIdentity.UnderlyingName := ResolveUnderlyingName(lIdentity);
    lIdentity.UnderlyingId := StableTypeId(lIdentity.UnitId, 'underlying',
      lIdentity.UnderlyingName);
  end;
  fByDeclaredId.AddOrSetValue(lIdentity.DeclaredId.Value, lIdentity);
  AddToMap(fByCanonicalId, lIdentity.CanonicalId.Value, lIdentity);
  AddToMap(fByUnderlyingId, lIdentity.UnderlyingId.Value, lIdentity);
  if SameText(lIdentity.ScopeKind, 'routine') then
  begin
    if (lIdentity.OwnerScopeId <> '') and (lIdentity.SemanticSymbolId <> '') and
      (lIdentity.DeclaredId.Value <> '') then
      AddToMap(fByLocalScopeName, LocalTypeKey(lIdentity.UnitId.Value,
        lIdentity.OwnerScopeId, lIdentity.Name), lIdentity);
  end else
  begin
    fByQualifiedName.AddOrSetValue(lIdentity.UnitName + '.' + lIdentity.Name, lIdentity);
    AddToMap(fBySimpleName, lIdentity.Name, lIdentity);
  end;
end;

function TDelphiSemanticTypeIdentityIndexData.TryFinalizeLocalAlias(
  var aIdentity: TDelphiSemanticTypeIdentity): Boolean;
var
  lLookup: TDelphiSemanticTypeLookupResult;
  lPointer: Boolean;
  lTargetName: string;
begin
  Result := False;
  if (aIdentity.OwnerScopeId = '') or (aIdentity.SemanticSymbolId = '') or
    (aIdentity.CanonicalName = '') then
    Exit;
  lTargetName := aIdentity.CanonicalName.Trim;
  lPointer := (lTargetName <> '') and (lTargetName[1] = '^');
  if lPointer then
    lTargetName := Copy(lTargetName, 2, MaxInt).Trim;
  if (lTargetName = '') or (Pos('^', lTargetName) > 0) or
    SameText(lTargetName, aIdentity.Name) then
    Exit;
  lLookup := ResolveScopedName(lTargetName, aIdentity.UnitName,
    aIdentity.OwnerScopeId, [aIdentity.UnitName], aIdentity.SectionKind);
  if not lLookup.Found or lLookup.Ambiguous or
    (lLookup.Identity.DeclaredId.Value = '') or
    (lLookup.Identity.CanonicalId.Value = '') or
    (lLookup.Identity.UnderlyingId.Value = '') then
    Exit;
  if lPointer then
  begin
    aIdentity.CanonicalId := StableTypeId(aIdentity.UnitId, 'local-pointer',
      lLookup.Identity.CanonicalId.Value);
    aIdentity.UnderlyingId := aIdentity.CanonicalId;
    aIdentity.UnderlyingName := '^' + lLookup.Identity.Name;
  end else
  begin
    aIdentity.CanonicalId := lLookup.Identity.CanonicalId;
    aIdentity.UnderlyingId := lLookup.Identity.UnderlyingId;
    aIdentity.UnderlyingName := lLookup.Identity.UnderlyingName;
  end;
  Result := True;
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

function TDelphiSemanticTypeIdentityIndexData.ResolveScopedName(const aName,
  aCurrentUnitName, aCallerScopeId: string; const aVisibleUnitNames: TArray<string>;
  const aSectionKind: string): TDelphiSemanticTypeLookupResult;
var
  lCandidate: TDelphiSemanticGraphRoutine;
  lChild: TDelphiSemanticGraphRoutine;
  lHadChild: Boolean;
  lList: TDelphiSemanticTypeIdentityList;
  lRoutine: TDelphiSemanticGraphRoutine;
  lScopeId: string;
  lScopePath: TArray<string>;
  lScopeKey: string;
  lStatus: string;
  lUnitId: string;
  lVisited: TDictionary<string, Byte>;
begin
  if (aCallerScopeId = '') or (aCurrentUnitName = '') or
    not fUnitIdsByName.TryGetValue(aCurrentUnitName, lUnitId) or
    not fUnitScopeStatus.TryGetValue(lUnitId, lStatus) or
    not SameText(lStatus, 'ast') then
    Exit(UnresolvedResult(aName, 'CALLER_SCOPE_UNKNOWN',
      'The source-backed caller scope is unavailable.'));
  lVisited := TDictionary<string, Byte>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
  try
    lScopeId := aCallerScopeId;
    lHadChild := False;
    while lScopeId <> '' do
    begin
      lScopeKey := ScopedKey(lUnitId, lScopeId);
      if lVisited.ContainsKey(lScopeKey) or fInvalidScopes.ContainsKey(lScopeKey) or
        not fRoutineScopes.TryGetValue(lScopeKey, lRoutine) or
        (lRoutine.SourceRange.Line < 1) or
        (lRoutine.SourceRange.EndLine < lRoutine.SourceRange.Line) then
        Exit(UnresolvedResult(aName, 'CALLER_SCOPE_INVALID',
          'The caller scope chain is stale, cyclic, or incomplete.'));
      if lHadChild and ((lRoutine.SourceRange.Line >= lChild.SourceRange.Line) or
        (lRoutine.SourceRange.EndLine < lChild.SourceRange.EndLine)) then
        Exit(UnresolvedResult(aName, 'CALLER_SCOPE_INVALID',
          'The parent routine does not enclose the caller.'));
      if lRoutine.ParentScopeId = '' then
        for lCandidate in fRoutineScopes.Values do
          if SameText(lCandidate.UnitId.Value, lUnitId) and
            (not SameText(lCandidate.ScopeId, lRoutine.ScopeId)) and
            (lCandidate.SourceRange.Line < lRoutine.SourceRange.Line) and
            (lCandidate.SourceRange.EndLine >= lRoutine.SourceRange.EndLine) then
            Exit(UnresolvedResult(aName, 'CALLER_SCOPE_INVALID',
              'A nested routine has no verified parent scope.'));
      lVisited.Add(lScopeKey, 0);
      SetLength(lScopePath, Length(lScopePath) + 1);
      lScopePath[High(lScopePath)] := lScopeId;
      lChild := lRoutine;
      lHadChild := True;
      lScopeId := lRoutine.ParentScopeId;
    end;
  finally
    lVisited.Free;
  end;
  for lScopeId in lScopePath do
  begin
    if fUnsupportedLocalScopeName.ContainsKey(LocalTypeKey(lUnitId, lScopeId,
      aName)) then
      Exit(UnresolvedResult(aName, 'UNSUPPORTED_LOCAL_TYPE',
        'The nearest local type declaration has no supported identity.'));
    if (Pos('.', aName) = 0) and fByLocalScopeName.TryGetValue(
      LocalTypeKey(lUnitId, lScopeId, aName), lList) then
    begin
      if lList.Count = 1 then
        Exit(ResolvedResult(lList[0]));
      Exit(AmbiguousResult(aName, lList.ToArray));
    end;
  end;
  if Pos('.', aName) > 0 then
    Result := ResolveQualifiedName(aName)
  else
    Result := ResolveVisibleName(aName, aCurrentUnitName, aVisibleUnitNames,
      aSectionKind);
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
  if SameText(aIdentity.ScopeKind, 'routine') then
  begin
    if aIdentity.CanonicalName[1] = '^' then
      Exit(False);
    lResult := ResolveScopedName(aIdentity.CanonicalName, aIdentity.UnitName,
      aIdentity.OwnerScopeId, [aIdentity.UnitName], aIdentity.SectionKind);
    Result := lResult.Found and (not lResult.Ambiguous) and
      (lResult.Identity.DeclaredId.Value <> aIdentity.DeclaredId.Value);
    if Result then
      aTarget := lResult.Identity;
    Exit;
  end;

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

function TDelphiSemanticTypeIdentityIndex.ResolveScopedName(const aName,
  aCurrentUnitName, aCallerScopeId: string; const aVisibleUnitNames: TArray<string>;
  const aSectionKind: string): TDelphiSemanticTypeLookupResult;
begin
  if fData = nil then
    Exit(TDelphiSemanticTypeIdentityIndexData.UnresolvedResult(aName, 'INDEX_NOT_BUILT',
      'The type identity index has not been built.'));

  Result := fData.ResolveScopedName(aName, aCurrentUnitName, aCallerScopeId,
    aVisibleUnitNames, aSectionKind);
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
