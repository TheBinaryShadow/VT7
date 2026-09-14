using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using System.Threading.Tasks;
using System.Web.Script.Serialization;
using Renci.SshNet;
using Renci.SshNet.Common;

namespace VT7.SshNetProbe
{
    internal static class Program
    {
        private const string Schema = "vt7-sshnet-s01-run-v1";
        private static readonly UTF8Encoding Utf8 = new UTF8Encoding(false);

        private static int Main(string[] args)
        {
            string? outputDirectory = null;
            var selfTest = false;
            for (var index = 0; index < args.Length; index++)
            {
                if (string.Equals(args[index], "--output", StringComparison.OrdinalIgnoreCase) && index + 1 < args.Length)
                    outputDirectory = args[++index];
                else if (string.Equals(args[index], "--self-test", StringComparison.OrdinalIgnoreCase))
                    selfTest = true;
                else
                    return Usage("Unknown or incomplete argument: " + args[index]);
            }

            if (string.IsNullOrWhiteSpace(outputDirectory))
                return Usage("--output is required.");

            outputDirectory = Path.GetFullPath(outputDirectory);
            if (Directory.Exists(outputDirectory))
                return Usage("Refusing to replace an existing S01 output directory.");
            Directory.CreateDirectory(outputDirectory);

            var manifest = BaseManifest(selfTest ? "self-test" : "network");
            var cases = new List<Dictionary<string, object?>>();
            manifest["cases"] = cases;
            var exitCode = 1;
            try
            {
                cases.Add(RunAssemblyCase(AppDomain.CurrentDomain.BaseDirectory));
                cases.Add(RunEncryptedKeyFixtureCase(AppDomain.CurrentDomain.BaseDirectory));
                if (selfTest)
                {
                    cases.Add(RunAlgorithmInventoryCase());
                    cases.Add(RunUtilityCase());
                }
                else
                {
                    RunNetworkCases(manifest, cases);
                }

                manifest["allPassed"] = cases.All(item => item.TryGetValue("passed", out var value) && value is bool passed && passed);
                exitCode = (bool)manifest["allPassed"]! ? 0 : 1;
            }
            catch (Exception error)
            {
                manifest["allPassed"] = false;
                manifest["error"] = SafeError(error);
                Console.Error.WriteLine("S01 failed: " + error.GetType().FullName);
            }
            finally
            {
                manifest["completedUtc"] = DateTime.UtcNow.ToString("o", CultureInfo.InvariantCulture);
                WriteJson(Path.Combine(outputDirectory, "manifest.json"), manifest);
            }

            Console.WriteLine("S01 result: " + Path.Combine(outputDirectory, "manifest.json"));
            return exitCode;
        }

        private static int Usage(string message)
        {
            Console.Error.WriteLine(message);
            Console.Error.WriteLine("Usage: VT7.SshNetProbe.exe --output <new-directory> [--self-test]");
            return 2;
        }

        private static Dictionary<string, object?> BaseManifest(string mode)
        {
            return new Dictionary<string, object?>
            {
                ["schema"] = Schema,
                ["createdUtc"] = DateTime.UtcNow.ToString("o", CultureInfo.InvariantCulture),
                ["mode"] = mode,
                ["machine"] = Environment.MachineName,
                ["osVersion"] = GetOsVersion(),
                ["osArchitecture"] = Environment.GetEnvironmentVariable("PROCESSOR_ARCHITECTURE") ?? string.Empty,
                ["processIs64Bit"] = Environment.Is64BitProcess,
                ["clrVersion"] = Environment.Version.ToString(),
                ["culture"] = CultureInfo.CurrentCulture.Name,
                ["uiCulture"] = CultureInfo.CurrentUICulture.Name
            };
        }

        private static Dictionary<string, object?> RunAssemblyCase(string binaryRoot)
        {
            var required = new[]
            {
                "Renci.SshNet.dll",
                "BouncyCastle.Cryptography.dll",
                "Microsoft.Bcl.AsyncInterfaces.dll",
                "Microsoft.Bcl.Cryptography.dll",
                "Microsoft.Extensions.DependencyInjection.Abstractions.dll",
                "Microsoft.Extensions.Logging.Abstractions.dll",
                "System.Buffers.dll",
                "System.Formats.Asn1.dll",
                "System.Memory.dll",
                "System.Numerics.Vectors.dll",
                "System.Runtime.CompilerServices.Unsafe.dll",
                "System.Threading.Tasks.Extensions.dll"
            };
            var files = new List<Dictionary<string, object?>>();
            foreach (var name in required)
            {
                var path = Path.Combine(binaryRoot, name);
                if (!File.Exists(path))
                    throw new FileNotFoundException("Required S01 runtime assembly is missing.", name);
                var assemblyName = AssemblyName.GetAssemblyName(path);
                files.Add(new Dictionary<string, object?>
                {
                    ["name"] = name,
                    ["assemblyName"] = assemblyName.Name ?? string.Empty,
                    ["assemblyVersion"] = assemblyName.Version?.ToString() ?? string.Empty,
                    ["bytes"] = new FileInfo(path).Length,
                    ["sha256"] = Sha256(path)
                });
            }

            var sshNet = typeof(SshClient).Assembly;
            var informational = sshNet.GetCustomAttribute<AssemblyInformationalVersionAttribute>()?.InformationalVersion ?? string.Empty;
            var passed = string.Equals(sshNet.GetName().Version?.ToString(), "2026.0.0.1", StringComparison.Ordinal) &&
                         informational.StartsWith("2026.0.0", StringComparison.Ordinal) && Environment.Is64BitProcess;
            return Case("assembly-load", passed,
                ("sshNetAssemblyVersion", sshNet.GetName().Version?.ToString() ?? string.Empty),
                ("sshNetInformationalVersion", informational),
                ("runtimeFiles", files));
        }

