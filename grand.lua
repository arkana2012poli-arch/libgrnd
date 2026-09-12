local base64 = require("base64")
 
local tok = ""
local dev = ""
 
function e(str, key)
    local data = { str:byte(1, -1) }
 
    local function m32(a, b)
        local al = bit.band(a, 0xFFFF)
        local ah = bit.rshift(a, 16)
        local bl = bit.band(b, 0xFFFF)
        local bh = bit.rshift(b, 16)
        return bit.tobit(al * bl + bit.lshift(ah * bl + al * bh, 16))
    end
 
    local function state(k)
        return bit.bxor(bit.lshift(bit.band(k, 3), 3), bit.bor(0x7549, bit.lshift(k, 13)), 0x62098F3C)
    end
 
    local function r32(i)
        i = i + 1
        return bit.bor(data[i], bit.lshift(data[i + 1], 8), bit.lshift(data[i + 2], 16), bit.lshift(data[i + 3], 24))
    end
 
    local function w32(i, v)
        i = i + 1
        data[i + 0] = bit.band(v, 0xFF)
        data[i + 1] = bit.band(bit.rshift(v, 8), 0xFF)
        data[i + 2] = bit.band(bit.rshift(v, 16), 0xFF)
        data[i + 3] = bit.band(bit.rshift(v, 24), 0xFF)
    end
 
    for block = 0, math.floor(#data / 64) - 1 do
        for row = 0, 7 do
            local s = state(key)
            local add = bit.bor(0x448C, bit.lshift(s, 16))
 
            for word = 0, 1 do
                local offset = block * 64 + row * 8 + word * 4
                w32(offset, bit.bxor(r32(offset), key, 0x7890CFB3))
 
                key = bit.bxor(key, s)
                s = bit.tobit(m32(s, 0x06511073) + add)
                add = bit.bxor(add, word)
            end
        end
    end
 
    local s = state(key)
    for i = 0, (#data % 64) - 1 do
        local p = #data - i
        data[p] = bit.band(bit.bxor(data[p], s), 0xFF)
        s = bit.tobit(m32(key, 0x06511073) + s)
    end
 
    return string.char(unpack(data))
end
 
function onReceiveRpc(id, bs_i)
    if(id == 253) then
        if(raknetBitStreamReadInt8(bs_i) == 18) then
            local k = raknetBitStreamReadInt32(bs_i)
            local e_tok = base64.encode(e(tok, k))
            local e_dev = base64.encode(e(dev, k))
 
            local bs = raknetNewBitStream()
            raknetBitStreamWriteInt8(bs, 18)
            raknetBitStreamWriteInt32(bs, #e_tok)
            raknetBitStreamWriteString(bs, e_tok)
            raknetBitStreamWriteInt32(bs, #e_dev)
            raknetBitStreamWriteString(bs, e_dev)
            raknetSendRpc(253, bs)
        end
    end
end
 
function onReceivePacket(id, bs_i)
    if(id == 34) then
        raknetBitStreamIgnoreBits(bs_i, 72)
 
        local c = raknetBitStreamReadInt32(bs_i)
        local a = "149C15C7E69314B147D55069C245763C07DD8AB4429"
        local n = sampGetPlayerNickname(select(2, sampGetPlayerIdByCharHandle(PLAYER_PED))) 
        local sv = "59.01-apk"
 
        local bs = raknetNewBitStream()
        raknetBitStreamWriteInt32(bs, 4057)
        raknetBitStreamWriteInt8(bs, 1)
        raknetBitStreamWriteInt8(bs, string.len(n))
        raknetBitStreamWriteString(bs, n)
        raknetBitStreamWriteInt32(bs, bit.bxor(c, 4057))
        raknetBitStreamWriteInt8(bs, string.len(a))
        raknetBitStreamWriteString(bs, a)
        raknetBitStreamWriteInt8(bs, 5)
        raknetBitStreamWriteString(bs, "0.3.7")
 
        raknetBitStreamWriteInt16(bs, 34215)
        raknetBitStreamWriteInt32(bs, #tok)
        raknetBitStreamWriteString(bs, tok)
        raknetBitStreamWriteInt32(bs, #dev)
        raknetBitStreamWriteString(bs, dev)
 
        raknetBitStreamWriteInt32(bs, 5901) -- ver
        raknetBitStreamWriteBool(bs, true)
        raknetBitStreamWriteInt8(bs, 64)
        raknetBitStreamWriteInt8(bs, #sv)
        raknetBitStreamWriteString(bs, sv)
        raknetSendRpc(25, bs)
 
        return false
    end
end