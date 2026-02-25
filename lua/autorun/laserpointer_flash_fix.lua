-- Laser Pointer Flash Fix
-- Replaces the white flash effect with a freeze-frame effect that's safer for people with epilepsy

if CLIENT then
    -- Variables to store our screenshot and effect state
    local freezeFrameTexture = nil
    local freezeFrameMaterial = nil
    local freezeFrameActive = false
    local freezeEndTime = 0
    local freezeDuration = 2.5 -- Same as the original FLASH_DURATION
    local dieTimer = 1.5 -- Same as the original DIETIMER
    
    -- Create render target and material for the screenshot
    local function SetupRenderTarget()
        if not freezeFrameTexture then
            local screenW, screenH = ScrW(), ScrH()
            freezeFrameTexture = GetRenderTarget("LaserPointerFreezeFrame_RT", screenW, screenH, false)
            
            freezeFrameMaterial = CreateMaterial("LaserPointerFreezeFrame", "UnlitGeneric", {
                ["$basetexture"] = freezeFrameTexture:GetName(),
                ["$translucent"] = 1,
                ["$vertexalpha"] = 1,
                ["$vertexcolor"] = 1
            })
        end
    end
    
    -- Helper function to draw a subtle white edge glow
    local function DrawSubtleEdgeGlow(alpha)
        local screenW, screenH = ScrW(), ScrH()
        
        -- Just draw a subtle white border around the edges of the screen
        local borderSize = math.min(screenW, screenH) * 0.15 -- 15% of the smaller screen dimension
        
        -- Top border (fades from white to transparent)
        surface.SetDrawColor(255, 255, 255, alpha)
        for i = 0, borderSize do
            local edgeAlpha = alpha * (1 - (i / borderSize))
            surface.SetDrawColor(255, 255, 255, edgeAlpha)
            surface.DrawRect(0, i, screenW, 1)
        end
        
        -- Bottom border (fades from white to transparent)
        for i = 0, borderSize do
            local edgeAlpha = alpha * (1 - (i / borderSize))
            surface.SetDrawColor(255, 255, 255, edgeAlpha)
            surface.DrawRect(0, screenH - i - 1, screenW, 1)
        end
        
        -- Left border (fades from white to transparent)
        for i = 0, borderSize do
            local edgeAlpha = alpha * (1 - (i / borderSize))
            surface.SetDrawColor(255, 255, 255, edgeAlpha)
            surface.DrawRect(i, 0, 1, screenH)
        end
        
        -- Right border (fades from white to transparent)
        for i = 0, borderSize do
            local edgeAlpha = alpha * (1 - (i / borderSize))
            surface.SetDrawColor(255, 255, 255, edgeAlpha)
            surface.DrawRect(screenW - i - 1, 0, 1, screenH)
        end
    end
    
    -- Initialize on game load
    hook.Add("Initialize", "LaserPointerFreezeFrame_Setup", SetupRenderTarget)
    
    -- Remove the original flash hook and add our own
    hook.Add("InitPostEntity", "LaserPointerFlashFix_Replace", function()
        timer.Simple(2, function()
            -- Remove the original flash hook if it exists
            hook.Remove("HUDPaint", "SimulateFlash_REALCS_NOT_ANYTHINGELSE")
            
            -- Add our safer version
            hook.Add("HUDPaint", "LaserPointer_SafeFlashEffect", function()
                local ply = LocalPlayer()
                local endTime = ply:GetNWFloat("RCS_flashed_time")
                
                -- If we're flashed and the effect isn't active yet, take a screenshot
                if endTime > CurTime() and not freezeFrameActive then
                    -- Make sure we have our render target
                    SetupRenderTarget()
                    
                    -- Capture the current screen
                    render.CopyRenderTargetToTexture(freezeFrameTexture)
                    
                    -- Set the effect as active
                    freezeFrameActive = true
                    freezeEndTime = endTime
                end
                
                -- If the effect is active, display the frozen frame with fading alpha
                if freezeFrameActive then
                    -- Calculate alpha based on remaining time
                    local alpha = 255
                    local edgeAlpha = 40 -- Very subtle edge glow (reduced from 100)
                    
                    if freezeEndTime - CurTime() <= dieTimer then
                        local pf = 1 - (CurTime() - (freezeEndTime - dieTimer)) / dieTimer
                        alpha = pf * 255
                        edgeAlpha = pf * 40
                    end
                    
                    -- Draw the frozen frame
                    surface.SetDrawColor(255, 255, 255, math.Round(alpha))
                    surface.SetMaterial(freezeFrameMaterial)
                    surface.DrawTexturedRect(0, 0, ScrW(), ScrH())
                    
                    -- Draw a very subtle edge glow
                    DrawSubtleEdgeGlow(edgeAlpha)
                    
                    -- Deactivate when the effect is done
                    if CurTime() >= freezeEndTime then
                        freezeFrameActive = false
                    end
                end
            end)
        end)
    end)
    
    -- Remove the original blur hook and add our own with reduced intensity
    hook.Add("InitPostEntity", "LaserPointerBlurFix_Replace", function()
        timer.Simple(2, function()
            -- Remove the original blur hook if it exists
            hook.Remove("RenderScreenspaceEffects", "SimulateBlur_REALCS_NOT_ANYTHINGELSE")
            
            -- Add our safer version
            hook.Add("RenderScreenspaceEffects", "LaserPointer_SafeBlurEffect", function()
                local ply = LocalPlayer()
                local endTime = ply:GetNWFloat("RCS_flashed_time")
                
                if endTime > CurTime() then
                    -- Reduced motion blur intensity by 90%
                    local blurAmount = 0.001 -- Original is 0.01
                    DrawMotionBlur(0, blurAmount, 0)
                else
                    DrawMotionBlur(0, 0, 0)
                end
            end)
        end)
    end)
end