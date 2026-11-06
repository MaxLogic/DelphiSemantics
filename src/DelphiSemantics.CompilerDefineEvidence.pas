unit DelphiSemantics.CompilerDefineEvidence;

interface

type
  TDelphiSemanticCompilerDefineRequest = record
    ProjectFileName: string;
    MainSourceFileName: string;
    Configuration: string;
    Platform: string;
    DelphiVersion: string;
  end;

  TDelphiSemanticCompilerSourceWitness = record
    UnitName: string;
    SourceFileName: string;
    ContentHash: string;
  end;

  TDelphiSemanticCompilerDefineDescriptor = record
    Format: string;
    Producer: string;
    CaptureKind: string;
    Invocation: TDelphiSemanticCompilerDefineRequest;
    WorkingDirectory: string;
    CompilerFileName: string;
    CompilerHash: string;
    CompilerVersion: string;
    BuildTarget: string;
    RebuildMode: string;
    Defines: TArray<string>;
    OrderedArguments: TArray<string>;
    ProducerInputIdentity: string;
    SourceApplicabilityIdentity: string;
    Sources: TArray<TDelphiSemanticCompilerSourceWitness>;
    PredefinedFormat: string;
    PredefinedIdentity: string;
    PredefinedTrue: TArray<string>;
    PredefinedFalse: TArray<string>;
  end;

  // The producer owns native inputs and re-evaluation. Descriptor reads occur
  // once at admission; the admitted wrapper returns only defensive copies.
  IDelphiSemanticCompilerDefineEvidence = interface
    ['{E424FE43-BEF9-4502-9782-93FC5F27F7B2}']
    function Descriptor: TDelphiSemanticCompilerDefineDescriptor;
    function InputsAreCurrent(out aReason: string): Boolean;
  end;

  TDelphiSemanticCompilerDefines = record
  public
    class function TryAdmit(const aEvidence: IDelphiSemanticCompilerDefineEvidence;
      const aRequest: TDelphiSemanticCompilerDefineRequest;
      out aAdmitted: IDelphiSemanticCompilerDefineEvidence; out aReason: string): Boolean; static;
    class function SameDefines(const aLeft, aRight: TArray<string>): Boolean; static;
    class function Fingerprint(const aEvidence: IDelphiSemanticCompilerDefineEvidence): string; static;
    class function AppliesToSource(const aEvidence: IDelphiSemanticCompilerDefineEvidence;
      const aSourceFileName: string): Boolean; static;
    class function EffectiveDefines(const aEvidence: IDelphiSemanticCompilerDefineEvidence): TArray<string>; static;
    class procedure RequireCurrent(const aEvidence: IDelphiSemanticCompilerDefineEvidence); static;
    // A session publishes the combined result after a single native checkpoint.
    // Individual models inside it never publish an independently current context.
    class function ForSession(const aEvidence: IDelphiSemanticCompilerDefineEvidence):
      IDelphiSemanticCompilerDefineEvidence; static;
    class procedure RequireCurrentAtCheckpoint(
      const aEvidence: IDelphiSemanticCompilerDefineEvidence); static;
  end;

implementation

uses
  System.Classes, System.Hash, System.IOUtils, System.SysUtils;

type
  IAdmittedCompilerDefineEvidence = interface
    ['{37818CE0-922B-47C0-834F-A28E3C74A42F}']
    function EvidenceFingerprint: string;
  end;

  TAdmittedCompilerDefineEvidence = class(TInterfacedObject,
    IDelphiSemanticCompilerDefineEvidence, IAdmittedCompilerDefineEvidence)
  private
    fDescriptor: TDelphiSemanticCompilerDefineDescriptor;
    fProducer: IDelphiSemanticCompilerDefineEvidence;
    fFingerprint: string;
  public
    constructor Create(const aDescriptor: TDelphiSemanticCompilerDefineDescriptor;
      const aProducer: IDelphiSemanticCompilerDefineEvidence; const aFingerprint: string);
    function Descriptor: TDelphiSemanticCompilerDefineDescriptor;
    function InputsAreCurrent(out aReason: string): Boolean;
    function EvidenceFingerprint: string;
  end;

