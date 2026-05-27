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
    class function ProfileForTargetFromRtlSourceRoot(const aCache: TDelphiSemanticUnitCache;
      const aCompilerProfileName, aDelphiVersion, aPlatform, aRtlSourceRoot: string;
      const aUnitNames: TArray<string>): TDelphiSemanticCompilerProfile; static;
    class function ResolveBdsRoot(const aDelphiVersion, aRsVarsPath: string): string; static;
    class function ResolveRtlSourceRoot(const aDelphiVersion, aRsVarsPath: string): string; static;
  end;

implementation

uses
  System.Classes, System.Generics.Collections, System.Hash, System.IOUtils,
  System.RegularExpressions, System.StrUtils, System.SysUtils,
  System.Win.Registry,
  Winapi.Windows,
  MaxLogic.StrUtils,
  DelphiSemantics.Preprocess, DelphiSemantics.Source;

const
  cIntrinsicSeedVersion = 'delphi-intrinsics-v1';
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
  AddIntrinsic(Result, 'Assigned', 'intrinsic-routine', 'Boolean', 'compiler',
    'function Assigned(P): Boolean', 'compiler intrinsic');
  AddIntrinsic(Result, 'Assert', 'intrinsic-routine', '', 'compiler',
    'procedure Assert(Expression: Boolean)', 'compiler intrinsic');
  AddIntrinsic(Result, 'Break', 'intrinsic-routine', '', 'compiler', 'procedure Break',
    'compiler intrinsic');
  AddIntrinsic(Result, 'Continue', 'intrinsic-routine', '', 'compiler', 'procedure Continue',
    'compiler intrinsic');
  AddIntrinsic(Result, 'Copy', 'intrinsic-routine', '', 'compiler',
    'function Copy(S; Index, Count: Integer)', 'compiler intrinsic');
  AddIntrinsic(Result, 'Dec', 'intrinsic-routine', '', 'compiler',
    'procedure Dec(var X; N: Integer = 1)', 'compiler intrinsic');
  AddIntrinsic(Result, 'Default', 'intrinsic-routine', 'T', 'compiler', 'function Default(T): T',
    'compiler intrinsic');
  AddIntrinsic(Result, 'Dispose', 'intrinsic-routine', '', 'compiler', 'procedure Dispose(P)',
    'compiler intrinsic');
  AddIntrinsic(Result, 'Exclude', 'intrinsic-routine', '', 'compiler',
    'procedure Exclude(var S; I)', 'compiler intrinsic');
  AddIntrinsic(Result, 'Exit', 'intrinsic-routine', '', 'compiler', 'procedure Exit',
    'compiler intrinsic');
  AddIntrinsic(Result, 'FillChar', 'intrinsic-routine', '', 'compiler',
    'procedure FillChar(var X; Count: NativeInt; Value)', 'compiler intrinsic');
  AddIntrinsic(Result, 'FreeAndNil', 'intrinsic-routine', '', 'rtl',
    'procedure FreeAndNil(var Obj)', 'RTL helper');
  AddIntrinsic(Result, 'High', 'intrinsic-routine', '', 'compiler', 'function High(X)',
    'compiler intrinsic');
  AddIntrinsic(Result, 'Inc', 'intrinsic-routine', '', 'compiler',
    'procedure Inc(var X; N: Integer = 1)', 'compiler intrinsic');
  AddIntrinsic(Result, 'Include', 'intrinsic-routine', '', 'compiler',
    'procedure Include(var S; I)', 'compiler intrinsic');
  AddIntrinsic(Result, 'IOResult', 'intrinsic-routine', 'Integer', 'compiler',
    'function IOResult: Integer', 'compiler/RTL intrinsic');
  AddIntrinsic(Result, 'Length', 'intrinsic-routine', 'Integer', 'compiler',
    'function Length(S): Integer', 'compiler intrinsic');
  AddIntrinsic(Result, 'Low', 'intrinsic-routine', '', 'compiler', 'function Low(X)',
    'compiler intrinsic');
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
  AddIntrinsic(Result, 'Pred', 'intrinsic-routine', '', 'compiler', 'function Pred(X)',
    'compiler intrinsic');
  AddIntrinsic(Result, 'Random', 'intrinsic-routine', 'Integer', 'compiler',
    'function Random([Range: Integer]): Integer', 'compiler/RTL intrinsic');
  AddIntrinsic(Result, 'Read', 'intrinsic-routine', '', 'System', 'procedure Read(var V)',
    'System routine');
  AddIntrinsic(Result, 'ReadLn', 'intrinsic-routine', '', 'System', 'procedure ReadLn(var V)',
    'System routine');
  AddIntrinsic(Result, 'Round', 'intrinsic-routine', 'Integer', 'compiler',
    'function Round(X): Integer', 'compiler/RTL intrinsic');
  AddIntrinsic(Result, 'SetLength', 'intrinsic-routine', '', 'compiler',
    'procedure SetLength(var S; NewLength: Integer)', 'compiler intrinsic');
  AddIntrinsic(Result, 'SizeOf', 'intrinsic-routine', 'NativeInt', 'compiler',
    'function SizeOf(X): NativeInt', 'compiler intrinsic');
  AddIntrinsic(Result, 'Sqr', 'intrinsic-routine', 'numeric', 'compiler', 'function Sqr(X): numeric',
    'compiler/RTL intrinsic');
  AddIntrinsic(Result, 'Succ', 'intrinsic-routine', '', 'compiler', 'function Succ(X)',
    'compiler intrinsic');
  AddIntrinsic(Result, 'System', 'intrinsic-unit', 'unit', 'compiler', 'unit System',
    'implicitly available unit');
  AddIntrinsic(Result, 'TObject', 'intrinsic-type', 'class', 'rtl', 'type TObject',
    'RTL base class');
  AddIntrinsic(Result, 'Trunc', 'intrinsic-routine', 'Integer', 'compiler',
    'function Trunc(X): Integer', 'compiler/RTL intrinsic');
  AddIntrinsic(Result, 'TypeInfo', 'intrinsic-routine', 'Pointer', 'compiler',
    'function TypeInfo(TypeIdentifier): Pointer', 'compiler intrinsic');
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
  AddIntrinsic(Result, 'Single', 'intrinsic-type', 'Single', 'compiler', 'type Single',
    'compiler intrinsic type');
  AddIntrinsic(Result, 'string', 'intrinsic-type', 'string', 'compiler', 'type string',
    'compiler intrinsic type');
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
begin
  Result := TDictionary<string, string>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
  if not TDirectory.Exists(aRtlSourceRoot) then
    Exit;

  lFiles := TDirectory.GetFiles(aRtlSourceRoot, '*.pas', TSearchOption.soAllDirectories);
  for lFile in lFiles do
  begin
    lFileName := TPath.GetFileName(lFile);
    if not Result.ContainsKey(lFileName) then
      Result.Add(lFileName, TPath.GetFullPath(lFile));
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
  Result.IntrinsicSymbols := [
    MakeIntrinsic('Length', 'intrinsic-routine', 'Integer', 'compiler',
      'function Length(S): Integer', 'compiler intrinsic'),
    MakeIntrinsic('Assigned', 'intrinsic-routine', 'Boolean', 'compiler',
      'function Assigned(P): Boolean', 'compiler intrinsic'),
    MakeIntrinsic('TObject', 'intrinsic-type', 'class', 'rtl', 'type TObject',
      'RTL base class')];
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

