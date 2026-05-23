unit DelphiSemantics.Index;

interface

uses
  DelphiSemantics.Model, DelphiSemantics.Query, DelphiSemantics.Symbols;

type
  IDelphiSemanticProjectSymbolIndexData = interface
    ['{64A8F9E0-E098-47D3-9029-A6710E8F16AC}']
    function FindSymbolById(const aId: TDelphiSemanticSymbolId; out aSymbol:
      TDelphiSemanticIndexedSymbol): Boolean;
    function FindSymbolsByName(const aName: string): TArray<TDelphiSemanticIndexedSymbol>;
    function FindTopLevelSymbolsByName(const aName: string): TArray<TDelphiSemanticIndexedSymbol>;
    function FindLocalSymbolsByRoutineAndName(const aRoutineName, aName: string):
      TArray<TDelphiSemanticIndexedSymbol>;
    function FindLocalSymbolsByRoutineIdAndName(const aRoutineId: TDelphiSemanticSymbolId;
      const aName: string): TArray<TDelphiSemanticIndexedSymbol>;
    function FindMembersByOwnerAndName(const aOwnerName, aName: string):
      TArray<TDelphiSemanticIndexedSymbol>;
    function FindReferencesByName(const aName: string): TArray<TDelphiSemanticIndexedReference>;
    function FindReferencesBySymbolId(const aId: TDelphiSemanticSymbolId):
      TArray<TDelphiSemanticIndexedReference>;
    function FindVisibleUnitScopes(const aUnitName, aSectionKind: string):
      TArray<TDelphiSemanticUnitModel>;
    function FindUnitModelByName(const aName: string; out aModel:
      TDelphiSemanticUnitModel): Boolean;
  end;

  TDelphiSemanticProjectSymbolIndex = record
  private
    fData: IDelphiSemanticProjectSymbolIndexData;
  public
    Symbols: TArray<TDelphiSemanticIndexedSymbol>;
    References: TArray<TDelphiSemanticIndexedReference>;
    function FindSymbolById(const aId: TDelphiSemanticSymbolId; out aSymbol:
      TDelphiSemanticIndexedSymbol): Boolean;
    function FindSymbolsByName(const aName: string): TArray<TDelphiSemanticIndexedSymbol>;
    function FindTopLevelSymbolsByName(const aName: string): TArray<TDelphiSemanticIndexedSymbol>;
    function FindLocalSymbolsByRoutineAndName(const aRoutineName, aName: string):
      TArray<TDelphiSemanticIndexedSymbol>;
    function FindLocalSymbolsByRoutineIdAndName(const aRoutineId: TDelphiSemanticSymbolId;
      const aName: string): TArray<TDelphiSemanticIndexedSymbol>;
    function FindMembersByOwnerAndName(const aOwnerName, aName: string):
      TArray<TDelphiSemanticIndexedSymbol>;
    function FindReferencesByName(const aName: string): TArray<TDelphiSemanticIndexedReference>;
    function FindReferencesBySymbolId(const aId: TDelphiSemanticSymbolId):
      TArray<TDelphiSemanticIndexedReference>;
    function FindVisibleUnitScopes(const aUnitName, aSectionKind: string):
      TArray<TDelphiSemanticUnitModel>;
    function FindUnitModelByName(const aName: string; out aModel:
      TDelphiSemanticUnitModel): Boolean;
  end;

  TDelphiSemanticProjectSymbolIndexer = record
  public
    class var BuildInvocationCount: Integer;
    class var ReferenceResolutionSymbolScanCount: Integer;
    class function Build(const aContext: TDelphiSemanticSymbolQueryContext):
      TDelphiSemanticProjectSymbolIndex; static;
    class procedure ResetBuildInvocationCount; static;
    class procedure ResetReferenceResolutionSymbolScanCount; static;
  end;

implementation

uses
  System.Generics.Collections, System.Generics.Defaults, System.StrUtils, System.SysUtils,
  MaxLogic.StrUtils;

