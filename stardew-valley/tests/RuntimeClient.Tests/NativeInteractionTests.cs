using GameAgent.Stardew.Events;
using GameAgent.Stardew.State;
using StardewValley;
using StardewValley.Quests;
using Xunit;

namespace GameAgent.Stardew.Tests;

public sealed class NativeInteractionTests
{
    [Fact]
    public void NativeFishingProbePassesReadyQuestWithoutCompletingIt()
    {
        var npc = new NPC { Name = "Willy" };
        var quest = new FishingQuest();
        quest.target.Value = "Willy";
        quest.numberToFish.Value = 3;
        quest.numberFished.Value = 2;
        Assert.False(NativeInteraction.ShouldPassThrough(npc, false, new[] { quest }));
        quest.numberFished.Value = 3;
        Assert.True(NativeInteraction.ShouldPassThrough(npc, false, new[] { quest }));
        Assert.False(quest.completed.Value);
        Assert.Equal(3, quest.numberFished.Value);
        quest.completed.Value = true;
        Assert.False(NativeInteraction.ShouldPassThrough(npc, false, new[] { quest }));
        Assert.True(NativeInteraction.ShouldPassThrough(npc, true, Array.Empty<Quest>()));
    }

    [Theory]
    [InlineData(FriendshipStatus.Friendly, "friendly")]
    [InlineData(FriendshipStatus.Dating, "dating")]
    [InlineData(FriendshipStatus.Engaged, "engaged")]
    [InlineData(FriendshipStatus.Married, "married")]
    [InlineData(FriendshipStatus.Divorced, "divorced")]
    public void RelationshipUsesTheNativeStatus(FriendshipStatus status, string expected)
    {
        var friendship = new Friendship { Status = status };
        Assert.Equal(expected, ProgressReader.Relationship(friendship));
        Assert.Equal("unknown", ProgressReader.Relationship(null));
    }

    [Fact]
    public void NativeDeliveryProbeMatchesTargetItemAndQuantityWithoutConsuming()
    {
        var npc = new NPC { Name = "Willy" };
        var quest = new ItemDeliveryQuest();
        quest.target.Value = "Willy";
        quest.ItemId.Value = "(O)145";
        quest.number.Value = 3;
        var item = new StardewValley.Object { ItemId = "145", Stack = 2 };
        Assert.False(quest.OnItemOfferedToNpc(npc, item, probe: true));
        item.Stack = 3;
        Assert.True(quest.OnItemOfferedToNpc(npc, item, probe: true));
        Assert.Equal(3, item.Stack);
        Assert.False(quest.completed.Value);
        npc.Name = "Robin";
        Assert.False(quest.OnItemOfferedToNpc(npc, item, probe: true));
    }

    [Fact]
    public void NativeRoommateRelationshipRemainsDistinctFromMarriage()
    {
        var friendship = new Friendship { Status = FriendshipStatus.Married, RoommateMarriage = true };
        Assert.True(friendship.IsMarried());
        Assert.True(friendship.IsRoommate());
        Assert.Equal("roommate", ProgressReader.Relationship(friendship));
    }

    [Fact]
    public void NativeFishingMetadataSurrogateRoundTripsWithoutGamePresentation()
    {
        var quest = new FishingQuest();
        quest.modData[NativeObjectiveTracker.InstanceKey] = "568f54a9de614a1186d11e2969af349f";
        quest.target.Value = "Willy";
        quest.ItemId.Value = "(O)145";
        quest.numberToFish.Value = 3;
        // Presentation getters require the running game's item registry; metadata uses the native XML surrogate.
        var overrides = new System.Xml.Serialization.XmlAttributeOverrides();
        foreach (string property in new[] { "questTitle", "questDescription", "currentObjective" })
            overrides.Add(typeof(Quest), property, new System.Xml.Serialization.XmlAttributes { XmlIgnore = true });
        var serializer = new System.Xml.Serialization.XmlSerializer(typeof(FishingQuest), overrides);
        using var writer = new StringWriter();
        serializer.Serialize(writer, quest);
        using var reader = new StringReader(writer.ToString());
        var restored = Assert.IsType<FishingQuest>(serializer.Deserialize(reader));
        Assert.Equal(quest.modData[NativeObjectiveTracker.InstanceKey], restored.modData[NativeObjectiveTracker.InstanceKey]);
        Assert.Equal("Willy", restored.target.Value);
    }
}
