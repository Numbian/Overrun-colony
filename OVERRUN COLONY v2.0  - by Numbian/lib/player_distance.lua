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

	player_distance.lua - Small interface for recording player travel
	
	Inspired by RedMew's walked-distance.

--]]

require 'lib/event_extend'

local event_player_distance = Event.def("player_distance_update")

function pdistance_init(event)
	if not global.player_distance then
		global.player_distance = {}
	end
end

function pdistance_init_player(event)
	local player = game.players[event.player_index]
	if not global.player_distance[player.index] then
		global.player_distance[player.index] = {
			last_state = 'walked',
			walked = 0,
			driven = 0,
			trained = 0,
			last_position = {
				x = player.position.x,
				y = player.position.y,
			},
		}
	end
end

function pdistance_player_left(event)
	local player = game.players[event.player_index]
	pdistance_update_player(player)
end

function pdistance_update(event)
	local player = game.players[event.player_index]
	if player and player.character and player.character.valid then
		pdistance_update_player(player)
	end
end

function pdistance_player_drive_change(event)
	local player = game.players[event.player_index]
	pdistance_update_player(player)
end

function pdistance_update_player(player)
	-- add distance to current state.
	pd = global.player_distance[player.index]
	delta = {
		x = player.position.x - pd.last_position.x,
		y = player.position.y - pd.last_position.y,
	}
	local distance = math.sqrt(delta.x * delta.x + delta.y * delta.y)
	pd[pd.last_state] = pd[pd.last_state] + distance
	
	-- update current state & position
	pd.last_position = {
		x = player.position.x,
		y = player.position.y,
	}
	if player.vehicle then
		if player.vehicle.train then
			pd.last_state = 'trained'
		else
			pd.last_state = 'driven'
		end
	else
		pd.last_state = 'walked'
	end
	if distance > 0 then
		Event.dispatch({
			name = event_player_distance, 
			tick = game.tick,
			player_index = player.index,
		})
	end
end

-- functions for data retrieval (preferred via remote interface)
function pdistance_driven(player_idx)
	if not global.player_distance[player_idx] then
		return 0
	end
	return global.player_distance[player_idx].driven
end
function pdistance_walked(player_idx)
	if not global.player_distance[player_idx] then
		return 0
	end
	return global.player_distance[player_idx].walked
end
function pdistance_trained(player_idx)
	if not global.player_distance[player_idx] then
		return 0
	end
	return global.player_distance[player_idx].trained
end
function pdistance_travelled(player_idx)
	local pd = global.player_distance[player_idx]
	if not pd then
		return 0
	end
	return pd.driven + pd.walked + pd.trained
end
remote.add_interface('pdistance', {
	driven = pdistance_driven,
	walked = pdistance_walked,
	trained = pdistance_trained,
	travelled = pdistance_travelled,
})

Event.register(Event.def("softmod_init"), pdistance_init)
Event.register(defines.events.on_player_joined_game, pdistance_init_player)
Event.register(defines.events.on_player_left_game, pdistance_player_left)
Event.register(defines.events.on_player_driving_changed_state, pdistance_player_drive_change)
Event.register(defines.events.on_player_changed_position, pdistance_update)
