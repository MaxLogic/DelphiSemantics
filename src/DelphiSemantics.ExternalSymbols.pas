unit DelphiSemantics.ExternalSymbols;

interface

uses
  DelphiSemantics.Cache, DelphiSemantics.CompilerProfile, DelphiSemantics.Model,
  DelphiSemantics.Resolve.TypeResolver;

type
  TDelphiSemanticExternalSymbolMetrics = record
    IntrinsicLookupCount: Integer;
    IntrinsicResolvedCount: Integer;
    RtlUnitLookupCount: Integer;
    RtlUnitLoadCount: Integer;
    RtlSourceDiscoveryIndexBuildCount: Integer;
    RtlTypeLookupCount: Integer;
    RtlTypeResolvedCount: Integer;
    RtlTypeIndexBuildCount: Integer;
    CacheHits: Integer;
    CacheMisses: Integer;
  end;

  TDelphiSemanticExternalSymbolResult = record
    Found: Boolean;
    Status: string;
    ReasonCode: string;
    Reason: string;
    Name: string;
    Kind: string;
    TypeName: string;
    OwnerName: string;
    SourceKind: string;
    Signature: string;
    FileName: string;
    UnitModel: TDelphiSemanticUnitModel;
    TypeIdentity: TDelphiSemanticTypeIdentity;
  end;

  IDelphiSemanticExternalSymbolServiceData = interface
    ['{076AE15E-6D9E-4133-B4A4-E466482EE1FC}']
    function Metrics: TDelphiSemanticExternalSymbolMetrics;
    function ResolveIntrinsic(const aName: string): TDelphiSemanticExternalSymbolResult;
    function ResolveRtlUnit(const aUnitName: string): TDelphiSemanticExternalSymbolResult;
    function ResolveType(const aTypeName: string): TDelphiSemanticExternalSymbolResult;
  end;

  TDelphiSemanticExternalSymbolService = record
  private
    fData: IDelphiSemanticExternalSymbolServiceData;
  public
    class function Open(const aCache: TDelphiSemanticUnitCache;
      const aProfile: TDelphiSemanticCompilerProfile): TDelphiSemanticExternalSymbolService;
      static;
    function Metrics: TDelphiSemanticExternalSymbolMetrics;
    function ResolveIntrinsic(const aName: string): TDelphiSemanticExternalSymbolResult;
    function ResolveRtlUnit(const aUnitName: string): TDelphiSemanticExternalSymbolResult;
    function ResolveType(const aTypeName: string): TDelphiSemanticExternalSymbolResult;
  end;

implementation

uses
  System.Generics.Collections, System.SysUtils,
  MaxLogic.StrUtils,
  DelphiSemantics.ProjectContext, DelphiSemantics.SemanticGraph;

type
  TDelphiSemanticExternalSymbolServiceData = class(TInterfacedObject,
    IDelphiSemanticExternalSymbolServiceData)
  private
    fCache: TDelphiSemanticUnitCache;
    fIntrinsicByName: TDictionary<string, TDelphiSemanticIntrinsicSymbol>;
    fLock: TObject;
    fLoadedUnitsByName: TDictionary<string, TDelphiSemanticUnitModel>;
    fMetrics: TDelphiSemanticExternalSymbolMetrics;
    fProfile: TDelphiSemanticCompilerProfile;
    fRtlSourceDiscovery: TDelphiSemanticRtlSourceDiscovery;
    fTypeIndex: TDelphiSemanticTypeIdentityIndex;
    fTypeIndexValid: Boolean;
    function LoadedModels: TArray<TDelphiSemanticUnitModel>;
    procedure AddLoadedUnitModel(const aModel: TDelphiSemanticUnitModel); overload;
    procedure AddLoadedUnitModel(const aLookupName: string;
      const aModel: TDelphiSemanticUnitModel); overload;
    function BuildTypeIndex: TDelphiSemanticTypeIdentityIndex;
    procedure CaptureCacheMetrics;
    function LoadRtlUnit(const aUnitName: string; out aModel: TDelphiSemanticUnitModel):
      Boolean;
    function TryResolveIntrinsic(const aName: string;
      out aResult: TDelphiSemanticExternalSymbolResult): Boolean;
    class function IntrinsicResult(const aSymbol: TDelphiSemanticIntrinsicSymbol):
      TDelphiSemanticExternalSymbolResult; static;
    class function RtlUnitResult(const aModel: TDelphiSemanticUnitModel):
      TDelphiSemanticExternalSymbolResult; static;
    class function TypeResult(const aIdentity: TDelphiSemanticTypeIdentity):
      TDelphiSemanticExternalSymbolResult; static;
    class function UnresolvedResult(const aName, aReasonCode, aReason: string):
      TDelphiSemanticExternalSymbolResult; static;
  public
    constructor Create(const aCache: TDelphiSemanticUnitCache;
      const aProfile: TDelphiSemanticCompilerProfile);
    destructor Destroy; override;
    function Metrics: TDelphiSemanticExternalSymbolMetrics;
    function ResolveIntrinsic(const aName: string): TDelphiSemanticExternalSymbolResult;
    function ResolveRtlUnit(const aUnitName: string): TDelphiSemanticExternalSymbolResult;
    function ResolveType(const aTypeName: string): TDelphiSemanticExternalSymbolResult;
  end;

