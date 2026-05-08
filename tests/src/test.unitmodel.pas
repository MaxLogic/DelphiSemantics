unit Test.UnitModel;

interface

uses
  DUnitX.TestFramework,
  DelphiSemantics.Model,
  DelphiSemantics.Source;

type
  [TestFixture]
  TUnitModelTests = class
  private
    function FixturePath(const aFolder, aFileName: string): string;
    function HasDeclaration(const aModel: TDelphiSemanticUnitModel; const aName, aKind,
      aSection: string): Boolean;
    function HasDiagnostic(const aModel: TDelphiSemanticUnitModel; const aCode: string): Boolean;
    function HasMemberOfOwner(const aModel: TDelphiSemanticUnitModel; const aOwnerName,
      aName: string): Boolean;
    function HasMemberOnLine(const aModel: TDelphiSemanticUnitModel; const aOwnerName,
      aName: string; const aLine: Integer): Boolean;
    function HasLocal(const aModel: TDelphiSemanticUnitModel; const aRoutineName, aName,
      aTypeName: string): Boolean;
    function HasLocalOnLine(const aModel: TDelphiSemanticUnitModel; const aRoutineName,
      aName: string; const aLine: Integer): Boolean;
    function HasMember(const aModel: TDelphiSemanticUnitModel; const aOwnerName, aName, aKind,
      aTypeName: string): Boolean;
    function FindDeclaration(const aModel: TDelphiSemanticUnitModel; const aName, aKind,
      aSection: string; out aDeclaration: TDelphiSemanticDeclaration): Boolean;
    function FindMember(const aModel: TDelphiSemanticUnitModel; const aOwnerName, aName, aKind:
      string; out aMember: TDelphiSemanticMember): Boolean;
    function HasReference(const aModel: TDelphiSemanticUnitModel; const aName: string): Boolean;
    function HasReferenceOnLine(const aModel: TDelphiSemanticUnitModel; const aName: string;
      const aLine: Integer): Boolean;
    function FindRoutine(const aModel: TDelphiSemanticUnitModel; const aName, aSection: string;
      out aRoutine: TDelphiSemanticRoutine): Boolean;
    function HasRoutine(const aModel: TDelphiSemanticUnitModel; const aName, aSection: string):
      Boolean;
    function HasRoutineOnLine(const aModel: TDelphiSemanticUnitModel; const aName: string;
      const aLine: Integer): Boolean;
    function LineContaining(const aText, aPattern: string): Integer;
    function StatementText(const aText: string; const aStartLine, aStartColumn, aEndLine,
      aEndColumn: Integer): string;
    function LineOfDeclaration(const aModel: TDelphiSemanticUnitModel; const aName: string):
      Integer;
  public
    [Test]
    procedure SourceLoaderUsesAnsiFallbackForInvalidUtf8;
    [Test]
    procedure SourceLoaderUsesAnsiFallbackForMalformedUtf8;
    [Test]
    procedure ExtractsUnitNameUsesDeclarationsAndWithStatements;
    [Test]
    procedure ExtractsMembersRoutinesLocalsAndReferences;
    [Test]
    procedure ExtractsUnprefixedConstVarAndTypedConstDeclarations;
    [Test]
    procedure MigratedSymbolMapExtractsUnitNameAndUsesSections;
    [Test]
    procedure MigratedSymbolMapExtractsNamespacedUnitName;
    [Test]
    procedure MigratedSymbolMapExtractsTopLevelDeclarationsAndEnumValues;
    [Test]
    procedure MigratedSymbolMapExtractsMembersPropertiesAndMetadata;
    [Test]
    procedure PreprocessingRemovesInactiveDeclarations;
    [Test]
    procedure IncludeExpansionDoesNotShiftFollowingParentLineNumbers;
    [Test]
    procedure IncludeExpansionPreservesMultiLineIncludedDeclarations;
    [Test]
    procedure IncludeExpansionDoesNotShiftFollowingParentWithRanges;
    [Test]
    procedure ModelUsesSourceLoaderFallbackWhenExtractingAnsiSource;
    [Test]
    procedure WithStatementsExposeSourceRanges;
    [Test]
    procedure WithDiscoveryIgnoresStringsAndCommentsAndKeepsRepeatedRanges;
    [Test]
    procedure ReferencesIgnoreStringsAndComments;
    [Test]
    procedure IncludeExpansionDoesNotShiftFollowingParentReferences;
    [Test]
    procedure IncludeExpansionDoesNotShiftFollowingParentMembersRoutinesAndLocals;
    [Test]
    procedure WithStatementRangeCoversIfThenElseBodies;
    [Test]
    procedure ModelKeepsOriginalSourceLineNumbersAfterPreprocessing;
    [Test]
    procedure ModelPropagatesSourceAndPreprocessDiagnostics;
    [Test]
    procedure StandaloneExtractionReportsDegradedMode;
  end;

implementation

uses
  System.IOUtils, System.SysUtils,
  maxLogic.IOUtils;

function TUnitModelTests.FixturePath(const aFolder, aFileName: string): string;
begin
  Result := TPath.GetFullPath(CombinePath([ExtractFilePath(ParamStr(0)), '..', 'fixtures',
    aFolder, aFileName]));
end;

function TUnitModelTests.HasDeclaration(const aModel: TDelphiSemanticUnitModel;
  const aName, aKind, aSection: string): Boolean;
var
  lDeclaration: TDelphiSemanticDeclaration;
begin
  for lDeclaration in aModel.Declarations do
    if SameText(lDeclaration.Name, aName) and SameText(lDeclaration.Kind, aKind) and
      SameText(lDeclaration.SectionKind, aSection) then
      Exit(True);

  Result := False;
end;

function TUnitModelTests.HasDiagnostic(const aModel: TDelphiSemanticUnitModel;
  const aCode: string): Boolean;
