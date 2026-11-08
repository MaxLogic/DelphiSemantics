unit DelphiSemantics.Query;

interface

uses
  DelphiSemantics.Cache, DelphiSemantics.CompilerProfile, DelphiSemantics.Model,
  DelphiSemantics.Snapshot;

type
  TDelphiSemanticSymbolQueryContext = record
    UnitModel: TDelphiSemanticUnitModel;
    IndexedUnitModels: TArray<TDelphiSemanticUnitModel>;
    IndexedUnitSourceKinds: TArray<string>;
    CompilerProfile: TDelphiSemanticCompilerProfile;
    CacheMetrics: TDelphiSemanticCacheMetrics;
    ProjectSnapshot: IDelphiProjectSnapshotRef;
  end;

  TDelphiSemanticSymbolQueryResult = record
    Found: Boolean;
    Status: string;
    Name: string;
    Kind: string;
    TypeName: string;
    OwnerName: string;
    UnitName: string;
    SectionKind: string;
    Description: string;
    SourceKind: string;
    Confidence: string;
    Provenance: string;
    Signature: string;
    FileName: string;
    Line: Integer;
    Column: Integer;
    EndLine: Integer;
    EndColumn: Integer;
  end;

  TDelphiSemanticSymbolReferenceResult = record
    Name: string;
    UnitName: string;
    SourceKind: string;
    Confidence: string;
    Role: string;
    SectionKind: string;
    FileName: string;
    Line: Integer;
    Column: Integer;
    EndLine: Integer;
    EndColumn: Integer;
  end;

  TDelphiSemanticVisibleUnitScope = record
    UnitName: string;
    FileName: string;
    SourceKind: string;
  end;

  TDelphiSemanticSymbolQueryCacheStatus = record
    CacheFileName: string;
    CacheKind: string;
    CacheHits: Integer;
    CacheMisses: Integer;
    Invalidations: Integer;
    CompilerProfileName: string;
    CompilerProfileKey: string;
    IntrinsicCount: Integer;
    RtlSourceUnitCount: Integer;
  end;

  TDelphiSemanticSymbolQuery = record
  public
    class function DescribeOwnedMember(const aContext: TDelphiSemanticSymbolQueryContext;
      const aOwnerName, aName: string): TDelphiSemanticSymbolQueryResult; static;
    class function FindDefinitionAtPosition(const aContext: TDelphiSemanticSymbolQueryContext;
      const aFileName: string; const aLine, aColumn: Integer):
      TDelphiSemanticSymbolQueryResult; static;
    class function FindDefinitionByName(const aContext: TDelphiSemanticSymbolQueryContext;
      const aName: string): TDelphiSemanticSymbolQueryResult; static;
    class function FindTokenReferences(const aContext: TDelphiSemanticSymbolQueryContext;
      const aName: string; const aLimit: Integer): TArray<TDelphiSemanticSymbolReferenceResult>;
      static;
    class function GetCacheStatus(const aContext: TDelphiSemanticSymbolQueryContext):
      TDelphiSemanticSymbolQueryCacheStatus; static;
    class function GetVisibleUnitScopes(const aContext: TDelphiSemanticSymbolQueryContext):
      TArray<TDelphiSemanticVisibleUnitScope>; static;
    class function Search(const aContext: TDelphiSemanticSymbolQueryContext; const aName: string;
      const aLimit: Integer): TArray<TDelphiSemanticSymbolQueryResult>; static;
    class function SearchAllMatches(const aContext: TDelphiSemanticSymbolQueryContext;
      const aName: string; const aLimit: Integer): TArray<TDelphiSemanticSymbolQueryResult>;
      static;
  end;

implementation

uses
  System.Classes, System.Generics.Collections, System.IOUtils, System.StrUtils, System.SysUtils,
  DelphiSemantics.Model.Coordinates, DelphiSemantics.Model.Text,
  DelphiSemantics.Snapshot.PositionResolver, DelphiSemantics.Snapshot.QuerySupport,
  DelphiSemantics.Source;

function MakeNotFound(const aName: string): TDelphiSemanticSymbolQueryResult;
begin
  Result := Default(TDelphiSemanticSymbolQueryResult);
  Result.Found := False;
  Result.Status := 'not-found';
  Result.Name := aName;
  Result.Provenance := 'semantic-model';
end;

function MakeDescription(const aName, aTypeName: string): string;
begin
  if aTypeName <> '' then
    Result := aName + ': ' + aTypeName
  else
    Result := aName;
end;

procedure ClearUnknownPosition(var aResult: TDelphiSemanticSymbolQueryResult);
begin
  aResult.Line := 0;
  aResult.Column := 0;
  aResult.EndLine := 0;
  aResult.EndColumn := 0;
end;

procedure ApplyModelSymbolOrigin(const aModel: TDelphiSemanticUnitModel;
  const aFactKind: string; const aFactIndex: Integer;
  var aResult: TDelphiSemanticSymbolQueryResult);
var
  lOccurrence, lFound: TDelphiSemanticPhysicalSymbolOccurrence;
  lCount: Integer;
begin
  // A fact explicitly marked unknown must not acquire coordinates from another generation.
  if not SourcePositionKnown(aResult.Line, aResult.Column) then
  begin
    ClearUnknownPosition(aResult);
    Exit;
  end;
  if Length(aModel.IncludeFileNames) = 0 then
    Exit;
  lCount := 0;
  lFound := Default(TDelphiSemanticPhysicalSymbolOccurrence);
  if aModel.PhysicalSymbolOccurrencesAvailable then
    for lOccurrence in aModel.PhysicalSymbolOccurrences do
      if (lOccurrence.FactKind = aFactKind) and (lOccurrence.FactIndex = aFactIndex) and
        (lOccurrence.ParentFactIndex = -1) then
      begin
        Inc(lCount);
        lFound := lOccurrence;
      end;
  if (lCount = 1) and lFound.Verified and PhysicalSymbolFactMatches(lFound, aModel) and
    SourcePositionKnown(lFound.Line, lFound.Column) then
  begin
    aResult.FileName := FactSourceFileName(aModel.FileName, lFound.FileName);
    aResult.Line := lFound.Line;
    aResult.Column := lFound.Column;
    aResult.EndLine := lFound.EndLine;
    aResult.EndColumn := lFound.EndColumn;
  end else
    ClearUnknownPosition(aResult);
end;

function DeclarationResult(const aModel: TDelphiSemanticUnitModel;
  const aFactIndex: Integer; const aSourceKind: string):
  TDelphiSemanticSymbolQueryResult;
var
  lDeclaration: TDelphiSemanticDeclaration;
begin
  lDeclaration := aModel.Declarations[aFactIndex];
  Result := Default(TDelphiSemanticSymbolQueryResult);
  Result.Found := True;
  Result.Status := 'resolved';
  Result.Name := lDeclaration.Name;
  Result.Kind := lDeclaration.Kind;
  Result.TypeName := lDeclaration.TypeName;
  Result.OwnerName := aModel.UnitName;
  Result.UnitName := aModel.UnitName;
  Result.SectionKind := lDeclaration.SectionKind;
  Result.Description := MakeDescription(lDeclaration.Name, lDeclaration.TypeName);
  Result.SourceKind := aSourceKind;
  Result.Confidence := 'declaration-name-match';
  Result.Provenance := 'semantic-model';
  Result.FileName := FactSourceFileName(aModel.FileName, lDeclaration.FileName);
  Result.Line := lDeclaration.Line;
  Result.Column := lDeclaration.Column;
  Result.EndLine := lDeclaration.Line;
  Result.EndColumn := lDeclaration.Column + Length(lDeclaration.Name) - 1;
  ApplyModelSymbolOrigin(aModel, 'declaration', aFactIndex, Result);
end;

function MemberResult(const aModel: TDelphiSemanticUnitModel; const aFactIndex: Integer;
  const aSourceKind: string): TDelphiSemanticSymbolQueryResult;
var
  lMember: TDelphiSemanticMember;
