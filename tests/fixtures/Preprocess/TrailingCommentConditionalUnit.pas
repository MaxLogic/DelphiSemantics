unit TrailingCommentConditionalUnit;

interface

{$IFDEF ACTIVE_FEATURE}
type
  TActiveTrailingType = class end;
{$ELSE !ACTIVE_FEATURE}
type
  TInactiveTrailingType = class end;
{$ENDIF ACTIVE_FEATURE}

{$IFDEF INACTIVE_FEATURE}
type
  TInactiveSecondTrailingType = class end;
{$ELSE !INACTIVE_FEATURE}
type
  TElseTrailingType = class end;
{$ENDIF INACTIVE_FEATURE}

implementation

end.
