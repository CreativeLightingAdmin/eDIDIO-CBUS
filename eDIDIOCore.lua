require("user.eDIDIOConfig")

local host, port = eDIDIOS10.ip, 23
local socket = require("socket")
local tcp = assert(socket.tcp())

-- TODOs
-- DMX Message - Needs Testing
-- DMX Colour - Do we do this, or just do 3/4 times DMX Message
-- DALI DT8 CCT - Working, test with light
-- DALI DT8 Colour - Working, test with light
-- Start List Message

--ENUMs
-- DALI Addressing
DALI_0 = 0
DALI_1 = 1
DALI_2 = 2
DALI_3 = 3
DALI_4 = 4
DALI_5 = 5
DALI_6 = 6
DALI_7 = 7
DALI_8 = 8
DALI_9 = 9
DALI_10 = 10
DALI_11 = 11
DALI_12 = 12
DALI_13 = 13
DALI_14 = 14
DALI_15 = 15
DALI_16 = 16
DALI_17 = 17
DALI_18 = 18
DALI_19 = 19
DALI_20 = 20
DALI_21 = 21
DALI_22 = 22
DALI_23 = 23
DALI_24 = 24
DALI_25 = 25
DALI_26 = 26
DALI_27 = 27
DALI_28 = 28
DALI_29 = 29
DALI_30 = 30
DALI_31 = 31
DALI_32 = 32
DALI_33 = 33
DALI_34 = 34
DALI_35 = 35
DALI_36 = 36
DALI_37 = 37
DALI_38 = 38
DALI_39 = 39
DALI_40 = 40
DALI_41 = 41
DALI_42 = 42
DALI_43 = 43
DALI_44 = 44
DALI_45 = 45
DALI_46 = 46
DALI_47 = 47
DALI_48 = 48
DALI_49 = 49
DALI_50 = 50
DALI_51 = 51
DALI_52 = 52
DALI_53 = 53
DALI_54 = 54
DALI_55 = 55
DALI_56 = 56
DALI_57 = 57
DALI_58 = 58
DALI_59 = 59
DALI_60 = 60
DALI_61 = 61
DALI_62 = 62
DALI_63 = 63
DALI_G0 = 64
DALI_G1 = 65
DALI_G2 = 66
DALI_G3 = 67
DALI_G4 = 68
DALI_G5 = 69
DALI_G6 = 70
DALI_G7 = 71
DALI_G8 = 72
DALI_G9 = 73
DALI_G10 = 74
DALI_G11 = 75
DALI_G12 = 76
DALI_G13 = 77
DALI_G14 = 78
DALI_G15 = 79
DALI_BROADCAST = 80

-- Type 8
SET_TEMP_X_COORD = 0
SET_TEMP_Y_COORD = 1
ACTIVATE = 2
SET_TEMP_COLOUR_TEMP = 7
COLOUR_TEMP_COOLER = 8
COLOUR_TEMP_WARMER = 9

function PrintHex(data)
    for i = 1, #data do
        char = string.sub(data, i, i)
        io.write(string.format("%02x", string.byte(char)) .. " ")
    end
end

-- This Function as a basic protocol buffer - Uses Override type for sensors
function createDALIOverrideString(line, address, level) -- DALI Arc Override Command
    if (level == 0) then
        if (address == 0) then
            return "\xCD\x00\x09\xAA\x01\x06\x0A\x04\x08\x36\x18\x01" -- Last Byte is the Line
        else
            msg = "\xCD\x00\x0B\xAA\x01\x08\x0A\x06\x08\x36\x18\x01\x20\x01" -- 3rd Last Byte is the Line, Last Byte is the Address
            msg = replace_char(14, msg, address)
            return msg
        end
    elseif (level < 127) then
        if (address == 0) then
            msg = "\xCD\x00\x0B\xAA\x01\x08\x0A\x06\x08\x36\x18\x01\x28\x00" -- Last Byte is Level, 3rd Last Byte is Line
            msg = replace_char(13, msg, level)
            return msg
        else
            msg = "\xCD\x00\x0D\xAA\x01\x0A\x0A\x08\x08\x36\x18\x01\x20\x01\x28\x01" -- Last Byte is Level, 5th Last Byte is Line, 3th Last Byte is Address
            msg = replace_char(16, msg, level)
            msg = replace_char(14, msg, address)
            msg = replace_char(12, msg, line)
            return msg
        end
    else -- Level above 127
        if (address == 0) then
            msg = "\xCD\x00\x0C\xAA\x01\x09\x0A\x07\x08\x36\x18\x01\x28\x80\x01" -- Second Last Byte is Level, 4th Last Byte is Line
            msg = replace_char(14, msg, level)
            msg = replace_char(12, msg, line)
            return msg
        else
            msg = "\xCD\x00\x0E\xAA\x01\x0B\x0A\x09\x08\x36\x18\x01\x20\x01\x28\x80\x01" -- Second Last Byte is Level, 6th Last Byte is Line, 4th Last Byte is Address
            msg = replace_char(16, msg, level)
            msg = replace_char(14, msg, address)
            msg = replace_char(12, msg, line)
            return msg
        end
    end
