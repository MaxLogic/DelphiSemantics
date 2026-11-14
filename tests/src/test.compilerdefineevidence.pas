unit Test.CompilerDefineEvidence;

interface

uses
  DUnitX.TestFramework, DelphiSemantics.Api, DelphiSemantics.CompilerDefineEvidence, DelphiSemantics.Model;

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
    [TestCase('compiler switch identity and immutability', 'switches')]
    procedure AdmitsClosedCompilerInputs(const aShape: string);
    [TestCase('Native 32-bit host', 'A4945A14F9C4DE0CA2B38B4E772F45929235FA515F3621AFB63387AC5F23AC03')]
    [TestCase('Native 64-bit host', '69AE66304E62B37EA7C2DB59A563BE2E416F5D6ADF77FB5D42EDFE5FA02FB7F9')]
    procedure AdmitsVerifiedNativeCompilerHost(const aCompilerHash: string);
    [TestCase('Win32 native 32-bit host', 'BD301B7A6B56EB3D34C714545ABF7D2044D17C6B7641C7FBDF4BDCECB90D2378')]
    [TestCase('Win32 native 64-bit host', '7B746D2F234AC262014A3524CD6CA559860370C56D10CA43806E953A9CDEA765')]
    procedure AdmitsVerifiedWin32CompilerHost(const aCompilerHash: string);
    [Test]
    procedure AdmitsVerifiedLinuxCompiler;
    [TestCase('Linux64 wrong-states', 'Linux64,wrong-states')]
    [TestCase('Linux64 partial', 'Linux64,partial')]
    [TestCase('Linux64 missing-false', 'Linux64,missing-false')]
    [TestCase('Linux64 missing table', 'Linux64,missing-table')]
    [TestCase('Linux64 bcb', 'Linux64,bcb')]
    [TestCase('Win32 wrong-states', 'Win32,wrong-states')]
    [TestCase('Win32 partial', 'Win32,partial')]
    [TestCase('Win32 missing-false', 'Win32,missing-false')]
    [TestCase('Win32 bcb', 'Win32,bcb')]
    [TestCase('Win64 wrong-states', 'Win64,wrong-states')]
    [TestCase('Win64 partial', 'Win64,partial')]
    [TestCase('Win64 missing-false', 'Win64,missing-false')]
    [TestCase('Win64 bcb', 'Win64,bcb')]
    procedure RejectsMislabeledNativeTable(const aPlatform, aShape: string);
    [TestCase('Win64 table on Win32', 'win64-table')]
    [TestCase('Win32 table on Win64', 'win32-table')]
    [TestCase('Win64 hash on Win32', 'win64-hash')]
    [TestCase('Win32 hash on Win64', 'win32-hash')]
    [TestCase('Wrong compiler filename', 'filename')]
    [TestCase('Tampered Linux compiler', 'linux-hash')]
    [TestCase('Wrong Linux compiler filename', 'linux-filename')]
    [TestCase('Stale Win32 producer', 'stale')]
    procedure RejectsMismatchedCompilerSelection(const aShape: string);
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
    [TestCase('missing switch format', 'switch-format')]
    [TestCase('missing switch identity', 'switch-identity')]
    [TestCase('invalid switch state', 'switch-value')]
    [TestCase('unsupported switch', 'switch-unknown')]
    [TestCase('contradictory switch', 'switch-duplicate')]
    procedure RejectsUnprovedInputs(const aShape: string);
    [Test]
    [TestCase('cold publication', 'cold')]
    [TestCase('warm reuse', 'warm')]
    procedure ChangedProducerAbortsModelPublication(const aShape: string);
    [TestCase('Dependency transport is not semantic input', 'transport')]
    [TestCase('Source selection is immutable', 'source')]
    [TestCase('DCU has no source applicability', 'dcu')]
    [TestCase('Legacy selection format requires re-plan', 'legacy-format')]
    [TestCase('Missing format', 'format')]
    [TestCase('Missing dependency digest', 'dependency')]
    [TestCase('Unmatched source witness', 'witness')]
    [TestCase('Duplicate unit selection', 'duplicate')]
    [TestCase('DCU cannot grant source evidence', 'dcu-source')]
    [TestCase('Capture failure cannot publish rows', 'failure')]
    procedure ValidatesNativeSourceSelection(const aShape: string);
    [Test]
    procedure FrozenModelAdmissionDoesNotReevaluateNativeInputs;
    [TestCase('Before facts publication', 'facts')]
    [TestCase('Before snapshot publication', 'snapshot')]
    [TestCase('Before warm snapshot reuse', 'warm')]
    procedure SessionCurrentnessRemainsAtCheckpoints(const aShape: string);
  end;

