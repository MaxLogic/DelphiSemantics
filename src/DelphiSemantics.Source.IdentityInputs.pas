unit DelphiSemantics.Source.IdentityInputs;

interface

uses
  System.Generics.Collections,
  DelphiSemantics.Source;

type
  // One identity computation owns these first observations. Publication must
  // validate Observations through the uncached currentness path before reuse.
  TDelphiSemanticIdentityInputs = class
  private
    type
      TDirectoryInput = record
        Observation: TDelphiSemanticSourceText;
        FileNames: TArray<string>;
      end;
  private
    fShared: Boolean;
    fFiles: TDictionary<string, TDelphiSemanticSourceLoadResult>;
    fExistence: TDictionary<string, Boolean>;
    fBinaries: TDictionary<string, TDelphiSemanticSourceText>;
    fDirectories: TDictionary<string, TDirectoryInput>;
    fLines: TDictionary<string, TArray<string>>;
    fObserved: TDictionary<string, TDelphiSemanticSourceText>;
    procedure Remember(const aSource: TDelphiSemanticSourceText);
  public
    constructor Create(const aShared: Boolean);
    destructor Destroy; override;
    function LoadFile(const aFileName: string): TDelphiSemanticSourceLoadResult;
    function FileExists(const aFileName: string): Boolean;
    function BinaryObservation(const aFileName: string): TDelphiSemanticSourceText;
    function DirectoryObservation(const aDirectory: string;
      out aFileNames: TArray<string>): TDelphiSemanticSourceText;
    function ReadAllLines(const aFileName: string): TArray<string>;
    function Observations: IDelphiSemanticSourceObservations;
    property Shared: Boolean read fShared;
  end;

implementation

uses
  System.Hash, System.IOUtils, System.SysUtils,
  MaxLogic.StrUtils;

constructor TDelphiSemanticIdentityInputs.Create(const aShared: Boolean);
begin
  inherited Create;
  fShared := aShared;
  fFiles := TDictionary<string, TDelphiSemanticSourceLoadResult>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
  fExistence := TDictionary<string, Boolean>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
  fBinaries := TDictionary<string, TDelphiSemanticSourceText>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
  fDirectories := TDictionary<string, TDirectoryInput>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
  fLines := TDictionary<string, TArray<string>>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
  fObserved := TDictionary<string, TDelphiSemanticSourceText>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
end;

destructor TDelphiSemanticIdentityInputs.Destroy;
begin
  fObserved.Free;
  fLines.Free;
  fDirectories.Free;
  fBinaries.Free;
  fExistence.Free;
  fFiles.Free;
  inherited;
end;

procedure TDelphiSemanticIdentityInputs.Remember(const aSource: TDelphiSemanticSourceText);
var
  lPrevious: TDelphiSemanticSourceText;
begin
  if not fShared then
    Exit;
  if fObserved.TryGetValue(aSource.FileName, lPrevious) then
  begin
    // Binary witnesses omit decoded text. Byte identity covers both roles;
    // the uncached checkpoint validates the retained witness by content hash.
    if lPrevious.ContentHash <> aSource.ContentHash then
      raise EInvalidOpException.Create('MODEL_SOURCE_VALIDATION_FAILED: conflicting identity observations: ' + aSource.FileName);
  end else begin
    fObserved.Add(aSource.FileName, aSource);
  end;
end;

function TDelphiSemanticIdentityInputs.LoadFile(const aFileName: string): TDelphiSemanticSourceLoadResult;
var
  lFileName: string;
  lMissing: TDelphiSemanticSourceText;
  i: Integer;
