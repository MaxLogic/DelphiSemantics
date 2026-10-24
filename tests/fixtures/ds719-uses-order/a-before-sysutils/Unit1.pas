unit Unit1;
interface
uses Unit2, Winapi.Windows, System.SysUtils;
var
 G: Integer = 0;
 FindData: TWin32FindData;
procedure Run;
implementation
procedure Run;
var SR: TSearchRec;
begin
  FillChar(SR, SizeOf(SR), 0);
  SR.Name := 'abc';
  with SR do
  begin
    FindData.dwFileAttributes := 7;
  end;
  Writeln(SR.FindData.dwFileAttributes, ' ', FindData.dwFileAttributes);
end;
end.
