unit DelphiSemantics.Api.ProjectOptions;

interface

uses
  DelphiSemantics.Api, DelphiSemantics.ProjectContext;

function ProjectOptionsFromApiOptions(const aOptions: TDelphiSemanticApiOptions):
  TDelphiSemanticOptions;

implementation

function ProjectOptionsFromApiOptions(const aOptions: TDelphiSemanticApiOptions):
  TDelphiSemanticOptions;
begin
  Result := Default(TDelphiSemanticOptions);
  Result.ProjectPath := aOptions.ProjectFileName;
  Result.Configuration := aOptions.Configuration;
  Result.Platform := aOptions.Platform;
  Result.DelphiVersion := aOptions.DelphiVersion;
  Result.RsVarsPath := aOptions.RsVarsPath;
  Result.EnvOptionsPath := aOptions.EnvOptionsPath;
  Result.EnvironmentVariables := aOptions.EnvironmentVariables;
  Result.AdditionalSourceFileNames := aOptions.AdditionalSourceFileNames;
  Result.SearchPaths := aOptions.SearchPaths;
  Result.SqliteCacheFileName := aOptions.Cache.SqliteCacheFileName;
  Result.UseLspEnrichment := aOptions.UseLspEnrichment;
  Result.ImplicitRootMemberAbsence := aOptions.ImplicitRootMemberAbsence;
end;

end.
