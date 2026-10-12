unit DelphiSemantics.Preprocess;

interface

uses
  DelphiSemantics.Source, DelphiSemantics.SourceConditionals;

type
  TDelphiSemanticPreprocessOptions = record
    SourceFileName: string;
    SourceText: string;
    Defines: TArray<string>;
    SearchPaths: TArray<string>;
  end;

  TDelphiSemanticPreprocessDiagnostic = record
    Code: string;
    Message: string;
    FileName: string;
    Line: Integer;
    Column: Integer;
  end;

  TDelphiSemanticSourceRegion = record
    FileName: string;
    StartLine: Integer;
    EndLine: Integer;
    Active: Boolean;
  end;

  // DS-659: where one output line came from. A Mixed line holds text of an include expanded
  // inside a source line; it has no exact position, so FileName, Line and Column name that
  // include directive. Line 0 means the origin is unknown.
  TDelphiSemanticSourceLineOrigin = record
    FileName: string;
    Line: Integer;
    Column: Integer;
    Mixed: Boolean;
  end;

  TDelphiSemanticIncludeFile = record
    FileName: string;
    ContentHash: string;
  end;

  // A copied segment of expanded text and its in-memory source witness.
  TDelphiSemanticCopiedSourceSpan = record
    OutputStartOffset: Integer;
    OutputEndOffset: Integer;
    FileName: string;
    Line: Integer;
    Column: Integer;
    SourceLineStartOffset: Integer;
    SourceStartOffset: Integer;
    SourceText: string;
    ExpansionId: string;
  end;

  TDelphiSemanticPreprocessResult = record
    Success: Boolean;
    OutputText: string;
    IncludeGraphHash: string;
    SourceObservations: IDelphiSemanticSourceObservations;
    Regions: TArray<TDelphiSemanticSourceRegion>;
    Includes: TArray<TDelphiSemanticIncludeFile>;
    // One entry per OutputText line, in order.
    LineOrigins: TArray<TDelphiSemanticSourceLineOrigin>;
    CopiedSourceSpans: TArray<TDelphiSemanticCopiedSourceSpan>;
    ActivitySpans: TArray<TDelphiSemanticActivitySpan>;
    HasUnknownActivity: Boolean;
    ActivityEvidenceAvailable: Boolean;
    Diagnostics: TArray<TDelphiSemanticPreprocessDiagnostic>;
  end;

  TDelphiSemanticPreprocessor = record
  public
    class function PreprocessFile(const aOptions: TDelphiSemanticPreprocessOptions):
      TDelphiSemanticPreprocessResult; static;
  end;

function TryReadShortCompilerSwitch(const aDirective: string; const aSwitch: Char;
  out aEnabled: Boolean): Boolean;

implementation

uses
  System.Classes, System.Generics.Collections, System.IOUtils, System.StrUtils, System.SysUtils,
  MaxLogic.StrUtils, SimpleParser.Lexer, SimpleParser.Lexer.Types;

type
  TDefineMap = TDictionary<string, Boolean>;
  TSourceTextCache = TDictionary<string, TDelphiSemanticSourceLoadResult>;
  TLineOriginList = TList<TDelphiSemanticSourceLineOrigin>;

  TPreprocessCapture = class
    Spans: TList<TDelphiSemanticCopiedSourceSpan>;
    ActivitySpans: TList<TDelphiSemanticActivitySpan>;
    UnknownSymbols: TDictionary<string, Boolean>;
    AllSymbolsUnknown: Boolean;
    HasUnknownActivity: Boolean;
    ActivityComplete: Boolean;
    NextId: Integer;
    constructor Create;
    destructor Destroy; override;
    function NewExpansionId: string;
  end;

  TPreprocessOutputContext = record
    Capture: TPreprocessCapture;
    BaseOffset: Integer;
    ExpansionId: string;
  end;

  TPreprocessFrame = record
    ParentActive: Boolean;
    Active: Boolean;
    BranchTaken: Boolean;
    ParentActivity: TDelphiSemanticSourceActivity;
    Activity: TDelphiSemanticSourceActivity;
    BranchCoverage: TDelphiSemanticSourceActivity;
  end;

constructor TPreprocessCapture.Create;
begin
  inherited Create;
  ActivityComplete := True;
  Spans := TList<TDelphiSemanticCopiedSourceSpan>.Create;
  ActivitySpans := TList<TDelphiSemanticActivitySpan>.Create;
  UnknownSymbols := TDictionary<string, Boolean>.Create;
end;

destructor TPreprocessCapture.Destroy;
begin
  UnknownSymbols.Free;
  ActivitySpans.Free;
  Spans.Free;
  inherited;
end;

function TPreprocessCapture.NewExpansionId: string;
begin
  Inc(NextId);
  Result := IntToStr(NextId);
end;

function SourceLineStarts(const aText: string): TArray<Integer>;
var
  i: Integer;
  lStarts: TList<Integer>;
begin
  lStarts := TList<Integer>.Create;
  try
    lStarts.Add(1);
    i := 1;
    while i <= Length(aText) do
    begin
      if aText[i] = #13 then
      begin
        if i < Length(aText) then
          if aText[i + 1] = #10 then
            Inc(i);
        lStarts.Add(i + 1);
      end else if aText[i] = #10 then
        lStarts.Add(i + 1);
      Inc(i);
    end;
    Result := lStarts.ToArray;
  finally
    lStarts.Free;
  end;
end;

procedure AppendCopiedText(const aOutput: TStringBuilder;
  const aContext: TPreprocessOutputContext; const aText, aSourceText, aFileName: string;
  const aLine, aColumn, aLineStartOffset: Integer);
var
  lSpan: TDelphiSemanticCopiedSourceSpan;
begin
  if aText = '' then
    Exit;
  lSpan := Default(TDelphiSemanticCopiedSourceSpan);
  lSpan.OutputStartOffset := aContext.BaseOffset + aOutput.Length + 1;
  lSpan.OutputEndOffset := lSpan.OutputStartOffset + Length(aText);
  lSpan.FileName := aFileName;
  lSpan.Line := aLine;
  lSpan.Column := aColumn;
  lSpan.SourceLineStartOffset := aLineStartOffset;
  if aLineStartOffset > 0 then
    lSpan.SourceStartOffset := aLineStartOffset + aColumn - 1;
  lSpan.SourceText := aSourceText;
  lSpan.ExpansionId := aContext.ExpansionId;
  aContext.Capture.Spans.Add(lSpan);
  aOutput.Append(aText);
end;

function CreateDiagnostic(const aCode, aMessage, aFileName: string;
  const aLine: Integer): TDelphiSemanticPreprocessDiagnostic;
begin
  Result.Code := aCode;
  Result.Message := aMessage;
  Result.FileName := aFileName;
  Result.Line := aLine;
  Result.Column := 1;
end;

procedure AddDiagnostic(const aDiagnostics: TList<TDelphiSemanticPreprocessDiagnostic>;
  const aCode, aMessage, aFileName: string; const aLine: Integer);
begin
  aDiagnostics.Add(CreateDiagnostic(aCode, aMessage, aFileName, aLine));
end;

function DefineKey(const aName: string): string;
begin
  Result := UpperCase(aName.Trim);
end;

function IsCompilerPredefinedConditional(const aName: string): Boolean;
var
  i: Integer;
  lName: string;
