unit DelphiSemantics.NameFlow.SdkEffects;

interface

uses
  System.Generics.Collections,
  DelphiSemantics.Model, DelphiSemantics.NameConsumers;

type
  TNameSdkProgress = reference to procedure(const aStage, aSource: string;
    const aElapsedMilliseconds: Int64);

  TNameSdkGenerationRequest = record
    SdkRoot: string;
    CompilerFileName: string;
    CompilerVersion: string;
    ExpectedSourceIdentity: string;
    ExpectedCompilerHash: string;
    Platform: string;
    Configuration: string;
    UnitOptions: TArray<TDelphiSemanticModelOptions>;
    MaxSources: Integer;
    MaxSourceBytes: Int64;
    MaxFactNodes: Integer;
    MaxRoutines: Integer;
    MaxEdges: Integer;
    MaxWorkItems: Integer;
    MaxUnitSourceBytes: Int64;
    OnProgress: TNameSdkProgress;
  end;

  TNameSdkSourceCoverage = record
    FileName: string;
    Reason: string;
    ByteCount: Int64;
    Covered: Boolean;
  end;

  TNameSdkEffectEntry = record
    DeclarationId: string;
    QualifiedName: string;
    FileName: string;
    UnitName: string;
    OwnerName: string;
    RoutineName: string;
    Line: Integer;
    Column: Integer;
    BodyComplete: Boolean;
    Effect: TNameSdkEffect;
    CalleeNames: TArray<string>;
  end;

  TNameSdkStatistics = record
    SourceCount: Integer;
    RoutineCount: Integer;
    PassiveCount: Integer;
    OpaqueCount: Integer;
    MetadataCount: Integer;
    ProducerCount: Integer;
    StoreCount: Integer;
    CallbackCount: Integer;
    FixedPointPasses: Integer;
    SourceBytes: Int64;
    FactNodes: Integer;
    CandidateEdges: Integer;
    HashPasses: Integer;
    HashedBytes: Int64;
    PinnedFileCount: Integer;
    RequestedSourceCount: Integer;
    CoveredSourceCount: Integer;
    SkippedSourceCount: Integer;
    CacheLoaded: Boolean;
  end;

  // One query owns this catalog and excludes SDK writers. Validate before query and
  // publication; mismatch permanently poisons lookups until explicit regeneration.
  // The catalog is not thread safe. No hand-authored passive exemptions exist.
  TNameSdkCatalog = class
  private
    fRequest: TNameSdkGenerationRequest;
    fEntries: TArray<TNameSdkEffectEntry>;
    fIdentity: string;
    fReason: string;
    fValidated: Boolean;
    fInitialInputsCaptured: Boolean;
    fInitialActualInputs: string;
    fIndex: TDictionary<string, Integer>;
    fStatistics: TNameSdkStatistics;
    fCacheReason: string;
    fCoverage: TArray<TNameSdkSourceCoverage>;
    function ComputeIdentity: string;
    function ActualInputIdentity: string;
    procedure CaptureInitialActualInputs;
    procedure AddModel(const aModel: TDelphiSemanticUnitModel);
    procedure Propagate;
    procedure CountEffects;
    procedure Progress(const aStage, aSource: string; const aElapsedMilliseconds: Int64);
  public
    constructor Create(const aRequest: TNameSdkGenerationRequest);
    destructor Destroy; override;
    procedure Generate;
    function ValidateCurrentIdentity: Boolean;
    function InputsUnchangedSinceAnalysis: Boolean;
    function Lookup(const aDeclarationId: string): TNameSdkEffect;
    function JoinCandidates(const aDeclarationIds: TArray<string>;
      const aCandidatesComplete: Boolean): TNameSdkEffect;
    function Entries: TArray<TNameSdkEffectEntry>;
    function SourceCoverage: TArray<TNameSdkSourceCoverage>;
    function RequestedSourceFileNames: TArray<string>;
    function ArtifactKey: string;
    function Save(const aFileName: string): Boolean;
    function TryLoad(const aFileName: string): Boolean;
    property Identity: string read fIdentity;
    property Reason: string read fReason;
    property Statistics: TNameSdkStatistics read fStatistics;
    property CacheReason: string read fCacheReason;
    property Validated: Boolean read fValidated;
  end;

// Positive consumer descriptions only; this does not certify passivity or binding.
function PositivePrimitiveNameConsumer(const aQualifiedName: string;
  out aEffect: TNameSdkEffect): Boolean;

// Bootstrap/review helper only. Production requests require a previously retained pin.
function CaptureSdkSourceIdentity(const aSdkRoot: string): string;

implementation

uses
  System.Classes, System.Diagnostics, System.Hash, System.IOUtils, System.StrUtils, System.SysUtils,
  AutoFree,
  DelphiSemantics.Cache, DelphiSemantics.NameFlow.Facts, DelphiSemantics.NameFlow.SdkArtifact;

const
  cSdkGeneratorVersion = 'ds803-sdk-effects-v2/primitive-v1/full-body-v1';

type
  ESdkGenerationBudget = class(Exception);
  ESdkExpectedPinMissing = class(Exception);
  ESdkExpectedPinMismatch = class(Exception);

function CaptureSdkSourceIdentity(const aSdkRoot: string): string;
var
  g: TGarbos;
  lText: TStringBuilder;
  lFiles: TArray<string>;
  lFile, lRoot: string;
begin
  if not TDirectory.Exists(aSdkRoot) then
    raise EArgumentException.Create('SDK source root is unavailable');
  lRoot := IncludeTrailingPathDelimiter(TPath.GetFullPath(aSdkRoot));
  lFiles := TDirectory.GetFiles(lRoot, '*', TSearchOption.soAllDirectories);
  TArray.Sort<string>(lFiles);
  GC(lText, TStringBuilder.Create, g);
  lText.AppendLine('ds803-sdk-source-pin-v1');
  for lFile in lFiles do
    lText.AppendLine(LowerCase(ExtractRelativePath(lRoot, TPath.GetFullPath(lFile))))
      .AppendLine(THashSHA2.GetHashStringFromFile(lFile));
  Result := THashSHA2.GetHashString(lText.ToString);
end;

function InsideRoot(const aFileName, aRoot: string): Boolean;
begin
  Result := SameText(ExcludeTrailingPathDelimiter(TPath.GetFullPath(aFileName)),
    ExcludeTrailingPathDelimiter(TPath.GetFullPath(aRoot))) or
    StartsText(IncludeTrailingPathDelimiter(TPath.GetFullPath(aRoot)), TPath.GetFullPath(aFileName));
