-- Detective Playercam Network Visibility Fix
-- This ensures players being viewed through the Detective's camera stay loaded
-- Credit: Snuffles the Fox

if SERVER then
    
    -- Track active camera relationships (who is viewing whom)
    local activeCameras = {}
    
    -- Add network message handler for camera close notification
    util.AddNetworkString("DetectiveCamFix_StopTracking")
    
    -- Add our own messages to track when camera is closed
    util.AddNetworkString("DetectiveCamFix_CameraOpened")
    util.AddNetworkString("DetectiveCamFix_CameraClosed")
    
    -- Modified weapon handling
    hook.Add("Initialize", "DetectiveCamFix_Setup", function()
        -- Hook into the weapon's PrimaryAttack function
        timer.Simple(5, function()
            local weaponMeta = weapons.GetStored("weapon_ttt_dete_playercam")
            if weaponMeta then
                -- Store the original PrimaryAttack function
                local originalPrimaryAttack = weaponMeta.PrimaryAttack
                
                -- Replace with our version that hooks into the bullet callback
                weaponMeta.PrimaryAttack = function(self)
                    local ply = self.Owner
                    
                    -- Bail if no ammo
                    if self:Clip1() <= 0 then 
                        return 
                    end
                    
                    -- Set up the bullet data
                    local Kugel = {}
                    Kugel.Dmgtype = "DMG_GENERIC"
                    Kugel.Num = 1 -- Was using 'num' but that's not defined
                    Kugel.Spread = Vector(self.Primary.Cone or 0.01, self.Primary.Cone or 0.01, 0)
                    Kugel.Tracer = 0
                    Kugel.Force = 0
                    Kugel.Damage = 0
                    Kugel.Src = self.Owner:GetShootPos()
                    Kugel.Dir = self.Owner:GetAimVector()
                    Kugel.TracerName = "TRACER_NONE"
                    
                    -- Modified callback that also tracks for PVS
                    Kugel.Callback = function(Schuetze, Ziel)
                        if SERVER and Ziel.Entity and Ziel.Entity:IsPlayer() then
                            -- Original functionality
                            net.Start("CamFensterDetePlyCam")
                            net.WriteEntity(Ziel.Entity)
                            net.Send(Schuetze)
                            self:TakePrimaryAmmo(1)
                            
                            -- Our new tracking for PVS
                            activeCameras[Schuetze:SteamID()] = {
                                viewer = Schuetze,
                                target = Ziel.Entity
                            }
                        end
                    end
                    
                    -- Fire the bullet with our enhanced callback
                    self.Owner:FireBullets(Kugel)
                    self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
                end
            end
        end)
    end)
    
    -- Listen for the original close message
    net.Receive("CamSchliessenDetePlyCam", function(len, ply)
        -- When we get the original close message, clean up our tracking
        if activeCameras[ply:SteamID()] then
            activeCameras[ply:SteamID()] = nil
        end
    end)
    
    -- Use SetupPlayerVisibility hook to ensure target is always visible
    hook.Add("SetupPlayerVisibility", "DetectiveCamFix_EnsureTargetVisible", function(ply, viewEntity)
        -- Check if this player is viewing someone
        if activeCameras[ply:SteamID()] then
            local camInfo = activeCameras[ply:SteamID()]
            
            -- If the target is valid, make sure they're visible
            if IsValid(camInfo.target) and camInfo.target:IsPlayer() and camInfo.target:Alive() then
                -- Add the target's position to the PVS for this player
                AddOriginToPVS(camInfo.target:GetPos())
                
                -- Also add the position around the target's head (where the camera actually is)
                local headPos = camInfo.target:GetBonePosition(camInfo.target:LookupBone("ValveBiped.Bip01_Head1") or 0)
                if headPos then
                    AddOriginToPVS(headPos)
                end
                
                -- Add what the target is looking at (to see what they see)
                local lookPos = camInfo.target:GetPos() + camInfo.target:GetAimVector() * 500
                AddOriginToPVS(lookPos)
                
                -- Add positions in a sphere around the player to ensure surroundings load
                local radius = 500
                for i = 0, 8 do
                    local angle = math.rad(i * 45)
                    local pos = camInfo.target:GetPos() + Vector(math.cos(angle) * radius, math.sin(angle) * radius, 0)
                    AddOriginToPVS(pos)
                    
                    -- Add positions above and below for vertical coverage
                    AddOriginToPVS(pos + Vector(0, 0, radius))
                    AddOriginToPVS(pos + Vector(0, 0, -radius))
                end
            else
                -- Target is no longer valid, clean up
                activeCameras[ply:SteamID()] = nil
            end
        end
    end)
    
    -- Handle player disconnects, deaths, round restart, etc.
    hook.Add("PlayerDisconnected", "DetectiveCamFix_CleanupOnDisconnect", function(ply)
        activeCameras[ply:SteamID()] = nil
        
        -- Also check if this player was being tracked by anyone
        for id, camInfo in pairs(activeCameras) do
            if camInfo.target == ply then
                if IsValid(camInfo.viewer) then
                    -- Notify the viewer their target disconnected
                    net.Start("DetectiveCamFix_StopTracking")
                    net.Send(camInfo.viewer)
                end
                activeCameras[id] = nil
            end
        end
    end)
    
    hook.Add("PlayerDeath", "DetectiveCamFix_CleanupOnDeath", function(victim, inflictor, attacker)
        -- Check if this player was being tracked by anyone
        for id, camInfo in pairs(activeCameras) do
            if camInfo.target == victim then
                -- The target died, but the client-side Think hook should handle closing the camera
                -- We'll just clean up our own tracking
                activeCameras[id] = nil
            end
        end
    end)
    
    hook.Add("TTTPrepareRound", "DetectiveCamFix_CleanupOnRoundReset", function()
        activeCameras = {}
    end)
    
    timer.Create("DetectiveCamFix_Maintenance", 5, 0, function()
        for id, camInfo in pairs(activeCameras) do
            if not IsValid(camInfo.target) or not camInfo.target:Alive() or not IsValid(camInfo.viewer) then
                activeCameras[id] = nil
            end
        end
    end)
end

if CLIENT then
    -- Handle notification that the target player disconnected
    net.Receive("DetectiveCamFix_StopTracking", function()
        if CamFrame and CamFrameOffen then
            CamFrame:Remove()
            CamFrameOffen = false
            
            -- Send the close message to get ammo back
            net.Start("CamSchliessenDetePlyCam")
            net.WriteEntity(LocalPlayer())
            net.SendToServer()
        end
    end)
end