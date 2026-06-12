unit System.SemanticRtl;

interface

type
  TRtlBase = class
  end;

  TRtlChild = class(TRtlBase)
  private
    FValue: Integer;
    function GetItem(const aIndex: Integer): string;
  public
    function Pick(const aValue: Integer): Integer; overload;
    function Pick(const aText: string): string; overload;
    property Items[const aIndex: Integer]: string read GetItem; default;
  end;

  TRtlLifecycle = class
  public
    constructor Create;
    destructor Destroy; override;
  end;

  TRtlClassLifecycle = class
  public
    class constructor Create;
    class destructor Destroy;
  end;

  TRtlRecord = record
    Value: Integer;
  end;

  TRtlRecordHelper = record helper for TRtlRecord
    property HelperValue: Integer read Value;
  end;

  TRtlClassHelper = class helper for TRtlChild
    procedure HelperMethod;
  end;

  TRtlForward = class;

  TRtlEnum = (reOne, reAssigned = 7, reTwo);

  TRtlCommentedEnum = (
    rceOne, // comment
    rceTwo
  );

const
  RtlPlainConst = 1;
  RtlTypedConst: Integer = 2;

resourcestring
  rsRtlMessage = 'message';

var
  RtlGlobal: Integer;

threadvar
  RtlThreadGlobal: Integer;

function RtlProjectValue(const aValue: Integer): Integer;
function RtlOverloaded(const aValue: Integer): Integer; overload;
function RtlOverloaded(const aText: string): string; overload;

implementation

type
  TImplementationOnly = class
  end;

const
  ImplementationOnlyConst = 99;

var
  ImplementationOnlyGlobal: Integer;

constructor TRtlLifecycle.Create;
begin
  inherited Create;
end;

destructor TRtlLifecycle.Destroy;
begin
  inherited Destroy;
end;

class constructor TRtlClassLifecycle.Create;
begin
end;

class destructor TRtlClassLifecycle.Destroy;
begin
end;

function TRtlChild.GetItem(const aIndex: Integer): string;
begin
  Result := '';
end;

function TRtlChild.Pick(const aValue: Integer): Integer;
begin
  Result := aValue;
end;

function TRtlChild.Pick(const aText: string): string;
begin
  Result := aText;
end;

procedure TRtlClassHelper.HelperMethod;
begin
end;

function ImplementationOnlyRoutine: Integer;
begin
  Result := ImplementationOnlyConst + ImplementationOnlyGlobal;
end;

function RtlProjectValue(const aValue: Integer): Integer;
begin
  Result := aValue;
end;

function RtlOverloaded(const aValue: Integer): Integer;
begin
  Result := aValue;
end;

function RtlOverloaded(const aText: string): string;
begin
  Result := aText;
end;

end.
