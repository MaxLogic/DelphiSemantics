unit DelphiSemantics.ProjectSession;

interface

uses
  DelphiSemantics.Model, DelphiSemantics.ProjectContext, DelphiSemantics.SemanticGraph,
  DelphiSemantics.Snapshot, DelphiSemantics.WithBinding;

type
  TDelphiSemanticProjectSession = class;

  TDelphiSemanticProjectSessionStatus = (psUnavailable, psOpen, psInvalidProject);

  TDelphiSemanticProjectSessionResult = record
    Success: Boolean;
    Status: TDelphiSemanticProjectSessionStatus;
    Provenance: string;
    Session: TDelphiSemanticProjectSession;
    Diagnostics: TArray<TDelphiSemanticDiagnostic>;
  end;

  TDelphiSemanticSessionChange = record
    FileName: string;
    ChangeKind: string;
  end;

  TDelphiSemanticSessionInvalidationPlan = record
    RequiresFullSessionRebuild: Boolean;
    ContextInvalidated: Boolean;
    IncludeGraphInvalidated: Boolean;
    LookupMemoizationInvalidated: Boolean;
    AffectedUnitFiles: TArray<string>;
    AffectedUnitNames: TArray<string>;
    Reasons: TArray<string>;
  end;

  TDelphiSemanticProjectSnapshotBuildMetrics = record
    UnitCount: Integer;
    SymbolCount: Integer;
    ReferenceCount: Integer;
    WithStatementCount: Integer;
    BuildMilliseconds: Int64;
  end;

  TDelphiSemanticProjectSession = class
  private
    fDiagnostics: TArray<TDelphiSemanticDiagnostic>;
    fLastSnapshotBuildMetrics: TDelphiSemanticProjectSnapshotBuildMetrics;
    fLastSemanticGraphBuildMetrics: TDelphiSemanticGraphBuildMetrics;
    fOptions: TDelphiSemanticOptions;
    fProject: TDelphiSemanticProjectInfo;
    fProvenance: string;
    fStatus: TDelphiSemanticProjectSessionStatus;
  public
    constructor Create(const aOptions: TDelphiSemanticOptions;
      const aProject: TDelphiSemanticProjectInfo;
      const aDiagnostics: TArray<TDelphiSemanticDiagnostic>;
      const aStatus: TDelphiSemanticProjectSessionStatus; const aProvenance: string);
    function BuildSemanticGraph: TDelphiSemanticSemanticGraph;
    function BuildSnapshot: TDelphiProjectSnapshot;
    function BuildWithBindingFacts: TDelphiSemanticProjectWithBindingFacts;
    function PlanInvalidation(const aChanges: TArray<TDelphiSemanticSessionChange>):
      TDelphiSemanticSessionInvalidationPlan;
    class function Open(const aOptions: TDelphiSemanticOptions):
      TDelphiSemanticProjectSessionResult; static;
    property Diagnostics: TArray<TDelphiSemanticDiagnostic> read fDiagnostics;
    property LastSnapshotBuildMetrics: TDelphiSemanticProjectSnapshotBuildMetrics
      read fLastSnapshotBuildMetrics;
    property LastSemanticGraphBuildMetrics: TDelphiSemanticGraphBuildMetrics
      read fLastSemanticGraphBuildMetrics;
    property Options: TDelphiSemanticOptions read fOptions;
    property Project: TDelphiSemanticProjectInfo read fProject;
    property Provenance: string read fProvenance;
    property Status: TDelphiSemanticProjectSessionStatus read fStatus;
  end;

implementation

uses
  System.Diagnostics, System.Generics.Collections, System.Hash, System.IOUtils,
  System.JSON, System.SysUtils,
  DelphiSemantics.Cache, DelphiSemantics.Cache.Sqlite, DelphiSemantics.Version,
  MaxLogic.StrUtils;

const
  cProjectFactsCacheSchemaVersion = 'remove-with-project-facts-v1';
  cSnapshotDeclarationKindAlias = 'alias';
  cSnapshotDeclarationKindTypeAlias = 'type-alias';
  cSnapshotSymbolFlagIsDefault = 1;
  cSnapshotSymbolFlagIsIndexed = 2;
  cSnapshotSymbolKindLocal = 'local';
  cSnapshotSymbolKindParameter = 'parameter';
  cSnapshotSymbolKindRoutine = 'routine';
  cSnapshotWithFlagHasScopedDeclaration = 1;

function MainModelOptions(const aProject: TDelphiSemanticProjectInfo):
  TDelphiSemanticModelOptions;
begin
  Result := Default(TDelphiSemanticModelOptions);
  Result.SourceFileName := aProject.MainSourceFileName;
  Result.Defines := aProject.Defines;
  Result.SearchPaths := aProject.SourceLookupPaths;
  Result.ProjectContextApplied := True;
end;

procedure ApplyProjectMainUnitName(const aProject: TDelphiSemanticProjectInfo;
  var aModel: TDelphiSemanticUnitModel);
begin
  if aModel.Success and (aModel.UnitName = '') and
    SameText(aModel.FileName, aProject.MainSourceFileName) then
    aModel.UnitName := aProject.ProjectName;
end;

function ExtractUnitModel(const aProject: TDelphiSemanticProjectInfo; const aFileName: string):
  TDelphiSemanticUnitModel;
var
  lOptions: TDelphiSemanticModelOptions;
begin
  lOptions := MainModelOptions(aProject);
  lOptions.SourceFileName := aFileName;
  Result := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  ApplyProjectMainUnitName(aProject, Result);
end;

function CacheOptionsFromSessionOptions(const aOptions: TDelphiSemanticOptions):
  TDelphiSemanticCacheOptions;
begin
  Result := Default(TDelphiSemanticCacheOptions);
  Result.SqliteCacheFileName := aOptions.SqliteCacheFileName;
  Result.CompilerProfileName := Format('ProjectSession-%s-%s-%s',
    [aOptions.DelphiVersion, aOptions.Platform, aOptions.Configuration]);
  Result.DelphiVersion := aOptions.DelphiVersion;
  Result.Configuration := aOptions.Configuration;
  Result.Platform := aOptions.Platform;
end;

function ExtractProjectUnitModel(const aProject: TDelphiSemanticProjectInfo;
  const aFileName: string; const aCache: TDelphiSemanticUnitCache;
  const aSkipBodyAnalysis: Boolean;
  out aIdentity: TDelphiSemanticUnitCacheIdentity):
  TDelphiSemanticUnitModel; overload;
var
  lAccessResult: TDelphiSemanticUnitCacheAccessResult;
  lOptions: TDelphiSemanticModelOptions;
begin
  aIdentity := Default(TDelphiSemanticUnitCacheIdentity);
  lOptions := MainModelOptions(aProject);
  lOptions.SourceFileName := aFileName;
  lOptions.SkipBodyAnalysis := aSkipBodyAnalysis;
  if aCache = nil then
  begin
    Result := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
    ApplyProjectMainUnitName(aProject, Result);
    Exit;
  end;

  lAccessResult := aCache.GetOrBuildUnitModelWithStatus(lOptions,
    function(const aBuildOptions: TDelphiSemanticModelOptions): TDelphiSemanticUnitModel
    begin
      Result := TDelphiSemanticUnitModelExtractor.ExtractFromFile(aBuildOptions);
      ApplyProjectMainUnitName(aProject, Result);
    end);
  aIdentity := lAccessResult.Identity;
  Result := lAccessResult.Model;
  ApplyProjectMainUnitName(aProject, Result);
end;

function ProjectModelFileNames(const aProject: TDelphiSemanticProjectInfo):
  TArray<string>;
var
  lFileName: string;
  lFiles: TList<string>;
  lSeen: TDictionary<string, Byte>;
  lSourceFileName: string;
begin
  lFiles := TList<string>.Create;
  lSeen := TDictionary<string, Byte>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
  try
    if aProject.MainSourceFileName <> '' then
    begin
      lSourceFileName := TPath.GetFullPath(aProject.MainSourceFileName);
      lSeen.AddOrSetValue(lSourceFileName, 0);
      lFiles.Add(lSourceFileName);
    end;

    for lFileName in aProject.SourceFileNames do
    begin
      lSourceFileName := TPath.GetFullPath(lFileName);
      if lSeen.ContainsKey(lSourceFileName) then
        Continue;
      lSeen.Add(lSourceFileName, 0);
      lFiles.Add(lSourceFileName);
    end;
    Result := lFiles.ToArray;
  finally
    lSeen.Free;
    lFiles.Free;
  end;
