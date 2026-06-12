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
  System.Classes, System.Diagnostics, System.Generics.Collections, System.Hash, System.IOUtils, System.Math,
  System.RegularExpressions, System.StrUtils, System.SysUtils,
  DelphiSemantics.CompilerProfile, DelphiSemantics.ProjectContext,
  DelphiSemantics.Resolve.MemberResolver, DelphiSemantics.Resolve.TypeResolver,
  MaxLogic.StrUtils;

type
  TRelatedInventoryMemberRelation = record
    SourceOwnerType: string;
    TargetOwnerType: string;
    IsHelper: Boolean;
  end;

  TDelphiSemanticRemoveWithLookupIndexData = class(TInterfacedObject,
    IDelphiSemanticRemoveWithLookupIndexData)
  private
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

function SelectorPrefixUsesProperty(const aModel: TDelphiSemanticUnitModel;
  const aContext: TDelphiSemanticResolveContext; const aSelectorPrefix: string;
  const aCheckDefaultProperty: Boolean): Boolean;
var
  lResult: TDelphiSemanticResolveResult;
begin
  lResult := TDelphiSemanticResolver.ResolveName(aModel, aContext, aSelectorPrefix);
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
    lResult := TDelphiSemanticResolver.ResolveName(aModel, lContext, lSelectorText);
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

procedure AddInventorySymbol(const aSymbols: TList<TDelphiSemanticInventorySymbol>;
  const aSymbol: TDelphiSemanticInventorySymbol);
begin
  if aSymbol.Name <> '' then
    aSymbols.Add(aSymbol);
end;

function InventoryCleanLine(const aLine: string): string;
var
  lCommentPos: Integer;
  lEndPos: Integer;
  lStartPos: Integer;
begin
  Result := Trim(aLine);
  if Result = '' then
    Exit;
  if StartsText('{$', Result) or StartsText('(*$', Result) then
    Exit;

  repeat
    lStartPos := Pos('{', Result);
    if lStartPos = 0 then
      Break;
    if Copy(Result, lStartPos, 2) = '{$' then
      Break;
    lEndPos := PosEx('}', Result, lStartPos + 1);
    if lEndPos = 0 then
    begin
      Delete(Result, lStartPos, MaxInt);
      Break;
    end;
    Delete(Result, lStartPos, lEndPos - lStartPos + 1);
    Result := Trim(Result);
  until False;

  repeat
    lStartPos := Pos('(*', Result);
    if lStartPos = 0 then
      Break;
    if Copy(Result, lStartPos, 3) = '(*$' then
      Break;
    lEndPos := PosEx('*)', Result, lStartPos + 2);
    if lEndPos = 0 then
    begin
      Delete(Result, lStartPos, MaxInt);
      Break;
    end;
    Delete(Result, lStartPos, lEndPos - lStartPos + 2);
    Result := Trim(Result);
  until False;

  lCommentPos := Pos('//', Result);
  if lCommentPos > 0 then
    Result := Trim(Copy(Result, 1, lCommentPos - 1));
end;

function InventoryIsIdentifierChar(const aValue: Char): Boolean;
begin
  Result := CharInSet(aValue, ['A'..'Z', 'a'..'z', '0'..'9', '_']);
end;

function InventoryRemoveInlineConditionalBlocks(const aText: string): string;
var
  lEndPos: Integer;
  lStartPos: Integer;
  lUpper: string;
begin
  Result := aText;
  repeat
    lUpper := UpperCase(Result);
    lStartPos := Pos('{$IF', lUpper);
    if lStartPos = 0 then
      Break;
    lEndPos := PosEx('{$ENDIF}', lUpper, lStartPos + 1);
    if lEndPos = 0 then
      Break;
    Delete(Result, lStartPos, lEndPos - lStartPos + Length('{$ENDIF}'));
  until False;

  repeat
    lStartPos := Pos('{$', Result);
    if lStartPos = 0 then
      Break;
    lEndPos := PosEx('}', Result, lStartPos + 1);
    if lEndPos = 0 then
      Break;
    Delete(Result, lStartPos, lEndPos - lStartPos + 1);
  until False;
  Result := Trim(Result);
end;

function InventoryIsTopLevelLine(const aLine: string): Boolean;
begin
  Result := (Trim(aLine) <> '') and (TrimLeft(aLine) = aLine);
end;

function InventoryIsVisibilityLine(const aLine: string): Boolean;
begin
  Result := MatchText(LowerCase(Trim(aLine)), ['private', 'protected', 'public', 'published',
    'strict private', 'strict protected']);
end;

function InventoryIsDirectMemberKind(const aKind: string): Boolean;
begin
  Result := MatchText(aKind, ['field', 'property', 'method', 'constant', 'class-var']);
end;

function InventoryIsRoutineStart(const aLine: string): Boolean;
var
  lText: string;
begin
  lText := LowerCase(Trim(aLine));
  Result := StartsText('procedure ', lText) or StartsText('function ', lText) or
    StartsText('class procedure ', lText) or StartsText('class function ', lText) or
    StartsText('constructor ', lText) or StartsText('destructor ', lText);
end;

function InventoryIsAttributeLine(const aLine: string): Boolean;
begin
  Result := StartsText('[', Trim(aLine));
end;

function InventoryIsConditionalDirectiveLine(const aLine: string): Boolean;
var
  lText: string;
begin
  lText := UpperCase(Trim(aLine));
  Result := StartsText('{$IF', lText) or StartsText('{$ELSE', lText) or
    StartsText('{$ELSEIF', lText) or StartsText('{$ENDIF', lText) or
    StartsText('{$IFEND', lText);
end;

function InventoryIsConditionalStartDirective(const aLine: string): Boolean;
var
  lText: string;
begin
  lText := UpperCase(Trim(aLine));
  Result := StartsText('{$IF', lText) and (not StartsText('{$IFEND', lText));
end;

function InventoryIsConditionalEndDirective(const aLine: string): Boolean;
var
  lText: string;
begin
  lText := UpperCase(Trim(aLine));
  Result := StartsText('{$ENDIF', lText) or StartsText('{$IFEND', lText);
end;

function InventoryIsMultilineDeclarationStart(const aLine: string): Boolean;
var
  lText: string;
begin
  lText := Trim(aLine);
  Result := (Pos(',', lText) > 0) and (Pos(':', lText) = 0) and (Pos(';', lText) = 0) and
    (not InventoryIsRoutineStart(lText));
end;

function InventoryFindColumn(const aLine, aName: string): Integer;
begin
  Result := Pos(aName, aLine);
  if Result = 0 then
    Result := 1;
end;

function InventorySimpleTypeName(const aTypeName: string): string;
var
  lDelimiterPos: Integer;
  lTypeName: string;
begin
  lTypeName := Trim(aTypeName);
  if StartsText('^', lTypeName) then
    Delete(lTypeName, 1, 1);
  lDelimiterPos := Pos('<', lTypeName);
  if lDelimiterPos = 0 then
    lDelimiterPos := Pos('[', lTypeName);
  if lDelimiterPos = 0 then
    lDelimiterPos := Pos(' ', lTypeName);
  if lDelimiterPos > 0 then
    lTypeName := Trim(Copy(lTypeName, 1, lDelimiterPos - 1));
  lDelimiterPos := LastDelimiter('.', lTypeName);
  if lDelimiterPos > 0 then
    lTypeName := Copy(lTypeName, lDelimiterPos + 1, MaxInt);
  Result := lTypeName;
end;

function InventoryIsBuiltInTypeName(const aTypeName: string): Boolean;
begin
  Result := MatchText(aTypeName, ['AnsiString', 'Array', 'Boolean', 'Byte',
    'Cardinal', 'Char', 'Currency', 'Date', 'DateTime', 'Double', 'Extended',
    'Integer', 'Int64', 'NativeInt', 'NativeUInt', 'Pointer', 'Real',
    'ShortInt', 'Single', 'SmallInt', 'String', 'UInt64', 'Variant',
    'WideChar', 'WideString', 'Word']);
end;

function InventoryTryDeclaration(const aLine: string; out aNames: TArray<string>;
  out aTypeName: string): Boolean;
var
  lColonPos: Integer;
  lEqualsPos: Integer;
  lLeft: string;
  lLine: string;
  lNames: TList<string>;
  lPart: string;
  lParts: TArray<string>;
  lRawPart: string;
  lRight: string;
  lSemiPos: Integer;
begin
  Result := False;
  SetLength(aNames, 0);
  aTypeName := '';
  lLine := InventoryRemoveInlineConditionalBlocks(aLine);
  lColonPos := Pos(':', lLine);
  if lColonPos = 0 then
    Exit;

  lLeft := Trim(Copy(lLine, 1, lColonPos - 1));
  if (lLeft = '') or InventoryIsRoutineStart(lLeft) or StartsText('property ', LowerCase(lLeft)) then
    Exit;

  lRight := Trim(Copy(lLine, lColonPos + 1, MaxInt));
  lEqualsPos := Pos('=', lRight);
  if lEqualsPos > 0 then
    lRight := Trim(Copy(lRight, 1, lEqualsPos - 1));
  lSemiPos := Pos(';', lRight);
  if lSemiPos > 0 then
    lRight := Trim(Copy(lRight, 1, lSemiPos - 1));
  if lRight = '' then
    Exit;

  lNames := TList<string>.Create;
  try
    lParts := lLeft.Split([',']);
    for lRawPart in lParts do
    begin
      lPart := Trim(lRawPart);
      if lPart <> '' then
        lNames.Add(lPart);
    end;
    aNames := lNames.ToArray;
  finally
    lNames.Free;
  end;
  aTypeName := lRight;
  Result := Length(aNames) > 0;
end;

function InventoryTryConstDeclaration(const aLine: string; out aName: string;
  out aTypeName: string): Boolean;
var
  lColonPos: Integer;
  lEqualsPos: Integer;
begin
  Result := False;
  aName := '';
  aTypeName := '';
  lEqualsPos := Pos('=', aLine);
  if lEqualsPos = 0 then
    Exit;

  lColonPos := Pos(':', aLine);
  if (lColonPos > 0) and (lColonPos < lEqualsPos) then
  begin
    aName := Trim(Copy(aLine, 1, lColonPos - 1));
    aTypeName := Trim(Copy(aLine, lColonPos + 1, lEqualsPos - lColonPos - 1));
  end else
  begin
    aName := Trim(Copy(aLine, 1, lEqualsPos - 1));
    aTypeName := '';
  end;
  Result := aName <> '';
end;

function InventoryTryEnumValues(const aTypeText: string; out aNames: TArray<string>): Boolean;
var
  i: Integer;
  lClosePos: Integer;
  lEqualsPos: Integer;
  lList: TList<string>;
  lName: string;
  lOpenPos: Integer;
  lPart: string;
  lParts: TArray<string>;
  lPrefix: string;
  lRawPart: string;
  lText: string;
begin
  Result := False;
  SetLength(aNames, 0);
  lText := Trim(aTypeText);
  lEqualsPos := Pos('=', lText);
  lOpenPos := Pos('(', lText);
  lClosePos := PosEx(')', lText, lOpenPos + 1);
  if (lEqualsPos = 0) or (lOpenPos <= lEqualsPos) or (lClosePos <= lOpenPos) then
    Exit;

  lPrefix := Copy(lText, 1, lOpenPos - 1);
  if ContainsText(lPrefix, 'procedure') or ContainsText(lPrefix, 'function') then
    Exit;

  lList := TList<string>.Create;
  try
    lParts := Copy(lText, lOpenPos + 1, lClosePos - lOpenPos - 1).Split([',']);
    for lRawPart in lParts do
    begin
      lPart := Trim(lRawPart);
      lName := '';
      i := 1;
      while (i <= Length(lPart)) and InventoryIsIdentifierChar(lPart[i]) do
      begin
        lName := lName + lPart[i];
        Inc(i);
      end;
      if lName <> '' then
        lList.Add(lName);
    end;
    aNames := lList.ToArray;
    Result := Length(aNames) > 0;
  finally
    lList.Free;
  end;
end;

function InventoryTryPropertyDeclaration(const aLine: string; out aName, aTypeName: string;
  out aIsDefault, aIsIndexed: Boolean; out aIndexParameterCount: Integer): Boolean;
var
  i: Integer;
  lBracketDepth: Integer;
  lIndexText: string;
  lMemberText: string;
  lNameEnd: Integer;
  lPropertyTypeEnd: Integer;
  lTypePos: Integer;
