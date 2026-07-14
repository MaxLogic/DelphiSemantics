unit DelphiSemantics.WithBinding;

interface

uses
  DelphiSemantics.Model, DelphiSemantics.Resolve, DelphiSemantics.Resolve.ScopeResolver,
  DelphiSemantics.SemanticGraph;

type
  TDelphiSemanticWithSelectorBinding = record
    SelectorText: string;
    Status: string;
    ReasonCode: string;
    TypeName: string;
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
  end;

  TDelphiSemanticWithBinding = record
    SemanticId: string;
    Provenance: string;
    FileName: string;
    UnitName: string;
    RoutineName: string;
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
      TDelphiSemanticProjectWithBindingFacts; static;
    class function BuildInventory(const aModel: TDelphiSemanticUnitModel):
      TDelphiSemanticRemoveWithInventory; static;
    class function ExpandInventorySymbols(const aSymbols: TArray<TDelphiSemanticInventorySymbol>):
      TArray<TDelphiSemanticInventorySymbol>; static;
  end;

implementation

uses
  System.Classes, System.Diagnostics, System.Generics.Collections, System.Hash, System.Math,
  System.RegularExpressions, System.StrUtils, System.SysUtils,
  DelphiSemantics.ProjectContext,
  DelphiSemantics.Resolve.MemberResolver, DelphiSemantics.Resolve.TypeResolver, DelphiSemantics.WithBinding.Inventory,
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

  TWithBindingProjectMemberIndex = class
  private
    fByUnitOwnerName: TDictionary<string, TList<TDelphiSemanticResolveResult>>;
    fDirectMembersByContextOwnerName: TDictionary<string, TList<TDelphiSemanticResolveResult>>;
    fMemberKeysByUnit: TDictionary<string, TList<string>>;
    fSemanticMemberIndex: TDelphiSemanticMemberIdentityIndex;
    fSemanticMemberIndexAvailable: Boolean;
    fSemanticMemberResultsByOwnerName: TDictionary<string, TDelphiSemanticResolveResult>;
    fUnitNames: TArray<string>;
    fVisibleUnitsByUnit: TDictionary<string, TArray<string>>;
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
      TList<TDelphiSemanticResolveResult>>; const aKey: string;
      const aResult: TDelphiSemanticResolveResult); static;
    procedure BuildContextMemberIndex;
    class function ResolveMemberList(const aOwnerName, aName: string;
      const aList: TList<TDelphiSemanticResolveResult>;
      out aResult: TDelphiSemanticResolveResult): Boolean; static;
    class function ResolveResultIsUsable(
      const aResult: TDelphiSemanticResolveResult): Boolean; static;
    procedure ClearOwnedState;
    function TryResolveContextMember(const aContextUnitName, aOwnerName, aName: string;
      out aResult: TDelphiSemanticResolveResult): Boolean;
    function TryResolveUnitMember(const aUnitName, aOwnerName, aName: string;
      out aResult: TDelphiSemanticResolveResult): Boolean;
  public
    constructor Create(const aModels: TArray<TDelphiSemanticUnitModel>;
      const aGraph: TDelphiSemanticSemanticGraph);
    destructor Destroy; override;
    function TryResolveDirectMember(const aCurrentUnitName, aCurrentTypeName, aOwnerName,
      aName: string; const aAllowSemanticFallback: Boolean;
      out aResult: TDelphiSemanticResolveResult): Boolean;
  end;

  TWithSelectorBindingArray = TArray<TDelphiSemanticWithSelectorBinding>;
  TWithSelectorStackArray = TArray<TWithSelectorBindingArray>;

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

constructor TWithBindingProjectMemberIndex.Create(
  const aModels: TArray<TDelphiSemanticUnitModel>;
  const aGraph: TDelphiSemanticSemanticGraph);
