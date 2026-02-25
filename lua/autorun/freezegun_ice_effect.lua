-- Freezegun Ice Effect Integration
-- Makes the freezegun apply the same ice effect as the ice grenade
-- Credit: Snuffles the Fox

if SERVER then
    util.AddNetworkString("Freezegun_IceEffect")

    local function ApplyIceEffect(ply, duration)
        if not IsValid(ply) or not ply:IsPlayer() then return end

        ply:SetColor(Color(87, 230, 230, 255))
        ply:Freeze(true)
        ParticleEffect("ice_explosion", ply:GetPos(), Angle(0, 0, 0))
        ply:EmitSound("ice_explosion.wav", 85, 90, 1, CHAN_AUTO)

        net.Start("Freezegun_IceEffect")
        net.WriteFloat(duration)
        net.Send(ply)

        timer.Simple(duration, function()
            if IsValid(ply) then
                ply:Freeze(false)
                ply:SetColor(Color(255, 255, 255, 255))
                net.Start("Freezegun_IceEffect")
                net.WriteFloat(0)
                net.Send(ply)
            end
        end)
    end

    -- Patch the freezegun's FreezeTarget function at runtime
    hook.Add("InitPostEntity", "PatchFreezegunFreezeEffect", function()
        timer.Simple(1, function()
            for _, wep in ipairs(weapons.GetList()) do
                if wep and wep.ClassName == "weapon_ttt_freezegun" then
                    -- Patch the global FreezeTarget function if it exists
                    if FreezeTarget then
                        local oldFreezeTarget = FreezeTarget
                        _G.FreezeTarget = function(att, path, dmginfo)
                            local ent = path.Entity
                            if not IsValid(ent) then return end
                            if SERVER then
                                if ent:IsPlayer() and (not GAMEMODE:AllowPVP()) then return end
                                -- Use our effect instead of just Freeze
                                local duration = 5
                                if ConVarExists("ttt_freezegun_duration") then
                                    duration = GetConVar("ttt_freezegun_duration"):GetInt()
                                end
                                ApplyIceEffect(ent, duration)
                            end
                        end
                    end
                end
            end
        end)
    end)
end

if CLIENT then
    local iceEffectEnd = 0

    net.Receive("Freezegun_IceEffect", function()
        local duration = net.ReadFloat()
        if duration > 0 then
            iceEffectEnd = CurTime() + duration
        else
            iceEffectEnd = 0
        end
    end)

    hook.Add("HUDPaint", "Freezegun_IceEffectOverlay", function()
        if iceEffectEnd > CurTime() then
            surface.SetDrawColor(255,255,255,250)
            surface.SetMaterial(Material("ice_effect.png"))
            surface.DrawTexturedRect(0,0,surface.ScreenWidth(),surface.ScreenHeight())
        end
    end)
end