type
  IDelphiSemanticMutableProjectSymbolIndexData = interface(IDelphiSemanticProjectSymbolIndexData)
    ['{3E7E4923-9F78-4129-BFA2-D2030CB49593}']
    procedure AddReferences(const aReferences: TArray<TDelphiSemanticIndexedReference>);
  end;

  TDelphiSemanticSymbolList = TList<TDelphiSemanticIndexedSymbol>;
  TDelphiSemanticIndexedSymbolList = TList<TDelphiSemanticIndexedSymbol>;
  TDelphiSemanticIndexedReferenceList = TList<TDelphiSemanticIndexedReference>;
  TDelphiSemanticUnitModelList = TList<TDelphiSemanticUnitModel>;

  TDelphiSemanticOwnerNameKey = record
    OwnerName: string;
    Name: string;
  end;

  TDelphiSemanticUnitSectionKey = record
    UnitName: string;
    SectionKind: string;
  end;

  TDelphiSemanticSymbolOriginKey = record
    UnitName: string;
    OwnerName: string;
    Name: string;
    Kind: string;
    Line: Integer;
    Column: Integer;
  end;

  TDelphiSemanticOwnerNameKeyComparer = class(TInterfacedObject,
    IEqualityComparer<TDelphiSemanticOwnerNameKey>)
  private
    fStringComparer: IEqualityComparer<string>;
  public
    constructor Create;
    function Equals(const aLeft, aRight: TDelphiSemanticOwnerNameKey): Boolean; reintroduce;
    function GetHashCode(const aValue: TDelphiSemanticOwnerNameKey): Integer; reintroduce;
  end;

  TDelphiSemanticUnitSectionKeyComparer = class(TInterfacedObject,
    IEqualityComparer<TDelphiSemanticUnitSectionKey>)
  private
    fStringComparer: IEqualityComparer<string>;
  public
    constructor Create;
    function Equals(const aLeft, aRight: TDelphiSemanticUnitSectionKey): Boolean; reintroduce;
    function GetHashCode(const aValue: TDelphiSemanticUnitSectionKey): Integer; reintroduce;
  end;

  TDelphiSemanticSymbolOriginKeyComparer = class(TInterfacedObject,
    IEqualityComparer<TDelphiSemanticSymbolOriginKey>)
  private
    fStringComparer: IEqualityComparer<string>;
  public
    constructor Create;
    function Equals(const aLeft, aRight: TDelphiSemanticSymbolOriginKey): Boolean; reintroduce;
    function GetHashCode(const aValue: TDelphiSemanticSymbolOriginKey): Integer; reintroduce;
  end;

  TDelphiSemanticSymbolOriginSet = TDictionary<TDelphiSemanticSymbolOriginKey, Boolean>;

  TDelphiSemanticProjectSymbolIndexData = class(TInterfacedObject,
    IDelphiSemanticProjectSymbolIndexData, IDelphiSemanticMutableProjectSymbolIndexData)
  private
    fMembersByOwnerAndName: TDictionary<TDelphiSemanticOwnerNameKey,
      TDelphiSemanticIndexedSymbolList>;
    fReferencesByName: TDictionary<string, TDelphiSemanticIndexedReferenceList>;
    fReferencesBySymbolId: TDictionary<string, TDelphiSemanticIndexedReferenceList>;
    fSymbolsById: TDictionary<string, TDelphiSemanticIndexedSymbol>;
    fSymbolsByName: TDictionary<string, TDelphiSemanticIndexedSymbolList>;
    fTopLevelSymbolsByName: TDictionary<string, TDelphiSemanticIndexedSymbolList>;
    fLocalSymbolsByRoutineAndName: TDictionary<TDelphiSemanticOwnerNameKey,
      TDelphiSemanticIndexedSymbolList>;
    fLocalSymbolsByRoutineIdAndName: TDictionary<TDelphiSemanticOwnerNameKey,
      TDelphiSemanticIndexedSymbolList>;
    fUnitModelsByName: TDictionary<string, TDelphiSemanticUnitModel>;
    fVisibleScopesByUnitAndSection: TDictionary<TDelphiSemanticUnitSectionKey,
      TDelphiSemanticUnitModelList>;
    class procedure AddReferenceToMap(const aMap: TDictionary<string,
      TDelphiSemanticIndexedReferenceList>; const aKey: string;
      const aReference: TDelphiSemanticIndexedReference); static;
    class procedure AddLocalOriginKeys(const aMap: TDelphiSemanticSymbolOriginSet;
      const aModel: TDelphiSemanticUnitModel); static;
    class procedure AddMemberOriginKeys(const aMap: TDelphiSemanticSymbolOriginSet;
      const aModel: TDelphiSemanticUnitModel); static;
    class procedure AddSymbolToCompositeMap(const aMap:
      TDictionary<TDelphiSemanticOwnerNameKey, TDelphiSemanticIndexedSymbolList>;
      const aOwnerName, aName: string; const aSymbol: TDelphiSemanticIndexedSymbol); static;
    procedure AddUsedVisibleScopes(const aUnitName, aSectionKind: string;
      const aUsedUnitNames: TArray<string>);
    procedure AddVisibleScopesForModel(const aModel: TDelphiSemanticUnitModel);
    procedure AddVisibleScope(const aUnitName, aSectionKind: string;
      const aModel: TDelphiSemanticUnitModel);
    class procedure AddSymbolToMap(const aMap: TDictionary<string,
      TDelphiSemanticIndexedSymbolList>; const aKey: string;
      const aSymbol: TDelphiSemanticIndexedSymbol); static;
  public
    constructor Create(const aContext: TDelphiSemanticSymbolQueryContext;
      const aSymbols: TArray<TDelphiSemanticIndexedSymbol>;
      const aReferences: TArray<TDelphiSemanticIndexedReference>);
    destructor Destroy; override;
    function FindSymbolById(const aId: TDelphiSemanticSymbolId; out aSymbol:
      TDelphiSemanticIndexedSymbol): Boolean;
    function FindSymbolsByName(const aName: string): TArray<TDelphiSemanticIndexedSymbol>;
    function FindTopLevelSymbolsByName(const aName: string): TArray<TDelphiSemanticIndexedSymbol>;
    function FindLocalSymbolsByRoutineAndName(const aRoutineName, aName: string):
      TArray<TDelphiSemanticIndexedSymbol>;
    function FindLocalSymbolsByRoutineIdAndName(const aRoutineId: TDelphiSemanticSymbolId;
      const aName: string): TArray<TDelphiSemanticIndexedSymbol>;
    function FindMembersByOwnerAndName(const aOwnerName, aName: string):
      TArray<TDelphiSemanticIndexedSymbol>;
    function FindReferencesByName(const aName: string): TArray<TDelphiSemanticIndexedReference>;
    function FindReferencesBySymbolId(const aId: TDelphiSemanticSymbolId):
      TArray<TDelphiSemanticIndexedReference>;
    function FindVisibleUnitScopes(const aUnitName, aSectionKind: string):
      TArray<TDelphiSemanticUnitModel>;
    function FindUnitModelByName(const aName: string; out aModel:
      TDelphiSemanticUnitModel): Boolean;
    procedure AddReferences(const aReferences: TArray<TDelphiSemanticIndexedReference>);
  end;

constructor TDelphiSemanticOwnerNameKeyComparer.Create;
begin
  inherited Create;
  fStringComparer := TFastCaseAwareComparer.OrdinalIgnoreCase;
end;

function TDelphiSemanticOwnerNameKeyComparer.Equals(
  const aLeft, aRight: TDelphiSemanticOwnerNameKey): Boolean;
begin
  Result := fStringComparer.Equals(aLeft.OwnerName, aRight.OwnerName) and
    fStringComparer.Equals(aLeft.Name, aRight.Name);
end;

function TDelphiSemanticOwnerNameKeyComparer.GetHashCode(
  const aValue: TDelphiSemanticOwnerNameKey): Integer;
begin
  Result := fStringComparer.GetHashCode(aValue.OwnerName) xor
    (fStringComparer.GetHashCode(aValue.Name) shl 1);
end;

constructor TDelphiSemanticUnitSectionKeyComparer.Create;
begin
  inherited Create;
  fStringComparer := TFastCaseAwareComparer.OrdinalIgnoreCase;
end;

function TDelphiSemanticUnitSectionKeyComparer.Equals(
  const aLeft, aRight: TDelphiSemanticUnitSectionKey): Boolean;
begin
  Result := fStringComparer.Equals(aLeft.UnitName, aRight.UnitName) and
    fStringComparer.Equals(aLeft.SectionKind, aRight.SectionKind);
end;

function TDelphiSemanticUnitSectionKeyComparer.GetHashCode(
  const aValue: TDelphiSemanticUnitSectionKey): Integer;
begin
  Result := fStringComparer.GetHashCode(aValue.UnitName) xor
    (fStringComparer.GetHashCode(aValue.SectionKind) shl 1);
end;

constructor TDelphiSemanticSymbolOriginKeyComparer.Create;
begin
  inherited Create;
  fStringComparer := TFastCaseAwareComparer.OrdinalIgnoreCase;
end;

function TDelphiSemanticSymbolOriginKeyComparer.Equals(
  const aLeft, aRight: TDelphiSemanticSymbolOriginKey): Boolean;
begin
  Result := fStringComparer.Equals(aLeft.UnitName, aRight.UnitName) and
    fStringComparer.Equals(aLeft.OwnerName, aRight.OwnerName) and
    fStringComparer.Equals(aLeft.Name, aRight.Name) and
    fStringComparer.Equals(aLeft.Kind, aRight.Kind) and (aLeft.Line = aRight.Line) and
    (aLeft.Column = aRight.Column);
end;

function TDelphiSemanticSymbolOriginKeyComparer.GetHashCode(
  const aValue: TDelphiSemanticSymbolOriginKey): Integer;
