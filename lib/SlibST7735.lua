-----------------------------------------------
-- SoraMame library of ST7735@65K for W4.00.03
-- Copyright (c) 2018, Saya
-- All rights reserved.
-- 2018/10/17 rev.0.03 setRamMode debug
-----------------------------------------------
--[[
Pin assign
	PI	 SPI	init	TYPE1	TYPE2
CMD	0x01 DO 	L		SDA 	SDA
D0	0x02 CLK	L		SCK 	SCK
D1	0x04 CS 	H		A0		A0
D2	0x08 DI 	I		CS		CS
D3	0x10 RSV	L		RESET 	Hi-Z
--]]

local ST7735 = {
id	  = 0;
gs	  = 0;
swp   = false;
xMax  = 176-1;
yMax  = 220-1;
hSize = 176;
vSize = 220;
hDrc  = 1;
vDrc  = 1;
hOfs  = 0;
vOfs  = 0;
rOfs  = 0;
ctrl  = 0x1F;
x	  = 0;
y	  = 0;
x0	  = 0;
fc	  = "\255\255";
bc	  = "\000\000";
font  = {};
mag   = 1;
enable= false;
}

--[Low layer functions]--

function ST7735:writeString(cmd,str,...)
	local spi = fa.spi
	spi("cs",0)
	spi("write",cmd)
	spi("cs",1)
	spi("write",str,...)
end

function ST7735:writeByte(cmd,...)
	local spi = fa.spi
	spi("cs",0)
	spi("write",cmd)
	spi("cs",1)
	spi("write",...)
end

function ST7735:writeWord(cmd,...)
	local spi = fa.spi
	spi("cs",0)
	spi("write",cmd)
	spi("cs",1)
	spi("bit",16)
	spi("write",...)
	spi("bit",8)
end

function ILI9163C:writeCmd(cmd)
	local spi = fa.spi
	spi("cs",0)
	spi("write", cmd)
	spi("cs",1)
end

--[[
function ILI9163C:readData(cmd, bit)
	local i, s, dt, ret
	local pio = fa.pio
	local ctrl= self.ctrl
	local bx  = bit32.extract
	local bb  = bit32.band

	for i=7,0,-1 do
		dt = bx(cmd,i,1)
		pio(ctrl,0x10+dt) -- CS=0,RS=0,CLK=0
		pio(ctrl,0x12+dt) -- CS=0,RS=0,CLK=1
	end
	ctrl = ctrl-0x01
	ret = 0
	for i=1,bit do
		pio(ctrl,0x14) -- CS=0,RS=1,CLK=0,
		s,dt = pio(ctrl,0x16) -- CS=0,RS=1,CLK=1
		ret = ret*2+bb(dt,0x01)
	end

	return ret
end
--]]

function ST7735:writeRam(h,v,str,...)
	self:writeWord(0x2A,h)
	self:writeWord(0x2B,v)
	self:writeString(0x2C,str,...)
end

function ST7735:writeRamCmd(h1,v1,h2,v2)
	local spi = fa.spi
	self:writeWord(0x2A,h1,h2)
	self:writeWord(0x2B,v1,v2)
	self:writeCmd(0x2C)
end

function ST7735:writeRamData(str,...)
	fa.spi("write",str,...)
end

function ST7735:setRamMode(BGR,MDT,DRC)
	-- BGR 0:BGR order,1:RGB order
	-- MDT 0:16bit,3:24bit
	-- DRC 0:incliment to up,1:incliment to right
	-- set GRAM writeWord direction and [12]BGR,[9:8]MDT,[5:4]ID=3,[3]AM
	local val = 0x0000
			+ BGR * 0x1000
			+ MDT * 0x100
			+ self.id * 0x10
			+ bit32.bxor(DRC,(self.swp and 1 or 0)) * 0x8
	self:writeWord(0x03,val)
end

function ILI9163C:setRamMode(BGR,IFPF,MYXV)
	-- BGR 0:BGR order, 1:RGB order
	-- IFPF 3:12bit 5:16bit, 6:18bit
	-- MYXV 2:
	-- set GRAM writeWord direction and [7:5]MYXV,[3]BGR,
	local val = MYXV * 0x20
			  + BGR  * 0x8
	self:writeByte(0x36, val)
	-- Interface Pixel Format [2:0]IFPF
	local val = IFPF
	self:writeByte(0x3A, val)
end

function ST7735:setWindow(h1,v1,h2,v2)
	if h1>h2 then h1,h2=h2,h1 end
	if v1>v2 then v1,v2=v2,v1 end
	self:writeRamCmd(h1,v1,h2,v2)
