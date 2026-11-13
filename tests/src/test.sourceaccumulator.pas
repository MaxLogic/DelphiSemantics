unit Test.SourceAccumulator;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TSourceAccumulatorTests = class
  public
    [Test] [Category('Fast,RefactoringLightObservations')]
    procedure SingleSetRemainsLazyAndUnchanged;
    [Test] [Category('Fast,RefactoringLightObservations')]
    procedure ManyAddsMaterializeOnlyAtPublication;
    [Test] [Category('Fast,RefactoringLightObservations')]
    [TestCase('Hash conflict', 'hash')]
    [TestCase('Text conflict', 'text')]
    [TestCase('Normalization exception', 'path')]
    procedure FailedAddBlocksFurtherAddsAndPublication(const aKind: string);
    [Test] [Category('Fast,RefactoringLightObservations')]
    procedure SeededSequencesMatchFrozenReference;
    [Test] [Category('Fast,RefactoringLightObservations')]
    [TestCase('Long relative spelling', 'long')]
    [TestCase('Trailing dot and space', 'trailing')]
    [TestCase('Parent segment', 'parent')]
    [TestCase('Forward slash', 'slash')]
    [TestCase('Extended prefix', 'extended')]
    procedure RepeatedNormalizationMatchesReference(const aKind: string);
    [Test] [Category('Fast,RefactoringLightObservations')]
    procedure MidMergeLookupRetainsLazyAndFirstSortedWinner;
  end;

implementation

uses
  System.Generics.Collections, System.Hash, System.IOUtils, System.SysUtils,
  AutoFree, MaxLogic.StrUtils,
  DelphiSemantics.Source;

function Item(const aName, aText, aRole: string): TDelphiSemanticSourceText;
begin
  Result := Default(TDelphiSemanticSourceText);
  Result.FileName := aName;
  Result.Text := aText;
  Result.ContentHash := THashSHA2.GetHashString(aText);
  Result.Role := aRole;
  Result.EncodingName := 'utf8';
  Result.LineEndingName := 'crlf';
  Result.LineBreak := #13#10;
end;

procedure EqualSources(const aExpected, aActual: IDelphiSemanticSourceObservations);
var
  i: Integer;
  lExpected, lActual: TDelphiSemanticSourceText;
begin
  Assert.AreEqual(aExpected = nil, aActual = nil);
  if aExpected = nil then
    Exit;
  Assert.AreEqual(aExpected.Count, aActual.Count);
  for i := 0 to aExpected.Count - 1 do
  begin
    lExpected := aExpected.Items[i];
    lActual := aActual.Items[i];
    Assert.AreEqual(lExpected.FileName, lActual.FileName);
    Assert.AreEqual(lExpected.ContentHash, lActual.ContentHash);
    Assert.AreEqual(lExpected.Text, lActual.Text);
    Assert.AreEqual(lExpected.Role, lActual.Role);
    Assert.AreEqual(lExpected.EncodingName, lActual.EncodingName);
    Assert.AreEqual(lExpected.LineEndingName, lActual.LineEndingName);
    Assert.AreEqual(lExpected.LineBreak, lActual.LineBreak);
  end;
end;

// Frozen 7490e05 merge oracle. Deliberately independent of candidate TryMerge:
// a shared normalization/conflict bug must not make both sides pass.
function ReferenceMerge(const aLeft, aRight: IDelphiSemanticSourceObservations;
  out aCombined: IDelphiSemanticSourceObservations; out aError: string): Boolean;
var
  g: TGarbos;
  i: Integer;
  lItem, lPrevious: TDelphiSemanticSourceText;
  lItems: TList<TDelphiSemanticSourceText>;
  lKnown: TDictionary<string, TDelphiSemanticSourceText>;
  lObservations: IDelphiSemanticSourceObservations;
begin
  aCombined := nil;
  aError := 'source.missing-observations';
  Result := False;
  if (aLeft = nil) or (aRight = nil) then
    Exit;
  g := Default(TGarbos);
  GC(lItems, TList<TDelphiSemanticSourceText>.Create, g);
  GC(lKnown, TDictionary<string, TDelphiSemanticSourceText>.Create(
    TFastCaseAwareComparer.OrdinalIgnoreCase), g);
  for lObservations in [aLeft, aRight] do
    for i := 0 to lObservations.Count - 1 do
    begin
      lItem := lObservations.Items[i];
      lItem.FileName := TPath.GetFullPath(lItem.FileName);
      if lKnown.TryGetValue(lItem.FileName, lPrevious) then
      begin
        if (lPrevious.ContentHash <> lItem.ContentHash) or (lPrevious.Text <> lItem.Text) then
        begin
          aError := 'source.conflicting-observations';
          Exit;
        end;
      end else begin
        lKnown.Add(lItem.FileName, lItem);
        lItems.Add(lItem);
      end;
    end;
  aCombined := TDelphiSemanticSourceEvidence.FromItems(lItems.ToArray);
  aError := '';
  Result := True;
end;

procedure TSourceAccumulatorTests.SingleSetRemainsLazyAndUnchanged;
var
  g: TGarbos;
  lOwner: TDelphiSemanticSourceAccumulator;
  lFirst: IDelphiSemanticSourceObservations;
  lError: string;
