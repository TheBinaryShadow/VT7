using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Windows;
using System.Windows.Input;
using System.Windows.Threading;

namespace VT7.InputFocusProbe
{
    public partial class MainWindow : Window
    {
        private const string CroatianExpected = "čćžšđ ČĆŽŠĐ";
        private const string AltGrExpected = "@\\|[]{}€";
        private readonly string _outputDirectory;
        private readonly bool _selfTest;
        private readonly JsonEventLog _log;
        private readonly NativeInputHost _nativeHost;
        private readonly Dictionary<string, int> _counts = new Dictionary<string, int>(StringComparer.Ordinal);
        private bool _completed;

        internal MainWindow(string outputDirectory, bool selfTest)
        {
            _outputDirectory = outputDirectory;
            _selfTest = selfTest;
            _log = new JsonEventLog(Path.Combine(outputDirectory, "input-events.jsonl"));
            InitializeComponent();
            _nativeHost = new NativeInputHost(_log, ObserveNative);
            NativeHostContainer.Content = _nativeHost;
            AddHandler(Keyboard.PreviewKeyDownEvent, new KeyEventHandler(PreviewKeyDownObserved), true);
            AddHandler(Keyboard.PreviewKeyUpEvent, new KeyEventHandler(PreviewKeyUpObserved), true);
            GotKeyboardFocus += FocusObserved;
            LostKeyboardFocus += FocusObserved;
            SizeChanged += SizeObserved;
            Closed += WindowClosed;
            Loaded += WindowLoaded;

            EnvironmentText.Text = "Active layout: " + LayoutDescription() + " | Culture: " + CultureInfo.CurrentCulture.Name +
                " | UI culture: " + CultureInfo.CurrentUICulture.Name + (_selfTest ? " | SELF TEST" : string.Empty);
            StatusText.Text = "Events are being recorded in " + outputDirectory;
            _log.Write("wpf", "startup", Pair("layout", LayoutName()), Pair("culture", CultureInfo.CurrentCulture.Name),
                Pair("uiCulture", CultureInfo.CurrentUICulture.Name), Pair("selfTest", _selfTest));
        }

        private void WindowLoaded(object sender, RoutedEventArgs e)
        {
            if (!_selfTest) return;
            WpfInput.Text = CroatianExpected + Environment.NewLine + AltGrExpected;
            Width += 48;
            Height -= 32;
            _nativeHost.FocusNative();
            _nativeHost.RunSyntheticSelfTest();
            WpfInput.Focus();
            Dispatcher.BeginInvoke(new Action(() => Complete(true)), DispatcherPriority.ApplicationIdle);
        }

        private void PreviewKeyDownObserved(object sender, KeyEventArgs e) => LogWpfKey("PreviewKeyDown", e);
        private void PreviewKeyUpObserved(object sender, KeyEventArgs e) => LogWpfKey("PreviewKeyUp", e);

        private void LogWpfKey(string name, KeyEventArgs e)
        {
            Increment("wpf." + name);
            var key = e.Key == Key.System ? e.SystemKey : e.Key;
            _log.Write("wpf", name, Pair("key", key.ToString()), Pair("virtualKey", KeyInterop.VirtualKeyFromKey(key)),
                Pair("systemKey", e.SystemKey.ToString()), Pair("modifiers", Keyboard.Modifiers.ToString()),
                Pair("repeat", e.IsRepeat), Pair("focusOwner", Keyboard.FocusedElement?.GetType().Name ?? string.Empty),
                Pair("handled", e.Handled));
        }

        private void WpfTextInput(object sender, TextCompositionEventArgs e)
        {
            Increment("wpf.PreviewTextInput");
            _log.Write("wpf", "PreviewTextInput", Pair("text", e.Text), Pair("systemText", e.SystemText),
                Pair("controlText", e.ControlText), Pair("focusOwner", Keyboard.FocusedElement?.GetType().Name ?? string.Empty),
                Pair("handled", e.Handled));
        }

        private void WpfTextChanged(object sender, System.Windows.Controls.TextChangedEventArgs e)
        {
            Increment("wpf.TextChanged");
            _log.Write("wpf", "TextChanged", Pair("length", WpfInput.Text.Length));
        }

        private void FocusObserved(object sender, KeyboardFocusChangedEventArgs e)
        {
            var name = e.RoutedEvent == GotKeyboardFocusEvent ? "GotKeyboardFocus" : "LostKeyboardFocus";
            Increment("wpf." + name);
            _log.Write("wpf", name, Pair("old", e.OldFocus?.GetType().Name ?? string.Empty),
                Pair("new", e.NewFocus?.GetType().Name ?? string.Empty));
        }

