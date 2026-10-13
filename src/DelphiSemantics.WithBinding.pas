unit DelphiSemantics.WithBinding;

interface

uses
  DelphiSemantics.Model, DelphiSemantics.Resolve, DelphiSemantics.Resolve.ScopeResolver,
  DelphiSemantics.Resolve.TypeResolver, DelphiSemantics.RootMemberAbsence,
  DelphiSemantics.SemanticGraph;

type
  TDelphiSemanticWithSelectorBinding = record
    SelectorText: string;
    Status: string;
    ReasonCode: string;
    TypeName: string;
    TypeIdentity: TDelphiSemanticTypeIdentity;
  end;

  TDelphiSemanticBoundReference = record
    SemanticId: string;
    Name: string;
    Classification: string;
    LookupSource: string;
    ReceiverTypeName: string;
    Kind: string;
    TypeName: string;
    ReasonCode: string;
    ScopeConflictKind: string;
    ScopeConflictName: string;
    Line: Integer;
    Column: Integer;
    EndLine: Integer;
    EndColumn: Integer;
  end;

  TDelphiSemanticInventorySymbol = record
    Name: string;
    SymbolClass: string;
    Kind: string;
    TypeName: string;
    Modifier: string;
    OwnerName: string;
    OwnerType: string;
    SourceOwnerType: string;
    RelatedTypeName: string;
    RoutineName: string;
    RoutineScopeId: string;
    ParentScopeId: string;
    OwnerScopeId: string;
    OwnerSymbolId: string;
    UnitName: string;
    FileName: string;
    SectionKind: string;
    Line: Integer;
    Column: Integer;
    EndLine: Integer;
    EndColumn: Integer;
    UnsupportedReason: string;
    IsHelper: Boolean;
    IsOverride: Boolean;
    IsDefault: Boolean;
    IsIndexed: Boolean;
    IndexParameterCount: Integer;
    TypeCategory: string;
    OwnerIdentity: TDelphiSemanticTypeIdentity;
    AccessOwnerIdentity: TDelphiSemanticTypeIdentity;
    AccessOwnerUnitName: string;
    AccessOwnerFileName: string;
    AccessOwnerSectionKind: string;
    AccessOwnerLine: Integer;
    AccessOwnerColumn: Integer;
  end;

  TDelphiSemanticWithBinding = record
    SemanticId: string;
    Provenance: string;
    FileName: string;
    UnitName: string;
    RoutineName: string;
    RoutineScopeId: string;
    Line: Integer;
    Column: Integer;
    EndLine: Integer;
    EndColumn: Integer;
    BodyLine: Integer;
    BodyColumn: Integer;
    BodyEndLine: Integer;
    BodyEndColumn: Integer;
    SelectorText: string;
    Status: string;
    SkipReason: string;
    HasScopedDeclaration: Boolean;
    ActivityUnverified: Boolean;
    MemberActivityUnverified: Boolean;
    InactiveSpanSkipReason: string;
    InactiveSpanReferences: TArray<TDelphiSemanticBoundReference>;
    MemberReferenceCount: Integer;
    LexicalReferenceCount: Integer;
    ExternalReferenceCount: Integer;
    IntrinsicReferenceCount: Integer;
    UnsupportedReferenceCount: Integer;
    UnresolvedReferenceCount: Integer;
    Selectors: TArray<TDelphiSemanticWithSelectorBinding>;
    References: TArray<TDelphiSemanticBoundReference>;
  end;

  TDelphiSemanticRemoveWithInventory = record
    FileName: string;
    UnitName: string;
    Symbols: TArray<TDelphiSemanticInventorySymbol>;
    Bindings: TArray<TDelphiSemanticWithBinding>;
  end;

  TDelphiSemanticProjectWithBindingMetrics = record
    SemanticGraphUsed: Boolean;
    BuildUnitIndexUsed: Boolean;
    UnitCount: Integer;
    WithStatementCount: Integer;
    BindingCount: Integer;
    ModelExtractionMilliseconds: Int64;
    SemanticGraphBuildMilliseconds: Int64;
    InventoryBuildMilliseconds: Int64;
    InventoryExpansionMilliseconds: Int64;
    BindingBuildMilliseconds: Int64;
    ScopeIndexBuildMilliseconds: Int64;
    SelectorBindingMilliseconds: Int64;
    ReferenceBindingMilliseconds: Int64;
    ReceiverMemberResolveMilliseconds: Int64;
    LexicalResolveMilliseconds: Int64;
    ReferenceCacheHitCount: Int64;
    ReferenceCacheMissCount: Int64;
    LookupIndexBuildMilliseconds: Int64;
    SemanticCacheHits: Int64;
    SemanticCacheMisses: Int64;
    SemanticCacheInvalidations: Int64;
    SemanticCachePersistentConnectionOpenCount: Int64;
    ProjectFactsCacheHits: Int64;
    ProjectFactsCacheMisses: Int64;
    ProjectFactsCacheInvalidations: Int64;
    SnapshotSqlWriteMilliseconds: Int64;
    SnapshotSqlReadMilliseconds: Int64;
    SnapshotDeserializeMilliseconds: Int64;
    SnapshotIndexRebuildMilliseconds: Int64;
  end;

  TDelphiSemanticRemoveWithLookupMetrics = record
    BuildMilliseconds: Int64;
    HitCount: Int64;
    MissCount: Int64;
  end;

  TDelphiSemanticRemoveWithLookupActivityMetrics = record
    ResultMaterializationCount: Int64;
    MaterializedSymbolCount: Int64;
  end;

  IDelphiSemanticRemoveWithLookupIndexData = interface
    ['{14739A1A-96F8-4F81-B0B9-73AF9DA6BE2F}']
    function FindMembersByOwnerAndName(const aOwnerName, aName: string):
      TArray<TDelphiSemanticInventorySymbol>;
    function FindRoutineSymbol(const aRoutineName, aName: string;
      out aSymbol: TDelphiSemanticInventorySymbol): Boolean;
    function PointerTargetType(const aTypeName: string): string;
    function FindDeclarationOrTypeAliasByName(const aName: string):
      TArray<TDelphiSemanticInventorySymbol>;
    function FindUnitOrGlobalByName(const aName: string): TArray<TDelphiSemanticInventorySymbol>;
    function FindUnitOrGlobalByPrefix(const aName: string):
      TArray<TDelphiSemanticInventorySymbol>;
    function FindSymbolsByName(const aName: string): TArray<TDelphiSemanticInventorySymbol>;
    function FindSymbolsByOwnerType(const aOwnerType: string):
      TArray<TDelphiSemanticInventorySymbol>;
    function Metrics: TDelphiSemanticRemoveWithLookupMetrics;
  end;

  TDelphiSemanticRemoveWithLookupIndex = record
  private
    fData: IDelphiSemanticRemoveWithLookupIndexData;
  public
    class function Build(const aModels: TArray<TDelphiSemanticUnitModel>;
      const aSymbols: TArray<TDelphiSemanticInventorySymbol>):
      TDelphiSemanticRemoveWithLookupIndex; static;
    function IsAvailable: Boolean;
    function FindMembersByOwnerAndName(const aOwnerName, aName: string):
      TArray<TDelphiSemanticInventorySymbol>;
    function FindRoutineSymbol(const aRoutineName, aName: string;
      out aSymbol: TDelphiSemanticInventorySymbol): Boolean;
    function PointerTargetType(const aTypeName: string): string;
    function FindDeclarationOrTypeAliasByName(const aName: string):
      TArray<TDelphiSemanticInventorySymbol>;
    function FindUnitOrGlobalByName(const aName: string): TArray<TDelphiSemanticInventorySymbol>;
    function FindUnitOrGlobalByPrefix(const aName: string):
      TArray<TDelphiSemanticInventorySymbol>;
    function FindSymbolsByName(const aName: string): TArray<TDelphiSemanticInventorySymbol>;
    function FindSymbolsByOwnerType(const aOwnerType: string):
      TArray<TDelphiSemanticInventorySymbol>;
    function Metrics: TDelphiSemanticRemoveWithLookupMetrics;
    function ActivityMetrics: TDelphiSemanticRemoveWithLookupActivityMetrics;
  end;

  TDelphiSemanticProjectWithBindingFacts = record
    ContextFingerprint: string;
    Metrics: TDelphiSemanticProjectWithBindingMetrics;
    LookupIndex: TDelphiSemanticRemoveWithLookupIndex;
    UnitModels: TArray<TDelphiSemanticUnitModel>;
    Symbols: TArray<TDelphiSemanticInventorySymbol>;
    Bindings: TArray<TDelphiSemanticWithBinding>;
  end;

  TDelphiSemanticWithBinder = record
  public
    class function BindModel(const aModel: TDelphiSemanticUnitModel):
      TArray<TDelphiSemanticWithBinding>; static;
    class function BindProject(const aContextFingerprint: string;
      const aGraph: TDelphiSemanticSemanticGraph;
      const aModels: TArray<TDelphiSemanticUnitModel>):
      TDelphiSemanticProjectWithBindingFacts; overload; static;
    class function BindProject(const aContextFingerprint: string;
      const aGraph: TDelphiSemanticSemanticGraph;
      const aModels: TArray<TDelphiSemanticUnitModel>;
      const aRootMemberAbsence: IDelphiSemanticImplicitRootMemberAbsence):
      TDelphiSemanticProjectWithBindingFacts; overload; static;
    class function BuildInventory(const aModel: TDelphiSemanticUnitModel):
      TDelphiSemanticRemoveWithInventory; static;
    class function ExpandInventorySymbols(const aSymbols: TArray<TDelphiSemanticInventorySymbol>):
      TArray<TDelphiSemanticInventorySymbol>; static;
  end;

// WITH-only verification must not become rename/find-usages reference output.
function WithBindingForPlanning(const aBinding: TDelphiSemanticWithBinding):
  TDelphiSemanticWithBinding;

implementation

uses
  System.Classes, System.Diagnostics, System.Generics.Collections, System.Hash, System.Math,
  System.RegularExpressions, System.StrUtils, System.SysUtils,
  AutoFree,
  SimpleParser.Lexer, SimpleParser.Lexer.Types,
  DelphiSemantics.CompilerProfile, DelphiSemantics.Model.Text, DelphiSemantics.ProjectContext,
  DelphiSemantics.Resolve.MemberResolver, DelphiSemantics.Resolve.SelectorTypes,
  DelphiSemantics.SourceConditionals, DelphiSemantics.WithBinding.Inventory,
  MaxLogic.StrUtils;

type
  IDelphiSemanticRemoveWithLookupActivityData = interface
    ['{5E17BE4B-30D7-43E4-A47D-835EB036B78A}']
    function ActivityMetrics: TDelphiSemanticRemoveWithLookupActivityMetrics;
  end;

  TDelphiSemanticRemoveWithLookupIndexData = class(TInterfacedObject,
    IDelphiSemanticRemoveWithLookupIndexData,
    IDelphiSemanticRemoveWithLookupActivityData)
  private
    fActivityMetrics: TDelphiSemanticRemoveWithLookupActivityMetrics;
    fDeclarationsByName: TDictionary<string, TList<TDelphiSemanticInventorySymbol>>;
    fMembersByOwnerName: TDictionary<string, TList<TDelphiSemanticInventorySymbol>>;
    fMemberMisses: TDictionary<string, Byte>;
    fMetrics: TDelphiSemanticRemoveWithLookupMetrics;
    fPointerTargetByType: TDictionary<string, string>;
    fPointerTargetMisses: TDictionary<string, Byte>;
    fRoutineMisses: TDictionary<string, Byte>;
    fRoutineSymbolsByName: TDictionary<string, TDelphiSemanticInventorySymbol>;
    fSymbolsByName: TDictionary<string, TList<TDelphiSemanticInventorySymbol>>;
    fSymbolsByOwnerType: TDictionary<string, TList<TDelphiSemanticInventorySymbol>>;
    fUnitsAndGlobalsByName: TDictionary<string, TList<TDelphiSemanticInventorySymbol>>;
    fUnitsAndGlobalsByPrefix: TDictionary<string, TList<TDelphiSemanticInventorySymbol>>;
    class function OwnerNameKey(const aOwnerName, aName: string): string; static;
    class function IsDirectMemberSymbolClass(const aSymbolClass: string): Boolean; static;
    class procedure AddSymbolToMap(const aMap: TDictionary<string,
      TList<TDelphiSemanticInventorySymbol>>; const aKey: string;
      const aSymbol: TDelphiSemanticInventorySymbol); static;
    class function MemberSymbol(const aModel: TDelphiSemanticUnitModel;
      const aMember: TDelphiSemanticMember): TDelphiSemanticInventorySymbol; static;
    class function RoutineNameForModelRoutine(const aRoutine: TDelphiSemanticRoutine): string; static;
    class function RoutineParameterSymbol(const aModel: TDelphiSemanticUnitModel;
      const aRoutineName: string; const aParameter: TDelphiSemanticParameter):
      TDelphiSemanticInventorySymbol; static;
    class function RoutineLocalSymbol(const aModel: TDelphiSemanticUnitModel;
      const aLocal: TDelphiSemanticLocal): TDelphiSemanticInventorySymbol; static;
    procedure AddRoutineSymbol(const aRoutineName: string;
      const aSymbol: TDelphiSemanticInventorySymbol);
    procedure CountLookup(const aHit: Boolean);
    function SymbolsFromMap(const aMap: TDictionary<string,
      TList<TDelphiSemanticInventorySymbol>>; const aKey: string;
      const aMisses: TDictionary<string, Byte>): TArray<TDelphiSemanticInventorySymbol>;
  public
    constructor Create(const aModels: TArray<TDelphiSemanticUnitModel>;
      const aSymbols: TArray<TDelphiSemanticInventorySymbol>);
    destructor Destroy; override;
    function FindMembersByOwnerAndName(const aOwnerName, aName: string):
      TArray<TDelphiSemanticInventorySymbol>;
    function FindRoutineSymbol(const aRoutineName, aName: string;
      out aSymbol: TDelphiSemanticInventorySymbol): Boolean;
    function PointerTargetType(const aTypeName: string): string;
    function FindDeclarationOrTypeAliasByName(const aName: string):
      TArray<TDelphiSemanticInventorySymbol>;
    function FindUnitOrGlobalByName(const aName: string): TArray<TDelphiSemanticInventorySymbol>;
    function FindUnitOrGlobalByPrefix(const aName: string):
      TArray<TDelphiSemanticInventorySymbol>;
    function FindSymbolsByName(const aName: string): TArray<TDelphiSemanticInventorySymbol>;
    function FindSymbolsByOwnerType(const aOwnerType: string):
      TArray<TDelphiSemanticInventorySymbol>;
    function Metrics: TDelphiSemanticRemoveWithLookupMetrics;
    function ActivityMetrics: TDelphiSemanticRemoveWithLookupActivityMetrics;
  end;

  TIndexedDeclarationCandidate = record
    ModelIndex: Integer;
    DeclarationIndex: Integer;
  end;

  TMemberSafetyDiagnostic = record
    Code: string;
    UnitName: string;
    FileName: string;
    Line: Integer;
    OwnerName: string;
    OwnerResolved: Boolean;
  end;

  TBoundMemberResolution = record
    Value: TDelphiSemanticResolveResult;
    DeclaringUnitName: string;
    OwnerDeclaredId: TDelphiSemanticGraphTypeId;
  end;

  TWithBindingProjectMemberIndex = class
  private
    fRootMemberAbsence: IDelphiSemanticImplicitRootMemberAbsence;
    fCompilerIntrinsics: TDictionary<string, TDelphiSemanticIntrinsicSymbol>;
    fLookupIndex: TDelphiSemanticRemoveWithLookupIndex;
    fTypeIndex: TDelphiSemanticTypeIdentityIndex;
    fModels: TArray<TDelphiSemanticUnitModel>;
    fDeclarationCandidates: TObjectDictionary<string, TList<TIndexedDeclarationCandidate>>;
    fDeclarationModels: TDictionary<string, TArray<TDelphiSemanticUnitModel>>;
    fByUnitOwnerName: TDictionary<string, TList<TBoundMemberResolution>>;
    fDirectMembersByContextOwnerName: TDictionary<string, TList<TBoundMemberResolution>>;
    fMemberKeysByUnit: TDictionary<string, TList<string>>;
    fSemanticMemberIndex: TDelphiSemanticMemberIdentityIndex;
    fSemanticMemberIndexAvailable: Boolean;
    fSemanticMemberResultsByOwnerName: TDictionary<string, TBoundMemberResolution>;
    fUnitNames: TArray<string>;
    fVisibleUnitsByUnit: TDictionary<string, TArray<string>>;
    fMemberSafetyDiagnostics: TArray<TMemberSafetyDiagnostic>;
    fActivityMemberFacts: TArray<TMemberSafetyDiagnostic>;
    fSafetyDeclarationsByName: TObjectDictionary<string, TList<TIndexedDeclarationCandidate>>;
    fSafetyModelsByUnit: TDictionary<string, TArray<Integer>>;
    fSafetyProfileTypes: TDictionary<string, Byte>;
    procedure BuildMemberSafetyDiagnostics;
    function LineageHasActivityFact(const aLineage: TArray<TDelphiSemanticTypeIdentity>): Boolean;
    function MemberActivityIsUnverified(const aBinding: TDelphiSemanticWithBinding;
      const aSelectorIdentities: TArray<TDelphiSemanticTypeIdentity>): Boolean;
    function IsKnownSafetyProfileTerminal(const aName: string;
      const aLookup: TDelphiSemanticTypeLookupResult): Boolean;
    function TryBuildMemberSafetyLineage(const aBinding: TDelphiSemanticWithBinding;
      const aSelectorTypeName: string; const aSelectorIdentity: TDelphiSemanticTypeIdentity;
      out aLineage: TArray<TDelphiSemanticTypeIdentity>): Boolean;
    function ReceiverMemberAbsenceIsVerified(const aModel: TDelphiSemanticUnitModel;
      const aSelector: TDelphiSemanticWithSelectorBinding; const aName: string): Boolean;
    function TryResolveVerifiedSimpleMember(const aModel: TDelphiSemanticUnitModel;
      const aSelectors: TArray<TDelphiSemanticWithSelectorBinding>;
      const aCurrentTypeName, aMemberCachePrefix, aName: string;
      const aMemberCache: TDictionary<string, TBoundMemberResolution>;
      out aResult: TBoundMemberResolution): Boolean;
    function TryResolveSelectorIdentity(const aOriginModel: TDelphiSemanticUnitModel;
      const aOriginSectionKind, aOriginScopeId, aTypeName: string;
      out aIdentity: TDelphiSemanticTypeIdentity): Boolean;
    function IsUnsupportedRoutineLocalType(const aOriginModel: TDelphiSemanticUnitModel;
      const aOriginSectionKind, aOriginScopeId, aTypeName: string): Boolean;
    function TryResolveTypeOriginScope(const aDeclaringModel,
      aOriginModel: TDelphiSemanticUnitModel; const aResolved: TDelphiSemanticResolveResult;
      out aScopeId, aOwnRoutineScopeId: string): Boolean;
    function TryResolveMemberOwnerIdentity(const aSymbol: TDelphiSemanticInventorySymbol;
      out aIdentity, aAccessIdentity: TDelphiSemanticTypeIdentity): Boolean;
    function IsVerifiedRecordHelper(const aModel: TDelphiSemanticUnitModel;
      const aDeclaration: TDelphiSemanticDeclaration): Boolean;
    function HasClosedRootSourceContext(const aContextModel: TDelphiSemanticUnitModel): Boolean;
    function UnitRoutineDeclarationIsVerified(const aModel: TDelphiSemanticUnitModel;
      const aDeclaration: TDelphiSemanticDeclaration): Boolean;
    function TrySafetyDeclarationModel(const aIdentity: TDelphiSemanticTypeIdentity;
      out aModel: TDelphiSemanticUnitModel): Boolean;
    function TryResolveUniqueExportedFinalType(const aOriginModel: TDelphiSemanticUnitModel;
      const aTypeName: string; out aIdentity: TDelphiSemanticTypeIdentity): Boolean;
    function TryResolveAnonymousMemberTypeIdentity(
      const aDeclaringModel: TDelphiSemanticUnitModel;
      const aMember: TDelphiSemanticResolveResult;
      out aIdentity: TDelphiSemanticTypeIdentity): Boolean;
    procedure BuildDeclarationIndex;
    procedure BuildCompilerIntrinsicIndex;
    function DeclarationModelsForName(const aName: string): TArray<TDelphiSemanticUnitModel>;
    class function Key(const aUnitName, aOwnerName, aName: string): string; static;
    class function KeyMemberName(const aKey: string): string; static;
    class function KeyOwnerName(const aKey: string): string; static;
    class function KeyUnitName(const aKey: string): string; static;
    class function MemberResult(const aMember: TDelphiSemanticMember):
      TDelphiSemanticResolveResult; static;
    procedure AddContextMemberKey(const aContextUnitName, aMemberKey: string;
      const aOnlyOwnerMatchingSourceUnit: Boolean);
    procedure AddContextUnitMembers(const aContextUnitName, aSourceUnitName: string;
      const aOnlyOwnerMatchingSourceUnit: Boolean);
    procedure AddMember(const aUnitName: string; const aMember: TDelphiSemanticMember);
    procedure AddMemberKey(const aUnitName, aKey: string);
    class procedure AddResultToMap(const aMap: TDictionary<string,
      TList<TBoundMemberResolution>>; const aKey: string;
      const aResult: TBoundMemberResolution); static;
    procedure BuildContextMemberIndex;
    class function ResolveMemberList(const aOwnerName, aName: string;
      const aList: TList<TBoundMemberResolution>;
      out aResult: TBoundMemberResolution): Boolean; static;
    class function ResolveResultIsUsable(
      const aResult: TDelphiSemanticResolveResult): Boolean; static;
    procedure ClearOwnedState;
    function TryResolveContextMember(const aContextUnitName, aOwnerName, aName: string;
      out aResult: TBoundMemberResolution): Boolean;
    function TryResolveUnitMember(const aUnitName, aOwnerName, aName: string;
      out aResult: TBoundMemberResolution): Boolean;
  public
    constructor Create(const aModels: TArray<TDelphiSemanticUnitModel>;
      const aGraph: TDelphiSemanticSemanticGraph;
      const aLookupIndex: TDelphiSemanticRemoveWithLookupIndex);
    destructor Destroy; override;
    function TryResolveCompilerIntrinsic(const aName: string;
      out aResult: TDelphiSemanticResolveResult): Boolean;
    function TryResolvePointerCastType(const aModel: TDelphiSemanticUnitModel;
      const aName: string; const aLine: Integer; out aTypeName: string): Boolean;
    function EstablishedMemberSafetyReason(const aBinding: TDelphiSemanticWithBinding;
      const aSelectorIdentities: TArray<TDelphiSemanticTypeIdentity>): string;
    function MemberSafetyReason(const aBinding: TDelphiSemanticWithBinding;
      const aSelectorIdentities: TArray<TDelphiSemanticTypeIdentity>): string;
    function ContextForName(const aContext: TDelphiSemanticResolveContext;
      const aName: string): TDelphiSemanticResolveContext;
    function TryResolveDirectMember(const aCurrentUnitName, aCurrentTypeName, aOwnerName,
      aName: string; const aAllowSemanticFallback: Boolean;
      out aResult: TDelphiSemanticResolveResult): Boolean; overload;
    function TryResolveDirectMember(const aCurrentUnitName, aCurrentTypeName, aOwnerName,
      aName: string; const aAllowSemanticFallback: Boolean;
      out aResult: TBoundMemberResolution): Boolean; overload;
    function TryResolveDirectMember(const aCurrentUnitName, aCurrentTypeName, aOwnerName,
      aName: string; const aAllowSemanticFallback: Boolean;
      const aCurrentFileName: string; const aOwnerIdentity: TDelphiSemanticTypeIdentity;
      out aResult: TBoundMemberResolution): Boolean; overload;
    function TryResolveRoutineLocalMember(const aOwnerIdentity: TDelphiSemanticTypeIdentity;
      const aCurrentTypeName, aName: string; out aResult: TBoundMemberResolution): Boolean;
  end;

  TWithSelectorBindingArray = TArray<TDelphiSemanticWithSelectorBinding>;
  TWithSelectorStackArray = TArray<TWithSelectorBindingArray>;
  TWithSelectorIdentityArray = TArray<TDelphiSemanticTypeIdentity>;
  TWithSelectorIdentityStackArray = TArray<TWithSelectorIdentityArray>;

function StableFactId(const aPrefix, aText: string): string;
begin
  Result := aPrefix + '-' + THashSHA2.GetHashString(aText);
end;

class function TDelphiSemanticRemoveWithLookupIndexData.OwnerNameKey(
  const aOwnerName, aName: string): string;
begin
  Result := aOwnerName + #31 + aName;
end;

class function TDelphiSemanticRemoveWithLookupIndexData.IsDirectMemberSymbolClass(
  const aSymbolClass: string): Boolean;
begin
  Result := MatchText(aSymbolClass, ['member', 'field', 'property', 'method',
    'constant', 'class-var']);
end;

class procedure TDelphiSemanticRemoveWithLookupIndexData.AddSymbolToMap(
  const aMap: TDictionary<string, TList<TDelphiSemanticInventorySymbol>>;
  const aKey: string; const aSymbol: TDelphiSemanticInventorySymbol);
var
  lSymbols: TList<TDelphiSemanticInventorySymbol>;
begin
  if not aMap.TryGetValue(aKey, lSymbols) then
  begin
    lSymbols := TList<TDelphiSemanticInventorySymbol>.Create;
    aMap.Add(aKey, lSymbols);
  end;
  lSymbols.Add(aSymbol);
end;

class function TDelphiSemanticRemoveWithLookupIndexData.MemberSymbol(
  const aModel: TDelphiSemanticUnitModel;
  const aMember: TDelphiSemanticMember): TDelphiSemanticInventorySymbol;
begin
  Result := Default(TDelphiSemanticInventorySymbol);
  Result.Name := aMember.Name;
  Result.SymbolClass := 'member';
  Result.Kind := aMember.Kind;
  Result.TypeName := aMember.TypeName;
  Result.OwnerName := aMember.OwnerName;
  Result.OwnerType := aMember.OwnerName;
  Result.UnitName := aModel.UnitName;
  Result.FileName := aModel.FileName;
  Result.Line := aMember.Line;
  Result.Column := aMember.Column;
  Result.EndLine := aMember.Line;
  Result.EndColumn := aMember.Column;
  Result.IsDefault := aMember.IsDefault;
  Result.IsIndexed := aMember.IsIndexed;
  if aMember.IsIndexed then
    Result.IndexParameterCount := 1;
end;

class function TDelphiSemanticRemoveWithLookupIndexData.RoutineNameForModelRoutine(
  const aRoutine: TDelphiSemanticRoutine): string;
begin
  Result := aRoutine.Name;
  if aRoutine.OwnerName <> '' then
    Result := aRoutine.OwnerName + '.' + aRoutine.Name;
end;

class function TDelphiSemanticRemoveWithLookupIndexData.RoutineParameterSymbol(
  const aModel: TDelphiSemanticUnitModel; const aRoutineName: string;
  const aParameter: TDelphiSemanticParameter): TDelphiSemanticInventorySymbol;
begin
  Result := Default(TDelphiSemanticInventorySymbol);
  Result.Name := aParameter.Name;
  Result.SymbolClass := 'parameter';
  Result.Kind := 'parameter';
  Result.TypeName := aParameter.TypeName;
  Result.Modifier := aParameter.Modifier;
  Result.RoutineName := aRoutineName;
  Result.UnitName := aModel.UnitName;
  Result.FileName := aModel.FileName;
  Result.Line := aParameter.Line;
  Result.Column := aParameter.Column;
  Result.EndLine := aParameter.Line;
  Result.EndColumn := aParameter.Column;
end;

class function TDelphiSemanticRemoveWithLookupIndexData.RoutineLocalSymbol(
  const aModel: TDelphiSemanticUnitModel;
  const aLocal: TDelphiSemanticLocal): TDelphiSemanticInventorySymbol;
begin
  Result := Default(TDelphiSemanticInventorySymbol);
  Result.Name := aLocal.Name;
  Result.SymbolClass := 'local';
  Result.Kind := aLocal.Kind;
  Result.TypeName := aLocal.TypeName;
  Result.RoutineName := aLocal.RoutineName;
  Result.UnitName := aModel.UnitName;
  Result.FileName := aModel.FileName;
  Result.Line := aLocal.Line;
  Result.Column := aLocal.Column;
  Result.EndLine := aLocal.Line;
  Result.EndColumn := aLocal.Column;
end;

procedure TDelphiSemanticRemoveWithLookupIndexData.AddRoutineSymbol(
  const aRoutineName: string; const aSymbol: TDelphiSemanticInventorySymbol);
var
  lExistingSymbol: TDelphiSemanticInventorySymbol;
  lKey: string;
begin
  lKey := OwnerNameKey(aRoutineName, aSymbol.Name);
  if (aSymbol.Modifier = '') and fRoutineSymbolsByName.TryGetValue(lKey,
    lExistingSymbol) and (lExistingSymbol.Modifier <> '') then
    Exit;
  fRoutineSymbolsByName.AddOrSetValue(lKey, aSymbol);
end;

constructor TDelphiSemanticRemoveWithLookupIndexData.Create(
  const aModels: TArray<TDelphiSemanticUnitModel>;
  const aSymbols: TArray<TDelphiSemanticInventorySymbol>);
var
  lDeclaration: TDelphiSemanticDeclaration;
  lLocal: TDelphiSemanticLocal;
  lMember: TDelphiSemanticMember;
  lModel: TDelphiSemanticUnitModel;
  lNextDot: Integer;
  lOwnerName: string;
  lParameter: TDelphiSemanticParameter;
  lPrefixLength: Integer;
  lRoutine: TDelphiSemanticRoutine;
  lRoutineName: string;
  lSimpleRoutineName: string;
  lSymbol: TDelphiSemanticInventorySymbol;
  lTypeName: string;
