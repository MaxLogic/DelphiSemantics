unit DelphiSemantics.NameFlow.Extract;

interface

uses
  DelphiAST.Classes,
  DelphiSemantics.NameFlow.Facts, DelphiSemantics.Preprocess;

type
  // Typed parser-owned annotation; never confuse a routine heading witness with unsupported syntax.
  TDelphiNameFlowRoutineHeadingNode = class(TCompoundSyntaxNode);


function ExtractNameFlowFacts(const aRoot: TSyntaxNode; const aFileName, aText: string;
  const aComplete, aConfigurationComplete: Boolean; const aReason: string;
  const aMaximumNodes: Integer = 1000000): IDelphiNameFlowFacts;
function MapNameFlowFacts(const aFacts: IDelphiNameFlowFacts; const aText: string;
  const aPreprocess: TDelphiSemanticPreprocessResult; const aOutputOffsetShift: Integer): IDelphiNameFlowFacts;

implementation

uses
  System.Generics.Collections, System.StrUtils, System.SysUtils,
  AutoFree, DelphiAST.Consts, SimpleParser.Lexer, SimpleParser.Lexer.Types;

type
  TDelimiterEnd = record
    Offset, Line, Column: Integer;
  end;

  TPendingNode = record
    Node: TSyntaxNode;
    ParentId, ChildIndex: Integer;
  end;

function NodeKind(const aKind: TSyntaxNodeType): TDelphiNameFlowNodeKind;
begin
  case aKind of
    TSyntaxNodeType.ntMethod, TSyntaxNodeType.ntAnonymousMethod, TSyntaxNodeType.ntInitialization, TSyntaxNodeType.ntFinalization:
      Result := TDelphiNameFlowNodeKind.Routine;
    TSyntaxNodeType.ntParameter: Result := TDelphiNameFlowNodeKind.Formal;
    TSyntaxNodeType.ntReturnType: Result := TDelphiNameFlowNodeKind.ResultValue;
    TSyntaxNodeType.ntConstant, TSyntaxNodeType.ntVariable, TSyntaxNodeType.ntField: Result := TDelphiNameFlowNodeKind.Definition;
    TSyntaxNodeType.ntAssign: Result := TDelphiNameFlowNodeKind.Assignment;
    TSyntaxNodeType.ntCall: Result := TDelphiNameFlowNodeKind.Call;
    // Until declaration binding, every identifier may be a no-parentheses call or property read.
    TSyntaxNodeType.ntIdentifier: Result := TDelphiNameFlowNodeKind.PotentialCall;
    TSyntaxNodeType.ntProperty: Result := TDelphiNameFlowNodeKind.PropertyAccess;
    TSyntaxNodeType.ntRaise, TSyntaxNodeType.ntExceptionHandler, TSyntaxNodeType.ntIs, TSyntaxNodeType.ntAs: Result := TDelphiNameFlowNodeKind.RaiseValue;
    TSyntaxNodeType.ntLiteral: Result := TDelphiNameFlowNodeKind.LiteralValue;
    TSyntaxNodeType.ntUnknown: Result := TDelphiNameFlowNodeKind.Unknown;
    TSyntaxNodeType.ntAdd, TSyntaxNodeType.ntSub, TSyntaxNodeType.ntMul, TSyntaxNodeType.ntDiv, TSyntaxNodeType.ntFDiv, TSyntaxNodeType.ntMod, TSyntaxNodeType.ntAddr, TSyntaxNodeType.ntDeref, TSyntaxNodeType.ntDot, TSyntaxNodeType.ntIndex, TSyntaxNodeType.ntIndexed,
      TSyntaxNodeType.ntGeneric, TSyntaxNodeType.ntAnd, TSyntaxNodeType.ntOr, TSyntaxNodeType.ntXor, TSyntaxNodeType.ntNot, TSyntaxNodeType.ntUnaryMinus, TSyntaxNodeType.ntEqual, TSyntaxNodeType.ntNotEqual,
      TSyntaxNodeType.ntGreater, TSyntaxNodeType.ntGreaterEqual, TSyntaxNodeType.ntLower, TSyntaxNodeType.ntLowerEqual, TSyntaxNodeType.ntShl, TSyntaxNodeType.ntShr:
      Result := TDelphiNameFlowNodeKind.Operation;
  else
    Result := TDelphiNameFlowNodeKind.Syntax;
  end;
