-- Spawns a Christmas tree with presents on round start (December only)

--[[
if CLIENT then
    -- Network message to render hull trace on clients
    net.Receive("ChristmasTreeHullTrace", function()
        local startPos = net.ReadVector()
        local endPos = net.ReadVector()
        local mins = net.ReadVector()
        local maxs = net.ReadVector()
        
        -- Draw the hull trace for 10 seconds
        local drawTime = CurTime() + 60
        
        hook.Add("PostDrawTranslucentRenderables", "DrawChristmasTreeHull", function()
            if CurTime() > drawTime then
                hook.Remove("PostDrawTranslucentRenderables", "DrawChristmasTreeHull")
                return
            end
            
            -- Draw the hull box at start position
            render.DrawWireframeBox(startPos, Angle(0, 0, 0), mins, maxs, Color(0, 255, 0), true)
            
            -- Draw the hull box at end position
            render.DrawWireframeBox(endPos, Angle(0, 0, 0), mins, maxs, Color(0, 255, 0), true)
            
            -- Draw lines connecting the corners
            local corners = {
                Vector(mins.x, mins.y, mins.z),
                Vector(maxs.x, mins.y, mins.z),
                Vector(maxs.x, maxs.y, mins.z),
                Vector(mins.x, maxs.y, mins.z),
                Vector(mins.x, mins.y, maxs.z),
                Vector(maxs.x, mins.y, maxs.z),
                Vector(maxs.x, maxs.y, maxs.z),
                Vector(mins.x, maxs.y, maxs.z),
            }
            
            for _, corner in ipairs(corners) do
                render.DrawLine(startPos + corner, endPos + corner, Color(0, 255, 0), true)
            end
        end)
    end)
end
--]]

