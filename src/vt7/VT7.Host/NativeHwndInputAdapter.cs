using System;
using System.Collections.Generic;

namespace VT7.Host
{
    internal sealed class NativeHwndInputAdapter
    {
        internal const int WmSetFocus = 0x0007;
        internal const int WmKillFocus = 0x0008;
        internal const int WmSize = 0x0005;
        internal const int WmAuthoritativeGrid = 0x8002;
        internal const int WmKeyDown = 0x0100;
        internal const int WmKeyUp = 0x0101;
        internal const int WmChar = 0x0102;
        internal const int WmDeadChar = 0x0103;
        internal const int WmSysKeyDown = 0x0104;
        internal const int WmSysKeyUp = 0x0105;
        internal const int WmSysChar = 0x0106;
        internal const int WmSysDeadChar = 0x0107;

        private const uint RightAltPressed = 0x0001;
        private const uint LeftAltPressed = 0x0002;
        private const uint RightCtrlPressed = 0x0004;
        private const uint LeftCtrlPressed = 0x0008;
        private const uint ShiftPressed = 0x0010;
        private const uint NumlockOn = 0x0020;
        private const uint ScrolllockOn = 0x0040;
        private const uint CapslockOn = 0x0080;
        private const uint EnhancedKey = 0x0100;

        private readonly TerminalSurface _surface;
        private readonly SessionOutboundQueue _queue;
        private readonly long _generation;
        private readonly Action<string> _failure;
        private readonly HashSet<uint> _pressedModifiers = new HashSet<uint>();
        private uint _suppressedCharacter;
        private uint _suppressedCharacterCount;

        internal NativeHwndInputAdapter(TerminalSurface surface, SessionOutboundQueue queue, long generation, Action<string> failure)
        {
            _surface = surface ?? throw new ArgumentNullException(nameof(surface));
            _queue = queue ?? throw new ArgumentNullException(nameof(queue));
            _generation = generation;
            _failure = failure ?? throw new ArgumentNullException(nameof(failure));
        }

        internal bool ProcessMessage(int message, IntPtr wParam, IntPtr lParam)
        {
            if (!_queue.IsCurrent(_generation)) return false;
            switch (message)
            {
            case WmDeadChar:
            case WmSysDeadChar:
                return true;
            case WmChar:
            case WmSysChar:
                return ProcessCharacter(unchecked((uint)wParam.ToInt64()), lParam);
            case WmKeyDown:
            case WmSysKeyDown:
                return ProcessKey(unchecked((uint)wParam.ToInt64()), lParam, true);
            case WmKeyUp:
            case WmSysKeyUp:
                return ProcessKey(unchecked((uint)wParam.ToInt64()), lParam, false);
            case WmSetFocus:
                return ProcessFocus(true);
            case WmKillFocus:
                ReleaseModifiers();
                return ProcessFocus(false);
            default:
                return false;
            }
        }

        internal void ObserveAuthoritativeGrid(uint columns, uint rows)
        {
            if (columns == 0 || rows == 0 || !_queue.IsCurrent(_generation)) return;
            CheckEnqueue(_queue.TryEnqueue(_generation, SessionOutboundOperation.Resize(columns, rows)), "resize");
        }

        private bool ProcessCharacter(uint character, IntPtr lParam)
        {
            if (_suppressedCharacterCount > 0 && character == _suppressedCharacter)
            {
                --_suppressedCharacterCount;
                return true;
            }
            _suppressedCharacterCount = 0;
            var repeat = RepeatCount(lParam);
            var scan = ScanCode(lParam);
            var encoded = _surface.EncodeCharacter(character, scan, ControlState(lParam), repeat);
            if (encoded.Bytes.Length > 0)
                CheckEnqueue(_queue.TryEnqueue(_generation,
                    SessionOutboundOperation.Input(SessionOutboundKind.InputBytes, encoded.Bytes)), "committed text");
            return encoded.Handled;
        }

