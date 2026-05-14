unit SourceModelGoldenUnit;

interface

const
  cGoldenVariantReal = 1;
  cGoldenVariantString = 2;

type
  TGoldenChild = record
    Name: string;
  end;

  TGoldenBase = class
  public
    BaseName: string;
    procedure Touch; virtual;
  end;

  IGoldenContract = interface
    ['{7CC46C06-55D2-44F2-8D14-A2E5E7989668}']
    procedure ContractTouch;
  end;

  TGoldenVariant = record
    Prefix: Integer;
    MultiA,
      MultiB: Integer;
    case Mode: Integer of
      cGoldenVariantReal: (RealValue, ExtraReal: Double;
        HasReal: Boolean);
      cGoldenVariantString: (TextValue: string; Offset, Size: Integer)
  end;

  TGoldenRecord = record
    RecordName: string;
    Child: TGoldenChild;
    procedure Touch;
    property RecordTitle: string read RecordName write RecordName;
  end;

  PGoldenRecord = ^TGoldenRecord;
  TGoldenRecordAlias = TGoldenRecord;

  TGoldenRecordHelper = record helper for TGoldenRecord
    procedure HelperTouch;
  end;

  TGoldenDefaultList = class
  private
    function GetItem(aIndex: Integer): PGoldenRecord;
  public
    property Items[aIndex: Integer]: PGoldenRecord read GetItem; default;
  end;

  TGoldenClass = class(TGoldenBase, IGoldenContract)
  private
    FClassRecord: TGoldenRecord;
  public
    const
      ClassLimit: Integer = 7;
    class var
      SharedCount: Integer;
    procedure ContractTouch;
    procedure Touch; override;
    property ClassRecord: TGoldenRecord read FClassRecord write FClassRecord;
  end;

  TGoldenScope = class
  private
    FScopeRecord: TGoldenRecord;
  public
    class procedure Run;
  end;

implementation

var
  {$IFDEF GOLDEN_PROTOCOL}
  GoldenProtocol: Text;
  {$ENDIF}

var
  GoldenSplitGlobal:
    Integer;
  GoldenInlineState: (gisRead, gisSkip);

procedure TGoldenBase.Touch;
begin
end;

procedure TGoldenRecord.Touch;
begin
end;

procedure TGoldenRecordHelper.HelperTouch;
begin
end;

procedure TGoldenClass.ContractTouch;
begin
end;

procedure TGoldenClass.Touch;
begin
  Inc(SharedCount);
end;

function TGoldenDefaultList.GetItem(aIndex: Integer): PGoldenRecord;
begin
  Result := nil;
end;

class procedure TGoldenScope.Run;
type
  TGoldenLocalRecord = record
    LocalName: string;
    LocalCount: Integer;
  end;
var
  lAnonymousLocal: packed record
    LocalFlag: Boolean;
    LocalText: string;
  end;
  lVariantLocal: packed record
    Len: Byte;
    case Kind: Integer of
      1: (AsInteger: Integer);
      2: (AsText: string)
  end;
  lDefaultList: TGoldenDefaultList;
  lLocalRecord: TGoldenLocalRecord;
  lObject: TGoldenClass;
  lRecord: TGoldenRecord;
  lRecordPtr: PGoldenRecord;
  lRecords: TArray<TGoldenRecord>;
  lStaticRecordPtrs: array[1..2] of PGoldenRecord;
  lStaticRecords: array [1 .. 2] of TGoldenRecord;

  procedure IgnoreNestedDeclarationBody;
  begin
  end;

type
  TGoldenLateLocalRecord = record
    LateName: string;
  end;
var
  lLateLocalRecord: TGoldenLateLocalRecord;
begin
  lRecord.RecordName := '';
  lRecord.Child.Name := lRecord.RecordName;
  lLocalRecord.LocalName := lRecord.RecordName;
  lAnonymousLocal.LocalFlag := lLocalRecord.LocalCount > 0;
  lAnonymousLocal.LocalText := lLocalRecord.LocalName;
  lVariantLocal.Len := 1;
  lVariantLocal.AsInteger := lVariantLocal.Len;
  lLateLocalRecord.LateName := lAnonymousLocal.LocalText;
  IgnoreNestedDeclarationBody;
  lRecordPtr := @lRecord;
  SetLength(lRecords, 1);
  lRecords[0] := lRecordPtr^;
  lStaticRecords[1] := lRecord;
  lStaticRecordPtrs[1] := @lRecord;
  lDefaultList := nil;
  FScopeRecord := lRecords[0];
  lObject := TGoldenClass.Create;
  try
    lObject.FClassRecord := FScopeRecord;
  finally
    lObject.Free;
  end;
end;

  type
    TGoldenIndentedState = record
      StateName: string;
    end;

  var
    GoldenIndentedState: TGoldenIndentedState;

procedure UseGoldenIndentedState;
begin
  with GoldenIndentedState do
    StateName := '';
end;

end.
