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

if CLIENT then

local framenum = 0
local startTime = 0

hook.Add("Initialize", "TTT2AntiAfkFix", function()
    framenum = 0

    timer.Simple(0.1, function()
        startTime = SysTime()
        timer.Pause("idlecheck")
    end)
end)

hook.Add("PostRender", "TTT2AntiAfkFix", function()
    if framenum == -1 then return end

    if framenum < 300 then
        framenum = framenum + 1
    else
        timer.UnPause("idlecheck")
        framenum = -1
    end
end)

hook.Add("Move", "TTT2AntiAfkFix", function(ply, mv)
    if framenum ~= -1 or not IsFirstTimePredicted() then return end
    mv:SetButtons(bit.bxor(mv:GetButtons(), IN_BULLRUSH))
end)

end