begin
  Result := False;
  aName := '';
  aTypeName := '';
  aIsDefault := False;
  aIsIndexed := False;
  aIndexParameterCount := 0;
  if not StartsText('property ', LowerCase(aLine)) then
    Exit;

  lMemberText := Trim(Copy(aLine, Length('property ') + 1, MaxInt));
  aIsDefault := ContainsText(LowerCase(lMemberText), ' default');
  lBracketDepth := 0;
  lTypePos := 0;
  for i := 1 to Length(lMemberText) do
  begin
    if lMemberText[i] = '[' then
      Inc(lBracketDepth)
    else if (lMemberText[i] = ']') and (lBracketDepth > 0) then
      Dec(lBracketDepth)
    else if (lMemberText[i] = ':') and (lBracketDepth = 0) then
    begin
      lTypePos := i;
      Break;
    end;
  end;

  if lTypePos > 0 then
  begin
    aTypeName := Trim(Copy(lMemberText, lTypePos + 1, MaxInt));
    lPropertyTypeEnd := Pos(' read ', LowerCase(aTypeName));
    if lPropertyTypeEnd = 0 then
      lPropertyTypeEnd := Pos(' write ', LowerCase(aTypeName));
    if lPropertyTypeEnd = 0 then
      lPropertyTypeEnd := Pos(' index ', LowerCase(aTypeName));
    if lPropertyTypeEnd = 0 then
      lPropertyTypeEnd := Pos(' default', LowerCase(aTypeName));
    if lPropertyTypeEnd = 0 then
      lPropertyTypeEnd := Pos(';', aTypeName);
    if lPropertyTypeEnd > 0 then
      aTypeName := Trim(Copy(aTypeName, 1, lPropertyTypeEnd - 1));
    lMemberText := Trim(Copy(lMemberText, 1, lTypePos - 1));
  end;

  lNameEnd := Pos('[', lMemberText);
  if lNameEnd > 0 then
  begin
    aIsIndexed := True;
    lIndexText := Copy(lMemberText, lNameEnd + 1, LastDelimiter(']', lMemberText) - lNameEnd - 1);
    if Trim(lIndexText) <> '' then
      aIndexParameterCount := Length(lIndexText.Split([';']));
  end else
    lNameEnd := Pos(';', lMemberText);

  if lNameEnd > 0 then
    aName := Trim(Copy(lMemberText, 1, lNameEnd - 1))
  else
    aName := Trim(lMemberText);
  Result := aName <> '';
end;

function InventoryTryTypeAlias(const aLine: string; out aName: string;
  out aTypeName: string): Boolean;
var
  lEqualsPos: Integer;
  lRight: string;
  lSemiPos: Integer;
begin
  Result := False;
  aName := '';
  aTypeName := '';
  lEqualsPos := Pos('=', aLine);
  if lEqualsPos = 0 then
    Exit;

  aName := Trim(Copy(aLine, 1, lEqualsPos - 1));
  lRight := Trim(Copy(aLine, lEqualsPos + 1, MaxInt));
  lSemiPos := Pos(';', lRight);
  if lSemiPos > 0 then
    lRight := Trim(Copy(lRight, 1, lSemiPos - 1));

  aTypeName := lRight;
  Result := (aName <> '') and (aTypeName <> '');
end;

function InventoryTryTypeStart(const aLine: string; out aName, aCategory: string): Boolean;
var
  lEqualsPos: Integer;
  lLower: string;
begin
  Result := False;
  aName := '';
  aCategory := 'unknown';
  lEqualsPos := Pos('=', aLine);
  if lEqualsPos = 0 then
    Exit;

  lLower := LowerCase(aLine);
  if (Pos(' record', lLower) = 0) and (Pos(' class', lLower) = 0) and
    (Pos(' interface', lLower) = 0) then
    Exit;

  if Pos(' record', lLower) > 0 then
    aCategory := 'record'
  else if Pos(' interface', lLower) > 0 then
    aCategory := 'interface'
  else if Pos(' class', lLower) > 0 then
    aCategory := 'class';

  aName := Trim(Copy(aLine, 1, lEqualsPos - 1));
  Result := aName <> '';
end;

function InventoryTryVariantTagDeclaration(const aLine: string; out aName,
  aTypeName: string): Boolean;
var
  lColonPos: Integer;
  lOfPos: Integer;
  lRest: string;
  lRestLower: string;
  lText: string;
begin
  Result := False;
  aName := '';
  aTypeName := '';
  lText := Trim(aLine);
  if not StartsText('case ', LowerCase(lText)) then
    Exit;

  lRest := Trim(Copy(lText, Length('case ') + 1, MaxInt));
  lRestLower := LowerCase(lRest);
  lColonPos := Pos(':', lRest);
  lOfPos := Pos(' of', lRestLower);
  if (lColonPos = 0) or (lOfPos = 0) or (lOfPos < lColonPos) then
    Exit;

  aName := Trim(Copy(lRest, 1, lColonPos - 1));
  aTypeName := Trim(Copy(lRest, lColonPos + 1, lOfPos - lColonPos - 1));
  Result := (aName <> '') and (aTypeName <> '');
end;

function InventoryVariantFieldDeclarationLine(const aLine: string): string;
var
  lInnerText: string;
  lOpenPos: Integer;
  lText: string;
begin
  Result := aLine;
  lText := Trim(aLine);
  lOpenPos := Pos('(', lText);
  if (lOpenPos > 1) and (Pos(':', Copy(lText, 1, lOpenPos - 1)) > 0) then
  begin
    lInnerText := Copy(lText, lOpenPos + 1, MaxInt);
    if Pos(':', lInnerText) > 0 then
      lText := Trim(Copy(lText, lOpenPos, MaxInt));
  end;
  if StartsText('(', lText) then
  begin
    lText := Trim(Copy(lText, 2, MaxInt));
    if EndsText(');', lText) then
      Result := Trim(Copy(lText, 1, Length(lText) - 2)) + ';'
    else if EndsText(')', lText) then
      Result := Trim(Copy(lText, 1, Length(lText) - 1)) + ';'
    else
      Result := lText;
  end else if EndsText(');', lText) then
    Result := Trim(Copy(lText, 1, Length(lText) - 2)) + ';';
end;

function InventoryTryTypeRelation(const aLine: string; out aRelatedTypeName: string;
  out aIsHelper: Boolean): Boolean;
var
  lClosePos: Integer;
  lLower: string;
  lRelationPos: Integer;
  lStartPos: Integer;
  lText: string;
begin
  aRelatedTypeName := '';
  aIsHelper := False;
  lText := Trim(aLine);
  lLower := LowerCase(lText);

  lRelationPos := Pos(' helper for ', lLower);
  if lRelationPos > 0 then
  begin
    aIsHelper := True;
    aRelatedTypeName := Trim(Copy(lText, lRelationPos + Length(' helper for '), MaxInt));
    lClosePos := Pos(';', aRelatedTypeName);
    if lClosePos > 0 then
      aRelatedTypeName := Trim(Copy(aRelatedTypeName, 1, lClosePos - 1));
    Exit(aRelatedTypeName <> '');
  end;
  if Pos(' helper(', lLower) > 0 then
  begin
    aIsHelper := True;
    Exit(False);
  end;

  lStartPos := Pos('class(', lLower);
  if lStartPos > 0 then
  begin
    Inc(lStartPos, Length('class('));
    lClosePos := PosEx(')', lText, lStartPos);
    if lClosePos > lStartPos then
      aRelatedTypeName := Trim(Copy(lText, lStartPos, lClosePos - lStartPos));
    lClosePos := Pos(',', aRelatedTypeName);
    if lClosePos > 0 then
      aRelatedTypeName := Trim(Copy(aRelatedTypeName, 1, lClosePos - 1));
  end;
  if aRelatedTypeName = '' then
  begin
    lStartPos := Pos('interface(', lLower);
    if lStartPos > 0 then
    begin
      Inc(lStartPos, Length('interface('));
      lClosePos := PosEx(')', lText, lStartPos);
      if lClosePos > lStartPos then
        aRelatedTypeName := Trim(Copy(lText, lStartPos, lClosePos - lStartPos));
    end;
  end;
  Result := aRelatedTypeName <> '';
end;

function InventoryTryRoutineName(const aLine: string; out aName: string): Boolean;
var
  lNameEnd: Integer;
  lNameStart: Integer;
  lText: string;
begin
  Result := False;
  aName := '';
  lText := Trim(aLine);
  if StartsText('class procedure ', lText) then
    lNameStart := Length('class procedure ') + 1
  else if StartsText('class function ', lText) then
    lNameStart := Length('class function ') + 1
  else if StartsText('procedure ', lText) then
    lNameStart := Length('procedure ') + 1
  else if StartsText('function ', lText) then
    lNameStart := Length('function ') + 1
  else if StartsText('constructor ', lText) then
    lNameStart := Length('constructor ') + 1
  else if StartsText('destructor ', lText) then
    lNameStart := Length('destructor ') + 1
  else
    Exit;

  lNameEnd := lNameStart;
  while lNameEnd <= Length(lText) do
  begin
    if InventoryIsIdentifierChar(lText[lNameEnd]) or (lText[lNameEnd] = '.') then
      Inc(lNameEnd)
    else
      Break;
  end;
  aName := Copy(lText, lNameStart, lNameEnd - lNameStart);
  Result := aName <> '';
end;

function InventoryTryRoutineOwner(const aRoutineName: string; out aOwnerType: string): Boolean;
var
  lDotPos: Integer;
begin
  lDotPos := LastDelimiter('.', aRoutineName);
  Result := lDotPos > 0;
  if Result then
    aOwnerType := Copy(aRoutineName, 1, lDotPos - 1)
  else
    aOwnerType := '';
end;

function InventoryTokenCount(const aText, aToken: string): Integer;
var
  i: Integer;
  lEndPos: Integer;
  lStartPos: Integer;
begin
  Result := 0;
  i := 1;
  while i <= Length(aText) do
  begin
    if not InventoryIsIdentifierChar(aText[i]) then
    begin
      Inc(i);
      Continue;
    end;
    lStartPos := i;
    while (i <= Length(aText)) and InventoryIsIdentifierChar(aText[i]) do
      Inc(i);
    lEndPos := i - 1;
    if SameText(Copy(aText, lStartPos, lEndPos - lStartPos + 1), aToken) then
      Inc(Result);
  end;
end;

function InventoryEndTerminatedBlockOpenCount(const aText: string): Integer;
begin
  Result := InventoryTokenCount(aText, 'begin') + InventoryTokenCount(aText, 'case') +
    InventoryTokenCount(aText, 'try') + InventoryTokenCount(aText, 'asm');
end;

function InventoryFindRoutineEndLine(const aLines: TArray<string>; const aStartIndex: Integer):
  Integer;
var
  i: Integer;
  lDepth: Integer;
  lLine: string;
  lNestedEndLine: Integer;
  lStarted: Boolean;
begin
  Result := 0;
  lDepth := 0;
  lStarted := False;
  i := aStartIndex + 1;
  while i <= High(aLines) do
  begin
    lLine := LowerCase(InventoryCleanLine(aLines[i]));
    if lLine = '' then
    begin
      Inc(i);
      Continue;
    end;
    if not lStarted then
    begin
      if InventoryIsTopLevelLine(aLines[i]) and (InventoryIsRoutineStart(lLine) or
        SameText(lLine, 'implementation') or SameText(lLine, 'interface')) then
        Exit(0);
      if InventoryIsRoutineStart(lLine) then
      begin
        lNestedEndLine := InventoryFindRoutineEndLine(aLines, i);
        if lNestedEndLine > 0 then
        begin
          i := lNestedEndLine;
          Continue;
        end;
      end;
      if (InventoryTokenCount(lLine, 'begin') = 0) and (InventoryTokenCount(lLine, 'asm') = 0) then
      begin
        Inc(i);
        Continue;
      end;
      lStarted := True;
    end;
    Inc(lDepth, InventoryEndTerminatedBlockOpenCount(lLine));
    Dec(lDepth, InventoryTokenCount(lLine, 'end'));
    if lStarted and (lDepth <= 0) then
      Exit(i + 1);
    Inc(i);
  end;
end;

function InventoryCollectDeclarationText(const aLines: TArray<string>; const aStartLine: Integer;
  out aEndLine: Integer): string;
var
  i: Integer;
  j: Integer;
  lLine: string;
  lParenDepth: Integer;
begin
  Result := '';
  aEndLine := aStartLine;
  lParenDepth := 0;
  for i := aStartLine to High(aLines) do
  begin
    aEndLine := i;
    lLine := InventoryCleanLine(aLines[i]);
    if lLine <> '' then
    begin
      if Result <> '' then
        Result := Result + ' ';
      Result := Result + lLine;
      for j := 1 to Length(lLine) do
      begin
        if lLine[j] = '(' then
          Inc(lParenDepth)
        else if (lLine[j] = ')') and (lParenDepth > 0) then
          Dec(lParenDepth);
      end;
    end;
    if (Pos(';', lLine) > 0) and (lParenDepth = 0) then
      Exit;
  end;
