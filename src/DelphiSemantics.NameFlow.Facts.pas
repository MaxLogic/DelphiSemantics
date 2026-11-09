unit DelphiSemantics.NameFlow.Facts;

{$SCOPEDENUMS ON}

interface

type
  TDelphiNameFlowNodeKind = (Syntax, Routine, Formal, ResultValue, Definition, Assignment,
    Call, PotentialCall, PropertyAccess, RaiseValue, LiteralValue, IdentifierValue, Operation, Unknown);

  TDelphiNameFlowAttribute = record
    Name, Value: string;
  end;

  TDelphiNameFlowNode = record
    Id, ParentId: Integer;
    Children: TArray<Integer>;
    Attributes: TArray<TDelphiNameFlowAttribute>;
    Kind: TDelphiNameFlowNodeKind;
    SyntaxKind, Name, Value, TypeName, ScopeId, OwnerType, FileName: string;
    // Physical UTF-16 coordinates; end is exclusive. Zero means unavailable.
    Line, Column, EndLine, EndColumn: Integer;
    // One-based, exclusive-end offsets in the exact expanded parser input.
    OutputStartOffset, OutputEndOffset: Integer;
    ExpansionId: string;
    SpanKnown, ActivityKnown, BodyComplete: Boolean;
  end;

  IDelphiNameFlowFacts = interface
    ['{FD0A1B0F-76DD-4AF8-BBB1-E9130904A16F}']
    function NodeCount: Integer;
    function NodeById(const aId: Integer): TDelphiNameFlowNode;
    function GetComplete: Boolean;
    function GetConfigurationComplete: Boolean;
    function GetCoverageReason: string;
    // Complete syntax capture never asserts complete call binding or effects.
    property Complete: Boolean read GetComplete;
    property ConfigurationComplete: Boolean read GetConfigurationComplete;
    property CoverageReason: string read GetCoverageReason;
  end;

function CreateNameFlowFacts(const aNodes: TArray<TDelphiNameFlowNode>;
  const aComplete, aConfigurationComplete: Boolean; const aReason: string): IDelphiNameFlowFacts;
function NameFlowFactsToJson(const aFacts: IDelphiNameFlowFacts): string;
function NameFlowFactsFromJson(const aJson: string): IDelphiNameFlowFacts;

implementation

uses
  System.Hash, System.JSON.Serializers, System.SysUtils,
  AutoFree;

type
  TNameFlowEnvelope = record
    Version: Integer;
    Complete, ConfigurationComplete: Boolean;
    CoverageReason, Digest: string;
    Nodes: TArray<TDelphiNameFlowNode>;
  end;

  TDelphiNameFlowFacts = class(TInterfacedObject, IDelphiNameFlowFacts)
  private
    fNodes: TArray<TDelphiNameFlowNode>;
    fComplete, fConfigurationComplete: Boolean;
    fCoverageReason: string;
  public
    constructor Create(const aNodes: TArray<TDelphiNameFlowNode>;
      const aComplete, aConfigurationComplete: Boolean; const aReason: string);
    function NodeCount: Integer;
    function NodeById(const aId: Integer): TDelphiNameFlowNode;
    function GetComplete: Boolean;
    function GetConfigurationComplete: Boolean;
    function GetCoverageReason: string;
  end;

function CopyNode(const aNode: TDelphiNameFlowNode): TDelphiNameFlowNode;
begin
  Result := aNode;
  Result.Children := Copy(aNode.Children);
  Result.Attributes := Copy(aNode.Attributes);
end;

constructor TDelphiNameFlowFacts.Create(const aNodes: TArray<TDelphiNameFlowNode>;
  const aComplete, aConfigurationComplete: Boolean; const aReason: string);
var
  i: Integer;
begin
  inherited Create;
  SetLength(fNodes, Length(aNodes));
  for i := 0 to High(aNodes) do
    fNodes[i] := CopyNode(aNodes[i]);
  fComplete := aComplete and (Length(aNodes) > 0);
  fConfigurationComplete := aConfigurationComplete;
  fCoverageReason := aReason;
  if not fComplete and (fCoverageReason = '') then
    fCoverageReason := 'name-flow-facts-missing';
end;

function TDelphiNameFlowFacts.NodeCount: Integer;
begin
  Result := Length(fNodes);
end;

function TDelphiNameFlowFacts.NodeById(const aId: Integer): TDelphiNameFlowNode;
begin
  if (aId < 1) or (aId > Length(fNodes)) then
    raise EArgumentOutOfRangeException.Create('Name-flow fact ID out of range');
  Result := CopyNode(fNodes[aId - 1]);
