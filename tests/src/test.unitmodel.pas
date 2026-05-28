unit Test.UnitModel;

interface

uses
  DUnitX.TestFramework,
  DelphiSemantics.Model, DelphiSemantics.Source, DelphiSemantics.WithBinding;

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
    function FindLocal(const aModel: TDelphiSemanticUnitModel; const aRoutineName, aName:
      string; out aLocal: TDelphiSemanticLocal): Boolean;
    function HasMember(const aModel: TDelphiSemanticUnitModel; const aOwnerName, aName, aKind,
      aTypeName: string): Boolean;
    function FindDeclaration(const aModel: TDelphiSemanticUnitModel; const aName, aKind,
      aSection: string; out aDeclaration: TDelphiSemanticDeclaration): Boolean;
    function FindMember(const aModel: TDelphiSemanticUnitModel; const aOwnerName, aName, aKind:
      string; out aMember: TDelphiSemanticMember): Boolean;
    function ColumnOfSourceOffset(const aSource: string; const aOffset: Integer): Integer;
    function FindReferenceAtOffset(const aModel: TDelphiSemanticUnitModel; const aName: string;
      const aOffset: Integer; out aReference: TDelphiSemanticReference): Boolean;
    function HasReference(const aModel: TDelphiSemanticUnitModel; const aName: string): Boolean;
    function HasReferenceOnLine(const aModel: TDelphiSemanticUnitModel; const aName: string;
      const aLine: Integer): Boolean;
    function HasReferenceAtOffset(const aModel: TDelphiSemanticUnitModel; const aName: string;
      const aOffset: Integer): Boolean;
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
    procedure ExtractsUntypedRoutineParameters;
    [Test]
    procedure ExtractsRoutineAfterSingleLineGuidInterface;
    [Test]
    procedure ExtractsAnonymousNestedRecordMembers;
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
    procedure SourceSectionsExposeInitializationAndFinalizationBoundaries;
    [Test]
    procedure SourceSectionsHandleUnitsWithoutImplementation;
    [Test]
    procedure SourceSectionsIgnoreCommentsAndStringsWhenFindingImplementation;
    [Test]
    procedure ModelCarriesOriginalSourceRangesForDeclarationsRoutinesMembersAndLocals;
    [Test]
    procedure ReferencesCarryOriginalSourceRanges;
    [Test]
    procedure ReferencesCarryOriginalSourceRangesWithoutFallbackForPlainSource;
    [Test]
    procedure ModelPropagatesSourceAndPreprocessDiagnostics;
    [Test]
    procedure StandaloneExtractionReportsDegradedMode;
    [Test]
    procedure TypeBlockAnalysisIsBuiltOncePerExtraction;
    [Test]
    procedure ReferenceReconciliationScansRepeatedNamesOnce;
    [Test]
    procedure ReferenceReconciliationBuildsOccurrenceTableOnce;
    [Test]
    procedure RoutineReconciliationUsesOffsetMapBeforeFallback;
  end;

implementation

uses
  System.IOUtils, System.StrUtils, System.SysUtils,
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

function TUnitModelTests.FindLocal(const aModel: TDelphiSemanticUnitModel;
  const aRoutineName, aName: string; out aLocal: TDelphiSemanticLocal): Boolean;
var
  lLocal: TDelphiSemanticLocal;
begin
  for lLocal in aModel.Locals do
    if SameText(lLocal.RoutineName, aRoutineName) and SameText(lLocal.Name, aName) then
    begin
      aLocal := lLocal;
      Exit(True);
    end;

  aLocal := Default(TDelphiSemanticLocal);
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

function TUnitModelTests.ColumnOfSourceOffset(const aSource: string;
  const aOffset: Integer): Integer;
var
  i: Integer;
begin
  Result := 1;
  for i := 1 to aOffset - 1 do
    if aSource[i] = #10 then
      Result := 1
    else if aSource[i] <> #13 then
      Inc(Result);
end;

function TUnitModelTests.FindReferenceAtOffset(const aModel: TDelphiSemanticUnitModel;
  const aName: string; const aOffset: Integer; out aReference: TDelphiSemanticReference):
  Boolean;
var
  lReference: TDelphiSemanticReference;
