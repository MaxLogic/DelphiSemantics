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
echo   --dak-root ^<path^>            DAK checkout root. Maps to -DakRoot.
echo   --work-root ^<path^>           Gate clone/report root. Maps to -WorkRoot.
echo   --delphi-semantics-root ^<path^>
echo                                DelphiSemantics checkout root. Maps to -DelphiSemanticsRoot.
echo   --help                       Show this help.
echo.
echo DAK RemoveWith tests run sequentially by default. Do not split DUnitX
echo RemoveWith filters across parallel DelphiAIKit.Tests.exe processes unless
echo each process has isolated output via DAK_TEST_OUTPUT_ROOT.
exit /b 0

:help_error
call :help
exit /b 1
