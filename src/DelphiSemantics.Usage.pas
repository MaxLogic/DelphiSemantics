unit DelphiSemantics.Usage;

interface

uses
  DelphiSemantics.Query, DelphiSemantics.Symbols;

type
  TDelphiSemanticUsage = record
    Name: string;
    RoutineName: string;
    Role: string;
    SectionKind: string;
    SourceKind: string;
    FileName: string;
    UnitName: string;
    Line: Integer;
    Column: Integer;
    EndLine: Integer;
    EndColumn: Integer;
  end;

  TDelphiSemanticUsageResult = record
    Status: string;
    Diagnostic: string;
    Symbol: TDelphiSemanticIndexedSymbol;
    Usages: TArray<TDelphiSemanticUsage>;
  end;

  TDelphiSemanticUsageFinder = record
  public
    class function FindUsagesAtPosition(const aContext: TDelphiSemanticSymbolQueryContext;
      const aFileName: string; const aLine, aColumn: Integer): TDelphiSemanticUsageResult;
      static;
    class function FindUsagesByName(const aContext: TDelphiSemanticSymbolQueryContext;
      const aName: string): TDelphiSemanticUsageResult; static;
  end;

implementation

uses
  System.Generics.Collections, System.SysUtils,
  DelphiSemantics.Index;

function MakeDiagnosticResult(const aStatus, aDiagnostic: string): TDelphiSemanticUsageResult;
begin
  Result := Default(TDelphiSemanticUsageResult);
  Result.Status := aStatus;
  Result.Diagnostic := aDiagnostic;
end;

function FindSymbolById(const aIndex: TDelphiSemanticProjectSymbolIndex;
  const aId: TDelphiSemanticSymbolId; out aSymbol: TDelphiSemanticIndexedSymbol): Boolean;
var
  lSymbol: TDelphiSemanticIndexedSymbol;
begin
  for lSymbol in aIndex.Symbols do
    if lSymbol.Id.Value = aId.Value then
    begin
      aSymbol := lSymbol;
      Exit(True);
    end;

  aSymbol := Default(TDelphiSemanticIndexedSymbol);
  Result := False;
end;

function SymbolMatchesName(const aSymbol: TDelphiSemanticIndexedSymbol; const aName: string):
  Boolean;
begin
  Result := (aSymbol.OwnerName = '') and (SameText(aSymbol.Kind, 'unit') or
    SameText(aSymbol.Kind, 'type') or SameText(aSymbol.Kind, 'type-alias') or
    SameText(aSymbol.Kind, 'var') or SameText(aSymbol.Kind, 'const') or
    SameText(aSymbol.Kind, 'routine')) and SameText(aSymbol.Name, aName);
end;

function SymbolIdInList(const aIds: TList<TDelphiSemanticSymbolId>;
  const aId: TDelphiSemanticSymbolId): Boolean;
var
  lId: TDelphiSemanticSymbolId;
begin
  for lId in aIds do
    if lId.Value = aId.Value then
      Exit(True);

  Result := False;
end;

function MakeUsage(const aReference: TDelphiSemanticIndexedReference): TDelphiSemanticUsage;
begin
  Result := Default(TDelphiSemanticUsage);
  Result.Name := aReference.Name;
  Result.RoutineName := aReference.RoutineName;
  Result.Role := 'reference';
  Result.SectionKind := aReference.SectionKind;
  Result.SourceKind := aReference.SourceKind;
  Result.FileName := aReference.FileName;
  Result.UnitName := aReference.UnitName;
  Result.Line := aReference.Line;
  Result.Column := aReference.Column;
  Result.EndLine := aReference.EndLine;
  Result.EndColumn := aReference.EndColumn;
end;

function MakeDeclarationUsage(const aSymbol: TDelphiSemanticIndexedSymbol): TDelphiSemanticUsage;
begin
  Result := Default(TDelphiSemanticUsage);
  Result.Name := aSymbol.Name;
  Result.Role := 'declaration';
  Result.SectionKind := aSymbol.SectionKind;
  Result.SourceKind := aSymbol.SourceKind;
  Result.FileName := aSymbol.FileName;
  Result.UnitName := aSymbol.UnitName;
  Result.Line := aSymbol.Line;
  Result.Column := aSymbol.Column;
  Result.EndLine := aSymbol.Line;
  Result.EndColumn := aSymbol.Column + Length(aSymbol.Name) - 1;
end;

function SymbolIsMethodPair(const aLeft, aRight: TDelphiSemanticIndexedSymbol): Boolean;
begin
  Result := SameText(aLeft.UnitName, aRight.UnitName) and
    SameText(aLeft.OwnerName, aRight.OwnerName) and SameText(aLeft.Name, aRight.Name) and
    ((SameText(aLeft.Kind, 'method') and SameText(aRight.Kind, 'routine')) or
    (SameText(aLeft.Kind, 'routine') and SameText(aRight.Kind, 'method')));
end;

function ReferenceMatchesSymbol(const aReference: TDelphiSemanticIndexedReference;
  const aSymbol: TDelphiSemanticIndexedSymbol): Boolean;
begin
  if (aReference.Status = 'resolved') and (aReference.SymbolId.Value = aSymbol.Id.Value) then
    Exit(True);

  Result := SameText(aSymbol.Kind, 'var') and (aSymbol.OwnerName <> '') and
    SameText(aReference.Name, aSymbol.Name) and SameText(aReference.UnitName, aSymbol.UnitName) and
    SameText(aReference.RoutineName, aSymbol.OwnerName);
end;

function BuildResultForSymbol(const aIndex: TDelphiSemanticProjectSymbolIndex;
  const aSymbol: TDelphiSemanticIndexedSymbol): TDelphiSemanticUsageResult;
