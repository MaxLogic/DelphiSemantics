unit ChildHelp;
interface
uses TypesUnit, ParentHelp;
type TChildHelp = class helper(TParentHelp) for TRec
end;
implementation
end.
