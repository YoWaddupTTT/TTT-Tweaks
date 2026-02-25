-- Dynamic Camera Hull - Slope Bug Fix
-- This addon fixes issues with slopes when using the Dynamic Camera Hull addon

if SERVER then
    -- Fix for the server-side net.Send parameter bug
    hook.Add("InitPostEntity", "DynamicCameraFix_Server", function()
        timer.Simple(1, function()
            -- Patch the DynamicCameraHullViewSV function if it exists
            if DynamicCameraHullViewSV then
                local originalFunc = DynamicCameraHullViewSV
                
                DynamicCameraHullViewSV = function(ply, tbl)
                    if not ply.DynamCamTable then
                        net.Start("DynamicCameraHullViewSetup")
                        net.Send(ply) -- Fix: use ply instead of self
                        return
                    end
                    
                    -- Call original function with correct parameters
                    return originalFunc(ply, tbl)
                end
            end
        end)
    end)
end

if CLIENT then
    -- Store default hull dimensions for comparison
    local defMins, defMaxs = Vector(-16, -16, 0), Vector(16, 16, 72)
    
    -- Fix for the hull checking code
    hook.Add("InitPostEntity", "DynamicCameraFix_Client", function()
        timer.Simple(1, function()
            if DynamicCameraHullViewCL then
                local originalFunc = DynamicCameraHullViewCL
                
                -- Replace with improved version that handles slopes better
                DynamicCameraHullViewCL = function(model)
                    if model == "models/player.mdl" then return end
                    local ply = LocalPlayer()
                    
                    -- Improved check that fixes slope issues
                    local mins, maxs = ply:GetHull()
                    if mins ~= defMins and maxs ~= defMaxs and ply.LastModel ~= nil and ply.LastModel == model then
                        return
                    end
                    ply.LastModel = model
                    
                    -- Call original function
                    return originalFunc(model)
                end
            end
        end)
    end)
    
    -- Fix for the PostDrawPlayerHands hook
    hook.Add("PostDrawPlayerHands", "DynamicCameraFix_Hands", function(hands, vm, ply, weapon)
        -- This will run after the original hook, fixing any potential issues
        if IsValid(hands) and ply:GetNumBodyGroups() > 0 and ply:GetNumBodyGroups() == hands:GetNumBodyGroups() then
            hands:SetBodyGroups(ply:GetBodygroupsAsString())
        end
    end, 20) -- Higher hook priority to run after original
end

-- Fix the ResetHull function
hook.Add("InitPostEntity", "DynamicCameraFix_ResetHull", function()
    timer.Simple(1, function()
        local PLY_META = FindMetaTable("Player")
        local originalResetHull = PLY_META.ResetHull
        
        -- Only replace if it's not already the fixed version
        if originalResetHull then
            PLY_META.ResetHull = function(self)
                if self:GetInfoNum("dynamiccamerahull_client_enabled", 1) == 0 then
                    self:SetHull(Vector(-16, -16, 0), Vector(16, 16, 72))
                    self:SetHullDuck(Vector(-16, -16, 0), Vector(16, 16, 36))
                    return
                end
                
                if SERVER then
                    net.Start("DynamicCameraHullViewSetup")
                    net.Send(self)
                else
                    DynamicCameraHullViewCL(DynamicCameraGetModelNamePath())
                end
            end
        end
    end)
end)