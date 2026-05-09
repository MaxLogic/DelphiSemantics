unit DelphiSemantics.Graph;

interface

uses
  DelphiSemantics.Model;

type
  TDelphiSemanticDependencyGraphOptions = record
    SearchPaths: TArray<string>;
  end;

  TDelphiSemanticDependencyNode = record
    UnitName: string;
    FileName: string;
    Status: string;
    IsProjectUnit: Boolean;
    IsExternal: Boolean;
    IsUnresolved: Boolean;
    InCycle: Boolean;
  end;

  TDelphiSemanticDependencyEdge = record
    SourceUnit: string;
    TargetUnit: string;
    SectionKind: string;
    TargetStatus: string;
    IsCycleEdge: Boolean;
  end;

  TDelphiSemanticDependencyCycleComponent = record
    Units: TArray<string>;
    Path: TArray<string>;
  end;

  TDelphiSemanticDependencyUnitHotspot = record
    UnitName: string;
    Score: Integer;
  end;

  TDelphiSemanticDependencyEdgeHotspot = record
    SourceUnit: string;
    TargetUnit: string;
    SectionKind: string;
    Score: Integer;
  end;

  TDelphiSemanticDependencyGraph = record
    Nodes: TArray<TDelphiSemanticDependencyNode>;
    Edges: TArray<TDelphiSemanticDependencyEdge>;
    UnresolvedUnits: TArray<string>;
    CycleComponents: TArray<TDelphiSemanticDependencyCycleComponent>;
    UnitHotspots: TArray<TDelphiSemanticDependencyUnitHotspot>;
    EdgeHotspots: TArray<TDelphiSemanticDependencyEdgeHotspot>;
  end;

  TDelphiSemanticDependencyGraphBuilder = record
  public
    class function Build(const aModels: TArray<TDelphiSemanticUnitModel>;
      const aOptions: TDelphiSemanticDependencyGraphOptions): TDelphiSemanticDependencyGraph; static;
  end;

  TDelphiSemanticDependencyGraphQuery = record
  public
    class function FocusNeighborhood(const aGraph: TDelphiSemanticDependencyGraph;
      const aUnitName: string): TArray<string>; static;
  end;

implementation

uses
  System.Generics.Collections, System.Generics.Defaults, System.IOUtils, System.SysUtils;

function SameUnit(const aLeft, aRight: string): Boolean;
begin
  Result := SameText(aLeft, aRight);
end;

function ContainsUnit(const aUnits: TArray<string>; const aUnitName: string): Boolean;
var
  lUnit: string;
begin
  for lUnit in aUnits do
    if SameUnit(lUnit, aUnitName) then
      Exit(True);

  Result := False;
end;

procedure AddUniqueUnit(const aUnits: TList<string>; const aUnitName: string);
var
  lUnit: string;
begin
  for lUnit in aUnits do
    if SameUnit(lUnit, aUnitName) then
      Exit;
  aUnits.Add(aUnitName);
end;

function FindNodeIndex(const aNodes: TList<TDelphiSemanticDependencyNode>;
  const aUnitName: string): Integer;
var
  i: Integer;
begin
  for i := 0 to Pred(aNodes.Count) do
    if SameUnit(aNodes[i].UnitName, aUnitName) then
      Exit(i);

  Result := -1;
end;

function FindModel(const aModels: TArray<TDelphiSemanticUnitModel>; const aUnitName: string;
  out aModel: TDelphiSemanticUnitModel): Boolean;
var
  lModel: TDelphiSemanticUnitModel;
begin
  for lModel in aModels do
    if SameUnit(lModel.UnitName, aUnitName) then
    begin
      aModel := lModel;
      Exit(True);
    end;

  aModel := Default(TDelphiSemanticUnitModel);
  Result := False;
end;

function FindExternalFile(const aOptions: TDelphiSemanticDependencyGraphOptions;
  const aUnitName: string): string;
var
  lPath: string;
  lSearchPath: string;
begin
  for lSearchPath in aOptions.SearchPaths do
  begin
    lPath := TPath.Combine(lSearchPath, aUnitName + '.pas');
    if TFile.Exists(lPath) then
      Exit(TPath.GetFullPath(lPath));
  end;

  Result := '';
end;

procedure AddNode(const aNodes: TList<TDelphiSemanticDependencyNode>;
  const aNode: TDelphiSemanticDependencyNode);
