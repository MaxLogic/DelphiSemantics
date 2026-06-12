unit DelphiSemantics.CompilerProfile;

interface

uses
  DelphiSemantics.Cache, DelphiSemantics.Model;

type
  TDelphiSemanticIntrinsicSymbol = record
    Name: string;
    Kind: string;
    TypeName: string;
    OwnerName: string;
    Signature: string;
    Notes: string;
  end;

  TDelphiSemanticCompilerProfile = record
    Name: string;
    ProfileKey: string;
    DelphiVersion: string;
    Platform: string;
    IntrinsicSeedVersion: string;
    RtlSourceRoot: string;
    IntrinsicSymbols: TArray<TDelphiSemanticIntrinsicSymbol>;
    RtlSourceUnitModels: TArray<TDelphiSemanticUnitModel>;
  end;

  TDelphiSemanticCompilerProfileBuilder = record
  public
    class function DefaultProfile(const aCompilerProfileName: string):
      TDelphiSemanticCompilerProfile; static;
    class function FromCachedSources(const aCache: TDelphiSemanticUnitCache;
      const aSourceFileNames: TArray<string>): TDelphiSemanticCompilerProfile; static;
    class function ProfileForTarget(const aCompilerProfileName, aDelphiVersion, aPlatform,
      aRtlSourceRoot: string): TDelphiSemanticCompilerProfile; static;
    class function DiscoverRtlSourceFiles(const aRtlSourceRoot: string;
      const aUnitNames: TArray<string>): TArray<string>; static;
    class function DefinesForPlatform(const aPlatform: string): TArray<string>; static;
    class function ProfileForTargetFromRtlSourceRoot(const aCache: TDelphiSemanticUnitCache;
      const aCompilerProfileName, aDelphiVersion, aPlatform, aRtlSourceRoot: string;
      const aUnitNames: TArray<string>): TDelphiSemanticCompilerProfile; static;
    class function ResolveBdsRoot(const aDelphiVersion, aRsVarsPath: string): string; static;
    class function ResolveRtlSourceRoot(const aDelphiVersion, aRsVarsPath: string): string; static;
  end;

implementation

uses
  System.Generics.Collections, System.Generics.Defaults, System.Hash, System.IOUtils,
  System.SysUtils,
  System.Win.Registry,
  Winapi.Windows,
  MaxLogic.StrUtils;

const
  cIntrinsicSeedVersion = 'delphi-intrinsics-v2';
  cProfileSchemaVersion = '1';

function StableHash(const aText: string): string;
begin
  Result := THashSHA2.GetHashString(aText);
end;

function NormalizePart(const aValue, aFallback: string): string;
begin
  Result := Trim(aValue);
  if Result = '' then
    Result := aFallback;
end;

function NormalizeDelphiVersion(const aValue: string): string;
begin
  Result := Trim(aValue);
  if (Result <> '') and (Pos('.', Result) = 0) then
    Result := Result + '.0';
end;

function NormalizeRtlSourceRoot(const aRtlSourceRoot: string): string;
begin
  Result := Trim(aRtlSourceRoot);
  if Result <> '' then
    Result := TPath.GetFullPath(Result);
end;

function MakeIntrinsic(const aName, aKind, aTypeName, aOwnerName, aSignature,
  aNotes: string):
  TDelphiSemanticIntrinsicSymbol;
begin
  Result.Name := aName;
  Result.Kind := aKind;
  Result.TypeName := aTypeName;
  Result.OwnerName := aOwnerName;
  Result.Signature := aSignature;
  Result.Notes := aNotes;
end;

procedure AddIntrinsic(var aSymbols: TArray<TDelphiSemanticIntrinsicSymbol>; const aName,
  aKind, aTypeName, aOwnerName, aSignature, aNotes: string);
var
  lIndex: Integer;
begin
  lIndex := Length(aSymbols);
  SetLength(aSymbols, lIndex + 1);
  aSymbols[lIndex] := MakeIntrinsic(aName, aKind, aTypeName, aOwnerName, aSignature, aNotes);
end;