begin
  lMember := aModel.Members[aFactIndex];
  Result := Default(TDelphiSemanticSymbolQueryResult);
  Result.Found := True;
  Result.Status := 'resolved';
  Result.Name := lMember.Name;
  Result.Kind := lMember.Kind;
  Result.TypeName := lMember.TypeName;
  Result.OwnerName := lMember.OwnerName;
  Result.UnitName := aModel.UnitName;
  Result.Description := MakeDescription(lMember.Name, lMember.TypeName);
  Result.SourceKind := aSourceKind;
  Result.Confidence := 'member-name-match';
  Result.Provenance := 'semantic-model';
  Result.Signature := lMember.Signature;
  Result.FileName := FactSourceFileName(aModel.FileName, lMember.FileName);
  Result.Line := lMember.Line;
  Result.Column := lMember.Column;
  Result.EndLine := lMember.Line;
  Result.EndColumn := lMember.Column + Length(lMember.Name) - 1;
  ApplyModelSymbolOrigin(aModel, 'member', aFactIndex, Result);
end;

function RoutineResult(const aModel: TDelphiSemanticUnitModel;
  const aFactIndex: Integer; const aSourceKind: string):
  TDelphiSemanticSymbolQueryResult;
var
  lRoutine: TDelphiSemanticRoutine;
begin
  lRoutine := aModel.Routines[aFactIndex];
  Result := Default(TDelphiSemanticSymbolQueryResult);
  Result.Found := True;
  Result.Status := 'resolved';
  Result.Name := lRoutine.Name;
  Result.Kind := 'routine';
  Result.TypeName := lRoutine.ReturnType;
  Result.OwnerName := lRoutine.OwnerName;
  Result.UnitName := aModel.UnitName;
  Result.SectionKind := lRoutine.SectionKind;
  Result.Description := MakeDescription(lRoutine.Name, lRoutine.ReturnType);
  Result.SourceKind := aSourceKind;
  Result.Confidence := 'routine-name-match';
  Result.Provenance := 'semantic-model';
  Result.Signature := lRoutine.Signature;
  Result.FileName := FactSourceFileName(aModel.FileName, lRoutine.FileName);
  Result.Line := lRoutine.Line;
  Result.Column := lRoutine.Column;
  Result.EndLine := lRoutine.Line;
  Result.EndColumn := lRoutine.Column + Length(lRoutine.Name) - 1;
  ApplyModelSymbolOrigin(aModel, 'routine', aFactIndex, Result);
end;

function LocalResult(const aModel: TDelphiSemanticUnitModel; const aFactIndex: Integer;
  const aSourceKind: string): TDelphiSemanticSymbolQueryResult;
var
  lLocal: TDelphiSemanticLocal;
begin
  lLocal := aModel.Locals[aFactIndex];
  Result := Default(TDelphiSemanticSymbolQueryResult);
  Result.Found := True;
  Result.Status := 'resolved';
  Result.Name := lLocal.Name;
  Result.Kind := lLocal.Kind;
  Result.TypeName := lLocal.TypeName;
  Result.OwnerName := lLocal.RoutineName;
  Result.UnitName := aModel.UnitName;
  Result.Description := MakeDescription(lLocal.Name, lLocal.TypeName);
  Result.SourceKind := aSourceKind;
  Result.Confidence := 'local-name-match';
  Result.Provenance := 'semantic-model';
  Result.FileName := FactSourceFileName(aModel.FileName, lLocal.FileName);
  Result.Line := lLocal.Line;
  Result.Column := lLocal.Column;
  Result.EndLine := lLocal.Line;
  Result.EndColumn := lLocal.Column + Length(lLocal.Name) - 1;
  ApplyModelSymbolOrigin(aModel, 'local', aFactIndex, Result);
end;

function IntrinsicResult(const aSymbol: TDelphiSemanticIntrinsicSymbol):
  TDelphiSemanticSymbolQueryResult;
begin
  Result := Default(TDelphiSemanticSymbolQueryResult);
  Result.Found := True;
  Result.Status := 'resolved';
  Result.Name := aSymbol.Name;
  Result.Kind := aSymbol.Kind;
  Result.TypeName := aSymbol.TypeName;
  Result.OwnerName := aSymbol.OwnerName;
  Result.UnitName := aSymbol.OwnerName;
  Result.Description := MakeDescription(aSymbol.Name, aSymbol.TypeName);
  Result.SourceKind := 'compiler-profile';
  Result.Confidence := 'intrinsic-name-match';
  Result.Provenance := 'semantic-model';
  Result.Signature := aSymbol.Signature;
end;

function UnitResult(const aModel: TDelphiSemanticUnitModel; const aSourceKind: string):
  TDelphiSemanticSymbolQueryResult;
begin
  Result := Default(TDelphiSemanticSymbolQueryResult);
  Result.Found := True;
  Result.Status := 'resolved';
  Result.Name := aModel.UnitName;
  Result.Kind := 'unit';
  Result.UnitName := aModel.UnitName;
  Result.Description := aModel.UnitName;
  Result.SourceKind := aSourceKind;
  Result.Confidence := 'exact';
  Result.Provenance := 'semantic-model';
  Result.FileName := aModel.FileName;
  Result.Line := 1;
  Result.Column := 1;
  Result.EndLine := 1;
  Result.EndColumn := Length(aModel.UnitName) + 5;
end;

function SnapshotSymbolResult(const aSnapshot: TDelphiProjectSnapshot;
  const aUnit: TUnitSnapshot; const aSymbol: TSemanticSymbolFact; const aConfidence: string):
  TDelphiSemanticSymbolQueryResult;
var
  lKind: string;
begin
  Result := Default(TDelphiSemanticSymbolQueryResult);
  lKind := SnapshotPublicSymbolKind(SnapshotText(aSnapshot, aSymbol.KindId));
  Result.Found := True;
  Result.Status := 'resolved';
  Result.Name := SnapshotText(aSnapshot, aSymbol.NameId);
  Result.Kind := lKind;
  Result.TypeName := SnapshotText(aSnapshot, aSymbol.TypeId);
  Result.OwnerName := SnapshotSymbolOwnerName(aSnapshot, aSymbol, lKind);
  Result.UnitName := SnapshotText(aSnapshot, aUnit.UnitNameId);
  Result.SectionKind := SnapshotText(aSnapshot, aSymbol.SectionKindId);
  Result.Description := MakeDescription(Result.Name, Result.TypeName);
  Result.SourceKind := SnapshotText(aSnapshot, aSymbol.SourceKindId);
  if Result.SourceKind = '' then
    Result.SourceKind := 'project-snapshot';
  Result.Confidence := aConfidence;
  Result.Provenance := 'project-snapshot';
  Result.Signature := SnapshotText(aSnapshot, aSymbol.SignatureId);
  Result.FileName := SnapshotFactFileName(aSnapshot, aUnit, aSymbol.FileId);
  Result.Line := aSymbol.Line;
  Result.Column := aSymbol.Column;
  Result.EndLine := SnapshotEndLine(aSymbol.Line, aSymbol.EndLine);
  Result.EndColumn := SnapshotEndColumn(aSymbol.Column, Result.Name, aSymbol.EndColumn);
  ApplySnapshotSymbolOrigin(aSnapshot, aUnit, aSymbol, Result.FileName, Result.Line,
    Result.Column, Result.EndLine, Result.EndColumn);
end;

function SnapshotReferenceResult(const aSnapshot: TDelphiProjectSnapshot;
  const aUnit: TUnitSnapshot; const aReference: TSemanticReferenceFact):
  TDelphiSemanticSymbolReferenceResult;
