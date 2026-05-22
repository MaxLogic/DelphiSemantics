unit DelphiSemantics.Query;

interface

uses
  DelphiSemantics.Cache, DelphiSemantics.CompilerProfile, DelphiSemantics.Model;

type
  TDelphiSemanticSymbolQueryContext = record
    UnitModel: TDelphiSemanticUnitModel;
    IndexedUnitModels: TArray<TDelphiSemanticUnitModel>;
    IndexedUnitSourceKinds: TArray<string>;
    CompilerProfile: TDelphiSemanticCompilerProfile;
    CacheMetrics: TDelphiSemanticCacheMetrics;
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

function DeclarationResult(const aModel: TDelphiSemanticUnitModel;
  const aDeclaration: TDelphiSemanticDeclaration; const aSourceKind: string):
  TDelphiSemanticSymbolQueryResult;
begin
  Result := Default(TDelphiSemanticSymbolQueryResult);
  Result.Found := True;
  Result.Status := 'resolved';
  Result.Name := aDeclaration.Name;
  Result.Kind := aDeclaration.Kind;
  Result.TypeName := aDeclaration.TypeName;
  Result.OwnerName := aModel.UnitName;
  Result.UnitName := aModel.UnitName;
  Result.SectionKind := aDeclaration.SectionKind;
  Result.Description := MakeDescription(aDeclaration.Name, aDeclaration.TypeName);
  Result.SourceKind := aSourceKind;
  Result.Confidence := 'declaration-name-match';
  Result.Provenance := 'semantic-model';
  Result.FileName := aModel.FileName;
  Result.Line := aDeclaration.Line;
  Result.Column := aDeclaration.Column;
  Result.EndLine := aDeclaration.Line;
  Result.EndColumn := aDeclaration.Column + Length(aDeclaration.Name) - 1;
end;

function MemberResult(const aModel: TDelphiSemanticUnitModel; const aMember: TDelphiSemanticMember;
  const aSourceKind: string): TDelphiSemanticSymbolQueryResult;
begin
  Result := Default(TDelphiSemanticSymbolQueryResult);
  Result.Found := True;
  Result.Status := 'resolved';
  Result.Name := aMember.Name;
  Result.Kind := aMember.Kind;
  Result.TypeName := aMember.TypeName;
  Result.OwnerName := aMember.OwnerName;
  Result.UnitName := aModel.UnitName;
  Result.Description := MakeDescription(aMember.Name, aMember.TypeName);
  Result.SourceKind := aSourceKind;
  Result.Confidence := 'member-name-match';
  Result.Provenance := 'semantic-model';
  Result.Signature := aMember.Signature;
  Result.FileName := aModel.FileName;
  Result.Line := aMember.Line;
  Result.Column := aMember.Column;
  Result.EndLine := aMember.Line;
  Result.EndColumn := aMember.Column + Length(aMember.Name) - 1;
end;

function RoutineResult(const aModel: TDelphiSemanticUnitModel;
  const aRoutine: TDelphiSemanticRoutine; const aSourceKind: string):
  TDelphiSemanticSymbolQueryResult;
begin
  Result := Default(TDelphiSemanticSymbolQueryResult);
  Result.Found := True;
  Result.Status := 'resolved';
  Result.Name := aRoutine.Name;
  Result.Kind := 'routine';
  Result.TypeName := aRoutine.ReturnType;
  Result.OwnerName := aRoutine.OwnerName;
  Result.UnitName := aModel.UnitName;
  Result.SectionKind := aRoutine.SectionKind;
  Result.Description := MakeDescription(aRoutine.Name, aRoutine.ReturnType);
  Result.SourceKind := aSourceKind;
  Result.Confidence := 'routine-name-match';
  Result.Provenance := 'semantic-model';
  Result.Signature := aRoutine.Signature;
  Result.FileName := aModel.FileName;
  Result.Line := aRoutine.Line;
  Result.Column := aRoutine.Column;
  Result.EndLine := aRoutine.Line;
  Result.EndColumn := aRoutine.Column + Length(aRoutine.Name) - 1;
end;

function LocalResult(const aModel: TDelphiSemanticUnitModel; const aLocal: TDelphiSemanticLocal;
  const aSourceKind: string): TDelphiSemanticSymbolQueryResult;