end

-- DALI Frame Message.
-- Byte 10 is the command (offset by 0x80). Byte 11 is the Address which is 2 * the Adjusted Value. Byte 12 is 0x01 if the Adjusted Value is over 127
-- Line is the 4th last byte
-- Covers all messages under 79
function createDALICommandFrame(line, address, command)
    if (address == 80) then
        address = 255
    end
    frame = bit.lshift((address * 2 + 1), 8) + command
    if (command <= 79) then
        if (address <= 32) then
            msg = "\xCD\x00\x08\x92\x01\x05\x08\x01\x58\x86\x02" -- Standard Command
            arg1 = bit.band(frame, 0x7F) + 0x80
            arg2 = bit.band(bit.rshift(frame, 7), 0x7F)
            msg = replace_char(10, msg, arg1) -- Frame Data
            msg = replace_char(11, msg, arg2) -- Frame Data
        else
            msg = "\xCD\x00\x09\x92\x01\x06\x08\x01\x58\x86\x02\x01" -- Additional Byte
            arg1 = bit.band(frame, 0x7F) + 0x80
            arg2 = bit.band(bit.rshift(frame, 7), 0x7F) + 0x80
            arg3 = bit.band(bit.rshift(frame, 14), 0x7F)
            msg = replace_char(10, msg, arg1) -- Frame Data
            msg = replace_char(11, msg, arg2) -- Frame Data
            msg = replace_char(12, msg, arg3) -- Frame Data
        end
        msg = replace_char(8, msg, line) --Replace Line
    end
    return msg
end