end;

function AstName(const aNode: TSyntaxNode): string;
var
  lChild: TSyntaxNode;
begin
  Result := aNode.GetAttribute(TAttributeName.anName);
  if Result <> '' then
    Exit;
  lChild := aNode.FindNode(TSyntaxNodeType.ntName);
  if lChild is TValuedSyntaxNode then
    Result := TValuedSyntaxNode(lChild).Value
  else if lChild <> nil then
    Result := lChild.GetAttribute(TAttributeName.anName);
end;

function PositionOffset(const aStarts: TArray<Integer>; const aLine, aColumn: Integer;
  const aLength: Integer): Integer;
begin
  Result := 0;
  if (aLine > 0) and (aLine <= Length(aStarts)) and (aColumn > 0) then
  begin
    Result := aStarts[aLine - 1] + aColumn - 1;
    if (Result > aLength + 1) or
      ((aLine < Length(aStarts)) and (Result >= aStarts[aLine])) then
      Result := 0;
  end;
end;

function NextCodeOffset(const aOffsets: TList<Integer>; const aOffset: Integer): Integer;
var
  lo, hi, lMiddle: Integer;
begin
  lo := 0;
  hi := aOffsets.Count;
  while lo < hi do
  begin
    lMiddle := lo + (hi - lo) div 2;
    if aOffsets[lMiddle] < aOffset then
      lo := lMiddle + 1
    else
      hi := lMiddle;
  end;
  Result := 0;
  if lo < aOffsets.Count then
    Result := aOffsets[lo];
end;

function PreviousCodeOffset(const aOffsets: TList<Integer>; const aOffset: Integer): Integer;
var
  lo, hi, lMiddle: Integer;
begin
  lo := 0;
  hi := aOffsets.Count;
  while lo < hi do
  begin
    lMiddle := lo + (hi - lo) div 2;
    if aOffsets[lMiddle] < aOffset then
      lo := lMiddle + 1
    else
      hi := lMiddle;
  end;
  Result := 0;
  if lo > 0 then
    Result := aOffsets[lo - 1];
end;

procedure CoordinatesAtOffset(const aStarts: TArray<Integer>; const aOffset: Integer;
  out aLine, aColumn: Integer);
var
  lo, hi, lMiddle: Integer;
begin
  lo := 0;
  hi := Length(aStarts);
  while lo < hi do
  begin
    lMiddle := lo + (hi - lo) div 2;
    if aStarts[lMiddle] <= aOffset then
      lo := lMiddle + 1
    else
      hi := lMiddle;
  end;
  aLine := lo;
  aColumn := aOffset - aStarts[lo - 1] + 1;
end;

procedure RecordDelimiterEnd(const aLexer: TmwBasePasLex; const aStack: TStack<Integer>;
  const aEnds: TDictionary<Integer, TDelimiterEnd>);
var
  lEnd: TDelimiterEnd;
begin
  if aStack.Count = 0 then
    Exit;
  lEnd.Offset := aLexer.TokenPos + aLexer.TokenLen + 1;
  lEnd.Line := aLexer.PosXY.Y;
  lEnd.Column := aLexer.PosXY.X + aLexer.TokenLen;
  aEnds.AddOrSetValue(aStack.Pop, lEnd);
end;

