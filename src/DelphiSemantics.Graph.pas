unit DelphiSemantics.Graph;

interface

uses
  DelphiSemantics.Model;

type
  TDelphiSemanticTypedSccEdge = record
    EdgeId: Integer;
    SourceNodeId: Integer;
    TargetNodeId: Integer;
  end;

  TDelphiSemanticTypedSccComponent = record
    SccId: Integer;
    NodeIds: TArray<Integer>;
    EdgeIds: TArray<Integer>;
    RepresentativePath: TArray<Integer>;
  end;

  TDelphiSemanticTypedSccResult = record
    Components: TArray<TDelphiSemanticTypedSccComponent>;
    NodeSccIds: TArray<Integer>;
    EdgeSccIds: TArray<Integer>;
  end;

  TDelphiSemanticTypedSccAnalyzer = record
  public
    class function Analyze(const aNodeCount: Integer;
      const aEdges: TArray<TDelphiSemanticTypedSccEdge>):
      TDelphiSemanticTypedSccResult; static;
  end;

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

class function TDelphiSemanticTypedSccAnalyzer.Analyze(const aNodeCount: Integer;
  const aEdges: TArray<TDelphiSemanticTypedSccEdge>): TDelphiSemanticTypedSccResult;
type
  TAdjacencyEdge = record
    EdgeId: Integer;
    TargetNodeId: Integer;
  end;
  TPathFrame = record
    NodeId: Integer;
    NextEdgeIndex: Integer;
  end;
