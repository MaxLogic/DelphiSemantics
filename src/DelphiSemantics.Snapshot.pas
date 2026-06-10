unit DelphiSemantics.Snapshot;

interface

uses
  System.Generics.Collections, MaxLogic.FastList;

type
  TSemanticStringId = Cardinal;

  TSemanticStringPool = class
  private
    fIdByText: TDictionary<string, TSemanticStringId>;
    fTextById: TSimpleList<string>;
    function GetCount: Cardinal;
  public
    constructor Create;
    destructor Destroy; override;
    function Intern(const aText: string): TSemanticStringId;
    function TextOf(const aId: TSemanticStringId): string;
    property Count: Cardinal read GetCount;
  end;

function MemberKey(const aOwnerTypeId, aNameId: Cardinal): UInt64; inline;

implementation

uses
  MaxLogic.StrUtils;

function MemberKey(const aOwnerTypeId, aNameId: Cardinal): UInt64;
begin
  Result := (UInt64(aOwnerTypeId) shl 32) or UInt64(aNameId);
end;

constructor TSemanticStringPool.Create;
begin
  inherited;
  try
    fTextById := TSimpleList<string>.Create;
    fTextById.add('');
    fIdByText := TDictionary<string, TSemanticStringId>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
    fIdByText.Add('', 0);
  except
    fIdByText.Free;
    fTextById.Free;
    raise;
  end;
end;

destructor TSemanticStringPool.Destroy;
begin
  fIdByText.Free;
  fTextById.Free;
  inherited;
end;

function TSemanticStringPool.GetCount: Cardinal;
begin
  Result := Cardinal(fTextById.Count - 1);
end;

function TSemanticStringPool.Intern(const aText: string): TSemanticStringId;
begin
  if aText = '' then
    Exit(0);

  if fIdByText.TryGetValue(aText, Result) then
    Exit;

  Result := Cardinal(fTextById.Count);
  fTextById.add(aText);
  fIdByText.Add(aText, Result);
end;

function TSemanticStringPool.TextOf(const aId: TSemanticStringId): string;
begin
  if aId < Cardinal(fTextById.Count) then
    Result := fTextById[Integer(aId)]
  else
    Result := '';
end;

end.
