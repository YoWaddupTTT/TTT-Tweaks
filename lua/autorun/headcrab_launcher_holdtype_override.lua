-- Headcrab Launcher HoldType Fix
-- This ensures the headcrab launcher uses the "revolver" holdtype animation instead of pistol

-- Common function for both client and server
local function FixHeadcrabHoldType(weapon)
    if IsValid(weapon) and weapon:GetClass() == "weapon_ttt_headlauncher" then
        -- Force the holdtype to revolver and explicitly call SetHoldType
        weapon.HoldType = "revolver"
        weapon:SetHoldType("revolver")
    end
end

-- Initial patch when the game loads
hook.Add("InitPostEntity", "HeadcrabLauncher_HoldTypeOverride", function()
    -- Small delay to ensure the weapon is fully registered
    timer.Simple(1, function()
        -- Get the stored weapon table
        local weaponTable = weapons.GetStored("weapon_ttt_headlauncher")
        
        -- Check if the weapon exists and patch it
        if weaponTable then
            -- Patch the prototype
            weaponTable.HoldType = "revolver"
            
            -- Override the Deploy function to fix the holdtype when drawn
            local originalDeploy = weaponTable.Deploy
            weaponTable.Deploy = function(self, ...)
                -- Call the original deploy function
                local result = true
                if originalDeploy then
                    result = originalDeploy(self, ...)
                end
                
                -- Force the holdtype to revolver
                self.HoldType = "revolver"
                self:SetHoldType("revolver")
                
                return result
            end
            
            -- Override the Initialize function to set the holdtype
            local originalInit = weaponTable.Initialize
            weaponTable.Initialize = function(self, ...)
                -- Call the original init function
                if originalInit then
                    originalInit(self, ...)
                end
                
                -- Set the holdtype after initialization
                self.HoldType = "revolver"
                self:SetHoldType("revolver")
            end
        end
    end)
end)

-- Fix holdtype for newly created weapons
hook.Add("PlayerSwitchWeapon", "HeadcrabLauncher_HoldTypeOverride_Switch", function(ply, oldWeapon, newWeapon)
    if IsValid(newWeapon) and newWeapon:GetClass() == "weapon_ttt_headlauncher" then
        -- Apply fix immediately
        FixHeadcrabHoldType(newWeapon)
        
        -- Also apply after a delay to catch late changes
        timer.Simple(0.1, function()
            if IsValid(newWeapon) then
                FixHeadcrabHoldType(newWeapon)
            end
        end)
    end
end)

-- Client-specific fixes for networked weapons
if CLIENT then
    hook.Add("NetworkEntityCreated", "HeadcrabLauncher_HoldTypeOverride_Client", function(ent)
        if IsValid(ent) and ent:GetClass() == "weapon_ttt_headlauncher" then
            -- Fix when the weapon is first created on the client
            timer.Simple(0, function()
                if IsValid(ent) then
                    FixHeadcrabHoldType(ent)
                end
            end)
        end
    end)
end