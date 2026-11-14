unit DelphiSemantics.NameFlow.SdkPins;

interface

// Generated from the native DS SDK extractor helper, Delphi 23.0 compiler
// 29.0.55362.2017. New SDK contents require generation and review of a new pin.
function ExpectedNameSdkSourceIdentity(const aDelphiVersion: string): string;
function ExpectedNameSdkCompilerHash(const aDelphiVersion, aPlatform: string): string; overload;

function ExpectedNameSdkCompilerHash(const aDelphiVersion, aPlatform,
  aCompilerFileName: string): string; overload;

implementation

uses
  System.SysUtils,
  DelphiSemantics.CompilerDefineEvidence;

function ExpectedNameSdkSourceIdentity(const aDelphiVersion: string): string;
begin
  Result := '';
  if SameText(aDelphiVersion, '23.0') then
    Result := 'c95c0b4278c8472854fbc50c1de36cb6efacbe03a3e9a3b18a5ec2078d9abfda';
end;

function ExpectedNameSdkCompilerHash(const aDelphiVersion, aPlatform: string): string;
begin
  Result := '';
  if not SameText(aDelphiVersion, '23.0') then
    Exit;
  if SameText(aPlatform, 'Win32') then
    Result := 'bd301b7a6b56eb3d34c714545abf7d2044d17c6b7641c7fbdf4bdcecb90d2378'
  else if SameText(aPlatform, 'Win64') then
    Result := 'a4945a14f9c4de0ca2b38b4e772f45929235fa515f3621afb63387ac5f23ac03'
  else if SameText(aPlatform, 'Linux64') then
    Result := '7887660dbbb0c055b2ac6cb933020d6f966dd2a1e5913320c9d4c34980060b02';
end;

function ExpectedNameSdkCompilerHash(const aDelphiVersion, aPlatform,
  aCompilerFileName: string): string;
begin
  Result := ExpectedNameSdkCompilerHash(aDelphiVersion, aPlatform);
  if not SameText(aDelphiVersion, '23.0') or
    not SameText(ExtractFileName(ExcludeTrailingPathDelimiter(
      ExtractFilePath(aCompilerFileName))), 'bin64') then
    Exit;
  // The native certificate already admits these independently certified hosts.
  // Select the reviewed pin, never the captured hash itself.
  if SameText(aPlatform, 'Win32') then
    Result := LowerCase(cVerifiedWin32Compiler64Hash)
  else if SameText(aPlatform, 'Win64') then
    Result := LowerCase(cVerifiedCompiler64Hash);
end;

end.
