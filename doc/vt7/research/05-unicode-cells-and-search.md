# Unicode versions, graphemes, terminal cells, bidi and search

Status note, 2026-09-13: this file preserves dated research and proposals,
not current implementation or acceptance claims. Source references and words
such as "current", "next" and "latest" below retain their research-date scope.
Use the [research status](README.md#planning-adoption), [current handoff](../HANDOFF.md)
and [roadmap](../../../ROADMAP.md) for port-first priorities and present evidence.

Research date: 2026-09-11. Priority: P0 for shaping, P1 for interaction.

## Five different units

A byte, UTF-16 code unit, Unicode scalar, grapheme cluster, and glyph are not interchangeable. Terminal cells add another coordinate system. Unicode segmentation defines user-perceived character boundaries; DirectWrite shaping can map characters and glyphs many-to-many. [1][2]

For example, supplementary characters occupy two UTF-16 units, a base-plus-accent may be one grapheme, and a ligature may draw several characters with one glyph. **Recommendation:** use named types or strongly documented ranges for byte offsets, UTF-16 offsets, cluster indexes, cells, and pixels. Never use a glyph count as a terminal column count.

## Existing inherited behavior is modern but tailored

Observed in repository: CodepointWidthDetector.cpp identifies its generated data as Unicode 16.0.0, generated 2024-12-04. Its introductory comments explicitly describe a simplified adjacent-character join table rather than full context-sensitive UAX #29 behavior. That is a documented implementation tradeoff, not a conformance proof. [3]

**Recommendation:** retain the inherited behavior initially, measure discrepancies using version-matched conformance data, and classify intentional tailoring separately from defects. Do not replace it with Windows 7 NLS categories, GDI widths, or a modern .NET implementation without a compatibility decision.

Unicode's East_Asian_Width property distinguishes several width categories and explicitly warns that it is not a complete off-the-shelf terminal-width algorithm. Ambiguous characters require a policy; canonical decomposition also does not preserve that property's values in a simple character-by-character way. [4]

This matters when a remote application's wcwidth/locale disagrees with VT7. **Inference:** identical glyphs do not ensure identical cursor positions. A terminal identity or locale change should be tested with the remote application's width assumptions.

## Cell and cluster policy

Proposed invariants:

- The core assigns cells; the renderer fits shaped clusters into those assignments.
- Cursor movement, selection, mouse reporting, accessibility ranges and resize all use the same core coordinates.
- A continuation cell cannot become a standalone copied character.
- Combining input can extend a preceding cluster across transport writes.
- A font fallback change must not silently change the terminal's declared dimensions.
- Visual overhang and decoration extents are tracked separately from logical cells.
- Reflow distinguishes a soft wrap from an explicit line break.

Test narrow windows, wide characters in the final column, combining-only input, regional indicators, ZWJ sequences, variation selectors, keycaps, Hangul jamo, Indic conjuncts, and style changes inside a potential shaping sequence. The correct expected result must come from the chosen core policy and Unicode version, not from how Notepad happens to display it.

## Bidirectional text is a product decision

UAX #9 specifies display ordering for bidirectional text while text remains in logical order. [5] DirectWrite may return runs with bidi levels, but that does not define how terminal cursor-addressing commands should interact with them.

**Recommendation:** document the current TerminalCore/Atlas ordering policy before adapting text layout. Do not accidentally enable paragraph-style visual reordering just because an IDWriteTextLayout callback makes it convenient. If bidi display is implemented, maintain logical-to-visual mappings for selection, copy, hit testing and cursor placement. Test mixed Hebrew/Arabic, Latin identifiers, numbers, punctuation and explicit directional controls.

No claim is made here that VT7 currently has full bidi support.

## Search, normalization and case behavior

Observed in repository: under VT7_CORE, TextBuffer::SearchText returns std::nullopt because the proof does not ship ICU; URL discovery is also excluded. [6]

Unicode normalization distinguishes canonical forms NFC/NFD from compatibility forms NFKC/NFKD. Compatibility normalization can erase distinctions that matter to technical text. [7]

**Recommendation:** preserve original terminal text. A search engine may offer normalized comparison, but it needs an offset map back to original UTF-16/cell ranges. Do not normalize displayed commands, copied text, file names, or passwords as an incidental rendering fix.

Before restoring search, choose:

| Decision | Consequence |
| --- | --- |
| Literal vs regular-expression search | Dependency footprint and worst-case execution cost |
| Ordinal vs Unicode case folding | Turkish I, Greek sigma and multi-character folds behave differently |
| Canonical equivalence | Precomposed and decomposed accents may compare equal; offsets can change |
| Soft-wrap joining | Search may span visual rows without inserting an artificial newline |
| Snapshot vs locked buffer | Avoid holding the core lock during a long search |
| Unicode version | Reproducible behavior independent of OS update/font inventory |

A private, pinned ICU build is one candidate, not an automatic requirement. Audit its actual Windows 7 dependency closure. The current disabled feature should remain reported as unavailable until an implementation and its semantics are accepted.

## Sources

- [1] Unicode Consortium, [UAX #29: Text Segmentation](https://www.unicode.org/reports/tr29/).
- [2] Microsoft, [IDWriteTextAnalyzer::GetGlyphs](https://learn.microsoft.com/en-us/windows/win32/api/dwrite/nf-dwrite-idwritetextanalyzer-getglyphs).
- [3] [Inherited width/cluster implementation](../../../src/types/CodepointWidthDetector.cpp) and [width tests](../../../src/types/ut_types/CodepointWidthDetectorTests.cpp).
- [4] Unicode Consortium, [UAX #11: East Asian Width](https://www.unicode.org/reports/tr11/).
- [5] Unicode Consortium, [UAX #9: Bidirectional Algorithm](https://www.unicode.org/reports/tr9/).
- [6] [TextBuffer search implementation](../../../src/buffer/out/textBuffer.cpp), [TerminalCore](../../../src/cascadia/TerminalCore/Terminal.cpp), and [proof exclusions](../../../src/vt7/VT7.Core/README.md).
- [7] Unicode Consortium, [UAX #15: Normalization Forms](https://www.unicode.org/reports/tr15/).
