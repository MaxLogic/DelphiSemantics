unit DelphiSemantics.Resolve.TypeResolver;

interface

uses
  DelphiSemantics.Model, DelphiSemantics.Resolve.UnitNameWitness,
  DelphiSemantics.RootMemberAbsence, DelphiSemantics.SemanticGraph;

type
  TDelphiSemanticNameOutcome = (noUnproved, noResolved, noAmbiguous, noAbsent);
  TDelphiSemanticNameSiteKind = (nskSource, nskMetadata);

  TDelphiSemanticNameSite = record
    Kind: TDelphiSemanticNameSiteKind;
    UnitName: string;
    SectionKind: string;
    FileName: string;
    Line, Column: Integer;
    RoutineScopeId: string;
    ClassScopeId: TDelphiSemanticGraphTypeId;
    LocalCutoffLine: Integer;
    ForwardPointerTarget: Boolean;
    Origin: string;
    CaptureVisibility: Boolean;
  end;

  TDelphiSemanticTypeIdentity = record
    Synthetic: Boolean;
    MembersClosed: Boolean;
    EnclosingTypeId: TDelphiSemanticGraphTypeId;
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
    HelperParentName: string;
    SectionKind: string;
    ScopeKind: string;
    OwnerScopeId: string;
    SemanticSymbolId: string;
    SourceRange: TDelphiSemanticSourceRange;
  end;

  TDelphiSemanticLineage = record
    Items: TArray<TDelphiSemanticTypeIdentity>;
    Complete: Boolean;
    Cause: string;
    ImplicitRoot: string;
    RootIndexed: Boolean;
    StrongAliasAt: Integer;
  end;

  TDelphiSemanticHelperLevel = record
    Identity: TDelphiSemanticTypeIdentity;
    Outcome: TDelphiSemanticNameOutcome;
    Chain: TArray<TDelphiSemanticTypeIdentity>;
    Cause: string;
    ProjectOwned: Boolean;
  end;

  TDelphiSemanticHelperResolution = record
    Levels: TArray<TDelphiSemanticHelperLevel>;
    OpenFromLevel: Integer;
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

  TDelphiSemanticTypeResolution = record
    Outcome: TDelphiSemanticNameOutcome;
    Identity: TDelphiSemanticTypeIdentity;
    Candidates: TArray<TDelphiSemanticTypeIdentity>;
    ReasonCode: string;
    Cause: string;
    Reason: string;
    DecidingScope: string;
    function AsLookupResult: TDelphiSemanticTypeLookupResult;
  end;

  TDelphiSemanticValueResolution = record
    Outcome: TDelphiSemanticNameOutcome;
    UnitName: string;
    Identity: TDelphiSemanticGraphDeclaration;
    Candidates: TArray<TDelphiSemanticGraphDeclaration>;
    ReasonCode: string;
    Cause: string;
    Reason: string;
    DecidingScope: string;
  end;

  IDelphiSemanticTypeIdentityIndexData = interface
    ['{B6C3E987-C5DD-4BE9-A55E-A9E80172CF68}']
    function ResolveTypeAt(const aSite: TDelphiSemanticNameSite; const aSpelling: string):
      TDelphiSemanticTypeResolution;
    function ResolveActiveHelperAt(const aTargetId: TDelphiSemanticGraphTypeId;
      const aSite: TDelphiSemanticNameSite): TDelphiSemanticTypeResolution;
    function ResolveHelpersAt(const aLineage: TDelphiSemanticLineage;
      const aSite: TDelphiSemanticNameSite): TDelphiSemanticHelperResolution;
    function ProjectOwnedTo(const aLineage: TDelphiSemanticLineage;
      const aLevel: Integer): Boolean;
    function ProjectOwned(const aLineage: TDelphiSemanticLineage): Boolean;
    function ResolveValueRootAt(const aSite: TDelphiSemanticNameSite; const aName: string):
      TDelphiSemanticValueResolution;
    function ResolveInterfaceMetadataName(const aName, aCurrentUnitName: string;
      const aOwnerTypeName: string = ''): TDelphiSemanticTypeLookupResult;
    function FindByCanonicalId(const aId: TDelphiSemanticGraphTypeId):
      TArray<TDelphiSemanticTypeIdentity>;
    function FindByDeclaredId(const aId: TDelphiSemanticGraphTypeId; out aIdentity:
      TDelphiSemanticTypeIdentity): Boolean;
    function FindByUnderlyingId(const aId: TDelphiSemanticGraphTypeId):
      TArray<TDelphiSemanticTypeIdentity>;
    function ResolveLineage(const aIdentity: TDelphiSemanticTypeIdentity):
      TDelphiSemanticLineage;
    function FindAncestors(const aIdentity: TDelphiSemanticTypeIdentity):
      TArray<TDelphiSemanticTypeIdentity>;
    function FindHelpersForTarget(const aTargetTypeName: string):
      TArray<TDelphiSemanticTypeIdentity>;
    // Not position-aware; never use for rewrite admission.
    function ResolveQualifiedName(const aName: string): TDelphiSemanticTypeLookupResult;
    // Not position-aware; never use for rewrite admission.
    function ResolveSimpleName(const aName: string): TDelphiSemanticTypeLookupResult;
    // Not position-aware; never use for rewrite admission.
    function ResolveScopedName(const aName, aCurrentUnitName, aCallerScopeId: string;
      const aVisibleUnitNames: TArray<string>; const aSectionKind: string):
      TDelphiSemanticTypeLookupResult;
    function VisibleUnitNames(const aUnitName, aSectionKind: string): TArray<string>;
    // Not position-aware; never use for rewrite admission.
    function ResolveVisibleName(const aName, aCurrentUnitName: string;
      const aVisibleUnitNames: TArray<string>; const aSectionKind: string):
      TDelphiSemanticTypeLookupResult;
  end;

  TDelphiSemanticTypeIdentityIndex = record
  private
    fData: IDelphiSemanticTypeIdentityIndexData;
  public
    function ResolveTypeAt(const aSite: TDelphiSemanticNameSite; const aSpelling: string):
      TDelphiSemanticTypeResolution;
    function ResolveActiveHelperAt(const aTargetId: TDelphiSemanticGraphTypeId;
      const aSite: TDelphiSemanticNameSite): TDelphiSemanticTypeResolution;
    function ResolveHelpersAt(const aLineage: TDelphiSemanticLineage;
      const aSite: TDelphiSemanticNameSite): TDelphiSemanticHelperResolution;
    function ProjectOwnedTo(const aLineage: TDelphiSemanticLineage;
      const aLevel: Integer): Boolean;
    function ProjectOwned(const aLineage: TDelphiSemanticLineage): Boolean;
    function ResolveValueRootAt(const aSite: TDelphiSemanticNameSite; const aName: string):
      TDelphiSemanticValueResolution;
    function ResolveInterfaceMetadataName(const aName, aCurrentUnitName: string;
      const aOwnerTypeName: string = ''): TDelphiSemanticTypeLookupResult;
    function FindByCanonicalId(const aId: TDelphiSemanticGraphTypeId):
      TArray<TDelphiSemanticTypeIdentity>;
    function FindByDeclaredId(const aId: TDelphiSemanticGraphTypeId; out aIdentity:
      TDelphiSemanticTypeIdentity): Boolean;
    function FindByUnderlyingId(const aId: TDelphiSemanticGraphTypeId):
      TArray<TDelphiSemanticTypeIdentity>;
    function ResolveLineage(const aIdentity: TDelphiSemanticTypeIdentity):
      TDelphiSemanticLineage;
    function FindAncestors(const aIdentity: TDelphiSemanticTypeIdentity):
      TArray<TDelphiSemanticTypeIdentity>;
    function FindHelpersForTarget(const aTargetTypeName: string):
      TArray<TDelphiSemanticTypeIdentity>;
    // Not position-aware; never use for rewrite admission.
    function ResolveQualifiedName(const aName: string): TDelphiSemanticTypeLookupResult;
    // Not position-aware; never use for rewrite admission.
    function ResolveSimpleName(const aName: string): TDelphiSemanticTypeLookupResult;
    // Not position-aware; never use for rewrite admission.
    function ResolveScopedName(const aName, aCurrentUnitName, aCallerScopeId: string;
      const aVisibleUnitNames: TArray<string>; const aSectionKind: string = 'implementation'):
      TDelphiSemanticTypeLookupResult;
    function VisibleUnitNames(const aUnitName, aSectionKind: string): TArray<string>;
    // Not position-aware; never use for rewrite admission.
    function ResolveVisibleName(const aName, aCurrentUnitName: string;
      const aVisibleUnitNames: TArray<string>; const aSectionKind: string = 'interface'):
      TDelphiSemanticTypeLookupResult;
  end;

  TDelphiSemanticTypeResolver = record
  public
    class function BuildIndex(const aGraph: TDelphiSemanticSemanticGraph):
      TDelphiSemanticTypeIdentityIndex; overload; static;
    class function BuildIndex(const aGraph: TDelphiSemanticSemanticGraph;
      const aNamedRootAbsence: IDelphiSemanticNamedRootMemberAbsence):
      TDelphiSemanticTypeIdentityIndex; overload; static;
    class function VerifiedRoutineBody(const aModel: TDelphiSemanticUnitModel;
      const aFirst, aSecond: TDelphiSemanticRoutine;
      out aBody: TDelphiSemanticRoutine): Boolean; static;
  end;

implementation

uses
  System.Classes, System.Generics.Collections, System.Hash, System.RegularExpressions,
  System.StrUtils, System.SysUtils,
  MaxLogic.StrUtils,
  DelphiSemantics.Resolve.NameSites;

