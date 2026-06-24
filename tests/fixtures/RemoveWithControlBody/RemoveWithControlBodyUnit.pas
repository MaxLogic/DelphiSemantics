unit RemoveWithControlBodyUnit;

interface

type
  PControlMemo = ^TControlMemo;
  TControlMemo = record
    Active: Boolean;
    Code: Integer;
    Count: Integer;
    Memo: Integer;
    MemoOffset: Integer;
    Value: Integer;
  end;

procedure RepeatLeak(aItem: PControlMemo);
procedure LoopBranchLeak(aItem: PControlMemo);
procedure SafeWhileRewrite(aItem: PControlMemo);

implementation

procedure RepeatLeak(aItem: PControlMemo);
begin
  with aItem^ do
    repeat
      Memo := Code;
      Inc(MemoOffset);
    until MemoOffset >= Count;
end;

procedure LoopBranchLeak(aItem: PControlMemo);
begin
  with aItem^ do
    while Active do
      case Code of
        0:
          Memo := Memo + 1;
      else
        MemoOffset := Count;
      end;
end;

procedure SafeWhileRewrite(aItem: PControlMemo);
begin
  with aItem^ do
    while Active do
    begin
      Memo := Code;
      MemoOffset := Count;
      Active := False;
    end;
end;

end.