var
  lGraph: TDelphiSemanticSemanticGraph;
  lIndex: Integer;
  lMember: TDelphiSemanticMember;
  lModel: TDelphiSemanticUnitModel;
  lOwnGraph: Boolean;
  lTypeIndex: TDelphiSemanticTypeIdentityIndex;
begin
  inherited Create;
  try
    fByUnitOwnerName := TDictionary<string, TList<TDelphiSemanticResolveResult>>.Create(
      TFastCaseAwareComparer.OrdinalIgnoreCase);
    fDirectMembersByContextOwnerName := TDictionary<string,
      TList<TDelphiSemanticResolveResult>>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
    fMemberKeysByUnit := TDictionary<string, TList<string>>.Create(
      TFastCaseAwareComparer.OrdinalIgnoreCase);
    fSemanticMemberResultsByOwnerName := TDictionary<string,
      TDelphiSemanticResolveResult>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
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
      lTypeIndex := TDelphiSemanticTypeResolver.BuildIndex(lGraph);
      fSemanticMemberIndex := TDelphiSemanticMemberResolver.BuildIndex(lGraph, lTypeIndex);
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
    BuildContextMemberIndex;
  except
    ClearOwnedState;
    raise;
  end;
end;

procedure TWithBindingProjectMemberIndex.ClearOwnedState;
var
  lList: TList<TDelphiSemanticResolveResult>;
  lStringList: TList<string>;
begin
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
  lSourceList: TList<TDelphiSemanticResolveResult>;
  lSourceResult: TDelphiSemanticResolveResult;
  lSourceUnitName: string;
  lTargetList: TList<TDelphiSemanticResolveResult>;
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

  lTargetList := TList<TDelphiSemanticResolveResult>.Create;
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
  lKey: string;
begin
  lKey := Key(aUnitName, aMember.OwnerName, aMember.Name);
  AddResultToMap(fByUnitOwnerName, lKey, MemberResult(aMember));
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
  const aMap: TDictionary<string, TList<TDelphiSemanticResolveResult>>;
  const aKey: string;
  const aResult: TDelphiSemanticResolveResult);
var
  lList: TList<TDelphiSemanticResolveResult>;
begin
  if not aMap.TryGetValue(aKey, lList) then
  begin
    lList := TList<TDelphiSemanticResolveResult>.Create;
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
  const aList: TList<TDelphiSemanticResolveResult>;
  out aResult: TDelphiSemanticResolveResult): Boolean;
begin
  if aList.Count > 1 then
  begin
    aResult := Default(TDelphiSemanticResolveResult);
    aResult.Status := 'ambiguous';
    aResult.Name := aName;
    aResult.ReasonCode := 'MULTIPLE_MEMBER_CANDIDATES';
    aResult.Reason := 'Multiple direct members named "' + aName + '" were found on ' +
      aOwnerName + '.';
    Exit(True);
  end;

  aResult := aList[0];
  Result := True;
end;

function TWithBindingProjectMemberIndex.TryResolveContextMember(
  const aContextUnitName, aOwnerName, aName: string;
  out aResult: TDelphiSemanticResolveResult): Boolean;
var
  lList: TList<TDelphiSemanticResolveResult>;
begin
  if not fDirectMembersByContextOwnerName.TryGetValue(Key(aContextUnitName, aOwnerName,
    aName), lList) then
  begin
    aResult := Default(TDelphiSemanticResolveResult);
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
  aName: string; out aResult: TDelphiSemanticResolveResult): Boolean;
var
  lList: TList<TDelphiSemanticResolveResult>;
begin
  if not fByUnitOwnerName.TryGetValue(Key(aUnitName, aOwnerName, aName), lList) then
  begin
    aResult := Default(TDelphiSemanticResolveResult);
    Exit(False);
  end;

  Result := ResolveMemberList(aOwnerName, aName, lList, aResult);
end;

function TWithBindingProjectMemberIndex.TryResolveDirectMember(const aCurrentUnitName,
  aCurrentTypeName, aOwnerName, aName: string; const aAllowSemanticFallback: Boolean;
  out aResult: TDelphiSemanticResolveResult): Boolean;
