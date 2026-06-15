unit Test.DependencyGraph;

interface

uses
  DUnitX.TestFramework,
  DelphiSemantics.Graph, DelphiSemantics.Model;

type
  [TestFixture]
  TDependencyGraphTests = class
  private
    function LoadModel(const aFileName: string): TDelphiSemanticUnitModel;
    function LoadModels(const aFileNames: array of string): TArray<TDelphiSemanticUnitModel>;
    function BuildGraph(const aFileNames: array of string): TDelphiSemanticDependencyGraph;
    function FindNode(const aGraph: TDelphiSemanticDependencyGraph; const aUnitName: string;
      out aNode: TDelphiSemanticDependencyNode): Boolean;
    function FindEdge(const aGraph: TDelphiSemanticDependencyGraph; const aSourceUnit,
      aTargetUnit, aSectionKind: string; out aEdge: TDelphiSemanticDependencyEdge): Boolean;
    function FindComponentWithUnit(const aGraph: TDelphiSemanticDependencyGraph;
      const aUnitName: string; out aComponent: TDelphiSemanticDependencyCycleComponent): Boolean;
    function HasHotspotEdgeUnit(const aGraph: TDelphiSemanticDependencyGraph;
      const aUnitName: string): Boolean;
    function HasHotspotUnit(const aGraph: TDelphiSemanticDependencyGraph;
      const aUnitName: string): Boolean;
    function HasUnit(const aUnits: TArray<string>; const aUnitName: string): Boolean;
    function PathEquals(const aPath: TArray<string>; const aExpected: array of string): Boolean;
  public
    [Test]
    procedure BuildsProjectExternalAndUnresolvedNodes;
    [Test]
    procedure BuildsProjectUnitEdgesFromSemanticModel;
    [Test]
    procedure ReportsCycleComponentsAndRealTraversalPaths;
    [Test]
    procedure FocusNeighborhoodUsesExactUnitName;
    [Test]
    procedure RanksHotspotsAndPrefersImplementationEdges;
    [Test]
    procedure MergesInterconnectedCyclesIntoOneComponent;
    [Test]
    procedure ReportsSelfLoopAsCycleComponent;
    [Test]
    procedure TypedSccAnalyzerHandlesDeepCycleIteratively;
    [Test]
    procedure SkipsInvalidExternalFileCandidateNames;
  end;

implementation

uses
  System.IOUtils, System.SysUtils,
  maxLogic.IOUtils,
  Test.Support;


function TDependencyGraphTests.LoadModel(const aFileName: string): TDelphiSemanticUnitModel;
var
  lOptions: TDelphiSemanticModelOptions;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := FixturePath('DependencyGraph', aFileName);
  lOptions.ProjectContextApplied := True;
  Result := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(Result.Success, aFileName);
end;

function TDependencyGraphTests.LoadModels(const aFileNames: array of string):
  TArray<TDelphiSemanticUnitModel>;
var
  i: Integer;
begin
  SetLength(Result, Length(aFileNames));
  for i := 0 to High(aFileNames) do
    Result[i] := LoadModel(aFileNames[i]);
end;

function TDependencyGraphTests.BuildGraph(const aFileNames: array of string):
  TDelphiSemanticDependencyGraph;
var
  lOptions: TDelphiSemanticDependencyGraphOptions;
begin
  lOptions := Default(TDelphiSemanticDependencyGraphOptions);
  lOptions.SearchPaths := [FixturePath('DependencyGraph', 'External')];
  Result := TDelphiSemanticDependencyGraphBuilder.Build(LoadModels(aFileNames), lOptions);
end;

function TDependencyGraphTests.FindNode(const aGraph: TDelphiSemanticDependencyGraph;
  const aUnitName: string; out aNode: TDelphiSemanticDependencyNode): Boolean;
var
  lNode: TDelphiSemanticDependencyNode;
begin
  for lNode in aGraph.Nodes do
    if SameText(lNode.UnitName, aUnitName) then
    begin
      aNode := lNode;
      Exit(True);
    end;

  aNode := Default(TDelphiSemanticDependencyNode);
  Result := False;
end;

function TDependencyGraphTests.FindEdge(const aGraph: TDelphiSemanticDependencyGraph;
  const aSourceUnit, aTargetUnit, aSectionKind: string;
  out aEdge: TDelphiSemanticDependencyEdge): Boolean;
