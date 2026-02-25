AddCSLuaFile()

-- Store reference to this file's SWEP table to force override later
local FORCE_OVERRIDE_SWEP = nil

-- Hook to force override after all addons load
hook.Add("InitPostEntity", "PropRain_CompleteOverride", function()
	if FORCE_OVERRIDE_SWEP then
		-- Completely replace the weapon with our version
		weapons.Register(FORCE_OVERRIDE_SWEP, "weapon_prop_rain", FORCE_OVERRIDE_SWEP.Base)
	end
end)

CreateConVar("ttt_proprain_sidelength", 300, {FCVAR_NOTIFY, FCVAR_ARCHIVE, FCVAR_REPLICATED})
CreateConVar("ttt_proprain_proptimer", 100, {FCVAR_NOTIFY, FCVAR_ARCHIVE, FCVAR_REPLICATED}) -- in ms
CreateConVar("ttt_proprain_iterations", 30, {FCVAR_NOTIFY, FCVAR_ARCHIVE, FCVAR_REPLICATED})
CreateConVar("ttt_proprain_despawn_props", 0, {FCVAR_NOTIFY, FCVAR_ARCHIVE, FCVAR_REPLICATED})
CreateConVar("ttt_proprain_despawn_seconds", 5, {FCVAR_NOTIFY, FCVAR_ARCHIVE, FCVAR_REPLICATED})

SWEP.PrintName = "Prop Rain"
SWEP.Author = "Blechkanne"
SWEP.Instructions = "Left click to let it rain Props in a certain area"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.Primary.ClipSize = 1
SWEP.Primary.DefaultClip = 1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"
SWEP.Primary.Delay = 0
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = 1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"
SWEP.Weight = 5
SWEP.AutoSwitchTo = true
SWEP.AutoSwitchFrom = false
SWEP.Slot = 4
SWEP.SlotPos = 4
SWEP.DrawAmmo = true
SWEP.DrawCrosshair = true
SWEP.ViewModel = "models/weapons/c_slam.mdl"
SWEP.WorldModel = "models/weapons/c_slam.mdl"
SWEP.UseHands = true
SWEP.ShootSound = Sound("Weapon_Mortar.Incomming")
SWEP.DeploySpeed = 100

-- TTT Customisation
if (engine.ActiveGamemode() == "terrortown") then
	SWEP.Base = "weapon_tttbase"
	SWEP.Kind = WEAPON_EQUIP1
	SWEP.AutoSpawnable = false
	SWEP.CanBuy = { ROLE_TRAITOR, ROLE_JACKAL }
	SWEP.LimitedStock = true
	SWEP.Slot = 7
	SWEP.Icon = "VGUI/ttt/icon_prop_rain.vtf"

	-- The information shown in the buy menu
	SWEP.EquipMenuData = {
		type = "item_weapon",
		name = "Prop Rain",
		desc = [[IT IS RAINING PROPS!
Left Click to let it rain some props on your foes]]
	}

end

if SERVER then
	AddCSLuaFile()
	resource.AddFile("materials/vgui/ttt/blue_template_icon.vmt")
end

local max_height = 1000
local lowest_height = 200
local height = max_height
local power = -400000
local spreading = 1000
local hitpos = Vector(0,0,0)

local side_length = GetConVar( "ttt_proprain_sidelength" ):GetInt() or 300
local proptimer = GetConVar("ttt_proprain_proptimer"):GetInt() or 100
local iterations = GetConVar("ttt_proprain_iterations"):GetInt() or 30
local despawn_props = GetConVar("ttt_proprain_despawn_props"):GetBool() or 0
local despawn_props_seconds = GetConVar("ttt_proprain_despawn_seconds"):GetInt() or 5


function SWEP:Initialize()
	self:SetHoldType(self.HoldType or "slam")
	
	-- Set infinite ammo to prevent ammo checks
	self:SetClip1(-1)
end

function SWEP:Deploy()
	-- Mark that we just deployed
	self.DeployTime = CurTime()
	self:SetNextPrimaryFire(0)
	self:SetNextSecondaryFire(0)
	return true
end

function SWEP:Think()
	-- Force firing to be available immediately after deploy
	if self.DeployTime and CurTime() - self.DeployTime < 0.5 then
		self:SetNextPrimaryFire(0)
	end
end

function SWEP:CanPrimaryAttack()
	-- Always return true since we handle firing logic manually
	return true