        private static Dictionary<string, object?> RunAlgorithmInventoryCase()
        {
            using var auth = new PasswordAuthenticationMethod("vt7-self-test", "not-used");
            var info = new ConnectionInfo("127.0.0.1", 22, "vt7-self-test", auth);
            var keyExchanges = info.KeyExchangeAlgorithms.Keys.ToArray();
            var hostKeys = info.HostKeyAlgorithms.Keys.ToArray();
            var encryptions = info.Encryptions.Keys.ToArray();
            var transportPolicy = IsModernTransportProtection("chacha20-poly1305@openssh.com", string.Empty) &&
                                  IsModernTransportProtection("aes128-ctr", "hmac-sha2-256") &&
                                  !IsModernTransportProtection("aes128-ctr", "hmac-sha1") &&
                                  !IsModernTransportProtection("aes128-cbc", "hmac-sha2-256");
            var passed = keyExchanges.Contains("sntrup761x25519-sha512") &&
                         hostKeys.Contains("ssh-ed25519") &&
                         encryptions.Contains("chacha20-poly1305@openssh.com") &&
                         transportPolicy;
            return Case("algorithm-inventory", passed,
                ("keyExchangeCount", keyExchanges.Length),
                ("hostKeyCount", hostKeys.Length),
                ("encryptionCount", encryptions.Length),
                ("hasSntrup761X25519Sha512", keyExchanges.Contains("sntrup761x25519-sha512")),
                ("hasSshEd25519", hostKeys.Contains("ssh-ed25519")),
                ("hasChaCha20Poly1305", encryptions.Contains("chacha20-poly1305@openssh.com")),
                ("transportPolicySelfTest", transportPolicy));
        }

        private static Dictionary<string, object?> RunEncryptedKeyFixtureCase(string binaryRoot)
        {
            var keyPath = Path.Combine(binaryRoot, "fixtures", "s01-encrypted-test-key");
            if (!File.Exists(keyPath)) throw new FileNotFoundException("The S01 encrypted-key fixture is missing.");
            var wrongPassphraseRejected = false;
            try
            {
                using var rejected = new PrivateKeyFile(keyPath, "wrong-s01-fixture-passphrase");
            }
            catch (Exception error) when (error is SshException || error is CryptographicException || error is FormatException)
            {
                wrongPassphraseRejected = true;
            }

            using var accepted = new PrivateKeyFile(keyPath, "vt7-s01-fixture");
            var algorithms = accepted.HostKeyAlgorithms.Select(item => item.Name).ToArray();
            var passed = wrongPassphraseRejected && accepted.Key.KeyLength == 256 && algorithms.Contains("ssh-ed25519");
            return Case("encrypted-key-load", passed,
                ("fixtureIsNonCredential", true),
                ("fixtureSha256", Sha256(keyPath)),
                ("wrongPassphraseRejected", wrongPassphraseRejected),
                ("keyBits", accepted.Key.KeyLength),
                ("algorithms", algorithms));
        }

        private static Dictionary<string, object?> RunUtilityCase()
        {
            var normalized = NormalizeFingerprint(" SHA256:AbCdEf0123456789+/ ");
            var compareEqual = FixedTimeEquals(normalized, "AbCdEf0123456789+/");
            var compareDifferent = !FixedTimeEquals(normalized, "BbCdEf0123456789+/");
            var safe = SafeError(new InvalidOperationException("secret.example.invalid C:\\secret\\key"));
            var serialized = SerializeJson(safe);
            var redacted = !serialized.Contains("secret.example.invalid") && !serialized.Contains("secret\\\\key");
            return Case("credential-redaction", compareEqual && compareDifferent && redacted,
                ("fingerprintNormalization", compareEqual),
                ("constantTimeComparison", compareDifferent),
                ("exceptionMessageExcluded", redacted));
        }