end;

function InventoryCollectTypeStartText(const aLines: TArray<string>;
  const aStartLine: Integer): string;
var
  i: Integer;
  lLine: string;
  lText: string;
begin
  Result := '';
  for i := aStartLine to High(aLines) do
  begin
    lLine := InventoryCleanLine(aLines[i]);
    if lLine <> '' then
    begin
      if Result <> '' then
        Result := Result + ' ';
      Result := Result + lLine;
      lText := LowerCase(Result);
      if (Pos(' class', lText) > 0) or (Pos(' record', lText) > 0) or
        (Pos(' interface', lText) > 0) or (Pos(';', lLine) > 0) then
        Exit;
    end;
  end;
end;

function InventoryUnsupportedReasonForTypeStart(const aTypeName, aPendingReason: string;
  const aConditionalDepth: Integer): string;
begin
  if aPendingReason <> '' then
    Exit(aPendingReason);
  if aConditionalDepth > 0 then
    Exit('unsupported-source-model-conditional-region');
  if Pos('<', aTypeName) > 0 then
    Exit('unsupported-source-model-generic-declaration');
  Result := '';
end;

function InventoryFindTypeEndLine(const aLines: TArray<string>; const aStartIndex: Integer):
  Integer;
var
  i: Integer;
  lLine: string;
begin
  Result := aStartIndex + 1;
  for i := aStartIndex + 1 to High(aLines) do
  begin
    lLine := LowerCase(InventoryCleanLine(aLines[i]));
    if SameText(lLine, 'end;') or SameText(lLine, 'end') or StartsText('end ', lLine) then
      Exit(i + 1);
  end;
end;

function InventoryFindNameSource(const aLines: TArray<string>; const aStartIndex,
  aEndIndex: Integer; const aName: string; out aLineNumber: Integer;
  out aLineText: string): Boolean;
var
  i: Integer;
  lEndIndex: Integer;
begin
  Result := False;
  aLineNumber := 0;
  aLineText := '';
  lEndIndex := aEndIndex;
  if lEndIndex > High(aLines) then
    lEndIndex := High(aLines);
  for i := aStartIndex to lEndIndex do
  begin
    if Pos(aName, aLines[i]) > 0 then
    begin
      aLineNumber := i + 1;
      aLineText := aLines[i];
      Exit(True);
    end;
  end;
end;

function InventoryDecodeSourceText(const aBytes: TBytes): string;
var
  lOffset: Integer;
begin
  lOffset := 0;
  if (Length(aBytes) >= 3) and (aBytes[0] = $EF) and (aBytes[1] = $BB) and
    (aBytes[2] = $BF) then
    lOffset := 3;

  try
    Result := TEncoding.UTF8.GetString(aBytes, lOffset, Length(aBytes) - lOffset);
  except
    on E: EEncodingError do
      Result := TEncoding.Default.GetString(aBytes, lOffset, Length(aBytes) - lOffset);
  end;
end;

function InventoryReadSourceLines(const aFileName: string): TArray<string>;
var
  i: Integer;
  lLines: TStringList;
  lText: string;
begin
  SetLength(Result, 0);
  if not TFile.Exists(aFileName) then
    Exit;

  lText := InventoryDecodeSourceText(TFile.ReadAllBytes(aFileName));
  lLines := TStringList.Create;
  try
    lLines.Text := lText;
    SetLength(Result, lLines.Count);
    for i := 0 to lLines.Count - 1 do
      Result[i] := lLines[i];
  finally
    lLines.Free;
  end;
end;

procedure AddDakInventorySymbol(const aSymbols: TList<TDelphiSemanticInventorySymbol>;
  const aName, aTypeName, aOwnerType, aRoutineName, aUnitName, aFileName: string;
  const aLineNumber: Integer; const aLineText, aKind: string;
  const aModifier: string = '');
var
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  lSymbol := Default(TDelphiSemanticInventorySymbol);
  lSymbol.Name := aName;
  lSymbol.SymbolClass := aKind;
  lSymbol.Kind := aKind;
  lSymbol.TypeName := aTypeName;
  lSymbol.OwnerName := aOwnerType;
  lSymbol.OwnerType := aOwnerType;
  lSymbol.RoutineName := aRoutineName;
  lSymbol.Modifier := aModifier;
  lSymbol.UnitName := aUnitName;
  lSymbol.FileName := aFileName;
  lSymbol.Line := aLineNumber;
  lSymbol.EndLine := aLineNumber;
  lSymbol.Column := InventoryFindColumn(aLineText, aName);
  lSymbol.EndColumn := lSymbol.Column + Length(aName);
  AddInventorySymbol(aSymbols, lSymbol);
end;

procedure AddDakInventoryTypeSymbol(const aSymbols: TList<TDelphiSemanticInventorySymbol>;
  const aName, aTypeName, aTypeCategory, aUnitName, aFileName: string; const aLineNumber,
  aEndLine: Integer; const aLineText: string);
var
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  lSymbol := Default(TDelphiSemanticInventorySymbol);
  lSymbol.Name := aName;
  lSymbol.SymbolClass := 'type-member';
  lSymbol.Kind := 'type-member';
  lSymbol.TypeName := aTypeName;
  lSymbol.TypeCategory := aTypeCategory;
  lSymbol.UnitName := aUnitName;
  lSymbol.FileName := aFileName;
  lSymbol.Line := aLineNumber;
  lSymbol.EndLine := aEndLine;
  lSymbol.Column := InventoryFindColumn(aLineText, aName);
  lSymbol.EndColumn := lSymbol.Column + Length(aName);
  AddInventorySymbol(aSymbols, lSymbol);
end;

procedure AddDakInventorySymbolsFromSource(const aSymbols: TList<TDelphiSemanticInventorySymbol>;
  const aNames: TArray<string>; const aTypeName, aOwnerType, aRoutineName, aUnitName,
  aFileName: string; const aLines: TArray<string>; const aStartIndex, aEndIndex: Integer;
  const aKind: string; const aModifier: string = '');
var
  lLineNumber: Integer;
  lLineText: string;
  lName: string;
begin
  for lName in aNames do
  begin
    if not InventoryFindNameSource(aLines, aStartIndex, aEndIndex, lName, lLineNumber,
      lLineText) then
    begin
      lLineNumber := aStartIndex + 1;
      if (aStartIndex >= 0) and (aStartIndex <= High(aLines)) then
        lLineText := aLines[aStartIndex]
      else
        lLineText := lName;
    end;
    AddDakInventorySymbol(aSymbols, lName, aTypeName, aOwnerType, aRoutineName, aUnitName,
      aFileName, lLineNumber, lLineText, aKind, aModifier);
  end;
end;

procedure MarkDakTypeUnsupported(const aSymbols: TList<TDelphiSemanticInventorySymbol>;
  const aTypeName, aReason: string);
var
  i: Integer;
  lSymbol: TDelphiSemanticInventorySymbol;
  lTypeName: string;
begin
  if aReason = '' then
    Exit;
  lTypeName := InventorySimpleTypeName(aTypeName);
  for i := 0 to Pred(aSymbols.Count) do
  begin
    lSymbol := aSymbols[i];
    if SameText(lSymbol.SymbolClass, 'type-member') and SameText(lSymbol.Name, lTypeName) then
    begin
      if lSymbol.UnsupportedReason = '' then
      begin
        lSymbol.UnsupportedReason := aReason;
        aSymbols[i] := lSymbol;
      end;
      Exit;
    end;
  end;
end;

procedure AddDakTypedSymbols(const aSymbols: TList<TDelphiSemanticInventorySymbol>;
  const aNames: TArray<string>; const aTypeName, aOwnerType, aRoutineName, aUnitName,
  aFileName: string; const aLineNumber: Integer; const aLineText, aKind: string);
var
  lName: string;
begin
  for lName in aNames do
    AddDakInventorySymbol(aSymbols, lName, aTypeName, aOwnerType, aRoutineName, aUnitName,
      aFileName, aLineNumber, aLineText, aKind);
end;

function InventoryTryAnonymousRecordLocalStart(const aLine: string; out aName,
  aTypeCategory: string): Boolean;
var
  lColonPos: Integer;
  lRest: string;
begin
  Result := False;
  aName := '';
  aTypeCategory := '';
  lColonPos := Pos(':', aLine);
  if lColonPos = 0 then
    Exit;

  aName := Trim(Copy(aLine, 1, lColonPos - 1));
  lRest := LowerCase(Trim(Copy(aLine, lColonPos + 1, MaxInt)));
  if StartsText('packed record', lRest) or StartsText('record', lRest) then
    aTypeCategory := 'record'
  else
    Exit;

  Result := aName <> '';
end;

procedure AddDakInventoryRecordFieldsFromLine(const aSymbols: TList<TDelphiSemanticInventorySymbol>;
  const aLines: TArray<string>; const aLineIndex: Integer; const aOwnerType, aUnitName,
  aFileName: string);
var
  lDeclaration: string;
  lDeclarationParts: TArray<string>;
  lLine: string;
  lMemberName: string;
  lNames: TArray<string>;
  lRawDeclaration: string;
  lTypeName: string;
begin
  lLine := InventoryVariantFieldDeclarationLine(InventoryCleanLine(aLines[aLineIndex]));
  if lLine = '' then
    Exit;
  if InventoryTryVariantTagDeclaration(lLine, lMemberName, lTypeName) then
  begin
    AddDakInventorySymbol(aSymbols, lMemberName, lTypeName, aOwnerType, '', aUnitName,
      aFileName, aLineIndex + 1, aLines[aLineIndex], 'field');
    Exit;
  end;

  lDeclarationParts := lLine.Split([';']);
  for lRawDeclaration in lDeclarationParts do
  begin
    lDeclaration := Trim(lRawDeclaration);
    if lDeclaration = '' then
      Continue;
    if InventoryTryDeclaration(lDeclaration + ';', lNames, lTypeName) then
      AddDakTypedSymbols(aSymbols, lNames, lTypeName, aOwnerType, '', aUnitName, aFileName,
        aLineIndex + 1, aLines[aLineIndex], 'field');
  end;
end;

procedure ParseDakInventoryParams(const aSymbols: TList<TDelphiSemanticInventorySymbol>;
  const aLines: TArray<string>; const aStartIndex: Integer; const aSignature, aRoutineName,
  aUnitName, aFileName: string);
var
  lClosePos: Integer;
  lEndIndex: Integer;
  lModifier: string;
  lNames: TArray<string>;
  lOpenPos: Integer;
  lPart: string;
  lParts: TArray<string>;
  lText: string;
  lTypeName: string;
begin
  lOpenPos := Pos('(', aSignature);
  lClosePos := LastDelimiter(')', aSignature);
  if (lOpenPos = 0) or (lClosePos <= lOpenPos) then
    Exit;

  lParts := Copy(aSignature, lOpenPos + 1, lClosePos - lOpenPos - 1).Split([';']);
  for lPart in lParts do
  begin
    lText := Trim(lPart);
    lModifier := '';
    if StartsText('const ', lText) then
    begin
      Delete(lText, 1, Length('const '));
      lModifier := 'const';
    end else if StartsText('var ', lText) then
    begin
      Delete(lText, 1, Length('var '));
      lModifier := 'var';
    end else if StartsText('out ', lText) then
    begin
      Delete(lText, 1, Length('out '));
      lModifier := 'out';
    end;

    if InventoryTryDeclaration(lText, lNames, lTypeName) then
    begin
      lEndIndex := aStartIndex + 20;
      AddDakInventorySymbolsFromSource(aSymbols, lNames, lTypeName, '', aRoutineName, aUnitName,
        aFileName, aLines, aStartIndex, lEndIndex, 'parameter', lModifier);
    end else if (lModifier <> '') and (Pos(':', lText) = 0) and (lText <> '') then
    begin
      lNames := lText.Split([',']);
      lEndIndex := aStartIndex + 20;
      AddDakInventorySymbolsFromSource(aSymbols, lNames, '', '', aRoutineName, aUnitName,
        aFileName, aLines, aStartIndex, lEndIndex, 'parameter', lModifier);
    end;
  end;
end;

procedure ParseDakInventoryLocals(const aSymbols: TList<TDelphiSemanticInventorySymbol>;
  const aLines: TArray<string>; const aStartLine: Integer; const aRoutineName, aUnitName,
  aFileName: string);
