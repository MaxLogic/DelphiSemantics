unit DelphiSemantics.Rename.Preparation;

interface

uses
  System.Generics.Collections,
  DelphiSemantics.Model, DelphiSemantics.Preprocess, DelphiSemantics.ProjectContext,
  DelphiSemantics.ProjectSession,
  DelphiSemantics.Source, DelphiSemantics.Source.IdentityInputs;

type
  TDelphiSemanticRenamePreparedSource = record
    FileName: string;
    Text: string;
    IdentifierText: string;
    AnalysisOnly: Boolean;
    Preprocess: TDelphiSemanticPreprocessResult;
  end;

  // One command/pair owns its first observations. No validation result is
  // memoized: every RequireCurrent call starts a fresh checkpoint.
  TDelphiSemanticRenamePreparation = class
  private
    fInputs: TDelphiSemanticIdentityInputs;
    fFileIdentities: TDictionary<string, string>;
    fSources: TArray<TDelphiSemanticRenamePreparedSource>;
    fObservations: IDelphiSemanticSourceObservations;
    fObservationAccumulator: TDelphiSemanticSourceAccumulator;
    fSession: TDelphiSemanticProjectSession;
    fModelOptions: TDelphiSemanticModelOptions;
    function LoadFile(const aFileName: string): TDelphiSemanticSourceLoadResult;
    procedure MergeObservations(const aSources: IDelphiSemanticSourceObservations);
  public
    constructor Create(const aOptions: TDelphiSemanticOptions);
    destructor Destroy; override;
    function HasUnknownName(const aName: string): Boolean;
    function HasName(const aName: string): Boolean;
    function HasAnalysisPreprocessingGap: Boolean;
    function HasProjectPreprocessingFailure: Boolean;
    procedure RequireCurrent;
    property Sources: TArray<TDelphiSemanticRenamePreparedSource> read fSources;
  end;

implementation

uses
  System.IOUtils, System.StrUtils, System.SysUtils,
  Winapi.Windows,
  DelphiSemantics.Cache, DelphiSemantics.ImportFacts, DelphiSemantics.Model.PossibleSources, DelphiSemantics.Model.Text,
  DelphiSemantics.SourceConditionals,
  MaxLogic.StrUtils;

type
  // Windows SDK FILE_ID_INFO (WinBase.h), including all 128 file-id bits.
  TCommandFileIdInfo = record
    VolumeSerialNumber: UInt64;
    FileId: array[0..15] of Byte;
  end;

function CommandGetFileInformationByHandleEx(const aFile: THandle;
  const aInformationClass: Integer; const aInformation: Pointer;
  const aSize: DWORD): BOOL; stdcall;
  external kernel32 name 'GetFileInformationByHandleEx';

function FileIdentity(const aHandle: THandle): string;
const
  cFileIdInfo = 18;
var
  lInfo: TCommandFileIdInfo;
  lValue: Byte;
begin
  lInfo := Default(TCommandFileIdInfo);
  if not CommandGetFileInformationByHandleEx(aHandle, cFileIdInfo, @lInfo, SizeOf(lInfo)) then
    RaiseLastOSError;
  Result := IntToHex(lInfo.VolumeSerialNumber, 16);
  for lValue in lInfo.FileId do
    Result := Result + IntToHex(lValue, 2);
end;

function OpenSource(const aFileName: string): THandle;
begin
  // Short-lived read lock binds the loader's bytes to this physical file.
  // Release it before compilation/apply; editable sources are never retained locked.
  Result := CreateFile(PChar(aFileName), GENERIC_READ, FILE_SHARE_READ, nil,
    OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0);
  if Result = INVALID_HANDLE_VALUE then
    RaiseLastOSError;
end;

function TDelphiSemanticRenamePreparation.LoadFile(const aFileName: string):
  TDelphiSemanticSourceLoadResult;
var
  lHandle: THandle;
  lFileName, lIdentity, lPrevious: string;
