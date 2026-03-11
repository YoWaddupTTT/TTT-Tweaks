/*
MIT License

Copyright (c) 2026 GoopSwagger

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

hook.Add("OnEntityCreated", "TTT2MarkerProjectileSpeed", function(ent)
    if ent and ent:GetClass() == "paint_ball" and SERVER then
        ent:SetCustomCollisionCheck(true)
        ent.Touch = function(slf, other) end

        local update = ent.PhysicsUpdate
        ent.PhysicsUpdate = function(slf, phys)
            if not slf.speedUpdate then
                phys:SetVelocityInstantaneous((phys:GetVelocity() / 2.8) + (ent:GetOwner():EyeAngles():Up() * 80))
                slf.speedUpdate = true
            end

            update(slf, phys)
        end

        SafeRemoveEntityDelayed(ent, 10.0)
    end
end)

hook.Add("ShouldCollide", "TTT2MarkerProjectileCollision", function(ent1, ent2)
    local class1 = ent1:GetClass()
    local class2 = ent2:GetClass()

    if (class1 == "paint_ball" or class2 == "paint_ball") and (class1 == "ttt_seekgull_bird" or class2 == "ttt_seekgull_bird") then
        return false
    end
end)
