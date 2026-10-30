unit B;
interface
uses A, DsrU719;
type
  TOuter = record
    Sub: TX;
  end;
  PX = ^TX;
  TArr = array[0..1] of TX;
  TY = TX;
  THolder = class
  public
    FSub: TX;
  end;
var
  GSub: TX;
implementation
end.
