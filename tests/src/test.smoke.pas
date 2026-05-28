unit Test.Smoke;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TDelphiSemanticsSmokeTests = class
  public
    [Test]
    procedure VersionTextIsAvailable;
  end;

implementation

uses
  DelphiSemantics.Version;

procedure TDelphiSemanticsSmokeTests.VersionTextIsAvailable;
begin
  Assert.AreEqual('0.1.1', DelphiSemanticsVersionText);
end;

initialization
  TDUnitX.RegisterTestFixture(TDelphiSemanticsSmokeTests);

end.
