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
  end;

  TDelphiSemanticCompilerProfile = record
    Name: string;
    ProfileKey: string;
    IntrinsicSymbols: TArray<TDelphiSemanticIntrinsicSymbol>;
    RtlSourceUnitModels: TArray<TDelphiSemanticUnitModel>;
  end;

  TDelphiSemanticCompilerProfileBuilder = record
  public
    class function DefaultProfile(const aCompilerProfileName: string):
      TDelphiSemanticCompilerProfile; static;
    class function FromCachedSources(const aCache: TDelphiSemanticUnitCache;
      const aSourceFileNames: TArray<string>): TDelphiSemanticCompilerProfile; static;
  end;

implementation

function MakeIntrinsic(const aName, aKind, aTypeName, aOwnerName: string):
  TDelphiSemanticIntrinsicSymbol;
begin
  Result.Name := aName;
  Result.Kind := aKind;
  Result.TypeName := aTypeName;
  Result.OwnerName := aOwnerName;
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
    MakeIntrinsic('Length', 'intrinsic-routine', 'Integer', 'compiler'),
    MakeIntrinsic('Assigned', 'intrinsic-routine', 'Boolean', 'compiler'),
    MakeIntrinsic('TObject', 'intrinsic-type', 'class', 'rtl')];
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

end.
