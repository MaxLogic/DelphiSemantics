unit DelphiSemantics.DeadCode;

interface

uses
  DelphiSemantics.Query, DelphiSemantics.Symbols;

type
  TDelphiSemanticDeadCodeCandidate = record
    SymbolId: TDelphiSemanticSymbolId;
    Name: string;
    Kind: string;
    OwnerName: string;
    UnitName: string;
    FileName: string;
    Line: Integer;
    Column: Integer;
    Status: string;
    Reason: string;
    SafetyProfile: string;
    ReferenceCount: Integer;
    Blockers: TArray<string>;
  end;

  TDelphiSemanticDeadCodeReport = record
    Profile: string;
    Candidates: TArray<TDelphiSemanticDeadCodeCandidate>;
  end;

  TDelphiSemanticDeadCodeReporter = record
  public
    class function Report(const aContext: TDelphiSemanticSymbolQueryContext;
      const aProfile: string): TDelphiSemanticDeadCodeReport; static;
  end;

implementation

uses
  System.Classes, System.Generics.Collections, System.RegularExpressions, System.StrUtils,
  System.SysUtils,
  DelphiSemantics.Index;

function SameSymbolId(const aLeft, aRight: TDelphiSemanticSymbolId): Boolean;
begin
  Result := aLeft.Value = aRight.Value;
end;

function IsProjectSymbol(const aSymbol: TDelphiSemanticIndexedSymbol): Boolean;
begin
  Result := SameText(aSymbol.SourceKind, 'project-source');
end;

function IsDataSymbol(const aSymbol: TDelphiSemanticIndexedSymbol): Boolean;
begin
  Result := SameText(aSymbol.Kind, 'var') or SameText(aSymbol.Kind, 'const') or
    SameText(aSymbol.Kind, 'typed-const') or SameText(aSymbol.Kind, 'resourcestring');
end;

function IsCandidateKind(const aSymbol: TDelphiSemanticIndexedSymbol): Boolean;
begin
  Result := not SameText(aSymbol.Kind, 'unit') and not SameText(aSymbol.Kind, 'local') and
    not (SameText(aSymbol.Kind, 'routine') and (aSymbol.OwnerName <> '')) and
    not (IsDataSymbol(aSymbol) and (aSymbol.OwnerName <> ''));
end;

function HasSymbolCandidate(const aReference: TDelphiSemanticIndexedReference;
  const aSymbol: TDelphiSemanticIndexedSymbol): Boolean;
var
  lCandidateId: TDelphiSemanticSymbolId;
begin
  for lCandidateId in aReference.CandidateSymbolIds do
    if SameSymbolId(lCandidateId, aSymbol.Id) then
      Exit(True);

  Result := False;
end;

function CountResolvedReferences(const aIndex: TDelphiSemanticProjectSymbolIndex;
  const aSymbol: TDelphiSemanticIndexedSymbol): Integer;
var
  lReference: TDelphiSemanticIndexedReference;
begin
  Result := 0;
  for lReference in aIndex.References do
    if SameText(lReference.Status, 'resolved') and SameSymbolId(lReference.SymbolId,
      aSymbol.Id) then
      Inc(Result);
end;

function CountSameUnitNameReferences(const aIndex: TDelphiSemanticProjectSymbolIndex;
  const aSymbol: TDelphiSemanticIndexedSymbol): Integer;
var
  lReference: TDelphiSemanticIndexedReference;
begin
  Result := 0;
  if aSymbol.OwnerName <> '' then
    Exit;
  for lReference in aIndex.References do
    if SameText(lReference.Name, aSymbol.Name) and SameText(lReference.UnitName,
      aSymbol.UnitName) and SameText(lReference.SourceKind, 'project-source') then
      Inc(Result);
end;

function HasAmbiguousReference(const aIndex: TDelphiSemanticProjectSymbolIndex;
  const aSymbol: TDelphiSemanticIndexedSymbol): Boolean;
var
  lReference: TDelphiSemanticIndexedReference;
begin
  for lReference in aIndex.References do
    if SameText(lReference.Status, 'ambiguous') and HasSymbolCandidate(lReference, aSymbol) then
      Exit(True);

  Result := False;
end;

function HasUnresolvedReferenceByName(const aIndex: TDelphiSemanticProjectSymbolIndex;
  const aSymbol: TDelphiSemanticIndexedSymbol): Boolean;
var
  lReference: TDelphiSemanticIndexedReference;
begin
  for lReference in aIndex.References do
    if SameText(lReference.Status, 'unresolved') and SameText(lReference.Name, aSymbol.Name) then
      Exit(True);

  Result := False;
end;

function CandidateWithBlockerExists(const aCandidates: TList<TDelphiSemanticDeadCodeCandidate>;
  const aName, aBlocker: string): Boolean;
var
  lBlocker: string;
  lCandidate: TDelphiSemanticDeadCodeCandidate;