begin
  Result := Default(TDelphiSemanticSymbolReferenceResult);
  Result.Name := SnapshotText(aSnapshot, aReference.NameId);
  Result.UnitName := SnapshotText(aSnapshot, aUnit.UnitNameId);
  Result.SourceKind := SnapshotText(aSnapshot, aReference.SourceKindId);
  if Result.SourceKind = '' then
    Result.SourceKind := 'project-snapshot';
  Result.Confidence := 'snapshot-index';
  Result.Role := SnapshotText(aSnapshot, aReference.ClassificationId);
  if Result.Role = '' then
    Result.Role := 'token';
  Result.SectionKind := SnapshotText(aSnapshot, aReference.SectionKindId);
  if Result.SectionKind = '' then
    Result.SectionKind := 'implementation';
  Result.FileName := SnapshotFactFileName(aSnapshot, aUnit, aReference.FileId);
  Result.Line := aReference.Line;
  Result.Column := aReference.Column;
  Result.EndLine := SnapshotEndLine(aReference.Line, aReference.EndLine);
  Result.EndColumn := SnapshotEndColumn(aReference.Column, Result.Name, aReference.EndColumn);
  if not SourcePositionKnown(aReference.Line, aReference.Column) then
  begin
    Result.Line := 0;
    Result.Column := 0;
    Result.EndLine := 0;
    Result.EndColumn := 0;
  end;
end;

function TryExtractIdentifierAtColumn(const aLineText: string; const aColumn: Integer;
  out aToken: string): Boolean;
var
  lIndex: Integer;
  lLeft: Integer;
  lRight: Integer;
begin
  aToken := '';
  if (aLineText = '') or (aColumn <= 0) or (aColumn > Length(aLineText) + 1) then
    Exit(False);

  lIndex := aColumn;
  if lIndex > Length(aLineText) then
    Dec(lIndex);
  if not IsIdentifierChar(aLineText[lIndex]) then
  begin
    if (lIndex > 1) and IsIdentifierChar(aLineText[lIndex - 1]) then
      Dec(lIndex)
    else
      Exit(False);
  end;

  lLeft := lIndex;
  while (lLeft > 1) and IsIdentifierChar(aLineText[lLeft - 1]) do
    Dec(lLeft);

  lRight := lIndex;
  while (lRight < Length(aLineText)) and IsIdentifierChar(aLineText[lRight + 1]) do
    Inc(lRight);

  aToken := Copy(aLineText, lLeft, lRight - lLeft + 1);
  Result := aToken <> '';
end;

function TryReadLineFromSourceText(const aSourceText: string; const aLine: Integer;
  out aLineText: string): Boolean;
var
  lLines: TStringList;
begin
  aLineText := '';
  if (aSourceText = '') or (aLine <= 0) then
    Exit(False);

  lLines := TStringList.Create;
  try
    lLines.Text := aSourceText;
    if aLine > lLines.Count then
      Exit(False);
    aLineText := lLines[aLine - 1];
    Result := True;
  finally
    lLines.Free;
  end;
end;

function TryFindTypeForLocal(const aModel: TDelphiSemanticUnitModel; const aName: string;
  out aTypeName: string): Boolean;
begin
  for var lLocalIndex := 0 to High(aModel.Locals) do
    if SameText(aModel.Locals[lLocalIndex].Name, aName) then
    begin
      aTypeName := aModel.Locals[lLocalIndex].TypeName;
      Exit(True);
    end;

  aTypeName := '';
  Result := False;
end;

function TryFindLocalAtPosition(const aModel: TDelphiSemanticUnitModel; const aSourceKind,
  aName: string; const aLine, aColumn: Integer; out aResult: TDelphiSemanticSymbolQueryResult):
  Boolean;
begin
  for var lLocalIndex := 0 to High(aModel.Locals) do
    if SameText(aModel.Locals[lLocalIndex].Name, aName) and
      (aModel.Locals[lLocalIndex].Line = aLine) and
      (aColumn >= aModel.Locals[lLocalIndex].Column) and
      (aColumn <= aModel.Locals[lLocalIndex].Column + Length(aModel.Locals[lLocalIndex].Name)) then
    begin
      aResult := LocalResult(aModel, lLocalIndex, aSourceKind);
      Exit(True);
    end;

  aResult := Default(TDelphiSemanticSymbolQueryResult);
  Result := False;
end;

function TryFindLocalReferenceAtPosition(const aModel: TDelphiSemanticUnitModel; const aSourceKind,
  aName: string; const aLine, aColumn: Integer; out aResult: TDelphiSemanticSymbolQueryResult):
  Boolean;
var
  lReference: TDelphiSemanticReference;
begin
  for lReference in aModel.References do
    if SameText(lReference.Name, aName) and (lReference.RoutineName <> '') and
      (lReference.Line = aLine) and (aColumn >= lReference.Column) and
      (aColumn <= lReference.EndColumn + 1) then
      for var lLocalIndex := 0 to High(aModel.Locals) do
        if SameText(aModel.Locals[lLocalIndex].RoutineName, lReference.RoutineName) and
          SameText(aModel.Locals[lLocalIndex].Name, aName) then
        begin
          aResult := LocalResult(aModel, lLocalIndex, aSourceKind);
          Exit(True);
        end;

  aResult := Default(TDelphiSemanticSymbolQueryResult);
  Result := False;
end;

function TryFindMemberAtPosition(const aModel: TDelphiSemanticUnitModel; const aSourceKind,
  aName: string; const aLine, aColumn: Integer; out aResult: TDelphiSemanticSymbolQueryResult):
  Boolean;
begin
  for var lMemberIndex := 0 to High(aModel.Members) do
    if SameText(aModel.Members[lMemberIndex].Name, aName) and (aModel.Members[lMemberIndex].Line = aLine) and
      (aColumn >= aModel.Members[lMemberIndex].Column) and
      (aColumn <= aModel.Members[lMemberIndex].Column +
        Length(aModel.Members[lMemberIndex].Name)) then
    begin
      aResult := MemberResult(aModel, lMemberIndex, aSourceKind);
      Exit(True);
    end;

  aResult := Default(TDelphiSemanticSymbolQueryResult);
  Result := False;
end;

function TryFindMemberReferenceAtPosition(const aModel: TDelphiSemanticUnitModel;
  const aSourceKind, aName: string; const aLine, aColumn: Integer;
  out aResult: TDelphiSemanticSymbolQueryResult): Boolean;
var
  lReference: TDelphiSemanticReference;
begin
  for lReference in aModel.References do
    if SameText(lReference.Name, aName) and (lReference.Line = aLine) and
      (aColumn >= lReference.Column - 1) and (aColumn <= lReference.EndColumn + 1) then
      for var lMemberIndex := 0 to High(aModel.Members) do
        if SameText(aModel.Members[lMemberIndex].Name, aName) then
        begin
          aResult := MemberResult(aModel, lMemberIndex, aSourceKind);
          Exit(True);
        end;

  aResult := Default(TDelphiSemanticSymbolQueryResult);
  Result := False;
end;

function SameFileName(const aLeft, aRight: string): Boolean;
begin
  if (aLeft = '') or (aRight = '') then
    Exit(False);
  try
    Result := SameText(TPath.GetFullPath(aLeft), TPath.GetFullPath(aRight));
  except
    Result := SameText(aLeft, aRight);
  end;
end;

function NameMatchesQuery(const aName, aQuery: string; const aAllowSubstring: Boolean): Boolean;
begin
  Result := SameText(aName, aQuery) or (aAllowSubstring and ContainsText(aName, aQuery));
end;

function PhysicalPositionMatches(const aFile, aQueryFile: string;
  const aLine, aColumn, aEndLine, aEndColumn, aQueryLine, aQueryColumn: Integer): Boolean;
begin
  Result := SameFileName(aFile, aQueryFile) and SourcePositionKnown(aLine, aColumn) and
    (aQueryLine >= aLine) and (aQueryLine <= aEndLine) and
    ((aQueryLine > aLine) or (aQueryColumn >= aColumn)) and
    ((aQueryLine < aEndLine) or (aQueryColumn <= aEndColumn));
end;

function ModelOccurrenceResult(const aModel: TDelphiSemanticUnitModel;
  const aOccurrence: TDelphiSemanticPhysicalSymbolOccurrence; const aSourceKind: string):
  TDelphiSemanticSymbolQueryResult;
begin
  Result := MakeNotFound(aOccurrence.Name);
  if not aOccurrence.Verified or not PhysicalSymbolFactMatches(aOccurrence, aModel) then
    Exit;
  if aOccurrence.FactKind = 'declaration' then
    Result := DeclarationResult(aModel, aOccurrence.FactIndex, aSourceKind)
  else if aOccurrence.FactKind = 'member' then
    Result := MemberResult(aModel, aOccurrence.FactIndex, aSourceKind)
  else if aOccurrence.FactKind = 'routine' then
    Result := RoutineResult(aModel, aOccurrence.FactIndex, aSourceKind)
  else if aOccurrence.FactKind = 'local' then
    Result := LocalResult(aModel, aOccurrence.FactIndex, aSourceKind);
