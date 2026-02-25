-- Extinguisher PAP Jarate Buff
-- This script makes the fire extinguisher clean off PAP viral jarate and provide immunity
-- Credit: Snuffles the Fox

-- Create console command for overlay toggle
local jarate_overlay_enabled = CreateConVar("ttt_jarate_overlay", "1", {FCVAR_ARCHIVE, FCVAR_USERINFO}, "Enable/disable jarate screen overlay effect (1 = enabled, 0 = disabled)")

if SERVER then
    -- Track who has temporary immunity
    local jarateImmunity = {}
    
    -- Function to clean jarate off a player
    local function CleanJarateFromPlayer(ply)
        if not IsValid(ply) or not ply:IsPlayer() then return false end
        
        -- Check if player has PAP jarate effect OR regular jarate effect
        if ply.TTTPAPViralJarte or ply:GetNWBool("PissedOn") then
            -- Stop particles
            ply:StopParticles()
            
            -- Remove the specific particle effect
            net.Start("JarateCleanParticles")
            net.WriteEntity(ply)
            net.Broadcast()
            
            -- Remove the timer that would spread the effect (PAP jarate)
            timer.Remove("TTTPAPViralJarteSpread" .. ply:SteamID64())
            
            -- Remove the timer for regular jarate duration
            timer.Remove("PissedOff_" .. ply:EntIndex())
            
            -- Reset jarate flags
            ply.TTTPAPViralJarte = nil
            ply:SetNWBool("PissedOn", false)
            
            -- Give temporary immunity and set NWBool for client-side effects
            jarateImmunity[ply:SteamID64()] = CurTime() + 30
            ply:SetNWBool("PAPJarateImmune", true)
            
            -- Create a timer to remove immunity after 30 seconds
            timer.Create("JarateImmunity_" .. ply:SteamID64(), 30, 1, function()
                if IsValid(ply) then
                    ply:SetNWBool("PAPJarateImmune", false)
                    jarateImmunity[ply:SteamID64()] = nil
                    ply:PrintMessage(HUD_PRINTCENTER, "Your jarate immunity has worn off!")
                end
            end)
            
            -- Notify the player
            ply:PrintMessage(HUD_PRINTCENTER, "Jarate washed off! Immunity for 30 seconds.")
            ply:PrintMessage(HUD_PRINTTALK, "The extinguisher has cleaned the jarate off you! You're immune to it for 30 seconds.")
            
            ply:EmitSound("vo/npc/male01/finally.wav")
            
            return true
        end
        
        return false
    end
    
    -- Network strings
    util.AddNetworkString("JarateCleanParticles")
    util.AddNetworkString("JarateImmunityEffect")
    
    -- Helper function to check if a player has immunity
    local function HasJarateImmunity(ply)
        if not IsValid(ply) or not ply:IsPlayer() then return false end
        local steamID = ply:SteamID64()
        local hasImmunity = jarateImmunity[steamID] and jarateImmunity[steamID] > CurTime()
        return hasImmunity
    end
    
    -- Hook into the extinguisher's custom function
    hook.Add("ExtinguisherDoExtinguish", "ExtinguisherCleanJarate", function(prop)
        if IsValid(prop) and prop:IsPlayer() then
            -- Only clean jarate and add immunity if infected - no immunity for non-infected players
            if CleanJarateFromPlayer(prop) then
                return true
            end
        end
    end)

    -- Hook to make regular jarate also respect immunity
    hook.Add("OnEntityCreated", "ExtinguisherJarateImmunityFix", function(ent)
        if not IsValid(ent) then return end
        
        -- Wait a tick for the entity to fully initialize
        timer.Simple(0, function()
            if not IsValid(ent) then return end
            
            local class = ent:GetClass()
            
            -- Handle PAP jarate
            if class == "ttt_pap_jarate_proj" then
                -- Store the original Explode function
                local originalExplode = ent.Explode
                if not originalExplode then return end
                
                -- Override the Explode function to use our immunity-aware SpreadPee
                ent.Explode = function(self, tr)
                    if SERVER then
                        self:SetNoDraw(true)
                        self:SetSolid(SOLID_NONE)

                        if tr.Fraction ~= 1.0 then
                            self:SetPos(tr.HitPos + tr.HitNormal * 0.6)
                        end

                        local pos = self:GetPos()
                        self:Remove()
                        
                        -- Our immunity-aware SpreadPee function
                        for _, ent in ipairs(ents.FindInSphere(pos, 400)) do
                            if IsValid(ent) and ent:IsPlayer() and ent:Alive() and not ent:IsSpec() and not ent.TTTPAPViralJarte then
                                
                                -- IMMUNITY CHECK - skip infection silently for immune players
                                if HasJarateImmunity(ent) then
                                    -- Skip infection silently
                                    continue
                                end
                                
                                -- Standard infection logic for non-immune players
                                ParticleEffectAttach("peejar_drips", PATTACH_POINT_FOLLOW, ent, ent:LookupAttachment("eyes"))
                                ent:SetNWBool("PissedOn", true)

                                if not ent.TTTPAPViralJarte then
                                    ent:PrintMessage(HUD_PRINTCENTER, "You're infected with jarate!")
                                    ent:PrintMessage(HUD_PRINTTALK, "You're infected with jarate, you'll take double damage!\nFind some water or an extinguisher to clean it off!")
                                end

                                ent.TTTPAPViralJarte = true
                                ent:EmitSound("vo/npc/male01/goodgod.wav")
                                local timerName = "TTTPAPViralJarteSpread" .. ent:SteamID64()

                                timer.Create(timerName, 3, 0, function()
                                    if not IsValid(ent) or not ent:Alive() or ent:IsSpec() or GetRoundState() ~= ROUND_ACTIVE or not ent.TTTPAPViralJarte or not ent:GetNWBool("PissedOn") then
                                        timer.Remove(timerName)
                                        return
                                    end

                                    -- Recursion - but now using our immunity-aware spreading
                                    local spreadPos = ent:GetPos()
                                    for _, spreadEnt in ipairs(ents.FindInSphere(spreadPos, 400)) do
                                        if IsValid(spreadEnt) and spreadEnt:IsPlayer() and spreadEnt:Alive() and not spreadEnt:IsSpec() and not spreadEnt.TTTPAPViralJarte then
                                            
                                            -- IMMUNITY CHECK for spreading
                                            if HasJarateImmunity(spreadEnt) then
                                                continue
                                            end
                                            
                                            -- Apply infection to non-immune players
                                            ParticleEffectAttach("peejar_drips", PATTACH_POINT_FOLLOW, spreadEnt, spreadEnt:LookupAttachment("eyes"))
                                            spreadEnt:SetNWBool("PissedOn", true)

                                            if not spreadEnt.TTTPAPViralJarte then
                                                spreadEnt:PrintMessage(HUD_PRINTCENTER, "You're infected with jarate!")
                                                spreadEnt:PrintMessage(HUD_PRINTTALK, "You're infected with jarate, you'll take double damage!\nFind some water or an extinguisher to clean it off!")
                                            end

                                            spreadEnt.TTTPAPViralJarte = true
                                            spreadEnt:EmitSound("vo/npc/male01/goodgod.wav")
                                            local spreadTimerName = "TTTPAPViralJarteSpread" .. spreadEnt:SteamID64()

                                            timer.Create(spreadTimerName, 3, 0, function()
                                                if not IsValid(spreadEnt) or not spreadEnt:Alive() or spreadEnt:IsSpec() or GetRoundState() ~= ROUND_ACTIVE or not spreadEnt.TTTPAPViralJarte or not spreadEnt:GetNWBool("PissedOn") then
                                                    timer.Remove(spreadTimerName)
                                                    return
                                                end

                                                -- Continue the recursive spreading
                                                local recursiveSpreadPos = spreadEnt:GetPos()
                                                for _, recursiveEnt in ipairs(ents.FindInSphere(recursiveSpreadPos, 400)) do
                                                    if IsValid(recursiveEnt) and recursiveEnt:IsPlayer() and recursiveEnt:Alive() and not recursiveEnt:IsSpec() and not recursiveEnt.TTTPAPViralJarte then
                                                        
                                                        -- IMMUNITY CHECK for recursive spreading
                                                        if HasJarateImmunity(recursiveEnt) then
                                                            continue
                                                        end
                                                        
                                                        -- Apply recursive infection
                                                        ParticleEffectAttach("peejar_drips", PATTACH_POINT_FOLLOW, recursiveEnt, recursiveEnt:LookupAttachment("eyes"))
                                                        recursiveEnt:SetNWBool("PissedOn", true)
                                                        recursiveEnt.TTTPAPViralJarte = true
                                                        recursiveEnt:EmitSound("vo/npc/male01/goodgod.wav")
                                                        
                                                        if not recursiveEnt.TTTPAPViralJarte then
                                                            recursiveEnt:PrintMessage(HUD_PRINTCENTER, "You're infected with jarate!")
                                                            recursiveEnt:PrintMessage(HUD_PRINTTALK, "You're infected with jarate, you'll take double damage!\nFind some water or an extinguisher to clean it off!")
                                                        end
                                                    end
                                                end
                                            end)
                                        end
                                    end
                                end)
                            end
                        end
                        
                        -- Create the visual effects
                        local effect = EffectData()
                        effect:SetStart(pos)
                        effect:SetOrigin(pos)

                        if tr.Fraction ~= 1.0 then
                            effect:SetNormal(tr.HitNormal)
                        end

                        util.Effect("AntlionGib", effect, true, true)
                        sound.Play("ambient/water/water_splash2.wav", pos, 100, 100)
                    else
                        -- Client side effects
                        local spos = self:GetPos()

                        local trs = util.TraceLine({
                            start = spos + Vector(0, 0, 64),
                            endpos = spos + Vector(0, 0, -128),
                            filter = self
                        })

                        util.Decal("YellowBlood", trs.HitPos + trs.HitNormal, trs.HitPos - trs.HitNormal)
                        self:SetDetonateExact(0)
                    end
                end
                
            -- Handle regular jarate
            elseif class == "ttt_jarate_proj" then
                -- Store the original Explode function
                local originalExplode = ent.Explode
                if not originalExplode then return end
                
                -- Override the Explode function to check immunity
                ent.Explode = function(self, tr)
                    if SERVER then
                        self:SetNoDraw(true)
                        self:SetSolid(SOLID_NONE)

                        if tr.Fraction ~= 1.0 then
                            self:SetPos(tr.HitPos + tr.HitNormal * 0.6)
                        end

                        local pos = self:GetPos()
                        self:Remove()
                        
                        -- Immunity-aware regular jarate spread
                        local radius = 250
                        local jarateConVar = GetConVar("ttt_jarate_duration")
                        local duration = jarateConVar and jarateConVar:GetInt() or 10

                        for k, target in pairs(ents.FindInSphere(pos, radius)) do
                            if IsValid(target) and target:IsPlayer() and (not target:IsFrozen()) and (not target:IsSpec()) then
                                -- IMMUNITY CHECK
                                if HasJarateImmunity(target) then
                                    continue
                                end
                                
                                -- Tell all hit players to get pissed on
                                ParticleEffectAttach("peejar_drips", PATTACH_POINT_FOLLOW, target, target:LookupAttachment("eyes"))
                                target:SetNWBool("PissedOn", true)
                                target:EmitSound("bot/i_cant_see.wav")
                                timer.Create("PissedOff_" .. target:EntIndex(), duration, 1, function()
                                    if IsValid(target) then
                                        target:StopParticles()
                                        target:SetNWBool("PissedOn", false)
                                        if target:Alive() then
                                            target:EmitSound("bot/oh_man.wav")
                                        end
                                    end
                                end)
                            end
                        end
                        
                        -- Create the visual effects
                        local effect = EffectData()
                        effect:SetStart(pos)
                        effect:SetOrigin(pos)

                        if tr.Fraction ~= 1.0 then
                            effect:SetNormal(tr.HitNormal)
                        end

                        util.Effect("AntlionGib", effect, true, true)
                        sound.Play("jarate/jar_explode.wav", pos, 100, 100)
                    else
                        -- Client side effects
                        local spos = self:GetPos()

                        local trs = util.TraceLine({
                            start = spos + Vector(0, 0, 64),
                            endpos = spos + Vector(0, 0, -128),
                            filter = self
                        })

                        util.Decal("YellowBlood", trs.HitPos + trs.HitNormal, trs.HitPos - trs.HitNormal)
                        self:SetDetonateExact(0)
                    end
                end
            end
        end)
    end)
    
    -- Block damage modification for immune players
    hook.Add("EntityTakeDamage", "JarateImmunityDamageProtection", function(target, dmginfo)
        if IsValid(target) and target:IsPlayer() and HasJarateImmunity(target) then
            -- If player has viral jarate immunity, prevent extra damage
            dmginfo:ScaleDamage(0.5)
        end
    end)
    
    -- Clean up immunity list on round end
    hook.Add("TTTPrepareRound", "CleanJarateImmunity", function()
        for steamID, _ in pairs(jarateImmunity) do
            timer.Remove("JarateImmunity_" .. steamID)
        end
        
        jarateImmunity = {}
        
        for _, ply in ipairs(player.GetAll()) do
            ply:SetNWBool("PAPJarateImmune", false)
        end
    end)
    
    -- Handle disconnects
    hook.Add("PlayerDisconnected", "CleanJarateImmunityOnDisconnect", function(ply)
        if ply:SteamID64() then
            timer.Remove("JarateImmunity_" .. ply:SteamID64())
            jarateImmunity[ply:SteamID64()] = nil
        end
    end)
