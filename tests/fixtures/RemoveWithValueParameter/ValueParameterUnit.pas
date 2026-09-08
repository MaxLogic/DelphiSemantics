unit ValueParameterUnit;

interface

type
  TValueRecord = record
    Value: Integer;
    aDelta: Integer;
  end;

procedure Update(aRecord: TValueRecord; aStep: Integer; out aObserved: Integer);
procedure Shadow(aRecord: TValueRecord; aDelta: Integer; out aObserved: Integer);

implementation

procedure Update(aRecord: TValueRecord; aStep: Integer; out aObserved: Integer);
begin
  with aRecord do
  begin
    Value := Value + aStep;
    aObserved := Value;
  end;
end;

procedure Shadow(aRecord: TValueRecord; aDelta: Integer; out aObserved: Integer);
begin
  with aRecord do
  begin
    aObserved := aDelta;
  end;
end;

end.