function StripRtlLineComment(const aLine: string): string;
var
  lCommentPos: Integer;
begin
  lCommentPos := Pos('//', aLine);
  if lCommentPos > 0 then
    Result := Trim(Copy(aLine, 1, lCommentPos - 1))
  else
    Result := Trim(aLine);
end;

function RtlSourceUnitNameFromText(const aText, aSourceFileName: string): string;
var
  lMatch: TMatch;
begin
  lMatch := TRegEx.Match(aText, '^\s*unit\s+([A-Za-z_][A-Za-z0-9_\.]*)\s*;',
    [roIgnoreCase, roMultiLine]);
  if lMatch.Success then
    Exit(lMatch.Groups[1].Value);

  Result := ChangeFileExt(TPath.GetFileName(aSourceFileName), '');
end;

function RtlInterfacePrefixText(const aText: string): string;
var
  i: Integer;
  lLines: TStringList;
  lText: string;
begin
  lLines := TStringList.Create;
  try
    lLines.Text := aText;
    for i := 0 to Pred(lLines.Count) do
    begin
      lText := StripRtlLineComment(lLines[i]);
      if SameText(lText, 'implementation') then
      begin
        while lLines.Count > i + 1 do
          lLines.Delete(lLines.Count - 1);
        Exit(lLines.Text);
      end;
    end;
  finally
    lLines.Free;
  end;

  Result := aText;
