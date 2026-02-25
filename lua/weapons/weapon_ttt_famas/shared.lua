AddCSLuaFile()

-- Store reference to this file's SWEP table to force override later
local FORCE_OVERRIDE_SWEP = nil

-- Hook to force override after all addons load
hook.Add("InitPostEntity", "FAMAS_CompleteOverride", function()
    if FORCE_OVERRIDE_SWEP then
        -- Completely replace the weapon with our version
        weapons.Register(FORCE_OVERRIDE_SWEP, "weapon_ttt_famas", "weapon_tttbase")
    end
end)

-- Add click sound for firemode switching
sound.Add({
    name = "FAMAS.FiremodeSwitch",
    channel = CHAN_ITEM,
    volume = 0.5,
    level = 60,
    pitch = {98, 102},
    sound = "weapons/smg1/switch_single.wav"
})

if CLIENT then
	LANG.AddToLanguage("english", "famas_name", "Famas")

	SWEP.PrintName = "famas_name"
	SWEP.Slot = 2
	SWEP.Icon = "vgui/ttt/icon_famas"

	-- client side model settings
	SWEP.UseHands = true
	SWEP.ViewModelFlip = false
	SWEP.ViewModelFOV = 64
end

-- always derive from weapon_tttbase
SWEP.Base = "weapon_tttbase"

--[[Author informations]]--
SWEP.Author = "Zaratusa (Modified with burst fire)"
SWEP.Contact = "http://steamcommunity.com/profiles/76561198032479768"

--[[Default GMod values]]--
SWEP.Primary.Ammo = "SMG1"
SWEP.Primary.Delay = 0.08
SWEP.Primary.Recoil = 0.8
SWEP.Primary.Cone = 0.025
SWEP.Primary.Damage = 17
SWEP.Primary.Automatic = true
SWEP.Primary.ClipSize = 30
SWEP.Primary.ClipMax = 60
SWEP.Primary.DefaultClip = 30
SWEP.Primary.Sound = Sound("Weapon_FAMAS.Single")
SWEP.Primary.NumShots = 1

--[[Model settings]]--
SWEP.HoldType = "ar2"
SWEP.ViewModel = Model("models/weapons/cstrike/c_rif_famas.mdl")
SWEP.WorldModel = Model("models/weapons/w_rif_famas.mdl")

SWEP.IronSightsPos = Vector(-6.24, -2.757, 1.2)
SWEP.IronSightsAng = Vector(0.2, 0, -1)

--[[TTT config values]]--
SWEP.Kind = WEAPON_HEAVY
SWEP.AutoSpawnable = true
SWEP.AmmoEnt = "item_ammo_smg1_ttt"
SWEP.AllowDrop = true
SWEP.IsSilent = false
SWEP.NoSights = false

-- Burst fire variables
SWEP.BurstMode = false
SWEP.BurstCount = 0
SWEP.BurstInProgress = false
SWEP.NextBurstShot = 0

function SWEP:Initialize()
	if SERVER and self.AutoSpawnable then
		self:SetDeploySpeed(self.DeploySpeed)
	end
	self:SetHoldType(self.HoldType)
	self.BurstMode = false
	self.BurstCount = 0
	self.BurstInProgress = false
end

-- Toggle burst mode with ALT+E
if CLIENT then
	hook.Add("PlayerBindPress", "FAMAS_BurstToggle", function(ply, bind, pressed)
		if not pressed then return end
		if bind ~= "+use" then return end
		
		-- Check if ALT is held
		if not input.IsKeyDown(KEY_LALT) and not input.IsKeyDown(KEY_RALT) then return end
		
		local wep = ply:GetActiveWeapon()
		if not IsValid(wep) or wep:GetClass() ~= "weapon_ttt_famas" then return end
		
		-- Toggle burst mode
		wep.BurstMode = not wep.BurstMode
		
		-- Play switch sound
		wep:EmitSound("FAMAS.FiremodeSwitch")
		
		-- Send to server
		net.Start("FAMAS_ToggleFireMode")
		net.WriteBool(wep.BurstMode)
		net.SendToServer()
		
		-- Show message
		if wep.BurstMode then
			chat.AddText(Color(100, 255, 100), "[FAMAS] ", Color(255, 255, 255), "Burst fire mode enabled")
		else
			chat.AddText(Color(255, 150, 100), "[FAMAS] ", Color(255, 255, 255), "Full auto mode enabled")
		end
		
		return true -- Prevent use key
	end)
end

if SERVER then
	util.AddNetworkString("FAMAS_ToggleFireMode")
	
	net.Receive("FAMAS_ToggleFireMode", function(len, ply)
		local wep = ply:GetActiveWeapon()
		if not IsValid(wep) or wep:GetClass() ~= "weapon_ttt_famas" then return end
		
		wep.BurstMode = net.ReadBool()
		wep:EmitSound("FAMAS.FiremodeSwitch")
	end)
end