end;

function BodyAnalysisSourceFileSet(const aOptions: TDelphiSemanticOptions):
  TDictionary<string, Byte>;
var
  lFileName: string;
begin
  if Length(aOptions.BodyAnalysisSourceFileNames) = 0 then
    Exit(nil);

  Result := TDictionary<string, Byte>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
  for lFileName in aOptions.BodyAnalysisSourceFileNames do
    if Trim(lFileName) <> '' then
      Result.AddOrSetValue(TPath.GetFullPath(lFileName), 0);
end;

function ProjectFactsCacheFileName(const aOptions: TDelphiSemanticOptions): string;
begin
  if Trim(aOptions.SqliteCacheFileName) = '' then
    Exit('');

  Result := aOptions.SqliteCacheFileName + '.project-facts.json';
end;

procedure AppendCacheLine(const aBuilder: TStringBuilder; const aName,
  aValue: string);
begin
  aBuilder.Append(aName);
  aBuilder.Append('=');
  aBuilder.Append(aValue);
  aBuilder.AppendLine;
end;

procedure AppendFileFingerprint(const aBuilder: TStringBuilder; const aFileName: string);
var
  lFileName: string;
begin
  if Trim(aFileName) = '' then
    Exit;

  lFileName := TPath.GetFullPath(aFileName);
  AppendCacheLine(aBuilder, 'file', UpperCase(lFileName));
  if not TFile.Exists(lFileName) then
  begin
    AppendCacheLine(aBuilder, 'exists', '0');
    Exit;
  end;

  AppendCacheLine(aBuilder, 'exists', '1');
  AppendCacheLine(aBuilder, 'stamp', IntToStr(FileAge(lFileName)));
  AppendCacheLine(aBuilder, 'size', IntToStr(TFile.GetSize(lFileName)));
  AppendCacheLine(aBuilder, 'hash', THashSHA2.GetHashStringFromFile(lFileName));
end;

function ProjectFactsCacheKey(const aProject: TDelphiSemanticProjectInfo;
  const aOptions: TDelphiSemanticOptions;
  const aUnitIdentities: TArray<TDelphiSemanticUnitCacheIdentity>): string;
var
  lBuilder: TStringBuilder;
  lFileName: string;
  lIdentity: TDelphiSemanticUnitCacheIdentity;
  lProjectFileNames: TDictionary<string, Byte>;
begin
  lBuilder := nil;
  lProjectFileNames := nil;
  try
    lBuilder := TStringBuilder.Create;
    lProjectFileNames := TDictionary<string, Byte>.Create(
      TFastCaseAwareComparer.OrdinalIgnoreCase);
    for lFileName in ProjectModelFileNames(aProject) do
      lProjectFileNames.AddOrSetValue(TPath.GetFullPath(lFileName), 0);
    AppendCacheLine(lBuilder, 'schema', cProjectFactsCacheSchemaVersion);
    AppendCacheLine(lBuilder, 'library', DelphiSemanticsVersionText);
    AppendCacheLine(lBuilder, 'context', aProject.ContextFingerprint);
    AppendCacheLine(lBuilder, 'project', TPath.GetFullPath(aOptions.ProjectPath));
    AppendCacheLine(lBuilder, 'delphiVersion', aOptions.DelphiVersion);
    AppendCacheLine(lBuilder, 'configuration', aOptions.Configuration);
    AppendCacheLine(lBuilder, 'platform', aOptions.Platform);
    AppendCacheLine(lBuilder, 'skipSemanticGraph',
      BoolToStr(aOptions.SkipWithBindingSemanticGraph, True));
    AppendFileFingerprint(lBuilder, aOptions.ProjectPath);
    for lFileName in aOptions.BodyAnalysisSourceFileNames do
      if Trim(lFileName) <> '' then
      begin
        if lProjectFileNames.ContainsKey(TPath.GetFullPath(lFileName)) then
          Continue;
        AppendCacheLine(lBuilder, 'bodyAnalysisFile',
          UpperCase(TPath.GetFullPath(lFileName)));
        AppendFileFingerprint(lBuilder, lFileName);
      end;
    for lIdentity in aUnitIdentities do
    begin
      AppendCacheLine(lBuilder, 'unitCacheKey', lIdentity.UnitCacheKey);
      AppendCacheLine(lBuilder, 'includeGraph', lIdentity.IncludeGraphHash);
    end;
    Result := THashSHA2.GetHashString(lBuilder.ToString);
  finally
    lProjectFileNames.Free;
    lBuilder.Free;
  end;
end;

function JsonString(const aObject: TJSONObject; const aName: string): string;
var
  lValue: TJSONValue;
begin
  lValue := aObject.GetValue(aName);
  if lValue = nil then
    Exit('');

  Result := lValue.Value;
end;

function JsonInt(const aObject: TJSONObject; const aName: string): Integer;
begin
  Result := StrToIntDef(JsonString(aObject, aName), 0);
end;

function JsonBool(const aObject: TJSONObject; const aName: string): Boolean;
begin
  Result := SameText(JsonString(aObject, aName), 'true');
end;

function JsonArray(const aObject: TJSONObject; const aName: string): TJSONArray;
var
  lValue: TJSONValue;
begin
  lValue := aObject.GetValue(aName);
  if not (lValue is TJSONArray) then
    raise EConvertError.CreateFmt('Project facts cache array missing: %s', [aName]);

  Result := TJSONArray(lValue);
end;

function TryJsonArray(const aObject: TJSONObject; const aName: string;
  out aArray: TJSONArray): Boolean;
var
  lValue: TJSONValue;
begin
  lValue := aObject.GetValue(aName);
  Result := lValue is TJSONArray;
  if Result then
    aArray := TJSONArray(lValue)
  else
    aArray := nil;
end;

procedure AddJsonStringPair(const aObject: TJSONObject; const aName, aValue: string);
begin
  if aValue <> '' then
    aObject.AddPair(aName, aValue);
end;

procedure AddJsonIntPair(const aObject: TJSONObject; const aName: string;
  const aValue: Integer);
begin
  if aValue <> 0 then
    aObject.AddPair(aName, TJSONNumber.Create(aValue));
end;

procedure AddJsonBoolPair(const aObject: TJSONObject; const aName: string;
  const aValue: Boolean);
begin
  if aValue then
    aObject.AddPair(aName, TJSONBool.Create(True));
end;

function InventorySymbolToJson(const aSymbol: TDelphiSemanticInventorySymbol):
  TJSONObject;
begin
  Result := TJSONObject.Create;
  AddJsonStringPair(Result, 'name', aSymbol.Name);
  AddJsonStringPair(Result, 'symbolClass', aSymbol.SymbolClass);
  AddJsonStringPair(Result, 'kind', aSymbol.Kind);
  AddJsonStringPair(Result, 'typeName', aSymbol.TypeName);
  AddJsonStringPair(Result, 'modifier', aSymbol.Modifier);
  AddJsonStringPair(Result, 'ownerName', aSymbol.OwnerName);
  AddJsonStringPair(Result, 'ownerType', aSymbol.OwnerType);
  AddJsonStringPair(Result, 'sourceOwnerType', aSymbol.SourceOwnerType);
  AddJsonStringPair(Result, 'relatedTypeName', aSymbol.RelatedTypeName);
  AddJsonStringPair(Result, 'routineName', aSymbol.RoutineName);
  AddJsonStringPair(Result, 'unitName', aSymbol.UnitName);
  AddJsonStringPair(Result, 'fileName', aSymbol.FileName);
  AddJsonStringPair(Result, 'sectionKind', aSymbol.SectionKind);
  AddJsonIntPair(Result, 'line', aSymbol.Line);
  AddJsonIntPair(Result, 'column', aSymbol.Column);
  AddJsonIntPair(Result, 'endLine', aSymbol.EndLine);
  AddJsonIntPair(Result, 'endColumn', aSymbol.EndColumn);
  AddJsonStringPair(Result, 'unsupportedReason', aSymbol.UnsupportedReason);
  AddJsonBoolPair(Result, 'isHelper', aSymbol.IsHelper);
  AddJsonBoolPair(Result, 'isOverride', aSymbol.IsOverride);
  AddJsonBoolPair(Result, 'isDefault', aSymbol.IsDefault);
  AddJsonBoolPair(Result, 'isIndexed', aSymbol.IsIndexed);
  AddJsonIntPair(Result, 'indexParameterCount', aSymbol.IndexParameterCount);
  AddJsonStringPair(Result, 'typeCategory', aSymbol.TypeCategory);