if SERVER then
    --util.AddNetworkString("ChristmasTreeHullTrace")
    
    -- Store weapon/ammo spawn locations on map load (before they're removed)
    local weaponSpawnLocations = {}
    
    -- Store previous tree spawn locations to avoid clustering
    local previousTreeSpawns = {}
    
    hook.Add("InitPostEntity", "StoreWeaponSpawnLocations", function()
        weaponSpawnLocations = {}
        
        -- Store all weapon spawn locations
        for _, ent in ipairs(ents.FindByClass("ttt_random_weapon")) do
            if IsValid(ent) then
                table.insert(weaponSpawnLocations, ent:GetPos())
            end
        end
        
        -- Store all ammo spawn locations
        for _, ent in ipairs(ents.FindByClass("ttt_random_ammo")) do
            if IsValid(ent) then
                table.insert(weaponSpawnLocations, ent:GetPos())
            end
        end
        
        --print("[Christmas Tree] Stored " .. #weaponSpawnLocations .. " weapon/ammo spawn locations")
    end)
    
    hook.Add("TTTBeginRound", "SpawnChristmasTree", function()
        -- Only spawn in December
        if os.date("%m") ~= "12" then
            return
        end
        
        -- Wait a tick for map to be fully loaded
        timer.Simple(0.1, function()
            local treePos = nil
            local useNavMesh = false
            
            -- Minimum distance from previous spawn locations (in units)
            local MIN_SPAWN_DISTANCE = 800
            
            -- Helper function to check if position is far enough from previous spawns
            local function IsFarEnoughFromPrevious(pos)
                for _, prevPos in ipairs(previousTreeSpawns) do
                    if pos:Distance(prevPos) < MIN_SPAWN_DISTANCE then
                        return false
                    end
                end
                return true
            end
            
            -- Try to find a random navigation node on the map
            local allNavAreas = navmesh.GetAllNavAreas()
            
            if allNavAreas and #allNavAreas > 0 then
                useNavMesh = true
                
                -- Try up to 1100 random nav areas to find a suitable spot
                for i = 1, 1100 do
                    local randomArea = allNavAreas[math.random(1, #allNavAreas)]
                    
                    if IsValid(randomArea) then
                        local nodePos = randomArea:GetCenter()
                        
                        --print("[Christmas Tree] Attempt " .. i .. ": Checking position " .. tostring(nodePos))
                        
                        -- Trace down to find ground
                        local tr = util.TraceLine({
                            start = nodePos + Vector(0, 0, 16),
                            endpos = nodePos - Vector(0, 0, 100),
                            mask = MASK_SOLID
                        })
                        
                        -- Skip if trace hit a physics prop or NPC
                        if IsValid(tr.Entity) then
                            if tr.Entity:GetMoveType() == MOVETYPE_VPHYSICS or tr.Entity:IsNPC() then
                                --print("[Christmas Tree] Attempt " .. i .. ": REJECTED - Hit physics prop or NPC (" .. tr.Entity:GetClass() .. ")")
                                continue
                            end
                        end
                        
                        -- Check if there's enough space (hull test) - smaller hull for more spawn options
                        local hullTrace = util.TraceHull({
                            start = tr.HitPos,
                            endpos = tr.HitPos + Vector(0, 0, 50),
                            mins = Vector(-61, -61, 0),
                            maxs = Vector(61, 61, 70),
                            mask = MASK_SOLID_BRUSHONLY -- Only check walls/world geometry, not props
                        })
                        
                        if not hullTrace.Hit then
                            -- Check if far enough from previous spawns (skip this check after 1000 attempts)
                            if i <= 1000 and not IsFarEnoughFromPrevious(tr.HitPos) then
                                --print("[Christmas Tree] Attempt " .. i .. ": REJECTED - Too close to previous spawn location")
                                continue
                            end
                            
                            if i > 1000 then
                                --print("[Christmas Tree] Attempt " .. i .. ": ACCEPTED (distance check bypassed after 1000 attempts) - Found location at " .. tostring(tr.HitPos))
                            else
                                --print("[Christmas Tree] Attempt " .. i .. ": ACCEPTED - Found suitable location at " .. tostring(tr.HitPos))
                            end
                            treePos = tr.HitPos
                            
                            --[[
                            -- Send hull trace to all clients for visualization
                            net.Start("ChristmasTreeHullTrace")
                            net.WriteVector(tr.HitPos + Vector(0, 0, 0))
                            net.WriteVector(tr.HitPos + Vector(0, 0, 50))
                            net.WriteVector(Vector(-61, -61, 0))
                            net.WriteVector(Vector(61, 61, 70))
                            net.Broadcast()
                            --]]
                            
                            break
                        else
                            --print("[Christmas Tree] Attempt " .. i .. ": REJECTED - Hull trace hit (not enough clearance)")
                        end
                    else
                        --print("[Christmas Tree] Attempt " .. i .. ": REJECTED - Invalid nav area")
                    end
                end
            end
            
            -- Fallback: Use stored weapon/ammo spawn locations if nav mesh failed
            if not treePos and #weaponSpawnLocations > 0 then
                --print("[Christmas Tree] Using fallback: stored weapon/ammo spawn locations (" .. #weaponSpawnLocations .. " available)")
                
                -- Create a shuffled copy of the locations to try
                local shuffledLocations = table.Copy(weaponSpawnLocations)
                table.Shuffle(shuffledLocations)
                
                local totalAttempts = 0
                local maxAttempts = 1000
                
                -- First pass: try all locations with distance check
                for i = 1, #shuffledLocations do
                    if totalAttempts >= maxAttempts then
                        break
                    end
                    
                    totalAttempts = totalAttempts + 1
                    local testPos = shuffledLocations[i]
                    
                    --print("[Christmas Tree] Fallback Attempt " .. totalAttempts .. ": Checking weapon/ammo spawn at " .. tostring(testPos))
                    
                    -- Check if there's enough space at this location
                    local hullTrace = util.TraceHull({
                        start = testPos,
                        endpos = testPos + Vector(0, 0, 50),
                        mins = Vector(-61, -61, 0),
                        maxs = Vector(61, 61, 70),
                        mask = MASK_SOLID_BRUSHONLY
                    })
                    
                    if not hullTrace.Hit then
                        -- Check if far enough from previous spawns
                        if not IsFarEnoughFromPrevious(testPos) then
                            --print("[Christmas Tree] Fallback Attempt " .. totalAttempts .. ": REJECTED - Too close to previous spawn location")
                            continue
                        end
                        
                        --print("[Christmas Tree] Fallback Attempt " .. totalAttempts .. ": ACCEPTED - Found suitable location at " .. tostring(testPos))
                        treePos = testPos
                        
                        --[[
                        -- Send hull trace to all clients for visualization
                        net.Start("ChristmasTreeHullTrace")
                        net.WriteVector(testPos + Vector(0, 0, 0))
                        net.WriteVector(testPos + Vector(0, 0, 50))
                        net.WriteVector(Vector(-61, -61, 0))
                        net.WriteVector(Vector(61, 61, 70))
                        net.Broadcast()
                        --]]
                        
                        break
                    else
                        --print("[Christmas Tree] Fallback Attempt " .. totalAttempts .. ": REJECTED - Hull trace hit (not enough clearance)")
                    end
                end
                
                -- Second pass: if still no position, try again without distance check
                if not treePos and totalAttempts < maxAttempts then
                    --print("[Christmas Tree] First pass complete, retrying without distance check...")
                    
                    for i = 1, #shuffledLocations do
                        if totalAttempts >= maxAttempts then
                            break
                        end
                        
                        totalAttempts = totalAttempts + 1
                        local testPos = shuffledLocations[i]
                        
                        --print("[Christmas Tree] Fallback Retry Attempt " .. totalAttempts .. ": Checking weapon/ammo spawn at " .. tostring(testPos))
                        
                        -- Check if there's enough space at this location
                        local hullTrace = util.TraceHull({
                            start = testPos,
                            endpos = testPos + Vector(0, 0, 50),
                            mins = Vector(-61, -61, 0),
                            maxs = Vector(61, 61, 70),
                            mask = MASK_SOLID_BRUSHONLY
                        })
                        
                        if not hullTrace.Hit then
                            --print("[Christmas Tree] Fallback Retry Attempt " .. totalAttempts .. ": ACCEPTED (distance check bypassed) - Found location at " .. tostring(testPos))
                            treePos = testPos
                            
                            --[[
                            -- Send hull trace to all clients for visualization
                            net.Start("ChristmasTreeHullTrace")
                            net.WriteVector(testPos + Vector(0, 0, 0))
                            net.WriteVector(testPos + Vector(0, 0, 50))
                            net.WriteVector(Vector(-61, -61, 0))
                            net.WriteVector(Vector(61, 61, 70))
                            net.Broadcast()
                            --]]
                            
                            break
                        else
                            --print("[Christmas Tree] Fallback Retry Attempt " .. totalAttempts .. ": REJECTED - Hull trace hit (not enough clearance)")
                        end
                    end
                end
            end
            
            -- If we still don't have a position, give up
            if not treePos then
                --print("[Christmas Tree] Failed to find suitable spawn location")
                return
            end
            
            -- Spawn the Christmas tree
            local tree = ents.Create("prop_dynamic")
            if not IsValid(tree) then
                --print("[Christmas Tree] Failed to create tree entity")
                return
            end
            tree:SetModel("models/props_snowville/tree_pine_small.mdl")
            tree:SetPos(treePos)
            tree:SetAngles(Angle(0, math.random(0, 360), 0))
            tree:SetSolid(SOLID_VPHYSICS)
            tree:SetCollisionGroup(COLLISION_GROUP_NONE)
            tree:Spawn()
            tree:Activate()
            
            -- Store this spawn location for future rounds
            table.insert(previousTreeSpawns, treePos)
            
            -- Keep only the last 10 spawn locations to avoid memory bloat
            if #previousTreeSpawns > 10 then
                table.remove(previousTreeSpawns, 1)
            end
            
            -- Spawn 3 presents around the tree
            local presentModels = {
                "models/katharsmodels/present/type-2/big/present.mdl",
                "models/katharsmodels/present/type-2/big/present2.mdl",
                "models/katharsmodels/present/type-2/big/present3.mdl"
            }
            
            local presentAngles = { 0, 120, 240 } -- Evenly spaced around tree
            
            for i = 1, 3 do
                local angle = math.rad(presentAngles[i])
                local distance = 60 -- Distance from tree center
                local offset = Vector(math.cos(angle) * distance, math.sin(angle) * distance, 0)
                local presentPos = treePos + offset
                
                -- Trace down to find ground for present
                local tr = util.TraceLine({
                    start = presentPos + Vector(0, 0, 50),
                    endpos = presentPos - Vector(0, 0, 100),
                    mask = MASK_SOLID
                })
                
                local present = ents.Create("christmas_present")
                
                if IsValid(present) then
                    present.Model = presentModels[i]
                    present:SetPos(tr.HitPos + Vector(0, 0, 5))
                    present:SetAngles(Angle(0, math.random(0, 360), 0))
                    present:Spawn()
                end
            end
            
            --print("[Christmas Tree] Spawned at " .. tostring(treePos) .. (useNavMesh and " (using nav mesh)" or " (fallback spawn)"))
        end)
    end)
end
