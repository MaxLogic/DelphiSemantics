unit DelphiSemantics.RemoveWith.Visibility;

interface

uses
  System.Classes, System.Generics.Collections,
  DelphiSemantics.Model, DelphiSemantics.Snapshot;

const
  cRemoveWithVisibilityExtensionName = 'DelphiSemantics.RemoveWithVisibility';

type
  TRemoveWithVisibleUnit = record
    FileName: string;
    UnitName: string;
  end;

  TRemoveWithUnitVisibility = class
  private
    fPairCount: Integer;
    fUnits: TObjectDictionary<string, TStringList>;
    procedure AddVisibleUnit(const aFileName, aUnitName: string);
    function GetUnitCount: Integer;
  public
    constructor Create(const aModels: TArray<TDelphiSemanticUnitModel>); overload;
    constructor Create(const aRows: TArray<TRemoveWithVisibleUnit>); overload;
    destructor Destroy; override;
    function HasUnit(const aFileName: string): Boolean;
    function IsUnitVisible(const aFileName, aDeclaringUnitName: string): Boolean;
    function Rows: TArray<TRemoveWithVisibleUnit>;
    property PairCount: Integer read fPairCount;
    property UnitCount: Integer read GetUnitCount;
  end;

procedure AttachRemoveWithVisibility(const aBuilder: TDelphiProjectSnapshotBuilder;
  const aModels: TArray<TDelphiSemanticUnitModel>);
function TryGetRemoveWithVisibility(const aSnapshot: TDelphiProjectSnapshot;
  out aVisibility: TRemoveWithUnitVisibility): Boolean;

implementation

uses
  System.SysUtils,
  MaxLogic.StrUtils,
  DelphiSemantics.Cache;

constructor TRemoveWithUnitVisibility.Create(
  const aModels: TArray<TDelphiSemanticUnitModel>);
var
  lModel: TDelphiSemanticUnitModel;
  lUnitName: string;
begin
  inherited Create;
  fUnits := TObjectDictionary<string, TStringList>.Create([doOwnsValues],
    TFastCaseAwareComparer.OrdinalIgnoreCase);
  for lModel in aModels do
  begin
    if (Trim(lModel.FileName) = '') or (Trim(lModel.UnitName) = '') then
      Continue;
    AddVisibleUnit(lModel.FileName, lModel.UnitName);
    for lUnitName in lModel.InterfaceUses do
      AddVisibleUnit(lModel.FileName, lUnitName);
    for lUnitName in lModel.ImplementationUses do
      AddVisibleUnit(lModel.FileName, lUnitName);
  end;
end;

constructor TRemoveWithUnitVisibility.Create(
  const aRows: TArray<TRemoveWithVisibleUnit>);
var
  lRow: TRemoveWithVisibleUnit;
begin
  inherited Create;
  fUnits := TObjectDictionary<string, TStringList>.Create([doOwnsValues],
    TFastCaseAwareComparer.OrdinalIgnoreCase);
  for lRow in aRows do
  begin
    if (Trim(lRow.FileName) = '') or (Trim(lRow.UnitName) = '') then
      raise Exception.Create('Invalid remove-with visibility row.');
    AddVisibleUnit(lRow.FileName, lRow.UnitName);
  end;
  if fPairCount <> Length(aRows) then
    raise Exception.Create('Duplicate remove-with visibility rows.');
end;

destructor TRemoveWithUnitVisibility.Destroy;
begin
  fUnits.Free;
  inherited;
end;

procedure TRemoveWithUnitVisibility.AddVisibleUnit(const aFileName, aUnitName: string);
var
  lFileName: string;
  lNames: TStringList;
  lUnitName: string;
begin
  lUnitName := Trim(aUnitName);
  if lUnitName = '' then
    Exit;
  lFileName := TDelphiSemanticCacheIdentityBuilder.CanonicalPath(aFileName);
  if not fUnits.TryGetValue(lFileName, lNames) then
  begin
    lNames := TStringList.Create;
    try
      lNames.CaseSensitive := False;
      lNames.Sorted := True;
      lNames.Duplicates := dupIgnore;
      fUnits.Add(lFileName, lNames);
    except
      lNames.Free;
      raise;
    end;
  end;
  if lNames.IndexOf(lUnitName) < 0 then
  begin
    lNames.Add(lUnitName);
    Inc(fPairCount);
  end;
end;

function TRemoveWithUnitVisibility.GetUnitCount: Integer;
begin
  Result := fUnits.Count;
end;

function TRemoveWithUnitVisibility.HasUnit(const aFileName: string): Boolean;
begin
  Result := fUnits.ContainsKey(TDelphiSemanticCacheIdentityBuilder.CanonicalPath(aFileName));
end;

function TRemoveWithUnitVisibility.IsUnitVisible(const aFileName,
  aDeclaringUnitName: string): Boolean;
var
  lNames: TStringList;
begin
  Result := fUnits.TryGetValue(TDelphiSemanticCacheIdentityBuilder.CanonicalPath(aFileName), lNames)
    and (lNames.IndexOf(aDeclaringUnitName) >= 0);
end;

function TRemoveWithUnitVisibility.Rows: TArray<TRemoveWithVisibleUnit>;
var
  i: Integer;
  lFileName: string;
  lFileNames: TStringList;
  lNames: TStringList;
  lUnitName: string;
begin
  SetLength(Result, fPairCount);
  lFileNames := TStringList.Create;
  try
    lFileNames.Sorted := True;
    for lFileName in fUnits.Keys do
      lFileNames.Add(lFileName);
    i := 0;
    for lFileName in lFileNames do
    begin
      lNames := fUnits[lFileName];
      for lUnitName in lNames do
      begin
        Result[i].FileName := lFileName;
        Result[i].UnitName := lUnitName;
        Inc(i);
      end;
    end;
  finally
    lFileNames.Free;
  end;
end;

procedure AttachRemoveWithVisibility(const aBuilder: TDelphiProjectSnapshotBuilder;
  const aModels: TArray<TDelphiSemanticUnitModel>);
var
  lVisibility: TRemoveWithUnitVisibility;
begin
  lVisibility := TRemoveWithUnitVisibility.Create(aModels);
  try
    aBuilder.SetExtensionOwned(cRemoveWithVisibilityExtensionName, lVisibility);
    lVisibility := nil;
  finally
    lVisibility.Free;
  end;
end;

function TryGetRemoveWithVisibility(const aSnapshot: TDelphiProjectSnapshot;
  out aVisibility: TRemoveWithUnitVisibility): Boolean;
var
  lExtension: TObject;
begin
  aVisibility := nil;
  Result := (aSnapshot <> nil) and
    aSnapshot.TryGetExtension(cRemoveWithVisibilityExtensionName, lExtension) and
    (lExtension is TRemoveWithUnitVisibility);
  if Result then
    aVisibility := lExtension as TRemoveWithUnitVisibility;
end;

end.
