unit Test.SemanticGraphDeclarations;

interface

uses
  DUnitX.TestFramework,
  DelphiSemantics.Model, DelphiSemantics.ProjectContext, DelphiSemantics.SemanticGraph;

type
  [TestFixture]
  TSemanticGraphDeclarationTests = class
  private
    function ProjectInfo: TDelphiSemanticProjectInfo;
    function UnitModel: TDelphiSemanticUnitModel;
  public
    [Test]
    [TestCase('unknown', 'unknown,0,0')]
    [TestCase('declaration', 'declaration,2,3')]
    [TestCase('member', 'member,3,5')]
    [TestCase('routine', 'routine,5,11')]
    [TestCase('parameter', 'parameter,5,23')]
    [TestCase('local', 'local,7,3')]
    [TestCase('reference', 'reference,9,3')]
    procedure IncludedGraphFactOrigins(const aKind: string;
      const aLine, aColumn: Integer);
    [Category('Fast')]
    [Test]
    procedure GraphStoresDeclarationTypeMemberRoutineParameterAndLocalDtos;
    [Category('Fast')]
    [Test]
    procedure DeclaredCanonicalAndUnderlyingTypeIdsStaySeparate;
    [Category('Fast')]
    [Test]
    procedure ExtractedParameterRangesFeedGraphDtos;
    [Category('Fast')]
    [Test]
    procedure RoutineSourceRangesPreserveModelCoordinates;
    [Category('Fast')]
    [Test]
    procedure LocalNominalTypesKeepDistinctIdsAcrossAndWithinRoutines;
    [Category('Fast')]
    [TestCase('ordered duplicate forwards', '0')]
    [TestCase('owner scope isolation', '1')]
    [TestCase('section isolation', '2')]
    [TestCase('physical include isolation', '3')]
    [TestCase('unknown forward coordinates', '4')]
    [TestCase('missing semantic identity', '5')]
    [TestCase('body must be strictly later', '6')]
    [TestCase('unnamed forward still sets visibility', '7')]
    [TestCase('non ASCII declaration names', '8')]
    procedure ForwardClassVisibilityPreservesOrderAndScope(const aShape: Integer);
  end;

implementation

uses
  System.IOUtils, System.SysUtils,
  Winapi.Windows,
  maxLogic.IOUtils,
  Test.Support;

var
  GSemanticGraphDeclarationTempRoot: string;

function SemanticGraphDeclarationTempPath(const aName: string): string;
begin
  if GSemanticGraphDeclarationTempRoot = '' then
  begin
    GSemanticGraphDeclarationTempRoot := CreateTestTempRoot('semantic-graph-declarations-temp');
  end;
  TDirectory.CreateDirectory(GSemanticGraphDeclarationTempRoot);
  Result := TPath.Combine(GSemanticGraphDeclarationTempRoot, aName);
end;


function TSemanticGraphDeclarationTests.ProjectInfo: TDelphiSemanticProjectInfo;
var
  lOptions: TDelphiSemanticOptions;
  lResult: TDelphiSemanticContextResult;
begin
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := FixturePath('ProjectContext\Basic\BasicProject.dproj');
  lResult := TDelphiSemanticProject.Load(lOptions.ProjectPath, lOptions);
  Assert.IsTrue(lResult.Success);
  Result := lResult.Project;
end;

