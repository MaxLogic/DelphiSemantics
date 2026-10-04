unit DelphiSemantics.Resolve;

interface

uses
  DelphiSemantics.CompilerProfile, DelphiSemantics.Model;

type
  TDelphiSemanticResolveContext = record
    RoutineName: string;
    ParentRoutineNames: TArray<string>;
    CurrentTypeName: string;
    SectionKind: string;
    ConformanceLevel: Integer;
    IntrinsicSymbols: TArray<TDelphiSemanticIntrinsicSymbol>;
    IndexedUnitModels: TArray<TDelphiSemanticUnitModel>;
  end;

  TDelphiSemanticResolveResult = record
    Found: Boolean;
    Authoritative: Boolean;
    Status: string;
    ReasonCode: string;
    Reason: string;
    Name: string;
    Kind: string;
    TypeName: string;
    OwnerName: string;
    SectionKind: string;
    Line: Integer;
    Column: Integer;
  end;

  TDelphiSemanticResolver = record
  public
    class function ResolveMember(const aModel: TDelphiSemanticUnitModel;
      const aOwnerName, aName: string): TDelphiSemanticResolveResult; static;
    class function ResolveMemberAtLevel(const aModel: TDelphiSemanticUnitModel;
      const aOwnerName, aName: string; const aConformanceLevel: Integer):
      TDelphiSemanticResolveResult; static;
    class function ResolveName(const aModel: TDelphiSemanticUnitModel;
      const aContext: TDelphiSemanticResolveContext; const aName: string):
      TDelphiSemanticResolveResult; static;
    class function ResolveSelectorFromBoundBase(const aModel: TDelphiSemanticUnitModel;
      const aContext: TDelphiSemanticResolveContext; const aSelector: string;
      const aBaseResult: TDelphiSemanticResolveResult;
      const aBaseDeclaringModel: TDelphiSemanticUnitModel;
      const aBaseDeclaringSectionKind: string): TDelphiSemanticResolveResult; static;
  end;

implementation

uses
  System.StrUtils, System.SysUtils,
  DelphiSemantics.Resolve.SelectorTypes;

function IsImplementationLikeSection(const aSectionKind: string): Boolean;
begin
  Result := MatchText(aSectionKind, ['implementation', 'initialization', 'finalization']);
end;

function IsVisibleSection(const aContextSection, aSymbolSection: string): Boolean;
begin
  Result := SameText(aSymbolSection, 'interface') or IsImplementationLikeSection(aContextSection);
end;

function EffectiveConformanceLevel(const aContext: TDelphiSemanticResolveContext): Integer;
begin
  if aContext.ConformanceLevel > 0 then
    Result := aContext.ConformanceLevel
  else
    Result := 1;
end;

function ResolvedResult(const aName, aKind, aTypeName, aOwnerName, aSectionKind: string;
  const aLine, aColumn: Integer): TDelphiSemanticResolveResult;
begin
  Result := Default(TDelphiSemanticResolveResult);
  Result.Found := True;
  Result.Authoritative := True;
  Result.Status := 'resolved';
  Result.Name := aName;
  Result.Kind := aKind;
  Result.TypeName := aTypeName;
  Result.OwnerName := aOwnerName;
  Result.SectionKind := aSectionKind;
  Result.Line := aLine;
  Result.Column := aColumn;
end;

function UnresolvedResult(const aName, aReasonCode, aReason: string):
  TDelphiSemanticResolveResult;
begin
  Result := Default(TDelphiSemanticResolveResult);
  Result.Found := False;
  Result.Authoritative := False;
  Result.Status := 'unresolved';
  Result.Name := aName;
  Result.ReasonCode := aReasonCode;
  Result.Reason := aReason;
end;

function AmbiguousResult(const aName, aReasonCode, aReason: string):
  TDelphiSemanticResolveResult;
begin
  Result := Default(TDelphiSemanticResolveResult);
  Result.Found := False;
  Result.Authoritative := False;
  Result.Status := 'ambiguous';
  Result.Name := aName;
  Result.ReasonCode := aReasonCode;
  Result.Reason := aReason;
