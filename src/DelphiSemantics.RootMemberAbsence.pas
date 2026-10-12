unit DelphiSemantics.RootMemberAbsence;

interface

type
  // DS-712: optional exact-name evidence; it never certifies an SDK inventory.
  // Implementations retain immutable compiler inputs while facts/plans use it.
  IDelphiSemanticImplicitRootMemberAbsence = interface
    ['{5F39BB7A-1DC1-4F37-A460-B1A2FBDCB152}']
    function EvidenceFingerprint: string;
    function IsNameAbsent(const aName: string): Boolean;
  end;

implementation

end.