end;

function JsonToInventorySymbol(const aObject: TJSONObject):
  TDelphiSemanticInventorySymbol;
begin
  Result := Default(TDelphiSemanticInventorySymbol);
  Result.Name := JsonString(aObject, 'name');
  Result.SymbolClass := JsonString(aObject, 'symbolClass');
  Result.Kind := JsonString(aObject, 'kind');
  Result.TypeName := JsonString(aObject, 'typeName');
  Result.Modifier := JsonString(aObject, 'modifier');
  Result.OwnerName := JsonString(aObject, 'ownerName');
  Result.OwnerType := JsonString(aObject, 'ownerType');
  Result.SourceOwnerType := JsonString(aObject, 'sourceOwnerType');
  Result.RelatedTypeName := JsonString(aObject, 'relatedTypeName');
  Result.RoutineName := JsonString(aObject, 'routineName');
  Result.UnitName := JsonString(aObject, 'unitName');
  Result.FileName := JsonString(aObject, 'fileName');
  Result.SectionKind := JsonString(aObject, 'sectionKind');
  Result.Line := JsonInt(aObject, 'line');
  Result.Column := JsonInt(aObject, 'column');
  Result.EndLine := JsonInt(aObject, 'endLine');
  Result.EndColumn := JsonInt(aObject, 'endColumn');
  Result.UnsupportedReason := JsonString(aObject, 'unsupportedReason');
  Result.IsHelper := JsonBool(aObject, 'isHelper');
  Result.IsOverride := JsonBool(aObject, 'isOverride');
  Result.IsDefault := JsonBool(aObject, 'isDefault');
  Result.IsIndexed := JsonBool(aObject, 'isIndexed');
  Result.IndexParameterCount := JsonInt(aObject, 'indexParameterCount');
  Result.TypeCategory := JsonString(aObject, 'typeCategory');
end;

function InventorySymbolsToJson(const aSymbols: TArray<TDelphiSemanticInventorySymbol>):
  TJSONArray;
var
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  Result := TJSONArray.Create;
  for lSymbol in aSymbols do
    Result.AddElement(InventorySymbolToJson(lSymbol));
end;

function JsonToInventorySymbols(const aArray: TJSONArray):
  TArray<TDelphiSemanticInventorySymbol>;
var
  i: Integer;
begin
  SetLength(Result, aArray.Count);
  for i := 0 to aArray.Count - 1 do
    Result[i] := JsonToInventorySymbol(aArray.Items[i] as TJSONObject);
end;

function SelectorBindingToJson(const aSelector: TDelphiSemanticWithSelectorBinding):
  TJSONObject;
begin
  Result := TJSONObject.Create;
  AddJsonStringPair(Result, 'selectorText', aSelector.SelectorText);
  AddJsonStringPair(Result, 'status', aSelector.Status);
  AddJsonStringPair(Result, 'reasonCode', aSelector.ReasonCode);
  AddJsonStringPair(Result, 'typeName', aSelector.TypeName);
end;

function JsonToSelectorBinding(const aObject: TJSONObject):
  TDelphiSemanticWithSelectorBinding;
begin
  Result := Default(TDelphiSemanticWithSelectorBinding);
  Result.SelectorText := JsonString(aObject, 'selectorText');
  Result.Status := JsonString(aObject, 'status');
  Result.ReasonCode := JsonString(aObject, 'reasonCode');
  Result.TypeName := JsonString(aObject, 'typeName');
end;

function SelectorBindingsToJson(
  const aSelectors: TArray<TDelphiSemanticWithSelectorBinding>): TJSONArray;
var
  lSelector: TDelphiSemanticWithSelectorBinding;
begin
  Result := TJSONArray.Create;
  for lSelector in aSelectors do
    Result.AddElement(SelectorBindingToJson(lSelector));
end;

function JsonToSelectorBindings(const aArray: TJSONArray):
  TArray<TDelphiSemanticWithSelectorBinding>;
var
  i: Integer;
begin
  SetLength(Result, aArray.Count);
  for i := 0 to aArray.Count - 1 do
    Result[i] := JsonToSelectorBinding(aArray.Items[i] as TJSONObject);
end;

function BoundReferenceToJson(const aReference: TDelphiSemanticBoundReference):
  TJSONObject;
begin
  Result := TJSONObject.Create;
  AddJsonStringPair(Result, 'semanticId', aReference.SemanticId);
  AddJsonStringPair(Result, 'name', aReference.Name);
  AddJsonStringPair(Result, 'classification', aReference.Classification);
  AddJsonStringPair(Result, 'lookupSource', aReference.LookupSource);
  AddJsonStringPair(Result, 'receiverTypeName', aReference.ReceiverTypeName);
  AddJsonStringPair(Result, 'kind', aReference.Kind);
  AddJsonStringPair(Result, 'typeName', aReference.TypeName);
  AddJsonStringPair(Result, 'reasonCode', aReference.ReasonCode);
  AddJsonStringPair(Result, 'scopeConflictKind', aReference.ScopeConflictKind);
  AddJsonStringPair(Result, 'scopeConflictName', aReference.ScopeConflictName);
  AddJsonIntPair(Result, 'line', aReference.Line);
  AddJsonIntPair(Result, 'column', aReference.Column);
  AddJsonIntPair(Result, 'endLine', aReference.EndLine);
  AddJsonIntPair(Result, 'endColumn', aReference.EndColumn);
end;

function JsonToBoundReference(const aObject: TJSONObject):
  TDelphiSemanticBoundReference;
begin
  Result := Default(TDelphiSemanticBoundReference);
  Result.SemanticId := JsonString(aObject, 'semanticId');
  Result.Name := JsonString(aObject, 'name');
  Result.Classification := JsonString(aObject, 'classification');
  Result.LookupSource := JsonString(aObject, 'lookupSource');
  Result.ReceiverTypeName := JsonString(aObject, 'receiverTypeName');
  Result.Kind := JsonString(aObject, 'kind');
  Result.TypeName := JsonString(aObject, 'typeName');
  Result.ReasonCode := JsonString(aObject, 'reasonCode');
  Result.ScopeConflictKind := JsonString(aObject, 'scopeConflictKind');
  Result.ScopeConflictName := JsonString(aObject, 'scopeConflictName');
  Result.Line := JsonInt(aObject, 'line');
  Result.Column := JsonInt(aObject, 'column');
  Result.EndLine := JsonInt(aObject, 'endLine');
  Result.EndColumn := JsonInt(aObject, 'endColumn');
end;

function BoundReferencesToJson(
  const aReferences: TArray<TDelphiSemanticBoundReference>): TJSONArray;
var
  lReference: TDelphiSemanticBoundReference;
begin
  Result := TJSONArray.Create;
  for lReference in aReferences do
    Result.AddElement(BoundReferenceToJson(lReference));
end;

function JsonToBoundReferences(const aArray: TJSONArray):
  TArray<TDelphiSemanticBoundReference>;
var
  i: Integer;
begin
  SetLength(Result, aArray.Count);
  for i := 0 to aArray.Count - 1 do
    Result[i] := JsonToBoundReference(aArray.Items[i] as TJSONObject);
end;

function WithBindingToJson(const aBinding: TDelphiSemanticWithBinding):
  TJSONObject;
