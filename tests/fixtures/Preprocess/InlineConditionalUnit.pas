unit InlineConditionalUnit;

interface

procedure TouchInlineConditional;

implementation

procedure TouchInlineConditional;
begin
{$IFDEF INACTIVE_FEATURE} TouchInlineConditional; {$ENDIF}
end;

type
  TAfterInlineConditional = class
  end;

end.
