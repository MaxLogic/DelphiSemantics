unit DelphiSemantics.Resolve.UnitResolver;

interface

uses
  DelphiSemantics.Model, DelphiSemantics.ProjectContext;

type
  TDelphiSemanticUnitResolutionCandidate = record
    RequestedName: string;
    CandidateName: string;
    CanonicalUnitName: string;
    FileName: string;
    SourceKind: string;
    MatchKind: string;
    UnitScopeName: string;
    SearchPathIndex: Integer;
  end;

  TDelphiSemanticUnitResolutionResult = record
    Found: Boolean;
    Ambiguous: Boolean;
    Status: string;
    ReasonCode: string;
    Reason: string;
    RequestedName: string;
    CanonicalUnitName: string;
    FileName: string;
    SourceKind: string;
    MatchKind: string;
    UnitScopeName: string;
    SearchPathIndex: Integer;
    Candidates: TArray<TDelphiSemanticUnitResolutionCandidate>;
  end;

  TUnitCandidateName = record
    TargetName: string;
    MatchKind: string;
    UnitScopeName: string;
  end;

  TDelphiSemanticUnitResolver = record
  public
    class function CandidateNames(const aProject: TDelphiSemanticProjectInfo;
      const aUnitName: string): TArray<TUnitCandidateName>; static;
    class function TryReadDeclaredUnitName(const aFileName: string;
      out aUnitName: string): Boolean; static;
    class function Resolve(const aProject: TDelphiSemanticProjectInfo;
      const aUnitName: string): TDelphiSemanticUnitResolutionResult; overload; static;
    class function Resolve(const aProject: TDelphiSemanticProjectInfo; const aUnitName: string;
      const aUnitModels: TArray<TDelphiSemanticUnitModel>): TDelphiSemanticUnitResolutionResult;
      overload; static;
  end;

implementation

uses
  System.Generics.Collections, System.IOUtils, System.RegularExpressions, System.SysUtils,
  MaxLogic.StrUtils;

type
  TResolvedAlias = record
    TargetName: string;
    IsAlias: Boolean;
  end;

  TUnitCandidateRank = record
    Candidate: TDelphiSemanticUnitResolutionCandidate;
    Rank: Integer;
  end;

function NormalizedUnitName(const aUnitName: string): string;
begin
  Result := Trim(aUnitName);
end;

function CandidateKey(const aCandidate: TDelphiSemanticUnitResolutionCandidate): string;
begin
  Result := aCandidate.CanonicalUnitName + '|' + aCandidate.FileName + '|' +
    aCandidate.MatchKind + '|' + aCandidate.SourceKind;
end;

function CandidateFileNames(const aUnitName: string): TArray<string>;
begin
  Result := [aUnitName + '.pas', aUnitName + '.dcu'];
end;

class function TDelphiSemanticUnitResolver.TryReadDeclaredUnitName(const aFileName: string; out aUnitName: string): Boolean;
var
  lMatch: TMatch;
  lText: string;