end;

function UnsupportedResult(const aName, aReasonCode, aReason: string):
  TDelphiSemanticResolveResult;
begin
  Result := Default(TDelphiSemanticResolveResult);
  Result.Found := False;
  Result.Authoritative := False;
  Result.Status := 'unsupported';
  Result.Name := aName;
  Result.ReasonCode := aReasonCode;
  Result.Reason := aReason;
end;

function TryFindTypeAlias(const aModel: TDelphiSemanticUnitModel; const aName: string;
  out aTypeName: string): Boolean;
var
  lDeclaration: TDelphiSemanticDeclaration;
begin
  for lDeclaration in aModel.Declarations do
    if SameText(lDeclaration.Name, aName) and SameText(lDeclaration.Kind, 'type-alias') then
    begin
      aTypeName := lDeclaration.TypeName;
      Exit(True);
    end;

  aTypeName := '';
  Result := False;
end;

function TryFindTypeDeclaration(const aModel: TDelphiSemanticUnitModel; const aName: string;
  out aDeclaration: TDelphiSemanticDeclaration): Boolean;
var
  lDeclaration: TDelphiSemanticDeclaration;
begin
  for lDeclaration in aModel.Declarations do
    if SameText(lDeclaration.Name, aName) and SameText(lDeclaration.Kind, 'type') then
    begin
      aDeclaration := lDeclaration;
      Exit(True);
    end;

  aDeclaration := Default(TDelphiSemanticDeclaration);
  Result := False;
end;

function ResolveTypeAlias(const aModel: TDelphiSemanticUnitModel; const aTypeName: string): string;
var
  lDepth: Integer;
  lCurrent: string;
  lNext: string;
begin
  lCurrent := aTypeName.Trim;
  lDepth := 0;
  while lDepth < 16 do
  begin
    if TryFindTypeAlias(aModel, lCurrent, lNext) then
      lCurrent := lNext.Trim
    else
      Break;
    Inc(lDepth);
  end;

  Result := lCurrent;
end;

function TryUnsupportedSelector(const aName: string;
  out aResult: TDelphiSemanticResolveResult): Boolean;
begin
  if Pos('.', aName) > 0 then
  begin
    aResult := UnsupportedResult(aName, 'QUALIFIED_SELECTOR_UNSUPPORTED',
      'Qualified selector resolution is not part of Level 1.');
    Exit(True);
  end;

  if Pos('[', aName) > 0 then
  begin
    aResult := UnsupportedResult(aName, 'INDEXED_SELECTOR_UNSUPPORTED',
      'Indexed/default property resolution is not part of Level 1.');
    Exit(True);
  end;

  if Pos('(', aName) > 0 then
  begin
    aResult := UnsupportedResult(aName, 'CALL_SELECTOR_UNSUPPORTED',
      'Call-result selector resolution is not part of Level 1.');
    Exit(True);
  end;

  aResult := Default(TDelphiSemanticResolveResult);
  Result := False;
end;

function IsRoutineVariableDeclaration(const aDeclaration: TDelphiSemanticDeclaration): Boolean;
begin
  // Locals are resolved through lexical owners; retain legacy const/type/enum fallback.
  Result := SameText(aDeclaration.Kind, 'var') and SameText(aDeclaration.ScopeKind, 'routine');
end;

function TryResolveLocal(const aModel: TDelphiSemanticUnitModel;
  const aRoutineName, aName, aSectionKind: string;
  out aResult: TDelphiSemanticResolveResult): Boolean;
var
  lCandidate: TDelphiSemanticDeclaration;
  lDeclaration: TDelphiSemanticDeclaration;
  lFound: Boolean;
  lLocal: TDelphiSemanticLocal;
  lLocalCandidate: TDelphiSemanticLocal;
