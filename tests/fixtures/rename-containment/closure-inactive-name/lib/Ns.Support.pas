unit Ns.Support;
interface
uses Leaf, UCertified;
implementation
{$IFDEF RELEASE}
procedure OldConsumer;
begin
  UCertified.Counter := 1;
end;
{$ENDIF}
end.
