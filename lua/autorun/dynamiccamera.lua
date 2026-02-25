-- Dynamic Camera
-- Fixes camera stuff relating to playermodel height changes?
-- Credit: Snuffles the Fox (?)

AddCSLuaFile("DynamicCamera.lua")

CreateConVar("dynamiccamerahull_debug", 0, FCVAR_ARCHIVE, "Minimum height for playermodels", 0, 1)
CreateConVar("dynamiccamerahull_npcs", 1, FCVAR_ARCHIVE, "Minimum height for playermodels", 0, 1)
CreateConVar("dynamiccamerahull_minheight", 10, FCVAR_ARCHIVE, "Minimum height for playermodels", 10, 33)
CreateConVar("dynamiccamerahull_maxheight", 200, FCVAR_ARCHIVE, "Minimum height for playermodels", 72, 200)

DYNAMICCAMERAINIT = false

hook.Add( "InitPostEntity", "DynamicCamera:InitPostEntity", function()
	timer.Simple( 5, function()
		DYNAMICCAMERAINIT = true
	end )
end )

function ChatPrintDEBUG( ply, message )
	if !GetConVar( "dynamiccamerahull_debug" ):GetBool() then return end
	if !ply or !ply:IsPlayer() then
		for k, v in pairs( player.GetAll() ) do
			if v:IsSuperAdmin() then
				v:ChatPrint( message )
			end
		end
	else
		ply:ChatPrint( message )
	end
end

function DynamicCameraGetModelNamePath()
	if CLIENT then
		if !IsValid( LocalPlayer() ) then return end
		local model = LocalPlayer().enforce_model
		if model == nil and isfunction(LocalPlayer().GetModel) then model = LocalPlayer():GetModel() end
		if model == nil then model = "models/player.mdl" end
		return model
	else
		return ""
	end
end

function CLAMPHEIGHT( value )
	return math.Clamp( value, GetConVar("dynamiccamerahull_minheight"):GetFloat(), GetConVar("dynamiccamerahull_maxheight"):GetFloat() )
end
function CLAMPCAMHEIGHT( value )
	return math.Clamp( value * 1.09121366, GetConVar("dynamiccamerahull_minheight"):GetFloat(), GetConVar("dynamiccamerahull_maxheight"):GetFloat() ) / 1.09121366
end
function CLAMPCROUCHCAMHEIGHT( ccamheight, height )
	if ccamheight > height / 1.83214558 then
		return math.Clamp( ccamheight + 3, GetConVar("dynamiccamerahull_minheight"):GetFloat(), GetConVar("dynamiccamerahull_maxheight"):GetFloat() ) - 3
	else
		return math.Clamp( height / 1.83214558, GetConVar("dynamiccamerahull_minheight"):GetFloat(), GetConVar("dynamiccamerahull_maxheight"):GetFloat() ) * 1.83214558
	end
end

local PLY_META = FindMetaTable( "Player" )

function PLY_META.GetBodygroupsAsNumber(self)
	local num = 0
	local bodys = self:GetNumBodyGroups()
	for i = 0, bodys - 1 do
		num = num + (self:GetBodygroup(i) < 10 and self:GetBodygroup(i) or 0) * math.pow( 10, bodys - 1 - i )
	end
	return num
end

function PLY_META.GetBodygroupsAsString(self)
	local num = ""
	local bodys = self:GetNumBodyGroups()
	local digits = "0123456789abcdefghijklmnopqrstuvwxyz"
	for i = 0, bodys - 1 do
		num = num .. string.sub(digits, self:GetBodygroup(i)+1,self:GetBodygroup(i)+1)
	end
	return num
end

-- CAUTION : OVERRIDE
function PLY_META.ResetHull(self)
	if self:GetInfoNum( "dynamiccamerahull_client_enabled", 1 ) == 0 then
		self:SetHull(Vector(-16,-16,0), Vector(16,16,72))
		self:SetHullDuck(Vector(-16,-16,0), Vector(16,16,36))
		return
	end

	if SERVER then
		net.Start("DynamicCameraHullViewSetup")
		net.Send(self)
	else
		DynamicCameraHullViewCL(DynamicCameraGetModelNamePath())
	end
end