var
  lAdjacency: TArray<TList<TAdjacencyEdge>>;
  lComponents: TList<TDelphiSemanticTypedSccComponent>;
  lCurrentIndex: Integer;
  lAdjacencyEdge: TAdjacencyEdge;
  lEdgeTargetComparer: IComparer<TAdjacencyEdge>;
  lEdge: TDelphiSemanticTypedSccEdge;
  lIndexes: TArray<Integer>;
  lLowLinks: TArray<Integer>;
  lMaxEdgeId: Integer;
  lNodeId: Integer;
  lOnStack: TArray<Boolean>;
  lResultComponent: TDelphiSemanticTypedSccComponent;
  lResultEdgeId: Integer;
  lStack: TStack<Integer>;

  function TryBuildIterativePath(const aStartNodeId, aRootNodeId: Integer;
    const aInComponent: TArray<Boolean>; out aPath: TArray<Integer>): Boolean;
  var
    i: Integer;
    lEdge: TAdjacencyEdge;
    lFrame: TPathFrame;
    lFrameIndex: Integer;
    lFrames: TList<TPathFrame>;
    lVisited: TArray<Boolean>;
  begin
    aPath := [];
    lFrames := TList<TPathFrame>.Create;
    try
      SetLength(lVisited, aNodeCount);
      lFrame.NodeId := aStartNodeId;
      lFrame.NextEdgeIndex := 0;
      lFrames.Add(lFrame);
      lVisited[aStartNodeId] := True;
      while lFrames.Count > 0 do
      begin
        lFrameIndex := Pred(lFrames.Count);
        lFrame := lFrames[lFrameIndex];
        if lFrame.NodeId = aRootNodeId then
        begin
          SetLength(aPath, lFrames.Count);
          for i := 0 to Pred(lFrames.Count) do
            aPath[i] := lFrames[i].NodeId;
          Exit(True);
        end;

        if lFrame.NextEdgeIndex >= lAdjacency[lFrame.NodeId].Count then
        begin
          lVisited[lFrame.NodeId] := False;
          lFrames.Delete(lFrameIndex);
          Continue;
        end;

        lEdge := lAdjacency[lFrame.NodeId][lFrame.NextEdgeIndex];
        Inc(lFrame.NextEdgeIndex);
        lFrames[lFrameIndex] := lFrame;
        if aInComponent[lEdge.TargetNodeId] and not lVisited[lEdge.TargetNodeId] then
        begin
          lFrame.NodeId := lEdge.TargetNodeId;
          lFrame.NextEdgeIndex := 0;
          lFrames.Add(lFrame);
          lVisited[lEdge.TargetNodeId] := True;
        end;
      end;
      Result := False;
    finally
      lFrames.Free;
    end;
  end;

  function RepresentativePath(const aComponent: TDelphiSemanticTypedSccComponent):
    TArray<Integer>;
  var
    i: Integer;
    lEdge: TAdjacencyEdge;
    lInComponent: TArray<Boolean>;
    lPath: TArray<Integer>;
    lRootNodeId: Integer;
  begin
    lRootNodeId := aComponent.NodeIds[0];
    if Length(aComponent.NodeIds) = 1 then
      Exit(TArray<Integer>.Create(lRootNodeId, lRootNodeId));

    SetLength(lInComponent, aNodeCount);
    for i := 0 to High(aComponent.NodeIds) do
      lInComponent[aComponent.NodeIds[i]] := True;

    for lEdge in lAdjacency[lRootNodeId] do
      if lInComponent[lEdge.TargetNodeId] then
      begin
        if TryBuildIterativePath(lEdge.TargetNodeId, lRootNodeId, lInComponent, lPath) then
        begin
          SetLength(Result, Length(lPath) + 1);
          Result[0] := lRootNodeId;
          for i := 0 to High(lPath) do
            Result[i + 1] := lPath[i];
          Exit;
        end;
      end;

    Result := Copy(aComponent.NodeIds);
    SetLength(Result, Length(Result) + 1);
    Result[High(Result)] := Result[0];
  end;

  procedure FinishComponent(const aRootNodeId: Integer);
  var
    lComponent: TDelphiSemanticTypedSccComponent;
    lComponentEdge: TAdjacencyEdge;
    lEdgeIds: TList<Integer>;
    lHasSelfLoop: Boolean;
    lInComponent: TArray<Boolean>;
    lMemberId: Integer;
    lNodeIds: TList<Integer>;
  begin
    lNodeIds := TList<Integer>.Create;
    lEdgeIds := TList<Integer>.Create;
    try
      repeat
        lMemberId := lStack.Pop;
        lOnStack[lMemberId] := False;
        lNodeIds.Add(lMemberId);
      until lMemberId = aRootNodeId;

      lNodeIds.Sort;
      lComponent := Default(TDelphiSemanticTypedSccComponent);
      lComponent.NodeIds := lNodeIds.ToArray;
      SetLength(lInComponent, aNodeCount);
      for lMemberId in lComponent.NodeIds do
        lInComponent[lMemberId] := True;
      lHasSelfLoop := False;
      for lMemberId in lComponent.NodeIds do
        for lComponentEdge in lAdjacency[lMemberId] do
          if lInComponent[lComponentEdge.TargetNodeId] then
          begin
            lEdgeIds.Add(lComponentEdge.EdgeId);
            lHasSelfLoop := lHasSelfLoop or (lMemberId = lComponentEdge.TargetNodeId);
          end;

      if (Length(lComponent.NodeIds) <= 1) and not lHasSelfLoop then
        Exit;

      lEdgeIds.Sort;
      lComponent.SccId := lComponents.Count + 1;
      lComponent.EdgeIds := lEdgeIds.ToArray;
      lComponent.RepresentativePath := RepresentativePath(lComponent);
      lComponents.Add(lComponent);
    finally
      lEdgeIds.Free;
      lNodeIds.Free;
    end;
  end;

  procedure StrongConnect(const aNodeId: Integer);
  var
    lAdjacencyEdge: TAdjacencyEdge;
  begin
    lIndexes[aNodeId] := lCurrentIndex;
    lLowLinks[aNodeId] := lCurrentIndex;
    Inc(lCurrentIndex);
    lStack.Push(aNodeId);
    lOnStack[aNodeId] := True;

    for lAdjacencyEdge in lAdjacency[aNodeId] do
      if lIndexes[lAdjacencyEdge.TargetNodeId] < 0 then
      begin
        StrongConnect(lAdjacencyEdge.TargetNodeId);
        if lLowLinks[lAdjacencyEdge.TargetNodeId] < lLowLinks[aNodeId] then
          lLowLinks[aNodeId] := lLowLinks[lAdjacencyEdge.TargetNodeId];
      end else if lOnStack[lAdjacencyEdge.TargetNodeId] and
        (lIndexes[lAdjacencyEdge.TargetNodeId] < lLowLinks[aNodeId]) then
        lLowLinks[aNodeId] := lIndexes[lAdjacencyEdge.TargetNodeId];

    if lLowLinks[aNodeId] = lIndexes[aNodeId] then
      FinishComponent(aNodeId);
  end;

