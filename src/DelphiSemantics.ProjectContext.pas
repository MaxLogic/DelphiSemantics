unit DelphiSemantics.ProjectContext;

interface

uses
  DelphiSemantics.RootMemberAbsence;

const
  cDelphiSemanticCompilerLinkPropertyNames: array[0..4] of string = (
    'DCC_UsePackage', 'UsePackages', 'DCC_EnabledPackages', '_UsePackage',
    'DCC_AdditionalSwitches');

type
  TDelphiSemanticDiagnosticSeverity = (dsInfo, dsWarning, dsError);

  TDelphiSemanticProperty = record
    Name: string;
    Value: string;
  end;

  TDelphiSemanticProfileFolder = (pfDocuments, pfPublicDocuments);

  // Optional system-input boundary; nil uses our native Windows profile inputs.
  IDelphiSemanticProfileInputs = interface
    ['{BE506838-E9B9-4657-9D4B-F22ED5514F50}']
    function TryEnvironmentValue(const aName: string; out aValue: string): Boolean;
    function RegistryValues(const aKey: string; const aView: Cardinal): TArray<TDelphiSemanticProperty>;
    function KnownFolderPath(const aFolder: TDelphiSemanticProfileFolder): string;
  end;

  TDelphiSemanticOptions = record
    ProjectPath: string;
    Configuration: string;
    Platform: string;
    DelphiVersion: string;
    RsVarsPath: string;
    EnvOptionsPath: string;
    ProfileInputs: IDelphiSemanticProfileInputs;
    EnvironmentVariables: TArray<TDelphiSemanticProperty>;
    AdditionalSourceFileNames: TArray<string>;
    CallerDefinesProvided: Boolean;
    // Complete ordered include-search option directories used by the compiler.
      // The caller certifies completeness, including additional -I and response files.
      // Relative entries are project-relative. DS never appends emulated directories.
      // Native source-directory lookup remains separate from this option list.
      // Provided distinguishes certified empty from unavailable evidence.
    CompilerIncludeSearchPath: string;
    CompilerIncludeSearchPathProvided: Boolean;
    SearchPaths: TArray<string>;
    SqliteCacheFileName: string;
    // Certify every external compiler/context input, including ordered native
    // settings, compiler content and captured environments. False bypasses reuse.
    PlanningCacheInputsProvided: Boolean;
    PlanningCacheInputs: TArray<TDelphiSemanticProperty>;
    SnapshotBuildWorkerCount: Integer;
    UseLspEnrichment: Boolean;
    SkipWithBindingSemanticGraph: Boolean;
    ImplicitRootMemberAbsence: IDelphiSemanticImplicitRootMemberAbsence;
    ForceFullIdentifierAnalysis: Boolean;
  end;

  TDelphiSemanticDiagnostic = record
    Code: string;
    Message: string;
    FileName: string;
    Line: Integer;
    Column: Integer;
    Severity: TDelphiSemanticDiagnosticSeverity;
  end;

  TDelphiSemanticProjectContextObservationKind = (pckoInput, pckoPresence,
    pckoSearchCandidate);

  TDelphiSemanticProjectContextObservation = record
    Kind: TDelphiSemanticProjectContextObservationKind;
    FileName: string;
    ContentHash: string;
    Role: string;
    Exists: Boolean;
    Selected: Boolean;
  end;

  IDelphiSemanticProjectContextObservations = interface
    ['{9BC8154A-8D58-4C50-B83B-BF6477A0C3E8}']
    function GetCount: Integer;
    function GetItem(const aIndex: Integer): TDelphiSemanticProjectContextObservation;
    function GetEvidenceFingerprint: string;
    function GetConfigurationIdentity: string;
    property Count: Integer read GetCount;
    property Items[const aIndex: Integer]: TDelphiSemanticProjectContextObservation read GetItem;
    property EvidenceFingerprint: string read GetEvidenceFingerprint;
    property ConfigurationIdentity: string read GetConfigurationIdentity;
  end;

  TDelphiSemanticProjectInfo = record
    ProjectFileName: string;
    ProjectDirectory: string;
    ProjectName: string;
    Configuration: string;
    Platform: string;
    MainSourceFileName: string;
    SourceFileNames: TArray<string>;
    Defines: TArray<string>;
    DefineEvidenceComplete: Boolean;
    IncludePaths: TArray<string>;
    SearchPaths: TArray<string>;
    UnitScopeNames: TArray<string>;
    UnitAliases: TArray<string>;
    ReferenceDirectories: TArray<string>;
    Properties: TArray<TDelphiSemanticProperty>;
    CompilerProfileName: string;
    ContextFingerprint: string;
    ContextObservations: IDelphiSemanticProjectContextObservations;
    function PropertyValue(const aName: string): string;
    function SourceLookupPaths: TArray<string>;
  end;

  IDelphiSemanticProjectProfileValidator = interface
    ['{86A704A8-67F1-4E5F-B4DE-09751D1F370B}']
    function ValidateProjectProfile(const aProject: TDelphiSemanticProjectInfo;
      out aReason: string): Boolean;
  end;

  TDelphiSemanticContextResult = record
    Success: Boolean;
    Project: TDelphiSemanticProjectInfo;
    Diagnostics: TArray<TDelphiSemanticDiagnostic>;
  end;

  TDelphiSemanticProject = record
  public
    class function Load(const aFileName: string): TDelphiSemanticContextResult; overload; static;
    class function Load(const aFileName: string; const aOptions: TDelphiSemanticOptions): TDelphiSemanticContextResult; overload; static;
  end;

  TDelphiSemanticMsBuild = record
  public
    class function ExpandMacros(const aValue: string; const aProperties, aEnvironment: TArray<TDelphiSemanticProperty>;
      const aUnknownAsEmpty: Boolean; out aDiagnostics: TArray<TDelphiSemanticDiagnostic>): string; static;
    class function TryEvaluateCondition(const aCondition, aBaseDirectory: string;
      const aProperties, aEnvironment: TArray<TDelphiSemanticProperty>; out aResult: Boolean; out aError: string;
      out aDiagnostics: TArray<TDelphiSemanticDiagnostic>): Boolean; static;
  end;

// Search entries are MSBuild list values, not command-line arguments. Quotes
// remain in the native search item and must not be stripped to invent a directory.
function TryResolveCompilerSearchPathEntry(const aBaseDirectory, aValue: string;
  out aPath, aError: string): Boolean;

implementation

uses
  System.Classes, System.Generics.Collections, System.Generics.Defaults, System.Hash,
  System.IOUtils, System.RegularExpressions, System.StrUtils, System.SysUtils,
  System.Win.ComObj, System.Win.Registry, Xml.omnixmldom, Xml.XMLDoc, Xml.XMLIntf, Xml.xmldom,
  Winapi.ActiveX, Winapi.KnownFolders, Winapi.ShlObj, Winapi.Windows,
  MaxLogic.IOUtils, MaxLogic.StrUtils,
  DelphiSemantics.Cache, DelphiSemantics.CompilerProfile, DelphiSemantics.Lsp;

const
  cOptionalCompilerIncludeProperties: array[0..9] of string = ('BDSLIB', 'DelphiLibraryPath', 'DCC_UnitSearchPath',
    'LANGDIR', 'DCC_DebugDCUs', 'DelphiDebugDCUPath', 'DCC_TranslatedLibraryPath',
    'DCC_TranslatedDebugLibraryPath', 'DelphiTranslatedLibraryPath', 'DelphiTranslatedDebugLibraryPath');

type
  TPropertyMap = TDictionary<string, string>;

  TNativeProfileInputs = class(TInterfacedObject, IDelphiSemanticProfileInputs)
  public
    function TryEnvironmentValue(const aName: string; out aValue: string): Boolean;
    function RegistryValues(const aKey: string; const aView: Cardinal): TArray<TDelphiSemanticProperty>;
    function KnownFolderPath(const aFolder: TDelphiSemanticProfileFolder): string;
  end;

  IProjectContextObservationsBuilder = interface
    ['{319C9185-AD19-4EE7-A1AA-09D9FBDEAC58}']
    procedure AddInput(const aFileName, aContentHash, aRole: string);
    procedure AddPresence(const aFileName, aRole: string; const aExists: Boolean);
    procedure AddSearchCandidate(const aFileName, aRole: string; const aExists,
      aSelected: Boolean);
    procedure MarkIncomplete;
    procedure MarkDefineEvidenceIncomplete;
    function DefineEvidenceIsComplete: Boolean;
    procedure MarkBoundedDefineImportPending;
    function BoundedDefineImportPending: Boolean;
    function Build(const aConfigurationIdentity: string):
      IDelphiSemanticProjectContextObservations;
  end;

  TProjectContextObservations = class(TInterfacedObject,
    IDelphiSemanticProjectContextObservations)
  private
    fConfigurationIdentity: string;
    fEvidenceFingerprint: string;
    fItems: TArray<TDelphiSemanticProjectContextObservation>;
  public
    constructor Create(const aItems: TArray<TDelphiSemanticProjectContextObservation>;
      const aConfigurationIdentity, aEvidenceFingerprint: string);
    function GetCount: Integer;
    function GetItem(const aIndex: Integer): TDelphiSemanticProjectContextObservation;
    function GetEvidenceFingerprint: string;
    function GetConfigurationIdentity: string;
  end;

  TProjectContextObservationsBuilder = class(TInterfacedObject,
    IProjectContextObservationsBuilder)
  private
    fConsistent: Boolean;
    fDefineEvidenceIncomplete: Boolean;
    fBoundedDefineImportPending: Boolean;
    fInputHashes: TDictionary<string, string>;
    fItems: TList<TDelphiSemanticProjectContextObservation>;
    function CanonicalPath(const aFileName: string): string;
  public
    constructor Create;
    destructor Destroy; override;
    procedure AddInput(const aFileName, aContentHash, aRole: string);
    procedure AddPresence(const aFileName, aRole: string; const aExists: Boolean);
    procedure AddSearchCandidate(const aFileName, aRole: string; const aExists,
      aSelected: Boolean);
    procedure MarkIncomplete;
    procedure MarkDefineEvidenceIncomplete;
    function DefineEvidenceIsComplete: Boolean;
    procedure MarkBoundedDefineImportPending;
    function BoundedDefineImportPending: Boolean;
    function Build(const aConfigurationIdentity: string):
      IDelphiSemanticProjectContextObservations;
  end;

procedure AppendFingerprintItem(const aBuilder: TStringBuilder; const aName,
  aValue: string); forward;

constructor TProjectContextObservations.Create(
  const aItems: TArray<TDelphiSemanticProjectContextObservation>;
  const aConfigurationIdentity, aEvidenceFingerprint: string);
begin
  inherited Create;
  fItems := Copy(aItems);
  fConfigurationIdentity := aConfigurationIdentity;
  fEvidenceFingerprint := aEvidenceFingerprint;
end;

function TProjectContextObservations.GetCount: Integer;
begin
  Result := Length(fItems);
end;

function TProjectContextObservations.GetItem(
  const aIndex: Integer): TDelphiSemanticProjectContextObservation;
begin
  Result := fItems[aIndex];
end;

function TProjectContextObservations.GetEvidenceFingerprint: string;
begin
  Result := fEvidenceFingerprint;
end;

function TProjectContextObservations.GetConfigurationIdentity: string;
begin
  Result := fConfigurationIdentity;
end;

constructor TProjectContextObservationsBuilder.Create;
begin
  inherited Create;
  fConsistent := True;
  fInputHashes := TDictionary<string, string>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
  fItems := TList<TDelphiSemanticProjectContextObservation>.Create;
end;

destructor TProjectContextObservationsBuilder.Destroy;
begin
  fItems.Free;
  fInputHashes.Free;
  inherited Destroy;
end;

function TProjectContextObservationsBuilder.CanonicalPath(const aFileName: string): string;
begin
  try
    Result := TPath.GetFullPath(aFileName);
  except
    fConsistent := False;
    Result := aFileName;
  end;
end;

procedure TProjectContextObservationsBuilder.AddInput(const aFileName, aContentHash,
  aRole: string);
var
  lCanonicalFileName: string;
  lExistingHash: string;
  lObservation: TDelphiSemanticProjectContextObservation;
begin
  if (Trim(aFileName) = '') or (Trim(aContentHash) = '') then
  begin
    MarkIncomplete;
    Exit;
  end;

  lCanonicalFileName := CanonicalPath(aFileName);
  if fInputHashes.TryGetValue(lCanonicalFileName, lExistingHash) then
  begin
    if not SameText(lExistingHash, aContentHash) then
      MarkIncomplete;
    Exit;
  end;

  fInputHashes.Add(lCanonicalFileName, aContentHash);
  lObservation := Default(TDelphiSemanticProjectContextObservation);
  lObservation.Kind := TDelphiSemanticProjectContextObservationKind.pckoInput;
  lObservation.FileName := lCanonicalFileName;
  lObservation.ContentHash := aContentHash;
  lObservation.Role := aRole;
  lObservation.Exists := True;
  fItems.Add(lObservation);
end;

procedure TProjectContextObservationsBuilder.AddPresence(const aFileName, aRole: string;
  const aExists: Boolean);
var
  lObservation: TDelphiSemanticProjectContextObservation;
begin
  lObservation := Default(TDelphiSemanticProjectContextObservation);
  lObservation.Kind := TDelphiSemanticProjectContextObservationKind.pckoPresence;
  lObservation.FileName := CanonicalPath(aFileName);
  lObservation.Role := aRole;
  lObservation.Exists := aExists;
  fItems.Add(lObservation);
end;

procedure TProjectContextObservationsBuilder.AddSearchCandidate(const aFileName, aRole: string;
  const aExists, aSelected: Boolean);
var
  lObservation: TDelphiSemanticProjectContextObservation;
begin
  lObservation := Default(TDelphiSemanticProjectContextObservation);
  lObservation.Kind := TDelphiSemanticProjectContextObservationKind.pckoSearchCandidate;
  lObservation.FileName := CanonicalPath(aFileName);
  lObservation.Role := aRole;
  lObservation.Exists := aExists;
  lObservation.Selected := aSelected;
  fItems.Add(lObservation);
end;

procedure TProjectContextObservationsBuilder.MarkDefineEvidenceIncomplete;
begin
  fDefineEvidenceIncomplete := True;
end;

function TProjectContextObservationsBuilder.DefineEvidenceIsComplete: Boolean;
begin
  Result := not fDefineEvidenceIncomplete;
end;

procedure TProjectContextObservationsBuilder.MarkBoundedDefineImportPending;
begin
  fBoundedDefineImportPending := True;
end;

function TProjectContextObservationsBuilder.BoundedDefineImportPending: Boolean;
begin
  Result := fBoundedDefineImportPending;
end;

procedure TProjectContextObservationsBuilder.MarkIncomplete;
begin
  fConsistent := False;
end;

function TProjectContextObservationsBuilder.Build(
  const aConfigurationIdentity: string): IDelphiSemanticProjectContextObservations;
var
  lBuilder: TStringBuilder;
  lFingerprint: string;
  lIndex: Integer;
  lObservation: TDelphiSemanticProjectContextObservation;