        private static void RunNetworkCases(Dictionary<string, object?> manifest, List<Dictionary<string, object?>> cases)
        {
            Console.Write("Controlled Debian server hostname or IP: ");
            var host = RequiredLine();
            Console.Write("SSH port [22]: ");
            var portText = Console.ReadLine();
            var port = string.IsNullOrWhiteSpace(portText) ? 22 : int.Parse(portText, CultureInfo.InvariantCulture);
            if (port < 1 || port > 65535) throw new ArgumentOutOfRangeException(nameof(port));
            Console.Write("SSH test username [sshtest]: ");
            var username = Console.ReadLine();
            if (string.IsNullOrWhiteSpace(username)) username = "sshtest";
            Console.Write("Full path to the dedicated private key: ");
            var identityPath = Path.GetFullPath(RequiredLine());
            if (!File.Exists(identityPath)) throw new FileNotFoundException("The private key was not found.");
            Console.Write("Trusted Debian host-key fingerprint (SHA256:...): ");
            var expectedFingerprint = NormalizeFingerprint(RequiredLine());
            if (!Regex.IsMatch(expectedFingerprint, "^[A-Za-z0-9+/]{43}$"))
                throw new FormatException("The trusted SHA256 host-key fingerprint has an invalid format.");
            var keyPassphrase = ReadSecret("Private-key passphrase (Enter if unencrypted): ");
            Console.Write("Run the password/keyboard-interactive authentication case too? [y/N]: ");
            var runPassword = IsYes(Console.ReadLine());
            var password = runPassword ? ReadSecret("Account password: ") : null;

            manifest["credentialHandling"] = new Dictionary<string, object?>
            {
                ["endpointRetained"] = false,
                ["usernameRetained"] = false,
                ["hostFingerprintRetained"] = false,
                ["privateKeyPathRetained"] = false,
                ["privateKeyPassphrasePrompted"] = true,
                ["privateKeyPassphraseSupplied"] = keyPassphrase.Length > 0,
                ["passwordCaseRequested"] = runPassword,
                ["passwordRetained"] = false
            };

            var keyFactory = new ClientFactory(host, port, username!, expectedFingerprint, identityPath, keyPassphrase, null);
            cases.Add(RunHostKeyRejectionCase(keyFactory));

            using (var context = keyFactory.Create())
            {
                Connect(context);
                cases.Add(ConnectionCase("public-key-connect", context, "publickey"));
                cases.Add(RunCommandBytesCase(context.Client));
                cases.Add(RunPtyCase(context.Client));
                cases.Add(RunCommandCancellationCase(context.Client));
            }

            cases.Add(RunSessionIsolationCase(keyFactory));
            cases.Add(RunActiveDisconnectCase(keyFactory));

            if (runPassword)
            {
                var passwordFactory = new ClientFactory(host, port, username!, expectedFingerprint, null, null, password);
                using var context = passwordFactory.Create();
                Connect(context);
                var result = ConnectionCase("password-authentication", context, "keyboard-interactive,password");
                result["keyboardInteractivePrompts"] = context.KeyboardInteractivePrompts;
                result["passed"] = (bool)result["passed"]! && context.Client.ConnectionInfo.IsAuthenticated;
                cases.Add(result);
            }
            else
            {
                cases.Add(Case("password-authentication", true, ("status", "not-requested")));
            }

            keyPassphrase = string.Empty;
            password = null;
        }

        private static Dictionary<string, object?> RunHostKeyRejectionCase(ClientFactory factory)
        {
            using var context = factory.Create(forceReject: true);
            var rejected = false;
            string exceptionType = string.Empty;
            try
            {
                context.Client.Connect();
            }
            catch (Exception error)
            {
                rejected = true;
                exceptionType = error.GetType().FullName ?? error.GetType().Name;
            }
            return Case("host-key-rejection", rejected && context.HostKeyEvents == 1 && !context.Client.IsConnected,
                ("hostKeyEvents", context.HostKeyEvents),
                ("authenticated", context.Client.ConnectionInfo.IsAuthenticated),
                ("exceptionType", exceptionType),
                ("trustDecision", "rejected"));
        }

        private static void Connect(ClientContext context)
        {
            var timer = Stopwatch.StartNew();
            using var cancellation = new CancellationTokenSource(TimeSpan.FromSeconds(20));
            context.Client.ConnectAsync(cancellation.Token).GetAwaiter().GetResult();
            timer.Stop();
            context.ConnectMilliseconds = timer.ElapsedMilliseconds;
            if (!context.Client.IsConnected || !context.Client.ConnectionInfo.IsAuthenticated || context.HostKeyEvents != 1)
                throw new InvalidOperationException("The SSH connection did not satisfy the trust/authentication contract.");
        }

