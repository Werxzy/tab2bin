-- tab2bin
-- by werxzy

do

local function char_set(str)
	local tab = {}
	for s in all(str) do
		tab[s] = true
	end
	return tab
end

local char_stoppers, char_stores, group_stoppers, char_non_modifier
	= char_set"#%?!@$-+<>(){}[],=", char_set"})],", char_set"(){}[],=", char_set"#%?!@$(){}[],="

local function read_to_stopper(i, str)
	local ch, s = "", ""
	repeat
		s ..= ch
		i += 1
		ch = str[i]
	until not ch or char_stoppers[ch] 
	-- could use sub() to improve performance?
	return i,s
end

local function w_bits(addr)
	local addr0, b, c = addr, 0, 8
	-- can only write 16 bits at a time
	return function(x, n)
		if(x == "len") return addr - addr0
		while n > 0 do
			local c2 = min(n, c) -- get max possible write for byte
			n -= c2 -- decrease total write count
			c -= c2 -- decreate write count for current byte
			b |= (x>>n & (1<<c2)-1) << c -- take only needed bits

			if c == 0 then
				poke(addr, b)-- write next byte, put into position
				b, c = 0, 8 -- reset current byte and bits left to write
				addr += 1 -- next address
			end
		end
		return x
	end
end

local function rollback_writer(addr)
	local writer, loop_stack, byte_stack, writing_length = w_bits(addr), {}, {} 
	-- may need to change byte_stack format a little bit since tables are limited in size

	return function(x, n)
		if x == "push" then -- now entering loop
			add(loop_stack, {#byte_stack, #byte_stack+1})

		elseif x == "prep length" then -- prepare to write the length of a loop
			writing_length = true

		elseif x == "pop" then -- now exiting loop (approve last section)
			writing_length = false
			deli(loop_stack)

			if #loop_stack == 0 then -- if exited last loop, then write everything
				for b in all(byte_stack) do
					writer(unpack(b))
				end
				byte_stack = {}
			end

		elseif x == "confirm" then -- confirms the current data for the current loop works
			loop_stack[#loop_stack][1] = #byte_stack

		elseif x == "rollback" then -- delete writes after previous confirm
			for i = 1, #byte_stack - loop_stack[#loop_stack][1] do -- there's a chance that this is incorrect, but it currently passes all the tests
				deli(byte_stack)
			end

		elseif #loop_stack > 0 then -- store information to be written or ignored
			add(byte_stack, {x, n}, 
				writing_length and loop_stack[#loop_stack][2] 
				or #byte_stack+1)

		else -- write normally
			writer(x, n)
		end
	end
end


-- instead store bit write information in a table 
-- only write when outside of a loop
function tab2bin(tab, addr, format, subformat) 
	-- init writer only if addr is an address
	local writer, tab_current, tab_i, tab_stack, tab_type, stored_values, i
		= type(addr) == "number" and rollback_writer(addr) or addr, {tab}, 1, {}, "[", {}, 1

	local function val(v)
		return tonum(v) or stored_values[v]
	end

	while i < #format do
		
		local ch = format[i]

		-- read key for next index-table element
		if tab_type == "{" and not char_stores[ch] then
			i, tab_i = read_to_stopper(i-1, format)
			i += 1
			ch = format[i]
		end
		
		-- read if next character is for a table {}[],
		if ch == "[" or ch == "{" then
			add(tab_stack, {tab_current, tab_i, tab_type})
			tab_current, tab_type, tab_i 
				= tab_current[tab_i], ch, ch == "[" and 1 or ""

		elseif ch == "]" or ch == "}" then
			last_value, tab_current, tab_i, tab_type 
				= tab_current, unpack(deli(tab_stack))

		elseif ch == "," then
			if tab_type == "[" then
				tab_i += 1
			end

		else
			local write_value, j, loop_stack_count, groups, firstloop = tab_current[tab_i], i, 0, {}

			-- calculate groups "#8@b#8+10>>8!55" => {"#8@b", "#8+10>>8", "!55"}
			repeat
				local ch2 = format[i]
				
				if loop_stack_count == 0 then
					if i ~= j and (not ch2 or char_non_modifier[ch2]) then
						add(groups, sub(format, j, i-1))
						j = i+1
					end
				end
				
				if ch2 == "(" then 
					loop_stack_count += 1 
					if(not firstloop) firstloop = i
				elseif ch2 == ")" then 
					loop_stack_count -= 1
				end
				i += 1
				-- we want to stop at the end of the last loop #8([#2(#2)])Vhere
			until group_stoppers[ch2] and loop_stack_count == 0 or not ch2
			i -= 2
			
			if firstloop then
				-- could process all but the last group normally, though they should probably cause errors
				local valid, loopformat = true, sub(format, firstloop+1, i)
				write_value = 0
				writer"push"

				while valid and tab_current[tab_i] do
					valid = tab2bin(tab_current[tab_i], writer, loopformat, subformat) 
					-- might not need bits? would need to figure this out
					if valid then -- entry is valid
						tab_i += 1
						write_value += 1
						writer"confirm"
					else -- entry is invalid
						writer"rollback"
					end 
				end
				
				i += 1
				writer"prep length"

			end
			
			-- proceed calculations per group
			-- should only contain $#@%!?+-<> n and xyz
			for g in all(groups) do
				local value = write_value
				
				if g[1] == "#" then -- read things backwards to calculate the from the expected value
					-- could potentially be merged with the other one 
					-- (Would need to read the first command to understand what value is being read)
					local j = #g
					while j > 0 do
						
						-- reads backwards to reverse calculate the what is to be written
						local ch2, s = "", ""
						repeat 
							s, ch2 = ch2..s, g[j]
							j -= 1
						until j <= 0 or char_stoppers[ch2] 
						j += 1

						local v = val(s)

						if ch2 == "#" then -- write bits to be read later
							if(type(value) ~= "number" or value & (1<<v)-1 ~= value) return false
							writer(value, v)
							
						elseif ch2 == "@" then
							stored_values[s] = value

						-- do the opposite of the asked action
						elseif ch2 == "+" then 
							value -= v
						elseif ch2 == "-" then 
							value += v
						elseif ch2 == ">" then 
							value <<= v
						elseif ch2 == "<" then 
							value >>>= v
						
						end

						j -= 1
					end

					
				else
					local j, last_value, g2 = 1, value

					while j <= #g do
						
						j, g2 = read_to_stopper(j, g)
						local v = val(g2)

						if ch == "%" then -- read 1 bit to bool
							last_value = val(last_value and true or false)
							writer(tonum(last_value), 1)
						elseif ch == "!" then -- set last value to given
							last_value = v
						
						elseif ch == "@" then -- store last value
							stored_values[g2] = last_value
				
						elseif ch == "+" then -- add number
							last_value += v
						elseif ch == "-" then -- subtract
							last_value -= v
						elseif ch == ">" then -- shift right
							last_value >>>= v
						elseif ch == "<" then -- shift left
							last_value <<= v
				
						elseif ch == "?" then -- read string data
							-- assert(type(last_value) == "string", "expected string") -- might give more information
							if(type(last_value) ~= "string") return false

							writer(#last_value, v) -- write length
							for i=1,#last_value do
								writer(ord(last_value[i]) or 0, 8) -- write bytes
							end
							-- doesn't support #8+10@xyz?xyz
						end
						j += 1
					end
				end
			end
			
			if firstloop then -- pop loop if tab2bin was in one
				writer"pop"
			end
		end
		
		i += 1
	end
	
	if type(addr) == "number" then
		writer(0, 7) -- write 7 bits just in case
		return writer"len"
	else
		return true
	end
end

end