procedure TDelphiSemanticExternalSymbolServiceData.AddLoadedUnitModel(
  const aModel: TDelphiSemanticUnitModel);
begin
  if aModel.UnitName = '' then
    Exit;

  fLoadedUnitsByName.AddOrSetValue(aModel.UnitName, aModel);
  fTypeIndexValid := False;
end;

procedure TDelphiSemanticExternalSymbolServiceData.AddLoadedUnitModel(const aLookupName: string;
  const aModel: TDelphiSemanticUnitModel);
var
  lLookupName: string;
begin
  AddLoadedUnitModel(aModel);
  lLookupName := Trim(aLookupName);
  if (lLookupName <> '') and (aModel.UnitName <> '') and not SameText(lLookupName,
    aModel.UnitName) then
    fLoadedUnitsByName.AddOrSetValue(lLookupName, aModel);
end;

function TDelphiSemanticExternalSymbolServiceData.BuildTypeIndex:
  TDelphiSemanticTypeIdentityIndex;
var
  lGraph: TDelphiSemanticSemanticGraph;
  lProject: TDelphiSemanticProjectInfo;
begin
  if fTypeIndexValid then
    Exit(fTypeIndex);

  lProject := Default(TDelphiSemanticProjectInfo);
  lProject.ProjectName := fProfile.Name;
  lGraph := TDelphiSemanticSemanticGraphBuilder.Build(lProject, LoadedModels);
  try
    fTypeIndex := TDelphiSemanticTypeResolver.BuildIndex(lGraph);
    fTypeIndexValid := True;
    Inc(fMetrics.RtlTypeIndexBuildCount);
    Result := fTypeIndex;
  finally
    lGraph.Free;
  end;
end;

procedure TDelphiSemanticExternalSymbolServiceData.CaptureCacheMetrics;
begin
  if fCache = nil then
    Exit;

  fMetrics.CacheHits := fCache.Metrics.CacheHits;
  fMetrics.CacheMisses := fCache.Metrics.CacheMisses;
end;

constructor TDelphiSemanticExternalSymbolServiceData.Create(
  const aCache: TDelphiSemanticUnitCache; const aProfile: TDelphiSemanticCompilerProfile);
var
  lIntrinsic: TDelphiSemanticIntrinsicSymbol;
  lModel: TDelphiSemanticUnitModel;
begin
  inherited Create;
  fCache := aCache;
  fProfile := aProfile;
  try
    fLock := TObject.Create;
    fIntrinsicByName := TDictionary<string, TDelphiSemanticIntrinsicSymbol>.Create(
      TFastCaseAwareComparer.OrdinalIgnoreCase);
    fLoadedUnitsByName := TDictionary<string, TDelphiSemanticUnitModel>.Create(
      TFastCaseAwareComparer.OrdinalIgnoreCase);
    fRtlSourceDiscovery := TDelphiSemanticRtlSourceDiscovery.Create(fProfile.RtlSourceRoot);

    for lIntrinsic in fProfile.IntrinsicSymbols do
      if lIntrinsic.Name <> '' then
        fIntrinsicByName.AddOrSetValue(lIntrinsic.Name, lIntrinsic);

    for lModel in fProfile.RtlSourceUnitModels do
      AddLoadedUnitModel(lModel);

    CaptureCacheMetrics;
  except
    fLock.Free;
    fLock := nil;
    fLoadedUnitsByName.Free;
    fLoadedUnitsByName := nil;
    fRtlSourceDiscovery.Free;
    fRtlSourceDiscovery := nil;
    fIntrinsicByName.Free;
    fIntrinsicByName := nil;
    raise;
  end;
end;

destructor TDelphiSemanticExternalSymbolServiceData.Destroy;
begin
  fRtlSourceDiscovery.Free;
  fLoadedUnitsByName.Free;
  fIntrinsicByName.Free;
  fLock.Free;
  inherited;
end;

class function TDelphiSemanticExternalSymbolServiceData.IntrinsicResult(
  const aSymbol: TDelphiSemanticIntrinsicSymbol): TDelphiSemanticExternalSymbolResult;