// Only generated, closed synthetic test universes may use this producer.
function ClosedTestCompilerDefines(const aRequest: TDelphiSemanticCompilerDefineRequest;
  const aSources, aDefines: TArray<string>;
  const aPredefinedFalse: TArray<string> = nil): IDelphiSemanticCompilerDefineEvidence;

// Explicit fixture opt-in; never use for native projects, corpora or RTL.
procedure CertifyClosedGeneratedProject(var aOptions: TDelphiSemanticApiOptions;
  const aGeneratedRoot: string; const aDefines: TArray<string>;
  const aPredefinedFalse: TArray<string> = nil);

// A direct model can also describe a deliberately closed generated universe.
procedure CertifyClosedGeneratedModel(var aOptions: TDelphiSemanticModelOptions);

implementation

uses
  System.Hash, System.IOUtils, System.SysUtils,
  DelphiSemantics.Cache,
  DelphiSemantics.ProjectContext, DelphiSemantics.ProjectSession,
  Test.Support;

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
  Result.Sources[0].SourceFileName := FixturePath('ProjectContext\Basic', 'BasicProject.dpr');
  Result.Sources[0].ContentHash := THashSHA2.GetHashStringFromFile(Result.Sources[0].SourceFileName);
end;

function ClosedTestCompilerDefines(const aRequest: TDelphiSemanticCompilerDefineRequest;
  const aSources, aDefines, aPredefinedFalse: TArray<string>): IDelphiSemanticCompilerDefineEvidence;
var
  i: Integer;
  lDescriptor: TDelphiSemanticCompilerDefineDescriptor;
begin
  lDescriptor := ClosedDescriptor;
  lDescriptor.Invocation := aRequest;
  lDescriptor.Defines := Copy(aDefines);
  if Length(aPredefinedFalse) > 0 then
  begin
    lDescriptor.PredefinedFormat := 'compiler-predefines-23-' + LowerCase(aRequest.Platform) + '-v1';
    lDescriptor.PredefinedIdentity := 'explicit-closed-generated-predefined-states-v1';
    lDescriptor.PredefinedFalse := Copy(aPredefinedFalse);
  end;
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

procedure CertifyClosedGeneratedModel(var aOptions: TDelphiSemanticModelOptions);
begin
  Assert.IsTrue(TFile.Exists(aOptions.SourceFileName));
  Assert.IsTrue(aOptions.CompilerDefineEvidence = nil, 'Do not replace an existing witness.');
  aOptions.CompilerDefineRequest.ProjectFileName := TPath.ChangeExtension(aOptions.SourceFileName, '.dproj');
  aOptions.CompilerDefineRequest.MainSourceFileName := aOptions.SourceFileName;
  aOptions.CompilerDefineRequest.Configuration := 'Debug';
  aOptions.CompilerDefineRequest.Platform := 'Win64';
  aOptions.CompilerDefineRequest.DelphiVersion := '23.0';
  aOptions.CompilerDefineEvidence := ClosedTestCompilerDefines(aOptions.CompilerDefineRequest,
    [aOptions.SourceFileName], aOptions.Defines);
end;

procedure CertifyClosedGeneratedProject(var aOptions: TDelphiSemanticApiOptions;
  const aGeneratedRoot: string; const aDefines, aPredefinedFalse: TArray<string>);
var
  lContext: TDelphiSemanticContextResult;
  lRequest: TDelphiSemanticCompilerDefineRequest;
  lSources: TArray<string>;