end;

function TryPhysicalModelPosition(const aModel: TDelphiSemanticUnitModel;
  const aSourceKind, aFileName: string; const aLine, aColumn: Integer;
  out aResult: TDelphiSemanticSymbolQueryResult): Boolean;
var
  lOccurrence: TDelphiSemanticPhysicalSymbolOccurrence;
  lReference: TDelphiSemanticPhysicalReferenceOccurrence;
  lCandidate: TDelphiSemanticSymbolQueryResult;
  lCount: Integer;
begin
  aResult := MakeNotFound('');
  lCount := 0;
  if not aModel.PhysicalSymbolOccurrencesAvailable then
    Exit(False);
  for lOccurrence in aModel.PhysicalSymbolOccurrences do
    if PhysicalPositionMatches(lOccurrence.FileName, aFileName, lOccurrence.Line,
      lOccurrence.Column, lOccurrence.EndLine, lOccurrence.EndColumn, aLine, aColumn) then
    begin
      lCandidate := ModelOccurrenceResult(aModel, lOccurrence, aSourceKind);
      if lCandidate.Found then
      begin
        Inc(lCount);
        aResult := lCandidate;
      end;
    end;
  if lCount <> 0 then
    Exit(lCount = 1);
  if aModel.PhysicalReferenceOccurrencesAvailable then
    for lReference in aModel.PhysicalReferenceOccurrences do
      if lReference.Verified and (lReference.RoutineScopeId <> '') and
        PhysicalPositionMatches(lReference.FileName, aFileName, lReference.Line,
          lReference.Column, lReference.EndLine, lReference.EndColumn, aLine, aColumn) then
        for lOccurrence in aModel.PhysicalSymbolOccurrences do
          if (lOccurrence.FactKind = 'local') and
            (lOccurrence.RoutineScopeId = lReference.RoutineScopeId) and
            SameText(lOccurrence.Name, lReference.Name) then
          begin
            lCandidate := ModelOccurrenceResult(aModel, lOccurrence, aSourceKind);
            if lCandidate.Found then
            begin
              Inc(lCount);
              aResult := lCandidate;
            end;
          end;
  Result := lCount = 1;
end;

function IndexedSourceKind(const aContext: TDelphiSemanticSymbolQueryContext;
  const aIndex: Integer): string;
begin
  if (aIndex >= 0) and (aIndex < Length(aContext.IndexedUnitSourceKinds)) and
    (aContext.IndexedUnitSourceKinds[aIndex] <> '') then
    Exit(aContext.IndexedUnitSourceKinds[aIndex]);

  Result := 'rtl-source';
end;

function ModelContainsFile(const aModel: TDelphiSemanticUnitModel;
  const aFileName: string): Boolean;
var
  lSource: TDelphiSemanticSourceText;
  lOccurrence: TDelphiSemanticPhysicalSymbolOccurrence;
begin
  if SameFileName(aModel.FileName, aFileName) then
    Exit(True);
  if (aModel.SourceObservations <> nil) and aModel.SourceObservations.TryFind(aFileName, lSource) then
    Exit(True);
  for lOccurrence in aModel.PhysicalSymbolOccurrences do
    if SameFileName(lOccurrence.FileName, aFileName) then
      Exit(True);
  Result := False;
end;

function TryFindModelForFile(const aContext: TDelphiSemanticSymbolQueryContext;
  const aFileName: string; out aModel: TDelphiSemanticUnitModel; out aSourceKind: string):
  Boolean;
var
  i: Integer;
  lModel: TDelphiSemanticUnitModel;
  lFound: Boolean;
begin
  aModel := Default(TDelphiSemanticUnitModel);
  aSourceKind := '';
  if SameFileName(aContext.UnitModel.FileName, aFileName) then
  begin
    aModel := aContext.UnitModel;
    aSourceKind := 'project-source';
    Exit(True);
  end;
  for i := 0 to High(aContext.IndexedUnitModels) do
    if SameFileName(aContext.IndexedUnitModels[i].FileName, aFileName) then
    begin
      aModel := aContext.IndexedUnitModels[i];
      aSourceKind := IndexedSourceKind(aContext, i);
      Exit(True);
    end;

  // An include position has no unique unit scope when several units own it.
  lFound := ModelContainsFile(aContext.UnitModel, aFileName);
  if lFound then
  begin
    aModel := aContext.UnitModel;
    aSourceKind := 'project-source';
  end;
  for i := 0 to High(aContext.IndexedUnitModels) do
  begin
    lModel := aContext.IndexedUnitModels[i];
    if not ModelContainsFile(lModel, aFileName) then
      Continue;
    if lFound and not SameFileName(aModel.FileName, lModel.FileName) then
    begin
      aModel := Default(TDelphiSemanticUnitModel);
      aSourceKind := '';
      Exit(False);
    end;
    if not lFound then
    begin
      aModel := lModel;
      aSourceKind := IndexedSourceKind(aContext, i);
      lFound := True;
    end;
  end;
  Result := lFound;
end;

function TryReadContextLine(const aContext: TDelphiSemanticSymbolQueryContext;
  const aFileName: string; const aLine: Integer; out aLineText: string): Boolean;
var
  i: Integer;
  lModel: TDelphiSemanticUnitModel;
  lSource: TDelphiSemanticSourceText;
  lSourceKind: string;
  lSnapshot: TDelphiProjectSnapshot;
  lUnit: TUnitSnapshot;
  lCaptured: TSemanticCapturedSourceFact;
  lFileId: TSemanticStringId;
  lReason: string;
begin
  aLineText := '';
  lSnapshot := ContextProjectSnapshot(aContext);
  if lSnapshot <> nil then
  begin
    if not lSnapshot.TryFindStringId(aFileName, lFileId) or
      lSnapshot.TryCapturedSourceConflict(lFileId, lReason) then
      Exit(False);
    for i := 0 to lSnapshot.UnitCount - 1 do
    begin
      lUnit := lSnapshot.UnitByIndex(i);
      if lUnit.CapturedSourcesAvailable and lUnit.TryFindCapturedSource(lFileId, lCaptured) and
        (lCaptured.Status in [cCapturedSourceText, cCapturedSourceEmpty]) then
        Exit(TryReadLineFromSourceText(lSnapshot.ExactTextOf(lCaptured.TextId), aLine, aLineText));
    end;
    Exit(False);
  end;
  if TryFindModelForFile(aContext, aFileName, lModel, lSourceKind) then
  begin
    if SameFileName(lModel.FileName, aFileName) then
      Exit(TryReadLineFromSourceText(lModel.SourceText, aLine, aLineText));
    if (lModel.SourceObservations <> nil) and lModel.SourceObservations.TryFind(aFileName, lSource) then
      Exit(TryReadLineFromSourceText(lSource.Text, aLine, aLineText));
    Exit(False);
  end;
  // Missing captured evidence cannot be replaced by the current filesystem.
  Result := False;
end;

function FindDefinitionInModel(const aModel: TDelphiSemanticUnitModel; const aSourceKind,
  aName: string): TDelphiSemanticSymbolQueryResult;
begin
  for var lDeclarationIndex := 0 to High(aModel.Declarations) do
    if SameText(aModel.Declarations[lDeclarationIndex].Name, aName) then
      Exit(DeclarationResult(aModel, lDeclarationIndex, aSourceKind));

  for var lRoutineIndex := 0 to High(aModel.Routines) do
    if SameText(aModel.Routines[lRoutineIndex].Name, aName) then
      Exit(RoutineResult(aModel, lRoutineIndex, aSourceKind));

  for var lMemberIndex := 0 to High(aModel.Members) do
    if SameText(aModel.Members[lMemberIndex].Name, aName) then
      Exit(MemberResult(aModel, lMemberIndex, aSourceKind));

  Result := MakeNotFound(aName);
