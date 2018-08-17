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

	kwidgets.lua - Kovus' GUI Widget wrappers.
	
	This is a series of methods which aim to provide convenience functionality
	over manually managing all aspects of gui element design.
	
	Top-Left Toolbar Buttons
	Flow & center frames
	Callbacks related to clicks.
	
--]]

require 'mod-gui'
require 'lib/kw_style'

kw = {} -- module

local function kw_init()
	if not global.widgets then
		global.widgets = {
			callbacks = {
				buttons = {},
				buttons2 = {},
				dropdowns = {},
			},
			button2tab = {},
			objects = {},
		}
	end
end
if not global.widgets then
	kw_init()
end
Event.register(Event.def("softmod_init"), function(event)
	kw_init()
end)

-- creates a new button and callback if provided
function kw_newButton(container, buttonName, caption, description, sprite, style, onClick)
	if not style then
		style = mod_gui.button_style
	end
	local parms = {name=buttonName, type = "button", caption=caption, tooltip=description, style = style}
	if sprite then
		parms.type = 'sprite-button'
		if sprite ~= '' then
			parms.sprite = sprite
			parms.caption = nil
		end
	end
	local button = container.add(parms)
	
	if onClick and type(onClick) == 'function' then
		kw_connectButton(buttonName, onClick)
	end
	return button
end

-- creates a new button in the upper-left corner "toolbar"
function kw_newToolbarButton(player, buttonName, caption, description, sprite, onClick)
	local container = mod_gui.get_button_flow(player)
	--container.style = 'table_spacing_flow_style'
	--container.style.left_padding = 4
	--container.style.top_padding = 4
	
	local button = nil
	if container[buttonName] then
		container[buttonName].destroy()
	end
	if not container[buttonName] then
		button = kw_newButton(container, buttonName, caption, description, sprite, nil, onClick)
		kw_applyStyle(button, global.kw_style.toolbar_button)
		--spacer = container.add({type='label', text=''})
		--kw_applyStyle(spacer, global.kw_style.toolbar_spacer)
	end
	return button
end

-- removes a button from the upper-left corner "toolbar"
function kw_delToolbarButton(player, buttonName)
	local container = mod_gui.get_button_flow(player)
	if container[buttonName] then
		container[buttonName].destroy()
	end
end

function kw_toolbar(player)
	return mod_gui.get_button_flow(player)
end

-- wrapper to connect a button to an on-click event.
function kw_connectButton(buttonName, onClick)
	global.widgets.callbacks.buttons[buttonName] = onClick
end
function kw_connectButtonMatch(buttonmatch, onClick)
	table.insert(global.widgets.callbacks.buttons2, {
		match = buttonmatch,
		callback = onClick,
	})
end
function kw_connectDropdown(name, onClick)
	global.widgets.callbacks.dropdowns[name] = onClick
end

--
-- Misc items:
--

-- horizontal line (foolishly implemented using a progressbar)
function kw_hline(container, name, settings)
	if not settings then
		settings = {}
	end
	local line = container.add({name=name, type='progressbar', size=1, value=1})
	line.style.minimal_height = settings.height or 3
	line.style.maximal_height = settings.height or 3
	line.style.minimal_width = settings.width or container.style.minimal_width
	line.style.maximal_width = settings.width or container.style.maximal_width
	line.style.color = settings.color or { r=1, g=1, b=1 }
	return line
end

-- spacer
function kw_space(container, name, settings)
	if not settings then
		settings = {}
	end
	local space = container.add({name=name, type='label', caption=''})
	space.style.minimal_height = settings.height or 10
	space.style.maximal_height = settings.height or 10
	space.style.minimal_width = settings.width or container.style.minimal_width
	space.style.maximal_width = settings.width or container.style.maximal_width
	return space
end

--
-- Frames
--

