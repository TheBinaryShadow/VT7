using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.Cryptography;
using System.Threading;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;

namespace VT7.Host
{
    internal sealed class HostKeyProblemRequest
    {
        internal HostKeyProblemRequest(Guid requestId, string hostToken, PresentedHostKey presented,
            KnownHostTrustResult trust, KnownHostsStoreSnapshot snapshot)
        {
            RequestId = requestId;
            HostToken = hostToken ?? throw new ArgumentNullException(nameof(hostToken));
            Presented = presented ?? throw new ArgumentNullException(nameof(presented));
            Trust = trust ?? throw new ArgumentNullException(nameof(trust));
            Snapshot = snapshot ?? throw new ArgumentNullException(nameof(snapshot));
        }

        internal Guid RequestId { get; }
        internal string HostToken { get; }
        internal PresentedHostKey Presented { get; }
        internal KnownHostTrustResult Trust { get; }
        internal KnownHostsStoreSnapshot Snapshot { get; }
    }

    internal delegate Task HostKeyProblemHandler(HostKeyProblemRequest request,
        CancellationToken cancellationToken);

    internal sealed class KnownHostsManagementDialog : Window
    {
        private readonly HostKeyProblemRequest _request;
        private readonly List<(int LineNumber, CheckBox CheckBox)> _choices =
            new List<(int LineNumber, CheckBox CheckBox)>();
        private readonly TextBlock _status;

        internal KnownHostsManagementDialog(HostKeyProblemRequest request)
        {
            _request = request ?? throw new ArgumentNullException(nameof(request));
            Title = "Changed SSH host key";
            Width = 720;
            Height = 520;
            MinWidth = 600;
            MinHeight = 430;
            WindowStartupLocation = WindowStartupLocation.CenterOwner;
            Background = Brushes.White;
            Foreground = Brushes.Black;
            FontFamily = new FontFamily("Segoe UI");
            var root = new Grid { Margin = new Thickness(18) };
            root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
            root.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
            root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
            root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });

            var heading = new StackPanel();
            heading.Children.Add(new TextBlock
            {
                Text = "The server presented a different SSH host key.",
                FontSize = 17,
                FontWeight = FontWeights.SemiBold,
                Foreground = Brushes.Black,
                Margin = new Thickness(0, 0, 0, 8),
            });
            heading.Children.Add(new TextBlock
            {
                Text = "The connection stopped before authentication. Verify the new fingerprint through a separate trusted source before removing any old record.",
                TextWrapping = TextWrapping.Wrap,
                Foreground = Brushes.Black,
            });
            heading.Children.Add(new TextBlock
            {
                Text = request.HostToken + "   " + request.Presented.KeyType + "   " + request.Presented.Fingerprint,
                TextWrapping = TextWrapping.Wrap,
                Foreground = Brushes.Black,
                Margin = new Thickness(0, 10, 0, 8),
            });
            root.Children.Add(heading);

            var records = new StackPanel();
            var primary = request.Snapshot.Sources[0];
            records.Children.Add(new TextBlock
            {
                Text = "User file: " + primary.Definition.Path,
                TextWrapping = TextWrapping.Wrap,
                Foreground = Brushes.Black,
                FontWeight = FontWeights.SemiBold,
                Margin = new Thickness(0, 0, 0, 8),
            });
            if (primary.Document != null && primary.Document.FatalError == null)
            {
                foreach (var line in primary.Document.Lines)
                {
                    var record = line.Record;
                    if (record == null || record.Marker != KnownHostMarker.None ||
                        !OpenSshHostMatcher.Matches(request.HostToken, record.HostField)) continue;
                    using var sha = SHA256.Create();
                    var fingerprint = "SHA256:" + Convert.ToBase64String(sha.ComputeHash(record.KeyBlob)).TrimEnd('=');
                    var choice = new CheckBox
                    {
                        Content = "Line " + line.LineNumber + "   " + record.HostField + "   " +
                            record.KeyType + "   " + fingerprint,
                        Foreground = Brushes.Black,
                        Margin = new Thickness(0, 5, 0, 5),
                    };
                    _choices.Add((line.LineNumber, choice));
                    records.Children.Add(choice);
                }
            }
            if (_choices.Count == 0)
                records.Children.Add(new TextBlock
                {
                    Text = "No matching ordinary key in the primary user file can be removed here. Review the source locations below and manage other files outside VT7.",
                    TextWrapping = TextWrapping.Wrap,
                    Foreground = Brushes.Black,
                });
            records.Children.Add(new TextBlock
            {
                Text = "Relevant sources: " + string.Join(", ", request.Trust.Locations),
                TextWrapping = TextWrapping.Wrap,
                Foreground = Brushes.Black,
                Margin = new Thickness(0, 14, 0, 0),
            });
            var scroll = new ScrollViewer { Content = records, VerticalScrollBarVisibility = ScrollBarVisibility.Auto };
            Grid.SetRow(scroll, 1);
            root.Children.Add(scroll);

            _status = new TextBlock
            {
                Text = "Removal saves the exact prior file as known_hosts.old. A new connection and trust decision are required afterward.",
                TextWrapping = TextWrapping.Wrap,
                Foreground = Brushes.Black,
                Margin = new Thickness(0, 12, 0, 0),
            };
            Grid.SetRow(_status, 2);
            root.Children.Add(_status);

            var buttons = new StackPanel
            {
                Orientation = Orientation.Horizontal,
                HorizontalAlignment = HorizontalAlignment.Right,
                Margin = new Thickness(0, 18, 0, 0),
            };
            var cancel = new Button { Content = "_Cancel", MinWidth = 90, IsCancel = true };
            var remove = new Button
            {
                Content = "_Remove selected records", MinWidth = 170,
                IsEnabled = _choices.Count > 0, Margin = new Thickness(8, 0, 0, 0),
            };
            cancel.Click += (_, __) => Close();
            remove.Click += (_, __) => RemoveSelected();
            buttons.Children.Add(cancel);
            buttons.Children.Add(remove);
            Grid.SetRow(buttons, 3);
            root.Children.Add(buttons);
            Content = root;
            Loaded += (_, __) => cancel.Focus();
        }

        internal FrameworkElement FormContent => (FrameworkElement)Content;

        private void RemoveSelected()
        {
            var lines = _choices.Where(choice => choice.CheckBox.IsChecked == true)
                .Select(choice => choice.LineNumber).ToArray();
            if (lines.Length == 0)
            {
                _status.Text = "Select at least one user record.";
                return;
            }
            var answer = MessageBox.Show(this,
                "Remove " + lines.Length + " selected record(s) from your primary OpenSSH known_hosts file? The original will be saved as known_hosts.old. Verify the new host key separately before reconnecting.",
                "Confirm known-host removal", MessageBoxButton.YesNo, MessageBoxImage.Warning,
                MessageBoxResult.No);
            if (answer != MessageBoxResult.Yes) return;
            try
            {
                OpenSshKnownHostsWriter.RemovePrimaryUserRecords(_request.Snapshot,
                    _request.HostToken, lines);
                _status.Text = "Selected records removed. Reconnect to make a fresh host-key decision.";
                DialogResult = true;
            }
            catch (KnownHostsMutationException error)
            {
                _status.Text = "Removal stopped during " + error.Category +
                    ". Reload and review the known-host file before trying again.";
            }
        }
    }
}
