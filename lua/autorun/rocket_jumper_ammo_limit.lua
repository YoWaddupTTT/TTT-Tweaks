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
local RJ_BASE_AMMO = CreateConVar("ttt_rocket_jumper_ammo", 60, CVAR_FLAGS, "How much ammo the Jumper starts with.", 1, 1000)
local RJ_CVAR_UPDATE_MSG = "TTT_Tweaks_RocketJumperAmmoCvarUpdate"

local RJ_HIT_GROUND_HOOK = "market_gardener__DropMeleeOnFall" -- original addon
local RJ_CLASSNAME = "weapon_ttt_rocket_jumper"

function RJ_ApplyChanges(firstTimeSetup)
    local swep = weapons.GetStored(RJ_CLASSNAME)
    local ammoVal = RJ_BASE_AMMO:GetInt()
    print("[TTT-Tweaks] Changing Rocket Jumper ammo limit to", ammoVal)

    swep.Primary.ClipSize    = ammoVal
    swep.Primary.DefaultClip = ammoVal
    if not firstTimeSetup then return end -- first time setup below
    if CLIENT then swep.DrawAmmo = true end

    -- for idempotency
    RJ_OG_JUMPERFIRE = RJ_OG_JUMPERFIRE or swep.JumperFire

    swep.JumperFire = function(self)
        local ply = self:GetOwner()
        local worldShootPos = ply:GetShootPos()
        local viewTargetPos = ply:GetAimVector() * 200
        local tr = util.TraceLine({
            start = worldShootPos,
            endpos = worldShootPos + viewTargetPos,
            filter = ply,
            mask = MASK_NPCSOLID_BRUSHONLY
        }) -- same "in range" criteria as original addon (local func)

        if tr.Fraction < 1 and self:CanPrimaryAttack() then
            RJ_OG_JUMPERFIRE(self)
            self:SetClip1(self:Clip1() - 1)
        end
    end

    function swep:AddToSettingsMenu(parent)
        local formTweaks = vgui.CreateTTT2Form(parent, "TTT Tweaks")

        formTweaks:MakeSlider({
            serverConvar = "ttt_rocket_jumper_ammo",
            label = "Base ammo",
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


if SERVER then
    util.AddNetworkString(RJ_CVAR_UPDATE_MSG)

    function cvarChangeNotify(name, oldVal, newVal)
        RJ_ApplyChanges() --server call
        net.Start(RJ_CVAR_UPDATE_MSG)
        net.Broadcast()
    end

    cvars.RemoveChangeCallback(RJ_BASE_AMMO:GetName(), RJ_BASE_AMMO:GetName())
    cvars.AddChangeCallback(RJ_BASE_AMMO:GetName(), cvarChangeNotify, RJ_BASE_AMMO:GetName())

elseif CLIENT then
    net.Receive(RJ_CVAR_UPDATE_MSG, function()
        RJ_ApplyChanges() --client call
    end)
end

-- initial setup
hook.Add("InitPostEntity", "TTT2RocketJumperAmmoLimit", function()
    RJ_ApplyChanges(true)
end)