begin
  if FindNodeIndex(aNodes, aNode.UnitName) < 0 then
    aNodes.Add(aNode);
end;

function ProjectNode(const aModel: TDelphiSemanticUnitModel): TDelphiSemanticDependencyNode;
begin
  Result := Default(TDelphiSemanticDependencyNode);
  Result.UnitName := aModel.UnitName;
  Result.FileName := aModel.FileName;
  Result.Status := 'project';
  Result.IsProjectUnit := True;
end;

function ExternalNode(const aUnitName, aFileName: string): TDelphiSemanticDependencyNode;
begin
  Result := Default(TDelphiSemanticDependencyNode);
  Result.UnitName := aUnitName;
  Result.FileName := aFileName;
  Result.Status := 'external';
  Result.IsExternal := True;
end;

function UnresolvedNode(const aUnitName: string): TDelphiSemanticDependencyNode;
begin
  Result := Default(TDelphiSemanticDependencyNode);
  Result.UnitName := aUnitName;
  Result.Status := 'unresolved';
  Result.IsUnresolved := True;
end;

function ResolveTargetNode(const aModels: TArray<TDelphiSemanticUnitModel>;
  const aOptions: TDelphiSemanticDependencyGraphOptions; const aUnitName: string):
  TDelphiSemanticDependencyNode;
var
  lExternalFile: string;
  lModel: TDelphiSemanticUnitModel;
begin
  if FindModel(aModels, aUnitName, lModel) then
    Exit(ProjectNode(lModel));

  lExternalFile := FindExternalFile(aOptions, aUnitName);
  if lExternalFile <> '' then
    Exit(ExternalNode(aUnitName, lExternalFile));

  Result := UnresolvedNode(aUnitName);
end;

procedure AddEdge(const aEdges: TList<TDelphiSemanticDependencyEdge>; const aSourceUnit,
  aTargetUnit, aSectionKind, aTargetStatus: string);
var
  lEdge: TDelphiSemanticDependencyEdge;
begin
  lEdge := Default(TDelphiSemanticDependencyEdge);
  lEdge.SourceUnit := aSourceUnit;
  lEdge.TargetUnit := aTargetUnit;
  lEdge.SectionKind := aSectionKind;
  lEdge.TargetStatus := aTargetStatus;
  aEdges.Add(lEdge);
end;

function IsProjectUnit(const aModels: TArray<TDelphiSemanticUnitModel>;
  const aUnitName: string): Boolean;
var
  lModel: TDelphiSemanticUnitModel;
begin
  Result := FindModel(aModels, aUnitName, lModel);
end;

function FindPath(const aEdges: TList<TDelphiSemanticDependencyEdge>;
  const aModels: TArray<TDelphiSemanticUnitModel>; const aStartUnit, aTargetUnit: string;
  out aPath: TArray<string>): Boolean;
var
  lPath: TList<string>;
  lVisited: TList<string>;

  function IsVisited(const aUnitName: string): Boolean;
  var
    lUnit: string;
  begin
    for lUnit in lVisited do
      if SameUnit(lUnit, aUnitName) then
        Exit(True);
    Result := False;
  end;

  function Visit(const aUnitName: string): Boolean;
  var
    lEdge: TDelphiSemanticDependencyEdge;
  begin
    AddUniqueUnit(lVisited, aUnitName);
    lPath.Add(aUnitName);
    if SameUnit(aUnitName, aTargetUnit) then
      Exit(True);

    for lEdge in aEdges do
      if SameUnit(lEdge.SourceUnit, aUnitName) and IsProjectUnit(aModels, lEdge.TargetUnit) and
        not IsVisited(lEdge.TargetUnit) then
        if Visit(lEdge.TargetUnit) then
          Exit(True);

    lPath.Delete(Pred(lPath.Count));
    Result := False;
  end;

begin
  lPath := TList<string>.Create;
  lVisited := TList<string>.Create;
  try
    Result := Visit(aStartUnit);
    if Result then
      aPath := lPath.ToArray
    else
      aPath := [];
  finally
    lVisited.Free;
    lPath.Free;
  end;
end;

procedure MarkCycles(const aNodes: TList<TDelphiSemanticDependencyNode>;
  const aEdges: TList<TDelphiSemanticDependencyEdge>;
  const aModels: TArray<TDelphiSemanticUnitModel>);
var
  i: Integer;
  lBackPath: TArray<string>;
  lEdge: TDelphiSemanticDependencyEdge;
  lNode: TDelphiSemanticDependencyNode;
  lNodeIndex: Integer;
