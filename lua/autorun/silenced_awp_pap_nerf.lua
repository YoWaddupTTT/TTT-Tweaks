-- Silenced AWP PAP Nerf
-- Makes the Silenced AWP PAP upgrade use the AWP's unsilenced sound rather than the generic PAP shoot sound. 
-- Credit: Snuffles the Fox

-- Hook into weapon firing to override the sound for the unsilenced AWP upgrade
hook.Add("EntityFireBullets", "TTTPAP_UnsilencedAWP_SoundOverride", function(entity, bulletInfo)
    -- Check if entity is a weapon and has been Pack-a-Punched with unsilenced_awp
    if IsValid(entity) and entity.PAPUpgrade and entity.PAPUpgrade.id == "unsilenced_awp" then
        -- Play the unsilenced AWP sound instead of the default PAP sound
        entity:EmitSound("weapons/awp/awp1.wav")
        return true -- Don't block the bullets, just play our custom sound
    end
end)

-- Apply our changes to any weapons that get created with the unsilenced_awp upgrade
hook.Add("OnEntityCreated", "TTTPAP_UnsilencedAWP_Init", function(entity)
    -- Wait until entity is valid and initialized
    timer.Simple(0, function()
        if not IsValid(entity) or not entity:IsWeapon() then return end
        if not entity.PAPUpgrade or entity.PAPUpgrade.id ~= "unsilenced_awp" then return end
        
        -- Override the Primary.Sound property directly
        if entity.Primary then
            entity.Primary.Sound = "weapons/awp/awp1.wav"
        end
        
        -- Store the original FireSound function if it exists
        local originalFireSound = entity.FireSound
        
        -- Override the FireSound function
        entity.FireSound = function(self)
            self:EmitSound("weapons/awp/awp1.wav")
            -- Don't call the original to avoid double sounds
        end
    end)
end)

-- For weapons that are already in the world or get upgraded later
timer.Create("TTTPAP_UnsilencedAWP_CheckExisting", 1, 0, function()
    for _, entity in ipairs(ents.GetAll()) do
        if IsValid(entity) and entity:IsWeapon() and entity.PAPUpgrade and 
           entity.PAPUpgrade.id == "unsilenced_awp" and entity.Primary and 
           entity.Primary.Sound ~= "weapons/awp/awp1.wav" then
            
            -- Override the Primary.Sound property
            entity.Primary.Sound = "weapons/awp/awp1.wav"
            
            -- Override the FireSound function
            local originalFireSound = entity.FireSound
            entity.FireSound = function(self)
                self:EmitSound("weapons/awp/awp1.wav")
                -- Don't call the original to avoid double sounds
            end
        end
    end
end)