type
  ISessionCompilerDefineEvidence = interface
    ['{832C8B54-ED02-4BCC-8375-F7859A8C5275}']
  end;

  TSessionCompilerDefineEvidence = class(TInterfacedObject,
    IDelphiSemanticCompilerDefineEvidence, IAdmittedCompilerDefineEvidence, ISessionCompilerDefineEvidence)
  private
    fAdmitted: IDelphiSemanticCompilerDefineEvidence;
  public
    constructor Create(const aAdmitted: IDelphiSemanticCompilerDefineEvidence);
    function Descriptor: TDelphiSemanticCompilerDefineDescriptor;
    function InputsAreCurrent(out aReason: string): Boolean;
    function EvidenceFingerprint: string;
  end;

constructor TSessionCompilerDefineEvidence.Create(const aAdmitted: IDelphiSemanticCompilerDefineEvidence);
begin
  inherited Create;
  fAdmitted := aAdmitted;
end;

function TSessionCompilerDefineEvidence.Descriptor: TDelphiSemanticCompilerDefineDescriptor;
begin
  Result := fAdmitted.Descriptor;
end;

function TSessionCompilerDefineEvidence.InputsAreCurrent(out aReason: string): Boolean;
begin
  // Explicit producer queries always re-evaluate, including on session evidence.
  Result := fAdmitted.InputsAreCurrent(aReason);
end;

function TSessionCompilerDefineEvidence.EvidenceFingerprint: string;
begin
  Result := TDelphiSemanticCompilerDefines.Fingerprint(fAdmitted);
end;

function CopyDescriptor(const aDescriptor: TDelphiSemanticCompilerDefineDescriptor):
  TDelphiSemanticCompilerDefineDescriptor;
begin
  Result := aDescriptor;
  Result.Defines := Copy(aDescriptor.Defines);
  Result.OrderedArguments := Copy(aDescriptor.OrderedArguments);
  Result.Sources := Copy(aDescriptor.Sources);
  Result.PredefinedTrue := Copy(aDescriptor.PredefinedTrue);
  Result.PredefinedFalse := Copy(aDescriptor.PredefinedFalse);
end;

function CanonicalPath(const aPath: string): string;
begin
  if aPath = '' then
    Exit('');
  Result := LowerCase(ExcludeTrailingPathDelimiter(TPath.GetFullPath(aPath)));
end;

function IsDigest(const aValue: string): Boolean;
var
  c: Char;
begin
  if Length(aValue) <> 64 then
    Exit(False);
  for c in aValue do
    if not CharInSet(c, ['0'..'9', 'a'..'f', 'A'..'F']) then
      Exit(False);
  Result := True;
end;

function IsSymbol(const aValue: string): Boolean;
var
  i: Integer;
begin
  if (aValue = '') or not CharInSet(aValue[1], ['A'..'Z', 'a'..'z', '_']) then
    Exit(False);
  for i := 2 to Length(aValue) do
    if not CharInSet(aValue[i], ['A'..'Z', 'a'..'z', '_', '0'..'9']) then
      Exit(False);
  Result := True;
end;

function NormalizeSymbols(const aSymbols: TArray<string>; out aNormalized: TArray<string>): Boolean;
var
  lItems: TStringList;
  lSymbol: string;
begin
  aNormalized := nil;
  lItems := TStringList.Create;
  try
    lItems.Sorted := True;
    lItems.CaseSensitive := True;
    lItems.Duplicates := dupIgnore;
    for lSymbol in aSymbols do
    begin
      if not IsSymbol(lSymbol) then
        Exit(False);
      lItems.Add(UpperCase(lSymbol));
    end;
    aNormalized := lItems.ToStringArray;
    Result := True;
  finally
    lItems.Free;
  end;
end;

procedure AppendValue(const aBuilder: TStringBuilder; const aValue: string);
begin
  aBuilder.Append(Length(aValue)).Append(':').Append(aValue);
end;

procedure AppendValues(const aBuilder: TStringBuilder; const aValues: TArray<string>);
var
  lValue: string;
begin
  aBuilder.Append(Length(aValues)).Append(':');
  for lValue in aValues do
    AppendValue(aBuilder, lValue);
end;

function DescriptorFingerprint(const aDescriptor: TDelphiSemanticCompilerDefineDescriptor): string;
var
  lBuilder: TStringBuilder;
  lSource: TDelphiSemanticCompilerSourceWitness;
