unit DelphiSemantics.WithBinding;

interface

uses
  DelphiSemantics.Model, DelphiSemantics.Resolve, DelphiSemantics.Resolve.ScopeResolver,
  DelphiSemantics.Resolve.TypeResolver, DelphiSemantics.Resolve.UnitNameWitness,
  DelphiSemantics.RootMemberAbsence,
  DelphiSemantics.SemanticGraph;

type
  TDelphiSemanticWithSelectorBinding = record
    Cause: string;
    SelectorText: string;
    Status: string;
    ReasonCode: string;
    TypeName: string;
    TypeIdentity: TDelphiSemanticTypeIdentity;
    CaptureTypeIdentity: TDelphiSemanticTypeIdentity;
    CaptureTypeName: string;
    CaptureTypeStatus: string;
    CaptureInsertionLine: Integer;
  end;

  TDelphiSemanticBoundReference = record
    Cause: string;
    ReceiverIndex: Integer;
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
    ProjectFactsCacheStoreOutcome: string;
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

  // The planner needs value coverage, not a second semantic model graph.
  TDelphiSemanticValueEvidenceUnit = record
    UnitName: string;
    FileName: string;
    SourceText: string;
    VerifiedActiveSourceText: string;
    ScopeModelStatus: string;
    ScopeModelVersion: string;
    RejectedDeclarationCount: Integer;
  end;

  TDelphiSemanticValueEvidenceOwner = record
    DeclaredId: string;
    UnitName: string;
    FileName: string;
    Name: string;
    Complete: Boolean;
    TerminalVerified: Boolean;
    UnindexedRoot: Boolean;
    NextDeclaredId: string;
    ValueNames: TArray<string>;
  end;

  TDelphiSemanticValueEvidenceQuery = record
    Name: string;
    DeclaredId: string;
  end;

  TDelphiSemanticValueMemberEvidence = record
    Available: Boolean;
    Units: TArray<TDelphiSemanticValueEvidenceUnit>;
    Owners: TArray<TDelphiSemanticValueEvidenceOwner>;
    Queries: TArray<TDelphiSemanticValueEvidenceQuery>;
    ValueNames: TArray<string>;
    UnverifiedOwnerKeys: TArray<string>;
    RootMemberAbsences: TArray<string>;
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
    function UnverifiedValueMemberMayApply(const aOwnerType, aName: string): Boolean; overload;
    function UnverifiedValueMemberMayApply(const aOwnerType, aName: string;
      const aOwnerIdentity: TDelphiSemanticTypeIdentity): Boolean; overload;
    function ReceiverLineageDeclaresMember(const aOwnerIdentity: TDelphiSemanticTypeIdentity;
      const aOwnerName, aName: string): Boolean;
    function UnverifiedReceiverMemberMayApply(const aOwnerType, aName: string;
      const aOwnerIdentity: TDelphiSemanticTypeIdentity): Boolean;
    function ReceiverMemberAbsenceProved(const aSiteUnitName, aOwnerType, aName: string;
      const aOwnerIdentity: TDelphiSemanticTypeIdentity): Boolean;
    function ReceiverLineageHasUnindexedRoot(const aOwnerIdentity: TDelphiSemanticTypeIdentity): Boolean;
    procedure RecordRootMemberAbsence(const aSiteUnitName, aRootOwnerId, aName: string);
    function RootMemberAbsenceRecorded(const aSiteUnitName, aRootOwnerId, aName: string): Boolean;
    procedure AttachValueMemberModels(const aModels: TArray<TDelphiSemanticUnitModel>);
    procedure AttachValueMemberEvidence(const aEvidence: TDelphiSemanticValueMemberEvidence);
    function ExportValueMemberEvidence: TDelphiSemanticValueMemberEvidence;
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
    class function BindProject(const aContextFingerprint: string;
      const aGraph: TDelphiSemanticSemanticGraph;
      const aModels: TArray<TDelphiSemanticUnitModel>;
      const aRootMemberAbsence: IDelphiSemanticImplicitRootMemberAbsence;
      const aUnitNameWitness: IDelphiSemanticUnitNameWitness):
      TDelphiSemanticProjectWithBindingFacts; overload; static;
    class function BuildInventory(const aModel: TDelphiSemanticUnitModel):
      TDelphiSemanticRemoveWithInventory; static;
    class function ExpandInventorySymbols(const aSymbols: TArray<TDelphiSemanticInventorySymbol>):
      TArray<TDelphiSemanticInventorySymbol>; static;
  end;

// Shared by binder adapters and planner before inventory recovery or persistence.
function BinderDenialCode(const aCode: string): Boolean;

// WITH-only verification must not become rename/find-usages reference output.
function WithBindingForPlanning(const aBinding: TDelphiSemanticWithBinding):
  TDelphiSemanticWithBinding;

implementation

uses
  System.Character, System.Classes, System.Diagnostics, System.Generics.Collections, System.Hash, System.Math,
  System.RegularExpressions, System.StrUtils, System.SysUtils,
  AutoFree,
  SimpleParser.Lexer, SimpleParser.Lexer.Types,
  DelphiSemantics.CompilerProfile, DelphiSemantics.Model.Extract, DelphiSemantics.Model.Text, DelphiSemantics.ProjectContext,
  DelphiSemantics.RemoveWith.TempInsertion, DelphiSemantics.Resolve.MemberResolver,
  DelphiSemantics.Resolve.NameSites, DelphiSemantics.Resolve.SelectorTypes,
  DelphiSemantics.Source, DelphiSemantics.SourceConditionals, DelphiSemantics.WithBinding.Inventory,
  MaxLogic.StrUtils;

function BinderDenialCode(const aCode: string): Boolean;
begin
  Result := MatchText(aCode, ['HELPER_COLLISION_UNVERIFIED', 'RECORD_HELPER_MEMBERS_UNVERIFIED',
    'ALIAS_RECEIVER_MEMBERS_UNVERIFIED', 'TYPE_VALUE_MEMBERS_UNVERIFIED',
    'TYPE_VALUE_MEMBER_ACCESS_UNVERIFIED', 'SELECTOR_MEMBERS_UNVERIFIED',
    'TYPE_VISIBILITY_UNPROVED', 'PARENT_SELECTOR_UNRESOLVED']);
end;

type
  IDelphiSemanticRemoveWithLookupActivityData = interface
    ['{5E17BE4B-30D7-43E4-A47D-835EB036B78A}']
    function ActivityMetrics: TDelphiSemanticRemoveWithLookupActivityMetrics;
  end;

  IDelphiSemanticRemoveWithValueEvidence = interface
    ['{AF3CBB02-1895-4585-9549-01FB130F53D8}']
    function ReceiverLineageDeclaresMember(const aOwnerIdentity: TDelphiSemanticTypeIdentity;
      const aOwnerName, aName: string): Boolean;
    function UnverifiedReceiverMemberMayApply(const aOwnerType, aName: string;
      const aOwnerIdentity: TDelphiSemanticTypeIdentity): Boolean;
    function ReceiverMemberAbsenceProved(const aSiteUnitName, aOwnerType, aName: string;
      const aOwnerIdentity: TDelphiSemanticTypeIdentity): Boolean;
    function ReceiverLineageHasUnindexedRoot(const aOwnerIdentity: TDelphiSemanticTypeIdentity): Boolean;
    procedure RecordRootMemberAbsence(const aSiteUnitName, aRootOwnerId, aName: string);
    function RootMemberAbsenceRecorded(const aSiteUnitName, aRootOwnerId, aName: string): Boolean;
    function UnverifiedValueMemberMayApply(const aOwnerType, aName: string): Boolean; overload;
    function UnverifiedValueMemberMayApply(const aOwnerType, aName: string;
      const aOwnerIdentity: TDelphiSemanticTypeIdentity): Boolean; overload;
  end;

  IDelphiSemanticRemoveWithModelEvidence = interface
    ['{1795242E-015B-4CEB-BABF-BD160B88C083}']
    procedure AttachValueMemberModels(const aModels: TArray<TDelphiSemanticUnitModel>);
    procedure AttachValueMemberEvidence(const aEvidence: TDelphiSemanticValueMemberEvidence);
    function ExportValueMemberEvidence: TDelphiSemanticValueMemberEvidence;
  end;

  TWithBindingProjectMemberIndex = class;

  TDelphiSemanticRemoveWithLookupIndexData = class(TInterfacedObject,
    IDelphiSemanticRemoveWithLookupIndexData,
    IDelphiSemanticRemoveWithLookupActivityData, IDelphiSemanticRemoveWithValueEvidence,
    IDelphiSemanticRemoveWithModelEvidence)
  private
    fValueMemberModels: TArray<TDelphiSemanticUnitModel>;
    fValueEvidence: TDelphiSemanticValueMemberEvidence;
    fValueEvidenceLoaded: Boolean;
    fRootMemberAbsences: THashSet<string>;
    fValueOwners: TDictionary<string, Integer>;
    fValueQueries: TDictionary<string, string>;
    fValueOwnerNames: THashSet<string>;
    fValueMemberNames: THashSet<string>;
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
    procedure EnsureValueMemberEvidence;
    function UnverifiedMemberMayApply(const aOwnerType, aName: string;
      const aOwnerIdentity: TDelphiSemanticTypeIdentity; const aValueMembersOnly,
      aRootProvesAbsence: Boolean; const aSiteUnitName: string = ''): Boolean;
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
    function UnverifiedValueMemberMayApply(const aOwnerType, aName: string): Boolean; overload;
    function UnverifiedValueMemberMayApply(const aOwnerType, aName: string;
      const aOwnerIdentity: TDelphiSemanticTypeIdentity): Boolean; overload;
    function ReceiverLineageDeclaresMember(const aOwnerIdentity: TDelphiSemanticTypeIdentity;
      const aOwnerName, aName: string): Boolean;
    function UnverifiedReceiverMemberMayApply(const aOwnerType, aName: string;
      const aOwnerIdentity: TDelphiSemanticTypeIdentity): Boolean;
    function ReceiverMemberAbsenceProved(const aSiteUnitName, aOwnerType, aName: string;
      const aOwnerIdentity: TDelphiSemanticTypeIdentity): Boolean;
    function ReceiverLineageHasUnindexedRoot(const aOwnerIdentity: TDelphiSemanticTypeIdentity): Boolean;
    procedure RecordRootMemberAbsence(const aSiteUnitName, aRootOwnerId, aName: string);
    function RootMemberAbsenceRecorded(const aSiteUnitName, aRootOwnerId, aName: string): Boolean;
    procedure AttachValueMemberModels(const aModels: TArray<TDelphiSemanticUnitModel>);
    procedure AttachValueMemberEvidence(const aEvidence: TDelphiSemanticValueMemberEvidence);
    function ExportValueMemberEvidence: TDelphiSemanticValueMemberEvidence;
  end;

  TReceiverLookupSite = record
    UnitName: string;
    FileName: string;
    Line: Integer;
    Column: Integer;
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
    Cause: string;
    Value: TDelphiSemanticResolveResult;
    DeclaringUnitName: string;
    OwnerDeclaredId: TDelphiSemanticGraphTypeId;
    ReceiverIndex: Integer;
  end;

  TRootAbsenceProofKind = (rapNone, rapClosedSourceRoot, rapNamedSiteScopedRoot);

  TRootAbsenceProof = record
    Kind: TRootAbsenceProofKind;
    SiteUnits: TArray<string>;
  end;

  TMemberVerdict = record
  strict private
    fOutcome: TDelphiSemanticNameOutcome;
    fMember: TBoundMemberResolution;
    fReasonCode, fReason, fCause: string;
    fMemberTypeOpen: Boolean;
  public
    class function Present(const aMember: TBoundMemberResolution;
      const aMemberTypeOpen: Boolean = False): TMemberVerdict; static;
    class function NotPresent: TMemberVerdict; static;
    class function Barrier(const aOutcome: TDelphiSemanticNameOutcome;
      const aReasonCode, aReason, aCause: string): TMemberVerdict; static;
    property Outcome: TDelphiSemanticNameOutcome read fOutcome;
    property ReasonCode: string read fReasonCode;
    property Cause: string read fCause;
    property MemberTypeOpen: Boolean read fMemberTypeOpen;
    function Member: TBoundMemberResolution;
    function AsBound(const aName: string; const aReceiverIndex: Integer): TBoundMemberResolution;
  end;

  TWithBindingProjectMemberIndex = class
  private
    fCaptureProofGraph: TDelphiSemanticSemanticGraph;
    fRootMemberAbsence: IDelphiSemanticImplicitRootMemberAbsence;
    fUnitNameWitness: IDelphiSemanticUnitNameWitness;
    fCompilerIntrinsics: TDictionary<string, TDelphiSemanticIntrinsicSymbol>;
    fLookupIndex: TDelphiSemanticRemoveWithLookupIndex;
    fTypeIndex: TDelphiSemanticTypeIdentityIndex;
    fModels: TArray<TDelphiSemanticUnitModel>;
    fValueTypeIds: TArray<TDelphiSemanticGraphTypeId>;
    fOwnerIdentities: TDictionary<string, TDelphiSemanticTypeIdentity>;
    fDeclarationCandidates: TObjectDictionary<string, TList<TIndexedDeclarationCandidate>>;
    fDeclarationModels: TDictionary<string, TArray<TDelphiSemanticUnitModel>>;
    fByUnitOwnerName: TDictionary<string, TList<TBoundMemberResolution>>;
    fInventoryByOwnerId: TDictionary<string, TList<TBoundMemberResolution>>;
    fDirectMembersByContextOwnerName: TDictionary<string, TList<TBoundMemberResolution>>;
    fMemberKeysByUnit: TDictionary<string, TList<string>>;
    fSemanticMemberIndex: TDelphiSemanticMemberIdentityIndex;
    fSemanticMemberIndexAvailable: Boolean;
    fSemanticMemberResultsByOwnerName: TDictionary<string, TMemberVerdict>;
    fUnitNames: TArray<string>;
    fVisibleUnitsByUnit: TDictionary<string, TArray<string>>;
    fMemberSafetyDiagnostics: TArray<TMemberSafetyDiagnostic>;
    fActivityMemberFacts: TArray<TMemberSafetyDiagnostic>;
    fSafetyDeclarationsByName: TObjectDictionary<string, TList<TIndexedDeclarationCandidate>>;
    fSafetyModelsByUnit: TDictionary<string, TArray<Integer>>;
    fSafetyProfileTypes: TDictionary<string, Byte>;
    fUnindexedHelperModelIndexes: TArray<Integer>;
    fValueMembers: TDictionary<string, TArray<TBoundMemberResolution>>;
    fValueVisibility: TDictionary<string, TArray<string>>;
    fValueMemberNames: TDictionary<string, Byte>;
    fUnverifiedValueOwners: TDictionary<string, Byte>;
    fHelperValueNames: TDictionary<string, Byte>;
    fHelperTargetDeclaredIds: TDictionary<string, Byte>;
    fUnindexedAliases: TDictionary<string, Boolean>;
    fHasUnresolvedHelperTarget: Boolean;
    function LookupIdentityMember(const aContext: TDelphiSemanticMemberLookupContext;
      const aOwner: TDelphiSemanticTypeIdentity; const aName: string;
      const aCheckHidden: Boolean; const aCheckHelpers: Boolean = True): TDelphiSemanticMemberLookupResult;
    function LookupLegacyHelperMember(const aContext: TDelphiSemanticMemberLookupContext;
      const aOwner: TDelphiSemanticTypeIdentity; const aName: string):
      TDelphiSemanticMemberLookupResult;
    procedure BuildOwnerIdentityIndex;
    function OwnerIdentity(const aUnitName, aOwnerName, aScopeId, aSymbolId: string;
      out aIdentity: TDelphiSemanticTypeIdentity): Boolean;
    procedure BuildHelperTargetIndex;
    function TryResolveAliasTargetSelector(const aModel: TDelphiSemanticUnitModel;
      const aSite: TReceiverLookupSite; const aSelector: TDelphiSemanticWithSelectorBinding;
      out aTarget: TDelphiSemanticWithSelectorBinding; out aRefusal: string): Boolean;
    procedure BuildValueMemberIndex;
    function ResolveValueEvidenceType(const aName: string;
      const aContext: TDelphiSemanticTypeIdentity): TDelphiSemanticTypeLookupResult;
    function ExportValueMemberEvidence: TDelphiSemanticValueMemberEvidence;
    function TryResolveReceiverValueMember(const aModel: TDelphiSemanticUnitModel;
      const aSite: TReceiverLookupSite; const aSelector: TDelphiSemanticWithSelectorBinding;
      const aName, aStopDeclaredId: string): TMemberVerdict;
    function TryResolveShadowingValueMember(const aModel: TDelphiSemanticUnitModel;
      const aSite: TReceiverLookupSite; const aSelector: TDelphiSemanticWithSelectorBinding;
      const aName: string; const aDirect: TBoundMemberResolution;
      out aResult: TBoundMemberResolution): Boolean;
    function UnindexedRecordHelperMayApply(const aSite: TReceiverLookupSite;
      const aLineage: TArray<TDelphiSemanticTypeIdentity>): Boolean;
    procedure BuildMemberSafetyDiagnostics;
    function LineageHasActivityFact(const aLineage: TArray<TDelphiSemanticTypeIdentity>): Boolean;
    function MemberActivityIsUnverified(const aBinding: TDelphiSemanticWithBinding;
      const aSelectorIdentities: TArray<TDelphiSemanticTypeIdentity>): Boolean;
    function IsKnownSafetyProfileTerminal(const aName: string;
      const aLookup: TDelphiSemanticTypeLookupResult): Boolean;
    function TryBuildMemberSafetyLineage(const aBinding: TDelphiSemanticWithBinding;
      const aSelectorTypeName: string; const aSelectorIdentity: TDelphiSemanticTypeIdentity):
      TDelphiSemanticLineage;
    function ResolveBodyMemberVerdict(const aModel: TDelphiSemanticUnitModel;
      const aSite: TReceiverLookupSite;
      const aLookupSelector, aOriginalSelector: TDelphiSemanticWithSelectorBinding;
      const aCurrentTypeName, aName: string): TMemberVerdict;
    function ResolveSelectorMemberVerdict(const aModel: TDelphiSemanticUnitModel;
      const aSite: TReceiverLookupSite; const aSelector: TDelphiSemanticWithSelectorBinding;
      const aLineage: TDelphiSemanticLineage;
      const aCurrentTypeName, aName: string): TMemberVerdict;
    function ReceiverMemberAbsenceIsVerified(const aModel: TDelphiSemanticUnitModel;
      const aSelector: TDelphiSemanticWithSelectorBinding; const aName: string;
      const aSite: TReceiverLookupSite; out aRefusalCode: string): Boolean overload;
    function ReceiverMemberAbsenceIsVerified(const aModel: TDelphiSemanticUnitModel;
      const aSelector: TDelphiSemanticWithSelectorBinding; const aName: string;
      const aSite: TReceiverLookupSite; out aRefusalCode: string;
      out aRootProof: TRootAbsenceProof): Boolean; overload;
    function MembersClosed(const aIdentity: TDelphiSemanticTypeIdentity): Boolean;
    function ResolveReceiverMemberVerdict(const aModel: TDelphiSemanticUnitModel;
      const aSite: TReceiverLookupSite;
      const aSelector, aOriginalSelector: TDelphiSemanticWithSelectorBinding;
      const aCurrentTypeName, aName: string; const aDirect: TMemberVerdict): TMemberVerdict;
    function TryResolveVerifiedSimpleMember(const aModel: TDelphiSemanticUnitModel;
      const aSite: TReceiverLookupSite;
      const aSelectors: TArray<TDelphiSemanticWithSelectorBinding>;
      const aCurrentTypeName, aMemberCachePrefix, aName: string;
      const aMemberCache: TDictionary<string, TMemberVerdict>;
      out aResult: TBoundMemberResolution): Boolean;
    function SelectorTypeLookup(const aOriginModel: TDelphiSemanticUnitModel;
      const aOriginSectionKind, aOriginScopeId, aTypeName: string):
      TDelphiSemanticTypeLookupResult;
    function TryClassScopedReceiverType(const aModel: TDelphiSemanticUnitModel;
      const aResolved: TDelphiSemanticResolveResult; const aCurrentTypeName: string;
      out aResolution: TDelphiSemanticTypeResolution): Boolean;
    function TryResolveSelectorIdentity(const aOriginModel: TDelphiSemanticUnitModel;
      const aOriginSectionKind, aOriginScopeId, aTypeName: string;
      out aIdentity: TDelphiSemanticTypeIdentity): Boolean;
    function UnindexedAliasMayApply(const aTypeName: string): Boolean;
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
    function ModelIsClosedForRootProof(const aModel: TDelphiSemanticUnitModel): Boolean;
    function RootHeadingIsNonGeneric(const aIdentity: TDelphiSemanticTypeIdentity;
      const aModel: TDelphiSemanticUnitModel): Boolean;
    function TryRootProofUnits(const aModel: TDelphiSemanticUnitModel;
      const aIncludeImplementation: Boolean; out aUnits: TArray<string>): Boolean;
    function TryBuildRootQueryLineage(const aBinding: TDelphiSemanticWithBinding;
      const aSelectorTypeName: string; const aSelectorIdentity: TDelphiSemanticTypeIdentity;
      out aLineage: TArray<TDelphiSemanticTypeIdentity>): Boolean;

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
      const aLookupIndex: TDelphiSemanticRemoveWithLookupIndex;
      const aUnitNameWitness: IDelphiSemanticUnitNameWitness);
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
      const aIncludeHelpers: Boolean = True): TMemberVerdict; overload;
    function TryResolveRoutineLocalMember(const aOwnerIdentity: TDelphiSemanticTypeIdentity;
      const aCurrentTypeName, aName: string; const aSite: TReceiverLookupSite): TMemberVerdict;
  end;

  // Prepared inputs belong to one immutable model in one BindProject call.
  // We share text transformations, never scope/position-dependent answers.
  TWithBindingSourceContext = record
    LineStarts: TArray<Integer>;
    Lines: TArray<string>;
    SanitizedSourceText: string;
    ReferenceScanText: string;
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
  fRootMemberAbsences := THashSet<string>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
  fValueOwners := TDictionary<string, Integer>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
  fValueQueries := TDictionary<string, string>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
  fValueOwnerNames := THashSet<string>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
  fValueMemberNames := THashSet<string>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
  AttachValueMemberModels(aModels);
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
  fRootMemberAbsences.Free;
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
  fValueOwners.Free;
  fValueQueries.Free;
  fValueOwnerNames.Free;
  fValueMemberNames.Free;
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

function TDelphiSemanticRemoveWithLookupIndex.UnverifiedValueMemberMayApply(
  const aOwnerType, aName: string): Boolean;
begin
  Result := UnverifiedValueMemberMayApply(aOwnerType, aName,
    Default(TDelphiSemanticTypeIdentity));
end;

function TDelphiSemanticRemoveWithLookupIndex.UnverifiedValueMemberMayApply(
  const aOwnerType, aName: string; const aOwnerIdentity: TDelphiSemanticTypeIdentity): Boolean;
var
  lEvidence: IDelphiSemanticRemoveWithValueEvidence;
begin
  // A foreign lookup producer without value evidence cannot prove absence.
  if not Supports(fData, IDelphiSemanticRemoveWithValueEvidence, lEvidence) then
    Exit(True);
  Result := lEvidence.UnverifiedValueMemberMayApply(aOwnerType, aName, aOwnerIdentity);
end;

function TDelphiSemanticRemoveWithLookupIndex.UnverifiedReceiverMemberMayApply(
  const aOwnerType, aName: string; const aOwnerIdentity: TDelphiSemanticTypeIdentity): Boolean;
var
  lEvidence: IDelphiSemanticRemoveWithValueEvidence;
begin
  if not Supports(fData, IDelphiSemanticRemoveWithValueEvidence, lEvidence) then
    Exit(True);
  Result := lEvidence.UnverifiedReceiverMemberMayApply(aOwnerType, aName, aOwnerIdentity);
end;

function TDelphiSemanticRemoveWithLookupIndex.ReceiverMemberAbsenceProved(const aSiteUnitName, aOwnerType, aName: string;
  const aOwnerIdentity: TDelphiSemanticTypeIdentity): Boolean;
var
  lEvidence: IDelphiSemanticRemoveWithValueEvidence;
begin
  if not Supports(fData, IDelphiSemanticRemoveWithValueEvidence, lEvidence) then
    Exit(False);
  Result := lEvidence.ReceiverMemberAbsenceProved(aSiteUnitName, aOwnerType, aName, aOwnerIdentity);
end;

function TDelphiSemanticRemoveWithLookupIndex.ReceiverLineageHasUnindexedRoot(const aOwnerIdentity: TDelphiSemanticTypeIdentity): Boolean;
var
  lEvidence: IDelphiSemanticRemoveWithValueEvidence;
begin
  if not Supports(fData, IDelphiSemanticRemoveWithValueEvidence, lEvidence) then
    Exit(True);
  Result := lEvidence.ReceiverLineageHasUnindexedRoot(aOwnerIdentity);
end;

function TDelphiSemanticRemoveWithLookupIndex.RootMemberAbsenceRecorded(const aSiteUnitName, aRootOwnerId, aName: string): Boolean;
var
  lEvidence: IDelphiSemanticRemoveWithValueEvidence;
begin
  if not Supports(fData, IDelphiSemanticRemoveWithValueEvidence, lEvidence) then
    Exit(False);
  Result := lEvidence.RootMemberAbsenceRecorded(aSiteUnitName, aRootOwnerId, aName);
end;

procedure TDelphiSemanticRemoveWithLookupIndex.RecordRootMemberAbsence(
  const aSiteUnitName, aRootOwnerId, aName: string);
var
  lEvidence: IDelphiSemanticRemoveWithValueEvidence;
begin
  if Supports(fData, IDelphiSemanticRemoveWithValueEvidence, lEvidence) then
    lEvidence.RecordRootMemberAbsence(aSiteUnitName, aRootOwnerId, aName);
end;

procedure TDelphiSemanticRemoveWithLookupIndexData.RecordRootMemberAbsence(
  const aSiteUnitName, aRootOwnerId, aName: string);
