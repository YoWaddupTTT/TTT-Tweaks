-- Trigger Finger Outline Fix
-- Ensures that Trigger Finger chipped players are outlined
-- Credit: Snuffles the Fox

hook.Add("PostDrawEffects", "TriggerFingerOutlineFix", function()
    for _, ply in ipairs(player.GetAll()) do
        if ply:HasChip() then
            outline.Add(ply.traitorChip, Color(0, 0, 0, 0), OUTLINE_MODE_BOTH)
        end
    end
end)