begin
  if not fShared then
    Exit(TDelphiSemanticSourceLoader.LoadFile(aFileName));
  lFileName := TPath.GetFullPath(aFileName);
  if not fShared or not fFiles.TryGetValue(lFileName, Result) then
  begin
    Result := TDelphiSemanticSourceLoader.LoadFile(lFileName);
    if fShared then
      fFiles.Add(lFileName, Result);
  end;
  // Path spelling belongs to this caller, even when Windows observed identical
  // bytes through another spelling of the same case-insensitive filename.
  Result.Source.FileName := lFileName;
  if Result.Success then
  begin
    Result.SourceObservations := TDelphiSemanticSourceEvidence.FromItems([Result.Source]);
    Remember(Result.Source);
  end else begin
    lMissing := Result.Source;
    lMissing.Role := 'possible-source-absence';
    Remember(lMissing);
    Result.Diagnostics := Copy(Result.Diagnostics);
    for i := 0 to High(Result.Diagnostics) do
    begin
      Result.Diagnostics[i].FileName := lFileName;
      if Result.Diagnostics[i].Code = 'SOURCE_FILE_NOT_FOUND' then
        Result.Diagnostics[i].Message := 'Source file not found: ' + lFileName;
    end;
  end;
end;

function TDelphiSemanticIdentityInputs.FileExists(const aFileName: string): Boolean;
var
  lFileName: string;
  lMissing: TDelphiSemanticSourceText;
begin
  if not fShared then
    Exit(TFile.Exists(aFileName));
  lFileName := TPath.GetFullPath(aFileName);
  if not fExistence.TryGetValue(lFileName, Result) then
  begin
    Result := TFile.Exists(lFileName);
    fExistence.Add(lFileName, Result);
    if not Result then
    begin
      lMissing := Default(TDelphiSemanticSourceText);
      lMissing.FileName := lFileName;
      lMissing.Role := 'possible-source-absence';
      Remember(lMissing);
    end;
  end;
end;

function TDelphiSemanticIdentityInputs.BinaryObservation(const aFileName: string): TDelphiSemanticSourceText;
var
  lFileName: string;
begin
  lFileName := TPath.GetFullPath(aFileName);
  if not fShared or not fBinaries.TryGetValue(lFileName, Result) then
  begin
    Result := Default(TDelphiSemanticSourceText);
    Result.FileName := lFileName;
    Result.ContentHash := THashSHA2.GetHashStringFromFile(lFileName);
    Result.Role := 'possible-source-binary';
    if fShared then
      fBinaries.Add(lFileName, Result);
  end;
  Result.FileName := lFileName;
  Remember(Result);
end;

function TDelphiSemanticIdentityInputs.DirectoryObservation(const aDirectory: string;
  out aFileNames: TArray<string>): TDelphiSemanticSourceText;
var
  lDirectory: string;
  lInput: TDirectoryInput;
begin
  if not fShared then
    Exit(TDelphiSemanticSourceEvidence.UnitDirectoryObservation(aDirectory, aFileNames));
  lDirectory := ExcludeTrailingPathDelimiter(TPath.GetFullPath(aDirectory));
  if not fDirectories.TryGetValue(lDirectory, lInput) then
  begin
    lInput.Observation := TDelphiSemanticSourceEvidence.UnitDirectoryObservation(lDirectory, lInput.FileNames);
    fDirectories.Add(lDirectory, lInput);
    Remember(lInput.Observation);
  end;
  aFileNames := Copy(lInput.FileNames);
  Result := lInput.Observation;
  Result.FileName := lDirectory;
end;

function TDelphiSemanticIdentityInputs.ReadAllLines(const aFileName: string): TArray<string>;
var
  lFileName: string;
begin
  lFileName := TPath.GetFullPath(aFileName);
  if not fShared or not fLines.TryGetValue(lFileName, Result) then
  begin
    Result := TFile.ReadAllLines(lFileName);
    if fShared then
      fLines.Add(lFileName, Result);
  end;
  Result := Copy(Result);
end;

function TDelphiSemanticIdentityInputs.Observations: IDelphiSemanticSourceObservations;
begin
  Result := TDelphiSemanticSourceEvidence.FromItems(fObserved.Values.ToArray);
end;

end.