begin
  Result := Default(TDelphiSemanticExternalSymbolResult);
  Result.Found := True;
  Result.Status := 'resolved';
  Result.Name := aSymbol.Name;
  Result.Kind := aSymbol.Kind;
  Result.TypeName := aSymbol.TypeName;
  Result.OwnerName := aSymbol.OwnerName;
  Result.SourceKind := 'compiler-intrinsic';
  Result.Signature := aSymbol.Signature;
end;

function TDelphiSemanticExternalSymbolServiceData.LoadedModels:
  TArray<TDelphiSemanticUnitModel>;
var
  lIndex: Integer;
  lModel: TDelphiSemanticUnitModel;
  lSeen: TDictionary<string, Byte>;
  lKey: string;
begin
  lSeen := TDictionary<string, Byte>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
  try
    SetLength(Result, fLoadedUnitsByName.Count);
    lIndex := 0;
    for lModel in fLoadedUnitsByName.Values do
    begin
      lKey := lModel.UnitName + '|' + lModel.FileName;
      if (lModel.UnitName = '') or lSeen.ContainsKey(lKey) then
        Continue;
      lSeen.Add(lKey, 0);
      Result[lIndex] := lModel;
      Inc(lIndex);
    end;
    SetLength(Result, lIndex);
  finally
    lSeen.Free;
  end;
end;

function TDelphiSemanticExternalSymbolServiceData.LoadRtlUnit(const aUnitName: string;
  out aModel: TDelphiSemanticUnitModel): Boolean;
var
  lProfile: TDelphiSemanticCompilerProfile;
  lSourceFileNames: TArray<string>;
begin
  aModel := Default(TDelphiSemanticUnitModel);
  if fLoadedUnitsByName.TryGetValue(aUnitName, aModel) then
    Exit(True);

  if (fCache = nil) or (fProfile.RtlSourceRoot = '') then
    Exit(False);

  lSourceFileNames := fRtlSourceDiscovery.DiscoverSourceFiles([aUnitName]);
  fMetrics.RtlSourceDiscoveryIndexBuildCount := fRtlSourceDiscovery.RecursiveIndexBuildCount;
  lProfile := TDelphiSemanticCompilerProfileBuilder.ProfileForTargetFromRtlSourceFiles(
    fCache, fProfile.Name, fProfile.DelphiVersion, fProfile.Platform, fProfile.RtlSourceRoot,
    lSourceFileNames);
  CaptureCacheMetrics;
  if Length(lProfile.RtlSourceUnitModels) = 0 then
    Exit(False);

  aModel := lProfile.RtlSourceUnitModels[0];
  AddLoadedUnitModel(aUnitName, aModel);
  Inc(fMetrics.RtlUnitLoadCount);
  Result := True;
end;

function TDelphiSemanticExternalSymbolServiceData.Metrics:
  TDelphiSemanticExternalSymbolMetrics;
begin
  TMonitor.Enter(fLock);
  try
    CaptureCacheMetrics;
    Result := fMetrics;
  finally
    TMonitor.Exit(fLock);
  end;
end;

function TDelphiSemanticExternalSymbolServiceData.ResolveIntrinsic(
  const aName: string): TDelphiSemanticExternalSymbolResult;
begin
  TMonitor.Enter(fLock);
  try
    Inc(fMetrics.IntrinsicLookupCount);
    if TryResolveIntrinsic(aName, Result) then
    begin
      Inc(fMetrics.IntrinsicResolvedCount);
      Exit;
    end;

    Result := UnresolvedResult(aName, 'EXTERNAL_INTRINSIC_NOT_FOUND',
      'No compiler intrinsic named "' + aName + '" was found.');
  finally
    TMonitor.Exit(fLock);
  end;
end;

function TDelphiSemanticExternalSymbolServiceData.ResolveRtlUnit(
  const aUnitName: string): TDelphiSemanticExternalSymbolResult;
var
  lModel: TDelphiSemanticUnitModel;
  lUnitName: string;
begin
  TMonitor.Enter(fLock);
  try
    Inc(fMetrics.RtlUnitLookupCount);
    lUnitName := Trim(aUnitName);
    if LoadRtlUnit(lUnitName, lModel) then
      Exit(RtlUnitResult(lModel));

    Result := UnresolvedResult(aUnitName, 'EXTERNAL_RTL_UNIT_NOT_FOUND',
      'No source-available RTL unit named "' + aUnitName + '" was found.');
  finally
    TMonitor.Exit(fLock);
  end;
end;

function TDelphiSemanticExternalSymbolServiceData.ResolveType(
  const aTypeName: string): TDelphiSemanticExternalSymbolResult;
var
  lIndex: TDelphiSemanticTypeIdentityIndex;
  lIntrinsic: TDelphiSemanticExternalSymbolResult;
  lResult: TDelphiSemanticTypeLookupResult;
