unit DelphiSemantics.CompilerSourceInventory;

interface

uses
  DelphiSemantics.CompilerDefineEvidence, DelphiSemantics.ProjectContext;

type
  TDelphiSemanticCompilerSourceInventory = record
    Files: TArray<TDelphiSemanticCompilerSourceWitness>;
    Identity: string;
    LookupIdentity: string;
    ConsoleSafe: Boolean;
    Cause: string;
    class function Build(const aProject: TDelphiSemanticProjectInfo):
      TDelphiSemanticCompilerSourceInventory; static;
    class function ProjectLookupIdentity(const aProject: TDelphiSemanticProjectInfo): string; static;
  end;

implementation

uses
  System.Classes, System.Generics.Collections, System.Hash, System.IOUtils,
  System.StrUtils, System.SysUtils,
  SimpleParser.Lexer, SimpleParser.Lexer.Types,
  DelphiSemantics.Preprocess, DelphiSemantics.Resolve.UnitResolver;

type
  // This is a possible-source inventory, not a selected-branch parse. Both
  // planners and the producer use DS's ordered lookup and candidate names.
  TInventoryBuilder = class
  private
    fProject: TDelphiSemanticProjectInfo;
    fVisited: TStringList;
    fImports: TStringList;
    fFiles: TList<TDelphiSemanticCompilerSourceWitness>;
    fIdentity: TStringBuilder;
    fConsoleSafe: Boolean;
    fCause: string;
    procedure Unproved(const aCause: string);
    function Expand(const aFileName, aUnitFileName: string; const aDepth: Integer): string;
    procedure ScanUnit(const aFileName: string);
    procedure ScanImports(const aText, aFileName: string);
    procedure AddImport(const aName, aExplicitPath, aFileName: string);
  public
    constructor Create(const aProject: TDelphiSemanticProjectInfo);
    destructor Destroy; override;
    function Build: TDelphiSemanticCompilerSourceInventory;
  end;

class function TDelphiSemanticCompilerSourceInventory.ProjectLookupIdentity(
  const aProject: TDelphiSemanticProjectInfo): string;
var
  lText: TStringBuilder;
  lPath: string;
begin
  lText := TStringBuilder.Create;
  try
    lText.AppendLine('possible-compiler-source-lookup-v1')
      .AppendLine(LowerCase(aProject.MainSourceFileName));
    for lPath in aProject.SourceLookupPaths do
      lText.AppendLine('lookup').AppendLine(LowerCase(lPath));
    for lPath in aProject.UnitAliases do
      lText.AppendLine('alias').AppendLine(LowerCase(lPath));
    for lPath in aProject.UnitScopeNames do
      lText.AppendLine('scope').AppendLine(LowerCase(lPath));
    Result := THashSHA2.GetHashString(lText.ToString);
  finally
    lText.Free;
  end;
end;

constructor TInventoryBuilder.Create(const aProject: TDelphiSemanticProjectInfo);
begin
  inherited Create;
  fProject := aProject;
  fVisited := TStringList.Create;
  fVisited.Sorted := True;
  fVisited.CaseSensitive := False;
  fVisited.Duplicates := dupIgnore;
  fImports := TStringList.Create;
  fImports.Sorted := True;
  fImports.CaseSensitive := False;
  fImports.Duplicates := dupIgnore;
  fFiles := TList<TDelphiSemanticCompilerSourceWitness>.Create;
  fIdentity := TStringBuilder.Create;
  fConsoleSafe := True;
end;

destructor TInventoryBuilder.Destroy;
begin
  fIdentity.Free;
  fFiles.Free;
  fImports.Free;
  fVisited.Free;
  inherited;
end;

procedure TInventoryBuilder.Unproved(const aCause: string);
begin
  fConsoleSafe := False;
  if fCause = '' then
    fCause := aCause;
end;

function TInventoryBuilder.Expand(const aFileName, aUnitFileName: string;
  const aDepth: Integer): string;
var
  lSource, lToken, lArgument, lChild, lCandidate, lPath, lFileName: string;
  lWitness: TDelphiSemanticCompilerSourceWitness;
  lBytes: TBytes;
  lStream: TFileStream;
  lHash: THashSHA2;
  lText: TStringBuilder;
  i, j, lStart, lStop, lWord: Integer;
  lParen: Boolean;