begin
  // Overloads share a routine name, so a name match in two routine scopes is ambiguous.
  lFound := False;
  lLocalCandidate := Default(TDelphiSemanticLocal);
  for lLocal in aModel.Locals do
    if SameText(lLocal.RoutineName, aRoutineName) and SameText(lLocal.Name, aName) then
    begin
      if lFound and ((lLocalCandidate.RoutineScopeId <> lLocal.RoutineScopeId) or
        (lLocalCandidate.Line <> lLocal.Line) or (lLocalCandidate.Column <> lLocal.Column)) then
      begin
        aResult := AmbiguousResult(aName, 'MULTIPLE_LEXICAL_DECLARATIONS',
          'Multiple distinct local declarations match the requested routine owner.');
        Exit(True);
      end;
      lLocalCandidate := lLocal;
      lFound := True;
    end;
  if lFound then
  begin
    aResult := ResolvedResult(lLocalCandidate.Name, 'local', lLocalCandidate.TypeName,
      lLocalCandidate.RoutineName, aSectionKind, lLocalCandidate.Line, lLocalCandidate.Column);
    Exit(True);
  end;

  // A model without extracted locals (for example one built from declarations only) still has
  // AST declarations with their lexical owner, so never use unit-wide fallback.
  lFound := False;
  lCandidate := Default(TDelphiSemanticDeclaration);
  if aRoutineName <> '' then
    for lDeclaration in aModel.Declarations do
      if IsRoutineVariableDeclaration(lDeclaration) and (lDeclaration.OwnerName <> '') and
        SameText(lDeclaration.OwnerName, aRoutineName) and SameText(lDeclaration.Name, aName) then
      begin
        if lFound and ((lCandidate.OwnerScopeId <> lDeclaration.OwnerScopeId) or
          (lCandidate.SymbolId <> lDeclaration.SymbolId) or
          (lCandidate.Line <> lDeclaration.Line) or (lCandidate.Column <> lDeclaration.Column) or
          (lCandidate.Offset <> lDeclaration.Offset) or
          (lCandidate.EndOffset <> lDeclaration.EndOffset) or
          not SameText(lCandidate.TypeName, lDeclaration.TypeName)) then
        begin
          aResult := AmbiguousResult(aName, 'MULTIPLE_LEXICAL_DECLARATIONS',
            'Multiple distinct local declarations match the requested routine owner.');
          Exit(True);
        end;
        lCandidate := lDeclaration;
        lFound := True;
      end;

  if lFound then
  begin
    aResult := ResolvedResult(lCandidate.Name, 'local', lCandidate.TypeName,
      lCandidate.OwnerName, aSectionKind, lCandidate.Line, lCandidate.Column);
    Exit(True);
  end;

  aResult := Default(TDelphiSemanticResolveResult);
  Result := False;
end;

function TryResolveLexicalLocal(const aModel: TDelphiSemanticUnitModel;
  const aContext: TDelphiSemanticResolveContext; const aName: string;
  out aResult: TDelphiSemanticResolveResult): Boolean;
var
  lRoutineName: string;
begin
  if TryResolveLocal(aModel, aContext.RoutineName, aName, aContext.SectionKind, aResult) then
    Exit(True);

  if EffectiveConformanceLevel(aContext) >= 2 then
    for lRoutineName in aContext.ParentRoutineNames do
      if TryResolveLocal(aModel, lRoutineName, aName, aContext.SectionKind, aResult) then
        Exit(True);

  aResult := Default(TDelphiSemanticResolveResult);
  Result := False;
end;

function RoutineNameMatches(const aRoutine: TDelphiSemanticRoutine;
  const aRoutineName: string): Boolean;
begin
  Result := SameText(aRoutine.Name, aRoutineName) or
    ((aRoutine.OwnerName <> '') and SameText(aRoutine.OwnerName + '.' + aRoutine.Name,
    aRoutineName));
end;

function TryResolveParameter(const aModel: TDelphiSemanticUnitModel; const aRoutineName,
  aSectionKind, aName: string;
  out aResult: TDelphiSemanticResolveResult): Boolean;
var
  lParameter: TDelphiSemanticParameter;
  lRoutine: TDelphiSemanticRoutine;
