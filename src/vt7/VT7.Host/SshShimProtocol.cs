using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;

namespace VT7.Host
{
    internal enum SshShimMessage : byte { Hello = 1, Challenge = 2, Request = 3, Response = 4, BarrierWritten = 5, Complete = 6 }
    internal enum SshShimAction : byte { Embedded = 1, System = 2, Reject = 3 }

    internal sealed class SshShimRequest
    {
        internal ushort Protocol { get; set; }
        internal uint ProcessId { get; set; }
        internal long CreationTime { get; set; }
        internal byte[] ClientNonce { get; set; } = Array.Empty<byte>();
        internal byte[] ServerNonce { get; set; } = Array.Empty<byte>();
        internal long Generation { get; set; }
        internal uint StandardInputFlags { get; set; }
        internal uint StandardOutputFlags { get; set; }
        internal uint StandardErrorFlags { get; set; }
        internal uint[] ConsoleProcesses { get; set; } = Array.Empty<uint>();
        internal string CurrentDirectory { get; set; } = string.Empty;
        internal string[] Arguments { get; set; } = Array.Empty<string>();
        internal byte[] Mac { get; set; } = Array.Empty<byte>();
        internal byte[] CanonicalBytes { get; set; } = Array.Empty<byte>();
    }

    internal sealed class SshInvocation
    {
        internal string Destination { get; set; } = string.Empty;
        internal string? User { get; set; }
        internal int Port { get; set; } = 22;
        internal string? KeyPath { get; set; }
        internal bool ForceIpv4 { get; set; }
        internal bool ForceIpv6 { get; set; }
    }

    internal static class SshInvocationParser
    {
        internal static bool TryParse(string[] arguments, string currentDirectory, out SshInvocation invocation, out string reason)
        {
            invocation = new SshInvocation();
            reason = "unsupported-grammar";
            if (arguments == null || arguments.Length < 2 || arguments.Length > 256) return false;
            string? destination = null;
            var sawUser = false;
            var sawPort = false;
            var sawKey = false;
            for (var index = 1; index < arguments.Length; ++index)
            {
                var token = arguments[index];
                if (!IsSafe(token)) { reason = "invalid-token"; return false; }
                if (destination != null) { reason = "remote-command"; return false; }
                if (token == "-4")
                {
                    if (invocation.ForceIpv4 || invocation.ForceIpv6) { reason = "conflicting-address-family"; return false; }
                    invocation.ForceIpv4 = true;
                }
                else if (token == "-6")
                {
                    if (invocation.ForceIpv4 || invocation.ForceIpv6) { reason = "conflicting-address-family"; return false; }
                    invocation.ForceIpv6 = true;
                }
                else if (token == "-l")
                {
                    if (sawUser || ++index >= arguments.Length || !IsSafe(arguments[index]) || arguments[index].StartsWith("-", StringComparison.Ordinal))
                    { reason = "invalid-user"; return false; }
                    invocation.User = arguments[index];
                    sawUser = true;
                }
                else if (token == "-p")
                {
                    if (sawPort || ++index >= arguments.Length || !int.TryParse(arguments[index], out var port) || port < 1 || port > 65535)
                    { reason = "invalid-port"; return false; }
                    invocation.Port = port;
                    sawPort = true;
                }
                else if (token == "-i")
                {
                    if (sawKey || ++index >= arguments.Length || !IsSafe(arguments[index]))
                    { reason = "invalid-key"; return false; }
                    var key = arguments[index];
                    invocation.KeyPath = Path.GetFullPath(Path.IsPathRooted(key) ? key : Path.Combine(currentDirectory, key));
                    sawKey = true;
                }
                else if (token.StartsWith("-", StringComparison.Ordinal))
                {
                    reason = "unsupported-option";
                    return false;
                }
                else
                {
                    destination = token;
                }
            }
            if (string.IsNullOrWhiteSpace(destination)) { reason = "missing-destination"; return false; }
            var at = destination!.LastIndexOf('@');
            if (at >= 0)
            {
                if (sawUser || at == 0 || at == destination.Length - 1)
                { reason = "invalid-destination"; return false; }
                invocation.User = destination.Substring(0, at);
                destination = destination.Substring(at + 1);
            }
            if (!IsSafe(destination) || destination.Any(char.IsWhiteSpace)) { reason = "invalid-destination"; return false; }
            invocation.Destination = destination;
            reason = "eligible";
            return true;
        }

        private static bool IsSafe(string value) => !string.IsNullOrEmpty(value) &&
            value.IndexOf('\0') < 0 && !value.Any(character => char.IsControl(character));
    }

    internal static class SshShimProtocol
    {
        internal const ushort Version = 1;
        internal const int MaximumFrame = 64 * 1024;
        internal const uint ConsoleHandleFlag = 0x10000;
        internal const uint FileTypeChar = 2;

        internal static byte[] Challenge(long generation, byte[] serverNonce) => Write(writer =>
        {
            writer.Write((byte)SshShimMessage.Challenge);
            writer.Write(Version);
            writer.Write(generation);
            writer.Write(serverNonce);
        });

        internal static byte[] Response(SshShimAction action, int exitCode, Guid requestId,
            string reason, string first, string second) => Write(writer =>
        {
            writer.Write((byte)SshShimMessage.Response);
            writer.Write((byte)action);
            writer.Write(exitCode);
            writer.Write(requestId.ToByteArray());
            WriteString(writer, reason);
            WriteString(writer, first);
            WriteString(writer, second);
        });

