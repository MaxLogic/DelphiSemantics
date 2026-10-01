unit DelphiSemantics.Refactor.UnitOrder;

interface

uses
  DelphiSemantics.Model;

type
  TDelphiSemanticUnitOrderResult = record
    Known: Boolean;
    Reason: string;
    InitializationOrder: TArray<string>;
    FinalizationOrder: TArray<string>;
  end;

  TDelphiSemanticUnitOrder = record
    class function Analyze(const aModels: TArray<TDelphiSemanticUnitModel>;
      const aRoots: TArray<string>): TDelphiSemanticUnitOrderResult; static;
  end;

implementation

uses
  System.Generics.Collections, System.SysUtils, maxLogic.StrUtils;

type
  TUnitOrderFrame = record
    ModelIndex: Integer;
    NextImport: Integer;
    Imports: TArray<string>;
  end;

  TUnitOrderTraversal = record
    Models: TArray<TDelphiSemanticUnitModel>;
    Index: TDictionary<string, Integer>;
    States: TArray<Byte>;
    Stack: TList<TUnitOrderFrame>;
    Order: TList<string>;
    function EnterUnit(const aName: string): Boolean;
    function VisitRoot(const aRoot: string): Boolean;
  end;

function TUnitOrderTraversal.EnterUnit(const aName: string): Boolean;
var
  lModelIndex: Integer;
  lFrame: TUnitOrderFrame;
begin
  Result := False;
  if not Index.TryGetValue(LowerCase(aName), lModelIndex) then
    Exit;
  if States[lModelIndex] = 1 then
    Exit;
  if States[lModelIndex] = 2 then
    Exit(True);
  if not Models[lModelIndex].Success or not Models[lModelIndex].DependencyFacts.Known then
    Exit;
  lFrame := Default(TUnitOrderFrame);
  lFrame.ModelIndex := lModelIndex;
  lFrame.Imports := Models[lModelIndex].DependencyFacts.RootImports +
    Models[lModelIndex].DependencyFacts.InterfaceImports +
    Models[lModelIndex].DependencyFacts.ImplementationImports;
  States[lModelIndex] := 1;
  Stack.Add(lFrame);
  Result := True;
end;

function TUnitOrderTraversal.VisitRoot(const aRoot: string): Boolean;
var
  lFrame: TUnitOrderFrame;
  lImport: string;
begin
  Result := False;
  if not EnterUnit(aRoot) then
    Exit;
  while Stack.Count > 0 do
  begin
    lFrame := Stack.Last;
    if lFrame.NextImport < Length(lFrame.Imports) then
    begin
      lImport := lFrame.Imports[lFrame.NextImport];
      Inc(lFrame.NextImport);
      Stack[Stack.Count - 1] := lFrame;
      if not EnterUnit(lImport) then
        Exit;
    end else begin
      States[lFrame.ModelIndex] := 2;
      Order.Add(Models[lFrame.ModelIndex].UnitName);
      Stack.Delete(Stack.Count - 1);
    end;
  end;
  Result := True;
end;

class function TDelphiSemanticUnitOrder.Analyze(
  const aModels: TArray<TDelphiSemanticUnitModel>;
  const aRoots: TArray<string>): TDelphiSemanticUnitOrderResult;
var
  lTraversal: TUnitOrderTraversal;
  lRoot: string;
  i: Integer;
begin
  Result := Default(TDelphiSemanticUnitOrderResult);
  Result.Reason := 'uses.order-unresolved';
  if Length(aRoots) = 0 then
    Exit;
  lTraversal := Default(TUnitOrderTraversal);
  lTraversal.Models := aModels;
  lTraversal.Index := TDictionary<string, Integer>.Create(TFastCaseAwareComparer.Ordinal);
  lTraversal.Stack := nil;
  lTraversal.Order := nil;
  try
    lTraversal.Stack := TList<TUnitOrderFrame>.Create;
    lTraversal.Order := TList<string>.Create;
    SetLength(lTraversal.States, Length(aModels));
    for i := 0 to High(aModels) do
    begin
      if (Trim(aModels[i].UnitName) = '') or
        lTraversal.Index.ContainsKey(LowerCase(aModels[i].UnitName)) then
        Exit;
      lTraversal.Index.Add(LowerCase(aModels[i].UnitName), i);
    end;
    for lRoot in aRoots do
      if not lTraversal.VisitRoot(lRoot) then
        Exit;
    // Keep all units: managed state can matter without explicit lifecycle sections.
    Result.InitializationOrder := lTraversal.Order.ToArray;
    SetLength(Result.FinalizationOrder, lTraversal.Order.Count);
    for i := 0 to lTraversal.Order.Count - 1 do
      Result.FinalizationOrder[i] := lTraversal.Order[lTraversal.Order.Count - i - 1];
    Result.Known := True;
    Result.Reason := '';
  finally
    lTraversal.Order.Free;
    lTraversal.Stack.Free;
    lTraversal.Index.Free;
  end;
end;

end.