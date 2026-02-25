-- Eagle Flight Gun Passive Abilities Fix
-- This file fixes the issue where passive abilities are removed after using the Eagle Flight gun

if SERVER then -- Only run on server

    local eaglePassives = {}
    local eagleRagdolls = {}

    -- Initialize the global ragdoll table if it doesn't exist
    if not efrn then
        efrn = {}
    end

    -- Track when a player gets the Eagle Flight gun
    hook.Add("PlayerSwitchWeapon", "EagleFlightPassiveFix_TrackWeapon", function(ply, oldWeapon, newWeapon)
        if IsValid(newWeapon) and newWeapon:GetClass() == "ttt_weapon_eagleflightgun" then
            ply.HasEagleFlightGun = true
        end
    end)

    -- Hook directly into the ragdoll creation
    hook.Add("OnEntityCreated", "EagleFlightPassiveFix_TrackRagdoll", function(ent)
        if not IsValid(ent) then return end
        
        -- Wait until entity is fully initialized
        timer.Simple(0, function()
            if not IsValid(ent) then return end
            
            -- Check if this is an Eagle Flight ragdoll
            if ent:GetClass() == "prop_ragdoll" and IsValid(ent.Owner) and ent.Owner:IsPlayer() and ent.Owner.HasEagleFlightGun then
                local ply = ent.Owner
                local steamID = ply:SteamID()
                
                -- Store player's passives
                StorePlayerPassives(ply)
                
                -- Mark this as an Eagle Flight ragdoll
                eagleRagdolls[ent:EntIndex()] = steamID
                
                -- Hook into the original unragdoll function to restore passives
                local originalUnragdoll = ent.unragdoll
                if originalUnragdoll then
                    ent.unragdoll = function()
                        local plyID = eagleRagdolls[ent:EntIndex()]
                        local stepback = ent.vel
                        
                        -- Call the original function
                        originalUnragdoll()
                        
                        -- Restore passives after a short delay
                        timer.Simple(0.1, function()
                            local restoredPlayer = player.GetBySteamID(plyID)
                            if IsValid(restoredPlayer) then
                                RestorePlayerPassives(restoredPlayer)
                            end
                        end)
                        
                        -- Remove from tracking
                        eagleRagdolls[ent:EntIndex()] = nil
                    end
                end
            end
        end)
    end)

    -- Store all passive items for a player
    function StorePlayerPassives(ply)
        local steamID = ply:SteamID()
        eaglePassives[steamID] = {
            passives = {},
            health = ply:Health(),
            armor = ply:Armor(),
            walkSpeed = ply:GetWalkSpeed(),
            runSpeed = ply:GetRunSpeed(),
            jumpPower = ply:GetJumpPower(),
            crouchSpeed = ply:GetCrouchedWalkSpeed()
        }
        
        -- Store TTT-specific passives if the gamemode is TTT
        if GAMEMODE_NAME == "terrortown" or GetRoundState then
            eaglePassives[steamID].credits = ply:GetCredits()
            
            -- Store equipment items
            if ply.HasEquipmentItem then
                for _, item in pairs({"item_ttt_nofalldmg", "item_ttt_radar", "item_ttt_armor", "item_ttt_speed"}) do
                    if ply:HasEquipmentItem(item) then
                        table.insert(eaglePassives[steamID].passives, item)
                    end
                end
            end
            
            -- If TTT2 is installed, handle its passive items
            if ply.GetEquipmentItems then
                eaglePassives[steamID].ttt2Items = ply:GetEquipmentItems()
            end
        end
        
        -- Store custom properties that might be set by passive items
        eaglePassives[steamID].customProps = {
            noFallDamage = ply.NoFallDamage,
            hasRadar = ply.HasRadar,
            radarTime = ply.RadarTime,
            speedModifier = ply.SpeedModifier
        }
    end

    -- Restore all passive items for a player
    function RestorePlayerPassives(ply)
        local steamID = ply:SteamID()
        if not eaglePassives[steamID] then 
            return 
        end
        
        -- Restore basic attributes
        ply:SetHealth(eaglePassives[steamID].health)
        ply:SetArmor(eaglePassives[steamID].armor)
        ply:SetWalkSpeed(eaglePassives[steamID].walkSpeed)
        ply:SetRunSpeed(eaglePassives[steamID].runSpeed)
        ply:SetJumpPower(eaglePassives[steamID].jumpPower)
        ply:SetCrouchedWalkSpeed(eaglePassives[steamID].crouchSpeed)
        
        -- Restore TTT-specific passives
        if GAMEMODE_NAME == "terrortown" or GetRoundState then
            -- Restore credits
            ply:SetCredits(eaglePassives[steamID].credits)
            
            -- Restore standard TTT items
            if ply.GiveEquipmentItem then
                for _, item in ipairs(eaglePassives[steamID].passives) do
                    ply:GiveEquipmentItem(item)
                end
                
                -- Restore TTT2 items if applicable
                if eaglePassives[steamID].ttt2Items then
                    for _, itemID in ipairs(eaglePassives[steamID].ttt2Items) do
                        ply:GiveEquipmentItem(itemID)
                    end
                end
            end
        end
        
        -- Restore custom properties
        local props = eaglePassives[steamID].customProps
        ply.NoFallDamage = props.noFallDamage
        ply.HasRadar = props.hasRadar
        ply.RadarTime = props.radarTime
        ply.SpeedModifier = props.speedModifier
        
        -- Clear stored data
        eaglePassives[steamID] = nil
    end
end