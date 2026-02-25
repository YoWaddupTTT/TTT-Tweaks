-- Force Shield Weapon Override
-- Sets SWEP.Slot = 3, SWEP.Kind = WEAPON_NADE, SWEP.AutoSpawnable = true
-- Credit: Snuffles the Fox

local function PatchForceShieldWeapon(wep)
    if not IsValid(wep) then return end
    if wep:GetClass() ~= "weapon_ttt_force_shield" then return end

    wep.Slot = 3
    wep.Kind = WEAPON_NADE
    wep.AutoSpawnable = true
end

if SERVER then
    -- Patch weapon entity on spawn
    hook.Add("OnEntityCreated", "ForceShieldOverride_EntityCreated", function(ent)
        if IsValid(ent) and ent:GetClass() == "weapon_ttt_force_shield" then
            timer.Simple(0, function()
                if IsValid(ent) then
                    PatchForceShieldWeapon(ent)
                end
            end)
        end
    end)

    -- Patch weapon table at runtime
    hook.Add("InitPostEntity", "ForceShieldOverride_WeaponTable", function()
        timer.Simple(1, function()
            local wepTable = weapons.GetStored("weapon_ttt_force_shield")
            if wepTable then
                wepTable.Slot = 3
                wepTable.Kind = WEAPON_NADE
                wepTable.AutoSpawnable = true

                -- Patch Initialize and Deploy to enforce changes
                local origInit = wepTable.Initialize
                wepTable.Initialize = function(self, ...)
                    if origInit then origInit(self, ...) end
                    self.Slot = 3
                    self.Kind = WEAPON_NADE
                    self.AutoSpawnable = true
                end

                local origDeploy = wepTable.Deploy
                wepTable.Deploy = function(self, ...)
                    local result = true
                    if origDeploy then result = origDeploy(self, ...) end
                    self.Slot = 3
                    self.Kind = WEAPON_NADE
                    self.AutoSpawnable = true
                    return result
                end
            end
        end)
    end)
end

if CLIENT then
    -- Patch clientside weapon entity
    hook.Add("OnEntityCreated", "ForceShieldOverride_EntityCreated_Client", function(ent)
        if IsValid(ent) and ent:GetClass() == "weapon_ttt_force_shield" then
            timer.Simple(0, function()
                if IsValid(ent) then
                    PatchForceShieldWeapon(ent)
                end
            end)
        end
    end)
end