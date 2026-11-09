unit UCertified;
interface
type IRun = interface
procedure Run;
end;
type TC = class(TInterfacedObject)
public
procedure Exec;
end;
implementation
procedure TC.Exec; begin end;
end.
