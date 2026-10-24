unit DelphiSemantics.SemanticGraph;

interface

uses
  DelphiSemantics.Model, DelphiSemantics.ProjectContext, DelphiSemantics.Resolve.UnitNameWitness;

type
  TDelphiSemanticProjectGraphId = record
    Value: string;
  end;

  TDelphiSemanticUnitGraphId = record
    Value: string;
  end;

  TDelphiSemanticGraphSymbolId = record
    Value: string;
  end;

  TDelphiSemanticGraphReferenceId = record
    Value: string;
  end;

  TDelphiSemanticGraphWithStatementId = record
    Value: string;
  end;

  TDelphiSemanticGraphTypeId = record
    Value: string;
  end;

  TDelphiSemanticSourceRange = record
    FileName: string;
    Line: Integer;
    Column: Integer;
    EndLine: Integer;
    EndColumn: Integer;
    Offset: Integer;
    EndOffset: Integer;
  end;

  TDelphiSemanticGraphUnit = record
    Id: TDelphiSemanticUnitGraphId;
    ProjectId: TDelphiSemanticProjectGraphId;
    UnitName: string;
    FileName: string;
    SourceKind: string;
    ScopeModelStatus: string;
    InterfaceImports: TArray<string>;
    ImplementationImports: TArray<string>;
    ImportsKnown: Boolean;
    SourceRange: TDelphiSemanticSourceRange;
  end;

  TDelphiSemanticGraphSymbol = record
    Id: TDelphiSemanticGraphSymbolId;
    UnitId: TDelphiSemanticUnitGraphId;
    Name: string;
    Kind: string;
    OwnerName: string;
    SourceRange: TDelphiSemanticSourceRange;
  end;

  TDelphiSemanticGraphDeclaration = record
    SymbolId: TDelphiSemanticGraphSymbolId;
    UnitId: TDelphiSemanticUnitGraphId;
    Name: string;
    Kind: string;
    TypeName: string;
    ScopeKind: string;
    OwnerScopeId: string;
    SemanticSymbolId: string;
    SourceRange: TDelphiSemanticSourceRange;
  end;

  TDelphiSemanticGraphType = record
    SymbolId: TDelphiSemanticGraphSymbolId;
    DeclaredId: TDelphiSemanticGraphTypeId;
    CanonicalId: TDelphiSemanticGraphTypeId;
    UnderlyingId: TDelphiSemanticGraphTypeId;
    UnitId: TDelphiSemanticUnitGraphId;
    Name: string;
    Kind: string;
    CanonicalName: string;
    UnderlyingName: string;
    BaseTypeName: string;
    HelperTargetName: string;
    SectionKind: string;
    ScopeKind: string;
    OwnerScopeId: string;
    SemanticSymbolId: string;
    SourceRange: TDelphiSemanticSourceRange;
  end;

  TDelphiSemanticGraphMember = record
    SymbolId: TDelphiSemanticGraphSymbolId;
    UnitId: TDelphiSemanticUnitGraphId;
    OwnerName: string;
    OwnerScopeId: string;
    OwnerSemanticSymbolId: string;
    Name: string;
    Kind: string;
    TypeName: string;
    Visibility: string;
    Signature: string;
    IsIndexed: Boolean;
    IsDefault: Boolean;
    SourceRange: TDelphiSemanticSourceRange;
  end;

  TDelphiSemanticGraphParameter = record
    SymbolId: TDelphiSemanticGraphSymbolId;
    UnitId: TDelphiSemanticUnitGraphId;
    RoutineName: string;
    RoutineScopeId: string;
    Name: string;
    TypeName: string;
    Modifier: string;
    SourceRange: TDelphiSemanticSourceRange;
  end;

  TDelphiSemanticGraphRoutine = record
    SymbolId: TDelphiSemanticGraphSymbolId;
    UnitId: TDelphiSemanticUnitGraphId;
    Name: string;
    OwnerName: string;
    SectionKind: string;
    Signature: string;
    ReturnType: string;
    ScopeId: string;
    ParentScopeId: string;
    AstScopeKind: string;
    AstSemanticSignature: string;
    AstSourceSignature: string;
    AstSourceSignatureVerified: Boolean;
    SourceRange: TDelphiSemanticSourceRange;
  end;

  TDelphiSemanticGraphLocal = record
    SymbolId: TDelphiSemanticGraphSymbolId;
    UnitId: TDelphiSemanticUnitGraphId;
    RoutineName: string;
    RoutineScopeId: string;
    Name: string;
    Kind: string;
    TypeName: string;
    SourceRange: TDelphiSemanticSourceRange;
  end;

  TDelphiSemanticGraphReference = record
    Id: TDelphiSemanticGraphReferenceId;
    UnitId: TDelphiSemanticUnitGraphId;
    Name: string;
    RoutineName: string;
    RoutineScopeId: string;
    Role: string;
    SectionKind: string;
    SourceRange: TDelphiSemanticSourceRange;
  end;

  TDelphiSemanticGraphWithStatement = record
    Id: TDelphiSemanticGraphWithStatementId;
    UnitId: TDelphiSemanticUnitGraphId;
    SelectorText: string;
    SelectorCount: Integer;
    NestingDepth: Integer;
    SourceRange: TDelphiSemanticSourceRange;
    BodyRange: TDelphiSemanticSourceRange;
  end;

  TDelphiSemanticGraphBuildMetrics = record
    UnitCount: Integer;
    SymbolCount: Integer;
    ReferenceCount: Integer;
    WithStatementCount: Integer;
    BuildMilliseconds: Int64;
  end;

  TDelphiSemanticSemanticGraph = class
  private
    fUnitNameWitness: IDelphiSemanticUnitNameWitness;
    fDeclarations: TArray<TDelphiSemanticGraphDeclaration>;
    fLocals: TArray<TDelphiSemanticGraphLocal>;
    fMembers: TArray<TDelphiSemanticGraphMember>;
    fMetrics: TDelphiSemanticGraphBuildMetrics;
    fParameters: TArray<TDelphiSemanticGraphParameter>;
    fProjectId: TDelphiSemanticProjectGraphId;
    fReferences: TArray<TDelphiSemanticGraphReference>;
    fRoutines: TArray<TDelphiSemanticGraphRoutine>;
    fSymbols: TArray<TDelphiSemanticGraphSymbol>;
    fTypes: TArray<TDelphiSemanticGraphType>;
    fUnits: TArray<TDelphiSemanticGraphUnit>;
    fWithStatements: TArray<TDelphiSemanticGraphWithStatement>;
  public
    constructor Create(const aProjectId: TDelphiSemanticProjectGraphId;
      const aUnits: TArray<TDelphiSemanticGraphUnit>;
      const aSymbols: TArray<TDelphiSemanticGraphSymbol>;
      const aDeclarations: TArray<TDelphiSemanticGraphDeclaration>;
      const aTypes: TArray<TDelphiSemanticGraphType>;
      const aMembers: TArray<TDelphiSemanticGraphMember>;
      const aRoutines: TArray<TDelphiSemanticGraphRoutine>;
      const aParameters: TArray<TDelphiSemanticGraphParameter>;
      const aLocals: TArray<TDelphiSemanticGraphLocal>;
      const aMetrics: TDelphiSemanticGraphBuildMetrics); overload;
    constructor Create(const aProjectId: TDelphiSemanticProjectGraphId;
      const aUnits: TArray<TDelphiSemanticGraphUnit>;
      const aSymbols: TArray<TDelphiSemanticGraphSymbol>;
      const aDeclarations: TArray<TDelphiSemanticGraphDeclaration>;
      const aTypes: TArray<TDelphiSemanticGraphType>;
      const aMembers: TArray<TDelphiSemanticGraphMember>;
      const aRoutines: TArray<TDelphiSemanticGraphRoutine>;
      const aParameters: TArray<TDelphiSemanticGraphParameter>;
      const aLocals: TArray<TDelphiSemanticGraphLocal>;
      const aReferences: TArray<TDelphiSemanticGraphReference>;
      const aWithStatements: TArray<TDelphiSemanticGraphWithStatement>;
      const aMetrics: TDelphiSemanticGraphBuildMetrics); overload;
    function Declarations: TArray<TDelphiSemanticGraphDeclaration>;
    function FindRoutineByName(const aName: string; out aRoutine: TDelphiSemanticGraphRoutine):
      Boolean;
    function FindTypeByName(const aName: string; out aType: TDelphiSemanticGraphType):
      Boolean;
    function FindUnitByName(const aUnitName: string; out aUnit: TDelphiSemanticGraphUnit):
      Boolean;
    function Locals: TArray<TDelphiSemanticGraphLocal>;
    function Members: TArray<TDelphiSemanticGraphMember>;
    function Parameters: TArray<TDelphiSemanticGraphParameter>;
    function References: TArray<TDelphiSemanticGraphReference>;
    function Routines: TArray<TDelphiSemanticGraphRoutine>;
    function Symbols: TArray<TDelphiSemanticGraphSymbol>;
    function Types: TArray<TDelphiSemanticGraphType>;
    function Units: TArray<TDelphiSemanticGraphUnit>;
    function WithStatements: TArray<TDelphiSemanticGraphWithStatement>;
    property UnitNameWitness: IDelphiSemanticUnitNameWitness read fUnitNameWitness
      write fUnitNameWitness;
    property Metrics: TDelphiSemanticGraphBuildMetrics read fMetrics;
    property ProjectId: TDelphiSemanticProjectGraphId read fProjectId;
  end;

  TDelphiSemanticSemanticGraphBuilder = record
  public
    class function ProjectImports(const aProject: TDelphiSemanticProjectInfo;
      const aModel: TDelphiSemanticUnitModel; const aModels: TArray<TDelphiSemanticUnitModel>;
      out aInterface, aImplementation: TArray<string>): Boolean; static;
    class function Build(const aProject: TDelphiSemanticProjectInfo;
      const aUnitModels: TArray<TDelphiSemanticUnitModel>): TDelphiSemanticSemanticGraph;
      static;
  end;