        private bool ProcessKey(uint virtualKey, IntPtr lParam, bool keyDown)
        {
            var scan = ScanCode(lParam);
            var extended = IsExtended(lParam);
            var canonical = CanonicalModifier(virtualKey, scan, extended);
            if (IsModifier(canonical))
            {
                if (keyDown) _pressedModifiers.Add(canonical);
                else _pressedModifiers.Remove(canonical);
            }
            var state = ControlState(lParam);
            var ctrl = (state & (RightCtrlPressed | LeftCtrlPressed)) != 0;
            var alt = (state & (RightAltPressed | LeftAltPressed)) != 0;

            if (keyDown && ctrl && !alt && virtualKey == 0x43)
            {
                var repeat = RepeatCount(lParam);
                ArmCharacterSuppression(3, repeat);
                var bytes = new byte[repeat];
                for (var index = 0; index < bytes.Length; ++index) bytes[index] = 3;
                CheckEnqueue(_queue.TryEnqueue(_generation,
                    SessionOutboundOperation.Input(SessionOutboundKind.Interrupt, bytes)), "Ctrl+C");
                return true;
            }
            if (keyDown && ctrl && !alt && virtualKey == 0x03)
            {
                var repeat = RepeatCount(lParam);
                ArmCharacterSuppression(3, repeat);
                var bytes = new byte[repeat];
                for (var index = 0; index < bytes.Length; ++index) bytes[index] = 3;
                CheckEnqueue(_queue.TryEnqueue(_generation,
                    SessionOutboundOperation.Input(SessionOutboundKind.Break, bytes)), "Ctrl+Break");
                return true;
            }

            if (!IsNativeKeyCandidate(canonical)) return false;
            var encoded = _surface.EncodeKey(virtualKey, scan, state, keyDown, keyDown ? RepeatCount(lParam) : 1u);
            if (encoded.Bytes.Length > 0)
            {
                CheckEnqueue(_queue.TryEnqueue(_generation,
                    SessionOutboundOperation.Input(SessionOutboundKind.InputBytes, encoded.Bytes)), "key input");
                if (keyDown)
                {
                    if (canonical == 0x08) ArmCharacterSuppression(8, RepeatCount(lParam));
                    if (canonical == 0x09) ArmCharacterSuppression(9, RepeatCount(lParam));
                    if (canonical == 0x0D) ArmCharacterSuppression(ctrl ? 10u : 13u, RepeatCount(lParam));
                }
            }
            return encoded.Handled;
        }

        private bool ProcessFocus(bool focused)
        {
            var encoded = _surface.EncodeFocus(focused);
            CheckEnqueue(_queue.TryEnqueue(_generation, SessionOutboundOperation.Focus(focused, encoded.Bytes)), "focus");
            return true;
        }

        private void ReleaseModifiers()
        {
            foreach (var virtualKey in new List<uint>(_pressedModifiers))
            {
                _pressedModifiers.Remove(virtualKey);
                var extended = virtualKey == 0xA3 || virtualKey == 0xA5;
                var generic = virtualKey == 0xA0 || virtualKey == 0xA1 ? 0x10u :
                    virtualKey == 0xA2 || virtualKey == 0xA3 ? 0x11u : 0x12u;
                _surface.EncodeKey(generic, 0, ControlState(IntPtr.Zero) | (extended ? EnhancedKey : 0), false, 1);
            }
            _pressedModifiers.Clear();
            _suppressedCharacterCount = 0;
        }

        private void ArmCharacterSuppression(uint character, uint count)
        {
            if (_suppressedCharacterCount != 0 && _suppressedCharacter == character)
                _suppressedCharacterCount = checked(_suppressedCharacterCount + count);
            else
            {
                _suppressedCharacter = character;
                _suppressedCharacterCount = count;
            }
        }

        private uint ControlState(IntPtr lParam)
        {
            uint state = 0;
            foreach (var key in _pressedModifiers)
            {
                switch (key)
                {
                case 0xA0:
                case 0xA1: state |= ShiftPressed; break;
                case 0xA2: state |= LeftCtrlPressed; break;
                case 0xA3: state |= RightCtrlPressed; break;
                case 0xA4: state |= LeftAltPressed; break;
                case 0xA5: state |= RightAltPressed; break;
                }
            }
            if ((NativeMethods.GetKeyState(0x90) & 1) != 0) state |= NumlockOn;
            if ((NativeMethods.GetKeyState(0x91) & 1) != 0) state |= ScrolllockOn;
            if ((NativeMethods.GetKeyState(0x14) & 1) != 0) state |= CapslockOn;
            if (IsExtended(lParam)) state |= EnhancedKey;
            return state;
        }

        private void CheckEnqueue(SessionEnqueueResult result, string source)
        {
            if (result == SessionEnqueueResult.Full)
                _failure("The bounded outbound session queue is full while accepting " + source + ".");
        }

        private static uint RepeatCount(IntPtr lParam) => Math.Max(1u, unchecked((uint)lParam.ToInt64()) & 0xffffu);
        private static uint ScanCode(IntPtr lParam) => (unchecked((uint)lParam.ToInt64()) >> 16) & 0xffu;
        private static bool IsExtended(IntPtr lParam) => (unchecked((uint)lParam.ToInt64()) & 0x01000000u) != 0;

        private static bool IsModifier(uint key) => key >= 0xA0 && key <= 0xA5;

        private static uint CanonicalModifier(uint key, uint scan, bool extended)
        {
            if (key == 0x10) return scan == 0x36 ? 0xA1u : 0xA0u;
            if (key == 0x11) return extended ? 0xA3u : 0xA2u;
            if (key == 0x12) return extended ? 0xA5u : 0xA4u;
            return key;
        }

        private static bool IsNativeKeyCandidate(uint key)
        {
            if (IsModifier(key)) return true;
            if (key == 0x08 || key == 0x09 || key == 0x0D || key == 0x13 || key == 0x0C) return true;
            if (key >= 0x21 && key <= 0x28) return true;
            if (key == 0x2D || key == 0x2E) return true;
            if (key >= 0x60 && key <= 0x6F) return true;
            if (key >= 0x70 && key <= 0x87) return true;
            if (key >= 0xAD && key <= 0xB3) return true;
            return false;
        }
    }
}
