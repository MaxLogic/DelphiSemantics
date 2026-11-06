unit Test.Preprocess;

interface

uses
  DUnitX.TestFramework,
  DelphiSemantics.Preprocess;

type
  [TestFixture]
  TPreprocessTests = class
  private
    function HasDiagnostic(const aResult: TDelphiSemanticPreprocessResult;
      const aCode: string): Boolean;
    function HasRegion(const aResult: TDelphiSemanticPreprocessResult; const aLine: Integer;
      const aActive: Boolean): Boolean;
  public
    [Category('Fast')]
    [TestCase('IFDEF', 'ifdef')]
    [TestCase('IFNDEF', 'ifndef')]
    [TestCase('Defined expression', 'defined')]
    [TestCase('ELSEIF', 'elseif')]
    procedure IncompleteDefinesMakeAbsentOrdinaryUnknown(const aShape: string);

    [Category('Fast')]
    [TestCase('Declaration absent from AST', 'declaration')]
    [TestCase('Conditional uses absent from AST', 'imports')]
    [TestCase('Empty unknown arm', 'empty')]
    [TestCase('Scanner only declaration', 'scan-declaration')]
    [TestCase('Scanner only imports', 'scan-imports')]
    [TestCase('Text-only uses entry point', 'text-imports')]
    procedure IncompleteDefinesOpenDeclarationAndImportFacts(const aShape: string);

    [Category('Fast')]
    [Test]
    procedure KnownActiveWriteRestoresScannerCertainty;
    [Category('Fast')]
    [TestCase('Less than inactive', 'a<b.inc,False')]
    [TestCase('Pipe active', 'a|b.inc,True')]
    procedure InvalidIncludeIsUnresolved(const aName: string; const aActive: Boolean);
    [Category('Fast')]
    [TestCase('Less than', 'a<b.inc')]
    [TestCase('Pipe', 'a|b.inc')]
    procedure InvalidIncludeCannotProveImportOrder(const aName: string);

    [Category('Fast')]
    [Test]
    procedure RepeatedIncludeUsesItsOwnActivityInstance;

    [Category('Fast')]
    [TestCase('Uses include', 'uses')]
    [TestCase('Declaration include', 'declaration')]
    [TestCase('Outside dependency spans', 'outside')]
    [TestCase('Include closes parent conditional', 'cross-endif')]
    procedure IncludeSpanRequiresCallerEvidence(const aShape: string);

    [Category('Fast')]
    [TestCase('IFDEF after unknown DEFINE', 'ifdef')]
    [TestCase('IF Defined after unknown DEFINE', 'defined')]
    [TestCase('IFNDEF after unknown UNDEF', 'ifndef')]
    [TestCase('ELSEIF after unknown DEFINE', 'elseif')]
    [TestCase('Nested DEFINE', 'nested')]
    [TestCase('DEFINE from include', 'include-define')]
    [TestCase('Conditional in include', 'include-condition')]
    procedure UnknownDirectiveSymbolTaintsLaterImports(const aShape: string);

    [Category('Fast')]
    [Test]
    procedure NestedIncludesUseUnitDirectoryBeforeSearchPaths;
    [Category('Fast')]
    [Test]
    procedure UnprovedIncludePathIsNotASkippedIncludeDirectory;

    [Category('Fast')]
    [TestCase('Triple quoted with apostrophe', '3')]
    [TestCase('Five quoted with shorter quote run', '5')]
    procedure MultilineStringsCannotHideFollowingDirectives(const aQuotes: Integer);

    [Category('Fast')]
    [Test]
    procedure ActivityEvidenceCoversGapsAndInclusiveEnd;
    [Category('Fast')]
    [Test]
    procedure ActiveDefinesSelectExpectedConditionalRegions;
    [Category('Fast')]
    [Test]
    procedure MissingPossibleIncludeKeepsTheModelAndTaintsLaterConditions;
    [Category('Fast')]
    [TestCase('Earlier UNDEF invalidated', 'False')]
    [TestCase('Later UNDEF restores witness', 'True')]
    procedure GlobalTaintInvalidatesEarlierWitness(const aRestore: Boolean);
    [Category('Fast')]
    [Test]
    procedure InvalidActivitySpanNeverDiscardsUncertainty;
    [Category('Fast')]
    [Test]
    procedure PlainActivityBuilderWithoutRootWitnessRetainsUncertainty;
    [Category('Fast')]
    [TestCase('OR known true left', 'or-true')]
    [TestCase('AND known false left', 'and-false')]
    [TestCase('OR known true right', 'or-right')]
    [TestCase('AND known false right', 'and-right')]
    [TestCase('OR unknown', 'or-unknown')]
    [TestCase('AND unknown', 'and-unknown')]
    [TestCase('Bare identifier is a constant', 'bare')]
    [TestCase('Malformed IFDEF', 'ifdef')]
    [TestCase('Malformed IFNDEF', 'ifndef')]
    procedure ConditionalExpressionsRetainTriStateShortCircuit(const aShape: string);
    [Category('Fast')]
    [Test]
    [TestCase('Certified ordinary absent', 'complete-ordinary')]
    [TestCase('Certified framework absent', 'complete-framework')]
    [TestCase('BCB without predefined witness', 'bcb')]
    [TestCase('BCB witnessed absent', 'bcb-false')]
    [TestCase('Ordinary absent', 'ordinary')]
    [TestCase('Ordinary Defined expression', 'ordinary-defined')]
    [TestCase('Ordinary IFNDEF', 'ordinary-ifndef')]
    [TestCase('Unicode absent', 'unicode')]
    [TestCase('Defined Unicode absent', 'unicode-defined')]
    [TestCase('Version family absent', 'version')]
    [TestCase('Framework absent', 'framework')]
    [TestCase('Simulator absent', 'IOSSIMULATOR')]
    [TestCase('iOS32 absent', 'IOS32')]
    [TestCase('OSX32 absent', 'OSX32')]
    [TestCase('Managed records compiler symbol', 'MANAGED_RECORD')]
    [TestCase('Weak nativeint compiler symbol', 'WEAK_NATIVEINT')]
    [TestCase('LLVM compiler symbol', 'LLVM')]
    [TestCase('Captured Unicode', 'captured')]
    [TestCase('Source undef overrides captured Unicode', 'undef')]
    procedure ConditionalStateDistinguishesOrdinaryAndCompilerSymbols(const aShape: string);

    [Category('Fast')]
    [Test]
    procedure DefineAndUndefDirectivesAffectLaterRegions;
    [Category('Fast')]
    [Test]
    procedure IncludesResolveFromSearchPathsAndAffectGraphHash;
    [Category('Fast')]
    [Test]
    procedure IncludeHashUsesLoadedIncludeText;
    [Category('Fast')]
    [Test]
    procedure IncludeCyclesProduceDeterministicDiagnostic;
    [Category('Fast')]
    [Test]
    procedure MalformedConditionalStackProducesDiagnostics;
    [Category('Fast')]
    [Test]
    procedure ConditionalDirectivesAllowTrailingComments;
    [Category('Fast')]
    [Test]
    procedure ConditionalDirectivesAllowLegacyMultilineCloseBrace;
    [Category('Fast')]
    [Test]
    procedure CompilerSwitchDirectivesDoNotFailPreprocessing;
    [Category('Fast')]
    [Test]
    [TestCase('External symbol metadata', '0,True')]
    [TestCase('C++ header text', '1,True')]
    [TestCase('C++ header type exclusion', '2,True')]
    [TestCase('Object type name metadata', '3,True')]
    [TestCase('Grouped short switches', '4,True')]
    [TestCase('Unknown directive', '5,False')]
    [TestCase('Mixed group with unknown item', '6,False')]
    [TestCase('Metadata name lookalike', '7,False')]
    [TestCase('Trailing group separator', '8,False')]
    [TestCase('C++ closing brace in parenthesized directive', '9,True')]
    [TestCase('Indented parenthesized switch group', '10,True')]
    procedure RtlMetadataAndSwitchGroupsPreservePascalSource(const aCase: Integer;
      const aSuccess: Boolean);
    [Category('Fast')]
    [Test]
    procedure DirectivesInsideLineCommentsAreIgnored;
    [Category('Fast')]
    [Test]
    [TestCase('Brace text inside block comment', '0')]
    [TestCase('Parenthesized text inside brace comment', '1')]
    [TestCase('Directive text inside escaped string', '2')]
    procedure DirectiveLookalikesPreserveSource(const aCase: Integer);
    [Category('Fast')]
    [Test]
    [TestCase('Parenthesized comment', '0')]
    [TestCase('Brace comment', '1')]
    procedure CommentSlashesDoNotHideFollowingDirective(const aCase: Integer);
    [Category('Fast')]
    [Test]
    procedure InlineConditionalDirectivesCloseOnSameLine;
    [Category('Fast')]
    [Test]
    procedure Linux64ProjectConditionalsUseTargetDefines;
    [Category('Fast')]
    [Test]
    procedure UnsupportedConditionalElseBranchStaysInactive;
    [Category('Fast')]
    [Test]
    procedure UnsupportedConditionalDirectiveProducesDiagnostic;
  end;

