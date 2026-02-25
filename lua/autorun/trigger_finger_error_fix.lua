-- Fix for the Nick() error in sv_traitor_chip.lua
-- Credit: Snuffles the Fox

hook.Add("InitPostEntity", "TriggerFingerChip_ErrorFix", function()
    if SERVER then
        local originalDoDamage = hook.GetTable()["EntityTakeDamage"]["traitorchip_damage"]
        
        if originalDoDamage then
            hook.Remove("EntityTakeDamage", "traitorchip_damage")
            
            hook.Add("EntityTakeDamage", "traitorchip_damage", function(pl, dmgInfo)
                local attacker = dmgInfo:GetAttacker()
                if IsValid(attacker) and attacker.isChipControlled then
                    local controller = attacker.controlledBy
                    if IsValid(controller) and IsValid(pl) and pl:IsPlayer() then
                        -- Use PrintMessage instead of DamageLog with timer
                        controller:PrintMessage(HUD_PRINTTALK, "Controlling " .. attacker:Nick() .. " to attack " .. pl:Nick())
                    end
                end
            end)
        end
    end
end)