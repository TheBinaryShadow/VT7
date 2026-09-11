# GNU Unifont fonts bundled by VT7

Pinned upstream release: 17.0.05, published 2026-06-28.
Source: https://unifoundry.com/pub/unifont/unifont-17.0.05/unifont-17.0.05.tar.gz

Archive SHA256: `F287CFFB26E22723AA36E6684869B0F3FF3BFB822C4B01008BD847911EC1B631`.
Downloaded over HTTPS from the official project site. Hashes pin the downloaded
bytes; independent release-signature verification is not claimed.

The two unmodified static OpenType/CFF files were extracted from `font/precompiled/`:

- `unifont-17.0.05.otf`: `85701AB9B1E251EE16F4DF00B13F22EAC311D72B7DAB427A7D975FE7F5064702`.
- `unifont_upper-17.0.05.otf`: `F4FD6D5D752726D384FEEF175BB780C9F29382CD4941C9E1E6990D7C3822A090`.

VT7 distributes these fonts under the SIL Open Font License 1.1 option offered
by their upstream dual license. See the unmodified `OFL-1.1.txt`, upstream
`COPYING` (which documents both options), and copyright metadata retained in
both font files. Fonts are not relicensed under MIT. No Unifont utility source
code is compiled or linked into VT7; the downloaded full source archive is a
local acquisition artifact, not part of the application package.

`OFL-1.1.txt` SHA256: `869692AF094C57FB7258C57FE26820C759319603321D0FFEB278DE3651763DED`.
`COPYING` SHA256: `CD2785C2B8E0A01D203560265B2D2D47CDB1401D2707D25918AC5531BCDBA947`.

The font name tables identify Unifont / Unifont Upper, Regular, Version 17.0.05,
and explicitly state the dual OFL/GPL-with-font-exception license. They preserve
the upstream copyright holder list. This is a bundled-font attribution, not an
endorsement of VT7 by the font authors.

Copyright notice from both font name tables:

Copyright © 1998-2026 Roman Czyborra, Paul Hardy, Qianqian Fang, Andrew Miller,
Johnnie Weaver, David Corbett, Ælla Chiana Moskopp, Rebecca Bettencourt,
Ho-Seok Ee, et al.

Scope: private fallback assets for the native renderer probe. Files load from
the executable's `fonts` subdirectory after SHA256 validation, without Windows
font installation or system collection registration. Current fallback is limited
to a missing standalone symbol/pictograph scalar in U+2190..U+2BFF or
U+1F000..U+1FAFF occupying one complete core cluster/run. Complex
script runs and multi-scalar sequences are not replaced by raw Unifont glyphs.
The existing shaped system-font paths remain preferred and unchanged.

Unifont supplies monochrome coverage, not modern emoji composition or full
complex-script shaping. Its glyph repertoire does not change TerminalCore's
Unicode width/cluster tables. Probe 0.5 verified these exact font files with
Windows 7 DirectWrite, including visible forced BMP/SMP glyphs and automatic
missing-system U+1F600 fallback. See the source repository's
`doc/vt7/validation/2026-09-11-private-font-probe.md` for evidence and limitations.
This is bounded probe acceptance, not arbitrary font or full Atlas compatibility.
