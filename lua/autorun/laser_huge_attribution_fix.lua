-- TTT Laser Huge Attribution Fix
-- This fixes the damage attribution for the Laser Huge weapon's projectiles

if SERVER then
    -- Define the damage multiplier locally (copied from original code)
    local dmgmult = 0.65
    
    -- Define the distotime function locally (copied from original code)
    local function distotime(dis)
        return math.min(1, 0.02+0.1*dis/600)
    end

    -- Wait until the addon is loaded
    hook.Add("InitPostEntity", "FixLaserHugeAttribution", function()
        -- Check if the entity class exists
        if scripted_ents.GetStored("ttt_laser_bullet_ent") then
            local ENT = scripted_ents.GetStored("ttt_laser_bullet_ent").t
            
            -- Fix the network receive function for smoke trace detection FIRST
            -- (to ensure it's patched before any StartTouch can use it)
            net.Receive("smoketracedetection2", function() 
                local dmg = net.ReadFloat()
                local entity = net.ReadEntity()
                local swepp = net.ReadEntity()
                local swepowner = net.ReadEntity()
                
                -- Make sure we have valid entities
                if IsValid(entity) and IsValid(swepp) and IsValid(swepowner) then
                    -- Fix: Use swepowner instead of sweppr (typo in original code)
                    entity:TakeDamage(dmg, swepowner, swepp)
                end
            end)
            
            -- Store the original StartTouch function
            local originalStartTouch = ENT.StartTouch
            
            -- Override the StartTouch function with our fixed version
            ENT.StartTouch = function(self, entity)
                if entity:IsPlayer() and entity:Alive() then
                    if self.SWEP.hitplys[self.currentbulletidx][entity] then
                        -- Already hit this player, do nothing
                    else
                        self.SWEP.hitplys[self.currentbulletidx][entity] = true
                        local tr = util.TraceLine({
                            start = entity:EyePos(),
                            endpos = self.Owner:EyePos(),
                            mask = MASK_SHOT_PORTAL,
                            collisiongroup = COLLISION_GROUP_DEBRIS
                        })
                        
                        if (tr.Entity:IsValid() or tr.Entity == game.GetWorld()) then
                            -- Direct line of sight - apply damage directly
                            entity:TakeDamage(self.damage * dmgmult, self.Owner, self.SWEP)
                        else
                            -- Through smoke - use network to check client-side smoke
                            -- Use SafeNetStart to avoid conflicts with other addons
                            timer.Simple(0, function()
                                if IsValid(self) and IsValid(entity) and IsValid(self.Owner) and IsValid(self.SWEP) then
                                    net.Start("smoketracedetection")
                                    net.WriteEntity(entity)
                                    net.WriteEntity(self.SWEP)
                                    net.WriteFloat(self.damage)
                                    net.Send(self.Owner)
                                end
                            end)
                        end
                        
                        -- Send hit notification - delay slightly to avoid conflicts
                        timer.Simple(0.01, function()
                            if IsValid(self) and IsValid(entity) and IsValid(self.Owner) then
                                local dis = entity:GetPos():Distance(self.Owner:GetPos())
                                net.Start("updatelastlaserhugehits")
                                net.WriteFloat(CurTime() + distotime(dis))
                                net.WriteEntity(entity)
                                net.Send(self.Owner)
                            end
                        end)
                    end
                end
            end
        end
    end)
end