-- Eagle Flight Gun Holdtype Override
-- This ensures the Eagle Flight gun uses the "revolver" holdtype animation instead of pistol
-- Credit: Snuffles the Fox

-- Wait until the game is fully initialized
hook.Add("InitPostEntity", "EagleFlightGun_HoldTypeOverride", function()
    -- Small delay to ensure the weapon is fully registered
    timer.Simple(1, function()
        -- Get the stored weapon table
        local weapon = weapons.GetStored("ttt_weapon_eagleflightgun")
        
        -- Check if the weapon exists
        if weapon then
            -- Override the hold type
            weapon.HoldType = "revolver"
        end
    end)
end)