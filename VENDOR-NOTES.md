# Vendor notes

## DelphiAST

Pinned commit: `d07a36411262e6230516b66178c9474ecfc7a467` (DS-812).
The upstream base and lexer delta are documented in `lib/DelphiAST/VENDOR-NOTES.md`.

The terminal-NUL guard also changes the malformed-input case of a NUL embedded
inside a multiline string: the scan now ends with "Unterminated string" instead
of skipping past the NUL. The next iteration's `#0` branch exits the loop.
This supplement records that behavior while preserving the pinned vendor commit.
