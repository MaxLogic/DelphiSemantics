unit DelphiSemantics.Query;

interface

uses
  DelphiSemantics.Cache, DelphiSemantics.CompilerProfile, DelphiSemantics.Model;

type
  TDelphiSemanticSymbolQueryContext = record
    UnitModel: TDelphiSemanticUnitModel;
    IndexedUnitModels: TArray<TDelphiSemanticUnitModel>;
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
    Description: string;
    SourceKind: string;
    Confidence: string;
    Provenance: string;
    FileName: string;
    Line: Integer;
    Column: Integer;
  end;

  TDelphiSemanticSymbolReferenceResult = record
    Name: string;
    SourceKind: string;
    Confidence: string;
    FileName: string;
    Line: Integer;
    Column: Integer;
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
    class function Search(const aContext: TDelphiSemanticSymbolQueryContext; const aName: string;
      const aLimit: Integer): TArray<TDelphiSemanticSymbolQueryResult>; static;
  end;

implementation

uses
  System.Classes, System.Generics.Collections, System.IOUtils, System.SysUtils,
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
  Result.Description := MakeDescription(aDeclaration.Name, aDeclaration.TypeName);
  Result.SourceKind := aSourceKind;
  Result.Confidence := 'declaration-name-match';
  Result.Provenance := 'semantic-model';
  Result.FileName := aModel.FileName;
  Result.Line := aDeclaration.Line;
  Result.Column := aDeclaration.Column;
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
  Result.Description := MakeDescription(aMember.Name, aMember.TypeName);
  Result.SourceKind := aSourceKind;
  Result.Confidence := 'member-name-match';
  Result.Provenance := 'semantic-model';
  Result.FileName := aModel.FileName;
  Result.Line := aMember.Line;
  Result.Column := aMember.Column;
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
  Result.Description := MakeDescription(aRoutine.Name, aRoutine.ReturnType);
  Result.SourceKind := aSourceKind;
  Result.Confidence := 'routine-name-match';
  Result.Provenance := 'semantic-model';
  Result.FileName := aModel.FileName;
  Result.Line := aRoutine.Line;
  Result.Column := aRoutine.Column;
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
  Result.Description := MakeDescription(aSymbol.Name, aSymbol.TypeName);
  Result.SourceKind := 'compiler-profile';
  Result.Confidence := 'intrinsic-name-match';
  Result.Provenance := 'semantic-model';
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

function TryFindModelForFile(const aContext: TDelphiSemanticSymbolQueryContext;
  const aFileName: string; out aModel: TDelphiSemanticUnitModel; out aSourceKind: string):
  Boolean;
var
  lModel: TDelphiSemanticUnitModel;
begin
  if SameFileName(aContext.UnitModel.FileName, aFileName) then
  begin
    aModel := aContext.UnitModel;
    aSourceKind := 'project-source';
    Exit(True);
  end;

  for lModel in aContext.IndexedUnitModels do
    if SameFileName(lModel.FileName, aFileName) then
    begin
      aModel := lModel;
      aSourceKind := 'rtl-source';
      Exit(True);
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
  lMember: TDelphiSemanticMember;
begin
  for lMember in aContext.UnitModel.Members do
    if SameText(lMember.OwnerName, aOwnerName) and SameText(lMember.Name, aName) then
      Exit(MemberResult(aContext.UnitModel, lMember, 'project-source'));

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
  lIntrinsic: TDelphiSemanticIntrinsicSymbol;
  lModel: TDelphiSemanticUnitModel;
begin
  Result := FindDefinitionInModel(aContext.UnitModel, 'project-source', aName);
  if Result.Found then
    Exit;

  for lModel in aContext.IndexedUnitModels do
  begin
    Result := FindDefinitionInModel(lModel, 'rtl-source', aName);
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
  lReference: TDelphiSemanticReference;
  lResult: TDelphiSemanticSymbolReferenceResult;
  lResults: TList<TDelphiSemanticSymbolReferenceResult>;
begin
  lResults := TList<TDelphiSemanticSymbolReferenceResult>.Create;
  try
    for lReference in aContext.UnitModel.References do
      if SameText(lReference.Name, aName) and ((aLimit <= 0) or (lResults.Count < aLimit)) then
      begin
        lResult.Name := lReference.Name;
        lResult.SourceKind := 'project-source';
        lResult.Confidence := 'token-name-match';
        lResult.FileName := aContext.UnitModel.FileName;
        lResult.Line := lReference.Line;
        lResult.Column := lReference.Column;
        lResults.Add(lResult);
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

class function TDelphiSemanticSymbolQuery.Search(
  const aContext: TDelphiSemanticSymbolQueryContext; const aName: string; const aLimit: Integer):
  TArray<TDelphiSemanticSymbolQueryResult>;
var
  lDeclaration: TDelphiSemanticDeclaration;
  lIntrinsic: TDelphiSemanticIntrinsicSymbol;
  lMember: TDelphiSemanticMember;
  lModel: TDelphiSemanticUnitModel;
  lResults: TList<TDelphiSemanticSymbolQueryResult>;
begin
  lResults := TList<TDelphiSemanticSymbolQueryResult>.Create;
  try
    for lDeclaration in aContext.UnitModel.Declarations do
      if SameText(lDeclaration.Name, aName) then
        AddResult(lResults, DeclarationResult(aContext.UnitModel, lDeclaration, 'project-source'),
          aLimit);

    for lMember in aContext.UnitModel.Members do
      if SameText(lMember.Name, aName) then
        AddResult(lResults, MemberResult(aContext.UnitModel, lMember, 'project-source'),
          aLimit);

    for lModel in aContext.IndexedUnitModels do
      for lDeclaration in lModel.Declarations do
        if SameText(lDeclaration.Name, aName) then
          AddResult(lResults, DeclarationResult(lModel, lDeclaration, 'rtl-source'), aLimit);

    for lIntrinsic in aContext.CompilerProfile.IntrinsicSymbols do
      if SameText(lIntrinsic.Name, aName) then
        AddResult(lResults, IntrinsicResult(lIntrinsic), aLimit);

    Result := lResults.ToArray;
  finally
    lResults.Free;
  end;
end;

end.
