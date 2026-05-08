unit DelphiSemantics.ProjectContext;

interface

type
  TDelphiSemanticDiagnosticSeverity = (dsInfo, dsWarning, dsError);

  TDelphiSemanticOptions = record
    Configuration: string;
    Platform: string;
    SqliteCacheFileName: string;
  end;

  TDelphiSemanticDiagnostic = record
    Code: string;
    Message: string;
    FileName: string;
    Line: Integer;
    Column: Integer;
    Severity: TDelphiSemanticDiagnosticSeverity;
  end;

  TDelphiSemanticProjectInfo = record
    ProjectFileName: string;
    ProjectDirectory: string;
    ProjectName: string;
    Configuration: string;
    Platform: string;
    MainSourceFileName: string;
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

implementation

uses
  System.IOUtils,
  System.RegularExpressions,
  System.SysUtils;

function CreateErrorDiagnostic(const aCode, aMessage, aFileName: string): TDelphiSemanticDiagnostic;
begin
  Result.Code := aCode;
  Result.Message := aMessage;
  Result.FileName := aFileName;
  Result.Line := 0;
  Result.Column := 0;
  Result.Severity := dsError;
end;

function FailureResult(const aDiagnostic: TDelphiSemanticDiagnostic): TDelphiSemanticContextResult;
begin
  Result.Success := False;
  SetLength(Result.Diagnostics, 1);
  Result.Diagnostics[0] := aDiagnostic;
end;

function SuccessResult(const aProject: TDelphiSemanticProjectInfo): TDelphiSemanticContextResult;
begin
  Result.Success := True;
  Result.Project := aProject;
  SetLength(Result.Diagnostics, 0);
end;

function DecodeXmlText(const aValue: string): string;
begin
  Result := aValue.Trim;
  Result := Result.Replace('&lt;', '<');
  Result := Result.Replace('&gt;', '>');
  Result := Result.Replace('&quot;', '"');
  Result := Result.Replace('&apos;', '''');
  Result := Result.Replace('&amp;', '&');
end;

function ExtractXmlElementText(const aText, aElementName: string): string;
var
  lMatch: TMatch;
  lPattern: string;
begin
  lPattern := Format('<%s(?:\s+[^>]*)?>(.*?)</%s>', [aElementName, aElementName]);
  lMatch := TRegEx.Match(aText, lPattern, [roIgnoreCase, roSingleLine]);
  if lMatch.Success then
    Result := DecodeXmlText(lMatch.Groups[1].Value)
  else
    Result := '';
end;

function NormalizeProjectPath(const aBaseDirectory, aFileName: string): string;
begin
  if TPath.IsPathRooted(aFileName) then
    Result := TPath.GetFullPath(aFileName)
  else
    Result := TPath.GetFullPath(TPath.Combine(aBaseDirectory, aFileName));
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

function LoadProjectInfo(const aProjectFileName: string; const aOptions: TDelphiSemanticOptions): TDelphiSemanticProjectInfo;
var
  lText: string;
  lMainSource: string;
begin
  lText := TFile.ReadAllText(aProjectFileName, TEncoding.UTF8);

  Result.ProjectFileName := aProjectFileName;
  Result.ProjectDirectory := TPath.GetDirectoryName(aProjectFileName);
  Result.ProjectName := ExtractXmlElementText(lText, 'ProjectName');
  if Result.ProjectName = '' then
    Result.ProjectName := TPath.GetFileNameWithoutExtension(aProjectFileName);

  Result.Configuration := aOptions.Configuration;
  if Result.Configuration = '' then
    Result.Configuration := ExtractXmlElementText(lText, 'Config');

  Result.Platform := aOptions.Platform;
  if Result.Platform = '' then
    Result.Platform := ExtractXmlElementText(lText, 'Platform');

  lMainSource := ExtractXmlElementText(lText, 'MainSource');
  if lMainSource = '' then
    lMainSource := TPath.ChangeExtension(TPath.GetFileName(aProjectFileName), '.dpr');
  Result.MainSourceFileName := NormalizeProjectPath(Result.ProjectDirectory, lMainSource);
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
  lFailure: TDelphiSemanticContextResult;
  lProject: TDelphiSemanticProjectInfo;
  lProjectFileName: string;
begin
  if not ResolveProjectFileName(aFileName, lProjectFileName, lFailure) then
    Exit(lFailure);

  lProject := LoadProjectInfo(lProjectFileName, aOptions);
  Result := SuccessResult(lProject);
end;

end.
