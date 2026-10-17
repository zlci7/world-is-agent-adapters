using System;
using StardewValley;

namespace GameAgent.Stardew.State;

public static class ProgressReader
{
    public static string Relationship(Friendship? friendship)
    {
        if (friendship is null) return "unknown";
        if (friendship.IsRoommate()) return "roommate";
        return friendship.Status switch
        {
            FriendshipStatus.Friendly => "friendly", FriendshipStatus.Dating => "dating",
            FriendshipStatus.Engaged => "engaged", FriendshipStatus.Married => "married",
            FriendshipStatus.Divorced => "divorced", _ => "unknown",
        };
    }

    public static StardewWorldProgress World()
    {
        Farmer master = Game1.MasterPlayer;
        return new StardewWorldProgress(
            Flag(() => master.hasCompletedCommunityCenter(), "complete", "incomplete"),
            Flag(() => master.mailReceived.Contains("JojaMember"), "yes", "no"),
            Facility(master, "ccVault", "jojaVault"),
            Facility(master, "ccBoilerRoom", "jojaBoilerRoom"),
            ProgressFacts.Facility(Read(() => Game1.getFarm().greenhouseUnlocked.Value),
                Read(() => master.hasOrWillReceiveMail("ccPantry") || master.hasOrWillReceiveMail("jojaPantry"))));
    }

    public static StardewNpcProgress Npc(string npcName, Farmer player) =>
        ProgressFacts.Events(npcName, id => Read(() => player.eventsSeen.Contains(id))) with
        {
            LanguageUnderstood = npcName == "Dwarf" ? Read(() => player.canUnderstandDwarves) : null,
        };

    private static string Facility(Farmer master, string activeFlag, string purchaseFlag) =>
        ProgressFacts.Facility(Read(() => master.mailReceived.Contains(activeFlag)),
            Read(() => master.hasOrWillReceiveMail(activeFlag) || master.hasOrWillReceiveMail(purchaseFlag)));

    private static string Flag(Func<bool> read, string yes, string no) => Read(read) switch { true => yes, false => no, _ => "unknown" };
    private static bool? Read(Func<bool> read) { try { return read(); } catch { return null; } }
}