end;

function TDelphiNameFlowFacts.GetComplete: Boolean;
begin
  Result := fComplete;
end;

function TDelphiNameFlowFacts.GetConfigurationComplete: Boolean;
begin
  Result := fConfigurationComplete;
end;

function TDelphiNameFlowFacts.GetCoverageReason: string;
begin
  Result := fCoverageReason;
end;

function CreateNameFlowFacts(const aNodes: TArray<TDelphiNameFlowNode>;
  const aComplete, aConfigurationComplete: Boolean; const aReason: string): IDelphiNameFlowFacts;
begin
  Result := TDelphiNameFlowFacts.Create(aNodes, aComplete, aConfigurationComplete, aReason);
end;

function NameFlowFactsToJson(const aFacts: IDelphiNameFlowFacts): string;
var
  i: Integer;
  lEnvelope: TNameFlowEnvelope;
  lSerializer: TJsonSerializer;
  g: TGarbos;
begin
  lEnvelope := Default(TNameFlowEnvelope);
  lEnvelope.Version := 202;
  if aFacts <> nil then
  begin
    lEnvelope.Complete := aFacts.Complete;
    lEnvelope.ConfigurationComplete := aFacts.ConfigurationComplete;
    lEnvelope.CoverageReason := aFacts.CoverageReason;
    SetLength(lEnvelope.Nodes, aFacts.NodeCount);
    for i := 1 to aFacts.NodeCount do
      lEnvelope.Nodes[i - 1] := aFacts.NodeById(i);
  end else
    lEnvelope.CoverageReason := 'name-flow-facts-missing';
  GC(lSerializer, TJsonSerializer.Create, g);
  lEnvelope.Digest := THashSHA2.GetHashString(lSerializer.Serialize<TNameFlowEnvelope>(lEnvelope));
  Result := lSerializer.Serialize<TNameFlowEnvelope>(lEnvelope);
end;

function ValidNodes(const aNodes: TArray<TDelphiNameFlowNode>): Boolean;
var
  i, j, lChild: Integer;
  lSeen: TArray<Boolean>;
begin
  Result := False;
  SetLength(lSeen, Length(aNodes));
  for i := 0 to High(aNodes) do
  begin
    if (aNodes[i].Id <> i + 1) or (aNodes[i].SyntaxKind = '') or
      (Ord(aNodes[i].Kind) > Ord(High(TDelphiNameFlowNodeKind))) then
      Exit;
    if (i = 0) and (aNodes[i].ParentId <> 0) then
      Exit;
    if (i > 0) and ((aNodes[i].ParentId < 1) or (aNodes[i].ParentId > i)) then
      Exit;
    for j := 0 to High(aNodes[i].Children) do
    begin
      lChild := aNodes[i].Children[j];
      if (lChild <= i + 1) or (lChild > Length(aNodes)) then
        Exit;
      if lSeen[lChild - 1] or (aNodes[lChild - 1].ParentId <> i + 1) then
        Exit;
      lSeen[lChild - 1] := True;
    end;
  end;
  for i := 1 to High(aNodes) do
    if not lSeen[i] then
      Exit;
  Result := True;
end;

function NameFlowFactsFromJson(const aJson: string): IDelphiNameFlowFacts;
var
  lDigest: string;
  lEnvelope: TNameFlowEnvelope;
  lSerializer: TJsonSerializer;
  g: TGarbos;
begin
  Result := CreateNameFlowFacts(nil, False, False, 'name-flow-facts-json-unverified');
  if aJson = '' then
    Exit;
  GC(lSerializer, TJsonSerializer.Create, g);
  try
    lEnvelope := lSerializer.Deserialize<TNameFlowEnvelope>(aJson);
    if (lEnvelope.Version <> 202) or not ValidNodes(lEnvelope.Nodes) or
      ((Length(lEnvelope.Nodes) = 0) and lEnvelope.Complete) then
      Exit;
    lDigest := lEnvelope.Digest;
    lEnvelope.Digest := '';
    if (lDigest = '') or (lDigest <>
      THashSHA2.GetHashString(lSerializer.Serialize<TNameFlowEnvelope>(lEnvelope))) then
      Exit;
    Result := CreateNameFlowFacts(lEnvelope.Nodes, lEnvelope.Complete,
      lEnvelope.ConfigurationComplete, lEnvelope.CoverageReason);
  except
    on e: Exception do
      Result := CreateNameFlowFacts(nil, False, False, 'name-flow-facts-json-unverified:' + e.ClassName);
  end;
end;

end.
