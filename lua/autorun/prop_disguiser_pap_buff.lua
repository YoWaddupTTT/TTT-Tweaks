-- Fix for Pack-a-Punch Prop Disguiser to remove taunt sounds
-- This keeps the infinite timer but eliminates the noise
-- Credit: Snuffles the Fox

-- Direct hook to intercept weapon pickup
hook.Add("WeaponEquip", "SilentPAPDisguiser", function(weapon, owner)
    -- Check if this is a PAP'd prop disguiser
    if IsValid(weapon) and weapon:GetClass() == "weapon_ttt_prop_disguiser" and weapon.IsPAPUpgraded then
        -- Wait a tick to make sure weapon is fully initialized
        timer.Simple(0, function()
            if not IsValid(weapon) then return end
            
            -- Check if this is already our modified version
            if weapon.IsSilentPAPDisguiser then return end
            
            -- Mark as modified
            weapon.IsSilentPAPDisguiser = true
            
            -- Store original function if it exists
            if weapon.PropDisguise then
                weapon.OriginalPropDisguise = weapon.PropDisguise
                
                -- Replace with our silent version
                weapon.PropDisguise = function(self)
                    -- Set disguise time to effectively infinity
                    local oldTime = GetGlobalInt("ttt_prop_disguiser_time")
                    SetGlobalInt("ttt_prop_disguiser_time", 99999)
                    
                    -- Call original but prepare to clean up after
                    self:OriginalPropDisguise()
                    
                    -- Restore original time
                    SetGlobalInt("ttt_prop_disguiser_time", oldTime)
                    
                    -- Clean up any taunt timers
                    if SERVER and IsValid(owner) then
                        timer.Simple(0.1, function()
                            local timername = "TTTPAPInfiniteDisguiser" .. owner:SteamID64()
                            if timer.Exists(timername) then
                                timer.Remove(timername)
                            end
                        end)
                    end
                end
            end
        end)
    end
end)

-- Also hook player disguise state for extra safety
hook.Add("TTTPAPPlayerDisguised", "SilentPAPDisguiser", function(ply)
    if SERVER and IsValid(ply) then
        timer.Simple(0.1, function()
            local timername = "TTTPAPInfiniteDisguiser" .. ply:SteamID64()
            if timer.Exists(timername) then
                timer.Remove(timername)
            end
        end)
    end
end)

-- Global timer killer - check every 2 seconds for taunt timers and remove them
timer.Create("SilentPAPDisguiser_CleanupTimers", 2, 0, function()
    if SERVER then
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) then
                local timername = "TTTPAPInfiniteDisguiser" .. ply:SteamID64()
                if timer.Exists(timername) then
                    timer.Remove(timername)
                end
            end
        end
    end
end)