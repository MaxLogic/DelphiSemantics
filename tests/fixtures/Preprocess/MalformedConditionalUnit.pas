unit MalformedConditionalUnit;

interface

{$ELSE}
type TUnmatchedElseType = class end;

{$IFDEF NEVER_CLOSED}
type TUnterminatedType = class end;

implementation

end.