end

function SWEP:TakePrimaryAmmo()
	-- Override to prevent base class from taking ammo
	-- Do nothing - we want infinite ammo
end

function SWEP:PrimaryAttack()
	if not IsValid(self:GetOwner()) then return end
	
	-- Don't set any cooldown - we want instant firing
	-- (weapon gets removed anyway after firing)
	
	local owner = self:GetOwner()
	local eyetrace = owner:GetEyeTrace()
	local traceup = util.QuickTrace(eyetrace.HitPos, Vector(0, 0, max_height))
	local distance_to_hit = max_height * traceup.Fraction
	local fireable = false

	hitpos = eyetrace.HitPos

	if eyetrace.HitSky or traceup.Hit then
		if distance_to_hit < lowest_height then
			fireable = false
		else
			fireable = true
			height = distance_to_hit * 0.9
		end
	else
		fireable = true
		height = max_height * 0.9
	end

	-- Don't do anything if conditions aren't met
	if not fireable then return end
	
	if SERVER then
		-- SERVER: Do the actual firing
		self:StartPropRain()
		
		-- Remove weapon after a short delay to ensure sound plays
		timer.Simple(0.1, function()
			if IsValid(self) then
				self:Remove()
			end
		end)
	else
		-- CLIENT: Play the sound for feedback only if fireable
		self:EmitSound(self.ShootSound)
	end
end

function SWEP:SecondaryAttack()
end

function SWEP:StartPropRain()
	if CLIENT then return end
	
	-- Server-side only: Play sound for everyone
	self:EmitSound(self.ShootSound)
	
	-- Create the spawn timer
	timer.Create("timer_spawn_prop", proptimer / 1000, iterations, function() SpawnProp() end)
end

-- Cache the map props on first use
local mapPropModels = nil

local function GetMapPropModels()
	if mapPropModels then return mapPropModels end
	
	mapPropModels = {}
	local modelSet = {}
	
	-- Gather all prop models from the map
	for _, entClass in ipairs({"prop_physics", "prop_physics_multiplayer", "prop_physics_override"}) do
		for _, prop in ipairs(ents.FindByClass(entClass)) do
			local model = prop:GetModel()
			if model and model ~= "" and not modelSet[model] then
				modelSet[model] = true
				table.insert(mapPropModels, model)
			end
		end
	end
	
	-- Fallback to default props if no props found on map
	if #mapPropModels == 0 then
		mapPropModels = {
			"models/props_c17/FurnitureCouch001a.mdl",
			"models/props_c17/bench01a.mdl",
			"models/props_c17/chair02a.mdl",
			"models/props_c17/oildrum001.mdl",
			"models/props_c17/oildrum001_explosive.mdl",
			"models/props_c17/FurnitureCouch002a.mdl",
			"models/props_junk/PopCan01a.mdl",
			"models/props_junk/MetalBucket01a.mdl",
			"models/props_junk/watermelon01.mdl",
			"models/props_junk/wood_crate001a.mdl",
			"models/props_junk/PlasticCrate01a.mdl",
			"models/props_c17/doll01.mdl",
			"models/props_lab/monitor01a.mdl"
		}
	end
	
	return mapPropModels
end

