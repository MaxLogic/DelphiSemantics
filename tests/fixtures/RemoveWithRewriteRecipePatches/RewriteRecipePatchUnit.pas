unit RewriteRecipePatchUnit;

interface

type
  TLowFile = record
    _FileSize: Integer;
  end;

  PLowFile = ^TLowFile;

  TDbFile = record
    f: PLowFile;
    FileSize: Integer;
  end;

  PDbFile = ^TDbFile;

var
  Files: array[0..10] of PDbFile;

procedure RecipePatchRead(const D: Integer);
procedure ReadNBytes(var aFile: TLowFile; const aOffset: Integer;
  const aSize: Integer; var aValue: Integer; const aCode: Integer);

implementation

procedure ReadNBytes(var aFile: TLowFile; const aOffset: Integer;
  const aSize: Integer; var aValue: Integer; const aCode: Integer);
begin
  aValue := aFile._FileSize + aOffset + aSize + aCode;
end;

procedure RecipePatchRead(const D: Integer);
begin
  with Files[D]^ do
    ReadNBytes(f^, 0, 4, FileSize, 0);
end;

end.