var
  i: Integer;
  j: Integer;
  lAnonymousEndLine: Integer;
  lConstName: string;
  lCurrentType: string;
  lDeclaration: string;
  lDeclarationLine: Integer;
  lEnumMatch: TMatch;
  lEnumNames: TArray<string>;
  lInType: Boolean;
  lInConst: Boolean;
  lInVar: Boolean;
  lLine: string;
  lNames: TArray<string>;
  lRawTypeName: string;
  lSkipUntilLine: Integer;
  lTypeCategory: string;
  lTypeText: string;
  lTypeName: string;
begin
  lCurrentType := '';
  lDeclaration := '';
  lDeclarationLine := 0;
  lInConst := False;
  lInType := False;
  lInVar := False;
  lSkipUntilLine := 0;
  for i := aStartLine to High(aLines) do
  begin
    if i < lSkipUntilLine then
      Continue;
    lLine := InventoryCleanLine(aLines[i]);
    if SameText(lLine, 'const') then
    begin
      lCurrentType := '';
      lInConst := True;
      lInType := False;
      lInVar := False;
      lDeclaration := '';
      Continue;
    end;
    if SameText(lLine, 'type') then
    begin
      lCurrentType := '';
      lInConst := False;
      lInType := True;
      lInVar := False;
      lDeclaration := '';
      Continue;
    end;
    if SameText(lLine, 'var') then
    begin
      lCurrentType := '';
      lInConst := False;
      lInType := False;
      lInVar := True;
      lDeclaration := '';
      Continue;
    end;
    if SameText(lLine, 'begin') then
      Exit;
    if InventoryIsRoutineStart(lLine) then
    begin
      lSkipUntilLine := InventoryFindRoutineEndLine(aLines, i);
      if lSkipUntilLine = 0 then
        Exit;
      Continue;
    end;
    if StartsText('const ', LowerCase(lLine)) then
    begin
      lInConst := True;
      lInVar := False;
      lLine := Trim(Copy(lLine, Length('const ') + 1, MaxInt));
    end;
    if lInType and (lLine <> '') then
    begin
      if (lCurrentType <> '') and (SameText(lLine, 'end;') or SameText(lLine, 'end')) then
      begin
        lCurrentType := '';
        Continue;
      end;

      if lCurrentType = '' then
      begin
        lTypeText := InventoryCollectTypeStartText(aLines, i);
        if InventoryTryTypeStart(lTypeText, lRawTypeName, lTypeCategory) then
        begin
          lCurrentType := InventorySimpleTypeName(lRawTypeName);
          AddDakInventoryTypeSymbol(aSymbols, lCurrentType, '', lTypeCategory, aUnitName,
            aFileName, i + 1, InventoryFindTypeEndLine(aLines, i), aLines[i]);
          if InventoryTryEnumValues(lTypeText, lEnumNames) then
            AddDakTypedSymbols(aSymbols, lEnumNames, lCurrentType, '', aRoutineName, aUnitName,
              aFileName, i + 1, aLines[i], 'constant');
        end else if InventoryTryTypeAlias(lTypeText, lCurrentType, lTypeName) then
        begin
          AddDakInventorySymbol(aSymbols, lCurrentType, lTypeName, '', '', aUnitName,
            aFileName, i + 1, aLines[i], 'type-member');
          if InventoryTryEnumValues(lTypeText, lEnumNames) then
            AddDakTypedSymbols(aSymbols, lEnumNames, lCurrentType, '', aRoutineName, aUnitName,
              aFileName, i + 1, aLines[i], 'constant');
        end;
        Continue;
      end;

      AddDakInventoryRecordFieldsFromLine(aSymbols, aLines, i, lCurrentType, aUnitName,
        aFileName);
      Continue;
    end;
    if lInConst and (lLine <> '') and InventoryTryConstDeclaration(lLine, lConstName, lTypeName) then
    begin
      AddDakInventorySymbol(aSymbols, lConstName, lTypeName, '', aRoutineName, aUnitName,
        aFileName, i + 1, aLines[i], 'constant');
      Continue;
    end;
    if lInVar and (lLine <> '') then
    begin
      if InventoryTryAnonymousRecordLocalStart(lLine, lConstName, lTypeCategory) then
      begin
        lTypeName := aRoutineName + '.' + lConstName;
        lAnonymousEndLine := InventoryFindTypeEndLine(aLines, i);
        AddDakInventoryTypeSymbol(aSymbols, lTypeName, '', lTypeCategory, aUnitName,
          aFileName, i + 1, lAnonymousEndLine, aLines[i]);
        AddDakInventorySymbol(aSymbols, lConstName, lTypeName, '', aRoutineName, aUnitName,
          aFileName, i + 1, aLines[i], 'local');
        for j := i + 1 to lAnonymousEndLine - 2 do
          AddDakInventoryRecordFieldsFromLine(aSymbols, aLines, j, lTypeName, aUnitName,
            aFileName);
        lSkipUntilLine := lAnonymousEndLine;
        lDeclaration := '';
        lDeclarationLine := 0;
        Continue;
      end;
      if lDeclaration = '' then
        lDeclarationLine := i + 1;
      if lDeclaration <> '' then
        lDeclaration := lDeclaration + ' ';
      lDeclaration := lDeclaration + lLine;
      if Pos(';', lLine) > 0 then
      begin
        if InventoryTryDeclaration(lDeclaration, lNames, lTypeName) then
        begin
          AddDakInventorySymbolsFromSource(aSymbols, lNames, lTypeName, '', aRoutineName,
            aUnitName, aFileName, aLines, lDeclarationLine - 1, i, 'local');
          lEnumMatch := TRegEx.Match(lDeclaration, ':\s*\(([^)]*)\)');
          if lEnumMatch.Success and
            InventoryTryEnumValues('TAnonymousEnum = (' + lEnumMatch.Groups[1].Value + ')', lEnumNames) then
            AddDakTypedSymbols(aSymbols, lEnumNames, lTypeName, '', aRoutineName, aUnitName,
              aFileName, lDeclarationLine, aLines[lDeclarationLine - 1], 'constant');
        end;
        lDeclaration := '';
        lDeclarationLine := 0;
      end;
    end;
  end;
end;

procedure ParseDakInventoryTypeMembers(const aSymbols: TList<TDelphiSemanticInventorySymbol>;
  const aLines: TArray<string>; const aUnitName, aFileName: string);
var
  i: Integer;
  j: Integer;
  lAnonymousEndLine: Integer;
  lCollectedEndLine: Integer;
  lConditionalDepth: Integer;
  lConstName: string;
  lCurrentType: string;
  lCurrentTypeUnsupportedReason: string;
  lDeclaration: string;
  lDeclarationAdded: Boolean;
  lDeclarationParts: TArray<string>;
  lEnumMatch: TMatch;
  lEnumNames: TArray<string>;
  lInClassVar: Boolean;
  lInConst: Boolean;
  lInTypeSection: Boolean;
  lLine: string;
  lLower: string;
  lMemberName: string;
  lNames: TArray<string>;
  lPendingUnsupportedReason: string;
  lPropertyIndexed: Boolean;
  lPropertyIndexParameterCount: Integer;
  lPropertyIsDefault: Boolean;
  lPropertyType: string;
  lRawDeclaration: string;
  lRawLine: string;
  lRawTypeName: string;
  lRelatedTypeName: string;
  lSkipUntilLine: Integer;
  lSymbol: TDelphiSemanticInventorySymbol;
  lTypeCategory: string;
  lTypeIsHelper: Boolean;
  lTypeName: string;
  lTypeText: string;