begin
  Result := Default(TDelphiSemanticSymbolQueryResult);
  Result.Found := True;
  Result.Status := 'resolved';
  Result.Name := aLocal.Name;
  Result.Kind := aLocal.Kind;
  Result.TypeName := aLocal.TypeName;
  Result.OwnerName := aLocal.RoutineName;
  Result.UnitName := aModel.UnitName;
  Result.Description := MakeDescription(aLocal.Name, aLocal.TypeName);
  Result.SourceKind := aSourceKind;
  Result.Confidence := 'local-name-match';
  Result.Provenance := 'semantic-model';
  Result.FileName := aModel.FileName;
  Result.Line := aLocal.Line;
  Result.Column := aLocal.Column;
  Result.EndLine := aLocal.Line;
  Result.EndColumn := aLocal.Column + Length(aLocal.Name) - 1;
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

function IsIdentifierChar(const aChar: Char): Boolean;
begin
  Result := (aChar = '_') or CharInSet(aChar, ['A'..'Z', 'a'..'z', '0'..'9']);
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

function TryReadLine(const aFileName: string; const aLine: Integer; out aLineText: string):
  Boolean;
var
  lLines: TStringList;
  lSourceResult: TDelphiSemanticSourceLoadResult;
begin
  aLineText := '';
  if (aLine <= 0) or not TFile.Exists(aFileName) then
    Exit(False);

  lSourceResult := TDelphiSemanticSourceLoader.LoadFile(aFileName);
  if not lSourceResult.Success then
    Exit(False);

  lLines := TStringList.Create;
  try
    lLines.Text := lSourceResult.Source.Text;
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
var
  lLocal: TDelphiSemanticLocal;
begin
  for lLocal in aModel.Locals do
    if SameText(lLocal.Name, aName) then
    begin
      aTypeName := lLocal.TypeName;
      Exit(True);
    end;

  aTypeName := '';
  Result := False;
end;

function TryFindLocalAtPosition(const aModel: TDelphiSemanticUnitModel; const aSourceKind,
  aName: string; const aLine, aColumn: Integer; out aResult: TDelphiSemanticSymbolQueryResult):
  Boolean;
var
  lLocal: TDelphiSemanticLocal;
begin
  for lLocal in aModel.Locals do
    if SameText(lLocal.Name, aName) and (lLocal.Line = aLine) and (aColumn >= lLocal.Column) and
      (aColumn <= lLocal.Column + Length(lLocal.Name)) then
    begin
      aResult := LocalResult(aModel, lLocal, aSourceKind);
      Exit(True);
    end;

  aResult := Default(TDelphiSemanticSymbolQueryResult);
  Result := False;
end;

function TryFindLocalReferenceAtPosition(const aModel: TDelphiSemanticUnitModel; const aSourceKind,
  aName: string; const aLine, aColumn: Integer; out aResult: TDelphiSemanticSymbolQueryResult):
  Boolean;
var
  lLocal: TDelphiSemanticLocal;
  lReference: TDelphiSemanticReference;
begin
  for lReference in aModel.References do
    if SameText(lReference.Name, aName) and (lReference.RoutineName <> '') and
      (lReference.Line = aLine) and (aColumn >= lReference.Column) and
      (aColumn <= lReference.EndColumn + 1) then
      for lLocal in aModel.Locals do
        if SameText(lLocal.RoutineName, lReference.RoutineName) and
          SameText(lLocal.Name, aName) then
        begin
          aResult := LocalResult(aModel, lLocal, aSourceKind);
          Exit(True);
        end;

  aResult := Default(TDelphiSemanticSymbolQueryResult);
  Result := False;
end;

function TryFindMemberAtPosition(const aModel: TDelphiSemanticUnitModel; const aSourceKind,
  aName: string; const aLine, aColumn: Integer; out aResult: TDelphiSemanticSymbolQueryResult):
  Boolean;
var
  lMember: TDelphiSemanticMember;
begin
  for lMember in aModel.Members do
    if SameText(lMember.Name, aName) and (lMember.Line = aLine) and
      (aColumn >= lMember.Column) and (aColumn <= lMember.Column + Length(lMember.Name)) then
    begin
      aResult := MemberResult(aModel, lMember, aSourceKind);
      Exit(True);
    end;

  aResult := Default(TDelphiSemanticSymbolQueryResult);
  Result := False;
end;

function TryFindMemberReferenceAtPosition(const aModel: TDelphiSemanticUnitModel;
  const aSourceKind, aName: string; const aLine, aColumn: Integer;
  out aResult: TDelphiSemanticSymbolQueryResult): Boolean;
var
  lMember: TDelphiSemanticMember;
  lReference: TDelphiSemanticReference;
