-- Barnacle Marker Vision Integration
-- Replaces the barnacle's custom warning system with TTT2's marker vision

if SERVER then
    AddCSLuaFile()
    
    hook.Add("Initialize", "DisableBarnacleOriginalWarning", function()
        if SendWarn then
            SendWarn = function(armed, enti) end
        end
    end)
    
    hook.Add("OnEntityCreated", "BarnacleMarkerVision", function(ent)
        timer.Simple(0, function()
            if not IsValid(ent) or ent:GetClass() ~= "npc_barnacle" then return end
            
            timer.Simple(0.1, function()
                if not IsValid(ent) then return end
                
                local owner = ent:GetNWEntity('owner')
                if not IsValid(owner) or not owner:IsPlayer() then return end
                
                local mvObject = ent:AddMarkerVision("barnacle_trap")
                if not mvObject then return end
                
                mvObject:SetOwner(owner)
                mvObject:SetVisibleFor(VISIBLE_FOR_TEAM)
                mvObject:SetColor(Color(255, 100, 100, 255))
                mvObject:SyncToClients()
                
                local checkTimer = "BarnacleMarkerVision_" .. ent:EntIndex()
                timer.Create(checkTimer, 0.5, 0, function()
                    if not IsValid(ent) or ent:Health() <= 0 then
                        timer.Remove(checkTimer)
                        
                        if IsValid(ent) then
                            ent:RemoveMarkerVision("barnacle_trap")
                        end
                    end
                end)
            end)
        end)
    end)
end

if CLIENT then
    hook.Add("Initialize", "DisableBarnacleOriginalWarningClient", function()
        if net then
            net.Receive("TTT2_BarnacleWarning", function() end)
        end
    end)
    
    hook.Add("TTT2RenderMarkerVisionInfo", "BarnacleMarkerVisionDisplay", function(mvData)
        local ent = mvData:GetEntity()
        if not IsValid(ent) or ent:GetClass() ~= "npc_barnacle" then return end
        
        local mvObject = mvData:GetMarkerVisionObject()
        if not mvObject or mvObject:GetIdentifier() ~= "barnacle_trap" then return end
        
        mvData:EnableText(true)
        
        mvData:AddIcon(Material("vgui/ttt/icon_barnacle_fairer_ttt2"), mvObject:GetColor())
        
        mvData:SetTitle("BARNACLE TRAP", mvObject:GetColor())
        
        local distance = math.Round(mvData:GetEntityDistance())
        mvData:AddDescriptionLine("Distance: " .. distance .. " units", COLOR_WHITE)
        
        local owner = ent:GetNWEntity('owner')
        if IsValid(owner) and owner:IsPlayer() then
            mvData:SetSubtitle("Placed by: " .. owner:Nick(), COLOR_LGRAY)
        end
        
        mvData:SetCollapsedLine("Barnacle: " .. distance .. "u", mvObject:GetColor())
    end)
end
