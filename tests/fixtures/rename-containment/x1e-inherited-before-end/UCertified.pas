unit UCertified;
interface
type
  TBase = class
    procedure DoIt;
  end;
  TDesc = class(TBase)
    procedure DoIt;
  end;
var
  SharedValue: Integer;
procedure Touch;
implementation
procedure TBase.DoIt;
begin
  SharedValue := SharedValue + 1000;
end;
procedure TDesc.DoIt;
begin
  SharedValue := SharedValue + 4;
  inherited
end;
procedure Touch;
var
  l: TDesc;
begin
  l := TDesc.Create;
  try
    l.DoIt;
  finally
    l.Free;
  end;
end;
end.
