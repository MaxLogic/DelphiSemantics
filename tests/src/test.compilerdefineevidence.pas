unit Test.CompilerDefineEvidence;

interface

uses
  DUnitX.TestFramework, DelphiSemantics.CompilerDefineEvidence;

type
  [TestFixture]
  TCompilerDefineEvidenceTests = class
  public
    [Test]
    [TestCase('ordinary', 'ordinary')]
    [TestCase('certified empty', 'empty')]
    [TestCase('normalization', 'normalization')]
    [TestCase('source applicability', 'source')]
    [TestCase('immutable descriptor', 'immutable')]
    procedure AdmitsClosedCompilerInputs(const aShape: string);
    [TestCase('Native 32-bit host', 'A4945A14F9C4DE0CA2B38B4E772F45929235FA515F3621AFB63387AC5F23AC03')]
    [TestCase('Native 64-bit host', '69AE66304E62B37EA7C2DB59A563BE2E416F5D6ADF77FB5D42EDFE5FA02FB7F9')]
    procedure AdmitsVerifiedNativeCompilerHost(const aCompilerHash: string);
    [Test]
    [TestCase('replace emulated defines', 'replace')]
    [TestCase('certified empty', 'empty')]
    [TestCase('project fingerprint', 'identity')]
    [TestCase('invalid certificate contributes no defines', 'invalid')]
    [TestCase('legacy boolean is not a certificate', 'legacy-model')]
    [TestCase('direct model certificate', 'direct-model')]
    [TestCase('direct cache certificate identity', 'cache')]
    procedure CertificateFlowsThroughProductionOptions(const aShape: string);
    [Test]
    [TestCase('wrong format', 'format')]
    [TestCase('malformed digest', 'digest')]
    [TestCase('wrong project', 'project')]
    [TestCase('wrong main source', 'main')]
    [TestCase('wrong configuration', 'configuration')]
    [TestCase('wrong platform', 'platform')]
    [TestCase('unsupported installation', 'installation')]
    [TestCase('malformed symbol', 'symbol')]
    [TestCase('stale producer', 'stale')]
    [TestCase('missing evidence', 'missing')]
    procedure RejectsUnprovedInputs(const aShape: string);
    [Test]
    [TestCase('cold publication', 'cold')]
    [TestCase('warm reuse', 'warm')]
    procedure ChangedProducerAbortsModelPublication(const aShape: string);
  end;

// Only generated, closed synthetic test universes may use this producer.
function ClosedTestCompilerDefines(const aRequest: TDelphiSemanticCompilerDefineRequest;
  const aSources, aDefines: TArray<string>): IDelphiSemanticCompilerDefineEvidence;

implementation

uses
  System.Hash, System.IOUtils, System.SysUtils,
  DelphiSemantics.Cache, DelphiSemantics.Model,
  DelphiSemantics.ProjectContext;

type
  TTestDefineEvidence = class(TInterfacedObject, IDelphiSemanticCompilerDefineEvidence)
  private
    fDescriptor: TDelphiSemanticCompilerDefineDescriptor;
    fCurrent: TFunc<Boolean>;
  public
    constructor Create(const aDescriptor: TDelphiSemanticCompilerDefineDescriptor;
      const aCurrent: TFunc<Boolean> = nil);
    function Descriptor: TDelphiSemanticCompilerDefineDescriptor;
    function InputsAreCurrent(out aReason: string): Boolean;
  end;

constructor TTestDefineEvidence.Create(const aDescriptor: TDelphiSemanticCompilerDefineDescriptor;
  const aCurrent: TFunc<Boolean>);
begin
  inherited Create;
  fDescriptor := aDescriptor;
  fCurrent := aCurrent;
end;

function TTestDefineEvidence.Descriptor: TDelphiSemanticCompilerDefineDescriptor;
begin
  Result := fDescriptor;
end;

function TTestDefineEvidence.InputsAreCurrent(out aReason: string): Boolean;
begin
  aReason := '';
  Result := fDescriptor.ProducerInputIdentity <> 'stale';
  if Assigned(fCurrent) then
    Result := Result and fCurrent();
  if not Result then
    aReason := 'evaluated native values changed';
end;

