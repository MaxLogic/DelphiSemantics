unit UCertified;
interface
uses
  System.Rtti;
type
  MarkAttribute = class(TCustomAttribute)
  end;
  [Mark]
  TTarget = class
  end;
var
  SharedValue: Integer;
procedure Touch;
implementation
procedure Touch;
var
  lContext: TRttiContext;
begin
  lContext := TRttiContext.Create;
  SharedValue := Length(lContext.GetType(TTarget).GetAttributes);
end;
end.