var
  lContext: TDelphiSemanticMemberLookupContext;
  lLookup: TDelphiSemanticMemberLookupResult;
  lSemanticKey: string;
begin
  if TryResolveContextMember(aCurrentUnitName, aOwnerName, aName, aResult) then
    Exit(True);

  if not aAllowSemanticFallback then
  begin
    aResult := Default(TDelphiSemanticResolveResult);
    Exit(False);
  end;

  lSemanticKey := Key(aCurrentUnitName + #30 + aCurrentTypeName, aOwnerName, aName);
  if fSemanticMemberResultsByOwnerName.TryGetValue(lSemanticKey, aResult) then
    Exit(ResolveResultIsUsable(aResult));

  if fSemanticMemberIndexAvailable then
  begin
    lContext := Default(TDelphiSemanticMemberLookupContext);
    lContext.CallerUnitName := aCurrentUnitName;
    lContext.CurrentTypeName := aCurrentTypeName;
    lContext.InstanceContext := True;
    lLookup := fSemanticMemberIndex.ResolveMember(lContext, aOwnerName, aName);
    if ResolveResultFromMemberLookup(aName, lLookup, aResult) then
    begin
      fSemanticMemberResultsByOwnerName.AddOrSetValue(lSemanticKey, aResult);
      Exit(True);
    end;
  end;

  aResult := Default(TDelphiSemanticResolveResult);
  fSemanticMemberResultsByOwnerName.AddOrSetValue(lSemanticKey, aResult);
  Result := False;
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
  lMatch := TRegEx.Match(aStatement.Text, '\bdo\b(.*)$', [roIgnoreCase, roSingleLine]);
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

function ReceiverMemberCachePrefix(const aUnitName, aCurrentTypeName: string;
  const aSelectors: TArray<TDelphiSemanticWithSelectorBinding>): string; forward;

function TryResolveReceiverMember(const aModel: TDelphiSemanticUnitModel;
  const aProjectModels: TArray<TDelphiSemanticUnitModel>;
  const aSelectors: TArray<TDelphiSemanticWithSelectorBinding>;
  const aCurrentTypeName, aMemberCachePrefix, aName: string;
  const aProjectMemberIndex: TWithBindingProjectMemberIndex;
  const aMemberCache: TDictionary<string, TDelphiSemanticResolveResult>;
  out aResult: TDelphiSemanticResolveResult): Boolean; forward;

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
  TDelphiSemanticResolveResult;
begin
  // Compatibility adapter for model-array name resolution while WithBinding moves to one authority.
  Result := TDelphiSemanticResolver.ResolveName(aModel, aContext, aName);
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

function MakeSelectorBinding(const aModel: TDelphiSemanticUnitModel;
  const aProjectModels: TArray<TDelphiSemanticUnitModel>; const aRoutineName,
  aCurrentTypeName, aSelectorText: string; const aParentRoutineNames: TArray<string>;
  const aPreviousSelectors: TArray<TDelphiSemanticWithSelectorBinding>;
  const aProjectMemberIndex: TWithBindingProjectMemberIndex;
  const aMemberCache: TDictionary<string, TDelphiSemanticResolveResult>):
  TDelphiSemanticWithSelectorBinding;
var
  lContext: TDelphiSemanticResolveContext;
  lResult: TDelphiSemanticResolveResult;
  lSelectorText: string;
begin
  lSelectorText := aSelectorText.Trim;
  lContext := Default(TDelphiSemanticResolveContext);
  lContext.RoutineName := aRoutineName;
  lContext.CurrentTypeName := aCurrentTypeName;
  lContext.ParentRoutineNames := aParentRoutineNames;
  lContext.SectionKind := 'implementation';
  lContext.ConformanceLevel := 3;
  lContext.IndexedUnitModels := aProjectModels;
  if not ((Length(aPreviousSelectors) > 0) and TRegEx.IsMatch(lSelectorText,
    '^[A-Za-z_][A-Za-z0-9_]*$') and
    TryResolveReceiverMember(aModel, aProjectModels, aPreviousSelectors,
    aCurrentTypeName, ReceiverMemberCachePrefix(aModel.UnitName, aCurrentTypeName,
    aPreviousSelectors), lSelectorText, aProjectMemberIndex, aMemberCache, lResult)) then
    lResult := ResolveNameThroughWithBindingAuthority(aModel, lContext, lSelectorText);
  if lResult.Found and SelectorUsesUnsafeProperty(aModel, lContext, lSelectorText) then
    MarkPropertySelectorUnsupported(lSelectorText, lResult);
  Result.SelectorText := lSelectorText;
  Result.Status := lResult.Status;
  Result.ReasonCode := lResult.ReasonCode;
  Result.TypeName := lResult.TypeName;
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
begin
  if (aStartOffset <= 0) or (aLength <= 0) or (aStatement.BodyText = '') then
    Exit;

  lEndOffset := aStartOffset + aLength - 1;
  lStartLine := BodyLineOfOffset(aBodyLineStarts, aStartOffset);
  lStartColumn := BodyColumnOfOffset(aBodyLineStarts, lStartLine, aStartOffset);
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
  lClosePos: Integer;
  lParenPos: Integer;
begin
  lParenPos := Pos('(', aName);
  lClosePos := LastDelimiter(')', aName);
  Result := (lParenPos > 1) and (lClosePos > lParenPos);
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
      if SameText(lRoutine.Name, aName) and (lRoutine.Line > 0) and
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

function ReceiverMemberCachePrefix(const aUnitName, aCurrentTypeName: string;
  const aSelectors: TArray<TDelphiSemanticWithSelectorBinding>): string;
var
  lBuilder: TStringBuilder;
  lSelector: TDelphiSemanticWithSelectorBinding;
begin
  lBuilder := TStringBuilder.Create;
  try
    lBuilder.Append(aUnitName).Append(#31).Append(aCurrentTypeName).Append(#31);
    for lSelector in aSelectors do
      lBuilder.Append(lSelector.Status).Append(#30).Append(lSelector.TypeName).Append(#30).
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
  const aMemberCache: TDictionary<string, TDelphiSemanticResolveResult>;
  out aResult: TDelphiSemanticResolveResult): Boolean;
var
  i: Integer;
  lKey: string;
begin
  lKey := ReceiverMemberCacheKey(aMemberCachePrefix, aName);
  if Assigned(aMemberCache) and aMemberCache.TryGetValue(lKey, aResult) then
    Exit(aResult.Found or SameText(aResult.Status, 'ambiguous') or
      SameText(aResult.Status, 'unsupported'));

  for i := High(aSelectors) downto 0 do
    if SameText(aSelectors[i].Status, 'resolved') then
    begin
      if Assigned(aProjectMemberIndex) and aProjectMemberIndex.TryResolveDirectMember(
        aModel.UnitName, aCurrentTypeName, aSelectors[i].TypeName, aName,
        SelectorAllowsReceiverMemberLookup(aSelectors[i]), aResult) then
      begin
        if Assigned(aMemberCache) then
          aMemberCache.AddOrSetValue(lKey, aResult);
        Exit(True);
      end;
    end;

  aResult := Default(TDelphiSemanticResolveResult);
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
      lBuilder.Append(lSelector.Status).Append(#30).Append(lSelector.TypeName).Append(#29);
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
  const aResolveCachePrefix: string):
  TDelphiSemanticResolveResult;
var
  lKey: string;
begin
  lKey := ResolveNameCacheKey(aResolveCachePrefix, aName);
  if Assigned(aResolveCache) and aResolveCache.TryGetValue(lKey, Result) then
    Exit;

  Result := ResolveNameThroughWithBindingAuthority(aModel, aContext, aName);
  if Assigned(aResolveCache) then
    aResolveCache.AddOrSetValue(lKey, Result);
end;

procedure ApplyScopeConflictFact(const aModel: TDelphiSemanticUnitModel;
  const aContext: TDelphiSemanticResolveContext;
  const aResolveCache: TDictionary<string, TDelphiSemanticResolveResult>;
  const aResolveCachePrefix: string; var aReference: TDelphiSemanticBoundReference;
  var aLexicalResolveMs: Int64);
var
  lResult: TDelphiSemanticResolveResult;
  lStopwatch: TStopwatch;
begin
  if (not SameText(aReference.Classification, 'member')) or (aReference.Name = '') then
    Exit;

  lStopwatch := TStopwatch.StartNew;
  lResult := ResolveNameCached(aModel, aContext, aReference.Name, aResolveCache,
    aResolveCachePrefix);
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
  const aMemberCache: TDictionary<string, TDelphiSemanticResolveResult>;
  var aReceiverMemberResolveMs, aLexicalResolveMs, aReferenceCacheHits,
  aReferenceCacheMisses: Int64):
  TDelphiSemanticBoundReference;
var
  lCallName: string;
  lContext: TDelphiSemanticResolveContext;
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
      aResolveCachePrefix);
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
    Exit(CacheBoundReference(aReferenceCache, lKey, MakeBoundReference(lCallName, 'external',
      MakeSyntheticResolveResult(lCallName, 'routine', '', '', 'UNKNOWN_ROUTINE_CALL'))));
  end;

  if (Pos('.', aName) > 0) or (Pos('[', aName) > 0) then
  begin
    lStopwatch := TStopwatch.StartNew;
    lResult := ResolveNameCached(aModel, Default(TDelphiSemanticResolveContext),
      aName, aResolveCache, ResolveNameCachePrefix(aModel.UnitName,
      Default(TDelphiSemanticResolveContext)));
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
    aResolveCachePrefix);
  lStopwatch.Stop;
  Inc(aLexicalResolveMs, lStopwatch.ElapsedMilliseconds);
  if lResult.Found then
    Exit(CacheBoundReference(aReferenceCache, lKey, MakeBoundReference(aName, 'lexical', lResult)));

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

