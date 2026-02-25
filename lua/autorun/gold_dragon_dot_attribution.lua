-- Gold Dragon fire damage attribution fix
-- This ensures that fire damage from the Gold Dragon is properly attributed to the shooter
-- and prevents damage if shooter is a Jester
-- Credit: Snuffles the Fox

if SERVER then
    -- Hook into the damage event to modify fire damage attribution
    hook.Add("EntityTakeDamage", "GoldDragon_FireDamageAttribution", function(victim, dmginfo)
        -- Check if this is fire damage
        if dmginfo:IsDamageType(DMG_BURN) then
            -- Check if the victim has stored ignite information
            if IsValid(victim) and victim.ignite_info then
                local attacker = victim.ignite_info.att
                local inflictor = victim.ignite_info.infl
                
                -- Make sure attacker and inflictor are still valid
                if IsValid(attacker) and IsValid(inflictor) then
                    -- Check if the attacker is a Jester
                    if IsValid(attacker) and attacker:IsPlayer() and attacker:GetTeam() == TEAM_JESTER then
                        -- Block all damage from Jester's fire
                        dmginfo:ScaleDamage(0)
                        dmginfo:SetDamage(0)
                        return true
                    end
                    
                    -- Check if marked player hitting marker with fire
                    if IsValid(attacker) and attacker:IsPlayer() and IsValid(victim) and victim:IsPlayer() then
                        if MARKER_DATA and MARKER_DATA.IsMarked and victim:GetTeam() == TEAM_MARKER and MARKER_DATA:IsMarked(attacker) then
                            -- Block all damage from marked player to marker
                            dmginfo:ScaleDamage(0)
                            dmginfo:SetDamage(0)
                            return true
                        end
                    end
                
                    -- Override the damage attribution
                    dmginfo:SetAttacker(attacker)
                    dmginfo:SetInflictor(inflictor)
                end
            end
        end
    end)
    
    -- Apply additional hooks when the weapon is initialized
    hook.Add("Initialize", "GoldDragon_InitOverride", function()
        -- Find and enhance the weapon if it exists
        if weapons.GetStored("weapon_ap_golddragon") then
            local SWEP = weapons.GetStored("weapon_ap_golddragon")
            
            -- Store the original IgniteTarget function
            local originalIgniteTarget = IgniteTarget
            
            -- Override the IgniteTarget function to provide better tracking
            function IgniteTarget(att, path, dmginfo)
                -- Check if the attacker is a Jester
                local attacker = dmginfo:GetAttacker()
                if IsValid(attacker) and attacker:IsPlayer() and attacker:GetTeam() == TEAM_JESTER then
                    -- Jesters still set entities on fire visually but no damage
                    local ent = path.Entity
                    if IsValid(ent) and SERVER then
                        -- Store the jester info for visual effects but no damage
                        ent.ignite_info = {
                            att = attacker,
                            infl = dmginfo:GetInflictor(),
                            weapon = "weapon_ap_golddragon",
                            is_jester = true
                        }
                        
                        -- Visual fire effect without damage
                        if ent:IsPlayer() then
                            ent:Ignite(5, 0) -- Duration but zero damage
                        else
                            ent:Ignite(10, 0) -- Duration but zero damage
                        end
                        return
                    end
                end
                
                -- Call original function for non-Jesters
                originalIgniteTarget(att, path, dmginfo)
                
                -- Enhanced tracking for non-Jesters
                local ent = path.Entity
                if IsValid(ent) and SERVER then
                    -- Store more detailed information
                    ent.ignite_info = {
                        att = dmginfo:GetAttacker(),
                        infl = dmginfo:GetInflictor(),
                        weapon = "weapon_ap_golddragon"
                    }
                end
            end
        end
    end)
end