end;

function PrimitiveEffect(const aName: string; out aEffect: TNameSdkEffect): Boolean;
var
  lName: string;
begin
  Result := True;
  lName := LowerCase(aName);
  aEffect := TNameSdkEffect.PassiveEffect;
  aEffect.MetadataFormalOrdinal := 0;
  if MatchText(lName, ['system.tobject.classname', 'system.tobject.classnameis',
    'system.tobject.qualifiedclassname', 'system.tobject.unitname', 'system.tobject.unitscope']) then
  begin
    aEffect.Channels := [TNameEffectChannel.ReceiverMetadata, TNameEffectChannel.ProducedName];
    aEffect.Targets := [TNameEffectTargetKind.ClassType];
    if MatchText(lName, ['system.tobject.qualifiedclassname', 'system.tobject.unitname',
      'system.tobject.unitscope']) then
      Include(aEffect.Targets, TNameEffectTargetKind.UnitName);
    if lName = 'system.tobject.classnameis' then
    begin
      Exclude(aEffect.Channels, TNameEffectChannel.ProducedName);
      Include(aEffect.Channels, TNameEffectChannel.NameFormal);
      aEffect.Precision.FormalOrdinal := 1;
      aEffect.Precision.Grammar := TNameConsumerGrammar.Identifier;
    end;
  end else if MatchText(lName, ['system.typinfo.getenumname', 'system.typinfo.getenumvalue',
    'system.typinfo.settostring', 'system.typinfo.stringtoset',
    'system.rtti.trttienumerationtype.getname', 'system.rtti.trttienumerationtype.getvalue']) then
  begin
    aEffect.Channels := [TNameEffectChannel.ArgumentMetadata, TNameEffectChannel.ProducedName];
    aEffect.Targets := [TNameEffectTargetKind.EnumType, TNameEffectTargetKind.EnumElement];
    aEffect.MetadataFormalOrdinal := 1;
    if MatchText(lName, ['system.typinfo.getenumvalue', 'system.typinfo.stringtoset',
      'system.rtti.trttienumerationtype.getvalue']) then
    begin
      Include(aEffect.Channels, TNameEffectChannel.NameFormal);
      aEffect.Precision.FormalOrdinal := 2;
      aEffect.Precision.Grammar := TNameConsumerGrammar.Identifier;
      Exclude(aEffect.Channels, TNameEffectChannel.ProducedName);
      if lName = 'system.rtti.trttienumerationtype.getvalue' then
      begin
        aEffect.Precision.FormalOrdinal := 1;
        aEffect.MetadataFormalOrdinal := -1;
      end;
    end;
  end else if MatchText(lName, ['system.rtti.trtticontext.gettypes',
    'system.rtti.trttipackage.gettypes']) then
  begin
    aEffect.Channels := [TNameEffectChannel.GlobalMetadata, TNameEffectChannel.ProducedName];
    aEffect.Targets := [Low(TNameEffectTargetKind)..High(TNameEffectTargetKind)];
    aEffect.MetadataFormalOrdinal := -1;
  end else if MatchText(lName, ['system.tobject.methodname', 'system.tobject.methodaddress',
    'system.tobject.fieldaddress', 'system.tobject.classinfo', 'system.typinfo.gettypename',
    'system.typinfo.getpropinfo', 'system.typinfo.getproplist', 'system.typinfo.getpropname',
    'system.rtti.trttinamedobject.getname', 'system.rtti.trttitype.getqualifiedname',
    'system.rtti.trttitype.getfield', 'system.rtti.trttitype.getfields',
    'system.rtti.trttitype.getmethod', 'system.rtti.trttitype.getmethods',
    'system.rtti.trttitype.getproperty', 'system.rtti.trttitype.getproperties',
    'system.rtti.trtticontext.findtype']) then
  begin
    aEffect.Channels := [TNameEffectChannel.ReceiverMetadata, TNameEffectChannel.ProducedName];
    aEffect.Targets := [Low(TNameEffectTargetKind)..High(TNameEffectTargetKind)];
    if StartsText('system.typinfo.', lName) then
    begin
      aEffect.Channels := [TNameEffectChannel.ArgumentMetadata, TNameEffectChannel.ProducedName];
      aEffect.MetadataFormalOrdinal := 1;
    end;
    if MatchText(lName, ['system.tobject.methodaddress', 'system.tobject.fieldaddress',
      'system.rtti.trttitype.getfield', 'system.rtti.trttitype.getmethod',
      'system.rtti.trttitype.getproperty', 'system.rtti.trtticontext.findtype']) then
    begin
      Include(aEffect.Channels, TNameEffectChannel.NameFormal);
      aEffect.Precision.FormalOrdinal := 1;
      aEffect.Precision.Grammar := TNameConsumerGrammar.Identifier;
      if lName = 'system.rtti.trtticontext.findtype' then
        aEffect.Precision.Grammar := TNameConsumerGrammar.QualifiedIdentifier;
    end;
  end else if MatchText(lName, ['system.tobject.dispatch', 'system.rtti.trttimethod.invoke',
    'system.rtti.tvirtualinterface.create', 'system.rtti.tvirtualmethodinterceptor.create',
    'system.variants.dispinvoke']) then
  begin
    aEffect := TNameSdkEffect.OpaqueEffect('sdk-dispatch-primitive');
    aEffect.Channels := aEffect.Channels + [TNameEffectChannel.Callback,
      TNameEffectChannel.ArgumentMetadata];
  end else if MatchText(lName, ['winapi.windows.getprocaddress', 'winapi.windows.findresourcea',
    'winapi.windows.findresourcew', 'winapi.windows.findresourceexa', 'winapi.windows.findresourceexw',
    'winapi.windows.findwindowa', 'winapi.windows.findwindoww', 'winapi.windows.getclassnamea',
    'winapi.windows.getclassnamew', 'winapi.windows.registerclassa', 'winapi.windows.registerclassw',
    'winapi.windows.registerclassexa', 'winapi.windows.registerclassexw',
    'winapi.activex.clsidfromprogid', 'winapi.activex.progidfromclsid']) then
  begin
    aEffect := TNameSdkEffect.OpaqueEffect('sdk-os-name-primitive');
    Include(aEffect.Channels, TNameEffectChannel.NameFormal);
    aEffect.Precision.Grammar := TNameConsumerGrammar.Unknown;
  end else
    Result := False;
  if Result and (aEffect.Reason = '') then
    aEffect.Reason := 'sdk-name-metadata-primitive';