begin
  for i := 0 to Pred(aEdges.Count) do
  begin
    lEdge := aEdges[i];
    if IsProjectUnit(aModels, lEdge.SourceUnit) and IsProjectUnit(aModels, lEdge.TargetUnit) and
      FindPath(aEdges, aModels, lEdge.TargetUnit, lEdge.SourceUnit, lBackPath) then
    begin
      lEdge.IsCycleEdge := True;
      aEdges[i] := lEdge;
      lNodeIndex := FindNodeIndex(aNodes, lEdge.SourceUnit);
      if lNodeIndex >= 0 then
      begin
        lNode := aNodes[lNodeIndex];
        lNode.InCycle := True;
        aNodes[lNodeIndex] := lNode;
      end;
      lNodeIndex := FindNodeIndex(aNodes, lEdge.TargetUnit);
      if lNodeIndex >= 0 then
      begin
        lNode := aNodes[lNodeIndex];
        lNode.InCycle := True;
        aNodes[lNodeIndex] := lNode;
      end;
    end;
  end;
end;

function ComponentIndexForUnit(
  const aComponents: TList<TDelphiSemanticDependencyCycleComponent>;
  const aUnitName: string): Integer;
var
  i: Integer;
begin
  for i := 0 to Pred(aComponents.Count) do
    if ContainsUnit(aComponents[i].Units, aUnitName) then
      Exit(i);

  Result := -1;
end;

procedure MergeComponentUnits(var aComponent: TDelphiSemanticDependencyCycleComponent;
  const aUnits: TArray<string>);
var
  lList: TList<string>;
  lUnit: string;
begin
  lList := TList<string>.Create;
  try
    for lUnit in aComponent.Units do
      AddUniqueUnit(lList, lUnit);
    for lUnit in aUnits do
      AddUniqueUnit(lList, lUnit);
    aComponent.Units := lList.ToArray;
  finally
    lList.Free;
  end;
end;

function CyclePathForEdge(const aEdges: TList<TDelphiSemanticDependencyEdge>;
  const aModels: TArray<TDelphiSemanticUnitModel>;
  const aEdge: TDelphiSemanticDependencyEdge): TArray<string>;
var
  lBackPath: TArray<string>;
  lList: TList<string>;
  lUnit: string;
begin
  lList := TList<string>.Create;
  try
    lList.Add(aEdge.SourceUnit);
    if FindPath(aEdges, aModels, aEdge.TargetUnit, aEdge.SourceUnit, lBackPath) then
      for lUnit in lBackPath do
        lList.Add(lUnit);
    Result := lList.ToArray;
  finally
    lList.Free;
  end;
end;

function BuildCycleComponents(const aEdges: TList<TDelphiSemanticDependencyEdge>;
  const aModels: TArray<TDelphiSemanticUnitModel>):
  TArray<TDelphiSemanticDependencyCycleComponent>;
var
  i: Integer;
  lComponent: TDelphiSemanticDependencyCycleComponent;
  lComponents: TList<TDelphiSemanticDependencyCycleComponent>;
  lEdge: TDelphiSemanticDependencyEdge;
  lIndex: Integer;
  lTargetIndex: Integer;
begin
  lComponents := TList<TDelphiSemanticDependencyCycleComponent>.Create;
  try
    for lEdge in aEdges do
      if lEdge.IsCycleEdge then
      begin
        lIndex := ComponentIndexForUnit(lComponents, lEdge.SourceUnit);
        lTargetIndex := ComponentIndexForUnit(lComponents, lEdge.TargetUnit);
        if (lIndex >= 0) and (lTargetIndex >= 0) and (lIndex <> lTargetIndex) then
        begin
          lComponent := lComponents[lIndex];
          MergeComponentUnits(lComponent, lComponents[lTargetIndex].Units);
          if Length(lComponent.Path) = 0 then
            lComponent.Path := lComponents[lTargetIndex].Path;
          lComponents[lIndex] := lComponent;
          lComponents.Delete(lTargetIndex);
          Continue;
        end else if lIndex < 0 then
          lIndex := lTargetIndex;
        if lIndex < 0 then
        begin
          lComponent := Default(TDelphiSemanticDependencyCycleComponent);
          lComponent.Units := [lEdge.SourceUnit, lEdge.TargetUnit];
          lComponent.Path := CyclePathForEdge(aEdges, aModels, lEdge);
          lComponents.Add(lComponent);
        end else
        begin
          lComponent := lComponents[lIndex];
          MergeComponentUnits(lComponent, [lEdge.SourceUnit, lEdge.TargetUnit]);
          if Length(lComponent.Path) = 0 then
            lComponent.Path := CyclePathForEdge(aEdges, aModels, lEdge);
          lComponents[lIndex] := lComponent;
        end;
      end;

    for i := 0 to Pred(lComponents.Count) do
    begin
      lComponent := lComponents[i];
      TArray.Sort<string>(lComponent.Units, TComparer<string>.Construct(
        function(const aLeft, aRight: string): Integer
        begin
          Result := CompareText(aLeft, aRight);
        end));
      lComponents[i] := lComponent;
    end;
    Result := lComponents.ToArray;
  finally
    lComponents.Free;
  end;