implementation

uses
  System.IOUtils, System.StrUtils, System.SysUtils,
  Winapi.Windows,
  maxLogic.IOUtils,
  DelphiSemantics.Model, DelphiSemantics.Model.Extract, DelphiSemantics.ProjectContext,
  DelphiSemantics.SourceConditionals,
  Test.Support;

function PreprocessTempRoot(const aName: string): string;
begin
  Result := TPath.Combine(CreateTestTempRoot('preprocess-temp'), aName);
  TDirectory.CreateDirectory(Result);
end;


procedure TPreprocessTests.KnownActiveWriteRestoresScannerCertainty;
var
  lOptions: TDelphiSemanticPreprocessOptions;
  lResult: TDelphiSemanticPreprocessResult;
begin
  lOptions := Default(TDelphiSemanticPreprocessOptions);
  lOptions.SourceFileName := TPath.Combine(PreprocessTempRoot('scanner-recovery'), 'Unit1.pas');
  lOptions.SourceText := 'unit Unit1; interface {$IFDEF HIDDEN}{$DEFINE FLAG}{$ENDIF}' +
    '{$DEFINE FLAG}uses Always {$IFDEF FLAG}, Conditional{$ENDIF}; implementation end.';
  lResult := TDelphiSemanticPreprocessor.PreprocessFile(lOptions);
  Assert.IsTrue(lResult.Success);
  Assert.IsFalse(lResult.DirectiveFacts.ImportsUnproved,
    'A known-active assignment recovers the symbol after an earlier uncertain write.');
end;

procedure TPreprocessTests.RepeatedIncludeUsesItsOwnActivityInstance;
var
  lOptions: TDelphiSemanticPreprocessOptions;
  lResult: TDelphiSemanticPreprocessResult;
  lRoot: string;
  lIncludeSpans: Integer;
begin
  lRoot := PreprocessTempRoot('repeat-instance');
  TFile.WriteAllText(TPath.Combine(lRoot, 'field.inc'),
    '{$IFDEF FEATURE}Count: Integer;{$ENDIF}', TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticPreprocessOptions);
  lOptions.SourceFileName := TPath.Combine(lRoot, 'Unit1.pas');
  lOptions.SourceText := '{$UNDEF FEATURE}{$I field.inc}' +
    '{$IFDEF UNKNOWN_FEATURE}{$DEFINE FEATURE}{$ENDIF}{$I field.inc}';
  lResult := TDelphiSemanticPreprocessor.PreprocessFile(lOptions);
  Assert.IsTrue(lResult.Success);
  lIncludeSpans := 0;
  for var lSpan in lResult.DirectiveFacts.Spans do
    if SameText(lSpan.StartFileName, TPath.Combine(lRoot, 'field.inc')) then
      Inc(lIncludeSpans);
  Assert.AreEqual(1, lIncludeSpans, 'Only the second include expansion has an unknown conditional.');
  Assert.IsTrue(lResult.DirectiveFacts.NameCause('Count') <> '',
    'An earlier inactive expansion cannot hide a later possible member.');
end;

procedure TPreprocessTests.IncompleteDefinesMakeAbsentOrdinaryUnknown(const aShape: string);
var
  lOptions: TDelphiSemanticPreprocessOptions;
  lResult: TDelphiSemanticPreprocessResult;
  lDirective, lEvidence: string;
begin
  lOptions := Default(TDelphiSemanticPreprocessOptions);
  lOptions.SourceFileName := TPath.Combine(PreprocessTempRoot('incomplete-' + aShape), 'Unit1.pas');
  lDirective := '{$IFDEF REVIEW_FEATURE}';
  if aShape = 'ifndef' then
    lDirective := '{$IFNDEF REVIEW_FEATURE}'
  else if aShape = 'defined' then
    lDirective := '{$IF Defined(REVIEW_FEATURE)}'
  else if aShape = 'elseif' then
    lDirective := '{$UNDEF CLOSED}{$IFDEF CLOSED}Excluded;{$ELSEIF Defined(REVIEW_FEATURE)}';
  lOptions.SourceText := lDirective + 'Possible;{$ELSE}Alternative;{$ENDIF}';
  lResult := TDelphiSemanticPreprocessor.PreprocessFile(lOptions);
  Assert.IsTrue(lResult.Success);
  Assert.IsTrue(lResult.ActivityEvidenceAvailable);
  lEvidence := TDelphiSemanticSourceConditionals.EncodeActivity(lOptions.SourceText,
    lOptions.SourceFileName, lResult.ActivitySpans);
  Assert.IsTrue(TDelphiSemanticSourceConditionals.UnknownAtOffset(lOptions.SourceText,
    lEvidence, Pos('Possible;', lOptions.SourceText)), 'An uncaptured ordinary define is unknown.');
  Assert.IsTrue(TDelphiSemanticSourceConditionals.UnknownAtOffset(lOptions.SourceText,
    lEvidence, Pos('Alternative;', lOptions.SourceText)), 'The opposite reachable arm is also unknown.');
  Assert.IsTrue(HasDiagnostic(lResult, 'UNVERIFIED_PREPROCESS_CONDITION'));
end;

procedure TPreprocessTests.InvalidIncludeCannotProveImportOrder(const aName: string);
begin
  Assert.IsTrue(TDelphiSemanticSourceConditionals.ImportOrderUnknown(
    'unit Unit1; interface uses {$I ' + aName + '} System.SysUtils; implementation end.',
    '', [], ['System.SysUtils']), 'An unresolved include cannot prove import order.');
end;

procedure TPreprocessTests.InvalidIncludeIsUnresolved(const aName: string; const aActive: Boolean);
var
  lOptions: TDelphiSemanticPreprocessOptions;
  lResult: TDelphiSemanticPreprocessResult;
  lResolved: string;
