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

	Color conversion functionality.

Based on https://github.com/hvalidi/ColorMine.

RGB.* functions are based on RGB values in the 0..255 range.
RGB01.* functions are based on RGB values in the 0..1 range.

--]]

RGB = {}
RGB01 = {}
XYZ = {}
LAB = {}
LCH = {}

--
-- LAB to __ Conversion functions
--

function LAB.pivot2xyz(value)
	local vp = math.pow(value, 3)
	if vp > 0.008856 then
		return vp
	end
	return (116 * value - 16) / 903.3
end

function LAB.toLCH(color)
	local h = math.atan2(color.B, color.A)
	-- convert from rad to deg
	if h > 0 then
		h = (h/math.pi) * 180
	else
		h = 360 - (math.abs(h) / math.pi) * 180
	end
	return {
		L = color.L,
		C = math.sqrt(math.pow(color.A, 2) + math.pow(color.B, 2)),
		H = h % 360,
	}
end

function LAB.toRGB(color)
	return RGB01.toRGB(LAB.toRGB01(color))
end

function LAB.toRGB01(color)
	return XYZ.toRGB01(LAB.toXYZ(color))
end

function LAB.toXYZ(color)
	local y = (color.L + 16) / 116.0
	local x = color.A / 500.0 + y
	local z = y - color.B / 200.0
	
	x = LAB.pivot2xyz(x)
	y = LAB.pivot2xyz(y)
	z = LAB.pivot2xyz(z)
	
	return {
		X = x * XYZ.refX,
		Y = y * XYZ.refY,
		Z = z * XYZ.refZ,
	}
end

--
-- LCH to __ Conversion functions
--

function LCH.toLAB(color)
	local rads = (math.pi * color.H) / 180.0
	return {
		L = color.L,
		A = math.cos(rads) * color.C,
		B = math.sin(rads) * color.C,
	}
end

function LCH.toRGB(color)
	return RGB01.toRGB(LCH.toRGB01(color))
end

function LCH.toRGB01(color)
	return XYZ.toRGB01(LCH.toXYZ(color))
end

function LCH.toXYZ(color)
	return LAB.toXYZ(LCH.toLAB(color))
end

--
-- RGB to __ Conversion functions (0..255 value range)
--

function RGB.intValue(color)
	return {
		r = math.floor(color.r + 0.5),
		g = math.floor(color.g + 0.5),
		b = math.floor(color.b + 0.5),
	}
end

function RGB.toLAB(color)
	return RGB01.toLAB(RGB.toRGB01(color))
end

function RGB.toLCH(color)
	return RGB01.toLCH(RGB.toRGB01(color))
end

function RGB.toRGB01(color)
	return {
		r = color.r / 255,
		g = color.g / 255,
		b = color.b / 255,
	}
end

function RGB.toXYZ(color)
	return RGB01.toXYZ(RGB.toRGB01(color))
end

--
-- RGB01 to __ Conversion functions (0..1 value range)
--

function RGB01.brighten(color, multiplier, min_start)
	-- brighten the color provided.
	local lab = RGB01.toLAB(color)
	if min_start then
		lab.L = math.max(min_start, lab.L)
	end
	lab.L = math.min(100, lab.L * multiplier)
	return LAB.toRGB01(lab)
end

function RGB01.pivot2xyz(value)
	local chan = value
	if value > 0.04045 then
		chan = math.pow( (value + 0.055) / 1.055, 2.4)
	else
		chan = value / 12.92
	end
	return chan * 100.0
end

function RGB01.toLAB(color)
	return XYZ.toLAB(RGB01.toXYZ(color))
end

function RGB01.toLCH(color)
	return LAB.toLCH(RGB01.toLAB(color))
end

function RGB01.toRGB(color)
	return {
		r = color.r * 255,
		g = color.g * 255,
		b = color.b * 255,
	}
end

function RGB01.toXYZ(color)
	-- Factorio colors start as 0..1 range values.
	local r = RGB01.pivot2xyz(color.r);
	local g = RGB01.pivot2xyz(color.g);
	local b = RGB01.pivot2xyz(color.b);
	return {
		X = r * 0.4124 + g * 0.3576 + b * 0.1805,
		Y = r * 0.2126 + g * 0.7152 + b * 0.0722,
		Z = r * 0.0193 + g * 0.1192 + b * 0.9505,
	}
end

--
-- XYZ to __ Conversion functions
--

XYZ.refX =  95.047
XYZ.refY = 100.000
XYZ.refZ = 108.883

function XYZ.pivot2lab(value, ref)
	local chan = value / ref
	if chan > 0.008856 then
		chan = math.pow(chan, 1.0/3.0)
	else
		chan = (903.3 * chan + 16) / 116.0
	end
	return chan
end

function XYZ.pivot2rgb(value)
	if value > 0.0031308 then
		return 1.055 * math.pow(value, 1/2.4) - 0.055
	end
	return 12.92 * value
end

function XYZ.toLAB(color)
	local x = XYZ.pivot2lab(color.X,  95.047)
	local y = XYZ.pivot2lab(color.Y, 100.000)
	local z = XYZ.pivot2lab(color.Z, 108.883)
	return {
		L = 116 * y - 16,
		A = 500 * (x - y),
		B = 200 * (y - z),
	}
end

function XYZ.toLCH(color)
	return LAB.toLCH(XYZ.toLAB(color))
end

function XYZ.toRGB(color)
	return RGB01.toRGB(XYZ.toRGB01(color))
end

