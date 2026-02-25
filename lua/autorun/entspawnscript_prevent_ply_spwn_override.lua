-- Hook to replace custom player spawns with map default spawns for specific maps
-- Keeps custom weapon/ammo spawns but rebuilds player spawn table from map entities
-- Credit: Snuffles the Fox

if SERVER then
    -- Maps that should use default player spawns instead of custom spawns
    local mapsUsingDefaultPlayerSpawns = {
        ["ttt_casino_b2"] = true,
        ["ttt_college"] = true,
        ["ttt_deepsea"] = true,
        ["ttt_innocentmotel_v1"] = true,
        ["ttt_lumbridge_a4"] = true,
    }
    
    hook.Add("Initialize", "UseMapPlayerSpawns", function()
        -- Store original SetSpawns
        local originalSetSpawns = entspawnscript.SetSpawns
        
        -- Override SetSpawns to replace player spawns for specific maps
        entspawnscript.SetSpawns = function(spawnPoints)
            local mapName = game.GetMap()
            
            if mapsUsingDefaultPlayerSpawns[mapName] then
                -- Get all player spawn entities from the map
                local playerEnts = map.GetPlayerSpawnEntities()
                
                -- Clear the custom player spawns
                spawnPoints[SPAWN_TYPE_PLAYER] = {}
                
                -- Rebuild player spawn table from map entities
                local spawnCount = 0
                for _, ents in pairs(playerEnts) do
                    for i = 1, #ents do
                        local ent = ents[i]
                        if IsValid(ent) then
                            -- Get the spawn data from this entity
                            local entType, data = map.GetDataFromSpawnEntity(ent, SPAWN_TYPE_PLAYER)
                            
                            -- Initialize the table structure if needed
                            spawnPoints[SPAWN_TYPE_PLAYER][entType] = spawnPoints[SPAWN_TYPE_PLAYER][entType] or {}
                            
                            -- Add this spawn point
                            spawnPoints[SPAWN_TYPE_PLAYER][entType][#spawnPoints[SPAWN_TYPE_PLAYER][entType] + 1] = data
                            spawnCount = spawnCount + 1
                        end
                    end
                end
                
                print("[Map Player Spawn Fix] " .. mapName .. ": Replaced custom spawns with " .. spawnCount .. " map default player spawns")
            end
            
            -- Call original function with modified spawn points
            originalSetSpawns(spawnPoints)
        end
    end)
end
