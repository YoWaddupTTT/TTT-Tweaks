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

hook.Add("InitPostEntity", "TTT2PositionSwapperFix", function()
    swep = weapons.GetStored("posswitch")

    if not swep then return end

    swep.PrimaryAttack = function(self)
        if SERVER then
            timer.Simple(0.1, function()
                local owner = self:GetOwner()
                local target = self.TargetEnt

                if IsValid( target ) and owner:Alive() then
                    if ( target:Alive() ) then
                        local selfpos = owner:GetPos()
                        local entpos = target:GetPos()

                        owner:SetPos( entpos )
                        target:SetPos( selfpos )

                        owner:ChatPrint( "Swapped position with " .. target:Nick() .. "." )
                        self:Remove()
                    else
                        owner:ChatPrint( "The target is dead!" )
                    end
                else
                    owner:ChatPrint( "No target is selected: Right-click on a player to select one." )
                    return "failed"
                end
            end)
        end
    end
end)