begin
  lConditionalDepth := 0;
  lCurrentType := '';
  lCurrentTypeUnsupportedReason := '';
  lInClassVar := False;
  lInConst := False;
  lInTypeSection := False;
  lPendingUnsupportedReason := '';
  lSkipUntilLine := 0;
  for i := 0 to High(aLines) do
  begin
    if i < lSkipUntilLine then
      Continue;
    lRawLine := aLines[i];
    lLine := InventoryCleanLine(lRawLine);
    lLower := LowerCase(lLine);
    if lLine = '' then
      Continue;

    if InventoryIsConditionalDirectiveLine(lLine) then
    begin
      if lCurrentType <> '' then
      begin
        lCurrentTypeUnsupportedReason := 'unsupported-source-model-conditional-region';
        MarkDakTypeUnsupported(aSymbols, lCurrentType, lCurrentTypeUnsupportedReason);
      end else if lInTypeSection and (not InventoryIsConditionalEndDirective(lLine)) then
        lPendingUnsupportedReason := 'unsupported-source-model-conditional-region';

      if InventoryIsConditionalStartDirective(lLine) then
        Inc(lConditionalDepth)
      else if InventoryIsConditionalEndDirective(lLine) and (lConditionalDepth > 0) then
        Dec(lConditionalDepth);
      Continue;
    end;

    if InventoryIsAttributeLine(lLine) then
    begin
      if lCurrentType <> '' then
      begin
        lCurrentTypeUnsupportedReason := 'unsupported-source-model-attribute';
        MarkDakTypeUnsupported(aSymbols, lCurrentType, lCurrentTypeUnsupportedReason);
      end else if lInTypeSection then
        lPendingUnsupportedReason := 'unsupported-source-model-attribute';
      Continue;
    end;

    if (lCurrentType = '') and SameText(lLine, 'type') then
    begin
      lConditionalDepth := 0;
      lInTypeSection := True;
      Continue;
    end;
    if SameText(lLine, 'implementation') or ((lCurrentType = '') and
      (SameText(lLine, 'const') or SameText(lLine, 'var') or SameText(lLine, 'threadvar') or
      InventoryIsRoutineStart(lLine))) then
    begin
      lCurrentType := '';
      lCurrentTypeUnsupportedReason := '';
      lInTypeSection := False;
      lInClassVar := False;
      lInConst := False;
      lPendingUnsupportedReason := '';
      Continue;
    end;

    if lCurrentType = '' then
    begin
      if not lInTypeSection then
        Continue;
      lTypeText := InventoryCollectTypeStartText(aLines, i);
      if InventoryTryTypeStart(lTypeText, lRawTypeName, lTypeCategory) then
      begin
        lCurrentType := InventorySimpleTypeName(lRawTypeName);
        lCurrentTypeUnsupportedReason := InventoryUnsupportedReasonForTypeStart(lRawTypeName,
          lPendingUnsupportedReason, lConditionalDepth);
        lInClassVar := False;
        lInConst := False;
        InventoryTryTypeRelation(lTypeText, lRelatedTypeName, lTypeIsHelper);
        lSymbol := Default(TDelphiSemanticInventorySymbol);
        lSymbol.Name := lCurrentType;
        lSymbol.SymbolClass := 'type-member';
        lSymbol.Kind := 'type-member';
        lSymbol.RelatedTypeName := lRelatedTypeName;
        lSymbol.IsHelper := lTypeIsHelper;
        lSymbol.TypeCategory := lTypeCategory;
        lSymbol.UnitName := aUnitName;
        lSymbol.FileName := aFileName;
        lSymbol.Line := i + 1;
        lSymbol.EndLine := InventoryFindTypeEndLine(aLines, i);
        lSymbol.Column := InventoryFindColumn(aLines[i], lCurrentType);
        lSymbol.EndColumn := lSymbol.Column + Length(lCurrentType);
        lSymbol.UnsupportedReason := lCurrentTypeUnsupportedReason;
        AddInventorySymbol(aSymbols, lSymbol);
        if InventoryTryEnumValues(lTypeText, lEnumNames) then
          AddDakTypedSymbols(aSymbols, lEnumNames, lCurrentType, '', '', aUnitName, aFileName,
            i + 1, aLines[i], 'constant');
        lPendingUnsupportedReason := '';
      end else if InventoryTryTypeAlias(lTypeText, lMemberName, lTypeName) then
      begin
        AddDakInventorySymbol(aSymbols, lMemberName, lTypeName, '', '', aUnitName, aFileName,
          i + 1, aLines[i], 'type-member');
        lSymbol := aSymbols[Pred(aSymbols.Count)];
        lSymbol.RelatedTypeName := InventorySimpleTypeName(lTypeName);
        aSymbols[Pred(aSymbols.Count)] := lSymbol;
        if InventoryTryEnumValues(lTypeText, lEnumNames) then
          AddDakTypedSymbols(aSymbols, lEnumNames, lMemberName, '', '', aUnitName, aFileName,
            i + 1, aLines[i], 'constant');
        lPendingUnsupportedReason := '';
      end;
      Continue;
    end;

    if SameText(lLine, 'end;') or SameText(lLine, 'end') then
    begin
      lCurrentType := '';
      lCurrentTypeUnsupportedReason := '';
      Continue;
    end;
    if InventoryIsVisibilityLine(lLine) then
      Continue;
    if SameText(lLine, 'type') then
    begin
      lCurrentTypeUnsupportedReason := 'unsupported-source-model-nested-type';
      MarkDakTypeUnsupported(aSymbols, lCurrentType, lCurrentTypeUnsupportedReason);
      Continue;
    end;
    if InventoryIsMultilineDeclarationStart(lLine) then
    begin
      lLine := InventoryCollectDeclarationText(aLines, i, lCollectedEndLine);
      lSkipUntilLine := lCollectedEndLine + 1;
    end;
    if lCurrentTypeUnsupportedReason <> '' then
      Continue;
    if InventoryTryAnonymousRecordLocalStart(lLine, lMemberName, lTypeCategory) then
    begin
      lTypeName := lCurrentType + '.' + lMemberName;
      lAnonymousEndLine := InventoryFindTypeEndLine(aLines, i);
      AddDakInventoryTypeSymbol(aSymbols, lTypeName, '', lTypeCategory, aUnitName,
        aFileName, i + 1, lAnonymousEndLine, aLines[i]);
      AddDakInventorySymbol(aSymbols, lMemberName, lTypeName, lCurrentType, '', aUnitName,
        aFileName, i + 1, aLines[i], 'field');
      for j := i + 1 to lAnonymousEndLine - 2 do
        AddDakInventoryRecordFieldsFromLine(aSymbols, aLines, j, lTypeName, aUnitName,
          aFileName);
      lSkipUntilLine := lAnonymousEndLine;
      Continue;
    end;
    lLine := InventoryVariantFieldDeclarationLine(lLine);
    lLower := LowerCase(lLine);
    if InventoryTryVariantTagDeclaration(lLine, lMemberName, lTypeName) then
    begin
      AddDakInventorySymbol(aSymbols, lMemberName, lTypeName, lCurrentType, '', aUnitName,
        aFileName, i + 1, aLines[i], 'field');
      Continue;
    end;
    if StartsText('class var', lLower) then
    begin
      lInClassVar := True;
      lLine := Trim(Copy(lLine, Length('class var') + 1, MaxInt));
      if lLine = '' then
        Continue;
    end;
    if SameText(lLine, 'const') then
    begin
      lInConst := True;
      lInClassVar := False;
      Continue;
    end;
    if StartsText('const ', lLower) then
    begin
      lInConst := True;
      lLine := Trim(Copy(lLine, Length('const ') + 1, MaxInt));
    end;

    if lInConst and InventoryTryConstDeclaration(lLine, lConstName, lTypeName) then
    begin
      AddDakInventorySymbol(aSymbols, lConstName, lTypeName, lCurrentType, '', aUnitName,
        aFileName, i + 1, aLines[i], 'constant');
      Continue;
    end;

    if InventoryTryPropertyDeclaration(lLine, lMemberName, lPropertyType, lPropertyIsDefault,
      lPropertyIndexed, lPropertyIndexParameterCount) then
    begin
      lSymbol := Default(TDelphiSemanticInventorySymbol);
      lSymbol.Name := lMemberName;
      lSymbol.SymbolClass := 'property';
      lSymbol.Kind := 'property';
      lSymbol.TypeName := lPropertyType;
      lSymbol.OwnerName := lCurrentType;
      lSymbol.OwnerType := lCurrentType;
      lSymbol.UnitName := aUnitName;
      lSymbol.FileName := aFileName;
      lSymbol.Line := i + 1;
      lSymbol.EndLine := i + 1;
      lSymbol.Column := InventoryFindColumn(aLines[i], lMemberName);
      lSymbol.EndColumn := lSymbol.Column + Length(lMemberName);
      lSymbol.IsDefault := lPropertyIsDefault;
      lSymbol.IsIndexed := lPropertyIndexed;
      lSymbol.IndexParameterCount := lPropertyIndexParameterCount;
      AddInventorySymbol(aSymbols, lSymbol);
      Continue;
    end;

    if InventoryIsRoutineStart(lLine) and InventoryTryRoutineName(lLine, lMemberName) then
    begin
      if Pos('.', lMemberName) > 0 then
        lMemberName := Copy(lMemberName, LastDelimiter('.', lMemberName) + 1, MaxInt);
      lSymbol := Default(TDelphiSemanticInventorySymbol);
      lSymbol.Name := lMemberName;
      lSymbol.SymbolClass := 'method';
      lSymbol.Kind := 'method';
      lSymbol.OwnerName := lCurrentType;
      lSymbol.OwnerType := lCurrentType;
      lSymbol.UnitName := aUnitName;
      lSymbol.FileName := aFileName;
      lSymbol.Line := i + 1;
      lSymbol.EndLine := i + 1;
      lSymbol.Column := InventoryFindColumn(aLines[i], lMemberName);
      lSymbol.EndColumn := lSymbol.Column + Length(lMemberName);
      lSymbol.IsOverride := Pos(' override', lLower) > 0;
      AddInventorySymbol(aSymbols, lSymbol);
      Continue;
    end;

    lDeclarationAdded := False;
    lDeclarationParts := lLine.Split([';']);
    for lRawDeclaration in lDeclarationParts do
    begin
      lDeclaration := Trim(lRawDeclaration);
      if lDeclaration = '' then
        Continue;
      if not InventoryTryDeclaration(lDeclaration + ';', lNames, lTypeName) then
        Continue;

      if lInClassVar then
        AddDakTypedSymbols(aSymbols, lNames, lTypeName, lCurrentType, '', aUnitName, aFileName,
          i + 1, aLines[i], 'class-var')
      else
        AddDakTypedSymbols(aSymbols, lNames, lTypeName, lCurrentType, '', aUnitName, aFileName,
          i + 1, aLines[i], 'field');
      lDeclarationAdded := True;
    end;
    if lDeclarationAdded then
      Continue;

    if InventoryTryDeclaration(lLine, lNames, lTypeName) then
    begin
      if lInClassVar then
        AddDakTypedSymbols(aSymbols, lNames, lTypeName, lCurrentType, '', aUnitName, aFileName,
          i + 1, aLines[i], 'class-var')
      else
        AddDakTypedSymbols(aSymbols, lNames, lTypeName, lCurrentType, '', aUnitName, aFileName,
          i + 1, aLines[i], 'field');
    end;
  end;
end;

procedure ParseDakInventoryUnitGlobals(const aSymbols: TList<TDelphiSemanticInventorySymbol>;
  const aLines: TArray<string>; const aUnitName, aFileName: string);
var
  i: Integer;
  j: Integer;
  lAnonymousEndLine: Integer;
  lConstName: string;
  lDeclaration: string;
  lDeclarationLine: Integer;
  lEnumMatch: TMatch;
  lEnumNames: TArray<string>;
  lInConst: Boolean;
  lInType: Boolean;
  lInVar: Boolean;
  lLine: string;
  lNames: TArray<string>;
  lRawLine: string;
  lRoutineEndLine: Integer;
  lTypeCategory: string;
  lTypeName: string;
begin
  lDeclaration := '';
  lDeclarationLine := 0;
  lInConst := False;
  lInType := False;
  lInVar := False;
  i := 0;
  while i <= High(aLines) do
  begin
    try
      lRawLine := aLines[i];
      lLine := InventoryCleanLine(lRawLine);
      if lLine = '' then
        Continue;

      if SameText(lLine, 'implementation') then
      begin
        lDeclaration := '';
        lDeclarationLine := 0;
        lInType := False;
        lInVar := False;
        lInConst := False;
        Continue;
      end;

      if SameText(lLine, 'type') then
      begin
        lDeclaration := '';
        lDeclarationLine := 0;
        lInType := True;
        lInVar := False;
        lInConst := False;
        Continue;
      end;
      if SameText(lLine, 'var') or SameText(lLine, 'threadvar') then
      begin
        lDeclaration := '';
        lDeclarationLine := 0;
        lInType := False;
        lInVar := True;
        lInConst := False;
        Continue;
      end;
      if SameText(lLine, 'const') then
      begin
        lDeclaration := '';
        lDeclarationLine := 0;
        lInType := False;
        lInConst := True;
        lInVar := False;
        Continue;
      end;

      if InventoryIsConditionalDirectiveLine(lLine) then
        Continue;

      if lInType then
        Continue;

      if InventoryIsRoutineStart(lLine) then
      begin
        lInVar := False;
        lInConst := False;
        lRoutineEndLine := InventoryFindRoutineEndLine(aLines, i);
        if lRoutineEndLine > 0 then
          i := lRoutineEndLine - 1;
        Continue;
      end;

      if lInVar and (lLine <> '') then
      begin
        if (lDeclaration = '') and InventoryTryAnonymousRecordLocalStart(lLine, lConstName,
          lTypeCategory) then
        begin
          lTypeName := aUnitName + '.' + lConstName;
          lAnonymousEndLine := InventoryFindTypeEndLine(aLines, i);
          AddDakInventoryTypeSymbol(aSymbols, lTypeName, '', lTypeCategory, aUnitName,
            aFileName, i + 1, lAnonymousEndLine, aLines[i]);
          AddDakInventorySymbol(aSymbols, lConstName, lTypeName, '', '', aUnitName, aFileName,
            i + 1, aLines[i], 'unit-global');
          for j := i + 1 to lAnonymousEndLine - 2 do
            AddDakInventoryRecordFieldsFromLine(aSymbols, aLines, j, lTypeName, aUnitName,
              aFileName);
          i := lAnonymousEndLine - 1;
          Continue;
        end;

        if lDeclaration = '' then
          lDeclarationLine := i + 1;
        if lDeclaration <> '' then
          lDeclaration := lDeclaration + ' ';
        lDeclaration := lDeclaration + lLine;
        if Pos(';', lLine) > 0 then
        begin
          if InventoryTryDeclaration(lDeclaration, lNames, lTypeName) then
          begin
            AddDakTypedSymbols(aSymbols, lNames, lTypeName, '', '', aUnitName, aFileName,
              lDeclarationLine, aLines[lDeclarationLine - 1], 'unit-global');
            lEnumMatch := TRegEx.Match(lDeclaration, ':\s*\(([^)]*)\)');
            if lEnumMatch.Success and
              InventoryTryEnumValues('TAnonymousEnum = (' + lEnumMatch.Groups[1].Value + ')',
              lEnumNames) then
              AddDakTypedSymbols(aSymbols, lEnumNames, lTypeName, '', '', aUnitName,
                aFileName, lDeclarationLine, aLines[lDeclarationLine - 1], 'constant');
          end;
          lDeclaration := '';
          lDeclarationLine := 0;
        end;
      end else if lInConst and InventoryTryConstDeclaration(lLine, lConstName, lTypeName) then
        AddDakInventorySymbol(aSymbols, lConstName, lTypeName, '', '', aUnitName, aFileName,
          i + 1, aLines[i], 'constant');
    finally
      Inc(i);
    end;
  end;
end;

procedure ParseDakInventoryRoutines(const aSymbols: TList<TDelphiSemanticInventorySymbol>;
  const aLines: TArray<string>; const aUnitName, aFileName: string);
var
  i: Integer;
  lEndLine: Integer;
  lInImplementation: Boolean;
  lInType: Boolean;
  lLine: string;
  lMember: TDelphiSemanticInventorySymbol;
  lMemberCopy: TDelphiSemanticInventorySymbol;
  lMembers: TList<TDelphiSemanticInventorySymbol>;
  lMembersByOwner: TDictionary<string, TList<TDelphiSemanticInventorySymbol>>;
  lOwnerType: string;
  lRawLine: string;
  lRoutineName: string;
  lSignature: string;
  lSymbol: TDelphiSemanticInventorySymbol;
  lTopLevelLine: Boolean;