begin
  Assert.AreEqual(TPath.GetFullPath(aGeneratedRoot),
    TPath.GetDirectoryName(TPath.GetFullPath(aOptions.ProjectFileName)),
    'A closed generated fixture must own its entire project source root.');
  Assert.IsFalse(aOptions.CompilerDefineEvidence <> nil, 'Do not replace an existing witness.');
  lContext := TDelphiSemanticApi.LoadProjectContext(aOptions.ProjectFileName, aOptions);
  Assert.IsTrue(lContext.Success);
  lRequest := Default(TDelphiSemanticCompilerDefineRequest);
  lRequest.ProjectFileName := lContext.Project.ProjectFileName;
  lRequest.MainSourceFileName := lContext.Project.MainSourceFileName;
  lRequest.Configuration := lContext.Project.Configuration;
  lRequest.Platform := lContext.Project.Platform;
  lRequest.DelphiVersion := aOptions.DelphiVersion;
  lSources := TDirectory.GetFiles(aGeneratedRoot, '*.pas', TSearchOption.soTopDirectoryOnly);
  lSources := lSources + [lRequest.MainSourceFileName];
  aOptions.CompilerDefineEvidence := ClosedTestCompilerDefines(lRequest, lSources, aDefines, aPredefinedFalse);
end;

function NativeTableDescriptor(const aPlatform: string): TDelphiSemanticCompilerDefineDescriptor;
begin
  Result := ClosedDescriptor;
  Result.CaptureKind := 'native-msbuild-dcc-inputs-v1';
  Result.Invocation.Platform := aPlatform;
  Result.PredefinedIdentity := 'native-probe-table';
  if aPlatform = 'Linux64' then
  begin
    Result.CompilerFileName := TPath.GetFullPath('dcclinux64.exe');
    Result.CompilerHash := '7887660DBBB0C055B2AC6CB933020D6F966DD2A1E5913320C9D4C34980060B02';
    Result.PredefinedFormat := 'compiler-predefines-23-linux64-v1';
    Result.PredefinedTrue := ['CONDITIONALEXPRESSIONS', 'CPU64BITS', 'CPUX64', 'DCC', 'ELF',
      'EXTERNALLINKER', 'LINUX', 'LINUX64', 'LLVM', 'MANAGED_RECORD',
      'NATIVECODE', 'PIC', 'POSIX', 'POSIX64', 'UNICODE',
      'VER360', 'WEAKINTFREF', 'WEAKREF', 'WEAK_NATIVEINT'];
    Result.PredefinedFalse := ['ALIGN_STACK', 'ANDROID', 'ANDROID32', 'ANDROID64', 'ASSEMBLER',
      'AUTOREFCOUNT', 'BCB', 'CPU32BITS', 'CPU386', 'CPUARM',
      'CPUARM32', 'CPUARM64', 'CPUX86', 'IOS', 'IOS32',
      'IOS64', 'IOSSIMULATOR', 'LINUX32', 'MACOS', 'MACOS32',
      'MACOS64', 'MSWINDOWS', 'NEXTGEN', 'OSX', 'OSX32',
      'OSX64', 'PC_MAPPED_EXCEPTIONS', 'POSIX32', 'UNDERSCOREIMPORTNAME', 'VER120',
      'VER80', 'VER90', 'WEAKINSTREF', 'WIN32', 'WIN64'];
  end else if aPlatform = 'Win32' then
  begin
    Result.CompilerFileName := TPath.GetFullPath('dcc32.exe');
    Result.CompilerHash := 'BD301B7A6B56EB3D34C714545ABF7D2044D17C6B7641C7FBDF4BDCECB90D2378';
    Result.PredefinedFormat := 'compiler-predefines-23-win32-v1';
    Result.PredefinedTrue := ['ASSEMBLER', 'CONDITIONALEXPRESSIONS', 'CPU32BITS', 'CPU386',
      'CPUX86', 'DCC', 'MANAGED_RECORD', 'MSWINDOWS', 'NATIVECODE', 'UNDERSCOREIMPORTNAME', 'UNICODE',
      'VER360', 'WEAKINTFREF', 'WEAKREF', 'WEAK_NATIVEINT', 'WIN32'];
    Result.PredefinedFalse := ['ALIGN_STACK', 'ANDROID', 'ANDROID32', 'ANDROID64', 'AUTOREFCOUNT',
      'BCB', 'CPU64BITS', 'CPUARM', 'CPUARM32', 'CPUARM64', 'CPUX64', 'ELF', 'EXTERNALLINKER', 'IOS',
      'IOS32', 'IOS64', 'IOSSIMULATOR', 'LINUX', 'LINUX32', 'LINUX64', 'LLVM', 'MACOS', 'MACOS32', 'MACOS64',
      'NEXTGEN', 'OSX', 'OSX32', 'OSX64', 'PC_MAPPED_EXCEPTIONS', 'PIC', 'POSIX', 'POSIX32', 'POSIX64',
      'VER120', 'VER80', 'VER90', 'WEAKINSTREF', 'WIN64'];
  end else begin
    Result.CompilerHash := 'A4945A14F9C4DE0CA2B38B4E772F45929235FA515F3621AFB63387AC5F23AC03';
    Result.PredefinedFormat := 'compiler-predefines-23-win64-v1';
    Result.PredefinedTrue := ['ASSEMBLER', 'CONDITIONALEXPRESSIONS', 'CPU64BITS', 'CPUX64', 'DCC',
      'MANAGED_RECORD', 'MSWINDOWS', 'NATIVECODE', 'UNICODE', 'VER360', 'WEAKINTFREF', 'WEAKREF',
      'WEAK_NATIVEINT', 'WIN64'];
    Result.PredefinedFalse := ['ALIGN_STACK', 'ANDROID', 'ANDROID32', 'ANDROID64', 'AUTOREFCOUNT',
      'BCB', 'CPU32BITS', 'CPU386', 'CPUARM', 'CPUARM32', 'CPUARM64', 'CPUX86', 'ELF', 'EXTERNALLINKER', 'IOS',
      'IOS32', 'IOS64', 'IOSSIMULATOR', 'LINUX', 'LINUX32', 'LINUX64', 'LLVM', 'MACOS', 'MACOS32', 'MACOS64',
      'NEXTGEN', 'OSX', 'OSX32', 'OSX64', 'PC_MAPPED_EXCEPTIONS', 'PIC', 'POSIX', 'POSIX32', 'POSIX64',
      'UNDERSCOREIMPORTNAME', 'VER120', 'VER80', 'VER90', 'WEAKINSTREF', 'WIN32'];
  end;
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

