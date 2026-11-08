unit UCertified;
interface
uses System.Classes;
type
  TBaseDM = class(TDataModule)
    procedure DMCreate(Sender: TObject);
  end;
var SharedValue: Integer;
implementation
procedure TBaseDM.DMCreate(Sender: TObject);
begin
  SharedValue := 4;
end;
end.
