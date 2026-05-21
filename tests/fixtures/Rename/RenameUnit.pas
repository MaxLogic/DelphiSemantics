unit RenameUnit;

interface

type
  TRenameCollision = class
  public
    ExistingMember: Integer;
  end;

var
  GlobalQueryValue: Integer;

implementation

procedure UseGlobal;
begin
  // GlobalQueryValue in this comment must not become a rename edit.
  GlobalQueryValue := 1;
end;

procedure UseLocal;
var
  ExistingLocalName: Integer;
  GlobalQueryValue: Integer;
begin
  ExistingLocalName := 1;
  GlobalQueryValue := 2;
end;

end.
