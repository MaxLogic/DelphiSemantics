unit Test.Snapshot;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TSnapshotTests = class
  public
    [Test]
    procedure MemberKeyPacksOwnerAndNameIds;
    [Test]
    procedure SnapshotUnitDoesNotUseJsonLiveRepresentation;
    [Test]
    procedure StringPoolInternsStableCaseAwareIds;
    [Test]
    procedure UnitSnapshotAssignsStableDenseFactIds;
    [Test]
    procedure UnitSnapshotFindsWithCandidatesBySourceLine;
    [Test]
    procedure UnitSnapshotReturnsReferencesForWithWithoutReferenceScan;
    [Test]
    procedure UnitSnapshotStoresFactsAsRecords;
  end;

implementation

uses
  System.IOUtils, System.StrUtils, System.SysUtils,
  maxLogic.IOUtils,
  DelphiSemantics.Snapshot;

procedure TSnapshotTests.MemberKeyPacksOwnerAndNameIds;
var
  lExpected: UInt64;
  lFirst: UInt64;
  lOtherName: UInt64;
  lOtherOwner: UInt64;
begin
  lExpected := (UInt64(1) shl 32) or UInt64(2);

  lFirst := MemberKey(1, 2);
  lOtherName := MemberKey(1, 3);
  lOtherOwner := MemberKey(2, 2);

  Assert.AreEqual(lExpected, lFirst);
  Assert.IsTrue(lFirst <> lOtherName, 'Different names must not collide.');
  Assert.IsTrue(lFirst <> lOtherOwner, 'Different owners must not collide.');
end;

procedure TSnapshotTests.SnapshotUnitDoesNotUseJsonLiveRepresentation;
var
  lSourceFileName: string;
  lSourceText: string;
begin
  lSourceFileName := TPath.GetFullPath(CombinePath([ExtractFilePath(ParamStr(0)), '..',
    '..', 'src', 'DelphiSemantics.Snapshot.pas']));

  lSourceText := TFile.ReadAllText(lSourceFileName, TEncoding.UTF8);

  Assert.IsFalse(ContainsText(lSourceText, 'System.JSON'),
    'Snapshot primitives must not use JSON as the live representation.');
  Assert.IsFalse(ContainsText(lSourceText, 'TJSONObject'),
    'Snapshot primitives must not traverse JSON objects in hot paths.');
  Assert.IsFalse(ContainsText(lSourceText, 'TJSONArray'),
    'Snapshot primitives must not traverse JSON arrays in hot paths.');
end;

procedure TSnapshotTests.StringPoolInternsStableCaseAwareIds;
var
  lOtherId: TSemanticStringId;
  lPool: TSemanticStringPool;
  lTextId: TSemanticStringId;
begin
  lPool := TSemanticStringPool.Create;
  try
    Assert.AreEqual(0, Integer(lPool.Count));
    Assert.AreEqual('', lPool.TextOf(0));

    lTextId := lPool.Intern('TWidget');
    Assert.AreEqual(lTextId, lPool.Intern('twidget'));
    lOtherId := lPool.Intern('TOther');

    Assert.IsTrue(lTextId <> 0, 'Non-empty strings should not use the sentinel ID.');
    Assert.IsTrue(lTextId <> lOtherId, 'Different strings must get different IDs.');
    Assert.AreEqual('TWidget', lPool.TextOf(lTextId));
    Assert.AreEqual('TOther', lPool.TextOf(lOtherId));
    Assert.AreEqual(2, Integer(lPool.Count));
  finally
    lPool.Free;
  end;
end;

procedure TSnapshotTests.UnitSnapshotAssignsStableDenseFactIds;
var
  lReference: TSemanticReferenceFact;
  lReferenceId: TSemanticReferenceId;
  lSnapshot: TUnitSnapshot;
  lSymbol: TSemanticSymbolFact;
  lSymbolId: TSemanticSymbolId;
  lWith: TSemanticWithStatementFact;
  lWithId: TSemanticWithId;
begin
  lSnapshot := TUnitSnapshot.Create(42);
  try
    lSymbol := Default(TSemanticSymbolFact);
    lSymbol.NameId := 10;
    lSymbolId := lSnapshot.AddSymbol(lSymbol);

    lWith := Default(TSemanticWithStatementFact);
    lWith.BodyStartLine := 5;
    lWith.BodyEndLine := 7;
    lWithId := lSnapshot.AddWithStatement(lWith);

    lReference := Default(TSemanticReferenceFact);
    lReference.WithId := lWithId;
    lReference.NameId := 20;
    lReferenceId := lSnapshot.AddReference(lReference);

    Assert.AreEqual(1, Integer(lSymbolId));
    Assert.AreEqual(1, Integer(lWithId));
    Assert.AreEqual(1, Integer(lReferenceId));
    Assert.AreEqual(42, Integer(lSnapshot.SymbolById(lSymbolId).UnitId));
    Assert.AreEqual(42, Integer(lSnapshot.WithStatementById(lWithId).UnitId));
    Assert.AreEqual(42, Integer(lSnapshot.ReferenceById(lReferenceId).UnitId));
    Assert.AreEqual(1, lSnapshot.SymbolCount);
    Assert.AreEqual(1, lSnapshot.WithStatementCount);
    Assert.AreEqual(1, lSnapshot.ReferenceCount);
  finally
    lSnapshot.Free;
  end;
end;

