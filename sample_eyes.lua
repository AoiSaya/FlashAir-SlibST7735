-----------------------------------------------
-- Sample eyes of SlibST7735.lua for W4.00.03
-- Copyright (c) 2018, Saya
-- All rights reserved.
-- 2018/11/08 rev.0.01
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

local to64K = function(dat)
	local bx = bit32.extract
	local r = bx(dat,19,5)
	local g = bx(dat,10,6)
	local b = bx(dat, 3,5)
	return b*2048 + g*32 + r
end


-- main
local myDir  = script_path()
local libDir = myDir.."lib/"
local imgDir = myDir.."img/"
local fontDir= myDir.."font/"
local lcd  = require(libDir .. "SlibST7735")
local bmp = require(libDir .. "SlibBMP")
local font74 = require(fontDir .. "font74")
local x1,y1,x2,y2,c

local COL_K = to64K(0x000000) -- kuro
local COL_B = to64K(0x0000FF) -- blue
local COL_R = to64K(0xFF0000) -- red
local COL_M = to64K(0xFF00FF) -- magenta
local COL_G = to64K(0x00FF00) -- green
local COL_C = to64K(0x00FFFF) -- cyan
local COL_Y = to64K(0xFFFF00) -- yellow
local COL_W = to64K(0xFFFFFF) -- white

--128x128 red
local mx,my,rOfs,dOfs,gm = 128,128,2,1,0

lcd:init(23, 1, mx, my, rOfs, dOfs, gm)
lcd:dspOn()

---[[
-- eyes
x1a,y1a,x2a,y2a = 0,0,0,0
local function boxMove(x,y,xs,ys,fgcol,bgcol)
	x1,y1,x2,y2 = x,y,x+xs-1,y+ys-1
	if x1>x2 then x1,x2=x2,x1 end
	if y1>y2 then y1,y2=y2,y1 end
	if x2a<x1 or x1a>x2 or y2a<y1 or y1a>y2 then
		lcd:boxFill(x1a,y1a,x2a,y2a,bgcol)
		lcd:boxFill(x1, y1, x2 ,y2, fgcol)
	elseif x1a>=x1 and y1a>=y1 and x2a<=x2 and y2a<=y2 then
		lcd:boxFill(x1, y1, x2 ,y2, fgcol)
	else
		xa = x1
		xb = x2
		if x1a<x1 then
			lcd:boxFill(x1a,y1a,x1-1,y2a,bgcol)
		elseif x1a>x1 then
			xa = x1a
			lcd:boxFill(x1,y1,x1a-1,y2,fgcol)
		end
		if x2a>x2 then
			lcd:boxFill(x2+1,y1a,x2a,y2a,bgcol)
		elseif x2a<x2 then
			xb = x2a
			lcd:boxFill(x2a+1,y1,x2,y2,fgcol)
		end
		if y1a<y1 then
			lcd:boxFill(xa,y1a,xb,y1-1,bgcol)
		elseif y1a>y1 then
			lcd:boxFill(xa,y1,xb,y1a-1,fgcol)
		end
		if y2a>y2 then
			lcd:boxFill(xa,y2+1,xb,y2a,bgcol)
		elseif y2a<y2 then
			lcd:boxFill(xa,y2a+1,xb,y2,fgcol)
		end
	end
	x1a,y1a,x2a,y2a = x1,y1,x2,y2
end

lcd:writeStart(2)
lcd:flip(1,1)
lcd:writeStart(3)
lcd:boxFill(0,0,mx-1,my-1,COL_W)

while 1 do
	xs,ys = 30,-64
	x, y  = 64-xs/2, 64-ys/2
	fgcol = COL_K
	bgcol = COL_W
--open eyes
	boxMove(x,y,xs,-4,fgcol,bgcol)
	sleep(3000)

	for i=-4,ys,-1 do
		boxMove(x,y,xs,i,fgcol,bgcol)
		sleep(20)
		chkBreak()
	end
	sleep(1000)

--to right
	for i=x,x+30,1 do
		boxMove(i,y,xs,ys,fgcol,bgcol)
		chkBreak()
	end
	sleep(300)

--to left
	for i=x+30,x-30,-1 do
		boxMove(i,y,xs,ys,fgcol,bgcol)
		chkBreak()
	end

--to center
	for i=x-30,x,10 do
		boxMove(i,y,xs,ys,fgcol,bgcol)
		chkBreak()
	end

--blink
	for j=1,2 do
		for i=ys,-4,20 do
			boxMove(x,y,xs,i,fgcol,bgcol)
			chkBreak()
		end
		for i=-4,ys,-20 do
			boxMove(x,y,xs,i,fgcol,bgcol)
			chkBreak()
		end
	end
	sleep(2000)

--wink
	lcd:writeStart(1)
	for i=ys,-4,20 do
		boxMove(x,y,xs,i,fgcol,bgcol)
		chkBreak()
	end
	sleep(1000)
	for i=-4,ys,-20 do
		boxMove(x,y,xs,i,fgcol,bgcol)
		chkBreak()
	end
	sleep(2000)
	lcd:writeStart(3)
--]]

end
