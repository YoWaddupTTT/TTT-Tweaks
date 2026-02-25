-- Hook to handle ttt_innocentmotel_v1 rearm script special case
-- Forces replacespawns to 0 and ignores all ttt_playerspawn entries
-- Credit: Snuffles the Fox

if SERVER then
    -- Wait for TTT to fully initialize before hooking
    hook.Add("Initialize", "InnoMotel_AntiRearm", function()
        -- Check if ents.TTT exists (it should after Initialize)
        if not ents.TTT or not ents.TTT.ImportEntities then
            print("[Innocent Motel Anti-Rearm] ERROR: ents.TTT.ImportEntities not found!")
            return
        end

        -- Store the original ImportEntities function
        local originalImportEntities = ents.TTT.ImportEntities

        -- Override the ImportEntities function
        function ents.TTT.ImportEntities(map)
            -- Call the original function to get the spawns and settings
            local spawns, settings = originalImportEntities(map)

            -- Check if this is the innocent motel map
            if map == "ttt_innocentmotel_v1" then
                -- Force replacespawns to 0 (don't replace existing spawns)
                settings.replacespawns = 0

                -- Filter out all ttt_playerspawn entries
                local filteredSpawns = {}
                for i = 1, #spawns do
                    local spawn = spawns[i]
                    -- Only keep spawns that are NOT ttt_playerspawn or info_player_deathmatch
                    -- (info_player_deathmatch is what ttt_playerspawn remaps to)
                    if spawn.class ~= "ttt_playerspawn" and spawn.class ~= "info_player_deathmatch" then
                        filteredSpawns[#filteredSpawns + 1] = spawn
                    end
                end

                -- Return the filtered spawns and modified settings
                return filteredSpawns, settings
            end

            -- For all other maps, return the original data unchanged
            return spawns, settings
        end
    end)
end