implementation

uses
  System.Diagnostics, System.Generics.Collections, System.Hash, System.IOUtils, System.SysUtils,
  DelphiSemantics.Resolve.UnitResolver, DelphiSemantics.SourceConditionals;

function StableHash(const aText: string): string;
begin
  Result := THashSHA2.GetHashString(aText);
end;

function NormalizePathForId(const aFileName: string): string;
begin
  Result := LowerCase(TPath.GetFullPath(aFileName));
end;

function MakeProjectId(const aProject: TDelphiSemanticProjectInfo):
  TDelphiSemanticProjectGraphId;
var
  lIdentity: string;
begin
  if aProject.ContextFingerprint <> '' then
    lIdentity := aProject.ContextFingerprint
  else
    lIdentity := aProject.ProjectFileName + '|' + aProject.ProjectName + '|' +
      aProject.Configuration + '|' + aProject.Platform;

  Result.Value := StableHash('project|' + LowerCase(lIdentity));
end;

function MakeUnitId(const aProjectId: TDelphiSemanticProjectGraphId;
  const aModel: TDelphiSemanticUnitModel): TDelphiSemanticUnitGraphId;
begin
  Result.Value := StableHash('unit|' + aProjectId.Value + '|' + LowerCase(aModel.UnitName) +
    '|' + NormalizePathForId(aModel.FileName));
end;

function MakeSymbolId(const aUnitId: TDelphiSemanticUnitGraphId;
  const aKind, aOwnerName, aName: string; const aLine, aColumn, aOrdinal: Integer):
  TDelphiSemanticGraphSymbolId;