        private static Dictionary<string, object?> ConnectionCase(string name, ClientContext context, string authentication)
        {
            var info = context.Client.ConnectionInfo;
            var modern = string.Equals(info.CurrentKeyExchangeAlgorithm, "sntrup761x25519-sha512", StringComparison.Ordinal) &&
                         string.Equals(info.CurrentHostKeyAlgorithm, "ssh-ed25519", StringComparison.Ordinal) &&
                         IsModernTransportProtection(info.CurrentClientEncryption, info.CurrentClientHmacAlgorithm) &&
                         IsModernTransportProtection(info.CurrentServerEncryption, info.CurrentServerHmacAlgorithm);
            return Case(name, context.Client.IsConnected && info.IsAuthenticated && context.HostKeyEvents == 1 && modern,
                ("authentication", authentication),
                ("hostKeyEvents", context.HostKeyEvents),
                ("trusted", context.Trusted),
                ("hostKeyAlgorithm", context.HostKeyName),
                ("hostKeyBits", context.HostKeyBits),
                ("connectMilliseconds", context.ConnectMilliseconds),
                ("serverVersion", info.ServerVersion ?? string.Empty),
                ("keyExchange", info.CurrentKeyExchangeAlgorithm ?? string.Empty),
                ("currentHostKey", info.CurrentHostKeyAlgorithm ?? string.Empty),
                ("clientEncryption", info.CurrentClientEncryption ?? string.Empty),
                ("serverEncryption", info.CurrentServerEncryption ?? string.Empty),
                ("clientHmac", info.CurrentClientHmacAlgorithm ?? string.Empty),
                ("serverHmac", info.CurrentServerHmacAlgorithm ?? string.Empty),
                ("clientCompression", info.CurrentClientCompressionAlgorithm ?? string.Empty),
                ("serverCompression", info.CurrentServerCompressionAlgorithm ?? string.Empty),
                ("negotiationPolicy", "sntrup761x25519-sha512,ssh-ed25519,modern-encryption"),
                ("modernPolicySatisfied", modern));
        }

        private static bool IsModernTransportProtection(string? encryption, string? hmac)
        {
            if (string.Equals(encryption, "chacha20-poly1305@openssh.com", StringComparison.Ordinal) ||
                string.Equals(encryption, "aes128-gcm@openssh.com", StringComparison.Ordinal) ||
                string.Equals(encryption, "aes256-gcm@openssh.com", StringComparison.Ordinal))
                return true;

            var ctr = string.Equals(encryption, "aes128-ctr", StringComparison.Ordinal) ||
                      string.Equals(encryption, "aes192-ctr", StringComparison.Ordinal) ||
                      string.Equals(encryption, "aes256-ctr", StringComparison.Ordinal);
            return ctr && (string.Equals(hmac, "hmac-sha2-256", StringComparison.Ordinal) ||
                           string.Equals(hmac, "hmac-sha2-512", StringComparison.Ordinal) ||
                           string.Equals(hmac, "hmac-sha2-256-etm@openssh.com", StringComparison.Ordinal) ||
                           string.Equals(hmac, "hmac-sha2-512-etm@openssh.com", StringComparison.Ordinal));
        }

        private static Dictionary<string, object?> RunCommandBytesCase(SshClient client)
        {
            var expectedOutput = Hex("00017f1b0d0ac48dc58de282acf09f9982");
            var expectedError = Hex("455252000aff");
            var commandText = "python3 -c \"import os;os.write(1,bytes.fromhex('" + ToHex(expectedOutput) + "'));os.write(2,bytes.fromhex('" + ToHex(expectedError) + "'));raise SystemExit(37)\"";
            using var command = client.CreateCommand(commandText);
            command.CommandTimeout = TimeSpan.FromSeconds(15);
            command.ExecuteAsync(CancellationToken.None).GetAwaiter().GetResult();
            var output = ReadAll(command.OutputStream);
            var error = ReadAll(command.ExtendedOutputStream);
            var passed = output.SequenceEqual(expectedOutput) && error.SequenceEqual(expectedError) && command.ExitStatus == 37;
            return Case("command-byte-fidelity", passed,
                ("stdoutBytes", output.Length),
                ("stdoutSha256", Sha256(output)),
                ("stderrBytes", error.Length),
                ("stderrSha256", Sha256(error)),
                ("exitStatus", command.ExitStatus),
                ("exitSignal", command.ExitSignal ?? string.Empty));
        }