begin
  lFingerprint := '';
  if fConsistent then
  begin
    lBuilder := TStringBuilder.Create;
    try
      lBuilder.AppendLine('schema=project-context-observations-v1');
      AppendFingerprintItem(lBuilder, 'configuration', aConfigurationIdentity);
      lIndex := 0;
      for lObservation in fItems do
      begin
        AppendFingerprintItem(lBuilder, 'sequence', IntToStr(lIndex));
        AppendFingerprintItem(lBuilder, 'kind', IntToStr(Ord(lObservation.Kind)));
        AppendFingerprintItem(lBuilder, 'file',
          TDelphiSemanticCacheIdentityBuilder.CanonicalPath(lObservation.FileName));
        AppendFingerprintItem(lBuilder, 'hash', lObservation.ContentHash);
        AppendFingerprintItem(lBuilder, 'role', lObservation.Role);
        AppendFingerprintItem(lBuilder, 'exists', BoolToStr(lObservation.Exists, True));
        AppendFingerprintItem(lBuilder, 'selected', BoolToStr(lObservation.Selected, True));
        Inc(lIndex);
      end;
      lFingerprint := THashSHA2.GetHashString(lBuilder.ToString);
    finally
      lBuilder.Free;
    end;
  end;

  Result := TProjectContextObservations.Create(fItems.ToArray, aConfigurationIdentity,
    lFingerprint);
end;

function HashProjectContextBytes(const aBytes: TBytes): string;
var
  lHash: THashSHA2;
begin
  lHash := THashSHA2.Create;
  if Length(aBytes) > 0 then
    lHash.Update(aBytes);
  Result := lHash.HashAsString;
end;

procedure ReadProjectContextInput(const aFileName, aRole: string;
  const aObservations: IProjectContextObservationsBuilder; out aText: string);
var
  lBytes: TBytes;
  lEncoding: TEncoding;
  lPreambleLength: Integer;
begin
  lBytes := TFile.ReadAllBytes(aFileName);
  if aObservations <> nil then
    aObservations.AddInput(aFileName, HashProjectContextBytes(lBytes), aRole);

  lEncoding := TEncoding.UTF8;
  lPreambleLength := TEncoding.GetBufferEncoding(lBytes, lEncoding, TEncoding.UTF8);
  aText := lEncoding.GetString(lBytes, lPreambleLength, Length(lBytes) - lPreambleLength);
end;

function TDelphiSemanticProjectInfo.PropertyValue(const aName: string): string;
var
  lProperty: TDelphiSemanticProperty;
begin
  for lProperty in Properties do
    if SameText(lProperty.Name, aName) then
      Exit(lProperty.Value);

  Result := '';
end;

function CreateDiagnostic(const aCode, aMessage, aFileName: string;
  const aSeverity: TDelphiSemanticDiagnosticSeverity): TDelphiSemanticDiagnostic;
begin
  Result.Code := aCode;
  Result.Message := aMessage;
  Result.FileName := aFileName;
  Result.Line := 0;
  Result.Column := 0;
  Result.Severity := aSeverity;
end;

function CreateErrorDiagnostic(const aCode, aMessage, aFileName: string): TDelphiSemanticDiagnostic;
begin
  Result := CreateDiagnostic(aCode, aMessage, aFileName, dsError);
end;

function CreateWarningDiagnostic(const aCode, aMessage, aFileName: string): TDelphiSemanticDiagnostic;
begin
  Result := CreateDiagnostic(aCode, aMessage, aFileName, dsWarning);
end;

function FailureResult(const aDiagnostic: TDelphiSemanticDiagnostic): TDelphiSemanticContextResult;
begin
  Result.Success := False;
  SetLength(Result.Diagnostics, 1);
  Result.Diagnostics[0] := aDiagnostic;
end;

function SuccessResult(const aProject: TDelphiSemanticProjectInfo;
  const aDiagnostics: TList<TDelphiSemanticDiagnostic>): TDelphiSemanticContextResult;
begin
  Result.Success := True;
  Result.Project := aProject;
  Result.Diagnostics := aDiagnostics.ToArray;
end;

function TryReadEnvironmentRegistryValue(const aRoot: HKEY; const aKey, aName: string;
  out aValue: string): Boolean;
var
  lRegistry: TRegistry;
begin
  aValue := '';
  lRegistry := TRegistry.Create(KEY_READ);
  try
    lRegistry.RootKey := aRoot;
    Result := lRegistry.OpenKeyReadOnly(aKey) and lRegistry.ValueExists(aName) and
      (lRegistry.GetDataType(aName) in [rdString, rdExpandString]);
    if Result then
      aValue := lRegistry.ReadString(aName);
  finally
    lRegistry.Free;
  end;
end;

function TNativeProfileInputs.TryEnvironmentValue(const aName: string;
  out aValue: string): Boolean;
var
  lBlock, lEntry: PWideChar;
  lText: string;
  lSeparator: Integer;
begin
  aValue := '';
  // A copied environment block preserves present-empty entries without changing
  // process state or racing a size/read pair of GetEnvironmentVariable calls.
  lBlock := GetEnvironmentStringsW;
  if lBlock = nil then
    RaiseLastOSError;
  try
    lEntry := lBlock;
    while lEntry^ <> #0 do
    begin
      lText := lEntry;
      lSeparator := Pos('=', lText);
      if (lSeparator > 1) and SameText(Copy(lText, 1, lSeparator - 1), aName) then
      begin
        aValue := Copy(lText, lSeparator + 1, MaxInt);
        Exit(True);
      end;
      Inc(lEntry, Length(lText) + 1);
    end;
  finally
    FreeEnvironmentStringsW(lBlock);
  end;
  Result := TryReadEnvironmentRegistryValue(HKEY_CURRENT_USER, 'Environment', aName, aValue);
  if not Result then
    Result := TryReadEnvironmentRegistryValue(HKEY_LOCAL_MACHINE,
      'SYSTEM\CurrentControlSet\Control\Session Manager\Environment', aName, aValue);
end;

function TNativeProfileInputs.RegistryValues(const aKey: string;
  const aView: Cardinal): TArray<TDelphiSemanticProperty>;
var
  lRegistry: TRegistry;
  lNames: TStringList;
  lValues: TList<TDelphiSemanticProperty>;
  lName: string;
  lValue: TDelphiSemanticProperty;
begin
  lRegistry := TRegistry.Create(KEY_READ or aView);
  lNames := TStringList.Create;
  lValues := TList<TDelphiSemanticProperty>.Create;
  try
    lRegistry.RootKey := HKEY_CURRENT_USER;
    if lRegistry.OpenKeyReadOnly(aKey) then
    begin
      lRegistry.GetValueNames(lNames);
      for lName in lNames do
        if lRegistry.GetDataType(lName) in [rdString, rdExpandString] then
        begin
          lValue.Name := lName;
          lValue.Value := lRegistry.ReadString(lName);
          lValues.Add(lValue);
        end;
    end;
    Result := lValues.ToArray;
  finally
    lValues.Free;
    lNames.Free;
    lRegistry.Free;
  end;
end;

function TNativeProfileInputs.KnownFolderPath(
  const aFolder: TDelphiSemanticProfileFolder): string;
var
  lPath: PWideChar;
  lFolder: TGUID;
begin
  if aFolder = TDelphiSemanticProfileFolder.pfDocuments then
    lFolder := FOLDERID_Documents
  else
    lFolder := FOLDERID_PublicDocuments;
  lPath := nil;
  try
    OleCheck(SHGetKnownFolderPath(lFolder, KF_FLAG_DONT_VERIFY, 0, lPath));
    Result := lPath;
  finally
    CoTaskMemFree(lPath);
  end;
end;

function ProfileInputs(const aOptions: TDelphiSemanticOptions): IDelphiSemanticProfileInputs;
begin
  Result := aOptions.ProfileInputs;
  if Result = nil then
    Result := TNativeProfileInputs.Create;
end;

function ProfileVersion(const aOptions: TDelphiSemanticOptions): string;
begin
  Result := aOptions.DelphiVersion.Trim;
  if Result = '' then
    Result := '23.0';
  if Pos('.', Result) = 0 then
    Result := Result + '.0';
end;

function PropertyKey(const aName: string): string;
begin
  Result := UpperCase(aName);
end;

function PropertyArrayToMap(const aProperties: TArray<TDelphiSemanticProperty>): TPropertyMap;
var
  lProperty: TDelphiSemanticProperty;
begin
  Result := TPropertyMap.Create;
  for lProperty in aProperties do
    Result.AddOrSetValue(PropertyKey(lProperty.Name), lProperty.Value);
end;

function TryGetPropertyValue(const aProperties: TPropertyMap; const aName: string;
  out aValue: string): Boolean;
begin
  Result := aProperties.TryGetValue(PropertyKey(aName), aValue);
  if not Result then
  begin
    aValue := '';
    // Delphi's generated configuration selectors are intentionally absent for
    // inactive configurations; MSBuild compares those unset values as empty.
    Result := StartsText('Base_', aName) or StartsText('Cfg_', aName);
  end;
end;

function TryGetMacroValue(const aProperties, aEnvironment: TPropertyMap; const aName: string;
  out aValue: string): Boolean;
begin
  if (aProperties <> nil) and aProperties.TryGetValue(PropertyKey(aName), aValue) then
    Exit(True);
  if (aEnvironment <> nil) and aEnvironment.TryGetValue(PropertyKey(aName), aValue) then
    Exit(True);

  aValue := System.SysUtils.GetEnvironmentVariable(aName);
  Result := aValue <> '';
end;

function MacroStackContains(const aStack: TList<string>; const aName: string): Boolean;
var
  lItem: string;
begin
  for lItem in aStack do
    if SameText(lItem, aName) then
      Exit(True);

  Result := False;
end;

procedure AddDiagnostic(const aDiagnostics: TList<TDelphiSemanticDiagnostic>;
  const aDiagnostic: TDelphiSemanticDiagnostic); forward;
function TryEvaluateConditionExpression(const aCondition, aFileName, aBaseDirectory: string;
  const aProperties: TPropertyMap; const aDiagnostics: TList<TDelphiSemanticDiagnostic>;
  out aActive: Boolean;
  const aObservations: IProjectContextObservationsBuilder = nil): Boolean; forward;

function ExpandMacroText(const aValue: string; const aProperties, aEnvironment: TPropertyMap;
  const aDiagnostics: TList<TDelphiSemanticDiagnostic>; const aUnknownAsEmpty: Boolean;
  const aStack: TList<string>): string;
var
  lIndex: Integer;
  lMacroStart: Integer;
  lMacroValue: string;
  lName: string;
  lReplacement: string;
  lResult: TStringBuilder;
begin
  lResult := TStringBuilder.Create;
  try
    lIndex := 1;
    while lIndex <= Length(aValue) do
    begin
      if (aValue[lIndex] = '$') and (lIndex < Length(aValue)) and (aValue[lIndex + 1] = '(') then
      begin
        lMacroStart := lIndex + 2;
        Inc(lIndex, 2);
        while (lIndex <= Length(aValue)) and (aValue[lIndex] <> ')') do
          Inc(lIndex);

        if lIndex > Length(aValue) then
        begin
          lResult.Append('$(');
          lResult.Append(Copy(aValue, lMacroStart, MaxInt));
          Break;
        end;

        lName := Copy(aValue, lMacroStart, lIndex - lMacroStart);
        if MacroStackContains(aStack, lName) then
        begin
          if (aDiagnostics <> nil) and (not aUnknownAsEmpty) then
            AddDiagnostic(aDiagnostics, CreateWarningDiagnostic('CYCLE_MSBUILD_MACRO',
              'Cycle in MSBuild macro: $(' + lName + ')', ''));
          if aUnknownAsEmpty then
            lReplacement := ''
          else
            lReplacement := '$(' + lName + ')';
        end else if TryGetMacroValue(aProperties, aEnvironment, lName, lMacroValue) then
        begin
          aStack.Add(lName);
          try
            lReplacement := ExpandMacroText(lMacroValue, aProperties, aEnvironment, aDiagnostics,
              aUnknownAsEmpty, aStack);
          finally
            aStack.Delete(aStack.Count - 1);
          end;
        end else
        begin
          if (aDiagnostics <> nil) and (not aUnknownAsEmpty) then
            AddDiagnostic(aDiagnostics, CreateWarningDiagnostic('UNRESOLVED_MSBUILD_MACRO',
              'Unresolved MSBuild macro: $(' + lName + ')', ''));
          if aUnknownAsEmpty then
            lReplacement := ''
          else
            lReplacement := '$(' + lName + ')';
        end;

        lResult.Append(lReplacement);
        Inc(lIndex);
      end else
      begin
        lResult.Append(aValue[lIndex]);
        Inc(lIndex);
      end;
    end;

    Result := lResult.ToString;
  finally
    lResult.Free;
  end;
end;

class function TDelphiSemanticMsBuild.ExpandMacros(const aValue: string;
  const aProperties, aEnvironment: TArray<TDelphiSemanticProperty>; const aUnknownAsEmpty: Boolean;
  out aDiagnostics: TArray<TDelphiSemanticDiagnostic>): string;
var
  lDiagnostics: TList<TDelphiSemanticDiagnostic>;
  lEnvironment: TPropertyMap;
  lProperties: TPropertyMap;
  lStack: TList<string>;
begin
  lProperties := PropertyArrayToMap(aProperties);
  try
    lEnvironment := PropertyArrayToMap(aEnvironment);
    try
      lDiagnostics := TList<TDelphiSemanticDiagnostic>.Create;
      try
        lStack := TList<string>.Create;
        try
          Result := ExpandMacroText(aValue, lProperties, lEnvironment, lDiagnostics,
            aUnknownAsEmpty, lStack);
          aDiagnostics := lDiagnostics.ToArray;
        finally
          lStack.Free;
        end;
      finally
        lDiagnostics.Free;
      end;
    finally
      lEnvironment.Free;
    end;
  finally
    lProperties.Free;
  end;
end;

class function TDelphiSemanticMsBuild.TryEvaluateCondition(const aCondition, aBaseDirectory: string;
  const aProperties, aEnvironment: TArray<TDelphiSemanticProperty>; out aResult: Boolean;
  out aError: string; out aDiagnostics: TArray<TDelphiSemanticDiagnostic>): Boolean;
var
  lDiagnostics: TList<TDelphiSemanticDiagnostic>;
  lEnvironment: TPropertyMap;
  lExpandedCondition: string;
  lProperties: TPropertyMap;
  lStack: TList<string>;
begin
  aResult := True;
  aError := '';
  lProperties := PropertyArrayToMap(aProperties);
  try
    lEnvironment := PropertyArrayToMap(aEnvironment);
    try
      lDiagnostics := TList<TDelphiSemanticDiagnostic>.Create;
      try
        lStack := TList<string>.Create;
        try
          lExpandedCondition := ExpandMacroText(aCondition, lProperties, lEnvironment,
            lDiagnostics, True, lStack);
        finally
          lStack.Free;
        end;

        if lExpandedCondition.Trim = '' then
        begin
          aDiagnostics := lDiagnostics.ToArray;
          Exit(True);
        end;

        Result := TryEvaluateConditionExpression(lExpandedCondition, '', aBaseDirectory,
          lProperties, lDiagnostics, aResult);
        if not Result then
          aError := 'Unsupported or invalid Condition: ' + aCondition;
        aDiagnostics := lDiagnostics.ToArray;
      finally
        lDiagnostics.Free;
      end;
    finally
      lEnvironment.Free;
    end;
  finally
    lProperties.Free;
  end;
end;

function GetPropertyValue(const aProperties: TPropertyMap; const aName: string): string;
begin
  TryGetPropertyValue(aProperties, aName, Result);
end;

procedure SetPropertyValue(const aProperties: TPropertyMap; const aName, aValue: string);
var
  lKey: string;
  lValue: string;
begin
  lKey := PropertyKey(aName);
  lValue := aValue;
  if lValue.Trim = '''''' then
    lValue := '';

  if aProperties.ContainsKey(lKey) then
    aProperties[lKey] := lValue
  else
    aProperties.Add(lKey, lValue);