procedure TCompilerDefineEvidenceTests.AdmitsVerifiedWin32CompilerHost(const aCompilerHash: string);
var
  lDescriptor: TDelphiSemanticCompilerDefineDescriptor;
  lEvidence, lAdmitted: IDelphiSemanticCompilerDefineEvidence;
  lReason: string;
begin
  lDescriptor := NativeTableDescriptor('Win32');
  lDescriptor.CompilerHash := aCompilerHash;
  lEvidence := TTestDefineEvidence.Create(lDescriptor);
  Assert.IsTrue(TDelphiSemanticCompilerDefines.TryAdmit(lEvidence, lDescriptor.Invocation, lAdmitted, lReason),
    lReason);
  Assert.IsTrue(TDelphiSemanticCompilerDefines.AppliesToSource(lAdmitted,
    lDescriptor.Sources[0].SourceFileName));
end;

procedure TCompilerDefineEvidenceTests.AdmitsVerifiedLinuxCompiler;
var
  lDescriptor: TDelphiSemanticCompilerDefineDescriptor;
  lEvidence, lAdmitted: IDelphiSemanticCompilerDefineEvidence;
  lReason: string;
begin
  lDescriptor := NativeTableDescriptor('Linux64');
  lEvidence := TTestDefineEvidence.Create(lDescriptor);
  Assert.IsTrue(TDelphiSemanticCompilerDefines.TryAdmit(lEvidence,
    lDescriptor.Invocation, lAdmitted, lReason), lReason);
  Assert.IsTrue(TDelphiSemanticCompilerDefines.AppliesToSource(lAdmitted,
    lDescriptor.Sources[0].SourceFileName));
end;