begin
  Result.Value := StableHash('symbol|' + aUnitId.Value + '|' + LowerCase(aKind) + '|' +
    LowerCase(aOwnerName) + '|' + LowerCase(aName) + '|' + IntToStr(aLine) + '|' +
    IntToStr(aColumn) + '|' + IntToStr(aOrdinal));
end;

function MakeTypeId(const aUnitId: TDelphiSemanticUnitGraphId; const aRole, aName: string):
  TDelphiSemanticGraphTypeId;
begin
  Result.Value := StableHash('type|' + aUnitId.Value + '|' + LowerCase(aRole) + '|' +
    LowerCase(aName));
end;

function MakeScopedTypeId(const aUnitId: TDelphiSemanticUnitGraphId; const aRole,
  aOwnerScopeId, aSemanticSymbolId: string): TDelphiSemanticGraphTypeId;
begin
  Result := Default(TDelphiSemanticGraphTypeId);
  if (aOwnerScopeId = '') or (aSemanticSymbolId = '') then
    Exit;
  Result.Value := StableHash('local-type|' + aUnitId.Value + '|' + LowerCase(aRole) +
    '|' + LowerCase(aOwnerScopeId) + '|' + LowerCase(aSemanticSymbolId));
end;

function MakeReferenceId(const aUnitId: TDelphiSemanticUnitGraphId;
  const aReference: TDelphiSemanticReference; const aOrdinal: Integer):
  TDelphiSemanticGraphReferenceId;
begin
  Result.Value := StableHash('reference|' + aUnitId.Value + '|' +
    LowerCase(aReference.Name) + '|' + IntToStr(aReference.Line) + '|' +
    IntToStr(aReference.Column) + '|' + IntToStr(aOrdinal));
end;

function MakeWithStatementId(const aUnitId: TDelphiSemanticUnitGraphId;
  const aWithStatement: TDelphiSemanticWithStatement; const aOrdinal: Integer):
  TDelphiSemanticGraphWithStatementId;
begin
  Result.Value := StableHash('with|' + aUnitId.Value + '|' +
    LowerCase(aWithStatement.SelectorText) + '|' + IntToStr(aWithStatement.Line) + '|' +
    IntToStr(aWithStatement.Column) + '|' + IntToStr(aOrdinal));
end;

function CompleteNameRange(const aRange: TDelphiSemanticSourceRange; const aName: string):
  TDelphiSemanticSourceRange;
begin
  Result := aRange;
  if (Result.Line > 0) and (Result.Column > 0) and (Result.EndLine = 0) then
    Result.EndLine := Result.Line;
  if (Result.EndLine = Result.Line) and (Result.EndColumn = 0) then
    Result.EndColumn := Result.Column + Length(aName);
  if (Result.Offset > 0) and (Result.EndOffset = 0) then
    Result.EndOffset := Result.Offset + Length(aName);
end;

function UnitSourceRange(const aModel: TDelphiSemanticUnitModel): TDelphiSemanticSourceRange;
begin
  Result := Default(TDelphiSemanticSourceRange);
  Result.FileName := aModel.FileName;
end;

function BuildUnit(const aProjectId: TDelphiSemanticProjectGraphId;
  const aProject: TDelphiSemanticProjectInfo; const aModel: TDelphiSemanticUnitModel;
  const aModels: TArray<TDelphiSemanticUnitModel>): TDelphiSemanticGraphUnit;
begin
  Result := Default(TDelphiSemanticGraphUnit);
  Result.Id := MakeUnitId(aProjectId, aModel);
  Result.ProjectId := aProjectId;
  Result.UnitName := aModel.UnitName;
  Result.FileName := aModel.FileName;
  Result.SourceKind := 'project';
  Result.ScopeModelStatus := aModel.ScopeModelStatus;
  Result.ImportsKnown := TDelphiSemanticSemanticGraphBuilder.ProjectImports(aProject,
    aModel, aModels, Result.InterfaceImports, Result.ImplementationImports);
  Result.SourceRange := UnitSourceRange(aModel);
end;

function DeclarationSourceRange(const aModel: TDelphiSemanticUnitModel;
  const aDeclaration: TDelphiSemanticDeclaration): TDelphiSemanticSourceRange;
begin
  Result := Default(TDelphiSemanticSourceRange);
  Result.FileName := aModel.FileName;
  Result.Line := aDeclaration.Line;
  Result.Column := aDeclaration.Column;
  Result.Offset := aDeclaration.Offset;
  Result.EndOffset := aDeclaration.EndOffset;
  Result := CompleteNameRange(Result, aDeclaration.Name);
end;

function MemberSourceRange(const aModel: TDelphiSemanticUnitModel;
  const aMember: TDelphiSemanticMember): TDelphiSemanticSourceRange;
begin
  Result := Default(TDelphiSemanticSourceRange);
  Result.FileName := aModel.FileName;
  Result.Line := aMember.Line;
  Result.Column := aMember.Column;
  Result.Offset := aMember.Offset;
  Result.EndOffset := aMember.EndOffset;
  Result := CompleteNameRange(Result, aMember.Name);
end;

function RoutineSourceRange(const aModel: TDelphiSemanticUnitModel;
  const aRoutine: TDelphiSemanticRoutine): TDelphiSemanticSourceRange;
begin
  Result := Default(TDelphiSemanticSourceRange);
  if aRoutine.FileName <> '' then
    Result.FileName := aRoutine.FileName
  else
    Result.FileName := aModel.FileName;
  Result.Line := aRoutine.Line;
  Result.Column := aRoutine.Column;
  Result.Offset := aRoutine.Offset;
  Result.EndOffset := aRoutine.EndOffset;
  if aRoutine.EndLine > 0 then
    Result.EndLine := aRoutine.EndLine;
  if aRoutine.EndColumn > 0 then
    Result.EndColumn := aRoutine.EndColumn;
  Result := CompleteNameRange(Result, aRoutine.Name);
end;

