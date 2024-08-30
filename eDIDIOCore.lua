require("user.eDIDIOLuaProtoc")

local socket = require("socket")
local tcp = assert(socket.tcp())

-- Define the EDIDIO Class/module
EDIDIO = {}
EDIDIO.__index = EDIDIO

function EDIDIO.new(edidio)
    local instance = setmetatable({}, EDIDIO)
    instance.ip = edidio.ip
    return instance
end

-- TODOs
-- DMX Message - Needs Testing
-- DMX Colour - Do we do this, or just do 3/4 times DMX Message
-- DALI DT8 CCT - Working, test with light
-- DALI DT8 Colour - Working, test with light

-- This Function as a basic protocol buffer - Uses Override type for sensors
function createDALIArcLevel(line, address, level) -- DALI Arc Override Command
    -- TODO override flag
    local edidio_message = {
        message_id = GetMessageID(),
        payload = {
            dali_message = {
                line_mask = line,
                address = address,
                action = {custom_command = 0},
                params = {arg = level},
                instance_type = 0,
                op_code = 0
            }
        }
    }

    -- Encode the EdidioMessage
    local encoded_message = Encode_edidio_message(edidio_message)

    -- Wrap the encoded message with the required format
    return Wrap_message(encoded_message)
end

-- This Function will create a message to query the DALI Line
function createDALIQuery(line, address, cmd)
    local edidio_message = {
        message_id = GetMessageID(),
        payload = {
            dali_message = {
                line_mask = line,
                address = address,
                action = {query = cmd},
                params = {0},
                instance_type = 0,
                op_code = 0
            }
        }
    }

    -- Encode the EdidioMessage
    local encoded_message = Encode_edidio_message(edidio_message)

    -- Wrap the encoded message with the required format
    return Wrap_message(encoded_message)
end

-- DALI Frame Message.
function createDALICommandFrame(line, address, command)
    local edidio_message = {
        message_id = GetMessageID(),
        payload = {
            dali_message = {
                line_mask = line,
                address = address,
                action = {command = command},
                params = {arg = 0},
                instance_type = 0,
                op_code = 0
            }
        }
    }

    -- Encode the EdidioMessage
    local encoded_message = Encode_edidio_message(edidio_message)

    -- Wrap the encoded message with the required format
    return Wrap_message(encoded_message)
end

-- Creates a DT8 Message. Suits X/Y Coords, Temp, Activate, Warmer/Cooler
function createDT8Command(line, address, cmd, arg)
    local edidio_message = {
        message_id = GetMessageID(),
        payload = {
            dali_message = {
                line_mask = line,
                address = address,
                action = {type8 = cmd},
                params = {arg = arg},
                instance_type = 0,
                op_code = 0
            }
        }
    }

    -- Encode the EdidioMessage
    local encoded_message = Encode_edidio_message(edidio_message)

    -- Wrap the encoded message with the required format
    return Wrap_message(encoded_message)
end

-- Important DALI messages (DTR0, 1, 2, Enable Type X)
function createDALISPECCommandFrame(line, spec, value)
    local edidio_message = {
        message_id = GetMessageID(),
        payload = {
            dali_message = {
                line_mask = line,
                address = 0x20,
                action = {frame_16_bit = bit.bor(bit.lshift(spec, 8), value)},
                params = {arg = 0},
                instance_type = 0,
                op_code = 0
            }
        }
    }

    -- Encode the EdidioMessage
    local encoded_message = Encode_edidio_message(edidio_message)

    -- Wrap the encoded message with the required format
    return Wrap_message(encoded_message)
end

-- Function to send DMX
function createDMXMessage(line, channel, level, fadetime, rpt)
    local edidio_message = {
        message_id = GetMessageID(),
        payload = {
            dmx_message = {
                zone = 0xFF,
                universe_mask = line,
                channel = channel,
                repeat_count = rpt,
                levels = level,
                fade_time_by_10ms = fadetime
            }
        }
    }

    -- Encode the EdidioMessage
    local encoded_message = Encode_edidio_message(edidio_message)

    -- Wrap the encoded message with the required format
    return Wrap_message(encoded_message)
end

-- Exposed Functions
function EDIDIO:sendDALIRGBMessage(line, address, red, green, blue)
    -- Connect to Host
    tcp:connect(self.ip, 23)
    -- Get Message (Line, Address, Level) - Red
    msg = createDALIArcLevel(line, address, red)
    -- Send Message
    tcp:send(msg)
    -- Get Message (Line, Address, Level) - Green
    msg = createDALIArcLevel(line, address, green)
    -- Send Message
    tcp:send(msg)
    -- Get Message (Line, Address, Level) - Blue
    msg = createDALIArcLevel(line, address, blue)
    -- Send Message
    tcp:send(msg)
end

function EDIDIO:sendDALIRGBDT8Message(line, address, red, green, blue, brightness)
    -- Convert RGB to XY
    X, Y = RGBToXY(red, green, blue)

    -- Send X
    self:sendDT8Cmd(line, address, SET_TEMP_X_COORD, X)

    -- Send Y
    self:sendDT8Cmd(line, address, SET_TEMP_Y_COORD, Y)

    -- Send Brightness
    self:sendDALIArcLevel(line, address, brightness)

    -- Activate
    self:sendDT8Cmd(line, address, ACTIVATE, 0)
end

function EDIDIO:sendDALICCTDT8Message(line, address, kelvin, brightness)
    -- Convert Kelvin to Mirek
    mirek = 1000000 / kelvin

    -- Send CCT
    self:sendDT8Cmd(line, address, SET_TEMP_COLOUR_TEMP, mirek)

    -- Send Brightness
    self:sendDALIArcLevel(line, address, brightness)

    -- Activate
    self:sendDT8Cmd(line, address, ACTIVATE, 0)
