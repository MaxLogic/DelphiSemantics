unit Test.SourceLookup;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture] [Category('Fast')]
  TSourceLookupTests = class
  public
    [Test]
    procedure KeysAreBuiltOnceInCandidateAndExtensionOrder;
    [Test]
    procedure PathsAndSdkClassificationAreCaptureOwned;
    [TestCase('Locale', 'locale')]
    [TestCase('NLS version', 'nls')]
    [TestCase('Unavailable', 'unavailable')]
    procedure ChangedContextInvalidates(const aKind: string);
    [Test]
    procedure ClassificationIsLazyAndExceptionsAreRetried;
    [Test]
    procedure RelativePathsBypassClassificationReuse;
    [Test]
    procedure RelativeEntriesReuseProjectAnchoredExpansion;
    [TestCase('Root relative', 'root')]
    [TestCase('Drive relative', 'drive')]
    [TestCase('Relative project', 'project')]
    procedure CwdDependentExpansionIsRepeated(const aKind: string);
    [Test]
    procedure UnresolvedExpansionIsRetried;
  end;

implementation

uses
  System.IOUtils, System.SysUtils,
  Winapi.Windows,
  AutoFree,
  DelphiSemantics.ProjectContext, DelphiSemantics.Resolve.UnitResolver,
  DelphiSemantics.SourceLookup;

type
  TLookupProbe = class(TDelphiSemanticSourceLookup)
  public
    LocaleGeneration, NlsGeneration: Cardinal;
    Unavailable: Boolean;
  protected
    function ReadComparisonContext(out aLocale: LCID;
      out aVersion: TNlsVersionInfoEx): Boolean; override;
  end;

function TLookupProbe.ReadComparisonContext(out aLocale: LCID;
  out aVersion: TNlsVersionInfoEx): Boolean;
begin
  Result := inherited ReadComparisonContext(aLocale, aVersion) and not Unavailable;
  Inc(aLocale, LocaleGeneration);
  Inc(aVersion.dwNLSVersion, NlsGeneration);
end;

function Project: TDelphiSemanticProjectInfo;
begin
  Result := Default(TDelphiSemanticProjectInfo);
  Result.ProjectDirectory := 'C:\project';
  Result.SearchPaths := ['C:\project\first', 'C:\project\second'];
end;

procedure TSourceLookupTests.KeysAreBuiltOnceInCandidateAndExtensionOrder;
var
  g: TGarbos;
  lProject: TDelphiSemanticProjectInfo;
  lLookup: TLookupProbe;
  lNames: TArray<TUnitCandidateName>;
  lFiles: TArray<TDelphiSemanticLookupCandidate>;
  i: Integer;
begin
  g := Default(TGarbos);
  lProject := Project;
  lProject.UnitScopeNames := ['Winapi', 'System'];
  lNames := TDelphiSemanticUnitResolver.CandidateNames(lProject, 'Alpha');
  GC(lLookup, TLookupProbe.Create(lProject, nil, False, ''), g);
  lFiles := lLookup.Candidates(lNames);
  Assert.AreEqual(Length(lNames) * 2, Length(lFiles));
  for i := 0 to High(lNames) do
  begin
    Assert.AreEqual(lNames[i].TargetName + '.pas', lFiles[i * 2].FileName);
    Assert.AreEqual(lNames[i].TargetName + '.dcu', lFiles[i * 2 + 1].FileName);
    Assert.AreEqual(LowerCase(lFiles[i * 2].FileName), lFiles[i * 2].Key);
    Assert.AreEqual(LowerCase(lFiles[i * 2 + 1].FileName), lFiles[i * 2 + 1].Key);
  end;
  Assert.AreEqual<NativeInt>(Length(lFiles), lLookup.CandidateKeys);
end;

procedure TSourceLookupTests.PathsAndSdkClassificationAreCaptureOwned;
var
  g: TGarbos;
  lLookup, lOther: TLookupProbe;
  lPaths: TArray<string>;