end;

procedure AddResult(const aResults: TList<TDelphiSemanticSymbolQueryResult>;
  const aResult: TDelphiSemanticSymbolQueryResult; const aLimit: Integer);
begin
  if not aResult.Found then
    Exit;
  if (aLimit > 0) and (aResults.Count >= aLimit) then
    Exit;
  aResults.Add(aResult);
end;

function ResultLimitReached(const aResults: TList<TDelphiSemanticSymbolQueryResult>;
  const aLimit: Integer): Boolean;
begin
  Result := (aLimit > 0) and (aResults.Count >= aLimit);
end;

function TrySnapshotSymbolResultByName(const aSnapshot: TDelphiProjectSnapshot;
  const aName: string; out aResult: TDelphiSemanticSymbolQueryResult): Boolean;
var
  i: Integer;
  lHighIndex: Integer;
  lLowIndex: Integer;
  lNameId: TSemanticStringId;
  lSymbol: TSemanticSymbolFact;
  lSymbolRef: TSemanticSymbolRef;
  lUnit: TUnitSnapshot;
begin
  if (aSnapshot = nil) or not aSnapshot.TryFindStringId(aName, lNameId) then
  begin
    aResult := MakeNotFound(aName);
    Exit(False);
  end;
  if not aSnapshot.TrySymbolsByName(lNameId, lLowIndex, lHighIndex) then
  begin
    aResult := MakeNotFound(aName);
    Exit(False);
  end;

  for i := lLowIndex to lHighIndex do
  begin
    lSymbolRef := aSnapshot.SymbolRefByNameIndex(i);
    if not aSnapshot.TryFindUnitById(lSymbolRef.UnitId, lUnit) then
      Continue;
    lSymbol := lUnit.SymbolById(lSymbolRef.SymbolId);
    if not SnapshotSymbolVisibleToPublicNameQuery(aSnapshot, lSymbol) then
      Continue;
    aResult := SnapshotSymbolResult(aSnapshot, lUnit, lSymbol, 'snapshot-name-match');
    Exit(True);
  end;

  aResult := MakeNotFound(aName);
  Result := False;
end;

function SnapshotHasExactSymbolMatch(const aContext: TDelphiSemanticSymbolQueryContext;
  const aName: string): Boolean;
var
  i: Integer;
  lHighIndex: Integer;
  lIntrinsic: TDelphiSemanticIntrinsicSymbol;
  lLowIndex: Integer;
  lNameId: TSemanticStringId;
  lSnapshot: TDelphiProjectSnapshot;
  lSymbol: TSemanticSymbolFact;
  lSymbolRef: TSemanticSymbolRef;
  lUnit: TUnitSnapshot;
begin
  lSnapshot := ContextProjectSnapshot(aContext);
  if (lSnapshot <> nil) and lSnapshot.TryFindStringId(aName, lNameId) and
    lSnapshot.TrySymbolsByName(lNameId, lLowIndex, lHighIndex) then
    for i := lLowIndex to lHighIndex do
    begin
      lSymbolRef := lSnapshot.SymbolRefByNameIndex(i);
      if not lSnapshot.TryFindUnitById(lSymbolRef.UnitId, lUnit) then
        Continue;
      lSymbol := lUnit.SymbolById(lSymbolRef.SymbolId);
      if SnapshotSymbolVisibleToPublicNameQuery(lSnapshot, lSymbol) then
        Exit(True);
    end;

  for lIntrinsic in aContext.CompilerProfile.IntrinsicSymbols do
    if SameText(lIntrinsic.Name, aName) then
      Exit(True);

  Result := False;
end;

function SnapshotSearch(const aContext: TDelphiSemanticSymbolQueryContext; const aName: string;
  const aLimit: Integer; const aAllowSubstring: Boolean):
  TArray<TDelphiSemanticSymbolQueryResult>;
var
  i: Integer;
  lIntrinsic: TDelphiSemanticIntrinsicSymbol;
  lResult: TDelphiSemanticSymbolQueryResult;
  lResults: TList<TDelphiSemanticSymbolQueryResult>;
  lSnapshot: TDelphiProjectSnapshot;
  lSymbol: TSemanticSymbolFact;
  lSymbolName: string;
  lSymbolRef: TSemanticSymbolRef;
  lUnit: TUnitSnapshot;
  lUnitIndex: Integer;
  lHighIndex: Integer;
  lLowIndex: Integer;
  lNameId: TSemanticStringId;
begin
  lResults := TList<TDelphiSemanticSymbolQueryResult>.Create;
  try
    lSnapshot := ContextProjectSnapshot(aContext);
    if lSnapshot <> nil then
    begin
      if (not aAllowSubstring) and lSnapshot.TryFindStringId(aName, lNameId) and
        lSnapshot.TrySymbolsByName(lNameId, lLowIndex, lHighIndex) then
      begin
        for i := lLowIndex to lHighIndex do
        begin
          lSymbolRef := lSnapshot.SymbolRefByNameIndex(i);
          if not lSnapshot.TryFindUnitById(lSymbolRef.UnitId, lUnit) then
            Continue;
          lSymbol := lUnit.SymbolById(lSymbolRef.SymbolId);
          if not SnapshotSymbolVisibleToPublicNameQuery(lSnapshot, lSymbol) then
            Continue;
          lSymbolName := SnapshotText(lSnapshot, lSymbol.NameId);
          if NameMatchesQuery(lSymbolName, aName, aAllowSubstring) then
          begin
            lResult := SnapshotSymbolResult(lSnapshot, lUnit, lSymbol, 'snapshot-name-match');
            AddResult(lResults, lResult, aLimit);
            if ResultLimitReached(lResults, aLimit) then
              Break;
          end;
        end;
      end else
      begin
        for lUnitIndex := 0 to lSnapshot.UnitCount - 1 do
        begin
          lUnit := lSnapshot.UnitByIndex(lUnitIndex);
          for i := 1 to lUnit.SymbolCount do
          begin
            lSymbol := lUnit.SymbolById(TSemanticSymbolId(i));
            if not SnapshotSymbolVisibleToPublicNameQuery(lSnapshot, lSymbol) then
              Continue;
            lSymbolName := SnapshotText(lSnapshot, lSymbol.NameId);
            if NameMatchesQuery(lSymbolName, aName, aAllowSubstring) then
            begin
              lResult := SnapshotSymbolResult(lSnapshot, lUnit, lSymbol, 'snapshot-name-match');
              AddResult(lResults, lResult, aLimit);
              if ResultLimitReached(lResults, aLimit) then
                Break;
            end;
          end;
          if ResultLimitReached(lResults, aLimit) then
            Break;
        end;
      end;
    end;

    for lIntrinsic in aContext.CompilerProfile.IntrinsicSymbols do
    begin
      if ResultLimitReached(lResults, aLimit) then
        Break;
      if NameMatchesQuery(lIntrinsic.Name, aName, aAllowSubstring) then
        AddResult(lResults, IntrinsicResult(lIntrinsic), aLimit);
    end;

    Result := lResults.ToArray;
  finally
    lResults.Free;
  end;
end;

function SnapshotTokenReferences(const aSnapshot: TDelphiProjectSnapshot; const aName: string;
  const aLimit: Integer): TArray<TDelphiSemanticSymbolReferenceResult>;
var
  i, j, lLowIndex, lHighIndex: Integer;
  lNameId: TSemanticStringId;
  lReferenceRef: TSemanticReferenceRef;
  lHaveLegacy: Boolean;
  lReference: TSemanticReferenceFact;
  lOccurrence: TSemanticPhysicalReferenceOccurrence;
  lResult: TDelphiSemanticSymbolReferenceResult;
  lResults: TList<TDelphiSemanticSymbolReferenceResult>;
  lUnit: TUnitSnapshot;