begin
  aUnitName := '';
  if not TFile.Exists(aFileName) then
    Exit(False);

  lText := TFile.ReadAllText(aFileName);
  if (lText <> '') and (lText[1] = #$FEFF) then
    Delete(lText, 1, 1);
  lMatch := TRegEx.Match(lText, '^\s*unit\s+([A-Za-z_][A-Za-z0-9_\.]*)\s*;',
    [roIgnoreCase, roMultiLine]);
  if not lMatch.Success then
    Exit(False);

  aUnitName := lMatch.Groups[1].Value;
  Result := True;
end;

function UnitPathCandidates(const aProject: TDelphiSemanticProjectInfo): TArray<string>;
var
  lItem: string;
  lItems: TList<string>;
  lSeen: TDictionary<string, Byte>;
begin
  lItems := nil;
  lSeen := nil;
  try
    lItems := TList<string>.Create;
    lSeen := TDictionary<string, Byte>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
    for lItem in aProject.SourceLookupPaths do
      if (lItem <> '') and not lSeen.ContainsKey(lItem) then
      begin
        lSeen.Add(lItem, 0);
        lItems.Add(lItem);
      end;
    Result := lItems.ToArray;
  finally
    lSeen.Free;
    lItems.Free;
  end;
end;

function ResolveAlias(const aAliases: TArray<string>; const aUnitName: string): TResolvedAlias;
var
  lAlias: string;
  lEquals: Integer;
  lLeft: string;
  lRight: string;
begin
  Result := Default(TResolvedAlias);
  Result.TargetName := aUnitName;
  for lAlias in aAliases do
  begin
    lEquals := Pos('=', lAlias);
    if lEquals <= 0 then
      Continue;

    lLeft := Trim(Copy(lAlias, 1, lEquals - 1));
    lRight := Trim(Copy(lAlias, lEquals + 1, MaxInt));
    if SameText(lLeft, aUnitName) and (lRight <> '') then
    begin
      Result.TargetName := lRight;
      Result.IsAlias := True;
      Exit;
    end;
  end;
end;

procedure AddCandidateName(const aNames: TList<TUnitCandidateName>; const aName, aMatchKind,
  aScope: string);
var
  lItem: TUnitCandidateName;
begin
  lItem := Default(TUnitCandidateName);
  lItem.TargetName := aName;
  lItem.MatchKind := aMatchKind;
  lItem.UnitScopeName := aScope;
  aNames.Add(lItem);
end;

class function TDelphiSemanticUnitResolver.CandidateNames(const aProject: TDelphiSemanticProjectInfo; const aUnitName: string):
  TArray<TUnitCandidateName>;
var
  lAlias: TResolvedAlias;
  lItems: TList<TUnitCandidateName>;
  lScope: string;
begin
  lItems := TList<TUnitCandidateName>.Create;
  try
    lAlias := ResolveAlias(aProject.UnitAliases, aUnitName);
    if lAlias.IsAlias then
      AddCandidateName(lItems, lAlias.TargetName, 'alias', '')
    else
      AddCandidateName(lItems, lAlias.TargetName, 'exact', '');

    for lScope in aProject.UnitScopeNames do
        if Trim(lScope) <> '' then
          AddCandidateName(lItems, Trim(lScope) + '.' + lAlias.TargetName, 'scope',
            Trim(lScope));

    Result := lItems.ToArray;
  finally
    lItems.Free;
  end;
end;

procedure AddRankedCandidate(const aItems: TList<TUnitCandidateRank>;
  const aSeen: TDictionary<string, Byte>; const aCandidate: TDelphiSemanticUnitResolutionCandidate;
  const aRank: Integer);
var
  lItem: TUnitCandidateRank;
  lKey: string;
begin
  lKey := CandidateKey(aCandidate);
  if aSeen.ContainsKey(lKey) then
    Exit;

  aSeen.Add(lKey, 0);
  lItem.Candidate := aCandidate;
  lItem.Rank := aRank;
  aItems.Add(lItem);
end;

procedure AddModelCandidates(const aItems: TList<TUnitCandidateRank>;
  const aSeen: TDictionary<string, Byte>; const aUnitModels: TArray<TDelphiSemanticUnitModel>;
  const aRequestedName: string; const aNameInfo: TUnitCandidateName; const aRank: Integer);
var
  lCandidate: TDelphiSemanticUnitResolutionCandidate;
  lModel: TDelphiSemanticUnitModel;
begin
  for lModel in aUnitModels do
    if SameText(lModel.UnitName, aNameInfo.TargetName) then
    begin
      lCandidate := Default(TDelphiSemanticUnitResolutionCandidate);
      lCandidate.RequestedName := aRequestedName;
      lCandidate.CandidateName := aNameInfo.TargetName;
      lCandidate.CanonicalUnitName := lModel.UnitName;
      lCandidate.FileName := lModel.FileName;
      lCandidate.SourceKind := 'project';
      lCandidate.MatchKind := aNameInfo.MatchKind;
      lCandidate.UnitScopeName := aNameInfo.UnitScopeName;
      lCandidate.SearchPathIndex := -1;
      AddRankedCandidate(aItems, aSeen, lCandidate, aRank);
    end;
end;

procedure AddFileCandidates(const aItems: TList<TUnitCandidateRank>;
  const aSeen: TDictionary<string, Byte>; const aProject: TDelphiSemanticProjectInfo;
  const aRequestedName: string; const aNameInfo: TUnitCandidateName; const aBaseRank: Integer);
var
  i: Integer;
  lCandidate: TDelphiSemanticUnitResolutionCandidate;
  lDeclaredName: string;
  lExtension: string;
  lFileCandidate: string;
  lFileIndex: Integer;
  lFileName: string;
  lFileNames: TArray<string>;
  lPaths: TArray<string>;
begin
  lPaths := UnitPathCandidates(aProject);
  for i := 0 to High(lPaths) do
  begin
    lFileNames := CandidateFileNames(aNameInfo.TargetName);
    for lFileIndex := 0 to High(lFileNames) do
    begin
      lFileCandidate := lFileNames[lFileIndex];
      lFileName := TPath.Combine(lPaths[i], lFileCandidate);
      if not TFile.Exists(lFileName) then
        Continue;

      lExtension := TPath.GetExtension(lFileName);
      if SameText(lExtension, '.pas') then
      begin
        if not TDelphiSemanticUnitResolver.TryReadDeclaredUnitName(lFileName, lDeclaredName) then
          lDeclaredName := aNameInfo.TargetName;
        if not SameText(lDeclaredName, aNameInfo.TargetName) then
          Continue;
      end else begin
        lDeclaredName := aNameInfo.TargetName;
      end;

      lCandidate := Default(TDelphiSemanticUnitResolutionCandidate);
      lCandidate.RequestedName := aRequestedName;
      lCandidate.CandidateName := aNameInfo.TargetName;
      lCandidate.CanonicalUnitName := lDeclaredName;
      lCandidate.FileName := TPath.GetFullPath(lFileName);
      if SameText(lExtension, '.pas') then
        lCandidate.SourceKind := 'source'
      else
        lCandidate.SourceKind := 'precompiled';
      lCandidate.MatchKind := aNameInfo.MatchKind;
      lCandidate.UnitScopeName := aNameInfo.UnitScopeName;
      lCandidate.SearchPathIndex := i;
      AddRankedCandidate(aItems, aSeen, lCandidate, aBaseRank + (i * 10) + lFileIndex);
    end;
  end;
end;

function UnresolvedResult(const aUnitName: string): TDelphiSemanticUnitResolutionResult;
begin
  Result := Default(TDelphiSemanticUnitResolutionResult);
  Result.Found := False;
  Result.Status := 'unresolved';
  Result.ReasonCode := 'UNIT_NOT_FOUND';
  Result.Reason := 'No compiler-derived unit candidate was found.';
  Result.RequestedName := aUnitName;
end;

function AmbiguousResult(const aUnitName: string;
  const aCandidates: TArray<TDelphiSemanticUnitResolutionCandidate>):
  TDelphiSemanticUnitResolutionResult;
begin
  Result := Default(TDelphiSemanticUnitResolutionResult);
  Result.Found := False;
  Result.Ambiguous := True;
  Result.Status := 'ambiguous';
  Result.ReasonCode := 'UNIT_AMBIGUOUS';
  Result.Reason := 'Multiple compiler-equivalent unit candidates were found.';
  Result.RequestedName := aUnitName;
  Result.Candidates := aCandidates;
end;

function ResolvedResult(const aCandidate: TDelphiSemanticUnitResolutionCandidate):
  TDelphiSemanticUnitResolutionResult;
begin
  Result := Default(TDelphiSemanticUnitResolutionResult);
  Result.Found := True;
  Result.Status := 'resolved';
  Result.RequestedName := aCandidate.RequestedName;
  Result.CanonicalUnitName := aCandidate.CanonicalUnitName;
  Result.FileName := aCandidate.FileName;
  Result.SourceKind := aCandidate.SourceKind;
  Result.MatchKind := aCandidate.MatchKind;
  Result.UnitScopeName := aCandidate.UnitScopeName;
  Result.SearchPathIndex := aCandidate.SearchPathIndex;
  Result.Candidates := [aCandidate];
end;

function PickBestCandidate(const aUnitName: string; const aItems: TList<TUnitCandidateRank>):
  TDelphiSemanticUnitResolutionResult;
var
  i: Integer;
  lBestRank: Integer;
  lCandidate: TDelphiSemanticUnitResolutionCandidate;
  lCandidates: TList<TDelphiSemanticUnitResolutionCandidate>;
begin
  if aItems.Count = 0 then
    Exit(UnresolvedResult(aUnitName));

  lBestRank := aItems[0].Rank;
  for i := 1 to Pred(aItems.Count) do
    if aItems[i].Rank < lBestRank then
      lBestRank := aItems[i].Rank;

  lCandidates := TList<TDelphiSemanticUnitResolutionCandidate>.Create;
  try
    for i := 0 to Pred(aItems.Count) do
      if aItems[i].Rank = lBestRank then
        lCandidates.Add(aItems[i].Candidate);

    if lCandidates.Count > 1 then
      Exit(AmbiguousResult(aUnitName, lCandidates.ToArray));

    lCandidate := lCandidates[0];
    Result := ResolvedResult(lCandidate);
  finally
    lCandidates.Free;
  end;
end;

class function TDelphiSemanticUnitResolver.Resolve(const aProject: TDelphiSemanticProjectInfo;
  const aUnitName: string): TDelphiSemanticUnitResolutionResult;
begin
  Result := Resolve(aProject, aUnitName, nil);
end;

class function TDelphiSemanticUnitResolver.Resolve(const aProject: TDelphiSemanticProjectInfo;
  const aUnitName: string; const aUnitModels: TArray<TDelphiSemanticUnitModel>):
  TDelphiSemanticUnitResolutionResult;
var
  lItems: TList<TUnitCandidateRank>;
  lNameInfo: TUnitCandidateName;
  lNames: TArray<TUnitCandidateName>;
  lRank, lPreviousCount: Integer;
  lSeen: TDictionary<string, Byte>;
  lUnitName: string;
begin
  lUnitName := NormalizedUnitName(aUnitName);
  if lUnitName = '' then
    Exit(UnresolvedResult(aUnitName));

  lItems := nil;
  lSeen := nil;
  try
    lItems := TList<TUnitCandidateRank>.Create;
    lSeen := TDictionary<string, Byte>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
    lRank := 0;
    lNames := CandidateNames(aProject, lUnitName);
    for lNameInfo in lNames do
    begin
      lPreviousCount := lItems.Count;
      AddModelCandidates(lItems, lSeen, aUnitModels, lUnitName, lNameInfo, lRank);
      // Files start at rank 1000; later names cannot beat this project rank.
      // Keep all same-name models above so compiler-equivalent ambiguity survives.
      if (lRank < 1000) and (lItems.Count > lPreviousCount) then
        Exit(PickBestCandidate(lUnitName, lItems));
      AddFileCandidates(lItems, lSeen, aProject, lUnitName, lNameInfo, lRank + 1000);
      Inc(lRank, 100);
    end;
    Result := PickBestCandidate(lUnitName, lItems);
  finally
    lSeen.Free;
    lItems.Free;
  end;
end;

end.
