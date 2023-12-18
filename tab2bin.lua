-- tab2bin
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
	for s in all(str) do
		tab[s] = true
	end
	return tab
end

char_stoppers = char_set"#%?!@$-+<>(){}[],="
function read_to_stopper(i, str)
	local ch, s = "", ""
	repeat
		s ..= ch
		i += 1
		ch = str[i]
	until not ch or char_stoppers[ch] 
	-- could use sub() to improve performance?
	return i,s
end


function w_bits(addr)
	local addr0, b, c, mask = addr, 0, 8, split"1,3,7,15,31,63,127,255" -- apparently ((1<<x)-1) is faster
	-- can only write 16 bits at a time
	return function(x, n)
		if(x == "len") return addr - addr0
		while n > 0 do
			local c2 = min(n, c) -- get max possible write for byte
			n -= c2 -- decrease total write count
			c -= c2 -- decreate write count for current byte
			b |= (x>>n & mask[c2]) << c -- take only needed bits

			if c == 0 then
				poke(addr, b)-- write next byte, put into position
				b = 0
				addr += 1 -- next address
				c = 8 -- reset bit read count
			end
		end
		return x
	end
end

function rollback_writer(addr)
	local writer = w_bits(addr)
	local loop_stack, byte_stack = {}, {} 
	local writing_length = false
	-- may need to change this format a little bit since tables are limited in size

	return function(x, n)
		if x == "push" then -- now entering loop
			add(loop_stack, {n, #byte_stack, #byte_stack+1})

		elseif x == "prep length" then
			writing_length = true

		elseif x == "pop" then -- now exiting loop (approve last section)
			writing_length = false
			local l = deli(loop_stack)

			if #loop_stack == 0 then -- if exited last loop, then write everything
				for b in all(byte_stack) do
					writer(unpack(b))
				end
				byte_stack = {}
			end

		elseif x == "confirm" then -- confirms the current data for the current loop works

			loop_stack[#loop_stack][2] = #byte_stack

		elseif x == "rollback" then -- delete writes after previous confirm

			-- may need to return extra info, like what key the loop was entered in
			-- this way data can be passed to a proceeding loop [#4(#8),#4(?8)]
			local y = loop_stack[#loop_stack][2]
			while #byte_stack > y do
				deli(byte_stack)
			end

		elseif #loop_stack > 0 then
			if writing_length then
				add(byte_stack, {x, n}, loop_stack[#loop_stack][3])
			else
				add(byte_stack, {x, n})
			end
		else
			writer(x, n)
		end
	end
end


-- instead store bit write information in a table 
-- only write when outside of a loop
function tab2bin(tab, addr, format, subformat) 
	-- init writer only if addr is an address
	local writer = type(addr) == "number" and rollback_writer(addr) or addr

	local char_stores = char_set"})],"
	local group_stoppers = char_set"(){}[],=" -- does not include @-+<>


	local tab_current = {tab}
	local tab_i = 1
	local tab_stack = {}
	local tab_type = "["

	local stored_values = {}


	local function val(v)
		return tonum(v) or stored_values[v]
	end

	local i = 1

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
			tab_current = tab_current[tab_i]
			tab_type = ch
			tab_i = ch == "[" and 1 or ""

		elseif ch == "]" or ch == "}" then
			last_value = tab_current
			tab_current, tab_i, tab_type = unpack(deli(tab_stack))

		elseif ch == "," then
			if tab_type == "[" then
				tab_i += 1
			end

		else
			
			local write_value = tab_current[tab_i]

			local j, loop_stack_count, groups, firstloop = i, 0, {}
			-- calculate groups "#8@b#8+10>>8!55" => {"#8@b", "#8+10>>8", "!55"}
			repeat
				local ch2 = format[j] -- todo, check where i+=1 is needed
				
				
				if loop_stack_count == 0 then
					if i ~= j and (ch2 == "#" or ch2 == "!" or ch2 == "%" or ch2 == "?" or group_stoppers[ch2] or not ch2) then
						add(groups, sub(format,i,j-1))
						i = j+1
					end
				end
				
				if ch2 == "(" then loop_stack_count += 1 if(not firstloop) firstloop = j
				elseif ch2 == ")" then loop_stack_count -= 1
				end
				j += 1
				-- we want to stop at the end of the last loop #8([#2(#2)])Vhere
			until group_stoppers[ch2] and loop_stack_count == 0 or not ch2
			j -= 2
			-- i,j = j,i
			i = j
			
			
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
				
					
				--!!! maybe push the writing into the groups part below, treating the entry length as the written value
				-- THEN if the value can't fit, consider the segment invalid
				-- then after the bytes are written, write loop data write IF there's information to write
				-- will still need to somehow push the length data before the loop data

			end
			
			-- proceed calculations per group
			-- should only contain $#@%!?+-<> n and xyz
			for g in all(groups) do
				local value = write_value -- needs to be reread for each group
				local ch1 = g[1]
				
				if ch1 == "#" then -- read things backwards to calculate the expected value
					-- could potentially be merged with the other one 
					-- (Would need to read the first command to understand what value is being read)
					local j = #g
					while j > 0 do
						
						-- reads backwards to reverse calculate the what is to be written
						local ch2, s = "", ""
						repeat 
							s = ch2 .. s
							ch2 = g[j]
							j -= 1
						until j <= 0 or char_stoppers[ch2] 
						j += 1

						local v = val(s)

						if ch2 == "#" then -- write bits to be read later
							if(type(value) ~= "number" or value & (1<<v)-1 ~= value) return false
							-- assert(value & (1<<v)-1 == value, "invalid size")
							-- the number won't fit
							-- could also return false

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
						
						local ch2 = g[j]
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
							-- doesn't support #8+10@n?n
						end
						j += 1
					end
				end
			end
			
			if firstloop then -- pop
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


	-- if type(addr) == "number" then -- will need to change what is returned based on what level the function is on
end
-- probably too many nested statements