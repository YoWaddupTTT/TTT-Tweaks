--[[
MIT License

Copyright (c) 2026 xproot

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

-- xproot's code
-- This should send all messages from CustomChat that generate a PostPlayerSay to SourceTV.
-- Temporary fix until https://github.com/StyledStrike/gmod-custom-chat/issues/57 is fixed.
]]

if SERVER then
	local function PostPlayerSay(speaker, text, teamOnly, channel, dmTarget)
		if dmTarget then return end --don't send DMs to SourceTV
		local botplayers = player.GetBots()
        if botplayers == nil and #botplayers < 1 then return end

		for _, ply in ipairs( botplayers ) do
			if IsValid(ply) and ply:GetPlayerInfo().ishltv then
				net.Start( "customchat.say", false )
				net.WriteString( util.TableToJSON( {
					channel = channel,
					text = text
				} ) )
				net.WriteEntity( speaker )
				net.Send( ply )
                -- print("DEBUG: Message sent to SourceTV")
			end
		end
	end

	hook.Add("PostPlayerSay", "gmod_custom_chat_to_sourcetv", PostPlayerSay)
end