var
  lDiagnostic: TDelphiSemanticModelDiagnostic;
begin
  for lDiagnostic in aModel.Diagnostics do
    if SameText(lDiagnostic.Code, aCode) then
      Exit(True);

  Result := False;
end;

function TUnitModelTests.HasMemberOfOwner(const aModel: TDelphiSemanticUnitModel;
  const aOwnerName, aName: string): Boolean;
var
  lMember: TDelphiSemanticMember;
begin
  for lMember in aModel.Members do
    if SameText(lMember.OwnerName, aOwnerName) and SameText(lMember.Name, aName) then
      Exit(True);

  Result := False;
end;

function TUnitModelTests.HasMemberOnLine(const aModel: TDelphiSemanticUnitModel;
  const aOwnerName, aName: string; const aLine: Integer): Boolean;
var
  lMember: TDelphiSemanticMember;
begin
  for lMember in aModel.Members do
    if SameText(lMember.OwnerName, aOwnerName) and SameText(lMember.Name, aName) and
      (lMember.Line = aLine) then
      Exit(True);

  Result := False;
end;

function TUnitModelTests.HasLocal(const aModel: TDelphiSemanticUnitModel;
  const aRoutineName, aName, aTypeName: string): Boolean;
var
  lLocal: TDelphiSemanticLocal;
begin
  for lLocal in aModel.Locals do
    if SameText(lLocal.RoutineName, aRoutineName) and SameText(lLocal.Name, aName) and
      SameText(lLocal.TypeName, aTypeName) then
      Exit(True);

  Result := False;
end;

function TUnitModelTests.HasLocalOnLine(const aModel: TDelphiSemanticUnitModel;
  const aRoutineName, aName: string; const aLine: Integer): Boolean;
var
  lLocal: TDelphiSemanticLocal;
begin
  for lLocal in aModel.Locals do
    if SameText(lLocal.RoutineName, aRoutineName) and SameText(lLocal.Name, aName) and
      (lLocal.Line = aLine) then
      Exit(True);

  Result := False;
end;

function TUnitModelTests.HasMember(const aModel: TDelphiSemanticUnitModel;
  const aOwnerName, aName, aKind, aTypeName: string): Boolean;
var
  lMember: TDelphiSemanticMember;
begin
  for lMember in aModel.Members do
    if SameText(lMember.OwnerName, aOwnerName) and SameText(lMember.Name, aName) and
      SameText(lMember.Kind, aKind) and SameText(lMember.TypeName, aTypeName) then
      Exit(True);

  Result := False;
end;

function TUnitModelTests.FindDeclaration(const aModel: TDelphiSemanticUnitModel;
  const aName, aKind, aSection: string; out aDeclaration: TDelphiSemanticDeclaration): Boolean;
var
  lDeclaration: TDelphiSemanticDeclaration;
begin
  for lDeclaration in aModel.Declarations do
    if SameText(lDeclaration.Name, aName) and SameText(lDeclaration.Kind, aKind) and
      SameText(lDeclaration.SectionKind, aSection) then
    begin
      aDeclaration := lDeclaration;
      Exit(True);
    end;

  aDeclaration := Default(TDelphiSemanticDeclaration);
  Result := False;
end;

function TUnitModelTests.FindMember(const aModel: TDelphiSemanticUnitModel;
  const aOwnerName, aName, aKind: string; out aMember: TDelphiSemanticMember): Boolean;
var
  lMember: TDelphiSemanticMember;
begin
  for lMember in aModel.Members do
    if SameText(lMember.OwnerName, aOwnerName) and SameText(lMember.Name, aName) and
      SameText(lMember.Kind, aKind) then
    begin
      aMember := lMember;
      Exit(True);
    end;

  aMember := Default(TDelphiSemanticMember);
  Result := False;
end;

function TUnitModelTests.HasReference(const aModel: TDelphiSemanticUnitModel;
  const aName: string): Boolean;
var
  lReference: TDelphiSemanticReference;
begin
  for lReference in aModel.References do
    if SameText(lReference.Name, aName) then
      Exit(True);

  Result := False;
end;

function TUnitModelTests.HasReferenceOnLine(const aModel: TDelphiSemanticUnitModel;
  const aName: string; const aLine: Integer): Boolean;
var
  lReference: TDelphiSemanticReference;
begin
  for lReference in aModel.References do
    if SameText(lReference.Name, aName) and (lReference.Line = aLine) then
      Exit(True);

  Result := False;
end;

function TUnitModelTests.FindRoutine(const aModel: TDelphiSemanticUnitModel;
  const aName, aSection: string; out aRoutine: TDelphiSemanticRoutine): Boolean;
var
  lRoutine: TDelphiSemanticRoutine;
begin
  for lRoutine in aModel.Routines do
    if SameText(lRoutine.Name, aName) and SameText(lRoutine.SectionKind, aSection) then
    begin
      aRoutine := lRoutine;
      Exit(True);
    end;

  aRoutine := Default(TDelphiSemanticRoutine);
  Result := False;
end;

function TUnitModelTests.HasRoutine(const aModel: TDelphiSemanticUnitModel;
  const aName, aSection: string): Boolean;
var
  lRoutine: TDelphiSemanticRoutine;
begin
  for lRoutine in aModel.Routines do
    if SameText(lRoutine.Name, aName) and SameText(lRoutine.SectionKind, aSection) then
      Exit(True);

  Result := False;
end;

function TUnitModelTests.HasRoutineOnLine(const aModel: TDelphiSemanticUnitModel;
  const aName: string; const aLine: Integer): Boolean;
var
  lRoutine: TDelphiSemanticRoutine;
begin
  for lRoutine in aModel.Routines do
    if SameText(lRoutine.Name, aName) and (lRoutine.Line = aLine) then
      Exit(True);

  Result := False;
end;

