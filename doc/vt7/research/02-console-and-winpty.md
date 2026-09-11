# Windows 7 console, PTY choices and WinPTY fidelity

Research date: 2026-09-11. Priority: P0 before local-session feature commitments.

## Architectural boundary

CreatePseudoConsole requires Windows 10 version 1809 or later. Windows 7 does not acquire that service merely by compiling the inherited winconpty sources or redistributing a similarly named DLL. [1]

WinPTY's documented design starts an agent with a hidden console, polls its screen buffer, and generates terminal output representing changes. The library supports Windows XP through Windows 10 and both 32- and 64-bit builds. Its native library/agent are distinct from its Cygwin/MSYS command-line adapter. [2]

**Inference:** VT7 should integrate the native library/agent boundary, not require a Cygwin terminal wrapper. Pin and build the selected source revision, then test the exact artifacts on Windows 7. The consulted master-branch API sources are research references, not a dependency selection.

The two principal output paths are:

    Local application -> Windows 7 console state -> WinPTY reconstruction -> VT7
    Remote application -> remote PTY -> SSH channel bytes -> VT7

These paths have different information loss. The terminal renderer and parser may support more than the local console backend can convey.

## Legacy console behavior that affects the product

ReadConsoleOutput transfers rectangular arrays of CHAR_INFO cells containing character and attribute information. It does not consume a byte stream or move the console cursor. [3] Traditional console text attributes expose a small indexed foreground/background color model and separate cell flags; this is not a storage format for arbitrary original VT sequences. [4]

**Inference:** screen polling cannot generally reconstruct application intent that was never represented in the buffer: the original escape sequences, precise ordering of overwritten intermediate states, or arbitrary richer colors. A final identical screen does not prove identical terminal semantics.

Modern SetConsoleMode documentation describes ENABLE_VIRTUAL_TERMINAL_PROCESSING and ENABLE_VIRTUAL_TERMINAL_INPUT alongside much older mode bits. Their presence on that page is not proof of Windows 7 support. The Windows console team's history places modern VT processing work in the Windows 10 era. [5][6]

Consequently, do not promise that stock WinPTY on Windows 7 transports arbitrary 256-color/true-color application output, OSC hyperlinks, or every terminal mode. Direct SSH can deliver sequences to VT7 without passing through Windows 7 console state. A different local path or explicit adaptation would need its own design and evidence.

Console input has line, echo, processed-input, mouse, window-input and Quick Edit modes. Their interaction belongs to the child console/agent as well as to VT7. For example, toggling a terminal UI option is not equivalent to changing the child application's console mode. [5]

## Relevant WinPTY API and options

The public API provides configuration, agent startup, named I/O pipe names, process spawn, resize, and cleanup. Configuration objects are not thread-safe; the session object is documented as thread-safe. API text parameters are wide strings, and allocated errors need winpty_error_free. The agent process handle returned by winpty_agent_process is borrowed. [7]

| API group | VT7 use |
| --- | --- |
| winpty_config_new / set_initial_size / set_agent_timeout | Set initial cells and finite startup/RPC deadlines |
| winpty_open / conin_name / conout_name | Start agent and connect the data channels |
| winpty_spawn_config_new / winpty_spawn | Launch the configured executable |
| winpty_set_size | Propagate cell dimensions |
| winpty_free and the matching config/error frees | Deterministic ownership |

WINPTY_FLAG_PLAIN_OUTPUT suppresses escape sequences; WINPTY_FLAG_COLOR_ESCAPES can restore color escapes in that mode. WINPTY_FLAG_CONERR creates a separate screen buffer for stderr and changes active-buffer polling behavior. Mouse-mode constants govern agent reporting/Quick Edit interaction; NONE still permits received mouse input to become console mouse records. [8]

**Recommendation:** keep the terminal-mode output path and avoid separate CONERR by default for an interactive terminal. Splitting stderr is a semantic change, not a free logging feature. Validate full-screen applications that activate another screen buffer before selecting flags.

## Proposed integration contract

The following is a design proposal:

1. Create a session object with its own worker, error state, size generation and cancellation signal.
2. Configure a positive grid size, explicit mouse policy, and bounded startup deadline.
3. Start the agent, connect its pipe names, and prepare both directions of I/O before allowing substantial child output.
4. Spawn using an explicit executable, Unicode command line, environment and working directory.
5. Decode the backend's terminal stream incrementally; keep parser state across read boundaries.
6. Serialize writes from keyboard, paste, mouse, and terminal replies. Preserve byte order.
7. Coalesce resize requests, but acknowledge the latest accepted dimensions and report failure.
8. Distinguish child exit, agent exit, pipe EOF, cancellation and final drain. Release the session only after workers have stopped.

The [process/IPC analysis](03-process-lifecycle-and-ipc.md) expands ownership and termination details. This order must be checked against the pinned implementation's spawn and pipe contracts; it is not tested adapter code.

## Fidelity matrix to measure on Windows 7

| Producer/operation | What to capture | Why it matters |
| --- | --- | --- |
| WriteConsoleW, WriteConsoleOutputW | Exact UTF-16 input, console cells and emitted bytes | Separates transport loss from glyph appearance |
| WriteConsoleA/WriteFile under CP437, CP850, CP852, CP932, CP65001 | Return counts, errors, characters and EOF behavior | Code page and API path are independent variables |
| Raw SGR 16/256/24-bit output | Whether escapes display literally, are interpreted, approximated, or lost | Core rendering success does not settle local color fidelity |
| Fast rewrite of one cell/progress bar | Final state, observed transitions and CPU | Polling observes snapshots, not necessarily every write |
| Alternate screen-buffer activation | Entry, content, cursor and restored main screen | Active buffer handling and CONERR effects |
| CJK, combining marks, supplementary characters | Before/after cells and selected glyphs | A UTF-8 pipe cannot reverse legacy-console information loss |
| Mouse and PSReadLine | Button/modifier records and editing behavior | Host input mode must match child expectations |
| Width shrink/grow during output | Console window/buffer dimensions and VT7 cursor | Console resize and core reflow can interact |
| Child exits while output is pending | Last output and exit status | Prevents truncation at process-signal time |

Keep claims narrow until these captures exist. A successful prompt launch closes only startup, not interactive compatibility.

## Sources

- [1] Microsoft, [CreatePseudoConsole requirements](https://learn.microsoft.com/en-us/windows/console/createpseudoconsole).
- [2] WinPTY, [README and architecture](https://github.com/rprichard/winpty).
- [3] Microsoft, [ReadConsoleOutput](https://learn.microsoft.com/en-us/windows/console/readconsoleoutput).
- [4] Microsoft, [CHAR_INFO](https://learn.microsoft.com/en-us/windows/console/char-info-str).
- [5] Microsoft, [SetConsoleMode](https://learn.microsoft.com/en-us/windows/console/setconsolemode); modern and historical behavior must be distinguished.
- [6] Microsoft Windows Command Line team, [Windows Console and Terminal ecosystem roadmap](https://learn.microsoft.com/en-us/windows/console/ecosystem-roadmap).
- [7] WinPTY, [public API source](https://raw.githubusercontent.com/rprichard/winpty/master/src/include/winpty.h), master as consulted 2026-09-11.
- [8] WinPTY, [option constants and comments](https://raw.githubusercontent.com/rprichard/winpty/master/src/include/winpty_constants.h), master as consulted 2026-09-11.
