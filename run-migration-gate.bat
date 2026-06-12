@echo off
setlocal EnableExtensions

set "SCRIPT_DIR=%~dp0"
set "PS_ARGS="

if /I "%~1"=="--help" goto :help
if /I "%~1"=="-h" goto :help
if /I "%~1"=="/?" goto :help

:parse
if "%~1"=="" goto :run
if /I "%~1"=="--skip-build" (
  set "PS_ARGS=%PS_ARGS% -SkipBuild"
  shift
  goto :parse
)
if /I "%~1"=="--allow-dirty" (
  set "PS_ARGS=%PS_ARGS% -AllowDirty"
  shift
  goto :parse
)
if /I "%~1"=="--dak-root" (
  if "%~2"=="" goto :missing_value
  set "PS_ARGS=%PS_ARGS% -DakRoot ""%~2"""
  shift
  shift
  goto :parse
)
if /I "%~1"=="--work-root" (
  if "%~2"=="" goto :missing_value
  set "PS_ARGS=%PS_ARGS% -WorkRoot ""%~2"""
  shift
  shift
  goto :parse
)
if /I "%~1"=="--dak-test-shards" (
  if "%~2"=="" goto :missing_value
  set "PS_ARGS=%PS_ARGS% -DakTestShards %~2"
  shift
  shift
  goto :parse
)
if /I "%~1"=="--dak-test-profile" (
  if "%~2"=="" goto :missing_value
  set "PS_ARGS=%PS_ARGS% -DakTestProfile %~2"
  shift
  shift
  goto :parse
)
if /I "%~1"=="--delphi-semantics-root" (
  if "%~2"=="" goto :missing_value
  set "PS_ARGS=%PS_ARGS% -DelphiSemanticsRoot ""%~2"""
  shift
  shift
  goto :parse
)

echo Unknown option: %~1
echo.
goto :help_error

:run
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%scripts\run-migration-gate.ps1" %PS_ARGS%
exit /b %ERRORLEVEL%

:missing_value
echo Missing value for option: %~1
echo.
goto :help_error

:help
echo Usage: run-migration-gate.bat [options]
echo.
echo Options:
echo   --skip-build                 Skip project rebuilds. Maps to PowerShell -SkipBuild.
echo   --allow-dirty                Allow dirty DelphiSemantics/DAK worktrees and record it in the manifest.
echo   --dak-root ^<path^>            DAK checkout root. Maps to -DakRoot.
echo   --work-root ^<path^>           Gate clone/report root. Maps to -WorkRoot.
echo   --dak-test-shards ^<count^>     DAK RemoveWith DUnitX shard count. Only 1 is safe.
echo   --dak-test-profile ^<Gate^|Full^>
echo                                DAK RemoveWith test profile. Default is Gate.
echo   --delphi-semantics-root ^<path^>
echo                                DelphiSemantics checkout root. Maps to -DelphiSemanticsRoot.
echo   --help                       Show this help.
echo.
echo DAK RemoveWith tests run sequentially. Do not split DUnitX filters across
echo parallel DelphiAIKit.Tests.exe processes; even isolated DAK_TEST_OUTPUT_ROOT
echo runs have exposed additional shared-state/codepage failures. The Gate
echo profile skips the long proprietary fixture because cloned maxTdb smoke
echo verifies that path separately. Use --dak-test-profile Full for all fixtures.
exit /b 0

:help_error
call :help
exit /b 1
