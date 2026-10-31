unit Unit1;
interface
type
  IFoo = interface(IInterface)
    ['{96D02671-2EA3-4DBC-B72B-000000000002}']
  end;
  TFoo = class(TInterfacedObject, IFoo)
    function _AddRef: Integer; stdcall;
    function _Release: Integer; stdcall;
  end;
procedure Run;
implementation
var G: Integer;
function TFoo._AddRef: Integer;
begin
  Writeln('addref');
  Result := inherited _AddRef;
end;
function TFoo._Release: Integer;
begin
  Writeln('release');
  Result := inherited _Release;
end;
procedure Run;
var lValue: IFoo;
begin
  lValue := TFoo.Create;
  Writeln('before');
  with lValue do G := 7;
  Writeln('after ', G);
end;
end.