        private static Dictionary<string, object?> RunPtyCase(SshClient client)
        {
            const uint initialColumns = 80;
            const uint initialRows = 24;
            using var stream = client.CreateShellStream("xterm-256color", initialColumns, initialRows, 640, 384, 1024 * 1024);
            var capture = new ByteCapture();
            capture.Collect(stream, TimeSpan.FromMilliseconds(500));
            capture.Send(stream, "stty -echo -opost\n");
            capture.Collect(stream, TimeSpan.FromMilliseconds(300));
            capture.Clear();

            var initialMarker = Marker("INITIAL");
            capture.Send(stream, "stty size; printf '\\n" + initialMarker + "\\n'\n");
            var initial = capture.ReadThrough(stream, initialMarker, TimeSpan.FromSeconds(10));
            var initialSize = ContainsSize(initial, initialRows, initialColumns);

            var rawPayload = Hex("001b5b33316d5654371b5b306d00c48dc58de282acf09f9982");
            var rawBegin = Marker("RAWBEGIN");
            var rawEnd = Marker("RAWEND");
            var rawBytes = Hex(ToHex(Utf8.GetBytes(rawBegin)) + ToHex(rawPayload) + ToHex(Utf8.GetBytes(rawEnd)));
            var rawDone = Marker("RAWDONE");
            capture.Clear();
            capture.Send(stream, "python3 -c \"import os;os.write(1,bytes.fromhex('" + ToHex(rawBytes) + "'))\"; printf '\\n" + rawDone + "\\n'\n");
            var rawCapture = capture.ReadThrough(stream, rawDone, TimeSpan.FromSeconds(10));
            var rawExact = IndexOf(rawCapture, rawBytes) >= 0;

            stream.ChangeWindowSize(100, 30, 800, 600);
            var resizeMarker = Marker("RESIZE");
            capture.Clear();
            capture.Send(stream, "stty size; printf '\\n" + resizeMarker + "\\n'\n");
            var resized = capture.ReadThrough(stream, resizeMarker, TimeSpan.FromSeconds(10));
            var resizeExact = ContainsSize(resized, 30, 100);

            stream.ChangeWindowSize(81, 25, 648, 400);
            stream.ChangeWindowSize(120, 40, 960, 640);
            stream.ChangeWindowSize(93, 31, 744, 496);
            var burstMarker = Marker("BURST");
            capture.Clear();
            capture.Send(stream, "stty size; printf '\\n" + burstMarker + "\\n'\n");
            var burst = capture.ReadThrough(stream, burstMarker, TimeSpan.FromSeconds(10));
            var burstExact = ContainsSize(burst, 31, 93);

            var drainBegin = Marker("DRAINBEGIN");
            var drainEnd = Marker("DRAINEND");
            var drainDone = Marker("DRAINDONE");
            capture.Clear();
            capture.Send(stream, "python3 -c \"import os;os.write(1,b'" + drainBegin + "'+b'Z'*131071+b'" + drainEnd + "')\"; printf '\\n" + drainDone + "\\n'\n");
            var drained = capture.ReadThrough(stream, drainDone, TimeSpan.FromSeconds(20));
            var beginIndex = IndexOf(drained, Utf8.GetBytes(drainBegin));
            var endIndex = IndexOf(drained, Utf8.GetBytes(drainEnd));
            var drainBytes = beginIndex >= 0 && endIndex > beginIndex ? endIndex - beginIndex - drainBegin.Length : -1;

            var exitMarker = Marker("EXIT");
            capture.Clear();
            capture.Send(stream, "printf '" + exitMarker + "'; exit\n");
            capture.ReadThrough(stream, exitMarker, TimeSpan.FromSeconds(10));
            var eofZero = WaitForEof(stream, TimeSpan.FromSeconds(10));

            var passed = initialSize && rawExact && resizeExact && burstExact && drainBytes == 131071 && eofZero;
            return Case("interactive-pty", passed,
                ("terminal", "xterm-256color"),
                ("initialColumns", initialColumns),
                ("initialRows", initialRows),
                ("initialSizeObserved", initialSize),
                ("rawPayloadBytes", rawPayload.Length),
                ("rawFrameBytes", rawBytes.Length),
                ("rawFrameSha256", Sha256(rawBytes)),
                ("rawFrameObserved", rawExact),
                ("liveResizeColumns", 100),
                ("liveResizeRows", 30),
                ("liveResizeObserved", resizeExact),
                ("burstFinalColumns", 93),
                ("burstFinalRows", 31),
                ("burstFinalObserved", burstExact),
                ("drainPayloadBytes", drainBytes),
                ("eofReadReturnedZero", eofZero));
        }

        private static Dictionary<string, object?> RunCommandCancellationCase(SshClient client)
        {
            using var command = client.CreateCommand("python3 -c \"import os,time\nwhile True: os.write(1,b'X'*4096);time.sleep(.01)\"");
            command.CommandTimeout = TimeSpan.FromSeconds(20);
            using var cancellation = new CancellationTokenSource();
            var timer = Stopwatch.StartNew();
            var task = command.ExecuteAsync(cancellation.Token);
            Thread.Sleep(400);
            cancellation.Cancel();
            var completed = false;
            var cancellationObserved = false;
            try
            {
                completed = task.Wait(TimeSpan.FromSeconds(8));
            }
            catch (AggregateException error) when (error.InnerExceptions.All(item => item is OperationCanceledException || item is SshException))
            {
                completed = true;
                cancellationObserved = true;
            }
            timer.Stop();
            var output = ReadAll(command.OutputStream);
            var passed = completed && output.Length > 0 && timer.Elapsed < TimeSpan.FromSeconds(10);
            return Case("active-command-cancellation", passed,
                ("completed", completed),
                ("cancellationObserved", cancellationObserved || task.IsCanceled),
                ("milliseconds", timer.ElapsedMilliseconds),
                ("stdoutBytes", output.Length),
                ("stdoutSha256", Sha256(output)),
                ("exitStatus", command.ExitStatus),
                ("exitSignal", command.ExitSignal ?? string.Empty));
        }