function BuildIntrinsicSymbols: TArray<TDelphiSemanticIntrinsicSymbol>;
begin
  SetLength(Result, 0);
  AddIntrinsic(Result, 'Abs', 'intrinsic-routine', 'numeric', 'compiler',
    'function Abs(X): numeric', 'compiler/RTL intrinsic');
  AddIntrinsic(Result, 'Addr', 'intrinsic-routine', 'Pointer', 'compiler',
    'function Addr(X): Pointer', 'compiler intrinsic');
  AddIntrinsic(Result, 'Assign', 'intrinsic-routine', '', 'compiler',
    'procedure Assign(var F; FileName: string)', 'compiler/RTL intrinsic');
  AddIntrinsic(Result, 'Assigned', 'intrinsic-routine', 'Boolean', 'compiler',
    'function Assigned(P): Boolean', 'compiler intrinsic');
  AddIntrinsic(Result, 'Assert', 'intrinsic-routine', '', 'compiler',
    'procedure Assert(Expression: Boolean)', 'compiler intrinsic');
  AddIntrinsic(Result, 'BlockRead', 'intrinsic-routine', '', 'compiler',
    'procedure BlockRead(var F; var Buf; Count: Integer)', 'compiler/RTL intrinsic');
  AddIntrinsic(Result, 'BlockWrite', 'intrinsic-routine', '', 'compiler',
    'procedure BlockWrite(var F; const Buf; Count: Integer)', 'compiler/RTL intrinsic');
  AddIntrinsic(Result, 'Break', 'intrinsic-routine', '', 'compiler', 'procedure Break',
    'compiler intrinsic');
  AddIntrinsic(Result, 'Close', 'intrinsic-routine', '', 'compiler', 'procedure Close(var F)',
    'compiler/RTL intrinsic');
  AddIntrinsic(Result, 'Continue', 'intrinsic-routine', '', 'compiler', 'procedure Continue',
    'compiler intrinsic');
  AddIntrinsic(Result, 'Copy', 'intrinsic-routine', '', 'compiler',
    'function Copy(S; Index, Count: Integer)', 'compiler intrinsic');
  AddIntrinsic(Result, 'Dec', 'intrinsic-routine', '', 'compiler',
    'procedure Dec(var X; N: Integer = 1)', 'compiler intrinsic');
  AddIntrinsic(Result, 'Default', 'intrinsic-routine', 'T', 'compiler', 'function Default(T): T',
    'compiler intrinsic');
  AddIntrinsic(Result, 'Delete', 'intrinsic-routine', '', 'compiler',
    'procedure Delete(var S; Index, Count: Integer)', 'compiler intrinsic');
  AddIntrinsic(Result, 'Dispose', 'intrinsic-routine', '', 'compiler', 'procedure Dispose(P)',
    'compiler intrinsic');
  AddIntrinsic(Result, 'EOF', 'intrinsic-routine', 'Boolean', 'compiler', 'function EOF(var F): Boolean',
    'compiler/RTL intrinsic');
  AddIntrinsic(Result, 'Exclude', 'intrinsic-routine', '', 'compiler',
    'procedure Exclude(var S; I)', 'compiler intrinsic');
  AddIntrinsic(Result, 'Exit', 'intrinsic-routine', '', 'compiler', 'procedure Exit',
    'compiler intrinsic');
  AddIntrinsic(Result, 'FilePos', 'intrinsic-routine', 'Integer', 'compiler',
    'function FilePos(var F): Integer', 'compiler/RTL intrinsic');
  AddIntrinsic(Result, 'FillChar', 'intrinsic-routine', '', 'compiler',
    'procedure FillChar(var X; Count: NativeInt; Value)', 'compiler intrinsic');
  AddIntrinsic(Result, 'Flush', 'intrinsic-routine', '', 'compiler', 'procedure Flush(var F)',
    'compiler/RTL intrinsic');
  AddIntrinsic(Result, 'FreeMem', 'intrinsic-routine', '', 'compiler',
    'procedure FreeMem(P: Pointer)', 'compiler intrinsic');
  AddIntrinsic(Result, 'FreeAndNil', 'intrinsic-routine', '', 'rtl',
    'procedure FreeAndNil(var Obj)', 'RTL helper');
  AddIntrinsic(Result, 'ExpandFileName', 'intrinsic-routine', 'string', 'rtl',
    'function ExpandFileName(const FileName: string): string', 'RTL helper');
  AddIntrinsic(Result, 'FileDateToDateTime', 'intrinsic-routine', 'TDateTime', 'rtl',
    'function FileDateToDateTime(FileDate: Integer): TDateTime', 'RTL helper');
  AddIntrinsic(Result, 'GetMem', 'intrinsic-routine', '', 'compiler',
    'procedure GetMem(var P: Pointer; Size: NativeInt)', 'compiler intrinsic');
  AddIntrinsic(Result, 'Halt', 'intrinsic-routine', '', 'compiler', 'procedure Halt(Code: Integer = 0)',
    'compiler intrinsic');
  AddIntrinsic(Result, 'High', 'intrinsic-routine', '', 'compiler', 'function High(X)',
    'compiler intrinsic');
  AddIntrinsic(Result, 'Inc', 'intrinsic-routine', '', 'compiler',
    'procedure Inc(var X; N: Integer = 1)', 'compiler intrinsic');
  AddIntrinsic(Result, 'Include', 'intrinsic-routine', '', 'compiler',
    'procedure Include(var S; I)', 'compiler intrinsic');
  AddIntrinsic(Result, 'IOResult', 'intrinsic-routine', 'Integer', 'compiler',
    'function IOResult: Integer', 'compiler/RTL intrinsic');
  AddIntrinsic(Result, 'IntToStr', 'intrinsic-routine', 'string', 'rtl',
    'function IntToStr(Value: Integer): string', 'RTL helper');
  AddIntrinsic(Result, 'Length', 'intrinsic-routine', 'Integer', 'compiler',
    'function Length(S): Integer', 'compiler intrinsic');
  AddIntrinsic(Result, 'Low', 'intrinsic-routine', '', 'compiler', 'function Low(X)',
    'compiler intrinsic');
  AddIntrinsic(Result, 'Max', 'intrinsic-routine', 'Integer', 'rtl',
    'function Max(A, B: Integer): Integer', 'RTL helper');
  AddIntrinsic(Result, 'Min', 'intrinsic-routine', 'Integer', 'rtl',
    'function Min(A, B: Integer): Integer', 'RTL helper');
  AddIntrinsic(Result, 'Move', 'intrinsic-routine', '', 'compiler',
    'procedure Move(const Source; var Dest; Count: NativeInt)', 'compiler intrinsic');
  AddIntrinsic(Result, 'New', 'intrinsic-routine', '', 'compiler', 'procedure New(var P)',
    'compiler intrinsic');
  AddIntrinsic(Result, 'Ord', 'intrinsic-routine', 'Integer', 'compiler',
    'function Ord(X): Integer', 'compiler intrinsic');
  AddIntrinsic(Result, 'ParamCount', 'intrinsic-routine', 'Integer', 'System',
    'function ParamCount: Integer', 'System routine');
  AddIntrinsic(Result, 'ParamStr', 'intrinsic-routine', 'string', 'System',
    'function ParamStr(Index: Integer): string', 'System routine');
  AddIntrinsic(Result, 'Pop', 'intrinsic-routine', '', 'rtl', 'procedure Pop(var Buffer; Count: Integer)',
    'RTL compatibility helper');
  AddIntrinsic(Result, 'Pred', 'intrinsic-routine', '', 'compiler', 'function Pred(X)',
    'compiler intrinsic');
  AddIntrinsic(Result, 'Push', 'intrinsic-routine', '', 'rtl',
    'procedure Push(const Buffer; Count: Integer)', 'RTL compatibility helper');
  AddIntrinsic(Result, 'Random', 'intrinsic-routine', 'Integer', 'compiler',
    'function Random([Range: Integer]): Integer', 'compiler/RTL intrinsic');
  AddIntrinsic(Result, 'Read', 'intrinsic-routine', '', 'System', 'procedure Read(var V)',
    'System routine');
  AddIntrinsic(Result, 'ReadLn', 'intrinsic-routine', '', 'System', 'procedure ReadLn(var V)',
    'System routine');
  AddIntrinsic(Result, 'ReallocMem', 'intrinsic-routine', '', 'compiler',
    'procedure ReallocMem(var P: Pointer; Size: NativeInt)', 'compiler intrinsic');
  AddIntrinsic(Result, 'Reset', 'intrinsic-routine', '', 'compiler', 'procedure Reset(var F)',
    'compiler/RTL intrinsic');
  AddIntrinsic(Result, 'Rewrite', 'intrinsic-routine', '', 'compiler', 'procedure Rewrite(var F)',
    'compiler/RTL intrinsic');
  AddIntrinsic(Result, 'Round', 'intrinsic-routine', 'Integer', 'compiler',
    'function Round(X): Integer', 'compiler/RTL intrinsic');
  AddIntrinsic(Result, 'Seek', 'intrinsic-routine', '', 'compiler',
    'procedure Seek(var F; N: Integer)', 'compiler/RTL intrinsic');
  AddIntrinsic(Result, 'SetLength', 'intrinsic-routine', '', 'compiler',
    'procedure SetLength(var S; NewLength: Integer)', 'compiler intrinsic');
  AddIntrinsic(Result, 'SizeOf', 'intrinsic-routine', 'NativeInt', 'compiler',
    'function SizeOf(X): NativeInt', 'compiler intrinsic');
  AddIntrinsic(Result, 'Sqr', 'intrinsic-routine', 'numeric', 'compiler', 'function Sqr(X): numeric',
    'compiler/RTL intrinsic');
  AddIntrinsic(Result, 'Str', 'intrinsic-routine', '', 'compiler', 'procedure Str(X; var S: string)',
    'compiler/RTL intrinsic');
  AddIntrinsic(Result, 'Succ', 'intrinsic-routine', '', 'compiler', 'function Succ(X)',
    'compiler intrinsic');
  AddIntrinsic(Result, 'Swap', 'intrinsic-routine', 'Integer', 'compiler', 'function Swap(X): Integer',
    'compiler intrinsic');
  AddIntrinsic(Result, 'System', 'intrinsic-unit', 'unit', 'compiler', 'unit System',
    'implicitly available unit');
  AddIntrinsic(Result, 'TObject', 'intrinsic-type', 'class', 'rtl', 'type TObject',
    'RTL base class');
  AddIntrinsic(Result, 'Trunc', 'intrinsic-routine', 'Integer', 'compiler',
    'function Trunc(X): Integer', 'compiler/RTL intrinsic');
  AddIntrinsic(Result, 'TypeInfo', 'intrinsic-routine', 'Pointer', 'compiler',
    'function TypeInfo(TypeIdentifier): Pointer', 'compiler intrinsic');
  AddIntrinsic(Result, 'UpCase', 'intrinsic-routine', 'Char', 'compiler', 'function UpCase(Ch): Char',
    'compiler intrinsic');
  AddIntrinsic(Result, 'Val', 'intrinsic-routine', '', 'System',
    'procedure Val(S; var V; var Code: Integer)', 'System routine');
  AddIntrinsic(Result, 'Write', 'intrinsic-routine', '', 'System', 'procedure Write(Args)',
    'System routine');
  AddIntrinsic(Result, 'WriteLn', 'intrinsic-routine', '', 'System', 'procedure WriteLn(Args)',
    'System routine');
  AddIntrinsic(Result, 'Boolean', 'intrinsic-type', 'Boolean', 'compiler', 'type Boolean',
    'compiler intrinsic type');
  AddIntrinsic(Result, 'Byte', 'intrinsic-type', 'Byte', 'compiler', 'type Byte',
    'compiler intrinsic type');
  AddIntrinsic(Result, 'Char', 'intrinsic-type', 'Char', 'compiler', 'type Char',
    'compiler intrinsic type');
  AddIntrinsic(Result, 'Double', 'intrinsic-type', 'Double', 'compiler', 'type Double',
    'compiler intrinsic type');
  AddIntrinsic(Result, 'Integer', 'intrinsic-type', 'Integer', 'compiler', 'type Integer',
    'compiler intrinsic type');
  AddIntrinsic(Result, 'Int32', 'intrinsic-type', 'Int32', 'compiler', 'type Int32',
    'compiler intrinsic type');
  AddIntrinsic(Result, 'NativeInt', 'intrinsic-type', 'NativeInt', 'compiler', 'type NativeInt',
    'compiler intrinsic type');
  AddIntrinsic(Result, 'NativeUInt', 'intrinsic-type', 'NativeUInt', 'compiler',
    'type NativeUInt', 'compiler intrinsic type');
  AddIntrinsic(Result, 'Pointer', 'intrinsic-type', 'Pointer', 'compiler', 'type Pointer',
    'compiler intrinsic type');
  AddIntrinsic(Result, 'PByte', 'intrinsic-type', 'Pointer', 'compiler', 'type PByte = ^Byte',
    'compiler compatibility pointer type');
  AddIntrinsic(Result, 'Single', 'intrinsic-type', 'Single', 'compiler', 'type Single',
    'compiler intrinsic type');
  AddIntrinsic(Result, 'string', 'intrinsic-type', 'string', 'compiler', 'type string',
    'compiler intrinsic type');
  AddIntrinsic(Result, 'TFileName', 'intrinsic-type', 'string', 'rtl', 'type TFileName = string',
    'RTL compatibility type');
  AddIntrinsic(Result, 'TSearchRec', 'intrinsic-type', 'record', 'rtl', 'type TSearchRec = record',
    'RTL compatibility record');
  AddIntrinsic(Result, 'Exception', 'intrinsic-type', 'class', 'rtl', 'type Exception = class',
    'RTL compatibility class');
  AddIntrinsic(Result, 'Name', 'intrinsic-field', 'TFileName', 'TSearchRec',
    'Name: TFileName', 'RTL compatibility field');
  AddIntrinsic(Result, 'Size', 'intrinsic-field', 'Int64', 'TSearchRec', 'Size: Int64',
    'RTL compatibility field');
  AddIntrinsic(Result, 'Attr', 'intrinsic-field', 'Integer', 'TSearchRec', 'Attr: Integer',
    'RTL compatibility field');
  AddIntrinsic(Result, 'Time', 'intrinsic-field', 'Integer', 'TSearchRec', 'Time: Integer',
    'RTL compatibility field');
  AddIntrinsic(Result, 'Message', 'intrinsic-property', 'string', 'Exception',
    'property Message: string', 'RTL compatibility property');
