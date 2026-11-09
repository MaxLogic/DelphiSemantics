unit DelphiSemantics.WithBinding.Budget;

interface

uses
  System.SysUtils;

const
  cDefaultWithInventoryRecordLimit = 1000000;
  cWithInventoryBudgetExceeded = 'WITH_INVENTORY_BUDGET_EXCEEDED';

type
  EDelphiSemanticWithInventoryBudget = class(EInvalidOpException);

function WithInventoryRecordLimit(const aOverride: Integer): Integer;
procedure RequireWithInventoryBudget(const aCount: Int64; const aLimit: Integer;
  const aStage: string);
procedure RequireCombinedInventoryBudget(const aPayload: string; const aLimit: Integer);

implementation

uses
  System.Classes, System.JSON.Readers, System.JSON.Types;

function WithInventoryRecordLimit(const aOverride: Integer): Integer;
begin
  if aOverride < 0 then
    raise EArgumentOutOfRangeException.Create('WITH record limit must be zero (default) or positive.');
  Result := aOverride;
  if Result = 0 then
    Result := cDefaultWithInventoryRecordLimit;
end;

procedure RequireWithInventoryBudget(const aCount: Int64; const aLimit: Integer;
  const aStage: string);
var
  lLimit: Integer;
begin
  lLimit := WithInventoryRecordLimit(aLimit);
  if aCount > lLimit then
    raise EDelphiSemanticWithInventoryBudget.CreateFmt(
      '%s: limit=%d records, count=%d records at %s; whole-project coverage is incomplete. ' +
      'No partial plan is available. Raise the explicit record limit only with sufficient memory.',
      [cWithInventoryBudgetExceeded, lLimit, aCount, aStage]);
end;

procedure RequireCombinedInventoryBudget(const aPayload: string; const aLimit: Integer);
var
  lArrayDepth: Integer;
  lCount: Int64;
  lReader: TJsonTextReader;
  lText: TStringReader;
begin
  // Admission precedes RTTI deserialization: a larger cached override cannot
  // allocate its symbol array before this request's limit has been checked.
  // The deserializer accepts case variants and duplicate property names. Count
  // every root array slot across them before canonical validation can reject it.
  lText := TStringReader.Create(aPayload);
  try
    lReader := TJsonTextReader.Create(lText);
    try
      lArrayDepth := -1;
      lCount := 0;
      while lReader.Read do
      begin
        if (lReader.TokenType = TJsonToken.PropertyName) and
          (lReader.Depth = 1) and SameText(lReader.Value.AsString, 'Symbols') then
        begin
          lArrayDepth := -1;
          if lReader.Read and (lReader.TokenType = TJsonToken.StartArray) then
            lArrayDepth := lReader.Depth;
        end else if lArrayDepth >= 0 then
        begin
          if (lReader.TokenType = TJsonToken.EndArray) and
            (lReader.Depth = lArrayDepth) then
            lArrayDepth := -1
          else if (lReader.Depth = lArrayDepth + 1) and
            not (lReader.TokenType in [TJsonToken.EndObject, TJsonToken.EndArray,
              TJsonToken.Comment]) then
          begin
            Inc(lCount);
            RequireWithInventoryBudget(lCount, aLimit, 'cached combined inventory');
          end;
        end;
      end;
    finally
      lReader.Free;
    end;
  finally
    lText.Free;
  end;
end;

end.
