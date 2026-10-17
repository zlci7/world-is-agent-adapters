using System;
using System.Collections.Generic;
using System.Linq;

namespace GameAgent.Stardew.State;

public static class ProgressFacts
{
    // IDs are selected from the shipped 1.6.15 Data/Events assets. Seen flags do not encode choices.
    public static readonly IReadOnlyDictionary<string, string[]> SelectedEvents = new Dictionary<string, string[]>(StringComparer.Ordinal)
    {
        ["Abigail"] = new[] { "1", "2", "4" }, ["Alex"] = new[] { "20", "2481135", "21" },
        ["Caroline"] = new[] { "17" }, ["Clint"] = new[] { "97", "101" },
        ["Demetrius"] = new[] { "25" }, ["Dwarf"] = new[] { "691039" },
        ["Elliott"] = new[] { "40", "43" }, ["Emily"] = new[] { "471942", "463391", "917409" },
        ["Evelyn"] = new[] { "19" }, ["George"] = new[] { "18" }, ["Gus"] = new[] { "96" },
        ["Haley"] = new[] { "11", "12", "13" }, ["Harvey"] = new[] { "56", "57", "58" },
        ["Jas"] = new[] { "3910979" }, ["Kent"] = new[] { "100" },
        ["Leah"] = new[] { "50", "51", "52" }, ["Leo"] = new[] { "6497423", "6497428", "8959199" },
        ["Lewis"] = new[] { "639373" }, ["Linus"] = new[] { "502969", "26", "371652" },
        ["Marnie"] = new[] { "639373" }, ["Maru"] = new[] { "6", "7", "8" },
        ["Penny"] = new[] { "34", "35", "36" }, ["Pierre"] = new[] { "16" },
        ["Robin"] = new[] { "33" }, ["Sam"] = new[] { "44", "733330", "46" },
        ["Sebastian"] = new[] { "2794460", "384883", "27" },
        ["Shane"] = new[] { "611944", "3910975", "831125" },
        ["Vincent"] = new[] { "3910979" }, ["Willy"] = new[] { "711130" },
    };

    public static string Facility(bool? available, bool? pending)
    {
        if (available == true) return "available";
        if (available is null || pending is null) return "unknown";
        return pending == true ? "pending" : "locked";
    }

    public static StardewNpcProgress Events(string npcName, Func<string, bool?> seen)
    {
        if (!SelectedEvents.TryGetValue(npcName, out string[]? ids))
            return new StardewNpcProgress(Array.Empty<StardewKeyEvent>());
        return new StardewNpcProgress(ids.Select(id => new StardewKeyEvent(id, seen(id) switch
        {
            true => "seen", false => "not_seen", _ => "unknown",
        })).ToArray());
    }
}