end;

function RtlSourceSearchRoots(const aRtlSourceRoot: string): TArray<string>;
var
  lRtlRoot: string;
begin
  lRtlRoot := TPath.Combine(aRtlSourceRoot, 'rtl');
  Result := [
    aRtlSourceRoot,
    lRtlRoot,
    TPath.Combine(lRtlRoot, 'sys'),
    TPath.Combine(lRtlRoot, 'common'),
    TPath.Combine(lRtlRoot, 'os'),
    TPath.Combine(lRtlRoot, 'win'),
    TPath.Combine(aRtlSourceRoot, 'vcl'),
    TPath.Combine(aRtlSourceRoot, 'fmx')];
end;

function RtlSourceCandidateFileNames(const aUnitName: string): TArray<string>;
var
  lIndex: Integer;
  lScopes: TArray<string>;
  lScope: string;
  lUnitName: string;
begin
  lUnitName := Trim(aUnitName);
  if lUnitName = '' then
  begin
    SetLength(Result, 0);
    Exit;
  end;
  if Pos('.', lUnitName) > 0 then
  begin
    Result := [lUnitName + '.pas'];
    Exit;
  end;

  lScopes := ['System', 'Winapi', 'Vcl', 'FMX'];
  SetLength(Result, Length(lScopes) + 1);
  Result[0] := lUnitName + '.pas';
  lIndex := 1;
  for lScope in lScopes do
  begin
    Result[lIndex] := lScope + '.' + lUnitName + '.pas';
    Inc(lIndex);
  end;