begin
  lOptions := Default(TDelphiSemanticPreprocessOptions);
  lOptions.SourceFileName := TPath.Combine(PreprocessTempRoot('invalid-include'), 'Unit1.pas');
  Assert.IsFalse(TDelphiSemanticPreprocessor.ResolveIncludeFileName(aName,
    TPath.GetDirectoryName(lOptions.SourceFileName), lOptions, lResolved));
  Assert.AreEqual('', lResolved);
  lOptions.SourceText := '{$I ' + aName + '}';
  if not aActive then
  begin
    lOptions.DefineEvidenceComplete := True;
    lOptions.SourceText := '{$IFDEF NEVER_X}' + lOptions.SourceText + '{$ENDIF}';
  end;
  lResult := TDelphiSemanticPreprocessor.PreprocessFile(lOptions);
  Assert.IsTrue(HasDiagnostic(lResult, 'INCLUDE_FILE_NOT_FOUND'),
    'Invalid include names retain a named diagnostic even when known inactive.');
  if not aActive then
    Assert.IsTrue(lResult.Success, 'An inactive unresolved include must retain the model.');
end;

procedure TPreprocessTests.IncompleteDefinesOpenDeclarationAndImportFacts(const aShape: string);
var
  lOptions: TDelphiSemanticPreprocessOptions;
  lResult: TDelphiSemanticPreprocessResult;
  lFacts: TDelphiSemanticDirectiveFacts;
  lBody: string;
begin
  lOptions := Default(TDelphiSemanticPreprocessOptions);
  lOptions.SourceFileName := TPath.Combine(PreprocessTempRoot('facts-' + aShape), 'Unit1.pas');
  lBody := 'type TPossible = record Count: Integer; end;';
  if ContainsText(aShape, 'imports') then
    lBody := 'uses PossibleHelper;'
  else if aShape = 'empty' then
    lBody := '';
  lOptions.SourceText := 'unit Unit1; interface {$IFDEF REVIEW_FEATURE}' + lBody +
    '{$ELSE}{$ENDIF} implementation end.';
  if StartsText('text-', aShape) then
  begin
    Assert.IsTrue(TDelphiSemanticSourceConditionals.UsesDirectiveUnproved(lOptions.SourceText));
    lOptions.SourceFileName := '';
  end;
  if StartsText('scan-', aShape) or StartsText('text-', aShape) then
    lFacts := TDelphiSemanticPreprocessor.ScanDirectiveFacts(lOptions)
  else begin
    lResult := TDelphiSemanticPreprocessor.PreprocessFile(lOptions);
    Assert.IsTrue(lResult.Success);
    lFacts := lResult.DirectiveFacts;
  end;
  Assert.IsTrue(Length(lFacts.Spans) > 0, 'Even an empty unknown arm retains a directive span.');
  if ContainsText(aShape, 'imports') then
  begin
    Assert.IsTrue(lFacts.ImportsUnproved, 'A possible import omitted from the AST is not absent.');
    Assert.IsTrue(lFacts.NameCause('PossibleHelper') <> '');
  end else if aShape <> 'empty' then
  begin
    Assert.IsTrue(lFacts.NameCause('Count') <> '', 'A conditional member cannot prove absence.');
    Assert.IsTrue(lFacts.NameCause('TPossible') <> '');
  end;
end;

procedure TPreprocessTests.IncludeSpanRequiresCallerEvidence(const aShape: string);
var
  lFacts: TDelphiSemanticDirectiveFacts;
  lOptions: TDelphiSemanticPreprocessOptions;
  lRoot, lChild: string;
begin
  lRoot := PreprocessTempRoot('caller-include-' + aShape);
  lOptions := Default(TDelphiSemanticPreprocessOptions);
  lOptions.SourceFileName := TPath.Combine(lRoot, 'Unit1.pas');
  lOptions.SearchPaths := ['<include-path-unproved>'];
  lChild := 'TSelected = record Value: Integer; end;';
  if aShape = 'uses' then
  begin
    lOptions.SourceText := 'unit Unit1; interface uses A {$I child.inc}; implementation end.';
    lChild := ', C';
  end else if aShape = 'cross-endif' then
  begin
    lOptions.SourceText := 'unit Unit1; interface type {$IFDEF FLAG}{$I child.inc} implementation end.';
    lChild := '{$ENDIF}' + lChild;
  end else if aShape = 'declaration' then
    lOptions.SourceText := 'unit Unit1; interface type {$I child.inc} implementation end.'
  else begin
    lOptions.SourceText := 'unit Unit1; interface type TSelected = Integer; implementation ' +
      'procedure Run; begin {$I child.inc} end; end.';
    lChild := 'Writeln(1);';
  end;
  TFile.WriteAllText(TPath.Combine(lRoot, 'child.inc'), lChild, TEncoding.ASCII);
  lFacts := TDelphiSemanticPreprocessor.ScanDirectiveFacts(lOptions);
  Assert.IsFalse(lFacts.UnitUnproved, 'A local include has a bounded expansion.');
  if aShape = 'uses' then
    Assert.AreEqual('IMPORTS_DIRECTIVE_UNPROVED', lFacts.ImportCause)
  else if (aShape = 'declaration') or (aShape = 'cross-endif') then
    Assert.AreEqual('DECLARATIONS_DIRECTIVE_UNPROVED', lFacts.NameCause('TSelected'))
  else begin
    Assert.AreEqual('', lFacts.ImportCause);
    Assert.AreEqual('', lFacts.NameCause('TSelected'));
  end;
end;

procedure TPreprocessTests.UnknownDirectiveSymbolTaintsLaterImports(const aShape: string);
var
  lOptions: TDelphiSemanticPreprocessOptions;
  lFacts: TDelphiSemanticDirectiveFacts;
  lPrefix, lCondition, lRoot: string;
begin
  lRoot := PreprocessTempRoot('symbol-taint-' + aShape);
  lOptions := Default(TDelphiSemanticPreprocessOptions);
  lOptions.SourceFileName := TPath.Combine(lRoot, 'Unit1.pas');
  lPrefix := '{$IFOPT R-}{$DEFINE USEC}{$ENDIF}';
  lCondition := '{$IFDEF USEC}, C{$ENDIF}';
  if aShape = 'defined' then
    lCondition := '{$IF Defined(USEC)}, C{$IFEND}'
  else if aShape = 'ifndef' then
  begin
    lPrefix := '{$DEFINE NOC}{$IFOPT R-}{$UNDEF NOC}{$ENDIF}';
    lCondition := '{$IFNDEF NOC}, C{$ENDIF}';
  end else if aShape = 'elseif' then
    lCondition := '{$IF False}{$ELSEIF Defined(USEC)}, C{$IFEND}'
  else if aShape = 'nested' then
    lPrefix := '{$IFOPT R-}{$IFDEF WIN64}{$DEFINE USEC}{$ENDIF}{$ENDIF}'
  else if aShape = 'include-define' then
  begin
    TFile.WriteAllText(TPath.Combine(lRoot, 'd.inc'), lPrefix, TEncoding.ASCII);
    lPrefix := '{$I d.inc}';
  end else if aShape = 'include-condition' then
  begin
    TFile.WriteAllText(TPath.Combine(lRoot, 'c.inc'), lCondition, TEncoding.ASCII);
    lCondition := '{$I c.inc}';
  end;
  lOptions.SourceText := 'unit Unit1;'#13#10'interface'#13#10 + lPrefix +
    #13#10'uses A ' + lCondition + ';'#13#10'implementation'#13#10'end.';
  lFacts := TDelphiSemanticPreprocessor.ScanDirectiveFacts(lOptions);
  Assert.IsTrue(lFacts.Scanned);
  Assert.IsTrue(lFacts.ImportsUnproved,
    'An unknown write must taint every later conditional on that symbol.');
  Assert.IsFalse(lFacts.UnitUnproved, 'The span is bounded; keep the precise import cause.');
end;

procedure TPreprocessTests.UnprovedIncludePathIsNotASkippedIncludeDirectory;
var
  lOptions: TDelphiSemanticPreprocessOptions;
  lResult: TDelphiSemanticPreprocessResult;
