-- Banana Health Fix
-- This fixes the banana reducing health when player has above max health

-- Helper function to apply the fix to a weapon
local function ApplyBananaFix(weaponTable)
    if not weaponTable or not weaponTable.Consume then return false end
    
    -- Replace with our fixed version
    weaponTable.Consume = function(self)
        local healAmount = GetConVar("banana_heal"):GetInt()
        local ply = self:GetOwner()
        
        -- Only heal if health is below max health
        if ply:Health() < ply:GetMaxHealth() then
            ply:SetHealth(math.Clamp(ply:Health() + healAmount, 0, ply:GetMaxHealth()))
        end
        -- Otherwise do nothing (leave health unchanged)
        
        self:Remove()
    end
    
    return true
end

hook.Add("InitPostEntity", "BananaHealthFix_Setup", function()
    timer.Simple(2, function()
        -- Get both banana weapon classes
        local bananaWeaponTable = weapons.GetStored("ttt_banana")
        local ragnanaWeaponTable = weapons.GetStored("ttt_ragnana")
        
        if bananaWeaponTable then
            ApplyBananaFix(bananaWeaponTable)
        end
        
        if ragnanaWeaponTable then
            ApplyBananaFix(ragnanaWeaponTable)
        end
    end)
end)

-- Create a hook for the case where the weapon is created after our initial patch
hook.Add("WeaponEquip", "BananaHealthFix_LatePatch", function(weapon)
    local weaponClass = weapon:GetClass()
    
    if (weaponClass == "ttt_banana" or weaponClass == "ttt_ragnana") and weapon.Consume then
        -- Check if it's already patched by looking at the function code
        if string.find(string.dump(weapon.Consume), "ply:Health() < ply:GetMaxHealth()") then
            return -- Already patched
        end
        
        -- Apply our fix directly to this instance
        weapon.Consume = function(self)
            local healAmount = GetConVar("banana_heal"):GetInt()
            local ply = self:GetOwner()
            
            -- Only heal if health is below max health
            if ply:Health() < ply:GetMaxHealth() then
                ply:SetHealth(math.Clamp(ply:Health() + healAmount, 0, ply:GetMaxHealth()))
            end
            -- Otherwise do nothing (leave health unchanged)
            
            self:Remove()
        end
    end
end)