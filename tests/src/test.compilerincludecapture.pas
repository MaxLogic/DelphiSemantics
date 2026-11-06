unit Test.CompilerIncludeCapture;

interface

uses
  DelphiSemantics.CompilerDefineEvidence, DelphiSemantics.ProjectContext;

function CaptureFixtureCompilerDefines(const aProjectFileName: string):
  IDelphiSemanticCompilerDefineEvidence;

function CaptureTestCompilerIncludePath(const aRoot: string;
  const aDirectories: TArray<string>): string;

function CaptureFixtureCompilerIncludePath(const aProjectFileName: string): string;

function CaptureFixtureCompilerDefineContext(const aProjectFileName: string;
  out aIncludePath: string): IDelphiSemanticCompilerDefineEvidence overload;

function CaptureFixtureCompilerDefineContext(const aPlanningOptions: TDelphiSemanticOptions;
  out aIncludePath: string): IDelphiSemanticCompilerDefineEvidence; overload;

implementation

uses
  System.IOUtils, System.StrUtils, System.SysUtils,
  Winapi.Windows,
  Dak.Build.NativeContext, Dak.Build.Types, Dak.ExternalToolProcess,
  DelphiSemantics.CompilerProfile;

type
  TIncludeCaptureProcessRunner = class(TInterfacedObject, IBuildProcessRunner)
  public
    function RunProcess(const aExePath, aArguments, aWorkDir, aStdOutPath, aStdErrPath: string;
      const aEnvironmentBlock: string; aTimeoutSec: Integer; out aExitCode: Integer;
      out aTimedOut: Boolean; out aError: string): Boolean;
  end;

function TIncludeCaptureProcessRunner.RunProcess(const aExePath, aArguments, aWorkDir, aStdOutPath, aStdErrPath: string;
  const aEnvironmentBlock: string; aTimeoutSec: Integer; out aExitCode: Integer;
  out aTimedOut: Boolean; out aError: string): Boolean;
var
  lErrHandle: THandle;
  lOutHandle: THandle;
  lProcExitCode: Cardinal;
  lRunOptions: TExternalToolProcessRunOptions;
  lRunTimedOut: Boolean;
  lSa: TSecurityAttributes;
begin
  Result := False;
  aExitCode := 1;
  aTimedOut := False;
  aError := '';
  lOutHandle := INVALID_HANDLE_VALUE;
  lErrHandle := INVALID_HANDLE_VALUE;

  lSa := Default(TSecurityAttributes);
  lSa.nLength := SizeOf(lSa);
  lSa.bInheritHandle := True;

  lOutHandle := CreateFile(PChar(aStdOutPath), GENERIC_WRITE, FILE_SHARE_READ, @lSa, CREATE_ALWAYS,
    FILE_ATTRIBUTE_NORMAL, 0);
  if lOutHandle = INVALID_HANDLE_VALUE then
  begin
    aError := 'Failed to create stdout log.';
    Exit(False);
  end;

  lErrHandle := CreateFile(PChar(aStdErrPath), GENERIC_WRITE, FILE_SHARE_READ, @lSa, CREATE_ALWAYS,
    FILE_ATTRIBUTE_NORMAL, 0);
  if lErrHandle = INVALID_HANDLE_VALUE then
  begin
    CloseHandle(lOutHandle);
    aError := 'Failed to create stderr log.';
    Exit(False);
  end;

  try
    lRunOptions := Default(TExternalToolProcessRunOptions);
    lRunOptions.fApplicationName := aExePath;
    lRunOptions.fExePath := aExePath;
    lRunOptions.fArguments := aArguments;
    lRunOptions.fWorkDir := aWorkDir;
    lRunOptions.fEnvironmentBlock := aEnvironmentBlock;
    lRunOptions.fToolName := ExtractFileName(aExePath);
    lRunOptions.fStdInHandle := GetStdHandle(STD_INPUT_HANDLE);
    lRunOptions.fStdOutHandle := lOutHandle;
    lRunOptions.fStdErrHandle := lErrHandle;
    lRunOptions.fCreationFlags := CREATE_NO_WINDOW;
    lRunOptions.fTimeoutSec := aTimeoutSec;
    lRunOptions.fTimeoutExitCode := 124;

    if not TryRunExternalToolProcess(lRunOptions, lProcExitCode, lRunTimedOut, aError) then
    begin
      aTimedOut := lRunTimedOut;
      if aTimedOut then
      begin
        aExitCode := Integer(lProcExitCode);
        aError := '';
        Exit(True);
      end;
      Exit(False);
    end;
    aExitCode := Integer(lProcExitCode);
  finally
    if lErrHandle <> INVALID_HANDLE_VALUE then
      CloseHandle(lErrHandle);
    if lOutHandle <> INVALID_HANDLE_VALUE then
      CloseHandle(lOutHandle);
  end;

  Result := True;
