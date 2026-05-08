unit UnsupportedElseUnit;

interface

{$IF Declared(UnknownSymbol)}
type TUnsupportedIfType = class end;
{$ELSE}
type TUnsupportedIfElseType = class end;
{$IFEND}

{$IFOPT R+}
type TUnsupportedIfOptType = class end;
{$ELSE}
type TUnsupportedIfOptElseType = class end;
{$ENDIF}

implementation

end.