function SWEP:PrimaryAttack()
	if not self:CanPrimaryAttack() then return end
	
	if self.BurstMode then
		-- Burst fire mode - make weapon non-automatic during burst
		self.Primary.Automatic = false
		
		if self.BurstInProgress then return end
		
		self.BurstInProgress = true
		self.BurstCount = 1
		self.NextBurstShot = CurTime() + 0.065
		
		-- Fire first shot
		self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
		self:GetOwner():SetAnimation(PLAYER_ATTACK1)
		
		-- Improved stats for burst
		local cone = self.Primary.Cone * 0.7
		local recoil = self.Primary.Recoil * 0.75
		
		if not self:GetOwner():IsNPC() then
			self:ShootBullet(self.Primary.Damage, recoil, self.Primary.NumShots, cone)
		else
			self:ShootBullet(self.Primary.Damage, recoil, self.Primary.NumShots, self.Primary.Cone)
		end
		
		self:TakePrimaryAmmo(1)
		
		-- Set next primary fire to after burst completes
		self:SetNextPrimaryFire(CurTime() + (0.065 * 2) + 0.35)
	else
		-- Full auto mode (default behavior)
		self.Primary.Automatic = true
		
		self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
		self:GetOwner():SetAnimation(PLAYER_ATTACK1)
		
		if not self:GetOwner():IsNPC() then
			self:ShootBullet(self.Primary.Damage, self.Primary.Recoil, self.Primary.NumShots, self:GetPrimaryCone())
		else
			self:ShootBullet(self.Primary.Damage, self.Primary.Recoil, self.Primary.NumShots, self.Primary.Cone)
		end
		
		self:TakePrimaryAmmo(1)
		self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
	end
end

function SWEP:Think()
	-- Handle burst continuation
	if self.BurstInProgress and self.BurstCount < 3 and CurTime() >= self.NextBurstShot then
		if not self:CanPrimaryAttack() then
			self.BurstInProgress = false
			self.BurstCount = 0
			return
		end
		
		-- Fire next shot in burst
		self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
		self:GetOwner():SetAnimation(PLAYER_ATTACK1)
		
		-- Improved stats for burst
		local cone = self.Primary.Cone * 0.7
		local recoil = self.Primary.Recoil * 0.75
		
		if not self:GetOwner():IsNPC() then
			self:ShootBullet(self.Primary.Damage, recoil, self.Primary.NumShots, cone)
		else
			self:ShootBullet(self.Primary.Damage, recoil, self.Primary.NumShots, self.Primary.Cone)
		end
		
		self:TakePrimaryAmmo(1)
		self.BurstCount = self.BurstCount + 1
		
		if self.BurstCount < 3 then
			self.NextBurstShot = CurTime() + 0.065
		else
			self.BurstInProgress = false
		end
	end
end

function SWEP:ShootBullet(dmg, recoil, numbul, cone)
	local owner = self:GetOwner()
	if not IsValid(owner) then return end
	
	self:SendWeaponAnim(self.PrimaryAnim)
	owner:MuzzleFlash()
	owner:SetAnimation(PLAYER_ATTACK1)
	
	self:EmitSound(self.Primary.Sound)
	
	numbul = numbul or 1
	cone = cone or 0.02
	
	local bullet = {}
	bullet.Num = numbul
	bullet.Src = owner:GetShootPos()
	bullet.Dir = owner:GetAimVector()
	bullet.Spread = Vector(cone, cone, 0)
	bullet.Tracer = 1
	bullet.TracerName = self.Tracer or "Tracer"
	bullet.Force = 10
	bullet.Damage = dmg
	bullet.AmmoType = self.Primary.Ammo
	
	owner:FireBullets(bullet)
	
	-- Owner can die after firebullets
	if not IsValid(owner) or owner:IsNPC() or not owner:Alive() then
		return
	end
	
	-- Apply recoil exactly like weapon_tttbase does (CLIENT in multiplayer, SERVER in singleplayer only)
	if SERVER and game.SinglePlayer() or CLIENT and not game.SinglePlayer() and IsFirstTimePredicted() then
		local eyeang = owner:EyeAngles()
		eyeang.pitch = eyeang.pitch - recoil
		owner:SetEyeAngles(eyeang)
	end
end

function SWEP:GetPrimaryCone()
	local cone = self.Primary.Cone or 0.02
	if self:GetIronsights() then
		return cone * 0.6
	end
	return cone
end

function SWEP:Reload()
	if self:Clip1() == self.Primary.ClipSize or self:GetOwner():GetAmmoCount(self.Primary.Ammo) <= 0 then
		return
	end
	
	-- Can't reload during burst
	if self.BurstInProgress then
		return
	end
	
	-- Reset burst on reload
	self.BurstCount = 0
	
	if self:DefaultReload(ACT_VM_RELOAD) then
		self:SetIronsights(false)
	end
end

function SWEP:CanPrimaryAttack()
	if self:Clip1() <= 0 then
		self:EmitSound("Weapon_Pistol.Empty")
		self:SetNextPrimaryFire(CurTime() + 0.2)
		return false
	end
	return true
end

function SWEP:Deploy()
	self.BurstCount = 0
	self.BurstInProgress = false
	self:SendWeaponAnim(ACT_VM_DRAW)
	self:SetNextPrimaryFire(CurTime() + 0.5)
	self:SetNextSecondaryFire(CurTime() + 0.5)
	return true
end

if CLIENT then
	-- Draw firemode indicator on HUD
	hook.Add("HUDPaint", "FAMAS_BurstFire_HUD", function()
		local ply = LocalPlayer()
		if not IsValid(ply) then return end
		
		local wep = ply:GetActiveWeapon()
		if not IsValid(wep) or wep:GetClass() ~= "weapon_ttt_famas" then return end
		
		local text = wep.BurstMode and "BURST" or "AUTO"
		local color = wep.BurstMode and Color(100, 255, 100, 200) or Color(255, 150, 100, 200)
		
		-- Draw in bottom right corner
		local scrW, scrH = ScrW(), ScrH()
		
		draw.SimpleText(text, "DermaLarge", scrW - 150, scrH - 375, color, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText("ALT+E to toggle", "DermaDefault", scrW - 150, scrH - 355, Color(255, 255, 255, 150), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end)
end

-- Store the SWEP table for forced override
FORCE_OVERRIDE_SWEP = table.Copy(SWEP)