begin
  Result := '';
  lFileName := TPath.GetFullPath(aFileName);
  if (aDepth > 64) or (fVisited.Count > 10000) then
  begin
    Unproved('compiler-source-inventory-limit: ' + lFileName);
    Exit;
  end;
  if fVisited.IndexOf(lFileName) >= 0 then
    Exit;
  fVisited.Add(lFileName);
  try
    lStream := TFileStream.Create(lFileName, fmOpenRead or fmShareDenyWrite);
    try
      SetLength(lBytes, lStream.Size);
      if Length(lBytes) > 0 then
        lStream.ReadBuffer(lBytes[0], Length(lBytes));
    finally
      lStream.Free;
    end;
    lHash := THashSHA2.Create;
    lHash.Update(lBytes);
    lWitness := Default(TDelphiSemanticCompilerSourceWitness);
    lWitness.SourceFileName := lFileName;
    lWitness.ContentHash := lHash.HashAsString;
    fFiles.Add(lWitness);
    // ReadAllText uses the same Delphi BOM/default decoding as project models.
    lSource := TFile.ReadAllText(lFileName);
    if THashSHA2.GetHashStringFromFile(lFileName) <> lWitness.ContentHash then
      raise EInvalidOpException.Create('source changed during inventory');
    fIdentity.AppendLine(LowerCase(lFileName)).AppendLine(lWitness.ContentHash);
  except
    on E: Exception do
    begin
      Unproved('compiler-source-inventory-unavailable: ' + lFileName + ': ' + E.Message);
      Exit;
    end;
  end;
  lText := TStringBuilder.Create;
  try
    i := 1;
    while i <= Length(lSource) do
    begin
      lStart := i;
      if lSource[i] = '''' then
      begin
        Inc(i);
        while i <= Length(lSource) do
        begin
          if lSource[i] = '''' then
          begin
            Inc(i);
            if (i > Length(lSource)) or (lSource[i] <> '''') then
              Break;
          end;
          Inc(i);
        end;
        lText.Append(Copy(lSource, lStart, i - lStart));
        Continue;
      end;
      if (lSource[i] = '/') and (i < Length(lSource)) and (lSource[i + 1] = '/') then
      begin
        while (i <= Length(lSource)) and not CharInSet(lSource[i], [#10, #13]) do
          Inc(i);
        lText.Append(' ');
        Continue;
      end;
      lParen := (lSource[i] = '(') and (i < Length(lSource)) and (lSource[i + 1] = '*');
      if (lSource[i] <> '{') and not lParen then
      begin
        lText.Append(lSource[i]);
        Inc(i);
        Continue;
      end;
      j := i + 1;
      if lParen then
        Inc(j);
      lStop := j;
      while lStop <= Length(lSource) do
      begin
        if (not lParen and (lSource[lStop] = '}')) or
          (lParen and (lSource[lStop] = '*') and (lStop < Length(lSource)) and (lSource[lStop + 1] = ')')) then
          Break;
        Inc(lStop);
      end;
      i := lStop + 1;
      if lParen then
        Inc(i);
      if lStop > Length(lSource) then
        Unproved('compiler-source-inventory-comment-unbounded: ' + lFileName);
      while (j < lStop) and (lSource[j] <= #32) do
        Inc(j);
      if (j < lStop) and (lSource[j] = '$') then
      begin
        Inc(j);
        while (j < lStop) and (lSource[j] <= #32) do
          Inc(j);
        lWord := j;
        while (j < lStop) and CharInSet(lSource[j], ['A'..'Z', 'a'..'z']) do
          Inc(j);
        lToken := Copy(lSource, lWord, j - lWord);
        lArgument := Trim(Copy(lSource, j, lStop - j));
        if SameText(lToken, 'APPTYPE') and not SameText(lFileName, fProject.MainSourceFileName) then
          Unproved('console-apptype-outside-main: ' + lFileName);
        if MatchText(lToken, ['I', 'INCLUDE']) and (lArgument <> '') and
          not MatchText(lArgument, ['+', '-']) then
        begin
          if (Length(lArgument) >= 2) and (lArgument[1] = '''') and
            (lArgument[Length(lArgument)] = '''') then
            lArgument := Copy(lArgument, 2, Length(lArgument) - 2);
          if lArgument.StartsWith('*.') then
            lArgument := TPath.GetFileNameWithoutExtension(aUnitFileName) + Copy(lArgument, 2, MaxInt);
          lArgument := TDelphiSemanticPreprocessor.CompilerIncludeFileName(lArgument);
          lChild := '';
          for lPath in [ExtractFilePath(aUnitFileName)] + fProject.IncludePaths do
          begin
            lCandidate := TPath.GetFullPath(TPath.Combine(lPath, lArgument));
            fIdentity.AppendLine('include-candidate').AppendLine(LowerCase(lCandidate))
              .AppendLine(BoolToStr(TFile.Exists(lCandidate), True));
            if TFile.Exists(lCandidate) then
            begin
              lChild := lCandidate;
              Break;
            end;
          end;
          if lChild = '' then
            Unproved('console-include-unresolved: ' + lFileName + ': ' + lArgument)
          else
            lText.Append(' ').Append(Expand(lChild, aUnitFileName, aDepth + 1)).Append(' ');
        end;
      end;
      lText.Append(' ');
    end;
    Result := lText.ToString;
  finally
    lText.Free;
  end;
end;

procedure TInventoryBuilder.AddImport(const aName, aExplicitPath, aFileName: string);
var
  lName: TUnitCandidateName;
  lPath, lCandidate: string;
begin
  if aExplicitPath <> '' then
  begin
    ScanUnit(TPath.GetFullPath(TPath.Combine(ExtractFilePath(aFileName), aExplicitPath)));
    Exit;
  end;
  if fImports.IndexOf(aName) >= 0 then
    Exit;
  fImports.Add(aName);
  // Source anywhere in the planning lookup can be rebuilt by -B. A DCU alone
  // is not source and is deliberately never opened by this inventory.
  for lName in TDelphiSemanticUnitResolver.CandidateNames(fProject, aName) do
    for lPath in [fProject.ProjectDirectory] + fProject.SourceLookupPaths do
    begin
      lCandidate := TPath.GetFullPath(TPath.Combine(lPath, lName.TargetName + '.pas'));
      if TFile.Exists(lCandidate) then
        ScanUnit(lCandidate);
    end;
end;

procedure TInventoryBuilder.ScanImports(const aText, aFileName: string);
var
  lLexer: TmwBasePasLex;
  lName, lExplicit: string;
  lInUses: Boolean;
begin
  lLexer := TmwBasePasLex.Create;
  try
    lLexer.UseDefines := False;
    lLexer.Origin := aText;
    lInUses := False;
    while lLexer.TokenID <> ptNull do
    begin
      if lLexer.TokenID in [ptUses, ptContains] then
        lInUses := True
      else if lLexer.TokenID = ptSemiColon then
        lInUses := False
      else if lInUses and (lLexer.TokenID = ptIdentifier) then
      begin
        lName := lLexer.Token;
        lLexer.NextNoJunk;
        while lLexer.TokenID = ptPoint do
        begin
          lLexer.NextNoJunk;
          if lLexer.TokenID <> ptIdentifier then
          begin
            Unproved('compiler-source-inventory-unit-name-unproved: ' + aFileName);
            Break;
          end;
          lName := lName + '.' + lLexer.Token;
          lLexer.NextNoJunk;
        end;
        lExplicit := '';
        if lLexer.TokenID = ptIn then
        begin
          lLexer.NextNoJunk;
          if lLexer.TokenID = ptStringConst then
          begin
            lExplicit := Copy(lLexer.Token, 2, Length(lLexer.Token) - 2);
            lLexer.NextNoJunk;
          end else
            Unproved('compiler-source-inventory-explicit-path-unproved: ' + aFileName);
        end;
        AddImport(lName, lExplicit, aFileName);
        Continue;
      end;
      lLexer.Next;
    end;
  finally
    lLexer.Free;
  end;
end;

procedure TInventoryBuilder.ScanUnit(const aFileName: string);
var
  lText: string;
begin
  if fVisited.IndexOf(TPath.GetFullPath(aFileName)) >= 0 then
    Exit;
  lText := Expand(aFileName, aFileName, 0);
  ScanImports(lText, aFileName);
end;

function TInventoryBuilder.Build: TDelphiSemanticCompilerSourceInventory;
var
  lFileName: string;
begin
  Result := Default(TDelphiSemanticCompilerSourceInventory);
  Result.LookupIdentity := TDelphiSemanticCompilerSourceInventory.ProjectLookupIdentity(fProject);
  fIdentity.AppendLine(Result.LookupIdentity);
  for lFileName in fProject.IncludePaths do
    fIdentity.AppendLine('include').AppendLine(LowerCase(lFileName));
  ScanUnit(fProject.MainSourceFileName);
  AddImport('System', '', fProject.MainSourceFileName);
  AddImport('SysInit', '', fProject.MainSourceFileName);
  for lFileName in fProject.SourceFileNames do
    if SameText(TPath.GetExtension(lFileName), '.pas') then
      ScanUnit(lFileName);
  Result.Files := fFiles.ToArray;
  Result.ConsoleSafe := fConsoleSafe;
  Result.Cause := fCause;
  fIdentity.AppendLine(BoolToStr(fConsoleSafe, True)).AppendLine(fCause);
  Result.Identity := THashSHA2.GetHashString(fIdentity.ToString);
end;

class function TDelphiSemanticCompilerSourceInventory.Build(const aProject: TDelphiSemanticProjectInfo):
  TDelphiSemanticCompilerSourceInventory;
var
  lBuilder: TInventoryBuilder;
begin
  lBuilder := TInventoryBuilder.Create(aProject);
  try
    Result := lBuilder.Build;
  finally
    lBuilder.Free;
  end;
end;

end.
