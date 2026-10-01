unit Test.Refactor.SignatureAlignment;

interface

uses
  DUnitX.TestFramework,
  DelphiSemantics.Model, DelphiSemantics.Snapshot;

type
  [TestFixture]
  [Category('RefactoringLightAlign')]
  TSignatureAlignmentTests = class
  private
    function ExtractModel(const aShape: string): TDelphiSemanticUnitModel;
    procedure CreateAlignmentProject(const aShape: string; out aModel: TDelphiSemanticUnitModel;
      out aSnapshot: TDelphiProjectSnapshot);

  public
    [Test] procedure BuildsBoundAlignmentSuggestion;
    [Test]
    [TestCase('Function result', 'function-drift')]
    [TestCase('Calling convention', 'cdecl-body')]
    [TestCase('Default value', 'default-body')]
    procedure RetainsSignatureShapeInPlan(const aShape: string);
    [Test]
    [TestCase('Return type differs', 'return-type')]
    [TestCase('Parameter order differs', 'parameter-order')]
    [TestCase('Calling convention differs', 'convention-mismatch')]
    procedure RefusesSignatureShapeChanges(const aShape: string);
    [Test]
    [TestCase('Distinct new parameter names', 'multiple-drift')]
    [TestCase('Simultaneous parameter-name swap', 'swap-drift')]
    procedure MapsMultipleParameterNames(const aShape: string);
    [Test] procedure LeavesCommentsStringsAndQualifiedMembersUntouched;
    [Test] procedure BindingIdentityIncludesSemanticModelEvidence;
    [Test] procedure CapturedModelEvidenceIsIsolated;
    [Test] procedure RefusesUnresolvedNestedParameterReference;
    [Test]
    [TestCase('Unextracted parameter use', 'assembler-old')]
    [TestCase('Unextracted replacement-name use', 'assembler-new')]
    [TestCase('Field after method and visibility on one line', 'mixed-method-field')]
    procedure RefusesUncoveredBodyTokens(const aShape: string);
    [Test]
    [TestCase('Missing reference inventory', 'references')]
    [TestCase('Altered declaration signature', 'signature')]
    [TestCase('Altered nested parent', 'nested-parent')]
    [TestCase('Missing local and capture reference', 'locals')]
    procedure RefusesDivergentModelEvidence(const aFault: string);
    [Test]
    [TestCase('Local collision', 'capture-local')]
    [TestCase('Nested parameter collision', 'capture-nested')]
    [TestCase('Nested capture during simultaneous swap', 'swap-capture')]
    [TestCase('Previously bound field', 'capture-field')]
    [TestCase('Previously unresolved name', 'capture-unknown')]
    [TestCase('Range bound constant', 'capture-range')]
    procedure RefusesParameterNameCapture(const aShape: string);
    [Test]
    [TestCase('Already aligned', 'aligned,aligned')]
    [TestCase('Implementation name drift', 'drift,name-drift')]
    [TestCase('Parameter type differs', 'type,mismatch')]
    [TestCase('Parameter mode differs', 'mode,mismatch')]
    [TestCase('Parameter count differs', 'count,mismatch')]
    [TestCase('Function name drift', 'function-drift,name-drift')]
    [TestCase('Return type differs', 'return-type,mismatch')]
    [TestCase('Parameter order differs', 'parameter-order,mismatch')]
    [TestCase('Calling convention differs', 'convention-mismatch,mismatch')]
    [TestCase('Select matching overload', 'overload,name-drift')]
    procedure ComparesSelectedDeclaration(const aShape, aStatus: string);
    [Test]
    [TestCase('Duplicate declarations', 'duplicate-declaration')]
    [TestCase('Duplicate implementations', 'duplicate-implementation')]
    procedure RefusesAmbiguousPairs(const aShape: string);
    [Test]
    [TestCase('Ordinary parameter', 'drift')]
    [TestCase('Default value retained', 'default-drift')]
    [TestCase('Calling convention retained', 'cdecl-drift')]
    procedure LocatesParameterNameChangeWithoutAuthorizingEdits(const aShape: string);
    [Test]
    [TestCase('Missing positional inventory', 'missing')]
    [TestCase('Inconsistent type fact', 'type')]
    [TestCase('Inconsistent coordinates', 'coordinates')]
    [TestCase('Partial identifier', 'partial')]
    [TestCase('Body occurrence is not a declaration', 'body')]
    [TestCase('Native Unicode positional gap', 'unicode')]
    [TestCase('Type occurrence is not a parameter', 'type-token')]
    procedure RefusesUnprovenParameterPositions(const aFault: string);
  end;

implementation

uses
  System.IOUtils, System.SysUtils,
  DelphiSemantics.Model.Json, DelphiSemantics.ProjectContext, DelphiSemantics.ProjectSession,
  DelphiSemantics.Refactor.Binding, DelphiSemantics.Refactor.Plan,
  DelphiSemantics.Refactor.SignatureAlignment, DelphiSemantics.Resolve.TypeResolver,
  DelphiSemantics.SemanticGraph, DelphiSemantics.Snapshot.Builder,
  DelphiSemantics.Snapshot.ContextEvidence, DelphiSemantics.WithBinding;

function AlignmentDeclarationOffset(const aModel: TDelphiSemanticUnitModel): Integer;
var
  lMember: TDelphiSemanticMember;
begin
  for lMember in aModel.Members do
    if SameText(lMember.OwnerName, 'TSubject') and SameText(lMember.Kind, 'method') and
      SameText(lMember.Name, 'SetValue') then
      Exit(lMember.Offset);
  Result := 0;
end;
function CaptureAlignmentSource(const aSource, aShape: string): string;
var
  lBody: string;