-- Creates a DT8 Message. Suits X/Y Coords, Temp, Activate, Warmer/Cooler
function createDT8Command(line, address, cmd, arg)
    -- Varint encoding. Split into 7-bit chunks. Convert to Hex, set MSB for all except the last byte
    if (address == 0) then
        if ((cmd == 0) or (cmd == 1) or (cmd == 7)) then -- Set X/Y Coords, Colour Temp Add DTRs
            msg = "\xCD\x00\x0E\x92\x01\x0B\x08\x01\x40\x00\x52\x05\x0A\x03\x00\x01\x02"

            -- line
            msg = replace_char(8, msg, line)

            -- cmd
            msg = replace_char(10, msg, cmd)

            -- dtr
            dtr0 = bit.band(arg, 0xFF)
            dtr1 = bit.band(bit.rshift(arg, 8), 0xFF)
            dtr2 = bit.band(bit.rshift(arg, 16), 0xFF)

            offset = 0
            if (dtr0 >= 0x80) then
                msg = replace_char(15, msg, bit.band(dtr0, 0x7F) + 0x80)
                msg = insert_char(15, msg, bit.band(bit.rshift(dtr0, 7), 0x7F))
                offset = offset + 2
            else
                msg = replace_char(15, msg, dtr0)
                offset = offset + 1
            end

            if (dtr1 >= 0x80) then
                msg = replace_char(15 + offset, msg, bit.band(dtr1, 0x7F) + 0x80)
                msg = insert_char(15 + offset, msg, bit.band(bit.rshift(dtr1, 7), 0x7F))
                offset = offset + 2
            else
                msg = replace_char(15 + offset, msg, dtr1)
                offset = offset + 1
            end

            if (dtr2 >= 0x80) then
                msg = replace_char(15 + offset, msg, bit.band(dtr2, 0x7F) + 0x80)
                msg = insert_char(15 + offset, msg, bit.band(bit.rshift(dtr2, 7), 0x7F))
                offset = offset + 2
            else
                msg = replace_char(15 + offset, msg, dtr2)
                offset = offset + 1
            end

            -- Replace DTR Length
            msg = replace_char(14, msg, offset)
            -- Replace Data Length
            msg = replace_char(12, msg, offset + 2)
            -- Replace Data Length
            msg = replace_char(6, msg, 0x0B - 3 + offset)
            -- Replace Full Length
            msg = replace_char(3, msg, 0x0E - 3 + offset)
        else
            msg = "\xCD\x00\x09\x92\x01\x06\x08\x01\x40\x02\x52\x00"
            -- line
            msg = replace_char(8, msg, line)
            -- cmd
            msg = replace_char(10, msg, cmd)
        end
    else
        if ((cmd == 0) or (cmd == 1) or (cmd == 7)) then -- Set X/Y Coords, Colour Temp Add DTRs
            msg = "\xCD\x00\x10\x92\x01\x0D\x08\x01\x10\x05\x40\x02\x52\x05\x0A\x03\x00\x01\x02"

            -- line
            msg = replace_char(8, msg, line)

            -- cmd
            msg = replace_char(12, msg, cmd)

            -- address
            msg = replace_char(10, msg, address)

            -- dtr
            dtr0 = bit.band(arg, 0xFF)
            dtr1 = bit.band(bit.rshift(arg, 8), 0xFF)
            dtr2 = bit.band(bit.rshift(arg, 16), 0xFF)

            offset = 0
            if (dtr0 >= 0x80) then
                msg = replace_char(17, msg, bit.band(dtr0, 0x7F) + 0x80)
                msg = insert_char(17, msg, bit.band(bit.rshift(dtr0, 7), 0x7F))
                offset = offset + 2
            else
                msg = replace_char(17, msg, dtr0)
                offset = offset + 1
            end

            if (dtr1 >= 0x80) then
                msg = replace_char(17 + offset, msg, bit.band(dtr1, 0x7F) + 0x80)
                msg = insert_char(17 + offset, msg, bit.band(bit.rshift(dtr1, 7), 0x7F))
                offset = offset + 2
            else
                msg = replace_char(17 + offset, msg, dtr1)
                offset = offset + 1
            end

            if (dtr2 >= 0x80) then
                msg = replace_char(17 + offset, msg, bit.band(dtr2, 0x7F) + 0x80)
                msg = insert_char(17 + offset, msg, bit.band(bit.rshift(dtr2, 7), 0x7F))
                offset = offset + 2
            else
                msg = replace_char(17 + offset, msg, dtr2)
                offset = offset + 1
            end

            -- Replace DTR Length
            msg = replace_char(16, msg, offset)
            -- Replace Data Length
            msg = replace_char(14, msg, offset + 2)
            -- Replace Data Length
            msg = replace_char(6, msg, 0x0D - 3 + offset)
            -- Replace Full Length
            msg = replace_char(3, msg, 0x10 - 3 + offset)
        else
            msg = "\xCD\x00\x0B\x92\x01\x08\x08\x01\x10\x01\x40\x02\x52\00"
            -- line
            msg = replace_char(8, msg, line)
            -- cmd
            msg = replace_char(12, msg, cmd)
            -- address
            msg = replace_char(10, msg, address)
        end
    end
    return msg
end

