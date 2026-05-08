unit ConditionalModelUnit;

interface

{$IFDEF ACTIVE_MODEL}
type
  TActiveModelType = class end;
{$ELSE}
type
  TInactiveModelType = class end;
{$ENDIF}

{$IFNDEF ACTIVE_MODEL}
type
  TDuplicateModelType = class end;
{$ENDIF}

{$IFDEF ACTIVE_MODEL}
type
  TDuplicateModelType = record
    Value: Integer;
  end;
{$ENDIF}

implementation

end.