begin
  Result := aSource;
  lBody := '';
  if aShape = 'qualified-literals' then
    lBody := 'begin { aOldValue aValue } if ''aOldValue'' = ''aValue'' then aOldValue := Self.aOldValue; end;'
  else if aShape = 'assembler-old' then
    lBody := 'asm mov rax, aOldValue end;'
  else if aShape = 'assembler-new' then
    lBody := 'asm mov rax, aValue end;'
  else if aShape = 'capture-local' then
    lBody := 'var aValue: TValue; begin aOldValue := aValue; end;'
  else if aShape = 'nested-reference' then
    lBody := 'procedure Nested;'#13#10 +
      'begin aOldValue := two; end;'#13#10'begin Nested; end;'
  else if aShape = 'capture-nested' then
    lBody := 'procedure Nested(aValue: TValue);'#13#10 +
      'begin aOldValue := aValue; end;'#13#10'begin end;'
  else if (aShape = 'capture-field') or (aShape = 'capture-unknown') then
    lBody := 'begin aOldValue := aValue; end;'
  else if aShape = 'capture-range' then
    // A range separator is not a qualifier: the renamed parameter would capture aValue.
    lBody := 'begin if aOldValue in [one..aValue] then aOldValue := one; end;';
  if aShape = 'capture-range' then
    Result := StringReplace(Result, 'implementation'#13#10,
      'const aValue = two;'#13#10'implementation'#13#10, []);
  if aShape = 'qualified-literals' then
    Result := StringReplace(Result, '  public', '  public aOldValue: TValue;', []);
  if aShape = 'capture-field' then
    Result := StringReplace(Result, '  public', '  public aValue: TValue;', []);
  if aShape = 'mixed-method-field' then
  begin
    Result := StringReplace(Result, '  public',
      '  public procedure Other; private aOldValue: TValue;', []);
    Result := StringReplace(Result, 'implementation'#13#10,
      'implementation'#13#10'procedure TSubject.Other; begin end;'#13#10, []);
    lBody := 'begin aOldValue := Self.aOldValue; end;';
  end;
  if lBody <> '' then
    Result := StringReplace(Result, 'begin end;'#13#10'end.', lBody + #13#10'end.', []);
end;

function AdjustAlignmentHeader(const aSource, aShape: string): string;
begin
  Result := aSource;
  if (aShape = 'default-drift') or (aShape = 'default-body') then
    Result := StringReplace(Result, 'var aValue: TValue', 'aValue: TValue = one', []);
  if (aShape = 'cdecl-drift') or (aShape = 'cdecl-body') then
  begin
    Result := StringReplace(Result, '); overload;', '); cdecl; overload;', []);
    Result := StringReplace(Result, ');'#13#10'begin', '); cdecl;'#13#10'begin', []);
  end;
  if aShape = 'type-token-drift' then
    Result := StringReplace(Result, '  TOther =', '  aOldValue = TValue;'#13#10'  TOther =', []);
  if (aShape = 'body-drift') or (aShape = 'cdecl-body') or (aShape = 'default-body') then
    Result := StringReplace(Result, 'begin end;', 'begin aOldValue := two; end;', []);
end;

function MultipleParameterSource(const aSource, aShape: string): string;
var
  lFirst, lSecond: string;
begin
  Result := aSource;
  if (aShape <> 'multiple-drift') and (aShape <> 'swap-drift') and (aShape <> 'swap-capture') then
    Exit;
  lFirst := 'aOldFirst';
  lSecond := 'aOldSecond';
  if (aShape = 'swap-drift') or (aShape = 'swap-capture') then
  begin
    lFirst := 'aSecond';
    lSecond := 'aFirst';
  end;
  Result := StringReplace(Result, 'var aValue: TValue',
    'var aFirst: TValue; var aSecond: TValue', []);
  Result := StringReplace(Result, 'var aOldValue: TValue',
    'var ' + lFirst + ': TValue; var ' + lSecond + ': TValue', []);
  Result := StringReplace(Result, 'begin end;',
    'begin ' + lFirst + ' := ' + lSecond + '; end;', []);
  if aShape = 'swap-capture' then
    Result := StringReplace(Result, 'begin aSecond := aFirst; end;',
      'procedure Nested(aFirst: TValue);'#13#10 +
      'begin aSecond := aFirst; end;'#13#10'begin aSecond := aFirst; end;', []);
end;

function SignatureShapeSource(const aSource, aShape: string): string;
begin
  Result := aSource;
  if (aShape = 'function-drift') or (aShape = 'return-type') then
  begin
    Result := StringReplace(Result, 'procedure ', 'function ', [rfReplaceAll]);
    Result := StringReplace(Result, 'TValue); overload;', 'TValue): TValue; overload;', []);
    Result := StringReplace(Result, 'TValue);'#13#10, 'TValue): TValue;'#13#10, []);
    Result := StringReplace(Result, 'begin end;', 'begin Result := aOldValue; end;', []);
    if aShape = 'return-type' then
      Result := StringReplace(Result, '): TValue;'#13#10, '): TOther;'#13#10, []);
  end else if aShape = 'parameter-order' then
  begin
    Result := StringReplace(Result, 'var aValue: TValue',
      'var aValue: TValue; aOther: TOther', []);
    Result := StringReplace(Result, 'var aOldValue: TValue',
      'var aOldValue: TOther; aOther: TValue', []);
  end else if aShape = 'convention-mismatch' then
    Result := StringReplace(Result, '); overload;', '); cdecl; overload;', []);
end;

function AlignmentSource(const aShape: string): string;
var
  lName, lType, lMode, lExtra, lOverload, lDeclaration: string;
begin
  lName := 'aOldValue';
  lType := 'TValue';
  lMode := 'var ';
  lExtra := '';
  lOverload := '';
  lDeclaration := '';
  if aShape = 'type-token-drift' then
    lType := 'aOldValue';
  if aShape = 'unicode-drift' then
    lName := #196'aOldValue';
  if (aShape = 'default-drift') or (aShape = 'default-body') then
  begin
    lMode := '';
    lExtra := ' = one';
  end;
  if aShape = 'aligned' then
    lName := 'aValue'
  else if aShape = 'type' then
    lType := 'TOther'
  else if aShape = 'mode' then
    lMode := 'const '
  else if aShape = 'count' then
    lExtra := '; aExtra: TValue'
  else if aShape = 'overload' then
  begin
    lDeclaration := '    procedure SetValue(aOther: TOther); overload;'#13#10;
    lOverload := 'procedure TSubject.SetValue(aOther: TOther); begin end;'#13#10;
  end;
  if aShape = 'duplicate-declaration' then
    lDeclaration := '    procedure SetValue(var aOther: TValue); overload;'#13#10
  else if aShape = 'duplicate-implementation' then
    lOverload := 'procedure TSubject.SetValue(var aOther: TValue); begin end;'#13#10;
  Result := 'unit AlignmentSubject;'#13#10'interface'#13#10'type'#13#10 +
    '  TValue = (one, two);'#13#10'  TOther = (three, four);'#13#10 +
    '  TSubject = class'#13#10'  public'#13#10 +
    '    procedure SetValue(var aValue: TValue); overload;'#13#10 + lDeclaration + '  end;'#13#10 +
    'implementation'#13#10 + lOverload +
    'procedure TSubject.SetValue(' + lMode + lName + ': ' + lType + lExtra + ');'#13#10 +
    'begin end;'#13#10'end.'#13#10;
  Result := CaptureAlignmentSource(AdjustAlignmentHeader(Result, aShape), aShape);
  Result := MultipleParameterSource(Result, aShape);
  Result := SignatureShapeSource(Result, aShape);
end;

function TSignatureAlignmentTests.ExtractModel(const aShape: string): TDelphiSemanticUnitModel;
var
  id: TGUID;
  lDirectory: string;
  lOptions: TDelphiSemanticModelOptions;
begin
  CreateGUID(id);
  lDirectory := TPath.GetFullPath(TPath.Combine(ExtractFilePath(ParamStr(0)),
    '..\.dak\delphiSemanticsTests\refactoring-light-align\fixtures\' + GUIDToString(id)));
  TDirectory.CreateDirectory(lDirectory);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.ProjectContextApplied := True;
  lOptions.SourceFileName := TPath.Combine(lDirectory, 'AlignmentSubject.pas');
  TFile.WriteAllText(lOptions.SourceFileName, AlignmentSource(aShape), TEncoding.UTF8);
  Result := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(Result.Success);
  Assert.AreEqual('ast', Result.ScopeModelStatus);
  Assert.AreEqual(0, Result.RejectedDeclarationCount);
  Result := JsonToModel(ModelToJson(Result));
end;

procedure TSignatureAlignmentTests.ComparesSelectedDeclaration(const aShape, aStatus: string);
var
  lModel: TDelphiSemanticUnitModel;
  lProject: TDelphiSemanticProjectInfo;
  lGraph: TDelphiSemanticSemanticGraph;
  lResult: TDelphiSemanticAlignmentComparison;
begin
  lModel := ExtractModel(aShape);
  if aShape = 'overload' then
    Assert.AreEqual<NativeInt>(2, Length(lModel.Members))
  else
    Assert.AreEqual<NativeInt>(1, Length(lModel.Members));
  lProject := Default(TDelphiSemanticProjectInfo);
  lProject.ProjectName := 'AlignmentSubject';
  lGraph := TDelphiSemanticSemanticGraphBuilder.Build(lProject, [lModel]);
  try
    lResult := TDelphiSemanticSignatureAlignment.Compare([lModel],
      TDelphiSemanticTypeResolver.BuildIndex(lGraph), lModel.FileName, AlignmentDeclarationOffset(lModel));
    Assert.AreEqual(aStatus, lResult.Status, lResult.Reason);
    Assert.AreEqual(0, lResult.DeclarationIndex);
    if aShape = 'overload' then
      Assert.AreEqual(1, lResult.ImplementationIndex)
    else
      Assert.AreEqual(0, lResult.ImplementationIndex);
  finally
    lGraph.Free;
  end;
end;

procedure TSignatureAlignmentTests.RefusesAmbiguousPairs(const aShape: string);
var
  lModel: TDelphiSemanticUnitModel;
  lProject: TDelphiSemanticProjectInfo;
  lGraph: TDelphiSemanticSemanticGraph;
  lResult: TDelphiSemanticAlignmentComparison;
begin
  lModel := ExtractModel(aShape);
  if aShape = 'duplicate-declaration' then
    Assert.AreEqual<NativeInt>(2, Length(lModel.Members))
  else
    Assert.AreEqual<NativeInt>(2, Length(lModel.Routines));
  lProject := Default(TDelphiSemanticProjectInfo);
  lGraph := TDelphiSemanticSemanticGraphBuilder.Build(lProject, [lModel]);
  try
    lResult := TDelphiSemanticSignatureAlignment.Compare([lModel],
      TDelphiSemanticTypeResolver.BuildIndex(lGraph), lModel.FileName, AlignmentDeclarationOffset(lModel));
    Assert.AreEqual('unknown', lResult.Status);
    Assert.AreEqual('alignment.pair-ambiguous', lResult.Reason);
    Assert.AreEqual(-1, lResult.ImplementationIndex);
  finally
    lGraph.Free;
  end;
end;

procedure TSignatureAlignmentTests.LocatesParameterNameChangeWithoutAuthorizingEdits(const aShape: string);
var
  lModel: TDelphiSemanticUnitModel;
  lProject: TDelphiSemanticProjectInfo;
  lGraph: TDelphiSemanticSemanticGraph;
  lResult: TDelphiSemanticAlignmentParameterChanges;
begin
  lModel := ExtractModel(aShape);
  lProject := Default(TDelphiSemanticProjectInfo);
  lGraph := TDelphiSemanticSemanticGraphBuilder.Build(lProject, [lModel]);
  try
    lResult := TDelphiSemanticSignatureAlignment.InspectParameterChanges([lModel],
      TDelphiSemanticTypeResolver.BuildIndex(lGraph), lModel.FileName, AlignmentDeclarationOffset(lModel));
    Assert.AreEqual('name-drift', lResult.Comparison.Status);
    Assert.IsTrue(lResult.Known, lResult.Reason);
    Assert.AreEqual<NativeInt>(1, Length(lResult.Changes));
    Assert.AreEqual(0, lResult.Changes[0].ParameterIndex);
    Assert.AreEqual('aOldValue', lResult.Changes[0].Original.Name);
    Assert.AreEqual('aValue', lResult.Changes[0].ReplacementName);
    Assert.AreEqual(lModel.Routines[0].Parameters[0].Offset, lResult.Changes[0].Original.Offset);
    Assert.AreEqual('aOldValue', lModel.Routines[0].Parameters[0].Name, 'Input remains unchanged');
  finally
    lGraph.Free;
  end;
end;

procedure AlterParameterEvidence(var aModel: TDelphiSemanticUnitModel; const aFault: string);
begin
  if aFault = 'type-token' then
  begin
    Inc(aModel.Routines[0].Parameters[0].Offset, 11);
    Inc(aModel.Routines[0].Parameters[0].EndOffset, 11);
    Inc(aModel.Routines[0].Parameters[0].Column, 11);
  end else if aFault = 'missing' then
    aModel.Routines[0].Parameters := nil
  else if aFault = 'type' then
    aModel.Routines[0].Parameters[0].TypeName := 'TOther'
  else if aFault = 'coordinates' then
    Inc(aModel.Routines[0].Parameters[0].Column)
  else if aFault = 'partial' then
  begin
    aModel.Routines[0].Parameters[0].Name := 'OldValue';
    Inc(aModel.Routines[0].Parameters[0].Offset);
    Inc(aModel.Routines[0].Parameters[0].Column);
    aModel.Routines[0].ProcedureSignature.Parameters[0].Name := 'OldValue';
  end else if aFault = 'body' then
  begin
    aModel.Routines[0].Parameters[0].Offset := Pos('aOldValue :=', aModel.SourceText);
    aModel.Routines[0].Parameters[0].EndOffset := aModel.Routines[0].Parameters[0].Offset + 9;
    aModel.Routines[0].Parameters[0].Line := 12;
    aModel.Routines[0].Parameters[0].Column := 7;
  end;
end;

procedure TSignatureAlignmentTests.RefusesUnprovenParameterPositions(const aFault: string);
var
  lModel: TDelphiSemanticUnitModel;
  lProject: TDelphiSemanticProjectInfo;
  lGraph: TDelphiSemanticSemanticGraph;
  lResult: TDelphiSemanticAlignmentParameterChanges;
begin
  if aFault = 'unicode' then
    lModel := ExtractModel('unicode-drift')
  else if aFault = 'type-token' then
    lModel := ExtractModel('type-token-drift')
  else
    lModel := ExtractModel('body-drift');
  AlterParameterEvidence(lModel, aFault);
  lProject := Default(TDelphiSemanticProjectInfo);
  lGraph := TDelphiSemanticSemanticGraphBuilder.Build(lProject, [lModel]);
  try
    lResult := TDelphiSemanticSignatureAlignment.InspectParameterChanges([lModel],
      TDelphiSemanticTypeResolver.BuildIndex(lGraph), lModel.FileName, AlignmentDeclarationOffset(lModel));
    Assert.AreEqual('name-drift', lResult.Comparison.Status, 'Signature comparison remains separate');
    Assert.IsFalse(lResult.Known, aFault);
    Assert.AreEqual('alignment.parameter-positions-unavailable', lResult.Reason);
    Assert.AreEqual<NativeInt>(0, Length(lResult.Changes), 'No partial mapping escapes');
  finally
    lGraph.Free;
  end;
end;

procedure TSignatureAlignmentTests.CreateAlignmentProject(const aShape: string;
  out aModel: TDelphiSemanticUnitModel;
  out aSnapshot: TDelphiProjectSnapshot);
var
  lDirectory, lProjectFile: string;
  lOptions: TDelphiSemanticOptions;
  lSession: TDelphiSemanticProjectSessionResult;
begin
  aModel := ExtractModel(aShape);
  lDirectory := ExtractFilePath(aModel.FileName);
  lProjectFile := TPath.Combine(lDirectory, 'AlignmentProject.dproj');
  TFile.WriteAllText(TPath.Combine(lDirectory, 'AlignmentProject.dpr'),
    'program AlignmentProject; uses AlignmentSubject in ''AlignmentSubject.pas''; begin end.',
    TEncoding.UTF8);
  TFile.WriteAllText(lProjectFile,
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' +
    '<PropertyGroup><MainSource>AlignmentProject.dpr</MainSource></PropertyGroup>' +
    '<ItemGroup><DCCReference Include="AlignmentSubject.pas"/></ItemGroup></Project>', TEncoding.UTF8);
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := lProjectFile;
  lOptions.Configuration := 'Debug';
  lOptions.Platform := 'Win64';
  lSession := TDelphiSemanticProjectSession.Open(lOptions);
  Assert.IsTrue(lSession.Success);
  try
    aSnapshot := lSession.Session.BuildSnapshot;
    Assert.IsNotNull(aSnapshot);
  finally
    lSession.Session.Free;
  end;
end;

procedure TSignatureAlignmentTests.BuildsBoundAlignmentSuggestion;
var
  lModel: TDelphiSemanticUnitModel;
  lSnapshot: TDelphiProjectSnapshot;
  lGraph: TDelphiSemanticSemanticGraph;
  lResult: TDelphiSemanticBoundPlanResult;
begin
  CreateAlignmentProject('body-drift', lModel, lSnapshot);
  lGraph := TDelphiSemanticSemanticGraphBuilder.Build(Default(TDelphiSemanticProjectInfo), [lModel]);
  try
    lResult := TDelphiSemanticSignatureAlignment.PlanAlignment([lModel],
      TDelphiSemanticTypeResolver.BuildIndex(lGraph), lSnapshot, lModel.FileName,
      AlignmentDeclarationOffset(lModel));
    try
      Assert.IsTrue(lResult.Status = TSemanticPlanStatus.Complete, lResult.Reason);
      Assert.AreEqual('signature.align-implementation', lResult.OperationIdentity);
      Assert.AreEqual(2, lResult.Plan.EditCount, 'Parameter declaration and bound body reference');
      Assert.IsTrue(pvBaselineBuild in lResult.RequiredVerifications);
      Assert.IsTrue(pvPostEditBuild in lResult.RequiredVerifications);
      Assert.AreEqual('aOldValue', lResult.Plan.Edits[0].ExpectedText);
      Assert.AreEqual('aValue', lResult.Plan.Edits[0].ReplacementText);
      Assert.AreEqual('aOldValue', lResult.Plan.Edits[1].ExpectedText);
      Assert.AreEqual('aValue', lResult.Plan.Edits[1].ReplacementText);
    finally
      lResult.Free;
    end;
  finally
    lGraph.Free;
    lSnapshot.Free;
  end;
end;

procedure TSignatureAlignmentTests.RefusesParameterNameCapture(const aShape: string);
var
  lModel: TDelphiSemanticUnitModel;
  lSnapshot: TDelphiProjectSnapshot;
  lGraph: TDelphiSemanticSemanticGraph;
  lResult: TDelphiSemanticBoundPlanResult;
begin
  CreateAlignmentProject(aShape, lModel, lSnapshot);
  lGraph := TDelphiSemanticSemanticGraphBuilder.Build(Default(TDelphiSemanticProjectInfo), [lModel]);
  try
    lResult := TDelphiSemanticSignatureAlignment.PlanAlignment([lModel],
      TDelphiSemanticTypeResolver.BuildIndex(lGraph), lSnapshot, lModel.FileName,
      AlignmentDeclarationOffset(lModel));
    try
      Assert.IsTrue(lResult.Status = TSemanticPlanStatus.Incomplete, lResult.Reason);
      Assert.AreEqual('alignment.name-capture', lResult.Reason);
      Assert.IsNull(lResult.Plan, 'Capture must not expose a partially applicable plan');
    finally
      lResult.Free;
    end;
  finally
    lGraph.Free;
    lSnapshot.Free;
  end;
end;

procedure TSignatureAlignmentTests.RefusesUnresolvedNestedParameterReference;
var
  lModel: TDelphiSemanticUnitModel;
  lSnapshot: TDelphiProjectSnapshot;
  lGraph: TDelphiSemanticSemanticGraph;
  lResult: TDelphiSemanticBoundPlanResult;
begin
  CreateAlignmentProject('nested-reference', lModel, lSnapshot);
  lGraph := TDelphiSemanticSemanticGraphBuilder.Build(Default(TDelphiSemanticProjectInfo), [lModel]);
  try
    lResult := TDelphiSemanticSignatureAlignment.PlanAlignment([lModel],
      TDelphiSemanticTypeResolver.BuildIndex(lGraph), lSnapshot, lModel.FileName,
      AlignmentDeclarationOffset(lModel));
    try
      Assert.IsTrue(lResult.Status = TSemanticPlanStatus.Incomplete,
        'An unresolved captured parameter must not produce a header-only plan');
      Assert.AreEqual('alignment.reference-proof-unavailable', lResult.Reason);
      Assert.IsNull(lResult.Plan, 'No partial suggestion escapes');
    finally
      lResult.Free;
    end;
  finally
    lGraph.Free;
    lSnapshot.Free;
  end;
end;

procedure AlterAlignmentEvidence(var aModel: TDelphiSemanticUnitModel; const aFault: string);
begin
  if aFault = 'signature' then
    aModel.Members[0].ProcedureSignature.Parameters[0].Name := 'aAlternative'
  else if aFault = 'nested-parent' then
    aModel.Routines[1].ParentScopeId := ''
  else if aFault = 'references' then
    aModel.References := nil
  else if aFault = 'locals' then
  begin
    aModel.Locals := nil;
    aModel.References := nil;
  end;
end;

procedure TSignatureAlignmentTests.RefusesDivergentModelEvidence(const aFault: string);
var
  lModel: TDelphiSemanticUnitModel;
  lSnapshot: TDelphiProjectSnapshot;
  lGraph: TDelphiSemanticSemanticGraph;
  lResult: TDelphiSemanticBoundPlanResult;
  lShape: string;
begin
  lShape := 'body-drift';
  if aFault = 'references' then
    lShape := 'capture-field'
  else if aFault = 'nested-parent' then
    lShape := 'nested-reference'
  else if aFault = 'locals' then
    lShape := 'capture-local';
  CreateAlignmentProject(lShape, lModel, lSnapshot);
  AlterAlignmentEvidence(lModel, aFault);
  lGraph := TDelphiSemanticSemanticGraphBuilder.Build(Default(TDelphiSemanticProjectInfo), [lModel]);
  try
    lResult := TDelphiSemanticSignatureAlignment.PlanAlignment([lModel],
      TDelphiSemanticTypeResolver.BuildIndex(lGraph), lSnapshot, lModel.FileName,
      AlignmentDeclarationOffset(lModel));
    try
      Assert.IsTrue(lResult.Status = TSemanticPlanStatus.Incomplete,
        'Equal source text cannot certify altered semantic facts: ' + aFault);
      Assert.AreEqual('alignment.model-evidence-mismatch', lResult.Reason);
      Assert.IsNull(lResult.Plan);
    finally
      lResult.Free;
    end;
  finally
    lGraph.Free;
    lSnapshot.Free;
  end;
end;

function CopyEvidenceContext(const aEvidence: TDelphiSemanticContextEvidenceExtension):
  TDelphiSemanticContextEvidenceContext;
begin
  Result := Default(TDelphiSemanticContextEvidenceContext);
  Result.SessionOpen := aEvidence.SessionOpen;
  Result.ProjectFileName := aEvidence.ProjectFileName;
  Result.MainSourceFileName := aEvidence.MainSourceFileName;
  Result.CompilerLinkProperties := aEvidence.CompilerLinkProperties;
  Result.CompilerIdentity := aEvidence.CompilerIdentity;
  Result.ModelVersion := aEvidence.ModelVersion;
  Result.ProjectContextFingerprint := aEvidence.ProjectContextFingerprint;
  Result.ExpectedRootFileNames := aEvidence.ExpectedRootFileNames;
  Result.RequestedAnalysisFileNames := aEvidence.RequestedAnalysisFileNames;
  Result.ProjectDiagnostics := aEvidence.ProjectDiagnostics;
end;

function SnapshotWithDifferentEvidence(const aEvidence: TDelphiSemanticContextEvidenceExtension):
  TDelphiProjectSnapshot;
var
  i: Integer;
  lEvidence: TArray<TDelphiSemanticContextModelEvidence>;
  lModels: TArray<TDelphiSemanticUnitModel>;
  lOptions: TDelphiSemanticModelOptions;
  lExtension: TObject;
  lMetrics: TDelphiSnapshotBuilderMetrics;
begin
  SetLength(lEvidence, aEvidence.ModelCount);
  SetLength(lModels, aEvidence.ModelCount);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.ProjectContextApplied := True;
  for i := 0 to High(lEvidence) do
  begin
    lEvidence[i] := aEvidence.ModelEvidence[i];
    lOptions.SourceFileName := lEvidence[i].SourceFileName;
    lModels[i] := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
    Assert.IsTrue(lModels[i].Success, 'Identity fixture model must parse');
  end;
  lEvidence[0].SemanticModelFingerprint := 'different-semantic-evidence';
  lExtension := TDelphiSemanticContextEvidenceExtension.Create(CopyEvidenceContext(aEvidence),
    aEvidence.ProjectObservations, lEvidence);
  try
    Result := BuildProjectSnapshotFromModelsWithExtension(lModels,
      Default(TDelphiSemanticProjectWithBindingFacts), Default(TDelphiSnapshotBuildOptions),
      cDelphiSemanticContextEvidenceExtensionName, lExtension, lMetrics);
  finally
    lExtension.Free;
  end;
end;

procedure TSignatureAlignmentTests.BindingIdentityIncludesSemanticModelEvidence;
var
  lModel: TDelphiSemanticUnitModel;
  lSnapshot, lChanged: TDelphiProjectSnapshot;
  lExtension: TObject;
  lRequest: TDelphiSemanticPlanBindingRequest;
  lOriginal, lDifferent: TDelphiSemanticBoundPlanResult;
begin
  CreateAlignmentProject('body-drift', lModel, lSnapshot);
  lChanged := nil;
  lOriginal := nil;
  lDifferent := nil;
  try
    Assert.IsTrue(lSnapshot.TryGetExtension(cDelphiSemanticContextEvidenceExtensionName, lExtension));
    lRequest := Default(TDelphiSemanticPlanBindingRequest);
    lRequest.OperationIdentity := 'signature.align-implementation';
    lRequest.Status := TSemanticPlanStatus.NoChange;
    lRequest.ScopeRootFileNames := [lModel.FileName];
    lRequest.RequiredAnalysisKinds := [pakBodyAnalysis, pakReferenceExtraction];
    lRequest.SelectedConfigurationIdentities := [
      (lExtension as TDelphiSemanticContextEvidenceExtension).ProjectConfigurationIdentity];
    lChanged := SnapshotWithDifferentEvidence((lExtension as TDelphiSemanticContextEvidenceExtension));
    lOriginal := TDelphiSemanticPlanBinder.Bind(lSnapshot, lRequest);
    lDifferent := TDelphiSemanticPlanBinder.Bind(lChanged, lRequest);
    Assert.IsTrue(lOriginal.Status = TSemanticPlanStatus.NoChange, lOriginal.Reason);
    Assert.IsTrue(lDifferent.Status = TSemanticPlanStatus.NoChange, lDifferent.Reason);
    Assert.IsFalse(lOriginal.ContextFingerprint = lDifferent.ContextFingerprint,
      'Same source with different semantic evidence must change context identity');
    Assert.IsFalse(lOriginal.BindingFingerprint = lDifferent.BindingFingerprint);
  finally
    lDifferent.Free;
    lOriginal.Free;
    lChanged.Free;
    lSnapshot.Free;
  end;
end;

procedure AssertIsolatedEvidenceCopies(const aEvidence: TDelphiSemanticContextEvidenceExtension;
  const aModel: TDelphiSemanticUnitModel);
var
  i: Integer;
  lCopy, lMissing: TDelphiSemanticContextEvidenceExtension;
  lModels: TArray<TDelphiSemanticContextModelEvidence>;
  lReturned: TDelphiSemanticContextModelEvidence;
begin
  SetLength(lModels, aEvidence.ModelCount);
  for i := 0 to High(lModels) do
    lModels[i] := aEvidence.ModelEvidence[i];
  lCopy := TDelphiSemanticContextEvidenceExtension.Create(CopyEvidenceContext(aEvidence),
    aEvidence.ProjectObservations, lModels);
  lMissing := nil;
  try
    for i := 0 to High(lModels) do
    begin
      lModels[i].SemanticModelFingerprint := '';
      lReturned := lCopy.ModelEvidence[i];
      lReturned.SemanticModelFingerprint := '';
      Assert.IsEmpty(lReturned.SemanticModelFingerprint);
      lReturned := lCopy.ModelEvidence[i];
      Assert.IsNotEmpty(lReturned.SemanticModelFingerprint);
    end;
    Assert.IsTrue(lCopy.MatchesModel(aModel), 'Caller copies cannot erase retained fingerprint');
    lMissing := TDelphiSemanticContextEvidenceExtension.Create(CopyEvidenceContext(aEvidence),
      aEvidence.ProjectObservations, lModels);
    Assert.IsTrue(lMissing.HasCoProducedEvidence, 'Legacy generic context remains compatible');
    Assert.IsFalse(lMissing.MatchesModel(aModel), 'Missing fingerprints cannot certify model facts');
  finally
    lMissing.Free;
    lCopy.Free;
  end;
end;

procedure TSignatureAlignmentTests.CapturedModelEvidenceIsIsolated;
var
  lModel: TDelphiSemanticUnitModel;
  lSnapshot: TDelphiProjectSnapshot;
  lExtension: TObject;
  lEvidence: TDelphiSemanticContextEvidenceExtension;
begin
  CreateAlignmentProject('body-drift', lModel, lSnapshot);
  try
    Assert.IsTrue(lSnapshot.TryGetExtension(cDelphiSemanticContextEvidenceExtensionName, lExtension));
    lEvidence := lExtension as TDelphiSemanticContextEvidenceExtension;
    Assert.IsTrue(lEvidence.MatchesModel(lModel));
    AssertIsolatedEvidenceCopies(lEvidence, lModel);
  finally
    lSnapshot.Free;
  end;
end;

procedure TSignatureAlignmentTests.RefusesUncoveredBodyTokens(const aShape: string);
var
  lModel: TDelphiSemanticUnitModel;
  lSnapshot: TDelphiProjectSnapshot;
  lGraph: TDelphiSemanticSemanticGraph;
  lResult: TDelphiSemanticBoundPlanResult;
begin
  CreateAlignmentProject(aShape, lModel, lSnapshot);
  lGraph := TDelphiSemanticSemanticGraphBuilder.Build(Default(TDelphiSemanticProjectInfo), [lModel]);
  try
    lResult := TDelphiSemanticSignatureAlignment.PlanAlignment([lModel],
      TDelphiSemanticTypeResolver.BuildIndex(lGraph), lSnapshot, lModel.FileName,
      AlignmentDeclarationOffset(lModel));
    try
      Assert.IsTrue(lResult.Status = TSemanticPlanStatus.Incomplete,
        'A complete AST does not prove extracted body token coverage: ' + aShape);
      Assert.AreEqual('alignment.reference-proof-unavailable', lResult.Reason);
      Assert.IsNull(lResult.Plan);
    finally
      lResult.Free;
    end;
  finally
    lGraph.Free;
    lSnapshot.Free;
  end;
end;

procedure TSignatureAlignmentTests.LeavesCommentsStringsAndQualifiedMembersUntouched;
var
  lModel: TDelphiSemanticUnitModel;
  lSnapshot: TDelphiProjectSnapshot;
  lGraph: TDelphiSemanticSemanticGraph;
  lResult: TDelphiSemanticBoundPlanResult;
  lLines: TArray<string>;
  lBody: string;
begin
  CreateAlignmentProject('qualified-literals', lModel, lSnapshot);
  lGraph := TDelphiSemanticSemanticGraphBuilder.Build(Default(TDelphiSemanticProjectInfo), [lModel]);
  try
    lResult := TDelphiSemanticSignatureAlignment.PlanAlignment([lModel],
      TDelphiSemanticTypeResolver.BuildIndex(lGraph), lSnapshot, lModel.FileName,
      AlignmentDeclarationOffset(lModel));
    try
      Assert.IsTrue(lResult.Status = TSemanticPlanStatus.Complete, lResult.Reason);
      Assert.AreEqual(2, lResult.Plan.EditCount, 'Only the parameter header and assignment');
      Assert.AreEqual(lModel.Routines[0].Parameters[0].Line, lResult.Plan.Edits[0].StartLine);
      Assert.AreEqual(lModel.Routines[0].Parameters[0].Column, lResult.Plan.Edits[0].StartColumn);
      lLines := lModel.SourceText.Split([#10]);
      lBody := lLines[lResult.Plan.Edits[1].StartLine - 1];
      Assert.IsTrue(Pos('then aOldValue', lBody) > 0);
      Assert.AreEqual(Pos('then aOldValue', lBody) + 5, lResult.Plan.Edits[1].StartColumn);
      Assert.AreEqual('aOldValue', lResult.Plan.Edits[1].ExpectedText);
      Assert.AreEqual('aValue', lResult.Plan.Edits[1].ReplacementText);
    finally
      lResult.Free;
    end;
  finally
    lGraph.Free;
    lSnapshot.Free;
  end;
end;

procedure AssertMultipleParameterEdits(const aPlan: TSemanticRefactoringPlan;
  const aShape: string);
var
  i, lFirstCount, lSecondCount: Integer;
  lEdit: TSemanticPlanEdit;
  lFirst, lSecond: string;
begin
  lFirst := 'aOldFirst';
  lSecond := 'aOldSecond';
  if aShape = 'swap-drift' then
  begin
    lFirst := 'aSecond';
    lSecond := 'aFirst';
  end;
  lFirstCount := 0;
  lSecondCount := 0;
  Assert.AreEqual(4, aPlan.EditCount, 'Both headers and their bound body uses');
  for i := 0 to aPlan.EditCount - 1 do
  begin
    lEdit := aPlan.Edits[i];
    if lEdit.ExpectedText = lFirst then
    begin
      Assert.AreEqual('aFirst', lEdit.ReplacementText);
      Inc(lFirstCount);
    end else
    begin
      Assert.AreEqual(lSecond, lEdit.ExpectedText);
      Assert.AreEqual('aSecond', lEdit.ReplacementText);
      Inc(lSecondCount);
    end;
  end;
  Assert.AreEqual(2, lFirstCount);
  Assert.AreEqual(2, lSecondCount);
end;

procedure TSignatureAlignmentTests.MapsMultipleParameterNames(const aShape: string);
var
  lModel: TDelphiSemanticUnitModel;
  lSnapshot: TDelphiProjectSnapshot;
  lGraph: TDelphiSemanticSemanticGraph;
  lResult: TDelphiSemanticBoundPlanResult;
begin
  CreateAlignmentProject(aShape, lModel, lSnapshot);
  lGraph := TDelphiSemanticSemanticGraphBuilder.Build(Default(TDelphiSemanticProjectInfo), [lModel]);
  try
    lResult := TDelphiSemanticSignatureAlignment.PlanAlignment([lModel],
      TDelphiSemanticTypeResolver.BuildIndex(lGraph), lSnapshot, lModel.FileName,
      AlignmentDeclarationOffset(lModel));
    try
      Assert.IsTrue(lResult.Status = TSemanticPlanStatus.Complete, lResult.Reason);
      Assert.IsTrue(pvBaselineBuild in lResult.RequiredVerifications);
      Assert.IsTrue(pvPostEditBuild in lResult.RequiredVerifications);
      AssertMultipleParameterEdits(lResult.Plan, aShape);
    finally
      lResult.Free;
    end;
  finally
    lGraph.Free;
    lSnapshot.Free;
  end;
end;

procedure TSignatureAlignmentTests.RetainsSignatureShapeInPlan(const aShape: string);
var
  lModel: TDelphiSemanticUnitModel;
  lSnapshot: TDelphiProjectSnapshot;
  lGraph: TDelphiSemanticSemanticGraph;
  lResult: TDelphiSemanticBoundPlanResult;
  lEdit: TSemanticPlanEdit;
  i: Integer;
begin
  CreateAlignmentProject(aShape, lModel, lSnapshot);
  lGraph := TDelphiSemanticSemanticGraphBuilder.Build(Default(TDelphiSemanticProjectInfo), [lModel]);
  try
    lResult := TDelphiSemanticSignatureAlignment.PlanAlignment([lModel],
      TDelphiSemanticTypeResolver.BuildIndex(lGraph), lSnapshot, lModel.FileName,
      AlignmentDeclarationOffset(lModel));
    try
      Assert.IsTrue(lResult.Status = TSemanticPlanStatus.Complete, lResult.Reason);
      Assert.AreEqual(2, lResult.Plan.EditCount, 'Only the parameter header and body identifier');
      Assert.IsTrue(pvBaselineBuild in lResult.RequiredVerifications);
      Assert.IsTrue(pvPostEditBuild in lResult.RequiredVerifications);
      for i := 0 to lResult.Plan.EditCount - 1 do
      begin
        lEdit := lResult.Plan.Edits[i];
        Assert.AreEqual('aOldValue', lEdit.ExpectedText);
        Assert.AreEqual('aValue', lEdit.ReplacementText);
      end;
    finally
      lResult.Free;
    end;
  finally
    lGraph.Free;
    lSnapshot.Free;
  end;
end;

procedure TSignatureAlignmentTests.RefusesSignatureShapeChanges(const aShape: string);
var
  lModel: TDelphiSemanticUnitModel;
  lSnapshot: TDelphiProjectSnapshot;
  lGraph: TDelphiSemanticSemanticGraph;
  lResult: TDelphiSemanticBoundPlanResult;
begin
  CreateAlignmentProject(aShape, lModel, lSnapshot);
  lGraph := TDelphiSemanticSemanticGraphBuilder.Build(Default(TDelphiSemanticProjectInfo), [lModel]);
  try
    lResult := TDelphiSemanticSignatureAlignment.PlanAlignment([lModel],
      TDelphiSemanticTypeResolver.BuildIndex(lGraph), lSnapshot, lModel.FileName,
      AlignmentDeclarationOffset(lModel));
    try
      Assert.IsTrue(lResult.Status = TSemanticPlanStatus.Incomplete, aShape);
      Assert.IsTrue(lResult.Reason <> '', 'A refused shape needs a reason');
      Assert.IsNull(lResult.Plan, 'An incompatible signature must not expose partial edits');
    finally
      lResult.Free;
    end;
  finally
    lGraph.Free;
    lSnapshot.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TSignatureAlignmentTests);

end.