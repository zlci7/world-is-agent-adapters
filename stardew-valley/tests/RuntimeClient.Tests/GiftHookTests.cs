using System.Reflection;
using GameAgent.Stardew.State;
using HarmonyLib;
using StardewModdingAPI;
using StardewValley;
using Xunit;

namespace GameAgent.Stardew.Tests;

public sealed class GiftHookTests
{
    [Fact]
    public void HookRegistersAgainstInstalledNativeSignatureAndUnpatchesItsOwnMethods()
    {
        var method = typeof(NPC).GetMethod("receiveGift", new[] { typeof(StardewValley.Object), typeof(Farmer), typeof(bool), typeof(float), typeof(bool) });
        Assert.NotNull(method);
        var tracker = new GiftExperienceTracker(DispatchProxy.Create<IMonitor, SilentMonitor>(), Array.Empty<string>());
        tracker.Install();
        var patches = Harmony.GetPatchInfo(method);
        const string owner = "gameagent.StardewAdapterProbe.experiences";
        Assert.Contains(patches.Prefixes, patch => patch.owner == owner && patch.PatchMethod.Name == "BeforeGift");
        Assert.Contains(patches.Postfixes, patch => patch.owner == owner && patch.PatchMethod.Name == "AfterGift");
        Assert.DoesNotContain(patches.Prefixes, patch => patch.owner == owner && patch.PatchMethod.ReturnType == typeof(bool));
        tracker.Dispose();
        Assert.DoesNotContain(Harmony.GetPatchInfo(method)?.Owners.AsEnumerable() ?? Enumerable.Empty<string>(), id => id == owner);
    }
}
