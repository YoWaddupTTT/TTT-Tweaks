-- R8 Revolver + Speed Cola Compatibility Fix
-- Fixes primary fire and reload issues when Speed Cola perk is active
-- Credit: Snuffles the Fox

if SERVER then
    AddCSLuaFile()
end

-- Add this line to explicitly run the code on both client and server
local isClient = CLIENT

local speedMultCvar = GetConVar("ttt_speedcola_speed_multiplier") or CreateClientConVar("ttt_speedcola_speed_multiplier", "2", true, false)

-- Hook to detect when R8 revolver is spawned/picked up
hook.Add("PlayerSwitchWeapon", "R8SpeedColaFix_Main", function(ply, oldWep, newWep)
    if not IsValid(newWep) then return end
    
    -- Only process for local player on client
    if isClient and ply ~= LocalPlayer() then return end
    
    -- Check if switching to R8 Revolver
    if newWep:GetClass() == "weapon_ttt_csgo_r8revolver" then
        
        -- Check if player has Speed Cola active
        if ply:GetNWBool("SpeedColaActive", false) then
            ApplyR8SpeedColaFix(newWep)
        end
    end
    
    -- Clean up old weapon if it was R8
    if IsValid(oldWep) and oldWep:GetClass() == "weapon_ttt_csgo_r8revolver" then
        RemoveR8SpeedColaFix(oldWep)
    end
end)