function TUnitModelTests.LineOfDeclaration(const aModel: TDelphiSemanticUnitModel;
  const aName: string): Integer;
var
  lDeclaration: TDelphiSemanticDeclaration;
begin
  for lDeclaration in aModel.Declarations do
    if SameText(lDeclaration.Name, aName) then
      Exit(lDeclaration.Line);

  Result := 0;
end;

function TUnitModelTests.LineContaining(const aText, aPattern: string): Integer;
var
  i: Integer;
  lLine: Integer;
begin
  Result := 0;
  lLine := 1;
  for i := 1 to Length(aText) do
  begin
    if SameText(Copy(aText, i, Length(aPattern)), aPattern) then
      Exit(lLine);
    if aText[i] = #10 then
      Inc(lLine);
  end;
end;

function TUnitModelTests.StatementText(const aText: string; const aStartLine, aStartColumn,
  aEndLine, aEndColumn: Integer): string;
var
  i: Integer;
  lColumn: Integer;
  lEndOffset: Integer;
  lLine: Integer;
  lStartOffset: Integer;
begin
  lLine := 1;
  lColumn := 1;
  lStartOffset := 0;
  lEndOffset := 0;
  for i := 1 to Length(aText) do
  begin
    if (lLine = aStartLine) and (lColumn = aStartColumn) and (lStartOffset = 0) then
      lStartOffset := i;
    if (lLine = aEndLine) and (lColumn = aEndColumn) then
    begin
      lEndOffset := i;
      Break;
    end;

    if aText[i] = #10 then
    begin
      Inc(lLine);
      lColumn := 1;
    end else if aText[i] <> #13 then
      Inc(lColumn);
  end;

  if (lStartOffset = 0) or (lEndOffset = 0) then
    Exit('');

  Result := Copy(aText, lStartOffset, lEndOffset - lStartOffset + 1);
end;

procedure TUnitModelTests.SourceLoaderUsesAnsiFallbackForInvalidUtf8;
var
  lBytes: TBytes;
  lResult: TDelphiSemanticSourceLoadResult;
  lPath: string;
begin
  lPath := TPath.Combine(ExtractFilePath(ParamStr(0)), 'unit-model-ansi-source.pas');
  lBytes := [$75, $6E, $69, $74, $20, $41, $6E, $73, $69, $46, $61, $6C, $6C, $62, $61, $63,
    $6B, $3B, $0D, $0A, $69, $6E, $74, $65, $72, $66, $61, $63, $65, $0D, $0A, $2F, $2F,
    $20, $E4, $0D, $0A, $69, $6D, $70, $6C, $65, $6D, $65, $6E, $74, $61, $74, $69,
    $6F, $6E, $0D, $0A, $65, $6E, $64, $2E];
  TFile.WriteAllBytes(lPath, lBytes);

  lResult := TDelphiSemanticSourceLoader.LoadFile(lPath);

  Assert.IsTrue(lResult.Success);
  Assert.AreEqual('windows-1252', lResult.Source.EncodingName);
  Assert.IsTrue(Pos('AnsiFallback', lResult.Source.Text) > 0);
end;

procedure TUnitModelTests.SourceLoaderUsesAnsiFallbackForMalformedUtf8;
var
  lBytes: TBytes;
  lResult: TDelphiSemanticSourceLoadResult;
  lPath: string;
begin
  lPath := TPath.Combine(ExtractFilePath(ParamStr(0)), 'unit-model-overlong-source.pas');
  lBytes := [$75, $6E, $69, $74, $20, $4F, $76, $65, $72, $6C, $6F, $6E, $67, $46, $61, $6C,
    $6C, $62, $61, $63, $6B, $3B, $0D, $0A, $69, $6E, $74, $65, $72, $66, $61, $63,
    $65, $0D, $0A, $2F, $2F, $20, $C0, $AF, $0D, $0A, $69, $6D, $70, $6C, $65, $6D,
    $65, $6E, $74, $61, $74, $69, $6F, $6E, $0D, $0A, $65, $6E, $64, $2E];
  TFile.WriteAllBytes(lPath, lBytes);

  lResult := TDelphiSemanticSourceLoader.LoadFile(lPath);

  Assert.IsTrue(lResult.Success);
  Assert.AreEqual('windows-1252', lResult.Source.EncodingName);
  Assert.IsTrue(Pos('OverlongFallback', lResult.Source.Text) > 0);
end;

procedure TUnitModelTests.ExtractsUnitNameUsesDeclarationsAndWithStatements;
var
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := FixturePath('UnitModel', 'SemanticUnit.pas');
  lOptions.ProjectContextApplied := True;

  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsTrue(lModel.Success);
  Assert.AreEqual('SemanticUnit', lModel.UnitName);
  Assert.AreEqual('utf-8', lModel.EncodingName);
  Assert.AreEqual(2, Length(lModel.InterfaceUses));
  Assert.AreEqual('System.SysUtils', lModel.InterfaceUses[0]);
  Assert.AreEqual('Winapi.Windows', lModel.InterfaceUses[1]);
  Assert.AreEqual(1, Length(lModel.ImplementationUses));
  Assert.AreEqual('System.Classes', lModel.ImplementationUses[0]);
  Assert.IsTrue(HasDeclaration(lModel, 'TSemanticEnum', 'type', 'interface'));
  Assert.IsTrue(HasDeclaration(lModel, 'seOne', 'enum-value', 'interface'));
  Assert.IsTrue(HasDeclaration(lModel, 'TSemanticAlias', 'type-alias', 'interface'));
  Assert.IsTrue(HasDeclaration(lModel, 'TSemanticRecord', 'type', 'interface'));
  Assert.IsTrue(HasDeclaration(lModel, 'TAfterClassType', 'type', 'interface'));
  Assert.IsTrue(HasDeclaration(lModel, 'cSemanticConst', 'const', 'interface'));
  Assert.IsTrue(HasDeclaration(lModel, 'GSemanticGlobal', 'var', 'interface'));
  Assert.IsTrue(HasDeclaration(lModel, 'SemanticProcedure', 'routine', 'interface'));
  Assert.AreEqual(1, Length(lModel.WithStatements));
  Assert.AreNotEqual(0, lModel.WithStatements[0].Line);