begin
  g := Default(TGarbos);
  GC(lLookup, TLookupProbe.Create(Project, ['C:\sdk\source\rtl'], True, 'C:\sdk'), g);
  for var i := 1 to 2 do
  begin
    lLookup.BeginCall;
    lPaths := lLookup.Paths;
    Assert.AreEqual('C:\project\first', lPaths[0]);
    Assert.AreEqual('C:\project\second', lPaths[1]);
    Assert.AreEqual('C:\sdk\source\rtl', lPaths[2]);
    Assert.IsTrue(lLookup.IsSdkPath(2));
  end;
  Assert.AreEqual(1, lLookup.PathExpansions);
  Assert.AreEqual(1, lLookup.SdkClassifications);
  // Returned arrays cannot mutate the retained ordered list.
  lPaths[0] := 'changed';
  Assert.AreEqual('C:\project\first', lLookup.Paths[0]);
  GC(lOther, TLookupProbe.Create(Project, ['C:\sdk\source\rtl'], True, 'C:\other'), g);
  lOther.BeginCall;
  Assert.AreEqual(Length(lPaths), Length(lOther.Paths));
  Assert.IsFalse(lOther.IsSdkPath(2));
end;

procedure TSourceLookupTests.ChangedContextInvalidates(const aKind: string);
var
  g: TGarbos;
  lLookup: TLookupProbe;
begin
  g := Default(TGarbos);
  GC(lLookup, TLookupProbe.Create(Project, ['C:\sdk\lib\win64'], False, 'C:\sdk'), g);
  lLookup.BeginCall;
  Assert.AreEqual<NativeInt>(1, Length(lLookup.Paths));
  Assert.IsTrue(lLookup.IsSdkPath(0));
  if aKind = 'locale' then
    Inc(lLookup.LocaleGeneration)
  else if aKind = 'nls' then
    Inc(lLookup.NlsGeneration)
  else
    lLookup.Unavailable := True;
  lLookup.BeginCall;
  Assert.AreEqual<NativeInt>(1, Length(lLookup.Paths));
  Assert.IsTrue(lLookup.IsSdkPath(0));
  Assert.AreEqual(2, lLookup.PathExpansions);
  Assert.AreEqual(2, lLookup.SdkClassifications);
  Assert.IsTrue(lLookup.IsSdkPath(0));
  Assert.AreEqual(2 + Ord(aKind = 'unavailable'), lLookup.SdkClassifications);
end;

procedure TSourceLookupTests.ClassificationIsLazyAndExceptionsAreRetried;
var
  g: TGarbos;
  lLookup: TLookupProbe;
  lRaised: Boolean;
