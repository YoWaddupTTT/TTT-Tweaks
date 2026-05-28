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

local CVAR_FLAGS = {FCVAR_NOTIFY, FCVAR_ARCHIVE, FCVAR_REPLICATED}
local ENABLE_OVERRIDE = CreateConVar("ttt_hellcrane_rounds_override", 1, CVAR_FLAGS, "Whether to override the number of rounds played on ttt_hellcrane", 0, 1)
local ROUND_COUNT     = CreateConVar("ttt_hellcrane_rounds_count", 4, CVAR_FLAGS, "How many rounds will be played on ttt_hellcrane before map vote", 1, 100)

if SERVER then
    hook.Add("PostInitialize", "TTT-Tweaks_OverrideRoundsLeft", function()
        if game.GetMap() == "ttt_hellcrane" and ENABLE_OVERRIDE:GetBool() then
            local roundCount = ROUND_COUNT:GetInt()

            print("[TTT-Tweaks] Overriding Hellcrane round count; rounds: ", roundCount)
            gameloop.SetRoundsLeft(roundCount)
        end
    end)
end