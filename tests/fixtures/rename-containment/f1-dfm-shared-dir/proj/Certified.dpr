program Certified;
{$APPTYPE CONSOLE}
uses
  System.Classes,
  UCertified in 'UCertified.pas',
  UDM in '..\shared\UDM.pas';
var
  DM: TDM;
begin
  DM := TDM.Create(nil);
  try
    WriteLn('v=', SharedValue, ' p=', Peek);
  finally
    DM.Free;
  end;
end.
