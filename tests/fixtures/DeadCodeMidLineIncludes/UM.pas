unit UM;

interface

procedure Pub;

implementation

{$I dead.inc} // helpers

procedure DeadOneWrap;
begin
end;

procedure Pub;
begin
  UsedHelper;
  DeadOneWrap;
end;

end.
