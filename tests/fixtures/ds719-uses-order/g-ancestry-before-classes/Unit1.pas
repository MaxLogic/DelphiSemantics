unit Unit1;
interface
uses WrongUnit, System.Classes;
type
 TFoo = class(TComponent)
 public
  Mine: Integer;
 end;
var
 Extra: Integer = 0;
procedure Run;
implementation
procedure Run;
var F: TFoo;
begin
  F := TFoo.Create(nil);
  with F do
  begin
    Mine := 1;
    Extra := 5;
  end;
  Writeln(F.Mine, ' ', Extra);
  F.Free;
end;
end.
