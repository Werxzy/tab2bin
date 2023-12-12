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
	for i = 1,#str do
		tab[str[i]] = true
	end
	return tab
end

-- to be reworked and fixed

function tab2bin(tab, addr, format, sub)
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
	-- local simple_op = char_set"@#?!$-+<>%"
	local group_stoppers = char_set"#?!$%(){}[],=" -- does not include @-+<>
	local char_stoppers = char_set"@#?!$%-+<>(){}[],="
	local char_notop = char_set"{}[]()"
	
	local tab_current = tab
	local tab_i = 1
	local tab_stack = {}
	local loop_stack = {}
	local stored_values = {}
	local last_value = nil
	local key = ""
	local tab_type = "index"
	local i = 1

	local function read_to_stopper(stops)
		local ch, s = "", ""
		repeat
			s ..= ch
			i += 1
			ch = format[i]
		until not ch or stops[ch] 
		i -= 1
		return s
	end

	local function val(v)
		return tonum(v) or stored_values[v]
	end

	--[[ note
	this one is a bit weird, due to needing to look ahead of bit
	something like #8>1-64 would need to add 64 first and then shift left
	
	probably accumulate characters until a char_stoppers is reached
	
	for loops, could hold a stack of rollback info
		original byte addr, byte value at that stage
		when one iteration is complete, increment the loop value and then continue
	]]

	-- for loops, try storing an indexed table to bits to be written
	-- store where in everything that needs to be rolled back if an inconsistency is found
	-- potentially first store sets of instructions and then change what happens to it based on if a loop or store call happens
	-- could also first make this function without loops first

	-- [#8@b,!b(#8)] is a bit of a weird situation due to the dependancy of b on another value
	-- maybe just assume the "!b" value is a stuck number
	-- then EXPECT there to be that many entries, missing entries will just be zeroes
	-- and if the number is too low, the next entries iwll be ignored

	while i < #format do
		local ch = format[i]
		
		-- todo, check for key table

		if ch == "[" or ch == "{" then 
			local next_tab = tab_current[tab_i]
			add(tab_stack, {tab_current, tab_i, tab_type})
			tab_current = next_tab
			tab_type = ch
			tab_i = ch == "[" and 1 or ""

		elseif ch == "]" or ch == "}" then

		end

		if char_stores[ch] then
			--increment
			if tab_type == "[" then

			else

			end

		elseif not char_notop[ch]
			-- uh oh, for loops, will need to actually check 
			-- !!! need to check where the final number is from
			-- either a table entry, or a loop length

			-- reads the characters until it hits the first stopper (past the first character)
			local value = tab_current[tab_i]
			if ch == "!" then -- use given value instead of table value
				value = val(read_to_stopper(char_stoppers))
			end
			i -= 1 -- todo:double check, not sure if either of these are 1 off or not
			local str = read_to_stopper(group_stoppers)

			local j = #str
			while j > 0 do

				-- reads backwards to reverse calculate the what is to be written
				local ch2, s = "", ""
				repeat
					s ..= ch2
					j -= 1
					ch2 = str[j]
				until not ch2 or char_stoppers[ch] 

				local v = val(s)

				if ch2 == "#" then -- write bits to be read later
					writer(value, s)
				elseif ch2 == "%" then -- write bool
					writer(value and 1 or 0, 1)
				elseif ch2 == "@" then
					stored_values[s] == value

				-- do the opposite of the asked action
				elseif ch2 == "-" then 
					value += s
				elseif ch2 == "+" then 
					value -= s
				elseif ch2 == "<" then 
					value >>>= s
				elseif ch2 == ">" then 
					value <<= s

				-- elseif ch == "?" -- string
				
				end -- ignore ! as it's already been read

				j -= 1
			end
		end


	end
	writer(0, 7) -- write 7 bits just in case
end

