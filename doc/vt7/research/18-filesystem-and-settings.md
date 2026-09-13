# Files, Unicode paths, settings persistence and change notification

Status note, 2026-09-13: this file preserves dated research and proposals,
not current implementation or acceptance claims. Source references and words
such as "current", "next" and "latest" below retain their research-date scope.
Use the [research status](README.md#planning-adoption), [current handoff](../HANDOFF.md)
and [roadmap](../../../ROADMAP.md) for port-first priorities and present evidence.

Research date: 2026-09-11. Priority: P1 for profiles/settings and portable deployment.

## Paths and portable behavior

Many Win32 paths have a MAX_PATH limit of 260 characters. Some W APIs support extended-length paths using the extended prefix; broad long-path opt-in behavior is a Windows 10-era addition and is not a Windows 7 baseline. Extended paths also have different parsing rules. [1]

**Recommendation:** use UTF-16 paths end to end, but do not confuse Unicode support with universal long-path support. Test the complete path through file dialogs, managed I/O, native helpers, process creation and the child application.

SHGetKnownFolderPath returns a Unicode path and requires the caller to free its returned storage with CoTaskMemFree. It is available from Vista. [2]

Proposed directory policy:

- Locate application resources relative to the executable, not the current directory.
- Put ordinary per-user settings under a known user-data location.
- Make write-next-to-executable portable mode explicit.
- If the portable directory is read-only, produce a clear choice/error instead of silently losing settings.
- Keep runtime binaries and user-writable settings distinct for loader security.

No new storage location is selected by this research.

## Configuration format

Recommended UTF-8 JSON rules:

- Define BOM acceptance and always write one documented encoding.
- Validate schema/types/ranges before applying.
- Keep the last known-good in-memory configuration when parsing fails.
- Report file, line/column and a useful error without dumping secrets.
- Preserve unknown fields where practical so older versions do not destroy newer settings.
- Use a settings version and explicit migration/backup behavior.
- Separate profile commands from shell interpretation.

Do not normalize Unicode file names, private-key paths or command strings as a side effect of parsing. Search equivalence and filesystem identity are different policies.

## Replacement and durability

ReplaceFileW can replace an existing file while optionally retaining a backup and preserving/merging selected metadata. REPLACEFILE_WRITE_THROUGH is documented as unsupported; error cases can leave different combinations of old, replacement and backup names. [3]

**Recommended save transaction:**

1. Serialize a complete validated document.
2. Create a uniquely named temporary file in the destination directory.
3. Write all bytes and handle short/error results.
4. Flush according to the intended durability requirement.
5. Close/reopen or validate as needed.
6. Replace the destination with a backup, using a separate first-create path when absent.
7. Inspect errors and retain recoverable files.

This is a recovery-oriented design, not a claim that ReplaceFile guarantees survival of every power loss. Test crash points and real filesystems before making durability promises.

For two running instances, use a generation/hash or other concurrency check. Do not overwrite a file another instance changed after the current instance loaded it.

## File watching is advisory

ReadDirectoryChangesW supports asynchronous notification. Its buffer can overflow, and a zero-byte result can require re-enumeration rather than meaning that nothing changed. [4]

**Recommendation:** watch the directory, debounce events, then reopen and validate the current settings file. Editors commonly save by replacement, so a file-only identity assumption can miss updates. Treat events as a reason to reread state, not a complete transaction log.

Watch cancellation must retain outstanding OVERLAPPED/buffer storage until completion. That lifetime follows the [IPC cancellation analysis](03-process-lifecycle-and-ipc.md).

## Shell integration and path safety

User-selected URLs/files should enter a typed action path. Terminal-emitted strings are not automatically shell commands. For hyperlinks, allow only intended URI schemes and invoke the appropriate shell operation after a user action; do not concatenate text into cmd /c.

Named-pipe single-instance IPC, if added, needs user/session access control and input limits. Do not assume that sharing a settings directory authenticates the sender.

These are implementation recommendations, not newly added interface behavior.

## Acceptance

Unicode names including č/ć/ž/š/đ and CJK; spaces; root/read-only directories; long paths at each boundary; UNC paths where intended; removable storage; full disk; sharing violation; concurrent saves; external editor replacement; malformed/truncated JSON; watcher overflow; and startup with a corrupt file plus valid backup.

Verify that no failure writes partial configuration over the only good copy and that diagnostics show the actual selected settings path.

## Sources

- [1] Microsoft, [Maximum Path Length Limitation](https://learn.microsoft.com/en-us/windows/win32/fileio/maximum-file-path-limitation).
- [2] Microsoft, [SHGetKnownFolderPath](https://learn.microsoft.com/en-us/windows/win32/api/shlobj_core/nf-shlobj_core-shgetknownfolderpath).
- [3] Microsoft, [ReplaceFileW](https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-replacefilew).
- [4] Microsoft, [ReadDirectoryChangesW](https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-readdirectorychangesw).
