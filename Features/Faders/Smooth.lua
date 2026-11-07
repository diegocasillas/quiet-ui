local _, ns = ...
local Faders = ns.Faders or {}
ns.Faders = Faders

function ns.UpdateSmooth(elapsed)
    Faders.samplingPower = false
    Faders.sampledPlayerShow = nil
    local ok, kind = pcall(Faders.ReadRestingPower)
    Faders.sampledKind = ok and kind or nil
    if not ok then ns.Report("player power", kind) end
    for i = 1, Faders.powerSampleCount do Faders.powerAlphas[i] = nil end
    Faders.powerSampleCount = 0
    for i = 1, Faders.thresholdSampleCount do Faders.thresholdAlphas[i] = nil end
    Faders.thresholdSampleCount = 0
    Faders.samplingPower = true
    Faders.Run("resource bar", Faders.UpdateResource, elapsed)
    Faders.Run("player frame", Faders.UpdatePlayer, elapsed)
    Faders.Run("party frames", Faders.UpdateParty, elapsed)
    Faders.Run("raid manager", Faders.UpdateRaidManager, elapsed)
    Faders.Run("buffs", Faders.UpdateAuras, elapsed)
    Faders.samplingPower = false
end
