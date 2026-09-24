using System;
using System.IO;
using System.Threading;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;

namespace VT7.Host
{
    internal enum HostTrustPromptAction
    {
        Cancel,
        ConnectOnce,
        TrustAndConnect,
    }

    internal sealed class HostTrustPromptRequest
    {
        internal HostTrustPromptRequest(Guid requestId, Guid transportId, Guid sessionId,
            long transportGeneration, long connectionGeneration, long promptGeneration,
            string hostToken, string username, PresentedHostKey presented,
            bool fingerprintSupplied, bool fingerprintMatched, string storeIdentity,
            string primaryUserPath)
        {
            RequestId = requestId;
            TransportId = transportId;
            SessionId = sessionId;
            TransportGeneration = transportGeneration;
            ConnectionGeneration = connectionGeneration;
            PromptGeneration = promptGeneration;
            HostToken = hostToken ?? throw new ArgumentNullException(nameof(hostToken));
            Username = username ?? throw new ArgumentNullException(nameof(username));
            Presented = presented ?? throw new ArgumentNullException(nameof(presented));
            FingerprintSupplied = fingerprintSupplied;
            FingerprintMatched = fingerprintMatched;
            StoreIdentity = storeIdentity ?? throw new ArgumentNullException(nameof(storeIdentity));
            PrimaryUserPath = Path.GetFullPath(primaryUserPath ?? throw new ArgumentNullException(nameof(primaryUserPath)));
        }

        internal Guid RequestId { get; }
        internal Guid TransportId { get; }
        internal Guid SessionId { get; }
        internal long TransportGeneration { get; }
        internal long ConnectionGeneration { get; }
        internal long PromptGeneration { get; }
        internal string HostToken { get; }
        internal string Username { get; }
        internal PresentedHostKey Presented { get; }
        internal bool FingerprintSupplied { get; }
        internal bool FingerprintMatched { get; }
        internal string StoreIdentity { get; }
        internal string PrimaryUserPath { get; }
    }

    internal sealed class HostTrustPromptResponse
    {
        internal HostTrustPromptResponse(Guid requestId, HostTrustPromptAction action)
        {
            RequestId = requestId;
            Action = action;
        }

        internal Guid RequestId { get; }
        internal HostTrustPromptAction Action { get; }
    }

    internal delegate Task<HostTrustPromptResponse> HostTrustPromptHandler(
        HostTrustPromptRequest request, CancellationToken cancellationToken);

    internal sealed class HostTrustDialog : Window
    {
        private readonly HostTrustPromptRequest _request;

        internal HostTrustDialog(HostTrustPromptRequest request)
        {
            _request = request ?? throw new ArgumentNullException(nameof(request));
            Title = "Verify SSH host";
            Width = 660;
            Height = 500;
            MinWidth = 580;
            MinHeight = 440;
            WindowStartupLocation = WindowStartupLocation.CenterOwner;
            ResizeMode = ResizeMode.CanResize;
            Background = Brushes.White;
            Foreground = Brushes.Black;
            FontFamily = new FontFamily("Segoe UI");

            var textStyle = new Style(typeof(TextBlock));
            textStyle.Setters.Add(new Setter(TextBlock.ForegroundProperty, Brushes.Black));
            Resources.Add(typeof(TextBlock), textStyle);

            var root = new Grid { Margin = new Thickness(20) };
            root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
            root.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
            root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });

            var heading = new TextBlock
            {
                Text = "The host is not in your OpenSSH known-host files.",
                FontSize = 17,
                FontWeight = FontWeights.SemiBold,
                Margin = new Thickness(0, 0, 0, 14),
            };
            root.Children.Add(heading);

            var details = new StackPanel();
            AddDetail(details, "Host", request.HostToken);
            AddDetail(details, "Username", request.Username);
            AddDetail(details, "Key type", request.Presented.KeyType);
            AddDetail(details, "SHA256 fingerprint", request.Presented.Fingerprint);
            AddDetail(details, "Out-of-band fingerprint", request.FingerprintSupplied
                ? (request.FingerprintMatched ? "Supplied and matched" : "Supplied but did not match")
                : "Not supplied");
            AddDetail(details, "Trust file", request.PrimaryUserPath);
            details.Children.Add(new TextBlock
            {
                Text = "Compare the fingerprint with a separate trusted source. Connect once trusts only this key for the fresh retry. Trust and connect appends this key to the user file, verifies the saved record, and then starts a fresh connection.",
                TextWrapping = TextWrapping.Wrap,
                Foreground = Brushes.DimGray,
                Margin = new Thickness(0, 18, 0, 0),
            });
            Grid.SetRow(details, 1);
            root.Children.Add(details);

            var buttons = new StackPanel
            {
                Orientation = Orientation.Horizontal,
                HorizontalAlignment = HorizontalAlignment.Right,
                Margin = new Thickness(0, 18, 0, 0),
            };
            var cancel = new Button { Content = "_Cancel", MinWidth = 88, IsCancel = true };
            var once = new Button { Content = "Connect _once", MinWidth = 112, Margin = new Thickness(8, 0, 0, 0) };
            var trust = new Button { Content = "_Trust and connect", MinWidth = 138, Margin = new Thickness(8, 0, 0, 0), IsDefault = true };
            cancel.Click += (_, __) => Complete(HostTrustPromptAction.Cancel);
            once.Click += (_, __) => Complete(HostTrustPromptAction.ConnectOnce);
            trust.Click += (_, __) => Complete(HostTrustPromptAction.TrustAndConnect);
            buttons.Children.Add(cancel);
            buttons.Children.Add(once);
            buttons.Children.Add(trust);
            Grid.SetRow(buttons, 2);
            root.Children.Add(buttons);

            Content = root;
            Loaded += (_, __) => cancel.Focus();
        }

        internal HostTrustPromptResponse Result { get; private set; } =
            new HostTrustPromptResponse(Guid.Empty, HostTrustPromptAction.Cancel);
        internal FrameworkElement FormContent => (FrameworkElement)Content;

        private static void AddDetail(Panel panel, string label, string value)
        {
            panel.Children.Add(new TextBlock { Text = label, FontWeight = FontWeights.SemiBold, Margin = new Thickness(0, 5, 0, 1) });
            panel.Children.Add(new TextBox
            {
                Text = value,
                IsReadOnly = true,
                BorderThickness = new Thickness(0),
                Background = Brushes.White,
                Foreground = Brushes.Black,
                Padding = new Thickness(0),
            });
        }

        private void Complete(HostTrustPromptAction action)
        {
            Result = new HostTrustPromptResponse(_request.RequestId, action);
            DialogResult = action != HostTrustPromptAction.Cancel;
        }
    }
}