begin
  Result := fStringComparer.GetHashCode(aValue.UnitName) xor
    (fStringComparer.GetHashCode(aValue.OwnerName) shl 1) xor
    (fStringComparer.GetHashCode(aValue.Name) shl 2) xor
    (fStringComparer.GetHashCode(aValue.Kind) shl 3) xor
    (aValue.Line shl 4) xor aValue.Column;
end;

function TDelphiSemanticProjectSymbolIndex.FindSymbolById(
  const aId: TDelphiSemanticSymbolId; out aSymbol: TDelphiSemanticIndexedSymbol): Boolean;
begin
  if fData = nil then
  begin
    aSymbol := Default(TDelphiSemanticIndexedSymbol);
    Exit(False);
  end;

  Result := fData.FindSymbolById(aId, aSymbol);
end;

function TDelphiSemanticProjectSymbolIndex.FindSymbolsByName(
  const aName: string): TArray<TDelphiSemanticIndexedSymbol>;
begin
  if fData = nil then
    Exit(nil);

  Result := fData.FindSymbolsByName(aName);
end;

function TDelphiSemanticProjectSymbolIndex.FindTopLevelSymbolsByName(
  const aName: string): TArray<TDelphiSemanticIndexedSymbol>;
begin
  if fData = nil then
    Exit(nil);

  Result := fData.FindTopLevelSymbolsByName(aName);
end;

function TDelphiSemanticProjectSymbolIndex.FindLocalSymbolsByRoutineAndName(
  const aRoutineName, aName: string): TArray<TDelphiSemanticIndexedSymbol>;
begin
  if fData = nil then
    Exit(nil);

  Result := fData.FindLocalSymbolsByRoutineAndName(aRoutineName, aName);
end;

function TDelphiSemanticProjectSymbolIndex.FindLocalSymbolsByRoutineIdAndName(
  const aRoutineId: TDelphiSemanticSymbolId; const aName: string):
  TArray<TDelphiSemanticIndexedSymbol>;
begin
  if fData = nil then
    Exit(nil);

  Result := fData.FindLocalSymbolsByRoutineIdAndName(aRoutineId, aName);
end;

function TDelphiSemanticProjectSymbolIndex.FindMembersByOwnerAndName(
  const aOwnerName, aName: string): TArray<TDelphiSemanticIndexedSymbol>;
begin
  if fData = nil then
    Exit(nil);

  Result := fData.FindMembersByOwnerAndName(aOwnerName, aName);
end;

function TDelphiSemanticProjectSymbolIndex.FindReferencesByName(
  const aName: string): TArray<TDelphiSemanticIndexedReference>;
begin
  if fData = nil then
    Exit(nil);

  Result := fData.FindReferencesByName(aName);
end;

function TDelphiSemanticProjectSymbolIndex.FindReferencesBySymbolId(
  const aId: TDelphiSemanticSymbolId): TArray<TDelphiSemanticIndexedReference>;
begin
  if fData = nil then
    Exit(nil);

  Result := fData.FindReferencesBySymbolId(aId);
end;

function TDelphiSemanticProjectSymbolIndex.FindVisibleUnitScopes(
  const aUnitName, aSectionKind: string): TArray<TDelphiSemanticUnitModel>;
begin
  if fData = nil then
    Exit(nil);

  Result := fData.FindVisibleUnitScopes(aUnitName, aSectionKind);
end;

function TDelphiSemanticProjectSymbolIndex.FindUnitModelByName(
  const aName: string; out aModel: TDelphiSemanticUnitModel): Boolean;
begin
  if fData = nil then
  begin
    aModel := Default(TDelphiSemanticUnitModel);
    Exit(False);
  end;

  Result := fData.FindUnitModelByName(aName, aModel);
end;

class procedure TDelphiSemanticProjectSymbolIndexData.AddReferenceToMap(
  const aMap: TDictionary<string, TDelphiSemanticIndexedReferenceList>; const aKey: string;
  const aReference: TDelphiSemanticIndexedReference);
var
  lList: TDelphiSemanticIndexedReferenceList;
begin
  if not aMap.TryGetValue(aKey, lList) then
  begin
    lList := TDelphiSemanticIndexedReferenceList.Create;
    try
      aMap.Add(aKey, lList);
    except
      lList.Free;
      raise;
    end;
  end;
  lList.Add(aReference);
end;

class procedure TDelphiSemanticProjectSymbolIndexData.AddLocalOriginKeys(
  const aMap: TDelphiSemanticSymbolOriginSet; const aModel: TDelphiSemanticUnitModel);
var
  lKey: TDelphiSemanticSymbolOriginKey;
  lLocal: TDelphiSemanticLocal;
begin
  for lLocal in aModel.Locals do
  begin
    lKey.UnitName := aModel.UnitName;
    lKey.OwnerName := lLocal.RoutineName;
    lKey.Name := lLocal.Name;
    lKey.Kind := lLocal.Kind;
    lKey.Line := lLocal.Line;
    lKey.Column := lLocal.Column;
    aMap.AddOrSetValue(lKey, True);
  end;
end;

class procedure TDelphiSemanticProjectSymbolIndexData.AddMemberOriginKeys(
  const aMap: TDelphiSemanticSymbolOriginSet; const aModel: TDelphiSemanticUnitModel);
var
  lKey: TDelphiSemanticSymbolOriginKey;
  lMember: TDelphiSemanticMember;
begin
  for lMember in aModel.Members do
  begin
    lKey.UnitName := aModel.UnitName;
    lKey.OwnerName := lMember.OwnerName;
    lKey.Name := lMember.Name;
    lKey.Kind := lMember.Kind;
    lKey.Line := lMember.Line;
    lKey.Column := lMember.Column;
    aMap.AddOrSetValue(lKey, True);
  end;
end;

class procedure TDelphiSemanticProjectSymbolIndexData.AddSymbolToCompositeMap(
  const aMap: TDictionary<TDelphiSemanticOwnerNameKey, TDelphiSemanticIndexedSymbolList>;
  const aOwnerName, aName: string; const aSymbol: TDelphiSemanticIndexedSymbol);
var
  lKey: TDelphiSemanticOwnerNameKey;
  lList: TDelphiSemanticIndexedSymbolList;
begin
  lKey.OwnerName := aOwnerName;
  lKey.Name := aName;
  if not aMap.TryGetValue(lKey, lList) then
  begin
    lList := TDelphiSemanticIndexedSymbolList.Create;
    try
      aMap.Add(lKey, lList);
    except
      lList.Free;
      raise;
    end;
  end;
  lList.Add(aSymbol);
end;

class procedure TDelphiSemanticProjectSymbolIndexData.AddSymbolToMap(
  const aMap: TDictionary<string, TDelphiSemanticIndexedSymbolList>; const aKey: string;
  const aSymbol: TDelphiSemanticIndexedSymbol);
var
  lList: TDelphiSemanticIndexedSymbolList;
begin
  if not aMap.TryGetValue(aKey, lList) then
  begin
    lList := TDelphiSemanticIndexedSymbolList.Create;
    try
      aMap.Add(aKey, lList);
    except
      lList.Free;
      raise;
    end;
  end;
  lList.Add(aSymbol);
