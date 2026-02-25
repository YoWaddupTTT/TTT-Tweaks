-- Quick chat cooldown system
-- Prevents radio command spam by enforcing a 10 second cooldown
-- Credit: Snuffles the Fox

if CLIENT then
    local lastRadioTime = 0
    local spamAttempts = {}
    local COOLDOWN_TIME = 10
    local SPAM_THRESHOLD = 10
    
    hook.Add("TTT2ClientRadioCommand", "QuickChatCooldown", function(cmd)
        local currentTime = CurTime()
        local timeSinceLastRadio = currentTime - lastRadioTime
        
        if timeSinceLastRadio < COOLDOWN_TIME then
            table.insert(spamAttempts, currentTime)
            
            for i = #spamAttempts, 1, -1 do
                if currentTime - spamAttempts[i] > COOLDOWN_TIME then
                    table.remove(spamAttempts, i)
                end
            end
            
            if #spamAttempts >= SPAM_THRESHOLD then
                chat.AddText(COLOR_RED, "Chill. Out.")
                spamAttempts = {}
            end
            
            return true
        end
        
        lastRadioTime = currentTime
        spamAttempts = {}
        
        return false
    end)
    
    hook.Add("PlayerBindPress", "BlockSayAfterRadio", function(ply, bind, pressed)
        if not pressed then return end
        
        if string.StartWith(bind, "say ") then
            local currentTime = CurTime()
            local timeSinceLastRadio = currentTime - lastRadioTime
            
            if timeSinceLastRadio < COOLDOWN_TIME and lastRadioTime > 0 then
                return true
            end
        end
    end)
end
