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