begin
  lMembersByOwner := TDictionary<string, TList<TDelphiSemanticInventorySymbol>>.Create(
    TFastCaseAwareComparer.OrdinalIgnoreCase);
  lInImplementation := False;
  lInType := False;
  try
    for lMember in aSymbols do
      if (lMember.RoutineName = '') and InventoryIsDirectMemberKind(lMember.SymbolClass) then
      begin
        if not lMembersByOwner.TryGetValue(lMember.OwnerType, lMembers) then
        begin
          lMembers := TList<TDelphiSemanticInventorySymbol>.Create;
          lMembersByOwner.Add(lMember.OwnerType, lMembers);
        end;
        lMembers.Add(lMember);
      end;

    for i := 0 to High(aLines) do
    begin
      lRawLine := aLines[i];
      lLine := InventoryCleanLine(lRawLine);
      if lLine = '' then
        Continue;
      lTopLevelLine := InventoryIsTopLevelLine(lRawLine);
      if lTopLevelLine and SameText(lLine, 'type') then
      begin
        lInType := True;
        Continue;
      end;
      if lTopLevelLine and (SameText(lLine, 'const') or SameText(lLine, 'var') or
        SameText(lLine, 'threadvar') or SameText(lLine, 'implementation')) then
      begin
        lInType := False;
        if SameText(lLine, 'implementation') then
        begin
          lInImplementation := True;
          Continue;
        end;
      end;
      if lInImplementation and lTopLevelLine and InventoryIsRoutineStart(lLine) then
        lInType := False;
      if lInType then
        Continue;

      if (not lTopLevelLine) and (not InventoryIsRoutineStart(lLine)) then
        Continue;
      lSignature := InventoryCollectDeclarationText(aLines, i, lEndLine);
      if not InventoryTryRoutineName(lSignature, lRoutineName) then
        Continue;

      lSymbol := Default(TDelphiSemanticInventorySymbol);
      lSymbol.Name := lRoutineName;
      lSymbol.SymbolClass := 'routine';
      lSymbol.Kind := 'routine';
      lSymbol.UnitName := aUnitName;
      lSymbol.FileName := aFileName;
      lSymbol.Line := i + 1;
      lSymbol.EndLine := InventoryFindRoutineEndLine(aLines, i);
      if lSymbol.EndLine = 0 then
        Continue;
      lSymbol.Column := InventoryFindColumn(aLines[i], lRoutineName);
      lSymbol.EndColumn := lSymbol.Column + Length(lRoutineName);
      AddInventorySymbol(aSymbols, lSymbol);
      ParseDakInventoryParams(aSymbols, aLines, i, lSignature, lRoutineName, aUnitName,
        aFileName);
      ParseDakInventoryLocals(aSymbols, aLines, i + 1, lRoutineName, aUnitName, aFileName);

      if InventoryTryRoutineOwner(lRoutineName, lOwnerType) and
        lMembersByOwner.TryGetValue(lOwnerType, lMembers) then
      begin
        for lMember in lMembers do
        begin
          lMemberCopy := lMember;
          lMemberCopy.SymbolClass := 'current-class-member';
          lMemberCopy.Kind := 'current-class-member';
          lMemberCopy.RoutineName := lRoutineName;
          AddInventorySymbol(aSymbols, lMemberCopy);
        end;
      end;
    end;
  finally
    for lMembers in lMembersByOwner.Values do
      lMembers.Free;
    lMembersByOwner.Free;
  end;
end;

function InventorySourceTextLines(const aSourceText: string): TArray<string>;
var
  lLines: TStringList;
  i: Integer;
begin
  lLines := TStringList.Create;
  try
    lLines.Text := aSourceText;
    SetLength(Result, lLines.Count);
    for i := 0 to lLines.Count - 1 do
      Result[i] := lLines[i];
  finally
    lLines.Free;
  end;
end;

procedure AddModelSourceCompatibilitySymbols(
  const aModel: TDelphiSemanticUnitModel; const aSymbols: TList<TDelphiSemanticInventorySymbol>);
var
  lLines: TArray<string>;
begin
  lLines := InventorySourceTextLines(aModel.SourceText);
  ParseDakInventoryTypeMembers(aSymbols, lLines, aModel.UnitName, aModel.FileName);
  ParseDakInventoryUnitGlobals(aSymbols, lLines, aModel.UnitName, aModel.FileName);
  ParseDakInventoryRoutines(aSymbols, lLines, aModel.UnitName, aModel.FileName);
end;

procedure AddDakCompatibleInventorySymbols(const aModel: TDelphiSemanticUnitModel;
  const aSymbols: TList<TDelphiSemanticInventorySymbol>);
begin
  AddDakInventorySymbol(aSymbols, aModel.UnitName, '', '', '', aModel.UnitName, aModel.FileName,
    1, aModel.UnitName, 'unit');
  AddModelSourceCompatibilitySymbols(aModel, aSymbols);
end;

function InventorySameSymbol(const aLeft, aRight: TDelphiSemanticInventorySymbol): Boolean;
begin
  Result := SameText(aLeft.SymbolClass, aRight.SymbolClass) and SameText(aLeft.Name, aRight.Name) and
    SameText(aLeft.TypeName, aRight.TypeName) and SameText(aLeft.Modifier, aRight.Modifier) and
    SameText(aLeft.OwnerType, aRight.OwnerType) and SameText(aLeft.SourceOwnerType, aRight.SourceOwnerType) and
    SameText(aLeft.RelatedTypeName, aRight.RelatedTypeName) and
    SameText(aLeft.RoutineName, aRight.RoutineName) and SameText(aLeft.UnitName, aRight.UnitName) and
    SameText(aLeft.FileName, aRight.FileName) and (aLeft.Line = aRight.Line) and
    (aLeft.Column = aRight.Column) and SameText(aLeft.UnsupportedReason, aRight.UnsupportedReason) and
    (aLeft.IsHelper = aRight.IsHelper) and (aLeft.IsOverride = aRight.IsOverride) and
    (aLeft.IsDefault = aRight.IsDefault) and SameText(aLeft.TypeCategory, aRight.TypeCategory);
end;

function InventorySymbolKey(const aSymbol: TDelphiSemanticInventorySymbol): string;
const
  cSeparator = #31;
begin
  Result := aSymbol.SymbolClass + cSeparator + aSymbol.Name + cSeparator +
    aSymbol.TypeName + cSeparator + aSymbol.Modifier + cSeparator +
    aSymbol.OwnerType + cSeparator + aSymbol.SourceOwnerType + cSeparator + aSymbol.RelatedTypeName +
    cSeparator + aSymbol.RoutineName + cSeparator + aSymbol.UnitName +
    cSeparator + aSymbol.FileName + cSeparator + IntToStr(aSymbol.Line) +
    cSeparator + IntToStr(aSymbol.Column) + cSeparator + aSymbol.UnsupportedReason +
    cSeparator + IntToStr(Ord(aSymbol.IsHelper)) + cSeparator +
    IntToStr(Ord(aSymbol.IsOverride)) + cSeparator + IntToStr(Ord(aSymbol.IsDefault)) +
    cSeparator + aSymbol.TypeCategory;
end;

function AddExpandedInventorySymbol(const aSymbols: TList<TDelphiSemanticInventorySymbol>;
  const aSymbol: TDelphiSemanticInventorySymbol): Boolean;
var
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  for lSymbol in aSymbols do
    if InventorySameSymbol(lSymbol, aSymbol) then
      Exit(False);

  aSymbols.Add(aSymbol);
  Result := True;
end;

function AddExpandedInventorySymbolWithKeys(const aSymbols: TList<TDelphiSemanticInventorySymbol>;
  const aKeys: TDictionary<string, Byte>; const aSymbol: TDelphiSemanticInventorySymbol): Boolean;
var
  lKey: string;
begin
  lKey := InventorySymbolKey(aSymbol);
  if aKeys.ContainsKey(lKey) then
    Exit(False);

  aKeys.Add(lKey, 1);
  aSymbols.Add(aSymbol);
  Result := True;
end;

function InventoryOwnMemberKey(const aOwnerType, aName: string): string;
const
  cSeparator = #31;
begin
  Result := aOwnerType + cSeparator + aName;
end;

function BuildInventoryOwnMemberKeys(const aSymbols: TList<TDelphiSemanticInventorySymbol>;
  const aSymbolCount: Integer): TDictionary<string, Byte>;
var
  i: Integer;
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  Result := TDictionary<string, Byte>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
  for i := 0 to aSymbolCount - 1 do
  begin
    lSymbol := aSymbols[i];
    if (lSymbol.OwnerType <> '') and (lSymbol.SourceOwnerType = '') and
      InventoryIsDirectMemberKind(lSymbol.SymbolClass) then
      Result.AddOrSetValue(InventoryOwnMemberKey(lSymbol.OwnerType, lSymbol.Name), 1);
  end;
end;

procedure AddRelatedInventoryMemberOwnerIndex(const aMembersByOwner: TDictionary<string,
  TList<TDelphiSemanticInventorySymbol>>; const aOwnerType: string;
  const aSymbol: TDelphiSemanticInventorySymbol);
var
  lMembers: TList<TDelphiSemanticInventorySymbol>;
begin
  if aOwnerType = '' then
    Exit;

  if not aMembersByOwner.TryGetValue(aOwnerType, lMembers) then
  begin
    lMembers := TList<TDelphiSemanticInventorySymbol>.Create;
    aMembersByOwner.Add(aOwnerType, lMembers);
  end;
  lMembers.Add(aSymbol);
end;

procedure QueueRelatedInventoryOwner(const aPendingOwners: TQueue<string>;
  const aQueuedOwners: TDictionary<string, Byte>; const aOwnerType: string);
begin
  if aOwnerType = '' then
    Exit;
  if aQueuedOwners.ContainsKey(aOwnerType) then
    Exit;

  aQueuedOwners.Add(aOwnerType, 1);
  aPendingOwners.Enqueue(aOwnerType);
end;

procedure AddRelatedInventoryMemberRelation(const aRelationsByOwner: TDictionary<string,
  TList<TRelatedInventoryMemberRelation>>; const aRelation:
  TRelatedInventoryMemberRelation);
var
  lRelations: TList<TRelatedInventoryMemberRelation>;
begin
  if (aRelation.SourceOwnerType = '') or (aRelation.TargetOwnerType = '') then
    Exit;

  if not aRelationsByOwner.TryGetValue(aRelation.SourceOwnerType, lRelations) then
  begin
    lRelations := TList<TRelatedInventoryMemberRelation>.Create;
    aRelationsByOwner.Add(aRelation.SourceOwnerType, lRelations);
  end;
  lRelations.Add(aRelation);
end;

function BuildRelatedInventoryMemberRelations(const aSymbols:
  TList<TDelphiSemanticInventorySymbol>; const aSymbolCount: Integer): TDictionary<string,
  TList<TRelatedInventoryMemberRelation>>;
var
  i: Integer;
  lRelation: TRelatedInventoryMemberRelation;
  lTypeSymbol: TDelphiSemanticInventorySymbol;
begin
  Result := TDictionary<string, TList<TRelatedInventoryMemberRelation>>.Create(
    TFastCaseAwareComparer.OrdinalIgnoreCase);
  for i := 0 to aSymbolCount - 1 do
  begin
    lTypeSymbol := aSymbols[i];
    if (not SameText(lTypeSymbol.SymbolClass, 'type-member')) or
      (lTypeSymbol.RelatedTypeName = '') or (lTypeSymbol.UnsupportedReason <> '') then
      Continue;

    lRelation := Default(TRelatedInventoryMemberRelation);
    lRelation.IsHelper := lTypeSymbol.IsHelper;
    if lTypeSymbol.IsHelper then
    begin
      lRelation.SourceOwnerType := lTypeSymbol.Name;
      lRelation.TargetOwnerType := lTypeSymbol.RelatedTypeName;
    end else
    begin
      lRelation.SourceOwnerType := lTypeSymbol.RelatedTypeName;
      lRelation.TargetOwnerType := lTypeSymbol.Name;
    end;
    AddRelatedInventoryMemberRelation(Result, lRelation);
  end;
end;

procedure AddRelatedInventoryMemberSymbols(const aSymbols: TList<TDelphiSemanticInventorySymbol>;
  const aKeys: TDictionary<string, Byte>);
