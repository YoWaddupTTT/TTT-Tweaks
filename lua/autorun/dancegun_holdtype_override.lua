-- Dance Gun Holdtype Override
-- This ensures the dance gun uses the "revolver" holdtype animation instead of pistol
-- Credit: Snuffles the Fox

-- Wait until the game is fully initialized
hook.Add("InitPostEntity", "DanceGun_HoldTypeOverride", function()
    -- Small delay to ensure the weapon is fully registered
    timer.Simple(1, function()
        -- Get the stored weapon table
        local weapon = weapons.GetStored("dancedead")
        
        -- Check if the weapon exists
        if weapon then
            -- Override the hold type
            weapon.HoldType = "revolver"
        end
    end)
end)