function TSemanticGraphDeclarationTests.UnitModel: TDelphiSemanticUnitModel;
begin
  Result := Default(TDelphiSemanticUnitModel);
  Result.Success := True;
  Result.UnitName := 'GraphDeclarationsUnit';
  Result.FileName := FixturePath('ProjectContext\Basic\BasicProject.dpr');

  SetLength(Result.Declarations, 2);
  Result.Declarations[0].Name := 'TDeclaredAlias';
  Result.Declarations[0].Kind := 'type-alias';
  Result.Declarations[0].TypeName := 'TCanonicalRecord';
  Result.Declarations[0].Line := 4;
  Result.Declarations[0].Column := 3;
  Result.Declarations[0].Offset := 40;
  Result.Declarations[0].EndOffset := 55;
  Result.Declarations[1].Name := 'TCanonicalRecord';
  Result.Declarations[1].Kind := 'type';
  Result.Declarations[1].Line := 5;
  Result.Declarations[1].Column := 3;
  Result.Declarations[1].Offset := 60;
  Result.Declarations[1].EndOffset := 78;

  SetLength(Result.Members, 1);
  Result.Members[0].OwnerName := 'TCanonicalRecord';
  Result.Members[0].Name := 'Value';
  Result.Members[0].Kind := 'field';
  Result.Members[0].TypeName := 'Integer';
  Result.Members[0].Line := 6;
  Result.Members[0].Column := 5;
  Result.Members[0].Offset := 80;
  Result.Members[0].EndOffset := 91;

  SetLength(Result.Routines, 1);
  Result.Routines[0].Name := 'RunGraph';
  Result.Routines[0].Signature := 'RunGraph(const aValue: Integer): string';
  Result.Routines[0].ReturnType := 'string';
  Result.Routines[0].Line := 10;
  Result.Routines[0].Column := 1;
  Result.Routines[0].Offset := 140;
  Result.Routines[0].EndOffset := 260;
  SetLength(Result.Routines[0].Parameters, 1);
  Result.Routines[0].Parameters[0].RoutineName := 'RunGraph';
  Result.Routines[0].Parameters[0].Name := 'aValue';
  Result.Routines[0].Parameters[0].TypeName := 'Integer';
  Result.Routines[0].Parameters[0].Modifier := 'const';
  Result.Routines[0].Parameters[0].Line := 10;
  Result.Routines[0].Parameters[0].Column := 16;
  Result.Routines[0].Parameters[0].Offset := 156;
  Result.Routines[0].Parameters[0].EndOffset := 162;

  SetLength(Result.Locals, 1);
  Result.Locals[0].RoutineName := 'RunGraph';
  Result.Locals[0].Name := 'lText';
  Result.Locals[0].Kind := 'local';
  Result.Locals[0].TypeName := 'string';
  Result.Locals[0].Line := 12;
  Result.Locals[0].Column := 3;
  Result.Locals[0].Offset := 180;
  Result.Locals[0].EndOffset := 190;
end;

procedure TSemanticGraphDeclarationTests.GraphStoresDeclarationTypeMemberRoutineParameterAndLocalDtos;
var
  lGraph: TDelphiSemanticSemanticGraph;
begin
  lGraph := TDelphiSemanticSemanticGraphBuilder.Build(ProjectInfo, [UnitModel]);
  try
    Assert.AreEqual(2, Integer(Length(lGraph.Declarations)));
    Assert.AreEqual(2, Integer(Length(lGraph.Types)));
    Assert.AreEqual(1, Integer(Length(lGraph.Members)));
    Assert.AreEqual(1, Integer(Length(lGraph.Routines)));
    Assert.AreEqual(1, Integer(Length(lGraph.Parameters)));
    Assert.AreEqual(1, Integer(Length(lGraph.Locals)));
    Assert.AreEqual(6, lGraph.Metrics.SymbolCount);
  finally
    lGraph.Free;
  end;
end;

procedure TSemanticGraphDeclarationTests.DeclaredCanonicalAndUnderlyingTypeIdsStaySeparate;
var
  lGraph: TDelphiSemanticSemanticGraph;
  lType: TDelphiSemanticGraphType;
begin
  lGraph := TDelphiSemanticSemanticGraphBuilder.Build(ProjectInfo, [UnitModel]);
  try
    Assert.IsTrue(lGraph.FindTypeByName('TDeclaredAlias', lType));
    Assert.AreNotEqual('', lType.DeclaredId.Value);
    Assert.AreNotEqual('', lType.CanonicalId.Value);
    Assert.AreNotEqual('', lType.UnderlyingId.Value);
    Assert.AreNotEqual(lType.DeclaredId.Value, lType.CanonicalId.Value);
    Assert.AreNotEqual(lType.CanonicalId.Value, lType.UnderlyingId.Value);
  finally
    lGraph.Free;
  end;
end;

procedure TSemanticGraphDeclarationTests.LocalNominalTypesKeepDistinctIdsAcrossAndWithinRoutines;
var
  lGraph: TDelphiSemanticSemanticGraph;
  lModel: TDelphiSemanticUnitModel;
  lTypes: TArray<TDelphiSemanticGraphType>;