end

function ST7735:resetWindow()
	self:writeRamCmd(0,self.rOfs,self.hSize-1,self.rOfs+self.vSize-1)
end

function ST7735:pTrans(x,y)
	if self.swp then x,y = y,x end
	return self.hDrc*x+self.hOfs, self.vDrc*y+self.vOfs
end

function ST7735:bTrans(x1,y1,x2,y2)
	local hD,vD,hO,vO = self.hDrc, self.vDrc, self.hOfs, self.vOfs
	if self.swp then x1,y1,x2,y2 = y1,x1,y2,x2 end
	return hD*x1+hO, vD*y1+vO, hD*x2+hO, vD*y2+vO
end

function ST7735:clip(x1,y1,x2,y2)
	local xMax = self.xMax
	local yMax = self.yMax
	local a1,ret
	local xd,yd,x0,y0,xm,ym

	xd = x2-x1
	yd = y2-y1
	a1 = y1*x2-y2*x1
	y0 = (xd==0) and y1 or a1/xd
	ym = (xd==0) and y2 or xMax*yd/xd+y0
	x0 = (yd==0) and x1 or -a1/yd
	xm = (yd==0) and x2 or yMax*xd/yd+x0

	if x1>x2 then x1,y1,x2,y2=x2,y2,x1,y1 end
	if x1<0 then x1,y1=0,y0 end
	if x2>xMax then x2,y2=xMax,ym end

	if y1>y2 then x1,y1,x2,y2=x2,y2,x1,y1 end
	if y1<0 then x1,y1=x0,0 end
	if y2>yMax then x2,y2=xm,yMax end

	ret = x1<0 or y1<0 or x2>xMax or y2>yMax or x2<0 or y2<0 or x1>xMax or y1>yMax

	return ret,x1,y1,x2,y2
end

function ILI9163C:setup()
	self:writeStart()
	self:writeCmd(0x11) --exit sleep
	sleep(5)
	self:writeByte(0x26, 0x04) --default gamma curve 3
	self:writeByte(0xF2, 0x01) --Enable Gamma adj
	self:writeCmd(0x13)
	self:writeByte(0xB6, {0xFF,0x06})
	self:writeByte(0xE0, --Positive Gamma Correction Setting
	{0x36, --p1
	 0x29, --p2
	 0x12, --p3
	 0x22, --p4
	 0x1C, --p5
	 0x15, --p6
	 0x42, --p7
	 0xB7, --p8
	 0x2F, --p9
	 0x13, --p10
	 0x12, --p11
	 0x0A, --p12
	 0x11, --p13
	 0x0B, --p14
	 0x06}) --p15
	self:writeByte(0xE1, --Negative Gamma Correction Setting
		{0x09, --p1
		 0x16, --p2
		 0x2D, --p3
		 0x0D, --p4
		 0x13, --p5
		 0x15, --p6
		 0x40, --p7
		 0x48, --p8
		 0x53, --p9
		 0x0C, --p10
		 0x1D, --p11
		 0x25, --p12
		 0x2E, --p13
		 0x34, --p14
		 0x39}) --p15

	self:writeByte(0xB1,	--Frame Rate Control (In normal mode/Full colors)
		{0x08,	--0x0C//0x08
		 0x02}) --0x14//0x08
	self:writeByte(0xB4, 0x07) --display inversion
	self:writeByte(0xC0, --Set VRH1[4:0] & VC[2:0] for VCI1 & GVDD
		{0x0A, --4.30 - 0x0A
		 0x02}) --0x05
	self:writeByte(0xC1, 0x02) --Set BT[2:0] for AVDD & VCL & VGH & VGL
	self:writeByte(0xC5, --Set VMH[6:0] & VML[6:0] for VOMH & VCOML
		{0x50, --0x50
		 99}) --0x5b
	self:writeByte(0xC7, 0) --0x40
	self:setRamMode(0, 5, 2)
	self:resetWindow()
	self:writeEnd()
end

--[For user functions]--

-- type: 1:D3=RST=H/L, 2:D3=Hi-Z(no hard reset)
-- rotate: 0:upper pin1, 1:upper pin5, 2:lower pin1, 3:lower pin11