begin
  lBuilder := TStringBuilder.Create;
  try
    AppendValues(lBuilder, [aDescriptor.Format, aDescriptor.Producer, aDescriptor.CaptureKind,
      aDescriptor.Invocation.ProjectFileName, aDescriptor.Invocation.MainSourceFileName,
      aDescriptor.Invocation.Configuration, aDescriptor.Invocation.Platform, aDescriptor.Invocation.DelphiVersion,
      aDescriptor.WorkingDirectory, aDescriptor.CompilerFileName, aDescriptor.CompilerHash,
      aDescriptor.CompilerVersion, aDescriptor.BuildTarget, aDescriptor.RebuildMode,
      aDescriptor.ProducerInputIdentity, aDescriptor.SourceApplicabilityIdentity,
      aDescriptor.PredefinedFormat, aDescriptor.PredefinedIdentity]);
    AppendValues(lBuilder, aDescriptor.Defines);
    AppendValues(lBuilder, aDescriptor.OrderedArguments);
    AppendValues(lBuilder, aDescriptor.PredefinedTrue);
    AppendValues(lBuilder, aDescriptor.PredefinedFalse);
    lBuilder.Append(Length(aDescriptor.Sources)).Append(':');
    for lSource in aDescriptor.Sources do
      AppendValues(lBuilder, [lSource.UnitName, lSource.SourceFileName, lSource.ContentHash]);
    Result := THashSHA2.GetHashString(lBuilder.ToString);
  finally
    lBuilder.Free;
  end;
end;

constructor TAdmittedCompilerDefineEvidence.Create(
  const aDescriptor: TDelphiSemanticCompilerDefineDescriptor;
  const aProducer: IDelphiSemanticCompilerDefineEvidence; const aFingerprint: string);
begin
  inherited Create;
  fDescriptor := CopyDescriptor(aDescriptor);
  fProducer := aProducer;
  fFingerprint := aFingerprint;
end;

function TAdmittedCompilerDefineEvidence.Descriptor: TDelphiSemanticCompilerDefineDescriptor;
begin
  Result := CopyDescriptor(fDescriptor);
end;

function TAdmittedCompilerDefineEvidence.InputsAreCurrent(out aReason: string): Boolean;
begin
  Result := fProducer.InputsAreCurrent(aReason);
end;

function TAdmittedCompilerDefineEvidence.EvidenceFingerprint: string;
begin
  Result := fFingerprint;
end;

function RequestMatches(const aDescriptor, aRequest: TDelphiSemanticCompilerDefineRequest): Boolean;
begin
  Result := (aRequest.ProjectFileName <> '') and (aRequest.MainSourceFileName <> '') and
    (aRequest.Configuration <> '') and (aRequest.Platform <> '') and (aRequest.DelphiVersion <> '') and
    (CanonicalPath(aDescriptor.ProjectFileName) = CanonicalPath(aRequest.ProjectFileName)) and
    (CanonicalPath(aDescriptor.MainSourceFileName) = CanonicalPath(aRequest.MainSourceFileName)) and
    SameText(aDescriptor.Configuration, aRequest.Configuration) and
    SameText(aDescriptor.Platform, aRequest.Platform) and
    SameText(aDescriptor.DelphiVersion, aRequest.DelphiVersion);
end;

function ValidateDescriptor(var aDescriptor: TDelphiSemanticCompilerDefineDescriptor;
  const aRequest: TDelphiSemanticCompilerDefineRequest; out aReason: string): Boolean;
const
  cVerifiedCompilerHash = 'A4945A14F9C4DE0CA2B38B4E772F45929235FA515F3621AFB63387AC5F23AC03';
  cVerifiedCompiler64Hash = '69AE66304E62B37EA7C2DB59A563BE2E416F5D6ADF77FB5D42EDFE5FA02FB7F9';
var
  i, j: Integer;
  lNormalized: TArray<string>;
  lSymbol: string;