procedure TCompilerDefineEvidenceTests.RejectsMislabeledNativeTable(const aPlatform, aShape: string);
var
  lDescriptor, lOther: TDelphiSemanticCompilerDefineDescriptor;
  lEvidence, lAdmitted: IDelphiSemanticCompilerDefineEvidence;
  lReason, lSymbol: string;
  lFalse: TArray<string>;
begin
  lDescriptor := NativeTableDescriptor(aPlatform);
  if aPlatform = 'Win32' then
    lOther := NativeTableDescriptor('Win64')
  else
    lOther := NativeTableDescriptor('Win32');
  if aShape = 'wrong-states' then
  begin
    lDescriptor.PredefinedTrue := lOther.PredefinedTrue;
    lDescriptor.PredefinedFalse := lOther.PredefinedFalse;
  end else if aShape = 'partial' then
    lDescriptor.PredefinedTrue := [UpperCase(aPlatform)]
  else if aShape = 'missing-table' then
  begin
    lDescriptor.PredefinedFormat := '';
    lDescriptor.PredefinedIdentity := '';
    lDescriptor.PredefinedTrue := nil;
    lDescriptor.PredefinedFalse := nil;
  end else if aShape = 'missing-false' then
    lDescriptor.PredefinedFalse := nil
  else
  begin
    lDescriptor.PredefinedTrue := lDescriptor.PredefinedTrue + ['BCB'];
    lFalse := nil;
    for lSymbol in lDescriptor.PredefinedFalse do
      if lSymbol <> 'BCB' then
        lFalse := lFalse + [lSymbol];
    lDescriptor.PredefinedFalse := lFalse;
  end;
  lEvidence := TTestDefineEvidence.Create(lDescriptor);
  Assert.IsFalse(TDelphiSemanticCompilerDefines.TryAdmit(lEvidence,
    lDescriptor.Invocation, lAdmitted, lReason), 'Native table contents must match the compiler, not its label.');
  Assert.IsNull(lAdmitted);
  Assert.Contains(lReason, 'predefined');
end;

procedure TCompilerDefineEvidenceTests.RejectsMismatchedCompilerSelection(const aShape: string);
var
  lDescriptor: TDelphiSemanticCompilerDefineDescriptor;
  lEvidence, lAdmitted: IDelphiSemanticCompilerDefineEvidence;
  lReason: string;
begin
  lDescriptor := ClosedDescriptor;
  lDescriptor.CaptureKind := 'native-msbuild-dcc-inputs-v1';
  lDescriptor.Invocation.Platform := 'Win32';
  lDescriptor.CompilerFileName := TPath.GetFullPath('dcc32.exe');
  lDescriptor.CompilerHash := 'BD301B7A6B56EB3D34C714545ABF7D2044D17C6B7641C7FBDF4BDCECB90D2378';
  lDescriptor.PredefinedFormat := 'compiler-predefines-23-win32-v1';
  lDescriptor.PredefinedIdentity := 'native-dcc32-probe-table';
  lDescriptor.PredefinedTrue := ['WIN32'];
  if aShape = 'win64-table' then
    lDescriptor.PredefinedFormat := 'compiler-predefines-23-win64-v1';
  if aShape = 'win32-table' then
  begin
    lDescriptor.Invocation.Platform := 'Win64';
    lDescriptor.CompilerFileName := TPath.GetFullPath('dcc64.exe');
    lDescriptor.CompilerHash := 'A4945A14F9C4DE0CA2B38B4E772F45929235FA515F3621AFB63387AC5F23AC03';
  end;
  if aShape = 'win64-hash' then
    lDescriptor.CompilerHash := 'A4945A14F9C4DE0CA2B38B4E772F45929235FA515F3621AFB63387AC5F23AC03';
  if aShape = 'win32-hash' then
    lDescriptor.Invocation.Platform := 'Win64';
  if aShape = 'filename' then
    lDescriptor.CompilerFileName := TPath.GetFullPath('dcc64.exe');
  if aShape.StartsWith('linux-') then
  begin
    lDescriptor := NativeTableDescriptor('Linux64');
    if aShape = 'linux-hash' then
      lDescriptor.CompilerHash := StringOfChar('0', 64)
    else
      lDescriptor.CompilerFileName := TPath.GetFullPath('dcc64.exe');
  end;
  if aShape = 'stale' then
    lDescriptor.ProducerInputIdentity := 'stale';
  lEvidence := TTestDefineEvidence.Create(lDescriptor);
  Assert.IsFalse(TDelphiSemanticCompilerDefines.TryAdmit(lEvidence, lDescriptor.Invocation, lAdmitted, lReason));
  Assert.IsNull(lAdmitted);
  Assert.IsNotEmpty(lReason);
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
  if aShape = 'switches' then
  begin
    lDescriptor.CompilerSwitchFormat := 'compiler-switches-23-windows-v1';
    lDescriptor.CompilerSwitchIdentity := 'closed-switch-inputs-v1';
    lDescriptor.CompilerSwitches := ['R+', 'Q-', 'O+', 'I+', 'H+'];
  end;
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
  if aShape = 'switches' then
  begin
    lDescriptor.CompilerSwitches[0] := 'R-';
    lRead := lAdmitted.Descriptor;
    Assert.AreEqual('R+', lRead.CompilerSwitches[0]);
    lRead.CompilerSwitches[0] := 'R-';
    Assert.AreEqual('R+', lAdmitted.Descriptor.CompilerSwitches[0]);
    lProvider := TTestDefineEvidence.Create(lDescriptor);
    Assert.IsTrue(TDelphiSemanticCompilerDefines.TryAdmit(lProvider, lDescriptor.Invocation,
      lEquivalent, lReason), lReason);
    Assert.AreNotEqual(TDelphiSemanticCompilerDefines.Fingerprint(lAdmitted),
      TDelphiSemanticCompilerDefines.Fingerprint(lEquivalent),
      'Changing only an effective switch invalidates dependent artifacts.');
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

