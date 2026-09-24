using System;
using System.Collections;
using System.Collections.Generic;
using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.Text.RegularExpressions;

namespace VT7.Host
{
    internal enum TerminalProfileKind
    {
        CommandPrompt,
        WindowsPowerShell,
        PowerShell7,
    }

    internal sealed class TerminalProfile
    {
        private TerminalProfile(TerminalProfileKind kind, string id, string name, string executable,
            string arguments, string workingDirectory, IReadOnlyList<KeyValuePair<string, string>> environment,
            Version? runtimeVersion, bool cleanProfile)
        {
            Kind = kind;
            Id = id;
            Name = name;
            Executable = executable;
            Arguments = arguments;
            WorkingDirectory = workingDirectory;
            Environment = environment;
            RuntimeVersion = runtimeVersion;
            IsCleanProfile = cleanProfile;
        }

        internal TerminalProfileKind Kind { get; }
        internal string Id { get; }
        internal string Name { get; }
        internal string Executable { get; }
        internal string Arguments { get; }
        internal string WorkingDirectory { get; }
        internal IReadOnlyList<KeyValuePair<string, string>> Environment { get; }
        internal Version? RuntimeVersion { get; }
        internal bool IsCleanProfile { get; }
        internal bool IsWindows7Qualified => Kind == TerminalProfileKind.CommandPrompt ||
            (Kind == TerminalProfileKind.WindowsPowerShell && RuntimeVersion != null &&
             RuntimeVersion.Major == 5 && RuntimeVersion.Minor == 1) ||
            (Kind == TerminalProfileKind.PowerShell7 && RuntimeVersion != null &&
             RuntimeVersion.Major == 7 && RuntimeVersion.Minor == 2 && RuntimeVersion.Build == 24);
        internal string CommandLine => Quote(Executable) + (string.IsNullOrWhiteSpace(Arguments) ? string.Empty : " " + Arguments);
        internal string DisplayName => Kind == TerminalProfileKind.CommandPrompt || IsWindows7Qualified
            ? Name : Name + " (unqualified on Windows 7)";

        public override string ToString() => DisplayName;

        internal static TerminalProfile CreateCommandPrompt(string arguments = "/d /q /k") =>
            Create(TerminalProfileKind.CommandPrompt, "command-prompt", "Command Prompt", GetWindowsExecutable("cmd.exe"),
                arguments, null, false);

        internal static TerminalProfile CreateWindowsPowerShell(bool cleanProfile = false)
        {
            var executable = GetWindowsExecutable(Path.Combine("WindowsPowerShell", "v1.0", "powershell.exe"));
            if (!File.Exists(executable)) throw new FileNotFoundException("Windows PowerShell was not found.", executable);
            var version = ReadWindowsPowerShellVersion(executable);
            return Create(TerminalProfileKind.WindowsPowerShell, "windows-powershell",
                $"Windows PowerShell {version.Major}.{version.Minor}", executable,
                cleanProfile ? "-NoLogo -NoProfile" : "-NoLogo", version, cleanProfile);
        }

        internal static TerminalProfile CreatePowerShell7(bool cleanProfile = false)
        {
            var candidates = new List<string>();
            AddPowerShell7Candidates(candidates, System.Environment.GetEnvironmentVariable("ProgramW6432"));
            AddPowerShell7Candidates(candidates, System.Environment.GetFolderPath(System.Environment.SpecialFolder.ProgramFiles));
            string? executable = null;
            foreach (var candidate in candidates)
            {
                if (File.Exists(candidate)) { executable = candidate; break; }
            }
            if (executable == null)
                throw new FileNotFoundException("PowerShell 7 was not found in the standard 64-bit installation directory.",
                    candidates.Count > 0 ? candidates[0] : "pwsh.exe");
            var version = ReadPowerShellVersion(executable);
            if (version.Major != 7) throw new InvalidOperationException($"The discovered pwsh.exe reports version {version}, not PowerShell 7.");
            return Create(TerminalProfileKind.PowerShell7, "powershell-7",
                $"PowerShell {version.Major}.{version.Minor}.{version.Build}", executable,
                cleanProfile ? "-NoLogo -NoProfile" : "-NoLogo", version, cleanProfile);
        }

        internal TerminalProfile WithEnvironmentVariable(string name, string value)
        {
            if (string.IsNullOrWhiteSpace(name) || name.IndexOf('=') >= 0 || name.IndexOf('\0') >= 0)
                throw new ArgumentException("Environment variable name is invalid.", nameof(name));
            if (value == null || value.IndexOf('\0') >= 0) throw new ArgumentException("Environment variable value is invalid.", nameof(value));
            var values = new List<KeyValuePair<string, string>>(Environment.Count + 1);
            var replaced = false;
            foreach (var pair in Environment)
            {
                if (string.Equals(pair.Key, name, StringComparison.OrdinalIgnoreCase))
                {
                    values.Add(new KeyValuePair<string, string>(name, value));
                    replaced = true;
                }
                else values.Add(pair);
            }
            if (!replaced) values.Add(new KeyValuePair<string, string>(name, value));
            values.Sort((left, right) => StringComparer.OrdinalIgnoreCase.Compare(left.Key, right.Key));
            return new TerminalProfile(Kind, Id, Name, Executable, Arguments, WorkingDirectory,
                values.AsReadOnly(), RuntimeVersion, IsCleanProfile);
        }

