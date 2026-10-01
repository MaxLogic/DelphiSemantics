unit DelphiSemantics.Refactor.Plan;

interface

uses
  System.SysUtils;

type
  ESemanticPlanValidation = class(EArgumentException);

  // Structural status is not certification of closed-world semantic completeness.
  TSemanticPlanStatus = (Complete, NoChange, Incomplete, Blocked);

  TSemanticPlanContext = record
    ProjectIdentity: string;
    CompilerIdentity: string;
    ModelVersion: string;
    ConfigurationFingerprint: string;
  end;

  // Facts must come from the same observations used to produce semantic results.
  // This contract does not read files or certify caller-supplied completeness.
  TSemanticPlanSource = record
    FileName: string;
    ContentHash: string;
    IncludeGraphHash: string;
    OriginalText: string;
  end;

  // Original-source UTF-16 coordinates, 1-based and half-open [start, finish).
  // An insertion has equal endpoints and empty ExpectedText. Insertions touching
  // another edit are refused; adjacent nonempty replacement ranges are allowed.
  TSemanticPlanEdit = record
    FileName: string;
    StartLine: Integer;
    StartColumn: Integer;
    EndLine: Integer;
    EndColumn: Integer;
    ExpectedText: string;
    ReplacementText: string;
  end;

  TSemanticRefactoringPlan = class sealed
  strict private
    fContext: TSemanticPlanContext;
    fStatus: TSemanticPlanStatus;
    fReason: string;
    fSources: TArray<TSemanticPlanSource>;
    fEdits: TArray<TSemanticPlanEdit>;
    function GetSourceCount: Integer;
    function GetEditCount: Integer;
    function GetSource(const aIndex: Integer): TSemanticPlanSource;
    function GetEdit(const aIndex: Integer): TSemanticPlanEdit;
  public
    constructor Create(const aContext: TSemanticPlanContext;
      const aStatus: TSemanticPlanStatus; const aReason: string;
      const aSources: TArray<TSemanticPlanSource>; const aEdits: TArray<TSemanticPlanEdit>);
    class function TryCreate(const aContext: TSemanticPlanContext;
      const aStatus: TSemanticPlanStatus; const aReason: string;
      const aSources: TArray<TSemanticPlanSource>; const aEdits: TArray<TSemanticPlanEdit>;
      out aPlan: TSemanticRefactoringPlan; out aError: string): Boolean; static;
    function MatchesObservations(const aContext: TSemanticPlanContext;
      const aSources: TArray<TSemanticPlanSource>; out aError: string): Boolean;
    property Context: TSemanticPlanContext read fContext;
    property Status: TSemanticPlanStatus read fStatus;
    property Reason: string read fReason;
    property SourceCount: Integer read GetSourceCount;
    property EditCount: Integer read GetEditCount;
    property Sources[const aIndex: Integer]: TSemanticPlanSource read GetSource;
    property Edits[const aIndex: Integer]: TSemanticPlanEdit read GetEdit;
  end;

implementation

uses
  System.Generics.Collections, System.Generics.Defaults,
  AutoFree;

type
  TValidatedEdit = record
    SourceIndex: Integer;
    StartOffset: Integer;
    EndOffset: Integer;
  end;

function SameContext(const aLeft, aRight: TSemanticPlanContext): Boolean;
begin
  Result := (aLeft.ProjectIdentity = aRight.ProjectIdentity) and
    (aLeft.CompilerIdentity = aRight.CompilerIdentity) and
    (aLeft.ModelVersion = aRight.ModelVersion) and
    (aLeft.ConfigurationFingerprint = aRight.ConfigurationFingerprint);
end;

function HasContext(const aContext: TSemanticPlanContext): Boolean;
begin
  Result := (Trim(aContext.ProjectIdentity) <> '') and
    (Trim(aContext.CompilerIdentity) <> '') and (Trim(aContext.ModelVersion) <> '') and
    (Trim(aContext.ConfigurationFingerprint) <> '');
end;

function TryOffset(const aText: string; const aLine, aColumn: Integer;
  out aOffset: Integer): Boolean;
var
  i, lLine, lStart, lFinish: Integer;
