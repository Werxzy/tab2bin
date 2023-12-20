-- bin2tab
-- by werxzy

do

local function char_set(str)
	local tab = {}
	for s in all(str) do
		tab[s] = true
	end
	return tab
end

local char_stores, char_stoppers 
	= char_set"})],", char_set"#%?!@$-+<>(){}[],="

local function r_bits(addr)
	local b, c, a = 0, 8, addr
	-- can only read 16 bits at a time
	return function(n)
		local x = 0
		while n > 0 do
			if c == 8 then
				b, c = @a>>8, 0 -- read next byte, put into position and reset bit read count
				a += 1 -- next address
			end
			local c2 = min(n, 8-c) -- get max possible read for byte
			c += c2 -- raise read count for current byte
			n -= c2 -- decrease total read count
			x |= (b<<c & (1<<c2)-1) << n -- take only needed bits
		end
		return x
	end
end

function bin2tab(addr, format, subformat, stored_values_carried, last_value_carried)
	
	local reader, tab_current, tab_i, tab_type, tab_stack, loop_stack, stored_values, i, last_value 
		= type(addr) == "number" and r_bits(addr) or addr, {}, 1, "[", {}, {}, stored_values_carried or {}, 1, last_value_carried

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
		
		if tab_type == "{" and not char_stoppers[ch] then
			-- read key for next index-table element
			i -= 1
			tab_i = read_to_stopper()
			i += 2
			ch = format[i]
		end

		if char_stores[ch] and last_value ~= nil then -- store value in table on })],
			tab_current[tab_i], tab_i, last_value 
				= last_value, tab_type == "[" and tab_i+1 or ""
		end
		
		if ch == "[" or ch == "{" then -- start of table
			-- add to stack, then update index and type
			add(tab_stack, {tab_current, tab_i, tab_type})
			tab_current, tab_i, tab_type 
				= {}, ch == "[" and 1 or "", ch

		elseif ch == "]" or ch == "}" then -- end of table
			last_value, tab_current, tab_i, tab_type 
				= tab_current, unpack(deli(tab_stack))

		elseif ch == "(" then -- start of loop
			if last_value > 0 then
		    	add(loop_stack, {i, last_value})
			else -- no values to read inside loop, skip to end of loop
				local loop_count = 1
				repeat
					i += 1
					local ch2 = format[i]
					loop_count += tonum(ch2 == "(") - tonum(ch2 == ")")
				until loop_count == 0
				last_value = nil
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

		elseif ch == "$" then -- subformat
			local subf = subformat[read_to_stopper()]
			
			if type(subf) == "string" then -- string subformat
				last_value = bin2tab(reader, subf, subformat, stored_values, last_value)
			elseif type(subf) == "function" then -- subformat dependent on a function
				last_value = subf(reader, last_value, stored_values)
			end
		end

		i += 1
	end

	-- last value should be expected to be the final table due to } or ]
	return last_value 
end

end