end;

procedure TDelphiSemanticProjectSymbolIndexData.AddVisibleScope(
  const aUnitName, aSectionKind: string; const aModel: TDelphiSemanticUnitModel);
var
  lExistingModel: TDelphiSemanticUnitModel;
  lKey: TDelphiSemanticUnitSectionKey;
  lList: TDelphiSemanticUnitModelList;
begin
  if (aUnitName = '') or (aSectionKind = '') or (aModel.UnitName = '') then
    Exit;

  lKey.UnitName := aUnitName;
  lKey.SectionKind := aSectionKind;
  if not fVisibleScopesByUnitAndSection.TryGetValue(lKey, lList) then
  begin
    lList := TDelphiSemanticUnitModelList.Create;
    try
      fVisibleScopesByUnitAndSection.Add(lKey, lList);
    except
      lList.Free;
      raise;
    end;
  end;
  for lExistingModel in lList do
    if SameText(lExistingModel.UnitName, aModel.UnitName) then
      Exit;
  lList.Add(aModel);
end;

procedure TDelphiSemanticProjectSymbolIndexData.AddUsedVisibleScopes(
  const aUnitName, aSectionKind: string; const aUsedUnitNames: TArray<string>);
var
  lModel: TDelphiSemanticUnitModel;
  lUnitName: string;
begin
  for lUnitName in aUsedUnitNames do
    if fUnitModelsByName.TryGetValue(lUnitName, lModel) then
      AddVisibleScope(aUnitName, aSectionKind, lModel);
end;

procedure TDelphiSemanticProjectSymbolIndexData.AddReferences(
  const aReferences: TArray<TDelphiSemanticIndexedReference>);
var
  lReference: TDelphiSemanticIndexedReference;
begin
  for lReference in aReferences do
  begin
    AddReferenceToMap(fReferencesByName, lReference.Name, lReference);
    if lReference.SymbolId.Value <> '' then
      AddReferenceToMap(fReferencesBySymbolId, lReference.SymbolId.Value, lReference);
  end;
end;

procedure TDelphiSemanticProjectSymbolIndexData.AddVisibleScopesForModel(
  const aModel: TDelphiSemanticUnitModel);
begin
  AddVisibleScope(aModel.UnitName, 'interface', aModel);
  AddUsedVisibleScopes(aModel.UnitName, 'interface', aModel.InterfaceUses);
  AddVisibleScope(aModel.UnitName, 'implementation', aModel);
  AddUsedVisibleScopes(aModel.UnitName, 'implementation', aModel.InterfaceUses);
  AddUsedVisibleScopes(aModel.UnitName, 'implementation', aModel.ImplementationUses);
end;

function TryFindUniqueRoutineSymbolId(const aSymbols: TArray<TDelphiSemanticIndexedSymbol>;
  const aUnitName, aRoutineName: string; out aRoutineId: TDelphiSemanticSymbolId): Boolean;
  forward;

constructor TDelphiSemanticProjectSymbolIndexData.Create(
  const aContext: TDelphiSemanticSymbolQueryContext;
  const aSymbols: TArray<TDelphiSemanticIndexedSymbol>;
  const aReferences: TArray<TDelphiSemanticIndexedReference>);
var
  i: Integer;
  lCompositeComparer: IEqualityComparer<TDelphiSemanticOwnerNameKey>;
  lComparer: IEqualityComparer<string>;
  lLocalOriginKeys: TDelphiSemanticSymbolOriginSet;
  lMemberOriginKeys: TDelphiSemanticSymbolOriginSet;
  lModel: TDelphiSemanticUnitModel;
  lOriginComparer: IEqualityComparer<TDelphiSemanticSymbolOriginKey>;
  lOriginKey: TDelphiSemanticSymbolOriginKey;
  lReference: TDelphiSemanticIndexedReference;
  lRoutineId: TDelphiSemanticSymbolId;
  lSymbol: TDelphiSemanticIndexedSymbol;
  lVisibleScopeComparer: IEqualityComparer<TDelphiSemanticUnitSectionKey>;
begin
  inherited Create;
  lLocalOriginKeys := nil;
  lMemberOriginKeys := nil;
  lComparer := TFastCaseAwareComparer.OrdinalIgnoreCase;
  lCompositeComparer := TDelphiSemanticOwnerNameKeyComparer.Create;
  lOriginComparer := TDelphiSemanticSymbolOriginKeyComparer.Create;
  lVisibleScopeComparer := TDelphiSemanticUnitSectionKeyComparer.Create;
  fSymbolsById := TDictionary<string, TDelphiSemanticIndexedSymbol>.Create(lComparer);
  fSymbolsByName := TDictionary<string, TDelphiSemanticIndexedSymbolList>.Create(lComparer);
  fTopLevelSymbolsByName := TDictionary<string, TDelphiSemanticIndexedSymbolList>.Create(
    lComparer);
  fLocalSymbolsByRoutineAndName := TDictionary<TDelphiSemanticOwnerNameKey,
    TDelphiSemanticIndexedSymbolList>.Create(lCompositeComparer);
  fLocalSymbolsByRoutineIdAndName := TDictionary<TDelphiSemanticOwnerNameKey,
    TDelphiSemanticIndexedSymbolList>.Create(lCompositeComparer);
  fMembersByOwnerAndName := TDictionary<TDelphiSemanticOwnerNameKey,
    TDelphiSemanticIndexedSymbolList>.Create(lCompositeComparer);
  fReferencesByName := TDictionary<string, TDelphiSemanticIndexedReferenceList>.Create(
    lComparer);
  fReferencesBySymbolId := TDictionary<string, TDelphiSemanticIndexedReferenceList>.Create(
    lComparer);
  fUnitModelsByName := TDictionary<string, TDelphiSemanticUnitModel>.Create(lComparer);
  fVisibleScopesByUnitAndSection := TDictionary<TDelphiSemanticUnitSectionKey,
    TDelphiSemanticUnitModelList>.Create(lVisibleScopeComparer);

  if aContext.UnitModel.UnitName <> '' then
    fUnitModelsByName.AddOrSetValue(aContext.UnitModel.UnitName, aContext.UnitModel);
  for i := 0 to High(aContext.IndexedUnitModels) do
  begin
    lModel := aContext.IndexedUnitModels[i];
    if lModel.UnitName <> '' then
      fUnitModelsByName.AddOrSetValue(lModel.UnitName, lModel);
  end;
  AddVisibleScopesForModel(aContext.UnitModel);
  for i := 0 to High(aContext.IndexedUnitModels) do
    AddVisibleScopesForModel(aContext.IndexedUnitModels[i]);

  lLocalOriginKeys := TDelphiSemanticSymbolOriginSet.Create(lOriginComparer);
  try
    lMemberOriginKeys := TDelphiSemanticSymbolOriginSet.Create(lOriginComparer);
    AddLocalOriginKeys(lLocalOriginKeys, aContext.UnitModel);
    AddMemberOriginKeys(lMemberOriginKeys, aContext.UnitModel);
    for i := 0 to High(aContext.IndexedUnitModels) do
    begin
      AddLocalOriginKeys(lLocalOriginKeys, aContext.IndexedUnitModels[i]);
      AddMemberOriginKeys(lMemberOriginKeys, aContext.IndexedUnitModels[i]);
    end;

    for lSymbol in aSymbols do
    begin
      fSymbolsById.AddOrSetValue(lSymbol.Id.Value, lSymbol);
      AddSymbolToMap(fSymbolsByName, lSymbol.Name, lSymbol);
      lOriginKey.UnitName := lSymbol.UnitName;
      lOriginKey.OwnerName := lSymbol.OwnerName;
      lOriginKey.Name := lSymbol.Name;
      lOriginKey.Kind := lSymbol.Kind;
      lOriginKey.Line := lSymbol.Line;
      lOriginKey.Column := lSymbol.Column;
      if lLocalOriginKeys.ContainsKey(lOriginKey) then
      begin
        AddSymbolToCompositeMap(fLocalSymbolsByRoutineAndName, lSymbol.OwnerName, lSymbol.Name,
          lSymbol);
        if TryFindUniqueRoutineSymbolId(aSymbols, lSymbol.UnitName, lSymbol.OwnerName,
          lRoutineId) then
          AddSymbolToCompositeMap(fLocalSymbolsByRoutineIdAndName, lRoutineId.Value, lSymbol.Name,
            lSymbol);
      end
      else if lMemberOriginKeys.ContainsKey(lOriginKey) then
        AddSymbolToCompositeMap(fMembersByOwnerAndName, lSymbol.OwnerName, lSymbol.Name, lSymbol)
      else if lSymbol.OwnerName = '' then
        AddSymbolToMap(fTopLevelSymbolsByName, lSymbol.Name, lSymbol);
    end;
  finally
    lMemberOriginKeys.Free;
    lLocalOriginKeys.Free;
  end;

  AddReferences(aReferences);