begin
  for lRoutine in aModel.Routines do
    if RoutineNameMatches(lRoutine, aRoutineName) and IsVisibleSection(aSectionKind,
      lRoutine.SectionKind) then
      for lParameter in lRoutine.Parameters do
        if SameText(lParameter.Name, aName) then
        begin
          aResult := ResolvedResult(lParameter.Name, 'parameter', lParameter.TypeName,
            lRoutine.Name, lRoutine.SectionKind, lRoutine.Line, lRoutine.Column);
          Exit(True);
        end;

  aResult := Default(TDelphiSemanticResolveResult);
  Result := False;
end;

function TryResolveLexicalParameter(const aModel: TDelphiSemanticUnitModel;
  const aContext: TDelphiSemanticResolveContext; const aName: string;
  out aResult: TDelphiSemanticResolveResult): Boolean;
var
  lRoutineName: string;
begin
  if TryResolveParameter(aModel, aContext.RoutineName, aContext.SectionKind, aName,
    aResult) then
    Exit(True);

  if EffectiveConformanceLevel(aContext) >= 2 then
    for lRoutineName in aContext.ParentRoutineNames do
      if TryResolveParameter(aModel, lRoutineName, aContext.SectionKind, aName, aResult) then
        Exit(True);

  aResult := Default(TDelphiSemanticResolveResult);
  Result := False;
end;

function TryResolveParentRoutineSymbol(const aModel: TDelphiSemanticUnitModel;
  const aContext: TDelphiSemanticResolveContext; const aName: string;
  out aResult: TDelphiSemanticResolveResult): Boolean;
var
  lRoutineName: string;
begin
  if EffectiveConformanceLevel(aContext) >= 2 then
    for lRoutineName in aContext.ParentRoutineNames do
    begin
      if TryResolveLocal(aModel, lRoutineName, aName, aContext.SectionKind, aResult) then
        Exit(True);
      if TryResolveParameter(aModel, lRoutineName, aContext.SectionKind, aName, aResult) then
        Exit(True);
    end;

  aResult := Default(TDelphiSemanticResolveResult);
  Result := False;
end;

function TryResolveUnitDeclaration(const aModel: TDelphiSemanticUnitModel;
  const aContext: TDelphiSemanticResolveContext; const aName: string;
  out aResult: TDelphiSemanticResolveResult): Boolean;
var
  lCandidateKey: string;
  lCount: Integer;
  lDeclaration: TDelphiSemanticDeclaration;
  lKey: string;
begin
  lCandidateKey := '';
  lCount := 0;
  for lDeclaration in aModel.Declarations do
    if SameText(lDeclaration.Name, aName) and
      not IsRoutineVariableDeclaration(lDeclaration) and
      IsVisibleSection(aContext.SectionKind, lDeclaration.SectionKind) then
    begin
      lKey := LowerCase(lDeclaration.Kind) + '|' + LowerCase(lDeclaration.TypeName);
      if not SameText(lKey, lCandidateKey) then
      begin
        Inc(lCount);
        lCandidateKey := lKey;
      end;
      if SameText(lDeclaration.SectionKind, aContext.SectionKind) or (aResult.Name = '') then
        aResult := ResolvedResult(lDeclaration.Name, lDeclaration.Kind, lDeclaration.TypeName, '',
          lDeclaration.SectionKind, lDeclaration.Line, lDeclaration.Column);
    end;

  if lCount > 1 then
    aResult := AmbiguousResult(aName, 'MULTIPLE_VISIBLE_DECLARATIONS',
      'Multiple visible declarations named "' + aName + '" were found.');

  if lCount > 0 then
    Exit(True);

  aResult := Default(TDelphiSemanticResolveResult);
  Result := False;
end;

function TryResolveIndexedUnitDeclaration(const aContext: TDelphiSemanticResolveContext;
  const aName: string; out aResult: TDelphiSemanticResolveResult): Boolean;
