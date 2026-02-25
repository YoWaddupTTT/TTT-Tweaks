-- Auto Spectate Killer System
-- Console command: ttt_auto_spectate_killer (0 = off, 1 = on) - Per Player

if SERVER then
	util.AddNetworkString("TTT_AutoSpectateKiller_Toggle")
	
	local playerPreferences = {}
	
	net.Receive("TTT_AutoSpectateKiller_Toggle", function(len, ply)
		local enabled = net.ReadBool()
		playerPreferences[ply:SteamID64()] = enabled
	end)
	
	hook.Add("PlayerDisconnected", "TTT_AutoSpectate_Cleanup", function(ply)
		playerPreferences[ply:SteamID64()] = nil
	end)
	
	hook.Add("PlayerDeath", "TTT_AutoSpectate_HandleDeath", function(victim, inflictor, attacker)
		if not IsValid(victim) then return end
		
		for _, spec in ipairs(player.GetAll()) do
			if IsValid(spec) and spec:Team() == TEAM_SPEC then
				local steamID = spec:SteamID64()
				if playerPreferences[steamID] then
					local spectateTarget = spec:GetObserverTarget()
					
					if spectateTarget == victim and IsValid(attacker) and attacker:IsPlayer() and attacker ~= victim then
						timer.Simple(0.01, function()
							if IsValid(spec) and IsValid(attacker) and attacker:Alive() then
								spec:SpectateEntity(attacker)
								spec:SetObserverMode(OBS_MODE_IN_EYE)
							end
						end)
					end
				end
			end
		end
		
		local victimSteamID = victim:SteamID64()
		if playerPreferences[victimSteamID] and IsValid(attacker) and attacker:IsPlayer() and attacker ~= victim then
			timer.Simple(0.01, function()
				if IsValid(victim) and IsValid(attacker) and attacker:Alive() then
					victim:SpectateEntity(attacker)
					victim:SetObserverMode(OBS_MODE_IN_EYE)
				end
			end)
		end
	end)
end

if CLIENT then
	CreateClientConVar("ttt_auto_spectate_killer", "0", true, false, "Automatically spectate your killer when you die")
	
	cvars.AddChangeCallback("ttt_auto_spectate_killer", function(convar, oldValue, newValue)
		net.Start("TTT_AutoSpectateKiller_Toggle")
		net.WriteBool(tobool(tonumber(newValue)))
		net.SendToServer()
	end)
	
	hook.Add("InitPostEntity", "TTT_AutoSpectate_SendInitial", function()
		timer.Simple(1, function()
			net.Start("TTT_AutoSpectateKiller_Toggle")
			net.WriteBool(GetConVar("ttt_auto_spectate_killer"):GetBool())
			net.SendToServer()
		end)
	end)
end