if CLIENT then

	CreateClientConVar("dynamiccamerahull_client_enabled", 1, true, true, "Client enabled height changes?", 0, 1)

	cvars.AddChangeCallback("dynamiccamerahull_client_enabled", function(convar_name, value_old, value_new)
		DynamicCameraHullViewCL(DynamicCameraGetModelNamePath())
	end )

	concommand.Add("dynamiccamerahull_reload", function()
		DynamicCameraHullViewCL(DynamicCameraGetModelNamePath())
	end )

	local function EnhancedCameraToolMenu(self)
		if !IsValid(self) then return end
		self:Help("Dynamic Camera + Hull"):SetFont("DermaDefaultBold")
		self:CheckBox("Print Debug Info", "dynamiccamerahull_debug")
		self:CheckBox("Affect NPCs", "dynamiccamerahull_npcs")
		self:NumSlider("Minimum Height", "dynamiccamerahull_minheight", 10, 33, 0)
		self:NumSlider("Maximum Height", "dynamiccamerahull_maxheight", 72, 200, 0)
		self:Help("Client Side"):SetFont("DermaDefaultBold")
		self:CheckBox("Enabled", "dynamiccamerahull_client_enabled")
	end

	hook.Add("PopulateToolMenu", "dynamiccamerahull_utilities", function()
		spawnmenu.AddToolMenuOption(
			"Utilities",
			"Dynamic Camera + Hull",
			"DynamicCameraHull",
			"Settings",
			"",
			"",
			EnhancedCameraToolMenu,
			{
			}
		)
	end)

	local defMins, defMaxs = Vector(-16, -16, 0), Vector(16, 16, 72)
	function DynamicCameraHullViewCL( model ) -- Find the height by spawning a dummy entity
		if model == "models/player.mdl" then return end
		local ply = LocalPlayer()

		local mins, maxs = ply:GetHull()
		if mins != defMins and maxs != defMaxs and ply.LastModel != nil and ply.LastModel == model then
			return
		end
		ply.LastModel = model

		if ply.DynamCamTable == nil then
			ply.DynamCamTable = {
				["height"] = 0,
				["cheight"] = 0,
				["camheight"] = 0,
				["ccamheight"] = 0,
				["hull"] = 0,
				["chull"] = 0,
			}
		end

		if ply:GetInfoNum( "dynamiccamerahull_client_enabled", 1 ) == 0 then
			ply:SetHull(Vector(-16,-16,0), Vector(16,16,72))
			ply:SetHullDuck(Vector(-16,-16,0), Vector(16,16,36))
			ply:SetViewOffset(Vector(0, 0, 64))
			ply:SetViewOffsetDucked(Vector(0, 0, 28))

			net.Start("DynamicCameraHullViewSetup")
				net.WriteTable( ply.DynamCamTable )
			net.SendToServer()

			return
		end

		if render.GetRenderTarget() then return end

		local height = 64
		local camheight = -1
		local entity = ents.CreateClientside("base_anim")
		entity:SetModel(model)
		entity:ResetSequence(entity:LookupSequence("idle_all_01"))

		bone = entity:LookupBone("ValveBiped.Bip01_Neck1")
		if bone then
			height = entity:GetBonePosition(bone).z + 5
		end
		attach = entity:LookupAttachment( "eyes" )
		if attach > 0 then
			camheight = entity:GetAttachment( entity:LookupAttachment( "eyes" ) ).Pos.z
		end

		height = CLAMPCAMHEIGHT( height )
		if attach > 0 then
			camheight = CLAMPHEIGHT( camheight )
		end

		entity:Remove()
		--if height == 64 then return end
		--ply:SetNWFloat("DynamicCamera:StandHeight", height)
		--ply:SetNWFloat("DynamicCamera:StandCamHeight", camheight)

		local cheight = 36
		local ccamheight = -1
		local entity = ents.CreateClientside("base_anim")
		entity:SetModel(model)
		entity:ResetSequence(entity:LookupSequence("cidle_all"))
		bone = entity:LookupBone("ValveBiped.Bip01_Neck1")

		if bone then
			cheight = entity:GetBonePosition(bone).z + 5
		end
		attach = entity:LookupAttachment( "eyes" )
		if attach > 0 then
			ccamheight = math.Clamp(entity:GetAttachment( entity:LookupAttachment( "eyes" ) ).Pos.z, GetConVar("dynamiccamerahull_minheight"):GetFloat(), 33)
		end

		if attach > 0 then
			ccamheight = CLAMPCROUCHCAMHEIGHT( ccamheight, -1 )
		end

		entity:Remove()
		cheight = math.Clamp(cheight, GetConVar("dynamiccamerahull_minheight"):GetFloat(), height / 1.83214558 - 1)
		--ply:SetNWFloat("DynamicCamera:CrouchHeight", cheight)
		--ply:SetNWFloat("DynamicCamera:CrouchCamHeight", ccamheight)

		local hullmin = Vector(height / -4.5, height / -4.5, 0)
		local hullmax = Vector(height / 4.5, height / 4.5, CLAMPHEIGHT( height * 1.09121366 ))
		local hullcrouch = Vector(height / 4.5, height / 4.5, CLAMPHEIGHT( ccamheight > height / 1.83214558 and ccamheight + 3 or height / 1.83214558 ))

		if GetConVar( "dynamiccamerahull_debug" ):GetBool() then
			ply:ChatPrint( "PLAYER HEIGHT : " .. height )
			ply:ChatPrint( "PLAYER CROUCH HEIGHT : " .. cheight )
			ply:ChatPrint( "PLAYER CAM HEIGHT : " .. camheight )
			ply:ChatPrint( "PLAYER CROUCH CAM HEIGHT : " .. ccamheight )
			ply:ChatPrint( "PLAYER HULL HEIGHT : " .. hullmax.z )
			ply:ChatPrint( "PLAYER CROUCH HULL HEIGHT : " .. hullcrouch.z )
		end

		ply.DynamCamTable["height"] = height
		ply.DynamCamTable["cheight"] = cheight
		ply.DynamCamTable["camheight"] = camheight
		ply.DynamCamTable["ccamheight"] = ccamheight
		ply.DynamCamTable["hull"] = hullmax.z
		ply.DynamCamTable["chull"] = hullcrouch.z

		ply:SetHull(hullmin, hullmax)
		ply:SetHullDuck(hullmin, hullcrouch)

		net.Start("DynamicCameraHullViewSetup")
			net.WriteTable( ply.DynamCamTable )
		net.SendToServer()

		ply:SetViewOffset( Vector( 0, 0, camheight > 0 and camheight or height ) )
		ply:SetViewOffsetDucked( Vector( 0, 0, ccamheight > 0 and ccamheight or cheight ) )
	end

	net.Receive("DynamicCameraHullViewSetup", function()
		DynamicCameraHullViewCL(DynamicCameraGetModelNamePath())
	end)

	hook.Add("OutfitApply", "DynamicCamera:OutfitApply", function() print("OutfitApply") DynamicCameraHullViewCL(DynamicCameraGetModelNamePath()) end)

	local ECPostDrawViewModelRate = 0.5
	local ECPostDrawViewModelTime = CurTime()
	hook.Add("PostDrawPlayerHands", "DynamicCamera:PostDrawViewModel", function( hands, vm, ply, weapon )
		if ECPostDrawViewModelTime > CurTime() then return end
		ECPostDrawViewModelTime = CurTime() + ECPostDrawViewModelRate

		if IsValid( hands ) then

			hands:DrawModel()
			if ply:SkinCount() == ply:GetHands():SkinCount() then
				hands:SetSkin( ply:GetSkin() )
			end
			if ply:GetNumBodyGroups() > 0 and ply:GetNumBodyGroups() == ply:GetHands():GetNumBodyGroups() then
				hands:SetBodyGroups( ply:GetBodygroupsAsString() )
			end
		end
	end )