end

-- Client side effects
if CLIENT then
    -- Override the jarate overlay rendering to respect the console command
    local lastTexture = nil
    local mat_Overlay = nil

    local function DrawMaterialOverlay( texture, refractamount )
        if ( texture ~= lastTexture or mat_Overlay == nil ) then
            mat_Overlay = Material( texture )
            lastTexture = texture
        end

        if ( mat_Overlay == nil || mat_Overlay:IsError() ) then return end

        render.UpdateScreenEffectTexture()

        mat_Overlay:SetFloat( "$envmap", 0 )
        mat_Overlay:SetFloat( "$envmaptint", 0 )
        mat_Overlay:SetFloat( "$refractamount", refractamount )
        mat_Overlay:SetInt( "$ignorez", 1 )

        render.SetMaterial( mat_Overlay )
        render.DrawScreenQuad()
    end

    -- We need to override this more aggressively since the original jarate keeps adding it back
    local function OverrideJarateOverlay()
        -- Remove any existing overlay hooks
        hook.Remove("RenderScreenspaceEffects", "RenderMaterialOverlay")
        
        -- Add our controlled version
        hook.Add("RenderScreenspaceEffects", "RenderMaterialOverlay", function()
            local ply = LocalPlayer()
            if not IsValid(ply) then return end
            
            -- Check if overlay is enabled via console command
            if not jarate_overlay_enabled:GetBool() then return end
            
            -- Show overlay if player has jarate effect
            if ply:GetNWBool("PissedOn") then 
                local overlay = "effects/tp_refract"
                DrawMaterialOverlay( overlay, 0.05 )
            end
        end)
    end

    -- Override immediately
    OverrideJarateOverlay()
    
    -- Also override it when the original jarate entity loads (since it adds the hook in its Initialize)
    hook.Add("OnEntityCreated", "OverrideJarateOverlayHook", function(ent)
        if IsValid(ent) and ent:GetClass() == "ttt_jarate_proj" then
            -- Wait a tick for the entity to fully initialize and add its hook
            timer.Simple(0.1, function()
                OverrideJarateOverlay()
            end)
        end
    end)
    
    -- Network handler to clean particles
    net.Receive("JarateCleanParticles", function()
        local ply = net.ReadEntity()
        if IsValid(ply) then
            ply:StopParticles()
            
            -- Multiple StopParticles to ensure cleanup
            timer.Create("CleanJarateEffect_" .. ply:EntIndex(), 0.1, 5, function()
                if IsValid(ply) then
                    ply:StopParticles()
                end
            end)
        end
    end)
    
    -- Network handler for immunity visual effect
    net.Receive("JarateImmunityEffect", function()
        local ply = net.ReadEntity()
        if IsValid(ply) then
            local pos = ply:GetPos() + Vector(0, 0, 40)
            local emitter = ParticleEmitter(pos)
            
            for i = 1, 10 do
                local particle = emitter:Add("effects/splash4", pos)
                if particle then
                    particle:SetVelocity(VectorRand() * 70)
                    particle:SetDieTime(0.5)
                    particle:SetStartAlpha(255)
                    particle:SetEndAlpha(0)
                    particle:SetStartSize(10)
                    particle:SetEndSize(2)
                    particle:SetRoll(math.Rand(0, 360))
                    particle:SetColor(50, 150, 255)
                end
            end
            
            emitter:Finish()
            
            -- Play a sound
            ply:EmitSound("physics/glass/glass_bottle_break2.wav", 75, 150)
        end
    end)
    
    -- Add visual feedback for immunity
    hook.Add("Think", "JarateImmunityVisuals", function()
        local ply = LocalPlayer()
        if not IsValid(ply) then return end
        
        -- Check if we have immunity
        if ply:GetNWBool("PAPJarateImmune") and (not ply.NextJarateImmuneParticle or ply.NextJarateImmuneParticle < CurTime()) then
            -- Add shield particle effect occasionally
            local attachment = ply:LookupAttachment("chest")
            if attachment and attachment > 0 then
                local effectData = EffectData()
                effectData:SetEntity(ply)
                effectData:SetAttachment(attachment)
                util.Effect("water_splash", effectData)
            end
            ply.NextJarateImmuneParticle = CurTime() + 2
            
            -- Forcibly clear any jarate particles just in case
            ply:StopParticles()
        end
    end)
    
    -- Add HUD effect to show immunity status
    hook.Add("HUDPaint", "JarateImmunityHUD", function()
        local ply = LocalPlayer()
        if not IsValid(ply) or not ply:Alive() or ply:IsSpec() then return end
        
        if ply:GetNWBool("PAPJarateImmune") then
            local scrW, scrH = ScrW(), ScrH()
            local width = 200
            local height = 30
            local x = scrW - width - 20
            local y = scrH / 2
            
            -- Draw background
            draw.RoundedBox(8, x, y, width, height, Color(0, 0, 0, 150))
            
            -- Draw text
            draw.SimpleText("Jarate Immunity Active", "DermaDefault", x + width/2, y + 6, Color(150, 220, 255), TEXT_ALIGN_CENTER)
            
            -- Draw border
            surface.SetDrawColor(50, 150, 255, math.sin(CurTime() * 5) * 100 + 155)
            surface.DrawOutlinedRect(x, y, width, height, 2)
        end
    end)
end