begin
  for lReference in aModel.References do
    if SameText(lReference.Name, aName) and (lReference.Offset = aOffset) then
    begin
      aReference := lReference;
      Exit(True);
    end;

  aReference := Default(TDelphiSemanticReference);
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

function TUnitModelTests.HasReferenceAtOffset(const aModel: TDelphiSemanticUnitModel;
  const aName: string; const aOffset: Integer): Boolean;
var
  lReference: TDelphiSemanticReference;
begin
  for lReference in aModel.References do
    if SameText(lReference.Name, aName) and (lReference.Offset = aOffset) and
      (lReference.EndOffset = aOffset + Length(aName)) then
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

procedure TUnitModelTests.ExtractsUntypedRoutineParameters;
var
  lInventory: TDelphiSemanticRemoveWithInventory;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lRoutine: TDelphiSemanticRoutine;
  lSymbol: TDelphiSemanticInventorySymbol;
  lSymbolFound: Boolean;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := FixturePath('UnitModel', 'UntypedParameterUnit.pas');
  lOptions.ProjectContextApplied := True;

  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsTrue(lModel.Success);
  Assert.IsTrue(FindRoutine(lModel, 'Run', 'implementation', lRoutine),
    'Expected implementation routine.');
  Assert.AreEqual('TUntypedParameterScope', lRoutine.OwnerName);
  Assert.AreEqual(2, Length(lRoutine.Parameters));
  Assert.AreEqual('aValue', lRoutine.Parameters[0].Name);
  Assert.AreEqual('', lRoutine.Parameters[0].TypeName);
  Assert.AreEqual('const', lRoutine.Parameters[0].Modifier);
  Assert.AreEqual('aOther', lRoutine.Parameters[1].Name);
  Assert.AreEqual('', lRoutine.Parameters[1].TypeName);
  Assert.AreEqual('var', lRoutine.Parameters[1].Modifier);

  Assert.IsTrue(FindRoutine(lModel, 'RunMixed', 'implementation', lRoutine),
    'Expected mixed untyped-parameter routine.');
  Assert.AreEqual(3, Length(lRoutine.Parameters));
  Assert.AreEqual('aFirst', lRoutine.Parameters[0].Name);
  Assert.AreEqual('Integer', lRoutine.Parameters[0].TypeName);
  Assert.AreEqual('aUntyped', lRoutine.Parameters[1].Name);
  Assert.AreEqual('', lRoutine.Parameters[1].TypeName);
  Assert.AreEqual('var', lRoutine.Parameters[1].Modifier);
  Assert.AreEqual('aLast', lRoutine.Parameters[2].Name);
  Assert.AreEqual('Integer', lRoutine.Parameters[2].TypeName);

  lSymbolFound := False;
  lInventory := TDelphiSemanticWithBinder.BuildInventory(lModel);
  for lSymbol in lInventory.Symbols do
    if SameText(lSymbol.SymbolClass, 'parameter') and SameText(lSymbol.Name, 'aValue') then
    begin
      Assert.AreEqual('TUntypedParameterScope.Run', lSymbol.RoutineName);
      lSymbolFound := True;
    end;
  Assert.IsTrue(lSymbolFound, 'Expected inventory parameter symbol.');

  lSymbolFound := False;
  for lSymbol in lInventory.Symbols do
    if SameText(lSymbol.SymbolClass, 'parameter') and
      SameText(lSymbol.Name, 'aInventoryUntyped') then
    begin
      Assert.AreEqual('RunInventory', lSymbol.RoutineName);
      Assert.AreEqual('', lSymbol.TypeName);
      lSymbolFound := True;
    end;
  Assert.IsTrue(lSymbolFound, 'Expected multiline untyped inventory parameter symbol.');
end;

procedure TUnitModelTests.ExtractsRoutineAfterSingleLineGuidInterface;
var
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := FixturePath('UnitModel', 'GuidInterfaceRoutineUnit.pas');
  lOptions.ProjectContextApplied := True;

  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsTrue(HasDeclaration(lModel, 'IGuidInline', 'type', 'interface'));
  Assert.IsTrue(HasRoutine(lModel, 'RoutineAfterGuidInterface', 'interface'));
end;

