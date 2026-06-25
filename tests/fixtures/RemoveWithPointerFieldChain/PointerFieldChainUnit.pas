unit PointerFieldChainUnit;

interface

type
  PQueueNode = ^TQueueNode;
  TQueueNode = record
    last: PQueueNode;
    next: PQueueNode;
  end;
  PSelectorNode = ^TSelectorNode;
  TSelector = record
    count: Integer;
  end;
  TSelectorNode = record
    n: Pointer;
    Sel: TSelector;
  end;
  PMaskNode = ^TMaskNode;
  TMaskNode = record
    Marker: Integer;
  end;

procedure AppendQueue(aFptr: PQueueNode);
procedure DeleteQueue(aFptr: PQueueNode);
procedure ReadSelector(aNode: PSelectorNode; var aValue: Integer);
procedure ReadSelectorAndNode(aNode: PSelectorNode; var aValue: Integer);
procedure ReadSelectorAndNodeUnderOuterWith(aMask: PMaskNode;
  aNode: PSelectorNode; var aValue: Integer);

implementation

var
  Queue: PQueueNode;

procedure AppendQueue(aFptr: PQueueNode);
begin
  with aFptr^ do
    if Queue = nil then
    begin
      next := aFptr;
      last := aFptr;
      Queue := aFptr;
    end
    else begin
      next := Queue;
      last := Queue^.last;
      last^.next := aFptr;
      next^.last := aFptr;
      Queue := aFptr;
    end;
end;

procedure DeleteQueue(aFptr: PQueueNode);
begin
  with aFptr^ do
  begin
    last^.next := next;
    next^.last := last;
    if Queue = aFptr then
    begin
      Queue := next;
      if Queue = aFptr then
        Queue := nil;
    end;
  end;
end;

procedure ReadSelector(aNode: PSelectorNode; var aValue: Integer);
begin
  with aNode^, Sel do
    aValue := count;
end;

procedure ReadSelectorAndNode(aNode: PSelectorNode; var aValue: Integer);
begin
  with aNode^, Sel do
  begin
    aValue := count;
    n := nil;
  end;
end;

procedure ReadSelectorAndNodeUnderOuterWith(aMask: PMaskNode;
  aNode: PSelectorNode; var aValue: Integer);
begin
  with aMask^ do
  begin
    Inc(Marker);
    with aNode^, Sel do
    begin
      aValue := count;
      n := nil;
    end;
  end;
end;

end.
