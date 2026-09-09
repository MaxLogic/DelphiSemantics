unit IntrinsicBodyCastsUnit;

interface

type
  TBodyCastRecord = record
    Number: Double;
    IntValue: Integer;
    Ptr: Pointer;
  end;

procedure WriteDouble(var aReceiver: TBodyCastRecord; var aValue; const aRun: Boolean);
procedure WritePointer(var aReceiver: TBodyCastRecord; var aValue; const aRun: Boolean);
procedure WriteInteger(var aReceiver: TBodyCastRecord; var aValue; const aRun: Boolean);
procedure ReadPointer(var aReceiver: TBodyCastRecord; var aResult: Pointer; const aRun: Boolean);

implementation

procedure WriteDouble(var aReceiver: TBodyCastRecord; var aValue; const aRun: Boolean);
begin
  if aRun then
    with aReceiver do
    begin
      Double(aValue) := Number
    end;
end;

procedure WritePointer(var aReceiver: TBodyCastRecord; var aValue; const aRun: Boolean);
begin
  if aRun then
    with aReceiver do
    begin
      Pointer(aValue) := Ptr
    end;
end;

procedure WriteInteger(var aReceiver: TBodyCastRecord; var aValue; const aRun: Boolean);
begin
  if aRun then
    with aReceiver do
    begin
      Integer(aValue) := IntValue
    end;
end;

procedure ReadPointer(var aReceiver: TBodyCastRecord; var aResult: Pointer; const aRun: Boolean);
begin
  if aRun then
    with aReceiver do
    begin
      aResult := Pointer(Ptr)
    end;
end;

end.