begin
  // Model facts are injected here to isolate the graph contract from AST extraction.
  lModel := Default(TDelphiSemanticUnitModel);
  lModel.Success := True;
  lModel.UnitName := 'LocalNominalGraph';
  lModel.FileName := FixturePath('ProjectContext\Basic\BasicProject.dpr');
  SetLength(lModel.Declarations, 3);
  lModel.Declarations[0].Name := 'TItem';
  lModel.Declarations[0].Kind := 'type';
  lModel.Declarations[0].TypeName := 'record';
  lModel.Declarations[0].ScopeKind := 'routine';
  lModel.Declarations[0].OwnerScopeId := 'localnominalgraph|first()';
  lModel.Declarations[0].SymbolId := 'localnominalgraph|first()|type|titem';
  lModel.Declarations[0].Line := 8;
  lModel.Declarations[0].Column := 3;
  lModel.Declarations[1] := lModel.Declarations[0];
  lModel.Declarations[1].OwnerScopeId := 'localnominalgraph|second()';
  lModel.Declarations[1].SymbolId := 'localnominalgraph|second()|type|titem';
  lModel.Declarations[1].Line := 18;
  lModel.Declarations[2] := lModel.Declarations[0];
  lModel.Declarations[2].Name := 'TOther';
  lModel.Declarations[2].SymbolId := 'localnominalgraph|first()|type|tother';
  lModel.Declarations[2].Line := 9;
  lGraph := TDelphiSemanticSemanticGraphBuilder.Build(ProjectInfo, [lModel]);
  try
    lTypes := lGraph.Types;
    Assert.AreEqual(3, Integer(Length(lTypes)));
    Assert.AreEqual(8, lTypes[0].SourceRange.Line);
    Assert.AreEqual(18, lTypes[1].SourceRange.Line);
    Assert.AreEqual(9, lTypes[2].SourceRange.Line);
    Assert.AreNotEqual(lTypes[0].DeclaredId.Value, lTypes[1].DeclaredId.Value,
      'Homonymous routine-local types must keep separate declarations.');
    Assert.AreNotEqual(lTypes[0].CanonicalId.Value, lTypes[1].CanonicalId.Value);
    Assert.AreNotEqual(lTypes[0].UnderlyingId.Value, lTypes[1].UnderlyingId.Value);
    Assert.AreNotEqual(lTypes[0].CanonicalId.Value, lTypes[2].CanonicalId.Value,
      'Distinct nominal records in the same routine cannot collapse to record.');
    Assert.AreNotEqual(lTypes[0].UnderlyingId.Value, lTypes[2].UnderlyingId.Value);
  finally
    lGraph.Free;
  end;
end;

procedure TSemanticGraphDeclarationTests.ExtractedParameterRangesFeedGraphDtos;
var
  lGraph: TDelphiSemanticSemanticGraph;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lParameterOffset: Integer;
  lPath: string;
  lSource: string;
begin
  lPath := SemanticGraphDeclarationTempPath('semantic-graph-parameters.pas');
  lSource := 'unit SemanticGraphParameters;' + sLineBreak + 'interface' + sLineBreak +
    'function RunGraph(const aValue: Integer): string;' + sLineBreak + 'implementation' +
    sLineBreak + 'function RunGraph(const aValue: Integer): string;' + sLineBreak +
    'begin' + sLineBreak + '  Result := aValue.ToString;' + sLineBreak + 'end;' +
    sLineBreak + 'end.';
  lParameterOffset := Pos('aValue', lSource);
  TFile.WriteAllText(lPath, lSource);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lPath;
  lOptions.ProjectContextApplied := True;
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  lGraph := TDelphiSemanticSemanticGraphBuilder.Build(ProjectInfo, [lModel]);
  try
    Assert.AreEqual(2, Integer(Length(lGraph.Parameters)));
    Assert.AreEqual(3, lGraph.Parameters[0].SourceRange.Line);
    Assert.AreEqual(25, lGraph.Parameters[0].SourceRange.Column);
    Assert.AreEqual(3, lGraph.Parameters[0].SourceRange.EndLine);
    Assert.AreEqual(31, lGraph.Parameters[0].SourceRange.EndColumn);
    Assert.AreEqual(lParameterOffset, lGraph.Parameters[0].SourceRange.Offset);
    Assert.AreEqual(lParameterOffset + Length('aValue'),
      lGraph.Parameters[0].SourceRange.EndOffset);
  finally
    lGraph.Free;
  end;
