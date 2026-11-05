unit Unit1;
interface
uses Unit2;
procedure Run;
implementation
const Count = 17;
procedure Execute;
var lObject: TC;
begin
  lObject := TC.Create;
  try
    with lObject do Other := Count;
    Writeln(lObject.Other);
  finally
    lObject.Free;
  end;
end;
procedure Run;

begin
  Execute;
end;
end.
