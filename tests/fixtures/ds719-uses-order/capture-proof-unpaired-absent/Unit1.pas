unit Unit1;
interface
procedure Run;
implementation
uses A, U;
procedure Run;
begin
  Receiver.Data := 7;
  with Receiver do Writeln(Data);
end;
end.
