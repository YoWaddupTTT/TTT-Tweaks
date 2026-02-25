ENT.Type = "anim"
ENT.Base = "base_anim"

ENT.PrintName = "Christmas Present"
ENT.Author = "TTT2"
ENT.Spawnable = false
ENT.AdminSpawnable = false
ENT.Model = "models/katharsmodels/present/type-2/big/present.mdl"

-- Console variable for special items (shared so clients can access it)
CreateConVar("ttt_present_special_items", "1", FCVAR_NOTIFY + FCVAR_ARCHIVE, "Enable special items from Christmas presents (0 = disabled, 1 = enabled)")