begin
  g := Default(TGarbos);
  GC(lOwner, TDelphiSemanticSourceAccumulator.Create, g);
  Assert.IsTrue(lOwner.TryAdd(nil, lError));
  Assert.AreEqual('', lError);
  Assert.IsTrue(lOwner.Freeze = nil);
  lFirst := TDelphiSemanticSourceEvidence.FromItems([Item('.\Lazy.pas', 'one', 'source')]);
  Assert.IsTrue(lOwner.TryAdd(lFirst, lError), lError);
  Assert.IsTrue(lOwner.TryAdd(nil, lError));
  Assert.AreEqual('', lError);
  Assert.IsTrue(lOwner.Freeze = lFirst, 'One set must retain its unnormalized interface and fields.');
  Assert.AreEqual(0, lOwner.MaterializationCount);
end;

procedure TSourceAccumulatorTests.ManyAddsMaterializeOnlyAtPublication;
var
  g: TGarbos;
  i: Integer;
  lOwner: TDelphiSemanticSourceAccumulator;
  lFrozen: IDelphiSemanticSourceObservations;
  lError: string;
begin
  g := Default(TGarbos);
  GC(lOwner, TDelphiSemanticSourceAccumulator.Create, g);
  for i := 0 to 31 do
    Assert.IsTrue(lOwner.TryAdd(TDelphiSemanticSourceEvidence.FromItems([
      Item('.\Unit' + IntToStr(i) + '.pas', IntToStr(i), 'source')]), lError), lError);
  Assert.AreEqual(0, lOwner.MaterializationCount,
    'Accumulation must not reconstruct the growing immutable union.');
  lFrozen := lOwner.Freeze;
  Assert.AreEqual(32, lFrozen.Count);
  Assert.AreEqual(1, lOwner.MaterializationCount);
  Assert.IsTrue(lOwner.Freeze = lFrozen);
  Assert.AreEqual(1, lOwner.MaterializationCount);
end;

procedure TSourceAccumulatorTests.FailedAddBlocksFurtherAddsAndPublication(const aKind: string);
var
  g: TGarbos;
  lOwner: TDelphiSemanticSourceAccumulator;
  lFirst, lChanged: TDelphiSemanticSourceText;
  lError: string;
begin
  g := Default(TGarbos);
  GC(lOwner, TDelphiSemanticSourceAccumulator.Create, g);
  lFirst := Item('.\Poison.pas', 'first', 'source');
  lChanged := lFirst;
  if aKind = 'hash' then
    lChanged.ContentHash := 'different'
  else if aKind = 'text' then
    lChanged.Text := 'different'
  else
    lChanged.FileName := 'invalid' + #0 + 'path';
  Assert.IsTrue(lOwner.TryAdd(TDelphiSemanticSourceEvidence.FromItems([lFirst]), lError));
  if aKind = 'path' then
    Assert.WillRaiseAny(
      procedure
      begin
        Assert.IsTrue(lOwner.TryAdd(TDelphiSemanticSourceEvidence.FromItems([lChanged]), lError));
      end)
  else begin
    Assert.IsFalse(lOwner.TryAdd(TDelphiSemanticSourceEvidence.FromItems([lChanged]), lError));
    Assert.AreEqual('source.conflicting-observations', lError);
  end;
  Assert.WillRaise(
    procedure
    begin
      Assert.IsTrue(lOwner.Freeze = nil);
    end, EInvalidOpException, 'A failed add must never publish its partial union.');
  Assert.IsFalse(lOwner.TryAdd(TDelphiSemanticSourceEvidence.FromItems([lFirst]), lError),
    'A poisoned owner must reject further additions.');
  Assert.IsTrue(lError <> '', 'The failed state keeps a precise failure reason.');
end;

procedure TSourceAccumulatorTests.SeededSequencesMatchFrozenReference;
var
  lOwner: TDelphiSemanticSourceAccumulator;
  lExpected, lIncoming, lCombined: IDelphiSemanticSourceObservations;
  lItems: TArray<TDelphiSemanticSourceText>;
  lExpectedError, lActualError: string;
  lSeed, lStep, lKey, lSavedSeed: Integer;
  lExpectedOk, lActualOk: Boolean;
begin
  lSavedSeed := RandSeed;
  try
    for lSeed := 0 to 39 do
    begin
      RandSeed := lSeed;
      lExpected := nil;
      lOwner := TDelphiSemanticSourceAccumulator.Create;
      try
        for lStep := 0 to 15 do
        begin
          SetLength(lItems, Random(4));
          for lKey := 0 to High(lItems) do
            lItems[lKey] := Item('.\U' + IntToStr(Random(7)) + '.pas', 'stable', IntToStr(lStep));
          if (lStep = 11) and (Length(lItems) > 0) and Odd(lSeed) then
            lItems[0].Text := 'changed';
          lIncoming := TDelphiSemanticSourceEvidence.FromItems(lItems);
          lExpectedOk := True;
          if lExpected = nil then
          begin
            lExpectedError := '';
            lExpected := lIncoming;
          end
          else begin
            lExpectedOk := ReferenceMerge(lExpected, lIncoming, lCombined, lExpectedError);
            if lExpectedOk then
              lExpected := lCombined;
          end;
          lActualOk := lOwner.TryAdd(lIncoming, lActualError);
          Assert.AreEqual(lExpectedOk, lActualOk, 'Refusal must occur at the same merge index.');
          Assert.AreEqual(lExpectedError, lActualError);
          if not lExpectedOk then
            Break;
          EqualSources(lExpected, lOwner.Freeze);
        end;
      finally
        lOwner.Free;
      end;
    end;
  finally
    RandSeed := lSavedSeed;
  end;
