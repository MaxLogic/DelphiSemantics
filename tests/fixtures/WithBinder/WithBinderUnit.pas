unit WithBinderUnit;

interface

type
  TFirstRecord = record
    Shared: Integer;
    FirstOnly: Integer;
  end;

  TSecondRecord = record
    Shared: Integer;
    SecondOnly: Integer;
  end;

procedure RunWithBinder(const aParamValue: Integer);

procedure RunNestedBinder;

implementation

procedure RunWithBinder(const aParamValue: Integer);
var
  lFirst: TFirstRecord;
  lSecond: TSecondRecord;
  lLocalValue: Integer;
begin
  with lFirst do
  begin
    FirstOnly := aParamValue;
    lLocalValue := Shared;
    lSecond.SecondOnly := 2;
    // PhantomMember := 3;
    { BracePhantom := 4; }
    (* ParenPhantom := 5; *)
    FirstOnly[0] := 6;
    lLocalValue := Length('FirstOnly');
    MissingValue := 1;
  end;

  with lFirst, lSecond do
  begin
    Shared := SecondOnly + FirstOnly;
  end;

  with MissingReceiver do
    MissingMember := 1;

  with lFirst do
  begin
    with lSecond do
    begin
      FirstOnly := SecondOnly;
    end;
  end;
end;

procedure RunSiblingBinder;
var
  lSiblingReceiver: TFirstRecord;
begin
  lSiblingReceiver.FirstOnly := 11;
end;

procedure RunNestedBinder;
var
  lOuterReceiver: TFirstRecord;

  procedure InnerWithScope;
  var
    lInnerValue: Integer;
  begin
    lInnerValue := 7;
    with lOuterReceiver do
      FirstOnly := lInnerValue;
    with lSiblingReceiver do
      FirstOnly := 9;
  end;

begin
  InnerWithScope;
end;

end.
