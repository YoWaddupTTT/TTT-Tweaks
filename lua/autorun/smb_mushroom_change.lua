/*
MIT License

Copyright (c) 2026 Guy-L

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

hook.Add("InitPostEntity", "TTT-Tweaks_PreventJesterMarios", function()
    local gsmbWep = weapons.GetStored("giantsupermariomushroom")
    if not gsmbWep then return end

    print("[TTT-Tweaks] Applying Giant Super Mario Mushroom prevention for Jesters")

    if SERVER then
        local OGMarioPrimary = gsmbWep.PrimaryAttack

        gsmbWep.PrimaryAttack = function(self)
            local owner = self:GetOwner()

            if owner:GetTeam() == TEAM_JESTER then
                owner:ChatPrint("Jesters are allergic to this!")

                -- throw out weapon even if Allow Drop is disabled
                local newShroom = ents.Create("giantsupermariomushroom")
                newShroom:SetPos(owner:GetShootPos())
                newShroom._JustThrown = true
                newShroom:Spawn()

                local phys = newShroom:GetPhysicsObject()
                if IsValid(phys) then
                    phys:SetVelocity(owner:GetAimVector() * 500)
                    phys:AddAngleVelocity(Vector(0, 0, 1000))
                end

                self:Remove()
                timer.Simple(1, function() newShroom._JustThrown = false end)
                if file.Exists("sound/giftwrap/throw.mp3", "GAME") then
                    owner:EmitSound("giftwrap/throw.mp3", 75, math.random(90, 120))
                end

            else
                OGMarioPrimary(self)
            end
        end

        -- prevent picking up shroom that was just thrown
        hook.Add("PlayerCanPickupWeapon", "TTT-Tweaks_DontAutoPickUpThrownShroom", function(ply, wep)
            if wep:GetClass() == "giantsupermariomushroom" and wep._JustThrown then
                return false
            end
        end)

    elseif CLIENT then
        local lmbInstructions = {
            "Become Super Mario",
            "Go big mode",
            "Eat",
            "Power up",
            "Mario time",
        }

        gsmbWep.Initialize = function(self)
            self:AddTTT2HUDHelp(lmbInstructions[math.random(#lmbInstructions)], "Say the line")
        end

        -- prevents default sound/bullet from appearing client-side
        gsmbWep.PrimaryAttack = function() end
    end
end)