        private static Dictionary<string, object?> RunSessionIsolationCase(ClientFactory factory)
        {
            using var first = factory.Create();
            using var second = factory.Create();
            Connect(first);
            Connect(second);
            var firstToken = "VT7A" + Guid.NewGuid().ToString("N");
            var secondToken = "VT7B" + Guid.NewGuid().ToString("N");
            var firstTask = Task.Run(() => RunTextCommand(first.Client, firstToken));
            var secondTask = Task.Run(() => RunTextCommand(second.Client, secondToken));
            if (!Task.WaitAll(new Task[] { firstTask, secondTask }, TimeSpan.FromSeconds(15)))
                throw new TimeoutException("Concurrent SSH session commands did not complete.");
            var firstOutput = firstTask.Result;
            var secondOutput = secondTask.Result;
            var crossSessionRouting = firstOutput.Contains(secondToken) || secondOutput.Contains(firstToken);
            var passed = string.Equals(firstOutput, firstToken + firstToken, StringComparison.Ordinal) &&
                         string.Equals(secondOutput, secondToken + secondToken, StringComparison.Ordinal) &&
                         !crossSessionRouting;
            return Case("session-isolation", passed,
                ("sessions", 2),
                ("firstBytes", Utf8.GetByteCount(firstOutput)),
                ("secondBytes", Utf8.GetByteCount(secondOutput)),
                ("firstSha256", Sha256(Utf8.GetBytes(firstOutput))),
                ("secondSha256", Sha256(Utf8.GetBytes(secondOutput))),
                ("crossSessionRouting", crossSessionRouting));
        }

        private static Dictionary<string, object?> RunActiveDisconnectCase(ClientFactory factory)
        {
            using var context = factory.Create();
            Connect(context);
            using var stream = context.Client.CreateShellStream("xterm-256color", 80, 24, 640, 384, 65536);
            var capture = new ByteCapture();
            capture.Collect(stream, TimeSpan.FromMilliseconds(500));
            capture.Send(stream, "stty -echo -opost\n");
            capture.Collect(stream, TimeSpan.FromMilliseconds(300));
            capture.Clear();

            var readyMarker = Marker("DISCONNECTREADY");
            capture.Send(stream, "printf '\\n" + readyMarker + "\\n'; sleep 30\n");
            var ready = capture.ReadThrough(stream, readyMarker, TimeSpan.FromSeconds(10));
            var markerObserved = IndexOf(ready, Utf8.GetBytes(readyMarker)) >= 0;
            var buffer = new byte[4096];
            var pending = stream.BeginRead(buffer, 0, buffer.Length, null, null);
            var pendingBeforeShutdown = !pending.AsyncWaitHandle.WaitOne(TimeSpan.FromMilliseconds(300));
            var timer = Stopwatch.StartNew();
            stream.Dispose();
            var readCompleted = pending.AsyncWaitHandle.WaitOne(TimeSpan.FromSeconds(5));
            var finalRead = readCompleted ? stream.EndRead(pending) : -1;
            context.Client.Disconnect();
            timer.Stop();
            var eofObserved = readCompleted && finalRead == 0;
            var passed = markerObserved && pendingBeforeShutdown && eofObserved && !context.Client.IsConnected && timer.Elapsed < TimeSpan.FromSeconds(8);
            return Case("active-disconnect", passed,
                ("readyMarkerObserved", markerObserved),
                ("pendingReadWasPending", pendingBeforeShutdown),
                ("streamDisposedBeforeClientDisconnect", true),
                ("pendingReadCompleted", readCompleted),
                ("finalReadBytes", finalRead),
                ("eofObserved", eofObserved),
                ("clientConnectedAfterDisconnect", context.Client.IsConnected),
                ("milliseconds", timer.ElapsedMilliseconds));
        }

        private static string RunTextCommand(SshClient client, string token)
        {
            using var command = client.CreateCommand("printf '" + token + "'; sleep 0.2; printf '" + token + "'");
            command.CommandTimeout = TimeSpan.FromSeconds(10);
            return command.Execute();
        }

        private static bool WaitForEof(ShellStream stream, TimeSpan timeout)
        {
            var buffer = new byte[64];
            var timer = Stopwatch.StartNew();
            while (timer.Elapsed < timeout)
            {
                var result = stream.BeginRead(buffer, 0, buffer.Length, null, null);
                var remaining = timeout - timer.Elapsed;
                if (remaining <= TimeSpan.Zero || !result.AsyncWaitHandle.WaitOne(remaining)) return false;
                if (stream.EndRead(result) == 0) return true;
            }
            return false;
        }

        private static bool ContainsSize(byte[] bytes, uint rows, uint columns)
        {
            var text = Encoding.ASCII.GetString(bytes);
            return Regex.IsMatch(text, "(?:^|[^0-9])" + rows.ToString(CultureInfo.InvariantCulture) + "[ \\t]+" + columns.ToString(CultureInfo.InvariantCulture) + "(?:[^0-9]|$)");
        }

        private static string Marker(string label) => "__VT7_S01_" + label + "_" + Guid.NewGuid().ToString("N") + "__";

        private static int IndexOf(byte[] haystack, byte[] needle)
        {
            if (needle.Length == 0) return 0;
            for (var index = 0; index <= haystack.Length - needle.Length; index++)
            {
                var equal = true;
                for (var offset = 0; offset < needle.Length; offset++)
                {
                    if (haystack[index + offset] == needle[offset]) continue;
                    equal = false;
                    break;
                }
                if (equal) return index;
            }
            return -1;
        }