begin
  inherited Create;
  fDeclarationsByName := TDictionary<string, TList<TDelphiSemanticInventorySymbol>>.Create(
    TFastCaseAwareComparer.OrdinalIgnoreCase);
  fMembersByOwnerName := TDictionary<string, TList<TDelphiSemanticInventorySymbol>>.Create(
    TFastCaseAwareComparer.OrdinalIgnoreCase);
  fMemberMisses := TDictionary<string, Byte>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
  fPointerTargetByType := TDictionary<string, string>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
  fPointerTargetMisses := TDictionary<string, Byte>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
  fRoutineMisses := TDictionary<string, Byte>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
  fRoutineSymbolsByName := TDictionary<string, TDelphiSemanticInventorySymbol>.Create(
    TFastCaseAwareComparer.OrdinalIgnoreCase);
  fSymbolsByName := TDictionary<string, TList<TDelphiSemanticInventorySymbol>>.Create(
    TFastCaseAwareComparer.OrdinalIgnoreCase);
  fSymbolsByOwnerType := TDictionary<string, TList<TDelphiSemanticInventorySymbol>>.Create(
    TFastCaseAwareComparer.OrdinalIgnoreCase);
  fUnitsAndGlobalsByName := TDictionary<string, TList<TDelphiSemanticInventorySymbol>>.Create(
    TFastCaseAwareComparer.OrdinalIgnoreCase);
  fUnitsAndGlobalsByPrefix := TDictionary<string, TList<TDelphiSemanticInventorySymbol>>.Create(
    TFastCaseAwareComparer.OrdinalIgnoreCase);

  for lModel in aModels do
  begin
    for lMember in lModel.Members do
      AddSymbolToMap(fMembersByOwnerName, OwnerNameKey(lMember.OwnerName, lMember.Name),
        MemberSymbol(lModel, lMember));

    for lRoutine in lModel.Routines do
    begin
      lRoutineName := RoutineNameForModelRoutine(lRoutine);
      for lParameter in lRoutine.Parameters do
      begin
        lSymbol := RoutineParameterSymbol(lModel, lRoutineName, lParameter);
        AddRoutineSymbol(lRoutine.Name, lSymbol);
        AddRoutineSymbol(lRoutineName, lSymbol);
      end;
    end;

    for lLocal in lModel.Locals do
    begin
      lSymbol := RoutineLocalSymbol(lModel, lLocal);
      AddRoutineSymbol(lLocal.RoutineName, lSymbol);
      if Pos('.', lLocal.RoutineName) > 0 then
      begin
        lSimpleRoutineName := Copy(lLocal.RoutineName,
          LastDelimiter('.', lLocal.RoutineName) + 1, MaxInt);
        AddRoutineSymbol(lSimpleRoutineName, lSymbol);
      end;
    end;

    for lDeclaration in lModel.Declarations do
    begin
      lTypeName := Trim(lDeclaration.TypeName);
      if StartsText('^', lTypeName) then
        fPointerTargetByType.AddOrSetValue(lDeclaration.Name,
          Trim(Copy(lTypeName, 2, MaxInt)));
    end;
  end;

  for lSymbol in aSymbols do
  begin
    lTypeName := Trim(lSymbol.TypeName);
    if Trim(lSymbol.Name) <> '' then
      AddSymbolToMap(fSymbolsByName, lSymbol.Name, lSymbol);
    if Trim(lSymbol.OwnerType) <> '' then
      AddSymbolToMap(fSymbolsByOwnerType, lSymbol.OwnerType, lSymbol);
    if StartsText('^', lTypeName) and
      (SameText(lSymbol.SymbolClass, 'declaration') or
      SameText(lSymbol.SymbolClass, 'type-member') or SameText(lSymbol.Kind, 'type') or
      SameText(lSymbol.Kind, 'type-alias')) then
      fPointerTargetByType.AddOrSetValue(lSymbol.Name,
        Trim(Copy(lTypeName, 2, MaxInt)));
    if (SameText(lSymbol.SymbolClass, 'local') or
      SameText(lSymbol.SymbolClass, 'parameter')) and
      (Trim(lSymbol.RoutineName) <> '') then
    begin
      AddRoutineSymbol(lSymbol.RoutineName, lSymbol);
      if Pos('.', lSymbol.RoutineName) > 0 then
      begin
        lSimpleRoutineName := Copy(lSymbol.RoutineName,
          LastDelimiter('.', lSymbol.RoutineName) + 1, MaxInt);
        AddRoutineSymbol(lSimpleRoutineName, lSymbol);
      end;
    end;
    if IsDirectMemberSymbolClass(lSymbol.SymbolClass) then
    begin
      lOwnerName := Trim(lSymbol.OwnerType);
      if lOwnerName = '' then
        lOwnerName := Trim(lSymbol.OwnerName);
      if lOwnerName <> '' then
        AddSymbolToMap(fMembersByOwnerName, OwnerNameKey(lOwnerName, lSymbol.Name),
          lSymbol);
    end;
    if SameText(lSymbol.SymbolClass, 'declaration') or
      SameText(lSymbol.SymbolClass, 'type-member') or
      (SameText(lSymbol.SymbolClass, 'external') and (Trim(lSymbol.TypeName) <> '')) or
      SameText(lSymbol.Kind, 'type') or SameText(lSymbol.Kind, 'type-alias') then
      AddSymbolToMap(fDeclarationsByName, lSymbol.Name, lSymbol);
    if SameText(lSymbol.SymbolClass, 'unit') or SameText(lSymbol.SymbolClass, 'unit-global') or
      (SameText(lSymbol.SymbolClass, 'external') and (Trim(lSymbol.TypeName) = '') and
      (Trim(lSymbol.UnitName) <> '')) then
    begin
      AddSymbolToMap(fUnitsAndGlobalsByName, lSymbol.Name, lSymbol);
      if (SameText(lSymbol.SymbolClass, 'unit') or
        SameText(lSymbol.SymbolClass, 'external')) and (Pos('.', lSymbol.Name) > 0) then
      begin
        lPrefixLength := Pos('.', lSymbol.Name);
        while lPrefixLength > 0 do
        begin
          AddSymbolToMap(fUnitsAndGlobalsByPrefix, Copy(lSymbol.Name, 1,
            lPrefixLength - 1), lSymbol);
          lNextDot := Pos('.', Copy(lSymbol.Name, lPrefixLength + 1, MaxInt));
          if lNextDot = 0 then
            Break;
          Inc(lPrefixLength, lNextDot);
        end;
      end;
    end;
  end;
end;

destructor TDelphiSemanticRemoveWithLookupIndexData.Destroy;
var
  lSymbols: TList<TDelphiSemanticInventorySymbol>;
begin
  for lSymbols in fDeclarationsByName.Values do
    lSymbols.Free;
  for lSymbols in fMembersByOwnerName.Values do
    lSymbols.Free;
  for lSymbols in fSymbolsByName.Values do
    lSymbols.Free;
  for lSymbols in fSymbolsByOwnerType.Values do
    lSymbols.Free;
  for lSymbols in fUnitsAndGlobalsByName.Values do
    lSymbols.Free;
  for lSymbols in fUnitsAndGlobalsByPrefix.Values do
    lSymbols.Free;
  fUnitsAndGlobalsByPrefix.Free;
  fUnitsAndGlobalsByName.Free;
  fSymbolsByOwnerType.Free;
  fSymbolsByName.Free;
  fRoutineSymbolsByName.Free;
  fRoutineMisses.Free;
  fPointerTargetMisses.Free;
  fPointerTargetByType.Free;
  fMemberMisses.Free;
  fMembersByOwnerName.Free;
  fDeclarationsByName.Free;
  inherited;
end;

procedure TDelphiSemanticRemoveWithLookupIndexData.CountLookup(const aHit: Boolean);
begin
  if aHit then
    Inc(fMetrics.HitCount)
  else
    Inc(fMetrics.MissCount);
end;

function TDelphiSemanticRemoveWithLookupIndexData.SymbolsFromMap(
  const aMap: TDictionary<string, TList<TDelphiSemanticInventorySymbol>>;
  const aKey: string; const aMisses: TDictionary<string, Byte>):
  TArray<TDelphiSemanticInventorySymbol>;
var
  lSymbols: TList<TDelphiSemanticInventorySymbol>;
begin
  if aMap.TryGetValue(aKey, lSymbols) then
  begin
    CountLookup(True);
    Inc(fActivityMetrics.ResultMaterializationCount);
    Inc(fActivityMetrics.MaterializedSymbolCount, lSymbols.Count);
    Exit(lSymbols.ToArray);
  end;
  if (aMisses <> nil) and aMisses.ContainsKey(aKey) then
  begin
    CountLookup(True);
    Exit(nil);
  end;
  if aMisses <> nil then
    aMisses.AddOrSetValue(aKey, 0);
  CountLookup(False);
  Result := nil;
end;

function TDelphiSemanticRemoveWithLookupIndexData.FindMembersByOwnerAndName(
  const aOwnerName, aName: string): TArray<TDelphiSemanticInventorySymbol>;
begin
  Result := SymbolsFromMap(fMembersByOwnerName, OwnerNameKey(aOwnerName, aName),
    fMemberMisses);
end;

function TDelphiSemanticRemoveWithLookupIndexData.FindRoutineSymbol(
  const aRoutineName, aName: string;
  out aSymbol: TDelphiSemanticInventorySymbol): Boolean;
var
  lKey: string;
begin
  lKey := OwnerNameKey(aRoutineName, aName);
  if fRoutineSymbolsByName.TryGetValue(lKey, aSymbol) then
  begin
    CountLookup(True);
    Exit(True);
  end;
  if fRoutineMisses.ContainsKey(lKey) then
  begin
    aSymbol := Default(TDelphiSemanticInventorySymbol);
    CountLookup(True);
    Exit(False);
  end;
  fRoutineMisses.AddOrSetValue(lKey, 0);
  aSymbol := Default(TDelphiSemanticInventorySymbol);
  CountLookup(False);
  Result := False;
end;

function TDelphiSemanticRemoveWithLookupIndexData.PointerTargetType(
  const aTypeName: string): string;
var
  lTypeName: string;
begin
  Result := '';
  lTypeName := Trim(aTypeName);
  if StartsText('^', lTypeName) then
    Exit(Trim(Copy(lTypeName, 2, MaxInt)));

  if fPointerTargetByType.TryGetValue(lTypeName, Result) then
  begin
    CountLookup(True);
    Exit;
  end;
  if fPointerTargetMisses.ContainsKey(lTypeName) then
  begin
    CountLookup(True);
    Exit;
  end;
  fPointerTargetMisses.AddOrSetValue(lTypeName, 0);
  CountLookup(False);
end;

function TDelphiSemanticRemoveWithLookupIndexData.FindDeclarationOrTypeAliasByName(
  const aName: string): TArray<TDelphiSemanticInventorySymbol>;
begin
  Result := SymbolsFromMap(fDeclarationsByName, aName, nil);
end;

function TDelphiSemanticRemoveWithLookupIndexData.FindUnitOrGlobalByName(
  const aName: string): TArray<TDelphiSemanticInventorySymbol>;
begin
  Result := SymbolsFromMap(fUnitsAndGlobalsByName, aName, nil);
end;

function TDelphiSemanticRemoveWithLookupIndexData.FindUnitOrGlobalByPrefix(
  const aName: string): TArray<TDelphiSemanticInventorySymbol>;
begin
  Result := SymbolsFromMap(fUnitsAndGlobalsByPrefix, aName, nil);
end;

function TDelphiSemanticRemoveWithLookupIndexData.FindSymbolsByName(
  const aName: string): TArray<TDelphiSemanticInventorySymbol>;
begin
  Result := SymbolsFromMap(fSymbolsByName, aName, nil);
end;

function TDelphiSemanticRemoveWithLookupIndexData.FindSymbolsByOwnerType(
  const aOwnerType: string): TArray<TDelphiSemanticInventorySymbol>;
begin
  Result := SymbolsFromMap(fSymbolsByOwnerType, aOwnerType, nil);
end;

function TDelphiSemanticRemoveWithLookupIndexData.Metrics:
  TDelphiSemanticRemoveWithLookupMetrics;
begin
  Result := fMetrics;
end;

function TDelphiSemanticRemoveWithLookupIndexData.ActivityMetrics:
  TDelphiSemanticRemoveWithLookupActivityMetrics;
begin
  Result := fActivityMetrics;
end;

class function TDelphiSemanticRemoveWithLookupIndex.Build(
  const aModels: TArray<TDelphiSemanticUnitModel>;
  const aSymbols: TArray<TDelphiSemanticInventorySymbol>):
  TDelphiSemanticRemoveWithLookupIndex;
var
  lData: TDelphiSemanticRemoveWithLookupIndexData;
  lStopwatch: TStopwatch;
begin
  Result := Default(TDelphiSemanticRemoveWithLookupIndex);
  lStopwatch := TStopwatch.StartNew;
  lData := TDelphiSemanticRemoveWithLookupIndexData.Create(aModels, aSymbols);
  lStopwatch.Stop;
  lData.fMetrics.BuildMilliseconds := lStopwatch.ElapsedMilliseconds;
  Result.fData := lData;
end;

function TDelphiSemanticRemoveWithLookupIndex.IsAvailable: Boolean;
begin
  Result := fData <> nil;
end;

function TDelphiSemanticRemoveWithLookupIndex.FindMembersByOwnerAndName(
  const aOwnerName, aName: string): TArray<TDelphiSemanticInventorySymbol>;
begin
  if fData = nil then
    Exit(nil);
  Result := fData.FindMembersByOwnerAndName(aOwnerName, aName);
end;

function TDelphiSemanticRemoveWithLookupIndex.FindRoutineSymbol(
  const aRoutineName, aName: string;
  out aSymbol: TDelphiSemanticInventorySymbol): Boolean;
begin
  if fData = nil then
  begin
    aSymbol := Default(TDelphiSemanticInventorySymbol);
    Exit(False);
  end;
  Result := fData.FindRoutineSymbol(aRoutineName, aName, aSymbol);
end;

function TDelphiSemanticRemoveWithLookupIndex.PointerTargetType(
  const aTypeName: string): string;
begin
  if fData = nil then
    Exit('');
  Result := fData.PointerTargetType(aTypeName);
end;

function TDelphiSemanticRemoveWithLookupIndex.FindDeclarationOrTypeAliasByName(
  const aName: string): TArray<TDelphiSemanticInventorySymbol>;
begin
  if fData = nil then
    Exit(nil);
  Result := fData.FindDeclarationOrTypeAliasByName(aName);
end;

function TDelphiSemanticRemoveWithLookupIndex.FindUnitOrGlobalByName(
  const aName: string): TArray<TDelphiSemanticInventorySymbol>;
begin
  if fData = nil then
    Exit(nil);
  Result := fData.FindUnitOrGlobalByName(aName);
end;

function TDelphiSemanticRemoveWithLookupIndex.FindUnitOrGlobalByPrefix(
  const aName: string): TArray<TDelphiSemanticInventorySymbol>;
begin
  if fData = nil then
    Exit(nil);
  Result := fData.FindUnitOrGlobalByPrefix(aName);
end;

function TDelphiSemanticRemoveWithLookupIndex.FindSymbolsByName(
  const aName: string): TArray<TDelphiSemanticInventorySymbol>;
begin
  if fData = nil then
    Exit(nil);
  Result := fData.FindSymbolsByName(aName);
end;

function TDelphiSemanticRemoveWithLookupIndex.FindSymbolsByOwnerType(
  const aOwnerType: string): TArray<TDelphiSemanticInventorySymbol>;
begin
  if fData = nil then
    Exit(nil);
  Result := fData.FindSymbolsByOwnerType(aOwnerType);
end;

function TDelphiSemanticRemoveWithLookupIndex.Metrics:
  TDelphiSemanticRemoveWithLookupMetrics;
begin
  if fData = nil then
    Exit(Default(TDelphiSemanticRemoveWithLookupMetrics));
  Result := fData.Metrics;
end;

function TDelphiSemanticRemoveWithLookupIndex.ActivityMetrics:
  TDelphiSemanticRemoveWithLookupActivityMetrics;
var
  lActivityData: IDelphiSemanticRemoveWithLookupActivityData;
begin
  if not Supports(fData, IDelphiSemanticRemoveWithLookupActivityData,
    lActivityData) then
    Exit(Default(TDelphiSemanticRemoveWithLookupActivityMetrics));
  Result := lActivityData.ActivityMetrics;
end;

class function TWithBindingProjectMemberIndex.Key(const aUnitName, aOwnerName,
  aName: string): string;
begin
  Result := aUnitName + #31 + aOwnerName + #31 + aName;
end;

class function TWithBindingProjectMemberIndex.KeyMemberName(const aKey: string): string;
var
  lFirstDelimiter: Integer;
  lSecondDelimiter: Integer;