type
  TDelphiSemanticTypeIdentityList = TList<TDelphiSemanticTypeIdentity>;
  TDelphiSemanticGraphDeclarationList = TList<TDelphiSemanticGraphDeclaration>;
  TDelphiSemanticUnitDecision = record
    Outcome: TDelphiSemanticNameOutcome;
    UnitName: string;
    Cause: string;
    IsUnit: Boolean;
  end;

  TDelphiSemanticTypeIdentityIndexData = class(TInterfacedObject,
    IDelphiSemanticTypeIdentityIndexData)
  private
    fByCanonicalId: TDictionary<string, TDelphiSemanticTypeIdentityList>;
    fByDeclaredId: TDictionary<string, TDelphiSemanticTypeIdentity>;
    fVisibilityRanges: TDictionary<string, TDelphiSemanticSourceRange>;
    fByQualifiedName: TDictionary<string, TDelphiSemanticTypeIdentity>;
    fHelpersByTargetName: TDictionary<string, TDelphiSemanticTypeIdentityList>;
    fBySimpleName: TDictionary<string, TDelphiSemanticTypeIdentityList>;
    fByLocalScopeName: TDictionary<string, TDelphiSemanticTypeIdentityList>;
    fUnsupportedLocalScopeName: TDictionary<string, Byte>;
    fByUnderlyingId: TDictionary<string, TDelphiSemanticTypeIdentityList>;
    fRoutineScopes: TDictionary<string, TDelphiSemanticGraphRoutine>;
    fInvalidScopes: TDictionary<string, Byte>;
    fUnitNameWitness: IDelphiSemanticUnitNameWitness;
    fNamedRootAbsence: IDelphiSemanticNamedRootMemberAbsence;
    fUnits: TDictionary<string, TDelphiSemanticGraphUnit>;
    fSiteUnits: TArray<TDelphiSemanticGraphUnit>;
    fUnitValuesByName: TDictionary<string, TDelphiSemanticGraphDeclarationList>;
    fDeclarations: TArray<TDelphiSemanticGraphDeclaration>;
    fLocals: TArray<TDelphiSemanticGraphLocal>;
    fParameters: TArray<TDelphiSemanticGraphParameter>;
    fMembers: TArray<TDelphiSemanticGraphMember>;
    fUnitIdsByName: TDictionary<string, string>;
    fUnitScopeStatus: TDictionary<string, string>;
    fUnitNamesById: TDictionary<string, string>;
    function FindHelperSiteUnit(const aSite: TDelphiSemanticNameSite;
      out aUnit: TDelphiSemanticGraphUnit): Boolean;
    function ResolveHelperInUnit(const aTarget: TDelphiSemanticTypeIdentity;
      const aSite: TDelphiSemanticNameSite; const aUnitName: string;
      const aOwn: Boolean; const aExactSite: Boolean = False): TDelphiSemanticTypeResolution;
    function WeakAliasTerminal(const aIdentity: TDelphiSemanticTypeIdentity;
      out aTerminal: TDelphiSemanticTypeIdentity): Boolean;
    function HelperReceiverTerminal(const aIdentity: TDelphiSemanticTypeIdentity;
      out aTerminal: TDelphiSemanticTypeIdentity; out aIndirect: Boolean): Boolean;
    function HelperApplicabilityLineage(const aLineage: TDelphiSemanticLineage):
      TDelphiSemanticLineage;
    function CompareWeakAliasTargets(const aLeft, aRight: TDelphiSemanticTypeIdentity):
      TDelphiSemanticNameOutcome;
    function RoutineScopePath(const aSite: TDelphiSemanticNameSite;
      out aPath: TArray<TDelphiSemanticGraphRoutine>): Boolean;
    function ResolveTypeCore(const aSite: TDelphiSemanticNameSite;
      const aSpelling: string; const aUnitHead: Boolean;
      out aResolvedUnit: string): TDelphiSemanticTypeResolution;
    function CaptureIdentityDependenciesKnown(const aIdentity: TDelphiSemanticTypeIdentity;
      const aVisited: THashSet<string>; const aCallerUnitName: string): Boolean;
    function IsAliasConflict(const aUnitName, aImportName: string): Boolean;
    function VisibleAt(const aSite: TDelphiSemanticNameSite;
      const aRange: TDelphiSemanticSourceRange; const aLocal: Boolean): Integer;
    function CaptureScopeClosed(const aUnit: TDelphiSemanticGraphUnit;
      const aSite: TDelphiSemanticNameSite; const aOwn: Boolean): Boolean;
    function CaptureNamesAgree(const aSite: TDelphiSemanticNameSite;
      const aName, aScopeKind, aScopeId, aUnitName: string;
      const aPositional: Boolean): Boolean;
    function TypesInScope(const aSite: TDelphiSemanticNameSite;
      const aName, aScopeKind, aScopeId, aUnitName: string; const aPositional: Boolean):
      TDelphiSemanticTypeResolution;
    function WalkVisibleUnits(const aSite: TDelphiSemanticNameSite;
      const aName: string; const aValues: Boolean; const aUnitHead: Boolean = False;
      const aImportsOverride: TArray<string> = nil;
      const aUseImportsOverride: Boolean = False): TDelphiSemanticUnitDecision;
    function UnitValues(const aUnitName, aName: string;
      const aInterfaceOnly: Boolean): TArray<TDelphiSemanticGraphDeclaration>;
    function ResolveNestedTypeAt(const aOwner: TDelphiSemanticTypeIdentity;
      const aName: string; const aSite: TDelphiSemanticNameSite): TDelphiSemanticTypeResolution;
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
    constructor Create(const aGraph: TDelphiSemanticSemanticGraph;
      const aNamedRootAbsence: IDelphiSemanticNamedRootMemberAbsence = nil);
    destructor Destroy; override;
    function ResolveTypeAt(const aSite: TDelphiSemanticNameSite; const aSpelling: string):
      TDelphiSemanticTypeResolution;
    function ResolveActiveHelperAt(const aTargetId: TDelphiSemanticGraphTypeId;
      const aSite: TDelphiSemanticNameSite): TDelphiSemanticTypeResolution;
    function ResolveHelpersAt(const aLineage: TDelphiSemanticLineage;
      const aSite: TDelphiSemanticNameSite): TDelphiSemanticHelperResolution;
    function ProjectOwnedTo(const aLineage: TDelphiSemanticLineage;
      const aLevel: Integer): Boolean;
    function ProjectOwned(const aLineage: TDelphiSemanticLineage): Boolean;
    function ResolveValueRootAt(const aSite: TDelphiSemanticNameSite; const aName: string):
      TDelphiSemanticValueResolution;
    function ResolveInterfaceMetadataName(const aName, aCurrentUnitName: string;
      const aOwnerTypeName: string = ''): TDelphiSemanticTypeLookupResult;
    function FindByCanonicalId(const aId: TDelphiSemanticGraphTypeId):
      TArray<TDelphiSemanticTypeIdentity>;
    function FindByDeclaredId(const aId: TDelphiSemanticGraphTypeId; out aIdentity:
      TDelphiSemanticTypeIdentity): Boolean;
    function FindByUnderlyingId(const aId: TDelphiSemanticGraphTypeId):
      TArray<TDelphiSemanticTypeIdentity>;
    function ResolveLineage(const aIdentity: TDelphiSemanticTypeIdentity):
      TDelphiSemanticLineage;
    function FindAncestors(const aIdentity: TDelphiSemanticTypeIdentity):
      TArray<TDelphiSemanticTypeIdentity>;
    function FindHelpersForTarget(const aTargetTypeName: string):
      TArray<TDelphiSemanticTypeIdentity>;
    // Not position-aware; never use for rewrite admission.
    function ResolveQualifiedName(const aName: string): TDelphiSemanticTypeLookupResult;
    // Not position-aware; never use for rewrite admission.
    function ResolveSimpleName(const aName: string): TDelphiSemanticTypeLookupResult;
    // Not position-aware; never use for rewrite admission.
    function ResolveScopedName(const aName, aCurrentUnitName, aCallerScopeId: string;
      const aVisibleUnitNames: TArray<string>; const aSectionKind: string):
      TDelphiSemanticTypeLookupResult;
    function VisibleUnitNames(const aUnitName, aSectionKind: string): TArray<string>;
    // Not position-aware; never use for rewrite admission.
    function ResolveVisibleName(const aName, aCurrentUnitName: string;
      const aVisibleUnitNames: TArray<string>; const aSectionKind: string):
      TDelphiSemanticTypeLookupResult;
  end;

function TDelphiSemanticTypeResolution.AsLookupResult: TDelphiSemanticTypeLookupResult;
begin
  Result := Default(TDelphiSemanticTypeLookupResult);
  Result.Identity := Identity;
  Result.Candidates := Candidates;
  Result.ReasonCode := ReasonCode;
  Result.Reason := Reason;
  Result.Found := Outcome = noResolved;
  Result.Ambiguous := Outcome = noAmbiguous;
  case Outcome of
    noResolved: Result.Status := 'resolved';
    noUnproved: Result.Status := 'unproved';
    noAmbiguous: Result.Status := 'ambiguous';
    noAbsent: Result.Status := 'unresolved';
  end;
end;

function TDelphiSemanticTypeIdentityIndex.ResolveTypeAt(const aSite: TDelphiSemanticNameSite;
  const aSpelling: string): TDelphiSemanticTypeResolution;
begin
  Result := Default(TDelphiSemanticTypeResolution);
  Result.Outcome := noUnproved;
  Result.Cause := 'caller-scope-invalid';
  if fData <> nil then
    Result := fData.ResolveTypeAt(aSite, aSpelling);
end;

function TDelphiSemanticTypeIdentityIndex.ResolveActiveHelperAt(
  const aTargetId: TDelphiSemanticGraphTypeId;
  const aSite: TDelphiSemanticNameSite): TDelphiSemanticTypeResolution;
begin
  Result := Default(TDelphiSemanticTypeResolution);
  Result.Outcome := noUnproved;
  if fData <> nil then
    Result := fData.ResolveActiveHelperAt(aTargetId, aSite);
end;

function TDelphiSemanticTypeIdentityIndex.ResolveHelpersAt(
  const aLineage: TDelphiSemanticLineage; const aSite: TDelphiSemanticNameSite):
  TDelphiSemanticHelperResolution;
begin
  Result := Default(TDelphiSemanticHelperResolution);
  Result.OpenFromLevel := 0;
  if fData <> nil then
    Result := fData.ResolveHelpersAt(aLineage, aSite);
end;

function TDelphiSemanticTypeIdentityIndex.ProjectOwnedTo(
  const aLineage: TDelphiSemanticLineage; const aLevel: Integer): Boolean;
begin
  Result := (fData <> nil) and fData.ProjectOwnedTo(aLineage, aLevel);
end;

function TDelphiSemanticTypeIdentityIndex.ProjectOwned(
  const aLineage: TDelphiSemanticLineage): Boolean;
begin
  Result := (fData <> nil) and fData.ProjectOwned(aLineage);
end;

function TDelphiSemanticTypeIdentityIndex.ResolveValueRootAt(const aSite: TDelphiSemanticNameSite;
  const aName: string): TDelphiSemanticValueResolution;
begin
  Result := Default(TDelphiSemanticValueResolution);
  Result.Outcome := noUnproved;
  Result.Cause := 'caller-scope-invalid';
  if fData <> nil then
    Result := fData.ResolveValueRootAt(aSite, aName);
end;

function ScopedKey(const aUnitId, aScopeId: string): string;
begin
  Result := aUnitId + #1 + aScopeId;
end;

function LocalTypeKey(const aUnitId, aScopeId, aName: string): string;
begin
  Result := ScopedKey(aUnitId, aScopeId) + #1 + aName;
end;

function NameResolution(const aOutcome: TDelphiSemanticNameOutcome;
  const aCause, aScope, aName: string): TDelphiSemanticTypeResolution;
begin
  Result := Default(TDelphiSemanticTypeResolution);
  Result.Outcome := aOutcome;
  Result.Cause := aCause;
  Result.DecidingScope := aScope;
  Result.Reason := aCause + ': ' + aName + ' in ' + aScope;
  case aOutcome of
    noResolved: Result.ReasonCode := '';
    noUnproved: Result.ReasonCode := 'TYPE_VISIBILITY_UNPROVED';
    noAmbiguous: Result.ReasonCode := 'TYPE_AMBIGUOUS';
    noAbsent: Result.ReasonCode := 'TYPE_NOT_VISIBLE';
  end;
end;

function TDelphiSemanticTypeIdentityIndexData.IsAliasConflict(const aUnitName,
  aImportName: string): Boolean;
var
  lUnit: TDelphiSemanticGraphUnit;
begin
  Result := fUnits.TryGetValue(aUnitName, lUnit) and MatchText(aImportName, lUnit.AliasConflictNames);
end;

function TDelphiSemanticTypeIdentityIndexData.VisibleAt(const aSite: TDelphiSemanticNameSite;
  const aRange: TDelphiSemanticSourceRange; const aLocal: Boolean): Integer;
var
  lFileName: string;
  lInterval: string;
  lLines: TStringList;
  lStart, lFinish: Integer;
  lUnit: TDelphiSemanticGraphUnit;
begin
  Result := -1;
  lFileName := aRange.FileName;
  if not fUnits.TryGetValue(aSite.UnitName, lUnit) then
    Exit;
  if lFileName = '' then
    lFileName := lUnit.FileName;
  if (aSite.Line <= 0) or (aSite.Column <= 0) or (aRange.Line <= 0) or
    (aRange.Column <= 0) or not SameText(lFileName, aSite.FileName) then
    Exit;
  if aLocal and (aSite.LocalCutoffLine > 0) then
  begin
    if not SameText(lFileName, lUnit.FileName) then
      Exit;
    if aRange.Line >= aSite.LocalCutoffLine then
      Exit(0);
  end;
  if (aRange.Line < aSite.Line) or ((aRange.Line = aSite.Line) and
    (aRange.Column < aSite.Column)) then
    Exit(1);
  Result := 0;
  if not aSite.ForwardPointerTarget then
    Exit;
  if (lUnit.SourceText = '') or not SameText(lFileName, lUnit.FileName) then
    Exit(-1);
  lLines := TStringList.Create;
  try
    lLines.Text := lUnit.SourceText;
    if (aSite.Line > lLines.Count) or (aRange.Line > lLines.Count) then
      Exit(-1);
    lStart := 0;
    for var i := 0 to aSite.Line - 2 do
      Inc(lStart, Length(lLines[i]) + Length(sLineBreak));
    Inc(lStart, aSite.Column);
    lFinish := 0;
    for var i := 0 to aRange.Line - 2 do
      Inc(lFinish, Length(lLines[i]) + Length(sLineBreak));
    Inc(lFinish, aRange.Column);
    lInterval := Copy(lUnit.SourceText, lStart, lFinish - lStart);
    if ContainsText(lInterval, '{$') or ContainsText(lInterval, '(*$') then
      Exit(-1);
    lInterval := TRegEx.Replace(lInterval,
      '''(?:''''|[^''])*''|//[^\r\n]*|\{[^}]*\}|\(\*.*?\*\)', ' ', [roSingleLine]);
    if not TRegEx.IsMatch(lInterval,
      '\b(type|var|const|resourcestring|threadvar|label|procedure|function|constructor|destructor|begin|implementation)\b',
      [roIgnoreCase]) then
      Result := 1;
  finally
    lLines.Free;
  end;
end;

function TDelphiSemanticTypeIdentityIndexData.CaptureScopeClosed(
  const aUnit: TDelphiSemanticGraphUnit; const aSite: TDelphiSemanticNameSite;
  const aOwn: Boolean): Boolean;
begin
  if not aSite.CaptureVisibility then
    Exit(aUnit.TypeNamesKnown);
  if aOwn then
    Result := aUnit.CaptureScopeProof.Known
  else
    Result := aUnit.CaptureExportProof.Known;
end;

function TDelphiSemanticTypeIdentityIndexData.CaptureNamesAgree(
  const aSite: TDelphiSemanticNameSite; const aName, aScopeKind, aScopeId,
  aUnitName: string; const aPositional: Boolean): Boolean;
var
  lUnit: TDelphiSemanticGraphUnit;
  lProof: TDelphiSemanticCaptureScopeProof;
  lList: TDelphiSemanticTypeIdentityList;
  lRange: TDelphiSemanticSourceRange;
  lMatched, lRelevant: Boolean;
begin
  Result := True;
  if not aSite.CaptureVisibility then
    Exit;
  Result := False;
  if not fUnits.TryGetValue(aUnitName, lUnit) then
    Exit;
  if SameText(aUnitName, aSite.UnitName) then
    lProof := lUnit.CaptureScopeProof
  else
    lProof := lUnit.CaptureExportProof;
  if not lProof.Known then
    Exit;
  for var lFact in lProof.Names do
  begin
    if not SameText(lFact.Name, aName) then
      Continue;
    if aScopeKind = 'routine' then
      lRelevant := SameText(lFact.OwnerScopeId, aScopeId) and (lFact.OwnerTypeName = '')
    else if aScopeKind = 'class' then
      // Nested type lookup retains its existing owner proof. An unknown owner
      // cannot be used as evidence for a capture spelling.
      lRelevant := lFact.OwnerTypeName <> ''
    else
      lRelevant := (lFact.OwnerScopeId = '') and (lFact.OwnerTypeName = '');
    if not lRelevant then
      Continue;
    if not SameText(aUnitName, aSite.UnitName) and
      not SameText(lFact.SectionKind, 'interface') then
      Continue;
    if lProof.AbsenceOnly then
      Exit;
    lRange := Default(TDelphiSemanticSourceRange);
    lRange.FileName := lFact.FileName;
    lRange.Line := lFact.Line;
    lRange.Column := lFact.Column;
    if aPositional and (VisibleAt(aSite, lRange, aScopeKind = 'routine') = 0) then
      Continue;
    if (lFact.Kind <> 'type') or (lFact.VariantCount <> lProof.VariantCount) then
      Exit;
    lMatched := False;
    if fBySimpleName.TryGetValue(aName, lList) then
      for var lIdentity in lList do
      begin
        if not SameText(lIdentity.UnitName, aUnitName) then
          Continue;
        lRange := lIdentity.SourceRange;
        lMatched := lMatched or (SameText(lRange.FileName, lFact.FileName) and
          (lRange.Line = lFact.Line) and (lRange.Column = lFact.Column));
        if fVisibilityRanges.TryGetValue(lIdentity.DeclaredId.Value, lRange) then
          lMatched := lMatched or (SameText(lRange.FileName, lFact.FileName) and
            (lRange.Line = lFact.Line) and (lRange.Column = lFact.Column));
      end;
    if not lMatched then
      Exit;
  end;
  Result := True;
