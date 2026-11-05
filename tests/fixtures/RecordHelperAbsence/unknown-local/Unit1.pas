unit Unit1;
interface
type
  TRec = record
    Value: Integer;
  end;
{$IFOPT R+}
  THelp = record helper for TRec
    function GetCount: Integer;
    property lCount: Integer read GetCount;
  end;
{$ENDIF}
procedure Run;
implementation
{$IFOPT R+}
function THelp.GetCount: Integer;
begin Result := 7; end;
{$ENDIF}
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
