using System;
using System.IO;
using System.Windows;

namespace VT7.InputFocusProbe
{
    public partial class App : Application
    {
        protected override void OnStartup(StartupEventArgs e)
        {
            base.OnStartup(e);
            string? outputDirectory = null;
            var selfTest = false;
            for (var index = 0; index < e.Args.Length; index++)
            {
                if (string.Equals(e.Args[index], "--output", StringComparison.OrdinalIgnoreCase) && index + 1 < e.Args.Length)
                    outputDirectory = e.Args[++index];
                else if (string.Equals(e.Args[index], "--self-test", StringComparison.OrdinalIgnoreCase))
                    selfTest = true;
            }
            if (string.IsNullOrWhiteSpace(outputDirectory))
            {
                MessageBox.Show("Usage: VT7.InputFocusProbe.exe --output <directory> [--self-test]", "VT7 I01", MessageBoxButton.OK, MessageBoxImage.Error);
                Shutdown(2);
                return;
            }

            outputDirectory = Path.GetFullPath(outputDirectory);
            Directory.CreateDirectory(outputDirectory);
            try
            {
                var window = new MainWindow(outputDirectory, selfTest);
                MainWindow = window;
                window.Show();
            }
            catch (Exception error)
            {
                File.WriteAllText(Path.Combine(outputDirectory, "focus-probe-error.txt"), error.ToString());
                MessageBox.Show(error.ToString(), "VT7 I01 startup failed", MessageBoxButton.OK, MessageBoxImage.Error);
                Shutdown(1);
            }
        }
    }
}
