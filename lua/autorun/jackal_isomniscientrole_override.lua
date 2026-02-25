-- Jackal and Sidekick isOmniscientRole Override
-- This sets the isOmniscientRole flag for the jackal and sidekick roles to true

if SERVER then
    hook.Add("InitPostEntity", "Jackal_Sidekick_isOmniscientRole_Override", function()
        timer.Simple(1, function()
            local jackalRole = roles and roles.GetByName and roles.GetByName("jackal")
            if jackalRole then
                jackalRole.isOmniscientRole = true
                jackalRole.omniscient = true
            end

            local sidekickRole = roles and roles.GetByName and roles.GetByName("sidekick")
            if sidekickRole then
                sidekickRole.isOmniscientRole = true
                sidekickRole.omniscient = true
            end
        end)
    end)
end

if CLIENT then
    hook.Add("InitPostEntity", "Jackal_Sidekick_isOmniscientRole_Override_Client", function()
        timer.Simple(1, function()
            local jackalRole = roles and roles.GetByName and roles.GetByName("jackal")
            if jackalRole then
                jackalRole.isOmniscientRole = true
                jackalRole.omniscient = true
            end

            local sidekickRole = roles and roles.GetByName and roles.GetByName("sidekick")
            if sidekickRole then
                sidekickRole.isOmniscientRole = true
                sidekickRole.omniscient = true
            end
        end)
    end)
end