end;

function NormalizeRtlTypeCategory(const aTypeText: string): string;
var
  lText: string;
begin
  lText := Trim(aTypeText);
  if StartsText('packed ', lText) then
    lText := Trim(Copy(lText, Length('packed ') + 1, MaxInt));
  if StartsText('record', lText) then
    Exit('record');
  if StartsText('class', lText) or ContainsText(lText, ' class') then
    Exit('class');
  if StartsText('interface', lText) then
    Exit('interface');
  if StartsText('object', lText) then
    Exit('object');
  if StartsText('(', lText) then
    Exit('enum');

  Result := lText;
end;

function ExtractRtlBaseTypeName(const aTypeText: string): string;
var
  lMatch: TMatch;
begin
  lMatch := TRegEx.Match(aTypeText, '\b(?:class|interface)\s*\(\s*([A-Za-z_][A-Za-z0-9_\.]*)',
    [roIgnoreCase]);
  if lMatch.Success then
    Result := lMatch.Groups[1].Value
  else
    Result := '';
end;

function RtlMatchGroupValue(const aMatch: TMatch; const aIndex: Integer): string;
begin
  if aIndex < aMatch.Groups.Count then
    Result := aMatch.Groups[aIndex].Value
  else
    Result := '';
end;

procedure AddRtlSourceDeclaration(const aDeclarations: TList<TDelphiSemanticDeclaration>;
  const aName, aKind, aTypeName: string; const aLine: Integer; const aBaseTypeName: string = '');
var
  lDeclaration: TDelphiSemanticDeclaration;
begin
  if aName = '' then
    Exit;

  lDeclaration := Default(TDelphiSemanticDeclaration);
  lDeclaration.Name := aName;
  lDeclaration.Kind := aKind;
  lDeclaration.TypeName := aTypeName;
  lDeclaration.BaseTypeName := aBaseTypeName;
  lDeclaration.SectionKind := 'interface';
  lDeclaration.Line := aLine;
  lDeclaration.Column := 1;
  aDeclarations.Add(lDeclaration);
end;

procedure AddRtlEnumValueDeclarations(const aDeclarations: TList<TDelphiSemanticDeclaration>;
  const aOwnerName, aTypeText: string; const aLine: Integer);
var
  lEnumText: string;
  lMatch: TMatch;
  lName: string;
  lPart: string;
begin
  lMatch := TRegEx.Match(aTypeText, '\((.*?)\)', [roSingleLine]);
  if not lMatch.Success then
    Exit;

  lEnumText := lMatch.Groups[1].Value;
  for lPart in lEnumText.Split([',']) do
  begin
    lName := Trim(lPart);
    if Pos('=', lName) > 0 then
      lName := Trim(Copy(lName, 1, Pos('=', lName) - 1));
    AddRtlSourceDeclaration(aDeclarations, lName, 'enum-value', aOwnerName, aLine);
  end;
end;

function TryAddRtlConstDeclaration(const aDeclarations: TList<TDelphiSemanticDeclaration>;
  const aLine, aBlockKind: string; const aLineNumber: Integer): Boolean;
var
  lDeclarationKind: string;
  lMatch: TMatch;
  lTypeName: string;
begin
  lMatch := TRegEx.Match(aLine, '^([A-Za-z_][A-Za-z0-9_]*)\s*(?::\s*([^=]+?))?\s*=',
    [roIgnoreCase]);
  Result := lMatch.Success;
  if not Result then
    Exit;

  lTypeName := Trim(RtlMatchGroupValue(lMatch, 2));
  if SameText(aBlockKind, 'resourcestring') then
    lDeclarationKind := 'resourcestring'
  else if lTypeName <> '' then
    lDeclarationKind := 'typed-const'
  else
    lDeclarationKind := 'const';
  AddRtlSourceDeclaration(aDeclarations, lMatch.Groups[1].Value, lDeclarationKind, lTypeName,
    aLineNumber);
end;

function TryAddRtlVarDeclaration(const aDeclarations: TList<TDelphiSemanticDeclaration>;
  const aLine, aBlockKind: string; const aLineNumber: Integer): Boolean;
