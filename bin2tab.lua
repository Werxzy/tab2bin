-- bin2tab
-- by werxzy

function char_set(str)
	local tab = {}
	for s in all(str) do
		tab[s] = true
	end
	return tab
end

function bin2tab(addr, format, subformat)
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
	-- local simple_op = char_set"#%?!@$-+<>"
	local char_stoppers = char_set"#%?!@$-+<>(){}[],="
	
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
		until not ch or char_stoppers[ch] 
		i -= 1
		-- could use sub() to improve performance?
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

		if char_stores[ch] and last_value ~= nil then -- store value in table on })],
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
			if last_value > 0 then
		    	add(loop_stack, {i, last_value})
			else -- no values to read inside loop, skip to end of loop
				local loop_count = 1
				repeat
					local ch2 = format[i]
					loop_count += tonum(ch2 == "(") - tonum(ch2 == ")")
					i += 1
				until loop_count == 0
			end
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
		end

		i += 1
	end

	-- last value should be expected to be the final table due to } or ]
	return last_value 
end
