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

	rdchat.lua
	
Methods for sending and receiving chat messages for an external process.

--]]

require 'lib/event_extend'

require 'lib/fb_util' -- parseParms(...)

local json = require 'lib/dkjson'

RDChat = {}

function RDChat.send(event)
	name = 'server'
	if event.player_index then
		player = game.players[event.player_index]
		name = player.name
	end
	
	local content = {
		user = name,
		event = 'chat',
		message = event.message,
	}
	
	if global.rdchat.data_exchange == "message_queue" then
		remote.call('mqueue', 'push', 'rdchat', content)
	end
end
function RDChat.join(event)
	player = game.players[event.player_index]
	local content = {
		user = player.name,
		event = 'player_joined',
		message = "<"..player.name.."> has joined the game.",
	}
	remote.call('mqueue', 'push', 'rdchat', content)
end
function RDChat.leave(event)
	player = game.players[event.player_index]
	local content = {
		user = player.name,
		event = 'player_left',
		message = "<"..player.name.."> has left the game.",
	}
	remote.call('mqueue', 'push', 'rdchat', content)
end
function RDChat.player_died(event)
	player = game.players[event.player_index]
	local content = {
		user = player.name,
		event = 'player_died',
	}
	if event.cause then
		content.cause = event.cause.name
		if event.cause.name == "player" then
			content.cause_detail = event.cause.player.name
		end
		if event.cause.type == 'car' or event.cause.type == 'locomotive' then
			if event.cause.get_driver() then
				local driver = event.cause.get_driver()
				content.cause_detail = event.cause.get_driver().player.name
			end
		end
	end
	remote.call('mqueue', 'push', 'rdchat', content)
end

function RDChat.research_finished(event)
	local research = event.research
	local content = {
		event = 'research_finished',
		name = research.name,
	}
	remote.call('mqueue', 'push', 'rdchat', content)
end
function RDChat.research_started(event)
	local research = event.research
	local content = {
		event = 'research_started',
		name = research.name,
	}
	if event.last_research and event.last_research.researched == false then
		content.last_name = event.last_research.name
	end
	remote.call('mqueue', 'push', 'rdchat', content)
end

function RDChat.status(event)
	
end

function RDChat.message(user, message)
	game.print({'rdchat.message', user, message})
	game.play_sound({path="utility/console_message"})
end

function RDChat.private_clear()
	-- Clear any pre-existing keystore lookup queries.  We can't have 
	-- lookups without having a callback, and we have no callbacks.
	if global.rdchat.data_exchange == "message_queue" then
		remote.call('mqueue', 'clear', 'rdchat')
	end
end

commands.add_command('rdchat.message', 'Called when a Discord message arrives', function(data)
	-- Command executed by external script when responding to a keystore.set
	-- request.  Get the 'set' status, then call callback, if it exists.
	if not data.player_index then
		local params, pos, err = json.decode(data.parameter)
		if not err then
			--print("rdchat.message params: " .. serpent.line(params))
			RDChat.message(params[1], params[2])
		end
	end
end)
commands.add_command('rdchat.techlist', 'Called by the Discord bot to get the technology names', function(data)
	if not data.player_index then
		local techs = ''
		local count = 0
		for _, tech in pairs(game.technology_prototypes) do
			if count > 0 then
				techs = {'rdchat.tree_chain', techs, {'rdchat.tree_entry', tech.name, tech.localised_name}}
			else
				techs = {'rdchat.tree_entry', tech.name, tech.localised_name}
			end
			count = count + 1
		end
		rcon.print({'rdchat.tech_tree', techs})
	end
end)
commands.add_command('rdchat.entitylist', 'Called by the Discord bot to get the entity names', function(data)
	if not data.player_index then
		local entities = ''
		local count = 0
		for _, entry in pairs(game.entity_prototypes) do
			if count > 0 then
				entities = {'rdchat.tree_chain', entities, {'rdchat.tree_entry', entry.name, entry.localised_name}}
			else
				entities = {'rdchat.tree_entry', entry.name, entry.localised_name}
			end
			count = count + 1
		end
		rcon.print({'rdchat.entity_tree', entities})
	end
end)
commands.add_command('rdchat.status', 'Called by the Discord bot to get current server status', function(data)
	if not data.player_index then
		data = {
			players = {},
			current_research = {},
		}
		if game.forces['player'] and game.forces['player'].current_research then
			tech = game.forces['player'].current_research
			data.current_research = {
				name = tech.name,
			}
		end
		for _, player in pairs(game.connected_players) do
			table.insert(data.players, player.name)
		end
		rcon.print(json.encode(data))
	end
end)


remote.add_interface('rdchat', {
	send = RDChat.send,
})

function RDChat.initMod(event)
	if not global.rdchat then
		global.rdchat = {
			debug = false,
			data_exchange = "message_queue",
		}
		if global.rdchat.data_exchange == "message_queue" then
			-- Check that the message queue module exists.
			if not remote.interfaces['mqueue'] then
				print("Unable to use 'message_queue' for keystore: module not loaded.")
			end
		end
		RDChat.private_clear()
		-- Note: leave the set file alone, in case it hasn't been processed yet.
	end
end

Event.register(Event.core_events.init, RDChat.initMod)
Event.register(Event.def("softmod_init"), RDChat.initMod)

Event.register(defines.events.on_console_chat, RDChat.send)
Event.register(defines.events.on_player_joined_game, RDChat.join)
Event.register(defines.events.on_player_left_game, RDChat.leave)
Event.register(defines.events.on_pre_player_died, RDChat.player_died)
Event.register(defines.events.on_research_finished, RDChat.research_finished)
Event.register(defines.events.on_research_started, RDChat.research_started)
