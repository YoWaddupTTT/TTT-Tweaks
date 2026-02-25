AddCSLuaFile()

if SERVER then return end

-- Climb Item - Disable Camera Roll
-- Keeps the sound, velocity boost, and fall damage immunity
-- Only removes the camera rolling effect when landing

hook.Add("Initialize", "Climb_DisableCameraRoll", function()
    net.Receive("ClimbRoll", function()
        net.ReadInt(16)
    end)
    
    hook.Remove("CalcView", "ClimbRollEffect")
end)