begin
  lName := DefineKey(aName);
  // DS-667: names, not assumed values, from Embarcadero's predefined table:
  // https://docwiki.embarcadero.com/RADStudio/Athens/en/Conditional_compilation_(Delphi)
  // Includes documented legacy and framework symbols; VER versions remain unknown.
  if (Length(lName) > 3) and StartsStr('VER', lName) then
  begin
    for i := 4 to Length(lName) do
      if not CharInSet(lName[i], ['0'..'9']) then
        Exit(False);
    Exit(True);
  end;
  // Delphi 12 compiler probes across all nine installed targets also establish LLVM,
  // MANAGED_RECORD and WEAK_NATIVEINT (round9-compiler-predefined-probe.json).
  Result := MatchText(lName, ['ALIGN_STACK', 'ANDROID', 'ANDROID32', 'ANDROID64',
    'ASSEMBLER', 'AUTOREFCOUNT', 'CONDITIONALEXPRESSIONS', 'CONSOLE', 'CPU386',
    'CPU32BITS', 'CPU64BITS', 'CPUARM', 'CPUARM32', 'CPUARM64', 'CPUX64', 'CPUX86',
    'DCC', 'ELF', 'EXTERNALLINKER', 'FRAMEWORK_FMX', 'FRAMEWORK_VCL', 'IOS', 'IOS32', 'IOS64',
    'IOSSIMULATOR',
    'LINUX', 'LINUX32', 'LINUX64', 'LLVM', 'MACOS', 'MACOS32', 'MACOS64', 'MANAGED_RECORD', 'MSWINDOWS',
    'NATIVECODE', 'NEXTGEN', 'OSX', 'OSX32', 'OSX64', 'PC_MAPPED_EXCEPTIONS', 'PIC', 'POSIX',
    'POSIX32', 'POSIX64', 'UNDERSCOREIMPORTNAME', 'UNICODE', 'WEAKINSTREF',
    'WEAKINTFREF', 'WEAKREF', 'WEAK_NATIVEINT', 'WIN32', 'WIN64']);
end;

function IsConditionalStateKnown(const aDefines: TDefineMap; const aName: string;
  const aCapture: TPreprocessCapture = nil): Boolean;
var
  lUnknown: Boolean;
begin
  // An ordinary absent define is false; captured DEFINE/UNDEF states also win
  // for compiler symbols whose implicit value is otherwise not captured.
  Result := aDefines.ContainsKey(DefineKey(aName)) or
    not IsCompilerPredefinedConditional(aName);
  if aCapture <> nil then
  begin
    if aCapture.UnknownSymbols.TryGetValue(DefineKey(aName), lUnknown) then
      Result := not lUnknown
    else if aCapture.AllSymbolsUnknown then
      Result := False;
  end;
end;

function IsDefined(const aDefines: TDefineMap; const aName: string): Boolean;
begin
  if not aDefines.TryGetValue(DefineKey(aName), Result) then
    Result := False;
end;

function CalculateTextHash(const aText: string): string;
const
  cFnv32Mask: UInt64 = $FFFFFFFF;
  cFnvOffsetBasis: UInt64 = 2166136261;
  cFnvPrime: UInt64 = 16777619;
var
  i: Integer;
  lHash: UInt64;
begin
  lHash := cFnvOffsetBasis;
  for i := 1 to Length(aText) do
  begin
    lHash := lHash xor Ord(aText[i]);
    lHash := (lHash * cFnvPrime) and cFnv32Mask;
  end;
  Result := IntToHex(Int64(lHash), 8);
end;

function TryLoadPreprocessSource(const aFileName: string;
  const aSourceCache: TSourceTextCache;
  const aDiagnostics: TList<TDelphiSemanticPreprocessDiagnostic>;
  out aSourceText: string): Boolean;
var
  lDiagnostic: TDelphiSemanticSourceDiagnostic;
  lFileName: string;
  lSourceLoad: TDelphiSemanticSourceLoadResult;
begin
  lFileName := TPath.GetFullPath(aFileName);
  if aSourceCache.TryGetValue(lFileName, lSourceLoad) then
  begin
    aSourceText := lSourceLoad.Source.Text;
    Exit(True);
  end;

  lSourceLoad := TDelphiSemanticSourceLoader.LoadFile(lFileName);
  if not lSourceLoad.Success then
  begin
    if Length(lSourceLoad.Diagnostics) > 0 then
    begin
      lDiagnostic := lSourceLoad.Diagnostics[0];
      AddDiagnostic(aDiagnostics, lDiagnostic.Code, lDiagnostic.Message,
        lDiagnostic.FileName, 0);
    end else
      AddDiagnostic(aDiagnostics, 'SOURCE_FILE_NOT_FOUND',
        'Source file not found: ' + lFileName, lFileName, 0);
    aSourceText := '';
    Exit(False);
  end;

  aSourceText := lSourceLoad.Source.Text;
  aSourceCache.Add(lFileName, lSourceLoad);
  Result := True;
end;

function CurrentActive(const aStack: TList<TPreprocessFrame>): Boolean;
begin
  if aStack.Count = 0 then
    Exit(True);

  Result := aStack[Pred(aStack.Count)].Active;
end;

function ActivityAnd(const aLeft, aRight: TDelphiSemanticSourceActivity):
  TDelphiSemanticSourceActivity;
begin
  if (aLeft = saInactive) or (aRight = saInactive) then
    Exit(saInactive);
  if (aLeft = saUnknown) or (aRight = saUnknown) then
    Exit(saUnknown);
  Result := saActive;
end;

function ActivityNot(const aValue: TDelphiSemanticSourceActivity): TDelphiSemanticSourceActivity;
begin
  case aValue of
    saInactive: Result := saActive;
    saActive: Result := saInactive;
  else
    Result := saUnknown;
  end;
end;

function ConditionActivity(const aActive, aKnown: Boolean): TDelphiSemanticSourceActivity;
begin
  if not aKnown then
    Exit(saUnknown);
  if aActive then
    Result := saActive
  else
    Result := saInactive;
end;

function CurrentActivity(const aStack: TList<TPreprocessFrame>): TDelphiSemanticSourceActivity;
begin
  if aStack.Count = 0 then
    Exit(saActive);
  Result := aStack[Pred(aStack.Count)].Activity;
end;

procedure CaptureActivity(const aContext: TPreprocessOutputContext;
  const aStack: TList<TPreprocessFrame>; const aSource, aFileName: string;
  const aStart, aLength: Integer);
var
  lSpan: TDelphiSemanticActivitySpan;
begin
  if aLength <= 0 then
    Exit;
  lSpan.FileName := aFileName;
  lSpan.SourceText := aSource;
  lSpan.StartOffset := aStart;
  lSpan.EndOffset := aStart + aLength;
  lSpan.Activity := CurrentActivity(aStack);
  if lSpan.Activity = saUnknown then
    aContext.Capture.HasUnknownActivity := True;
  aContext.Capture.ActivitySpans.Add(lSpan);
end;

procedure CaptureDirectiveActivity(const aContext: TPreprocessOutputContext;
  const aBefore, aAfter: TDelphiSemanticSourceActivity;
  const aSource, aFileName: string; const aStart, aLength: Integer);
var
  lSpan: TDelphiSemanticActivitySpan;
begin
  if aLength <= 0 then
    Exit;
  lSpan.FileName := aFileName;
  lSpan.SourceText := aSource;
  lSpan.StartOffset := aStart;
  lSpan.EndOffset := aStart + aLength;
  if (aBefore = saUnknown) or (aAfter = saUnknown) then
  begin
    lSpan.Activity := saUnknown;
    aContext.Capture.HasUnknownActivity := True;
  end else if (aBefore = saInactive) or (aAfter = saInactive) then
    lSpan.Activity := saInactive
  else
    lSpan.Activity := saActive;
  aContext.Capture.ActivitySpans.Add(lSpan);
end;

function IsConditionalDirectiveText(const aDirective: string): Boolean;
var
  lText: string;
begin
  lText := aDirective.Trim;
  Result := StartsText('IFDEF ', lText) or StartsText('IFNDEF ', lText) or
    StartsText('IF ', lText) or StartsText('ELSEIF ', lText) or SameText(lText, 'ELSE') or
    StartsText('ELSE ', lText) or SameText(lText, 'ENDIF') or StartsText('ENDIF ', lText) or
    SameText(lText, 'IFEND') or StartsText('IFEND ', lText);
