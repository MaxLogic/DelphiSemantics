unit Unit1;
interface
procedure Run;
implementation
type TRec = record Value: Integer; end;
var Item: TRec;
procedure Work; begin with Item do Value := 7; end;
procedure Run; begin Work; Writeln(Item.Value); end;
end.