function XYZ.toRGB01(color)
	local x = color.X / 100
	local y = color.Y / 100
	local z = color.Z / 100
	
	local r = x *  3.2406 + y * -1.5372 + z * -0.4986
	local g = x * -0.9689 + y *  1.8758 + z *  0.0415
	local b = x *  0.0557 + y * -0.2040 + z *  1.0570
	
	return {
		r = math.min(1, XYZ.pivot2rgb(r)),
		g = math.min(1, XYZ.pivot2rgb(g)),
		b = math.min(1, XYZ.pivot2rgb(b)),
	}
end

--
-- Testing functionality
--
CConv = {}

function CConv.table_equals(o1, o2, ignore_mt)
    if o1 == o2 then return true end
    local o1Type = type(o1)
    local o2Type = type(o2)
    if o1Type ~= o2Type then return false end
    if o1Type ~= 'table' then return false end

    if not ignore_mt then
        local mt1 = getmetatable(o1)
        if mt1 and mt1.__eq then
            --compare using built in method
            return o1 == o2
        end
    end

    local keySet = {}

    for key1, value1 in pairs(o1) do
        local value2 = o2[key1]
        if value2 == nil or CConv.table_equals(value1, value2, ignore_mt) == false then
            return false
        end
        keySet[key1] = true
    end

    for key2, _ in pairs(o2) do
        if not keySet[key2] then return false end
    end
    return true
end

function CConv.compare(func, srcval, dstval, funcname, accuracy)
	if not accuracy then
		accuracy = 10
	end
	local compval = table.deepcopy(dstval)
	local multiplier = math.pow(10, accuracy)
	local calcval = func(srcval)
	if CConv.debug then
		game.print("Evaluate "..funcname.."("..serpent.block(srcval)..") = "..serpent.block(calcval))
	end
	for key, value in pairs(calcval) do
		local temp = math.floor(value * multiplier) / multiplier
		calcval[key] = temp
	end
	for key, value in pairs(compval) do
		local temp = math.floor(value * multiplier) / multiplier
		compval[key] = temp
	end
	if not CConv.table_equals(calcval, compval) then
		game.print("FAILED "..funcname.."("..serpent.block(srcval)..")")
		game.print("\tExpected: "..serpent.block(compval))
		game.print("\tGot: "..serpent.block(calcval))
	end
end

function CConv.test()
	CConv.debug = false
	-- run a quick test suite for known values.
	tests = {
		{
			rgb = {r = 100, g = 150, b = 200},
			xyz = {X = 26.587203242060426, Y = 28.692148568242207, Z = 58.78042436979214},
			lab = {L = 60.508968394256485, A = -2.779785985673966, B = -30.937902681993833},
			lch = {L = 60.508968394256485, C = 31.0625342251187, H = 264.865732521772},
		},
		{
			rgb = {r = 0, g = 0, b = 0},
			xyz = {X = 0, Y = 0, Z = 0},
			lab = {L = 0, A = 0, B = 0},
			lch = {L = 0, C = 0, H = 0},
		},
		{
			rgb = {r = 255, g = 255, b = 255},
			xyz = {X = 95.05, Y = 100, Z = 108.89999999999999},
			lab = {L = 100, A = 0.00526049995830391, B = -0.010408184525267927},
			lch = {L = 100, C = 0.011662039483869973, H = 296.81292623674057},
		},
		{
			rgb = {r = 68, g = 2, b = 243},
			xyz = {X = 18.583266019348535, Y = 7.743424676951119, Z = 85.30920260178058},
			lab = {L = 33.44271931347735, A = 77.08514659305595, B = -99.1317188177598},
			lch = {L = 33.44271931347735, C = 125.5755449959757, H = 307.8687524890283},
		},
		{
			rgb = {r = 222, g = 128, b = 33},
			xyz = {X = 38.117886090732796, Y = 31.077743776600425, Z = 5.428415685629915},
			lab = {L = 62.57320767450899, A = 30.045301860465667, B = 61.86146849351842},
			lch = {L = 62.57320767450899, C = 68.77180707281927, H = 64.09476383437209},
		},
	}
	for _, set in ipairs(tests) do
		-- LAB testing
		CConv.compare(LAB.toLCH, set.lab, set.lch, "LAB.toLCH")
		CConv.compare(LAB.toRGB, set.lab, set.rgb, "LAB.toRGB")
		CConv.compare(LAB.toXYZ, set.lab, set.xyz, "LAB.toXYZ")
		
		-- LCH testing
		CConv.compare(LCH.toLAB, set.lch, set.lab, "LCH.toLAB")
		CConv.compare(LCH.toRGB, set.lch, set.rgb, "LCH.toRGB")
		CConv.compare(LCH.toXYZ, set.lch, set.xyz, "LCH.toXYZ")
		
		-- RGB testing
		CConv.compare(RGB.toLAB, set.rgb, set.lab, "RGB.toLAB")
		CConv.compare(RGB.toLCH, set.rgb, set.lch, "RGB.toLCH")
		CConv.compare(RGB.toXYZ, set.rgb, set.xyz, "RGB.toXYZ")
		
		-- XYZ testing
		CConv.compare(XYZ.toLAB, set.xyz, set.lab, "XYZ.toLAB")
		CConv.compare(XYZ.toLCH, set.xyz, set.lch, "XYZ.toLCH")
		CConv.compare(XYZ.toRGB, set.xyz, set.rgb, "XYZ.toRGB")
	end
	game.print("ColorConversion testing finished.  If no messages were printed, all comparisons succeeded.")
end