function kw_newDialog(frameName, factorioSettings, settings, instantiateFunc, renderFunc)
	if global.widgets.objects[frameName] then
		return global.widgets.objects[frameName]
	end
	
	local dialog = {
		frame_def = factorioSettings,
		position = settings.position,
		renderFunc = renderFunc,
	}
	global.widgets.objects[frameName] = dialog
	dialog.__index = dialog
	dialog.frame_def.type = 'frame'
	dialog.frame_def.name = frameName
	dialog.frame_def.caption = dialog.frame_def.caption
	dialog.frame_def.direction = dialog.frame_def.direction or 'vertical'
	dialog.frame_def.style = dialog.frame_def.style or 'frame'
	
	-- validate position
	if not(dialog.position == 'center' or dialog.position == 'left') then
		error("Invalid frame position argument: "..serpent.block(dialog.position), 2)
	end
	
	-- add some functionality.
	function dialog:flow(player)
		local flow
		if not (player and player.valid) then
			error("Player is nil", 2)
		end
		if self.position == 'center' then
			flow = player.gui.center
		elseif self.position == 'left' then
			flow = mod_gui.get_frame_flow(player)
		else
			error("Unknown frame position for '"..self.frame_def.name.."'")
		end
		return flow
	end
	function dialog:container(player)
		local flow = self:flow(player)
		return flow[self.frame_def.name]
	end
	
	function dialog:is_open(player)
		if self:flow(player)[self.frame_def.name] then
			return true
		end
		return false
	end
	function dialog:show(player)
		local flow = self:flow(player)
		if flow[self.frame_def.name] then
			return
		end
		local frame = self:flow(player).add(self.frame_def)
		if self.renderFunc then
			self.renderFunc(player, self, frame)
		else
			player.print("DEBUG: Undefined render function for ".. self.frame_def.name)
		end
	end
	function dialog:hide(player)
		if self:flow(player)[self.frame_def.name] then
			self:flow(player)[self.frame_def.name].destroy()
		end
	end
	function dialog:toggleShow(player)
		if self:flow(player)[self.frame_def.name] then
			self:hide(player)
		else
			self:show(player)
		end
	end
	
	if instantiateFunc then
		instantiateFunc(dialog)
	end
	
	return dialog
end

local function tabDialogInstantiate(dialog)
	-- called after the tab instantiation functions.
	-- Add our button callbacks for the different tabs
	for _, tabdef in pairs(dialog.tabs) do
		global.widgets.button2tab[dialog.frame_def.name .. ".tabbtn."..tabdef.name] = tabdef.name
		kw_connectButton(dialog.frame_def.name .. ".tabbtn."..tabdef.name,
			function(event)
				-- get frame
				local player = game.players[event.player_index]
				local frameName = event.element.parent.parent.parent.name
				local dialog = kw_getWidget(frameName)
				local frame = dialog:container(player)
				-- remove existing contents from tab
				if frame and frame['tabPane'] then
					for _, ele in pairs(frame['tabPane'].children) do
						ele.destroy()
					end
					-- open tab
					dialog:openTab(player, global.widgets.button2tab[event.element.name])
				end
			end
		)
	end
	
	kw_connectButton(dialog.frame_def.name .. ".close",
		function(event)
			-- get frame
			local frame = event.element.parent.parent.parent
			local dialog = kw_getWidget(frame.name)
			local player = game.players[event.player_index]
			dialog:toggleShow(player)
		end
	)
	
	-- Add close button callback.
end

local function tabDialogRender(player, dialog, frame)
	-- run the provided render function (which tells us how to do the rest)
	if dialog.subRenderFunc then
		dialog.subRenderFunc(player, dialog, frame)
	end
	-- add tabs to window
	local frame = dialog:container(player)
	if not frame then
		error("DEBUG: Unable to get frame", 2)
	end
	-- create tab button space
	local tablistScroll = frame.add({
		name = 'tablistScroll',
		type = 'scroll-pane',
		vertical_scroll_policy = 'never',
		horitzontal_scroll_policy = 'auto',
	})
	kw_applyStyle(tablistScroll, global.kw_style.tab_bar)
	local tablist = tablistScroll.add({
		name = 'tabList',
		type = 'flow',
		direction = 'horizontal',
	})
	-- create tab space (used later.)
	local tabPane = frame.add({
		type = "scroll-pane", 
		name= "tabPane", 
		vertical_scroll_policy="auto", 
		horizontal_scroll_policy="never",
	})
	kw_applyStyle(tabPane, global.kw_style.tab_container)
	
	-- add tabs to tab button space
	for _, tabdef in pairs(dialog.tabs) do
		local will_show = true
		if tabdef.settings.showif_func then
			will_show = tabdef.settings.showif_func(player.index)
		end
		if will_show then
			local sets = tabdef.settings
			local name = dialog.frame_def.name..".tabbtn."..tabdef.name
			local title = tabdef.settings.caption or tabdef.name
			local button = kw_newButton(tablist, name, title, sets.tooltip, sets.sprite, sets.style)
			kw_applyStyle(button, global.kw_style.tab_button)
		end
	end
	-- add a close button
	kw_newButton(tablist, dialog.frame_def.name..".close", {'kw.tabDialog.close_name'}, 
		{'kw.tabDialog.close_tooltip'}, nil, nil)
	-- add the tab-bar line after all the buttons.
	kw_hline(tablistScroll)
	
	-- display default tab or message
	if dialog.defaultTab and dialog.tabs[dialog.defaultTab] then
		dialog:openTab(player, dialog.defaultTab)
	else
		-- load a dummy element into the blank window.
		frame['tabPane'].add{name='no_default_tab_label', type='label', caption={"kwidgets.select_tab"}}
	end
	
