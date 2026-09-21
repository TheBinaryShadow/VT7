using Microsoft.Win32;
using System;
using System.Globalization;
using System.IO;
using System.Windows;
using System.Windows.Controls;

namespace VT7.Host
{
    internal sealed class SshConnectionDialog : Window
    {
        private readonly TextBox _host = new TextBox();
        private readonly TextBox _port = new TextBox { Text = "22" };
        private readonly TextBox _username = new TextBox();
        private readonly TextBox _fingerprint = new TextBox();
        private readonly ComboBox _authentication = new ComboBox();
        private readonly TextBox _keyPath = new TextBox();
        private readonly Button _browse = new Button { Content = "Browse...", Margin = new Thickness(6, 0, 0, 0) };
        private readonly TextBlock _secretLabel = new TextBlock();
        private readonly PasswordBox _secret = new PasswordBox();

        internal SshConnectionDialog()
        {
            Title = "Start SSH.NET session";
            Width = 590;
            Height = 490;
            MinWidth = 520;
            MinHeight = 440;
            WindowStartupLocation = WindowStartupLocation.CenterOwner;
            ResizeMode = ResizeMode.CanResize;
            Background = System.Windows.Media.Brushes.White;
            Foreground = System.Windows.Media.Brushes.Black;
            FontFamily = new System.Windows.Media.FontFamily("Segoe UI");

            _authentication.Items.Add("Private key");
            _authentication.Items.Add("Password");
            _authentication.SelectedIndex = 0;
            _authentication.SelectionChanged += (_, __) => RefreshAuthentication();
            _browse.Click += Browse_Click;
            _keyPath.Text = DefaultKeyPath();

            var root = new Grid { Margin = new Thickness(20) };
            root.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(170) });
            root.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
            for (var index = 0; index < 9; ++index)
                root.RowDefinitions.Add(new RowDefinition { Height = index == 7 ? new GridLength(1, GridUnitType.Star) : GridLength.Auto });

            AddField(root, 0, "Host", _host);
            AddField(root, 1, "Port", _port);
            AddField(root, 2, "Username", _username);
            AddField(root, 3, "Trusted SHA256 fingerprint", _fingerprint);
            AddField(root, 4, "Authentication", _authentication);

            var keyPanel = new Grid();
            keyPanel.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
            keyPanel.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
            Grid.SetColumn(_browse, 1);
            keyPanel.Children.Add(_keyPath);
            keyPanel.Children.Add(_browse);
            AddField(root, 5, "Private key", keyPanel);

            _secretLabel.VerticalAlignment = VerticalAlignment.Center;
            _secretLabel.Margin = new Thickness(0, 5, 12, 5);
            Grid.SetRow(_secretLabel, 6);
            root.Children.Add(_secretLabel);
            _secret.Margin = new Thickness(0, 5, 0, 5);
            Grid.SetRow(_secret, 6);
            Grid.SetColumn(_secret, 1);
            root.Children.Add(_secret);

            var note = new TextBlock
            {
                Text = "The fingerprint must come from a trusted path. VT7 will reject a different host key before authentication. Values and credentials are not written to diagnostics. This direct profile is the staged SSH.NET path; typed ssh remains disabled.",
                TextWrapping = TextWrapping.Wrap,
                Foreground = System.Windows.Media.Brushes.DimGray,
                Margin = new Thickness(0, 12, 0, 12),
            };
            Grid.SetRow(note, 7);
            Grid.SetColumnSpan(note, 2);
            root.Children.Add(note);

            var buttons = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Right };
            var cancel = new Button { Content = "Cancel", MinWidth = 88, IsCancel = true, Margin = new Thickness(0, 0, 8, 0) };
            var connect = new Button { Content = "Connect", MinWidth = 88, IsDefault = true };
            connect.Click += Connect_Click;
            buttons.Children.Add(cancel);
            buttons.Children.Add(connect);
            Grid.SetRow(buttons, 8);
            Grid.SetColumnSpan(buttons, 2);
            root.Children.Add(buttons);

            Content = root;
            RefreshAuthentication();
            Loaded += (_, __) => _host.Focus();
        }

        internal SshConnectionOptions? Result { get; private set; }

        private static void AddField(Grid root, int row, string label, FrameworkElement control)
        {
            var text = new TextBlock { Text = label, VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(0, 5, 12, 5) };
            Grid.SetRow(text, row);
            root.Children.Add(text);
            control.Margin = new Thickness(0, 5, 0, 5);
            Grid.SetRow(control, row);
            Grid.SetColumn(control, 1);
            root.Children.Add(control);
        }

        private void RefreshAuthentication()
        {
            var key = _authentication.SelectedIndex == 0;
            _keyPath.IsEnabled = key;
            _browse.IsEnabled = key;
            _secretLabel.Text = key ? "Key passphrase (optional)" : "Password";
            _secret.Password = string.Empty;
        }

        private void Browse_Click(object sender, RoutedEventArgs e)
        {
            var picker = new OpenFileDialog { Title = "Select SSH private key", CheckFileExists = true };
            if (!string.IsNullOrWhiteSpace(_keyPath.Text))
            {
                try { picker.InitialDirectory = Path.GetDirectoryName(Path.GetFullPath(_keyPath.Text)); }
                catch { }
            }
            if (picker.ShowDialog(this) == true) _keyPath.Text = picker.FileName;
        }

        private void Connect_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                if (!int.TryParse(_port.Text, NumberStyles.None, CultureInfo.InvariantCulture, out var port))
                    throw new FormatException("SSH port must be a number from 1 to 65535.");
                using (var secret = _secret.SecurePassword)
                {
                    Result = new SshConnectionOptions(_host.Text, port, _username.Text, _fingerprint.Text,
                        _authentication.SelectedIndex == 0 ? SshAuthenticationKind.PrivateKey : SshAuthenticationKind.Password,
                        _keyPath.Text, secret);
                }
                DialogResult = true;
            }
            catch (Exception error)
            {
                MessageBox.Show(this, error.Message, "Cannot start SSH session", MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }

        private static string DefaultKeyPath()
        {
            var root = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
            foreach (var name in new[] { "id_ed25519", "id_rsa" })
            {
                var path = Path.Combine(root, ".ssh", name);
                if (File.Exists(path)) return path;
            }
            return Path.Combine(root, ".ssh", "id_ed25519");
        }
    }
}