-- Function to apply Speed Cola fixes to R8 Revolver
function ApplyR8SpeedColaFix(wep)
    if not IsValid(wep) or wep:GetClass() ~= "weapon_ttt_csgo_r8revolver" then
        return 
    end
    
    -- Prevent double-application
    if wep.SpeedCola_Applied then
        return
    end
    
    local speedMult = speedMultCvar:GetFloat()
    
    -- Store original functions and values on the weapon instance
    wep.SpeedCola_OriginalReload = wep.Reload
    wep.SpeedCola_OriginalThink = wep.Think
    wep.SpeedCola_OriginalReloadingTime = wep.ReloadingTime
    wep.SpeedCola_Applied = true
    
    -- Apply speed multiplier to reload timing
    wep.ReloadingTime = wep.SpeedCola_OriginalReloadingTime / speedMult
    
    -- Fix the Reload function to work with Speed Cola
    wep.Reload = function(self, ...)
        
        if self.Reloading == 0
            and self.ReloadingTimer <= CurTime()
            and self:Clip1() < self.Primary.ClipSize
            and self:Ammo1() > 0 then
            
            self:SendWeaponAnim(ACT_VM_RELOAD)
            self:GetOwner():SetAnimation(PLAYER_RELOAD)
            
            -- Set playback rate for faster animation
            self:SetPlaybackRate(speedMult)
            if IsValid(self:GetOwner():GetViewModel()) then
                self:GetOwner():GetViewModel():SetPlaybackRate(speedMult)
            end
            
            self:SetNextPrimaryFire(CurTime() + self:GetOwner():GetViewModel():SequenceDuration() / speedMult)
            self:SetNextSecondaryFire(CurTime() + self:GetOwner():GetViewModel():SequenceDuration() / speedMult)
            
            self.Hammer = 0
            self.HammerTimer = CurTime()
            self.InspectTimer = CurTime() + self:GetOwner():GetViewModel():SequenceDuration() / speedMult
            self.Reloading = 1
            self.ReloadingTimer = CurTime() + self.ReloadingTime
            self.ReloadingStage = 1
            self.ReloadingStageTimer = CurTime() + (1.033333 / speedMult)
            self.Idle = 0
            self.IdleTimer = CurTime() + self:GetOwner():GetViewModel():SequenceDuration() / speedMult
        end
    end
    
    -- Fix the Think function to handle Speed Cola timing while preserving original logic
    wep.Think = function(self, ...)
        -- DON'T call original Think as it would handle hammer firing twice
        -- Instead, we need to implement the firing logic here
        
        -- Handle firing sequence from original Think function
        if self.Hammer == 1 then
            if not self:GetOwner():KeyDown(IN_ATTACK) then
                self.Hammer = 0
                self.HammerTimer = CurTime()
                self.Idle = 0
                self.IdleTimer = CurTime()
            end

            if self.HammerTimer <= CurTime() and self:GetOwner():KeyDown(IN_ATTACK) then
                self:FireCylinder(false)
            end
        end
        
        -- Now call the rest of the original think (without duplicating the hammer code)
        -- For view punch during reloading and spread calculations
        
        -- Add Speed Cola specific enhancements
        local speedMult = speedMultCvar:GetFloat()
        
        -- Fix hammer pull animation speed for Speed Cola
        if self.Hammer == 1 and self:GetOwner():KeyDown(IN_ATTACK) then
            if IsValid(self:GetOwner():GetViewModel()) then
                self:GetOwner():GetViewModel():SetPlaybackRate(speedMult)
            end
        end
        
        -- Adjust reload view punch timing for Speed Cola
        if self.Reloading == 1 then
            local timeLeft = self.ReloadingTimer - CurTime()
            local originalTimeLeft = timeLeft * speedMult
            
            -- Only override view punch if we're in Speed Cola mode
            if originalTimeLeft <= self.SpeedCola_OriginalReloadingTime and originalTimeLeft > 1.75 then
                self:GetOwner():ViewPunch(Angle(-0.025, 0, 0))
            elseif originalTimeLeft <= 1.75 and originalTimeLeft > 1.5 then
                self:GetOwner():ViewPunch(Angle(-0.05, -0.025, 0))
            elseif originalTimeLeft <= 1.5 and originalTimeLeft > 1.25 then
                self:GetOwner():ViewPunch(Angle(0.05, -0.05, 0))
            elseif originalTimeLeft <= 1.25 and originalTimeLeft > 1 then
                self:GetOwner():ViewPunch(Angle(0.1, -0.075, 0))
            elseif originalTimeLeft <= 1 and originalTimeLeft > 0.75 then
                self:GetOwner():ViewPunch(Angle(0.075, -0.1, 0))
            elseif originalTimeLeft <= 0.75 and originalTimeLeft > 0.5 then
                self:GetOwner():ViewPunch(Angle(0.05, -0.1, 0))
            elseif originalTimeLeft <= 0.5 and originalTimeLeft > 0.25 then
                self:GetOwner():ViewPunch(Angle(-0.05, -0.075, 0))
            elseif originalTimeLeft <= 0.25 and originalTimeLeft > 0 then
                self:GetOwner():ViewPunch(Angle(-0.025, 0.025, 0))
            end
        end
        
        -- Add these parts from the original Think function to handle spread and reloading
        if self.ShotTimer > CurTime() then
            self.Primary.SpreadTimer = CurTime() + self.Primary.SpreadTime
        end
        
        if self:GetOwner():IsOnGround() then
            if self:GetOwner():GetVelocity():Length() <= 100 then
                if self.Primary.SpreadTimer <= CurTime() then
                    self.Primary.Spread = self.Primary.SpreadMin
                end
                if self.Primary.Spread > self.Primary.SpreadMin then
                    self.Primary.Spread = (
                        (self.Primary.SpreadTimer - CurTime()) / self.Primary.SpreadTime
                    ) * self.Primary.Spread
                end
            end

            if self:GetOwner():GetVelocity():Length() <= 100 and self.Primary.Spread > self.Primary.SpreadMax then
                self.Primary.Spread = self.Primary.SpreadMax
            end
            if self:GetOwner():GetVelocity():Length() > 100 then
                self.Primary.Spread = self.Primary.SpreadMove
                self.Primary.SpreadTimer = CurTime() + self.Primary.SpreadTime
                if self.Primary.Spread > self.Primary.SpreadMin then
                    self.Primary.Spread = (
                        (self.Primary.SpreadTimer - CurTime()) / self.Primary.SpreadTime
                    ) * self.Primary.SpreadMove
                end
            end
        end

        if not self:GetOwner():IsOnGround() then
            self.Primary.Spread = self.Primary.SpreadAir
            self.Primary.SpreadTimer = CurTime() + self.Primary.SpreadTime
            if self.Primary.Spread > self.Primary.SpreadMin then
                self.Primary.Spread = ((self.Primary.SpreadTimer - CurTime()) / self.Primary.SpreadTime)
                    * self.Primary.SpreadAir
            end
        end

        if self.Reloading == 1 and self.ReloadingTimer <= CurTime() then
            self:ReloadEnd()
        end
        if self.IdleTimer <= CurTime() then
            self:IdleAnimation()
        end
    end

    -- Store the original FireCylinder function
    wep.SpeedCola_OriginalFireCylinder = wep.FireCylinder
    
    -- Override the FireCylinder function to ensure proper client effects
    wep.FireCylinder = function(self, is_secondary)
        
        -- Use original function but ensure client-side effects work
        local result = self.SpeedCola_OriginalFireCylinder(self, is_secondary)
        
        -- If on client, ensure sound and effects play
        if CLIENT then
            -- This helps ensure client effects trigger properly
            self:EmitSound(self.Primary.Sound)
        end
        
        return result
    end