function LocalSourceRange(const aModel: TDelphiSemanticUnitModel;
  const aLocal: TDelphiSemanticLocal): TDelphiSemanticSourceRange;
begin
  Result := Default(TDelphiSemanticSourceRange);
  Result.FileName := aModel.FileName;
  Result.Line := aLocal.Line;
  Result.Column := aLocal.Column;
  Result.Offset := aLocal.Offset;
  Result.EndOffset := aLocal.EndOffset;
  Result := CompleteNameRange(Result, aLocal.Name);
end;

function ParameterSourceRange(const aModel: TDelphiSemanticUnitModel;
  const aParameter: TDelphiSemanticParameter): TDelphiSemanticSourceRange;
begin
  Result := Default(TDelphiSemanticSourceRange);
  Result.FileName := aModel.FileName;
  Result.Line := aParameter.Line;
  Result.Column := aParameter.Column;
  Result.Offset := aParameter.Offset;
  Result.EndOffset := aParameter.EndOffset;
  Result := CompleteNameRange(Result, aParameter.Name);
end;

function ReferenceSourceRange(const aModel: TDelphiSemanticUnitModel;
  const aReference: TDelphiSemanticReference): TDelphiSemanticSourceRange;
begin
  Result := Default(TDelphiSemanticSourceRange);
  Result.FileName := aModel.FileName;
  Result.Line := aReference.Line;
  Result.Column := aReference.Column;
  Result.EndLine := aReference.EndLine;
  Result.EndColumn := aReference.EndColumn;
  Result.Offset := aReference.Offset;
  Result.EndOffset := aReference.EndOffset;
  Result := CompleteNameRange(Result, aReference.Name);
end;

function WithSourceRange(const aModel: TDelphiSemanticUnitModel;
  const aWithStatement: TDelphiSemanticWithStatement): TDelphiSemanticSourceRange;
begin
  Result := Default(TDelphiSemanticSourceRange);
  Result.FileName := aModel.FileName;
  Result.Line := aWithStatement.Line;
  Result.Column := aWithStatement.Column;
  Result.EndLine := aWithStatement.EndLine;
  Result.EndColumn := aWithStatement.EndColumn;
end;

function WithBodyRange(const aModel: TDelphiSemanticUnitModel;
  const aWithStatement: TDelphiSemanticWithStatement): TDelphiSemanticSourceRange;
begin
  Result := Default(TDelphiSemanticSourceRange);
  Result.FileName := aModel.FileName;
  Result.Line := aWithStatement.BodyLine;
  Result.Column := aWithStatement.BodyColumn;
  Result.EndLine := aWithStatement.BodyEndLine;
  Result.EndColumn := aWithStatement.BodyEndColumn;
end;

procedure AddDeclarationSymbols(const aSymbols: TList<TDelphiSemanticGraphSymbol>;
  const aDeclarations: TList<TDelphiSemanticGraphDeclaration>;
  const aTypes: TList<TDelphiSemanticGraphType>;
  const aUnit: TDelphiSemanticGraphUnit; const aModel: TDelphiSemanticUnitModel);
var
  lDeclarationDto: TDelphiSemanticGraphDeclaration;
  lDeclaration: TDelphiSemanticDeclaration;
  lSymbol: TDelphiSemanticGraphSymbol;
  lType: TDelphiSemanticGraphType;
  lTypeName: string;
begin
  for lDeclaration in aModel.Declarations do
  begin
    if lDeclaration.Name = '' then
      Continue;

    lSymbol := Default(TDelphiSemanticGraphSymbol);
    lSymbol.Id := MakeSymbolId(aUnit.Id, lDeclaration.Kind, '', lDeclaration.Name,
      lDeclaration.Line, lDeclaration.Column, aSymbols.Count);
    lSymbol.UnitId := aUnit.Id;
    lSymbol.Name := lDeclaration.Name;
    lSymbol.Kind := lDeclaration.Kind;
    lSymbol.SourceRange := DeclarationSourceRange(aModel, lDeclaration);
    aSymbols.Add(lSymbol);

    lDeclarationDto := Default(TDelphiSemanticGraphDeclaration);
    lDeclarationDto.SymbolId := lSymbol.Id;
    lDeclarationDto.UnitId := aUnit.Id;
    lDeclarationDto.Name := lDeclaration.Name;
    lDeclarationDto.Kind := lDeclaration.Kind;
    lDeclarationDto.TypeName := lDeclaration.TypeName;
    lDeclarationDto.ScopeKind := lDeclaration.ScopeKind;
    lDeclarationDto.OwnerScopeId := lDeclaration.OwnerScopeId;
    lDeclarationDto.SemanticSymbolId := lDeclaration.SymbolId;
    lDeclarationDto.SourceRange := lSymbol.SourceRange;
    aDeclarations.Add(lDeclarationDto);

    if SameText(lDeclaration.Kind, 'type') or SameText(lDeclaration.Kind, 'type-alias') then
    begin
      lTypeName := lDeclaration.TypeName;
      if lTypeName = '' then
        lTypeName := lDeclaration.Name;
      lType := Default(TDelphiSemanticGraphType);
      lType.SymbolId := lSymbol.Id;
      lType.UnitId := aUnit.Id;
      lType.Name := lDeclaration.Name;
      lType.Kind := lDeclaration.Kind;
      lType.CanonicalName := lTypeName;
      lType.UnderlyingName := lTypeName;
      lType.BaseTypeName := lDeclaration.BaseTypeName;
      lType.HelperTargetName := lDeclaration.HelperTargetName;
      lType.SectionKind := lDeclaration.SectionKind;
      lType.ScopeKind := lDeclaration.ScopeKind;
      lType.OwnerScopeId := lDeclaration.OwnerScopeId;
      lType.SemanticSymbolId := lDeclaration.SymbolId;
      if SameText(lDeclaration.ScopeKind, 'routine') then
      begin
        lType.DeclaredId := MakeScopedTypeId(aUnit.Id, 'declared',
          lDeclaration.OwnerScopeId, lDeclaration.SymbolId);
        lType.CanonicalId := MakeScopedTypeId(aUnit.Id, 'canonical',
          lDeclaration.OwnerScopeId, lDeclaration.SymbolId);
        lType.UnderlyingId := MakeScopedTypeId(aUnit.Id, 'underlying',
          lDeclaration.OwnerScopeId, lDeclaration.SymbolId);
      end else
      begin
        lType.DeclaredId := MakeTypeId(aUnit.Id, 'declared', lDeclaration.Name);
        lType.CanonicalId := MakeTypeId(aUnit.Id, 'canonical', lType.CanonicalName);
        lType.UnderlyingId := MakeTypeId(aUnit.Id, 'underlying', lType.UnderlyingName);
      end;
      lType.SourceRange := lSymbol.SourceRange;
      aTypes.Add(lType);
    end;
  end;