function ClosedDescriptor: TDelphiSemanticCompilerDefineDescriptor;
begin
  Result := Default(TDelphiSemanticCompilerDefineDescriptor);
  Result.Format := 'ds-compiler-defines-v1';
  Result.Producer := 'closed-generated-test-universe-v1';
  Result.CaptureKind := 'closed-generated-test-universe-v1';
  Result.Invocation.ProjectFileName := TPath.GetFullPath('CertificateFixture.dproj');
  Result.Invocation.MainSourceFileName := TPath.GetFullPath('CertificateFixture.dpr');
  Result.Invocation.Configuration := 'Debug';
  Result.Invocation.Platform := 'Win64';
  Result.Invocation.DelphiVersion := '23.0';
  Result.WorkingDirectory := TPath.GetFullPath('.');
  Result.CompilerFileName := TPath.GetFullPath('dcc64.exe');
  Result.CompilerHash := StringOfChar('A', 64);
  Result.CompilerVersion := '36.0';
  Result.BuildTarget := 'Build';
  Result.RebuildMode := 'all-source-units';
  Result.Defines := ['FEATURE', 'DEBUG'];
  Result.OrderedArguments := ['--no-config', '-DFEATURE;DEBUG'];
  Result.ProducerInputIdentity := 'closed-generated-inputs-v1';
  Result.SourceApplicabilityIdentity := 'explicit-main-source-v1';
  SetLength(Result.Sources, 1);
  Result.Sources[0].UnitName := 'Fixture';
  Result.Sources[0].SourceFileName := TPath.GetFullPath('tests\fixtures\ProjectContext\Basic\BasicProject.dpr');
  Result.Sources[0].ContentHash := THashSHA2.GetHashStringFromFile(Result.Sources[0].SourceFileName);
end;

function ClosedTestCompilerDefines(const aRequest: TDelphiSemanticCompilerDefineRequest;
  const aSources, aDefines: TArray<string>): IDelphiSemanticCompilerDefineEvidence;
var
  i: Integer;
  lDescriptor: TDelphiSemanticCompilerDefineDescriptor;
begin
  lDescriptor := ClosedDescriptor;
  lDescriptor.Invocation := aRequest;
  lDescriptor.Defines := Copy(aDefines);
  lDescriptor.OrderedArguments := ['--no-config'];
  SetLength(lDescriptor.Sources, Length(aSources));
  for i := 0 to High(aSources) do
  begin
    lDescriptor.Sources[i].UnitName := TPath.GetFileNameWithoutExtension(aSources[i]);
    lDescriptor.Sources[i].SourceFileName := TPath.GetFullPath(aSources[i]);
    lDescriptor.Sources[i].ContentHash := THashSHA2.GetHashStringFromFile(aSources[i]);
  end;
  Result := TTestDefineEvidence.Create(lDescriptor);
end;

procedure TCompilerDefineEvidenceTests.AdmitsVerifiedNativeCompilerHost(const aCompilerHash: string);
var
  lDescriptor: TDelphiSemanticCompilerDefineDescriptor;
  lEvidence, lAdmitted: IDelphiSemanticCompilerDefineEvidence;
  lReason: string;
begin
  lDescriptor := ClosedDescriptor;
  lDescriptor.CaptureKind := 'native-msbuild-dcc-inputs-v1';
  lDescriptor.CompilerHash := aCompilerHash;
  lEvidence := TTestDefineEvidence.Create(lDescriptor);
  Assert.IsTrue(TDelphiSemanticCompilerDefines.TryAdmit(lEvidence, lDescriptor.Invocation, lAdmitted, lReason),
    lReason);
end;

procedure TCompilerDefineEvidenceTests.AdmitsClosedCompilerInputs(const aShape: string);
var
  lDescriptor, lRead: TDelphiSemanticCompilerDefineDescriptor;
  lProvider, lAdmitted, lEquivalent: IDelphiSemanticCompilerDefineEvidence;
  lReason: string;