end;

procedure TUnitModelTests.ExtractsMembersRoutinesLocalsAndReferences;
var
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := FixturePath('UnitModel', 'SemanticUnit.pas');
  lOptions.ProjectContextApplied := True;

  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsTrue(lModel.Success);
  Assert.IsTrue(HasMember(lModel, 'TSemanticRecord', 'Value', 'field', 'Integer'));
  Assert.IsTrue(HasMember(lModel, 'TSemanticClass', 'FName', 'field', 'string'));
  Assert.IsTrue(HasMember(lModel, 'TSemanticClass', 'Name', 'property', 'string'));
  Assert.IsTrue(HasRoutine(lModel, 'SemanticProcedure', 'interface'));
  Assert.IsTrue(HasRoutine(lModel, 'SetName', 'implementation'));
  Assert.IsFalse(HasDeclaration(lModel, 'SetName', 'routine', 'interface'));
  Assert.IsTrue(HasLocal(lModel, 'SemanticProcedure', 'lRecord', 'TSemanticRecord'));
  Assert.IsTrue(HasReference(lModel, 'Value'));
  Assert.IsTrue(HasReference(lModel, 'Length'));
  Assert.IsTrue(HasReference(lModel, 'SemanticGlobal'));
end;

procedure TUnitModelTests.ExtractsUnprefixedConstVarAndTypedConstDeclarations;
var
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := FixturePath('UnitModel', 'SemanticUnit.pas');
  lOptions.ProjectContextApplied := True;

  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsTrue(lModel.Success);
  Assert.IsTrue(HasDeclaration(lModel, 'PlainSemanticConst', 'const', 'interface'));
  Assert.IsTrue(HasDeclaration(lModel, 'TypedSemanticConst', 'typed-const', 'interface'));
  Assert.IsFalse(HasDeclaration(lModel, 'PlainSemanticConst', 'type-alias', 'interface'));
  Assert.IsTrue(HasDeclaration(lModel, 'SemanticGlobal', 'var', 'interface'));
end;

procedure TUnitModelTests.MigratedSymbolMapExtractsUnitNameAndUsesSections;
var
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := FixturePath('UnitModel', 'SymbolMapUnit.pas');
  lOptions.ProjectContextApplied := True;

  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsTrue(lModel.Success);
  Assert.AreEqual('SymbolMapUnit', lModel.UnitName);
  Assert.AreEqual(lOptions.SourceFileName, lModel.FileName);
  Assert.AreEqual('utf-8', lModel.EncodingName);
  Assert.AreEqual(2, Length(lModel.InterfaceUses));
  Assert.AreEqual('System.SysUtils', lModel.InterfaceUses[0]);
  Assert.AreEqual('Winapi.Windows', lModel.InterfaceUses[1]);
  Assert.AreEqual(2, Length(lModel.ImplementationUses));
  Assert.AreEqual('System.Classes', lModel.ImplementationUses[0]);
  Assert.AreEqual('System.Generics.Collections', lModel.ImplementationUses[1]);
end;

procedure TUnitModelTests.MigratedSymbolMapExtractsNamespacedUnitName;
var
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lPath: string;
begin
  lPath := TPath.Combine(ExtractFilePath(ParamStr(0)), 'symbol-map-namespaced-unit.pas');
  TFile.WriteAllText(lPath, 'unit Foo.Bar;' + sLineBreak + 'interface' + sLineBreak +
    'uses System.SysUtils;' + sLineBreak + 'implementation' + sLineBreak + 'end.',
    TEncoding.UTF8);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lPath;
  lOptions.ProjectContextApplied := True;

  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsTrue(lModel.Success);
  Assert.AreEqual('Foo.Bar', lModel.UnitName);
  Assert.AreEqual('System.SysUtils', lModel.InterfaceUses[0]);
end;