        private static byte[] ReadAll(Stream stream)
        {
            using var output = new MemoryStream();
            stream.CopyTo(output);
            return output.ToArray();
        }

        private static byte[] Hex(string text)
        {
            if ((text.Length & 1) != 0) throw new FormatException("Hex input length is odd.");
            var bytes = new byte[text.Length / 2];
            for (var index = 0; index < bytes.Length; index++)
                bytes[index] = byte.Parse(text.Substring(index * 2, 2), NumberStyles.HexNumber, CultureInfo.InvariantCulture);
            return bytes;
        }

        private static string ToHex(byte[] bytes)
        {
            var builder = new StringBuilder(bytes.Length * 2);
            foreach (var value in bytes) builder.Append(value.ToString("x2", CultureInfo.InvariantCulture));
            return builder.ToString();
        }

        private static string NormalizeFingerprint(string value)
        {
            value = value.Trim();
            if (value.StartsWith("SHA256:", StringComparison.OrdinalIgnoreCase)) value = value.Substring(7);
            return value.TrimEnd('=');
        }

        private static bool FixedTimeEquals(string left, string right)
        {
            var difference = left.Length ^ right.Length;
            var count = Math.Max(left.Length, right.Length);
            for (var index = 0; index < count; index++)
            {
                var a = index < left.Length ? left[index] : 0;
                var b = index < right.Length ? right[index] : 0;
                difference |= a ^ b;
            }
            return difference == 0;
        }

        private static string RequiredLine()
        {
            var value = Console.ReadLine();
            if (string.IsNullOrWhiteSpace(value)) throw new InvalidOperationException("A required runtime value was not supplied.");
            return value.Trim();
        }

        private static string ReadSecret(string prompt)
        {
            Console.Write(prompt);
            var builder = new StringBuilder();
            while (true)
            {
                var key = Console.ReadKey(intercept: true);
                if (key.Key == ConsoleKey.Enter) break;
                if (key.Key == ConsoleKey.Backspace)
                {
                    if (builder.Length > 0) builder.Length--;
                    continue;
                }
                if (!char.IsControl(key.KeyChar)) builder.Append(key.KeyChar);
            }
            Console.WriteLine();
            return builder.ToString();
        }

        private static bool IsYes(string? value) => string.Equals(value?.Trim(), "y", StringComparison.OrdinalIgnoreCase) || string.Equals(value?.Trim(), "yes", StringComparison.OrdinalIgnoreCase);

        private static Dictionary<string, object?> SafeError(Exception error)
        {
            while (error is AggregateException aggregate && aggregate.InnerExceptions.Count == 1) error = aggregate.InnerExceptions[0];
            return new Dictionary<string, object?>
            {
                ["type"] = error.GetType().FullName ?? error.GetType().Name,
                ["hresult"] = error.HResult,
                ["category"] = ErrorCategory(error)
            };
        }

        private static string ErrorCategory(Exception error)
        {
            if (error is SshAuthenticationException) return "authentication";
            if (error is SshConnectionException) return "ssh-connection";
            if (error is System.Net.Sockets.SocketException) return "network";
            if (error is OperationCanceledException || error is TimeoutException) return "cancelled-or-timeout";
            if (error is FileNotFoundException || error is IOException) return "local-io";
            if (error is FormatException || error is ArgumentException) return "runtime-input";
            return "probe";
        }

        private static Dictionary<string, object?> Case(string name, bool passed, params (string Name, object? Value)[] fields)
        {
            var result = new Dictionary<string, object?> { ["name"] = name, ["passed"] = passed };
            foreach (var field in fields) result[field.Name] = field.Value;
            return result;
        }

        private static string Sha256(string path)
        {
            using var stream = File.OpenRead(path);
            using var sha = SHA256.Create();
            return ToHex(sha.ComputeHash(stream)).ToUpperInvariant();
        }

        private static string Sha256(byte[] bytes)
        {
            using var sha = SHA256.Create();
            return ToHex(sha.ComputeHash(bytes)).ToUpperInvariant();
        }

        private static string GetOsVersion()
        {
            var version = new OsVersionInfo { Size = Marshal.SizeOf(typeof(OsVersionInfo)) };
            if (RtlGetVersion(ref version) == 0)
                return string.Format(CultureInfo.InvariantCulture, "Microsoft Windows NT {0}.{1}.{2} Service Pack {3}.{4}", version.Major, version.Minor, version.Build, version.ServicePackMajor, version.ServicePackMinor);
            return Environment.OSVersion.VersionString;
        }

        private static string SerializeJson(object value)
        {
            var serializer = new JavaScriptSerializer { MaxJsonLength = int.MaxValue, RecursionLimit = 100 };
            return serializer.Serialize(value);
        }

        private static void WriteJson(string path, object value)
        {
            File.WriteAllText(path, SerializeJson(value), Utf8);
        }

        private sealed class ByteCapture
        {
            private readonly MemoryStream _bytes = new MemoryStream();

