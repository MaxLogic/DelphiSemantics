unit Unit1;

interface

type
  TGen<T> = class
  public
    Value: Integer;
  end;

procedure Run;

implementation

procedure Run;
var
  lItem: TGen<Integer>;
begin
  lItem := TGen<Integer>.Create;
  try
    lItem.Value := 3;
    with lItem do
      Value := Value + 1;
    Writeln(lItem.Value);
  finally
    lItem.Free;
  end;
end;
end.
