using GameAgent.Stardew.Runtime;
using GameAgent.Stardew.State;
using GameAgent.Stardew.Tasks;
using GameAgent.Protocol.V1Alpha2;
using Google.Protobuf;
using Xunit;

namespace GameAgent.Stardew.Tests;

public sealed class ExperienceTests
{
    private static GiftReceipt Receipt(string id = "receipt") => new(id, "save", 42, "玩家", "Robin", "罗宾", "(O)258", "蓝莓", 0,
        1, 2, 7, 23, 50, GameClock.ToTick(1, 1, 7, 2350));

    [Fact]
    public void OfflineReceiptSurvivesSaveAndAckPreservesMembership()
    {
        var journal = GiftExperienceJournal.Restore(null, "save", 42);
        journal.Add(Receipt()); journal.Add(Receipt());
        Assert.Single(journal.Pending);
        var loaded = GiftExperienceJournal.Restore(journal.Serialize(), "save", 42);
        Assert.Equal(Receipt(), Assert.Single(loaded.Pending));
        Assert.True(loaded.Acknowledge("receipt"));
        Assert.False(loaded.Acknowledge("receipt"));
        var acknowledged = GiftExperienceJournal.Restore(loaded.Serialize(), "save", 42);
        Assert.Empty(acknowledged.Pending);
        Assert.Equal("receipt", Assert.Single(acknowledged.ValidIds["Robin"]));
    }

    [Theory]
    [InlineData(0, 0, false)]
    [InlineData(2, 2, false)]
    [InlineData(2, 3, true)]
    [InlineData(3, 2, false)]
    public void OnlyAnIncreasedNativeGiftLedgerCreatesExperience(int before, int after, bool accepted)
    {
        var journal = GiftExperienceJournal.Restore(null, "save", 42);
        Assert.Equal(accepted, journal.RecordAcceptedGift(Receipt(), before, after));
        Assert.Equal(accepted ? 1 : 0, journal.Pending.Count);
    }

    [Fact]
    public void LoadingEarlierSaveRemovesLaterBranchMembership()
    {
        var journal = GiftExperienceJournal.Restore(null, "save", 42);
        journal.Add(Receipt("first"));
        string saved = journal.Serialize();
        journal.Add(Receipt("later"));
        var restored = GiftExperienceJournal.Restore(saved, "save", 42);
        Assert.Equal(new[] { "first" }, restored.ValidIds["Robin"]);
        Assert.DoesNotContain(restored.Pending, receipt => receipt.Id == "later");
        Assert.Throws<InvalidDataException>(() => GiftExperienceJournal.Restore(saved, "other-save", 42));
        Assert.Throws<InvalidDataException>(() => GiftExperienceJournal.Restore(saved, "save", 43));
    }

    [Fact]
    public void MapperPreservesConfirmedFactClockAndSaveMembership()
    {
        GiftReceipt receipt = Receipt();
        GameEvent value = ProtocolMapper.BuildGiftExperience(receipt);
        value = GameEvent.Parser.ParseFrom(value.ToByteArray());
        Assert.Equal(receipt.Id, value.EventId);
        Assert.Equal("npc:Robin", value.TargetEntityId);
        Assert.Null(value.InteractionSource);
        Assert.Empty(value.TaskEvidence);
        var fact = Assert.Single(value.ContextFacts);
        Assert.Equal("interaction", fact.Kind);
        Assert.Equal("player:local", fact.ActorEntityId);
        Assert.Equal(value.TargetEntityId, fact.TargetEntityId);
        Assert.Contains("蓝莓", fact.Text);
        Assert.Equal(1, fact.Attributes.Fields["quantity"].NumberValue);
        Assert.Equal("accepted", fact.Attributes.Fields["outcome"].StringValue);
        var meta = value.Payload.Fields[RuntimeSessionState.ExperienceExtension].StructValue;
        Assert.Equal(GameClock.ClockId, meta.Fields["clock_id"].StringValue);
        Assert.Equal(receipt.Tick.ToString(), meta.Fields["occurred_tick"].StringValue);
        Assert.Equal((receipt.Tick + 3L * GameClock.MinutesPerDay).ToString(), meta.Fields["focus_until_tick"].StringValue);
        Assert.True(value.GameTime.HasDay);
        Assert.False(value.GameTime.HasTick); // process-local Game1.ticks is not a durable clock.
        var observation = new Observation();
        ProtocolMapper.AttachExperienceView(observation, receipt.Tick + 1440, new[] { receipt.Id });
        var view = observation.Extensions.Fields[RuntimeSessionState.ExperienceExtension].StructValue;
        Assert.Equal(receipt.Id, Assert.Single(view.Fields["valid_fact_ids"].ListValue.Values).StringValue);
        Assert.Equal(JsonParser.Default.Parse<GameEvent>(File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "fixtures", "experience-record.json"))), value);
        Assert.Equal(JsonParser.Default.Parse<Observation>(File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "fixtures", "experience-view.json"))), observation);
    }

    [Fact]
    public void NegotiationKeepsExperiencesOptionalAndResetsOnDisconnect()
    {
        var session = new RuntimeSessionState();
        session.BeginConnection();
        Assert.True(session.AcceptEnvironmentReady(Array.Empty<string>(), out _));
        Assert.False(session.ExperienceExtensionAccepted);
        session.Disconnect(); session.BeginConnection();
        Assert.True(session.AcceptEnvironmentReady(new[] { RuntimeSessionState.ExperienceExtension }, out _));
        Assert.True(session.ExperienceExtensionAccepted);
        Assert.False(session.TaskExtensionAccepted);
        session.Disconnect();
        Assert.False(session.ExperienceExtensionAccepted);
    }
}
