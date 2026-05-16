/*
MIT License

Copyright (c) 2026 GoopSwagger

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

local CVAR_FLAGS = {FCVAR_NOTIFY, FCVAR_ARCHIVE, FCVAR_REPLICATED}
local RJ_USES_AMMO = CreateConVar("ttt_rocket_jumper_limit_ammo", 0, CVAR_FLAGS, "Whether the Jumper has limited ammo.", 0, 1)
local RJ_BASE_AMMO = CreateConVar("ttt_rocket_jumper_ammo", 60, CVAR_FLAGS, "How much ammo the Jumper starts with.", 1, 1000)
local PHD_COOLDOWN = CreateConVar("ttt_phd_explosion_cooldown", 2, CVAR_FLAGS, "Cooldown before PHD explosions can trigger again.", 0, 15)
local RJ_CVAR_UPDATE_MSG = "TTT_Tweaks_RocketJumperAmmoCvarUpdate"

local RJ_HIT_GROUND_HOOK = "market_gardener__DropMeleeOnFall" -- original addon
local PHD_FALL_DMG_HOOK = "TTTPHDRemoveFallDamage" -- original addon
local RJ_CLASSNAME = "weapon_ttt_rocket_jumper"
local PHD_ITEM_CLASSNAME = "item_ttt_phd"

function RJ_ApplyChanges(firstTimeSetup)
    print("[TTT-Tweaks] Applying Rocket Jumper changes; first time setup:", firstTimeSetup)
    local swep = weapons.GetStored(RJ_CLASSNAME)

    -- for idempotency
    RJ_OG_JUMPERFIRE = RJ_OG_JUMPERFIRE or swep.JumperFire

    if RJ_USES_AMMO:GetBool() then
        local ammoVal = RJ_BASE_AMMO:GetInt()
        print("[TTT-Tweaks] Changing Rocket Jumper ammo limit to", ammoVal)

        swep.Primary.ClipSize    = ammoVal
        swep.Primary.DefaultClip = ammoVal
        if CLIENT then swep.DrawAmmo = true end
    else
        swep.Primary.ClipSize    = -1
        swep.Primary.DefaultClip = -1
        if CLIENT then swep.DrawAmmo = false end
    end

    ---------------------------------------------------------------
    if not firstTimeSetup then return end -- first time setup below

    swep.JumperFire = function(self)
        local usesAmmo = RJ_USES_AMMO:GetBool()
        local ply = self:GetOwner()

        local worldShootPos = ply:GetShootPos()
        local viewTargetPos = ply:GetAimVector() * 200
        local tr = util.TraceLine({
            start = worldShootPos,
            endpos = worldShootPos + viewTargetPos,
            filter = ply,
            mask = MASK_NPCSOLID_BRUSHONLY
        }) -- same "in range" criteria as original addon (local func)

        if tr.Fraction < 1 and (not usesAmmo or self:CanPrimaryAttack()) then
            RJ_OG_JUMPERFIRE(self)

            if usesAmmo then
                self:SetClip1(self:Clip1() - 1)
            else
                self._rjJumpTracker = self._rjJumpTracker and (self._rjJumpTracker + 1) or 1
            end
        end
    end

    function swep:AddToSettingsMenu(parent)
        local formTweaks = vgui.CreateTTT2Form(parent, "TTT Tweaks")

        formTweaks:MakeCheckBox({
            serverConvar = "ttt_rocket_jumper_limit_ammo",
            label = "Limit rocket ammo"
        })
        formTweaks:MakeSlider({
            serverConvar = "ttt_rocket_jumper_ammo",
            label = "Base ammo if limited",
            min = 1, max = 1000, decimal = 0
        })
    end

    -- fix for the bug where landing does not reset the player's "Jumper" state if not holding the weapons
    hook.Remove("OnPlayerHitGround", RJ_HIT_GROUND_HOOK)

    if SERVER then
        hook.Add("OnPlayerHitGround", RJ_HIT_GROUND_HOOK, function(ply, inWater, onFloater, speed)
            if not SERVER or not ply:IsPlayer() then return end

            for _, wep in ipairs(ply:GetWeapons()) do
                if wep:GetClass() == RJ_CLASSNAME then
                    if not wep:GetIsJumper() then
                        wep:BecomeJumper()

                        if not RJ_USES_AMMO:GetBool() then
                            local stat = "[Stat Track] This Rocket Jumper has been used "..wep._rjJumpTracker.." time"
                            if wep._rjJumpTracker >= 500 then stat = stat.."s! Give it a rest!"
                            elseif wep._rjJumpTracker >= 200 then stat = stat.."s! You're not stalling are you?"
                            elseif wep._rjJumpTracker >= 100 then stat = stat.."s! Wow!"
                            elseif wep._rjJumpTracker >= 20 then stat = stat.."s!"
                            elseif wep._rjJumpTracker > 1 then stat = stat.."s" end
                            LANG.Msg(ply, stat, nil, MSG_MSTACK_PLAIN)
                        end
                    end

                    return
                end
            end
        end)

        function swep:PreDrop() -- also reset on drop :)
            if not self:GetIsJumper() then
                self:BecomeJumper()
            end
        end
    end
end

function PHD_ApplyChanges()
    print("[TTT-Tweaks] Applying PHD changes (cooldown)")
    local item = items.GetStored(PHD_ITEM_CLASSNAME)

    phdFallDmgHook = phdFallDmgHook or hook.GetTable()["EntityTakeDamage"][PHD_FALL_DMG_HOOK]
    if not phdFallDmgHook then return end

    hook.Add("EntityTakeDamage", PHD_FALL_DMG_HOOK, function(target, dmginfo)
        if not target:IsPlayer() then return end

        if dmginfo:IsFallDamage() then
            local curTime = CurTime()
            local timeSinceLast = target._phdCDLastTime and (curTime-target._phdCDLastTime) or 999
            local timeRemaining = PHD_COOLDOWN:GetFloat() - timeSinceLast

            if timeRemaining > 0 then
                print("[TTT-Tweaks] PHD explosion blocked due to cooldown ("..timeRemaining.."s remains)")
                return true
            else
                target._phdCDLastTime = curTime
            end
        end

        return phdFallDmgHook(target, dmginfo)
    end)

    function item:AddToSettingsMenu(parent)
        local formTweaks = vgui.CreateTTT2Form(parent, "TTT Tweaks")

        formTweaks:MakeSlider({
            serverConvar = "ttt_phd_explosion_cooldown",
            label = "Minimum cooldown between PHD explosions (s)",
            min = 0, max = 15
        })
    end
end



if SERVER then
    util.AddNetworkString(RJ_CVAR_UPDATE_MSG)

    function cvarChangeNotify(name, oldVal, newVal)
        RJ_ApplyChanges() --server call
        net.Start(RJ_CVAR_UPDATE_MSG)
        net.Broadcast()
    end

    local rjCvars = {RJ_USES_AMMO, RJ_BASE_AMMO}
    for _, cvar in ipairs(rjCvars) do
        cvars.RemoveChangeCallback(cvar:GetName(), cvar:GetName())
        cvars.AddChangeCallback(cvar:GetName(), cvarChangeNotify, cvar:GetName())
    end

elseif CLIENT then
    net.Receive(RJ_CVAR_UPDATE_MSG, function()
        RJ_ApplyChanges() --client call
    end)
end

-- initial setup
hook.Add("InitPostEntity", "TTT2RocketJumperAmmoLimit", function()
    RJ_ApplyChanges(true)
    PHD_ApplyChanges()
end)