end;

function PositivePrimitiveNameConsumer(const aQualifiedName: string;
  out aEffect: TNameSdkEffect): Boolean;
begin
  // Reviewed Delphi 23.0 declarations. These descriptions identify possible
  // name-taking overloads only; callers must establish the visible SDK group.
  aEffect := TNameSdkEffect.PassiveEffect;
  aEffect.Precision.Grammar := TNameConsumerGrammar.Identifier;
  if MatchText(aQualifiedName, ['System.Classes.GetClass', 'System.Classes.FindClass',
    'System.Classes.TComponent.FindComponent']) then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.FormalOrdinal := 1;
    if SameText(aQualifiedName, 'System.Classes.TComponent.FindComponent') then
      aEffect.Targets := [TNameEffectTargetKind.Member]
    else
      aEffect.Targets := [TNameEffectTargetKind.ClassType];
    Exit(True);
  end;
  if MatchText(aQualifiedName, ['System.TypInfo.PropType', 'System.TypInfo.PropIsType',
    'System.TypInfo.IsStoredProp', 'System.TypInfo.IsPublishedProp',
    'System.TypInfo.GetPropInfo', 'System.TypInfo.GetPropValue', 'System.TypInfo.SetPropValue',
    'System.TypInfo.GetOrdProp', 'System.TypInfo.SetOrdProp',
    'System.TypInfo.GetEnumProp', 'System.TypInfo.SetEnumProp',
    'System.TypInfo.GetSetProp', 'System.TypInfo.SetSetProp',
    'System.TypInfo.GetObjectProp', 'System.TypInfo.SetObjectProp', 'System.TypInfo.GetObjectPropClass',
    'System.TypInfo.GetStrProp', 'System.TypInfo.SetStrProp',
    'System.TypInfo.GetAnsiStrProp', 'System.TypInfo.SetAnsiStrProp',
    'System.TypInfo.GetWideStrProp', 'System.TypInfo.SetWideStrProp',
    'System.TypInfo.GetUnicodeStrProp', 'System.TypInfo.SetUnicodeStrProp',
    'System.TypInfo.GetRawByteStrProp', 'System.TypInfo.SetRawByteStrProp',
    'System.TypInfo.GetFloatProp', 'System.TypInfo.SetFloatProp',
    'System.TypInfo.GetVariantProp', 'System.TypInfo.SetVariantProp',
    'System.TypInfo.GetMethodProp', 'System.TypInfo.SetMethodProp',
    'System.TypInfo.GetInt64Prop', 'System.TypInfo.SetInt64Prop',
    'System.TypInfo.GetInterfaceProp', 'System.TypInfo.SetInterfaceProp',
    'System.TypInfo.GetDynArrayProp', 'System.TypInfo.SetDynArrayProp']) then
  begin
    aEffect.Channels := [TNameEffectChannel.ArgumentMetadata, TNameEffectChannel.NameFormal];
    aEffect.MetadataFormalOrdinal := 1;
    aEffect.Precision.FormalOrdinal := 2;
    aEffect.Targets := [TNameEffectTargetKind.Member];
    Exit(True);
  end;
  if SameText(aQualifiedName, 'Winapi.Windows.GetProcAddress') then
  begin
    aEffect.Channels := [TNameEffectChannel.NameFormal];
    aEffect.Precision.FormalOrdinal := 2;
    aEffect.Precision.Grammar := TNameConsumerGrammar.ExportName;
    aEffect.Targets := [TNameEffectTargetKind.Routine];
    Exit(True);
  end;
  Result := PrimitiveEffect(aQualifiedName, aEffect) and
    (TNameEffectChannel.NameFormal in aEffect.Channels);
  if not Result then
    Exit;
  // A broad metadata producer target set is not the name formal's domain.
  if MatchText(aQualifiedName, ['System.Rtti.TRttiType.GetField',
    'System.Rtti.TRttiType.GetMethod', 'System.Rtti.TRttiType.GetProperty',
    'System.TObject.MethodAddress', 'System.TObject.FieldAddress']) then
    aEffect.Targets := [TNameEffectTargetKind.Member]
  else if SameText(aQualifiedName, 'System.Rtti.TRttiContext.FindType') then
    aEffect.Targets := [TNameEffectTargetKind.ClassType, TNameEffectTargetKind.OtherType,
      TNameEffectTargetKind.EnumType, TNameEffectTargetKind.UnitName];
end;


function RoutineQualifiedName(const aUnitName: string; const aRoutine: TDelphiSemanticRoutine): string;
begin
  if (aRoutine.OwnerName <> '') and not StartsText(aRoutine.OwnerName + '.', aRoutine.Name) then
    Result := aUnitName + '.' + aRoutine.OwnerName + '.' + aRoutine.Name
  else
    Result := aUnitName + '.' + aRoutine.Name;
end;

function LastName(const aName: string): string;
begin
  Result := Copy(aName, LastDelimiter('.', aName) + 1, MaxInt);
end;

function EffectEqual(const aLeft, aRight: TNameSdkEffect): Boolean;
begin
  Result := (aLeft.Channels = aRight.Channels) and (aLeft.Targets = aRight.Targets) and
    (aLeft.MetadataFormalOrdinal = aRight.MetadataFormalOrdinal) and
    (aLeft.Precision.FormalOrdinal = aRight.Precision.FormalOrdinal) and
    (aLeft.Precision.Grammar = aRight.Precision.Grammar);
end;

