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

	kwidget_table_with_header.lua - Kovus' GUI Widgets
	- table with fixed header that has sort functionality built-in.
	
Inspired by a table seen on RedMew's player list.  The table had sortable (and
clickable) headers, complete with a sort arrow.  Want to do the same here, but
generalized a bit, so that we don't know about the data we're displaying; just
that we're displaying it.
Note: the headers were also fixed in the frame, so they didn't scroll away.

--]]

local symbol_asc = "▲"
local symbol_desc = "▼"

--[[
	kw_table creates the table pair (header & data)
	Note: the data table will be contained in a scrollable field.

	container is the parent container of this table pair.
	header structure is an array of objects with the following fields:
		{ name, text, field }
	data structure is array of row objects.  Each row object is an array
	of objects referring to the contents of that cell.
		{ {text, renderfunc, etc}, {text, sortvalue, etc}, {text} }
	settings contains all sorts of settings:
		{
			widths: { array of {min, max} column widths },
			scrollpane:{width, height},
			name, scrollpane_name, header_name,
			may contain arbitrary data; will be passed to render functions
		}
--]]

function kw_table_init()
	if not global.kw_tables then
		global.kw_tables = {
			header_binds = {},
		}
	end
end

function kw_table_header_name_for(container, entry, settings)
	local hname = settings.header_name or 'table_header'
	local name = table.concat({ "kwtableheader", container.name, hname, entry.name}, "_")
	return name
end

function kw_table_header_names(container, headers, settings)
	-- returns an array of the header names that will be created with this
	-- table, so that we can listen for those click events.
	local names = {}
	for idx, entry in pairs(headers) do
		local name = kw_table_header_name_for(container, entry, settings)
		table.insert(names, name)
	end
	return names
end

function kw_table_header_is_asc(headertext)
	if type(headertext) == "table" and arr_contains(headertext, symbol_asc) then
		return true
	end
	if type(headertext) == 'string' and string.find(headertext, symbol_asc) then
		return true
	end
	return false
end

function kw_table_header_is_desc(headertext)
	if type(headertext) == "table" and arr_contains(headertext, symbol_desc) then
		return true
	end
	if type(headertext) == 'string' and string.find(headertext, symbol_desc) then
		return true
	end
	return false
end

function kw_table_draw(container, headers, data, settings)
	local tname = settings.name or 'fixed_table'
	local sname = 'table_scrollpane'
	if settings.scrollpane then
		sname = settings.scrollpane.name or sname
	end
	local hname = settings.header_name or 'table_header'
	
	-- do some simple validation
	if not settings.widths then
		error("Column widths must be specified.")
	end
	
	-- remove any existing header/table.
	if container[hname] then
		-- TODO: clear out the previously bound clickable headers.
		container[hname].destroy()
	end
	if container[sname] then
		container[sname].destroy()
	end
	
	-- display headers
	local header = container.add({
		type = "table",
		name = hname,
		column_count = #headers,
	})
	-- build header fields, binding clicks as well.
	for idx, entry in pairs(headers) do
		local sortdir = ""
		local label_name = kw_table_header_name_for(container, entry, settings)
		if settings.sort_field == entry.name then
			if settings.sort_dir == "asc" then
				sortdir = symbol_asc
			else
				sortdir = symbol_desc
			end
		end
		local label = header.add({
			type = "label",
			name = label_name,
			caption = {'kw.table.header', entry.text, sortdir},
		})
		
		label.style.font = settings.header_font or "default-large-bold"
		label.style.font_color = settings.header_color or { r=0.98, g=0.66, b=0.22}
		local width = settings.widths[entry.name] or 50
		label.style.minimal_width = width
		label.style.maximal_width = width
		
		if global.kw_tables.header_binds[label_name] then
			global.kw_tables.header_binds[label_name] = nil
		end
		if entry.sortable then
			global.kw_tables.header_binds[label_name] = settings.on_header_click
		end
		if settings.sortable_columns then
			if arr_contains(settings.sortable_columns, entry.name) then
				-- add binding for this column
				global.kw_tables.header_binds[label_name] = settings.on_header_click
			end
		end
	end
	
	-- Put the data table into a scrollpane.  Gives the Illusion of the headers
	-- Being fixed to the top of the table.
	local spane = container.add({
		type = "scroll-pane",
		name = sname,
		horizontal_scroll_policy = 'never',
		vertical_scroll_policy = 'auto',
	})
	if settings.scrollpane then
		if settings.scrollpane.width then
			spane.style.minimal_width = settings.scrollpane.width
			spane.style.maximal_width = settings.scrollpane.width
		end
		if settings.scrollpane.height then
			spane.style.minimal_height = settings.scrollpane.height
			spane.style.maximal_height = settings.scrollpane.height
		end
	end
	local datatable = spane.add({
		type = "table",
		name = tname,
		column_count = #headers,
	})
	-- sort data before display.
	if settings.sort_field then
		table.sort(data, function(a, b)
			local field_a = a[settings.sort_field]
			local field_b = b[settings.sort_field]
			local compare_a = field_a
			if type(field_a) == 'table' then
				compare_a = field_a.sortvalue or field_a.text or field_a
			end
			local compare_b = field_b
			if type(field_b) == 'table' then
				compare_b = field_b.sortvalue or field_b.text or field_b
			end
			if type(compare_a) == 'string' then
				compare_a = string.lower(compare_a)
			end	
			if type(compare_b) == 'string' then
				compare_b = string.lower(compare_b)
			end
			if type(compare_a) == 'table' or type(compare_b) == 'table' then
				log("kwidget_table_with_header.lua: attempted to sort tables.")
				return true
			end
			if settings.sort_dir == 'asc' then
				return compare_a > compare_b
			end
			return compare_a < compare_b
		end)
	end
	
	-- display
	for idx, row in pairs(data) do
		for jdx, header in pairs(headers) do
			local field = headers[jdx].name
			local celldata = row[field]
			-- determine if we're calling a function for the column or not.
			kw_table_draw_cell(datatable, idx, field, celldata, settings)
		end
	end
end

function kw_table_draw_cell(datatable, idx, field, celldata, settings)
	local cell = nil
	if type(celldata) == 'table' and celldata.render then
		cell = celldata.render(datatable, idx, field, celldata, settings)
	else
		local cellname = (idx .. field)
		local cellcaption = ''
		if type(celldata) == 'table' then
			if celldata.name then
				cellname = celldata.name
			end
			if celldata.text then
				cellcaption = celldata.text
			end
		else
			cellcaption = tostring(celldata)
		end
		cell = datatable[cellname]
		if cell then
			cell.caption = cellcaption
		else
			cell = datatable.add({
				type = "label",
				name = cellname,
				caption = cellcaption,
			})
		end
	end
	local width = settings.widths[field] or 50
	if type(celldata) == 'table' then
		if celldata.color then
			cell.style.font_color = celldata.color
		end	
		if celldata.font then
			cell.style.font = celldata.font or "default"
		end
	end
	cell.style.minimal_width = width
	cell.style.maximal_width = width
end

Event.register(Event.def("softmod_init"), function(event)
	kw_table_init()
end)

Event.register(defines.events.on_gui_click, function(event)
	local element = event.element
	if not element.valid then return end
	if string.find(element.name, "kwtableheader_") then
		local onclick = global.kw_tables.header_binds[element.name]
		local container = element.parent.parent
		if global.kw_tables.header_binds[element.name] then
			onclick(event, container, element.name)
		end
	end
end)