end;

procedure AddDiagnostic(const aDiagnostics: TList<TDelphiSemanticDiagnostic>;
  const aDiagnostic: TDelphiSemanticDiagnostic);
begin
  aDiagnostics.Add(aDiagnostic);
end;

function LoadProjectXml(const aText: string): IXMLDocument;
var
  lDocument: TXMLDocument;
begin
  lDocument := TXMLDocument.Create(nil);
  try
    lDocument.DOMVendor := GetDOMVendor(sOmniXmlVendor);
    lDocument.LoadFromXML(aText);
    Result := lDocument as IXMLDocument;
  except
    lDocument.Free;
    raise;
  end;
end;

function IsXmlElement(const aNode: IXMLNode): Boolean;
begin
  Result := Assigned(aNode) and (aNode.NodeType = ntElement);
end;

function XmlNodeName(const aNode: IXMLNode): string;
begin
  Result := '';
  if not Assigned(aNode) then
    Exit;

  Result := aNode.LocalName;
  if Result = '' then
    Result := aNode.NodeName;
end;

function IsXmlElementNamed(const aNode: IXMLNode; const aName: string): Boolean;
begin
  Result := IsXmlElement(aNode) and SameText(XmlNodeName(aNode), aName);
end;

function XmlNodeAttributeValue(const aNode: IXMLNode; const aName: string): string;
begin
  if Assigned(aNode) and aNode.HasAttribute(aName) then
    Result := string(aNode.Attributes[aName]).Trim
  else
    Result := '';
end;

function TryFindXmlElementText(const aNode: IXMLNode; const aName: string;
  out aValue: string): Boolean;
var
  i: Integer;
  lChild: IXMLNode;
begin
  Result := False;
  if not Assigned(aNode) then
    Exit;

  if IsXmlElementNamed(aNode, aName) then
  begin
    aValue := aNode.Text.Trim;
    Exit(True);
  end;

  for i := 0 to aNode.ChildNodes.Count - 1 do
  begin
    lChild := aNode.ChildNodes[i];
    if TryFindXmlElementText(lChild, aName, aValue) then
      Exit(True);
  end;
end;

function XmlElementText(const aDocument: IXMLDocument; const aName: string): string;
begin
  Result := '';
  if Assigned(aDocument) then
    TryFindXmlElementText(aDocument.DocumentElement, aName, Result);
end;

function TryResolveCompilerSearchPathEntry(const aBaseDirectory, aValue: string;
  out aPath, aError: string): Boolean;
var
  lValue: string;
begin
  Result := False;
  aPath := '';
  aError := '';
  lValue := Trim(aValue);
  if Pos('"', lValue) > 0 then
  begin
    aError := Format('Compiler search path entry [%s] contains a quote; its directory is unproved.', [aValue]);
    Exit;
  end;
  if Pos('$(', lValue) > 0 then
  begin
    aError := Format('Compiler search path entry [%s] contains an unresolved macro.', [aValue]);
    Exit;
  end;
  try
    if lValue <> '' then
    begin
      if not TPath.IsPathRooted(lValue) then
        lValue := TPath.Combine(aBaseDirectory, lValue);
      aPath := TPath.GetFullPath(lValue);
    end;
    Result := True;
  except
    on E: EArgumentException do
      aError := Format('Compiler search path entry [%s] is unusable: %s', [aValue, E.Message]);
  end;
end;

type
  ECompilerSearchPathError = class(EConvertError);

function NormalizeProjectPath(const aBaseDirectory, aFileName: string): string;
begin
  if TPath.IsPathRooted(aFileName) then
    Result := TPath.GetFullPath(aFileName)
  else
    Result := TPath.GetFullPath(TPath.Combine(aBaseDirectory, aFileName));
end;

function StripOuterParentheses(const aValue: string): string; forward;
function ExpandProperties(const aValue, aFileName: string; const aProperties: TPropertyMap;
  const aDiagnostics: TList<TDelphiSemanticDiagnostic>): string; forward;

function IsQuotedConditionValue(const aValue: string): Boolean;
var
  lText: string;
