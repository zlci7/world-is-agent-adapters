using System.Reflection;

namespace GameAgent.Stardew.Runtime;

public static class AdapterBuildInfo
{
    public static string Version { get; } =
        typeof(AdapterBuildInfo).Assembly
            .GetCustomAttribute<AssemblyInformationalVersionAttribute>()?
            .InformationalVersion
        ?? throw new InvalidOperationException("Assembly informational version is missing.");
}