end

function kw_newTabDialog(frameName, factorioSettings, settings, instantiateFunc, renderFunc)
	if global.widgets.objects[frameName] then
		return global.widgets.objects[frameName]
	end
	dialog = kw_newDialog(frameName, factorioSettings, settings, nil, tabDialogRender)
	-- note above: call instantiateFunc later so we have access to the new
	-- tab-dialog parts.
	dialog.tabs = {}
	dialog.defaultTab = settings.defaultTab or nil
	dialog.subRenderFunc = renderFunc
	
	function dialog:addTab(tabName, settings, tabInstantiateFunc, tabRenderFunc)
		self.tabs[tabName] = {
			name = tabName,
			settings = settings,
			renderFunc = tabRenderFunc,
		}
		if not self.defaultTab then
			self.defaultTab = tabName
		end
		if tabInstantiateFunc then
			tabInstantiateFunc(self, self.tabs[tabName])
		end
	end
	function dialog:openTab(player, tabName)
		if not self.tabs[tabName] then
			player.print({"kw.tabDialog.open_nonexistent", tabName})
			return
		end
		-- get variables.
		local frame = self:container(player)
		local pane = frame.tabPane
		-- set the active tab button
		if frame.tablistScroll and frame.tablistScroll.tabList then
			local list = frame.tablistScroll.tabList
			local buttonName = self.frame_def.name..".tabbtn."..tabName
			for _, button in pairs(list.children) do
				if button.name == buttonName then
					kw_applyStyle(button, global.kw_style.tab_button_selected)
				else
					kw_applyStyle(button, global.kw_style.tab_button)
				end
			end
		end
		
		-- render the active tab
		if pane then
			local tabwidget = self.tabs[tabName]
			if tabwidget.renderFunc then
				tabwidget.renderFunc(player, self, pane)
			else
				player.print("DEBUG: Tab '"..tabName.."' does not have a render function")
			end
		end
	end
	
	-- create our structures & links to buttons here
	if instantiateFunc then
		instantiateFunc(dialog)
	end
	tabDialogInstantiate(dialog)
	
	return dialog
end

--
-- misc supporting functions
--
function kw_getWidget(name)
	return global.widgets.objects[name]
end
function kw_buttonCallback(buttonName)
	local callback = global.widgets.callbacks.buttons[buttonName]
	if not callback then
		for _, butdata in pairs(global.widgets.callbacks.buttons2) do
			if string.match(buttonName, butdata.match) then
				callback = butdata.callback
				break
			end
		end
	end
	return callback
end
function kw_selectionCallback(name)
	return global.widgets.callbacks.dropdowns[name]
end

--
-- Dispatch events.
--

-- handle on-gui-click events which map to provided callbacks.
Event.register(defines.events.on_gui_click, function(event)
	if not (event and event.element and event.element.valid) then
		return
	end
	
	if event.element.type == 'button' or event.element.type == 'sprite-button' then
		local callback = kw_buttonCallback(event.element.name)
		if callback then
			callback(event)
		else
			--local player = game.players[event.player_index]
			--player.print("DEBUG: Callback for '"..event.element.name.."' is not registered.")
		end
	end
end)

Event.register(defines.events.on_gui_selection_state_changed, function(event)
	if not (event and event.element and event.element.valid) then
		return
	end
	local callback = kw_selectionCallback(event.element.name)
	if callback then
		callback(event)
	end
end)