begin
  lResults := TList<TDelphiSemanticSymbolReferenceResult>.Create;
  try
    if not aSnapshot.TryFindStringId(aName, lNameId) then
      Exit(nil);
    lHaveLegacy := aSnapshot.TryReferencesByName(lNameId, lLowIndex, lHighIndex);
    for i := 0 to aSnapshot.UnitCount - 1 do
    begin
      lUnit := aSnapshot.UnitByIndex(i);
      if lUnit.PhysicalReferenceOccurrencesAvailable and lUnit.HasIncludes then
      begin
        for j := 0 to lUnit.PhysicalReferenceOccurrenceCount - 1 do
        begin
          lOccurrence := lUnit.PhysicalReferenceOccurrenceByIndex(j);
          if (lOccurrence.NameId <> lNameId) or
            ((aLimit > 0) and (lResults.Count >= aLimit)) then
            Continue;
          lReference := Default(TSemanticReferenceFact);
          lReference.NameId := lOccurrence.NameId;
          lReference.FileId := lOccurrence.FileId;
          lReference.RoutineId := lOccurrence.RoutineNameId;
          lReference.RoutineScopeId := lOccurrence.RoutineScopeId;
          lReference.ClassificationId := lOccurrence.RoleId;
          if lOccurrence.Verified then
          begin
            lReference.Line := lOccurrence.Line;
            lReference.Column := lOccurrence.Column;
            lReference.EndLine := lOccurrence.EndLine;
            lReference.EndColumn := lOccurrence.EndColumn;
          end;
          lResult := SnapshotReferenceResult(aSnapshot, lUnit, lReference);
          lResults.Add(lResult);
        end;
      end else if lHaveLegacy then
        for j := lLowIndex to lHighIndex do
        begin
          lReferenceRef := aSnapshot.ReferenceRefByNameIndex(j);
          if (lReferenceRef.UnitId <> lUnit.UnitId) or
            ((aLimit > 0) and (lResults.Count >= aLimit)) then
            Continue;
          lReference := lUnit.ReferenceById(lReferenceRef.ReferenceId);
          if lReference.FileId <> 0 then
          begin
            lReference.Line := 0;
            lReference.Column := 0;
            lReference.EndLine := 0;
            lReference.EndColumn := 0;
          end;
          lResults.Add(SnapshotReferenceResult(aSnapshot, lUnit, lReference));
        end;
    end;
    Result := lResults.ToArray;
  finally
    lResults.Free;
  end;
end;

class function TDelphiSemanticSymbolQuery.DescribeOwnedMember(
  const aContext: TDelphiSemanticSymbolQueryContext; const aOwnerName, aName: string):
  TDelphiSemanticSymbolQueryResult;
var
  i: Integer;
  lHighIndex: Integer;
  lLowIndex: Integer;
  lModel: TDelphiSemanticUnitModel;
  lNameId: TSemanticStringId;
  lOwnerNameId: TSemanticStringId;
  lSnapshot: TDelphiProjectSnapshot;
  lSymbol: TSemanticSymbolFact;
  lSymbolRef: TSemanticSymbolRef;
  lUnit: TUnitSnapshot;
begin
  lSnapshot := ContextProjectSnapshot(aContext);
  if lSnapshot <> nil then
  begin
    if lSnapshot.TryFindStringId(aOwnerName, lOwnerNameId) and
      lSnapshot.TryFindStringId(aName, lNameId) and
      lSnapshot.TryFindMembers(lOwnerNameId, lNameId, lLowIndex, lHighIndex) then
    begin
      for i := lLowIndex to lHighIndex do
      begin
        lSymbolRef := lSnapshot.MemberRefByOwnerAndNameIndex(i);
        if not lSnapshot.TryFindUnitById(lSymbolRef.UnitId, lUnit) then
          Continue;
        lSymbol := lUnit.SymbolById(lSymbolRef.SymbolId);
        Exit(SnapshotSymbolResult(lSnapshot, lUnit, lSymbol, 'snapshot-member-match'));
      end;
    end;
    Exit(MakeNotFound(aName));
  end;

  for var lMemberIndex := 0 to High(aContext.UnitModel.Members) do
    if SameText(aContext.UnitModel.Members[lMemberIndex].OwnerName, aOwnerName) and
      SameText(aContext.UnitModel.Members[lMemberIndex].Name, aName) then
      Exit(MemberResult(aContext.UnitModel, lMemberIndex, 'project-source'));

  for i := 0 to High(aContext.IndexedUnitModels) do
  begin
    lModel := aContext.IndexedUnitModels[i];
    for var lMemberIndex := 0 to High(lModel.Members) do
      if SameText(lModel.Members[lMemberIndex].OwnerName, aOwnerName) and SameText(lModel.Members[lMemberIndex].Name, aName) then
        Exit(MemberResult(lModel, lMemberIndex, IndexedSourceKind(aContext, i)));
  end;

  Result := MakeNotFound(aName);
end;

class function TDelphiSemanticSymbolQuery.FindDefinitionAtPosition(
  const aContext: TDelphiSemanticSymbolQueryContext; const aFileName: string;
  const aLine, aColumn: Integer): TDelphiSemanticSymbolQueryResult;
var
  lPositionResolution: TDelphiSemanticSnapshotPositionResolution;
  lResult: TDelphiSemanticSymbolQueryResult;
  lLineText: string;
  lModel: TDelphiSemanticUnitModel;
  lSnapshot: TDelphiProjectSnapshot;
  lSourceKind: string;
  lToken: string;
  lTypeName: string;
  lUnitId: TSemanticUnitId;
begin
  lSnapshot := ContextProjectSnapshot(aContext);
  if (lSnapshot <> nil) and TryResolveSnapshotPosition(lSnapshot, aFileName, aLine, aColumn,
    '', lPositionResolution) then
    Exit(SnapshotSymbolResult(lSnapshot, lPositionResolution.SymbolUnit,
      lPositionResolution.Symbol, lPositionResolution.Status));

  if (lSnapshot = nil) and TryFindModelForFile(aContext, aFileName, lModel, lSourceKind) and
    (Length(lModel.IncludeFileNames) > 0) then
  begin
    if TryPhysicalModelPosition(lModel, lSourceKind, aFileName, aLine, aColumn, lResult) then
      Exit(lResult);
    if not SameFileName(lModel.FileName, aFileName) then
      Exit(MakeNotFound(''));
  end;
  if (lSnapshot <> nil) and not lSnapshot.TryFindUnitByFileName(aFileName, lUnitId) then
    Exit(MakeNotFound(''));

  if TryReadContextLine(aContext, aFileName, aLine, lLineText) and TryExtractIdentifierAtColumn(lLineText,
    aColumn, lToken) then
  begin
    if lSnapshot <> nil then
    begin
      if TryResolveSnapshotPosition(lSnapshot, aFileName, aLine, aColumn, lToken,
        lPositionResolution) then
        Exit(SnapshotSymbolResult(lSnapshot, lPositionResolution.SymbolUnit,
          lPositionResolution.Symbol, lPositionResolution.Status));
      lResult := FindDefinitionByName(aContext, lToken);
      if lResult.Found then
        Exit(lResult);
      Exit(MakeNotFound(lToken));
    end;

    if SameText(lToken, 'unit') and TryFindModelForFile(aContext, aFileName, lModel,
      lSourceKind) then
      Exit(UnitResult(lModel, lSourceKind));
    if TryFindModelForFile(aContext, aFileName, lModel, lSourceKind) and
      TryFindLocalAtPosition(lModel, lSourceKind, lToken, aLine, aColumn, lResult) then
      Exit(lResult);
    if TryFindModelForFile(aContext, aFileName, lModel, lSourceKind) and
      TryFindLocalReferenceAtPosition(lModel, lSourceKind, lToken, aLine, aColumn, lResult) then
      Exit(lResult);
    if TryFindModelForFile(aContext, aFileName, lModel, lSourceKind) and
      TryFindMemberAtPosition(lModel, lSourceKind, lToken, aLine, aColumn, lResult) then
      Exit(lResult);
    if TryFindModelForFile(aContext, aFileName, lModel, lSourceKind) and
      TryFindMemberReferenceAtPosition(lModel, lSourceKind, lToken, aLine, aColumn, lResult) then
      Exit(lResult);
    if TryFindModelForFile(aContext, aFileName, lModel, lSourceKind) then
      lResult := FindDefinitionInModel(lModel, lSourceKind, lToken)
    else
      lResult := FindDefinitionByName(aContext, lToken);
    if lResult.Found then
      Exit(lResult);
    if TryFindModelForFile(aContext, aFileName, lModel, lSourceKind) and
      TryFindTypeForLocal(lModel, lToken, lTypeName) then
    begin
      lResult := FindDefinitionInModel(lModel, lSourceKind, lTypeName);
      if lResult.Found then
        Exit(lResult);
      Exit(FindDefinitionByName(aContext, lTypeName));
    end;
    lResult := FindDefinitionByName(aContext, lToken);
    if lResult.Found then
      Exit(lResult);
    Exit(lResult);
  end;

  Result := MakeNotFound('');
