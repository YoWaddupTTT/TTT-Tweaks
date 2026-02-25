-- Prop Disguiser Passive Abilities Fix
-- This file fixes issues with the Prop Disguiser:
-- 1. Lost passive items when undisguising
-- 2. Weapon breaking if player dies while disguised
-- 3. Message spam to dead players

if SERVER then
    -- Storage for player passives and prop tracking
    local disguiserPassives = {}
    local deadDisguisedPlayers = {}
    
    -- Prevent message spam to dead players
    hook.Add("Initialize", "PropDisguiser_AntiSpam_Hook", function()
        -- Wait a bit for the game to initialize
        timer.Simple(5, function()
            if net and net._Receivers and net._Receivers["PD_ChatPrint"] then
                local originalHandler = net._Receivers["PD_ChatPrint"]
                
                -- Replace the handler with our fixed version
                net._Receivers["PD_ChatPrint"] = function(len, ply)
                    -- Only forward messages to living players
                    if IsValid(ply) and ply:Alive() and not deadDisguisedPlayers[ply:SteamID()] then
                        originalHandler(len, ply)
                    end
                end
            end
        end)
    end)
    
    -- Store all passive items for a player
    local function StorePlayerPassives(ply)
        local steamID = ply:SteamID()
        
        -- Count how many armor stacks the player has
        local armorStacks = 0
        if ply.HasEquipmentItem and ply:HasEquipmentItem("item_ttt_armor") then
            -- For TTT, we need to count how many times they bought armor
            -- This is tricky, but we can infer from armor value (each stack = 30 armor)
            armorStacks = math.floor(ply:Armor() / 30)
        end
        
        disguiserPassives[steamID] = {
            passives = {},
            health = ply:Health(),
            armor = ply:Armor(),
            armorStacks = armorStacks, -- Store the exact number of armor stacks
            walkSpeed = ply:GetWalkSpeed(),
            runSpeed = ply:GetRunSpeed(),
            jumpPower = ply:GetJumpPower(),
            crouchSpeed = ply:GetCrouchedWalkSpeed()
        }
        
        -- Store TTT-specific passives if the gamemode is TTT
        if GAMEMODE_NAME == "terrortown" or GetRoundState then
            disguiserPassives[steamID].credits = ply:GetCredits()
            
            -- Store equipment items (excluding armor since we're handling it separately)
            if ply.HasEquipmentItem then
                for _, item in pairs({"item_ttt_nofalldmg", "item_ttt_radar", "item_ttt_speed"}) do
                    if ply:HasEquipmentItem(item) then
                        table.insert(disguiserPassives[steamID].passives, item)
                    end
                end
            end
            
            -- If TTT2 is installed, handle its passive items
            if ply.GetEquipmentItems then
                disguiserPassives[steamID].ttt2Items = ply:GetEquipmentItems()
            end
        end
        
        -- Store custom properties that might be set by passive items
        disguiserPassives[steamID].customProps = {
            noFallDamage = ply.NoFallDamage,
            hasRadar = ply.HasRadar,
            radarTime = ply.RadarTime,
            speedModifier = ply.SpeedModifier
        }
    end

    -- Restore all passive items for a player
    local function RestorePlayerPassives(ply)
        local steamID = ply:SteamID()
        if not disguiserPassives[steamID] then 
            return 
        end
        
        -- Don't restore passives for dead players to prevent issues
        if not ply:Alive() then
            disguiserPassives[steamID] = nil
            return
        end
        
        -- Restore movement attributes
        ply:SetWalkSpeed(disguiserPassives[steamID].walkSpeed)
        ply:SetRunSpeed(disguiserPassives[steamID].runSpeed)
        ply:SetJumpPower(disguiserPassives[steamID].jumpPower)
        ply:SetCrouchedWalkSpeed(disguiserPassives[steamID].crouchSpeed)
        
        -- Restore TTT-specific passives
        if GAMEMODE_NAME == "terrortown" or GetRoundState then
            -- Restore credits
            ply:SetCredits(disguiserPassives[steamID].credits)
            
            -- Restore non-armor items first
            if ply.GiveEquipmentItem then
                for _, item in ipairs(disguiserPassives[steamID].passives) do
                    ply:GiveEquipmentItem(item)
                end
                
                -- Restore exactly the number of armor stacks they had
                for i = 1, disguiserPassives[steamID].armorStacks do
                    ply:GiveEquipmentItem("item_ttt_armor")
                end
                
                -- Restore TTT2 items if applicable
                if disguiserPassives[steamID].ttt2Items then
                    for _, itemID in ipairs(disguiserPassives[steamID].ttt2Items) do
                        ply:GiveEquipmentItem(itemID)
                    end
                end
            end
        end
        
        -- Restore custom properties
        local props = disguiserPassives[steamID].customProps
        ply.NoFallDamage = props.noFallDamage
        ply.HasRadar = props.hasRadar
        ply.RadarTime = props.radarTime
        ply.SpeedModifier = props.speedModifier
        
        -- Clear stored data
        disguiserPassives[steamID] = nil
    end
    
    -- Fix the prop disguiser by hooking into weapon functions
    hook.Add("InitPostEntity", "PropDisguiserFix_Setup", function()
        -- Wait for all entities to load
        timer.Simple(5, function()
            local weaponTable = weapons.GetStored("weapon_ttt_prop_disguiser")
            if weaponTable then
                -- Fix the disguise function to store passives
                local originalPropDisguise = weaponTable.PropDisguise
                weaponTable.PropDisguise = function(self, ...)
                    -- Store passives before disguising
                    if IsValid(self.Owner) then
                        StorePlayerPassives(self.Owner)
                    end
                    
                    -- Call original function
                    originalPropDisguise(self, ...)
                end
                
                -- Fix the undisguise function to restore passives
                local originalPropUnDisguise = weaponTable.PropUnDisguise
                weaponTable.PropUnDisguise = function(self, ...)
                    local ply = self.Owner
                    
                    -- Call original function
                    originalPropUnDisguise(self, ...)
                    
                    -- Restore passives after a short delay
                    if IsValid(ply) then
                        timer.Simple(0.1, function()
                            if IsValid(ply) then
                                RestorePlayerPassives(ply)
                            end
                        end)
                    end
                end
            end
        end)
    end)
    
    -- Fix death handler to properly clean up disguises and prevent issues
    hook.Add("PlayerDeath", "PropDisguiserFix_DeathCleanup", function(victim, inflictor, attacker)
        if victim:GetNWBool("PD_Disguised") then
            local steamID = victim:SteamID()
            
            -- Mark this player as dead while disguised to prevent message spam
            deadDisguisedPlayers[steamID] = true
            
            -- Remove any timers associated with this player
            timer.Remove(steamID.."_DisguiseTime")
            
            -- Clean up the disguise entity
            if IsValid(victim.DisguisedProp) then
                victim.DisguisedProp.IsADisguise = false
                victim.DisguisedProp:Remove()
                victim.DisguisedProp = nil
            end
            
            -- Reset NWVars
            victim:SetNWBool("PD_Disguised", false)
            
            -- Find and fix the player's weapon
            for _, weapon in pairs(victim:GetWeapons()) do
                if weapon:GetClass() == "weapon_ttt_prop_disguiser" then
                    weapon:SetNWBool("PD_WepDisguised", false)
                    weapon:SetNWBool("PD_TimeOut", false)
                end
            end
            
            -- Remove the passives entry as we don't need to restore them on death
            disguiserPassives[steamID] = nil
            
            -- Clean up the dead player flag after round restart
            timer.Simple(10, function()
                deadDisguisedPlayers[steamID] = nil
            end)
        end
    end)
    
    -- Fix for round end/prep to clean up any disguised players
    hook.Add("TTTEndRound", "PropDisguiserFix_RoundCleanup", function()
        -- Clean up all disguises
        for _, ply in ipairs(player.GetAll()) do
            if ply:GetNWBool("PD_Disguised") then
                timer.Remove(ply:SteamID().."_DisguiseTime")
                
                if IsValid(ply.DisguisedProp) then
                    ply.DisguisedProp:Remove()
                    ply.DisguisedProp = nil
                end
                
                ply:SetNWBool("PD_Disguised", false)
                
                -- Reset any weapons
                for _, weapon in pairs(ply:GetWeapons()) do
                    if weapon:GetClass() == "weapon_ttt_prop_disguiser" then
                        weapon:SetNWBool("PD_WepDisguised", false)
                        weapon:SetNWBool("PD_TimeOut", false)
                    end
                end
            end
        end
        
        -- Clear all tracking tables
        disguiserPassives = {}
        deadDisguisedPlayers = {}
    end)
    
    hook.Add("TTTPrepareRound", "PropDisguiserFix_PrepCleanup", function()
        -- Same cleanup as round end
        disguiserPassives = {}
        deadDisguisedPlayers = {}
    end)
    
    -- Fix for dropped weapons to ensure they're clean
    hook.Add("PlayerDroppedWeapon", "PropDisguiserFix_DroppedWeapon", function(ply, weapon)
        if IsValid(weapon) and weapon:GetClass() == "weapon_ttt_prop_disguiser" then
            weapon:SetNWBool("PD_WepDisguised", false)
            weapon:SetNWBool("PD_TimeOut", false)
        end
    end)
end