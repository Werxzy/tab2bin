-- bin2tab, tab2bin
-- by werxzy

--[[ format

n is any positive integer, they can be replaced by xyz
xyz represents any stored variable (b reserved for reading bit)
_ next element, can be table, number or variable
abc a string, but not based on stored xyz variables

[ start index table
] end index table
{ start key table
} end key table
_,_ seperates values in table
abc=_ denotes a key-value pair in a key table
(key tables MUST use keys, no mixing allowed)

stores only happen on })],
after words, }] set the last_value to the table
	this is mostly so that tables can be added to other tables in a simple way
	but this can be abused with @xyz

#n read n bits as number (stored in last_value)
% read 1 bit and converts to boolean (stored in last_value)

~ ignore next store (may need to remove)
!n stores n in last_value

@xyz store last value into xyz
$abc starts seperate sub-format, provided in separate string, or use seperate function
(_) repeats values inside a number of times equal to the last_value (for index tables)
?n read next n bits to read the next n bytes as a string

+n alter last number by adding n
-n alter last number by subtracting n
>n alter last number by shifting right n (>>>)
<n alter last number by shifting left n (<<)

unfortunately, the possible range of values NEED to be known ahead of time
	though this usually shouldn't be a problem
can tecnically store a fixed point number with
	[#16>16@dec#16+dec]
	#16 read in 16 bits (0xffff)
	>16 shift those 16 bits to the right (0x0.ffff)
	@dec store the 16 bits into 
readability? who needs that?

]]


function char_set(str)
	local tab = {}
	for i = 1,#str do
		tab[str[i]] = true
	end
	return tab
end

function tab2bin(format, sub, tab, addr)
	-- pushes bits from the right
	local function w_bits()
		local b, c, a, mask = 0, 0, addr, split"1,3,7,15,31,63,127,255"
		-- can only write 16 bits at a time
		return function(x, n)
			while n > 0 do
				local c2 = min(n,8-c) -- get max possible read for byte
				n -= c2 -- lower read count
				c += c2 -- raise total count
				b <<= c2 -- make room for new bits
				b |= x & mask[c2] -- take only needed bits
				x >>>= c2 -- move bits over
				if c == 8 then -- if 8 bits read, write byte
					poke(a, b)
					b = 0
					a += 1
				end
			end
		end
	end
	local writer = w_bits()

	local char_stores = char_set"})],"
	local simple_op = char_set"@#?!$-+<>%"
	
	local tab_current = {}
	local tab_i = 1
	local tab_stack = {}
	local loop_stack = {}
	local stored_values = {}
	local last_value = nil
	local key = ""
	local tab_type = "index"
	local i = 1

	--[[ note
	this one is a bit weird, due to needing to look ahead of bit
	something like #8>1-64 would need to add 64 first and then shift left
	
	probably accumulate characters until a char_stoppers is reached

	(had an idea that the format could be read backwards, but realized it wouldn't work well with 
	]]

	-- should try to apply current indexed value when dealing with most/any simple_op

	while i < #format do
		local ch = format[i]
		-- todo

	end
	writer(0, 7) -- write 7 bits just in case
end

function bin2tab(format, sub, addr)
	local function r_bits()
		local b, c, a, mask = 0, 8, addr, split"1,3,7,15,31,63,127,255" -- is table read faster than ((1<<x)-1) ?
		-- can only read 16 bits at a time
		return function(n)
			local x = 0
			while n > 0 do
				if c == 8 then
					b = @a>>8 -- read next byte, put into position
					a += 1 -- next address
					c = 0 -- reset bit read count
				end
				local c2 = min(n, 8-c) -- get max possible read for byte
				c += c2 -- raise read count for current byte
				n -= c2 -- decrease total read count
				x |= (b<<c & mask[c2]) << n -- take only needed bits
			end
			return x
		end
	end
	local reader = r_bits()
	
	local char_stores = char_set"})],"
	local simple_pico8op = char_set"#%!@$-+<>?"
	local char_stoppers = char_set"#%!@$-+<>?(){}[],="
	
	local tab_current = {}
	local tab_i = 1
	local tab_type = "["
	local tab_stack = {}
	local loop_stack = {}
	local stored_values = {}
	local last_value = nil
	local i = 1

	local function read_to_stopper()
		local ch, s = "", ""
		repeat
			s ..= ch
			i += 1
			ch = format[i]
		until char_stoppers[ch]
		i -= 1
		return s
	end

	local function val(v)
		return tonum(v) or stored_values[v]
	end

	while i <= #format do
		local ch = format[i]
		
		if tab_type == "{" and not char_stores[ch] then
			-- read key for next index-table element
			i -= 1
			tab_i = read_to_stopper()
			i += 2
			ch = format[i]
		end

		if char_stores[ch] and last_value then -- store value in table on })],
			tab_current[tab_i] = last_value
			tab_i = tab_type == "[" and tab_i+1 or ""
			last_value = nil
		end
		
		if ch == "[" or ch == "{" then -- start of table
			-- add to stack, then update index and type
			add(tab_stack, {tab_current, tab_i, tab_type})
			tab_current = {}
			tab_type = ch
			tab_i = ch == "[" and 1 or ""

		elseif ch == "]" or ch == "}" then -- end of table
			last_value = tab_current
			tab_current, tab_i, tab_type = unpack(deli(tab_stack))

		elseif ch == "(" then -- start of loop
		    add(loop_stack, {i, last_value})
					elseif ch == ")" then -- end of loop check
			local l = loop_stack[#loop_stack]
			l[2] -= 1
			if l[2] == 0 then -- end loop
				deli(loop_stack)
			else -- jump back and repeat instructions
				i = l[1]
			end

		elseif ch == "#" then -- read bits
			last_value = reader(val(read_to_stopper()))
		elseif ch == "%" then -- read 1 bit to bool
			last_value = reader(1) == 1
		elseif ch == "!" then -- set last value to given
			last_value = val(read_to_stopper())
		
		elseif ch == "@" then -- store last value
			stored_values[read_to_stopper()] = last_value

		elseif ch == "+" then -- add number
			last_value += val(read_to_stopper())
		elseif ch == "-" then -- subtract
			last_value -= val(read_to_stopper())
		elseif ch == ">" then -- shift right
			last_value >>>= val(read_to_stopper())
		elseif ch == "<" then -- shift left
			last_value <<= val(read_to_stopper())

		elseif ch == "?" then -- read string data
			last_value = ""
			for m = 1, reader(val(read_to_stopper())) do
				last_value ..= chr(reader(8))
			end
			print(format[i])
		end

		i += 1
	end

	-- last value should be expected to be the final table due to } or ]
	return last_value 
end

-- [[ test

-- d = {{1,2,3},{100,200,300},{255,64,8}}}
-- form = "{a=[#8,#8,#8],b=[#8,#8,#8],asdf=[#8,#8,#8]}"
form = "[#8([!3(#8)])]"
-- form = "[#8([#8,#8,#8])]"
-- form = "[[#8,#8,#8],[#8,#8,#8],[#8,#8,#8]]"
-- tab2bin(form, nil, d, 0x8000)
poke(0x8000, 3, 1,2,3, 100,150,200, 255,64,8)
d = bin2tab(form, nil, 0x8000)
print(d[1][1])
print(d[2][2])
print(d[3][3])

-- form = "[?8]"
-- poke(0x8000, 5, ord("abcde", 1, 5))
-- d = bin2tab(form, nil, 0x8000)
-- print(d)
-- print(d[1])



--]]