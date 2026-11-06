unit Unit1;

interface

type
  TBase = class end;
  TChild = class(TBase)
  public
    Value: Integer;
  end;

procedure Run;

implementation

procedure Run;
var
  lChild: TChild;
begin
  lChild := TChild.Create;
  try
    lChild.Value := 3;
    with lChild do
      Value := Value + 1;
    Writeln(lChild.Value);
  finally
    lChild.Free;
  end;
end;
end.