end;

function TDelphiSemanticTypeIdentityIndexData.TypesInScope(const aSite: TDelphiSemanticNameSite;
  const aName, aScopeKind, aScopeId, aUnitName: string; const aPositional: Boolean):
  TDelphiSemanticTypeResolution;
var
  lCandidates: TDelphiSemanticTypeIdentityList;
  lIdentity: TDelphiSemanticTypeIdentity;
  lList: TDelphiSemanticTypeIdentityList;
  lScope: string;
  lVisible: Integer;
begin
  lScope := aScopeKind + ':' + aScopeId;
  Result := NameResolution(noAbsent, '', lScope, aName);
  if not CaptureNamesAgree(aSite, aName, aScopeKind, aScopeId, aUnitName, aPositional) then
    Exit(NameResolution(noUnproved, 'capture-name-shadow-unproved', lScope, aName));
  if aScopeKind = 'routine' then
  begin
    var lUnitId: string;
    if not fUnitIdsByName.TryGetValue(aUnitName, lUnitId) or
      not fByLocalScopeName.TryGetValue(LocalTypeKey(lUnitId, aScopeId, aName), lList) then
      Exit;
  end else if not fBySimpleName.TryGetValue(aName, lList) then
    Exit;
  lCandidates := TDelphiSemanticTypeIdentityList.Create;
  try
    for lIdentity in lList do
    begin
      if lIdentity.Synthetic or not SameText(lIdentity.UnitName, aUnitName) then
        Continue;
      if aScopeKind = 'routine' then
      begin
        if not SameText(lIdentity.ScopeKind, 'routine') or
          not SameText(lIdentity.OwnerScopeId, aScopeId) then
          Continue;
      end else if aScopeKind = 'class' then
      begin
        if not SameText(lIdentity.ScopeKind, 'type') or
          not SameText(lIdentity.OwnerScopeId, aScopeId) then
          Continue;
      end else if MatchText(lIdentity.ScopeKind, ['routine', 'type']) then
        Continue;
      if not SameUnitOrInterfaceVisible(lIdentity, aSite.UnitName, aSite.SectionKind) then
        Continue;
      if aPositional then
      begin
        var lRange := lIdentity.SourceRange;
        fVisibilityRanges.TryGetValue(lIdentity.DeclaredId.Value, lRange);
        lVisible := VisibleAt(aSite, lRange, aScopeKind = 'routine');
        if lVisible < 0 then
          Exit(NameResolution(noUnproved, 'position-unknown', lScope, aName));
        if lVisible = 0 then
          Continue;
      end;
      // Forward declarations and bodies denote one declaration identity.
      var lDuplicate := False;
      for var lExisting in lCandidates do
        if (lExisting.DeclaredId.Value = lIdentity.DeclaredId.Value) and
          (lExisting.SemanticSymbolId <> '') and
          SameText(lExisting.SemanticSymbolId, lIdentity.SemanticSymbolId) then
          lDuplicate := True;
      if not lDuplicate then
        lCandidates.Add(lIdentity);
    end;
    if lCandidates.Count = 1 then
    begin
      if aSite.CaptureVisibility then
      begin
        var lUnit: TDelphiSemanticGraphUnit;
        if not fUnits.TryGetValue(aUnitName, lUnit) then
          Exit(NameResolution(noUnproved, 'capture-model-evidence-missing', lScope, aName));
        var lProof := lUnit.CaptureExportProof;
        if SameText(aUnitName, aSite.UnitName) then
          lProof := lUnit.CaptureScopeProof;
        var lPresent := False;
        for var lFact in lProof.Names do
          if (lFact.Kind = 'type') and SameText(lFact.Name, aName) and
            (lFact.VariantCount = lProof.VariantCount) and
            SameText(lFact.FileName, lCandidates[0].SourceRange.FileName) and
            (lFact.Line = lCandidates[0].SourceRange.Line) and
            (lFact.Column = lCandidates[0].SourceRange.Column) then
            lPresent := True;
        if not lProof.Known or not lPresent then
          Exit(NameResolution(noUnproved, 'capture-positive-declaration-unproved', lScope, aName));
      end;
      Result := NameResolution(noResolved, '', lScope, aName);
      Result.Identity := lCandidates[0];
    end else if lCandidates.Count > 1 then
    begin
      Result := NameResolution(noAmbiguous, '', lScope, aName);
      Result.Candidates := lCandidates.ToArray;
    end;
  finally
    lCandidates.Free;
  end;
end;

function TDelphiSemanticTypeIdentityIndexData.WalkVisibleUnits(const aSite: TDelphiSemanticNameSite;
  const aName: string; const aValues, aUnitHead: Boolean;
  const aImportsOverride: TArray<string>; const aUseImportsOverride: Boolean): TDelphiSemanticUnitDecision;
var
  lImports: TArray<string>;
  lUnitName, lUnknown, lCause: string;
  lUnit: TDelphiSemanticGraphUnit;
  lTypes: TDelphiSemanticTypeResolution;
  lHasCandidate: Boolean;
begin
  Result := Default(TDelphiSemanticUnitDecision);
  Result.Outcome := noAbsent;
  if aSite.CaptureVisibility and not aUseImportsOverride then
  begin
    if not fUnits.TryGetValue(aSite.UnitName, lUnit) or
      not lUnit.CaptureScopeProof.Known or (Length(lUnit.CaptureScopeProof.Imports) = 0) then
    begin
      Result.Outcome := noUnproved;
      Result.Cause := 'capture-import-evidence-missing';
      Result.UnitName := aSite.UnitName;
      Exit;
    end;
    var lFirst := True;
    for var lImportFacts in lUnit.CaptureScopeProof.Imports do
    begin
      lImports := lImportFacts.InterfaceImports;
      if SameText(aSite.SectionKind, 'implementation') then
        lImports := lImports + lImportFacts.ImplementationImports;
      if (Length(lImports) = 0) and (Length(lImportFacts.RootImports) > 0) then
        lImports := lImportFacts.RootImports;
      var lDecision := WalkVisibleUnits(aSite, aName, aValues, aUnitHead, lImports, True);
      if lFirst then
      begin
        Result := lDecision;
        lFirst := False;
      end else if (Result.Outcome <> lDecision.Outcome) or
        not SameText(Result.UnitName, lDecision.UnitName) or
        (Result.IsUnit <> lDecision.IsUnit) then
      begin
        Result.Outcome := noUnproved;
        Result.Cause := 'capture-import-order-unproved';
        Result.UnitName := aSite.UnitName;
        Exit;
      end;
    end;
    Exit;
  end;
  if aUseImportsOverride then
    lImports := aImportsOverride
  else
    lImports := VisibleUnitNames(aSite.UnitName, aSite.SectionKind);
  lUnknown := '';
  lCause := '';
  for var i := High(lImports) downto 0 do
  begin
    lUnitName := lImports[i];
    if SameText(lUnitName, aSite.UnitName) or (lUnitName = '') then
      Continue;
    if lUnitName = '<imports-unproved>' then
    begin
      lUnknown := lUnitName;
      lCause := 'imports-unproved';
      Continue;
    end;
    if IsAliasConflict(aSite.UnitName, lUnitName) then
    begin
      lUnknown := lUnitName;
      lCause := 'alias-conflict';
      Continue;
    end;
    if aUnitHead and SameText(lUnitName, aName) then
    begin
      Result.UnitName := lUnitName;
      Result.IsUnit := True;
      Result.Outcome := noResolved;
      if lUnknown <> '' then
      begin
        Result.Outcome := noUnproved;
        Result.UnitName := lUnknown;
        Result.Cause := lCause;
      end;
      Exit;
    end;
    if aSite.CaptureVisibility and not fUnits.ContainsKey(lUnitName) then
    begin
      // Missing indexed evidence is not a failed indexed proof. Keep external
      // imports on the existing witness path: absence requires SDK pairing.
      if (fUnitNameWitness = nil) or fUnitNameWitness.MayDeclare(lUnitName, aName) then
      begin
        lUnknown := lUnitName;
        lCause := 'witness-unknown';
      end;
      Continue;
    end;
    if fUnits.TryGetValue(lUnitName, lUnit) and not CaptureScopeClosed(lUnit, aSite, False) then
    begin
      lUnknown := lUnitName;
      lCause := 'later-unknown-unit';
      Continue;
    end;
    lTypes := TypesInScope(aSite, aName, 'uses', lUnitName, lUnitName, False);
    lHasCandidate := lTypes.Outcome <> noAbsent;
    if aValues then
      lHasCandidate := Length(UnitValues(lUnitName, aName, True)) > 0;
    if lHasCandidate then
    begin
      Result.UnitName := lUnitName;
      if lUnknown <> '' then
      begin
        Result.Outcome := noUnproved;
        Result.UnitName := lUnknown;
        Result.Cause := lCause;
        if lCause = 'witness-unknown' then
          Result.Cause := 'later-unknown-unit';
      end else
        Result.Outcome := noResolved;
      Exit;
    end;
    if fUnits.TryGetValue(lUnitName, lUnit) then
    begin
      if not CaptureScopeClosed(lUnit, aSite, False) then
      begin
        lUnknown := lUnitName;
        lCause := 'later-unknown-unit';
      end;
    end else if (fUnitNameWitness = nil) or fUnitNameWitness.MayDeclare(lUnitName, aName) then
    begin
      lUnknown := lUnitName;
      lCause := 'witness-unknown';
    end;
  end;
  if lUnknown <> '' then
  begin
    Result.Outcome := noUnproved;
    Result.UnitName := lUnknown;
    Result.Cause := lCause;
  end;
end;

function TDelphiSemanticTypeIdentityIndexData.RoutineScopePath(
  const aSite: TDelphiSemanticNameSite; out aPath: TArray<TDelphiSemanticGraphRoutine>): Boolean;
var
  lScopeId, lKey: string;
  lUnit: TDelphiSemanticGraphUnit;
  lRoutine, lChild: TDelphiSemanticGraphRoutine;
  lVisited: THashSet<string>;
begin
  Result := False;
  aPath := nil;
  if aSite.RoutineScopeId = '' then
    Exit(True);
  if not fUnits.TryGetValue(aSite.UnitName, lUnit) or
    not SameText(lUnit.ScopeModelStatus, 'ast') then
    Exit;
  lVisited := THashSet<string>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
  try
    lScopeId := aSite.RoutineScopeId;
    while lScopeId <> '' do
    begin
      lKey := ScopedKey(lUnit.Id.Value, lScopeId);
      if lVisited.Contains(lKey) or fInvalidScopes.ContainsKey(lKey) or
        not fRoutineScopes.TryGetValue(lKey, lRoutine) or
        (lRoutine.SourceRange.Line < 1) or
        (lRoutine.SourceRange.EndLine < lRoutine.SourceRange.Line) then
        Exit;
      if Length(aPath) > 0 then
      begin
        lChild := aPath[High(aPath)];
        if (lRoutine.SourceRange.Line >= lChild.SourceRange.Line) or
          (lRoutine.SourceRange.EndLine < lChild.SourceRange.EndLine) then
          Exit;
      end;
      if lRoutine.ParentScopeId = '' then
        for var lOther in fRoutineScopes.Values do
          if SameText(lOther.UnitId.Value, lUnit.Id.Value) and
            not SameText(lOther.ScopeId, lRoutine.ScopeId) and
            (lOther.SourceRange.Line < lRoutine.SourceRange.Line) and
            (lOther.SourceRange.EndLine >= lRoutine.SourceRange.EndLine) then
            Exit;
      lVisited.Add(lKey);
      aPath := aPath + [lRoutine];
      lScopeId := lRoutine.ParentScopeId;
    end;
    Result := True;
  finally
    lVisited.Free;
  end;
end;

function TDelphiSemanticTypeIdentityIndexData.ResolveInterfaceMetadataName(
  const aName, aCurrentUnitName, aOwnerTypeName: string): TDelphiSemanticTypeLookupResult;
var
  lOwner: TDelphiSemanticTypeIdentity;
  lSite: TDelphiSemanticNameSite;
begin
  lSite := TDelphiSemanticNameSites.AtMetadata(aCurrentUnitName, aOwnerTypeName);
  // The owner is verified interface metadata, not a source spelling lookup.
  if (aOwnerTypeName <> '') and
    fByQualifiedName.TryGetValue(aCurrentUnitName + '.' + aOwnerTypeName, lOwner) and
    SameText(lOwner.SectionKind, 'interface') and SameText(lOwner.CanonicalName, 'class') then
  begin
    lSite.FileName := lOwner.SourceRange.FileName;
    lSite.Line := lOwner.SourceRange.Line;
    lSite.Column := lOwner.SourceRange.Column;
  end;
  Result := ResolveTypeAt(lSite, aName).AsLookupResult;