end;

function ContainsPath(const aPaths: TList<string>; const aPath: string): Boolean;
var
  i: Integer;
  lPath: string;
begin
  for i := 0 to Pred(aPaths.Count) do
  begin
    lPath := aPaths[i];
    if SameText(lPath, aPath) then
      Exit(True);
  end;

  Result := False;
end;

function TryFindDirectRtlSourceFile(const aSearchRoots, aFileNames: TArray<string>;
  out aSourceFileName: string): Boolean;
var
  lCandidate: string;
  lFileName: string;
  lSearchRoot: string;
begin
  aSourceFileName := '';
  for lSearchRoot in aSearchRoots do
  begin
    if not TDirectory.Exists(lSearchRoot) then
      Continue;
    for lFileName in aFileNames do
    begin
      lCandidate := TPath.Combine(lSearchRoot, lFileName);
      if TFile.Exists(lCandidate) then
      begin
        aSourceFileName := TPath.GetFullPath(lCandidate);
        Exit(True);
      end;
    end;
  end;

  Result := False;
end;

function BuildRecursiveRtlSourceFileIndex(const aRtlSourceRoot: string): TDictionary<string, string>;
var
  lFile: string;
  lFileName: string;
  lFiles: TArray<string>;
  lIndex: Integer;
begin
  Result := TDictionary<string, string>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
  if not TDirectory.Exists(aRtlSourceRoot) then
    Exit;

  lFiles := TDirectory.GetFiles(aRtlSourceRoot, '*.pas', TSearchOption.soAllDirectories);
  for lIndex := 0 to High(lFiles) do
    lFiles[lIndex] := TPath.GetFullPath(lFiles[lIndex]);
  TArray.Sort<string>(lFiles, TStringComparer.OrdinalIgnoreCase);
  for lFile in lFiles do
  begin
    lFileName := TPath.GetFileName(lFile);
    // Duplicate RTL basenames use the first normalized sorted path for stable fallback selection.
    if not Result.ContainsKey(lFileName) then
      Result.Add(lFileName, lFile);
  end;
