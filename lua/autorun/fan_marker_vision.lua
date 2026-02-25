-- Fan Marker Vision Integration
-- Replaces the fan's custom text display with TTT2's marker vision while keeping the range line
-- Credit: Snuffles the Fox

if SERVER then
    AddCSLuaFile()
    
    hook.Add("OnEntityCreated", "FanMarkerVision", function(ent)
        timer.Simple(0, function()
            if not IsValid(ent) or ent:GetClass() ~= "ent_ttt_fan" then return end
            
            timer.Simple(0.1, function()
                if not IsValid(ent) then return end
                
                local owner = ent.Owner
                if not IsValid(owner) or not owner:IsPlayer() then return end
                
                local mvObject = ent:AddMarkerVision("fan_trap")
                if not mvObject then return end
                
                mvObject:SetOwner(owner)
                mvObject:SetVisibleFor(VISIBLE_FOR_TEAM)
                mvObject:SetColor(Color(255, 100, 100, 255))
                mvObject:SyncToClients()
                
                ent:CallOnRemove("FanMarkerVisionCleanup", function()
                    if IsValid(ent) then
                        ent:RemoveMarkerVision("fan_trap")
                    end
                end)
            end)
        end)
    end)
end

if CLIENT then
    hook.Add("Initialize", "DisableFanOriginalTextDisplay", function()
        timer.Simple(0, function()
            local fanMeta = scripted_ents.GetStored("ent_ttt_fan")
            if fanMeta and fanMeta.t then
                fanMeta.t.Initialize = function(self)
                    local color = Color(206, 0, 0)
                    
                    hook.Add("HUDPaint", self, function()
                        if (LocalPlayer():GetTeam() ~= "traitors") then return end
                        local fanEnabled = self:GetNWBool("fanenabled")
                        
                        if (not LocalPlayer():IsLineOfSightClear(self:GetPos()) or not TTT_FAN.CVARS.fan_show_range or not fanEnabled) then return end

                        cam.Start3D()
                        render.DrawLine(self:GetPos(), self:GetPos() + self:GetRight() * TTT_FAN.CVARS.fan_range * -1, color, true)
                        cam.End3D()
                    end)
                end
            end
        end)
    end)
    
    hook.Add("TTT2RenderMarkerVisionInfo", "FanMarkerVisionDisplay", function(mvData)
        local ent = mvData:GetEntity()
        if not IsValid(ent) or ent:GetClass() ~= "ent_ttt_fan" then return end
        
        local mvObject = mvData:GetMarkerVisionObject()
        if not mvObject or mvObject:GetIdentifier() ~= "fan_trap" then return end
        
        mvData:EnableText(true)
        
        mvData:AddIcon(Material("vgui/ttt/weapon_fan_gun.png"), mvObject:GetColor())
        
        local fanEnabled = ent:GetNWBool("fanenabled")
        local stateText = fanEnabled and "ACTIVE" or "INACTIVE"
        local stateColor = fanEnabled and Color(255, 100, 100) or Color(150, 150, 150)
        
        mvData:SetTitle("FAN (" .. stateText .. ")", stateColor)
        
        local distance = math.Round(mvData:GetEntityDistance())
        mvData:AddDescriptionLine("Distance: " .. distance .. " units", COLOR_WHITE)
        
        local owner = mvObject:GetOwner()
        if IsValid(owner) and owner:IsPlayer() then
            mvData:SetSubtitle("Placed by: " .. owner:Nick(), COLOR_LGRAY)
        end
        
        mvData:SetCollapsedLine("Fan (" .. stateText .. "): " .. distance .. "u", stateColor)
    end)
end
