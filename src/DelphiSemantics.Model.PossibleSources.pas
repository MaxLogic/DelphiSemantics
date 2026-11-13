unit DelphiSemantics.Model.PossibleSources;

interface

uses
  System.Generics.Collections,
  DelphiSemantics.CompilerProfile, DelphiSemantics.ImportFacts, DelphiSemantics.Model,
  DelphiSemantics.Preprocess, DelphiSemantics.ProjectContext, DelphiSemantics.Resolve.UnitResolver,
  DelphiSemantics.Source, DelphiSemantics.Source.IdentityInputs;

type
  TDelphiSemanticPossibleSources = record
    RootActivity: string;
    ProjectUnitImports: TArray<string>;
    ImportFacts: TArray<TDelphiSemanticImportFact>;
    Identity: string;
    Sources: IDelphiSemanticSourceObservations;
    References: TArray<TDelphiSemanticReference>;
    Diagnostics: TArray<TDelphiSemanticModelDiagnostic>;
    class function Capture(const aOptions: TDelphiSemanticModelOptions;
      const aNormal: TDelphiSemanticPreprocessResult; const aCollectReferences: Boolean):
      TDelphiSemanticPossibleSources; static;
  end;

  // Fixed model context, fresh inputs and derived lookup state for one batch.
  // No instance or captured result survives its identity computation.
  TDelphiSemanticPossibleSourceBatch = class
  private
    fOptions: TDelphiSemanticModelOptions;
    fInputs: TDelphiSemanticIdentityInputs;
    fSdkDiscovery: TDelphiSemanticRtlSourceDiscovery;
    fSdkSources: TDictionary<string, TArray<string>>;
    fSdkDirectories: TArray<string>;
    fSdkDirectoriesLoaded: Boolean;
    fResolutions: TDictionary<string, TDelphiSemanticUnitResolutionResult>;
    fNeutral: TDictionary<string, TDelphiSemanticPreprocessResult>;
    function FindSdkSources(const aName: string): TArray<string>;
    function SdkDirectories: TArray<string>;
    function Resolve(const aProject: TDelphiSemanticProjectInfo; const aName: string):
      TDelphiSemanticUnitResolutionResult;
    function PreprocessNeutral(const aFileName: string): TDelphiSemanticPreprocessResult;
  public
    constructor Create(const aOptions: TDelphiSemanticModelOptions; const aShared: Boolean);
    destructor Destroy; override;
    procedure RequireCurrentDiscovery;
    function Capture(const aOptions: TDelphiSemanticModelOptions;
      const aNormal: TDelphiSemanticPreprocessResult; const aCollectReferences: Boolean):
      TDelphiSemanticPossibleSources;
    property Inputs: TDelphiSemanticIdentityInputs read fInputs;
  end;

implementation

uses
  System.Generics.Defaults, System.Hash, System.IOUtils, System.StrUtils, System.SysUtils,
  SimpleParser.Lexer, SimpleParser.Lexer.Types,
  DelphiSemantics.SourceConditionals, DelphiSemantics.SourceLookup, MaxLogic.IoUtils, MaxLogic.StrUtils;

type
  TPossibleImportState = record
    SourceText: string;
    Activity: string;
    ScanSource: string;
  end;

  TPossibleSourceCapture = class
  private
    fOptions: TDelphiSemanticModelOptions;
    fProject: TDelphiSemanticProjectInfo;
    fResult: TDelphiSemanticPossibleSources;
    fReferences: TList<TDelphiSemanticReference>;
    fProjectImports: TList<string>;
    fImportFacts: TList<TDelphiSemanticImportFact>;
    fDiagnostics: TList<TDelphiSemanticModelDiagnostic>;
    fVisited: THashSet<string>;
    fCollectReferences: Boolean;
    fCandidateSources: TList<TDelphiSemanticSourceText>;
    fObservedCandidates: THashSet<string>;
    fDirectoryFiles: TDictionary<string, TArray<string>>;
    fBatch: TDelphiSemanticPossibleSourceBatch;
    fSdkBinaries: TDictionary<string, string>;
    fSdkDirectories: TArray<string>;
    fLookup: TDelphiSemanticSourceLookup;
    function TrySdkAlias(const aName: string; out aTarget: string): Boolean;
    function ResolveProjectUnit(const aName: string): TDelphiSemanticUnitResolutionResult;
    function HasAlternateProjectSource(const aName, aOwner, aSelected: string): Boolean;
    procedure ProjectImport(const aFileName: string);
    function IsSdkFile(const aFileName: string): Boolean;
    function TryFindSdkUnit(const aName: string; out aFileName: string): Boolean;
    procedure SdkBoundary(const aName, aFileName, aOwnerFileName: string);
    procedure MergeSources(const aSources: IDelphiSemanticSourceObservations);
    procedure Gap(const aCode, aFileName: string; const aLine: Integer;
      const aDetail: string = '');
    procedure ObserveCandidate(const aFileName: string);
    procedure ImportUnit(const aName, aExplicit, aFileName, aCause: string;
      const aDepth: Integer);
    function ImportCause(const aPossible, aCurrent: TDelphiSemanticPreprocessResult;
      const aOffset: Integer; const aRootFileName, aInheritedCause: string;
      const aActivities: TDictionary<string, TPossibleImportState>;
      out aFileName: string): string;
    procedure ScanImports(const aPossible, aCurrent: TDelphiSemanticPreprocessResult;
      const aRootFileName, aInheritedCause: string; const aDepth: Integer);
    procedure ScanFile(const aSource, aFileName, aPossible, aCurrent,
      aInheritedCause: string; const aDepth: Integer; const aRoot: Boolean);
    procedure ScanUnit(const aFileName, aCause: string; const aDepth: Integer);
    procedure ScanPreprocessed(const aPossible, aCurrent: TDelphiSemanticPreprocessResult;
      const aRootFileName, aCause: string; const aDepth: Integer);
  public
    constructor Create(const aOptions: TDelphiSemanticModelOptions;
      const aCollectReferences: Boolean; const aBatch: TDelphiSemanticPossibleSourceBatch);
    destructor Destroy; override;
    function Execute(const aNormal: TDelphiSemanticPreprocessResult): TDelphiSemanticPossibleSources;
  end;

