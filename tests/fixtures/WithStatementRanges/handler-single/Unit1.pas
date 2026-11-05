unit Unit1;
interface
procedure Run;
implementation
uses System.SysUtils;
type
  TItem = record Count, Other: Integer; end;
  TRec = record Item: TItem; Count, Other: Integer; Text: string; end;
procedure Run;
var
  lRec: TRec;
begin
  lRec := Default(TRec);
  try raise Exception.Create('x'); except on E: Exception do with lRec do Count := 1; end;
  Writeln(lRec.Count, ':', lRec.Other, ':', lRec.Item.Count, ':', lRec.Item.Other, ':', lRec.Text);
end;
end.
