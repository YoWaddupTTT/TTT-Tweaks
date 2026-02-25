-- Ensures suicide bomb users always die to their own explosion
-- even if they have explosion resistance

if SERVER then
    local suicideBombUsers = {}
    
    hook.Add("Think", "TrackSuicideBombUsers", function()
        for _, ply in ipairs(player.GetAll()) do
            if not IsValid(ply) then continue end
            
            local wep = ply:GetActiveWeapon()
            if IsValid(wep) and wep:GetClass() == "weapon_ttt_suicide" then
                if wep:GetNextPrimaryFire() > CurTime() then
                    suicideBombUsers[ply] = CurTime() + 3
                end
            end
        end
        
        for ply, expireTime in pairs(suicideBombUsers) do
            if not IsValid(ply) or expireTime < CurTime() then
                suicideBombUsers[ply] = nil
            end
        end
    end)
    
    hook.Add("EntityTakeDamage", "SuicideBombResistNerf", function(target, dmginfo)
        if not IsValid(target) or not target:IsPlayer() or not dmginfo:IsExplosionDamage() then
            return
        end

        local attacker = dmginfo:GetAttacker()
        
        if IsValid(attacker) and attacker == target and suicideBombUsers[target] then
            if target:HasEquipmentItem("item_ttt_noexplosiondmg") then
                timer.Simple(0, function()
                    if IsValid(target) and target:Alive() then
                        target:Kill()
                        suicideBombUsers[target] = nil
                    end
                end)
            else
                suicideBombUsers[target] = nil
            end
        end
    end)
end