begin
  aReason := 'invalid compiler define evidence envelope';
  if (aDescriptor.Format <> 'ds-compiler-defines-v1') or (aDescriptor.Producer = '') or
    (aDescriptor.CaptureKind = '') or (aDescriptor.ProducerInputIdentity = '') or
    (aDescriptor.SourceApplicabilityIdentity = '') or
    (aDescriptor.WorkingDirectory = '') or (aDescriptor.CompilerFileName = '') or
    not IsDigest(aDescriptor.CompilerHash) or
    (aDescriptor.BuildTarget <> 'Build') or (aDescriptor.RebuildMode <> 'all-source-units') then
    Exit(False);
  aReason := 'compiler define evidence request identity mismatch';
  if not RequestMatches(aDescriptor.Invocation, aRequest) then
    Exit(False);
  aReason := 'compiler define evidence compiler identity unsupported';
  if (aDescriptor.Invocation.DelphiVersion <> '23.0') or
    not SameText(aDescriptor.Invocation.Platform, 'Win64') or
    (aDescriptor.CompilerVersion <> '36.0') then
    Exit(False);
  if (aDescriptor.CaptureKind <> 'closed-generated-test-universe-v1') and
    ((aDescriptor.CaptureKind <> 'native-msbuild-dcc-inputs-v1') or
    (not SameText(aDescriptor.CompilerHash, cVerifiedCompilerHash) and
    not SameText(aDescriptor.CompilerHash, cVerifiedCompiler64Hash))) then
    Exit(False);
  aReason := 'compiler define evidence contains invalid ordinary symbols';
  if not NormalizeSymbols(aDescriptor.Defines, lNormalized) then
    Exit(False);
  aDescriptor.Defines := lNormalized;
  aReason := 'compiler predefined witness invalid';
  if (aDescriptor.PredefinedFormat <> '') or (aDescriptor.PredefinedIdentity <> '') or
    (Length(aDescriptor.PredefinedTrue) <> 0) or (Length(aDescriptor.PredefinedFalse) <> 0) then
  begin
    if (aDescriptor.PredefinedFormat <> 'compiler-predefines-23-win64-v1') or
      (aDescriptor.PredefinedIdentity = '') then
      Exit(False);
    if not NormalizeSymbols(aDescriptor.PredefinedTrue, lNormalized) then
      Exit(False);
    aDescriptor.PredefinedTrue := lNormalized;
    if not NormalizeSymbols(aDescriptor.PredefinedFalse, lNormalized) then
      Exit(False);
    aDescriptor.PredefinedFalse := lNormalized;
    for lSymbol in aDescriptor.PredefinedTrue do
      for i := 0 to High(aDescriptor.PredefinedFalse) do
        if lSymbol = aDescriptor.PredefinedFalse[i] then
          Exit(False);
  end;
  aDescriptor.Invocation.ProjectFileName := CanonicalPath(aDescriptor.Invocation.ProjectFileName);
  aDescriptor.Invocation.MainSourceFileName := CanonicalPath(aDescriptor.Invocation.MainSourceFileName);
  aDescriptor.Invocation.Configuration := LowerCase(aDescriptor.Invocation.Configuration);
  aDescriptor.Invocation.Platform := LowerCase(aDescriptor.Invocation.Platform);
  aDescriptor.WorkingDirectory := CanonicalPath(aDescriptor.WorkingDirectory);
  aDescriptor.CompilerFileName := CanonicalPath(aDescriptor.CompilerFileName);
  aDescriptor.CompilerHash := UpperCase(aDescriptor.CompilerHash);
  aReason := 'compiler define evidence source applicability invalid';
  for i := 0 to High(aDescriptor.Sources) do
  begin
    if (aDescriptor.Sources[i].SourceFileName = '') or
      (aDescriptor.Sources[i].UnitName = '') or not IsDigest(aDescriptor.Sources[i].ContentHash) then
      Exit(False);
    aDescriptor.Sources[i].UnitName := UpperCase(aDescriptor.Sources[i].UnitName);
    aDescriptor.Sources[i].SourceFileName := CanonicalPath(aDescriptor.Sources[i].SourceFileName);
    aDescriptor.Sources[i].ContentHash := UpperCase(aDescriptor.Sources[i].ContentHash);
    for j := 0 to i - 1 do
      if (aDescriptor.Sources[j].UnitName = aDescriptor.Sources[i].UnitName) or
        (aDescriptor.Sources[j].SourceFileName = aDescriptor.Sources[i].SourceFileName) then
        Exit(False);
  end;
  aReason := '';
  Result := True;
end;

class function TDelphiSemanticCompilerDefines.TryAdmit(
  const aEvidence: IDelphiSemanticCompilerDefineEvidence;
  const aRequest: TDelphiSemanticCompilerDefineRequest;
  out aAdmitted: IDelphiSemanticCompilerDefineEvidence; out aReason: string): Boolean;
var
  lDescriptor: TDelphiSemanticCompilerDefineDescriptor;