procedure TSnapshotTests.UnitSnapshotFindsWithCandidatesBySourceLine;
var
  i: Integer;
  lFoundFirst: Boolean;
  lFoundSecond: Boolean;
  lHighIndex: Integer;
  lLowIndex: Integer;
  lSnapshot: TUnitSnapshot;
  lWith: TSemanticWithStatementFact;
  lWithFirst: TSemanticWithId;
  lWithSecond: TSemanticWithId;
begin
  lSnapshot := TUnitSnapshot.Create(7);
  try
    lWith := Default(TSemanticWithStatementFact);
    lWith.BodyStartLine := 10;
    lWith.BodyEndLine := 12;
    lWithFirst := lSnapshot.AddWithStatement(lWith);

    lWith := Default(TSemanticWithStatementFact);
    lWith.BodyStartLine := 12;
    lWith.BodyEndLine := 15;
    lWithSecond := lSnapshot.AddWithStatement(lWith);

    Assert.IsTrue(lSnapshot.TryWithStatementsAtLine(12, lLowIndex, lHighIndex));

    lFoundFirst := False;
    lFoundSecond := False;
    for i := lLowIndex to lHighIndex do
    begin
      lFoundFirst := lFoundFirst or (lSnapshot.WithIdBySourceLineIndex(i) = lWithFirst);
      lFoundSecond := lFoundSecond or (lSnapshot.WithIdBySourceLineIndex(i) = lWithSecond);
    end;

    Assert.IsTrue(lFoundFirst, 'Expected the first with statement to be indexed for line 12.');
    Assert.IsTrue(lFoundSecond, 'Expected the second with statement to be indexed for line 12.');
    Assert.IsFalse(lSnapshot.TryWithStatementsAtLine(9, lLowIndex, lHighIndex));
  finally
    lSnapshot.Free;
  end;
end;

procedure TSnapshotTests.UnitSnapshotReturnsReferencesForWithWithoutReferenceScan;
var
  i: Integer;
  lFoundFirst: Boolean;
  lFoundSecond: Boolean;
  lHighIndex: Integer;
  lLowIndex: Integer;
  lReference: TSemanticReferenceFact;
  lReferenceFirst: TSemanticReferenceId;
  lReferenceSecond: TSemanticReferenceId;
  lSnapshot: TUnitSnapshot;
  lWith: TSemanticWithStatementFact;
  lWithFirst: TSemanticWithId;
  lWithSecond: TSemanticWithId;
begin
  lSnapshot := TUnitSnapshot.Create(7);
  try
    lWith := Default(TSemanticWithStatementFact);
    lWith.BodyStartLine := 1;
    lWith.BodyEndLine := 1;
    lWithFirst := lSnapshot.AddWithStatement(lWith);

    lWith := Default(TSemanticWithStatementFact);
    lWith.BodyStartLine := 2;
    lWith.BodyEndLine := 2;
    lWithSecond := lSnapshot.AddWithStatement(lWith);

    lReference := Default(TSemanticReferenceFact);
    lReference.WithId := lWithSecond;
    lSnapshot.AddReference(lReference);

    lReference.WithId := lWithFirst;
    lReference.NameId := 101;
    lReferenceFirst := lSnapshot.AddReference(lReference);

    lReference.NameId := 102;
    lReferenceSecond := lSnapshot.AddReference(lReference);

    Assert.IsTrue(lSnapshot.TryReferencesForWith(lWithFirst, lLowIndex, lHighIndex));
    Assert.AreEqual(2, lHighIndex - lLowIndex + 1);

    lFoundFirst := False;
    lFoundSecond := False;
    for i := lLowIndex to lHighIndex do
    begin
      lFoundFirst := lFoundFirst or (lSnapshot.ReferenceIdByWithIndex(i) = lReferenceFirst);
      lFoundSecond := lFoundSecond or (lSnapshot.ReferenceIdByWithIndex(i) = lReferenceSecond);
    end;

    Assert.IsTrue(lFoundFirst, 'Expected first matching reference ID in the with-index range.');
    Assert.IsTrue(lFoundSecond, 'Expected second matching reference ID in the with-index range.');
    Assert.IsTrue(lSnapshot.TryReferencesForWith(lWithSecond, lLowIndex, lHighIndex));
    Assert.AreEqual(1, lHighIndex - lLowIndex + 1);
    Assert.IsFalse(lSnapshot.TryReferencesForWith(999, lLowIndex, lHighIndex));
  finally
    lSnapshot.Free;
  end;
end;

procedure TSnapshotTests.UnitSnapshotStoresFactsAsRecords;
var
  lSourceFileName: string;
  lSourceText: string;
begin
  lSourceFileName := TPath.GetFullPath(CombinePath([ExtractFilePath(ParamStr(0)), '..',
    '..', 'src', 'DelphiSemantics.Snapshot.pas']));

  lSourceText := TFile.ReadAllText(lSourceFileName, TEncoding.UTF8);

  Assert.IsTrue(ContainsText(lSourceText, 'TSemanticSymbolFact = record'));
  Assert.IsTrue(ContainsText(lSourceText, 'TSemanticWithStatementFact = record'));
  Assert.IsTrue(ContainsText(lSourceText, 'TSemanticReferenceFact = record'));
  Assert.IsFalse(ContainsText(lSourceText, 'TSemanticSymbolFact = class'));
  Assert.IsFalse(ContainsText(lSourceText, 'TSemanticWithStatementFact = class'));
  Assert.IsFalse(ContainsText(lSourceText, 'TSemanticReferenceFact = class'));
end;

initialization
  TDUnitX.RegisterTestFixture(TSnapshotTests);

end.
