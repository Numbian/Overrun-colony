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

	spectate.lua

Implements a spectator mode for a player to enter into in order to see what
someone else is talking about.  Also useful for players to help identify
griefers.

We'll try and notify a player that they are being injured or killed.
- Need visual notification
- Need death to cause a player died event (manually created).
- Need a fast way back to their character.

--]]

require 'lib/event_extend'
require 'lib/fb_util'

Spec = {}

function Spec.init(event)
	if not global.spec then
		global.spec = {
			followers = {},
			being_followed_by = {},
			orig_chars = {},
			max_range = 64, -- Chunks are 32x32, so this is 2 chunks.
		}
	end
	if remote.interfaces['perms'] then
		-- make sure the permissions interface knows about the perms we use.
		remote.call('perms', 'registerPermission', 'spec.follow_any')
	end
end

function Spec.can_follow(src, dst)
	-- check if src is permitted to follow dst
	if src.force == dst.force then
		return true
	end
	if src.admin then
		return true
	end
	if remote.interfaces['perms'] then
		return remote.call('perms', 'userHasPermission', src.name, 'spec.follow_any')
	end
	return false
end

function Spec.check_char_damaged(event)
	if event.entity.type == "player" then
		for idx, char in pairs(global.spec.orig_chars) do
			if char == event.entity then
				local player = game.players[idx]
				player.print("You are being injured!")
			end
		end
	end
end

function Spec.check_char_died(event)
	if event.entity.type == "player" then
		for idx, char in pairs(global.spec.orig_chars) do
			if char == event.entity then
				local player = game.players[idx]
				player.print("Your character has died while you were spectating someone else.")
				global.spec.orig_chars[idx] = nil
			end
		end
	end
end

function Spec.cmd_spectate(data)
	-- only valid for players, not for console
	if not data.player_index then
		print("Unable to execute from console, as this command is only for players.")
		rcon.print("Unable to execute from console, as this command is only for players.")
		return
	end
	local player = game.players[data.player_index]
	if not data.parameter or data.parameter == '' then
		player.print("You need to specify a name to follow: /spectate username")
		return
	end
	local dstplayer = getPlayerNamed(data.parameter)
	if not dstplayer then
		player.print("No player named '"..data.parameter.."' found.")
		return
	end
	Spec.start_follow(player, dstplayer)
end

function Spec.cmd_stop_spectate(data)
	-- only valid for players, not for console
	if not data.player_index then
		print("Unable to execute from console, as this command is only for players.")
		rcon.print("Unable to execute from console, as this command is only for players.")
		return
	end
	local player = game.players[data.player_index]
	Spec.stop_follow(player)
end

function Spec.follow_update_tick(event)
	-- Update the watchers.
	if event.tick == 0 then return end
	for src, dst in pairs(global.spec.followers) do
		if src and dst then
			srcp = game.players[src]
			dstp = game.players[dst]
			if srcp and dstp and srcp.connected and dstp.connected then
				srcp.teleport(dstp.position, dstp.surface)
			else
				Spec.stop_follow(srcp)
				global.spec.followers[src] = nil
			end
		elseif src then
			-- src without dst?  Stop following.
			Spec.stop_follow(srcp)
			global.spec.followers[src] = nil
		end
	end
end

function Spec.player_moved(event)
	-- Check that spectators do not stray too far away from their follow mark
	local fol = global.spec.followers
	if fol[event.player_index] then
		local spectator = game.players[event.player_index]
		if spectator.character == nil then
			local target = game.players[fol[event.player_index]]
			if distance(spectator.position, target.position) > global.spec.max_range then
				spectator.print("You have moved too far away from your target.  Recentering..")
				spectator.teleport(target.position, target.surface)
			end
		end
	end
	local bfb = global.spec.being_followed_by
	if bfb[event.player_index] then
		local target = game.players[event.player_index]
		for _, idx_spec in ipairs(bfb[event.player_index]) do
			local spectator = game.players[idx_spec]
			if spectator.character == nil then
				if distance(spectator.position, target.position) > global.spec.max_range then
					spectator.print("Your target has moved too far away from you.  Recentering..")
					spectator.teleport(target.position, target.surface)
				end
			end
		end
	end
end

function Spec.player_respawn(event)
	local player = game.players[event.player_index]
	global.spec.orig_chars[player.index] = player.character
	player.character = nil
	Spec.stop_follow(player)
end

function Spec.start_follow(src_player, dst_player, skip_check)
	-- Make src_player start following dst_player.
	-- If src_player has a character, then archive it off.
	if not skip_check then
		if not Spec.can_follow(src_player, dst_player) then
			src_player.print("Not allowed to follow ".. dst_player.name)
			return
		end
	end
	if src_player == dst_player then
		src_player.print("Cannot spectate yourself.")
		return
	end
	if src_player.character and src_player.character.valid then
		global.spec.orig_chars[src_player.index] = src_player.character
	end
	if dst_player.character and dst_player.character.valid then
		src_player.character = nil
		global.spec.followers[src_player.index] = dst_player.index
		bfb = global.spec.being_followed_by
		if not bfb[dst_player.index] then
			bfb[dst_player.index] = {}
		end
		table.insert(bfb[dst_player.index], src_player.index)
		src_player.teleport(dst_player.position, dst_player.surface)
	--elseif global.spec.followers[dst_player.index] then
		-- See if they're following someone, then we can follow them?
	else
		src_player.print("Unable to follow " .. dst_player.name)
	end
end

function Spec.stop_follow(src_player)
	-- Stop following anyone.
	if not src_player then
		-- weird.
		game.print("Unable to make unknown player stop watching.")
		return
	end
	if src_player.character and src_player.character.valid then
		-- nothing to do.
		return
	end
	-- Check that the previous character is valid.
	local orig = global.spec.orig_chars[src_player.index]
	local dest_idx = global.spec.followers[src_player.index]
	
	global.spec.followers[src_player.index] = nil
	if type(bfb[dest_idx]) == "table" then
		table.remove_keys(bfb[dest_idx], {src_player.index})
		if #(bfb[dest_idx]) == 0 then
			if type(bfb) == "table" then
				table.remove_keys(bfb, {dest_idx})
			end
		end
	end
	
	if orig and orig.valid then
		src_player.character = orig
	else
		-- Seems that the player character has died or otherwise vanished?
		-- Create a new one.
		src_player.ticks_to_respawn = 0
	end
	global.spec.orig_chars[src_player.index] = nil
end

commands.add_command('spectate', 'Spectate a player.  `/spectate player_name`', Spec.cmd_spectate)
commands.add_command('stop-spectate', 'Quit spectating another player', Spec.cmd_stop_spectate)

Event.register(Event.core_events.init, Spec.init)
Event.register(Event.def("softmod_init"), Spec.init)
Event.register(defines.events.on_entity_damaged, Spec.check_char_damaged)
Event.register(defines.events.on_entity_died, Spec.check_char_died)
Event.register(defines.events.on_player_respawned, Spec.player_respawn)
Event.register(defines.events.on_tick, Spec.follow_update_tick)
--Event.register(defines.events.on_player_changed_position, Spec.player_moved)
