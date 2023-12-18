pico-8 cartridge // http://www.pico-8.com
version 41
__lua__
#include bin2tab.lua
#include tab2bin.lua


-- -- d = {{1,2,3},{100,200,300},{255,64,8}}}
-- -- tab2bin(d, 0x8000, form)
-- poke(0x8000, 3, 1,2,3, 100,150,200, 255,64,8)
-- --temp poke

-- -- form = "{a=[#8,#8,#8],b=[#8,#8,#8],asdf=[#8,#8,#8]}"
-- -- form = "[[#8,#8,#8],[#8,#8,#8],[#8,#8,#8]]"
-- -- form = "[#8([#8,#8,#8])]"
-- form = "[#8([!3(#8)])]"

-- d = bin2tab(0x8000, form)
-- for a in all(d) do
-- 	local s = ""
-- 	for b in all(a) do
-- 		s ..= b .. "\t"
-- 	end
-- 	print(s)
-- end


-- form = "?8"
-- --form = "[?8]"
-- poke(0x8000, 5, ord("abcde", 1, 5))
-- d = bin2tab(0x8000, form)
-- print(d)


--form = "[#8,#8-128,%,?8]"
--tab = {10,-10,true,"this is a test"}

--form = "{a=#8,b=#8,c=#8}"
--tab = {a=10,b=20,c=30}

--form = "[[#8,#8,#8],[#8,#8,#8]]"
--tab = {{1,2,3},{9,8,7}}

--form = "{a={x=#8,y=#8},b={x=#8,y=#8}}"
--tab = {a={x=100,y=200},b={x=5,y=6}}

--form = "[#8(#8)]"
--tab = {1,2,3,9,8,7}

--form = "[#8([#8,#8(#8)])]"
--tab = {{1,2,3,4},{33},{9,8,7}}

form = "[#8(#8)#8(?8)]"
tab = {1,2,3,4,"asdf","test"}

--form = "[#16>>16@dec#16+dec]"
print(tab2bin(tab, 0x8000, form))
tab2 = bin2tab(0x8000, form)
print"done"
for k,v in pairs(tab2) do
	if type(v) == "table" then
		local found = false
		for k2,v in pairs(v) do
			found = true
			print(k..","..k2.."="..tostr(v))
		end
		if not found then
			print(k.."={}")
		end
	else
		print(k.."="..tostr(v))
	end
end

__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