end;

function TDelphiSemanticTypeIdentityIndex.ResolveInterfaceMetadataName(
  const aName, aCurrentUnitName, aOwnerTypeName: string): TDelphiSemanticTypeLookupResult;
begin
  if fData = nil then
    Exit(TDelphiSemanticTypeIdentityIndexData.UnresolvedResult(aName, 'INDEX_NOT_BUILT',
      'The type identity index has not been built.'));
  Result := fData.ResolveInterfaceMetadataName(aName, aCurrentUnitName, aOwnerTypeName);
end;

function TDelphiSemanticTypeIdentityIndexData.ResolveTypeAt(const aSite: TDelphiSemanticNameSite;
  const aSpelling: string): TDelphiSemanticTypeResolution;
var
  lUnitName: string;
  lVisited: THashSet<string>;
begin
  Result := ResolveTypeCore(aSite, aSpelling, False, lUnitName);
  if not aSite.CaptureVisibility or (Result.Outcome <> noResolved) then
    Exit;
  lVisited := THashSet<string>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
  try
    if not CaptureIdentityDependenciesKnown(Result.Identity, lVisited, aSite.UnitName) then
      Result := NameResolution(noUnproved, 'capture-identity-dependency-unproved',
        Result.DecidingScope, aSpelling);
  finally
    lVisited.Free;
  end;
end;

function TDelphiSemanticTypeIdentityIndexData.CaptureIdentityDependenciesKnown(
  const aIdentity: TDelphiSemanticTypeIdentity; const aVisited: THashSet<string>;
  const aCallerUnitName: string): Boolean;
var
  lUnit: TDelphiSemanticGraphUnit;
  lProof: TDelphiSemanticCaptureScopeProof;
  lFound: Boolean;
  lLookup: TDelphiSemanticTypeResolution;
  lOwner: TDelphiSemanticTypeIdentity;
  lSite: TDelphiSemanticNameSite;
  lUnitName: string;
begin
  Result := False;
  if (aIdentity.DeclaredId.Value = '') or aVisited.Contains(aIdentity.DeclaredId.Value) or
    not fUnits.TryGetValue(aIdentity.UnitName, lUnit) then
    Exit;
  aVisited.Add(aIdentity.DeclaredId.Value);
  try
    lProof := lUnit.CaptureScopeProof;
    // An own-unit capture uses its full lexical scope, including program roots.
    // Only a dependency crossing the unit boundary relies on exported evidence.
    if not SameText(aIdentity.UnitName, aCallerUnitName) and
      SameText(aIdentity.SectionKind, 'interface') then
      lProof := lUnit.CaptureExportProof;
    if not lProof.Known or lProof.AbsenceOnly then
      Exit;
    lFound := False;
    for var lFact in lProof.Names do
    begin
      if (lFact.Kind <> 'type') or not SameText(lFact.Name, aIdentity.Name) or
        not SameText(lFact.FileName, aIdentity.SourceRange.FileName) or
        (lFact.Line <> aIdentity.SourceRange.Line) or
        (lFact.Column <> aIdentity.SourceRange.Column) then
        Continue;
      if (lFact.VariantCount <> lProof.VariantCount) or not lFact.IdentityTextKnown then
        Exit;
      lFound := True;
      lSite := TDelphiSemanticNameSites.AtTypeIdentity(aIdentity);
      lSite.CaptureVisibility := True;
      for var lDependency in lFact.IdentityDependencies do
      begin
        // Keep the declaration's own scope, imports and witness. Do not use
        // canonical spelling lookup or an ordinary alias walk as proof.
        lLookup := ResolveTypeCore(lSite, lDependency, False, lUnitName);
        if (lLookup.Outcome <> noResolved) or
          not CaptureIdentityDependenciesKnown(lLookup.Identity, aVisited, aCallerUnitName) then
          Exit;
      end;
    end;
    if not lFound then
      Exit;
    if aIdentity.EnclosingTypeId.Value <> '' then
      if not FindByDeclaredId(aIdentity.EnclosingTypeId, lOwner) or
        not CaptureIdentityDependenciesKnown(lOwner, aVisited, aCallerUnitName) then
        Exit;
    Result := True;
  finally
    aVisited.Remove(aIdentity.DeclaredId.Value);
  end;
end;

function TDelphiSemanticTypeIdentityIndexData.ResolveTypeCore(const aSite: TDelphiSemanticNameSite;
  const aSpelling: string; const aUnitHead: Boolean;
  out aResolvedUnit: string): TDelphiSemanticTypeResolution;
var
  lScopeId, lUnitId, lName, lHead, lTail: string;
  lUnit: TDelphiSemanticGraphUnit;
  lRoutine: TDelphiSemanticGraphRoutine;
  lPath: TArray<TDelphiSemanticGraphRoutine>;
  lDecision: TDelphiSemanticUnitDecision;
  lOwner: TDelphiSemanticTypeIdentity;
  lSite: TDelphiSemanticNameSite;
  lDot: Integer;
  lQualifiedUnit: string;
begin
  aResolvedUnit := '';
  lName := Trim(aSpelling);
  if (lName = '') or not fUnits.TryGetValue(aSite.UnitName, lUnit) then
    Exit(NameResolution(noUnproved, 'caller-scope-invalid', 'unit:' + aSite.UnitName, lName));
  if aSite.CaptureVisibility and not lUnit.CaptureScopeProof.Known then
    Exit(NameResolution(noUnproved, lUnit.CaptureScopeProof.Cause,
      'unit:' + aSite.UnitName, lName));
  // Qualified heads obey the same nearer-scope shadowing before unit matching.
  lDot := Pos('.', lName);
  if (lDot > 0) and not aUnitHead then
  begin
    lHead := Copy(lName, 1, lDot - 1);
    lTail := Copy(lName, lDot + 1, MaxInt);
    // A unit qualifier is an identifier candidate at the same scope boundary.
    // Routine, class and own-unit type homonyms still take precedence.
    Result := ResolveTypeCore(aSite, lHead, True, lQualifiedUnit);
    if Result.Outcome in [noUnproved, noAmbiguous] then
      Exit;
    if (Result.Outcome = noResolved) and (lQualifiedUnit = '') then
      Exit(ResolveNestedTypeAt(Result.Identity, lTail, aSite));
    if lQualifiedUnit = '' then
    begin
      var lPrefix := '';
      for var lImport in VisibleUnitNames(aSite.UnitName, aSite.SectionKind) + [aSite.UnitName] do
        if StartsText(lImport + '.', lName) and (Length(lImport) > Length(lPrefix)) then
          lPrefix := lImport;
      if lPrefix = '' then
        Exit(NameResolution(noAbsent, '', 'qualified', lName));
      Result := ResolveTypeCore(aSite, lPrefix, True, lQualifiedUnit);
      if Result.Outcome <> noResolved then
        Exit;
      lTail := Copy(lName, Length(lPrefix) + 2, MaxInt);
    end;
    if not fUnits.TryGetValue(lQualifiedUnit, lUnit) then
      Exit(NameResolution(noUnproved, 'external-unindexed', 'uses:' + lQualifiedUnit, lName));
    if not CaptureScopeClosed(lUnit, aSite, SameText(lUnit.UnitName, aSite.UnitName)) then
      Exit(NameResolution(noUnproved, 'type-names-unknown', 'uses:' + lQualifiedUnit, lName));
    lDot := Pos('.', lTail);
    if lDot > 0 then
      lHead := Copy(lTail, 1, lDot - 1)
    else
      lHead := lTail;
    Result := TypesInScope(aSite, lHead, 'unit', lQualifiedUnit, lQualifiedUnit,
      SameText(lQualifiedUnit, aSite.UnitName));
    if (lDot > 0) and (Result.Outcome = noResolved) then
      Result := ResolveNestedTypeAt(Result.Identity, Copy(lTail, lDot + 1, MaxInt), aSite);
    Exit;
  end;
  lUnitId := lUnit.Id.Value;
  if not RoutineScopePath(aSite, lPath) then
    Exit(NameResolution(noUnproved, 'caller-scope-invalid', 'routine:' + aSite.RoutineScopeId, lName));
  lSite := aSite;
  for lRoutine in lPath do
  begin
    lScopeId := lRoutine.ScopeId;
    if fUnsupportedLocalScopeName.ContainsKey(LocalTypeKey(lUnitId, lScopeId, lName)) then
    begin
      // Unsupported declarations are shadows only where their own token is visible.
      // P4 and temp insertion apply to these facts just as to supported local types.
      for var lDeclaration in fDeclarations do
        if SameText(lDeclaration.UnitId.Value, lUnitId) and
          SameText(lDeclaration.OwnerScopeId, lScopeId) and
          SameText(lDeclaration.Name, lName) then
        begin
          var lVisible := VisibleAt(lSite, lDeclaration.SourceRange, True);
          if lVisible < 0 then
            Exit(NameResolution(noUnproved, 'position-unknown', 'routine:' + lScopeId, lName));
          if lVisible = 0 then
            Continue;
          Result := NameResolution(noUnproved, 'unsupported-local', 'routine:' + lScopeId, lName);
          Result.ReasonCode := 'UNSUPPORTED_LOCAL_TYPE';
          Exit;
        end;
    end;
    Result := TypesInScope(lSite, lName, 'routine', lScopeId, aSite.UnitName, True);
    if Result.Outcome <> noAbsent then
      Exit;
    // P4: a parent is viewed at the nested routine's declaration token.
    lSite := TDelphiSemanticNameSites.AtRoutineDeclaration(lRoutine, aSite.UnitName);
    lSite.CaptureVisibility := aSite.CaptureVisibility;
    lSite.LocalCutoffLine := aSite.LocalCutoffLine;
  end;
  if aSite.ClassScopeId.Value <> '' then
  begin
    if not FindByDeclaredId(aSite.ClassScopeId, lOwner) then
      Exit(NameResolution(noUnproved, 'class-root-open', 'class:' + aSite.ClassScopeId.Value, lName));
    var lEnclosingVisited := THashSet<string>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
    try
      repeat
        if lEnclosingVisited.Contains(lOwner.DeclaredId.Value) then
          Exit(NameResolution(noUnproved, 'class-root-open', 'class:' + lOwner.Name, lName));
        lEnclosingVisited.Add(lOwner.DeclaredId.Value);
        Result := ResolveNestedTypeAt(lOwner, lName, aSite);
        if Result.Outcome <> noAbsent then
          Exit;
        // dcc64 class-precedence probe: ancestors precede the enclosing class.
        if lOwner.EnclosingTypeId.Value = '' then
          Break;
        var lEnclosing: TDelphiSemanticTypeIdentity;
        if not FindByDeclaredId(lOwner.EnclosingTypeId, lEnclosing) then
          Exit(NameResolution(noUnproved, 'class-root-open', 'class:' + lOwner.Name, lName));
        lOwner := lEnclosing;
      until False;
    finally
      lEnclosingVisited.Free;
    end;
  end;
  Result := TypesInScope(aSite, lName, 'unit', aSite.UnitName, aSite.UnitName, True);
  if Result.Outcome <> noAbsent then
    Exit;
  if aUnitHead and SameText(lName, aSite.UnitName) then
  begin
    aResolvedUnit := aSite.UnitName;
    Exit(NameResolution(noResolved, '', 'unit:' + aSite.UnitName, lName));
  end;
  if not CaptureScopeClosed(lUnit, aSite, SameText(lUnit.UnitName, aSite.UnitName)) then
    Exit(NameResolution(noUnproved, 'type-names-unknown', 'unit:' + aSite.UnitName, lName));
  lDecision := WalkVisibleUnits(aSite, lName, False, aUnitHead);
  if lDecision.Outcome = noUnproved then
    Exit(NameResolution(noUnproved, lDecision.Cause, 'uses:' + lDecision.UnitName, lName));
  if (lDecision.Outcome = noResolved) and lDecision.IsUnit then
  begin
    aResolvedUnit := lDecision.UnitName;
    Exit(NameResolution(noResolved, '', 'uses:' + aResolvedUnit, lName));
  end;
  if lDecision.Outcome = noResolved then
    Exit(TypesInScope(aSite, lName, 'uses', lDecision.UnitName, lDecision.UnitName, False));
  Result := NameResolution(noAbsent, '', 'system', lName);
end;

function TDelphiSemanticTypeIdentityIndexData.ResolveNestedTypeAt(
  const aOwner: TDelphiSemanticTypeIdentity; const aName: string;
  const aSite: TDelphiSemanticNameSite): TDelphiSemanticTypeResolution;
var
  lOwner, lParent: TDelphiSemanticTypeIdentity;
  lVisited: THashSet<string>;
  lOwnerScope: string;
