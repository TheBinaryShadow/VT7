# UTF-8, UTF-16, code pages and incremental decoding

Research date: 2026-09-11. Priority: P0. Encoding, grapheme segmentation and font rendering are separate problems.

## Define every text boundary

Recommended VT7 contracts:

| Boundary | Representation | Policy |
| --- | --- | --- |
| Win32 paths, process configuration, window text | UTF-16 through W APIs | Explicit lengths/ownership; no ANSI detour |
| Backend terminal stream | Explicit backend encoding, normally UTF-8 for the selected terminal protocol | Stateful decoder per session |
| TerminalCore input | UTF-16 text passed to Terminal::Write | Preserve parser state between writes |
| Keyboard/IME commit | UTF-16 -> selected backend encoding | Preserve supplementary characters and composition |
| Settings/log files | Explicit UTF-8 | Define BOM and invalid-data policy |
| Clipboard | CF_UNICODETEXT | Convert line endings at the clipboard boundary |
| Legacy child console | Child's input/output code pages and W/A API choice | Report separately from VT7's transport encoding |

The current viewport injects wide-string samples directly; its split-VT test does not establish decoding of split UTF-8 byte sequences. [1]

## Windows conversion APIs

MultiByteToWideChar supports CP_UTF8 on Windows 7. For UTF-8 its flags must be zero or MB_ERR_INVALID_CHARS. The strict flag fails invalid input; without it, Vista and later replace invalid sequences with U+FFFD. Explicit byte counts avoid accidental NUL termination semantics. Querying the required UTF-16 capacity is supported. [2]

WideCharToMultiByte converts UTF-16 to bytes. With CP_UTF8, use the permitted flags and NULL default-character parameters. WC_ERR_INVALID_CHARS is available from Vista and catches invalid surrogate input. Input sizes count UTF-16 units, while output sizes count bytes. [3]

**Important distinction:** these functions convert a supplied buffer; they do not retain a network stream's trailing partial character for the next call. The application must preserve that state.

**Recommended decoder behavior:**

1. Retain an incomplete valid UTF-8 prefix at the end of a read.
2. Combine it with the next read before conversion.
3. Treat malformed input according to an explicit replacement policy, with guaranteed forward progress.
4. Preserve ESC, BEL, CR, LF and other protocol controls for the parser; do not sanitize the terminal stream as a log.
5. On final EOF, resolve the trailing incomplete sequence once. Do not let it leak into a restarted session.
6. Keep decoder state and VT parser state separate. Both may be incomplete at the same boundary.

Do not guess a stream's code page from its contents or use CP_ACP as a fallback for a malformed UTF-8 sequence. A permissive decoder and an encoding detector solve different problems.

## Code pages are scoped

The console has distinct input and output code pages. SetConsoleOutputCP changes output translation, and its documented effect also depends on the console font type. It does not install font coverage or globally change Windows text encoding. [4][5]

Windows' ANSI API code page and the console OEM code page are not interchangeable. Microsoft recommends Unicode W APIs for avoiding that mismatch. Current general console guidance about CP65001 must not be read as a guarantee that every legacy Windows 7 application and every A/CRT input path behaves correctly. [6]

**Recommendation:** provide per-profile environment/startup configuration only after testing the shell. Never globally alter the system ANSI/OEM code-page registry to make VT7 work. A UTF-8 byte stream between the agent and host does not force the child to use UTF-8 internally.

## Failure cases that deserve exact byte tests

| Case | Example input | Required assertion |
| --- | --- | --- |
| Split two-byte scalar | C4 / 8D for U+010D | One č, independent of read split |
| Split three-byte scalar | E4 / B8 / AD | One U+4E2D |
| Split supplementary scalar | F0 / 9F / 98 / 80 | One U+1F600 represented as a UTF-16 pair |
| Combining sequence split | ASCII e then CC / 81 | Text survives; segmentation is tested separately |
| Malformed sequences | Lone continuation; overlong form; UTF-8-encoded surrogate; value above U+10FFFF | Defined replacement/progress behavior |
| Incomplete EOF | E2 82 then close | One documented finalization outcome; no hang |
| NUL/control bytes | Explicit-length buffers | No strlen truncation; parser policy applies |
| Adjacent protocol sequence | Split multibyte text followed by split ESC [ ... m | Same final core state for every split |
| Restart after malformed close | New session begins with ASCII | No retained decoder state |

Feed each corpus at every possible split and compare with one-shot decoding. Also compare one-byte reads with larger randomized chunks under a fixed seed.

**Open implementation question:** choose whether an existing inherited UTF helper or a new adapter owns streaming conversion. Audit its malformed-sequence policy before reuse. The proof's /utf-8 compiler switch controls source/execution encoding, not runtime pipe decoding. [7]

## Sources

- [1] [Core proof and tests](../../../src/vt7/VT7.Core/README.md), [sample injection](../../../src/vt7/VT7.Native/surface.cpp).
- [2] Microsoft, [MultiByteToWideChar](https://learn.microsoft.com/en-us/windows/win32/api/stringapiset/nf-stringapiset-multibytetowidechar).
- [3] Microsoft, [WideCharToMultiByte](https://learn.microsoft.com/en-us/windows/win32/api/stringapiset/nf-stringapiset-widechartomultibyte).
- [4] Microsoft, [Console Code Pages](https://learn.microsoft.com/en-us/windows/console/console-code-pages).
- [5] Microsoft, [SetConsoleOutputCP](https://learn.microsoft.com/en-us/windows/console/setconsoleoutputcp).
- [6] Microsoft, [Console Application Issues](https://learn.microsoft.com/en-us/windows/console/console-application-issues).
- [7] [Core compiler settings](../../../src/vt7/VT7.Core/Core.props) and [inherited Unicode helpers](../../../src/inc/til/unicode.h).
