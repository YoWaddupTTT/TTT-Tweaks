-- LaserHuge HoldType Fix
-- This fixes the holdtype for the LaserHuge weapon to use crossbow animations
-- Credit: Snuffles the Fox

-- Common parts shared between client and server
local function SetLaserHoldType(weapon)
    if IsValid(weapon) and weapon:GetClass() == "ttt_laser_bullet" then
        weapon.HoldType = "crossbow"
        weapon:SetHoldType("crossbow")
    end
end

if SERVER then
    -- Track if we've already patched the weapon
    local hasPatched = false
    
    -- Server-side weapon patching
    hook.Add("PlayerSwitchWeapon", "LaserHuge_HoldTypeOverride_Server", function(ply, oldWeapon, newWeapon)
        if IsValid(newWeapon) and newWeapon:GetClass() == "ttt_laser_bullet" then
            SetLaserHoldType(newWeapon)
            
            -- Also apply after a small delay to catch any resets
            timer.Simple(0.1, function()
                if IsValid(newWeapon) then
                    SetLaserHoldType(newWeapon)
                end
            end)
        end
    end)
    
    -- Patch the weapon table itself when it becomes available
    hook.Add("InitPostEntity", "LaserHuge_HoldTypePatch", function()
        -- Try to patch once at start
        if not hasPatched then
            timer.Simple(1, function()
                local weaponTable = weapons.GetStored("ttt_laser_bullet")
                if weaponTable then
                    -- Modify the weapon prototype table
                    weaponTable.HoldType = "crossbow"
                    
                    -- Patch the Initialize method to set holdtype
                    local originalInit = weaponTable.Initialize
                    weaponTable.Initialize = function(self, ...)
                        if originalInit then
                            originalInit(self, ...)
                        end
                        
                        -- Set holdtype after original init
                        self.HoldType = "crossbow"
                        self:SetHoldType("crossbow")
                    end
                    
                    -- Also patch Deploy to ensure holdtype is set when weapon is drawn
                    local originalDeploy = weaponTable.Deploy
                    weaponTable.Deploy = function(self, ...)
                        local result = true
                        if originalDeploy then
                            result = originalDeploy(self, ...)
                        end
                        
                        -- Set holdtype after original deploy
                        self.HoldType = "crossbow"
                        self:SetHoldType("crossbow")
                        
                        return result
                    end
                    
                    hasPatched = true
                end
            end)
        end
    end)
    
    -- Check for existing weapons when this script loads (for hot reloading)
    timer.Simple(0, function()
        for _, weapon in ipairs(ents.FindByClass("ttt_laser_bullet")) do
            SetLaserHoldType(weapon)
        end
    end)
end

if CLIENT then
    -- Client-side weapon patching
    -- We don't call SetupHands here to avoid errors
    
    -- Hook into weapon deployment on client
    hook.Add("PlayerSwitchWeapon", "LaserHuge_HoldTypeOverride_Client", function(ply, oldWeapon, newWeapon)
        if IsValid(newWeapon) and newWeapon:GetClass() == "ttt_laser_bullet" then
            SetLaserHoldType(newWeapon)
            
            -- Also apply after a small delay to catch any resets
            timer.Simple(0.1, function()
                if IsValid(newWeapon) then
                    SetLaserHoldType(newWeapon)
                end
            end)
        end
    end)
    
    -- Hook into weapon creation to catch client-side weapons
    hook.Add("NetworkEntityCreated", "LaserHuge_ClientFixHoldType", function(ent)
        if IsValid(ent) and ent:GetClass() == "ttt_laser_bullet" then
            -- Wait a tick to ensure the weapon is fully initialized
            timer.Simple(0, function()
                if IsValid(ent) then
                    SetLaserHoldType(ent)
                end
            end)
        end
    end)
end