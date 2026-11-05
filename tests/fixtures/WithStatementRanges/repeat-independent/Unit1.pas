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
  lRec2: TRec;
begin
  lRec := Default(TRec);
  lRec2 := Default(TRec);
  repeat with lRec do with lRec2 do begin Count := Count + 1; Other := Count; end until lRec2.Count = 2;
  Writeln(lRec2.Count, ':', lRec2.Other, ':', lRec.Count, ':', lRec.Other, ':', lRec.Item.Count, ':', lRec.Item.Other, ':', lRec.Text);
end;
end.