begin
  aAdmitted := nil;
  aReason := 'compiler define evidence unavailable';
  if aEvidence = nil then
    Exit(False);
  try
    // Admitted descriptors are immutable and already normalized. Revalidate only
    // the request identity, rather than recopying/normalizing every source per model.
    if Fingerprint(aEvidence) <> 'unavailable' then
    begin
      aReason := 'compiler define evidence request identity mismatch';
      if not RequestMatches(aEvidence.Descriptor.Invocation, aRequest) then
        Exit(False);
      aAdmitted := aEvidence;
      aReason := '';
      Exit(True);
    end;
    lDescriptor := CopyDescriptor(aEvidence.Descriptor);
    if not ValidateDescriptor(lDescriptor, aRequest, aReason) then
      Exit(False);
    if not aEvidence.InputsAreCurrent(aReason) then
      Exit(False);
    aAdmitted := TAdmittedCompilerDefineEvidence.Create(lDescriptor, aEvidence,
      DescriptorFingerprint(lDescriptor));
    aReason := '';
    Result := True;
  except
    on E: Exception do
    begin
      aReason := 'compiler define evidence provider failed: ' + E.ClassName + ': ' + E.Message;
      Result := False;
    end;
  end;
end;

class function TDelphiSemanticCompilerDefines.SameDefines(const aLeft, aRight: TArray<string>): Boolean;
var
  lLeft, lRight: TArray<string>;
begin
  Result := NormalizeSymbols(aLeft, lLeft) and NormalizeSymbols(aRight, lRight);
  if Result then
    Result := String.Join(';', lLeft) = String.Join(';', lRight);
end;

class function TDelphiSemanticCompilerDefines.Fingerprint(
  const aEvidence: IDelphiSemanticCompilerDefineEvidence): string;
var
  lAdmitted: IAdmittedCompilerDefineEvidence;
begin
  if Supports(aEvidence, IAdmittedCompilerDefineEvidence, lAdmitted) then
    Exit(lAdmitted.EvidenceFingerprint);
  Result := 'unavailable';
end;

class function TDelphiSemanticCompilerDefines.AppliesToSource(
  const aEvidence: IDelphiSemanticCompilerDefineEvidence; const aSourceFileName: string): Boolean;
var
  lAdmitted: IAdmittedCompilerDefineEvidence;
  lDescriptor: TDelphiSemanticCompilerDefineDescriptor;
  lSource: TDelphiSemanticCompilerSourceWitness;
  lPath: string;
begin
  Result := False;
  if not Supports(aEvidence, IAdmittedCompilerDefineEvidence, lAdmitted) then
    Exit;
  lDescriptor := aEvidence.Descriptor;
  lPath := CanonicalPath(aSourceFileName);
  for lSource in lDescriptor.Sources do
    if lSource.SourceFileName = lPath then
      Exit(TFile.Exists(lPath) and
        SameText(THashSHA2.GetHashStringFromFile(lPath), lSource.ContentHash));
end;

class function TDelphiSemanticCompilerDefines.EffectiveDefines(
  const aEvidence: IDelphiSemanticCompilerDefineEvidence): TArray<string>;
var
  lDescriptor: TDelphiSemanticCompilerDefineDescriptor;
begin
  Result := nil;
  if Fingerprint(aEvidence) = 'unavailable' then
    Exit;
  lDescriptor := aEvidence.Descriptor;
  if not NormalizeSymbols(lDescriptor.Defines + lDescriptor.PredefinedTrue, Result) then
    raise EInvalidOpException.Create('COMPILER_DEFINE_EVIDENCE_INVALID: admitted symbols changed');
end;

class function TDelphiSemanticCompilerDefines.ForSession(
  const aEvidence: IDelphiSemanticCompilerDefineEvidence): IDelphiSemanticCompilerDefineEvidence;
begin
  Result := aEvidence;
  if aEvidence = nil then
    Exit;
  if Fingerprint(aEvidence) = 'unavailable' then
    raise EInvalidOpException.Create('COMPILER_DEFINE_EVIDENCE_INVALID: session requires admitted evidence');
  if not Supports(aEvidence, ISessionCompilerDefineEvidence) then
    Result := TSessionCompilerDefineEvidence.Create(aEvidence);
end;

class procedure TDelphiSemanticCompilerDefines.RequireCurrent(
  const aEvidence: IDelphiSemanticCompilerDefineEvidence);
begin
  if Supports(aEvidence, ISessionCompilerDefineEvidence) then
    Exit;
  RequireCurrentAtCheckpoint(aEvidence);
end;

class procedure TDelphiSemanticCompilerDefines.RequireCurrentAtCheckpoint(
  const aEvidence: IDelphiSemanticCompilerDefineEvidence);
var
  lReason: string;
begin
  if aEvidence = nil then
    Exit;
  if not aEvidence.InputsAreCurrent(lReason) then
    raise EInvalidOpException.Create('COMPILER_DEFINE_EVIDENCE_CHANGED: ' + lReason);
end;

end.
