-- S&W 500 Holdtype Override
-- This ensures the S&W 500 uses the "revolver" holdtype animation instead of pistol
-- Credit: Snuffles the Fox

-- Wait until the game is fully initialized
hook.Add("InitPostEntity", "S&W_HoldTypeOverride", function()
    -- Small delay to ensure the weapon is fully registered
    timer.Simple(1, function()
        -- Get the stored weapon table
        local weapon = weapons.GetStored("weapon_ttt_revolver")
        
        -- Check if the weapon exists
        if weapon then
            -- Override the hold type
            weapon.HoldType = "revolver"
        end
    end)
end)