begin
  lDescriptor := ClosedDescriptor;
  if aShape = 'empty' then
    lDescriptor.Defines := nil;
  lProvider := TTestDefineEvidence.Create(lDescriptor);
  Assert.IsTrue(TDelphiSemanticCompilerDefines.TryAdmit(lProvider, lDescriptor.Invocation,
    lAdmitted, lReason), lReason);
  Assert.IsNotNull(lAdmitted);
  Assert.IsNotEmpty(TDelphiSemanticCompilerDefines.Fingerprint(lAdmitted));
  if aShape = 'empty' then
    Assert.AreEqual<Integer>(0, Length(TDelphiSemanticCompilerDefines.EffectiveDefines(lAdmitted)))
  else
    Assert.AreEqual<Integer>(2, Length(TDelphiSemanticCompilerDefines.EffectiveDefines(lAdmitted)));
  if aShape = 'source' then
  begin
    Assert.IsTrue(TDelphiSemanticCompilerDefines.AppliesToSource(lAdmitted,
      lDescriptor.Sources[0].SourceFileName));
    Assert.IsFalse(TDelphiSemanticCompilerDefines.AppliesToSource(lAdmitted,
      lDescriptor.CompilerFileName));
  end;
  if aShape = 'normalization' then
  begin
    lDescriptor.Defines := ['debug', 'feature', 'FEATURE'];
    lProvider := TTestDefineEvidence.Create(lDescriptor);
    Assert.IsTrue(TDelphiSemanticCompilerDefines.TryAdmit(lProvider, lDescriptor.Invocation,
      lEquivalent, lReason), lReason);
    Assert.AreEqual(TDelphiSemanticCompilerDefines.Fingerprint(lAdmitted),
      TDelphiSemanticCompilerDefines.Fingerprint(lEquivalent));
  end;
  if aShape = 'immutable' then
  begin
    lDescriptor.Defines[0] := 'MUTATED_PROVIDER';
    lRead := lAdmitted.Descriptor;
    Assert.AreEqual('DEBUG', lRead.Defines[0]);
    lRead.Defines[0] := 'MUTATED_READER';
    lRead := lAdmitted.Descriptor;
    Assert.AreEqual('DEBUG', lRead.Defines[0]);
  end;
end;

procedure TCompilerDefineEvidenceTests.RejectsUnprovedInputs(const aShape: string);
var
  lDescriptor: TDelphiSemanticCompilerDefineDescriptor;
  lRequest: TDelphiSemanticCompilerDefineRequest;
  lProvider, lAdmitted: IDelphiSemanticCompilerDefineEvidence;
  lReason: string;
begin
  lDescriptor := ClosedDescriptor;
  lRequest := lDescriptor.Invocation;
  if aShape = 'format' then lDescriptor.Format := 'unknown';
  if aShape = 'digest' then lDescriptor.CompilerHash := 'broken';
  if aShape = 'project' then lRequest.ProjectFileName := lRequest.ProjectFileName + '.other';
  if aShape = 'main' then lRequest.MainSourceFileName := lRequest.MainSourceFileName + '.other';
  if aShape = 'configuration' then lRequest.Configuration := 'Release';
  if aShape = 'platform' then lRequest.Platform := 'Win32';
  if aShape = 'installation' then
  begin
    lDescriptor.Invocation.DelphiVersion := '37.0';
    lRequest.DelphiVersion := '37.0';
  end;
  if aShape = 'symbol' then lDescriptor.Defines := ['FEATURE=2'];
  if aShape = 'stale' then lDescriptor.ProducerInputIdentity := 'stale';
  if aShape <> 'missing' then
    lProvider := TTestDefineEvidence.Create(lDescriptor);
  Assert.IsFalse(TDelphiSemanticCompilerDefines.TryAdmit(lProvider, lRequest, lAdmitted, lReason));
  Assert.IsNull(lAdmitted);
  Assert.IsNotEmpty(lReason);
end;

procedure TCompilerDefineEvidenceTests.CertificateFlowsThroughProductionOptions(const aShape: string);
var
  lDescriptor: TDelphiSemanticCompilerDefineDescriptor;
  lOptions: TDelphiSemanticOptions;
  lOriginal, lCertified: TDelphiSemanticContextResult;
  lModelOptions: TDelphiSemanticModelOptions;
  lModel: TDelphiSemanticUnitModel;
  lCache: TDelphiSemanticUnitCache;
  lBefore, lAfter: TDelphiSemanticUnitCacheIdentity;
