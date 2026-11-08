unit UCertified;
interface
type
  TC = class
  public
    Count: Integer;
  end;
var SharedValue: Integer;
procedure Touch;
implementation
uses System.Rtti;
procedure Touch;
var
  lCtx: TRttiContext;
begin
  if lCtx.FindType('UCertified.TC') = nil then SharedValue := -1 else SharedValue := 4;
  if TC.ClassName = '' then SharedValue := 0;
end;
end.
