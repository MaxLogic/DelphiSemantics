unit DelphiSemantics.Resolve;

interface

uses
  DelphiSemantics.Model;

type
  TDelphiSemanticResolveContext = record
    RoutineName: string;
    CurrentTypeName: string;
    SectionKind: string;
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
    class function ResolveName(const aModel: TDelphiSemanticUnitModel;
      const aContext: TDelphiSemanticResolveContext; const aName: string):
      TDelphiSemanticResolveResult; static;
  end;

implementation

uses
  System.SysUtils;

function IsVisibleSection(const aContextSection, aSymbolSection: string): Boolean;
begin
  Result := SameText(aSymbolSection, 'interface') or SameText(aContextSection, 'implementation');
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

function TryResolveLocal(const aModel: TDelphiSemanticUnitModel;
  const aContext: TDelphiSemanticResolveContext; const aName: string;
  out aResult: TDelphiSemanticResolveResult): Boolean;
var
  lLocal: TDelphiSemanticLocal;
begin
  for lLocal in aModel.Locals do
    if SameText(lLocal.RoutineName, aContext.RoutineName) and SameText(lLocal.Name, aName) then
    begin
      aResult := ResolvedResult(lLocal.Name, 'local', lLocal.TypeName, lLocal.RoutineName,
        aContext.SectionKind, lLocal.Line, lLocal.Column);
      Exit(True);
    end;

  aResult := Default(TDelphiSemanticResolveResult);
  Result := False;
end;

function TryResolveParameter(const aModel: TDelphiSemanticUnitModel;
  const aContext: TDelphiSemanticResolveContext; const aName: string;
  out aResult: TDelphiSemanticResolveResult): Boolean;
var
  lParameter: TDelphiSemanticParameter;
  lRoutine: TDelphiSemanticRoutine;
begin
  for lRoutine in aModel.Routines do
    if SameText(lRoutine.Name, aContext.RoutineName) and
      IsVisibleSection(aContext.SectionKind, lRoutine.SectionKind) then
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
  Result := aResult.Found or (aResult.Status = 'ambiguous') or (aResult.Status = 'unsupported');
end;

class function TDelphiSemanticResolver.ResolveMember(const aModel: TDelphiSemanticUnitModel;
  const aOwnerName, aName: string): TDelphiSemanticResolveResult;
var
  lCount: Integer;
  lMember: TDelphiSemanticMember;
begin
  if TryUnsupportedSelector(aName, Result) then
    Exit;

  lCount := 0;
  for lMember in aModel.Members do
    if SameText(lMember.OwnerName, aOwnerName) and SameText(lMember.Name, aName) then
    begin
      if lMember.IsIndexed then
        Exit(UnsupportedResult(aName, 'INDEXED_PROPERTY_UNSUPPORTED',
          'Indexed property member resolution is not part of Level 1.'));
      if lMember.IsDefault then
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

  Result := UnresolvedResult(aName, 'MEMBER_NOT_FOUND',
    'No direct member named "' + aName + '" was found on ' + aOwnerName + '.');
end;

class function TDelphiSemanticResolver.ResolveName(const aModel: TDelphiSemanticUnitModel;
  const aContext: TDelphiSemanticResolveContext; const aName: string):
  TDelphiSemanticResolveResult;
begin
  if TryUnsupportedSelector(aName, Result) then
    Exit;

  if TryResolveLocal(aModel, aContext, aName, Result) then
    Exit;

  if TryResolveParameter(aModel, aContext, aName, Result) then
    Exit;

  if TryResolveCurrentMember(aModel, aContext, aName, Result) then
    Exit;

  if TryResolveUnitDeclaration(aModel, aContext, aName, Result) then
    Exit;

  Result := UnresolvedResult(aName, 'NAME_NOT_FOUND', 'No visible symbol named "' + aName +
    '" was found.');
end;

end.
