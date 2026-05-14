unit NestedAnonymousRecordUnit;

interface

type
  DBF_File = record
    FileName: string;
    Struktur: packed record
      Version: Byte;
      RecSize: Integer;
    end;
    OtherField: Integer;
  end;

implementation

end.
