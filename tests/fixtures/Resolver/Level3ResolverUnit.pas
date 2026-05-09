unit Level3ResolverUnit;

interface

type
  TAncestorRecord = record
    AncestorValue: Integer;
  end;

  TChildRecord = record
    ChildValue: string;
  end;

  TChildRecordHelper = record helper for TChildRecord
    function HelperValue: Boolean;
  end;

  TBaseClass = class
  public
    BaseValue: Integer;
  end;

  TChildClass = class(TBaseClass)
  public
    ChildText: string;
  end;

implementation

function TChildRecordHelper.HelperValue: Boolean;
begin
  Result := True;
end;

end.