end;

function MaskDirectiveLookalikes(const aText: string): string;
var
  i: Integer;
  lLexer: TmwBasePasLex;
begin
  Result := aText;
  lLexer := TmwBasePasLex.Create;
  try
    lLexer.UseDefines := False;
    lLexer.Origin := aText;
    while lLexer.TokenID <> ptNull do
    begin
      if lLexer.TokenID in [ptBorComment, ptAnsiComment, ptSlashesComment, ptStringConst] then
        for i := lLexer.TokenPos + 1 to lLexer.TokenPos + lLexer.TokenLen do
          if Result[i] = '$' then
            Result[i] := ' ';
      lLexer.Next;
    end;
  finally
    lLexer.Free;
  end;
end;

function TryExtractDirective(const aLine: string; out aDirective: string;
  out aNeedsCloseBrace: Boolean): Boolean;
var
  lLine: string;
  lStart: Integer;
  lStop: Integer;
begin
  aNeedsCloseBrace := False;
  lLine := aLine;
  lStart := Pos('{$', lLine);
  if lStart > 0 then
  begin
    lStop := PosEx('}', lLine, lStart + 2);
    if lStop > lStart then
    begin
      aDirective := Copy(lLine, lStart + 2, lStop - lStart - 2).Trim;
      Exit(True);
    end;
    aDirective := Copy(lLine, lStart + 2, MaxInt).Trim;
    if IsConditionalDirectiveText(aDirective) then
    begin
      aNeedsCloseBrace := True;
      Exit(True);
    end;
  end;

  lStart := Pos('(*$', lLine);
  if lStart > 0 then
  begin
    lStop := PosEx('*)', lLine, lStart + 3);
    if lStop > lStart then
    begin
      aDirective := Copy(lLine, lStart + 3, lStop - lStart - 3).Trim;
      Exit(True);
    end;
  end;

  Result := False;
end;

function StripOuterParentheses(const aText: string): string;
var
  i: Integer;
  lDepth: Integer;
  lText: string;
begin
  lText := aText.Trim;
  while (Length(lText) >= 2) and (lText[1] = '(') and (lText[Length(lText)] = ')') do
  begin
    lDepth := 0;
    for i := 1 to Length(lText) do
    begin
      if lText[i] = '(' then
        Inc(lDepth)
      else if lText[i] = ')' then
      begin
        Dec(lDepth);
        if (lDepth = 0) and (i < Length(lText)) then
          Exit(lText);
      end;
    end;
    lText := Copy(lText, 2, Length(lText) - 2).Trim;
  end;
  Result := lText;
end;

function IsOperatorBoundary(const aText: string; const aIndex: Integer): Boolean;
begin
  Result := (aIndex < 1) or (aIndex > Length(aText)) or
    not CharInSet(aText[aIndex], ['A'..'Z', 'a'..'z', '0'..'9', '_']);
end;

function IsOperatorAt(const aText: string; const aIndex: Integer; const aOperator: string): Boolean;
var
  lOperatorLength: Integer;
begin
  lOperatorLength := Length(aOperator);
  if (aIndex < 1) or (aIndex + lOperatorLength - 1 > Length(aText)) then
    Exit(False);

  Result := SameText(Copy(aText, aIndex, lOperatorLength), aOperator) and
    IsOperatorBoundary(aText, aIndex - 1) and
    IsOperatorBoundary(aText, aIndex + lOperatorLength);
end;

function TrySplitTopLevelExpression(const aText, aOperator: string;
  out aLeft, aRight: string): Boolean;
var
  i: Integer;
  lDepth: Integer;
begin
  lDepth := 0;
  i := 1;
  while i <= Length(aText) do
  begin
    if aText[i] = '(' then
      Inc(lDepth)
    else if aText[i] = ')' then
      Dec(lDepth)
    else if (lDepth = 0) and IsOperatorAt(aText, i, aOperator) then
    begin
      aLeft := Copy(aText, 1, i - 1).Trim;
      aRight := Copy(aText, i + Length(aOperator), MaxInt).Trim;
      Exit((aLeft <> '') and (aRight <> ''));
    end;
    Inc(i);
  end;

  Result := False;
end;

function IsPlainConditionalIdentifier(const aText: string): Boolean;
var
  i: Integer;
begin
  Result := False;
  if (aText = '') or not CharInSet(aText[1], ['A'..'Z', 'a'..'z', '_']) then
    Exit;
  for i := 2 to Length(aText) do
    if not CharInSet(aText[i], ['A'..'Z', 'a'..'z', '0'..'9', '_']) then
      Exit;
  Result := True;
end;

function TryEvaluateIfExpression(const aExpression: string; const aDefines: TDefineMap;
  out aActive: Boolean; const aRequireKnownSymbols: Boolean = False;
  const aCapture: TPreprocessCapture = nil): Boolean;
var
  lLeft: string;
  lLeftActive: Boolean;
  lLeftKnown: Boolean;
  lName: string;
  lRight: string;
  lRightActive: Boolean;
  lRightKnown: Boolean;
  lText: string;
begin
  lText := StripOuterParentheses(aExpression);

  if TrySplitTopLevelExpression(lText, 'or', lLeft, lRight) then
  begin
    lLeftKnown := TryEvaluateIfExpression(lLeft, aDefines, lLeftActive, aRequireKnownSymbols, aCapture);
    if lLeftKnown and lLeftActive then
    begin
      aActive := True;
      Exit(True);
    end;
    lRightKnown := TryEvaluateIfExpression(lRight, aDefines, lRightActive, aRequireKnownSymbols, aCapture);
    if lRightKnown and lRightActive then
    begin
      aActive := True;
      Exit(True);
    end;
    aActive := False;
    Exit(lLeftKnown and lRightKnown);
  end;

  if TrySplitTopLevelExpression(lText, 'and', lLeft, lRight) then
  begin
    lLeftKnown := TryEvaluateIfExpression(lLeft, aDefines, lLeftActive, aRequireKnownSymbols, aCapture);
    if lLeftKnown and not lLeftActive then
    begin
      aActive := False;
      Exit(True);
    end;
    lRightKnown := TryEvaluateIfExpression(lRight, aDefines, lRightActive, aRequireKnownSymbols, aCapture);
    if lRightKnown and not lRightActive then
    begin
      aActive := False;
      Exit(True);
    end;
    aActive := True;
    Exit(lLeftKnown and lRightKnown);
  end;

  if StartsText('not ', lText) then
  begin
    if not TryEvaluateIfExpression(Copy(lText, 5, MaxInt), aDefines, lLeftActive, aRequireKnownSymbols, aCapture) then
      Exit(False);
    aActive := not lLeftActive;
    Exit(True);
  end;

  if StartsText('Defined(', lText) and EndsText(')', lText) then
  begin
    lName := Copy(lText, 9, Length(lText) - 9).Trim;
    if not IsPlainConditionalIdentifier(lName) or
      (aRequireKnownSymbols and not IsConditionalStateKnown(aDefines, lName, aCapture)) then
      Exit(False);
    aActive := IsDefined(aDefines, lName);
    Exit(True);
  end;

  if SameText(lText, 'True') then
  begin
    aActive := True;
    Exit(True);
  end;

  if SameText(lText, 'False') then
  begin
    aActive := False;
    Exit(True);
  end;

  if (Pos('(', lText) > 0) or (Pos(')', lText) > 0) then
    Exit(False);

  if MatchText(lText, ['CompilerVersion', 'RTLVersion']) then
    Exit(False);

  // IF identifiers denote Delphi constant expressions, not conditional define names.
  // Without a verified constant evaluator they remain unknown, even when -D names them.
  Result := False;
end;

