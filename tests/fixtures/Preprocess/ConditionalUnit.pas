unit ConditionalUnit;

interface

{$IFDEF ACTIVE_FEATURE}
type TActiveType = class end;
{$ELSE}
type TInactiveType = class end;
{$ENDIF}

{$IFNDEF MISSING_DEFINE}
type TIfNDefType = class end;
{$ENDIF}

{$IF Defined(ACTIVE_FEATURE)}
type TIfDefinedType = class end;
{$ELSEIF Defined(OTHER_FEATURE)}
type TElseIfType = class end;
{$ELSE}
type TElseType = class end;
{$IFEND}

implementation

end.
