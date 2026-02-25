AddCSLuaFile()

if SERVER then return end

-- Smoke Grenade Name Blocking
-- Prevents seeing player names through smoke grenades

local traceoffset = 32
local balancingsizefactor = 1.4
local initblockseethroughradius = 130 * balancingsizefactor
local finalblockseethroughradius = 35 * balancingsizefactor
local MAX_TRACE_LENGTH = math.sqrt(3) * 2 * 16384

---
-- Calculate the blocking radius based on smoke age
-- @param time Number of seconds since smoke was created
-- @param isSuper Boolean indicating if this is a super smoke grenade
local function smoketimetoblockradius(time, isSuper)
    local fadeStart = isSuper and 100 or 45
    local fadeEnd = isSuper and 120 or 55
    
    if time < fadeStart then
        return initblockseethroughradius
    end

    if time > fadeEnd then
        return 0
    end

    return ((time - fadeStart) / (fadeEnd - fadeStart) * finalblockseethroughradius 
            + (1 - (time - fadeStart) / (fadeEnd - fadeStart)) * initblockseethroughradius)
end

local function visiontoentblockedbysmoke(client, startpos, entpos)
    if not client.smokecenters then
        return false
    end

    for i, v in pairs(client.smokecenters) do
        local smokeDuration = v[3] and 120 or 55
        
        if CurTime() - v[2] < smokeDuration then
            local dis, _, l = util.DistanceToLine(startpos, entpos, v[1])
            local maxdis = smoketimetoblockradius(CurTime() - v[2], v[3])

            if -traceoffset < l and l < startpos:Distance(entpos) + traceoffset and dis < maxdis then
                return true
            end
        else
            client.smokecenters[i] = nil
        end
    end

    return false
end

hook.Add("Initialize", "SmokeGrenade_OverrideExplode", function()
    local smokeEnt = scripted_ents.GetStored("ttt_smokegrenade_proj")
    if smokeEnt then
        local oldExplode = smokeEnt.t.Explode

        smokeEnt.t.Explode = function(self, tr)
            if CLIENT then
                local spos = self:GetPos()

                if tr.Fraction ~= 1.0 then
                    spos = tr.HitPos + tr.HitNormal * 0.6
                end

                if not gameloop or gameloop.GetRoundState() ~= ROUND_POST then
                    local client = LocalPlayer()
                    client.smokecenters = client.smokecenters or {}
                    table.insert(client.smokecenters, { spos + Vector(0, 0, 48), CurTime(), false })
                end
            end

            return oldExplode(self, tr)
        end
    end
    
    local superSmokeEnt = scripted_ents.GetStored("ttt_supersmokegrenade_proj")
    if superSmokeEnt then
        local oldSuperExplode = superSmokeEnt.t.Explode

        superSmokeEnt.t.Explode = function(self, tr)
            if CLIENT then
                local spos = self:GetPos()

                if tr.Fraction ~= 1.0 then
                    spos = tr.HitPos + tr.HitNormal * 0.6
                end

                if not gameloop or gameloop.GetRoundState() ~= ROUND_POST then
                    local client = LocalPlayer()
                    client.smokecenters = client.smokecenters or {}
                    table.insert(client.smokecenters, { spos + Vector(0, 0, 64), CurTime(), true })
                end
            end

            return oldSuperExplode(self, tr)
        end
    end
end)

hook.Add("HUDDrawTargetID", "SmokeGrenade_HidePlayerInfo", function()
    local client = LocalPlayer()

    local startpos = client:EyePos()
    local endpos = client:GetAimVector()
    endpos:Mul(MAX_TRACE_LENGTH)
    endpos:Add(startpos)

    local trace = util.TraceLine({
        start = startpos,
        endpos = endpos,
        mask = MASK_SHOT,
        filter = client:GetObserverMode() == OBS_MODE_IN_EYE
                and { client, client:GetObserverTarget() }
            or client,
    })

    local ent = trace.Entity
    if not IsValid(ent) or ent.NoTarget then
        return
    end

    if IsValid(ent:GetNWEntity("ttt_driver", nil)) then
        ent = ent:GetNWEntity("ttt_driver", nil)

        if ent == client then
            return
        end
    end

    if ent:IsPlayer() then
        client.smokecenters = client.smokecenters or {}

        if visiontoentblockedbysmoke(client, startpos, trace.HitPos) then
            return false
        end
    end
end)