constructor TNameSdkCatalog.Create(const aRequest: TNameSdkGenerationRequest);
begin
  inherited Create;
  fRequest := aRequest;
  fRequest.UnitOptions := Copy(aRequest.UnitOptions);
  fIndex := TDictionary<string, Integer>.Create;
  fReason := 'sdk-generation-unproved';
  if fRequest.MaxUnitSourceBytes = 0 then
    fRequest.MaxUnitSourceBytes := 64 * 1024;
  if fRequest.MaxSources = 0 then
    fRequest.MaxSources := 64;
  if fRequest.MaxSourceBytes = 0 then
    fRequest.MaxSourceBytes := 64 * 1024 * 1024;
  if fRequest.MaxFactNodes = 0 then
    fRequest.MaxFactNodes := 2000000;
  if fRequest.MaxRoutines = 0 then
    fRequest.MaxRoutines := 50000;
  if fRequest.MaxEdges = 0 then
    fRequest.MaxEdges := 500000;
  if fRequest.MaxWorkItems = 0 then
    fRequest.MaxWorkItems := 2000000;
  // Freeze mutable request arrays; the admitted compiler evidence already returns copies.
  for var i := 0 to High(fRequest.UnitOptions) do
  begin
    fRequest.UnitOptions[i].Defines := Copy(aRequest.UnitOptions[i].Defines);
    fRequest.UnitOptions[i].SearchPaths := Copy(aRequest.UnitOptions[i].SearchPaths);
    fRequest.UnitOptions[i].IncludePaths := Copy(aRequest.UnitOptions[i].IncludePaths);
    fRequest.UnitOptions[i].UnitAliases := Copy(aRequest.UnitOptions[i].UnitAliases);
    fRequest.UnitOptions[i].UnitScopeNames := Copy(aRequest.UnitOptions[i].UnitScopeNames);
    fRequest.UnitOptions[i].ProjectSourceFileNames := Copy(aRequest.UnitOptions[i].ProjectSourceFileNames);
    fRequest.UnitOptions[i].PossibleUnitSearchPaths := Copy(aRequest.UnitOptions[i].PossibleUnitSearchPaths);
    fRequest.UnitOptions[i].PossibleUnitScopeNames := Copy(aRequest.UnitOptions[i].PossibleUnitScopeNames);
  end;
end;

destructor TNameSdkCatalog.Destroy;
begin
  fIndex.Free;
  inherited;
end;

function TNameSdkCatalog.ActualInputIdentity: string;
begin
  Result := THashSHA2.GetHashString(CaptureSdkSourceIdentity(fRequest.SdkRoot) + #10 +
    THashSHA2.GetHashStringFromFile(fRequest.CompilerFileName));
end;

procedure TNameSdkCatalog.CaptureInitialActualInputs;
begin
  if fInitialInputsCaptured then
    Exit;
  fInitialInputsCaptured := True;
  try
    fInitialActualInputs := ActualInputIdentity;
  except
    on e: Exception do
      // An unreadable initial input permanently denies the relaxed currentness
      // check. It never becomes reviewed-pin authority or a new baseline.
      fInitialActualInputs := '';
  end;
end;

function TNameSdkCatalog.InputsUnchangedSinceAnalysis: Boolean;
begin
  Result := False;
  if not fInitialInputsCaptured or (fInitialActualInputs = '') then
    Exit;
  try
    Result := SameText(fInitialActualInputs, ActualInputIdentity);
  except
    on e: Exception do
      // Current unreadable inputs cannot establish an unchanged query input.
      Result := False;
  end;
end;

function TNameSdkCatalog.ComputeIdentity: string;
var
  lFiles: TArray<string>;
  lFile, lCompilerHash, lSourceIdentity: string;
  lTimer: TStopwatch;
begin
  if (fRequest.ExpectedSourceIdentity = '') or (fRequest.ExpectedCompilerHash = '') then
    raise ESdkExpectedPinMissing.Create('Reviewed SDK source and compiler pins are required');
  if not TDirectory.Exists(fRequest.SdkRoot) or not TFile.Exists(fRequest.CompilerFileName) or
    (fRequest.CompilerVersion = '') or (fRequest.Platform = '') or (fRequest.Configuration = '') then
    raise EArgumentException.Create('SDK/compiler/platform/configuration identity is incomplete');
  Result := ArtifactKey;
  lTimer := TStopwatch.StartNew;
  Progress('identity-start', '', 0);
  lCompilerHash := THashSHA2.GetHashStringFromFile(fRequest.CompilerFileName);
  lSourceIdentity := CaptureSdkSourceIdentity(fRequest.SdkRoot);
  if not SameText(lCompilerHash, fRequest.ExpectedCompilerHash) or
    not SameText(lSourceIdentity, fRequest.ExpectedSourceIdentity) then
    raise ESdkExpectedPinMismatch.Create('SDK source/compiler differs from the reviewed pin');
  lFiles := TDirectory.GetFiles(fRequest.SdkRoot, '*', TSearchOption.soAllDirectories);
  Inc(fStatistics.HashPasses);
  fStatistics.PinnedFileCount := Length(lFiles) + 1;
  Inc(fStatistics.HashedBytes, TFile.GetSize(fRequest.CompilerFileName));
  for lFile in lFiles do
  begin
    Inc(fStatistics.HashedBytes, TFile.GetSize(lFile));
  end;
  Progress('identity-complete', '', lTimer.ElapsedMilliseconds);
end;

procedure TNameSdkCatalog.AddModel(const aModel: TDelphiSemanticUnitModel);
var
  g: TGarbos;
  lNames: TList<string>;
  lRoutines: TList<TDelphiSemanticRoutine>;
  lSignatures: TDictionary<string, TDelphiSemanticRoutine>;
  lRoutineNodes: TDictionary<string, Integer>;
  lStack: TStack<Integer>;
  lRoutine: TDelphiSemanticRoutine;
  lEntry: TNameSdkEffectEntry;
  lFacts: IDelphiNameFlowFacts;
  lNode, lChild: TDelphiNameFlowNode;
  lPrimitive: TNameSdkEffect;
  lBodyFound, lSupported: Boolean;
  i, lNodeId, lChildId, lEntryCount: Integer;
  lInclude, lHeading: string;
