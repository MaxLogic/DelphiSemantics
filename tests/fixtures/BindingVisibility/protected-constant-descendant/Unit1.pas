unit Unit1;
interface
uses Unit2;
type TD = class(TC) public procedure Execute; end;
procedure Run;
implementation
const Count = 17;
procedure TD.Execute;
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
var lObject: TD;
begin
  lObject := TD.Create; try lObject.Execute; finally lObject.Free; end;
end;
end.