end;

class function TDelphiSemanticSymbolQuery.FindDefinitionByName(
  const aContext: TDelphiSemanticSymbolQueryContext; const aName: string):
  TDelphiSemanticSymbolQueryResult;
var
  i: Integer;
  lIntrinsic: TDelphiSemanticIntrinsicSymbol;
  lModel: TDelphiSemanticUnitModel;
  lSnapshot: TDelphiProjectSnapshot;
begin
  lSnapshot := ContextProjectSnapshot(aContext);
  if lSnapshot <> nil then
  begin
    if TrySnapshotSymbolResultByName(lSnapshot, aName, Result) then
      Exit;
    for lIntrinsic in aContext.CompilerProfile.IntrinsicSymbols do
      if SameText(lIntrinsic.Name, aName) then
        Exit(IntrinsicResult(lIntrinsic));
    Exit(MakeNotFound(aName));
  end;

  Result := FindDefinitionInModel(aContext.UnitModel, 'project-source', aName);
  if Result.Found then
    Exit;

  for i := 0 to High(aContext.IndexedUnitModels) do
  begin
    lModel := aContext.IndexedUnitModels[i];
    Result := FindDefinitionInModel(lModel, IndexedSourceKind(aContext, i), aName);
    if Result.Found then
      Exit;
  end;

  for lIntrinsic in aContext.CompilerProfile.IntrinsicSymbols do
    if SameText(lIntrinsic.Name, aName) then
      Exit(IntrinsicResult(lIntrinsic));

  Result := MakeNotFound(aName);
end;

class function TDelphiSemanticSymbolQuery.FindTokenReferences(
  const aContext: TDelphiSemanticSymbolQueryContext; const aName: string; const aLimit: Integer):
  TArray<TDelphiSemanticSymbolReferenceResult>;
var
  i: Integer;
  lModel: TDelphiSemanticUnitModel;
  lResult: TDelphiSemanticSymbolReferenceResult;
  lResults: TList<TDelphiSemanticSymbolReferenceResult>;
  lSnapshot: TDelphiProjectSnapshot;

  procedure AddModelReferences(const aModel: TDelphiSemanticUnitModel; const aSourceKind: string);
  var
    lReference: TDelphiSemanticReference;
    lOccurrence: TDelphiSemanticPhysicalReferenceOccurrence;
    lReferences: TArray<TDelphiSemanticReference>;
  begin
    if aModel.PhysicalReferenceOccurrencesAvailable and (Length(aModel.IncludeFileNames) > 0) then
    begin
      SetLength(lReferences, Length(aModel.PhysicalReferenceOccurrences));
      for var j := 0 to High(lReferences) do
      begin
        lOccurrence := aModel.PhysicalReferenceOccurrences[j];
        if not TryPhysicalReference(lOccurrence, lReferences[j]) then
        begin
          lReferences[j].Name := lOccurrence.Name;
          lReferences[j].FileName := lOccurrence.FileName;
        end;
      end;
    end else
      lReferences := aModel.References;
    for lReference in lReferences do
      if SameText(lReference.Name, aName) and ((aLimit <= 0) or (lResults.Count < aLimit)) then
      begin
        lResult := Default(TDelphiSemanticSymbolReferenceResult);
        lResult.Name := lReference.Name;
        lResult.UnitName := aModel.UnitName;
        lResult.SourceKind := aSourceKind;
        lResult.Confidence := 'token-name-match';
        lResult.Role := lReference.Role;
        if lResult.Role = '' then
          lResult.Role := 'token';
        lResult.SectionKind := lReference.SectionKind;
        if lResult.SectionKind = '' then
          lResult.SectionKind := 'implementation';
        lResult.FileName := FactSourceFileName(aModel.FileName, lReference.FileName);
        if SourcePositionKnown(lReference.Line, lReference.Column) and
          (aModel.PhysicalReferenceOccurrencesAvailable or (lReference.FileName = '')) then
        begin
          lResult.Line := lReference.Line;
          lResult.Column := lReference.Column;
          lResult.EndLine := SnapshotEndLine(lReference.Line, lReference.EndLine);
          lResult.EndColumn := SnapshotEndColumn(lReference.Column, lReference.Name, lReference.EndColumn);
        end;
        lResults.Add(lResult);
      end;
  end;

begin
  lSnapshot := ContextProjectSnapshot(aContext);
  if lSnapshot <> nil then
    Exit(SnapshotTokenReferences(lSnapshot, aName, aLimit));

  lResults := TList<TDelphiSemanticSymbolReferenceResult>.Create;
  try
    AddModelReferences(aContext.UnitModel, 'project-source');
    for i := 0 to High(aContext.IndexedUnitModels) do
    begin
      lModel := aContext.IndexedUnitModels[i];
      AddModelReferences(lModel, IndexedSourceKind(aContext, i));
    end;
    Result := lResults.ToArray;
  finally
    lResults.Free;
  end;
end;

class function TDelphiSemanticSymbolQuery.GetCacheStatus(
  const aContext: TDelphiSemanticSymbolQueryContext): TDelphiSemanticSymbolQueryCacheStatus;
begin
  Result.CacheFileName := aContext.CacheMetrics.CacheFileName;
  Result.CacheKind := aContext.CacheMetrics.CacheKind;
  Result.CacheHits := aContext.CacheMetrics.CacheHits;
  Result.CacheMisses := aContext.CacheMetrics.CacheMisses;
  Result.Invalidations := aContext.CacheMetrics.Invalidations;
  Result.CompilerProfileName := aContext.CompilerProfile.Name;
  Result.CompilerProfileKey := aContext.CompilerProfile.ProfileKey;
  Result.IntrinsicCount := Length(aContext.CompilerProfile.IntrinsicSymbols);
  Result.RtlSourceUnitCount := Length(aContext.CompilerProfile.RtlSourceUnitModels);
end;

class function TDelphiSemanticSymbolQuery.GetVisibleUnitScopes(
  const aContext: TDelphiSemanticSymbolQueryContext): TArray<TDelphiSemanticVisibleUnitScope>;
var
  i: Integer;
  lIndex: Integer;
  lModel: TDelphiSemanticUnitModel;
  lSnapshot: TDelphiProjectSnapshot;
  lSymbol: TSemanticSymbolFact;
  lUnit: TUnitSnapshot;
begin
  lSnapshot := ContextProjectSnapshot(aContext);
  if lSnapshot <> nil then
  begin
    SetLength(Result, lSnapshot.UnitCount);
    for i := 0 to lSnapshot.UnitCount - 1 do
    begin
      lUnit := lSnapshot.UnitByIndex(i);
      Result[i].UnitName := SnapshotText(lSnapshot, lUnit.UnitNameId);
      Result[i].FileName := SnapshotText(lSnapshot, lUnit.FileNameId);
      Result[i].SourceKind := 'project-snapshot';
      if lUnit.SymbolCount > 0 then
      begin
        lSymbol := lUnit.SymbolById(TSemanticSymbolId(1));
        if SnapshotText(lSnapshot, lSymbol.SourceKindId) <> '' then
          Result[i].SourceKind := SnapshotText(lSnapshot, lSymbol.SourceKindId);
      end;
    end;
    Exit;
  end;

  SetLength(Result, 1 + Length(aContext.IndexedUnitModels));
  Result[0].UnitName := aContext.UnitModel.UnitName;
  Result[0].FileName := aContext.UnitModel.FileName;
  Result[0].SourceKind := 'project-source';
  lIndex := 1;
  for i := 0 to High(aContext.IndexedUnitModels) do
  begin
    lModel := aContext.IndexedUnitModels[i];
    Result[lIndex].UnitName := lModel.UnitName;
    Result[lIndex].FileName := lModel.FileName;
    Result[lIndex].SourceKind := IndexedSourceKind(aContext, i);
    Inc(lIndex);
  end;
