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
  repeat with lRec do with Item do begin Count := Count + 1; Other := Count; end until lRec.Item.Count = 2;
  Writeln(lRec.Count, ':', lRec.Other, ':', lRec.Item.Count, ':', lRec.Item.Other, ':', lRec.Text);
end;
end.