begin
  lFileName := TPath.GetFullPath(aFileName);
  if not TFile.Exists(lFileName) then
    Exit(fInputs.LoadFile(lFileName));
  lHandle := OpenSource(lFileName);
  try
    lIdentity := FileIdentity(lHandle);
    if fFileIdentities.TryGetValue(lFileName, lPrevious) and (lPrevious <> lIdentity) then
      raise EInvalidOpException.Create('MODEL_SOURCE_VALIDATION_FAILED: file identity changed: ' + lFileName);
    Result := fInputs.LoadFile(lFileName);
    fFileIdentities.AddOrSetValue(lFileName, lIdentity);
  finally
    CloseHandle(lHandle);
  end;
end;

procedure TDelphiSemanticRenamePreparation.MergeObservations(
  const aSources: IDelphiSemanticSourceObservations);
var
  lError: string;
begin
  if not fObservationAccumulator.TryAdd(aSources, lError) then
    raise EInvalidOpException.Create('MODEL_SOURCE_VALIDATION_FAILED: ' + lError);
end;

constructor TDelphiSemanticRenamePreparation.Create(const aOptions: TDelphiSemanticOptions);
var
  lSession: TDelphiSemanticProjectSessionResult;
  lBatch: TDelphiSemanticPossibleSourceBatch;
  lFiles: TList<string>;
  lSeen, lProjectFiles: THashSet<string>;
  lFileName: string;
  lInput: TDelphiSemanticRenamePreparedSource;
  lOptions: TDelphiSemanticPreprocessOptions;
  lPossible: TDelphiSemanticPossibleSources;
  lImport: TDelphiSemanticImportFact;
  i: Integer;
begin
  inherited Create;
  fInputs := TDelphiSemanticIdentityInputs.Create(True);
  fObservationAccumulator := TDelphiSemanticSourceAccumulator.Create;
  fFileIdentities := TDictionary<string, string>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
  lSession := TDelphiSemanticProjectSession.Open(aOptions);
  if not lSession.Success then
    raise EInvalidOpException.Create('Rename project preparation unavailable');
  lFiles := nil;
  lSeen := nil;
  lProjectFiles := nil;
  lBatch := nil;
  try
    fSession := lSession.Session;
    lSession.Session := nil;
    fModelOptions := fSession.RenamePreparationModelOptions;
    lFiles := TList<string>.Create;
    lSeen := THashSet<string>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
    lProjectFiles := THashSet<string>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
    for lFileName in fSession.RenamePreparationSourceFileNames do
    begin
      lFiles.Add(lFileName);
      lSeen.Add(lFileName);
      lProjectFiles.Add(lFileName);
    end;
    lBatch := TDelphiSemanticPossibleSourceBatch.Create(fModelOptions, True);
    i := 0;
    while i < lFiles.Count do
    begin
      lInput := Default(TDelphiSemanticRenamePreparedSource);
      lInput.FileName := lFiles[i];
      lInput.AnalysisOnly := not lProjectFiles.Contains(lInput.FileName);
      lOptions := Default(TDelphiSemanticPreprocessOptions);
      lOptions.SourceFileName := lInput.FileName;
      lInput.Text := LoadFile(lInput.FileName).Source.Text;
      lInput.IdentifierText := UpperCase(SanitizeCodeText(lInput.Text));
      lOptions.SourceText := lInput.Text;
      lOptions.SourceLoader :=
        function(const aFileName: string): TDelphiSemanticSourceLoadResult
        begin
          Result := LoadFile(aFileName);
        end;
      lOptions.SourceExists :=
        function(const aFileName: string): Boolean
        begin
          Result := fInputs.FileExists(aFileName);
        end;
      lOptions.Defines := fModelOptions.Defines;
      lOptions.SearchPaths := fModelOptions.IncludePaths;
      lOptions.SkippedIncludeSearchPaths := fModelOptions.SearchPaths;
      lInput.Preprocess := TDelphiSemanticPreprocessor.PreprocessFile(lOptions);
      MergeObservations(lInput.Preprocess.SourceObservations);
      fModelOptions.SourceFileName := lInput.FileName;
      lPossible := lBatch.Capture(fModelOptions, lInput.Preprocess, False);
      MergeObservations(lPossible.Sources);
      for lImport in lPossible.ImportFacts do
        if not lImport.SdkBoundary and (lImport.TargetFileName <> '') and
          (lImport.Cause <> 'occurrence-in-inactive-configuration') and
          SameText(TPath.GetExtension(lImport.TargetFileName), '.pas') then
        begin
          lFileName := TPath.GetFullPath(lImport.TargetFileName);
          if lSeen.Add(lFileName) then
            lFiles.Add(lFileName);
        end;
      fSources := fSources + [lInput];
      Inc(i);
    end;
    lBatch.RequireCurrentDiscovery;
    MergeObservations(fInputs.Observations);
    fObservations := fObservationAccumulator.Freeze;
    RequireCurrent;
  finally
    lBatch.Free;
    lProjectFiles.Free;
    lSeen.Free;
    lFiles.Free;
    lSession.Session.Free;
  end;