end;

function TryFindRecursiveRtlSourceFile(const aFileIndex: TDictionary<string, string>;
  const aFileNames: TArray<string>; out aSourceFileName: string): Boolean;
var
  lFileName: string;
begin
  aSourceFileName := '';
  if aFileIndex = nil then
    Exit(False);

  for lFileName in aFileNames do
    if aFileIndex.TryGetValue(lFileName, aSourceFileName) then
      Exit(True);

  Result := False;
end;

function TryFindRtlSourceFile(const aRtlSourceRoot, aUnitName: string;
  var aRecursiveFileIndex: TDictionary<string, string>; out aSourceFileName: string): Boolean;
var
  lFileNames: TArray<string>;
  lSearchRoots: TArray<string>;
begin
  aSourceFileName := '';
  if not TDirectory.Exists(aRtlSourceRoot) then
    Exit(False);

  lFileNames := RtlSourceCandidateFileNames(aUnitName);
  if Length(lFileNames) = 0 then
    Exit(False);

  lSearchRoots := RtlSourceSearchRoots(aRtlSourceRoot);
  Result := TryFindDirectRtlSourceFile(lSearchRoots, lFileNames, aSourceFileName);
  if not Result then
  begin
    if aRecursiveFileIndex = nil then
      aRecursiveFileIndex := BuildRecursiveRtlSourceFileIndex(aRtlSourceRoot);
    Result := TryFindRecursiveRtlSourceFile(aRecursiveFileIndex, lFileNames, aSourceFileName);
  end;
end;