procedure TUnitModelTests.ExtractsAnonymousNestedRecordMembers;
var
  lMember: TDelphiSemanticMember;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := FixturePath('UnitModel', 'NestedAnonymousRecordUnit.pas');
  lOptions.ProjectContextApplied := True;

  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsTrue(lModel.Success);
  Assert.IsTrue(FindMember(lModel, 'DBF_File', 'Struktur', 'field', lMember));
  Assert.AreEqual('DBF_File.Struktur', lMember.TypeName);
  Assert.IsTrue(HasMember(lModel, 'DBF_File.Struktur', 'Version', 'field', 'Byte'));
  Assert.IsTrue(HasMember(lModel, 'DBF_File.Struktur', 'RecSize', 'field', 'Integer'));
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

procedure TUnitModelTests.SourceSectionsExposeInitializationAndFinalizationBoundaries;
var
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lPath: string;
  lSource: string;
begin
  lPath := TPath.Combine(ExtractFilePath(ParamStr(0)), 'unit-model-source-sections.pas');
  lSource :=
    'unit SourceSectionsUnit;' + sLineBreak +
    'interface' + sLineBreak +
    'implementation' + sLineBreak +
    'initialization' + sLineBreak +
    'finalization' + sLineBreak +
    'end.';
  TFile.WriteAllText(lPath, lSource, TEncoding.UTF8);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lPath;
  lOptions.ProjectContextApplied := True;

  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsTrue(lModel.Success);
  Assert.AreEqual(Pos('interface', lSource), lModel.SourceSections.InterfaceOffset);
  Assert.AreEqual(Pos('implementation', lSource), lModel.SourceSections.ImplementationOffset);
  Assert.AreEqual(Pos('initialization', lSource), lModel.SourceSections.InitializationOffset);
  Assert.AreEqual(Pos('finalization', lSource), lModel.SourceSections.FinalizationOffset);
end;

procedure TUnitModelTests.SourceSectionsHandleUnitsWithoutImplementation;
var
  lDeclaration: TDelphiSemanticDeclaration;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lPath: string;
  lSource: string;
begin
  lPath := TPath.Combine(ExtractFilePath(ParamStr(0)), 'unit-model-no-implementation.pas');
  lSource :=
    'unit NoImplementationUnit;' + sLineBreak +
    'interface' + sLineBreak +
    'type' + sLineBreak +
    '  TNoImplementationType = Integer;' + sLineBreak +
    'end.';
  TFile.WriteAllText(lPath, lSource, TEncoding.UTF8);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lPath;
  lOptions.ProjectContextApplied := True;

  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsTrue(lModel.Success);
  Assert.AreEqual(Pos('interface', lSource), lModel.SourceSections.InterfaceOffset);
  Assert.AreEqual(0, lModel.SourceSections.ImplementationOffset);
  Assert.AreEqual(0, lModel.SourceSections.InitializationOffset);
  Assert.AreEqual(0, lModel.SourceSections.FinalizationOffset);
  Assert.IsTrue(FindDeclaration(lModel, 'TNoImplementationType', 'type-alias', 'interface',
    lDeclaration));
end;

procedure TUnitModelTests.SourceSectionsIgnoreCommentsAndStringsWhenFindingImplementation;
var
  lInterfaceDeclaration: TDelphiSemanticDeclaration;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lPath: string;
  lSource: string;
begin
  lPath := TPath.Combine(ExtractFilePath(ParamStr(0)), 'unit-model-section-keywords.pas');
  lSource :=
    'unit SectionKeywordsUnit;' + sLineBreak +
    'interface' + sLineBreak +
    '// implementation in a comment' + sLineBreak +
    'const cText = ''implementation in a string'';' + sLineBreak +
    'type' + sLineBreak +
    '  TBeforeImplementation = Integer;' + sLineBreak +
    'implementation' + sLineBreak +
    'type' + sLineBreak +
    '  TAfterImplementation = Integer;' + sLineBreak +
    'end.';
  TFile.WriteAllText(lPath, lSource, TEncoding.UTF8);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lPath;
  lOptions.ProjectContextApplied := True;

  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsTrue(lModel.Success);
  Assert.AreEqual(PosEx('implementation' + sLineBreak + 'type', lSource),
    lModel.SourceSections.ImplementationOffset);
  Assert.IsTrue(FindDeclaration(lModel, 'TBeforeImplementation', 'type-alias', 'interface',
    lInterfaceDeclaration));
  Assert.IsTrue(FindDeclaration(lModel, 'TAfterImplementation', 'type-alias', 'implementation',
    lInterfaceDeclaration));