end;

procedure TSourceAccumulatorTests.RepeatedNormalizationMatchesReference(const aKind: string);
var
  lOwner: TDelphiSemanticSourceAccumulator;
  lInputs: TArray<IDelphiSemanticSourceObservations>;
  lExpected, lCombined: IDelphiSemanticSourceObservations;
  lPath, lError, lExpectedFailure, lActualFailure: string;
  i, lExpectedIndex, lActualIndex: Integer;
begin
  if aKind = 'long' then
    lPath := StringOfChar('x', 220) + '\Leaf.pas'
  else if aKind = 'trailing' then
    lPath := '.\Trailing. \Leaf.pas '
  else if aKind = 'parent' then
    lPath := '.\Parent\..\Leaf.pas'
  else if aKind = 'slash' then
    lPath := './Slash/Leaf.pas'
  else
    lPath := '\\?\' + TPath.GetFullPath('.\Extended\Leaf.pas');
  lInputs := [TDelphiSemanticSourceEvidence.FromItems([Item(lPath, 'one', 'source')]),
    TDelphiSemanticSourceEvidence.FromItems([]),
    TDelphiSemanticSourceEvidence.FromItems([Item('.\Other.pas', 'two', 'source')])];
  lExpected := nil;
  lExpectedFailure := '';
  lExpectedIndex := -1;
  for i := 0 to High(lInputs) do
    try
      if lExpected = nil then
        lExpected := lInputs[i]
      else begin
        Assert.IsTrue(ReferenceMerge(lExpected, lInputs[i], lCombined, lError), lError);
        lExpected := lCombined;
      end;
    except
      on E: Exception do
      begin
        lExpectedFailure := E.ClassName + '|' + E.Message;
        lExpectedIndex := i;
        Break;
      end;
    end;
  lActualFailure := '';
  lActualIndex := -1;
  lOwner := TDelphiSemanticSourceAccumulator.Create;
  try
    for i := 0 to High(lInputs) do
      try
        Assert.IsTrue(lOwner.TryAdd(lInputs[i], lError), lError);
      except
        on E: Exception do
        begin
          lActualFailure := E.ClassName + '|' + E.Message;
          lActualIndex := i;
          Break;
        end;
      end;
    Assert.AreEqual(lExpectedIndex, lActualIndex, 'Normalize-twice failure index.');
    Assert.AreEqual(lExpectedFailure, lActualFailure, 'Normalize-twice exception class/message.');
    if lExpectedFailure = '' then
      EqualSources(lExpected, lOwner.Freeze);
  finally
    lOwner.Free;
  end;
end;

procedure TSourceAccumulatorTests.MidMergeLookupRetainsLazyAndFirstSortedWinner;
var
  g: TGarbos;
  lOwner: TDelphiSemanticSourceAccumulator;
  lFirst, lExpected: IDelphiSemanticSourceObservations;
  lFound: TDelphiSemanticSourceText;
  lName, lError: string;
begin
  g := Default(TGarbos);
  GC(lOwner, TDelphiSemanticSourceAccumulator.Create, g);
  Assert.IsFalse(lOwner.TryFind('invalid' + #0 + 'path', lFound), 'Nil state must short-circuit lookup.');
  lFirst := TDelphiSemanticSourceEvidence.FromItems([Item('.\Beta.pas', 'one', 'first')]);
  Assert.IsTrue(lOwner.TryAdd(lFirst, lError));
  Assert.IsFalse(lOwner.TryFind('.\Beta.pas', lFound), 'Lazy raw names are not normalized early.');
  lName := TPath.GetFullPath('.\Sorted.pas');
  lFirst := TDelphiSemanticSourceEvidence.FromItems([
    Item(LowerCase(lName), 'stable', 'lower'), Item(UpperCase(lName), 'stable', 'upper')]);
  Assert.IsTrue(lOwner.TryAdd(lFirst, lError));
  Assert.IsTrue(ReferenceMerge(TDelphiSemanticSourceEvidence.FromItems([
    Item('.\Beta.pas', 'one', 'first')]), lFirst, lExpected, lError));
  Assert.IsTrue(lOwner.TryFind(lName, lFound));
  Assert.AreEqual('upper', lFound.Role, 'Ordinal-first incoming case duplicate must win.');
  EqualSources(lExpected, lOwner.Freeze);
end;

initialization
  TDUnitX.RegisterTestFixture(TSourceAccumulatorTests);

end.
