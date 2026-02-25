-- YoWaddup Holdtype Fixes
-- Consolidation of various holdtype animation fixes that were largely the same code
-- Credit: Snuffles the Fox (consolidation by Spanospy)

local HOLDTYPE_REVOLVER = "revolver"
local HOLDTYPE_PISTOL = "pistol"

local HOLDTYPE_OVERRIDES = {
    "dancedead" = HOLDTYPE_REVOLVER,
    "weapon_ttt_dete_playercam" = HOLDTYPE_REVOLVER,
    "ttt_weapon_eagleflightgun" = HOLDTYPE_REVOLVER,
    "weapon_ttt_freezegun" = HOLDTYPE_REVOLVER,
    "weapon_ttt_prop_disguiser" = HOLDTYPE_PISTOL,
    "weapon_ttt_revolver" = HOLDTYPE_REVOLVER
}

-- Wait until the game is fully initialized
hook.Add("InitPostEntity", "YoWaddup_HoldTypeOverrides", function()
    -- Small delay to ensure the weapons are fully registered
    timer.Simple(1, function()
    
		for weaponName, NewHoldType in pairs(HOLDTYPE_OVERRIDES) do
            -- Get the stored weapon table
            local weapon = weapons.GetStored(weaponName)
        
            -- Check if the weapon exists
            if weapon then
                -- Override the hold type
                weapon.HoldType = NewHoldType
            end
        end
    end)
end)