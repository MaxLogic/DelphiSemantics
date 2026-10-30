unit Unit1;
interface
uses A, DsrU719;
type
  THolder = class
    FP: PRec;
    procedure Work;
  end;
procedure Run;
implementation
var
  Extra: Integer;
procedure THolder.Work;
begin
  with FP^ do
  begin
    Value := 1;
    Extra := 5;
  end;
end;
procedure Run;
var
  H: THolder;
begin
  Extra := 0;
  H := THolder.Create;
  New(H.FP);
  H.Work;
  Writeln(SizeOf(H.FP^), ' ', Extra);
end;
end.
