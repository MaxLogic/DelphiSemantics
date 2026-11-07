unit Test.TypeVisibilityNative;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTypeVisibilityNativeTests = class
  public
    [Test]
    procedure FastCompilerComparison;
    [Test]
    procedure InterfaceLifetimeCompilerComparison;
    [Test]
    procedure QualifiedFallbackCompilerComparison;
    [Test]
    [TestCase('MSBuild certificate', 'certified')]
    [TestCase('Missing certificate', 'absent')]
    [TestCase('Unexpanded certificate', 'unresolved')]
    procedure IncludePathEvidenceSafety(const aEvidence: string);
  end;

  [TestFixture]
  TTypeVisibilityNativeSlowTests = class
  public
    [Test]
    [Category('Slow')]
    procedure FullCompilerComparison;
  end;

implementation

uses
  System.Diagnostics, System.IOUtils, System.JSON, System.SysUtils,
  Winapi.Windows,
  FireDAC.Comp.Client, FireDAC.Phys.SQLite,
  DelphiSemantics.Api, DelphiSemantics.Api.ProjectOptions,
  DelphiSemantics.Api.RemoveWith.Compatibility, DelphiSemantics.Api.WithBinding,
  DelphiSemantics.CompilerProfile, DelphiSemantics.Model.Extract, DelphiSemantics.ProjectContext,
  DelphiSemantics.ProjectSession, DelphiSemantics.RemoveWithPlan,
  DelphiSemantics.Snapshot, DelphiSemantics.Snapshot.Builder,
  DelphiSemantics.Snapshot.Cache.Sqlite, DelphiSemantics.Snapshot.RemoveWith,
  Test.CompilerIncludeCapture, Test.Support;

function RunReference(const aArguments, aLogFile: string;
  const aScript: string = 'ds719-native-reference.py'): Cardinal;
var
  lStartup: TStartupInfo;
  lProcess: TProcessInformation;
  lSecurity: TSecurityAttributes;
  lHandle: THandle;
  lCommand, lPython: string;
