-- SLAM Marker Vision Integration
-- Replaces the SLAM's custom warning system with TTT2's marker vision

if SERVER then
    AddCSLuaFile()
    
    hook.Add("Initialize", "DisableSLAMOriginalWarning", function()
        timer.Simple(0, function()
            local slamBaseMeta = scripted_ents.GetStored("ttt_slam_base")
            if slamBaseMeta and slamBaseMeta.t then
                slamBaseMeta.t.SendWarn = function(self, armed) end
            end
        end)
    end)
    
    hook.Add("OnEntityCreated", "SLAMMarkerVision", function(ent)
        timer.Simple(0, function()
            if not IsValid(ent) then return end
            
            local class = ent:GetClass()
            if not string.match(class, "^ttt_slam_") then return end
            
            timer.Simple(0.1, function()
                if not IsValid(ent) then return end
                
                local owner = ent:GetPlacer()
                if not IsValid(owner) or not owner:IsPlayer() then return end
                
                local mvObject = ent:AddMarkerVision("slam_trap")
                if not mvObject then return end
                
                mvObject:SetOwner(owner)
                mvObject:SetVisibleFor(VISIBLE_FOR_TEAM)
                mvObject:SetColor(Color(255, 100, 100, 255))
                mvObject:SyncToClients()
                
                local checkTimer = "SLAMMarkerVision_" .. ent:EntIndex()
                timer.Create(checkTimer, 0.5, 0, function()
                    if not IsValid(ent) then
                        timer.Remove(checkTimer)
                    end
                end)
                
                ent:CallOnRemove("SLAMMarkerVisionCleanup", function()
                    if IsValid(ent) then
                        ent:RemoveMarkerVision("slam_trap")
                    end
                    timer.Remove(checkTimer)
                end)
            end)
        end)
    end)
end

if CLIENT then
    hook.Add("Initialize", "DisableSLAMOriginalWarningClient", function()
        if net then
            net.Receive("TTT_SLAMWarning", function() end)
        end
    end)
    
    hook.Add("TTT2RenderMarkerVisionInfo", "SLAMMarkerVisionDisplay", function(mvData)
        local ent = mvData:GetEntity()
        if not IsValid(ent) then return end
        
        local class = ent:GetClass()
        if not string.match(class, "^ttt_slam_") then return end
        
        local mvObject = mvData:GetMarkerVisionObject()
        if not mvObject or mvObject:GetIdentifier() ~= "slam_trap" then return end
        
        mvData:EnableText(true)
        
        mvData:AddIcon(Material("vgui/ttt/icon_slam"), mvObject:GetColor())
        
        mvData:SetTitle("SLAM", mvObject:GetColor())
        
        local distance = math.Round(mvData:GetEntityDistance())
        mvData:AddDescriptionLine("Distance: " .. distance .. " units", COLOR_WHITE)
        
        local owner = mvObject:GetOwner()
        if IsValid(owner) and owner:IsPlayer() then
            mvData:SetSubtitle("Placed by: " .. owner:Nick(), COLOR_LGRAY)
        end
        
        mvData:SetCollapsedLine("SLAM: " .. distance .. "u", mvObject:GetColor())
    end)
end