procedure TCompilerDefineEvidenceTests.ValidatesNativeSourceSelection(const aShape: string);
var
  lDescriptor, lRead: TDelphiSemanticCompilerDefineDescriptor;
  lProvider, lAdmitted, lChanged: IDelphiSemanticCompilerDefineEvidence;
  lReason, lFingerprint: string;
begin
  lDescriptor := ClosedDescriptor;
  lDescriptor.Sources[0].SourceFileName :=
    TPath.GetFullPath('tests/fixtures/RemoveWithPointerEvaluation/PointerReceiverUnit.pas');
  lDescriptor.Sources[0].ContentHash := THashSHA2.GetHashStringFromFile(lDescriptor.Sources[0].SourceFileName);
  lDescriptor.SourceSelectionFormat := 'dcc-dependencies-rebuilt-units-v2';
  lDescriptor.SourceSelectionIdentity := StringOfChar('B', 64);
  lDescriptor.DependencyContentHash := StringOfChar('C', 64);
  SetLength(lDescriptor.SourceSelections, 1);
  lDescriptor.SourceSelections[0].UnitName := lDescriptor.Sources[0].UnitName;
  lDescriptor.SourceSelections[0].DependencyFileName :=
    TPath.ChangeExtension(lDescriptor.Sources[0].SourceFileName, '.dcu');
  lDescriptor.SourceSelections[0].Kind := 'source';
  lDescriptor.SourceSelections[0].SourceFileName := lDescriptor.Sources[0].SourceFileName;
  lDescriptor.SourceSelections[0].ContentHash := lDescriptor.Sources[0].ContentHash;
  lDescriptor.SourceSelections[0].CompiledUnitHash := StringOfChar('D', 64);
  if (aShape = 'dcu') or (aShape = 'dcu-source') then
  begin
    lDescriptor.SourceSelections[0].Kind := 'dcu';
    lDescriptor.SourceSelections[0].SourceFileName := '';
    lDescriptor.SourceSelections[0].CompiledUnitHash := '';
    if aShape = 'dcu' then
      lDescriptor.Sources := nil;
  end;
  if aShape = 'legacy-format' then
    lDescriptor.SourceSelectionFormat := 'dcc-dependencies-rebuilt-units-v1';
  if aShape = 'format' then lDescriptor.SourceSelectionFormat := '';
  if aShape = 'dependency' then lDescriptor.DependencyContentHash := '';
  if aShape = 'witness' then lDescriptor.SourceSelections[0].ContentHash := StringOfChar('E', 64);
  if aShape = 'duplicate' then
    lDescriptor.SourceSelections := lDescriptor.SourceSelections + [lDescriptor.SourceSelections[0]];
  if aShape = 'failure' then lDescriptor.SourceSelectionReason := 'compile failed';
  lProvider := TTestDefineEvidence.Create(lDescriptor);
  if (aShape <> 'source') and (aShape <> 'dcu') and (aShape <> 'transport') then
  begin
    Assert.IsFalse(TDelphiSemanticCompilerDefines.TryAdmit(lProvider, lDescriptor.Invocation,
      lAdmitted, lReason), 'Malformed source selection must fail closed.');
    Assert.IsNotEmpty(lReason);
    if aShape = 'legacy-format' then
      Assert.IsTrue(lReason.Contains('re-plan'), lReason);
    Exit;
  end;
  Assert.IsTrue(TDelphiSemanticCompilerDefines.TryAdmit(lProvider, lDescriptor.Invocation,
    lAdmitted, lReason), lReason);
  if aShape = 'dcu' then
  begin
    Assert.IsFalse(TDelphiSemanticCompilerDefines.AppliesToSource(lAdmitted,
      TPath.ChangeExtension(lDescriptor.SourceSelections[0].DependencyFileName, '.pas')));
    Exit;
  end;
  lFingerprint := TDelphiSemanticCompilerDefines.Fingerprint(lAdmitted);
  if aShape = 'transport' then
  begin
    // Native .d headers name a unique owned output directory on every launch.
    // Unchanged parsed dependencies and selected bytes must reuse the snapshot.
    lDescriptor.DependencyContentHash := StringOfChar('E', 64);
    lProvider := TTestDefineEvidence.Create(lDescriptor);
    Assert.IsTrue(TDelphiSemanticCompilerDefines.TryAdmit(lProvider, lDescriptor.Invocation,
      lChanged, lReason), lReason);
    Assert.AreEqual(lFingerprint, TDelphiSemanticCompilerDefines.Fingerprint(lChanged));
    Exit;
  end;
  lDescriptor.SourceSelections[0].CompiledUnitHash := StringOfChar('E', 64);
  lDescriptor.SourceSelectionIdentity := StringOfChar('F', 64);
  lProvider := TTestDefineEvidence.Create(lDescriptor);
  Assert.IsTrue(TDelphiSemanticCompilerDefines.TryAdmit(lProvider, lDescriptor.Invocation,
    lChanged, lReason), lReason);
  Assert.AreNotEqual(lFingerprint, TDelphiSemanticCompilerDefines.Fingerprint(lChanged));
  lRead := lAdmitted.Descriptor;
  Assert.AreEqual(StringOfChar('D', 64), lRead.SourceSelections[0].CompiledUnitHash);
  lRead.SourceSelections[0].Kind := 'dcu';
  lRead := lAdmitted.Descriptor;
  Assert.AreEqual('source', lRead.SourceSelections[0].Kind);
  Assert.AreEqual(lFingerprint, TDelphiSemanticCompilerDefines.Fingerprint(lAdmitted));
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
  if aShape.StartsWith('switch-') then
  begin
    lDescriptor.CompilerSwitchFormat := 'compiler-switches-23-windows-v1';
    lDescriptor.CompilerSwitchIdentity := 'closed-switch-inputs-v1';
    lDescriptor.CompilerSwitches := ['R+'];
    if aShape = 'switch-format' then lDescriptor.CompilerSwitchFormat := '';
    if aShape = 'switch-identity' then lDescriptor.CompilerSwitchIdentity := '';
    if aShape = 'switch-value' then lDescriptor.CompilerSwitches := ['R?'];
    if aShape = 'switch-unknown' then lDescriptor.CompilerSwitches := ['Z+'];
    if aShape = 'switch-duplicate' then lDescriptor.CompilerSwitches := ['R+', 'R-'];
  end;
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
  lOptions.ProjectPath := FixturePath('ProjectContext\Basic', 'BasicProject.dproj');
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