var
  lCount: Integer;
  lDeclaration: TDelphiSemanticDeclaration;
  lModel: TDelphiSemanticUnitModel;
begin
  if EffectiveConformanceLevel(aContext) < 3 then
  begin
    aResult := Default(TDelphiSemanticResolveResult);
    Exit(False);
  end;

  lCount := 0;
  for lModel in aContext.IndexedUnitModels do
    for lDeclaration in lModel.Declarations do
      if SameText(lDeclaration.Name, aName) and
        not IsRoutineVariableDeclaration(lDeclaration) and
        SameText(lDeclaration.SectionKind, 'interface') then
      begin
        Inc(lCount);
        aResult := ResolvedResult(lDeclaration.Name, lDeclaration.Kind, lDeclaration.TypeName,
          lModel.UnitName, lDeclaration.SectionKind, lDeclaration.Line, lDeclaration.Column);
      end;

  if lCount > 1 then
    aResult := AmbiguousResult(aName, 'MULTIPLE_INDEXED_DECLARATIONS',
      'Multiple indexed source declarations named "' + aName + '" were found.');

  if lCount > 0 then
    Exit(True);

  aResult := Default(TDelphiSemanticResolveResult);
  Result := False;
end;

function TryResolveIntrinsic(const aContext: TDelphiSemanticResolveContext; const aName: string;
  out aResult: TDelphiSemanticResolveResult): Boolean;
var
  lSymbol: TDelphiSemanticIntrinsicSymbol;
begin
  if EffectiveConformanceLevel(aContext) < 3 then
  begin
    aResult := Default(TDelphiSemanticResolveResult);
    Exit(False);
  end;

  for lSymbol in aContext.IntrinsicSymbols do
    if SameText(lSymbol.Name, aName) then
    begin
      aResult := ResolvedResult(lSymbol.Name, lSymbol.Kind, lSymbol.TypeName,
        lSymbol.OwnerName, 'intrinsic', 0, 0);
      Exit(True);
    end;

  if SameText(aName, 'Length') then
  begin
    aResult := ResolvedResult(aName, 'intrinsic-routine', 'Integer', 'compiler', 'intrinsic',
      0, 0);
    Exit(True);
  end;

  if SameText(aName, 'Assigned') then
  begin
    aResult := ResolvedResult(aName, 'intrinsic-routine', 'Boolean', 'compiler', 'intrinsic',
      0, 0);
    Exit(True);
  end;

  if SameText(aName, 'TObject') then
  begin
    aResult := ResolvedResult(aName, 'intrinsic-type', 'class', 'rtl', 'intrinsic', 0, 0);
    Exit(True);
  end;

  aResult := Default(TDelphiSemanticResolveResult);
  Result := False;
end;

function TryResolveCurrentMember(const aModel: TDelphiSemanticUnitModel;
  const aContext: TDelphiSemanticResolveContext; const aName: string;
  out aResult: TDelphiSemanticResolveResult): Boolean;
begin
  if aContext.CurrentTypeName = '' then
  begin
    aResult := Default(TDelphiSemanticResolveResult);
    Exit(False);
  end;

  aResult := TDelphiSemanticResolver.ResolveMember(aModel, aContext.CurrentTypeName, aName);
  if EffectiveConformanceLevel(aContext) >= 2 then
    aResult := TDelphiSemanticResolver.ResolveMemberAtLevel(aModel, aContext.CurrentTypeName,
      aName, EffectiveConformanceLevel(aContext));
  Result := aResult.Found or (aResult.Status = 'ambiguous') or (aResult.Status = 'unsupported');
end;

procedure ContinueLevel2Selector(const aModel: TDelphiSemanticUnitModel;
  const aContext: TDelphiSemanticResolveContext; const aSelector: string;
  const aParts: TArray<string>; const aFirstIndexed, aFirstDereferenced,
  aFirstIndexBeforeDereference: Boolean; var aResult: TDelphiSemanticResolveResult;
  const aBaseDeclaringModel: TDelphiSemanticUnitModel;
  const aBaseDeclaringSectionKind: string);
