# Table to Binary in Pico-8

tab2bin and bin2tab are functions for converting a table of a known format/shape into binary within Pico-8.

Currently tab2bin is being worked on.

## Table Format

|||
|-|-|
|`n`| Any number recognized by Pico-8 |
|`xyz`| Stored variable name, can by almost any string |
|`_`| Any element or number |
|`abc`| Any string, though unrelated to stored variables |

|Characters| Function|
|-|-|
|`[_]`| Indexed table
|`{_}`| Keyed table
|`_,_`| Separate elements in a table |
|`abc=_`| Denotes a key-value pair in a keyed table |
|||
|`#n`| Reads the next n bits as a number into the `last read value` |
|`%`| Reads the next bit as a boolean into the `last read value` |
|`?n`| Read the next n bits to read that number of bytes as a string (into `last read value`) |
|`@xyz`| Stores the `last read value` into variable `xyz` |
|||
|`!n`| Stores n as the `last read value` |
|`+n`| Alters the `last read value` by adding n |
|`-n`| Alters the `last read value` by subtracting n |
|`>n`| Alters the `last read value` by shifting right n `>>>` |
|`<n`| Alters the `last read value` by shifting left n `<<` |
|||
|`$abc`| Starts a separate provided sub-format or function |
|`(_)`| Loops a section equal to the `last read value` before it starts |

## In Depth

### Last Read Value

The `last read value` is what is being assigned, altered, stored, and appended during the tab2bin and bin2tab functions. by applying something like `#9-256` you can have a full range of numbers from -256 to 255 with 9 bits of information. tab2bin applies this conversion for you.

### Appending to table

While the `last read value` is made or changed, it only gets added to the table(s) generated by tab2bin/bin2tab after the following characters:

- `,` end of current element
- `]` end of indexed table
- `}` end of keyed table
- `)` end of loop

After a store operation happens, the `last read value` is set to `nil` and store operations are skipped if the `last read value` is `nil`. If a new values is read into the `last read value`, the old one will be lost. In addition, the end of a table (`]` or `]`) will set that table to be the `last read value`, so that it can be appended to another table.

## Examples

```lua
-- reads 2 entries
tab = {1,2}
form = "[#8,#8]"
tab2bin(form, nil, tab, 0x8000)
tab2 = tab2bin(form, nil, 0x8000)
```

```lua
-- reads a variable amount of numbers, up to 255
tab = {1,2,4,8,16,32,64,128}
form = "[#8(#8)]"
```

```lua
-- reads a table of tables
tab = {{1,2,4},{8,16,32},{64,128,3}}
form = "[#8([#8,#8,#8])]"

-- the format will also work with a fixed loop size
form = "[#8([!3(#8)])]"
```

```lua
-- can store a full 32-bit fixed point number from pico8
form = "[#16>16@dec#16+dec]"

--[[
#16 read in 16 bits (0xffff)
>16 shift those 16 bits to the right (0x0.ffff)
@dec store the 16 bits into 
#16 read in 16 bits (0xffff)
+dec add the lower 16 bits in for the decimal (0xffff.ffff)
]]
```

```lua
tab = {
    x = 10,
    y = 30,
    z = 40
}
form = "{x=#8,y=#8,z=#8}
```

```lua
tab = {
    {name = "player", health = 5, maxhealth = 10},
    {name = "enemy1", health = 3, maxhealth = 3},
    {name = "enemy2", health = 2, maxhealth = 4},
    -- ...
}
form = "[#8({name=?5,health=#5,maxhealth=#5})]"
```

`todo: add examples of sub-formats when implemented`

## Extras

Something that would be nice to have is a format calculator function that takes in a table and returns a string that would best compress that table. This way any the format could be stored inside the pico-memory and the table could be easily compressed and decompressed without even knowing the format. Though this would be very complex and will likely have problems. (So I will not be the one making it if ever.)