begin
  for lCandidate in aCandidates do
    if SameText(lCandidate.Name, aName) then
      for lBlocker in lCandidate.Blockers do
        if SameText(lBlocker, aBlocker) then
          Exit(True);

  Result := False;
end;

function SourceLineContains(const aFileName: string; const aLine: Integer;
  const aText: string): Boolean;
var
  lLines: TStringList;
begin
  if (aFileName = '') or (aLine <= 0) then
    Exit(False);

  lLines := TStringList.Create;
  try
    try
      lLines.LoadFromFile(aFileName);
    except
      Exit(False);
    end;
    if aLine > lLines.Count then
      Exit(False);

    Result := ContainsText(lLines[aLine - 1], aText);
  finally
    lLines.Free;
  end;
end;

function SourceContains(const aFileName, aText: string): Boolean;
var
  lLines: TStringList;
begin
  if aFileName = '' then
    Exit(False);

  lLines := TStringList.Create;
  try
    try
      lLines.LoadFromFile(aFileName);
    except
      Exit(False);
    end;

    Result := ContainsText(lLines.Text, aText);
  finally
    lLines.Free;
  end;
end;

function SourceSectionContainsIdentifier(const aFileName, aSectionName, aName: string): Boolean;
var
  lAfterSection: string;
  lEndPos: Integer;
  lLines: TStringList;
  lSourceText: string;
  lStartPos: Integer;
begin
  if (aFileName = '') or (aSectionName = '') or (aName = '') then
    Exit(False);

  lLines := TStringList.Create;
  try
    try
      lLines.LoadFromFile(aFileName);
    except
      Exit(False);
    end;

    lSourceText := lLines.Text;
  finally
    lLines.Free;
  end;

  lStartPos := Pos(LowerCase(aSectionName), LowerCase(lSourceText));
  if lStartPos <= 0 then
    Exit(False);

  lAfterSection := Copy(lSourceText, lStartPos + Length(aSectionName), MaxInt);
  lEndPos := Pos('end.', LowerCase(lAfterSection));
  if lEndPos > 0 then
    lAfterSection := Copy(lAfterSection, 1, lEndPos - 1);

  Result := TRegEx.IsMatch(lAfterSection, '\b' + TRegEx.Escape(aName) + '\b', [roIgnoreCase]);
end;

function SourceExportsSymbol(const aFileName, aName: string): Boolean;
var
  lLines: TStringList;
  lMatch: TMatch;
  lSourceText: string;
begin
  if (aFileName = '') or (aName = '') then
    Exit(False);

  lLines := TStringList.Create;
  try
    try
      lLines.LoadFromFile(aFileName);
    except
      Exit(False);
    end;

    lSourceText := lLines.Text;
  finally
    lLines.Free;
  end;

  lMatch := TRegEx.Match(lSourceText, '\bexports\b(.*?);', [roIgnoreCase, roSingleLine]);
  while lMatch.Success do
  begin
    if TRegEx.IsMatch(lMatch.Groups[1].Value, '\b' + TRegEx.Escape(aName) + '\b',
      [roIgnoreCase]) then
      Exit(True);
    lMatch := lMatch.NextMatch;
  end;

  Result := False;
end;

procedure AddBlocker(const aBlockers: TList<string>; const aBlocker: string);
begin
  if aBlocker <> '' then
    aBlockers.Add(aBlocker);
end;

function HasInitializationHook(const aSymbol: TDelphiSemanticIndexedSymbol): Boolean;
begin
  Result := SourceSectionContainsIdentifier(aSymbol.FileName, 'initialization', aSymbol.Name) or
    SourceSectionContainsIdentifier(aSymbol.FileName, 'finalization', aSymbol.Name);
end;

function MakeCandidate(const aSymbol: TDelphiSemanticIndexedSymbol; const aStatus, aReason,
  aProfile: string; const aReferenceCount: Integer; const aBlockers: TArray<string>):
  TDelphiSemanticDeadCodeCandidate;
begin
  Result := Default(TDelphiSemanticDeadCodeCandidate);
  Result.SymbolId := aSymbol.Id;
  Result.Name := aSymbol.Name;
  Result.Kind := aSymbol.Kind;
  Result.OwnerName := aSymbol.OwnerName;
  Result.UnitName := aSymbol.UnitName;
  Result.FileName := aSymbol.FileName;
  Result.Line := aSymbol.Line;
  Result.Column := aSymbol.Column;
  Result.Status := aStatus;
  Result.Reason := aReason;
  Result.SafetyProfile := aProfile;
  Result.ReferenceCount := aReferenceCount;
  Result.Blockers := aBlockers;
end;

function ExternallyVisible(const aSymbol: TDelphiSemanticIndexedSymbol): Boolean;
begin
  Result := SameText(aSymbol.SectionKind, 'interface') or SameText(aSymbol.Visibility, 'public');