begin
  for lInclude in aModel.IncludeFileNames do
    if not InsideRoot(lInclude, fRequest.SdkRoot) then
      raise EInvalidOpException.Create('SDK include is outside the pinned SDK root: ' + lInclude);
  lFacts := aModel.NameFlowFacts;
  if lFacts <> nil then
  begin
    if Pos('name-flow-fact-budget-exceeded', lFacts.CoverageReason) > 0 then
      raise ESdkGenerationBudget.Create('AST fact nodes');
    if lFacts.NodeCount > fRequest.MaxFactNodes - fStatistics.FactNodes then
      raise ESdkGenerationBudget.Create('AST fact nodes');
    Inc(fStatistics.FactNodes, lFacts.NodeCount);
  end;
  GC(lNames, TList<string>.Create, g);
  GC(lRoutines, TList<TDelphiSemanticRoutine>.Create, g);
  GC(lSignatures, TDictionary<string, TDelphiSemanticRoutine>.Create, g);
  GC(lRoutineNodes, TDictionary<string, Integer>.Create, g);
  GC(lStack, TStack<Integer>.Create, g);
  for lRoutine in aModel.Routines do
    if lRoutine.ScopeId <> '' then
      lSignatures.AddOrSetValue(lRoutine.ScopeId, lRoutine);
  if lFacts <> nil then
    for i := 1 to lFacts.NodeCount do
    begin
      lNode := lFacts.NodeById(i);
      if lNode.Kind = TDelphiNameFlowNodeKind.Routine then
      begin
        lRoutineNodes.AddOrSetValue(lNode.ScopeId, i);
        if not lSignatures.TryGetValue(lNode.ScopeId, lRoutine) then
        begin
          lRoutine := Default(TDelphiSemanticRoutine);
          lRoutine.Name := lNode.Name;
          lRoutine.OwnerName := lNode.OwnerType;
          if Pos('.', lNode.Name) > 0 then
          begin
            lRoutine.OwnerName := Copy(lNode.Name, 1, LastDelimiter('.', lNode.Name) - 1);
            lRoutine.Name := LastName(lNode.Name);
          end;
          lRoutine.ScopeId := lNode.ScopeId;
          lRoutine.FileName := lNode.FileName;
          lRoutine.Line := lNode.Line;
          lRoutine.Column := lNode.Column;
          // Unknown signature cannot prove absence of implicit conversion effects.
          lRoutine.ReturnType := '#unverified-signature';
        end;
        lRoutines.Add(lRoutine);
      end;
    end;
  // Degraded models can still retain exact primitive identities, never passivity.
  if lRoutines.Count = 0 then
    lRoutines.AddRange(aModel.Routines);
  lEntryCount := Length(fEntries);
  if lRoutines.Count > fRequest.MaxRoutines - lEntryCount then
    raise ESdkGenerationBudget.Create('routine count');
  SetLength(fEntries, lEntryCount + lRoutines.Count);
  for lRoutine in lRoutines do
  begin
    lEntry := Default(TNameSdkEffectEntry);
    lEntry.UnitName := aModel.UnitName;
    lEntry.OwnerName := lRoutine.OwnerName;
    lEntry.RoutineName := lRoutine.Name;
    lEntry.QualifiedName := RoutineQualifiedName(aModel.UnitName, lRoutine);
    lEntry.FileName := lRoutine.FileName;
    if lEntry.FileName = '' then
      lEntry.FileName := aModel.FileName;
    lEntry.Line := lRoutine.Line;
    lEntry.Column := lRoutine.Column;
    lEntry.DeclarationId := lEntry.QualifiedName + '@' + lRoutine.ScopeId + ':' +
      IntToStr(lRoutine.Line) + ':' + IntToStr(lRoutine.Column);
    lEntry.Effect := TNameSdkEffect.OpaqueEffect('sdk-body-or-binding-unproved');
    lNames.Clear;
    lStack.Clear;
    lBodyFound := False;
    lSupported := False;
    lHeading := lRoutine.ScopeId;
    if (lFacts <> nil) and lRoutineNodes.TryGetValue(lHeading, lNodeId) then
    begin
      lNode := lFacts.NodeById(lNodeId);
      lBodyFound := lNode.BodyComplete;
      lSupported := aModel.Success and lFacts.Complete and lFacts.ConfigurationComplete and
        (lRoutine.OwnerName = '') and (lRoutine.ReturnType = '') and
        (Length(lRoutine.Parameters) = 0) and (Length(aModel.Locals) = 0);
      for lChildId in lNode.Children do
      begin
        lChild := lFacts.NodeById(lChildId);
        if lChild.SyntaxKind = 'statements' then
          lStack.Push(lChildId);
      end;
      while lStack.Count > 0 do
      begin
        lNode := lFacts.NodeById(lStack.Pop);
        if lNode.Kind = TDelphiNameFlowNodeKind.Routine then
          Continue;
        if lNode.Kind in [TDelphiNameFlowNodeKind.PotentialCall,
          TDelphiNameFlowNodeKind.IdentifierValue, TDelphiNameFlowNodeKind.Call] then
        begin
          if (lNode.Name <> '') and not SameText(lNode.Name, 'Result') and
            not SameText(lNode.Name, LastName(lRoutine.Name)) then
            if not lNames.Contains(lNode.Name) then
              lNames.Add(lNode.Name);
          // Spelling unions propagate observations; they never prove binding closure.
          if not SameText(lNode.Name, 'Result') then
            lSupported := False;
        end;
        if lNode.Kind in [TDelphiNameFlowNodeKind.Unknown, TDelphiNameFlowNodeKind.PropertyAccess,
          TDelphiNameFlowNodeKind.RaiseValue] then
          lSupported := False;
        if lNode.Kind = TDelphiNameFlowNodeKind.RaiseValue then
        begin
          Include(lEntry.Effect.Channels, TNameEffectChannel.ArgumentMetadata);
          Include(lEntry.Effect.Channels, TNameEffectChannel.ProducedName);
        end;
        if MatchText(lNode.SyntaxKind, ['addr', 'anonymousmethod']) then
          Include(lEntry.Effect.Channels, TNameEffectChannel.Callback);
        if MatchText(lNode.SyntaxKind, ['deref', 'index', 'indexed', 'dot']) then
          Include(lEntry.Effect.Channels, TNameEffectChannel.Store);
        // Until implicit conversions/initializers have binding facts, only an empty
        // free procedure with no parameters or locals can prove absence of effects.
        if not MatchText(lNode.SyntaxKind, ['statements', 'statement', 'emptystatement']) then
          lSupported := False;
        for lChildId in lNode.Children do
          lStack.Push(lChildId);
      end;
    end;
    if lSupported and lBodyFound then
      lEntry.Effect := TNameSdkEffect.PassiveEffect;
    lEntry.BodyComplete := lBodyFound;
    lEntry.CalleeNames := lNames.ToArray;
    if PrimitiveEffect(lEntry.QualifiedName, lPrimitive) then
    begin
      lEntry.Effect := lPrimitive;
      lEntry.CalleeNames := nil;
    end else if not lBodyFound then
      // Declaration/implementation signature ambiguity only broadens effects.
      lEntry.CalleeNames := lEntry.CalleeNames + [lEntry.QualifiedName];
    if not fIndex.ContainsKey(LowerCase(lEntry.DeclarationId)) then
    begin
      fIndex.Add(LowerCase(lEntry.DeclarationId), lEntryCount);
      fEntries[lEntryCount] := lEntry;
      Inc(lEntryCount);
    end;
  end;
  SetLength(fEntries, lEntryCount);
end;

procedure TNameSdkCatalog.Propagate;
var
  g: TGarbos;
  lByName: TDictionary<string, TList<Integer>>;
  lCallers: TArray<TList<Integer>>;
  lQueue: TQueue<Integer>;
  lQueued: TArray<Boolean>;
  lIndices, lQualifiedIndices: TList<Integer>;
  i, j, lCallee, lCaller: Integer;
  lName, lLookupName: string;
  lEffect: TNameSdkEffect;
