unit ParentRollbackUnit;

interface

function RunObservation: string;

implementation

uses
  System.SysUtils;

type
  PNode = ^TNode;
  TNode = record
    Value: Integer;
    n: PNode;
  end;

  THolder = record
    Current: PNode;
  end;

function RunObservation: string;
var
  lFirstNode: TNode;
  lHolder: THolder;
  lSecondNode: TNode;
  n: PNode;
begin
  lFirstNode := Default(TNode);
  lSecondNode := Default(TNode);
  lFirstNode.n := @lSecondNode;
  lHolder.Current := @lFirstNode;
  n := @lFirstNode;
  with lHolder do
  begin
    with Current^ do
      Value := 1;
    with n^, n^ do
      Value := 2;
  end;
  Result := Format('%d,%d', [lFirstNode.Value, lSecondNode.Value]);
end;

end.
