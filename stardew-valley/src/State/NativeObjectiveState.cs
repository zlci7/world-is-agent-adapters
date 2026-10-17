using System;
using System.Text.Json;

namespace GameAgent.Stardew.State;

public sealed record NativeObjectiveSave(string WorldId, long PlayerId, StardewObjectiveContext Objective);

public static class NativeObjectiveState
{
    public static StardewObjectiveContext? Restore(string? json, string worldId, long playerId)
    {
        if (string.IsNullOrEmpty(json) || json.Length > 4096) return null;
        try
        {
            NativeObjectiveSave? save = JsonSerializer.Deserialize<NativeObjectiveSave>(json);
            if (save is null || save.WorldId != worldId || save.PlayerId != playerId || save.Objective is not { } value)
                return null;
            if (!Guid.TryParseExact(value.InstanceRef, "N", out _) || value.Source != "game_native" ||
                value.Kind != "fishing" || value.NpcName != "Willy" || value.ItemId is null || value.ItemId.Length > 80 ||
                value.Required < 1 || value.Required > 9999 || value.Caught < 0 || value.Caught > 9999 ||
                value.DaysLeft < 0 || value.DaysLeft > 9999 ||
                value.ItemName?.Length > 64 || value.Seasons?.Length > 64 || value.TimeWindows?.Length > 80 || value.Weather?.Length > 32 ||
                value.KnowledgeBasis != "quest_giver" || value.Status is not ("active" or "ready_to_return" or "completed" or "unavailable"))
                return null;
            return value;
        }
        catch (JsonException) { return null; }
    }

    public static StardewObjectiveContext Missing(StardewObjectiveContext previous) =>
        previous.Status == "completed" ? previous : previous with { Status = "unavailable", DaysLeft = null };
}
