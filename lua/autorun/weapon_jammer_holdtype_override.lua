-- Weapon Jammer HoldType Fix
-- This ensures the jammer uses the "normal" holdtype animation instead of pistol
-- Credit: Snuffles the Fox

-- Common function for both client and server
local function FixJammerHoldType(weapon)
    if IsValid(weapon) and weapon:GetClass() == "weapon_ttt_wpnjammer" then
        -- Force the holdtype to normal and explicitly call SetHoldType
        weapon.HoldType = "normal"
        weapon:SetHoldType("normal")
    end
end

-- Initial patch when the game loads
hook.Add("InitPostEntity", "WeaponJammer_HoldTypeOverride", function()
    -- Small delay to ensure the weapon is fully registered
    timer.Simple(1, function()
        -- Get the stored weapon table
        local weaponTable = weapons.GetStored("weapon_ttt_wpnjammer")
        
        -- Check if the weapon exists and patch it
        if weaponTable then
            -- Patch the prototype
            weaponTable.HoldType = "normal"
            
            -- Override the Deploy function to fix the holdtype when drawn
            local originalDeploy = weaponTable.Deploy
            weaponTable.Deploy = function(self, ...)
                -- Call the original deploy function
                local result = true
                if originalDeploy then
                    result = originalDeploy(self, ...)
                end
                
                -- Force the holdtype to normal
                self.HoldType = "normal"
                self:SetHoldType("normal")
                
                return result
            end
            
            -- Override the Initialize function to set the holdtype
            local originalInit = weaponTable.Initialize
            weaponTable.Initialize = function(self, ...)
                if originalInit then
                    originalInit(self, ...)
                end
                
                -- Set the holdtype after initialization
                self.HoldType = "normal"
                self:SetHoldType("normal")
            end
        end
    end)
end)

-- Fix holdtype for newly created weapons
hook.Add("PlayerSwitchWeapon", "WeaponJammer_HoldTypeOverride_Switch", function(ply, oldWeapon, newWeapon)
    if IsValid(newWeapon) and newWeapon:GetClass() == "weapon_ttt_wpnjammer" then
        -- Apply fix immediately
        FixJammerHoldType(newWeapon)
        
        -- Also apply after a delay to catch late changes
        timer.Simple(0.1, function()
            if IsValid(newWeapon) then
                FixJammerHoldType(newWeapon)
            end
        end)
    end
end)

-- Client-specific fixes for networked weapons
if CLIENT then
    hook.Add("NetworkEntityCreated", "WeaponJammer_HoldTypeOverride_Client", function(ent)
        if IsValid(ent) and ent:GetClass() == "weapon_ttt_wpnjammer" then
            -- Fix when the weapon is first created on the client
            timer.Simple(0, function()
                if IsValid(ent) then
                    FixJammerHoldType(ent)
                end
            end)
        end
    end)
end