var
  i: Integer;
  lCurrentTypeName: string;
  lCurrentModel: TDelphiSemanticUnitModel;
  lCurrentSection: string;
  lLookupContext: TDelphiSemanticResolveContext;
  lDereferenced: Boolean;
  lIndexBeforeDereference: Boolean;
  lIndexed: Boolean;
  lMemberName: string;
  lPart: string;
  lResolvedTypeName: string;
  lIndexedModel: TDelphiSemanticUnitModel;
begin
  lLookupContext := aContext;
  lLookupContext.IndexedUnitModels := VisibleSelectorModels(aModel, aContext);
  if not aResult.Found then
    Exit;

  lCurrentModel := aModel;
  lCurrentSection := aContext.SectionKind;
  if aBaseDeclaringModel.UnitName <> '' then
  begin
    lCurrentModel := aBaseDeclaringModel;
    lCurrentSection := aBaseDeclaringSectionKind;
  end else if (aResult.OwnerName <> '') and SameText(aResult.SectionKind, 'interface') then
    for lIndexedModel in lLookupContext.IndexedUnitModels do
      if SameText(lIndexedModel.UnitName, aResult.OwnerName) then
      begin
        lCurrentModel := lIndexedModel;
        lCurrentSection := 'interface';
        Break;
      end;

  if not TryApplySelectorPostfix(aContext, lCurrentModel, lCurrentSection,
    aResult.TypeName, aFirstIndexed, aFirstDereferenced,
    aFirstIndexBeforeDereference, lCurrentTypeName) then
  begin
    aResult := UnresolvedResult(aSelector, 'SELECTOR_TYPE_NOT_RESOLVED',
      'The selector receiver type could not be resolved.');
    Exit;
  end;
  aResult.TypeName := lCurrentTypeName;

  for i := 1 to High(aParts) do
  begin
    lPart := aParts[i];
    if not ParseSelectorToken(lPart, lMemberName, lIndexed, lDereferenced,
      lIndexBeforeDereference) then
    begin
      aResult := UnresolvedResult(aSelector, 'SELECTOR_TOKEN_NOT_RESOLVED',
        'The selector token could not be resolved.');
      Exit;
    end;

    if not TryResolveSelectorType(aContext, lCurrentModel, lCurrentSection,
      lCurrentTypeName) then
    begin
      aResult := UnresolvedResult(aSelector, 'SELECTOR_TYPE_NOT_RESOLVED',
        'The selector receiver type could not be resolved.');
      Exit;
    end;
    aResult := TDelphiSemanticResolver.ResolveMemberAtLevel(lCurrentModel,
      lCurrentTypeName, lMemberName, EffectiveConformanceLevel(aContext));
    if not aResult.Found then
      Exit;

    if lIndexed and SameText(aResult.Kind, 'property') then
    begin
      lResolvedTypeName := aResult.TypeName;
      if lDereferenced and not TryApplyDereferencePostfix(aContext, lCurrentModel,
        lCurrentSection, lResolvedTypeName) then
      begin
        aResult := UnresolvedResult(aSelector, 'SELECTOR_TYPE_NOT_RESOLVED',
          'The selector receiver type could not be resolved.');
        Exit;
      end;
    end else if not TryApplySelectorPostfix(aContext, lCurrentModel, lCurrentSection,
      aResult.TypeName, lIndexed, lDereferenced,
      lIndexBeforeDereference, lResolvedTypeName) then
    begin
      aResult := UnresolvedResult(aSelector, 'SELECTOR_TYPE_NOT_RESOLVED',
        'The selector receiver type could not be resolved.');
      Exit;
    end;
    lCurrentTypeName := lResolvedTypeName;
    aResult.TypeName := lCurrentTypeName;
  end;

end;

function TryResolveLevel2Selector(const aModel: TDelphiSemanticUnitModel;
  const aContext: TDelphiSemanticResolveContext; const aSelector: string;
  out aResult: TDelphiSemanticResolveResult): Boolean;