function SplitSelectors(const aSelectorText: string): TArray<string>;
var
  lPart: string;
  lParts: TList<string>;
begin
  lParts := TList<string>.Create;
  try
    for lPart in aSelectorText.Split([',']) do
      if lPart.Trim <> '' then
        lParts.Add(lPart.Trim);
    Result := lParts.ToArray;
  finally
    lParts.Free;
  end;
end;

function BindSelectors(const aModel: TDelphiSemanticUnitModel;
  const aProjectModels: TArray<TDelphiSemanticUnitModel>; const aRoutineName,
  aCurrentTypeName, aSelectorText: string; const aParentRoutineNames: TArray<string>;
  const aProjectMemberIndex: TWithBindingProjectMemberIndex;
  const aMemberCache: TDictionary<string, TDelphiSemanticResolveResult>):
  TArray<TDelphiSemanticWithSelectorBinding>;
var
  lPart: string;
  lSelectors: TList<TDelphiSemanticWithSelectorBinding>;
begin
  lSelectors := TList<TDelphiSemanticWithSelectorBinding>.Create;
  try
    for lPart in SplitSelectors(aSelectorText) do
      lSelectors.Add(MakeSelectorBinding(aModel, aProjectModels, aRoutineName,
        aCurrentTypeName, lPart, aParentRoutineNames, lSelectors.ToArray, aProjectMemberIndex,
        aMemberCache));
    Result := lSelectors.ToArray;
  finally
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
  lOpenIndex: Integer;