begin
  Result := False;
  aOffset := 0;
  if (aLine < 1) or (aColumn < 1) then
    Exit;
  i := 1;
  lLine := 1;
  while (i <= Length(aText)) and (lLine < aLine) do
  begin
    if aText[i] = #13 then
    begin
      Inc(i);
      if (i <= Length(aText)) and (aText[i] = #10) then
        Inc(i);
      Inc(lLine);
    end else if aText[i] = #10 then
    begin
      Inc(i);
      Inc(lLine);
    end else
      Inc(i);
  end;
  if lLine <> aLine then
    Exit;
  lStart := i;
  while (i <= Length(aText)) and (aText[i] <> #13) and (aText[i] <> #10) do
    Inc(i);
  lFinish := i;
  if aColumn > lFinish - lStart + 1 then
    Exit;
  aOffset := lStart + aColumn - 1;
  // Never split a UTF-16 surrogate pair. Newline boundaries are line-local above.
  if (aOffset > 1) and (aOffset <= Length(aText)) and
    (Ord(aText[aOffset - 1]) >= $D800) and (Ord(aText[aOffset - 1]) <= $DBFF) and
    (Ord(aText[aOffset]) >= $DC00) and (Ord(aText[aOffset]) <= $DFFF) then
    Exit;
  Result := True;
end;

function ValidateEdits(const aSources: TArray<TSemanticPlanSource>;
  const aEdits: TArray<TSemanticPlanEdit>; out aError: string): Boolean;
var
  g: TGarbos;
  lIndex: TDictionary<string, Integer>;
  lRanges: TArray<TValidatedEdit>;
  lEdit: TSemanticPlanEdit;
  lSource: TSemanticPlanSource;
  i, lSourceIndex: Integer;
begin
  Result := False;
  g := Default(TGarbos);
  aError := 'plan.invalid-manifest';
  if Length(aSources) = 0 then
    Exit;
  GC(lIndex, TDictionary<string, Integer>.Create(TStringComparer.Ordinal), g);
  for i := 0 to High(aSources) do
  begin
    lSource := aSources[i];
    if (Trim(lSource.FileName) = '') or (Trim(lSource.ContentHash) = '') or
      (Trim(lSource.IncludeGraphHash) = '') or lIndex.ContainsKey(lSource.FileName) then
      Exit;
    lIndex.Add(lSource.FileName, i);
  end;
  SetLength(lRanges, Length(aEdits));
  for i := 0 to High(aEdits) do
  begin
    lEdit := aEdits[i];
    aError := 'plan.source-not-observed';
    if not lIndex.TryGetValue(lEdit.FileName, lSourceIndex) then
      Exit;
    lSource := aSources[lSourceIndex];
    lRanges[i].SourceIndex := lSourceIndex;
    aError := 'plan.invalid-range';
    if not TryOffset(lSource.OriginalText, lEdit.StartLine, lEdit.StartColumn,
      lRanges[i].StartOffset) or
      not TryOffset(lSource.OriginalText, lEdit.EndLine, lEdit.EndColumn,
        lRanges[i].EndOffset) or (lRanges[i].EndOffset < lRanges[i].StartOffset) then
      Exit;
    aError := 'plan.expected-text-mismatch';
    if Copy(lSource.OriginalText, lRanges[i].StartOffset,
      lRanges[i].EndOffset - lRanges[i].StartOffset) <> lEdit.ExpectedText then
      Exit;
  end;
  TArray.Sort<TValidatedEdit>(lRanges, TComparer<TValidatedEdit>.Construct(
    function(const aLeft, aRight: TValidatedEdit): Integer
    begin
      Result := aLeft.SourceIndex - aRight.SourceIndex;
      if Result = 0 then
        Result := aLeft.StartOffset - aRight.StartOffset;
      if Result = 0 then
        Result := aLeft.EndOffset - aRight.EndOffset;
    end));
  aError := 'plan.overlapping-edits';
  for i := 1 to High(lRanges) do
  begin
    if (lRanges[i - 1].SourceIndex = lRanges[i].SourceIndex) and
      ((lRanges[i].StartOffset < lRanges[i - 1].EndOffset) or
       (lRanges[i].StartOffset = lRanges[i - 1].StartOffset) or
       ((lRanges[i].StartOffset = lRanges[i - 1].EndOffset) and
        (lRanges[i].StartOffset = lRanges[i].EndOffset))) then
      Exit;
  end;
  aError := '';
  Result := True;
end;

function TSemanticRefactoringPlan.GetSourceCount: Integer;
begin
  Result := Length(fSources);
end;

constructor TSemanticRefactoringPlan.Create(const aContext: TSemanticPlanContext;
  const aStatus: TSemanticPlanStatus; const aReason: string;
  const aSources: TArray<TSemanticPlanSource>; const aEdits: TArray<TSemanticPlanEdit>);
var
  lError: string;
begin
  inherited Create;
  if not HasContext(aContext) then
    raise ESemanticPlanValidation.Create('plan.invalid-context');
  if not (aStatus in [TSemanticPlanStatus.Complete, TSemanticPlanStatus.NoChange,
    TSemanticPlanStatus.Incomplete, TSemanticPlanStatus.Blocked]) then
    raise ESemanticPlanValidation.Create('plan.invalid-status');
  if (aStatus = TSemanticPlanStatus.Complete) <> (Length(aEdits) > 0) then
    raise ESemanticPlanValidation.Create('plan.status-edits-mismatch');
  if (aStatus in [TSemanticPlanStatus.Incomplete, TSemanticPlanStatus.Blocked]) and
    (Trim(aReason) = '') then
    raise ESemanticPlanValidation.Create('plan.missing-reason');
  if not ValidateEdits(aSources, aEdits, lError) then
    raise ESemanticPlanValidation.Create(lError);
  fContext := aContext;
  fStatus := aStatus;
  fReason := aReason;
  fSources := Copy(aSources);
  fEdits := Copy(aEdits);
end;

function TSemanticRefactoringPlan.GetEditCount: Integer;
begin
  Result := Length(fEdits);
end;

function TSemanticRefactoringPlan.GetSource(const aIndex: Integer): TSemanticPlanSource;
begin
  Result := fSources[aIndex];
end;

function TSemanticRefactoringPlan.GetEdit(const aIndex: Integer): TSemanticPlanEdit;
begin
  Result := fEdits[aIndex];
end;

class function TSemanticRefactoringPlan.TryCreate(const aContext: TSemanticPlanContext;
  const aStatus: TSemanticPlanStatus; const aReason: string;
  const aSources: TArray<TSemanticPlanSource>; const aEdits: TArray<TSemanticPlanEdit>;
  out aPlan: TSemanticRefactoringPlan; out aError: string): Boolean;
begin
  aPlan := nil;
  aError := '';
  try
    aPlan := TSemanticRefactoringPlan.Create(aContext, aStatus, aReason, aSources, aEdits);
    Result := True;
  except
    on E: ESemanticPlanValidation do
    begin
      aError := E.Message;
      Result := False;
    end;
  end;
end;

function TSemanticRefactoringPlan.MatchesObservations(const aContext: TSemanticPlanContext;
  const aSources: TArray<TSemanticPlanSource>; out aError: string): Boolean;
var
  g: TGarbos;
  lIndex: TDictionary<string, Integer>;
  i, lSourceIndex: Integer;
  lSource: TSemanticPlanSource;
begin
  Result := False;
  g := Default(TGarbos);
  aError := 'plan.stale-context';
  if not SameContext(fContext, aContext) then
    Exit;
  aError := 'plan.stale-manifest';
  if Length(aSources) <> Length(fSources) then
    Exit;
  GC(lIndex, TDictionary<string, Integer>.Create(TStringComparer.Ordinal), g);
  for i := 0 to High(aSources) do
  begin
    if lIndex.ContainsKey(aSources[i].FileName) then
      Exit;
    lIndex.Add(aSources[i].FileName, i);
  end;
  for lSource in fSources do
  begin
    aError := 'plan.stale-manifest';
    if not lIndex.TryGetValue(lSource.FileName, lSourceIndex) then
      Exit;
    aError := 'plan.stale-source';
    if (lSource.ContentHash <> aSources[lSourceIndex].ContentHash) or
      (lSource.IncludeGraphHash <> aSources[lSourceIndex].IncludeGraphHash) or
      (lSource.OriginalText <> aSources[lSourceIndex].OriginalText) then
      Exit;
  end;
  aError := '';
  Result := True;
end;

end.