end

function EDIDIO:sendDALIArcLevel(line, address, level)
    -- Connect to Host
    tcp:connect(self.ip, 23)
    tcp:settimeout(5)
    -- Get Message (Line, Address, Level)
    msg = createDALIArcLevel(line, address, level)
    -- Send Message
    tcp:send(msg)

    -- Get Response
    local decoded_message = getReply()

    tcp:close()

    -- Handle Reply - Looking for Success
    if decoded_message then
        if decoded_message.payload.ack then
            if decoded_message.payload.ack.ack_id == SUCCESS then
                return "Success"
            end
        end
    end
    return "Failed"
end

function EDIDIO:sendDALIFadeMessage(line, address, fadetime)
    -- Connect to Host
    tcp:connect(self.ip, 23)
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

    -- Get Response
    local decoded_message = getReply()

    tcp:close()

    -- Handle Reply - Looking for Success
    if decoded_message then
        if decoded_message.payload.ack then
            if decoded_message.payload.ack.ack_id == SUCCESS then
                return "Success"
            end
        end
    end
    return "Failed"
end

function EDIDIO:sendDALIArcLevelWithFade(line, address, level, fadetime)
    self.sendDALIFadeMessage(line, address, fadetime)
    return self.sendDALIArcLevel(line, address, level)
end

function EDIDIO:sendDT8Cmd(line, address, cmd, arg)
    -- Connect to Host
    tcp:connect(self.ip, 23)
    -- Get Message
    msg = createDT8Command(line, address, cmd, arg)
    -- Send Message
    tcp:send(msg)

    -- Get Response
    local decoded_message = getReply()

    tcp:close()

    -- Handle Reply - Looking for Success
    if decoded_message then
        if decoded_message.payload.ack then
            if decoded_message.payload.ack.ack_id == SUCCESS then
                return "Success"
            end
        end
    end
    return "Failed"
end

function EDIDIO:getDALILevel(line, address)
    -- Connect to Host
    tcp:connect(self.ip, 23)
    -- Get Message
    msg = createDALIQuery(line, address, 0xA0)
    -- Send Message
    tcp:send(msg)

    -- Get Response
    local decoded_message = getReply()

    tcp:close()

    -- Handle Reply - Looking for DALI Message
    if decoded_message then
        if decoded_message.payload.ack then
            if decoded_message.payload.ack.ack_id == SUCCESS then
                return "Success" -- Should not happen for GetDALILevel
            elseif decoded_message.payload.ack.ack_id == INVALID_PARAMS then
                return "Invalid Parameters"
            end
        elseif decoded_message.payload.dali_query then
            if decoded_message.payload.dali_query.dali_flag == RECEIVED_8_BIT_FRAME then
                return "Valid DALI Response", decoded_message.payload.dali_query.response_data.uint_data
            else
                return "Bad DALI Response"
            end
        end
    end
    return "Failed"
end

function EDIDIO:sendDMXLevels(line, channel, level, fadetime, rpt)
    -- Connect to Host
    tcp:connect(self.ip, 23)
    -- Get Message
    msg = createDMXMessage(line, channel, level, fadetime, rpt)
    -- Send Message
    tcp:send(msg)
end

function EDIDIO:sendDMXRGBW(line, channel, red, green, blue, white, fadetime, rpt)
    -- Connect to Host
    tcp:connect(self.ip, 23)
    -- Get Message
    msg = createDMXMessage(line, channel, {red, green, blue, white}, fadetime, rpt)
    -- Send Message
    tcp:send(msg)

    -- Get Response
    local decoded_message = getReply()

    tcp:close()

    -- Handle Reply - Looking for Success
    if decoded_message then
        if decoded_message.payload.ack then
            if decoded_message.payload.ack.ack_id == SUCCESS then
                return "Success"
            end
        end
    end
    return "Failed"
end

-- Connection Functions
function closeConnection()
    tcp:close()
end

function getReply()
    -- Receive the first 3 bytes
    local header, err, partial = tcp:receive(3)

    if not header then
        --log("Failed to receive header:", err)
        return nil
    end

    -- Extract the 2nd and 3rd bytes to determine the length
    local byte2 = header:byte(2)
    local byte3 = header:byte(3)
    local length = byte2 * 256 + byte3 -- Combine the two bytes to form the length

    --log("Message Length:", length)

    -- Receive the rest of the message based on the extracted length
    local body, err, partial = tcp:receive(length)

    if not body then
        log("Failed to receive the full message:", err)
        return nil
    end

    --log("Received body:", body)

    return Decode_edidio_message(body)
end

-- Example Get Reply Decode
--if decoded_message then
--  if decoded_message.payload.dali_message then
--     log("DALI Message:", decoded_message.payload.dali_message)
--     PrintPairs(decoded_message.payload.dali_message);
--  elseif decoded_message.payload.dmx_message then
--     log("DMX Message:", decoded_message.payload.dmx_message)
--     PrintPairs(decoded_message.payload.dmx_message);
--  elseif decoded_message.payload.trigger_message then
--     log("Trigger Message:", decoded_message.payload.trigger_message)
--     PrintPairs(decoded_message.payload.trigger_message);
--  elseif decoded_message.payload.ack then
--     log("Ack Message:", decoded_message.payload.ack)
--     PrintPairs(decoded_message.payload.ack);
--  end
--end

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