var
  i: Integer;
  lMember: TDelphiSemanticInventorySymbol;
  lMemberCount: Integer;
  lMemberPair: TPair<string, TList<TDelphiSemanticInventorySymbol>>;
  lMembers: TList<TDelphiSemanticInventorySymbol>;
  lMembersByOwner: TDictionary<string, TList<TDelphiSemanticInventorySymbol>>;
  lMemberSourceOwnerType: string;
  lOwnMemberKeys: TDictionary<string, Byte>;
  lPendingOwners: TQueue<string>;
  lQueuedOwners: TDictionary<string, Byte>;
  lRelation: TRelatedInventoryMemberRelation;
  lRelationPair: TPair<string, TList<TRelatedInventoryMemberRelation>>;
  lRelations: TList<TRelatedInventoryMemberRelation>;
  lRelationsByOwner: TDictionary<string, TList<TRelatedInventoryMemberRelation>>;
  lSourceOwnerType: string;
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  lMembersByOwner := TDictionary<string, TList<TDelphiSemanticInventorySymbol>>.Create(
    TFastCaseAwareComparer.OrdinalIgnoreCase);
  lOwnMemberKeys := BuildInventoryOwnMemberKeys(aSymbols, aSymbols.Count);
  lPendingOwners := TQueue<string>.Create;
  lQueuedOwners := TDictionary<string, Byte>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
  lRelationsByOwner := BuildRelatedInventoryMemberRelations(aSymbols, aSymbols.Count);
  try
    for i := 0 to aSymbols.Count - 1 do
    begin
      lMember := aSymbols[i];
      if (lMember.RoutineName <> '') or (not InventoryIsDirectMemberKind(lMember.SymbolClass)) then
        Continue;
      AddRelatedInventoryMemberOwnerIndex(lMembersByOwner, lMember.OwnerType, lMember);
    end;

    for lRelationPair in lRelationsByOwner do
      if lMembersByOwner.ContainsKey(lRelationPair.Key) then
        QueueRelatedInventoryOwner(lPendingOwners, lQueuedOwners, lRelationPair.Key);

    while lPendingOwners.Count > 0 do
    begin
      lSourceOwnerType := lPendingOwners.Dequeue;
      lQueuedOwners.Remove(lSourceOwnerType);
      if not lRelationsByOwner.TryGetValue(lSourceOwnerType, lRelations) then
        Continue;
      if not lMembersByOwner.TryGetValue(lSourceOwnerType, lMembers) then
        Continue;

      lMemberCount := lMembers.Count;
      for lRelation in lRelations do
        for i := 0 to lMemberCount - 1 do
        begin
          lMember := lMembers[i];
          lSymbol := lMember;
          lSymbol.OwnerName := lRelation.TargetOwnerType;
          lSymbol.OwnerType := lRelation.TargetOwnerType;
          if lRelation.IsHelper then
            lSymbol.SourceOwnerType := lRelation.SourceOwnerType
          else
          begin
            lMemberSourceOwnerType := lMember.SourceOwnerType;
            if lMemberSourceOwnerType = '' then
              lMemberSourceOwnerType := lMember.OwnerType;
            lSymbol.SourceOwnerType := lMemberSourceOwnerType;
          end;

          if lOwnMemberKeys.ContainsKey(InventoryOwnMemberKey(lSymbol.OwnerType,
            lSymbol.Name)) then
            Continue;
          if AddExpandedInventorySymbolWithKeys(aSymbols, aKeys, lSymbol) then
          begin
            AddRelatedInventoryMemberOwnerIndex(lMembersByOwner, lSymbol.OwnerType, lSymbol);
            QueueRelatedInventoryOwner(lPendingOwners, lQueuedOwners, lSymbol.OwnerType);
          end;
        end;
    end;
  finally
    for lRelationPair in lRelationsByOwner do
      lRelationPair.Value.Free;
    for lMemberPair in lMembersByOwner do
      lMemberPair.Value.Free;
    lRelationsByOwner.Free;
    lQueuedOwners.Free;
    lPendingOwners.Free;
    lOwnMemberKeys.Free;
    lMembersByOwner.Free;
  end;
end;

procedure AddRelatedInventoryCurrentClassSymbols(const aSymbols: TList<TDelphiSemanticInventorySymbol>;
  const aKeys: TDictionary<string, Byte>);
var
  i: Integer;
  lCurrentMember: TDelphiSemanticInventorySymbol;
  lMember: TDelphiSemanticInventorySymbol;
  lMembers: TList<TDelphiSemanticInventorySymbol>;
  lMembersByOwner: TDictionary<string, TList<TDelphiSemanticInventorySymbol>>;
  lOwnerKey: string;
  lPair: TPair<string, TList<TDelphiSemanticInventorySymbol>>;
  lProjectedContextKey: string;
  lProjectedContextKeys: TDictionary<string, Byte>;
  lSymbol: TDelphiSemanticInventorySymbol;
  lSymbolCount: Integer;
begin
  lSymbolCount := aSymbols.Count;
  lMembersByOwner := TDictionary<string, TList<TDelphiSemanticInventorySymbol>>.Create(
    TFastCaseAwareComparer.OrdinalIgnoreCase);
  lProjectedContextKeys := TDictionary<string, Byte>.Create(
    TFastCaseAwareComparer.OrdinalIgnoreCase);
  try
    for i := 0 to lSymbolCount - 1 do
    begin
      lMember := aSymbols[i];
      if (lMember.OwnerType = '') or (lMember.RoutineName <> '') or
        (not InventoryIsDirectMemberKind(lMember.SymbolClass)) then
        Continue;
      lOwnerKey := lMember.UnitName + #31 + lMember.FileName + #31 +
        lMember.OwnerType;
      if not lMembersByOwner.TryGetValue(lOwnerKey, lMembers) then
      begin
        lMembers := TList<TDelphiSemanticInventorySymbol>.Create;
        lMembersByOwner.Add(lOwnerKey, lMembers);
      end;
      lMembers.Add(lMember);
    end;

    for i := 0 to lSymbolCount - 1 do
    begin
      lCurrentMember := aSymbols[i];
      if (not SameText(lCurrentMember.SymbolClass, 'current-class-member')) or
        (lCurrentMember.OwnerType = '') or (lCurrentMember.RoutineName = '') then
        Continue;
      lOwnerKey := lCurrentMember.UnitName + #31 + lCurrentMember.FileName +
        #31 + lCurrentMember.OwnerType;
      lProjectedContextKey := lOwnerKey + #31 + lCurrentMember.RoutineName;
      if lProjectedContextKeys.ContainsKey(lProjectedContextKey) then
        Continue;
      lProjectedContextKeys.Add(lProjectedContextKey, 1);
      if not lMembersByOwner.TryGetValue(lOwnerKey, lMembers) then
        Continue;

      for lMember in lMembers do
      begin
        lSymbol := lMember;
        lSymbol.SymbolClass := 'current-class-member';
        lSymbol.Kind := 'current-class-member';
        lSymbol.RoutineName := lCurrentMember.RoutineName;
        AddExpandedInventorySymbolWithKeys(aSymbols, aKeys, lSymbol);
      end;
    end;
  finally
    for lPair in lMembersByOwner do
      lPair.Value.Free;
    lProjectedContextKeys.Free;
    lMembersByOwner.Free;
  end;
end;

procedure AddExpandedExternalTypeSymbol(const aSymbols: TList<TDelphiSemanticInventorySymbol>;
  const aKeys, aSourceTypes, aExternalTypes: TDictionary<string, Byte>;
  const aTypeName: string);
var
  lSymbol: TDelphiSemanticInventorySymbol;
  lTypeName: string;
begin
  lTypeName := InventorySimpleTypeName(aTypeName);
  if (lTypeName = '') or InventoryIsBuiltInTypeName(lTypeName) then
    Exit;
  if aSourceTypes.ContainsKey(lTypeName) or aExternalTypes.ContainsKey(lTypeName) then
    Exit;

  aExternalTypes.Add(lTypeName, 1);
  lSymbol := Default(TDelphiSemanticInventorySymbol);
  lSymbol.Name := lTypeName;
  lSymbol.SymbolClass := 'external';
  lSymbol.Kind := 'external';
  lSymbol.TypeName := lTypeName;
  AddExpandedInventorySymbolWithKeys(aSymbols, aKeys, lSymbol);
end;

procedure AddExpandedExternalTypeSymbols(const aSymbols: TList<TDelphiSemanticInventorySymbol>;
  const aKeys: TDictionary<string, Byte>);
var
  i: Integer;
  lExternalTypes: TDictionary<string, Byte>;
  lSourceTypes: TDictionary<string, Byte>;
  lSymbol: TDelphiSemanticInventorySymbol;
  lSymbolCount: Integer;
begin
  lSourceTypes := TDictionary<string, Byte>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
  try
    lExternalTypes := TDictionary<string, Byte>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
    try
      for lSymbol in aSymbols do
      begin
        if SameText(lSymbol.SymbolClass, 'type-member') then
          lSourceTypes.AddOrSetValue(lSymbol.Name, 1)
        else if SameText(lSymbol.SymbolClass, 'external') and (lSymbol.TypeName <> '') then
          lExternalTypes.AddOrSetValue(lSymbol.Name, 1);
      end;

      lSymbolCount := aSymbols.Count;
      for i := 0 to lSymbolCount - 1 do
      begin
        lSymbol := aSymbols[i];
        AddExpandedExternalTypeSymbol(aSymbols, aKeys, lSourceTypes, lExternalTypes,
          lSymbol.TypeName);
        AddExpandedExternalTypeSymbol(aSymbols, aKeys, lSourceTypes, lExternalTypes,
          lSymbol.RelatedTypeName);
      end;
    finally
      lExternalTypes.Free;
    end;
  finally
    lSourceTypes.Free;
  end;
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

  Result := TDelphiSemanticResolver.ResolveName(aModel, aContext, aName);
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

function CombinedSelectors(const aModel: TDelphiSemanticUnitModel;
  const aProjectModels: TArray<TDelphiSemanticUnitModel>;
  const aStatements: TArray<TDelphiSemanticWithStatement>; const aStatementIndex: Integer;
  const aRoutineName, aCurrentTypeName: string;
  const aParentRoutineNames: TArray<string>;
  const aProjectMemberIndex: TWithBindingProjectMemberIndex;
  const aMemberCache: TDictionary<string, TDelphiSemanticResolveResult>):
  TArray<TDelphiSemanticWithSelectorBinding>;
var
  i: Integer;
  lSelector: TDelphiSemanticWithSelectorBinding;
  lSelectors: TList<TDelphiSemanticWithSelectorBinding>;
begin
  lSelectors := TList<TDelphiSemanticWithSelectorBinding>.Create;
  try
    for i := 0 to Pred(aStatementIndex) do
      if StatementContains(aStatements[i], aStatements[aStatementIndex]) then
        for lSelector in BindSelectors(aModel, aProjectModels, aRoutineName,
          aCurrentTypeName, aStatements[i].SelectorText, aParentRoutineNames,
          aProjectMemberIndex, aMemberCache) do
          lSelectors.Add(lSelector);
    for lSelector in BindSelectors(aModel, aProjectModels, aRoutineName,
      aCurrentTypeName, aStatements[aStatementIndex].SelectorText, aParentRoutineNames,
      aProjectMemberIndex, aMemberCache) do
      lSelectors.Add(lSelector);
    Result := lSelectors.ToArray;
  finally
    lSelectors.Free;
  end;
end;

class function TDelphiSemanticWithBinder.BindModel(const aModel: TDelphiSemanticUnitModel):
  TArray<TDelphiSemanticWithBinding>;
begin
  Result := BindProject('', nil, [aModel]).Bindings;
end;

function BuildInventorySymbols(const aModel: TDelphiSemanticUnitModel):
  TArray<TDelphiSemanticInventorySymbol>; forward;

function CompilerProfileCompatibilitySourceKind(
  const aIntrinsic: TDelphiSemanticIntrinsicSymbol): string;
begin
  if SameText(aIntrinsic.OwnerName, 'rtl') or
    SameText(aIntrinsic.Kind, 'intrinsic-field') or
    SameText(aIntrinsic.Kind, 'intrinsic-property') then
    Result := 'rtl-source'
  else
    Result := 'compiler-intrinsic';
end;

function CompilerProfileCompatibilityTypeCategory(
  const aIntrinsic: TDelphiSemanticIntrinsicSymbol): string;
begin
  if SameText(aIntrinsic.TypeName, 'record') then
    Result := 'record'
  else if SameText(aIntrinsic.TypeName, 'class') then
    Result := 'class'
  else if SameText(aIntrinsic.TypeName, 'Pointer') or StartsText('^', aIntrinsic.TypeName) then
    Result := 'pointer'
  else if MatchText(aIntrinsic.Name, ['Boolean', 'Byte', 'Char', 'Integer', 'Int32',
    'NativeInt', 'NativeUInt']) then
    Result := 'ordinal'
  else
    Result := '';
end;

procedure AddCompilerProfileCompatibilitySymbol(
  const aSymbols: TList<TDelphiSemanticInventorySymbol>;
  const aIntrinsic: TDelphiSemanticIntrinsicSymbol);
var
  lSymbol: TDelphiSemanticInventorySymbol;
  lSourceKind: string;
begin
  lSourceKind := CompilerProfileCompatibilitySourceKind(aIntrinsic);
  lSymbol := Default(TDelphiSemanticInventorySymbol);
  lSymbol.Name := aIntrinsic.Name;
  lSymbol.TypeName := aIntrinsic.TypeName;
  lSymbol.SourceOwnerType := lSourceKind;
  lSymbol.UnitName := lSourceKind;
  lSymbol.TypeCategory := CompilerProfileCompatibilityTypeCategory(aIntrinsic);
  if SameText(aIntrinsic.Kind, 'intrinsic-routine') then
  begin
    lSymbol.SymbolClass := 'routine';
    lSymbol.Kind := 'routine';
  end else if SameText(aIntrinsic.Kind, 'intrinsic-unit') then
  begin
    lSymbol.SymbolClass := 'unit';
    lSymbol.Kind := 'unit';
  end else if SameText(aIntrinsic.Kind, 'intrinsic-type') then
  begin
    if SameText(lSourceKind, 'rtl-source') then
    begin
      lSymbol.SymbolClass := 'type-member';
      lSymbol.Kind := 'type-member';
    end else
    begin
      lSymbol.SymbolClass := 'type';
      lSymbol.Kind := 'type';
    end;
  end else if SameText(aIntrinsic.Kind, 'intrinsic-field') then
  begin
    lSymbol.SymbolClass := 'field';
    lSymbol.Kind := 'field';
    lSymbol.OwnerName := aIntrinsic.OwnerName;
    lSymbol.OwnerType := aIntrinsic.OwnerName;
  end else if SameText(aIntrinsic.Kind, 'intrinsic-property') then
  begin
    lSymbol.SymbolClass := 'property';
    lSymbol.Kind := 'property';
    lSymbol.OwnerName := aIntrinsic.OwnerName;
    lSymbol.OwnerType := aIntrinsic.OwnerName;
  end else
    Exit;
  AddInventorySymbol(aSymbols, lSymbol);
