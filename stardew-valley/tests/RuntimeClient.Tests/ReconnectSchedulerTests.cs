using GameAgent.Stardew.Runtime;
using Xunit;

namespace GameAgent.Stardew.Tests;

public sealed class ReconnectSchedulerTests
{
    [Fact]
    public async Task DisconnectedAttemptSchedulesOneDelayedRetry()
    {
        var delay = new ControlledDelay();
        using var scheduler = new ReconnectScheduler(delay.WaitAsync);
        long epoch = scheduler.CurrentEpoch;
        int retries = 0;

        Task first = scheduler.ScheduleAsync(epoch, () => retries++);
        Task duplicate = scheduler.ScheduleAsync(epoch, () => retries++);
        Assert.Same(first, duplicate);
        Assert.Equal(0, retries);

        delay.Release();
        await first;
        Assert.Equal(1, retries);
    }

    [Fact]
    public async Task ManualReconnectCancelsThePendingAutomaticRetry()
    {
        var delay = new ControlledDelay();
        using var scheduler = new ReconnectScheduler(delay.WaitAsync);
        int retries = 0;
        Task pending = scheduler.ScheduleAsync(scheduler.CurrentEpoch, () => retries++);

        scheduler.Invalidate();
        delay.Release();
        await pending;

        Assert.Equal(0, retries);
    }

    [Fact]
    public async Task DisposalCancelsThePendingAutomaticRetry()
    {
        var delay = new ControlledDelay();
        var scheduler = new ReconnectScheduler(delay.WaitAsync);
        int retries = 0;
        Task pending = scheduler.ScheduleAsync(scheduler.CurrentEpoch, () => retries++);

        scheduler.Dispose();
        delay.Release();
        await pending;

        Assert.Equal(0, retries);
    }

    [Fact]
    public async Task OldCallbackCannotStartAfterANewerEpoch()
    {
        var delay = new IgnoringCancellationDelay();
        using var scheduler = new ReconnectScheduler(delay.WaitAsync);
        int retries = 0;
        Task stale = scheduler.ScheduleAsync(scheduler.CurrentEpoch, () => retries++);

        scheduler.Invalidate();
        delay.Release();
        await stale;

        Assert.Equal(0, retries);
    }

    [Fact]
    public async Task RepeatedRejectionsRemainSerialAcrossAttempts()
    {
        var delay = new QueueDelay();
        using var scheduler = new ReconnectScheduler(delay.WaitAsync);
        int retries = 0;

        Task first = scheduler.ScheduleAsync(scheduler.CurrentEpoch, () => retries++);
        delay.ReleaseNext();
        await first;
        Task second = scheduler.ScheduleAsync(scheduler.CurrentEpoch, () => retries++);
        delay.ReleaseNext();
        await second;

        Assert.Equal(2, retries);
        Assert.Equal(1, delay.MaximumConcurrentWaits);
    }

    private sealed class ControlledDelay
    {
        private readonly TaskCompletionSource released = new(TaskCreationOptions.RunContinuationsAsynchronously);
        public Task WaitAsync(TimeSpan _, CancellationToken token) => this.released.Task.WaitAsync(token);
        public void Release() => this.released.TrySetResult();
    }

    private sealed class IgnoringCancellationDelay
    {
        private readonly TaskCompletionSource released = new(TaskCreationOptions.RunContinuationsAsynchronously);
        public Task WaitAsync(TimeSpan _, CancellationToken __) => this.released.Task;
        public void Release() => this.released.TrySetResult();
    }

    private sealed class QueueDelay
    {
        private readonly Queue<TaskCompletionSource> waits = new();
        private int active;
        public int MaximumConcurrentWaits { get; private set; }

        public async Task WaitAsync(TimeSpan _, CancellationToken token)
        {
            var released = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
            this.waits.Enqueue(released);
            this.MaximumConcurrentWaits = Math.Max(this.MaximumConcurrentWaits, ++this.active);
            try { await released.Task.WaitAsync(token); }
            finally { this.active--; }
        }

        public void ReleaseNext() => this.waits.Dequeue().TrySetResult();
    }
}
