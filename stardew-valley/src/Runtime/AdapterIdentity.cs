using GameAgent.Protocol.V1Alpha2;

namespace GameAgent.Stardew.Runtime;

public static class AdapterIdentity
{
    public static AdapterHello BuildHello(
        string adapterId,
        string protocolVersion,
        string gameId,
        string gameVersion,
        string sessionId) =>
        ProtocolMapper.BuildAdapterHello(
            adapterId,
            AdapterBuildInfo.Version,
            protocolVersion,
            gameId,
            gameVersion,
            sessionId);
}
