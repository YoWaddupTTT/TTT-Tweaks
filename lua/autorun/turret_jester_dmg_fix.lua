-- TTT Turret Jester Fix
-- This prevents turrets placed by players on TEAM_JESTER from damaging other players
-- Credit: Snuffles the Fox

if SERVER then
    -- Wait until the game is fully loaded
    hook.Add("InitPostEntity", "FixTurretJesterDamage", function()
        -- Create a hook with higher priority (lower number) than the original
        hook.Add("EntityTakeDamage", "TurretJesterDamageOverride", function(victim, dmginfo)
            -- Check if it's damage from a turret to a player
            if victim:IsPlayer() and IsValid(dmginfo:GetInflictor()) and dmginfo:GetInflictor():GetClass() == "npc_turret_floor" then
                local turret = dmginfo:GetInflictor()
                local turretOwner = turret:GetOwner()
                
                -- If the turret has a valid owner who is on TEAM_JESTER
                if IsValid(turretOwner) and turretOwner:IsPlayer() and turretOwner:GetTeam() == TEAM_JESTER then
                    -- Prevent all damage from this turret
                    dmginfo:ScaleDamage(0)
                    dmginfo:SetDamage(0)
                    return true
                end
            end
        end, -5) -- Higher priority than default (0)
        
        -- We also need to make sure the turret properly stores its owner
        hook.Add("OnEntityCreated", "TrackTurretOwners", function(ent)
            if ent:GetClass() == "npc_turret_floor" then
                -- Wait until next tick to ensure entity is fully initialized
                timer.Simple(0, function()
                    if IsValid(ent) then
                        -- Store original owner data in case SetOwner gets overwritten later
                        local owner = ent:GetOwner()
                        if IsValid(owner) then
                            ent.OriginalOwner = owner
                        end
                    end
                end)
            end
        end)
        
        -- Add a check to the original TurretDamage hook to use OriginalOwner if needed
        hook.Add("EntityTakeDamage", "TurretJesterDamageBackup", function(victim, dmginfo)
            if victim:IsPlayer() and IsValid(dmginfo:GetInflictor()) and dmginfo:GetInflictor():GetClass() == "npc_turret_floor" then
                local turret = dmginfo:GetInflictor()
                local turretOwner = turret:GetOwner()
                
                -- If turret has no owner but has original owner stored
                if (!IsValid(turretOwner) or !turretOwner:IsPlayer()) and IsValid(turret.OriginalOwner) and turret.OriginalOwner:IsPlayer() then
                    -- If original owner is jester, prevent damage
                    if turret.OriginalOwner:GetTeam() == TEAM_JESTER then
                        dmginfo:ScaleDamage(0)
                        dmginfo:SetDamage(0)
                        return true
                    end
                end
            end
        end, -10) -- Even higher priority
    end)
end