end;

function FindUnitHotspotIndex(const aHotspots: TList<TDelphiSemanticDependencyUnitHotspot>;
  const aUnitName: string): Integer;
var
  i: Integer;
begin
  for i := 0 to Pred(aHotspots.Count) do
    if SameUnit(aHotspots[i].UnitName, aUnitName) then
      Exit(i);

  Result := -1;
end;

procedure IncrementUnitHotspot(const aHotspots: TList<TDelphiSemanticDependencyUnitHotspot>;
  const aUnitName: string);
var
  lHotspot: TDelphiSemanticDependencyUnitHotspot;
  lIndex: Integer;
begin
  lIndex := FindUnitHotspotIndex(aHotspots, aUnitName);
  if lIndex >= 0 then
  begin
    lHotspot := aHotspots[lIndex];
    Inc(lHotspot.Score);
    aHotspots[lIndex] := lHotspot;
  end else
  begin
    lHotspot := Default(TDelphiSemanticDependencyUnitHotspot);
    lHotspot.UnitName := aUnitName;
    lHotspot.Score := 1;
    aHotspots.Add(lHotspot);
  end;
end;

function BuildUnitHotspots(const aEdges: TList<TDelphiSemanticDependencyEdge>):
  TArray<TDelphiSemanticDependencyUnitHotspot>;
var
  lEdge: TDelphiSemanticDependencyEdge;
  lHotspots: TList<TDelphiSemanticDependencyUnitHotspot>;
begin
  lHotspots := TList<TDelphiSemanticDependencyUnitHotspot>.Create;
  try
    for lEdge in aEdges do
      if lEdge.IsCycleEdge then
      begin
        IncrementUnitHotspot(lHotspots, lEdge.SourceUnit);
        IncrementUnitHotspot(lHotspots, lEdge.TargetUnit);
      end;
    lHotspots.Sort(TComparer<TDelphiSemanticDependencyUnitHotspot>.Construct(
      function(const aLeft, aRight: TDelphiSemanticDependencyUnitHotspot): Integer
      begin
        Result := aRight.Score - aLeft.Score;
        if Result = 0 then
          Result := CompareText(aLeft.UnitName, aRight.UnitName);
      end));
    Result := lHotspots.ToArray;
  finally
    lHotspots.Free;
  end;
end;

function BuildEdgeHotspots(const aEdges: TList<TDelphiSemanticDependencyEdge>):
  TArray<TDelphiSemanticDependencyEdgeHotspot>;
var
  lEdge: TDelphiSemanticDependencyEdge;
  lHotspot: TDelphiSemanticDependencyEdgeHotspot;
  lHotspots: TList<TDelphiSemanticDependencyEdgeHotspot>;
begin
  lHotspots := TList<TDelphiSemanticDependencyEdgeHotspot>.Create;
  try
    for lEdge in aEdges do
      if lEdge.IsCycleEdge then
      begin
        lHotspot := Default(TDelphiSemanticDependencyEdgeHotspot);
        lHotspot.SourceUnit := lEdge.SourceUnit;
        lHotspot.TargetUnit := lEdge.TargetUnit;
        lHotspot.SectionKind := lEdge.SectionKind;
        lHotspot.Score := 1;
        lHotspots.Add(lHotspot);
      end;
    lHotspots.Sort(TComparer<TDelphiSemanticDependencyEdgeHotspot>.Construct(
      function(const aLeft, aRight: TDelphiSemanticDependencyEdgeHotspot): Integer
      begin
        Result := aRight.Score - aLeft.Score;
        if Result = 0 then
          Result := Ord(SameText(aRight.SectionKind, 'implementation')) -
            Ord(SameText(aLeft.SectionKind, 'implementation'));
        if Result = 0 then
          Result := CompareText(aLeft.SourceUnit, aRight.SourceUnit);
        if Result = 0 then
          Result := CompareText(aLeft.TargetUnit, aRight.TargetUnit);
      end));
    Result := lHotspots.ToArray;
  finally
    lHotspots.Free;
  end;
