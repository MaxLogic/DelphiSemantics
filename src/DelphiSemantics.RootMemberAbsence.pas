unit DelphiSemantics.RootMemberAbsence;

interface

type
  // The spelling and lookup context together identify the unindexed root.
  TDelphiSemanticQualifiedRootType = record
    Kind: string;
    TypeName: string;
    // Effective imports at the root-most project declaration, in compiler order.
    // The site imports are supplied separately to the named provider.
    LookupUnits: TArray<string>;
  end;

  IDelphiSemanticNamedRootMemberAbsence = interface
    ['{4E6FE4D3-5605-41ED-BA6B-1BD1AD5324E2}']
    function IsNamedRootMemberAbsent(const aRoot: TDelphiSemanticQualifiedRootType;
      const aSiteUnits: TArray<string>; const aName: string): Boolean;
  end;

  // DS-712: optional exact-name evidence; it never certifies an SDK inventory.
  // Implementations retain immutable compiler inputs while facts/plans use it.
  IDelphiSemanticImplicitRootMemberAbsence = interface
    ['{5F39BB7A-1DC1-4F37-A460-B1A2FBDCB152}']
    function EvidenceFingerprint: string;
    function IsNameAbsent(const aName: string): Boolean;
  end;

implementation

end.
