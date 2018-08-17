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

	global.kw_style.lua - Style options for kwidgets.
	
	These are styles that can be applied to a widget post-creation.
	Since we can't hook into data:extend as a softmod, and since some
	settings are only available post-creation, we can do it here to gain
	some major consistency.
	
--]]

require 'lib/event_extend'

function kw_applyStyle(object, style)
	if style then
		for name, value in pairs(style) do
			object.style[name] = value
		end
	end
end

Event.register(Event.def("softmod_init"), function(event)
	global.kw_style = {
	btn_height_dropdown = {
		minimal_height = 38,
		maximal_height = 38,
	},
	sort_dropdown = {
		minimal_height = 27,
		maximal_height = 27,
	},
	tab_button = {
		font_color = { r=1, g=1, b=1 },
		hovered_font_color = { r=0, g=0, b=0 },
	},
	tab_button_selected = {
		font_color = { r=0.98, g=0.66, b=0.22 }, -- orange
		hovered_font_color = { r=0.02, g=0.34, b=0.78 },  -- inverse
		--hovered_font_color = { r=0.22, g=0.53, b=0.97 },  -- complement
	},
	tab_container = {
		minimal_height = 300,
		maximal_height = 300,
		minimal_width = 550,
		maximal_width = 550,
	},
	tab_bar = {
		minimal_height = 60,
		maximal_height = 60,
		minimal_width = 550,
		maximal_width = 550,
	},
	toolbar_button = {
	},
	toolbar_spacer = {
		minimal_width = 5,
		maximal_width = 5,
	},
	toolbar_style = {
		horizontal_spacing = 5,
	},
}
end)