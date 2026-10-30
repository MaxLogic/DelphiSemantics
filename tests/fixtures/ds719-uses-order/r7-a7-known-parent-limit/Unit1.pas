unit Unit1;
interface
procedure Run;
implementation
type
  TInner = record Value: Integer; end;
  TOuter = record Other: Integer; end;
var
  Inner: TInner;
  Outer: TOuter;
procedure Run;
begin
  with Outer, Outer do
  begin
    with Inner do
      Value := 3;
  end;
  Writeln('VALUE=', Inner.Value);
end;
end.