var
  lDereferenced: Boolean;
  lIndexBeforeDereference: Boolean;
  lIndexed: Boolean;
  lLookupContext: TDelphiSemanticResolveContext;
  lMemberName: string;
  lParts: TArray<string>;
begin
  aResult := Default(TDelphiSemanticResolveResult);
  if (EffectiveConformanceLevel(aContext) < 2) or
    ((Pos('.', aSelector) = 0) and (Pos('[', aSelector) = 0) and (Pos('^', aSelector) = 0)) then
    Exit(False);
  lParts := aSelector.Split(['.']);
  if (Length(lParts) = 0) or
    not ParseSelectorToken(lParts[0], lMemberName, lIndexed, lDereferenced,
      lIndexBeforeDereference) then
    Exit(False);
  lLookupContext := aContext;
  lLookupContext.IndexedUnitModels := VisibleSelectorModels(aModel, aContext);
  aResult := TDelphiSemanticResolver.ResolveName(aModel, lLookupContext, lMemberName);
  ContinueLevel2Selector(aModel, aContext, aSelector, lParts, lIndexed,
    lDereferenced, lIndexBeforeDereference, aResult,
    Default(TDelphiSemanticUnitModel), '');
  Result := True;
end;

class function TDelphiSemanticResolver.ResolveSelectorFromBoundBase(
  const aModel: TDelphiSemanticUnitModel;
  const aContext: TDelphiSemanticResolveContext; const aSelector: string;
  const aBaseResult: TDelphiSemanticResolveResult;
  const aBaseDeclaringModel: TDelphiSemanticUnitModel;
  const aBaseDeclaringSectionKind: string): TDelphiSemanticResolveResult;
var
  lDereferenced: Boolean;
  lIndexBeforeDereference: Boolean;
  lIndexed: Boolean;
  lMemberName: string;
  lParts: TArray<string>;
begin
  Result := aBaseResult;
  if not Result.Found then
    Exit;
  if (aBaseDeclaringModel.UnitName = '') or
    ((not SameText(aBaseDeclaringSectionKind, 'interface')) and
    (not SameText(aBaseDeclaringSectionKind, 'implementation'))) then
    Exit(UnresolvedResult(aSelector, 'SELECTOR_TYPE_NOT_RESOLVED',
      'The bound selector declaring type could not be identified.'));
  if (EffectiveConformanceLevel(aContext) < 2) or
    ((Pos('.', aSelector) = 0) and (Pos('[', aSelector) = 0) and (Pos('^', aSelector) = 0)) then
    Exit(UnresolvedResult(aSelector, 'SELECTOR_TOKEN_NOT_RESOLVED',
      'The selector token could not be resolved.'));
  lParts := aSelector.Split(['.']);
  if (Length(lParts) = 0) or
    not ParseSelectorToken(lParts[0], lMemberName, lIndexed, lDereferenced,
      lIndexBeforeDereference) or not SameText(lMemberName, aBaseResult.Name) then
    Exit(UnresolvedResult(aSelector, 'SELECTOR_TOKEN_NOT_RESOLVED',
      'The selector token could not be resolved.'));
  ContinueLevel2Selector(aModel, aContext, aSelector, lParts, lIndexed,
    lDereferenced, lIndexBeforeDereference, Result, aBaseDeclaringModel,
    aBaseDeclaringSectionKind);
end;

class function TDelphiSemanticResolver.ResolveMember(const aModel: TDelphiSemanticUnitModel;
  const aOwnerName, aName: string): TDelphiSemanticResolveResult;
begin
  Result := ResolveMemberAtLevel(aModel, aOwnerName, aName, 1);
end;

class function TDelphiSemanticResolver.ResolveMemberAtLevel(const aModel: TDelphiSemanticUnitModel;
  const aOwnerName, aName: string; const aConformanceLevel: Integer):
  TDelphiSemanticResolveResult;
var
  lDeclaration: TDelphiSemanticDeclaration;
  lCount: Integer;
  lMember: TDelphiSemanticMember;
