unit Provider;

interface

uses
  HiddenTypes;

type
  TVisibleItem = HiddenTypes.THiddenItem;
  PVisibleItem = ^TVisibleItem;

var
  Current: PHiddenItem;
  VisibleCurrent: PVisibleItem;
  FirstItem: THiddenItem;
  SecondItem: THiddenItem;

procedure ResetItems;
procedure SwitchReceiver;

implementation

procedure ResetItems;
begin
  FirstItem.Value := 0;
  SecondItem.Value := 0;
  Current := @FirstItem;
  VisibleCurrent := @FirstItem;
end;

procedure SwitchReceiver;
begin
  Current := @SecondItem;
  VisibleCurrent := @SecondItem;
end;

end.