function TryReadRegistryBdsRoot(const aDelphiVersion: string; const aViewFlag: Cardinal;
  out aBdsRoot: string): Boolean;
var
  lBaseKey: string;
  lRegistry: TRegistry;
begin
  aBdsRoot := '';
  lBaseKey := 'Software\Embarcadero\BDS\' + aDelphiVersion;

  lRegistry := TRegistry.Create;
  try
    lRegistry.Access := KEY_READ or aViewFlag;
    lRegistry.RootKey := HKEY_CURRENT_USER;
    if lRegistry.OpenKeyReadOnly(lBaseKey + '\Environment Variables') then
    begin
      try
        if lRegistry.ValueExists('BDS') then
          aBdsRoot := Trim(lRegistry.ReadString('BDS'));
      finally
        lRegistry.CloseKey;
      end;
    end;

    if (aBdsRoot = '') and lRegistry.OpenKeyReadOnly(lBaseKey) then
    begin
      try
        if lRegistry.ValueExists('RootDir') then
          aBdsRoot := Trim(lRegistry.ReadString('RootDir'));
      finally
        lRegistry.CloseKey;
      end;
    end;
  finally
    lRegistry.Free;
  end;

  Exit(aBdsRoot <> '');
end;

function TryReadBdsRootFromRegistry(const aDelphiVersion: string; out aBdsRoot: string): Boolean;
begin
  Result := TryReadRegistryBdsRoot(aDelphiVersion, KEY_WOW64_64KEY, aBdsRoot);
  if not Result then
    Result := TryReadRegistryBdsRoot(aDelphiVersion, KEY_WOW64_32KEY, aBdsRoot);
end;

class function TDelphiSemanticCompilerProfileBuilder.DefaultProfile(
  const aCompilerProfileName: string): TDelphiSemanticCompilerProfile;
begin
  Result := Default(TDelphiSemanticCompilerProfile);
  Result.Name := aCompilerProfileName;
  if Result.Name = '' then
    Result.Name := 'default';
  Result.ProfileKey := Result.Name;
  Result.IntrinsicSeedVersion := cIntrinsicSeedVersion;
  Result.IntrinsicSymbols := BuildIntrinsicSymbols;
  SetLength(Result.RtlSourceUnitModels, 0);
end;

class function TDelphiSemanticCompilerProfileBuilder.FromCachedSources(
  const aCache: TDelphiSemanticUnitCache; const aSourceFileNames: TArray<string>):
  TDelphiSemanticCompilerProfile;
var
  i: Integer;
  lOptions: TDelphiSemanticModelOptions;
begin
  Result := DefaultProfile(aCache.CompilerProfileName);
  SetLength(Result.RtlSourceUnitModels, Length(aSourceFileNames));
  for i := 0 to Pred(Length(aSourceFileNames)) do
  begin
    lOptions := Default(TDelphiSemanticModelOptions);
    lOptions.SourceFileName := aSourceFileNames[i];
    lOptions.ProjectContextApplied := True;
    Result.RtlSourceUnitModels[i] := aCache.GetOrExtractUnitModel(lOptions);
  end;
end;

function MakeCompilerProfileDefines(const aValues: array of string): TArray<string>;
var
  i: Integer;
begin
  SetLength(Result, Length(aValues));
  for i := 0 to High(aValues) do
    Result[i] := aValues[i];
end;

function CompilerProfileDefinesForPlatform(const aPlatform: string): TArray<string>;
begin
  if SameText(aPlatform, 'Win32') then
    Exit(MakeCompilerProfileDefines(['MSWINDOWS', 'WINDOWS', 'WIN32', 'CPUX86']));
  if SameText(aPlatform, 'Win64') then
    Exit(MakeCompilerProfileDefines(['MSWINDOWS', 'WINDOWS', 'WIN64', 'CPUX64']));
  if SameText(aPlatform, 'Linux64') then
    Exit(MakeCompilerProfileDefines(['POSIX', 'LINUX', 'CPUX64']));
  if SameText(aPlatform, 'OSX64') then
    Exit(MakeCompilerProfileDefines(['POSIX', 'MACOS', 'OSX', 'CPUX64']));
  if SameText(aPlatform, 'OSXARM64') then
    Exit(MakeCompilerProfileDefines(['POSIX', 'MACOS', 'OSX', 'CPUARM64']));
  if SameText(aPlatform, 'Android') then
    Exit(MakeCompilerProfileDefines(['POSIX', 'ANDROID', 'CPUARM']));
  if SameText(aPlatform, 'Android64') then
    Exit(MakeCompilerProfileDefines(['POSIX', 'ANDROID', 'CPUARM64']));
  if SameText(aPlatform, 'iOSDevice64') or SameText(aPlatform, 'iOSSimARM64') then
    Exit(MakeCompilerProfileDefines(['POSIX', 'MACOS', 'IOS', 'CPUARM64']));
  SetLength(Result, 0);