begin
  lOptions := Default(TDelphiSemanticPreprocessOptions);
  lOptions.SourceFileName := TPath.Combine(PreprocessTempRoot('unproved-skipped'), 'Unit1.pas');
  lOptions.SourceText := 'unit Unit1; interface {$IFDEF ABSENT}{$I missing.inc}{$ENDIF} implementation end.';
  lOptions.SearchPaths := ['<include-path-unproved>'];
  lResult := TDelphiSemanticPreprocessor.PreprocessFile(lOptions);
  Assert.IsTrue(lResult.Success, 'An inactive include with unavailable search evidence must not raise.');
  Assert.AreEqual<Integer>(0, Length(lResult.Includes));
end;

procedure TPreprocessTests.NestedIncludesUseUnitDirectoryBeforeSearchPaths;
var
  lOptions: TDelphiSemanticPreprocessOptions;
  lResult: TDelphiSemanticPreprocessResult;
  lFacts: TDelphiSemanticDirectiveFacts;
  lRoot: string;
begin
  lRoot := PreprocessTempRoot('nested-include-order');
  TDirectory.CreateDirectory(TPath.Combine(lRoot, 'sub'));
  TFile.WriteAllText(TPath.Combine(lRoot, 'sub\c.inc'), '{$I d.inc}', TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'sub\d.inc'), ' ', TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'd.inc'), '{$IFOPT R-}, C{$ENDIF}', TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticPreprocessOptions);
  lOptions.SourceFileName := TPath.Combine(lRoot, 'Unit1.pas');
  lOptions.SourceText := 'unit Unit1;'#13#10'interface'#13#10 +
    'uses A {$I sub\c.inc};'#13#10'implementation'#13#10'end.';
  lFacts := TDelphiSemanticPreprocessor.ScanDirectiveFacts(lOptions);
  Assert.IsTrue(lFacts.ImportsUnproved, 'The compiler reads the unit-directory d.inc.');
  lResult := TDelphiSemanticPreprocessor.PreprocessFile(lOptions);
  Assert.AreEqual(2, Integer(Length(lResult.Includes)));
  Assert.AreEqual(TPath.Combine(lRoot, 'd.inc'), lResult.Includes[1].FileName);
end;

procedure TPreprocessTests.MultilineStringsCannotHideFollowingDirectives(const aQuotes: Integer);
var
  lOptions: TDelphiSemanticPreprocessOptions;
  lFacts: TDelphiSemanticDirectiveFacts;
  lDelimiter: string;