end;

class function TDelphiSemanticSymbolQuery.Search(
  const aContext: TDelphiSemanticSymbolQueryContext; const aName: string; const aLimit: Integer):
  TArray<TDelphiSemanticSymbolQueryResult>;
var
  i: Integer;
  lIntrinsic: TDelphiSemanticIntrinsicSymbol;
  lModel: TDelphiSemanticUnitModel;
  lUseSubstring: Boolean;
  lResults: TList<TDelphiSemanticSymbolQueryResult>;

  function HasExactVisibleMatch: Boolean;
  var
    lExactDeclaration: TDelphiSemanticDeclaration;
    lExactIntrinsic: TDelphiSemanticIntrinsicSymbol;
    lExactMember: TDelphiSemanticMember;
    lExactModel: TDelphiSemanticUnitModel;
    lExactRoutine: TDelphiSemanticRoutine;
  begin
    for lExactDeclaration in aContext.UnitModel.Declarations do
      if SameText(lExactDeclaration.Name, aName) then
        Exit(True);
    for lExactMember in aContext.UnitModel.Members do
      if SameText(lExactMember.Name, aName) then
        Exit(True);
    for lExactRoutine in aContext.UnitModel.Routines do
      if SameText(lExactRoutine.Name, aName) then
        Exit(True);
    for lExactModel in aContext.IndexedUnitModels do
    begin
      for lExactMember in lExactModel.Members do
        if SameText(lExactMember.Name, aName) then
          Exit(True);
      for lExactRoutine in lExactModel.Routines do
        if SameText(lExactRoutine.Name, aName) then
          Exit(True);
      for lExactDeclaration in lExactModel.Declarations do
        if SameText(lExactDeclaration.Name, aName) then
          Exit(True);
    end;
    for lExactIntrinsic in aContext.CompilerProfile.IntrinsicSymbols do
      if SameText(lExactIntrinsic.Name, aName) then
        Exit(True);
    Result := False;
  end;
begin
  if ContextProjectSnapshot(aContext) <> nil then
    Exit(SnapshotSearch(aContext, aName, aLimit, not SnapshotHasExactSymbolMatch(aContext,
      aName)));

  lUseSubstring := not HasExactVisibleMatch;
  lResults := TList<TDelphiSemanticSymbolQueryResult>.Create;
  try
    for var lDeclarationIndex := 0 to High(aContext.UnitModel.Declarations) do
      if NameMatchesQuery(aContext.UnitModel.Declarations[lDeclarationIndex].Name, aName, lUseSubstring) then
        AddResult(lResults, DeclarationResult(aContext.UnitModel, lDeclarationIndex, 'project-source'),
          aLimit);

    for var lMemberIndex := 0 to High(aContext.UnitModel.Members) do
      if NameMatchesQuery(aContext.UnitModel.Members[lMemberIndex].Name, aName, lUseSubstring) then
        AddResult(lResults, MemberResult(aContext.UnitModel, lMemberIndex, 'project-source'),
          aLimit);

    for var lRoutineIndex := 0 to High(aContext.UnitModel.Routines) do
      if NameMatchesQuery(aContext.UnitModel.Routines[lRoutineIndex].Name, aName, lUseSubstring) then
        AddResult(lResults, RoutineResult(aContext.UnitModel, lRoutineIndex, 'project-source'),
          aLimit);

    for i := 0 to High(aContext.IndexedUnitModels) do
    begin
      lModel := aContext.IndexedUnitModels[i];
      for var lMemberIndex := 0 to High(lModel.Members) do
        if NameMatchesQuery(lModel.Members[lMemberIndex].Name, aName, lUseSubstring) then
          AddResult(lResults, MemberResult(lModel, lMemberIndex, IndexedSourceKind(aContext, i)),
            aLimit);

      for var lRoutineIndex := 0 to High(lModel.Routines) do
        if NameMatchesQuery(lModel.Routines[lRoutineIndex].Name, aName, lUseSubstring) then
          AddResult(lResults, RoutineResult(lModel, lRoutineIndex, IndexedSourceKind(aContext, i)),
            aLimit);

      for var lDeclarationIndex := 0 to High(lModel.Declarations) do
        if NameMatchesQuery(lModel.Declarations[lDeclarationIndex].Name, aName, lUseSubstring) then
          AddResult(lResults, DeclarationResult(lModel, lDeclarationIndex, IndexedSourceKind(aContext,
            i)), aLimit);
    end;

    for lIntrinsic in aContext.CompilerProfile.IntrinsicSymbols do
      if NameMatchesQuery(lIntrinsic.Name, aName, lUseSubstring) then
        AddResult(lResults, IntrinsicResult(lIntrinsic), aLimit);

    Result := lResults.ToArray;
  finally
    lResults.Free;
  end;
end;

class function TDelphiSemanticSymbolQuery.SearchAllMatches(
  const aContext: TDelphiSemanticSymbolQueryContext; const aName: string; const aLimit: Integer):
  TArray<TDelphiSemanticSymbolQueryResult>;
var
  i: Integer;
  lIntrinsic: TDelphiSemanticIntrinsicSymbol;
  lModel: TDelphiSemanticUnitModel;
  lResults: TList<TDelphiSemanticSymbolQueryResult>;
begin
  if ContextProjectSnapshot(aContext) <> nil then
    Exit(SnapshotSearch(aContext, aName, aLimit, True));

  lResults := TList<TDelphiSemanticSymbolQueryResult>.Create;
  try
    for var lDeclarationIndex := 0 to High(aContext.UnitModel.Declarations) do
      if NameMatchesQuery(aContext.UnitModel.Declarations[lDeclarationIndex].Name, aName, True) then
        AddResult(lResults, DeclarationResult(aContext.UnitModel, lDeclarationIndex, 'project-source'),
          aLimit);

    for var lMemberIndex := 0 to High(aContext.UnitModel.Members) do
      if NameMatchesQuery(aContext.UnitModel.Members[lMemberIndex].Name, aName, True) then
        AddResult(lResults, MemberResult(aContext.UnitModel, lMemberIndex, 'project-source'),
          aLimit);

    for var lRoutineIndex := 0 to High(aContext.UnitModel.Routines) do
      if NameMatchesQuery(aContext.UnitModel.Routines[lRoutineIndex].Name, aName, True) then
        AddResult(lResults, RoutineResult(aContext.UnitModel, lRoutineIndex, 'project-source'),
          aLimit);

    for i := 0 to High(aContext.IndexedUnitModels) do
    begin
      lModel := aContext.IndexedUnitModels[i];
      for var lMemberIndex := 0 to High(lModel.Members) do
        if NameMatchesQuery(lModel.Members[lMemberIndex].Name, aName, True) then
          AddResult(lResults, MemberResult(lModel, lMemberIndex, IndexedSourceKind(aContext, i)),
            aLimit);

      for var lRoutineIndex := 0 to High(lModel.Routines) do
        if NameMatchesQuery(lModel.Routines[lRoutineIndex].Name, aName, True) then
          AddResult(lResults, RoutineResult(lModel, lRoutineIndex, IndexedSourceKind(aContext, i)),
            aLimit);

      for var lDeclarationIndex := 0 to High(lModel.Declarations) do
        if NameMatchesQuery(lModel.Declarations[lDeclarationIndex].Name, aName, True) then
          AddResult(lResults, DeclarationResult(lModel, lDeclarationIndex, IndexedSourceKind(aContext,
            i)), aLimit);
    end;

    for lIntrinsic in aContext.CompilerProfile.IntrinsicSymbols do
      if NameMatchesQuery(lIntrinsic.Name, aName, True) then
        AddResult(lResults, IntrinsicResult(lIntrinsic), aLimit);

    Result := lResults.ToArray;
  finally
    lResults.Free;
  end;
end;

end.
