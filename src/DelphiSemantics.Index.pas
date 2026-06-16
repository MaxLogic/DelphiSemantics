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

  TDelphiSemanticProjectSymbolIndexMetrics = record
    BuildInvocationCount: Integer;
    BuildElapsedMilliseconds: Int64;
    ReferenceResolutionSymbolScanCount: Integer;
  end;

  TDelphiSemanticProjectSymbolIndex = record
  private
    fData: IDelphiSemanticProjectSymbolIndexData;
  public
    Symbols: TArray<TDelphiSemanticIndexedSymbol>;
    References: TArray<TDelphiSemanticIndexedReference>;
    Metrics: TDelphiSemanticProjectSymbolIndexMetrics;
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
    class function Build(const aContext: TDelphiSemanticSymbolQueryContext):
      TDelphiSemanticProjectSymbolIndex; static;
  end;

implementation

uses
  System.Diagnostics, System.Generics.Collections, System.Generics.Defaults, System.StrUtils,
  System.SysUtils,
  DelphiSemantics.Index.LegacyModel, DelphiSemantics.Snapshot, DelphiSemantics.Snapshot.QuerySupport,
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
    procedure AddSnapshotSymbolMaps(const aSymbols: TArray<TDelphiSemanticIndexedSymbol>);
    procedure InitializeLookupMaps;
    class procedure AddSymbolToMap(const aMap: TDictionary<string,
      TDelphiSemanticIndexedSymbolList>; const aKey: string;
      const aSymbol: TDelphiSemanticIndexedSymbol); static;
  public
    constructor Create(const aContext: TDelphiSemanticSymbolQueryContext;
      const aSymbols: TArray<TDelphiSemanticIndexedSymbol>;
      const aReferences: TArray<TDelphiSemanticIndexedReference>);
    constructor CreateSnapshot(const aSymbols: TArray<TDelphiSemanticIndexedSymbol>;
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
var
  lSymbol: TDelphiSemanticIndexedSymbol;
begin
  if fData = nil then
  begin
    for lSymbol in Symbols do
      if SameText(lSymbol.Id.Value, aId.Value) then
      begin
        aSymbol := lSymbol;
        Exit(True);
      end;
    aSymbol := Default(TDelphiSemanticIndexedSymbol);
    Exit(False);
  end;

  Result := fData.FindSymbolById(aId, aSymbol);
end;

function TDelphiSemanticProjectSymbolIndex.FindSymbolsByName(
  const aName: string): TArray<TDelphiSemanticIndexedSymbol>;
var
  lList: TDelphiSemanticIndexedSymbolList;
  lSymbol: TDelphiSemanticIndexedSymbol;
begin
  if fData = nil then
  begin
    lList := TDelphiSemanticIndexedSymbolList.Create;
    try
      for lSymbol in Symbols do
        if SameText(lSymbol.Name, aName) then
          lList.Add(lSymbol);
      Exit(lList.ToArray);
    finally
      lList.Free;
    end;
  end;

  Result := fData.FindSymbolsByName(aName);
end;

function TDelphiSemanticProjectSymbolIndex.FindTopLevelSymbolsByName(
  const aName: string): TArray<TDelphiSemanticIndexedSymbol>;
var
  lList: TDelphiSemanticIndexedSymbolList;
  lSymbol: TDelphiSemanticIndexedSymbol;
begin
  if fData = nil then
  begin
    lList := TDelphiSemanticIndexedSymbolList.Create;
    try
      for lSymbol in Symbols do
        if (lSymbol.OwnerName = '') and SameText(lSymbol.Name, aName) then
          lList.Add(lSymbol);
      Exit(lList.ToArray);
    finally
      lList.Free;
    end;
  end;

  Result := fData.FindTopLevelSymbolsByName(aName);
end;

function TDelphiSemanticProjectSymbolIndex.FindLocalSymbolsByRoutineAndName(
  const aRoutineName, aName: string): TArray<TDelphiSemanticIndexedSymbol>;
var
  lList: TDelphiSemanticIndexedSymbolList;
  lSymbol: TDelphiSemanticIndexedSymbol;
begin
  if fData = nil then
  begin
    lList := TDelphiSemanticIndexedSymbolList.Create;
    try
      for lSymbol in Symbols do
        if SameText(lSymbol.OwnerName, aRoutineName) and SameText(lSymbol.Name, aName) then
          lList.Add(lSymbol);
      Exit(lList.ToArray);
    finally
      lList.Free;
    end;
  end;

  Result := fData.FindLocalSymbolsByRoutineAndName(aRoutineName, aName);
end;

function TDelphiSemanticProjectSymbolIndex.FindLocalSymbolsByRoutineIdAndName(
  const aRoutineId: TDelphiSemanticSymbolId; const aName: string):
  TArray<TDelphiSemanticIndexedSymbol>;
var
  lList: TDelphiSemanticIndexedSymbolList;
  lSymbol: TDelphiSemanticIndexedSymbol;
begin
  if fData = nil then
  begin
    lList := TDelphiSemanticIndexedSymbolList.Create;
    try
      for lSymbol in Symbols do
        if SameText(lSymbol.OwnerName, aRoutineId.Value) and SameText(lSymbol.Name, aName) then
          lList.Add(lSymbol);
      Exit(lList.ToArray);
    finally
      lList.Free;
    end;
  end;

  Result := fData.FindLocalSymbolsByRoutineIdAndName(aRoutineId, aName);
end;

function TDelphiSemanticProjectSymbolIndex.FindMembersByOwnerAndName(
  const aOwnerName, aName: string): TArray<TDelphiSemanticIndexedSymbol>;
var
  lList: TDelphiSemanticIndexedSymbolList;
  lSymbol: TDelphiSemanticIndexedSymbol;
begin
  if fData = nil then
  begin
    lList := TDelphiSemanticIndexedSymbolList.Create;
    try
      for lSymbol in Symbols do
        if SameText(lSymbol.OwnerName, aOwnerName) and SameText(lSymbol.Name, aName) then
          lList.Add(lSymbol);
      Exit(lList.ToArray);
    finally
      lList.Free;
    end;
  end;

  Result := fData.FindMembersByOwnerAndName(aOwnerName, aName);
end;

function TDelphiSemanticProjectSymbolIndex.FindReferencesByName(
  const aName: string): TArray<TDelphiSemanticIndexedReference>;
var
  lList: TDelphiSemanticIndexedReferenceList;
  lReference: TDelphiSemanticIndexedReference;
begin
  if fData = nil then
  begin
    lList := TDelphiSemanticIndexedReferenceList.Create;
    try
      for lReference in References do
        if SameText(lReference.Name, aName) then
          lList.Add(lReference);
      Exit(lList.ToArray);
    finally
      lList.Free;
    end;
  end;

  Result := fData.FindReferencesByName(aName);
end;

function TDelphiSemanticProjectSymbolIndex.FindReferencesBySymbolId(
  const aId: TDelphiSemanticSymbolId): TArray<TDelphiSemanticIndexedReference>;
var
  lList: TDelphiSemanticIndexedReferenceList;
  lReference: TDelphiSemanticIndexedReference;
begin
  if fData = nil then
  begin
    lList := TDelphiSemanticIndexedReferenceList.Create;
    try
      for lReference in References do
        if SameText(lReference.SymbolId.Value, aId.Value) then
          lList.Add(lReference);
      Exit(lList.ToArray);
    finally
      lList.Free;
    end;
  end;

  Result := fData.FindReferencesBySymbolId(aId);
end;

function TDelphiSemanticProjectSymbolIndex.FindVisibleUnitScopes(
  const aUnitName, aSectionKind: string): TArray<TDelphiSemanticUnitModel>;
var
  lList: TList<TDelphiSemanticUnitModel>;
  lModel: TDelphiSemanticUnitModel;
  lSymbol: TDelphiSemanticIndexedSymbol;
begin
  if fData = nil then
  begin
    lList := TList<TDelphiSemanticUnitModel>.Create;
    try
      for lSymbol in Symbols do
        if SameText(lSymbol.Kind, 'unit') and
          ((aUnitName = '') or SameText(lSymbol.UnitName, aUnitName)) then
        begin
          lModel := Default(TDelphiSemanticUnitModel);
          lModel.UnitName := lSymbol.UnitName;
          lModel.FileName := lSymbol.FileName;
          lModel.Success := True;
          lList.Add(lModel);
        end;
      Exit(lList.ToArray);
    finally
      lList.Free;
    end;
  end;

  Result := fData.FindVisibleUnitScopes(aUnitName, aSectionKind);
end;

function TDelphiSemanticProjectSymbolIndex.FindUnitModelByName(
  const aName: string; out aModel: TDelphiSemanticUnitModel): Boolean;
var
  lSymbol: TDelphiSemanticIndexedSymbol;
begin
  if fData = nil then
  begin
    for lSymbol in Symbols do
      if SameText(lSymbol.Kind, 'unit') and SameText(lSymbol.Name, aName) then
      begin
        aModel := Default(TDelphiSemanticUnitModel);
        aModel.UnitName := lSymbol.UnitName;
        aModel.FileName := lSymbol.FileName;
        aModel.Success := True;
        Exit(True);
      end;
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

function IsSnapshotLocalSymbol(const aSymbol: TDelphiSemanticIndexedSymbol): Boolean;
begin
  Result := (aSymbol.OwnerName <> '') and MatchText(aSymbol.Kind, ['local', 'parameter', 'var']);
end;

procedure TDelphiSemanticProjectSymbolIndexData.InitializeLookupMaps;
var
  lCompositeComparer: IEqualityComparer<TDelphiSemanticOwnerNameKey>;
  lComparer: IEqualityComparer<string>;
  lVisibleScopeComparer: IEqualityComparer<TDelphiSemanticUnitSectionKey>;
begin
  lComparer := TFastCaseAwareComparer.OrdinalIgnoreCase;
  lCompositeComparer := TDelphiSemanticOwnerNameKeyComparer.Create;
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
end;

procedure TDelphiSemanticProjectSymbolIndexData.AddSnapshotSymbolMaps(
  const aSymbols: TArray<TDelphiSemanticIndexedSymbol>);
var
  lModel: TDelphiSemanticUnitModel;
  lRoutineId: TDelphiSemanticSymbolId;
  lSymbol: TDelphiSemanticIndexedSymbol;
begin
  for lSymbol in aSymbols do
  begin
    fSymbolsById.AddOrSetValue(lSymbol.Id.Value, lSymbol);
    AddSymbolToMap(fSymbolsByName, lSymbol.Name, lSymbol);
    if SameText(lSymbol.Kind, 'unit') then
    begin
      lModel := Default(TDelphiSemanticUnitModel);
      lModel.UnitName := lSymbol.UnitName;
      lModel.FileName := lSymbol.FileName;
      lModel.Success := True;
      if lModel.UnitName <> '' then
      begin
        fUnitModelsByName.AddOrSetValue(lModel.UnitName, lModel);
        AddVisibleScope(lModel.UnitName, 'interface', lModel);
        AddVisibleScope(lModel.UnitName, 'implementation', lModel);
      end;
      AddSymbolToMap(fTopLevelSymbolsByName, lSymbol.Name, lSymbol);
    end else if IsSnapshotLocalSymbol(lSymbol) then
    begin
      AddSymbolToCompositeMap(fLocalSymbolsByRoutineAndName, lSymbol.OwnerName, lSymbol.Name,
        lSymbol);
      if TryFindUniqueRoutineSymbolId(aSymbols, lSymbol.UnitName, lSymbol.OwnerName,
        lRoutineId) then
        AddSymbolToCompositeMap(fLocalSymbolsByRoutineIdAndName, lRoutineId.Value, lSymbol.Name,
          lSymbol);
    end else if lSymbol.OwnerName <> '' then
      AddSymbolToCompositeMap(fMembersByOwnerAndName, lSymbol.OwnerName, lSymbol.Name, lSymbol)
    else
      AddSymbolToMap(fTopLevelSymbolsByName, lSymbol.Name, lSymbol);
  end;
end;

constructor TDelphiSemanticProjectSymbolIndexData.Create(
  const aContext: TDelphiSemanticSymbolQueryContext;
  const aSymbols: TArray<TDelphiSemanticIndexedSymbol>;
  const aReferences: TArray<TDelphiSemanticIndexedReference>);
var
  i: Integer;
  lLocalOriginKeys: TDelphiSemanticSymbolOriginSet;
  lMemberOriginKeys: TDelphiSemanticSymbolOriginSet;
  lModel: TDelphiSemanticUnitModel;
  lOriginComparer: IEqualityComparer<TDelphiSemanticSymbolOriginKey>;
  lOriginKey: TDelphiSemanticSymbolOriginKey;
  lRoutineId: TDelphiSemanticSymbolId;
  lSymbol: TDelphiSemanticIndexedSymbol;
begin
  inherited Create;
  lLocalOriginKeys := nil;
  lMemberOriginKeys := nil;
  lOriginComparer := TDelphiSemanticSymbolOriginKeyComparer.Create;
  InitializeLookupMaps;

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

constructor TDelphiSemanticProjectSymbolIndexData.CreateSnapshot(
  const aSymbols: TArray<TDelphiSemanticIndexedSymbol>;
  const aReferences: TArray<TDelphiSemanticIndexedReference>);
begin
  inherited Create;
  InitializeLookupMaps;
  AddSnapshotSymbolMaps(aSymbols);
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
  lModel: TDelphiSemanticUnitModel;
  lModels: TDelphiSemanticUnitModelList;
begin
  if aUnitName = '' then
  begin
    lModels := TDelphiSemanticUnitModelList.Create;
    try
      for lModel in fUnitModelsByName.Values do
        lModels.Add(lModel);
      Exit(lModels.ToArray);
    finally
      lModels.Free;
    end;
  end;

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

procedure AddSnapshotUnitSymbol(const aSymbols: TDelphiSemanticSymbolList;
  const aSnapshot: TDelphiProjectSnapshot; const aUnit: TUnitSnapshot);
begin
  if SnapshotText(aSnapshot, aUnit.UnitNameId) = '' then
    Exit;

  aSymbols.Add(SnapshotUnitIndexedSymbol(aSnapshot, aUnit));
end;

procedure AddSnapshotSymbol(const aSymbols: TDelphiSemanticSymbolList;
  const aSnapshot: TDelphiProjectSnapshot; const aUnit: TUnitSnapshot;
  const aSymbolRef: TSemanticSymbolRef; const aSymbol: TSemanticSymbolFact);
begin
  if aSymbol.NameId = 0 then
    Exit;

  aSymbols.Add(SnapshotIndexedSymbol(aSnapshot, aUnit, aSymbolRef, aSymbol));
end;

procedure AddSnapshotSymbols(const aSymbols: TDelphiSemanticSymbolList;
  const aSnapshot: TDelphiProjectSnapshot);
var
  i: Integer;
  lSymbol: TSemanticSymbolFact;
  lSymbolRef: TSemanticSymbolRef;
  lUnit: TUnitSnapshot;
  lUnitIndex: Integer;
begin
  for lUnitIndex := 0 to aSnapshot.UnitCount - 1 do
  begin
    lUnit := aSnapshot.UnitByIndex(lUnitIndex);
    AddSnapshotUnitSymbol(aSymbols, aSnapshot, lUnit);
    for i := 1 to lUnit.SymbolCount do
    begin
      lSymbol := lUnit.SymbolById(TSemanticSymbolId(i));
      lSymbolRef.UnitId := lUnit.UnitId;
      lSymbolRef.SymbolId := lSymbol.Id;
      AddSnapshotSymbol(aSymbols, aSnapshot, lUnit, lSymbolRef, lSymbol);
    end;
  end;
end;

procedure AddSnapshotReferences(const aReferences: TList<TDelphiSemanticIndexedReference>;
  const aSnapshot: TDelphiProjectSnapshot);
var
  i: Integer;
  lIndexedReference: TDelphiSemanticIndexedReference;
  lReference: TSemanticReferenceFact;
  lUnit: TUnitSnapshot;
  lUnitIndex: Integer;
begin
  for lUnitIndex := 0 to aSnapshot.UnitCount - 1 do
  begin
    lUnit := aSnapshot.UnitByIndex(lUnitIndex);
    for i := 1 to lUnit.ReferenceCount do
    begin
      lReference := lUnit.ReferenceById(TSemanticReferenceId(i));
      lIndexedReference := SnapshotIndexedReference(aSnapshot, lUnit, lReference);
      aReferences.Add(lIndexedReference);
    end;
  end;
end;

function BuildSnapshotProjectSymbolIndex(const aSnapshot: TDelphiProjectSnapshot):
  TDelphiSemanticProjectSymbolIndex;
var
  lReferences: TList<TDelphiSemanticIndexedReference>;
  lSymbols: TDelphiSemanticSymbolList;
  lStopwatch: TStopwatch;
begin
  Result := Default(TDelphiSemanticProjectSymbolIndex);
  lStopwatch := TStopwatch.StartNew;
  lSymbols := TDelphiSemanticSymbolList.Create;
  lReferences := TList<TDelphiSemanticIndexedReference>.Create;
  try
    AddSnapshotSymbols(lSymbols, aSnapshot);
    AddSnapshotReferences(lReferences, aSnapshot);
    Result.Symbols := lSymbols.ToArray;
    Result.References := lReferences.ToArray;
    Result.fData := TDelphiSemanticProjectSymbolIndexData.CreateSnapshot(Result.Symbols,
      Result.References);
    Result.Metrics.BuildInvocationCount := 0;
  finally
    lReferences.Free;
    lSymbols.Free;
    Result.Metrics.BuildElapsedMilliseconds := lStopwatch.ElapsedMilliseconds;
  end;
end;

class function TDelphiSemanticProjectSymbolIndexer.Build(
  const aContext: TDelphiSemanticSymbolQueryContext): TDelphiSemanticProjectSymbolIndex;
var
  lMutableData: IDelphiSemanticMutableProjectSymbolIndexData;
  lSnapshot: TDelphiProjectSnapshot;
  lStopwatch: TStopwatch;
begin
  lSnapshot := ContextProjectSnapshot(aContext);
  if lSnapshot <> nil then
    Exit(BuildSnapshotProjectSymbolIndex(lSnapshot));

  Result := Default(TDelphiSemanticProjectSymbolIndex);
  Result.Metrics.BuildInvocationCount := 1;
  lStopwatch := TStopwatch.StartNew;
  try
    Result.Symbols := TDelphiSemanticLegacyModelIndexer.BuildSymbols(aContext);
    Result.References := nil;
    Result.fData := TDelphiSemanticProjectSymbolIndexData.Create(aContext, Result.Symbols, nil);

    Result.References := TDelphiSemanticLegacyModelIndexer.BuildReferences(Result, aContext);
    if Supports(Result.fData, IDelphiSemanticMutableProjectSymbolIndexData, lMutableData) then
      lMutableData.AddReferences(Result.References);
  finally
    Result.Metrics.BuildElapsedMilliseconds := lStopwatch.ElapsedMilliseconds;
  end;
end;

end.
