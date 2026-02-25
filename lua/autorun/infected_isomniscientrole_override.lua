-- Infected isOmniscientRole Override
-- This sets the isOmniscientRole flag for the infected role to true

if SERVER then
    hook.Add("InitPostEntity", "Infected_isOmniscientRole_Override", function()
        timer.Simple(1, function()
            local infectedRole = roles and roles.GetByName and roles.GetByName("infected")
            if infectedRole then
                infectedRole.isOmniscientRole = true
                infectedRole.omniscient = true
            end
        end)
    end)
end

if CLIENT then
    hook.Add("InitPostEntity", "Infected_isOmniscientRole_Override_Client", function()
        timer.Simple(1, function()
            local infectedRole = roles and roles.GetByName and roles.GetByName("infected")
            if infectedRole then
                infectedRole.isOmniscientRole = true
                infectedRole.omniscient = true
            end
        end)
    end)
end