begin
  for lReference in aModel.References do
    if SameText(lReference.Name, aName) and (lReference.Line = aLine) and
      (aColumn >= lReference.Column - 1) and (aColumn <= lReference.EndColumn + 1) then
      for lMember in aModel.Members do
        if SameText(lMember.Name, aName) then
        begin
          aResult := MemberResult(aModel, lMember, aSourceKind);
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

function IndexedSourceKind(const aContext: TDelphiSemanticSymbolQueryContext;
  const aIndex: Integer): string;
begin
  if (aIndex >= 0) and (aIndex < Length(aContext.IndexedUnitSourceKinds)) and
    (aContext.IndexedUnitSourceKinds[aIndex] <> '') then
    Exit(aContext.IndexedUnitSourceKinds[aIndex]);

  Result := 'rtl-source';
end;

function TryFindModelForFile(const aContext: TDelphiSemanticSymbolQueryContext;
  const aFileName: string; out aModel: TDelphiSemanticUnitModel; out aSourceKind: string):
  Boolean;
var
  i: Integer;
  lModel: TDelphiSemanticUnitModel;
begin
  if SameFileName(aContext.UnitModel.FileName, aFileName) then
  begin
    aModel := aContext.UnitModel;
    aSourceKind := 'project-source';
    Exit(True);
  end;

  for i := 0 to High(aContext.IndexedUnitModels) do
  begin
    lModel := aContext.IndexedUnitModels[i];
    if SameFileName(lModel.FileName, aFileName) then
    begin
      aModel := lModel;
      aSourceKind := IndexedSourceKind(aContext, i);
      Exit(True);
    end;
  end;

  aModel := Default(TDelphiSemanticUnitModel);
  aSourceKind := '';
  Result := False;
end;

function FindDefinitionInModel(const aModel: TDelphiSemanticUnitModel; const aSourceKind,
  aName: string): TDelphiSemanticSymbolQueryResult;
var
  lDeclaration: TDelphiSemanticDeclaration;
  lMember: TDelphiSemanticMember;
  lRoutine: TDelphiSemanticRoutine;
begin
  for lDeclaration in aModel.Declarations do
    if SameText(lDeclaration.Name, aName) then
      Exit(DeclarationResult(aModel, lDeclaration, aSourceKind));

  for lRoutine in aModel.Routines do
    if SameText(lRoutine.Name, aName) then
      Exit(RoutineResult(aModel, lRoutine, aSourceKind));

  for lMember in aModel.Members do
    if SameText(lMember.Name, aName) then
      Exit(MemberResult(aModel, lMember, aSourceKind));

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

class function TDelphiSemanticSymbolQuery.DescribeOwnedMember(
  const aContext: TDelphiSemanticSymbolQueryContext; const aOwnerName, aName: string):
  TDelphiSemanticSymbolQueryResult;
var
  i: Integer;
  lMember: TDelphiSemanticMember;
  lModel: TDelphiSemanticUnitModel;
begin
  for lMember in aContext.UnitModel.Members do
    if SameText(lMember.OwnerName, aOwnerName) and SameText(lMember.Name, aName) then
      Exit(MemberResult(aContext.UnitModel, lMember, 'project-source'));

  for i := 0 to High(aContext.IndexedUnitModels) do
  begin
    lModel := aContext.IndexedUnitModels[i];
    for lMember in lModel.Members do
      if SameText(lMember.OwnerName, aOwnerName) and SameText(lMember.Name, aName) then
        Exit(MemberResult(lModel, lMember, IndexedSourceKind(aContext, i)));
  end;

  Result := MakeNotFound(aName);
end;

class function TDelphiSemanticSymbolQuery.FindDefinitionAtPosition(
  const aContext: TDelphiSemanticSymbolQueryContext; const aFileName: string;
  const aLine, aColumn: Integer): TDelphiSemanticSymbolQueryResult;
var
  lResult: TDelphiSemanticSymbolQueryResult;
  lLineText: string;
  lModel: TDelphiSemanticUnitModel;
  lSourceKind: string;
  lToken: string;
  lTypeName: string;
begin
  if TryReadLine(aFileName, aLine, lLineText) and TryExtractIdentifierAtColumn(lLineText,
    aColumn, lToken) then
  begin
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
begin
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

  procedure AddModelReferences(const aModel: TDelphiSemanticUnitModel; const aSourceKind: string);
  var
    lReference: TDelphiSemanticReference;
  begin
    for lReference in aModel.References do
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
        lResult.FileName := aModel.FileName;
        lResult.Line := lReference.Line;
        lResult.Column := lReference.Column;
        lResult.EndLine := lReference.EndLine;
        if lResult.EndLine = 0 then
          lResult.EndLine := lReference.Line;
        lResult.EndColumn := lReference.EndColumn;
        if lResult.EndColumn = 0 then
          lResult.EndColumn := lReference.Column + Length(lReference.Name) - 1;
        lResults.Add(lResult);
      end;
  end;