begin
  lVisited := THashSet<string>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
  try
    lOwner := aOwner;
    var lDot := Pos('.', aName);
    if lDot > 0 then
    begin
      Result := ResolveNestedTypeAt(aOwner, Copy(aName, 1, lDot - 1), aSite);
      if Result.Outcome = noResolved then
        Result := ResolveNestedTypeAt(Result.Identity, Copy(aName, lDot + 1, MaxInt), aSite);
      Exit;
    end;
    repeat
      if lVisited.Contains(lOwner.DeclaredId.Value) then
        Exit(NameResolution(noUnproved, 'class-root-open', 'class:' + lOwner.Name, aName));
      lVisited.Add(lOwner.DeclaredId.Value);
      lOwnerScope := lOwner.OwnerScopeId + '|type|' + LowerCase(lOwner.Name);
      Result := TypesInScope(aSite, aName, 'class', lOwnerScope, lOwner.UnitName,
        SameText(lOwner.UnitName, aSite.UnitName));
      if Result.Outcome <> noAbsent then
        Exit;
      if lOwner.BaseTypeName = '' then
        Exit(NameResolution(noAbsent, '', 'class:' + lOwner.Name, aName));
      if SameText(lOwner.BaseTypeName, 'TObject') or SameText(lOwner.BaseTypeName, 'System.TObject') then
        Exit(NameResolution(noAbsent, '', 'class:' + lOwner.Name, aName));
      Result := ResolveTypeAt(TDelphiSemanticNameSites.AtTypeIdentity(lOwner), lOwner.BaseTypeName);
      if Result.Outcome <> noResolved then
      begin
        var lRoot := Default(TDelphiSemanticQualifiedRootType);
        lRoot.Kind := 'class';
        lRoot.TypeName := lOwner.BaseTypeName;
        lRoot.LookupUnits := VisibleUnitNames(lOwner.UnitName, lOwner.SectionKind);
        if (fNamedRootAbsence <> nil) and
          fNamedRootAbsence.IsNamedRootMemberAbsent(lRoot,
            VisibleUnitNames(aSite.UnitName, aSite.SectionKind), aName) then
          Exit(NameResolution(noAbsent, '', 'class:' + lOwner.Name, aName));
        Exit(NameResolution(noUnproved, 'class-root-open', 'class:' + lOwner.Name, aName));
      end;
      lParent := Result.Identity;
      lOwner := lParent;
    until False;
  finally
    lVisited.Free;
  end;
end;

function ConstructedAlias(const aIdentity: TDelphiSemanticTypeIdentity): Boolean;
var
  lName: string;
begin
  lName := aIdentity.CanonicalName.Trim;
  Result := SameText(aIdentity.Kind, 'type-alias') and
    (SameText(lName, 'string') or StartsText('string[', lName) or
    StartsText('array ', lName) or StartsText('array[', lName) or
    StartsText('packed array', lName) or StartsText('set of ', lName) or
    SameText(lName, 'file') or StartsText('file of ', lName));
end;

function TDelphiSemanticTypeIdentityIndexData.HelperReceiverTerminal(
  const aIdentity: TDelphiSemanticTypeIdentity;
  out aTerminal: TDelphiSemanticTypeIdentity; out aIndirect: Boolean): Boolean;
var
  lCurrent, lNext: TDelphiSemanticTypeIdentity;
  lLookup: TDelphiSemanticTypeResolution;
  lName: string;
  lVisited: THashSet<string>;