var
  lMatch: TMatch;
  lName: string;
begin
  lMatch := TRegEx.Match(aLine,
    '^([A-Za-z_][A-Za-z0-9_]*(?:\s*,\s*[A-Za-z_][A-Za-z0-9_]*)*)\s*:\s*([^;]+);',
    [roIgnoreCase]);
  Result := lMatch.Success;
  if not Result then
    Exit;

  for lName in lMatch.Groups[1].Value.Split([',']) do
    AddRtlSourceDeclaration(aDeclarations, Trim(lName), aBlockKind,
      Trim(RtlMatchGroupValue(lMatch, 2)), aLineNumber);
end;

procedure AddRtlSourceMember(const aMembers: TList<TDelphiSemanticMember>; const aOwnerName,
  aName, aKind, aTypeName, aSignature: string; const aLine: Integer);
var
  lMember: TDelphiSemanticMember;
begin
  if (aOwnerName = '') or (aName = '') then
    Exit;

  lMember := Default(TDelphiSemanticMember);
  lMember.OwnerName := aOwnerName;
  lMember.Name := aName;
  lMember.Kind := aKind;
  lMember.TypeName := Trim(aTypeName);
  lMember.Visibility := 'public';
  lMember.Signature := aSignature;
  lMember.Line := aLine;
  lMember.Column := 1;
  aMembers.Add(lMember);
end;

procedure AddRtlSourceRoutine(const aDeclarations: TList<TDelphiSemanticDeclaration>;
  const aRoutines: TList<TDelphiSemanticRoutine>; const aUnitName, aName, aSignature,
  aReturnType: string; const aLine: Integer);
var
  lRoutine: TDelphiSemanticRoutine;
begin
  if aName = '' then
    Exit;

  lRoutine := Default(TDelphiSemanticRoutine);
  lRoutine.Name := aName;
  lRoutine.OwnerName := aUnitName;
  lRoutine.SectionKind := 'interface';
  lRoutine.Signature := aSignature;
  lRoutine.ReturnType := Trim(aReturnType);
  lRoutine.Line := aLine;
  lRoutine.Column := 1;
  aRoutines.Add(lRoutine);
  AddRtlSourceDeclaration(aDeclarations, aName, 'routine', lRoutine.ReturnType, aLine);
end;

function TryAddRtlRoutine(const aDeclarations: TList<TDelphiSemanticDeclaration>;
  const aRoutines: TList<TDelphiSemanticRoutine>; const aUnitName, aLine: string;
  const aLineNumber: Integer): Boolean;
var
  lMatch: TMatch;
  lReturnMatch: TMatch;
  lReturnType: string;
begin
  lMatch := TRegEx.Match(aLine,
    '^(?:class\s+)?(procedure|function)\s+([A-Za-z_][A-Za-z0-9_]*)\b(.*);',
    [roIgnoreCase]);
  Result := lMatch.Success;
  if not Result then
    Exit;

  lReturnType := '';
  if SameText(lMatch.Groups[1].Value, 'function') then
  begin
    lReturnMatch := TRegEx.Match(aLine, ':\s*([^:;]+)\s*;', [roIgnoreCase]);
    if lReturnMatch.Success then
      lReturnType := lReturnMatch.Groups[1].Value;
  end;
  AddRtlSourceRoutine(aDeclarations, aRoutines, aUnitName, lMatch.Groups[2].Value, aLine,
    lReturnType, aLineNumber);
end;

function TryAddRtlMember(const aMembers: TList<TDelphiSemanticMember>; const aOwnerName,
  aLine: string; const aLineNumber: Integer): Boolean;
var
  lFieldMatch: TMatch;
  lName: string;
  lPropertyMatch: TMatch;
  lRoutineMatch: TMatch;