begin
  Result := False;
  if (aIndex > Length(aText)) or (aText[aIndex] <> aOpenChar) then
    Exit;

  lOpenIndex := aIndex;
  lCloseIndex := lOpenIndex + 1;
  while (lCloseIndex <= Length(aText)) and (aText[lCloseIndex] <> aCloseChar) do
    Inc(lCloseIndex);
  if lCloseIndex > Length(aText) then
    Exit;
  if aRequireContent and (lCloseIndex = lOpenIndex + 1) then
    Exit;

  aIndex := lCloseIndex + 1;
  Result := True;
end;

function ReadReferenceToken(const aText: string; var aIndex: Integer;
  const aAllowCallSuffix: Boolean; out aToken: string; out aTokenStart: Integer):
  Boolean;
var
  lTokenStart: Integer;
begin
  aToken := '';
  aTokenStart := 0;
  while (aIndex <= Length(aText)) and (not ReferenceIdentifierStart(aText[aIndex])) do
  begin
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
  const aMemberCache: TDictionary<string, TDelphiSemanticResolveResult>;
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
    if not IsBinderKeyword(lArgumentToken) and
      not IsSelectorName(aSelectors, lArgumentToken) then
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
        lReference, aLexicalResolveMs);
      AddReference(aReferences, lReference);
    end;
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
  const aMemberCache: TDictionary<string, TDelphiSemanticResolveResult>;
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
      aSelectors);
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
      if not IsBinderKeyword(lToken) and not IsSelectorName(aSelectors, lToken) then
      begin
        lReference := BindReference(aModel, aProjectModels, aRoutineName, aCurrentTypeName,
          aParentRoutineNames, aSelectors, lReferenceCachePrefix, lResolveCachePrefix,
          lMemberCachePrefix, lToken, aProjectMemberIndex, aReferenceCache, aResolveCache,
          aMemberCache, aReceiverMemberResolveMs, aLexicalResolveMs, aReferenceCacheHits,
          aReferenceCacheMisses);
        ApplyBodyRange(lReference, aStatement, lTokenStart, Length(lToken), lBodyLineStarts);
        ApplyScopeConflictFact(aModel, lResolveContext, aResolveCache, lResolveCachePrefix,
          lReference, aLexicalResolveMs);
        AddReference(lReferences, lReference);
        AddArgumentReferences(lReferences, aModel, aProjectModels, aRoutineName,
          aCurrentTypeName,
          aParentRoutineNames, aSelectors, lReferenceCachePrefix, lResolveCachePrefix,
          lMemberCachePrefix, aStatement, lToken, lTokenStart, lBodyLineStarts,
          aProjectMemberIndex, aReferenceCache, aResolveCache, aMemberCache,
          aReceiverMemberResolveMs, aLexicalResolveMs, aReferenceCacheHits,
          aReferenceCacheMisses);
      end;
    end;
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

