# Process creation, console ownership, jobs and asynchronous pipes

Status note, 2026-09-13: this file preserves dated research and proposals,
not current implementation or acceptance claims. Source references and words
such as "current", "next" and "latest" below retain their research-date scope.
Use the [research status](README.md#planning-adoption), [current handoff](../HANDOFF.md)
and [roadmap](../../../ROADMAP.md) for port-first priorities and present evidence.

Research date: 2026-09-11. Priority: P0 for sessions. All lifecycle sequences below are proposed VT7 designs, not existing session code.

## Process creation contract

CreateProcessW may modify its command-line buffer. Passing an explicit executable path avoids ambiguity in the first command-line token. Windows 7 also has a documented exception in which standard handles are inherited even when bInheritHandles is FALSE. This needs an explicit test in the host/agent launch path. [1]

For a direct launcher, STARTUPINFOEX and PROC_THREAD_ATTRIBUTE_HANDLE_LIST can restrict inheritance to an explicit set; listed handles must be inheritable and bInheritHandles must be TRUE. EXTENDED_STARTUPINFO_PRESENT identifies the extended startup structure. [2]

**Recommendation:** centralize launching, quoting, environment construction, and inheritance. Use CreateProcessW and an explicit application path; never make an arbitrary profile string a shell command unless shell interpretation is the chosen profile behavior. Keep UTF-16 environment entries and CREATE_UNICODE_ENVIRONMENT consistent. Preserve the original failure code before cleanup calls.

WinPTY owns part of this launch sequence. VT7 must use the selected library's supported spawn arguments, not assume it can directly attach arbitrary STARTUPINFOEX options through that API. Keep returned child handles distinct from borrowed agent handles and pipe handles. [3]

## Windows 7 job-object limitation

On Windows 7 a process can belong to only one job; nested jobs arrive in Windows 8. Child processes normally inherit job membership, subject to breakaway flags. IsProcessInJob can detect membership, while TerminateJobObject and kill-on-job-close are available mechanisms for group termination. [4]

**Design implication:** a tab-per-job scheme can conflict with an existing launcher job or a child's own job use. Do not apply a Windows 8 nested-job design unchanged. Test VT7 launched by an IDE, automation runner, and job-restricted parent. Report inability to establish containment instead of claiming all descendants are guaranteed to die.

Where the selected backend permits it, a suspended-start -> job assignment -> resume sequence can close a child-escape race. That is an implementation option, not a property automatically supplied by WinPTY. Determine whether the backend exposes sufficient control before relying on it.

## Ctrl+C, process groups and console attachment

GenerateConsoleCtrlEvent targets processes sharing the caller's console. CTRL_C_EVENT cannot be restricted to a nonzero process group in the same way as CTRL_BREAK_EVENT; a successful call can therefore be misleading. A child that creates a different console is outside that delivery set. [5]

**Recommendation:** distinguish:

- A Ctrl+C key interpreted by an application in raw input mode.
- A processed Ctrl+C interrupt delivered through the console/agent.
- Ctrl+Break.
- Closing a tab.
- Forced process-tree termination.

Do not attach/detach the WPF UI process repeatedly to different consoles to synthesize per-tab interrupts. Route console-specific actions through the backend owner and test that one tab's interrupt cannot affect another. A graceful interrupt must not be implemented as unconditional process termination.

## Pipe I/O and cancellation

WinPTY provides separate named pipes for the input and output directions. [3] Pipes are transport queues, so a reader must keep draining while the child is alive and while final buffered output remains.

CancelIoEx requests cancellation of outstanding I/O issued by any thread in the process for the handle. It does not wait for completion. An operation can still complete successfully; ERROR_NOT_FOUND may mean there was no outstanding request. OVERLAPPED structures and buffers must remain valid until completion has been collected. [6]

**Proposed ownership rules:**

These are session/IPC proposals. They are not the renderer's current teardown
recipe: the later [0.3.5 ordering clarification](09-threading-and-renderer-lifecycle.md#teardown-protocol)
keeps the paused presentation worker alive through native-window destruction.

1. One session owner controls launch, resize, close and error transitions.
2. Every pending read/write owns its buffer, OVERLAPPED, and completion bookkeeping.
3. Stop accepting new input before cancellation; wake all workers.
4. Collect completion of all outstanding operations before releasing their storage.
5. Drain bounded final output when possible; record whether truncation was necessary.
6. Join workers before releasing the backend, native callbacks, core, or HWND.
7. Make close idempotent: two close requests share one completion.

Do not block the WPF dispatcher on pipe writes, agent RPC, or a worker that synchronously calls back to the dispatcher. Use bounded queues and an explicit overflow policy. High-rate output must not allocate an unbounded series of UI work items.

## IPC access control

The documented default named-pipe descriptor grants broad read access, including Everyone and anonymous accounts. Microsoft recommends a logon SID to constrain access across remote users or terminal-services sessions. [7]

**Recommendation:** review the selected agent's actual pipe ACL and peer verification. Names containing random values are not authorization. For new VT7 IPC, request only necessary rights, use private per-session names, reject unexpected peers, and keep standard-user/elevated boundaries explicit.

## Experiments

Run child/agent crash, close during startup, full output pipe, partial paste write, cancellation racing success, child spawning grandchildren, child opening another console, close while minimized, and parallel tab shutdown. Capture final output, all exit codes, surviving descendants, pending-I/O counts, worker completion time, and handle growth.

Success requires a responsive UI and an explicit final state, not merely disappearance of the tab.

## Sources

- [1] Microsoft, [CreateProcessW](https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-createprocessw).
- [2] Microsoft, [UpdateProcThreadAttribute](https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-updateprocthreadattribute).
- [3] WinPTY, [public API and ownership comments](https://raw.githubusercontent.com/rprichard/winpty/master/src/include/winpty.h).
- [4] Microsoft, [Job Objects](https://learn.microsoft.com/en-us/windows/win32/procthread/job-objects).
- [5] Microsoft, [GenerateConsoleCtrlEvent](https://learn.microsoft.com/en-us/windows/console/generateconsolectrlevent).
- [6] Microsoft, [CancelIoEx](https://learn.microsoft.com/en-us/windows/win32/api/ioapiset/nf-ioapiset-cancelioex).
- [7] Microsoft, [Named Pipe Security and Access Rights](https://learn.microsoft.com/en-us/windows/win32/ipc/named-pipe-security-and-access-rights).