end;

class function TDelphiSemanticCompilerProfileBuilder.DefinesForPlatform(
  const aPlatform: string): TArray<string>;
begin
  Result := CompilerProfileDefinesForPlatform(aPlatform);
end;

function RtlProfileKeepsMemberOwner(const aOwnerName: string;
  const aInterfaceTypeNames: TDictionary<string, Boolean>): Boolean;
var
  lDotPos: Integer;
  lOwnerName: string;
begin
  if aOwnerName = '' then
    Exit(False);
  if aInterfaceTypeNames.ContainsKey(aOwnerName) then
    Exit(True);

  lOwnerName := aOwnerName;
  while lOwnerName <> '' do
  begin
    lDotPos := LastDelimiter('.', lOwnerName);
    if lDotPos <= 0 then
      Break;
    lOwnerName := Copy(lOwnerName, 1, lDotPos - 1);
    if aInterfaceTypeNames.ContainsKey(lOwnerName) then
      Exit(True);
  end;

  Result := False;
end;

function RtlProfileInterfaceProjection(
  const aModel: TDelphiSemanticUnitModel): TDelphiSemanticUnitModel;
var
  lDeclaration: TDelphiSemanticDeclaration;
  lDeclarations: TList<TDelphiSemanticDeclaration>;
  lInterfaceTypeNames: TDictionary<string, Boolean>;
  lMember: TDelphiSemanticMember;
  lMembers: TList<TDelphiSemanticMember>;
  lRoutine: TDelphiSemanticRoutine;
  lRoutines: TList<TDelphiSemanticRoutine>;
begin
  Result := aModel;
  if (Result.SourceText <> '') and (Result.SourceSections.ImplementationOffset > 0) then
    Result.SourceText := Copy(Result.SourceText, 1, Result.SourceSections.ImplementationOffset - 1);
  Result.SourceSections.ImplementationOffset := 0;
  Result.SourceSections.InitializationOffset := 0;
  Result.SourceSections.FinalizationOffset := 0;

  lDeclarations := TList<TDelphiSemanticDeclaration>.Create;
  lMembers := TList<TDelphiSemanticMember>.Create;
  lRoutines := TList<TDelphiSemanticRoutine>.Create;
  lInterfaceTypeNames := TDictionary<string, Boolean>.Create(
    TFastCaseAwareComparer.OrdinalIgnoreCase);
  try
    for lDeclaration in aModel.Declarations do
    begin
      if SameText(lDeclaration.SectionKind, 'interface') then
      begin
        lDeclarations.Add(lDeclaration);
        if SameText(lDeclaration.Kind, 'type') then
          lInterfaceTypeNames.AddOrSetValue(lDeclaration.Name, True);
      end;
    end;

    for lMember in aModel.Members do
      if RtlProfileKeepsMemberOwner(lMember.OwnerName, lInterfaceTypeNames) then
        lMembers.Add(lMember);

    for lRoutine in aModel.Routines do
      if SameText(lRoutine.SectionKind, 'interface') then
        lRoutines.Add(lRoutine);

    Result.Declarations := lDeclarations.ToArray;
    Result.Members := lMembers.ToArray;
    Result.Routines := lRoutines.ToArray;
    SetLength(Result.ImplementationUses, 0);
    SetLength(Result.Locals, 0);
    SetLength(Result.References, 0);
    SetLength(Result.WithStatements, 0);
  finally
    lInterfaceTypeNames.Free;
    lRoutines.Free;
    lMembers.Free;
    lDeclarations.Free;
  end;
end;

function FromRtlSourceRootForPlatform(const aCache: TDelphiSemanticUnitCache;
  const aCompilerProfileName, aPlatform: string;
  const aSourceFileNames: TArray<string>): TDelphiSemanticCompilerProfile;
var
  i: Integer;
  lOptions: TDelphiSemanticModelOptions;
begin
  Result := TDelphiSemanticCompilerProfileBuilder.DefaultProfile(aCompilerProfileName);
  SetLength(Result.RtlSourceUnitModels, Length(aSourceFileNames));
  for i := 0 to Pred(Length(aSourceFileNames)) do
  begin
    lOptions := Default(TDelphiSemanticModelOptions);
    lOptions.SourceFileName := aSourceFileNames[i];
    lOptions.Defines := CompilerProfileDefinesForPlatform(aPlatform);
    lOptions.SearchPaths := [TPath.GetDirectoryName(aSourceFileNames[i])];
    lOptions.ProjectContextApplied := True;
    lOptions.SkipBodyAnalysis := True;
    lOptions.SkipReferenceExtraction := True;
    Result.RtlSourceUnitModels[i] := RtlProfileInterfaceProjection(
      aCache.GetOrExtractUnitModel(lOptions));
  end;
end;

