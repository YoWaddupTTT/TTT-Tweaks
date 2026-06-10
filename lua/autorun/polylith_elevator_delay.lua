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
local ELEVATOR_DELAY = CreateConVar("ttt_polylith_elevator_delay", 25, CVAR_FLAGS, "How long before the AFK kill elevator triggers once the round starts.", 0, 500)

if SERVER and string.StartsWith(game.GetMap(), "ttt_polylith") then
    local disabledElevatorOnce = false

    hook.Add("TTTPrepareRound", "TTT-Tweak_PolylithElevatorDelay", function()
        local relays = ents.FindByName("elevator_start_decon")

        if #relays >= 1 then
            local relay = relays[1]
            relay:SetKeyValue("StartDisabled", '1')

            if disabledElevatorOnce then
                local delay = ELEVATOR_DELAY:GetFloat()
                print("[TTT-Tweaks] Triggering Polylith elevator in: ", delay)

                timer.Simple(delay, function()
                    if IsValid(relay) then
                        relay:SetKeyValue("StartDisabled", '0')
                        relay:Fire("Trigger")
                    end
                end)

            else
                print("[TTT-Tweaks] Disabled Polylith elevator on first round")
                disabledElevatorOnce = true
            end
        end
    end)
end