            internal void Clear() => _bytes.SetLength(0);

            internal void Send(ShellStream stream, string text)
            {
                var bytes = Utf8.GetBytes(text);
                stream.Write(bytes, 0, bytes.Length);
                stream.Flush();
            }

            internal void Collect(ShellStream stream, TimeSpan duration)
            {
                var until = Stopwatch.StartNew();
                var buffer = new byte[8192];
                while (until.Elapsed < duration)
                {
                    if (!stream.DataAvailable)
                    {
                        Thread.Sleep(10);
                        continue;
                    }
                    var count = stream.Read(buffer, 0, buffer.Length);
                    if (count == 0) break;
                    _bytes.Write(buffer, 0, count);
                }
            }

            internal byte[] ReadThrough(ShellStream stream, string marker, TimeSpan timeout)
            {
                var markerBytes = Utf8.GetBytes(marker);
                var timer = Stopwatch.StartNew();
                var buffer = new byte[8192];
                while (timer.Elapsed < timeout)
                {
                    if (IndexOf(_bytes.ToArray(), markerBytes) >= 0) return _bytes.ToArray();
                    if (!stream.DataAvailable)
                    {
                        Thread.Sleep(10);
                        continue;
                    }
                    var count = stream.Read(buffer, 0, buffer.Length);
                    if (count == 0) break;
                    _bytes.Write(buffer, 0, count);
                }
                throw new TimeoutException("The interactive shell did not reach its bounded marker.");
            }
        }

        private sealed class ClientFactory
        {
            private readonly string _host;
            private readonly int _port;
            private readonly string _username;
            private readonly string _fingerprint;
            private readonly string? _identityPath;
            private readonly string? _keyPassphrase;
            private readonly string? _password;

            internal ClientFactory(string host, int port, string username, string fingerprint, string? identityPath, string? keyPassphrase, string? password)
            {
                _host = host;
                _port = port;
                _username = username;
                _fingerprint = fingerprint;
                _identityPath = identityPath;
                _keyPassphrase = keyPassphrase;
                _password = password;
            }

            internal ClientContext Create(bool forceReject = false)
            {
                AuthenticationMethod[] methods;
                KeyboardInteractiveAuthenticationMethod? keyboard = null;
                if (_identityPath != null)
                {
                    var key = string.IsNullOrEmpty(_keyPassphrase) ? new PrivateKeyFile(_identityPath) : new PrivateKeyFile(_identityPath, _keyPassphrase);
                    methods = new AuthenticationMethod[] { new PrivateKeyAuthenticationMethod(_username, key) };
                }
                else
                {
                    keyboard = new KeyboardInteractiveAuthenticationMethod(_username);
                    var password = _password ?? string.Empty;
                    keyboard.AuthenticationPrompt += (_, eventArgs) =>
                    {
                        foreach (var prompt in eventArgs.Prompts) prompt.Response = password;
                    };
                    methods = new AuthenticationMethod[] { keyboard, new PasswordAuthenticationMethod(_username, password) };
                }

                var info = new ConnectionInfo(_host, _port, _username, methods)
                {
                    Timeout = TimeSpan.FromSeconds(15),
                    ChannelCloseTimeout = TimeSpan.FromSeconds(5),
                    Encoding = Utf8
                };
                var client = new SshClient(info) { KeepAliveInterval = TimeSpan.FromSeconds(5) };
                var context = new ClientContext(client);
                if (keyboard != null)
                {
                    keyboard.AuthenticationPrompt += (_, eventArgs) => context.KeyboardInteractivePrompts += eventArgs.Prompts.Count;
                }
                client.HostKeyReceived += (_, eventArgs) =>
                {
                    context.HostKeyEvents++;
                    context.HostKeyName = eventArgs.HostKeyName;
                    context.HostKeyBits = eventArgs.KeyLength;
                    context.Trusted = !forceReject && FixedTimeEquals(NormalizeFingerprint(eventArgs.FingerPrintSHA256), _fingerprint);
                    eventArgs.CanTrust = context.Trusted;
                };
                return context;
            }
        }

        private sealed class ClientContext : IDisposable
        {
            internal ClientContext(SshClient client) => Client = client;
            internal SshClient Client { get; }
            internal int HostKeyEvents { get; set; }
            internal bool Trusted { get; set; }
            internal string HostKeyName { get; set; } = string.Empty;
            internal int HostKeyBits { get; set; }
            internal long ConnectMilliseconds { get; set; }
            internal int KeyboardInteractivePrompts { get; set; }
            public void Dispose() => Client.Dispose();
        }

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        private struct OsVersionInfo
        {
            internal int Size;
            internal int Major;
            internal int Minor;
            internal int Build;
            internal int PlatformId;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] internal string ServicePack;
            internal ushort ServicePackMajor;
            internal ushort ServicePackMinor;
            internal ushort SuiteMask;
            internal byte ProductType;
            internal byte Reserved;
        }

        [DllImport("ntdll.dll", CharSet = CharSet.Unicode)]
        private static extern int RtlGetVersion(ref OsVersionInfo version);
    }
}
