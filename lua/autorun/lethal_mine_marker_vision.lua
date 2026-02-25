-- Lethal Company Mine Marker Vision Integration
-- Adds TTT2 marker vision to Lethal Company landmines
-- Credit: Snuffles the Fox

if SERVER then
    AddCSLuaFile()
    
    -- Track the last player to use the lethal mine weapon
    local lastMinePlacer = nil
    
    -- Hook into weapon firing to track who's placing mines
    hook.Add("EntityFireBullets", "LethalMineTrackPlacer", function(ent, data)
        if IsValid(ent) and ent:IsPlayer() then
            local wep = ent:GetActiveWeapon()
            if IsValid(wep) and wep:GetClass() == "weapon_ttt_lethalmine" then
                lastMinePlacer = ent
            end
        end
    end)
    
    -- Also track when the weapon is used (more reliable)
    hook.Add("PlayerSwitchWeapon", "LethalMineResetPlacer", function(ply, oldwep, newwep)
        if IsValid(newwep) and newwep:GetClass() == "weapon_ttt_lethalmine" then
            lastMinePlacer = ply
        end
    end)
    
    -- Hook into landmine creation to add marker vision
    hook.Add("OnEntityCreated", "LethalMineMarkerVision", function(ent)
        timer.Simple(0, function()
            if not IsValid(ent) or ent:GetClass() ~= "item_lethal_company_landmine" then return end
            
            -- The weapon doesn't set owner, so we need to find who placed it
            -- First, try to get the owner if it exists
            local owner = ent:GetOwner()
            
            -- If no owner is set, use the last person who had the weapon
            if not IsValid(owner) or not owner:IsPlayer() then
                owner = lastMinePlacer
            end
            
            -- If still no owner, try to find nearby player with the weapon
            if not IsValid(owner) or not owner:IsPlayer() then
                local nearbyPlayers = ents.FindInSphere(ent:GetPos(), 200)
                for _, ply in pairs(nearbyPlayers) do
                    if IsValid(ply) and ply:IsPlayer() then
                        local wep = ply:GetActiveWeapon()
                        if IsValid(wep) and wep:GetClass() == "weapon_ttt_lethalmine" then
                            owner = ply
                            break
                        end
                    end
                end
            end
            
            if not IsValid(owner) or not owner:IsPlayer() then return end
            
            -- Set the owner on the entity for future reference
            ent:SetOwner(owner)
            
            -- Wait a bit for the mine to be fully initialized
            timer.Simple(0.1, function()
                if not IsValid(ent) or not IsValid(owner) then return end
                
                -- Add marker vision for the landmine
                local mvObject = ent:AddMarkerVision("lethal_mine_trap")
                if not mvObject then return end
                
                mvObject:SetOwner(owner)
                mvObject:SetVisibleFor(VISIBLE_FOR_TEAM)
                mvObject:SetColor(Color(255, 100, 100, 255)) -- Red color for danger
                mvObject:SyncToClients()
                
                -- Remove marker vision when mine is removed or explodes
                ent:CallOnRemove("LethalMineMarkerVisionCleanup", function()
                    if IsValid(ent) then
                        ent:RemoveMarkerVision("lethal_mine_trap")
                    end
                end)
            end)
        end)
    end)
end

if CLIENT then
    -- Add custom marker vision display for Lethal Company landmines
    hook.Add("TTT2RenderMarkerVisionInfo", "LethalMineMarkerVisionDisplay", function(mvData)
        local ent = mvData:GetEntity()
        if not IsValid(ent) or ent:GetClass() ~= "item_lethal_company_landmine" then return end
        
        -- Get the marker vision object
        local mvObject = mvData:GetMarkerVisionObject()
        if not mvObject or mvObject:GetIdentifier() ~= "lethal_mine_trap" then return end
        
        -- Enable the text display
        mvData:EnableText(true)
        
        -- Add the mine icon (using a generic mine/explosive icon)
        -- Note: Adjust the material path if there's a specific Lethal Company mine icon
        mvData:AddIcon(Material("materials/vgui/ttt/icon_lethalmine.png"), mvObject:GetColor())
        
        -- Set the title
        mvData:SetTitle("LANDMINE", mvObject:GetColor())
        
        -- Add distance information
        local distance = math.Round(mvData:GetEntityDistance())
        mvData:AddDescriptionLine("Distance: " .. distance .. " units", COLOR_WHITE)
        
        -- Get the owner from the marker vision object
        local owner = mvObject:GetOwner()
        if IsValid(owner) and owner:IsPlayer() then
            mvData:SetSubtitle("Placed by: " .. owner:Nick(), COLOR_LGRAY)
        end
        
        -- Set collapsed line for when off screen
        mvData:SetCollapsedLine("Landmine: " .. distance .. "u", mvObject:GetColor())
    end)
end