begin
  GC(lByName, TDictionary<string, TList<Integer>>.Create, g);
  GC(lQueue, TQueue<Integer>.Create, g);
  SetLength(lCallers, Length(fEntries));
  SetLength(lQueued, Length(fEntries));
  for i := 0 to High(fEntries) do
  begin
    lName := 'name:' + LowerCase(LastName(fEntries[i].QualifiedName));
    if not lByName.TryGetValue(lName, lIndices) then
    begin
      GC(lIndices, TList<Integer>.Create, g);
      lByName.Add(lName, lIndices);
    end;
    lIndices.Add(i);
    lName := 'qualified:' + LowerCase(fEntries[i].QualifiedName);
    if not lByName.TryGetValue(lName, lQualifiedIndices) then
    begin
      GC(lQualifiedIndices, TList<Integer>.Create, g);
      lByName.Add(lName, lQualifiedIndices);
    end;
    lQualifiedIndices.Add(i);
    lQueue.Enqueue(i);
    lQueued[i] := True;
  end;
  for i := 0 to High(fEntries) do
    for lName in fEntries[i].CalleeNames do
    begin
      if Pos('.', lName) > 0 then
        lLookupName := 'qualified:' + LowerCase(lName)
      else
        lLookupName := 'name:' + LowerCase(lName);
      if lByName.TryGetValue(lLookupName, lIndices) then
        for j in lIndices do
        begin
          if fStatistics.CandidateEdges >= fRequest.MaxEdges then
            raise ESdkGenerationBudget.Create('candidate edges');
          Inc(fStatistics.CandidateEdges);
          if lCallers[j] = nil then
            GC(lCallers[j], TList<Integer>.Create, g);
          lCallers[j].Add(i);
        end;
    end;
  // Iterative monotone worklist: each effect bit is added at most once per routine.
  while lQueue.Count > 0 do
  begin
    if fStatistics.FixedPointPasses >= fRequest.MaxWorkItems then
      raise ESdkGenerationBudget.Create('effect worklist items');
    Inc(fStatistics.FixedPointPasses);
    lCallee := lQueue.Dequeue;
    lQueued[lCallee] := False;
    if lCallers[lCallee] = nil then
      Continue;
    for lCaller in lCallers[lCallee] do
    begin
      lEffect := TNameSdkEffect.Join([fEntries[lCaller].Effect, fEntries[lCallee].Effect], True);
      lEffect.MetadataFormalOrdinal := -1;
      lEffect.Precision.FormalOrdinal := -1;
      lEffect.Precision.Grammar := TNameConsumerGrammar.Unknown;
      if not EffectEqual(lEffect, fEntries[lCaller].Effect) then
      begin
        fEntries[lCaller].Effect := lEffect;
        if not lQueued[lCaller] then
        begin
          lQueue.Enqueue(lCaller);
          lQueued[lCaller] := True;
        end;
      end;
    end;
  end;
end;

procedure TNameSdkCatalog.CountEffects;
var
  lEntry: TNameSdkEffectEntry;
begin
  fStatistics.RoutineCount := Length(fEntries);
  for lEntry in fEntries do
  begin
    if lEntry.Effect.IsPassive then
      Inc(fStatistics.PassiveCount);
    if TNameEffectChannel.Opaque in lEntry.Effect.Channels then
      Inc(fStatistics.OpaqueCount);
    if lEntry.Effect.Channels * [TNameEffectChannel.ReceiverMetadata,
      TNameEffectChannel.ArgumentMetadata, TNameEffectChannel.GlobalMetadata] <> [] then
      Inc(fStatistics.MetadataCount);
    if TNameEffectChannel.ProducedName in lEntry.Effect.Channels then
      Inc(fStatistics.ProducerCount);
    if TNameEffectChannel.Store in lEntry.Effect.Channels then
      Inc(fStatistics.StoreCount);
    if TNameEffectChannel.Callback in lEntry.Effect.Channels then
      Inc(fStatistics.CallbackCount);
  end;
end;

procedure TNameSdkCatalog.Generate;
var
  i: Integer;
  lOptions: TDelphiSemanticModelOptions;
  lModel: TDelphiSemanticUnitModel;
  lBefore: string;
  lInclude: string;
  lTimer: TStopwatch;