end;

procedure AddMemberSymbols(const aSymbols: TList<TDelphiSemanticGraphSymbol>;
  const aMembers: TList<TDelphiSemanticGraphMember>; const aUnit: TDelphiSemanticGraphUnit;
  const aModel: TDelphiSemanticUnitModel);
var
  lMember: TDelphiSemanticMember;
  lMemberDto: TDelphiSemanticGraphMember;
  lSymbol: TDelphiSemanticGraphSymbol;
begin
  for lMember in aModel.Members do
  begin
    if lMember.Name = '' then
      Continue;

    lSymbol := Default(TDelphiSemanticGraphSymbol);
    lSymbol.Id := MakeSymbolId(aUnit.Id, lMember.Kind, lMember.OwnerName, lMember.Name,
      lMember.Line, lMember.Column, aSymbols.Count);
    lSymbol.UnitId := aUnit.Id;
    lSymbol.Name := lMember.Name;
    lSymbol.Kind := lMember.Kind;
    lSymbol.OwnerName := lMember.OwnerName;
    lSymbol.SourceRange := MemberSourceRange(aModel, lMember);
    aSymbols.Add(lSymbol);

    lMemberDto := Default(TDelphiSemanticGraphMember);
    lMemberDto.SymbolId := lSymbol.Id;
    lMemberDto.UnitId := aUnit.Id;
    lMemberDto.OwnerScopeId := lMember.OwnerScopeId;
    lMemberDto.OwnerSemanticSymbolId := lMember.OwnerSymbolId;
    lMemberDto.OwnerName := lMember.OwnerName;
    lMemberDto.Name := lMember.Name;
    lMemberDto.Kind := lMember.Kind;
    lMemberDto.TypeName := lMember.TypeName;
    lMemberDto.Visibility := lMember.Visibility;
    lMemberDto.Signature := lMember.Signature;
    lMemberDto.IsIndexed := lMember.IsIndexed;
    lMemberDto.IsDefault := lMember.IsDefault;
    lMemberDto.SourceRange := lSymbol.SourceRange;
    aMembers.Add(lMemberDto);
  end;
end;

procedure AddRoutineSymbols(const aSymbols: TList<TDelphiSemanticGraphSymbol>;
  const aRoutines: TList<TDelphiSemanticGraphRoutine>;
  const aParameters: TList<TDelphiSemanticGraphParameter>; const aUnit: TDelphiSemanticGraphUnit;
  const aModel: TDelphiSemanticUnitModel);
var
  lParameter: TDelphiSemanticParameter;
  lParameterDto: TDelphiSemanticGraphParameter;
  lRoutine: TDelphiSemanticRoutine;
  lRoutineDto: TDelphiSemanticGraphRoutine;
  lSymbol: TDelphiSemanticGraphSymbol;
begin
  for lRoutine in aModel.Routines do
  begin
    if lRoutine.Name = '' then
      Continue;

    lSymbol := Default(TDelphiSemanticGraphSymbol);
    lSymbol.Id := MakeSymbolId(aUnit.Id, 'routine', lRoutine.OwnerName, lRoutine.Name,
      lRoutine.Line, lRoutine.Column, aSymbols.Count);
    lSymbol.UnitId := aUnit.Id;
    lSymbol.Name := lRoutine.Name;
    lSymbol.Kind := 'routine';
    lSymbol.OwnerName := lRoutine.OwnerName;
    lSymbol.SourceRange := RoutineSourceRange(aModel, lRoutine);
    aSymbols.Add(lSymbol);

    lRoutineDto := Default(TDelphiSemanticGraphRoutine);
    lRoutineDto.SymbolId := lSymbol.Id;
    lRoutineDto.UnitId := aUnit.Id;
    lRoutineDto.Name := lRoutine.Name;
    lRoutineDto.OwnerName := lRoutine.OwnerName;
    lRoutineDto.SectionKind := lRoutine.SectionKind;
    lRoutineDto.Signature := lRoutine.Signature;
    lRoutineDto.ReturnType := lRoutine.ReturnType;
    lRoutineDto.ScopeId := lRoutine.ScopeId;
    lRoutineDto.ParentScopeId := lRoutine.ParentScopeId;
    lRoutineDto.AstScopeKind := lRoutine.AstScopeKind;
    lRoutineDto.AstSemanticSignature := lRoutine.AstSemanticSignature;
    lRoutineDto.AstSourceSignature := lRoutine.AstSourceSignature;
    lRoutineDto.AstSourceSignatureVerified := lRoutine.AstSourceSignatureVerified;
    lRoutineDto.SourceRange := lSymbol.SourceRange;
    aRoutines.Add(lRoutineDto);

    for lParameter in lRoutine.Parameters do
    begin
      lSymbol := Default(TDelphiSemanticGraphSymbol);
      lSymbol.Id := MakeSymbolId(aUnit.Id, 'parameter', lParameter.RoutineName,
        lParameter.Name, 0, 0, aSymbols.Count);
      lSymbol.UnitId := aUnit.Id;
      lSymbol.Name := lParameter.Name;
      lSymbol.Kind := 'parameter';
      lSymbol.OwnerName := lParameter.RoutineName;
      lSymbol.SourceRange := ParameterSourceRange(aModel, lParameter);
      aSymbols.Add(lSymbol);

      lParameterDto := Default(TDelphiSemanticGraphParameter);
      lParameterDto.SymbolId := lSymbol.Id;
      lParameterDto.UnitId := aUnit.Id;
      lParameterDto.RoutineName := lParameter.RoutineName;
      lParameterDto.RoutineScopeId := lRoutine.ScopeId;
      lParameterDto.Name := lParameter.Name;
      lParameterDto.TypeName := lParameter.TypeName;
      lParameterDto.Modifier := lParameter.Modifier;
      lParameterDto.SourceRange := lSymbol.SourceRange;
      aParameters.Add(lParameterDto);
    end;
  end;
