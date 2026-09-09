unit InlineLexerUnit;
interface
type
  TItem = record
    n: Integer;
    On: Integer;
  end;
procedure RunOn(var aValue: TItem);
procedure RunConditional(var aValue: TItem);
implementation
{$DEFINE INLINE_DECL_ACTIVE}
procedure RunOn(var aValue: TItem);
begin
  with aValue do
  begin
    n := 1;
    On := 2;
    n := On + 3;
  end;
end;
procedure RunConditional(var aValue: TItem);
begin
  with aValue do
  begin
{$IFDEF INLINE_DECL_ACTIVE}
    var n: Integer;
{$ENDIF}
    n := n + 1;
  end;
end;
end.
