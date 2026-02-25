-- TTT2 Barnacle Jester Fix
-- This prevents barnacles placed by players on TEAM_JESTER from damaging other players

if SERVER then
    -- Track barnacles and their owners
    local barnacleOwners = {}
    
    -- Track which players have recently used the barnacle weapon
    local recentBarnacleUsers = {}
    
    -- Wait until the game is fully loaded
    hook.Add("InitPostEntity", "FixBarnacleJesterDamage", function()
        -- Try to hook the primary attack function of the weapon
        local SWEP = weapons.GetStored("weapon_ttt_barnacle")
        if SWEP then
            -- Store original functions
            local originalPrimaryAttack = SWEP.PrimaryAttack
            
            -- Override PrimaryAttack to track ownership
            SWEP.PrimaryAttack = function(self)
                -- Store owner before calling the original function
                local weaponOwner = self.Owner
                
                if not IsValid(weaponOwner) then 
                    return originalPrimaryAttack(self)
                end
                
                local ownerSteamID = weaponOwner:SteamID64() or "UNKNOWN"
                
                -- Mark this player as a recent barnacle user
                recentBarnacleUsers[weaponOwner] = CurTime()
                
                -- Call the original function
                local result = originalPrimaryAttack(self)
                
                -- Now track any new barnacles that might have been created
                timer.Create("TrackBarnaclesAfterWeaponUse_" .. ownerSteamID, 0.1, 10, function()
                    if not IsValid(weaponOwner) then return end
                    
                    for _, barnacle in ipairs(ents.FindByClass("npc_barnacle")) do
                        if not barnacleOwners[barnacle:EntIndex()] then
                            barnacleOwners[barnacle:EntIndex()] = weaponOwner
                            barnacle.BarnacleOwner = weaponOwner
                            barnacle:SetNWEntity("BarnacleOwner", weaponOwner)
                        end
                    end
                end)
                
                return result
            end
        end
        
        -- Track when players equip the barnacle weapon
        hook.Add("WeaponEquip", "TrackBarnacleWeaponEquip", function(weapon, owner)
            if IsValid(weapon) and weapon:GetClass() == "weapon_ttt_barnacle" and IsValid(owner) then
                recentBarnacleUsers[owner] = CurTime()
            end
        end)
        
        -- Hook into ALL entity creation to catch barnacles
        hook.Add("OnEntityCreated", "BarnacleTrackEverything", function(ent)
            if not IsValid(ent) then return end
            
            -- Wait a tick for the entity to be fully initialized
            timer.Simple(0, function()
                if not IsValid(ent) then return end
                
                -- Check for barnacles
                if ent:GetClass() == "npc_barnacle" then
                    local creator = nil
                    
                    -- Method 1: Check direct owner
                    if IsValid(ent:GetOwner()) and ent:GetOwner():IsPlayer() then
                        creator = ent:GetOwner()
                    end
                    
                    -- Method 2: Check activator (only if the method exists)
                    if not IsValid(creator) and ent.GetActivator and type(ent.GetActivator) == "function" then
                        local activator = ent:GetActivator()
                        if IsValid(activator) and activator:IsPlayer() then
                            creator = activator
                        end
                    end
                    
                    -- Method 3: Check for players who recently used the barnacle weapon
                    -- This is much more accurate than just finding the nearest player
                    if not IsValid(creator) then
                        local mostRecentTime = 0
                        local mostRecentUser = nil
                        
                        for user, time in pairs(recentBarnacleUsers) do
                            if IsValid(user) and time > mostRecentTime and CurTime() - time < 5 then
                                -- Only consider users who used the weapon in the last 5 seconds
                                mostRecentTime = time
                                mostRecentUser = user
                            end
                        end
                        
                        if IsValid(mostRecentUser) then
                            creator = mostRecentUser
                        end
                    end
                    
                    -- Method 4: Check for players with active barnacle weapons (backup)
                    if not IsValid(creator) then
                        for _, ply in ipairs(player.GetAll()) do
                            if IsValid(ply) then
                                local wep = ply:GetActiveWeapon()
                                if IsValid(wep) and wep:GetClass() == "weapon_ttt_barnacle" then
                                    creator = ply
                                    break
                                end
                            end
                        end
                    end
                    
                    -- If we found a creator, store the association
                    if IsValid(creator) then
                        barnacleOwners[ent:EntIndex()] = creator
                        ent.BarnacleOwner = creator
                        ent:SetNWEntity("BarnacleOwner", creator)
                    end
                end
                
                -- Also check for tongue entities
                if ent:GetClass() == "ttt2_barnacle_tongue" then
                    timer.Simple(0.1, function()
                        if not IsValid(ent) then return end
                        
                        local parent = ent:GetParent()
                        if IsValid(parent) and parent:GetClass() == "npc_barnacle" then
                            local owner = nil
                            if IsValid(parent.BarnacleOwner) then
                                owner = parent.BarnacleOwner
                            elseif barnacleOwners[parent:EntIndex()] then
                                owner = barnacleOwners[parent:EntIndex()]
                            end
                            
                            if IsValid(owner) then
                                ent.BarnacleOwner = owner
                                ent:SetNWEntity("BarnacleOwner", owner)
                            end
                        end
                    end)
                end
            end)
        end)
        
        -- Handle player damage from barnacles
        hook.Add("EntityTakeDamage", "BarnacleJesterDamageOverride", function(victim, dmginfo)
            if not victim:IsPlayer() then return end
            
            local attacker = dmginfo:GetAttacker()
            local inflictor = dmginfo:GetInflictor()
            
            -- Function to check and handle barnacle damage
            local function handleBarnacleAttribution(barnacle)
                if not IsValid(barnacle) then return false end
                
                -- Get owner from multiple possible sources
                local owner = nil
                
                if IsValid(barnacle.BarnacleOwner) then
                    owner = barnacle.BarnacleOwner
                elseif barnacleOwners[barnacle:EntIndex()] then
                    owner = barnacleOwners[barnacle:EntIndex()]
                elseif IsValid(barnacle:GetNWEntity("BarnacleOwner")) then
                    owner = barnacle:GetNWEntity("BarnacleOwner")
                end
                
                if IsValid(owner) and owner:IsPlayer() then
                    -- Apply proper attribution
                    dmginfo:SetAttacker(owner)
                    
                    -- Check for jester
                    if owner.GetTeam and type(owner.GetTeam) == "function" and owner:GetTeam() == TEAM_JESTER then
                        dmginfo:SetDamage(0)
                        return true
                    end
                    return true
                end
                return false
            end
            
            -- Check if attacker is barnacle
            if IsValid(attacker) and attacker:GetClass() == "npc_barnacle" then
                return handleBarnacleAttribution(attacker)
            end
            
            -- Check if inflictor is tongue
            if IsValid(inflictor) and inflictor:GetClass() == "ttt2_barnacle_tongue" then
                local parent = inflictor:GetParent()
                if IsValid(parent) then
                    return handleBarnacleAttribution(parent)
                end
                return handleBarnacleAttribution(inflictor)
            end
            
            -- Catch-all for any damage with "barnacle" in the class name
            if IsValid(attacker) and string.find(tostring(attacker:GetClass()), "barnacle") then
                return handleBarnacleAttribution(attacker)
            end
            if IsValid(inflictor) and string.find(tostring(inflictor:GetClass()), "barnacle") then
                return handleBarnacleAttribution(inflictor)
            end
        end, -5) -- Higher priority than default
    end)
    
    -- Clean up invalid entries to prevent memory leaks
    timer.Create("CleanupBarnacleOwners", 30, 0, function()
        for entIdx, owner in pairs(barnacleOwners) do
            local ent = Entity(entIdx)
            if not IsValid(ent) or not IsValid(owner) then
                barnacleOwners[entIdx] = nil
            end
        end
        
        -- Also clean up recent users table
        for user, time in pairs(recentBarnacleUsers) do
            if not IsValid(user) or CurTime() - time > 60 then
                recentBarnacleUsers[user] = nil
            end
        end
    end)
end