function NeutralOptions(const aOptions: TDelphiSemanticModelOptions;
  const aFileName: string): TDelphiSemanticPreprocessOptions;
begin
  Result := Default(TDelphiSemanticPreprocessOptions);
  Result.SourceFileName := aFileName;
  Result.PreservePossibleText := True;
  // No initial state can prove a branch never compiled in another configuration.
  Result.SearchPaths := aOptions.IncludePaths;
  Result.SkippedIncludeSearchPaths := aOptions.SearchPaths;
  if not aOptions.ProjectContextApplied then
    Result.SearchPaths := Result.SearchPaths + aOptions.SearchPaths;
end;

constructor TDelphiSemanticPossibleSourceBatch.Create(const aOptions: TDelphiSemanticModelOptions;
  const aShared: Boolean);
begin
  inherited Create;
  fOptions := aOptions;
  fInputs := TDelphiSemanticIdentityInputs.Create(aShared);
  // Exact request spelling is part of returned diagnostics and origins. These
  // derived keys deliberately retain case, even on our Windows host.
  fSdkSources := TDictionary<string, TArray<string>>.Create(TStringComparer.Ordinal);
  fResolutions := TDictionary<string, TDelphiSemanticUnitResolutionResult>.Create(TStringComparer.Ordinal);
  fNeutral := TDictionary<string, TDelphiSemanticPreprocessResult>.Create(TStringComparer.Ordinal);
end;

destructor TDelphiSemanticPossibleSourceBatch.Destroy;
begin
  fNeutral.Free;
  fResolutions.Free;
  fSdkSources.Free;
  fSdkDiscovery.Free;
  fInputs.Free;
  inherited;
end;

function TDelphiSemanticPossibleSourceBatch.FindSdkSources(const aName: string): TArray<string>;
begin
  if not fInputs.Shared or not fSdkSources.TryGetValue(aName, Result) then
  begin
    if fSdkDiscovery = nil then
      fSdkDiscovery := TDelphiSemanticRtlSourceDiscovery.Create(TPath.Combine(fOptions.InstalledSdkRoot, 'source'));
    Result := fSdkDiscovery.DiscoverSourceFiles([aName]);
    if fInputs.Shared then
      fSdkSources.Add(aName, Result);
  end;
  Result := Copy(Result);
end;

function TDelphiSemanticPossibleSourceBatch.SdkDirectories: TArray<string>;
var
  lRoot: string;
begin
  if not fSdkDirectoriesLoaded then
  begin
    lRoot := TPath.Combine(fOptions.InstalledSdkRoot, 'lib');
    if TDirectory.Exists(lRoot) then
    begin
      fSdkDirectories := [lRoot] + TDirectory.GetDirectories(lRoot, '*', TSearchOption.soAllDirectories);
      TArray.Sort<string>(fSdkDirectories);
    end;
    fSdkDirectoriesLoaded := True;
  end;
  Result := Copy(fSdkDirectories);
end;

procedure TDelphiSemanticPossibleSourceBatch.RequireCurrentDiscovery;
var
  lDiscovery: TDelphiSemanticRtlSourceDiscovery;
  lLookup: TPair<string, TArray<string>>;
  lActual: TArray<string>;
  lRoot: string;