begin
  lPython := GetEnvironmentVariable('DS719_PYTHON');
  if lPython = '' then
    lPython := 'python.exe';
  lCommand := '"' + lPython + '" -B "' +
    TPath.Combine(RepoRoot, 'tests\scripts\' + aScript) + '" ' + aArguments;
  lSecurity := Default(TSecurityAttributes);
  lSecurity.nLength := SizeOf(lSecurity);
  lSecurity.bInheritHandle := True;
  lHandle := CreateFile(PChar(aLogFile), GENERIC_WRITE, FILE_SHARE_READ,
    @lSecurity, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, 0);
  if lHandle = INVALID_HANDLE_VALUE then
    RaiseLastOSError;
  try
    lStartup := Default(TStartupInfo);
    lStartup.cb := SizeOf(lStartup);
    lStartup.dwFlags := STARTF_USESTDHANDLES;
    lStartup.hStdOutput := lHandle;
    lStartup.hStdError := lHandle;
    lStartup.hStdInput := GetStdHandle(STD_INPUT_HANDLE);
    lProcess := Default(TProcessInformation);
    UniqueString(lCommand);
    if not CreateProcess(PChar(lPython), PChar(lCommand), nil, nil, True, CREATE_NO_WINDOW,
      nil, PChar(RepoRoot), lStartup, lProcess) then
      RaiseLastOSError;
    try
      if WaitForSingleObject(lProcess.hProcess, 3600000) <> WAIT_OBJECT_0 then
      begin
        TerminateProcess(lProcess.hProcess, 124);
        WaitForSingleObject(lProcess.hProcess, 30000);
        raise Exception.Create('Native comparison timed out: ' + aLogFile);
      end;
      if not GetExitCodeProcess(lProcess.hProcess, Result) then
        RaiseLastOSError;
    finally
      CloseHandle(lProcess.hThread);
      CloseHandle(lProcess.hProcess);
    end;
  finally
    CloseHandle(lHandle);
  end;
end;

procedure WriteRoute(const aFileName: string; const aPlan: TDelphiSemanticRemoveWithPlan;
  const aFacts: TDelphiSemanticProjectWithBindingFacts;
  const aSnapshot: TDelphiProjectSnapshot = nil);
var
  lJson, lStatement, lEdit, lSelector, lModelJson, lDeclarationJson: TJSONObject;
  lStatements, lEdits, lSelectors, lModels, lDiagnostics, lDeclarations: TJSONArray;
  lSelectorIndex: Integer;
  lReferences, lDiagnosticCodes: TJSONArray;
  lReference: TJSONObject;
begin
  lJson := TJSONObject.Create;
  try
    lStatements := TJSONArray.Create;
    lJson.AddPair('statements', lStatements);
    for var lItem in aPlan.FinalStatements do
    begin
      lStatement := TJSONObject.Create;
      lStatements.AddElement(lStatement);
      lStatement.AddPair('file', lItem.FileName);
      lStatement.AddPair('id', lItem.StatementId);
      lStatement.AddPair('sl', TJSONNumber.Create(lItem.Range.StartLine));
      lStatement.AddPair('sc', TJSONNumber.Create(lItem.Range.StartColumn));
      lStatement.AddPair('el', TJSONNumber.Create(lItem.Range.EndLine));
      lStatement.AddPair('ec', TJSONNumber.Create(lItem.Range.EndColumn));
      lStatement.AddPair('status', lItem.Status);
      lStatement.AddPair('reason', lItem.Reason);
      lStatement.AddPair('safety', lItem.SafetyReason);
      // DS-719 A-369/A-371: export the full refusal publication boundary.
      lStatement.AddPair('replacement', lItem.ReplacementText);
      lStatement.AddPair('temp_count', TJSONNumber.Create(Length(lItem.Temps)));
      lStatement.AddPair('recipe_status', lItem.RewriteRecipe.Status);
      lStatement.AddPair('recipe_replacement', lItem.RewriteRecipe.ReplacementText);
      lStatement.AddPair('recipe_edit_count', TJSONNumber.Create(Length(lItem.RewriteRecipe.TextEdits)));
      lStatement.AddPair('recipe_temp_count', TJSONNumber.Create(Length(lItem.RewriteRecipe.TempDeclarations)));
      lEdits := TJSONArray.Create;
      lStatement.AddPair('edits', lEdits);
      for var lTextEdit in lItem.Edits do
      begin
        lEdit := TJSONObject.Create;
        lEdits.AddElement(lEdit);
        lEdit.AddPair('file', lTextEdit.FileName);
        lEdit.AddPair('sl', TJSONNumber.Create(lTextEdit.Range.StartLine));
        lEdit.AddPair('sc', TJSONNumber.Create(lTextEdit.Range.StartColumn));
        lEdit.AddPair('el', TJSONNumber.Create(lTextEdit.Range.EndLine));
        lEdit.AddPair('ec', TJSONNumber.Create(lTextEdit.Range.EndColumn));
        lEdit.AddPair('text', lTextEdit.ReplacementText);
      end;
    end;
    // Covered children have no final DTO. Export their explicit parent identity
    // so the oracle proves coverage and checks every absorbed receiver too.
    lEdits := TJSONArray.Create;
    lJson.AddPair('covered', lEdits);
    for var lItem in aPlan.Statements do
      if lItem.CoveredByStatementId <> '' then
      begin
        lStatement := TJSONObject.Create;
        lEdits.AddElement(lStatement);
        lStatement.AddPair('file', lItem.FileName);
        lStatement.AddPair('sl', TJSONNumber.Create(lItem.Range.StartLine));
        lStatement.AddPair('sc', TJSONNumber.Create(lItem.Range.StartColumn));
        lStatement.AddPair('el', TJSONNumber.Create(lItem.Range.EndLine));
        lStatement.AddPair('ec', TJSONNumber.Create(lItem.Range.EndColumn));
        lStatement.AddPair('parent', lItem.CoveredByStatementId);
        lStatement.AddPair('reason', lItem.Reason);
      end;
    lReferences := TJSONArray.Create;
    lJson.AddPair('references', lReferences);
    if aSnapshot <> nil then
    begin
      for var lBinding in aSnapshot.RemoveWithPlanningFacts.Bindings do
        for var lItem in lBinding.References do
        begin
          lReference := TJSONObject.Create;
          lReferences.AddElement(lReference);
          lReference.AddPair('name', aSnapshot.ExactTextOf(lItem.NameId));
          lReference.AddPair('classification', aSnapshot.ExactTextOf(lItem.ClassificationId));
          lReference.AddPair('code', aSnapshot.ExactTextOf(lItem.ReasonCodeId));
        end;
    end else
      for var lBinding in aFacts.Bindings do
        for var lItem in lBinding.References do
        begin
          lReference := TJSONObject.Create;
          lReferences.AddElement(lReference);
          lReference.AddPair('name', lItem.Name);
          lReference.AddPair('classification', lItem.Classification);
          lReference.AddPair('code', lItem.ReasonCode);
        end;
    lSelectors := TJSONArray.Create;
    lJson.AddPair('selectors', lSelectors);
    lModels := TJSONArray.Create;
    lJson.AddPair('models', lModels);
    for var lModel in aFacts.UnitModels do
    begin
      lModelJson := TJSONObject.Create;
      lModels.AddElement(lModelJson);
      lModelJson.AddPair('unit', lModel.UnitName);
      lModelJson.AddPair('success', TJSONBool.Create(lModel.Success));
      lModelJson.AddPair('directive_scan_count', TJSONNumber.Create(lModel.DirectiveFacts.ScanCount));
      lModelJson.AddPair('directive_scan_characters', TJSONNumber.Create(lModel.DirectiveFacts.CharactersScanned));
      lModelJson.AddPair('directive_span_count', TJSONNumber.Create(Length(lModel.DirectiveFacts.Spans)));
      lModelJson.AddPair('directive_import_cause', lModel.DirectiveFacts.ImportCause);
      lModelJson.AddPair('directive_count_cause', lModel.DirectiveFacts.NameCause('Count'));
      lModelJson.AddPair('define_complete', TJSONBool.Create(lModel.DefineEvidenceComplete));
      lModelJson.AddPair('skipped_include_count', TJSONNumber.Create(Length(lModel.SkippedIncludeFileNames)));
      lDeclarations := TJSONArray.Create;
      lModelJson.AddPair('declarations', lDeclarations);
      for var lDeclaration in TDelphiSemanticUnitModelExtractorImpl.AnonymousRecordAbsenceModel(lModel).Declarations do
      begin
        lDeclarationJson := TJSONObject.Create;
        lDeclarations.AddElement(lDeclarationJson);
        lDeclarationJson.AddPair('name', lDeclaration.Name);
        lDeclarationJson.AddPair('kind', lDeclaration.Kind);
        lDeclarationJson.AddPair('line', TJSONNumber.Create(lDeclaration.Line));
        lDeclarationJson.AddPair('column', TJSONNumber.Create(lDeclaration.Column));
      end;
      lDiagnostics := TJSONArray.Create;
      lModelJson.AddPair('diagnostics', lDiagnostics);
      lDiagnosticCodes := TJSONArray.Create;
      lModelJson.AddPair('diagnostic_codes', lDiagnosticCodes);
      for var lDiagnostic in lModel.Diagnostics do
      begin
        lDiagnostics.Add(lDiagnostic.Message);
        lDiagnosticCodes.Add(lDiagnostic.Code);
      end;
    end;
    if aSnapshot <> nil then
    begin
      for var lBinding in aSnapshot.RemoveWithPlanningFacts.Bindings do
      begin
        lSelectorIndex := 0;
        for var lItem in lBinding.Selectors do
        begin
          lSelector := TJSONObject.Create;
          lSelectors.AddElement(lSelector);
          lSelector.AddPair('index', TJSONNumber.Create(lSelectorIndex));
          Inc(lSelectorIndex);
          lSelector.AddPair('text', aSnapshot.ExactTextOf(lItem.SelectorTextId));
          lSelector.AddPair('file', aSnapshot.ExactTextOf(lBinding.FileNameId));
          lSelector.AddPair('line', TJSONNumber.Create(lBinding.Line));
          lSelector.AddPair('column', TJSONNumber.Create(lBinding.Column));
          lSelector.AddPair('type_name', aSnapshot.ExactTextOf(lItem.TypeNameId));
          lSelector.AddPair('source_unit', aSnapshot.ExactTextOf(lBinding.UnitNameId));
          lSelector.AddPair('name', aSnapshot.ExactTextOf(lItem.TypeIdentity.NameId));
          lSelector.AddPair('unit', aSnapshot.ExactTextOf(lItem.TypeIdentity.UnitNameId));
          lSelector.AddPair('status', aSnapshot.ExactTextOf(lItem.StatusId));
          lSelector.AddPair('code', aSnapshot.ExactTextOf(lItem.ReasonCodeId));
          lSelector.AddPair('capture', aSnapshot.ExactTextOf(lItem.CaptureTypeStatusId));
        end;
      end;
    end else
    for var lBinding in aFacts.Bindings do
    begin
      lSelectorIndex := 0;
      for var lItem in lBinding.Selectors do
      begin
        lSelector := TJSONObject.Create;
        lSelectors.AddElement(lSelector);
        lSelector.AddPair('index', TJSONNumber.Create(lSelectorIndex));
        Inc(lSelectorIndex);
        lSelector.AddPair('text', lItem.SelectorText);
        lSelector.AddPair('file', lBinding.FileName);
        lSelector.AddPair('line', TJSONNumber.Create(lBinding.Line));
        lSelector.AddPair('column', TJSONNumber.Create(lBinding.Column));
        lSelector.AddPair('type_name', lItem.TypeName);
        lSelector.AddPair('source_unit', lBinding.UnitName);
        lSelector.AddPair('name', lItem.TypeIdentity.Name);
        lSelector.AddPair('unit', lItem.TypeIdentity.UnitName);
        lSelector.AddPair('status', lItem.Status);
        lSelector.AddPair('code', lItem.ReasonCode);
        lSelector.AddPair('capture', lItem.CaptureTypeStatus);
      end;
    end;
    TFile.WriteAllText(aFileName, lJson.ToJSON, TEncoding.UTF8);
  finally
    lJson.Free;
  end;
end;

function LoadSessionSnapshot(const aFileName: string): TDelphiProjectSnapshot;
var
  lCache: TDelphiSemanticSnapshotSqliteCache;
  lConnection: TFDConnection;
  lIdentity: TDelphiSemanticSnapshotCacheIdentity;
  lQuery: TFDQuery;
begin
  Result := nil;
  lIdentity := Default(TDelphiSemanticSnapshotCacheIdentity);
  lConnection := TFDConnection.Create(nil);
  try
    lQuery := TFDQuery.Create(nil);
    try
      lConnection.DriverName := 'SQLite';
      lConnection.Params.Values['Database'] := aFileName;
      lConnection.LoginPrompt := False;
      lQuery.Connection := lConnection;
      lQuery.Open('select cache_key, identity_key, source_file_name, file_hash, ' +
        'context_hash, include_graph_hash, schema_version ' +
        'from snapshot_project_remove_with_facts');
      Assert.IsFalse(lQuery.Eof, 'The session must persist its planning facts.');
      lIdentity.CacheKey := lQuery.Fields[0].AsWideString;
      lIdentity.IdentityKey := lQuery.Fields[1].AsWideString;
      lIdentity.SourceFileName := lQuery.Fields[2].AsWideString;
      lIdentity.FileHash := lQuery.Fields[3].AsWideString;
      lIdentity.ContextHash := lQuery.Fields[4].AsWideString;
      lIdentity.IncludeGraphHash := lQuery.Fields[5].AsWideString;
      lIdentity.SchemaVersion := lQuery.Fields[6].AsWideString;
      lQuery.Next;
      Assert.IsTrue(lQuery.Eof, 'The isolated case has exactly one cache identity.');
    finally
      lQuery.Free;
    end;
  finally
    lConnection.Free;
  end;
  lCache := TDelphiSemanticSnapshotSqliteCache.Create(aFileName);
  try
    Assert.IsTrue(lCache.TryLoadProjectRemoveWithPlanningFacts(lIdentity, Result));
  finally
    lCache.Free;
  end;
end;

procedure CheckCollisionDenial(const aFileName, aName: string);
var
  lJson: TJSONObject;
  lCount: Integer;
begin
  lJson := TJSONObject.ParseJSONValue(TFile.ReadAllText(aFileName)) as TJSONObject;
  try
    for var lSelector in lJson.GetValue<TJSONArray>('selectors') do
      Assert.AreEqual('resolved', lSelector.GetValue<string>('status'), aFileName);
    lCount := 0;
    for var lReference in lJson.GetValue<TJSONArray>('references') do
      if SameText(lReference.GetValue<string>('name'), aName) or
        (Pos(LowerCase(aName) + '[', LowerCase(lReference.GetValue<string>('name'))) = 1) then
      begin
        Inc(lCount);
        Assert.AreEqual('HELPER_COLLISION_UNVERIFIED', lReference.GetValue<string>('code'), aFileName);
      end;
    Assert.IsTrue(lCount > 0, 'The denied body reference must be stored: ' + aFileName);
    for var lStatement in lJson.GetValue<TJSONArray>('statements') do
    begin
      Assert.AreEqual('skipped', lStatement.GetValue<string>('status'), aFileName);
      Assert.AreEqual('HELPER_COLLISION_UNVERIFIED', lStatement.GetValue<string>('safety'), aFileName);
      Assert.AreEqual(0, lStatement.GetValue<TJSONArray>('edits').Count, aFileName);
    end;
  finally
    lJson.Free;
  end;
end;

procedure CaptureNativeDefines(var aOptions: TDelphiSemanticApiOptions);
begin
  // Finalize Delphi's managed function-result temporary before native builds
  // mutate this disposable project's output settings.
  aOptions.CompilerDefineEvidence := CaptureFixtureCompilerDefines(aOptions.ProjectFileName);
end;

procedure CompareCompiler(const aFull: Boolean; const aRegression: string = '';
  const aEvidence: string = '');
var
  lRoot, lRetainRoot, lArgument, lCaseRoot, lBds, lDenialName, lRouteFile, lScript: string;
  lPhase: Integer;
  lCases: TJSONArray;
  lOptions: TDelphiSemanticApiOptions;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lPlan: TDelphiSemanticRemoveWithPlan;
  lIdentity: TDelphiSemanticSnapshotCacheIdentity;
  lStored, lLoaded: TDelphiProjectSnapshot;
  lCache: TDelphiSemanticSnapshotSqliteCache;
  lProjectOptions: TDelphiSemanticOptions;
  lContext: TDelphiSemanticContextResult;
  lSession: TDelphiSemanticProjectSessionResult;
  lBuild: TDelphiSemanticRemoveWithPlanBuildResult;
  lExit: Cardinal;
  lWatch: TStopwatch;
begin
  lWatch := TStopwatch.StartNew;
  lScript := 'ds719-native-reference.py';
  if aRegression <> '' then
    lScript := 'ds754-native-reference.py';
  lRoot := GetEnvironmentVariable('DS719_NATIVE_ROOT');
  if lRoot = '' then
  begin
    lRetainRoot := GetEnvironmentVariable('DS719_NATIVE_RETAIN_ROOT');
    if lRetainRoot <> '' then
      // Each comparison gets its own caller-owned retained evidence directory.
      // Successful suite cleanup must not erase or overwrite native artifacts.
      lRoot := TPath.Combine(lRetainRoot, TPath.GetGUIDFileName(False))
    else
      lRoot := CreateTestTempRoot('ds719-native-comparison-temp');
  end;
  if aEvidence <> '' then
    lRoot := TPath.Combine(lRoot, aEvidence);
  TDirectory.CreateDirectory(lRoot);
  lArgument := 'generate "' + lRoot + '" --repo "' + RepoRoot + '"';
  if aFull then
    lArgument := lArgument + ' --full';
  if aRegression <> '' then
  begin
    lBds := TDelphiSemanticCompilerProfileBuilder.ResolveBdsRoot('23.0', '');
    lArgument := lArgument + ' --only ' + aRegression + ' --bds "' +
      ExcludeTrailingPathDelimiter(lBds) + '"';
  end;
  if aEvidence <> '' then
    lArgument := lArgument + ' --only "msbuild-include-P1,msbuild-include-P2" --include-evidence ' + aEvidence
  else if GetEnvironmentVariable('DS719_NATIVE_ONLY') <> '' then
    lArgument := lArgument + ' --only "' + GetEnvironmentVariable('DS719_NATIVE_ONLY') + '"';
  Assert.AreEqual<Cardinal>(0, RunReference(lArgument,
    TPath.Combine(lRoot, 'generate.log'), lScript), 'Generator failed: ' + lRoot);
  lCases := TJSONObject.ParseJSONValue(TFile.ReadAllText(
    TPath.Combine(lRoot, 'cases.json'))) as TJSONArray;
  try
    Assert.IsTrue(lCases.Count > 0);
    for var lCase in lCases do
    begin
      lCaseRoot := lCase.GetValue<string>('root');
      lOptions := Default(TDelphiSemanticApiOptions);
      lOptions.ProjectFileName := TPath.Combine(lCaseRoot, 'P.dproj');
      lOptions.DelphiVersion := '23.0';
      lOptions.Configuration := 'Debug';
      lOptions.Platform := 'Win64';
      if lCase.GetValue<TJSONValue>('caller_search_paths', nil) <> nil then
        for var lSearchPath in lCase.GetValue<TJSONArray>('caller_search_paths') do
          lOptions.SearchPaths := lOptions.SearchPaths + [lSearchPath.Value];
      if lCase.GetValue<TJSONValue>('caller_defines', nil) <> nil then
        for var lDefine in lCase.GetValue<TJSONArray>('caller_defines') do
          lOptions.Defines := lOptions.Defines + [lDefine.Value];
      if lCase.GetValue<TJSONValue>('compiler_include_search_path', nil) <> nil then
      begin
        lOptions.CompilerIncludeSearchPathProvided := True;
        lOptions.CompilerIncludeSearchPath := lCase.GetValue<string>('compiler_include_search_path');
      end;
      if aEvidence <> '' then
      begin
        lProjectOptions := ProjectOptionsFromApiOptions(lOptions);
        lContext := TDelphiSemanticProject.Load(lOptions.ProjectFileName, lProjectOptions);
        Assert.IsTrue(lContext.Success, lCaseRoot);
        if aEvidence = 'certified' then
          Assert.AreEqual('True', lContext.Project.PropertyValue('DSCompilerIncludePathsKnown'), lCaseRoot)
        else
        begin
          Assert.AreEqual('False', lContext.Project.PropertyValue('DSCompilerIncludePathsKnown'), lCaseRoot);
          Assert.AreEqual<Integer>(1, Length(lContext.Project.IncludePaths), lCaseRoot);
          Assert.AreEqual('<include-path-unproved>', lContext.Project.IncludePaths[0], lCaseRoot);
        end;
      end;
      if lCase.GetValue<string>('define_evidence', 'missing') <> 'missing' then
        CaptureNativeDefines(lOptions);
      lOptions.Cache.SqliteCacheFileName := TPath.Combine(lCaseRoot, 'session.sqlite');
      lDenialName := lCase.GetValue<string>('denial_reference', '');
      for lPhase := 0 to Ord(lDenialName <> '') do
      begin
      lFacts := TDelphiSemanticRemoveWithCompatibilityApi.BuildProjectWithBindingFacts(lOptions);
      for var i := 0 to 4 do
      begin
        // Explicit exclusions remain visible in the case manifest. Local type
        // cases now exercise all persisted routes after DS-763.
        if (i > 1) and (lCase.GetValue<TJSONValue>('excluded_routes', nil) <> nil) and
          (GetEnvironmentVariable('DS719_NATIVE_ALL_ROUTES') <> '1') then
          Continue;
        try
        if i = 0 then
        begin
          lPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWith(lFacts);
          WriteRoute(TPath.Combine(lCaseRoot, 'route-0.json'), lPlan, lFacts);
        end else if i = 1 then
        begin
          lStored := BuildCompatibilityRemoveWithPlanningSnapshotFromFacts(lFacts);
          try
            lPlan := TDelphiSemanticRemoveWithPlanner.Plan(lStored);
            WriteRoute(TPath.Combine(lCaseRoot, 'route-1.json'), lPlan, lFacts, lStored);
          finally
            lStored.Free;
          end;
        end else if i = 2 then
        begin
          lIdentity := Default(TDelphiSemanticSnapshotCacheIdentity);
          lIdentity.CacheKey := 'ds719-native';
          lIdentity.IdentityKey := lIdentity.CacheKey;
          lIdentity.SourceFileName := lOptions.ProjectFileName;
          lIdentity.FileHash := lFacts.ContextFingerprint;
          lIdentity.ContextHash := lFacts.ContextFingerprint;
          lIdentity.IncludeGraphHash := 'ds719-native';
          lIdentity.SchemaVersion := 'ds719-native';
          lStored := BuildCompatibilityRemoveWithPlanningSnapshotFromFacts(lFacts);
          lCache := TDelphiSemanticSnapshotSqliteCache.Create(TPath.Combine(lCaseRoot, 'standalone.sqlite'));
          try
            lCache.StoreProjectRemoveWithPlanningFacts(lIdentity, lStored, lFacts.Symbols);
            Assert.IsTrue(lCache.TryLoadProjectRemoveWithPlanningFacts(lIdentity, lLoaded));
            try
              lPlan := TDelphiSemanticRemoveWithPlanner.Plan(lLoaded);
              WriteRoute(TPath.Combine(lCaseRoot, 'route-2.json'), lPlan, lFacts, lLoaded);
            finally
              lLoaded.Free;
            end;
          finally
            lCache.Free;
            lStored.Free;
          end;
        end else begin
          lProjectOptions := ProjectOptionsFromApiOptions(lOptions);
          lSession := TDelphiSemanticProjectSession.Open(lProjectOptions);
          try
            Assert.IsTrue(lSession.Success, lCaseRoot);
            lBuild := lSession.Session.PlanRemoveWithResult;
            // Capture both session publications, including a failed warm-hit invariant.
            WriteRoute(TPath.Combine(lCaseRoot, Format('route-%d-published.json', [i])),
              lBuild.Plan, lFacts);
            if lPhase = 0 then
              Assert.AreEqual(i - 3, Integer(lBuild.SnapshotMetrics.SnapshotCacheHits))
            else
              Assert.AreEqual(1, Integer(lBuild.SnapshotMetrics.SnapshotCacheHits));
            lPlan := lBuild.Plan;
            lLoaded := LoadSessionSnapshot(lOptions.Cache.SqliteCacheFileName);
            try
              WriteRoute(TPath.Combine(lCaseRoot, Format('route-%d.json', [i])),
                lPlan, lFacts, lLoaded);
            finally
              lLoaded.Free;
            end;
          finally
            lSession.Session.Free;
          end;
        end;
        except
          on E: Exception do
          begin
            // A full measurement retains failed routes and continues all cases.
            // The comparator still fails missing route coverage.
            if GetEnvironmentVariable('DS719_NATIVE_ALL_ROUTES') <> '1' then
              raise;
            TFile.WriteAllText(TPath.Combine(lCaseRoot,
              Format('route-%d-error.txt', [i])), E.ClassName + ': ' + E.Message);
            Continue;
          end;
        end;
        if lDenialName <> '' then
        begin
          lRouteFile := TPath.Combine(lCaseRoot, Format('route-%d.json', [i]));
          CheckCollisionDenial(lRouteFile, lDenialName);
          TFile.Copy(lRouteFile, TPath.Combine(lCaseRoot,
            Format('phase-%d-route-%d.json', [lPhase, i])));
        end;
      end;
      end;
      Writeln('DS719 planned routes: ', lCase.GetValue<string>('name'));
    end;
  finally
    lCases.Free;
  end;
  // Native comparison writes only disposable fixture copies after planning.
  // Release this test's capture locks before compiler output isolation edits.
  lOptions.CompilerDefineEvidence := nil;
  lProjectOptions.CompilerDefineEvidence := nil;
  lFacts := Default(TDelphiSemanticProjectWithBindingFacts);
  lContext := Default(TDelphiSemanticContextResult);
  lBds := TDelphiSemanticCompilerProfileBuilder.ResolveBdsRoot('23.0', '');
  Assert.IsTrue(TFile.Exists(TPath.Combine(lBds, 'bin\dcc64.exe')), 'dcc64 unavailable');
  if aFull and (GetEnvironmentVariable('DS719_NATIVE_ONLY') = '') then
    Assert.AreEqual<Cardinal>(0, RunReference('challenge "' + lRoot + '" --bds "' +
      ExcludeTrailingPathDelimiter(lBds) + '"', TPath.Combine(lRoot, 'challenge.log')),
      'Comparator non-vacuity failed: ' + TPath.Combine(lRoot, 'comparator-mutations.json'));
  lExit := RunReference('compare "' + lRoot + '" --bds "' +
    ExcludeTrailingPathDelimiter(lBds) + '"', TPath.Combine(lRoot, 'compare.log'), lScript);
  Writeln('DS719 compiler comparison: ', lWatch.ElapsedMilliseconds, ' ms; ', lRoot);
  Assert.AreEqual<Cardinal>(0, lExit, 'Compiler comparison failures: ' +
    TPath.Combine(lRoot, 'comparison.json'));

end;

procedure TTypeVisibilityNativeTests.FastCompilerComparison;
begin
  CompareCompiler(False);
end;

procedure TTypeVisibilityNativeTests.InterfaceLifetimeCompilerComparison;
begin
  CompareCompiler(False, 'ds754');
end;

procedure TTypeVisibilityNativeTests.QualifiedFallbackCompilerComparison;
begin
  CompareCompiler(False, 'ds755');
end;

procedure TTypeVisibilityNativeTests.IncludePathEvidenceSafety(const aEvidence: string);
begin
  CompareCompiler(False, '', aEvidence);
end;

procedure TTypeVisibilityNativeSlowTests.FullCompilerComparison;
begin
  CompareCompiler(True);
end;

initialization
  TDUnitX.RegisterTestFixture(TTypeVisibilityNativeTests);
  TDUnitX.RegisterTestFixture(TTypeVisibilityNativeSlowTests);

end.
