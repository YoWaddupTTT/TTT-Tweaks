function tweaks_fixHoldTypes()
	-- ANY NEW FIXES: TYPE YOUR FIX HERE
	-- If you need the weapon id, spawn a local server and type
	-- sv_cheats 1
	-- sv_allowcslua 1
	-- lua_run_cl for _,w in pairs(weapons.GetList()) do print(w.ClassName,w.PrintName) end
	local holdtypes_to_fix = {
		["dancedead"] = "revolver",
		["ttt_weapon_eagleflightgun"] = "revolver",
		["weapon_ttt_wpnjammer"] = "normal",
		["weapon_ttt_prop_disguiser"] = "pistol",
		["weapon_ttt_headlauncher"] = "revolver"
	}
	-- Holdtypes:
	-- pistol 	One hand grasp used for pistols
	-- revolver 	Two hand pistol holdtype, revolver reload animation.
	-- duel 	Dual pistols hold type
	-- smg 	Used for two-handed weapons such as the SMG1 (rifles with a vertical grip)
	-- ar2 	Used for two-handed weapons such as the AR2 (rifles without a vertical grip)
	-- shotgun 	Used for weapons such as shotguns
	-- rpg 	Used for weapons that rest on your shoulder, such as RPG
	-- physgun 	Used for the gravity and physics guns
	-- crossbow 	Used for weapons such as crossbows, very similar to shotgun
	-- camera 	Holds the weapon in front of your face as a camera
	-- slam 	Used for weapons such as SLAM/explosives/c4
	-- normal 	No weapon stance, hands at sides
	-- grenade 	Used for grenade, similar to melee
	-- melee 	Hand raised above head, used for crowbar
	-- melee2 	Two-handed sword
	-- knife 	Bent over stabbing hold type
	-- fist 	Hands up punching hold type
	-- passive 	Sort of an "idle" stance, like when the civil protection hold their smg's when they aren't aiming
	-- magic 	Use your power of will to move objects. One hand in front of you, one hand to your head
	-- https://wiki.facepunch.com/gmod/Hold_Types
	
	print("[TTT-Tweaks] HoldType Fixes:")
	-- Iterate through each fix and apply it
	for key, value in pairs(holdtypes_to_fix) do
		-- Get the stored weapon table
		local weapon = weapons.GetStored(key)
		
		-- Check if the weapon exists
		if weapon then
			-- Override the hold type
			weapon.HoldType = value
			print("[TTT-Tweaks] Fix " .. key .. " -> " .. value)
		else
			print("[TTT-Tweaks] Skip " .. key .. " -> " .. value)
		end
	end
end

function tweaks_forceHoldTypeOverride()
	-- This is for weapons that don't have any extra code in deploy plus hate their holdtypes_to_fix
	local holdtypes_to_force = {
		["weapon_ttt_wpnjammer"] = "normal"
	}
	print("[TTT-Tweaks] Force HoldType Fixes:")
	-- Iterate through each fix and apply it
	for key, value in pairs(holdtypes_to_force) do
		-- Get the stored weapon table
		local weapon = weapons.GetStored(key)
		
		-- Check if the weapon exists
		if weapon then
			-- Override the Deploy function to fix the holdtype when drawn
			local originalDeploy = weapon.Deploy
			weapon.Deploy = function(self, ...)
				-- Call the original deploy function
				local result = true
				if originalDeploy then
					result = originalDeploy(self, ...)
				end
				
				-- Force the holdtype to normal
				self.HoldType = value
				self:SetHoldType(value)
				
				return result
			end
			
			-- Override the Initialize function to set the holdtype
			local originalInit = weapon.Initialize
			weapon.Initialize = function(self, ...)
				if originalInit then
					originalInit(self, ...)
				end
				
				-- Set the holdtype after initialization
				self.HoldType = "normal"
				self:SetHoldType("normal")
			end
			print("[TTT-Tweaks] Fix " .. key .. " -> " .. value)
		else
			print("[TTT-Tweaks] Skip " .. key .. " -> " .. value)
		end
	end
end

-- Wait until the game is fully initialized
hook.Add("InitPostEntity", "TTTTweaks_HoldTypeOverride", function()
	-- Small delay to ensure the weapons are fully registered
	timer.Simple(1, function()
		tweaks_fixHoldTypes()
	end)
end)