function BuildSelectorStackCache(const aModel: TDelphiSemanticUnitModel;
  const aProjectModels: TArray<TDelphiSemanticUnitModel>;
  const aStatements: TArray<TDelphiSemanticWithStatement>;
  const aScopeIndex: TDelphiSemanticRoutineScopeIndex;
  const aProjectMemberIndex: TWithBindingProjectMemberIndex;
  const aMemberCache: TDictionary<string, TDelphiSemanticResolveResult>):
  TWithSelectorStackArray;
var
  i: Integer;
  lCurrentTypeName: string;
  lDirectSelectors: TWithSelectorBindingArray;
  lParentIndexes: TArray<Integer>;
  lParentIndex: Integer;
  lParentRoutineNames: TArray<string>;
  lRoutineLookupName: string;
  lRoutineName: string;
begin
  lParentIndexes := BuildParentStatementIndexes(aStatements);
  SetLength(Result, Length(aStatements));
  for i := 0 to High(aStatements) do
  begin
    lRoutineName := aScopeIndex.RoutineNameForLine(aStatements[i].Line);
    lParentRoutineNames := aScopeIndex.ParentRoutineNamesForLine(lRoutineName,
      aStatements[i].Line);
    lCurrentTypeName := CallerTypeNameForRoutineContext(aModel, lRoutineName,
      lParentRoutineNames, aStatements[i].Line);
    lRoutineLookupName := RoutineLookupNameForRoutineContext(aModel, lRoutineName,
      aStatements[i].Line);
    lDirectSelectors := BindSelectors(aModel, aProjectModels, lRoutineLookupName,
      lCurrentTypeName, aStatements[i].SelectorText, lParentRoutineNames,
      aProjectMemberIndex, aMemberCache);
    lParentIndex := lParentIndexes[i];
    if lParentIndex >= 0 then
      Result[i] := MergeSelectorStacks(Result[lParentIndex], lDirectSelectors)
    else
      Result[i] := lDirectSelectors;
  end;