begin
  if (aSiteUnitName <> '') and (aRootOwnerId <> '') and (aName <> '') then
    fRootMemberAbsences.Add(aSiteUnitName + #31 + aRootOwnerId + #31 + aName);
end;

function TDelphiSemanticRemoveWithLookupIndexData.RootMemberAbsenceRecorded(
  const aSiteUnitName, aRootOwnerId, aName: string): Boolean;
begin
  Result := (aSiteUnitName <> '') and (aRootOwnerId <> '') and (aName <> '') and
    fRootMemberAbsences.Contains(aSiteUnitName + #31 + aRootOwnerId + #31 + aName);
end;

function TDelphiSemanticRemoveWithLookupIndexData.ReceiverMemberAbsenceProved(
  const aSiteUnitName, aOwnerType, aName: string;
  const aOwnerIdentity: TDelphiSemanticTypeIdentity): Boolean;
begin
  Result := not UnverifiedMemberMayApply(aOwnerType, aName, aOwnerIdentity,
    False, False, aSiteUnitName);
end;

function TDelphiSemanticRemoveWithLookupIndexData.ReceiverLineageHasUnindexedRoot(
  const aOwnerIdentity: TDelphiSemanticTypeIdentity): Boolean;
var
  i, lRemaining: Integer;
  lDeclaredId: string;
  lOwner: TDelphiSemanticValueEvidenceOwner;
begin
  // Missing or incomplete owner evidence is uncertainty, never proof of a closed lineage.
  Result := True;
  if ((not fValueEvidenceLoaded) and (Length(fValueMemberModels) = 0)) or
    (fValueEvidenceLoaded and (not fValueEvidence.Available)) then
    Exit;
  EnsureValueMemberEvidence;
  lDeclaredId := aOwnerIdentity.DeclaredId.Value;
  if (not fValueEvidence.Available) or (lDeclaredId = '') or
    (not fValueOwners.TryGetValue(lDeclaredId, i)) then
    Exit;
  lOwner := fValueEvidence.Owners[i];
  if (aOwnerIdentity.UnitName = '') or (aOwnerIdentity.Name = '') or
    (aOwnerIdentity.SourceRange.FileName = '') or
    (not SameText(lOwner.UnitName, aOwnerIdentity.UnitName)) or
    (not SameText(lOwner.Name, aOwnerIdentity.Name)) or
    (not SameText(lOwner.FileName, aOwnerIdentity.SourceRange.FileName)) then
    Exit;
  lRemaining := Length(fValueEvidence.Owners);
  while (lRemaining > 0) and fValueOwners.TryGetValue(lDeclaredId, i) do
  begin
    Dec(lRemaining);
    lOwner := fValueEvidence.Owners[i];
    if not lOwner.Complete then
      Exit;
    if lOwner.NextDeclaredId = '' then
      Exit(lOwner.UnindexedRoot or (not lOwner.TerminalVerified));
    lDeclaredId := lOwner.NextDeclaredId;
  end;
  Result := True;
end;

procedure TDelphiSemanticRemoveWithLookupIndexData.AttachValueMemberModels(
  const aModels: TArray<TDelphiSemanticUnitModel>);
var
  lDeclaration: TDelphiSemanticDeclaration;
  lMember: TDelphiSemanticMember;
  lModel: TDelphiSemanticUnitModel;
begin
  // Evidence is independent of the inventory maps and their persisted identities.
  fValueEvidence := Default(TDelphiSemanticValueMemberEvidence);
  fValueEvidenceLoaded := False;
  fValueOwners.Clear;
  fValueQueries.Clear;
  fValueOwnerNames.Clear;
  fValueMemberModels := Copy(aModels);
  fValueMemberNames.Clear;
  for lModel in aModels do
  begin
    for lMember in lModel.TypeValueMembers do
      fValueMemberNames.Add(lMember.Name);
    for lDeclaration in lModel.Declarations do
      if SameText(lDeclaration.ScopeKind, 'type') and
        MatchText(lDeclaration.Kind, ['const', 'typed-const']) then
        fValueMemberNames.Add(lDeclaration.Name);
  end;
end;

procedure TDelphiSemanticRemoveWithLookupIndex.AttachValueMemberModels(
  const aModels: TArray<TDelphiSemanticUnitModel>);
var
  lEvidence: IDelphiSemanticRemoveWithModelEvidence;
begin
  if not Supports(fData, IDelphiSemanticRemoveWithModelEvidence, lEvidence) then
    raise EInvalidOperation.Create('Remove-with lookup cannot attach model evidence.');
  lEvidence.AttachValueMemberModels(aModels);
end;

procedure TDelphiSemanticRemoveWithLookupIndexData.EnsureValueMemberEvidence;
var
  lIndex: TWithBindingProjectMemberIndex;
begin
  if fValueEvidenceLoaded or (Length(fValueMemberModels) = 0) then
    Exit;
  lIndex := TWithBindingProjectMemberIndex.Create(fValueMemberModels, nil,
    Default(TDelphiSemanticRemoveWithLookupIndex), nil);
  try
    AttachValueMemberEvidence(lIndex.ExportValueMemberEvidence);
  finally
    lIndex.Free;
  end;
end;

procedure TDelphiSemanticRemoveWithLookupIndexData.AttachValueMemberEvidence(
  const aEvidence: TDelphiSemanticValueMemberEvidence);
var
  i: Integer;
  lName: string;
  lOwner: TDelphiSemanticValueEvidenceOwner;
  lQuery: TDelphiSemanticValueEvidenceQuery;
begin
  fValueEvidenceLoaded := False;
  fValueMemberModels := nil;
  fValueOwners.Clear;
  fValueQueries.Clear;
  fValueOwnerNames.Clear;
  fValueMemberNames.Clear;
  fValueEvidence := aEvidence;
  fValueEvidence.Units := Copy(aEvidence.Units);
  fValueEvidence.Owners := Copy(aEvidence.Owners);
  fValueEvidence.Queries := Copy(aEvidence.Queries);
  fValueEvidence.ValueNames := Copy(aEvidence.ValueNames);
  fValueEvidence.UnverifiedOwnerKeys := Copy(aEvidence.UnverifiedOwnerKeys);
  fValueEvidence.RootMemberAbsences := Copy(aEvidence.RootMemberAbsences);
  for lName in aEvidence.RootMemberAbsences do
    fRootMemberAbsences.Add(lName);
  for i := 0 to High(aEvidence.Owners) do
  begin
    lOwner := aEvidence.Owners[i];
    fValueEvidence.Owners[i].ValueNames := Copy(lOwner.ValueNames);
    fValueOwners.Add(lOwner.DeclaredId, i);
    for lName in lOwner.ValueNames do
      fValueOwnerNames.Add(lOwner.DeclaredId + #31 + lName);
  end;
  for lQuery in aEvidence.Queries do
    fValueQueries.Add(lQuery.Name, lQuery.DeclaredId);
  for lName in aEvidence.ValueNames do
    fValueMemberNames.Add(lName);
  // A foreign producer cannot turn a missing relation into an absence proof.
  for lOwner in aEvidence.Owners do
  begin
    if lOwner.DeclaredId = '' then
      raise EArgumentException.Create('Value evidence owner identity is missing.');
    if (lOwner.NextDeclaredId <> '') and (not fValueOwners.ContainsKey(lOwner.NextDeclaredId)) then
      raise EArgumentException.Create('Value evidence lineage owner is missing.');
    for lName in lOwner.ValueNames do
      if not fValueMemberNames.Contains(lName) then
        raise EArgumentException.Create('Value evidence project name witness is missing.');
  end;
  for lQuery in aEvidence.Queries do
    if not fValueOwners.ContainsKey(lQuery.DeclaredId) then
      raise EArgumentException.Create('Value evidence query owner is missing.');
  fValueEvidenceLoaded := True;
end;

function TDelphiSemanticRemoveWithLookupIndexData.ExportValueMemberEvidence:
  TDelphiSemanticValueMemberEvidence;
var
  i: Integer;
begin
  EnsureValueMemberEvidence;
  if not fValueEvidenceLoaded then
    Exit(Default(TDelphiSemanticValueMemberEvidence));
  Result := fValueEvidence;
  Result.Units := Copy(fValueEvidence.Units);
  Result.Owners := Copy(fValueEvidence.Owners);
  Result.Queries := Copy(fValueEvidence.Queries);
  Result.ValueNames := Copy(fValueEvidence.ValueNames);
  Result.UnverifiedOwnerKeys := Copy(fValueEvidence.UnverifiedOwnerKeys);
  Result.RootMemberAbsences := fRootMemberAbsences.ToArray;
  for i := 0 to High(Result.Owners) do
    Result.Owners[i].ValueNames := Copy(fValueEvidence.Owners[i].ValueNames);
end;

procedure TDelphiSemanticRemoveWithLookupIndex.AttachValueMemberEvidence(
  const aEvidence: TDelphiSemanticValueMemberEvidence);
var
  lEvidence: IDelphiSemanticRemoveWithModelEvidence;
begin
  if not Supports(fData, IDelphiSemanticRemoveWithModelEvidence, lEvidence) then
    raise EInvalidOperation.Create('Remove-with lookup cannot attach value evidence.');
  lEvidence.AttachValueMemberEvidence(aEvidence);
end;

function TDelphiSemanticRemoveWithLookupIndex.ExportValueMemberEvidence:
  TDelphiSemanticValueMemberEvidence;
var
  lEvidence: IDelphiSemanticRemoveWithModelEvidence;
begin
  if not Supports(fData, IDelphiSemanticRemoveWithModelEvidence, lEvidence) then
    Exit(Default(TDelphiSemanticValueMemberEvidence));
  Result := lEvidence.ExportValueMemberEvidence;
end;

function TDelphiSemanticRemoveWithLookupIndexData.UnverifiedValueMemberMayApply(
  const aOwnerType, aName: string): Boolean;
begin
  Result := UnverifiedValueMemberMayApply(aOwnerType, aName,
    Default(TDelphiSemanticTypeIdentity));
end;

function TDelphiSemanticRemoveWithLookupIndexData.UnverifiedValueMemberMayApply(
  const aOwnerType, aName: string; const aOwnerIdentity: TDelphiSemanticTypeIdentity): Boolean;
begin
  Result := UnverifiedMemberMayApply(aOwnerType, aName, aOwnerIdentity, True, True);
end;

function TDelphiSemanticRemoveWithLookupIndexData.UnverifiedReceiverMemberMayApply(
  const aOwnerType, aName: string; const aOwnerIdentity: TDelphiSemanticTypeIdentity): Boolean;
begin
  Result := UnverifiedMemberMayApply(aOwnerType, aName, aOwnerIdentity, False, True);
end;

function TDelphiSemanticRemoveWithLookupIndexData.ReceiverLineageDeclaresMember(
  const aOwnerIdentity: TDelphiSemanticTypeIdentity; const aOwnerName, aName: string): Boolean;
var
  i: Integer;
  lDeclaredId: string;
  lOwner: TDelphiSemanticValueEvidenceOwner;
  lRemaining: Integer;
  lSymbol: TDelphiSemanticInventorySymbol;
  lSymbols: TList<TDelphiSemanticInventorySymbol>;
begin
  Result := False;
  EnsureValueMemberEvidence;
  if not fValueEvidence.Available then
    Exit;
  lDeclaredId := aOwnerIdentity.DeclaredId.Value;
  lRemaining := Length(fValueEvidence.Owners);
  while (lRemaining > 0) and fValueOwners.TryGetValue(lDeclaredId, i) do
  begin
    Dec(lRemaining);
    lOwner := fValueEvidence.Owners[i];
    if SameText(lOwner.Name, aOwnerName) and
      fMembersByOwnerName.TryGetValue(OwnerNameKey(lOwner.Name, aName), lSymbols) then
      for lSymbol in lSymbols do
        if SameText(lSymbol.OwnerIdentity.DeclaredId.Value, lDeclaredId) then
          Exit(True);
    lDeclaredId := lOwner.NextDeclaredId;
  end;
end;

function TDelphiSemanticRemoveWithLookupIndex.ReceiverLineageDeclaresMember(
  const aOwnerIdentity: TDelphiSemanticTypeIdentity; const aOwnerName, aName: string): Boolean;
var
  lEvidence: IDelphiSemanticRemoveWithValueEvidence;
begin
  if not Supports(fData, IDelphiSemanticRemoveWithValueEvidence, lEvidence) then
    Exit(False);
  Result := lEvidence.ReceiverLineageDeclaresMember(aOwnerIdentity, aOwnerName, aName);
end;

function TDelphiSemanticRemoveWithLookupIndexData.UnverifiedMemberMayApply(
  const aOwnerType, aName: string; const aOwnerIdentity: TDelphiSemanticTypeIdentity;
  const aValueMembersOnly, aRootProvesAbsence: Boolean; const aSiteUnitName: string): Boolean;
var
  i: Integer;
  lDeclaredId: string;
  lOwner: TDelphiSemanticValueEvidenceOwner;
  lRemaining: Integer;
  lSymbol: TDelphiSemanticInventorySymbol;
  lSymbols: TList<TDelphiSemanticInventorySymbol>;
begin
  // An inventory without an explicit evidence witness cannot prove absence.
  if ((not fValueEvidenceLoaded) and (Length(fValueMemberModels) = 0)) or
    (fValueEvidenceLoaded and (not fValueEvidence.Available)) then
    Exit(True);
  // Retain the cheap model-route fast path before constructing the evidence view.
  if aValueMembersOnly and (not fValueMemberNames.Contains(aName)) then
    Exit(False);
  EnsureValueMemberEvidence;
  if not fValueEvidence.Available then
    Exit(True);
  if aOwnerIdentity.DeclaredId.Value <> '' then
  begin
    // A verified receiver selects its own declaration even when its name is ambiguous.
    // Both model and imported routes share these owner rows and lineage traversal.
    lDeclaredId := aOwnerIdentity.DeclaredId.Value;
    if not fValueOwners.TryGetValue(lDeclaredId, i) then
      Exit(True);
    lOwner := fValueEvidence.Owners[i];
    if (aOwnerIdentity.UnitName = '') or (aOwnerIdentity.Name = '') or
      (aOwnerIdentity.SourceRange.FileName = '') or
      (not SameText(lOwner.UnitName, aOwnerIdentity.UnitName)) or
      (not SameText(lOwner.Name, aOwnerIdentity.Name)) or
      (not SameText(lOwner.FileName, aOwnerIdentity.SourceRange.FileName)) then
      Exit(True);
  end else if not fValueQueries.TryGetValue(aOwnerType.Trim, lDeclaredId) then
    Exit(True);
  lRemaining := Length(fValueEvidence.Owners);
  while (lRemaining > 0) and fValueOwners.TryGetValue(lDeclaredId, i) do
  begin
    Dec(lRemaining);
    lOwner := fValueEvidence.Owners[i];
    if (not lOwner.Complete) or fValueOwnerNames.Contains(lDeclaredId + #31 + aName) then
      Exit(True);
    if (not aValueMembersOnly) and
      fMembersByOwnerName.TryGetValue(OwnerNameKey(lOwner.Name, aName), lSymbols) then
      for lSymbol in lSymbols do
      begin
        // Inventory may add a name the binder could not verify. It can require
        // refusal, never authorize qualification or prove member absence.
        if (lSymbol.OwnerIdentity.DeclaredId.Value = lDeclaredId) or
          (SameText(lSymbol.UnitName, lOwner.UnitName) and
          SameText(lSymbol.FileName, lOwner.FileName)) then
          Exit(True);
      end;
    if lOwner.NextDeclaredId = '' then
      Exit((not lOwner.TerminalVerified) or (lOwner.UnindexedRoot and
        (not aRootProvesAbsence) and
        (not RootMemberAbsenceRecorded(aSiteUnitName, lDeclaredId, aName))));
    lDeclaredId := lOwner.NextDeclaredId;
  end;
  // Missing owners and cycles are unverified coverage.
  Result := True;
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

class function TMemberVerdict.Present(const aMember: TBoundMemberResolution;
  const aMemberTypeOpen: Boolean): TMemberVerdict;
begin
  if (not aMember.Value.Found) or (aMember.Value.Kind = '') then
  begin
    Result := Barrier(noUnproved, 'SELECTOR_MEMBERS_UNVERIFIED',
      'The member provider returned an inconsistent present result.', 'invalid-present');
    Assert(False, 'A present member needs Found and Kind.');
    Exit;
  end;
  Result := Default(TMemberVerdict);
  Result.fOutcome := noResolved;
  Result.fMember := aMember;
  Result.fMemberTypeOpen := aMemberTypeOpen;
end;

class function TMemberVerdict.NotPresent: TMemberVerdict;
begin
  Result := Default(TMemberVerdict);
  Result.fOutcome := noAbsent;
end;

class function TMemberVerdict.Barrier(const aOutcome: TDelphiSemanticNameOutcome;
  const aReasonCode, aReason, aCause: string): TMemberVerdict;
begin
  Result := Default(TMemberVerdict);
  if (not (aOutcome in [noUnproved, noAmbiguous])) or (aReasonCode = '') then
  begin
    Result.fOutcome := noUnproved;
    Result.fReasonCode := 'SELECTOR_MEMBERS_UNVERIFIED';
    Result.fReason := 'The member provider returned an inconsistent barrier.';
    Result.fCause := 'invalid-barrier';
    Assert(False, 'A member barrier needs an unproved/ambiguous outcome and a code.');
    Exit;
  end;
  Result.fOutcome := aOutcome;
  Result.fReasonCode := aReasonCode;
  Result.fReason := aReason;
  Result.fCause := aCause;
end;

function TMemberVerdict.Member: TBoundMemberResolution;
begin
  if fOutcome <> noResolved then
    raise EInvalidOpException.Create('Only a resolved verdict contains a member.');
  Result := fMember;
end;

function TMemberVerdict.AsBound(const aName: string;
  const aReceiverIndex: Integer): TBoundMemberResolution;
begin
  Result := Default(TBoundMemberResolution);
  Result.ReceiverIndex := aReceiverIndex;
  Result.Value.Name := aName;
  case fOutcome of
    noResolved:
    begin
      Result := Member;
      Result.ReceiverIndex := aReceiverIndex;
      Result.Value.Status := 'resolved';
      Result.Value.ReasonCode := '';
    end;
    noAbsent: ;
    noUnproved, noAmbiguous:
    begin
      if fOutcome = noAmbiguous then
        Result.Value.Status := 'ambiguous'
      else
        Result.Value.Status := 'unsupported';
      Result.Value.ReasonCode := fReasonCode;
      Result.Value.Reason := fReason;
      Result.Cause := fCause;
      // An unset verdict fails closed without relying on an assertion.
      if Result.Value.ReasonCode = '' then
        Result.Value.ReasonCode := 'SELECTOR_MEMBERS_UNVERIFIED';
    end;
  end;
end;

function MemberVerdictFromBound(const aBound: TBoundMemberResolution): TMemberVerdict;
begin
  if aBound.Value.Found then
    Exit(TMemberVerdict.Present(aBound));
  if SameText(aBound.Value.Status, 'ambiguous') then
    Exit(TMemberVerdict.Barrier(noAmbiguous, aBound.Value.ReasonCode,
      aBound.Value.Reason, 'legacy-ambiguous'));
  if SameText(aBound.Value.Status, 'unsupported') then
    Exit(TMemberVerdict.Barrier(noUnproved, aBound.Value.ReasonCode,
      aBound.Value.Reason, 'legacy-unsupported'));
  Result := TMemberVerdict.NotPresent;
end;

function MemberVerdictFromLookup(const aName: string;
  const aLookup: TDelphiSemanticMemberLookupResult): TMemberVerdict;
var
  lMember: TBoundMemberResolution;
  lCode: string;
begin
  if aLookup.Found then
  begin
    lMember := Default(TBoundMemberResolution);
    lMember.ReceiverIndex := -1;
    lMember.Value.Found := True;
    lMember.Value.Authoritative := True;
    lMember.Value.Name := aName;
    lMember.Value.Kind := aLookup.Member.Kind;
    lMember.Value.TypeName := aLookup.Member.TypeName;
    lMember.Value.OwnerName := aLookup.Member.OwnerName;
    lMember.Value.Line := aLookup.Member.SourceRange.Line;
    lMember.Value.Column := aLookup.Member.SourceRange.Column;
    lMember.DeclaringUnitName := aLookup.Member.UnitName;
    lMember.OwnerDeclaredId := aLookup.Member.OwnerDeclaredId;
    Exit(TMemberVerdict.Present(lMember));
  end;
  if SameText(aLookup.Status, 'unresolved') and
    SameText(aLookup.ReasonCode, 'DIRECT_MEMBER_NOT_FOUND') then
    Exit(TMemberVerdict.NotPresent);
  lCode := NormalizeMemberLookupReasonCode(aLookup.ReasonCode);
  if aLookup.Ambiguous then
    Exit(TMemberVerdict.Barrier(noAmbiguous, lCode, aLookup.Reason, 'member-lookup'));
  // Recovery 4.7a: these refusals reached the same absence barrier at base.
  if MatchText(aLookup.Status, ['inaccessible', 'hidden', 'overloaded']) or
    SameText(aLookup.ReasonCode, 'OVERLOAD_NOT_FOUND') or (lCode = '') then
    lCode := 'OWNER_INHERITED_MEMBERS_UNVERIFIED';
  Result := TMemberVerdict.Barrier(noUnproved, lCode, aLookup.Reason, 'member-lookup');
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
  const aLookupIndex: TDelphiSemanticRemoveWithLookupIndex;
  const aUnitNameWitness: IDelphiSemanticUnitNameWitness);
var
  lGraph: TDelphiSemanticSemanticGraph;
  lGraphType: TDelphiSemanticGraphType;
  lIndex: Integer;
  lMember: TDelphiSemanticMember;
  lModel: TDelphiSemanticUnitModel;
  lOwnGraph: Boolean;
begin
  inherited Create;
  try
    fUnindexedAliases := TDictionary<string, Boolean>.Create(
      TFastCaseAwareComparer.OrdinalIgnoreCase);
    fModels := aModels;
    // BindProject's caller keeps this graph alive through evidence export.
    fCaptureProofGraph := aGraph;
    fUnitNameWitness := aUnitNameWitness;
    if (fUnitNameWitness = nil) and (aGraph <> nil) then
      fUnitNameWitness := aGraph.UnitNameWitness;
    fLookupIndex := aLookupIndex;
    BuildDeclarationIndex;
    fInventoryByOwnerId := TDictionary<string, TList<TBoundMemberResolution>>.Create(
      TFastCaseAwareComparer.OrdinalIgnoreCase);
    fByUnitOwnerName := TDictionary<string, TList<TBoundMemberResolution>>.Create(
      TFastCaseAwareComparer.OrdinalIgnoreCase);
    fDirectMembersByContextOwnerName := TDictionary<string,
      TList<TBoundMemberResolution>>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
    fMemberKeysByUnit := TDictionary<string, TList<string>>.Create(
      TFastCaseAwareComparer.OrdinalIgnoreCase);
    fSemanticMemberResultsByOwnerName := TDictionary<string,
      TMemberVerdict>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
    fVisibleUnitsByUnit := TDictionary<string, TArray<string>>.Create(
      TFastCaseAwareComparer.OrdinalIgnoreCase);
    lGraph := aGraph;
    lOwnGraph := False;
    if lGraph = nil then
    begin
      lGraph := TDelphiSemanticSemanticGraphBuilder.Build(BuildSyntheticWithBindingProjectInfo,
        aModels);
      lGraph.UnitNameWitness := fUnitNameWitness;
      lOwnGraph := True;
    end;
    try
      fTypeIndex := TDelphiSemanticTypeResolver.BuildIndex(lGraph);
      SetLength(fValueTypeIds, Length(lGraph.Types));
      lIndex := 0;
      for lGraphType in lGraph.Types do
      begin
        fValueTypeIds[lIndex] := lGraphType.DeclaredId;
        Inc(lIndex);
      end;
      fSemanticMemberIndex := TDelphiSemanticMemberResolver.BuildIndex(lGraph, fTypeIndex);
      fSemanticMemberIndexAvailable := True;
      BuildOwnerIdentityIndex;
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
    BuildValueMemberIndex;
    BuildHelperTargetIndex;
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
  FreeAndNil(fOwnerIdentities);
  if fInventoryByOwnerId <> nil then
    for lList in fInventoryByOwnerId.Values do
      lList.Free;
  FreeAndNil(fInventoryByOwnerId);
  FreeAndNil(fValueMembers);
  FreeAndNil(fValueVisibility);
  FreeAndNil(fValueMemberNames);
  FreeAndNil(fUnverifiedValueOwners);
  FreeAndNil(fHelperValueNames);
  FreeAndNil(fHelperTargetDeclaredIds);
  FreeAndNil(fUnindexedAliases);
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


procedure TWithBindingProjectMemberIndex.BuildOwnerIdentityIndex;
var
  lIdentity, lExisting: TDelphiSemanticTypeIdentity;
  lKey: string;
begin
  fOwnerIdentities := TDictionary<string, TDelphiSemanticTypeIdentity>.Create(
    TFastCaseAwareComparer.OrdinalIgnoreCase);
  for var id in fValueTypeIds do
    if fTypeIndex.FindByDeclaredId(id, lIdentity) then
    begin
      lKey := Key(lIdentity.UnitName, lIdentity.Name, '');
      if SameText(lIdentity.ScopeKind, 'routine') then
        lKey := lKey + lIdentity.OwnerScopeId + #31 + lIdentity.SemanticSymbolId;
      if fOwnerIdentities.TryGetValue(lKey, lExisting) and
        (lExisting.DeclaredId.Value <> lIdentity.DeclaredId.Value) then
        lIdentity := Default(TDelphiSemanticTypeIdentity);
      fOwnerIdentities.AddOrSetValue(lKey, lIdentity);
    end;
end;

function TWithBindingProjectMemberIndex.OwnerIdentity(const aUnitName, aOwnerName,
  aScopeId, aSymbolId: string; out aIdentity: TDelphiSemanticTypeIdentity): Boolean;
var
  lKey: string;
begin
  aIdentity := Default(TDelphiSemanticTypeIdentity);
  if (aUnitName = '') or (aOwnerName = '') or
    ((aScopeId <> '') and (aSymbolId = '')) then
    Exit(False);
  lKey := Key(aUnitName, aOwnerName, '');
  if aScopeId <> '' then
    lKey := lKey + aScopeId + #31 + aSymbolId;
  Result := fOwnerIdentities.TryGetValue(lKey, aIdentity) and
    (aIdentity.DeclaredId.Value <> '');
end;

procedure TWithBindingProjectMemberIndex.AddMember(const aUnitName: string;
  const aMember: TDelphiSemanticMember);
var
  lBound: TBoundMemberResolution;
  lKey: string;
  lOwner: TDelphiSemanticTypeIdentity;
begin
  lKey := Key(aUnitName, aMember.OwnerName, aMember.Name);
  lBound := Default(TBoundMemberResolution);
  lBound.Value := MemberResult(aMember);
  lBound.DeclaringUnitName := aUnitName;
  if OwnerIdentity(aUnitName, aMember.OwnerName, aMember.OwnerScopeId,
    aMember.OwnerSymbolId, lOwner) then
    lBound.OwnerDeclaredId := lOwner.DeclaredId;
  AddResultToMap(fByUnitOwnerName, lKey, lBound);
  if lBound.OwnerDeclaredId.Value <> '' then
    AddResultToMap(fInventoryByOwnerId, lBound.OwnerDeclaredId.Value + #31 + aMember.Name, lBound);
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

function TWithBindingProjectMemberIndex.LookupLegacyHelperMember(
  const aContext: TDelphiSemanticMemberLookupContext;
  const aOwner: TDelphiSemanticTypeIdentity; const aName: string):
  TDelphiSemanticMemberLookupResult;
var
  lContext: TDelphiSemanticMemberLookupContext;
  lHelper: TDelphiSemanticTypeIdentity;
  lLineage: TDelphiSemanticLineage;
  lTarget: TDelphiSemanticTypeIdentity;
begin
  lContext := aContext;
  lLineage := fTypeIndex.ResolveLineage(aOwner);
  for var i := 0 to High(lLineage.Items) do
  begin
    if (lLineage.StrongAliasAt >= 0) and (i > lLineage.StrongAliasAt) then
      Break;
    lTarget := lLineage.Items[i];
    for lHelper in fTypeIndex.FindHelpersForTarget(lTarget.DeclaredId.Value) do
    begin
      Result := fSemanticMemberIndex.ResolveDirectMemberByOwnerId(lHelper.DeclaredId, aName);
      if Length(Result.Candidates) = 0 then
        Continue;
      lContext.OwnerDeclaredId := lHelper.DeclaredId;
      Result := fSemanticMemberIndex.ResolveMember(lContext, '', aName);
      if Result.Found then
        Result.Status := 'helper';
      Exit;
    end;
  end;
  Result := Default(TDelphiSemanticMemberLookupResult);
  Result.Status := 'unresolved';
  Result.ReasonCode := 'DIRECT_MEMBER_NOT_FOUND';
end;

function TWithBindingProjectMemberIndex.LookupIdentityMember(
  const aContext: TDelphiSemanticMemberLookupContext;
  const aOwner: TDelphiSemanticTypeIdentity; const aName: string;
  const aCheckHidden, aCheckHelpers: Boolean): TDelphiSemanticMemberLookupResult;
var
  lContext: TDelphiSemanticMemberLookupContext;
  lExpanded: TDelphiSemanticMemberLookupResult;
  lIdentity: TDelphiSemanticTypeIdentity;
  lLineage: TDelphiSemanticLineage;
  lHidden: Boolean;
begin
  lContext := aContext;
  lContext.OwnerDeclaredId := aOwner.DeclaredId;
  Result := fSemanticMemberIndex.ResolveMember(lContext, '', aName);
  if (not aCheckHidden) or (Length(Result.Candidates) = 0) then
    Exit;
  // The spelling-based semantic provider checked hidden members before access
  // and overload resolution. Preserve that refusal without choosing D by name.
  lHidden := False;
  lLineage := fTypeIndex.ResolveLineage(aOwner);
  for lIdentity in lLineage.Items do
    if lIdentity.DeclaredId.Value <> aOwner.DeclaredId.Value then
    begin
      lExpanded := fSemanticMemberIndex.ResolveDirectMemberByOwnerId(lIdentity.DeclaredId, aName);
      if Length(lExpanded.Candidates) > 0 then
      begin
        lHidden := True;
        Break;
      end;
    end;
  if (not lHidden) and aCheckHelpers then
  begin
    lExpanded := LookupLegacyHelperMember(aContext, aOwner, aName);
    lHidden := Length(lExpanded.Candidates) > 0;
  end;
  if lHidden then
  begin
    Result.Found := False;
    Result.Ambiguous := False;
    Result.Status := 'hidden';
    Result.ReasonCode := 'MEMBER_HIDES_INHERITED';
    Result.Reason := 'A direct member hides an inherited or helper-provided member.';
  end;
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
var
  lVerdict: TMemberVerdict;
begin
  lVerdict := TryResolveDirectMember(aCurrentUnitName, aCurrentTypeName, aOwnerName,
    aName, aAllowSemanticFallback, '', Default(TDelphiSemanticTypeIdentity));
  aResult := lVerdict.AsBound(aName, -1);
  Result := lVerdict.Outcome <> noAbsent;
end;

function TWithBindingProjectMemberIndex.TryResolveDirectMember(const aCurrentUnitName,
  aCurrentTypeName, aOwnerName, aName: string; const aAllowSemanticFallback: Boolean;
  const aCurrentFileName: string; const aOwnerIdentity: TDelphiSemanticTypeIdentity;
  const aIncludeHelpers: Boolean): TMemberVerdict;
var
  lBinding: TDelphiSemanticWithBinding;
  lIdentityLineage: TDelphiSemanticLineage;
  lVerdict: TMemberVerdict;
  lBound: TBoundMemberResolution;
  lContext: TDelphiSemanticMemberLookupContext;
  lIdentity: TDelphiSemanticTypeIdentity;
  lLookup: TDelphiSemanticMemberLookupResult;
  lInventory: TList<TBoundMemberResolution>;
begin
  if aOwnerIdentity.DeclaredId.Value <> '' then
  begin
    lBinding := Default(TDelphiSemanticWithBinding);
    lBinding.UnitName := aCurrentUnitName;
    lBinding.FileName := aCurrentFileName;
    lIdentityLineage := TryBuildMemberSafetyLineage(lBinding, aOwnerName, aOwnerIdentity);
    // Inventory lookup predates semantic permission. Retain that fast path,
    // keyed by the held owner ID, without expanding to inherited members.
    if fInventoryByOwnerId.TryGetValue(aOwnerIdentity.DeclaredId.Value + #31 + aName,
      lInventory) then
    begin
      ResolveMemberList(aOwnerName, aName, lInventory, lBound);
      Exit(MemberVerdictFromBound(lBound));
    end;
    if (not aAllowSemanticFallback) or (not fSemanticMemberIndexAvailable) then
      Exit(TMemberVerdict.NotPresent);
    lContext := Default(TDelphiSemanticMemberLookupContext);
    lContext.CallerUnitName := aCurrentUnitName;
    lContext.CurrentTypeName := aCurrentTypeName;
    if OwnerIdentity(aCurrentUnitName, aCurrentTypeName, '', '', lIdentity) then
      lContext.CurrentTypeId := lIdentity.DeclaredId;
    lContext.InstanceContext := True;
    for lIdentity in lIdentityLineage.Items do
    begin
      if SameText(lIdentity.Kind, 'type-alias') then
        Continue;
      lLookup := LookupIdentityMember(lContext, lIdentity, aName,
        lIdentity.DeclaredId.Value = aOwnerIdentity.DeclaredId.Value, aIncludeHelpers);
      lVerdict := MemberVerdictFromLookup(aName, lLookup);
      if lVerdict.Outcome <> noAbsent then
        Exit(lVerdict);
    end;
    if not lIdentityLineage.Complete then
      Exit(TMemberVerdict.NotPresent);
    if not aIncludeHelpers then
      Exit(TMemberVerdict.NotPresent);
    // Non-receiver legacy callers keep their helper behavior.
    lLookup := LookupLegacyHelperMember(lContext, aOwnerIdentity, aName);
    Exit(MemberVerdictFromLookup(aName, lLookup));
  end;
  // Missing declaration identity is an unproved receiver, never an inventory
  // miss or permission to resolve its spelling in a different scope.
  Result := TMemberVerdict.Barrier(noUnproved, 'OWNER_INHERITED_MEMBERS_UNVERIFIED',
    'The receiver has no held declaration identity for member lookup.', 'owner-identity');
end;

function RoutineLocalTypeHasOnlyDirectMembers(
  const aIdentity: TDelphiSemanticTypeIdentity): Boolean;
begin
  Result := SameText(aIdentity.Kind, 'type') and (aIdentity.BaseTypeName = '') and
    (aIdentity.HelperTargetName = '') and
    MatchText(aIdentity.UnderlyingName, ['record', 'packed record']);
end;

function ReceiverLookupSite(const aModel: TDelphiSemanticUnitModel;
  const aLine, aColumn: Integer): TReceiverLookupSite;
begin
  Result.UnitName := aModel.UnitName;
  Result.FileName := aModel.FileName;
  Result.Line := aLine;
  Result.Column := aColumn;
end;

function TWithBindingProjectMemberIndex.TryResolveRoutineLocalMember(
  const aOwnerIdentity: TDelphiSemanticTypeIdentity; const aCurrentTypeName, aName: string;
  const aSite: TReceiverLookupSite): TMemberVerdict;
var
  lBinding: TDelphiSemanticWithBinding;
  lContext: TDelphiSemanticMemberLookupContext;
  lIdentity: TDelphiSemanticTypeIdentity;
  lLineage: TDelphiSemanticLineage;
  lLookup: TDelphiSemanticMemberLookupResult;
  lModel: TDelphiSemanticUnitModel;
  lOwnerVerified: Boolean;
  lSelector: TDelphiSemanticWithSelectorBinding;
  lRefusalCode: string;
  lVerdict: TMemberVerdict;
  lBound: TBoundMemberResolution;
  lVerifiedIdentity: TDelphiSemanticTypeIdentity;
begin
  // A routine-local type is identified only by its declaration. An owner-name
  // probe would also see same-named types of other routines or of the unit.
  if (aOwnerIdentity.DeclaredId.Value = '') or (not fSemanticMemberIndexAvailable) then
  begin
    lBound := Default(TBoundMemberResolution);
    lBound.Value.Status := 'unsupported';
    lBound.Value.Name := aName;
    lBound.Value.ReasonCode := 'ROUTINE_OWNER_IDENTITY_MISSING';
    lBound.Value.Reason := 'The routine-local receiver type has no declaration identity.';
    Exit(MemberVerdictFromBound(lBound));
  end;
  if SameText(aOwnerIdentity.Kind, 'type-alias') then
  begin
    // DS-701: finalized aliases own no direct fields. Resolve through the
    // source-proven target lineage, retaining access checks for unit types.
    lBound := Default(TBoundMemberResolution);
    lBound.Value.Status := 'unsupported';
    lBound.Value.Name := aName;
    lBound.Value.ReasonCode := 'ROUTINE_OWNER_INHERITED_MEMBERS_UNVERIFIED';
    lBound.Value.Reason := 'The routine-local alias target members are not verified.';
    if (aOwnerIdentity.CanonicalId.Value = '') or
      (aOwnerIdentity.UnderlyingId.Value = '') or
      (not TrySafetyDeclarationModel(aOwnerIdentity, lModel)) then
      Exit(MemberVerdictFromBound(lBound));
    lBinding := Default(TDelphiSemanticWithBinding);
    lBinding.UnitName := lModel.UnitName;
    lBinding.FileName := lModel.FileName;
    lLineage := TryBuildMemberSafetyLineage(lBinding, aOwnerIdentity.Name,
      aOwnerIdentity);
    if not lLineage.Complete then
      Exit(MemberVerdictFromBound(lBound));
    lContext := Default(TDelphiSemanticMemberLookupContext);
    lContext.CallerUnitName := aOwnerIdentity.UnitName;
    lContext.CurrentTypeName := aCurrentTypeName;
    if OwnerIdentity(aSite.UnitName, aCurrentTypeName, '', '', lIdentity) then
      lContext.CurrentTypeId := lIdentity.DeclaredId;
    lContext.InstanceContext := True;
    for lIdentity in lLineage.Items do
    begin
      if SameText(lIdentity.Kind, 'type-alias') then
        Continue;
      lLookup := LookupIdentityMember(lContext, lIdentity, aName,
        not SameText(lIdentity.ScopeKind, 'routine'));
      if lLookup.Found then
      begin
        lOwnerVerified := False;
        for lVerifiedIdentity in lLineage.Items do
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
          Exit(MemberVerdictFromBound(lBound));
      end;
      lVerdict := MemberVerdictFromLookup(aName, lLookup);
      if lVerdict.Outcome <> noAbsent then
        Exit(lVerdict);
      // A failed access or overload check is not proof that the member is
      // absent. It must shield same-named declarations farther out.
      if (not SameText(lLookup.Status, 'unresolved')) or
        (not SameText(lLookup.ReasonCode, 'DIRECT_MEMBER_NOT_FOUND')) then
      begin
        lBound.Value.ReasonCode := NormalizeMemberLookupReasonCode(lLookup.ReasonCode);
        lBound.Value.Reason := lLookup.Reason;
        Exit(MemberVerdictFromBound(lBound));
      end;
    end;
    lSelector := Default(TDelphiSemanticWithSelectorBinding);
    lSelector.TypeName := aOwnerIdentity.Name;
    lSelector.TypeIdentity := aOwnerIdentity;
    lVerdict := TryResolveReceiverValueMember(lModel, aSite, lSelector, aName, '');
    if lVerdict.Outcome <> noAbsent then
      Exit(lVerdict);
    if ReceiverMemberAbsenceIsVerified(lModel, lSelector, aName, aSite, lRefusalCode) then
    begin
      lBound := Default(TBoundMemberResolution);
      Exit(TMemberVerdict.NotPresent);
    end;
    if BinderDenialCode(lRefusalCode) then
    begin
      lBound.Value.ReasonCode := lRefusalCode;
      lBound.Value.Reason := 'The receiver member absence is not verified.';
    end;
    Exit(MemberVerdictFromBound(lBound));
  end;
  lLookup := fSemanticMemberIndex.ResolveDirectMemberByOwnerId(aOwnerIdentity.DeclaredId,
    aName);
  lVerdict := MemberVerdictFromLookup(aName, lLookup);
  if lVerdict.Outcome <> noAbsent then
    Exit(lVerdict);
  lBound := Default(TBoundMemberResolution);
  // The owner-ID lookup sees direct members only. A direct miss proves "not a
  // member" only for a plain local record: Delphi rejects local class,
  // interface, object and helper types (E2059) and local record methods
  // (E2433). Any other local type may inherit, so we refuse the name.
  if (lVerdict.Outcome = noAbsent) and RoutineLocalTypeHasOnlyDirectMembers(aOwnerIdentity) and
    LineageHasActivityFact([aOwnerIdentity]) then
  begin
    lBound.Value.Status := 'unsupported';
    lBound.Value.Name := aName;
    lBound.Value.ReasonCode := 'OWNER_INHERITED_MEMBERS_UNVERIFIED';
    lBound.Value.OwnerName := aOwnerIdentity.Name;
    lBound.Value.Reason := 'The routine-local receiver member activity is unverified.';
    Exit(MemberVerdictFromBound(lBound));
  end;
  if (lVerdict.Outcome = noAbsent) and RoutineLocalTypeHasOnlyDirectMembers(aOwnerIdentity) and
    (not LineageHasActivityFact([aOwnerIdentity])) and
    fValueMembers.ContainsKey(aOwnerIdentity.DeclaredId.Value + #31 + aName) then
  begin
    lModel := Default(TDelphiSemanticUnitModel);
    if TrySafetyDeclarationModel(aOwnerIdentity, lModel) then
    begin
      lSelector := Default(TDelphiSemanticWithSelectorBinding);
      lSelector.TypeName := aOwnerIdentity.Name;
      lSelector.TypeIdentity := aOwnerIdentity;
      lVerdict := TryResolveReceiverValueMember(lModel, aSite, lSelector, aName, '');
      if lVerdict.Outcome <> noAbsent then
        Exit(lVerdict);
    end;
  end;
  if (lVerdict.Outcome = noAbsent) and (not RoutineLocalTypeHasOnlyDirectMembers(aOwnerIdentity)) then
  begin
    lBound := Default(TBoundMemberResolution);
    lBound.Value.Status := 'unsupported';
    lBound.Value.Name := aName;
    lBound.Value.ReasonCode := 'ROUTINE_OWNER_INHERITED_MEMBERS_UNVERIFIED';
    lBound.Value.Reason := 'Members the routine-local receiver type may inherit are not verified.';
    Exit(MemberVerdictFromBound(lBound));
  end;
  Result := TMemberVerdict.NotPresent;
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

function AliasTargetTypeName(const aIdentity: TDelphiSemanticTypeIdentity;
  out aStrong: Boolean): string; forward;

function CallerTypeNameFromRoutineName(const aRoutineName: string): string; forward;

function CallerTypeNameForRoutineContext(const aModel: TDelphiSemanticUnitModel;
  const aRoutineName: string; const aParentRoutineNames: TArray<string>;
  const aLine: Integer): string; forward;

function RoutineLookupNameForRoutineContext(const aModel: TDelphiSemanticUnitModel;
  const aRoutineName: string; const aLine: Integer): string; forward;

function ReceiverMemberCachePrefix(const aUnitName, aFileName, aCurrentTypeName,
  aRoutineName: string; const aLine, aColumn: Integer;
  const aSelectors: TArray<TDelphiSemanticWithSelectorBinding>): string; forward;

function ResolveMemberAt(const aModel: TDelphiSemanticUnitModel;
  const aSite: TReceiverLookupSite;
  const aProjectModels: TArray<TDelphiSemanticUnitModel>;
  const aSelectors: TArray<TDelphiSemanticWithSelectorBinding>;
  const aCurrentTypeName, aMemberCachePrefix, aName: string;
  const aProjectMemberIndex: TWithBindingProjectMemberIndex;
  const aMemberCache: TDictionary<string, TMemberVerdict>): TMemberVerdict; forward;

function TryResolveReceiverMember(const aModel: TDelphiSemanticUnitModel;
  const aSite: TReceiverLookupSite;
  const aProjectModels: TArray<TDelphiSemanticUnitModel>;
  const aSelectors: TArray<TDelphiSemanticWithSelectorBinding>;
  const aCurrentTypeName, aMemberCachePrefix, aName: string;
  const aProjectMemberIndex: TWithBindingProjectMemberIndex;
  const aMemberCache: TDictionary<string, TMemberVerdict>;
  out aResult: TDelphiSemanticResolveResult): Boolean; overload; forward;

function TryResolveReceiverMember(const aModel: TDelphiSemanticUnitModel;
  const aSite: TReceiverLookupSite;
  const aProjectModels: TArray<TDelphiSemanticUnitModel>;
  const aSelectors: TArray<TDelphiSemanticWithSelectorBinding>;
  const aCurrentTypeName, aMemberCachePrefix, aName: string;
  const aProjectMemberIndex: TWithBindingProjectMemberIndex;
  const aMemberCache: TDictionary<string, TMemberVerdict>;
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
  lVisibleUnits := fTypeIndex.VisibleUnitNames(aModel.UnitName, 'implementation');
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
        fTypeIndex.VisibleUnitNames(lAliasModel.UnitName, lDeclaration.SectionKind),
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
    // The parameter token coordinates and name identify its declaration. The
    // resolved TypeName may be the selector's final type, so it cannot identify
    // the parameter.
    // Delphi resolves a heading's types in the scope enclosing the routine, so the
    // routine's own local types are not visible there. ScopeId and ParentScopeId come
    // from the uniquely matched AST scope, so an empty parent is a verified top level.
    for lRoutine in aModel.Routines do
      if SameText(lRoutine.Name, aResolved.OwnerName) and (lRoutine.ScopeId <> '') and
        (lRoutine.AstScopeKind <> '') then
        for lParameter in lRoutine.Parameters do
          if SameText(lParameter.Name, aResolved.Name) and
            (lParameter.Line = aResolved.Line) and (lParameter.Column = aResolved.Column) then
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

function AnonymousLocalHasTypeNameCollision(const aModel: TDelphiSemanticUnitModel;
  const aProjectModels: TArray<TDelphiSemanticUnitModel>;
  const aResolved: TDelphiSemanticResolveResult): Boolean;
var
  lDeclaration: TDelphiSemanticDeclaration;
  lLexer: TmwBasePasLex;
  lLocal: TDelphiSemanticLocal;
  lModel: TDelphiSemanticUnitModel;
  lRecord: Boolean;
begin
  Result := False;
  if not aResolved.Found or not SameText(aResolved.Kind, 'local') then
    Exit;
  for lLocal in aModel.Locals do
  begin
    if not SameText(lLocal.Name, aResolved.Name) or
      (lLocal.Line <> aResolved.Line) or (lLocal.Column <> aResolved.Column) or
      not SameText(lLocal.TypeName, lLocal.RoutineName + '.' + lLocal.Name) or
      ((lLocal.FileName <> '') and not SameText(lLocal.FileName, aModel.FileName)) or
      (lLocal.Offset < 1) then
      Continue;
    // Synthetic text alone is not evidence: a named type can have this spelling.
    // Verify the inline record at the exact local declaration before refusing.
    lRecord := False;
    lLexer := TmwBasePasLex.Create;
    try
      lLexer.UseDefines := False;
      lLexer.Origin := Copy(aModel.SourceText, lLocal.Offset, MaxInt);
      while not (lLexer.TokenID in [ptNull, ptSemiColon, ptColon]) do
        lLexer.Next;
      if lLexer.TokenID = ptColon then
      begin
        lLexer.Next;
        while lLexer.TokenID in [ptSpace, ptCRLF, ptAnsiComment, ptBorComment, ptSlashesComment] do
          lLexer.Next;
        if lLexer.TokenID = ptPacked then
        begin
          lLexer.Next;
          while lLexer.TokenID in [ptSpace, ptCRLF, ptAnsiComment, ptBorComment, ptSlashesComment] do
            lLexer.Next;
        end;
        lRecord := lLexer.TokenID = ptRecord;
      end;
    finally
      lLexer.Free;
    end;
    if not lRecord then
      Continue;
    for lModel in aProjectModels do
      for lDeclaration in lModel.Declarations do
        if MatchText(lDeclaration.Kind, ['type', 'type-alias']) and
          (SameText(lDeclaration.Name, lLocal.TypeName) or
          SameText(lDeclaration.Name, lLocal.Name) or
          EndsText('.' + lLocal.Name, lDeclaration.Name)) and
          not (SameText(lModel.FileName, aModel.FileName) and
          (lDeclaration.Line = lLocal.Line) and
          (lDeclaration.Column >= lLocal.Column) and
          (lDeclaration.Column < lLocal.Column + Length(lLocal.Name))) then
          Exit(True);
  end;
end;

function MakeSelectorBinding(const aModel: TDelphiSemanticUnitModel;
  const aProjectModels: TArray<TDelphiSemanticUnitModel>; const aRoutineName,
  aCurrentTypeName, aSelectorText: string; const aParentRoutineNames: TArray<string>;
  const aPreviousSelectors, aParentSelectors: TArray<TDelphiSemanticWithSelectorBinding>;
  const aLine, aColumn: Integer;
  const aProjectMemberIndex: TWithBindingProjectMemberIndex;
  const aMemberCache: TDictionary<string, TMemberVerdict>;
  out aIdentity: TDelphiSemanticTypeIdentity):
  TDelphiSemanticWithSelectorBinding;
var
  lBaseName: string;
  lBaseResult: TDelphiSemanticResolveResult;
  lBound: TBoundMemberResolution;
  lCastName: string;
  lCastResult: TDelphiSemanticResolveResult;
  lCastType: string;
  lCaptureTypeName, lCaptureTypeStatus: string;
  lTypeLookup: TDelphiSemanticTypeLookupResult;
  lClassTypeResolution: TDelphiSemanticTypeResolution;
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
    lLookup: TDelphiSemanticTypeLookupResult;
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
      if not TRegEx.IsMatch(lPointerTypeName, '^[A-Za-z_][A-Za-z0-9_]*$') then
        Exit;
      lLookup := aProjectMemberIndex.SelectorTypeLookup(aModel,
        lContext.SectionKind, aPointerScopeId, lPointerTypeName);
      if MatchText(lLookup.Status, ['unproved', 'ambiguous']) then
      begin
        // Keep the failed alias proof: inventory fallback may find its pointee,
        // but that cannot make an unknown declaration visible (DS-719).
        lCaptureTypeName := lPointerTypeName;
        lCaptureTypeStatus := lLookup.Status;
        Exit;
      end;
      if not aProjectMemberIndex.TryResolveSelectorIdentity(aModel,
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
    if not TRegEx.IsMatch(aPointeeName, '^[A-Za-z_][A-Za-z0-9_]*$') then
      Exit;
    lLookup := aProjectMemberIndex.SelectorTypeLookup(lTargetModel,
      lTargetSection, lTargetScopeId, aPointeeName);
    if MatchText(lLookup.Status, ['unproved', 'ambiguous']) then
    begin
      lCaptureTypeName := aPointeeName;
      lCaptureTypeStatus := lLookup.Status;
      Exit;
    end;
    Result := aProjectMemberIndex.TryResolveSelectorIdentity(lTargetModel, lTargetSection,
      lTargetScopeId, aPointeeName, aPointeeIdentity) and
      SameText(aPointeeIdentity.Kind, 'type') and
      SameText(aPointeeIdentity.CanonicalName, 'record');
  end;
begin
  Result.CaptureInsertionLine := 0;
  aIdentity := Default(TDelphiSemanticTypeIdentity);
  lCaptureTypeName := '';
  lCaptureTypeStatus := '';
  lLexicalPointerBase := False;
  lVerifiedLocalPointer := False;
  lOriginModel := Default(TDelphiSemanticUnitModel);
  lOriginSection := '';
  lOriginScopeId := '';
  lOwnRoutineScopeId := '';
  // Lexical symbols are declared in the current unit; a bound member in its owner's unit.
  lSymbolModel := aModel;
  lSelectorText := aSelectorText.Trim;
  if (aModel.DirectiveFacts.ImportCause <> '') then
  begin
    Result.SelectorText := lSelectorText;
    Result.Status := 'unsupported';
    Result.ReasonCode := aModel.DirectiveFacts.ImportCause;
    Result.Cause := LowerCase(Result.ReasonCode).Replace('_', '-');
    Exit;
  end;
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
          ReceiverLookupSite(aModel, aLine, aColumn),
          aPreviousSelectors, aCurrentTypeName,
          ReceiverMemberCachePrefix(aModel.UnitName, aModel.FileName, aCurrentTypeName,
          aRoutineName, aLine, aColumn, aPreviousSelectors), lBaseName,
          aMemberCache, lBound);
      if (not lWithBase) and (Length(aParentSelectors) > 0) then
        lWithBase := aProjectMemberIndex.TryResolveVerifiedSimpleMember(aModel,
          ReceiverLookupSite(aModel, aLine, aColumn),
          aParentSelectors, aCurrentTypeName,
          ReceiverMemberCachePrefix(aModel.UnitName, aModel.FileName, aCurrentTypeName,
          aRoutineName, aLine, aColumn, aParentSelectors), lBaseName,
          aMemberCache, lBound);
    end else
    begin
      if Length(aPreviousSelectors) > 0 then
        lWithBase := TryResolveReceiverMember(aModel,
          ReceiverLookupSite(aModel, aLine, aColumn), aProjectModels,
          aPreviousSelectors, aCurrentTypeName,
          ReceiverMemberCachePrefix(aModel.UnitName, aModel.FileName, aCurrentTypeName,
          aRoutineName, aLine, aColumn,
          aPreviousSelectors), lBaseName, aProjectMemberIndex, aMemberCache,
          lBound);
      if (not lWithBase) and (Length(aParentSelectors) > 0) then
        lWithBase := TryResolveReceiverMember(aModel,
          ReceiverLookupSite(aModel, aLine, aColumn), aProjectModels,
          aParentSelectors, aCurrentTypeName,
          ReceiverMemberCachePrefix(aModel.UnitName, aModel.FileName, aCurrentTypeName,
          aRoutineName, aLine, aColumn,
          aParentSelectors), lBaseName, aProjectMemberIndex, aMemberCache,
          lBound);
    end;
  end;
  if not lWithBase then
  begin
    lBaseResult := ResolveNameThroughWithBindingAuthority(aModel, lContext, lBaseName);
    if AnonymousLocalHasTypeNameCollision(aModel, aProjectModels, lBaseResult) then
    begin
      Result.SelectorText := lSelectorText;
      Result.Status := 'unsupported';
      Result.ReasonCode := 'ANONYMOUS_SELECTOR_NAME_COLLISION';
      Result.Cause := 'anonymous-selector-name-collision';
      Exit;
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
    (not TryResolveReceiverMember(aModel,
      ReceiverLookupSite(aModel, aLine, aColumn), aProjectModels, aPreviousSelectors,
    aCurrentTypeName, ReceiverMemberCachePrefix(aModel.UnitName, aModel.FileName, aCurrentTypeName,
    aRoutineName, aLine, aColumn,
    aPreviousSelectors), lCastName, aProjectMemberIndex, aMemberCache, lCastResult)) and
    (not TryResolveReceiverMember(aModel,
      ReceiverLookupSite(aModel, aLine, aColumn), aProjectModels, aParentSelectors,
    aCurrentTypeName, ReceiverMemberCachePrefix(aModel.UnitName, aModel.FileName, aCurrentTypeName,
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
  if (aModel.DirectiveFacts.NameCause(lResult.TypeName) <> '') or
    aModel.DirectiveFacts.HelpersUnproved then
  begin
    Result.SelectorText := lSelectorText;
    Result.Status := 'unsupported';
    Result.ReasonCode := aModel.DirectiveFacts.NameCause(lResult.TypeName);
    if Result.ReasonCode = '' then
      Result.ReasonCode := 'DECLARATIONS_DIRECTIVE_UNPROVED';
    Result.Cause := LowerCase(Result.ReasonCode).Replace('_', '-');
    Exit;
  end;
  if lResult.Found and SelectorUsesUnsafeProperty(aModel, lContext, lSelectorText) then
    MarkPropertySelectorUnsupported(lSelectorText, lResult);
  if lResult.Found and SameText(lResult.Status, 'resolved') then
    if lVerifiedLocalPointer then
      aIdentity := lPointerIdentity
    else if (not lComplex) and (not lWithBase) and
      aProjectMemberIndex.TryClassScopedReceiverType(aModel, lBaseResult,
        aCurrentTypeName, lClassTypeResolution) then
    begin
      if lClassTypeResolution.Outcome = noResolved then
        aIdentity := lClassTypeResolution.Identity
      else if not ((lClassTypeResolution.Outcome = noUnproved) and
        MatchText(lClassTypeResolution.Cause, ['external-unindexed', 'witness-unknown']) and
        StartsText('uses:', lClassTypeResolution.DecidingScope)) then
      begin
        lResult.Status := 'unsupported';
        lResult.ReasonCode := 'TYPE_VISIBILITY_UNPROVED';
        lResult.Reason := 'The class-scoped receiver type is not proved at its declaration.';
      end;
    end else if ((lWithBase or (not MatchText(lResult.Kind, ['field', 'member', 'property']))) or
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
        lTypeLookup := aProjectMemberIndex.SelectorTypeLookup(lOriginModel, lOriginSection,
          lOriginScopeId, lResult.TypeName);
        if MatchText(lTypeLookup.ReasonCode, ['TYPE_VISIBILITY_UNPROVED',
          'IMPORTS_DIRECTIVE_UNPROVED', 'DECLARATIONS_DIRECTIVE_UNPROVED',
          'UNIT_DIRECTIVE_UNPROVED']) then
        begin
          lResult.Status := 'unsupported';
          lResult.ReasonCode := lTypeLookup.ReasonCode;
          lResult.Reason := 'The receiver type is not proved at its declaration.';
        end else if (lOriginScopeId <> '') and
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
      if SameText(lResult.Status, 'resolved') and (lResult.ReasonCode = '') and
        (aIdentity.DeclaredId.Value = '') and
        aProjectMemberIndex.UnindexedAliasMayApply(lResult.TypeName) then
        lResult.ReasonCode := 'ALIAS_RECEIVER_MEMBERS_UNVERIFIED';
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
  if lWithBase and (not lComplex) and lResult.Found and
    DeclarationTypeVisibilityUnproved(lSymbolModel, lResult) then
  begin
    aIdentity := Default(TDelphiSemanticTypeIdentity);
    lResult.Status := 'unsupported';
    lResult.ReasonCode := 'TYPE_VISIBILITY_UNPROVED';
  end;
  if lWithBase then
    Result.Cause := lBound.Cause;
  if SameText(lResult.ReasonCode, 'TYPE_VISIBILITY_UNPROVED') and
    ((lResult.Reason <> '') or lWithBase) then
    Result.Cause := 'declaration-site-later-type';
  Result.CaptureTypeName := lCaptureTypeName;
  Result.CaptureTypeStatus := lCaptureTypeStatus;
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
  Result.ReceiverIndex := -1;
  Result.Name := aName;
  Result.Classification := aClassification;
  Result.LookupSource := LookupSourceForClassification(aClassification);
  Result.ReceiverTypeName := aResult.OwnerName;
  Result.Kind := aResult.Kind;
  Result.TypeName := aResult.TypeName;
  Result.ReasonCode := aResult.ReasonCode;
end;

function MakeMemberBoundReference(const aName, aClassification: string;
  const aVerdict: TMemberVerdict): TDelphiSemanticBoundReference;
var
  lBound: TBoundMemberResolution;
  lReceiverIndex: Integer;
begin
  lReceiverIndex := -1;
  if aVerdict.Outcome = noResolved then
    lReceiverIndex := aVerdict.Member.ReceiverIndex;
  lBound := aVerdict.AsBound(aName, lReceiverIndex);
  Result := MakeBoundReference(aName, aClassification, lBound.Value);
  Result.ReceiverIndex := lBound.ReceiverIndex;
  Result.Cause := lBound.Cause;
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

function PrepareWithBindingSource(const aModel: TDelphiSemanticUnitModel):
  TWithBindingSourceContext;
begin
  Result.LineStarts := BuildBodyLineStarts(aModel.SourceText);
  Result.Lines := aModel.SourceText.Split([#13#10, #10]);
  Result.SanitizedSourceText := SanitizeCodeText(aModel.SourceText);
  if aModel.ReferenceScanSourceText <> '' then
    Result.ReferenceScanText := TDelphiSemanticSourceConditionals.SourceForScan(
      aModel.SourceText, aModel.ReferenceScanSourceText)
  else
    Result.ReferenceScanText := TDelphiSemanticSourceConditionals.SourceForScan(
      aModel.SourceText, aModel.VerifiedActiveSourceText);
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

function ReceiverMemberCachePrefix(const aUnitName, aFileName, aCurrentTypeName,
  aRoutineName: string; const aLine, aColumn: Integer;
  const aSelectors: TArray<TDelphiSemanticWithSelectorBinding>): string;
var
  lBuilder: TStringBuilder;
  lSelector: TDelphiSemanticWithSelectorBinding;
begin
  lBuilder := TStringBuilder.Create;
  try
    lBuilder.Append(aUnitName).Append(#31).Append(aFileName).Append(#31)
      .Append(aCurrentTypeName).Append(#31)
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
  const aSite: TReceiverLookupSite;
  const aProjectModels: TArray<TDelphiSemanticUnitModel>;
  const aSelectors: TArray<TDelphiSemanticWithSelectorBinding>;
  const aCurrentTypeName, aMemberCachePrefix, aName: string;
  const aProjectMemberIndex: TWithBindingProjectMemberIndex;
  const aMemberCache: TDictionary<string, TMemberVerdict>;
  out aResult: TDelphiSemanticResolveResult): Boolean;
var
  lBound: TBoundMemberResolution;
begin
  Result := TryResolveReceiverMember(aModel, aSite, aProjectModels, aSelectors,
    aCurrentTypeName, aMemberCachePrefix, aName, aProjectMemberIndex,
    aMemberCache, lBound);
  aResult := lBound.Value;
end;

function TryResolveReceiverMember(const aModel: TDelphiSemanticUnitModel;
  const aSite: TReceiverLookupSite;
  const aProjectModels: TArray<TDelphiSemanticUnitModel>;
  const aSelectors: TArray<TDelphiSemanticWithSelectorBinding>;
  const aCurrentTypeName, aMemberCachePrefix, aName: string;
  const aProjectMemberIndex: TWithBindingProjectMemberIndex;
  const aMemberCache: TDictionary<string, TMemberVerdict>;
  out aResult: TBoundMemberResolution): Boolean;
var
  lVerdict: TMemberVerdict;
  lReceiverIndex: Integer;
begin
  lVerdict := ResolveMemberAt(aModel, aSite, aProjectModels, aSelectors,
    aCurrentTypeName, aMemberCachePrefix, aName, aProjectMemberIndex, aMemberCache);
  lReceiverIndex := -1;
  if (lVerdict.Outcome = noResolved) and lVerdict.MemberTypeOpen then
    lVerdict := TMemberVerdict.Barrier(noUnproved, 'OWNER_INHERITED_MEMBERS_UNVERIFIED',
      'The member receiver is known but its result type is open.', 'members-open');
  if lVerdict.Outcome = noResolved then
    lReceiverIndex := lVerdict.Member.ReceiverIndex;
  aResult := lVerdict.AsBound(aName, lReceiverIndex);
  Result := lVerdict.Outcome <> noAbsent;
end;

function TWithBindingProjectMemberIndex.ResolveReceiverMemberVerdict(
  const aModel: TDelphiSemanticUnitModel; const aSite: TReceiverLookupSite;
  const aSelector, aOriginalSelector: TDelphiSemanticWithSelectorBinding;
  const aCurrentTypeName, aName: string; const aDirect: TMemberVerdict): TMemberVerdict;
var
  lBinding: TDelphiSemanticWithBinding;
  lContext: TDelphiSemanticMemberLookupContext;
  lLineage: TDelphiSemanticLineage;
  lHelpers: TDelphiSemanticHelperResolution;
  lNameSite: TDelphiSemanticNameSite;
  lStatement: TDelphiSemanticWithStatement;
  lIdentity, lCaller: TDelphiSemanticTypeIdentity;
  lDirect, lValue, lHelper: TMemberVerdict;
  lLookup: TDelphiSemanticMemberLookupResult;
  lBound, lShadow: TBoundMemberResolution;
  lCandidates: TArray<TBoundMemberResolution>;
  lHelperCount, lHelperLevel: Integer;
  i: Integer;
  lRefusalCode: string;
  lRootProof: TRootAbsenceProof;
  lOpen, lValueCollision, lStrong: Boolean;
  lProfileMembers: TArray<string>;
  lProfileType: string;

  function CandidateOpen(const aMember: TBoundMemberResolution;
    const aKnownLevel: Integer): Boolean;
  var
    lOwner: TDelphiSemanticTypeIdentity;
    lLevel: Integer;
  begin
    lLevel := aKnownLevel;
    if lLevel < 0 then
      for var k := 0 to High(lHelpers.Levels) do
        if SameText(lHelpers.Levels[k].Identity.DeclaredId.Value,
          aMember.OwnerDeclaredId.Value) and (aMember.OwnerDeclaredId.Value <> '') then
        begin
          lLevel := k;
          Break;
        end;
    Result := (lLevel < 0) or (lHelpers.OpenFromLevel <= lLevel);
    for var k := 0 to lLevel do
      if not MembersClosed(lHelpers.Levels[k].Identity) then
        Result := True;
    // Helper declarations have their own completeness obligation too.
    if aKnownLevel >= 0 then
      for lOwner in lHelpers.Levels[aKnownLevel].Chain do
        if not MembersClosed(lOwner) then
          Result := True;
  end;

begin
  lBinding := Default(TDelphiSemanticWithBinding);
  lBinding.UnitName := aModel.UnitName;
  lBinding.FileName := aModel.FileName;
  lLineage := TryBuildMemberSafetyLineage(lBinding, aSelector.TypeName, aSelector.TypeIdentity);
  if SameText(lLineage.Cause, 'profile-terminal') then
  begin
    lProfileType := AliasTargetTypeName(lLineage.Items[High(lLineage.Items)], lStrong);
    TDelphiSemanticCompilerProfileBuilder.CompatibilityRecordMemberNames(lProfileType, lProfileMembers);
    // Inventory recovery may qualify a positively witnessed profile member.
    // Names outside that witness need helper absence; a profile is no such proof.
    if MatchText(aName, lProfileMembers) and (not fHasUnresolvedHelperTarget) and
      (not UnindexedRecordHelperMayApply(aSite, lLineage.Items)) then
    begin
      if aDirect.Outcome = noResolved then
        Exit(TMemberVerdict.Present(aDirect.Member, False));
      if aDirect.Outcome = noAbsent then
        Exit(TMemberVerdict.Barrier(noUnproved, 'OWNER_INHERITED_MEMBERS_UNVERIFIED',
          'The profile member retains compatibility inventory recovery.', 'profile-member-witness'));
      Exit(aDirect);
    end;
    Exit(TMemberVerdict.Barrier(noUnproved, 'ALIAS_RECEIVER_MEMBERS_UNVERIFIED',
      'The profile terminal does not prove helper or member absence.', 'profile-terminal'));
  end;
  lStatement := Default(TDelphiSemanticWithStatement);
  lStatement.Line := aSite.Line;
  lStatement.Column := aSite.Column;
  lCaller := Default(TDelphiSemanticTypeIdentity);
  OwnerIdentity(aModel.UnitName, aCurrentTypeName, '', '', lCaller);
  lNameSite := TDelphiSemanticNameSites.AtWithStatement(aModel, lStatement,
    RoutineScopeAtLine(aModel, aSite.Line), lCaller.DeclaredId);
  lNameSite.FileName := aSite.FileName;
  lHelpers := fTypeIndex.ResolveHelpersAt(lLineage, lNameSite);
  for i := 0 to High(lHelpers.Levels) do
    if MatchText(lHelpers.Levels[i].Cause, ['imports-directive-unproved',
      'declarations-directive-unproved', 'unit-directive-unproved']) then
      Exit(TMemberVerdict.Barrier(noUnproved,
        UpperCase(lHelpers.Levels[i].Cause).Replace('-', '_'),
        'An unsupported conditional leaves helper scope unproved.', lHelpers.Levels[i].Cause));
  lDirect := aDirect;
  lValue := TryResolveReceiverValueMember(aModel, aSite, aOriginalSelector, aName, '');
  lHelper := TMemberVerdict.NotPresent;
  lHelperLevel := -1;
  lValueCollision := False;
  lContext := Default(TDelphiSemanticMemberLookupContext);
  lContext.CallerUnitName := aModel.UnitName;
  lContext.CurrentTypeName := aCurrentTypeName;
  lContext.CurrentTypeId := lCaller.DeclaredId;
  lContext.InstanceContext := True;
  for i := 0 to High(lHelpers.Levels) do
  begin
    lHelperCount := 0;
    for lIdentity in lHelpers.Levels[i].Chain do
    begin
      lLookup := fSemanticMemberIndex.ResolveDirectMemberByOwnerId(lIdentity.DeclaredId, aName);
      if lLookup.Found or (Length(lLookup.Candidates) > 0) then
      begin
        Inc(lHelperCount);
        if lHelperLevel < 0 then
        begin
          lHelperLevel := i;
          if SelectorAllowsReceiverMemberLookup(aOriginalSelector) and fSemanticMemberIndexAvailable then
            lHelper := MemberVerdictFromLookup(aName,
              LookupIdentityMember(lContext, lIdentity, aName, False, False))
          else
            lHelper := TMemberVerdict.Barrier(noUnproved, 'OWNER_INHERITED_MEMBERS_UNVERIFIED',
              'Semantic helper lookup is not permitted for this receiver.', 'helper-permission');
        end;
      end;
      if fValueMembers.TryGetValue(lIdentity.DeclaredId.Value + #31 + aName, lCandidates) then
      begin
        Inc(lHelperCount);
        lValueCollision := True;
        if lHelperLevel < 0 then
        begin
          lHelperLevel := i;
          lHelper := TMemberVerdict.Barrier(noUnproved, 'TYPE_VALUE_MEMBERS_UNVERIFIED',
            'A helper value member is not verified.', 'value-member');
        end;
      end;
    end;
    if lHelperCount > 1 then
    begin
      lRefusalCode := 'HELPER_COLLISION_UNVERIFIED';
      if lValueCollision then
        lRefusalCode := 'TYPE_VALUE_MEMBERS_UNVERIFIED';
      Exit(TMemberVerdict.Barrier(noUnproved, lRefusalCode,
        'The child and parent helper both declare the member.', 'helper-collision'));
    end;
    // Helpers at higher receiver levels do not compete with a nearer helper.
    if lHelperLevel >= 0 then
      Break;
  end;
  if lDirect.Outcome in [noUnproved, noAmbiguous] then
    Exit(lDirect);
  if lValue.Outcome in [noUnproved, noAmbiguous] then
    Exit(lValue);
  if (lHelperLevel >= 0) and ((lDirect.Outcome = noResolved) or
    (lValue.Outcome = noResolved)) then
  begin
    lRefusalCode := 'HELPER_COLLISION_UNVERIFIED';
    if lValueCollision or (lValue.Outcome = noResolved) then
      lRefusalCode := 'TYPE_VALUE_MEMBERS_UNVERIFIED';
    Exit(TMemberVerdict.Barrier(noUnproved, lRefusalCode,
      'A helper member competes with a type member.', 'helper-collision'));
  end;
  if lDirect.Outcome in [noUnproved, noAmbiguous] then
    Exit(lDirect);
  if lValue.Outcome in [noUnproved, noAmbiguous] then
    Exit(lValue);
  if lHelper.Outcome in [noUnproved, noAmbiguous] then
    Exit(lHelper);
  if lHelper.Outcome = noResolved then
  begin
    // Helper ownership is provenance; receiver spelling normalization is for values.
    lBound := lHelper.Member;
    Exit(TMemberVerdict.Present(lBound, CandidateOpen(lBound, lHelperLevel)));
  end;
  if lDirect.Outcome = noResolved then
  begin
    lBound := lDirect.Member;
    if MatchText(lBound.Value.Kind, ['const', 'typed-const', 'variant-tag']) then
      lBound.Value.OwnerName := aOriginalSelector.TypeName;
    if TryResolveShadowingValueMember(aModel, aSite, aOriginalSelector, aName, lBound, lShadow) then
      Exit(MemberVerdictFromBound(lShadow));
    Exit(TMemberVerdict.Present(lBound, CandidateOpen(lBound, -1)));
  end;
  if lValue.Outcome = noResolved then
  begin
    lBound := lValue.Member;
    if CandidateOpen(lBound, -1) then
      Exit(TMemberVerdict.Barrier(noUnproved, 'TYPE_VALUE_MEMBERS_UNVERIFIED',
        'An unknown helper can reach the value member level.', 'helper-unknown'));
    Exit(lValue);
  end;
  lRefusalCode := '';
  if not ReceiverMemberAbsenceIsVerified(aModel, aSelector, aName, aSite,
    lRefusalCode, lRootProof) then
  begin
    if lRefusalCode = '' then
      lRefusalCode := 'OWNER_INHERITED_MEMBERS_UNVERIFIED';
    Exit(TMemberVerdict.Barrier(noUnproved, lRefusalCode,
      'The receiver member absence is not verified.', 'absence'));
  end;
  // A validated root proof closes only the external boundary of a verified
  // prefix. Each open project helper level remains an independent obligation.
  lOpen := ((not lLineage.Complete) and (lRootProof.Kind = rapNone)) or
    (Length(lHelpers.Levels) = 0);
  for i := 0 to High(lHelpers.Levels) do
    if lHelpers.OpenFromLevel <= i then
    begin
      // Project levels need their own helper proof. The named provider was
      // queried with this exact model's validated external imports, including
      // an empty set where all project imports were checked separately.
      if lHelpers.Levels[i].ProjectOwned then
        lOpen := True
      else
        case lRootProof.Kind of
          rapClosedSourceRoot: ;
          rapNamedSiteScopedRoot: ;
        else
          lOpen := True;
        end;
    end;
  if lOpen then
  begin
    lRefusalCode := 'OWNER_INHERITED_MEMBERS_UNVERIFIED';
    for lIdentity in lLineage.Items do
      if not SameText(lIdentity.Kind, 'type-alias') then
      begin
        if MatchText(lIdentity.UnderlyingName, ['record', 'packed record']) then
          lRefusalCode := 'RECORD_HELPER_MEMBERS_UNVERIFIED';
        Break;
      end;
    Exit(TMemberVerdict.Barrier(noUnproved, lRefusalCode,
      'Unknown helper scope prevents a verified absence.', 'helper-unknown'));
  end;
  Result := TMemberVerdict.NotPresent;
end;

function TWithBindingProjectMemberIndex.ResolveBodyMemberVerdict(
  const aModel: TDelphiSemanticUnitModel; const aSite: TReceiverLookupSite;
  const aLookupSelector, aOriginalSelector: TDelphiSemanticWithSelectorBinding;
  const aCurrentTypeName, aName: string): TMemberVerdict;
var
  lDirect: TMemberVerdict;
begin
  lDirect := TryResolveDirectMember(aModel.UnitName, aCurrentTypeName,
    aLookupSelector.TypeName, aName, SelectorAllowsReceiverMemberLookup(aOriginalSelector),
    aModel.FileName, aLookupSelector.TypeIdentity, False);
  Result := ResolveReceiverMemberVerdict(aModel, aSite, aLookupSelector, aOriginalSelector,
    aCurrentTypeName, aName, lDirect);
end;

function ResolveMemberAt(const aModel: TDelphiSemanticUnitModel;
  const aSite: TReceiverLookupSite;
  const aProjectModels: TArray<TDelphiSemanticUnitModel>;
  const aSelectors: TArray<TDelphiSemanticWithSelectorBinding>;
  const aCurrentTypeName, aMemberCachePrefix, aName: string;
  const aProjectMemberIndex: TWithBindingProjectMemberIndex;
  const aMemberCache: TDictionary<string, TMemberVerdict>): TMemberVerdict;
var
  i: Integer;
  lKey, lRefusalCode: string;
  lBound: TBoundMemberResolution;
  lLookupSelector: TDelphiSemanticWithSelectorBinding;
  lVerdict: TMemberVerdict;
begin
  lKey := ReceiverMemberCacheKey(aMemberCachePrefix, aName);
  if Assigned(aMemberCache) and aMemberCache.TryGetValue(lKey, lVerdict) then
    Exit(lVerdict);
  Result := TMemberVerdict.NotPresent;
  for i := High(aSelectors) downto 0 do
  begin
    if SameText(aSelectors[i].ReasonCode, 'ROUTINE_LOCAL_TYPE_UNSUPPORTED') then
      lVerdict := TMemberVerdict.Barrier(noUnproved, 'ROUTINE_LOCAL_TYPE_UNSUPPORTED',
        'The routine-local receiver type has no supported identity.', 'routine-local')
    else if not SameText(aSelectors[i].Status, 'resolved') then
      lVerdict := TMemberVerdict.Barrier(noUnproved, 'SELECTOR_MEMBERS_UNVERIFIED',
        'The receiver type is unresolved or ambiguous.', 'selector-status')
    else begin
      lLookupSelector := aSelectors[i];
      lRefusalCode := '';
      if Assigned(aProjectMemberIndex) then
        aProjectMemberIndex.TryResolveAliasTargetSelector(aModel, aSite, aSelectors[i],
          lLookupSelector, lRefusalCode);
      if SameText(aSelectors[i].ReasonCode, 'ALIAS_RECEIVER_MEMBERS_UNVERIFIED') then
        lRefusalCode := aSelectors[i].ReasonCode;
      if lRefusalCode <> '' then
        lVerdict := TMemberVerdict.Barrier(noUnproved, lRefusalCode,
          'The alias receiver member lineage or helper applicability is unverified.', 'alias')
      else if Assigned(aProjectMemberIndex) and
        SameText(aSelectors[i].TypeIdentity.ScopeKind, 'routine') then
      begin
        lVerdict := aProjectMemberIndex.TryResolveRoutineLocalMember(aSelectors[i].TypeIdentity,
          aCurrentTypeName, aName, aSite);
        if lVerdict.Outcome = noAbsent then
          Continue;
      end else begin
        if Assigned(aProjectMemberIndex) then
          lVerdict := aProjectMemberIndex.ResolveBodyMemberVerdict(aModel, aSite,
            lLookupSelector, aSelectors[i], aCurrentTypeName, aName)
        else
          lVerdict := TMemberVerdict.Barrier(noUnproved, 'OWNER_INHERITED_MEMBERS_UNVERIFIED',
            'The receiver may inherit a member that is not indexed.', 'absence');
      end;
    end;
    case lVerdict.Outcome of
      noAbsent: Continue;
      noResolved:
      begin
        lBound := lVerdict.Member;
        lBound.ReceiverIndex := i;
        Result := TMemberVerdict.Present(lBound, lVerdict.MemberTypeOpen);
      end;
      noUnproved, noAmbiguous: Result := lVerdict;
    end;
    Break;
  end;
  if Assigned(aMemberCache) then
    aMemberCache.AddOrSetValue(lKey, Result);
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

function HelperVisibilityCacheSuffix(const aModel: TDelphiSemanticUnitModel;
  const aStatement: TDelphiSemanticWithStatement): string;
var
  lHelper: TDelphiSemanticUnindexedHelperFact;
  lVisibleCount: Integer;
begin
  Result := '';
  if Length(aModel.UnindexedHelpers) = 0 then
    Exit;
  // Overloads share their lookup name. S4 visibility can still change between
  // their WITH sites; the monotonically growing visible fact set separates them.
  lVisibleCount := 0;
  for lHelper in aModel.UnindexedHelpers do
    if SameText(lHelper.SectionKind, 'interface') or (lHelper.FileName <> '') or
      (lHelper.Line <= 0) or (lHelper.Line < aStatement.Line) or
      ((lHelper.Line = aStatement.Line) and (lHelper.Column < aStatement.Column)) then
      Inc(lVisibleCount);
  Result := 'unindexed-helpers:' + IntToStr(lVisibleCount) + #31;
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

function ResolveNameCachePrefix(const aUnitName, aFileName: string; const aContext:
  TDelphiSemanticResolveContext): string;
var
  lBuilder: TStringBuilder;
  lParentRoutineName: string;
begin
  lBuilder := TStringBuilder.Create;
  try
    lBuilder.Append(aUnitName).Append(#31).Append(aFileName).Append(#31)
      .Append(aContext.RoutineName).Append(#31)
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
  const aSite: TReceiverLookupSite;
  const aProjectModels: TArray<TDelphiSemanticUnitModel>;
  const aRoutineName, aCurrentTypeName: string;
  const aParentRoutineNames: TArray<string>;
  const aSelectors: TArray<TDelphiSemanticWithSelectorBinding>;
  const aReferenceCachePrefix, aResolveCachePrefix, aMemberCachePrefix, aName: string;
  const aProjectMemberIndex: TWithBindingProjectMemberIndex;
  const aReferenceCache: TDictionary<string, TDelphiSemanticBoundReference>;
  const aResolveCache: TDictionary<string, TDelphiSemanticResolveResult>;
  const aMemberCache: TDictionary<string, TMemberVerdict>;
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
  lVerdict: TMemberVerdict;
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
    lVerdict := ResolveMemberAt(aModel, aSite, aProjectModels, aSelectors, aCurrentTypeName,
      aMemberCachePrefix, lCallName, aProjectMemberIndex, aMemberCache);
    lStopwatch.Stop;
    Inc(aReceiverMemberResolveMs, lStopwatch.ElapsedMilliseconds);
    case lVerdict.Outcome of
      noResolved:
      begin
        lResult := lVerdict.Member.Value;
        if SameText(lResult.Kind, 'method') then
          Exit(CacheBoundReference(aReferenceCache, lKey,
            MakeMemberBoundReference(lCallName, 'member', lVerdict)));
        Exit(CacheBoundReference(aReferenceCache, lKey,
          MakeBoundReference(lCallName, 'unsupported',
            MakeSyntheticResolveResult(lCallName, lResult.Kind, lResult.TypeName,
              lResult.OwnerName, 'CALL_SELECTOR_UNSUPPORTED'))));
      end;
      noUnproved, noAmbiguous:
      begin
        // A binder denial must survive the call adapter before persistence.
        if BinderDenialCode(lVerdict.ReasonCode) then
          Exit(CacheBoundReference(aReferenceCache, lKey,
            MakeMemberBoundReference(lCallName, 'unsupported', lVerdict)));
        Exit(CacheBoundReference(aReferenceCache, lKey,
          MakeBoundReference(lCallName, 'unsupported',
            MakeSyntheticResolveResult(lCallName, '', '', '', 'CALL_SELECTOR_UNSUPPORTED'))));
      end;
      noAbsent: ;
    end;

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
    // DS-741: lexical indexed/qualified fallback cannot discard an alias
    // receiver refusal. Resolve only the root here; leave syntax binding intact.
    lCallName := aName;
    if Pos('.', lCallName) > 0 then
      lCallName := Copy(lCallName, 1, Pos('.', lCallName) - 1);
    if Pos('[', lCallName) > 0 then
      lCallName := Copy(lCallName, 1, Pos('[', lCallName) - 1);
    lStopwatch := TStopwatch.StartNew;
    lVerdict := ResolveMemberAt(aModel, aSite, aProjectModels, aSelectors, aCurrentTypeName,
      aMemberCachePrefix, lCallName, aProjectMemberIndex, aMemberCache);
    lStopwatch.Stop;
    Inc(aReceiverMemberResolveMs, lStopwatch.ElapsedMilliseconds);
    case lVerdict.Outcome of
      noUnproved, noAmbiguous:
        if BinderDenialCode(lVerdict.ReasonCode) then
          Exit(CacheBoundReference(aReferenceCache, lKey,
            MakeMemberBoundReference(aName, 'unsupported', lVerdict)));
      noResolved, noAbsent: ;
    end;
    lStopwatch := TStopwatch.StartNew;
    lResult := ResolveNameCached(aModel, Default(TDelphiSemanticResolveContext),
      aName, aResolveCache, ResolveNameCachePrefix(aModel.UnitName, aModel.FileName,
      Default(TDelphiSemanticResolveContext)), aProjectMemberIndex);
    lStopwatch.Stop;
    Inc(aLexicalResolveMs, lStopwatch.ElapsedMilliseconds);
    Exit(CacheBoundReference(aReferenceCache, lKey, MakeBoundReference(aName, 'unsupported',
      lResult)));
  end;

  lStopwatch := TStopwatch.StartNew;
  lVerdict := ResolveMemberAt(aModel, aSite, aProjectModels, aSelectors, aCurrentTypeName,
    aMemberCachePrefix, aName, aProjectMemberIndex, aMemberCache);
  lStopwatch.Stop;
  Inc(aReceiverMemberResolveMs, lStopwatch.ElapsedMilliseconds);
  case lVerdict.Outcome of
    noResolved:
      Exit(CacheBoundReference(aReferenceCache, lKey,
        MakeMemberBoundReference(aName, 'member', lVerdict)));
    noAmbiguous:
      Exit(CacheBoundReference(aReferenceCache, lKey,
        MakeMemberBoundReference(aName, 'ambiguous', lVerdict)));
    noUnproved:
      Exit(CacheBoundReference(aReferenceCache, lKey,
        MakeMemberBoundReference(aName, 'unsupported', lVerdict)));
    noAbsent: ;
  end;

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
  const aSource: TWithBindingSourceContext; const aStatement: TDelphiSemanticWithStatement;
  var aBinding: TDelphiSemanticWithBinding);
var
  lActiveCount: Integer;
  lInactiveCount: Integer;
  lOffset: Integer;
  lReference: TDelphiSemanticBoundReference;
  lScanText: string;
  lVerification: TDelphiSemanticWithBinding;
begin
  lScanText := aSource.ReferenceScanText;
  lVerification := aBinding;
  FinalizeBinding(lVerification, aStatement);
  SetLength(aBinding.InactiveSpanReferences, Length(aBinding.References));
  lActiveCount := 0;
  lInactiveCount := 0;
  for lReference in aBinding.References do
  begin
    lOffset := ActivityOffset(aSource.LineStarts, Length(aModel.SourceText),
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
    (aBinding.InactiveSpanSkipReason <> 'INACTIVE_NESTED_WITH_SHADOW') and
    ((Result.SkipReason = '') or
    MatchText(Result.SkipReason, ['ACTIVITY_UNVERIFIED', 'UNRESOLVED_REFERENCE',
      'UNSUPPORTED_REFERENCE', 'SCOPED_DECLARATION', 'EXTERNAL_REFERENCE'])) then
    Result.SkipReason := aBinding.InactiveSpanSkipReason;
end;

function CaptureStatementIsInUnit(const aModel: TDelphiSemanticUnitModel;
  const aSource: TWithBindingSourceContext;
  const aStatement: TDelphiSemanticWithStatement): Boolean;
var
  lMatch: TMatch;
  lOffset: Integer;
  lSource: string;
begin
  Result := False;
  if (aModel.SourceText = '') or (aStatement.Line <= 0) or (aStatement.Column <= 0) then
    Exit;
  lOffset := ActivityOffset(aSource.LineStarts, Length(aModel.SourceText),
    aStatement.Line, aStatement.Column);
  if lOffset <= 0 then
    Exit;
  // An expanded include position is not a position in the physical unit.
  // Check the physical header before choosing either capture lookup site.
  lSource := aSource.SanitizedSourceText;
  lMatch := TRegEx.Match(Copy(lSource, lOffset, MaxInt),
    '^with\b\s+(.*?)\s+(?<!&)\bdo\b', [roIgnoreCase, roSingleLine]);
  Result := lMatch.Success and SameText(
    TRegEx.Replace(lMatch.Groups[1].Value, '\s+', ''),
    TRegEx.Replace(SanitizeCodeText(aStatement.SelectorText), '\s+', ''));
  // A conditional header can retain two physical tokens for one selector.
  // Exact full-statement agreement proves this physical site without treating
  // expanded include coordinates or an empty source as a unit position.
  if not Result and (aStatement.Text <> '') and
    (Length(aStatement.Text) <= Length(aModel.SourceText) - lOffset + 1) and
    (Copy(aModel.SourceText, lOffset, Length(aStatement.Text)) = aStatement.Text) then
    Result := TRegEx.IsMatch(Copy(lSource, lOffset, MaxInt), '^with\b', [roIgnoreCase]);
end;

function CaptureHasFailedDecidingModel(const aModel: TDelphiSemanticUnitModel;
  const aProjectModels: TArray<TDelphiSemanticUnitModel>;
  const aLookup: TDelphiSemanticTypeResolution): Boolean;
var
  lCount: Integer;
  lFailed: Boolean;
begin
  Result := False;
  if aLookup.Outcome <> noUnproved then
    Exit;
  // Step 3 preserves the old unsuccessful capture status. It does not claim
  // absence or publish a type from a model excluded from the identity graph.
  if not aModel.Success and (aLookup.Cause = 'caller-scope-invalid') then
    Exit(True);
  // witness-unknown at the end of the walk means there was no earlier indexed
  // candidate. A later-unknown-unit shadow of a real candidate stays unproved.
  if aLookup.Cause <> 'witness-unknown' then
    Exit;
  lCount := 0;
  lFailed := False;
  for var lModel in aProjectModels do
    if SameText(aLookup.DecidingScope, 'uses:' + lModel.UnitName) then
    begin
      Inc(lCount);
      lFailed := not lModel.Success;
    end;
  Result := (lCount = 1) and lFailed;
end;

function BindSelectors(const aModel: TDelphiSemanticUnitModel;
  const aSource: TWithBindingSourceContext;
  const aProjectModels: TArray<TDelphiSemanticUnitModel>; const aRoutineName,
  aCurrentTypeName, aSelectorText: string; const aParentRoutineNames: TArray<string>;
  const aParentSelectors: TArray<TDelphiSemanticWithSelectorBinding>;
  const aLine, aColumn: Integer;
  const aStatement: TDelphiSemanticWithStatement;
  const aProjectMemberIndex: TWithBindingProjectMemberIndex;
  const aMemberCache: TDictionary<string, TMemberVerdict>;
  out aIdentities: TWithSelectorIdentityArray):
  TArray<TDelphiSemanticWithSelectorBinding>;
var
  lCaptureLookup: TDelphiSemanticTypeResolution;
  lCaptureSite: TDelphiSemanticNameSite;
  lClass: TDelphiSemanticTypeIdentity;
  lInsertionLine: Integer;
  lHasVarSection: Boolean;
  lPhysicalStatement, lHasInsertionSite: Boolean;
  lIdentity, lPrefixIdentity: TDelphiSemanticTypeIdentity;
  lBinding, lPrefixBinding: TDelphiSemanticWithSelectorBinding;
  lActivityBinding: TDelphiSemanticWithBinding;
  lLineage: TDelphiSemanticLineage;
  i, lParenDepth, lBracketDepth: Integer;
  lIdentities: TList<TDelphiSemanticTypeIdentity>;
  lPart, lScopeId: string;
  lSelectors: TList<TDelphiSemanticWithSelectorBinding>;
  lParts: TArray<string>;
begin
  aIdentities := nil;
  lPhysicalStatement := CaptureStatementIsInUnit(aModel, aSource, aStatement);
  lInsertionLine := 0;
  lHasInsertionSite := lPhysicalStatement and
    TryFindTempInsertionLine(aSource.Lines, aLine,
      aRoutineName, lInsertionLine, lHasVarSection);
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
        lLineage := aProjectMemberIndex.TryBuildMemberSafetyLineage(lActivityBinding,
          lPrefixBinding.TypeName, lPrefixIdentity);
        if aProjectMemberIndex.LineageHasActivityFact(lLineage.Items) then
        begin
          lBinding.Status := 'unsupported';
          lBinding.ReasonCode := 'SELECTOR_MEMBERS_ACTIVITY_UNVERIFIED';
          lIdentity := Default(TDelphiSemanticTypeIdentity);
          lBinding.TypeIdentity := lIdentity;
          Break;
        end;
      end;
      if Assigned(aProjectMemberIndex) and (lBinding.CaptureTypeName = '') and
        TRegEx.IsMatch(lBinding.TypeName, '^[A-Za-z_][A-Za-z0-9_]*$') then
      begin
        lBinding.CaptureTypeName := lBinding.TypeName;
        lBinding.CaptureTypeStatus := 'unproved';
        lBinding.CaptureTypeIdentity := Default(TDelphiSemanticTypeIdentity);
        if lPhysicalStatement then
        begin
          lScopeId := RoutineScopeAtLine(aModel, aLine);
          aProjectMemberIndex.OwnerIdentity(aModel.UnitName, aCurrentTypeName, '', '', lClass);
          if lHasInsertionSite then
          begin
            lCaptureSite := TDelphiSemanticNameSites.AtTempInsertion(aModel, lScopeId,
              lClass.DeclaredId, lInsertionLine);
            lBinding.CaptureInsertionLine := lInsertionLine;
          end else
            lCaptureSite := TDelphiSemanticNameSites.AtWithStatement(aModel, aStatement,
              lScopeId, lClass.DeclaredId);
          lCaptureSite.CaptureVisibility := True;
          lCaptureLookup := aProjectMemberIndex.fTypeIndex.ResolveTypeAt(lCaptureSite,
            lBinding.TypeName);
          // Publish each intact outcome explicitly; uncertainty is never absence.
          case lCaptureLookup.Outcome of
            noResolved:
              begin
                lBinding.CaptureTypeStatus := 'resolved';
                lBinding.CaptureTypeIdentity := lCaptureLookup.Identity;
              end;
            noUnproved:
              begin
                if CaptureHasFailedDecidingModel(aModel, aProjectModels, lCaptureLookup) then
                  lBinding.CaptureTypeStatus := 'unresolved'
                else
                  lBinding.CaptureTypeStatus := 'unproved';
              end;
            noAmbiguous: lBinding.CaptureTypeStatus := 'ambiguous';
            noAbsent: lBinding.CaptureTypeStatus := 'unresolved';
          end;
        end else
          lBinding.Cause := 'position-unknown';
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
  const aMemberCache: TDictionary<string, TMemberVerdict>;
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
    lReference := BindReference(aModel, ReceiverLookupSite(aModel, aStatement.Line,
      aStatement.Column), aProjectModels, aRoutineName, aCurrentTypeName,
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
  const aMemberCache: TDictionary<string, TMemberVerdict>;
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
      lReference := BindReference(aModel, ReceiverLookupSite(aModel, aStatement.Line,
        aStatement.Column), aProjectModels, aRoutineName, aCurrentTypeName,
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
  const aMemberCache: TDictionary<string, TMemberVerdict>;
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
    // Distinct site models can share unit/routine/receiver names while their
    // uses lists differ. All three lookup caches retain the source model identity.
    lReferenceCachePrefix := BoundReferenceCachePrefix(aModel.UnitName, aRoutineName,
      aCurrentTypeName,
      aParentRoutineNames, aSelectors) + aModel.FileName + #31 +
      HelperVisibilityCacheSuffix(aModel, aStatement);
    lMemberCachePrefix := ReceiverMemberCachePrefix(aModel.UnitName, aModel.FileName, aCurrentTypeName,
      aRoutineName, aStatement.Line, aStatement.Column, aSelectors);
    lResolveContext := Default(TDelphiSemanticResolveContext);
    lResolveContext.RoutineName := aRoutineName;
    lResolveContext.CurrentTypeName := aCurrentTypeName;
    lResolveContext.ParentRoutineNames := aParentRoutineNames;
    lResolveContext.SectionKind := 'implementation';
    lResolveContext.ConformanceLevel := 3;
    lResolveContext.IndexedUnitModels := aProjectModels;
    lResolveCachePrefix := ResolveNameCachePrefix(aModel.UnitName, aModel.FileName, lResolveContext);
    lBodyText := ExtractWithBodyText(aStatement, aAllStatements, aStatementIndex);
    lBodyLineStarts := BuildBodyLineStarts(lBodyText);
    lTokenIndex := 1;
    while ReadReferenceToken(lBodyText, lTokenIndex, True, lToken, lTokenStart) do
    begin
      if ((not IsBinderKeyword(lToken)) or
        ReferenceTokenIsEscaped(lBodyText, lTokenStart)) and
        (not IsSelectorName(aSelectors, lToken)) then
      begin
        lReference := BindReference(aModel, ReceiverLookupSite(aModel, aStatement.Line,
          aStatement.Column), aProjectModels, aRoutineName, aCurrentTypeName,
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
  const aSource: TWithBindingSourceContext;
  const aProjectModels: TArray<TDelphiSemanticUnitModel>;
  const aStatements: TArray<TDelphiSemanticWithStatement>;
  const aScopeIndex: TDelphiSemanticRoutineScopeIndex;
  const aProjectMemberIndex: TWithBindingProjectMemberIndex;
  const aMemberCache: TDictionary<string, TMemberVerdict>;
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
    lDirectSelectors := BindSelectors(aModel, aSource, aProjectModels, lRoutineLookupName,
      lCurrentTypeName, aStatements[i].SelectorText, lParentRoutineNames,
      lParentSelectors, aStatements[i].Line, aStatements[i].Column, aStatements[i],
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


function InactiveSubjectMayShadow(const aModel: TDelphiSemanticUnitModel;
  const aSource: TWithBindingSourceContext;
  const aProjectModels: TArray<TDelphiSemanticUnitModel>;
  const aStatement: TDelphiSemanticWithStatement;
  const aBinding: TDelphiSemanticWithBinding;
  const aRoutineName, aCurrentTypeName: string;
  const aParentRoutineNames: TArray<string>;
  const aProjectMemberIndex: TWithBindingProjectMemberIndex;
  const aMemberCache: TDictionary<string, TMemberVerdict>): Boolean;
var
  lMatch: TMatch;
  lHeader, lPart: string;
  lParts: TArray<string>;
  lSelectors: TArray<TDelphiSemanticWithSelectorBinding>;
  lIdentities: TWithSelectorIdentityArray;
  lReference: TDelphiSemanticBoundReference;
  lBound: TBoundMemberResolution;
  lOwnerModel: TDelphiSemanticUnitModel;
  lDeclaration: TDelphiSemanticDeclaration;
  lOwnerSource: TWithBindingSourceContext;
  lOwnerScan: string;
  lOffset, lPartOffset, lStart, lFinish, i, j: Integer;
  lInactive, lActive: Boolean;
  lVerification: TDelphiSemanticWithBinding;
begin
  Result := False;
  if aBinding.ActivityUnverified then
    Exit;
  lMatch := TRegEx.Match(SanitizeCodeText(aStatement.Text),
    '(?<!&)\bwith\b\s+(.*?)\s+(?<!&)\bdo\b', [roIgnoreCase, roSingleLine]);
  if not lMatch.Success then
    Exit;
  lHeader := lMatch.Groups[1].Value;
  lOffset := ActivityOffset(aSource.LineStarts, Length(aModel.SourceText),
    aStatement.Line, aStatement.Column) + lMatch.Groups[1].Index - 1;
  if (lOffset <= 0) or (lOffset + Length(lHeader) - 1 > Length(aSource.ReferenceScanText)) then
    Exit(True);
  lInactive := False;
  for i := 1 to Length(lHeader) do
    if not CharInSet(lHeader[i], [#9, #10, #13, ' ']) and
      (aSource.ReferenceScanText[lOffset + i - 1] = ' ') then
    begin
      lInactive := True;
      Break;
    end;
  if not lInactive then
    Exit;
  if not TrySplitTopLevelCommaList(lHeader, lParts) then
    Exit(True);
  lVerification := WithBindingForPlanning(aBinding);
  // Bind the physical subject list with the same lexical/member resolver. These
  // speculative selectors never become rewrite selectors or persisted edits.
  lSelectors := nil;
  lPartOffset := 1;
  for i := 0 to High(lParts) do
  begin
    lPart := lParts[i];
    j := Pos(lPart, lHeader, lPartOffset);
    if j = 0 then
      Exit(True);
    lPartOffset := j + Length(lPart);
    lInactive := False;
    lActive := False;
    for lStart := j to lPartOffset - 1 do
      if not CharInSet(lHeader[lStart], [#9, #10, #13, ' ']) then
      begin
        if aSource.ReferenceScanText[lOffset + lStart - 1] = ' ' then
          lInactive := True
        else
          lActive := True;
      end;
    if not lInactive then
      Continue;
    // Optional earlier subjects can change later selector lookup. Nested lists
    // need their enclosing selector environment before absence is authoritative.
    if (i <> High(lParts)) or (aStatement.NestingDepth > 0) then
      Exit(True);
    // A partially conditional expression is not an independently absent subject.
    if lActive then
      Exit(True);
    if Length(lSelectors) = 0 then
      lSelectors := BindSelectors(aModel, aSource, aProjectModels, aRoutineName,
        aCurrentTypeName, lHeader, aParentRoutineNames, nil,
        aStatement.Line, aStatement.Column, aStatement, aProjectMemberIndex,
        aMemberCache, lIdentities);
    if Length(lSelectors) <> Length(lParts) then
      Exit(True);
    // Only a closed source-backed record can currently establish absence across
    // the alternative subject list. Conditional record members cannot prove it.
    if not SameText(lSelectors[i].TypeIdentity.Kind, 'type') or
      not SameText(lSelectors[i].TypeIdentity.CanonicalName, 'record') or
      not aProjectMemberIndex.TrySafetyDeclarationModel(lSelectors[i].TypeIdentity, lOwnerModel) then
      Exit(True);
    if not SameText(lSelectors[i].TypeIdentity.SourceRange.FileName, lOwnerModel.FileName) then
      Exit(True);
    lOwnerSource := PrepareWithBindingSource(lOwnerModel);
    lStart := ActivityOffset(lOwnerSource.LineStarts, Length(lOwnerModel.SourceText),
      lSelectors[i].TypeIdentity.SourceRange.Line, lSelectors[i].TypeIdentity.SourceRange.Column);
    // Type identity ranges identify the name. The AST body endpoint covers
    // conditional fields hidden from the selected member inventory.
    lFinish := 0;
    for lDeclaration in lOwnerModel.Declarations do
      if (lDeclaration.Line = lSelectors[i].TypeIdentity.SourceRange.Line) and
        (lDeclaration.Column = lSelectors[i].TypeIdentity.SourceRange.Column) and
        SameText(lDeclaration.Name, lSelectors[i].TypeIdentity.Name) then
      begin
        lFinish := ActivityOffset(lOwnerSource.LineStarts, Length(lOwnerModel.SourceText),
          lDeclaration.TypeBodyEndLine, lDeclaration.TypeBodyEndColumn);
        Break;
      end;
    if (lStart <= 0) or (lFinish < lStart) or (lFinish > Length(lOwnerModel.SourceText)) then
      Exit(True);
    lOwnerScan := SanitizeCodeText(lOwnerSource.ReferenceScanText);
    for j := lStart to lFinish do
      if not CharInSet(lOwnerSource.SanitizedSourceText[j], [#9, #10, #13, ' ']) and
        (lOwnerScan[j] = ' ') then
        Exit(True);
    for lReference in lVerification.References do
      if SameText(lReference.Classification, 'member') and
        aProjectMemberIndex.TryResolveVerifiedSimpleMember(aModel,
          ReceiverLookupSite(aModel, aStatement.Line, aStatement.Column),
          [lSelectors[i]], aCurrentTypeName, 'inactive-subject:' + aBinding.SemanticId,
          lReference.Name, aMemberCache, lBound) then
        Exit(True);
  end;
end;

function ContainsInactiveAsm(const aModel: TDelphiSemanticUnitModel;
  const aStatement: TDelphiSemanticWithStatement;
  const aSource: TWithBindingSourceContext): Boolean;
var
  lMatch: TMatch;
  lStart, lOffset: Integer;
begin
  Result := False;
  lStart := ActivityOffset(aSource.LineStarts, Length(aModel.SourceText),
    aStatement.BodyLine, aStatement.BodyColumn);
  if lStart <= 0 then
    Exit;
  lMatch := TRegEx.Match(SanitizeCodeText(aStatement.BodyText), '(?<!&)\basm\b', [roIgnoreCase]);
  while lMatch.Success do
  begin
    lOffset := lStart + lMatch.Index - 1;
    if (lOffset > 0) and (lOffset <= Length(aSource.ReferenceScanText)) and
      (aSource.ReferenceScanText[lOffset] = ' ') and
      not TDelphiSemanticSourceConditionals.UnknownAtOffset(aModel.SourceText,
        aModel.VerifiedActiveSourceText, lOffset) then
      Exit(True);
    lMatch := lMatch.NextMatch;
  end;
end;

function InactiveWithIdentifierChar(const aChar: Char): Boolean;
begin
  Result := (aChar = '_') or aChar.IsLetterOrDigit;
end;

function ContainsInactiveNestedWith(const aModel: TDelphiSemanticUnitModel;
  const aStatement: TDelphiSemanticWithStatement;
  const aSource: TWithBindingSourceContext): Boolean;
var
  i: Integer;
  lBodyOffset: Integer;
  lEvidence: string;
  lScanText: string;
  lStart: Integer;
  lText: string;
  lDirectiveStart: Integer;
  lDirectiveName: string;

  function KnownInactiveAt(const aOffset: Integer): Boolean;
  var
    lOffset: Integer;
  begin
    lOffset := lBodyOffset + aOffset - 1;
    Result := (lOffset > 0) and (lOffset <= Length(lScanText)) and
      (lScanText[lOffset] = ' ') and
      not TDelphiSemanticSourceConditionals.UnknownAtOffset(aModel.SourceText,
        lEvidence, lOffset);
  end;
begin
  Result := False;
  lEvidence := aModel.ReferenceScanSourceText;
  if lEvidence = '' then
    lEvidence := aModel.VerifiedActiveSourceText;
  lScanText := aSource.ReferenceScanText;
  lBodyOffset := ActivityOffset(aSource.LineStarts, Length(aModel.SourceText),
    aStatement.BodyLine, aStatement.BodyColumn);
  if lBodyOffset <= 0 then
    Exit;
  // DS-724 v4: only lexical token presence and stored activity matter.
  // We never infer another build's subjects, types or governed statement extent.
  lText := aStatement.BodyText;
  i := 1;
  while i <= Length(lText) do
  begin
    if lText[i] = '''' then
    begin
      Inc(i);
      while i <= Length(lText) do
      begin
        if lText[i] = '''' then
        begin
          Inc(i);
          if (i > Length(lText)) or (lText[i] <> '''') then
            Break;
        end;
        Inc(i);
      end;
      Continue;
    end;
    if (lText[i] = '/') and (i < Length(lText)) and (lText[i + 1] = '/') then
    begin
      while (i <= Length(lText)) and not CharInSet(lText[i], [#10, #13]) do
        Inc(i);
      Continue;
    end;
    // Real include directives can hide a WITH header in another build.
    // We use stored activity only; comments/strings never reach this check.
    lDirectiveStart := 0;
    if (lText[i] = '{') and (i < Length(lText)) and (lText[i + 1] = '$') then
      lDirectiveStart := i + 2
    else if (lText[i] = '(') and (i + 2 <= Length(lText)) and
      (lText[i + 1] = '*') and (lText[i + 2] = '$') then
      lDirectiveStart := i + 3;
    if lDirectiveStart > 0 then
    begin
      lStart := lDirectiveStart;
      while (lDirectiveStart <= Length(lText)) and
        InactiveWithIdentifierChar(lText[lDirectiveStart]) do
        Inc(lDirectiveStart);
      lDirectiveName := Copy(lText, lStart, lDirectiveStart - lStart);
      // {$I+}/{$I-} are compiler switches, not includes.
      if MatchText(lDirectiveName, ['I', 'INCLUDE']) and
        (lDirectiveStart <= Length(lText)) and
        CharInSet(lText[lDirectiveStart], [#9, #10, #13, ' ']) and
        KnownInactiveAt(lStart) then
        Exit(True);
    end;
    if lText[i] = '{' then
    begin
      while (i <= Length(lText)) and (lText[i] <> '}') do
        Inc(i);
      Inc(i);
      Continue;
    end;
    if (lText[i] = '(') and (i < Length(lText)) and (lText[i + 1] = '*') then
    begin
      Inc(i, 2);
      while i < Length(lText) do
      begin
        if (lText[i] = '*') and (lText[i + 1] = ')') then
          Break;
        Inc(i);
      end;
      Inc(i, 2);
      Continue;
    end;
    lStart := i;
    // Include the escape in the token: &with is an identifier, never WITH.
    if (lText[i] = '&') and (i < Length(lText)) and
      InactiveWithIdentifierChar(lText[i + 1]) then
      Inc(i);
    if InactiveWithIdentifierChar(lText[i]) then
    begin
      while (i <= Length(lText)) and InactiveWithIdentifierChar(lText[i]) do
        Inc(i);
      if SameText(Copy(lText, lStart, i - lStart), 'with') then
      begin
        if KnownInactiveAt(lStart) then
          Exit(True);
      end;
    end else
      Inc(i);
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
  fUnindexedHelperModelIndexes := nil;
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
    for lDiagnostic in lModel.Diagnostics do
      if SameText(lDiagnostic.Code, 'AST_HELPER_DECLARATION_UNINDEXED') then
      begin
        lIndex := Length(fUnindexedHelperModelIndexes);
        SetLength(fUnindexedHelperModelIndexes, lIndex + 1);
        fUnindexedHelperModelIndexes[lIndex] := i;
        Break;
      end;
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
  lLineage: TDelphiSemanticLineage;
begin
  for i := 0 to High(aBinding.Selectors) do
  begin
    if SameText(aBinding.Selectors[i].ReasonCode,
      'SELECTOR_MEMBERS_ACTIVITY_UNVERIFIED') then
      Exit(True);
    if i >= Length(aSelectorIdentities) then
      Continue;
    // A failed walk still supplies the verified prefix, which can carry a fact.
    lLineage := TryBuildMemberSafetyLineage(aBinding, aBinding.Selectors[i].TypeName,
      aSelectorIdentities[i]);
    if LineageHasActivityFact(lLineage.Items) then
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

function AnonymousRecordDeclarationIsVerified(const aModel: TDelphiSemanticUnitModel;
  const aIdentity: TDelphiSemanticTypeIdentity): Boolean;
var
  g: TGarbos;
  lDeclaration: TDelphiSemanticDeclaration;
  lDiagnostic: TDelphiSemanticModelDiagnostic;
  lLexer: TmwBasePasLex;
  lMatched: Integer;
  lName: string;
  lOffset: Integer;
begin
  Result := False;
  if (not aModel.Success) or (not SameText(aModel.ScopeModelStatus, 'ast')) or
    (not SameText(aIdentity.Kind, 'type')) or
    (not SameText(aIdentity.UnderlyingName, 'record')) then
    Exit;
  lMatched := 0;
  for lDeclaration in aModel.Declarations do
    if SameText(lDeclaration.SymbolId, aIdentity.SemanticSymbolId) and
      (lDeclaration.Line = aIdentity.SourceRange.Line) and
      (lDeclaration.Column = aIdentity.SourceRange.Column) and
      (lDeclaration.TypeBodyEndLine > 0) then
    begin
      // The declaration token is the variable/field name, followed by ':' and
      // an inline record. A named record or alias has '=' and cannot qualify.
      GC(lLexer, TmwBasePasLex.Create, g);
      lLexer.UseDefines := False;
      // Synthetic names do not occur verbatim in source; their extraction offset
      // can still be relative to expanded text. Use the verified physical token.
      lOffset := ActivityOffset(BuildBodyLineStarts(aModel.SourceText),
        Length(aModel.SourceText), lDeclaration.Line, lDeclaration.Column);
      if lOffset = 0 then
        Exit;
      lName := lDeclaration.Name;
      if LastDelimiter('.', lName) > 0 then
        lName := Copy(lName, LastDelimiter('.', lName) + 1, MaxInt);
      lLexer.Origin := Copy(aModel.SourceText, lOffset, MaxInt);
      if not SameText(lLexer.Token, lName) then
        Exit;
      lLexer.NextNoJunk;
      if lLexer.Token <> ':' then
        Exit;
      lLexer.NextNoJunk;
      if SameText(lLexer.Token, 'packed') then
        lLexer.NextNoJunk;
      if not SameText(lLexer.Token, 'record') then
        Exit;
      for lDiagnostic in aModel.Diagnostics do
        if (lDiagnostic.Line >= lDeclaration.Line) and
          (lDiagnostic.Line <= lDeclaration.TypeBodyEndLine) and
          MatchText(lDiagnostic.Code, ['ANONYMOUS_RECORD_MEMBERS_UNVERIFIED',
            'MEMBERS_INCOMPLETE', 'MEMBERS_UNVERIFIED',
            'MEMBERS_ACTIVITY_UNVERIFIED', 'UNVERIFIED_PREPROCESS_CONDITION',
            'UNSUPPORTED_PREPROCESS_DIRECTIVE', 'UNMATCHED_PREPROCESS_DIRECTIVE',
            'UNTERMINATED_PREPROCESS_CONDITIONAL']) then
          Exit;
      Inc(lMatched);
    end;
  Result := lMatched = 1;
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
function TWithBindingProjectMemberIndex.SelectorTypeLookup(
  const aOriginModel: TDelphiSemanticUnitModel;
  const aOriginSectionKind, aOriginScopeId, aTypeName: string):
  TDelphiSemanticTypeLookupResult;
var
  lVisibleUnits: TArray<string>;
begin
  Result := Default(TDelphiSemanticTypeLookupResult);
  if (aOriginModel.UnitName = '') or (aTypeName = '') or
    not MatchText(aOriginSectionKind, ['interface', 'implementation']) then
    Exit;
  lVisibleUnits := fTypeIndex.VisibleUnitNames(aOriginModel.UnitName, aOriginSectionKind);
  if aOriginScopeId <> '' then
    Result := fTypeIndex.ResolveScopedName(aTypeName, aOriginModel.UnitName,
      aOriginScopeId, lVisibleUnits, aOriginSectionKind)
  else if Pos('.', aTypeName) > 0 then
    Result := fTypeIndex.ResolveQualifiedName(aTypeName)
  else
    Result := fTypeIndex.ResolveVisibleName(aTypeName, aOriginModel.UnitName,
      lVisibleUnits, aOriginSectionKind);
end;

function TWithBindingProjectMemberIndex.TryClassScopedReceiverType(
  const aModel: TDelphiSemanticUnitModel; const aResolved: TDelphiSemanticResolveResult;
  const aCurrentTypeName: string; out aResolution: TDelphiSemanticTypeResolution): Boolean;
var
  lClass: TDelphiSemanticTypeIdentity;
  lSite: TDelphiSemanticNameSite;
  lSpelling: string;
  lMatches: Integer;
begin
  Result := False;
  aResolution := Default(TDelphiSemanticTypeResolution);
  if (aCurrentTypeName = '') or not MatchText(aResolved.Kind, ['local', 'parameter']) or
    not TRegEx.IsMatch(aResolved.TypeName, '^[A-Za-z_][A-Za-z0-9_]*$') then
    Exit;
  Result := True;
  lMatches := 0;
  OwnerIdentity(aModel.UnitName, aCurrentTypeName, '', '', lClass);
  if SameText(aResolved.Kind, 'local') then
    for var lLocal in aModel.Locals do
      if SameText(lLocal.Name, aResolved.Name) and (lLocal.Line = aResolved.Line) and
        (lLocal.Column = aResolved.Column) then
      begin
        Inc(lMatches);
        lSite := TDelphiSemanticNameSites.AtLocal(aModel, lLocal, lClass.DeclaredId);
        lSpelling := lLocal.TypeName;
      end;
  if SameText(aResolved.Kind, 'parameter') then
    for var lRoutine in aModel.Routines do
      for var lParameter in lRoutine.Parameters do
        if SameText(lParameter.Name, aResolved.Name) and (lParameter.Line = aResolved.Line) and
          (lParameter.Column = aResolved.Column) then
        begin
          Inc(lMatches);
          lSite := TDelphiSemanticNameSites.AtParameter(aModel, lRoutine, lParameter, lClass.DeclaredId);
          lSpelling := lParameter.TypeName;
        end;
  if (lMatches <> 1) or (lClass.DeclaredId.Value = '') or
    not TRegEx.IsMatch(lSpelling, '^[A-Za-z_][A-Za-z0-9_]*$') then
  begin
    aResolution.Outcome := noUnproved;
    aResolution.ReasonCode := 'TYPE_VISIBILITY_UNPROVED';
    Exit;
  end;
  // A method's class and its ancestors precede unit scope. Resolve at the
  // variable/parameter token so later local declarations cannot change it.
  // An unindexed external target retains no identity. Its member lookup will
  // keep the existing owner barrier; never retry the spelling in unit scope.
  aResolution := fTypeIndex.ResolveTypeAt(lSite, lSpelling);
end;

function TWithBindingProjectMemberIndex.TryResolveSelectorIdentity(
  const aOriginModel: TDelphiSemanticUnitModel;
  const aOriginSectionKind, aOriginScopeId, aTypeName: string;
  out aIdentity: TDelphiSemanticTypeIdentity): Boolean;
var
  lLookup: TDelphiSemanticTypeLookupResult;
  lModel: TDelphiSemanticUnitModel;
begin
  aIdentity := Default(TDelphiSemanticTypeIdentity);
  lLookup := SelectorTypeLookup(aOriginModel, aOriginSectionKind, aOriginScopeId, aTypeName);
  Result := lLookup.Found and not lLookup.Ambiguous and
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
      aScopeId, fTypeIndex.VisibleUnitNames(aDeclaringModel.UnitName, 'implementation'), 'implementation');
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

function TWithBindingProjectMemberIndex.UnindexedAliasMayApply(const aTypeName: string): Boolean;

  function ScanProjectAliases: Boolean;
  var
    lLexer: TmwBasePasLex;
    lModel: TDelphiSemanticUnitModel;
    lName, lUnitName: string;
    lDot: Integer;

    procedure NextCodeToken;
    begin
      repeat
        lLexer.Next;
      until not IsTokenIDJunk(lLexer.TokenID);
    end;

  begin
    Result := False;
    lName := aTypeName.Replace('&', '');
    lUnitName := '';
    lDot := LastDelimiter('.', lName);
    if lDot > 0 then
    begin
      lUnitName := Copy(lName, 1, lDot - 1);
      lName := Copy(lName, lDot + 1, MaxInt);
    end;
    if lName = '' then
      Exit;
    for lModel in fModels do
    begin
      if (lUnitName <> '') and (not SameText(lUnitName, lModel.UnitName)) then
        Continue;
      // SetOrigin allocates a fresh buffer; each model owns a fresh lexer.
      lLexer := TmwBasePasLex.Create;
      try
        lLexer.UseDefines := False;
        lLexer.Origin := lModel.SourceText;
        while lLexer.TokenID <> ptNull do
        begin
          if (lLexer.TokenID = ptIdentifier) and
            SameText(lLexer.Token.Replace('&', ''), lName) then
          begin
            NextCodeToken;
            if lLexer.TokenID = ptEqual then
            begin
              NextCodeToken;
              // Missing extraction is not absence proof. This spelling only
              // refuses an alias candidate; it never grants a type identity.
              if lLexer.TokenID in [ptIdentifier, ptType] then
                Exit(True);
            end;
          end else
            lLexer.Next;
        end;
      finally
        lLexer.Free;
      end;
    end;
  end;
begin
  // The index owns immutable project models; both hits and misses share its lifetime.
  if fUnindexedAliases.TryGetValue(aTypeName, Result) then
    Exit;
  Result := ScanProjectAliases;
  fUnindexedAliases.AddOrSetValue(aTypeName, Result);
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
    lVisibleUnits := fTypeIndex.VisibleUnitNames(aOriginModel.UnitName, 'interface')
  else
    lVisibleUnits := fTypeIndex.VisibleUnitNames(aOriginModel.UnitName, 'implementation');
  lLookup := fTypeIndex.ResolveScopedName(aTypeName, aOriginModel.UnitName,
    aOriginScopeId, lVisibleUnits, aOriginSectionKind);
  Result := (not lLookup.Found) and SameText(lLookup.ReasonCode, 'UNSUPPORTED_LOCAL_TYPE');
end;

function TWithBindingProjectMemberIndex.TryResolveMemberOwnerIdentity(
  const aSymbol: TDelphiSemanticInventorySymbol;
  out aIdentity, aAccessIdentity: TDelphiSemanticTypeIdentity): Boolean;
var
  lAccessLookup: TDelphiSemanticTypeLookupResult;
  lOwnerIdentity: TDelphiSemanticTypeIdentity;
  lContext: TDelphiSemanticMemberLookupContext;
  lLineage: TDelphiSemanticLineage;
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
      lAccessLookup := Default(TDelphiSemanticTypeLookupResult);
      lAccessLookup.Found := OwnerIdentity(aSymbol.UnitName, aSymbol.OwnerName,
        aSymbol.OwnerScopeId, aSymbol.OwnerSymbolId, lAccessLookup.Identity);
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
    lAccessLookup := Default(TDelphiSemanticTypeLookupResult);
    lAccessLookup.Found := OwnerIdentity(Copy(lAccessOwnerName, 1, LastDelimiter('.',
      lAccessOwnerName) - 1), Copy(lAccessOwnerName, LastDelimiter('.', lAccessOwnerName) + 1,
      MaxInt), '', '', lAccessLookup.Identity);
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
    lAccessLookup := Default(TDelphiSemanticTypeLookupResult);
    lAccessLookup.Found := OwnerIdentity(Copy(lAccessOwnerName, 1, LastDelimiter('.',
      lAccessOwnerName) - 1), Copy(lAccessOwnerName, LastDelimiter('.', lAccessOwnerName) + 1,
      MaxInt), '', '', lAccessLookup.Identity);
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
  if aSymbol.SourceOwnerType = '' then
  begin
    lAccessLookup := Default(TDelphiSemanticTypeLookupResult);
    lAccessLookup.Found := OwnerIdentity(aSymbol.UnitName, aSymbol.OwnerName,
      '', '', lAccessLookup.Identity);
  end;
  if not lAccessLookup.Found then
    Exit;
  lLineage := fTypeIndex.ResolveLineage(lAccessLookup.Identity);
  lContext := Default(TDelphiSemanticMemberLookupContext);
  lContext.CallerUnitName := aSymbol.UnitName;
  lContext.InstanceContext := True;
  lLookup := Default(TDelphiSemanticMemberLookupResult);
  for lOwnerIdentity in lLineage.Items do
  begin
    lContext.OwnerDeclaredId := lOwnerIdentity.DeclaredId;
    lLookup := fSemanticMemberIndex.ResolveMember(lContext, '', aSymbol.Name);
    if not (SameText(lLookup.Status, 'unresolved') and
      SameText(lLookup.ReasonCode, 'DIRECT_MEMBER_NOT_FOUND')) then
      Break;
  end;
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
    Result := fTypeIndex.FindByDeclaredId(lLookup.Member.OwnerDeclaredId, aIdentity) and
      TrySafetyDeclarationModel(aIdentity, lAccessModel);
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

function AliasTargetTypeName(const aIdentity: TDelphiSemanticTypeIdentity;
  out aStrong: Boolean): string;
var
  i: Integer;
begin
  Result := '';
  aStrong := False;
  if not SameText(aIdentity.Kind, 'type-alias') then
    Exit;
  Result := aIdentity.CanonicalName.Trim;
  aStrong := (Length(Result) > 4) and SameText(Copy(Result, 1, 4), 'type') and
    CharInSet(Result[5], [#9, #10, #13, ' ']);
  if aStrong then
    Result := Copy(Result, 6, MaxInt).Trim;
  // Escapes are lexical spelling, not part of the identifier identity.
  Result := Result.Replace('&', '');
  if (Result = '') or (not CharInSet(Result[1], ['A'..'Z', 'a'..'z', '_'])) then
    Exit('');
  for i := 2 to Length(Result) do
    if not CharInSet(Result[i], ['A'..'Z', 'a'..'z', '0'..'9', '_', '.']) then
      Exit('');
end;

procedure TWithBindingProjectMemberIndex.BuildHelperTargetIndex;
var
  lDeclaration: TDelphiSemanticDeclaration;
  lLookup: TDelphiSemanticTypeLookupResult;
  lModel: TDelphiSemanticUnitModel;
  lVisibleUnits: TArray<string>;
begin
  fHelperTargetDeclaredIds := TDictionary<string, Byte>.Create(
    TFastCaseAwareComparer.OrdinalIgnoreCase);
  for lModel in fModels do
    for lDeclaration in lModel.Declarations do
      if lDeclaration.HelperTargetName <> '' then
      begin
        if SameText(lDeclaration.SectionKind, 'interface') then
          lVisibleUnits := fTypeIndex.VisibleUnitNames(lModel.UnitName, 'interface')
        else if SameText(lDeclaration.SectionKind, 'implementation') then
          lVisibleUnits := fTypeIndex.VisibleUnitNames(lModel.UnitName, 'implementation')
        else begin
          fHasUnresolvedHelperTarget := True;
          Continue;
        end;
        lLookup := fTypeIndex.ResolveVisibleName(lDeclaration.HelperTargetName,
          lModel.UnitName, lVisibleUnits, lDeclaration.SectionKind);
        // Alias targets may hide a strong identity further down their chain.
        if (not lLookup.Found) or lLookup.Ambiguous or
          SameText(lLookup.Identity.Kind, 'type-alias') or
          (lLookup.Identity.DeclaredId.Value = '') then
          fHasUnresolvedHelperTarget := True
        else
          fHelperTargetDeclaredIds.AddOrSetValue(lLookup.Identity.DeclaredId.Value, 0);
      end;
end;

function TWithBindingProjectMemberIndex.TryResolveAliasTargetSelector(
  const aModel: TDelphiSemanticUnitModel; const aSite: TReceiverLookupSite;
  const aSelector: TDelphiSemanticWithSelectorBinding;
  out aTarget: TDelphiSemanticWithSelectorBinding; out aRefusal: string): Boolean;
var
  lBinding: TDelphiSemanticWithBinding;
  lHasStrong, lStrong: Boolean;
  lIdentity: TDelphiSemanticTypeIdentity;
  lLineage: TDelphiSemanticLineage;
  lTargetIndex: Integer;
begin
  Result := False;
  aTarget := aSelector;
  aRefusal := '';
  if (not SameText(aSelector.Status, 'resolved')) or
    (aSelector.ReasonCode <> '') or
    (not SameText(aSelector.TypeIdentity.Kind, 'type-alias')) then
    Exit;
  lBinding := Default(TDelphiSemanticWithBinding);
  lBinding.UnitName := aModel.UnitName;
  lBinding.FileName := aModel.FileName;
  lLineage := TryBuildMemberSafetyLineage(lBinding, aSelector.TypeName,
    aSelector.TypeIdentity);
  if (not lLineage.Complete) and (lLineage.Cause <> 'profile-terminal') then
  begin
    aRefusal := 'ALIAS_RECEIVER_MEMBERS_UNVERIFIED';
    Exit;
  end;
  lHasStrong := False;
  lTargetIndex := 0;
  while (lTargetIndex < Length(lLineage.Items)) and
    SameText(lLineage.Items[lTargetIndex].Kind, 'type-alias') do
  begin
    AliasTargetTypeName(lLineage.Items[lTargetIndex], lStrong);
    lHasStrong := lHasStrong or lStrong;
    Inc(lTargetIndex);
  end;
  // Weak profile terminals retain the DS-742 boundary. Strong aliases have
  // no indexed member identities here, so they cannot authorize a rewrite.
  if lTargetIndex >= Length(lLineage.Items) then
  begin
    if lHasStrong then
      aRefusal := 'ALIAS_RECEIVER_MEMBERS_UNVERIFIED';
    Exit;
  end;
  if lHasStrong then
  begin
    if fHasUnresolvedHelperTarget or UnindexedRecordHelperMayApply(aSite, lLineage.Items) then
      aRefusal := 'ALIAS_RECEIVER_MEMBERS_UNVERIFIED';
    for lIdentity in lLineage.Items do
      if fHelperTargetDeclaredIds.ContainsKey(lIdentity.DeclaredId.Value) then
        aRefusal := 'ALIAS_RECEIVER_MEMBERS_UNVERIFIED';
    if aRefusal <> '' then
      Exit;
  end;
  aTarget.TypeIdentity := lLineage.Items[lTargetIndex];
  aTarget.TypeName := aTarget.TypeIdentity.Name;
  Result := True;
end;

function TWithBindingProjectMemberIndex.TryBuildMemberSafetyLineage(
  const aBinding: TDelphiSemanticWithBinding;
  const aSelectorTypeName: string; const aSelectorIdentity: TDelphiSemanticTypeIdentity):
  TDelphiSemanticLineage;
var
  lIdentity: TDelphiSemanticTypeIdentity;
  lModel: TDelphiSemanticUnitModel;
  lTargetName: string;
  lStrong: Boolean;
begin
  Result := fTypeIndex.ResolveLineage(aSelectorIdentity);
  // Retain the verified prefix for activity checks and external root queries.
  // An incomplete prefix itself never proves absence or helper applicability.
  for lIdentity in Result.Items do
    if not TrySafetyDeclarationModel(lIdentity, lModel) then
    begin
      Result.Complete := False;
      Result.Cause := 'declaration-unverified';
      Exit;
    end;
  if SameText(Result.Cause, 'alias-unresolved') and (Length(Result.Items) > 0) then
  begin
    // A profile tail is an alias boundary, not evidence for a class ancestor.
    for lIdentity in Result.Items do
      if not SameText(lIdentity.Kind, 'type-alias') then
        Exit;
    lIdentity := Result.Items[High(Result.Items)];
    lTargetName := AliasTargetTypeName(lIdentity, lStrong);
    // Preserve the positive compiler-profile boundary from the old walk.
    // This does not convert an unproved import lookup to absence: the lineage
    // stays incomplete, and only witnessed profile members may recover below.
    if (Pos('.', lTargetName) = 0) and
      fSafetyProfileTypes.ContainsKey(lTargetName) and
      (not fSafetyDeclarationsByName.ContainsKey(lTargetName)) then
      Result.Cause := 'profile-terminal';
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
    lVisibleUnits := fTypeIndex.VisibleUnitNames(aModel.UnitName, 'interface')
  else if SameText(aDeclaration.SectionKind, 'implementation') then
    lVisibleUnits := fTypeIndex.VisibleUnitNames(aModel.UnitName, 'implementation')
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

function ModelCanSupplyMemberEvidence(const aModel: TDelphiSemanticUnitModel): Boolean;
begin
  Result := aModel.Success;
end;

function TWithBindingProjectMemberIndex.ModelIsClosedForRootProof(
  const aModel: TDelphiSemanticUnitModel): Boolean;
var
  lDeclaration: TDelphiSemanticDeclaration;
  lDiagnostic: TMemberSafetyDiagnostic;
  lInvalidRoutineCount: Integer;
  lModelDiagnostic: TDelphiSemanticModelDiagnostic;
begin
  Result := False;
  // Extraction already expands resolved includes. Failed expansion and unknown
  // activity remain unverified; an include filename alone does not open the scope.
  if (not ModelCanSupplyMemberEvidence(aModel)) or (not SameText(aModel.ScopeModelStatus, 'ast')) or
    SameText(aModel.UnitName, 'System') then
    Exit;
  // A dropped conditional branch can hide uses, helpers, types or another include.
  // The existing preprocess diagnostics apply to this model and its expanded includes;
  // neither a provider answer nor a closed-root shortcut can repair that missing scope.
  for lModelDiagnostic in aModel.Diagnostics do
    if MatchText(lModelDiagnostic.Code, ['UNVERIFIED_PREPROCESS_CONDITION',
      'UNSUPPORTED_PREPROCESS_DIRECTIVE', 'UNMATCHED_PREPROCESS_DIRECTIVE',
      'UNTERMINATED_PREPROCESS_CONDITIONAL']) then
      Exit;
  lInvalidRoutineCount := 0;
  for lDeclaration in aModel.Declarations do
  begin
    if MatchText(lDeclaration.Kind, ['type', 'type-alias']) then
    begin
      // DS-716: an empty or unknown AST kind cannot establish helper absence.
      if not SameText(lDeclaration.AstHelperKind, 'none') then
      begin
        if not IsVerifiedRecordHelper(aModel, lDeclaration) then
          Exit;
      end else if lDeclaration.HelperTargetName <> '' then
        Exit;
    end else if lDeclaration.HelperTargetName <> '' then
      Exit;
    if SameText(lDeclaration.DeclarationRole, 'invalid') then
    begin
      // DS-715: only uniquely matched, source-verified unit routine headers
      // may lack declaration IDs. Unknown/local/type omissions cannot prove closure.
      if not UnitRoutineDeclarationIsVerified(aModel, lDeclaration) then
        Exit;
      Inc(lInvalidRoutineCount);
    end;
  end;
  if aModel.RejectedDeclarationCount <> lInvalidRoutineCount then
    Exit;
  for lDiagnostic in fMemberSafetyDiagnostics do
    if SameText(lDiagnostic.UnitName, aModel.UnitName) and
      ((not lDiagnostic.OwnerResolved) or
      SameText(lDiagnostic.Code, 'MEMBERS_UNVERIFIED') or
      SameText(lDiagnostic.Code, 'MEMBERS_INCOMPLETE')) then
      Exit;
  Result := True;
end;

function TWithBindingProjectMemberIndex.RootHeadingIsNonGeneric(
  const aIdentity: TDelphiSemanticTypeIdentity;
  const aModel: TDelphiSemanticUnitModel): Boolean;
var
  g: TGarbos;
  lDeclaration: TDelphiSemanticDeclaration;
  lLexer: TmwBasePasLex;
  lSource: TDelphiSemanticSourceText;
  lSourceText: string;
  lHeading, lInBase: Boolean;
begin
  Result := False;
  for lDeclaration in aModel.Declarations do
    if (lDeclaration.SymbolId = aIdentity.SemanticSymbolId) and
      (lDeclaration.Line = aIdentity.SourceRange.Line) and
      (lDeclaration.Column = aIdentity.SourceRange.Column) then
    begin
      // Snapshot-backed models retain their own source, but not observation handles.
      lSourceText := '';
      if SameText(aModel.FileName, aIdentity.SourceRange.FileName) then
        lSourceText := aModel.SourceText
      else if (aModel.SourceObservations <> nil) and
        aModel.SourceObservations.TryFind(aIdentity.SourceRange.FileName, lSource) then
        lSourceText := lSource.Text;
      if (lDeclaration.Offset <= 0) or (lDeclaration.Offset > Length(lSourceText)) then
        Exit;
      GC(lLexer, TmwBasePasLex.Create, g);
      lLexer.UseDefines := False;
      lLexer.Origin := Copy(lSourceText, lDeclaration.Offset, MaxInt);
      lHeading := False;
      lInBase := False;
      while lLexer.TokenID <> ptNull do
      begin
        if not IsTokenIDJunk(lLexer.TokenID) then
        begin
          if lLexer.Token = '<' then
            Exit;
          if lHeading then
          begin
            if lLexer.Token = '(' then
              lInBase := True
            else if lInBase then
            begin
              if lLexer.Token = ')' then
                Exit(True);
            end else if not MatchText(lLexer.Token, ['abstract', 'sealed']) then
              Exit(aIdentity.BaseTypeName = '');
          end else if MatchText(lLexer.Token, ['class', 'interface']) then
            lHeading := True;
        end;
        lLexer.Next;
      end;
      Exit;
    end;
end;

function TWithBindingProjectMemberIndex.TryRootProofUnits(
  const aModel: TDelphiSemanticUnitModel; const aIncludeImplementation: Boolean;
  out aUnits: TArray<string>): Boolean;
var
  lIndexes: TArray<Integer>;
  lUsedUnit: string;
  lUses: TArray<string>;
begin
  Result := False;
  aUnits := nil;
  if (not ModelIsClosedForRootProof(aModel)) or
    (not aModel.DependencyFacts.Known) then
    Exit;
  // The exact source model owns this scope. An index selected by unit name
  // may represent a different file and must not silently drop its imports.
  lUses := Copy(aModel.DependencyFacts.InterfaceImports);
  if aIncludeImplementation then
    lUses := lUses + aModel.DependencyFacts.ImplementationImports;
  if (Length(lUses) = 0) and (Length(aModel.DependencyFacts.RootImports) > 0) then
    lUses := Copy(aModel.DependencyFacts.RootImports);
  if ((Length(aModel.InterfaceUses) > 0) or
    (aIncludeImplementation and (Length(aModel.ImplementationUses) > 0))) and
    (Length(lUses) = 0) then
    Exit;
  // Unknown imports cannot be supplied as a unit name to an absence provider.
  if MatchText('<imports-unproved>', lUses) then
    Exit;
  // Empty means no external units remain after each project import is checked.
  // Unknown or dropped imports above cannot certify an empty scope.
  for lUsedUnit in lUses do
    if fSafetyModelsByUnit.TryGetValue(lUsedUnit, lIndexes) then
    begin
      if (Length(lIndexes) <> 1) or
        (not ModelIsClosedForRootProof(fModels[lIndexes[0]])) then
        Exit;
    end else
      aUnits := aUnits + [lUsedUnit];
  Result := True;
end;

function TWithBindingProjectMemberIndex.TryBuildRootQueryLineage(
  const aBinding: TDelphiSemanticWithBinding; const aSelectorTypeName: string;
  const aSelectorIdentity: TDelphiSemanticTypeIdentity;
  out aLineage: TArray<TDelphiSemanticTypeIdentity>): Boolean;
var
  lSafetyLineage: TDelphiSemanticLineage;
  lIdentity: TDelphiSemanticTypeIdentity;
  lLookup: TDelphiSemanticTypeLookupResult;
  lModel: TDelphiSemanticUnitModel;
  lSegments: TArray<string>;
  lTarget: string;
begin
  Result := False;
  // The ordinary walk retains its verified prefix on an unresolved terminal.
  // Reuse that walk so scope, cycle and declaration identity checks cannot drift.
  lSafetyLineage := TryBuildMemberSafetyLineage(aBinding, aSelectorTypeName, aSelectorIdentity);
  aLineage := lSafetyLineage.Items;
  if MatchText(lSafetyLineage.Cause, ['cycle', 'declaration-unverified']) then
    Exit;
  if Length(aLineage) = 0 then
    Exit;
  for lIdentity in aLineage do
    if (not SameText(lIdentity.Kind, 'type')) or
      SameText(lIdentity.ScopeKind, 'routine') or (lIdentity.HelperTargetName <> '') or
      (not MatchText(lIdentity.UnderlyingName, ['class', 'interface'])) or
      (not TrySafetyDeclarationModel(lIdentity, lModel)) or
      (not RootHeadingIsNonGeneric(lIdentity, lModel)) then
      Exit;
  lIdentity := aLineage[High(aLineage)];
  lTarget := lIdentity.BaseTypeName;
  if not TRegEx.IsMatch(lTarget, '^[A-Za-z_][A-Za-z0-9_]*(\.[A-Za-z_][A-Za-z0-9_]*)*$') then
    Exit;
  lLookup := ResolveValueEvidenceType(lTarget, lIdentity);
  if lLookup.Found or lLookup.Ambiguous or
    (not SameText(lLookup.ReasonCode, 'TYPE_NOT_FOUND')) then
    Exit;
  lSegments := lTarget.Split(['.']);
  Result := (not fSafetyDeclarationsByName.ContainsKey(lSegments[0])) and
    (not fSafetyDeclarationsByName.ContainsKey(lSegments[High(lSegments)]));
end;

function TWithBindingProjectMemberIndex.HasClosedRootSourceContext(
  const aContextModel: TDelphiSemanticUnitModel): Boolean;
var
  g: TGarbos;
  lIndexes: TArray<Integer>;
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
    if not ModelIsClosedForRootProof(lModel) then
      Exit;
    for lUsedUnit in lModel.InterfaceUses do
      lPending.Enqueue(lUsedUnit);
    for lUsedUnit in lModel.ImplementationUses do
      lPending.Enqueue(lUsedUnit);
  end;
  Result := True;
end;

function ValueOwnerKey(const aUnitName, aOwnerName, aName: string): string;
begin
  Result := aUnitName + #31 + Copy(aOwnerName, LastDelimiter('.', aOwnerName) + 1,
    MaxInt) + #31 + aName;
end;

function RefuseValueMember(const aName, aCode, aReason: string;
  out aResult: TBoundMemberResolution): Boolean;
begin
  aResult := Default(TBoundMemberResolution);
  aResult.Value.Status := 'unsupported';
  aResult.Value.Name := aName;
  aResult.Value.ReasonCode := aCode;
  aResult.Value.Reason := aReason;
  Result := True;
end;

function TWithBindingProjectMemberIndex.ResolveValueEvidenceType(
  const aName: string; const aContext: TDelphiSemanticTypeIdentity):
  TDelphiSemanticTypeLookupResult;
var
  lCandidate, lSelected: TDelphiSemanticTypeIdentity;
  lDeclaration: TDelphiSemanticDeclaration;
  lFullCount: Integer;
  lModel: TDelphiSemanticUnitModel;
  lUses: TArray<string>;
begin
  if (aContext.DeclaredId.Value = '') or (Pos('.', aName) > 0) then
    Result := fTypeIndex.ResolveQualifiedName(aName)
  else begin
    if not TrySafetyDeclarationModel(aContext, lModel) then
      Exit(Default(TDelphiSemanticTypeLookupResult));
    lUses := fTypeIndex.VisibleUnitNames(lModel.UnitName, aContext.SectionKind);
    if SameText(aContext.ScopeKind, 'routine') then
      Result := fTypeIndex.ResolveScopedName(aName, aContext.UnitName,
        aContext.OwnerScopeId, lUses, aContext.SectionKind)
    else
      Result := fTypeIndex.ResolveVisibleName(aName, aContext.UnitName,
        lUses, aContext.SectionKind);
  end;
  if not Result.Ambiguous then
    Exit;
  // A forward and its full declaration share an owner, but may have distinct
  // source identities. Only the single full declaration supplies member facts.
  lFullCount := 0;
  lSelected := Default(TDelphiSemanticTypeIdentity);
  for lCandidate in Result.Candidates do
  begin
    if not TrySafetyDeclarationModel(lCandidate, lModel) then
      Exit;
    if (lSelected.Name <> '') and
      ((not SameText(lCandidate.UnitName, lSelected.UnitName)) or
      (not SameText(lCandidate.Name, lSelected.Name)) or
      (not SameText(lCandidate.OwnerScopeId, lSelected.OwnerScopeId)) or
      (not SameText(lCandidate.ScopeKind, lSelected.ScopeKind))) then
      Exit;
    if lSelected.Name = '' then
      lSelected := lCandidate;
    for lDeclaration in lModel.Declarations do
      if SameText(lDeclaration.SymbolId, lCandidate.SemanticSymbolId) and
        (lDeclaration.Line = lCandidate.SourceRange.Line) and
        (lDeclaration.Column = lCandidate.SourceRange.Column) and
        (lDeclaration.TypeBodyEndLine > 0) and
        SameText(lDeclaration.TypeName, 'class') then
      begin
        Inc(lFullCount);
        lSelected := lCandidate;
      end;
  end;
  if lFullCount = 1 then
  begin
    Result.Found := True;
    Result.Ambiguous := False;
    Result.Identity := lSelected;
  end;
end;

procedure AppendAnonymousAbsenceEvidence(const aModels: TArray<TDelphiSemanticUnitModel>;
  const aCaptureProofGraph: TDelphiSemanticSemanticGraph;
  const aUnitNameWitness: IDelphiSemanticUnitNameWitness;
  const aOwners: TList<TDelphiSemanticValueEvidenceOwner>;
  const aQueries: TList<TDelphiSemanticValueEvidenceQuery>;
  const aValueNames: THashSet<string>);
var
  g: TGarbos;
  lIdentity: TDelphiSemanticTypeIdentity;
  lGraph: TDelphiSemanticSemanticGraph;
  lGraphType: TDelphiSemanticGraphType;
  lIndex: TDelphiSemanticTypeIdentityIndex;
  lKey: string;
  lMember: TDelphiSemanticMember;
  lModel, lParsed: TDelphiSemanticUnitModel;
  lNames, lSeen, lAmbiguous: THashSet<string>;
  lPendingQueries: TList<TDelphiSemanticValueEvidenceQuery>;
  lOwner: TDelphiSemanticValueEvidenceOwner;
  lQuery: TDelphiSemanticValueEvidenceQuery;
begin
  GC(lNames, THashSet<string>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase), g);
  GC(lSeen, THashSet<string>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase), g);
  GC(lAmbiguous, THashSet<string>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase), g);
  GC(lPendingQueries, TList<TDelphiSemanticValueEvidenceQuery>.Create, g);
  for lModel in aModels do
  begin
    lParsed := TDelphiSemanticUnitModelExtractorImpl.AnonymousRecordAbsenceModel(lModel);
    if (not SameText(lParsed.ScopeModelStatus, 'ast')) or
      (Length(lParsed.Declarations) = 0) then
      Continue;
    GC(lGraph, TDelphiSemanticSemanticGraphBuilder.Build(
      BuildSyntheticWithBindingProjectInfo, [lParsed], aCaptureProofGraph), g);
    lGraph.UnitNameWitness := aUnitNameWitness;
    lIndex := TDelphiSemanticTypeResolver.BuildIndex(lGraph);
    for lGraphType in lGraph.Types do
    begin
      if not lIndex.FindByDeclaredId(lGraphType.DeclaredId, lIdentity) then
        Continue;
      if not AnonymousRecordDeclarationIsVerified(lParsed, lIdentity) then
        Continue;
      lNames.Clear;
      for lMember in lParsed.Members + lParsed.TypeValueMembers do
        if SameText(lMember.OwnerName, lIdentity.Name) then
        begin
          lNames.Add('ds742-anonymous-member:' + lMember.Name);
          aValueNames.Add('ds742-anonymous-member:' + lMember.Name);
        end;
      lKey := 'ds742-anonymous:' + lParsed.UnitName + #31 + lIdentity.Name;
      lOwner := Default(TDelphiSemanticValueEvidenceOwner);
      lOwner.DeclaredId := lKey + #31 + lIdentity.DeclaredId.Value;
      lOwner.UnitName := lParsed.UnitName;
      lOwner.FileName := lParsed.FileName;
      lOwner.Name := lIdentity.Name;
      lOwner.Complete := True;
      lOwner.TerminalVerified := True;
      lOwner.ValueNames := lNames.ToArray;
      aOwners.Add(lOwner);
      lQuery.Name := lKey;
      lQuery.DeclaredId := lOwner.DeclaredId;
      if not lSeen.Add(lKey) then
        lAmbiguous.Add(lKey);
      lPendingQueries.Add(lQuery);
    end;
  end;
  // A synthetic spelling shared by overloaded routines is not an identity.
  for lQuery in lPendingQueries do
    if not lAmbiguous.Contains(lQuery.Name) then
      aQueries.Add(lQuery);
end;

function TWithBindingProjectMemberIndex.ExportValueMemberEvidence:
  TDelphiSemanticValueMemberEvidence;
var
  g: TGarbos;
  i: Integer;
  lDeclaredId: TDelphiSemanticGraphTypeId;
  lDeclaration: TDelphiSemanticDeclaration;
  lFullDeclarationVerified: Boolean;
  lFact: TMemberSafetyDiagnostic;
  lIdentity: TDelphiSemanticTypeIdentity;
  lKey, lName, lTarget: string;
  lStrong: Boolean;
  lKeys: TArray<string>;
  lLookup: TDelphiSemanticTypeLookupResult;
  lModel: TDelphiSemanticUnitModel;
  lNames, lQueryNames, lSeen: THashSet<string>;
  lOwner: TDelphiSemanticValueEvidenceOwner;
  lOwners: TList<TDelphiSemanticValueEvidenceOwner>;
  lQueries: TList<TDelphiSemanticValueEvidenceQuery>;
  lQuery: TDelphiSemanticValueEvidenceQuery;
begin
  Result := Default(TDelphiSemanticValueMemberEvidence);
  Result.Available := Length(fModels) > 0;
  Result.ValueNames := fValueMemberNames.Keys.ToArray;
  Result.UnverifiedOwnerKeys := fUnverifiedValueOwners.Keys.ToArray;
  SetLength(Result.Units, Length(fModels));
  for i := 0 to High(fModels) do
  begin
    lModel := fModels[i];
    Result.Units[i].UnitName := lModel.UnitName;
    Result.Units[i].FileName := lModel.FileName;
    Result.Units[i].SourceText := lModel.SourceText;
    Result.Units[i].VerifiedActiveSourceText := lModel.VerifiedActiveSourceText;
    Result.Units[i].ScopeModelStatus := lModel.ScopeModelStatus;
    Result.Units[i].ScopeModelVersion := lModel.ScopeModelVersion;
    Result.Units[i].RejectedDeclarationCount := lModel.RejectedDeclarationCount;
  end;
  GC(lOwners, TList<TDelphiSemanticValueEvidenceOwner>.Create, g);
  GC(lQueries, TList<TDelphiSemanticValueEvidenceQuery>.Create, g);
  GC(lSeen, THashSet<string>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase), g);
  GC(lNames, THashSet<string>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase), g);
  GC(lQueryNames, THashSet<string>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase), g);
  for lDeclaredId in fValueTypeIds do
  begin
    if (lDeclaredId.Value = '') or (not lSeen.Add(lDeclaredId.Value)) or
      (not fTypeIndex.FindByDeclaredId(lDeclaredId, lIdentity)) then
      Continue;
    lOwner := Default(TDelphiSemanticValueEvidenceOwner);
    lOwner.DeclaredId := lDeclaredId.Value;
    lOwner.UnitName := lIdentity.UnitName;
    lOwner.FileName := lIdentity.SourceRange.FileName;
    lOwner.Name := lIdentity.Name;
    lOwner.Complete := TrySafetyDeclarationModel(lIdentity, lModel) and
      ModelCanSupplyMemberEvidence(lModel) and
      SameText(lModel.ScopeModelStatus, 'ast');
    if lOwner.Complete and SameText(lIdentity.Kind, 'type') and
      SameText(lIdentity.UnderlyingName, 'class') then
    begin
      // An indexed forward declaration is not an unindexed RTL root. Its
      // missing body cannot supply an explicit complete member-set witness.
      lFullDeclarationVerified := False;
      for lDeclaration in lModel.Declarations do
        if SameText(lDeclaration.SymbolId, lIdentity.SemanticSymbolId) and
          (lDeclaration.Line = lIdentity.SourceRange.Line) and
          (lDeclaration.Column = lIdentity.SourceRange.Column) and
          (lDeclaration.TypeBodyEndLine > 0) then
          lFullDeclarationVerified := True;
      lOwner.Complete := lFullDeclarationVerified;
    end;
    // Export the exact receiver/lineage diagnostic rule used by value coverage.
    for lFact in fMemberSafetyDiagnostics + fActivityMemberFacts do
      if SameText(lIdentity.UnitName, lFact.UnitName) and
        (SameText(lFact.Code, 'MEMBERS_UNVERIFIED') or (not lFact.OwnerResolved) or
        (SameText(lIdentity.Name, lFact.OwnerName) and
        (lIdentity.SourceRange.Line = lFact.Line) and
        SameText(lIdentity.SourceRange.FileName, lFact.FileName))) then
        lOwner.Complete := False;
    lNames.Clear;
    for lName in Result.ValueNames do
      if fValueMembers.ContainsKey(lDeclaredId.Value + #31 + lName) or
        fUnverifiedValueOwners.ContainsKey(ValueOwnerKey(lIdentity.UnitName,
          lIdentity.Name, lName)) then
        lNames.Add(lName);
    lOwner.ValueNames := lNames.ToArray;
    if SameText(lIdentity.Kind, 'type-alias') then
      lTarget := AliasTargetTypeName(lIdentity, lStrong)
    else
      lTarget := lIdentity.BaseTypeName;
    if lTarget = '' then
    begin
      lOwner.TerminalVerified := not SameText(lIdentity.Kind, 'type-alias');
      lOwner.UnindexedRoot := lOwner.TerminalVerified and
        (not MatchText(lIdentity.UnderlyingName, ['record', 'packed record']));
    end else begin
      lLookup := ResolveValueEvidenceType(lTarget, lIdentity);
      if lLookup.Ambiguous then
        lOwner.Complete := False
      else if lLookup.Found then
        lOwner.NextDeclaredId := lLookup.Identity.DeclaredId.Value
      else begin
        // Root completeness is distinct from indexed member-set completeness.
        lOwner.TerminalVerified := SameText(lIdentity.Kind, 'type') and
          SameText(lIdentity.UnderlyingName, 'class');
        lOwner.UnindexedRoot := lOwner.TerminalVerified;
      end;
    end;
    lOwners.Add(lOwner);
    // The planner supplies the same simple/qualified keys as the type resolver.
    lKeys := [lIdentity.Name, lIdentity.UnitName + '.' + lIdentity.Name];
    for lKey in lKeys do
      if lQueryNames.Add(lKey) then
      begin
        lLookup := ResolveValueEvidenceType(lKey, Default(TDelphiSemanticTypeIdentity));
        if lLookup.Found and (not lLookup.Ambiguous) then
        begin
          lQuery.Name := lKey;
          lQuery.DeclaredId := lLookup.Identity.DeclaredId.Value;
          lQueries.Add(lQuery);
        end;
      end;
  end;
  lNames.Clear;
  for lName in Result.ValueNames do
    lNames.Add(lName);
  AppendAnonymousAbsenceEvidence(fModels, fCaptureProofGraph, fUnitNameWitness, lOwners, lQueries, lNames);
  Result.ValueNames := lNames.ToArray;
  Result.Owners := lOwners.ToArray;
  Result.Queries := lQueries.ToArray;
end;

procedure TWithBindingProjectMemberIndex.BuildValueMemberIndex;
var
  lBound: TBoundMemberResolution;
  lDeclaration: TDelphiSemanticDeclaration;
  lExisting: TArray<TBoundMemberResolution>;
  lKey: string;
  lMatched: Boolean;
  lMember: TDelphiSemanticMember;
  lModel: TDelphiSemanticUnitModel;
  lOwner: TDelphiSemanticTypeLookupResult;
  lVisibility: TArray<string>;
begin
  fValueMembers := TDictionary<string, TArray<TBoundMemberResolution>>.Create(
    TFastCaseAwareComparer.OrdinalIgnoreCase);
  fValueVisibility := TDictionary<string, TArray<string>>.Create(
    TFastCaseAwareComparer.OrdinalIgnoreCase);
  fValueMemberNames := TDictionary<string, Byte>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
  fUnverifiedValueOwners := TDictionary<string, Byte>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
  fHelperValueNames := TDictionary<string, Byte>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
  for lModel in fModels do
  begin
    for lMember in lModel.TypeValueMembers do
    begin
      fValueMemberNames.AddOrSetValue(lMember.Name, 0);
      if lMember.OwnerScopeId <> '' then
      begin
        lOwner := fTypeIndex.ResolveScopedName(lMember.OwnerName, lModel.UnitName,
          lMember.OwnerScopeId, []);
        lMatched := lOwner.Found and (not lOwner.Ambiguous) and
          SameText(lOwner.Identity.OwnerScopeId, lMember.OwnerScopeId) and
          SameText(lOwner.Identity.SemanticSymbolId, lMember.OwnerSymbolId);
      end else begin
        lOwner := fTypeIndex.ResolveQualifiedName(lModel.UnitName + '.' + lMember.OwnerName);
        lMatched := lOwner.Found and (not lOwner.Ambiguous) and
          SameText(lOwner.Identity.ScopeKind, 'unit');
      end;
      if (not lMatched) or (lOwner.Identity.DeclaredId.Value = '') then
      begin
        fUnverifiedValueOwners.AddOrSetValue(ValueOwnerKey(lModel.UnitName,
          lMember.OwnerName, lMember.Name), 0);
        Continue;
      end;
      if lOwner.Identity.HelperTargetName <> '' then
        fHelperValueNames.AddOrSetValue(ValueOwnerKey('', lOwner.Identity.HelperTargetName,
          lMember.Name), 0);
      lBound := Default(TBoundMemberResolution);
      lBound.Value := MemberResult(lMember);
      lBound.DeclaringUnitName := lModel.UnitName;
      lBound.OwnerDeclaredId := lOwner.Identity.DeclaredId;
      lKey := lOwner.Identity.DeclaredId.Value + #31 + lMember.Name;
      if not fValueMembers.TryGetValue(lKey, lExisting) then
        lExisting := nil;
      if not fValueVisibility.TryGetValue(lKey, lVisibility) then
        lVisibility := nil;
      // Avoid managed-record array-constructor temporaries in Delphi's array concatenation.
      SetLength(lExisting, Length(lExisting) + 1);
      lExisting[High(lExisting)] := lBound;
      fValueMembers.AddOrSetValue(lKey, lExisting);
      SetLength(lVisibility, Length(lVisibility) + 1);
      lVisibility[High(lVisibility)] := lMember.Visibility;
      fValueVisibility.AddOrSetValue(lKey, lVisibility);
    end;
    // A declaration survives a lost value array: it must never authorize lexical fallthrough.
    for lDeclaration in lModel.Declarations do
    begin
      if (not SameText(lDeclaration.ScopeKind, 'type')) or
        (not MatchText(lDeclaration.Kind, ['const', 'typed-const'])) then
        Continue;
      lMatched := False;
      for lMember in lModel.TypeValueMembers do
        if SameText(lMember.OwnerName, lDeclaration.OwnerName) and
          SameText(lMember.Name, lDeclaration.Name) and
          (lMember.Line = lDeclaration.Line) and (lMember.Column = lDeclaration.Column) and
          SameText(lMember.FileName, lDeclaration.FileName) then
        begin
          lMatched := True;
          Break;
        end;
      if not lMatched then
      begin
        fValueMemberNames.AddOrSetValue(lDeclaration.Name, 0);
        fUnverifiedValueOwners.AddOrSetValue(ValueOwnerKey(lModel.UnitName,
          lDeclaration.OwnerName, lDeclaration.Name), 0);
      end;
    end;
  end;
end;

function TWithBindingProjectMemberIndex.MembersClosed(
  const aIdentity: TDelphiSemanticTypeIdentity): Boolean;
var
  lFact: TMemberSafetyDiagnostic;
begin
  Result := not LineageHasActivityFact([aIdentity]);
  if not Result then
    Exit;
  for lFact in fMemberSafetyDiagnostics do
    if SameText(aIdentity.UnitName, lFact.UnitName) and
      (SameText(lFact.Code, 'MEMBERS_UNVERIFIED') or (not lFact.OwnerResolved) or
      (SameText(aIdentity.Name, lFact.OwnerName) and
      (aIdentity.SourceRange.Line = lFact.Line) and
      SameText(aIdentity.SourceRange.FileName, lFact.FileName))) then
      Exit(False);
end;

function TWithBindingProjectMemberIndex.TryResolveReceiverValueMember(
  const aModel: TDelphiSemanticUnitModel; const aSite: TReceiverLookupSite;
  const aSelector: TDelphiSemanticWithSelectorBinding; const aName, aStopDeclaredId: string): TMemberVerdict;
var
  lBinding: TDelphiSemanticWithBinding;
  lBound: TBoundMemberResolution;
  lCandidates: TArray<TBoundMemberResolution>;
  lIdentity: TDelphiSemanticTypeIdentity;
  lKey: string;
  lLineage: TDelphiSemanticLineage;
  lVisibility: TArray<string>;
begin
  Result := TMemberVerdict.NotPresent;
  lBound := Default(TBoundMemberResolution);
  if not fValueMemberNames.ContainsKey(aName) then
    Exit;
  lBinding := Default(TDelphiSemanticWithBinding);
  lBinding.UnitName := aModel.UnitName;
  lBinding.FileName := aModel.FileName;
  lLineage := TryBuildMemberSafetyLineage(lBinding, aSelector.TypeName, aSelector.TypeIdentity);
  for lIdentity in lLineage.Items do
  begin
    if (aStopDeclaredId <> '') and SameText(lIdentity.DeclaredId.Value, aStopDeclaredId) then
      Exit;
    if fUnverifiedValueOwners.ContainsKey(ValueOwnerKey(lIdentity.UnitName,
      lIdentity.Name, aName)) then
      Exit(TMemberVerdict.Barrier(noUnproved, 'TYPE_VALUE_MEMBERS_UNVERIFIED',
        'A type value member has no verified owner fact.', 'value-member'));
    lKey := lIdentity.DeclaredId.Value + #31 + aName;
    if not fValueMembers.TryGetValue(lKey, lCandidates) then
      Continue;
    if Length(lCandidates) <> 1 then
    begin
      lBound.Value.Status := 'ambiguous';
      lBound.Value.Name := aName;
      lBound.Value.ReasonCode := 'MULTIPLE_MEMBER_CANDIDATES';
      Exit(MemberVerdictFromBound(lBound));
    end;
    if (not fValueVisibility.TryGetValue(lKey, lVisibility)) or
      (Length(lVisibility) <> 1) or
      (not (MatchText(lVisibility[0], ['', 'public', 'published', 'automated']) or
      (MatchText(lVisibility[0], ['private', 'protected']) and
      SameText(lCandidates[0].DeclaringUnitName, aSite.UnitName)))) then
      Exit(TMemberVerdict.Barrier(noUnproved, 'TYPE_VALUE_MEMBER_ACCESS_UNVERIFIED',
        'Access to the type value member is not verified.', 'value-member'));
    if (not lLineage.Complete) or UnindexedRecordHelperMayApply(aSite, lLineage.Items) then
      Exit(TMemberVerdict.Barrier(noUnproved, 'TYPE_VALUE_MEMBERS_UNVERIFIED',
        'The value member lineage or helper applicability is unverified.', 'value-member'));
    for var lOwner in lLineage.Items do
    begin
      if not MembersClosed(lOwner) then
        Exit(TMemberVerdict.Barrier(noUnproved, 'TYPE_VALUE_MEMBERS_UNVERIFIED',
          'The value member owner evidence is not closed.', 'value-member'));
      if lOwner.DeclaredId.Value = lIdentity.DeclaredId.Value then
        Break;
    end;
    lBound := lCandidates[0];
    // Value references name the selected receiver; OwnerDeclaredId still identifies the fact.
    lBound.Value.OwnerName := aSelector.TypeName;
    Exit(MemberVerdictFromBound(lBound));
  end;
end;

function TWithBindingProjectMemberIndex.TryResolveShadowingValueMember(
  const aModel: TDelphiSemanticUnitModel; const aSite: TReceiverLookupSite;
  const aSelector: TDelphiSemanticWithSelectorBinding; const aName: string;
  const aDirect: TBoundMemberResolution; out aResult: TBoundMemberResolution): Boolean;
var
  i: Integer;
  lBinding: TDelphiSemanticWithBinding;
  lLineage: TDelphiSemanticLineage;
  lIdentity: TDelphiSemanticTypeIdentity;
  lVerdict: TMemberVerdict;
begin
  Result := False;
  if not fValueMemberNames.ContainsKey(aName) then
    Exit;
  lBinding := Default(TDelphiSemanticWithBinding);
  lBinding.UnitName := aModel.UnitName;
  lBinding.FileName := aModel.FileName;
  lLineage := TryBuildMemberSafetyLineage(lBinding, aSelector.TypeName, aSelector.TypeIdentity);
  if not lLineage.Complete then
    Exit;
  for i := 0 to High(lLineage.Items) do
    if ((aDirect.OwnerDeclaredId.Value <> '') and
      SameText(lLineage.Items[i].DeclaredId.Value, aDirect.OwnerDeclaredId.Value)) or
      ((aDirect.OwnerDeclaredId.Value = '') and
      SameText(ValueOwnerKey(lLineage.Items[i].UnitName, lLineage.Items[i].Name, ''),
      ValueOwnerKey(aDirect.DeclaringUnitName, aDirect.Value.OwnerName, ''))) then
    begin
      if i = 0 then
        Exit;
      lVerdict := TryResolveReceiverValueMember(aModel, aSite, aSelector, aName,
        lLineage.Items[i].DeclaredId.Value);
      aResult := lVerdict.AsBound(aName, -1);
      Exit(lVerdict.Outcome <> noAbsent);
    end;
  // Helper-owned direct members need no shadowing proof when this name occurs
  // only on unrelated types. Refuse only a real or unverified lineage candidate.
  for lIdentity in lLineage.Items do
    if fValueMembers.ContainsKey(lIdentity.DeclaredId.Value + #31 + aName) or
      fUnverifiedValueOwners.ContainsKey(ValueOwnerKey(lIdentity.UnitName,
        lIdentity.Name, aName)) then
      Exit(RefuseValueMember(aName, 'TYPE_VALUE_MEMBERS_UNVERIFIED',
        'A type value member may shadow a direct member with an unverified owner.', aResult));
end;

function TWithBindingProjectMemberIndex.UnindexedRecordHelperMayApply(
  const aSite: TReceiverLookupSite; const aLineage: TArray<TDelphiSemanticTypeIdentity>): Boolean;
var
  lSiteModel, lHelperModel: TDelphiSemanticUnitModel;
  lIndexes: TArray<Integer>;
  lHelper: TDelphiSemanticUnindexedHelperFact;
  lDiagnostic: TDelphiSemanticModelDiagnostic;
  lLookup: TDelphiSemanticTypeLookupResult;
  lBinding: TDelphiSemanticWithBinding;
  lTargetLineage: TDelphiSemanticLineage;
  lTargetIdentity, lReceiverIdentity: TDelphiSemanticTypeIdentity;
  lUses: TArray<string>;
  lUsedUnit, lTargetName: string;
  lIndex, lMatches, lDiagnosticCount: Integer;
  lSameUnit, lVisible: Boolean;
  function LastName(const aName: string): string;
  begin
    Result := Copy(aName, LastDelimiter('.', aName) + 1, MaxInt);
  end;
begin
  Result := False;
  if Length(fUnindexedHelperModelIndexes) = 0 then
    Exit;
  if not fSafetyModelsByUnit.TryGetValue(aSite.UnitName, lIndexes) then
    Exit(True);
  lMatches := 0;
  for lIndex in lIndexes do
    if SameText(fModels[lIndex].FileName, aSite.FileName) then
    begin
      lSiteModel := fModels[lIndex];
      Inc(lMatches);
    end;
  if lMatches <> 1 then
    Exit(True);
  for lIndex in fUnindexedHelperModelIndexes do
  begin
    lHelperModel := fModels[lIndex];
    lSameUnit := SameText(lHelperModel.UnitName, aSite.UnitName);
    lVisible := lSameUnit;
    for lUsedUnit in lSiteModel.InterfaceUses + lSiteModel.ImplementationUses do
      if SameText(lUsedUnit, lHelperModel.UnitName) or
        EndsText('.' + lUsedUnit, lHelperModel.UnitName) then
        lVisible := True;
    if not lVisible then
      Continue;
    lDiagnosticCount := 0;
    for lDiagnostic in lHelperModel.Diagnostics do
      if SameText(lDiagnostic.Code, 'AST_HELPER_DECLARATION_UNINDEXED') then
        Inc(lDiagnosticCount);
    // Missing persisted facts cannot authorize member absence.
    if Length(lHelperModel.UnindexedHelpers) < lDiagnosticCount then
      Exit(True);
    for lHelper in lHelperModel.UnindexedHelpers do
    begin
      if SameText(lHelper.HelperKind, 'class') then
        Continue;
      if lSameUnit then
      begin
        if not SameText(lHelper.SectionKind, 'interface') and (lHelper.FileName = '') and
          (lHelper.Line > 0) and ((lHelper.Line > aSite.Line) or
          ((lHelper.Line = aSite.Line) and (lHelper.Column >= aSite.Column))) then
          Continue;
      end else if not SameText(lHelper.SectionKind, 'interface') or
        not SameText(lHelper.ScopeKind, 'unit') then
        Continue;
      if (lHelper.HelperKind = '') or (lHelper.TargetName = '') then
        Exit(True);
      lUses := fTypeIndex.VisibleUnitNames(lHelperModel.UnitName, lHelper.SectionKind);
      if SameText(lHelper.ScopeKind, 'routine') then
        lLookup := fTypeIndex.ResolveScopedName(lHelper.TargetName, lHelperModel.UnitName,
          lHelper.OwnerScopeId, fTypeIndex.VisibleUnitNames(lHelperModel.UnitName, 'implementation'),
          'implementation')
      else if Pos('.', lHelper.TargetName) > 0 then
        lLookup := fTypeIndex.ResolveQualifiedName(lHelper.TargetName)
      else
        lLookup := fTypeIndex.ResolveVisibleName(lHelper.TargetName, lHelperModel.UnitName,
          lUses, lHelper.SectionKind);
      if lLookup.Ambiguous then
        Exit(True);
      if lLookup.Found then
      begin
        lBinding := Default(TDelphiSemanticWithBinding);
        lBinding.UnitName := lHelperModel.UnitName;
        lBinding.FileName := lHelperModel.FileName;
        lTargetLineage := TryBuildMemberSafetyLineage(lBinding, lLookup.Identity.Name, lLookup.Identity);
        if not lTargetLineage.Complete then
          Exit(True);
        for lTargetIdentity in lTargetLineage.Items do
          for lReceiverIdentity in aLineage do
            if (lTargetIdentity.DeclaredId.Value <> '') and
              (lTargetIdentity.DeclaredId.Value = lReceiverIdentity.DeclaredId.Value) then
              Exit(True);
      end else begin
        lTargetName := LastName(lHelper.TargetName);
        for lReceiverIdentity in aLineage do
          if SameText(lTargetName, LastName(lReceiverIdentity.Name)) then
            Exit(True);
      end;
    end;
  end;
end;

function TWithBindingProjectMemberIndex.ReceiverMemberAbsenceIsVerified(
  const aModel: TDelphiSemanticUnitModel;
  const aSelector: TDelphiSemanticWithSelectorBinding; const aName: string;
  const aSite: TReceiverLookupSite; out aRefusalCode: string): Boolean;
var
  lRootProof: TRootAbsenceProof;
begin
  Result := ReceiverMemberAbsenceIsVerified(aModel, aSelector, aName, aSite,
    aRefusalCode, lRootProof);
end;

function TWithBindingProjectMemberIndex.ReceiverMemberAbsenceIsVerified(
  const aModel: TDelphiSemanticUnitModel;
  const aSelector: TDelphiSemanticWithSelectorBinding; const aName: string;
  const aSite: TReceiverLookupSite; out aRefusalCode: string;
  out aRootProof: TRootAbsenceProof): Boolean;
var
  lBinding: TDelphiSemanticWithBinding;
  lDirectLookup: TDelphiSemanticMemberLookupResult;
  lIdentity: TDelphiSemanticTypeIdentity;
  lLineage: TDelphiSemanticLineage;
  lOwnerModel: TDelphiSemanticUnitModel;
  lNamed: IDelphiSemanticNamedRootMemberAbsence;
  lRoot: TDelphiSemanticQualifiedRootType;
  lSiteUnits, lOwnerUnits: TArray<string>;
  i: Integer;
  lClosed: Boolean;
begin
  Result := False;
  aRefusalCode := '';
  aRootProof := Default(TRootAbsenceProof);
  lBinding := Default(TDelphiSemanticWithBinding);
  lBinding.UnitName := aModel.UnitName;
  lBinding.FileName := aModel.FileName;
  Supports(fRootMemberAbsence, IDelphiSemanticNamedRootMemberAbsence, lNamed);
  lLineage := TryBuildMemberSafetyLineage(lBinding, aSelector.TypeName,
    aSelector.TypeIdentity);
  if not lLineage.Complete then
    if (lNamed = nil) or (not TryBuildRootQueryLineage(lBinding, aSelector.TypeName,
      aSelector.TypeIdentity, lLineage.Items)) then
      Exit;
  if Length(lLineage.Items) = 0 then
    Exit;
  for lIdentity in lLineage.Items do
    if not MembersClosed(lIdentity) then
      Exit;
  // Root evidence covers only the implicit root, never indexed declarations.
  for lIdentity in lLineage.Items do
  begin
    lDirectLookup := fSemanticMemberIndex.ResolveDirectMemberByOwnerId(
      lIdentity.DeclaredId, aName);
    if (not SameText(lDirectLookup.Status, 'unresolved')) or
      (not SameText(lDirectLookup.ReasonCode, 'DIRECT_MEMBER_NOT_FOUND')) then
      Exit;
  end;
  lIdentity := lLineage.Items[High(lLineage.Items)];
  // DS-700: compiler-profile terminals verify a type name, not its member set.
  // An implicit class root can also own a missing name. Only an indexed root
  // record proves absence without consulting an unindexed ancestor.
  Result := SameText(lIdentity.Kind, 'type') and (lIdentity.BaseTypeName = '') and
    (lIdentity.HelperTargetName = '') and
    MatchText(lIdentity.UnderlyingName, ['record', 'packed record']);
  if Result then
  begin
    if UnindexedRecordHelperMayApply(aSite, lLineage.Items) then
    begin
      Result := False;
      aRefusalCode := 'RECORD_HELPER_MEMBERS_UNVERIFIED';
    end;
    Exit;
  end;
  if (fRootMemberAbsence = nil) or (aName = '') then
    Exit;
  // BaseTypeName erases arguments; neither provider route may certify that root.
  for lIdentity in lLineage.Items do
    if (not TrySafetyDeclarationModel(lIdentity, lOwnerModel)) or
      (not RootHeadingIsNonGeneric(lIdentity, lOwnerModel)) then
      Exit;
  // The closed implicit-class route plans only with positive absence proof,
  // including expanded includes on DS routes. DAK rejects conditional or include directives
  // for native root proof, so statements needing that proof refuse there.
  // The named route below still requires exact declaration and site scopes.
  lClosed := HasClosedRootSourceContext(aModel) and
    SameText(lIdentity.Kind, 'type') and SameText(lIdentity.UnderlyingName, 'class') and
    (lIdentity.BaseTypeName = '') and (lIdentity.HelperTargetName = '');
  if lClosed then
    for lIdentity in lLineage.Items do
      if (not TrySafetyDeclarationModel(lIdentity, lOwnerModel)) or
        (not HasClosedRootSourceContext(lOwnerModel)) then
        lClosed := False;
  lIdentity := lLineage.Items[High(lLineage.Items)];
  try
    if fRootMemberAbsence.EvidenceFingerprint = '' then
      Exit;
    if lClosed then
    begin
      Result := fRootMemberAbsence.IsNameAbsent(aName);
      if Result then
        aRootProof.Kind := rapClosedSourceRoot;
    end else begin
      if (lNamed = nil) or (not TryRootProofUnits(aModel, True, lSiteUnits)) then
        Exit;
      // Validate every project declaration, but keep its imported helpers out
      // of the site scope. The root-most declaration captures its own helper.
      for i := High(lLineage.Items) downto 0 do
      begin
        lIdentity := lLineage.Items[i];
        if (not SameText(lIdentity.Kind, 'type')) or
          (not SameText(lIdentity.ScopeKind, 'unit')) or
          (not MatchText(lIdentity.SectionKind, ['interface', 'implementation'])) or
          (lIdentity.HelperTargetName <> '') or
          (not MatchText(lIdentity.UnderlyingName, ['class', 'interface'])) or
          (not TrySafetyDeclarationModel(lIdentity, lOwnerModel)) or
          (not ModelIsClosedForRootProof(lOwnerModel)) or
          (not RootHeadingIsNonGeneric(lIdentity, lOwnerModel)) then
          Exit;
        if not TryRootProofUnits(lOwnerModel,
          SameText(lIdentity.SectionKind, 'implementation'), lOwnerUnits) then
          Exit;
      end;
      lIdentity := lLineage.Items[High(lLineage.Items)];
      if not TrySafetyDeclarationModel(lIdentity, lOwnerModel) then
        Exit;
      lRoot := Default(TDelphiSemanticQualifiedRootType);
      lRoot.Kind := LowerCase(lIdentity.UnderlyingName);
      lRoot.TypeName := lIdentity.BaseTypeName;
      if lRoot.TypeName = '' then
      begin
        if lRoot.Kind = 'class' then
          lRoot.TypeName := 'System.TObject'
        else
          lRoot.TypeName := 'System.IInterface';
      end;
      // LookupUnits is the declaration-point scope, distinct from aSiteUnits.
      // Implementation imports follow interface imports only for an
      // implementation declaration, matching compiler helper precedence.
      if not TryRootProofUnits(lOwnerModel,
        SameText(lIdentity.SectionKind, 'implementation'), lRoot.LookupUnits) then
        Exit;
      Result := lNamed.IsNamedRootMemberAbsent(lRoot, lSiteUnits, aName);
      if Result then
      begin
        aRootProof.Kind := rapNamedSiteScopedRoot;
        aRootProof.SiteUnits := lSiteUnits;
      end;
    end;
    if Result then
      fLookupIndex.RecordRootMemberAbsence(aModel.UnitName, lIdentity.DeclaredId.Value, aName);
  except
    on E: Exception do
    begin
      // External evidence failure preserves the caller's unsupported diagnostic.
      Result := False;
      aRootProof := Default(TRootAbsenceProof);
    end;
  end;
end;

function TWithBindingProjectMemberIndex.ResolveSelectorMemberVerdict(
  const aModel: TDelphiSemanticUnitModel; const aSite: TReceiverLookupSite;
  const aSelector: TDelphiSemanticWithSelectorBinding; const aLineage: TDelphiSemanticLineage;
  const aCurrentTypeName, aName: string): TMemberVerdict;
var
  lContext: TDelphiSemanticMemberLookupContext;
  lIdentity, lLineageIdentity: TDelphiSemanticTypeIdentity;
  lLookup, lDirectLookup: TDelphiSemanticMemberLookupResult;
  lVerifiedOwner: Boolean;
  lVerdict, lDirect: TMemberVerdict;
begin
  lContext := Default(TDelphiSemanticMemberLookupContext);
  lContext.CallerUnitName := aModel.UnitName;
  lContext.CurrentTypeName := aCurrentTypeName;
  lContext.InstanceContext := True;
  lVerifiedOwner := False;
  lLookup := Default(TDelphiSemanticMemberLookupResult);
  lLookup.Status := 'unresolved';
  lLookup.ReasonCode := 'DIRECT_MEMBER_NOT_FOUND';
  for lLineageIdentity in aLineage.Items do
  begin
    if SameText(lLineageIdentity.Kind, 'type-alias') then
      Continue;
    lLookup := LookupIdentityMember(lContext, lLineageIdentity, aName,
      lLineageIdentity.DeclaredId.Value = aSelector.TypeIdentity.DeclaredId.Value, False);
    lVerdict := MemberVerdictFromLookup(aName, lLookup);
    if lVerdict.Outcome <> noAbsent then
      Break;
  end;
  if lLookup.Found and (not SameText(lLookup.Status, 'helper')) then
  begin
    lVerifiedOwner := False;
    for lIdentity in aLineage.Items do
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
    lVerdict := MemberVerdictFromLookup(aName, lLookup);
    if lVerifiedOwner and (lVerdict.Outcome = noResolved) then
    begin
      lDirect := lVerdict;
    end;
  end;
  lDirect := MemberVerdictFromLookup(aName, lLookup);
  if (lDirect.Outcome = noResolved) and not lVerifiedOwner then
    Exit(TMemberVerdict.Barrier(noUnproved, 'PARENT_SELECTOR_UNRESOLVED',
      'The parent member owner is outside the held lineage.', 'selector-eligibility'));
  lVerdict := ResolveReceiverMemberVerdict(aModel, aSite, aSelector, aSelector,
    aCurrentTypeName, aName, lDirect);
  if lVerdict.Outcome = noResolved then
  begin
    if (lDirect.Outcome <> noResolved) or lVerdict.MemberTypeOpen then
      Exit(TMemberVerdict.Barrier(noUnproved, 'PARENT_SELECTOR_UNRESOLVED',
        'The parent WITH member type is not verified.', 'members-open'));
    Exit(lVerdict);
  end;
  if lVerdict.Outcome <> noAbsent then
    Exit(TMemberVerdict.Barrier(lVerdict.Outcome, 'PARENT_SELECTOR_UNRESOLVED',
      'The parent WITH selector or its member cannot be proven.', lVerdict.Cause));
  for lLineageIdentity in aLineage.Items do
  begin
    lDirectLookup := fSemanticMemberIndex.ResolveDirectMemberByOwnerId(
      lLineageIdentity.DeclaredId, aName);
    if (not SameText(lDirectLookup.Status, 'unresolved')) or
      (not SameText(lDirectLookup.ReasonCode, 'DIRECT_MEMBER_NOT_FOUND')) then
      Exit(TMemberVerdict.Barrier(noUnproved, 'PARENT_SELECTOR_UNRESOLVED',
        'The parent WITH selector or its member cannot be proven.', 'selector-eligibility'));
  end;
  Result := TMemberVerdict.NotPresent;
end;

function TWithBindingProjectMemberIndex.TryResolveVerifiedSimpleMember(
  const aModel: TDelphiSemanticUnitModel;
  const aSite: TReceiverLookupSite;
  const aSelectors: TArray<TDelphiSemanticWithSelectorBinding>;
  const aCurrentTypeName, aMemberCachePrefix, aName: string;
  const aMemberCache: TDictionary<string, TMemberVerdict>;
  out aResult: TBoundMemberResolution): Boolean;
var
  i: Integer;
  lBinding: TDelphiSemanticWithBinding;
  lIdentity: TDelphiSemanticTypeIdentity;
  lKey: string;
  lLineage: TDelphiSemanticLineage;
  lOwner: TDelphiSemanticTypeLookupResult;
  lOwnerModel: TDelphiSemanticUnitModel;
  lVerdict: TMemberVerdict;
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
    lOwner := Default(TDelphiSemanticTypeLookupResult);
    lOwner.Found := fTypeIndex.FindByDeclaredId(lIdentity.DeclaredId, lOwner.Identity);
    lLineage := TryBuildMemberSafetyLineage(lBinding, aSelectors[i].TypeName,
        lIdentity);
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
      (not lLineage.Complete) then
      Exit(Blocked);
    lKey := aMemberCachePrefix + #31 + 'verified-simple' + #31 +
      IntToStr(i) + #31 + lIdentity.UnitName + #31 +
      lIdentity.DeclaredId.Value + #31 + lIdentity.CanonicalId.Value + #31 +
      lIdentity.SectionKind + #31 + lIdentity.SourceRange.FileName + #31 +
      IntToStr(lIdentity.SourceRange.Line) + #31 +
      IntToStr(lIdentity.SourceRange.Column) + #31 +
      IntToStr(lIdentity.SourceRange.EndLine) + #31 +
      IntToStr(lIdentity.SourceRange.EndColumn) + #31 + aName;
    if Assigned(aMemberCache) and aMemberCache.TryGetValue(lKey, lVerdict) then
    begin
      case lVerdict.Outcome of
        noResolved, noUnproved, noAmbiguous:
        begin
          aResult := lVerdict.AsBound(aName, i);
          Exit(True);
        end;
        noAbsent: ;
      end;
      Continue;
    end;
    lVerdict := ResolveSelectorMemberVerdict(aModel, aSite, aSelectors[i],
      lLineage, aCurrentTypeName, aName);
    if Assigned(aMemberCache) then
      aMemberCache.AddOrSetValue(lKey, lVerdict);
    if lVerdict.Outcome = noAbsent then
      Continue;
    aResult := lVerdict.AsBound(aName, i);
    Exit(True);
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
  lLineage: TDelphiSemanticLineage;
  lLineageComplete: Boolean;
begin
  Result := '';
  if Length(fMemberSafetyDiagnostics) = 0 then
    Exit;
  if Length(aBinding.Selectors) <> Length(aSelectorIdentities) then
    Exit('MEMBERS_INCOMPLETE');
  for i := 0 to High(aBinding.Selectors) do
  begin
    lLineage := TryBuildMemberSafetyLineage(aBinding,
      aBinding.Selectors[i].TypeName, aSelectorIdentities[i]);
    lLineageComplete := lLineage.Complete or SameText(lLineage.Cause, 'profile-terminal');
    if not lLineageComplete then
      Exit('MEMBERS_INCOMPLETE');
    for lFact in fMemberSafetyDiagnostics do
    begin
      for lIdentity in lLineage.Items do
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
begin
  Result := BindProject(aContextFingerprint, aGraph, aModels, aRootMemberAbsence, nil);
end;

class function TDelphiSemanticWithBinder.BindProject(const aContextFingerprint: string;
  const aGraph: TDelphiSemanticSemanticGraph;
  const aModels: TArray<TDelphiSemanticUnitModel>;
  const aRootMemberAbsence: IDelphiSemanticImplicitRootMemberAbsence;
  const aUnitNameWitness: IDelphiSemanticUnitNameWitness):
  TDelphiSemanticProjectWithBindingFacts;
var
  i: Integer;
  j: Integer;
  lBinding: TDelphiSemanticWithBinding;
  lBindingCapacity: Integer;
  lParentStatementIndexes: TArray<Integer>;
  lProofStatementIndex: Integer;
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
  lMemberCache: TDictionary<string, TMemberVerdict>;
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
  lSourceContext: TWithBindingSourceContext;
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
  lMemberCache := TDictionary<string, TMemberVerdict>.Create(
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
      Default(TDelphiSemanticRemoveWithLookupIndex), aUnitNameWitness);
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
    // Coverage must use the same project-scoped DeclaredIds as the bound selectors.
    Result.LookupIndex.AttachValueMemberEvidence(lProjectMemberIndex.ExportValueMemberEvidence);
    lProjectMemberIndex.fLookupIndex := Result.LookupIndex;
    for lModel in aModels do
    begin
      if Length(lModel.WithStatements) = 0 then
        Continue;
      lSourceContext := PrepareWithBindingSource(lModel);
      lActivityLineStarts := lSourceContext.LineStarts;
      lParentStatementIndexes := BuildParentStatementIndexes(lModel.WithStatements);
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
      lSelectorStacks := BuildSelectorStackCache(lModel, lSourceContext, aModels, lModel.WithStatements,
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
        SeparateInactiveSpanVerification(lModel, lSourceContext, lStatement, lBinding);
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
        if not lBinding.ActivityUnverified then
        begin
          // A child's qualification can use an inherited outer subject. Check
          // every covering header against all names that this binding rewrites.
          lProofStatementIndex := i;
          while lProofStatementIndex >= 0 do
          begin
            if InactiveSubjectMayShadow(lModel, lSourceContext, aModels,
              lModel.WithStatements[lProofStatementIndex], lBinding,
              lRoutineLookupName, lCurrentTypeName, lParentRoutineNames,
              lProjectMemberIndex, lMemberCache) then
            begin
              lBinding.SkipReason := 'INACTIVE_SUBJECT_SHADOWING';
              Break;
            end;
            lProofStatementIndex := lParentStatementIndexes[lProofStatementIndex];
          end;
          if (lBinding.SkipReason <> 'INACTIVE_SUBJECT_SHADOWING') and
            ContainsInactiveAsm(lModel, lStatement, lSourceContext) then
            lBinding.SkipReason := 'INACTIVE_ASM_BLOCK';
          if MatchText(lBinding.SkipReason, ['INACTIVE_SUBJECT_SHADOWING', 'INACTIVE_ASM_BLOCK']) then
            lBinding.Status := 'skipped';
        end;
        if ContainsInactiveNestedWith(lModel, lStatement, lSourceContext) then
          // The earlier inactive refusal has already been copied to SkipReason.
          // Replacing this persisted barrier cannot overwrite its precedence.
          // This late marker is independent of outer-owned references.
          lBinding.InactiveSpanSkipReason := 'INACTIVE_NESTED_WITH_SHADOW';
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