begin
  if TryUnsupportedSelector(aName, Result) then
    Exit;

  lCount := 0;
  for lMember in aModel.Members do
    if (SameText(lMember.OwnerName, aOwnerName) or ((aConformanceLevel >= 2) and
      SameText(lMember.OwnerName, ResolveTypeAlias(aModel, aOwnerName)))) and
      SameText(lMember.Name, aName) then
    begin
      if (aConformanceLevel < 2) and lMember.IsIndexed then
        Exit(UnsupportedResult(aName, 'INDEXED_PROPERTY_UNSUPPORTED',
          'Indexed property member resolution is not part of Level 1.'));
      if (aConformanceLevel < 2) and lMember.IsDefault then
        Exit(UnsupportedResult(aName, 'DEFAULT_PROPERTY_UNSUPPORTED',
          'Default property member resolution is not part of Level 1.'));
      Inc(lCount);
      Result := ResolvedResult(lMember.Name, lMember.Kind, lMember.TypeName, lMember.OwnerName,
        '', lMember.Line, lMember.Column);
    end;

  if lCount > 1 then
    Exit(AmbiguousResult(aName, 'MULTIPLE_MEMBER_CANDIDATES',
      'Multiple direct members named "' + aName + '" were found on ' + aOwnerName + '.'));

  if lCount > 0 then
    Exit;

  if (aConformanceLevel >= 3) and TryFindTypeDeclaration(aModel, aOwnerName, lDeclaration) and
    (lDeclaration.BaseTypeName <> '') then
  begin
    Result := ResolveMemberAtLevel(aModel, lDeclaration.BaseTypeName, aName, aConformanceLevel);
    if Result.Found or (Result.Status = 'ambiguous') then
      Exit;
  end;

  if aConformanceLevel >= 3 then
  begin
    lCount := 0;
    for lDeclaration in aModel.Declarations do
      if SameText(lDeclaration.HelperTargetName, aOwnerName) then
        for lMember in aModel.Members do
          if SameText(lMember.OwnerName, lDeclaration.Name) and SameText(lMember.Name, aName) then
          begin
            Inc(lCount);
            Result := ResolvedResult(lMember.Name, lMember.Kind, lMember.TypeName,
              lMember.OwnerName, '', lMember.Line, lMember.Column);
          end;
    if lCount > 1 then
      Exit(AmbiguousResult(aName, 'MULTIPLE_HELPER_MEMBER_CANDIDATES',
        'Multiple helper members named "' + aName + '" were found on ' + aOwnerName + '.'));
    if lCount > 0 then
      Exit;
  end;

  Result := UnresolvedResult(aName, 'MEMBER_NOT_FOUND',
    'No direct member named "' + aName + '" was found on ' + aOwnerName + '.');
end;

class function TDelphiSemanticResolver.ResolveName(const aModel: TDelphiSemanticUnitModel;
  const aContext: TDelphiSemanticResolveContext; const aName: string):
  TDelphiSemanticResolveResult;
begin
  if TryResolveLevel2Selector(aModel, aContext, aName, Result) then
    Exit;

  if TryUnsupportedSelector(aName, Result) then
    Exit;

  if TryResolveLocal(aModel, aContext.RoutineName, aName, aContext.SectionKind, Result) then
    Exit;

  if TryResolveParameter(aModel, aContext.RoutineName, aContext.SectionKind, aName, Result) then
    Exit;

  if TryResolveCurrentMember(aModel, aContext, aName, Result) then
    Exit;

  if TryResolveParentRoutineSymbol(aModel, aContext, aName, Result) then
    Exit;

  if TryResolveUnitDeclaration(aModel, aContext, aName, Result) then
    Exit;

  if TryResolveIndexedUnitDeclaration(aContext, aName, Result) then
    Exit;

  if TryResolveIntrinsic(aContext, aName, Result) then
    Exit;

  Result := UnresolvedResult(aName, 'NAME_NOT_FOUND', 'No visible symbol named "' + aName +
    '" was found.');
end;

end.