end;

class function TDelphiSemanticWithBinder.BindModel(const aModel: TDelphiSemanticUnitModel):
  TArray<TDelphiSemanticWithBinding>;
begin
  Result := BindProject('', nil, [aModel]).Bindings;
end;

class function TDelphiSemanticWithBinder.BindProject(const aContextFingerprint: string;
  const aGraph: TDelphiSemanticSemanticGraph;
  const aModels: TArray<TDelphiSemanticUnitModel>): TDelphiSemanticProjectWithBindingFacts;
var
  i: Integer;
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
  lMemberCache: TDictionary<string, TDelphiSemanticResolveResult>;
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
  lSelectorStacks: TWithSelectorStackArray;
  lScopeIndex: TDelphiSemanticRoutineScopeIndex;
  lStatement: TDelphiSemanticWithStatement;
  lStopwatch: TStopwatch;
  lSubphaseStopwatch: TStopwatch;
  lSymbol: TDelphiSemanticInventorySymbol;
  lSymbolCapacity: Integer;
  lSymbols: TList<TDelphiSemanticInventorySymbol>;
  lWithStatementLines: TArray<Integer>;
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
  lMemberCache := TDictionary<string, TDelphiSemanticResolveResult>.Create(
    TFastCaseAwareComparer.OrdinalIgnoreCase);
  lProjectMemberIndex := TWithBindingProjectMemberIndex.Create(aModels, aGraph);
  try
    for lModel in aModels do
    begin
      lStopwatch := TStopwatch.StartNew;
      for lSymbol in TDelphiSemanticWithBindingInventory.BuildInventorySymbols(lModel) do
        lSymbols.Add(lSymbol);
      lStopwatch.Stop;
      Inc(lInventoryBuildMs, lStopwatch.ElapsedMilliseconds);
      if Length(lModel.WithStatements) = 0 then
        Continue;
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
        lScopeIndex, lProjectMemberIndex, lMemberCache);
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
        FinalizeBinding(lBinding, lStatement);
        lBindings.Add(lBinding);
      end;
      lBindingStopwatch.Stop;
      Inc(lBindingBuildMs, lBindingStopwatch.ElapsedMilliseconds);
    end;
    TDelphiSemanticWithBindingInventory.AddCompilerProfileCompatibilitySymbols(lSymbols);
    TDelphiSemanticWithBindingInventory.AddProjectExternalUnitSymbols(aModels, lSymbols);
    lStopwatch := TStopwatch.StartNew;
    Result.Symbols := TDelphiSemanticWithBinder.ExpandInventorySymbols(lSymbols.ToArray);
    lStopwatch.Stop;
    lInventoryExpansionMs := lStopwatch.ElapsedMilliseconds;
    Result.UnitModels := Copy(aModels);
    lStopwatch := TStopwatch.StartNew;
    Result.LookupIndex := TDelphiSemanticRemoveWithLookupIndex.Build(Result.UnitModels,
      Result.Symbols);
    lStopwatch.Stop;
    lLookupIndexBuildMs := lStopwatch.ElapsedMilliseconds;
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
