program RemoveWithValueParameter;

{$APPTYPE CONSOLE}

uses
  ValueParameterUnit in 'ValueParameterUnit.pas';

var
  lRecord: TValueRecord;
  lObserved: Integer;
begin
  lRecord.Value := 7;
  lRecord.aDelta := 41;
  Update(lRecord, 3, lObserved);
  if (lObserved <> 10) or (lRecord.Value <> 7) then
    Halt(1);
  Shadow(lRecord, 999, lObserved);
  if (lObserved <> 41) or (lRecord.aDelta <> 41) then
    Halt(2);
  WriteLn('PASS: record copy and receiver precedence');
end.
