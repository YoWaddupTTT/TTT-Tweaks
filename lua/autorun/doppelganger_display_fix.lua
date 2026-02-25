hook.Add("TTTPrepareRound", "DoppelgangerHUDFix", function()
-- hook.Add("InitPostEntity", "DoppelgangerHUDFix", function()
    if CLIENT and TTT2 then
        --bleh
        local materialRoleUnknown = Material("vgui/ttt/tid/tid_big_role_not_known")
        local materialRing = Material("effects/select_ring")

        --key: ent string
        --value: player
        local doppelownertbl = {}
        local lastply = nil
        local cachedentity = nil
        
        --remove original hook
        local originalHook = hook.GetTable()["HUDDrawTargetID"]["DrawTheEntName"]
        
        if originalHook then
            hook.Remove("HUDDrawTargetID","DrawTheEntName")
        end

        --little silly but should work I think
        net.Receive("plyname", function (len, ply)
            lastply = net.ReadEntity()
        end)

        net.Receive("doppelganger", function (len, ply)
            doppeltbl = net.ReadTable()
            if lastply then
                if cachedentity then
                    cachedentity:SetColor(lastply:GetColor())
                    cachedentity:SnatchModelInstance(lastply)
                    local playerColor = lastply:GetPlayerColor()

                    cachedentity.GetPlayerColor = function()
                        return playerColor
                    end
                end
                doppelownertbl[doppeltbl[#doppeltbl]] = lastply
            end
        end)

        hook.Add("TTTPrepareRound", "DoppelgangerFixRoundInit", function()
            doppelownertbl = {}
            lastply = nil
            cachedentity = nil
        end)

        hook.Add("OnEntityCreated", "SetDoppelgangerColor", function(ent)
            if (ent:IsNextBot()) then
                -- this is probably not the best solution and likely
                -- causes a bug when two people use doppelganger on the same tick
                -- but idk what else to do
                cachedentity = ent
            end
        end)
        
            
        hook.Add("TTTRenderEntityInfo", "DrawTheEntNameFix", function(tData)
            local ent = tData:GetEntity()

            if not (ent:IsNextBot() and doppelownertbl[tostring(ent)]) then
                return
            end
            
            local name = doppelgangername[tostring(ent)]
            
            local karma = 1000
            
            local h_string, h_color = util.HealthToString(ent:Health(), ent:GetMaxHealth())
            
            local target_role = nil
            
            local ply = doppelownertbl[tostring(ent)]
            
            -- if we succesfully have a reference to the player then..
            if ply then
                name = ply:Nick()
                karma = ply:GetBaseKarma()
                
                -- show the role of a player if it is known to the client
                local rstate = gameloop.GetRoundState()
                
                if rstate == ROUND_ACTIVE and ply.HasRole and ply:HasRole() then
                    target_role = ply:GetSubRoleData()
                end
                
                
            end
            
            -- add glowing ring around crosshair and outline when role is known
            if target_role then
                local icon_size = 64
                
                draw.FilteredTexture(
                    math.Round(0.5 * (ScrW() - icon_size)),
                    math.Round(0.5 * (ScrH() - icon_size)),
                    icon_size,
                    icon_size,
                    materialRing,
                    200,
                    target_role.color
                )
                
                outline.Add(ent, target_role.color, OUTLINE_MODE_BOTH)
            end

            -- enable targetID rendering
            tData:EnableText()
            
            tData:SetTitle(name, nil, nil)

            tData:SetSubtitle(LANG.TryTranslation(h_string), h_color)

            -- add icon to the element
            tData:AddIcon(
                target_role and target_role.iconMaterial or materialRoleUnknown,
                target_role and ply:GetRoleColor() or COLOR_SLATEGRAY
            )

            -- add karma string if karma is enabled
            if KARMA.IsEnabled() then
                local k_string, k_color = util.KarmaToString(karma)

                tData:AddDescriptionLine(LANG.TryTranslation(k_string), k_color)
            end

            -- add scoreboard tags if tag is set
            if ply.sb_tag and ply.sb_tag.txt then
                tData:AddDescriptionLine(LANG.TryTranslation(ply.sb_tag.txt), ply.sb_tag.color)
            end


            -- pronouns
            -- code copy pasted from DeltaJordan's addon
            -- I should probably be putting this stuff in a seperate function and all but then it would be inconsistent and idk whatever im lazy
            local displayOnPlayers = GetConVar("ttt2_pronouns_players"):GetBool()
            if not displayOnPlayers then return end
            local sqlTableName = "ttt2_pronouns_table"
            local savingKeys = {
                -- steamId is primary key column 'name'
                pronouns = {
                    typ = "string",
                    default = nil
                }
            }
            if not sql.CreateSqlTable(sqlTableName, savingKeys) then return end
            local pronounORM = orm.Make(sqlTableName)
            if not pronounORM then return end
            local userTable = pronounORM:Find(ply:SteamID64())
            if not userTable then return end
            tData:AddDescriptionLine("(" .. userTable.pronouns .. ")", Color(255, 255, 255))
            

        end)
    end
end)