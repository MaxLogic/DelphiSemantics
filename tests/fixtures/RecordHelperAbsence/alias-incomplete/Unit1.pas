unit Unit1;
interface
type
  TRec = record
    Value: Integer;
  end;
  TAlias = TRec;
  THelp = record helper for TAlias
    function GetCount: Integer;
    property
      lCount: Integer read GetCount;
  end;
procedure Run;
implementation
function THelp.GetCount: Integer;
begin Result := 7; end;
procedure Run;
var
  lRec: TRec;
  lCount: Integer;
begin
  lCount := 13;
  lRec.Value := 2;
  with lRec do Value := lCount;
  Writeln(lRec.Value, ':', lCount);
end;
end.
