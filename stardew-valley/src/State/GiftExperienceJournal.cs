using System.Text.Json;

namespace GameAgent.Stardew.State;

public sealed record GiftReceipt(string Id, string WorldId, long PlayerId, string PlayerName,
    string NpcName, string NpcDisplayName, string ItemId, string ItemName, int Quality,
    int Year, int Season, int Day, int Hour, int Minute, long Tick);

// Receipt membership and the offline outbox are saved together with the player.
public sealed class GiftExperienceJournal
{
    public string WorldId { get; set; } = string.Empty;
    public long PlayerId { get; set; }
    public Dictionary<string, List<string>> ValidIds { get; set; } = new(StringComparer.Ordinal);
    public List<GiftReceipt> Pending { get; set; } = new();

    public static GiftExperienceJournal Restore(string? json, string worldId, long playerId)
    {
        GiftExperienceJournal value = string.IsNullOrEmpty(json)
            ? new() { WorldId = worldId, PlayerId = playerId }
            : JsonSerializer.Deserialize<GiftExperienceJournal>(json) ?? throw new InvalidDataException("Missing experience journal");
        if (value.WorldId != worldId || value.PlayerId != playerId || value.ValidIds is null || value.Pending is null ||
            value.ValidIds.Any(pair => string.IsNullOrEmpty(pair.Key) || pair.Value is null || pair.Value.Any(string.IsNullOrWhiteSpace)) ||
            value.Pending.Any(receipt => receipt.WorldId != worldId || receipt.PlayerId != playerId ||
                !value.ValidIds.TryGetValue(receipt.NpcName, out var ids) || !ids.Contains(receipt.Id)))
            throw new InvalidDataException("Experience journal does not match the loaded player/save");
        return value;
    }

    public void Add(GiftReceipt receipt)
    {
        if (receipt.WorldId != this.WorldId || receipt.PlayerId != this.PlayerId)
            throw new ArgumentException("Gift receipt belongs to another save/player");
        if (!this.ValidIds.TryGetValue(receipt.NpcName, out var ids)) this.ValidIds[receipt.NpcName] = ids = new();
        if (ids.Contains(receipt.Id)) return;
        ids.Add(receipt.Id);
        this.Pending.Add(receipt);
    }

    public bool RecordAcceptedGift(GiftReceipt receipt, int before, int after)
    {
        if (after <= before) return false;
        this.Add(receipt);
        return true;
    }

    public bool Acknowledge(string id) => this.Pending.RemoveAll(receipt => receipt.Id == id) > 0;
    public string Serialize() => JsonSerializer.Serialize(this);
}
