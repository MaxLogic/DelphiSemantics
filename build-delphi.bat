@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "DAK_BUILD=F:\projects\MaxLogic\DelphiAiKit\build-delphi.bat"
if not exist "%DAK_BUILD%" (
  echo ERROR: DAK build script not found: %DAK_BUILD%
  exit /b 1
)

set "ARG_LIST="
set "PROJECT_SEEN="

:collect_args
if "%~1"=="" goto run_build

if /I "%~1"=="-test-output-dir" goto collect_test_output_dir

set "ARG=%~1"
set "EXT=%~x1"
if not defined PROJECT_SEEN (
  if /I "!EXT!"==".dproj" goto normalize_project
  if /I "!EXT!"==".dpr" goto normalize_project
  if /I "!EXT!"==".dpk" goto normalize_project
)
goto append_arg

:normalize_project
set "PROJECT_SEEN=1"
if exist "%~1" (
  for %%p in ("%~1") do set "ARG=%%~fp"
)

:append_arg
set "ARG_LIST=!ARG_LIST! "!ARG!""
shift
goto collect_args

:collect_test_output_dir
set "ARG_LIST=!ARG_LIST! "%~1""
shift
if "%~1"=="" (
  echo ERROR: -test-output-dir requires a value.
  exit /b 2
)
for %%p in ("%~1") do set "OUT_ARG=%%~fp"
set "DCC_DcuOutput=!OUT_ARG!"
set "ARG_LIST=!ARG_LIST! "!OUT_ARG!""
shift
goto collect_args

:run_build
call "%DAK_BUILD%" !ARG_LIST!
exit /b %ERRORLEVEL%