function ST7735:init(type,rotate,xSize,ySize,offset)
	local id,gs,swp,hDrc,vDrc
	if type==1 then self.ctrl=0x1F end
	if type==2 then self.ctrl=0x0F end
	if rotate==0 then id,gs,swp,hDrc,vDrc = 0,0,false,-1, 1 end
	if rotate==1 then id,gs,swp,hDrc,vDrc = 0,1,true,  1,-1 end
	if rotate==2 then id,gs,swp,hDrc,vDrc = 3,0,false, 1,-1 end
	if rotate==3 then id,gs,swp,hDrc,vDrc = 3,1,true, -1, 1 end

	self.id	 = id
	self.gs	 = gs
	self.swp = swp
	if swp then
		self.hSize = ySize
		self.vSize = xSize
	else
		self.hSize = xSize
		self.vSize = ySize
	end
	self.hDrc = hDrc
	self.vDrc = vDrc
	self.hOfs = (hDrc>0) and 0 or self.hSize-1
	self.vOfs = (vDrc>0) and offset or self.vSize+offset-1
	self.mRot = mRot
	self.xMax = xSize-1
	self.yMax = ySize-1
	self.rOfs = offset;

-- reset sequence
	fa.pio(self.ctrl,0x10) -- RST=1,CS=0,RS=0
	sleep(1)
	fa.pio(self.ctrl,0x00) -- RST=0,CS=0,RS=0
	sleep(10)
	fa.pio(self.ctrl,0x18) -- RST=1,CS=1,RS=0
	self:writeWord(0x28,0xCE) -- Software reset
	sleep(120)
	self:setup()
end

function ST7735:writeStart()
	if not self.enable then
		fa.spi("mode",0)
		fa.spi("init",1)
		fa.spi("bit",8)
		fa.pio(self.ctrl,0x18) -- CS=1,RS=0
		self.enable = true
	end
end

function ST7735:writeEnd()
	if self.enable then
		self:writeCmd(0x00)
		fa.pio(self.ctrl,0x1C) -- CS=1,RS=1
		self.enable = falce
	end
end

function ST7735:cls()
	self:resetWindow()
	self:writeRam(0,self.hSize*self.rOfs*2,"",self.hSize*self.vSize*2)
	collectgarbage()
end

function ST7735:dspOn()
	self:writeCmd(0x29)
end

function ST7735:dspOff()
	self:writeCmd(0x28)
end

function ST7735:pset(x,y,color)
	if (x<0 or x>self.xMax) then return end
	if (y<0 or y>self.yMax) then return end
	local h,v = self:pTrans(x,y)
	self:writeWord(0x2A,h)
	self:writeWord(0x2B,v)
	self:writeWord(0x2C,color)
end

function ST7735:line(x1,y1,x2,y2,color)
	local swap
	local h1,h2,hn,ha,hb,hd,hv,hr,hs,h
	local v1,v2,vn,vd,v
	local xMax = self.xMax
	local yMax = self.yMax
	local bx = bit32.extract
	local mf = math.floor
	local col = string.char(bx(color,8,8),bx(color,0,8))
	local dat, ret

	if	x1<0 or y1<0 or x2>xMax or y2>yMax or x2<0 or y2<0 or x1>xMax or y1>yMax then
		if self.clip then ret,x1,y1,x2,y2 = self:clip(x1,y1,x2,y2) else ret = true end
		if ret then return end
	end

	x1 = mf(x1+0.5)
	x2 = mf(x2+0.5)
	y1 = mf(y1+0.5)
	y2 = mf(y2+0.5)
	h1,v1,h2,v2 = self:bTrans(x1,y1,x2,y2)
	hn = math.abs(h2-h1)+1
	vn = math.abs(v2-v1)+1
	if hn>vn then
		swap = false
		if self.swp then self:setRamMode(0,0,1) end
		dat = string.rep(col,self.hSize)
	else
		swap = true
		if not self.swp then self:setRamMode(0,0,1) end
		dat = string.rep(col,self.vSize)
		h1,v1,h2,v2 = v1,h1,v2,h2
		hn,vn = vn,hn
	end
	hd = (self.id==0) and -1 or 1
	if h1*hd>h2*hd then h1,v1,h2,v2 = h2,v2,h1,v1 end
	vd = (v1<v2) and 1 or -1
	hv = hd*vd*hn/vn
	ha = h1
	hr = h1+0.5
	hs = hd*2
	for i=v1,v2,vd do
		hb = mf((i-v1+vd)*hv+hr)
		h = swap and i or ha
		v = swap and ha or i
		self:writeRam(h,v,dat,(hb-ha)*hs)
		ha = hb
	end
	self:setRamMode(0,0,0)
	dat = nil
	collectgarbage()