end;

procedure AddCompilerProfileCompatibilitySymbols(
  const aSymbols: TList<TDelphiSemanticInventorySymbol>);
var
  lIntrinsic: TDelphiSemanticIntrinsicSymbol;
  lProfile: TDelphiSemanticCompilerProfile;
begin
  lProfile := TDelphiSemanticCompilerProfileBuilder.DefaultProfile('with-binding-compatibility');
  for lIntrinsic in lProfile.IntrinsicSymbols do
    AddCompilerProfileCompatibilitySymbol(aSymbols, lIntrinsic);
end;

procedure AddProjectExternalUsesUnits(const aSymbols: TList<TDelphiSemanticInventorySymbol>;
  const aExistingUnits, aExternalUnits: TDictionary<string, Byte>; const aUnits: TArray<string>;
  const aSourceUnitName, aFileName: string);
var
  lSymbol: TDelphiSemanticInventorySymbol;
  lUnitKey: string;
  lUnitName: string;
  lUsedUnit: string;
begin
  for lUsedUnit in aUnits do
  begin
    lUnitName := Trim(lUsedUnit);
    if lUnitName = '' then
      Continue;

    lUnitKey := aFileName + '|' + lUnitName;
    if aExistingUnits.ContainsKey(lUnitName) or aExternalUnits.ContainsKey(lUnitKey) then
      Continue;

    aExternalUnits.Add(lUnitKey, 1);
    lSymbol := Default(TDelphiSemanticInventorySymbol);
    lSymbol.Name := lUnitName;
    lSymbol.SymbolClass := 'external';
    lSymbol.Kind := 'external';
    lSymbol.UnitName := aSourceUnitName;
    lSymbol.FileName := aFileName;
    AddInventorySymbol(aSymbols, lSymbol);
  end;
end;

procedure AddProjectExternalUnitSymbols(const aModels: TArray<TDelphiSemanticUnitModel>;
  const aSymbols: TList<TDelphiSemanticInventorySymbol>);
var
  lExistingUnits: TDictionary<string, Byte>;
  lExternalUnits: TDictionary<string, Byte>;
  lModel: TDelphiSemanticUnitModel;
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  lExistingUnits := TDictionary<string, Byte>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
  try
    lExternalUnits := TDictionary<string, Byte>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
    try
      for lSymbol in aSymbols do
      begin
        if SameText(lSymbol.SymbolClass, 'unit') then
          lExistingUnits.AddOrSetValue(lSymbol.Name, 1)
        else if SameText(lSymbol.SymbolClass, 'external') then
          lExternalUnits.AddOrSetValue(lSymbol.FileName + '|' + lSymbol.Name, 1);
      end;

      for lModel in aModels do
      begin
        AddProjectExternalUsesUnits(aSymbols, lExistingUnits, lExternalUnits,
          lModel.InterfaceUses, lModel.UnitName, lModel.FileName);
        AddProjectExternalUsesUnits(aSymbols, lExistingUnits, lExternalUnits,
          lModel.ImplementationUses, lModel.UnitName, lModel.FileName);
      end;
    finally
      lExternalUnits.Free;
    end;
  finally
    lExistingUnits.Free;
  end;
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
      for lSymbol in BuildInventorySymbols(lModel) do
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
        lSubphaseStopwatch := TStopwatch.StartNew;
        lBinding.Selectors := CombinedSelectors(lModel, aModels, lModel.WithStatements, i,
          lRoutineLookupName, lCurrentTypeName, lParentRoutineNames, lProjectMemberIndex,
          lMemberCache);
        lSubphaseStopwatch.Stop;
        Inc(lSelectorBindingMs, lSubphaseStopwatch.ElapsedMilliseconds);
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
    AddCompilerProfileCompatibilitySymbols(lSymbols);
    AddProjectExternalUnitSymbols(aModels, lSymbols);
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
var
  lKeys: TDictionary<string, Byte>;
  lSymbol: TDelphiSemanticInventorySymbol;
  lSymbols: TList<TDelphiSemanticInventorySymbol>;
begin
  lKeys := TDictionary<string, Byte>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
  lSymbols := TList<TDelphiSemanticInventorySymbol>.Create;
  try
    for lSymbol in aSymbols do
      AddExpandedInventorySymbolWithKeys(lSymbols, lKeys, lSymbol);
    AddRelatedInventoryMemberSymbols(lSymbols, lKeys);
    AddRelatedInventoryCurrentClassSymbols(lSymbols, lKeys);
    AddExpandedExternalTypeSymbols(lSymbols, lKeys);
    Result := lSymbols.ToArray;
  finally
    lSymbols.Free;
    lKeys.Free;
  end;
end;

function BuildInventorySymbols(const aModel: TDelphiSemanticUnitModel):
  TArray<TDelphiSemanticInventorySymbol>;
var
  lDeclaration: TDelphiSemanticDeclaration;
  lLocal: TDelphiSemanticLocal;
  lMember: TDelphiSemanticMember;
  lParameter: TDelphiSemanticParameter;
  lRoutine: TDelphiSemanticRoutine;
  lSymbol: TDelphiSemanticInventorySymbol;
  lSymbolCapacity: Integer;
  lSymbols: TList<TDelphiSemanticInventorySymbol>;
begin
  lSymbols := TList<TDelphiSemanticInventorySymbol>.Create;
  try
    lSymbolCapacity := 1 + Length(aModel.Declarations) + Length(aModel.Members) +
      Length(aModel.Routines) + Length(aModel.Locals);
    for lRoutine in aModel.Routines do
      Inc(lSymbolCapacity, Length(lRoutine.Parameters));
    lSymbols.Capacity := lSymbolCapacity;

    lSymbol := Default(TDelphiSemanticInventorySymbol);
    lSymbol.Name := aModel.UnitName;
    lSymbol.SymbolClass := 'unit';
    lSymbol.Kind := 'unit';
    lSymbol.UnitName := aModel.UnitName;
    lSymbol.FileName := aModel.FileName;
    lSymbol.Line := 1;
    lSymbol.Column := 1;
    AddInventorySymbol(lSymbols, lSymbol);

    for lDeclaration in aModel.Declarations do
    begin
      lSymbol := Default(TDelphiSemanticInventorySymbol);
      lSymbol.Name := lDeclaration.Name;
      lSymbol.SymbolClass := 'declaration';
      lSymbol.Kind := lDeclaration.Kind;
      lSymbol.TypeName := lDeclaration.TypeName;
      lSymbol.OwnerName := aModel.UnitName;
      lSymbol.OwnerType := aModel.UnitName;
      lSymbol.RelatedTypeName := lDeclaration.BaseTypeName;
      if SameText(lDeclaration.Kind, 'type-alias') then
        lSymbol.RelatedTypeName := lDeclaration.TypeName;
      lSymbol.IsHelper := lDeclaration.HelperTargetName <> '';
      if lSymbol.IsHelper then
        lSymbol.RelatedTypeName := lDeclaration.HelperTargetName;
      if SameText(lDeclaration.TypeName, 'record') or SameText(lDeclaration.TypeName, 'class') or
        SameText(lDeclaration.TypeName, 'interface') then
        lSymbol.TypeCategory := lDeclaration.TypeName;
      lSymbol.UnitName := aModel.UnitName;
      lSymbol.FileName := aModel.FileName;
      lSymbol.SectionKind := lDeclaration.SectionKind;
      lSymbol.Line := lDeclaration.Line;
      lSymbol.Column := lDeclaration.Column;
      lSymbol.EndLine := lDeclaration.Line;
      lSymbol.EndColumn := lDeclaration.Column;
      AddInventorySymbol(lSymbols, lSymbol);
    end;

    for lMember in aModel.Members do
    begin
      lSymbol := Default(TDelphiSemanticInventorySymbol);
      lSymbol.Name := lMember.Name;
      lSymbol.SymbolClass := 'member';
      lSymbol.Kind := lMember.Kind;
      lSymbol.TypeName := lMember.TypeName;
      lSymbol.OwnerName := lMember.OwnerName;
      lSymbol.OwnerType := lMember.OwnerName;
      lSymbol.UnitName := aModel.UnitName;
      lSymbol.FileName := aModel.FileName;
      lSymbol.Line := lMember.Line;
      lSymbol.Column := lMember.Column;
      lSymbol.EndLine := lMember.Line;
      lSymbol.EndColumn := lMember.Column;
      lSymbol.IsDefault := lMember.IsDefault;
      lSymbol.IsIndexed := lMember.IsIndexed;
      if lMember.IsIndexed then
        lSymbol.IndexParameterCount := 1;
      AddInventorySymbol(lSymbols, lSymbol);
    end;

    for lRoutine in aModel.Routines do
    begin
      lSymbol := Default(TDelphiSemanticInventorySymbol);
      lSymbol.Name := lRoutine.Name;
      lSymbol.SymbolClass := 'routine';
      lSymbol.Kind := 'routine';
      lSymbol.TypeName := lRoutine.ReturnType;
      lSymbol.OwnerName := lRoutine.OwnerName;
      lSymbol.OwnerType := lRoutine.OwnerName;
      lSymbol.UnitName := aModel.UnitName;
      lSymbol.FileName := aModel.FileName;
      lSymbol.SectionKind := lRoutine.SectionKind;
      lSymbol.Line := lRoutine.Line;
      lSymbol.Column := lRoutine.Column;
      lSymbol.EndLine := lRoutine.Line;
      lSymbol.EndColumn := lRoutine.Column;
      AddInventorySymbol(lSymbols, lSymbol);

      for lParameter in lRoutine.Parameters do
      begin
        lSymbol := Default(TDelphiSemanticInventorySymbol);
        lSymbol.Name := lParameter.Name;
        lSymbol.SymbolClass := 'parameter';
        lSymbol.Kind := 'parameter';
        lSymbol.TypeName := lParameter.TypeName;
        lSymbol.Modifier := lParameter.Modifier;
        if lRoutine.OwnerName <> '' then
          lSymbol.RoutineName := lRoutine.OwnerName + '.' + lParameter.RoutineName
        else
          lSymbol.RoutineName := lParameter.RoutineName;
        lSymbol.UnitName := aModel.UnitName;
        lSymbol.FileName := aModel.FileName;
        lSymbol.Line := lParameter.Line;
        lSymbol.Column := lParameter.Column;
        lSymbol.EndLine := lParameter.Line;
        lSymbol.EndColumn := lParameter.Column;
        AddInventorySymbol(lSymbols, lSymbol);
      end;
    end;

    for lLocal in aModel.Locals do
    begin
      lSymbol := Default(TDelphiSemanticInventorySymbol);
      lSymbol.Name := lLocal.Name;
      lSymbol.SymbolClass := 'local';
      lSymbol.Kind := lLocal.Kind;
      lSymbol.TypeName := lLocal.TypeName;
      lSymbol.RoutineName := lLocal.RoutineName;
      lSymbol.UnitName := aModel.UnitName;
      lSymbol.FileName := aModel.FileName;
      lSymbol.Line := lLocal.Line;
      lSymbol.Column := lLocal.Column;
      lSymbol.EndLine := lLocal.Line;
      lSymbol.EndColumn := lLocal.Column;
      AddInventorySymbol(lSymbols, lSymbol);
    end;

    AddDakCompatibleInventorySymbols(aModel, lSymbols);
    Result := lSymbols.ToArray;
  finally
    lSymbols.Free;
  end;
end;

class function TDelphiSemanticWithBinder.BuildInventory(
  const aModel: TDelphiSemanticUnitModel): TDelphiSemanticRemoveWithInventory;
begin
  Result := Default(TDelphiSemanticRemoveWithInventory);
  Result.FileName := aModel.FileName;
  Result.UnitName := aModel.UnitName;
  Result.Symbols := BuildInventorySymbols(aModel);

  Result.Bindings := BindModel(aModel);
end;

end.