procedure TCompilerDefineEvidenceTests.FrozenModelAdmissionDoesNotReevaluateNativeInputs;
var
  lDescriptor: TDelphiSemanticCompilerDefineDescriptor;
  lEvidence, lAdmitted, lReadmitted: IDelphiSemanticCompilerDefineEvidence;
  lOptions: TDelphiSemanticModelOptions;
  lReason: string;
  lEvaluations: Integer;
begin
  lDescriptor := ClosedDescriptor;
  lEvaluations := 0;
  lEvidence := TTestDefineEvidence.Create(lDescriptor,
    function: Boolean
    begin
      Inc(lEvaluations);
      Result := True;
    end);
  Assert.IsTrue(TDelphiSemanticCompilerDefines.TryAdmit(lEvidence, lDescriptor.Invocation, lAdmitted, lReason), lReason);
  Assert.AreEqual(1, lEvaluations, 'Admission validates the producer once.');
  Assert.IsTrue(TDelphiSemanticCompilerDefines.TryAdmit(lAdmitted, lDescriptor.Invocation, lReadmitted, lReason), lReason);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lDescriptor.Sources[0].SourceFileName;
  lOptions.CompilerDefineEvidence := lReadmitted;
  lOptions.CompilerDefineRequest := lDescriptor.Invocation;
  for var i := 1 to 8 do
  begin
    lOptions := AdmitCompilerDefineModelOptions(lOptions);
    Assert.IsTrue(lOptions.DefineEvidenceComplete);
  end;
  Assert.AreEqual(1, lEvaluations,
    'Model admission reuses the frozen descriptor; currentness belongs to publication/reuse checkpoints.');
  lDescriptor.Invocation.Configuration := 'Release';
  Assert.IsFalse(TDelphiSemanticCompilerDefines.TryAdmit(lAdmitted,
    lDescriptor.Invocation, lReadmitted, lReason), 'Frozen evidence cannot move to another request.');
  Assert.AreEqual(1, lEvaluations, 'Request mismatch refuses without native re-admission.');
