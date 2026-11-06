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
  DelphiSemantics.Model.Text, DelphiSemantics.Preprocess, DelphiSemantics.Resolve.UnitResolver;

type
  // This is a possible-source inventory, not a selected-branch parse. Both
  // planners and the producer use DS's ordered lookup and candidate names.
  TInventoryBuilder = class
  private
    fProject: TDelphiSemanticProjectInfo;
    fVisited: TStringList;
    fExpansions: TStringList;
    fImports: TStringList;
    fSourcePaths: TArray<string>;
    fPascalSourceNames: TStringList;
    fFiles: TList<TDelphiSemanticCompilerSourceWitness>;
    fIdentity: TStringBuilder;
    fConsoleSafe: Boolean;
    fCause: string;
    procedure Unproved(const aCause: string);
    function Expand(const aFileName, aUnitFileName: string; const aDepth: Integer): string;
    procedure IndexSourcePaths;
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
  fExpansions := TStringList.Create;
  fExpansions.Sorted := True;
  fExpansions.CaseSensitive := False;
  fExpansions.Duplicates := dupIgnore;
  fImports := TStringList.Create;
  fImports.Sorted := True;
  fImports.CaseSensitive := False;
  fImports.Duplicates := dupIgnore;
  fPascalSourceNames := TStringList.Create(True);
  fPascalSourceNames.Sorted := True;
  fPascalSourceNames.CaseSensitive := False;
  fPascalSourceNames.Duplicates := dupIgnore;
  fFiles := TList<TDelphiSemanticCompilerSourceWitness>.Create;
  fIdentity := TStringBuilder.Create;
  fConsoleSafe := True;
end;

destructor TInventoryBuilder.Destroy;
begin
  fIdentity.Free;
  fFiles.Free;
  fPascalSourceNames.Free;
  fImports.Free;
  fExpansions.Free;
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
  lSource, lToken, lArgument, lChild, lFileName, lExpansion: string;
  lOptions: TDelphiSemanticPreprocessOptions;
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
  if (aDepth > 64) or (fExpansions.Count > 10000) then
  begin
    Unproved('compiler-source-inventory-limit: ' + lFileName);
    Exit;
  end;
  // The same include can resolve nested names differently in each owning
  // unit, including wildcard names. Visit expansion contexts, not just files.
  lExpansion := TPath.GetFullPath(aUnitFileName) + #10 + lFileName;
  if fExpansions.IndexOf(lExpansion) >= 0 then
    Exit;
  fExpansions.Add(lExpansion);
  fIdentity.AppendLine('expansion').AppendLine(LowerCase(lExpansion));
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
    if fVisited.IndexOf(lFileName) < 0 then
    begin
      fVisited.Add(lFileName);
      fFiles.Add(lWitness);
    end;
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
        SkipPascalStringLiteral(lSource, i);
        lToken := Copy(lSource, lStart, i - lStart);
        // The import lexer predates multiline literals. Preserve ordinary
        // quoted IN paths, but give it a neutral literal for multiline text.
        if ContainsStr(lToken, #10) or ContainsStr(lToken, #13) then
          lText.Append('''''')
        else
          lText.Append(lToken);
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
          lOptions := Default(TDelphiSemanticPreprocessOptions);
          lOptions.SourceFileName := aUnitFileName;
          lOptions.SearchPaths := [fProject.ProjectDirectory] + fProject.IncludePaths;
          // Reuse native include order at capture and every checkpoint. The
          // selected path (or absence) changes if a higher-priority file appears.
          TDelphiSemanticPreprocessor.ResolveIncludeFileName(lArgument,
            ExtractFilePath(aUnitFileName), lOptions, lChild);
          fIdentity.AppendLine('include-selection').AppendLine(lArgument)
            .AppendLine(LowerCase(lChild));
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

procedure TInventoryBuilder.IndexSourcePaths;
var
  lFileName, lPath, lName: string;
  lPaths: TStringList;
  lIndex: Integer;
begin
  // Rebuild this index for every inventory, including currentness checkpoints.
  // This avoids a filesystem query for every namespace/path combination while
  // retaining newly appearing sources and the original ordered lookup.
  fSourcePaths := [fProject.ProjectDirectory] + fProject.SourceLookupPaths;
  for lPath in fSourcePaths do
    try
      if TDirectory.Exists(lPath) then
        for lFileName in TDirectory.GetFiles(lPath, '*.pas', TSearchOption.soTopDirectoryOnly) do
        begin
          lName := TPath.GetFileName(lFileName);
          if fPascalSourceNames.Find(lName, lIndex) then
            lPaths := TStringList(fPascalSourceNames.Objects[lIndex])
          else
          begin
            lPaths := TStringList.Create;
            fPascalSourceNames.AddObject(lName, lPaths);
          end;
          lPaths.Add(lPath);
        end;
    except
      on E: Exception do
        Unproved('compiler-source-directory-unavailable: ' + lPath + ': ' + E.Message);
    end;
end;

procedure TInventoryBuilder.AddImport(const aName, aExplicitPath, aFileName: string);
var
  lName: TUnitCandidateName;
  lNames: TArray<TUnitCandidateName>;
  lUnaliased: TDelphiSemanticProjectInfo;
  lPath, lCandidate: string;
  lIndex: Integer;
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
  lNames := TDelphiSemanticUnitResolver.CandidateNames(fProject, aName);
  if Length(lNames) = 0 then
    Unproved('compiler-source-inventory-alias-conflict: ' + aName);
  // Planning and native aliases can differ. Scan the unaliased planning name
  // as well; conflicting aliases cannot establish a common CONSOLE state.
  lUnaliased := fProject;
  lUnaliased.UnitAliases := nil;
  lNames := lNames + TDelphiSemanticUnitResolver.CandidateNames(lUnaliased, aName);
  for lName in lNames do
  begin
    if not fPascalSourceNames.Find(lName.TargetName + '.pas', lIndex) then
      Continue;
    for lPath in TStringList(fPascalSourceNames.Objects[lIndex]) do
    begin
      lCandidate := TPath.GetFullPath(TPath.Combine(lPath, lName.TargetName + '.pas'));
      ScanUnit(lCandidate);
    end;
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
  if fExpansions.IndexOf(TPath.GetFullPath(aFileName) + #10 + TPath.GetFullPath(aFileName)) >= 0 then
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
  fIdentity.AppendLine('project-directory').AppendLine(LowerCase(fProject.ProjectDirectory));
  try
    IndexSourcePaths;
    ScanUnit(fProject.MainSourceFileName);
    AddImport('System', '', fProject.MainSourceFileName);
    AddImport('SysInit', '', fProject.MainSourceFileName);
    for lFileName in fProject.SourceFileNames do
      if SameText(TPath.GetExtension(lFileName), '.pas') then
        ScanUnit(lFileName);
  except
    on E: Exception do
      // Invalid paths can arrive between admission and a checkpoint. Retain
      // an unproved inventory identity so currentness refuses normally.
      Unproved('compiler-source-inventory-unavailable: ' + E.Message);
  end;
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
