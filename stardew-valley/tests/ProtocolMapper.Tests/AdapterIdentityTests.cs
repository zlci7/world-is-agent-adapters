using System.Reflection;
using GameAgent.Stardew.Runtime;
using Xunit;

namespace GameAgent.Stardew.Tests;

public sealed class AdapterIdentityTests
{
    [Fact]
    public void HelloUsesAssemblyInformationalVersion()
    {
        string expected = typeof(AdapterBuildInfo).Assembly
            .GetCustomAttribute<AssemblyInformationalVersionAttribute>()!
            .InformationalVersion;

        var hello = AdapterIdentity.BuildHello("adapter", "v1alpha2", "stardew-valley", "1.6", "session");

        Assert.Equal(expected, hello.AdapterVersion);
    }
}
