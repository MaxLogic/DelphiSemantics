unit UCertified;
interface
type IRun = interface
procedure Run;
end;
type TC = class(TInterfacedObject, IRun)
public
procedure Exec;
procedure IRun.Run = Exec;
end;
implementation
procedure TC.Exec; begin end;
end.