end

function ST7735:box(x1,y1,x2,y2,color)
	self:line(x1,y1,x2,y1,color)
	self:line(x2,y1,x2,y2,color)
	self:line(x2,y2,x1,y2,color)
	self:line(x1,y2,x1,y1,color)
end

function ST7735:boxFill(x1,y1,x2,y2,color)
	local xMax = self.xMax
	local yMax = self.yMax
	local bx = bit32.extract
	local mf = math.floor
	local len,dat,col,vd,hd

	if x1>x2 then x1,x2 = x2,x1 end
	if y1>y2 then y1,y2 = y2,y1 end
	if x2<0 or y2<0 or x1>xMax or y1>yMax then return end
	if x1<0 then x1=0 end
	if y1<0 then y1=0 end
	if x2>xMax then x2=xMax end
	if y2>yMax then y2=yMax end

	col = string.char(bx(color,8,8),bx(color,0,8))

	x1 = mf(x1+0.5)
	x2 = mf(x2+0.5)
	y1 = mf(y1+0.5)
	y2 = mf(y2+0.5)
	h1,v1,h2,v2 = self:bTrans(x1,y1,x2,y2)
	hn = math.abs(h2-h1)+1
	vn = math.abs(v2-v1)+1
	if hn>vn then
		if self.swp then self:setRamMode(0,0,1);h1=h2 end
		dat = string.rep(col,hn)
		vd = (v1>v2) and -1 or 1
		for i=v1,v2,vd do
			self:writeRam(h1,i,dat)
		end
	else
		if not self.swp then self:setRamMode(0,0,1);v1=v2 end
		dat = string.rep(col,vn)
		hd = (h1>h2) and -1 or 1
		for i=h1,h2,hd do
			self:writeRam(i,v1,dat)
		end
	end

	self:setRamMode(0,0,0)
	dat = nil
	collectgarbage()
end

function ST7735:circle(x,y,xr,yr,color)
	local c
	local x1,y1,x2,y2
	local sin = math.sin
	local cos = math.cos
	local pi  = math.pi

	x1 = x + xr
	y1 = y
	for i=1,64 do
		c = 2*pi*i/64
		x2 = x + xr*cos(c)
		y2 = y + yr*sin(c)
		self:line(x1,y1,x2,y2,color)
		x1 = x2
		y1 = y2
	end
	collectgarbage()
end

function ST7735:circleFill(x,y,xr,yr,color)
	local h1,v1,h2,v2
	local x1,x2,y1,y2,xs,r2,xn
	local xMax = self.xMax
	local yMax = self.yMax
	local bx  = bit32.extract
	local mf  = math.floor
	local sqrt= math.sqrt
	local col = string.char(bx(color,8,8),bx(color,0,8))
	local dat = string.rep(col,(xMax+1))

	x = mf(x+0.5)
	y = mf(y+0.5)
	r2 = yr*yr

	if y>=0 and y<=yMax then
		xs = mf(xr)
		x1 = x-xs
		x2 = x+xs
		if x1<0 then x1=0 end
		if x2>xMax then x2=xMax end
		xn= (x2-x1+1)*2
		h1,v1 = self:pTrans(x1,y)
		self:writeRam(h1,v1,dat,xn)
	end

	for i=1,yr do
		xs = mf(sqrt(r2-i*i)*xr/yr)
		x1 = x-xs
		x2 = x+xs
		y1 = y-i
		y2 = y+i
		if x1<0 then x1=0 end
		if x2>xMax then x2=xMax end
		xn= (x2-x1+1)*2
		h1,v1,h2,v2 = self:bTrans(x1,y1,x2,y2)
		if y1>=0 then self:writeRam(h1,v1,dat,xn) end
		if self.swp then v2=v1 else h2=h1 end
		if y2<=yMax then self:writeRam(h2,v2,dat,xn) end
	end

	dat = nil
	collectgarbage()
end