end;

destructor TDelphiSemanticProjectSymbolIndexData.Destroy;
var
  lReferenceList: TDelphiSemanticIndexedReferenceList;
  lSymbolList: TDelphiSemanticIndexedSymbolList;
  lUnitModelList: TDelphiSemanticUnitModelList;
begin
  if fSymbolsByName <> nil then
    for lSymbolList in fSymbolsByName.Values do
      lSymbolList.Free;
  if fTopLevelSymbolsByName <> nil then
    for lSymbolList in fTopLevelSymbolsByName.Values do
      lSymbolList.Free;
  if fLocalSymbolsByRoutineAndName <> nil then
    for lSymbolList in fLocalSymbolsByRoutineAndName.Values do
      lSymbolList.Free;
  if fLocalSymbolsByRoutineIdAndName <> nil then
    for lSymbolList in fLocalSymbolsByRoutineIdAndName.Values do
      lSymbolList.Free;
  if fMembersByOwnerAndName <> nil then
    for lSymbolList in fMembersByOwnerAndName.Values do
      lSymbolList.Free;
  if fReferencesByName <> nil then
    for lReferenceList in fReferencesByName.Values do
      lReferenceList.Free;
  if fReferencesBySymbolId <> nil then
    for lReferenceList in fReferencesBySymbolId.Values do
      lReferenceList.Free;
  if fVisibleScopesByUnitAndSection <> nil then
    for lUnitModelList in fVisibleScopesByUnitAndSection.Values do
      lUnitModelList.Free;
  fVisibleScopesByUnitAndSection.Free;
  fUnitModelsByName.Free;
  fReferencesBySymbolId.Free;
  fReferencesByName.Free;
  fMembersByOwnerAndName.Free;
  fLocalSymbolsByRoutineIdAndName.Free;
  fLocalSymbolsByRoutineAndName.Free;
  fTopLevelSymbolsByName.Free;
  fSymbolsByName.Free;
  fSymbolsById.Free;
  inherited Destroy;
end;

function TDelphiSemanticProjectSymbolIndexData.FindSymbolById(
  const aId: TDelphiSemanticSymbolId; out aSymbol: TDelphiSemanticIndexedSymbol): Boolean;
begin
  Result := fSymbolsById.TryGetValue(aId.Value, aSymbol);
end;

function TDelphiSemanticProjectSymbolIndexData.FindSymbolsByName(
  const aName: string): TArray<TDelphiSemanticIndexedSymbol>;
var
  lList: TDelphiSemanticIndexedSymbolList;
begin
  if fSymbolsByName.TryGetValue(aName, lList) then
    Exit(lList.ToArray);

  Result := nil;
end;

function TDelphiSemanticProjectSymbolIndexData.FindTopLevelSymbolsByName(
  const aName: string): TArray<TDelphiSemanticIndexedSymbol>;
var
  lList: TDelphiSemanticIndexedSymbolList;
begin
  if fTopLevelSymbolsByName.TryGetValue(aName, lList) then
    Exit(lList.ToArray);

  Result := nil;
end;

function TDelphiSemanticProjectSymbolIndexData.FindLocalSymbolsByRoutineAndName(
  const aRoutineName, aName: string): TArray<TDelphiSemanticIndexedSymbol>;
var
  lKey: TDelphiSemanticOwnerNameKey;
  lList: TDelphiSemanticIndexedSymbolList;
begin
  lKey.OwnerName := aRoutineName;
  lKey.Name := aName;
  if fLocalSymbolsByRoutineAndName.TryGetValue(lKey, lList) then
    Exit(lList.ToArray);

  Result := nil;
end;

function TDelphiSemanticProjectSymbolIndexData.FindLocalSymbolsByRoutineIdAndName(
  const aRoutineId: TDelphiSemanticSymbolId; const aName: string):
  TArray<TDelphiSemanticIndexedSymbol>;
var
  lKey: TDelphiSemanticOwnerNameKey;
  lList: TDelphiSemanticIndexedSymbolList;
begin
  lKey.OwnerName := aRoutineId.Value;
  lKey.Name := aName;
  if fLocalSymbolsByRoutineIdAndName.TryGetValue(lKey, lList) then
    Exit(lList.ToArray);

  Result := nil;
end;

function TDelphiSemanticProjectSymbolIndexData.FindMembersByOwnerAndName(
  const aOwnerName, aName: string): TArray<TDelphiSemanticIndexedSymbol>;
var
  lKey: TDelphiSemanticOwnerNameKey;
  lList: TDelphiSemanticIndexedSymbolList;
begin
  lKey.OwnerName := aOwnerName;
  lKey.Name := aName;
  if fMembersByOwnerAndName.TryGetValue(lKey, lList) then
    Exit(lList.ToArray);

  Result := nil;
end;

function TDelphiSemanticProjectSymbolIndexData.FindReferencesByName(
  const aName: string): TArray<TDelphiSemanticIndexedReference>;
var
  lList: TDelphiSemanticIndexedReferenceList;
begin
  if fReferencesByName.TryGetValue(aName, lList) then
    Exit(lList.ToArray);

  Result := nil;
