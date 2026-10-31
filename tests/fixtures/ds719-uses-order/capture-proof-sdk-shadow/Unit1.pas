unit Unit1;
interface
procedure Run;
implementation
uses A, System.Math;
procedure Run;
begin
  Receiver.Data := 7;
  with Receiver do Writeln(Data);
end;
end.
