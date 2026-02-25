-- Trigger Finger Chip Buff
-- Improves the Trigger Finger Chip weapon with additional features

if SERVER then
    -- Network string for communicating chip-controlled kills to clients
    util.AddNetworkString("TTT_TriggerFingerChipKill")

    -- Store original functions we'll override
    local META = FindMetaTable("Weapon")
    if not META._OriginalTraitorChipPrimary then
        META._OriginalTraitorChipPrimary = META.PrimaryAttack
    end

    -- Continuous firing variables
    local continuousFiringPlayers = {}

    local CHIP_MAX_CONTINUOUS_FIRE_DURATION = 2 -- Maximum duration in seconds

    -- Helper function to deduct charges when stopping continuous fire
    local function DeductContinuousFiringCharge(targetInfo)
        -- Only deduct a charge if we haven't already AND if at least one shot was actually fired
        if IsValid(targetInfo.weapon) and targetInfo.hasDeductedCharge == false and targetInfo.shotsFired > 0 then
            targetInfo.weapon:SetShots(targetInfo.weapon:GetShots() - 1)
            targetInfo.hasDeductedCharge = true
            
            -- Debug message
            if IsValid(targetInfo.weapon:GetOwner()) then
                targetInfo.weapon:GetOwner():PrintMessage(HUD_PRINTTALK, "Used 1 charge. " .. targetInfo.weapon:GetShots() .. " remaining.")
            end
            
            return true
        end
        return false
    end

    -- Override the PrimaryAttack function for traitor_chip
    hook.Add("Think", "TriggerFingerChip_ContinuousFiring", function()
        for owner, targetInfo in pairs(continuousFiringPlayers) do
            if IsValid(owner) and IsValid(targetInfo.target) and IsValid(targetInfo.weapon) then
                -- Check if we've been firing for too long (over 2 seconds)
                local currentDuration = CurTime() - targetInfo.startTime
                if currentDuration >= CHIP_MAX_CONTINUOUS_FIRE_DURATION then
                    -- Time limit reached, stop firing and deduct charge
                    if IsValid(owner) then
                        owner:PrintMessage(HUD_PRINTTALK, "Maximum control duration reached.")
                    end
                    DeductContinuousFiringCharge(targetInfo)
                    continuousFiringPlayers[owner] = nil
                    continue -- Skip to next player
                end
                
                -- Check if player is still holding attack button
                if owner:KeyDown(IN_ATTACK) then
                    -- Get the target's active weapon
                    local targetWeapon = targetInfo.target:GetActiveWeapon()
                    
                    -- Stop if target is reloading or changed weapons
                    if not IsValid(targetWeapon) or targetWeapon:GetClass() == "weapon_ttt_unarmed" or 
                    targetWeapon:GetClass() ~= targetInfo.lastWeaponClass then
                        
                        -- Deduct one charge since continuous firing is stopping
                        DeductContinuousFiringCharge(targetInfo)
                        continuousFiringPlayers[owner] = nil
                    else
                        -- Check if we can fire (respect weapon's firing rate)
                        if not targetInfo.nextFire or CurTime() >= targetInfo.nextFire then
                            -- Only fire if weapon can primary attack
                            if targetWeapon.CanPrimaryAttack and targetWeapon:CanPrimaryAttack() then
                                -- Use the chip's stored reference to firing function
                                targetInfo.target.isChipControlled = true
                                targetInfo.target.controlledBy = owner
                                targetWeapon:PrimaryAttack(true)
                                targetInfo.target.isChipControlled = false
                                targetInfo.target:SetAnimation(PLAYER_ATTACK1)
                                
                                -- Set next fire time based on weapon's fire rate
                                local delay = 0.1 -- Default delay
                                if targetWeapon.Primary and targetWeapon.Primary.Delay then
                                    delay = targetWeapon.Primary.Delay
                                end
                                targetInfo.nextFire = CurTime() + delay
                                
                                -- Track that at least one shot was fired
                                targetInfo.shotsFired = targetInfo.shotsFired + 1
                            end
                        end
                    end
                else
                    -- Player released attack key, stop continuous firing and deduct charge
                    DeductContinuousFiringCharge(targetInfo)
                    continuousFiringPlayers[owner] = nil
                end
            else
                -- Invalid references, clean up
                if targetInfo and not targetInfo.hasDeductedCharge then
                    DeductContinuousFiringCharge(targetInfo)
                end
                continuousFiringPlayers[owner] = nil
            end
        end
    end)

    -- Override weapon functions
    hook.Add("WeaponEquip", "TriggerFingerChip_BuffOverride", function(weapon, owner)
        if not IsValid(weapon) or weapon:GetClass() ~= "traitor_chip" then return end
        
        -- Wait a tick to make sure weapon is fully initialized
        timer.Simple(0, function()
            if not IsValid(weapon) then return end
            
            -- Modify the PrimaryAttack function
            weapon.OriginalTraitorChipPrimaryAttack = weapon.PrimaryAttack
            
            -- Replace with our enhanced version
            weapon.PrimaryAttack = function(self, tbl)
                local target = self:GetTarget()
                
                if not IsValid(target) then
                    -- PLACEMENT MODE: Allow placement on any part of the back
                    local placeDist = (TRAITORCHIP and TRAITORCHIP.MaxPlaceDistance) or self.MaxPlaceDistance
                    local pl = self:GetOwner()
                    local tr = util.QuickTrace(pl:GetShootPos(), pl:EyeAngles():Forward() * placeDist, pl)
                    
                    if tr.Hit then
                        local pos = tr.HitPos
                        if pos:Distance(pl:GetShootPos()) <= placeDist then
                            local ent = tr.Entity
                            if IsValid(ent) and ent:IsPlayer() and ent != pl then
                                if not ent:HasChip() then
                                    -- Check if we're behind the player (more permissive than original)
                                    local yawDelta = math.abs(math.AngleDifference(ent:GetAngles().y, pl:EyeAngles().y))
                                    if yawDelta <= 120 then -- Much more permissive angle
                                        -- Get current charges before placing
                                        local currentCharges = self:GetShots()
                                        
                                        -- Only use default charges if this is a fresh chip (no charges set)
                                        if currentCharges <= 0 then
                                            currentCharges = (TRAITORCHIP and TRAITORCHIP.Charges) or self.Charges
                                        end
                                        
                                        self:SetPlaced(true)
                                        self:SetTarget(ent)
                                        self:SetShots(currentCharges) -- Use existing charges
                                        
                                        ent:SetChip(true)
                                        self:PlaySequence("draw")
                                        
                                        -- Store reference for death hook - FIXED: ensure these get set properly
                                        ent.chipOwner = pl
                                        ent.chipWeapon = self
                                        
                                        -- Add chip owner's fingerprints to the chipped player
                                        if not ent.fingerprints then 
                                            ent.fingerprints = {} 
                                        end
                                        table.insert(ent.fingerprints, pl)
                                    end
                                end
                            end
                        end
                    end
                elseif self:GetPlaced() then
                    -- CONTROL MODE: Continuous firing
                    if not self.nextAttack or self.nextAttack < CurTime() then
                        self:PlaySequence("press")
                        
                        timer.Simple(0.2, function() -- Button press delay
                            if not IsValid(self) or not IsValid(self:GetOwner()) then return end
                            local sound = CreateSound(self:GetOwner(), "buttons/button18.wav")
                            sound:PlayEx(0.1, 196)
                            
                            local target = self:GetTarget()
                            if IsValid(target) and target:Alive() then
                                local wep = target:GetActiveWeapon()
                                
                                if IsValid(wep) and wep:GetClass() != "weapon_ttt_unarmed" then
                                    local isController = wep:GetClass() == self:GetClass()
                                    local overflow = isController and tbl and table.HasValue(tbl, wep:GetTarget())
                                    
                                    if not overflow and wep.CanPrimaryAttack and wep:CanPrimaryAttack() and wep.PrimaryAttack then
                                        if self:GetShots() > 0 then
                                            if isController then
                                                -- Original logic for chip controlling another chip
                                                local tbl = tbl or {self:GetOwner()}
                                                wep:PrimaryAttack(tbl)
                                                self:SetShots(self:GetShots() - 1)
                                            else
                                                -- Start continuous firing mode
                                                local owner = self:GetOwner()
                                                
                                                -- Start continuous firing mode
                                                local owner = self:GetOwner()

                                                -- Setup continuous firing data
                                                continuousFiringPlayers[owner] = {
                                                    target = target,
                                                    weapon = self,
                                                    lastWeaponClass = wep:GetClass(),
                                                    hasDeductedCharge = false,
                                                    nextFire = 0, -- Start firing immediately
                                                    startTime = CurTime(),
                                                    shotsFired = 0 -- Add a counter to track successful shots
                                                }
                                                
                                                -- Initial shot happens in the Think hook
                                            end
                                            
                                            self:SetError("")
                                        else
                                            self:SetError("No charges")
                                        end
                                    elseif tbl then
                                        for _, pl in pairs(tbl) do
                                            if IsValid(pl) then
                                                local wep = pl:GetActiveWeapon()
                                                if wep and wep:GetClass() == self:GetClass() then
                                                    wep:SetError("Overflow")
                                                end
                                            end
                                        end
                                    end
                                else
                                    self:SetError("No weapon")
                                end
                            else
                                self:SetError("Target dead")
                            end
                        end)
                        
                        self.nextAttack = CurTime() + 0.75
                    end
                end
            end
        end)
    end)
    
    -- Return chip when victim dies - FIXED VERSION with proper charge handling
    hook.Add("PlayerDeath", "TriggerFingerChip_ReturnOnDeath", function(victim, inflictor, attacker)
        -- Check if this player has a chip on them
        if IsValid(victim) and victim:HasChip() then
            -- Stop any continuous firing first
            for owner, info in pairs(continuousFiringPlayers) do
                if info.target == victim then
                    DeductContinuousFiringCharge(info)
                    continuousFiringPlayers[owner] = nil
                end
            end
            
            -- Get the chip owner
            local chipOwner = victim.chipOwner
            
            if IsValid(chipOwner) then
                -- Get the weapon reference and charges
                local chipWeapon = victim.chipWeapon
                
                if IsValid(chipWeapon) then
                    local originalCharges = chipWeapon:GetShots()
                    local newCharges = originalCharges - 2 -- No minimum - can go to zero or negative
                    
                    -- Remove the original weapon from the owner first
                    if chipOwner:HasWeapon("traitor_chip") then
                        local existingChip = chipOwner:GetWeapon("traitor_chip")
                        if IsValid(existingChip) and existingChip == chipWeapon then
                            chipOwner:StripWeapon("traitor_chip")
                        end
                    end
                    
                    -- Only give chip back if we have charges remaining
                    if newCharges > 0 then
                        -- Short delay to allow weapon removal to process
                        timer.Simple(0.1, function()
                            if IsValid(chipOwner) then
                                -- Give the owner a new chip with reduced charges
                                local newChip = chipOwner:Give("traitor_chip")
                                if IsValid(newChip) then
                                    newChip:SetPlaced(false)
                                    newChip:SetShots(newCharges)
                                    
                                    -- Notify player
                                    chipOwner:PrintMessage(HUD_PRINTTALK, "Your Trigger Finger Chip was recovered with " .. newCharges .. " charges remaining.")
                                end
                            end
                        end)
                    else
                        -- Chip had insufficient charges - destroyed
                        chipOwner:PrintMessage(HUD_PRINTTALK, "Your Trigger Finger Chip was destroyed.")
                    end
                end
            end
            
            -- Clean up the victim's chip data
            victim:SetChip(false)
            victim.chipOwner = nil
            victim.chipWeapon = nil
        end
    end)
    
    -- Monitor weapon reloading 
    hook.Add("Think", "TriggerFingerChip_CheckReloading", function()
        for _, ply in pairs(player.GetAll()) do
            if IsValid(ply) and ply:HasChip() then
                local activeWep = ply:GetActiveWeapon()
                if IsValid(activeWep) then
                    -- Check if player is reloading
                    if activeWep.GetActivity and activeWep:GetActivity() == ACT_VM_RELOAD then
                        -- Find and stop any continuous firing for this player
                        for owner, info in pairs(continuousFiringPlayers) do
                            if info.target == ply then
                                DeductContinuousFiringCharge(info)
                                continuousFiringPlayers[owner] = nil
                                
                                if IsValid(owner) then
                                    owner:PrintMessage(HUD_PRINTTALK, "Target is reloading - control stopped.")
                                end
                            end
                        end
                    end
                end
            end
        end
    end)
    
    -- Logging only - no kill attribution change
    hook.Add("EntityTakeDamage", "TriggerFingerChip_LogDamage", function(victim, dmginfo)
        if not IsValid(victim) or not victim:IsPlayer() then return end
        
        local attacker = dmginfo:GetAttacker()
        if IsValid(attacker) and attacker:IsPlayer() and attacker.isChipControlled and IsValid(attacker.controlledBy) then
            -- Log the damage event
            if DamageLog then
                DamageLog(string.format("CHIP: %s [%s] controlled %s [%s] to damage %s [%s] for %.1f damage", 
                    attacker.controlledBy:Nick(), 
                    attacker.controlledBy:GetRoleString(), 
                    attacker:Nick(), 
                    attacker:GetRoleString(),
                    victim:Nick(),
                    victim:GetRoleString(),
                    dmginfo:GetDamage()))
            end
        end
    end)
    
    -- Notify about chip-controlled kills for the killcard text
    hook.Add("DoPlayerDeath", "TriggerFingerChip_NotifyChipped", function(victim, attacker, dmginfo)
        if not IsValid(victim) or not IsValid(attacker) or not attacker:IsPlayer() then return end
        
        if attacker.isChipControlled and IsValid(attacker.controlledBy) then
            -- Create DNA evidence on the victim pointing to the controlled player
            if not victim.fingerprints then victim.fingerprints = {} end
            table.insert(victim.fingerprints, attacker)
            
            victim.killer_sample = {
                t = CurTime() + (GetGlobalFloat("ttt_killer_dna_basetime") or 100),
                killer = attacker, -- Leave the original attacker for DNA
                killer_sid64 = attacker:SteamID64()
            }
            
            -- Send message to clients that this kill was chip-controlled
            net.Start("TTT_TriggerFingerChipKill")
            net.WriteEntity(victim)
            net.WriteEntity(attacker)
            net.Broadcast()
        end
    end)
    
    -- Prevent karma penalties from going to the controlled player
    hook.Add("TTTKarmaGivePenalty", "TriggerFingerChip_KarmaRedirect", function(ply, penalty, victim)
        if ply:HasChip() and ply.isChipControlled and IsValid(ply.controlledBy) then
            local controller = ply.controlledBy
            
            -- Redirect karma penalty to the controller
            if KARMA and KARMA.GivePenalty then
                KARMA.GivePenalty(controller, penalty, victim)
                controller:SetCleanRound(false)
            end
            
            -- Return true to prevent default karma handling
            return true
        end
    end)
end

if CLIENT then
    -- Keep track of chip-controlled kills
    local chipControlledKills = {}
    
    -- Reset on round events
    hook.Add("TTTBeginRound", "TriggerFingerChip_ResetKills", function()
        chipControlledKills = {}
    end)
    
    hook.Add("TTTEndRound", "TriggerFingerChip_ResetKills", function()
        chipControlledKills = {}
    end)
    
    -- Listen for chip-controlled kill notifications
    net.Receive("TTT_TriggerFingerChipKill", function()
        local victim = net.ReadEntity()
        local killer = net.ReadEntity()
        
        if IsValid(victim) and IsValid(killer) then
            chipControlledKills[killer:SteamID64()] = true
            
            -- Create a timer to clear the data after the kill popup would disappear
            timer.Create("TriggerFingerChip_ClearKillData_" .. killer:SteamID64(), 10, 1, function()
                chipControlledKills[killer:SteamID64()] = nil
            end)
        end
    end)
    
    -- Find the killer info popup element and hook into it
    local originalDrawHelper = nil

    -- Hook that will run every time the HUD updates
    hook.Add("HUDPaint", "TriggerFingerChip_CheckHookDrawHelper", function()
        -- Only run this code once when we need to hook
        if originalDrawHelper or not KILLER_INFO or not KILLER_INFO.data then return end
        
        -- Find the killer info popup element
        for _, element in pairs(hudelements.GetList()) do
            if element.id == "pure_skin_killer_info_popup" then
                
                -- Store original DrawHelper function
                originalDrawHelper = element.DrawHelper
                
                -- Replace DrawHelper with our modified version
                element.DrawHelper = function(self, x, y, w, h)
                    -- Call original function first
                    originalDrawHelper(self, x, y, w, h)
                    
                    -- Check if the killer was chip-controlled
                    if KILLER_INFO.data.killer_sid64 and chipControlledKills[KILLER_INFO.data.killer_sid64] then
                        -- Only show for normal kills, not self-kills or world kills
                        if KILLER_INFO.data.mode ~= "killer_self_no_weapon" and 
                        KILLER_INFO.data.mode ~= "killer_world" then
                            
                            local paddingEdge = 39 * self.scale
                            local paddingInner = 14 * self.scale
                            local sizeColorBar2 = 78 * self.scale
                            
                            -- Use the exact same offsetContentX calculation from the popup code
                            local offsetContentX = x + paddingEdge + sizeColorBar2 + paddingInner
                            
                            -- Get the exact killer name text as shown in HUD
                            local killerNameText = string.upper(KILLER_INFO.data.killer_name)
                            
                            -- Use correct font before measuring text width
                            surface.SetFont("PureSkinBar")
                            local nameWidth = surface.GetTextSize(killerNameText)
                            
                            -- Get the text color based on user's HUD settings
                            local colorTextBase = util.GetDefaultColor(self.basecolor)
                            
                            -- Add the chip text immediately after the last character of the name
                            draw.AdvancedText(
                                " (Trigger-Finger Chipped)",  -- Space at start to separate from name
                                "PureSkinBar",
                                offsetContentX + nameWidth,  -- Position exactly at the end of name
                                y + paddingEdge + paddingInner - 4 * self.scale,  -- Use exact same Y position as killer name
                                colorTextBase,  -- Use the user's HUD text color
                                TEXT_ALIGN_LEFT,
                                TEXT_ALIGN_TOP,
                                true,
                                self.scale
                            )
                        end
                    end
                end
                break
            end
        end
    end)
    
    -- Variable to track the state of KILLER_INFO
    local wasKillerInfoActive = false
    
    -- Check for popup visibility changes to reset tracking when popup disappears
    hook.Add("Think", "TriggerFingerChip_CheckPopupVisibility", function()
        local isKillerInfoActive = KILLER_INFO and KILLER_INFO.data and KILLER_INFO.data.render
        
        if wasKillerInfoActive and not isKillerInfoActive then
            -- Popup was just hidden, clean up specific killer data
            if KILLER_INFO and KILLER_INFO.data and KILLER_INFO.data.killer_sid64 then
                chipControlledKills[KILLER_INFO.data.killer_sid64] = nil
            end
        end
        
        wasKillerInfoActive = isKillerInfoActive
    end)
end