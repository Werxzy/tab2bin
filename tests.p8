pico-8 cartridge // http://www.pico-8.com
version 41
__lua__
#include bin2tab.lua
#include tab2bin.lua

cls()

function get_keys(tab)
    local keys = {}
    for k,_ in pairs(tab) do
        add(keys, k)
    end
    return keys
end

function equal(tab1, tab2)
    if(tab1 == nil or tab2 == nil or #get_keys(tab1) ~= #get_keys(tab2)) return false

    for k,v in pairs(tab1) do
        if type(v) == "table" then
            if not equal(v, tab2[k]) then
                return false
            end
        elseif v ~= tab2[k] then
            return false
        end
    end

    return true
end

function print_tab(tab)
    for k,v in pairs(tab) do
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
end

local tab = {1, 2, 3, {a=4,b=6,c=7,d={8,9}}, "test",{"test2", "test3"}}
assert(equal(tab,tab))

function test(format, tab)
    tab2bin(tab, 0x8000, format)
    local tab2 = bin2tab(0x8000, format)
    if not equal(tab, tab2) then
        print_tab(tab)
        print_tab(tab2)
        return false
    end
    return true
end

assert(test(
    "[#8,#8-128,%,?8]",
    {10,-10,true,"this is a test"}
))
assert(test(
    "{a=#8,b=#8,c=#8}",
    {a=10,b=20,c=30}
))
assert(test(
    "[[#8,#8,#8],[#8,#8,#8]]",
    {{1,2,3},{9,8,7}}
))
assert(test(
    "{a={x=#8,y=#8},b={x=#8,y=#8}}",
    {a={x=100,y=200},b={x=5,y=6}}
))
assert(test(
    "[#8(#8)]",
    {1,2,3,9,8,7}
))
assert(test(
    "[#8([#8,#8(#8)])]",
    {{1,2,3,4},{33},{9,8,7}}
))
assert(test(
    "[#8(#8)#8(?8)]",
    {1,2,3,4,"asdf","test"}
))
assert(test(
    "[#8([!3(#8)])]",
    {{1,2,3},{9,8,7}}
))

print("all tests passed")
__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
