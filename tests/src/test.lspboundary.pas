unit Test.LspBoundary;

interface

uses
  DUnitX.TestFramework,
  DelphiSemantics.Lsp, DelphiSemantics.Resolve;

type
  [TestFixture]
  TLspBoundaryTests = class
  public
    [Test]
    procedure LspEnrichmentIsDisabledByDefault;
    [Test]
    procedure LspDerivedResultsCarryLspProvenance;
    [Test]
    procedure SemanticResultsRemainAuthoritativeByDefault;
  end;

implementation

procedure TLspBoundaryTests.LspEnrichmentIsDisabledByDefault;
var
  lLocation: TDelphiSemanticLspLocation;
  lOptions: TDelphiSemanticLspOptions;
  lResult: TDelphiSemanticLspResult;
begin
  lOptions := Default(TDelphiSemanticLspOptions);
  lLocation.FileName := 'Unit1.pas';
  lLocation.Line := 10;
  lLocation.Column := 5;

  lResult := TDelphiSemanticLspBoundary.EnrichDefinition(lOptions, 'Value', lLocation);

  Assert.IsFalse(lResult.Found);
  Assert.IsFalse(lResult.Authoritative);
  Assert.AreEqual('disabled', lResult.Status);
  Assert.AreEqual('', lResult.Provenance);
end;

procedure TLspBoundaryTests.LspDerivedResultsCarryLspProvenance;
var
  lLocation: TDelphiSemanticLspLocation;
  lOptions: TDelphiSemanticLspOptions;
  lResult: TDelphiSemanticLspResult;
begin
  lOptions := Default(TDelphiSemanticLspOptions);
  lOptions.Enabled := True;
  lLocation.FileName := 'Unit1.pas';
  lLocation.Line := 10;
  lLocation.Column := 5;

  lResult := TDelphiSemanticLspBoundary.EnrichDefinition(lOptions, 'Value', lLocation);

  Assert.IsTrue(lResult.Found);
  Assert.IsFalse(lResult.Authoritative);
  Assert.AreEqual('lsp', lResult.Provenance);
  Assert.AreEqual('Value', lResult.Name);
  Assert.AreEqual('Unit1.pas', lResult.FileName);
  Assert.AreEqual(10, lResult.Line);
  Assert.AreEqual(5, lResult.Column);
end;

procedure TLspBoundaryTests.SemanticResultsRemainAuthoritativeByDefault;
var
  lResolveResult: TDelphiSemanticResolveResult;
  lResult: TDelphiSemanticLspResult;
begin
  lResolveResult := Default(TDelphiSemanticResolveResult);
  lResolveResult.Found := True;
  lResolveResult.Authoritative := True;
  lResolveResult.Status := 'resolved';
  lResolveResult.Name := 'Value';
  lResolveResult.Kind := 'field';
  lResolveResult.TypeName := 'Integer';
  lResolveResult.OwnerName := 'TRecord';

  lResult := TDelphiSemanticLspBoundary.FromSemanticResult(lResolveResult);

  Assert.IsTrue(lResult.Found);
  Assert.IsTrue(lResult.Authoritative);
  Assert.AreEqual('semantic-model', lResult.Provenance);
  Assert.AreEqual('field', lResult.Kind);
  Assert.AreEqual('Integer', lResult.TypeName);
end;

initialization
  TDUnitX.RegisterTestFixture(TLspBoundaryTests);

end.