end

-- Function to remove Speed Cola fixes from R8 Revolver
function RemoveR8SpeedColaFix(wep)
    if not IsValid(wep) or wep:GetClass() ~= "weapon_ttt_csgo_r8revolver" then return end
    if not wep.SpeedCola_Applied then return end
    
    -- Restore original functions and values
    if wep.SpeedCola_OriginalReload then
        wep.Reload = wep.SpeedCola_OriginalReload
        wep.SpeedCola_OriginalReload = nil
    end
    
    if wep.SpeedCola_OriginalThink then
        wep.Think = wep.SpeedCola_OriginalThink
        wep.SpeedCola_OriginalThink = nil
    end
    
    if wep.SpeedCola_OriginalReloadingTime then
        wep.ReloadingTime = wep.SpeedCola_OriginalReloadingTime
        wep.SpeedCola_OriginalReloadingTime = nil
    end

    if wep.SpeedCola_OriginalFireCylinder then
        wep.FireCylinder = wep.SpeedCola_OriginalFireCylinder
        wep.SpeedCola_OriginalFireCylinder = nil
    end
    
    -- Reset playback rates
    wep:SetPlaybackRate(1)
    if IsValid(wep:GetOwner()) and IsValid(wep:GetOwner():GetViewModel()) then
        wep:GetOwner():GetViewModel():SetPlaybackRate(1)
    end
    
    -- Reset reloading state
    wep.Reloading = 0
    wep.SpeedCola_Applied = false
end

-- Hook to handle when Speed Cola is activated/deactivated
hook.Add("Think", "R8SpeedColaCheck", function()
    for _, ply in pairs(player.GetAll()) do
        -- On client, only process for local player
        if isClient and ply ~= LocalPlayer() then continue end
        
        if IsValid(ply) and ply:Alive() then
            local activeWep = ply:GetActiveWeapon()
            if IsValid(activeWep) and activeWep:GetClass() == "weapon_ttt_csgo_r8revolver" then
                local hasSpeedCola = ply:GetNWBool("SpeedColaActive", false)
                local hasFixApplied = activeWep.SpeedCola_Applied
                
                if hasSpeedCola and not hasFixApplied then
                    ApplyR8SpeedColaFix(activeWep)
                elseif not hasSpeedCola and hasFixApplied then
                    RemoveR8SpeedColaFix(activeWep)
                end
            end
        end
    end
end)

-- Prevent Speed Cola's normal ApplySpeed from affecting R8 Revolver
hook.Add("PlayerSwitchWeapon", "R8SpeedColaFix_Prevent", function(ply, oldWep, newWep)
    if not IsValid(newWep) then return end
    
    -- If switching to R8 Revolver with Speed Cola active, mark it to prevent normal Speed Cola logic
    if newWep:GetClass() == "weapon_ttt_csgo_r8revolver" and ply:GetNWBool("SpeedColaActive", false) then
        -- This will be checked by the Speed Cola system to skip applying its normal logic
        newWep.SpeedColaIgnore = true
    end
end)

-- Override Speed Cola's ApplySpeed function to ignore R8 Revolver
local originalApplySpeed = ApplySpeed
if originalApplySpeed then
    ApplySpeed = function(wep)
        if IsValid(wep) and (wep.SpeedColaIgnore or wep:GetClass() == "weapon_ttt_csgo_r8revolver") then
            return
        end
        return originalApplySpeed(wep)
    end
end

-- Clean up on round restart
hook.Add("TTTPrepareRound", "R8SpeedColaCleanup", function()
    for _, ply in pairs(player.GetAll()) do
        if IsValid(ply) then
            local activeWep = ply:GetActiveWeapon()
            if IsValid(activeWep) and activeWep:GetClass() == "weapon_ttt_csgo_r8revolver" then
                RemoveR8SpeedColaFix(activeWep)
            end
        end
    end
end)