unit Test.SemanticGraphDeclarations;

interface

uses
  DUnitX.TestFramework,
  DelphiSemantics.Model, DelphiSemantics.ProjectContext, DelphiSemantics.SemanticGraph;

type
  [TestFixture]
  TSemanticGraphDeclarationTests = class
  private
    function FixturePath(const aRelativePath: string): string;
    function ProjectInfo: TDelphiSemanticProjectInfo;
    function UnitModel: TDelphiSemanticUnitModel;
  public
    [Test]
    procedure GraphStoresDeclarationTypeMemberRoutineParameterAndLocalDtos;
    [Test]
    procedure DeclaredCanonicalAndUnderlyingTypeIdsStaySeparate;
    [Test]
    procedure ExtractedParameterRangesFeedGraphDtos;
    [Test]
    procedure RoutineSourceRangesPreserveModelCoordinates;
  end;

implementation

uses
  System.IOUtils, System.SysUtils,
  maxLogic.IOUtils;

function TSemanticGraphDeclarationTests.FixturePath(const aRelativePath: string): string;
begin
  Result := TPath.GetFullPath(CombinePath([ExtractFilePath(ParamStr(0)), '..', 'fixtures',
    aRelativePath]));
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

procedure TSemanticGraphDeclarationTests.ExtractedParameterRangesFeedGraphDtos;
var
  lGraph: TDelphiSemanticSemanticGraph;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lParameterOffset: Integer;
  lPath: string;
  lSource: string;
begin
  lPath := TPath.Combine(ExtractFilePath(ParamStr(0)), 'semantic-graph-parameters.pas');
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

initialization
  TDUnitX.RegisterTestFixture(TSemanticGraphDeclarationTests);

end.