begin
  Result := TJSONObject.Create;
  AddJsonStringPair(Result, 'semanticId', aBinding.SemanticId);
  AddJsonStringPair(Result, 'provenance', aBinding.Provenance);
  AddJsonStringPair(Result, 'fileName', aBinding.FileName);
  AddJsonStringPair(Result, 'unitName', aBinding.UnitName);
  AddJsonStringPair(Result, 'routineName', aBinding.RoutineName);
  AddJsonIntPair(Result, 'line', aBinding.Line);
  AddJsonIntPair(Result, 'column', aBinding.Column);
  AddJsonIntPair(Result, 'endLine', aBinding.EndLine);
  AddJsonIntPair(Result, 'endColumn', aBinding.EndColumn);
  AddJsonIntPair(Result, 'bodyLine', aBinding.BodyLine);
  AddJsonIntPair(Result, 'bodyColumn', aBinding.BodyColumn);
  AddJsonIntPair(Result, 'bodyEndLine', aBinding.BodyEndLine);
  AddJsonIntPair(Result, 'bodyEndColumn', aBinding.BodyEndColumn);
  AddJsonStringPair(Result, 'selectorText', aBinding.SelectorText);
  AddJsonStringPair(Result, 'status', aBinding.Status);
  AddJsonStringPair(Result, 'skipReason', aBinding.SkipReason);
  AddJsonBoolPair(Result, 'hasScopedDeclaration', aBinding.HasScopedDeclaration);
  AddJsonIntPair(Result, 'memberReferenceCount', aBinding.MemberReferenceCount);
  AddJsonIntPair(Result, 'lexicalReferenceCount', aBinding.LexicalReferenceCount);
  AddJsonIntPair(Result, 'externalReferenceCount', aBinding.ExternalReferenceCount);
  AddJsonIntPair(Result, 'intrinsicReferenceCount', aBinding.IntrinsicReferenceCount);
  AddJsonIntPair(Result, 'unsupportedReferenceCount', aBinding.UnsupportedReferenceCount);
  AddJsonIntPair(Result, 'unresolvedReferenceCount', aBinding.UnresolvedReferenceCount);
  Result.AddPair('selectors', SelectorBindingsToJson(aBinding.Selectors));
  Result.AddPair('references', BoundReferencesToJson(aBinding.References));
end;

function JsonToWithBinding(const aObject: TJSONObject): TDelphiSemanticWithBinding;
begin
  Result := Default(TDelphiSemanticWithBinding);
  Result.SemanticId := JsonString(aObject, 'semanticId');
  Result.Provenance := JsonString(aObject, 'provenance');
  Result.FileName := JsonString(aObject, 'fileName');
  Result.UnitName := JsonString(aObject, 'unitName');
  Result.RoutineName := JsonString(aObject, 'routineName');
  Result.Line := JsonInt(aObject, 'line');
  Result.Column := JsonInt(aObject, 'column');
  Result.EndLine := JsonInt(aObject, 'endLine');
  Result.EndColumn := JsonInt(aObject, 'endColumn');
  Result.BodyLine := JsonInt(aObject, 'bodyLine');
  Result.BodyColumn := JsonInt(aObject, 'bodyColumn');
  Result.BodyEndLine := JsonInt(aObject, 'bodyEndLine');
  Result.BodyEndColumn := JsonInt(aObject, 'bodyEndColumn');
  Result.SelectorText := JsonString(aObject, 'selectorText');
  Result.Status := JsonString(aObject, 'status');
  Result.SkipReason := JsonString(aObject, 'skipReason');
  Result.HasScopedDeclaration := JsonBool(aObject, 'hasScopedDeclaration');
  Result.MemberReferenceCount := JsonInt(aObject, 'memberReferenceCount');
  Result.LexicalReferenceCount := JsonInt(aObject, 'lexicalReferenceCount');
  Result.ExternalReferenceCount := JsonInt(aObject, 'externalReferenceCount');
  Result.IntrinsicReferenceCount := JsonInt(aObject, 'intrinsicReferenceCount');
  Result.UnsupportedReferenceCount := JsonInt(aObject, 'unsupportedReferenceCount');
  Result.UnresolvedReferenceCount := JsonInt(aObject, 'unresolvedReferenceCount');
  Result.Selectors := JsonToSelectorBindings(JsonArray(aObject, 'selectors'));
  Result.References := JsonToBoundReferences(JsonArray(aObject, 'references'));
end;

function WithBindingsToJson(const aBindings: TArray<TDelphiSemanticWithBinding>):
  TJSONArray;
var
  lBinding: TDelphiSemanticWithBinding;
begin
  Result := TJSONArray.Create;
  for lBinding in aBindings do
    Result.AddElement(WithBindingToJson(lBinding));
end;

function JsonToWithBindings(const aArray: TJSONArray):
  TArray<TDelphiSemanticWithBinding>;
var
  i: Integer;
begin
  SetLength(Result, aArray.Count);
  for i := 0 to aArray.Count - 1 do
    Result[i] := JsonToWithBinding(aArray.Items[i] as TJSONObject);
end;

function ProjectFactsCacheToJson(const aCacheKey: string;
  const aFacts: TDelphiSemanticProjectWithBindingFacts): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('schemaVersion', cProjectFactsCacheSchemaVersion);
  Result.AddPair('cacheKey', aCacheKey);
  Result.AddPair('contextFingerprint', aFacts.ContextFingerprint);
  AddJsonBoolPair(Result, 'semanticGraphUsed', aFacts.Metrics.SemanticGraphUsed);
  Result.AddPair('symbols', InventorySymbolsToJson(aFacts.Symbols));
  Result.AddPair('bindings', WithBindingsToJson(aFacts.Bindings));
end;

function TryLoadProjectFactsCache(const aCacheFileName, aCacheKey: string;
  const aModels: TArray<TDelphiSemanticUnitModel>;
  out aFacts: TDelphiSemanticProjectWithBindingFacts; out aInvalidated: Boolean):
  Boolean;
var
  lBindings: TJSONArray;
  lLookupStopwatch: TStopwatch;
  lObject: TJSONObject;
  lSymbols: TJSONArray;
  lValue: TJSONValue;
begin
  Result := False;
  aFacts := Default(TDelphiSemanticProjectWithBindingFacts);
  aInvalidated := False;
  if (Trim(aCacheFileName) = '') or (not TFile.Exists(aCacheFileName)) then
    Exit;

  lValue := nil;
  try
    lValue := TJSONObject.ParseJSONValue(TFile.ReadAllText(aCacheFileName,
      TEncoding.UTF8));
    if not (lValue is TJSONObject) then
    begin
      aInvalidated := True;
      Exit;
    end;

    lObject := TJSONObject(lValue);
    if (JsonString(lObject, 'schemaVersion') <> cProjectFactsCacheSchemaVersion) or
      (JsonString(lObject, 'cacheKey') <> aCacheKey) then
    begin
      aInvalidated := True;
      Exit;
    end;
    if (not TryJsonArray(lObject, 'symbols', lSymbols)) or
      (not TryJsonArray(lObject, 'bindings', lBindings)) then
    begin
      aInvalidated := True;
      Exit;
    end;

    aFacts.ContextFingerprint := JsonString(lObject, 'contextFingerprint');
    aFacts.Symbols := JsonToInventorySymbols(lSymbols);
    aFacts.Bindings := JsonToWithBindings(lBindings);
    aFacts.UnitModels := Copy(aModels);
    aFacts.Metrics.SemanticGraphUsed := JsonBool(lObject, 'semanticGraphUsed');
    aFacts.Metrics.UnitCount := Length(aFacts.UnitModels);
    aFacts.Metrics.WithStatementCount := Length(aFacts.Bindings);
    aFacts.Metrics.BindingCount := Length(aFacts.Bindings);
    aFacts.Metrics.ProjectFactsCacheHits := 1;
    lLookupStopwatch := TStopwatch.StartNew;
    aFacts.LookupIndex := TDelphiSemanticRemoveWithLookupIndex.Build(aFacts.UnitModels,
      aFacts.Symbols);
    lLookupStopwatch.Stop;
    aFacts.Metrics.LookupIndexBuildMilliseconds :=
      lLookupStopwatch.ElapsedMilliseconds;
    Result := True;
  finally
    lValue.Free;
  end;
end;