begin
  g := Default(TGarbos);
  GC(lLookup, TLookupProbe.Create(Project,
    ['<alternate-alias-unverified>', 'bad' + #0 + 'path'], False, 'C:\sdk'), g);
  lLookup.BeginCall;
  Assert.AreEqual('<alternate-alias-unverified>', lLookup.Paths[0]);
  Assert.AreEqual(0, lLookup.SdkClassifications, 'Sentinels must be handled before path classification.');
  for var i := 1 to 2 do
  begin
    lRaised := False;
    try
      lLookup.IsSdkPath(1);
    except
      on E: EArgumentException do
        lRaised := True;
    end;
    Assert.IsTrue(lRaised, 'Invalid path classification must raise again.');
  end;
  Assert.AreEqual(2, lLookup.SdkClassifications, 'A failed classification must be retried.');
end;

procedure TSourceLookupTests.RelativePathsBypassClassificationReuse;
var
  g: TGarbos;
  lLookup: TLookupProbe;
begin
  g := Default(TGarbos);
  GC(lLookup, TLookupProbe.Create(Project, ['relative', '\root-relative', 'C:drive-relative'],
    False, 'C:\sdk'), g);
  lLookup.BeginCall;
  Assert.AreEqual<NativeInt>(3, Length(lLookup.Paths));
  for var i := 0 to 2 do
  begin
    Assert.AreEqual(lLookup.IsSdkFile(TPath.Combine(lLookup.Paths[i], '_')), lLookup.IsSdkPath(i));
    Assert.AreEqual(lLookup.IsSdkFile(TPath.Combine(lLookup.Paths[i], '_')), lLookup.IsSdkPath(i));
  end;
  Assert.AreEqual(6, lLookup.SdkClassifications);
end;

procedure TSourceLookupTests.RelativeEntriesReuseProjectAnchoredExpansion;
var
  g: TGarbos;
  lProject: TDelphiSemanticProjectInfo;
  lLookup: TLookupProbe;
  lPaths: TArray<string>;
begin
  g := Default(TGarbos);
  lProject := Project;
  lProject.ProjectDirectory := 'C:\project\app';
  lProject.ReferenceDirectories := ['..\ref'];
  lProject.SearchPaths := ['..\lib', '..\sdk\source'];
  GC(lLookup, TLookupProbe.Create(lProject, nil, True, 'C:\project\sdk'), g);
  for var i := 1 to 2 do
  begin
    lLookup.BeginCall;
    lPaths := lLookup.Paths;
    Assert.AreEqual<NativeInt>(3, Length(lPaths));
    Assert.AreEqual('C:\project\ref', lPaths[0]);
    Assert.AreEqual('C:\project\lib', lPaths[1]);
    Assert.AreEqual('C:\project\sdk\source', lPaths[2]);
    Assert.IsTrue(lLookup.IsSdkPath(2));
  end;
  Assert.AreEqual(1, lLookup.PathExpansions,
    'Project-anchored relative entries must retain the ordered expansion.');
  Assert.AreEqual(1, lLookup.SdkClassifications);
end;

procedure TSourceLookupTests.UnresolvedExpansionIsRetried;
var
  g: TGarbos;
  lProject: TDelphiSemanticProjectInfo;
  lLookup: TLookupProbe;
  lPaths: TArray<string>;
  lRaised: Boolean;
begin
  g := Default(TGarbos);
  lProject := Project;
  lProject.SearchPaths := ['$(UnknownRoot)\lib'];
  GC(lLookup, TLookupProbe.Create(lProject, nil, True, 'C:\sdk'), g);
  for var i := 1 to 2 do
  begin
    lLookup.BeginCall;
    lRaised := False;
    try
      lPaths := lLookup.Paths;
      Assert.AreEqual<NativeInt>(0, Length(lPaths));
    except
      on E: EConvertError do
      begin
        lRaised := True;
        Assert.IsTrue(Pos('unresolved macro', E.Message) > 0);
      end;
    end;
    Assert.IsTrue(lRaised, 'Unresolved entries must retry their original error.');
  end;
  Assert.AreEqual(0, lLookup.PathExpansions);
end;

procedure TSourceLookupTests.CwdDependentExpansionIsRepeated(const aKind: string);
var
  g: TGarbos;
  lProject: TDelphiSemanticProjectInfo;
  lLookup: TLookupProbe;
begin
  g := Default(TGarbos);
  lProject := Project;
  if aKind = 'root' then
    lProject.SearchPaths := ['\root-relative']
  else if aKind = 'drive' then
    lProject.SearchPaths := ['C:drive-relative']
  else begin
    lProject.ProjectDirectory := 'relative-project';
    lProject.SearchPaths := ['relative'];
  end;
  GC(lLookup, TLookupProbe.Create(lProject, nil, True, 'C:\sdk'), g);
  for var i := 1 to 2 do
  begin
    lLookup.BeginCall;
    Assert.AreEqual<NativeInt>(1, Length(lLookup.Paths));
  end;
  Assert.AreEqual(2, lLookup.PathExpansions, 'CWD-dependent expansions must not be retained across operations.');
end;

initialization
  TDUnitX.RegisterTestFixture(TSourceLookupTests);

end.
