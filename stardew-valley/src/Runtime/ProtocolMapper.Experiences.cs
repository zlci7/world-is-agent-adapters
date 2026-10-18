using System.Globalization;
using GameAgent.Protocol.V1Alpha2;
using GameAgent.Stardew.State;
using GameAgent.Stardew.Tasks;
using Google.Protobuf.WellKnownTypes;

namespace GameAgent.Stardew.Runtime;

public static partial class ProtocolMapper
{
    public static GameEvent BuildGiftExperience(GiftReceipt receipt)
    {
        string target = ToNpcEntityId(receipt.NpcName);
        return new GameEvent {
            EventId = receipt.Id, EventType = "gift_received", WorldId = receipt.WorldId, TargetEntityId = target,
            GameTime = new GameTime { Year = receipt.Year, Season = receipt.Season, Day = receipt.Day, Hour = receipt.Hour, Minute = receipt.Minute },
            Entities = { BuildEntity(PlayerEntityId, "player", receipt.PlayerName), BuildEntity(target, "npc", receipt.NpcDisplayName) },
            Payload = new Struct { Fields = { [RuntimeSessionState.ExperienceExtension] = Value.ForStruct(new Struct { Fields = {
                ["version"] = Value.ForNumber(1), ["clock_id"] = Value.ForString(GameClock.ClockId),
                ["occurred_tick"] = Value.ForString(receipt.Tick.ToString(CultureInfo.InvariantCulture)),
                ["focus_until_tick"] = Value.ForString(checked(receipt.Tick + 3L * GameClock.MinutesPerDay).ToString(CultureInfo.InvariantCulture)),
                ["priority"] = Value.ForNumber(50),
            } }) } },
            ContextFacts = { new ContextFact {
                Kind = "interaction", ActorEntityId = PlayerEntityId, TargetEntityId = target,
                Text = $"{receipt.PlayerName}向{receipt.NpcDisplayName}赠送了1个{receipt.ItemName}；游戏确认赠送成功。",
                Attributes = new Struct { Fields = { ["item_id"] = Value.ForString(receipt.ItemId),
                    ["item_name"] = Value.ForString(receipt.ItemName), ["quantity"] = Value.ForNumber(1),
                    ["quality"] = Value.ForNumber(receipt.Quality), ["outcome"] = Value.ForString("accepted") } },
            } },
        };
    }

    public static void AttachExperienceView(Observation observation, long tick, IEnumerable<string> validIds)
    {
        observation.Extensions ??= new Struct();
        observation.Extensions.Fields[RuntimeSessionState.ExperienceExtension] = Value.ForStruct(new Struct { Fields = {
            ["version"] = Value.ForNumber(1), ["clock_id"] = Value.ForString(GameClock.ClockId),
            ["now_tick"] = Value.ForString(tick.ToString(CultureInfo.InvariantCulture)),
            ["valid_fact_ids"] = Value.ForList(validIds.Select(Value.ForString).ToArray()),
        } });
    }
}
