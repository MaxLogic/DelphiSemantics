unit Test.WithBinder;

interface

uses
  DUnitX.TestFramework,
  DelphiSemantics.Api, DelphiSemantics.Api.RemoveWith,
  DelphiSemantics.Api.RemoveWith.Compatibility,
  DelphiSemantics.Model, DelphiSemantics.RootMemberAbsence, DelphiSemantics.WithBinding;

type
  [TestFixture]
  TWithBinderTests = class
  private
    function LoadModel: TDelphiSemanticUnitModel;
    function LoadBareReceiverSafetyModels: TArray<TDelphiSemanticUnitModel>;
    function LoadReceiverSafetyModels: TArray<TDelphiSemanticUnitModel>;
    function HasReference(const aBinding: TDelphiSemanticWithBinding; const aName,
      aClassification: string): Boolean;
    function HasAnyReference(const aBinding: TDelphiSemanticWithBinding; const aName: string):
      Boolean;
    function ReceiverOf(const aBinding: TDelphiSemanticWithBinding; const aName,
      aClassification: string): string;
    function CountReferences(const aBinding: TDelphiSemanticWithBinding; const aName: string):
      Integer;
    function LookupSourceOf(const aBinding: TDelphiSemanticWithBinding; const aName,
      aClassification: string): string;
    function ReasonOf(const aBinding: TDelphiSemanticWithBinding; const aName,
      aClassification: string): string;
    function HasInventorySymbol(const aInventory: TDelphiSemanticRemoveWithInventory;
      const aName, aSymbolClass, aRoutineName: string): Boolean;
    function TryFindInventorySymbol(const aInventory: TDelphiSemanticRemoveWithInventory;
      const aName, aSymbolClass, aOwnerName: string; out aSymbol:
      TDelphiSemanticInventorySymbol): Boolean;
  public
    [TestCase('Lost helper facts', 'lost')]
    [TestCase('Overload visibility sites', 'overloads')]
    [TestCase('Two routine visibility sites', 'routines')]
    procedure UnindexedHelperCacheAndLostFacts(const aMode: string);
    [Test]
    procedure UnindexedHelperColdWarmSnapshot;
    [TestCase('Null imported helper target', 'null-target')]
    [TestCase('Null imported helper fact', 'null')]
    [TestCase('Imported helper fact without target', 'missing-target')]
    [TestCase('Name JSON number', 'Name:number')]
    [TestCase('Name JSON bool', 'Name:bool')]
    [TestCase('Name JSON null', 'Name:null')]
    [TestCase('HelperKind JSON number', 'HelperKind:number')]
    [TestCase('HelperKind JSON bool', 'HelperKind:bool')]
    [TestCase('HelperKind JSON null', 'HelperKind:null')]
    [TestCase('TargetName JSON number', 'TargetName:number')]
    [TestCase('TargetName JSON bool', 'TargetName:bool')]
    [TestCase('TargetName JSON null', 'TargetName:null')]
    [TestCase('SectionKind JSON number', 'SectionKind:number')]
    [TestCase('SectionKind JSON bool', 'SectionKind:bool')]
    [TestCase('SectionKind JSON null', 'SectionKind:null')]
    [TestCase('ScopeKind JSON number', 'ScopeKind:number')]
    [TestCase('ScopeKind JSON bool', 'ScopeKind:bool')]
    [TestCase('ScopeKind JSON null', 'ScopeKind:null')]
    [TestCase('OwnerScopeId JSON number', 'OwnerScopeId:number')]
    [TestCase('OwnerScopeId JSON bool', 'OwnerScopeId:bool')]
    [TestCase('OwnerScopeId JSON null', 'OwnerScopeId:null')]
    [TestCase('FileName JSON number', 'FileName:number')]
    [TestCase('FileName JSON bool', 'FileName:bool')]
    [TestCase('FileName JSON null', 'FileName:null')]
    [TestCase('HelperKind unknown value', 'HelperKind:bogus')]
    [TestCase('SectionKind unknown value', 'SectionKind:bogus')]
    [TestCase('ScopeKind unknown value', 'ScopeKind:bogus')]
    procedure MalformedImportedHelperFactsFailClosed(const aMode: string);
    [TestCase('Empty writer helper kind', 'kind')]
    [TestCase('Empty writer helper target', 'target')]
    procedure UnindexedHelperWriterValuesRoundTrip(const aMode: string);
    [TestCase('Line coordinate string', 'Line:string')]
    [TestCase('Line coordinate float', 'Line:float')]
    [TestCase('Line coordinate null', 'Line:null')]
    [TestCase('Line coordinate missing', 'Line:missing')]
    [TestCase('Line coordinate bool', 'Line:bool')]
    [TestCase('Line coordinate array', 'Line:array')]
    [TestCase('Line coordinate object', 'Line:object')]
    [TestCase('Line coordinate negative', 'Line:negative')]
    [TestCase('Line coordinate overflow', 'Line:overflow')]
    [TestCase('Column coordinate string', 'Column:string')]
    [TestCase('Column coordinate float', 'Column:float')]
    [TestCase('Column coordinate null', 'Column:null')]
    [TestCase('Column coordinate missing', 'Column:missing')]
    [TestCase('Column coordinate bool', 'Column:bool')]
    [TestCase('Column coordinate array', 'Column:array')]
    [TestCase('Column coordinate object', 'Column:object')]
    [TestCase('Column coordinate negative', 'Column:negative')]
    [TestCase('Column coordinate overflow', 'Column:overflow')]
    procedure MalformedHelperCoordinatesFailClosed(const aMode: string);
    [TestCase('Writer coordinates position', 'position')]
    [TestCase('Writer coordinates zero', 'zero')]
    procedure HelperCoordinatesWriterRoundTrip(const aMode: string);
    [TestCase('Duplicate unit site models', 'forward')]
    [TestCase('Reversed duplicate unit site models', 'reverse')]
    procedure UnindexedHelperCacheSeparatesSiteModels(const aOrder: string);
    [TestCase('Root helper after include and site', 'after')]
    [TestCase('Root helper before site after include', 'before')]
    [TestCase('Helper inside include', 'included')]
    procedure UnindexedHelperIncludeOrigins(const aMode: string);
    [TestCase('unrelated', 'unrelated')]
    [TestCase('same-name', 'same-name')]
    [TestCase('private-import', 'private-import')]
    [TestCase('after-site', 'after-site')]
    [TestCase('class-helper', 'class-helper')]
    [TestCase('indexed-import', 'indexed-import')]
    [TestCase('import', 'import')]
    [TestCase('call', 'call')]
    [TestCase('alias-target', 'alias-target')]
    [TestCase('alias-receiver', 'alias-receiver')]
    [TestCase('local-alias', 'local-alias')]
    [TestCase('nested', 'nested')]
    [TestCase('intrinsic', 'intrinsic')]
    [TestCase('local-array', 'local-array')]
    [TestCase('no-helper', 'no-helper')]
    procedure UnindexedRecordHelperRequiresVisibleMatchingIdentity(const aShape: string);
    [TestCase('Imported routine homonym', 'cross')]
    [TestCase('Same unit routine homonym', 'direct')]
    procedure RoutineTypeHomonymCannotSupplyReceiverMember(const aShape: string);
    [TestCase('Operator local is an identifier', 'local')]
    [TestCase('Operator field is an identifier', 'field')]
    procedure OperatorIdentifierDoesNotHideDeclarations(const aShape: string);
    [TestCase('Exact reviewer plain alias', 'alias-plain')]
    [TestCase('Exact reviewer pointer alias', 'alias-ptr')]
    [TestCase('Inherited indexed homonym', 'inherited-index')]
    [TestCase('Inherited pointer homonym', 'inherited-pointer')]
    [TestCase('Alias indexed homonym', 'alias-index')]
    [TestCase('Alias pointer homonym', 'alias-pointer')]
    procedure VerifiedCrossUnitReceiverKeepsMember(const aShape: string);
    [TestCase('Selected unknown member', 'selected-unknown')]
    [TestCase('Selected unknown selector path', 'selector-selected')]
    [TestCase('Context index foreign owner', 'context-borrow')]
    [TestCase('Lexical homonym retains lexical binding', 'homonym-lexical')]
    [TestCase('Unit constant cannot borrow a foreign receiver member', 'homonym-constant')]
    [TestCase('Routine-local unknown member', 'local-type')]
    [TestCase('Unknown lexical without homonym stays planned', 'lexical-unknown-no-homonym')]
    [TestCase('Known-inactive miss keeps ordinary candidate', 'known-inactive-member')]
    procedure ReceiverOwnerIdentityAndMemberActivity(const aShape: string);
    [Test]
    procedure FieldSelectorsRetainTheirDeclaredKinds;
    [Test]
    [TestCase('Complete source import', 'complete,resolved')]
    [TestCase('Unknown source import', 'missing,unsupported')]
    [TestCase('Ambiguous source import', 'ambiguous,unsupported')]
    [TestCase('Imported helper', 'helper,unsupported')]
    [TestCase('Escaped helper name', 'helper-escaped-name,unsupported')]
    [TestCase('Omitted empty helper declaration', 'helper-unindexed-empty,unsupported')]
    [TestCase('Verified record helper', 'record-helper,resolved')]
    [TestCase('Routine-local record target homonym', 'record-helper-local,unsupported')]
    [TestCase('Record alias target stays conservative', 'record-helper-alias,unsupported')]
    [TestCase('Unresolved record helper target', 'record-helper-missing,unsupported')]
    [TestCase('Unverified helper kind', 'helper-unverified,unsupported')]
    [TestCase('Class helper with missing heuristic target', 'helper-empty-target,unsupported')]
    [TestCase('Failed imported source', 'failed,unsupported')]
    [TestCase('Interface-only import', 'interface-only,unsupported')]
    [TestCase('Mismatched rejection count', 'rejected,unsupported')]
    [TestCase('Verified unit routine omissions', 'routine-complete,resolved')]
    [TestCase('Unverified routine signature', 'routine-unverified,unsupported')]
    [TestCase('Wrong routine source position', 'routine-position,unsupported')]
    [TestCase('Nested routine ownership', 'routine-parent,unsupported')]
    [TestCase('Wrong declaration source', 'routine-declaration-file,unsupported')]
    [TestCase('Wrong declaration scope', 'routine-declaration-scope,unsupported')]
    [TestCase('Wrong declaration owner', 'routine-declaration-owner,unsupported')]
    [TestCase('Wrong declaration owner scope', 'routine-declaration-owner-scope,unsupported')]
    procedure RootAbsenceRequiresClosedImportedSource(const aBarrier, aExpectedStatus: string);

    [Test]
    [TestCase('Missing root evidence', 'missing,lPair,unsupported')]
    [TestCase('Exact absence evidence', 'accepted,lPair,resolved')]
    [TestCase('Root member refusal', 'refused,ClassName,unsupported')]
    procedure SimpleSelectorFallthroughRequiresExactRootAbsence(
      const aMode, aName, aExpectedStatus: string);

    [Test]
    [TestCase('MissingProvider', 'missing')]
    [TestCase('ImportedUnit', 'import')]
    [TestCase('ReachableHelper', 'helper')]
    [TestCase('UnknownAncestor', 'ancestor')]
    [TestCase('FailedModel', 'failed')]
    [TestCase('InterfaceOnly', 'interface-only')]
    [TestCase('RejectedDeclaration', 'rejected')]
    [TestCase('SystemOrigin', 'system')]
    procedure OptionalRootAbsenceKeepsUnverifiedContextsBlocked(const aBarrier: string);
    [Test]
    procedure OptionalRootAbsenceFlowsThroughApiAndBypassesPersistentFacts;
    [TestCase('Public remove-with plan', 'plan')]
    [TestCase('Public project load', 'project')]
    [TestCase('Public project session', 'session')]
    procedure PublicProviderFingerprintFailureRefuses(const aPath: string);
    [TestCase('Conditional ancestor declaration homonym', 'ancestor-declaration')]
    [TestCase('Declared receiver borrows foreign member', 'declared-receiver')]
    [TestCase('Unknown declaration in active WITH', 'declaration')]
    [TestCase('Unknown selected field', 'selected-field')]
    [TestCase('Unknown global', 'global')]
    [TestCase('Unknown local', 'local')]
    [TestCase('Unknown selector member', 'selector')]
    [TestCase('Unknown nested statement blocks parent', 'nested')]
    [TestCase('Known-active declaration control', 'active')]
    [TestCase('Known-false declaration is absent', 'inactive')]
    [TestCase('Unknown inner activity skips parent', 'activity-nested')]
    [TestCase('Mixed unknown WITH', 'mixed')]
    [TestCase('Missing unknown include WITH', 'missing')]
    [TestCase('Unmodeled directive WITH', 'directive')]
    procedure UnknownActivityCannotAuthorizeRemoveWith(const aShape: string);
    [TestCase('Hidden IF ELSE nested WITH', 'hidden-if')]
    [TestCase('Hidden Declared nested WITH', 'hidden-declared')]
    [TestCase('Malformed IFDEF nested WITH', 'hidden-malformed')]
    [TestCase('Uncaptured LINUX nested WITH', 'hidden-linux')]
    [TestCase('Missing include inside WITH', 'hidden-missing')]
    [TestCase('Include only inside unknown WITH', 'hidden-include')]
    [TestCase('Unknown selector text', 'selector-text')]
    [TestCase('Global taint invalidates earlier UNDEF', 'taint')]
    [TestCase('Conditional ancestor control receiver', 'ancestor-control')]
    [TestCase('Unresolved reason wins activity', 'binder-unresolved')]
    [TestCase('Plannable scoped body is activity-unverified', 'binder-scoped')]
    procedure WholeWithSourceActivityIsRequired(const aShape: string);

    [TestCase('Known-inactive homonym preserves base replacement', 'known')]
    [TestCase('Unknown homonym refuses whole statement', 'unknown')]
    procedure WholeWithRangeRefusesOnlyUnknownActivity(const aShape: string);

    [TestCase('Overload', 'overload')]
    [TestCase('Indexed inherited field', 'indexed')]
    [TestCase('Dereferenced inherited field', 'pointer')]
    procedure RootAbsenceNeverOverridesIndexedLineage(const aShape: string);
    [TestCase('Indexed local class', 'indexed')]
    [TestCase('Dereferenced local class', 'pointer')]
    procedure LocalLineageNeverBorrowsUnitTypeIdentity(const aShape: string);
    [TestCase('Fingerprint failure', 'fingerprint')]
    [TestCase('Absence failure', 'absence')]
    procedure RootAbsenceProviderFailureKeepsBindingUnsupported(const aMode: string);
    [TestCase('Record', 'record')]
    [TestCase('Indexed record', 'indexed')]
    [TestCase('Dereferenced record', 'pointer')]
    [TestCase('Unindexed imported helper coverage', 'import')]
    procedure UnindexedRecordHelperShieldsLexicalHomonym(const aShape: string);
    [TestCase('Ord', 'Ord')]
    [TestCase('SizeOf', 'SizeOf')]
    procedure CompilerRoutineInWithBodyUsesIntrinsicFallback(const aName: string);
    [TestCase('Member', 'member')]
    [TestCase('Lexical', 'lexical')]
    [TestCase('Unknown', 'unknown')]
    procedure IntrinsicFallbackPreservesNamePrecedenceAndUnknownRefusal(const aShape: string);
    [TestCase('Pointer', 'pointer')]
    [TestCase('Homonym', 'homonym')]
    [TestCase('Range', 'range')]
    [TestCase('UnknownBase', 'unknown')]
    procedure QualifiedPointerFieldNeverBindsToWithHomonym(const aShape: string);
    [TestCase('Inactive', 'false')]
    [TestCase('Active', 'true')]
    procedure ConditionalWithBodyOnlyBindsActiveReferences(const aActive: Boolean);
    [Test]
    procedure ResolvesSelectorTypesAndClassifiesBodyIdentifiers;
    [Test]
    procedure BindingsExposeSourceRangesForDakPlanner;
    [Test]
    procedure MultipleSelectorsPreferInnermostReceiver;
    [Test]
    procedure AmbiguousReceiverMembersClassifyAsAmbiguous;
    [Test]
    procedure ClassMethodWithBindingUsesOwnedRoutineTypeForInheritedProtectedMembers;
    [Test]
    procedure InheritedHomonymProjectionsKeepTheirAccessDeclaration;
    [Test]
    procedure OneLineTypeDeclarationsDoNotOpenMemberBodies;
    [Test]
    procedure IndexedPropertySelectorWithoutDereferenceStaysUnsupported;
    [Test]
    procedure MemberReferenceReportsRoutineScopeConflict;
    [Test]
    procedure UnresolvedSelectorMarksBodyReferencesExternal;
    [Test]
    procedure UnresolvedReceiverShieldsOuterAndLexicalHomonyms;
    [Test]
    procedure NestedWithStatementsUseOuterReceiverStack;
    [Test]
    procedure NestedRoutineWithUsesParentRoutineScope;
    [Test]
    procedure SiblingRoutineLocalsDoNotLeakIntoNestedWith;
    [Test]
    procedure PlanningMetadataCountsLookupSourcesAndReasons;
    [Test]
    procedure ScopedDeclarationsMarkBindingSkipped;
    [Test]
    procedure ControlCharacterLiteralsAreIgnored;
    [Test]
    procedure SafeBindingsArePlannedDirectReferences;
    [Test]
    procedure SkipReasonsCoverExternalAndUnresolvedBranches;
    [Test]
    procedure CastExpressionRolesRemainUnsupported;
    [Test]
    procedure InventoryExposesFileAwareSymbolsAndBindings;
    [Test]
    procedure InventoryExposesDakPlannerSourceModelFacts;
    [Test]
    procedure InventoryExpansionUsesIndexedOwnMemberLookup;
    [Test]
    procedure InventoryExpansionUsesStableRelatedMemberOwnerIndex;
    [Test]
    procedure InventoryExpansionIndexesCurrentClassProjectionContexts;
    [Test]
    procedure InventoryExpansionScopesCurrentClassProjectionByUnit;
    [Test]
    procedure ReferenceScannerPreservesRepresentativeTokenShapes;
    [Test]
    procedure ReferenceBindingUsesManualIdentifierScanner;
    [Test]
    procedure InventoryExpansionUsesOrdinalIgnoreCaseSymbolKeys;
    [Test]
    procedure InventoryExpansionDeduplicatesSymbolsCaseInsensitively;
    [Test]
    procedure AnonymousNestedRecordSelectorsUseSyntheticOwner;
    [Test]
    procedure GlobalAnonymousRecordSelectorUsesSyntheticOwner;
    [Test]
    procedure DefaultIndexedPropertyPointerSelectorDereferencesToRecord;
    [Test]
    procedure NestedParentDefaultIndexedPropertyPointerSelectorDereferencesToRecord;
    [Test]
    procedure NestedParentIndexedSelectorPreservesPrecedenceAndSafety;
    [Test]
    procedure NestedUnresolvedSelectorRefusesFinalRewrite;
    [Test]
    procedure NestedIndexedSelectorPreservesBoundTypeDeclaringUnit;
    [Test]
    procedure HiddenCompleteReceiverIgnoresUnrelatedDiagnostics;
    [Test]
    procedure AmbiguousFinalReceiverTypeFailsClosed;
    [Test]
    procedure HiddenReceiverExactOwnerDiagnosticsRefuse;
    [Test]
    procedure BareImportedReceiverUsesActualOwnerForSafety;
    [Test]
    procedure BareImportedReceiverWithoutVisibleOwnerIsRefused;
    [Test]
    procedure NestedLocalReceiverKeepsSourceScopeAndIdentity;
    [Test]
    procedure LocalPointerPointeeShadowsImportedUnitHomonym;
    [Test]
    procedure PointerAliasesResolvePointeesFromTheirDeclarationScopes;
    [Test]
    procedure RoutineLocalHomonymMembersUseTheirOwnDeclaration;
    [Test]
    procedure RoutineLocalInheritedMembersNeverBindElsewhere;
    [TestCase('UnitRecord', 'UnitRecord')]
    [TestCase('LocalRecord', 'LocalRecord')]
    [TestCase('UnitClass', 'UnitClass')]
    [TestCase('StrictPrivate', 'StrictPrivate')]
    [TestCase('UnfinalizableAlias', 'Unknown')]
    procedure FinalizedLocalAliasesUseTargetMemberIdentities(const aTargetKind: string);
    [TestCase('StrictPrivate', 'strict private')]
    [TestCase('Private', 'private')]
    [TestCase('StrictProtected', 'strict protected')]
    [TestCase('Protected', 'protected')]
    procedure LocalAliasVisibilityUsesCallerUnitIdentity(const aVisibility: string);
    [TestCase('UnindexedList', 'TStringList')]
    [TestCase('UnindexedRoot', 'TObject')]
    [TestCase('UnresolvedBase', 'TUnknownBase')]
    [TestCase('CompleteRecord', 'record')]
    procedure UnitReceiverWithUnindexedAncestorNeverBindsElsewhere(const aBaseTypeName: string);
    [Test]
    procedure MalformedPointerAliasOwnersAndAmbiguousPointeesAreRefused;
    [Test]
    procedure SelectorIdentityUsesTheDeclaringUnitScope;
    [Test]
    procedure ParameterTypesResolveInTheEnclosingScope;
  end;

implementation

uses
  System.IOUtils, System.JSON, System.StrUtils, System.SysUtils,
  Winapi.Windows,
  FireDAC.Comp.Client, FireDAC.Phys.SQLite,
  AutoFree, maxLogic.IOUtils,
  DelphiSemantics.Api.ProjectOptions, DelphiSemantics.Cache, DelphiSemantics.Model.Json,
  DelphiSemantics.ProjectContext, DelphiSemantics.ProjectSession, DelphiSemantics.RemoveWithPlan,
  DelphiSemantics.Snapshot,
  DelphiSemantics.Snapshot.Cache.Sqlite, Test.Support;

var
  GWithBinderTempRoot: string;

function WithBinderTempPath(const aName: string): string;
var
  lGuid: TGUID;
  lGuidText: string;
begin
  if GWithBinderTempRoot = '' then
  begin
    CreateGUID(lGuid);
    lGuidText := StringReplace(StringReplace(GUIDToString(lGuid), '{', '', [rfReplaceAll]), '}',
      '', [rfReplaceAll]);
    GWithBinderTempRoot := TPath.GetFullPath(CombinePath([ExtractFilePath(ParamStr(0)),
      'with-binder-temp', 'run-' + GetCurrentProcessId.ToString + '-' + lGuidText]));
  end;
  TDirectory.CreateDirectory(GWithBinderTempRoot);
  Result := TPath.Combine(GWithBinderTempRoot, aName);
end;

type
  TImplicitRootAbsenceStub = class(TInterfacedObject, IDelphiSemanticImplicitRootMemberAbsence)
  public
    function EvidenceFingerprint: string;
    function IsNameAbsent(const aName: string): Boolean;
  end;

type
  // Provider failures are an external callback boundary exercised deliberately.
  TThrowingRootAbsenceProvider = class(TInterfacedObject, IDelphiSemanticImplicitRootMemberAbsence)
  private
    fMode: string;
  public
    constructor Create(const aMode: string);
    function EvidenceFingerprint: string;
    function IsNameAbsent(const aName: string): Boolean;
  end;

constructor TThrowingRootAbsenceProvider.Create(const aMode: string);
begin
  inherited Create;
  fMode := aMode;
end;

function TThrowingRootAbsenceProvider.EvidenceFingerprint: string;
begin
  if fMode = 'fingerprint' then
    raise Exception.Create('Fingerprint unavailable');
  Result := 'review-throwing-provider';
end;

function TThrowingRootAbsenceProvider.IsNameAbsent(const aName: string): Boolean;
begin
  raise Exception.Create('Absence unavailable for ' + aName);
end;

function TImplicitRootAbsenceStub.EvidenceFingerprint: string;
begin
  Result := 'ds712-lPair-LeftOnly-lNearest-stub';
end;

function TImplicitRootAbsenceStub.IsNameAbsent(const aName: string): Boolean;
begin
  Result := SameText(aName, 'lPair') or SameText(aName, 'LeftOnly') or
    SameText(aName, 'lNearest');
end;

procedure TWithBinderTests.SimpleSelectorFallthroughRequiresExactRootAbsence(
  const aMode, aName, aExpectedStatus: string);
var
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lGuid: TGUID;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lProvider: IDelphiSemanticImplicitRootMemberAbsence;
  lRoot: string;
  lText: string;
begin
  CreateGUID(lGuid);
  lRoot := CombinePath([RepoRoot, 'tests', '.dak', 'delphiSemanticsTests',
    'ds712-simple-' + GUIDToString(lGuid)]);
  TDirectory.CreateDirectory(lRoot);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.ProjectContextApplied := True;
  lOptions.SourceFileName := TPath.Combine(lRoot, 'SimpleSelectors.pas');
  lText := 'unit SimpleSelectors;' + #13#10 +
    'interface' + #13#10 +
    'type' + #13#10 +
    '  TLeft = class' + #13#10 +
    '  public' + #13#10 +
    '    LeftOnly: Integer;' + #13#10 +
    '  end;' + #13#10 +
    '  TRight = record' + #13#10 +
    '    RightOnly: Integer;' + #13#10 +
    '  end;' + #13#10 +
    '  TOwner = class' + #13#10 +
    '  public' + #13#10 +
    '    class procedure Run;' + #13#10 +
    '  end;' + #13#10 +
    'implementation' + #13#10 +
    'class procedure TOwner.Run;' + #13#10 +
    'var' + #13#10 +
    '  lLeft: TLeft;' + #13#10 +
    '  ' + aName + ': TRight;' + #13#10 +
    'begin' + #13#10 +
    '  with lLeft, ' + aName + ' do RightOnly := 1;' + #13#10 +
    'end;' + #13#10 +
    'end.' + #13#10;
  TFile.WriteAllText(lOptions.SourceFileName, lText, TEncoding.ASCII);
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  TFile.WriteAllText(TPath.Combine(lRoot, 'model.json'), ModelToJson(lModel), TEncoding.UTF8);
  Assert.IsTrue(lModel.Success, 'The selector control requires a real complete source model.');
  Assert.AreEqual(0, lModel.RejectedDeclarationCount, 'The positive control must have no rejected declarations.');
  if aMode <> 'missing' then
    lProvider := TImplicitRootAbsenceStub.Create;
  lFacts := TDelphiSemanticWithBinder.BindProject('simple-selector-root-' + aMode,
    nil, [lModel], lProvider);
  Assert.AreEqual(1, Integer(Length(lFacts.Bindings)));
  Assert.AreEqual(2, Integer(Length(lFacts.Bindings[0].Selectors)));
  Assert.AreEqual(aExpectedStatus, lFacts.Bindings[0].Selectors[1].Status);
  if aExpectedStatus = 'resolved' then
    Assert.AreEqual('TRight', lFacts.Bindings[0].Selectors[1].TypeName);
end;

procedure TWithBinderTests.RootAbsenceRequiresClosedImportedSource(
  const aBarrier, aExpectedStatus: string);
var
  i: Integer;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lDiagnostic: TDelphiSemanticModelDiagnostic;
  lGuid: TGUID;
  lHelperDiagnosticCount: Integer;
  lModel: TDelphiSemanticUnitModel;
  lModels: TArray<TDelphiSemanticUnitModel>;
  lOptions: TDelphiSemanticModelOptions;
  lProvider: IDelphiSemanticImplicitRootMemberAbsence;
  lRoot: string;
  lSupport: TDelphiSemanticUnitModel;
  lText: string;
begin
  CreateGUID(lGuid);
  lRoot := CombinePath([RepoRoot, 'tests', '.dak', 'delphiSemanticsTests',
    'ds715-closure-' + GUIDToString(lGuid)]);
  TDirectory.CreateDirectory(lRoot);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.ProjectContextApplied := True;
  lOptions.SourceFileName := TPath.Combine(lRoot, 'MultipleSelectorUnit.pas');
  lText := TFile.ReadAllText(TPath.GetFullPath(TPath.Combine(RepoRoot,
    '..\DelphiAiKit\tests\fixtures\RemoveWithMultipleSelectorRewriteFixture\MultipleSelectorUnit.pas')));
  lText := StringReplace(lText, 'interface', 'interface' + #13#10 + 'uses ClosureSupport;', []);
  TFile.WriteAllText(lOptions.SourceFileName, lText, TEncoding.UTF8);
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);
  Assert.AreEqual(0, lModel.RejectedDeclarationCount);
  lOptions.SourceFileName := TPath.Combine(lRoot, 'ClosureSupport.pas');
  lText := 'unit ClosureSupport;' + #13#10 + 'interface' + #13#10 +
    'type' + #13#10 + '  TMarker = record' + #13#10 + '    Number: Integer;' + #13#10 +
    '  end;' + #13#10;
  if StartsText('helper', aBarrier) then
    lText := lText + '  TObjectExtraHelper = class helper for TObject' + #13#10 +
      '    procedure Extra;' + #13#10 + '  end;' + #13#10;
  if StartsText('record-helper', aBarrier) then
  begin
    if aBarrier = 'record-helper-alias' then
      lText := lText + '  TAlias = TMarker;' + #13#10;
    if aBarrier = 'record-helper-local' then
      lText := lText + '  TMarkerHelper = record helper for LocalMarker' + #13#10
    else if aBarrier = 'record-helper-alias' then
      lText := lText + '  TMarkerHelper = record helper for TAlias' + #13#10
    else
      lText := lText + '  TMarkerHelper = record helper for TMarker' + #13#10;
    lText := lText + '    procedure Extra;' + #13#10 + '  end;' + #13#10;
  end;
  if StartsText('routine-', aBarrier) then
    lText := lText + 'procedure SupportRoutine;' + #13#10;
  lText := lText + 'implementation' + #13#10;
  if StartsText('helper', aBarrier) then
    lText := lText + 'procedure TObjectExtraHelper.Extra; begin end;' + #13#10;
  if StartsText('record-helper', aBarrier) then
    lText := lText + 'procedure TMarkerHelper.Extra; begin end;' + #13#10;
  if StartsText('routine-', aBarrier) then
    lText := lText + 'procedure SupportRoutine; begin end;' + #13#10;
  if aBarrier = 'record-helper-local' then
    lText := lText + 'procedure LocalScope;' + #13#10 +
      'type LocalMarker = record Value: Integer; end;' + #13#10 +
      'begin end;' + #13#10;
  lText := lText + 'end.' + #13#10;
  if aBarrier = 'helper-escaped-name' then
    lText := StringReplace(lText, 'TObjectExtraHelper', '&type', [rfReplaceAll]);
  if aBarrier = 'helper-unindexed-empty' then
    lText := 'unit ClosureSupport; interface type &type = class helper for TObject end; implementation end.';
  TFile.WriteAllText(lOptions.SourceFileName, lText, TEncoding.ASCII);
  lSupport := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lSupport.Success);
  if MatchText(aBarrier, ['helper-escaped-name', 'helper-unindexed-empty']) then
  begin
    TFile.WriteAllText(TPath.Combine(lRoot, 'support-model.json'),
      ModelToJson(lSupport), TEncoding.UTF8);
    Assert.AreEqual('ast', lSupport.ScopeModelStatus);
    if aBarrier = 'helper-escaped-name' then
      // Our line scanner also rejects Extra under the escaped helper owner.
      Assert.AreEqual(2, lSupport.RejectedDeclarationCount)
    else
      Assert.AreEqual(1, lSupport.RejectedDeclarationCount);
    lHelperDiagnosticCount := 0;
    for lDiagnostic in lSupport.Diagnostics do
      if lDiagnostic.Code = 'AST_HELPER_DECLARATION_UNINDEXED' then
      begin
        Inc(lHelperDiagnosticCount);
        Assert.IsTrue(ContainsText(lDiagnostic.Message, 'column'));
      end;
    Assert.AreEqual(1, lHelperDiagnosticCount);
  end;
  if aBarrier = 'record-helper' then
    Assert.AreEqual(0, lSupport.RejectedDeclarationCount);
  for i := 0 to High(lSupport.Declarations) do
  begin
    if SameText(lSupport.Declarations[i].Name, 'TObjectExtraHelper') then
    begin
      if aBarrier = 'helper-unverified' then
        lSupport.Declarations[i].AstHelperKind := '';
      if MatchText(aBarrier, ['helper-unverified', 'helper-empty-target']) then
        lSupport.Declarations[i].HelperTargetName := '';
    end;
    if (aBarrier = 'record-helper-missing') and
      SameText(lSupport.Declarations[i].Name, 'TMarkerHelper') then
      lSupport.Declarations[i].HelperTargetName := 'MissingRecord';
  end;
  if aBarrier = 'failed' then
    lSupport.Success := False
  else if aBarrier = 'interface-only' then
    lSupport.ScopeModelStatus := 'ast-interface-only'
  else if aBarrier = 'rejected' then
    lSupport.RejectedDeclarationCount := 1;
  if StartsText('routine-', aBarrier) then
  begin
    Assert.IsTrue(lSupport.RejectedDeclarationCount > 0);
    Assert.IsTrue(Length(lSupport.Routines) > 0);
    Assert.IsTrue(lSupport.Routines[0].AstSourceSignatureVerified);
    if aBarrier = 'routine-unverified' then
      lSupport.Routines[0].AstSourceSignatureVerified := False
    else if aBarrier = 'routine-position' then
      Inc(lSupport.Routines[0].Line)
    else if aBarrier = 'routine-parent' then
      lSupport.Routines[0].ParentScopeId := 'unverified-parent';
    for i := 0 to High(lSupport.Declarations) do
      if SameText(lSupport.Declarations[i].Kind, 'routine') and
        SameText(lSupport.Declarations[i].DeclarationRole, 'invalid') then
      begin
        if aBarrier = 'routine-declaration-file' then
          lSupport.Declarations[i].FileName := TPath.Combine(lRoot, 'DifferentInclude.inc')
        else if aBarrier = 'routine-declaration-scope' then
          lSupport.Declarations[i].ScopeKind := 'routine'
        else if aBarrier = 'routine-declaration-owner' then
          lSupport.Declarations[i].OwnerName := 'DifferentOwner'
        else if aBarrier = 'routine-declaration-owner-scope' then
          lSupport.Declarations[i].OwnerScopeId := 'different-owner-scope';
      end;
  end;
  lModels := [lModel, lSupport];
  if aBarrier = 'missing' then
    lModels := [lModel]
  else if aBarrier = 'ambiguous' then
    lModels := [lModel, lSupport, lSupport];
  lProvider := TImplicitRootAbsenceStub.Create;
  lFacts := TDelphiSemanticWithBinder.BindProject('closed-source-root-' + aBarrier,
    nil, lModels, lProvider);
  Assert.AreEqual(2, Integer(Length(lFacts.Bindings)));
  Assert.AreEqual(2, Integer(Length(lFacts.Bindings[0].Selectors)));
  Assert.AreEqual(aExpectedStatus, lFacts.Bindings[0].Selectors[1].Status);
  // Keep the source-backed field declaration proof independent of the import result.
  for i := 0 to High(lModel.Members) do
    if SameText(lModel.Members[i].Name, 'fLeft') then
      Assert.AreEqual('field', lModel.Members[i].Kind);
end;

procedure TWithBinderTests.FieldSelectorsRetainTheirDeclaredKinds;
var
  lBinding: TDelphiSemanticWithBinding;
  lDiagnostics: string;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lFieldCount: Integer;
  lGuid: TGUID;
  lMember: TDelphiSemanticMember;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lRoot: string;
  lRootMemberAbsence: IDelphiSemanticImplicitRootMemberAbsence;
  lSelector: TDelphiSemanticWithSelectorBinding;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.ProjectContextApplied := True;
  lOptions.SourceFileName := TPath.GetFullPath(TPath.Combine(RepoRoot,
    '..\DelphiAiKit\tests\fixtures\RemoveWithMultipleSelectorRewriteFixture\MultipleSelectorUnit.pas'));
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);
  CreateGUID(lGuid);
  lRoot := TPath.Combine(RepoRoot, 'tests\.dak\delphiSemanticsTests\ds712-field-' +
    GUIDToString(lGuid));
  TDirectory.CreateDirectory(lRoot);
  TFile.WriteAllText(TPath.Combine(lRoot, 'model.json'), ModelToJson(lModel), TEncoding.UTF8);
  lRootMemberAbsence := TImplicitRootAbsenceStub.Create;
  lFacts := TDelphiSemanticWithBinder.BindProject('field-selector-regression', nil, [lModel],
    lRootMemberAbsence);
  lDiagnostics := '';
  for lBinding in lFacts.Bindings do
    for lSelector in lBinding.Selectors do
      lDiagnostics := lDiagnostics + lBinding.RoutineName + ': ' + lSelector.SelectorText +
        ': ' + lSelector.Status + ':' + lSelector.TypeName + ':' + lSelector.ReasonCode + #13#10;
  TFile.WriteAllText(TPath.Combine(lRoot, 'selectors.txt'), lDiagnostics, TEncoding.UTF8);
  lFieldCount := 0;
  for lMember in lModel.Members do
    if SameText(lMember.OwnerName, 'TMultiPair') and
      (SameText(lMember.Name, 'fLeft') or SameText(lMember.Name, 'fRight')) then
    begin
      Inc(lFieldCount);
      Assert.AreEqual('field', lMember.Kind, lMember.Name);
      Assert.AreNotEqual('', lMember.TypeName, lMember.Name);
    end;
  Assert.AreEqual(2, lFieldCount);
  Assert.AreEqual(2, Integer(Length(lFacts.Bindings)));
  Assert.AreEqual(2, Integer(Length(lFacts.Bindings[0].Selectors)));
  Assert.AreEqual('lPair.fLeft', lFacts.Bindings[0].Selectors[0].SelectorText);
  Assert.AreEqual('resolved', lFacts.Bindings[0].Selectors[0].Status, lDiagnostics);
  Assert.AreEqual('TMultiLeft', lFacts.Bindings[0].Selectors[0].TypeName);
  Assert.AreEqual('lPair.fRight', lFacts.Bindings[0].Selectors[1].SelectorText);
  Assert.AreEqual('resolved', lFacts.Bindings[0].Selectors[1].Status, lDiagnostics);
  Assert.AreEqual('TMultiRight', lFacts.Bindings[0].Selectors[1].TypeName);
  Assert.IsTrue(HasReference(lFacts.Bindings[0], 'Code1', 'member'), lDiagnostics);
  Assert.IsTrue(HasReference(lFacts.Bindings[0], 'RightOnly', 'member'), lDiagnostics);
  Assert.IsTrue(HasReference(lFacts.Bindings[0], 'LeftOnly', 'member'));
  Assert.AreEqual('TMultiLeft', ReceiverOf(lFacts.Bindings[0], 'LeftOnly', 'member'));
end;

procedure TWithBinderTests.OptionalRootAbsenceKeepsUnverifiedContextsBlocked(const aBarrier: string);
var
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lProvider: IDelphiSemanticImplicitRootMemberAbsence;
  lText: string;
begin
  lText := TFile.ReadAllText(TPath.GetFullPath(TPath.Combine(RepoRoot,
    '..\DelphiAiKit\tests\fixtures\RemoveWithMultipleSelectorRewriteFixture\MultipleSelectorUnit.pas')),
    TEncoding.UTF8);
  if aBarrier = 'import' then
    lText := StringReplace(lText, 'interface', 'interface' + #13#10 + 'uses System;', [])
  else if aBarrier = 'helper' then
    lText := StringReplace(lText, 'implementation',
      'type TExtraHelper = class helper for TMultiLeft' + #13#10 +
      'procedure Extra;' + #13#10 + 'end;' + #13#10 +
      'implementation' + #13#10 + 'procedure TExtraHelper.Extra; begin end;', [])
  else if aBarrier = 'ancestor' then
    lText := StringReplace(lText, 'TMultiLeft = class', 'TMultiLeft = class(TUnindexed)', [])
  else if aBarrier = 'system' then
    lText := StringReplace(lText, 'unit MultipleSelectorUnit;', 'unit System;', []);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.ProjectContextApplied := True;
  lOptions.SourceFileName := WithBinderTempPath('RootAbsence-' + aBarrier + '.pas');
  TFile.WriteAllText(lOptions.SourceFileName, lText, TEncoding.UTF8);
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success, 'The control must start with a source-extracted model.');
  if aBarrier = 'failed' then
    lModel.Success := False
  else if aBarrier = 'interface-only' then
    lModel.ScopeModelStatus := 'ast-interface-only'
  else if aBarrier = 'rejected' then
    lModel.RejectedDeclarationCount := 1;
  if aBarrier <> 'missing' then
    lProvider := TImplicitRootAbsenceStub.Create;
  lFacts := TDelphiSemanticWithBinder.BindProject('root-absence-guard-' + aBarrier,
    nil, [lModel], lProvider);
  Assert.AreEqual(2, Integer(Length(lFacts.Bindings)));
  Assert.AreEqual(2, Integer(Length(lFacts.Bindings[0].Selectors)));
  Assert.AreEqual('unsupported', lFacts.Bindings[0].Selectors[1].Status);
  Assert.AreEqual('OWNER_INHERITED_MEMBERS_UNVERIFIED',
    lFacts.Bindings[0].Selectors[1].ReasonCode);
end;


procedure TWithBinderTests.OperatorIdentifierDoesNotHideDeclarations(const aShape: string);
var
  lRoot, lBody, lLocal: string;
  lOptions: TDelphiSemanticApiOptions;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lBinding: TDelphiSemanticWithBinding;
  lReference: TDelphiSemanticBoundReference;
  lFound: Boolean;
begin
  lRoot := WithBinderTempPath('OperatorIdentifier-' + aShape);
  TDirectory.CreateDirectory(lRoot);
  lBody := 'Value: Integer;';
  lLocal := 'var'#13#10'  Operator: Char;'#13#10'  Count: Integer;'#13#10;
  if aShape = 'field' then
  begin
    lBody := 'Operator: Char;'#13#10'    Count: Integer;';
    lLocal := '';
  end;
  TFile.WriteAllText(TPath.Combine(lRoot, 'P.dpr'), 'program P; uses Unit1; begin end.', TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'P.dproj'),
    '<Project><PropertyGroup><MainSource>P.dpr</MainSource></PropertyGroup>' +
    '<ItemGroup><DCCReference Include="Unit1.pas"/></ItemGroup></Project>', TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'Unit1.pas'),
    'unit Unit1;'#13#10'interface'#13#10'type'#13#10'  TR = record'#13#10 +
    '    ' + lBody + #13#10'  end;'#13#10 + lLocal + 'implementation'#13#10 +
    'procedure Run(var R: TR);'#13#10'begin'#13#10 +
    '  with R do Count := Count + 1;'#13#10'end;'#13#10'end.', TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticApiOptions);
  lOptions.ProjectFileName := TPath.Combine(lRoot, 'P.dproj');
  lFacts := TDelphiSemanticRemoveWithCompatibilityApi.BuildProjectWithBindingFacts(lOptions);
  lFound := False;
  for lBinding in lFacts.Bindings do
    for lReference in lBinding.References do
      if SameText(lReference.Name, 'Count') then
      begin
        lFound := True;
        if aShape = 'local' then
          Assert.AreEqual('lexical', lReference.Classification, lReference.ReasonCode)
        else
          Assert.AreEqual('member', lReference.Classification, lReference.ReasonCode);
      end;
  Assert.IsTrue(lFound);
end;

procedure TWithBinderTests.VerifiedCrossUnitReceiverKeepsMember(const aShape: string);
var
  lOptions: TDelphiSemanticApiOptions;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lBinding: TDelphiSemanticWithBinding;
  lReference: TDelphiSemanticBoundReference;
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
  lRoot, lType, lSelector, lVars, lControl, lExpectedClass, lExpectedReason: string;
  lFound: Boolean;
begin
  lRoot := WithBinderTempPath('VerifiedCrossUnit-' + aShape);
  TDirectory.CreateDirectory(lRoot);
  lType := 'TFoo = class(ControlUnit.TFoo) end;';
  lControl := 'TFoo = class Count: Integer; end;';
  if StartsText('alias', aShape) then
  begin
    lType := 'TFoo = ControlUnit.TFoo;';
    lControl := 'TFoo = record Count: Integer; end;';
  end;
  lExpectedClass := 'member';
  lExpectedReason := 'receiver-type-not-visible';
  if StartsText('alias', aShape) and (aShape <> 'alias-plain') then
  begin
    lExpectedClass := 'unsupported';
    lExpectedReason := 'selector-type-not-resolved';
  end;
  lVars := 'var Arr: array[0..0] of TFoo;';
  lSelector := 'Arr[0]';
  if EndsText('pointer', aShape) then
  begin
    lVars := 'var Ptr: ^TFoo;';
    lSelector := 'Ptr^';
  end;
  TFile.WriteAllText(TPath.Combine(lRoot, 'P.dpr'),
    'program P; uses Unit1, ControlUnit; begin end.', TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'ControlUnit.pas'),
    'unit ControlUnit;'#13#10'interface'#13#10'type ' + lControl +
    #13#10'implementation'#13#10'end.', TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'Unit1.pas'),
    'unit Unit1;'#13#10'interface'#13#10'uses ControlUnit;'#13#10'type ' + lType +
    #13#10 + lVars + #13#10'implementation'#13#10'procedure Run;'#13#10'begin'#13#10 +
    '  with ' + lSelector + ' do Count := Count + 1;'#13#10'end;'#13#10'end.', TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'P.dproj'),
    '<Project><PropertyGroup><MainSource>P.dpr</MainSource></PropertyGroup>' +
    '<ItemGroup><DCCReference Include="Unit1.pas"/><DCCReference Include="ControlUnit.pas"/>' +
    '</ItemGroup></Project>', TEncoding.ASCII);
  if MatchText(aShape, ['alias-plain', 'alias-ptr']) then
  begin
    lType := '';
    lVars := 'var R: TRec;';
    lSelector := 'R';
    if aShape = 'alias-ptr' then
    begin
      lType := '  PRec = ^TRec;'#13#10;
      lVars := 'var P: PRec;';
      lSelector := 'P^';
    end;
    TFile.WriteAllText(TPath.Combine(lRoot, 'ControlUnit.pas'),
      'unit ControlUnit;'#13#10'interface'#13#10 +
      'type TRec = record Count: Integer; end;'#13#10'implementation'#13#10#13#10'end.',
      TEncoding.ASCII);
    TFile.WriteAllText(TPath.Combine(lRoot, 'Unit1.pas'),
      'unit Unit1;'#13#10'interface'#13#10'uses ControlUnit;'#13#10 +
      'type TRec = ControlUnit.TRec;'#13#10 + lType + lVars +
      #13#10'implementation'#13#10'procedure Run;'#13#10'begin'#13#10 +
      '  with ' + lSelector + ' do Count := Count + 1;'#13#10'end;'#13#10'end.', TEncoding.ASCII);
  end;
  lOptions := Default(TDelphiSemanticApiOptions);
  lOptions.ProjectFileName := TPath.Combine(lRoot, 'P.dpr');
  lFacts := TDelphiSemanticRemoveWithCompatibilityApi.BuildProjectWithBindingFacts(lOptions);
  lFound := False;
  for lBinding in lFacts.Bindings do
    if SameText(lBinding.UnitName, 'Unit1') then
      for lReference in lBinding.References do
        if SameText(lReference.Name, 'Count') then
        begin
          lFound := True;
          Assert.AreEqual(lExpectedClass, lReference.Classification, aShape + ': ' + lReference.ReasonCode);
        end;
  Assert.IsTrue(lFound);
  lPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWith(lFacts);
  lFound := False;
  for lStatement in lPlan.FinalStatements do
    if SameText(ExtractFileName(lStatement.FileName), 'Unit1.pas') then
    begin
      lFound := True;
      // Native base already refuses this homonymous receiver at final DTO publication.
      Assert.AreEqual('skipped', lStatement.Status);
      Assert.AreEqual(lExpectedReason, lStatement.Reason);
      Assert.AreEqual(lExpectedReason, lStatement.SafetyReason);
      Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
      Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
      Assert.AreEqual('', lStatement.ReplacementText);
    end;
  Assert.IsTrue(lFound);
end;

procedure TWithBinderTests.ReceiverOwnerIdentityAndMemberActivity(const aShape: string);
var
  lOptions: TDelphiSemanticApiOptions;
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
  lEdit: TDelphiSemanticRemoveWithEdit;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lBinding: TDelphiSemanticWithBinding;
  lReference: TDelphiSemanticBoundReference;
  lRoot, lField, lExtra, lLocal, lBody, lControlType, lExpectedReason, lImports, lReceiverType: string;
  lPass: Integer;
  lFound, lFoundControl, lFoundReference, lCandidate: Boolean;
begin
  lRoot := WithBinderTempPath('ReceiverOwnerActivity-' + aShape);
  TDirectory.CreateDirectory(lRoot);
  lField := 'Other: Integer;';
  lExtra := '';
  lLocal := '';
  lBody := 'with Rec do Count := Count + 1;';
  lControlType := 'TRec';
  lImports := '';
  lReceiverType := 'TRec';
  if aShape = 'context-borrow' then
  begin
    lImports := 'uses ControlUnit;'#13#10;
  end;
  lExpectedReason := 'receiver-member-owner-conflict';
  if aShape = 'context-borrow' then
    lExpectedReason := 'receiver-type-not-visible';
  if aShape = 'selected-unknown' then
  begin
    lField := '{$IFNDEF LINUX} Count: Integer; {$ENDIF}';
    lExpectedReason := 'members-unverified';
  end else if aShape = 'selector-selected' then
  begin
    lExtra := 'type TOuter = record {$IFNDEF LINUX} Child: TRec; {$ENDIF} end;'#13#10 +
      'var Outer: TOuter;'#13#10;
    lBody := 'with Outer.Child do Count := Count + 1;';
    lExpectedReason := 'property-selector';
  end else if aShape = 'homonym-lexical' then
    lExtra := 'var Count: Integer;'#13#10
  else if aShape = 'homonym-constant' then
  begin
    lExtra := 'const Count = 10;'#13#10;
    lBody := 'with Rec do Other := Count;';
  end else if aShape = 'local-type' then
  begin
    lLocal := 'type TLocal = record {$IFDEF LINUX} Count: Integer; {$ENDIF} end;'#13#10 +
      'var LocalRec: TLocal;'#13#10;
    lBody := 'with LocalRec do Count := Count + 1;';
    lExpectedReason := 'receiver-member-not-found';
  end else if aShape = 'lexical-unknown-no-homonym' then
  begin
    lExtra := '{$IFNDEF LINUX} var Count: Integer; {$ENDIF}'#13#10;
    lControlType := 'TControlRec';
    lExpectedReason := '';
  end else if aShape = 'known-inactive-member' then
  begin
    lField := '{$IFDEF NEVER_DEFINED} Count: Integer; {$ENDIF}';
    lControlType := 'TControlRec';
    lExpectedReason := 'receiver-member-not-found';
  end;
  TFile.WriteAllText(TPath.Combine(lRoot, 'P.dpr'),
    'program P; uses Unit1, ControlUnit; begin end.', TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'P.dproj'),
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' +
    '<PropertyGroup><MainSource>P.dpr</MainSource></PropertyGroup>' +
    '<ItemGroup><DCCReference Include="Unit1.pas"/>' +
    '<DCCReference Include="ControlUnit.pas"/></ItemGroup></Project>', TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'Unit1.pas'),
    'unit Unit1;'#13#10'interface'#13#10 +
    'type TRec = record ' + lField + ' end;'#13#10'var Rec: ' + lReceiverType + ';'#13#10 +
    lExtra + 'implementation'#13#10 + lImports + 'procedure Run;'#13#10 +
    lLocal + 'begin'#13#10 + lBody + #13#10'end;'#13#10'end.', TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'ControlUnit.pas'),
    'unit ControlUnit;'#13#10'interface'#13#10 +
    'type ' + lControlType + ' = record Count: Integer; end;'#13#10 +
    'var ControlRec: ' + lControlType + ';'#13#10 +
    'implementation'#13#10'procedure Run; begin with ControlRec do Count := Count + 1; end;'#13#10 +
    'end.', TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticApiOptions);
  lOptions.ProjectFileName := TPath.Combine(lRoot, 'P.dproj');
  if aShape = 'known-inactive-member' then
  begin
    lOptions.Configuration := 'Debug';
    lOptions.Platform := 'Win64';
    lOptions.DelphiVersion := '23.0';
  end;
  lOptions.Cache.SqliteCacheFileName := TPath.Combine(lRoot, 'owner-activity.sqlite');
  if TFile.Exists(lOptions.Cache.SqliteCacheFileName) then
    TFile.Delete(lOptions.Cache.SqliteCacheFileName);
  for lPass := 0 to 1 do
  begin
    lFacts := TDelphiSemanticRemoveWithCompatibilityApi.BuildProjectWithBindingFacts(lOptions);
    lPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWith(lFacts);
    lFound := False;
    lFoundControl := False;
    for lStatement in lPlan.FinalStatements do
      if SameText(ExtractFileName(lStatement.FileName), 'Unit1.pas') then
      begin
        lFound := True;
        if lExpectedReason = '' then
        begin
          Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
          Assert.IsTrue(ContainsText(lStatement.ReplacementText, 'Count := Count + 1'));
          Assert.IsFalse(ContainsText(lStatement.ReplacementText, '.Count'));
        end else begin
          Assert.AreEqual('skipped', lStatement.Status, aShape);
          Assert.AreEqual(lExpectedReason, lStatement.Reason);
          Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
          Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
          Assert.AreEqual('', lStatement.ReplacementText);
          lCandidate := False;
          for lEdit in lPlan.Edits do
            if lEdit.StatementId = lStatement.SemanticId then
              lCandidate := True;
          Assert.AreEqual(MatchText(aShape, ['known-inactive-member', 'context-borrow']), lCandidate,
            'Only the ordinary known-inactive refusal keeps candidate coverage.');
        end;
      end else if SameText(ExtractFileName(lStatement.FileName), 'ControlUnit.pas') then
      begin
        lFoundControl := True;
        Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
      end;
    Assert.IsTrue(lFound);
    Assert.IsTrue(lFoundControl);
    if MatchText(aShape, ['selector-selected', 'local-type']) then
      for lBinding in lFacts.Bindings do
        if SameText(lBinding.UnitName, 'Unit1') then
        begin
          Assert.AreEqual('MEMBERS_UNVERIFIED', lBinding.SkipReason);
        end;
    if MatchText(aShape, ['context-borrow', 'homonym-lexical', 'homonym-constant']) then
    begin
      lFoundReference := False;
      for lBinding in lFacts.Bindings do
        if SameText(lBinding.UnitName, 'Unit1') then
          for lReference in lBinding.References do
            if SameText(lReference.Name, 'Count') then
            begin
              lFoundReference := True;
              Assert.AreNotEqual('member', lReference.Classification);
              if MatchText(aShape, ['homonym-lexical', 'homonym-constant']) then
                Assert.AreEqual('lexical', lReference.Classification);
            end;
      Assert.IsTrue(lFoundReference);
    end;
  end;
end;

procedure TWithBinderTests.UnknownActivityCannotAuthorizeRemoveWith(const aShape: string);
var
  lOptions: TDelphiSemanticApiOptions;
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
  lEdit: TDelphiSemanticRemoveWithEdit;
  lRoot, lPrefix, lField, lBody, lExtra, lLocal: string;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lBinding: TDelphiSemanticWithBinding;
  lReference: TDelphiSemanticBoundReference;
  lPass, lAffectedCount: Integer;
  lActive: Boolean;
  lFoundSkipped, lFoundControl: Boolean;
begin
  lRoot := WithBinderTempPath('UnknownWith-' + aShape);
  TDirectory.CreateDirectory(lRoot);
  lPrefix := '';
  if aShape = 'missing' then
    lPrefix := '{$IFDEF LINUX}{$I Missing.inc}{$ENDIF}'#13#10
  else if aShape = 'directive' then
    lPrefix := '{$HINTS OFF}'#13#10;
  lExtra := '';
  lLocal := '';
  lActive := aShape = 'active';
  lField := 'Count: Integer;';
  lBody := '{$IFNDEF LINUX} with Rec do Count := Count + 1; {$ENDIF}';
  if aShape = 'declared-receiver' then
  begin
    lField := '{$IF Declared(TRec)} Count: Integer; {$IFEND}';
    lBody := 'with Rec do Count := Count + 1;';
  end;
  if aShape = 'declaration' then
  begin
    lField := '{$IFDEF LINUX} Count: Integer; {$ENDIF}';
    lBody := 'with Rec do Count := Count + 1;';
  end;
  if MatchText(aShape, ['selected-field', 'active', 'inactive']) then
  begin
    lField := '{$IFDEF MSWINDOWS} Count: Integer; {$ENDIF}';
    if aShape = 'inactive' then
      lField := '{$IFDEF LINUX} Count: Integer; {$ENDIF}';
    lBody := 'with Rec do Count := Count + 1;';
  end else if MatchText(aShape, ['global', 'local']) then
  begin
    lField := 'Other: Integer;';
    if aShape = 'global' then
      lExtra := '{$IFDEF MSWINDOWS} var Count: Integer; {$ENDIF}'#13#10
    else
      lLocal := '{$IFDEF MSWINDOWS} var Count: Integer; {$ENDIF}'#13#10;
    lBody := 'with Rec do Count := Count + 1;';
  end else if aShape = 'selector' then
  begin
    lExtra := 'type TOuter = record {$IFDEF MSWINDOWS} Child: TRec; {$ENDIF} end;'#13#10 +
      'var Outer: TOuter;'#13#10;
    lBody := 'with Outer.Child do Count := Count + 1;';
  end else if aShape = 'activity-nested' then
  begin
    lBody := 'with Rec do begin {$IFNDEF LINUX} with Rec do Count := Count + 1; {$ENDIF} end;';
  end else if aShape = 'nested' then
  begin
    lField := '{$IFDEF LINUX} Count: Integer; {$ENDIF}';
    lBody := 'with Rec do begin with Rec do Count := Count + 1; end;';
  end;
  TFile.WriteAllText(TPath.Combine(lRoot, 'P.dpr'),
    'program P; uses Unit1, ControlUnit; begin end.', TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'P.dproj'),
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' +
    '<PropertyGroup><MainSource>P.dpr</MainSource></PropertyGroup>' +
    '<ItemGroup><DCCReference Include="Unit1.pas"/>' +
    '<DCCReference Include="ControlUnit.pas"/></ItemGroup></Project>', TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'Unit1.pas'),
    'unit Unit1;'#13#10'interface'#13#10 +
    'type TRec = record ' + lField + ' end;'#13#10'var Rec: TRec;'#13#10 +
    lExtra + 'implementation'#13#10 + lPrefix + 'procedure Run;'#13#10 + lLocal + 'begin'#13#10 +
    lBody + #13#10'end;'#13#10'end.', TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'ControlUnit.pas'),
    'unit ControlUnit;'#13#10'interface'#13#10 +
    'type TRec = record Count: Integer; end;'#13#10'var Rec: TRec;'#13#10 +
    'implementation'#13#10'procedure Run; begin with Rec do Count := Count + 1; end;'#13#10 +
    'end.', TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticApiOptions);
  lOptions.ProjectFileName := TPath.Combine(lRoot, 'P.dproj');
  if aShape = 'ancestor-declaration' then
    TFile.WriteAllText(TPath.Combine(lRoot, 'Unit1.pas'),
      'unit Unit1;'#13#10'interface'#13#10 +
      'type TBase = class {$IF Declared(TBase)} Count: Integer; {$IFEND} end;'#13#10 +
      'TRec = class(TBase) end;'#13#10'var Rec: TRec;'#13#10 +
      'implementation'#13#10'procedure Run;'#13#10'begin'#13#10 +
      'with Rec do begin Count := 1;'#13#10'end;'#13#10'end;'#13#10'end.', TEncoding.ASCII);
  if MatchText(aShape, ['active', 'inactive', 'ancestor-declaration']) then
  begin
    lOptions.Configuration := 'Debug';
    lOptions.Platform := 'Win64';
    lOptions.DelphiVersion := '23.0';
  end;
  lOptions.Cache.SqliteCacheFileName := TPath.Combine(lRoot, 'round11-cache.sqlite');
  if TFile.Exists(lOptions.Cache.SqliteCacheFileName) then
    TFile.Delete(lOptions.Cache.SqliteCacheFileName);
  for lPass := 0 to 1 do
  begin
    lPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWith(lOptions);
    if aShape = 'ancestor-declaration' then
      Assert.AreEqual('blocked', lPlan.Status, lPlan.Diagnostic)
    else
      Assert.AreEqual('planned', lPlan.Status, lPlan.Diagnostic);
    Assert.IsNotEmpty(lPlan.ContextFingerprint, 'Control statement retains its apply context.');
    lAffectedCount := 0;
    lFoundSkipped := False;
    lFoundControl := False;
    for lStatement in lPlan.FinalStatements do
      if SameText(ExtractFileName(lStatement.FileName), 'Unit1.pas') then
      begin
        Inc(lAffectedCount);
        if lActive then
        begin
          Assert.AreEqual('planned', lStatement.Status);
          Assert.IsTrue(Length(lStatement.Edits) > 0);
        end else begin
          Assert.AreEqual('skipped', lStatement.Status, 'Unknown declaration/activity cannot authorize apply.');
          if MatchText(aShape, ['mixed', 'missing', 'activity-nested']) then
            Assert.AreEqual('activity-unverified', lStatement.Reason)
          else if aShape = 'directive' then
            Assert.AreEqual('receiver-type-not-visible', lStatement.Reason)
          else if aShape = 'ancestor-declaration' then
            Assert.AreEqual('members-unverified', lStatement.Reason);
          Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
          Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
          Assert.AreEqual('', lStatement.ReplacementText);
        end;
        lFoundSkipped := True;
      end else if SameText(ExtractFileName(lStatement.FileName), 'ControlUnit.pas') then
      begin
        if aShape = 'ancestor-declaration' then
        begin
          // Native base contract: ds-721/ancestor-exact-native-base.log.
          Assert.AreEqual('skipped', lStatement.Status);
          Assert.AreEqual('receiver-type-not-visible', lStatement.Reason);
          Assert.AreEqual('receiver-type-not-visible', lStatement.SafetyReason);
          Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
          Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
          Assert.AreEqual('', lStatement.ReplacementText);
          for lEdit in lPlan.Edits do
            if lEdit.StatementId = lStatement.SemanticId then
              lFoundControl := True;
          Assert.IsTrue(lFoundControl, 'The established refusal retains its candidate.');
        end else begin
          Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
          Assert.IsTrue(Length(lStatement.Edits) > 0);
          lFoundControl := True;
        end;
      end;
    Assert.IsTrue(lFoundSkipped, 'Expected affected statement DTO.');
    Assert.IsTrue(lFoundControl, 'Expected unrelated known-active statement DTO.');
    if MatchText(aShape, ['nested', 'activity-nested']) then
      Assert.AreEqual(2, lAffectedCount, 'Inner unsafe statement must retain its parent.');
    if not lActive then
      for lEdit in lPlan.Edits do
        Assert.IsFalse(SameText(ExtractFileName(lEdit.FileName), 'Unit1.pas'),
          'Retained fingerprint cannot authorize any candidate edit in the skipped unit.');
    if aShape = 'inactive' then
    begin
      lFacts := TDelphiSemanticRemoveWithCompatibilityApi.BuildProjectWithBindingFacts(lOptions);
      for lBinding in lFacts.Bindings do
        if SameText(lBinding.UnitName, 'Unit1') then
          for lReference in lBinding.References do
            Assert.AreNotEqual('member', lReference.Classification,
              'Known-false field must not borrow a foreign member.');
    end;
  end;
end;

procedure TWithBinderTests.WholeWithSourceActivityIsRequired(const aShape: string);
var
  lOptions: TDelphiSemanticApiOptions;
  lPlan, lSnapshotPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
  lExpectedReason: string;
  lRoot, lField, lBody: string;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lPass, lAffectedCount: Integer;
  lFoundSkipped, lFoundControl: Boolean;
begin
  lRoot := WithBinderTempPath('UnknownWith-' + aShape);
  TDirectory.CreateDirectory(lRoot);
  lField := 'Count: Integer;';
  lExpectedReason := 'activity-unverified';
  lBody := 'with Rec do begin Count := 1;'#13#10;
  if aShape = 'hidden-if' then
    lBody := lBody + '{$IF UseFast}{$ELSE} with Rec do Count := 5; {$IFEND}'
  else if aShape = 'hidden-declared' then
    lBody := lBody + '{$IF Declared(TFoo)} with Rec do Count := 5; {$IFEND}'
  else if aShape = 'hidden-malformed' then
    lBody := lBody + '{$IFDEF MSWINDOWS trailing} with Rec do Count := 5; {$ENDIF}'
  else if aShape = 'hidden-linux' then
    lBody := lBody + '{$IFDEF LINUX} with Rec do Count := 5; {$ENDIF}'
  else if aShape = 'hidden-missing' then
    lBody := lBody + '{$IFNDEF LINUX}{$I Missing.inc}{$ENDIF}'
  else if aShape = 'hidden-include' then
    lBody := lBody + '{$IFDEF LINUX}{$I Body.inc}{$ENDIF}'
  else if aShape = 'selector-text' then
    lBody := 'with {$IFDEF LINUX} Rec {$ELSE} Rec {$ENDIF} do begin Count := Count + 1;'
  else if aShape = 'taint' then
    lBody := lBody + '{$UNDEF X}{$IFDEF LINUX}{$I Missing.inc}{$ENDIF}' +
      '{$IFDEF X} Count := 2; {$ENDIF}'
  else if aShape = 'ancestor-control' then
  begin
    lField := '';
  end else if aShape = 'binder-unresolved' then
  begin
    lBody := 'with Rec do begin Missing := 1; {$IFNDEF LINUX} Count := 2; {$ENDIF}';
    lExpectedReason := 'receiver-member-not-found';
  end else if aShape = 'binder-scoped' then
  begin
    lBody := 'with Rec do begin var Local := 1; {$IFNDEF LINUX} Count := 2; {$ENDIF}';
    lExpectedReason := 'activity-unverified';
  end;
  lBody := lBody + #13#10'end;';
  TFile.WriteAllText(TPath.Combine(lRoot, 'P.dpr'),
    'program P; uses Unit1, ControlUnit; begin end.', TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'P.dproj'),
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' +
    '<PropertyGroup><MainSource>P.dpr</MainSource></PropertyGroup>' +
    '<ItemGroup><DCCReference Include="Unit1.pas"/>' +
    '<DCCReference Include="ControlUnit.pas"/></ItemGroup></Project>', TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'Unit1.pas'),
    'unit Unit1;'#13#10'interface'#13#10 +
    'type TRec = record ' + lField + ' end;'#13#10'var Rec: TRec;'#13#10 +
    'implementation'#13#10'procedure Run;'#13#10'begin'#13#10 +
    lBody + #13#10'end;'#13#10'end.', TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'ControlUnit.pas'),
    'unit ControlUnit;'#13#10'interface'#13#10 +
    'type TRec = record Count: Integer; end;'#13#10'var Rec: TRec;'#13#10 +
    'implementation'#13#10'procedure Run; begin with Rec do Count := Count + 1; end;'#13#10 +
    'end.', TEncoding.ASCII);
  if aShape = 'ancestor-control' then
    // A distinct identity keeps this control independent of DS-721's homonym gap.
    TFile.WriteAllText(TPath.Combine(lRoot, 'ControlUnit.pas'),
      'unit ControlUnit;'#13#10'interface'#13#10 +
      'type TControlRec = record Count: Integer; end;'#13#10'var Rec: TControlRec;'#13#10 +
      'implementation'#13#10'procedure Run; begin with Rec do Count := Count + 1; end;'#13#10 +
      'end.', TEncoding.ASCII);
  if aShape = 'hidden-include' then
    TFile.WriteAllText(TPath.Combine(lRoot, 'Body.inc'), 'with Rec do Count := 5;', TEncoding.ASCII);
  if aShape = 'ancestor-control' then
    TFile.WriteAllText(TPath.Combine(lRoot, 'Unit1.pas'),
      'unit Unit1;'#13#10'interface'#13#10 +
      'type TBase = class {$IF Declared(TBase)} Count: Integer; {$IFEND} end;'#13#10 +
      'TRec = class(TBase) end;'#13#10'var Rec: TRec;'#13#10 +
      'implementation'#13#10'procedure Run;'#13#10'begin'#13#10 + lBody +
      #13#10'end;'#13#10'end.', TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticApiOptions);
  lOptions.ProjectFileName := TPath.Combine(lRoot, 'P.dproj');
  begin
    lOptions.Configuration := 'Debug';
    lOptions.Platform := 'Win64';
    lOptions.DelphiVersion := '23.0';
  end;
  lOptions.Cache.SqliteCacheFileName := TPath.Combine(lRoot, 'round11-cache.sqlite');
  if TFile.Exists(lOptions.Cache.SqliteCacheFileName) then
    TFile.Delete(lOptions.Cache.SqliteCacheFileName);
  for lPass := 0 to 1 do
  begin
    lFacts := TDelphiSemanticRemoveWithCompatibilityApi.BuildProjectWithBindingFacts(lOptions);
    lPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWith(lFacts);
    lSnapshotPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWithCompatibilitySnapshot(lFacts);
    Assert.AreEqual(Length(lPlan.FinalStatements), Length(lSnapshotPlan.FinalStatements));
    for var i := 0 to High(lPlan.FinalStatements) do
    begin
      Assert.AreEqual(lPlan.FinalStatements[i].Status, lSnapshotPlan.FinalStatements[i].Status);
      Assert.AreEqual(lPlan.FinalStatements[i].Reason, lSnapshotPlan.FinalStatements[i].Reason);
      Assert.AreEqual(Length(lPlan.FinalStatements[i].Edits), Length(lSnapshotPlan.FinalStatements[i].Edits));
    end;
    Assert.AreEqual('planned', lPlan.Status, lPlan.Diagnostic);
    Assert.IsNotEmpty(lPlan.ContextFingerprint, 'Control statement retains its apply context.');
    lAffectedCount := 0;
    lFoundSkipped := False;
    lFoundControl := False;
    for lStatement in lPlan.FinalStatements do
      if SameText(ExtractFileName(lStatement.FileName), 'Unit1.pas') then
      begin
        // The declaration-owner refusal is retained separately under DS-721.
        if aShape = 'ancestor-control' then
        begin
          lFoundSkipped := True;
          Continue;
        end;
        Inc(lAffectedCount);
        begin
          Assert.AreEqual('skipped', lStatement.Status, 'Unknown declaration/activity cannot authorize apply.');
          Assert.AreEqual(lExpectedReason, lStatement.Reason);
          Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
          Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
          Assert.AreEqual('', lStatement.ReplacementText);
        end;
        lFoundSkipped := True;
      end else if SameText(ExtractFileName(lStatement.FileName), 'ControlUnit.pas') then
      begin
        Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
        Assert.IsTrue(Length(lStatement.Edits) > 0);
        lFoundControl := True;
      end;
    Assert.IsTrue(lFoundSkipped, 'Expected affected statement DTO.');
    Assert.IsTrue(lFoundControl, 'Expected unrelated known-active statement DTO.');
    // DAK transaction coverage consumes only planned FinalStatements with Edits.
    for lStatement in lPlan.FinalStatements do
      if (aShape <> 'ancestor-control') and SameText(lStatement.Status, 'planned') and
        (Length(lStatement.Edits) > 0) then
        Assert.IsFalse(SameText(ExtractFileName(lStatement.FileName), 'Unit1.pas'),
          'Fingerprint input must never include the refused source.');
  end;
end;

procedure TWithBinderTests.WholeWithRangeRefusesOnlyUnknownActivity(const aShape: string);
var
  lOptions: TDelphiSemanticApiOptions;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lPlan, lSnapshotPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
  lRoot, lSource, lExpectedReplacement: string;
  lPass: Integer;
begin
  lRoot := WithBinderTempPath('RangeKnownOrUnknown-' + aShape);
  TDirectory.CreateDirectory(lRoot);
  lSource := 'unit Unit1;'#13#10'interface'#13#10 +
    'type TRec = record Count: Integer; end;'#13#10 +
    'var Rec, Inner: TRec;'#13#10'implementation'#13#10 +
    'procedure Run;'#13#10'begin'#13#10 +
    '  with Rec do begin'#13#10'    Count := 1;'#13#10 +
    '    {$IFDEF RELEASE_TRACE}'#13#10 +
    '    with Inner do Count := 5;'#13#10 +
    '    {$ENDIF}'#13#10'  end;'#13#10'end;'#13#10'end.'#13#10;
  if aShape = 'unknown' then
    lSource := StringReplace(lSource, '{$IFDEF RELEASE_TRACE}', '{$IF UseFast}', []);
  TFile.WriteAllText(TPath.Combine(lRoot, 'P.dpr'),
    'program P; uses Unit1; begin end.', TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'P.dproj'),
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' +
    '<PropertyGroup><MainSource>P.dpr</MainSource></PropertyGroup>' +
    '<ItemGroup><DCCReference Include="Unit1.pas"/></ItemGroup></Project>', TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'Unit1.pas'), lSource, TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticApiOptions);
  lOptions.ProjectFileName := TPath.Combine(lRoot, 'P.dproj');
  lOptions.Configuration := 'Debug';
  lOptions.Platform := 'Win64';
  lOptions.DelphiVersion := '23.0';
  lOptions.Cache.SqliteCacheFileName := TPath.Combine(lRoot, 'range-cache.sqlite');
  if TFile.Exists(lOptions.Cache.SqliteCacheFileName) then
    TFile.Delete(lOptions.Cache.SqliteCacheFileName);
  // Native d308bc5 control pins this general known-inactive same-type shape under P2.
  lExpectedReplacement := '  lWithRecPtr := @Rec;' + #13#10 +
    ' begin' + #13#10 +
    '    lWithRecPtr^.Count := 1;' + #13#10 +
    '    {$IFDEF RELEASE_TRACE}' + #13#10 +
    '    with Inner do lWithRecPtr^.Count := 5;' + #13#10 +
    '    {$ENDIF}' + #13#10 +
    '  end;';
  for lPass := 0 to 1 do
  begin
    lFacts := TDelphiSemanticRemoveWithCompatibilityApi.BuildProjectWithBindingFacts(lOptions);
    lPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWith(lFacts);
    lSnapshotPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWithCompatibilitySnapshot(lFacts);
    Assert.AreEqual(1, Integer(Length(lPlan.FinalStatements)));
    Assert.AreEqual(1, Integer(Length(lSnapshotPlan.FinalStatements)));
    lStatement := lPlan.FinalStatements[0];
    Assert.AreEqual(lStatement.Status, lSnapshotPlan.FinalStatements[0].Status);
    Assert.AreEqual(lStatement.Reason, lSnapshotPlan.FinalStatements[0].Reason);
    Assert.AreEqual(lStatement.SafetyReason, lSnapshotPlan.FinalStatements[0].SafetyReason);
    Assert.AreEqual(lStatement.ReplacementText, lSnapshotPlan.FinalStatements[0].ReplacementText);
    Assert.AreEqual(Length(lStatement.Edits), Length(lSnapshotPlan.FinalStatements[0].Edits));
    Assert.AreEqual(Length(lStatement.Temps), Length(lSnapshotPlan.FinalStatements[0].Temps));
    if aShape = 'known' then
    begin
      Assert.AreEqual('planned', lPlan.Status, lPlan.Diagnostic);
      Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
      Assert.AreEqual('', lStatement.Reason);
      Assert.AreEqual('', lStatement.SafetyReason);
      Assert.AreEqual(1, Integer(Length(lStatement.Temps)));
      Assert.AreEqual(2, Integer(Length(lStatement.Edits)));
      Assert.AreEqual(lExpectedReplacement, lStatement.ReplacementText);
      Assert.IsNotEmpty(lPlan.ContextFingerprint);
    end else begin
      Assert.AreEqual('skipped', lStatement.Status);
      Assert.AreEqual('activity-unverified', lStatement.Reason);
      Assert.AreEqual('ACTIVITY_UNVERIFIED', lStatement.SafetyReason);
      Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
      Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
      Assert.AreEqual('', lStatement.ReplacementText);
      // Apply consumes only planned final DTOs with edits, not the plan-wide seal.
      Assert.AreEqual(lPlan.ContextFingerprint, lSnapshotPlan.ContextFingerprint);
    end;
    Assert.AreEqual(lSource, TFile.ReadAllText(TPath.Combine(lRoot, 'Unit1.pas')));
  end;
end;

procedure TWithBinderTests.PublicProviderFingerprintFailureRefuses(const aPath: string);
var
  lOptions: TDelphiSemanticApiOptions;
  lPlan: TDelphiSemanticRemoveWithPlan;
  lContext: TDelphiSemanticContextResult;
  lSession: TDelphiSemanticProjectSessionResult;
  lDiagnostics: TArray<TDelphiSemanticDiagnostic>;
begin
  lOptions := Default(TDelphiSemanticApiOptions);
  lOptions.ProjectFileName := TPath.GetFullPath(TPath.Combine(RepoRoot,
    '..\DelphiAiKit\tests\fixtures\RemoveWithMultipleSelectorRewriteFixture\' +
    'RemoveWithMultipleSelectorRewriteFixture.dproj'));
  lOptions.ImplicitRootMemberAbsence := TThrowingRootAbsenceProvider.Create('fingerprint');
  try
    if aPath = 'plan' then
    begin
      lPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWith(lOptions);
      Assert.AreNotEqual('planned', lPlan.Status);
      Assert.AreEqual('', lPlan.ContextFingerprint);
      lDiagnostics := lPlan.Diagnostics;
    end else if aPath = 'project' then
    begin
      lContext := TDelphiSemanticProject.Load(lOptions.ProjectFileName,
        ProjectOptionsFromApiOptions(lOptions));
      Assert.IsFalse(lContext.Success);
      Assert.AreEqual('', lContext.Project.ContextFingerprint);
      lDiagnostics := lContext.Diagnostics;
    end else begin
      lSession := TDelphiSemanticProjectSession.Open(ProjectOptionsFromApiOptions(lOptions));
      try
        Assert.IsFalse(lSession.Success);
        Assert.IsTrue(lSession.Session = nil);
        lDiagnostics := lSession.Diagnostics;
      finally
        lSession.Session.Free;
      end;
    end;
  except
    on E: Exception do
      Assert.Fail('The public provider boundary threw: ' + E.Message);
  end;
  Assert.AreEqual(1, Integer(Length(lDiagnostics)));
  Assert.AreEqual('IMPLICIT_ROOT_PROVIDER_FAILED', lDiagnostics[0].Code);
  Assert.IsTrue(Pos('Fingerprint unavailable', lDiagnostics[0].Message) > 0);
end;

procedure TWithBinderTests.OptionalRootAbsenceFlowsThroughApiAndBypassesPersistentFacts;
var
  lBuildResult: TDelphiSemanticRemoveWithPlanBuildResult;
  lCache: TDelphiSemanticSnapshotSqliteCache;
  lConnection: TFDConnection;
  lDriverLink: TFDPhysSQLiteDriverLink;
  lDefaultIdentity: TDelphiSemanticSnapshotCacheIdentity;
  lDefaultPlan: TDelphiSemanticRemoveWithPlan;
  lEvidenceIdentity: TDelphiSemanticSnapshotCacheIdentity;
  lProjectOptions: TDelphiSemanticOptions;
  lSeedSnapshot: TDelphiProjectSnapshot;
  lSession: TDelphiSemanticProjectSessionResult;
  lOptions: TDelphiSemanticApiOptions;
  lPlan: TDelphiSemanticRemoveWithPlan;
begin
  lOptions := Default(TDelphiSemanticApiOptions);
  lOptions.ProjectFileName := TPath.GetFullPath(TPath.Combine(RepoRoot,
    '..\DelphiAiKit\tests\fixtures\RemoveWithMultipleSelectorRewriteFixture\' +
    'RemoveWithMultipleSelectorRewriteFixture.dproj'));
  lOptions.Cache.SqliteCacheFileName := WithBinderTempPath('RootAbsenceProjectCache.sqlite');
  lDefaultPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWith(lOptions);
  Assert.AreEqual(2, Integer(Length(lDefaultPlan.FinalStatements)));
  Assert.AreEqual('skipped', lDefaultPlan.FinalStatements[0].Status);
  Assert.AreEqual('planned', lDefaultPlan.FinalStatements[1].Status);
  lProjectOptions := ProjectOptionsFromApiOptions(lOptions);
  lSession := TDelphiSemanticProjectSession.Open(lProjectOptions);
  try
    Assert.IsTrue(lSession.Success);
    lDefaultIdentity := ProjectRemoveWithFactsIdentityForTest(lSession.Session.Project, lProjectOptions);
  finally
    lSession.Session.Free;
  end;
  lOptions.ImplicitRootMemberAbsence := TImplicitRootAbsenceStub.Create;
  lProjectOptions := ProjectOptionsFromApiOptions(lOptions);
  lSession := TDelphiSemanticProjectSession.Open(lProjectOptions);
  try
    Assert.IsTrue(lSession.Success);
    lEvidenceIdentity := ProjectRemoveWithFactsIdentityForTest(lSession.Session.Project, lProjectOptions);
  finally
    lSession.Session.Free;
  end;
  lCache := TDelphiSemanticSnapshotSqliteCache.Create(lOptions.Cache.SqliteCacheFileName);
  lSeedSnapshot := nil;
  try
    Assert.IsTrue(lCache.TryLoadProjectRemoveWithPlanningFacts(lDefaultIdentity, lSeedSnapshot));
    lCache.StoreProjectRemoveWithPlanningFacts(lEvidenceIdentity, lSeedSnapshot);
  finally
    lSeedSnapshot.Free;
    lCache.Free;
  end;
  lDriverLink := TFDPhysSQLiteDriverLink.Create(nil);
  lConnection := TFDConnection.Create(nil);
  try
    lConnection.LoginPrompt := False;
    lConnection.Params.Values['DriverID'] := 'SQLite';
    lConnection.Params.Values['Database'] := lOptions.Cache.SqliteCacheFileName;
    lConnection.Connected := True;
    lConnection.ExecSQL('create table root_absence_write_audit (event text not null)');
    lConnection.ExecSQL('create trigger root_absence_insert after insert on ' +
      'snapshot_project_remove_with_facts begin insert into root_absence_write_audit ' +
      'values (''insert''); end');
    lConnection.ExecSQL('create trigger root_absence_update after update on ' +
      'snapshot_project_remove_with_facts begin insert into root_absence_write_audit ' +
      'values (''update''); end');
    lConnection.ExecSQL('create trigger root_absence_delete after delete on ' +
      'snapshot_project_remove_with_facts begin insert into root_absence_write_audit ' +
      'values (''delete''); end');
    lConnection.Connected := False;
    lPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWith(lOptions);
    Assert.AreEqual(2, Integer(Length(lPlan.FinalStatements)),
      'Optional evidence must reach the binder through API and project session.');
    Assert.AreEqual('planned', lPlan.FinalStatements[0].Status);
    Assert.AreEqual('planned', lPlan.FinalStatements[1].Status);
    Assert.AreNotEqual(lDefaultPlan.ContextFingerprint, lPlan.ContextFingerprint);
    lConnection.Connected := True;
    Assert.AreEqual(0, Integer(lConnection.ExecSQLScalar(
      'select count(*) from root_absence_write_audit')),
      'The API provider request must bypass every persistent planning-fact write.');
    lConnection.Connected := False;
    // The exact provider-context entry must remain the seeded default refusal.
    // Probe metrics also catch a forbidden cache read that subsequently rebinds.
    lCache := TDelphiSemanticSnapshotSqliteCache.Create(lOptions.Cache.SqliteCacheFileName);
    lSeedSnapshot := nil;
    try
      Assert.IsTrue(lCache.TryLoadProjectRemoveWithPlanningFacts(lEvidenceIdentity, lSeedSnapshot));
      lDefaultPlan := TDelphiSemanticRemoveWithPlanner.Plan(lSeedSnapshot);
      Assert.AreEqual('skipped', lDefaultPlan.FinalStatements[0].Status,
        'Provider-backed WITH facts must bypass persistent writes.');
    finally
      lSeedSnapshot.Free;
      lCache.Free;
    end;
    lSession := TDelphiSemanticProjectSession.Open(lProjectOptions);
    try
      Assert.IsTrue(lSession.Success);
      lBuildResult := lSession.Session.PlanRemoveWithResult;
      Assert.AreEqual(0, lBuildResult.SnapshotMetrics.SnapshotCacheProbes,
        'Provider-backed WITH facts must bypass persistent reads, including rebind-on-hit.');
    finally
      lSession.Session.Free;
    end;
    lConnection.Connected := True;
    Assert.AreEqual(0, Integer(lConnection.ExecSQLScalar(
      'select count(*) from root_absence_write_audit')),
      'Provider-backed WITH facts must bypass every persistent planning-fact write.');
  finally
    lConnection.Free;
    lDriverLink.Free;
  end;
  lOptions.ImplicitRootMemberAbsence := nil;
  lDefaultPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWith(lOptions);
  Assert.AreEqual(2, Integer(Length(lDefaultPlan.FinalStatements)),
    'Provider-backed facts must never contaminate the default persistent cache.');
  Assert.AreEqual('skipped', lDefaultPlan.FinalStatements[0].Status);
  Assert.AreEqual('planned', lDefaultPlan.FinalStatements[1].Status);
end;

procedure TWithBinderTests.UnindexedRecordHelperRequiresVisibleMatchingIdentity(const aShape: string);
var
  lRoot: string;
function Unit_(const aName, aText: string): TDelphiSemanticUnitModel;
var
  lOptions: TDelphiSemanticModelOptions;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.ProjectContextApplied := True;
  lOptions.SourceFileName := TPath.Combine(lRoot, aName + '.pas');
  TFile.WriteAllText(lOptions.SourceFileName, aText, TEncoding.ASCII);
  Result := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(Result.Success, aName);
  Assert.AreEqual('ast', Result.ScopeModelStatus);
end;
procedure Report(const aCase: string; const aModels: TArray<TDelphiSemanticUnitModel>);
var
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lPlan, lSnapshotPlan: TDelphiSemanticRemoveWithPlan;
  lReference: TDelphiSemanticBoundReference;
  lEdit: TDelphiSemanticRemoveWithEdit;
  lExpectedClass, lExpectedReason, lExpectedSafety, lExpectedStatus, lName: string;
  lExpectedEdits, lBindingIndex, lStatementIndex, lExpectedCount: Integer;
begin
  lFacts := TDelphiSemanticWithBinder.BindProject('ds720-' + aShape, nil, aModels);
  lExpectedCount := 1;
  if aShape = 'nested' then
  begin
    lExpectedCount := 2;
  end;
  Assert.AreEqual(lExpectedCount, Integer(Length(lFacts.Bindings)));
  lBindingIndex := lExpectedCount - 1;
  Assert.AreEqual('resolved', lFacts.Bindings[lBindingIndex].Selectors[0].Status);
  lExpectedClass := 'unsupported';
  lExpectedStatus := 'skipped';
  lExpectedReason := 'receiver-member-not-found';
  lExpectedSafety := 'RECORD_HELPER_MEMBERS_UNVERIFIED';
  lExpectedEdits := 0;
  lName := 'Count';
  if MatchText(aShape, ['call', 'intrinsic']) then
  begin
    lExpectedReason := 'symbol-not-found';
  end;
  if MatchText(aShape, ['unrelated', 'class-helper', 'local-array', 'no-helper']) then
  begin
    lExpectedStatus := 'planned';
    lExpectedReason := '';
    lExpectedSafety := '';
    lExpectedEdits := 2;
    lExpectedClass := 'lexical';
  end;
  if MatchText(aShape, ['same-name', 'private-import', 'import', 'indexed-import']) then
  begin
    lExpectedReason := 'type-source-not-indexed';
    lExpectedSafety := lExpectedReason;
    if aShape <> 'import' then
    begin
      lExpectedClass := 'lexical';
    end;
  end;
  if aShape = 'after-site' then
  begin
    lExpectedClass := 'lexical';
    lExpectedReason := 'receiver-member-owner-conflict';
    lExpectedSafety := lExpectedReason;
  end;
  if aShape = 'indexed-import' then
  begin
    lExpectedClass := 'member';
  end;
  if MatchText(aShape, ['intrinsic', 'no-helper']) then
  begin
    lName := 'FillChar';
    if aShape = 'no-helper' then
    begin
      lExpectedClass := 'intrinsic';
    end;
  end;
  if aShape = 'local-array' then
  begin
    lName := 'lArr[0]';
    lExpectedClass := 'unsupported';
  end;
  Assert.IsTrue(HasReference(lFacts.Bindings[lBindingIndex], lName, lExpectedClass), aShape + ': ' + lName);
  for lReference in lFacts.Bindings[lBindingIndex].References do
  begin
    if SameText(lReference.Name, lName) and (lExpectedClass = 'unsupported') then
    begin
      if aShape = 'local-array' then
      begin
        Assert.AreEqual('INDEXED_SELECTOR_UNSUPPORTED', lReference.ReasonCode);
      end else begin
        Assert.AreEqual('RECORD_HELPER_MEMBERS_UNVERIFIED', lReference.ReasonCode);
      end;
    end;
  end;
  lPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWith(lFacts);
  Assert.AreEqual(lExpectedCount, Integer(Length(lPlan.FinalStatements)));
  for lStatementIndex := 0 to High(lPlan.FinalStatements) do
  begin
    Assert.AreEqual(lExpectedStatus, lPlan.FinalStatements[lStatementIndex].Status, aShape);
    Assert.AreEqual(lExpectedReason, lPlan.FinalStatements[lStatementIndex].Reason, aShape);
    Assert.AreEqual(lExpectedSafety, lPlan.FinalStatements[lStatementIndex].SafetyReason, aShape);
    Assert.AreEqual(lExpectedEdits, Integer(Length(lPlan.FinalStatements[lStatementIndex].Edits)), aShape);
    if lExpectedSafety = 'RECORD_HELPER_MEMBERS_UNVERIFIED' then
    begin
      Assert.AreEqual(0, Integer(Length(lPlan.FinalStatements[lStatementIndex].Temps)));
      Assert.AreEqual('', lPlan.FinalStatements[lStatementIndex].ReplacementText);
      for lEdit in lPlan.Edits do
      begin
        Assert.AreNotEqual('remove-with-candidate', lEdit.Kind);
      end;
    end;
    lSnapshotPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWithCompatibilitySnapshot(lFacts);
    Assert.AreEqual(lPlan.FinalStatements[lStatementIndex].Status, lSnapshotPlan.FinalStatements[lStatementIndex].Status);
    Assert.AreEqual(lPlan.FinalStatements[lStatementIndex].Reason, lSnapshotPlan.FinalStatements[lStatementIndex].Reason);
    Assert.AreEqual(lPlan.FinalStatements[lStatementIndex].SafetyReason, lSnapshotPlan.FinalStatements[lStatementIndex].SafetyReason);
    Assert.AreEqual(lPlan.FinalStatements[lStatementIndex].ReplacementText, lSnapshotPlan.FinalStatements[lStatementIndex].ReplacementText);
  end;
end;
procedure ControlCase(const aShape: string);
var
  lHelper, lBody, lSource, lTarget: string;
  lTypeA, lTypeB, lHelperModel, lConsumer: TDelphiSemanticUnitModel;
begin
  lHelper := '  &THelp = record helper for %s'#13#10 +
    '    function Count: Integer;'#13#10'  end;'#13#10;
  lBody := 'procedure Run;'#13#10'var'#13#10'  lRecord: %s;'#13#10'  Count: Integer;'#13#10 +
    'begin'#13#10'  with lRecord do Count := 1;'#13#10'end;'#13#10;
  if MatchText(aShape, ['same-name', 'private-import', 'import', 'indexed-import']) then
  begin
    lTypeA := Unit_('TypesA', 'unit TypesA;'#13#10'interface'#13#10 +
      'type TRec = record Value: Integer; end;'#13#10'implementation'#13#10'end.');
    lTypeB := Unit_('TypesB', 'unit TypesB;'#13#10'interface'#13#10 +
      'type TRec = record Value: Integer; end;'#13#10'implementation'#13#10'end.');
    if aShape = 'private-import' then
      lSource := 'unit Helpers;'#13#10'interface'#13#10'implementation'#13#10 +
        'uses TypesA;'#13#10'type'#13#10
    else
      lSource := 'unit Helpers;'#13#10'interface'#13#10'uses TypesA;'#13#10'type'#13#10;
    if aShape = 'indexed-import' then
      lSource := lSource + '  THelp = record helper for TypesA.TRec'#13#10 +
        '    function Count: Integer;'#13#10'  end;'#13#10
    else
      lSource := lSource + Format(lHelper, ['TypesA.TRec']);
    if aShape <> 'private-import' then
      lSource := lSource + 'implementation'#13#10;
    lHelperModel := Unit_('Helpers', lSource + 'function ' +
      IfThen(aShape = 'indexed-import', '', '&') +
      'THelp.Count: Integer;'#13#10'begin Result := 1; end;'#13#10'end.');
    lTarget := 'TypesA.TRec';
    if aShape = 'same-name' then
      lTarget := 'TypesB.TRec';
    lConsumer := Unit_('Consumer', 'unit Consumer;'#13#10'interface'#13#10 +
      'uses TypesA, TypesB, Helpers;'#13#10'implementation'#13#10 +
      Format(lBody, [lTarget]) + 'end.');
    Report(aShape, [lConsumer, lTypeA, lTypeB, lHelperModel]);
  end else begin
    lSource := 'unit Consumer;'#13#10'interface'#13#10'type'#13#10 +
      '  TRec = record Value: Integer; end;'#13#10 +
      '  TOther = record Value: Integer; end;'#13#10;
    lTarget := 'TRec';
    if aShape = 'unrelated' then
      lTarget := 'TOther';
    if not MatchText(aShape, ['after-site', 'no-helper']) then
      lSource := lSource + Format(lHelper, [lTarget]);
    lSource := lSource + 'implementation'#13#10;
    if aShape = 'call' then
      lSource := lSource + 'procedure Count;'#13#10'begin'#13#10'end;'#13#10 +
        'procedure Run;'#13#10'var'#13#10'  lRecord: TRec;'#13#10'begin'#13#10 +
        '  with lRecord do Count();'#13#10'end;'#13#10
    else if MatchText(aShape, ['intrinsic', 'no-helper']) then
      lSource := lSource + 'procedure Run;'#13#10'var'#13#10'  lRecord: TRec;'#13#10 +
        '  lSize: Integer;'#13#10'begin'#13#10 +
        '  with lRecord do begin FillChar(Value, SizeOf(Value), 0); lSize := SizeOf(TRec); end;'#13#10 +
        'end;'#13#10
    else if aShape = 'local-array' then
      lSource := lSource + 'procedure Run;'#13#10'var'#13#10'  lRecord: TRec;'#13#10 +
        '  lArr: array[0..1] of Integer;'#13#10'begin'#13#10 +
        '  with lRecord do lArr[0] := Value;'#13#10 +
        'end;'#13#10
    else
      lSource := lSource + Format(lBody, ['TRec']);
    if aShape = 'after-site' then
      lSource := lSource + 'type'#13#10 + Format(lHelper, [lTarget]);
    lConsumer := Unit_('Consumer', lSource + IfThen(aShape = 'no-helper', '',
      'function &THelp.Count: Integer;'#13#10'begin Result := 1; end;'#13#10) + 'end.');
    Report(aShape, [lConsumer]);
  end;
end;


procedure ExtraCase(const aShape: string);
var
  lSource: string;
begin
  lSource := 'unit Consumer;'#13#10'interface'#13#10'type'#13#10 +
    '  TRec = record Value: Integer; end;'#13#10 +
    '  TAlias = TRec;'#13#10;
  if aShape = 'alias-receiver' then
    lSource := lSource + '  &THelp = record helper for TRec'#13#10'    function Count: Integer;'#13#10'  end;'#13#10
  else if aShape = 'alias-target' then
    lSource := lSource + '  &THelp = record helper for TAlias'#13#10'    function Count: Integer;'#13#10'  end;'#13#10
  else if aShape = 'class-helper' then
    lSource := lSource + '  &THelp = class helper for TObject'#13#10'    function Count: Integer;'#13#10'  end;'#13#10
  else
    lSource := lSource + '  &THelp = record helper for TRec'#13#10'    function Count: Integer;'#13#10'  end;'#13#10;
  lSource := lSource + 'implementation'#13#10;
  if aShape = 'alias-receiver' then
    lSource := lSource + 'procedure Run;'#13#10'var'#13#10'  lRecord: TAlias;'#13#10'  Count: Integer;'#13#10 +
      'begin'#13#10'  with lRecord do Count := 1;'#13#10'end;'#13#10
  else if aShape = 'local-alias' then
    lSource := lSource + 'procedure Run;'#13#10'type'#13#10'  TLocal = TRec;'#13#10'var'#13#10 +
      '  lRecord: TLocal;'#13#10'  Count: Integer;'#13#10 +
      'begin'#13#10'  with lRecord do Count := 1;'#13#10'end;'#13#10
  else if aShape = 'nested' then
    lSource := lSource + 'type'#13#10'  TOuter = record Inner: TRec; Other: Integer; end;'#13#10 +
      'procedure Run;'#13#10'var'#13#10'  lOuter: TOuter;'#13#10'  Count: Integer;'#13#10 +
      'begin'#13#10'  with lOuter do with Inner do Count := Other;'#13#10'end;'#13#10
  else
    lSource := lSource + 'procedure Run;'#13#10'var'#13#10'  lRecord: TRec;'#13#10'  Count: Integer;'#13#10 +
      'begin'#13#10'  with lRecord do Count := 1;'#13#10'end;'#13#10;
  Report('extra-' + aShape, [Unit_('Consumer', lSource +
    'function &THelp.Count: Integer;'#13#10'begin Result := 1; end;'#13#10'end.')]);
end;
begin
  lRoot := WithBinderTempPath('DS720-' + aShape);
  TDirectory.CreateDirectory(lRoot);
  if MatchText(aShape, ['alias-receiver', 'alias-target', 'local-alias', 'nested', 'class-helper']) then
  begin
    ExtraCase(aShape);
  end else begin
    ControlCase(aShape);
  end;
end;

procedure TWithBinderTests.UnindexedRecordHelperShieldsLexicalHomonym(const aShape: string);
var
  lDiagnostic: TDelphiSemanticModelDiagnostic;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lModel: TDelphiSemanticUnitModel;
  lPlan: TDelphiSemanticRemoveWithPlan;
  lOptions: TDelphiSemanticModelOptions;
  lReference: TDelphiSemanticBoundReference;
  lSelector: string;
  lFound: Boolean;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.ProjectContextApplied := True;
  lOptions.SourceFileName := WithBinderTempPath('RecordHelper-' + aShape + '.pas');
  lSelector := 'lRecord';
  if aShape = 'indexed' then
    lSelector := 'lItems[0]'
  else if aShape = 'pointer' then
    lSelector := 'lPointer^';
  TFile.WriteAllText(lOptions.SourceFileName,
    'unit RecordHelper;'#13#10'interface'#13#10 +
    IfThen(aShape = 'import', 'uses MissingHelperUnit;'#13#10, '') + 'type'#13#10 +
    '  TRec = record Value: Integer; end;'#13#10'  PRec = ^TRec;'#13#10 +
    '  &TRecHelper = record helper for TRec'#13#10 +
    '    function Count: Integer;'#13#10'  end;'#13#10 +
    'var Count: Integer;'#13#10'implementation'#13#10 +
    'function &TRecHelper.Count: Integer;'#13#10'begin Result := 1; end;'#13#10 +
    'procedure Run;'#13#10 +
    'var'#13#10'  lRecord: TRec;'#13#10'  lItems: array[0..0] of TRec;'#13#10 +
    '  lPointer: PRec;'#13#10'  Count: Integer;'#13#10 +
    'begin'#13#10'  with ' + lSelector + ' do Count := 1;'#13#10 +
    'end;'#13#10'end.', TEncoding.ASCII);
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);
  Assert.AreEqual('ast', lModel.ScopeModelStatus);
  lFound := False;
  for lDiagnostic in lModel.Diagnostics do
    if lDiagnostic.Code = 'AST_HELPER_DECLARATION_UNINDEXED' then
      lFound := True;
  Assert.IsTrue(lFound, 'The regression requires a real unindexed record helper.');
  lFacts := TDelphiSemanticWithBinder.BindProject('record-helper-' + aShape, nil, [lModel]);
  Assert.AreEqual(1, Integer(Length(lFacts.Bindings)));
  Assert.AreEqual('resolved', lFacts.Bindings[0].Selectors[0].Status);
  Assert.AreEqual('unit', lFacts.Bindings[0].Selectors[0].TypeIdentity.ScopeKind);
  TFile.WriteAllText(WithBinderTempPath('record-helper-model-' + aShape + '.json'),
    ModelToJson(lModel), TEncoding.UTF8);
  lFound := False;
  for lReference in lFacts.Bindings[0].References do
    if SameText(lReference.Name, 'Count') then
    begin
      lFound := True;
      Assert.AreEqual('unsupported', lReference.Classification);
      Assert.AreEqual('RECORD_HELPER_MEMBERS_UNVERIFIED', lReference.ReasonCode);
    end;
  Assert.IsTrue(lFound);
  if aShape = 'record' then
  begin
    lPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWith(lFacts);
    Assert.AreEqual(1, Integer(Length(lPlan.FinalStatements)));
    Assert.AreEqual('skipped', lPlan.FinalStatements[0].Status,
      'An unindexed helper refusal must not bind the lexical Count in final planning.');
    Assert.AreEqual('receiver-member-not-found', lPlan.FinalStatements[0].Reason);
    Assert.AreEqual(0, Integer(Length(lPlan.FinalStatements[0].Edits)));
  end;
end;

procedure TWithBinderTests.RootAbsenceProviderFailureKeepsBindingUnsupported(const aMode: string);
var
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lProvider: IDelphiSemanticImplicitRootMemberAbsence;
  lReference: TDelphiSemanticBoundReference;
  lFound: Boolean;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.ProjectContextApplied := True;
  lOptions.SourceFileName := WithBinderTempPath('ProviderFailure-' + aMode + '.pas');
  TFile.WriteAllText(lOptions.SourceFileName,
    'unit ProviderFailure;'#13#10'interface'#13#10 +
    'type TChild = class end;'#13#10'var lChild: TChild; lPair: Integer;'#13#10 +
    'implementation'#13#10'procedure Run;'#13#10'begin'#13#10 +
    '  with lChild do lPair := 1;'#13#10'end;'#13#10'end.', TEncoding.ASCII);
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);
  lProvider := TThrowingRootAbsenceProvider.Create(aMode);
  try
    lFacts := TDelphiSemanticWithBinder.BindProject('provider-failure-' + aMode,
      nil, [lModel], lProvider);
  except
    on E: Exception do
      Assert.Fail('A failing provider aborted binding: ' + E.Message);
  end;
  Assert.AreEqual(1, Integer(Length(lFacts.Bindings)));
  lFound := False;
  for lReference in lFacts.Bindings[0].References do
    if SameText(lReference.Name, 'lPair') then
    begin
      lFound := True;
      Assert.AreEqual('unsupported', lReference.Classification);
      Assert.AreEqual('OWNER_INHERITED_MEMBERS_UNVERIFIED', lReference.ReasonCode);
    end;
  Assert.IsTrue(lFound);
end;

procedure TWithBinderTests.LocalLineageNeverBorrowsUnitTypeIdentity(const aShape: string);
var
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lReference: TDelphiSemanticBoundReference;
  lSelector: string;
  lFound: Boolean;
begin
  lSelector := 'lItems[0]';
  if aShape = 'pointer' then
    lSelector := 'lPointer^';
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.ProjectContextApplied := True;
  lOptions.SourceFileName := WithBinderTempPath('LocalLineage-' + aShape + '.pas');
  TFile.WriteAllText(lOptions.SourceFileName,
    'unit LocalLineage;'#13#10'interface'#13#10 +
    'type TBase = class OtherValue: Integer; end;'#13#10 +
    '  TChild = class(TBase) end;'#13#10 +
    'var LeftOnly: Integer;'#13#10'implementation'#13#10'procedure Execute;'#13#10 +
    'type TBase = class LeftOnly: Integer; end;'#13#10 +
    '  TChild = class(TBase) end;'#13#10'  PChild = ^TChild;'#13#10 +
    'var lItems: array[0..0] of TChild; lPointer: PChild;'#13#10'begin'#13#10 +
    '  with ' + lSelector + ' do LeftOnly := 1;'#13#10'end;'#13#10'end.', TEncoding.ASCII);
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);
  lFacts := TDelphiSemanticWithBinder.BindProject('local-lineage-' + aShape,
    nil, [lModel], TImplicitRootAbsenceStub.Create);
  Assert.AreEqual(1, Integer(Length(lFacts.Bindings)));
  lFound := False;
  for lReference in lFacts.Bindings[0].References do
    if SameText(lReference.Name, 'LeftOnly') then
    begin
      lFound := True;
      Assert.AreNotEqual('lexical', lReference.Classification,
        'A unit-level namesake cannot prove absence on the local base class.');
      Assert.AreNotEqual('unresolved', lReference.Classification);
    end;
  Assert.IsTrue(lFound);
end;

procedure TWithBinderTests.RootAbsenceNeverOverridesIndexedLineage(const aShape: string);
var
  lBinding: TDelphiSemanticWithBinding;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lProvider: IDelphiSemanticImplicitRootMemberAbsence;
  lReference: TDelphiSemanticBoundReference;
  lSelector: string;
  lText: string;
  lFound: Boolean;
begin
  lText := 'unit RootLineage;'#13#10'interface'#13#10'type'#13#10;
  if aShape = 'overload' then
    lText := lText + '  TBase = class'#13#10'  public'#13#10 +
      '    procedure LeftOnly(aValue: string); overload;'#13#10 +
      '    procedure LeftOnly(aValue: Integer); overload;'#13#10'  end;'#13#10
  else
    lText := lText + '  TBase = class LeftOnly: Integer; end;'#13#10;
  lText := lText + '  TChild = class(TBase)'#13#10'  end;'#13#10 +
    '  PChild = ^TChild;'#13#10;
  if aShape = 'overload' then
    lText := lText + 'procedure LeftOnly;'#13#10
  else
    lText := lText + 'var LeftOnly: Integer;'#13#10;
  lText := lText + 'implementation'#13#10;
  if aShape = 'overload' then
    lText := lText + 'procedure TBase.LeftOnly(aValue: string);'#13#10'begin'#13#10'end;'#13#10 +
      'procedure TBase.LeftOnly(aValue: Integer);'#13#10'begin'#13#10'end;'#13#10 +
      'procedure LeftOnly;'#13#10'begin'#13#10'end;'#13#10;
  lText := lText + 'procedure Execute;'#13#10 +
    'var lChild: TChild; lItems: array[0..0] of TChild; lPointer: PChild;'#13#10 +
    'begin'#13#10;
  lSelector := 'lChild';
  if aShape = 'indexed' then
    lSelector := 'lItems[0]'
  else if aShape = 'pointer' then
    lSelector := 'lPointer^';
  if aShape = 'overload' then
    lText := lText + '  with ' + lSelector + ' do LeftOnly;'#13#10
  else
    lText := lText + '  with ' + lSelector + ' do LeftOnly := 1;'#13#10;
  lText := lText + 'end;'#13#10'end.'#13#10;
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.ProjectContextApplied := True;
  lOptions.SourceFileName := WithBinderTempPath('RootLineage-' + aShape + '.pas');
  TFile.WriteAllText(lOptions.SourceFileName, lText, TEncoding.ASCII);
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);
  lProvider := TImplicitRootAbsenceStub.Create;
  lFacts := TDelphiSemanticWithBinder.BindProject('root-lineage-' + aShape,
    nil, [lModel], lProvider);
  Assert.AreEqual(1, Integer(Length(lFacts.Bindings)));
  lBinding := lFacts.Bindings[0];
  lFound := False;
  for lReference in lBinding.References do
    if SameText(lReference.Name, 'LeftOnly') then
    begin
      lFound := True;
      Assert.AreEqual('unsupported', lReference.Classification,
        'Indexed lineage evidence must shield the lexical homonym.');
      if aShape = 'pointer' then
        Assert.AreEqual('SELECTOR_MEMBERS_UNVERIFIED', lReference.ReasonCode)
      else
      Assert.AreEqual('OWNER_INHERITED_MEMBERS_UNVERIFIED', lReference.ReasonCode);
    end;
  Assert.IsTrue(lFound);
end;

procedure TWithBinderTests.CompilerRoutineInWithBodyUsesIntrinsicFallback(const aName: string);
var
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := WithBinderTempPath('CompilerRoutine' + aName + '.pas');
  TFile.WriteAllText(lOptions.SourceFileName,
    'unit CompilerRoutine' + aName + ';' + sLineBreak +
    'interface' + sLineBreak +
    'type TReceiver = record Value: Integer; end;' + sLineBreak +
    'var Receiver: TReceiver;' + sLineBreak +
    'implementation' + sLineBreak +
    'procedure Run;' + sLineBreak +
    'begin' + sLineBreak +
    '  with Receiver do Value := ' + aName + '(Value);' + sLineBreak +
    'end;' + sLineBreak + 'end.', TEncoding.UTF8);
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);
  lBindings := TDelphiSemanticWithBinder.BindModel(lModel);
  Assert.AreEqual(1, Integer(Length(lBindings)));
  Assert.IsTrue(HasReference(lBindings[0], 'Value', 'member'));
  Assert.IsTrue(HasReference(lBindings[0], aName, 'intrinsic'), aName);
  Assert.AreEqual('planned', lBindings[0].Status);
end;

procedure TWithBinderTests.ConditionalWithBodyOnlyBindsActiveReferences(const aActive: Boolean);
var
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lReference: TDelphiSemanticBoundReference;
  lValueCount: Integer;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := WithBinderTempPath('ConditionalWith' + BoolToStr(aActive, True) + '.pas');
  if aActive then
    lOptions.Defines := ['ENABLE_MISSING'];
  TFile.WriteAllText(lOptions.SourceFileName,
    'unit ConditionalWith;' + sLineBreak +
    'interface' + sLineBreak +
    'type TReceiver = record Value: Integer; end;' + sLineBreak +
    'var Receiver: TReceiver;' + sLineBreak +
    'implementation' + sLineBreak +
    'procedure Run;' + sLineBreak +
    'begin' + sLineBreak +
    '  with Receiver do' + sLineBreak +
    '  begin' + sLineBreak +
    '    Value := 1;' + sLineBreak +
    '    {$IFDEF ENABLE_MISSING}' + sLineBreak +
    '    MissingName := 2;' + sLineBreak +
    '    {$ENDIF}' + sLineBreak +
    '    Value := 3;' + sLineBreak +
    '  end;' + sLineBreak +
    'end;' + sLineBreak + 'end.', TEncoding.UTF8);
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);
  Assert.AreEqual(TFile.ReadAllText(lOptions.SourceFileName, TEncoding.UTF8), lModel.SourceText,
    'The original source remains available for rendering and byte verification.');
  lModel := JsonToModel(ModelToJson(lModel));
  lBindings := TDelphiSemanticWithBinder.BindModel(lModel);
  Assert.AreEqual(1, Integer(Length(lBindings)));
  Assert.IsTrue(HasReference(lBindings[0], 'Value', 'member'));
  lValueCount := 0;
  for lReference in lBindings[0].References do
    if SameText(lReference.Name, 'Value') and SameText(lReference.Classification, 'member') then
    begin
      if lValueCount = 0 then
        Assert.AreEqual(10, lReference.Line)
      else
        Assert.AreEqual(14, lReference.Line);
      Assert.AreEqual(5, lReference.Column);
      Inc(lValueCount);
    end;
  Assert.AreEqual(2, lValueCount, 'Active references keep their original physical coordinates.');
  if aActive then
  begin
    Assert.IsTrue(HasReference(lBindings[0], 'MissingName', 'unresolved'));
    Assert.AreEqual('skipped', lBindings[0].Status);
  end else begin
    Assert.IsFalse(HasAnyReference(lBindings[0], 'MissingName'),
      'Inactive source must not regain references during coordinate reconciliation.');
    // Round 23: the public refusal retains the base reason; inactive detail is separate.
    Assert.AreEqual('skipped', lBindings[0].Status);
    Assert.AreEqual('UNRESOLVED_REFERENCE', lBindings[0].SkipReason);
    Assert.AreEqual('UNRESOLVED_REFERENCE', lBindings[0].InactiveSpanSkipReason);
  end;
end;

procedure TWithBinderTests.QualifiedPointerFieldNeverBindsToWithHomonym(const aShape: string);
var
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lExpression: string;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
begin
  lExpression := 'p^.n';
  if SameText(aShape, 'homonym') then
    lExpression := lExpression + ' + n'
  else if SameText(aShape, 'range') then
    lExpression := lExpression + '; if Value in [1..n] then Value := 1'
  else if SameText(aShape, 'unknown') then
    lExpression := 'MissingPointer^.n';
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := WithBinderTempPath('QualifiedPointer' + aShape + '.pas');
  TFile.WriteAllText(lOptions.SourceFileName,
    'unit QualifiedPointer' + aShape + ';' + sLineBreak +
    'interface' + sLineBreak +
    'type TNode = record n: Integer; end;' + sLineBreak +
    '  TReceiver = record Value, n: Integer; end;' + sLineBreak +
    'var Receiver: TReceiver;' + sLineBreak +
    'implementation' + sLineBreak +
    'procedure Run;' + sLineBreak +
    'var p: ^TNode;' + sLineBreak +
    'begin' + sLineBreak +
    '  with Receiver do' + sLineBreak +
    '  begin' + sLineBreak +
    '    Value := ' + lExpression + ';' + sLineBreak +
    '  end;' + sLineBreak +
    'end;' + sLineBreak + 'end.', TEncoding.UTF8);
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);
  lBindings := TDelphiSemanticWithBinder.BindModel(lModel);
  Assert.AreEqual(1, Integer(Length(lBindings)));
  Assert.IsTrue(HasReference(lBindings[0], 'Value', 'member'));
  if SameText(aShape, 'homonym') or SameText(aShape, 'range') then
  begin
    Assert.AreEqual(1, CountReferences(lBindings[0], 'n'),
      'Only the bare n may bind to the WITH receiver.');
    Assert.IsTrue(HasReference(lBindings[0], 'n', 'member'));
  end else
    Assert.IsFalse(HasAnyReference(lBindings[0], 'n'),
      'The explicitly qualified field must retain its own receiver.');
  if SameText(aShape, 'unknown') then
  begin
    Assert.IsTrue(HasReference(lBindings[0], 'MissingPointer', 'unresolved'));
    Assert.AreEqual('skipped', lBindings[0].Status);
  end else begin
    Assert.IsTrue(HasReference(lBindings[0], 'p', 'lexical'));
    Assert.AreEqual('planned', lBindings[0].Status);
  end;
end;

procedure TWithBinderTests.IntrinsicFallbackPreservesNamePrecedenceAndUnknownRefusal(
  const aShape: string);
var
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lMemberText: string;
  lModel: TDelphiSemanticUnitModel;
  lName: string;
  lOptions: TDelphiSemanticModelOptions;
  lVariableText: string;
begin
  lMemberText := '';
  lVariableText := '';
  lName := 'SizeOf';
  if SameText(aShape, 'member') then
    lMemberText := ' SizeOf: Integer;'
  else if SameText(aShape, 'lexical') then
    lVariableText := 'var SizeOf: Integer;' + sLineBreak
  else
    lName := 'MissingCompilerRoutine';
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := WithBinderTempPath('IntrinsicPrecedence' + aShape + '.pas');
  TFile.WriteAllText(lOptions.SourceFileName,
    'unit IntrinsicPrecedence' + aShape + ';' + sLineBreak +
    'interface' + sLineBreak +
    'type TReceiver = record Value: Integer;' + lMemberText + ' end;' + sLineBreak +
    'var Receiver: TReceiver;' + sLineBreak + lVariableText +
    'implementation' + sLineBreak +
    'procedure Run;' + sLineBreak +
    'begin' + sLineBreak +
    '  with Receiver do Value := ' + lName + ';' + sLineBreak +
    'end;' + sLineBreak + 'end.', TEncoding.UTF8);
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);
  lBindings := TDelphiSemanticWithBinder.BindModel(lModel);
  Assert.AreEqual(1, Integer(Length(lBindings)));
  Assert.IsFalse(HasReference(lBindings[0], lName, 'intrinsic'));
  if SameText(aShape, 'unknown') then
  begin
    Assert.IsTrue(HasReference(lBindings[0], lName, 'unresolved'));
    Assert.AreEqual('NAME_NOT_FOUND', ReasonOf(lBindings[0], lName, 'unresolved'));
    Assert.AreEqual('skipped', lBindings[0].Status);
  end else begin
    Assert.IsTrue(HasReference(lBindings[0], lName, aShape));
    Assert.AreEqual('planned', lBindings[0].Status);
  end;
end;

procedure TWithBinderTests.NestedLocalReceiverKeepsSourceScopeAndIdentity;
var
  lBinding: TDelphiSemanticWithBinding;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lOptions: TDelphiSemanticApiOptions;
  lSeenNested: Boolean;
begin
  lOptions := Default(TDelphiSemanticApiOptions);
  lOptions.ProjectFileName := FixturePath('RemoveWithLocalCaptureType',
    'LocalReceiver.dproj');
  lFacts := TDelphiSemanticRemoveWithCompatibilityApi.BuildProjectWithBindingFacts(
    lOptions);
  lSeenNested := False;
  for lBinding in lFacts.Bindings do
    if SameText(ExtractFileName(lBinding.FileName), 'LocalConsumer.pas') and
      (lBinding.Line = 37) then
    begin
      lSeenNested := True;
      Assert.IsNotEmpty(lBinding.RoutineScopeId);
      Assert.AreEqual(1, Integer(Length(lBinding.Selectors)));
      Assert.AreEqual('resolved', lBinding.Selectors[0].Status);
      Assert.AreEqual('TOuter', lBinding.Selectors[0].TypeIdentity.Name);
      Assert.AreEqual('routine', lBinding.Selectors[0].TypeIdentity.ScopeKind);
      Assert.IsNotEmpty(lBinding.Selectors[0].TypeIdentity.OwnerScopeId);
      Assert.IsNotEmpty(lBinding.Selectors[0].TypeIdentity.SemanticSymbolId);
      Assert.AreNotEqual(lBinding.RoutineScopeId,
        lBinding.Selectors[0].TypeIdentity.OwnerScopeId,
        'The receiver type belongs to the enclosing routine.');
    end;
  Assert.IsTrue(lSeenNested, 'The source-backed nested WITH must be discovered.');
end;

procedure TWithBinderTests.LocalPointerPointeeShadowsImportedUnitHomonym;
var
  lBinding: TDelphiSemanticWithBinding;
  lConsumerModel: TDelphiSemanticUnitModel;
  lDeclaration: TDelphiSemanticDeclaration;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lGuid: TGUID;
  lGuidText: string;
  lLocal: TDelphiSemanticLocal;
  lLocalType: TDelphiSemanticDeclaration;
  lMember: TDelphiSemanticMember;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticApiOptions;
  lProjectPath: string;
  lProviderTypeCount: Integer;
  lRoot: string;
  lSeenBinding: Boolean;
  lSeenConsumer: Boolean;
  lSeenLocalMember: Boolean;
  lSeenLocalType: Boolean;
  lSeenPointer: Boolean;
  lSeenProvider: Boolean;
  lSeenProviderUse: Boolean;
  lSeenSymbol: Boolean;
  lSymbol: TDelphiSemanticInventorySymbol;
  lUsedUnit: string;
begin
  CreateGUID(lGuid);
  lGuidText := StringReplace(StringReplace(GUIDToString(lGuid), '{', '', [rfReplaceAll]),
    '}', '', [rfReplaceAll]);
  lRoot := WithBinderTempPath('local-pointer-homonym-' + lGuidText);
  TDirectory.CreateDirectory(lRoot);
  lProjectPath := TPath.Combine(lRoot, 'PointerScopeHomonym.dproj');
  TFile.WriteAllText(TPath.Combine(lRoot, 'PointerScopeHomonym.dpr'),
    'program PointerScopeHomonym;'#13#10 +
    'uses LocalPointerConsumer in ''LocalPointerConsumer.pas'';'#13#10 +
    'begin'#13#10'end.'#13#10, TEncoding.ASCII);
  TFile.WriteAllText(lProjectPath,
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' +
    '<PropertyGroup><MainSource>PointerScopeHomonym.dpr</MainSource></PropertyGroup>' +
    '<ItemGroup><DCCReference Include="LocalPointerProvider.pas"/>' +
    '<DCCReference Include="LocalPointerConsumer.pas"/></ItemGroup></Project>',
    TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'LocalPointerProvider.pas'),
    'unit LocalPointerProvider;'#13#10 +
    'interface'#13#10 +
    'type TNode = record UnitOnly: Integer; end;'#13#10 +
    'implementation'#13#10'end.'#13#10, TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'LocalPointerConsumer.pas'),
    'unit LocalPointerConsumer;'#13#10 +
    'interface'#13#10 +
    'procedure Run;'#13#10 +
    'implementation'#13#10 +
    'uses LocalPointerProvider;'#13#10 +
    'procedure Run;'#13#10 +
    'type TNode = record LocalOnly: Integer; end;'#13#10 +
    'var'#13#10 +
    '  lNode: TNode;'#13#10 +
    '  lPointer: ^TNode;'#13#10 +
    '  procedure Nested;'#13#10 +
    '  begin'#13#10 +
    '    with lPointer^ do LocalOnly := 1;'#13#10 +
    '  end;'#13#10 +
    'begin'#13#10 +
    '  lPointer := @lNode;'#13#10 +
    '  Nested;'#13#10 +
    'end;'#13#10 +
    'end.'#13#10, TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticApiOptions);
  lOptions.ProjectFileName := lProjectPath;
  lFacts := TDelphiSemanticRemoveWithCompatibilityApi.BuildProjectWithBindingFacts(lOptions);
  lConsumerModel := Default(TDelphiSemanticUnitModel);
  lSeenConsumer := False;
  lSeenProvider := False;
  lSeenProviderUse := False;
  lProviderTypeCount := 0;
  for lModel in lFacts.UnitModels do
  begin
    if SameText(lModel.UnitName, 'LocalPointerConsumer') then
    begin
      lConsumerModel := lModel;
      lSeenConsumer := True;
      for lUsedUnit in lModel.ImplementationUses do
        if SameText(lUsedUnit, 'LocalPointerProvider') then
          lSeenProviderUse := True;
    end else if SameText(lModel.UnitName, 'LocalPointerProvider') then
    begin
      lSeenProvider := True;
      for lDeclaration in lModel.Declarations do
        if SameText(lDeclaration.Name, 'TNode') and
          SameText(lDeclaration.ScopeKind, 'unit') then
          Inc(lProviderTypeCount);
    end;
  end;
  Assert.IsTrue(lSeenConsumer and lConsumerModel.Success, 'Actual consumer AST model');
  Assert.IsTrue(lSeenProvider and lSeenProviderUse and (lProviderTypeCount = 1),
    'The imported unit homonym must be present and visible to the consumer.');
  lLocalType := Default(TDelphiSemanticDeclaration);
  lSeenLocalType := False;
  for lDeclaration in lConsumerModel.Declarations do
    if SameText(lDeclaration.Name, 'TNode') and
      SameText(lDeclaration.ScopeKind, 'routine') then
    begin
      Assert.IsFalse(lSeenLocalType, 'Only one local TNode should be declared.');
      lLocalType := lDeclaration;
      lSeenLocalType := True;
    end;
  Assert.IsTrue(lSeenLocalType, 'The actual AST must retain the local declaration.');
  Assert.IsNotEmpty(lLocalType.OwnerScopeId);
  Assert.IsNotEmpty(lLocalType.SymbolId);
  lSeenPointer := False;
  for lLocal in lConsumerModel.Locals do
    if SameText(lLocal.Name, 'lPointer') then
    begin
      Assert.IsFalse(lSeenPointer, 'Only one pointer local should be extracted.');
      Assert.AreEqual('Run', lLocal.RoutineName);
      Assert.AreEqual('^TNode', lLocal.TypeName);
      Assert.AreEqual(lLocalType.OwnerScopeId, lLocal.RoutineScopeId);
      Assert.IsTrue(lLocal.Line > 0, 'The pointer local needs a source position.');
      lSeenPointer := True;
    end;
  Assert.IsTrue(lSeenPointer, 'The actual model must extract the pointer local.');
  lSeenLocalMember := False;
  for lMember in lConsumerModel.Members do
    if SameText(lMember.Name, 'LocalOnly') then
    begin
      Assert.AreEqual(lLocalType.OwnerScopeId, lMember.OwnerScopeId);
      Assert.AreEqual(lLocalType.SymbolId, lMember.OwnerSymbolId);
      lSeenLocalMember := True;
    end;
  Assert.IsTrue(lSeenLocalMember, 'The local member must retain its AST owner.');
  lSeenBinding := False;
  for lBinding in lFacts.Bindings do
    if SameText(lBinding.UnitName, 'LocalPointerConsumer') and
      SameText(lBinding.RoutineName, 'Nested') and
      SameText(lBinding.SelectorText, 'lPointer^') then
    begin
      Assert.IsFalse(lSeenBinding, 'Only one nested pointer WITH should be bound.');
      lSeenBinding := True;
      Assert.AreEqual(1, Integer(Length(lBinding.Selectors)));
      Assert.AreEqual('resolved', lBinding.Selectors[0].Status,
        lBinding.Selectors[0].ReasonCode);
      Assert.AreEqual('LocalPointerConsumer',
        lBinding.Selectors[0].TypeIdentity.UnitName);
      Assert.AreEqual('routine', lBinding.Selectors[0].TypeIdentity.ScopeKind);
      Assert.AreEqual(lLocalType.OwnerScopeId,
        lBinding.Selectors[0].TypeIdentity.OwnerScopeId);
      Assert.AreEqual(lLocalType.SymbolId,
        lBinding.Selectors[0].TypeIdentity.SemanticSymbolId);
      Assert.AreEqual(TPath.Combine(lRoot, 'LocalPointerConsumer.pas'),
        lBinding.Selectors[0].TypeIdentity.SourceRange.FileName);
      Assert.AreEqual('TNode', ReceiverOf(lBinding, 'LocalOnly', 'member'));
      Assert.IsFalse(HasReference(lBinding, 'UnitOnly', 'member'));
    end;
  Assert.IsTrue(lSeenBinding, 'The source-backed nested pointer WITH must be found.');
  lSeenSymbol := False;
  for lSymbol in lFacts.Symbols do
    if SameText(lSymbol.UnitName, 'LocalPointerConsumer') and
      SameText(lSymbol.Name, 'LocalOnly') and
      SameText(lSymbol.SymbolClass, 'field') then
    begin
      Assert.AreEqual(lLocalType.OwnerScopeId, lSymbol.OwnerIdentity.OwnerScopeId);
      Assert.AreEqual(lLocalType.SymbolId, lSymbol.OwnerIdentity.SemanticSymbolId);
      lSeenSymbol := True;
    end;
  Assert.IsTrue(lSeenSymbol, 'The receiver member must use the local owner identity.');
end;

function BuildPointerAliasScopeModel: TDelphiSemanticUnitModel;
var
  lGuid: TGUID;
  lGuidText: string;
  lOptions: TDelphiSemanticModelOptions;
  lRoot: string;
begin
  CreateGUID(lGuid);
  lGuidText := StringReplace(StringReplace(GUIDToString(lGuid), '{', '', [rfReplaceAll]),
    '}', '', [rfReplaceAll]);
  lRoot := WithBinderTempPath('pointer-alias-scope-' + lGuidText);
  TDirectory.CreateDirectory(lRoot);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := TPath.Combine(lRoot, 'PointerAliasScope.pas');
  lOptions.ProjectContextApplied := True;
  TFile.WriteAllText(lOptions.SourceFileName,
    'unit PointerAliasScope;'#13#10 +
    'interface'#13#10 +
    'type'#13#10 +
    '  TNode = record UnitOnly: Integer; end;'#13#10 +
    '  PUnitNode = ^TNode;'#13#10 +
    'procedure UnitAliasRun(aItem: PUnitNode);'#13#10 +
    'procedure LocalAliasRun;'#13#10 +
    'implementation'#13#10 +
    'procedure UnitAliasRun(aItem: PUnitNode);'#13#10 +
    'type TNode = record LocalOnly: Integer; end;'#13#10 +
    'begin'#13#10 +
    '  with aItem^ do UnitOnly := 1;'#13#10 +
    'end;'#13#10 +
    'procedure LocalAliasRun;'#13#10 +
    'type'#13#10 +
    '  TNode = record LocalOnly: Integer; end;'#13#10 +
    '  PLocalNode = ^TNode;'#13#10 +
    'var'#13#10 +
    '  lItem: PLocalNode;'#13#10 +
    'begin'#13#10 +
    '  with lItem^ do LocalOnly := 1;'#13#10 +
    'end;'#13#10 +
    'end.'#13#10, TEncoding.ASCII);
  Result := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(Result.Success, 'The pointer alias fixture must extract from source.');
end;

procedure TWithBinderTests.PointerAliasesResolvePointeesFromTheirDeclarationScopes;
var
  lBinding: TDelphiSemanticWithBinding;
  lDeclaration: TDelphiSemanticDeclaration;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lLocalScopeId: string;
  lModel: TDelphiSemanticUnitModel;
  lRoutine: TDelphiSemanticRoutine;
  lSeenLocal: Boolean;
  lSeenUnit: Boolean;
  lUnitNodeId: string;
  lLocalNodeId: string;
begin
  lModel := BuildPointerAliasScopeModel;
  lUnitNodeId := '';
  lLocalNodeId := '';
  lLocalScopeId := '';
  for lRoutine in lModel.Routines do
    if SameText(lRoutine.Name, 'LocalAliasRun') and
      SameText(lRoutine.SectionKind, 'implementation') then
      lLocalScopeId := lRoutine.ScopeId;
  Assert.IsNotEmpty(lLocalScopeId);
  for lDeclaration in lModel.Declarations do
    if SameText(lDeclaration.Name, 'TNode') and
      SameText(lDeclaration.ScopeKind, 'unit') then
      lUnitNodeId := lDeclaration.SymbolId
    else if SameText(lDeclaration.Name, 'TNode') and
      SameText(lDeclaration.ScopeKind, 'routine') and
      SameText(lDeclaration.OwnerScopeId, lLocalScopeId) then
      lLocalNodeId := lDeclaration.SymbolId;
  Assert.IsNotEmpty(lUnitNodeId);
  Assert.IsNotEmpty(lLocalNodeId);
  lFacts := TDelphiSemanticWithBinder.BindProject('', nil, [lModel]);
  lSeenUnit := False;
  lSeenLocal := False;
  for lBinding in lFacts.Bindings do
  begin
    if SameText(lBinding.RoutineName, 'UnitAliasRun') then
    begin
      Assert.IsFalse(lSeenUnit);
      lSeenUnit := True;
      Assert.AreEqual(1, Integer(Length(lBinding.Selectors)));
      Assert.AreEqual('resolved', lBinding.Selectors[0].Status,
        lBinding.Selectors[0].ReasonCode);
      Assert.AreEqual('unit', lBinding.Selectors[0].TypeIdentity.ScopeKind);
      Assert.AreEqual(lUnitNodeId,
        lBinding.Selectors[0].TypeIdentity.SemanticSymbolId);
      Assert.AreEqual('TNode', ReceiverOf(lBinding, 'UnitOnly', 'member'));
      Assert.IsFalse(HasReference(lBinding, 'LocalOnly', 'member'));
    end else if SameText(lBinding.RoutineName, 'LocalAliasRun') then
    begin
      Assert.IsFalse(lSeenLocal);
      lSeenLocal := True;
      Assert.AreEqual(1, Integer(Length(lBinding.Selectors)));
      Assert.AreEqual('resolved', lBinding.Selectors[0].Status,
        lBinding.Selectors[0].ReasonCode);
      Assert.AreEqual('routine', lBinding.Selectors[0].TypeIdentity.ScopeKind);
      Assert.AreEqual(lLocalNodeId,
        lBinding.Selectors[0].TypeIdentity.SemanticSymbolId);
      Assert.AreEqual('TNode', ReceiverOf(lBinding, 'LocalOnly', 'member'));
      Assert.IsFalse(HasReference(lBinding, 'UnitOnly', 'member'));
    end;
  end;
  Assert.IsTrue(lSeenUnit and lSeenLocal, 'Both source-backed alias bindings are required.');
end;

procedure TWithBinderTests.RoutineLocalHomonymMembersUseTheirOwnDeclaration;
var
  lBinding: TDelphiSemanticWithBinding;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lGuid: TGUID;
  lGuidText: string;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lOwnName: string;
  lOtherName: string;
  lRoot: string;
  lSeenFirst: Boolean;
  lSeenSecond: Boolean;
begin
  // DS-685 C7: two routines each declare a local TNode, and the unit declares a
  // third TNode. Each WITH must bind only the members of its own local type.
  CreateGUID(lGuid);
  lGuidText := StringReplace(StringReplace(GUIDToString(lGuid), '{', '', [rfReplaceAll]),
    '}', '', [rfReplaceAll]);
  lRoot := WithBinderTempPath('local-homonym-members-' + lGuidText);
  TDirectory.CreateDirectory(lRoot);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := TPath.Combine(lRoot, 'LocalHomonymMembers.pas');
  lOptions.ProjectContextApplied := True;
  TFile.WriteAllText(lOptions.SourceFileName,
    'unit LocalHomonymMembers;'#13#10 +
    'interface'#13#10 +
    'type'#13#10 +
    '  TNode = record UnitOnly: Integer; Shared: Integer; end;'#13#10 +
    'procedure RunFirst(aValue: Integer);'#13#10 +
    'procedure RunSecond(const aText: string);'#13#10 +
    'implementation'#13#10 +
    'procedure RunFirst(aValue: Integer);'#13#10 +
    'type'#13#10 +
    '  TNode = record FirstOnly: Integer; Shared: Integer; end;'#13#10 +
    'var'#13#10 +
    '  lItem: TNode;'#13#10 +
    'begin'#13#10 +
    '  with lItem do'#13#10 +
    '  begin'#13#10 +
    '    FirstOnly := aValue;'#13#10 +
    '    Shared := 1;'#13#10 +
    '    SecondOnly := 2;'#13#10 +
    '    UnitOnly := 3;'#13#10 +
    '  end;'#13#10 +
    'end;'#13#10 +
    'procedure RunSecond(const aText: string);'#13#10 +
    'type'#13#10 +
    '  TNode = record SecondOnly: Integer; Shared: Integer; end;'#13#10 +
    'var'#13#10 +
    '  lItem: TNode;'#13#10 +
    'begin'#13#10 +
    '  with lItem do'#13#10 +
    '  begin'#13#10 +
    '    SecondOnly := Length(aText);'#13#10 +
    '    Shared := 1;'#13#10 +
    '    FirstOnly := 2;'#13#10 +
    '    UnitOnly := 3;'#13#10 +
    '  end;'#13#10 +
    'end;'#13#10 +
    'end.'#13#10, TEncoding.ASCII);
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success, 'The local homonym fixture must extract from source.');
  lFacts := TDelphiSemanticWithBinder.BindProject('', nil, [lModel]);
  lSeenFirst := False;
  lSeenSecond := False;
  for lBinding in lFacts.Bindings do
  begin
    Assert.AreEqual(1, Integer(Length(lBinding.Selectors)));
    Assert.AreEqual('resolved', lBinding.Selectors[0].Status, lBinding.Selectors[0].ReasonCode);
    Assert.AreEqual('routine', lBinding.Selectors[0].TypeIdentity.ScopeKind);
    if SameText(lBinding.RoutineName, 'RunFirst') then
    begin
      Assert.IsFalse(lSeenFirst);
      lSeenFirst := True;
      lOwnName := 'FirstOnly';
      lOtherName := 'SecondOnly';
    end else
    begin
      Assert.IsFalse(lSeenSecond);
      lSeenSecond := True;
      lOwnName := 'SecondOnly';
      lOtherName := 'FirstOnly';
    end;
    Assert.AreEqual('TNode', ReceiverOf(lBinding, lOwnName, 'member'),
      lOwnName + ' must bind to its own routine-local TNode: ' +
      ReasonOf(lBinding, lOwnName, 'ambiguous'));
    Assert.AreEqual('TNode', ReceiverOf(lBinding, 'Shared', 'member'),
      'Shared must bind to the routine-local TNode, not be ambiguous: ' +
      ReasonOf(lBinding, 'Shared', 'ambiguous'));
    Assert.IsFalse(HasReference(lBinding, lOtherName, 'member'),
      lOtherName + ' belongs to the other routine-local TNode.');
    Assert.IsFalse(HasReference(lBinding, 'UnitOnly', 'member'),
      'UnitOnly belongs to the unit-level TNode homonym.');
  end;
  Assert.IsTrue(lSeenFirst and lSeenSecond, 'Both routine-local bindings are required.');
end;

function RoutineLocalInheritedReferenceProblem(const aBinding: TDelphiSemanticWithBinding;
  const aName: string): string;
var
  lReference: TDelphiSemanticBoundReference;
begin
  // A member a routine-local class may inherit must be refused or bound to its
  // declaring ancestor; it may never bind to an outer receiver or stay lexical.
  Result := '';
  for lReference in aBinding.References do
    if SameText(lReference.Name, aName) and
      (not MatchText(lReference.Classification, ['unsupported', 'ambiguous'])) and
      (not (SameText(lReference.Classification, 'member') and
      SameText(lReference.ReceiverTypeName, 'TBase'))) then
      Result := Result + ' ' + aBinding.RoutineName + ':' + aName + '=' +
        lReference.Classification + '/' + lReference.ReceiverTypeName + '/' +
        lReference.ReasonCode;
end;

procedure TWithBinderTests.LocalAliasVisibilityUsesCallerUnitIdentity(
  const aVisibility: string);
var
  lBinding: TDelphiSemanticWithBinding;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lInspected: Integer;
  lModels: TArray<TDelphiSemanticUnitModel>;
  lOptions: TDelphiSemanticModelOptions;
  lRoot: string;
begin
  // DS-701 review: two unrelated classes named TBase must not share access.
  lRoot := WithBinderTempPath('alias-visibility-' + StringReplace(aVisibility, ' ', '-',
    [rfReplaceAll]));
  TDirectory.CreateDirectory(lRoot);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.ProjectContextApplied := True;
  lOptions.SourceFileName := TPath.Combine(lRoot, 'AliasVisibilityA.pas');
  TFile.WriteAllText(lOptions.SourceFileName,
    'unit AliasVisibilityA;'#13#10 +
    'interface'#13#10 +
    'type TBase = class'#13#10 +
    '  ' + aVisibility + ' Hidden: Integer;'#13#10 +
    '  public Visible: Integer; procedure Run;'#13#10 +
    'end;'#13#10 +
    'implementation'#13#10 +
    'procedure TBase.Run;'#13#10 +
    'type TOwnAlias = TBase;'#13#10 +
    'var lItem: TOwnAlias;'#13#10 +
    'begin with lItem do begin Hidden := 1; Visible := 1; end; end;'#13#10 +
    'end.'#13#10, TEncoding.ASCII);
  SetLength(lModels, 2);
  lModels[0] := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModels[0].Success);
  lOptions.SourceFileName := TPath.Combine(lRoot, 'AliasVisibilityB.pas');
  TFile.WriteAllText(lOptions.SourceFileName,
    'unit AliasVisibilityB;'#13#10 +
    'interface'#13#10 +
    'uses AliasVisibilityA;'#13#10 +
    'type TBase = class public Hidden: Integer; procedure Run; end;'#13#10 +
    'implementation'#13#10 +
    'procedure TBase.Run;'#13#10 +
    'type TAlias = AliasVisibilityA.TBase;'#13#10 +
    'var lItem: TAlias;'#13#10 +
    'begin with lItem do begin Hidden := 1; Visible := 1; end; end;'#13#10 +
    'end.'#13#10, TEncoding.ASCII);
  lModels[1] := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModels[1].Success);
  lFacts := TDelphiSemanticWithBinder.BindProject('', nil, lModels);
  lInspected := 0;
  for lBinding in lFacts.Bindings do
    if SameText(lBinding.SelectorText, 'lItem') then
    begin
      Inc(lInspected);
      Assert.AreEqual('resolved', lBinding.Selectors[0].Status);
      Assert.AreEqual('routine', lBinding.Selectors[0].TypeIdentity.ScopeKind);
      Assert.IsTrue(HasReference(lBinding, 'Visible', 'member'));
      Assert.AreEqual(1, CountReferences(lBinding, 'Hidden'));
      if SameText(lBinding.UnitName, 'AliasVisibilityB') then
      begin
        Assert.IsTrue(HasReference(lBinding, 'Hidden', 'unsupported'),
          'The unrelated caller TBase must not acquire another unit TBase access.');
        Assert.IsFalse(HasReference(lBinding, 'Hidden', 'member'));
        Assert.IsFalse(HasReference(lBinding, 'Hidden', 'lexical'));
      end else begin
        Assert.AreEqual('AliasVisibilityA', lBinding.UnitName);
        Assert.IsTrue(HasReference(lBinding, 'Hidden', 'member'),
          'A local alias in the actual declaring class retains its access.');
      end;
    end;
  Assert.AreEqual(2, lInspected);
end;

procedure TWithBinderTests.FinalizedLocalAliasesUseTargetMemberIdentities(
  const aTargetKind: string);
var
  lBinding: TDelphiSemanticWithBinding;
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lInspected: Integer;
  lLocalTypes: string;
  lLexicalTypes: string;
  lLexicalTargetId: string;
  lOuterTargetId: string;
  lReference: TDelphiSemanticBoundReference;
  lParentMembers: string;
  lVisibility: string;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lTargetName: string;
begin
  // DS-701: alias declaration IDs own no fields. Bind through the finalized
  // target identity; an inherited miss still cannot fall through unsafely.
  lTargetName := 'TSafe';
  if SameText(aTargetKind, 'LocalRecord') then
    lTargetName := 'TLocal'
  else if MatchText(aTargetKind, ['UnitClass', 'StrictPrivate']) then
    lTargetName := 'TBase'
  else if SameText(aTargetKind, 'Unknown') then
    lTargetName := 'TUnknown';
  lParentMembers := 'InheritedValue: Integer;';
  lVisibility := '';
  if SameText(aTargetKind, 'StrictPrivate') then
  begin
    lParentMembers := lParentMembers + ' Caption: Integer;';
    lVisibility := 'strict private ';
  end;
  lLocalTypes := 'type'#13#10;
  if SameText(aTargetKind, 'LocalRecord') then
    lLocalTypes := lLocalTypes +
      '  TLocal = record Caption: Integer; InheritedValue: Integer; end;'#13#10;
  lLocalTypes := lLocalTypes + '  TAlias = ' + lTargetName + ';'#13#10;
  lLexicalTypes := lLocalTypes;
  if SameText(aTargetKind, 'LocalRecord') then
    lLexicalTypes := StringReplace(lLocalTypes, 'Caption: Integer', 'Caption: Cardinal',
      [rfReplaceAll]);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := WithBinderTempPath('local-alias-' + aTargetKind + '.pas');
  lOptions.ProjectContextApplied := True;
  TFile.WriteAllText(lOptions.SourceFileName,
    'unit LocalAliasMemberIdentities;'#13#10 +
    'interface'#13#10 +
    'type'#13#10 +
    '  TParent = class ' + lParentMembers + ' end;'#13#10 +
    '  TBase = class(TParent) ' + lVisibility + 'Caption: Integer; end;'#13#10 +
    '  TSafe = record Caption: Integer; InheritedValue: Integer; end;'#13#10 +
    '  TOuter = record Caption: Integer; InheritedValue: Integer; Count: Integer; end;'#13#10 +
    'var Count: Integer;'#13#10 +
    'implementation'#13#10 +
    'procedure RunOuter;'#13#10 + lLocalTypes +
    'var'#13#10 +
    '  lItem: TAlias;'#13#10 +
    '  lOuter: TOuter;'#13#10 +
    'begin'#13#10 +
    '  with lOuter do with lItem do'#13#10 +
    '  begin Caption := 1; InheritedValue := 1; Count := 1; end;'#13#10 +
    'end;'#13#10 +
    'procedure RunLexical;'#13#10 + lLexicalTypes +
    'var lItem: TAlias;'#13#10 +
    'begin'#13#10 +
    '  with lItem do'#13#10 +
    '  begin Caption := 1; InheritedValue := 1; Count := 1; end;'#13#10 +
    'end;'#13#10 +
    'end.'#13#10, TEncoding.ASCII);
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success, 'Alias source must extract before checking binding.');
  lBindings := TDelphiSemanticWithBinder.BindModel(lModel);
  lInspected := 0;
  lLexicalTargetId := '';
  lOuterTargetId := '';
  for lBinding in lBindings do
    if SameText(lBinding.SelectorText, 'lItem') then
    begin
      Inc(lInspected);
      if SameText(aTargetKind, 'Unknown') then
      begin
        Assert.AreEqual('unsupported', lBinding.Selectors[High(lBinding.Selectors)].Status);
        Assert.AreEqual('ROUTINE_LOCAL_TYPE_UNSUPPORTED',
          lBinding.Selectors[High(lBinding.Selectors)].ReasonCode);
        Assert.IsTrue(HasReference(lBinding, 'Caption', 'unsupported'));
        Assert.IsTrue(HasReference(lBinding, 'Count', 'unsupported'));
      end else begin
        Assert.AreEqual('resolved', lBinding.Selectors[High(lBinding.Selectors)].Status);
        Assert.AreEqual('routine', lBinding.Selectors[High(lBinding.Selectors)].TypeIdentity.ScopeKind);
        Assert.AreEqual('type-alias', lBinding.Selectors[High(lBinding.Selectors)].TypeIdentity.Kind);
        Assert.IsNotEmpty(lBinding.Selectors[High(lBinding.Selectors)].TypeIdentity.CanonicalId.Value);
        if SameText(aTargetKind, 'StrictPrivate') then
        begin
          Assert.IsTrue(HasReference(lBinding, 'Caption', 'unsupported'),
            'An inaccessible direct member must shield a public ancestor homonym.');
          Assert.IsFalse(HasReference(lBinding, 'Caption', 'member'));
        end else begin
          Assert.IsTrue(HasReference(lBinding, 'Caption', 'member'),
            'The finalized alias must bind the target field, rather than the outer homonym.');
          Assert.AreEqual(lTargetName, ReceiverOf(lBinding, 'Caption', 'member'));
        end;
        if SameText(aTargetKind, 'LocalRecord') then
        begin
          if SameText(lBinding.RoutineName, 'RunOuter') then
            lOuterTargetId := lBinding.Selectors[High(lBinding.Selectors)].TypeIdentity.CanonicalId.Value
          else
            lLexicalTargetId := lBinding.Selectors[High(lBinding.Selectors)].TypeIdentity.CanonicalId.Value;
          for lReference in lBinding.References do
            if SameText(lReference.Name, 'Caption') then
              if SameText(lBinding.RoutineName, 'RunOuter') then
                Assert.AreEqual('Integer', lReference.TypeName)
              else
                Assert.AreEqual('Cardinal', lReference.TypeName,
                  'The other routine TLocal field has a different source-backed type.');
        end;
        Assert.IsTrue(HasReference(lBinding, 'InheritedValue', 'member'));
        if MatchText(aTargetKind, ['UnitClass', 'StrictPrivate']) then
        begin
          Assert.AreEqual('TParent', ReceiverOf(lBinding, 'InheritedValue', 'member'));
          Assert.IsTrue(HasReference(lBinding, 'Count', 'unsupported'));
          Assert.IsFalse(HasReference(lBinding, 'Count', 'member'));
          Assert.IsFalse(HasReference(lBinding, 'Count', 'lexical'));
        end else begin
          Assert.AreEqual(lTargetName, ReceiverOf(lBinding, 'InheritedValue', 'member'));
          if SameText(lBinding.RoutineName, 'RunOuter') then
            Assert.AreEqual('TOuter', ReceiverOf(lBinding, 'Count', 'member'))
          else
            Assert.IsTrue(HasReference(lBinding, 'Count', 'lexical'));
        end;
      end;
      Assert.AreEqual(1, CountReferences(lBinding, 'Caption'));
      Assert.AreEqual(1, CountReferences(lBinding, 'InheritedValue'));
      Assert.AreEqual(1, CountReferences(lBinding, 'Count'));
    end;
  Assert.AreEqual(2, lInspected, 'Inspect alias receiver inside outer WITH and directly.');
  if SameText(aTargetKind, 'LocalRecord') then
  begin
    Assert.IsNotEmpty(lOuterTargetId);
    Assert.IsNotEmpty(lLexicalTargetId);
    Assert.AreNotEqual(lOuterTargetId, lLexicalTargetId,
      'Each routine local target keeps its own declaration identity.');
  end;
end;

procedure TWithBinderTests.RoutineLocalInheritedMembersNeverBindElsewhere;
var
  lBinding: TDelphiSemanticWithBinding;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lGuid: TGUID;
  lGuidText: string;
  lInspected: Integer;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lProblems: string;
  lRoot: string;
begin
  // DS-685 C7 review: an owner-identity lookup is direct only, so a direct miss
  // on a routine-local class must not be read as "not a member".
  CreateGUID(lGuid);
  lGuidText := StringReplace(StringReplace(GUIDToString(lGuid), '{', '', [rfReplaceAll]),
    '}', '', [rfReplaceAll]);
  lRoot := WithBinderTempPath('local-inherited-members-' + lGuidText);
  TDirectory.CreateDirectory(lRoot);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := TPath.Combine(lRoot, 'LocalInheritedMembers.pas');
  lOptions.ProjectContextApplied := True;
  TFile.WriteAllText(lOptions.SourceFileName,
    'unit LocalInheritedMembers;'#13#10 +
    'interface'#13#10 +
    'type'#13#10 +
    '  TBase = class'#13#10 +
    '  public'#13#10 +
    '    Caption: string;'#13#10 +
    '    procedure Ping;'#13#10 +
    '  end;'#13#10 +
    '  TOuter = class'#13#10 +
    '  public'#13#10 +
    '    Caption: string;'#13#10 +
    '    procedure Ping;'#13#10 +
    '  end;'#13#10 +
    '  TOwner = class'#13#10 +
    '  public'#13#10 +
    '    Caption: string;'#13#10 +
    '    procedure Ping;'#13#10 +
    '    procedure RunWithoutOuter;'#13#10 +
    '  end;'#13#10 +
    'procedure RunWithOuter(lOuter: TOuter);'#13#10 +
    'procedure RunWithAlias(lOuter: TOuter);'#13#10 +
    'implementation'#13#10 +
    'procedure TBase.Ping;'#13#10 +
    'begin'#13#10 +
    'end;'#13#10 +
    'procedure TOuter.Ping;'#13#10 +
    'begin'#13#10 +
    'end;'#13#10 +
    'procedure TOwner.Ping;'#13#10 +
    'begin'#13#10 +
    'end;'#13#10 +
    'procedure RunWithOuter(lOuter: TOuter);'#13#10 +
    'type'#13#10 +
    '  TLocal = class(TBase)'#13#10 +
    '    Extra: Integer;'#13#10 +
    '  end;'#13#10 +
    'var'#13#10 +
    '  lLocal: TLocal;'#13#10 +
    'begin'#13#10 +
    '  with lOuter do'#13#10 +
    '    with lLocal do'#13#10 +
    '    begin'#13#10 +
    '      Extra := 1;'#13#10 +
    '      Caption := '''';'#13#10 +
    '      Ping;'#13#10 +
    '      Free;'#13#10 +
    '    end;'#13#10 +
    'end;'#13#10 +
    'procedure RunWithAlias(lOuter: TOuter);'#13#10 +
    'type'#13#10 +
    '  TLocal = TBase;'#13#10 +
    'var'#13#10 +
    '  lLocal: TLocal;'#13#10 +
    'begin'#13#10 +
    '  with lOuter do'#13#10 +
    '    with lLocal do'#13#10 +
    '    begin'#13#10 +
    '      Caption := '''';'#13#10 +
    '      Ping;'#13#10 +
    '    end;'#13#10 +
    'end;'#13#10 +
    'procedure TOwner.RunWithoutOuter;'#13#10 +
    'type'#13#10 +
    '  TLocal = class(TBase)'#13#10 +
    '    Extra: Integer;'#13#10 +
    '  end;'#13#10 +
    'var'#13#10 +
    '  lLocal: TLocal;'#13#10 +
    'begin'#13#10 +
    '  with lLocal do'#13#10 +
    '  begin'#13#10 +
    '    Extra := 1;'#13#10 +
    '    Caption := '''';'#13#10 +
    '    Ping;'#13#10 +
    '    Free;'#13#10 +
    '  end;'#13#10 +
    'end;'#13#10 +
    'end.'#13#10, TEncoding.ASCII);
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success, 'The local inherited member fixture must extract from source.');
  lFacts := TDelphiSemanticWithBinder.BindProject('', nil, [lModel]);
  lProblems := '';
  lInspected := 0;
  for lBinding in lFacts.Bindings do
  begin
    // Every binding is inspected, including the outer WITH on lOuter.
    if (Length(lBinding.Selectors) > 0) and
      SameText(lBinding.Selectors[High(lBinding.Selectors)].SelectorText, 'lLocal') then
      Inc(lInspected);
    lProblems := lProblems + RoutineLocalInheritedReferenceProblem(lBinding, 'Caption') +
      RoutineLocalInheritedReferenceProblem(lBinding, 'Ping') +
      RoutineLocalInheritedReferenceProblem(lBinding, 'Free');
  end;
  Assert.AreEqual(3, lInspected, 'All three WITH statements on lLocal must be bound.');
  Assert.AreEqual('', lProblems,
    'Inherited members of a routine-local class must be refused or bound to TBase.');
end;

procedure TWithBinderTests.SelectorIdentityUsesTheDeclaringUnitScope;
var
  lBinding: TDelphiSemanticWithBinding;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lLocalScopeId: string;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticApiOptions;
  lPairScopeId: string;
  lProjectPath: string;
  lRoot: string;
  lRoutine: TDelphiSemanticRoutine;
  lSeen: string;
  lSelector: TDelphiSemanticWithSelectorBinding;
  c: Char;

  procedure AssertUnitIdentity(const aCase, aUnitName, aTypeName: string);
  begin
    Assert.AreEqual('resolved', lSelector.Status, aCase + ': ' + lSelector.ReasonCode);
    Assert.AreEqual(aTypeName, lSelector.TypeIdentity.Name, aCase);
    Assert.AreEqual(aUnitName, lSelector.TypeIdentity.UnitName, aCase);
    Assert.AreEqual('unit', lSelector.TypeIdentity.ScopeKind, aCase);
    Assert.IsNotEmpty(lSelector.TypeIdentity.SemanticSymbolId, aCase);
  end;

begin
  lRoot := WithBinderTempPath('declaring-unit-scope-' + TPath.GetGUIDFileName);
  TDirectory.CreateDirectory(lRoot);
  lProjectPath := TPath.Combine(lRoot, 'DeclaringScope.dproj');
  TFile.WriteAllText(TPath.Combine(lRoot, 'DeclaringScope.dpr'),
    'program DeclaringScope;'#13#10 +
    'uses MaskConsumer in ''MaskConsumer.pas'';'#13#10 +
    'begin'#13#10'end.'#13#10, TEncoding.ASCII);
  TFile.WriteAllText(lProjectPath,
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' +
    '<PropertyGroup><MainSource>DeclaringScope.dpr</MainSource></PropertyGroup>' +
    '<ItemGroup><DCCReference Include="MaskProvider.pas"/>' +
    '<DCCReference Include="TableDecl.pas"/>' +
    '<DCCReference Include="MaskConsumer.pas"/></ItemGroup></Project>',
    TEncoding.ASCII);
  // The final record type lives in MaskProvider; the field and parameter that reach it
  // are declared in TableDecl (like maxTdb DatFile.Maske and MaskType).
  TFile.WriteAllText(TPath.Combine(lRoot, 'MaskProvider.pas'),
    'unit MaskProvider;'#13#10 +
    'interface'#13#10 +
    'type'#13#10 +
    '  TMaskEntry = record Width: Integer; end;'#13#10 +
    '  PMaskEntry = ^TMaskEntry;'#13#10 +
    '  TMaskArray = array[1..4] of PMaskEntry;'#13#10 +
    'implementation'#13#10'end.'#13#10, TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'TableDecl.pas'),
    'unit TableDecl;'#13#10 +
    'interface'#13#10 +
    'uses MaskProvider;'#13#10 +
    'type'#13#10 +
    '  TTable = record Mask: TMaskArray; end;'#13#10 +
    '  PTable = ^TTable;'#13#10 +
    'var'#13#10 +
    '  Tables: array[1..2] of PTable;'#13#10 +
    'procedure CopyMask(const aMask: TMaskArray);'#13#10 +
    'implementation'#13#10 +
    'procedure CopyMask(const aMask: TMaskArray);'#13#10 +
    'begin'#13#10 +
    '  with aMask[1]^ do Width := 1;'#13#10 +
    'end;'#13#10 +
    'end.'#13#10, TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'MaskConsumer.pas'),
    'unit MaskConsumer;'#13#10 +
    'interface'#13#10 +
    'type'#13#10 +
    '  TCell = record Value: Integer; end;'#13#10 +
    '  TCellArray = array[1..4] of TCell;'#13#10 +
    '  PCellArray = ^TCellArray;'#13#10 +
    'procedure UseCells(aCells: PCellArray);'#13#10 +
    'procedure UseField;'#13#10 +
    'procedure UseNested;'#13#10 +
    'procedure UseLocal;'#13#10 +
    'procedure UseInline;'#13#10 +
    'procedure UsePair(aValue: Integer;aOther : Integer );'#13#10 +
    'implementation'#13#10 +
    'uses MaskProvider, TableDecl;'#13#10 +
    'procedure UseCells(aCells: PCellArray);'#13#10 +
    'begin'#13#10 +
    '  with aCells^[1] do Value := 1;'#13#10 +
    'end;'#13#10 +
    'procedure UseField;'#13#10 +
    'begin'#13#10 +
    '  with Tables[1]^.Mask[2]^ do Width := 2;'#13#10 +
    'end;'#13#10 +
    'procedure UseNested;'#13#10 +
    'begin'#13#10 +
    '  with Tables[1]^ do'#13#10 +
    '    with Mask[2]^ do Width := 3;'#13#10 +
    'end;'#13#10 +
    'procedure UseLocal;'#13#10 +
    'type TMaskEntry = record LocalOnly: Integer; end;'#13#10 +
    'var lEntry: TMaskEntry;'#13#10 +
    'begin'#13#10 +
    '  with lEntry do LocalOnly := 4;'#13#10 +
    'end;'#13#10 +
    'procedure UseInline;'#13#10 +
    'var lMasks: array[1..2] of PMaskEntry;'#13#10 +
    'begin'#13#10 +
    '  with lMasks[1]^ do Width := 5;'#13#10 +
    'end;'#13#10 +
    // The body repeats the header with different line breaks and spacing only.
    'procedure UsePair(aValue: Integer;'#13#10 +
    '  aOther: Integer);'#13#10 +
    'type TPairLocal = record PairOnly: Integer; end;'#13#10 +
    'var lPair: TPairLocal;'#13#10 +
    '  procedure Inner;'#13#10 +
    '  begin'#13#10 +
    '    with lPair do PairOnly := 6;'#13#10 +
    '  end;'#13#10 +
    'begin'#13#10 +
    '  Inner;'#13#10 +
    'end;'#13#10 +
    'end.'#13#10, TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticApiOptions);
  lOptions.ProjectFileName := lProjectPath;
  lFacts := TDelphiSemanticRemoveWithCompatibilityApi.BuildProjectWithBindingFacts(lOptions);
  lLocalScopeId := '';
  lPairScopeId := '';
  for lModel in lFacts.UnitModels do
    if SameText(lModel.UnitName, 'MaskConsumer') then
    begin
      Assert.AreEqual('ast', lModel.ScopeModelStatus);
      for lRoutine in lModel.Routines do
        if SameText(lRoutine.SectionKind, 'implementation') and
          SameText(lRoutine.Name, 'UseLocal') then
          lLocalScopeId := lRoutine.ScopeId
        else if SameText(lRoutine.SectionKind, 'implementation') and
          SameText(lRoutine.Name, 'UsePair') then
          lPairScopeId := lRoutine.ScopeId;
    end;
  Assert.IsNotEmpty(lLocalScopeId);
  Assert.IsNotEmpty(lPairScopeId);
  lSeen := '';
  for lBinding in lFacts.Bindings do
  begin
    if Length(lBinding.Selectors) = 0 then
      Continue;
    lSelector := lBinding.Selectors[High(lBinding.Selectors)];
    if SameText(lBinding.RoutineName, 'CopyMask') then
    begin
      // Parameter declared in TableDecl; its final type comes from MaskProvider.
      AssertUnitIdentity('parameter', 'MaskProvider', 'TMaskEntry');
      Assert.AreEqual('TMaskEntry', ReceiverOf(lBinding, 'Width', 'member'));
      lSeen := lSeen + 'P';
    end else if SameText(lBinding.RoutineName, 'UseCells') then
    begin
      // Same-unit parameter reached through its interface header coordinates.
      AssertUnitIdentity('same-unit parameter', 'MaskConsumer', 'TCell');
      lSeen := lSeen + 'C';
    end else if SameText(lBinding.RoutineName, 'UseField') then
    begin
      AssertUnitIdentity('field', 'MaskProvider', 'TMaskEntry');
      lSeen := lSeen + 'F';
    end else if SameText(lBinding.RoutineName, 'UseNested') and
      SameText(lSelector.SelectorText, 'Mask[2]^') then
    begin
      AssertUnitIdentity('bound field', 'MaskProvider', 'TMaskEntry');
      lSeen := lSeen + 'N';
    end else if SameText(lBinding.RoutineName, 'UseLocal') then
    begin
      // Negative control: the routine-local homonym keeps its routine identity.
      Assert.AreEqual('resolved', lSelector.Status, lSelector.ReasonCode);
      Assert.AreEqual('routine', lSelector.TypeIdentity.ScopeKind);
      Assert.AreEqual(lLocalScopeId, lSelector.TypeIdentity.OwnerScopeId);
      Assert.AreEqual('TMaskEntry', ReceiverOf(lBinding, 'LocalOnly', 'member'));
      lSeen := lSeen + 'L';
    end else if SameText(lBinding.RoutineName, 'UseInline') then
    begin
      // Negative control: an inline local type cannot prove the scope of an imported
      // final type, so the identity stays unproven (blank), which member safety refuses.
      Assert.AreEqual('resolved', lSelector.Status, lSelector.ReasonCode);
      Assert.AreEqual('TMaskEntry', lSelector.TypeName);
      Assert.IsEmpty(lSelector.TypeIdentity.Name, 'An unproven origin must stay blank.');
      Assert.IsEmpty(lSelector.TypeIdentity.UnitName, 'An unproven origin must stay blank.');
      lSeen := lSeen + 'I';
    end else if SameText(lBinding.RoutineName, 'Inner') then
    begin
      // Header and body differ only by whitespace, so the parent scope stays valid.
      Assert.AreEqual('resolved', lSelector.Status, lSelector.ReasonCode);
      Assert.AreEqual('TPairLocal', lSelector.TypeIdentity.Name);
      Assert.AreEqual('routine', lSelector.TypeIdentity.ScopeKind);
      Assert.AreEqual(lPairScopeId, lSelector.TypeIdentity.OwnerScopeId);
      Assert.AreEqual('TPairLocal', ReceiverOf(lBinding, 'PairOnly', 'member'));
      lSeen := lSeen + 'W';
    end;
  end;
  // Binding order follows the units, so compare the set of cases.
  Assert.AreEqual(7, Length(lSeen), 'Every source-backed WITH must be bound once: ' + lSeen);
  for c in 'PCFNLIW' do
    Assert.IsTrue(Pos(c, lSeen) > 0, 'Missing case ' + c + ' in ' + lSeen);
end;

procedure TWithBinderTests.UnitReceiverWithUnindexedAncestorNeverBindsElsewhere(
  const aBaseTypeName: string);
var
  lBinding: TDelphiSemanticWithBinding;
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lInnerDeclaration: string;
  lInspected: Integer;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
begin
  // DS-700: an unindexed ancestor may own Count. A direct miss is not proof
  // that either an outer receiver or a unit-scope homonym owns the name.
  if SameText(aBaseTypeName, 'record') then
    lInnerDeclaration := '  TInner = record Extra: Integer; end;'#13#10
  else
    lInnerDeclaration := '  TInner = class(' + aBaseTypeName + ')'#13#10 +
      '  public'#13#10'    Extra: Integer;'#13#10'  end;'#13#10;
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := WithBinderTempPath('UnitAncestor-' + aBaseTypeName + '.pas');
  lOptions.ProjectContextApplied := True;
  TFile.WriteAllText(lOptions.SourceFileName,
    'unit UnitAncestor;'#13#10'interface'#13#10'uses System.Classes;'#13#10 +
    'type'#13#10'  TOuter = record Count: Integer; end;'#13#10 + lInnerDeclaration +
    'var'#13#10'  Outer: TOuter;'#13#10'  Inner: TInner;'#13#10 +
    '  Count: Integer;'#13#10 +
    'procedure RunOuter;'#13#10'procedure RunLexical;'#13#10'implementation'#13#10 +
    'procedure RunOuter;'#13#10'begin'#13#10'  with Outer do'#13#10 +
    '    with Inner do'#13#10'    begin'#13#10 +
    '      Extra := 1;'#13#10'      Count := Count + 1;'#13#10'    end;'#13#10'end;'#13#10 +
    'procedure RunLexical;'#13#10'begin'#13#10'  with Inner do'#13#10'  begin'#13#10 +
    '    Extra := 1;'#13#10'    Count := Count + 1;'#13#10'  end;'#13#10'end;'#13#10 +
    'end.'#13#10, TEncoding.ASCII);
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success, 'Unit receiver fixture must extract.');
  lBindings := TDelphiSemanticWithBinder.BindModel(lModel);
  lInspected := 0;
  for lBinding in lBindings do
    if (Length(lBinding.Selectors) > 0) and
      SameText(lBinding.Selectors[High(lBinding.Selectors)].SelectorText, 'Inner') then
    begin
      Inc(lInspected);
      Assert.AreEqual('resolved', lBinding.Selectors[High(lBinding.Selectors)].Status);
      Assert.AreEqual('TInner', ReceiverOf(lBinding, 'Extra', 'member'));
      Assert.AreEqual(2, CountReferences(lBinding, 'Count'));
      if SameText(aBaseTypeName, 'record') then
      begin
        if SameText(lBinding.RoutineName, 'RunOuter') then
          Assert.AreEqual('TOuter', ReceiverOf(lBinding, 'Count', 'member'))
        else
          Assert.IsTrue(HasReference(lBinding, 'Count', 'lexical'));
      end else begin
        Assert.IsTrue(HasReference(lBinding, 'Count', 'unsupported'),
          aBaseTypeName + ': Count must not fall through to an outer or lexical homonym.');
        Assert.IsFalse(HasReference(lBinding, 'Count', 'member'));
        Assert.IsFalse(HasReference(lBinding, 'Count', 'lexical'));
      end;
    end;
  Assert.AreEqual(2, lInspected, 'Inspect both nested and lexical receiver paths.');
end;

procedure TWithBinderTests.ParameterTypesResolveInTheEnclosingScope;
var
  lBinding: TDelphiSemanticWithBinding;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lOuterScopeId: string;
  lRoot: string;
  lRoutine: TDelphiSemanticRoutine;
  lSeen: string;
  lSelector: TDelphiSemanticWithSelectorBinding;
  c: Char;

  // Delphi resolves parameter types in the scope that encloses the routine heading, so
  // a routine's own local homonym never names its parameter's type (verified with a
  // dcc64 probe: Count binds to the parameter's unit-level record field).
  procedure AssertUnitParameterType(const aCase, aTypeName: string);
  begin
    Assert.AreNotEqual('routine', lSelector.TypeIdentity.ScopeKind,
      aCase + ': a routine-local homonym must never type a parameter.');
    if SameText(lSelector.Status, 'resolved') and (lSelector.TypeIdentity.Name <> '') then
    begin
      Assert.AreEqual(aTypeName, lSelector.TypeIdentity.Name, aCase);
      Assert.AreEqual('unit', lSelector.TypeIdentity.ScopeKind, aCase);
    end;
    Assert.IsFalse(HasReference(lBinding, 'Count', 'lexical'),
      aCase + ': Count must not bind to the global variable.');
    Assert.IsFalse(HasReference(lBinding, 'Other', 'member'), aCase);
  end;

begin
  lRoot := WithBinderTempPath('parameter-scope-' + TPath.GetGUIDFileName);
  TDirectory.CreateDirectory(lRoot);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := TPath.Combine(lRoot, 'ParameterScope.pas');
  lOptions.ProjectContextApplied := True;
  TFile.WriteAllText(lOptions.SourceFileName,
    'unit ParameterScope;'#13#10 +
    'interface'#13#10 +
    'type'#13#10 +
    '  TFoo = record Count: Integer; end;'#13#10 +
    '  TFooArr = array[0..1] of TFoo;'#13#10 +
    'var'#13#10 +
    '  Count: Integer;'#13#10 +
    'procedure OpenRun(const aItems: array of TFoo);'#13#10 +
    'procedure ArrayRun(var aArr: TFooArr);'#13#10 +
    'procedure PlainRun(var aOne: TFoo);'#13#10 +
    'procedure OuterRun;'#13#10 +
    'implementation'#13#10 +
    'procedure OpenRun(const aItems: array of TFoo);'#13#10 +
    'type TFoo = record Other: Integer; end;'#13#10 +
    'begin'#13#10 +
    '  with aItems[0] do Count := 1;'#13#10 +
    'end;'#13#10 +
    'procedure ArrayRun(var aArr: TFooArr);'#13#10 +
    'type'#13#10 +
    '  TFoo = record Other: Integer; end;'#13#10 +
    '  TFooArr = array[0..1] of TFoo;'#13#10 +
    'begin'#13#10 +
    '  with aArr[1] do Count := 2;'#13#10 +
    'end;'#13#10 +
    'procedure PlainRun(var aOne: TFoo);'#13#10 +
    'type TFoo = record Other: Integer; end;'#13#10 +
    'begin'#13#10 +
    '  with aOne do Count := 3;'#13#10 +
    'end;'#13#10 +
    'procedure OuterRun;'#13#10 +
    'type TOuterRec = record Inner: Integer; end;'#13#10 +
    '  procedure NestedRun(var aRec: TOuterRec);'#13#10 +
    '  begin'#13#10 +
    '    with aRec do Inner := 4;'#13#10 +
    '  end;'#13#10 +
    'begin'#13#10 +
    'end;'#13#10 +
    'end.'#13#10, TEncoding.ASCII);
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success, 'The parameter scope fixture must extract from source.');
  Assert.AreEqual('ast', lModel.ScopeModelStatus);
  lOuterScopeId := '';
  for lRoutine in lModel.Routines do
    if SameText(lRoutine.Name, 'OuterRun') and SameText(lRoutine.SectionKind, 'implementation') then
      lOuterScopeId := lRoutine.ScopeId;
  Assert.IsNotEmpty(lOuterScopeId);
  lFacts := TDelphiSemanticWithBinder.BindProject('', nil, [lModel]);
  lSeen := '';
  for lBinding in lFacts.Bindings do
  begin
    if Length(lBinding.Selectors) <> 1 then
      Continue;
    lSelector := lBinding.Selectors[0];
    if SameText(lBinding.RoutineName, 'OpenRun') then
    begin
      AssertUnitParameterType('open array', 'TFoo');
      lSeen := lSeen + 'O';
    end else if SameText(lBinding.RoutineName, 'ArrayRun') then
    begin
      AssertUnitParameterType('identifier array', 'TFoo');
      lSeen := lSeen + 'A';
    end else if SameText(lBinding.RoutineName, 'PlainRun') then
    begin
      AssertUnitParameterType('plain parameter', 'TFoo');
      lSeen := lSeen + 'P';
    end else if SameText(lBinding.RoutineName, 'NestedRun') then
    begin
      // Positive control: a nested heading sees its parent's local types.
      Assert.AreEqual('resolved', lSelector.Status, lSelector.ReasonCode);
      Assert.AreEqual('TOuterRec', lSelector.TypeIdentity.Name);
      Assert.AreEqual('routine', lSelector.TypeIdentity.ScopeKind);
      Assert.AreEqual(lOuterScopeId, lSelector.TypeIdentity.OwnerScopeId);
      Assert.AreEqual('TOuterRec', ReceiverOf(lBinding, 'Inner', 'member'));
      lSeen := lSeen + 'N';
    end;
  end;
  Assert.AreEqual(4, Length(lSeen), 'Every source-backed WITH must be bound once: ' + lSeen);
  for c in 'OAPN' do
    Assert.IsTrue(Pos(c, lSeen) > 0, 'Missing case ' + c + ' in ' + lSeen);
end;

procedure TWithBinderTests.MalformedPointerAliasOwnersAndAmbiguousPointeesAreRefused;
var
  i: Integer;
  j: Integer;
  lBinding: TDelphiSemanticWithBinding;
  lDeclaration: TDelphiSemanticDeclaration;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lModel: TDelphiSemanticUnitModel;
  lModels: TArray<TDelphiSemanticUnitModel>;
  lSeen: Boolean;
  lUnitNode: TDelphiSemanticDeclaration;
  lUnitNodeCount: Integer;
begin
  lModel := BuildPointerAliasScopeModel;
  lUnitNode := Default(TDelphiSemanticDeclaration);
  lUnitNodeCount := 0;
  for lDeclaration in lModel.Declarations do
    if SameText(lDeclaration.Name, 'TNode') and
      SameText(lDeclaration.ScopeKind, 'unit') then
    begin
      Inc(lUnitNodeCount);
      lUnitNode := lDeclaration;
    end;
  Assert.AreEqual(1, lUnitNodeCount, 'The unmutated source has one unit pointee.');
  Assert.IsNotEmpty(lUnitNode.SymbolId);
  lFacts := TDelphiSemanticWithBinder.BindProject('', nil, [lModel]);
  lSeen := False;
  for lBinding in lFacts.Bindings do
    if SameText(lBinding.RoutineName, 'UnitAliasRun') then
    begin
      Assert.IsFalse(lSeen, 'The unmutated unit alias has one binding.');
      lSeen := True;
      Assert.AreEqual(1, Integer(Length(lBinding.Selectors)));
      Assert.AreEqual('resolved', lBinding.Selectors[0].Status,
        lBinding.Selectors[0].ReasonCode);
      Assert.AreEqual(lModel.UnitName, lBinding.Selectors[0].TypeIdentity.UnitName);
      Assert.AreEqual('unit', lBinding.Selectors[0].TypeIdentity.ScopeKind);
      Assert.AreEqual(LowerCase(lModel.UnitName),
        lBinding.Selectors[0].TypeIdentity.OwnerScopeId);
      Assert.AreEqual(lUnitNode.SymbolId,
        lBinding.Selectors[0].TypeIdentity.SemanticSymbolId);
      Assert.IsNotEmpty(lBinding.Selectors[0].TypeIdentity.DeclaredId.Value);
      Assert.AreEqual(lModel.FileName,
        lBinding.Selectors[0].TypeIdentity.SourceRange.FileName);
      Assert.AreEqual(lUnitNode.Line,
        lBinding.Selectors[0].TypeIdentity.SourceRange.Line);
      Assert.AreEqual(lUnitNode.Column,
        lBinding.Selectors[0].TypeIdentity.SourceRange.Column);
    end;
  Assert.IsTrue(lSeen, 'The unmutated source-backed unit alias must resolve.');
  for i := 0 to 2 do
  begin
    lModels := [lModel];
    lModels[0].Declarations := Copy(lModel.Declarations);
    for j := 0 to High(lModels[0].Declarations) do
      if SameText(lModels[0].Declarations[j].Name, 'PUnitNode') then
      begin
        if i = 0 then
          lModels[0].Declarations[j].OwnerScopeId := 'wrong-unit'
        else if i = 1 then
          lModels[0].Declarations[j].ScopeKind := 'unknown';
        Break;
      end;
    if i = 2 then
    begin
      for lDeclaration in lModel.Declarations do
        if SameText(lDeclaration.Name, 'TNode') and
          SameText(lDeclaration.ScopeKind, 'unit') then
        begin
          j := Length(lModels[0].Declarations);
          SetLength(lModels[0].Declarations, j + 1);
          lModels[0].Declarations[j] := lDeclaration;
          lModels[0].Declarations[j].SymbolId := lDeclaration.SymbolId + ':duplicate';
          lModels[0].Declarations[j].Line := lDeclaration.Line + 1;
          Break;
        end;
    end;
    lFacts := TDelphiSemanticWithBinder.BindProject('', nil, lModels);
    lSeen := False;
    for lBinding in lFacts.Bindings do
      if SameText(lBinding.RoutineName, 'UnitAliasRun') then
      begin
        Assert.IsFalse(lSeen, 'The mutated unit alias has one binding.');
        lSeen := True;
        Assert.AreEqual(1, Integer(Length(lBinding.Selectors)));
        Assert.AreEqual('unresolved', lBinding.Selectors[0].Status);
        Assert.AreEqual('SELECTOR_TYPE_NOT_RESOLVED',
          lBinding.Selectors[0].ReasonCode,
          'Malformed alias owner or ambiguous pointee must fail closed.');
      end;
    Assert.IsTrue(lSeen, 'The source-backed unit alias binding must be retained.');
  end;
end;


function TWithBinderTests.LoadModel: TDelphiSemanticUnitModel;
var
  lOptions: TDelphiSemanticModelOptions;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := FixturePath('WithBinder', 'WithBinderUnit.pas');
  lOptions.ProjectContextApplied := True;
  Result := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(Result.Success);
end;

function TWithBinderTests.LoadBareReceiverSafetyModels: TArray<TDelphiSemanticUnitModel>;
var
  i: Integer;
  lOptions: TDelphiSemanticModelOptions;
  lUnitName: string;
begin
  SetLength(Result, 3);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.ProjectContextApplied := True;
  for i := 0 to 2 do
  begin
    case i of
      0: lUnitName := 'ReceiverSafetyHidden';
      1: lUnitName := 'ReceiverSafetyBareOwner';
    else
      lUnitName := 'ReceiverSafetyBareCaller';
    end;
    lOptions.SourceFileName := FixturePath('WithBinder\ReceiverSafetyIdentity',
      lUnitName + '.pas');
    Result[i] := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
    Assert.IsTrue(Result[i].Success, lUnitName + ' source model');
  end;
end;

function TWithBinderTests.LoadReceiverSafetyModels: TArray<TDelphiSemanticUnitModel>;
var
  i: Integer;
  lOptions: TDelphiSemanticModelOptions;
  lUnitName: string;
begin
  SetLength(Result, 4);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.ProjectContextApplied := True;
  for i := 0 to 3 do
  begin
    case i of
      0: lUnitName := 'ReceiverSafetyHidden';
      1: lUnitName := 'ReceiverSafetyAlias';
      2: lUnitName := 'ReceiverSafetyOwner';
    else
      lUnitName := 'ReceiverSafetyCaller';
    end;
    lOptions.SourceFileName := FixturePath('WithBinder\ReceiverSafetyIdentity',
      lUnitName + '.pas');
    Result[i] := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
    Assert.IsTrue(Result[i].Success, lUnitName + ' source model');
  end;
end;

function TWithBinderTests.HasReference(const aBinding: TDelphiSemanticWithBinding;
  const aName, aClassification: string): Boolean;
var
  lReference: TDelphiSemanticBoundReference;
begin
  for lReference in aBinding.References do
    if SameText(lReference.Name, aName) and SameText(lReference.Classification, aClassification) then
      Exit(True);

  Result := False;
end;

function TWithBinderTests.HasAnyReference(const aBinding: TDelphiSemanticWithBinding;
  const aName: string): Boolean;
var
  lReference: TDelphiSemanticBoundReference;
begin
  for lReference in aBinding.References do
    if SameText(lReference.Name, aName) then
      Exit(True);

  Result := False;
end;

function TWithBinderTests.ReceiverOf(const aBinding: TDelphiSemanticWithBinding; const aName,
  aClassification: string): string;
var
  lReference: TDelphiSemanticBoundReference;
begin
  for lReference in aBinding.References do
    if SameText(lReference.Name, aName) and SameText(lReference.Classification, aClassification) then
      Exit(lReference.ReceiverTypeName);

  Result := '';
end;

function TWithBinderTests.CountReferences(const aBinding: TDelphiSemanticWithBinding;
  const aName: string): Integer;
var
  lReference: TDelphiSemanticBoundReference;
begin
  Result := 0;
  for lReference in aBinding.References do
    if SameText(lReference.Name, aName) then
      Inc(Result);
end;

function TWithBinderTests.LookupSourceOf(const aBinding: TDelphiSemanticWithBinding; const aName,
  aClassification: string): string;
var
  lReference: TDelphiSemanticBoundReference;
begin
  for lReference in aBinding.References do
    if SameText(lReference.Name, aName) and SameText(lReference.Classification, aClassification) then
      Exit(lReference.LookupSource);

  Result := '';
end;

function TWithBinderTests.ReasonOf(const aBinding: TDelphiSemanticWithBinding; const aName,
  aClassification: string): string;
var
  lReference: TDelphiSemanticBoundReference;
begin
  for lReference in aBinding.References do
    if SameText(lReference.Name, aName) and SameText(lReference.Classification, aClassification) then
      Exit(lReference.ReasonCode);

  Result := '';
end;

function TWithBinderTests.HasInventorySymbol(const aInventory: TDelphiSemanticRemoveWithInventory;
  const aName, aSymbolClass, aRoutineName: string): Boolean;
var
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  for lSymbol in aInventory.Symbols do
    if SameText(lSymbol.Name, aName) and SameText(lSymbol.SymbolClass, aSymbolClass) and
      SameText(lSymbol.RoutineName, aRoutineName) then
      Exit(True);

  Result := False;
end;

function TWithBinderTests.TryFindInventorySymbol(const aInventory: TDelphiSemanticRemoveWithInventory;
  const aName, aSymbolClass, aOwnerName: string; out aSymbol:
  TDelphiSemanticInventorySymbol): Boolean;
var
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  for lSymbol in aInventory.Symbols do
  begin
    if SameText(lSymbol.Name, aName) and SameText(lSymbol.SymbolClass, aSymbolClass) and
      SameText(lSymbol.OwnerName, aOwnerName) then
    begin
      aSymbol := lSymbol;
      Exit(True);
    end;
  end;

  aSymbol := Default(TDelphiSemanticInventorySymbol);
  Result := False;
end;

procedure TWithBinderTests.ResolvesSelectorTypesAndClassifiesBodyIdentifiers;
var
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lModel: TDelphiSemanticUnitModel;
begin
  lModel := LoadModel;

  lBindings := TDelphiSemanticWithBinder.BindModel(lModel);

  Assert.AreEqual(10, Integer(Length(lBindings)));
  Assert.AreEqual(1, Integer(Length(lBindings[0].Selectors)));
  Assert.AreEqual('lFirst', lBindings[0].Selectors[0].SelectorText);
  Assert.AreEqual('resolved', lBindings[0].Selectors[0].Status);
  Assert.AreEqual('TFirstRecord', lBindings[0].Selectors[0].TypeName);
  Assert.IsTrue(HasReference(lBindings[0], 'FirstOnly', 'member'));
  Assert.IsTrue(HasReference(lBindings[0], 'aParamValue', 'lexical'));
  Assert.IsTrue(HasReference(lBindings[0], 'lLocalValue', 'lexical'));
  Assert.IsTrue(HasReference(lBindings[0], 'lSecond.SecondOnly', 'unsupported'));
  Assert.IsTrue(HasReference(lBindings[0], 'FirstOnly[0]', 'unsupported'));
  Assert.IsTrue(HasReference(lBindings[0], 'MissingValue', 'unresolved'));
  Assert.IsFalse(HasAnyReference(lBindings[0], 'PhantomMember'));
  Assert.IsFalse(HasAnyReference(lBindings[0], 'BracePhantom'));
  Assert.IsFalse(HasAnyReference(lBindings[0], 'ParenPhantom'));
end;

procedure TWithBinderTests.BindingsExposeSourceRangesForDakPlanner;
var
  lBinding: TDelphiSemanticWithBinding;
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lModel: TDelphiSemanticUnitModel;
begin
  lModel := LoadModel;

  lBindings := TDelphiSemanticWithBinder.BindModel(lModel);
  lBinding := lBindings[0];

  Assert.AreEqual(lModel.WithStatements[0].Line, lBinding.Line);
  Assert.AreEqual(lModel.WithStatements[0].Column, lBinding.Column);
  Assert.AreEqual(lModel.WithStatements[0].EndLine, lBinding.EndLine);
  Assert.AreEqual(lModel.WithStatements[0].EndColumn, lBinding.EndColumn);
  Assert.AreEqual(lModel.WithStatements[0].BodyLine, lBinding.BodyLine);
  Assert.AreEqual(lModel.WithStatements[0].BodyColumn, lBinding.BodyColumn);
  Assert.AreEqual(lModel.WithStatements[0].BodyEndLine, lBinding.BodyEndLine);
  Assert.AreEqual(lModel.WithStatements[0].BodyEndColumn, lBinding.BodyEndColumn);
  Assert.AreEqual(lModel.WithStatements[0].SelectorText, lBinding.SelectorText);
end;

procedure TWithBinderTests.MultipleSelectorsPreferInnermostReceiver;
var
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lModel: TDelphiSemanticUnitModel;
begin
  lModel := LoadModel;

  lBindings := TDelphiSemanticWithBinder.BindModel(lModel);

  Assert.AreEqual(2, Integer(Length(lBindings[1].Selectors)));
  Assert.AreEqual('TFirstRecord', lBindings[1].Selectors[0].TypeName);
  Assert.AreEqual('TSecondRecord', lBindings[1].Selectors[1].TypeName);
  Assert.IsTrue(HasReference(lBindings[1], 'Shared', 'member'));
  Assert.AreEqual('TSecondRecord', ReceiverOf(lBindings[1], 'Shared', 'member'));
  Assert.IsTrue(HasReference(lBindings[1], 'SecondOnly', 'member'));
  Assert.IsTrue(HasReference(lBindings[1], 'FirstOnly', 'member'));
end;

procedure TWithBinderTests.AmbiguousReceiverMembersClassifyAsAmbiguous;
var
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lLength: Integer;
  lMember: TDelphiSemanticMember;
  lModel: TDelphiSemanticUnitModel;
begin
  lModel := LoadModel;
  lLength := Length(lModel.Members);
  SetLength(lModel.Members, lLength + 1);
  lMember := lModel.Members[0];
  lMember.OwnerName := 'TFirstRecord';
  lMember.Name := 'FirstOnly';
  lModel.Members[lLength] := lMember;

  lBindings := TDelphiSemanticWithBinder.BindModel(lModel);

  Assert.IsTrue(HasReference(lBindings[0], 'FirstOnly', 'ambiguous'));
end;

procedure TWithBinderTests.ClassMethodWithBindingUsesOwnedRoutineTypeForInheritedProtectedMembers;
var
  lBinding: TDelphiSemanticWithBinding;
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lExpandedCount: Integer;
  lOwnerCount: Integer;
  lPath: string;
  lSource: string;
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  lPath := WithBinderTempPath('withbinder-current-type-regression.pas');
  lSource :=
    'unit WithBinderCurrentTypeRegression;' + sLineBreak +
    'interface' + sLineBreak +
    'type' + sLineBreak +
    '  TBase = class' + sLineBreak +
    '  protected' + sLineBreak +
    '    BaseValue: Integer;' + sLineBreak +
    '  end;' + sLineBreak +
    '  TChild = class(TBase)' + sLineBreak +
    '  public' + sLineBreak +
    '    class procedure Run;' + sLineBreak +
    '  end;' + sLineBreak +
    'implementation' + sLineBreak +
    'class procedure TChild.Run;' + sLineBreak +
    'var' + sLineBreak +
    '  lChild: TChild;' + sLineBreak +
    'begin' + sLineBreak +
    '  with lChild do' + sLineBreak +
    '    BaseValue := 1;' + sLineBreak +
    'end;' + sLineBreak +
    'end.';
  TFile.WriteAllText(lPath, lSource, TEncoding.ASCII);
  try
    lOptions := Default(TDelphiSemanticModelOptions);
    lOptions.SourceFileName := lPath;
    lOptions.ProjectContextApplied := True;
    lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
    Assert.IsTrue(lModel.Success);

    lBindings := TDelphiSemanticWithBinder.BindModel(lModel);

    Assert.AreEqual(1, Integer(Length(lBindings)));
    lBinding := lBindings[0];
    Assert.AreEqual('TChild.Run', lBinding.RoutineName);
    Assert.IsTrue(HasReference(lBinding, 'BaseValue', 'member'),
      'Inherited protected receiver members need the owned routine type as access context.');
    Assert.AreEqual('TBase', ReceiverOf(lBinding, 'BaseValue', 'member'));
    lFacts := TDelphiSemanticWithBinder.BindProject('', nil, [lModel]);
    lExpandedCount := 0;
    lOwnerCount := 0;
    for lSymbol in lFacts.Symbols do
      if SameText(lSymbol.Name, 'BaseValue') then
      begin
        if SameText(lSymbol.SymbolClass, 'member') and
          SameText(lSymbol.OwnerName, 'TBase') then
          Inc(lOwnerCount)
        else if SameText(lSymbol.SymbolClass, 'field') and
          SameText(lSymbol.OwnerName, 'TChild') then
        begin
          Inc(lExpandedCount);
          Assert.AreEqual('TBase', lSymbol.SourceOwnerType);
          Assert.AreEqual('WithBinderCurrentTypeRegression',
            lSymbol.AccessOwnerIdentity.UnitName);
          Assert.AreEqual('TChild', lSymbol.AccessOwnerIdentity.Name);
          Assert.IsTrue(lSymbol.AccessOwnerIdentity.DeclaredId.Value <> '');
          Assert.AreEqual(lPath, lSymbol.AccessOwnerIdentity.SourceRange.FileName);
        end
        else
          Continue;
        Assert.AreEqual('WithBinderCurrentTypeRegression',
          lSymbol.OwnerIdentity.UnitName);
        Assert.AreEqual('TBase', lSymbol.OwnerIdentity.Name);
        Assert.IsTrue(lSymbol.OwnerIdentity.DeclaredId.Value <> '');
        Assert.AreEqual(lPath, lSymbol.OwnerIdentity.SourceRange.FileName);
      end;
    Assert.AreEqual(1, lOwnerCount,
      'Inherited BaseValue must retain its actual declaring TBase owner.');
    Assert.AreEqual(1, lExpandedCount,
      'The derived projection must retain the inherited declaration identity.');
  finally
    if TFile.Exists(lPath) then
      TFile.Delete(lPath);
  end;
end;

procedure TWithBinderTests.InheritedHomonymProjectionsKeepTheirAccessDeclaration;
var
  i: Integer;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lFirstCount: Integer;
  lBinding: TDelphiSemanticWithBinding;
  lFirstBindingCount: Integer;
  lNearestBindingCount: Integer;
  lOptions: TDelphiSemanticApiOptions;
  lProjectPath: string;
  lRoot: string;
  lSecondCount: Integer;
  lSecondBindingCount: Integer;
  lUnknownBindingCount: Integer;
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  lRoot := WithBinderTempPath('inherited-homonym');
  TDirectory.CreateDirectory(lRoot);
  lProjectPath := TPath.Combine(lRoot, 'P.dproj');
  TFile.WriteAllText(TPath.Combine(lRoot, 'P.dpr'),
    'program P;'#13#10'uses AUnit in ''AUnit.pas'', BUnit in ''BUnit.pas'';'#13#10 +
    'begin'#13#10'end.'#13#10, TEncoding.ASCII);
  TFile.WriteAllText(lProjectPath,
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' +
    '<PropertyGroup><MainSource>P.dpr</MainSource></PropertyGroup><ItemGroup>' +
    '<DCCReference Include="BaseUnit.pas"/><DCCReference Include="MidUnit.pas"/>' +
    '<DCCReference Include="AUnit.pas"/><DCCReference Include="BUnit.pas"/>' +
    '</ItemGroup></Project>', TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'BaseUnit.pas'),
    'unit BaseUnit;'#13#10'interface'#13#10'type'#13#10 +
    '  TLeaf = record'#13#10'    Value: Integer;'#13#10'  end;'#13#10 +
    '  TBase = class'#13#10'  public'#13#10'    Child: TLeaf;'#13#10 +
    '  end;'#13#10'implementation'#13#10'end.'#13#10, TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'MidUnit.pas'),
    'unit MidUnit;'#13#10'interface'#13#10'uses BaseUnit;'#13#10'type'#13#10 +
    '  TIntermediate = class(TBase) end;'#13#10 +
    'implementation'#13#10'end.'#13#10, TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'AUnit.pas'),
    'unit AUnit;'#13#10'interface'#13#10'uses MidUnit;'#13#10'type'#13#10 +
    '  TDerived = class(TIntermediate) end;'#13#10 +
    '  TWrongLeaf = record OtherValue: Integer; end;'#13#10 +
    '  TGlobalLeaf = record GlobalValue: Integer; end;'#13#10 +
    '  TNearest = record Child: TWrongLeaf; end;'#13#10 +
    'var'#13#10'  Child: TGlobalLeaf;'#13#10 +
    'procedure RunA;'#13#10'procedure RunNearest;'#13#10 +
    'procedure RunUnknown;'#13#10 +
    'implementation'#13#10 +
    'procedure RunA;'#13#10'var'#13#10'  lDerived: TDerived;'#13#10 +
    'begin with lDerived do with Child do Value := 1; end;'#13#10 +
    'procedure RunNearest;'#13#10 +
    'var'#13#10'  lDerived: TDerived;'#13#10 +
    '  lNearest: TNearest;'#13#10 +
    'begin with lDerived do with lNearest do with Child do OtherValue := 1; end;'#13#10 +
    'procedure RunUnknown;'#13#10 +
    'begin with Missing do with Child do Value := 1; end;'#13#10 +
    'end.'#13#10, TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'BUnit.pas'),
    'unit BUnit;'#13#10'interface'#13#10'uses MidUnit;'#13#10'type'#13#10 +
    '  TDerived = class(TIntermediate) end;'#13#10 +
    'procedure RunB;'#13#10'implementation'#13#10 +
    'procedure RunB;'#13#10'var'#13#10'  lDerived: TDerived;'#13#10 +
    'begin with lDerived do with Child do Value := 2; end;'#13#10 +
    'end.'#13#10, TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticApiOptions);
  lOptions.ProjectFileName := lProjectPath;
  for i := 0 to 1 do
  begin
    if i = 1 then
      lOptions.ImplicitRootMemberAbsence := TImplicitRootAbsenceStub.Create;
    lFacts := TDelphiSemanticRemoveWithCompatibilityApi.BuildProjectWithBindingFacts(lOptions);
    lFirstCount := 0;
    lSecondCount := 0;
    lFirstBindingCount := 0;
    lNearestBindingCount := 0;
    lSecondBindingCount := 0;
    lUnknownBindingCount := 0;
    for lBinding in lFacts.Bindings do
      if SameText(lBinding.SelectorText, 'Child') and
        SameText(lBinding.UnitName, 'AUnit') and
        SameText(lBinding.RoutineName, 'RunA') then
      begin
        Inc(lFirstBindingCount);
        Assert.AreEqual(2, Integer(Length(lBinding.Selectors)));
        Assert.AreEqual('resolved', lBinding.Selectors[0].Status,
          'RunA parent: ' + lBinding.Selectors[0].ReasonCode);
        Assert.AreEqual('resolved', lBinding.Selectors[1].Status,
          'RunA child: ' + lBinding.Selectors[1].ReasonCode);
        Assert.AreEqual('TLeaf', lBinding.Selectors[1].TypeName);
        Assert.AreEqual('BaseUnit', lBinding.Selectors[1].TypeIdentity.UnitName);
        Assert.AreEqual('TLeaf', lBinding.Selectors[1].TypeIdentity.Name);
      end else if SameText(lBinding.SelectorText, 'Child') and
        SameText(lBinding.UnitName, 'BUnit') and
        SameText(lBinding.RoutineName, 'RunB') then
      begin
        Inc(lSecondBindingCount);
        Assert.AreEqual(2, Integer(Length(lBinding.Selectors)));
        Assert.AreEqual('resolved', lBinding.Selectors[0].Status,
          'RunB parent: ' + lBinding.Selectors[0].ReasonCode);
        Assert.AreEqual('resolved', lBinding.Selectors[1].Status,
          'RunB child: ' + lBinding.Selectors[1].ReasonCode);
        Assert.AreEqual('BaseUnit', lBinding.Selectors[1].TypeIdentity.UnitName);
        Assert.AreEqual('TLeaf', lBinding.Selectors[1].TypeIdentity.Name);
      end else if SameText(lBinding.SelectorText, 'Child') and
        SameText(lBinding.UnitName, 'AUnit') and
        SameText(lBinding.RoutineName, 'RunNearest') then
      begin
        Inc(lNearestBindingCount);
        Assert.AreEqual(3, Integer(Length(lBinding.Selectors)));
        if i = 0 then
        begin
          Assert.AreEqual('unsupported', lBinding.Selectors[1].Status);
          Assert.AreEqual('PARENT_SELECTOR_UNRESOLVED', lBinding.Selectors[1].ReasonCode);
          Assert.AreEqual('unsupported', lBinding.Selectors[2].Status);
        end else begin
          Assert.AreEqual('resolved', lBinding.Selectors[1].Status);
          Assert.AreEqual('TNearest', lBinding.Selectors[1].TypeName);
          Assert.AreEqual('resolved', lBinding.Selectors[2].Status);
          Assert.AreEqual('TWrongLeaf', lBinding.Selectors[2].TypeName);
          Assert.AreEqual('AUnit', lBinding.Selectors[2].TypeIdentity.UnitName);
          Assert.AreEqual('TWrongLeaf', lBinding.Selectors[2].TypeIdentity.Name);
        end;
      end else if SameText(lBinding.SelectorText, 'Child') and
        SameText(lBinding.UnitName, 'AUnit') and
        SameText(lBinding.RoutineName, 'RunUnknown') then
      begin
        Inc(lUnknownBindingCount);
        Assert.AreEqual(2, Integer(Length(lBinding.Selectors)));
        Assert.AreNotEqual('resolved', lBinding.Selectors[0].Status);
        Assert.AreNotEqual('resolved', lBinding.Selectors[1].Status,
          'An unknown parent must not turn the global Child namesake into a receiver.');
      end;
    Assert.AreEqual(1, lFirstBindingCount);
    Assert.AreEqual(1, lSecondBindingCount);
    Assert.AreEqual(1, lNearestBindingCount);
    Assert.AreEqual(1, lUnknownBindingCount);
    for lSymbol in lFacts.Symbols do
      if SameText(lSymbol.Name, 'Child') and
        SameText(lSymbol.SymbolClass, 'field') and
        SameText(lSymbol.OwnerName, 'TDerived') then
      begin
        Assert.AreEqual('BaseUnit', lSymbol.OwnerIdentity.UnitName);
        Assert.AreEqual('TBase', lSymbol.OwnerIdentity.Name);
        Assert.AreEqual(TPath.Combine(lRoot, 'BaseUnit.pas'),
          lSymbol.OwnerIdentity.SourceRange.FileName);
        if SameText(lSymbol.AccessOwnerIdentity.UnitName, 'AUnit') then
        begin
          Inc(lFirstCount);
          Assert.AreEqual(TPath.Combine(lRoot, 'AUnit.pas'),
            lSymbol.AccessOwnerIdentity.SourceRange.FileName);
        end else if SameText(lSymbol.AccessOwnerIdentity.UnitName, 'BUnit') then
        begin
          Inc(lSecondCount);
          Assert.AreEqual(TPath.Combine(lRoot, 'BUnit.pas'),
            lSymbol.AccessOwnerIdentity.SourceRange.FileName);
        end else
          Assert.Fail('Inherited projection has no proven access declaration.');
        Assert.AreEqual('TDerived', lSymbol.AccessOwnerIdentity.Name);
        Assert.IsTrue(lSymbol.AccessOwnerIdentity.DeclaredId.Value <> '');
      end;
    Assert.AreEqual(1, lFirstCount);
    Assert.AreEqual(1, lSecondCount);
  end;
end;

procedure TWithBinderTests.OneLineTypeDeclarationsDoNotOpenMemberBodies;
const
  cFakeOwners: array[0..8] of string = ('TShortDerived', 'TEmptyDerived', 'TEmpty',
    'TEmptyRec', 'TMeta', 'IForward', 'IEmpty', 'TOddVis', 'TLocalDerived');
  cOneLineTypes: array[0..9] of string = ('TShortDerived', 'TEmptyDerived', 'TEmpty',
    'TEmptyRec', 'TMeta', 'IEmpty', 'TWrongLeaf', 'TNearest', 'TOddVis', 'TAfterOdd');
var
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lFound: Boolean;
  lGlobalCount: Integer;
  lLines: TArray<string>;
  lMultiCount: Integer;
  lOptions: TDelphiSemanticApiOptions;
  lProjectPath: string;
  lRoot: string;
  lSymbol: TDelphiSemanticInventorySymbol;
  lTypeName: string;

  procedure AssertMember(const aName, aOwnerName, aTypeName: string; const aLine: Integer;
    const aExpectedCount: Integer = 1);
  var
    lCount: Integer;
    lMember: TDelphiSemanticInventorySymbol;
  begin
    lCount := 0;
    for lMember in lFacts.Symbols do
      if SameText(lMember.Name, aName) and SameText(lMember.SymbolClass, 'field') and
        SameText(lMember.OwnerName, aOwnerName) then
      begin
        Inc(lCount);
        Assert.AreEqual(aTypeName, lMember.TypeName, aOwnerName + '.' + aName + ' type');
        Assert.AreEqual(aLine, lMember.Line, aOwnerName + '.' + aName + ' line');
        Assert.AreEqual(Pos(aName, lLines[aLine - 1]), lMember.Column,
          aOwnerName + '.' + aName + ' column');
      end;
    Assert.AreEqual(aExpectedCount, lCount, 'Field count of ' + aOwnerName + '.' + aName);
  end;

  function CountFields(const aName, aOwnerName: string): Integer;
  var
    lMember: TDelphiSemanticInventorySymbol;
  begin
    Result := 0;
    for lMember in lFacts.Symbols do
      if SameText(lMember.Name, aName) and SameText(lMember.SymbolClass, 'field') and
        SameText(lMember.OwnerName, aOwnerName) then
        Inc(Result);
  end;

begin
  lRoot := WithBinderTempPath('one-line-types');
  TDirectory.CreateDirectory(lRoot);
  lProjectPath := TPath.Combine(lRoot, 'P.dproj');
  TFile.WriteAllText(TPath.Combine(lRoot, 'P.dpr'),
    'program P;'#13#10'uses OneLineUnit in ''OneLineUnit.pas'';'#13#10 +
    'begin'#13#10'end.'#13#10, TEncoding.ASCII);
  TFile.WriteAllText(lProjectPath,
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' +
    '<PropertyGroup><MainSource>P.dpr</MainSource></PropertyGroup><ItemGroup>' +
    '<DCCReference Include="OneLineUnit.pas"/></ItemGroup></Project>', TEncoding.ASCII);
  // Every one-line form is followed by declarations that a still-open body would claim,
  // including a unit global that shares the inherited field name Child.
  lLines := [
    'unit OneLineUnit;',
    'interface',
    'type',
    '  TBase = class',
    '  public',
    '    Child: Integer;',
    '  end;',
    '  TForward = class;',
    '  TShortDerived = class(TBase);',
    '  TEmptyDerived = class(TBase) end;',
    '  TEmpty = class end;',
    '  TEmptyRec = record end;',
    '  TMeta = class of TBase;',
    '  IForward = interface;',
    '  IEmpty = interface end;',
    '  TWrongLeaf = record OtherValue: Integer; end;',
    '  TNearest = record Child: TWrongLeaf; end;',
    '  TOddVis = class(TBase) public Extra: Integer; end;',
    '  TAfterOdd = record Kept, Also: Integer; end;',
    '  TForward = class',
    '  public',
    '    Value: Integer;',
    '  end;',
    '  IForward = interface',
    '  end;',
    '  TMixed = record First: Integer;',
    '    Second: Integer;',
    '  end;',
    '  TMixedOdd = class(TBase) public Extra2: Integer;',
    '  end;',
    '  THintClass = class end deprecated;',
    '  THintRec = record HintValue: Integer; end platform;',
    '  THintMsg = class(TBase) end deprecated ''Use TBase'';',
    '  THintMulti = class end platform experimental;',
    '  TAfterHints = class',
    '  public',
    '    AfterValue: Integer;',
    '  end;',
    'var',
    '  Child: Integer;',
    'procedure RunLocal;',
    'implementation',
    'procedure RunLocal;',
    'type',
    '  TLocalDerived = class(TBase) end;',
    '  TLocalRec = record LocalValue: Integer; end;',
    '  TLocalMulti = record',
    '    MultiValue: Integer;',
    '  end;',
    'var',
    '  lRec: TLocalRec;',
    'begin',
    '  lRec.LocalValue := Child;',
    'end;',
    'end.'];
  TFile.WriteAllText(TPath.Combine(lRoot, 'OneLineUnit.pas'),
    string.Join(#13#10, lLines) + #13#10, TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticApiOptions);
  lOptions.ProjectFileName := lProjectPath;
  lFacts := TDelphiSemanticRemoveWithCompatibilityApi.BuildProjectWithBindingFacts(lOptions);

  lGlobalCount := 0;
  for lSymbol in lFacts.Symbols do
  begin
    if not SameText(lSymbol.UnitName, 'OneLineUnit') then
      Continue;
    if MatchText(lSymbol.SymbolClass, ['field', 'property', 'method', 'constant',
      'class-var']) then
    begin
      Assert.IsTrue((Pos('=', lSymbol.Name) = 0) and (Pos(' ', Trim(lSymbol.Name)) = 0),
        'A declaration line became member "' + lSymbol.Name + '" of ' + lSymbol.OwnerName);
      // Derived one-liners may only carry the inherited projection of TBase.Child, which
      // keeps the source line of the TBase declaration.
      if MatchText(lSymbol.OwnerName, cFakeOwners) then
        Assert.IsTrue(SameText(lSymbol.Name, 'Child') and (lSymbol.Line = 6),
          'Fake member ' + lSymbol.OwnerName + '.' + lSymbol.Name + ' at line ' +
          IntToStr(lSymbol.Line));
    end;
    if SameText(lSymbol.Name, 'Child') and (lSymbol.OwnerName = '') and
      SameText(lSymbol.SymbolClass, 'unit-global') then
    begin
      Inc(lGlobalCount);
      Assert.AreEqual(40, lSymbol.Line, 'Global Child line');
    end;
  end;
  Assert.AreEqual(1, lGlobalCount, 'The unit global Child must stay a unit global.');

  AssertMember('OtherValue', 'TWrongLeaf', 'Integer', 16);
  AssertMember('Child', 'TNearest', 'TWrongLeaf', 17);
  AssertMember('Kept', 'TAfterOdd', 'Integer', 19);
  AssertMember('Also', 'TAfterOdd', 'Integer', 19);
  AssertMember('Value', 'TForward', 'Integer', 22);
  // A routine-local record is reported by both the model and the text scanner, so the
  // one-line form must match the field count of the equivalent multi-line form.
  lMultiCount := CountFields('MultiValue', 'TLocalMulti');
  Assert.IsTrue(lMultiCount > 0, 'Expected the multi-line local record field.');
  AssertMember('LocalValue', 'TLocalRec', 'Integer', 46, lMultiCount);
  // A hint directive after the closing end still closes the type on its line, and the
  // following type keeps its own members.
  AssertMember('HintValue', 'THintRec', 'Integer', 32);
  AssertMember('AfterValue', 'TAfterHints', 'Integer', 37);
  for lSymbol in lFacts.Symbols do
    if SameText(lSymbol.SymbolClass, 'type-member') and
      SameText(lSymbol.UnitName, 'OneLineUnit') and
      MatchText(lSymbol.Name, ['THintClass', 'THintRec', 'THintMsg', 'THintMulti']) then
    begin
      Assert.AreEqual(lSymbol.Line, lSymbol.EndLine, lSymbol.Name + ' must end on its line.');
      Assert.AreEqual('', lSymbol.UnsupportedReason, lSymbol.Name + ' reason');
    end;
  for lSymbol in lFacts.Symbols do
    if MatchText(lSymbol.OwnerName, ['THintClass', 'THintRec', 'THintMsg', 'THintMulti']) and
      SameText(lSymbol.SymbolClass, 'field') then
      Assert.IsTrue(SameText(lSymbol.Name, 'HintValue') or
        (SameText(lSymbol.Name, 'Child') and (lSymbol.Line = 6)),
        'Fake member ' + lSymbol.OwnerName + '.' + lSymbol.Name);
  // A record whose first fields share the header line keeps its later body lines.
  AssertMember('First', 'TMixed', 'Integer', 26);
  AssertMember('Second', 'TMixed', 'Integer', 27);
  Assert.AreEqual(0, CountFields('Extra2', 'TMixedOdd'),
    'An unparsed header member must not be guessed.');
  lFound := False;
  for lSymbol in lFacts.Symbols do
    if SameText(lSymbol.SymbolClass, 'type-member') and
      SameText(lSymbol.UnitName, 'OneLineUnit') and
      (SameText(lSymbol.Name, 'TMixed') or SameText(lSymbol.Name, 'TMixedOdd')) then
    begin
      lFound := True;
      if SameText(lSymbol.Name, 'TMixed') then
      begin
        Assert.AreEqual(28, lSymbol.EndLine, 'TMixed end line');
        Assert.AreEqual('', lSymbol.UnsupportedReason, 'TMixed reason');
      end else
      begin
        Assert.AreEqual(30, lSymbol.EndLine, 'TMixedOdd end line');
        Assert.AreNotEqual('', lSymbol.UnsupportedReason, 'TMixedOdd must fail closed.');
      end;
    end;
  Assert.IsTrue(lFound, 'Expected the mixed record types.');

  for lTypeName in cOneLineTypes do
  begin
    lFound := False;
    for lSymbol in lFacts.Symbols do
      if SameText(lSymbol.Name, lTypeName) and SameText(lSymbol.SymbolClass, 'type-member') and
        SameText(lSymbol.UnitName, 'OneLineUnit') then
      begin
        lFound := True;
        Assert.AreEqual(lSymbol.Line, lSymbol.EndLine, lTypeName + ' must end on its own line.');
        // An inline body that is not plain fields stays unsupported instead of guessed.
        if SameText(lTypeName, 'TOddVis') then
          Assert.AreNotEqual('', lSymbol.UnsupportedReason, 'TOddVis must fail closed.')
        else
          Assert.AreEqual('', lSymbol.UnsupportedReason, lTypeName + ' reason');
      end;
    Assert.IsTrue(lFound, 'Expected type ' + lTypeName);
  end;
  for lSymbol in lFacts.Symbols do
    if SameText(lSymbol.Name, 'TBase') and SameText(lSymbol.SymbolClass, 'type-member') and
      SameText(lSymbol.UnitName, 'OneLineUnit') then
      Assert.AreEqual(7, lSymbol.EndLine, 'TBase body must still end at its end line.');
end;

procedure TWithBinderTests.IndexedPropertySelectorWithoutDereferenceStaysUnsupported;
var
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lPath: string;
  lSource: string;
begin
  lPath := WithBinderTempPath('withbinder-indexed-property-regression.pas');
  lSource :=
    'unit WithBinderIndexedPropertyRegression;' + sLineBreak +
    'interface' + sLineBreak +
    'type' + sLineBreak +
    '  TIndexedRecord = record' + sLineBreak +
    '    Name: string;' + sLineBreak +
    '  end;' + sLineBreak +
    '  TIndexedBox = class' + sLineBreak +
    '  private' + sLineBreak +
    '    function GetItem(const aIndex: Integer): TIndexedRecord;' + sLineBreak +
    '  public' + sLineBreak +
    '    property Items[const aIndex: Integer]: TIndexedRecord read GetItem; default;' +
    sLineBreak +
    '  end;' + sLineBreak +
    '  TScope = class' + sLineBreak +
    '  public' + sLineBreak +
    '    class procedure Run;' + sLineBreak +
    '  end;' + sLineBreak +
    'implementation' + sLineBreak +
    'function TIndexedBox.GetItem(const aIndex: Integer): TIndexedRecord;' + sLineBreak +
    'begin' + sLineBreak +
    '  Result.Name := '''';' + sLineBreak +
    'end;' + sLineBreak +
    'class procedure TScope.Run;' + sLineBreak +
    'var' + sLineBreak +
    '  lBox: TIndexedBox;' + sLineBreak +
    'begin' + sLineBreak +
    '  with lBox[0] do' + sLineBreak +
    '    Name := ''indexed property'';' + sLineBreak +
    'end;' + sLineBreak +
    'end.';
  TFile.WriteAllText(lPath, lSource, TEncoding.ASCII);
  try
    lOptions := Default(TDelphiSemanticModelOptions);
    lOptions.SourceFileName := lPath;
    lOptions.ProjectContextApplied := True;
    lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
    Assert.IsTrue(lModel.Success);

    lBindings := TDelphiSemanticWithBinder.BindModel(lModel);

    Assert.AreEqual(1, Integer(Length(lBindings)));
    Assert.AreEqual('unsupported', lBindings[0].Selectors[0].Status);
    Assert.AreEqual('PROPERTY_SELECTOR_UNSUPPORTED', lBindings[0].Selectors[0].ReasonCode);
    Assert.AreEqual('', lBindings[0].Selectors[0].TypeName);
  finally
    if TFile.Exists(lPath) then
      TFile.Delete(lPath);
  end;
end;

procedure TWithBinderTests.MemberReferenceReportsRoutineScopeConflict;
var
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lPath: string;
  lReference: TDelphiSemanticBoundReference;
  lSource: string;
begin
  lPath := WithBinderTempPath('withbinder-scope-conflict-regression.pas');
  lSource :=
    'unit WithBinderScopeConflictRegression;' + sLineBreak +
    'interface' + sLineBreak +
    'type' + sLineBreak +
    '  TBox = class' + sLineBreak +
    '  public' + sLineBreak +
    '    procedure Flush;' + sLineBreak +
    '  end;' + sLineBreak +
    '  TScope = class' + sLineBreak +
    '  public' + sLineBreak +
    '    class procedure Run;' + sLineBreak +
    '  end;' + sLineBreak +
    'procedure Flush;' + sLineBreak +
    'implementation' + sLineBreak +
    'procedure Flush;' + sLineBreak +
    'begin' + sLineBreak +
    'end;' + sLineBreak +
    'procedure TBox.Flush;' + sLineBreak +
    'begin' + sLineBreak +
    'end;' + sLineBreak +
    'class procedure TScope.Run;' + sLineBreak +
    'var' + sLineBreak +
    '  lBox: TBox;' + sLineBreak +
    'begin' + sLineBreak +
    '  with lBox do' + sLineBreak +
    '    Flush;' + sLineBreak +
    'end;' + sLineBreak +
    'end.';
  TFile.WriteAllText(lPath, lSource, TEncoding.ASCII);
  try
    lOptions := Default(TDelphiSemanticModelOptions);
    lOptions.SourceFileName := lPath;
    lOptions.ProjectContextApplied := True;
    lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
    Assert.IsTrue(lModel.Success);

    lBindings := TDelphiSemanticWithBinder.BindModel(lModel);

    Assert.AreEqual(1, Integer(Length(lBindings)));
    for lReference in lBindings[0].References do
      if SameText(lReference.Name, 'Flush') and SameText(lReference.Classification, 'member') then
      begin
        Assert.AreEqual('routine', lReference.ScopeConflictKind);
        Assert.AreEqual('Flush', lReference.ScopeConflictName);
        Exit;
      end;
    Assert.Fail('Expected member-bound Flush reference.');
  finally
    if TFile.Exists(lPath) then
      TFile.Delete(lPath);
  end;
end;

procedure TWithBinderTests.UnresolvedReceiverShieldsOuterAndLexicalHomonyms;
var
  lBinding: TDelphiSemanticWithBinding;
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lInspected: Integer;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lReference: TDelphiSemanticBoundReference;
begin
  // DS-705: the missing receiver can own Child or Count, so global and outer
  // homonyms do not establish a safe binding inside its WITH body.
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := WithBinderTempPath('unresolved-receiver-shielding.pas');
  lOptions.ProjectContextApplied := True;
  TFile.WriteAllText(lOptions.SourceFileName,
    'unit UnresolvedReceiverShielding;'#13#10 +
    'interface'#13#10 +
    'type'#13#10 +
    '  PChild = ^TChild;'#13#10 +
    '  TChild = record Count: Integer; end;'#13#10 +
    '  TOuter = record Count: Integer; Child: PChild; end;'#13#10 +
    'var'#13#10 +
    '  Outer: TOuter;'#13#10 +
    '  Child: PChild;'#13#10 +
    '  Count: Integer;'#13#10 +
    'implementation'#13#10 +
    'procedure RunNested;'#13#10 +
    'begin with Missing^ do with Child^ do Count := 1; end;'#13#10 +
    'procedure RunOuter;'#13#10 +
    'begin with Outer do with Missing^ do Count := 1; end;'#13#10 +
    'procedure RunLexical;'#13#10 +
    'begin with Missing^ do Count := 1; end;'#13#10 +
    'end.'#13#10, TEncoding.ASCII);
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success, 'The unresolved receiver fixture must extract.');
  lBindings := TDelphiSemanticWithBinder.BindModel(lModel);
  lInspected := 0;
  for lBinding in lBindings do
    if SameText(lBinding.RoutineName, 'RunNested') and
      SameText(lBinding.SelectorText, 'Child^') then
    begin
      Inc(lInspected);
      Assert.AreEqual(2, Integer(Length(lBinding.Selectors)));
      Assert.AreNotEqual('resolved', lBinding.Selectors[0].Status);
      Assert.AreNotEqual('resolved', lBinding.Selectors[1].Status,
        'The child must not acquire the global Child identity across an unresolved receiver.');
      Assert.AreEqual('', lBinding.Selectors[1].TypeIdentity.DeclaredId.Value);
    end else if (SameText(lBinding.RoutineName, 'RunOuter') or
      SameText(lBinding.RoutineName, 'RunLexical')) and
      SameText(lBinding.SelectorText, 'Missing^') then
    begin
      Inc(lInspected);
      Assert.IsTrue(HasAnyReference(lBinding, 'Count'));
      for lReference in lBinding.References do
        if SameText(lReference.Name, 'Count') then
        begin
          Assert.AreEqual('unsupported', lReference.Classification);
          Assert.AreEqual('SELECTOR_MEMBERS_UNVERIFIED', lReference.ReasonCode);
        end;
      Assert.IsFalse(HasReference(lBinding, 'Count', 'member'));
      Assert.IsFalse(HasReference(lBinding, 'Count', 'lexical'));
    end;
  Assert.AreEqual(3, lInspected, 'Inspect the nested selector, outer homonym and lexical homonym.');
end;

procedure TWithBinderTests.UnresolvedSelectorMarksBodyReferencesExternal;
var
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lModel: TDelphiSemanticUnitModel;
begin
  lModel := LoadModel;

  lBindings := TDelphiSemanticWithBinder.BindModel(lModel);

  Assert.AreEqual('MissingReceiver', lBindings[2].Selectors[0].SelectorText);
  Assert.AreEqual('unresolved', lBindings[2].Selectors[0].Status);
  Assert.IsTrue(HasReference(lBindings[2], 'MissingMember', 'unsupported'));
  Assert.AreEqual('SELECTOR_MEMBERS_UNVERIFIED',
    ReasonOf(lBindings[2], 'MissingMember', 'unsupported'));
end;

procedure TWithBinderTests.NestedWithStatementsUseOuterReceiverStack;
var
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lFoundOuterAfterInnerRange: Boolean;
  lModel: TDelphiSemanticUnitModel;
  lReference: TDelphiSemanticBoundReference;
begin
  lFoundOuterAfterInnerRange := False;
  lModel := LoadModel;

  lBindings := TDelphiSemanticWithBinder.BindModel(lModel);

  Assert.AreEqual(1, Integer(Length(lBindings[3].Selectors)));
  Assert.AreEqual('TFirstRecord', lBindings[3].Selectors[0].TypeName);
  Assert.IsFalse(HasAnyReference(lBindings[3], 'SecondOnly'));
  for lReference in lBindings[3].References do
    if SameText(lReference.Name, 'FirstOnly') and SameText(lReference.Classification, 'member') and
      (lReference.Line = 57) and (lReference.Column = 5) and (lReference.EndLine = 57) and
      (lReference.EndColumn = 13) then
      lFoundOuterAfterInnerRange := True;
  Assert.IsTrue(lFoundOuterAfterInnerRange, 'Expected outer reference after inner with to keep range.');
  Assert.AreEqual(2, Integer(Length(lBindings[4].Selectors)));
  Assert.AreEqual('TFirstRecord', lBindings[4].Selectors[0].TypeName);
  Assert.AreEqual('TSecondRecord', lBindings[4].Selectors[1].TypeName);
  Assert.AreEqual('TFirstRecord', ReceiverOf(lBindings[4], 'FirstOnly', 'member'));
  Assert.AreEqual('TSecondRecord', ReceiverOf(lBindings[4], 'SecondOnly', 'member'));
end;

procedure TWithBinderTests.NestedRoutineWithUsesParentRoutineScope;
var
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lModel: TDelphiSemanticUnitModel;
begin
  lModel := LoadModel;

  lBindings := TDelphiSemanticWithBinder.BindModel(lModel);

  Assert.AreEqual('lOuterReceiver', lBindings[5].Selectors[0].SelectorText);
  Assert.AreEqual('resolved', lBindings[5].Selectors[0].Status);
  Assert.AreEqual('TFirstRecord', lBindings[5].Selectors[0].TypeName);
  Assert.IsTrue(HasReference(lBindings[5], 'FirstOnly', 'member'));
  Assert.IsTrue(HasReference(lBindings[5], 'lInnerValue', 'lexical'));
end;

procedure TWithBinderTests.SiblingRoutineLocalsDoNotLeakIntoNestedWith;
var
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lModel: TDelphiSemanticUnitModel;
begin
  lModel := LoadModel;

  lBindings := TDelphiSemanticWithBinder.BindModel(lModel);

  Assert.AreEqual('lSiblingReceiver', lBindings[6].Selectors[0].SelectorText);
  Assert.AreEqual('unresolved', lBindings[6].Selectors[0].Status);
  Assert.IsTrue(HasReference(lBindings[6], 'FirstOnly', 'unsupported'));
  Assert.AreEqual('SELECTOR_MEMBERS_UNVERIFIED',
    ReasonOf(lBindings[6], 'FirstOnly', 'unsupported'));
end;

procedure TWithBinderTests.PlanningMetadataCountsLookupSourcesAndReasons;
var
  lBinding: TDelphiSemanticWithBinding;
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lModel: TDelphiSemanticUnitModel;
begin
  lModel := LoadModel;

  lBindings := TDelphiSemanticWithBinder.BindModel(lModel);
  lBinding := lBindings[7];

  Assert.AreEqual('skipped', lBinding.Status);
  Assert.AreEqual('UNSUPPORTED_REFERENCE', lBinding.SkipReason);
  Assert.AreEqual(5, lBinding.MemberReferenceCount);
  Assert.AreEqual(2, lBinding.LexicalReferenceCount);
  Assert.AreEqual(3, lBinding.ExternalReferenceCount);
  Assert.AreEqual(1, lBinding.IntrinsicReferenceCount);
  Assert.AreEqual(3, lBinding.UnsupportedReferenceCount);
  Assert.AreEqual(1, lBinding.UnresolvedReferenceCount);
  Assert.AreEqual('receiver', LookupSourceOf(lBinding, 'FirstOnly', 'member'));
  Assert.AreEqual('lexical', LookupSourceOf(lBinding, 'lText', 'lexical'));
  Assert.AreEqual(2, CountReferences(lBinding, 'lText'));
  Assert.AreEqual('intrinsic', LookupSourceOf(lBinding, 'Length', 'intrinsic'));
  Assert.AreEqual('external', LookupSourceOf(lBinding, 'KnownExternalCall', 'external'));
  Assert.AreEqual('EXTERNAL_ROUTINE_CALL', ReasonOf(lBinding, 'KnownExternalCall', 'external'));
  Assert.AreEqual('UNKNOWN_ROUTINE_CALL', ReasonOf(lBinding, 'UnknownExternalCall', 'external'));
  Assert.AreEqual('CALL_SELECTOR_UNSUPPORTED', ReasonOf(lBinding, 'FirstOnly', 'unsupported'));
  Assert.AreEqual('INDEXED_SELECTOR_UNSUPPORTED', ReasonOf(lBinding, 'FirstOnly[0]', 'unsupported'));
  Assert.AreEqual('CALL_SELECTOR_UNSUPPORTED', ReasonOf(lBinding, 'TFirstRecord', 'unsupported'));
  Assert.AreEqual('NAME_NOT_FOUND', ReasonOf(lBinding, 'MissingPlanValue', 'unresolved'));
end;

procedure TWithBinderTests.ScopedDeclarationsMarkBindingSkipped;
var
  lBinding: TDelphiSemanticWithBinding;
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lModel: TDelphiSemanticUnitModel;
begin
  lModel := LoadModel;

  lBindings := TDelphiSemanticWithBinder.BindModel(lModel);
  lBinding := lBindings[8];

  Assert.IsTrue(lBinding.HasScopedDeclaration);
  Assert.AreEqual('skipped', lBinding.Status);
  Assert.AreEqual('SCOPED_DECLARATION', lBinding.SkipReason);
end;

procedure TWithBinderTests.ControlCharacterLiteralsAreIgnored;
var
  lBinding: TDelphiSemanticWithBinding;
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lModel: TDelphiSemanticUnitModel;
begin
  lModel := LoadModel;

  lBindings := TDelphiSemanticWithBinder.BindModel(lModel);
  lBinding := lBindings[7];

  Assert.AreEqual(6, CountReferences(lBinding, 'FirstOnly'));
  Assert.IsFalse(HasAnyReference(lBinding, '13'));
  Assert.IsFalse(HasAnyReference(lBinding, '10'));
end;

procedure TWithBinderTests.SafeBindingsArePlannedDirectReferences;
var
  lBinding: TDelphiSemanticWithBinding;
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lModel: TDelphiSemanticUnitModel;
begin
  lModel := LoadModel;

  lBindings := TDelphiSemanticWithBinder.BindModel(lModel);
  lBinding := lBindings[1];

  Assert.AreEqual('planned', lBinding.Status);
  Assert.AreEqual('', lBinding.SkipReason);
  Assert.AreEqual(3, lBinding.MemberReferenceCount);
  Assert.AreEqual(0, lBinding.UnsupportedReferenceCount);
  Assert.AreEqual(0, lBinding.UnresolvedReferenceCount);
  Assert.AreEqual(0, lBinding.ExternalReferenceCount);
end;

procedure TWithBinderTests.SkipReasonsCoverExternalAndUnresolvedBranches;
var
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lModel: TDelphiSemanticUnitModel;
begin
  lModel := LoadModel;

  lBindings := TDelphiSemanticWithBinder.BindModel(lModel);

  Assert.AreEqual('skipped', lBindings[6].Status);
  Assert.AreEqual('UNSUPPORTED_REFERENCE', lBindings[6].SkipReason);
  Assert.AreEqual('skipped', lBindings[9].Status);
  Assert.AreEqual('UNRESOLVED_REFERENCE', lBindings[9].SkipReason);
  Assert.IsTrue(HasReference(lBindings[9], 'MissingOnly', 'unresolved'));
end;

procedure TWithBinderTests.CastExpressionRolesRemainUnsupported;
var
  lBinding: TDelphiSemanticWithBinding;
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lModel: TDelphiSemanticUnitModel;
begin
  lModel := LoadModel;

  lBindings := TDelphiSemanticWithBinder.BindModel(lModel);
  lBinding := lBindings[7];

  Assert.IsTrue(HasReference(lBinding, 'TFirstRecord', 'unsupported'));
  Assert.AreEqual('none', LookupSourceOf(lBinding, 'TFirstRecord', 'unsupported'));
  Assert.AreEqual('CALL_SELECTOR_UNSUPPORTED', ReasonOf(lBinding, 'TFirstRecord', 'unsupported'));
end;

procedure TWithBinderTests.InventoryExposesFileAwareSymbolsAndBindings;
var
  lFoundCallArgumentRange: Boolean;
  lFoundFirstOnlyRange: Boolean;
  lFoundRepeatedCallArgumentRange: Boolean;
  lInventory: TDelphiSemanticRemoveWithInventory;
  lModel: TDelphiSemanticUnitModel;
  lRangeDetails: string;
  lReference: TDelphiSemanticBoundReference;
begin
  lFoundCallArgumentRange := False;
  lFoundFirstOnlyRange := False;
  lFoundRepeatedCallArgumentRange := False;
  lRangeDetails := '';
  lModel := LoadModel;

  lInventory := TDelphiSemanticWithBinder.BuildInventory(lModel);

  Assert.AreEqual(lModel.FileName, lInventory.FileName);
  Assert.AreEqual('WithBinderUnit', lInventory.UnitName);
  Assert.IsTrue(HasInventorySymbol(lInventory, 'WithBinderUnit', 'unit', ''));
  Assert.IsTrue(HasInventorySymbol(lInventory, 'TFirstRecord', 'declaration', ''));
  Assert.IsTrue(HasInventorySymbol(lInventory, 'FirstOnly', 'member', ''));
  Assert.IsTrue(HasInventorySymbol(lInventory, 'RunWithBinder', 'routine', ''));
  Assert.IsTrue(HasInventorySymbol(lInventory, 'aParamValue', 'parameter', 'RunWithBinder'));
  Assert.IsTrue(HasInventorySymbol(lInventory, 'lFirst', 'local', 'RunWithBinder'));
  Assert.IsTrue(Length(lInventory.Bindings) > 0, 'Expected with bindings.');
  Assert.AreEqual(lModel.FileName, lInventory.Bindings[0].FileName);
  Assert.AreEqual('WithBinderUnit', lInventory.Bindings[0].UnitName);
  Assert.AreEqual('RunWithBinder', lInventory.Bindings[0].RoutineName);
  Assert.AreEqual(1, Integer(Length(lInventory.Bindings[0].Selectors)));
  Assert.AreEqual('lFirst', lInventory.Bindings[0].Selectors[0].SelectorText);
  for lReference in lInventory.Bindings[0].References do
    if SameText(lReference.Name, 'FirstOnly') and SameText(lReference.Classification, 'member') and
      (lReference.Line = 32) and (lReference.Column = 5) and (lReference.EndLine = 32) and
      (lReference.EndColumn = 13) then
      lFoundFirstOnlyRange := True;
  Assert.IsTrue(lFoundFirstOnlyRange, 'Expected exact source range for FirstOnly member reference.');
  for lReference in lInventory.Bindings[7].References do
  begin
    if SameText(lReference.Name, 'FirstOnly') then
      lRangeDetails := lRangeDetails + Format('%s:%d:%d-%d:%d ',
        [lReference.Classification, lReference.Line, lReference.Column, lReference.EndLine,
        lReference.EndColumn]);
    if SameText(lReference.Name, 'FirstOnly') and SameText(lReference.Classification, 'member') and
      (lReference.Line = 99) and (lReference.Column = 23) and (lReference.EndLine = 99) and
      (lReference.EndColumn = 31) then
      lFoundCallArgumentRange := True;
    if SameText(lReference.Name, 'FirstOnly') and SameText(lReference.Classification, 'member') and
      (lReference.Line = 100) and (lReference.Column = 23) and (lReference.EndLine = 100) and
      (lReference.EndColumn = 31) then
      lFoundRepeatedCallArgumentRange := True;
  end;
  Assert.IsTrue(lFoundCallArgumentRange, 'Expected exact source range for FirstOnly call argument. Actual: ' +
    lRangeDetails);
  Assert.IsTrue(lFoundRepeatedCallArgumentRange,
    'Expected exact source range for repeated FirstOnly call argument. Actual: ' + lRangeDetails);
end;

procedure TWithBinderTests.InventoryExposesDakPlannerSourceModelFacts;
var
  lInventory: TDelphiSemanticRemoveWithInventory;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lIndentedDetails: string;
  lProjectedBaseName: Boolean;
  lScanSymbol: TDelphiSemanticInventorySymbol;
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  lProjectedBaseName := False;
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := FixturePath('WithBinder', 'SourceModelGoldenUnit.pas');
  lOptions.ProjectContextApplied := True;
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);

  lInventory := TDelphiSemanticWithBinder.BuildInventory(lModel);
  lInventory.Symbols := TDelphiSemanticWithBinder.ExpandInventorySymbols(lInventory.Symbols);

  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'TGoldenVariant', 'type-member', '', lSymbol));
  Assert.AreEqual('record', lSymbol.TypeCategory);
  Assert.IsTrue(lSymbol.EndLine > lSymbol.Line, 'Expected declaration end range.');

  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'Mode', 'field', 'TGoldenVariant', lSymbol));
  Assert.AreEqual('Integer', lSymbol.TypeName);
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'MultiA', 'field', 'TGoldenVariant', lSymbol));
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'MultiB', 'field', 'TGoldenVariant', lSymbol));
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'RealValue', 'field', 'TGoldenVariant', lSymbol));
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'ExtraReal', 'field', 'TGoldenVariant', lSymbol));
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'HasReal', 'field', 'TGoldenVariant', lSymbol));
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'TextValue', 'field', 'TGoldenVariant', lSymbol));
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'Offset', 'field', 'TGoldenVariant', lSymbol));
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'Size', 'field', 'TGoldenVariant', lSymbol));
  Assert.IsFalse(TryFindInventorySymbol(lInventory, 'cGoldenVariantReal', 'field',
    'TGoldenVariant', lSymbol));
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'GoldenSplitGlobal', 'unit-global', '',
    lSymbol), 'Expected split unit-global declaration.');
  Assert.AreEqual('Integer', lSymbol.TypeName);
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'gisSkip', 'constant', '', lSymbol),
    'Expected unit-global anonymous enum value.');
  Assert.AreEqual('(gisRead, gisSkip)', lSymbol.TypeName);

  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'PGoldenRecord', 'type-member', '', lSymbol));
  Assert.AreEqual('^TGoldenRecord', lSymbol.TypeName);
  Assert.AreEqual('TGoldenRecord', lSymbol.RelatedTypeName);
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'TGoldenRecordAlias', 'type-member', '',
    lSymbol));
  Assert.AreEqual('TGoldenRecord', lSymbol.TypeName);
  Assert.AreEqual('TGoldenRecord', lSymbol.RelatedTypeName);
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'RecordName', 'field', 'TGoldenRecordAlias',
    lSymbol));
  Assert.AreEqual('TGoldenRecord', lSymbol.SourceOwnerType);

  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'Items', 'property', 'TGoldenDefaultList',
    lSymbol));
  Assert.IsTrue(lSymbol.IsDefault);
  Assert.IsTrue(lSymbol.IsIndexed);
  Assert.AreEqual(1, lSymbol.IndexParameterCount);
  Assert.AreEqual('PGoldenRecord', lSymbol.TypeName);

  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'lRecords', 'local', '', lSymbol));
  Assert.AreEqual('TArray<TGoldenRecord>', lSymbol.TypeName);
  Assert.AreEqual('TGoldenScope.Run', lSymbol.RoutineName);
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'lStaticRecordPtrs', 'local', '', lSymbol));
  Assert.AreEqual('array[1..2]ofPGoldenRecord', StringReplace(lSymbol.TypeName, ' ', '',
    [rfReplaceAll]));
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'TGoldenLocalRecord', 'type-member', '',
    lSymbol));
  Assert.AreEqual('record', lSymbol.TypeCategory);
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'LocalName', 'field', 'TGoldenLocalRecord',
    lSymbol));
  Assert.AreEqual('string', lSymbol.TypeName);
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'LocalCount', 'field', 'TGoldenLocalRecord',
    lSymbol));
  Assert.AreEqual('Integer', lSymbol.TypeName);
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'lLocalRecord', 'local', '', lSymbol));
  Assert.AreEqual('TGoldenLocalRecord', lSymbol.TypeName);
  Assert.AreEqual('TGoldenScope.Run', lSymbol.RoutineName);
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'TGoldenScope.Run.lAnonymousLocal',
    'type-member', '', lSymbol));
  Assert.AreEqual('record', lSymbol.TypeCategory);
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'LocalFlag', 'field',
    'TGoldenScope.Run.lAnonymousLocal', lSymbol));
  Assert.AreEqual('Boolean', lSymbol.TypeName);
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'LocalText', 'field',
    'TGoldenScope.Run.lAnonymousLocal', lSymbol));
  Assert.AreEqual('string', lSymbol.TypeName);
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'lAnonymousLocal', 'local', '', lSymbol));
  Assert.AreEqual('TGoldenScope.Run.lAnonymousLocal', lSymbol.TypeName);
  Assert.AreEqual('TGoldenScope.Run', lSymbol.RoutineName);
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'TGoldenScope.Run.lVariantLocal',
    'type-member', '', lSymbol));
  Assert.AreEqual('record', lSymbol.TypeCategory);
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'Len', 'field',
    'TGoldenScope.Run.lVariantLocal', lSymbol));
  Assert.AreEqual('Byte', lSymbol.TypeName);
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'Kind', 'field',
    'TGoldenScope.Run.lVariantLocal', lSymbol));
  Assert.AreEqual('Integer', lSymbol.TypeName);
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'AsInteger', 'field',
    'TGoldenScope.Run.lVariantLocal', lSymbol));
  Assert.AreEqual('Integer', lSymbol.TypeName);
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'AsText', 'field',
    'TGoldenScope.Run.lVariantLocal', lSymbol));
  Assert.AreEqual('string', lSymbol.TypeName);
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'lVariantLocal', 'local', '', lSymbol));
  Assert.AreEqual('TGoldenScope.Run.lVariantLocal', lSymbol.TypeName);
  Assert.AreEqual('TGoldenScope.Run', lSymbol.RoutineName);
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'TGoldenLateLocalRecord', 'type-member', '',
    lSymbol));
  Assert.AreEqual('record', lSymbol.TypeCategory);
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'LateName', 'field', 'TGoldenLateLocalRecord',
    lSymbol));
  Assert.AreEqual('string', lSymbol.TypeName);
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'lLateLocalRecord', 'local', '', lSymbol));
  Assert.AreEqual('TGoldenLateLocalRecord', lSymbol.TypeName);
  lIndentedDetails := '';
  for lScanSymbol in lInventory.Symbols do
    if ContainsText(lScanSymbol.Name, 'GoldenIndented') or ContainsText(lScanSymbol.TypeName,
      'GoldenIndented') then
      lIndentedDetails := lIndentedDetails + lScanSymbol.Name + ':' + lScanSymbol.SymbolClass + ':' +
        lScanSymbol.TypeName + ':' + lScanSymbol.OwnerType + '; ';
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'TGoldenIndentedState', 'type-member', '',
    lSymbol), 'Expected indented implementation type. Symbols=' + lIndentedDetails);
  Assert.AreEqual('record', lSymbol.TypeCategory);
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'StateName', 'field',
    'TGoldenIndentedState', lSymbol), 'Expected indented implementation type field. Symbols=' +
    lIndentedDetails);
  Assert.AreEqual('string', lSymbol.TypeName);
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'GoldenIndentedState', 'unit-global', '',
    lSymbol), 'Expected indented implementation var. Symbols=' + lIndentedDetails);
  Assert.AreEqual('TGoldenIndentedState', lSymbol.TypeName);

  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'BaseName', 'field', 'TGoldenClass', lSymbol));
  Assert.AreEqual('TGoldenBase', lSymbol.SourceOwnerType);
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'HelperTouch', 'method', 'TGoldenRecord',
    lSymbol));
  Assert.AreEqual('TGoldenRecordHelper', lSymbol.SourceOwnerType);
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'Touch', 'method', 'TGoldenClass', lSymbol));
  Assert.IsTrue(lSymbol.IsOverride);
  for lScanSymbol in lInventory.Symbols do
    if SameText(lScanSymbol.Name, 'BaseName') and
      SameText(lScanSymbol.SymbolClass, 'current-class-member') and
      SameText(lScanSymbol.OwnerName, 'TGoldenClass') and
      SameText(lScanSymbol.RoutineName, 'TGoldenClass.Touch') then
      lProjectedBaseName := True;
  Assert.IsTrue(lProjectedBaseName);
end;

procedure TWithBinderTests.InventoryExpansionUsesIndexedOwnMemberLookup;
var
  lSourceText: string;
begin
  lSourceText := ReadRepoSource('src\DelphiSemantics.WithBinding.Inventory.pas');

  Assert.IsTrue(ContainsText(lSourceText, 'BuildInventoryOwnMemberKeys'),
    'Inventory expansion must build an indexed own-member lookup for large semantic inventories.');
  Assert.IsFalse(ContainsText(lSourceText, 'InventoryOwnerHasOwnMember(aSymbols'),
    'Inventory expansion must not scan every symbol for each related inherited member.');
end;

procedure TWithBinderTests.InventoryExpansionUsesStableRelatedMemberOwnerIndex;
var
  lExpansionEnd: Integer;
  lExpansionStart: Integer;
  lExpansionText: string;
  lSourceText: string;
begin
  lSourceText := ReadRepoSource('src\DelphiSemantics.WithBinding.Inventory.pas');
  lExpansionStart := Pos('procedure AddRelatedInventoryMemberSymbols', lSourceText);
  lExpansionEnd := Pos('procedure AddRelatedInventoryCurrentClassSymbols', lSourceText);
  lExpansionText := Copy(lSourceText, lExpansionStart, lExpansionEnd - lExpansionStart);

  Assert.IsTrue(ContainsText(lSourceText, 'BuildRelatedInventoryMemberRelations'),
    'Inventory expansion must index inherited/helper owner relations once for propagation.');
  Assert.IsFalse(ContainsText(lExpansionText, 'repeat'),
    'Inventory expansion must not rebuild related-member indexes in a repeat loop.');
end;

procedure TWithBinderTests.InventoryExpansionIndexesCurrentClassProjectionContexts;
var
  lExpansionEnd: Integer;
  lExpansionStart: Integer;
  lExpansionText: string;
  lSourceText: string;
begin
  lSourceText := ReadRepoSource('src\DelphiSemantics.WithBinding.Inventory.pas');
  lExpansionStart := Pos('procedure AddRelatedInventoryCurrentClassSymbols', lSourceText);
  lExpansionEnd := Pos('procedure AddExpandedExternalTypeSymbol', lSourceText);
  Assert.IsTrue((lExpansionStart > 0) and (lExpansionEnd > lExpansionStart),
    'Expected current-class expansion source section.');

  lExpansionText := Copy(lSourceText, lExpansionStart, lExpansionEnd - lExpansionStart);
  Assert.IsTrue(ContainsText(lExpansionText, 'lProjectedContextKeys'),
    'Current-class expansion must project each owner/routine context once.');
  Assert.IsTrue(ContainsText(lExpansionText,
    'lOwnerKey := lCurrentMember.UnitName + #31 + lCurrentMember.FileName'),
    'Current-class owner keys must include unit and file identity.');
  Assert.IsTrue(ContainsText(lExpansionText,
    'lProjectedContextKey := lOwnerKey + #31 + lCurrentMember.RoutineName'),
    'Current-class projection keys must include owner key plus routine identity.');
end;

procedure TWithBinderTests.InventoryExpansionScopesCurrentClassProjectionByUnit;
var
  lExpandedSymbols: TArray<TDelphiSemanticInventorySymbol>;
  lSymbols: TArray<TDelphiSemanticInventorySymbol>;

  function CountCurrentClassSymbol(const aName, aRoutineName,
    aUnitName: string): Integer;
  var
    lSymbol: TDelphiSemanticInventorySymbol;
  begin
    Result := 0;
    for lSymbol in lExpandedSymbols do
      if SameText(lSymbol.Name, aName) and
        SameText(lSymbol.SymbolClass, 'current-class-member') and
        SameText(lSymbol.RoutineName, aRoutineName) and
        SameText(lSymbol.UnitName, aUnitName) then
        Inc(Result);
  end;
begin
  SetLength(lSymbols, 8);

  lSymbols[0] := Default(TDelphiSemanticInventorySymbol);
  lSymbols[0].Name := 'UnitAOnly';
  lSymbols[0].SymbolClass := 'field';
  lSymbols[0].OwnerType := 'TDuplicate';
  lSymbols[0].UnitName := 'DuplicateA';
  lSymbols[0].FileName := 'DuplicateA.pas';

  lSymbols[1] := Default(TDelphiSemanticInventorySymbol);
  lSymbols[1].Name := 'UnitBOnly';
  lSymbols[1].SymbolClass := 'field';
  lSymbols[1].OwnerType := 'TDuplicate';
  lSymbols[1].UnitName := 'DuplicateB';
  lSymbols[1].FileName := 'DuplicateB.pas';

  lSymbols[2] := Default(TDelphiSemanticInventorySymbol);
  lSymbols[2].Name := 'ExistingA';
  lSymbols[2].SymbolClass := 'current-class-member';
  lSymbols[2].OwnerType := 'TDuplicate';
  lSymbols[2].RoutineName := 'RunA';
  lSymbols[2].UnitName := 'DuplicateA';
  lSymbols[2].FileName := 'DuplicateA.pas';

  lSymbols[3] := Default(TDelphiSemanticInventorySymbol);
  lSymbols[3].Name := 'ExistingB';
  lSymbols[3].SymbolClass := 'current-class-member';
  lSymbols[3].OwnerType := 'TDuplicate';
  lSymbols[3].RoutineName := 'RunB';
  lSymbols[3].UnitName := 'DuplicateB';
  lSymbols[3].FileName := 'DuplicateB.pas';

  lSymbols[4] := Default(TDelphiSemanticInventorySymbol);
  lSymbols[4].Name := 'UnitCOnly';
  lSymbols[4].SymbolClass := 'field';
  lSymbols[4].OwnerType := 'TDuplicate';
  lSymbols[4].UnitName := 'DuplicateC';
  lSymbols[4].FileName := 'DuplicateC.pas';

  lSymbols[5] := Default(TDelphiSemanticInventorySymbol);
  lSymbols[5].Name := 'UnitDOnly';
  lSymbols[5].SymbolClass := 'field';
  lSymbols[5].OwnerType := 'TDuplicate';
  lSymbols[5].UnitName := 'DuplicateD';
  lSymbols[5].FileName := 'DuplicateD.pas';

  lSymbols[6] := Default(TDelphiSemanticInventorySymbol);
  lSymbols[6].Name := 'ExistingC';
  lSymbols[6].SymbolClass := 'current-class-member';
  lSymbols[6].OwnerType := 'TDuplicate';
  lSymbols[6].RoutineName := 'RunShared';
  lSymbols[6].UnitName := 'DuplicateC';
  lSymbols[6].FileName := 'DuplicateC.pas';

  lSymbols[7] := Default(TDelphiSemanticInventorySymbol);
  lSymbols[7].Name := 'ExistingD';
  lSymbols[7].SymbolClass := 'current-class-member';
  lSymbols[7].OwnerType := 'TDuplicate';
  lSymbols[7].RoutineName := 'RunShared';
  lSymbols[7].UnitName := 'DuplicateD';
  lSymbols[7].FileName := 'DuplicateD.pas';

  lExpandedSymbols := TDelphiSemanticWithBinder.ExpandInventorySymbols(lSymbols);

  Assert.AreEqual(1, CountCurrentClassSymbol('UnitAOnly', 'RunA',
    'DuplicateA'));
  Assert.AreEqual(1, CountCurrentClassSymbol('UnitBOnly', 'RunB',
    'DuplicateB'));
  Assert.AreEqual(0, CountCurrentClassSymbol('UnitAOnly', 'RunB',
    'DuplicateA'), 'Unit A members must not project into Unit B routines.');
  Assert.AreEqual(0, CountCurrentClassSymbol('UnitBOnly', 'RunA',
    'DuplicateB'), 'Unit B members must not project into Unit A routines.');
  Assert.AreEqual(1, CountCurrentClassSymbol('UnitCOnly', 'RunShared',
    'DuplicateC'));
  Assert.AreEqual(1, CountCurrentClassSymbol('UnitDOnly', 'RunShared',
    'DuplicateD'));
end;

procedure TWithBinderTests.ReferenceScannerPreservesRepresentativeTokenShapes;
var
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lModel: TDelphiSemanticUnitModel;

  procedure AssertReference(const aBinding: TDelphiSemanticWithBinding; const aName,
    aClassification: string; const aLine, aColumn, aEndLine, aEndColumn: Integer);
  var
    lDetails: string;
    lReference: TDelphiSemanticBoundReference;
  begin
    lDetails := '';
    for lReference in aBinding.References do
    begin
      lDetails := lDetails + Format('%s/%s@%d:%d-%d:%d ', [lReference.Name,
        lReference.Classification, lReference.Line, lReference.Column,
        lReference.EndLine, lReference.EndColumn]);
      if SameText(lReference.Name, aName) and
        SameText(lReference.Classification, aClassification) and
        (lReference.Line = aLine) and (lReference.Column = aColumn) and
        (lReference.EndLine = aEndLine) and (lReference.EndColumn = aEndColumn) then
        Exit;
    end;
    Assert.Fail(Format('Expected %s/%s at %d:%d-%d:%d. Actual: %s',
      [aName, aClassification, aLine, aColumn, aEndLine, aEndColumn, lDetails]));
  end;

begin
  lModel := LoadModel;
  lBindings := TDelphiSemanticWithBinder.BindModel(lModel);

  AssertReference(lBindings[0], 'FirstOnly', 'member', 32, 5, 32, 13);
  AssertReference(lBindings[0], 'aParamValue', 'lexical', 32, 18, 32, 28);
  AssertReference(lBindings[0], 'lSecond.SecondOnly', 'unsupported', 34, 5, 34, 22);
  AssertReference(lBindings[0], 'FirstOnly[0]', 'unsupported', 38, 5, 38, 16);
  AssertReference(lBindings[7], 'KnownExternalCall', 'external', 99, 5, 99, 32);
  AssertReference(lBindings[7], 'FirstOnly', 'member', 99, 23, 99, 31);
end;

procedure TWithBinderTests.ReferenceBindingUsesManualIdentifierScanner;
var
  lArgumentScannerText: string;
  lArgumentStart: Integer;
  lBindEnd: Integer;
  lBindStart: Integer;
  lBindText: string;
  lSourceText: string;
begin
  lSourceText := ReadRepoSource('src\DelphiSemantics.WithBinding.pas');

  lArgumentStart := Pos('procedure AddArgumentReferences', lSourceText);
  lBindStart := Pos('function BindReferences', lSourceText);
  lBindEnd := Pos('function StatementContains', lSourceText);
  Assert.IsTrue((lArgumentStart > 0) and (lBindStart > lArgumentStart) and
    (lBindEnd > lBindStart), 'Expected reference binding source sections.');

  lArgumentScannerText := Copy(lSourceText, lArgumentStart, lBindStart - lArgumentStart);
  lBindText := Copy(lSourceText, lBindStart, lBindEnd - lBindStart);
  Assert.IsFalse(ContainsText(lArgumentScannerText, 'TRegEx.Match'),
    'Argument reference binding must use the manual identifier scanner.');
  Assert.IsFalse(ContainsText(lBindText, 'TRegEx.Match'),
    'Body reference binding must use the manual identifier scanner.');
end;

procedure TWithBinderTests.InventoryExpansionUsesOrdinalIgnoreCaseSymbolKeys;
var
  lKeyFunctionText: string;
  lSourceText: string;
begin
  lSourceText := ReadRepoSource('src\DelphiSemantics.WithBinding.Inventory.pas');
  lKeyFunctionText := Copy(lSourceText, Pos('function InventorySymbolKey', lSourceText), 900);

  Assert.IsTrue(ContainsText(lSourceText,
    'lKeys := TDictionary<string, Byte>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);'),
    'Inventory expansion symbol keys must use the Delphi ordinal-ignore-case comparer.');
  Assert.IsFalse(ContainsText(lKeyFunctionText, 'UpperCase('),
    'Inventory expansion must not allocate uppercase copies while building every symbol key.');
end;

procedure TWithBinderTests.InventoryExpansionDeduplicatesSymbolsCaseInsensitively;
var
  lExpandedSymbols: TArray<TDelphiSemanticInventorySymbol>;
  lLocalSymbolCount: Integer;
  lSymbol: TDelphiSemanticInventorySymbol;
  lSymbols: TArray<TDelphiSemanticInventorySymbol>;
begin
  SetLength(lSymbols, 2);
  lSymbols[0] := Default(TDelphiSemanticInventorySymbol);
  lSymbols[0].Name := 'LocalName';
  lSymbols[0].SymbolClass := 'local';
  lSymbols[0].TypeName := 'TRecord';
  lSymbols[0].RoutineName := 'TRunner.Run';
  lSymbols[0].UnitName := 'CaseUnit';
  lSymbols[0].FileName := 'CaseUnit.pas';
  lSymbols[0].Line := 10;
  lSymbols[0].Column := 5;

  lSymbols[1] := lSymbols[0];
  lSymbols[1].Name := 'localname';
  lSymbols[1].TypeName := 'trecord';
  lSymbols[1].RoutineName := 'trunner.run';
  lSymbols[1].UnitName := 'caseunit';
  lSymbols[1].FileName := 'caseunit.pas';

  lExpandedSymbols := TDelphiSemanticWithBinder.ExpandInventorySymbols(lSymbols);

  lLocalSymbolCount := 0;
  for lSymbol in lExpandedSymbols do
    if SameText(lSymbol.Name, 'LocalName') and SameText(lSymbol.SymbolClass, 'local') then
      Inc(lLocalSymbolCount);

  Assert.AreEqual(1, lLocalSymbolCount,
    'Inventory expansion must keep duplicate symbol identity case-insensitive.');
end;

procedure TWithBinderTests.AnonymousNestedRecordSelectorsUseSyntheticOwner;
var
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lInventory: TDelphiSemanticRemoveWithInventory;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := FixturePath('WithBinder', 'NestedAnonymousWithUnit.pas');
  lOptions.ProjectContextApplied := True;
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);

  lInventory := TDelphiSemanticWithBinder.BuildInventory(lModel);
  lInventory.Symbols := TDelphiSemanticWithBinder.ExpandInventorySymbols(lInventory.Symbols);
  Assert.IsFalse(TryFindInventorySymbol(lInventory, 'Version', 'field', 'DBF_File', lSymbol),
    'Expected nested anonymous fields not to be flattened onto the outer record.');
  Assert.IsFalse(TryFindInventorySymbol(lInventory, 'RecSize', 'field', 'DBF_File', lSymbol),
    'Expected nested anonymous fields not to be flattened onto the outer record.');

  lBindings := TDelphiSemanticWithBinder.BindModel(lModel);

  Assert.AreEqual(1, Integer(Length(lBindings)));
  Assert.AreEqual('DBF_File', lBindings[0].Selectors[0].TypeName);
  Assert.AreEqual('DBF_File.Struktur', lBindings[0].Selectors[1].TypeName);
  Assert.IsTrue(HasReference(lBindings[0], 'Version', 'member'));
  Assert.AreEqual('DBF_File.Struktur', ReceiverOf(lBindings[0], 'Version', 'member'));
  Assert.IsTrue(HasReference(lBindings[0], 'RecSize', 'member'));
end;

procedure TWithBinderTests.GlobalAnonymousRecordSelectorUsesSyntheticOwner;
var
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lInventory: TDelphiSemanticRemoveWithInventory;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := FixturePath('WithBinder', 'GlobalAnonymousWithUnit.pas');
  lOptions.ProjectContextApplied := True;
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);

  lInventory := TDelphiSemanticWithBinder.BuildInventory(lModel);
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'ModuleError', 'unit-global', '',
    lSymbol));
  Assert.AreEqual('GlobalAnonymousWithUnit.ModuleError', lSymbol.TypeName);
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'LineNo', 'field',
    'GlobalAnonymousWithUnit.ModuleError', lSymbol));

  lBindings := TDelphiSemanticWithBinder.BindModel(lModel);

  Assert.AreEqual(1, Integer(Length(lBindings)));
  Assert.AreEqual('ModuleError', lBindings[0].Selectors[0].SelectorText);
  Assert.AreEqual('GlobalAnonymousWithUnit.ModuleError', lBindings[0].Selectors[0].TypeName);
  Assert.IsTrue(HasReference(lBindings[0], 'fc', 'member'));
  Assert.IsTrue(HasReference(lBindings[0], 'LineNo', 'member'));
  Assert.IsTrue(HasReference(lBindings[0], 'ErrorChar', 'member'));
  Assert.AreEqual('GlobalAnonymousWithUnit.ModuleError', ReceiverOf(lBindings[0], 'fc', 'member'));
end;

procedure TWithBinderTests.DefaultIndexedPropertyPointerSelectorDereferencesToRecord;
var
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := FixturePath('WithBinder', 'DefaultPointerWithUnit.pas');
  lOptions.ProjectContextApplied := True;
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);

  lBindings := TDelphiSemanticWithBinder.BindModel(lModel);

  Assert.AreEqual(1, Integer(Length(lBindings)));
  Assert.AreEqual('lList[0]^', lBindings[0].Selectors[0].SelectorText);
  Assert.AreEqual('TDefaultRecord', lBindings[0].Selectors[0].TypeName);
  Assert.IsTrue(HasReference(lBindings[0], 'Value', 'member'));
  Assert.AreEqual('TDefaultRecord', ReceiverOf(lBindings[0], 'Value', 'member'));
end;

procedure TWithBinderTests.NestedParentDefaultIndexedPropertyPointerSelectorDereferencesToRecord;
var
  lBinding: TDelphiSemanticWithBinding;
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lCount: Integer;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := FixturePath('WithBinder',
    'NestedParentDefaultPointerWithUnit.pas');
  lOptions.ProjectContextApplied := True;
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);
  lBindings := TDelphiSemanticWithBinder.BindModel(lModel);
  lCount := 0;
  for lBinding in lBindings do
    if SameText(lBinding.RoutineName, 'RunNested') and
      SameText(lBinding.SelectorText, 'Maske[i]^') then
    begin
      Inc(lCount);
      Assert.AreEqual(2, Integer(Length(lBinding.Selectors)));
      Assert.AreEqual('TDatFile', lBinding.Selectors[0].TypeName);
      Assert.AreEqual('NestedParentDefaultPointerWithUnit',
        lBinding.Selectors[0].TypeIdentity.UnitName);
      Assert.AreEqual('TDatFile', lBinding.Selectors[0].TypeIdentity.Name);
      Assert.IsTrue(lBinding.Selectors[0].TypeIdentity.DeclaredId.Value <> '');
      Assert.AreEqual('resolved', lBinding.Selectors[1].Status);
      Assert.AreEqual('TMaskEntry', lBinding.Selectors[1].TypeName);
      Assert.AreEqual('NestedParentDefaultPointerWithUnit',
        lBinding.Selectors[1].TypeIdentity.UnitName);
      Assert.AreEqual('TMaskEntry', lBinding.Selectors[1].TypeIdentity.Name);
      Assert.IsTrue(lBinding.Selectors[1].TypeIdentity.DeclaredId.Value <> '');
      Assert.IsTrue(HasReference(lBinding, 'Value', 'member'));
      Assert.AreEqual('TMaskEntry', ReceiverOf(lBinding, 'Value', 'member'));
    end;
  Assert.AreEqual(1, lCount);
end;

procedure TWithBinderTests.NestedParentIndexedSelectorPreservesPrecedenceAndSafety;
var
  lBinding: TDelphiSemanticWithBinding;
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lDeclaration: TDelphiSemanticDeclaration;
  lDiagnostic: TDelphiSemanticModelDiagnostic;
  lFoundAmbiguous: Boolean;
  lFoundIncomplete: Boolean;
  lFallbackCount: Integer;
  lMember: TDelphiSemanticMember;
  lModel: TDelphiSemanticUnitModel;
  lNearestCount: Integer;
  lOptions: TDelphiSemanticModelOptions;
  lShadowCount: Integer;
  lUnresolvedCount: Integer;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := FixturePath('WithBinder',
    'NestedParentDefaultPointerWithUnit.pas');
  lOptions.ProjectContextApplied := True;
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);
  lBindings := TDelphiSemanticWithBinder.BindModel(lModel);
  lShadowCount := 0;
  lNearestCount := 0;
  lFallbackCount := 0;
  lUnresolvedCount := 0;
  for lBinding in lBindings do
  begin
    if not SameText(lBinding.SelectorText, 'Maske[0]^') then
      Continue;
    if SameText(lBinding.RoutineName, 'RunShadow') then
    begin
      Inc(lShadowCount);
      Assert.AreEqual('TMaskEntry', lBinding.Selectors[1].TypeName);
      Assert.IsTrue(HasReference(lBinding, 'Value', 'member'));
    end else if SameText(lBinding.RoutineName, 'RunNearestParent') then
    begin
      Inc(lNearestCount);
      Assert.AreEqual(3, Integer(Length(lBinding.Selectors)));
      Assert.AreEqual('TAltEntry', lBinding.Selectors[2].TypeName);
      Assert.IsTrue(HasReference(lBinding, 'AltValue', 'member'));
    end else if SameText(lBinding.RoutineName, 'RunLexicalFallback') then
    begin
      Inc(lFallbackCount);
      Assert.AreEqual('TAltEntry', lBinding.Selectors[1].TypeName);
      Assert.IsTrue(HasReference(lBinding, 'AltValue', 'member'));
    end;
  end;
  for lBinding in lBindings do
    if SameText(lBinding.RoutineName, 'RunUnresolved') and
      SameText(lBinding.SelectorText, 'Missing[0]^') then
    begin
      Inc(lUnresolvedCount);
      Assert.AreEqual('unresolved', lBinding.Selectors[1].Status,
        'RunUnresolved selector status');
      Assert.AreEqual('NAME_NOT_FOUND', lBinding.Selectors[1].ReasonCode,
        'RunUnresolved selector reason');
      Assert.AreEqual('skipped', lBinding.Status,
        'RunUnresolved receiver shields outer member homonyms in raw binding facts');
      Assert.AreEqual('UNSUPPORTED_REFERENCE', lBinding.SkipReason);
    end;
  Assert.AreEqual(1, lShadowCount);
  Assert.AreEqual(1, lNearestCount);
  Assert.AreEqual(1, lFallbackCount);
  Assert.AreEqual(1, lUnresolvedCount);

  lFoundAmbiguous := False;
  for lMember in lModel.Members do
    if SameText(lMember.OwnerName, 'TDatFile') and
      SameText(lMember.Name, 'Maske') then
    begin
      lFoundAmbiguous := True;
      Break;
    end;
  Assert.IsTrue(lFoundAmbiguous);
  SetLength(lModel.Members, Length(lModel.Members) + 1);
  lModel.Members[High(lModel.Members)] := lMember;
  lBindings := TDelphiSemanticWithBinder.BindModel(lModel);
  lFoundAmbiguous := False;
  for lBinding in lBindings do
    if SameText(lBinding.RoutineName, 'RunNested') and
      SameText(lBinding.SelectorText, 'Maske[i]^') then
    begin
      Assert.AreEqual('ambiguous', lBinding.Selectors[1].Status,
        'RunNested duplicate member selector status');
      Assert.AreEqual('MULTIPLE_MEMBER_CANDIDATES',
        lBinding.Selectors[1].ReasonCode,
        'RunNested duplicate member selector reason');
      Assert.AreEqual('skipped', lBinding.Status,
        'RunNested duplicate member raw body-reference status');
      lFoundAmbiguous := True;
    end;
  Assert.IsTrue(lFoundAmbiguous);
  SetLength(lModel.Members, Length(lModel.Members) - 1);

  lFoundIncomplete := False;
  for lDeclaration in lModel.Declarations do
    if SameText(lDeclaration.Name, 'TMaskEntry') and
      SameText(lDeclaration.Kind, 'type') and
      SameText(lDeclaration.TypeName, 'record') then
    begin
      lDiagnostic := Default(TDelphiSemanticModelDiagnostic);
      lDiagnostic.Code := 'MEMBERS_INCOMPLETE';
      lDiagnostic.FileName := lDeclaration.FileName;
      if lDiagnostic.FileName = '' then
        lDiagnostic.FileName := lModel.FileName;
      lDiagnostic.Line := lDeclaration.Line;
      SetLength(lModel.Diagnostics, Length(lModel.Diagnostics) + 1);
      lModel.Diagnostics[High(lModel.Diagnostics)] := lDiagnostic;
      lFoundIncomplete := True;
      Break;
    end;
  Assert.IsTrue(lFoundIncomplete);
  lBindings := TDelphiSemanticWithBinder.BindModel(lModel);
  for lBinding in lBindings do
    if SameText(lBinding.RoutineName, 'RunNested') and
      SameText(lBinding.SelectorText, 'Maske[i]^') then
    begin
      Assert.AreEqual('resolved', lBinding.Selectors[1].Status,
        'RunNested injected incomplete-owner selector status');
      Assert.AreEqual('TMaskEntry', lBinding.Selectors[1].TypeName);
      Assert.AreEqual('skipped', lBinding.Status,
        'RunNested injected incomplete-owner binding status');
      Assert.AreEqual('MEMBERS_INCOMPLETE', lBinding.SkipReason,
        'RunNested injected incomplete-owner safety reason');
      Exit;
    end;
  Assert.Fail('Expected nested selector binding with incomplete owner.');
end;

procedure TWithBinderTests.NestedUnresolvedSelectorRefusesFinalRewrite;
var
  lBinding: TDelphiSemanticWithBinding;
  lBindingCount: Integer;
  lEdit: TDelphiSemanticRemoveWithEdit;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lOptions: TDelphiSemanticApiOptions;
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
  lStatementCount: Integer;
  lTarget: TDelphiSemanticWithBinding;
begin
  lOptions := Default(TDelphiSemanticApiOptions);
  lOptions.ProjectFileName := FixturePath('WithBinder',
    'NestedParentDefaultPointerWith.dproj');
  lFacts := TDelphiSemanticRemoveWithCompatibilityApi.BuildProjectWithBindingFacts(lOptions);
  lBindingCount := 0;
  lTarget := Default(TDelphiSemanticWithBinding);
  for lBinding in lFacts.Bindings do
    if SameText(ExtractFileName(lBinding.FileName),
      'NestedParentDefaultPointerWithUnit.pas') and
      SameText(lBinding.UnitName, 'NestedParentDefaultPointerWithUnit') and
      SameText(lBinding.RoutineName, 'RunUnresolved') and
      SameText(lBinding.SelectorText, 'Missing[0]^') then
    begin
      Inc(lBindingCount);
      lTarget := lBinding;
      Assert.AreEqual(2, Integer(Length(lBinding.Selectors)),
        'RunUnresolved project binding selector stack');
      Assert.AreEqual('unresolved', lBinding.Selectors[1].Status,
        'RunUnresolved project selector status');
      Assert.AreEqual('NAME_NOT_FOUND', lBinding.Selectors[1].ReasonCode,
        'RunUnresolved project selector reason');
    end;
  Assert.AreEqual(1, lBindingCount,
    'RunUnresolved must identify exactly one source binding');

  lPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWith(lFacts);
  lStatementCount := 0;
  for lStatement in lPlan.FinalStatements do
    if SameText(ExtractFileName(lStatement.FileName),
      'NestedParentDefaultPointerWithUnit.pas') and
      SameText(lStatement.RoutineName, 'RunUnresolved') and
      (lStatement.Range.StartLine = lTarget.Line) and
      (lStatement.Range.StartColumn = lTarget.Column) then
    begin
      Inc(lStatementCount);
      Assert.AreEqual('skipped', lStatement.Status,
        'RunUnresolved final statement status');
      Assert.AreEqual('selector-type-not-resolved', lStatement.Reason,
        'RunUnresolved final selector refusal');
      Assert.AreEqual(0, Integer(Length(lStatement.Edits)),
        'RunUnresolved final statement edits');
      Assert.AreEqual(0, Integer(Length(lStatement.Temps)),
        'RunUnresolved final statement temps');
      for lEdit in lPlan.Edits do
        Assert.AreNotEqual(lStatement.StatementId, lEdit.StatementId,
          'RunUnresolved must have no plan edit');
    end;
  Assert.AreEqual(1, lStatementCount,
    'RunUnresolved must identify exactly one final source statement');
end;

procedure TWithBinderTests.NestedIndexedSelectorPreservesBoundTypeDeclaringUnit;
var
  lADeclaredId: string;
  lAMaskTypeCount: Integer;
  lAValueCount: Integer;
  lBDeclaredId: string;
  lBMaskTypeCount: Integer;
  lBAltValueCount: Integer;
  lBinding: TDelphiSemanticWithBinding;
  lBindingCount: Integer;
  lDeclaration: TDelphiSemanticDeclaration;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lMember: TDelphiSemanticMember;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticApiOptions;
  lRepeatedCount: Integer;
begin
  lADeclaredId := '';
  lBDeclaredId := '';
  lOptions := Default(TDelphiSemanticApiOptions);
  lOptions.ProjectFileName := FixturePath('WithBinder',
    'NestedParentDefaultPointerWith.dproj');
  lFacts := TDelphiSemanticRemoveWithCompatibilityApi.BuildProjectWithBindingFacts(lOptions);
  lAMaskTypeCount := 0;
  lAValueCount := 0;
  lBMaskTypeCount := 0;
  lBAltValueCount := 0;
  for lModel in lFacts.UnitModels do
  begin
    for lDeclaration in lModel.Declarations do
      if SameText(lDeclaration.Name, 'TMaskType') and
        SameText(lDeclaration.Kind, 'type') then
      begin
        if SameText(lModel.UnitName, 'NestedParentBoundTypeOwnerA') then
          Inc(lAMaskTypeCount)
        else if SameText(lModel.UnitName, 'NestedParentBoundTypeOwnerB') then
          Inc(lBMaskTypeCount);
      end;
    for lMember in lModel.Members do
    begin
      if SameText(lModel.UnitName, 'NestedParentBoundTypeOwnerA') and
        SameText(lMember.OwnerName, 'TMaskEntry') and
        SameText(lMember.Name, 'Value') then
        Inc(lAValueCount);
      if SameText(lModel.UnitName, 'NestedParentBoundTypeOwnerB') and
        SameText(lMember.OwnerName, 'TAltEntry') and
        SameText(lMember.Name, 'AltValue') then
        Inc(lBAltValueCount);
    end;
  end;
  Assert.AreEqual(1, lAMaskTypeCount,
    'Imported owner A must declare one TMaskType');
  Assert.AreEqual(1, lBMaskTypeCount,
    'Caller B must declare a colliding local TMaskType');
  Assert.AreEqual(1, lAValueCount,
    'Value must belong to A.TMaskEntry');
  Assert.AreEqual(1, lBAltValueCount,
    'AltValue must belong to B.TAltEntry');

  lBindingCount := 0;
  for lBinding in lFacts.Bindings do
    if SameText(ExtractFileName(lBinding.FileName),
      'NestedParentBoundTypeOwnerB.pas') and
      SameText(lBinding.UnitName, 'NestedParentBoundTypeOwnerB') and
      SameText(lBinding.RoutineName, 'RunImportedBoundType') and
      SameText(lBinding.SelectorText, 'Maske[0]^') then
    begin
      Inc(lBindingCount);
      Assert.AreEqual(2, Integer(Length(lBinding.Selectors)),
        'Imported nested selector must retain outer D');
      Assert.AreEqual('resolved', lBinding.Selectors[1].Status,
        'Imported A.Maske selector status');
      Assert.AreEqual('TMaskEntry', lBinding.Selectors[1].TypeName,
        'A.TDatFile.Maske must retain A.TMaskType despite caller B homonym');
      Assert.AreEqual('NestedParentBoundTypeOwnerA',
        lBinding.Selectors[1].TypeIdentity.UnitName);
      Assert.AreEqual('NestedParentBoundTypeOwnerA.pas',
        ExtractFileName(lBinding.Selectors[1].TypeIdentity.SourceRange.FileName));
      lADeclaredId := lBinding.Selectors[1].TypeIdentity.DeclaredId.Value;
      Assert.IsTrue(lADeclaredId <> '');
      Assert.IsTrue(HasReference(lBinding, 'Value', 'member'),
        'Value must bind to A.TMaskEntry member');
      Assert.AreEqual('TMaskEntry', ReceiverOf(lBinding, 'Value', 'member'),
        'Value receiver must retain A.TMaskEntry type');
    end;
  Assert.AreEqual(1, lBindingCount,
    'Expected one nested imported A.Maske binding in B');

  lRepeatedCount := 0;
  for lBinding in lFacts.Bindings do
    if SameText(lBinding.UnitName, 'NestedParentBoundTypeOwnerB') and
      (SameText(lBinding.RoutineName, 'RunLocalThenImported') or
      SameText(lBinding.RoutineName, 'RunImportedThenLocal')) and
      SameText(lBinding.SelectorText, 'Maske[0]^') then
    begin
      Inc(lRepeatedCount);
      Assert.AreEqual(2, Integer(Length(lBinding.Selectors)),
        'Repeated two-owner selector stack');
      if SameText(lBinding.Selectors[0].SelectorText, 'D') then
      begin
        Assert.AreEqual('TMaskEntry', lBinding.Selectors[1].TypeName,
          'Imported A receiver must retain A type in either order');
        Assert.AreEqual('NestedParentBoundTypeOwnerA',
          lBinding.Selectors[1].TypeIdentity.UnitName);
        Assert.IsTrue(HasReference(lBinding, 'Value', 'member'),
          'Imported A receiver must bind A.Value in either order');
      end else if SameText(lBinding.Selectors[0].SelectorText, 'L') then
      begin
        Assert.AreEqual('TAltEntry', lBinding.Selectors[1].TypeName,
          'Local B receiver must retain B type in either order');
        Assert.AreEqual('NestedParentBoundTypeOwnerB',
          lBinding.Selectors[1].TypeIdentity.UnitName);
        lBDeclaredId := lBinding.Selectors[1].TypeIdentity.DeclaredId.Value;
        Assert.IsTrue(lBDeclaredId <> '');
        Assert.IsTrue(HasReference(lBinding, 'AltValue', 'member'),
          'Local B receiver must bind B.AltValue in either order');
      end else
        Assert.Fail('Unexpected outer receiver in repeated two-owner case.');
    end;
  Assert.AreEqual(4, lRepeatedCount,
    'Both receiver orders must produce two distinct inner bindings');
  Assert.IsTrue((lADeclaredId <> '') and (lBDeclaredId <> '') and
    (lADeclaredId <> lBDeclaredId),
    'Same-name owner types in imported and caller units need distinct declarations.');
end;

procedure TWithBinderTests.HiddenCompleteReceiverIgnoresUnrelatedDiagnostics;
var
  i: Integer;
  lAliasDetails: string;
  lBinding: TDelphiSemanticWithBinding;
  lCount: Integer;
  lDeclaration: TDelphiSemanticDeclaration;
  lDeclarationFileName: string;
  lDiagnostic: TDelphiSemanticModelDiagnostic;
  lDiagnosticDetails: string;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lHiddenOwnerLine: Integer;
  lIdentityDetails: string;
  lModels: TArray<TDelphiSemanticUnitModel>;
begin
  lModels := LoadReceiverSafetyModels;
  lAliasDetails := '';
  lDiagnosticDetails := '';
  lHiddenOwnerLine := 0;
  Assert.AreEqual(1, Integer(Length(lModels[3].InterfaceUses)),
    'Caller imports only the intermediate owner');
  Assert.IsTrue(SameText(lModels[3].InterfaceUses[0], 'ReceiverSafetyOwner'),
    'Caller import must be the intermediate owner');
  for i := 0 to 3 do
    for lDeclaration in lModels[i].Declarations do
    begin
      lDeclarationFileName := lDeclaration.FileName;
      if lDeclarationFileName = '' then
        lDeclarationFileName := lModels[i].FileName;
      if (i = 0) and SameText(lDeclaration.Name, 'THiddenEntry') and
        SameText(lDeclaration.Kind, 'type') then
        lHiddenOwnerLine := lDeclaration.Line;
      if ((i = 0) and SameText(lDeclaration.Name, 'PHiddenEntry')) or
        ((i = 1) and SameText(lDeclaration.Name, 'TAliasPointer')) then
        lAliasDetails := lAliasDetails + Format('%s.%s=%s@%s:%d; ',
          [lModels[i].UnitName, lDeclaration.Name, lDeclaration.TypeName,
          ExtractFileName(lDeclarationFileName), lDeclaration.Line]);
      if ((i = 0) and SameText(lDeclaration.Name, 'TUnrelated')) or
        ((i = 2) and SameText(lDeclaration.Name, 'TOther')) or
        ((i = 3) and SameText(lDeclaration.Name, 'THiddenEntry')) then
      begin
        Assert.AreEqual('type', lDeclaration.Kind,
          lModels[i].UnitName + '.' + lDeclaration.Name + ' diagnostic owner kind');
        Assert.AreEqual('record', lDeclaration.TypeName,
          lModels[i].UnitName + '.' + lDeclaration.Name + ' diagnostic owner type');
        lDiagnosticDetails := lDiagnosticDetails + Format('%s.%s %s/%s@%s:%d; ',
          [lModels[i].UnitName, lDeclaration.Name, lDeclaration.Kind,
          lDeclaration.TypeName, ExtractFileName(lDeclarationFileName),
          lDeclaration.Line]);
        lDiagnostic := Default(TDelphiSemanticModelDiagnostic);
        lDiagnostic.Code := 'MEMBERS_INCOMPLETE';
        lDiagnostic.FileName := lModels[i].FileName;
        lDiagnostic.Line := lDeclaration.Line;
        SetLength(lModels[i].Diagnostics, Length(lModels[i].Diagnostics) + 1);
        lModels[i].Diagnostics[High(lModels[i].Diagnostics)] := lDiagnostic;
      end;
    end;
  Assert.IsTrue(lHiddenOwnerLine > 0, 'Hidden receiver declaration must have a line');
  Assert.AreEqual(1, Integer(Length(lModels[0].Diagnostics)),
    'Hidden unit has one unrelated diagnostic');
  Assert.AreEqual(1, Integer(Length(lModels[2].Diagnostics)),
    'Intermediate owner has one unrelated diagnostic');
  Assert.AreEqual(1, Integer(Length(lModels[3].Diagnostics)),
    'Caller homonym has one unrelated diagnostic');
  lFacts := TDelphiSemanticWithBinder.BindProject('', nil, lModels);
  lCount := 0;
  for lBinding in lFacts.Bindings do
    if SameText(lBinding.UnitName, 'ReceiverSafetyCaller') and
      SameText(lBinding.SelectorText, 'Item^') then
    begin
      Inc(lCount);
      Assert.AreEqual(2, Integer(Length(lBinding.Selectors)),
        'Nested selector keeps its parent');
      lIdentityDetails := Format(
        'parent=%s.%s id=%s source=%s:%d; receiver=%s.%s id=%s source=%s:%d; aliases=%s; diagnostics=%s',
        [lBinding.Selectors[0].TypeIdentity.UnitName,
        lBinding.Selectors[0].TypeIdentity.Name,
        lBinding.Selectors[0].TypeIdentity.DeclaredId.Value,
        ExtractFileName(lBinding.Selectors[0].TypeIdentity.SourceRange.FileName),
        lBinding.Selectors[0].TypeIdentity.SourceRange.Line,
        lBinding.Selectors[1].TypeIdentity.UnitName,
        lBinding.Selectors[1].TypeIdentity.Name,
        lBinding.Selectors[1].TypeIdentity.DeclaredId.Value,
        ExtractFileName(lBinding.Selectors[1].TypeIdentity.SourceRange.FileName),
        lBinding.Selectors[1].TypeIdentity.SourceRange.Line,
        lAliasDetails, lDiagnosticDetails]);
      Assert.AreEqual('resolved', lBinding.Selectors[1].Status);
      Assert.AreEqual('THiddenEntry', lBinding.Selectors[1].TypeName);
      Assert.AreEqual('ReceiverSafetyOwner',
        lBinding.Selectors[0].TypeIdentity.UnitName, lIdentityDetails);
      Assert.AreEqual('ReceiverSafetyHidden',
        lBinding.Selectors[1].TypeIdentity.UnitName, lIdentityDetails);
      Assert.AreEqual('THiddenEntry',
        lBinding.Selectors[1].TypeIdentity.Name, lIdentityDetails);
      Assert.AreEqual(lHiddenOwnerLine,
        lBinding.Selectors[1].TypeIdentity.SourceRange.Line, lIdentityDetails);
      Assert.IsTrue(SameText(lModels[0].FileName,
        lBinding.Selectors[1].TypeIdentity.SourceRange.FileName), lIdentityDetails);
      Assert.IsNotEmpty(lBinding.Selectors[1].TypeIdentity.DeclaredId.Value,
        lIdentityDetails);
      Assert.AreNotEqual('MEMBERS_INCOMPLETE', lBinding.SkipReason,
        'Complete hidden receiver must ignore unrelated diagnostics. ' +
        lIdentityDetails);
      Assert.AreNotEqual('MEMBERS_UNVERIFIED', lBinding.SkipReason,
        'No hidden owner has unverified members');
    end;
  Assert.AreEqual(1, lCount, 'Expected one nested hidden receiver');
end;

procedure TWithBinderTests.AmbiguousFinalReceiverTypeFailsClosed;
var
  i: Integer;
  j: Integer;
  lBinding: TDelphiSemanticWithBinding;
  lBindingCount: Integer;
  lDeclaration: TDelphiSemanticDeclaration;
  lDiagnostic: TDelphiSemanticModelDiagnostic;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lModels: TArray<TDelphiSemanticUnitModel>;
  lResultCount: Integer;
  lTemplate: TDelphiSemanticDeclaration;
  lTemplateFound: Boolean;
  lValueCount: Integer;
  lWithCount: Integer;
begin
  lModels := LoadReceiverSafetyModels;
  lTemplate := Default(TDelphiSemanticDeclaration);
  lTemplateFound := False;
  for lDeclaration in lModels[0].Declarations do
    if SameText(lDeclaration.Name, 'THiddenEntry') and
      SameText(lDeclaration.Kind, 'type') then
    begin
      Assert.IsFalse(lTemplateFound, 'Expected one parsed hidden record type');
      lTemplate := lDeclaration;
      lTemplateFound := True;
    end;
  Assert.IsTrue(lTemplateFound, 'Hidden record type must come from the parsed fixture');
  Assert.AreEqual('record', lTemplate.TypeName);
  Assert.AreEqual('unit', lTemplate.ScopeKind);
  Assert.AreEqual('interface', lTemplate.SectionKind);
  Assert.AreEqual(LowerCase(lModels[0].UnitName), lTemplate.OwnerScopeId);
  Assert.IsNotEmpty(lTemplate.SymbolId);
  for i := 0 to 1 do
  begin
    j := Length(lModels[0].Declarations);
    SetLength(lModels[0].Declarations, j + 1);
    lModels[0].Declarations[j] := lTemplate;
    lModels[0].Declarations[j].Name := 'TResult';
    lModels[0].Declarations[j].Line := lTemplate.Line + 20 + i;
    lModels[0].Declarations[j].Offset := lTemplate.Offset + 200 + i * 10;
    lModels[0].Declarations[j].EndOffset := lTemplate.EndOffset + 200 + i * 10;
    lModels[0].Declarations[j].SymbolId := lTemplate.SymbolId + ':result-' + IntToStr(i);
  end;
  lResultCount := 0;
  for lDeclaration in lModels[0].Declarations do
    if SameText(lDeclaration.Name, 'TResult') and
      SameText(lDeclaration.ScopeKind, 'unit') and
      SameText(lDeclaration.SectionKind, 'interface') then
      Inc(lResultCount);
  Assert.AreEqual(2, lResultCount,
    'Two exported declarations share the final qualified type name');
  Assert.AreNotEqual(lModels[0].Declarations[High(lModels[0].Declarations) - 1].SymbolId,
    lModels[0].Declarations[High(lModels[0].Declarations)].SymbolId);
  lValueCount := 0;
  for i := 0 to High(lModels[0].Members) do
    if SameText(lModels[0].Members[i].OwnerName, 'THiddenEntry') and
      SameText(lModels[0].Members[i].Name, 'Value') then
    begin
      Inc(lValueCount);
      lModels[0].Members[i].TypeName := 'TResult';
    end;
  Assert.AreEqual(1, lValueCount, 'Mutated member must be the parsed hidden field');
  lWithCount := 0;
  for i := 0 to High(lModels[3].WithStatements) do
    if SameText(lModels[3].WithStatements[i].SelectorText, 'Item^') then
    begin
      Inc(lWithCount);
      lModels[3].WithStatements[i].SelectorText := 'Item^.Value';
    end;
  Assert.AreEqual(1, lWithCount, 'Mutated selector must be the parsed nested with');
  for i := 0 to 3 do
    for lDeclaration in lModels[i].Declarations do
      if ((i = 0) and SameText(lDeclaration.Name, 'TUnrelated')) or
        ((i = 2) and SameText(lDeclaration.Name, 'TOther')) or
        ((i = 3) and SameText(lDeclaration.Name, 'THiddenEntry')) then
      begin
        Assert.AreEqual('type', lDeclaration.Kind);
        Assert.AreEqual('record', lDeclaration.TypeName);
        lDiagnostic := Default(TDelphiSemanticModelDiagnostic);
        lDiagnostic.Code := 'MEMBERS_INCOMPLETE';
        lDiagnostic.FileName := lModels[i].FileName;
        lDiagnostic.Line := lDeclaration.Line;
        j := Length(lModels[i].Diagnostics);
        SetLength(lModels[i].Diagnostics, j + 1);
        lModels[i].Diagnostics[j] := lDiagnostic;
      end;
  Assert.AreEqual(1, Integer(Length(lModels[0].Diagnostics)));
  Assert.AreEqual(1, Integer(Length(lModels[2].Diagnostics)));
  Assert.AreEqual(1, Integer(Length(lModels[3].Diagnostics)));
  lFacts := TDelphiSemanticWithBinder.BindProject('', nil, lModels);
  lBindingCount := 0;
  for lBinding in lFacts.Bindings do
    if SameText(lBinding.UnitName, 'ReceiverSafetyCaller') and
      SameText(lBinding.SelectorText, 'Item^.Value') then
    begin
      Inc(lBindingCount);
      Assert.AreEqual(2, Integer(Length(lBinding.Selectors)));
      Assert.AreEqual('ReceiverSafetyOwner',
        lBinding.Selectors[0].TypeIdentity.UnitName);
      Assert.AreEqual('resolved', lBinding.Selectors[1].Status);
      Assert.AreEqual('TResult', lBinding.Selectors[1].TypeName);
      Assert.AreEqual('', lBinding.Selectors[1].TypeIdentity.UnitName,
        'Ambiguous exported final type must not acquire a unit identity');
      Assert.AreEqual('', lBinding.Selectors[1].TypeIdentity.DeclaredId.Value,
        'Ambiguous exported final type must not acquire one declared ID');
      Assert.AreEqual('MEMBERS_INCOMPLETE', lBinding.SkipReason,
        'Ambiguous final receiver must refuse member-safety lineage');
    end;
  Assert.AreEqual(1, lBindingCount, 'Expected one mutated nested receiver');
end;

procedure TWithBinderTests.HiddenReceiverExactOwnerDiagnosticsRefuse;
var
  lBinding: TDelphiSemanticWithBinding;
  lDeclaration: TDelphiSemanticDeclaration;
  lDiagnostic: TDelphiSemanticModelDiagnostic;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lFound: Boolean;
  lModels: TArray<TDelphiSemanticUnitModel>;
  lOwnerLine: Integer;
  lReason: string;
begin
  lModels := LoadReceiverSafetyModels;
  lOwnerLine := 0;
  for lDeclaration in lModels[0].Declarations do
    if SameText(lDeclaration.Name, 'THiddenEntry') and
      SameText(lDeclaration.Kind, 'type') then
      lOwnerLine := lDeclaration.Line;
  Assert.IsTrue(lOwnerLine > 0, 'Hidden receiver declaration must be source backed');
  for lReason in ['MEMBERS_INCOMPLETE', 'MEMBERS_UNVERIFIED'] do
  begin
    lDiagnostic := Default(TDelphiSemanticModelDiagnostic);
    lDiagnostic.Code := lReason;
    lDiagnostic.FileName := lModels[0].FileName;
    if SameText(lReason, 'MEMBERS_INCOMPLETE') then
      lDiagnostic.Line := lOwnerLine;
    lModels[0].Diagnostics := [lDiagnostic];
    lFacts := TDelphiSemanticWithBinder.BindProject('', nil, lModels);
    lFound := False;
    for lBinding in lFacts.Bindings do
      if SameText(lBinding.UnitName, 'ReceiverSafetyCaller') and
        SameText(lBinding.SelectorText, 'Item^') then
      begin
        lFound := True;
        Assert.AreEqual('resolved', lBinding.Selectors[1].Status);
        Assert.AreEqual(lReason, lBinding.SkipReason,
          'Exact hidden owner diagnostic must refuse the binding');
      end;
    Assert.IsTrue(lFound, 'Expected one nested hidden receiver');
  end;
end;

procedure TWithBinderTests.BareImportedReceiverUsesActualOwnerForSafety;
var
  lBinding: TDelphiSemanticWithBinding;
  lDeclaration: TDelphiSemanticDeclaration;
  lDiagnostic: TDelphiSemanticModelDiagnostic;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lFound: Boolean;
  lModels: TArray<TDelphiSemanticUnitModel>;
  lOwnerLine: Integer;
  lReason: string;
begin
  lModels := LoadBareReceiverSafetyModels;
  Assert.AreEqual(1, Integer(Length(lModels[2].InterfaceUses)),
    'Caller imports only the variable owner');
  Assert.IsTrue(SameText(lModels[2].InterfaceUses[0], 'ReceiverSafetyBareOwner'));
  lOwnerLine := 0;
  for lDeclaration in lModels[0].Declarations do
    if SameText(lDeclaration.Name, 'THiddenEntry') and
      SameText(lDeclaration.Kind, 'type') then
      lOwnerLine := lDeclaration.Line;
  Assert.IsTrue(lOwnerLine > 0, 'Hidden receiver declaration must be source backed');
  for lReason in ['MEMBERS_INCOMPLETE', 'MEMBERS_UNVERIFIED'] do
  begin
    lDiagnostic := Default(TDelphiSemanticModelDiagnostic);
    lDiagnostic.Code := lReason;
    lDiagnostic.FileName := lModels[0].FileName;
    if SameText(lReason, 'MEMBERS_INCOMPLETE') then
      lDiagnostic.Line := lOwnerLine;
    lModels[0].Diagnostics := [lDiagnostic];
    lFacts := TDelphiSemanticWithBinder.BindProject('', nil, lModels);
    lFound := False;
    for lBinding in lFacts.Bindings do
      if SameText(lBinding.UnitName, 'ReceiverSafetyBareCaller') and
        SameText(lBinding.SelectorText, 'G') then
      begin
        lFound := True;
        Assert.AreEqual('resolved', lBinding.Selectors[0].Status);
        Assert.AreEqual('THiddenEntry', lBinding.Selectors[0].TypeName);
        Assert.AreEqual(lReason, lBinding.SkipReason,
          'Bare imported receiver must refuse exact hidden owner diagnostic');
      end;
    Assert.IsTrue(lFound, 'Expected bare imported G binding');
  end;
  lModels[0].Diagnostics := nil;
  for lDeclaration in lModels[2].Declarations do
    if SameText(lDeclaration.Name, 'THiddenEntry') and
      SameText(lDeclaration.Kind, 'type') then
    begin
      lDiagnostic := Default(TDelphiSemanticModelDiagnostic);
      lDiagnostic.Code := 'MEMBERS_INCOMPLETE';
      lDiagnostic.FileName := lModels[2].FileName;
      lDiagnostic.Line := lDeclaration.Line;
      lModels[2].Diagnostics := [lDiagnostic];
    end;
  Assert.AreEqual(1, Integer(Length(lModels[2].Diagnostics)),
    'Caller homonym diagnostic must be source backed');
  lFacts := TDelphiSemanticWithBinder.BindProject('', nil, lModels);
  lFound := False;
  for lBinding in lFacts.Bindings do
    if SameText(lBinding.UnitName, 'ReceiverSafetyBareCaller') and
      SameText(lBinding.SelectorText, 'G') then
    begin
      lFound := True;
      Assert.AreNotEqual('MEMBERS_INCOMPLETE', lBinding.SkipReason,
        'Caller homonym diagnostic cannot refuse imported G');
    end;
  Assert.IsTrue(lFound, 'Expected bare imported G binding');
end;

procedure TWithBinderTests.BareImportedReceiverWithoutVisibleOwnerIsRefused;
var
  lBinding: TDelphiSemanticWithBinding;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lFound: Boolean;
  lModels: TArray<TDelphiSemanticUnitModel>;
begin
  lModels := LoadBareReceiverSafetyModels;
  lModels[2].InterfaceUses := nil;
  Assert.AreEqual(0, Integer(Length(lModels[2].InterfaceUses)));
  lFacts := TDelphiSemanticWithBinder.BindProject('', nil, lModels);
  lFound := False;
  for lBinding in lFacts.Bindings do
    if SameText(lBinding.UnitName, 'ReceiverSafetyBareCaller') and
      SameText(lBinding.SelectorText, 'G') then
    begin
      lFound := True;
      Assert.AreEqual('unresolved', lBinding.Selectors[0].Status,
        'Indexed G without a visible declaring unit must not bind');
      Assert.AreEqual('SELECTOR_TYPE_NOT_RESOLVED',
        lBinding.Selectors[0].ReasonCode);
      Assert.AreNotEqual('', lBinding.SkipReason,
        'Missing receiver provenance must refuse the binding without diagnostics');
    end;
  Assert.IsTrue(lFound, 'Expected bare imported G binding');
end;

procedure TWithBinderTests.RoutineTypeHomonymCannotSupplyReceiverMember(const aShape: string);
var
  lRoot, lReceiver, lGlobals, lBody: string;
  lOptions: TDelphiSemanticApiOptions;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lBinding: TDelphiSemanticWithBinding;
  lReference: TDelphiSemanticBoundReference;
  lPlan, lSnapshotPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
  lFound: Boolean;
  i: Integer;
begin
  lRoot := WithBinderTempPath('routine-type-homonym-' + aShape);
  TDirectory.CreateDirectory(lRoot);
  lGlobals := '';
  lReceiver := 'type TRec = ControlUnit.TRec;'#13#10'var R: TRec;'#13#10;
  lBody := 'Count := Count + 1';
  if aShape = 'direct' then
  begin
    lGlobals := 'var R: TRec;'#13#10'  Count: Integer;'#13#10;
    lReceiver := '';
    lBody := 'Other := Count';
  end;
  TFile.WriteAllText(TPath.Combine(lRoot, 'ControlUnit.pas'),
    'unit ControlUnit;'#13#10'interface'#13#10'type'#13#10 +
    '  TRec = record Other: Integer; end;'#13#10 + lGlobals +
    'implementation'#13#10'procedure X;'#13#10'type'#13#10 +
    '  TRec = record Count: Integer; end;'#13#10'var L: TRec;'#13#10 +
    'begin'#13#10'  L.Count := 1;'#13#10'end;'#13#10'end.', TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'Unit1.pas'),
    'unit Unit1;'#13#10'interface'#13#10'uses ControlUnit;'#13#10 + lReceiver +
    'implementation'#13#10'procedure Run;'#13#10'begin'#13#10 +
    '  with R do ' + lBody + ';'#13#10'end;'#13#10'end.', TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'P.dpr'),
    'program P; uses Unit1, ControlUnit; begin end.', TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'P.dproj'),
    '<Project><PropertyGroup><MainSource>P.dpr</MainSource></PropertyGroup>' +
    '<ItemGroup><DCCReference Include="Unit1.pas"/>' +
    '<DCCReference Include="ControlUnit.pas"/></ItemGroup></Project>', TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticApiOptions);
  lOptions.ProjectFileName := TPath.Combine(lRoot, 'P.dproj');
  lOptions.Cache.SqliteCacheFileName := TPath.Combine(lRoot, 'cache.sqlite');
  for i := 0 to 1 do
  begin
    lFacts := TDelphiSemanticRemoveWithCompatibilityApi.BuildProjectWithBindingFacts(lOptions);
    lFound := False;
    for lBinding in lFacts.Bindings do
      if SameText(lBinding.UnitName, 'Unit1') then
        for lReference in lBinding.References do
          if SameText(lReference.Name, 'Count') then
          begin
            lFound := True;
            Assert.AreNotEqual('member', lReference.Classification,
              'A routine-local declaration cannot supply a unit-level receiver member.');
            if aShape = 'cross' then
              Assert.AreEqual('unresolved', lReference.Classification, lReference.ReasonCode)
            else
              Assert.AreEqual('lexical', lReference.Classification, lReference.ReasonCode);
          end;
    Assert.IsTrue(lFound);
    lPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWith(lFacts);
    lSnapshotPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWithCompatibilitySnapshot(lFacts);
    lFound := False;
    for lStatement in lPlan.FinalStatements do
      if SameText(ExtractFileName(lStatement.FileName), 'Unit1.pas') then
      begin
        lFound := True;
        Assert.IsFalse(ContainsText(lStatement.ReplacementText, '.Count'));
        if aShape = 'cross' then
        begin
          Assert.AreEqual('skipped', lStatement.Status);
          Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
          Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
          Assert.AreEqual('', lStatement.ReplacementText);
        end else begin
          Assert.AreEqual('skipped', lStatement.Status);
          Assert.AreEqual('receiver-member-owner-conflict', lStatement.Reason);
          Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
          Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
          Assert.AreEqual('', lStatement.ReplacementText);
        end;
      end;
    Assert.IsTrue(lFound);
    for lStatement in lSnapshotPlan.FinalStatements do
      if SameText(ExtractFileName(lStatement.FileName), 'Unit1.pas') then
      begin
        Assert.IsFalse(ContainsText(lStatement.ReplacementText, '.Count'));
        if aShape = 'cross' then
        begin
          Assert.AreEqual('skipped', lStatement.Status);
          Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
        end else
          Assert.AreEqual('skipped', lStatement.Status, lStatement.Reason);
      end;
  end;
end;

procedure TWithBinderTests.UnindexedHelperCacheAndLostFacts(const aMode: string);
var
  lOptions: TDelphiSemanticModelOptions;
  lModel: TDelphiSemanticUnitModel;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lObject: TJSONObject;
  lValue: TJSONPair;
  lBinding: TDelphiSemanticWithBinding;
  lReference: TDelphiSemanticBoundReference;
  lCount: Integer;
  lExpected: string;
  lSource: string;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.ProjectContextApplied := True;
  lOptions.SourceFileName := WithBinderTempPath('helper-cache-' + aMode + '.pas');
  lSource :=
    'unit HelperCache;'#13#10'interface'#13#10 +
    'type TRec = record Value: Integer; end;'#13#10'implementation'#13#10 +
    'procedure BeforeHelper;'#13#10'var lRecord: TRec; Count: Integer;'#13#10 +
    'begin'#13#10'  with lRecord do Count := 1;'#13#10'end;'#13#10 +
    'type'#13#10'  &THelp = record helper for TRec'#13#10 +
    '    function Count: Integer;'#13#10'  end;'#13#10 +
    'procedure AfterHelper;'#13#10'var lRecord: TRec; Count: Integer;'#13#10 +
    'begin'#13#10'  with lRecord do Count := 1;'#13#10'end;'#13#10 +
    'function &THelp.Count: Integer;'#13#10'begin Result := 1; end;'#13#10'end.';
  if aMode = 'overloads' then
    lSource := 'unit HelperCache;'#13#10 +
      'interface'#13#10 +
      'type'#13#10 +
      '  TRec = record Value: Integer; end;'#13#10 +
      '  TAlias = TRec;'#13#10 +
      'procedure Run; overload;'#13#10 +
      'procedure Run(X: Integer); overload;'#13#10 +
      'implementation'#13#10 +
      'var'#13#10 +
      '  GRec: TRec;'#13#10 +
      '  Count: Integer;'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      '  with GRec do Count := 1;'#13#10 +
      'end;'#13#10 +
      'type'#13#10 +
      '  &THelp = record helper for TAlias'#13#10 +
      '    class var FCount: Integer;'#13#10 +
      '    class property Count: Integer read FCount write FCount;'#13#10 +
      '  end;'#13#10 +
      'procedure Run(X: Integer);'#13#10 +
      'begin'#13#10 +
      '  with GRec do Count := 2;'#13#10 +
      'end;'#13#10 +
      'end.'#13#10;
  TFile.WriteAllText(lOptions.SourceFileName, lSource, TEncoding.ASCII);
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);
  Assert.AreEqual('ast', lModel.ScopeModelStatus);
  if aMode = 'lost' then
  begin
    lObject := TJSONObject.ParseJSONValue(ModelToJson(lModel)) as TJSONObject;
    try
      lValue := lObject.RemovePair('UnindexedHelpers');
      lValue.Free;
      lModel := JsonToModel(lObject.ToJSON);
    finally
      lObject.Free;
    end;
  end;
  lFacts := TDelphiSemanticWithBinder.BindProject('helper-cache', nil, [lModel]);
  Assert.AreEqual(2, Integer(Length(lFacts.Bindings)));
  lCount := 0;
  for lBinding in lFacts.Bindings do
    for lReference in lBinding.References do
      if SameText(lReference.Name, 'Count') then
      begin
        Inc(lCount);
        lExpected := 'unsupported';
        if (aMode <> 'lost') and
          (lBinding.Line < lModel.UnindexedHelpers[0].Line) then
          lExpected := 'lexical';
        Assert.AreEqual(lExpected, lReference.Classification, lBinding.RoutineName);
        if lExpected = 'unsupported' then
          Assert.AreEqual('RECORD_HELPER_MEMBERS_UNVERIFIED', lReference.ReasonCode);
      end;
  Assert.AreEqual(2, lCount);
end;

procedure TWithBinderTests.MalformedImportedHelperFactsFailClosed(const aMode: string);
var
  g: TGarbos;
  lOptions: TDelphiSemanticModelOptions;
  lRecordModel, lHelperModel, lSiteModel: TDelphiSemanticUnitModel;
  lObject, lEntry: TJSONObject;
  lPair: TJSONPair;
  lArray: TJSONArray;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lField, lKind: string;
  lValue: TJSONValue;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.ProjectContextApplied := True;
  lOptions.SourceFileName := WithBinderTempPath('MalformedRecord-' + StringReplace(aMode, ':', '-', [rfReplaceAll]) + '.pas');
  TFile.WriteAllText(lOptions.SourceFileName,
    'unit MalformedRecord;'#13#10'interface'#13#10 +
    'type TRec = record Value: Integer; end;'#13#10'implementation'#13#10'end.', TEncoding.ASCII);
  lRecordModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  lOptions.SourceFileName := WithBinderTempPath('MalformedHelper-' + StringReplace(aMode, ':', '-', [rfReplaceAll]) + '.pas');
  TFile.WriteAllText(lOptions.SourceFileName,
    'unit MalformedHelper;'#13#10'interface'#13#10'uses MalformedRecord;'#13#10 +
    'type'#13#10'  &THelp = record helper for TRec'#13#10 +
    '    function Count: Integer;'#13#10'  end;'#13#10'implementation'#13#10 +
    'function &THelp.Count: Integer;'#13#10'begin Result := 1; end;'#13#10'end.', TEncoding.ASCII);
  lHelperModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.AreEqual(1, Integer(Length(lHelperModel.UnindexedHelpers)));
  lObject := TJSONObject.ParseJSONValue(ModelToJson(lHelperModel)) as TJSONObject;
  GC(lObject, g);
  lPair := lObject.RemovePair('UnindexedHelpers');
  lPair.Free;
  lArray := TJSONArray.Create;
  lObject.AddPair('UnindexedHelpers', lArray);
  lEntry := nil;
  if aMode = 'null' then
    lArray.AddElement(TJSONNull.Create)
  else
  begin
    lEntry := TJSONObject.Create;
    lArray.AddElement(lEntry);
    lEntry.AddPair('Name', 'THelp');
    if aMode = 'null-target' then
      lEntry.AddPair('TargetName', TJSONNull.Create);
    lEntry.AddPair('HelperKind', 'record');
    lEntry.AddPair('SectionKind', 'interface');
    lEntry.AddPair('ScopeKind', 'unit');
    lEntry.AddPair('OwnerScopeId', 'malformedhelper');
  end;
  if Pos(':', aMode) > 0 then
  begin
    lField := Copy(aMode, 1, Pos(':', aMode) - 1);
    lKind := Copy(aMode, Pos(':', aMode) + 1, MaxInt);
    lEntry.AddPair('TargetName', 'TRec');
    lEntry.AddPair('FileName', '');
    lPair := lEntry.RemovePair(lField);
    lPair.Free;
    if lKind = 'number' then
      lValue := TJSONNumber.Create(123)
    else if lKind = 'bool' then
      lValue := TJSONBool.Create(True)
    else if lKind = 'null' then
      lValue := TJSONNull.Create
    else
      lValue := TJSONString.Create('bogus');
    lEntry.AddPair(lField, lValue);
  end;
  lHelperModel := JsonToModel(lObject.ToJSON);
  lOptions.SourceFileName := WithBinderTempPath('MalformedSite-' + StringReplace(aMode, ':', '-', [rfReplaceAll]) + '.pas');
  TFile.WriteAllText(lOptions.SourceFileName,
    'unit MalformedSite;'#13#10'interface'#13#10'uses MalformedRecord, MalformedHelper;'#13#10 +
    'implementation'#13#10'procedure Run;'#13#10'var lRecord: TRec; Count: Integer;'#13#10 +
    'begin'#13#10'  with lRecord do Count := 1;'#13#10'end;'#13#10'end.', TEncoding.ASCII);
  lSiteModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  lFacts := TDelphiSemanticWithBinder.BindProject('malformed-helper', nil,
    [lRecordModel, lHelperModel, lSiteModel]);
  Assert.AreEqual(1, Integer(Length(lFacts.Bindings)));
  Assert.IsTrue(HasReference(lFacts.Bindings[0], 'Count', 'unsupported'),
    'Malformed imported helper facts cannot authorize lexical fallback.');
  Assert.AreEqual('RECORD_HELPER_MEMBERS_UNVERIFIED',
    ReasonOf(lFacts.Bindings[0], 'Count', 'unsupported'));
  Assert.AreEqual(0, Integer(Length(lHelperModel.UnindexedHelpers)),
    'Malformed entries must not count as valid helper facts.');
end;


procedure TWithBinderTests.MalformedHelperCoordinatesFailClosed(const aMode: string);
var
  g: TGarbos;
  lOptions: TDelphiSemanticModelOptions;
  lModel: TDelphiSemanticUnitModel;
  lObject, lEntry: TJSONObject;
  lArray: TJSONArray;
  lPair: TJSONPair;
  lValue: TJSONValue;
  lField, lKind: string;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.ProjectContextApplied := True;
  lOptions.SourceFileName := WithBinderTempPath('coordinates-' +
    StringReplace(aMode, ':', '-', [rfReplaceAll]) + '.pas');
  TFile.WriteAllText(lOptions.SourceFileName,
    'unit CoordinateHelper;'#13#10'interface'#13#10 +
    'type TRec = record Value: Integer; end;'#13#10'implementation'#13#10 +
    'type'#13#10'  &THelp = record helper for TRec'#13#10 +
    '    procedure Count;'#13#10'  end;'#13#10 +
    'procedure Count;'#13#10'begin end;'#13#10 +
    'procedure Run;'#13#10'var lRecord: TRec;'#13#10 +
    'begin'#13#10'  with lRecord do Count();'#13#10'end;'#13#10 +
    'procedure &THelp.Count;'#13#10'begin end;'#13#10'end.', TEncoding.ASCII);
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.AreEqual(1, Integer(Length(lModel.UnindexedHelpers)));
  lFacts := TDelphiSemanticWithBinder.BindProject('coordinate-cold', nil, [lModel]);
  Assert.AreEqual(1, Integer(Length(lFacts.Bindings)));
  Assert.IsTrue(HasReference(lFacts.Bindings[0], 'Count', 'unsupported'));
  Assert.AreEqual('RECORD_HELPER_MEMBERS_UNVERIFIED',
    ReasonOf(lFacts.Bindings[0], 'Count', 'unsupported'));
  lObject := TJSONObject.ParseJSONValue(ModelToJson(lModel)) as TJSONObject;
  GC(lObject, g);
  lArray := lObject.GetValue('UnindexedHelpers') as TJSONArray;
  lEntry := lArray.Items[0] as TJSONObject;
  lField := Copy(aMode, 1, Pos(':', aMode) - 1);
  lKind := Copy(aMode, Pos(':', aMode) + 1, MaxInt);
  if lField = 'Column' then
  begin
    // A string column can move the helper past the WITH on the same physical line.
    lPair := lEntry.RemovePair('Line');
    lPair.Free;
    lEntry.AddPair('Line', TJSONNumber.Create(lFacts.Bindings[0].Line));
  end;
  lPair := lEntry.RemovePair(lField);
  lPair.Free;
  lValue := nil;
  if lKind = 'string' then
    lValue := TJSONString.Create('999')
  else if lKind = 'float' then
    lValue := TJSONNumber.Create('999.5')
  else if lKind = 'null' then
    lValue := TJSONNull.Create
  else if lKind = 'bool' then
    lValue := TJSONBool.Create(True)
  else if lKind = 'array' then
    lValue := TJSONArray.Create
  else if lKind = 'object' then
    lValue := TJSONObject.Create
  else if lKind = 'negative' then
    lValue := TJSONNumber.Create(-1)
  else if lKind = 'overflow' then
    lValue := TJSONNumber.Create('2147483648');
  if Assigned(lValue) then
    lEntry.AddPair(lField, lValue);
  lModel := JsonToModel(lObject.ToJSON);
  lFacts := TDelphiSemanticWithBinder.BindProject('coordinate-reloaded', nil, [lModel]);
  Assert.AreEqual(1, Integer(Length(lFacts.Bindings)));
  Assert.IsTrue(HasReference(lFacts.Bindings[0], 'Count', 'unsupported'),
    'Malformed coordinates must refuse the helper call: ' + aMode);
  Assert.AreEqual('RECORD_HELPER_MEMBERS_UNVERIFIED',
    ReasonOf(lFacts.Bindings[0], 'Count', 'unsupported'));
  Assert.AreEqual(0, Integer(Length(lModel.UnindexedHelpers)),
    'Malformed coordinates must not count as valid facts: ' + aMode);
end;

procedure TWithBinderTests.HelperCoordinatesWriterRoundTrip(const aMode: string);
var
  lOptions: TDelphiSemanticModelOptions;
  lModel, lDecoded: TDelphiSemanticUnitModel;
  lCold, lReloaded: TDelphiSemanticProjectWithBindingFacts;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.ProjectContextApplied := True;
  lOptions.SourceFileName := WithBinderTempPath('writer-coordinate-' + aMode + '.pas');
  TFile.WriteAllText(lOptions.SourceFileName,
    'unit WriterCoordinate;'#13#10'interface'#13#10 +
    'type TRec = record Value: Integer; end;'#13#10'implementation'#13#10 +
    'type'#13#10'  &THelp = record helper for TRec'#13#10 +
    '    procedure Count;'#13#10'  end;'#13#10 +
    'procedure Run;'#13#10'var lRecord: TRec;'#13#10 +
    'begin'#13#10'  with lRecord do Count();'#13#10'end;'#13#10 +
    'procedure &THelp.Count;'#13#10'begin end;'#13#10'end.', TEncoding.ASCII);
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.AreEqual(1, Integer(Length(lModel.UnindexedHelpers)));
  if aMode = 'zero' then
  begin
    lModel.UnindexedHelpers[0].Line := 0;
    lModel.UnindexedHelpers[0].Column := 0;
  end;
  lDecoded := JsonToModel(ModelToJson(lModel));
  Assert.AreEqual(ModelToJson(lModel), ModelToJson(lDecoded));
  lCold := TDelphiSemanticWithBinder.BindProject('writer-coordinate-cold', nil, [lModel]);
  lReloaded := TDelphiSemanticWithBinder.BindProject('writer-coordinate-reload', nil, [lDecoded]);
  Assert.AreEqual(1, Integer(Length(lCold.Bindings)));
  Assert.AreEqual(1, Integer(Length(lReloaded.Bindings)));
  Assert.IsTrue(HasReference(lCold.Bindings[0], 'Count', 'unsupported'));
  Assert.IsTrue(HasReference(lReloaded.Bindings[0], 'Count', 'unsupported'));
  Assert.AreEqual('RECORD_HELPER_MEMBERS_UNVERIFIED',
    ReasonOf(lReloaded.Bindings[0], 'Count', 'unsupported'));
end;

procedure TWithBinderTests.UnindexedHelperWriterValuesRoundTrip(const aMode: string);
var
  lOptions: TDelphiSemanticModelOptions;
  lModel, lDecoded: TDelphiSemanticUnitModel;
  lCold, lReloaded: TDelphiSemanticProjectWithBindingFacts;
  lReference: TDelphiSemanticBoundReference;
  lCount: Integer;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.ProjectContextApplied := True;
  lOptions.SourceFileName := WithBinderTempPath('writer-values-' + aMode + '.pas');
  TFile.WriteAllText(lOptions.SourceFileName,
    'unit WriterValues;'#13#10'interface'#13#10 +
    'type TRec = record Value: Integer; end;'#13#10'implementation'#13#10 +
    'type'#13#10'  &THelp = record helper for TRec'#13#10 +
    '    function Count: Integer;'#13#10'  end;'#13#10 +
    'procedure Run;'#13#10'var lRecord: TRec; Count: Integer;'#13#10 +
    'begin'#13#10'  with lRecord do Count := 1;'#13#10'end;'#13#10 +
    'function &THelp.Count: Integer;'#13#10'begin Result := 1; end;'#13#10'end.',
    TEncoding.ASCII);
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.AreEqual(1, Integer(Length(lModel.UnindexedHelpers)));
  // These are legitimate writer values when AST helper metadata is incomplete.
  if aMode = 'kind' then
    lModel.UnindexedHelpers[0].HelperKind := ''
  else
    lModel.UnindexedHelpers[0].TargetName := '';
  lDecoded := JsonToModel(ModelToJson(lModel));
  Assert.AreEqual(1, Integer(Length(lDecoded.UnindexedHelpers)),
    'Writer-produced empty metadata must survive JSON reload.');
  Assert.AreEqual(ModelToJson(lModel), ModelToJson(lDecoded));
  lCold := TDelphiSemanticWithBinder.BindProject('writer-cold', nil, [lModel]);
  lReloaded := TDelphiSemanticWithBinder.BindProject('writer-reloaded', nil, [lDecoded]);
  Assert.AreEqual(1, Integer(Length(lCold.Bindings)));
  Assert.AreEqual(1, Integer(Length(lReloaded.Bindings)));
  lCount := 0;
  for lReference in lCold.Bindings[0].References do
    if SameText(lReference.Name, 'Count') then
    begin
      Inc(lCount);
      Assert.IsTrue(HasReference(lReloaded.Bindings[0], 'Count', lReference.Classification),
        'Cold and JSON-reloaded models must make the same binding decision.');
      Assert.AreEqual(lReference.ReasonCode,
        ReasonOf(lReloaded.Bindings[0], 'Count', lReference.Classification));
    end;
  Assert.AreEqual(1, lCount);
end;

procedure TWithBinderTests.UnindexedHelperCacheSeparatesSiteModels(const aOrder: string);
var
  lOptions: TDelphiSemanticModelOptions;
  lRecordModel, lHelperModel, lNoHelper, lHasHelper: TDelphiSemanticUnitModel;
  lFacts, lAlone: TDelphiSemanticProjectWithBindingFacts;
  lBinding: TDelphiSemanticWithBinding;
  lSource, lExpected: string;
  i: Integer;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.ProjectContextApplied := True;
  lOptions.SourceFileName := WithBinderTempPath('duplicate-record-' + aOrder + '.pas');
  TFile.WriteAllText(lOptions.SourceFileName,
    'unit TypesA;'#13#10'interface'#13#10 +
    'type TRec = record Value: Integer; end;'#13#10'implementation'#13#10'end.',
    TEncoding.ASCII);
  lRecordModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  lOptions.SourceFileName := WithBinderTempPath('duplicate-helper-' + aOrder + '.pas');
  TFile.WriteAllText(lOptions.SourceFileName,
    'unit Helpers;'#13#10'interface'#13#10'uses TypesA;'#13#10 +
    'type'#13#10'  &THelp = record helper for TypesA.TRec'#13#10 +
    '    function Count: Integer;'#13#10'  end;'#13#10'implementation'#13#10 +
    'function &THelp.Count: Integer;'#13#10'begin Result := 1; end;'#13#10'end.',
    TEncoding.ASCII);
  lHelperModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.AreEqual(1, Integer(Length(lHelperModel.UnindexedHelpers)));
  lSource := 'unit Consumer;'#13#10'interface'#13#10'uses TypesA%s;'#13#10 +
    'implementation'#13#10'procedure Run;'#13#10 +
    'var lRecord: TypesA.TRec; Count: Integer;'#13#10'begin'#13#10 +
    '  with lRecord do Count := 1;'#13#10 +
    '  with lRecord do Count := 2;'#13#10'end;'#13#10'end.';
  lOptions.SourceFileName := WithBinderTempPath('duplicate-no-helper-' + aOrder + '.pas');
  TFile.WriteAllText(lOptions.SourceFileName, Format(lSource, ['']), TEncoding.ASCII);
  lNoHelper := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  lOptions.SourceFileName := WithBinderTempPath('duplicate-has-helper-' + aOrder + '.pas');
  TFile.WriteAllText(lOptions.SourceFileName, Format(lSource, [', Helpers']), TEncoding.ASCII);
  lHasHelper := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  // Alone controls also pin intra-model cache reuse for both visibility states.
  for i := 0 to 1 do
  begin
    if i = 0 then
    begin
      lAlone := TDelphiSemanticWithBinder.BindProject('alone-no-helper', nil,
        [lRecordModel, lHelperModel, lNoHelper]);
      lExpected := 'lexical';
    end else begin
      lAlone := TDelphiSemanticWithBinder.BindProject('alone-has-helper', nil,
        [lRecordModel, lHelperModel, lHasHelper]);
      lExpected := 'unsupported';
    end;
    Assert.AreEqual(2, Integer(Length(lAlone.Bindings)));
    Assert.AreEqual(Int64(1), lAlone.Metrics.ReferenceCacheHitCount);
    Assert.AreEqual(Int64(1), lAlone.Metrics.ReferenceCacheMissCount);
    for lBinding in lAlone.Bindings do
      Assert.IsTrue(HasReference(lBinding, 'Count', lExpected), 'Isolated ' + lExpected);
  end;
  if aOrder = 'forward' then
    lFacts := TDelphiSemanticWithBinder.BindProject('combined', nil,
      [lRecordModel, lHelperModel, lNoHelper, lHasHelper])
  else
    lFacts := TDelphiSemanticWithBinder.BindProject('combined', nil,
      [lRecordModel, lHelperModel, lHasHelper, lNoHelper]);
  Assert.AreEqual(4, Integer(Length(lFacts.Bindings)));
  for lBinding in lFacts.Bindings do
  begin
    if SameText(lBinding.FileName, lHasHelper.FileName) then
      lExpected := 'unsupported'
    else
      lExpected := 'lexical';
    Assert.IsTrue(HasReference(lBinding, 'Count', lExpected),
      'Combined binding must match isolated site: ' + lExpected);
    if lExpected = 'unsupported' then
      Assert.AreEqual('RECORD_HELPER_MEMBERS_UNVERIFIED',
        ReasonOf(lBinding, 'Count', lExpected));
  end;
  Assert.AreEqual(Int64(2), lFacts.Metrics.ReferenceCacheHitCount);
  Assert.AreEqual(Int64(2), lFacts.Metrics.ReferenceCacheMissCount);
end;

procedure TWithBinderTests.UnindexedHelperIncludeOrigins(const aMode: string);
var
  lOptions: TDelphiSemanticModelOptions;
  lModel: TDelphiSemanticUnitModel;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lPlan: TDelphiSemanticRemoveWithPlan;
  lSource, lHelper, lInclude, lIncludePath: string;
  lExpectedLine: Integer;
  i: Integer;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.ProjectContextApplied := True;
  lOptions.SourceFileName := WithBinderTempPath('HelperOrigin-' + aMode + '.pas');
  lIncludePath := ChangeFileExt(lOptions.SourceFileName, '.inc');
  lHelper := 'type'#13#10'  &THelp = record helper for TRec'#13#10 +
    '    function Count: Integer;'#13#10'  end;'#13#10;
  lInclude := '// padding'#13#10'// padding'#13#10'// padding'#13#10;
  if aMode = 'included' then
    lInclude := lHelper;
  TFile.WriteAllText(lIncludePath, lInclude, TEncoding.ASCII);
  lSource := 'unit HelperOrigin;'#13#10'interface'#13#10 +
    'type TRec = record Value: Integer; end;'#13#10'implementation'#13#10 +
    '{$I ' + TPath.GetFileName(lIncludePath) + '}'#13#10;
  if aMode = 'before' then
    lSource := lSource + lHelper;
  lSource := lSource + 'procedure Count;'#13#10'begin end;'#13#10 +
    'procedure Run;'#13#10'var lRecord: TRec;'#13#10'begin'#13#10 +
    '  with lRecord do Count();'#13#10'end;'#13#10;
  if aMode = 'after' then
    lSource := lSource + lHelper;
  lSource := lSource + 'function &THelp.Count: Integer;'#13#10 +
    'begin Result := 1; end;'#13#10'end.';
  TFile.WriteAllText(lOptions.SourceFileName, lSource, TEncoding.ASCII);
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);
  Assert.AreEqual(1, Integer(Length(lModel.UnindexedHelpers)));
  if aMode = 'included' then
  begin
    Assert.IsTrue(SameFileName(lIncludePath, lModel.UnindexedHelpers[0].FileName));
    Assert.AreEqual(0, lModel.UnindexedHelpers[0].Line);
    Assert.AreEqual(0, lModel.UnindexedHelpers[0].Column);
  end else begin
    lExpectedLine := 1;
    for i := 1 to Pos('&THelp =', lSource) - 1 do
      if lSource[i] = #10 then
        Inc(lExpectedLine);
    Assert.AreEqual('', lModel.UnindexedHelpers[0].FileName);
    Assert.AreEqual(lExpectedLine, lModel.UnindexedHelpers[0].Line,
      'Root-origin helper must retain its physical line after include expansion.');
    Assert.AreEqual(3, lModel.UnindexedHelpers[0].Column);
  end;
  lFacts := TDelphiSemanticWithBinder.BindProject('helper-origins', nil, [lModel]);
  Assert.AreEqual(1, Integer(Length(lFacts.Bindings)));
  lPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWith(lFacts);
  Assert.AreEqual(1, Integer(Length(lPlan.FinalStatements)));
  if aMode = 'after' then
  begin
    Assert.IsTrue(HasReference(lFacts.Bindings[0], 'Count', 'external'));
    Assert.AreEqual('UNKNOWN_ROUTINE_CALL', ReasonOf(lFacts.Bindings[0], 'Count', 'external'));
    Assert.AreEqual('planned', lPlan.FinalStatements[0].Status);
    Assert.AreEqual(2, Integer(Length(lPlan.FinalStatements[0].Edits)));
  end else begin
    Assert.IsTrue(HasReference(lFacts.Bindings[0], 'Count', 'unsupported'));
    Assert.AreEqual('skipped', lPlan.FinalStatements[0].Status);
    Assert.AreEqual('symbol-not-found', lPlan.FinalStatements[0].Reason);
    Assert.AreEqual('RECORD_HELPER_MEMBERS_UNVERIFIED', lPlan.FinalStatements[0].SafetyReason);
    Assert.AreEqual(0, Integer(Length(lPlan.FinalStatements[0].Edits)));
  end;
end;

procedure TWithBinderTests.UnindexedHelperColdWarmSnapshot;
var
  lRoot: string;
  lOptions: TDelphiSemanticApiOptions;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lPlan, lSnapshotPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
  lEdit: TDelphiSemanticRemoveWithEdit;
  lPass, lAffected, lControls: Integer;
begin
  lRoot := WithBinderTempPath('helper-session-' + TPath.GetGUIDFileName);
  TDirectory.CreateDirectory(lRoot);
  TFile.WriteAllText(TPath.Combine(lRoot, 'P.dpr'),
    'program P; uses Unit1, ControlUnit; begin end.', TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'P.dproj'),
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' +
    '<PropertyGroup><MainSource>P.dpr</MainSource></PropertyGroup>' +
    '<ItemGroup><DCCReference Include="Unit1.pas"/>' +
    '<DCCReference Include="ControlUnit.pas"/></ItemGroup></Project>', TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'Unit1.pas'),
    'unit Unit1;'#13#10'interface'#13#10'type TRec = record Value: Integer; end;'#13#10 +
    '  &THelp = record helper for TRec'#13#10'    function Count: Integer;'#13#10'  end;'#13#10 +
    'implementation'#13#10'function &THelp.Count: Integer;'#13#10'begin Result := 1; end;'#13#10 +
    'procedure Run;'#13#10'var lRecord: TRec; Count: Integer;'#13#10 +
    'begin'#13#10'  with lRecord do Count := 1;'#13#10'end;'#13#10'end.', TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'ControlUnit.pas'),
    'unit ControlUnit;'#13#10'interface'#13#10'type TRec = record Count: Integer; end;'#13#10 +
    'var Rec: TRec;'#13#10'implementation'#13#10 +
    'procedure Run; begin with Rec do Count := Count + 1; end;'#13#10'end.', TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticApiOptions);
  lOptions.ProjectFileName := TPath.Combine(lRoot, 'P.dproj');
  lOptions.Cache.SqliteCacheFileName := TPath.Combine(lRoot, 'helper-session.sqlite');
  for lPass := 0 to 1 do
  begin
    lPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWith(lOptions);
    lAffected := 0;
    lControls := 0;
    for lStatement in lPlan.FinalStatements do
      if SameText(ExtractFileName(lStatement.FileName), 'Unit1.pas') then
      begin
        Inc(lAffected);
        Assert.AreEqual('skipped', lStatement.Status);
        Assert.AreEqual('receiver-member-not-found', lStatement.Reason);
        Assert.AreEqual('RECORD_HELPER_MEMBERS_UNVERIFIED', lStatement.SafetyReason);
        Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
        Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
        Assert.AreEqual('', lStatement.ReplacementText);
      end else if SameText(ExtractFileName(lStatement.FileName), 'ControlUnit.pas') then
      begin
        Inc(lControls);
        Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
      end;
    Assert.AreEqual(1, lAffected);
    Assert.AreEqual(1, lControls);
    for lEdit in lPlan.Edits do
      Assert.IsFalse(SameText(ExtractFileName(lEdit.FileName), 'Unit1.pas'));
    lFacts := TDelphiSemanticRemoveWithCompatibilityApi.BuildProjectWithBindingFacts(lOptions);
    lSnapshotPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWithCompatibilitySnapshot(lFacts);
    Assert.AreEqual(Integer(Length(lPlan.FinalStatements)), Integer(Length(lSnapshotPlan.FinalStatements)));
    Assert.AreEqual(lPlan.FinalStatements[0].Status, lSnapshotPlan.FinalStatements[0].Status);
    Assert.AreEqual(lPlan.FinalStatements[0].Reason, lSnapshotPlan.FinalStatements[0].Reason);
    Assert.AreEqual(lPlan.FinalStatements[0].SafetyReason, lSnapshotPlan.FinalStatements[0].SafetyReason);
    Assert.AreEqual(lPlan.FinalStatements[0].ReplacementText, lSnapshotPlan.FinalStatements[0].ReplacementText);
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TWithBinderTests);

end.