begin
  CaptureInitialActualInputs;
  fValidated := False;
  fReason := '';
  fIdentity := '';
  fEntries := nil;
  fCoverage := nil;
  fIndex.Clear;
  fStatistics := Default(TNameSdkStatistics);
  try
    if (fRequest.MaxSources <= 0) or (fRequest.MaxSourceBytes <= 0) or
      (fRequest.MaxFactNodes <= 0) or (fRequest.MaxRoutines <= 0) or
      (fRequest.MaxEdges <= 0) or (fRequest.MaxWorkItems <= 0) or
      (fRequest.MaxUnitSourceBytes <= 0) then
      raise ESdkGenerationBudget.Create('nonpositive budget');
    if Length(fRequest.UnitOptions) > fRequest.MaxSources then
      raise ESdkGenerationBudget.Create('requested source count');
    // Check byte work before any AST allocation. All SDK include bytes are included
    // in this bound because preprocessing may reach an include from any selected unit.
    for lOptions in fRequest.UnitOptions do
    begin
      Inc(fStatistics.SourceBytes, TFile.GetSize(lOptions.SourceFileName));
      if fStatistics.SourceBytes > fRequest.MaxSourceBytes then
        raise ESdkGenerationBudget.Create('source bytes');
    end;
    for lInclude in TDirectory.GetFiles(fRequest.SdkRoot, '*', TSearchOption.soAllDirectories) do
    begin
      if SameText(ExtractFileExt(lInclude), '.pas') then
        Continue;
      Inc(fStatistics.SourceBytes, TFile.GetSize(lInclude));
      if fStatistics.SourceBytes > fRequest.MaxSourceBytes then
        raise ESdkGenerationBudget.Create('source and include bytes');
    end;
    lBefore := ComputeIdentity;
    fStatistics.RequestedSourceCount := Length(fRequest.UnitOptions);
    SetLength(fCoverage, Length(fRequest.UnitOptions));
    for i := 0 to High(fRequest.UnitOptions) do
    begin
      lOptions := fRequest.UnitOptions[i];
      fCoverage[i].FileName := lOptions.SourceFileName;
      fCoverage[i].ByteCount := TFile.GetSize(lOptions.SourceFileName);
      if fCoverage[i].ByteCount > fRequest.MaxUnitSourceBytes then
      begin
        fCoverage[i].Reason := 'sdk-unit-source-budget-exceeded';
        Inc(fStatistics.SkippedSourceCount);
        Progress('unit-skipped', lOptions.SourceFileName, 0);
        Continue;
      end;
      lOptions.SkipBodyAnalysis := False;
      lOptions.SkipReferenceExtraction := False;
      lOptions.WithStatementsOnly := False;
      if fStatistics.FactNodes >= fRequest.MaxFactNodes then
        raise ESdkGenerationBudget.Create('AST fact nodes');
      lOptions.NameFlowFactLimit := fRequest.MaxFactNodes - fStatistics.FactNodes;
      Progress('extract-start', lOptions.SourceFileName, 0);
      lTimer := TStopwatch.StartNew;
      lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
      Progress('extract-complete', lOptions.SourceFileName, lTimer.ElapsedMilliseconds);
      lTimer := TStopwatch.StartNew;
      AddModel(lModel);
      Progress('effects-complete', lOptions.SourceFileName, lTimer.ElapsedMilliseconds);
      Inc(fStatistics.SourceCount);
      fCoverage[i].Covered := lModel.Success and (lModel.NameFlowFacts <> nil) and
        (lModel.NameFlowFacts.NodeCount > 0);
      if fCoverage[i].Covered then
      begin
        Inc(fStatistics.CoveredSourceCount);
        if not lModel.NameFlowFacts.Complete then
          fCoverage[i].Reason := 'sdk-body-coverage-unproved: ' + lModel.NameFlowFacts.CoverageReason
        else if not lModel.NameFlowFacts.ConfigurationComplete then
          fCoverage[i].Reason := 'sdk-configuration-unproved';
      end else begin
        fCoverage[i].Reason := 'sdk-extraction-unavailable';
        Inc(fStatistics.SkippedSourceCount);
      end;
    end;
    Propagate;
    CountEffects;
    fIdentity := lBefore;
    fValidated := True;
    ValidateCurrentIdentity;
  except
    on E: ESdkExpectedPinMissing do
    begin
      fValidated := False;
      fReason := 'sdk-expected-pin-missing';
    end;
    on E: ESdkExpectedPinMismatch do
    begin
      fValidated := False;
      fReason := 'sdk-identity-mismatch';
    end;
    on E: ESdkGenerationBudget do
    begin
      fValidated := False;
      fReason := 'sdk-generation-budget-exceeded: ' + E.Message;
    end;
    on E: Exception do
    begin
      fValidated := False;
      fReason := 'sdk-generation-unproved: ' + E.ClassName + ': ' + E.Message;
    end;
  end;
end;

function TNameSdkCatalog.ValidateCurrentIdentity: Boolean;
begin
  if not fValidated then
    Exit(False);
  try
    Result := (fIdentity <> '') and (ComputeIdentity = fIdentity);
  except
    on E: ESdkExpectedPinMismatch do
    begin
      fReason := 'sdk-identity-mismatch';
      Result := False;
    end;
    on E: Exception do
    begin
      fReason := 'sdk-identity-unavailable: ' + E.ClassName + ': ' + E.Message;
      Result := False;
    end;
  end;
  if not Result then
  begin
    fValidated := False;
    if fReason = '' then
      fReason := 'sdk-identity-mismatch';
  end;
end;

function TNameSdkCatalog.Lookup(const aDeclarationId: string): TNameSdkEffect;
var
  lIndex: Integer;
begin
  if not fValidated then
    Exit(TNameSdkEffect.OpaqueEffect(fReason));
  if not fIndex.TryGetValue(LowerCase(aDeclarationId), lIndex) then
    Exit(TNameSdkEffect.OpaqueEffect('sdk-declaration-uncovered'));
  Result := fEntries[lIndex].Effect;
end;

function TNameSdkCatalog.JoinCandidates(const aDeclarationIds: TArray<string>;
  const aCandidatesComplete: Boolean): TNameSdkEffect;
var
  i: Integer;
  lEffects: TArray<TNameSdkEffect>;
begin
  SetLength(lEffects, Length(aDeclarationIds));
  for i := 0 to High(aDeclarationIds) do
    lEffects[i] := Lookup(aDeclarationIds[i]);
  Result := TNameSdkEffect.Join(lEffects, aCandidatesComplete);
end;

function TNameSdkCatalog.Entries: TArray<TNameSdkEffectEntry>;
var
  i: Integer;
begin
  Result := Copy(fEntries);
  for i := 0 to High(Result) do
  begin
    Result[i].CalleeNames := Copy(fEntries[i].CalleeNames);
    if not fValidated then
      Result[i].Effect := TNameSdkEffect.OpaqueEffect(fReason);
  end;
end;

function TNameSdkCatalog.RequestedSourceFileNames: TArray<string>;
var
  i: Integer;
begin
  // Request inventory only: it carries no extraction, body or passivity claim.
  SetLength(Result, Length(fRequest.UnitOptions));
  for i := 0 to High(fRequest.UnitOptions) do
    Result[i] := fRequest.UnitOptions[i].SourceFileName;
end;

function TNameSdkCatalog.SourceCoverage: TArray<TNameSdkSourceCoverage>;
begin
  Result := Copy(fCoverage);
end;

function TNameSdkCatalog.ArtifactKey: string;
var
  g: TGarbos;
  lText: TStringBuilder;
  lOptions: TDelphiSemanticModelOptions;
  lValue: string;