function ST7735:put(x,y,bitmap)
	local bx,by= 0,0
	local xMax = self.xMax
	local yMax = self.yMax
	local bw   = bitmap.width
	local bh   = bitmap.height
	local bb   = bitmap.bit/8
	local flat = bitmap.flat
	local br   = bw*bb
	local bi,bn
	local h1,v2,hs,vs

	if( x>xMax or y>yMax or x+bw<0 or y+bh<0 ) then return end
	if( x<0 ) then x,bw,bx=0,bw+x,-x end
	if( y<0 ) then y,bh=0,bh+y end
	if( x+bw>xMax+1 ) then bw=xMax+1-x end
	if( y+bh>yMax+1 ) then bh,by=yMax+1-y,y+bh-yMax-1 end
	h1,v2 = self:pTrans(x,y+bh-1)
	hs = (self.id==0) and 1 or -1
	vs = hs
	if self.swp then vs=0 else hs=0 end

	if bb==3 then
		self:setRamMode(0,3,0)
	end
	if bx==0 then
		if( flat==0 )then
			bn = bw*bb
			for i=0,bh-1 do
				self:writeRam(h1-i*hs,v2-i*vs,bitmap.data[by+i+1],bn)
			end
		else
			for i=0,bh-1 do
				bs = (by+i)*br+1
				bn = bs+bw*bb-1
				self:writeRam(h1-i*hs,v2-i*vs,bitmap.data:sub(bs,bn))
			end
		end
	else
		bs = bx*bb+1
		bn = (bx+bw)*bb
		if( flat==0 )then
			for i=0,bh-1 do
				self:writeRam(h1-i*hs,v2-i*vs,bitmap.data[by+i+1]:sub(bs,bn))
				collectgarbage()
			end
		else
			bs = bs+by*br
			bn = bn+by*br
			for i=0,bh-1 do
				self:writeRam(h1-i*hs,v2-i*vs,bitmap.data:sub(bs,bn))
				bs = bs+br
				bn = bn+br
				collectgarbage()
			end
		end
	end
	self:setRamMode(0,0,0)
	collectgarbage()
end

function ST7735:put2(x,y,bitmap)
	local x2 = x+bitmap.width-1
	local y2 = y+bitmap.height-1
	local h1,v1,h2,v2 = self:bTrans(x,y,x2,y2)
	self:setWindow(h1,v1,h2,v2)
	self:writeRam(h1,v2,bitmap.data)
	self:resetWindow()
	collectgarbage()
end

function ST7735:locate(x,y,mag,color,bgcolor,font)
	local bx = bit32.extract
	local mf = math.floor

	if x then
		self.x	= mf(x+0.5)
		self.x0 = self.x
	end
	if y then
		self.y	= mf(y+0.5)
	end
	if mag then
		self.mag= mf(mag)
	end
	if color then
		self.fc = string.char(bx(color,8,8),bx(color,0,8))
	end
	if bgcolor then
		self.bc = string.char(bx(bgcolor,8,8),bx(bgcolor,0,8))
	end
	if font then
		self.font = font
	end
end

function ST7735:print(str)
	local n,c,b,bk,bj,il,is,sn,slen,sp
	local h1,v1,h2,v2
	local s = ""
	local p = {}
	local fw = self.font.width
	local fh = self.font.height
	local mg = self.mag
	local bx = bit32.extract
	local mf = math.floor
	local s0 = string.rep(self.bc,mg)
	local s1 = string.rep(self.fc,mg)
	local ti = table.insert

	self:setRamMode(0,0,1)

	is = 1
	slen = #str
	while slen>0 do
		sn = mf((self.xMax+1-self.x)/mg/fw)
		il = sn<slen and sn or slen
		slen = slen - il
		h1,v1,h2,v2 = self:bTrans(self.x,self.y,self.xMax,self.y+mg*fh-1)
		self:setWindow(h1,v1,h2,v2)
		if self.id==0 then self:writeRamCmd(h1,v2) else	self:writeRamCmd(h2,v1) end

		bk=1
		for i=is,is+il-1 do
			c = str.sub(str,i,i)
			b = self.font[c]
			for j=1,fw do
				bj,bk=b[j],bk+fh
				for k=fh-1,0,-1 do ti(p,bx(bj,k)>0 and s1 or s0) end
				if bk>800 or mg>1 then
					s = table.concat(p)
					for l=1,mg do
						self:writeRamData(s)
					end
					bk=1
					p={}
				end
			end
		end
		if bk>1 and il>0 then
			s = table.concat(p)
			for l=1,mg do
				 self:writeRamData(s)
			end
			p={}
		end
		self.x = self.x+mg*fw*il
		if slen>0 or self.x>self.xMax then
			self.x,self.y = self.x0,self.y+mg*fh
			is = is+il
		end
		s=""
		collectgarbage()
	end
	self:resetWindow()
	self:setRamMode(0,0,0)

	return self.x,self.y
end

function ST7735:println(str)
	self:print(str)
	self.x,self.y = self.x0,self.y+self.mag*self.font.height

	return self.x,self.y
end

collectgarbage()
return ST7735
