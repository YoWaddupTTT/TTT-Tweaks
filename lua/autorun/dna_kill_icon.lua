-- DNA Kill Icon
-- Adds a DNA icon to the killer info victims receive, if they were killed while the killer had their DNA.
-- Credit: Snuffles the Fox

if SERVER then
    -- Network string to send DNA info
    util.AddNetworkString("tttRsDeathNotifyDNA")
    
    -- Store the original DoPlayerDeath hook
    local originalTellKiller = nil
    
    -- Save a reference to the original hook when our code loads
    hook.Add("Initialize", "DNAKillIcon_SaveOriginalHook", function()
        -- Find the original TellKiller function
        for k, v in pairs(hook.GetTable()["DoPlayerDeath"] or {}) do
            if k == "TTTChatStats" then
                originalTellKiller = v
                
                -- Actually remove the original hook
                hook.Remove("DoPlayerDeath", "TTTChatStats")
                
                break
            end
        end
        
        if not originalTellKiller then
            return
        end
        
        -- Replace the DoPlayerDeath hook with our version
        hook.Add("DoPlayerDeath", "TTTChatStats", function(victim, attacker, dmg)
            -- Call original hook first
            originalTellKiller(victim, attacker, dmg)
            
            local killer = dmg:GetAttacker()
            
            -- Check if killer is valid and a player
            if not IsValid(killer) or not killer:IsPlayer() then return end
            
            -- Check if killer has a DNA scanner
            local scanner = killer:GetWeapon("weapon_ttt_wtester")
            
            local hasVictimDNA = false
            if IsValid(scanner) and scanner.ItemSamples then
                -- Check if killer has victim's DNA
                for _, ply in pairs(scanner.ItemSamples) do
                    if ply == victim then
                        hasVictimDNA = true
                        break
                    end
                end
            end
            
            -- Send additional network message with DNA info
            if hasVictimDNA then
                net.Start("tttRsDeathNotifyDNA")
                net.WriteBool(true)
                net.Send(victim)
            end
        end)
    end)
end

if CLIENT then
    -- Create a variable to store if killer had victim's DNA
    local killerHadDNA = false
    
    -- Listen for DNA notification
    net.Receive("tttRsDeathNotifyDNA", function()
        killerHadDNA = net.ReadBool()
    end)
    
    -- Reset DNA flag when player respawns
    net.Receive("tttRsPlayerRespawn", function()
        killerHadDNA = false
    end)
    
    -- Reset DNA flag when round starts
    hook.Add("TTTBeginRound", "DNAKillIcon_ResetOnRoundStart", function()
        killerHadDNA = false
    end)
    
    -- Reset DNA flag when round ends
    hook.Add("TTTEndRound", "DNAKillIcon_ResetOnRoundEnd", function()
        killerHadDNA = false
    end)
    
    -- Store the original DrawHelper function reference
    local originalDrawHelper = nil
    
    -- Use Rentek's DNA material
    local dnaIconMat = Material("vgui/ttt/dna")
    
    -- Variable to track the state of KILLER_INFO
    local wasKillerInfoActive = false
    
    -- Check for popup visibility changes to reset DNA flag when popup disappears
    hook.Add("Think", "DNAKillIcon_CheckPopupVisibility", function()
        local isKillerInfoActive = KILLER_INFO and KILLER_INFO.data and KILLER_INFO.data.render
        
        if wasKillerInfoActive and not isKillerInfoActive then
            -- Popup was just hidden
            killerHadDNA = false
        end
        
        wasKillerInfoActive = isKillerInfoActive
    end)
    
    -- Store the original killer name draw function reference
    local originalKillerNameFunc = nil
    
    -- Better hook that will run every time the HUD updates
    hook.Add("HUDPaint", "DNAKillIcon_CheckHookDrawHelper", function()
        -- Only run this code once when we need to hook
        if originalDrawHelper or not KILLER_INFO or not KILLER_INFO.data then return end
        
        -- Find the killer info popup element
        for _, element in pairs(hudelements.GetList()) do
            if element.id == "pure_skin_killer_info_popup" then
                
                -- Store original DrawHelper function
                originalDrawHelper = element.DrawHelper
                
                -- Replace DrawHelper with our modified version
                element.DrawHelper = function(self, x, y, w, h)
                    -- Call original function first
                    originalDrawHelper(self, x, y, w, h)
                    
                    -- If killer had victim's DNA, draw the DNA icon and add text to killer name
                    if killerHadDNA and KILLER_INFO.data.mode ~= "killer_self_no_weapon" and 
                       KILLER_INFO.data.mode ~= "killer_world" then
                        
                        local paddingEdge = 39 * self.scale
                        local paddingInner = 14 * self.scale
                        local sizeWeaponIcon = 32 * self.scale
                        local sizeDNAIcon = 24 * self.scale
                        local sizeHeadshotIcon = 24 * self.scale
                        local sizeColorBar2 = 78 * self.scale
                        
                        -- Calculate position for DNA icon
                        local xDNAIcon
                        if KILLER_INFO.data.killer_weapon_head then
                            -- Position next to headshot icon
                            xDNAIcon = x + w - paddingInner - sizeHeadshotIcon - sizeDNAIcon - 5 * self.scale
                        else
                            -- Position where headshot icon would be
                            xDNAIcon = x + w - paddingInner - sizeDNAIcon
                        end
                        
                        -- Position the DNA icon at the same vertical height as the headshot icon
                        local yDNAIcon = y + h - paddingEdge - sizeHeadshotIcon/2 - sizeDNAIcon/2 - 15 * self.scale
                        
                        -- Draw DNA icon
                        draw.FilteredShadowedTexture(
                            xDNAIcon,
                            yDNAIcon,
                            sizeDNAIcon,
                            sizeDNAIcon,
                            dnaIconMat,
                            255,
                            Color(41, 217, 234) -- DNA blue color
                        )
                        
                        -- Get the exact killer name text as shown in HUD
                        local killerNameText = string.upper(KILLER_INFO.data.killer_name)
                        local nameX = x + paddingEdge + sizeColorBar2 + paddingInner
                        local nameY = y + paddingEdge + paddingInner - 4 * self.scale
                        
                        surface.SetFont("PureSkinBar")
                        local nameWidth = surface.GetTextSize(killerNameText)
                        
                        -- Get the text color based on user's HUD settings
                        local colorTextBase = util.GetDefaultColor(self.basecolor)
                        
                        -- Add the DNA text immediately after the last character of the name
                        draw.AdvancedText(
                            " (WITH DNA)",  -- Space at start to separate from name
                            "PureSkinBar",
                            nameX + nameWidth,  -- Position exactly at the end of name
                            nameY,  -- Same Y position as the name
                            colorTextBase,  -- Use the user's HUD text color
                            TEXT_ALIGN_LEFT,
                            TEXT_ALIGN_TOP,
                            true,
                            self.scale
                        )
                    end
                end
                break
            end
        end
    end)
end