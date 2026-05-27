unit DelphiSemantics.SemanticGraph;

interface

uses
  DelphiSemantics.Model, DelphiSemantics.ProjectContext;

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

  TDelphiSemanticGraphBuildMetrics = record
    UnitCount: Integer;
    SymbolCount: Integer;
    BuildMilliseconds: Int64;
  end;

  TDelphiSemanticSemanticGraph = class
  private
    fMetrics: TDelphiSemanticGraphBuildMetrics;
    fProjectId: TDelphiSemanticProjectGraphId;
    fSymbols: TArray<TDelphiSemanticGraphSymbol>;
    fUnits: TArray<TDelphiSemanticGraphUnit>;
  public
    constructor Create(const aProjectId: TDelphiSemanticProjectGraphId;
      const aUnits: TArray<TDelphiSemanticGraphUnit>;
      const aSymbols: TArray<TDelphiSemanticGraphSymbol>;
      const aMetrics: TDelphiSemanticGraphBuildMetrics);
    function FindUnitByName(const aUnitName: string; out aUnit: TDelphiSemanticGraphUnit):
      Boolean;
    function Symbols: TArray<TDelphiSemanticGraphSymbol>;
    function Units: TArray<TDelphiSemanticGraphUnit>;
    property Metrics: TDelphiSemanticGraphBuildMetrics read fMetrics;
    property ProjectId: TDelphiSemanticProjectGraphId read fProjectId;
  end;

  TDelphiSemanticSemanticGraphBuilder = record
  public
    class function Build(const aProject: TDelphiSemanticProjectInfo;
      const aUnitModels: TArray<TDelphiSemanticUnitModel>): TDelphiSemanticSemanticGraph;
      static;
  end;

implementation

uses
  System.Diagnostics, System.Generics.Collections, System.Hash, System.IOUtils, System.SysUtils;

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

function UnitSourceRange(const aModel: TDelphiSemanticUnitModel): TDelphiSemanticSourceRange;
begin
  Result := Default(TDelphiSemanticSourceRange);
  Result.FileName := aModel.FileName;
end;

function BuildUnit(const aProjectId: TDelphiSemanticProjectGraphId;
  const aModel: TDelphiSemanticUnitModel): TDelphiSemanticGraphUnit;
begin
  Result := Default(TDelphiSemanticGraphUnit);
  Result.Id := MakeUnitId(aProjectId, aModel);
  Result.ProjectId := aProjectId;
  Result.UnitName := aModel.UnitName;
  Result.FileName := aModel.FileName;
  Result.SourceKind := 'project';
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
end;

procedure AddDeclarationSymbols(const aSymbols: TList<TDelphiSemanticGraphSymbol>;
  const aUnit: TDelphiSemanticGraphUnit; const aModel: TDelphiSemanticUnitModel);
var
  lDeclaration: TDelphiSemanticDeclaration;
  lSymbol: TDelphiSemanticGraphSymbol;
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
  end;
end;

constructor TDelphiSemanticSemanticGraph.Create(
  const aProjectId: TDelphiSemanticProjectGraphId;
  const aUnits: TArray<TDelphiSemanticGraphUnit>;
  const aSymbols: TArray<TDelphiSemanticGraphSymbol>;
  const aMetrics: TDelphiSemanticGraphBuildMetrics);
begin
  inherited Create;
  fProjectId := aProjectId;
  fUnits := Copy(aUnits);
  fSymbols := Copy(aSymbols);
  fMetrics := aMetrics;
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

function TDelphiSemanticSemanticGraph.Symbols: TArray<TDelphiSemanticGraphSymbol>;
begin
  Result := Copy(fSymbols);
end;

function TDelphiSemanticSemanticGraph.Units: TArray<TDelphiSemanticGraphUnit>;
begin
  Result := Copy(fUnits);
end;

class function TDelphiSemanticSemanticGraphBuilder.Build(
  const aProject: TDelphiSemanticProjectInfo;
  const aUnitModels: TArray<TDelphiSemanticUnitModel>): TDelphiSemanticSemanticGraph;
var
  lMetrics: TDelphiSemanticGraphBuildMetrics;
  lUnit: TDelphiSemanticGraphUnit;
  lProjectId: TDelphiSemanticProjectGraphId;
  lStopwatch: TStopwatch;
  lSymbols: TList<TDelphiSemanticGraphSymbol>;
  lUnits: TList<TDelphiSemanticGraphUnit>;
  lModel: TDelphiSemanticUnitModel;
begin
  lStopwatch := TStopwatch.StartNew;
  lSymbols := nil;
  lUnits := TList<TDelphiSemanticGraphUnit>.Create;
  try
    lSymbols := TList<TDelphiSemanticGraphSymbol>.Create;
    lProjectId := MakeProjectId(aProject);
    for lModel in aUnitModels do
      if lModel.Success and (lModel.UnitName <> '') then
      begin
        lUnit := BuildUnit(lProjectId, lModel);
        lUnits.Add(lUnit);
        AddDeclarationSymbols(lSymbols, lUnit, lModel);
      end;

    lStopwatch.Stop;
    lMetrics := Default(TDelphiSemanticGraphBuildMetrics);
    lMetrics.UnitCount := lUnits.Count;
    lMetrics.SymbolCount := lSymbols.Count;
    lMetrics.BuildMilliseconds := lStopwatch.ElapsedMilliseconds;
    Result := TDelphiSemanticSemanticGraph.Create(lProjectId, lUnits.ToArray,
      lSymbols.ToArray, lMetrics);
  finally
    lSymbols.Free;
    lUnits.Free;
  end;
end;

end.
