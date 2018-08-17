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

	kwidget_playertable.lua - Kovus' GUI Widget - player table.
	
	Inspired by ExplosiveGaming's player table.
	
	Builds a table of players, with an optional function for rendering
	additional commands or buttons, per-player.
	
--]]

require 'lib/fb_util'
require 'lib/kwidgets'
require 'lib/kwidget_table_with_header'
require 'lib/color_conversions'

function kw_playerTableSortItems()
	-- localizations in kwidgets.cfg
	return {
		{'kw.pTable.sort_id'},
		{'kw.pTable.sort_name'},
		{'kw.pTable.sort_time'},
		{'kw.pTable.sort_group'},
	}
end

-- these need to match up.  we can go from index to name
-- but 'short name' to index is harder.  I want descriptive code.
function kw_playerFilterList()
	return {
		{'kw.pTable.filter_both'},
		{'kw.pTable.filter_online'},
		{'kw.pTable.filter_offline'},
	}
end
function kw_playerFilterByname(str)
	strmap = {
		['both'] = 1,
		['online'] = 2,
		['offline'] = 3,
	}
	return strmap[str]
end

function kw_playerTable_columns(settings)
	local columns = {}
	if not settings.no_icons then
		table.insert(columns, {text={'playertable.header_icon'}, name='icon', sortable=false})
	end
	table.insert(columns, {text={'playertable.header_name', #game.connected_players}, name='playername', sortable=true})
	if settings.status then
		table.insert(columns, {text={'playertable.header_status'}, name='status', sortable=true})
	end
	table.insert(columns, {text={"playertable.header_played"}, name='time', sortable=true})
	if settings.distances and settings.distances.walked then
		table.insert(columns, {text={"playertable.header_walked"}, name='walked', sortable=true})
	end
	if settings.distances and settings.distances.driven then
		table.insert(columns, {text={"playertable.header_driven"}, name='driven', sortable=true})
	end
	if settings.distances and settings.distances.trained then
		table.insert(columns, {text={"playertable.header_trained"}, name='trained', sortable=true})
	end
	if settings.distances and settings.distances.total then
		table.insert(columns, {text={"playertable.header_travelled"}, name='travelled', sortable=true})
	end
	table.insert(columns, {text={"playertable.header_group"}, name='group', sortable=true})
	if settings.renderFunc then
		table.insert(columns, {
			text=settings.action_header or {'playertable.header_actions'}, 
			name='actions', 
			sortable=false,
		})
	end
	return columns
end

function kw_playerTable_icon_draw(table, rownumber, field, celldata, settings)
	local fieldname = celldata.name or (rownumber .. field)
	local cell = table[fieldname]
	if cell then
		cell.clear()
	else
		cell = table.add({
			type = 'flow',
			name = fieldname,
		})
	end
	local sprite = cell.add({
		type = "sprite",
		sprite = celldata.sprite,
	})
	return cell
end

function kw_playerTable_player_icon(player)
	local player_role = player.tag:sub(2,-2)
	if remote.interfaces['ktags'] then
		icon = remote.call('ktags', 'getTagIcon', player.tag:sub(2,-2))
		if icon then
			return {render=kw_playerTable_icon_draw, sprite=icon}
		end
	end
	return {render=kw_playerTable_icon_draw, sprite='entity/player'}
end

function kw_playerTable_distances(player)
	local travel = {walked=0, trained=0, driven=0, total=0}
	local idx = player.index
	if remote.interfaces['pdistance'] then
		travel.driven = remote.call('pdistance', 'driven', idx)
		travel.driven_text = {
			'playertable.distance', 
			string.format("%0.3f", travel.driven / 1000)
		}
		travel.trained = remote.call('pdistance', 'trained', idx)
		travel.trained_text = {
			'playertable.distance', 
			string.format("%0.3f", travel.trained / 1000)
		}
		travel.walked = remote.call('pdistance', 'walked', idx)
		travel.walked_text = {
			'playertable.distance', 
			string.format("%0.3f", travel.walked / 1000)
		}
		travel.travelled = remote.call('pdistance', 'travelled', idx)
		travel.travelled_text = {
			'playertable.distance', 
			string.format("%0.3f", travel.travelled / 1000)
		}
	end
	return travel
end

function kw_playerTable_player_onlineTime(player)
	local time = tick2time(player.online_time)
	return {
		'playertable.online_time', 
		time.hours, 
		string.format("%02d", time.minutes), 
		string.format("%02d", time.seconds)
	}
end

function kw_playerTable_build_playerdata(player, settings)
	local playerdata = {}
	playerdata.icon = kw_playerTable_player_icon(player)
	playerdata.playername = {
		text=player.name, 
		font="default-bold"
	}
	if settings.use_player_colors then
		playerdata.playername.color = RGB01.brighten(player.color, 1.17, 50)
	end
	playerdata.status = {text={'playertable.online'}, sortvalue=1}
	if not player.connected then
		playerdata.status = {text={'playertable.offline'}, sortvalue=2}
	end
	local dist = kw_playerTable_distances(player)
	playerdata.driven    = {text=dist.driven_text, sortvalue=dist.driven}
	playerdata.walked    = {text=dist.walked_text, sortvalue=dist.walked}
	playerdata.trained   = {text=dist.trained_text, sortvalue=dist.trained}
	playerdata.travelled = {text=dist.travelled_text, sortvalue=dist.travelled}
	playerdata.time = {text=kw_playerTable_player_onlineTime(player), sortvalue=player.online_time}
	local group = perms.playerGroup(player.name)
	playerdata.group = {text=group.i18n_sname, sortvalue=group.name}
	playerdata.actions = {render=settings.renderFunc, target=player}
	return playerdata
end

function kw_playerTable_playerlist(settings)
	local sourcelist = {}
	local playerlist = {}
	if settings.playernamelist then
		for idx, name in pairs(settings.playernamelist) do
			local player = getPlayerNamed(name)
			if player then
				--if settings.connected_players and player.connected then
					table.insert(sourcelist, player)
				--elseif not settings.connected_players then
				--	table.insert(playerlist, player)
				--end
			end
		end
	elseif settings.connected_players then
		sourcelist = game.connected_players
	else
		sourcelist = game.players
	end

	for idx, player in pairs(sourcelist) do
		if not settings.filterFunc or (settings.filterFunc and settings.filterFunc(player, settings)) then
			local playerdata = kw_playerTable_build_playerdata(player, settings)
			table.insert(playerlist, playerdata)
		end
	end
	return playerlist
end

function kw_playerTable_settings(settings)
	if not settings.widths then
		settings.widths = {}
	end
	settings.widths.icon = settings.widths.icon or 30
	settings.widths.playername = settings.widths.playername or 150
	settings.widths.status = settings.widths.status or 65
	settings.widths.time = settings.widths.time or 55
	settings.widths.group = settings.widths.group or 60
	settings.widths.actions = settings.widths.actions or 200
	
	settings.widths.walked    = settings.widths.walked    or 75
	settings.widths.driven    = settings.widths.driven    or 75
	settings.widths.trained   = settings.widths.trained   or 75
	settings.widths.travelled = settings.widths.travelled or 75
	
	settings.name = "PlayerTable"
	settings.scrollpane = settings.scrollpane or { width=545, height=265 }
	--settings.sort_field = settings.sort_field or 'playername'
	--settings.sort_dir = sortdir or "desc"
	--settings.on_header_click = test_headerClick
	return settings
end

function kw_playerTable_headerClick(event, container, header_field)
	local element = event.element
	local settings = global.playertable_settings[container.player_index .. "." .. container.name]

	local dir = "desc"
	if kw_table_header_is_desc(element.caption) then
		dir = "asc"
	end
	
	local headers = kw_playerTable_columns(settings)

	local header = headers[1].name
	for idx, entry in pairs(headers) do
		if kw_table_header_name_for(container, entry, settings) == element.name then
			-- selected header
			header = entry.name
		end
	end
	kw_playerTable_draw(container, header, dir)
end

function kw_playerTable(container, in_name, in_playerlist, in_settings, filterFunc, renderFunc)
	local settings = kw_playerTable_settings(in_settings or {})
	settings.table_name = in_name or 'playerTable'
	settings.name = in_name or 'playerTable'
	settings.playernamelist = in_playerlist
	settings.filterFunc = filterFunc
	settings.renderFunc = renderFunc
	settings.on_header_click = kw_playerTable_headerClick
	if not global.playertable_settings then
		global.playertable_settings = {}
	end
	player = game.players[container.player_index]
	global.playertable_settings[container.player_index .. "." .. container.name] = settings
	kw_playerTable_draw(container, 'playername', 'desc')
end

function kw_playerTable_draw(container, sort_field, sort_dir)
	local settings = global.playertable_settings[container.player_index .. "." .. container.name]

	local name = settings.table_name or 'playerTable'
	settings.sort_field = sort_field
	settings.sort_dir = sort_dir or "desc"
	
	-- only allow a single player table in the container
	if container[name] then
		container[name].destroy()
	end
	
	
	local columns = kw_playerTable_columns(settings)
	local data = kw_playerTable_playerlist(settings)
	kw_table_draw(container, columns, data, settings)

	return
end

function kw_playerTable_update(container, player_index, options)
	local settings = global.playertable_settings[container.player_index .. "." .. container.name]
	local tablename = settings.table_name or 'playerTable'
	local ptable = container.table_scrollpane[tablename]
	if not ptable then
		-- Cannot update a table that isn't there.
		game.print("DEBUG: Unable to find player table named " .. tablename)
		return
	end
	local tblidx = 1
	local player = game.players[player_index]
	local row = 0
	--[[
	for idx, child in ipairs(ptable.children) do
		game.print("DEBUG: cell? " .. child.name)
	end
	game.print("DEBUG: Cell exists? " .. serpent.block(ptable['1playername'].name))
	--]]
	for _, child in ipairs(ptable.children) do
		local index = string.match(child.name, "(%d+)playername")
		if index then
			if child.caption == player.name then
				row = tonumber(index)
				break
			end
		end
	end
	if row > 0 then
		-- Update the cells associated with this row/player.
		local pdata = kw_playerTable_build_playerdata(player, settings)
		local headers = kw_playerTable_columns(settings)
		for _, header in pairs(headers) do
			if header.name == "icon" and options.update_icon == false then
				-- do nothing.
			else
				kw_table_draw_cell(ptable, row, header.name, pdata[header.name], settings)
			end
		end
	end
end