end;

function TDelphiSemanticProjectSymbolIndexData.FindReferencesBySymbolId(
  const aId: TDelphiSemanticSymbolId): TArray<TDelphiSemanticIndexedReference>;
var
  lList: TDelphiSemanticIndexedReferenceList;
begin
  if fReferencesBySymbolId.TryGetValue(aId.Value, lList) then
    Exit(lList.ToArray);

  Result := nil;
end;

function TDelphiSemanticProjectSymbolIndexData.FindVisibleUnitScopes(
  const aUnitName, aSectionKind: string): TArray<TDelphiSemanticUnitModel>;
var
  lKey: TDelphiSemanticUnitSectionKey;
  lList: TDelphiSemanticUnitModelList;
begin
  lKey.UnitName := aUnitName;
  lKey.SectionKind := aSectionKind;
  if fVisibleScopesByUnitAndSection.TryGetValue(lKey, lList) then
    Exit(lList.ToArray);

  Result := nil;
end;

function TDelphiSemanticProjectSymbolIndexData.FindUnitModelByName(
  const aName: string; out aModel: TDelphiSemanticUnitModel): Boolean;
begin
  Result := fUnitModelsByName.TryGetValue(aName, aModel);
end;

function NormalizeSignatureForSymbolId(const aSignature: string): string;
begin
  Result := LowerCase(StringReplace(aSignature.Trim, ' ', '', [rfReplaceAll]));
end;

function QualifiedSymbolRoutineName(const aSymbol: TDelphiSemanticIndexedSymbol): string;
begin
  if aSymbol.OwnerName <> '' then
    Result := aSymbol.OwnerName + '.' + aSymbol.Name
  else
    Result := aSymbol.Name;
end;

function TryFindUniqueRoutineSymbolId(const aSymbols: TArray<TDelphiSemanticIndexedSymbol>;
  const aUnitName, aRoutineName: string; out aRoutineId: TDelphiSemanticSymbolId): Boolean;
var
  lCount: Integer;
  lSignature: string;
  lSymbol: TDelphiSemanticIndexedSymbol;
begin
  aRoutineId := Default(TDelphiSemanticSymbolId);
  lCount := 0;
  lSignature := '';
  for lSymbol in aSymbols do
    if SameText(lSymbol.UnitName, aUnitName) and SameText(lSymbol.Kind, 'routine') and
      SameText(QualifiedSymbolRoutineName(lSymbol), aRoutineName) then
    begin
      if lCount = 0 then
      begin
        Inc(lCount);
        aRoutineId := lSymbol.Id;
        lSignature := NormalizeSignatureForSymbolId(lSymbol.Signature);
      end else if not SameText(lSignature, NormalizeSignatureForSymbolId(lSymbol.Signature)) then
      begin
        Inc(lCount);
        aRoutineId := Default(TDelphiSemanticSymbolId);
        Exit(False);
      end;
    end;

  Result := lCount = 1;
end;

function MakeSymbolId(const aModel: TDelphiSemanticUnitModel; const aKind, aOwnerName,
  aName, aSignature: string; const aLine, aColumn, aOrdinal: Integer): TDelphiSemanticSymbolId;
begin
  if SameText(aKind, 'routine') then
    Result.Value := LowerCase(aModel.UnitName) + ':' + LowerCase(aKind) + ':' +
      LowerCase(aOwnerName) + ':' + LowerCase(aName) + ':' +
      NormalizeSignatureForSymbolId(aSignature)
  else
    Result.Value := LowerCase(aModel.UnitName) + ':' + LowerCase(aKind) + ':' +
      LowerCase(aOwnerName) + ':' + LowerCase(aName) + ':' + IntToStr(aLine) + ':' +
      IntToStr(aColumn) + ':' + IntToStr(aOrdinal);
end;

function IndexedSourceKind(const aContext: TDelphiSemanticSymbolQueryContext;
  const aIndex: Integer): string;
begin
  if (aIndex >= 0) and (aIndex < Length(aContext.IndexedUnitSourceKinds)) and
    (aContext.IndexedUnitSourceKinds[aIndex] <> '') then
    Exit(aContext.IndexedUnitSourceKinds[aIndex]);

  Result := 'rtl-source';
end;

procedure AddSymbol(const aSymbols: TDelphiSemanticSymbolList;
  const aModel: TDelphiSemanticUnitModel; const aSourceKind, aKind, aOwnerName, aName: string;
  const aSectionKind, aVisibility, aSignature: string; const aLine, aColumn: Integer);
var
  lSymbol: TDelphiSemanticIndexedSymbol;
begin
  if aName = '' then
    Exit;

  lSymbol := Default(TDelphiSemanticIndexedSymbol);
  lSymbol.Id := MakeSymbolId(aModel, aKind, aOwnerName, aName, aSignature, aLine, aColumn,
    aSymbols.Count);
  lSymbol.Name := aName;
  lSymbol.Kind := aKind;
  lSymbol.OwnerName := aOwnerName;
  lSymbol.UnitName := aModel.UnitName;
  lSymbol.SectionKind := aSectionKind;
  lSymbol.SourceKind := aSourceKind;
  lSymbol.Visibility := aVisibility;
  lSymbol.Signature := aSignature;
  lSymbol.FileName := aModel.FileName;
  lSymbol.Line := aLine;
  lSymbol.Column := aColumn;
  aSymbols.Add(lSymbol);
end;

procedure AddModelSymbols(const aSymbols: TDelphiSemanticSymbolList;
  const aModel: TDelphiSemanticUnitModel; const aSourceKind: string);
var
  lDeclaration: TDelphiSemanticDeclaration;
  lLocal: TDelphiSemanticLocal;
  lMember: TDelphiSemanticMember;
  lRoutine: TDelphiSemanticRoutine;
begin
  AddSymbol(aSymbols, aModel, aSourceKind, 'unit', '', aModel.UnitName, 'interface', '', '', 1, 1);

  for lDeclaration in aModel.Declarations do
    if not SameText(lDeclaration.Kind, 'routine') then
      AddSymbol(aSymbols, aModel, aSourceKind, lDeclaration.Kind, '', lDeclaration.Name,
        lDeclaration.SectionKind, '', '', lDeclaration.Line, lDeclaration.Column);

  for lRoutine in aModel.Routines do
    AddSymbol(aSymbols, aModel, aSourceKind, 'routine', lRoutine.OwnerName, lRoutine.Name,
      lRoutine.SectionKind, '', lRoutine.Signature, lRoutine.Line, lRoutine.Column);

  for lMember in aModel.Members do
    AddSymbol(aSymbols, aModel, aSourceKind, lMember.Kind, lMember.OwnerName, lMember.Name,
      '', lMember.Visibility, lMember.Signature, lMember.Line, lMember.Column);

  for lLocal in aModel.Locals do
    AddSymbol(aSymbols, aModel, aSourceKind, lLocal.Kind, lLocal.RoutineName, lLocal.Name,
      '', '', '', lLocal.Line, lLocal.Column);