end;

procedure AddLocalSymbols(const aSymbols: TList<TDelphiSemanticGraphSymbol>;
  const aLocals: TList<TDelphiSemanticGraphLocal>; const aUnit: TDelphiSemanticGraphUnit;
  const aModel: TDelphiSemanticUnitModel);
var
  lLocal: TDelphiSemanticLocal;
  lLocalDto: TDelphiSemanticGraphLocal;
  lSymbol: TDelphiSemanticGraphSymbol;
begin
  for lLocal in aModel.Locals do
  begin
    if lLocal.Name = '' then
      Continue;

    lSymbol := Default(TDelphiSemanticGraphSymbol);
    lSymbol.Id := MakeSymbolId(aUnit.Id, lLocal.Kind, lLocal.RoutineName, lLocal.Name,
      lLocal.Line, lLocal.Column, aSymbols.Count);
    lSymbol.UnitId := aUnit.Id;
    lSymbol.Name := lLocal.Name;
    lSymbol.Kind := lLocal.Kind;
    lSymbol.OwnerName := lLocal.RoutineName;
    lSymbol.SourceRange := LocalSourceRange(aModel, lLocal);
    aSymbols.Add(lSymbol);

    lLocalDto := Default(TDelphiSemanticGraphLocal);
    lLocalDto.SymbolId := lSymbol.Id;
    lLocalDto.UnitId := aUnit.Id;
    lLocalDto.RoutineName := lLocal.RoutineName;
    lLocalDto.RoutineScopeId := lLocal.RoutineScopeId;
    lLocalDto.Name := lLocal.Name;
    lLocalDto.Kind := lLocal.Kind;
    lLocalDto.TypeName := lLocal.TypeName;
    lLocalDto.SourceRange := lSymbol.SourceRange;
    aLocals.Add(lLocalDto);
  end;
end;

procedure AddReferences(const aReferences: TList<TDelphiSemanticGraphReference>;
  const aUnit: TDelphiSemanticGraphUnit; const aModel: TDelphiSemanticUnitModel);
var
  lReference: TDelphiSemanticReference;
  lReferenceDto: TDelphiSemanticGraphReference;
  lUnitOrdinal: Integer;
begin
  lUnitOrdinal := 0;
  for lReference in aModel.References do
  begin
    if lReference.Name = '' then
      Continue;

    lReferenceDto := Default(TDelphiSemanticGraphReference);
    lReferenceDto.Id := MakeReferenceId(aUnit.Id, lReference, lUnitOrdinal);
    lReferenceDto.UnitId := aUnit.Id;
    lReferenceDto.Name := lReference.Name;
    lReferenceDto.RoutineName := lReference.RoutineName;
    lReferenceDto.RoutineScopeId := lReference.RoutineScopeId;
    lReferenceDto.Role := lReference.Role;
    lReferenceDto.SectionKind := lReference.SectionKind;
    lReferenceDto.SourceRange := ReferenceSourceRange(aModel, lReference);
    aReferences.Add(lReferenceDto);
    Inc(lUnitOrdinal);
  end;
end;

procedure AddWithStatements(const aWithStatements: TList<TDelphiSemanticGraphWithStatement>;
  const aUnit: TDelphiSemanticGraphUnit; const aModel: TDelphiSemanticUnitModel);
var
  lWithDto: TDelphiSemanticGraphWithStatement;
  lWithStatement: TDelphiSemanticWithStatement;
  lUnitOrdinal: Integer;
begin
  lUnitOrdinal := 0;
  for lWithStatement in aModel.WithStatements do
  begin
    lWithDto := Default(TDelphiSemanticGraphWithStatement);
    lWithDto.Id := MakeWithStatementId(aUnit.Id, lWithStatement, lUnitOrdinal);
    lWithDto.UnitId := aUnit.Id;
    lWithDto.SelectorText := lWithStatement.SelectorText;
    lWithDto.SelectorCount := lWithStatement.SelectorCount;
    lWithDto.NestingDepth := lWithStatement.NestingDepth;
    lWithDto.SourceRange := WithSourceRange(aModel, lWithStatement);
    lWithDto.BodyRange := WithBodyRange(aModel, lWithStatement);
    aWithStatements.Add(lWithDto);
    Inc(lUnitOrdinal);
  end;
end;

constructor TDelphiSemanticSemanticGraph.Create(
  const aProjectId: TDelphiSemanticProjectGraphId;
  const aUnits: TArray<TDelphiSemanticGraphUnit>;
  const aSymbols: TArray<TDelphiSemanticGraphSymbol>;
  const aDeclarations: TArray<TDelphiSemanticGraphDeclaration>;
  const aTypes: TArray<TDelphiSemanticGraphType>;
  const aMembers: TArray<TDelphiSemanticGraphMember>;
  const aRoutines: TArray<TDelphiSemanticGraphRoutine>;
  const aParameters: TArray<TDelphiSemanticGraphParameter>;
  const aLocals: TArray<TDelphiSemanticGraphLocal>;
  const aMetrics: TDelphiSemanticGraphBuildMetrics);
