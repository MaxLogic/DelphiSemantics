unit RenameForwardCommentProviderUnit;

interface

type
  TForwardItem = record
    Value: Integer;
  end; { legacy trailing comment keeps parser honest }
  TForwardOtherItem = record
    Value: Integer;
  end; { another legacy trailing comment }
  TForwardSet = Integer;

var
  ForwardGlobal: TForwardSet;

function ForwardAfterCommentedRecord(aValue: TForwardSet): TForwardSet;

implementation

function ForwardAfterCommentedRecord(aValue: TForwardSet): TForwardSet;
begin
  ForwardAfterCommentedRecord := aValue;
end;

end.
