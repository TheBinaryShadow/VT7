# UT01: current-upstream Unicode, text and font parity before 1.0

Decision/research date: 2026-10-05.
Status: owner-approved required scope and delivery plan; parity is not implemented
or accepted. The owner explicitly selected Unicode, text rendering and font
fallback, rather than the entire Windows Terminal feature set.
The [roadmap](../../../ROADMAP.md#ut01-current-upstream-text-and-font-parity)
owns completion. This decision supersedes earlier deferral of capabilities
needed for this parity target, while preserving historical evidence and the
Windows 7 platform floor.

## Completed work and present baseline

| Area | Recorded result | Remaining boundary |
| --- | --- | --- |
| TerminalCore and Atlas integration | C1/C2, bounded repaint/recovery and actual 96/120/144 system-DPI slices accepted on Windows 7. | Full renderer qualification and broader font behavior are incomplete. |
| Session/document/view ownership | 3A separates TerminalCore/session lifetime from HWND/WPF presentation. Streaming UTF-8 generations and serialized input/resize boundaries are implemented. | Complete interactive selection, IME and accessibility qualification remains open. |
| Local shells | Command Prompt/WinPTY, Windows PowerShell 5.1 and exact PowerShell 7.2.24 accepted for their recorded corpus; keyboard and scrollback corrections accepted. | WinPTY fidelity limits remain independently measured. |
| SSH | Direct and typed SSH.NET paths, remote PTY/resize, original-shell return and tested Unicode/TUI workflows accepted. | Final terminal-only authentication/trust UX and broader lifecycle gates remain open. |
| Known hosts | KH01.1-KH01.5 accepted, including OpenSSH-compatible trust, durable addition/removal, exact backup and live host-certificate matrix. | This does not qualify unrelated text/rendering capabilities. |
| Legacy tier | LEOPARD works without WMF 5.1 or installed OpenSSH; live typed/direct SSH, resize, TUI and exit are confirmed. | PowerShell 2.0's full interactive editor corpus remains unqualified. |
| SL01.1 | Application 0.14.0, native ABI 11, candidate 0.4: 24 returned stages plus live shutdown/disconnect/reconnect checks accepted on LEOPARD, NESSY and TURTLE. | Explicit Disconnect SSH was tested; network-loss timing is not accepted. |
| Prompt finding | UTF-8 f0 92 80 b2 identifies U+12032 CUNEIFORM SIGN ANSHE; Croatian letters work. The older package also misses this glyph. | Pre-existing font coverage gap; now a required UT01 regression fixture. |

The current issued native baseline remains 0.12.3. SL01.1 changed managed lifetime
handling, not the renderer, fonts or pinned SSH.NET closure. Its acceptance
record and exact package identity are in the
[SL01.1 record](../validation/2026-10-05-ssh-lifecycle-sl01-1.md).
Use the [handoff](../HANDOFF.md) and [index](../README.md) for each older result.
None of those passes establishes current-upstream text parity.

## What one-to-one support means

For equivalent input, profile/font settings and available font assets, VT7 must
match the selected upstream Terminal's supported text behavior: source text,
cluster/cell allocation, glyph availability, shaping and ordering, style,
decorations, emoji presentation, wrapping/reflow and associated interactions.
Differences introduced by the Windows 7 adapter must be fixed before 1.0.

This includes upstream-supported font family fallback preferences, weight and
style, OpenType features, variable axes, color-font/emoji paths, and relevant
text measurement settings. These are required capability audits and delivery
gates, not permission to mark them optional because newer DirectWrite APIs are
absent. Match what the reference actually supports; do not invent paragraph
bidi, ligature or emoji behavior that upstream does not provide.

Support parity is distinct from identical antialiasing pixels on different OS,
GPU and font rasterizer versions. Matched-font tests compare actual shaping,
placement, ink bounds and legibility under declared tolerances. The release
record must name any raster-only differences. A missing character, broken join,
wrong width, unreadable required glyph or incorrect selection is not a
raster-only difference.

Neither Terminal nor a font guarantees a glyph for every Unicode scalar.
Do not promise universal Unicode repertoire. Equally, do not use Windows 7's
smaller default font collection as a blanket exemption for upstream-visible
characters. Required missing coverage needs an app-local, legally distributable
font solution or another verified implementation. Copying modern Windows system
fonts into the portable package is not a distribution plan.

The whole Windows Terminal feature set, modern deployment/composition and
ConPTY remain outside this new scope. Existing UI01/SSHUX01 requirements remain
separate and required before polish/1.0.

## Reproducible upstream reference

The initial current stable reference, verified on 2026-10-05, is
[Windows Terminal v1.25.2733.0](https://github.com/microsoft/terminal/releases/tag/v1.25.2733.0),
released 2026-10-02. Its tag resolves locally to commit
dc8ae365847d41f62d1ebca93815bb00959bc12f. The unpackaged distribution's internal
binary version is 1.25.260930003; capture actual binary hashes rather than
assuming its file version equals the release tag.

VT7's source provenance stays pinned to main commit
c7572cde0c69733e4511787dc963eb336f17adbf from 2026-08-25. The parity reference
is a behavior target, not an automatic upstream merge or source downgrade.
Focused source updates retain authorship, dependency review and Windows 7
import/runtime checks under [UPSTREAM.md](../../../UPSTREAM.md).

Inspect the then-current stable release again before the 1.0 release freeze.
Record its tag, full commit, binaries and all text/font changes since the
accepted reference. Update the corpus and resolve applicable deltas before
claiming parity. Preview/main changes are tracked separately; the initial
reference is stable, not a moving development branch. A subsequent stable
release requires explicit delta review, not an unrecorded reference change.

The owner's Windows Terminal screenshot,
codex-clipboard-2fa65da9-0c33-49d9-a94f-04a715454c7f.png, is retained as a
visual reference from the same Debian server. It shows a root prompt and a
visible symbol; the earlier VT7 byte dump came from sshtest. The screenshot
does not supply Terminal version, font hashes or that root symbol's scalar,
so it is supporting evidence rather than a controlled same-character pass.
UT01.1 must reproduce U+12032 explicitly in both applications.

The source-only inspection is retained under
artifacts/vt7/evidence/upstream-text-font-parity-20261005/SOURCE-AUDIT.json,
with baseline/reference Git blob identities. The copied owner screenshot has
SHA256 507E3686E081A25B4E6108F15BA8D9075E96ADC78CB70B536D919180FE90228D.
This evidence does not include a captured reference binary/font corpus, so
UT01.1 remains incomplete.

## Research and initial gap inventory

The stable tag was inspected using local Git objects; no upstream files were
merged. In that reference:

- Atlas resolves an ordered family list, using the first available family for
  the primary grid and later families for fallback before system fallback.
  See [font resolution](https://github.com/microsoft/terminal/blob/dc8ae365847d41f62d1ebca93815bb00959bc12f/src/renderer/atlas/AtlasEngine.api.cpp).
- Its [font mapping](https://github.com/microsoft/terminal/blob/dc8ae365847d41f62d1ebca93815bb00959bc12f/src/renderer/atlas/AtlasEngine.cpp)
  uses DirectWrite system/custom fallback and an axis-aware path when configured.
- Its [width detector](https://github.com/microsoft/terminal/blob/dc8ae365847d41f62d1ebca93815bb00959bc12f/src/types/CodepointWidthDetector.cpp)
  records generated Unicode 16.0.0 data and deliberately adapted grapheme rules.
  Preserve the actual upstream rules and modes rather than substituting the
  host OS tables or treating Unifont 17's version as a core-width upgrade.
- The release adds/supports configurable ambiguous width and expanded built-in
  legacy-computing glyphs. Inventory actual settings and fixtures; several
  relevant sources are already inherited from VT7's newer main baseline.
  Do not assume every feature requires importing a new implementation.
- The [D2D backend](https://github.com/microsoft/terminal/blob/dc8ae365847d41f62d1ebca93815bb00959bc12f/src/renderer/atlas/BackendD2D.cpp)
  contains color-glyph translation/drawing. Audit both Atlas backends and all
  font formats exercised by upstream, not just a monochrome sample.

| Current VT7 gap | Implementation evidence | Required disposition |
| --- | --- | --- |
| Private fallback restricted to standalone U+2190-U+2BFF and U+1F000-U+1FAFF | Win7FontFallback.cpp; U+12032 lies outside both ranges. | Replace the narrow coverage policy with a tested sequence-aware repertoire policy. |
| Secondary family preferences rejected | VT7_ATLAS branch in AtlasEngine.api.cpp returns E_NOTIMPL. | Implement upstream-equivalent ordered family selection and primary-grid ownership. |
| Nearby font loading disabled | RendererFeatures.hpp. | Audit upstream nearby/custom collection behavior and implement supported equivalent loading and lifetime rules. |
| Variable axes rejected | VT7_ATLAS branch in AtlasEngine.api.cpp. | Deliver applicable upstream axis behavior through a verified compatible path. |
| Color glyphs forcibly disabled | VT7_ATLAS branch sets colorGlyphs=false. | Deliver applicable upstream color/emoji rendering and sequence behavior. |
| Layout callbacks choose the face for an entire core cluster from its starting face | Win7FontFallback.cpp. | Prove context, cluster coverage and shaping against upstream; a nonzero scalar glyph alone is insufficient. |
| Wider interaction and renderer qualification incomplete | Existing 2C/2F/3C and REL01 records. | Integrate parity with original-text/cell mapping and product qualification; keep REL01's conditional investigation policy. |

Windows 7 can use baseline
[IDWriteTextAnalyzer::GetGlyphs](https://learn.microsoft.com/en-us/windows/win32/api/dwrite/nf-dwrite-idwritetextanalyzer-getglyphs).
However, [IDWriteFontFallback](https://learn.microsoft.com/en-us/windows/win32/api/dwrite_2/nn-dwrite_2-idwritefontfallback)
and [TranslateColorGlyphRun](https://learn.microsoft.com/en-us/windows/win32/api/dwrite_2/nf-dwrite_2-idwritefactory2-translatecolorglyphrun)
start at Windows 8.1, while
[IDWriteFontFace5](https://learn.microsoft.com/en-us/windows/win32/api/dwrite_3/nn-dwrite_3-idwritefontface5)
starts at Windows 10 build 16299. Exposing their SDK declarations does not
implement them. These are concrete adaptation gaps, not evidence that parity
is already possible with the current adapter.

Prefer baseline DirectWrite plus owned font collection/mapping where it passes
the comparison. For shaping, axes or color formats that cannot match through
those interfaces, evaluate a bounded app-local implementation. A portable
font stack is a candidate, not a selected dependency: [HarfBuzz](https://harfbuzz.github.io/what-is-harfbuzz.html)
provides shaping and [FreeType](https://freetype.org/freetype2/docs/index.html)
provides font access/rasterization; neither alone implements Terminal's fallback,
core widths or all rendering behavior. Any candidate needs target build/import,
license/security, output-equivalence and cost evidence before adoption.
This plan adds no runtime, fonts, prerequisite or system DLL replacement.

## Delivery slices and ownership

| Slice | Deliverable | Acceptance gate |
| --- | --- | --- |
| UT01.1: reference and gap ledger | Pin stable binaries/source, font identities/settings and a shared corpus. Audit VT7 branches, upstream tests and newer API needs. | Every in-scope capability has an upstream expectation, fixture, owner and status; unknown feasibility is recorded, not passed. |
| UT01.2: coverage and font selection | Sequence-aware fallback, ordered families, app-local font collections and missing-family behavior; U+12032 first regression. | Required characters/sequences render with declared font evidence and unchanged source/cells/styles on all Windows 7 tiers. |
| UT01.3: core and shaping equivalence | Grapheme/width modes, ambiguous width, built-in glyphs, scripts, ligatures, features and fallback context. | Differential core/shaping corpus and resize/reflow tests match the selected upstream behavior. |
| UT01.4: advanced font parity | Required color emoji/font formats, variation selectors/ZWJ behavior and variable axes through compatible implementations. | Capability and visual comparisons pass for upstream-supported cases; monochrome substitution or ignored axes cannot count as parity. |
| UT01.5: settings and interaction | Expose required font/text controls through Milestone 4; align cursor, selection/copy/search, IME and accessibility through Milestone 3C. | Same settings take effect; original text and core-cell geometry agree across consumers. |
| UT01.6: assembled acceptance | Hardware/WARP, DPI, all Windows 7 tiers, streaming/local/SSH and a fresh portable extraction; final stable-release delta review. | All required comparisons pass, no unresolved capability gap, licenses/dependency closure complete. |

Milestone 2C owns mapping/shaping/font implementation; 2F owns integrated
rendering comparisons; 3C/4 own consumers and settings; Milestone 6 owns assembled
qualification. UT01 must be complete before Milestone 7 polish and before 1.0.
Do not create a separate optional typography research detour or abandon the
ongoing bounded SSH lifecycle work. First establish UT01.1's inventory/corpus,
then deliver isolated slices in dependency order alongside the owning milestones.

## Comparison corpus and evidence

Each fixture records source scalars/UTF-8 bytes, settings, locale, expected core
clusters/cells, allowed shaping/paint results and original-text round trips.
Include ASCII and Croatian lower/upper case, composed/decomposed accents,
stacked marks, CJK/wide/ambiguous characters, Hangul, Arabic/Hebrew mixed text,
Indic/Thai shaping, supplementary scripts including U+12032, ligatures,
box/legacy-computing glyphs, bold/italic/decorations, variation selectors,
emoji modifiers/flags/ZWJ sequences and the upstream missing-glyph path.
Use upstream-supported results as the oracle, including limitations; do not
equate successful font cmap lookup with successful shaping or visible ink.

Run two font comparisons. A matched-font lane uses the same legally available
font bytes, face indices, fallback order and settings to isolate adapter defects.
An out-of-box lane compares coverage against the documented modern reference
environment and verifies VT7's distributable replacement coverage. Different
font outlines in that lane are recorded explicitly; missing supported text
cannot be hidden by choosing a weaker reference font.

Core/source/cell checks are exact. Glyph IDs are compared only for identical
font bytes and face instances; different fonts require visible/structural
comparisons. Declare raster/advance tolerances before accepting a fixture,
with observed reference bounds; do not invent thresholds after seeing a failure.
Test partial redraw against full redraw, neighbor damage, alternate screen,
scrollback, repeated resize/reflow, cache invalidation and font/settings changes.

Inject UTF-8 through the document boundary at every byte split, including the
four-byte U+12032 sequence, and verify malformed/EOF behavior separately. Run
real SSH from Command Prompt, Windows PowerShell 5.1 and exact PowerShell 7.2.24
where installed; retain LEOPARD's PS2 startup/live scope and qualify any newly
required PS2 interactive corpus explicitly. Isolate local-console byte losses
from renderer failures. A core-only pass cannot claim end-to-end parity for a
transport that loses required text.

Retain per-run package/commit hashes, upstream binary hashes, OS/build/DPI,
backend/driver, font file hashes and face/style/axis/feature choices, fixture
manifest, mapped faces/glyph evidence, core results, screenshots and verdicts.
Test LEOPARD, NESSY and TURTLE plus the declared hardware/WARP/DPI matrix.
Diagnostics use synthetic fixture text and must not capture credentials or
ordinary session contents. Record cache/font lifetime, startup/fallback cost
and memory budgets before final qualification; broad fallback must not introduce
unbounded scanning or allocations.

## Release policy and retained evidence

POL01-POL03 enhancements beyond measured upstream behavior remain optional.
POL04/POL05 capability gaps needed to match upstream are promoted to UT01 and
their implementing milestones. Their extra appearance/repertoire experiments
remain separate. The U+12032 finding is no longer merely a possible polish item.

Unresolved upstream-supported text behavior, required coverage, color/axis
capability or interaction differences block UT01 and the 1.0 parity claim.
An infeasible Windows 7 adaptation requires an explicit owner scope decision;
it cannot be silently described as supported, gracefully absent or deferred.
An inherited upstream limitation is documented and matched rather than claimed
as a VT7-specific failure. No scope waiver is granted by this plan.

Current evidence remains unchanged: SL01.1 and KH01.1-KH01.5 are accepted for
their bounded scopes; C3/REL01 and the larger SSH lifecycle gate remain open.
The documentation update does not change version 0.14.0, ABI 11, issued archives,
their manifests or dependency pins. The next text-parity action is UT01.1;
implementation and acceptance checkboxes remain unchecked.
