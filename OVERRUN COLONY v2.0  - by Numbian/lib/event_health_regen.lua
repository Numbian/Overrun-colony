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

	event_health_regen.lua
	
Generates an Event when a player's health is noticed to be regenerating.
Event content:
	player_index :: uint: index of player whos health is regenerating.
	generated :: float: amount of health generated since last event.

Note of warning:  This will still execute an event if you script or run a
command which adds health to a player.

--]]

require 'lib/event_extend'

local event_player_regen = Event.def("player_health_regen")

function healthregen_init(event)
	if not global.healthregen then
		global.healthregen = {
			players = {},
		}
	end
end

function healthregen_add_health_without_event(plidx, amount)
	-- adds health to a player without appling that increased amount
	-- to the event calculation.
	local player = game.players[plidx]
	if player and player.character and player.character.valid then
		player.character.health = player.character.health + amount
	end
	local hrplayer = healthregen_get_player(plidx)
	hrplayer.last_health = hrplayer.last_health + amount
end

function healthregen_entity_damaged(event)
	--game.print("DEBUG: HR: Entity type: " .. event.entity.type)
	if event.entity.type == "player" and event.entity.player ~= nil then
		local player = event.entity.player
		--game.print("DEBUG: HR: Player: " .. player.name)
		--game.print("Debug: Damaged player: " .. event.final_damage_amount)
		local hrplayer = healthregen_get_player(player.index)
		if player.character then
			hrplayer.last_health = player.character.health
		end
	end
end

function healthregen_get_player(index)
	if not global.healthregen.players[index] then
		local health = 0
		if player and player.character and player.character.valid then
			health = player.character.health
		end
		global.healthregen.players[index] = {
			last_health = health,
		}
	end
	return global.healthregen.players[index]
end

function healthregen_on_tick(event)
	if event.tick == 0 then return end -- don't execute on tick 0
	-- on-tick event to update the distance all players have been travelling.
	local iteration = 30
	local index = event.tick % iteration
	local player = game.players[index]
	while(player) do
		if player.connected and player.character and player.character.valid then
			healthregen_update_player(player)
		end
		-- find next player for this iteration, if exists.
		index = index + iteration
		player = game.players[index]
	end
end

function healthregen_update_player(player)
	local hr_player = healthregen_get_player(player.index)
	if player.character and player.character.valid then
		if hr_player.last_health < player.character.health then
			local generated = player.character.health - hr_player.last_health
			Event.dispatch({
				name = event_player_regen, 
				tick = game.tick,
				player_index = player.index,
				generated = generated,
			})
		end
		hr_player.last_health = player.character.health
	end
end

function healthregen_reinit_player_event(event)
	local player = game.players[event.player_index]
	local hr_player = healthregen_get_player(player.index)
	if player.character and player.character.valid then
		hr_player.last_health = player.character.health
	end
end

Event.register(Event.core_events.init, healthregen_init)
Event.register(Event.def("softmod_init"), healthregen_init)
Event.register(defines.events.on_player_joined_game, healthregen_reinit_player_event)
Event.register(defines.events.on_player_left_game, healthregen_reinit_player_event)
Event.register(defines.events.on_player_respawned, healthregen_reinit_player_event)
Event.register(defines.events.on_tick, healthregen_on_tick)
Event.register(defines.events.on_entity_damaged, healthregen_entity_damaged)
