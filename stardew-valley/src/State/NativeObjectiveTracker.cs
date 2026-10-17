using System;
using System.Linq;
using System.Collections.Generic;
using System.Text.Json;
using StardewModdingAPI;
using StardewValley;
using StardewValley.Quests;

namespace GameAgent.Stardew.State;

// One native Willy fishing objective; quest and receipt metadata travel with the same game save.
public sealed class NativeObjectiveTracker
{
    public const string InstanceKey = "gameagent.StardewAdapterProbe/native_objective_instance";
    public const string SaveKey = "gameagent.StardewAdapterProbe/willy_fishing_objective";
    private readonly IMonitor monitor;
    private FishingQuest? tracked;
    private Farmer? owner;
    private string worldId = string.Empty;
    private StardewObjectiveContext? last;

    public NativeObjectiveTracker(IMonitor monitor) => this.monitor = monitor;

    public void Reset() { this.tracked = null; this.owner = null; this.worldId = string.Empty; this.last = null; }

    public StardewObjectiveContext? Observe(NPC npc, Farmer player, string currentWorld)
    {
        if (npc.Name != "Willy" || Game1.IsMultiplayer || string.IsNullOrEmpty(currentWorld)) return null;
        try
        {
            if (!ReferenceEquals(this.owner, player) || this.worldId != currentWorld) this.Reset();
            this.owner = player;
            this.worldId = currentWorld;
            this.Refresh();
            player.modData.TryGetValue(SaveKey, out string? json);
            StardewObjectiveContext? previous = NativeObjectiveState.Restore(json, currentWorld, player.UniqueMultiplayerID);
            FishingQuest? candidate = player.questLog.OfType<FishingQuest>()
                .Where(q => q.target.Value == "Willy" && !q.destroy.Value && !q.completed.Value)
                .OrderByDescending(q => q.dayQuestAccepted.Value).FirstOrDefault();
            if (candidate is null && previous is not null)
                candidate = player.questLog.OfType<FishingQuest>().FirstOrDefault(q =>
                    q.target.Value == "Willy" && !q.destroy.Value && q.modData.TryGetValue(InstanceKey, out string? id) && id == previous.InstanceRef);
            if (candidate is not null)
            {
                this.tracked = candidate;
                return this.Persist(this.Describe(this.Snapshot(candidate)));
            }
            return previous is null ? null : this.Persist(this.Describe(NativeObjectiveState.Missing(previous)));
        }
        catch (Exception ex)
        {
            this.monitor.Log($"GameAgent native objective observation unavailable: {ex.GetType().Name}.", LogLevel.Warn);
            return null;
        }
    }

    public void Update()
    {
        if (!Context.IsWorldReady || Game1.IsMultiplayer || !ReferenceEquals(this.owner, Game1.player) || Constants.SaveFolderName != this.worldId) return;
        try { this.Refresh(); }
        catch (Exception ex)
        {
            this.monitor.Log($"GameAgent native objective result unavailable: {ex.GetType().Name}.", LogLevel.Warn);
            this.Reset();
        }
    }

    private void Refresh()
    {
        if (this.owner is null || this.tracked is null) return;
        StardewObjectiveContext snapshot = this.Snapshot(this.tracked);
        // Keep the object reference until its completed flag has been checked, even if removed from questLog.
        if (!this.tracked.completed.Value && (!this.owner.questLog.Contains(this.tracked) || this.tracked.destroy.Value))
            snapshot = NativeObjectiveState.Missing(snapshot);
        this.Persist(snapshot);
    }

    private StardewObjectiveContext Snapshot(FishingQuest quest)
    {
        if (!quest.modData.TryGetValue(InstanceKey, out string? id) || !Guid.TryParseExact(id, "N", out _))
            quest.modData[InstanceKey] = id = Guid.NewGuid().ToString("N");
        var snapshot = new StardewObjectiveContext(id, "game_native", "fishing", "Willy",
            quest.completed.Value ? "completed" : quest.numberFished.Value >= quest.numberToFish.Value ? "ready_to_return" : "active",
            quest.ItemId.Value, quest.numberToFish.Value, quest.numberFished.Value,
            quest.dailyQuest.Value && quest.daysLeft.Value >= 0 ? quest.daysLeft.Value : null, "quest_giver");
        return this.last?.InstanceRef == id && this.last.ItemId == snapshot.ItemId ? snapshot with {
            ItemName = this.last.ItemName, Seasons = this.last.Seasons,
            TimeWindows = this.last.TimeWindows, Weather = this.last.Weather,
        } : snapshot;
    }

    private StardewObjectiveContext Describe(StardewObjectiveContext value)
    {
        // Fish data describes general conditions, not a guarantee that this location can spawn the fish.
        value = value with { ItemName = null, Seasons = null, TimeWindows = null, Weather = null };
        try
        {
            string id = value.ItemId.StartsWith("(O)", StringComparison.Ordinal) ? value.ItemId[3..] : value.ItemId;
            var fish = Game1.content.Load<Dictionary<string, string>>("Data/Fish");
            string? name = ItemRegistry.GetData(value.ItemId)?.DisplayName;
            if (fish.TryGetValue(id, out string? row))
            {
                string[] fields = row.Split('/');
                if (fields.Length >= 8)
                    return value with { ItemName = Limit(name, 64), Seasons = Limit(fields[6], 64),
                        TimeWindows = Limit(fields[5], 80), Weather = Limit(fields[7], 32) };
            }
            return value with { ItemName = Limit(name, 64) };
        }
        catch { return value; }
    }

    private static string? Limit(string? value, int max) => value is { Length: > 0 } && value.Length <= max ? value : null;

    private StardewObjectiveContext Persist(StardewObjectiveContext value)
    {
        this.last = value;
        string json = JsonSerializer.Serialize(new NativeObjectiveSave(this.worldId, this.owner!.UniqueMultiplayerID, value));
        if (!this.owner.modData.TryGetValue(SaveKey, out string? previous) || previous != json)
            this.owner.modData[SaveKey] = json;
        return value;
    }
}