begin
  lComponents := TList<TDelphiSemanticTypedSccComponent>.Create;
  lStack := TStack<Integer>.Create;
  try
    SetLength(lAdjacency, aNodeCount);
    for lNodeId := 0 to Pred(aNodeCount) do
      lAdjacency[lNodeId] := TList<TAdjacencyEdge>.Create;
    try
      lMaxEdgeId := -1;
      for lEdge in aEdges do
      begin
        lAdjacencyEdge.EdgeId := lEdge.EdgeId;
        lAdjacencyEdge.TargetNodeId := lEdge.TargetNodeId;
        lAdjacency[lEdge.SourceNodeId].Add(lAdjacencyEdge);
        if lEdge.EdgeId > lMaxEdgeId then
          lMaxEdgeId := lEdge.EdgeId;
      end;
      lEdgeTargetComparer := TComparer<TAdjacencyEdge>.Construct(
        function(const aLeft, aRight: TAdjacencyEdge): Integer
        begin
          Result := aLeft.TargetNodeId - aRight.TargetNodeId;
          if Result = 0 then
            Result := aLeft.EdgeId - aRight.EdgeId;
        end);
      for lNodeId := 0 to Pred(aNodeCount) do
        lAdjacency[lNodeId].Sort(lEdgeTargetComparer);

      SetLength(lIndexes, aNodeCount);
      SetLength(lLowLinks, aNodeCount);
      SetLength(lOnStack, aNodeCount);
      for lNodeId := 0 to Pred(aNodeCount) do
      begin
        lIndexes[lNodeId] := -1;
        lLowLinks[lNodeId] := -1;
      end;

      lCurrentIndex := 0;
      for lNodeId := 0 to Pred(aNodeCount) do
        if lIndexes[lNodeId] < 0 then
          StrongConnect(lNodeId);

      Result.Components := lComponents.ToArray;
      SetLength(Result.NodeSccIds, aNodeCount);
      SetLength(Result.EdgeSccIds, lMaxEdgeId + 1);
      for lResultComponent in Result.Components do
      begin
        for lNodeId in lResultComponent.NodeIds do
          Result.NodeSccIds[lNodeId] := lResultComponent.SccId;
        for lResultEdgeId in lResultComponent.EdgeIds do
          Result.EdgeSccIds[lResultEdgeId] := lResultComponent.SccId;
      end;
    finally
      for lNodeId := 0 to High(lAdjacency) do
        lAdjacency[lNodeId].Free;
    end;
  finally
    lStack.Free;
    lComponents.Free;
  end;
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

function HasInvalidFileNameCharacter(const aUnitName: string): Boolean;
const
  cInvalidChars = '<>:"/\|?*';
var
  lChar: Char;
begin
  for lChar in aUnitName do
    if (Ord(lChar) < 32) or (Pos(string(lChar), cInvalidChars) > 0) then
      Exit(True);

  Result := False;
end;

function FindExternalFile(const aOptions: TDelphiSemanticDependencyGraphOptions;
  const aUnitName: string): string;
var
  lPath: string;
  lSearchPath: string;
begin
  if (aUnitName = '') or HasInvalidFileNameCharacter(aUnitName) then
    Exit('');

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

function UnitLookupKey(const aUnitName: string): string;
begin
  Result := LowerCase(aUnitName);
end;

function BuildTypedSccResult(const aEdges: TList<TDelphiSemanticDependencyEdge>;
  const aModels: TArray<TDelphiSemanticUnitModel>; out aNodeNames: TArray<string>):
  TDelphiSemanticTypedSccResult;
var
  i: Integer;
  lEdge: TDelphiSemanticDependencyEdge;
  lNodeIdByUnit: TDictionary<string, Integer>;
  lNodeNames: TList<string>;
  lSourceNodeId: Integer;
  lTargetNodeId: Integer;
  lTypedEdge: TDelphiSemanticTypedSccEdge;
  lTypedEdges: TList<TDelphiSemanticTypedSccEdge>;
  lUnitModel: TDelphiSemanticUnitModel;
