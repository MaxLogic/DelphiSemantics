unit Test.ResolutionBoundary;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TResolutionBoundaryTests = class
  public
    [Test]
    [Category('Fast')]
    procedure LegacyResolutionCallsMatchReviewedBoundary;
  end;

implementation

uses
  System.Classes, System.Generics.Collections, System.IOUtils,
  System.RegularExpressions, System.SysUtils,
  Test.Support;

const
  cTokens = '''(?:''''|[^''])*''|\{[^}]*\}|\(\*[\s\S]*?\*\)|//[^\r\n]*';
  cHeader = '(?im)^\s*(?:class\s+)?(?:function|procedure|constructor|destructor)\s+([\w.]+)';
  cCalls = '(?i)\b(ResolveVisibleName|ResolveScopedName|ResolveSimpleName|' +
    'ResolveQualifiedName|FindVisibleSelectorType|UsesSelectorUnit|IsUnitVisible|' +
    'OwnerHasMemberNamed|ResolveInterfaceMetadataName)\s*\(';

function BoundaryRows(const aSource, aUnitName: string): TArray<string>;
var
  lSource, lRoutine, lBody: string;
  lHeaders, lCalls: TMatchCollection;
  lRows: TList<string>;
  lEnd: Integer;
begin
  lRows := TList<string>.Create;
  try
    // Remove comments and strings before identifying executable call sites.
    lSource := TRegEx.Replace(aSource, cTokens, ' ');
    lHeaders := TRegEx.Matches(lSource, cHeader);
    for var i := 0 to lHeaders.Count - 1 do
    begin
      lRoutine := lHeaders[i].Groups[1].Value;
      lEnd := Length(lSource) + 1;
      if i < lHeaders.Count - 1 then
        lEnd := lHeaders[i + 1].Index;
      // Drop the complete routine declaration, including its own method name.
      lBody := Copy(lSource, lHeaders[i].Index + lHeaders[i].Length + 1,
        lEnd - lHeaders[i].Index - lHeaders[i].Length);
      lCalls := TRegEx.Matches(lBody, cCalls);
      for var lCall in lCalls do
        lRows.Add(LowerCase(aUnitName + '|' + lRoutine + '|' + lCall.Groups[1].Value));
    end;
    Result := lRows.ToArray;
  finally
    lRows.Free;
  end;
end;

procedure TResolutionBoundaryTests.LegacyResolutionCallsMatchReviewedBoundary;
var
  lExpected, lActual: TStringList;
  lLine, lKey, lReason, lPath: string;
  lSeparator: Integer;
begin
  lExpected := TStringList.Create;
  try
    lActual := TStringList.Create;
    try
      lPath := TPath.Combine(RepoRoot, 'tests\data\resolution-boundary.txt');
      for lLine in TFile.ReadAllLines(lPath) do
      begin
        if (Trim(lLine) = '') or lLine.StartsWith('#') then
          Continue;
        lSeparator := LastDelimiter('|', lLine);
        Assert.IsTrue(lSeparator > 0, 'Boundary entry needs a reason: ' + lLine);
        lKey := Copy(lLine, 1, lSeparator - 1);
        lReason := Copy(lLine, lSeparator + 1, MaxInt);
        Assert.IsTrue(Trim(lReason) <> '', 'Boundary entry needs a reason: ' + lLine);
        lExpected.Add(LowerCase(lKey));
      end;
      for lPath in TDirectory.GetFiles(TPath.Combine(RepoRoot, 'src'), '*.pas') do
        for lKey in BoundaryRows(TFile.ReadAllText(lPath), ExtractFileName(lPath)) do
          lActual.Add(lKey);
      lExpected.Sort;
      lActual.Sort;
      Assert.IsTrue(lActual.Count > 0, 'Boundary scanner must find existing legacy calls.');
      Assert.AreEqual(lExpected.Text, lActual.Text,
        'Legacy resolution boundary changed; migrate or justify each call explicitly.');
    finally
      lActual.Free;
    end;
  finally
    lExpected.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TResolutionBoundaryTests);

end.
