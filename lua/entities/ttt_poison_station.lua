-- @class ENT
-- @desc Poison Station (disguised as health station)
-- @section ttt_poison_station

if SERVER then
    AddCSLuaFile()
    
    -- ConVars for poison damage
    CreateConVar("ttt_poison_station_amount_tick", "5", FCVAR_ARCHIVE, "Amount of damage per tick from poison station")
    CreateConVar("ttt_poison_station_hurt_traitors", "true", FCVAR_ARCHIVE, "Whether poison station damages traitors")
end

DEFINE_BASECLASS("ttt_base_placeable")

-- Store reference to this entity table to force override later
local FORCE_OVERRIDE_ENT = nil

if CLIENT then
    ENT.Icon = "vgui/ttt/icon_health"
    ENT.PrintName = "hstation_name"
end

ENT.Base = "ttt_base_placeable"
ENT.Model = "models/props/cs_office/microwave.mdl"

ENT.CanHavePrints = true
ENT.MaxHeal = 25
ENT.MaxStored = 200
ENT.RechargeRate = 1
ENT.RechargeFreq = 2 -- in seconds

ENT.NextHeal = 0
ENT.HealRate = 1
ENT.HealFreq = 0.2

---
-- @realm shared
function ENT:SetupDataTables()
    BaseClass.SetupDataTables(self)

    self:NetworkVar("Int", 0, "StoredHealth")
end

---
-- @realm shared
function ENT:Initialize()
    self:SetModel(self.Model)

    BaseClass.Initialize(self)

    local b = 32

    self:SetCollisionBounds(Vector(-b, -b, -b), Vector(b, b, b))

    if SERVER then
        self:SetMaxHealth(200)

        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            phys:SetMass(200)
        end

        self:SetUseType(CONTINUOUS_USE)
    end

    self:SetHealth(200)
    self:SetColor(Color(180, 180, 250, 255))
    self:SetStoredHealth(200)

    self.NextHeal = 0
    self.fingerprints = {}
end

---
-- @param number amount
-- @realm shared
function ENT:AddToStorage(amount)
    self:SetStoredHealth(math.min(self.MaxStored, self:GetStoredHealth() + amount))
end

---
-- @param number amount
-- @return number
-- @realm shared
function ENT:TakeFromStorage(amount)
    -- if we only have 5 healthpts in store, that is the amount we heal
    amount = math.min(amount, self:GetStoredHealth())

    self:SetStoredHealth(math.max(0, self:GetStoredHealth() - amount))

    return amount
end

local soundHealing = Sound("items/medshot4.wav")
local soundFail = Sound("items/medshotno1.wav")
local timeLastSound = 0

