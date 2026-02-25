if CLIENT then return end

-- Beacon PVS Enhancement
-- Adds PVS points to players detected by beacons to keep them loaded on all clients

hook.Add("SetupPlayerVisibility", "Beacon_PVS_AddPoints", function(viewer, viewEntity)
    if not IsValid(viewer) or not viewer:IsPlayer() then return end
    
    local plys = player.GetAll()
    
    for i = 1, #plys do
        local target = plys[i]
        
        if not IsValid(target) then continue end
        if target == viewer then continue end
        
        local mvObject = markerVision.Get(target, "beacon_player")
        
        if mvObject then
            AddOriginToPVS(target:GetPos())
        end
    end
end)