-- Important DALI messages (DTR0, 1, 2, Enable Type X)
function createDALISPECCommandFrame(line, speccmd, value)
    if (value <= 79) then
        if (speccmd == 0xA3) then -- DTR0
            msg = "\xCD\x00\x09\x92\x01\x06\x08\x01\x58\x85\xC6\x02"
        elseif (speccmd == 0xC1) then -- Set Type X
            msg = "\xCD\x00\x09\x92\x01\x06\x08\x01\x58\x85\x82\x03"
        elseif (speccmd == 0xC3) then -- DTR1
            msg = "\xCD\x00\x09\x92\x01\x06\x08\x01\x58\x85\x86\x03"
        elseif (speccmd == 0xC5) then -- DTR2
            msg = "\xCD\x00\x09\x92\x01\x06\x08\x01\x58\x85\x8A\x03"
        end
        msg = replace_char(8, msg, line) --Replace Line
        msg = replace_char(10, msg, value + 0x80) --Replace Value
    else
        if (speccmd == 0xA3) then -- DTR0
            msg = "\xCD\x00\x09\x92\x01\x06\x08\x01\x58\x85\xC7\x02"
        elseif (speccmd == 0xC1) then -- Set Type X
            msg = "\xCD\x00\x09\x92\x01\x06\x08\x01\x58\x85\x83\x03"
        elseif (speccmd == 0xC3) then -- DTR1
            msg = "\xCD\x00\x09\x92\x01\x06\x08\x01\x58\x85\x87\x03"
        elseif (speccmd == 0xC5) then -- DTR2
            msg = "\xCD\x00\x09\x92\x01\x06\x08\x01\x58\x85\x8B\x03"
        end
        msg = replace_char(8, msg, line) --Replace Line
        msg = replace_char(10, msg, value) --Replace Value
    end
    return msg
end

-- Function to send a single channel DMX Message
function createDMXMessage(line, channel, level, fadetime, rpt)
    if (rpt == 0) then
        rpt = 1 -- For consistency, make rpt = 1
    end
    if (fadetime == 0) then
        fadetime = 1 -- Minimum Fadetime of 10ms, also for consistency
    end

    offset = 0
    msg = "\xCD\x00\x0E\xA2\x01\x0B\x10\x01\x18\x01\x20\x01\x2A\x01\x00\x30\x01" -- Smallest Message Variant
    if (channel > 0x80) then
        msg = replace_char(10, msg, bit.band(channel, 0x7F) + 0x80)
        msg = insert_char(10, msg, bit.band(bit.rshift(channel, 7), 0x7F))
        offset = offset + 1
    else
        msg = replace_char(10, msg, channel)
    end

    if (level > 0x80) then
        msg = replace_char(15 + offset, msg, bit.band(level, 0x7F) + 0x80)
        msg = insert_char(15 + offset, msg, bit.band(bit.rshift(level, 7), 0x7F))
        offset = offset + 1
    else
        msg = replace_char(15 + offset, msg, level)
    end

    -- Fade Time
    msg = replace_char(17 + offset, msg, fadetime)

    -- Line
    msg = replace_char(8, msg, line)

    -- Replace Data Length
    msg = replace_char(6, msg, 0x0B + offset)
    -- Replace Full Length
    msg = replace_char(3, msg, 0x0E + offset)

    -- TODO Repeat
    return msg
end

-- TODO, copy above for multiple levels (RGBW and RGB)

-- Function Replaces the Nth element
function replace_char(pos, str, r)
    return str:sub(1, pos - 1) .. string.char(r) .. str:sub(pos + 1)
end

-- Function Removes the Nth element
function remove_char(pos, str)
    return str:sub(1, pos - 1) .. str:sub(pos + 1)
end

-- Function Inserts at the Nth element
function insert_char(pos, str, r)
    return str:sub(1, pos) .. string.char(r) .. str:sub(pos + 1)
end

-- Exposed Functions
function sendDALIRGBMessage(line, address, red, green, blue)
    -- Connect to Host
    tcp:connect(host, port)
    -- Get Message (Line, Address, Level) - Red
    msg = createDALIOverrideString(line, address, red)
    -- Send Message
    tcp:send(msg)
    -- Get Message (Line, Address, Level) - Green
    msg = createDALIOverrideString(line, address, green)
    -- Send Message
    tcp:send(msg)
    -- Get Message (Line, Address, Level) - Blue
    msg = createDALIOverrideString(line, address, blue)
    -- Send Message
    tcp:send(msg)
end

function sendDALIRGBDT8Message(line, address, red, green, blue, brightness)
    -- Convert RGB to XY
    X, Y = RGBToXY(red, green, blue)

    -- Send X
    sendDT8Cmd(line, address, SET_TEMP_X_COORD, X)

    -- Send Y
    sendDT8Cmd(line, address, SET_TEMP_Y_COORD, Y)

    -- Send Brightness
    sendDALIArcLevel(line, address, brightness)

    -- Activate
    sendDT8Cmd(line, address, ACTIVATE, 0)
end

