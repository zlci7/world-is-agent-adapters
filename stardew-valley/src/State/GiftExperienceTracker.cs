using HarmonyLib;
using GameAgent.Stardew.Runtime;
using GameAgent.Stardew.Tasks;
using StardewModdingAPI;
using StardewValley;

namespace GameAgent.Stardew.State;

public sealed class GiftExperienceTracker : IDisposable
{
    public const string SaveKey = "gameagent.StardewAdapterProbe/experiences.v1";
    private readonly IMonitor monitor;
    private readonly HashSet<string> targets;
    private readonly Harmony harmony = new("gameagent.StardewAdapterProbe.experiences");
    private static GiftExperienceTracker? active;
    private GiftExperienceJournal? journal;

    public GiftExperienceTracker(IMonitor monitor, IEnumerable<string> targets)
    {
        this.monitor = monitor;
        this.targets = new(targets.Where(name => !string.IsNullOrWhiteSpace(name)).Select(name => name.Trim()), StringComparer.Ordinal);
    }

    public void Install()
    {
        try
        {
            var method = AccessTools.Method(typeof(NPC), nameof(NPC.receiveGift), new[] { typeof(StardewValley.Object), typeof(Farmer), typeof(bool), typeof(float), typeof(bool) });
            this.harmony.Patch(method, prefix: new HarmonyMethod(typeof(GiftExperienceTracker), nameof(BeforeGift)),
                postfix: new HarmonyMethod(typeof(GiftExperienceTracker), nameof(AfterGift)));
            active = this;
        }
        catch (Exception ex) { this.monitor.Log($"GameAgent gift experiences unavailable: {ex.GetType().Name}.", LogLevel.Error); }
    }

    public void Load()
    {
        this.journal = null;
        if (!Context.IsWorldReady || Game1.IsMultiplayer || string.IsNullOrEmpty(Constants.SaveFolderName)) return;
        try
        {
            Game1.player.modData.TryGetValue(SaveKey, out string? json);
            this.journal = GiftExperienceJournal.Restore(json, Constants.SaveFolderName!, Game1.player.UniqueMultiplayerID);
        }
        catch (Exception ex) { this.monitor.Log($"GameAgent experience journal unavailable: {ex.GetType().Name}. Existing save metadata is preserved.", LogLevel.Error); }
    }

    public void Reset() => this.journal = null;
    private bool IsCurrent => Context.IsWorldReady && !Game1.IsMultiplayer && this.journal is { } value &&
        value.WorldId == Constants.SaveFolderName && value.PlayerId == Game1.player.UniqueMultiplayerID;
    public GiftReceipt[] Pending => this.IsCurrent ? this.journal!.Pending.ToArray() : Array.Empty<GiftReceipt>();
    public string[]? ValidIds(string npcName) => !this.IsCurrent ? null :
        this.journal!.ValidIds.TryGetValue(npcName, out var ids) ? ids.ToArray() : Array.Empty<string>();

    public bool Acknowledge(string id)
    {
        if (!this.IsCurrent || !this.journal!.Acknowledge(id)) return false;
        this.Persist(); return true;
    }

    private void Persist() => Game1.player.modData[SaveKey] = this.journal!.Serialize();

    private static int GiftCount(Farmer player, NPC npc, StardewValley.Object item) =>
        player.giftedItems.TryGetValue(npc.Name, out var items) && items.TryGetValue(item.ItemId, out int count) ? count : 0;

    private sealed record GiftAttempt(int Count, GiftReceipt Receipt);

    private static void BeforeGift(NPC __instance, StardewValley.Object __0, Farmer __1, out GiftAttempt? __state)
    {
        __state = null;
        var tracker = active;
        if (tracker is null || !tracker.IsCurrent || !ReferenceEquals(__1, Game1.player)) return;
        try
        {
            if (!__instance.IsVillager || tracker.targets.Count > 0 && !tracker.targets.Contains(__instance.Name)) return;
            var receipt = new GiftReceipt(Guid.NewGuid().ToString("N"), tracker.journal!.WorldId, __1.UniqueMultiplayerID,
                __1.Name, __instance.Name, __instance.displayName, __0.QualifiedItemId, __0.DisplayName, __0.Quality,
                Game1.year, GameClock.SeasonIndex(Game1.currentSeason) + 1, Game1.dayOfMonth, Game1.timeOfDay / 100, Game1.timeOfDay % 100,
                GameClock.ToTick(Game1.year, GameClock.SeasonIndex(Game1.currentSeason), Game1.dayOfMonth, Game1.timeOfDay));
            __state = new(GiftCount(__1, __instance, __0), receipt);
        }
        catch (Exception ex) { tracker.monitor.Log($"GameAgent gift capture unavailable: {ex.GetType().Name}.", LogLevel.Warn); }
    }

    private static void AfterGift(NPC __instance, StardewValley.Object __0, Farmer __1, GiftAttempt? __state)
    {
        var tracker = active;
        if (__state is null || tracker is null || !tracker.IsCurrent) return;
        try
        {
            // The native accepted-gift ledger is authoritative; refused offers and quest hand-ins do not increment it.
            if (!tracker.journal!.RecordAcceptedGift(__state.Receipt, __state.Count, GiftCount(__1, __instance, __0))) return;
            tracker.Persist();
        }
        catch (Exception ex) { tracker.monitor.Log($"GameAgent gift receipt could not be saved: {ex.GetType().Name}.", LogLevel.Error); }
    }

    public void Dispose()
    {
        this.harmony.UnpatchAll(this.harmony.Id);
        if (ReferenceEquals(active, this)) active = null;
    }
}
