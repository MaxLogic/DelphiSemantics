unit WithDiscoveryUnit;

interface

type
  TDiscoveryRecord = record
    Value: Integer;
    Shared: Integer;
  end;

procedure RunDiscovery;

implementation

procedure RunDiscovery;
var
  lFirst: TDiscoveryRecord;
  lSecond: TDiscoveryRecord;
begin
  with lFirst do
    Value := 1;

  with lFirst, lSecond do
  begin
    Shared := Value;
  end;

  with lFirst do
  begin
    with lSecond do
      Value := lFirst.Value;
  end;

  with lFirst do
  begin
    var lScoped := Value;
    Value := lScoped;
  end;

  {$IFDEF INCLUDE_INACTIVE_WITH}
  with lSecond do
    Value := 99;
  {$ENDIF}
end;

end.