begin
  Create(aProjectId, aUnits, aSymbols, aDeclarations, aTypes, aMembers, aRoutines,
    aParameters, aLocals, nil, nil, aMetrics);
end;

constructor TDelphiSemanticSemanticGraph.Create(
  const aProjectId: TDelphiSemanticProjectGraphId;
  const aUnits: TArray<TDelphiSemanticGraphUnit>;
  const aSymbols: TArray<TDelphiSemanticGraphSymbol>;
  const aDeclarations: TArray<TDelphiSemanticGraphDeclaration>;
  const aTypes: TArray<TDelphiSemanticGraphType>;
  const aMembers: TArray<TDelphiSemanticGraphMember>;
  const aRoutines: TArray<TDelphiSemanticGraphRoutine>;
  const aParameters: TArray<TDelphiSemanticGraphParameter>;
  const aLocals: TArray<TDelphiSemanticGraphLocal>;
  const aReferences: TArray<TDelphiSemanticGraphReference>;
  const aWithStatements: TArray<TDelphiSemanticGraphWithStatement>;
  const aMetrics: TDelphiSemanticGraphBuildMetrics);
begin
  inherited Create;
  fProjectId := aProjectId;
  fUnits := Copy(aUnits);
  fSymbols := Copy(aSymbols);
  fDeclarations := Copy(aDeclarations);
  fTypes := Copy(aTypes);
  fMembers := Copy(aMembers);
  fRoutines := Copy(aRoutines);
  fParameters := Copy(aParameters);
  fLocals := Copy(aLocals);
  fReferences := Copy(aReferences);
  fWithStatements := Copy(aWithStatements);
  fMetrics := aMetrics;
end;

function TDelphiSemanticSemanticGraph.Declarations: TArray<TDelphiSemanticGraphDeclaration>;
begin
  Result := Copy(fDeclarations);
end;

function TDelphiSemanticSemanticGraph.FindRoutineByName(const aName: string;
  out aRoutine: TDelphiSemanticGraphRoutine): Boolean;
var
  lRoutine: TDelphiSemanticGraphRoutine;
begin
  for lRoutine in fRoutines do
    if SameText(lRoutine.Name, aName) then
    begin
      aRoutine := lRoutine;
      Exit(True);
    end;

  aRoutine := Default(TDelphiSemanticGraphRoutine);
  Result := False;
end;

function TDelphiSemanticSemanticGraph.FindTypeByName(const aName: string;
  out aType: TDelphiSemanticGraphType): Boolean;
var
  lType: TDelphiSemanticGraphType;
begin
  for lType in fTypes do
    if SameText(lType.Name, aName) then
    begin
      aType := lType;
      Exit(True);
    end;

  aType := Default(TDelphiSemanticGraphType);
  Result := False;
end;

function TDelphiSemanticSemanticGraph.FindUnitByName(const aUnitName: string;
  out aUnit: TDelphiSemanticGraphUnit): Boolean;
var
  lUnit: TDelphiSemanticGraphUnit;
begin
  for lUnit in fUnits do
    if SameText(lUnit.UnitName, aUnitName) then
    begin
      aUnit := lUnit;
      Exit(True);
    end;

  aUnit := Default(TDelphiSemanticGraphUnit);
  Result := False;
end;

function TDelphiSemanticSemanticGraph.Locals: TArray<TDelphiSemanticGraphLocal>;
begin
  Result := Copy(fLocals);
end;

function TDelphiSemanticSemanticGraph.Members: TArray<TDelphiSemanticGraphMember>;
begin
  Result := Copy(fMembers);
end;

function TDelphiSemanticSemanticGraph.Parameters: TArray<TDelphiSemanticGraphParameter>;
begin
  Result := Copy(fParameters);
end;

function TDelphiSemanticSemanticGraph.References: TArray<TDelphiSemanticGraphReference>;
begin
  Result := Copy(fReferences);
end;

function TDelphiSemanticSemanticGraph.Routines: TArray<TDelphiSemanticGraphRoutine>;
begin
  Result := Copy(fRoutines);
end;

function TDelphiSemanticSemanticGraph.Symbols: TArray<TDelphiSemanticGraphSymbol>;
begin
  Result := Copy(fSymbols);
end;

function TDelphiSemanticSemanticGraph.Types: TArray<TDelphiSemanticGraphType>;
begin
  Result := Copy(fTypes);
end;

function TDelphiSemanticSemanticGraph.Units: TArray<TDelphiSemanticGraphUnit>;
begin
  Result := Copy(fUnits);
end;

function TDelphiSemanticSemanticGraph.WithStatements:
  TArray<TDelphiSemanticGraphWithStatement>;
begin
  Result := Copy(fWithStatements);
end;

function CanonicalProjectImport(const aProject: TDelphiSemanticProjectInfo;
  const aModels: TArray<TDelphiSemanticUnitModel>; const aUnitName: string): string;
var
  lCandidate: TUnitCandidateName;
  lModel: TDelphiSemanticUnitModel;
  lResolved: TDelphiSemanticUnitResolutionResult;
begin
  Result := aUnitName;
  // Only a model hit can change ProjectImports' spelling. Avoid filesystem
  // resolution for source/DCU-only names; their result is discarded below.
  for lCandidate in TDelphiSemanticUnitResolver.CandidateNames(aProject, Trim(aUnitName)) do
    for lModel in aModels do
      if SameText(lModel.UnitName, lCandidate.TargetName) then
      begin
        lResolved := TDelphiSemanticUnitResolver.Resolve(aProject, aUnitName, aModels);
        if lResolved.Found and SameText(lResolved.SourceKind, 'project') then
          Result := lResolved.CanonicalUnitName;
        Exit;
      end;
end;

class function TDelphiSemanticSemanticGraphBuilder.ProjectImports(
  const aProject: TDelphiSemanticProjectInfo; const aModel: TDelphiSemanticUnitModel;
  const aModels: TArray<TDelphiSemanticUnitModel>;
  out aInterface, aImplementation: TArray<string>): Boolean;
