-- Fart Grenade Attribution Fix
-- This fixes the issue where players killed by the fart grenade show as killed by world
-- Credit: Snuffles the Fox

if SERVER then
    -- Define the sound variables locally in our script
    local fartSound = Sound("fart_1.wav")
    local dieSound = Sound("fart_2.wav")
    local throwSound = Sound("weapons/slam/throw.wav")
    
    local hurtSounds = {
        Sound("vo/npc/Barney/ba_ohshit03.wav"), 
        Sound("vo/k_lab/kl_ahhhh.wav"),
        Sound("vo/npc/male01/moan01.wav"),
        Sound("vo/npc/male01/moan04.wav"),
        Sound("vo/npc/male01/ohno.wav")
    }
    
    local hurtImpacts = {
        Sound("player/pl_pain5.wav"),
        Sound("player/pl_pain6.wav"),
        Sound("player/pl_pain7.wav")
    }
    
    -- Wait until the weapon is loaded
    hook.Add("InitPostEntity", "FixFartGrenadeAttribution", function()
        local SWEP = weapons.GetStored("weapon_fartgrenade")
        
        if SWEP then
            -- Store the original function to call it later
            local originalCreateGrenade = SWEP.CreateGrenade
            
            -- Override the CreateGrenade function
            SWEP.CreateGrenade = function(self, src, ang, vel, angimp, ply)
                local gren = ents.Create("prop_physics")
                if not IsValid(gren) then return end
                
                gren:SetPos(src)
                gren:SetAngles(ang)
                gren:SetModel("models/weapons/w_grenade.mdl")
                gren:SetOwner(ply)
                gren:SetGravity(0.4)
                gren:SetFriction(0.2)
                gren:SetElasticity(0.45)
                
                -- Store the thrower in a networked variable
                gren.GrenadeOwner = ply
                
                gren:Spawn()
                gren:PhysWake()
                
                timer.Simple(3, function()
                    if not IsValid(gren) then return end
                    
                    ParticleEffect("fartsmoke", gren:GetPos()+Vector(-80,-40,0), Angle(0,0,0), nil)
                    gren:EmitSound(fartSound)
                    local v = {}
                    
                    timer.Create("fartsmoke_"..gren:EntIndex(), 0.5, 24, function()
                        if IsValid(gren) then
                            local left = timer.RepsLeft("fartsmoke_"..gren:EntIndex())
                            local players = player.GetAll()
                            local attacker = IsValid(gren.GrenadeOwner) and gren.GrenadeOwner or nil
                            
                            for p in pairs(player.GetAll()) do
                                local ply = players[p]
                                if not IsValid(ply) then continue end
                                
                                local vel = ply:GetVelocity()
                                local dir = (ply:GetPos()-gren:GetPos()):GetNormalized()
                                
                                local dmg_rate = math.Clamp(ply:GetPos():Distance(gren:GetPos()),0,420)
                                dmg_rate = (1-((1/420)*dmg_rate))
                                
                                local zdist = ply:GetPos().z-gren:GetPos().z
                                if(zdist < 0) then zdist = zdist*-1 end
                                
                                if(dmg_rate <= 0 || zdist >= 160 || !ply:Alive()) then continue end
                                
                                local force = vel+dmg_rate*500*dir
                                local isDead = ply:Health()-10 <= 0
                                
                                -- Use the stored attacker instead of self
                                if attacker then
                                    -- Create a damage info object for better attribution
                                    local dmg = DamageInfo()
                                    dmg:SetAttacker(attacker)
                                    dmg:SetInflictor(gren)
                                    dmg:SetDamage(10)
                                    dmg:SetDamageType(DMG_POISON)
                                    ply:TakeDamageInfo(dmg)
                                else
                                    ply:TakeDamage(10, gren, gren)
                                end
                                
                                ply:ScreenFade(SCREENFADE.IN, Color(255, 155, 0, 128), 0.3, 0)
                                ply:SetVelocity(force)
                                
                                if(!IsValid(v[ply:EntIndex()])) then
                                    ply:EmitSound(hurtSounds[math.random(1,5)])
                                    v[ply:EntIndex()] = ply
                                end
                                
                                if(ply:Health() > 0) then
                                    ply:EmitSound(hurtImpacts[math.random(1,3)])
                                end
                                
                                if(isDead) then
                                    ply:EmitSound(dieSound)
                                end
                            end
                            
                            if(left == 0) then
                                gren:Remove()
                            end 
                        end
                    end)
                end)
                
                local phys = gren:GetPhysicsObject()
                if IsValid(phys) then
                    phys:SetVelocity(vel)
                    phys:AddAngleVelocity(angimp)
                end
            end
        end
    end)
end