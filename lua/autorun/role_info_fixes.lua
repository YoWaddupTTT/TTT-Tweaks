/*
MIT License

Copyright (c) 2026 Spanospy

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

if CLIENT then
    hook.Add("InitPostEntity", "ReplaceRoleInfoHook", function()
        -- Replace TTT2RequestRoleInfoUpdateSubrole with modified version with checks and delay.
        hook.Remove("TTT2UpdateSubrole", "TTT2RequestRoleInfoUpdateSubrole")
        hook.Add("TTT2UpdateSubrole", "TTT2RequestRoleInfoUpdateSubrole", function(ply, oldSubroleID, newSubroleID)
            if not IsValid(ply) then return end
            if LocalPlayer() ~= ply then return end

            timer.Remove("RequestRoleInfoDelay") -- Remove any pending role info request, because our role has since changed.
            if LocalPlayer().role == ROLE_NONE then return end -- This role is never supposed to be displayed in normal gameplay.
            timer.Create("RequestRoleInfoDelay", 2.5, 1, function() -- Create a new delayed request for role info, imitating TTT's Round Start Popup delay.
                local ply = LocalPlayer()
                local steamID = ply:SteamID()
                local roleName = ply:GetSubRoleData().name -- this is the role that the player currently is when the delay expires, not when the delay was made.
                
                if gameloop.GetRoundState() == ROUND_ACTIVE then -- In case our role changes when a round is not active.
                    -- use our own net message so we call our function instead of the original. (see SendYoWaddupRoleInfo)
                    net.Start("YoWaddupRequestRoleInfoChat")
                    net.WriteTable({steamID, roleName})
                    net.SendToServer()
                end
            end)
        end)
    end)
end

if SERVER then

    -- As roleDescriptions is stored locally, we'll need to hook into functions to replicate the variable.
    local roleDescriptions = nil
    hook.Add("InitPostEntity", "HookIntoRoleDescriptions", function()
    
        local origSaveStoreData = SaveStoreData
        function SaveStoreData(fileName, newRoleDescriptions)
            roleDescriptions = newRoleDescriptions
            origSaveStoreData(fileName, roleDescriptions)
        end
        
        local origReadStoreData = ReadStoreData
        function ReadStoreData(fileName)
            roleDescriptions = origReadStoreData(fileName)
            return roleDescriptions
        end
        
        -- ReadStoreData only gets run when an admin requests them, or on init (which we're past now). So, run it once to populate our variable.
        ReadStoreData("role_descriptions_v3.json")
    end)
    
    -- Add a check to SendRoleInfo to prevent replying to clients when there's no role info to send. 
    -- SendRoleInfo is a local function, so we have to instead copy the function's code and make our hook use that. (see TTT2RequestRoleInfoUpdateSubrole)
    local function SendYoWaddupRoleInfo(steamID, roleName)
        
        -- Just in case...
        if roleDescriptions == nil then 
            print("[TTT2 Role Info Fix] ROLE DESCRIPTIONS WAS NIL")
            ReadStoreData("role_descriptions_v3.json") 
        end
        
        local ply = player.GetBySteamID(steamID)
        local data = roleDescriptions[roleName]
        print("[TTT2 Role Info Fix] Player " .. ply:Nick() .. " asked for role info of " .. roleName)
        if data ~= nil and data.description ~= nil and data.description ~= "" then
            net.Start("ttt2SendRoleInfoChat") -- we don't need to overwrite this, fortunately.
            if (data == nil) then
                data = {}
            end
            
            net.WriteString(roleName)
            net.WriteTable(data)
            net.Send(ply)
        else
            print("[TTT2 Role Info Fix] ..But we have no data for that role.")
        end
    end

    util.AddNetworkString("YoWaddupRequestRoleInfoChat")
    net.Receive("YoWaddupRequestRoleInfoChat", function(len, ply)
        data = net.ReadTable()
        SendYoWaddupRoleInfo(data[1], data[2])
    end)
end