end;

function SymbolIdInList(const aIds: TList<TDelphiSemanticSymbolId>;
  const aId: TDelphiSemanticSymbolId): Boolean;
var
  lId: TDelphiSemanticSymbolId;
begin
  for lId in aIds do
    if lId.Value = aId.Value then
      Exit(True);

  Result := False;
end;

function ReferenceConfidence(const aReferenceName: string;
  const aCandidates: TList<TDelphiSemanticSymbolId>;
  const aIndex: TDelphiSemanticProjectSymbolIndex): string;
var
  lCandidate: TDelphiSemanticSymbolId;
  lSymbol: TDelphiSemanticIndexedSymbol;
begin
  if aCandidates.Count = 0 then
    Exit('no-candidates');

  for lCandidate in aCandidates do
    if aIndex.FindSymbolById(lCandidate, lSymbol) and (lSymbol.Name = aReferenceName) then
      Exit('exact-name-match');

  Result := 'case-insensitive-name-match';
end;

function UnitNameIsUsedBySection(const aModel: TDelphiSemanticUnitModel; const aSourceKind,
  aTargetUnitName: string): Boolean;
var
  s: string;
begin
  if SameText(aModel.UnitName, aTargetUnitName) then
    Exit(True);

  for s in aModel.InterfaceUses do
    if SameText(s, aTargetUnitName) then
      Exit(True);

  if SameText(aSourceKind, 'implementation') then
    for s in aModel.ImplementationUses do
      if SameText(s, aTargetUnitName) then
        Exit(True);

  Result := False;
end;

function OwnedSymbolIsVisibleFromReference(const aReferenceModel: TDelphiSemanticUnitModel;
  const aReference: TDelphiSemanticReference; const aSymbol: TDelphiSemanticIndexedSymbol):
  Boolean;
begin
  if aSymbol.OwnerName = '' then
    Exit(False);
  if not SameText(aReferenceModel.UnitName, aSymbol.UnitName) then
    Exit(False);
  if MatchText(aSymbol.Kind, ['field', 'class-var', 'property']) then
    Exit(StartsText(aSymbol.OwnerName + '.', aReference.RoutineName));

  Result := False;
end;

function IsOwnedMethodCandidate(const aModel: TDelphiSemanticUnitModel;
  const aSymbol: TDelphiSemanticIndexedSymbol): Boolean;
begin
  Result := (aSymbol.OwnerName <> '') and SameText(aModel.UnitName, aSymbol.UnitName) and
    SameText(aSymbol.Kind, 'method');
end;

function TopLevelSymbolIsVisibleFromReference(const aReferenceModel: TDelphiSemanticUnitModel;
  const aSectionKind: string; const aSymbol: TDelphiSemanticIndexedSymbol): Boolean;
begin
  if aSymbol.OwnerName <> '' then
    Exit(False);

  if not (SameText(aSymbol.Kind, 'unit') or SameText(aSymbol.Kind, 'type') or
    SameText(aSymbol.Kind, 'type-alias') or SameText(aSymbol.Kind, 'var') or
    SameText(aSymbol.Kind, 'const') or SameText(aSymbol.Kind, 'routine')) then
    Exit(False);

  if SameText(aReferenceModel.UnitName, aSymbol.UnitName) then
    Exit(SameText(aSectionKind, 'implementation') or SameText(aSymbol.SectionKind, 'interface') or
      SameText(aSymbol.Kind, 'unit'));

  Result := SameText(aSymbol.SectionKind, 'interface') or SameText(aSymbol.Kind, 'unit');
end;

procedure AddCandidateId(const aCandidateIds: TList<TDelphiSemanticSymbolId>;
  const aSymbol: TDelphiSemanticIndexedSymbol);
begin
  if not SymbolIdInList(aCandidateIds, aSymbol.Id) then
    aCandidateIds.Add(aSymbol.Id);
end;

function RoutineSimpleName(const aRoutineName: string): string;
var
  lIndex: Integer;
begin
  lIndex := LastDelimiter('.', aRoutineName);
  if lIndex > 0 then
    Result := Copy(aRoutineName, lIndex + 1, MaxInt)
  else
    Result := aRoutineName;
end;

function TryResolveUniqueRoutineId(const aIndex: TDelphiSemanticProjectSymbolIndex;
  const aModel: TDelphiSemanticUnitModel; const aRoutineName: string;
  out aRoutineId: TDelphiSemanticSymbolId; out aAmbiguous: Boolean): Boolean;
var
  lCount: Integer;
  lSignature: string;
  lSymbol: TDelphiSemanticIndexedSymbol;
begin
  aRoutineId := Default(TDelphiSemanticSymbolId);
  aAmbiguous := False;
  lCount := 0;
  lSignature := '';
  for lSymbol in aIndex.FindSymbolsByName(RoutineSimpleName(aRoutineName)) do
    if SameText(lSymbol.UnitName, aModel.UnitName) and SameText(lSymbol.Kind, 'routine') and
      SameText(QualifiedSymbolRoutineName(lSymbol), aRoutineName) then
    begin
      if lCount = 0 then
      begin
        Inc(lCount);
        aRoutineId := lSymbol.Id;
        lSignature := NormalizeSignatureForSymbolId(lSymbol.Signature);
      end else if not SameText(lSignature, NormalizeSignatureForSymbolId(lSymbol.Signature)) then
      begin
        Inc(lCount);
        aRoutineId := Default(TDelphiSemanticSymbolId);
        aAmbiguous := True;
        Exit(False);
      end;
    end;

  Result := lCount = 1;
end;

function AddLocalReferenceCandidates(const aIndex: TDelphiSemanticProjectSymbolIndex;
  const aModel: TDelphiSemanticUnitModel; const aReference: TDelphiSemanticReference;
  const aCandidateIds: TList<TDelphiSemanticSymbolId>): Boolean;
var
  lAmbiguousRoutine: Boolean;
  lRoutineId: TDelphiSemanticSymbolId;
  lSymbol: TDelphiSemanticIndexedSymbol;
begin
  Result := False;
  if aReference.RoutineName = '' then
    Exit;

  if not TryResolveUniqueRoutineId(aIndex, aModel, aReference.RoutineName, lRoutineId,
    lAmbiguousRoutine) then
  begin
    Result := lAmbiguousRoutine;
    Exit;
  end;

  for lSymbol in aIndex.FindLocalSymbolsByRoutineIdAndName(lRoutineId, aReference.Name) do
    if SameText(lSymbol.UnitName, aModel.UnitName) then
      AddCandidateId(aCandidateIds, lSymbol);

  Result := aCandidateIds.Count > 0;
end;

procedure AddOwnedReferenceCandidates(const aIndex: TDelphiSemanticProjectSymbolIndex;
  const aModel: TDelphiSemanticUnitModel; const aReference: TDelphiSemanticReference;
  const aCandidateIds: TList<TDelphiSemanticSymbolId>);