procedure StoreProjectFactsCache(const aCacheFileName, aCacheKey: string;
  const aFacts: TDelphiSemanticProjectWithBindingFacts);
var
  lCacheDir: string;
  lObject: TJSONObject;
  lTempFileName: string;
begin
  if Trim(aCacheFileName) = '' then
    Exit;

  lCacheDir := TPath.GetDirectoryName(aCacheFileName);
  if lCacheDir <> '' then
    TDirectory.CreateDirectory(lCacheDir);

  lObject := ProjectFactsCacheToJson(aCacheKey, aFacts);
  try
    lTempFileName := aCacheFileName + '.' + TGUID.NewGuid.ToString + '.tmp';
    TFile.WriteAllText(lTempFileName, lObject.ToJSON, TEncoding.UTF8);
    if TFile.Exists(aCacheFileName) then
      TFile.Delete(aCacheFileName);
    TFile.Move(lTempFileName, aCacheFileName);
  finally
    if (lTempFileName <> '') and TFile.Exists(lTempFileName) then
      TFile.Delete(lTempFileName);
    lObject.Free;
  end;
end;

function ExtractProjectModels(const aProject: TDelphiSemanticProjectInfo;
  const aOptions: TDelphiSemanticOptions; out aExtractionMilliseconds: Int64):
  TArray<TDelphiSemanticUnitModel>; overload; forward;
function ExtractProjectModels(const aProject: TDelphiSemanticProjectInfo;
  const aOptions: TDelphiSemanticOptions; out aExtractionMilliseconds: Int64;
  out aCacheMetrics: TDelphiSemanticCacheMetrics): TArray<TDelphiSemanticUnitModel>;
  overload; forward;
function ExtractProjectModels(const aProject: TDelphiSemanticProjectInfo;
  const aOptions: TDelphiSemanticOptions; out aExtractionMilliseconds: Int64;
  out aCacheMetrics: TDelphiSemanticCacheMetrics;
  out aCacheIdentities: TArray<TDelphiSemanticUnitCacheIdentity>):
  TArray<TDelphiSemanticUnitModel>; overload; forward;

function ExtractProjectModels(const aProject: TDelphiSemanticProjectInfo;
  const aOptions: TDelphiSemanticOptions):
  TArray<TDelphiSemanticUnitModel>; overload;
var
  lCacheIdentities: TArray<TDelphiSemanticUnitCacheIdentity>;
  lCacheMetrics: TDelphiSemanticCacheMetrics;
  lExtractionMilliseconds: Int64;
begin
  Result := ExtractProjectModels(aProject, aOptions, lExtractionMilliseconds,
    lCacheMetrics, lCacheIdentities);
end;

function ExtractProjectModels(const aProject: TDelphiSemanticProjectInfo;
  const aOptions: TDelphiSemanticOptions; out aExtractionMilliseconds: Int64):
  TArray<TDelphiSemanticUnitModel>; overload;
var
  lCacheIdentities: TArray<TDelphiSemanticUnitCacheIdentity>;
  lCacheMetrics: TDelphiSemanticCacheMetrics;
begin
  Result := ExtractProjectModels(aProject, aOptions, aExtractionMilliseconds,
    lCacheMetrics, lCacheIdentities);
end;

function ExtractProjectModels(const aProject: TDelphiSemanticProjectInfo;
  const aOptions: TDelphiSemanticOptions; out aExtractionMilliseconds: Int64;
  out aCacheMetrics: TDelphiSemanticCacheMetrics): TArray<TDelphiSemanticUnitModel>;
  overload;
var
  lCacheIdentities: TArray<TDelphiSemanticUnitCacheIdentity>;
begin
  Result := ExtractProjectModels(aProject, aOptions, aExtractionMilliseconds,
    aCacheMetrics, lCacheIdentities);
end;

function ExtractProjectModels(const aProject: TDelphiSemanticProjectInfo;
  const aOptions: TDelphiSemanticOptions; out aExtractionMilliseconds: Int64;
  out aCacheMetrics: TDelphiSemanticCacheMetrics;
  out aCacheIdentities: TArray<TDelphiSemanticUnitCacheIdentity>):
  TArray<TDelphiSemanticUnitModel>;
  overload;
var
  lBodyAnalysisSourceFiles: TDictionary<string, Byte>;
  lCache: TDelphiSemanticUnitCache;
  lCacheOptions: TDelphiSemanticCacheOptions;
  i: Integer;
  lIdentity: TDelphiSemanticUnitCacheIdentity;
  lModel: TDelphiSemanticUnitModel;
  lModels: TList<TDelphiSemanticUnitModel>;
  lSkipBodyAnalysis: Boolean;
  lSourceFileNames: TArray<string>;
  lStopwatch: TStopwatch;
begin
  lBodyAnalysisSourceFiles := nil;
  lModels := nil;
  lCache := nil;
  aExtractionMilliseconds := 0;
  aCacheMetrics := Default(TDelphiSemanticCacheMetrics);
  SetLength(aCacheIdentities, 0);
  lStopwatch := TStopwatch.StartNew;
  try
    if Trim(aOptions.SqliteCacheFileName) <> '' then
    begin
      lCacheOptions := CacheOptionsFromSessionOptions(aOptions);
      lCache := TDelphiSemanticSqliteUnitCache.Create(lCacheOptions);
    end;

    lSourceFileNames := ProjectModelFileNames(aProject);
    SetLength(aCacheIdentities, Length(lSourceFileNames));
    lBodyAnalysisSourceFiles := BodyAnalysisSourceFileSet(aOptions);
    lModels := TList<TDelphiSemanticUnitModel>.Create;
    for i := 0 to High(lSourceFileNames) do
    begin
      lSkipBodyAnalysis := Assigned(lBodyAnalysisSourceFiles) and
        (not lBodyAnalysisSourceFiles.ContainsKey(lSourceFileNames[i]));
      lModel := ExtractProjectUnitModel(aProject, lSourceFileNames[i], lCache,
        lSkipBodyAnalysis, lIdentity);
      aCacheIdentities[i] := lIdentity;
      if (i = 0) and (lModel.Success) and (lModel.UnitName = '') and
        SameText(lModel.FileName, aProject.MainSourceFileName) then
        lModel.UnitName := aProject.ProjectName;
      lModels.Add(lModel);
    end;

    Result := lModels.ToArray;
  finally
    lStopwatch.Stop;
    aExtractionMilliseconds := lStopwatch.ElapsedMilliseconds;
    if Assigned(lCache) then
      aCacheMetrics := lCache.Metrics;
    lCache.Free;
    lBodyAnalysisSourceFiles.Free;
    lModels.Free;
  end;
end;

function SnapshotDeclarationKind(const aKind: string): string;
begin
  if SameText(aKind, cSnapshotDeclarationKindTypeAlias) then
    Exit(cSnapshotDeclarationKindAlias);

  Result := aKind;
end;

function SnapshotEndColumn(const aColumn: Integer; const aName: string): Integer;
begin
  if (aColumn <= 0) or (aName = '') then
    Exit(0);

  Result := aColumn + Length(aName) - 1;
end;

function SnapshotFullPath(const aFileName: string): string;
begin
  if Trim(aFileName) = '' then
    Exit('');

  Result := TPath.GetFullPath(aFileName);
end;

function SnapshotRoutineName(const aRoutine: TDelphiSemanticRoutine): string;
begin
  if aRoutine.OwnerName <> '' then
    Exit(aRoutine.OwnerName + '.' + aRoutine.Name);

  Result := aRoutine.Name;
end;

function SnapshotRoutineNameForLine(const aModel: TDelphiSemanticUnitModel;
  const aLine: Integer): string;
var
  lBestLine: Integer;
  lRoutine: TDelphiSemanticRoutine;
begin
  Result := '';
  lBestLine := 0;
  if aLine <= 0 then
    Exit;

  for lRoutine in aModel.Routines do
  begin
    if (lRoutine.Line <= 0) or (lRoutine.Line > aLine) then
      Continue;
    if lRoutine.Line < lBestLine then
      Continue;

    lBestLine := lRoutine.Line;
    Result := SnapshotRoutineName(lRoutine);
  end;
end;