procedure AddRegion(const aRegions: TList<TDelphiSemanticSourceRegion>; const aFileName: string;
  const aLine: Integer; const aActive: Boolean);
var
  lRegion: TDelphiSemanticSourceRegion;
begin
  lRegion.FileName := aFileName;
  lRegion.StartLine := aLine;
  lRegion.EndLine := aLine;
  lRegion.Active := aActive;
  aRegions.Add(lRegion);
end;

function ResolveIncludeFileName(const aIncludeName, aCurrentDirectory: string;
  const aOptions: TDelphiSemanticPreprocessOptions; out aFileName: string): Boolean;
var
  lPath: string;
  lSearchPath: string;
begin
  if TPath.IsPathRooted(aIncludeName) then
  begin
    aFileName := TPath.GetFullPath(aIncludeName);
    Exit(TFile.Exists(aFileName));
  end;

  lPath := TPath.GetFullPath(TPath.Combine(aCurrentDirectory, aIncludeName));
  if TFile.Exists(lPath) then
  begin
    aFileName := lPath;
    Exit(True);
  end;

  for lSearchPath in aOptions.SearchPaths do
  begin
    lPath := TPath.GetFullPath(TPath.Combine(lSearchPath, aIncludeName));
    if TFile.Exists(lPath) then
    begin
      aFileName := lPath;
      Exit(True);
    end;
  end;

  aFileName := '';
  Result := False;
end;

function IncludeArgumentFromDirective(const aDirective: string): string;
var
  lText: string;
