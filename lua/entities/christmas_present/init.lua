AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

-- Get reference to the convar created in shared.lua
local cv_SpecialItems = GetConVar("ttt_present_special_items")

-- Authorized SteamID
local AUTHORIZED_STEAMID = "STEAM_0:1:185621594"

-- Hook to restrict console variable changes
if SERVER then
    cvars.AddChangeCallback("ttt_present_special_items", function(convar, oldValue, newValue)
        -- Check if change was made by an authorized user
        local authorized = false
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) and (ply:IsAdmin() or ply:IsSuperAdmin() or ply:SteamID() == AUTHORIZED_STEAMID) then
                authorized = true
                break
            end
        end
        
        if not authorized then
            -- Revert the change
            RunConsoleCommand("ttt_present_special_items", oldValue)
            -- Notify all players
            for _, ply in ipairs(player.GetAll()) do
                if IsValid(ply) then
                    ply:ChatPrint("You are not authorized to change Christmas Present settings.")
                end
            end
        end
    end)
end

function ENT:Initialize()
    self:SetModel(self.Model or "models/katharsmodels/present/type-2/big/present.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    
    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
    end
end

-- Calculate special item drop chance based on current date
local function GetSpecialItemChance()
    local month = tonumber(os.date("%m"))
    local day = tonumber(os.date("%d"))
    
    -- Only applies in December
    if month ~= 12 then
        return 0
    end
    
    -- December 1-25: gradually increase from 0% to 50%
    if day <= 25 then
        return (day - 1) / 24 * 0.5 -- 0% on Dec 1, 50% on Dec 25
    else
        -- December 26-31: gradually decrease from 50% to 0%
        local daysAfterChristmas = day - 25
        local daysUntilNewYear = 31 - 25
        return 0.5 * (1 - (daysAfterChristmas / daysUntilNewYear))
    end
end

function ENT:OnTakeDamage(dmginfo)
    local attacker = dmginfo:GetAttacker()
    
    -- Check if damaged by player with crowbar
    if IsValid(attacker) and attacker:IsPlayer() then
        local wep = attacker:GetActiveWeapon()
        if IsValid(wep) and wep:GetClass() == "weapon_zm_improvised" then
            local spawnPos = self:GetPos()
            
            -- Special items that can drop from presents
            local specialItems = {
                "weapon_ttt_health_station",
                "weapon_ttt2_lens",
                "weapon_ttt_cse",
                "weapon_ttt2_camera",
                "weapon_ttt_decoy",
                "weapon_ttt_glue_trap",
                "weapon_ttt_identity_disguiser",
                "weapon_ttt_prop_disguiser",
                "weapon_ttt_radio",
                "weapon_ttt_supersmoke",
                "weapon_ttt_teleport",
                "weapon_ttt_sandwich",
                "weapon_ttt_binoculars",
                "weapon_doppelganger",
                "weapon_ttt_beacon",
                "weapon_ttt_identity_swap_grenade",
                "weapon_extinguisher",
                "adsplacer",
                "weapon_ttt_emp",
                "ttt_duct_tape",
                "ttt_wormholecaller"
            }
            
            -- Calculate special item drop chance
            local specialChance = GetSpecialItemChance()
            --print("[Christmas Present] Special item drop chance: " .. math.floor(specialChance * 100) .. "%")
            
            local weaponToSpawn = nil
            local ammoType = nil
            
            -- Roll for special item (only if enabled)
            if cv_SpecialItems:GetBool() and math.random() < specialChance then
                --print("[Christmas Present] Rolling for special item...")
                
                -- Try to spawn a special item (retry up to 10 times if it fails)
                for attempt = 1, 10 do
                    local specialClass = specialItems[math.random(#specialItems)]
                    local testEnt = ents.Create(specialClass)
                    
                    if IsValid(testEnt) then
                        weaponToSpawn = specialClass
                        testEnt:Remove()
                        --print("[Christmas Present] Special item selected: " .. specialClass)
                        break
                    else
                        if testEnt then testEnt:Remove() end
                        --print("[Christmas Present] Failed to spawn " .. specialClass .. ", rerolling... (attempt " .. attempt .. "/10)")
                    end
                end
            end
            
            -- If no special item, spawn a regular floor weapon
            if not weaponToSpawn then
                --print("[Christmas Present] Spawning regular floor weapon")
                
                local allWeapons = weapons.GetList()
                local floorWeapons = {}
                
                for _, w in ipairs(allWeapons) do
                    if w.AutoSpawnable and w.Kind and w.Kind ~= WEAPON_EQUIP and w.Kind ~= WEAPON_ROLE then
                        table.insert(floorWeapons, w)
                    end
                end
                
                if #floorWeapons > 0 then
                    local selectedWeapon = floorWeapons[math.random(#floorWeapons)]
                    weaponToSpawn = WEPS.GetClass(selectedWeapon)
                    ammoType = selectedWeapon.AmmoEnt
                end
            end
            
            -- Spawn the weapon
            if weaponToSpawn then
                local weapon = ents.Create(weaponToSpawn)
                if IsValid(weapon) then
                    weapon:SetPos(spawnPos + Vector(0, 0, 5))
                    weapon:Spawn()
                    
                    local phys = weapon:GetPhysicsObject()
                    if IsValid(phys) then
                        phys:Wake()
                    end
                    
                    -- Spawn 2 ammo boxes for this weapon (only if it's a regular weapon with ammo)
                    if ammoType and ammoType ~= "" then
                        for j = 1, 2 do
                            local ammo = ents.Create(ammoType)
                            if IsValid(ammo) then
                                local ammoOffset = VectorRand() * 20
                                ammo:SetPos(spawnPos + Vector(ammoOffset.x, ammoOffset.y, 5))
                                ammo:Spawn()
                                
                                local ammoPhys = ammo:GetPhysicsObject()
                                if IsValid(ammoPhys) then
                                    ammoPhys:Wake()
                                end
                            end
                        end
                    end
                end
                
                -- Remove the present
                self:Remove()
            end
        end
    end
end
