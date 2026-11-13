unit DelphiSemantics.SourceLookup;

interface

uses
  DelphiSemantics.ComparisonContext, DelphiSemantics.ProjectContext,
  DelphiSemantics.Resolve.UnitResolver;

type
  TDelphiSemanticLookupCandidate = record
    FileName: string;
    Key: string;
  end;

  // Capture-owned lexical work only. Directory/absence and byte observations
  // remain with the caller and its existing publication checkpoints.
  TDelphiSemanticSourceLookup = class(TDelphiSemanticComparisonContext)
  private
    fProject: TDelphiSemanticProjectInfo;
    fPossiblePaths, fPaths: TArray<string>;
    fSdkStates: TArray<Byte>;
    fSdkRoot: string;
    fExpand, fPathsReady, fReusableExpansion: Boolean;
    fPathExpansions, fSdkClassifications, fCandidateKeys: Integer;
  public
    constructor Create(const aProject: TDelphiSemanticProjectInfo;
      const aPossiblePaths: TArray<string>; const aExpand: Boolean; const aSdkRoot: string);
    procedure BeginCall;
    function Paths: TArray<string>;
    function IsSdkPath(const aIndex: Integer): Boolean;
    function IsSdkFile(const aFileName: string): Boolean;
    function Candidates(const aNames: TArray<TUnitCandidateName>): TArray<TDelphiSemanticLookupCandidate>;
    property PathExpansions: Integer read fPathExpansions;
    property SdkClassifications: Integer read fSdkClassifications;
    property CandidateKeys: Integer read fCandidateKeys;
  end;

implementation

uses
  System.IOUtils, System.StrUtils, System.SysUtils;

function FullyQualified(const aPath: string): Boolean;
begin
{$IFDEF MSWINDOWS}
  // Lexical guard only: do not raise earlier than the original path operation.
  Result := ((Length(aPath) >= 3) and (aPath[2] = ':') and CharInSet(aPath[3], ['\', '/'])) or
    ((Length(aPath) >= 2) and CharInSet(aPath[1], ['\', '/']) and CharInSet(aPath[2], ['\', '/']));
{$ELSE}
  Result := False;
{$ENDIF}
end;

constructor TDelphiSemanticSourceLookup.Create(const aProject: TDelphiSemanticProjectInfo;
  const aPossiblePaths: TArray<string>; const aExpand: Boolean; const aSdkRoot: string);
var
  lPath: string;
begin
  inherited Create;
  fProject := aProject;
  fPossiblePaths := Copy(aPossiblePaths);
  fExpand := aExpand;
  fSdkRoot := aSdkRoot;
  fReusableExpansion := True;
  // Keep relative, root-relative and drive-relative expansions at their original
  // call boundary. No CWD-dependent normalization or exception is cached.
  if aExpand then
  begin
    fReusableExpansion := FullyQualified(aProject.ProjectDirectory);
    for lPath in aProject.ReferenceDirectories + aProject.SearchPaths do
      fReusableExpansion := fReusableExpansion and FullyQualified(lPath);
  end;
end;

procedure TDelphiSemanticSourceLookup.BeginCall;
begin
  if not BeginOperation or not fReusableExpansion then
  begin
    fPathsReady := False;
    fPaths := nil;
    fSdkStates := nil;
  end;
end;

function TDelphiSemanticSourceLookup.Paths: TArray<string>;
begin
  if not fPathsReady then
  begin
    // Compute into a local before publication: failed expansion is retried.
    Result := fPossiblePaths;
    if fExpand then
      Result := fProject.SourceLookupPaths + Result;
    fPaths := Result;
    SetLength(fSdkStates, Length(fPaths));
    fPathsReady := True;
    Inc(fPathExpansions);
  end;
  Result := Copy(fPaths);
end;

function TDelphiSemanticSourceLookup.IsSdkFile(const aFileName: string): Boolean;
var
  lRoot, lFileName: string;
begin
  if fSdkRoot = '' then
    Exit(False);
  lRoot := IncludeTrailingPathDelimiter(TPath.GetFullPath(fSdkRoot));
  lFileName := TPath.GetFullPath(aFileName);
  Result := StartsText(IncludeTrailingPathDelimiter(TPath.Combine(lRoot, 'source')), lFileName) or
    StartsText(IncludeTrailingPathDelimiter(TPath.Combine(lRoot, 'lib')), lFileName);
end;

function TDelphiSemanticSourceLookup.IsSdkPath(const aIndex: Integer): Boolean;
begin
  // Invoked lazily in the original directory order, after sentinel handling.
  // Exceptions and CWD-dependent paths are never retained as classifications.
  if fSdkStates[aIndex] <> 0 then
    Exit(fSdkStates[aIndex] = 2);
  Inc(fSdkClassifications);
  Result := IsSdkFile(TPath.Combine(fPaths[aIndex], '_'));
  if ComparisonAvailable and FullyQualified(fSdkRoot) and FullyQualified(fPaths[aIndex]) then
    if Result then
      fSdkStates[aIndex] := 2
    else
      fSdkStates[aIndex] := 1;
end;

function TDelphiSemanticSourceLookup.Candidates(const aNames: TArray<TUnitCandidateName>):
  TArray<TDelphiSemanticLookupCandidate>;
var
  lName: TUnitCandidateName;
  lExtension: string;
  i: Integer;
begin
  SetLength(Result, Length(aNames) * 2);
  i := 0;
  for lName in aNames do
    for lExtension in ['.pas', '.dcu'] do
    begin
      Result[i].FileName := lName.TargetName + lExtension;
      Result[i].Key := LowerCase(Result[i].FileName);
      Inc(fCandidateKeys);
      Inc(i);
    end;
end;

end.