procedure TUnitModelTests.MigratedSymbolMapExtractsTopLevelDeclarationsAndEnumValues;
var
  lDeclaration: TDelphiSemanticDeclaration;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lRoutine: TDelphiSemanticRoutine;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := FixturePath('UnitModel', 'SymbolMapDeclarations.pas');
  lOptions.ProjectContextApplied := True;

  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsTrue(lModel.Success);
  Assert.AreEqual('SymbolMapDeclarations', lModel.UnitName);
  Assert.IsTrue(FindDeclaration(lModel, 'TDeclarationEnum', 'type', 'interface', lDeclaration));
  Assert.AreEqual('enum', lDeclaration.TypeName);
  Assert.IsTrue(FindDeclaration(lModel, 'deOne', 'enum-value', 'interface', lDeclaration));
  Assert.AreEqual('TDeclarationEnum', lDeclaration.TypeName);
  Assert.IsTrue(FindDeclaration(lModel, 'deTwo', 'enum-value', 'interface', lDeclaration));
  Assert.AreEqual('TDeclarationEnum', lDeclaration.TypeName);
  Assert.IsTrue(FindDeclaration(lModel, 'TDeclarationAlias', 'type-alias', 'interface',
    lDeclaration));
  Assert.AreEqual('string', lDeclaration.TypeName);
  Assert.IsTrue(FindDeclaration(lModel, 'TDeclarationRecord', 'type', 'interface',
    lDeclaration));
  Assert.AreEqual('record', lDeclaration.TypeName);
  Assert.IsTrue(FindDeclaration(lModel, 'TDeclarationClass', 'type', 'interface',
    lDeclaration));
  Assert.AreEqual('class', lDeclaration.TypeName);
  Assert.IsTrue(FindDeclaration(lModel, 'cDeclarationConst', 'const', 'interface',
    lDeclaration));
  Assert.IsTrue(FindDeclaration(lModel, 'cDeclarationTyped', 'typed-const', 'interface',
    lDeclaration));
  Assert.AreEqual('Integer', lDeclaration.TypeName);
  Assert.IsTrue(FindDeclaration(lModel, 'GDeclarationGlobal', 'var', 'interface',
    lDeclaration));
  Assert.AreEqual('Integer', lDeclaration.TypeName);
  Assert.IsTrue(FindDeclaration(lModel, 'DeclarationProcedure', 'routine', 'interface',
    lDeclaration));
  Assert.IsTrue(FindRoutine(lModel, 'DeclarationProcedure', 'interface', lRoutine));
  Assert.IsTrue(Pos('const aName: string', lRoutine.Signature) > 0);
  Assert.IsTrue(FindDeclaration(lModel, 'DeclarationFunction', 'routine', 'interface',
    lDeclaration));
  Assert.AreEqual('Integer', lDeclaration.TypeName);
  Assert.IsTrue(FindDeclaration(lModel, 'DeclarationMultiParam', 'routine', 'interface',
    lDeclaration));
  Assert.AreEqual('Boolean', lDeclaration.TypeName);
  Assert.IsTrue(FindRoutine(lModel, 'DeclarationMultiParam', 'interface', lRoutine));
  Assert.IsTrue(Pos('const aName: string; const aValue: Integer', lRoutine.Signature) > 0);
  Assert.IsTrue(FindDeclaration(lModel, 'ImplementationOnlyProcedure', 'routine',
    'implementation', lDeclaration));
  Assert.IsTrue(FindDeclaration(lModel, 'cImplementationConst', 'const', 'implementation',
    lDeclaration));
  Assert.IsTrue(FindDeclaration(lModel, 'GImplementationGlobal', 'var', 'implementation',
    lDeclaration));
  Assert.IsFalse(HasDeclaration(lModel, 'cLocalConst', 'const', 'implementation'));
  Assert.IsFalse(HasDeclaration(lModel, 'TLocalType', 'type-alias', 'implementation'));
  Assert.IsFalse(HasDeclaration(lModel, 'lLocalValue', 'var', 'implementation'));
end;

procedure TUnitModelTests.MigratedSymbolMapExtractsMembersPropertiesAndMetadata;
var
  lMember: TDelphiSemanticMember;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := FixturePath('UnitModel', 'SymbolMapMembers.pas');
  lOptions.ProjectContextApplied := True;

  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsTrue(lModel.Success);
  Assert.AreEqual('SymbolMapMembers', lModel.UnitName);
  Assert.AreEqual(22, Length(lModel.Members));
  Assert.IsTrue(FindMember(lModel, 'TMemberRecord', 'RecordField', 'field', lMember));
  Assert.AreEqual('Integer', lMember.TypeName);
  Assert.AreEqual(7, lMember.Line);
  Assert.AreEqual(5, lMember.Column);
  Assert.IsTrue(FindMember(lModel, 'TMemberRecord', 'Reset', 'method', lMember));
  Assert.AreEqual(8, lMember.Line);
  Assert.AreEqual(15, lMember.Column);
  Assert.IsTrue(FindMember(lModel, 'TMemberRecord', 'DisplayName', 'property', lMember));
  Assert.AreEqual(9, lMember.Line);
  Assert.AreEqual(14, lMember.Column);
  Assert.IsTrue(FindMember(lModel, 'TMemberClass', 'FName', 'field', lMember));
  Assert.AreEqual('private', lMember.Visibility);
  Assert.IsTrue(FindMember(lModel, 'TMemberClass', 'FItems', 'field', lMember));
  Assert.IsTrue(FindMember(lModel, 'TMemberClass', 'FEnabled', 'field', lMember));
  Assert.IsTrue(FindMember(lModel, 'TMemberClass', 'GetItem', 'method', lMember));
  Assert.IsTrue(FindMember(lModel, 'TMemberClass', 'GetNamedItem', 'method', lMember));
  Assert.IsTrue(FindMember(lModel, 'TMemberClass', 'ClassField', 'field', lMember));
  Assert.AreEqual('public', lMember.Visibility);
  Assert.IsTrue(FindMember(lModel, 'TMemberClass', 'Run', 'method', lMember));
  Assert.IsTrue(Pos('const aName: string', lMember.Signature) > 0);
  Assert.AreEqual(21, lMember.Line);
  Assert.AreEqual(15, lMember.Column);
  Assert.IsTrue(FindMember(lModel, 'TMemberClass', 'Count', 'method', lMember));
  Assert.IsTrue(FindMember(lModel, 'TMemberClass', 'Name', 'property', lMember));
  Assert.AreEqual('string', lMember.TypeName);
  Assert.IsFalse(lMember.IsIndexed);
  Assert.IsTrue(FindMember(lModel, 'TMemberClass', 'Enabled', 'property', lMember));
  Assert.IsFalse(lMember.IsDefault);
  Assert.IsTrue(FindMember(lModel, 'TMemberClass', 'Items', 'property', lMember));
  Assert.IsTrue(lMember.IsIndexed);
  Assert.IsTrue(lMember.IsDefault);
  Assert.IsTrue(FindMember(lModel, 'TMemberClass', 'MultiItems', 'property', lMember));
  Assert.AreEqual('string', lMember.TypeName);
  Assert.IsTrue(lMember.IsIndexed);
  Assert.IsFalse(lMember.IsDefault);
  Assert.IsTrue(FindMember(lModel, 'TDefaultVisibilityClass', 'DefaultField', 'field',
    lMember));
  Assert.AreEqual('public', lMember.Visibility);
  Assert.IsTrue(FindMember(lModel, 'TDefaultVisibilityClass', 'DefaultProperty', 'property',
    lMember));
  Assert.IsTrue(FindMember(lModel, 'IMemberInterface', 'Touch', 'method', lMember));
  Assert.AreEqual('public', lMember.Visibility);
  Assert.AreEqual(35, lMember.Line);
  Assert.AreEqual(15, lMember.Column);
  Assert.IsTrue(FindMember(lModel, 'IMemberInterface', 'GetCaption', 'method', lMember));
  Assert.IsTrue(FindMember(lModel, 'IMemberInterface', 'Caption', 'property', lMember));
  Assert.IsTrue(FindMember(lModel, 'TMemberRecordHelper', 'Normalize', 'method', lMember));
  Assert.AreEqual(41, lMember.Line);
  Assert.AreEqual(15, lMember.Column);
  Assert.IsTrue(FindMember(lModel, 'TMemberRecordHelper', 'HelperValue', 'property',
    lMember));
  Assert.AreEqual(42, lMember.Line);
  Assert.AreEqual(14, lMember.Column);