class function TDelphiSemanticCompilerProfileBuilder.ProfileForTarget(
  const aCompilerProfileName, aDelphiVersion, aPlatform, aRtlSourceRoot: string):
  TDelphiSemanticCompilerProfile;
begin
  Result := Default(TDelphiSemanticCompilerProfile);
  Result.Name := NormalizePart(aCompilerProfileName, 'default');
  Result.DelphiVersion := NormalizePart(aDelphiVersion, 'unknown');
  Result.Platform := NormalizePart(aPlatform, 'Win32');
  Result.RtlSourceRoot := NormalizeRtlSourceRoot(aRtlSourceRoot);
  Result.IntrinsicSeedVersion := cIntrinsicSeedVersion;
  Result.ProfileKey := StableHash('compiler-profile|' + cProfileSchemaVersion + '|' +
    cIntrinsicSeedVersion + '|' + LowerCase(Result.DelphiVersion) + '|' +
    LowerCase(Result.Platform) + '|' + LowerCase(Result.RtlSourceRoot));
  Result.IntrinsicSymbols := BuildIntrinsicSymbols;
  SetLength(Result.RtlSourceUnitModels, 0);
end;

class function TDelphiSemanticCompilerProfileBuilder.DiscoverRtlSourceFiles(
  const aRtlSourceRoot: string; const aUnitNames: TArray<string>): TArray<string>;
var
  lList: TList<string>;
  lRecursiveFileIndex: TDictionary<string, string>;
  lRtlSourceRoot: string;
  lSourceFileName: string;
  lUnitName: string;
begin
  lRtlSourceRoot := NormalizeRtlSourceRoot(aRtlSourceRoot);
  lRecursiveFileIndex := nil;
  lList := TList<string>.Create;
  try
    if TDirectory.Exists(lRtlSourceRoot) then
    begin
      for lUnitName in aUnitNames do
      begin
        if TryFindRtlSourceFile(lRtlSourceRoot, lUnitName, lRecursiveFileIndex, lSourceFileName) and
          (not ContainsPath(lList, lSourceFileName)) then
          lList.Add(lSourceFileName);
      end;
    end;

    Result := lList.ToArray;
  finally
    lRecursiveFileIndex.Free;
    lList.Free;
  end;
end;

class function TDelphiSemanticCompilerProfileBuilder.ProfileForTargetFromRtlSourceRoot(
  const aCache: TDelphiSemanticUnitCache; const aCompilerProfileName, aDelphiVersion, aPlatform,
  aRtlSourceRoot: string; const aUnitNames: TArray<string>): TDelphiSemanticCompilerProfile;
var
  lSourceFileNames: TArray<string>;
begin
  lSourceFileNames := DiscoverRtlSourceFiles(aRtlSourceRoot, aUnitNames);
  Result := ProfileForTarget(aCompilerProfileName, aDelphiVersion, aPlatform, aRtlSourceRoot);
  Result.RtlSourceUnitModels := FromRtlSourceRootForPlatform(aCache, aCompilerProfileName, aPlatform,
    lSourceFileNames).RtlSourceUnitModels;
end;

class function TDelphiSemanticCompilerProfileBuilder.ResolveBdsRoot(const aDelphiVersion,
  aRsVarsPath: string): string;
var
  lDelphiVersion: string;
  lProgramFilesX86: string;
begin
  Result := Trim(aRsVarsPath);
  if Result <> '' then
    Exit(TPath.GetFullPath(ExtractFileDir(ExtractFileDir(Result))));

  Result := Trim(GetEnvironmentVariable('BDS'));
  if Result <> '' then
    Exit(TPath.GetFullPath(Result));

  lDelphiVersion := NormalizeDelphiVersion(aDelphiVersion);
  if lDelphiVersion = '' then
    lDelphiVersion := '23.0';
  if TryReadBdsRootFromRegistry(lDelphiVersion, Result) then
    Exit(TPath.GetFullPath(Result));

  lProgramFilesX86 := Trim(GetEnvironmentVariable('ProgramFiles(x86)'));
  if lProgramFilesX86 = '' then
    lProgramFilesX86 := 'C:\Program Files (x86)';
  Result := TPath.Combine(lProgramFilesX86, 'Embarcadero');
  Result := TPath.Combine(Result, 'Studio');
  Result := TPath.Combine(Result, lDelphiVersion);
end;

class function TDelphiSemanticCompilerProfileBuilder.ResolveRtlSourceRoot(const aDelphiVersion,
  aRsVarsPath: string): string;
var
  lBdsRoot: string;
begin
  lBdsRoot := ResolveBdsRoot(aDelphiVersion, aRsVarsPath);
  if lBdsRoot = '' then
    Exit('');

  Result := NormalizeRtlSourceRoot(TPath.Combine(lBdsRoot, 'source'));
end;

end.