begin
  lPropertyMatch := TRegEx.Match(aLine,
    '^property\s+([A-Za-z_][A-Za-z0-9_]*)\s*(?:\[[^\]]+\])?\s*:\s*([^;]+);',
    [roIgnoreCase]);
  if lPropertyMatch.Success then
  begin
    AddRtlSourceMember(aMembers, aOwnerName, lPropertyMatch.Groups[1].Value, 'property',
      lPropertyMatch.Groups[2].Value, aLine, aLineNumber);
    Exit(True);
  end;

  lRoutineMatch := TRegEx.Match(aLine,
    '^(?:class\s+)?(procedure|function|constructor|destructor)\s+([A-Za-z_][A-Za-z0-9_]*)\b(.*);',
    [roIgnoreCase]);
  if lRoutineMatch.Success then
  begin
    AddRtlSourceMember(aMembers, aOwnerName, lRoutineMatch.Groups[2].Value, 'method', '',
      aLine, aLineNumber);
    Exit(True);
  end;

  lFieldMatch := TRegEx.Match(aLine,
    '^([A-Za-z_][A-Za-z0-9_]*(?:\s*,\s*[A-Za-z_][A-Za-z0-9_]*)*)\s*:\s*([^;]+);',
    [roIgnoreCase]);
  Result := lFieldMatch.Success;
  if not Result then
    Exit;

  for lName in lFieldMatch.Groups[1].Value.Split([',']) do
    AddRtlSourceMember(aMembers, aOwnerName, Trim(lName), 'field',
      lFieldMatch.Groups[2].Value, '', aLineNumber);
end;

function TryStartRtlType(const aDeclarations: TList<TDelphiSemanticDeclaration>;
  const aLine: string; const aLineNumber: Integer; out aOwnerName, aPendingEnumName: string):
  Boolean;
var
  lCategory: string;
  lKind: string;
  lMatch: TMatch;
  lTypeText: string;
begin
  aOwnerName := '';
  aPendingEnumName := '';
  lMatch := TRegEx.Match(aLine, '^([A-Za-z_][A-Za-z0-9_]*)\s*=\s*([^;\r\n]+)',
    [roIgnoreCase]);
  Result := lMatch.Success;
  if not Result then
    Exit;

  lTypeText := Trim(lMatch.Groups[2].Value);
  lCategory := NormalizeRtlTypeCategory(lTypeText);
  if MatchText(lCategory, ['class', 'interface', 'record', 'object', 'enum']) then
    lKind := 'type'
  else
    lKind := 'type-alias';

  AddRtlSourceDeclaration(aDeclarations, lMatch.Groups[1].Value, lKind, lCategory, aLineNumber,
    ExtractRtlBaseTypeName(lTypeText));
  if SameText(lCategory, 'enum') then
  begin
    if Pos(')', lTypeText) > 0 then
      AddRtlEnumValueDeclarations(aDeclarations, lMatch.Groups[1].Value, lTypeText, aLineNumber)
    else
      aPendingEnumName := lMatch.Groups[1].Value;
  end;
  if SameText(lCategory, 'class') or SameText(lCategory, 'interface') or
    SameText(lCategory, 'record') or SameText(lCategory, 'object') then
    if (not ContainsText(aLine, ' end')) and (not EndsText(';', Trim(aLine))) then
      aOwnerName := lMatch.Groups[1].Value;
end;

function BuildRtlSourceUnitModel(const aSourceFileName, aPlatform: string): TDelphiSemanticUnitModel;
var
  i: Integer;
  lDeclarations: TList<TDelphiSemanticDeclaration>;
  lBlockKind: string;
  lInInterface: Boolean;
  lLine: string;
  lLines: TStringList;
  lMembers: TList<TDelphiSemanticMember>;
  lPendingEnumName: string;
  lPendingEnumText: string;
  lOwnerName: string;
  lPreprocessOptions: TDelphiSemanticPreprocessOptions;
  lPreprocessResult: TDelphiSemanticPreprocessResult;
  lRoutines: TList<TDelphiSemanticRoutine>;
  lSourceResult: TDelphiSemanticSourceLoadResult;
  lText: string;