begin
  lText := aValue.Trim;
  Result := (Length(lText) >= 2) and (lText[1] = '''') and (lText[Length(lText)] = '''');
end;

function TryGetConditionOperand(const aValue, aFileName: string; const aProperties: TPropertyMap;
  const aDiagnostics: TList<TDelphiSemanticDiagnostic>; out aOperand: string): Boolean;
var
  lText: string;
begin
  lText := StripOuterParentheses(aValue);
  if lText = '' then
  begin
    aOperand := '';
    Exit(True);
  end;

  if (lText[1] = '''') or (lText[Length(lText)] = '''') then
  begin
    if not IsQuotedConditionValue(lText) then
      Exit(False);

    lText := Copy(lText, 2, Length(lText) - 2);
  end;

  aOperand := ExpandProperties(lText, aFileName, aProperties, aDiagnostics);
  Result := True;
end;

function TryEvaluateConditionFunction(const aCondition, aFileName, aBaseDirectory: string;
  const aProperties: TPropertyMap; const aDiagnostics: TList<TDelphiSemanticDiagnostic>;
  out aActive: Boolean;
  const aObservations: IProjectContextObservationsBuilder = nil): Boolean;
var
  lArgument: string;
  lFunctionName: string;
  lMatch: TMatch;
  lNegated: Boolean;
  lPath: string;
  lText: string;
begin
  lText := StripOuterParentheses(aCondition);
  lNegated := StartsText('!', lText);
  if lNegated then
    lText := Copy(lText, 2, MaxInt).Trim;

  lMatch := TRegEx.Match(lText, '^(Exists|HasTrailingSlash)\((.*)\)$',
    [roIgnoreCase, roSingleLine]);
  if not lMatch.Success then
    Exit(False);

  lFunctionName := lMatch.Groups[1].Value;
  if not TryGetConditionOperand(lMatch.Groups[2].Value, aFileName, aProperties, aDiagnostics,
    lArgument) then
    Exit(False);

  if SameText(lFunctionName, 'Exists') then
  begin
    if lArgument.Trim = '' then
      aActive := False
    else
    begin
      if TPath.IsPathRooted(lArgument) then
        lPath := TPath.GetFullPath(lArgument)
      else
        lPath := NormalizeProjectPath(aBaseDirectory, lArgument);
      aActive := TFile.Exists(lPath) or TDirectory.Exists(lPath);
      if aObservations <> nil then
        aObservations.AddPresence(lPath, 'exists-condition', aActive);
    end;
  end else
    aActive := EndsText('\', lArgument) or EndsText('/', lArgument);

  if lNegated then
    aActive := not aActive;

  Result := True;
end;

function TryEvaluateConditionClause(const aCondition, aFileName, aBaseDirectory: string;
  const aProperties: TPropertyMap; const aDiagnostics: TList<TDelphiSemanticDiagnostic>;
  out aActive: Boolean;
  const aObservations: IProjectContextObservationsBuilder = nil): Boolean;
var
  lActualValue: string;
  lExpectedValue: string;
  lMatch: TMatch;
  lOperator: string;
  lText: string;
begin
  lText := StripOuterParentheses(aCondition);

  if TryEvaluateConditionFunction(lText, aFileName, aBaseDirectory, aProperties,
    aDiagnostics, aActive, aObservations) then
    Exit(True);

  lMatch := TRegEx.Match(lText, '^(.+?)\s*(==|!=)\s*(.+)$', [roIgnoreCase, roSingleLine]);
  if not lMatch.Success then
    Exit(False);

  if not TryGetConditionOperand(lMatch.Groups[1].Value, aFileName, aProperties,
    aDiagnostics, lActualValue) then
    Exit(False);
  if not TryGetConditionOperand(lMatch.Groups[3].Value, aFileName, aProperties,
    aDiagnostics, lExpectedValue) then
    Exit(False);

  lOperator := lMatch.Groups[2].Value;
  if lOperator = '==' then
    aActive := SameText(lActualValue, lExpectedValue)
  else
    aActive := not SameText(lActualValue, lExpectedValue);

  Result := True;
end;

function IsConditionOperatorBoundary(const aText: string; const aIndex: Integer): Boolean;
begin
  Result := (aIndex < 1) or (aIndex > Length(aText)) or
    not CharInSet(aText[aIndex], ['A'..'Z', 'a'..'z', '0'..'9', '_']);
end;

function IsConditionOperatorAt(const aText: string; const aIndex: Integer;
  const aOperator: string): Boolean;
var
  lOperatorLength: Integer;
begin
  lOperatorLength := Length(aOperator);
  if (aIndex < 1) or (aIndex + lOperatorLength - 1 > Length(aText)) then
    Exit(False);

  Result := SameText(Copy(aText, aIndex, lOperatorLength), aOperator) and
    IsConditionOperatorBoundary(aText, aIndex - 1) and
    IsConditionOperatorBoundary(aText, aIndex + lOperatorLength);
end;

function TrySplitTopLevelCondition(const aText, aOperator: string;
  out aLeft, aRight: string): Boolean;
var
  i: Integer;
  lDepth: Integer;
  lInQuote: Boolean;
begin
  lDepth := 0;
  lInQuote := False;
  i := 1;
  while i <= Length(aText) do
  begin
    if aText[i] = '''' then
      lInQuote := not lInQuote
    else if not lInQuote then
    begin
      if aText[i] = '(' then
        Inc(lDepth)
      else if aText[i] = ')' then
        Dec(lDepth)
      else if (lDepth = 0) and IsConditionOperatorAt(aText, i, aOperator) then
      begin
        aLeft := Copy(aText, 1, i - 1).Trim;
        aRight := Copy(aText, i + Length(aOperator), MaxInt).Trim;
        Exit((aLeft <> '') and (aRight <> ''));
      end;
    end;
    Inc(i);
  end;

  Result := False;
end;

function TryEvaluateConditionExpression(const aCondition, aFileName, aBaseDirectory: string;
  const aProperties: TPropertyMap; const aDiagnostics: TList<TDelphiSemanticDiagnostic>;
  out aActive: Boolean;
  const aObservations: IProjectContextObservationsBuilder = nil): Boolean;
var
  lLeft: string;
  lLeftActive: Boolean;
  lRight: string;
  lRightActive: Boolean;
  lText: string;
begin
  lText := StripOuterParentheses(aCondition);

  if SameText(lText, 'true') then
  begin
    aActive := True;
    Exit(True);
  end;

  if SameText(lText, 'false') then
  begin
    aActive := False;
    Exit(True);
  end;

  if TrySplitTopLevelCondition(lText, 'or', lLeft, lRight) then
  begin
    if not TryEvaluateConditionExpression(lLeft, aFileName, aBaseDirectory, aProperties,
      aDiagnostics, lLeftActive, aObservations) then
      Exit(False);

    if lLeftActive then
    begin
      aActive := True;
      Exit(True);
    end;

    if not TryEvaluateConditionExpression(lRight, aFileName, aBaseDirectory, aProperties,
      aDiagnostics, lRightActive, aObservations) then
      Exit(False);

    aActive := lRightActive;
    Exit(True);
  end;

  if TrySplitTopLevelCondition(lText, 'and', lLeft, lRight) then
  begin
    if not TryEvaluateConditionExpression(lLeft, aFileName, aBaseDirectory, aProperties,
      aDiagnostics, lLeftActive, aObservations) then
      Exit(False);

    if not lLeftActive then
    begin
      aActive := False;
      Exit(True);
    end;

    if not TryEvaluateConditionExpression(lRight, aFileName, aBaseDirectory, aProperties,
      aDiagnostics, lRightActive, aObservations) then
      Exit(False);

    aActive := lRightActive;
    Exit(True);
  end;

  if StartsText('!', lText) and (not StartsText('!=', lText)) then
  begin
    if not TryEvaluateConditionExpression(Copy(lText, 2, MaxInt), aFileName, aBaseDirectory,
      aProperties, aDiagnostics, aActive, aObservations) then
      Exit(False);
    aActive := not aActive;
    Exit(True);
  end;

  Result := TryEvaluateConditionClause(lText, aFileName, aBaseDirectory, aProperties,
    aDiagnostics, aActive, aObservations);
end;

function StripOuterParentheses(const aValue: string): string;
var
  i: Integer;
  lDepth: Integer;
  lText: string;
begin
  lText := aValue.Trim;
  while (Length(lText) >= 2) and (lText[1] = '(') and (lText[Length(lText)] = ')') do
  begin
    lDepth := 0;
    for i := 1 to Length(lText) do
    begin
      if lText[i] = '(' then
        Inc(lDepth)
      else if lText[i] = ')' then
      begin
        Dec(lDepth);
        if (lDepth = 0) and (i < Length(lText)) then
        begin
          Result := lText;
          Exit;
        end;
      end;
    end;
    lText := Copy(lText, 2, Length(lText) - 2).Trim;
  end;
  Result := lText;
end;

function IsConditionActive(const aCondition, aFileName, aBaseDirectory: string;
  const aProperties: TPropertyMap; const aDiagnostics: TList<TDelphiSemanticDiagnostic>;
  const aObservations: IProjectContextObservationsBuilder = nil): Boolean;
var
  lActive: Boolean;
begin
  if aCondition.Trim = '' then
    Exit(True);

  if not TryEvaluateConditionExpression(aCondition, aFileName, aBaseDirectory, aProperties,
    aDiagnostics, lActive, aObservations) then
  begin
    if aObservations <> nil then
      aObservations.MarkDefineEvidenceIncomplete;
    AddDiagnostic(aDiagnostics, CreateWarningDiagnostic('INVALID_MSBUILD_CONDITION',
      'Unsupported or invalid Condition: ' + aCondition, aFileName));
    Exit(False);
  end;

  Result := lActive;
end;

function HasDiagnosticCode(const aDiagnostics: TList<TDelphiSemanticDiagnostic>;
  const aCode: string): Boolean;
var
  lDiagnostic: TDelphiSemanticDiagnostic;
begin
  for lDiagnostic in aDiagnostics do
    if SameText(lDiagnostic.Code, aCode) then
      Exit(True);

  Result := False;
end;

function HasDiagnosticCodeSince(const aDiagnostics: TList<TDelphiSemanticDiagnostic>;
  const aStartIndex: Integer; const aCode: string): Boolean;
var
  i: Integer;
begin
  for i := aStartIndex to aDiagnostics.Count - 1 do
    if SameText(aDiagnostics[i].Code, aCode) then
      Exit(True);

  Result := False;
end;

function IsConditionActiveForNonSemanticProperty(const aCondition, aFileName,
  aBaseDirectory: string; const aProperties: TPropertyMap;
  const aDiagnostics: TList<TDelphiSemanticDiagnostic>;
  const aObservations: IProjectContextObservationsBuilder;
  out aHasUnresolvedMacro: Boolean): Boolean;
var
  lConditionDiagnostics: TList<TDelphiSemanticDiagnostic>;
  lDiagnostic: TDelphiSemanticDiagnostic;
begin
  lConditionDiagnostics := TList<TDelphiSemanticDiagnostic>.Create;
  try
    Result := IsConditionActive(aCondition, aFileName, aBaseDirectory, aProperties,
      lConditionDiagnostics, aObservations);
    aHasUnresolvedMacro := HasDiagnosticCode(lConditionDiagnostics,
      'UNRESOLVED_MSBUILD_MACRO');
    for lDiagnostic in lConditionDiagnostics do
      if not SameText(lDiagnostic.Code, 'UNRESOLVED_MSBUILD_MACRO') then
        AddDiagnostic(aDiagnostics, lDiagnostic);
  finally
    lConditionDiagnostics.Free;
  end;
end;

function HasUnresolvedPropertyReference(const aValue: string; const aProperties: TPropertyMap): Boolean;
var
  lMacroName: string;
  lMacroStart: Integer;
  lMacroStop: Integer;
  lMacroValue: string;
begin
  lMacroStart := Pos('$(', aValue);
  while lMacroStart > 0 do
  begin
    lMacroStop := PosEx(')', aValue, lMacroStart + 2);
    if lMacroStop = 0 then
      Break;

    lMacroName := Copy(aValue, lMacroStart + 2, lMacroStop - lMacroStart - 2);
    if not TryGetPropertyValue(aProperties, lMacroName, lMacroValue) then
      Exit(True);

    lMacroStart := PosEx('$(', aValue, lMacroStop + 1);
  end;

  Result := False;
end;

function ExpandProperties(const aValue, aFileName: string; const aProperties: TPropertyMap;
  const aDiagnostics: TList<TDelphiSemanticDiagnostic>): string;
var
  lMacroName: string;
  lMacroStart: Integer;
  lMacroStop: Integer;
  lReplacement: string;
begin
  Result := aValue;
  lMacroStart := Pos('$(', Result);
  while lMacroStart > 0 do
  begin
    lMacroStop := PosEx(')', Result, lMacroStart + 2);
    if lMacroStop = 0 then
      Break;

    lMacroName := Copy(Result, lMacroStart + 2, lMacroStop - lMacroStart - 2);
    if not TryGetPropertyValue(aProperties, lMacroName, lReplacement) then
    begin
      AddDiagnostic(aDiagnostics, CreateWarningDiagnostic('UNRESOLVED_MSBUILD_MACRO',
        'Unresolved MSBuild macro: $(' + lMacroName + ')', aFileName));
      Delete(Result, lMacroStart, lMacroStop - lMacroStart + 1);
      lMacroStart := PosEx('$(', Result, lMacroStart);
    end else
    begin
      Delete(Result, lMacroStart, lMacroStop - lMacroStart + 1);
      Insert(lReplacement, Result, lMacroStart);
      lMacroStart := PosEx('$(', Result, lMacroStart + Length(lReplacement));
    end;
  end;
end;

function ExpandSemanticProjectProperty(const aValue, aFileName: string;
  const aProperties: TPropertyMap;
  const aDiagnostics: TList<TDelphiSemanticDiagnostic>): string;
const
  cMaximumExpansionPasses = 64;
var
  lExpansionPass: Integer;
  lMacroName: string;
  lMacroStart: Integer;
  lMacroStop: Integer;
  lPreviousValue: string;
begin
  Result := aValue;
  lExpansionPass := 0;
  while lExpansionPass < cMaximumExpansionPasses do
  begin
    lPreviousValue := Result;
    Result := ExpandProperties(Result, aFileName, aProperties, aDiagnostics);
    lMacroStart := Pos('$(', Result);
    if lMacroStart = 0 then
      Exit;

    if Result = lPreviousValue then
    begin
      lMacroStop := PosEx(')', Result, lMacroStart + 2);
      if lMacroStop = 0 then
        lMacroName := Copy(Result, lMacroStart + 2,
          Length(Result) - lMacroStart - 1)
      else
        lMacroName := Copy(Result, lMacroStart + 2,
          lMacroStop - lMacroStart - 2);
      AddDiagnostic(aDiagnostics, CreateWarningDiagnostic('UNRESOLVED_MSBUILD_MACRO',
        'Unresolved or cyclic MSBuild macro: $(' + lMacroName + ')', aFileName));
      Exit;
    end;
    Inc(lExpansionPass);
  end;

  lMacroStart := Pos('$(', Result);
  if lMacroStart > 0 then
  begin
    lMacroStop := PosEx(')', Result, lMacroStart + 2);
    if lMacroStop = 0 then
      lMacroName := Copy(Result, lMacroStart + 2, Length(Result) - lMacroStart - 1)
    else
      lMacroName := Copy(Result, lMacroStart + 2,
        lMacroStop - lMacroStart - 2);
    AddDiagnostic(aDiagnostics, CreateWarningDiagnostic('UNRESOLVED_MSBUILD_MACRO',
      'MSBuild macro expansion exceeded the safe limit at $(' + lMacroName + ')',
      aFileName));
  end;
end;

function ExpandPropertiesPreservingUnresolved(const aValue, aPropertyName: string;
  const aProperties: TPropertyMap): string;
var
  lMacroName: string;
  lMacroStart: Integer;
  lMacroStop: Integer;
  lReplacement: string;
begin
  Result := aValue;
  lMacroStart := Pos('$(', Result);
  while lMacroStart > 0 do
  begin
    lMacroStop := PosEx(')', Result, lMacroStart + 2);
    if lMacroStop = 0 then
      Break;

    lMacroName := Copy(Result, lMacroStart + 2, lMacroStop - lMacroStart - 2);
    if not TryGetPropertyValue(aProperties, lMacroName, lReplacement) then
    begin
      if SameText(lMacroName, aPropertyName) then
      begin
        Delete(Result, lMacroStart, lMacroStop - lMacroStart + 1);
        lMacroStart := PosEx('$(', Result, lMacroStart);
      end else
        lMacroStart := PosEx('$(', Result, lMacroStop + 1);
    end
    else
    begin
      Delete(Result, lMacroStart, lMacroStop - lMacroStart + 1);
      Insert(lReplacement, Result, lMacroStart);
      lMacroStart := PosEx('$(', Result, lMacroStart + Length(lReplacement));
    end;
  end;
end;

procedure AddUniqueText(const aItems: TList<string>; const aValue: string);
var
  lItem: string;
  lValue: string;
begin
  lValue := aValue.Trim;
  if lValue = '' then
    Exit;

  for lItem in aItems do
    if SameText(lItem, lValue) then
      Exit;

  aItems.Add(lValue);
end;

procedure AddUniquePath(const aItems: TList<string>; const aBaseDirectory, aValue: string);
var
  lItem: string;
  lPath: string;
  lValue, lError: string;
begin
  lValue := aValue.Trim;
  if not TryResolveCompilerSearchPathEntry(aBaseDirectory, lValue, lPath, lError) then
    raise ECompilerSearchPathError.Create(lError);
  if lPath = '' then
    Exit;
  lPath := ExcludeTrailingPathDelimiter(lPath);
  for lItem in aItems do
    if SameText(lItem, lPath) then
      Exit;

  aItems.Add(lPath);
end;

procedure AddDelimitedTexts(const aItems: TList<string>; const aValue: string);
var
  lPart: string;
  lParts: TArray<string>;
begin
  lParts := aValue.Split([';']);
  for lPart in lParts do
    AddUniqueText(aItems, lPart);
end;

function IsSemanticProjectProperty(const aName: string): Boolean;
begin
  Result := SameText(aName, 'MainSource') or SameText(aName, 'Config') or
    SameText(aName, 'Platform') or SameText(aName, 'DCC_Define') or
    SameText(aName, 'DCC_IncludePath') or SameText(aName, 'DCC_UnitSearchPath') or
    SameText(aName, 'DCC_UnitScopeNames') or SameText(aName, 'DCC_Namespace') or
    SameText(aName, 'DCC_UnitAlias') or SameText(aName, 'DCC_UnitAliases') or
    SameText(aName, 'CfgDependentOn') or MatchText(aName, cDelphiSemanticCompilerLinkPropertyNames);
end;

function PropertyGroupContainsSemanticProjectProperty(const aNode: IXMLNode): Boolean;
var
  i: Integer;
  lChild: IXMLNode;
begin
  for i := 0 to aNode.ChildNodes.Count - 1 do
  begin
    lChild := aNode.ChildNodes[i];
    if IsXmlElement(lChild) and IsSemanticProjectProperty(XmlNodeName(lChild)) then
      Exit(True);
  end;

  Result := False;
end;

procedure InvalidateNonSemanticProperty(const aProperties: TPropertyMap; const aName: string);
begin
  // A discarded conditional value is unknown, unlike an optional input that
  // was never supplied. Do not let default seeding turn that uncertainty empty.
  if MatchText(aName, cOptionalCompilerIncludeProperties) then
    SetPropertyValue(aProperties, 'DSCompilerIncludeUnknown.' + aName, 'True');
  aProperties.Remove(PropertyKey(aName));
end;

procedure RemoveNonSemanticPropertyGroupValues(const aNode: IXMLNode;
  const aProperties: TPropertyMap);
var
  i: Integer;
  lChild: IXMLNode;
begin
  for i := 0 to aNode.ChildNodes.Count - 1 do
  begin
    lChild := aNode.ChildNodes[i];
    if IsXmlElement(lChild) and not IsSemanticProjectProperty(XmlNodeName(lChild)) then
      InvalidateNonSemanticProperty(aProperties, XmlNodeName(lChild));
  end;
end;

procedure AddDelimitedPaths(const aItems: TList<string>; const aBaseDirectory, aValue: string);
var
  lPart: string;
  lParts: TArray<string>;
begin
  lParts := aValue.Split([';']);
  for lPart in lParts do
    AddUniquePath(aItems, aBaseDirectory, lPart);
end;

function TDelphiSemanticProjectInfo.SourceLookupPaths: TArray<string>;
var
  lItem: string;
  lItems: TList<string>;
begin
  lItems := TList<string>.Create;
  try
    for lItem in ReferenceDirectories do
      AddUniquePath(lItems, ProjectDirectory, lItem);
    for lItem in SearchPaths do
      AddUniquePath(lItems, ProjectDirectory, lItem);
    Result := lItems.ToArray;
  finally
    lItems.Free;
  end;
end;

procedure ApplyPropertyFile(const aFileName, aBaseDirectory: string; const aProperties: TPropertyMap;
  const aDiagnostics: TList<TDelphiSemanticDiagnostic>; const aLockPlatform: Boolean;
  const aObservations: IProjectContextObservationsBuilder = nil); forward;

function BoundedDefineImport(const aProject, aCondition: string): Boolean;
begin
  Result := (SameText(aProject, '$(BDS)\Bin\CodeGear.Delphi.Targets') or
    SameText(aProject, '$(APPDATA)\Embarcadero\$(BDSAPPDATABASEDIR)\$(PRODUCTVERSION)\UserTools.proj')) and
    SameText(aCondition.Trim, 'Exists(''' + aProject + ''')');
end;

function OnlyUnresolvedSelfReference(const aDiagnostics: TList<TDelphiSemanticDiagnostic>;
  const aFirst: Integer; const aPropertyName: string): Boolean;
begin
  Result := True;
  for var i := aFirst to aDiagnostics.Count - 1 do
    if SameText(aDiagnostics[i].Code, 'UNRESOLVED_MSBUILD_MACRO') and
      not SameText(aDiagnostics[i].Message, 'Unresolved MSBuild macro: $(' + aPropertyName + ')') then
      Exit(False);
end;

procedure ApplyImport(const aNode: IXMLNode; const aFileName, aBaseDirectory: string;
  const aProperties: TPropertyMap; const aDiagnostics: TList<TDelphiSemanticDiagnostic>;
  const aLockPlatform: Boolean; const aObservations: IProjectContextObservationsBuilder);
var
  lCondition: string;
  lImportFileName: string;
  lProject: string;
  lDiagnosticCount: Integer;
  lBounded, lActive: Boolean;
begin
  lDiagnosticCount := aDiagnostics.Count;
  lCondition := XmlNodeAttributeValue(aNode, 'Condition');
  lBounded := BoundedDefineImport(XmlNodeAttributeValue(aNode, 'Project'), lCondition);
  if lBounded and (aObservations <> nil) then
    aObservations.MarkBoundedDefineImportPending;
  // The same evaluator and diagnostics still decide whether we apply the
  // import. Only the bounded proof owns incompleteness for these two imports.
  if lBounded then
    lActive := IsConditionActive(lCondition, aFileName, aBaseDirectory, aProperties, aDiagnostics)
  else
    lActive := IsConditionActive(lCondition, aFileName, aBaseDirectory, aProperties, aDiagnostics,
      aObservations);
  if lActive then
  begin
    lProject := XmlNodeAttributeValue(aNode, 'Project');
    lProject := ExpandProperties(lProject, aFileName, aProperties, aDiagnostics);
    if lProject <> '' then
    begin
      lImportFileName := NormalizeProjectPath(aBaseDirectory, lProject);
      ApplyPropertyFile(lImportFileName, ExtractFilePath(lImportFileName), aProperties,
        aDiagnostics, aLockPlatform, aObservations);
      if SameText(TPath.GetFileName(lImportFileName), 'CodeGear.Delphi.Targets') and
        TFile.Exists(lImportFileName) then
        SetPropertyValue(aProperties, 'DSCompilerTargetsEvaluated', 'True');
    end else if (aObservations <> nil) and not lBounded then
      aObservations.MarkDefineEvidenceIncomplete;
  end;
  if (aObservations <> nil) and not lBounded and HasDiagnosticCodeSince(aDiagnostics, lDiagnosticCount,
    'UNRESOLVED_MSBUILD_MACRO') then
    aObservations.MarkDefineEvidenceIncomplete;
end;

procedure ApplyPropertyGroup(const aNode: IXMLNode; const aFileName, aBaseDirectory: string;
  const aProperties: TPropertyMap; const aDiagnostics: TList<TDelphiSemanticDiagnostic>;
  const aLockPlatform: Boolean; const aObservations: IProjectContextObservationsBuilder);
var
  i: Integer;
  lChild: IXMLNode;
  lConditionActive: Boolean;
  lConditionIsUnknown: Boolean;
  lCondition: string;
  lDiagnosticCount: Integer;
  lExpandedValue: string;
  lGroupHasSemanticProperty, lGroupHasDefineProperty: Boolean;
  lName: string;
  lOptsetPath: string;
  lPart: string;
  lParts: TArray<string>;
  lValue: string;
begin
  lCondition := XmlNodeAttributeValue(aNode, 'Condition');
  lGroupHasSemanticProperty := PropertyGroupContainsSemanticProjectProperty(aNode);
  lGroupHasDefineProperty := False;
  for i := 0 to aNode.ChildNodes.Count - 1 do
    if MatchText(XmlNodeName(aNode.ChildNodes[i]),
      ['DCC_Define', 'DCC_AdditionalSwitches', 'CfgDependentOn']) then
      lGroupHasDefineProperty := True;
  if lGroupHasSemanticProperty then
  begin
    lDiagnosticCount := aDiagnostics.Count;
    lConditionActive := IsConditionActive(lCondition, aFileName, aBaseDirectory,
      aProperties, aDiagnostics, aObservations);
    lConditionIsUnknown := HasDiagnosticCodeSince(aDiagnostics, lDiagnosticCount,
      'UNRESOLVED_MSBUILD_MACRO');
  end else
    lConditionActive := IsConditionActiveForNonSemanticProperty(lCondition, aFileName,
      aBaseDirectory, aProperties, aDiagnostics, aObservations, lConditionIsUnknown);

  if lConditionIsUnknown then
  begin
    if lGroupHasDefineProperty and (aObservations <> nil) then
      aObservations.MarkDefineEvidenceIncomplete;
    RemoveNonSemanticPropertyGroupValues(aNode, aProperties);
    Exit;
  end;
  if lConditionActive then
  begin
    for i := 0 to aNode.ChildNodes.Count - 1 do
    begin
      lChild := aNode.ChildNodes[i];
      if not IsXmlElement(lChild) then
        Continue;

      lName := XmlNodeName(lChild);
      lCondition := XmlNodeAttributeValue(lChild, 'Condition');
      if IsSemanticProjectProperty(lName) then
      begin
        lDiagnosticCount := aDiagnostics.Count;
        lConditionActive := IsConditionActive(lCondition, aFileName, aBaseDirectory,
          aProperties, aDiagnostics, aObservations);
        lConditionIsUnknown := HasDiagnosticCodeSince(aDiagnostics, lDiagnosticCount,
          'UNRESOLVED_MSBUILD_MACRO');
      end else
        lConditionActive := IsConditionActiveForNonSemanticProperty(lCondition, aFileName,
          aBaseDirectory, aProperties, aDiagnostics, aObservations, lConditionIsUnknown);

      if lConditionIsUnknown then
      begin
        if (aObservations <> nil) and MatchText(lName,
          ['DCC_Define', 'DCC_AdditionalSwitches', 'CfgDependentOn']) then
          aObservations.MarkDefineEvidenceIncomplete;
        if not IsSemanticProjectProperty(lName) then
          InvalidateNonSemanticProperty(aProperties, lName);
        Continue;
      end;
      if lConditionActive then
      begin
        lDiagnosticCount := aDiagnostics.Count;
        lValue := lChild.Text.Trim;
        if IsSemanticProjectProperty(lName) then
          lExpandedValue := ExpandSemanticProjectProperty(lValue, aFileName, aProperties,
            aDiagnostics)
        else
          lExpandedValue := ExpandPropertiesPreservingUnresolved(lValue, lName,
            aProperties);
        if (aObservations <> nil) and MatchText(lName,
          ['DCC_Define', 'DCC_AdditionalSwitches', 'CfgDependentOn']) and
          (Pos('$(', lValue) > 0) and HasDiagnosticCodeSince(aDiagnostics,
            lDiagnosticCount, 'UNRESOLVED_MSBUILD_MACRO') and
          not OnlyUnresolvedSelfReference(aDiagnostics, lDiagnosticCount, lName) then
          aObservations.MarkDefineEvidenceIncomplete;
        if SameText(lName, 'CfgDependentOn') then
        begin
          lParts := lExpandedValue.Split([';']);
          for lPart in lParts do
          begin
            if lPart.Trim = '' then
              Continue;

            lOptsetPath := NormalizeProjectPath(aBaseDirectory, lPart.Trim);
            ApplyPropertyFile(lOptsetPath, ExtractFilePath(lOptsetPath), aProperties,
              aDiagnostics, aLockPlatform, aObservations);
          end;
        end;
        if (not aLockPlatform) or (not SameText(lName, 'Platform')) then
        begin
          SetPropertyValue(aProperties, lName, lExpandedValue);
          aProperties.Remove(PropertyKey('DSCompilerIncludeUnknown.' + lName));
          if SameText(lName, 'BDSUSERDIR') or SameText(lName, 'BDSCOMMONDIR') then
            SetPropertyValue(aProperties, lName + 'Source', 'project property');
        end;
      end;
    end;
  end;
end;

// We evaluate only root property groups and direct imports. Unhandled MSBuild
// execution/containers are not evidence of define absence (DS-719 section 0.9).
function ProjectDefineImpactClosed(const aNode: IXMLNode): Boolean;
begin
  Result := True;
  if not IsXmlElement(aNode) then
    Exit;
  if MatchText(XmlNodeName(aNode), ['Target', 'Choose', 'When', 'Otherwise',
    'ImportGroup', 'UsingTask']) then
    Exit(False);
  // An output is a property writer even without a DCC_Define XML element.
  if XmlNodeAttributeValue(aNode, 'PropertyName') <> '' then
    Exit(False);
  if IsXmlElementNamed(aNode, 'ProjectExtensions') then
    Exit; // IDE metadata, not an evaluated MSBuild container.
  for var i := 0 to aNode.ChildNodes.Count - 1 do
    if not ProjectDefineImpactClosed(aNode.ChildNodes[i]) then
      Exit(False);
end;

procedure ApplyPropertyDocument(const aDocument: IXMLDocument; const aFileName,
  aBaseDirectory: string;
  const aProperties: TPropertyMap; const aDiagnostics: TList<TDelphiSemanticDiagnostic>;
  const aLockPlatform: Boolean; const aObservations: IProjectContextObservationsBuilder);
var
  i: Integer;
  lNode: IXMLNode;
  lRoot: IXMLNode;
begin
  if not Assigned(aDocument) then
    Exit;

  lRoot := aDocument.DocumentElement;
  if not Assigned(lRoot) then
    Exit;

  if (aObservations <> nil) and not ProjectDefineImpactClosed(lRoot) then
    aObservations.MarkDefineEvidenceIncomplete;
  for i := 0 to lRoot.ChildNodes.Count - 1 do
  begin
    lNode := lRoot.ChildNodes[i];
    if IsXmlElementNamed(lNode, 'PropertyGroup') then
      ApplyPropertyGroup(lNode, aFileName, aBaseDirectory, aProperties, aDiagnostics,
        aLockPlatform, aObservations)
    else if IsXmlElementNamed(lNode, 'Import') then
      ApplyImport(lNode, aFileName, aBaseDirectory, aProperties, aDiagnostics, aLockPlatform,
        aObservations);
  end;
end;

procedure ApplyPropertyFile(const aFileName, aBaseDirectory: string; const aProperties: TPropertyMap;
  const aDiagnostics: TList<TDelphiSemanticDiagnostic>; const aLockPlatform: Boolean;
  const aObservations: IProjectContextObservationsBuilder);
var
  lDocument: IXMLDocument;
  lText: string;
begin
  if not TFile.Exists(aFileName) then
  begin
    if aObservations <> nil then
    begin
      aObservations.AddPresence(aFileName, 'property-file', False);
      aObservations.MarkDefineEvidenceIncomplete;
    end;
    AddDiagnostic(aDiagnostics, CreateWarningDiagnostic('OPTSET_FILE_NOT_FOUND',
      'Optset file not found: ' + aFileName, aFileName));
    Exit;
  end;

  ReadProjectContextInput(aFileName, 'property-file', aObservations, lText);
  lDocument := LoadProjectXml(lText);
  if (lDocument = nil) or (lDocument.DocumentElement = nil) then
    raise Exception.Create('Property file has no document element: ' + aFileName);
  ApplyPropertyDocument(lDocument, aFileName, aBaseDirectory, aProperties, aDiagnostics,
    aLockPlatform, aObservations);
end;

function TryResolveDccReferenceDirectory(const aProjectDirectory, aInclude: string;
  const aSearchPaths: TList<string>; out aDirectory: string;
  const aObservations: IProjectContextObservationsBuilder = nil): Boolean;
var
  lCandidate: string;
  lFileName: string;
  lIncludeFileName: string;
  lSearchPath: string;
  lExists: Boolean;
begin
  aDirectory := '';
  if aInclude.Trim = '' then
    Exit(False);

  try
    lIncludeFileName := NormalizeProjectPath(aProjectDirectory, aInclude);
    lFileName := TPath.GetFileName(aInclude);
  except
    if aObservations <> nil then
      aObservations.MarkIncomplete;
    Exit(False);
  end;

  lExists := TFile.Exists(lIncludeFileName);
  if aObservations <> nil then
    aObservations.AddSearchCandidate(lIncludeFileName, 'dcc-reference-directory', lExists, lExists);
  if lExists then
  begin
    aDirectory := ExtractFilePath(lIncludeFileName);
    Exit(True);
  end;

  if lFileName <> '' then
  begin
    for lSearchPath in aSearchPaths do
    begin
      lCandidate := TPath.Combine(lSearchPath, lFileName);
      lExists := TFile.Exists(lCandidate);
      if aObservations <> nil then
        aObservations.AddSearchCandidate(lCandidate, 'dcc-reference-directory', lExists, lExists);
      if lExists then
      begin
        aDirectory := lSearchPath;
        Exit(True);
      end;
    end;
  end;

  aDirectory := ExtractFilePath(aInclude);
  Result := aDirectory <> '';
end;

function TryResolveDccReferenceFileName(const aProjectDirectory, aInclude: string;
  const aSearchPaths: TList<string>; out aFileName: string;
  const aObservations: IProjectContextObservationsBuilder = nil): Boolean;
var
  lCandidate: string;
  lIncludeFileName: string;
  lSearchPath: string;
  lExists: Boolean;
begin
  aFileName := '';
  if aInclude.Trim = '' then
    Exit(False);

  try
    lIncludeFileName := NormalizeProjectPath(aProjectDirectory, aInclude);
  except
    if aObservations <> nil then
      aObservations.MarkIncomplete;
    Exit(False);
  end;

  lExists := TFile.Exists(lIncludeFileName);
  if aObservations <> nil then
    aObservations.AddSearchCandidate(lIncludeFileName, 'dcc-reference-file', lExists, lExists);
  if lExists then
  begin
    aFileName := lIncludeFileName;
    Exit(True);
  end;

  for lSearchPath in aSearchPaths do
  begin
    lCandidate := TPath.Combine(lSearchPath, TPath.GetFileName(aInclude));
    lExists := TFile.Exists(lCandidate);
    if aObservations <> nil then
      aObservations.AddSearchCandidate(lCandidate, 'dcc-reference-file', lExists, lExists);
    if lExists then
    begin
      aFileName := TPath.GetFullPath(lCandidate);
      Exit(True);
    end;
  end;

  Result := False;
end;

procedure AddReferenceDirectories(const aDocument: IXMLDocument; const aProjectFileName,
  aProjectDirectory: string;
  const aProperties: TPropertyMap; const aDiagnostics: TList<TDelphiSemanticDiagnostic>;
  const aSearchPaths, aItems, aSourceFiles: TList<string>;
  const aObservations: IProjectContextObservationsBuilder);
var
  i: Integer;
  j: Integer;
  lCondition: string;
  lDirectory: string;
  lFileName: string;
  lGroup: IXMLNode;
  lInclude: string;
  lReference: IXMLNode;
  lRoot: IXMLNode;
begin
  if not Assigned(aDocument) then
    Exit;

  lRoot := aDocument.DocumentElement;
  if not Assigned(lRoot) then
    Exit;

  for i := 0 to lRoot.ChildNodes.Count - 1 do
  begin
    lGroup := lRoot.ChildNodes[i];
    if not IsXmlElementNamed(lGroup, 'ItemGroup') then
      Continue;

    lCondition := XmlNodeAttributeValue(lGroup, 'Condition');
    if IsConditionActive(lCondition, aProjectFileName, aProjectDirectory, aProperties,
      aDiagnostics, aObservations) then
    begin
      for j := 0 to lGroup.ChildNodes.Count - 1 do
      begin
        lReference := lGroup.ChildNodes[j];
        if not IsXmlElementNamed(lReference, 'DCCReference') then
          Continue;

        lCondition := XmlNodeAttributeValue(lReference, 'Condition');
        if IsConditionActive(lCondition, aProjectFileName, aProjectDirectory, aProperties,
          aDiagnostics, aObservations) then
        begin
          lInclude := XmlNodeAttributeValue(lReference, 'Include');
          if HasUnresolvedPropertyReference(lInclude, aProperties) then
          begin
            ExpandProperties(lInclude, aProjectFileName, aProperties, aDiagnostics);
            Continue;
          end;

          lInclude := ExpandProperties(lInclude, aProjectFileName, aProperties, aDiagnostics);
          if TryResolveDccReferenceFileName(aProjectDirectory, lInclude, aSearchPaths,
            lFileName, aObservations) then
            AddUniquePath(aSourceFiles, aProjectDirectory, lFileName);
          if not TryResolveDccReferenceDirectory(aProjectDirectory, lInclude, aSearchPaths,
            lDirectory, aObservations) then
            AddUniquePath(aItems, aProjectDirectory, '.')
          else
            AddUniquePath(aItems, aProjectDirectory, lDirectory);
        end;
      end;
    end;
  end;
end;

// DS-719 section 0.8: validate a closed toolchain without evaluating its
// properties into the project. The only product result is the evidence bit.
function BoundedDefineNodeClosed(const aNode: IXMLNode; const aKind: Integer;
  const aVersion: string): Boolean;
var
  lName, lValue, lImport, lCondition, lOutput: string;
begin
  Result := True;
  if not IsXmlElement(aNode) then
    Exit;
  lName := XmlNodeName(aNode);
  lValue := '';
  if MatchText(lName, ['DCC_Define', 'DCC_AdditionalSwitches', 'ProductVersion',
    'BDSAppDataBaseDir', 'EnvironmentSettings', 'EnvOptions', 'Profiles', 'FrameworkType']) then
    lValue := aNode.Text.Trim;
  if MatchText(lName, ['DCC_Define', 'DCC_AdditionalSwitches']) then
  begin
    if aKind <> 0 then
      Exit(False);
    if SameText(lName, 'DCC_Define') then
      Exit(lValue = '$(DCC_Define);FRAMEWORK_$(FrameworkType)');
    Exit(MatchText(lValue, ['$(DCC_AdditionalSwitches) -JF:COFFI', '-JF:COFFI',
      '$(DCC_AdditionalSwitches) --sdk-version:$(Profile_version)', '--sdk-version:$(Profile_version)']));
  end;
  // Task outputs are also property writers. Dynamic output names are not proof.
  lOutput := XmlNodeAttributeValue(aNode, 'PropertyName');
  if (Pos('$(', lOutput) > 0) or MatchText(lOutput,
    ['DCC_Define', 'DCC_AdditionalSwitches', 'GlobalOptionFile', 'PlatformSDK',
    'DefaultPlatformSDK', 'EnvironmentSettings', 'EnvOptions', 'Profiles']) then
    Exit(False);
  if SameText(lName, 'ProductVersion') and
    not (((aKind = 1) or (aKind = 2)) and SameText(lValue, aVersion)) then
    Exit(False);
  if SameText(lName, 'BDSAppDataBaseDir') and not ((aKind = 1) and SameText(lValue, 'BDS')) then
    Exit(False);
  if SameText(lName, 'EnvironmentSettings') and not ((aKind = 1) and
    SameText(lValue, '$(APPDATA)\Embarcadero\$(BDSAppDataBaseDir)\$(ProductVersion)\environment.proj')) then
    Exit(False);
  if SameText(lName, 'EnvOptions') and not ((aKind = 1) and
    SameText(lValue, '$(APPDATA)\Embarcadero\$(BDSAppDataBaseDir)\$(ProductVersion)\EnvOptions.proj')) then
    Exit(False);
  if SameText(lName, 'Profiles') and not ((aKind = 1) and
    SameText(lValue, '$(BDS)\bin\CodeGear.Profiles.Targets')) then
    Exit(False);
  if SameText(lName, 'FrameworkType') and not MatchText(lValue, ['None', 'VCL', 'FMX']) then
    Exit(False);
  if SameText(lName, 'Import') then
  begin
    lImport := XmlNodeAttributeValue(aNode, 'Project');
    lCondition := TRegEx.Replace(XmlNodeAttributeValue(aNode, 'Condition'), '\s+', '');
    case aKind of
      0: Result := SameText(lImport, '$(BDS)\bin\CodeGear.Common.Targets') and (lCondition = '');
      1: Result :=
        (SameText(lImport, '$(EnvironmentSettings)') and SameText(lCondition, 'Exists(''$(EnvironmentSettings)'')')) or
        (SameText(lImport, '$(EnvOptions)') and
          SameText(lCondition, 'Exists(''$(EnvOptions)'')and(''$(ImportEnvOptions)''!=''false'')')) or
        (SameText(lImport, '$(Profiles)') and SameText(lCondition, 'Exists(''$(Profiles)'')')) or
        (SameText(lImport, '$(GlobalOptionFile)') and SameText(lCondition, 'Exists(''$(GlobalOptionFile)'')'));
      2: Result := SameText(lImport, '$(APPDATA)\Embarcadero\$(BDSAPPDATABASEDIR)\$(ProductVersion)\$(PlatformSDK)') and
        SameText(lCondition, '''$(PlatformSDK)''!=''''AndExists(''$(APPDATA)\Embarcadero\$(BDSAPPDATABASEDIR)\$(ProductVersion)\$(PlatformSDK)'')');
    else
      Result := False;
    end;
    Exit;
  end;
  for var i := 0 to aNode.ChildNodes.Count - 1 do
    if not BoundedDefineNodeClosed(aNode.ChildNodes[i], aKind, aVersion) then
      Exit(False);
end;

function BoundedDefineOptionsEmpty(const aDocument: IXMLDocument;
  const aProperties: TPropertyMap): Boolean;
var
  lDiagnostics: TList<TDelphiSemanticDiagnostic>;
  lGroup, lChild: IXMLNode;
  lActive: Boolean;
begin
  lDiagnostics := TList<TDelphiSemanticDiagnostic>.Create;
  try
    for var i := 0 to aDocument.DocumentElement.ChildNodes.Count - 1 do
    begin
      lGroup := aDocument.DocumentElement.ChildNodes[i];
      if not IsXmlElementNamed(lGroup, 'PropertyGroup') then
        Continue;
      for var j := 0 to lGroup.ChildNodes.Count - 1 do
      begin
        lChild := lGroup.ChildNodes[j];
        if not MatchText(XmlNodeName(lChild), ['GlobalOptionFile', 'PlatformSDK', 'DefaultPlatformSDK']) then
          Continue;
        lDiagnostics.Clear;
        lActive := IsConditionActive(XmlNodeAttributeValue(lGroup, 'Condition'), '', '',
          aProperties, lDiagnostics);
        if lDiagnostics.Count > 0 then
          Exit(False);
        if not lActive then
          Continue;
        lActive := IsConditionActive(XmlNodeAttributeValue(lChild, 'Condition'), '', '',
          aProperties, lDiagnostics);
        if lDiagnostics.Count > 0 then
          Exit(False);
        if lActive and (lChild.Text.Trim <> '') and
          not (SameText(XmlNodeName(lChild), 'PlatformSDK') and
            SameText(lChild.Text.Trim, '$(DefaultPlatformSDK)')) then
          Exit(False);
      end;
    end;
    Result := True;
  finally
    lDiagnostics.Free;
  end;
end;

function BoundedDefineToolchain(const aProperties: TPropertyMap;
  const aOptions: TDelphiSemanticOptions; const aObservations: IProjectContextObservationsBuilder;
  out aFailure: string): Boolean;
const
  cFiles: array[0..5] of string = ('CodeGear.Delphi.Targets', 'CodeGear.Common.Targets',
    'CodeGear.Profiles.Targets', 'environment.proj', 'EnvOptions.proj', 'UserTools.proj');
var
  lInputs: IDelphiSemanticProfileInputs;
  lDocuments: array[0..5] of IXMLDocument;
  lRoot, lAppData, lUser, lDatabase, lVersion, lFileName, lText, lValue: string;
begin
  Result := False;
  aFailure := 'missing-version';
  if aOptions.DelphiVersion.Trim = '' then
    Exit;
  lVersion := ProfileVersion(aOptions);
  lInputs := ProfileInputs(aOptions);
  aFailure := 'nonempty-option-or-redirect';
  for lValue in ['GlobalOptionFile', 'PlatformSDK', 'DefaultPlatformSDK'] do
  begin
    if GetPropertyValue(aProperties, lValue).Trim <> '' then
      Exit;
    if lInputs.TryEnvironmentValue(lValue, lText) and (lText.Trim <> '') then
      Exit;
  end;
  if not MatchText(GetPropertyValue(aProperties, 'FrameworkType'), ['None', 'VCL', 'FMX']) then
    Exit;
  lRoot := TDelphiSemanticCompilerProfileBuilder.ResolveBdsRoot(lVersion, aOptions.RsVarsPath);
  lAppData := GetPropertyValue(aProperties, 'APPDATA');
  if lAppData = '' then
    lInputs.TryEnvironmentValue('APPDATA', lAppData);
  aFailure := 'appdata-unavailable';
  if (lAppData = '') or (Pos('$(', lAppData) > 0) then
    Exit;
  lDatabase := GetPropertyValue(aProperties, 'BDSAPPDATABASEDIR');
  if lDatabase = '' then
    if not lInputs.TryEnvironmentValue('BDSAPPDATABASEDIR', lDatabase) then
      lDatabase := 'BDS';
  if (lDatabase = '') or (TPath.GetFileName(lDatabase) <> lDatabase) then
    Exit;
  lUser := CombinePath([lAppData, 'Embarcadero', lDatabase, lVersion]);
  for lValue in ['EnvironmentSettings', 'EnvOptions', 'Profiles', 'ProductVersion', 'BDS'] do
    if GetPropertyValue(aProperties, lValue) <> '' then
    begin
      // An override can change which files native MSBuild imports. Do not claim
      // closure through a different input just because the default file is safe.
      aFailure := 'redirected-input:' + lValue;
      Exit;
    end;
  for lValue in ['EnvironmentSettings', 'EnvOptions', 'Profiles', 'ProductVersion', 'BDS'] do
    if lInputs.TryEnvironmentValue(lValue, lText) and (lText <> '') and
      not (SameText(lValue, 'BDS') and SameText(ExcludeTrailingPathDelimiter(lText),
        ExcludeTrailingPathDelimiter(lRoot))) then
    begin
      aFailure := 'environment-redirect:' + lValue;
      Exit;
    end;
  try
    for var i := Low(cFiles) to High(cFiles) do
    begin
      if i < 3 then
        lFileName := CombinePath([lRoot, 'Bin', cFiles[i]])
      else
        lFileName := TPath.Combine(lUser, cFiles[i]);
      aFailure := 'missing-input:' + lFileName;
      if not TFile.Exists(lFileName) then
      begin
        aObservations.AddPresence(lFileName, 'define-evidence-toolchain', False);
        if i = 5 then
          Continue;
        Exit;
      end;
      ReadProjectContextInput(lFileName, 'define-evidence-toolchain', aObservations, lText);
      lDocuments[i] := LoadProjectXml(lText);
      aFailure := 'unclosed-input:' + lFileName;
      if (lDocuments[i] = nil) or (lDocuments[i].DocumentElement = nil) or
        not IsXmlElementNamed(lDocuments[i].DocumentElement, 'Project') then
        Exit;
    end;
    aFailure := 'missing-toolchain-version';
    if not SameText(XmlElementText(lDocuments[1], 'ProductVersion'), lVersion) then
      Exit;
    for var i := Low(cFiles) to High(cFiles) do
    begin
      if lDocuments[i] = nil then
        Continue;
      aFailure := 'unapproved-writer-or-import:' + cFiles[i];
      if not BoundedDefineNodeClosed(lDocuments[i].DocumentElement, i, lVersion) then
        Exit;
      aFailure := 'nonempty-or-unknown-option:' + cFiles[i];
      if not BoundedDefineOptionsEmpty(lDocuments[i], aProperties) then
        Exit;
    end;
    aFailure := '';
    Result := True;
  except
    on E: Exception do
    begin
      // Failed input reading/XML validation is an explicit lack of proof.
      // Keep the existing project diagnostics and properties unchanged.
      aFailure := aFailure + ':' + E.ClassName + ':' + E.Message;
      Result := False;
    end;
  end;
end;

function CompleteProjectDefineEvidence(const aProperties: TPropertyMap;
  const aOptions: TDelphiSemanticOptions;
  const aObservations: IProjectContextObservationsBuilder): Boolean;
var
  lInputs: IDelphiSemanticProfileInputs;
  lProperty: TDelphiSemanticProperty;
  lSwitch, lValue, lFailure: string;
begin
  Result := (aObservations <> nil) and not aOptions.CallerDefinesProvided;
  if not Result then
    Exit;
  if not aObservations.DefineEvidenceIsComplete then
    Exit(False);
  // These are the only switches added by the compiler targets whose inputs
  // cannot change defines or search. Do not decode caller switches (DS-772).
  for lSwitch in GetPropertyValue(aProperties, 'DCC_AdditionalSwitches').Split(
    [' ', #9, #13, #10], TStringSplitOptions.ExcludeEmpty) do
    if not StartsText('--sdk-version:', lSwitch) and not SameText(lSwitch, '-JF:COFFI') then
      Exit(False);
  lInputs := ProfileInputs(aOptions);
  for lValue in ['DCC_Define', 'DCC_AdditionalSwitches'] do
  begin
    for lProperty in aOptions.EnvironmentVariables do
      if SameText(lProperty.Name, lValue) then
        Exit(False);
    if lInputs.TryEnvironmentValue(lValue, lSwitch) then
      Exit(False);
  end;
  if aObservations.BoundedDefineImportPending then
    Result := BoundedDefineToolchain(aProperties, aOptions, aObservations, lFailure);
end;

procedure CaptureMainSourceConfig(const aMainSourceFileName: string;
  const aObservations: IProjectContextObservationsBuilder);
var
  lFileName: string;
  lExists: Boolean;
begin
  if aObservations = nil then
    Exit;
  lFileName := TPath.ChangeExtension(aMainSourceFileName, '.cfg');
  // --no-config excludes dcc*.cfg, not the actual main source's config.
  // We do not evaluate config/response-file options in this bounded rule.
  try
    lExists := TFile.Exists(lFileName);
    aObservations.AddPresence(lFileName, 'main-source-config', lExists);
    if lExists then
    begin
      aObservations.MarkDefineEvidenceIncomplete;
      aObservations.AddInput(lFileName, HashProjectContextBytes(TFile.ReadAllBytes(lFileName)),
        'main-source-config');
    end;
  except
    on E: Exception do
    begin
      // An unreadable input is explicit missing proof, never absent config.
      aObservations.MarkDefineEvidenceIncomplete;
      aObservations.MarkIncomplete;
    end;
  end;
end;

procedure PopulateProjectSemanticContext(var aProject: TDelphiSemanticProjectInfo;
  const aDocument: IXMLDocument; const aProperties: TPropertyMap;
  const aOptions: TDelphiSemanticOptions;
  const aDiagnostics: TList<TDelphiSemanticDiagnostic>;
  const aObservations: IProjectContextObservationsBuilder);
var
  lDefine: string;
  lDefines: TList<string>;
  lIncludePaths: TList<string>;
  lReferenceDirectories: TList<string>;
  lSearchPath: string;
  lSearchPaths: TList<string>;
  lSourceFiles: TList<string>;
  lUnitAliases: TList<string>;
  lUnitScopeNames: TList<string>;
begin
  lDefines := nil;
  lIncludePaths := nil;
  lReferenceDirectories := nil;
  lSearchPaths := nil;
  lSourceFiles := nil;
  lUnitAliases := nil;
  lUnitScopeNames := nil;
  try
    lDefines := TList<string>.Create;
    lIncludePaths := TList<string>.Create;
    lReferenceDirectories := TList<string>.Create;
    lSearchPaths := TList<string>.Create;
    lSourceFiles := TList<string>.Create;
    lUnitAliases := TList<string>.Create;
    lUnitScopeNames := TList<string>.Create;

    AddDelimitedTexts(lDefines, GetPropertyValue(aProperties, 'DCC_Define'));
    for lDefine in TDelphiSemanticCompilerProfileBuilder.DefinesForPlatform(aProject.Platform) do
      AddUniqueText(lDefines, lDefine);
    if SameText(GetPropertyValue(aProperties, 'DSCompilerIncludePathsKnown'), 'True') then
      AddDelimitedPaths(lIncludePaths, aProject.ProjectDirectory,
        GetPropertyValue(aProperties, 'DSCompilerIncludePaths'))
    else
      lIncludePaths.Add('<include-path-unproved>');
    AddDelimitedPaths(lSearchPaths, aProject.ProjectDirectory,
      GetPropertyValue(aProperties, 'DCC_UnitSearchPath'));
    for lSearchPath in aOptions.SearchPaths do
      AddUniquePath(lSearchPaths, aProject.ProjectDirectory,
        ExpandProperties(lSearchPath, aProject.ProjectFileName, aProperties, aDiagnostics));
    AddDelimitedTexts(lUnitScopeNames, GetPropertyValue(aProperties, 'DCC_UnitScopeNames'));
    AddDelimitedTexts(lUnitScopeNames, GetPropertyValue(aProperties, 'DCC_Namespace'));
    AddDelimitedTexts(lUnitAliases, GetPropertyValue(aProperties, 'DCC_UnitAlias'));
    AddDelimitedTexts(lUnitAliases, GetPropertyValue(aProperties, 'DCC_UnitAliases'));
    AddReferenceDirectories(aDocument, aProject.ProjectFileName, aProject.ProjectDirectory,
      aProperties, aDiagnostics, lSearchPaths, lReferenceDirectories, lSourceFiles, aObservations);

    aProject.Defines := lDefines.ToArray;
    CaptureMainSourceConfig(aProject.MainSourceFileName, aObservations);
    aProject.DefineEvidenceComplete := CompleteProjectDefineEvidence(aProperties,
      aOptions, aObservations);
    aProject.IncludePaths := lIncludePaths.ToArray;
    aProject.SearchPaths := lSearchPaths.ToArray;
    aProject.UnitScopeNames := lUnitScopeNames.ToArray;
    aProject.UnitAliases := lUnitAliases.ToArray;
    aProject.ReferenceDirectories := lReferenceDirectories.ToArray;
    aProject.SourceFileNames := lSourceFiles.ToArray;
  finally
    lUnitScopeNames.Free;
    lUnitAliases.Free;
    lSearchPaths.Free;
    lSourceFiles.Free;
    lReferenceDirectories.Free;
    lIncludePaths.Free;
    lDefines.Free;
  end;
end;

procedure AddAdditionalSourceFiles(var aProject: TDelphiSemanticProjectInfo;
  const aOptions: TDelphiSemanticOptions);
var
  lFileName: string;
  lSourceFiles: TList<string>;
begin
  if Length(aOptions.AdditionalSourceFileNames) = 0 then
    Exit;

  lSourceFiles := TList<string>.Create;
  try
    for lFileName in aProject.SourceFileNames do
      AddUniquePath(lSourceFiles, aProject.ProjectDirectory, lFileName);
    for lFileName in aOptions.AdditionalSourceFileNames do
      AddUniquePath(lSourceFiles, aProject.ProjectDirectory, lFileName);
    aProject.SourceFileNames := lSourceFiles.ToArray;
  finally
    lSourceFiles.Free;
  end;
end;

function NormalizeFingerprintPart(const aValue, aFallback: string): string;
begin
  Result := Trim(aValue);
  if Result = '' then
    Result := aFallback;
end;

function BuildCompilerProfileName(const aProject: TDelphiSemanticProjectInfo;
  const aOptions: TDelphiSemanticOptions): string;
var
  lConfiguration: string;
  lPlatform: string;
  lVersion: string;
begin
  lVersion := NormalizeFingerprintPart(aOptions.DelphiVersion, 'default');
  lPlatform := NormalizeFingerprintPart(aProject.Platform, 'default');
  lConfiguration := NormalizeFingerprintPart(aProject.Configuration, 'default');
  Result := Format('Delphi-%s-%s-%s', [lVersion, lPlatform, lConfiguration]);
end;

procedure AppendFingerprintItem(const aBuilder: TStringBuilder; const aName, aValue: string);
begin
  aBuilder.Append(aName);
  aBuilder.Append('=');
  aBuilder.AppendLine(aValue);
end;

function CanonicalFingerprintText(const aValue: string): string;
begin
  Result := LowerCase(Trim(aValue));
end;

procedure AppendFingerprintItems(const aBuilder: TStringBuilder; const aName: string;
  const aItems: TArray<string>; const aItemsArePaths: Boolean);
var
  lItem: string;
  lValue: string;
begin
  aBuilder.Append(aName);
  aBuilder.Append('=');
  for lItem in aItems do
  begin
    if aItemsArePaths then
      lValue := TDelphiSemanticCacheIdentityBuilder.CanonicalPath(lItem)
    else
      lValue := CanonicalFingerprintText(lItem);
    if lValue <> '' then
    begin
      aBuilder.Append(lValue);
      aBuilder.Append('|');
    end;
  end;
  aBuilder.AppendLine;
end;

function BuildContextFingerprint(const aProject: TDelphiSemanticProjectInfo;
  const aOptions: TDelphiSemanticOptions; const aRootAbsenceFingerprint: string): string;
var
  lBuilder: TStringBuilder;
  lContext: TDelphiSemanticCacheIdentityContext;
  lProjectIdentity: TDelphiSemanticProjectCacheIdentity;
  lPropertyName: string;
begin
  lContext := Default(TDelphiSemanticCacheIdentityContext);
  lContext.SchemaVersion := 'project-context-fingerprint-v3';
  lContext.ProjectPath := aProject.ProjectFileName;
  lContext.Configuration := aProject.Configuration;
  lContext.Platform := aProject.Platform;
  lContext.DelphiVersion := aOptions.DelphiVersion;
  lContext.Defines := aProject.Defines;
  lContext.SearchPaths := aProject.SourceLookupPaths;
  lContext.UnitScopes := aProject.UnitScopeNames;
  lContext.UnitAliases := aProject.UnitAliases;
  lProjectIdentity := TDelphiSemanticCacheIdentityBuilder.BuildProjectIdentity(lContext);

  lBuilder := TStringBuilder.Create;
  try
    AppendFingerprintItem(lBuilder, 'projectIdentity', lProjectIdentity.ProjectKey);
    AppendFingerprintItem(lBuilder, 'defineEvidenceComplete',
      BoolToStr(aProject.DefineEvidenceComplete, True));
    AppendFingerprintItem(lBuilder, 'main',
      TDelphiSemanticCacheIdentityBuilder.CanonicalPath(aProject.MainSourceFileName));
    AppendFingerprintItem(lBuilder, 'rsvars',
      TDelphiSemanticCacheIdentityBuilder.CanonicalPath(aOptions.RsVarsPath));
    AppendFingerprintItem(lBuilder, 'envoptions',
      TDelphiSemanticCacheIdentityBuilder.CanonicalPath(aOptions.EnvOptionsPath));
    AppendFingerprintItem(lBuilder, 'compilerProfile',
      CanonicalFingerprintText(aProject.CompilerProfileName));
    if aOptions.ImplicitRootMemberAbsence <> nil then
      AppendFingerprintItem(lBuilder, 'implicitRootMemberAbsence',
        aRootAbsenceFingerprint);
    AppendFingerprintItem(lBuilder, 'compilerIncludeSearchPathProvided',
      BoolToStr(aOptions.CompilerIncludeSearchPathProvided, True));
    AppendFingerprintItem(lBuilder, 'compilerIncludeSearchPath', aOptions.CompilerIncludeSearchPath);
    AppendFingerprintItems(lBuilder, 'includePaths', aProject.IncludePaths, True);
    AppendFingerprintItems(lBuilder, 'references', aProject.ReferenceDirectories, True);
    AppendFingerprintItems(lBuilder, 'sourceFiles', aProject.SourceFileNames, True);
    // Hash raw switch values without case folding or delimiter ambiguity.
    for lPropertyName in cDelphiSemanticCompilerLinkPropertyNames do
      AppendFingerprintItem(lBuilder, lPropertyName,
        THashSHA2.GetHashString(aProject.PropertyValue(lPropertyName)));
    Result := THashSHA2.GetHashString(lBuilder.ToString);
  finally
    lBuilder.Free;
  end;
end;

function BuildConfigurationIdentity(const aProject: TDelphiSemanticProjectInfo;
  const aOptions: TDelphiSemanticOptions; const aRootAbsenceFingerprint: string): string;
var
  i: Integer;
  lBuilder: TStringBuilder;
begin
  lBuilder := TStringBuilder.Create;
  try
    lBuilder.AppendLine('schema=semantic-project-configuration-v1');
    AppendFingerprintItem(lBuilder, 'configuration', aProject.Configuration);
    AppendFingerprintItem(lBuilder, 'platform', aProject.Platform);
    AppendFingerprintItem(lBuilder, 'delphiVersion', aOptions.DelphiVersion);
    AppendFingerprintItem(lBuilder, 'compilerIncludeSearchPathProvided',
      BoolToStr(aOptions.CompilerIncludeSearchPathProvided, True));
    AppendFingerprintItem(lBuilder, 'compilerIncludeSearchPath', aOptions.CompilerIncludeSearchPath);
    if aOptions.ImplicitRootMemberAbsence <> nil then
      AppendFingerprintItem(lBuilder, 'implicitRootMemberAbsence',
        aRootAbsenceFingerprint);
    AppendFingerprintItem(lBuilder, 'rsvarsPath',
      TDelphiSemanticCacheIdentityBuilder.CanonicalPath(aOptions.RsVarsPath));
    AppendFingerprintItem(lBuilder, 'environmentOptionsPath',
      TDelphiSemanticCacheIdentityBuilder.CanonicalPath(aOptions.EnvOptionsPath));
    for i := 0 to High(aOptions.EnvironmentVariables) do
    begin
      AppendFingerprintItem(lBuilder, 'environmentName',
        aOptions.EnvironmentVariables[i].Name);
      AppendFingerprintItem(lBuilder, 'environmentValue',
        aOptions.EnvironmentVariables[i].Value);
    end;
    Result := THashSHA2.GetHashString(lBuilder.ToString);
  finally
    lBuilder.Free;
  end;
end;

procedure PopulateProjectProperties(var aProject: TDelphiSemanticProjectInfo;
  const aProperties: TPropertyMap);
var
  lPair: TPair<string, string>;
  lProperties: TList<TDelphiSemanticProperty>;
  lProperty: TDelphiSemanticProperty;
begin
  lProperties := TList<TDelphiSemanticProperty>.Create;
  try
    for lPair in aProperties do
    begin
      lProperty.Name := lPair.Key;
      lProperty.Value := lPair.Value;
      lProperties.Add(lProperty);
    end;
    aProject.Properties := lProperties.ToArray;
  finally
    lProperties.Free;
  end;
end;

procedure SeedProfileDirectories(const aProperties: TPropertyMap;
  const aOptions: TDelphiSemanticOptions);
const
  cNames: array[TDelphiSemanticProfileFolder] of string = ('BDSUSERDIR', 'BDSCOMMONDIR');
  cViews: array[0..1] of Cardinal = (KEY_WOW64_64KEY, KEY_WOW64_32KEY);
var
  lInputs: IDelphiSemanticProfileInputs;
  lProperty: TDelphiSemanticProperty;
  lFolder: TDelphiSemanticProfileFolder;
  lView: Cardinal;
  lName, lValue, lSource, lVersion: string;
  lPresent: Boolean;
begin
  lInputs := ProfileInputs(aOptions);
  lVersion := ProfileVersion(aOptions);
  for lFolder := Low(TDelphiSemanticProfileFolder) to High(TDelphiSemanticProfileFolder) do
  begin
    lName := cNames[lFolder];
    try
      lPresent := aProperties.TryGetValue(PropertyKey(lName), lValue);
      lSource := 'native option';
      if not lPresent then
      begin
        lPresent := lInputs.TryEnvironmentValue(lName, lValue);
        lSource := 'environment';
      end;
      if not lPresent then
      begin
        lSource := 'BDS registry';
        for lView in cViews do
        begin
          for lProperty in lInputs.RegistryValues('Software\Embarcadero\BDS\' +
            lVersion + '\Environment Variables', lView) do
            if SameText(lProperty.Name, lName) then
            begin
              lValue := lProperty.Value;
              lPresent := True;
              Break;
            end;
          if lPresent then
            Break;
        end;
      end;
      if not lPresent then
      begin
        lValue := lInputs.KnownFolderPath(lFolder);
        if lValue <> '' then
          lValue := TPath.Combine(lValue, 'Embarcadero\Studio\' + lVersion);
        lSource := 'derived default';
      end;
      if lPresent or (lValue <> '') then
      begin
        SetPropertyValue(aProperties, lName, lValue);
        SetPropertyValue(aProperties, lName + 'Source', lSource);
      end;
    except
      on E: Exception do
        // Retain fallback evidence until all project/profile overrides have
        // been evaluated; only final reconciliation decides availability.
        SetPropertyValue(aProperties, lName + 'InputError', E.ClassName + ': ' + E.Message);
    end;
  end;
end;

procedure ReconcileProfileDirectories(const aProfile, aProperties: TPropertyMap;
  const aProblems: TList<TDelphiSemanticDiagnostic>);
const
  cNames: array[0..1] of string = ('BDSUSERDIR', 'BDSCOMMONDIR');
var
  lName, lValue, lError: string;
begin
  // Presence in the final profile (including empty) supersedes fallback
  // failures. Decide errors and provenance once, after every override source.
  for lName in cNames do
    if aProfile.TryGetValue(PropertyKey(lName), lValue) then
    begin
      aProperties.Remove(PropertyKey(lName + 'InputError'));
      // Successful provenance is profile metadata: consumers use diagnostics
      // to decide completeness, so a resolved input must not become a defect.
      SetPropertyValue(aProperties, 'DSWitnessProfile' + lName,
        ExpandSemanticProjectProperty(lValue,
          GetPropertyValue(aProperties, 'MSBuildProjectFullPath'), aProfile,
          aProblems));
      SetPropertyValue(aProperties, 'DSWitnessProfile' + lName + 'Source',
        GetPropertyValue(aProfile, lName + 'Source'));
    end else begin
      lError := GetPropertyValue(aProfile, lName + 'InputError');
      if lError = '' then
        lError := 'No explicit value or known-folder default is available';
      SetPropertyValue(aProperties, lName + 'InputError', lError);
      AddDiagnostic(aProblems, CreateWarningDiagnostic('PROFILE_DIRECTORY_UNAVAILABLE',
        lName + ': ' + lError, GetPropertyValue(aProperties, 'MSBuildProjectFullPath')));
    end;
end;

procedure PublishProfileProblem(const aDiagnostics: TList<TDelphiSemanticDiagnostic>;
  const aProblem: TDelphiSemanticDiagnostic);
var
  lExisting: TDelphiSemanticDiagnostic;
begin
  // Repeated consumption may rediscover a problem. Preserve distinct source
  // locations, but publish each equivalent problem only once to consumers.
  for lExisting in aDiagnostics do
    if (lExisting.Code = aProblem.Code) and (lExisting.Message = aProblem.Message) and
      SameText(lExisting.FileName, aProblem.FileName) and
      (lExisting.Line = aProblem.Line) and (lExisting.Column = aProblem.Column) and
      (lExisting.Severity = aProblem.Severity) then
      Exit;
  AddDiagnostic(aDiagnostics, aProblem);
end;

procedure ReconcileWitnessProfile(const aProfile, aProperties: TPropertyMap;
  const aProblems, aDiagnostics: TList<TDelphiSemanticDiagnostic>;
  const aExpandedPaths: string; const aHasLibraryEvidence: Boolean);
var
  lProblem: TDelphiSemanticDiagnostic;
  lProjectFile: string;
begin
  ReconcileProfileDirectories(aProfile, aProperties, aProblems);
  lProjectFile := GetPropertyValue(aProperties, 'MSBuildProjectFullPath');
  if not aHasLibraryEvidence and (aProblems.Count = 0) then
    AddDiagnostic(aProblems, CreateWarningDiagnostic('PROFILE_INPUT_UNAVAILABLE',
      'No library search and browsing metadata is available from the registry or profile',
      lProjectFile));
  if (Pos('$(', aExpandedPaths) > 0) and (aProblems.Count = 0) then
    AddDiagnostic(aProblems, CreateWarningDiagnostic('UNRESOLVED_MSBUILD_MACRO',
      'Unresolved profile path: ' + aExpandedPaths, lProjectFile));
  // Knowledge is a consequence of reconciled problems, never an independent
  // flag that can silently become false on an availability or exception path.
  SetPropertyValue(aProperties, 'DSWitnessProfileKnown', BoolToStr(aProblems.Count = 0, True));
  SetPropertyValue(aProperties, 'DSWitnessProfilePaths', aExpandedPaths);
  if aProblems.Count > 0 then
    SetPropertyValue(aProperties, 'DSWitnessProfileError',
      aProblems[0].Code + ': ' + aProblems[0].Message)
  else
    aProperties.Remove(PropertyKey('DSWitnessProfileError'));
  for lProblem in aProblems do
    PublishProfileProblem(aDiagnostics, lProblem);
end;

function CreateInitialProperties(const aProjectFileName: string; const aDocument: IXMLDocument;
  const aOptions: TDelphiSemanticOptions): TPropertyMap;
var
  lEnvironmentProperty: TDelphiSemanticProperty;
  lProjectDirectory: string;
  lProjectFile: string;
  lProjectName: string;
  lPropertyName: string;
begin
  Result := TPropertyMap.Create;
  lProjectDirectory := TPath.GetDirectoryName(aProjectFileName);
  lProjectFile := TPath.GetFileName(aProjectFileName);
  lProjectName := TPath.GetFileNameWithoutExtension(aProjectFileName);
  SetPropertyValue(Result, 'MSBuildProjectDirectory', lProjectDirectory);
  SetPropertyValue(Result, 'ProjectDir', IncludeTrailingPathDelimiter(lProjectDirectory));
  SetPropertyValue(Result, 'PROJECTDIR', IncludeTrailingPathDelimiter(lProjectDirectory));
  SetPropertyValue(Result, 'ProjectName', lProjectName);
  SetPropertyValue(Result, 'MSBuildProjectName', lProjectName);
  SetPropertyValue(Result, 'MSBuildProjectFullPath', aProjectFileName);
  SetPropertyValue(Result, 'MSBuildProjectFile', lProjectFile);
  SetPropertyValue(Result, 'Config', aOptions.Configuration);
  SetPropertyValue(Result, 'Platform', aOptions.Platform);
  SetPropertyValue(Result, 'DelphiVersion', aOptions.DelphiVersion);
  for lEnvironmentProperty in aOptions.EnvironmentVariables do
    if not Result.ContainsKey(PropertyKey(lEnvironmentProperty.Name)) then
      SetPropertyValue(Result, lEnvironmentProperty.Name, lEnvironmentProperty.Value);
  SeedProfileDirectories(Result, aOptions);
  // Optional CodeGear target properties follow MSBuild's unset-as-empty behavior.
  for lPropertyName in cDelphiSemanticCompilerLinkPropertyNames do
    if not Result.ContainsKey(PropertyKey(lPropertyName)) then
      SetPropertyValue(Result, lPropertyName, '');
  if not Result.ContainsKey(PropertyKey('PlatformSDK')) then
    SetPropertyValue(Result, 'PlatformSDK', '');
  if not Result.ContainsKey(PropertyKey('DefaultPlatformSDK')) then
    SetPropertyValue(Result, 'DefaultPlatformSDK', '');
  if not Result.ContainsKey(PropertyKey('GlobalOptionFile')) then
    SetPropertyValue(Result, 'GlobalOptionFile', '');
  if GetPropertyValue(Result, 'Config') = '' then
    SetPropertyValue(Result, 'Config', XmlElementText(aDocument, 'Config'));
  if GetPropertyValue(Result, 'Platform') = '' then
    SetPropertyValue(Result, 'Platform', XmlElementText(aDocument, 'Platform'));
end;

function CreateProjectInfoFromProperties(const aProjectFileName: string;
  const aDocument: IXMLDocument;
  const aProperties: TPropertyMap): TDelphiSemanticProjectInfo;
var
  lMainSource: string;
begin
  Result.DefineEvidenceComplete := False;
  Result.ProjectFileName := aProjectFileName;
  Result.ProjectDirectory := TPath.GetDirectoryName(aProjectFileName);
  Result.ProjectName := GetPropertyValue(aProperties, 'ProjectName');
  if Result.ProjectName = '' then
    Result.ProjectName := TPath.GetFileNameWithoutExtension(aProjectFileName);

  Result.Configuration := GetPropertyValue(aProperties, 'Config');
  Result.Platform := GetPropertyValue(aProperties, 'Platform');

  lMainSource := GetPropertyValue(aProperties, 'MainSource');
  if lMainSource = '' then
    lMainSource := XmlElementText(aDocument, 'MainSource');
  if lMainSource = '' then
    lMainSource := TPath.ChangeExtension(TPath.GetFileName(aProjectFileName), '.dpr');
  Result.MainSourceFileName := NormalizeProjectPath(Result.ProjectDirectory, lMainSource);
  PopulateProjectProperties(Result, aProperties);
end;

function ResolveProjectFileName(const aFileName: string; out aProjectFileName: string;
  out aFailure: TDelphiSemanticContextResult): Boolean;
var
  lExtension: string;
  lInputFileName: string;
begin
  lInputFileName := TPath.GetFullPath(aFileName);
  if not TFile.Exists(lInputFileName) then
  begin
    aFailure := FailureResult(CreateErrorDiagnostic('PROJECT_FILE_NOT_FOUND',
      'Project file not found: ' + lInputFileName, lInputFileName));
    Exit(False);
  end;

  lExtension := TPath.GetExtension(lInputFileName).ToLowerInvariant;
  if lExtension = '.dproj' then
  begin
    aProjectFileName := lInputFileName;
    Exit(True);
  end;

  if lExtension = '.dpr' then
  begin
    aProjectFileName := TPath.ChangeExtension(lInputFileName, '.dproj');
    if TFile.Exists(aProjectFileName) then
      Exit(True);

    aFailure := FailureResult(CreateErrorDiagnostic('PROJECT_FILE_NOT_FOUND',
      'Sibling .dproj file not found: ' + aProjectFileName, aProjectFileName));
    Exit(False);
  end;

  aFailure := FailureResult(CreateErrorDiagnostic('PROJECT_FILE_UNSUPPORTED',
    'Unsupported project file extension: ' + lExtension, lInputFileName));
  Result := False;
end;

procedure PopulateCompilerIncludePaths(const aProperties: TPropertyMap;
  const aOptions: TDelphiSemanticOptions;
  const aDiagnostics: TList<TDelphiSemanticDiagnostic>);
begin
  // Only the caller can certify the complete ordered compiler include-search list.
  // The project evaluator cannot observe every MSBuild writer or its timing.
  SetPropertyValue(aProperties, 'DSCompilerIncludePathsKnown', 'False');
  SetPropertyValue(aProperties, 'DSCompilerIncludePaths', '');
  if not aOptions.CompilerIncludeSearchPathProvided then
    Exit;
  if aOptions.CompilerIncludeSearchPathProvided and
    (Pos('$(', aOptions.CompilerIncludeSearchPath) = 0) then
  begin
    SetPropertyValue(aProperties, 'DSCompilerIncludePaths', aOptions.CompilerIncludeSearchPath);
    SetPropertyValue(aProperties, 'DSCompilerIncludePathsKnown', 'True');
    Exit;
  end;
  // Absence is informational for unrelated statements. Directive facts withhold
  // proof only where imports or declarations depend on an include expansion.
  AddDiagnostic(aDiagnostics, CreateDiagnostic('COMPILER_INCLUDE_PATH_UNPROVED',
    'The caller did not supply an evaluated MSBuild IncludePath.',
    GetPropertyValue(aProperties, 'MSBuildProjectFullPath'),
    TDelphiSemanticDiagnosticSeverity.dsInfo));
end;

procedure PopulateWitnessProfileProperties(const aProperties: TPropertyMap;
  const aOptions: TDelphiSemanticOptions;
  const aObservations: IProjectContextObservationsBuilder;
  const aDiagnostics: TList<TDelphiSemanticDiagnostic>);
const
  cRegistryViews: array[0..1] of Cardinal = (KEY_WOW64_64KEY, KEY_WOW64_32KEY);
var
  lProfile: TPropertyMap;
  lDiagnostics: TList<TDelphiSemanticDiagnostic>;
  lInputs: IDelphiSemanticProfileInputs;
  lValues: TPropertyMap;
  lProperty: TDelphiSemanticProperty;
  lPair: TPair<string, string>;
  lVersion, lPlatform, lBaseKey, lRawPaths, lExpandedPaths: string;
  lEnvOptions, lBdsRoot, lTranslatedPaths: string;
  lHasLibraryEvidence, lRegistryKnown: Boolean;
  lView: Cardinal;
begin
  lProfile := TPropertyMap.Create;
  lDiagnostics := TList<TDelphiSemanticDiagnostic>.Create;
  lInputs := ProfileInputs(aOptions);
  lValues := TPropertyMap.Create;
  SetPropertyValue(aProperties, 'DSCompilerIncludePathsKnown', 'False');
  lHasLibraryEvidence := False;
  lExpandedPaths := '';
  lEnvOptions := '';
  try
    try
      for lPair in aProperties do
        lProfile.AddOrSetValue(lPair.Key, lPair.Value);
      // The IDE appends the project path macro even when it is unset.
      if not lProfile.ContainsKey(PropertyKey('DCC_UnitSearchPath')) then
        SetPropertyValue(lProfile, 'DCC_UnitSearchPath', '');
      lVersion := ProfileVersion(aOptions);
      lPlatform := GetPropertyValue(aProperties, 'Platform');
      if lPlatform = '' then
        lPlatform := 'Win64';
      SetPropertyValue(lProfile, 'Platform', lPlatform);
      lBdsRoot := TDelphiSemanticCompilerProfileBuilder.ResolveBdsRoot(lVersion, aOptions.RsVarsPath);
      SetPropertyValue(lProfile, 'BDS', lBdsRoot);
      SetPropertyValue(lProfile, 'BDSLIB', TPath.Combine(lBdsRoot, 'lib'));
      lBaseKey := 'Software\Embarcadero\BDS\' + lVersion;
      lRegistryKnown := False;
      lRawPaths := GetPropertyValue(aProperties, 'DelphiLibraryPath') + ';' +
        GetPropertyValue(aProperties, 'DelphiBrowsingPath') + ';' +
        GetPropertyValue(aProperties, 'DelphiDebugDCUPath');
      lTranslatedPaths := GetPropertyValue(aProperties, 'DelphiTranslatedLibraryPath') + ';' +
        GetPropertyValue(aProperties, 'DelphiTranslatedDebugLibraryPath');
      for lView in cRegistryViews do
      begin
        for lProperty in lInputs.RegistryValues(lBaseKey + '\Environment Variables', lView) do
          if not lProfile.ContainsKey(PropertyKey(lProperty.Name)) then
            SetPropertyValue(lProfile, lProperty.Name, lProperty.Value);
        lValues.Clear;
        for lProperty in lInputs.RegistryValues(lBaseKey + '\Library\' + lPlatform, lView) do
          SetPropertyValue(lValues, lProperty.Name, lProperty.Value);
        if lValues.ContainsKey(PropertyKey('Search Path')) and
          lValues.ContainsKey(PropertyKey('Browsing Path')) then
        begin
          lRegistryKnown := True;
          lRawPaths := lRawPaths + ';' + GetPropertyValue(lValues, 'Search Path') + ';' +
            GetPropertyValue(lValues, 'Browsing Path');
        end;
        lRawPaths := lRawPaths + ';' + GetPropertyValue(lValues, 'Debug DCU Path');
        lTranslatedPaths := lTranslatedPaths + ';' +
          GetPropertyValue(lValues, 'Translated Library Path') + ';' +
          GetPropertyValue(lValues, 'Translated Debug Library Path');
      end;
      // Use our existing evaluator for profile files and retain its input evidence.
      lEnvOptions := aOptions.EnvOptionsPath;
      if lEnvOptions = '' then
      begin
        lEnvOptions := GetPropertyValue(lProfile, 'BDSUSERDIR');
        if lEnvOptions <> '' then
          lEnvOptions := TPath.Combine(lEnvOptions, 'EnvOptions.proj');
      end;
      lHasLibraryEvidence := lRegistryKnown;
      if (aOptions.EnvOptionsPath <> '') or
        ((lEnvOptions <> '') and TFile.Exists(lEnvOptions)) then
      begin
        ApplyPropertyFile(lEnvOptions, ExtractFilePath(lEnvOptions), lProfile,
          lDiagnostics, True, aObservations);
        lRawPaths := lRawPaths + ';' + GetPropertyValue(lProfile, 'DelphiLibraryPath') + ';' +
          GetPropertyValue(lProfile, 'DelphiBrowsingPath') + ';' +
          GetPropertyValue(lProfile, 'DelphiDebugDCUPath');
        lTranslatedPaths := lTranslatedPaths + ';' +
          GetPropertyValue(lProfile, 'DelphiTranslatedLibraryPath') + ';' +
          GetPropertyValue(lProfile, 'DelphiTranslatedDebugLibraryPath');
        lHasLibraryEvidence := lHasLibraryEvidence or (lProfile.ContainsKey(PropertyKey('DelphiLibraryPath')) and
          lProfile.ContainsKey(PropertyKey('DelphiBrowsingPath')));
      end;
      // MSBuild enables translated paths only for a nonempty language directory.
      if GetPropertyValue(lProfile, 'LANGDIR').Trim <> '' then
        lRawPaths := lRawPaths + ';' + lTranslatedPaths;
      // Directory inputs may themselves contain macros; reuse bounded semantic
      // expansion so final paths and their known state observe the same values.
      lExpandedPaths := ExpandSemanticProjectProperty(lRawPaths, lEnvOptions,
        lProfile, lDiagnostics);
    except
      on E: Exception do
      begin
        // Inaccessible or malformed profiles leave absence unavailable.
        lExpandedPaths := '';
        AddDiagnostic(lDiagnostics, CreateWarningDiagnostic('PROFILE_INPUT_UNAVAILABLE',
          lEnvOptions + ': ' + E.ClassName + ': ' + E.Message,
          GetPropertyValue(aProperties, 'MSBuildProjectFullPath')));
      end;
    end;
    ReconcileWitnessProfile(lProfile, aProperties, lDiagnostics, aDiagnostics,
      lExpandedPaths, lHasLibraryEvidence);
  finally
    lValues.Free;
    lDiagnostics.Free;
    lProfile.Free;
  end;
end;

function LoadProjectInfo(const aProjectFileName: string; const aOptions: TDelphiSemanticOptions;
  const aRootAbsenceFingerprint: string; const aDiagnostics: TList<TDelphiSemanticDiagnostic>): TDelphiSemanticProjectInfo;
var
  lDocument: IXMLDocument;
  lContextObservations: IDelphiSemanticProjectContextObservations;
  lObservations: IProjectContextObservationsBuilder;
  lProperties: TPropertyMap;
  lText: string;
begin
  lObservations := TProjectContextObservationsBuilder.Create;
  ReadProjectContextInput(aProjectFileName, 'project', lObservations, lText);
  lDocument := LoadProjectXml(lText);
  lProperties := CreateInitialProperties(aProjectFileName, lDocument, aOptions);
  try
    ApplyPropertyDocument(lDocument, aProjectFileName, TPath.GetDirectoryName(aProjectFileName),
      lProperties, aDiagnostics, Trim(aOptions.Platform) <> '', lObservations);
    PopulateWitnessProfileProperties(lProperties, aOptions, lObservations, aDiagnostics);
    PopulateCompilerIncludePaths(lProperties, aOptions, aDiagnostics);
    Result := CreateProjectInfoFromProperties(aProjectFileName, lDocument, lProperties);
    PopulateProjectSemanticContext(Result, lDocument, lProperties, aOptions, aDiagnostics,
      lObservations);
    AddAdditionalSourceFiles(Result, aOptions);
    Result.CompilerProfileName := BuildCompilerProfileName(Result, aOptions);
    Result.ContextFingerprint := BuildContextFingerprint(Result, aOptions, aRootAbsenceFingerprint);
    lContextObservations := lObservations.Build(
      BuildConfigurationIdentity(Result, aOptions, aRootAbsenceFingerprint));
    Result.ContextObservations := lContextObservations;
  finally
    lProperties.Free;
  end;
end;

procedure AddLspEnrichmentDiagnosticIfRequested(const aOptions: TDelphiSemanticOptions;
  const aProjectFileName: string; const aDiagnostics: TList<TDelphiSemanticDiagnostic>);
begin
  if not aOptions.UseLspEnrichment then
    Exit;

  AddDiagnostic(aDiagnostics, CreateWarningDiagnostic(
    cDelphiSemanticLspEnrichmentUnsupportedCode,
    cDelphiSemanticLspEnrichmentUnsupportedMessage, aProjectFileName));
end;

class function TDelphiSemanticProject.Load(const aFileName: string): TDelphiSemanticContextResult;
var
  lOptions: TDelphiSemanticOptions;
begin
  lOptions := Default(TDelphiSemanticOptions);
  Result := Load(aFileName, lOptions);
end;

class function TDelphiSemanticProject.Load(const aFileName: string;
  const aOptions: TDelphiSemanticOptions): TDelphiSemanticContextResult;
var
  lDiagnostics: TList<TDelphiSemanticDiagnostic>;
  lFailure: TDelphiSemanticContextResult;
  lProject: TDelphiSemanticProjectInfo;
  lProjectFileName: string;
  lRootAbsenceFingerprint: string;
begin
  if not ResolveProjectFileName(aFileName, lProjectFileName, lFailure) then
    Exit(lFailure);

  lRootAbsenceFingerprint := '';
  if aOptions.ImplicitRootMemberAbsence <> nil then
    try
      // Capture the external getter once before constructing either identity. Every
      // public project/session/planning path shares this containment boundary.
      lRootAbsenceFingerprint := aOptions.ImplicitRootMemberAbsence.EvidenceFingerprint;
    except
      on E: Exception do
        Exit(FailureResult(CreateErrorDiagnostic('IMPLICIT_ROOT_PROVIDER_FAILED',
          'Implicit root-member provider fingerprint failed: ' + E.Message, lProjectFileName)));
    end;
  lDiagnostics := TList<TDelphiSemanticDiagnostic>.Create;
  try
    try
      lProject := LoadProjectInfo(lProjectFileName, aOptions, lRootAbsenceFingerprint, lDiagnostics);
    except
      on E: ECompilerSearchPathError do
        Exit(FailureResult(CreateErrorDiagnostic('COMPILER_SEARCH_PATH_UNPROVED', E.Message, lProjectFileName)));
    end;
    AddLspEnrichmentDiagnosticIfRequested(aOptions, lProjectFileName, lDiagnostics);
    Result := SuccessResult(lProject, lDiagnostics);
  finally
    lDiagnostics.Free;
  end;
end;

end.
