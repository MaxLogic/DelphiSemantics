unit UCertified;
interface
type IRun = interface
procedure Run;
end;
type TBase = class(TInterfacedObject)
public
procedure Run;
end;
TDesc = class(TBase, IRun);
implementation
procedure TBase.Run; begin end;
end.
