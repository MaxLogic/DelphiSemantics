unit PropertyChainUnit;

interface

type
  TChainLeaf = record
    Count: Integer;
  end;

  TChainParent = record
    Child: TChainLeaf;
  end;

  PChainParent = ^TChainParent;

procedure RewritePropertyChain(const aParent: PChainParent);

implementation

procedure RewritePropertyChain(const aParent: PChainParent);
begin
  with aParent^.Child do
    Count := Count + 1;
end;

end.
