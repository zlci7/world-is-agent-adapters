using System.Text.Json;
using GameAgent.Stardew.State;
using Xunit;

namespace GameAgent.Stardew.Tests;

public sealed class ProgressFactsTests
{
    [Theory]
    [InlineData(false, false, "locked")]
    [InlineData(false, true, "pending")]
    [InlineData(true, true, "available")]
    [InlineData(true, null, "available")]
    [InlineData(null, true, "unknown")]
    [InlineData(false, null, "unknown")]
    public void FacilityDistinguishesEffectivePendingAndUnknown(bool? available, bool? pending, string expected) =>
        Assert.Equal(expected, ProgressFacts.Facility(available, pending));

    [Fact]
    public void EventsAreLimitedToTheCurrentNpcAndCurrentPlayerSnapshot()
    {
        var a = ProgressFacts.Events("Abigail", id => id == "1");
        var b = ProgressFacts.Events("Robin", _ => null);
        Assert.Equal(new[] { "1", "2", "4" }, a.KeyEvents.Select(e => e.EventId));
        Assert.Equal(new[] { "seen", "not_seen", "not_seen" }, a.KeyEvents.Select(e => e.Status));
        Assert.Equal("unknown", Assert.Single(b.KeyEvents).Status);
        Assert.All(ProgressFacts.SelectedEvents.Values, ids => Assert.InRange(ids.Length, 1, 3));
        Assert.Empty(ProgressFacts.Events("UnknownNpc", _ => throw new Exception()).KeyEvents);
        Assert.All(ProgressFacts.Events("Abigail", _ => false).KeyEvents, e => Assert.Equal("not_seen", e.Status));
    }

    [Theory]
    [InlineData("active", "unavailable")]
    [InlineData("ready_to_return", "unavailable")]
    [InlineData("completed", "completed")]
    public void DisappearanceNeverCreatesACompletion(string before, string after)
    {
        Assert.Equal(after, NativeObjectiveState.Missing(Objective(before)).Status);
    }

    [Fact]
    public void ReceiptRestoresOnlyWithinItsWorldAndPlayerAndFollowsTheSaveBranch()
    {
        var completed = Objective("completed");
        string json = JsonSerializer.Serialize(new NativeObjectiveSave("world-a", 42, completed));
        Assert.Equal(completed, NativeObjectiveState.Restore(json, "world-a", 42));
        Assert.Null(NativeObjectiveState.Restore(json, "world-b", 42));
        Assert.Null(NativeObjectiveState.Restore(json, "world-a", 43));
        Assert.Null(NativeObjectiveState.Restore(null, "world-a", 42));
        Assert.Null(NativeObjectiveState.Restore("{bad", "world-a", 42));
        string priorBranch = JsonSerializer.Serialize(new NativeObjectiveSave("world-a", 42, Objective("active")));
        Assert.Equal("active", NativeObjectiveState.Restore(priorBranch, "world-a", 42)!.Status);
        string invalid = JsonSerializer.Serialize(new NativeObjectiveSave("world-a", 42, completed with { Required = 0 }));
        Assert.Null(NativeObjectiveState.Restore(invalid, "world-a", 42));
    }

    private static StardewObjectiveContext Objective(string status) => new(
        "568f54a9de614a1186d11e2969af349f", "game_native", "fishing", "Willy", status, "(O)145", 3, 3, 1, "quest_giver");
}