end;

procedure TUnitModelTests.ModelCarriesOriginalSourceRangesForDeclarationsRoutinesMembersAndLocals;
var
  lDeclaration: TDelphiSemanticDeclaration;
  lFirstSameNameOffset: Integer;
  lLocal: TDelphiSemanticLocal;
  lMember: TDelphiSemanticMember;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lPath: string;
  lRoutine: TDelphiSemanticRoutine;
  lRoutineCount: Integer;
  lRoutineItem: TDelphiSemanticRoutine;
  lSecondSameNameOffset: Integer;
  lSource: string;
begin
  lPath := TPath.Combine(ExtractFilePath(ParamStr(0)), 'unit-model-original-ranges.pas');
  lSource :=
    'unit OriginalRangeUnit;' + sLineBreak +
    'interface' + sLineBreak +
    'type' + sLineBreak +
    '  TRangeFirst = class' + sLineBreak +
    '  private' + sLineBreak +
    '    FValue: Integer;' + sLineBreak +
    '  public' + sLineBreak +
    '    procedure SameName;' + sLineBreak +
    '    function Overloaded(const aValue: Integer): Integer; overload;' + sLineBreak +
    '    function Overloaded(const aText: string): string; overload;' + sLineBreak +
    '  end;' + sLineBreak +
    '  TRangeSecond = class' + sLineBreak +
    '  public' + sLineBreak +
    '    procedure SameName;' + sLineBreak +
    '  end;' + sLineBreak +
    'procedure TopLevel(const aText: string);' + sLineBreak +
    'implementation' + sLineBreak +
    'procedure TRangeFirst.SameName;' + sLineBreak +
    'var' + sLineBreak +
    '  lFirstLocal: Integer;' + sLineBreak +
    '  procedure NestedWorker;' + sLineBreak +
    '  var' + sLineBreak +
    '    lNestedLocal: Integer;' + sLineBreak +
    '  begin' + sLineBreak +
    '    lNestedLocal := lFirstLocal;' + sLineBreak +
    '  end;' + sLineBreak +
    'begin' + sLineBreak +
    '  NestedWorker;' + sLineBreak +
    'end;' + sLineBreak +
    'function TRangeFirst.Overloaded(const aValue: Integer): Integer;' + sLineBreak +
    'begin' + sLineBreak +
    '  Result := aValue;' + sLineBreak +
    'end;' + sLineBreak +
    'function TRangeFirst.Overloaded(const aText: string): string;' + sLineBreak +
    'begin' + sLineBreak +
    '  Result := aText;' + sLineBreak +
    'end;' + sLineBreak +
    'procedure TRangeSecond.SameName;' + sLineBreak +
    'begin' + sLineBreak +
    'end;' + sLineBreak +
    'end.';
  TFile.WriteAllText(lPath, lSource, TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lPath;
  lOptions.ProjectContextApplied := True;

  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsTrue(lModel.Success);
  Assert.IsTrue(FindDeclaration(lModel, 'TRangeFirst', 'type', 'interface', lDeclaration),
    'TRangeFirst declaration');
  Assert.AreEqual(Pos('TRangeFirst = class', lSource), lDeclaration.Offset);
  Assert.AreEqual(lDeclaration.Offset + Length(lDeclaration.Name), lDeclaration.EndOffset);
  Assert.AreEqual(lDeclaration.Name, Copy(lSource, lDeclaration.Offset,
    lDeclaration.EndOffset - lDeclaration.Offset));
  Assert.IsTrue(FindDeclaration(lModel, 'TopLevel', 'routine', 'interface', lDeclaration),
    'TopLevel declaration');
  Assert.AreEqual(Pos('TopLevel', lSource), lDeclaration.Offset);
  Assert.AreEqual(lDeclaration.Offset + Length(lDeclaration.Name), lDeclaration.EndOffset);
  Assert.AreEqual(lDeclaration.Name, Copy(lSource, lDeclaration.Offset,
    lDeclaration.EndOffset - lDeclaration.Offset));
  Assert.IsTrue(FindMember(lModel, 'TRangeFirst', 'FValue', 'field', lMember),
    'FValue member');
  Assert.AreEqual(Pos('FValue: Integer', lSource), lMember.Offset);
  Assert.AreEqual(lMember.Offset + Length(lMember.Name), lMember.EndOffset);
  Assert.AreEqual(lMember.Name, Copy(lSource, lMember.Offset,
    lMember.EndOffset - lMember.Offset));
  Assert.IsTrue(FindMember(lModel, 'TRangeFirst', 'SameName', 'method', lMember),
    'TRangeFirst.SameName member');
  Assert.AreEqual(Pos('SameName;', lSource), lMember.Offset);
  Assert.AreEqual(lMember.Offset + Length(lMember.Name), lMember.EndOffset);
  Assert.AreEqual(lMember.Name, Copy(lSource, lMember.Offset,
    lMember.EndOffset - lMember.Offset));
  Assert.IsTrue(FindRoutine(lModel, 'NestedWorker', 'implementation', lRoutine),
    'NestedWorker routine');
  Assert.AreEqual(Pos('NestedWorker;', lSource), lRoutine.Offset);
  Assert.AreEqual(lRoutine.Offset + Length(lRoutine.Name), lRoutine.EndOffset);
  Assert.AreEqual(lRoutine.Name, Copy(lSource, lRoutine.Offset,
    lRoutine.EndOffset - lRoutine.Offset));
  Assert.IsTrue(FindLocal(lModel, 'TRangeFirst.SameName', 'lFirstLocal', lLocal),
    'lFirstLocal local');
  Assert.AreEqual(Pos('lFirstLocal: Integer', lSource), lLocal.Offset);
  Assert.AreEqual(lLocal.Offset + Length(lLocal.Name), lLocal.EndOffset);
  Assert.AreEqual(lLocal.Name, Copy(lSource, lLocal.Offset,
    lLocal.EndOffset - lLocal.Offset));
  Assert.IsTrue(FindLocal(lModel, 'NestedWorker', 'lNestedLocal', lLocal), 'lNestedLocal local');
  Assert.AreEqual(Pos('lNestedLocal: Integer', lSource), lLocal.Offset);
  Assert.AreEqual(lLocal.Offset + Length(lLocal.Name), lLocal.EndOffset);
  Assert.AreEqual(lLocal.Name, Copy(lSource, lLocal.Offset,
    lLocal.EndOffset - lLocal.Offset));

  lRoutineCount := 0;
  lFirstSameNameOffset := Pos('procedure TRangeFirst.SameName;', lSource) +
    Length('procedure TRangeFirst.');
  lSecondSameNameOffset := Pos('procedure TRangeSecond.SameName;', lSource) +
    Length('procedure TRangeSecond.');
  for lRoutineItem in lModel.Routines do
    if SameText(lRoutineItem.Name, 'SameName') and SameText(lRoutineItem.SectionKind,
      'implementation') then
    begin
      Inc(lRoutineCount);
      if SameText(lRoutineItem.OwnerName, 'TRangeFirst') then
        Assert.AreEqual(lFirstSameNameOffset, lRoutineItem.Offset)
      else if SameText(lRoutineItem.OwnerName, 'TRangeSecond') then
        Assert.AreEqual(lSecondSameNameOffset, lRoutineItem.Offset)
      else
        Assert.Fail('Unexpected SameName owner: ' + lRoutineItem.OwnerName);
      Assert.AreEqual(lRoutineItem.Offset + Length(lRoutineItem.Name), lRoutineItem.EndOffset);
      Assert.AreEqual(lRoutineItem.Name, Copy(lSource, lRoutineItem.Offset,
        lRoutineItem.EndOffset - lRoutineItem.Offset));
    end;
  Assert.AreEqual(2, lRoutineCount);
  lRoutineCount := 0;
  for lRoutineItem in lModel.Routines do
    if SameText(lRoutineItem.Name, 'Overloaded') and SameText(lRoutineItem.OwnerName,
      'TRangeFirst') and SameText(lRoutineItem.SectionKind, 'implementation') then
    begin
      Inc(lRoutineCount);
      Assert.AreEqual(lRoutineItem.Offset + Length(lRoutineItem.Name), lRoutineItem.EndOffset);
      Assert.AreEqual(lRoutineItem.Name, Copy(lSource, lRoutineItem.Offset,
        lRoutineItem.EndOffset - lRoutineItem.Offset));
    end;
  Assert.AreEqual(2, lRoutineCount);
end;

procedure TUnitModelTests.ReferencesCarryOriginalSourceRanges;
var
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lPath: string;
  lReference: TDelphiSemanticReference;
  lReferenceOffset: Integer;
  lRoot: string;
  lSource: string;
begin
  lRoot := TPath.Combine(ExtractFilePath(ParamStr(0)), 'unit-model-reference-ranges');
  TDirectory.CreateDirectory(lRoot);
  TFile.WriteAllText(TPath.Combine(lRoot, 'ReferenceRanges.inc'),
    '// include before body references' + sLineBreak, TEncoding.ASCII);
  lPath := TPath.Combine(lRoot, 'ReferenceRangeUnit.pas');
  lSource :=
    'unit ReferenceRangeUnit;' + sLineBreak +
    'interface' + sLineBreak +
    '{$DEFINE ACTIVE_RANGE}' + sLineBreak +
    'type' + sLineBreak +
    '  TTarget = record' + sLineBreak +
    '    Field: Integer;' + sLineBreak +
    '  end;' + sLineBreak +
    '  TAlias = TTarget;' + sLineBreak +
    '  PTarget = ^TTarget;' + sLineBreak +
    '  TArray = array of TAlias;' + sLineBreak +
    '  TContainer = record' + sLineBreak +
    '    Item: TArray;' + sLineBreak +
    '  end;' + sLineBreak +
    '  TInline = {$IFDEF ACTIVE_RANGE}TAlias{$ENDIF};' + sLineBreak +
    '{$IFDEF ACTIVE_RANGE}' + sLineBreak +
    '  TConditional = TAlias;' + sLineBreak +
    '{$ENDIF}' + sLineBreak +
    '{$IFNDEF ACTIVE_RANGE}' + sLineBreak +
    '  TInactive = TAlias;' + sLineBreak +
    '{$ENDIF}' + sLineBreak +
    'var' + sLineBreak +
    '  GTarget: TTarget;' + sLineBreak +
    'procedure UseRefs(const aParam: TAlias);' + sLineBreak +
    'implementation' + sLineBreak +
    '{$I ReferenceRanges.inc}' + sLineBreak +
    'procedure UseRefs(const aParam: TAlias);' + sLineBreak +
    'var' + sLineBreak +
    '  lLocal: TContainer;' + sLineBreak +
    'begin' + sLineBreak +
    '  GTarget.Field := lLocal.Item[0].Field;' + sLineBreak +
    '  aParam.Field := GTarget.Field;' + sLineBreak +
    '  // TAlias in a comment must not produce a range' + sLineBreak +
    '  Writeln(''TTarget in a string'');' + sLineBreak +
    'end;' + sLineBreak +
    'end.';
  TFile.WriteAllText(lPath, lSource, TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lPath;
  lOptions.SearchPaths := [lRoot];
  lOptions.ProjectContextApplied := True;

  TDelphiSemanticUnitModelExtractor.ResetReferenceReconciliationFallbackCount;
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsTrue(lModel.Success);
  lReferenceOffset := Pos('TAlias = TTarget', lSource) + Length('TAlias = ');
  Assert.IsTrue(FindReferenceAtOffset(lModel, 'TTarget', lReferenceOffset, lReference),
    'alias type reference');
  Assert.AreEqual('TTarget', Copy(lSource, lReference.Offset, lReference.EndOffset -
    lReference.Offset));
  Assert.AreEqual(ColumnOfSourceOffset(lSource, lReferenceOffset), lReference.Column);
  Assert.IsTrue(HasReferenceAtOffset(lModel, 'TTarget', Pos('PTarget = ^TTarget', lSource) +
    Length('PTarget = ^')), 'pointer type reference');
  Assert.IsTrue(HasReferenceAtOffset(lModel, 'TAlias', Pos('TArray = array of TAlias',
    lSource) + Length('TArray = array of ')), 'array type reference');
  Assert.IsTrue(HasReferenceAtOffset(lModel, 'TArray', Pos('Item: TArray', lSource) +
    Length('Item: ')), 'record field type reference');
  Assert.IsTrue(HasReferenceAtOffset(lModel, 'TAlias', Pos('TInline = {$IFDEF ACTIVE_RANGE}TAlias',
    lSource) + Length('TInline = {$IFDEF ACTIVE_RANGE}')), 'inline directive type reference');
  Assert.IsTrue(HasReferenceAtOffset(lModel, 'TAlias', Pos('TConditional = TAlias',
    lSource) + Length('TConditional = ')), 'active conditional type reference');
  Assert.IsFalse(HasReferenceAtOffset(lModel, 'TAlias', Pos('TInactive = TAlias',
    lSource) + Length('TInactive = ')), 'inactive conditional type reference');
  Assert.IsTrue(HasReferenceAtOffset(lModel, 'TTarget', Pos('GTarget: TTarget', lSource) +
    Length('GTarget: ')), 'global type reference');
  Assert.IsTrue(HasReferenceAtOffset(lModel, 'TAlias', Pos('aParam: TAlias', lSource) +
    Length('aParam: ')), 'parameter type reference');
  Assert.IsTrue(HasReferenceAtOffset(lModel, 'TContainer', Pos('lLocal: TContainer', lSource) +
    Length('lLocal: ')), 'local type reference');
  Assert.IsTrue(HasReferenceAtOffset(lModel, 'GTarget', Pos('GTarget.Field :=', lSource)),
    'global body reference after include');
  Assert.IsTrue(HasReferenceAtOffset(lModel, 'Field', Pos('Field :=', lSource)),
    'field body reference');
  Assert.IsTrue(HasReferenceAtOffset(lModel, 'lLocal', Pos('lLocal.Item', lSource)),
    'local body reference');
  Assert.IsTrue(HasReferenceAtOffset(lModel, 'aParam', Pos('aParam.Field', lSource)),
    'parameter body reference');
  Assert.IsFalse(HasReferenceAtOffset(lModel, 'TAlias', Pos('TAlias in a comment',
    lSource)), 'comment token');
  Assert.IsFalse(HasReferenceAtOffset(lModel, 'TTarget', Pos('TTarget in a string',
    lSource)), 'string token');
  Assert.IsTrue(TDelphiSemanticUnitModelExtractor.ReferenceReconciliationFallbackCount <= 17,
    'preprocessed source should keep reference reconciliation fallback within the documented ceiling');
end;

procedure TUnitModelTests.ReferencesCarryOriginalSourceRangesWithoutFallbackForPlainSource;
var
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lPath: string;
  lRoot: string;
  lSource: string;
begin
  lRoot := TPath.Combine(ExtractFilePath(ParamStr(0)), 'unit-model-plain-reference-ranges');
  TDirectory.CreateDirectory(lRoot);
  lPath := TPath.Combine(lRoot, 'PlainReferenceRangeUnit.pas');
  lSource :=
    'unit PlainReferenceRangeUnit;' + sLineBreak +
    'interface' + sLineBreak +
    'type' + sLineBreak +
    '  TTarget = record' + sLineBreak +
    '    Value: Integer;' + sLineBreak +
    '  end;' + sLineBreak +
    'var' + sLineBreak +
    '  GTarget: TTarget;' + sLineBreak +
    'procedure UseRefs(const aParam: TTarget);' + sLineBreak +
    'implementation' + sLineBreak +
    'procedure UseRefs(const aParam: TTarget);' + sLineBreak +
    'begin' + sLineBreak +
    '  GTarget.Value := aParam.Value;' + sLineBreak +
    'end;' + sLineBreak +
    'end.';
  TFile.WriteAllText(lPath, lSource, TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lPath;
  lOptions.ProjectContextApplied := True;

  TDelphiSemanticUnitModelExtractor.ResetReferenceReconciliationFallbackCount;
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsTrue(lModel.Success);
  Assert.IsTrue(HasReferenceAtOffset(lModel, 'TTarget', Pos('GTarget: TTarget', lSource) +
    Length('GTarget: ')), 'global type reference');
  Assert.IsTrue(HasReferenceAtOffset(lModel, 'GTarget', Pos('GTarget.Value', lSource)),
    'body global reference');
  Assert.IsTrue(TDelphiSemanticUnitModelExtractor.ReferenceReconciliationFallbackCount <= 5,
    'plain source should keep reference reconciliation fallback within the documented ceiling');
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

procedure TUnitModelTests.TypeBlockAnalysisIsBuiltOncePerExtraction;
var
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := FixturePath('UnitModel', 'SemanticUnit.pas');
  lOptions.ProjectContextApplied := True;

  TDelphiSemanticUnitModelExtractor.ResetTypeBlockAnalysisBuildCount;
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsTrue(lModel.Success);
  Assert.AreEqual(1, TDelphiSemanticUnitModelExtractor.TypeBlockAnalysisBuildCount,
    'type-block analysis should be built once per extracted unit');
end;

procedure TUnitModelTests.ReferenceReconciliationScansRepeatedNamesOnce;
var
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := FixturePath('UnitModel', 'ConditionalModelUnit.pas');
  lOptions.Defines := ['ACTIVE'];
  lOptions.ProjectContextApplied := True;

  TDelphiSemanticUnitModelExtractor.ResetReferenceReconciliationFallbackCount;
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsTrue(lModel.Success);
  Assert.IsTrue(TDelphiSemanticUnitModelExtractor.ReferenceReconciliationFallbackCount > 0,
    'fixture should exercise reference reconciliation fallback');
  Assert.IsTrue(TDelphiSemanticUnitModelExtractor.ReferenceReconciliationNameScanCount <
    TDelphiSemanticUnitModelExtractor.ReferenceReconciliationFallbackCount,
    'repeated fallback names should share one source scan per name');
end;

procedure TUnitModelTests.ReferenceReconciliationBuildsOccurrenceTableOnce;
var
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := FixturePath('UnitModel', 'ConditionalModelUnit.pas');
  lOptions.Defines := ['ACTIVE'];
  lOptions.ProjectContextApplied := True;

  TDelphiSemanticUnitModelExtractor.ResetReferenceReconciliationFallbackCount;
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsTrue(lModel.Success);
  Assert.IsTrue(TDelphiSemanticUnitModelExtractor.ReferenceReconciliationFallbackCount > 0,
    'fixture should exercise reference reconciliation fallback');
  Assert.AreEqual(1, TDelphiSemanticUnitModelExtractor.ReferenceOccurrenceTableBuildCount,
    'fallback reconciliation should build one token occurrence table per unit');
  Assert.AreEqual(0, TDelphiSemanticUnitModelExtractor.ReferenceReconciliationNameScanCount,
    'fallback reconciliation should not regex-scan source once per name');
end;

procedure TUnitModelTests.RoutineReconciliationUsesOffsetMapBeforeFallback;
var
  lSourceText: string;
begin
  lSourceText := TFile.ReadAllText(TPath.Combine(ExtractFilePath(ParamStr(0)),
    '..\..\src\DelphiSemantics.Model.pas'), TEncoding.UTF8);

  Assert.IsTrue(ContainsText(lSourceText,
    'ApplyRoutineSourceOffsetMap(lSourceResult.Source.Text, lOffsetMap, lRoutines);'),
    'routine reconciliation should first map preprocessed offsets back to source offsets');
  Assert.IsTrue(ContainsText(lSourceText, 'SourceRangeMatchesRoutine'),
    'routine reconciliation should skip fallback scans when the mapped source range is already exact');
  Assert.IsTrue(ContainsText(lSourceText,
    'ApplyDeclarationSourceOffsetMap(lSourceResult.Source.Text, lOffsetMap, lDeclarations);'),
    'declaration reconciliation should first map preprocessed offsets back to source offsets');
  Assert.IsTrue(ContainsText(lSourceText,
    'ApplyMemberSourceOffsetMap(lSourceResult.Source.Text, lOffsetMap, lMembers);'),
    'member reconciliation should first map preprocessed offsets back to source offsets');
  Assert.IsTrue(ContainsText(lSourceText,
    'ApplyLocalSourceOffsetMap(lSourceResult.Source.Text, lOffsetMap, lLocals);'),
    'local reconciliation should first map preprocessed offsets back to source offsets');
  Assert.IsTrue(ContainsText(lSourceText, 'if lCleanText = '''' then'),
    'fallback reconciliation should not sanitize whole source files when mapped ranges are already exact');
end;

initialization
  TDUnitX.RegisterTestFixture(TUnitModelTests);

end.