begin
  GC(lText, TStringBuilder.Create, g);
  lText.AppendLine(cSdkGeneratorVersion).AppendLine(TPath.GetFullPath(fRequest.SdkRoot))
    .AppendLine(TDelphiSemanticCacheIdentityBuilder.ModelParserVersion)
    .AppendLine(TPath.GetFullPath(fRequest.CompilerFileName))
    .AppendLine(LowerCase(fRequest.ExpectedCompilerHash)).AppendLine(LowerCase(fRequest.ExpectedSourceIdentity))
    .AppendLine(fRequest.CompilerVersion).AppendLine(fRequest.Platform).AppendLine(fRequest.Configuration);
  for lOptions in fRequest.UnitOptions do
  begin
    if not InsideRoot(lOptions.SourceFileName, fRequest.SdkRoot) or
      (Length(lOptions.ProjectSourceFileNames) <> 0) or (lOptions.CompilerDefineEvidence <> nil) or
      (lOptions.CompilerDefineRequest.ProjectFileName <> '') or
      (lOptions.CompilerDefineRequest.MainSourceFileName <> '') or
      (lOptions.CompilerDefineEvidenceReason <> '') then
      raise EArgumentException.Create('SDK catalog request contains project-dependent evidence');
    lText.AppendLine(lOptions.SourceFileName);
    for lValue in lOptions.Defines do
      lText.AppendLine('define=' + lValue);
    for lValue in lOptions.SearchPaths do
    begin
      if not InsideRoot(lValue, fRequest.SdkRoot) then
        raise EArgumentException.Create('SDK catalog search path is outside the pinned source root');
      lText.AppendLine('search=' + lValue);
    end;
    for lValue in lOptions.IncludePaths do
    begin
      if not InsideRoot(lValue, fRequest.SdkRoot) then
        raise EArgumentException.Create('SDK catalog include path is outside the pinned source root');
      lText.AppendLine('include=' + lValue);
    end;
    for lValue in lOptions.UnitAliases do
      lText.AppendLine('alias=' + lValue);
    for lValue in lOptions.UnitScopeNames do
      lText.AppendLine('scope=' + lValue);
    for lValue in lOptions.PossibleUnitSearchPaths do
    begin
      if not InsideRoot(lValue, fRequest.SdkRoot) then
        raise EArgumentException.Create('SDK catalog possible-source path is outside the pinned source root');
      lText.AppendLine('possible-search=' + lValue);
    end;
    for lValue in lOptions.PossibleUnitScopeNames do
      lText.AppendLine('possible-scope=' + lValue);
    lText.AppendLine(BoolToStr(lOptions.WritableTypedConstants, True))
      .AppendLine(BoolToStr(lOptions.SelectedConfigurationOnly, True))
      .AppendLine(BoolToStr(lOptions.ProjectContextApplied, True))
      .AppendLine(BoolToStr(lOptions.DefineEvidenceComplete, True))
      .AppendLine(lOptions.InstalledSdkRoot)
      .AppendLine(lOptions.CompilerDefineRequest.Configuration)
      .AppendLine(lOptions.CompilerDefineRequest.Platform)
      .AppendLine(lOptions.CompilerDefineRequest.DelphiVersion);
  end;
  Result := THashSHA2.GetHashString(lText.ToString);
end;

function TNameSdkCatalog.Save(const aFileName: string): Boolean;
var
  lArtifact: TNameSdkArtifact;
begin
  if not fValidated then
  begin
    fCacheReason := 'sdk-artifact-view-unvalidated';
    Exit(False);
  end;
  lArtifact := Default(TNameSdkArtifact);
  lArtifact.Key := ArtifactKey;
  lArtifact.Identity := fIdentity;
  lArtifact.SourcePin := fRequest.ExpectedSourceIdentity;
  lArtifact.CompilerPin := fRequest.ExpectedCompilerHash;
  lArtifact.UnitSourceCeiling := fRequest.MaxUnitSourceBytes;
  lArtifact.Entries := Entries;
  lArtifact.Coverage := SourceCoverage;
  lArtifact.Statistics := fStatistics;
  Result := TNameSdkArtifactStore.Save(aFileName, lArtifact, fCacheReason);
end;

function TNameSdkCatalog.TryLoad(const aFileName: string): Boolean;
var
  i: Integer;
  lArtifact: TNameSdkArtifact;
  lLimits: TNameSdkArtifactLimits;
  lCurrentStats: TNameSdkStatistics;
  lIdentity: string;
begin
  CaptureInitialActualInputs;
  Result := False;
  fValidated := False;
  fEntries := nil;
  fCoverage := nil;
  fIndex.Clear;
  fStatistics := Default(TNameSdkStatistics);
  try
    lLimits.MaxEntries := fRequest.MaxRoutines;
    lLimits.MaxSources := fRequest.MaxSources;
    lLimits.MaxEdges := fRequest.MaxEdges;
    if not TNameSdkArtifactStore.TryLoad(aFileName, ArtifactKey, lLimits, lArtifact, fCacheReason) then
    begin
      fReason := fCacheReason;
      Exit;
    end;
    if (lArtifact.SourcePin <> fRequest.ExpectedSourceIdentity) or
      (lArtifact.CompilerPin <> fRequest.ExpectedCompilerHash) or
      (Length(lArtifact.Coverage) <> Length(fRequest.UnitOptions)) then
      raise EConvertError.Create('Artifact pin/source inventory mismatch');
    for i := 0 to High(lArtifact.Coverage) do
      if not SameText(lArtifact.Coverage[i].FileName, fRequest.UnitOptions[i].SourceFileName) then
        raise EConvertError.Create('Artifact source inventory mismatch');
    for i := 0 to High(lArtifact.Entries) do
    begin
      if not InsideRoot(lArtifact.Entries[i].FileName, fRequest.SdkRoot) or
        fIndex.ContainsKey(LowerCase(lArtifact.Entries[i].DeclarationId)) then
        raise EConvertError.Create('Artifact declaration inventory mismatch');
      fIndex.Add(LowerCase(lArtifact.Entries[i].DeclarationId), i);
    end;
    lIdentity := ComputeIdentity;
    if lIdentity <> lArtifact.Identity then
      raise EConvertError.Create('Artifact semantic identity mismatch');
    lCurrentStats := fStatistics;
    fEntries := lArtifact.Entries;
    fCoverage := lArtifact.Coverage;
    fStatistics := lArtifact.Statistics;
    fStatistics.HashPasses := lCurrentStats.HashPasses;
    fStatistics.HashedBytes := lCurrentStats.HashedBytes;
    fStatistics.PinnedFileCount := lCurrentStats.PinnedFileCount;
    fStatistics.CacheLoaded := True;
    fIdentity := lIdentity;
    fReason := '';
    fCacheReason := '';
    fValidated := True;
    Result := True;
  except
    on E: ESdkExpectedPinMissing do
      fReason := 'sdk-expected-pin-missing';
    on E: ESdkExpectedPinMismatch do
      fReason := 'sdk-identity-mismatch';
    on E: Exception do
      fReason := 'sdk-artifact-invalid: ' + E.ClassName + ': ' + E.Message;
  end;
  if not Result then
    fCacheReason := fReason;
end;

procedure TNameSdkCatalog.Progress(const aStage, aSource: string; const aElapsedMilliseconds: Int64);
begin
  if Assigned(fRequest.OnProgress) then
    fRequest.OnProgress(aStage, aSource, aElapsedMilliseconds);
end;

end.