var
  lEdge: TDelphiSemanticDependencyEdge;
begin
  for lEdge in aGraph.Edges do
    if SameText(lEdge.SourceUnit, aSourceUnit) and SameText(lEdge.TargetUnit, aTargetUnit) and
      SameText(lEdge.SectionKind, aSectionKind) then
    begin
      aEdge := lEdge;
      Exit(True);
    end;

  aEdge := Default(TDelphiSemanticDependencyEdge);
  Result := False;
end;

function TDependencyGraphTests.HasUnit(const aUnits: TArray<string>;
  const aUnitName: string): Boolean;
var
  lUnit: string;
begin
  for lUnit in aUnits do
    if SameText(lUnit, aUnitName) then
      Exit(True);

  Result := False;
end;

function TDependencyGraphTests.FindComponentWithUnit(const aGraph: TDelphiSemanticDependencyGraph;
  const aUnitName: string; out aComponent: TDelphiSemanticDependencyCycleComponent): Boolean;
var
  lComponent: TDelphiSemanticDependencyCycleComponent;
begin
  for lComponent in aGraph.CycleComponents do
    if HasUnit(lComponent.Units, aUnitName) then
    begin
      aComponent := lComponent;
      Exit(True);
    end;

  aComponent := Default(TDelphiSemanticDependencyCycleComponent);
  Result := False;
end;

function TDependencyGraphTests.HasHotspotEdgeUnit(const aGraph: TDelphiSemanticDependencyGraph;
  const aUnitName: string): Boolean;
var
  lHotspot: TDelphiSemanticDependencyEdgeHotspot;
begin
  for lHotspot in aGraph.EdgeHotspots do
    if SameText(lHotspot.SourceUnit, aUnitName) or SameText(lHotspot.TargetUnit, aUnitName) then
      Exit(True);

  Result := False;
end;

function TDependencyGraphTests.HasHotspotUnit(const aGraph: TDelphiSemanticDependencyGraph;
  const aUnitName: string): Boolean;
var
  lHotspot: TDelphiSemanticDependencyUnitHotspot;
begin
  for lHotspot in aGraph.UnitHotspots do
    if SameText(lHotspot.UnitName, aUnitName) then
      Exit(True);

  Result := False;
end;

function TDependencyGraphTests.PathEquals(const aPath: TArray<string>;
  const aExpected: array of string): Boolean;
var
  i: Integer;
begin
  if Length(aPath) <> Length(aExpected) then
    Exit(False);

  for i := 0 to High(aExpected) do
    if not SameText(aPath[i], aExpected[i]) then
      Exit(False);

  Result := True;
end;

procedure TDependencyGraphTests.BuildsProjectExternalAndUnresolvedNodes;
var
  lEdge: TDelphiSemanticDependencyEdge;
  lGraph: TDelphiSemanticDependencyGraph;
  lNode: TDelphiSemanticDependencyNode;
begin
  lGraph := BuildGraph(['GraphRoot.pas', 'GraphA.pas']);

  Assert.IsTrue(FindNode(lGraph, 'GraphRoot', lNode));
  Assert.AreEqual('project', lNode.Status);
  Assert.IsTrue(FindNode(lGraph, 'ExternalLib', lNode));
  Assert.AreEqual('external', lNode.Status);
  Assert.IsTrue(lNode.IsExternal);
  Assert.IsTrue(FindNode(lGraph, 'MissingGraphUnit', lNode));
  Assert.AreEqual('unresolved', lNode.Status);
  Assert.IsTrue(lNode.IsUnresolved);
  Assert.IsTrue(HasUnit(lGraph.UnresolvedUnits, 'MissingGraphUnit'));
  Assert.IsTrue(FindEdge(lGraph, 'GraphRoot', 'GraphA', 'interface', lEdge));
  Assert.AreEqual('project', lEdge.TargetStatus);
  Assert.IsTrue(FindEdge(lGraph, 'GraphRoot', 'ExternalLib', 'interface', lEdge));
  Assert.AreEqual('external', lEdge.TargetStatus);
end;

procedure TDependencyGraphTests.BuildsProjectUnitEdgesFromSemanticModel;
var
  lEdge: TDelphiSemanticDependencyEdge;
  lGraph: TDelphiSemanticDependencyGraph;
  lModels: TArray<TDelphiSemanticUnitModel>;
  lOptions: TDelphiSemanticDependencyGraphOptions;
