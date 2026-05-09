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
  end;

implementation

uses
  System.Hash, System.StrUtils, System.SysUtils;

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
  AddIntrinsic(Result, 'Pointer', 'intrinsic-type', 'Pointer', 'compiler', 'type Pointer',
    'compiler intrinsic type');
  AddIntrinsic(Result, 'Single', 'intrinsic-type', 'Single', 'compiler', 'type Single',
    'compiler intrinsic type');
  AddIntrinsic(Result, 'string', 'intrinsic-type', 'string', 'compiler', 'type string',
    'compiler intrinsic type');
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

class function TDelphiSemanticCompilerProfileBuilder.ProfileForTarget(
  const aCompilerProfileName, aDelphiVersion, aPlatform, aRtlSourceRoot: string):
  TDelphiSemanticCompilerProfile;
begin
  Result := Default(TDelphiSemanticCompilerProfile);
  Result.Name := NormalizePart(aCompilerProfileName, 'default');
  Result.DelphiVersion := NormalizePart(aDelphiVersion, 'unknown');
  Result.Platform := NormalizePart(aPlatform, 'Win32');
  Result.RtlSourceRoot := Trim(aRtlSourceRoot);
  Result.IntrinsicSeedVersion := cIntrinsicSeedVersion;
  Result.ProfileKey := StableHash('compiler-profile|' + cProfileSchemaVersion + '|' +
    cIntrinsicSeedVersion + '|' + LowerCase(Result.DelphiVersion) + '|' +
    LowerCase(Result.Platform) + '|' + LowerCase(Result.RtlSourceRoot));
  Result.IntrinsicSymbols := BuildIntrinsicSymbols;
  SetLength(Result.RtlSourceUnitModels, 0);
end;

end.
