AddCSLuaFile()

if CLIENT then return end

-- CIA Glow PVS Enhancement
-- Adds PVS points to players with glow to keep them loaded on the client
-- Credit: Snuffles the Fox

local CIA_GLOW_PVS = {}

local function ShouldBeVisibleTo(viewer, target)
    if not IsValid(viewer) or not IsValid(target) then return false end
    
    if viewer == target then return false end
    
    local round_state = GetRoundState()
    local viewer_role = viewer:GetRole()
    
    if not target:Alive() then return false end
    if round_state == ROUND_ACTIVE and not target:IsTerror() then return false end
    
    if SpecDM and target.IsGhost and target:IsGhost() then return false end
    
    local detective_check = (target:IsInTeam(viewer) and not target:GetDetective()) or (target:GetRole() == viewer_role)
    
    if detective_check then
        return true
    end
    
    if target:IsActive() and target:HasRole() then
        local rd = target:GetSubRoleData()
        local should_draw_overhead = (not viewer:IsActive() or target:IsInTeam(viewer) or rd.isPublicRole) and not rd.avoidTeamIcons
        
        if should_draw_overhead then
            return true
        end
    end
    
    return false
end

hook.Add("SetupPlayerVisibility", "CIA_GLOW_PVS_AddPoints", function(viewer, viewEntity)
    if not IsValid(viewer) or not viewer:IsPlayer() then return end
    
    local plys = player.GetAll()
    
    for i = 1, #plys do
        local target = plys[i]
        
        if ShouldBeVisibleTo(viewer, target) then
            AddOriginToPVS(target:GetPos())
        end
    end
end)