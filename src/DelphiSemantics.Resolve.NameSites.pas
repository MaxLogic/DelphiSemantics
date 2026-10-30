unit DelphiSemantics.Resolve.NameSites;

interface

uses
  DelphiSemantics.Model, DelphiSemantics.Resolve.TypeResolver, DelphiSemantics.SemanticGraph;

type
  TDelphiSemanticNameSites = record
  private
    class function Source(const aUnitName, aFileName, aSectionKind, aOrigin: string;
      const aLine, aColumn: Integer): TDelphiSemanticNameSite; static;
  public
    class function AtWithStatement(const aModel: TDelphiSemanticUnitModel;
      const aWith: TDelphiSemanticWithStatement; const aRoutineScopeId: string;
      const aMethodClassId: TDelphiSemanticGraphTypeId): TDelphiSemanticNameSite; static;
    class function AtTempInsertion(const aModel: TDelphiSemanticUnitModel;
      const aRoutineScopeId: string; const aMethodClassId: TDelphiSemanticGraphTypeId;
      const aInsertionLine: Integer): TDelphiSemanticNameSite; static;
    class function AtDeclaration(const aModel: TDelphiSemanticUnitModel;
      const aDeclaration: TDelphiSemanticDeclaration;
      const aClassScopeId: TDelphiSemanticGraphTypeId): TDelphiSemanticNameSite; static;
    class function AtValueIdentity(const aDeclaration: TDelphiSemanticGraphDeclaration;
      const aUnitName: string): TDelphiSemanticNameSite; static;
    class function AtMember(const aModel: TDelphiSemanticUnitModel;
      const aMember: TDelphiSemanticMember;
      const aOwnerId: TDelphiSemanticGraphTypeId): TDelphiSemanticNameSite; static;
    class function AtLocal(const aModel: TDelphiSemanticUnitModel;
      const aLocal: TDelphiSemanticLocal;
      const aClassScopeId: TDelphiSemanticGraphTypeId): TDelphiSemanticNameSite; static;
    class function AtParameter(const aModel: TDelphiSemanticUnitModel;
      const aRoutine: TDelphiSemanticRoutine; const aParameter: TDelphiSemanticParameter;
      const aClassScopeId: TDelphiSemanticGraphTypeId): TDelphiSemanticNameSite; static;
    class function AtTypeIdentity(const aIdentity: TDelphiSemanticTypeIdentity): TDelphiSemanticNameSite; static;
    class function AtRoutineDeclaration(const aRoutine: TDelphiSemanticGraphRoutine;
      const aUnitName: string): TDelphiSemanticNameSite; static;
    class function AtUnindexedHelper(const aUnit: TDelphiSemanticGraphUnit;
      const aHelper: TDelphiSemanticUnindexedHelperFact): TDelphiSemanticNameSite; static;
    class function AtMetadata(const aUnitName, aOwnerTypeName: string): TDelphiSemanticNameSite; static;
  end;

implementation

uses
  System.SysUtils;

class function TDelphiSemanticNameSites.Source(const aUnitName, aFileName, aSectionKind,
  aOrigin: string; const aLine, aColumn: Integer): TDelphiSemanticNameSite;
begin
  Result := Default(TDelphiSemanticNameSite);
  Result.Kind := nskSource;
  Result.UnitName := aUnitName;
  Result.FileName := aFileName;
  Result.SectionKind := aSectionKind;
  Result.Line := aLine;
  Result.Column := aColumn;
  Result.Origin := aOrigin;
end;

class function TDelphiSemanticNameSites.AtWithStatement(const aModel: TDelphiSemanticUnitModel;
  const aWith: TDelphiSemanticWithStatement; const aRoutineScopeId: string;
  const aMethodClassId: TDelphiSemanticGraphTypeId): TDelphiSemanticNameSite;
begin
  Result := Source(aModel.UnitName, aModel.FileName, 'implementation', 'with',
    aWith.Line, aWith.Column);
  if Result.FileName = '' then
    Result.FileName := aModel.FileName;
  Result.RoutineScopeId := aRoutineScopeId;
  Result.ClassScopeId := aMethodClassId;
end;

class function TDelphiSemanticNameSites.AtTempInsertion(const aModel: TDelphiSemanticUnitModel;
  const aRoutineScopeId: string; const aMethodClassId: TDelphiSemanticGraphTypeId;
  const aInsertionLine: Integer): TDelphiSemanticNameSite;
begin
  Result := Source(aModel.UnitName, aModel.FileName, 'implementation', 'temp', aInsertionLine, 1);
  Result.RoutineScopeId := aRoutineScopeId;
  Result.ClassScopeId := aMethodClassId;
  Result.LocalCutoffLine := aInsertionLine;
end;

class function TDelphiSemanticNameSites.AtDeclaration(const aModel: TDelphiSemanticUnitModel;
  const aDeclaration: TDelphiSemanticDeclaration;
  const aClassScopeId: TDelphiSemanticGraphTypeId): TDelphiSemanticNameSite;
begin
  Result := Source(aModel.UnitName, aDeclaration.FileName, aDeclaration.SectionKind,
    'var', aDeclaration.Line, aDeclaration.Column);
  if Result.FileName = '' then
    Result.FileName := aModel.FileName;
  if aDeclaration.ScopeKind = 'routine' then
    Result.RoutineScopeId := aDeclaration.OwnerScopeId;
  Result.ClassScopeId := aClassScopeId;
