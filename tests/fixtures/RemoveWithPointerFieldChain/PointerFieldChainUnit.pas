unit PointerFieldChainUnit;

interface

type
  PQueueNode = ^TQueueNode;
  TQueueNode = record
    Next: PQueueNode;
    Last: PQueueNode;
  end;

procedure AppendQueue(const aNode: PQueueNode);

implementation

var
  Queue: PQueueNode;

procedure AppendQueue(const aNode: PQueueNode);
begin
  with aNode^ do
    if Queue = nil then
    begin
      Next := aNode;
      Last := aNode;
      Queue := aNode;
    end
    else begin
      Next := Queue;
      Last := Queue^.Last;
      Last^.Next := aNode;
      Next^.Last := aNode;
      Queue := aNode;
    end;
end;

end.
