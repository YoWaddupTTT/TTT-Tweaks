-- TTT2 Marker Vision Error Fix
-- Fixes two NULL entity errors in TTT2's marker_vision library:
-- 1. markerVision.Remove: "Tried to use a NULL entity!" when removing EFlags
-- 2. markerVision.Add: "Tried to use a NULL entity!" when adding EFlags
-- Credit: Snuffles the Fox

if SERVER then
    AddCSLuaFile()
end

-- Wait for TTT2 to fully initialize before patching
hook.Add("TTT2Initialize", "FixMarkerVisionNullEntityErrors", function()
    if not markerVision then
        ErrorNoHaltWithStack("TTT2 marker_vision library not found, can't apply fix")
        return
    end
    
    -- Fix 1: Patch markerVision.Add to check entity validity before AddEFlags
    local originalAdd = markerVision.Add
    
    markerVision.Add = function(ent, identifier)
        local _, index = markerVision.Get(ent, identifier)

        if index ~= -1 then
            table.remove(markerVision.registry, index)
        end

        local mvObject = table.Copy(MARKER_VISION_ELEMENT)
        mvObject:SetEnt(ent)
        mvObject:SetIdentifier(identifier)

        markerVision.registry[#markerVision.registry + 1] = mvObject

        -- Fix: Check if entity is valid before modifying it
        if IsValid(ent) then
            ent.ttt2MVTransmitOldFunc = ent.UpdateTransmitState

            ent.UpdateTransmitState = function()
                return TRANSMIT_ALWAYS
            end
            ent:AddEFlags(EFL_FORCE_CHECK_TRANSMIT)
        end

        return mvObject
    end
    
    -- Fix 2: Patch markerVision.Remove to check entity validity before RemoveEFlags
    local originalRemove = markerVision.Remove
    
    markerVision.Remove = function(ent, identifier)
        local _, index = markerVision.Get(ent, identifier)

        if index == -1 then
            return
        end

        table.remove(markerVision.registry, index)

        -- to simplify the networking and to prevent any artefacts due to
        -- role changes, a removal is broadcasted to everyone
        if SERVER then
            net.Start("ttt2_marker_vision_entity_removed")
            net.WriteEntity(ent)
            net.WriteString(identifier)
            net.Broadcast()
        end

        if CLIENT then
            marks.Remove({ ent })
        end

        -- Fix: Check if entity is valid before modifying it
        if IsValid(ent) then
            ent.UpdateTransmitState = ent.ttt2MVTransmitOldFunc
            ent:RemoveEFlags(EFL_FORCE_CHECK_TRANSMIT)
            ent.ttt2MVTransmitOldFunc = nil
        end
    end
end)

-- Alternative method using InitPostEntity in case TTT2Initialize isn't triggered
hook.Add("InitPostEntity", "FixMarkerVisionNullEntityErrors_Backup", function()
    -- Wait a bit to ensure TTT2 is fully loaded
    timer.Simple(3, function()
        if not markerVision or markerVision._fixed then return end
        
        -- Fix 1: Patch markerVision.Add to check entity validity before AddEFlags
        local originalAdd = markerVision.Add
        
        markerVision.Add = function(ent, identifier)
            local _, index = markerVision.Get(ent, identifier)

            if index ~= -1 then
                table.remove(markerVision.registry, index)
            end

            local mvObject = table.Copy(MARKER_VISION_ELEMENT)
            mvObject:SetEnt(ent)
            mvObject:SetIdentifier(identifier)

            markerVision.registry[#markerVision.registry + 1] = mvObject

            -- Fix: Check if entity is valid before modifying it
            if IsValid(ent) then
                ent.ttt2MVTransmitOldFunc = ent.UpdateTransmitState

                ent.UpdateTransmitState = function()
                    return TRANSMIT_ALWAYS
                end
                ent:AddEFlags(EFL_FORCE_CHECK_TRANSMIT)
            end

            return mvObject
        end
        
        -- Fix 2: Patch markerVision.Remove to check entity validity before RemoveEFlags
        local originalRemove = markerVision.Remove
        
        markerVision.Remove = function(ent, identifier)
            local _, index = markerVision.Get(ent, identifier)

            if index == -1 then
                return
            end

            table.remove(markerVision.registry, index)

            -- to simplify the networking and to prevent any artefacts due to
            -- role changes, a removal is broadcasted to everyone
            if SERVER then
                net.Start("ttt2_marker_vision_entity_removed")
                net.WriteEntity(ent)
                net.WriteString(identifier)
                net.Broadcast()
            end

            if CLIENT then
                marks.Remove({ ent })
            end

            -- Fix: Check if entity is valid before modifying it
            if IsValid(ent) then
                ent.UpdateTransmitState = ent.ttt2MVTransmitOldFunc
                ent:RemoveEFlags(EFL_FORCE_CHECK_TRANSMIT)
                ent.ttt2MVTransmitOldFunc = nil
            end
        end
        
        -- Mark as fixed to avoid double patching
        markerVision._fixed = true
    end)
end)