end;

procedure TUnitModelTests.PreprocessingRemovesInactiveDeclarations;
var
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := FixturePath('UnitModel', 'ConditionalModelUnit.pas');
  lOptions.Defines := ['ACTIVE_MODEL'];
  lOptions.ProjectContextApplied := True;

  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsTrue(lModel.Success);
  Assert.IsTrue(HasDeclaration(lModel, 'TActiveModelType', 'type', 'interface'));
  Assert.IsFalse(HasDeclaration(lModel, 'TInactiveModelType', 'type', 'interface'));
end;

procedure TUnitModelTests.IncludeExpansionDoesNotShiftFollowingParentLineNumbers;
var
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lRoot: string;
begin
  lRoot := TPath.Combine(ExtractFilePath(ParamStr(0)), 'unit-model-include-lines');
  TDirectory.CreateDirectory(lRoot);
  TFile.WriteAllText(TPath.Combine(lRoot, 'Included.inc'), 'type TIncludedLineType = class end;',
    TEncoding.UTF8);
  TFile.WriteAllText(TPath.Combine(lRoot, 'IncludeLineUnit.pas'),
    'unit IncludeLineUnit;' + sLineBreak +
    'interface' + sLineBreak +
    '{$I Included.inc}' + sLineBreak +
    'type' + sLineBreak +
    '  TAfterIncludeType = class end;' + sLineBreak +
    'implementation' + sLineBreak +
    'end.', TEncoding.UTF8);

  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := TPath.Combine(lRoot, 'IncludeLineUnit.pas');
  lOptions.SearchPaths := [lRoot];
  lOptions.ProjectContextApplied := True;

  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsTrue(lModel.Success);
  Assert.AreEqual(5, LineOfDeclaration(lModel, 'TAfterIncludeType'));
end;

procedure TUnitModelTests.IncludeExpansionPreservesMultiLineIncludedDeclarations;
var
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lRoot: string;
begin
  lRoot := TPath.Combine(ExtractFilePath(ParamStr(0)), 'unit-model-include-multiline');
  TDirectory.CreateDirectory(lRoot);
  TFile.WriteAllText(TPath.Combine(lRoot, 'IncludedRecord.inc'),
    'type' + sLineBreak +
    '  TIncludedRecord = record' + sLineBreak +
    '    IncludedValue: Integer;' + sLineBreak +
    '  end;', TEncoding.UTF8);
  TFile.WriteAllText(TPath.Combine(lRoot, 'IncludeMultiLineUnit.pas'),
    'unit IncludeMultiLineUnit;' + sLineBreak +
    'interface' + sLineBreak +
    '{$I IncludedRecord.inc}' + sLineBreak +
    'implementation' + sLineBreak +
    'end.', TEncoding.UTF8);

  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := TPath.Combine(lRoot, 'IncludeMultiLineUnit.pas');
  lOptions.SearchPaths := [lRoot];
  lOptions.ProjectContextApplied := True;

  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsTrue(lModel.Success);
  Assert.IsTrue(HasDeclaration(lModel, 'TIncludedRecord', 'type', 'interface'));
  Assert.IsTrue(HasMemberOfOwner(lModel, 'TIncludedRecord', 'IncludedValue'));
end;

procedure TUnitModelTests.IncludeExpansionDoesNotShiftFollowingParentWithRanges;
var
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lRoot: string;
  lSource: string;
begin
  lRoot := TPath.Combine(ExtractFilePath(ParamStr(0)), 'unit-model-include-with-lines');
  TDirectory.CreateDirectory(lRoot);
  TFile.WriteAllText(TPath.Combine(lRoot, 'IncludedTypes.inc'),
    'type' + sLineBreak +
    '  TIncludedWithRecord = record' + sLineBreak +
    '    Value: Integer;' + sLineBreak +
    '  end;', TEncoding.UTF8);
  lSource :=
    'unit IncludeWithLineUnit;' + sLineBreak +
    'interface' + sLineBreak +
    '{$I IncludedTypes.inc}' + sLineBreak +
    'implementation' + sLineBreak +
    'procedure Run;' + sLineBreak +
    'var' + sLineBreak +
    '  lRecord: TIncludedWithRecord;' + sLineBreak +
    'begin' + sLineBreak +
    '  with lRecord do' + sLineBreak +
    '  begin' + sLineBreak +
    '    Value := 1;' + sLineBreak +
    '  end;' + sLineBreak +
    'end;' + sLineBreak +
    'end.';
  TFile.WriteAllText(TPath.Combine(lRoot, 'IncludeWithLineUnit.pas'), lSource, TEncoding.UTF8);

  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := TPath.Combine(lRoot, 'IncludeWithLineUnit.pas');
  lOptions.SearchPaths := [lRoot];
  lOptions.ProjectContextApplied := True;

  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsTrue(lModel.Success);
  Assert.AreEqual(1, Length(lModel.WithStatements));
  Assert.AreEqual(9, lModel.WithStatements[0].Line);
  Assert.IsTrue(Pos('Value := 1', StatementText(lSource, lModel.WithStatements[0].Line,
    lModel.WithStatements[0].Column, lModel.WithStatements[0].EndLine,
    lModel.WithStatements[0].EndColumn)) > 0);
