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


	message_queue.lua

Defines a queue of messages for rcon clients to query.

During the 0.16 branch, RCON-based output was added, which means that we can
connect an rcon client, execute a command, and get output.  This is great for
commands executed from rcon, but if a script needs to provide output to an
rcon connection (that may or may not be connected, and certainly isn't the 
caller), then the aformentioned rcon output isn't useful.

This script defines a message queue for rcon clients.  An rcon client can 
then connect, query for new messages, get the responses, and go do what it 
needs to do.  The queue is not infinite.  We'll store messages with an index,
so that multiple rcon connections can connect, ask for messages "after index X"
and get the results.  It will be possible for us to not provide all the 
messages after index X, if we don't go back that far.

--]]

require 'lib/event_extend'

require 'lib/fb_util' -- parseParms(...)

json = require 'lib/dkjson'

MQueue = {}

function MQueue.clear(system)
	local smq = MQueue.system(system)
	smq.first_msg = nil
	smq.last_msg = nil
	smq.count = 0
end

function MQueue.prune(system, count, before_tick)
	-- Pruning old messages depends on meeting both conditions.
	-- there must be more than 'count' messages, and the oldest must
	-- be older than 'before_tick'
	local smq = MQueue.system(system)
	--print("DEBUG: smq #" .. smq.count .. " < count "..count .. "?")
	if smq.count < count then
		return nil
	end
	local msg = smq.first_msg
	while(msg) do
		if (smq.count <= count) or (msg.content.tick > before_tick) then
			break
		end
		-- move to the next msg, set the original msg's references to nil.
		-- then let GC do it's thing.
		msg = msg.next
		if msg then
			msg.prev.next = nil
			msg.prev = nil
		else
			smq.last_msg = nil
		end
		smq.count = smq.count - 1
	end
	smq.first_msg = msg
end

function MQueue.push(system, message)
	local smq = MQueue.system(system)
	local idx = smq.latest_index + 1
	msg = smq.last_msg
	if msg then
		msg.next = {prev = msg}
		msg = msg.next
	else
		msg = {prev = nil}
		smq.first_msg = msg
	end
	smq.last_msg = msg
	msg.content = {
		index = idx,
		tick = game.tick,
		message = message,
	}
	msg.next = nil
	
	smq.count = smq.count + 1
	smq.latest_index = idx
	
	-- currently, we'll prune based on 60 ticks/sec, for 5 minutes.
	MQueue.prune(system, 100, game.tick - (3600 * 5))
	return idx
end

function MQueue.get(system, in_index)
	local smq = MQueue.system(system)
	local index = tonumber(in_index)
	if not index then
		rcon.print("ERROR: mqueue.get: index is nil")
		return
	end
	-- gets all messages that have occurred since 'index'.
	-- Will not include 'index'.
	if index > smq.latest_index then
		if global.message_queue.debug_verbose1 then
			game.print("DEBUG: No new messages in " .. system)
		end
		return {count = 0}
	end
	if smq.count == 0 then
		if global.message_queue.debug_verbose1 then
			game.print("DEBUG: No messages in " .. system)
		end
		return {count = 0}
	end
	-- if system is specified, then only return messages relevent to that system
	local entries = {}
	local count = 0
	msg = smq.last_msg
	while msg do
		if index >= msg.content.index then
			break
		end
		table.insert(entries, msg.content)
		msg = msg.prev
	end
	return {count = #entries, entries = entries}
end

function MQueue.system(system)
	local smq = global.message_queue.queues[system]
	if not smq then
		global.message_queue.queues[system] = {
			latest_index = 0,
			count = 0,
			first_msg = nil,
			last_msg = nil,
		}
		smq = global.message_queue.queues[system]
	end
	return smq
end

commands.add_command('mqueue.push', 'Adds a message to a queue "mqueue.push(system, message)"', function(data)
	local params = parseParams(data.parameter)
	if data.player_index then
		-- only want to do the action if in debug
		if global.message_queue.debug then
			local pl = game.players[data.player_index]
			pl.print(serpent.block(data))
			pl.print("push() params: " .. serpent.block(params))
			result = MQueue.push(params[1], params[2])
			pl.print(serpent.block(result))
		end
	else
		-- This came from the server, probably RCON, so run!
		res = MQueue.push(params[1], params[2])
		if global.message_queue.debug then
			print("DEBUG: Response to mqueue.push: " .. json.encode(result))
		end
		rcon.print(json.encode(res))
	end
end)

commands.add_command('mqueue.get', 'Returns messages since index for a particular queue "mqueue.get(system, index)"', function(data)
	local params = parseParams(data.parameter)
	if data.player_index then
		-- only want to do the action if in debug
		if global.message_queue.debug then
			local pl = game.players[data.player_index]
			pl.print(serpent.block(data))
			pl.print("get() params: " .. serpent.block(params))
			local result = MQueue.get(params[1], params[2])
			pl.print(serpent.block(result))
		end
	else
		-- This came from the server, probably RCON, so run!
		result = MQueue.get(params[1], params[2])
		if global.message_queue.debug then
			print("DEBUG: Response to mqueue.get: " .. json.encode(result))
		end
		rcon.print(json.encode(result))
	end
end)

commands.add_command('mqueue.test', 'Just a test function...', function(data)
	if global.message_queue.debug then
		for entry = 1, 30 do 
			MQueue.push("test", 'payload_'..entry)
		end
		MQueue.prune("test", 5, game.tick)
		game.print(serpent.block(MQueue.system("test")))
	end
end)

commands.add_command('mqueue.gameinfo', 'Returns the current game information (seed, tick).  Used by backend to help identify a new game.', function(data)
	rcon.print(json.encode({
		seed = game.default_map_gen_settings.seed,
		tick = game.tick,
	}))
end)

remote.add_interface('mqueue', {
	clear = MQueue.clear,
	push = MQueue.push,
	get = MQueue.get,
})

local function initMod()
	if not global.message_queue then
		global.message_queue = {
			debug = false,
			debug_verbose1 = false,
			queues = {},
		}
	end
end

Event.register(Event.core_events.init, function(event)
	initMod()
end)
Event.register(Event.def("softmod_init"), function(event)
	initMod()
end)
