if not SERVER then return end

-- Wait until the server is fully initialized to ensure we override existing entities
hook.Add("Initialize", "TTT2OverrideMarkerLogicOnLoad", function()

	--  == Override the PhysicsCollide (function from the SWEP init) to properly attribute the inflictor. ==
	-- Get paint_ball definition
	local entRegistry = scripted_ents.GetStored("paint_ball")
	-- If paint_ball actually exists then
	if entRegistry and entRegistry.t then
		local ENT = entRegistry.t
		-- Rewrite function
		function ENT:PhysicsCollide(data, phy)
			-- Cleaned up code from original (paint_ball/init.lua)
			local trace = { filter = {self} }
			data.HitNormal = data.HitNormal * -1

			local startPos = data.HitPos + data.HitNormal
			local endPos = data.HitPos - data.HitNormal

			util.Decal("splat" .. math.random(1, 12), startPos, endPos)
			self:EmitSound("marker/pbhit.wav")

			-- FIX: Pass 'self' (the ball) as the inflictor, not the owner.
			util.BlastDamage(self, self:GetOwner(), data.HitPos, 1, paintballdamage or 0)

			self:Remove()
		end
	end
	-- == end ==

	-- == Rewrite Marker marking players hit registration ==
	-- Remove old hook (we will be using EntityTakeDamage so ScalePlayerDamage isn't worth keeping)
	hook.Remove("ScalePlayerDamage", "MarkerHitReg")
	-- Code Rewritten from Original MarkerHitReg
	hook.Add("EntityTakeDamage", "TTT2MarkerHitRegBETTER", function(target, dmginfo)
		-- If the round is not active, return
		-- This does mean that during post round (IF MARKER BALL DAMAGE IS NOT SET TO 0) the marker ball will do damage, which, dinke wants, so...
		if GetRoundState() ~= ROUND_ACTIVE then return end

		-- Get attacker and end execution if attacker is not valid or not a player or not a marker
		local attacker = dmginfo:GetAttacker()
		if not IsValid(attacker) or not attacker:IsPlayer() or attacker:GetTeam() ~= TEAM_MARKER then return end
		-- Get inflictor and end execution if the inflictor is not the paint_ball
		local inflictor = dmginfo:GetInflictor()
		if not IsValid(inflictor) or inflictor:GetClass() ~= "paint_ball" then return end

		-- If the target is a player and not a Marker, apply the mark
		if target:IsPlayer() and target:GetTeam() ~= TEAM_MARKER then
			MARKER_DATA:SetMarkedPlayer(attacker, target, false)
		end

		dmginfo:SetDamage(0)
		return true
	end)
	-- == end ==

	-- == Rewrite TTT2MarkerTakeNoDamage for barnacle fix ==
	-- Code Rewritten from Original
	local ttt_mark_take_no_damage
	hook.Add("EntityTakeDamage", "TTT2MarkerTakeNoDamage", function(victim, dmginfo)
		-- Check is ttt_mark_take_no_damage is set
		if not ttt_mark_take_no_damage then
			ttt_mark_take_no_damage = GetConVar("ttt_mark_take_no_damage")
		end
		
		if not ttt_mark_take_no_damage or not ttt_mark_take_no_damage:GetBool() then return end

		-- Return if victim is not valid marker
		if not IsValid(victim) or not victim:IsPlayer() or not TEAM_MARKER or victim:GetTeam() ~= TEAM_MARKER then return end

		-- Get attacker and return if this bloke ain't valid
		local attacker = dmginfo:GetAttacker()
		if not IsValid(attacker) then return end

		-- Logic to determine the "Real" attacker
		-- (sometimes the attacker is a player, but sometimes it isn't a player but rather a player owned entity)
		local realAttacker = attacker
		-- If the attacker is not a player (possible non-player entity)
		if not attacker:IsPlayer() then
			-- If the attacker is valid, try to find who owns its damage
			if attacker.GetDamageOwner and IsValid(attacker:GetDamageOwner()) and attacker:GetDamageOwner():IsPlayer() then
				-- set the realattacker to the owner and not the entity
				realAttacker = attacker:GetDamageOwner()
			else
				-- If we can't find a player owner, stop here (we can't do anything as it's already not a player)
				return
			end
		end

		-- If the REAL attacker is marked, negate the damage
		if MARKER_DATA and realAttacker ~= victim and MARKER_DATA:IsMarked(realAttacker) then
			dmginfo:ScaleDamage(0)
			dmginfo:SetDamage(0)
		end
	end)
	-- == end ==
end)
