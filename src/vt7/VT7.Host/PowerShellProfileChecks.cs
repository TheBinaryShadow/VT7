using System;
using System.IO;
using System.Text;
using System.Threading.Tasks;

namespace VT7.Host
{
    internal static class PowerShellProfileChecks
    {
        private const string UnicodeSentinel = "čćžšđ";

        internal static async Task Run(StringBuilder report, bool allowMissingPowerShell7)
        {
            var windowsOrdinary = TerminalProfile.CreateWindowsPowerShell();
            var windowsClean = TerminalProfile.CreateWindowsPowerShell(cleanProfile: true)
                .WithEnvironmentVariable("VT7_3B2_UNICODE", UnicodeSentinel);
            CheckProfileContract(windowsOrdinary, windowsClean, "Windows PowerShell 5.1");
            report.AppendLine("PASS: Windows PowerShell 5.1 uses an explicit System32 executable, preserves ordinary user profiles, and reserves -NoProfile for controlled diagnostics.");
            var windowsResult = await RunProfile(windowsClean, new[] { 50, 51 }, BuildWindowsPowerShellScript(), "Windows PowerShell 5.1");
            report.AppendLine(windowsResult == 51
                ? "PASS: Windows PowerShell 5.1 reported runtime 5.1, loaded PSReadLine, exposed completion, ran a native child, resized, drained, and exited through WinPTY."
                : "PASS: Windows PowerShell 5.1 reported runtime 5.1, used its legacy ConsoleHost editor because PSReadLine was not auto-loaded, exposed completion, ran a native child, resized, drained, and exited through WinPTY.");

            TerminalProfile powerShell7Ordinary;
            TerminalProfile powerShell7Clean;
            try
            {
                powerShell7Ordinary = TerminalProfile.CreatePowerShell7();
                powerShell7Clean = TerminalProfile.CreatePowerShell7(cleanProfile: true)
                    .WithEnvironmentVariable("VT7_3B2_UNICODE", UnicodeSentinel);
            }
            catch (FileNotFoundException) when (allowMissingPowerShell7)
            {
                report.AppendLine("SKIP: PowerShell 7 is not installed on this build machine. The distributed Windows 7 runner requires exact version 7.2.24.");
                return;
            }

            CheckProfileContract(powerShell7Ordinary, powerShell7Clean, "PowerShell 7");
            if (!powerShell7Ordinary.IsWindows7Qualified)
            {
                if (allowMissingPowerShell7)
                {
                    report.AppendLine($"SKIP: discovered PowerShell {FormatVersion(powerShell7Ordinary.RuntimeVersion)} is outside the Windows 7 qualification target 7.2.24.");
                    return;
                }
                throw new InvalidOperationException($"PowerShell 7.2.24 is required; discovered {FormatVersion(powerShell7Ordinary.RuntimeVersion)} at {powerShell7Ordinary.Executable}.");
            }
            report.AppendLine("PASS: PowerShell 7.2.24 uses an explicit Program Files executable, preserves ordinary user profiles, and reserves -NoProfile for controlled diagnostics.");
            await RunProfile(powerShell7Clean, new[] { 72 }, BuildPowerShell7Script(), "PowerShell 7.2.24");
            report.AppendLine("PASS: PowerShell 7.2.24 reported its exact runtime, loaded PSReadLine with prediction capability, exposed completion, ran a native child, resized, drained, and exited through WinPTY.");
        }

        private static void CheckProfileContract(TerminalProfile ordinary, TerminalProfile clean, string label)
        {
            Require(Path.IsPathRooted(ordinary.Executable) && File.Exists(ordinary.Executable), label + " executable is not explicit and present.");
            Require(Path.IsPathRooted(ordinary.WorkingDirectory) && Directory.Exists(ordinary.WorkingDirectory), label + " working directory is invalid.");
            Require(ordinary.Environment.Count > 0, label + " environment block is empty.");
            Require(!ordinary.IsCleanProfile && ordinary.Arguments.IndexOf("-NoProfile", StringComparison.OrdinalIgnoreCase) < 0,
                label + " ordinary profile suppresses the user's profile scripts.");
            Require(clean.IsCleanProfile && clean.Arguments.IndexOf("-NoProfile", StringComparison.OrdinalIgnoreCase) >= 0,
                label + " diagnostic profile is not isolated from user profile scripts.");
            Require(string.Equals(ordinary.Executable, clean.Executable, StringComparison.OrdinalIgnoreCase),
                label + " ordinary and diagnostic profiles resolved different executables.");
        }

