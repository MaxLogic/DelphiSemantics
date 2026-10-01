unit DelphiSemantics.Consistency.GuidInventory;

interface

uses
  DelphiSemantics.Model;

type
  TDelphiSemanticGuidStatus = (gsUnique, gsValidPair, gsDuplicate, gsMissingGuid, gsUnknown);

  TDelphiSemanticGuidInventoryItem = record
    UnitName: string;
    FileName: string;
    Name: string;
    Guid: string;
    TypeName: string;
    IsDispInterface: Boolean;
    Status: TDelphiSemanticGuidStatus;
  end;

  TDelphiSemanticGuidInventory = record
    Items: TArray<TDelphiSemanticGuidInventoryItem>;
    Complete: Boolean;
    Reason: string;
  end;

  TDelphiSemanticGuidInventoryPlanner = record
    class function Inspect(const aModels: TArray<TDelphiSemanticUnitModel>):
      TDelphiSemanticGuidInventory; static;
  end;

implementation

uses
  System.Generics.Collections, System.RegularExpressions, System.SysUtils;

class function TDelphiSemanticGuidInventoryPlanner.Inspect(
  const aModels: TArray<TDelphiSemanticUnitModel>): TDelphiSemanticGuidInventory;
const
  cGuidPattern = '^\{[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-' +
    '[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}\}$';
var
  i: Integer;
  j: Integer;
  lCount: Integer;
  lDeclaration: TDelphiSemanticDeclaration;
  lDispCount: Integer;
  lGuid: string;
  lHasUnknown: Boolean;
  lItem: TDelphiSemanticGuidInventoryItem;
  lItems: TList<TDelphiSemanticGuidInventoryItem>;
  lModel: TDelphiSemanticUnitModel;
begin
  Result := Default(TDelphiSemanticGuidInventory);
  Result.Complete := Length(aModels) > 0;
  if not Result.Complete then
    Result.Reason := 'model.missing';
  lItems := TList<TDelphiSemanticGuidInventoryItem>.Create;
  try
    for lModel in aModels do
    begin
      if not lModel.Success or not SameText(lModel.ScopeModelStatus, 'ast') or
        (lModel.RejectedDeclarationCount > 0) then
      begin
        Result.Complete := False;
        Result.Reason := 'model.incomplete';
      end;
      for lDeclaration in lModel.Declarations do
      begin
        if not SameText(lDeclaration.Kind, 'type') or
          not (SameText(lDeclaration.TypeName, 'interface') or
          lDeclaration.IsDispInterface) then
          Continue;
        lItem := Default(TDelphiSemanticGuidInventoryItem);
        lItem.UnitName := lModel.UnitName;
        lItem.FileName := lModel.FileName;
        lItem.Name := lDeclaration.Name;
        lItem.Guid := Trim(lDeclaration.InterfaceGuid);
        lItem.TypeName := lDeclaration.TypeName;
        lItem.IsDispInterface := lDeclaration.IsDispInterface;
        if not SameText(lDeclaration.DeclarationRole, 'declaration') or
          not SameText(lDeclaration.ScopeKind, 'unit') then
          lItem.Status := TDelphiSemanticGuidStatus.gsUnknown
        else if lItem.Guid = '' then
          lItem.Status := TDelphiSemanticGuidStatus.gsMissingGuid
        else if not TRegEx.IsMatch(lItem.Guid, cGuidPattern) then
          lItem.Status := TDelphiSemanticGuidStatus.gsUnknown
        else
          lItem.Status := TDelphiSemanticGuidStatus.gsUnique;
        lItems.Add(lItem);
      end;
    end;
    Result.Items := lItems.ToArray;
  finally
    lItems.Free;
  end;

  for i := 0 to High(Result.Items) do
  begin
    if not Result.Complete then
    begin
      Result.Items[i].Status := TDelphiSemanticGuidStatus.gsUnknown;
      Continue;
    end;
    if Result.Items[i].Status <> TDelphiSemanticGuidStatus.gsUnique then
      Continue;
    lGuid := Result.Items[i].Guid;
    lCount := 0;
    lDispCount := 0;
    lHasUnknown := False;
    for j := 0 to High(Result.Items) do
      if SameText(Result.Items[j].Guid, lGuid) then
      begin
        Inc(lCount);
        if Result.Items[j].IsDispInterface then
          Inc(lDispCount);
        if Result.Items[j].Status = TDelphiSemanticGuidStatus.gsUnknown then
          lHasUnknown := True;
      end;
    if lHasUnknown then
      Result.Items[i].Status := TDelphiSemanticGuidStatus.gsUnknown
    else if lCount = 1 then
      Result.Items[i].Status := TDelphiSemanticGuidStatus.gsUnique
    else if (lCount = 2) and (lDispCount = 1) then
      Result.Items[i].Status := TDelphiSemanticGuidStatus.gsValidPair
    else
      Result.Items[i].Status := TDelphiSemanticGuidStatus.gsDuplicate;
  end;
end;

end.