begin
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.Configuration := 'Debug';
  lOptions.Platform := 'Win64';
  lOptions.DelphiVersion := '23.0';
  lOptions.ProjectPath := TPath.GetFullPath('tests\fixtures\ProjectContext\Basic\BasicProject.dproj');
  lOriginal := TDelphiSemanticProject.Load(lOptions.ProjectPath, lOptions);
  Assert.IsTrue(lOriginal.Success);
  lDescriptor := ClosedDescriptor;
  lDescriptor.Invocation.ProjectFileName := lOriginal.Project.ProjectFileName;
  lDescriptor.Invocation.MainSourceFileName := lOriginal.Project.MainSourceFileName;
  if aShape = 'empty' then
    lDescriptor.Defines := nil;
  if aShape = 'invalid' then
    lDescriptor.Format := 'unknown';
  lOptions.CompilerDefineEvidence := TTestDefineEvidence.Create(lDescriptor);
  lCertified := TDelphiSemanticProject.Load(lOptions.ProjectPath, lOptions);
  Assert.IsTrue(lCertified.Success);
  if aShape = 'invalid' then
  begin
    Assert.IsFalse(lCertified.Project.DefineEvidenceComplete);
    Assert.AreEqual(String.Join(';', lOriginal.Project.Defines),
      String.Join(';', lCertified.Project.Defines), 'Invalid evidence contributes no positive facts.');
    Exit;
  end;
  if aShape = 'identity' then
  begin
    Assert.AreNotEqual(lOriginal.Project.ContextFingerprint, lCertified.Project.ContextFingerprint);
    Assert.AreNotEqual(lOriginal.Project.ContextObservations.ConfigurationIdentity,
      lCertified.Project.ContextObservations.ConfigurationIdentity);
    Exit;
  end;
  if aShape = 'replace' then
  begin
    Assert.IsTrue(lCertified.Project.DefineEvidenceComplete);
    Assert.AreEqual('DEBUG;FEATURE', String.Join(';', lCertified.Project.Defines));
    Exit;
  end;
  if aShape = 'empty' then
  begin
    Assert.IsTrue(lCertified.Project.DefineEvidenceComplete);
    Assert.AreEqual<Integer>(0, Length(lCertified.Project.Defines));
    Exit;
  end;
  lModelOptions := Default(TDelphiSemanticModelOptions);
  lModelOptions.SourceFileName := lDescriptor.Sources[0].SourceFileName;
  lModelOptions.ProjectContextApplied := True;
  lModelOptions.DefineEvidenceComplete := True;
  if aShape = 'legacy-model' then
  begin
    lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lModelOptions);
    Assert.IsFalse(lModel.DefineEvidenceComplete, 'Legacy booleans do not certify an invocation.');
    Exit;
  end;
  lCache := TDelphiSemanticUnitCache.Create(Default(TDelphiSemanticCacheOptions));
  try
    lBefore := lCache.BuildIdentity(lModelOptions);
    lModelOptions.CompilerDefineEvidence := lOptions.CompilerDefineEvidence;
    lModelOptions.CompilerDefineRequest := lDescriptor.Invocation;
    if aShape = 'cache' then
    begin
      lAfter := lCache.BuildIdentity(lModelOptions);
      Assert.AreNotEqual(lBefore.UnitCacheKey, lAfter.UnitCacheKey);
    end else begin
      lModelOptions.DefineEvidenceComplete := False;
      lModel := lCache.GetOrExtractUnitModel(lModelOptions);
      Assert.IsTrue(lModel.DefineEvidenceComplete, 'Validated evidence, not the legacy flag, establishes completeness.');
    end;
  finally
    lCache.Free;
  end;
end;

procedure TCompilerDefineEvidenceTests.ChangedProducerAbortsModelPublication(const aShape: string);
var
  lDescriptor: TDelphiSemanticCompilerDefineDescriptor;
  lModelOptions: TDelphiSemanticModelOptions;
  lCache: TDelphiSemanticUnitCache;
  lCurrent, lRefused: Boolean;
begin
  lDescriptor := ClosedDescriptor;
  lModelOptions := Default(TDelphiSemanticModelOptions);
  lModelOptions.SourceFileName := lDescriptor.Sources[0].SourceFileName;
  lModelOptions.ProjectContextApplied := True;
  lModelOptions.CompilerDefineRequest := lDescriptor.Invocation;
  lCurrent := True;
  lModelOptions.CompilerDefineEvidence := TTestDefineEvidence.Create(lDescriptor,
    function: Boolean
    begin
      Result := lCurrent;
    end);
  lCache := TDelphiSemanticUnitCache.Create(Default(TDelphiSemanticCacheOptions));
  try
    if aShape = 'warm' then
    begin
      lCache.GetOrExtractUnitModel(lModelOptions);
      // Reuse the frozen certificate, as a project-session worker does.
      lModelOptions := AdmitCompilerDefineModelOptions(lModelOptions);
      lCurrent := False;
    end;
    lRefused := False;
    try
      lCache.GetOrBuildUnitModelWithStatus(lModelOptions,
        function(const aOptions: TDelphiSemanticModelOptions): TDelphiSemanticUnitModel
        begin
          Result := TDelphiSemanticUnitModelExtractor.ExtractFromFile(aOptions);
          lCurrent := False;
        end);
    except
      on E: EInvalidOpException do
        lRefused := Pos('COMPILER_DEFINE_EVIDENCE_CHANGED', E.Message) > 0;
    end;
    Assert.IsTrue(lRefused, 'A native value change aborts publication or reuse.');
  finally
    lCache.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TCompilerDefineEvidenceTests);

end.