        private void SizeObserved(object sender, SizeChangedEventArgs e)
        {
            Increment("wpf.SizeChanged");
            _log.Write("wpf", "SizeChanged", Pair("width", (int)e.NewSize.Width), Pair("height", (int)e.NewSize.Height));
        }

        private void ObserveNative(string eventName)
        {
            Increment("native." + eventName);
            Dispatcher.BeginInvoke(new Action(() => StatusText.Text = "Recorded " + _log.Count + " events. Last native event: " + eventName));
        }

        private void FocusNativeClick(object sender, RoutedEventArgs e) => _nativeHost.FocusNative();
        private void FocusWpfClick(object sender, RoutedEventArgs e) => WpfInput.Focus();
        private void ResizeSmallerClick(object sender, RoutedEventArgs e) { Width = Math.Max(MinWidth, Width - 120); Height = Math.Max(MinHeight, Height - 80); }
        private void ResizeLargerClick(object sender, RoutedEventArgs e) { Width += 120; Height += 80; }
        private void CompleteClick(object sender, RoutedEventArgs e) => Complete(false);

        private void Complete(bool synthetic)
        {
            if (_completed) return;
            _completed = true;
            var nativeText = _nativeHost.ReadText();
            WriteSummary(true, synthetic, nativeText);
            _log.Write("wpf", "completed", Pair("synthetic", synthetic), Pair("eventCount", _log.Count));
            Close();
        }

        private void WindowClosed(object? sender, EventArgs e)
        {
            if (!_completed) WriteSummary(false, _selfTest, _nativeHost.ReadText());
            NativeHostContainer.Content = null;
            _nativeHost.Dispose();
            _log.Dispose();
        }

        private void WriteSummary(bool completed, bool synthetic, string nativeText)
        {
            var json = new StringBuilder(2048);
            json.Append("{\n");
            JsonEventLog.Property(json, "schema", "vt7-i01-focus-v1", false);
            JsonEventLog.Property(json, "completed", completed, true);
            JsonEventLog.Property(json, "selfTest", synthetic, true);
            JsonEventLog.Property(json, "layoutKlid", LayoutName(), true);
            JsonEventLog.Property(json, "layoutHandle", "0x" + unchecked((ulong)GetKeyboardLayout(0).ToInt64()).ToString("x"), true);
            JsonEventLog.Property(json, "culture", CultureInfo.CurrentCulture.Name, true);
            JsonEventLog.Property(json, "uiCulture", CultureInfo.CurrentUICulture.Name, true);
            JsonEventLog.Property(json, "eventCount", _log.Count, true);
            JsonEventLog.Property(json, "wpfText", WpfInput.Text, true);
            JsonEventLog.Property(json, "nativeText", nativeText, true);
            JsonEventLog.Property(json, "wpfContainsCroatian", WpfInput.Text.Contains(CroatianExpected), true);
            JsonEventLog.Property(json, "nativeContainsCroatian", nativeText.Contains(CroatianExpected), true);
            JsonEventLog.Property(json, "wpfContainsAltGr", WpfInput.Text.Contains(AltGrExpected), true);
            JsonEventLog.Property(json, "nativeContainsAltGr", nativeText.Contains(AltGrExpected), true);
            json.Append(",\"counts\":{");
            var first = true;
            foreach (var count in _counts)
            {
                JsonEventLog.Property(json, count.Key, count.Value, !first);
                first = false;
            }
            json.Append("}\n}\n");
            File.WriteAllText(Path.Combine(_outputDirectory, "focus-summary.json"), json.ToString(), new UTF8Encoding(false));
        }

        private void Increment(string name)
        {
            _counts.TryGetValue(name, out var count);
            _counts[name] = count + 1;
        }

        private static string LayoutDescription() => LayoutName() + " (HKL 0x" + unchecked((ulong)GetKeyboardLayout(0).ToInt64()).ToString("x") + ")";

        private static string LayoutName()
        {
            var name = new StringBuilder(9);
            return GetKeyboardLayoutNameW(name) ? name.ToString() : "unavailable";
        }

        private static KeyValuePair<string, object?> Pair(string name, object? value) =>
            new KeyValuePair<string, object?>(name, value);

        [DllImport("user32.dll")] private static extern IntPtr GetKeyboardLayout(uint threadId);
        [DllImport("user32.dll", CharSet = CharSet.Unicode)] private static extern bool GetKeyboardLayoutNameW(StringBuilder name);
    }
}