begin
  Result := Default(TDelphiSemanticUnitModel);
  Result.FileName := aSourceFileName;
  lSourceResult := TDelphiSemanticSourceLoader.LoadFile(aSourceFileName);
  Result.Success := lSourceResult.Success;
  Result.FileName := lSourceResult.Source.FileName;
  Result.EncodingName := lSourceResult.Source.EncodingName;
  if not lSourceResult.Success then
    Exit;

  lPreprocessOptions := Default(TDelphiSemanticPreprocessOptions);
  lPreprocessOptions.SourceFileName := aSourceFileName;
  lPreprocessOptions.SourceText := RtlInterfacePrefixText(lSourceResult.Source.Text);
  lPreprocessOptions.Defines := CompilerProfileDefinesForPlatform(aPlatform);
  lPreprocessOptions.SearchPaths := [TPath.GetDirectoryName(aSourceFileName)];
  lPreprocessResult := TDelphiSemanticPreprocessor.PreprocessFile(lPreprocessOptions);
  lText := lPreprocessResult.OutputText;
  if lText = '' then
    lText := lPreprocessOptions.SourceText;
  if (lText <> '') and (lText[1] = #$FEFF) then
    Delete(lText, 1, 1);

  Result.UnitName := RtlSourceUnitNameFromText(lText, aSourceFileName);

  lDeclarations := TList<TDelphiSemanticDeclaration>.Create;
  lMembers := TList<TDelphiSemanticMember>.Create;
  lRoutines := TList<TDelphiSemanticRoutine>.Create;
  lLines := TStringList.Create;
  try
    lLines.Text := lText;
    lInInterface := False;
    lBlockKind := '';
    lOwnerName := '';
    lPendingEnumName := '';
    lPendingEnumText := '';
    for i := 0 to Pred(lLines.Count) do
    begin
      lLine := StripRtlLineComment(lLines[i]);
      if lLine = '' then
        Continue;

      if SameText(lLine, 'interface') then
      begin
        lInInterface := True;
        Continue;
      end;
      if SameText(lLine, 'implementation') then
        Break;
      if not lInInterface then
        Continue;

      if lPendingEnumName <> '' then
      begin
        lPendingEnumText := lPendingEnumText + ' ' + lLine;
        if Pos(')', lLine) > 0 then
        begin
          AddRtlEnumValueDeclarations(lDeclarations, lPendingEnumName, lPendingEnumText, i + 1);
          lPendingEnumName := '';
          lPendingEnumText := '';
        end;
        Continue;
      end;

      if SameText(lLine, 'type') then
      begin
        lBlockKind := 'type';
        Continue;
      end;
      if MatchText(lLine, ['const', 'var', 'threadvar', 'resourcestring']) then
      begin
        lBlockKind := LowerCase(lLine);
        lOwnerName := '';
        Continue;
      end;

      if lOwnerName <> '' then
      begin
        if SameText(lLine, 'end;') or SameText(lLine, 'end') then
        begin
          lOwnerName := '';
          Continue;
        end;
        TryAddRtlMember(lMembers, lOwnerName, lLine, i + 1);
        Continue;
      end;

      if SameText(lBlockKind, 'type') then
      begin
        if TryAddRtlRoutine(lDeclarations, lRoutines, Result.UnitName, lLine, i + 1) then
        begin
          lBlockKind := '';
          Continue;
        end;
        if TryStartRtlType(lDeclarations, lLine, i + 1, lOwnerName, lPendingEnumName) and
          (lPendingEnumName <> '') then
          lPendingEnumText := lLine;
        Continue;
      end;
      if SameText(lBlockKind, 'const') or SameText(lBlockKind, 'resourcestring') then
      begin
        if TryAddRtlRoutine(lDeclarations, lRoutines, Result.UnitName, lLine, i + 1) then
        begin
          lBlockKind := '';
          Continue;
        end;
        TryAddRtlConstDeclaration(lDeclarations, lLine, lBlockKind, i + 1);
        Continue;
      end;
      if SameText(lBlockKind, 'var') or SameText(lBlockKind, 'threadvar') then
      begin
        if TryAddRtlRoutine(lDeclarations, lRoutines, Result.UnitName, lLine, i + 1) then
        begin
          lBlockKind := '';
          Continue;
        end;
        TryAddRtlVarDeclaration(lDeclarations, lLine, lBlockKind, i + 1);
        Continue;
      end;

      TryAddRtlRoutine(lDeclarations, lRoutines, Result.UnitName, lLine, i + 1);
    end;

    Result.Declarations := lDeclarations.ToArray;
    Result.Members := lMembers.ToArray;
    Result.Routines := lRoutines.ToArray;
  finally
    lLines.Free;
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
    Result.RtlSourceUnitModels[i] := aCache.GetOrBuildUnitModelWithStatus(lOptions,
      function(const aBuildOptions: TDelphiSemanticModelOptions): TDelphiSemanticUnitModel
      begin
        Result := BuildRtlSourceUnitModel(aBuildOptions.SourceFileName, aPlatform);
      end).Model;
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
