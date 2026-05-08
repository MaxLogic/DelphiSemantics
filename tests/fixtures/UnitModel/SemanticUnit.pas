unit SemanticUnit;

interface

uses
  System.SysUtils, Winapi.Windows;

type
  TSemanticEnum = (seOne, seTwo);
  TSemanticAlias = string;
  TSemanticRecord = record
    Value: Integer;
    Text: string;
  end;
  TSemanticClass = class
  private
    FName: string;
  public
    procedure SetName(const aValue: string);
    property Name: string read FName write SetName;
  end;
  TAfterClassType = record
    AfterValue: Integer;
  end;

const
  cSemanticConst = 1;
  PlainSemanticConst = 2;
  TypedSemanticConst: Integer = 3;

var
  GSemanticGlobal: Integer;
  SemanticGlobal: string;

procedure SemanticProcedure(const aName: string);

implementation

uses
  System.Classes;

procedure TSemanticClass.SetName(const aValue: string);
begin
  FName := aValue;
end;

procedure SemanticProcedure(const aName: string);
var
  lRecord: TSemanticRecord;
begin
  with lRecord do
  begin
    Text := 'a;b';
    Value := Length(aName);
  end;
  SemanticGlobal := IntToStr(lRecord.Value);
end;

end.
