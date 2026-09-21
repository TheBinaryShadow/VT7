using System;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace VT7.Host
{
    internal static class WinPtySessionChecks
    {
        internal static async Task Run(StringBuilder report)
        {
            var profile = TerminalProfile.CreateCommandPrompt().WithEnvironmentVariable("VT7_3B_UNICODE", "čćžšđ");
            Require(profile.Id == "command-prompt" && profile.Name == "Command Prompt",
                "The explicit Command Prompt profile identity changed.");
            Require(System.IO.Path.IsPathRooted(profile.Executable) && System.IO.File.Exists(profile.Executable),
                "The Command Prompt profile does not use an existing absolute executable.");
            Require(System.IO.Path.IsPathRooted(profile.WorkingDirectory) && System.IO.Directory.Exists(profile.WorkingDirectory),
                "The Command Prompt profile does not use an existing absolute working directory.");
            Require(profile.Arguments == "/d /q /k" && profile.CommandLine.StartsWith("\"" + profile.Executable + "\"", StringComparison.Ordinal),
                "The Command Prompt profile arguments or quoting changed.");
            Require(profile.Environment.Any(pair => pair.Key == "VT7_3B_UNICODE" && pair.Value == "čćžšđ"),
                "The explicit Unicode environment block lost its diagnostic value.");
            report.AppendLine("PASS: explicit Command Prompt profile pins executable, arguments, working directory, and a Unicode environment block.");

            var document = new TerminalDocument(loadDemonstration: false);
            var transport = new WinPtyTransport(profile);
            var session = new TerminalSession(document, transport);
            try
            {
                await session.StartAsync();
                Require(session.State == TerminalSessionState.RunningRoot && session.Outbound.Generation == 1,
                    "The WinPTY root did not enter generation 1.");
                await WaitFor(() => transport.Snapshot.OutputBytes > 0, "initial Command Prompt output");
                var before = transport.Snapshot;

                Require(session.Outbound.TryEnqueue(session.Outbound.Generation, SessionOutboundOperation.Resize(100, 30)) == SessionEnqueueResult.Accepted,
                    "The WinPTY resize was not admitted.");
                var commands = Encoding.UTF8.GetBytes("echo VT7_3B_READY_%VT7_3B_UNICODE%\r\nexit 37\r\n");
                Require(session.Outbound.TryEnqueue(session.Outbound.Generation,
                    SessionOutboundOperation.Input(SessionOutboundKind.InputBytes, commands)) == SessionEnqueueResult.Accepted,
                    "The Command Prompt input was not admitted.");

                var result = await WithTimeout(session.Completion, TimeSpan.FromSeconds(20), "Command Prompt natural exit");
                var snapshot = transport.Snapshot;
                var info = document.ReadInfo();
                Require(result.Kind == TerminalTransportResultKind.ReportedExit && result.ExitCode == 37,
                    $"Command Prompt exit differs: {result.Kind}, {result.ExitCode}.");
                Require(session.State == TerminalSessionState.Closed, "The session did not close after the WinPTY root exited.");
                Require(snapshot.ProcessId > 0 && snapshot.ResizeOperations == 1 && snapshot.Columns == 100 && snapshot.Rows == 30,
                    "WinPTY did not retain the child identity and authoritative 100x30 resize.");
                Require(snapshot.InputOperations == 1 && snapshot.InputBytes == commands.Length,
                    "WinPTY input operation or byte accounting differs.");
                Require(snapshot.OutputBytes > before.OutputBytes && snapshot.OutputBlocks > 0,
                    "WinPTY did not produce output after admitted input.");
                Require(info.Ended == 1 && info.PendingUtf8Bytes == 0 && info.ReceivedBytes == (ulong)snapshot.OutputBytes,
                    "TerminalDocument did not end after the exact final WinPTY output drain.");
                report.AppendLine($"PASS: WinPtyTransport launched cmd.exe PID {snapshot.ProcessId}, resized to 100x30, wrote {snapshot.InputBytes} input bytes, drained {snapshot.OutputBytes} output bytes in {snapshot.OutputBlocks} blocks, and preserved exit code 37.");
            }
            finally
            {
                if (session.State != TerminalSessionState.Closed && session.State != TerminalSessionState.Failed)
                    await session.CloseAsync(TerminalCloseReason.Cancelled);
                session.Dispose();
                document.Dispose();
            }

            var cancelDocument = new TerminalDocument(loadDemonstration: false);
            var cancelTransport = new WinPtyTransport(TerminalProfile.CreateCommandPrompt());
            var cancelSession = new TerminalSession(cancelDocument, cancelTransport);
            try
            {
                await cancelSession.StartAsync();
                await WaitFor(() => cancelTransport.Snapshot.OutputBytes > 0, "cancellation Command Prompt output");
                await WithTimeout(cancelSession.CloseAsync(TerminalCloseReason.Cancelled), TimeSpan.FromSeconds(10), "Command Prompt cancellation");
                var result = await cancelSession.Completion;
                var info = cancelDocument.ReadInfo();
                Require(result.Kind == TerminalTransportResultKind.Cancelled && info.Ended == 1,
                    "Cancellation did not close the child and document stream deterministically.");
                report.AppendLine("PASS: owner cancellation stopped WinPTY, joined its read path, and ended the document stream without a surviving session callback.");
            }
            finally
            {
                cancelSession.Dispose();
                cancelDocument.Dispose();
            }
        }

        private static async Task WaitFor(Func<bool> condition, string operation)
        {
            var deadline = DateTime.UtcNow.AddSeconds(10);
            while (DateTime.UtcNow < deadline)
            {
                if (condition()) return;
                await Task.Delay(20);
            }
            throw new TimeoutException("Timed out waiting for " + operation + ".");
        }

        private static async Task<T> WithTimeout<T>(Task<T> task, TimeSpan timeout, string operation)
        {
            if (await Task.WhenAny(task, Task.Delay(timeout)) != task)
                throw new TimeoutException("Timed out waiting for " + operation + ".");
            return await task;
        }

        private static async Task WithTimeout(Task task, TimeSpan timeout, string operation)
        {
            if (await Task.WhenAny(task, Task.Delay(timeout)) != task)
                throw new TimeoutException("Timed out waiting for " + operation + ".");
            await task;
        }

        private static void Require(bool condition, string message)
        {
            if (!condition) throw new InvalidOperationException(message);
        }
    }
}
