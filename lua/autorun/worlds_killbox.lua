-- Killbox for ttt_worlds map
-- Credit: Snuffles the Fox

if SERVER then
	hook.Add("Initialize", "TTT_Worlds_Killbox", function()
		if game.GetMap() ~= "ttt_worlds" then return end
		
		local killboxMin = Vector(1336, 2763, -1401)
		local killboxMax = Vector(-456, 1228, -539)
		
		local minX = math.min(killboxMin.x, killboxMax.x)
		local maxX = math.max(killboxMin.x, killboxMax.x)
		local minY = math.min(killboxMin.y, killboxMax.y)
		local maxY = math.max(killboxMin.y, killboxMax.y)
		local minZ = math.min(killboxMin.z, killboxMax.z)
		local maxZ = math.max(killboxMin.z, killboxMax.z)
		
		timer.Create("TTT_Worlds_Killbox_Check", 0.5, 0, function()
			for _, ply in ipairs(player.GetAll()) do
				if IsValid(ply) and ply:Alive() then
					local pos = ply:GetPos()
					
					if pos.x >= minX and pos.x <= maxX and
					   pos.y >= minY and pos.y <= maxY and
					   pos.z >= minZ and pos.z <= maxZ then

						ply:Kill()
					end
				end
			end
		end)
	end)
end
