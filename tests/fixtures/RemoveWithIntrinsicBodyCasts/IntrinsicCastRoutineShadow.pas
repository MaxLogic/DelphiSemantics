unit IntrinsicCastRoutineShadow;

interface

uses
  IntrinsicBodyCastsUnit;

procedure ObserveRoutine(var aReceiver: TBodyCastRecord; var aResult: Integer);

implementation

function Double(const aValue: Integer): Integer;
begin
  Result := aValue + 100;
end;

procedure ObserveRoutine(var aReceiver: TBodyCastRecord; var aResult: Integer);
begin
  with aReceiver do
  begin
    aResult := Double(IntValue)
  end;
end;

end.