var
  lSymbol: TDelphiSemanticIndexedSymbol;
  lReference: TDelphiSemanticIndexedReference;
  lUsages: TList<TDelphiSemanticUsage>;
begin
  lUsages := TList<TDelphiSemanticUsage>.Create;
  try
    for lSymbol in aIndex.Symbols do
      if (lSymbol.Id.Value = aSymbol.Id.Value) or SymbolIsMethodPair(lSymbol, aSymbol) then
        lUsages.Add(MakeDeclarationUsage(lSymbol));
    for lReference in aIndex.References do
      if ReferenceMatchesSymbol(lReference, aSymbol) then
        lUsages.Add(MakeUsage(lReference));

    Result := Default(TDelphiSemanticUsageResult);
    Result.Status := 'resolved';
    Result.Symbol := aSymbol;
    Result.Usages := lUsages.ToArray;
  finally
    lUsages.Free;
  end;
end;

function ResolveSymbolByName(const aIndex: TDelphiSemanticProjectSymbolIndex; const aName: string;
  out aSymbol: TDelphiSemanticIndexedSymbol; out aDiagnostic: string): string;
var
  lCount: Integer;
  lSymbol: TDelphiSemanticIndexedSymbol;
  lSymbolIds: TList<TDelphiSemanticSymbolId>;
begin
  lCount := 0;
  aDiagnostic := '';
  lSymbolIds := TList<TDelphiSemanticSymbolId>.Create;
  try
    for lSymbol in aIndex.Symbols do
      if SymbolMatchesName(lSymbol, aName) and not SymbolIdInList(lSymbolIds, lSymbol.Id) then
      begin
        Inc(lCount);
        lSymbolIds.Add(lSymbol.Id);
        if lCount = 1 then
          aSymbol := lSymbol;
      end;
  finally
    lSymbolIds.Free;
  end;

  if lCount = 1 then
    Exit('resolved');
  if lCount > 1 then
  begin
    aSymbol := Default(TDelphiSemanticIndexedSymbol);
    aDiagnostic := 'Multiple visible symbols named "' + aName + '" were found.';
    Exit('ambiguous');
  end;

  aSymbol := Default(TDelphiSemanticIndexedSymbol);
  aDiagnostic := 'No visible symbol named "' + aName + '" was found.';
  Result := 'unresolved';
end;

function ResolveSymbolByDefinition(const aIndex: TDelphiSemanticProjectSymbolIndex;
  const aDefinition: TDelphiSemanticSymbolQueryResult; out aSymbol: TDelphiSemanticIndexedSymbol;
  out aDiagnostic: string): string;
var
  lCount: Integer;
  lSymbol: TDelphiSemanticIndexedSymbol;
begin
  lCount := 0;
  aDiagnostic := '';
  for lSymbol in aIndex.Symbols do
    if SameText(lSymbol.Name, aDefinition.Name) and
      (SameText(lSymbol.Kind, aDefinition.Kind) or
      (SameText(lSymbol.Kind, 'routine') and SameText(aDefinition.Kind, 'method'))) and
      SameText(lSymbol.UnitName, aDefinition.UnitName) and (lSymbol.Line = aDefinition.Line) and
      (lSymbol.Column = aDefinition.Column) then
    begin
      Inc(lCount);
      aSymbol := lSymbol;
    end;

  if lCount = 1 then
    Exit('resolved');

  if lCount > 1 then
  begin
    aSymbol := Default(TDelphiSemanticIndexedSymbol);
    aDiagnostic := 'Multiple indexed symbols match the requested source position.';
    Exit('ambiguous');
  end;

  aSymbol := Default(TDelphiSemanticIndexedSymbol);
  aDiagnostic := 'No indexed symbol matches the requested source position.';
  Result := 'unresolved';
end;

class function TDelphiSemanticUsageFinder.FindUsagesAtPosition(
  const aContext: TDelphiSemanticSymbolQueryContext; const aFileName: string; const aLine,
  aColumn: Integer): TDelphiSemanticUsageResult;
var
  lDefinition: TDelphiSemanticSymbolQueryResult;
  lDiagnostic: string;
  lIndex: TDelphiSemanticProjectSymbolIndex;
  lStatus: string;
  lSymbol: TDelphiSemanticIndexedSymbol;
begin
  lDefinition := TDelphiSemanticSymbolQuery.FindDefinitionAtPosition(aContext, aFileName, aLine,
    aColumn);
  if not lDefinition.Found then
    Exit(MakeDiagnosticResult(lDefinition.Status, 'No symbol found at the requested position.'));

  lIndex := TDelphiSemanticProjectSymbolIndexer.Build(aContext);
  lStatus := ResolveSymbolByDefinition(lIndex, lDefinition, lSymbol, lDiagnostic);
  if lStatus <> 'resolved' then
    Exit(MakeDiagnosticResult(lStatus, lDiagnostic));

  Result := BuildResultForSymbol(lIndex, lSymbol);
end;

class function TDelphiSemanticUsageFinder.FindUsagesByName(
  const aContext: TDelphiSemanticSymbolQueryContext; const aName: string):
  TDelphiSemanticUsageResult;
var
  lDiagnostic: string;
  lIndex: TDelphiSemanticProjectSymbolIndex;
  lStatus: string;
  lSymbol: TDelphiSemanticIndexedSymbol;
begin
  lIndex := TDelphiSemanticProjectSymbolIndexer.Build(aContext);
  lStatus := ResolveSymbolByName(lIndex, aName, lSymbol, lDiagnostic);
  if lStatus <> 'resolved' then
    Exit(MakeDiagnosticResult(lStatus, lDiagnostic));

  Result := BuildResultForSymbol(lIndex, lSymbol);
end;

end.