var
  lMethodCandidate: TDelphiSemanticIndexedSymbol;
  lMethodCount: Integer;
  lMethodOwnerName: string;
  lSymbol: TDelphiSemanticIndexedSymbol;
begin
  lMethodCandidate := Default(TDelphiSemanticIndexedSymbol);
  lMethodCount := 0;
  lMethodOwnerName := '';
  for lSymbol in aIndex.FindSymbolsByName(aReference.Name) do
  begin
    if OwnedSymbolIsVisibleFromReference(aModel, aReference, lSymbol) then
      AddCandidateId(aCandidateIds, lSymbol);
    if IsOwnedMethodCandidate(aModel, lSymbol) and not SameText(lSymbol.OwnerName,
      lMethodOwnerName) then
    begin
      Inc(lMethodCount);
      lMethodOwnerName := lSymbol.OwnerName;
      lMethodCandidate := lSymbol;
    end;
  end;

  if lMethodCount = 1 then
    AddCandidateId(aCandidateIds, lMethodCandidate);
end;

procedure AddTopLevelReferenceCandidates(const aIndex: TDelphiSemanticProjectSymbolIndex;
  const aModel: TDelphiSemanticUnitModel; const aReference: TDelphiSemanticReference;
  const aCandidateIds: TList<TDelphiSemanticSymbolId>);
var
  lSectionKind: string;
  lScope: TDelphiSemanticUnitModel;
  lSymbol: TDelphiSemanticIndexedSymbol;
  lSymbols: TArray<TDelphiSemanticIndexedSymbol>;
begin
  lSectionKind := aReference.SectionKind;
  if lSectionKind = '' then
    lSectionKind := 'implementation';

  lSymbols := aIndex.FindSymbolsByName(aReference.Name);
  for lScope in aIndex.FindVisibleUnitScopes(aModel.UnitName, lSectionKind) do
    for lSymbol in lSymbols do
      if SameText(lSymbol.UnitName, lScope.UnitName) and
        TopLevelSymbolIsVisibleFromReference(aModel, lSectionKind, lSymbol) then
        AddCandidateId(aCandidateIds, lSymbol);
end;

procedure ResolveReference(const aIndex: TDelphiSemanticProjectSymbolIndex;
  const aModel: TDelphiSemanticUnitModel; const aReference: TDelphiSemanticReference;
  var aIndexedReference: TDelphiSemanticIndexedReference);
var
  lCandidateIds: TList<TDelphiSemanticSymbolId>;
begin
  lCandidateIds := TList<TDelphiSemanticSymbolId>.Create;
  try
    if not AddLocalReferenceCandidates(aIndex, aModel, aReference, lCandidateIds) then
    begin
      AddOwnedReferenceCandidates(aIndex, aModel, aReference, lCandidateIds);
      AddTopLevelReferenceCandidates(aIndex, aModel, aReference, lCandidateIds);
    end;

    aIndexedReference.CandidateSymbolIds := lCandidateIds.ToArray;
    aIndexedReference.Confidence := ReferenceConfidence(aReference.Name, lCandidateIds,
      aIndex);
    if lCandidateIds.Count = 0 then
      aIndexedReference.Status := 'unresolved'
    else if lCandidateIds.Count = 1 then
    begin
      aIndexedReference.Status := 'resolved';
      aIndexedReference.SymbolId := lCandidateIds[0];
    end else
      aIndexedReference.Status := 'ambiguous';
  finally
    lCandidateIds.Free;
  end;
end;

procedure AddModelReferences(const aIndex: TDelphiSemanticProjectSymbolIndex;
  const aReferences: TList<TDelphiSemanticIndexedReference>; const aModel:
  TDelphiSemanticUnitModel; const aSourceKind: string);
var
  lIndexedReference: TDelphiSemanticIndexedReference;
  lReference: TDelphiSemanticReference;
begin
  for lReference in aModel.References do
  begin
    lIndexedReference := Default(TDelphiSemanticIndexedReference);
    lIndexedReference.Name := lReference.Name;
    lIndexedReference.RoutineName := lReference.RoutineName;
    lIndexedReference.UnitName := aModel.UnitName;
    lIndexedReference.SourceKind := aSourceKind;
    lIndexedReference.FileName := aModel.FileName;
    lIndexedReference.SectionKind := lReference.SectionKind;
    if lIndexedReference.SectionKind = '' then
      lIndexedReference.SectionKind := 'implementation';
    lIndexedReference.Line := lReference.Line;
    lIndexedReference.Column := lReference.Column;
    lIndexedReference.EndLine := lReference.EndLine;
    if lIndexedReference.EndLine = 0 then
      lIndexedReference.EndLine := lReference.Line;
    lIndexedReference.EndColumn := lReference.EndColumn;
    if lIndexedReference.EndColumn = 0 then
      lIndexedReference.EndColumn := lReference.Column + Length(lReference.Name) - 1;
    ResolveReference(aIndex, aModel, lReference, lIndexedReference);
    aReferences.Add(lIndexedReference);
  end;
end;

class function TDelphiSemanticProjectSymbolIndexer.Build(
  const aContext: TDelphiSemanticSymbolQueryContext): TDelphiSemanticProjectSymbolIndex;
var
  i: Integer;
  lModel: TDelphiSemanticUnitModel;
  lMutableData: IDelphiSemanticMutableProjectSymbolIndexData;
  lReferences: TList<TDelphiSemanticIndexedReference>;
  lSymbols: TDelphiSemanticSymbolList;
begin
  Inc(BuildInvocationCount);
  lSymbols := TDelphiSemanticSymbolList.Create;
  lReferences := TList<TDelphiSemanticIndexedReference>.Create;
  try
    AddModelSymbols(lSymbols, aContext.UnitModel, 'project-source');
    for i := 0 to High(aContext.IndexedUnitModels) do
    begin
      lModel := aContext.IndexedUnitModels[i];
      AddModelSymbols(lSymbols, lModel, IndexedSourceKind(aContext, i));
    end;

    Result.Symbols := lSymbols.ToArray;
    Result.References := nil;
    Result.fData := TDelphiSemanticProjectSymbolIndexData.Create(aContext, Result.Symbols, nil);

    AddModelReferences(Result, lReferences, aContext.UnitModel, 'project-source');
    for i := 0 to High(aContext.IndexedUnitModels) do
    begin
      lModel := aContext.IndexedUnitModels[i];
      AddModelReferences(Result, lReferences, lModel, IndexedSourceKind(aContext, i));
    end;

    Result.References := lReferences.ToArray;
    if Supports(Result.fData, IDelphiSemanticMutableProjectSymbolIndexData, lMutableData) then
      lMutableData.AddReferences(Result.References);
  finally
    lReferences.Free;
    lSymbols.Free;
  end;
end;

class procedure TDelphiSemanticProjectSymbolIndexer.ResetBuildInvocationCount;
begin
  BuildInvocationCount := 0;
end;

class procedure TDelphiSemanticProjectSymbolIndexer.ResetReferenceResolutionSymbolScanCount;
begin
  ReferenceResolutionSymbolScanCount := 0;
end;

end.