end;

function DefinitelyUnusedEligible(const aSymbol: TDelphiSemanticIndexedSymbol): Boolean;
begin
  Result := IsDataSymbol(aSymbol) or
    SameText(aSymbol.Visibility, 'private') or SameText(aSymbol.Visibility, 'strict private');
end;

class function TDelphiSemanticDeadCodeReporter.Report(
  const aContext: TDelphiSemanticSymbolQueryContext; const aProfile: string):
  TDelphiSemanticDeadCodeReport;
var
  lBlockers: TList<string>;
  lCandidate: TDelphiSemanticDeadCodeCandidate;
  lCandidates: TList<TDelphiSemanticDeadCodeCandidate>;
  lIndex: TDelphiSemanticProjectSymbolIndex;
  lProfile: string;
  lReference: TDelphiSemanticIndexedReference;
  lReferenceCount: Integer;
  lSymbol: TDelphiSemanticIndexedSymbol;
begin
  lProfile := aProfile;
  if lProfile = '' then
    lProfile := 'audit';

  lIndex := TDelphiSemanticProjectSymbolIndexer.Build(aContext);
  lCandidates := TList<TDelphiSemanticDeadCodeCandidate>.Create;
  try
    for lSymbol in lIndex.Symbols do
    begin
      if not IsProjectSymbol(lSymbol) or not IsCandidateKind(lSymbol) then
        Continue;

      lReferenceCount := CountResolvedReferences(lIndex, lSymbol);
      if (lReferenceCount = 0) and not HasAmbiguousReference(lIndex, lSymbol) and
        not HasUnresolvedReferenceByName(lIndex, lSymbol) then
        lReferenceCount := CountSameUnitNameReferences(lIndex, lSymbol);
      if lReferenceCount > 0 then
        Continue;

      lBlockers := TList<string>.Create;
      try
        if SameText(lSymbol.Visibility, 'published') then
          AddBlocker(lBlockers, 'published-or-dfm-handler');
        if SourceLineContains(lSymbol.FileName, lSymbol.Line, 'message') then
          AddBlocker(lBlockers, 'message-method');
        if SourceExportsSymbol(lSymbol.FileName, lSymbol.Name) then
          AddBlocker(lBlockers, 'exported-symbol');
        if HasInitializationHook(lSymbol) then
          AddBlocker(lBlockers, 'initialization-hook');
        if HasAmbiguousReference(lIndex, lSymbol) then
          AddBlocker(lBlockers, 'ambiguous-reference');
        if HasUnresolvedReferenceByName(lIndex, lSymbol) then
          AddBlocker(lBlockers, 'unresolved-reference');

        if lBlockers.Count > 0 then
          lCandidate := MakeCandidate(lSymbol, 'blocked', 'dynamic-or-unresolved-risk',
            lProfile, lReferenceCount, lBlockers.ToArray)
        else if ExternallyVisible(lSymbol) then
          lCandidate := MakeCandidate(lSymbol, 'externally-visible', 'public-api-surface',
            lProfile, lReferenceCount, [])
        else if DefinitelyUnusedEligible(lSymbol) then
          lCandidate := MakeCandidate(lSymbol, 'definitely-unused', 'no-resolved-references',
            lProfile, lReferenceCount, [])
        else
          lCandidate := MakeCandidate(lSymbol, 'maybe-unused', 'conservative-audit',
            lProfile, lReferenceCount, []);

        lCandidates.Add(lCandidate);
      finally
        lBlockers.Free;
      end;
    end;

    for lReference in lIndex.References do
      if SameText(lReference.Status, 'unresolved') and not CandidateWithBlockerExists(lCandidates,
        lReference.Name, 'unresolved-reference') then
      begin
        lSymbol := Default(TDelphiSemanticIndexedSymbol);
        lSymbol.Id.Value := LowerCase(lReference.UnitName) + ':unresolved:' +
          LowerCase(lReference.Name) + ':' + IntToStr(lReference.Line) + ':' +
          IntToStr(lReference.Column);
        lSymbol.Name := lReference.Name;
        lSymbol.Kind := 'unresolved-reference';
        lSymbol.UnitName := lReference.UnitName;
        lSymbol.SectionKind := lReference.SectionKind;
        lSymbol.SourceKind := lReference.SourceKind;
        lSymbol.FileName := lReference.FileName;
        lSymbol.Line := lReference.Line;
        lSymbol.Column := lReference.Column;
        if IsProjectSymbol(lSymbol) then
          lCandidates.Add(MakeCandidate(lSymbol, 'blocked', 'unresolved-reference-risk',
            lProfile, 0, ['unresolved-reference']));
      end;

    Result := Default(TDelphiSemanticDeadCodeReport);
    Result.Profile := lProfile;
    Result.Candidates := lCandidates.ToArray;
  finally
    lCandidates.Free;
  end;
end;

end.