end

if SERVER then
	CreateConVar("dynamiccamerahull_enabled", 1, FCVAR_ARCHIVE, "Enables dynamically setting the hull size", 0, 1)

	-- Prevents this from running more than twice (thanks Garry)
	-- when manually reloading the file.
	cvars.RemoveChangeCallback("dynamiccamerahull_enabled", "dynamiccamerahull_enabled_callback")

	util.AddNetworkString("DynamicCameraHullViewSetup")

	cvars.AddChangeCallback("dynamiccamerahull_enabled", function(convar_name, value_old, value_new)
		for k, ply in pairs( player.GetAll() ) do
			DynamicCameraHullViewSV(ply)
		end
	end, "dynamiccamerahull_enabled_callback" )

	function DynamicCameraHullViewSV(ply, tbl)
		if ply.DynamCamTable == nil then
			net.Start("DynamicCameraHullViewSetup")
			net.Send(ply)
			return
		end
		local height = tbl["height"]
		local cheight = tbl["cheight"]
		local camheight = tbl["camheight"]
		local ccamheight = tbl["ccamheight"]

		local hullmin = Vector(height / -4.5, height / -4.5, 0)
		local hullmax = Vector(height / 4.5, height / 4.5, tbl["hull"])
		local hullcrouch = Vector(height / 4.5, height / 4.5, tbl["chull"])

		ply:SetViewOffset( Vector( 0, 0, camheight > 0 and camheight or height ) )
		ply:SetViewOffsetDucked( Vector( 0, 0, ccamheight > 0 and ccamheight or cheight ) )

		ply:SetHull(hullmin, hullmax)
		ply:SetHullDuck(hullmin, hullcrouch)
	end

	function DynamicCameraUpdateTrueModel(ply)
		net.Start("DynamicCameraHullViewSetup")
		net.Send(ply)
	end

	hook.Add("PlayerSpawn", "DynamicCamera:PlayerSpawn", function(ply)
		timer.Simple( 5, function()
			net.Start("DynamicCameraHullViewSetup")
			net.Send(ply)
		end )
	end)

	local ECPlayerTickRate = 5
	local ECPlayerTickTime = CurTime()
	hook.Add("PlayerTick", "DynamicCamera:PlayerTick", function(ply)
		if ECPlayerTickTime > CurTime() then return end
		ECPlayerTickTime = CurTime() + ECPlayerTickRate

		DynamicCameraUpdateTrueModel(ply)
	end)

	net.Receive( "DynamicCameraHullViewSetup", function(len, ply)
		ply.DynamCamTable = net.ReadTable()
		DynamicCameraHullViewSV(ply, ply.DynamCamTable)
	end )

	function DynamicCameraNPCCreate(ent)
		timer.Simple( 0.25, function()
			if !IsValid( ent ) then return end
			if !ent:IsNPC() then return end
			if !GetConVar( "dynamiccamerahull_npcs" ):GetBool() then return end
			if ent.IsVJBaseSNPC then return end
			if string.find( ent:GetClass(), "_torso" ) != nil then return end
			if string.find( ent:GetClass(), "zombie" ) != nil then return end

			if ent:GetModel() == nil or ent:GetModel() == "" then
				DynamicCameraNPCCreate(ent)
				return
			end

			local entity = ents.Create("base_anim")
			entity:SetModel(ent:GetModel())
			if entity:LookupSequence("idle_all_01") then
				entity:ResetSequence(entity:LookupSequence("idle_all_01"))
			end
			if entity:LookupSequence("reference") then
				entity:ResetSequence(entity:LookupSequence("reference"))
			end

			local bone = entity:LookupBone("ValveBiped.Bip01_Neck1")
			local height = 72
			if bone then
				local BONEPOS = entity:GetBonePosition(bone)
				height = entity:GetBonePosition(bone).z + 5
				if math.abs( BONEPOS.x ) > 10 or math.abs( BONEPOS.y ) > 10 then
					if GetConVar( "dynamiccamerahull_debug" ):GetBool() then
						ChatPrintDEBUG( entity:GetCreator(), "ENTITY BONE POS : " .. tostring( entity:GetBonePosition(bone) .. "\nNot Human? Bone is extruding from hull, cancelling." ) )
					end
					entity:Remove()
					return
				end
			else

				if GetConVar( "dynamiccamerahull_debug" ):GetBool() then
					ChatPrintDEBUG(ent:GetCreator(), "Neck Bone Not Found" )
				end
				entity:Remove()
				return
			end

			if GetConVar( "dynamiccamerahull_debug" ):GetBool() then
				ChatPrintDEBUG(ent:GetCreator(), "ENTITY HEIGHT : " .. ent:GetModel() .. " " .. height )
			end

			local hullmin = Vector(-height / 4.5, -height / 4.5, 0)
			local hullmax = Vector(height / 4.5, height / 4.5, height * 1.09121366)

			ent:SetCollisionBounds( hullmin, hullmax )

			entity:Remove()
		end )
	end
	hook.Add("OnEntityCreated", "DynamicCamera:OnEntityCreated", DynamicCameraNPCCreate )

end