        private static async Task<int> RunProfile(TerminalProfile profile, int[] expectedExitCodes, string[] scriptLines, string label)
        {
            var document = new TerminalDocument(loadDemonstration: false);
            var transport = new WinPtyTransport(profile);
            var session = new TerminalSession(document, transport);
            try
            {
                await session.StartAsync();
                Require(session.State == TerminalSessionState.RunningRoot && session.Outbound.Generation == 1,
                    label + " did not enter root generation 1.");
                await WaitFor(() => transport.Snapshot.OutputBytes > 0, label + " initial prompt");
                var before = transport.Snapshot;
                Require(session.Outbound.TryEnqueue(session.Outbound.Generation, SessionOutboundOperation.Resize(108, 32)) == SessionEnqueueResult.Accepted,
                    label + " resize was not admitted.");
                var inputBytes = 0;
                var progress = new StringBuilder($"initial-output={before.OutputBytes}");
                for (var index = 0; index < scriptLines.Length; ++index)
                {
                    var beforeLine = transport.Snapshot.OutputBytes;
                    // A terminal Enter key emits CR. LF is separate Ctrl+J-style
                    // input in PowerShell's console editors and can leave the older
                    // Windows 7 editor in a continued line instead of submitting it.
                    var bytes = Encoding.UTF8.GetBytes(scriptLines[index] + "\r");
                    inputBytes += bytes.Length;
                    Require(session.Outbound.TryEnqueue(session.Outbound.Generation,
                        SessionOutboundOperation.Input(SessionOutboundKind.InputBytes, bytes)) == SessionEnqueueResult.Accepted,
                        $"{label} input line {index + 1} was not admitted.");
                    if (index + 1 < scriptLines.Length)
                    {
                        await WaitFor(() => transport.Snapshot.OutputBytes > beforeLine, $"{label} response to input line {index + 1}");
                        progress.Append($"; line-{index + 1}-output={transport.Snapshot.OutputBytes}");
                    }
                }
                await WaitFor(() => transport.Snapshot.InputOperations == scriptLines.Length, label + " final input write");
                TerminalTransportResult result;
                try
                {
                    result = await WithTimeout(session.Completion, TimeSpan.FromSeconds(30), label + " natural exit");
                }
                catch (TimeoutException ex)
                {
                    var stalled = transport.Snapshot;
                    throw new TimeoutException(
                        $"{label} did not exit after {scriptLines.Length} terminal-Enter submissions. " +
                        $"WinPTY recorded {stalled.InputOperations} input writes/{stalled.InputBytes} bytes and " +
                        $"{stalled.OutputBlocks} output blocks/{stalled.OutputBytes} bytes; {progress}.", ex);
                }
                var snapshot = transport.Snapshot;
                var info = document.ReadInfo();
                if (result.Kind != TerminalTransportResultKind.ReportedExit || !result.ExitCode.HasValue)
                    throw new InvalidOperationException($"{label} did not report an exit code: {result.Kind}, {result.ExitCode}.");
                var exitCode = result.ExitCode.Value;
                Require(Array.IndexOf(expectedExitCodes, exitCode) >= 0,
                    $"{label} contract failed or exited unexpectedly: {result.Kind}, {exitCode} " +
                    $"(expected {string.Join(" or ", expectedExitCodes)}).");
                Require(session.State == TerminalSessionState.Closed, label + " session did not close after exit.");
                Require(snapshot.ProcessId > 0 && snapshot.ResizeOperations == 1 && snapshot.Columns == 108 && snapshot.Rows == 32,
                    label + " did not retain its process identity and 108x32 resize.");
                Require(snapshot.InputOperations == scriptLines.Length && snapshot.InputBytes == inputBytes,
                    label + " input operation or byte accounting differs.");
                Require(snapshot.OutputBytes > before.OutputBytes && snapshot.OutputBlocks > 0,
                    label + " did not produce output after input.");
                Require(info.Ended == 1 && info.PendingUtf8Bytes == 0 && info.ReceivedBytes == (ulong)snapshot.OutputBytes,
                    label + " document did not end after the final output drain.");
                return exitCode;
            }
            finally
            {
                if (session.State != TerminalSessionState.Closed && session.State != TerminalSessionState.Failed)
                    await session.CloseAsync(TerminalCloseReason.Cancelled);
                session.Dispose();
                document.Dispose();
            }
        }

        private static string[] BuildWindowsPowerShellScript() => BuildScript(
            "$v.Major -ne 5 -or $v.Minor -ne 1", requirePsReadLine: false, requirePrediction: false, successCode: 51);

        private static string[] BuildPowerShell7Script() => BuildScript(
            "$v.Major -ne 7 -or $v.Minor -ne 2 -or $v.Patch -ne 24", requirePsReadLine: true, requirePrediction: true, successCode: 72);

        private static string[] BuildScript(string wrongVersionExpression, bool requirePsReadLine, bool requirePrediction, int successCode)
        {
            var predictionCheck = requirePrediction
                ? " if ($null -eq $option.PSObject.Properties['PredictionSource']) { exit 87 };"
                : string.Empty;
            var lineEditorCheck = requirePsReadLine
                ? "$module = Get-Module PSReadLine; if ($null -eq $module) { exit 84 }; " +
                  "$option = Get-PSReadLineOption; if ($null -eq $option) { exit 86 };"
                : "$module = Get-Module PSReadLine; if ($null -ne $module) { " +
                  "$option = Get-PSReadLineOption; if ($null -eq $option) { exit 86 } };";
            var successExit = requirePsReadLine
                ? $"exit {successCode}"
                : $"if ($null -eq $module) {{ exit 50 }}; exit {successCode}";
            var body = "$ErrorActionPreference = 'Stop'; try { $v = $PSVersionTable.PSVersion; " +
                $"if ({wrongVersionExpression}) {{ exit 81 }}; " +
                "if ($Host.Name -ne 'ConsoleHost') { exit 82 }; " +
                "if ($env:VT7_3B2_UNICODE -cne 'čćžšđ') { exit 83 }; " +
                "if ($null -eq (Get-Command TabExpansion2 -ErrorAction SilentlyContinue)) { exit 85 }; " +
                lineEditorCheck +
                predictionCheck + " & $env:ComSpec /d /q /c 'exit 0'; " +
                "if ($LASTEXITCODE -ne 0) { exit 88 }; " + successExit + " } catch { exit 89 }";
            return new[] { body };
        }

        private static string FormatVersion(Version? version) => version == null
            ? "unknown" : $"{version.Major}.{version.Minor}.{version.Build}";

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

        private static void Require(bool condition, string message)
        {
            if (!condition) throw new InvalidOperationException(message);
        }
    }
}
