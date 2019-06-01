-----------------------------------------------
-- Sample of Kanji for SlibST7735.lua for W4.00.03
-- Copyright (c) 2019, AoiSaya
-- All rights reserved.
-- 2019/06/01 rev.0.03
-----------------------------------------------
function chkBreak(n)
	sleep(n or 0)
	if fa.sharedmemory("read", 0x00, 0x01, "") == "!" then
		error("Break!",2)
	end
end
fa.sharedmemory("write", 0x00, 0x01, "-")

local script_path = function()
	local  str = debug.getinfo(2, "S").source:sub(2)
	return str:match("(.*/)")
end

-- main
local myDir  = script_path()
local libDir = myDir.."lib/"
local fontDir= myDir.."font/"
local textDir= myDir.."text/"
local lcd  = require(libDir .. "SlibST7735")
local jfont= require(libDir .. "SlibJfont")
local font74 = require(fontDir .. "font74")
local f24x24 = jfont:open("jiskan24-2003-1.sef")
local f12x24 = jfont:open("12x24rk.sef")
local fw, xn

--128x128 red
local mx,my,rOfs,dOfs,gm = 128,128,2,1,0

--128x128 green
--local mx,my,rOfs,dOfs,gm = 128,128,0,0,3

lcd:init(1, 1, mx, my, rOfs, dOfs, gm)
lcd:dspOn()

lcd:cls()
lcd:setFont(jfont)
jfont:setFont(f12x24,f24x24)
--lcd:color(0xFFFF,0x0000)
lcd:locate(2,24,1,1,4);
lcd:println(jfont:utf82euc(" 令和元年"))
lcd:println(jfont:utf82euc("水無月朔日"))
lcd:println(jfont:utf82euc(" (土曜日)"))

jfont:close()

return