begin
  lFirstDelimiter := Pos(#31, aKey);
  if lFirstDelimiter = 0 then
    Exit('');
  lSecondDelimiter := PosEx(#31, aKey, lFirstDelimiter + 1);
  if lSecondDelimiter = 0 then
    Exit('');
  Result := Copy(aKey, lSecondDelimiter + 1, MaxInt);
end;

class function TWithBindingProjectMemberIndex.KeyOwnerName(const aKey: string): string;
var
  lFirstDelimiter: Integer;
  lSecondDelimiter: Integer;
begin
  lFirstDelimiter := Pos(#31, aKey);
  if lFirstDelimiter = 0 then
    Exit('');
  lSecondDelimiter := PosEx(#31, aKey, lFirstDelimiter + 1);
  if lSecondDelimiter = 0 then
    Exit('');
  Result := Copy(aKey, lFirstDelimiter + 1, lSecondDelimiter - lFirstDelimiter - 1);
end;

class function TWithBindingProjectMemberIndex.KeyUnitName(const aKey: string): string;
var
  lDelimiter: Integer;
begin
  lDelimiter := Pos(#31, aKey);
  if lDelimiter = 0 then
    Exit('');
  Result := Copy(aKey, 1, lDelimiter - 1);
end;

class function TWithBindingProjectMemberIndex.MemberResult(
  const aMember: TDelphiSemanticMember): TDelphiSemanticResolveResult;
begin
  Result := Default(TDelphiSemanticResolveResult);
  Result.Found := True;
  Result.Authoritative := True;
  Result.Status := 'resolved';
  Result.Name := aMember.Name;
  Result.Kind := aMember.Kind;
  Result.TypeName := aMember.TypeName;
  Result.OwnerName := aMember.OwnerName;
  Result.Line := aMember.Line;
  Result.Column := aMember.Column;
end;

function CombineUnitUses(const aInterfaceUses, aImplementationUses: TArray<string>):
  TArray<string>;
var
  i: Integer;
  lIndex: Integer;
begin
  SetLength(Result, Length(aInterfaceUses) + Length(aImplementationUses));
  lIndex := 0;
  for i := 0 to High(aInterfaceUses) do
  begin
    Result[lIndex] := aInterfaceUses[i];
    Inc(lIndex);
  end;
  for i := 0 to High(aImplementationUses) do
  begin
    Result[lIndex] := aImplementationUses[i];
    Inc(lIndex);
  end;
end;

function BuildSyntheticWithBindingProjectInfo: TDelphiSemanticProjectInfo;
begin
  Result := Default(TDelphiSemanticProjectInfo);
  Result.ProjectName := 'WithBindingMemberIndexProject';
  Result.ContextFingerprint := 'with-binding-member-index';
end;

function NormalizeMemberLookupReasonCode(const aReasonCode: string): string;
begin
  if SameText(aReasonCode, 'MULTIPLE_DIRECT_MEMBER_CANDIDATES') then
    Exit('MULTIPLE_MEMBER_CANDIDATES');
  Result := aReasonCode;
end;

function ResolveResultFromMemberLookup(const aName: string;
  const aLookup: TDelphiSemanticMemberLookupResult;
  out aResult: TDelphiSemanticResolveResult): Boolean;
begin
  if aLookup.Found then
  begin
    aResult := Default(TDelphiSemanticResolveResult);
    aResult.Found := True;
    aResult.Authoritative := True;
    aResult.Status := 'resolved';
    aResult.Name := aLookup.Member.Name;
    aResult.Kind := aLookup.Member.Kind;
    aResult.TypeName := aLookup.Member.TypeName;
    aResult.OwnerName := aLookup.Member.OwnerName;
    aResult.Line := aLookup.Member.SourceRange.Line;
    aResult.Column := aLookup.Member.SourceRange.Column;
    Exit(True);
  end;

  if aLookup.Ambiguous or SameText(aLookup.Status, 'unsupported') then
  begin
    aResult := Default(TDelphiSemanticResolveResult);
    aResult.Status := aLookup.Status;
    aResult.Name := aName;
    aResult.ReasonCode := NormalizeMemberLookupReasonCode(aLookup.ReasonCode);
    aResult.Reason := aLookup.Reason;
    Exit(True);
  end;

  aResult := Default(TDelphiSemanticResolveResult);
  Result := False;
end;

procedure TWithBindingProjectMemberIndex.BuildDeclarationIndex;
var
  lCandidate: TIndexedDeclarationCandidate;
  lCandidates: TList<TIndexedDeclarationCandidate>;
  lDeclaration: TDelphiSemanticDeclaration;
  i: Integer;
  j: Integer;
begin
  fDeclarationCandidates := TObjectDictionary<string,
    TList<TIndexedDeclarationCandidate>>.Create([doOwnsValues],
    TFastCaseAwareComparer.OrdinalIgnoreCase);
  fDeclarationModels := TDictionary<string, TArray<TDelphiSemanticUnitModel>>.Create(
    TFastCaseAwareComparer.OrdinalIgnoreCase);
  for i := 0 to High(fModels) do
    for j := 0 to High(fModels[i].Declarations) do
    begin
      lDeclaration := fModels[i].Declarations[j];
      if not SameText(lDeclaration.SectionKind, 'interface') then
        Continue;
      if not fDeclarationCandidates.TryGetValue(lDeclaration.Name, lCandidates) then
      begin
        lCandidates := TList<TIndexedDeclarationCandidate>.Create;
        fDeclarationCandidates.Add(lDeclaration.Name, lCandidates);
      end;
      lCandidate.ModelIndex := i;
      lCandidate.DeclarationIndex := j;
      lCandidates.Add(lCandidate);
    end;
end;

function TWithBindingProjectMemberIndex.DeclarationModelsForName(const aName: string):
  TArray<TDelphiSemanticUnitModel>;
var
  lCandidate: TIndexedDeclarationCandidate;
  lCandidates: TList<TIndexedDeclarationCandidate>;
  i: Integer;
begin
  if fDeclarationModels.TryGetValue(aName, Result) then
    Exit;
  Result := nil;
  if fDeclarationCandidates.TryGetValue(aName, lCandidates) then
  begin
    SetLength(Result, lCandidates.Count);
    for i := 0 to lCandidates.Count - 1 do
    begin
      lCandidate := lCandidates[i];
      Result[i].UnitName := fModels[lCandidate.ModelIndex].UnitName;
      Result[i].Declarations :=
        [fModels[lCandidate.ModelIndex].Declarations[lCandidate.DeclarationIndex]];
    end;
  end;
  fDeclarationModels.Add(aName, Result);
end;

function TWithBindingProjectMemberIndex.ContextForName(
  const aContext: TDelphiSemanticResolveContext;
  const aName: string): TDelphiSemanticResolveContext;
var
  ch: Char;
begin
  Result := aContext;
  if (aContext.ConformanceLevel < 3) or (aName = '') or
    (Length(aContext.IndexedUnitModels) = 0) or
    (Pointer(aContext.IndexedUnitModels) <> Pointer(fModels)) then
    Exit;
  for ch in aName do
    if not CharInSet(ch, ['A'..'Z', 'a'..'z', '0'..'9', '_']) then
      Exit;
  // Keep the resolver authoritative; only its project declaration scan is narrowed.
  Result.IndexedUnitModels := DeclarationModelsForName(aName);
end;

procedure TWithBindingProjectMemberIndex.BuildCompilerIntrinsicIndex;
var
  lProfile: TDelphiSemanticCompilerProfile;
  lSymbol: TDelphiSemanticIntrinsicSymbol;
begin
  lProfile := TDelphiSemanticCompilerProfileBuilder.DefaultProfile('');
  fCompilerIntrinsics := TDictionary<string, TDelphiSemanticIntrinsicSymbol>.Create(
    TFastCaseAwareComparer.OrdinalIgnoreCase);
  for lSymbol in lProfile.IntrinsicSymbols do
    if MatchText(lSymbol.Kind, ['intrinsic-type', 'intrinsic-routine']) and
      SameText(lSymbol.OwnerName, 'compiler') then
      fCompilerIntrinsics.Add(lSymbol.Name, lSymbol);
end;

constructor TWithBindingProjectMemberIndex.Create(
  const aModels: TArray<TDelphiSemanticUnitModel>;
  const aGraph: TDelphiSemanticSemanticGraph;
  const aLookupIndex: TDelphiSemanticRemoveWithLookupIndex);
var
  lGraph: TDelphiSemanticSemanticGraph;
  lIndex: Integer;
  lMember: TDelphiSemanticMember;
  lModel: TDelphiSemanticUnitModel;
  lOwnGraph: Boolean;
begin
  inherited Create;
  try
    fModels := aModels;
    fLookupIndex := aLookupIndex;
    BuildDeclarationIndex;
    fByUnitOwnerName := TDictionary<string, TList<TBoundMemberResolution>>.Create(
      TFastCaseAwareComparer.OrdinalIgnoreCase);
    fDirectMembersByContextOwnerName := TDictionary<string,
      TList<TBoundMemberResolution>>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
    fMemberKeysByUnit := TDictionary<string, TList<string>>.Create(
      TFastCaseAwareComparer.OrdinalIgnoreCase);
    fSemanticMemberResultsByOwnerName := TDictionary<string,
      TBoundMemberResolution>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
    fVisibleUnitsByUnit := TDictionary<string, TArray<string>>.Create(
      TFastCaseAwareComparer.OrdinalIgnoreCase);
    lGraph := aGraph;
    lOwnGraph := False;
    if lGraph = nil then
    begin
      lGraph := TDelphiSemanticSemanticGraphBuilder.Build(BuildSyntheticWithBindingProjectInfo,
        aModels);
      lOwnGraph := True;
    end;
    try
      fTypeIndex := TDelphiSemanticTypeResolver.BuildIndex(lGraph);
      fSemanticMemberIndex := TDelphiSemanticMemberResolver.BuildIndex(lGraph, fTypeIndex);
      fSemanticMemberIndexAvailable := True;
    finally
      if lOwnGraph then
        lGraph.Free;
    end;
    SetLength(fUnitNames, Length(aModels));
    lIndex := 0;
    for lModel in aModels do
    begin
      fUnitNames[lIndex] := lModel.UnitName;
      Inc(lIndex);
      for lMember in lModel.Members do
        AddMember(lModel.UnitName, lMember);
      fVisibleUnitsByUnit.AddOrSetValue(lModel.UnitName,
        CombineUnitUses(lModel.InterfaceUses, lModel.ImplementationUses));
    end;
    BuildMemberSafetyDiagnostics;
    BuildContextMemberIndex;
  except
    ClearOwnedState;
    raise;
  end;
end;

procedure TWithBindingProjectMemberIndex.ClearOwnedState;
var
  lList: TList<TBoundMemberResolution>;
  lStringList: TList<string>;
begin
  FreeAndNil(fSafetyDeclarationsByName);
  FreeAndNil(fSafetyModelsByUnit);
  FreeAndNil(fSafetyProfileTypes);
  FreeAndNil(fCompilerIntrinsics);
  FreeAndNil(fDeclarationModels);
  FreeAndNil(fDeclarationCandidates);
  fModels := nil;
  FreeAndNil(fVisibleUnitsByUnit);
  if fMemberKeysByUnit <> nil then
    for lStringList in fMemberKeysByUnit.Values do
      lStringList.Free;
  FreeAndNil(fMemberKeysByUnit);
  FreeAndNil(fSemanticMemberResultsByOwnerName);
  if fDirectMembersByContextOwnerName <> nil then
    for lList in fDirectMembersByContextOwnerName.Values do
      lList.Free;
  FreeAndNil(fDirectMembersByContextOwnerName);
  if fByUnitOwnerName <> nil then
    for lList in fByUnitOwnerName.Values do
      lList.Free;
  FreeAndNil(fByUnitOwnerName);
end;

destructor TWithBindingProjectMemberIndex.Destroy;
begin
  ClearOwnedState;
  inherited;
end;

procedure TWithBindingProjectMemberIndex.AddContextMemberKey(
  const aContextUnitName, aMemberKey: string; const aOnlyOwnerMatchingSourceUnit: Boolean);
var
  lContextKey: string;
  lMemberName: string;
  lOwnerName: string;
  lSourceList: TList<TBoundMemberResolution>;
  lSourceResult: TBoundMemberResolution;
  lSourceUnitName: string;
  lTargetList: TList<TBoundMemberResolution>;
begin
  lSourceUnitName := KeyUnitName(aMemberKey);
  lOwnerName := KeyOwnerName(aMemberKey);
  lMemberName := KeyMemberName(aMemberKey);
  if aOnlyOwnerMatchingSourceUnit and not SameText(lOwnerName, lSourceUnitName) then
    Exit;

  lContextKey := Key(aContextUnitName, lOwnerName, lMemberName);
  if fDirectMembersByContextOwnerName.ContainsKey(lContextKey) then
    Exit;

  if not fByUnitOwnerName.TryGetValue(aMemberKey, lSourceList) then
    Exit;

  lTargetList := TList<TBoundMemberResolution>.Create;
  try
    for lSourceResult in lSourceList do
      lTargetList.Add(lSourceResult);
    fDirectMembersByContextOwnerName.Add(lContextKey, lTargetList);
  except
    lTargetList.Free;
    raise;
  end;
end;

procedure TWithBindingProjectMemberIndex.AddContextUnitMembers(
  const aContextUnitName, aSourceUnitName: string; const aOnlyOwnerMatchingSourceUnit: Boolean);
var
  lMemberKey: string;
  lMemberKeys: TList<string>;
begin
  if not fMemberKeysByUnit.TryGetValue(aSourceUnitName, lMemberKeys) then
    Exit;

  for lMemberKey in lMemberKeys do
    AddContextMemberKey(aContextUnitName, lMemberKey, aOnlyOwnerMatchingSourceUnit);
end;

procedure TWithBindingProjectMemberIndex.AddMember(const aUnitName: string;
  const aMember: TDelphiSemanticMember);
var
  lBound: TBoundMemberResolution;
  lKey: string;
  lOwner: TDelphiSemanticTypeLookupResult;
begin
  lKey := Key(aUnitName, aMember.OwnerName, aMember.Name);
  lBound := Default(TBoundMemberResolution);
  lBound.Value := MemberResult(aMember);
  lBound.DeclaringUnitName := aUnitName;
  if aMember.OwnerScopeId <> '' then
  begin
    lOwner := fTypeIndex.ResolveScopedName(aMember.OwnerName, aUnitName,
      aMember.OwnerScopeId, [], 'implementation');
    if lOwner.Found and (not lOwner.Ambiguous) and
      SameText(lOwner.Identity.OwnerScopeId, aMember.OwnerScopeId) and
      SameText(lOwner.Identity.SemanticSymbolId, aMember.OwnerSymbolId) then
      lBound.OwnerDeclaredId := lOwner.Identity.DeclaredId;
  end else begin
    lOwner := fTypeIndex.ResolveQualifiedName(aUnitName + '.' + aMember.OwnerName);
    if lOwner.Found and (not lOwner.Ambiguous) and
      SameText(lOwner.Identity.ScopeKind, 'unit') then
      lBound.OwnerDeclaredId := lOwner.Identity.DeclaredId;
  end;
  AddResultToMap(fByUnitOwnerName, lKey, lBound);
  AddMemberKey(aUnitName, lKey);
end;

procedure TWithBindingProjectMemberIndex.AddMemberKey(const aUnitName, aKey: string);
var
  lKeys: TList<string>;
begin
  if not fMemberKeysByUnit.TryGetValue(aUnitName, lKeys) then
  begin
    lKeys := TList<string>.Create;
    try
      fMemberKeysByUnit.Add(aUnitName, lKeys);
    except
      lKeys.Free;
      raise;
    end;
  end;
  lKeys.Add(aKey);
end;

class procedure TWithBindingProjectMemberIndex.AddResultToMap(
  const aMap: TDictionary<string, TList<TBoundMemberResolution>>;
  const aKey: string;
  const aResult: TBoundMemberResolution);
var
  lList: TList<TBoundMemberResolution>;
begin
  if not aMap.TryGetValue(aKey, lList) then
  begin
    lList := TList<TBoundMemberResolution>.Create;
    try
      aMap.Add(aKey, lList);
    except
      lList.Free;
      raise;
    end;
  end;
  lList.Add(aResult);
end;

procedure TWithBindingProjectMemberIndex.BuildContextMemberIndex;
var
  lContextUnitName: string;
  lSourceUnitName: string;
  lVisibleUnitName: string;
  lVisibleUnits: TArray<string>;
begin
  for lContextUnitName in fUnitNames do
  begin
    AddContextUnitMembers(lContextUnitName, lContextUnitName, False);
    if fVisibleUnitsByUnit.TryGetValue(lContextUnitName, lVisibleUnits) then
      for lVisibleUnitName in lVisibleUnits do
        if not SameText(lVisibleUnitName, lContextUnitName) then
          AddContextUnitMembers(lContextUnitName, lVisibleUnitName, False);
    for lSourceUnitName in fUnitNames do
      AddContextUnitMembers(lContextUnitName, lSourceUnitName, True);
  end;
end;

class function TWithBindingProjectMemberIndex.ResolveMemberList(const aOwnerName, aName: string;
  const aList: TList<TBoundMemberResolution>;
  out aResult: TBoundMemberResolution): Boolean;
begin
  if aList.Count > 1 then
  begin
    aResult := Default(TBoundMemberResolution);
    aResult.Value.Status := 'ambiguous';
    aResult.Value.Name := aName;
    aResult.Value.ReasonCode := 'MULTIPLE_MEMBER_CANDIDATES';
    aResult.Value.Reason := 'Multiple direct members named "' + aName + '" were found on ' +
      aOwnerName + '.';
    Exit(True);
  end;

  aResult := aList[0];
  Result := True;
end;

function TWithBindingProjectMemberIndex.TryResolveContextMember(
  const aContextUnitName, aOwnerName, aName: string;
  out aResult: TBoundMemberResolution): Boolean;
var
  lList: TList<TBoundMemberResolution>;
begin
  if not fDirectMembersByContextOwnerName.TryGetValue(Key(aContextUnitName, aOwnerName,
    aName), lList) then
  begin
    aResult := Default(TBoundMemberResolution);
    Exit(False);
  end;

  Result := ResolveMemberList(aOwnerName, aName, lList, aResult);
end;

class function TWithBindingProjectMemberIndex.ResolveResultIsUsable(
  const aResult: TDelphiSemanticResolveResult): Boolean;
begin
  Result := aResult.Found or SameText(aResult.Status, 'ambiguous') or
    SameText(aResult.Status, 'unsupported');
end;

function TWithBindingProjectMemberIndex.TryResolveUnitMember(const aUnitName, aOwnerName,
  aName: string; out aResult: TBoundMemberResolution): Boolean;
var
  lList: TList<TBoundMemberResolution>;
begin
  if not fByUnitOwnerName.TryGetValue(Key(aUnitName, aOwnerName, aName), lList) then
  begin
    aResult := Default(TBoundMemberResolution);
    Exit(False);
  end;

  Result := ResolveMemberList(aOwnerName, aName, lList, aResult);
end;

function TWithBindingProjectMemberIndex.TryResolveDirectMember(const aCurrentUnitName,
  aCurrentTypeName, aOwnerName, aName: string; const aAllowSemanticFallback: Boolean;
  out aResult: TDelphiSemanticResolveResult): Boolean;
var
  lBound: TBoundMemberResolution;
begin
  Result := TryResolveDirectMember(aCurrentUnitName, aCurrentTypeName, aOwnerName,
    aName, aAllowSemanticFallback, lBound);
  aResult := lBound.Value;
end;

function TWithBindingProjectMemberIndex.TryResolveDirectMember(const aCurrentUnitName,
  aCurrentTypeName, aOwnerName, aName: string; const aAllowSemanticFallback: Boolean;
  out aResult: TBoundMemberResolution): Boolean;
begin
  Result := TryResolveDirectMember(aCurrentUnitName, aCurrentTypeName, aOwnerName,
    aName, aAllowSemanticFallback, '', Default(TDelphiSemanticTypeIdentity), aResult);
end;

function TWithBindingProjectMemberIndex.TryResolveDirectMember(const aCurrentUnitName,
  aCurrentTypeName, aOwnerName, aName: string; const aAllowSemanticFallback: Boolean;
  const aCurrentFileName: string; const aOwnerIdentity: TDelphiSemanticTypeIdentity;
  out aResult: TBoundMemberResolution): Boolean;
var
  lBinding: TDelphiSemanticWithBinding;
  lContext: TDelphiSemanticMemberLookupContext;
  lIdentity: TDelphiSemanticTypeIdentity;
  lLineage: TArray<TDelphiSemanticTypeIdentity>;
  lLookup: TDelphiSemanticMemberLookupResult;
  lTypeLookup: TDelphiSemanticTypeLookupResult;
  lSemanticKey, lOwnerProbe: string;
  lIdentityVerified, lOwnerVerified, lQualifiedProbe: Boolean;
begin
  lIdentityVerified := (aOwnerIdentity.UnitName <> '') and
    (aOwnerIdentity.Name <> '') and SameText(aOwnerIdentity.ScopeKind, 'unit');
  if TryResolveContextMember(aCurrentUnitName, aOwnerName, aName, aResult) then
  begin
    // Ambiguity and existing refusals retain the original lookup vocabulary.
    if (not lIdentityVerified) or (not aResult.Value.Found) then
      Exit(True);
    lBinding := Default(TDelphiSemanticWithBinding);
    lBinding.UnitName := aCurrentUnitName;
    lBinding.FileName := aCurrentFileName;
    TryBuildMemberSafetyLineage(lBinding, aOwnerName, aOwnerIdentity, lLineage);
    lOwnerVerified := False;
    for lIdentity in lLineage do
      if (aResult.OwnerDeclaredId.Value <> '') and
        SameText(lIdentity.DeclaredId.Value, aResult.OwnerDeclaredId.Value) then
        lOwnerVerified := True;
    if lOwnerVerified then
      Exit(True);
  end;
  aResult := Default(TBoundMemberResolution);
  if not aAllowSemanticFallback then
    Exit(False);

  lSemanticKey := Key(aCurrentUnitName + #30 + aCurrentTypeName + #30 +
    aOwnerIdentity.DeclaredId.Value, aOwnerName, aName);
  if fSemanticMemberResultsByOwnerName.TryGetValue(lSemanticKey, aResult) then
    Exit(ResolveResultIsUsable(aResult.Value));
  if fSemanticMemberIndexAvailable then
  begin
    lContext := Default(TDelphiSemanticMemberLookupContext);
    lContext.CallerUnitName := aCurrentUnitName;
    lContext.CurrentTypeName := aCurrentTypeName;
    lContext.InstanceContext := True;
    lOwnerProbe := aOwnerName;
    lQualifiedProbe := False;
    if lIdentityVerified then
    begin
      lTypeLookup := fTypeIndex.ResolveQualifiedName(aOwnerIdentity.UnitName + '.' +
        aOwnerIdentity.Name);
      if lTypeLookup.Found and (not lTypeLookup.Ambiguous) and
        (aOwnerIdentity.DeclaredId.Value <> '') and
        SameText(lTypeLookup.Identity.DeclaredId.Value, aOwnerIdentity.DeclaredId.Value) then
      begin
        lOwnerProbe := aOwnerIdentity.UnitName + '.' + aOwnerIdentity.Name;
        lQualifiedProbe := True;
      end;
    end;
    lLookup := fSemanticMemberIndex.ResolveMember(lContext, lOwnerProbe, aName);
    // Helpers and inherited results are intentionally outside this direct-owner filter.
    if lIdentityVerified and (not lQualifiedProbe) and lLookup.Found and
      (not MatchText(lLookup.Status, ['inherited', 'helper'])) and
      (not SameText(lLookup.Member.UnitName, aOwnerIdentity.UnitName)) and
      SameText(Copy(lLookup.Member.OwnerName, LastDelimiter('.', lLookup.Member.OwnerName) + 1,
      MaxInt), Copy(aOwnerIdentity.Name, LastDelimiter('.', aOwnerIdentity.Name) + 1, MaxInt)) then
    begin
      fSemanticMemberResultsByOwnerName.AddOrSetValue(lSemanticKey, aResult);
      Exit(False);
    end;
    if ResolveResultFromMemberLookup(aName, lLookup, aResult.Value) then
    begin
      if lLookup.Found then
        aResult.DeclaringUnitName := lLookup.Member.UnitName;
      fSemanticMemberResultsByOwnerName.AddOrSetValue(lSemanticKey, aResult);
      Exit(True);
    end;
  end;
  aResult := Default(TBoundMemberResolution);
  fSemanticMemberResultsByOwnerName.AddOrSetValue(lSemanticKey, aResult);
  Result := False;
end;

function RoutineLocalTypeHasOnlyDirectMembers(
  const aIdentity: TDelphiSemanticTypeIdentity): Boolean;
begin
  Result := SameText(aIdentity.Kind, 'type') and (aIdentity.BaseTypeName = '') and
    (aIdentity.HelperTargetName = '') and
    MatchText(aIdentity.UnderlyingName, ['record', 'packed record']);
end;

function TWithBindingProjectMemberIndex.TryResolveRoutineLocalMember(
  const aOwnerIdentity: TDelphiSemanticTypeIdentity; const aCurrentTypeName, aName: string;
  out aResult: TBoundMemberResolution): Boolean;
var
  lBinding: TDelphiSemanticWithBinding;
  lContext: TDelphiSemanticMemberLookupContext;
  lIdentity: TDelphiSemanticTypeIdentity;
  lLineage: TArray<TDelphiSemanticTypeIdentity>;
  lLookup: TDelphiSemanticMemberLookupResult;
  lModel: TDelphiSemanticUnitModel;
  lOwnerVerified: Boolean;
  lSelector: TDelphiSemanticWithSelectorBinding;
  lValue: TDelphiSemanticResolveResult;
  lVerifiedIdentity: TDelphiSemanticTypeIdentity;
begin
  // A routine-local type is identified only by its declaration. An owner-name
  // probe would also see same-named types of other routines or of the unit.
  if (aOwnerIdentity.DeclaredId.Value = '') or (not fSemanticMemberIndexAvailable) then
  begin
    aResult := Default(TBoundMemberResolution);
    aResult.Value.Status := 'unsupported';
    aResult.Value.Name := aName;
    aResult.Value.ReasonCode := 'ROUTINE_OWNER_IDENTITY_MISSING';
    aResult.Value.Reason := 'The routine-local receiver type has no declaration identity.';
    Exit(True);
  end;
  if SameText(aOwnerIdentity.Kind, 'type-alias') then
  begin
    // DS-701: finalized aliases own no direct fields. Resolve through the
    // source-proven target lineage, retaining access checks for unit types.
    aResult := Default(TBoundMemberResolution);
    aResult.Value.Status := 'unsupported';
    aResult.Value.Name := aName;
    aResult.Value.ReasonCode := 'ROUTINE_OWNER_INHERITED_MEMBERS_UNVERIFIED';
    aResult.Value.Reason := 'The routine-local alias target members are not verified.';
    if (aOwnerIdentity.CanonicalId.Value = '') or
      (aOwnerIdentity.UnderlyingId.Value = '') or
      (not TrySafetyDeclarationModel(aOwnerIdentity, lModel)) then
      Exit(True);
    lBinding := Default(TDelphiSemanticWithBinding);
    lBinding.UnitName := lModel.UnitName;
    lBinding.FileName := lModel.FileName;
    if not TryBuildMemberSafetyLineage(lBinding, aOwnerIdentity.Name,
      aOwnerIdentity, lLineage) then
      Exit(True);
    lContext := Default(TDelphiSemanticMemberLookupContext);
    lContext.CallerUnitName := aOwnerIdentity.UnitName;
    lContext.CurrentTypeName := aCurrentTypeName;
    lContext.InstanceContext := True;
    for lIdentity in lLineage do
    begin
      if SameText(lIdentity.Kind, 'type-alias') then
        Continue;
      if SameText(lIdentity.ScopeKind, 'routine') then
        lLookup := fSemanticMemberIndex.ResolveDirectMemberByOwnerId(
          lIdentity.DeclaredId, aName)
      else
        lLookup := fSemanticMemberIndex.ResolveMember(lContext,
          lIdentity.UnitName + '.' + lIdentity.Name, aName);
      if lLookup.Found then
      begin
        lOwnerVerified := False;
        for lVerifiedIdentity in lLineage do
          if ((lLookup.Member.OwnerDeclaredId.Value <> '') and
            SameText(lVerifiedIdentity.DeclaredId.Value,
              lLookup.Member.OwnerDeclaredId.Value)) or
            ((lLookup.Member.OwnerDeclaredId.Value = '') and
            SameText(lVerifiedIdentity.ScopeKind, 'unit') and
            SameText(lVerifiedIdentity.UnitName, lLookup.Member.UnitName) and
            SameText(lVerifiedIdentity.Name, lLookup.Member.OwnerName)) then
          begin
            lOwnerVerified := True;
            Break;
          end;
        if not lOwnerVerified then
          Exit(True);
      end;
      if ResolveResultFromMemberLookup(aName, lLookup, lValue) then
      begin
        aResult.Value := lValue;
        if lLookup.Found then
          aResult.DeclaringUnitName := lLookup.Member.UnitName;
        Exit(True);
      end;
      // A failed access or overload check is not proof that the member is
      // absent. It must shield same-named declarations farther out.
      if (not SameText(lLookup.Status, 'unresolved')) or
        (not SameText(lLookup.ReasonCode, 'DIRECT_MEMBER_NOT_FOUND')) then
      begin
        aResult.Value.ReasonCode := NormalizeMemberLookupReasonCode(lLookup.ReasonCode);
        aResult.Value.Reason := lLookup.Reason;
        Exit(True);
      end;
    end;
    lSelector := Default(TDelphiSemanticWithSelectorBinding);
    lSelector.TypeName := aOwnerIdentity.Name;
    lSelector.TypeIdentity := aOwnerIdentity;
    if ReceiverMemberAbsenceIsVerified(lModel, lSelector, aName) then
    begin
      aResult := Default(TBoundMemberResolution);
      Exit(False);
    end;
    Exit(True);
  end;
  lLookup := fSemanticMemberIndex.ResolveDirectMemberByOwnerId(aOwnerIdentity.DeclaredId,
    aName);
  Result := ResolveResultFromMemberLookup(aName, lLookup, lValue);
  aResult := Default(TBoundMemberResolution);
  aResult.Value := lValue;
  if Result and lLookup.Found then
    aResult.DeclaringUnitName := lLookup.Member.UnitName;
  // The owner-ID lookup sees direct members only. A direct miss proves "not a
  // member" only for a plain local record: Delphi rejects local class,
  // interface, object and helper types (E2059) and local record methods
  // (E2433). Any other local type may inherit, so we refuse the name.
  if (not Result) and RoutineLocalTypeHasOnlyDirectMembers(aOwnerIdentity) and
    LineageHasActivityFact([aOwnerIdentity]) then
  begin
    aResult.Value.Status := 'unsupported';
    aResult.Value.Name := aName;
    aResult.Value.ReasonCode := 'OWNER_INHERITED_MEMBERS_UNVERIFIED';
    aResult.Value.OwnerName := aOwnerIdentity.Name;
    aResult.Value.Reason := 'The routine-local receiver member activity is unverified.';
    Exit(True);
  end;
  if (not Result) and (not RoutineLocalTypeHasOnlyDirectMembers(aOwnerIdentity)) then
  begin
    aResult := Default(TBoundMemberResolution);
    aResult.Value.Status := 'unsupported';
    aResult.Value.Name := aName;
    aResult.Value.ReasonCode := 'ROUTINE_OWNER_INHERITED_MEMBERS_UNVERIFIED';
    aResult.Value.Reason := 'Members the routine-local receiver type may inherit are not verified.';
    Result := True;
  end;
end;

function ReferenceTokenIsEscaped(const aText: string; const aOffset: Integer): Boolean;
begin
  Result := (aOffset > 1) and (aOffset <= Length(aText)) and
    (aText[aOffset - 1] = '&');
end;

function IsBinderKeyword(const aName: string): Boolean;
begin
  Result := MatchText(aName, ['and', 'array', 'as', 'begin', 'case', 'class', 'const',
    'constructor', 'destructor', 'div', 'do', 'downto', 'else', 'end', 'except',
    'exit', 'false', 'finally', 'for', 'function', 'if', 'implementation', 'in',
    'inherited', 'interface', 'is', 'mod', 'nil', 'not', 'of', 'on', 'or', 'out',
    'procedure', 'program', 'property', 'record', 'repeat', 'result', 'self',
    'set', 'shl', 'shr', 'then', 'to', 'true', 'try', 'type', 'unit', 'until',
    'uses', 'var', 'while', 'with', 'xor']);
end;

function IsSelectorName(const aSelectors: TArray<TDelphiSemanticWithSelectorBinding>;
  const aName: string): Boolean;
var
  lSelector: TDelphiSemanticWithSelectorBinding;
begin
  for lSelector in aSelectors do
    if SameText(lSelector.SelectorText, aName) then
      Exit(True);

  Result := False;
end;

function SanitizeBodyText(const aText: string): string;
  procedure BlankAt(const aIndex: Integer);
  begin
    if not CharInSet(Result[aIndex], [#10, #13]) then
      Result[aIndex] := ' ';
  end;

var
  i: Integer;
begin
  Result := aText;
  i := 1;
  while i <= Length(Result) do
  begin
    if aText[i] = '''' then
    begin
      BlankAt(i);
      Inc(i);
      while i <= Length(Result) do
      begin
        BlankAt(i);
        if aText[i] = '''' then
        begin
          if (i < Length(aText)) and (aText[i + 1] = '''') then
          begin
            Inc(i);
            BlankAt(i);
          end else
            Break;
        end;
        Inc(i);
      end;
    end else if (aText[i] = '/') and (i < Length(aText)) and (aText[i + 1] = '/') then
    begin
      while (i <= Length(Result)) and not CharInSet(Result[i], [#10, #13]) do
      begin
        BlankAt(i);
        Inc(i);
      end;
      Continue;
    end else if aText[i] = '{' then
    begin
      BlankAt(i);
      Inc(i);
      while i <= Length(Result) do
      begin
        BlankAt(i);
        if aText[i] = '}' then
          Break;
        Inc(i);
      end;
    end else if (aText[i] = '(') and (i < Length(aText)) and (aText[i + 1] = '*') then
    begin
      BlankAt(i);
      Inc(i);
      BlankAt(i);
      Inc(i);
      while i <= Length(Result) do
      begin
        BlankAt(i);
        if (aText[i] = '*') and (i < Length(aText)) and (aText[i + 1] = ')') then
        begin
          Inc(i);
          BlankAt(i);
          Break;
        end;
        Inc(i);
      end;
    end;
    Inc(i);
  end;
end;

function ExtractWithBodyText(const aStatement: TDelphiSemanticWithStatement;
  const aAllStatements: TArray<TDelphiSemanticWithStatement>; const aStatementIndex: Integer):
  string;
var
  i: Integer;
  lMatch: TMatch;

  function BlankTextPreservingLines(const aText: string): string;
  var
    j: Integer;
  begin
    Result := aText;
    for j := 1 to Length(Result) do
      if not CharInSet(Result[j], [#10, #13]) then
        Result[j] := ' ';
  end;

begin
  lMatch := TRegEx.Match(aStatement.Text, '(?<!&)\bdo\b(.*)$', [roIgnoreCase, roSingleLine]);
  if lMatch.Success then
    Result := lMatch.Groups[1].Value
  else
    Result := aStatement.Text;
  for i := Succ(aStatementIndex) to High(aAllStatements) do
    if Pos(aAllStatements[i].Text, Result) > 0 then
      Result := StringReplace(Result, aAllStatements[i].Text,
        BlankTextPreservingLines(aAllStatements[i].Text), []);
  Result := SanitizeBodyText(Result);
end;

function CallerTypeNameFromRoutineName(const aRoutineName: string): string; forward;

function CallerTypeNameForRoutineContext(const aModel: TDelphiSemanticUnitModel;
  const aRoutineName: string; const aParentRoutineNames: TArray<string>;
  const aLine: Integer): string; forward;

function RoutineLookupNameForRoutineContext(const aModel: TDelphiSemanticUnitModel;
  const aRoutineName: string; const aLine: Integer): string; forward;

function ReceiverMemberCachePrefix(const aUnitName, aCurrentTypeName,
  aRoutineName: string; const aLine, aColumn: Integer;
  const aSelectors: TArray<TDelphiSemanticWithSelectorBinding>): string; forward;

function TryResolveReceiverMember(const aModel: TDelphiSemanticUnitModel;
  const aProjectModels: TArray<TDelphiSemanticUnitModel>;
  const aSelectors: TArray<TDelphiSemanticWithSelectorBinding>;
  const aCurrentTypeName, aMemberCachePrefix, aName: string;
  const aProjectMemberIndex: TWithBindingProjectMemberIndex;
  const aMemberCache: TDictionary<string, TBoundMemberResolution>;
  out aResult: TDelphiSemanticResolveResult): Boolean; overload; forward;

function TryResolveReceiverMember(const aModel: TDelphiSemanticUnitModel;
  const aProjectModels: TArray<TDelphiSemanticUnitModel>;
  const aSelectors: TArray<TDelphiSemanticWithSelectorBinding>;
  const aCurrentTypeName, aMemberCachePrefix, aName: string;
  const aProjectMemberIndex: TWithBindingProjectMemberIndex;
  const aMemberCache: TDictionary<string, TBoundMemberResolution>;
  out aResult: TBoundMemberResolution): Boolean; overload; forward;

function SelectorDereferencesAfterIndex(const aSelectorText: string;
  const aBracketPos: Integer): Boolean;
var
  lCloseBracketPos: Integer;
  lDereferencePos: Integer;
  lDotPos: Integer;
begin
  lCloseBracketPos := PosEx(']', aSelectorText, aBracketPos + 1);
  if lCloseBracketPos = 0 then
    Exit(False);

  lDereferencePos := PosEx('^', aSelectorText, lCloseBracketPos + 1);
  if lDereferencePos = 0 then
    Exit(False);

  lDotPos := PosEx('.', aSelectorText, lCloseBracketPos + 1);
  Result := (lDotPos = 0) or (lDereferencePos < lDotPos);
end;

function TypeHasDefaultIndexedProperty(const aModel: TDelphiSemanticUnitModel;
  const aTypeName: string): Boolean;
var
  lMember: TDelphiSemanticMember;
begin
  for lMember in aModel.Members do
    if SameText(lMember.OwnerName, aTypeName) and SameText(lMember.Kind, 'property') and
      lMember.IsIndexed and lMember.IsDefault then
      Exit(True);

  Result := False;
end;

function ResolveNameThroughWithBindingAuthority(const aModel: TDelphiSemanticUnitModel;
  const aContext: TDelphiSemanticResolveContext; const aName: string):
  TDelphiSemanticResolveResult; overload;
begin
  // Compatibility adapter for model-array name resolution while WithBinding moves to one authority.
  Result := TDelphiSemanticResolver.ResolveName(aModel, aContext, aName);
end;

function ResolveNameThroughWithBindingAuthority(const aModel: TDelphiSemanticUnitModel;
  const aContext: TDelphiSemanticResolveContext; const aName: string;
  out aFinalModel: TDelphiSemanticUnitModel; out aFinalSectionKind: string):
  TDelphiSemanticResolveResult; overload;
begin
  // The same adapter also reports the unit model and section that declare the final
  // receiver type, so selector bindings keep their source-proven receiver identity.
  Result := ResolveNameWithFinalTypeOrigin(aModel, aContext, aName, aFinalModel,
    aFinalSectionKind);
end;

function SelectorPrefixUsesProperty(const aModel: TDelphiSemanticUnitModel;
  const aContext: TDelphiSemanticResolveContext; const aSelectorPrefix: string;
  const aCheckDefaultProperty: Boolean): Boolean;
var
  lResult: TDelphiSemanticResolveResult;
begin
  lResult := ResolveNameThroughWithBindingAuthority(aModel, aContext, aSelectorPrefix);
  Result := SameText(lResult.Kind, 'property') or
    (aCheckDefaultProperty and lResult.Found and TypeHasDefaultIndexedProperty(aModel,
    lResult.TypeName));
end;

function SelectorUsesUnsafeProperty(const aModel: TDelphiSemanticUnitModel;
  const aContext: TDelphiSemanticResolveContext; const aSelectorText: string): Boolean;
var
  lBracketPos: Integer;
  lPrefix: string;
begin
  lBracketPos := Pos('[', aSelectorText);
  if lBracketPos = 0 then
    Exit(SelectorPrefixUsesProperty(aModel, aContext, aSelectorText, False));

  while lBracketPos > 0 do
  begin
    if not SelectorDereferencesAfterIndex(aSelectorText, lBracketPos) then
    begin
      lPrefix := Trim(Copy(aSelectorText, 1, lBracketPos - 1));
      if (lPrefix <> '') and SelectorPrefixUsesProperty(aModel, aContext, lPrefix, True) then
        Exit(True);
    end;
    lBracketPos := PosEx('[', aSelectorText, lBracketPos + 1);
  end;

  Result := False;
end;

procedure MarkPropertySelectorUnsupported(const aSelectorText: string;
  var aResult: TDelphiSemanticResolveResult);
begin
  aResult := Default(TDelphiSemanticResolveResult);
  aResult.Status := 'unsupported';
  aResult.ReasonCode := 'PROPERTY_SELECTOR_UNSUPPORTED';
  aResult.Reason := 'Property selectors are not safe remove-with receivers.';
  aResult.Name := aSelectorText;
  aResult.Kind := 'property';
end;

function RoutineScopeAtLine(const aModel: TDelphiSemanticUnitModel;
  const aLine: Integer): string;
var
  lBestLine: Integer;
  lRoutine: TDelphiSemanticRoutine;
begin
  Result := '';
  lBestLine := 0;
  for lRoutine in aModel.Routines do
    if (lRoutine.Line < aLine) and (lRoutine.EndLine >= aLine) and
      (lRoutine.Line > lBestLine) then
    begin
      lBestLine := lRoutine.Line;
      Result := lRoutine.ScopeId;
    end;
end;

function ScopeEncloses(const aScope, aChildScope: string): Boolean;
begin
  Result := (aScope <> '') and (SameText(aScope, aChildScope) or
    StartsText(aScope + '/', aChildScope));
end;

function PointerCastNameHasLexicalShadow(const aModel: TDelphiSemanticUnitModel;
  const aName, aScope: string; const aLine: Integer): Boolean;
var
  lLocal: TDelphiSemanticLocal;
  lParameter: TDelphiSemanticParameter;
  lRoutine: TDelphiSemanticRoutine;
begin
  for lRoutine in aModel.Routines do
  begin
    if SameText(lRoutine.Name, aName) and (lRoutine.Line < aLine) and
      ((lRoutine.ParentScopeId = '') or ScopeEncloses(lRoutine.ParentScopeId, aScope)) then
      Exit(True);
    if ScopeEncloses(lRoutine.ScopeId, aScope) then
      for lParameter in lRoutine.Parameters do
        if SameText(lParameter.Name, aName) then
          Exit(True);
  end;
  for lLocal in aModel.Locals do
    if SameText(lLocal.Name, aName) and (lLocal.Line < aLine) and
      ScopeEncloses(lLocal.RoutineScopeId, aScope) then
      Exit(True);
  Result := False;
end;

function TWithBindingProjectMemberIndex.TryResolvePointerCastType(
  const aModel: TDelphiSemanticUnitModel; const aName: string;
  const aLine: Integer; out aTypeName: string): Boolean;
var
  lAlias: TDelphiSemanticTypeLookupResult;
  lAliasModel: TDelphiSemanticUnitModel;
  lCapture: TDelphiSemanticTypeLookupResult;
  lDeclaration: TDelphiSemanticDeclaration;
  lScope: string;
  lSymbol: TDelphiSemanticInventorySymbol;
  lSymbolScope: string;
  lTarget: TDelphiSemanticTypeLookupResult;
  lTargetName: string;
  lVisibleUnits: TArray<string>;
begin
  Result := False;
  aTypeName := '';
  lScope := RoutineScopeAtLine(aModel, aLine);
  if PointerCastNameHasLexicalShadow(aModel, aName, lScope, aLine) then
    Exit;
  fVisibleUnitsByUnit.TryGetValue(aModel.UnitName, lVisibleUnits);
  lAlias := fTypeIndex.ResolveVisibleName(aName, aModel.UnitName,
    lVisibleUnits, 'implementation');
  if (not lAlias.Found) or (not SameText(lAlias.Identity.Kind, 'type-alias')) then
    Exit;
  for lSymbol in fLookupIndex.FindSymbolsByName(aName) do
    if (not SameText(lSymbol.FileName, aModel.FileName)) and
      MatchText(lSymbol.UnitName, lVisibleUnits) and
      SameText(lSymbol.SectionKind, 'interface') and
      (SameText(lSymbol.SymbolClass, 'declaration') or
      SameText(lSymbol.SymbolClass, 'unit-global')) and
      (not SameText(lSymbol.Kind, 'type')) and
      (not SameText(lSymbol.Kind, 'type-alias')) then
      Exit;
  for lAliasModel in fModels do
  begin
    if not SameText(lAliasModel.UnitName, lAlias.Identity.UnitName) then
      Continue;
    for lDeclaration in lAliasModel.Declarations do
    begin
      if (lDeclaration.Line <> lAlias.Identity.SourceRange.Line) or
        (lDeclaration.Column <> lAlias.Identity.SourceRange.Column) then
        Continue;
      // Only a direct source pointer declaration establishes storage identity.
      if RoutineScopeAtLine(lAliasModel, lDeclaration.Line) <> '' then
        Exit;
      lTargetName := Trim(lDeclaration.TypeName);
      if not StartsText('^', lTargetName) then
        Exit;
      lTargetName := Trim(Copy(lTargetName, 2, MaxInt));
      if not TRegEx.IsMatch(lTargetName, '^[A-Za-z_][A-Za-z0-9_]*$') then
        Exit;
      lTarget := fTypeIndex.ResolveVisibleName(lTargetName, lAliasModel.UnitName,
        CombineUnitUses(lAliasModel.InterfaceUses, lAliasModel.ImplementationUses),
        lDeclaration.SectionKind);
      if (not lTarget.Found) or ((not SameText(lTarget.Identity.Kind, 'type')) or
        (not SameText(lTarget.Identity.CanonicalName, 'record'))) then
        Exit;
      lCapture := fTypeIndex.ResolveVisibleName(lTargetName, aModel.UnitName,
        lVisibleUnits, 'implementation');
      if (not lCapture.Found) or
        (lCapture.Identity.DeclaredId.Value <> lTarget.Identity.DeclaredId.Value) then
        Exit;
      // Fast models can omit local types. The existing expanded inventory retains them.
      for lSymbol in fLookupIndex.FindSymbolsByName(aName) +
        fLookupIndex.FindSymbolsByName(lTargetName) do
      begin
        if not SameText(lSymbol.FileName, aModel.FileName) then
          Continue;
        if lSymbol.Line > aLine then
          Continue;
        lSymbolScope := RoutineScopeAtLine(aModel, lSymbol.Line);
        if ScopeEncloses(lSymbolScope, lScope) then
          Exit;
        if (lSymbolScope = '') and SameText(lSymbol.Name, aName) and
          ((lSymbol.Line <> lAlias.Identity.SourceRange.Line) or
          (lSymbol.Column <> lAlias.Identity.SourceRange.Column) or
          (not SameText(lSymbol.FileName, lAlias.Identity.SourceRange.FileName))) then
          Exit;
      end;
      aTypeName := lTargetName;
      Exit(True);
    end;
  end;
end;

// aModel must be the model that declares the resolved symbol, not the model of the
// selector's final type. Returns the scope in which the declared type text resolves,
// that text, and for a parameter its own routine scope, whose local types the
// parameter's type can never name.
function TryDeclarationScope(const aModel: TDelphiSemanticUnitModel;
  const aResolved: TDelphiSemanticResolveResult; out aScopeId, aDeclaredTypeName,
  aOwnRoutineScopeId: string): Boolean;
var
  lDeclaration: TDelphiSemanticDeclaration;
  lLocal: TDelphiSemanticLocal;
  lMatches: Integer;
  lMember: TDelphiSemanticMember;
  lParameter: TDelphiSemanticParameter;
  lRoutine: TDelphiSemanticRoutine;
begin
  aScopeId := '';
  aDeclaredTypeName := '';
  aOwnRoutineScopeId := '';
  if not MatchText(aResolved.Kind, ['local', 'parameter', 'field', 'member',
    'property']) then
    Exit(True);
  lMatches := 0;
  if SameText(aResolved.Kind, 'local') then
  begin
    for lLocal in aModel.Locals do
      if SameText(lLocal.Name, aResolved.Name) and
        (lLocal.Line = aResolved.Line) and (lLocal.Column = aResolved.Column) and
        (lLocal.RoutineScopeId <> '') then
      begin
        Inc(lMatches);
        aScopeId := lLocal.RoutineScopeId;
        aDeclaredTypeName := lLocal.TypeName;
      end;
    if lMatches = 0 then
      for lDeclaration in aModel.Declarations do
        if SameText(lDeclaration.Name, aResolved.Name) and
          SameText(lDeclaration.ScopeKind, 'routine') and
          (lDeclaration.Line = aResolved.Line) and
          (lDeclaration.Column = aResolved.Column) and
          (lDeclaration.OwnerScopeId <> '') then
        begin
          Inc(lMatches);
          aScopeId := lDeclaration.OwnerScopeId;
          aDeclaredTypeName := lDeclaration.TypeName;
        end;
  end else if SameText(aResolved.Kind, 'parameter') then
  begin
    // A resolved parameter carries its routine's coordinates: the routine at those
    // coordinates plus the parameter name identify the declaration. The resolved
    // TypeName is the selector's final type, so it cannot identify the parameter.
    // Delphi resolves a heading's types in the scope enclosing the routine, so the
    // routine's own local types are not visible there. ScopeId and ParentScopeId come
    // from the uniquely matched AST scope, so an empty parent is a verified top level.
    for lRoutine in aModel.Routines do
      if SameText(lRoutine.Name, aResolved.OwnerName) and
        (lRoutine.Line = aResolved.Line) and
        (lRoutine.Column = aResolved.Column) and (lRoutine.ScopeId <> '') and
        (lRoutine.AstScopeKind <> '') then
        for lParameter in lRoutine.Parameters do
          if SameText(lParameter.Name, aResolved.Name) then
          begin
            Inc(lMatches);
            aScopeId := lRoutine.ParentScopeId;
            aOwnRoutineScopeId := lRoutine.ScopeId;
            aDeclaredTypeName := lParameter.TypeName;
          end;
  end else
    for lMember in aModel.Members do
      if SameText(lMember.Name, aResolved.Name) and
        (lMember.Line = aResolved.Line) and (lMember.Column = aResolved.Column) then
      begin
        Inc(lMatches);
        aScopeId := lMember.OwnerScopeId;
        aDeclaredTypeName := lMember.TypeName;
        // A member inside a routine body whose local owner was not uniquely found is
        // not proven unit-level.
        if (aScopeId = '') and (lMember.FileName = '') and
          (RoutineScopeAtLine(aModel, lMember.Line) <> '') then
          Inc(lMatches);
      end;
  Result := lMatches = 1;
  if not Result then
  begin
    aScopeId := '';
    aDeclaredTypeName := '';
    aOwnRoutineScopeId := '';
  end;
end;

// A resolved member keeps the coordinates of its declaration but not its unit, so the
// declaring model is the single project model with a member at those coordinates.
function TryMemberDeclaringModel(const aProjectModels: TArray<TDelphiSemanticUnitModel>;
  const aResolved: TDelphiSemanticResolveResult;
  out aDeclaringModel: TDelphiSemanticUnitModel): Boolean;
var
  lMatches: Integer;
  lMember: TDelphiSemanticMember;
  lModel: TDelphiSemanticUnitModel;
begin
  aDeclaringModel := Default(TDelphiSemanticUnitModel);
  lMatches := 0;
  for lModel in aProjectModels do
    for lMember in lModel.Members do
      if SameText(lMember.Name, aResolved.Name) and
        (lMember.Line = aResolved.Line) and (lMember.Column = aResolved.Column) and
        ((aResolved.OwnerName = '') or SameText(lMember.OwnerName, aResolved.OwnerName)) then
      begin
        Inc(lMatches);
        aDeclaringModel := lModel;
        Break;
      end;
  Result := lMatches = 1;
  if not Result then
    aDeclaringModel := Default(TDelphiSemanticUnitModel);
end;

function MakeSelectorBinding(const aModel: TDelphiSemanticUnitModel;
  const aProjectModels: TArray<TDelphiSemanticUnitModel>; const aRoutineName,
  aCurrentTypeName, aSelectorText: string; const aParentRoutineNames: TArray<string>;
  const aPreviousSelectors, aParentSelectors: TArray<TDelphiSemanticWithSelectorBinding>;
  const aLine, aColumn: Integer;
  const aProjectMemberIndex: TWithBindingProjectMemberIndex;
  const aMemberCache: TDictionary<string, TBoundMemberResolution>;
  out aIdentity: TDelphiSemanticTypeIdentity):
  TDelphiSemanticWithSelectorBinding;
var
  lBaseName: string;
  lBaseResult: TDelphiSemanticResolveResult;
  lBound: TBoundMemberResolution;
  lCastName: string;
  lCastResult: TDelphiSemanticResolveResult;
  lCastType: string;
  lComplex: Boolean;
  lContext: TDelphiSemanticResolveContext;
  lDereferenced: Boolean;
  lDeclaringModel: TDelphiSemanticUnitModel;
  lDeclaringModelCount: Integer;
  lDeclaringSection: string;
  lDeclaredTypeName: string;
  lIndexBeforeDereference: Boolean;
  lOwnRoutineScopeId: string;
  lIndexed: Boolean;
  lLexicalPointerBase: Boolean;
  lOriginModel: TDelphiSemanticUnitModel;
  lOriginScopeId: string;
  lOriginSection: string;
  lParts: TArray<string>;
  lPointeeName: string;
  lPointerIdentity: TDelphiSemanticTypeIdentity;
  lProjectModel: TDelphiSemanticUnitModel;
  lResult: TDelphiSemanticResolveResult;
  lSelectorText: string;
  lSymbolModel: TDelphiSemanticUnitModel;
  lVerifiedLocalPointer: Boolean;
  lWithBase: Boolean;

  function TryVerifiedPointerPointee(const aPointerTypeName, aPointerScopeId: string;
    out aPointeeName: string; out aPointeeIdentity: TDelphiSemanticTypeIdentity): Boolean;
  var
    lAliasDeclaration: TDelphiSemanticDeclaration;
    lAliasIdentity: TDelphiSemanticTypeIdentity;
    lAliasModel: TDelphiSemanticUnitModel;
    lDeclaration: TDelphiSemanticDeclaration;
    lFileName: string;
    lMatchCount: Integer;
    lPointerTypeName: string;
    lTargetModel: TDelphiSemanticUnitModel;
    lTargetScopeId: string;
    lTargetSection: string;
  begin
    Result := False;
    aPointeeName := '';
    aPointeeIdentity := Default(TDelphiSemanticTypeIdentity);
    lPointerTypeName := Trim(aPointerTypeName);
    lTargetModel := aModel;
    lTargetScopeId := aPointerScopeId;
    lTargetSection := lContext.SectionKind;
    if not StartsText('^', lPointerTypeName) then
    begin
      if not TRegEx.IsMatch(lPointerTypeName, '^[A-Za-z_][A-Za-z0-9_]*$') or
        not aProjectMemberIndex.TryResolveSelectorIdentity(aModel,
          lContext.SectionKind, aPointerScopeId, lPointerTypeName, lAliasIdentity) or
        not SameText(lAliasIdentity.Kind, 'type-alias') or
        not aProjectMemberIndex.TrySafetyDeclarationModel(lAliasIdentity, lAliasModel) then
        Exit;
      lMatchCount := 0;
      for lDeclaration in lAliasModel.Declarations do
      begin
        lFileName := lDeclaration.FileName;
        if lFileName = '' then
          lFileName := lAliasModel.FileName;
        if SameText(lDeclaration.Name, lAliasIdentity.Name) and
          SameText(lFileName, lAliasIdentity.SourceRange.FileName) and
          (lDeclaration.Line = lAliasIdentity.SourceRange.Line) and
          (lDeclaration.Column = lAliasIdentity.SourceRange.Column) and
          SameText(lDeclaration.ScopeKind, lAliasIdentity.ScopeKind) and
          SameText(lDeclaration.OwnerScopeId, lAliasIdentity.OwnerScopeId) and
          SameText(lDeclaration.SymbolId, lAliasIdentity.SemanticSymbolId) and
          SameText(lDeclaration.SectionKind, lAliasIdentity.SectionKind) then
        begin
          Inc(lMatchCount);
          lAliasDeclaration := lDeclaration;
        end;
      end;
      if lMatchCount <> 1 then
        Exit;
      lPointerTypeName := Trim(lAliasDeclaration.TypeName);
      lTargetModel := lAliasModel;
      if SameText(lAliasIdentity.ScopeKind, 'unit') then
      begin
        if lAliasIdentity.OwnerScopeId <> LowerCase(lAliasModel.UnitName) then
          Exit;
        lTargetScopeId := '';
      end else if SameText(lAliasIdentity.ScopeKind, 'routine') then
      begin
        if lAliasIdentity.OwnerScopeId = '' then
          Exit;
        lTargetScopeId := lAliasIdentity.OwnerScopeId;
      end else
        Exit;
      lTargetSection := lAliasIdentity.SectionKind;
    end;
    if not StartsText('^', lPointerTypeName) then
      Exit;
    aPointeeName := Trim(Copy(lPointerTypeName, 2, MaxInt));
    Result := TRegEx.IsMatch(aPointeeName, '^[A-Za-z_][A-Za-z0-9_]*$') and
      aProjectMemberIndex.TryResolveSelectorIdentity(lTargetModel, lTargetSection,
        lTargetScopeId, aPointeeName, aPointeeIdentity) and
      SameText(aPointeeIdentity.Kind, 'type') and
      SameText(aPointeeIdentity.CanonicalName, 'record');
  end;
begin
  aIdentity := Default(TDelphiSemanticTypeIdentity);
  lLexicalPointerBase := False;
  lVerifiedLocalPointer := False;
  lOriginModel := Default(TDelphiSemanticUnitModel);
  lOriginSection := '';
  lOriginScopeId := '';
  lOwnRoutineScopeId := '';
  // Lexical symbols are declared in the current unit; a bound member in its owner's unit.
  lSymbolModel := aModel;
  lSelectorText := aSelectorText.Trim;
  lContext := Default(TDelphiSemanticResolveContext);
  lContext.RoutineName := aRoutineName;
  lContext.CurrentTypeName := aCurrentTypeName;
  lContext.ParentRoutineNames := aParentRoutineNames;
  lContext.SectionKind := 'implementation';
  lContext.ConformanceLevel := 3;
  lContext.IndexedUnitModels := aProjectModels;
  lComplex := (Pos('.', lSelectorText) > 0) or (Pos('[', lSelectorText) > 0) or
    (Pos('^', lSelectorText) > 0);
  lBaseName := '';
  if lComplex then
  begin
    lParts := lSelectorText.Split(['.']);
    if Length(lParts) > 0 then
      ParseSelectorToken(lParts[0], lBaseName, lIndexed, lDereferenced,
        lIndexBeforeDereference);
  end else
    lBaseName := lSelectorText;
  lWithBase := False;
  if TRegEx.IsMatch(lBaseName, '^[A-Za-z_][A-Za-z0-9_]*$') then
  begin
    if not lComplex then
    begin
      if Length(aPreviousSelectors) > 0 then
        lWithBase := aProjectMemberIndex.TryResolveVerifiedSimpleMember(aModel,
          aPreviousSelectors, aCurrentTypeName,
          ReceiverMemberCachePrefix(aModel.UnitName, aCurrentTypeName,
          aRoutineName, aLine, aColumn, aPreviousSelectors), lBaseName,
          aMemberCache, lBound);
      if (not lWithBase) and (Length(aParentSelectors) > 0) then
        lWithBase := aProjectMemberIndex.TryResolveVerifiedSimpleMember(aModel,
          aParentSelectors, aCurrentTypeName,
          ReceiverMemberCachePrefix(aModel.UnitName, aCurrentTypeName,
          aRoutineName, aLine, aColumn, aParentSelectors), lBaseName,
          aMemberCache, lBound);
    end else
    begin
      if Length(aPreviousSelectors) > 0 then
        lWithBase := TryResolveReceiverMember(aModel, aProjectModels,
          aPreviousSelectors, aCurrentTypeName,
          ReceiverMemberCachePrefix(aModel.UnitName, aCurrentTypeName,
          aRoutineName, aLine, aColumn,
          aPreviousSelectors), lBaseName, aProjectMemberIndex, aMemberCache,
          lBound);
      if (not lWithBase) and (Length(aParentSelectors) > 0) then
        lWithBase := TryResolveReceiverMember(aModel, aProjectModels,
          aParentSelectors, aCurrentTypeName,
          ReceiverMemberCachePrefix(aModel.UnitName, aCurrentTypeName,
          aRoutineName, aLine, aColumn,
          aParentSelectors), lBaseName, aProjectMemberIndex, aMemberCache,
          lBound);
    end;
  end;
  if lWithBase then
  begin
    lResult := lBound.Value;
    if lResult.Found then
    begin
      lDeclaringModel := Default(TDelphiSemanticUnitModel);
      lDeclaringModelCount := 0;
      for lProjectModel in aProjectModels do
        if SameText(lProjectModel.UnitName, lBound.DeclaringUnitName) and
          (lBound.DeclaringUnitName <> '') then
        begin
          Inc(lDeclaringModelCount);
          lDeclaringModel := lProjectModel;
        end;
      if lDeclaringModelCount = 1 then
      begin
        if SameText(lDeclaringModel.UnitName, aModel.UnitName) then
          lDeclaringSection := lContext.SectionKind
        else
          lDeclaringSection := 'interface';
        lOriginModel := lDeclaringModel;
        lOriginSection := lDeclaringSection;
        lSymbolModel := lDeclaringModel;
        if lComplex then
          lResult := ResolveBoundSelectorWithFinalTypeOrigin(aModel, lContext,
            lSelectorText, lResult, lDeclaringModel, lDeclaringSection,
            lOriginModel, lOriginSection);
      end;
      if lDeclaringModelCount <> 1 then
      begin
        lResult := Default(TDelphiSemanticResolveResult);
        lResult.Status := 'unsupported';
        lResult.Name := lSelectorText;
        lResult.ReasonCode := 'SELECTOR_TYPE_NOT_RESOLVED';
        lResult.Reason := 'The bound selector declaring type could not be identified.';
      end;
    end;
  end else
    lResult := ResolveNameThroughWithBindingAuthority(aModel, lContext, lSelectorText,
      lOriginModel, lOriginSection);
  if (not lWithBase) and (lSelectorText = lBaseName + '^') and
    TRegEx.IsMatch(lBaseName, '^[A-Za-z_][A-Za-z0-9_]*$') then
  begin
    lBaseResult := ResolveNameThroughWithBindingAuthority(aModel, lContext, lBaseName);
    if SameText(lBaseResult.Status, 'ambiguous') then
    begin
      lLexicalPointerBase := True;
      lResult := lBaseResult;
    end else if lBaseResult.Found and SameText(lBaseResult.Status, 'resolved') and
      MatchText(lBaseResult.Kind, ['local', 'parameter']) then
    begin
      // A lexical pointer's declaration scope takes precedence over a unit namesake.
      lLexicalPointerBase := True;
      lResult := Default(TDelphiSemanticResolveResult);
      lResult.Name := lSelectorText;
      lResult.Status := 'unresolved';
      lResult.ReasonCode := 'SELECTOR_TYPE_NOT_RESOLVED';
      lResult.Reason := 'The lexical pointer receiver type could not be verified.';
      // A top-level routine's parameter resolves its type in unit scope ('').
      if TryDeclarationScope(aModel, lBaseResult, lOriginScopeId, lDeclaredTypeName,
        lOwnRoutineScopeId) and
        ((lOriginScopeId <> '') or (lOwnRoutineScopeId <> '')) and
        TryVerifiedPointerPointee(lBaseResult.TypeName, lOriginScopeId,
          lPointeeName, lPointerIdentity) and
        ((lOwnRoutineScopeId = '') or
        (not SameText(lPointerIdentity.OwnerScopeId, lOwnRoutineScopeId))) then
      begin
        lResult := lBaseResult;
        lResult.TypeName := lPointeeName;
        lOriginModel := aModel;
        lOriginSection := lContext.SectionKind;
        lVerifiedLocalPointer := True;
      end;
    end;
  end;
  if (not lLexicalPointerBase) and TryParsePointerCastName(lSelectorText, lCastName) and
    (not TryResolveReceiverMember(aModel, aProjectModels, aPreviousSelectors,
    aCurrentTypeName, ReceiverMemberCachePrefix(aModel.UnitName, aCurrentTypeName,
    aRoutineName, aLine, aColumn,
    aPreviousSelectors), lCastName, aProjectMemberIndex, aMemberCache, lCastResult)) and
    (not TryResolveReceiverMember(aModel, aProjectModels, aParentSelectors,
    aCurrentTypeName, ReceiverMemberCachePrefix(aModel.UnitName, aCurrentTypeName,
    aRoutineName, aLine, aColumn,
    aParentSelectors), lCastName, aProjectMemberIndex, aMemberCache, lCastResult)) and
    ((aCurrentTypeName = '') or
    (not aProjectMemberIndex.TryResolveDirectMember(aModel.UnitName, aCurrentTypeName,
    aCurrentTypeName, lCastName, True, lCastResult))) and
    aProjectMemberIndex.TryResolvePointerCastType(aModel, lCastName, aLine, lCastType) then
  begin
    lResult := Default(TDelphiSemanticResolveResult);
    lResult.Found := True;
    lResult.Status := 'resolved';
    lResult.Kind := 'record';
    lResult.TypeName := lCastType;
    lOriginModel := aModel;
    lOriginSection := lContext.SectionKind;
  end;
  if lResult.Found and SelectorUsesUnsafeProperty(aModel, lContext, lSelectorText) then
    MarkPropertySelectorUnsupported(lSelectorText, lResult);
  if lResult.Found and SameText(lResult.Status, 'resolved') then
    if lVerifiedLocalPointer then
      aIdentity := lPointerIdentity
    else if ((lWithBase or (not MatchText(lResult.Kind, ['field', 'member', 'property']))) or
      TryMemberDeclaringModel(aProjectModels, lResult, lSymbolModel)) and
      aProjectMemberIndex.TryResolveTypeOriginScope(lSymbolModel, lOriginModel,
      lResult, lOriginScopeId, lOwnRoutineScopeId) then
    begin
      // A routine-local type without a supported identity (for example a local
      // class, which Delphi rejects with E2059) has members we cannot verify, so
      // a direct-member miss must not fall through to an outer receiver.
      if not aProjectMemberIndex.TryResolveSelectorIdentity(lOriginModel, lOriginSection,
        lOriginScopeId, lResult.TypeName, aIdentity) then
      begin
        if (lOriginScopeId <> '') and
          aProjectMemberIndex.IsUnsupportedRoutineLocalType(lOriginModel, lOriginSection,
          lOriginScopeId, lResult.TypeName) then
        begin
          lResult.Status := 'unsupported';
          lResult.ReasonCode := 'ROUTINE_LOCAL_TYPE_UNSUPPORTED';
          lResult.Reason := 'The routine-local receiver type has no supported identity.';
        end else if lWithBase and (not lComplex) and (lOriginScopeId = '') and
          (not aProjectMemberIndex.TryResolveAnonymousMemberTypeIdentity(lDeclaringModel,
          lResult, aIdentity)) then
          // The member was bound through a verified parent; without a proven
          // anonymous record its type stays explicitly unidentified.
          aIdentity := Default(TDelphiSemanticTypeIdentity);
      end;
      // A parameter's type never belongs to its own routine's local scope.
      if (lOwnRoutineScopeId <> '') and
        SameText(aIdentity.OwnerScopeId, lOwnRoutineScopeId) then
      begin
        aIdentity := Default(TDelphiSemanticTypeIdentity);
        lResult.Status := 'unsupported';
        lResult.ReasonCode := 'PARAMETER_TYPE_SCOPE_INVALID';
        lResult.Reason := 'A parameter type cannot belong to its own routine scope.';
      end;
    end else if lWithBase and lComplex and
      (lDeclaringModel.UnitName <> '') and
      (lOriginModel.UnitName <> '') and
      (not SameText(lOriginModel.UnitName, lDeclaringModel.UnitName)) and
      SameText(lOriginSection, 'interface') then
      aProjectMemberIndex.TryResolveUniqueExportedFinalType(lOriginModel,
        lResult.TypeName, aIdentity);
  Result.SelectorText := lSelectorText;
  Result.Status := lResult.Status;
  Result.ReasonCode := lResult.ReasonCode;
  Result.TypeName := lResult.TypeName;
  Result.TypeIdentity := aIdentity;
end;

function LookupSourceForClassification(const aClassification: string): string;
begin
  if SameText(aClassification, 'member') then
    Result := 'receiver'
  else if SameText(aClassification, 'lexical') then
    Result := 'lexical'
  else if SameText(aClassification, 'intrinsic') then
    Result := 'intrinsic'
  else if SameText(aClassification, 'external') then
    Result := 'external'
  else
    Result := 'none';
end;

function MakeBoundReference(const aName, aClassification: string;
  const aResult: TDelphiSemanticResolveResult): TDelphiSemanticBoundReference;
begin
  Result.Name := aName;
  Result.Classification := aClassification;
  Result.LookupSource := LookupSourceForClassification(aClassification);
  Result.ReceiverTypeName := aResult.OwnerName;
  Result.Kind := aResult.Kind;
  Result.TypeName := aResult.TypeName;
  Result.ReasonCode := aResult.ReasonCode;
end;

function BindingSemanticId(const aModel: TDelphiSemanticUnitModel;
  const aStatement: TDelphiSemanticWithStatement): string;
begin
  Result := StableFactId('with', LowerCase(aModel.FileName) + '|' +
    IntToStr(aStatement.Line) + '|' + IntToStr(aStatement.Column) + '|' +
    IntToStr(aStatement.EndLine) + '|' + IntToStr(aStatement.EndColumn) + '|' +
    aStatement.SelectorText);
end;

function ReferenceSemanticId(const aBindingId: string;
  const aReference: TDelphiSemanticBoundReference): string;
begin
  Result := StableFactId('with-ref', aBindingId + '|' + aReference.Name + '|' +
    aReference.Classification + '|' + IntToStr(aReference.Line) + '|' +
    IntToStr(aReference.Column) + '|' + IntToStr(aReference.EndLine) + '|' +
    IntToStr(aReference.EndColumn));
end;

function GraphWithStatementIdForBinding(const aGraph: TDelphiSemanticSemanticGraph;
  const aBinding: TDelphiSemanticWithBinding): string;
var
  lStatement: TDelphiSemanticGraphWithStatement;
begin
  if aGraph = nil then
    Exit(aBinding.SemanticId);

  for lStatement in aGraph.WithStatements do
    if SameText(lStatement.SourceRange.FileName, aBinding.FileName) and
      (lStatement.SourceRange.Line = aBinding.Line) and
      (lStatement.SourceRange.Column = aBinding.Column) and
      (lStatement.SourceRange.EndLine = aBinding.EndLine) and
      (lStatement.SourceRange.EndColumn = aBinding.EndColumn) then
      Exit(lStatement.Id.Value);

  Result := aBinding.SemanticId;
end;

function BuildBodyLineStarts(const aText: string): TArray<Integer>;
var
  i: Integer;
  lIndex: Integer;
  lLineCount: Integer;
begin
  lLineCount := 1;
  for i := 1 to Length(aText) do
    if aText[i] = #10 then
      Inc(lLineCount);

  SetLength(Result, lLineCount);
  Result[0] := 1;
  lIndex := 1;
  for i := 1 to Length(aText) do
    if aText[i] = #10 then
    begin
      Result[lIndex] := i + 1;
      Inc(lIndex);
    end;
end;

function BodyLineOfOffset(const aLineStarts: TArray<Integer>;
  const aOffset: Integer): Integer;
var
  lBest: Integer;
  lHigh: Integer;
  lLow: Integer;
  lMid: Integer;
begin
  if Length(aLineStarts) = 0 then
    Exit(1);

  lBest := 0;
  lLow := 0;
  lHigh := High(aLineStarts);
  while lLow <= lHigh do
  begin
    lMid := (lLow + lHigh) div 2;
    if aLineStarts[lMid] <= aOffset then
    begin
      lBest := lMid;
      lLow := lMid + 1;
    end else
      lHigh := lMid - 1;
  end;
  Result := lBest + 1;
end;

function BodyColumnOfOffset(const aLineStarts: TArray<Integer>;
  const aLine, aOffset: Integer): Integer;
var
  lIndex: Integer;
begin
  lIndex := aLine - 1;
  if (lIndex >= Low(aLineStarts)) and (lIndex <= High(aLineStarts)) then
    Result := aOffset - aLineStarts[lIndex] + 1
  else
    Result := aOffset;
  if Result < 1 then
    Result := 1;
end;

procedure ApplyBodyRange(var aReference: TDelphiSemanticBoundReference;
  const aStatement: TDelphiSemanticWithStatement; const aStartOffset, aLength: Integer;
  const aBodyLineStarts: TArray<Integer>);
var
  lEndColumn: Integer;
  lEndLine: Integer;
  lEndOffset: Integer;
  lStartColumn: Integer;
  lStartLine: Integer;
  lStartOffset: Integer;
begin
  if (aStartOffset <= 0) or (aLength <= 0) or (aStatement.BodyText = '') then
    Exit;

  lEndOffset := aStartOffset + aLength - 1;
  lStartOffset := aStartOffset;
  // DS-671: semantic names omit the escape; physical ranges include it.
  if ReferenceTokenIsEscaped(aStatement.BodyText, lStartOffset) then
    Dec(lStartOffset);
  lStartLine := BodyLineOfOffset(aBodyLineStarts, lStartOffset);
  lStartColumn := BodyColumnOfOffset(aBodyLineStarts, lStartLine, lStartOffset);
  lEndLine := BodyLineOfOffset(aBodyLineStarts, lEndOffset);
  lEndColumn := BodyColumnOfOffset(aBodyLineStarts, lEndLine, lEndOffset);

  aReference.Line := aStatement.BodyLine + lStartLine - 1;
  if lStartLine = 1 then
    aReference.Column := aStatement.BodyColumn + lStartColumn - 1
  else
    aReference.Column := lStartColumn;
  aReference.EndLine := aStatement.BodyLine + lEndLine - 1;
  if lEndLine = 1 then
    aReference.EndColumn := aStatement.BodyColumn + lEndColumn - 1
  else
    aReference.EndColumn := lEndColumn;
end;

procedure ApplyLocalLabelFact(const aModel: TDelphiSemanticUnitModel;
  var aReference: TDelphiSemanticBoundReference);
var
  lDeclarationCount: Integer;
  lDefinitionCount: Integer;
  lFact: TDelphiSemanticReference;
  lRelated: TDelphiSemanticReference;
begin
  if not SameText(aModel.ScopeModelStatus, 'ast') then
    Exit;
  for lFact in aModel.LocalLabelReferences do
  begin
    if (lFact.FileName <> '') or (lFact.Line <> aReference.Line) or
      (lFact.Column <> aReference.Column) or
      not SameText(lFact.Name, aReference.Name) or
      not MatchText(lFact.Role, ['local-label-target', 'local-label-definition',
      'local-goto-keyword']) then
      Continue;
    // Occurrence-specific facts must never enter the name-only binding cache.
    aReference.Classification := 'lexical';
    aReference.Kind := 'label';
    aReference.LookupSource := 'syntax';
    aReference.ReceiverTypeName := '';
    aReference.TypeName := '';
    aReference.ReasonCode := '';
    aReference.ScopeConflictKind := '';
    aReference.ScopeConflictName := '';
    if lFact.Role = 'local-goto-keyword' then
    begin
      aReference.Kind := 'goto-keyword';
      Exit;
    end;
    lDeclarationCount := 0;
    lDefinitionCount := 0;
    for lRelated in aModel.LocalLabelReferences do
      if (lRelated.FileName = '') and (lFact.RoutineScopeId <> '') and
        SameText(lRelated.RoutineScopeId, lFact.RoutineScopeId) and
        SameText(lRelated.Name, lFact.Name) then
      begin
        if lRelated.Role = 'local-label-declaration' then
          Inc(lDeclarationCount)
        else if lRelated.Role = 'local-label-definition' then
          Inc(lDefinitionCount);
      end;
    if (lDeclarationCount <> 1) or (lDefinitionCount <> 1) then
    begin
      aReference.Classification := 'unsupported';
      aReference.Kind := 'unverified-label';
      aReference.ReasonCode := 'LOCAL_LABEL_NOT_RESOLVED';
    end;
    Exit;
  end;
end;

function MakeSyntheticResolveResult(const aName, aKind, aTypeName, aOwnerName,
  aReasonCode: string): TDelphiSemanticResolveResult;
begin
  Result := Default(TDelphiSemanticResolveResult);
  Result.Found := aKind <> '';
  Result.Authoritative := Result.Found;
  if Result.Found then
    Result.Status := 'resolved'
  else
    Result.Status := 'unresolved';
  Result.Name := aName;
  Result.Kind := aKind;
  Result.TypeName := aTypeName;
  Result.OwnerName := aOwnerName;
  Result.ReasonCode := aReasonCode;
end;

function TWithBindingProjectMemberIndex.TryResolveCompilerIntrinsic(const aName: string;
  out aResult: TDelphiSemanticResolveResult): Boolean;
var
  lSymbol: TDelphiSemanticIntrinsicSymbol;
begin
  if fCompilerIntrinsics = nil then
    BuildCompilerIntrinsicIndex;
  Result := fCompilerIntrinsics.TryGetValue(aName, lSymbol);
  if Result then
    aResult := MakeSyntheticResolveResult(aName, lSymbol.Kind, lSymbol.TypeName,
      lSymbol.OwnerName, '')
  else
    aResult := Default(TDelphiSemanticResolveResult);
end;

function TryExtractCallName(const aName: string; out aCallName: string): Boolean;
var
  lBracketPos: Integer;
  lParenPos: Integer;
begin
  lBracketPos := Pos('[', aName);
  lParenPos := Pos('(', aName);
  Result := (lParenPos > 1) and ((lBracketPos = 0) or (lParenPos < lBracketPos));
  if Result then
    aCallName := Copy(aName, 1, lParenPos - 1).Trim
  else
    aCallName := '';
end;

function TryExtractCallArguments(const aName: string; out aArguments: string): Boolean;
var
  lBracketPos: Integer;
  lClosePos: Integer;
  lParenPos: Integer;
begin
  // Only a call suffix has arguments; parentheses inside an index such as Values[Length(Name)] belong
  // to the index contents, which AddIndexReferences binds (T-350), as TryExtractCallName decides.
  lBracketPos := Pos('[', aName);
  lParenPos := Pos('(', aName);
  lClosePos := LastDelimiter(')', aName);
  Result := (lParenPos > 1) and (lClosePos > lParenPos) and ((lBracketPos = 0) or (lParenPos < lBracketPos));
  if Result then
    aArguments := Copy(aName, lParenPos + 1, lClosePos - lParenPos - 1)
  else
    aArguments := '';
end;

function CallerTypeNameFromRoutineName(const aRoutineName: string): string;
var
  lDotPos: Integer;
begin
  lDotPos := LastDelimiter('.', aRoutineName);
  if lDotPos > 1 then
    Result := Copy(aRoutineName, 1, lDotPos - 1)
  else
    Result := '';
end;

function CallerTypeNameForRoutineContext(const aModel: TDelphiSemanticUnitModel;
  const aRoutineName: string; const aParentRoutineNames: TArray<string>;
  const aLine: Integer): string;
var
  lBestLine: Integer;
  lParentRoutineName: string;

  function FindOwnerForRoutineName(const aName: string; const aRequireOwner: Boolean): string;
  var
    lRoutine: TDelphiSemanticRoutine;
  begin
    Result := '';
    lBestLine := -1;
    for lRoutine in aModel.Routines do
      if (SameText(lRoutine.Name, aName) or
        ((lRoutine.OwnerName <> '') and
        SameText(lRoutine.OwnerName + '.' + lRoutine.Name, aName))) and
        (lRoutine.Line > 0) and
        (lRoutine.Line <= aLine) and (lRoutine.Line > lBestLine) then
      begin
        if aRequireOwner and (lRoutine.OwnerName = '') then
          Continue;
        Result := lRoutine.OwnerName;
        lBestLine := lRoutine.Line;
      end;
  end;

begin
  Result := CallerTypeNameFromRoutineName(aRoutineName);
  if Result <> '' then
    Exit;

  Result := FindOwnerForRoutineName(aRoutineName, False);
  if Result <> '' then
    Exit;

  for lParentRoutineName in aParentRoutineNames do
  begin
    Result := FindOwnerForRoutineName(lParentRoutineName, True);
    if Result <> '' then
      Exit;
  end;
end;

function RoutineLookupNameForRoutineContext(const aModel: TDelphiSemanticUnitModel;
  const aRoutineName: string; const aLine: Integer): string;
var
  lBestLine: Integer;
  lRoutine: TDelphiSemanticRoutine;
begin
  Result := aRoutineName;
  lBestLine := -1;
  for lRoutine in aModel.Routines do
    if SameText(lRoutine.Name, aRoutineName) and (lRoutine.Line > 0) and
      (lRoutine.Line <= aLine) and (lRoutine.Line > lBestLine) then
    begin
      if lRoutine.OwnerName <> '' then
        Result := lRoutine.OwnerName + '.' + lRoutine.Name
      else
        Result := lRoutine.Name;
      lBestLine := lRoutine.Line;
    end;
end;

function SelectorAllowsReceiverMemberLookup(
  const aSelector: TDelphiSemanticWithSelectorBinding): Boolean;
begin
  Result := (Pos('[', aSelector.SelectorText) = 0) and
    (Pos('^', aSelector.SelectorText) = 0);
end;

function ReceiverMemberCachePrefix(const aUnitName, aCurrentTypeName,
  aRoutineName: string; const aLine, aColumn: Integer;
  const aSelectors: TArray<TDelphiSemanticWithSelectorBinding>): string;
var
  lBuilder: TStringBuilder;
  lSelector: TDelphiSemanticWithSelectorBinding;
begin
  lBuilder := TStringBuilder.Create;
  try
    lBuilder.Append(aUnitName).Append(#31).Append(aCurrentTypeName).Append(#31)
      .Append(aRoutineName).Append(#31).Append(aLine).Append(#31)
      .Append(aColumn).Append(#31);
    for lSelector in aSelectors do
      lBuilder.Append(lSelector.SelectorText).Append(#30).Append(lSelector.Status).
        Append(#30).Append(lSelector.TypeName).Append(#30).
        Append(lSelector.TypeIdentity.DeclaredId.Value).Append(#30).
        Append(Ord(SelectorAllowsReceiverMemberLookup(lSelector))).Append(#29);
    lBuilder.Append(#31);
    Result := lBuilder.ToString;
  finally
    lBuilder.Free;
  end;
end;

function ReceiverMemberCacheKey(const aPrefix, aName: string): string;
begin
  Result := aPrefix + aName;
end;

function TryResolveReceiverMember(const aModel: TDelphiSemanticUnitModel;
  const aProjectModels: TArray<TDelphiSemanticUnitModel>;
  const aSelectors: TArray<TDelphiSemanticWithSelectorBinding>;
  const aCurrentTypeName, aMemberCachePrefix, aName: string;
  const aProjectMemberIndex: TWithBindingProjectMemberIndex;
  const aMemberCache: TDictionary<string, TBoundMemberResolution>;
  out aResult: TDelphiSemanticResolveResult): Boolean;
var
  lBound: TBoundMemberResolution;
begin
  Result := TryResolveReceiverMember(aModel, aProjectModels, aSelectors,
    aCurrentTypeName, aMemberCachePrefix, aName, aProjectMemberIndex,
    aMemberCache, lBound);
  aResult := lBound.Value;
end;

function TryResolveReceiverMember(const aModel: TDelphiSemanticUnitModel;
  const aProjectModels: TArray<TDelphiSemanticUnitModel>;
  const aSelectors: TArray<TDelphiSemanticWithSelectorBinding>;
  const aCurrentTypeName, aMemberCachePrefix, aName: string;
  const aProjectMemberIndex: TWithBindingProjectMemberIndex;
  const aMemberCache: TDictionary<string, TBoundMemberResolution>;
  out aResult: TBoundMemberResolution): Boolean;
var
  i: Integer;
  lKey: string;
begin
  lKey := ReceiverMemberCacheKey(aMemberCachePrefix, aName);
  if Assigned(aMemberCache) and aMemberCache.TryGetValue(lKey, aResult) then
    Exit(aResult.Value.Found or SameText(aResult.Value.Status, 'ambiguous') or
      SameText(aResult.Value.Status, 'unsupported'));

  for i := High(aSelectors) downto 0 do
  begin
    // An unverifiable routine-local receiver may own any name, so it shields
    // outer receivers and lexical declarations instead of being skipped.
    if SameText(aSelectors[i].ReasonCode, 'ROUTINE_LOCAL_TYPE_UNSUPPORTED') then
    begin
      aResult := Default(TBoundMemberResolution);
      aResult.Value.Status := 'unsupported';
      aResult.Value.Name := aName;
      aResult.Value.ReasonCode := 'ROUTINE_LOCAL_TYPE_UNSUPPORTED';
      aResult.Value.Reason := 'The routine-local receiver type has no supported identity.';
      if Assigned(aMemberCache) then
        aMemberCache.AddOrSetValue(lKey, aResult);
      Exit(True);
    end;
    // DS-705: an unresolved or ambiguous receiver may own this name. An
    // inner proven receiver gets its lookup first; this barrier shields the
    // remaining outer receivers and lexical declarations.
    if not SameText(aSelectors[i].Status, 'resolved') then
    begin
      aResult := Default(TBoundMemberResolution);
      aResult.Value.Status := 'unsupported';
      aResult.Value.Name := aName;
      aResult.Value.ReasonCode := 'SELECTOR_MEMBERS_UNVERIFIED';
      aResult.Value.Reason := 'The receiver type is unresolved or ambiguous.';
      if Assigned(aMemberCache) then
        aMemberCache.AddOrSetValue(lKey, aResult);
      Exit(True);
    end;
    if SameText(aSelectors[i].Status, 'resolved') then
    begin
      if Assigned(aProjectMemberIndex) and
        SameText(aSelectors[i].TypeIdentity.ScopeKind, 'routine') then
      begin
        if aProjectMemberIndex.TryResolveRoutineLocalMember(aSelectors[i].TypeIdentity,
          aCurrentTypeName, aName, aResult) then
        begin
          if Assigned(aMemberCache) then
            aMemberCache.AddOrSetValue(lKey, aResult);
          Exit(True);
        end;
        Continue;
      end;
      if Assigned(aProjectMemberIndex) and aProjectMemberIndex.TryResolveDirectMember(
        aModel.UnitName, aCurrentTypeName, aSelectors[i].TypeName, aName,
        SelectorAllowsReceiverMemberLookup(aSelectors[i]), aModel.FileName,
        aSelectors[i].TypeIdentity, aResult) then
      begin
        if Assigned(aMemberCache) then
          aMemberCache.AddOrSetValue(lKey, aResult);
        Exit(True);
      end;
      if (not Assigned(aProjectMemberIndex)) or
        (not aProjectMemberIndex.ReceiverMemberAbsenceIsVerified(aModel, aSelectors[i], aName)) then
      begin
        aResult := Default(TBoundMemberResolution);
        aResult.Value.Status := 'unsupported';
        aResult.Value.Name := aName;
        aResult.Value.ReasonCode := 'OWNER_INHERITED_MEMBERS_UNVERIFIED';
        aResult.Value.Reason := 'The receiver may inherit a member that is not indexed.';
        if Assigned(aMemberCache) then
          aMemberCache.AddOrSetValue(lKey, aResult);
        Exit(True);
      end;
    end;
  end;

  aResult := Default(TBoundMemberResolution);
  if Assigned(aMemberCache) then
    aMemberCache.AddOrSetValue(lKey, aResult);
  Result := False;
end;

function AnySelectorUnresolved(const aSelectors: TArray<TDelphiSemanticWithSelectorBinding>): Boolean;
var
  lSelector: TDelphiSemanticWithSelectorBinding;
begin
  for lSelector in aSelectors do
    if not SameText(lSelector.Status, 'resolved') then
      Exit(True);

  Result := False;
end;

procedure AddReference(const aReferences: TList<TDelphiSemanticBoundReference>;
  const aReference: TDelphiSemanticBoundReference);
begin
  aReferences.Add(aReference);
end;

function BoundReferenceCachePrefix(const aUnitName, aRoutineName, aCurrentTypeName: string;
  const aParentRoutineNames: TArray<string>;
  const aSelectors: TArray<TDelphiSemanticWithSelectorBinding>): string;
var
  lBuilder: TStringBuilder;
  lParentRoutineName: string;
  lSelector: TDelphiSemanticWithSelectorBinding;
begin
  lBuilder := TStringBuilder.Create;
  try
    lBuilder.Append(aUnitName).Append(#31).Append(aRoutineName).Append(#31)
      .Append(aCurrentTypeName).Append(#31);
    for lParentRoutineName in aParentRoutineNames do
      lBuilder.Append(lParentRoutineName).Append(#30);
    lBuilder.Append(#31);
    for lSelector in aSelectors do
      lBuilder.Append(lSelector.Status).Append(#30).Append(lSelector.TypeName).Append(#30).
        Append(lSelector.TypeIdentity.DeclaredId.Value).Append(#29);
    lBuilder.Append(#31);
    Result := lBuilder.ToString;
  finally
    lBuilder.Free;
  end;
end;

function BoundReferenceCacheKey(const aPrefix, aName: string): string;
begin
  Result := aPrefix + aName;
end;

function CacheBoundReference(
  const aReferenceCache: TDictionary<string, TDelphiSemanticBoundReference>;
  const aKey: string; const aReference: TDelphiSemanticBoundReference):
  TDelphiSemanticBoundReference;
begin
  Result := aReference;
  if Assigned(aReferenceCache) then
    aReferenceCache.AddOrSetValue(aKey, Result);
end;

function ResolveNameCachePrefix(const aUnitName: string; const aContext:
  TDelphiSemanticResolveContext): string;
var
  lBuilder: TStringBuilder;
  lParentRoutineName: string;
begin
  lBuilder := TStringBuilder.Create;
  try
    lBuilder.Append(aUnitName).Append(#31).Append(aContext.RoutineName).Append(#31)
      .Append(aContext.CurrentTypeName).Append(#31).Append(aContext.SectionKind).Append(#31)
      .Append(aContext.ConformanceLevel).Append(#31);
    for lParentRoutineName in aContext.ParentRoutineNames do
      lBuilder.Append(lParentRoutineName).Append(#30);
    lBuilder.Append(#31);
    Result := lBuilder.ToString;
  finally
    lBuilder.Free;
  end;
end;

function ResolveNameCacheKey(const aPrefix, aName: string): string;
begin
  Result := aPrefix + aName;
end;

function ResolveNameCached(const aModel: TDelphiSemanticUnitModel;
  const aContext: TDelphiSemanticResolveContext; const aName: string;
  const aResolveCache: TDictionary<string, TDelphiSemanticResolveResult>;
  const aResolveCachePrefix: string;
  const aProjectMemberIndex: TWithBindingProjectMemberIndex):
  TDelphiSemanticResolveResult;
var
  lContext: TDelphiSemanticResolveContext;
  lKey: string;
begin
  lKey := ResolveNameCacheKey(aResolveCachePrefix, aName);
  if Assigned(aResolveCache) and aResolveCache.TryGetValue(lKey, Result) then
    Exit;

  lContext := aContext;
  if aProjectMemberIndex <> nil then
    lContext := aProjectMemberIndex.ContextForName(aContext, aName);
  Result := ResolveNameThroughWithBindingAuthority(aModel, lContext, aName);
  if Assigned(aResolveCache) then
    aResolveCache.AddOrSetValue(lKey, Result);
end;

procedure ApplyScopeConflictFact(const aModel: TDelphiSemanticUnitModel;
  const aContext: TDelphiSemanticResolveContext;
  const aResolveCache: TDictionary<string, TDelphiSemanticResolveResult>;
  const aResolveCachePrefix: string;
  const aProjectMemberIndex: TWithBindingProjectMemberIndex;
  var aReference: TDelphiSemanticBoundReference;
  var aLexicalResolveMs: Int64);
var
  lResult: TDelphiSemanticResolveResult;
  lStopwatch: TStopwatch;
begin
  if (not SameText(aReference.Classification, 'member')) or (aReference.Name = '') then
    Exit;

  lStopwatch := TStopwatch.StartNew;
  lResult := ResolveNameCached(aModel, aContext, aReference.Name, aResolveCache,
    aResolveCachePrefix, aProjectMemberIndex);
  lStopwatch.Stop;
  Inc(aLexicalResolveMs, lStopwatch.ElapsedMilliseconds);

  if lResult.Found and SameText(lResult.Kind, 'routine') then
  begin
    aReference.ScopeConflictKind := 'routine';
    aReference.ScopeConflictName := lResult.Name;
  end;
end;

function BindReference(const aModel: TDelphiSemanticUnitModel;
  const aProjectModels: TArray<TDelphiSemanticUnitModel>;
  const aRoutineName, aCurrentTypeName: string;
  const aParentRoutineNames: TArray<string>;
  const aSelectors: TArray<TDelphiSemanticWithSelectorBinding>;
  const aReferenceCachePrefix, aResolveCachePrefix, aMemberCachePrefix, aName: string;
  const aProjectMemberIndex: TWithBindingProjectMemberIndex;
  const aReferenceCache: TDictionary<string, TDelphiSemanticBoundReference>;
  const aResolveCache: TDictionary<string, TDelphiSemanticResolveResult>;
  const aMemberCache: TDictionary<string, TBoundMemberResolution>;
  var aReceiverMemberResolveMs, aLexicalResolveMs, aReferenceCacheHits,
  aReferenceCacheMisses: Int64):
  TDelphiSemanticBoundReference;
var
  lCallName: string;
  lContext: TDelphiSemanticResolveContext;
  lIntrinsicResult: TDelphiSemanticResolveResult;
  lKey: string;
  lResult: TDelphiSemanticResolveResult;
  lStopwatch: TStopwatch;
begin
  lKey := BoundReferenceCacheKey(aReferenceCachePrefix, aName);
  if Assigned(aReferenceCache) and aReferenceCache.TryGetValue(lKey, Result) then
  begin
    Inc(aReferenceCacheHits);
    Exit;
  end;
  Inc(aReferenceCacheMisses);

  lContext := Default(TDelphiSemanticResolveContext);
  lContext.RoutineName := aRoutineName;
  lContext.CurrentTypeName := aCurrentTypeName;
  lContext.ParentRoutineNames := aParentRoutineNames;
  lContext.SectionKind := 'implementation';
  lContext.ConformanceLevel := 3;
  lContext.IndexedUnitModels := aProjectModels;

  if TryExtractCallName(aName, lCallName) then
  begin
    lStopwatch := TStopwatch.StartNew;
    if TryResolveReceiverMember(aModel, aProjectModels, aSelectors, aCurrentTypeName,
      aMemberCachePrefix, lCallName, aProjectMemberIndex, aMemberCache, lResult) then
    begin
      lStopwatch.Stop;
      Inc(aReceiverMemberResolveMs, lStopwatch.ElapsedMilliseconds);
      if SameText(lResult.Kind, 'method') then
        Exit(CacheBoundReference(aReferenceCache, lKey,
          MakeBoundReference(lCallName, 'member', lResult)))
      else
        Exit(CacheBoundReference(aReferenceCache, lKey,
          MakeBoundReference(lCallName, 'unsupported',
          MakeSyntheticResolveResult(lCallName, lResult.Kind, lResult.TypeName,
          lResult.OwnerName, 'CALL_SELECTOR_UNSUPPORTED'))));
    end;
    lStopwatch.Stop;
    Inc(aReceiverMemberResolveMs, lStopwatch.ElapsedMilliseconds);

    lStopwatch := TStopwatch.StartNew;
    lResult := ResolveNameCached(aModel, lContext, lCallName, aResolveCache,
      aResolveCachePrefix, aProjectMemberIndex);
    lStopwatch.Stop;
    Inc(aLexicalResolveMs, lStopwatch.ElapsedMilliseconds);
    if lResult.Found and SameText(lResult.Kind, 'intrinsic-routine') then
      Exit(CacheBoundReference(aReferenceCache, lKey,
        MakeBoundReference(lCallName, 'intrinsic', lResult)));
    if lResult.Found and SameText(lResult.Kind, 'routine') then
      Exit(CacheBoundReference(aReferenceCache, lKey, MakeBoundReference(lCallName, 'external',
        MakeSyntheticResolveResult(lCallName, 'routine', lResult.TypeName, lResult.OwnerName,
        'EXTERNAL_ROUTINE_CALL'))));
    if lResult.Found then
      Exit(CacheBoundReference(aReferenceCache, lKey, MakeBoundReference(lCallName, 'unsupported',
        MakeSyntheticResolveResult(lCallName, lResult.Kind, lResult.TypeName, lResult.OwnerName,
        'CALL_SELECTOR_UNSUPPORTED'))));
    if SameText(lResult.Status, 'unresolved') and
      SameText(lResult.ReasonCode, 'NAME_NOT_FOUND') and Assigned(aProjectMemberIndex) and
      aProjectMemberIndex.TryResolveCompilerIntrinsic(lCallName, lResult) then
      Exit(CacheBoundReference(aReferenceCache, lKey,
        MakeBoundReference(lCallName, 'intrinsic', lResult)));
    Exit(CacheBoundReference(aReferenceCache, lKey, MakeBoundReference(lCallName, 'external',
      MakeSyntheticResolveResult(lCallName, 'routine', '', '', 'UNKNOWN_ROUTINE_CALL'))));
  end;

  if (Pos('.', aName) > 0) or (Pos('[', aName) > 0) then
  begin
    lStopwatch := TStopwatch.StartNew;
    lResult := ResolveNameCached(aModel, Default(TDelphiSemanticResolveContext),
      aName, aResolveCache, ResolveNameCachePrefix(aModel.UnitName,
      Default(TDelphiSemanticResolveContext)), aProjectMemberIndex);
    lStopwatch.Stop;
    Inc(aLexicalResolveMs, lStopwatch.ElapsedMilliseconds);
    Exit(CacheBoundReference(aReferenceCache, lKey, MakeBoundReference(aName, 'unsupported',
      lResult)));
  end;

  lStopwatch := TStopwatch.StartNew;
  if TryResolveReceiverMember(aModel, aProjectModels, aSelectors, aCurrentTypeName,
    aMemberCachePrefix, aName, aProjectMemberIndex, aMemberCache, lResult) then
  begin
    lStopwatch.Stop;
    Inc(aReceiverMemberResolveMs, lStopwatch.ElapsedMilliseconds);
    if SameText(lResult.Status, 'ambiguous') then
      Exit(CacheBoundReference(aReferenceCache, lKey,
        MakeBoundReference(aName, 'ambiguous', lResult)));
    if SameText(lResult.Status, 'unsupported') then
      Exit(CacheBoundReference(aReferenceCache, lKey,
        MakeBoundReference(aName, 'unsupported', lResult)));
    Exit(CacheBoundReference(aReferenceCache, lKey, MakeBoundReference(aName, 'member', lResult)));
  end;
  lStopwatch.Stop;
  Inc(aReceiverMemberResolveMs, lStopwatch.ElapsedMilliseconds);

  lStopwatch := TStopwatch.StartNew;
  lResult := ResolveNameCached(aModel, lContext, aName, aResolveCache,
    aResolveCachePrefix, aProjectMemberIndex);
  lStopwatch.Stop;
  Inc(aLexicalResolveMs, lStopwatch.ElapsedMilliseconds);
  if lResult.Found then
    Exit(CacheBoundReference(aReferenceCache, lKey, MakeBoundReference(aName, 'lexical', lResult)));

  // Source-proven members and lexical declarations take precedence over the
  // compiler profile when a project graph has not seeded its intrinsic symbols.
  if SameText(lResult.Status, 'unresolved') and
    SameText(lResult.ReasonCode, 'NAME_NOT_FOUND') and Assigned(aProjectMemberIndex) and
    aProjectMemberIndex.TryResolveCompilerIntrinsic(aName, lIntrinsicResult) and
    SameText(lIntrinsicResult.Kind, 'intrinsic-routine') then
    Exit(CacheBoundReference(aReferenceCache, lKey,
      MakeBoundReference(aName, 'intrinsic', lIntrinsicResult)));

  if AnySelectorUnresolved(aSelectors) then
  begin
    Result := MakeBoundReference(aName, 'external', lResult);
    if Assigned(aReferenceCache) then
      aReferenceCache.AddOrSetValue(lKey, Result);
    Exit;
  end;

  Result := MakeBoundReference(aName, 'unresolved', lResult);
  if Assigned(aReferenceCache) then
    aReferenceCache.AddOrSetValue(lKey, Result);
end;

procedure CountBindingReference(var aBinding: TDelphiSemanticWithBinding;
  const aReference: TDelphiSemanticBoundReference);
begin
  if SameText(aReference.Classification, 'member') then
    Inc(aBinding.MemberReferenceCount)
  else if SameText(aReference.Classification, 'lexical') then
    Inc(aBinding.LexicalReferenceCount)
  else if SameText(aReference.Classification, 'external') then
    Inc(aBinding.ExternalReferenceCount)
  else if SameText(aReference.Classification, 'intrinsic') then
    Inc(aBinding.IntrinsicReferenceCount)
  else if SameText(aReference.Classification, 'unsupported') then
    Inc(aBinding.UnsupportedReferenceCount)
  else if SameText(aReference.Classification, 'unresolved') then
    Inc(aBinding.UnresolvedReferenceCount);
end;

function ActivityOffset(const aLineStarts: TArray<Integer>;
  const aSourceLength, aLine, aColumn: Integer): Integer;
begin
  Result := 0;
  if (aLine < 1) or (aLine > Length(aLineStarts)) or (aColumn < 1) then
    Exit;
  Result := aLineStarts[aLine - 1] + aColumn - 1;
  if (Result > aSourceLength + 1) or
    ((aLine < Length(aLineStarts)) and (Result >= aLineStarts[aLine])) then
    Result := 0;
end;

procedure ApplyBindingActivity(const aModel: TDelphiSemanticUnitModel;
  const aLineStarts: TArray<Integer>; var aBinding: TDelphiSemanticWithBinding);
var
  lEndOffset: Integer;
  lStartOffset: Integer;
begin
  lStartOffset := ActivityOffset(aLineStarts, Length(aModel.SourceText), aBinding.Line, aBinding.Column);
  lEndOffset := ActivityOffset(aLineStarts, Length(aModel.SourceText), aBinding.EndLine, aBinding.EndColumn);
  aBinding.ActivityUnverified := not TDelphiSemanticSourceConditionals.RangeIsKnownActive(
    aModel.SourceText, aModel.VerifiedActiveSourceText, lStartOffset, lEndOffset);
  if aBinding.ActivityUnverified then
  begin
    aBinding.Status := 'skipped';
    // Keep the established binder refusal; activity is a separate apply barrier.
    if aBinding.SkipReason = '' then
      aBinding.SkipReason := 'ACTIVITY_UNVERIFIED';
  end;
end;

procedure ApplyBindingReferenceIds(var aBinding: TDelphiSemanticWithBinding);
var
  i: Integer;
begin
  for i := 0 to High(aBinding.References) do
    aBinding.References[i].SemanticId := ReferenceSemanticId(aBinding.SemanticId,
      aBinding.References[i]);
end;

procedure FinalizeBinding(var aBinding: TDelphiSemanticWithBinding;
  const aStatement: TDelphiSemanticWithStatement);
var
  lReference: TDelphiSemanticBoundReference;
begin
  aBinding.HasScopedDeclaration := aStatement.HasScopedDeclaration;
  for lReference in aBinding.References do
    CountBindingReference(aBinding, lReference);

  if aBinding.HasScopedDeclaration then
  begin
    aBinding.Status := 'skipped';
    aBinding.SkipReason := 'SCOPED_DECLARATION';
  end else if aBinding.UnsupportedReferenceCount > 0 then
  begin
    aBinding.Status := 'skipped';
    aBinding.SkipReason := 'UNSUPPORTED_REFERENCE';
  end else if aBinding.UnresolvedReferenceCount > 0 then
  begin
    aBinding.Status := 'skipped';
    aBinding.SkipReason := 'UNRESOLVED_REFERENCE';
  end else if aBinding.ExternalReferenceCount > 0 then
  begin
    aBinding.Status := 'skipped';
    aBinding.SkipReason := 'EXTERNAL_REFERENCE';
  end else
  begin
    aBinding.Status := 'planned';
    aBinding.SkipReason := '';
  end;
end;

procedure SeparateInactiveSpanVerification(const aModel: TDelphiSemanticUnitModel;
  const aLineStarts: TArray<Integer>; const aStatement: TDelphiSemanticWithStatement;
  var aBinding: TDelphiSemanticWithBinding);
var
  lActiveCount: Integer;
  lInactiveCount: Integer;
  lOffset: Integer;
  lReference: TDelphiSemanticBoundReference;
  lScanText: string;
  lVerification: TDelphiSemanticWithBinding;
begin
  if aModel.ReferenceScanSourceText <> '' then
    lScanText := TDelphiSemanticSourceConditionals.SourceForScan(aModel.SourceText,
      aModel.ReferenceScanSourceText)
  else
    lScanText := TDelphiSemanticSourceConditionals.SourceForScan(aModel.SourceText,
      aModel.VerifiedActiveSourceText);
  lVerification := aBinding;
  FinalizeBinding(lVerification, aStatement);
  SetLength(aBinding.InactiveSpanReferences, Length(aBinding.References));
  lActiveCount := 0;
  lInactiveCount := 0;
  for lReference in aBinding.References do
  begin
    lOffset := ActivityOffset(aLineStarts, Length(aModel.SourceText),
      lReference.Line, lReference.Column);
    if (lOffset > 0) and (lOffset <= Length(lScanText)) and
      (lScanText[lOffset] = ' ') and (aModel.SourceText[lOffset] <> ' ') then
    begin
      aBinding.InactiveSpanReferences[lInactiveCount] := lReference;
      Inc(lInactiveCount);
    end else begin
      aBinding.References[lActiveCount] := lReference;
      Inc(lActiveCount);
    end;
  end;
  SetLength(aBinding.References, lActiveCount);
  SetLength(aBinding.InactiveSpanReferences, lInactiveCount);
  if lInactiveCount > 0 then
    aBinding.InactiveSpanSkipReason := lVerification.SkipReason;
end;

function WithBindingForPlanning(const aBinding: TDelphiSemanticWithBinding):
  TDelphiSemanticWithBinding;
var
  lActiveIndex: Integer;
  lInactiveIndex: Integer;
  lReference: TDelphiSemanticBoundReference;
  lResultIndex: Integer;
begin
  Result := aBinding;
  if Length(aBinding.InactiveSpanReferences) = 0 then
    Exit;
  SetLength(Result.References, Length(aBinding.References) +
    Length(aBinding.InactiveSpanReferences));
  lActiveIndex := 0;
  lInactiveIndex := 0;
  lResultIndex := 0;
  // Both partitions retain their source order. Merge without changing base precedence.
  while lResultIndex < Length(Result.References) do
  begin
    if (lActiveIndex < Length(aBinding.References)) and
      ((lInactiveIndex >= Length(aBinding.InactiveSpanReferences)) or
      (aBinding.References[lActiveIndex].Line < aBinding.InactiveSpanReferences[lInactiveIndex].Line) or
      ((aBinding.References[lActiveIndex].Line = aBinding.InactiveSpanReferences[lInactiveIndex].Line) and
      (aBinding.References[lActiveIndex].Column <= aBinding.InactiveSpanReferences[lInactiveIndex].Column))) then
    begin
      lReference := aBinding.References[lActiveIndex];
      Inc(lActiveIndex);
    end else begin
      lReference := aBinding.InactiveSpanReferences[lInactiveIndex];
      Inc(lInactiveIndex);
    end;
    Result.References[lResultIndex] := lReference;
    Inc(lResultIndex);
  end;
  for lReference in aBinding.InactiveSpanReferences do
    CountBindingReference(Result, lReference);
  if (aBinding.InactiveSpanSkipReason <> '') and
    ((Result.SkipReason = '') or
    MatchText(Result.SkipReason, ['ACTIVITY_UNVERIFIED', 'UNRESOLVED_REFERENCE',
      'UNSUPPORTED_REFERENCE', 'SCOPED_DECLARATION', 'EXTERNAL_REFERENCE'])) then
    Result.SkipReason := aBinding.InactiveSpanSkipReason;
end;

function BindSelectors(const aModel: TDelphiSemanticUnitModel;
  const aProjectModels: TArray<TDelphiSemanticUnitModel>; const aRoutineName,
  aCurrentTypeName, aSelectorText: string; const aParentRoutineNames: TArray<string>;
  const aParentSelectors: TArray<TDelphiSemanticWithSelectorBinding>;
  const aLine, aColumn: Integer;
  const aProjectMemberIndex: TWithBindingProjectMemberIndex;
  const aMemberCache: TDictionary<string, TBoundMemberResolution>;
  out aIdentities: TWithSelectorIdentityArray):
  TArray<TDelphiSemanticWithSelectorBinding>;
var
  lIdentity, lPrefixIdentity: TDelphiSemanticTypeIdentity;
  lBinding, lPrefixBinding: TDelphiSemanticWithSelectorBinding;
  lActivityBinding: TDelphiSemanticWithBinding;
  lLineage: TArray<TDelphiSemanticTypeIdentity>;
  i, lParenDepth, lBracketDepth: Integer;
  lIdentities: TList<TDelphiSemanticTypeIdentity>;
  lPart: string;
  lSelectors: TList<TDelphiSemanticWithSelectorBinding>;
  lParts: TArray<string>;
begin
  aIdentities := nil;
  if not TrySplitTopLevelCommaList(aSelectorText, lParts) then
    Exit(nil);
  lSelectors := TList<TDelphiSemanticWithSelectorBinding>.Create;
  lIdentities := TList<TDelphiSemanticTypeIdentity>.Create;
  try
    for lPart in lParts do
    begin
      lBinding := MakeSelectorBinding(aModel, aProjectModels, aRoutineName,
        aCurrentTypeName, lPart, aParentRoutineNames, lSelectors.ToArray,
        aParentSelectors, aLine, aColumn, aProjectMemberIndex,
        aMemberCache, lIdentity);
      lParenDepth := 0;
      lBracketDepth := 0;
      for i := 1 to Length(lPart) do
      begin
        case lPart[i] of
          '(': Inc(lParenDepth);
          ')': Dec(lParenDepth);
          '[': Inc(lBracketDepth);
          ']': Dec(lBracketDepth);
        end;
        if (lPart[i] <> '.') or (lParenDepth <> 0) or (lBracketDepth <> 0) or
          (not Assigned(aProjectMemberIndex)) then
          Continue;
        lPrefixBinding := MakeSelectorBinding(aModel, aProjectModels, aRoutineName,
          aCurrentTypeName, Copy(lPart, 1, i - 1), aParentRoutineNames, lSelectors.ToArray,
          aParentSelectors, aLine, aColumn, aProjectMemberIndex, aMemberCache, lPrefixIdentity);
        if not SameText(lPrefixBinding.Status, 'resolved') then
          Break;
        lActivityBinding := Default(TDelphiSemanticWithBinding);
        lActivityBinding.UnitName := aModel.UnitName;
        lActivityBinding.FileName := aModel.FileName;
        aProjectMemberIndex.TryBuildMemberSafetyLineage(lActivityBinding,
          lPrefixBinding.TypeName, lPrefixIdentity, lLineage);
        if aProjectMemberIndex.LineageHasActivityFact(lLineage) then
        begin
          lBinding.Status := 'unsupported';
          lBinding.ReasonCode := 'SELECTOR_MEMBERS_ACTIVITY_UNVERIFIED';
          lIdentity := Default(TDelphiSemanticTypeIdentity);
          lBinding.TypeIdentity := lIdentity;
          Break;
        end;
      end;
      lSelectors.Add(lBinding);
      lIdentities.Add(lIdentity);
    end;
    Result := lSelectors.ToArray;
    aIdentities := lIdentities.ToArray;
  finally
    lIdentities.Free;
    lSelectors.Free;
  end;
end;

function ReferenceIdentifierStart(const aValue: Char): Boolean;
begin
  Result := CharInSet(aValue, ['A'..'Z', 'a'..'z', '_']);
end;

function ReferenceIdentifierChar(const aValue: Char): Boolean;
begin
  Result := CharInSet(aValue, ['A'..'Z', 'a'..'z', '0'..'9', '_']);
end;

function ReferencePreviousNonWhitespaceChar(const aText: string;
  const aOffset: Integer): Char;
var
  i: Integer;
begin
  Result := #0;
  i := aOffset - 1;
  while (i >= 1) and CharInSet(aText[i], [#9, #10, #13, ' ']) do
    Dec(i);
  if i >= 1 then
    Result := aText[i];
end;

function ReferenceIsControlCharacterLiteralStart(const aText: string;
  const aOffset: Integer): Boolean;
begin
  Result := (aOffset < Length(aText)) and (aText[aOffset] = '^') and
    CharInSet(aText[aOffset + 1], ['A'..'Z', 'a'..'z', '@', '[', '\', ']', '^',
    '_']) and (ReferencePreviousNonWhitespaceChar(aText, aOffset) <> '^');
end;

function ReferenceIsHexDigit(const aValue: Char): Boolean;
begin
  Result := CharInSet(aValue, ['0'..'9', 'A'..'F', 'a'..'f']);
end;

function ReferenceIsHexLiteralStart(const aText: string;
  const aOffset: Integer): Boolean;
begin
  Result := (aOffset < Length(aText)) and (aText[aOffset] = '$') and
    ReferenceIsHexDigit(aText[aOffset + 1]);
end;

procedure SkipReferenceHexLiteral(const aText: string; var aIndex: Integer);
begin
  Inc(aIndex);
  while (aIndex <= Length(aText)) and ReferenceIsHexDigit(aText[aIndex]) do
    Inc(aIndex);
end;

function ReadReferenceSuffix(const aText: string; var aIndex: Integer;
  const aOpenChar, aCloseChar: Char; const aRequireContent: Boolean): Boolean;
var
  lCloseIndex: Integer;
  lDepth: Integer;
  lOpenIndex: Integer;
begin
  Result := False;
  if (aIndex > Length(aText)) or (aText[aIndex] <> aOpenChar) then
    Exit;

  // A suffix ends at its matching close character, so a nested call such as
  // FillChar(Buffer, SizeOf(TMD5Buffer), 0) (T-277) or a nested index such as Values[Lookup[Index]]
  // (T-350) keeps its complete extent; call arguments and index contents are bound separately. The
  // body text is sanitized, so string literals and comments cannot unbalance the count.
  lOpenIndex := aIndex;
  lCloseIndex := lOpenIndex + 1;
  lDepth := 1;
  while lCloseIndex <= Length(aText) do
  begin
    if aText[lCloseIndex] = aOpenChar then
      Inc(lDepth)
    else if aText[lCloseIndex] = aCloseChar then
    begin
      Dec(lDepth);
      if lDepth = 0 then
        Break;
    end;
    Inc(lCloseIndex);
  end;
  if lCloseIndex > Length(aText) then
    Exit;
  if aRequireContent and (lCloseIndex = lOpenIndex + 1) then
    Exit;

  aIndex := lCloseIndex + 1;
  Result := True;
end;

function ReferenceIsQualifiedComponent(const aText: string; const aOffset: Integer): Boolean;
var
  lDotOffset: Integer;
begin
  lDotOffset := aOffset - 1;
  if ReferenceTokenIsEscaped(aText, aOffset) then
    Dec(lDotOffset);
  while (lDotOffset > 0) and CharInSet(aText[lDotOffset], [' ', #9, #10, #13]) do
    Dec(lDotOffset);
  // A range endpoint is still a bare name; a field after one dot is explicitly
  // qualified even when its base token ended at a pointer or index suffix.
  Result := (lDotOffset > 0) and (aText[lDotOffset] = '.') and
    (ReferencePreviousNonWhitespaceChar(aText, lDotOffset) <> '.');
end;

function ReadReferenceToken(const aText: string; var aIndex: Integer;
  const aAllowCallSuffix: Boolean; out aToken: string; out aTokenStart: Integer):
  Boolean;
var
  lTokenStart: Integer;
begin
  aToken := '';
  aTokenStart := 0;
  while aIndex <= Length(aText) do
  begin
    if ReferenceIdentifierStart(aText[aIndex]) then
    begin
      if not ReferenceIsQualifiedComponent(aText, aIndex) then
        Break;
      // Retain the base and argument/index references, but never reinterpret
      // an explicitly qualified component as a member of the WITH receiver.
      Inc(aIndex);
      while (aIndex <= Length(aText)) and ReferenceIdentifierChar(aText[aIndex]) do
        Inc(aIndex);
      Continue;
    end;
    if ReferenceIsControlCharacterLiteralStart(aText, aIndex) then
    begin
      Inc(aIndex, 2);
      Continue;
    end;
    if ReferenceIsHexLiteralStart(aText, aIndex) then
    begin
      SkipReferenceHexLiteral(aText, aIndex);
      Continue;
    end;
    Inc(aIndex);
  end;
  if aIndex > Length(aText) then
    Exit(False);

  lTokenStart := aIndex;
  Inc(aIndex);
  while (aIndex <= Length(aText)) and ReferenceIdentifierChar(aText[aIndex]) do
    Inc(aIndex);

  if (aIndex < Length(aText)) and (aText[aIndex] = '.') and
    ReferenceIdentifierStart(aText[aIndex + 1]) then
  begin
    Inc(aIndex, 2);
    while (aIndex <= Length(aText)) and ReferenceIdentifierChar(aText[aIndex]) do
      Inc(aIndex);
  end;

  if (aIndex <= Length(aText)) and (aText[aIndex] = '[') then
    ReadReferenceSuffix(aText, aIndex, '[', ']', True)
  else if aAllowCallSuffix and (aIndex <= Length(aText)) and
    (aText[aIndex] = '(') then
    ReadReferenceSuffix(aText, aIndex, '(', ')', False);

  aTokenStart := lTokenStart;
  aToken := Copy(aText, lTokenStart, aIndex - lTokenStart);
  Result := True;
end;

// The identifiers inside a token's index suffix, such as Index and Lookup in Values[Lookup[Index]],
// are bound as references of their own, like call arguments; nested indexes are followed (T-350).
procedure AddIndexReferences(const aReferences: TList<TDelphiSemanticBoundReference>;
  const aModel: TDelphiSemanticUnitModel;
  const aProjectModels: TArray<TDelphiSemanticUnitModel>;
  const aRoutineName, aCurrentTypeName: string;
  const aParentRoutineNames: TArray<string>;
  const aSelectors: TArray<TDelphiSemanticWithSelectorBinding>;
  const aReferenceCachePrefix, aResolveCachePrefix, aMemberCachePrefix: string;
  const aStatement: TDelphiSemanticWithStatement; const aToken: string;
  const aTokenStartOffset: Integer; const aBodyLineStarts: TArray<Integer>;
  const aProjectMemberIndex: TWithBindingProjectMemberIndex;
  const aReferenceCache: TDictionary<string, TDelphiSemanticBoundReference>;
  const aResolveCache: TDictionary<string, TDelphiSemanticResolveResult>;
  const aMemberCache: TDictionary<string, TBoundMemberResolution>;
  var aReceiverMemberResolveMs, aLexicalResolveMs, aReferenceCacheHits,
  aReferenceCacheMisses: Int64);
var
  lCloseIndex: Integer;
  lContent: string;
  lInnerIndex: Integer;
  lInnerStart: Integer;
  lInnerStartOffset: Integer;
  lInnerToken: string;
  lOpenIndex: Integer;
  lReference: TDelphiSemanticBoundReference;
  lResolveContext: TDelphiSemanticResolveContext;
begin
  lOpenIndex := Pos('[', aToken);
  lCloseIndex := LastDelimiter(']', aToken);
  if (lOpenIndex <= 1) or (lCloseIndex <= lOpenIndex) then
    Exit;
  lResolveContext := Default(TDelphiSemanticResolveContext);
  lResolveContext.RoutineName := aRoutineName;
  lResolveContext.CurrentTypeName := aCurrentTypeName;
  lResolveContext.ParentRoutineNames := aParentRoutineNames;
  lResolveContext.SectionKind := 'implementation';
  lResolveContext.ConformanceLevel := 3;
  lResolveContext.IndexedUnitModels := aProjectModels;
  lContent := SanitizeBodyText(Copy(aToken, lOpenIndex + 1, lCloseIndex - lOpenIndex - 1));
  lInnerIndex := 1;
  while ReadReferenceToken(lContent, lInnerIndex, False, lInnerToken, lInnerStart) do
  begin
    if (IsBinderKeyword(lInnerToken) and
      (not ReferenceTokenIsEscaped(lContent, lInnerStart))) or
      IsSelectorName(aSelectors, lInnerToken) then
      Continue;
    lReference := BindReference(aModel, aProjectModels, aRoutineName, aCurrentTypeName,
      aParentRoutineNames, aSelectors, aReferenceCachePrefix, aResolveCachePrefix,
      aMemberCachePrefix, lInnerToken, aProjectMemberIndex, aReferenceCache, aResolveCache,
      aMemberCache, aReceiverMemberResolveMs, aLexicalResolveMs, aReferenceCacheHits,
      aReferenceCacheMisses);
    lInnerStartOffset := aTokenStartOffset + lOpenIndex + lInnerStart - 1;
    ApplyBodyRange(lReference, aStatement, lInnerStartOffset, Length(lInnerToken), aBodyLineStarts);
    ApplyScopeConflictFact(aModel, lResolveContext, aResolveCache, aResolveCachePrefix,
      aProjectMemberIndex, lReference, aLexicalResolveMs);
    ApplyLocalLabelFact(aModel, lReference);
    AddReference(aReferences, lReference);
    AddIndexReferences(aReferences, aModel, aProjectModels, aRoutineName, aCurrentTypeName,
      aParentRoutineNames, aSelectors, aReferenceCachePrefix, aResolveCachePrefix, aMemberCachePrefix,
      aStatement, lInnerToken, lInnerStartOffset, aBodyLineStarts, aProjectMemberIndex, aReferenceCache,
      aResolveCache, aMemberCache, aReceiverMemberResolveMs, aLexicalResolveMs, aReferenceCacheHits,
      aReferenceCacheMisses);
  end;
end;

procedure AddArgumentReferences(const aReferences: TList<TDelphiSemanticBoundReference>;
  const aModel: TDelphiSemanticUnitModel;
  const aProjectModels: TArray<TDelphiSemanticUnitModel>;
  const aRoutineName, aCurrentTypeName: string;
  const aParentRoutineNames: TArray<string>;
  const aSelectors: TArray<TDelphiSemanticWithSelectorBinding>;
  const aReferenceCachePrefix, aResolveCachePrefix, aMemberCachePrefix: string;
  const aStatement: TDelphiSemanticWithStatement; const aToken: string;
  const aTokenStartOffset: Integer; const aBodyLineStarts: TArray<Integer>;
  const aProjectMemberIndex: TWithBindingProjectMemberIndex;
  const aReferenceCache: TDictionary<string, TDelphiSemanticBoundReference>;
  const aResolveCache: TDictionary<string, TDelphiSemanticResolveResult>;
  const aMemberCache: TDictionary<string, TBoundMemberResolution>;
  var aReceiverMemberResolveMs, aLexicalResolveMs, aReferenceCacheHits,
  aReferenceCacheMisses: Int64);
var
  lArgumentIndex: Integer;
  lArgumentStartOffset: Integer;
  lArgumentToken: string;
  lArgumentTokenStart: Integer;
  lArguments: string;
  lParenPos: Integer;
  lReference: TDelphiSemanticBoundReference;
  lResolveContext: TDelphiSemanticResolveContext;
begin
  if not TryExtractCallArguments(aToken, lArguments) then
    Exit;

  lResolveContext := Default(TDelphiSemanticResolveContext);
  lResolveContext.RoutineName := aRoutineName;
  lResolveContext.CurrentTypeName := aCurrentTypeName;
  lResolveContext.ParentRoutineNames := aParentRoutineNames;
  lResolveContext.SectionKind := 'implementation';
  lResolveContext.ConformanceLevel := 3;
  lResolveContext.IndexedUnitModels := aProjectModels;
  lParenPos := Pos('(', aToken);
  lArguments := SanitizeBodyText(lArguments);
  lArgumentIndex := 1;
  while ReadReferenceToken(lArguments, lArgumentIndex, False, lArgumentToken,
    lArgumentTokenStart) do
  begin
    if ((not IsBinderKeyword(lArgumentToken)) or
      ReferenceTokenIsEscaped(lArguments, lArgumentTokenStart)) and
      (not IsSelectorName(aSelectors, lArgumentToken)) then
    begin
      lReference := BindReference(aModel, aProjectModels, aRoutineName, aCurrentTypeName,
        aParentRoutineNames, aSelectors, aReferenceCachePrefix, aResolveCachePrefix,
        aMemberCachePrefix, lArgumentToken, aProjectMemberIndex, aReferenceCache, aResolveCache,
        aMemberCache, aReceiverMemberResolveMs, aLexicalResolveMs, aReferenceCacheHits,
        aReferenceCacheMisses);
      lArgumentStartOffset := aTokenStartOffset + lParenPos + lArgumentTokenStart - 1;
      ApplyBodyRange(lReference, aStatement, lArgumentStartOffset, Length(lArgumentToken),
        aBodyLineStarts);
      ApplyScopeConflictFact(aModel, lResolveContext, aResolveCache, aResolveCachePrefix,
        aProjectMemberIndex, lReference, aLexicalResolveMs);
      ApplyLocalLabelFact(aModel, lReference);
      AddReference(aReferences, lReference);
      AddIndexReferences(aReferences, aModel, aProjectModels, aRoutineName, aCurrentTypeName,
        aParentRoutineNames, aSelectors, aReferenceCachePrefix, aResolveCachePrefix, aMemberCachePrefix,
        aStatement, lArgumentToken, lArgumentStartOffset, aBodyLineStarts, aProjectMemberIndex,
        aReferenceCache, aResolveCache, aMemberCache, aReceiverMemberResolveMs, aLexicalResolveMs,
        aReferenceCacheHits, aReferenceCacheMisses);
    end;
  end;
end;

procedure AppendNumericLabelReferences(const aModel: TDelphiSemanticUnitModel;
  const aStatement: TDelphiSemanticWithStatement; const aBodyText: string;
  const aBodyLineStarts: TArray<Integer>;
  const aReferences: TList<TDelphiSemanticBoundReference>);
var
  lFact: TDelphiSemanticReference;
  lLineIndex: Integer;
  lOffset: Integer;
  lReference: TDelphiSemanticBoundReference;
begin
  // Numeric labels are grammar tokens, but the ordinary identifier scanner skips them.
  for lFact in aModel.LocalLabelReferences do
  begin
    if (lFact.FileName <> '') or (lFact.Name = '') or
      not CharInSet(lFact.Name[1], ['0'..'9']) or
      not MatchText(lFact.Role, ['local-label-target', 'local-label-definition']) then
      Continue;
    lLineIndex := lFact.Line - aStatement.BodyLine;
    if (lLineIndex < 0) or (lLineIndex >= Length(aBodyLineStarts)) then
      Continue;
    lOffset := aBodyLineStarts[lLineIndex] + lFact.Column - 1;
    if lLineIndex = 0 then
      Dec(lOffset, aStatement.BodyColumn - 1);
    // Nested with bodies and non-code have already been blanked without moving text.
    if (lOffset <= 0) or (Copy(aBodyText, lOffset, Length(lFact.Name)) <> lFact.Name) then
      Continue;
    lReference := Default(TDelphiSemanticBoundReference);
    lReference.Name := lFact.Name;
    ApplyBodyRange(lReference, aStatement, lOffset, Length(lFact.Name), aBodyLineStarts);
    ApplyLocalLabelFact(aModel, lReference);
    AddReference(aReferences, lReference);
  end;
end;

function BindReferences(const aModel: TDelphiSemanticUnitModel;
  const aProjectModels: TArray<TDelphiSemanticUnitModel>;
  const aStatement: TDelphiSemanticWithStatement;
  const aAllStatements: TArray<TDelphiSemanticWithStatement>;
  const aStatementIndex: Integer;
  const aRoutineName, aCurrentTypeName: string;
  const aParentRoutineNames: TArray<string>;
  const aSelectors: TArray<TDelphiSemanticWithSelectorBinding>;
  const aProjectMemberIndex: TWithBindingProjectMemberIndex;
  const aReferenceCache: TDictionary<string, TDelphiSemanticBoundReference>;
  const aResolveCache: TDictionary<string, TDelphiSemanticResolveResult>;
  const aMemberCache: TDictionary<string, TBoundMemberResolution>;
  var aReceiverMemberResolveMs, aLexicalResolveMs, aReferenceCacheHits,
  aReferenceCacheMisses: Int64):
  TArray<TDelphiSemanticBoundReference>;
var
  lBodyLineStarts: TArray<Integer>;
  lBodyText: string;
  lTokenIndex: Integer;
  lTokenStart: Integer;
  lToken: string;
  lReferenceCachePrefix: string;
  lMemberCachePrefix: string;
  lResolveContext: TDelphiSemanticResolveContext;
  lResolveCachePrefix: string;
  lReference: TDelphiSemanticBoundReference;
  lReferences: TList<TDelphiSemanticBoundReference>;
begin
  lReferences := TList<TDelphiSemanticBoundReference>.Create;
  try
    lReferenceCachePrefix := BoundReferenceCachePrefix(aModel.UnitName, aRoutineName,
      aCurrentTypeName,
      aParentRoutineNames, aSelectors);
    lMemberCachePrefix := ReceiverMemberCachePrefix(aModel.UnitName, aCurrentTypeName,
      aRoutineName, aStatement.Line, aStatement.Column, aSelectors);
    lResolveContext := Default(TDelphiSemanticResolveContext);
    lResolveContext.RoutineName := aRoutineName;
    lResolveContext.CurrentTypeName := aCurrentTypeName;
    lResolveContext.ParentRoutineNames := aParentRoutineNames;
    lResolveContext.SectionKind := 'implementation';
    lResolveContext.ConformanceLevel := 3;
    lResolveContext.IndexedUnitModels := aProjectModels;
    lResolveCachePrefix := ResolveNameCachePrefix(aModel.UnitName, lResolveContext);
    lBodyText := ExtractWithBodyText(aStatement, aAllStatements, aStatementIndex);
    lBodyLineStarts := BuildBodyLineStarts(lBodyText);
    lTokenIndex := 1;
    while ReadReferenceToken(lBodyText, lTokenIndex, True, lToken, lTokenStart) do
    begin
      if ((not IsBinderKeyword(lToken)) or
        ReferenceTokenIsEscaped(lBodyText, lTokenStart)) and
        (not IsSelectorName(aSelectors, lToken)) then
      begin
        lReference := BindReference(aModel, aProjectModels, aRoutineName, aCurrentTypeName,
          aParentRoutineNames, aSelectors, lReferenceCachePrefix, lResolveCachePrefix,
          lMemberCachePrefix, lToken, aProjectMemberIndex, aReferenceCache, aResolveCache,
          aMemberCache, aReceiverMemberResolveMs, aLexicalResolveMs, aReferenceCacheHits,
          aReferenceCacheMisses);
        ApplyBodyRange(lReference, aStatement, lTokenStart, Length(lToken), lBodyLineStarts);
        ApplyScopeConflictFact(aModel, lResolveContext, aResolveCache, lResolveCachePrefix,
          aProjectMemberIndex, lReference, aLexicalResolveMs);
        ApplyLocalLabelFact(aModel, lReference);
        AddReference(lReferences, lReference);
        AddArgumentReferences(lReferences, aModel, aProjectModels, aRoutineName,
          aCurrentTypeName,
          aParentRoutineNames, aSelectors, lReferenceCachePrefix, lResolveCachePrefix,
          lMemberCachePrefix, aStatement, lToken, lTokenStart, lBodyLineStarts,
          aProjectMemberIndex, aReferenceCache, aResolveCache, aMemberCache,
          aReceiverMemberResolveMs, aLexicalResolveMs, aReferenceCacheHits,
          aReferenceCacheMisses);
        AddIndexReferences(lReferences, aModel, aProjectModels, aRoutineName, aCurrentTypeName,
          aParentRoutineNames, aSelectors, lReferenceCachePrefix, lResolveCachePrefix,
          lMemberCachePrefix, aStatement, lToken, lTokenStart, lBodyLineStarts,
          aProjectMemberIndex, aReferenceCache, aResolveCache, aMemberCache,
          aReceiverMemberResolveMs, aLexicalResolveMs, aReferenceCacheHits,
          aReferenceCacheMisses);
      end;
    end;
    AppendNumericLabelReferences(aModel, aStatement, lBodyText, lBodyLineStarts, lReferences);
    Result := lReferences.ToArray;
  finally
    lReferences.Free;
  end;
end;

function StatementContains(const aOuter, aInner: TDelphiSemanticWithStatement): Boolean;
begin
  Result := ((aOuter.Line < aInner.Line) or ((aOuter.Line = aInner.Line) and
    (aOuter.Column < aInner.Column))) and ((aOuter.EndLine > aInner.EndLine) or
    ((aOuter.EndLine = aInner.EndLine) and (aOuter.EndColumn >= aInner.EndColumn)));
end;

function BuildParentStatementIndexes(
  const aStatements: TArray<TDelphiSemanticWithStatement>): TArray<Integer>;
var
  i: Integer;
  lParentIndex: Integer;
  lStack: TList<Integer>;
begin
  SetLength(Result, Length(aStatements));
  lStack := TList<Integer>.Create;
  try
    for i := 0 to High(aStatements) do
    begin
      while lStack.Count > 0 do
      begin
        lParentIndex := lStack[lStack.Count - 1];
        if StatementContains(aStatements[lParentIndex], aStatements[i]) then
          Break;
        lStack.Delete(lStack.Count - 1);
      end;
      if lStack.Count > 0 then
        Result[i] := lStack[lStack.Count - 1]
      else
        Result[i] := -1;
      lStack.Add(i);
    end;
  finally
    lStack.Free;
  end;
end;

function MergeSelectorStacks(const aParentSelectors,
  aOwnSelectors: TWithSelectorBindingArray): TWithSelectorBindingArray;
var
  i: Integer;
  lParentCount: Integer;
begin
  lParentCount := Length(aParentSelectors);
  SetLength(Result, lParentCount + Length(aOwnSelectors));
  for i := 0 to High(aParentSelectors) do
    Result[i] := aParentSelectors[i];
  for i := 0 to High(aOwnSelectors) do
    Result[lParentCount + i] := aOwnSelectors[i];
end;

function MergeSelectorIdentities(const aParentIdentities,
  aOwnIdentities: TWithSelectorIdentityArray): TWithSelectorIdentityArray;
var
  i: Integer;
  lParentCount: Integer;
begin
  lParentCount := Length(aParentIdentities);
  SetLength(Result, lParentCount + Length(aOwnIdentities));
  for i := 0 to High(aParentIdentities) do
    Result[i] := aParentIdentities[i];
  for i := 0 to High(aOwnIdentities) do
    Result[lParentCount + i] := aOwnIdentities[i];
end;

function BuildSelectorStackCache(const aModel: TDelphiSemanticUnitModel;
  const aProjectModels: TArray<TDelphiSemanticUnitModel>;
  const aStatements: TArray<TDelphiSemanticWithStatement>;
  const aScopeIndex: TDelphiSemanticRoutineScopeIndex;
  const aProjectMemberIndex: TWithBindingProjectMemberIndex;
  const aMemberCache: TDictionary<string, TBoundMemberResolution>;
  out aIdentityStacks: TWithSelectorIdentityStackArray):
  TWithSelectorStackArray;
var
  i: Integer;
  lCurrentTypeName: string;
  lDirectSelectors: TWithSelectorBindingArray;
  lDirectIdentities: TWithSelectorIdentityArray;
  lParentIndexes: TArray<Integer>;
  lParentIndex: Integer;
  lParentSelectors: TArray<TDelphiSemanticWithSelectorBinding>;
  lParentIdentities: TWithSelectorIdentityArray;
  lParentRoutineNames: TArray<string>;
  lRoutineLookupName: string;
  lRoutineName: string;
begin
  lParentIndexes := BuildParentStatementIndexes(aStatements);
  SetLength(Result, Length(aStatements));
  SetLength(aIdentityStacks, Length(aStatements));
  for i := 0 to High(aStatements) do
  begin
    lRoutineName := aScopeIndex.RoutineNameForLine(aStatements[i].Line);
    lParentRoutineNames := aScopeIndex.ParentRoutineNamesForLine(lRoutineName,
      aStatements[i].Line);
    lCurrentTypeName := CallerTypeNameForRoutineContext(aModel, lRoutineName,
      lParentRoutineNames, aStatements[i].Line);
    lRoutineLookupName := RoutineLookupNameForRoutineContext(aModel, lRoutineName,
      aStatements[i].Line);
    lParentIndex := lParentIndexes[i];
    lParentSelectors := nil;
    lParentIdentities := nil;
    if lParentIndex >= 0 then
    begin
      lParentSelectors := Result[lParentIndex];
      lParentIdentities := aIdentityStacks[lParentIndex];
    end;
    lDirectSelectors := BindSelectors(aModel, aProjectModels, lRoutineLookupName,
      lCurrentTypeName, aStatements[i].SelectorText, lParentRoutineNames,
      lParentSelectors, aStatements[i].Line, aStatements[i].Column,
      aProjectMemberIndex, aMemberCache, lDirectIdentities);
    if lParentIndex >= 0 then
    begin
      Result[i] := MergeSelectorStacks(Result[lParentIndex], lDirectSelectors);
      aIdentityStacks[i] := MergeSelectorIdentities(lParentIdentities,
        lDirectIdentities);
    end else begin
      Result[i] := lDirectSelectors;
      aIdentityStacks[i] := lDirectIdentities;
    end;
  end;
end;

procedure TWithBindingProjectMemberIndex.BuildMemberSafetyDiagnostics;
var
  i: Integer;
  j: Integer;
  lCandidate: TIndexedDeclarationCandidate;
  lCandidates: TList<TIndexedDeclarationCandidate>;
  lDeclaration: TDelphiSemanticDeclaration;
  lDiagnostic: TDelphiSemanticModelDiagnostic;
  lFact: TMemberSafetyDiagnostic;
  lIndex: Integer;
  lModelIndexes: TArray<Integer>;
  lModel: TDelphiSemanticUnitModel;
  lOwnerFileName: string;
  lProfile: TDelphiSemanticCompilerProfile;
  lSymbol: TDelphiSemanticIntrinsicSymbol;
begin
  fMemberSafetyDiagnostics := nil;
  fActivityMemberFacts := nil;
  fSafetyDeclarationsByName := TObjectDictionary<string,
    TList<TIndexedDeclarationCandidate>>.Create([doOwnsValues],
    TFastCaseAwareComparer.OrdinalIgnoreCase);
  fSafetyModelsByUnit := TDictionary<string, TArray<Integer>>.Create(
    TFastCaseAwareComparer.OrdinalIgnoreCase);
  fSafetyProfileTypes := TDictionary<string, Byte>.Create(
    TFastCaseAwareComparer.OrdinalIgnoreCase);
  lProfile := TDelphiSemanticCompilerProfileBuilder.DefaultProfile('');
  for lSymbol in lProfile.IntrinsicSymbols do
    if SameText(lSymbol.Kind, 'intrinsic-type') and
      (SameText(lSymbol.OwnerName, 'compiler') or
      SameText(lSymbol.OwnerName, 'rtl')) then
      fSafetyProfileTypes.AddOrSetValue(lSymbol.Name, 0);
  for i := 0 to High(fModels) do
  begin
    lModel := fModels[i];
    lModelIndexes := nil;
    fSafetyModelsByUnit.TryGetValue(lModel.UnitName, lModelIndexes);
    lIndex := Length(lModelIndexes);
    SetLength(lModelIndexes, lIndex + 1);
    lModelIndexes[lIndex] := i;
    fSafetyModelsByUnit.AddOrSetValue(lModel.UnitName, lModelIndexes);
    for j := 0 to High(lModel.Declarations) do
    begin
      lDeclaration := lModel.Declarations[j];
      if not fSafetyDeclarationsByName.TryGetValue(lDeclaration.Name, lCandidates) then
      begin
        lCandidates := TList<TIndexedDeclarationCandidate>.Create;
        fSafetyDeclarationsByName.Add(lDeclaration.Name, lCandidates);
      end;
      lCandidate.ModelIndex := i;
      lCandidate.DeclarationIndex := j;
      lCandidates.Add(lCandidate);
    end;
  end;
  for lModel in fModels do
    for lDiagnostic in lModel.Diagnostics do
    begin
      if not (SameText(lDiagnostic.Code, 'MEMBERS_UNVERIFIED') or
        SameText(lDiagnostic.Code, 'MEMBERS_INCOMPLETE') or
        SameText(lDiagnostic.Code, 'MEMBERS_ACTIVITY_UNVERIFIED')) then
        Continue;
      lFact := Default(TMemberSafetyDiagnostic);
      lFact.Code := lDiagnostic.Code;
      lFact.UnitName := lModel.UnitName;
      lFact.FileName := lDiagnostic.FileName;
      lFact.Line := lDiagnostic.Line;
      if MatchText(lDiagnostic.Code, ['MEMBERS_INCOMPLETE', 'MEMBERS_ACTIVITY_UNVERIFIED']) and
        (lDiagnostic.FileName <> '') and (lDiagnostic.Line > 0) then
        for lDeclaration in lModel.Declarations do
        begin
          lOwnerFileName := lDeclaration.FileName;
          if lOwnerFileName = '' then
            lOwnerFileName := lModel.FileName;
          if SameText(lDiagnostic.FileName, lOwnerFileName) and
            (lDiagnostic.Line = lDeclaration.Line) and
            SameText(lDeclaration.Kind, 'type') and
            (SameText(lDeclaration.TypeName, 'record') or
            SameText(lDeclaration.TypeName, 'class') or
            SameText(lDeclaration.TypeName, 'interface')) then
          begin
            if lFact.OwnerName <> '' then
              lFact.OwnerResolved := False
            else
            begin
              lFact.OwnerName := lDeclaration.Name;
              lFact.OwnerResolved := True;
            end;
          end;
        end;
      if SameText(lFact.Code, 'MEMBERS_ACTIVITY_UNVERIFIED') then
      begin
        lIndex := Length(fActivityMemberFacts);
        SetLength(fActivityMemberFacts, lIndex + 1);
        fActivityMemberFacts[lIndex] := lFact;
      end else begin
        lIndex := Length(fMemberSafetyDiagnostics);
        SetLength(fMemberSafetyDiagnostics, lIndex + 1);
        fMemberSafetyDiagnostics[lIndex] := lFact;
      end;
    end;
end;

function TWithBindingProjectMemberIndex.LineageHasActivityFact(
  const aLineage: TArray<TDelphiSemanticTypeIdentity>): Boolean;
var
  lIdentity: TDelphiSemanticTypeIdentity;
  lFact: TMemberSafetyDiagnostic;
begin
  for lIdentity in aLineage do
    for lFact in fActivityMemberFacts do
      if SameText(lIdentity.UnitName, lFact.UnitName) and
        ((not lFact.OwnerResolved) or
        (SameText(lIdentity.Name, lFact.OwnerName) and
        (lIdentity.SourceRange.Line = lFact.Line) and
        SameText(lIdentity.SourceRange.FileName, lFact.FileName))) then
        Exit(True);
  Result := False;
end;

function TWithBindingProjectMemberIndex.MemberActivityIsUnverified(
  const aBinding: TDelphiSemanticWithBinding;
  const aSelectorIdentities: TArray<TDelphiSemanticTypeIdentity>): Boolean;
var
  i: Integer;
  lLineage: TArray<TDelphiSemanticTypeIdentity>;
begin
  for i := 0 to High(aBinding.Selectors) do
  begin
    if SameText(aBinding.Selectors[i].ReasonCode,
      'SELECTOR_MEMBERS_ACTIVITY_UNVERIFIED') then
      Exit(True);
    if i >= Length(aSelectorIdentities) then
      Continue;
    // A failed walk still supplies the verified prefix, which can carry a fact.
    TryBuildMemberSafetyLineage(aBinding, aBinding.Selectors[i].TypeName,
      aSelectorIdentities[i], lLineage);
    if LineageHasActivityFact(lLineage) then
      Exit(True);
  end;
  Result := False;
end;

function TWithBindingProjectMemberIndex.IsKnownSafetyProfileTerminal(
  const aName: string; const aLookup: TDelphiSemanticTypeLookupResult): Boolean;
begin
  Result := (Pos('.', aName) = 0) and (not aLookup.Found) and
    (not aLookup.Ambiguous) and SameText(aLookup.ReasonCode, 'TYPE_NOT_FOUND') and
    (not fSafetyDeclarationsByName.ContainsKey(aName)) and
    fSafetyProfileTypes.ContainsKey(aName);
end;

function TWithBindingProjectMemberIndex.TrySafetyDeclarationModel(
  const aIdentity: TDelphiSemanticTypeIdentity;
  out aModel: TDelphiSemanticUnitModel): Boolean;
var
  lCandidate: TIndexedDeclarationCandidate;
  lCandidates: TList<TIndexedDeclarationCandidate>;
  lDeclaration: TDelphiSemanticDeclaration;
  lFileName: string;
  lMatchCount: Integer;
  lModel: TDelphiSemanticUnitModel;
begin
  Result := False;
  aModel := Default(TDelphiSemanticUnitModel);
  if not fSafetyDeclarationsByName.TryGetValue(aIdentity.Name, lCandidates) then
    Exit;
  lMatchCount := 0;
  for lCandidate in lCandidates do
  begin
    lModel := fModels[lCandidate.ModelIndex];
    lDeclaration := lModel.Declarations[lCandidate.DeclarationIndex];
    lFileName := lDeclaration.FileName;
    if lFileName = '' then
      lFileName := lModel.FileName;
    if SameText(lModel.UnitName, aIdentity.UnitName) and
      SameText(lFileName, aIdentity.SourceRange.FileName) and
      (lDeclaration.Line = aIdentity.SourceRange.Line) and
      (lDeclaration.Column = aIdentity.SourceRange.Column) and
      SameText(lDeclaration.ScopeKind, aIdentity.ScopeKind) and
      SameText(lDeclaration.OwnerScopeId, aIdentity.OwnerScopeId) and
      SameText(lDeclaration.SymbolId, aIdentity.SemanticSymbolId) and
      SameText(lDeclaration.SectionKind, aIdentity.SectionKind) then
    begin
      Inc(lMatchCount);
      aModel := lModel;
    end;
  end;
  Result := lMatchCount = 1;
end;

function AnonymousRecordMembersAreProven(const aModel: TDelphiSemanticUnitModel;
  const aTypeName: string; const aHeaderLine: Integer): Boolean;
var
  i: Integer;
  lFieldMatch: TMatch;
  lLine: string;
  lLines: TArray<string>;
  lMember: TDelphiSemanticMember;
  lModelCount: Integer;
  lName: string;
  lNames: TDictionary<string, Byte>;
begin
  // The extractor scans an anonymous record body line by line up to the first
  // 'end;', so nested records, variant parts, comments or several statements on a
  // line can hide or misattribute fields. We accept only bodies made of plain
  // one-line field declarations whose names match the extracted member list.
  Result := False;
  lLines := aModel.SourceText.Split([#13#10, #10]);
  if (aHeaderLine < 1) or (aHeaderLine >= Length(lLines)) or
    (not TRegEx.IsMatch(lLines[aHeaderLine - 1],
    '^\s*&?[A-Za-z_][A-Za-z0-9_]*\s*:\s*(?:packed\s+)?record\s*$', [roIgnoreCase])) then
    Exit;
  lNames := TDictionary<string, Byte>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
  try
    for i := aHeaderLine to High(lLines) do
    begin
      lLine := Trim(lLines[i]);
      if lLine = '' then
        Continue;
      if TRegEx.IsMatch(lLine, '^end\s*;$', [roIgnoreCase]) then
      begin
        lModelCount := 0;
        for lMember in aModel.Members do
          if SameText(lMember.OwnerName, aTypeName) then
          begin
            Inc(lModelCount);
            if not lNames.ContainsKey(lMember.Name) then
              Exit(False);
          end;
        Exit((lNames.Count > 0) and (lModelCount = lNames.Count));
      end;
      lFieldMatch := TRegEx.Match(lLine,
        '^([A-Za-z_][A-Za-z0-9_]*(?:\s*,\s*[A-Za-z_][A-Za-z0-9_]*)*)\s*:\s*([^;]+);$',
        [roIgnoreCase]);
      if (not lFieldMatch.Success) or TRegEx.IsMatch(lFieldMatch.Groups[2].Value,
        '\b(?:record|case|end|class|object|interface)\b|[{}()/'']', [roIgnoreCase]) then
        Exit(False);
      for lName in lFieldMatch.Groups[1].Value.Split([',']) do
        if not lNames.TryAdd(Trim(lName), 0) then
          Exit(False);
    end;
  finally
    lNames.Free;
  end;
end;

function TWithBindingProjectMemberIndex.TryResolveAnonymousMemberTypeIdentity(
  const aDeclaringModel: TDelphiSemanticUnitModel;
  const aMember: TDelphiSemanticResolveResult;
  out aIdentity: TDelphiSemanticTypeIdentity): Boolean;
var
  lLookup: TDelphiSemanticTypeLookupResult;
  lModel: TDelphiSemanticUnitModel;
begin
  // An anonymous record field declares its type as <Owner>.<Member> in the
  // declaring unit, on the member's own name token (the extracted declaration
  // column may sit inside that token). Only that declaration identifies it; a
  // name-only or relocated match stays unproven.
  Result := False;
  aIdentity := Default(TDelphiSemanticTypeIdentity);
  if (not SameText(aMember.Kind, 'field')) or (aMember.OwnerName = '') or
    (aMember.Name = '') or (aDeclaringModel.UnitName = '') or
    (aMember.Line <= 0) or (aMember.Column <= 0) or
    (not SameText(aMember.TypeName, aMember.OwnerName + '.' + aMember.Name)) then
    Exit;
  lLookup := fTypeIndex.ResolveQualifiedName(aDeclaringModel.UnitName + '.' +
    aMember.TypeName);
  Result := lLookup.Found and (not lLookup.Ambiguous) and
    SameText(lLookup.Identity.UnitName, aDeclaringModel.UnitName) and
    SameText(lLookup.Identity.Name, aMember.TypeName) and
    SameText(lLookup.Identity.Kind, 'type') and
    SameText(lLookup.Identity.CanonicalName, 'record') and
    (not SameText(lLookup.Identity.ScopeKind, 'routine')) and
    SameText(lLookup.Identity.SourceRange.FileName, aDeclaringModel.FileName) and
    (lLookup.Identity.SourceRange.Line = aMember.Line) and
    (lLookup.Identity.SourceRange.Column >= aMember.Column) and
    (lLookup.Identity.SourceRange.Column < aMember.Column + Length(aMember.Name)) and
    TrySafetyDeclarationModel(lLookup.Identity, lModel) and
    AnonymousRecordMembersAreProven(aDeclaringModel, aMember.TypeName, aMember.Line);
  if Result then
    aIdentity := lLookup.Identity;
end;

function TWithBindingProjectMemberIndex.TryResolveUniqueExportedFinalType(
  const aOriginModel: TDelphiSemanticUnitModel; const aTypeName: string;
  out aIdentity: TDelphiSemanticTypeIdentity): Boolean;
var
  lCandidate: TIndexedDeclarationCandidate;
  lCandidates: TList<TIndexedDeclarationCandidate>;
  lDeclaration: TDelphiSemanticDeclaration;
  lFinalDeclaration: TDelphiSemanticDeclaration;
  lFileName: string;
  lLookup: TDelphiSemanticTypeLookupResult;
  lMatchCount: Integer;
  lModel: TDelphiSemanticUnitModel;
  lModelIndexes: TArray<Integer>;
begin
  Result := False;
  aIdentity := Default(TDelphiSemanticTypeIdentity);
  lFinalDeclaration := Default(TDelphiSemanticDeclaration);
  lModelIndexes := nil;
  if (aOriginModel.UnitName = '') or
    (not TRegEx.IsMatch(aTypeName, '^[A-Za-z_][A-Za-z0-9_]*$')) or
    (not fSafetyModelsByUnit.TryGetValue(aOriginModel.UnitName, lModelIndexes)) or
    (Length(lModelIndexes) <> 1) or
    (not fSafetyDeclarationsByName.TryGetValue(aTypeName, lCandidates)) then
    Exit;
  lModel := fModels[lModelIndexes[0]];
  lMatchCount := 0;
  for lCandidate in lCandidates do
  begin
    if lCandidate.ModelIndex <> lModelIndexes[0] then
      Continue;
    lDeclaration := lModel.Declarations[lCandidate.DeclarationIndex];
    if SameText(lDeclaration.ScopeKind, 'unit') and
      SameText(lDeclaration.SectionKind, 'interface') and
      SameText(lDeclaration.OwnerScopeId, LowerCase(lModel.UnitName)) and
      (SameText(lDeclaration.Kind, 'type') or
       SameText(lDeclaration.Kind, 'type-alias')) then
    begin
      Inc(lMatchCount);
      if lMatchCount > 1 then
        Exit;
      lFinalDeclaration := lDeclaration;
    end;
  end;
  if lMatchCount <> 1 then
    Exit;
  lLookup := fTypeIndex.ResolveQualifiedName(lModel.UnitName + '.' + aTypeName);
  if (not lLookup.Found) or lLookup.Ambiguous then
    Exit;
  lFileName := lFinalDeclaration.FileName;
  if lFileName = '' then
    lFileName := lModel.FileName;
  Result := SameText(lLookup.Identity.UnitName, lModel.UnitName) and
    SameText(lLookup.Identity.Name, lFinalDeclaration.Name) and
    SameText(lLookup.Identity.Kind, lFinalDeclaration.Kind) and
    SameText(lLookup.Identity.ScopeKind, 'unit') and
    SameText(lLookup.Identity.SectionKind, 'interface') and
    SameText(lLookup.Identity.OwnerScopeId, LowerCase(lModel.UnitName)) and
    SameText(lLookup.Identity.SourceRange.FileName, lFileName) and
    (lLookup.Identity.SourceRange.Line = lFinalDeclaration.Line) and
    (lLookup.Identity.SourceRange.Column = lFinalDeclaration.Column) and
    SameText(lLookup.Identity.SemanticSymbolId, lFinalDeclaration.SymbolId) and
    TrySafetyDeclarationModel(lLookup.Identity, lModel);
  if Result then
    aIdentity := lLookup.Identity;
end;
function TWithBindingProjectMemberIndex.TryResolveSelectorIdentity(
  const aOriginModel: TDelphiSemanticUnitModel;
  const aOriginSectionKind, aOriginScopeId, aTypeName: string;
  out aIdentity: TDelphiSemanticTypeIdentity): Boolean;
var
  lLookup: TDelphiSemanticTypeLookupResult;
  lModel: TDelphiSemanticUnitModel;
  lVisibleUnits: TArray<string>;
begin
  aIdentity := Default(TDelphiSemanticTypeIdentity);
  if (aOriginModel.UnitName = '') or (aTypeName = '') then
    Exit(False);
  if SameText(aOriginSectionKind, 'interface') then
    lVisibleUnits := Copy(aOriginModel.InterfaceUses)
  else if SameText(aOriginSectionKind, 'implementation') then
    lVisibleUnits := CombineUnitUses(aOriginModel.InterfaceUses,
      aOriginModel.ImplementationUses)
  else
    Exit(False);
  if aOriginScopeId <> '' then
    lLookup := fTypeIndex.ResolveScopedName(aTypeName, aOriginModel.UnitName,
      aOriginScopeId, lVisibleUnits, aOriginSectionKind)
  else if Pos('.', aTypeName) > 0 then
    lLookup := fTypeIndex.ResolveQualifiedName(aTypeName)
  else
  begin
    lLookup := fTypeIndex.ResolveVisibleName(aTypeName, aOriginModel.UnitName,
      lVisibleUnits, aOriginSectionKind);
  end;
  Result := lLookup.Found and (not lLookup.Ambiguous) and
    TrySafetyDeclarationModel(lLookup.Identity, lModel);
  if Result then
    aIdentity := lLookup.Identity;
end;

function TWithBindingProjectMemberIndex.TryResolveTypeOriginScope(const aDeclaringModel,
  aOriginModel: TDelphiSemanticUnitModel; const aResolved: TDelphiSemanticResolveResult;
  out aScopeId, aOwnRoutineScopeId: string): Boolean;
var
  lDeclaredTypeName: string;
  lLookup: TDelphiSemanticTypeLookupResult;
  lSameUnit: Boolean;
begin
  Result := TryDeclarationScope(aDeclaringModel, aResolved, aScopeId, lDeclaredTypeName,
    aOwnRoutineScopeId);
  // A unit-level declaration resolves its type names in unit scope.
  if (not Result) or (aScopeId = '') then
    Exit;
  lSameUnit := (aOriginModel.UnitName <> '') and
    SameText(aOriginModel.UnitName, aDeclaringModel.UnitName);
  lDeclaredTypeName := Trim(lDeclaredTypeName);
  if StartsText('^', lDeclaredTypeName) then
    lDeclaredTypeName := Trim(Copy(lDeclaredTypeName, 2, MaxInt));
  if TRegEx.IsMatch(lDeclaredTypeName, '^[A-Za-z_][A-Za-z0-9_]*$') then
  begin
    // Resolve the declared type where it is written. A unit-level type (another unit
    // cannot export a routine-local one) proves that the selector's later type names
    // are unit-level too; a routine-local one cannot leave its own unit.
    lLookup := fTypeIndex.ResolveScopedName(lDeclaredTypeName, aDeclaringModel.UnitName,
      aScopeId, CombineUnitUses(aDeclaringModel.InterfaceUses,
      aDeclaringModel.ImplementationUses), 'implementation');
    if lLookup.Found and (not lLookup.Ambiguous) then
      if SameText(lLookup.Identity.ScopeKind, 'routine') then
      begin
        Result := lSameUnit and ((aOwnRoutineScopeId = '') or
          (not SameText(lLookup.Identity.OwnerScopeId, aOwnRoutineScopeId)));
        if not Result then
          aScopeId := '';
        Exit;
      end else if SameText(lLookup.Identity.ScopeKind, 'unit') or
        ((lLookup.Identity.UnitName <> '') and
        (not SameText(lLookup.Identity.UnitName, aDeclaringModel.UnitName))) then
      begin
        aScopeId := '';
        Exit(True);
      end;
  end;
  // Unproven declared type: the same unit keeps the scoped lookup, which refuses what
  // it cannot prove; another unit's final type cannot be tied to this scope.
  Result := lSameUnit;
  if not Result then
    aScopeId := '';
end;

function TWithBindingProjectMemberIndex.IsUnsupportedRoutineLocalType(
  const aOriginModel: TDelphiSemanticUnitModel;
  const aOriginSectionKind, aOriginScopeId, aTypeName: string): Boolean;
var
  lLookup: TDelphiSemanticTypeLookupResult;
  lVisibleUnits: TArray<string>;
begin
  if (aOriginScopeId = '') or (aOriginModel.UnitName = '') or (aTypeName = '') then
    Exit(False);
  if SameText(aOriginSectionKind, 'interface') then
    lVisibleUnits := Copy(aOriginModel.InterfaceUses)
  else
    lVisibleUnits := CombineUnitUses(aOriginModel.InterfaceUses,
      aOriginModel.ImplementationUses);
  lLookup := fTypeIndex.ResolveScopedName(aTypeName, aOriginModel.UnitName,
    aOriginScopeId, lVisibleUnits, aOriginSectionKind);
  Result := (not lLookup.Found) and SameText(lLookup.ReasonCode, 'UNSUPPORTED_LOCAL_TYPE');
end;

function TWithBindingProjectMemberIndex.TryResolveMemberOwnerIdentity(
  const aSymbol: TDelphiSemanticInventorySymbol;
  out aIdentity, aAccessIdentity: TDelphiSemanticTypeIdentity): Boolean;
var
  lAccessLookup: TDelphiSemanticTypeLookupResult;
  lAccessModel: TDelphiSemanticUnitModel;
  lAccessOwnerName: string;
  lLookup: TDelphiSemanticMemberLookupResult;
  lModel: TDelphiSemanticUnitModel;
  lModelIndex: Integer;
  lModelIndexes: TArray<Integer>;
  lOwnerName: string;
  lSectionKind: string;
begin
  Result := False;
  aIdentity := Default(TDelphiSemanticTypeIdentity);
  aAccessIdentity := Default(TDelphiSemanticTypeIdentity);
  // Constants use the same declared-member origin proof for planner ownership;
  // this inventory enrichment does not alter bound reference classification.
  if (not MatchText(aSymbol.SymbolClass, ['member', 'field', 'constant'])) or
    aSymbol.IsHelper or
    (aSymbol.UnitName = '') or (aSymbol.OwnerName = '') or
    (aSymbol.FileName = '') or (aSymbol.Line <= 0) then
    Exit;
  if aSymbol.OwnerScopeId <> '' then
  begin
    if (aSymbol.OwnerSymbolId = '') or (aSymbol.SourceOwnerType <> '') or
      not fSafetyModelsByUnit.TryGetValue(aSymbol.UnitName, lModelIndexes) then
      Exit;
    for lModelIndex in lModelIndexes do
    begin
      lModel := fModels[lModelIndex];
      if not SameText(lModel.FileName, aSymbol.FileName) then
        Continue;
      lAccessLookup := fTypeIndex.ResolveScopedName(aSymbol.OwnerName,
        aSymbol.UnitName, aSymbol.OwnerScopeId, CombineUnitUses(
        lModel.InterfaceUses, lModel.ImplementationUses), 'implementation');
      if (not lAccessLookup.Found) or lAccessLookup.Ambiguous or
        (not SameText(lAccessLookup.Identity.SemanticSymbolId,
          aSymbol.OwnerSymbolId)) or
        (not TrySafetyDeclarationModel(lAccessLookup.Identity, lAccessModel)) then
        Exit;
      lLookup := fSemanticMemberIndex.ResolveDirectMemberByOwnerId(
        lAccessLookup.Identity.DeclaredId, aSymbol.Name);
      if (not lLookup.Found) or lLookup.Ambiguous or
        (not SameText(lLookup.Member.OwnerSymbolId, aSymbol.OwnerSymbolId)) or
        (not SameText(lLookup.Member.SourceRange.FileName, aSymbol.FileName)) or
        (lLookup.Member.SourceRange.Line <> aSymbol.Line) or
        (lLookup.Member.SourceRange.Column <> aSymbol.Column) then
        Exit;
      aIdentity := lAccessLookup.Identity;
      aAccessIdentity := aIdentity;
      Exit(True);
    end;
    Exit;
  end;
  if aSymbol.SourceOwnerType <> '' then
  begin
    if (aSymbol.AccessOwnerUnitName = '') or
      (aSymbol.AccessOwnerFileName = '') or
      (aSymbol.AccessOwnerLine <= 0) or
      (aSymbol.AccessOwnerColumn <= 0) then
      Exit;
    lAccessOwnerName := aSymbol.AccessOwnerUnitName + '.' + aSymbol.OwnerName;
    lAccessLookup := fTypeIndex.ResolveQualifiedName(lAccessOwnerName);
    if (not lAccessLookup.Found) or lAccessLookup.Ambiguous or
      (not TrySafetyDeclarationModel(lAccessLookup.Identity, lAccessModel)) or
      (not SameText(lAccessLookup.Identity.UnitName, aSymbol.AccessOwnerUnitName)) or
      (not SameText(lAccessLookup.Identity.SourceRange.FileName,
        aSymbol.AccessOwnerFileName)) or
      (lAccessLookup.Identity.SourceRange.Line <> aSymbol.AccessOwnerLine) or
      (lAccessLookup.Identity.SourceRange.Column <> aSymbol.AccessOwnerColumn) or
      ((aSymbol.AccessOwnerSectionKind <> '') and
        (not SameText(lAccessLookup.Identity.SectionKind,
          aSymbol.AccessOwnerSectionKind))) then
      Exit;
  end else
  begin
    lAccessOwnerName := aSymbol.OwnerName;
    if Pos('.', lAccessOwnerName) = 0 then
      lAccessOwnerName := aSymbol.UnitName + '.' + lAccessOwnerName;
  end;
  if SameText(aSymbol.SymbolClass, 'constant') and
    (aSymbol.SourceOwnerType = '') then
  begin
    // DS-710's declared constant facts are inventory members, not graph members.
    // Anchor their explicit owner to the unique verified declaration before D4
    // consumes them; unit/global constants have no type owner and fail here.
    lAccessLookup := fTypeIndex.ResolveQualifiedName(lAccessOwnerName);
    if (not lAccessLookup.Found) or lAccessLookup.Ambiguous or
      (not TrySafetyDeclarationModel(lAccessLookup.Identity, lAccessModel)) or
      (not SameText(lAccessLookup.Identity.UnitName, aSymbol.UnitName)) or
      (not SameText(lAccessLookup.Identity.SourceRange.FileName, aSymbol.FileName)) or
      ((aSymbol.SectionKind <> '') and
        (not SameText(lAccessLookup.Identity.SectionKind, aSymbol.SectionKind))) then
      Exit;
    aIdentity := lAccessLookup.Identity;
    aAccessIdentity := aIdentity;
    Exit(True);
  end;
  lLookup := fSemanticMemberIndex.ResolveMember(lAccessOwnerName, aSymbol.Name);
  if (not lLookup.Found) or lLookup.Ambiguous or
    SameText(lLookup.Status, 'helper') or
    (lLookup.Member.UnitName = '') or (lLookup.Member.OwnerName = '') or
    (not SameText(lLookup.Member.SourceRange.FileName, aSymbol.FileName)) or
    (lLookup.Member.SourceRange.Line <> aSymbol.Line) or
    (lLookup.Member.SourceRange.Column <> aSymbol.Column) then
    Exit;
  if not fSafetyModelsByUnit.TryGetValue(lLookup.Member.UnitName, lModelIndexes) then
    Exit;
  lOwnerName := lLookup.Member.UnitName + '.' + lLookup.Member.OwnerName;
  for lModelIndex in lModelIndexes do
  begin
    lModel := fModels[lModelIndex];
    if not SameText(lModel.FileName, aSymbol.FileName) then
      Continue;
    lSectionKind := aSymbol.SectionKind;
    if lSectionKind = '' then
      lSectionKind := 'interface';
    Result := TryResolveSelectorIdentity(lModel, lSectionKind, '',
      lOwnerName, aIdentity);
    if Result then
    begin
      if aSymbol.SourceOwnerType <> '' then
        aAccessIdentity := lAccessLookup.Identity
      else
        aAccessIdentity := aIdentity;
    end;
    Exit;
  end;
end;

function TWithBindingProjectMemberIndex.TryBuildMemberSafetyLineage(
  const aBinding: TDelphiSemanticWithBinding;
  const aSelectorTypeName: string; const aSelectorIdentity: TDelphiSemanticTypeIdentity;
  out aLineage: TArray<TDelphiSemanticTypeIdentity>): Boolean;
var
  lCurrent: TDelphiSemanticTypeIdentity;
  lIdentityId: string;
  lIndex: Integer;
  lLookup: TDelphiSemanticTypeLookupResult;
  lModel: TDelphiSemanticUnitModel;
  lModelIndex: Integer;
  lModelIndexes: TArray<Integer>;
  lSeenIds: TDictionary<string, Byte>;
  lTargetName: string;
  lVisibleUnits: TArray<string>;
begin
  Result := False;
  aLineage := nil;
  if not fSafetyModelsByUnit.TryGetValue(aBinding.UnitName, lModelIndexes) then
    Exit;
  lIndex := -1;
  for lModelIndex in lModelIndexes do
    if SameText(fModels[lModelIndex].FileName, aBinding.FileName) then
    begin
      if lIndex >= 0 then
        Exit;
      lIndex := lModelIndex;
    end;
  if lIndex < 0 then
    Exit;
  lModel := fModels[lIndex];
  if aSelectorIdentity.DeclaredId.Value = '' then
  begin
    lVisibleUnits := CombineUnitUses(lModel.InterfaceUses, lModel.ImplementationUses);
    lLookup := fTypeIndex.ResolveVisibleName(aSelectorTypeName,
      lModel.UnitName, lVisibleUnits, 'implementation');
    Exit(IsKnownSafetyProfileTerminal(aSelectorTypeName, lLookup));
  end;
  lCurrent := aSelectorIdentity;
  lSeenIds := TDictionary<string, Byte>.Create(
    TFastCaseAwareComparer.OrdinalIgnoreCase);
  try
    while True do
    begin
      lIdentityId := lCurrent.DeclaredId.Value;
      if (lIdentityId = '') or lSeenIds.ContainsKey(lIdentityId) or
        (not TrySafetyDeclarationModel(lCurrent, lModel)) then
        Exit;
      lSeenIds.Add(lIdentityId, 0);
      lIndex := Length(aLineage);
      SetLength(aLineage, lIndex + 1);
      aLineage[lIndex] := lCurrent;
      if SameText(lCurrent.Kind, 'type-alias') then
        lTargetName := lCurrent.CanonicalName
      else
        lTargetName := lCurrent.BaseTypeName;
      if (lTargetName <> '') and (lTargetName[1] = '^') then
        lTargetName := Copy(lTargetName, 2, MaxInt).Trim;
      if lTargetName = '' then
      begin
        Result := not SameText(lCurrent.Kind, 'type-alias');
        Exit;
      end;
      if SameText(lCurrent.ScopeKind, 'routine') then
      begin
        if SameText(lCurrent.SectionKind, 'interface') then
          lVisibleUnits := Copy(lModel.InterfaceUses)
        else if SameText(lCurrent.SectionKind, 'implementation') then
          lVisibleUnits := CombineUnitUses(lModel.InterfaceUses,
            lModel.ImplementationUses)
        else
          Exit;
        lLookup := fTypeIndex.ResolveScopedName(lTargetName,
          lCurrent.UnitName, lCurrent.OwnerScopeId, lVisibleUnits,
          lCurrent.SectionKind);
      end else if Pos('.', lTargetName) > 0 then
        lLookup := fTypeIndex.ResolveQualifiedName(lTargetName)
      else
      begin
        if SameText(lCurrent.SectionKind, 'interface') then
          lVisibleUnits := Copy(lModel.InterfaceUses)
        else if SameText(lCurrent.SectionKind, 'implementation') then
          lVisibleUnits := CombineUnitUses(lModel.InterfaceUses,
            lModel.ImplementationUses)
        else
          Exit;
        lLookup := fTypeIndex.ResolveVisibleName(lTargetName,
          lCurrent.UnitName, lVisibleUnits, lCurrent.SectionKind);
      end;
      if (not lLookup.Found) or lLookup.Ambiguous then
        Exit(IsKnownSafetyProfileTerminal(lTargetName, lLookup));
      lCurrent := lLookup.Identity;
    end;
  finally
    lSeenIds.Free;
  end;
end;

function TWithBindingProjectMemberIndex.UnitRoutineDeclarationIsVerified(
  const aModel: TDelphiSemanticUnitModel;
  const aDeclaration: TDelphiSemanticDeclaration): Boolean;
var
  lMatchCount: Integer;
  lDeclarationFileName: string;
  lRoutine: TDelphiSemanticRoutine;
  lRoutineFileName: string;
begin
  lMatchCount := 0;
  if (not SameText(aDeclaration.Kind, 'routine')) or
    (aDeclaration.Line <= 0) or (aDeclaration.Column <= 0) or
    (not SameText(aDeclaration.ScopeKind, 'unknown')) or
    (aDeclaration.OwnerName <> '') or (aDeclaration.OwnerScopeId <> '') or
    (not MatchText(aDeclaration.SectionKind, ['interface', 'implementation'])) then
    Exit(False);
  lDeclarationFileName := aDeclaration.FileName;
  if lDeclarationFileName = '' then
    lDeclarationFileName := aModel.FileName;
  if lDeclarationFileName = '' then
    Exit(False);
  for lRoutine in aModel.Routines do
    if SameText(lRoutine.Name, aDeclaration.Name) and
      (lRoutine.Line = aDeclaration.Line) and (lRoutine.Column = aDeclaration.Column) then
    begin
      lRoutineFileName := lRoutine.FileName;
      if lRoutineFileName = '' then
        lRoutineFileName := aModel.FileName;
      if (lRoutine.OwnerName <> '') or (lRoutine.ParentScopeId <> '') or
        (not SameText(lDeclarationFileName, lRoutineFileName)) or
        (not SameText(aDeclaration.SectionKind, lRoutine.SectionKind)) or
        (lRoutine.ScopeId = '') or (not lRoutine.AstSourceSignatureVerified) or
        (not MatchText(lRoutine.AstScopeKind, ['header', 'body'])) then
        Exit(False);
      Inc(lMatchCount);
    end;
  Result := lMatchCount = 1;
end;

function TWithBindingProjectMemberIndex.IsVerifiedRecordHelper(
  const aModel: TDelphiSemanticUnitModel;
  const aDeclaration: TDelphiSemanticDeclaration): Boolean;
var
  lIdentity: TDelphiSemanticTypeIdentity;
  lLookup: TDelphiSemanticTypeLookupResult;
  lTargetModel: TDelphiSemanticUnitModel;
  lVisibleUnits: TArray<string>;
begin
  Result := False;
  if (not SameText(aDeclaration.AstHelperKind, 'record')) or
    (not SameText(aDeclaration.DeclarationRole, 'declaration')) or
    (not SameText(aDeclaration.ScopeKind, 'unit')) or
    (not SameText(aDeclaration.OwnerName, aModel.UnitName)) or
    (not SameText(aDeclaration.OwnerScopeId, aModel.UnitName)) or
    (aDeclaration.HelperTargetName = '') then
    Exit;
  if SameText(aDeclaration.SectionKind, 'interface') then
    lVisibleUnits := Copy(aModel.InterfaceUses)
  else if SameText(aDeclaration.SectionKind, 'implementation') then
    lVisibleUnits := CombineUnitUses(aModel.InterfaceUses, aModel.ImplementationUses)
  else
    Exit;
  lLookup := fTypeIndex.ResolveVisibleName(aDeclaration.HelperTargetName,
    aModel.UnitName, lVisibleUnits, aDeclaration.SectionKind);
  if (not lLookup.Found) or lLookup.Ambiguous then
    Exit;
  lIdentity := lLookup.Identity;
  // DS-715: only a direct unit record is exempt; aliases and local/nested homonyms refuse.
  if (not SameText(lIdentity.Kind, 'type')) or
    (not SameText(lIdentity.ScopeKind, 'unit')) or
    (not MatchText(lIdentity.UnderlyingName, ['record', 'packed record'])) or
    (lIdentity.BaseTypeName <> '') or (lIdentity.HelperTargetName <> '') then
    Exit;
  Result := TrySafetyDeclarationModel(lIdentity, lTargetModel);
end;

function TWithBindingProjectMemberIndex.HasClosedRootSourceContext(
  const aContextModel: TDelphiSemanticUnitModel): Boolean;
var
  g: TGarbos;
  lDeclaration: TDelphiSemanticDeclaration;
  lDiagnostic: TMemberSafetyDiagnostic;
  lIndexes: TArray<Integer>;
  lInvalidRoutineCount: Integer;
  lModel: TDelphiSemanticUnitModel;
  lPending: TQueue<string>;
  lUnitName: string;
  lUsedUnit: string;
  lVisited: THashSet<string>;
begin
  Result := False;
  GC(lPending, TQueue<string>.Create, g);
  GC(lVisited, THashSet<string>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase), g);
  lPending.Enqueue(aContextModel.UnitName);
  while lPending.Count > 0 do
  begin
    lUnitName := lPending.Dequeue;
    if not lVisited.Add(lUnitName) then
      Continue;
    if (not fSafetyModelsByUnit.TryGetValue(lUnitName, lIndexes)) or
      (Length(lIndexes) <> 1) then
      Exit;
    lModel := fModels[lIndexes[0]];
    if (not lModel.Success) or (not SameText(lModel.ScopeModelStatus, 'ast')) or
      SameText(lModel.UnitName, 'System') then
      Exit;
    lInvalidRoutineCount := 0;
    for lDeclaration in lModel.Declarations do
    begin
      if MatchText(lDeclaration.Kind, ['type', 'type-alias']) then
      begin
        // DS-716: an empty or unknown AST kind cannot establish helper absence.
        if not SameText(lDeclaration.AstHelperKind, 'none') then
        begin
          if not IsVerifiedRecordHelper(lModel, lDeclaration) then
            Exit;
        end else if lDeclaration.HelperTargetName <> '' then
          Exit;
      end else if lDeclaration.HelperTargetName <> '' then
        Exit;
      if SameText(lDeclaration.DeclarationRole, 'invalid') then
      begin
        // DS-715: only uniquely matched, source-verified unit routine headers
        // may lack declaration IDs. Unknown/local/type omissions cannot prove closure.
        if not UnitRoutineDeclarationIsVerified(lModel, lDeclaration) then
          Exit;
        Inc(lInvalidRoutineCount);
      end;
    end;
    if lModel.RejectedDeclarationCount <> lInvalidRoutineCount then
      Exit;
    for lDiagnostic in fMemberSafetyDiagnostics do
      if SameText(lDiagnostic.UnitName, lModel.UnitName) and
        ((not lDiagnostic.OwnerResolved) or
        SameText(lDiagnostic.Code, 'MEMBERS_UNVERIFIED') or
        SameText(lDiagnostic.Code, 'MEMBERS_INCOMPLETE')) then
        Exit;
    for lUsedUnit in lModel.InterfaceUses do
      lPending.Enqueue(lUsedUnit);
    for lUsedUnit in lModel.ImplementationUses do
      lPending.Enqueue(lUsedUnit);
  end;
  Result := True;
end;

function TWithBindingProjectMemberIndex.ReceiverMemberAbsenceIsVerified(
  const aModel: TDelphiSemanticUnitModel;
  const aSelector: TDelphiSemanticWithSelectorBinding; const aName: string): Boolean;
var
  lBinding: TDelphiSemanticWithBinding;
  lDirectLookup: TDelphiSemanticMemberLookupResult;
  lFact: TMemberSafetyDiagnostic;
  lIdentity: TDelphiSemanticTypeIdentity;
  lLineage: TArray<TDelphiSemanticTypeIdentity>;
  lOwnerModel: TDelphiSemanticUnitModel;
begin
  Result := False;
  lBinding := Default(TDelphiSemanticWithBinding);
  lBinding.UnitName := aModel.UnitName;
  lBinding.FileName := aModel.FileName;
  if not TryBuildMemberSafetyLineage(lBinding, aSelector.TypeName,
    aSelector.TypeIdentity, lLineage) or (Length(lLineage) = 0) then
    Exit;
  if LineageHasActivityFact(lLineage) then
    Exit;
  for lIdentity in lLineage do
    for lFact in fMemberSafetyDiagnostics do
      if SameText(lIdentity.UnitName, lFact.UnitName) and
        (SameText(lFact.Code, 'MEMBERS_UNVERIFIED') or (not lFact.OwnerResolved) or
        (SameText(lIdentity.Name, lFact.OwnerName) and
        (lIdentity.SourceRange.Line = lFact.Line) and
        SameText(lIdentity.SourceRange.FileName, lFact.FileName))) then
        Exit;
  // Root evidence covers only the implicit root, never indexed declarations.
  for lIdentity in lLineage do
  begin
    lDirectLookup := fSemanticMemberIndex.ResolveDirectMember(
      lIdentity.UnitName + '.' + lIdentity.Name, aName);
    if (not SameText(lDirectLookup.Status, 'unresolved')) or
      (not SameText(lDirectLookup.ReasonCode, 'DIRECT_MEMBER_NOT_FOUND')) then
      Exit;
  end;
  lIdentity := lLineage[High(lLineage)];
  // DS-700: compiler-profile terminals verify a type name, not its member set.
  // An implicit class root can also own a missing name. Only an indexed root
  // record proves absence without consulting an unindexed ancestor.
  Result := SameText(lIdentity.Kind, 'type') and (lIdentity.BaseTypeName = '') and
    (lIdentity.HelperTargetName = '') and
    MatchText(lIdentity.UnderlyingName, ['record', 'packed record']);
  if Result then
    Exit;
  if (fRootMemberAbsence = nil) or (aName = '') or
    (not HasClosedRootSourceContext(aModel)) or
    (not SameText(lIdentity.Kind, 'type')) or
    (not SameText(lIdentity.UnderlyingName, 'class')) or
    (lIdentity.BaseTypeName <> '') or (lIdentity.HelperTargetName <> '') then
    Exit;
  for lIdentity in lLineage do
    if (not TrySafetyDeclarationModel(lIdentity, lOwnerModel)) or
      (not HasClosedRootSourceContext(lOwnerModel)) then
      Exit;
  // The root is implicit by Delphi class syntax, never an unindexed named base.
  try
    if fRootMemberAbsence.EvidenceFingerprint = '' then
      Exit;
    Result := fRootMemberAbsence.IsNameAbsent(aName);
  except
    on E: Exception do
      // External evidence failure preserves the caller's unsupported diagnostic.
      Result := False;
  end;
end;

function TWithBindingProjectMemberIndex.TryResolveVerifiedSimpleMember(
  const aModel: TDelphiSemanticUnitModel;
  const aSelectors: TArray<TDelphiSemanticWithSelectorBinding>;
  const aCurrentTypeName, aMemberCachePrefix, aName: string;
  const aMemberCache: TDictionary<string, TBoundMemberResolution>;
  out aResult: TBoundMemberResolution): Boolean;
var
  i: Integer;
  lBinding: TDelphiSemanticWithBinding;
  lContext: TDelphiSemanticMemberLookupContext;
  lIdentity: TDelphiSemanticTypeIdentity;
  lKey: string;
  lLineage: TArray<TDelphiSemanticTypeIdentity>;
  lLineageIdentity: TDelphiSemanticTypeIdentity;
  lLookup: TDelphiSemanticMemberLookupResult;
  lDirectLookup: TDelphiSemanticMemberLookupResult;
  lOwner: TDelphiSemanticTypeLookupResult;
  lOwnerModel: TDelphiSemanticUnitModel;
  lVerifiedOwner: Boolean;
  function Blocked: Boolean;
  begin
    aResult := Default(TBoundMemberResolution);
    aResult.Value.Status := 'unsupported';
    aResult.Value.Name := aName;
    aResult.Value.ReasonCode := 'PARENT_SELECTOR_UNRESOLVED';
    aResult.Value.Reason := 'The parent WITH selector or its member cannot be proven.';
    Result := True;
  end;
begin
  aResult := Default(TBoundMemberResolution);
  lBinding := Default(TDelphiSemanticWithBinding);
  lBinding.UnitName := aModel.UnitName;
  lBinding.FileName := aModel.FileName;
  for i := High(aSelectors) downto 0 do
  begin
    lIdentity := aSelectors[i].TypeIdentity;
    if (not SameText(aSelectors[i].Status, 'resolved')) or
      (lIdentity.UnitName = '') or (lIdentity.Name = '') or
      (lIdentity.DeclaredId.Value = '') or
      (lIdentity.CanonicalId.Value = '') or
      (lIdentity.SectionKind = '') or
      (lIdentity.SourceRange.FileName = '') or
      (lIdentity.SourceRange.Line <= 0) or
      (lIdentity.SourceRange.Column <= 0) or
      (not fSemanticMemberIndexAvailable) then
      Exit(Blocked);
    if SameText(lIdentity.ScopeKind, 'routine') then
    begin
      lOwner := Default(TDelphiSemanticTypeLookupResult);
      lOwner.Found := fTypeIndex.FindByDeclaredId(lIdentity.DeclaredId,
        lOwner.Identity);
    end else
      lOwner := fTypeIndex.ResolveQualifiedName(lIdentity.UnitName + '.' +
        lIdentity.Name);
    if (not lOwner.Found) or lOwner.Ambiguous or
      (lOwner.Identity.DeclaredId.Value <> lIdentity.DeclaredId.Value) or
      (lOwner.Identity.CanonicalId.Value <> lIdentity.CanonicalId.Value) or
      (not SameText(lOwner.Identity.ScopeKind, lIdentity.ScopeKind)) or
      (not SameText(lOwner.Identity.OwnerScopeId, lIdentity.OwnerScopeId)) or
      (not SameText(lOwner.Identity.SemanticSymbolId,
        lIdentity.SemanticSymbolId)) or
      (not SameText(lOwner.Identity.SectionKind, lIdentity.SectionKind)) or
      (not SameText(lOwner.Identity.SourceRange.FileName,
        lIdentity.SourceRange.FileName)) or
      (lOwner.Identity.SourceRange.Line <> lIdentity.SourceRange.Line) or
      (lOwner.Identity.SourceRange.Column <> lIdentity.SourceRange.Column) or
      (lOwner.Identity.SourceRange.EndLine <> lIdentity.SourceRange.EndLine) or
      (lOwner.Identity.SourceRange.EndColumn <> lIdentity.SourceRange.EndColumn) or
      (not TrySafetyDeclarationModel(lIdentity, lOwnerModel)) or
      (not TryBuildMemberSafetyLineage(lBinding, aSelectors[i].TypeName,
        lIdentity, lLineage)) then
      Exit(Blocked);
    lKey := aMemberCachePrefix + #31 + 'verified-simple' + #31 +
      IntToStr(i) + #31 + lIdentity.UnitName + #31 +
      lIdentity.DeclaredId.Value + #31 + lIdentity.CanonicalId.Value + #31 +
      lIdentity.SectionKind + #31 + lIdentity.SourceRange.FileName + #31 +
      IntToStr(lIdentity.SourceRange.Line) + #31 +
      IntToStr(lIdentity.SourceRange.Column) + #31 +
      IntToStr(lIdentity.SourceRange.EndLine) + #31 +
      IntToStr(lIdentity.SourceRange.EndColumn) + #31 + aName;
    if Assigned(aMemberCache) and aMemberCache.TryGetValue(lKey, aResult) then
    begin
      if aResult.Value.Found or (aResult.Value.Status <> '') then
        Exit(True);
      Continue;
    end;
    lContext := Default(TDelphiSemanticMemberLookupContext);
    lContext.CallerUnitName := aModel.UnitName;
    lContext.CurrentTypeName := aCurrentTypeName;
    lContext.InstanceContext := True;
    if SameText(lIdentity.ScopeKind, 'routine') then
    begin
      lLookup := fSemanticMemberIndex.ResolveDirectMemberByOwnerId(
        lIdentity.DeclaredId, aName);
      if not lLookup.Found then
        for lLineageIdentity in lLineage do
          if lLineageIdentity.DeclaredId.Value <> lIdentity.DeclaredId.Value then
          begin
            lLookup := fSemanticMemberIndex.ResolveDirectMemberByOwnerId(
              lLineageIdentity.DeclaredId, aName);
            if lLookup.Found or lLookup.Ambiguous then
              Break;
          end;
    end else
      lLookup := fSemanticMemberIndex.ResolveMember(lContext,
        lIdentity.UnitName + '.' + lIdentity.Name, aName);
    if lLookup.Found and (not SameText(lLookup.Status, 'helper')) then
    begin
      lVerifiedOwner := False;
      for lIdentity in lLineage do
        if ((lLookup.Member.OwnerDeclaredId.Value <> '') and
          SameText(lIdentity.DeclaredId.Value,
            lLookup.Member.OwnerDeclaredId.Value)) or
          ((lLookup.Member.OwnerDeclaredId.Value = '') and
            SameText(lIdentity.UnitName, lLookup.Member.UnitName) and
            SameText(lIdentity.Name, lLookup.Member.OwnerName)) then
        begin
          lVerifiedOwner := True;
          Break;
        end;
      if lVerifiedOwner and
        ResolveResultFromMemberLookup(aName, lLookup, aResult.Value) then
      begin
        aResult.DeclaringUnitName := lLookup.Member.UnitName;
        if Assigned(aMemberCache) then
          aMemberCache.AddOrSetValue(lKey, aResult);
        Exit(True);
      end;
    end;
    if SameText(lLookup.Status, 'unresolved') and
      SameText(lLookup.ReasonCode, 'DIRECT_MEMBER_NOT_FOUND') then
    begin
      if not ReceiverMemberAbsenceIsVerified(aModel, aSelectors[i], aName) then
        Exit(Blocked);
      for lLineageIdentity in lLineage do
      begin
        lDirectLookup := fSemanticMemberIndex.ResolveDirectMember(
          lLineageIdentity.UnitName + '.' + lLineageIdentity.Name, aName);
        if (not SameText(lDirectLookup.Status, 'unresolved')) or
          (not SameText(lDirectLookup.ReasonCode, 'DIRECT_MEMBER_NOT_FOUND')) then
          Exit(Blocked);
      end;
      if Assigned(aMemberCache) then
        aMemberCache.AddOrSetValue(lKey, aResult);
      Continue;
    end;
    Exit(Blocked);
  end;
  aResult := Default(TBoundMemberResolution);
  Result := False;
end;

function TWithBindingProjectMemberIndex.EstablishedMemberSafetyReason(
  const aBinding: TDelphiSemanticWithBinding;
  const aSelectorIdentities: TArray<TDelphiSemanticTypeIdentity>): string;
var
  i: Integer;
  lFact: TMemberSafetyDiagnostic;
  lIdentity: TDelphiSemanticTypeIdentity;
  lLineage: TArray<TDelphiSemanticTypeIdentity>;
  lLineageComplete: Boolean;
begin
  Result := '';
  if Length(fMemberSafetyDiagnostics) = 0 then
    Exit;
  if Length(aBinding.Selectors) <> Length(aSelectorIdentities) then
    Exit('MEMBERS_INCOMPLETE');
  for i := 0 to High(aBinding.Selectors) do
  begin
    lLineageComplete := TryBuildMemberSafetyLineage(aBinding,
      aBinding.Selectors[i].TypeName, aSelectorIdentities[i], lLineage);
    if not lLineageComplete then
      Exit('MEMBERS_INCOMPLETE');
    for lFact in fMemberSafetyDiagnostics do
    begin
      for lIdentity in lLineage do
      begin
        if not SameText(lIdentity.UnitName, lFact.UnitName) then
          Continue;
        if SameText(lFact.Code, 'MEMBERS_UNVERIFIED') then
          Exit('MEMBERS_UNVERIFIED');
        if not lFact.OwnerResolved then
          Exit('MEMBERS_INCOMPLETE');
        if SameText(lIdentity.Name, lFact.OwnerName) and
          (lIdentity.SourceRange.Line = lFact.Line) and
          SameText(lIdentity.SourceRange.FileName, lFact.FileName) then
          Exit('MEMBERS_INCOMPLETE');
      end;
    end;
  end;
end;

function TWithBindingProjectMemberIndex.MemberSafetyReason(
  const aBinding: TDelphiSemanticWithBinding;
  const aSelectorIdentities: TArray<TDelphiSemanticTypeIdentity>): string;
begin
  Result := EstablishedMemberSafetyReason(aBinding, aSelectorIdentities);
  if (Result = '') and MemberActivityIsUnverified(aBinding, aSelectorIdentities) then
    Result := 'MEMBERS_UNVERIFIED';
end;

class function TDelphiSemanticWithBinder.BindModel(const aModel: TDelphiSemanticUnitModel):
  TArray<TDelphiSemanticWithBinding>;
begin
  Result := BindProject('', nil, [aModel]).Bindings;
end;

class function TDelphiSemanticWithBinder.BindProject(const aContextFingerprint: string;
  const aGraph: TDelphiSemanticSemanticGraph;
  const aModels: TArray<TDelphiSemanticUnitModel>): TDelphiSemanticProjectWithBindingFacts;
begin
  Result := BindProject(aContextFingerprint, aGraph, aModels, nil);
end;

class function TDelphiSemanticWithBinder.BindProject(const aContextFingerprint: string;
  const aGraph: TDelphiSemanticSemanticGraph;
  const aModels: TArray<TDelphiSemanticUnitModel>;
  const aRootMemberAbsence: IDelphiSemanticImplicitRootMemberAbsence):
  TDelphiSemanticProjectWithBindingFacts;
var
  i: Integer;
  j: Integer;
  lBinding: TDelphiSemanticWithBinding;
  lBindingCapacity: Integer;
  lBindingStopwatch: TStopwatch;
  lBindings: TList<TDelphiSemanticWithBinding>;
  lBindingBuildMs: Int64;
  lCurrentTypeName: string;
  lInventoryExpansionMs: Int64;
  lInventoryBuildMs: Int64;
  lLookupIndexBuildMs: Int64;
  lLexicalResolveMs: Int64;
  lModel: TDelphiSemanticUnitModel;
  lAccessIdentity: TDelphiSemanticTypeIdentity;
  lOwnerIdentity: TDelphiSemanticTypeIdentity;
  lMemberCache: TDictionary<string, TBoundMemberResolution>;
  lParentRoutineNames: TArray<string>;
  lProjectMemberIndex: TWithBindingProjectMemberIndex;
  lReferenceCacheHits: Int64;
  lReferenceCacheMisses: Int64;
  lReferenceBindingMs: Int64;
  lReferenceCache: TDictionary<string, TDelphiSemanticBoundReference>;
  lReceiverMemberResolveMs: Int64;
  lResolveCache: TDictionary<string, TDelphiSemanticResolveResult>;
  lRoutine: TDelphiSemanticRoutine;
  lRoutineLookupName: string;
  lRoutineName: string;
  lScopeIndexBuildMs: Int64;
  lSelectorBindingMs: Int64;
  lSelectorIdentityStacks: TWithSelectorIdentityStackArray;
  lSkipReason: string;
  lSelectorStacks: TWithSelectorStackArray;
  lScopeIndex: TDelphiSemanticRoutineScopeIndex;
  lStatement: TDelphiSemanticWithStatement;
  lStopwatch: TStopwatch;
  lSubphaseStopwatch: TStopwatch;
  lSymbol: TDelphiSemanticInventorySymbol;
  lSymbolCapacity: Integer;
  lSymbols: TList<TDelphiSemanticInventorySymbol>;
  lWithStatementLines: TArray<Integer>;
  lActivityLineStarts: TArray<Integer>;
begin
  Result := Default(TDelphiSemanticProjectWithBindingFacts);
  Result.ContextFingerprint := aContextFingerprint;
  lBindings := TList<TDelphiSemanticWithBinding>.Create;
  lSymbols := TList<TDelphiSemanticInventorySymbol>.Create;
  lBindingCapacity := 0;
  lSymbolCapacity := Length(aModels) * 16;
  for lModel in aModels do
  begin
    Inc(lBindingCapacity, Length(lModel.WithStatements));
    Inc(lSymbolCapacity, 1 + Length(lModel.Declarations) + Length(lModel.Members) +
      Length(lModel.Routines) + Length(lModel.Locals));
    for lRoutine in lModel.Routines do
      Inc(lSymbolCapacity, Length(lRoutine.Parameters));
  end;
  lBindings.Capacity := lBindingCapacity;
  lSymbols.Capacity := lSymbolCapacity;
  lBindingBuildMs := 0;
  lInventoryExpansionMs := 0;
  lInventoryBuildMs := 0;
  lLexicalResolveMs := 0;
  lLookupIndexBuildMs := 0;
  lReferenceCacheHits := 0;
  lReferenceCacheMisses := 0;
  lReferenceBindingMs := 0;
  lReceiverMemberResolveMs := 0;
  lScopeIndexBuildMs := 0;
  lSelectorBindingMs := 0;
  lReferenceCache := TDictionary<string, TDelphiSemanticBoundReference>.Create(
    TFastCaseAwareComparer.OrdinalIgnoreCase);
  lResolveCache := TDictionary<string, TDelphiSemanticResolveResult>.Create(
    TFastCaseAwareComparer.OrdinalIgnoreCase);
  lMemberCache := TDictionary<string, TBoundMemberResolution>.Create(
    TFastCaseAwareComparer.OrdinalIgnoreCase);
  lProjectMemberIndex := nil;
  try
    for lModel in aModels do
    begin
      lStopwatch := TStopwatch.StartNew;
      for lSymbol in TDelphiSemanticWithBindingInventory.BuildInventorySymbols(lModel) do
        lSymbols.Add(lSymbol);
      lStopwatch.Stop;
      Inc(lInventoryBuildMs, lStopwatch.ElapsedMilliseconds);
    end;
    TDelphiSemanticWithBindingInventory.AddCompilerProfileCompatibilitySymbols(lSymbols);
    TDelphiSemanticWithBindingInventory.AddProjectExternalUnitSymbols(aModels, lSymbols);
    lStopwatch := TStopwatch.StartNew;
    Result.Symbols := TDelphiSemanticWithBinder.ExpandInventorySymbols(lSymbols.ToArray);
    lStopwatch.Stop;
    lInventoryExpansionMs := lStopwatch.ElapsedMilliseconds;
    Result.UnitModels := Copy(aModels);
    lProjectMemberIndex := TWithBindingProjectMemberIndex.Create(aModels, aGraph,
      Default(TDelphiSemanticRemoveWithLookupIndex));
    lProjectMemberIndex.fRootMemberAbsence := aRootMemberAbsence;
    for j := 0 to High(Result.Symbols) do
    begin
      lSymbol := Result.Symbols[j];
      if lProjectMemberIndex.TryResolveMemberOwnerIdentity(lSymbol,
        lOwnerIdentity, lAccessIdentity) then
      begin
        lSymbol.OwnerIdentity := lOwnerIdentity;
        lSymbol.AccessOwnerIdentity := lAccessIdentity;
        Result.Symbols[j] := lSymbol;
      end;
    end;
    lStopwatch := TStopwatch.StartNew;
    Result.LookupIndex := TDelphiSemanticRemoveWithLookupIndex.Build(Result.UnitModels,
      Result.Symbols);
    lStopwatch.Stop;
    lLookupIndexBuildMs := lStopwatch.ElapsedMilliseconds;
    lProjectMemberIndex.fLookupIndex := Result.LookupIndex;
    for lModel in aModels do
    begin
      if Length(lModel.WithStatements) = 0 then
        Continue;
      lActivityLineStarts := BuildBodyLineStarts(lModel.SourceText);
      SetLength(lWithStatementLines, Length(lModel.WithStatements));
      for i := 0 to High(lModel.WithStatements) do
        lWithStatementLines[i] := lModel.WithStatements[i].Line;
      lStopwatch := TStopwatch.StartNew;
      lScopeIndex := TDelphiSemanticScopeResolver.BuildRoutineScopeIndex(lModel,
        lWithStatementLines);
      lStopwatch.Stop;
      Inc(lScopeIndexBuildMs, lStopwatch.ElapsedMilliseconds);
      lBindingStopwatch := TStopwatch.StartNew;
      lSubphaseStopwatch := TStopwatch.StartNew;
      lSelectorStacks := BuildSelectorStackCache(lModel, aModels, lModel.WithStatements,
        lScopeIndex, lProjectMemberIndex, lMemberCache, lSelectorIdentityStacks);
      lSubphaseStopwatch.Stop;
      Inc(lSelectorBindingMs, lSubphaseStopwatch.ElapsedMilliseconds);
      for i := 0 to High(lModel.WithStatements) do
      begin
        lStatement := lModel.WithStatements[i];
        lBinding := Default(TDelphiSemanticWithBinding);
        lBinding.SemanticId := BindingSemanticId(lModel, lStatement);
        lBinding.Provenance := 'with-binding:model';
        lBinding.FileName := lModel.FileName;
        lBinding.UnitName := lModel.UnitName;
        lBinding.Line := lStatement.Line;
        lBinding.Column := lStatement.Column;
        lBinding.EndLine := lStatement.EndLine;
        lBinding.EndColumn := lStatement.EndColumn;
        lBinding.BodyLine := lStatement.BodyLine;
        lBinding.BodyColumn := lStatement.BodyColumn;
        lBinding.BodyEndLine := lStatement.BodyEndLine;
        lBinding.BodyEndColumn := lStatement.BodyEndColumn;
        lBinding.SelectorText := lStatement.SelectorText;
        lBinding.SemanticId := GraphWithStatementIdForBinding(aGraph, lBinding);
        if aGraph <> nil then
          lBinding.Provenance := 'with-binding:project-session';
        lRoutineName := lScopeIndex.RoutineNameForLine(lStatement.Line);
        lBinding.RoutineName := lRoutineName;
        lBinding.RoutineScopeId := RoutineScopeAtLine(lModel, lStatement.Line);
        lParentRoutineNames := lScopeIndex.ParentRoutineNamesForLine(lRoutineName,
          lStatement.Line);
        lCurrentTypeName := CallerTypeNameForRoutineContext(lModel, lRoutineName,
          lParentRoutineNames, lStatement.Line);
        lRoutineLookupName := RoutineLookupNameForRoutineContext(lModel, lRoutineName,
          lStatement.Line);
        lBinding.Selectors := lSelectorStacks[i];
        lSubphaseStopwatch := TStopwatch.StartNew;
        lBinding.References := BindReferences(lModel, aModels, lStatement,
          lModel.WithStatements, i, lRoutineLookupName, lCurrentTypeName,
          lParentRoutineNames, lBinding.Selectors, lProjectMemberIndex, lReferenceCache, lResolveCache,
          lMemberCache, lReceiverMemberResolveMs, lLexicalResolveMs,
          lReferenceCacheHits, lReferenceCacheMisses);
        lSubphaseStopwatch.Stop;
        Inc(lReferenceBindingMs, lSubphaseStopwatch.ElapsedMilliseconds);
        ApplyBindingReferenceIds(lBinding);
        SeparateInactiveSpanVerification(lModel, lActivityLineStarts, lStatement, lBinding);
        FinalizeBinding(lBinding, lStatement);
        if lBinding.InactiveSpanSkipReason <> '' then
        begin
          lBinding.Status := 'skipped';
          // Keep the public base refusal after partitioning its inactive references.
          lBinding.SkipReason := lBinding.InactiveSpanSkipReason;
        end;
        ApplyBindingActivity(lModel, lActivityLineStarts, lBinding);
        lSkipReason := lProjectMemberIndex.MemberSafetyReason(lBinding,
          lSelectorIdentityStacks[i]);
        lBinding.MemberActivityUnverified :=
          lProjectMemberIndex.MemberActivityIsUnverified(lBinding, lSelectorIdentityStacks[i]) and
          (lProjectMemberIndex.EstablishedMemberSafetyReason(lBinding,
          lSelectorIdentityStacks[i]) = '');
        if lSkipReason <> '' then
        begin
          lBinding.Status := 'skipped';
          lBinding.SkipReason := lSkipReason;
        end;
        lBindings.Add(lBinding);
      end;
      lBindingStopwatch.Stop;
      Inc(lBindingBuildMs, lBindingStopwatch.ElapsedMilliseconds);
    end;
    Result.Bindings := lBindings.ToArray;
    Result.Metrics.SemanticGraphUsed := aGraph <> nil;
    Result.Metrics.BuildUnitIndexUsed := False;
    Result.Metrics.InventoryBuildMilliseconds := lInventoryBuildMs;
    Result.Metrics.InventoryExpansionMilliseconds := lInventoryExpansionMs;
    Result.Metrics.BindingBuildMilliseconds := lBindingBuildMs;
    Result.Metrics.ScopeIndexBuildMilliseconds := lScopeIndexBuildMs;
    Result.Metrics.SelectorBindingMilliseconds := lSelectorBindingMs;
    Result.Metrics.ReferenceBindingMilliseconds := lReferenceBindingMs;
    Result.Metrics.ReceiverMemberResolveMilliseconds := lReceiverMemberResolveMs;
    Result.Metrics.LexicalResolveMilliseconds := lLexicalResolveMs;
    Result.Metrics.ReferenceCacheHitCount := lReferenceCacheHits;
    Result.Metrics.ReferenceCacheMissCount := lReferenceCacheMisses;
    Result.Metrics.LookupIndexBuildMilliseconds := lLookupIndexBuildMs;
    Result.Metrics.UnitCount := Length(aModels);
    if aGraph <> nil then
    begin
      Result.Metrics.UnitCount := aGraph.Metrics.UnitCount;
      Result.Metrics.WithStatementCount := aGraph.Metrics.WithStatementCount;
      Result.Metrics.SemanticGraphBuildMilliseconds := aGraph.Metrics.BuildMilliseconds;
    end else
      Result.Metrics.WithStatementCount := Length(Result.Bindings);
    Result.Metrics.BindingCount := Length(Result.Bindings);
  finally
    lProjectMemberIndex.Free;
    lMemberCache.Free;
    lResolveCache.Free;
    lReferenceCache.Free;
    lSymbols.Free;
    lBindings.Free;
  end;
end;

class function TDelphiSemanticWithBinder.ExpandInventorySymbols(
  const aSymbols: TArray<TDelphiSemanticInventorySymbol>): TArray<TDelphiSemanticInventorySymbol>;
begin
  Result := TDelphiSemanticWithBindingInventory.ExpandInventorySymbols(aSymbols);
end;

class function TDelphiSemanticWithBinder.BuildInventory(
  const aModel: TDelphiSemanticUnitModel): TDelphiSemanticRemoveWithInventory;
begin
  Result := Default(TDelphiSemanticRemoveWithInventory);
  Result.FileName := aModel.FileName;
  Result.UnitName := aModel.UnitName;
  Result.Symbols := TDelphiSemanticWithBindingInventory.BuildInventorySymbols(aModel);

  Result.Bindings := BindModel(aModel);
end;

end.
