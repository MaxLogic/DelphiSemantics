unit DeadCodeUnit;

interface

type
  TDeadCodeFixture = class
  private
    procedure PrivateUnused;
  published
    procedure Button1Click(Sender: TObject);
  public
    procedure PublicApi;
  end;

  TExternallyVisibleType = class
  end;

var
  AmbiguousGlobal: Integer;
  UsedGlobalValue: Integer;

implementation

uses
  DeadCodeOtherUnit;

var
  StaticUnusedValue: Integer;

procedure TDeadCodeFixture.PrivateUnused;
begin
end;

procedure TDeadCodeFixture.Button1Click(Sender: TObject);
begin
end;

procedure TDeadCodeFixture.PublicApi;
begin
end;

procedure MaybeDynamicHook;
begin
end;

procedure ExportedHook;
begin
end;

procedure MessageHandler(var aMessage: Integer); message 1024;
begin
end;

procedure InitializedHook;
begin
end;

procedure UseValues;
begin
  UsedGlobalValue := 1;
  AmbiguousGlobal := 2;
  MissingExternalSymbol := 3;
  ExternalOnlySymbol := 4;
end;

exports
  ExportedHook;

initialization
  InitializedHook;

end.