function sendDALICCTMessage(line, address, kelvin, brightness)
    -- Convert Kelvin to Mirek
    mirek = 1000000 / kelvin

    -- Send CCT
    sendDT8Cmd(line, address, SET_TEMP_COLOUR_TEMP, mirek)

    -- Send Brightness
    sendDALIArcLevel(line, address, brightness)

    -- Activate
    sendDT8Cmd(line, address, ACTIVATE, 0)
end

function sendDALIArcLevel(line, address, level)
    -- Connect to Host
    tcp:connect(host, port)
    -- Get Message (Line, Address, Level)
    msg = createDALIOverrideString(line, address, level)
    -- Send Message
    tcp:send(msg)
end

function sendDALIFadeMessage(line, address, fadetime)
    -- Connect to Host
    tcp:connect(host, port)
    -- Get Message (Line, CMD, Value) - Set DTR to Fade Value
    msg = createDALISPECCommandFrame(line, 0xA3, fadetime)
    -- Send Message
    tcp:send(msg)
    -- Get Message (Line, Address, Level) - Set Fade from DTR
    msg = createDALICommandFrame(line, address, 0x2E)
    -- Send Message
    tcp:send(msg)
    -- Send Message
    tcp:send(msg)
end

function sendDALIArcLevelWithFade(line, address, level, fadetime)
    --sendDALIFadeMessage(line, address, fadetime)
    --sendDALIArcLevel(line, address, level)
end

function sendDT8Cmd(line, address, cmd, arg)
    -- Connect to Host
    tcp:connect(host, port)
    -- Get Message
    msg = createDT8Command(line, address, cmd, arg)
    -- Send Message
    tcp:send(msg)
end

function sendDMXLevel(line, channel, level, fadetime, rpt)
    -- Connect to Host
    tcp:connect(host, port)
    -- Get Message
    msg = createDMXMessage(line, channel, level, fadetime, rpt)
    -- Send Message
    tcp:send(msg)
end

function sendDMXRGBW(line, channel, red, green, blue, white, rpt)
end

-- Connection Functions
function closeConnection()
    tcp:close()
end

-- Helper Functions
-- Colour Conversion
function HSLToRGB(h, s, l)
    c = ((1.0 - math.abs(2.0 * l - 1.0)) * s)
    x = (c * (1.0 - math.abs((h / 60.0) % 2.0 - 1.0)))
    m = (l - c / 2.0)

    r = 0
    g = 0
    b = 0

    if (0 <= h and h < 60) then
        r = c
        g = x
        b = 0
    elseif (60 <= h and h < 120) then
        r = x
        g = c
        b = 0
    elseif (120 <= h and h < 180) then
        r = 0
        g = c
        b = x
    elseif (180 <= h and h < 240) then
        r = 0
        g = x
        b = c
    elseif (240 <= h and h < 300) then
        r = x
        g = 0
        b = c
    elseif (300 <= h and h <= 360) then
        r = c
        g = 0
        b = x
    end

    R = (r + m)
    G = (g + m)
    B = (b + m)

    return R, G, B
end

--[[
 Input - RGB [0 1] or [0 255]
 Output - XY [0 65535]
 --]]
function RGBToXY(R, G, B)
    if (R > 1) then
        R = R / 255
    end
    if (G > 1) then
        G = G / 255
    end
    if (B > 1) then
        B = B / 255
    end

    -- 2 Add a gamma correction
    if (R > 0.045045) then
        R = math.pow((R + 0.055) / (1.0 + 0.055), 2.4)
    else
        R = (R / 12.92)
    end

    if (G > 0.045045) then
        G = math.pow((G + 0.055) / (1.0 + 0.055), 2.4)
    else
        G = (G / 12.92)
    end

    if (B > 0.045045) then
        B = math.pow((B + 0.055) / (1.0 + 0.055), 2.4)
    else
        B = (R / 12.92)
    end

    -- 3 Convert RGB to XYZ using Wide RGB D65 Conversion
    X = R * 0.649926 + G * 0.103455 + B * 0.197109
    Y = R * 0.234327 + G * 0.743075 + B * 0.022598
    Z = R * 0.0000000 + G * 0.053077 + B * 1.035763

    -- 4 Calculate the XY values from XYZ Values
    x = 65536 * (X / (X + Y + Z))
    y = 65536 * (Y / (X + Y + Z))

    return x, y
end