---
-- @param Player ply
-- @param number healthMax
-- @return boolean
-- @realm shared
function ENT:GiveHealth(ply, healthMax)
    if self:GetStoredHealth() > 0 then
        healthMax = healthMax or self.MaxHeal
        
        -- Get the tick damage amount from ConVar
        local tickAmount = GetConVarNumber("ttt_poison_station_amount_tick")
        
        -- Check if player has enough health to damage
        if ply:Health() > tickAmount then
            -- Take from storage (pretend we're "healing")
            local healed = self:TakeFromStorage(math.min(healthMax, tickAmount))
            
            -- Damage the player instead of healing
            local new = math.max(1, ply:Health() - tickAmount)
            
            -- Check if we should hurt traitors
            local hurtTraitors = string.lower(GetConVarString("ttt_poison_station_hurt_traitors"))
            
            if ply:IsTraitor() and hurtTraitors == "true" then
                ply:SetHealth(new)
            elseif not ply:IsTraitor() then
                ply:SetHealth(new)
            end
            
            ---
            -- @realm shared
            hook.Run("TTTPlayerUsedPoisonStation", ply, self, healed)

            if timeLastSound + 2 < CurTime() then
                self:EmitSound(soundHealing)

                timeLastSound = CurTime()
            end

            if not table.HasValue(self.fingerprints, ply) then
                self.fingerprints[#self.fingerprints + 1] = ply
            end

            return true
        else
            self:EmitSound(soundFail)
        end
    else
        self:EmitSound(soundFail)
    end

    return false
end

if SERVER then
    -- Add marker vision when entity is created
    hook.Add("OnEntityCreated", "PoisonStationMarkerVision", function(ent)
        timer.Simple(0, function()
            if not IsValid(ent) or ent:GetClass() ~= "ttt_poison_station" then return end
            
            timer.Simple(0.1, function()
                if not IsValid(ent) then return end
                
                local owner = ent:GetOriginator()
                if not IsValid(owner) or not owner:IsPlayer() then return end
                
                -- Add marker vision for the poison station
                local mvObject = ent:AddMarkerVision("poison_station_trap")
                if not mvObject then return end
                
                mvObject:SetOwner(owner)
                mvObject:SetVisibleFor(VISIBLE_FOR_TEAM)
                mvObject:SetColor(Color(180, 180, 250, 255))
                mvObject:SyncToClients()
                
                -- Remove marker vision when destroyed
                ent:CallOnRemove("PoisonStationMarkerVisionCleanup", function()
                    if IsValid(ent) then
                        ent:RemoveMarkerVision("poison_station_trap")
                    end
                end)
            end)
        end)
    end)
    
    -- recharge
    local nextcharge = 0

    ---
    -- @realm server
    function ENT:Think()
        if nextcharge > CurTime() then
            return
        end

        self:AddToStorage(self.RechargeRate)

        nextcharge = CurTime() + self.RechargeFreq
    end

    ---
    -- @param Player ply
    -- @realm server
    function ENT:Use(ply)
        if not IsValid(ply) or not ply:IsPlayer() or not ply:IsActive() then
            return
        end

        local t = CurTime()
        if t < self.NextHeal then
            return
        end

        local healed = self:GiveHealth(ply, self.HealRate)

        self.NextHeal = t + (self.HealFreq * (healed and 1 or 2))
    end

    ---
    -- @realm server
    function ENT:WasDestroyed()
        local originator = self:GetOriginator()

        if not IsValid(originator) then
            return
        end

        LANG.Msg(originator, "hstation_broken", nil, MSG_MSTACK_WARN)
    end
else
    local TryT = LANG.TryTranslation
    local ParT = LANG.GetParamTranslation

    local key_params = {
        usekey = Key("+use", "USE"),
        walkkey = Key("+walk", "WALK"),
    }

    ---
    -- Hook that is called if a player uses their use key while focusing on the entity.
    -- Early check if client can use the poison station
    -- @return bool True to prevent pickup
    -- @realm client
    function ENT:ClientUse()
        local client = LocalPlayer()

        if not IsValid(client) or not client:IsPlayer() or not client:IsActive() then
            return true
        end
    end

    -- handle looking at poison station
    hook.Add("TTTRenderEntityInfo", "HUDDrawTargetIDPoisonStation", function(tData)
        local client = LocalPlayer()
        local ent = tData:GetEntity()

        if
            not IsValid(client)
            or not client:IsTerror()
            or not client:Alive()
            or not IsValid(ent)
            or tData:GetEntityDistance() > 100
            or ent:GetClass() ~= "ttt_poison_station"
        then
            return
        end

        -- enable targetID rendering
        tData:EnableText()
        tData:EnableOutline()
        tData:SetOutlineColor(client:GetRoleColor())

        tData:SetTitle(TryT(ent.PrintName))
        tData:SetSubtitle(ParT("hstation_subtitle", key_params))
        tData:SetKeyBinding("+use")

        local hstation_charge = ent:GetStoredHealth() or 0

        tData:AddDescriptionLine(TryT("hstation_short_desc"))

        tData:AddDescriptionLine(
            (hstation_charge > 0) and ParT("hstation_charge", { charge = hstation_charge })
                or TryT("hstation_empty"),
            (hstation_charge > 0) and roles.DETECTIVE.ltcolor or COLOR_ORANGE
        )

        if client:Health() < client:GetMaxHealth() then
            return
        end

        tData:AddDescriptionLine(TryT("hstation_maxhealth"), COLOR_ORANGE)
    end)
    
    -- Add custom marker vision display for poison stations
    hook.Add("TTT2RenderMarkerVisionInfo", "PoisonStationMarkerVisionDisplay", function(mvData)
        local ent = mvData:GetEntity()
        if not IsValid(ent) or ent:GetClass() ~= "ttt_poison_station" then return end
        
        -- Get the marker vision object
        local mvObject = mvData:GetMarkerVisionObject()
        if not mvObject or mvObject:GetIdentifier() ~= "poison_station_trap" then return end
        
        -- Enable the text display
        mvData:EnableText(true)
        
        mvData:AddIcon(Material("vgui/ttt/icon_poison"), mvObject:GetColor())
        
        -- Set the title
        mvData:SetTitle("POISON STATION", mvObject:GetColor())
        
        -- Add distance and charge information
        local distance = math.Round(mvData:GetEntityDistance())
        mvData:AddDescriptionLine("Distance: " .. distance .. " units", COLOR_WHITE)
        
        local charge = ent:GetStoredHealth() or 0
        mvData:AddDescriptionLine("Charge: " .. charge, COLOR_WHITE)
        
        -- Get the owner from the marker vision object
        local owner = mvObject:GetOwner()
        if IsValid(owner) and owner:IsPlayer() then
            mvData:SetSubtitle("Placed by: " .. owner:Nick(), COLOR_LGRAY)
        end
        
        -- Set collapsed line for when off screen
        mvData:SetCollapsedLine("Poison Station: " .. distance .. "u", mvObject:GetColor())
    end)
end

-- Store the ENT table for forced override
FORCE_OVERRIDE_ENT = table.Copy(ENT)

-- Hook to force override after all addons load
hook.Add("InitPostEntity", "PoisonStation_CompleteOverride", function()
    if FORCE_OVERRIDE_ENT then
        -- Completely replace the entity with our version
        scripted_ents.Register(FORCE_OVERRIDE_ENT, "ttt_poison_station")
    end
end)