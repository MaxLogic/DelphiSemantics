unit DefineUndefUnit;

interface

{$DEFINE TEMP_FEATURE}
{$IFDEF TEMP_FEATURE}
type TDefinedType = class end;
{$ENDIF}

{$UNDEF TEMP_FEATURE}
{$IFDEF TEMP_FEATURE}
type TUndefinedType = class end;
{$ENDIF}

implementation

end.
