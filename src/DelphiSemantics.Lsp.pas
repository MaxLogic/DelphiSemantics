unit DelphiSemantics.Lsp;

interface

uses
  DelphiSemantics.Resolve;

type
  TDelphiSemanticLspOptions = record
    Enabled: Boolean;
  end;

  TDelphiSemanticLspLocation = record
    FileName: string;
    Line: Integer;
    Column: Integer;
  end;

  TDelphiSemanticLspResult = record
    Found: Boolean;
    Authoritative: Boolean;
    Status: string;
    Provenance: string;
    Name: string;
    Kind: string;
    TypeName: string;
    OwnerName: string;
    FileName: string;
    Line: Integer;
    Column: Integer;
  end;

  TDelphiSemanticLspBoundary = record
  public
    class function EnrichDefinition(const aOptions: TDelphiSemanticLspOptions;
      const aName: string; const aLocation: TDelphiSemanticLspLocation):
      TDelphiSemanticLspResult; static;
    class function FromSemanticResult(const aResult: TDelphiSemanticResolveResult):
      TDelphiSemanticLspResult; static;
  end;

implementation

class function TDelphiSemanticLspBoundary.EnrichDefinition(
  const aOptions: TDelphiSemanticLspOptions; const aName: string;
  const aLocation: TDelphiSemanticLspLocation): TDelphiSemanticLspResult;
begin
  Result := Default(TDelphiSemanticLspResult);
  if not aOptions.Enabled then
  begin
    Result.Status := 'disabled';
    Exit;
  end;

  Result.Found := True;
  Result.Authoritative := False;
  Result.Status := 'resolved';
  Result.Provenance := 'lsp';
  Result.Name := aName;
  Result.Kind := 'definition';
  Result.FileName := aLocation.FileName;
  Result.Line := aLocation.Line;
  Result.Column := aLocation.Column;
end;

class function TDelphiSemanticLspBoundary.FromSemanticResult(
  const aResult: TDelphiSemanticResolveResult): TDelphiSemanticLspResult;
begin
  Result := Default(TDelphiSemanticLspResult);
  Result.Found := aResult.Found;
  Result.Authoritative := aResult.Authoritative;
  Result.Status := aResult.Status;
  Result.Provenance := 'semantic-model';
  Result.Name := aResult.Name;
  Result.Kind := aResult.Kind;
  Result.TypeName := aResult.TypeName;
  Result.OwnerName := aResult.OwnerName;
  Result.Line := aResult.Line;
  Result.Column := aResult.Column;
end;

end.