begin
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
begin
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
  lDeclaration: TDelphiSemanticDeclaration;
  lIntrinsic: TDelphiSemanticIntrinsicSymbol;
  lMember: TDelphiSemanticMember;
  lModel: TDelphiSemanticUnitModel;
  lRoutine: TDelphiSemanticRoutine;
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
  lUseSubstring := not HasExactVisibleMatch;
  lResults := TList<TDelphiSemanticSymbolQueryResult>.Create;
  try
    for lDeclaration in aContext.UnitModel.Declarations do
      if NameMatchesQuery(lDeclaration.Name, aName, lUseSubstring) then
        AddResult(lResults, DeclarationResult(aContext.UnitModel, lDeclaration, 'project-source'),
          aLimit);

    for lMember in aContext.UnitModel.Members do
      if NameMatchesQuery(lMember.Name, aName, lUseSubstring) then
        AddResult(lResults, MemberResult(aContext.UnitModel, lMember, 'project-source'),
          aLimit);

    for lRoutine in aContext.UnitModel.Routines do
      if NameMatchesQuery(lRoutine.Name, aName, lUseSubstring) then
        AddResult(lResults, RoutineResult(aContext.UnitModel, lRoutine, 'project-source'),
          aLimit);

    for i := 0 to High(aContext.IndexedUnitModels) do
    begin
      lModel := aContext.IndexedUnitModels[i];
      for lMember in lModel.Members do
        if NameMatchesQuery(lMember.Name, aName, lUseSubstring) then
          AddResult(lResults, MemberResult(lModel, lMember, IndexedSourceKind(aContext, i)),
            aLimit);

      for lRoutine in lModel.Routines do
        if NameMatchesQuery(lRoutine.Name, aName, lUseSubstring) then
          AddResult(lResults, RoutineResult(lModel, lRoutine, IndexedSourceKind(aContext, i)),
            aLimit);

      for lDeclaration in lModel.Declarations do
        if NameMatchesQuery(lDeclaration.Name, aName, lUseSubstring) then
          AddResult(lResults, DeclarationResult(lModel, lDeclaration, IndexedSourceKind(aContext,
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
  lDeclaration: TDelphiSemanticDeclaration;
  lIntrinsic: TDelphiSemanticIntrinsicSymbol;
  lMember: TDelphiSemanticMember;
  lModel: TDelphiSemanticUnitModel;
  lRoutine: TDelphiSemanticRoutine;
  lResults: TList<TDelphiSemanticSymbolQueryResult>;
begin
  lResults := TList<TDelphiSemanticSymbolQueryResult>.Create;
  try
    for lDeclaration in aContext.UnitModel.Declarations do
      if NameMatchesQuery(lDeclaration.Name, aName, True) then
        AddResult(lResults, DeclarationResult(aContext.UnitModel, lDeclaration, 'project-source'),
          aLimit);

    for lMember in aContext.UnitModel.Members do
      if NameMatchesQuery(lMember.Name, aName, True) then
        AddResult(lResults, MemberResult(aContext.UnitModel, lMember, 'project-source'),
          aLimit);

    for lRoutine in aContext.UnitModel.Routines do
      if NameMatchesQuery(lRoutine.Name, aName, True) then
        AddResult(lResults, RoutineResult(aContext.UnitModel, lRoutine, 'project-source'),
          aLimit);

    for i := 0 to High(aContext.IndexedUnitModels) do
    begin
      lModel := aContext.IndexedUnitModels[i];
      for lMember in lModel.Members do
        if NameMatchesQuery(lMember.Name, aName, True) then
          AddResult(lResults, MemberResult(lModel, lMember, IndexedSourceKind(aContext, i)),
            aLimit);

      for lRoutine in lModel.Routines do
        if NameMatchesQuery(lRoutine.Name, aName, True) then
          AddResult(lResults, RoutineResult(lModel, lRoutine, IndexedSourceKind(aContext, i)),
            aLimit);

      for lDeclaration in lModel.Declarations do
        if NameMatchesQuery(lDeclaration.Name, aName, True) then
          AddResult(lResults, DeclarationResult(lModel, lDeclaration, IndexedSourceKind(aContext,
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
