hook.Add("Initialize", "CatgunIconOverride", function()
	timer.Simple(0, function()
		local catgun = weapons.GetStored("weapon_catgun")
		if catgun then
			catgun.Icon = "vgui/ttt/icon_catgun"
		end
	end)
end)

hook.Add("Initialize", "SuperSmokeIconOverride", function()
	timer.Simple(0, function()
		local supersmoke = weapons.GetStored("weapon_ttt_supersmoke")
		if supersmoke then
			supersmoke.Icon = "vgui/ttt/icon_supersmoke"
		end
	end)
end)

hook.Add("Initialize", "BananaIconOverride", function()
	timer.Simple(0, function()
		local banana = weapons.GetStored("ttt_banana")
		if banana then
			banana.Icon = "vgui/ttt/icon_banana_floor"
		end
	end)
end)

hook.Add("Initialize", "ClusterbombIconOverride", function()
	timer.Simple(0, function()
		local clusterbomb = weapons.GetStored("weapon_ttt_rclutterbomb")
		if clusterbomb then
			clusterbomb.Icon = "vgui/ttt/icon_clusterbomb"
		end
	end)
end)

hook.Add("Initialize", "FlashbangIconOverride", function()
	timer.Simple(0, function()
		local flashbang = weapons.GetStored("weapon_ttt_flashbang")
		if flashbang then
			flashbang.Icon = "vgui/ttt/icon_flashbang"
		end
	end)
end)

hook.Add("Initialize", "FragIconOverride", function()
	timer.Simple(0, function()
		local frag = weapons.GetStored("weapon_ttt_frag")
		if frag then
			frag.Icon = "vgui/ttt/icon_frag"
		end
	end)
end)