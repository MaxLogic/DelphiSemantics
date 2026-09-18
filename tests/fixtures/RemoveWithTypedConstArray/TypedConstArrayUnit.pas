unit TypedConstArrayUnit;

// T-290 fixture: the TDB02 ResWords shape. A with statement selects one element of a typed-constant
// array of packed records inside a nested routine, indexed by a local Word. Words is the same shape
// declared as a variable, as a control. Emit is a sibling nested routine, as SetByte is in TDB02.

interface

const
  NRes = 3;

type
  TReservedItem = packed record
    s: string[9];
    l: AnsiChar;
    p: AnsiChar;
  end;

const
  ResWords: array[1..NRes] of TReservedItem =
    ((s: 'ABS'; l: 'a'; p: 'n'),
    (s: 'AND'; l: '&'; p: #0),
    (s: 'OR'; l: '|'; p: #0));
  // A typed constant whose name matches a record field below: in "with Pair, B do" the field wins.
  B: TReservedItem = (s: 'B'; l: 'b'; p: #0);

type
  TInner = record
    l: AnsiChar;
  end;

  TPair = record
    B: TInner;
    n: Integer;
  end;
  PPair = ^TPair;
  TMask = record
    Art: Integer;
  end;
  PMask = ^TMask;

var
  Words: array[1..NRes] of TReservedItem;
  Pair: TPair;
  Masks: array[1..2] of PMask;
  Output: string;

function FindConstWord(const aKey: ShortString): Boolean;
function FindVarWord(const aKey: ShortString): Boolean;
function PairMemberText: string;
function PairPointerText: string;

implementation

function FindConstWord(const aKey: ShortString): Boolean;

  procedure Emit(aValue: AnsiChar);
  begin
    Output := Output + string(aValue);
  end;

  function CheckResWord: Boolean;
  var
    m: Word;
  begin
    Result := False;
    for m := 1 to NRes do
      if ResWords[m].s = aKey then
      begin
        with ResWords[m] do
        begin
          if p <> #0 then
            Emit(p);
          Emit(l);
        end;
        Exit(True);
      end;
  end;

begin
  Result := CheckResWord;
end;

function FindVarWord(const aKey: ShortString): Boolean;

  procedure Emit(aValue: AnsiChar);
  begin
    Output := Output + string(aValue);
  end;

  function CheckWord: Boolean;
  var
    m: Word;
  begin
    Result := False;
    for m := 1 to NRes do
      if Words[m].s = aKey then
      begin
        with Words[m] do
        begin
          if p <> #0 then
            Emit(p);
          Emit(l);
        end;
        Exit(True);
      end;
  end;

begin
  Result := CheckWord;
end;

function PairMemberText: string;
begin
  Pair.B.l := 'm';
  with Pair, B do
    Result := string(l);
end;

function PairPointerText: string;
var
  i: Integer;
  q: PPair;
begin
  Result := '';
  for i := 1 to 2 do
    with Masks[i]^ do
      if Art = i then
      begin
        New(q);
        with q^, B do
        begin
          n := i;
          l := AnsiChar(Ord('0') + i);
          Result := Result + string(l);
        end;
        Dispose(q);
      end;
end;

end.