begin
  lText := aDirective.Trim;
  if StartsText('I ', lText) then
    lText := Copy(lText, 3, MaxInt).Trim
  else if StartsText('INCLUDE ', lText) then
    lText := Copy(lText, 9, MaxInt).Trim
  else
    Exit('');

  if (Length(lText) >= 2) and (lText[1] = '''') and (lText[Length(lText)] = '''') then
    lText := Copy(lText, 2, Length(lText) - 2);

  Result := lText;
end;

function IsShortSwitchDirective(const aText: string): Boolean;
var
  i: Integer;
begin
  Result := False;
  i := 1;
  if aText = '' then
    Exit;
  while i <= Length(aText) do
  begin
    if (i + 1 > Length(aText)) or not CharInSet(UpCase(aText[i]), ['A'..'Z']) or
      not CharInSet(aText[i + 1], ['+', '-']) then
      Exit;
    Inc(i, 2);
    if i > Length(aText) then
      Exit(True);
    if aText[i] <> ',' then
      Exit;
    Inc(i);
    if i > Length(aText) then
      Exit;
  end;
end;

function TryReadShortCompilerSwitch(const aDirective: string; const aSwitch: Char;
  out aEnabled: Boolean): Boolean;
var
  i: Integer;
  lText: string;
begin
  Result := False;
  aEnabled := False;
  lText := aDirective.Trim;
  if StartsText('{$', lText) and EndsText('}', lText) then
    lText := Copy(lText, 3, Length(lText) - 3).Trim
  else if StartsText('(*$', lText) and EndsText('*)', lText) then
    lText := Copy(lText, 4, Length(lText) - 5).Trim;
  if not IsShortSwitchDirective(lText) then
    Exit;
  i := 1;
  while i <= Length(lText) do
  begin
    if UpCase(lText[i]) = UpCase(aSwitch) then
    begin
      // DS-714: compiler switch groups are applied from left to right.
      aEnabled := lText[i + 1] = '+';
      Result := True;
    end;
    Inc(i, 3);
  end;
end;

function IsCompilerSwitchDirective(const aDirective: string): Boolean;
var
  lText: string;
begin
  lText := aDirective.Trim;
  Result := IsShortSwitchDirective(lText) or StartsText('APPTYPE ', lText) or
    StartsText('LEGACYIFEND ', lText) or StartsText('M ', lText) or StartsText('MESSAGE ', lText) or
    StartsText('ENDREGION', lText) or StartsText('MINENUMSIZE ', lText) or StartsText('MODE ', lText) or
    StartsText('POINTERMATH ', lText) or StartsText('R ', lText) or StartsText('REGION', lText) or
    StartsText('RESOURCE ', lText) or StartsText('RANGECHECKS ', lText) or StartsText('RTTI ', lText) or
    StartsText('SCOPEDENUMS ', lText) or StartsText('SETPEFLAGS ', lText) or
    StartsText('STRONGLINKTYPES ', lText) or StartsText('WARN ', lText) or
    StartsText('WARNINGS ', lText) or StartsText('WEAKLINKRTTI ', lText) or
    StartsText('EXTERNALSYM ', lText) or StartsText('HPPEMIT ', lText) or
    StartsText('NODEFINE ', lText) or StartsText('OBJTYPENAME ', lText);
end;

procedure PushConditionalFrame(const aStack: TList<TPreprocessFrame>;
  const aActive: Boolean; const aKnown: Boolean = True);
var
  lFrame: TPreprocessFrame;
begin
  lFrame.ParentActive := CurrentActive(aStack);
  lFrame.Active := lFrame.ParentActive and aActive;
  lFrame.BranchTaken := aActive;
  lFrame.ParentActivity := CurrentActivity(aStack);
  lFrame.BranchCoverage := ConditionActivity(aActive, aKnown);
  lFrame.Activity := ActivityAnd(lFrame.ParentActivity, lFrame.BranchCoverage);
  aStack.Add(lFrame);
end;

procedure PushUnsupportedConditionalFrame(const aStack: TList<TPreprocessFrame>);
var
  lFrame: TPreprocessFrame;
begin
  lFrame.ParentActive := CurrentActive(aStack);
  lFrame.Active := False;
  lFrame.BranchTaken := True;
  lFrame.ParentActivity := CurrentActivity(aStack);
  lFrame.BranchCoverage := saUnknown;
  lFrame.Activity := ActivityAnd(lFrame.ParentActivity, saUnknown);
  aStack.Add(lFrame);
end;

procedure DisableUnsupportedConditionalFrame(const aStack: TList<TPreprocessFrame>);
var
  lFrame: TPreprocessFrame;
begin
  if aStack.Count = 0 then
    Exit;

  lFrame := aStack[Pred(aStack.Count)];
  lFrame.Active := False;
  lFrame.BranchTaken := True;
  lFrame.Activity := ActivityAnd(lFrame.ParentActivity,
    ActivityAnd(ActivityNot(lFrame.BranchCoverage), saUnknown));
  if lFrame.BranchCoverage <> saActive then
    lFrame.BranchCoverage := saUnknown;
  aStack[Pred(aStack.Count)] := lFrame;
end;

procedure UpdateElseFrame(const aStack: TList<TPreprocessFrame>);
var
  lFrame: TPreprocessFrame;
begin
  lFrame := aStack[Pred(aStack.Count)];
  lFrame.Active := lFrame.ParentActive and not lFrame.BranchTaken;
  lFrame.BranchTaken := True;
  lFrame.Activity := ActivityAnd(lFrame.ParentActivity, ActivityNot(lFrame.BranchCoverage));
  lFrame.BranchCoverage := saActive;
  aStack[Pred(aStack.Count)] := lFrame;
end;

procedure UpdateElseIfFrame(const aStack: TList<TPreprocessFrame>; const aActive: Boolean;
  const aKnown: Boolean);
var
  lFrame: TPreprocessFrame;
begin
  lFrame := aStack[Pred(aStack.Count)];
  lFrame.Active := lFrame.ParentActive and not lFrame.BranchTaken and aActive;
  lFrame.BranchTaken := lFrame.BranchTaken or aActive;
  lFrame.Activity := ActivityAnd(lFrame.ParentActivity,
    ActivityAnd(ActivityNot(lFrame.BranchCoverage), ConditionActivity(aActive, aKnown)));
  lFrame.BranchCoverage := ActivityNot(ActivityAnd(ActivityNot(lFrame.BranchCoverage),
    ActivityNot(ConditionActivity(aActive, aKnown))));
  aStack[Pred(aStack.Count)] := lFrame;
end;

procedure AddLineOrigin(const aOrigins: TLineOriginList; const aFileName: string;
  const aLine: Integer);
var
  lOrigin: TDelphiSemanticSourceLineOrigin;
begin
  lOrigin := Default(TDelphiSemanticSourceLineOrigin);
  lOrigin.FileName := aFileName;
  lOrigin.Line := aLine;
  aOrigins.Add(lOrigin);
end;

function IsFileInStack(const aStack: TList<string>; const aFileName: string): Boolean;
var
  lFileName: string;
begin
  for lFileName in aStack do
    if SameText(lFileName, aFileName) then
      Exit(True);

  Result := False;
end;

function ProcessDirective(const aDirective, aFileName: string; const aLine: Integer;
  const aOptions: TDelphiSemanticPreprocessOptions; const aDefines: TDefineMap;
  const aStack: TList<TPreprocessFrame>; const aDiagnostics: TList<TDelphiSemanticPreprocessDiagnostic>;
  const aOutput: TStringBuilder; const aRegions: TList<TDelphiSemanticSourceRegion>;
  const aIncludes: TList<TDelphiSemanticIncludeFile>; const aIncludeStack: TList<string>;
  const aSourceCache: TSourceTextCache; const aOrigins: TLineOriginList;
  const aContext: TPreprocessOutputContext; var aOutputLineWritten: Boolean): Boolean; forward;

function IsRootSourceFile(const aFileName: string;
  const aOptions: TDelphiSemanticPreprocessOptions): Boolean;
begin
  Result := SameText(TPath.GetFullPath(aOptions.SourceFileName), aFileName);
end;

function FindNextDirectiveStart(const aLine: string; const aStart: Integer): Integer;
var
  lBraceStart: Integer;
  lParenStart: Integer;
begin
  lBraceStart := PosEx('{$', aLine, aStart);
  lParenStart := PosEx('(*$', aLine, aStart);
  if lBraceStart = 0 then
    Exit(lParenStart);
  if lParenStart = 0 then
    Exit(lBraceStart);
  if lBraceStart < lParenStart then
    Result := lBraceStart
  else
    Result := lParenStart;
end;

function FindDirectiveStop(const aLine: string; const aDirectiveStart: Integer): Integer;
begin
  if Copy(aLine, aDirectiveStart, 3) = '(*$' then
    Result := PosEx('*)', aLine, aDirectiveStart + 3) + 1
  else
    Result := PosEx('}', aLine, aDirectiveStart + 2);

  if Result <= 1 then
    Result := 0;
end;

function RemoveInlineDirectivesForDetection(const aLine: string): string;
var
  lDirectiveStart: Integer;
  lDirectiveStop: Integer;
  lPos: Integer;
begin
  Result := '';
  lPos := 1;
  lDirectiveStart := FindNextDirectiveStart(aLine, lPos);
  while lDirectiveStart > 0 do
  begin
    Result := Result + Copy(aLine, lPos, lDirectiveStart - lPos);
    lDirectiveStop := FindDirectiveStop(aLine, lDirectiveStart);
    if lDirectiveStop = 0 then
      Exit(Result);
    lPos := lDirectiveStop + 1;
    lDirectiveStart := FindNextDirectiveStart(aLine, lPos);
  end;
  Result := Result + Copy(aLine, lPos, MaxInt);
end;

function ProcessInlineDirectiveLine(const aLine, aDirectiveLine, aFileName, aSourceText: string;
  const aLineNumber, aSourceLineStartOffset: Integer;
  const aOptions: TDelphiSemanticPreprocessOptions; const aDefines: TDefineMap;
  const aStack: TList<TPreprocessFrame>; const aDiagnostics:
  TList<TDelphiSemanticPreprocessDiagnostic>; const aOutput: TStringBuilder;
  const aRegions: TList<TDelphiSemanticSourceRegion>; const aIncludes:
  TList<TDelphiSemanticIncludeFile>; const aIncludeStack: TList<string>;
  const aSourceCache: TSourceTextCache; const aOrigins: TLineOriginList;
  const aContext: TPreprocessOutputContext): Boolean;
var
  lDirective: string;
  lDirectiveActivity: TDelphiSemanticSourceActivity;
  lDirectiveStart: Integer;
  lDirectiveStop: Integer;
  lIncludeColumn: Integer;
  lLineContext: TPreprocessOutputContext;
  lLineOutput: TStringBuilder;
  lOrigin: TDelphiSemanticSourceLineOrigin;
  lOriginCount: Integer;
  lOutputLineWritten: Boolean;
  lPos: Integer;
begin
  Result := True;
  lOriginCount := aOrigins.Count;
  lIncludeColumn := 0;
  lLineOutput := TStringBuilder.Create;
  try
    lLineContext := aContext;
    lLineContext.BaseOffset := aContext.BaseOffset + aOutput.Length;
    lPos := 1;
    lDirectiveStart := FindNextDirectiveStart(aDirectiveLine, lPos);
    while lDirectiveStart > 0 do
    begin
      CaptureActivity(aContext, aStack, aSourceText, aFileName,
        aSourceLineStartOffset + lPos - 1, lDirectiveStart - lPos);
      if CurrentActive(aStack) then
        AppendCopiedText(lLineOutput, lLineContext,
          Copy(aLine, lPos, lDirectiveStart - lPos), aSourceText, aFileName,
          aLineNumber, lPos, aSourceLineStartOffset)
      else
        lLineOutput.Append(StringOfChar(' ', lDirectiveStart - lPos));

      lDirectiveStop := FindDirectiveStop(aDirectiveLine, lDirectiveStart);
      if lDirectiveStop = 0 then
      begin
        lLineOutput.Append(StringOfChar(' ', Length(aLine) - lDirectiveStart + 1));
        Break;
      end;

      if Copy(aLine, lDirectiveStart, 3) = '(*$' then
        lDirective := Copy(aLine, lDirectiveStart + 3, lDirectiveStop - lDirectiveStart - 4).Trim
      else
        lDirective := Copy(aLine, lDirectiveStart + 2, lDirectiveStop - lDirectiveStart - 2).Trim;

      lDirectiveActivity := CurrentActivity(aStack);
      if IsCompilerSwitchDirective(lDirective) then
      begin
        if CurrentActive(aStack) then
          AppendCopiedText(lLineOutput, lLineContext,
            Copy(aLine, lDirectiveStart, lDirectiveStop - lDirectiveStart + 1),
            aSourceText, aFileName, aLineNumber, lDirectiveStart,
            aSourceLineStartOffset)
        else
          lLineOutput.Append(StringOfChar(' ', lDirectiveStop - lDirectiveStart + 1));
      end else
      begin
        lOutputLineWritten := False;
        if not ProcessDirective(lDirective, aFileName, aLineNumber, aOptions, aDefines,
          aStack, aDiagnostics, lLineOutput, aRegions, aIncludes, aIncludeStack, aSourceCache,
          aOrigins, lLineContext, lOutputLineWritten) then
          Result := False;
        // The first directive that expanded an include names the mixed lines.
        if (lIncludeColumn = 0) and (aOrigins.Count > lOriginCount) then
          lIncludeColumn := lDirectiveStart;
        lLineOutput.Append(StringOfChar(' ', lDirectiveStop - lDirectiveStart + 1));
      end;
      CaptureDirectiveActivity(aContext, lDirectiveActivity, CurrentActivity(aStack),
        aSourceText, aFileName, aSourceLineStartOffset + lDirectiveStart - 1,
        lDirectiveStop - lDirectiveStart + 1);
      lPos := lDirectiveStop + 1;
      lDirectiveStart := FindNextDirectiveStart(aDirectiveLine, lPos);
    end;

    CaptureActivity(aContext, aStack, aSourceText, aFileName,
      aSourceLineStartOffset + lPos - 1, Length(aLine) - lPos + 1);
    if CurrentActive(aStack) then
      AppendCopiedText(lLineOutput, lLineContext, Copy(aLine, lPos, MaxInt),
        aSourceText, aFileName, aLineNumber, lPos, aSourceLineStartOffset)
    else
      lLineOutput.Append(StringOfChar(' ', Length(aLine) - lPos + 1));
    aOutput.AppendLine(lLineOutput.ToString);
    // An include expanded inside this line mixes its text with the line's own text, so none of
    // the resulting lines has an exact position; all of them point at the include directive.
    if aOrigins.Count = lOriginCount then
      AddLineOrigin(aOrigins, aFileName, aLineNumber)
    else begin
      lOrigin.FileName := aFileName;
      lOrigin.Line := aLineNumber;
      lOrigin.Column := lIncludeColumn;
      lOrigin.Mixed := True;
      for lPos := lOriginCount to aOrigins.Count - 1 do
        aOrigins[lPos] := lOrigin;
      aOrigins.Add(lOrigin);
    end;
  finally
    lLineOutput.Free;
  end;
end;

procedure ProcessLoadedSourceFile(const aFileName, aSourceText: string;
  const aOptions: TDelphiSemanticPreprocessOptions;
  const aDefines: TDefineMap; const aStack: TList<TPreprocessFrame>;
  const aDiagnostics: TList<TDelphiSemanticPreprocessDiagnostic>; const aOutput: TStringBuilder;
  const aRegions: TList<TDelphiSemanticSourceRegion>; const aIncludes: TList<TDelphiSemanticIncludeFile>;
  const aIncludeStack: TList<string>; const aSourceCache: TSourceTextCache;
  const aOrigins: TLineOriginList; const aContext: TPreprocessOutputContext;
  var aSuccess: Boolean);
var
  i: Integer;
  lDirective: string;
  lDirectiveActivity: TDelphiSemanticSourceActivity;
  lDirectiveLines: TStringList;
  lDirectiveStart: Integer;
  lDirectiveStop: Integer;
  lLines: TStringList;
  lLineStarts: TArray<Integer>;
  lOutputLineWritten: Boolean;
  lPendingDirectiveCloseBrace: Boolean;
begin
  if IsFileInStack(aIncludeStack, aFileName) then
  begin
    aContext.Capture.ActivityComplete := False;
    AddDiagnostic(aDiagnostics, 'INCLUDE_CYCLE', 'Include cycle detected: ' + aFileName,
      aFileName, 0);
    aSuccess := False;
    Exit;
  end;

  lLines := TStringList.Create;
  lDirectiveLines := nil;
  try
    lDirectiveLines := TStringList.Create;
    lDirectiveLines.Text := MaskDirectiveLookalikes(aSourceText);
    aIncludeStack.Add(aFileName);
    lLines.Text := aSourceText;
    lLineStarts := SourceLineStarts(aSourceText);
    if Length(lLineStarts) < lLines.Count then
      SetLength(lLineStarts, lLines.Count);
    lPendingDirectiveCloseBrace := False;
    for i := 0 to Pred(lLines.Count) do
    begin
      if lPendingDirectiveCloseBrace and (lLines[i].Trim = '}') then
      begin
        lPendingDirectiveCloseBrace := False;
        aOutput.AppendLine('');
        AddLineOrigin(aOrigins, aFileName, i + 1);
        Continue;
      end;

      if TryExtractDirective(lDirectiveLines[i], lDirective, lPendingDirectiveCloseBrace) then
      begin
        lDirectiveStart := FindNextDirectiveStart(lDirectiveLines[i], 1);
        lDirectiveStop := FindDirectiveStop(lDirectiveLines[i], lDirectiveStart);
        if IsCompilerSwitchDirective(lDirective) or
          (RemoveInlineDirectivesForDetection(lDirectiveLines[i]).Trim <> '') or
          ((lDirectiveStop > 0) and
          (FindNextDirectiveStart(lDirectiveLines[i], lDirectiveStop + 1) > 0)) then
        begin
          AddRegion(aRegions, aFileName, i + 1, CurrentActive(aStack));
          if not ProcessInlineDirectiveLine(lLines[i], lDirectiveLines[i], aFileName,
            aSourceText, i + 1, lLineStarts[i], aOptions, aDefines,
            aStack, aDiagnostics, aOutput, aRegions, aIncludes, aIncludeStack,
            aSourceCache, aOrigins, aContext) then
            aSuccess := False;
          Continue;
        end;

        lDirectiveActivity := CurrentActivity(aStack);
        lOutputLineWritten := False;
        if not ProcessDirective(lDirective, aFileName, i + 1, aOptions, aDefines, aStack,
          aDiagnostics, aOutput, aRegions, aIncludes, aIncludeStack, aSourceCache, aOrigins,
          aContext, lOutputLineWritten) then
          aSuccess := False;
        CaptureDirectiveActivity(aContext, lDirectiveActivity, CurrentActivity(aStack),
          aSourceText, aFileName, lLineStarts[i] + lDirectiveStart - 1,
          lDirectiveStop - lDirectiveStart + 1);
        if not lOutputLineWritten then
        begin
          aOutput.AppendLine('');
          AddLineOrigin(aOrigins, aFileName, i + 1);
        end;
      end else
      begin
        AddRegion(aRegions, aFileName, i + 1, CurrentActive(aStack));
        CaptureActivity(aContext, aStack, aSourceText, aFileName,
          lLineStarts[i], Length(lLines[i]));
        if CurrentActive(aStack) then
        begin
          AppendCopiedText(aOutput, aContext, lLines[i], aSourceText, aFileName,
            i + 1, 1, lLineStarts[i]);
          aOutput.AppendLine;
        end
        else
          aOutput.AppendLine('');
        AddLineOrigin(aOrigins, aFileName, i + 1);
      end;
    end;
  finally
    if aIncludeStack.Count > 0 then
      aIncludeStack.Delete(Pred(aIncludeStack.Count));
    lDirectiveLines.Free;
    lLines.Free;
  end;
end;

procedure ProcessSourceFile(const aFileName: string; const aOptions: TDelphiSemanticPreprocessOptions;
  const aDefines: TDefineMap; const aStack: TList<TPreprocessFrame>;
  const aDiagnostics: TList<TDelphiSemanticPreprocessDiagnostic>; const aOutput: TStringBuilder;
  const aRegions: TList<TDelphiSemanticSourceRegion>; const aIncludes: TList<TDelphiSemanticIncludeFile>;
  const aIncludeStack: TList<string>; const aSourceCache: TSourceTextCache;
  const aOrigins: TLineOriginList; const aContext: TPreprocessOutputContext;
  var aSuccess: Boolean);
var
  lText: string;
begin
  if IsRootSourceFile(aFileName, aOptions) and (aOptions.SourceText <> '') then
    lText := aOptions.SourceText
  else if not TryLoadPreprocessSource(aFileName, aSourceCache, aDiagnostics, lText) then
  begin
    aContext.Capture.ActivityComplete := False;
    aSuccess := False;
    Exit;
  end;

  ProcessLoadedSourceFile(aFileName, lText, aOptions, aDefines, aStack, aDiagnostics,
    aOutput, aRegions, aIncludes, aIncludeStack, aSourceCache, aOrigins, aContext,
    aSuccess);
end;

function ProcessDirective(const aDirective, aFileName: string; const aLine: Integer;
  const aOptions: TDelphiSemanticPreprocessOptions; const aDefines: TDefineMap;
  const aStack: TList<TPreprocessFrame>; const aDiagnostics: TList<TDelphiSemanticPreprocessDiagnostic>;
  const aOutput: TStringBuilder; const aRegions: TList<TDelphiSemanticSourceRegion>;
  const aIncludes: TList<TDelphiSemanticIncludeFile>; const aIncludeStack: TList<string>;
  const aSourceCache: TSourceTextCache; const aOrigins: TLineOriginList;
  const aContext: TPreprocessOutputContext; var aOutputLineWritten: Boolean): Boolean;
var
  lActive: Boolean;
  lInclude: TDelphiSemanticIncludeFile;
  lIncludeContext: TPreprocessOutputContext;
  lIncludeFileName: string;
  lIncludeName: string;
  lIncludeOutput: TStringBuilder;
  lIncludeText: string;
  lKnown: Boolean;
  lDiscardOrigins: TLineOriginList;
  lOrigins: TLineOriginList;
  lEmitInclude: Boolean;
  lSuccess: Boolean;
  lText: string;
begin
  try
    aOutputLineWritten := False;
    lText := aDirective.Trim;

    if StartsText('IFDEF ', lText) then
    begin
      lKnown := IsPlainConditionalIdentifier(Copy(lText, 7, MaxInt).Trim) and
        IsConditionalStateKnown(aDefines, Copy(lText, 7, MaxInt), aContext.Capture);
      if not lKnown then
        AddDiagnostic(aDiagnostics, 'UNVERIFIED_PREPROCESS_CONDITION',
          'Conditional symbol has no verified definition state: ' + aDirective,
          aFileName, aLine);
      PushConditionalFrame(aStack, IsDefined(aDefines, Copy(lText, 7, MaxInt)), lKnown);
      Exit(True);
    end;

    if StartsText('IFNDEF ', lText) then
    begin
      lKnown := IsPlainConditionalIdentifier(Copy(lText, 8, MaxInt).Trim) and
        IsConditionalStateKnown(aDefines, Copy(lText, 8, MaxInt), aContext.Capture);
      if not lKnown then
        AddDiagnostic(aDiagnostics, 'UNVERIFIED_PREPROCESS_CONDITION',
          'Conditional symbol has no verified definition state: ' + aDirective,
          aFileName, aLine);
      PushConditionalFrame(aStack, not IsDefined(aDefines, Copy(lText, 8, MaxInt)), lKnown);
      Exit(True);
    end;

    if StartsText('IF ', lText) then
    begin
      lKnown := TryEvaluateIfExpression(Copy(lText, 4, MaxInt), aDefines, lActive, True,
        aContext.Capture);
      if not lKnown then
        AddDiagnostic(aDiagnostics, 'UNVERIFIED_PREPROCESS_CONDITION',
          'Conditional expression has no verified symbol state: ' + aDirective,
          aFileName, aLine);
      if lKnown then
        PushConditionalFrame(aStack, lActive, True)
      else if TryEvaluateIfExpression(Copy(lText, 4, MaxInt), aDefines, lActive) then
        PushConditionalFrame(aStack, lActive, False)
      else
      begin
        AddDiagnostic(aDiagnostics, 'UNSUPPORTED_PREPROCESS_DIRECTIVE',
          'Unsupported conditional directive: ' + aDirective, aFileName, aLine);
        PushUnsupportedConditionalFrame(aStack);
        Exit(True);
      end;
      Exit(True);
    end;

    if StartsText('DEFINE ', lText) then
    begin
      // A possible DEFINE/UNDEF (including one in an unknown include) taints later
      // conditions on that symbol. Only a known-active assignment restores certainty.
      if CurrentActivity(aStack) <> saInactive then
        aContext.Capture.UnknownSymbols.AddOrSetValue(DefineKey(Copy(lText, 8, MaxInt)),
          CurrentActivity(aStack) = saUnknown);
      if CurrentActive(aStack) then
        aDefines.AddOrSetValue(DefineKey(Copy(lText, 8, MaxInt)), True);
      Exit(True);
    end;

    if StartsText('UNDEF ', lText) then
    begin
      if CurrentActivity(aStack) <> saInactive then
        aContext.Capture.UnknownSymbols.AddOrSetValue(DefineKey(Copy(lText, 7, MaxInt)),
          CurrentActivity(aStack) = saUnknown);
      if CurrentActive(aStack) then
        aDefines.AddOrSetValue(DefineKey(Copy(lText, 7, MaxInt)), False);
      Exit(True);
    end;

    if StartsText('ELSEIF ', lText) then
    begin
      if aStack.Count = 0 then
      begin
        aContext.Capture.ActivityComplete := False;
        AddDiagnostic(aDiagnostics, 'UNMATCHED_PREPROCESS_DIRECTIVE',
          'Unmatched conditional directive: ' + aDirective, aFileName, aLine);
        Exit(False);
      end;

      lKnown := TryEvaluateIfExpression(Copy(lText, 8, MaxInt), aDefines, lActive, True,
        aContext.Capture);
      if not lKnown then
        AddDiagnostic(aDiagnostics, 'UNVERIFIED_PREPROCESS_CONDITION',
          'Conditional expression has no verified symbol state: ' + aDirective,
          aFileName, aLine);
      if lKnown then
        UpdateElseIfFrame(aStack, lActive, True)
      else if TryEvaluateIfExpression(Copy(lText, 8, MaxInt), aDefines, lActive) then
        UpdateElseIfFrame(aStack, lActive, False)
      else
      begin
        AddDiagnostic(aDiagnostics, 'UNSUPPORTED_PREPROCESS_DIRECTIVE',
          'Unsupported conditional directive: ' + aDirective, aFileName, aLine);
        DisableUnsupportedConditionalFrame(aStack);
        Exit(True);
      end;
      Exit(True);
    end;

    if SameText(lText, 'ELSE') or StartsText('ELSE ', lText) then
    begin
      if aStack.Count = 0 then
      begin
        aContext.Capture.ActivityComplete := False;
        AddDiagnostic(aDiagnostics, 'UNMATCHED_PREPROCESS_DIRECTIVE',
          'Unmatched conditional directive: ' + aDirective, aFileName, aLine);
        Exit(False);
      end;

      UpdateElseFrame(aStack);
      Exit(True);
    end;

    if SameText(lText, 'ENDIF') or StartsText('ENDIF ', lText) or SameText(lText, 'IFEND') or
      StartsText('IFEND ', lText) then
    begin
      if aStack.Count = 0 then
      begin
        aContext.Capture.ActivityComplete := False;
        AddDiagnostic(aDiagnostics, 'UNMATCHED_PREPROCESS_DIRECTIVE',
          'Unmatched conditional directive: ' + aDirective, aFileName, aLine);
        Exit(False);
      end;

      aStack.Delete(Pred(aStack.Count));
      Exit(True);
    end;

    lIncludeName := IncludeArgumentFromDirective(lText);
    if lIncludeName <> '' then
    begin
      if CurrentActivity(aStack) = saInactive then
        Exit(True);
      lEmitInclude := CurrentActive(aStack);

      if not ResolveIncludeFileName(lIncludeName, TPath.GetDirectoryName(aFileName), aOptions,
        lIncludeFileName) then
      begin
        AddDiagnostic(aDiagnostics, 'INCLUDE_FILE_NOT_FOUND', 'Include file not found: ' +
          lIncludeName, aFileName, aLine);
        if CurrentActivity(aStack) = saUnknown then
        begin
          // A possible include may define any symbol; keep its local uncertainty and taint
          // later conditions, rather than discarding the whole unit's activity evidence.
          aContext.Capture.UnknownSymbols.Clear;
          aContext.Capture.AllSymbolsUnknown := True;
          Exit(True);
        end;
        aContext.Capture.ActivityComplete := False;
        Exit(False);
      end;

      lInclude.FileName := lIncludeFileName;
      if not TryLoadPreprocessSource(lIncludeFileName, aSourceCache, aDiagnostics,
        lIncludeText) then
      begin
        if CurrentActivity(aStack) = saUnknown then
        begin
          aContext.Capture.UnknownSymbols.Clear;
          aContext.Capture.AllSymbolsUnknown := True;
          Exit(True);
        end;
        aContext.Capture.ActivityComplete := False;
        Exit(False);
      end;
      lInclude.ContentHash := CalculateTextHash(lIncludeText);
      aIncludes.Add(lInclude);
      lSuccess := True;
      lIncludeOutput := TStringBuilder.Create;
      lDiscardOrigins := nil;
      lOrigins := aOrigins;
      if not lEmitInclude then
      begin
        // Walk possible includes for their symbol effects without inventing AST output.
        lDiscardOrigins := TLineOriginList.Create;
        lOrigins := lDiscardOrigins;
      end;
      try
        lIncludeContext := aContext;
        lIncludeContext.BaseOffset := aContext.BaseOffset + aOutput.Length;
        lIncludeContext.ExpansionId := aContext.Capture.NewExpansionId;
        ProcessLoadedSourceFile(lIncludeFileName, lIncludeText, aOptions, aDefines,
          aStack, aDiagnostics, lIncludeOutput, aRegions, aIncludes, aIncludeStack,
          aSourceCache, lOrigins, lIncludeContext, lSuccess);
        if lEmitInclude then
        begin
          aOutput.Append(lIncludeOutput.ToString);
          aOutputLineWritten := True;
        end;
      finally
        lDiscardOrigins.Free;
        lIncludeOutput.Free;
      end;
      Exit(lSuccess);
    end;

    if StartsText('IFOPT ', lText) then
    begin
      AddDiagnostic(aDiagnostics, 'UNSUPPORTED_PREPROCESS_DIRECTIVE',
        'Unsupported conditional directive: ' + aDirective, aFileName, aLine);
      PushUnsupportedConditionalFrame(aStack);
      Exit(False);
    end;

    if IsCompilerSwitchDirective(lText) then
    begin
      if CurrentActive(aStack) then
      begin
        aOutput.AppendLine('{$' + lText + '}');
        AddLineOrigin(aOrigins, aFileName, aLine);
        aOutputLineWritten := True;
      end;
      Exit(True);
    end;

    // An unmodeled directive may affect later conditions. It cannot erase already
    // classified source regions and thereby make our selected AST branch into proof.
    if CurrentActivity(aStack) <> saInactive then
    begin
      aContext.Capture.UnknownSymbols.Clear;
      aContext.Capture.AllSymbolsUnknown := True;
    end;
    AddDiagnostic(aDiagnostics, 'UNSUPPORTED_PREPROCESS_DIRECTIVE',
      'Unsupported preprocessing directive: ' + aDirective, aFileName, aLine);
    Exit(False);
  finally
    // Observe even empty unknown branches before their frame is popped.
    if CurrentActivity(aStack) = saUnknown then
      aContext.Capture.HasUnknownActivity := True;
  end;
end;

function CreateDefineMap(const aDefines: TArray<string>): TDefineMap;
var
  lDefine: string;
begin
  Result := TDefineMap.Create;
  for lDefine in aDefines do
    if lDefine.Trim <> '' then
      Result.AddOrSetValue(DefineKey(lDefine), True);
end;

function CalculateIncludeGraphHash(const aIncludes: TList<TDelphiSemanticIncludeFile>): string;
var
  lInclude: TDelphiSemanticIncludeFile;
  lText: string;
begin
  lText := '';
  for lInclude in aIncludes do
    lText := lText + lInclude.FileName + '=' + lInclude.ContentHash + ';';

  Result := CalculateTextHash(lText);
end;

class function TDelphiSemanticPreprocessor.PreprocessFile(
  const aOptions: TDelphiSemanticPreprocessOptions): TDelphiSemanticPreprocessResult;
var
  lCapture: TPreprocessCapture;
  lContext: TPreprocessOutputContext;
  lDefines: TDefineMap;
  lDiagnostics: TList<TDelphiSemanticPreprocessDiagnostic>;
  lIncludeStack: TList<string>;
  lIncludes: TList<TDelphiSemanticIncludeFile>;
  lOrigins: TLineOriginList;
  lOutput: TStringBuilder;
  lRegions: TList<TDelphiSemanticSourceRegion>;
  lSourceCache: TSourceTextCache;
  lSourceLoad: TDelphiSemanticSourceLoadResult;
  lCombined: IDelphiSemanticSourceObservations;
  lObservationError: string;
  lStack: TList<TPreprocessFrame>;
  lSuccess: Boolean;
begin
  Result := Default(TDelphiSemanticPreprocessResult);
  lCapture := nil;
  lDefines := nil;
  lDiagnostics := nil;
  lIncludes := nil;
  lIncludeStack := nil;
  lOrigins := nil;
  lOutput := nil;
  lRegions := nil;
  lSourceCache := nil;
  lStack := nil;
  try
    lCapture := TPreprocessCapture.Create;
    lDefines := CreateDefineMap(aOptions.Defines);
    lDiagnostics := TList<TDelphiSemanticPreprocessDiagnostic>.Create;
    lIncludes := TList<TDelphiSemanticIncludeFile>.Create;
    lIncludeStack := TList<string>.Create;
    lOrigins := TLineOriginList.Create;
    lOutput := TStringBuilder.Create;
    lRegions := TList<TDelphiSemanticSourceRegion>.Create;
    lSourceCache := TSourceTextCache.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
    lStack := TList<TPreprocessFrame>.Create;

    lContext.Capture := lCapture;
    lContext.BaseOffset := 0;
    lContext.ExpansionId := lCapture.NewExpansionId;

    lSuccess := True;
    ProcessSourceFile(TPath.GetFullPath(aOptions.SourceFileName), aOptions, lDefines, lStack,
      lDiagnostics, lOutput, lRegions, lIncludes, lIncludeStack, lSourceCache, lOrigins,
      lContext, lSuccess);
    if lStack.Count > 0 then
    begin
      lCapture.ActivityComplete := False;
      AddDiagnostic(lDiagnostics, 'UNTERMINATED_PREPROCESS_CONDITIONAL',
        'Unterminated conditional directive stack.', aOptions.SourceFileName, 0);
      lSuccess := False;
    end;
    for lSourceLoad in lSourceCache.Values do
      if Result.SourceObservations = nil then
        Result.SourceObservations := lSourceLoad.SourceObservations
      else if TDelphiSemanticSourceEvidence.TryMerge(Result.SourceObservations,
        lSourceLoad.SourceObservations, lCombined, lObservationError) then
        Result.SourceObservations := lCombined
      else begin
        AddDiagnostic(lDiagnostics, lObservationError,
          'Source bytes changed during preprocessing.', aOptions.SourceFileName, 0);
        Result.SourceObservations := nil;
        lCapture.ActivityComplete := False;
        lSuccess := False;
        Break;
      end;
    Result.Success := lSuccess;
    Result.OutputText := lOutput.ToString;
    Result.IncludeGraphHash := CalculateIncludeGraphHash(lIncludes);
    Result.Regions := lRegions.ToArray;
    Result.Includes := lIncludes.ToArray;
    Result.LineOrigins := lOrigins.ToArray;
    Result.CopiedSourceSpans := lCapture.Spans.ToArray;
    Result.ActivitySpans := lCapture.ActivitySpans.ToArray;
    Result.HasUnknownActivity := lCapture.HasUnknownActivity;
    Result.ActivityEvidenceAvailable := lCapture.ActivityComplete;
    Result.Diagnostics := lDiagnostics.ToArray;
  finally
    lCapture.Free;
    lStack.Free;
    lSourceCache.Free;
    lRegions.Free;
    lOutput.Free;
    lIncludeStack.Free;
    lOrigins.Free;
    lIncludes.Free;
    lDiagnostics.Free;
    lDefines.Free;
  end;
end;

end.
