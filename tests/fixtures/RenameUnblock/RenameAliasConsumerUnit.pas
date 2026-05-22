unit RenameAliasConsumerUnit;

interface

uses
  RenameAliasProviderUnit, {$IFDEF EXTRA_ALIAS} RenameAliasOptionalUnit, {$ENDIF} System.SysUtils;

procedure UseAlias;

implementation

PROCEDURE UseAlias;

  PROCEDURE CheckAliasFiles;
  VAR
    lAlias: TSourceAliasPtr;
  BEGIN
    lAlias := nil;
  END;

BEGIN
  CheckAliasFiles;
END;

end.