function SnapshotWithIdForLine(const aUnit: TUnitSnapshot; const aLine: Integer):
  TSemanticWithId;
begin
  Result := 0;
  aUnit.TryFindInnermostWithStatementAtLine(aLine, Result);
end;

procedure AddSnapshotWithStatement(const aStrings: TSemanticStringPool;
  const aUnit: TUnitSnapshot; const aModel: TDelphiSemanticUnitModel;
  const aWith: TDelphiSemanticWithStatement;
  var aMetrics: TDelphiSemanticProjectSnapshotBuildMetrics);
var
  lWith: TSemanticWithStatementFact;
begin
  lWith := Default(TSemanticWithStatementFact);
  lWith.RoutineId := aStrings.Intern(SnapshotRoutineNameForLine(aModel, aWith.Line));
  lWith.SelectorStartLine := aWith.Line;
  lWith.SelectorStartColumn := aWith.Column;
  lWith.BodyStartLine := aWith.BodyLine;
  lWith.BodyStartColumn := aWith.BodyColumn;
  lWith.BodyEndLine := aWith.BodyEndLine;
  lWith.BodyEndColumn := aWith.BodyEndColumn;
  if aWith.HasScopedDeclaration then
    lWith.Flags := cSnapshotWithFlagHasScopedDeclaration;
  aUnit.AddWithStatement(lWith);
  Inc(aMetrics.WithStatementCount);
end;

procedure AddSnapshotDeclaration(const aStrings: TSemanticStringPool;
  const aUnit: TUnitSnapshot; const aDeclaration: TDelphiSemanticDeclaration;
  var aMetrics: TDelphiSemanticProjectSnapshotBuildMetrics);
var
  lSymbol: TSemanticSymbolFact;
begin
  lSymbol := Default(TSemanticSymbolFact);
  lSymbol.NameId := aStrings.Intern(aDeclaration.Name);
  lSymbol.TypeId := aStrings.Intern(aDeclaration.TypeName);
  lSymbol.KindId := aStrings.Intern(SnapshotDeclarationKind(aDeclaration.Kind));
  lSymbol.Line := aDeclaration.Line;
  lSymbol.Column := aDeclaration.Column;
  lSymbol.EndLine := aDeclaration.Line;
  lSymbol.EndColumn := SnapshotEndColumn(aDeclaration.Column, aDeclaration.Name);
  aUnit.AddSymbol(lSymbol);
  Inc(aMetrics.SymbolCount);
end;

procedure AddSnapshotMember(const aStrings: TSemanticStringPool;
  const aUnit: TUnitSnapshot; const aMember: TDelphiSemanticMember;
  var aMetrics: TDelphiSemanticProjectSnapshotBuildMetrics);
var
  lSymbol: TSemanticSymbolFact;
begin
  lSymbol := Default(TSemanticSymbolFact);
  lSymbol.NameId := aStrings.Intern(aMember.Name);
  lSymbol.OwnerTypeId := aStrings.Intern(aMember.OwnerName);
  lSymbol.TypeId := aStrings.Intern(aMember.TypeName);
  lSymbol.KindId := aStrings.Intern(aMember.Kind);
  lSymbol.Line := aMember.Line;
  lSymbol.Column := aMember.Column;
  lSymbol.EndLine := aMember.Line;
  lSymbol.EndColumn := SnapshotEndColumn(aMember.Column, aMember.Name);
  if aMember.IsDefault then
    lSymbol.Flags := lSymbol.Flags or cSnapshotSymbolFlagIsDefault;
  if aMember.IsIndexed then
    lSymbol.Flags := lSymbol.Flags or cSnapshotSymbolFlagIsIndexed;
  aUnit.AddSymbol(lSymbol);
  Inc(aMetrics.SymbolCount);
end;

procedure AddSnapshotParameter(const aStrings: TSemanticStringPool;
  const aUnit: TUnitSnapshot; const aRoutineName: string;
  const aParameter: TDelphiSemanticParameter;
  var aMetrics: TDelphiSemanticProjectSnapshotBuildMetrics);
var
  lSymbol: TSemanticSymbolFact;
begin
  lSymbol := Default(TSemanticSymbolFact);
  lSymbol.NameId := aStrings.Intern(aParameter.Name);
  lSymbol.TypeId := aStrings.Intern(aParameter.TypeName);
  lSymbol.RoutineId := aStrings.Intern(aRoutineName);
  lSymbol.KindId := aStrings.Intern(cSnapshotSymbolKindParameter);
  lSymbol.Line := aParameter.Line;
  lSymbol.Column := aParameter.Column;
  lSymbol.EndLine := aParameter.Line;
  lSymbol.EndColumn := SnapshotEndColumn(aParameter.Column, aParameter.Name);
  aUnit.AddSymbol(lSymbol);
  Inc(aMetrics.SymbolCount);
end;

procedure AddSnapshotRoutine(const aStrings: TSemanticStringPool;
  const aUnit: TUnitSnapshot; const aRoutine: TDelphiSemanticRoutine;
  var aMetrics: TDelphiSemanticProjectSnapshotBuildMetrics);
var
  lParameter: TDelphiSemanticParameter;
  lRoutineName: string;
  lSymbol: TSemanticSymbolFact;
begin
  lRoutineName := SnapshotRoutineName(aRoutine);
  lSymbol := Default(TSemanticSymbolFact);
  lSymbol.NameId := aStrings.Intern(aRoutine.Name);
  lSymbol.OwnerTypeId := aStrings.Intern(aRoutine.OwnerName);
  lSymbol.TypeId := aStrings.Intern(aRoutine.ReturnType);
  lSymbol.RoutineId := aStrings.Intern(lRoutineName);
  lSymbol.KindId := aStrings.Intern(cSnapshotSymbolKindRoutine);
  lSymbol.Line := aRoutine.Line;
  lSymbol.Column := aRoutine.Column;
  lSymbol.EndLine := aRoutine.Line;
  lSymbol.EndColumn := SnapshotEndColumn(aRoutine.Column, aRoutine.Name);
  aUnit.AddSymbol(lSymbol);
  Inc(aMetrics.SymbolCount);

  for lParameter in aRoutine.Parameters do
    AddSnapshotParameter(aStrings, aUnit, lRoutineName, lParameter, aMetrics);
end;

procedure AddSnapshotLocal(const aStrings: TSemanticStringPool;
  const aUnit: TUnitSnapshot; const aLocal: TDelphiSemanticLocal;
  var aMetrics: TDelphiSemanticProjectSnapshotBuildMetrics);
var
  lKind: string;
  lSymbol: TSemanticSymbolFact;
begin
  lKind := aLocal.Kind;
  if lKind = '' then
    lKind := cSnapshotSymbolKindLocal;
  lSymbol := Default(TSemanticSymbolFact);
  lSymbol.NameId := aStrings.Intern(aLocal.Name);
  lSymbol.TypeId := aStrings.Intern(aLocal.TypeName);
  lSymbol.RoutineId := aStrings.Intern(aLocal.RoutineName);
  lSymbol.KindId := aStrings.Intern(lKind);
  lSymbol.Line := aLocal.Line;
  lSymbol.Column := aLocal.Column;
  lSymbol.EndLine := aLocal.Line;
  lSymbol.EndColumn := SnapshotEndColumn(aLocal.Column, aLocal.Name);
  aUnit.AddSymbol(lSymbol);
  Inc(aMetrics.SymbolCount);
end;

procedure AddSnapshotReference(const aStrings: TSemanticStringPool;
  const aUnit: TUnitSnapshot; const aReference: TDelphiSemanticReference;
  var aMetrics: TDelphiSemanticProjectSnapshotBuildMetrics);
var
  lReference: TSemanticReferenceFact;
begin
  lReference := Default(TSemanticReferenceFact);
  lReference.WithId := SnapshotWithIdForLine(aUnit, aReference.Line);
  lReference.NameId := aStrings.Intern(aReference.Name);
  lReference.ClassificationId := aStrings.Intern(aReference.Role);
  lReference.Line := aReference.Line;
  lReference.Column := aReference.Column;
  lReference.EndLine := aReference.EndLine;
  if lReference.EndLine <= 0 then
    lReference.EndLine := aReference.Line;
  lReference.EndColumn := aReference.EndColumn;
  if lReference.EndColumn <= 0 then
    lReference.EndColumn := SnapshotEndColumn(aReference.Column, aReference.Name);
  aUnit.AddReference(lReference);
  Inc(aMetrics.ReferenceCount);