end;

procedure TSemanticGraphDeclarationTests.RoutineSourceRangesPreserveModelCoordinates;
var
  lGraph: TDelphiSemanticSemanticGraph;
  lParameter: TDelphiSemanticGraphParameter;
  lRoutine: TDelphiSemanticGraphRoutine;
begin
  lGraph := TDelphiSemanticSemanticGraphBuilder.Build(ProjectInfo, [UnitModel]);
  try
    lParameter := lGraph.Parameters[0];
    Assert.AreEqual(10, lParameter.SourceRange.Line);
    Assert.AreEqual(16, lParameter.SourceRange.Column);
    Assert.AreEqual(10, lParameter.SourceRange.EndLine);
    Assert.IsTrue(lParameter.SourceRange.EndColumn > lParameter.SourceRange.Column);
    Assert.IsTrue(lGraph.FindRoutineByName('RunGraph', lRoutine));
    Assert.AreEqual(140, lRoutine.SourceRange.Offset);
    Assert.AreEqual(260, lRoutine.SourceRange.EndOffset);
    Assert.AreEqual(10, lRoutine.SourceRange.Line);
    Assert.AreEqual(1, lRoutine.SourceRange.Column);
    Assert.AreEqual(10, lRoutine.SourceRange.EndLine);
    Assert.IsTrue(lRoutine.SourceRange.EndColumn > lRoutine.SourceRange.Column);
  finally
    lGraph.Free;
  end;
end;

procedure TSemanticGraphDeclarationTests.IncludedGraphFactOrigins(const aKind: string;
  const aLine, aColumn: Integer);
var
  lGraph: TDelphiSemanticSemanticGraph;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lRange: TDelphiSemanticSourceRange;
  lRoot, lInclude: string;
begin
  lRoot := CreateTestTempRoot('include-graph-probe-temp');
  lInclude := TPath.Combine(lRoot, 'facts.inc');
  TFile.WriteAllText(lInclude,
    'type'#13#10'  TIncluded = record'#13#10'    Value: Integer;'#13#10'  end;'#13#10 +
    'procedure IncludedRun(aValue: Integer);'#13#10'var'#13#10'  lValue: Integer;'#13#10 +
    'begin'#13#10'  lValue := aValue;'#13#10'end;'#13#10, TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'IncludeFactProbe.pas'),
    'unit IncludeFactProbe;'#13#10'interface'#13#10'implementation'#13#10 +
    '{$I facts.inc}'#13#10'end.', TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := TPath.Combine(lRoot, 'IncludeFactProbe.pas');
  lOptions.SearchPaths := [lRoot];
  lOptions.ProjectContextApplied := True;
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);
  if aKind = 'unknown' then
  begin
    lModel.Declarations[0].Line := 0;
    lModel.Declarations[0].Column := 0;
  end;
  lGraph := TDelphiSemanticSemanticGraphBuilder.Build(ProjectInfo, [lModel]);
  try
    lRange := Default(TDelphiSemanticSourceRange);
    if (aKind = 'declaration') or (aKind = 'unknown') then
      lRange := lGraph.Declarations[0].SourceRange
    else if aKind = 'member' then
      lRange := lGraph.Members[0].SourceRange
    else if aKind = 'routine' then
      lRange := lGraph.Routines[0].SourceRange
    else if aKind = 'parameter' then
      lRange := lGraph.Parameters[0].SourceRange
    else if aKind = 'local' then
      lRange := lGraph.Locals[0].SourceRange
    else
      for var i := 0 to High(lGraph.References) do
        if (lGraph.References[i].Name = 'lValue') and
          (lGraph.References[i].SourceRange.Line = aLine) then
          lRange := lGraph.References[i].SourceRange;
    Assert.AreEqual(lInclude, lRange.FileName);
    Assert.AreEqual(aLine, lRange.Line);
    Assert.AreEqual(aColumn, lRange.Column);
    if aKind = 'unknown' then
      Assert.AreEqual(0, lRange.EndColumn, 'Unknown positions cannot acquire a made-up endpoint.');
  finally
    lGraph.Free;
  end;
end;

procedure TSemanticGraphDeclarationTests.ForwardClassVisibilityPreservesOrderAndScope(
  const aShape: Integer);