function SpawnProp()
	local prop_table = GetMapPropModels()
	
	local ent = ents.Create("prop_physics")
	if not ent:IsValid() then return end

	local randompos
	
	-- 25% chance to target a player in range
	if math.random(100) <= 25 then
		-- Find all players in the prop rain radius
		local playersInRange = {}
		for _, ply in ipairs(player.GetAll()) do
			if ply:Alive() then
				local plyPos = ply:GetPos()
				local distance2D = math.sqrt((plyPos.x - hitpos.x)^2 + (plyPos.y - hitpos.y)^2)
				if distance2D <= side_length then
					table.insert(playersInRange, ply)
				end
			end
		end
		
		-- If we found players, target one of them
		if #playersInRange > 0 then
			local targetPlayer = playersInRange[math.random(#playersInRange)]
			local targetPos = targetPlayer:GetPos()
			randompos = Vector(targetPos.x, targetPos.y, height)
		else
			-- No players in range, use random position
			randompos = Vector(math.random(-side_length, side_length), math.random(-side_length, side_length), height)
			randompos:Add(hitpos)
		end
	else
		-- 75% chance: completely random position
		randompos = Vector(math.random(-side_length, side_length), math.random(-side_length, side_length), height)
		randompos:Add(hitpos)
	end

	ent:SetModel(prop_table[math.random(#prop_table)])
	ent:SetPos(randompos)
	ent:SetAngles(AngleRand())
	ent:Spawn()


	local phys = ent:GetPhysicsObject()
	-- Entity Removal
	if not phys:IsValid() then ent:Remove() return end
	if despawn_props then timer.Simple(despawn_props_seconds, function()
		if not IsValid(ent) then return end
		ent:Remove()
	end) end

	local force = Vector(math.random(-spreading, spreading), math.random(-spreading, spreading), power)
	phys:ApplyForceCenter(force)
end

local material = Material("vgui/white")
local mat_color = Color(255, 0, 0, 30)
local draw_warning = false

function SWEP:PostDrawViewModel()
	if CLIENT then
		local player = LocalPlayer()
		
		-- Only draw if the local player is holding this weapon
		if player:GetActiveWeapon() ~= self then return end
		
		local eyetrace          = player:GetEyeTrace()
		local traceup           = util.QuickTrace(eyetrace.HitPos, Vector(0, 0, max_height))
		local distance_to_hit   = max_height * traceup.Fraction

		if (eyetrace.HitSky or traceup.Hit) and (distance_to_hit < lowest_height) then
			mat_color = Color(255, 0, 0, 30)
			draw_warning = true
		else
			height = max_height * 0.9
			mat_color = Color(0, 255, 0, 30)
			draw_warning = false
		end

		cam.Start3D()
		render.SetMaterial(material)
		render.SetColorMaterial()
		render.DrawBox(eyetrace.HitPos, Angle(0, 0, 0), -Vector(side_length / 2, side_length / 2, 0),Vector(side_length / 2, side_length / 2, 5), mat_color)
		render.DrawWireframeBox(eyetrace.HitPos, Angle(0, 0, 0), -Vector(side_length / 2, side_length / 2, 0),Vector(side_length / 2, side_length / 2, 5), mat_color, true)
		cam.End3D()
	end
end

function SWEP:DrawHUD()
	if CLIENT and draw_warning then
		surface.SetFont("DermaDefault")
		surface.SetTextColor(255, 0, 0)
		surface.SetTextPos(ScrW() / 2 + 20, ScrH() / 2 - 10)
		surface.DrawText("Not enough space to the ceiling")
	end
end

if CLIENT then
	function SWEP:AddToSettingsMenu(parent)
		local form = vgui.CreateTTT2Form(parent, "prop_rain_addon_header")

		form:MakeHelp({
			label = "prop_rain_help_menu"
		})

		form:MakeCheckBox({
			label = "label_proprain_despawn_props",
			serverConvar = "ttt_proprain_despawn_props"
		})

		form:MakeSlider({
			label = "label_roprain_despawn_seconds",
			serverConvar = "ttt_proprain_despawn_seconds",
			min = 1,
			max = 60,
			decimal = 0
		})

		form:MakeSlider({
			label = "label_proprain_sidelength",
			serverConvar = "ttt_proprain_sidelength",
			min = 1,
			max = 2000,
			decimal = 0
		})

		form:MakeSlider({
			label = "label_proprain_proptimer",
			serverConvar = "ttt_proprain_proptimer",
			min = 50,
			max = 500,
			decimal = 0
		})

		form:MakeSlider({
			label = "label_proprain_iterations",
			serverConvar = "ttt_proprain_iterations",
			min = 1,
			max = 200,
			decimal = 0
		})
	end
end

cvars.AddChangeCallback("ttt_proprain_sidelength", function(cv, old, new)
	side_length = tonumber(new)
end)

cvars.AddChangeCallback("ttt_proprain_proptimer", function(cv, old, new)
	proptimer = tonumber(new)
end)

cvars.AddChangeCallback("ttt_proprain_iterations", function(cv, old, new)
	iterations = tonumber(new)
end)

cvars.AddChangeCallback("ttt_proprain_despawn_props", function(cv, old, new)
	despawn_props = tobool(new)
end)

cvars.AddChangeCallback("ttt_proprain_despawn_seconds", function(cv, old, new)
	despawn_props_seconds = tonumber(new)
end)

-- Store the SWEP table for forced override
FORCE_OVERRIDE_SWEP = table.Copy(SWEP)