function ExtractNameFlowFacts(const aRoot: TSyntaxNode; const aFileName, aText: string;
  const aComplete, aConfigurationComplete: Boolean; const aReason: string;
  const aMaximumNodes: Integer): IDelphiNameFlowFacts;
var
  i, j, lLength, lEnd, lLimit, lDelimiterOpen: Integer;
  lComplete: Boolean;
  lReason: string;
  lStarts: TArray<Integer>;
  lLines: TList<Integer>;
  lNodes: TList<TDelphiNameFlowNode>;
  lStack: TStack<TPendingNode>;
  lTokens: TDictionary<Integer, Integer>;
  lCodeOffsets: TList<Integer>;
  lRoundDelimiters, lSquareDelimiters, lAngleDelimiters: TStack<Integer>;
  lDelimiterEnds: TDictionary<Integer, TDelimiterEnd>;
  lDelimiterEnd: TDelimiterEnd;
  lLexer: TmwBasePasLex;
  lPending, lChild: TPendingNode;
  lNode, lParent: TDelphiNameFlowNode;
  lTypeNode: TSyntaxNode;
  g: TGarbos;
begin
{$IFDEF DS_PROJECT_SESSION_TEST_SUPPORT}
  RecordNameFlowWorkForTest(TDelphiNameFlowWorkKind.Extract);
{$ENDIF}
  if aRoot = nil then
    Exit(CreateNameFlowFacts(nil, False, False, 'name-flow-ast-missing'));
  if aMaximumNodes < 0 then
    Exit(CreateNameFlowFacts(nil, False, False, 'name-flow-fact-budget-exceeded'));
  lLimit := aMaximumNodes;
  if (lLimit = 0) or (lLimit > 1000000) then
    lLimit := 1000000;
  lComplete := aComplete;
  lReason := aReason;
  GC(lLines, TList<Integer>.Create, g);
  GC(lNodes, TList<TDelphiNameFlowNode>.Create, g);
  GC(lStack, TStack<TPendingNode>.Create, g);
  GC(lTokens, TDictionary<Integer, Integer>.Create, g);
  GC(lLexer, TmwBasePasLex.Create, g);
  GC(lCodeOffsets, TList<Integer>.Create, g);
  GC(lRoundDelimiters, TStack<Integer>.Create, g);
  GC(lSquareDelimiters, TStack<Integer>.Create, g);
  GC(lAngleDelimiters, TStack<Integer>.Create, g);
  GC(lDelimiterEnds, TDictionary<Integer, TDelimiterEnd>.Create, g);
  lLines.Add(1);
  for i := 1 to Length(aText) do
    if aText[i] = #10 then
      lLines.Add(i + 1);
  lStarts := lLines.ToArray;
  lLexer.UseDefines := False;
  lLexer.Origin := aText;
  while lLexer.TokenID <> ptNull do
  begin
    lTokens.AddOrSetValue(lLexer.TokenPos + 1, lLexer.TokenLen);
    if not lLexer.IsJunk then
    begin
      lCodeOffsets.Add(lLexer.TokenPos + 1);
      case lLexer.TokenID of
        TptTokenKind.ptRoundOpen: lRoundDelimiters.Push(lLexer.TokenPos + 1);
        TptTokenKind.ptSquareOpen: lSquareDelimiters.Push(lLexer.TokenPos + 1);
        TptTokenKind.ptLower: lAngleDelimiters.Push(lLexer.TokenPos + 1);
        TptTokenKind.ptRoundClose: RecordDelimiterEnd(lLexer, lRoundDelimiters, lDelimiterEnds);
        TptTokenKind.ptSquareClose: RecordDelimiterEnd(lLexer, lSquareDelimiters, lDelimiterEnds);
        TptTokenKind.ptGreater: RecordDelimiterEnd(lLexer, lAngleDelimiters, lDelimiterEnds);
      end;
    end;
    lLexer.Next;
  end;
  lPending := Default(TPendingNode);
  lPending.Node := aRoot;
  lStack.Push(lPending);
  while lStack.Count > 0 do
  begin
    lPending := lStack.Pop;
    // Reserve the current node and every pending/direct child before allocating arrays.
    // A budget failure publishes no truncated topology and remains a cacheable refusal.
    if (lNodes.Count >= lLimit) or (lStack.Count > lLimit - lNodes.Count - 1) or
      (Length(lPending.Node.ChildNodes) > lLimit - lNodes.Count - lStack.Count - 1) then
      Exit(CreateNameFlowFacts(nil, False, False, 'name-flow-fact-budget-exceeded'));
    lNode := Default(TDelphiNameFlowNode);
    lNode.Id := lNodes.Count + 1;
    lNode.ParentId := lPending.ParentId;
    lNode.Kind := NodeKind(lPending.Node.Typ);
    lNode.SyntaxKind := SyntaxNodeNames[lPending.Node.Typ];
    if lPending.Node is TDelphiNameFlowRoutineHeadingNode then
    begin
      lNode.Kind := TDelphiNameFlowNodeKind.Syntax;
      lNode.SyntaxKind := 'routineheading';
    end;
    lNode.Name := AstName(lPending.Node);
    lNode.TypeName := lPending.Node.GetAttribute(TAttributeName.anType);
    lTypeNode := lPending.Node.FindNode(TSyntaxNodeType.ntType);
    if (lNode.TypeName = '') and (lTypeNode <> nil) then
      lNode.TypeName := lTypeNode.GetAttribute(TAttributeName.anName);
    if lPending.Node is TValuedSyntaxNode then
      lNode.Value := TValuedSyntaxNode(lPending.Node).Value;
    SetLength(lNode.Attributes, Length(lPending.Node.Attributes));
    for i := 0 to High(lNode.Attributes) do
    begin
      lNode.Attributes[i].Name := AttributeNameStrings[lPending.Node.Attributes[i].Key];
      lNode.Attributes[i].Value := lPending.Node.Attributes[i].Value;
    end;
    lNode.FileName := aFileName;
    lNode.Line := lPending.Node.Line;
    lNode.Column := lPending.Node.Col;
    lNode.OutputStartOffset := PositionOffset(lStarts, lNode.Line, lNode.Column, Length(aText));
    if lTokens.TryGetValue(lNode.OutputStartOffset, lLength) then
    begin
      lNode.EndLine := lNode.Line;
      lNode.EndColumn := lNode.Column + lLength;
      lNode.OutputEndOffset := lNode.OutputStartOffset + lLength;
    end;
    if lPending.Node is TCompoundSyntaxNode then
    begin
      lNode.EndLine := TCompoundSyntaxNode(lPending.Node).EndLine;
      lNode.EndColumn := TCompoundSyntaxNode(lPending.Node).EndCol;
      lNode.OutputEndOffset := PositionOffset(lStarts, lNode.EndLine, lNode.EndColumn, Length(aText));
    end;
    lNode.ActivityKnown := aConfigurationComplete;
    if lPending.ParentId > 0 then
    begin
      lParent := lNodes[lPending.ParentId - 1];
      lNode.ScopeId := lParent.ScopeId;
      lNode.OwnerType := lParent.OwnerType;
      lParent.Children[lPending.ChildIndex] := lNode.Id;
      lNodes[lPending.ParentId - 1] := lParent;
    end;
    if lPending.Node.Typ = TSyntaxNodeType.ntTypeDecl then
      lNode.OwnerType := lNode.Name;
    if lNode.Kind = TDelphiNameFlowNodeKind.Routine then
    begin
      lNode.ScopeId := lNode.ScopeId + '/' + lNode.Name + '@' + IntToStr(lNode.Line) + ':' + IntToStr(lNode.Column);
      lNode.BodyComplete := aComplete and (lPending.Node.FindNode(TSyntaxNodeType.ntStatements) <> nil);
    end;
    if (lNode.Kind = TDelphiNameFlowNodeKind.Unknown) or
      SameText(lPending.Node.GetAttribute(TAttributeName.anType), 'asm') then
    begin
      lComplete := False;
      lReason := 'name-flow-syntax-unsupported';
    end;
    SetLength(lNode.Children, Length(lPending.Node.ChildNodes));
    lNodes.Add(lNode);
    for i := High(lPending.Node.ChildNodes) downto 0 do
    begin
      lChild.Node := lPending.Node.ChildNodes[i];
      lChild.ParentId := lNode.Id;
      lChild.ChildIndex := i;
      lStack.Push(lChild);
    end;
  end;
  // Extend syntax spans through every operand; these are witnesses, not guessed token lengths.
  for i := lNodes.Count - 1 downto 0 do
  begin
    lNode := lNodes[i];
    lDelimiterOpen := 0;
    // Delimiters are paired once by the existing lexer pass. AST kinds determine which
    // pairs belong to calls/indexing/type arguments; token spelling never infers a call.
    if (lNode.SyntaxKind = 'indexed') or
      ((lNode.SyntaxKind = 'expression') and (lNode.OutputStartOffset > 0) and
        (lNode.OutputStartOffset <= Length(aText)) and (aText[lNode.OutputStartOffset] = '(')) then
      lDelimiterOpen := lNode.OutputStartOffset;
    if lNode.SyntaxKind = 'typeargs' then
    begin
      // SimpleParser consumes '<' before invoking TypeArgs, so its AST position is
      // the first type token. Admit only the preceding paired delimiter for this AST kind.
      lDelimiterOpen := PreviousCodeOffset(lCodeOffsets, lNode.OutputStartOffset);
      if (lDelimiterOpen > 0) and (aText[lDelimiterOpen] = '<') and
        lDelimiterEnds.ContainsKey(lDelimiterOpen) then
      begin
        lNode.OutputStartOffset := lDelimiterOpen;
        CoordinatesAtOffset(lStarts, lDelimiterOpen, lNode.Line, lNode.Column);
      end else
        lDelimiterOpen := 0;
    end;
    if (lNode.SyntaxKind = 'call') and (Length(lNode.Children) = 2) then
    begin
      lParent := lNodes[lNode.Children[0] - 1];
      lDelimiterOpen := NextCodeOffset(lCodeOffsets, lParent.OutputEndOffset);
      if (lDelimiterOpen = 0) or (aText[lDelimiterOpen] <> '(') then
        lDelimiterOpen := 0;
    end;
    for j in lNode.Children do
    begin
      lParent := lNodes[j - 1];
      if (lParent.OutputStartOffset > 0) and
        ((lNode.OutputStartOffset = 0) or (lParent.OutputStartOffset < lNode.OutputStartOffset)) then
      begin
        lNode.OutputStartOffset := lParent.OutputStartOffset;
        lNode.Line := lParent.Line;
        lNode.Column := lParent.Column;
      end;
      lEnd := lParent.OutputEndOffset;
      if lEnd > lNode.OutputEndOffset then
      begin
        lNode.OutputEndOffset := lEnd;
        lNode.EndLine := lParent.EndLine;
        lNode.EndColumn := lParent.EndColumn;
      end;
    end;
    if (lDelimiterOpen > 0) and lDelimiterEnds.TryGetValue(lDelimiterOpen, lDelimiterEnd) and
      (lDelimiterEnd.Offset > lNode.OutputEndOffset) then
    begin
      lNode.OutputEndOffset := lDelimiterEnd.Offset;
      lNode.EndLine := lDelimiterEnd.Line;
      lNode.EndColumn := lDelimiterEnd.Column;
    end;
    lNode.SpanKnown := (lNode.OutputStartOffset > 0) and
      (lNode.OutputEndOffset > lNode.OutputStartOffset);
    lNodes[i] := lNode;
  end;
  Result := CreateNameFlowFacts(lNodes.ToArray, lComplete, aConfigurationComplete, lReason);