        private static TerminalProfile Create(TerminalProfileKind kind, string id, string name, string executable,
            string arguments, Version? runtimeVersion, bool cleanProfile)
        {
            executable = Path.GetFullPath(executable);
            if (!File.Exists(executable)) throw new FileNotFoundException(name + " was not found.", executable);
            var workingDirectory = System.Environment.GetFolderPath(System.Environment.SpecialFolder.UserProfile);
            if (string.IsNullOrWhiteSpace(workingDirectory) || !Directory.Exists(workingDirectory))
                workingDirectory = System.Environment.CurrentDirectory;
            return new TerminalProfile(kind, id, name, executable, arguments, Path.GetFullPath(workingDirectory),
                CaptureEnvironment(), runtimeVersion, cleanProfile);
        }

        private static string GetWindowsExecutable(string relativePath)
        {
            var windows = System.Environment.GetEnvironmentVariable("SystemRoot");
            if (string.IsNullOrWhiteSpace(windows)) windows = System.Environment.GetFolderPath(System.Environment.SpecialFolder.Windows);
            if (string.IsNullOrWhiteSpace(windows)) throw new InvalidOperationException("The Windows directory is unavailable.");
            return Path.Combine(windows, "System32", relativePath);
        }

        private static void AddPowerShell7Candidates(List<string> candidates, string? programFiles)
        {
            if (string.IsNullOrWhiteSpace(programFiles)) return;
            foreach (var channel in new[] { "7", "7-preview" })
            {
                var candidate = Path.GetFullPath(Path.Combine(programFiles, "PowerShell", channel, "pwsh.exe"));
                if (!candidates.Exists(path => string.Equals(path, candidate, StringComparison.OrdinalIgnoreCase)))
                    candidates.Add(candidate);
            }
        }

        private static Version ReadPowerShellVersion(string executable)
        {
            var info = FileVersionInfo.GetVersionInfo(executable);
            foreach (var text in new[] { info.ProductVersion, info.FileVersion })
            {
                if (string.IsNullOrWhiteSpace(text)) continue;
                var match = Regex.Match(text, @"\d+\.\d+\.\d+");
                if (match.Success && Version.TryParse(match.Value, out var version)) return version;
            }
            throw new InvalidOperationException("The PowerShell 7 executable has no parseable product version: " + executable);
        }

        private static Version ReadWindowsPowerShellVersion(string executable)
        {
            // The executable's file version is a Windows build number, not the
            // engine version. Query the engine itself without loading user profiles.
            var start = new ProcessStartInfo(executable,
                "-NoLogo -NoProfile -NonInteractive -Command \"$PSVersionTable.PSVersion.ToString()\"")
            {
                UseShellExecute = false,
                CreateNoWindow = true,
                RedirectStandardOutput = true,
            };
            Process process;
            try { process = Process.Start(start) ?? throw new InvalidOperationException("Windows PowerShell could not start."); }
            catch (Win32Exception ex) { throw new InvalidOperationException("Windows PowerShell version detection could not start.", ex); }
            using (process)
            {
                if (!process.WaitForExit(5000))
                {
                    try { process.Kill(); }
                    catch (InvalidOperationException) { }
                    throw new InvalidOperationException("Windows PowerShell version detection timed out.");
                }
                var output = process.StandardOutput.ReadToEnd().Trim();
                if (process.ExitCode != 0 || !Version.TryParse(output, out var version) || version.Major < 2)
                    throw new InvalidOperationException("Windows PowerShell did not report a usable engine version.");
                return version;
            }
        }

        private static IReadOnlyList<KeyValuePair<string, string>> CaptureEnvironment()
        {
            var values = new List<KeyValuePair<string, string>>();
            foreach (DictionaryEntry entry in System.Environment.GetEnvironmentVariables())
            {
                var name = entry.Key as string;
                var value = entry.Value as string;
                if (name == null || name.Length == 0 || name.IndexOf('\0') >= 0 || name.IndexOf('=') >= 0 ||
                    value == null || value.IndexOf('\0') >= 0) continue;
                values.Add(new KeyValuePair<string, string>(name, value));
            }
            values.Sort((left, right) => StringComparer.OrdinalIgnoreCase.Compare(left.Key, right.Key));
            return values.AsReadOnly();
        }

        private static string Quote(string value) => "\"" + value.Replace("\"", "\\\"") + "\"";
    }

    internal static class TerminalProfileCatalog
    {
        internal static IReadOnlyList<TerminalProfile> Discover()
        {
            var profiles = new List<TerminalProfile> { TerminalProfile.CreateCommandPrompt() };
            TryAdd(profiles, () => TerminalProfile.CreateWindowsPowerShell());
            TryAdd(profiles, () => TerminalProfile.CreatePowerShell7());
            return profiles.AsReadOnly();
        }

        internal static TerminalProfile Resolve(string id, bool cleanProfile = false)
        {
            if (string.Equals(id, "command-prompt", StringComparison.OrdinalIgnoreCase))
                return TerminalProfile.CreateCommandPrompt();
            if (string.Equals(id, "windows-powershell", StringComparison.OrdinalIgnoreCase))
                return TerminalProfile.CreateWindowsPowerShell(cleanProfile);
            if (string.Equals(id, "powershell-7", StringComparison.OrdinalIgnoreCase))
                return TerminalProfile.CreatePowerShell7(cleanProfile);
            throw new ArgumentException("Unknown terminal profile: " + id, nameof(id));
        }

        private static void TryAdd(List<TerminalProfile> profiles, Func<TerminalProfile> factory)
        {
            try { profiles.Add(factory()); }
            catch (FileNotFoundException) { }
            catch (InvalidOperationException) { }
        }
    }
}