begin
  lModels := LoadModels(['GraphProject.dpr', 'GraphA.pas', 'GraphRoot.pas']);
  lModels[0].UnitName := 'GraphProject';
  lOptions := Default(TDelphiSemanticDependencyGraphOptions);
  lOptions.ProjectUnitName := 'GraphProject';

  lGraph := TDelphiSemanticDependencyGraphBuilder.Build(lModels, lOptions);

  Assert.IsTrue(FindEdge(lGraph, 'GraphProject', 'GraphA', 'project', lEdge));
  Assert.AreEqual('project', lEdge.TargetStatus);
  Assert.IsTrue(FindEdge(lGraph, 'GraphProject', 'GraphRoot', 'contains', lEdge));
  Assert.AreEqual('project', lEdge.TargetStatus);
end;

procedure TDependencyGraphTests.ReportsCycleComponentsAndRealTraversalPaths;
var
  lComponent: TDelphiSemanticDependencyCycleComponent;
  lGraph: TDelphiSemanticDependencyGraph;
begin
  lGraph := BuildGraph(['CycleA.pas', 'CycleB.pas', 'CycleConsumer.pas', 'PathCycleA.pas',
    'PathCycleB.pas', 'PathCycleC.pas']);

  Assert.IsTrue(Length(lGraph.CycleComponents) >= 2);
  Assert.IsTrue(HasUnit(lGraph.CycleComponents[0].Units, 'CycleA') or
    HasUnit(lGraph.CycleComponents[1].Units, 'CycleA'));
  Assert.IsTrue(FindComponentWithUnit(lGraph, 'PathCycleA', lComponent));
  Assert.IsTrue(PathEquals(lComponent.Path, ['PathCycleA', 'PathCycleB', 'PathCycleC',
    'PathCycleA']));
  Assert.IsFalse(HasHotspotUnit(lGraph, 'MissingCycleUnit'));
  Assert.IsFalse(HasHotspotEdgeUnit(lGraph, 'MissingCycleUnit'));
end;

procedure TDependencyGraphTests.FocusNeighborhoodUsesExactUnitName;
var
  lFocused: TArray<string>;
  lGraph: TDelphiSemanticDependencyGraph;
begin
  lGraph := BuildGraph(['CycleA.pas', 'CycleB.pas', 'CycleConsumer.pas']);

  lFocused := TDelphiSemanticDependencyGraphQuery.FocusNeighborhood(lGraph, 'CycleA');

  Assert.IsTrue(HasUnit(lFocused, 'CycleA'));
  Assert.IsTrue(HasUnit(lFocused, 'CycleB'));
  Assert.IsTrue(HasUnit(lFocused, 'CycleConsumer'));
  Assert.AreEqual(3, Integer(Length(lFocused)));
  lFocused := TDelphiSemanticDependencyGraphQuery.FocusNeighborhood(lGraph, 'Cycle');
  Assert.AreEqual(0, Integer(Length(lFocused)));
end;

procedure TDependencyGraphTests.RanksHotspotsAndPrefersImplementationEdges;
var
  lGraph: TDelphiSemanticDependencyGraph;
begin
  lGraph := BuildGraph(['CycleA.pas', 'CycleB.pas']);

  Assert.IsTrue(Length(lGraph.EdgeHotspots) >= 2);
  Assert.AreEqual('CycleB', lGraph.EdgeHotspots[0].SourceUnit);
  Assert.AreEqual('CycleA', lGraph.EdgeHotspots[0].TargetUnit);
  Assert.AreEqual('implementation', lGraph.EdgeHotspots[0].SectionKind);
  Assert.AreEqual('CycleA', lGraph.EdgeHotspots[1].SourceUnit);
  Assert.AreEqual('CycleB', lGraph.EdgeHotspots[1].TargetUnit);
  Assert.AreEqual('interface', lGraph.EdgeHotspots[1].SectionKind);
end;

procedure TDependencyGraphTests.MergesInterconnectedCyclesIntoOneComponent;
var
  lComponent: TDelphiSemanticDependencyCycleComponent;
  lGraph: TDelphiSemanticDependencyGraph;