end;

procedure AddSnapshotUnitModel(const aBuilder: TDelphiProjectSnapshotBuilder;
  const aModel: TDelphiSemanticUnitModel; const aUnitId: TSemanticUnitId;
  var aMetrics: TDelphiSemanticProjectSnapshotBuildMetrics);
var
  lDeclaration: TDelphiSemanticDeclaration;
  lLocal: TDelphiSemanticLocal;
  lMember: TDelphiSemanticMember;
  lReference: TDelphiSemanticReference;
  lRoutine: TDelphiSemanticRoutine;
  lUnit: TUnitSnapshot;
  lWith: TDelphiSemanticWithStatement;
begin
  lUnit := TUnitSnapshot.Create(aUnitId,
    aBuilder.Strings.Intern(SnapshotFullPath(aModel.FileName)),
    aBuilder.Strings.Intern(aModel.UnitName));
  try
    for lWith in aModel.WithStatements do
      AddSnapshotWithStatement(aBuilder.Strings, lUnit, aModel, lWith, aMetrics);
    for lDeclaration in aModel.Declarations do
      AddSnapshotDeclaration(aBuilder.Strings, lUnit, lDeclaration, aMetrics);
    for lMember in aModel.Members do
      AddSnapshotMember(aBuilder.Strings, lUnit, lMember, aMetrics);
    for lRoutine in aModel.Routines do
      AddSnapshotRoutine(aBuilder.Strings, lUnit, lRoutine, aMetrics);
    for lLocal in aModel.Locals do
      AddSnapshotLocal(aBuilder.Strings, lUnit, lLocal, aMetrics);
    for lReference in aModel.References do
      AddSnapshotReference(aBuilder.Strings, lUnit, lReference, aMetrics);

    aBuilder.AddUnit(lUnit);
    lUnit := nil;
    Inc(aMetrics.UnitCount);
  finally
    lUnit.Free;
  end;
end;

function BuildSnapshotFromModels(const aModels: TArray<TDelphiSemanticUnitModel>;
  var aMetrics: TDelphiSemanticProjectSnapshotBuildMetrics): TDelphiProjectSnapshot;
var
  i: Integer;
  lBuilder: TDelphiProjectSnapshotBuilder;
  lStopwatch: TStopwatch;
begin
  aMetrics := Default(TDelphiSemanticProjectSnapshotBuildMetrics);
  lBuilder := TDelphiProjectSnapshotBuilder.Create;
  lStopwatch := TStopwatch.StartNew;
  try
    for i := 0 to High(aModels) do
      AddSnapshotUnitModel(lBuilder, aModels[i], TSemanticUnitId(i + 1), aMetrics);
    Result := lBuilder.Build;
  finally
    lStopwatch.Stop;
    aMetrics.BuildMilliseconds := lStopwatch.ElapsedMilliseconds;
    lBuilder.Free;
  end;
end;

procedure AddUniqueText(const aValues: TList<string>; const aValue: string);
var
  lValue: string;
begin
  if Trim(aValue) = '' then
    Exit;

  for lValue in aValues do
    if SameText(lValue, aValue) then
      Exit;
  aValues.Add(aValue);
end;

function UnitUsesName(const aModel: TDelphiSemanticUnitModel; const aUnitName: string): Boolean;
var
  lUsedUnit: string;
begin
  for lUsedUnit in aModel.InterfaceUses do
    if SameText(lUsedUnit, aUnitName) then
      Exit(True);

  for lUsedUnit in aModel.ImplementationUses do
    if SameText(lUsedUnit, aUnitName) then
      Exit(True);

  Result := False;
end;

function ListContainsText(const aValues: TList<string>; const aValue: string): Boolean;
var
  lValue: string;
begin
  for lValue in aValues do
    if SameText(lValue, aValue) then
      Exit(True);

  Result := False;
end;

function FindModelByFileName(const aModels: TArray<TDelphiSemanticUnitModel>;
  const aFileName: string; out aModel: TDelphiSemanticUnitModel): Boolean;
var
  lFileName: string;
  lModel: TDelphiSemanticUnitModel;
begin
  lFileName := TPath.GetFullPath(aFileName);
  for lModel in aModels do
    if SameText(TPath.GetFullPath(lModel.FileName), lFileName) then
    begin
      aModel := lModel;
      Exit(True);
    end;

  aModel := Default(TDelphiSemanticUnitModel);
  Result := False;
end;

procedure AddAffectedModel(const aModel: TDelphiSemanticUnitModel; const aFiles,
  aUnits: TList<string>);
begin
  AddUniqueText(aFiles, aModel.FileName);
  AddUniqueText(aUnits, aModel.UnitName);
end;

procedure AddAllModels(const aModels: TArray<TDelphiSemanticUnitModel>; const aFiles,
  aUnits: TList<string>);
var
  lModel: TDelphiSemanticUnitModel;
begin
  for lModel in aModels do
    AddAffectedModel(lModel, aFiles, aUnits);
end;

procedure AddDependentClosure(const aModels: TArray<TDelphiSemanticUnitModel>;
  const aChangedModel: TDelphiSemanticUnitModel; const aFiles, aUnits: TList<string>);
var
  lAdded: Boolean;
  lModel: TDelphiSemanticUnitModel;
  lUnitIndex: Integer;
begin
  AddAffectedModel(aChangedModel, aFiles, aUnits);
  lUnitIndex := 0;
  while lUnitIndex < aUnits.Count do
  begin
    lAdded := False;
    for lModel in aModels do
    begin
      if UnitUsesName(lModel, aUnits[lUnitIndex]) then
      begin
        if not SameText(lModel.UnitName, aUnits[lUnitIndex]) then
        begin
          if not ListContainsText(aUnits, lModel.UnitName) then
            lAdded := True;
          AddAffectedModel(lModel, aFiles, aUnits);
        end;
      end;
    end;
    if not lAdded then
      Inc(lUnitIndex);
  end;
end;

function SessionDiagnostic(const aCode, aMessage, aFileName: string;
  const aSeverity: TDelphiSemanticDiagnosticSeverity): TDelphiSemanticDiagnostic;
begin
  Result := Default(TDelphiSemanticDiagnostic);
  Result.Code := aCode;
  Result.Message := aMessage;
  Result.FileName := aFileName;
  Result.Severity := aSeverity;
end;

function SessionFailure(const aContext: TDelphiSemanticContextResult):
  TDelphiSemanticProjectSessionResult;
begin
  Result := Default(TDelphiSemanticProjectSessionResult);
  Result.Success := False;
  Result.Status := psInvalidProject;
  Result.Provenance := 'project-context';
  Result.Diagnostics := Copy(aContext.Diagnostics);
end;

function MissingProjectPathFailure: TDelphiSemanticProjectSessionResult;
begin
  Result := Default(TDelphiSemanticProjectSessionResult);
  Result.Success := False;
  Result.Status := psInvalidProject;
  Result.Provenance := 'project-context';
  SetLength(Result.Diagnostics, 1);
  Result.Diagnostics[0] := SessionDiagnostic('PROJECT_FILE_NOT_SPECIFIED',
    'Project file was not specified.', '', dsError);
end;

constructor TDelphiSemanticProjectSession.Create(const aOptions: TDelphiSemanticOptions;
  const aProject: TDelphiSemanticProjectInfo;
  const aDiagnostics: TArray<TDelphiSemanticDiagnostic>;
  const aStatus: TDelphiSemanticProjectSessionStatus; const aProvenance: string);
begin
  inherited Create;
  fOptions := aOptions;
  fProject := aProject;
  fDiagnostics := Copy(aDiagnostics);
  fStatus := aStatus;
  fProvenance := aProvenance;
end;

function TDelphiSemanticProjectSession.BuildSemanticGraph: TDelphiSemanticSemanticGraph;
var
  lExtractionMilliseconds: Int64;
  lModels: TArray<TDelphiSemanticUnitModel>;
