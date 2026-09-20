using System;
using System.Threading;
using System.Threading.Tasks;

namespace GameAgent.Stardew.Runtime;

internal sealed class ReconnectScheduler : IDisposable
{
    private static readonly TimeSpan RetryDelay = TimeSpan.FromSeconds(1);

    private readonly object gate = new();
    private readonly Func<TimeSpan, CancellationToken, Task> delay;
    private CancellationTokenSource pendingCancellation = new();
    private Task? pending;
    private long epoch;
    private bool disposed;

    internal ReconnectScheduler(Func<TimeSpan, CancellationToken, Task>? delay = null)
    {
        this.delay = delay ?? Task.Delay;
    }

    internal long CurrentEpoch
    {
        get { lock (this.gate) return this.epoch; }
    }

    internal bool HasPendingRetry
    {
        get { lock (this.gate) return this.pending is { IsCompleted: false }; }
    }

    internal Task ScheduleAsync(long expectedEpoch, Action retry)
    {
        ArgumentNullException.ThrowIfNull(retry);
        lock (this.gate)
        {
            if (this.disposed || expectedEpoch != this.epoch)
                return Task.CompletedTask;
            if (this.pending is { IsCompleted: false })
                return this.pending;

            CancellationToken token = this.pendingCancellation.Token;
            this.pending = this.RunAsync(expectedEpoch, retry, token);
            return this.pending;
        }
    }

    internal long Invalidate()
    {
        lock (this.gate)
        {
            this.epoch++;
            this.pendingCancellation.Cancel();
            this.pendingCancellation.Dispose();
            this.pendingCancellation = new CancellationTokenSource();
            this.pending = null;
            return this.epoch;
        }
    }

    public void Dispose()
    {
        lock (this.gate)
        {
            if (this.disposed)
                return;
            this.disposed = true;
            this.epoch++;
            this.pendingCancellation.Cancel();
            this.pendingCancellation.Dispose();
            this.pending = null;
        }
    }

    private async Task RunAsync(long expectedEpoch, Action retry, CancellationToken token)
    {
        try
        {
            await this.delay(RetryDelay, token);
        }
        catch (OperationCanceledException) when (token.IsCancellationRequested)
        {
            return;
        }

        lock (this.gate)
        {
            if (this.disposed || token.IsCancellationRequested || expectedEpoch != this.epoch)
                return;
            this.pending = null;
        }
        retry();
    }
}