end;

procedure TUnitModelTests.ModelUsesSourceLoaderFallbackWhenExtractingAnsiSource;
var
  lBytes: TBytes;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lPath: string;
begin
  lPath := TPath.Combine(ExtractFilePath(ParamStr(0)), 'unit-model-ansi-extract.pas');
  lBytes := [$75, $6E, $69, $74, $20, $41, $6E, $73, $69, $45, $78, $74, $72, $61, $63, $74,
    $55, $6E, $69, $74, $3B, $0D, $0A, $69, $6E, $74, $65, $72, $66, $61, $63, $65,
    $0D, $0A, $2F, $2F, $20, $E4, $0D, $0A, $69, $6D, $70, $6C, $65, $6D, $65, $6E,
    $74, $61, $74, $69, $6F, $6E, $0D, $0A, $65, $6E, $64, $2E];
  TFile.WriteAllBytes(lPath, lBytes);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lPath;
  lOptions.ProjectContextApplied := True;

  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsTrue(lModel.Success);
  Assert.AreEqual('AnsiExtractUnit', lModel.UnitName);
  Assert.AreEqual('windows-1252', lModel.EncodingName);
end;

procedure TUnitModelTests.WithStatementsExposeSourceRanges;
var
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := FixturePath('UnitModel', 'SemanticUnit.pas');
  lOptions.ProjectContextApplied := True;

  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsTrue(lModel.Success);
  Assert.AreEqual(1, Length(lModel.WithStatements));
  Assert.IsTrue(lModel.WithStatements[0].EndLine > lModel.WithStatements[0].Line);
  Assert.IsTrue(lModel.WithStatements[0].EndColumn > 0);
  Assert.AreEqual('lRecord', lModel.WithStatements[0].SelectorText);
  Assert.IsTrue(Pos('Value := Length', lModel.WithStatements[0].Text) > 0);
  Assert.IsTrue(Pos('SemanticGlobal :=', lModel.WithStatements[0].Text) = 0);
end;

procedure TUnitModelTests.WithDiscoveryIgnoresStringsAndCommentsAndKeepsRepeatedRanges;
var
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lPath: string;
  lSource: string;
begin
  lPath := TPath.Combine(ExtractFilePath(ParamStr(0)), 'unit-model-with-scanner.pas');
  lSource :=
    'unit WithScannerUnit;' + sLineBreak +
    'interface' + sLineBreak +
    'implementation' + sLineBreak +
    'procedure Run;' + sLineBreak +
    'var' + sLineBreak +
    '  lRecord: TSemanticRecord;' + sLineBreak +
    'begin' + sLineBreak +
    '  // with lRecord do' + sLineBreak +
    '  Text := ''with lRecord do'';' + sLineBreak +
    '  with lRecord do Value := 1;' + sLineBreak +
    '  with lRecord do Value := 2;' + sLineBreak +
    'end;' + sLineBreak +
    'end.';
  TFile.WriteAllText(lPath, lSource, TEncoding.UTF8);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lPath;
  lOptions.ProjectContextApplied := True;

  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsTrue(lModel.Success);
  Assert.AreEqual(2, Length(lModel.WithStatements));
  Assert.AreEqual(10, lModel.WithStatements[0].Line);
  Assert.AreEqual(11, lModel.WithStatements[1].Line);
end;

procedure TUnitModelTests.ReferencesIgnoreStringsAndComments;
var
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lPath: string;
begin
  lPath := TPath.Combine(ExtractFilePath(ParamStr(0)), 'unit-model-reference-scanner.pas');
  TFile.WriteAllText(lPath,
    'unit ReferenceScannerUnit;' + sLineBreak +
    'interface' + sLineBreak +
    'implementation' + sLineBreak +
    'procedure Run;' + sLineBreak +
    'begin' + sLineBreak +
    '  // PhantomReference' + sLineBreak +
    '  Text := ''StringReference'';' + sLineBreak +
    '  RealReference := 1;' + sLineBreak +
    'end;' + sLineBreak +
    'end.', TEncoding.UTF8);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lPath;
  lOptions.ProjectContextApplied := True;

  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsTrue(lModel.Success);
  Assert.IsFalse(HasReference(lModel, 'PhantomReference'));
  Assert.IsFalse(HasReference(lModel, 'StringReference'));
  Assert.IsTrue(HasReference(lModel, 'RealReference'));
end;

procedure TUnitModelTests.IncludeExpansionDoesNotShiftFollowingParentReferences;
var
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lRoot: string;
begin
  lRoot := TPath.Combine(ExtractFilePath(ParamStr(0)), 'unit-model-include-reference-lines');
  TDirectory.CreateDirectory(lRoot);
  TFile.WriteAllText(TPath.Combine(lRoot, 'IncludedRefTypes.inc'),
    'type' + sLineBreak +
    '  TReferenceInclude = record' + sLineBreak +
    '    Value: Integer;' + sLineBreak +
    '  end;', TEncoding.UTF8);
  TFile.WriteAllText(TPath.Combine(lRoot, 'IncludeReferenceLineUnit.pas'),
    'unit IncludeReferenceLineUnit;' + sLineBreak +
    'interface' + sLineBreak +
    '{$I IncludedRefTypes.inc}' + sLineBreak +
    'implementation' + sLineBreak +
    'procedure Run;' + sLineBreak +
    'begin' + sLineBreak +
    '  ParentReference := 1;' + sLineBreak +
    'end;' + sLineBreak +
    'end.', TEncoding.UTF8);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := TPath.Combine(lRoot, 'IncludeReferenceLineUnit.pas');
  lOptions.SearchPaths := [lRoot];
  lOptions.ProjectContextApplied := True;

  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsTrue(lModel.Success);
  Assert.IsTrue(HasReferenceOnLine(lModel, 'ParentReference', 7));
