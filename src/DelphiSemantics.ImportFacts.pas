unit DelphiSemantics.ImportFacts;

interface

type
  // Physical owner, ordered logical uses section, selected target and uncertainty.
  // These are provenance facts, never identifier references or binding authority.
  TDelphiSemanticImportFact = record
    OwnerFileName: string;
    Name: string;
    TargetFileName: string;
    SectionKind: string;
    Cause: string;
    Unconditional: Boolean;
    GapReason: string;
    OrderIndex: Integer;
    SdkBoundary: Boolean;
    ResolutionVaries: Boolean;
  end;

function ImportFactsToJson(const aFacts: TArray<TDelphiSemanticImportFact>): string;
function JsonToImportFacts(const aJson: string): TArray<TDelphiSemanticImportFact>;

implementation

uses
  System.JSON, System.SysUtils;

function ImportFactsToJson(const aFacts: TArray<TDelphiSemanticImportFact>): string;
var
  lArray: TJSONArray;
  lObject: TJSONObject;
  lFact: TDelphiSemanticImportFact;
begin
  lArray := TJSONArray.Create;
  try
    for lFact in aFacts do
    begin
      lObject := TJSONObject.Create;
      lArray.AddElement(lObject);
      lObject.AddPair('owner', lFact.OwnerFileName);
      lObject.AddPair('name', lFact.Name);
      lObject.AddPair('target', lFact.TargetFileName);
      lObject.AddPair('section', lFact.SectionKind);
      lObject.AddPair('cause', lFact.Cause);
      lObject.AddPair('unconditional', TJSONBool.Create(lFact.Unconditional));
      lObject.AddPair('gap', lFact.GapReason);
      lObject.AddPair('order', TJSONNumber.Create(lFact.OrderIndex));
      lObject.AddPair('sdk', TJSONBool.Create(lFact.SdkBoundary));
      lObject.AddPair('varies', TJSONBool.Create(lFact.ResolutionVaries));
    end;
    Result := lArray.ToJSON;
  finally
    lArray.Free;
  end;
end;

function JsonToImportFacts(const aJson: string): TArray<TDelphiSemanticImportFact>;
var
  lValue: TJSONValue;
  lArray: TJSONArray;
  lObject: TJSONObject;
  i: Integer;
begin
  lValue := TJSONObject.ParseJSONValue(aJson);
  try
    if not (lValue is TJSONArray) then
      raise EConvertError.Create('Import provenance array is missing.');
    lArray := TJSONArray(lValue);
    SetLength(Result, lArray.Count);
    for i := 0 to lArray.Count - 1 do
    begin
      if not (lArray.Items[i] is TJSONObject) then
        raise EConvertError.Create('Invalid import provenance fact.');
      lObject := TJSONObject(lArray.Items[i]);
      Result[i].OwnerFileName := lObject.GetValue<string>('owner');
      Result[i].Name := lObject.GetValue<string>('name');
      Result[i].TargetFileName := lObject.GetValue<string>('target');
      Result[i].SectionKind := lObject.GetValue<string>('section');
      Result[i].Cause := lObject.GetValue<string>('cause');
      Result[i].Unconditional := lObject.GetValue<Boolean>('unconditional');
      Result[i].GapReason := lObject.GetValue<string>('gap');
      Result[i].OrderIndex := lObject.GetValue<Integer>('order');
      Result[i].SdkBoundary := lObject.GetValue<Boolean>('sdk');
      Result[i].ResolutionVaries := lObject.GetValue<Boolean>('varies');
      if (Result[i].OwnerFileName = '') or (Result[i].Name = '') or
        (Result[i].OrderIndex < 0) or
        ((Result[i].SectionKind <> 'interface') and (Result[i].SectionKind <> 'implementation')) then
        raise EConvertError.Create('Invalid import provenance fields.');
    end;
  finally
    lValue.Free;
  end;
end;

end.