var
  i, lBodyIndex, lExpectedSymbols, lExpectedTypes, lExpectedVisibility: Integer;
  lGraph: TDelphiSemanticSemanticGraph;
  lModel: TDelphiSemanticUnitModel;
  lTypes: TArray<TDelphiSemanticGraphType>;
begin
  // DS-810 S1 characterization: forward suppression and visibility use different
  // predicates. In particular an unnamed forward can still supply visibility.
  lModel := UnitModel;
  lModel.Members := nil;
  lModel.Routines := nil;
  lModel.Locals := nil;
  SetLength(lModel.Declarations, 6);
  for i := 0 to High(lModel.Declarations) do
    lModel.Declarations[i] := Default(TDelphiSemanticDeclaration);
  for i := 0 to 3 do
  begin
    lModel.Declarations[i].Name := 'TItem';
    lModel.Declarations[i].Kind := 'type';
    lModel.Declarations[i].TypeName := 'class';
    lModel.Declarations[i].SectionKind := 'interface';
    lModel.Declarations[i].ScopeKind := 'unit';
    lModel.Declarations[i].SymbolId := 'type:item';
    lModel.Declarations[i].Line := 30;
    lModel.Declarations[i].Column := 2;
  end;
  lModel.Declarations[1].Line := 10;
  lModel.Declarations[1].Column := 3;
  lModel.Declarations[2].Line := 10;
  lModel.Declarations[2].Column := 9;
  lModel.Declarations[3].Line := 60;
  lModel.Declarations[3].TypeBodyEndLine := 80;
  lModel.Declarations[4].Name := 'TAlias';
  lModel.Declarations[4].Kind := 'type-alias';
  lModel.Declarations[4].TypeName := 'TItem';
  lModel.Declarations[4].Line := 90;
  lModel.Declarations[4].Column := 1;
  lModel.Declarations[5].Name := 'Flag';
  lModel.Declarations[5].Kind := 'const';
  lModel.Declarations[5].TypeName := 'Integer';
  lModel.Declarations[5].Line := 100;
  lModel.Declarations[5].Column := 1;
  lExpectedSymbols := 6;
  lExpectedTypes := 2;
  lExpectedVisibility := 10;
  case aShape of
    1, 2, 5, 6:
      begin
        lExpectedTypes := 5;
        lExpectedVisibility := 60;
      end;
    3, 4:
      lExpectedVisibility := 60;
    7:
      begin
        lExpectedSymbols := 5;
        lExpectedVisibility := 5;
        lModel.Declarations[1].Name := '';
        lModel.Declarations[1].Line := 5;
      end;
  end;
  for i := 0 to 2 do
    case aShape of
      1: lModel.Declarations[i].OwnerScopeId := 'another-routine';
      2: lModel.Declarations[i].SectionKind := 'implementation';
      3: lModel.Declarations[i].FileName := 'other-forward810.inc';
      4: lModel.Declarations[i].Column := 0;
      5: lModel.Declarations[i].SymbolId := '';
      6: lModel.Declarations[i].Line := 60;
    end;
  if aShape = 8 then
    for i := 0 to 3 do
      lModel.Declarations[i].Name := 'T' + Char($00C4) + 'rtikel';
  lGraph := TDelphiSemanticSemanticGraphBuilder.Build(ProjectInfo, [lModel]);
  try
    lTypes := lGraph.Types;
    Assert.AreEqual<Integer>(lExpectedSymbols, Length(lGraph.Symbols));
    Assert.AreEqual<Integer>(lExpectedSymbols, Length(lGraph.Declarations));
    Assert.AreEqual<Integer>(lExpectedTypes, Length(lTypes));
    lBodyIndex := lExpectedTypes - 2;
    Assert.AreEqual(lModel.Declarations[3].Name, lTypes[lBodyIndex].Name);
    Assert.AreEqual(60, lTypes[lBodyIndex].SourceRange.Line);
    Assert.AreEqual(lExpectedVisibility, lTypes[lBodyIndex].VisibilityRange.Line);
    if lExpectedVisibility <> 60 then
      Assert.AreEqual(3, lTypes[lBodyIndex].VisibilityRange.Column,
        'Equal-line forwards retain the first matching declaration in array order.');
    Assert.AreEqual('TAlias', lTypes[High(lTypes)].Name);
  finally
    lGraph.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TSemanticGraphDeclarationTests);

end.
