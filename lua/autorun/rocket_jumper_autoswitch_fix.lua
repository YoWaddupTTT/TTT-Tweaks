-- Rocket Jumper Auto-Switch Fix
-- Prevents automatically switching to the rocket jumper when acquired
-- Credit: Snuffles the Fox

if SERVER then
    AddCSLuaFile()
end

-- Function to override the Equip method
local function OverrideRocketJumper()
    local weapon = weapons.GetStored("weapon_ttt_rocket_jumper")
    
    if weapon then
        -- Store the original Equip function
        weapon.OriginalEquip = weapon.Equip
        
        -- Override the Equip function to not auto-select
        weapon.Equip = function(self, ply)
            -- Do nothing, don't call SelectWeapon
            -- We're just completely replacing this function
        end
        return true
    end
    
    return false
end

-- Hook into initialization to ensure the weapon is overridden
hook.Add("InitPostEntity", "RocketJumper_AutoSwitchFix", function()
    timer.Simple(1, function()
    end)
end)

-- Additional hook to catch late-registered weapons
hook.Add("Think", "RocketJumper_AutoSwitchWatchdog", function()
    if OverrideRocketJumper() then
        -- Successfully overrode, remove this watchdog hook
        hook.Remove("Think", "RocketJumper_AutoSwitchWatchdog")
    end
end)