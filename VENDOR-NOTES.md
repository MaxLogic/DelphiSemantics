# Vendor notes

## DelphiAST

Pinned commit: `791950b5f493217813977d70b7dd4b602bb1bb7f` (DS-832; candidate branch
`eval/ds832`, to be published on the fork's `maxlogic` branch).
The upstream base, the adopted upstream pull requests (#337, #346, #350) and the
pull requests not adopted are documented in `lib/DelphiAST/VENDOR-NOTES.md`.

Upstream #337 replaces the earlier local DS-812 terminal-NUL guard. A NUL
embedded inside a multiline string still ends the scan with "Unterminated
string": the scanner no longer skips any character, so the `#0` branch exits
the loop.

DelphiSemantics model extraction parses its own preprocessor output, so the
lexer's `$IF` evaluator (changed by #346 and #350) does not select branches
there. It does in the dependency-graph `TProjectIndexer` used by project
sessions.