end;

class function TDelphiSemanticNameSites.AtValueIdentity(
  const aDeclaration: TDelphiSemanticGraphDeclaration;
  const aUnitName: string): TDelphiSemanticNameSite;
begin
  Result := Source(aUnitName, aDeclaration.SourceRange.FileName, aDeclaration.SectionKind,
    'var', aDeclaration.SourceRange.Line, aDeclaration.SourceRange.Column);
  if aDeclaration.ScopeKind = 'routine' then
    Result.RoutineScopeId := aDeclaration.OwnerScopeId;
  Result.ClassScopeId := aDeclaration.OwnerDeclaredId;
end;

class function TDelphiSemanticNameSites.AtMember(const aModel: TDelphiSemanticUnitModel;
  const aMember: TDelphiSemanticMember;
  const aOwnerId: TDelphiSemanticGraphTypeId): TDelphiSemanticNameSite;
begin
  Result := Source(aModel.UnitName, aMember.FileName, '', 'member',
    aMember.Line, aMember.Column);
  if Result.FileName = '' then
    Result.FileName := aModel.FileName;
  for var lDeclaration in aModel.Declarations do
    if SameText(lDeclaration.Name, aMember.OwnerName) and
      SameText(lDeclaration.OwnerScopeId, aMember.OwnerScopeId) and
      ((aMember.OwnerSymbolId = '') or SameText(lDeclaration.SymbolId, aMember.OwnerSymbolId)) then
    begin
      Result.SectionKind := lDeclaration.SectionKind;
      Break;
    end;
  Result.ClassScopeId := aOwnerId;
end;

class function TDelphiSemanticNameSites.AtLocal(const aModel: TDelphiSemanticUnitModel;
  const aLocal: TDelphiSemanticLocal;
  const aClassScopeId: TDelphiSemanticGraphTypeId): TDelphiSemanticNameSite;
begin
  Result := Source(aModel.UnitName, aLocal.FileName, 'implementation', 'local',
    aLocal.Line, aLocal.Column);
  if Result.FileName = '' then
    Result.FileName := aModel.FileName;
  Result.RoutineScopeId := aLocal.RoutineScopeId;
  Result.ClassScopeId := aClassScopeId;
end;

class function TDelphiSemanticNameSites.AtParameter(const aModel: TDelphiSemanticUnitModel;
  const aRoutine: TDelphiSemanticRoutine; const aParameter: TDelphiSemanticParameter;
  const aClassScopeId: TDelphiSemanticGraphTypeId): TDelphiSemanticNameSite;
begin
  Result := Source(aModel.UnitName, aParameter.FileName, aRoutine.SectionKind, 'param',
    aParameter.Line, aParameter.Column);
  if Result.FileName = '' then
    Result.FileName := aModel.FileName;
  Result.RoutineScopeId := aRoutine.ParentScopeId;
  Result.ClassScopeId := aClassScopeId;
end;

class function TDelphiSemanticNameSites.AtTypeIdentity(
  const aIdentity: TDelphiSemanticTypeIdentity): TDelphiSemanticNameSite;
begin
  Result := Source(aIdentity.UnitName, aIdentity.SourceRange.FileName,
    aIdentity.SectionKind, 'alias', aIdentity.SourceRange.Line, aIdentity.SourceRange.Column);
  if aIdentity.ScopeKind = 'routine' then
    Result.RoutineScopeId := aIdentity.OwnerScopeId;
  Result.ClassScopeId := aIdentity.EnclosingTypeId;
  Result.ForwardPointerTarget := (aIdentity.CanonicalName <> '') and
    (aIdentity.CanonicalName[1] = '^');
end;

class function TDelphiSemanticNameSites.AtRoutineDeclaration(
  const aRoutine: TDelphiSemanticGraphRoutine;
  const aUnitName: string): TDelphiSemanticNameSite;
begin
  Result := Source(aUnitName, aRoutine.SourceRange.FileName, aRoutine.SectionKind,
    'routine', aRoutine.SourceRange.Line, aRoutine.SourceRange.Column);
  Result.RoutineScopeId := aRoutine.ParentScopeId;
end;

class function TDelphiSemanticNameSites.AtUnindexedHelper(
  const aUnit: TDelphiSemanticGraphUnit;
  const aHelper: TDelphiSemanticUnindexedHelperFact): TDelphiSemanticNameSite;
begin
  Result := Source(aUnit.UnitName, aHelper.FileName, aHelper.SectionKind,
    'helper-target', aHelper.Line, aHelper.Column);
  if Result.FileName = '' then
    Result.FileName := aUnit.FileName;
  if SameText(aHelper.ScopeKind, 'routine') then
    Result.RoutineScopeId := aHelper.OwnerScopeId;
end;

class function TDelphiSemanticNameSites.AtMetadata(const aUnitName,
  aOwnerTypeName: string): TDelphiSemanticNameSite;
begin
  Result := Default(TDelphiSemanticNameSite);
  Result.Kind := nskMetadata;
  Result.UnitName := aUnitName;
  Result.SectionKind := 'interface';
  Result.Origin := 'metadata:' + aOwnerTypeName;
end;

end.