end;

procedure TUnitModelTests.IncludeExpansionDoesNotShiftFollowingParentMembersRoutinesAndLocals;
var
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lRoot: string;
begin
  lRoot := TPath.Combine(ExtractFilePath(ParamStr(0)), 'unit-model-include-position-lines');
  TDirectory.CreateDirectory(lRoot);
  TFile.WriteAllText(TPath.Combine(lRoot, 'IncludedManyLines.inc'),
    'type' + sLineBreak +
    '  TIncludedPosition = record' + sLineBreak +
    '    Value: Integer;' + sLineBreak +
    '  end;', TEncoding.UTF8);
  TFile.WriteAllText(TPath.Combine(lRoot, 'IncludePositionLineUnit.pas'),
    'unit IncludePositionLineUnit;' + sLineBreak +
    'interface' + sLineBreak +
    '{$I IncludedManyLines.inc}' + sLineBreak +
    'type' + sLineBreak +
    '  TParentRecord = record' + sLineBreak +
    '    ParentField: Integer;' + sLineBreak +
    '  end;' + sLineBreak +
    'implementation' + sLineBreak +
    'procedure ParentRoutine;' + sLineBreak +
    'var' + sLineBreak +
    '  lParentLocal: TParentRecord;' + sLineBreak +
    'begin' + sLineBreak +
    '  lParentLocal.ParentField := 1;' + sLineBreak +
    'end;' + sLineBreak +
    'end.', TEncoding.UTF8);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := TPath.Combine(lRoot, 'IncludePositionLineUnit.pas');
  lOptions.SearchPaths := [lRoot];
  lOptions.ProjectContextApplied := True;

  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsTrue(lModel.Success);
  Assert.IsTrue(HasMemberOnLine(lModel, 'TParentRecord', 'ParentField', 6), 'member line');
  Assert.IsTrue(HasRoutineOnLine(lModel, 'ParentRoutine', 9), 'routine line');
  Assert.IsTrue(HasLocalOnLine(lModel, 'ParentRoutine', 'lParentLocal', 11), 'local line');
end;

procedure TUnitModelTests.WithStatementRangeCoversIfThenElseBodies;
var
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lPath: string;
  lSource: string;
begin
  lPath := TPath.Combine(ExtractFilePath(ParamStr(0)), 'unit-model-with-if-else.pas');
  lSource :=
    'unit WithIfElseUnit;' + sLineBreak +
    'interface' + sLineBreak +
    'implementation' + sLineBreak +
    'procedure Run;' + sLineBreak +
    'var' + sLineBreak +
    '  lRecord: TSemanticRecord;' + sLineBreak +
    'begin' + sLineBreak +
    '  with lRecord do' + sLineBreak +
    '    if Value > 0 then' + sLineBreak +
    '    begin' + sLineBreak +
    '      Text := ''positive'';' + sLineBreak +
    '    end else begin' + sLineBreak +
    '      Text := ''zero'';' + sLineBreak +
    '    end;' + sLineBreak +
    '  AfterWith := True;' + sLineBreak +
    'end;' + sLineBreak +
    'end.';
  TFile.WriteAllText(lPath, lSource, TEncoding.UTF8);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lPath;
  lOptions.ProjectContextApplied := True;

  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsTrue(lModel.Success);
  Assert.AreEqual(1, Length(lModel.WithStatements));
  Assert.IsTrue(Pos('Text := ''zero''', lModel.WithStatements[0].Text) > 0);
  Assert.IsTrue(Pos('AfterWith := True', lModel.WithStatements[0].Text) = 0);
end;

procedure TUnitModelTests.ModelKeepsOriginalSourceLineNumbersAfterPreprocessing;
var
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := FixturePath('UnitModel', 'ConditionalModelUnit.pas');
  lOptions.Defines := ['ACTIVE_MODEL'];
  lOptions.ProjectContextApplied := True;

  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsTrue(lModel.Success);
  Assert.AreEqual(7, LineOfDeclaration(lModel, 'TActiveModelType'));
  Assert.AreEqual(LineContaining(TFile.ReadAllText(lOptions.SourceFileName, TEncoding.UTF8),
    'TDuplicateModelType = record'), LineOfDeclaration(lModel, 'TDuplicateModelType'));
end;

procedure TUnitModelTests.ModelPropagatesSourceAndPreprocessDiagnostics;
var
  lMissingModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lPreprocessModel: TDelphiSemanticUnitModel;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := FixturePath('UnitModel', 'MissingUnit.pas');
  lOptions.ProjectContextApplied := True;

  lMissingModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsFalse(lMissingModel.Success);
  Assert.IsTrue(HasDiagnostic(lMissingModel, 'SOURCE_FILE_NOT_FOUND'));

  lOptions.SourceFileName := FixturePath('UnitModel', 'UnsupportedPreprocessUnit.pas');
  lPreprocessModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsFalse(lPreprocessModel.Success);
  Assert.IsTrue(HasDiagnostic(lPreprocessModel, 'UNSUPPORTED_PREPROCESS_DIRECTIVE'));
end;

procedure TUnitModelTests.StandaloneExtractionReportsDegradedMode;
var
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := FixturePath('UnitModel', 'SemanticUnit.pas');

  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsTrue(lModel.Success);
  Assert.IsTrue(HasDiagnostic(lModel, 'NO_PROJECT_CONTEXT'));
end;

initialization
  TDUnitX.RegisterTestFixture(TUnitModelTests);

end.