end;

procedure AddUsesEdges(const aModels: TArray<TDelphiSemanticUnitModel>;
  const aOptions: TDelphiSemanticDependencyGraphOptions;
  const aNodes: TList<TDelphiSemanticDependencyNode>;
  const aEdges: TList<TDelphiSemanticDependencyEdge>;
  const aUnresolvedUnits: TList<string>; const aModel: TDelphiSemanticUnitModel;
  const aUses: TArray<string>; const aSectionKind: string);
var
  lTargetNode: TDelphiSemanticDependencyNode;
  lUnit: string;
begin
  for lUnit in aUses do
  begin
    lTargetNode := ResolveTargetNode(aModels, aOptions, lUnit);
    AddNode(aNodes, lTargetNode);
    if lTargetNode.IsUnresolved then
      AddUniqueUnit(aUnresolvedUnits, lTargetNode.UnitName);
    AddEdge(aEdges, aModel.UnitName, lTargetNode.UnitName, aSectionKind, lTargetNode.Status);
  end;
end;

class function TDelphiSemanticDependencyGraphBuilder.Build(
  const aModels: TArray<TDelphiSemanticUnitModel>;
  const aOptions: TDelphiSemanticDependencyGraphOptions): TDelphiSemanticDependencyGraph;
var
  lEdges: TList<TDelphiSemanticDependencyEdge>;
  lModel: TDelphiSemanticUnitModel;
  lNodes: TList<TDelphiSemanticDependencyNode>;
  lUnresolvedUnits: TList<string>;
begin
  lNodes := TList<TDelphiSemanticDependencyNode>.Create;
  lEdges := TList<TDelphiSemanticDependencyEdge>.Create;
  lUnresolvedUnits := TList<string>.Create;
  try
    for lModel in aModels do
      if lModel.UnitName <> '' then
        AddNode(lNodes, ProjectNode(lModel));
    for lModel in aModels do
      if lModel.UnitName <> '' then
      begin
        AddUsesEdges(aModels, aOptions, lNodes, lEdges, lUnresolvedUnits, lModel,
          lModel.InterfaceUses, 'interface');
        AddUsesEdges(aModels, aOptions, lNodes, lEdges, lUnresolvedUnits, lModel,
          lModel.ImplementationUses, 'implementation');
      end;

    MarkCycles(lNodes, lEdges, aModels);
    Result.Nodes := lNodes.ToArray;
    Result.Edges := lEdges.ToArray;
    Result.UnresolvedUnits := lUnresolvedUnits.ToArray;
    Result.CycleComponents := BuildCycleComponents(lEdges, aModels);
    Result.UnitHotspots := BuildUnitHotspots(lEdges);
    Result.EdgeHotspots := BuildEdgeHotspots(lEdges);
  finally
    lUnresolvedUnits.Free;
    lEdges.Free;
    lNodes.Free;
  end;
end;

class function TDelphiSemanticDependencyGraphQuery.FocusNeighborhood(
  const aGraph: TDelphiSemanticDependencyGraph; const aUnitName: string): TArray<string>;
var
  lEdge: TDelphiSemanticDependencyEdge;
  lNode: TDelphiSemanticDependencyNode;
  lUnits: TList<string>;
begin
  lUnits := TList<string>.Create;
  try
    for lNode in aGraph.Nodes do
      if SameUnit(lNode.UnitName, aUnitName) then
      begin
        lUnits.Add(lNode.UnitName);
        Break;
      end;
    if lUnits.Count = 0 then
    begin
      SetLength(Result, 0);
      Exit;
    end;

    for lEdge in aGraph.Edges do
    begin
      if SameUnit(lEdge.SourceUnit, aUnitName) then
        AddUniqueUnit(lUnits, lEdge.TargetUnit);
      if SameUnit(lEdge.TargetUnit, aUnitName) then
        AddUniqueUnit(lUnits, lEdge.SourceUnit);
    end;
    Result := lUnits.ToArray;
  finally
    lUnits.Free;
  end;
end;

end.
