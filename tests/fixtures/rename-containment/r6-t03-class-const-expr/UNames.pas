unit UNames;
interface
type
  TNames = class
  public
    const Pre = 'Co';
    const Suf = 'unt';
  end;
const
  cName = TNames.Pre + TNames.Suf;
implementation
end.
