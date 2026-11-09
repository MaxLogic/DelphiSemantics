unit UCertified;
interface
type
  IRun = interface
    ['{6F1D2C1E-6C0B-4E5B-9A7E-1D2B3C4D5E6F}']
    procedure Run;
  end;
  TBase = class(TInterfacedObject)
  public
    procedure Run;
  end;
  TImpl = class(TBase, IRun)
  public
    procedure Run;
  end;
var
  SharedValue: Integer;
procedure Touch;
implementation
procedure TBase.Run;
begin
  SharedValue := 1000;
end;
procedure TImpl.Run;
begin
  SharedValue := 4;
end;
procedure Touch;
var
  l: IRun;
begin
  l := TImpl.Create;
  l.Run;
end;
end.
