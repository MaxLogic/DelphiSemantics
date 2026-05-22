unit RenameForwardCommentConsumerUnit;

interface

uses
  RenameForwardCommentProviderUnit;

procedure UseForwardAfterCommentedRecord;

implementation

procedure UseForwardAfterCommentedRecord;
var
  lValue: TForwardSet;
begin
  lValue := ForwardAfterCommentedRecord(1);
end;

end.
