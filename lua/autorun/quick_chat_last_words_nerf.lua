-- Prevents last words from showing in chat if the message is a radio command
-- This prevents abuse of revealing traitors through quick chat right before death
-- Credit: Snuffles the Fox

if CLIENT then
    local our_last_chat = ""
    
    hook.Add("ChatTextChanged", "TrackChatForLastWords", function(text)
        our_last_chat = text or ""
    end)
    
    hook.Add("Initialize", "OverrideChatInterruptForQuickChat", function()
        timer.Simple(0, function()
            net.Receive("TTT_InterruptChat", function()
                local client = LocalPlayer()
                local id = net.ReadUInt(32)

                local last_seen = IsValid(client.last_id) and client.last_id:EntIndex() or 0
                local last_words = "."

                if our_last_chat ~= "" then
                    last_words = our_last_chat
                elseif RADIO and RADIO.LastRadio and RADIO.LastRadio.t and RADIO.LastRadio.t > CurTime() - 2 then
                    last_words = "."
                else
                    last_words = "."
                end

                RunConsoleCommand("_deathrec", tostring(id), tostring(last_seen), last_words)
            end)
        end)
    end)
end