        internal static byte[] Complete(int exitCode, Guid requestId) => Write(writer =>
        {
            writer.Write((byte)SshShimMessage.Complete);
            writer.Write(exitCode);
            writer.Write(requestId.ToByteArray());
        });

        internal static void ParseHello(byte[] body, out uint processId, out long creationTime, out byte[] clientNonce)
        {
            using (var reader = Reader(body))
            {
                Require(reader.ReadByte() == (byte)SshShimMessage.Hello, "Unexpected shim hello type.");
                Require(reader.ReadUInt16() == Version, "Unknown shim protocol version.");
                processId = reader.ReadUInt32();
                creationTime = reader.ReadInt64();
                clientNonce = ReadExact(reader, 16);
                Require(reader.BaseStream.Position == reader.BaseStream.Length, "Trailing shim hello data.");
            }
        }

        internal static SshShimRequest ParseRequest(byte[] body)
        {
            Require(body.Length >= 32, "Truncated authenticated shim request.");
            var canonical = new byte[body.Length - 32];
            Buffer.BlockCopy(body, 0, canonical, 0, canonical.Length);
            using (var reader = Reader(body))
            {
                Require(reader.ReadByte() == (byte)SshShimMessage.Request, "Unexpected shim request type.");
                var request = new SshShimRequest
                {
                    Protocol = reader.ReadUInt16(),
                    ProcessId = reader.ReadUInt32(),
                    CreationTime = reader.ReadInt64(),
                    ClientNonce = ReadExact(reader, 16),
                    ServerNonce = ReadExact(reader, 16),
                    Generation = reader.ReadInt64(),
                    StandardInputFlags = reader.ReadUInt32(),
                    StandardOutputFlags = reader.ReadUInt32(),
                    StandardErrorFlags = reader.ReadUInt32(),
                    CanonicalBytes = canonical,
                };
                var processCount = reader.ReadUInt32();
                Require(processCount > 0 && processCount <= 256, "Invalid console process count.");
                request.ConsoleProcesses = Enumerable.Range(0, checked((int)processCount)).Select(_ => reader.ReadUInt32()).ToArray();
                request.CurrentDirectory = ReadString(reader);
                var argumentCount = reader.ReadUInt32();
                Require(argumentCount > 0 && argumentCount <= 256, "Invalid shim argument count.");
                request.Arguments = Enumerable.Range(0, checked((int)argumentCount)).Select(_ => ReadString(reader)).ToArray();
                request.Mac = ReadExact(reader, 32);
                Require(reader.BaseStream.Position == reader.BaseStream.Length, "Trailing authenticated shim request data.");
                return request;
            }
        }

        internal static void ParseBarrier(byte[] body, Guid requestId, byte[] serverNonce,
            out byte[] canonical, out byte[] mac)
        {
            Require(body.Length == 1 + 16 + 16 + 32, "Invalid barrier acknowledgement length.");
            canonical = new byte[body.Length - 32];
            Buffer.BlockCopy(body, 0, canonical, 0, canonical.Length);
            using (var reader = Reader(body))
            {
                Require(reader.ReadByte() == (byte)SshShimMessage.BarrierWritten, "Unexpected barrier acknowledgement.");
                Require(new Guid(ReadExact(reader, 16)) == requestId, "Barrier request identity mismatch.");
                Require(ReadExact(reader, 16).SequenceEqual(serverNonce), "Barrier server nonce mismatch.");
                mac = ReadExact(reader, 32);
            }
        }

        internal static bool HasConsoleHandles(SshShimRequest request) =>
            IsConsole(request.StandardInputFlags) && IsConsole(request.StandardOutputFlags) && IsConsole(request.StandardErrorFlags);

        private static bool IsConsole(uint flags) => (flags & 0xffff) == FileTypeChar && (flags & ConsoleHandleFlag) != 0;

        private static BinaryReader Reader(byte[] body)
        {
            Require(body != null && body.Length > 0 && body.Length <= MaximumFrame, "Invalid shim frame length.");
            return new BinaryReader(new MemoryStream(body, false), Encoding.Unicode, false);
        }

        private static byte[] Write(Action<BinaryWriter> action)
        {
            using (var stream = new MemoryStream())
            using (var writer = new BinaryWriter(stream, Encoding.Unicode, true))
            {
                action(writer);
                writer.Flush();
                return stream.ToArray();
            }
        }

        private static void WriteString(BinaryWriter writer, string value)
        {
            if (value == null || value.Length > 32767 || value.IndexOf('\0') >= 0) throw new InvalidDataException("Invalid protocol string.");
            writer.Write(value.Length);
            writer.Write(Encoding.Unicode.GetBytes(value));
        }

        private static string ReadString(BinaryReader reader)
        {
            var count = reader.ReadUInt32();
            Require(count <= 32767, "Protocol string exceeds bound.");
            return Encoding.Unicode.GetString(ReadExact(reader, checked((int)count * 2)));
        }

        private static byte[] ReadExact(BinaryReader reader, int count)
        {
            var bytes = reader.ReadBytes(count);
            Require(bytes.Length == count, "Truncated protocol field.");
            return bytes;
        }

        private static void Require(bool condition, string message)
        {
            if (!condition) throw new InvalidDataException(message);
        }
    }
}
