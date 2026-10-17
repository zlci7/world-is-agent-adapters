using System;
using System.Collections.Generic;
using StardewValley;
using StardewValley.Quests;

namespace GameAgent.Stardew.Events;

public static class NativeInteraction
{
    public static bool ShouldPassThrough(NPC npc, Farmer player) =>
        (npc.Name == "Dwarf" && !player.canUnderstandDwarves) ||
        ShouldPassThrough(npc, player.ActiveObject is not null, player.questLog);

    internal static bool ShouldPassThrough(NPC npc, bool hasActiveObject, IEnumerable<Quest> quests)
    {
        // Preserve the game's offer/gift path, including rejected offers and insufficient quantities.
        if (hasActiveObject) return true;
        try
        {
            foreach (var quest in quests)
                if (!quest.completed.Value && !quest.destroy.Value && quest.OnNpcSocialized(npc, probe: true))
                    return true;
            return false;
        }
        catch
        {
            // A failed probe leaves the original game interaction in charge.
            return true;
        }
    }
}