begin
  lModels := ExtractProjectModels(fProject, fOptions, lExtractionMilliseconds);
  Result := TDelphiSemanticSemanticGraphBuilder.Build(fProject, lModels);
  fLastSemanticGraphBuildMetrics := Result.Metrics;
end;

function TDelphiSemanticProjectSession.BuildSnapshot: TDelphiProjectSnapshot;
var
  lExtractionMilliseconds: Int64;
  lModels: TArray<TDelphiSemanticUnitModel>;
begin
  lModels := ExtractProjectModels(fProject, fOptions, lExtractionMilliseconds);
  Result := BuildSnapshotFromModels(lModels, fLastSnapshotBuildMetrics);
end;

function TDelphiSemanticProjectSession.BuildWithBindingFacts:
  TDelphiSemanticProjectWithBindingFacts;
var
  lCacheMetrics: TDelphiSemanticCacheMetrics;
  lProjectFactsCacheFileName: string;
  lProjectFactsCacheInvalidated: Boolean;
  lProjectFactsCacheKey: string;
  lGraph: TDelphiSemanticSemanticGraph;
  lExtractionMilliseconds: Int64;
  lCacheIdentities: TArray<TDelphiSemanticUnitCacheIdentity>;
  lModels: TArray<TDelphiSemanticUnitModel>;
begin
  lProjectFactsCacheFileName := ProjectFactsCacheFileName(fOptions);
  lProjectFactsCacheKey := '';
  lModels := ExtractProjectModels(fProject, fOptions, lExtractionMilliseconds,
    lCacheMetrics, lCacheIdentities);
  if lProjectFactsCacheFileName <> '' then
    lProjectFactsCacheKey := ProjectFactsCacheKey(fProject, fOptions,
      lCacheIdentities);
  if TryLoadProjectFactsCache(lProjectFactsCacheFileName, lProjectFactsCacheKey,
    lModels, Result, lProjectFactsCacheInvalidated) then
  begin
    Result.Metrics.ModelExtractionMilliseconds := lExtractionMilliseconds;
    Result.Metrics.SemanticCacheHits := lCacheMetrics.CacheHits;
    Result.Metrics.SemanticCacheMisses := lCacheMetrics.CacheMisses;
    Result.Metrics.SemanticCacheInvalidations := lCacheMetrics.Invalidations;
    Result.Metrics.SemanticCachePersistentConnectionOpenCount :=
      lCacheMetrics.PersistentConnectionOpenCount;
    Exit;
  end;

  if fOptions.SkipWithBindingSemanticGraph then
    lGraph := nil
  else
    lGraph := TDelphiSemanticSemanticGraphBuilder.Build(fProject, lModels);
  try
    if lGraph <> nil then
      fLastSemanticGraphBuildMetrics := lGraph.Metrics
    else
      fLastSemanticGraphBuildMetrics := Default(TDelphiSemanticGraphBuildMetrics);
    Result := TDelphiSemanticWithBinder.BindProject(fProject.ContextFingerprint, lGraph,
      lModels);
    Result.Metrics.ModelExtractionMilliseconds := lExtractionMilliseconds;
    Result.Metrics.SemanticCacheHits := lCacheMetrics.CacheHits;
    Result.Metrics.SemanticCacheMisses := lCacheMetrics.CacheMisses;
    Result.Metrics.SemanticCacheInvalidations := lCacheMetrics.Invalidations;
    Result.Metrics.SemanticCachePersistentConnectionOpenCount :=
      lCacheMetrics.PersistentConnectionOpenCount;
    if lProjectFactsCacheFileName <> '' then
    begin
      Result.Metrics.ProjectFactsCacheMisses := 1;
      if lProjectFactsCacheInvalidated then
        Result.Metrics.ProjectFactsCacheInvalidations := 1;
      StoreProjectFactsCache(lProjectFactsCacheFileName, lProjectFactsCacheKey, Result);
    end;
  finally
    lGraph.Free;
  end;
end;

function TDelphiSemanticProjectSession.PlanInvalidation(
  const aChanges: TArray<TDelphiSemanticSessionChange>):
  TDelphiSemanticSessionInvalidationPlan;
var
  lChange: TDelphiSemanticSessionChange;
  lFiles: TList<string>;
  lModel: TDelphiSemanticUnitModel;
  lModels: TArray<TDelphiSemanticUnitModel>;
  lReasons: TList<string>;
  lUnits: TList<string>;
begin
  Result := Default(TDelphiSemanticSessionInvalidationPlan);
  lFiles := TList<string>.Create;
  lUnits := TList<string>.Create;
  lReasons := TList<string>.Create;
  try
    lModels := ExtractProjectModels(fProject, fOptions);
    for lChange in aChanges do
    begin
      if SameText(lChange.ChangeKind, 'context') then
      begin
        Result.ContextInvalidated := True;
        Result.RequiresFullSessionRebuild := True;
        AddUniqueText(lReasons, 'CONTEXT_CHANGED');
        AddAllModels(lModels, lFiles, lUnits);
      end else if SameText(lChange.ChangeKind, 'include') or
        SameText(TPath.GetExtension(lChange.FileName), '.inc') then
      begin
        Result.IncludeGraphInvalidated := True;
        AddUniqueText(lReasons, 'INCLUDE_GRAPH_CHANGED');
        AddAllModels(lModels, lFiles, lUnits);
      end else if SameText(lChange.ChangeKind, 'unknown') then
      begin
        Result.RequiresFullSessionRebuild := True;
        AddUniqueText(lReasons, 'UNKNOWN_CHANGE');
        AddAllModels(lModels, lFiles, lUnits);
      end else if FindModelByFileName(lModels, lChange.FileName, lModel) then
      begin
        if (not lModel.Success) or (Trim(lModel.UnitName) = '') then
        begin
          Result.RequiresFullSessionRebuild := True;
          AddUniqueText(lReasons, 'CHANGED_UNIT_MODEL_UNAVAILABLE');
          AddAllModels(lModels, lFiles, lUnits);
          Continue;
        end;

        if SameText(lChange.ChangeKind, 'implementation') then
        begin
          AddUniqueText(lReasons, 'IMPLEMENTATION_CHANGED');
          AddAffectedModel(lModel, lFiles, lUnits);
        end else
        begin
          if SameText(lChange.ChangeKind, 'type-ancestor') or
            SameText(lChange.ChangeKind, 'helper') then
            Result.LookupMemoizationInvalidated := True;
          AddUniqueText(lReasons, UpperCase(StringReplace(lChange.ChangeKind, '-',
            '_', [rfReplaceAll])) + '_CHANGED');
          AddDependentClosure(lModels, lModel, lFiles, lUnits);
        end;
      end else
      begin
        Result.RequiresFullSessionRebuild := True;
        AddUniqueText(lReasons, 'CHANGE_OUTSIDE_PROJECT_MODEL');
        AddAllModels(lModels, lFiles, lUnits);
      end;
    end;

    Result.AffectedUnitFiles := lFiles.ToArray;
    Result.AffectedUnitNames := lUnits.ToArray;
    Result.Reasons := lReasons.ToArray;
  finally
    lReasons.Free;
    lUnits.Free;
    lFiles.Free;
  end;
end;

class function TDelphiSemanticProjectSession.Open(const aOptions: TDelphiSemanticOptions):
  TDelphiSemanticProjectSessionResult;
var
  lContext: TDelphiSemanticContextResult;
begin
  if Trim(aOptions.ProjectPath) = '' then
    Exit(MissingProjectPathFailure);

  lContext := TDelphiSemanticProject.Load(aOptions.ProjectPath, aOptions);
  if not lContext.Success then
    Exit(SessionFailure(lContext));

  Result := Default(TDelphiSemanticProjectSessionResult);
  Result.Success := True;
  Result.Status := psOpen;
  Result.Provenance := 'project-context';
  Result.Diagnostics := Copy(lContext.Diagnostics);
  Result.Session := TDelphiSemanticProjectSession.Create(aOptions, lContext.Project,
    lContext.Diagnostics, Result.Status, Result.Provenance);
end;

end.
