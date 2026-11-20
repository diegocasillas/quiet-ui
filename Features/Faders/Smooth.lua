local _, ns = ...
local Faders = ns.Faders or {}
ns.Faders = Faders

function ns.UpdateSmooth(elapsed, profile)
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
    local run = profile or Faders.Run
    run("resource bar", Faders.UpdateResource, elapsed)
    run("player frame", Faders.UpdatePlayer, elapsed)
    run("party frames", Faders.UpdateParty, elapsed)
    run("raid manager", Faders.UpdateRaidManager, elapsed)
    run("buffs", Faders.UpdateAuras, elapsed)
    Faders.samplingPower = false
end