end;

function SpanIndex(const aSpans: TArray<TDelphiSemanticCopiedSourceSpan>; const aOffset: Integer): Integer;
var
  lo, hi, lMiddle: Integer;
begin
  lo := 0;
  hi := High(aSpans);
  while lo <= hi do
  begin
    lMiddle := lo + (hi - lo) div 2;
    if aOffset < aSpans[lMiddle].OutputStartOffset then
      hi := lMiddle - 1
    else if aOffset >= aSpans[lMiddle].OutputEndOffset then
      lo := lMiddle + 1
    else
      Exit(lMiddle);
  end;
  Result := -1;
end;

function CopiedSpansConnect(const aText: string; const aFirst, aNext: TDelphiSemanticCopiedSourceSpan;
  const aOutputOffsetShift: Integer): Boolean;
var
  lOutputGapStart, lOutputGapLength, lSourceGapStart, lSourceGapLength: Integer;
  lOutputGap, lSourceGap: string;
begin
  Result := False;
  if not SameText(aFirst.FileName, aNext.FileName) or (aFirst.ExpansionId <> aNext.ExpansionId) or
    (aFirst.SourceStartOffset <= 0) or (aNext.SourceStartOffset <= 0) then
    Exit;
  lOutputGapStart := aFirst.OutputEndOffset - aOutputOffsetShift;
  lOutputGapLength := aNext.OutputStartOffset - aFirst.OutputEndOffset;
  lSourceGapStart := aFirst.SourceStartOffset + aFirst.OutputEndOffset - aFirst.OutputStartOffset;
  lSourceGapLength := aNext.SourceStartOffset - lSourceGapStart;
  if (lOutputGapStart < 1) or (lOutputGapLength < 0) or (lSourceGapStart < 1) or
    (lSourceGapLength < 0) or (lOutputGapStart + lOutputGapLength > Length(aText) + 1) or
    (lSourceGapStart + lSourceGapLength > Length(aFirst.SourceText) + 1) then
    Exit;
  // The preprocessor emits line breaks outside copied spans. Validate those gaps against
  // captured source rather than treating every ordinary multi-line routine as incomplete.
  lOutputGap := Copy(aText, lOutputGapStart, lOutputGapLength);
  lSourceGap := Copy(aFirst.SourceText, lSourceGapStart, lSourceGapLength);
  if lOutputGap = lSourceGap then
    Exit(True);
  lOutputGap := StringReplace(StringReplace(lOutputGap, #13#10, #10, [rfReplaceAll]), #13, #10, [rfReplaceAll]);
  lSourceGap := StringReplace(StringReplace(lSourceGap, #13#10, #10, [rfReplaceAll]), #13, #10, [rfReplaceAll]);
  Result := lOutputGap = lSourceGap;
end;

function MapNameFlowFacts(const aFacts: IDelphiNameFlowFacts; const aText: string;
  const aPreprocess: TDelphiSemanticPreprocessResult; const aOutputOffsetShift: Integer): IDelphiNameFlowFacts;
var
  i, lFirst, lLast, lStart, lEnd: Integer;
  lBlocks: TArray<Integer>;
  lNodes: TArray<TDelphiNameFlowNode>;
  lNode: TDelphiNameFlowNode;
  lSpan, lEndSpan: TDelphiSemanticCopiedSourceSpan;
  lComplete: Boolean;
  lReason: string;
begin
{$IFDEF DS_PROJECT_SESSION_TEST_SUPPORT}
  RecordNameFlowWorkForTest(TDelphiNameFlowWorkKind.Map);
{$ENDIF}
  if aFacts = nil then
    Exit(CreateNameFlowFacts(nil, False, False, 'name-flow-facts-missing'));
  SetLength(lBlocks, Length(aPreprocess.CopiedSourceSpans));
  for i := 1 to High(lBlocks) do
  begin
    lSpan := aPreprocess.CopiedSourceSpans[i - 1];
    lEndSpan := aPreprocess.CopiedSourceSpans[i];
    lBlocks[i] := lBlocks[i - 1];
    if not CopiedSpansConnect(aText, lSpan, lEndSpan, aOutputOffsetShift) then
      Inc(lBlocks[i]);
  end;
  lComplete := aFacts.Complete and aPreprocess.Success;
  lReason := aFacts.CoverageReason;
  SetLength(lNodes, aFacts.NodeCount);
  for i := 1 to aFacts.NodeCount do
  begin
    lNode := aFacts.NodeById(i);
    lStart := lNode.OutputStartOffset + aOutputOffsetShift;
    lEnd := lNode.OutputEndOffset + aOutputOffsetShift;
    lFirst := SpanIndex(aPreprocess.CopiedSourceSpans, lStart);
    lLast := SpanIndex(aPreprocess.CopiedSourceSpans, lEnd - 1);
    // Exclusive ends may be the next copied line's start, after an uncopied line break.
    if lLast < 0 then
      lLast := SpanIndex(aPreprocess.CopiedSourceSpans, lEnd);
    lNode.SpanKnown := lNode.SpanKnown and (lFirst >= 0) and (lLast >= 0);
    if lNode.SpanKnown then
    begin
      lSpan := aPreprocess.CopiedSourceSpans[lFirst];
      lEndSpan := aPreprocess.CopiedSourceSpans[lLast];
      lNode.SpanKnown := (lBlocks[lFirst] = lBlocks[lLast]) and
        SameText(lSpan.FileName, lEndSpan.FileName) and
        (lSpan.ExpansionId <> '') and (lSpan.ExpansionId = lEndSpan.ExpansionId) and
        (lSpan.SourceStartOffset > 0) and (lEndSpan.SourceStartOffset > 0);
      if lNode.SpanKnown then
      begin
        lNode.FileName := lSpan.FileName;
        lNode.ExpansionId := lSpan.ExpansionId;
        lNode.Line := lSpan.Line;
        lNode.Column := lSpan.Column + lStart - lSpan.OutputStartOffset;
        lNode.EndLine := lEndSpan.Line;
        lNode.EndColumn := lEndSpan.Column + lEnd - lEndSpan.OutputStartOffset;
        if (lSpan.Line = 1) and (lSpan.SourceText <> '') and (lSpan.SourceText[1] = #$FEFF) then
          Dec(lNode.Column);
        if (lEndSpan.Line = 1) and (lEndSpan.SourceText <> '') and (lEndSpan.SourceText[1] = #$FEFF) then
          Dec(lNode.EndColumn);
      end;
    end;
    lNode.ActivityKnown := aPreprocess.ActivityEvidenceAvailable and not aPreprocess.HasUnknownActivity;
    if not lNode.SpanKnown then
    begin
      // Keep output coordinates separately; physical coordinates are unavailable.
      lNode.FileName := '';
      lNode.Line := 0;
      lNode.Column := 0;
      lNode.EndLine := 0;
      lNode.EndColumn := 0;
      if lNode.Kind <> TDelphiNameFlowNodeKind.Syntax then
      begin
        lComplete := False;
        // Mapping is dischargeable only when extraction had no earlier gap.
        if lReason = '' then
          lReason := 'name-flow-physical-span-unproved';
      end;
    end;
    lNodes[i - 1] := lNode;
  end;
  if not aPreprocess.Success then
    lReason := 'name-flow-preprocess-incomplete';
  Result := CreateNameFlowFacts(lNodes, lComplete,
    aFacts.ConfigurationComplete and aPreprocess.ActivityEvidenceAvailable and not aPreprocess.HasUnknownActivity,
    lReason);
end;

end.
