unit Test.WithBindingIndexStorage;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TWithBindingIndexStorageTests = class
  public
    [Category('Fast')]
    [TestCase('members', 'members')]
    [TestCase('declarations', 'declarations')]
    [TestCase('names', 'names')]
    [TestCase('owners', 'owners')]
    [TestCase('units', 'units')]
    [TestCase('prefixes', 'prefixes')]
    procedure OrderedMapsKeepDuplicatesAndSnapshotIsolation(const aShape: string);
    [Test]
    [Category('Fast')]
    procedure ModelMembersPrecedeInventoryMembers;
  end;

implementation

uses
  System.JSON.Serializers, System.SysUtils,
  DelphiSemantics.Model, DelphiSemantics.WithBinding;

procedure TWithBindingIndexStorageTests.OrderedMapsKeepDuplicatesAndSnapshotIsolation(
  const aShape: string);
var
  i: Integer;
  lActual: TArray<TDelphiSemanticInventorySymbol>;
  lExpected: string;
  lIndex: TDelphiSemanticRemoveWithLookupIndex;
  lSerializer: TJsonSerializer;
  lSymbols: TArray<TDelphiSemanticInventorySymbol>;

  function Query: TArray<TDelphiSemanticInventorySymbol>;
  begin
    if aShape = 'members' then
      Exit(lIndex.FindMembersByOwnerAndName('TOwner', 'Shared'));
    if aShape = 'declarations' then
      Exit(lIndex.FindDeclarationOrTypeAliasByName('Shared'));
    if aShape = 'names' then
      Exit(lIndex.FindSymbolsByName('Shared'));
    if aShape = 'owners' then
      Exit(lIndex.FindSymbolsByOwnerType('TOwner'));
    if aShape = 'units' then
      Exit(lIndex.FindUnitOrGlobalByName('Shared'));
    Result := lIndex.FindUnitOrGlobalByPrefix('Unit');
  end;

begin
  SetLength(lSymbols, 3);
  for i := 0 to High(lSymbols) do
  begin
    lSymbols[i].Name := 'Shared';
    lSymbols[i].OwnerName := 'TOwner';
    lSymbols[i].OwnerType := 'TOwner';
    lSymbols[i].SymbolClass := 'member';
    lSymbols[i].Kind := 'field';
    lSymbols[i].TypeName := 'Integer';
    lSymbols[i].UnitName := 'Input' + IntToStr(i);
    lSymbols[i].Line := 30 - i;
    lSymbols[i].FileName := 'Distinct record ' + IntToStr(i);
    if aShape = 'declarations' then
      lSymbols[i].SymbolClass := 'declaration';
    if aShape = 'units' then
      lSymbols[i].SymbolClass := 'unit-global';
    if aShape = 'prefixes' then
    begin
      lSymbols[i].SymbolClass := 'unit';
      lSymbols[i].Name := 'Unit.Child.Leaf';
    end;
  end;
  lSerializer := TJsonSerializer.Create;
  try
    lExpected := lSerializer.Serialize<TArray<TDelphiSemanticInventorySymbol>>(lSymbols);
    lIndex := TDelphiSemanticRemoveWithLookupIndex.Build(nil, lSymbols);
    lActual := Query;
    Assert.AreEqual(lExpected,
      lSerializer.Serialize<TArray<TDelphiSemanticInventorySymbol>>(lActual));
    // Both caller inputs and returned arrays may be changed independently.
    lSymbols[0].FileName := 'Changed input';
    lActual[1].FileName := 'Changed result';
    lActual := Query;
    Assert.AreEqual(lExpected,
      lSerializer.Serialize<TArray<TDelphiSemanticInventorySymbol>>(lActual));
  finally
    lSerializer.Free;
  end;
end;

procedure TWithBindingIndexStorageTests.ModelMembersPrecedeInventoryMembers;
var
  lActual: TArray<TDelphiSemanticInventorySymbol>;
  lIndex: TDelphiSemanticRemoveWithLookupIndex;
  lModel: TDelphiSemanticUnitModel;
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  lModel := Default(TDelphiSemanticUnitModel);
  lModel.UnitName := 'ModelUnit';
  SetLength(lModel.Members, 2);
  lModel.Members[0].OwnerName := 'TOwner';
  lModel.Members[0].Name := 'Shared';
  lModel.Members[0].Kind := 'field';
  lModel.Members[0].Line := 11;
  lModel.Members[1] := lModel.Members[0];
  lModel.Members[1].Line := 12;
  lSymbol := Default(TDelphiSemanticInventorySymbol);
  lSymbol.OwnerType := 'TOwner';
  lSymbol.Name := 'Shared';
  lSymbol.SymbolClass := 'member';
  lSymbol.Line := 13;
  lIndex := TDelphiSemanticRemoveWithLookupIndex.Build([lModel], [lSymbol]);
  lActual := lIndex.FindMembersByOwnerAndName('TOwner', 'Shared');
  Assert.AreEqual(Integer(3), Integer(Length(lActual)));
  Assert.AreEqual(11, lActual[0].Line);
  Assert.AreEqual(12, lActual[1].Line);
  Assert.AreEqual(13, lActual[2].Line);
end;

initialization
  TDUnitX.RegisterTestFixture(TWithBindingIndexStorageTests);

end.
