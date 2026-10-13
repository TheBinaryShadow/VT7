using System;
using System.Diagnostics;
using System.Threading;
using System.Threading.Tasks;

namespace VT7.Host
{
    internal enum SshStartupPhase
    {
        Resolution, KnownHosts, Credentials, Identification, KeyExchange, Authentication, Pty, TrustUpdate
    }

    // An owned watchdog, not an abandoned operation raced against Task.Delay.
    // Expiry cancels token-aware work; synchronous library/OS work is joined and
    // checked before the next phase or Running can be published.
    internal sealed class SshStartupDeadline
    {
        private readonly object _gate = new object();
        private readonly TimeSpan _budget;
        private readonly CancellationTokenSource _operation;
        private readonly CancellationToken _token;
        private readonly CancellationTokenSource _stop = new CancellationTokenSource();
        private readonly Stopwatch _clock = Stopwatch.StartNew();
        private TaskCompletionSource<bool> _changed = NewSignal();
        private readonly Task _watchdog;
        private SshStartupPhase? _phase;
        private TimeSpan _entered;
        private string? _expired;
        private bool _stopped;

        internal SshStartupDeadline(TimeSpan budget, CancellationToken cancellationToken)
        {
            if (budget <= TimeSpan.Zero || budget > TimeSpan.FromSeconds(15))
                throw new ArgumentOutOfRangeException(nameof(budget));
            _budget = budget;
            _operation = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
            _token = _operation.Token;
            _watchdog = Task.Run(WatchAsync);
        }

        // A callback can retain this watchdog across Running publication. A
        // cached token remains readable after the owned source is disposed.
        internal CancellationToken Token => _token;
        internal string? ExpiredCategory { get { lock (_gate) { ObserveExpiry(); return _expired; } } }
        internal string CurrentCategory { get { lock (_gate) return _phase.HasValue ? Name(_phase.Value) : "SSH startup"; } }

        internal void Enter(SshStartupPhase phase)
        {
            Check();
            if (!TryEnter(phase)) Check();
        }

        // Event callbacks must fail closed, without throwing through SSH.NET's
        // message listener. A trusted key may advance only a live startup.
        internal bool TryEnter(SshStartupPhase phase)
        {
            lock (_gate)
            {
                ObserveExpiry();
                if (_stopped || _expired != null || _operation.IsCancellationRequested) return false;
                // Rekey callbacks must not extend the authentication budget.
                if (_phase == phase) return true;
                _phase = phase;
                _entered = _clock.Elapsed;
                SignalChange();
                return true;
            }
        }

        internal bool TryAdvance(SshStartupPhase expected, SshStartupPhase next)
        {
            lock (_gate)
            {
                if (_phase != expected) return false;
                return TryEnter(next);
            }
        }

        internal void Pause()
        {
            Check();
            lock (_gate)
            {
                ObserveExpiry();
                if (_expired != null) throw new SshTransportException(_expired);
                _phase = null;
                SignalChange();
            }
        }

        internal void Check()
        {
            var expired = ExpiredCategory;
            if (expired != null) throw new SshTransportException(expired);
            Token.ThrowIfCancellationRequested();
        }

        internal async Task StopAsync()
        {
            lock (_gate) { _stopped = true; SignalChange(); }
            _stop.Cancel();
            await _watchdog.ConfigureAwait(false);
            _operation.Dispose();
            _stop.Dispose();
        }

        private async Task WatchAsync()
        {
            try
            {
                while (true)
                {
                    Task changed;
                    TimeSpan remaining;
                    lock (_gate)
                    {
                        if (_stopped) return;
                        ObserveExpiry();
                        if (_expired != null) break;
                        changed = _changed.Task;
                        remaining = _phase.HasValue ? _budget - (_clock.Elapsed - _entered) : Timeout.InfiniteTimeSpan;
                    }
                    using var wait = CancellationTokenSource.CreateLinkedTokenSource(_stop.Token);
                    var delay = Task.Delay(remaining > TimeSpan.Zero || remaining == Timeout.InfiniteTimeSpan ?
                        remaining : TimeSpan.Zero, wait.Token);
                    await Task.WhenAny(changed, delay).ConfigureAwait(false);
                    wait.Cancel();
                    _stop.Token.ThrowIfCancellationRequested();
                }
                _operation.Cancel();
            }
            catch (OperationCanceledException) when (_stop.IsCancellationRequested) { }
        }

        private void ObserveExpiry()
        {
            if (!_stopped && _expired == null && _phase.HasValue && _clock.Elapsed - _entered >= _budget)
                _expired = Name(_phase.Value) + " timeout";
        }

        private void SignalChange()
        {
            var previous = _changed;
            _changed = NewSignal();
            previous.TrySetResult(true);
        }

        private static TaskCompletionSource<bool> NewSignal() =>
            new TaskCompletionSource<bool>(TaskCreationOptions.RunContinuationsAsynchronously);

        internal static string Name(SshStartupPhase phase) => phase switch
        {
            SshStartupPhase.Resolution => "address-family resolution",
            SshStartupPhase.KnownHosts => "known-host store loading",
            SshStartupPhase.Credentials => "authentication setup",
            SshStartupPhase.Identification => "DNS, TCP or SSH identification",
            SshStartupPhase.KeyExchange => "SSH key exchange and host-key verification",
            SshStartupPhase.Authentication => "SSH authentication",
            SshStartupPhase.Pty => "remote PTY allocation",
            SshStartupPhase.TrustUpdate => "known-host durable addition",
            _ => throw new ArgumentOutOfRangeException(nameof(phase))
        };
    }
}