var
  i: Integer;
  lRawImports: TArray<string>;
begin
  if aModel.DependencyFacts.Known then
  begin
    aInterface := Copy(aModel.DependencyFacts.InterfaceImports);
    aImplementation := Copy(aModel.DependencyFacts.ImplementationImports);
    if (Length(aInterface) = 0) and (Length(aModel.DependencyFacts.RootImports) > 0) then
    begin
      aInterface := Copy(aModel.DependencyFacts.RootImports);
      aImplementation := Copy(aModel.DependencyFacts.RootImports);
    end;
  end else begin
    aInterface := Copy(aModel.InterfaceUses);
    aImplementation := Copy(aModel.ImplementationUses);
  end;
  // Concatenation with an empty array may share storage with its nonempty input.
  // Keep the raw spelling independent of the canonicalization below.
  lRawImports := Copy(aInterface + aImplementation);
  for i := 0 to High(aInterface) do
    aInterface[i] := CanonicalProjectImport(aProject, aModels, aInterface[i]);
  for i := 0 to High(aImplementation) do
    aImplementation[i] := CanonicalProjectImport(aProject, aModels, aImplementation[i]);
  Result := aModel.DependencyFacts.Known and aModel.Success and
    (SameText(aModel.ScopeModelStatus, 'ast') or
     SameText(aModel.ScopeModelStatus, 'ast-interface-only')) and
    not TDelphiSemanticSourceConditionals.ImportOrderUnknown(aModel.SourceText,
      aModel.VerifiedActiveSourceText, aModel.IncludeFileNames, lRawImports);
end;

class function TDelphiSemanticSemanticGraphBuilder.Build(
  const aProject: TDelphiSemanticProjectInfo;
  const aUnitModels: TArray<TDelphiSemanticUnitModel>): TDelphiSemanticSemanticGraph;
var
  lDeclarations: TList<TDelphiSemanticGraphDeclaration>;
  lLocals: TList<TDelphiSemanticGraphLocal>;
  lMembers: TList<TDelphiSemanticGraphMember>;
  lMetrics: TDelphiSemanticGraphBuildMetrics;
  lParameters: TList<TDelphiSemanticGraphParameter>;
  lReferences: TList<TDelphiSemanticGraphReference>;
  lUnit: TDelphiSemanticGraphUnit;
  lProjectId: TDelphiSemanticProjectGraphId;
  lRoutines: TList<TDelphiSemanticGraphRoutine>;
  lStopwatch: TStopwatch;
  lSymbols: TList<TDelphiSemanticGraphSymbol>;
  lTypes: TList<TDelphiSemanticGraphType>;
  lUnits: TList<TDelphiSemanticGraphUnit>;
  lWithStatements: TList<TDelphiSemanticGraphWithStatement>;
  lModel: TDelphiSemanticUnitModel;
begin
  lStopwatch := TStopwatch.StartNew;
  lDeclarations := nil;
  lTypes := nil;
  lMembers := nil;
  lRoutines := nil;
  lParameters := nil;
  lLocals := nil;
  lReferences := nil;
  lWithStatements := nil;
  lSymbols := nil;
  lUnits := TList<TDelphiSemanticGraphUnit>.Create;
  try
    lDeclarations := TList<TDelphiSemanticGraphDeclaration>.Create;
    lTypes := TList<TDelphiSemanticGraphType>.Create;
    lMembers := TList<TDelphiSemanticGraphMember>.Create;
    lRoutines := TList<TDelphiSemanticGraphRoutine>.Create;
    lParameters := TList<TDelphiSemanticGraphParameter>.Create;
    lLocals := TList<TDelphiSemanticGraphLocal>.Create;
    lReferences := TList<TDelphiSemanticGraphReference>.Create;
    lWithStatements := TList<TDelphiSemanticGraphWithStatement>.Create;
    lSymbols := TList<TDelphiSemanticGraphSymbol>.Create;
    lProjectId := MakeProjectId(aProject);
    for lModel in aUnitModels do
      if lModel.Success and (lModel.UnitName <> '') then
      begin
        lUnit := BuildUnit(lProjectId, aProject, lModel, aUnitModels);
        lUnits.Add(lUnit);
        AddDeclarationSymbols(lSymbols, lDeclarations, lTypes, lUnit, lModel);
        AddMemberSymbols(lSymbols, lMembers, lUnit, lModel);
        AddRoutineSymbols(lSymbols, lRoutines, lParameters, lUnit, lModel);
        AddLocalSymbols(lSymbols, lLocals, lUnit, lModel);
        AddReferences(lReferences, lUnit, lModel);
        AddWithStatements(lWithStatements, lUnit, lModel);
      end;

    lStopwatch.Stop;
    lMetrics := Default(TDelphiSemanticGraphBuildMetrics);
    lMetrics.UnitCount := lUnits.Count;
    lMetrics.SymbolCount := lSymbols.Count;
    lMetrics.ReferenceCount := lReferences.Count;
    lMetrics.WithStatementCount := lWithStatements.Count;
    lMetrics.BuildMilliseconds := lStopwatch.ElapsedMilliseconds;
    Result := TDelphiSemanticSemanticGraph.Create(lProjectId, lUnits.ToArray,
      lSymbols.ToArray, lDeclarations.ToArray, lTypes.ToArray, lMembers.ToArray,
      lRoutines.ToArray, lParameters.ToArray, lLocals.ToArray, lReferences.ToArray,
      lWithStatements.ToArray, lMetrics);
  finally
    lSymbols.Free;
    lWithStatements.Free;
    lReferences.Free;
    lLocals.Free;
    lParameters.Free;
    lRoutines.Free;
    lMembers.Free;
    lTypes.Free;
    lDeclarations.Free;
    lUnits.Free;
  end;
end;

end.
