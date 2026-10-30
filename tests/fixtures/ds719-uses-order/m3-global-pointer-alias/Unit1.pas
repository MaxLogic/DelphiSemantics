unit Unit1;
interface
uses A, DsrU719;
procedure Run;
implementation
var
  GP: PRec;
  Extra: Integer;
procedure Run;
begin
  Extra := 0;
  New(GP);
  with GP^ do
  begin
    Value := 1;
    Extra := 5;
  end;
  Writeln(SizeOf(GP^), ' ', Extra);
end;
end.
