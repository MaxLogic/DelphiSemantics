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
  Result.CallerDefinesProvided := Length(aOptions.Defines) > 0;
  Result.Configuration := aOptions.Configuration;
  Result.Platform := aOptions.Platform;
  Result.DelphiVersion := aOptions.DelphiVersion;
  Result.RsVarsPath := aOptions.RsVarsPath;
  Result.EnvOptionsPath := aOptions.EnvOptionsPath;
  Result.EnvironmentVariables := aOptions.EnvironmentVariables;
  Result.CompilerIncludeSearchPath := aOptions.CompilerIncludeSearchPath;
  Result.CompilerIncludeSearchPathProvided := aOptions.CompilerIncludeSearchPathProvided;
  Result.AdditionalSourceFileNames := aOptions.AdditionalSourceFileNames;
  Result.SearchPaths := aOptions.SearchPaths;
  Result.SqliteCacheFileName := aOptions.Cache.SqliteCacheFileName;
  Result.PlanningCacheInputsProvided := aOptions.PlanningCacheInputsProvided;
  Result.PlanningCacheInputs := Copy(aOptions.PlanningCacheInputs);
  Result.UseLspEnrichment := aOptions.UseLspEnrichment;
  Result.ImplicitRootMemberAbsence := aOptions.ImplicitRootMemberAbsence;
end;

end.
