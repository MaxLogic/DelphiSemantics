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

initialization
  TDUnitX.RegisterTestFixture(TSnapshotTests);

end.