end;

procedure TCompilerDefineEvidenceTests.SessionCurrentnessRemainsAtCheckpoints(const aShape: string);
var
  lDescriptor: TDelphiSemanticCompilerDefineDescriptor;
  lOptions: TDelphiSemanticOptions;
  lOpened: TDelphiSemanticProjectSessionResult;
  lCurrent, lRefused: Boolean;
  lEvaluations: Integer;
begin
  lDescriptor := ClosedDescriptor;
  lDescriptor.Invocation.MainSourceFileName := lDescriptor.Sources[0].SourceFileName;
  lDescriptor.Invocation.ProjectFileName := TPath.ChangeExtension(lDescriptor.Invocation.MainSourceFileName, '.dproj');
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := lDescriptor.Invocation.ProjectFileName;
  lOptions.Configuration := 'Debug';
  lOptions.Platform := 'Win64';
  lOptions.DelphiVersion := '23.0';
  lCurrent := True;
  lEvaluations := 0;
  lOptions.CompilerDefineEvidence := TTestDefineEvidence.Create(lDescriptor,
    function: Boolean
    begin
      Inc(lEvaluations);
      Result := lCurrent;
    end);
  if aShape = 'warm' then
    lOptions.SqliteCacheFileName := TPath.Combine(TPath.GetTempPath, 'ds772-' + TGUID.NewGuid.ToString + '.db');
  lOpened := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lOpened.Success);
    Assert.IsTrue(lOpened.Session.Project.DefineEvidenceComplete);
    Assert.AreEqual(1, lEvaluations, 'Session admission validates once.');
    if aShape = 'warm' then
      lOpened.Session.BuildSnapshot.Free;
    lCurrent := False;
    lRefused := False;
    try
      if aShape = 'facts' then
        lOpened.Session.BuildWithBindingFactsResult
      else
        lOpened.Session.BuildSnapshot.Free;
    except
      on E: EInvalidOpException do
        lRefused := Pos('COMPILER_DEFINE_EVIDENCE_CHANGED', E.Message) > 0;
    end;
    Assert.IsTrue(lRefused, 'A mutation after admission must abort publication/reuse.');
  finally
    lOpened.Session.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TCompilerDefineEvidenceTests);

end.
