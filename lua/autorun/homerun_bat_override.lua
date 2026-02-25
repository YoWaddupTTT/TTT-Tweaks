-- TITLE
-- This prevents the homerun bat from damaging & launching other players if the user is on TEAM_JESTER, or if they are trying to hit the Marker while marked.
-- Credit: Snuffles the Fox & Spanospy

if CLIENT then
	sound.Add{
		name="Bat.Squeak",
		channel=CHAN_STATIC,
		volume=1,
		level=120,
		pitch=100,
		sound="ttt2/bat_squeak.mp3"
	}
	
	net.Receive("HomerunSqueak",function()
		local tr,ply,wep=net.ReadTable(),net.ReadEntity(),net.ReadEntity()
		local ent=tr.Entity

		local edata=EffectData()
		edata:SetStart(tr.StartPos)
		edata:SetOrigin(tr.HitPos)
		edata:SetNormal(tr.Normal)
		edata:SetSurfaceProp(tr.SurfaceProps)
		edata:SetHitBox(tr.HitBox)
		edata:SetEntity(ent)

		local isply=ent:IsPlayer()

		if isply or ent:GetClass()=="prop_ragdoll" then
			if isply then
				wep:EmitSound("Bat.Squeak")
			end
			util.Effect("BloodImpact", edata)
		else
			util.Effect("Impact",edata)
		end
    end)
end

if SERVER then
	util.AddNetworkString("HomerunSqueak")
end

hook.Add("OnEntityCreated", "PatchHomerunBatToSqueak", function(bat)
	if not IsValid(bat) then return end
	timer.Simple(1, function()
		if bat and bat.ClassName == "weapon_ttt_homebat" then
			if bat.PrimaryAttack then
				bat.PrimaryAttack = function()
					local ply,wep=bat.Owner,bat.Weapon
					local isJester = false
					if IsValid(ply) and ply:IsPlayer() and ply:GetTeam() == TEAM_JESTER then 
						isJester = true 
					end
						
					wep:SetNextPrimaryFire(CurTime()+bat.Primary.Delay)
					if !IsValid(ply) or wep:Clip1()<=0 then return end

					ply:SetAnimation(PLAYER_ATTACK1)
					wep:SendWeaponAnim(ACT_VM_MISSCENTER)
					wep:EmitSound("Bat.Swing")

					local av,spos,tr=ply:GetAimVector(),ply:GetShootPos()
					local epos=spos+av*bat.Range
					local kmins = Vector(1,1,1) * 7
					local kmaxs = Vector(1,1,1) * 7

					bat.Owner:LagCompensation( true )

					local tr = util.TraceHull({start=spos, endpos=epos, filter=ply, mask=MASK_SHOT_HULL, mins=kmins, maxs=kmaxs})

					-- Hull might hit environment stuff that line does not hit
					if not IsValid(tr.Entity) then
						tr = util.TraceLine({start=spos, endpos=epos, filter=ply, mask=MASK_SHOT_HULL})
					end

					bat.Owner:LagCompensation( false )

					local ent=tr.Entity

				if !tr.Hit or !(tr.HitWorld or IsValid(ent)) then return end

				if ent:GetClass()=="prop_ragdoll" then
					ply:FireBullets{Src=spos,Dir=av,Tracer=0,Damage=0}
				end
					
				if isJester then wep:SetNextPrimaryFire(CurTime()+wep.Primary.Delay*1.5) end

				-- Check if marked player hitting marker
				local isMarkedHittingMarker = false
				if IsValid(ply) and ply:IsPlayer() and IsValid(ent) and ent:IsPlayer() then
					if MARKER_DATA and MARKER_DATA.IsMarked and ent:GetTeam() == TEAM_MARKER and MARKER_DATA:IsMarked(ply) then
						isMarkedHittingMarker = true
					end
				end

				if CLIENT then return end

				if isJester or isMarkedHittingMarker then
					net.Start("HomerunSqueak")
					net.WriteTable(tr)
					net.WriteEntity(ply)
					net.WriteEntity(wep)
					net.Broadcast()
					
					-- Don't do damage if marked hitting marker
					if isMarkedHittingMarker then
						return
					end
				else
						net.Start("Bat Primary Hit")
						net.WriteTable(tr)
						net.WriteEntity(ply)
						net.WriteEntity(wep)
						net.Broadcast()

						local isply=ent:IsPlayer()

						if isply then
							bat:TakePrimaryAmmo(1)

							wep:SetNextPrimaryFire(CurTime()+wep.Primary.Delay*2)

							if ent:GetMoveType()==MOVETYPE_LADDER then ent:SetMoveType(MOVETYPE_WALK) end

							local boost=wep.VelocityBoostAmount
							ent:SetVelocity(ply:GetVelocity()+Vector(av.x,av.y,math.max(1,av.z+.35))*math.Rand(boost*.8,boost*1.2)*2)
							ent.was_pushed = {att=bat.Owner, t=CurTime(), wep=bat:GetClass()}
						elseif ent:GetClass()=="prop_physics" then
							local phys=ent:GetPhysicsObject()
							if IsValid(phys) then
								local boost=wep.VelocityBoostAmount
								phys:ApplyForceOffset(ply:GetVelocity()+Vector(av.x,av.y,math.max(1,av.z+.35))*math.Rand(boost*4,boost*8),tr.HitPos)
							end
						end

						do
							local dmg=DamageInfo()
							dmg:SetDamage(isply and bat.Primary.Damage or bat.Primary.Damage*.5)
							dmg:SetAttacker(ply)
							dmg:SetInflictor(wep)
							dmg:SetDamageForce(av*2000)
							dmg:SetDamagePosition(ply:GetPos())
							dmg:SetDamageType(DMG_CLUB)
							ent:DispatchTraceAttack(dmg,tr)
						end

						if wep:Clip1()<=0 then
							timer.Simple(0.49,function() if IsValid(self) then self:Remove() RunConsoleCommand("lastinv") end end)
						end
					end
					
				end
			end
		end
	end)
end)