begin
  aTerminal := Default(TDelphiSemanticTypeIdentity);
  aIndirect := False;
  lCurrent := aIdentity;
  lVisited := THashSet<string>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
  try
    repeat
      if (lCurrent.DeclaredId.Value = '') or not lVisited.Add(lCurrent.DeclaredId.Value) then
        Exit(False);
      lName := lCurrent.CanonicalName.Trim;
      if not SameText(lCurrent.Kind, 'type-alias') or ConstructedAlias(lCurrent) or
        ((Length(lName) > 4) and SameText(Copy(lName, 1, 4), 'type') and
        CharInSet(lName[5], [#9, #10, #13, ' '])) then
      begin
        aTerminal := lCurrent;
        Exit(True);
      end;
      if StartsText('^', lName) then
      begin
        // Implicit dereference is a receiver operation. A helper's own pointer
        // target remains unproved in CompareWeakAliasTargets.
        lLookup := ResolveTypeAt(TDelphiSemanticNameSites.AtTypeIdentity(lCurrent),
          Copy(lName, 2, MaxInt).Trim);
        if lLookup.Outcome <> noResolved then
          Exit(False);
        lNext := lLookup.Identity;
        aIndirect := True;
      end else if not TryResolveAliasTarget(lCurrent, lNext) then
        Exit(False);
      lCurrent := lNext;
    until False;
  finally
    lVisited.Free;
  end;
end;

function TDelphiSemanticTypeIdentityIndexData.HelperApplicabilityLineage(
  const aLineage: TDelphiSemanticLineage): TDelphiSemanticLineage;
var
  lTerminal: TDelphiSemanticTypeIdentity;
  lIndirect: Boolean;
begin
  Result := aLineage;
  if (Length(aLineage.Items) = 0) or
    not HelperReceiverTerminal(aLineage.Items[0], lTerminal, lIndirect) then
    Exit;
  if lIndirect then
    Result := ResolveLineage(lTerminal);
  if ConstructedAlias(lTerminal) then
  begin
    Result := Default(TDelphiSemanticLineage);
    Result.Items := [lTerminal];
    Result.StrongAliasAt := -1;
    Result.Complete := True;
  end;
end;

function TDelphiSemanticTypeIdentityIndexData.WeakAliasTerminal(
  const aIdentity: TDelphiSemanticTypeIdentity;
  out aTerminal: TDelphiSemanticTypeIdentity): Boolean;
var
  lCurrent, lNext: TDelphiSemanticTypeIdentity;
  lName: string;
  lVisited: THashSet<string>;
begin
  aTerminal := Default(TDelphiSemanticTypeIdentity);
  lCurrent := aIdentity;
  lVisited := THashSet<string>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
  try
    repeat
      if (lCurrent.DeclaredId.Value = '') or
        not lVisited.Add(lCurrent.DeclaredId.Value) then
        Exit(False);
      lName := lCurrent.CanonicalName.Trim;
      // A strong alias is its own terminal, never the type behind it.
      if not SameText(lCurrent.Kind, 'type-alias') or
        ((Length(lName) > 4) and SameText(Copy(lName, 1, 4), 'type') and
        CharInSet(lName[5], [#9, #10, #13, ' '])) then
      begin
        aTerminal := lCurrent;
        Exit(True);
      end;
      if ConstructedAlias(lCurrent) then
      begin
        aTerminal := lCurrent;
        Exit(True);
      end;
      if not TryResolveAliasTarget(lCurrent, lNext) then
        Exit(False);
      lCurrent := lNext;
    until False;
  finally
    lVisited.Free;
  end;
end;

function TDelphiSemanticTypeIdentityIndexData.CompareWeakAliasTargets(
  const aLeft, aRight: TDelphiSemanticTypeIdentity): TDelphiSemanticNameOutcome;
var
  lLeft, lRight: TDelphiSemanticTypeIdentity;
begin
  if not WeakAliasTerminal(aLeft, lLeft) or not WeakAliasTerminal(aRight, lRight) then
    Exit(TDelphiSemanticNameOutcome.noUnproved);
  if SameText(lLeft.DeclaredId.Value, lRight.DeclaredId.Value) then
    Exit(TDelphiSemanticNameOutcome.noResolved);
  // Separate constructed declarations are not evidence of distinct types.
  if ConstructedAlias(lLeft) and ConstructedAlias(lRight) then
    Exit(TDelphiSemanticNameOutcome.noUnproved);
  if (ConstructedAlias(lLeft) and not MatchText(lRight.CanonicalName,
    ['class', 'record', 'packed record', 'object', 'interface'])) or
    (ConstructedAlias(lRight) and not MatchText(lLeft.CanonicalName,
    ['class', 'record', 'packed record', 'object', 'interface'])) then
    Exit(TDelphiSemanticNameOutcome.noUnproved);
  Result := TDelphiSemanticNameOutcome.noAbsent;
end;

function TDelphiSemanticTypeIdentityIndexData.ResolveHelperInUnit(
  const aTarget: TDelphiSemanticTypeIdentity; const aSite: TDelphiSemanticNameSite;
  const aUnitName: string; const aOwn, aExactSite: Boolean): TDelphiSemanticTypeResolution;
var
  lCandidates: TArray<TDelphiSemanticTypeIdentity>;
  lTarget: TDelphiSemanticTypeIdentity;
  lIndirect: Boolean;
  lMatch: TDelphiSemanticNameOutcome;
begin
  if not HelperReceiverTerminal(aTarget, lTarget, lIndirect) then
    Exit(NameResolution(noUnproved, 'helper-unknown', 'helper:' + aUnitName, aTarget.Name));
  Result := NameResolution(noAbsent, '', 'helper:' + aUnitName, lTarget.Name);
  var lHelperUnit: TDelphiSemanticGraphUnit;
  if aOwn and aExactSite then
  begin
    if not FindHelperSiteUnit(aSite, lHelperUnit) then
      Exit(NameResolution(noUnproved, 'helper-unknown', 'helper:' + aUnitName, lTarget.Name));
  end else if not fUnits.TryGetValue(aUnitName, lHelperUnit) then
    Exit;
  begin
    if not lHelperUnit.HelperFactsKnown then
      Exit(NameResolution(noUnproved, 'helper-unknown', 'helper:' + aUnitName, lTarget.Name));
    for var lHelperFact in lHelperUnit.UnindexedHelpers do
    begin
      if ((not aOwn) and (not SameText(lHelperFact.SectionKind, 'interface') or
        not SameText(lHelperFact.ScopeKind, 'unit'))) or
        (SameText(lHelperFact.HelperKind, 'class') and
        MatchText(lTarget.UnderlyingName, ['record', 'packed record'])) then
        Continue;
      var lHelperSite := TDelphiSemanticNameSites.AtUnindexedHelper(lHelperUnit, lHelperFact);
      if aOwn then
      begin
        var lRange := Default(TDelphiSemanticSourceRange);
        lRange.FileName := lHelperSite.FileName;
        lRange.Line := lHelperSite.Line;
        lRange.Column := lHelperSite.Column;
        var lVisible := VisibleAt(aSite, lRange, False);
        if lVisible = 0 then
          Continue;
      end;
      if (lHelperFact.TargetName = '') or (lHelperFact.HelperKind = '') then
        Exit(NameResolution(noUnproved, 'helper-unknown', 'helper:' + aUnitName, lTarget.Name));
      var lResolved := ResolveTypeAt(lHelperSite, lHelperFact.TargetName);
      case lResolved.Outcome of
        noResolved:
        begin
          lMatch := CompareWeakAliasTargets(lResolved.Identity, lTarget);
          if lMatch = TDelphiSemanticNameOutcome.noUnproved then
            Exit(NameResolution(noUnproved, 'helper-unknown', 'helper:' + aUnitName, lTarget.Name));
          if lMatch = TDelphiSemanticNameOutcome.noResolved then
            Exit(NameResolution(noUnproved, 'helper-unknown', 'helper:' + aUnitName, lTarget.Name));
        end;
        noUnproved, noAmbiguous:
          Exit(NameResolution(noUnproved, 'helper-unknown', 'helper:' + aUnitName, lTarget.Name));
        noAbsent:
          // A missing identity cannot establish an unsupported helper's target.
          if SameText(lHelperFact.TargetName, lTarget.Name) then
            Exit(NameResolution(noUnproved, 'helper-unknown', 'helper:' + aUnitName, lTarget.Name));
      end;
    end;
  end;
  lCandidates := nil;
  for var lHelper in fByDeclaredId.Values do
  begin
    if (lHelper.HelperTargetName = '') or not SameText(lHelper.UnitName, aUnitName) or
      ((not aOwn) and not SameText(lHelper.SectionKind, 'interface')) or
      (aOwn and not SameUnitOrInterfaceVisible(lHelper, aSite.UnitName, aSite.SectionKind)) or
      (aOwn and aExactSite and not SameText(lHelper.SourceRange.FileName, aSite.FileName)) then
      Continue;
    if aOwn then
    begin
      var lVisible := VisibleAt(aSite, lHelper.SourceRange, False);
      if lVisible < 0 then
        Exit(NameResolution(noUnproved, 'helper-unknown', 'helper:' + aUnitName, lTarget.Name));
      if lVisible = 0 then
        Continue;
    end;
    var lResolved := ResolveTypeAt(TDelphiSemanticNameSites.AtTypeIdentity(lHelper),
      lHelper.HelperTargetName);
    case lResolved.Outcome of
      noResolved:
      begin
        lMatch := CompareWeakAliasTargets(lResolved.Identity, lTarget);
        if lMatch = TDelphiSemanticNameOutcome.noUnproved then
          Exit(NameResolution(noUnproved, 'helper-unknown', 'helper:' + aUnitName, lTarget.Name));
        if lMatch = TDelphiSemanticNameOutcome.noResolved then
          lCandidates := lCandidates + [lHelper];
      end;
      noUnproved, noAmbiguous:
        Exit(NameResolution(noUnproved, 'helper-unknown', 'helper:' + aUnitName, lTarget.Name));
      noAbsent: ;
    end;
  end;
  if Length(lCandidates) = 1 then
  begin
    Result.Outcome := noResolved;
    Result.Identity := lCandidates[0];
    Result.ReasonCode := '';
  end else if Length(lCandidates) > 1 then
  begin
    Result := NameResolution(noAmbiguous, '', 'helper:' + aUnitName, lTarget.Name);
    Result.Candidates := lCandidates;
  end;
end;

function TDelphiSemanticTypeIdentityIndexData.ResolveActiveHelperAt(
  const aTargetId: TDelphiSemanticGraphTypeId;
  const aSite: TDelphiSemanticNameSite): TDelphiSemanticTypeResolution;
var
  lTarget: TDelphiSemanticTypeIdentity;
  lUnit: TDelphiSemanticGraphUnit;
  lPairing: IDelphiSemanticSdkUnitPairing;


begin
  if not FindByDeclaredId(aTargetId, lTarget) or not fUnits.TryGetValue(aSite.UnitName, lUnit) then
    Exit(NameResolution(noUnproved, 'helper-unknown', 'helper', aTargetId.Value));
  Result := ResolveHelperInUnit(lTarget, aSite, aSite.UnitName, True);
  if Result.Outcome <> noAbsent then
    Exit;
  if not lUnit.TypeNamesKnown then
    Exit(NameResolution(noUnproved, 'helper-unknown', 'helper:' + aSite.UnitName, lTarget.Name));
  var lImports := VisibleUnitNames(aSite.UnitName, aSite.SectionKind);
  for var i := High(lImports) downto 0 do
  begin
    var lUnitName := lImports[i];
    if SameText(lUnitName, aSite.UnitName) then
      Continue;
    if (lUnitName = '<imports-unproved>') or IsAliasConflict(aSite.UnitName, lUnitName) then
      Exit(NameResolution(noUnproved, 'helper-unknown', 'helper:' + lUnitName, lTarget.Name));
    if fUnits.TryGetValue(lUnitName, lUnit) then
    begin
      if not lUnit.TypeNamesKnown then
        Exit(NameResolution(noUnproved, 'helper-unknown', 'helper:' + lUnitName, lTarget.Name));
      Result := ResolveHelperInUnit(lTarget, aSite, lUnitName, False);
      if Result.Outcome <> noAbsent then
        Exit;
    end else begin
      // SDK source cannot refer to a type declared in our project. Other units
      // need both absence proofs; a project-source file alone is never A4 proof.
      if Supports(fUnitNameWitness, IDelphiSemanticSdkUnitPairing, lPairing) and
        lPairing.IsSdkPaired(lUnitName) and fUnits.ContainsKey(lTarget.UnitName) then
        Continue;
      if (fUnitNameWitness <> nil) and
        not fUnitNameWitness.MayDeclare(lUnitName, lTarget.Name) and
        not fUnitNameWitness.MayDeclare(lUnitName, 'helper') then
        Continue;
      Exit(NameResolution(noUnproved, 'helper-unknown', 'helper:' + lUnitName, lTarget.Name));
    end;
  end;
  Result := NameResolution(noAbsent, '', 'helper', lTarget.Name);
end;

function TDelphiSemanticTypeIdentityIndexData.ProjectOwnedTo(
  const aLineage: TDelphiSemanticLineage; const aLevel: Integer): Boolean;
var
  lIdentity, lTerminal: TDelphiSemanticTypeIdentity;
  lPairing: IDelphiSemanticSdkUnitPairing;
  lLevel: Integer;
begin
  lLevel := -1;
  Supports(fUnitNameWitness, IDelphiSemanticSdkUnitPairing, lPairing);
  for lIdentity in aLineage.Items do
  begin
    if not WeakAliasTerminal(lIdentity, lTerminal) then
      Exit(False);
    if not SameText(lTerminal.DeclaredId.Value, lIdentity.DeclaredId.Value) then
      Continue;
    Inc(lLevel);
    if not fUnits.ContainsKey(lIdentity.UnitName) or
      ((lPairing <> nil) and lPairing.IsSdkPaired(lIdentity.UnitName)) then
      Exit(False);
    if lLevel = aLevel then
      Exit(True);
  end;
  Result := False;
end;

function TDelphiSemanticTypeIdentityIndexData.ProjectOwned(
  const aLineage: TDelphiSemanticLineage): Boolean;
begin
  Result := aLineage.Complete and (Length(aLineage.Items) > 0) and
    ((aLineage.ImplicitRoot = '') or aLineage.RootIndexed) and
    ProjectOwnedTo(aLineage, Length(aLineage.Items) - 1);
  // Weak aliases are not levels, so the final level may precede the array end.
  if aLineage.Complete and (Length(aLineage.Items) > 0) and
    ((aLineage.ImplicitRoot = '') or aLineage.RootIndexed) then
  begin
    var lLast := 0;
    for var lIdentity in aLineage.Items do
    begin
      var lTerminal := Default(TDelphiSemanticTypeIdentity);
      if not WeakAliasTerminal(lIdentity, lTerminal) then
        Exit(False);
      if SameText(lTerminal.DeclaredId.Value, lIdentity.DeclaredId.Value) then
        Inc(lLast);
    end;
    Result := ProjectOwnedTo(aLineage, lLast - 1);
  end;
end;

function TDelphiSemanticTypeIdentityIndexData.FindHelperSiteUnit(
  const aSite: TDelphiSemanticNameSite; out aUnit: TDelphiSemanticGraphUnit): Boolean;
var
  lUnit: TDelphiSemanticGraphUnit;
begin
  Result := False;
  aUnit := Default(TDelphiSemanticGraphUnit);
  // Unit names alone collapse independent source models with different imports.
  // Missing or duplicate exact sites cannot certify helper absence.
  for lUnit in fSiteUnits do
    if SameText(lUnit.UnitName, aSite.UnitName) and
      SameText(lUnit.FileName, aSite.FileName) then
    begin
      if Result then
        Exit(False);
      aUnit := lUnit;
      Result := True;
    end;
end;

function TDelphiSemanticTypeIdentityIndexData.ResolveHelpersAt(
  const aLineage: TDelphiSemanticLineage; const aSite: TDelphiSemanticNameSite):
  TDelphiSemanticHelperResolution;
var
  lLineage: TDelphiSemanticLineage;
  lIdentity, lTerminal, lParent: TDelphiSemanticTypeIdentity;
  lLevel: TDelphiSemanticHelperLevel;
  lLookup: TDelphiSemanticTypeResolution;
  lUnit: TDelphiSemanticGraphUnit;
  lPairing: IDelphiSemanticSdkUnitPairing;
  lImports: TArray<string>;
  lVisited: THashSet<string>;
  lUnitName: string;
  i, j: Integer;

  procedure OpenLevel(const aIndex: Integer);
  begin
    if aIndex < Result.OpenFromLevel then
      Result.OpenFromLevel := aIndex;
  end;

begin
  lLineage := HelperApplicabilityLineage(aLineage);
  Result := Default(TDelphiSemanticHelperResolution);
  Result.OpenFromLevel := MaxInt;
  for lIdentity in lLineage.Items do
  begin
    if not WeakAliasTerminal(lIdentity, lTerminal) then
    begin
      OpenLevel(0);
      Exit;
    end;
    if not SameText(lIdentity.DeclaredId.Value, lTerminal.DeclaredId.Value) then
      Continue;
    lLevel := Default(TDelphiSemanticHelperLevel);
    lLevel.Identity := lIdentity;
    lLevel.Outcome := noAbsent;
    lLevel.ProjectOwned := ProjectOwnedTo(lLineage, Length(Result.Levels));
    Result.Levels := Result.Levels + [lLevel];
  end;
  // The unindexed root is a level too, but it has no declaration identity.
  if (lLineage.ImplicitRoot <> '') and not lLineage.RootIndexed then
  begin
    lLevel := Default(TDelphiSemanticHelperLevel);
    lLevel.Identity.Name := lLineage.ImplicitRoot;
    lLevel.Outcome := noUnproved;
    lLevel.Cause := 'helper-unknown';
    Result.Levels := Result.Levels + [lLevel];
    OpenLevel(High(Result.Levels));
  end;
  if not lLineage.Complete then
    OpenLevel(Length(Result.Levels));
  if not FindHelperSiteUnit(aSite, lUnit) or
    not lUnit.HelperScopeKnown then
  begin
    OpenLevel(0);
    Exit;
  end;
  Supports(fUnitNameWitness, IDelphiSemanticSdkUnitPairing, lPairing);
  lImports := [aSite.UnitName];
  var lVisible := Copy(lUnit.InterfaceImports);
  if SameText(aSite.SectionKind, 'implementation') then
    lVisible := lVisible + lUnit.ImplementationImports;
  if not lUnit.ImportsKnown then
    lVisible := lVisible + ['<imports-unproved>'];
  var lAliasConflicts := lUnit.AliasConflictNames;
  for i := High(lVisible) downto 0 do
    if not SameText(lVisible[i], aSite.UnitName) then
      lImports := lImports + [lVisible[i]];
  for i := 0 to High(Result.Levels) do
  begin
    if Result.Levels[i].Identity.DeclaredId.Value = '' then
      Continue;
    for lUnitName in lImports do
    begin
      if (lUnitName = '<imports-unproved>') or MatchText(lUnitName, lAliasConflicts) then
      begin
        OpenLevel(i);
        Continue;
      end;
      var lHasUnit := False;
      if SameText(lUnitName, aSite.UnitName) then
        lHasUnit := FindHelperSiteUnit(aSite, lUnit)
      else
        lHasUnit := fUnits.TryGetValue(lUnitName, lUnit);
      if not lHasUnit then
      begin
        // e1/e2 require positive SDK pairing. A project-text witness cannot
        // certify helper absence, even when the member name is absent.
        if (lPairing <> nil) and lPairing.IsSdkPaired(lUnitName) and
          ((not fUnitNameWitness.MayDeclare(lUnitName, 'helper')) or
          Result.Levels[i].ProjectOwned) then
          Continue;
        OpenLevel(i);
        Continue;
      end;
      lLookup := ResolveHelperInUnit(Result.Levels[i].Identity, aSite, lUnitName,
        SameText(lUnitName, aSite.UnitName), True);
      if not lUnit.HelperScopeKnown then
        OpenLevel(i);
      if lLookup.Outcome in [noUnproved, noAmbiguous] then
      begin
        Result.Levels[i].Outcome := lLookup.Outcome;
        Result.Levels[i].Cause := 'helper-unknown';
        OpenLevel(i);
        Break;
      end;
      if lLookup.Outcome <> noResolved then
        Continue;
      Result.Levels[i].Outcome := noResolved;
      lParent := lLookup.Identity;
      lVisited := THashSet<string>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
      try
        repeat
          if not lVisited.Add(lParent.DeclaredId.Value) then
          begin
            Result.Levels[i].Outcome := noUnproved;
            Result.Levels[i].Cause := 'helper-unknown';
            OpenLevel(i);
            Break;
          end;
          Result.Levels[i].Chain := Result.Levels[i].Chain + [lParent];
          if lParent.HelperParentName = '' then
            Break;
          lLookup := ResolveTypeAt(TDelphiSemanticNameSites.AtTypeIdentity(lParent),
            lParent.HelperParentName);
          if (lLookup.Outcome <> noResolved) or (lLookup.Identity.HelperTargetName = '') then
          begin
            Result.Levels[i].Outcome := noUnproved;
            Result.Levels[i].Cause := 'helper-unknown';
            OpenLevel(i);
            Break;
          end;
          lParent := lLookup.Identity;
          // Parent lookup uses its declaration scope, never the WITH imports.
          lLookup := ResolveTypeAt(TDelphiSemanticNameSites.AtTypeIdentity(lParent),
            lParent.HelperTargetName);
          var lTargetFound := False;
          if lLookup.Outcome = noResolved then
            for j := i to High(Result.Levels) do
              if CompareWeakAliasTargets(lLookup.Identity, Result.Levels[j].Identity) = noResolved then
                lTargetFound := True;
          if not lTargetFound then
          begin
            Result.Levels[i].Outcome := noUnproved;
            Result.Levels[i].Cause := 'helper-unknown';
            OpenLevel(i);
            Break;
          end;
        until False;
      finally
        lVisited.Free;
      end;
      Break;
    end;
  end;
end;

function TDelphiSemanticTypeIdentityIndexData.UnitValues(const aUnitName, aName: string;
  const aInterfaceOnly: Boolean): TArray<TDelphiSemanticGraphDeclaration>;
var
  lList: TDelphiSemanticGraphDeclarationList;
  lDeclaration: TDelphiSemanticGraphDeclaration;
  lUnitId: string;
begin
  Result := nil;
  if not fUnitIdsByName.TryGetValue(aUnitName, lUnitId) or
    not fUnitValuesByName.TryGetValue(aName, lList) then
    Exit;
  for lDeclaration in lList do
    if (lDeclaration.UnitId.Value = lUnitId) and
      ((not aInterfaceOnly) or SameText(lDeclaration.SectionKind, 'interface')) then
      Result := Result + [lDeclaration];
end;

function TDelphiSemanticTypeIdentityIndexData.ResolveValueRootAt(const aSite: TDelphiSemanticNameSite;
  const aName: string): TDelphiSemanticValueResolution;
var
  lUnit: TDelphiSemanticGraphUnit;
  lRoutine: TDelphiSemanticGraphRoutine;
  lCandidates: TArray<TDelphiSemanticGraphDeclaration>;
  lDeclaration: TDelphiSemanticGraphDeclaration;
  lScopeId: string;
  lPath: TArray<TDelphiSemanticGraphRoutine>;
  lSite: TDelphiSemanticNameSite;
  lVisited: THashSet<string>;
  lDecision: TDelphiSemanticUnitDecision;
  lVisible: Integer;
  lDuplicate: Boolean;
  lExisting: TDelphiSemanticGraphDeclaration;

  function Decision(const aOutcome: TDelphiSemanticNameOutcome;
    const aCause, aScope: string): TDelphiSemanticValueResolution;
  begin
    Result := Default(TDelphiSemanticValueResolution);
    Result.Outcome := aOutcome;
    Result.Cause := aCause;
    Result.DecidingScope := aScope;
    Result.Reason := aCause + ': ' + aName + ' in ' + aScope;
    if aOutcome = noUnproved then
      Result.ReasonCode := 'TYPE_VISIBILITY_UNPROVED'
    else if aOutcome = noAmbiguous then
      Result.ReasonCode := 'TYPE_AMBIGUOUS'
    else if aOutcome = noAbsent then
      Result.ReasonCode := 'TYPE_NOT_VISIBLE';
  end;

  function CandidatesDecision(const aScope: string): TDelphiSemanticValueResolution;
  begin
    Result := Decision(noAbsent, '', aScope);
    if Length(lCandidates) = 1 then
    begin
      Result := Decision(noResolved, '', aScope);
      Result.Identity := lCandidates[0];
      fUnitNamesById.TryGetValue(Result.Identity.UnitId.Value, Result.UnitName);
    end else if Length(lCandidates) > 1 then
    begin
      Result := Decision(noAmbiguous, '', aScope);
      Result.Candidates := lCandidates;
    end;
  end;
begin
  Result := Decision(noAbsent, '', 'system');
  if not fUnits.TryGetValue(aSite.UnitName, lUnit) then
    Exit(Decision(noUnproved, 'caller-scope-invalid', 'unit:' + aSite.UnitName));
  if not RoutineScopePath(aSite, lPath) then
    Exit(Decision(noUnproved, 'caller-scope-invalid', 'routine:' + aSite.RoutineScopeId));
  lVisited := THashSet<string>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
  try
    lSite := aSite;
    for lRoutine in lPath do
    begin
      lScopeId := lRoutine.ScopeId;
      lCandidates := nil;
      for var lLocal in fLocals do
        if SameText(lLocal.UnitId.Value, lUnit.Id.Value) and
          SameText(lLocal.RoutineScopeId, lScopeId) and SameText(lLocal.Name, aName) then
        begin
          lVisible := VisibleAt(lSite, lLocal.SourceRange, True);
          if lVisible < 0 then
            Exit(Decision(noUnproved, 'position-unknown', 'routine:' + lScopeId));
          if lVisible = 0 then
            Continue;
          lDeclaration := Default(TDelphiSemanticGraphDeclaration);
          lDeclaration.SymbolId := lLocal.SymbolId;
          lDeclaration.UnitId := lLocal.UnitId;
          lDeclaration.Name := lLocal.Name;
          lDeclaration.Kind := lLocal.Kind;
          lDeclaration.TypeName := lLocal.TypeName;
          lDeclaration.ScopeKind := 'routine';
          lDeclaration.OwnerScopeId := lLocal.RoutineScopeId;
          lDeclaration.SectionKind := lRoutine.SectionKind;
          lDeclaration.SourceRange := lLocal.SourceRange;
          lCandidates := lCandidates + [lDeclaration];
        end;
      for var lParameter in fParameters do
        if SameText(lParameter.UnitId.Value, lUnit.Id.Value) and
          SameText(lParameter.RoutineScopeId, lScopeId) and SameText(lParameter.Name, aName) then
        begin
          lDeclaration := Default(TDelphiSemanticGraphDeclaration);
          lDeclaration.SymbolId := lParameter.SymbolId;
          lDeclaration.UnitId := lParameter.UnitId;
          lDeclaration.Name := lParameter.Name;
          lDeclaration.Kind := 'parameter';
          lDeclaration.TypeName := lParameter.TypeName;
          lDeclaration.ScopeKind := 'routine';
          lDeclaration.OwnerScopeId := lParameter.RoutineScopeId;
          lDeclaration.SectionKind := lRoutine.SectionKind;
          lDeclaration.SourceRange := lParameter.SourceRange;
          // Declaration and implementation headings denote one parameter.
          // Different type spellings retain separate, ambiguous evidence.
          lDuplicate := False;
          for lExisting in lCandidates do
          begin
            if SameText(lExisting.Kind, 'parameter') and
              SameText(lExisting.Name, lDeclaration.Name) and
              SameText(lExisting.OwnerScopeId, lDeclaration.OwnerScopeId) and
              SameText(lExisting.TypeName, lDeclaration.TypeName) then
              lDuplicate := True;
          end;
          if not lDuplicate then
            lCandidates := lCandidates + [lDeclaration];
        end;
      Result := CandidatesDecision('routine:' + lScopeId);
      if Result.Outcome <> noAbsent then
        Exit;
      lSite := TDelphiSemanticNameSites.AtRoutineDeclaration(lRoutine, aSite.UnitName);
      lSite.LocalCutoffLine := aSite.LocalCutoffLine;
    end;
    if aSite.ClassScopeId.Value <> '' then
    begin
      var lOwner: TDelphiSemanticTypeIdentity;
      if not FindByDeclaredId(aSite.ClassScopeId, lOwner) then
        Exit(Decision(noUnproved, 'class-root-open', 'class:' + aSite.ClassScopeId.Value));
      lVisited.Clear;
      repeat
        if lVisited.Contains(lOwner.DeclaredId.Value) then
          Exit(Decision(noUnproved, 'class-root-open', 'class:' + lOwner.Name));
        lVisited.Add(lOwner.DeclaredId.Value);
        lCandidates := nil;
        for var lMember in fMembers do
          if SameText(lMember.UnitId.Value, lOwner.UnitId.Value) and
            SameText(lMember.OwnerName, lOwner.Name) and SameText(lMember.Name, aName) then
          begin
            lDeclaration := Default(TDelphiSemanticGraphDeclaration);
            lDeclaration.SymbolId := lMember.SymbolId;
            lDeclaration.UnitId := lMember.UnitId;
            lDeclaration.Name := lMember.Name;
            lDeclaration.Kind := lMember.Kind;
            lDeclaration.TypeName := lMember.TypeName;
            lDeclaration.ScopeKind := 'type';
            lDeclaration.OwnerScopeId := lMember.OwnerScopeId;
            lDeclaration.SectionKind := lOwner.SectionKind;
            lDeclaration.SourceRange := lMember.SourceRange;
            lDeclaration.OwnerDeclaredId := lOwner.DeclaredId;
            lCandidates := lCandidates + [lDeclaration];
          end;
        Result := CandidatesDecision('class:' + lOwner.Name);
        if Result.Outcome <> noAbsent then
          Exit;
        if (lOwner.BaseTypeName = '') or SameText(lOwner.BaseTypeName, 'TObject') or
          SameText(lOwner.BaseTypeName, 'System.TObject') then
          Break;
        var lBase := ResolveTypeAt(TDelphiSemanticNameSites.AtTypeIdentity(lOwner), lOwner.BaseTypeName);
        if lBase.Outcome <> noResolved then
          Exit(Decision(noUnproved, 'class-root-open', 'class:' + lOwner.Name));
        lOwner := lBase.Identity;
      until False;
    end;
    lCandidates := nil;
    for lDeclaration in UnitValues(aSite.UnitName, aName, SameText(aSite.SectionKind, 'interface')) do
    begin
      lVisible := VisibleAt(aSite, lDeclaration.SourceRange, False);
      if lVisible < 0 then
        Exit(Decision(noUnproved, 'position-unknown', 'unit:' + aSite.UnitName));
      if lVisible > 0 then
        lCandidates := lCandidates + [lDeclaration];
    end;
    Result := CandidatesDecision('unit:' + aSite.UnitName);
    if Result.Outcome <> noAbsent then
      Exit;
    if not lUnit.TypeNamesKnown then
      Exit(Decision(noUnproved, 'type-names-unknown', 'unit:' + aSite.UnitName));
    lDecision := WalkVisibleUnits(aSite, aName, True);
    if lDecision.Outcome = noUnproved then
      Exit(Decision(noUnproved, lDecision.Cause, 'uses:' + lDecision.UnitName));
    if lDecision.Outcome = noResolved then
    begin
      lCandidates := UnitValues(lDecision.UnitName, aName, True);
      Exit(CandidatesDecision('uses:' + lDecision.UnitName));
    end;
    Result := Decision(noAbsent, '', 'system');
  finally
    lVisited.Free;
  end;
end;

function StableTypeId(const aUnitId: TDelphiSemanticUnitGraphId; const aRole,
  aName: string): TDelphiSemanticGraphTypeId;
begin
  Result.Value := THashSHA2.GetHashString('type|' + aUnitId.Value + '|' +
    LowerCase(aRole) + '|' + LowerCase(aName));
end;

function HasMatchingAstScopeIdentity(const aRoutine: TDelphiSemanticGraphRoutine;
  const aUnitName: string): Boolean;
var
  lExpectedPrefix: string;
  lQualifiedName: string;
begin
  Result := False;
  if (aUnitName = '') or (aRoutine.Name = '') or
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
  lExpectedPrefix := LowerCase(aUnitName) + '|';
  if aRoutine.ParentScopeId <> '' then
    lExpectedPrefix := LowerCase(aRoutine.ParentScopeId) + '/';
  lExpectedPrefix := lExpectedPrefix + LowerCase(lQualifiedName);
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
    // A nested forward and its body belong to the same physical parent scope.
    // Top-level interface/body pairing keeps its original section requirement.
    (((lHeader.ParentScopeId = '') and SameText(lHeader.SectionKind, 'interface')) or
    ((lHeader.ParentScopeId <> '') and SameText(lHeader.SectionKind, 'implementation') and
    SameText(lHeader.SourceRange.FileName, aBody.SourceRange.FileName))) and
    SameText(aBody.SectionKind, 'implementation') and
    SameText(lHeader.ReturnType, aBody.ReturnType) and
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
  const aGraph: TDelphiSemanticSemanticGraph;
  const aNamedRootAbsence: IDelphiSemanticNamedRootMemberAbsence);
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
  fUnitNameWitness := aGraph.UnitNameWitness;
  fNamedRootAbsence := aNamedRootAbsence;
  fByCanonicalId := TDictionary<string, TDelphiSemanticTypeIdentityList>.Create(
    TFastCaseAwareComparer.OrdinalIgnoreCase);
  fVisibilityRanges := TDictionary<string, TDelphiSemanticSourceRange>.Create(
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
  fDeclarations := aGraph.Declarations;
  fLocals := aGraph.Locals;
  fParameters := aGraph.Parameters;
  fMembers := aGraph.Members;
  fUnitValuesByName := TDictionary<string, TDelphiSemanticGraphDeclarationList>.Create(
    TFastCaseAwareComparer.OrdinalIgnoreCase);
  fUnits := TDictionary<string, TDelphiSemanticGraphUnit>.Create(
    TFastCaseAwareComparer.OrdinalIgnoreCase);
  fUnitIdsByName := TDictionary<string, string>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
  fUnitScopeStatus := TDictionary<string, string>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
  fUnitNamesById := TDictionary<string, string>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);

  fSiteUnits := Copy(aGraph.Units);
  for lUnit in aGraph.Units do
  begin
    fUnits.AddOrSetValue(lUnit.UnitName, lUnit);
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
  for var lValue in aGraph.Declarations do
    if MatchText(lValue.Kind, ['var', 'const', 'typed-const', 'routine', 'threadvar']) and
      not MatchText(lValue.ScopeKind, ['routine', 'type', 'unknown']) then
    begin
      var lValues: TDelphiSemanticGraphDeclarationList;
      if not fUnitValuesByName.TryGetValue(lValue.Name, lValues) then
      begin
        lValues := TDelphiSemanticGraphDeclarationList.Create;
        fUnitValuesByName.Add(lValue.Name, lValues);
      end;
      lValues.Add(lValue);
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
    lIdentity.Synthetic := lType.Synthetic;
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
    lIdentity.HelperParentName := lType.HelperParentName;
    lIdentity.SectionKind := lType.SectionKind;
    lIdentity.ScopeKind := lType.ScopeKind;
    lIdentity.OwnerScopeId := lType.OwnerScopeId;
    lIdentity.SemanticSymbolId := lType.SemanticSymbolId;
    lIdentity.SourceRange := lType.SourceRange;
    if lType.VisibilityRange.Line > 0 then
      fVisibilityRanges.AddOrSetValue(lIdentity.DeclaredId.Value, lType.VisibilityRange)
    else
      fVisibilityRanges.AddOrSetValue(lIdentity.DeclaredId.Value, lType.SourceRange);
    if SameText(lIdentity.ScopeKind, 'routine') and
      SameText(lIdentity.Kind, 'type-alias') then
    begin
      lPending.Add(lIdentity);
      fUnsupportedLocalScopeName.AddOrSetValue(LocalTypeKey(lIdentity.UnitId.Value,
        lIdentity.OwnerScopeId, lIdentity.Name), 0);
    end else if SameText(lIdentity.ScopeKind, 'routine') then
      AddIdentity(lIdentity)
    else begin
      // All unit names must exist before an alias can resolve its target.
      if not lIdentity.Synthetic then
      begin
        fByQualifiedName.AddOrSetValue(lIdentity.UnitName + '.' + lIdentity.Name, lIdentity);
        AddToMap(fBySimpleName, lIdentity.Name, lIdentity);
      end;
    end;
    lIdentities[i] := lIdentity;
    Inc(i);
  end;

  for lIdentity in lIdentities do
    if not SameText(lIdentity.ScopeKind, 'routine') then
      AddIdentity(lIdentity);

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

  for var lNested in aGraph.Types do
    if SameText(lNested.ScopeKind, 'type') then
    begin
      var lChild: TDelphiSemanticTypeIdentity;
      if fByDeclaredId.TryGetValue(lNested.DeclaredId.Value, lChild) then
        for var lOwner in lIdentities do
          if SameText(lOwner.UnitName, lChild.UnitName) and
            SameText(lOwner.OwnerScopeId + '|type|' + lOwner.Name, lChild.OwnerScopeId) then
          begin
            lChild.EnclosingTypeId := lOwner.DeclaredId;
            fByDeclaredId.AddOrSetValue(lChild.DeclaredId.Value, lChild);
            var lNames: TDelphiSemanticTypeIdentityList;
            if fBySimpleName.TryGetValue(lChild.Name, lNames) then
              for var j := 0 to lNames.Count - 1 do
                if lNames[j].DeclaredId.Value = lChild.DeclaredId.Value then
                begin
                  var lNamed := lNames[j];
                  lNamed.EnclosingTypeId := lOwner.DeclaredId;
                  lNames[j] := lNamed;
                end;
          end;
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
  for var lValues in fUnitValuesByName.Values do
    lValues.Free;
  fUnitValuesByName.Free;
  fUnits.Free;
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
  fVisibilityRanges.Free;
  fByDeclaredId.Free;
  fByCanonicalId.Free;
  inherited;
end;

procedure TDelphiSemanticTypeIdentityIndexData.AddIdentity(
  const aIdentity: TDelphiSemanticTypeIdentity);
var
  i: Integer;
  lIdentity: TDelphiSemanticTypeIdentity;
  lList: TDelphiSemanticTypeIdentityList;
begin
  lIdentity := aIdentity;
  if SameText(lIdentity.ScopeKind, 'routine') and
    ((lIdentity.OwnerScopeId = '') or (lIdentity.SemanticSymbolId = '') or
    (lIdentity.DeclaredId.Value = '') or (lIdentity.CanonicalId.Value = '') or
    (lIdentity.UnderlyingId.Value = '')) then
    Exit;
  if not MatchText(lIdentity.ScopeKind, ['routine', 'type']) then
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
  end else if not lIdentity.Synthetic then
  begin
    fByQualifiedName.AddOrSetValue(lIdentity.UnitName + '.' + lIdentity.Name, lIdentity);
    if fBySimpleName.TryGetValue(lIdentity.Name, lList) then
      for i := 0 to lList.Count - 1 do
        // Forward and full declarations share a DeclaredId, but not a source range.
        if (lList[i].DeclaredId.Value = lIdentity.DeclaredId.Value) and
          (lList[i].SourceRange.Line = lIdentity.SourceRange.Line) and
          (lList[i].SourceRange.Column = lIdentity.SourceRange.Column) then
          lList[i] := lIdentity;
  end;
end;

function TDelphiSemanticTypeIdentityIndexData.TryFinalizeLocalAlias(
  var aIdentity: TDelphiSemanticTypeIdentity): Boolean;
var
  lLookup: TDelphiSemanticTypeResolution;
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
  lLookup := ResolveTypeAt(TDelphiSemanticNameSites.AtTypeIdentity(aIdentity), lTargetName);
  if (lLookup.Outcome <> noResolved) or
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
  lTarget: TDelphiSemanticTypeResolution;
begin
  if aIdentity.HelperTargetName = '' then
    Exit;

  AddToMap(fHelpersByTargetName, aIdentity.HelperTargetName, aIdentity);
  lTarget := ResolveTypeAt(TDelphiSemanticNameSites.AtTypeIdentity(aIdentity),
    aIdentity.HelperTargetName);
  if lTarget.Outcome = noResolved then
  begin
    AddToMap(fHelpersByTargetName, lTarget.Identity.Name, aIdentity);
    AddToMap(fHelpersByTargetName, lTarget.Identity.UnitName + '.' + lTarget.Identity.Name,
      aIdentity);
    AddToMap(fHelpersByTargetName, lTarget.Identity.CanonicalName, aIdentity);
    AddToMap(fHelpersByTargetName, lTarget.Identity.UnderlyingName, aIdentity);
  end;
end;

function TDelphiSemanticTypeIdentityIndexData.ResolveLineage(
  const aIdentity: TDelphiSemanticTypeIdentity): TDelphiSemanticLineage;
var
  lAncestor, lCurrent: TDelphiSemanticTypeIdentity;
  lList: TDelphiSemanticTypeIdentityList;
  lLookup: TDelphiSemanticTypeResolution;
  lRoot, lSpelling: string;
  lStrong: Boolean;
  lVisited: THashSet<string>;
begin
  Result := Default(TDelphiSemanticLineage);
  Result.StrongAliasAt := -1;
  lList := TDelphiSemanticTypeIdentityList.Create;
  lVisited := THashSet<string>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
  try
    lCurrent := aIdentity;
    lList.Add(lCurrent);
    if (lCurrent.DeclaredId.Value = '') or
      not fByDeclaredId.ContainsKey(lCurrent.DeclaredId.Value) then
    begin
      Result.Cause := 'unresolved-base';
      Exit;
    end;
    lVisited.Add(lCurrent.DeclaredId.Value);
    repeat
      if SameText(lCurrent.UnitName, 'System') and
        MatchText(lCurrent.Name, ['TObject', 'IInterface']) then
      begin
        Result.ImplicitRoot := 'System.' + lCurrent.Name;
        Result.RootIndexed := True;
        Result.Complete := True;
        Break;
      end;
      if SameText(lCurrent.Kind, 'type-alias') then
      begin
        lSpelling := lCurrent.CanonicalName.Trim;
        lStrong := (Length(lSpelling) > 4) and
          SameText(Copy(lSpelling, 1, 4), 'type') and
          CharInSet(lSpelling[5], [#9, #10, #13, ' ']);
        if lStrong then
        begin
          if Result.StrongAliasAt < 0 then
            Result.StrongAliasAt := lList.Count - 1;
          lSpelling := Copy(lSpelling, 6, MaxInt).Trim;
        end;
        lLookup := ResolveTypeAt(TDelphiSemanticNameSites.AtTypeIdentity(lCurrent), lSpelling);
        if lLookup.Outcome <> TDelphiSemanticNameOutcome.noResolved then
        begin
          Result.Cause := 'alias-unresolved';
          Break;
        end;
        lAncestor := lLookup.Identity;
      end else begin
        lRoot := '';
        if lCurrent.BaseTypeName = '' then
        begin
          if SameText(lCurrent.CanonicalName, 'class') then
            lRoot := 'System.TObject'
          else if SameText(lCurrent.CanonicalName, 'interface') then
            lRoot := 'System.IInterface';
        end else begin
          lLookup := ResolveTypeAt(TDelphiSemanticNameSites.AtTypeIdentity(lCurrent),
            lCurrent.BaseTypeName);
          if lLookup.Outcome <> TDelphiSemanticNameOutcome.noResolved then
          begin
            // A spelled but unindexed SDK root is the same boundary as an
            // implicit one. An unknown unqualified homonym stays unproved.
            if ((lLookup.Outcome = TDelphiSemanticNameOutcome.noAbsent) and
              MatchText(lCurrent.BaseTypeName, ['TObject', 'IInterface'])) or
              (not fUnits.ContainsKey('System') and
              MatchText(lCurrent.BaseTypeName, ['System.TObject', 'System.IInterface'])) then
            begin
              if EndsText('TObject', lCurrent.BaseTypeName) then
                lRoot := 'System.TObject'
              else
                lRoot := 'System.IInterface';
            end else begin
              if lLookup.Outcome in [TDelphiSemanticNameOutcome.noUnproved,
                TDelphiSemanticNameOutcome.noAmbiguous] then
                Result.Cause := 'unproved-base'
              else
                Result.Cause := 'unresolved-base';
              Break;
            end;
          end else
            lAncestor := lLookup.Identity;
        end;
        if (lCurrent.BaseTypeName = '') or (lRoot <> '') then
        begin
          Result.ImplicitRoot := lRoot;
          if (lRoot = '') or not fByQualifiedName.TryGetValue(lRoot, lAncestor) then
          begin
            Result.Complete := True;
            Break;
          end;
          Result.RootIndexed := True;
        end;
      end;
      if (lAncestor.DeclaredId.Value = '') or
        lVisited.Contains(lAncestor.DeclaredId.Value) then
      begin
        Result.Cause := 'cycle';
        Break;
      end;
      lVisited.Add(lAncestor.DeclaredId.Value);
      lList.Add(lAncestor);
      lCurrent := lAncestor;
    until False;
  finally
    Result.Items := lList.ToArray;
    lVisited.Free;
    lList.Free;
  end;
end;

function TDelphiSemanticTypeIdentityIndexData.FindAncestors(
  const aIdentity: TDelphiSemanticTypeIdentity): TArray<TDelphiSemanticTypeIdentity>;
var
  lLineage: TDelphiSemanticLineage;
begin
  lLineage := ResolveLineage(aIdentity);
  Result := Copy(lLineage.Items, 1, MaxInt);
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

function TDelphiSemanticTypeIdentityIndexData.VisibleUnitNames(const aUnitName,
  aSectionKind: string): TArray<string>;
var
  lUnit: TDelphiSemanticGraphUnit;
begin
  Result := nil;
  if not fUnits.TryGetValue(aUnitName, lUnit) then
    Exit;
  Result := Copy(lUnit.InterfaceImports);
  if SameText(aSectionKind, 'implementation') then
    Result := Result + lUnit.ImplementationImports;
  if not lUnit.ImportsKnown then
    Result := Result + ['<imports-unproved>'];
end;

function TDelphiSemanticTypeIdentityIndexData.ResolveVisibleName(const aName,
  aCurrentUnitName: string; const aVisibleUnitNames: TArray<string>; const aSectionKind: string):
  TDelphiSemanticTypeLookupResult;
var
  i: Integer;
  lCandidate: TDelphiSemanticTypeIdentity;
  lList: TDelphiSemanticTypeIdentityList;
  lMatches: TDelphiSemanticTypeIdentityList;
  lUnit: TDelphiSemanticGraphUnit;
  lUnitName, lUnknownUnit: string;
begin
  if not fBySimpleName.TryGetValue(aName, lList) then
    Exit(UnresolvedResult(aName, 'TYPE_NOT_FOUND',
      'No visible type declaration named "' + aName + '" was found.'));
  lMatches := TDelphiSemanticTypeIdentityList.Create;
  try
    for lCandidate in lList do
      if SameText(lCandidate.UnitName, aCurrentUnitName) and
        SameUnitOrInterfaceVisible(lCandidate, aCurrentUnitName, aSectionKind) then
        lMatches.Add(lCandidate);
    if lMatches.Count = 1 then
      Exit(ResolvedResult(lMatches[0]));
    if lMatches.Count > 1 then
      Exit(AmbiguousResult(aName, lMatches.ToArray));
    lUnknownUnit := '';
    for i := High(aVisibleUnitNames) downto 0 do
    begin
      lUnitName := aVisibleUnitNames[i];
      if (lUnitName = '') or SameText(lUnitName, aCurrentUnitName) then
        Continue;
      lMatches.Clear;
      for lCandidate in lList do
        if SameText(lCandidate.UnitName, lUnitName) and
          SameUnitOrInterfaceVisible(lCandidate, aCurrentUnitName, aSectionKind) then
          lMatches.Add(lCandidate);
      if lMatches.Count > 0 then
      begin
        if lUnknownUnit <> '' then
        begin
          Result := UnresolvedResult(aName, 'TYPE_VISIBILITY_UNPROVED',
            'Used unit "' + lUnknownUnit + '" is listed after "' + lUnitName +
            '" and may declare "' + aName + '".');
          Result.Status := 'unproved';
          Exit;
        end;
        if lMatches.Count = 1 then
          Exit(ResolvedResult(lMatches[0]));
        Exit(AmbiguousResult(aName, lMatches.ToArray));
      end;
      if fUnits.TryGetValue(lUnitName, lUnit) then
      begin
        if not (SameText(lUnit.ScopeModelStatus, 'ast') or
          SameText(lUnit.ScopeModelStatus, 'ast-interface-only')) then
          lUnknownUnit := lUnitName;
      end else if (fUnitNameWitness = nil) or
        fUnitNameWitness.MayDeclare(lUnitName, aName) then
        lUnknownUnit := lUnitName;
    end;
  finally
    lMatches.Free;
  end;
  Result := UnresolvedResult(aName, 'TYPE_NOT_VISIBLE',
    'No visible type declaration named "' + aName + '" was found.');
end;

function TDelphiSemanticTypeIdentityIndexData.ResolveUnderlyingName(
  const aIdentity: TDelphiSemanticTypeIdentity): string;
var
  lCurrent, lTarget: TDelphiSemanticTypeIdentity;
  lRemaining: Integer;
begin
  lCurrent := aIdentity;
  lRemaining := fByQualifiedName.Count + 1;
  while lRemaining > 0 do
  begin
    Dec(lRemaining);
    if SameText(lCurrent.Kind, 'type-alias') and TryResolveAliasTarget(lCurrent, lTarget) then
      lCurrent := lTarget
    else begin
      if lCurrent.UnderlyingName <> '' then
        Exit(lCurrent.UnderlyingName);
      Exit(lCurrent.CanonicalName);
    end;
  end;
  // Registering all names first exposes cycles that a partial map could not follow.
  Result := '';
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
  lResult: TDelphiSemanticTypeResolution;
begin
  aTarget := Default(TDelphiSemanticTypeIdentity);
  if (aIdentity.CanonicalName = '') or (aIdentity.CanonicalName[1] = '^') then
    Exit(False);
  lResult := ResolveTypeAt(TDelphiSemanticNameSites.AtTypeIdentity(aIdentity),
    aIdentity.CanonicalName);
  Result := (lResult.Outcome = noResolved) and
    (lResult.Identity.DeclaredId.Value <> aIdentity.DeclaredId.Value);
  if Result then
    aTarget := lResult.Identity;
end;

function TDelphiSemanticTypeIdentityIndex.ResolveLineage(
  const aIdentity: TDelphiSemanticTypeIdentity): TDelphiSemanticLineage;
begin
  Result := Default(TDelphiSemanticLineage);
  Result.StrongAliasAt := -1;
  if fData <> nil then
    Result := fData.ResolveLineage(aIdentity);
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

function TDelphiSemanticTypeIdentityIndex.VisibleUnitNames(const aUnitName,
  aSectionKind: string): TArray<string>;
begin
  Result := nil;
  if fData <> nil then
    Result := fData.VisibleUnitNames(aUnitName, aSectionKind);
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

class function TDelphiSemanticTypeResolver.BuildIndex(
  const aGraph: TDelphiSemanticSemanticGraph;
  const aNamedRootAbsence: IDelphiSemanticNamedRootMemberAbsence): TDelphiSemanticTypeIdentityIndex;
begin
  Result := Default(TDelphiSemanticTypeIdentityIndex);
  Result.fData := TDelphiSemanticTypeIdentityIndexData.Create(aGraph, aNamedRootAbsence);
end;

end.