begin
  lOptions := Default(TDelphiSemanticPreprocessOptions);
  lOptions.SourceFileName := TPath.Combine(PreprocessTempRoot('multiline-directive'), 'Unit1.pas');
  lDelimiter := StringOfChar(#39, aQuotes);
  lOptions.SourceText := 'unit Unit1;'#13#10'interface'#13#10'const S = ' +
    lDelimiter + #13#10'  it' + #39 + 's'#13#10 +
    '  ' + lDelimiter + ';'#13#10'implementation'#13#10 +
    'uses A {$IFOPT R-}, C{$ENDIF};'#13#10'end.';
  lFacts := TDelphiSemanticPreprocessor.ScanDirectiveFacts(lOptions);
  Assert.IsTrue(lFacts.ImportsUnproved, 'Apostrophes inside multiline strings do not close them.');
  Assert.AreEqual(Pos('{$IFOPT R-}, C', lOptions.SourceText), lFacts.Spans[0].StartOffset,
    'Only the directive after the literal may supply import proof.');
  Assert.AreEqual(1, Integer(Length(lFacts.Spans)), 'The conditional following the closing delimiter is recorded.');
  Assert.IsFalse(lFacts.UnitUnproved);
end;

procedure TPreprocessTests.ActivityEvidenceCoversGapsAndInclusiveEnd;
var
  lSpan: TDelphiSemanticActivitySpan;
  lEvidence: string;
begin
  lSpan := Default(TDelphiSemanticActivitySpan);
  lSpan.FileName := 'Unit1.pas';
  lSpan.SourceText := 'AB';
  lSpan.StartOffset := 1;
  lSpan.EndOffset := 2;
  lSpan.Activity := saActive;
  lEvidence := TDelphiSemanticSourceConditionals.EncodeActivity('AB', 'Unit1.pas', [lSpan]);
  Assert.IsFalse(TDelphiSemanticSourceConditionals.RangeIsKnownActive('AB', lEvidence, 1, 2),
    'The inclusive last code offset lacks a witness.');
  Assert.IsTrue(TDelphiSemanticSourceConditionals.UnknownAtOffset('AB', lEvidence, 2),
    'Uncovered code is unknown, never proven inactive.');
  lSpan.EndOffset := 3;
  lEvidence := TDelphiSemanticSourceConditionals.EncodeActivity('AB', 'Unit1.pas', [lSpan]);
  Assert.IsTrue(TDelphiSemanticSourceConditionals.RangeIsKnownActive('AB', lEvidence, 1, 2));
end;

procedure TPreprocessTests.ConditionalExpressionsRetainTriStateShortCircuit(const aShape: string);
var
  lOptions: TDelphiSemanticPreprocessOptions;
  lResult: TDelphiSemanticPreprocessResult;
  lDirective, lEvidence: string;
  lUnknown, lActive: Boolean;
begin
  lOptions := Default(TDelphiSemanticPreprocessOptions);
  lOptions.SourceFileName := FixturePath('Preprocess', 'ConditionalUnit.pas');
  lOptions.Defines := ['MSWINDOWS', 'X'];
  // This primitive fixture explicitly closes the ordinary symbol universe.
  lOptions.DefineEvidenceComplete := True;
  lUnknown := False;
  lActive := False;
  if aShape = 'or-true' then
  begin
    lDirective := '{$IF Defined(MSWINDOWS) or (CompilerVersion >= 30)}';
    lActive := True;
  end else if aShape = 'and-false' then
    lDirective := '{$IF Defined(NOPE) and (CompilerVersion >= 30)}'
  else if aShape = 'or-right' then
  begin
    lDirective := '{$IF (CompilerVersion >= 30) or Defined(MSWINDOWS)}';
    lActive := True;
  end else if aShape = 'and-right' then
    lDirective := '{$IF (CompilerVersion >= 30) and Defined(NOPE)}'
  else begin
    lUnknown := True;
    if aShape = 'or-unknown' then
      lDirective := '{$IF Defined(NOPE) or (CompilerVersion >= 30)}'
    else if aShape = 'and-unknown' then
      lDirective := '{$IF Defined(MSWINDOWS) and (CompilerVersion >= 30)}'
    else if aShape = 'bare' then
      lDirective := '{$IF X}'
    else if aShape = 'ifdef' then
      lDirective := '{$IFDEF MSWINDOWS trailing}'
    else
      lDirective := '{$IFNDEF MSWINDOWS trailing}';
  end;
  lOptions.SourceText := 'unit Expr;'#13#10'interface'#13#10'implementation'#13#10 +
    lDirective + 'WriteLn(Fetch);{$ELSE}WriteLn(Other);{$ENDIF}'#13#10'end.';
  lResult := TDelphiSemanticPreprocessor.PreprocessFile(lOptions);
  Assert.IsTrue(lResult.Success, 'An unverified operand is a local unknown, not a model failure.');
  Assert.IsTrue(lResult.ActivityEvidenceAvailable);
  Assert.AreEqual(lUnknown, lResult.HasUnknownActivity);
  lEvidence := TDelphiSemanticSourceConditionals.EncodeActivity(lOptions.SourceText,
    lOptions.SourceFileName, lResult.ActivitySpans);
  Assert.AreEqual(lUnknown, TDelphiSemanticSourceConditionals.UnknownAtOffset(
    lOptions.SourceText, lEvidence, Pos('Fetch', lOptions.SourceText)));
  if not lUnknown then
    Assert.AreEqual(lActive, Pos('Fetch', TDelphiSemanticSourceConditionals.SourceForScan(
      lOptions.SourceText, lEvidence)) > 0);
end;

procedure TPreprocessTests.MissingPossibleIncludeKeepsTheModelAndTaintsLaterConditions;
var
  lOptions: TDelphiSemanticPreprocessOptions;
  lResult: TDelphiSemanticPreprocessResult;
  lSpan: TDelphiSemanticActivitySpan;
  lUnknown: Boolean;
begin
  lOptions := Default(TDelphiSemanticPreprocessOptions);
  lOptions.SourceFileName := TPath.Combine(PreprocessTempRoot('missing-possible'), 'Unit1.pas');
  lOptions.SourceText := '{$IFDEF LINUX}{$I Missing.inc}{$ENDIF}'#13#10 +
    '{$IFDEF FOO}WriteLn(Fetch);{$ENDIF}';
  lResult := TDelphiSemanticPreprocessor.PreprocessFile(lOptions);
  Assert.IsTrue(lResult.Success, 'A missing possible include must not fail the whole model.');
  Assert.IsTrue(lResult.ActivityEvidenceAvailable);
  Assert.IsTrue(lResult.HasUnknownActivity);
  Assert.IsTrue(HasDiagnostic(lResult, 'INCLUDE_FILE_NOT_FOUND'));
  lUnknown := False;
  for lSpan in lResult.ActivitySpans do
    if (lSpan.Activity = saUnknown) and
      (Pos('Fetch', Copy(lSpan.SourceText, lSpan.StartOffset,
        lSpan.EndOffset - lSpan.StartOffset)) > 0) then
      lUnknown := True;
  Assert.IsTrue(lUnknown, 'A possible include can define FOO, so the later region is unknown.');
end;

procedure TPreprocessTests.GlobalTaintInvalidatesEarlierWitness(const aRestore: Boolean);
var
  lOptions: TDelphiSemanticPreprocessOptions;
  lResult: TDelphiSemanticPreprocessResult;
  lEvidence: string;
begin
  lOptions := Default(TDelphiSemanticPreprocessOptions);
  lOptions.SourceFileName := TPath.Combine(PreprocessTempRoot('earlier-witness'), 'Unit1.pas');
  lOptions.SourceText := '{$UNDEF X}{$IFDEF LINUX}{$I Missing.inc}{$ENDIF}';
  if aRestore then
    lOptions.SourceText := lOptions.SourceText + '{$UNDEF X}';
  lOptions.SourceText := lOptions.SourceText + '{$IFDEF X}Fetch;{$ENDIF}';
  lResult := TDelphiSemanticPreprocessor.PreprocessFile(lOptions);
  Assert.IsTrue(lResult.Success);
  lEvidence := TDelphiSemanticSourceConditionals.EncodeActivity(lOptions.SourceText,
    lOptions.SourceFileName, lResult.ActivitySpans);
  Assert.AreEqual(not aRestore, TDelphiSemanticSourceConditionals.UnknownAtOffset(
    lOptions.SourceText, lEvidence, Pos('Fetch;', lOptions.SourceText)),
    'Only a later known-active directive can restore symbol certainty.');
end;

procedure TPreprocessTests.PlainActivityBuilderWithoutRootWitnessRetainsUncertainty;
var
  lOptions: TDelphiSemanticModelOptions;
  lModel: TDelphiSemanticUnitModel;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.ProjectContextApplied := True;
  lOptions.SourceFileName := TPath.Combine(PreprocessTempRoot('plain-proof-failure'), 'Unit1.pas');
  TFile.WriteAllText(lOptions.SourceFileName,
    '{$IFDEF NET}unit Unit1; interface function Fetch: Integer; implementation end.{$ENDIF}',
    TEncoding.ASCII);
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(TDelphiSemanticSourceConditionals.UnknownAtOffset(lModel.SourceText,
    lModel.VerifiedActiveSourceText, Pos('Fetch', lModel.SourceText)),
    'A plain builder without a copied root witness must publish no partial inactivity proof.');
end;

procedure TPreprocessTests.InvalidActivitySpanNeverDiscardsUncertainty;
var
  lSpan: TDelphiSemanticActivitySpan;
  lEvidence: string;
begin
  lSpan := Default(TDelphiSemanticActivitySpan);
  lSpan.FileName := 'Unit1.pas';
  lSpan.SourceText := 'different';
  lSpan.StartOffset := 1;
  lSpan.EndOffset := 6;
  lSpan.Activity := saUnknown;
  lEvidence := TDelphiSemanticSourceConditionals.EncodeActivity('Fetch', 'Unit1.pas', [lSpan]);
  Assert.IsTrue(TDelphiSemanticSourceConditionals.UnknownAtOffset('Fetch', lEvidence, 1),
    'A failed mixed builder must retain uncertainty instead of returning an empty proof.');
  Assert.AreEqual('Fetch', TDelphiSemanticSourceConditionals.SourceForScan('Fetch', lEvidence));
end;

function TPreprocessTests.HasDiagnostic(const aResult: TDelphiSemanticPreprocessResult;
  const aCode: string): Boolean;
var
  lDiagnostic: TDelphiSemanticPreprocessDiagnostic;
begin
  for lDiagnostic in aResult.Diagnostics do
    if SameText(lDiagnostic.Code, aCode) then
      Exit(True);

  Result := False;
end;

function TPreprocessTests.HasRegion(const aResult: TDelphiSemanticPreprocessResult;
  const aLine: Integer; const aActive: Boolean): Boolean;
var
  lRegion: TDelphiSemanticSourceRegion;
begin
  for lRegion in aResult.Regions do
    if (lRegion.StartLine <= aLine) and (lRegion.EndLine >= aLine) and
      (lRegion.Active = aActive) then
      Exit(True);

  Result := False;
end;

procedure TPreprocessTests.ConditionalStateDistinguishesOrdinaryAndCompilerSymbols(
  const aShape: string);
var
  lActive: Boolean;
  lDirective: string;
  lOptions: TDelphiSemanticPreprocessOptions;
  lPrefix: string;
  lResult: TDelphiSemanticPreprocessResult;
  lUnverified: Boolean;
begin
  lOptions := Default(TDelphiSemanticPreprocessOptions);
  lOptions.SourceFileName := FixturePath('Preprocess', 'ConditionalUnit.pas');
  lPrefix := '';
  lDirective := '{$IFDEF UNKNOWN_FEATURE}';
  lActive := False;
  lUnverified := True;
  if MatchText(aShape, ['complete-ordinary', 'complete-framework']) then
  begin
    // A closed primitive universe proves ordinary absence, not builtin absence.
    lOptions.DefineEvidenceComplete := True;
    lUnverified := False;
    if aShape = 'complete-framework' then
      lDirective := '{$IFDEF FRAMEWORK_FMX}';
  end else if MatchText(aShape, ['bcb', 'bcb-false']) then
  begin
    lOptions.DefineEvidenceComplete := True;
    lDirective := '{$IFDEF BCB}';
    if aShape = 'bcb-false' then
    begin
      lOptions.PredefinedFalse := ['BCB'];
      lUnverified := False;
    end;
  end else if aShape = 'ordinary-defined' then
    lDirective := '{$IF Defined(UNKNOWN_FEATURE)}'
  else if aShape = 'ordinary-ifndef' then
  begin
    lDirective := '{$IFNDEF UNKNOWN_FEATURE}';
    lActive := True;
  end else if MatchText(aShape, ['unicode', 'unicode-defined', 'captured', 'undef']) then
  begin
    lDirective := '{$IFDEF UNICODE}';
    if aShape = 'unicode-defined' then
      lDirective := '{$IF Defined(UNICODE)}';
    lUnverified := MatchText(aShape, ['unicode', 'unicode-defined']);
    if MatchText(aShape, ['captured', 'undef']) then
    begin
      lOptions.Defines := ['UNICODE'];
      lActive := aShape = 'captured';
      if aShape = 'undef' then
        lPrefix := '{$UNDEF UNICODE}'#13#10;
    end;
  end else if aShape = 'version' then
  begin
    lDirective := '{$IFDEF VER9999}';
    lUnverified := True;
  end else if MatchText(aShape, ['IOSSIMULATOR', 'IOS32', 'OSX32', 'MANAGED_RECORD', 'WEAK_NATIVEINT', 'LLVM']) then
  begin
    lDirective := '{$IFDEF ' + aShape + '}';
    lUnverified := True;
  end else if aShape = 'framework' then
  begin
    lDirective := '{$IFDEF FRAMEWORK_FMX}';
    lUnverified := True;
  end;
  lOptions.SourceText := 'unit SymbolState;'#13#10'interface'#13#10 + lPrefix +
    lDirective + #13#10'type TBranchMarker = record end;'#13#10 +
    '{$ENDIF}'#13#10'implementation'#13#10'end.';
  lResult := TDelphiSemanticPreprocessor.PreprocessFile(lOptions);
  Assert.IsTrue(lResult.Success);
  Assert.AreEqual(lActive, Pos('TBranchMarker', lResult.OutputText) > 0);
  Assert.AreEqual(lUnverified, HasDiagnostic(lResult, 'UNVERIFIED_PREPROCESS_CONDITION'));
end;

procedure TPreprocessTests.ActiveDefinesSelectExpectedConditionalRegions;
var
  lOptions: TDelphiSemanticPreprocessOptions;
  lResult: TDelphiSemanticPreprocessResult;
begin
  lOptions := Default(TDelphiSemanticPreprocessOptions);
  lOptions.SourceFileName := FixturePath('Preprocess', 'ConditionalUnit.pas');
  lOptions.Defines := ['ACTIVE_FEATURE'];

  lResult := TDelphiSemanticPreprocessor.PreprocessFile(lOptions);

  Assert.IsTrue(lResult.Success);
  Assert.IsTrue(Pos('TActiveType', lResult.OutputText) > 0);
  Assert.IsTrue(Pos('TIfNDefType', lResult.OutputText) > 0);
  Assert.IsTrue(Pos('TIfDefinedType', lResult.OutputText) > 0);
  Assert.IsFalse(Pos('TInactiveType', lResult.OutputText) > 0);
  Assert.IsFalse(Pos('TElseIfType', lResult.OutputText) > 0);
  Assert.IsTrue(HasRegion(lResult, 6, True), 'active IFDEF branch region');
  Assert.IsTrue(HasRegion(lResult, 8, False), 'inactive ELSE branch region');
end;

procedure TPreprocessTests.DefineAndUndefDirectivesAffectLaterRegions;
var
  lOptions: TDelphiSemanticPreprocessOptions;
  lResult: TDelphiSemanticPreprocessResult;
begin
  lOptions := Default(TDelphiSemanticPreprocessOptions);
  lOptions.SourceFileName := FixturePath('Preprocess', 'DefineUndefUnit.pas');

  lResult := TDelphiSemanticPreprocessor.PreprocessFile(lOptions);

  Assert.IsTrue(lResult.Success);
  Assert.IsTrue(Pos('TDefinedType', lResult.OutputText) > 0);
  Assert.IsFalse(Pos('TUndefinedType', lResult.OutputText) > 0);
end;

procedure TPreprocessTests.IncludesResolveFromSearchPathsAndAffectGraphHash;
var
  lFirst: TDelphiSemanticPreprocessResult;
  lOptions: TDelphiSemanticPreprocessOptions;
  lSecond: TDelphiSemanticPreprocessResult;
  lTempDir: string;
begin
  lTempDir := PreprocessTempRoot('includes');
  TFile.WriteAllText(TPath.Combine(lTempDir, 'Dynamic.inc'), 'type TFirstInclude = class end;',
    TEncoding.UTF8);
  TFile.WriteAllText(TPath.Combine(lTempDir, 'DynamicIncludeUnit.pas'),
    'unit DynamicIncludeUnit;' + sLineBreak +
    'interface' + sLineBreak +
    '{$I Dynamic.inc}' + sLineBreak +
    'implementation' + sLineBreak +
    'end.', TEncoding.UTF8);

  lOptions := Default(TDelphiSemanticPreprocessOptions);
  lOptions.SourceFileName := TPath.Combine(lTempDir, 'DynamicIncludeUnit.pas');
  lOptions.SearchPaths := [lTempDir];

  lFirst := TDelphiSemanticPreprocessor.PreprocessFile(lOptions);
  TFile.WriteAllText(TPath.Combine(lTempDir, 'Dynamic.inc'), 'type TSecondInclude = class end;',
    TEncoding.UTF8);
  lSecond := TDelphiSemanticPreprocessor.PreprocessFile(lOptions);

  Assert.IsTrue(lFirst.Success);
  Assert.IsTrue(lSecond.Success);
  Assert.AreEqual(1, Integer(Length(lFirst.Includes)));
  Assert.IsTrue(Pos('TFirstInclude', lFirst.OutputText) > 0);
  Assert.IsTrue(Pos('TSecondInclude', lSecond.OutputText) > 0);
  Assert.AreNotEqual(lFirst.IncludeGraphHash, lSecond.IncludeGraphHash);
end;

procedure TPreprocessTests.IncludeHashUsesLoadedIncludeText;
var
  lSource: string;
begin
  lSource := ReadRepoSource('src\DelphiSemantics.Preprocess.pas');

  Assert.IsFalse(Pos('CalculateTextHash(TFile.ReadAllText', lSource) > 0,
    'Include content hash must use the text already loaded for include processing.');
  Assert.IsFalse(Pos('ProcessSourceFile(lIncludeFileName', lSource) > 0,
    'Include processing should not call the file-loading entry point after hashing.');
  Assert.IsFalse(Pos('TFile.ReadAllText', lSource) > 0,
    'Preprocessor file reads should use the shared source loader.');
  Assert.IsTrue(Pos('TSourceTextCache', lSource) > 0,
    'Preprocessor should keep a pass-scoped source text cache.');
  Assert.IsTrue(Pos('TSourceTextCache.Create(TFastCaseAwareComparer.OrdinalIgnoreCase)',
    lSource) > 0, 'Preprocessor source text cache should use path-casing tolerant keys.');
  Assert.IsTrue(Pos('TDelphiSemanticSourceLoader.LoadFile', lSource) > 0,
    'Preprocessor source reads should route through the shared source loader.');
end;

procedure TPreprocessTests.IncludeCyclesProduceDeterministicDiagnostic;
var
  lOptions: TDelphiSemanticPreprocessOptions;
  lResult: TDelphiSemanticPreprocessResult;
  lTempDir: string;
begin
  lTempDir := PreprocessTempRoot('cycles');
  TFile.WriteAllText(TPath.Combine(lTempDir, 'CycleUnit.pas'),
    'unit CycleUnit;' + sLineBreak +
    'interface' + sLineBreak +
    '{$I Cycle.inc}' + sLineBreak +
    'implementation' + sLineBreak +
    'end.', TEncoding.UTF8);
  TFile.WriteAllText(TPath.Combine(lTempDir, 'Cycle.inc'), '{$I Cycle.inc}',
    TEncoding.UTF8);

  lOptions := Default(TDelphiSemanticPreprocessOptions);
  lOptions.SourceFileName := TPath.Combine(lTempDir, 'CycleUnit.pas');
  lOptions.SearchPaths := [lTempDir];

  lResult := TDelphiSemanticPreprocessor.PreprocessFile(lOptions);

  Assert.IsFalse(lResult.Success);
  Assert.IsTrue(HasDiagnostic(lResult, 'INCLUDE_CYCLE'));
end;

procedure TPreprocessTests.MalformedConditionalStackProducesDiagnostics;
var
  lOptions: TDelphiSemanticPreprocessOptions;
  lResult: TDelphiSemanticPreprocessResult;
begin
  lOptions := Default(TDelphiSemanticPreprocessOptions);
  lOptions.SourceFileName := FixturePath('Preprocess', 'MalformedConditionalUnit.pas');

  lResult := TDelphiSemanticPreprocessor.PreprocessFile(lOptions);

  Assert.IsFalse(lResult.Success);
  Assert.IsTrue(HasDiagnostic(lResult, 'UNMATCHED_PREPROCESS_DIRECTIVE'));
  Assert.IsTrue(HasDiagnostic(lResult, 'UNTERMINATED_PREPROCESS_CONDITIONAL'));
end;

procedure TPreprocessTests.ConditionalDirectivesAllowTrailingComments;
var
  lOptions: TDelphiSemanticPreprocessOptions;
  lResult: TDelphiSemanticPreprocessResult;
begin
  lOptions := Default(TDelphiSemanticPreprocessOptions);
  lOptions.SourceFileName := FixturePath('Preprocess', 'TrailingCommentConditionalUnit.pas');
  lOptions.Defines := ['ACTIVE_FEATURE'];

  lResult := TDelphiSemanticPreprocessor.PreprocessFile(lOptions);

  Assert.IsTrue(lResult.Success);
  Assert.IsTrue(Pos('TActiveTrailingType', lResult.OutputText) > 0);
  Assert.IsFalse(Pos('TInactiveTrailingType', lResult.OutputText) > 0);
  Assert.IsTrue(Pos('TElseTrailingType', lResult.OutputText) > 0);
end;

procedure TPreprocessTests.ConditionalDirectivesAllowLegacyMultilineCloseBrace;
var
  lOptions: TDelphiSemanticPreprocessOptions;
  lResult: TDelphiSemanticPreprocessResult;
begin
  lOptions := Default(TDelphiSemanticPreprocessOptions);
  lOptions.SourceFileName := FixturePath('Preprocess', 'LegacyMultilineCloseBraceUnit.pas');

  lResult := TDelphiSemanticPreprocessor.PreprocessFile(lOptions);

  Assert.IsTrue(lResult.Success);
  Assert.IsTrue(Pos('TAfterLegacyCloseBrace', lResult.OutputText) > 0);
  Assert.IsFalse(HasDiagnostic(lResult, 'UNTERMINATED_PREPROCESS_CONDITIONAL'));
end;

procedure TPreprocessTests.CompilerSwitchDirectivesDoNotFailPreprocessing;
var
  lOptions: TDelphiSemanticPreprocessOptions;
  lResult: TDelphiSemanticPreprocessResult;
begin
  lOptions := Default(TDelphiSemanticPreprocessOptions);
  lOptions.SourceFileName := FixturePath('Preprocess', 'CompilerSwitchUnit.pas');

  lResult := TDelphiSemanticPreprocessor.PreprocessFile(lOptions);

  Assert.IsTrue(lResult.Success);
  Assert.IsTrue(Pos('TAfterCompilerSwitch', lResult.OutputText) > 0);
  Assert.IsFalse(HasDiagnostic(lResult, 'UNSUPPORTED_PREPROCESS_DIRECTIVE'));
end;

procedure TPreprocessTests.RtlMetadataAndSwitchGroupsPreservePascalSource(
  const aCase: Integer; const aSuccess: Boolean);
const
  cDirectives: array[0..10] of string = (
    'EXTERNALSYM TNative ''NativeName''',
    'HPPEMIT ''#define DAK_SAMPLE 1''',
    'NODEFINE TNative ''NativeName'' ''NativeUnionName''',
    'OBJTYPENAME TNative ''NTNative''',
    'H+,I-,R-,O+,W-',
    'UNKNOWN_NATIVE_DIRECTIVE',
    'H+,UNKNOWN_NATIVE_DIRECTIVE',
    'EXTERNALSYM_FAKE TNative',
    'H+,I-,',
    'HPPEMIT ''}''',
    'H+,J+');
var
  lDirective: string;
  lOptions: TDelphiSemanticPreprocessOptions;
  lResult: TDelphiSemanticPreprocessResult;
  lSource: string;
begin
  lOptions := Default(TDelphiSemanticPreprocessOptions);
  lOptions.SourceFileName := TPath.Combine(PreprocessTempRoot('rtl-metadata-' + IntToStr(aCase)),
    'RtlMetadata.pas');
  lDirective := '{$' + cDirectives[aCase] + '}';
  if aCase >= 9 then
    lDirective := '(*$' + cDirectives[aCase] + '*)';
  if aCase = 10 then
    lDirective := '  ' + lDirective;
  lSource := 'unit RtlMetadata;' + sLineBreak + 'interface' + sLineBreak +
    'type TNative = type Integer;' + sLineBreak +
    lDirective + sLineBreak +
    'implementation' + sLineBreak + 'end.' + sLineBreak;
  TFile.WriteAllText(lOptions.SourceFileName, lSource, TEncoding.UTF8);
  lResult := TDelphiSemanticPreprocessor.PreprocessFile(lOptions);
  Assert.AreEqual(aSuccess, lResult.Success);
  Assert.AreEqual(not aSuccess, HasDiagnostic(lResult, 'UNSUPPORTED_PREPROCESS_DIRECTIVE'));
  if aSuccess then
  begin
    Assert.AreEqual(lSource, lResult.OutputText, 'Recognized directives must remain in source.');
    Assert.AreEqual<NativeInt>(6, Length(lResult.LineOrigins));
    Assert.AreEqual(4, lResult.LineOrigins[3].Line);
    Assert.IsTrue(SameText(lOptions.SourceFileName, lResult.LineOrigins[3].FileName));
    Assert.IsFalse(lResult.LineOrigins[3].Mixed);
  end;
end;

procedure TPreprocessTests.DirectivesInsideLineCommentsAreIgnored;
var
  lOptions: TDelphiSemanticPreprocessOptions;
  lPath: string;
  lResult: TDelphiSemanticPreprocessResult;
  lRoot: string;
begin
  lRoot := PreprocessTempRoot('line-comment-directive');
  lPath := TPath.Combine(lRoot, 'LineCommentDirectiveUnit.pas');
  TFile.WriteAllText(lPath,
    'unit LineCommentDirectiveUnit;' + sLineBreak +
    'interface' + sLineBreak +
    '/// Documentation mentioning {$IFDEF FPC} must stay a comment.' +
    sLineBreak + 'implementation' + sLineBreak +
    'end.', TEncoding.UTF8);
  lOptions := Default(TDelphiSemanticPreprocessOptions);
  lOptions.SourceFileName := lPath;

  lResult := TDelphiSemanticPreprocessor.PreprocessFile(lOptions);

  Assert.IsTrue(lResult.Success);
  Assert.IsTrue(Pos('implementation', lResult.OutputText) > 0);
  Assert.IsFalse(HasDiagnostic(lResult, 'UNTERMINATED_PREPROCESS_CONDITIONAL'));
end;

procedure TPreprocessTests.DirectiveLookalikesPreserveSource(const aCase: Integer);
const
  cExamples: array[0..2] of string = (
    '(* Example' + sLineBreak + '{$J+}' + sLineBreak + '*)',
    '{ Example' + sLineBreak + '(*$J+*)' + sLineBreak + '}',
    'const TextValue = ''It''''s {$J+} and (*$J+*)'';');
var
  lOptions: TDelphiSemanticPreprocessOptions;
  lResult: TDelphiSemanticPreprocessResult;
  lSource: string;
begin
  lOptions := Default(TDelphiSemanticPreprocessOptions);
  lOptions.SourceFileName := TPath.Combine(PreprocessTempRoot('directive-lookalikes'),
    'DirectiveLookalikes.pas');
  lSource := 'unit DirectiveLookalikes;' + sLineBreak + 'interface' +
    sLineBreak + '{$J-}' + sLineBreak + cExamples[aCase] + sLineBreak +
    'const ReadOnlyValue: Integer = 1;' + sLineBreak + 'implementation' +
    sLineBreak + 'end.' + sLineBreak;
  TFile.WriteAllText(lOptions.SourceFileName, lSource, TEncoding.UTF8);
  lResult := TDelphiSemanticPreprocessor.PreprocessFile(lOptions);
  Assert.IsTrue(lResult.Success);
  Assert.AreEqual(lSource, lResult.OutputText,
    'Inactive directive-shaped text must remain byte-position-equivalent source.');
end;

procedure TPreprocessTests.CommentSlashesDoNotHideFollowingDirective(const aCase: Integer);
const
  cComments: array[0..1] of string = ('(* // *)', '{ // }');
var
  lOptions: TDelphiSemanticPreprocessOptions;
  lResult: TDelphiSemanticPreprocessResult;
begin
  lOptions := Default(TDelphiSemanticPreprocessOptions);
  lOptions.SourceFileName := TPath.Combine(PreprocessTempRoot('comment-before-directive'),
    'CommentBeforeDirective.pas');
  TFile.WriteAllText(lOptions.SourceFileName,
    'unit CommentBeforeDirective;' + sLineBreak + 'interface' + sLineBreak +
    cComments[aCase] + ' {$IFDEF NEVER_DEFINED}' + sLineBreak +
    'const HiddenValue = 1;' + sLineBreak + '{$ENDIF}' + sLineBreak +
    'const VisibleValue = 2;' + sLineBreak + 'implementation' + sLineBreak +
    'end.', TEncoding.UTF8);
  lResult := TDelphiSemanticPreprocessor.PreprocessFile(lOptions);
  Assert.IsTrue(lResult.Success, 'Comment text must not hide the active conditional directive.');
  Assert.IsFalse(Pos('HiddenValue', lResult.OutputText) > 0);
  Assert.IsTrue(Pos('VisibleValue', lResult.OutputText) > 0);
end;

procedure TPreprocessTests.InlineConditionalDirectivesCloseOnSameLine;
var
  lOptions: TDelphiSemanticPreprocessOptions;
  lResult: TDelphiSemanticPreprocessResult;
begin
  lOptions := Default(TDelphiSemanticPreprocessOptions);
  lOptions.SourceFileName := FixturePath('Preprocess', 'InlineConditionalUnit.pas');

  lResult := TDelphiSemanticPreprocessor.PreprocessFile(lOptions);

  Assert.IsTrue(lResult.Success);
  Assert.IsTrue(Pos('TAfterInlineConditional', lResult.OutputText) > 0);
  Assert.IsFalse(HasDiagnostic(lResult, 'UNTERMINATED_PREPROCESS_CONDITIONAL'));
end;

procedure TPreprocessTests.Linux64ProjectConditionalsUseTargetDefines;
var
  lContextOptions: TDelphiSemanticOptions;
  lContext: TDelphiSemanticContextResult;
  lOptions: TDelphiSemanticPreprocessOptions;
  lResult: TDelphiSemanticPreprocessResult;
begin
  lContextOptions := Default(TDelphiSemanticOptions);
  lContextOptions.Configuration := 'Debug';
  lContextOptions.Platform := 'Linux64';
  lContextOptions.DelphiVersion := '23.0';

  lContext := TDelphiSemanticProject.Load(
    FixturePath('ProjectContext', 'MsBuild\MsBuildProject.dproj'), lContextOptions);
  Assert.IsTrue(lContext.Success);

  lOptions := Default(TDelphiSemanticPreprocessOptions);
  lOptions.SourceFileName := FixturePath('Preprocess', 'ConditionalUnit.pas');
  lOptions.SourceText :=
    'unit TargetPlatformConditionalUnit;' + sLineBreak +
    'interface' + sLineBreak +
    '{$IFDEF LINUX}' + sLineBreak +
    'type TLinuxTargetBranch = class end;' + sLineBreak +
    '{$ENDIF}' + sLineBreak +
    '{$IF DEFINED(POSIX) and DEFINED(CPUX64)}' + sLineBreak +
    'type TPosixCpuX64Branch = class end;' + sLineBreak +
    '{$ENDIF}' + sLineBreak +
    '{$IFDEF MSWINDOWS}' + sLineBreak +
    'type TWindowsHostBranch = class end;' + sLineBreak +
    '{$ENDIF}' + sLineBreak +
    '{$IFDEF WIN32}' + sLineBreak +
    'type TWin32HostBranch = class end;' + sLineBreak +
    '{$ENDIF}' + sLineBreak +
    'implementation' + sLineBreak +
    'end.';
  lOptions.Defines := lContext.Project.Defines;

  lResult := TDelphiSemanticPreprocessor.PreprocessFile(lOptions);

  Assert.IsTrue(lResult.Success);
  Assert.IsTrue(Pos('TLinuxTargetBranch', lResult.OutputText) > 0);
  Assert.IsTrue(Pos('TPosixCpuX64Branch', lResult.OutputText) > 0);
  Assert.IsFalse(Pos('TWindowsHostBranch', lResult.OutputText) > 0);
  Assert.IsFalse(Pos('TWin32HostBranch', lResult.OutputText) > 0);
end;

procedure TPreprocessTests.UnsupportedConditionalElseBranchStaysInactive;
var
  lOptions: TDelphiSemanticPreprocessOptions;
  lResult: TDelphiSemanticPreprocessResult;
begin
  lOptions := Default(TDelphiSemanticPreprocessOptions);
  lOptions.SourceFileName := FixturePath('Preprocess', 'UnsupportedElseUnit.pas');

  lResult := TDelphiSemanticPreprocessor.PreprocessFile(lOptions);

  Assert.IsFalse(lResult.Success);
  Assert.IsTrue(HasDiagnostic(lResult, 'UNSUPPORTED_PREPROCESS_DIRECTIVE'));
  Assert.IsFalse(Pos('TUnsupportedIfElseType', lResult.OutputText) > 0);
  Assert.IsFalse(Pos('TUnsupportedIfOptElseType', lResult.OutputText) > 0);
end;

procedure TPreprocessTests.UnsupportedConditionalDirectiveProducesDiagnostic;
var
  lOptions: TDelphiSemanticPreprocessOptions;
  lResult: TDelphiSemanticPreprocessResult;
begin
  lOptions := Default(TDelphiSemanticPreprocessOptions);
  lOptions.SourceFileName := FixturePath('Preprocess', 'UnsupportedDirectiveUnit.pas');

  lResult := TDelphiSemanticPreprocessor.PreprocessFile(lOptions);

  Assert.IsFalse(lResult.Success);
  Assert.IsTrue(HasDiagnostic(lResult, 'UNSUPPORTED_PREPROCESS_DIRECTIVE'));
  Assert.IsFalse(Pos('TUnsupportedActiveType', lResult.OutputText) > 0);
end;

initialization
  TDUnitX.RegisterTestFixture(TPreprocessTests);

end.