begin
  TMonitor.Enter(fLock);
  try
    Inc(fMetrics.RtlTypeLookupCount);

    if TryResolveIntrinsic(aTypeName, lIntrinsic) then
    begin
      Inc(fMetrics.RtlTypeResolvedCount);
      Exit(lIntrinsic);
    end;

    lIndex := BuildTypeIndex;
    lResult := lIndex.ResolveSimpleName(aTypeName);
    if lResult.Found then
    begin
      Inc(fMetrics.RtlTypeResolvedCount);
      Exit(TypeResult(lResult.Identity));
    end;

    Result := UnresolvedResult(aTypeName, lResult.ReasonCode, lResult.Reason);
  finally
    TMonitor.Exit(fLock);
  end;
end;

function TDelphiSemanticExternalSymbolServiceData.TryResolveIntrinsic(const aName: string;
  out aResult: TDelphiSemanticExternalSymbolResult): Boolean;
var
  lName: string;
  lSymbol: TDelphiSemanticIntrinsicSymbol;
begin
  lName := Trim(aName);
  if fIntrinsicByName.TryGetValue(lName, lSymbol) then
  begin
    aResult := IntrinsicResult(lSymbol);
    Exit(True);
  end;

  aResult := Default(TDelphiSemanticExternalSymbolResult);
  Result := False;
end;

class function TDelphiSemanticExternalSymbolServiceData.RtlUnitResult(
  const aModel: TDelphiSemanticUnitModel): TDelphiSemanticExternalSymbolResult;
begin
  Result := Default(TDelphiSemanticExternalSymbolResult);
  Result.Found := True;
  Result.Status := 'resolved';
  Result.Name := aModel.UnitName;
  Result.Kind := 'unit';
  Result.OwnerName := 'rtl';
  Result.SourceKind := 'rtl-source';
  Result.FileName := aModel.FileName;
  Result.UnitModel := aModel;
end;

class function TDelphiSemanticExternalSymbolServiceData.TypeResult(
  const aIdentity: TDelphiSemanticTypeIdentity): TDelphiSemanticExternalSymbolResult;
begin
  Result := Default(TDelphiSemanticExternalSymbolResult);
  Result.Found := True;
  Result.Status := 'resolved';
  Result.Name := aIdentity.Name;
  Result.Kind := aIdentity.Kind;
  Result.TypeName := aIdentity.CanonicalName;
  Result.OwnerName := aIdentity.UnitName;
  Result.SourceKind := 'rtl-source';
  Result.FileName := aIdentity.SourceRange.FileName;
  Result.TypeIdentity := aIdentity;
end;

class function TDelphiSemanticExternalSymbolServiceData.UnresolvedResult(const aName,
  aReasonCode, aReason: string): TDelphiSemanticExternalSymbolResult;
begin
  Result := Default(TDelphiSemanticExternalSymbolResult);
  Result.Found := False;
  Result.Status := 'unresolved';
  Result.ReasonCode := aReasonCode;
  Result.Reason := aReason;
  Result.Name := aName;
end;

function TDelphiSemanticExternalSymbolService.Metrics:
  TDelphiSemanticExternalSymbolMetrics;
begin
  if fData = nil then
    Exit(Default(TDelphiSemanticExternalSymbolMetrics));

  Result := fData.Metrics;
end;

class function TDelphiSemanticExternalSymbolService.Open(const aCache: TDelphiSemanticUnitCache;
  const aProfile: TDelphiSemanticCompilerProfile): TDelphiSemanticExternalSymbolService;
begin
  Result.fData := TDelphiSemanticExternalSymbolServiceData.Create(aCache, aProfile);
end;

function TDelphiSemanticExternalSymbolService.ResolveIntrinsic(
  const aName: string): TDelphiSemanticExternalSymbolResult;
begin
  if fData = nil then
    Exit(TDelphiSemanticExternalSymbolServiceData.UnresolvedResult(aName,
      'EXTERNAL_SERVICE_CLOSED', 'External symbol service is not open.'));

  Result := fData.ResolveIntrinsic(aName);
end;

function TDelphiSemanticExternalSymbolService.ResolveRtlUnit(
  const aUnitName: string): TDelphiSemanticExternalSymbolResult;
begin
  if fData = nil then
    Exit(TDelphiSemanticExternalSymbolServiceData.UnresolvedResult(aUnitName,
      'EXTERNAL_SERVICE_CLOSED', 'External symbol service is not open.'));

  Result := fData.ResolveRtlUnit(aUnitName);
end;

function TDelphiSemanticExternalSymbolService.ResolveType(
  const aTypeName: string): TDelphiSemanticExternalSymbolResult;
begin
  if fData = nil then
    Exit(TDelphiSemanticExternalSymbolServiceData.UnresolvedResult(aTypeName,
      'EXTERNAL_SERVICE_CLOSED', 'External symbol service is not open.'));

  Result := fData.ResolveType(aTypeName);
end;

end.
