--[[
Copyright 2017-2018 "Kovus" <kovus@soulless.wtf>

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice,
this list of conditions and the following disclaimer in the documentation and/or
other materials provided with the distribution.
3. Neither the name of the copyright holder nor the names of its contributors
may be used to endorse or promote products derived from this software without
specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

	player_time.lua - Create periodic events for updating player time

--]]

require 'lib/event_extend'

local event_player_time_10sec = Event.def("player_time_10_sec")
local event_player_time_1min  = Event.def("player_time_1_min")
local event_player_time_10min = Event.def("player_time_10_min")
local event_player_time_1hour = Event.def("player_time_1_hour")

function ptime_update_all(event)
	if event.tick == 0 then return end -- don't execute on tick 0
	-- on-tick event to create event for updating the online time for players
	ptime_update_iteration(event, 600, event_player_time_10sec)
	ptime_update_iteration(event, 3600, event_player_time_1min)
	ptime_update_iteration(event, 36000, event_player_time_10min)
	ptime_update_iteration(event, 216000, event_player_time_1hour)
end

function ptime_update_iteration(event, iteration, eventidx)
	local index = event.tick % iteration
	local player = game.connected_players[index]
	while(player) do
		ptime_update_player(player, eventidx)
		-- find next player for this iteration, if exists.
		index = index + iteration
		player = game.connected_players[index]
	end
end

function ptime_update_player(player, eventidx)
	Event.dispatch({
		name = eventidx,
		tick = game.tick,
		player_index = player.index,
		online_time = player.online_time,
	})
end

Event.register(defines.events.on_tick, ptime_update_all)
