-- Kamehameha Damage Attribution Fix
-- This ensures that AOE damage from the Kamehameha blast is properly attributed to the shooter
-- Credit: Snuffles the Fox

if SERVER then
    -- Wait for all weapons to be loaded
    hook.Add("InitPostEntity", "KamehamehaAttribution_Fix", function()
        local weaponClass = "ttt_kamehameha_swep"
        local SWEP = weapons.GetStored(weaponClass)
        
        -- Check if weapon exists
        if not SWEP then
            
            -- Try again later in case the weapon loads after this
            timer.Simple(5, function()
                SWEP = weapons.GetStored(weaponClass)
                if not SWEP then
                    return
                end
                ApplyFix(SWEP)
            end)
            return
        end
        
        ApplyFix(SWEP)
    end)
    
    function ApplyFix(SWEP)
        -- Store original PrimaryAttack function
        local originalPrimaryAttack = SWEP.PrimaryAttack
        
        -- Override PrimaryAttack to fix damage attribution
        SWEP.PrimaryAttack = function(self)
            local ply = self.Owner
            local myposition = self.Owner:GetShootPos()
            local aimraytrace = myposition + (self.Owner:GetAimVector() * 70)

            local kmins = Vector(1,1,1) * -10
            local kmaxs = Vector(1,1,1) * 10

            local tr = util.TraceHull({start=myposition, endpos=aimraytrace, filter=self.Owner, mask=MASK_SHOT_HULL, mins=kmins, maxs=kmaxs})

            if not IsValid(tr.Entity) then
                tr = util.TraceLine({start=myposition, endpos=aimraytrace, filter=self.Owner, mask=MASK_SHOT_HULL})
            end
            
            if (self.Weapon:Clip1() < 50) then return end
            for k, v in pairs(player.GetAll()) do
                v:ConCommand("play weapons/shoot/kamehame.wav\n")
            end
            
            self.Weapon:SendWeaponAnim(ACT_VM_SECONDARYATTACK)
            timer.Create("timerUnFreezePlayer", 4.9, 1, function() 
                if ply:Alive() then
                    self.Owner:Freeze(false) 
                end
            end)
            
            timer.Create("FinalHA", 3.4, 1, function()
                if IsValid(self) and IsValid(self.Owner) and self.Owner:Alive() then
                    self.Owner:Freeze(true)
                    
                    for k, v in pairs(player.GetAll()) do
                        v:ConCommand("play weapons/shoot/ha.wav\n")
                    end
                    
                    timer.Create("Beam", 0.010, 50, function()
                        if IsValid(self) and IsValid(self.Owner) and self.Owner:Alive() then
                            local bullet = {} 
                            bullet.Src = self.Owner:GetShootPos() 
                            bullet.Dir = self.Owner:GetAimVector() 
                            bullet.Spread = Vector(0, 0, 0)
                            bullet.Num = 1
                            bullet.Tracer = 1
                            bullet.Damage = 30
                            bullet.TracerName = "kamebeam"
                            self:TakePrimaryAmmo(1)
                            self.Owner:FireBullets(bullet)
                            
                            local effects = EffectData()
                            local trace = self.Owner:GetEyeTrace()
                            
                            effects:SetOrigin(trace.HitPos + 
                            Vector(math.Rand(-0.5, 0.5), 
                                  math.Rand(-0.5, 0.5), 
                                  math.Rand(-0.5, 0.5)))
                            
                            effects:SetScale(10)
                            effects:SetRadius(200)
                            effects:SetMagnitude(3.1)
                            effects:SetAngles(Angle(0,90,0))
                            
                            util.Effect("beampact", effects)
                            
                            -- FIX: Properly pass the owner as the attacker parameter
                            util.BlastDamage(self, self.Owner, trace.HitPos, 200, 170)
                            
                            sound.Play("weapons/explosion/dbzexplosion.wav", trace.HitPos, 180)
                        end
                    end)
                end
            end)
            
            self:SetNextPrimaryFire(CurTime() + 0.5)
        end
    end
end