end;


function CaptureProjectCompilerIncludePath(const aProjectFileName, aPlatform: string): string;
var
  lContext: IDakNativeCompilerContext;
  lInvocation: TDakNativeCompilerInvocation;
  lProfile: TDakNativeCompilerSourceProfile;
  lReason: string;
  lRunner: IBuildProcessRunner;
begin
  lInvocation := Default(TDakNativeCompilerInvocation);
  lInvocation.fProjectFileName := aProjectFileName;
  lInvocation.fSdkRoot := ExcludeTrailingPathDelimiter(TDelphiSemanticCompilerProfileBuilder.ResolveBdsRoot('23.0', ''));
  lInvocation.fCompilerFileName := TPath.Combine(lInvocation.fSdkRoot, IfThen(SameText(aPlatform, 'Win32'), 'bin\dcc32.exe', 'bin\dcc64.exe'));
  lInvocation.fMsBuildFileName := TPath.Combine(GetEnvironmentVariable('WINDIR'),
    'Microsoft.NET\Framework\v4.0.30319\MSBuild.exe');
  lInvocation.fPropertyArguments := '/p:Config=Debug /p:Platform=' + aPlatform + ' /p:BDS="' +
    lInvocation.fSdkRoot + '"';
  lInvocation.fWorkRoot := TPath.Combine(ExtractFilePath(aProjectFileName), '.dak\' + TPath.GetFileNameWithoutExtension(aProjectFileName) + '\inc');
  lRunner := TIncludeCaptureProcessRunner.Create;
  lContext := TryCaptureNativeCompilerContext(lInvocation, lRunner, lReason);
  if lContext = nil then
    raise EInvalidOpException.Create('Test native include capture failed: ' + lReason);
  if not lContext.InputsAreCurrent then
    raise EInvalidOpException.Create('Test native include capture changed');
  lProfile := lContext.SourceProfile;
  Result := StringReplace(lProfile.fCompilerIncludeSearchPath, sLineBreak, ';', [rfReplaceAll]);
end;

function CaptureFixtureCompilerDefineContext(const aProjectFileName: string;
  out aIncludePath: string): IDelphiSemanticCompilerDefineEvidence;
var
  lOptions: TDelphiSemanticOptions;
begin
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := aProjectFileName;
  Result := CaptureFixtureCompilerDefineContext(lOptions, aIncludePath);
end;

function CaptureFixtureCompilerDefineContext(const aPlanningOptions: TDelphiSemanticOptions;
  out aIncludePath: string): IDelphiSemanticCompilerDefineEvidence;
var
  lInvocation: TDakNativeCompilerInvocation;
  lContext: IDakNativeCompilerContext;
  lSettings: IDakNativeCompilerSettingsContext;
  lRunner: IBuildProcessRunner;
  lReason: string;
begin
  lInvocation := Default(TDakNativeCompilerInvocation);
  lInvocation.fPlanningOptions := aPlanningOptions;
  lInvocation.fSettingsEvidenceRequested := True;
  lInvocation.fDelphiVersion := '23.0';
  lInvocation.fBuildTarget := 'Build';
  lInvocation.fProjectFileName := aPlanningOptions.ProjectPath;
  lInvocation.fSdkRoot := ExcludeTrailingPathDelimiter(
    TDelphiSemanticCompilerProfileBuilder.ResolveBdsRoot('23.0', ''));
  lInvocation.fCompilerFileName := TPath.Combine(lInvocation.fSdkRoot, 'bin\dcc64.exe');
  lInvocation.fMsBuildFileName := TPath.Combine(GetEnvironmentVariable('WINDIR'),
    'Microsoft.NET\Framework\v4.0.30319\MSBuild.exe');
  lInvocation.fPropertyArguments := '/p:Config=Debug /p:Platform=Win64 /p:BDS="' +
    lInvocation.fSdkRoot + '"';
  lInvocation.fWorkRoot := TPath.Combine(ExtractFilePath(aPlanningOptions.ProjectPath),
    '.dak\' + TPath.GetFileNameWithoutExtension(aPlanningOptions.ProjectPath) + '\defines');
  lRunner := TIncludeCaptureProcessRunner.Create;
  lContext := TryCaptureNativeCompilerContext(lInvocation, lRunner, lReason);
  if (lContext = nil) or not Supports(lContext, IDakNativeCompilerSettingsContext, lSettings) then
    raise EInvalidOpException.Create('Test native define capture failed: ' + lReason);
  if not lSettings.TryGetCompilerDefineEvidence(Result, lReason) then
    raise EInvalidOpException.Create('Test native define capture refused: ' + lReason);
  if not lSettings.SettingsInputsAreCurrent then
    raise EInvalidOpException.Create('Test native settings changed before publication');
  aIncludePath := StringReplace(lContext.SourceProfile.fCompilerIncludeSearchPath,
    sLineBreak, ';', [rfReplaceAll]);
end;

function CaptureFixtureCompilerDefines(const aProjectFileName: string):
  IDelphiSemanticCompilerDefineEvidence;
var
  lIncludePath: string;
begin
  Result := CaptureFixtureCompilerDefineContext(aProjectFileName, lIncludePath);
end;

function CaptureTestCompilerIncludePath(const aRoot: string;
  const aDirectories: TArray<string>): string;
var
  lRoot: string;
  lSearchPath: string;
begin
  // A-375: caller fixtures use the same native snapshot helper as DAK.
  // This native metadata project supplies the complete -I list, not DS emulation.
  lRoot := TPath.Combine(aRoot, 'native-include-capture');
  TDirectory.CreateDirectory(lRoot);
  lSearchPath := String.Join(';', aDirectories);
  lSearchPath := StringReplace(lSearchPath, '&', '&amp;', [rfReplaceAll]);
  lSearchPath := StringReplace(lSearchPath, '<', '&lt;', [rfReplaceAll]);
  TFile.WriteAllText(TPath.Combine(lRoot, 'Capture.dpr'),
    'program Capture; begin end.', TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'Capture.dproj'),
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' +
    '<PropertyGroup><MainSource>Capture.dpr</MainSource><FrameworkType>None</FrameworkType>' +
    '<DCC_UnitSearchPath>' + lSearchPath + '</DCC_UnitSearchPath>' +
    '<DelphiLibraryPath></DelphiLibraryPath><ImportEnvOptions>false</ImportEnvOptions>' +
    '</PropertyGroup><Import Project="$(BDS)\Bin\CodeGear.Delphi.Targets"/></Project>', TEncoding.ASCII);
  Result := CaptureProjectCompilerIncludePath(TPath.Combine(lRoot, 'Capture.dproj'), 'Win64');
end;

function CaptureFixtureCompilerIncludePath(const aProjectFileName: string): string;
var
  lProjectText: string;
begin
  // These test-owned minimal fixtures become native metadata projects before
  // either caller capture or DS loading. We capture the same project DS reads.
  lProjectText := TFile.ReadAllText(aProjectFileName, TEncoding.UTF8);
  lProjectText := StringReplace(lProjectText, '<Project>',
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">', []);
  lProjectText := StringReplace(lProjectText, '</Project>',
    '<PropertyGroup><FrameworkType>None</FrameworkType><ImportEnvOptions>false</ImportEnvOptions>' +
    '<DelphiLibraryPath></DelphiLibraryPath><DCC_UnitSearchPath>$(MSBuildProjectDirectory)</DCC_UnitSearchPath>' +
    '</PropertyGroup><Import Project="$(BDS)\Bin\CodeGear.Delphi.Targets"/></Project>', []);
  TFile.WriteAllText(aProjectFileName, lProjectText, TEncoding.ASCII);
  Result := CaptureProjectCompilerIncludePath(aProjectFileName, 'Win32');
end;

end.