begin
  lNodeIdByUnit := TDictionary<string, Integer>.Create;
  lNodeNames := TList<string>.Create;
  lTypedEdges := TList<TDelphiSemanticTypedSccEdge>.Create;
  try
    for lUnitModel in aModels do
      if (lUnitModel.UnitName <> '') and not lNodeIdByUnit.ContainsKey(UnitLookupKey(lUnitModel.UnitName)) then
      begin
        lNodeIdByUnit.Add(UnitLookupKey(lUnitModel.UnitName), lNodeNames.Count);
        lNodeNames.Add(lUnitModel.UnitName);
      end;

    for i := 0 to Pred(aEdges.Count) do
    begin
      lEdge := aEdges[i];
      if lNodeIdByUnit.TryGetValue(UnitLookupKey(lEdge.SourceUnit), lSourceNodeId) and
        lNodeIdByUnit.TryGetValue(UnitLookupKey(lEdge.TargetUnit), lTargetNodeId) then
      begin
        lTypedEdge.EdgeId := i;
        lTypedEdge.SourceNodeId := lSourceNodeId;
        lTypedEdge.TargetNodeId := lTargetNodeId;
        lTypedEdges.Add(lTypedEdge);
      end;
    end;

    aNodeNames := lNodeNames.ToArray;
    Result := TDelphiSemanticTypedSccAnalyzer.Analyze(lNodeNames.Count, lTypedEdges.ToArray);
  finally
    lTypedEdges.Free;
    lNodeNames.Free;
    lNodeIdByUnit.Free;
  end;
end;

procedure ApplySccCycles(const aNodes: TList<TDelphiSemanticDependencyNode>;
  const aEdges: TList<TDelphiSemanticDependencyEdge>;
  const aSccResult: TDelphiSemanticTypedSccResult; const aNodeNames: TArray<string>);
var
  lComponent: TDelphiSemanticTypedSccComponent;
  lEdge: TDelphiSemanticDependencyEdge;
  lEdgeId: Integer;
  lNode: TDelphiSemanticDependencyNode;
  lNodeId: Integer;
  lNodeIndex: Integer;
begin
  for lComponent in aSccResult.Components do
  begin
    for lEdgeId in lComponent.EdgeIds do
    begin
      lEdge := aEdges[lEdgeId];
      lEdge.IsCycleEdge := True;
      aEdges[lEdgeId] := lEdge;
    end;
    for lNodeId in lComponent.NodeIds do
    begin
      lNodeIndex := FindNodeIndex(aNodes, aNodeNames[lNodeId]);
      if lNodeIndex >= 0 then
      begin
        lNode := aNodes[lNodeIndex];
        lNode.InCycle := True;
        aNodes[lNodeIndex] := lNode;
      end;
    end;
  end;
end;

function BuildCycleComponents(const aSccResult: TDelphiSemanticTypedSccResult;
  const aNodeNames: TArray<string>): TArray<TDelphiSemanticDependencyCycleComponent>;
var
  i: Integer;
  lComponent: TDelphiSemanticDependencyCycleComponent;
  lComponents: TList<TDelphiSemanticDependencyCycleComponent>;
  lNodeId: Integer;
  lSccComponent: TDelphiSemanticTypedSccComponent;
  lUnits: TList<string>;
begin
  lComponents := TList<TDelphiSemanticDependencyCycleComponent>.Create;
  try
    for lSccComponent in aSccResult.Components do
    begin
      lUnits := TList<string>.Create;
      try
        for lNodeId in lSccComponent.NodeIds do
          lUnits.Add(aNodeNames[lNodeId]);
        lComponent := Default(TDelphiSemanticDependencyCycleComponent);
        lComponent.Units := lUnits.ToArray;
        SetLength(lComponent.Path, Length(lSccComponent.RepresentativePath));
        for i := 0 to High(lSccComponent.RepresentativePath) do
          lComponent.Path[i] := aNodeNames[lSccComponent.RepresentativePath[i]];
      finally
        lUnits.Free;
      end;
      TArray.Sort<string>(lComponent.Units, TComparer<string>.Construct(
        function(const aLeft, aRight: string): Integer
        begin
          Result := CompareText(aLeft, aRight);
        end));
      lComponents.Add(lComponent);
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
  lNodeNames: TArray<string>;
  lNodes: TList<TDelphiSemanticDependencyNode>;
  lSccResult: TDelphiSemanticTypedSccResult;
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

    lSccResult := BuildTypedSccResult(lEdges, aModels, lNodeNames);
    ApplySccCycles(lNodes, lEdges, lSccResult, lNodeNames);
    Result.Nodes := lNodes.ToArray;
    Result.Edges := lEdges.ToArray;
    Result.UnresolvedUnits := lUnresolvedUnits.ToArray;
    Result.CycleComponents := BuildCycleComponents(lSccResult, lNodeNames);
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