end;

destructor TDelphiSemanticRenamePreparation.Destroy;
begin
  fSession.Free;
  fObservationAccumulator.Free;
  fFileIdentities.Free;
  fInputs.Free;
  inherited;
end;

function TDelphiSemanticRenamePreparation.HasName(const aName: string): Boolean;
var
  lSource: TDelphiSemanticRenamePreparedSource;
begin
  for lSource in fSources do
    if TextContainsIdentifier(lSource.IdentifierText, UpperCase(aName)) then
      Exit(True);
  Result := False;
end;

function TDelphiSemanticRenamePreparation.HasUnknownName(const aName: string): Boolean;
var
  lSource: TDelphiSemanticRenamePreparedSource;
  lCode, lActivity: string;
  lPosition: Integer;
begin
  for lSource in fSources do
  begin
    lCode := lSource.IdentifierText;
    lActivity := TDelphiSemanticSourceConditionals.EncodeActivity(lSource.Text,
      lSource.FileName, lSource.Preprocess.ActivitySpans);
    lPosition := Pos(UpperCase(aName), lCode);
    while lPosition > 0 do
    begin
      if IsWordAt(lCode, lPosition, UpperCase(aName)) and
        TDelphiSemanticSourceConditionals.UnknownAtOffset(lSource.Text, lActivity, lPosition) then
        Exit(True);
      lPosition := PosEx(UpperCase(aName), lCode, lPosition + 1);
    end;
  end;
  Result := False;
end;

function TDelphiSemanticRenamePreparation.HasAnalysisPreprocessingGap: Boolean;
var
  lSource: TDelphiSemanticRenamePreparedSource;
begin
  for lSource in fSources do
    if lSource.AnalysisOnly and
      (lSource.Preprocess.HasUnknownActivity or not lSource.Preprocess.Success) then
      Exit(True);
  Result := False;
end;

function TDelphiSemanticRenamePreparation.HasProjectPreprocessingFailure: Boolean;
var
  lSource: TDelphiSemanticRenamePreparedSource;
begin
  for lSource in fSources do
    if not lSource.AnalysisOnly and not lSource.Preprocess.Success then
      Exit(True);
  Result := False;
end;

procedure TDelphiSemanticRenamePreparation.RequireCurrent;
var
  lPair: TPair<string, string>;
  lHandle: THandle;
begin
  fSession.RequireRenamePreparationCurrent;
  // Fresh path/physical identity and fresh byte/lookup/absence validation.
  // Neither this result nor the native owner's checkpoint result is retained.
  for lPair in fFileIdentities do
  begin
    lHandle := OpenSource(lPair.Key);
    try
      if FileIdentity(lHandle) <> lPair.Value then
        raise EInvalidOpException.Create('MODEL_SOURCE_VALIDATION_FAILED: file identity changed: ' + lPair.Key);
    finally
      CloseHandle(lHandle);
    end;
  end;
  TDelphiSemanticUnitCache.RequireCurrentSources(fObservations);
end;

end.