begin
  // A newly installed source or library directory can change SDK fallback.
  // Recheck with a fresh discovery object, never with the captured inventory.
  if fSdkSources.Count > 0 then
  begin
    lDiscovery := TDelphiSemanticRtlSourceDiscovery.Create(TPath.Combine(fOptions.InstalledSdkRoot, 'source'));
    try
      for lLookup in fSdkSources do
      begin
        lActual := lDiscovery.DiscoverSourceFiles([lLookup.Key]);
        if string.Join(#0, lActual) <> string.Join(#0, lLookup.Value) then
          raise EInvalidOpException.Create('MODEL_SOURCE_VALIDATION_FAILED: SDK source discovery drift: ' + lLookup.Key);
      end;
    finally
      lDiscovery.Free;
    end;
  end;
  if fSdkDirectoriesLoaded then
  begin
    lRoot := TPath.Combine(fOptions.InstalledSdkRoot, 'lib');
    lActual := nil;
    if TDirectory.Exists(lRoot) then
    begin
      lActual := [lRoot] + TDirectory.GetDirectories(lRoot, '*', TSearchOption.soAllDirectories);
      TArray.Sort<string>(lActual);
    end;
    if string.Join(#0, lActual) <> string.Join(#0, fSdkDirectories) then
      raise EInvalidOpException.Create('MODEL_SOURCE_VALIDATION_FAILED: SDK library discovery drift');
  end;
end;

function TDelphiSemanticPossibleSourceBatch.Resolve(const aProject: TDelphiSemanticProjectInfo;
  const aName: string): TDelphiSemanticUnitResolutionResult;
var
  lKey: string;
begin
  // All options are fixed by this batch. Only the root's lookup directory and
  // requested import vary. Keep their order and spelling; no name-only reuse.
  lKey := aProject.ProjectDirectory + #0 + aName;
  if not fInputs.Shared or not fResolutions.TryGetValue(lKey, Result) then
  begin
    Result := TDelphiSemanticUnitResolver.Resolve(aProject, aName);
    if fInputs.Shared then
      fResolutions.Add(lKey, Result);
  end;
  Result.Candidates := Copy(Result.Candidates);
end;

function TDelphiSemanticPossibleSourceBatch.PreprocessNeutral(const aFileName: string):
  TDelphiSemanticPreprocessResult;
var
  lOptions: TDelphiSemanticPreprocessOptions;
begin
  if not fInputs.Shared or not fNeutral.TryGetValue(aFileName, Result) then
  begin
    lOptions := NeutralOptions(fOptions, aFileName);
    if fInputs.Shared then
    begin
      lOptions.SourceLoader := fInputs.LoadFile;
      lOptions.SourceExists := fInputs.FileExists;
    end;
    Result := TDelphiSemanticPreprocessor.PreprocessFile(lOptions);
    if fInputs.Shared then
      fNeutral.Add(aFileName, Result);
  end;
end;

function AggregateActivity(const aSource, aFileName: string;
  const aPreprocess: TDelphiSemanticPreprocessResult): string;
var
  i: Integer;
  lStates, lValidatedSource: string;
  lSpan: TDelphiSemanticActivitySpan;
  lState: Char;
begin
  if not aPreprocess.ActivityEvidenceAvailable then
    Exit(TDelphiSemanticSourceConditionals.UnavailableActivity);
  lStates := StringOfChar('-', Length(aSource));
  lValidatedSource := aSource;
  for lSpan in aPreprocess.ActivitySpans do
    if SameText(lSpan.FileName, aFileName) then
    begin
      // Activity spans from one expansion retain the same immutable string.
      // Keep the last equal value alive and compare its bytes only on a new
      // allocation. Every distinct value must still match our exact source.
      if Pointer(lSpan.SourceText) <> Pointer(lValidatedSource) then
      begin
        if lSpan.SourceText <> aSource then
          Exit(TDelphiSemanticSourceConditionals.UnavailableActivity);
        lValidatedSource := lSpan.SourceText;
      end;
      if (lSpan.StartOffset < 1) or (lSpan.EndOffset > Length(aSource) + 1) then
        Exit(TDelphiSemanticSourceConditionals.UnavailableActivity);
      case lSpan.Activity of
        saActive: lState := 'A';
        saInactive: lState := 'I';
      else
        lState := '?';
      end;
      for i := lSpan.StartOffset to lSpan.EndOffset - 1 do
        // An active/possible expansion defeats inactivity at a shared position.
        if (lStates[i] = '-') or (lState = 'A') or
          ((lStates[i] = 'I') and (lState = '?')) then
          lStates[i] := lState;
    end;
  if lStates = StringOfChar('-', Length(aSource)) then
    lStates := StringOfChar('I', Length(aSource));
  lStates := StringReplace(lStates, '-', '?', [rfReplaceAll]);
  Result := TDelphiSemanticSourceConditionals.UnavailableActivity + lStates;
end;

constructor TPossibleSourceCapture.Create(const aOptions: TDelphiSemanticModelOptions;
  const aCollectReferences: Boolean; const aBatch: TDelphiSemanticPossibleSourceBatch);
begin
  inherited Create;
  fOptions := aOptions;
  fBatch := aBatch;
  fCollectReferences := aCollectReferences;
  fCandidateSources := TList<TDelphiSemanticSourceText>.Create;
  fObservedCandidates := THashSet<string>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
  fDirectoryFiles := TDictionary<string, TArray<string>>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
  fReferences := TList<TDelphiSemanticReference>.Create;
  fProjectImports := TList<string>.Create;
  fImportFacts := TList<TDelphiSemanticImportFact>.Create;
  fDiagnostics := TList<TDelphiSemanticModelDiagnostic>.Create;
  fVisited := THashSet<string>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
  fProject.ProjectDirectory := ExtractFilePath(aOptions.SourceFileName);
  fProject.SearchPaths := aOptions.SearchPaths;
  fProject.SourceFileNames := aOptions.ProjectSourceFileNames;
  fProject.UnitAliases := aOptions.UnitAliases;
  fProject.UnitScopeNames := aOptions.UnitScopeNames;
  fLookup := TDelphiSemanticSourceLookup.Create(fProject, aOptions.PossibleUnitSearchPaths,
    Length(aOptions.PossibleUnitScopeNames) > 0, aOptions.InstalledSdkRoot);
end;

destructor TPossibleSourceCapture.Destroy;
begin
  fLookup.Free;
  fDirectoryFiles.Free;
  fObservedCandidates.Free;
  fCandidateSources.Free;
  fSdkBinaries.Free;
  fVisited.Free;
  fDiagnostics.Free;
  fReferences.Free;
  fImportFacts.Free;
  fProjectImports.Free;
  inherited Destroy;
end;

procedure TPossibleSourceCapture.Gap(const aCode, aFileName: string; const aLine: Integer;
  const aDetail: string);
var
  lDiagnostic: TDelphiSemanticModelDiagnostic;
begin
  lDiagnostic := Default(TDelphiSemanticModelDiagnostic);
  lDiagnostic.Code := aCode;
  lDiagnostic.Message := 'Possible source could not be fully observed. ' + aDetail;
  lDiagnostic.FileName := aFileName;
  lDiagnostic.Line := aLine;
  fDiagnostics.Add(lDiagnostic);
end;

procedure TPossibleSourceCapture.MergeSources(const aSources: IDelphiSemanticSourceObservations);
var
  lCombined: IDelphiSemanticSourceObservations;
  lError: string;
begin
  if aSources = nil then
    Exit;
  if fResult.Sources = nil then
    fResult.Sources := aSources
  else if TDelphiSemanticSourceEvidence.TryMerge(fResult.Sources, aSources, lCombined, lError) then
    fResult.Sources := lCombined
  else
    raise EInvalidOpException.Create('MODEL_SOURCE_VALIDATION_FAILED: ' + lError);
end;

procedure TPossibleSourceCapture.ObserveCandidate(const aFileName: string);
var
  lSource: TDelphiSemanticSourceText;
  lLoaded: TDelphiSemanticSourceLoadResult;
begin
  // Candidate paths are numerous. Retain the first observation in constant time
  // and merge the batch once, preserving the shared conflict/currentness rules.
  if fObservedCandidates.Contains(aFileName) then
    Exit;
  fObservedCandidates.Add(aFileName);
  if (fResult.Sources <> nil) and fResult.Sources.TryFind(aFileName, lSource) then
    Exit;
  if fBatch.Inputs.FileExists(aFileName) then
  begin
    if SameText(TPath.GetExtension(aFileName), '.pas') then
    begin
      lLoaded := fBatch.Inputs.LoadFile(aFileName);
      if not lLoaded.Success then
        Gap('POSSIBLE_UNIT_SOURCE_UNAVAILABLE', aFileName, 0);
      MergeSources(lLoaded.SourceObservations);
      Exit;
    end;
    lSource := fBatch.Inputs.BinaryObservation(aFileName);
  end else begin
    lSource := Default(TDelphiSemanticSourceText);
    lSource.FileName := TPath.GetFullPath(aFileName);
    lSource.Role := 'possible-source-absence';
  end;
  fCandidateSources.Add(lSource);
end;

function TPossibleSourceCapture.IsSdkFile(const aFileName: string): Boolean;
begin
  Result := fLookup.IsSdkFile(aFileName);
end;

function TPossibleSourceCapture.TryFindSdkUnit(const aName: string; out aFileName: string): Boolean;
var
  lName: TUnitCandidateName;
  lFiles: TArray<string>;
  lDirectory, lCandidate: string;
begin
  aFileName := '';
  if fOptions.InstalledSdkRoot = '' then
    Exit(False);
  for lName in TDelphiSemanticUnitResolver.CandidateNames(fProject, aName) do
  begin
    lFiles := fBatch.FindSdkSources(lName.TargetName);
    if Length(lFiles) > 0 then
    begin
      aFileName := lFiles[0];
      Exit(True);
    end;
  end;
  if fSdkBinaries = nil then
  begin
    fSdkBinaries := TDictionary<string, string>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
    // This inventory lasts only for this identity computation. Every
    // selected file is still witnessed by this capture.
    fSdkDirectories := fBatch.SdkDirectories;
  end;
  for lName in TDelphiSemanticUnitResolver.CandidateNames(fProject, aName) do
  begin
    if not fSdkBinaries.TryGetValue(lName.TargetName, aFileName) then
    begin
      aFileName := '';
      for lDirectory in fSdkDirectories do
      begin
        lCandidate := TPath.Combine(lDirectory, lName.TargetName + '.dcu');
        if fBatch.Inputs.FileExists(lCandidate) then
        begin
          aFileName := lCandidate;
          Break;
        end;
      end;
      fSdkBinaries.Add(lName.TargetName, aFileName);
    end;
    if aFileName <> '' then
      Exit(True);
  end;
  Result := False;
end;

procedure TPossibleSourceCapture.SdkBoundary(const aName, aFileName, aOwnerFileName: string);
var
  lDiagnostic: TDelphiSemanticModelDiagnostic;
begin
  ObserveCandidate(aFileName);
  fResult.Identity := fResult.Identity + #10 + aName + '|installed-sdk|' + LowerCase(aFileName);
  lDiagnostic := Default(TDelphiSemanticModelDiagnostic);
  lDiagnostic.Code := 'POSSIBLE_UNIT_SDK_BOUNDARY';
  lDiagnostic.Message := aName + ' resolves to installed SDK ' + aFileName +
    '; cannot-reference-project-code (any platform).';
  lDiagnostic.FileName := aOwnerFileName;
  fDiagnostics.Add(lDiagnostic);
end;

function TPossibleSourceCapture.TrySdkAlias(const aName: string; out aTarget: string): Boolean;
const
  cAliases = '-aWinTypes=Windows;WinProcs=Windows;DbiProcs=BDE;DbiTypes=BDE;DbiErrs=BDE';
var
  lAlias, lRelative, lConfig, lPlatform, lExpected: string;
  lNames: TArray<TUnitCandidateName>;
  lLines: TArray<string>;
begin
  aTarget := '';
  if fOptions.InstalledSdkRoot = '' then
    Exit(False);
  // Explicit project aliases, including an unresolved target, take precedence.
  lNames := TDelphiSemanticUnitResolver.CandidateNames(fProject, aName);
  if (Length(lNames) = 0) or (lNames[0].MatchKind = 'alias') then
    Exit(False);
  for lAlias in Copy(cAliases, 3, MaxInt).Split([';']) do
    if SameText(Copy(lAlias, 1, Pos('=', lAlias) - 1), aName) then
      aTarget := Copy(lAlias, Pos('=', lAlias) + 1, MaxInt);
  if aTarget = '' then
    Exit(False);
  // Recognize only the observed Delphi 23 SDK defaults, not arbitrary cfg syntax.
  // Every compiler host must agree; changed/missing cfg bytes invalidate reuse.
  for lRelative in [TPath.Combine('bin', 'dcc32.cfg'), TPath.Combine('bin64', 'dcc32.cfg'),
    TPath.Combine('bin64', 'dcc64.cfg')] do
  begin
    lConfig := TPath.Combine(fOptions.InstalledSdkRoot, lRelative);
    ObserveCandidate(lConfig);
    if not fBatch.Inputs.FileExists(lConfig) then
      Exit(False);
    lLines := fBatch.Inputs.ReadAllLines(lConfig);
    lPlatform := 'win32';
    if EndsText('dcc64.cfg', lRelative) then
      lPlatform := 'win64';
    lExpected := '-u"' + CombinePath([fOptions.InstalledSdkRoot, 'lib', lPlatform, 'release']) + '"';
    if (Length(lLines) <> 2) or (Trim(lLines[0]) <> cAliases) or
      not SameText(Trim(lLines[1]), lExpected) then
      Exit(False);
  end;
  Result := True;
end;

function TPossibleSourceCapture.ResolveProjectUnit(const aName: string):
  TDelphiSemanticUnitResolutionResult;
var
  lName: TUnitCandidateName;
  lPath, lCandidate, lExtension: string;
begin
  // Witness every candidate consulted by the shared resolver, including absences.
  for lName in TDelphiSemanticUnitResolver.CandidateNames(fProject, aName) do
    for lPath in fProject.SourceLookupPaths do
      for lExtension in ['.pas', '.dcu'] do
        ObserveCandidate(TPath.Combine(lPath, lName.TargetName + lExtension));
  for lCandidate in fProject.SourceFileNames do
    if SameText(TPath.GetFileNameWithoutExtension(lCandidate), aName) then
      ObserveCandidate(lCandidate);
  Result := fBatch.Resolve(fProject, aName);
  fResult.Identity := fResult.Identity + #10 + aName + '|' + Result.Status +
    '|' + LowerCase(Result.FileName);
end;

function TPossibleSourceCapture.HasAlternateProjectSource(const aName, aOwner, aSelected: string): Boolean;
var
  lFile: TDelphiSemanticLookupCandidate;
  lFiles: TArray<TDelphiSemanticLookupCandidate>;
  lPath, lCandidate: string;
  lProject: TDelphiSemanticProjectInfo;
  lPaths, lFileNames: TArray<string>;
  lDirectory: TDelphiSemanticSourceText;
  lIndex, lPathIndex: Integer;
begin
  Result := False;
  lProject := fProject;
  lProject.UnitScopeNames := lProject.UnitScopeNames + fOptions.PossibleUnitScopeNames;
  fLookup.BeginCall;
  lFiles := fLookup.Candidates(TDelphiSemanticUnitResolver.CandidateNames(lProject, aName));
  lPaths := fLookup.Paths;
  for lPathIndex := 0 to High(lPaths) do
  begin
    lPath := lPaths[lPathIndex];
    if lPath = '<alternate-alias-unverified>' then
    begin
      Gap('POSSIBLE_UNIT_SOURCE_UNAVAILABLE', aOwner, 0,
        'Import: ' + aName + '; alternate configuration/platform unit aliases vary.');
      Exit(True);
    end;
    if lPath = '<alternate-library-unverified>' then
    begin
      Gap('POSSIBLE_UNIT_SOURCE_UNAVAILABLE', aOwner, 0,
        'Import: ' + aName + '; alternate configuration/platform IDE library is unavailable.');
      Exit(True);
    end;
    // SDK directories cannot introduce project references. Test the directory
    // once, rather than canonicalizing every possible scoped filename there.
    if fLookup.IsSdkPath(lPathIndex) then
      Continue;
    if not fDirectoryFiles.TryGetValue(lPath, lFileNames) then
    begin
      try
        lDirectory := fBatch.Inputs.DirectoryObservation(lPath, lFileNames);
      except
        on E: Exception do
        begin
          Gap('POSSIBLE_UNIT_SOURCE_UNAVAILABLE', aOwner, 0,
            'Import: ' + aName + '; alternate configuration/platform directory unreadable: ' +
            lPath + '; ' + E.Message);
          Exit(True);
        end;
      end;
      fDirectoryFiles.Add(lPath, lFileNames);
      fCandidateSources.Add(lDirectory);
    end;
    for lFile in lFiles do
    begin
      // The sorted inventory also witnesses new candidates at publication.
      if not TArray.BinarySearch<string>(lFileNames,
        lFile.Key, lIndex) then
        Continue;
      lCandidate := TPath.Combine(lPath, lFile.FileName);
      if SameText(TPath.GetFullPath(lCandidate), aSelected) then
        Continue;
      ObserveCandidate(lCandidate);
      if fBatch.Inputs.FileExists(lCandidate) then
      begin
        Gap('POSSIBLE_UNIT_SOURCE_UNAVAILABLE', aOwner, 0,
          'Import: ' + aName + '; alternate configuration/platform project source: ' + lCandidate);
        Exit(True);
      end;
    end;
  end;
end;

procedure TPossibleSourceCapture.ProjectImport(const aFileName: string);
var
  lFileName: string;
begin
  lFileName := TPath.GetFullPath(aFileName);
  if not fProjectImports.Contains(lFileName) then
    fProjectImports.Add(lFileName);
end;

procedure TPossibleSourceCapture.ImportUnit(const aName, aExplicit, aFileName,
  aCause: string; const aDepth: Integer);
var
  lCandidate, lLookupName, lAliasTarget: string;
  lResolution: TDelphiSemanticUnitResolutionResult;
begin
  if aExplicit <> '' then
  begin
    lCandidate := TPath.GetFullPath(TPath.Combine(ExtractFilePath(aFileName), aExplicit));
    ObserveCandidate(lCandidate);
    if IsSdkFile(lCandidate) and fBatch.Inputs.FileExists(lCandidate) then
      SdkBoundary(aName, lCandidate, aFileName)
    else
      ScanUnit(lCandidate, aCause, aDepth + 1);
    Exit;
  end;
  lLookupName := aName;
  lResolution := ResolveProjectUnit(lLookupName);
  if HasAlternateProjectSource(aName, aFileName, lResolution.FileName) then
    Exit;
  if not lResolution.Found and not lResolution.Ambiguous and
    TrySdkAlias(aName, lAliasTarget) then
  begin
    lLookupName := lAliasTarget;
    lResolution := ResolveProjectUnit(lLookupName);
    if HasAlternateProjectSource(lLookupName, aFileName, lResolution.FileName) then
      Exit;
  end;
  // Project/search-path selection always wins, including a project shadow or DCU.
  // Only a genuinely unresolved import may fall back to the installed SDK inventory.
  if not lResolution.Ambiguous and
    ((lResolution.Found and IsSdkFile(lResolution.FileName)) or
     (not lResolution.Found and TryFindSdkUnit(lLookupName, lCandidate))) then
  begin
    if lResolution.Found then
      lCandidate := lResolution.FileName;
    SdkBoundary(aName, lCandidate, aFileName);
    Exit;
  end;
  if not lResolution.Found or lResolution.Ambiguous or
    not SameText(TPath.GetExtension(lResolution.FileName), '.pas') then
  begin
    Gap('POSSIBLE_UNIT_SOURCE_UNAVAILABLE', aFileName, 0, 'Import: ' + aName +
      '; selection: ' + lResolution.Status + '; file: ' + lResolution.FileName);
    Exit;
  end;
  ScanUnit(lResolution.FileName, aCause, aDepth + 1);
end;

function TPossibleSourceCapture.ImportCause(const aPossible,
  aCurrent: TDelphiSemanticPreprocessResult; const aOffset: Integer;
  const aRootFileName, aInheritedCause: string;
  const aActivities: TDictionary<string, TPossibleImportState>; out aFileName: string): string;
var
  lSpan: TDelphiSemanticCopiedSourceSpan;
  lState: TPossibleImportState;
  lSourceOffset: Integer;
begin
  aFileName := aRootFileName;
  for lSpan in aPossible.CopiedSourceSpans do
    if (aOffset >= lSpan.OutputStartOffset) and (aOffset < lSpan.OutputEndOffset) then
    begin
      aFileName := lSpan.FileName;
      if aInheritedCause <> '' then
        Exit(aInheritedCause);
      lSourceOffset := lSpan.SourceStartOffset + aOffset - lSpan.OutputStartOffset;
      if not aActivities.TryGetValue(lSpan.FileName, lState) then
      begin
        lState.SourceText := lSpan.SourceText;
        lState.Activity := AggregateActivity(lSpan.SourceText, lSpan.FileName, aCurrent);
        lState.ScanSource := TDelphiSemanticSourceConditionals.SourceForScan(lSpan.SourceText, lState.Activity);
        aActivities.Add(lSpan.FileName, lState);
      end;
      if lState.SourceText <> lSpan.SourceText then
        Break;
      if TDelphiSemanticSourceConditionals.UnknownAtOffset(lSpan.SourceText, lState.Activity,
        lSourceOffset) then
        Exit('unverified-condition');
      if (lSourceOffset < 1) or (lSourceOffset > Length(lState.ScanSource)) then
        Break;
      if lState.ScanSource[lSourceOffset] <> lSpan.SourceText[lSourceOffset] then
        Exit('occurrence-in-inactive-configuration');
      Exit('');
    end;
  Gap('POSSIBLE_SOURCE_COVERAGE_UNAVAILABLE', aRootFileName, 0, 'Import source mapping unavailable.');
  Result := 'unverified-condition';
end;

procedure TPossibleSourceCapture.ScanImports(const aPossible,
  aCurrent: TDelphiSemanticPreprocessResult; const aRootFileName, aInheritedCause: string;
  const aDepth: Integer);
var
  lLexer: TmwBasePasLex;
  lActivities, lNeutralActivities: TDictionary<string, TPossibleImportState>;
  lName, lExplicit, lCause, lFileName, lNeutralFileName: string;
  lInUses: Boolean;
  lPrevious: TptTokenKind;
  lOffset, lDiagnosticStart, lIndex, lOrder: Integer;
  lSection: string;
  lFact: TDelphiSemanticImportFact;
  lResolution: TDelphiSemanticUnitResolutionResult;
begin
  lActivities := TDictionary<string, TPossibleImportState>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
  lNeutralActivities := TDictionary<string, TPossibleImportState>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
  lLexer := TmwBasePasLex.Create;
  try
    lLexer.UseDefines := False;
    // Expanded text preserves uses fragments supplied by includes. Copied spans
    // map each import back to its physical source and current conditional activity.
    lLexer.Origin := aPossible.OutputText;
    lLexer.NextNoJunk;
    lInUses := False;
    lSection := 'interface';
    lPrevious := ptNull;
    lOrder := 0;
    while lLexer.TokenID <> ptNull do
    begin
      if lLexer.TokenID = ptImplementation then
        lSection := 'implementation';
      // Directives are trivia at clause boundaries. Keep the structural-token
      // guard so prose in unsupported inactive branches cannot invent imports.
      if (lLexer.TokenID in [ptUses, ptContains]) and
        (lPrevious in [ptNull, ptInterface, ptImplementation, ptSemiColon]) then
        lInUses := True
      else if lLexer.TokenID = ptSemiColon then
        lInUses := False
      else if lInUses and (lLexer.TokenID = ptIdentifier) then
      begin
        lOffset := lLexer.TokenPos + 1;
        lName := lLexer.Token;
        lLexer.NextNoJunk;
        while lLexer.TokenID = ptPoint do
        begin
          lLexer.NextNoJunk;
          if lLexer.TokenID <> ptIdentifier then
          begin
            Gap('POSSIBLE_UNIT_SOURCE_UNAVAILABLE', aRootFileName, 0);
            Break;
          end;
          lName := lName + '.' + lLexer.Token;
          lLexer.NextNoJunk;
        end;
        lExplicit := '';
        if lLexer.TokenID = ptIn then
        begin
          lLexer.NextNoJunk;
          if lLexer.TokenID = ptStringConst then
          begin
            lExplicit := Copy(lLexer.Token, 2, Length(lLexer.Token) - 2);
            lLexer.NextNoJunk;
          end else
            Gap('POSSIBLE_UNIT_SOURCE_UNAVAILABLE', aRootFileName, 0);
        end;
        lCause := ImportCause(aPossible, aCurrent, lOffset, aRootFileName, aInheritedCause, lActivities, lFileName);
        lDiagnosticStart := fDiagnostics.Count;
        lResolution := fBatch.Resolve(fProject, lName);
        lFact := Default(TDelphiSemanticImportFact);
        lFact.OwnerFileName := aRootFileName;
        lFact.Name := lName;
        lFact.TargetFileName := lResolution.FileName;
        if lExplicit <> '' then
          lFact.TargetFileName := TPath.GetFullPath(TPath.Combine(ExtractFilePath(lFileName), lExplicit));
        lFact.SdkBoundary := lResolution.Found and IsSdkFile(lResolution.FileName);
        lFact.SectionKind := lSection;
        lFact.Cause := lCause;
        // A selected active provider is not necessarily visible in every build.
        // Uses-order exemptions require configuration-neutral activity proof.
        lFact.Unconditional := ImportCause(aPossible, aPossible, lOffset, aRootFileName,
          aInheritedCause, lNeutralActivities, lNeutralFileName) = '';
        lFact.OrderIndex := lOrder;
        Inc(lOrder);
        if lCause <> '' then
          ImportUnit(lName, lExplicit, lFileName, lCause, aDepth)
        else if lExplicit <> '' then
          ProjectImport(TPath.GetFullPath(TPath.Combine(ExtractFilePath(lFileName), lExplicit)))
        else begin
          // Selected project models already own these bytes. Retain the edge
          // without rescanning their references or expanding installed SDK units.
          HasAlternateProjectSource(lName, lFileName, lResolution.FileName);
          if not lResolution.Found or lResolution.Ambiguous or
            not SameText(TPath.GetExtension(lResolution.FileName), '.pas') then
            // Selected missing/binary imports need typed gap provenance too.
            ImportUnit(lName, '', lFileName, '', aDepth)
          else if not IsSdkFile(lResolution.FileName) then
            ProjectImport(lResolution.FileName);
        end;
        for lIndex := lDiagnosticStart to fDiagnostics.Count - 1 do
          if SameText(fDiagnostics[lIndex].Code, 'POSSIBLE_UNIT_SOURCE_UNAVAILABLE') and
            SameText(fDiagnostics[lIndex].FileName, lFileName) then
          begin
            lFact.GapReason := 'possible-unit-source-unavailable';
            lFact.ResolutionVaries := lFact.ResolutionVaries or
              ContainsText(fDiagnostics[lIndex].Message, 'alternate configuration/platform');
          end;
        for lIndex := lDiagnosticStart to fDiagnostics.Count - 1 do
          if SameText(fDiagnostics[lIndex].Code, 'POSSIBLE_UNIT_SDK_BOUNDARY') and
            StartsText(lName + ' resolves to installed SDK ', fDiagnostics[lIndex].Message) then
            lFact.SdkBoundary := True;
        if lCause = '' then
          // Active import uncertainty belongs to typed provenance. It still
          // blocks affected rename/usage names, without discarding selected AST
          // declarations that consistency can follow to an unresolved external type.
          for lIndex := fDiagnostics.Count - 1 downto lDiagnosticStart do
            if MatchText(fDiagnostics[lIndex].Code,
              ['POSSIBLE_UNIT_SDK_BOUNDARY', 'POSSIBLE_UNIT_SOURCE_UNAVAILABLE']) then
              fDiagnostics.Delete(lIndex);
        fImportFacts.Add(lFact);
        lPrevious := ptIdentifier;
        Continue;
      end;
      if not lLexer.IsCompilerDirective then
        lPrevious := lLexer.TokenID;
      lLexer.NextNoJunk;
    end;
  finally
    lLexer.Free;
    lNeutralActivities.Free;
    lActivities.Free;
  end;
end;

procedure TPossibleSourceCapture.ScanFile(const aSource, aFileName, aPossible,
  aCurrent, aInheritedCause: string; const aDepth: Integer; const aRoot: Boolean);
var
  lLexer: TmwBasePasLex;
  lPossibleSource, lCurrentSource, lCause: string;
  lReference: TDelphiSemanticReference;
  lOffset, lScanned, lLine, lLineStart: Integer;
begin
  if not fCollectReferences or (aRoot and (aInheritedCause = '')) then
    Exit;
  lPossibleSource := TDelphiSemanticSourceConditionals.SourceForScan(aSource, aPossible);
  lCurrentSource := TDelphiSemanticSourceConditionals.SourceForScan(aSource, aCurrent);
  lLexer := TmwBasePasLex.Create;
  try
    lLexer.UseDefines := False;
    lLexer.Origin := lPossibleSource;
    lScanned := 1;
    lLine := 1;
    lLineStart := 1;
    while lLexer.TokenID <> ptNull do
    begin
      if lLexer.TokenID = ptIdentifier then
      begin
        lOffset := lLexer.TokenPos + 1;
        while lScanned < lOffset do
        begin
          if aSource[lScanned] = #10 then
          begin
            Inc(lLine);
            lLineStart := lScanned + 1;
          end;
          Inc(lScanned);
        end;
        lCause := aInheritedCause;
        if lCause = '' then
          if TDelphiSemanticSourceConditionals.UnknownAtOffset(aSource, aCurrent, lOffset) then
            lCause := 'unverified-condition'
          else if lCurrentSource[lOffset] <> aSource[lOffset] then
            lCause := 'occurrence-in-inactive-configuration'
          else
            lCause := 'possible-source-occurrence';
        if lCause = 'possible-source-occurrence' then
        begin
          lLexer.Next;
          Continue;
        end;
        lReference := Default(TDelphiSemanticReference);
        lReference.Name := lLexer.Token;
        if StartsText('&', lReference.Name) then
          Delete(lReference.Name, 1, 1);
        lReference.FileName := aFileName;
        lReference.Line := lLine;
        lReference.Column := lOffset - lLineStart + 1;
        lReference.Offset := lOffset;
        lReference.EndOffset := lOffset + lLexer.TokenLen;
        lReference.Role := lCause;
        fReferences.Add(lReference);
      end;
      lLexer.Next;
    end;
  finally
    lLexer.Free;
  end;
end;

procedure TPossibleSourceCapture.ScanPreprocessed(const aPossible,
  aCurrent: TDelphiSemanticPreprocessResult; const aRootFileName, aCause: string;
  const aDepth: Integer);
var
  lSource: TDelphiSemanticSourceText;
  lInclude: TDelphiSemanticIncludeFile;
  lDiagnostic: TDelphiSemanticPreprocessDiagnostic;
begin
  MergeSources(aPossible.SourceObservations);
  ScanImports(aPossible, aCurrent, aRootFileName, aCause, aDepth);
  fResult.Identity := fResult.Identity + #10 + aPossible.IncludeGraphHash;
  for lDiagnostic in aPossible.Diagnostics do
    if SameText(lDiagnostic.Code, 'INCLUDE_FILE_NOT_FOUND') then
      Gap(lDiagnostic.Code, lDiagnostic.FileName, lDiagnostic.Line);
  if not aPossible.ActivityEvidenceAvailable then
    Gap('POSSIBLE_SOURCE_COVERAGE_UNAVAILABLE', aRootFileName, 0);
  if (aPossible.SourceObservations <> nil) and
    aPossible.SourceObservations.TryFind(aRootFileName, lSource) then
    ScanFile(lSource.Text, aRootFileName, AggregateActivity(lSource.Text, aRootFileName, aPossible),
      AggregateActivity(lSource.Text, aRootFileName, aCurrent), aCause, aDepth, True);
  for lInclude in aPossible.Includes do
    if (aPossible.SourceObservations <> nil) and
      aPossible.SourceObservations.TryFind(lInclude.FileName, lSource) then
      ScanFile(lSource.Text, lSource.FileName, AggregateActivity(lSource.Text, lSource.FileName, aPossible),
        AggregateActivity(lSource.Text, lSource.FileName, aCurrent), aCause, aDepth, False);
end;

procedure TPossibleSourceCapture.ScanUnit(const aFileName, aCause: string;
  const aDepth: Integer);
var
  lFileName, lKnown: string;
  lPossible: TDelphiSemanticPreprocessResult;
begin
  lFileName := TPath.GetFullPath(aFileName);
  ProjectImport(lFileName);
  for lKnown in fOptions.ProjectSourceFileNames do
    if SameText(lFileName, TPath.GetFullPath(lKnown)) then
      Exit;
  if fVisited.Contains(lFileName) then
    Exit;
  if (aDepth > 32) or (fVisited.Count >= 256) then
  begin
    Gap('POSSIBLE_SOURCE_COVERAGE_UNAVAILABLE', lFileName, 0);
    Exit;
  end;
  fVisited.Add(lFileName);
  if not fBatch.Inputs.FileExists(lFileName) then
  begin
    Gap('POSSIBLE_UNIT_SOURCE_UNAVAILABLE', lFileName, 0);
    Exit;
  end;
  lPossible := fBatch.PreprocessNeutral(lFileName);
  ScanPreprocessed(lPossible, Default(TDelphiSemanticPreprocessResult), lFileName, aCause, aDepth);
end;

function TPossibleSourceCapture.Execute(const aNormal: TDelphiSemanticPreprocessResult):
  TDelphiSemanticPossibleSources;
var
  lPossible: TDelphiSemanticPreprocessResult;
  lRoot: TDelphiSemanticSourceText;
begin
  fResult.Sources := aNormal.SourceObservations;
  fVisited.Add(TPath.GetFullPath(fOptions.SourceFileName));
  lPossible := fBatch.PreprocessNeutral(fOptions.SourceFileName);
  ScanPreprocessed(lPossible, aNormal, TPath.GetFullPath(fOptions.SourceFileName), '', 0);
  if (lPossible.SourceObservations <> nil) and
    lPossible.SourceObservations.TryFind(fOptions.SourceFileName, lRoot) then
    fResult.RootActivity := AggregateActivity(lRoot.Text, lRoot.FileName, lPossible);
  if fCandidateSources.Count > 0 then
    MergeSources(TDelphiSemanticSourceEvidence.FromItems(fCandidateSources.ToArray));
  fResult.ProjectUnitImports := fProjectImports.ToArray;
  fResult.ImportFacts := fImportFacts.ToArray;
  fResult.References := fReferences.ToArray;
  fResult.Diagnostics := fDiagnostics.ToArray;
  fResult.Identity := THashSHA2.GetHashString(fResult.Identity);
  Result := fResult;
end;

function TDelphiSemanticPossibleSourceBatch.Capture(const aOptions: TDelphiSemanticModelOptions;
  const aNormal: TDelphiSemanticPreprocessResult; const aCollectReferences: Boolean):
  TDelphiSemanticPossibleSources;
var
  lCapture: TPossibleSourceCapture;
begin
  Result := Default(TDelphiSemanticPossibleSources);
  Result.Sources := aNormal.SourceObservations;
  // Project lean models still own possible imports. Standalone RTL declaration
  // profiles have no project membership graph and cannot reference project code.
  if aOptions.SelectedConfigurationOnly or aOptions.WithStatementsOnly or
    not aOptions.ProjectContextApplied or
    (aOptions.SkipReferenceExtraction and (Length(aOptions.ProjectSourceFileNames) = 0)) then
    Exit;
  lCapture := TPossibleSourceCapture.Create(aOptions, aCollectReferences, Self);
  try
    Result := lCapture.Execute(aNormal);
  finally
    lCapture.Free;
  end;
end;

class function TDelphiSemanticPossibleSources.Capture(const aOptions: TDelphiSemanticModelOptions;
  const aNormal: TDelphiSemanticPreprocessResult; const aCollectReferences: Boolean):
  TDelphiSemanticPossibleSources;
var
  lBatch: TDelphiSemanticPossibleSourceBatch;
begin
  lBatch := TDelphiSemanticPossibleSourceBatch.Create(aOptions, False);
  try
    Result := lBatch.Capture(aOptions, aNormal, aCollectReferences);
  finally
    lBatch.Free;
  end;
end;

end.