begin
  lGraph := BuildGraph(['BridgeA.pas', 'BridgeC.pas', 'BridgeD.pas', 'BridgeB.pas']);

  Assert.AreEqual(1, Integer(Length(lGraph.CycleComponents)));
  lComponent := lGraph.CycleComponents[0];
  Assert.IsTrue(HasUnit(lComponent.Units, 'BridgeA'));
  Assert.IsTrue(HasUnit(lComponent.Units, 'BridgeB'));
  Assert.IsTrue(HasUnit(lComponent.Units, 'BridgeC'));
  Assert.IsTrue(HasUnit(lComponent.Units, 'BridgeD'));
end;

procedure TDependencyGraphTests.ReportsSelfLoopAsCycleComponent;
var
  lComponent: TDelphiSemanticDependencyCycleComponent;
  lEdge: TDelphiSemanticDependencyEdge;
  lGraph: TDelphiSemanticDependencyGraph;
  lNode: TDelphiSemanticDependencyNode;
begin
  lGraph := BuildGraph(['SelfCycle.pas']);

  Assert.IsTrue(FindNode(lGraph, 'SelfCycle', lNode));
  Assert.IsTrue(lNode.InCycle);
  Assert.IsTrue(FindEdge(lGraph, 'SelfCycle', 'SelfCycle', 'interface', lEdge));
  Assert.IsTrue(lEdge.IsCycleEdge);
  Assert.AreEqual(1, Integer(Length(lGraph.CycleComponents)));
  lComponent := lGraph.CycleComponents[0];
  Assert.IsTrue(HasUnit(lComponent.Units, 'SelfCycle'));
  Assert.IsTrue(PathEquals(lComponent.Path, ['SelfCycle', 'SelfCycle']));
end;

procedure TDependencyGraphTests.TypedSccAnalyzerHandlesDeepCycleIteratively;
const
  cNodeCount = 4096;
var
  i: Integer;
  lEdges: TArray<TDelphiSemanticTypedSccEdge>;
  lResult: TDelphiSemanticTypedSccResult;
begin
  SetLength(lEdges, cNodeCount);
  for i := 0 to cNodeCount - 2 do
  begin
    lEdges[i].EdgeId := i;
    lEdges[i].SourceNodeId := i;
    lEdges[i].TargetNodeId := i + 1;
  end;
  lEdges[cNodeCount - 1].EdgeId := cNodeCount - 1;
  lEdges[cNodeCount - 1].SourceNodeId := cNodeCount - 1;
  lEdges[cNodeCount - 1].TargetNodeId := 0;

  lResult := TDelphiSemanticTypedSccAnalyzer.Analyze(cNodeCount, lEdges);

  Assert.AreEqual(1, Integer(Length(lResult.Components)));
  Assert.AreEqual(cNodeCount, Integer(Length(lResult.Components[0].NodeIds)));
  Assert.AreEqual(cNodeCount, Integer(Length(lResult.Components[0].EdgeIds)));
  Assert.AreEqual(lResult.Components[0].SccId, lResult.NodeSccIds[0]);
  Assert.AreEqual(lResult.Components[0].SccId, lResult.NodeSccIds[cNodeCount - 1]);
  Assert.AreEqual(lResult.Components[0].SccId, lResult.EdgeSccIds[cNodeCount - 1]);
end;

procedure TDependencyGraphTests.SkipsInvalidExternalFileCandidateNames;
var
  lGraph: TDelphiSemanticDependencyGraph;
  lModel: TDelphiSemanticUnitModel;
  lNode: TDelphiSemanticDependencyNode;
  lOptions: TDelphiSemanticDependencyGraphOptions;
begin
  lModel := Default(TDelphiSemanticUnitModel);
  lModel.UnitName := 'InvalidRoot';
  lModel.InterfaceUses := TArray<string>.Create('Bad' + #10 + 'Unit');
  lOptions := Default(TDelphiSemanticDependencyGraphOptions);
  lOptions.SearchPaths := [FixturePath('DependencyGraph', 'External')];

  lGraph := TDelphiSemanticDependencyGraphBuilder.Build([lModel], lOptions);

  Assert.IsTrue(FindNode(lGraph, 'Bad' + #10 + 'Unit', lNode));
  Assert.AreEqual('unresolved', lNode.Status);
end;

initialization
  TDUnitX.RegisterTestFixture(TDependencyGraphTests);

end.
