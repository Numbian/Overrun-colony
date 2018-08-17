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


	keystore.lua
	
	Define a method of sending and receiving data to an external process.  
	
	I wanted to have permission data (specifically users) be persistent between
	servers, and server restarts.  Instead of making it specific to permissions,
	the goal here is to generalize it into a request/response(callback) pattern.
	
	In this case, the most generic solution seems to be creating a key-value
	store layer, which can get the data out of factorio and get data back into
	factorio.  Then the data can be shared between servers or even simply
	persisted between server restarts.
	
	Responses are expected to use rcon (or server console, we can't tell the
	difference).  They get parsed for information, and appropriate callbacks
	get executed.  In this case, we'll abuse the Event system for these
	custom callbacks, as there may be multiple pieces of code which desire
	to be notified of a response (unlikely, but possible).

--]]

require 'lib/event_extend'

require 'lib/fb_util' -- parseParms(...)

local json = require 'lib/dkjson'

Keystore = {}

function Keystore.get(mod, field, callback, use_sgroup)
	if mod == nil or field == nil or callback == nil then
		error("Keystore.get(module, field, callback) - parameters must not be nil", 2)
	end
	
	Keystore.write_op('retrieve', mod, field, nil, callback, use_sgroup)
end

function Keystore.remove(mod, field, callback, use_sgroup)
	-- There's no logical difference between returning nil for the actual value
	-- vs returning nil because the value does not exist, so we'll cheat here
	-- and just call Keystore.set with 'nil' as the value.
	if mod == nil or field == nil then
		error("Keystore.remove(module, field, [callback]) - first 2 parameters must not be nil", 2)
	end
	Keystore.set(mod, field, nil, callback, use_sgroup)
end

function Keystore.set(mod, field, value, callback, use_sgroup)
	if mod == nil or field == nil then
		error("Keystore.set(module, field, [value, [callback]]) - first 2 parameters must not be nil", 2)
	end
	-- Sets the value associated with name in storage.  Will call callback
	-- with result of storage if requested.
	-- NOTE: Callback is optional.
	-- WARNING: Callback may be called WAY after value is set.
	
	-- only to server
	print("DEBUG: Keystore save: " .. mod .. "." .. field)
	
	Keystore.write_op('store', mod, field, value, callback, use_sgroup)
end

function Keystore.write_op(op, module, field, value, callback, use_sgroup)
	local callback_id = 0
	if callback then
		callback_id = global.keystore.cb_id
		global.keystore.callbacks[callback_id] = callback
		global.keystore.cb_id = callback_id + 1
	end
	
	local content = {
		op = op,
		module = module,
		field = field,
		value = value,
		callback_id = callback_id,
		global = use_sgroup,
	}

	if global.keystore.data_exchange == "message_queue" then
		remote.call('mqueue', 'push', 'keystore', content)
	elseif global.keystore.debug then
		game.write_file("keystore.operations", content.."\n", true)
	else
		game.write_file("keystore.operations", content.."\n", true, 0)
	end
end

function Keystore.private_clear()
	-- Clear any pre-existing keystore lookup queries.  We can't have 
	-- lookups without having a callback, and we have no callbacks.
	if global.keystore.data_exchange == "message_queue" then
		remote.call('mqueue', 'clear', 'keystore')
	elseif global.keystore.debug then
		game.write_file("keystore.operations", '', false)
	else
		game.write_file("keystore.operations", '', false, 0)
	end
end

function Keystore.print_result(params)
	print("DEBUG:")
	print("\tModule: " .. serpent.block(params.module))
	print("\tField: " .. serpent.block(params.field))
	print("\tValue: " .. serpent.block(params.value))
end

commands.add_command('keystore.fetch', 'Returns the data for a keystore lookup', function(data)
	-- Command executed by external script when responding to a keystore.get
	-- request.  This will get the data, then call the provided 'get' callback.
	if not data.player_index then
		local params = parseParams(data.parameter)
		local callback = Keystore.print_results
		if params[3] then
			callback = loadstring(params[3])
		end
		-- should be module, field, callback
		Keystore.get(params[1], params[2], callback)
	end
end)

commands.add_command('keystore.event', 'Called when a keystore operation completes - executes associated callback', function(data)
	-- Command executed by external script when responding to a keystore.set
	-- request.  Get the 'set' status, then call callback, if it exists.
	if not data.player_index then
		local params, pos, err = json.decode(data.parameter)
		if not err then
			print("keystore.event params: " .. serpent.line(params))
			local cid = tonumber(params.callback_id)
			if cid > 0 then
				local cb = global.keystore.callbacks[cid]
				pcall(cb, params)
				global.keystore.callbacks[cid] = nil
			end
			-- Sort of a strange thing to think that if we don't have a callback
			-- we don't know of anything to do with these, but that's the truth.
		end
	end
end)

commands.add_command('keystore.store', 'Stores data into the keystore.', function(data)
	-- Command executed by external script when responding to a keystore.set
	-- request.  Get the 'set' status, then call callback, if it exists.
	if not data.player_index then
		local params = parseParams(data.parameter)
		local callback = Keystore.print_results
		if params[4] then
			callback = loadstring(params[4])
		end
		-- should be module, field, value, callback
		Keystore.set(params[1], params[2], params[3], callback)
	end
end)

remote.add_interface('keystore', {
	set = Keystore.set,
	get = Keystore.get,
})

local function initMod()
	if not global.keystore then
		global.keystore = {
			debug = true,
			cb_id = 1,
			callbacks = {},
			data_exchange = "message_queue",
		}
		if global.keystore.data_exchange == "message_queue" then
			-- Check that the message queue module exists.
			if not remote.interfaces['mqueue'] then
				print("Unable to use 'message_queue' for keystore: module not loaded.")
				global.keystore.data_exchange = 'file'
			end
		end
		Keystore.private_clear()
		-- Note: leave the set file alone, in case it hasn't been processed yet.
	end
end

Event.register(Event.core_events.init, function(event)
	initMod()
end)
Event.register(Event.def("softmod_init"), function(event)
	initMod()
end)
