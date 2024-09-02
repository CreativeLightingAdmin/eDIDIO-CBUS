-- ENCODER FUNCTIONS
-- Function to encode a uint32 as a varint
local function encode_varint(value)
    local bytes = {}
    repeat
        local byte = bit.band(value, 0x7F)
    		value = bit.rshift(value, 7)
        if value ~= 0 then
      			byte = bit.bor(byte, 0x80)
        end
        table.insert(bytes, string.char(byte))
    until value == 0
    return table.concat(bytes)
end

-- Function to encode length delimited
local function encode_length_delimited(data)
    local length = encode_varint(#data)
    return length .. data
end

-- Function to encode a uint32 field
local function encode_uint32(field_number, value)
    local field_key = bit.bor(bit.lshift(field_number, 3), 0) -- 0 is the wire type for varint
    local field_key_encoded = encode_varint(field_key)
    local value_encoded = encode_varint(value)
    return field_key_encoded .. value_encoded
end

-- Function to encode a repeated uint32 field
local function encode_repeated_uint32(field_number, values)
    local encoded = ""
    if values then
        for _, value in ipairs(values) do
      			log(value)
            encoded = encoded .. encode_uint32(field_number, value)
        end
    end
    return encoded
end

-- Function to encode AckMessage
local function encode_ack_message(ack_message)
    local encoded_message = {}

    -- Encode ack_id
    if ack_message.ack_id then
        table.insert(encoded_message, string.char(0x08))  -- field number 1, wire type 0 (varint)
        table.insert(encoded_message, encode_varint(ack_message.ack_id))
    end

    return table.concat(encoded_message)
end

local function encode_dtr_payload_message(dtr_payload)
    return encode_repeated_uint32(10, dtr_payload)
end

-- Function to encode DALIMessage 
local function encode_dali_message(dali_message)
    local encoded_message = ""

    -- Encode line_mask
    encoded_message = encoded_message .. encode_uint32(1, dali_message.line_mask)
    
    -- Encode address
    encoded_message = encoded_message .. encode_uint32(2, dali_message.address)
    
    -- Encode the action oneof field
    if dali_message.action.frame_25_bit then
        encoded_message = encoded_message .. encode_uint32(3, dali_message.action.frame_25_bit)
    elseif dali_message.action.frame_25_bit_reply then
        encoded_message = encoded_message .. encode_uint32(4, dali_message.action.frame_25_bit_reply)
    elseif dali_message.action.command then
        encoded_message = encoded_message .. encode_uint32(5, dali_message.action.command)
    elseif dali_message.action.custom_command then
        encoded_message = encoded_message .. encode_uint32(6, dali_message.action.custom_command)
    elseif dali_message.action.query then
        encoded_message = encoded_message .. encode_uint32(7, dali_message.action.query)
    elseif dali_message.action.type8 then
        encoded_message = encoded_message .. encode_uint32(8, dali_message.action.type8)
    elseif dali_message.action.frame_16_bit then
        encoded_message = encoded_message .. encode_uint32(11, dali_message.action.frame_16_bit)
    elseif dali_message.action.frame_16_bit_reply then
        encoded_message = encoded_message .. encode_uint32(12, dali_message.action.frame_16_bit_reply)
    elseif dali_message.action.frame_24_bit then
        encoded_message = encoded_message .. encode_uint32(13, dali_message.action.frame_24_bit)
    elseif dali_message.action.frame_24_bit_reply then
        encoded_message = encoded_message .. encode_uint32(14, dali_message.action.frame_24_bit_reply)
    elseif dali_message.action.type8_reply then
        encoded_message = encoded_message .. encode_uint32(15, dali_message.action.type8_reply)
    elseif dali_message.action.device24_setting then
        encoded_message = encoded_message .. encode_uint32(16, dali_message.action.device24_setting)
    end
    
    -- Encode the params oneof field
    if dali_message.params.arg then
        encoded_message = encoded_message .. encode_uint32(9, dali_message.params.arg)
    elseif dali_message.params.dtr then
        encoded_message = encoded_message .. encode_dtr_payload_message(dali_message.params.dtr)
    end
    
    -- Encode instance_type
    encoded_message = encoded_message .. encode_uint32(17, dali_message.instance_type)
    
    -- Encode op_code
    encoded_message = encoded_message .. encode_uint32(18, dali_message.op_code)
    
    return encoded_message
end

-- Function to encode DALIQueryMessage
function encode_dali_query_response(response)
    local result = {}

    -- Deprecated Query Method (oneof payload)
    if response.status_flags then
        table.insert(result, string.char(0x08)) -- Field number 1, type 2 (length-delimited)
        local encoded_status_flags = encode_dali_status_flag_message(response.status_flags)
        table.insert(result, string.char(#encoded_status_flags)) -- Length of status_flags message
        table.insert(result, encoded_status_flags)
    elseif response.data then
        table.insert(result, string.char(0x12)) -- Field number 2, type 2 (length-delimited)
        local encoded_data = encode_payload_message(response.data)
        table.insert(result, string.char(#encoded_data)) -- Length of data message
        table.insert(result, encoded_data)
    end

    -- New Query Method
    if response.dali_flag then
        table.insert(result, string.char(0x18)) -- Field number 3, type 0 (varint)
        table.insert(result, encode_varint(response.dali_flag))
    end

    if response.response_data then
        table.insert(result, string.char(0x22)) -- Field number 4, type 2 (length-delimited)
        local encoded_response_data = encode_payload_message(response.response_data)
        table.insert(result, string.char(#encoded_response_data)) -- Length of response_data message
        table.insert(result, encoded_response_data)
    end

    return table.concat(result)
end


-- Function to encode DMXMessage
local function encode_dmx_message(dmx_message)
    local encoded_message = ""
    encoded_message = encoded_message .. encode_uint32(1, dmx_message.zone)
    encoded_message = encoded_message .. encode_uint32(2, dmx_message.universe_mask)
    encoded_message = encoded_message .. encode_uint32(3, dmx_message.channel)
    encoded_message = encoded_message .. encode_uint32(4, dmx_message.repeat_count)
    encoded_message = encoded_message .. encode_repeated_uint32(5, dmx_message.levels)
    encoded_message = encoded_message .. encode_uint32(6, dmx_message.fade_time_by_10ms)
    return encoded_message
end

-- Function to encode TriggerMessage
local function encode_trigger_message(trigger_message)
    local encoded_message = {}

    if trigger_message.type then
        table.insert(encoded_message, string.char(0x08))  -- field number 1, wire type 0
        table.insert(encoded_message, encode_varint(trigger_message.type))
    end

    if trigger_message.zone then
        table.insert(encoded_message, string.char(0x10))  -- field number 2, wire type 0
        table.insert(encoded_message, encode_varint(trigger_message.zone))
    end

    if trigger_message.line_mask then
        table.insert(encoded_message, string.char(0x18))  -- field number 3, wire type 0
        table.insert(encoded_message, encode_varint(trigger_message.line_mask))
    end

    if trigger_message.target_index then
        table.insert(encoded_message, string.char(0x20))  -- field number 4, wire type 0
        table.insert(encoded_message, encode_varint(trigger_message.target_index))
    end

    if trigger_message.value then
        table.insert(encoded_message, string.char(0x28))  -- field number 5, wire type 0
        table.insert(encoded_message, encode_varint(trigger_message.value))
    end

    if trigger_message.query_index then
        table.insert(encoded_message, string.char(0x30))  -- field number 6, wire type 0
        table.insert(encoded_message, encode_varint(trigger_message.query_index))
    end

    return table.concat(encoded_message)
end

-- Function to encode ExternalTriggerMessage
local function encode_external_trigger_message(external_trigger_message)
    local encoded_message = {}

    if external_trigger_message.trigger then
        table.insert(encoded_message, string.char(0x0A))  -- field number 1, wire type 2 (length-delimited)
        local encoded_trigger = encode_trigger_message(external_trigger_message.trigger)
        table.insert(encoded_message, encode_length_delimited(encoded_trigger))
    end

    return table.concat(encoded_message)
end

-- Function to encode the EdidioMessage
function Encode_edidio_message(edidio_message)
    local encoded_message = {}

    -- Encode message_id
    if edidio_message.message_id then
        table.insert(encoded_message, string.char(0x08))  -- field number 1, wire type 0 (varint)
        table.insert(encoded_message, encode_varint(edidio_message.message_id))
    end

    -- Encode the payload based on its type
    if edidio_message.payload then
        if edidio_message.payload.ack then
            table.insert(encoded_message, string.char(0x12))  -- field number 2, wire type 2 (length-delimited)
            -- Encode AckMessage (assuming an encode_ack_message function exists)
            local encoded_ack = encode_ack_message(edidio_message.payload.ack)
            table.insert(encoded_message, encode_length_delimited(encoded_ack))
        
        elseif edidio_message.payload.dali_message then
            table.insert(encoded_message, string.char(0x92, 0x01))  -- field number 18, wire type 2 (length-delimited)
            local encoded_dali = encode_dali_message(edidio_message.payload.dali_message)
            table.insert(encoded_message, encode_length_delimited(encoded_dali))
              
        elseif edidio_message.payload.dali_query_respose then
            table.insert(encoded_message, string.char(0xB2, 0x01))  -- field number 19, wire type 2 (length-delimited)
            local encoded_dali = encode_dali_query_response(edidio_message.payload.dali_query_response)
            table.insert(encoded_message, encode_length_delimited(encoded_dali))
      
        elseif edidio_message.payload.dmx_message then
            table.insert(encoded_message, string.char(0xA2, 0x01))  -- field number 20, wire type 2 (length-delimited)
            local encoded_dmx = encode_dmx_message(edidio_message.payload.dmx_message)
            table.insert(encoded_message, encode_length_delimited(encoded_dmx))

        elseif edidio_message.payload.external_trigger then
            table.insert(encoded_message, string.char(0xAA, 0x01))  -- field number 21, wire type 2 (length-delimited)
            local encoded_trigger = encode_external_trigger_message(edidio_message.payload.external_trigger)
            table.insert(encoded_message, encode_length_delimited(encoded_trigger))
        end
    end

    return table.concat(encoded_message)
end


function Wrap_message(encoded_message)
    -- Start byte
    local startbyte = string.char(0xCD)

    -- Calculate the length of the encoded message
    local length = #encoded_message

    -- Split length into MSB and LSB
    local length_msb = bit.band(bit.rshift(length, 8), 0xFF)
    local length_lsb = bit.band(length, 0xFF)

    -- Convert length MSB and LSB to bytes
    local length_msb_byte = string.char(length_msb)
    local length_lsb_byte = string.char(length_lsb)

    -- Concatenate all parts: startbyte, length MSB, length LSB, encoded_message
    local wrapped_message = startbyte .. length_msb_byte .. length_lsb_byte .. encoded_message

    return wrapped_message
end



-- DECODER FUNCTIONS
-- Function to decode a varint
local function varint_decode(data, pos)
    local value = 0
    local shift = 0
    local byte
    repeat
        byte = string.byte(data, pos)
        value = bit.bor(value, (bit.lshift(bit.band(byte, 0x7F), shift)))
        shift = shift + 7
        pos = pos + 1
    until byte < 0x80
    return value, pos
end

-- Function to decode a single field key (field number and wire type)
local function decode_field_key(data, pos)
    local field_key, new_pos = varint_decode(data, pos)
    local field_number = bit.rshift(field_key, 3)
    local wire_type = bit.band(field_key, 0x07)
    return field_number, wire_type, new_pos
end

-- Function to decode a length-delimited field (for embedded messages or strings)
local function decode_length_delimited(data, pos)
    local length, new_pos = varint_decode(data, pos)
    local value = string.sub(data, new_pos, new_pos + length - 1)
    return value, new_pos + length
end

-- Function to decode AckMessage
local function decode_ack_message(data)
    local pos = 1
    local ack_message = {}

    while pos <= #data do
        local field_number, wire_type, new_pos = decode_field_key(data, pos)
        pos = new_pos

        if field_number == 1 and wire_type == 0 then  -- ack_id (uint32)
            ack_message.ack_id, pos = varint_decode(data, pos)
        else
            -- Skip unknown fields
            if wire_type == 0 then  -- varint
                _, pos = varint_decode(data, pos)
            elseif wire_type == 2 then  -- length-delimited
                local length
                length, pos = varint_decode(data, pos)
                pos = pos + length
            else
                error("Unsupported wire type: " .. wire_type)
            end
        end
    end

    return ack_message
end

-- Function to decode DALIMessage
local function decode_dali_message(data)
    local pos = 1
    local dali_message = {}

    while pos <= #data do
        local field_number, wire_type, new_pos = decode_field_key(data, pos)
        pos = new_pos

        if field_number == 1 and wire_type == 0 then  -- line_mask (uint32)
            dali_message.line_mask, pos = varint_decode(data, pos)
        elseif field_number == 2 and wire_type == 0 then  -- address (uint32)
            dali_message.address, pos = varint_decode(data, pos)
        elseif field_number == 3 and wire_type == 0 then  -- frame_25_bit (uint32)
            dali_message.action = dali_message.action or {}
            dali_message.action.frame_25_bit, pos = varint_decode(data, pos)
        elseif field_number == 4 and wire_type == 0 then  -- frame_25_bit_reply (uint32)
            dali_message.action = dali_message.action or {}
            dali_message.action.frame_25_bit_reply, pos = varint_decode(data, pos)
        elseif field_number == 5 and wire_type == 0 then  -- command (DALICommandType)
            dali_message.action = dali_message.action or {}
            dali_message.action.command, pos = varint_decode(data, pos)
        elseif field_number == 6 and wire_type == 0 then  -- custom_command (CustomDALICommandType)
            dali_message.action = dali_message.action or {}
            dali_message.action.custom_command, pos = varint_decode(data, pos)
        elseif field_number == 7 and wire_type == 0 then  -- query (DALIQueryType)
            dali_message.action = dali_message.action or {}
            dali_message.action.query, pos = varint_decode(data, pos)
        elseif field_number == 8 and wire_type == 0 then  -- type8 (Type8CommandType)
            dali_message.action = dali_message.action or {}
            dali_message.action.type8, pos = varint_decode(data, pos)
        elseif field_number == 11 and wire_type == 0 then  -- frame_16_bit (uint32)
            dali_message.action = dali_message.action or {}
            dali_message.action.frame_16_bit, pos = varint_decode(data, pos)
        elseif field_number == 12 and wire_type == 0 then  -- frame_16_bit_reply (uint32)
            dali_message.action = dali_message.action or {}
            dali_message.action.frame_16_bit_reply, pos = varint_decode(data, pos)
        elseif field_number == 13 and wire_type == 0 then  -- frame_24_bit (uint32)
            dali_message.action = dali_message.action or {}
            dali_message.action.frame_24_bit, pos = varint_decode(data, pos)
        elseif field_number == 14 and wire_type == 0 then  -- frame_24_bit_reply (uint32)
            dali_message.action = dali_message.action or {}
            dali_message.action.frame_24_bit_reply, pos = varint_decode(data, pos)
        elseif field_number == 15 and wire_type == 0 then  -- type8_reply (Type8QueryType)
            dali_message.action = dali_message.action or {}
            dali_message.action.type8_reply, pos = varint_decode(data, pos)
        elseif field_number == 16 and wire_type == 0 then  -- device24_setting (DALI24DeviceSetting)
            dali_message.action = dali_message.action or {}
            dali_message.action.device24_setting, pos = varint_decode(data, pos)
        elseif field_number == 9 and wire_type == 0 then  -- arg (uint32)
            dali_message.params = dali_message.params or {}
            dali_message.params.arg, pos = varint_decode(data, pos)
        elseif field_number == 10 and wire_type == 2 then  -- dtr (DTRPayloadMessage)
            dali_message.params = dali_message.params or {}
            dali_message.params.dtr_value = dali_message.params.dtr_value or {}
            local dtr_value
            dtr_value, index = decode_uint32(encoded_message, index)
            table.insert(dali_message.params.dtr_value, dtr_value)
            table.insert(dali_message.dtr, dtr_value)
        elseif field_number == 17 and wire_type == 0 then  -- instance_type (DALI24InstanceType)
            dali_message.instance_type, pos = varint_decode(data, pos)
        elseif field_number == 18 and wire_type == 0 then  -- op_code (DALI24OpCode)
            dali_message.op_code, pos = varint_decode(data, pos)
        else
            -- Skip unknown fields
            if wire_type == 0 then  -- varint
                _, pos = varint_decode(data, pos)
            elseif wire_type == 2 then  -- length-delimited
                local length
                length, pos = varint_decode(data, pos)
                pos = pos + length
            else
                error("Unsupported wire type: " .. wire_type)
            end
        end
    end

    return dali_message
end

local function decode_dali_status_flag_message(data)
    local message = {}
    local pos = 1
    local len = #data

    while pos <= len do
        local key = data:byte(pos)
        pos = pos + 1

        local field_number = bit.rshift(key, 3)
        local wire_type = bit.band(key, 0x07)

        if field_number == 1 and wire_type == 0 then
            message.flag_status, pos = decode_varint(data, pos)
        elseif field_number == 2 and wire_type == 0 then
            message.flag_type, pos = decode_varint(data, pos)
        else
            error("Unknown field number: " .. field_number)
        end
    end

    return message
end

local function decode_payload_message(data)
    local message = {}
    local pos = 1
    local len = #data

    while pos <= len do
        local key = data:byte(pos)
        pos = pos + 1

        local field_number = bit.rshift(key, 3)
        local wire_type = bit.band(key, 0x07)

        if field_number == 1 then
            if wire_type == 0 then
                -- Decode uint32 (varint)
                message.uint_data, pos = varint_decode(data, pos)
            else
                error("Unsupported wire type for uint_data: " .. wire_type)
            end
        elseif field_number == 2 then
            if wire_type == 5 then
                -- Decode float (fixed32)
                local float_bytes = data:sub(pos, pos + 3)
                message.float_data = string.unpack("<f", float_bytes)
                pos = pos + 4
            else
                error("Unsupported wire type for float_data: " .. wire_type)
            end
        elseif field_number == 3 then
            if wire_type == 2 then
                -- Decode string (length-delimited)
                local length = data:byte(pos)
                pos = pos + 1
                message.string_data = data:sub(pos, pos + length - 1)
                pos = pos + length
            else
                error("Unsupported wire type for string_data: " .. wire_type)
            end
        else
            error("Unknown field number: " .. field_number)
        end
    end

    return message
end

-- Function to decode DALIQuery Message
local function decode_dali_query_response(data)
    local response = {}
    local pos = 1
    local len = #data

    while pos <= len do
        local key = data:byte(pos)
        pos = pos + 1

        local field_number = bit.rshift(key, 3)
        local wire_type = bit.band(key, 0x07)

        if field_number == 1 and wire_type == 2 then
            local length = data:byte(pos)
            pos = pos + 1
            response.status_flags = decode_dali_status_flag_message(data:sub(pos, pos + length - 1))
            pos = pos + length
        elseif field_number == 2 and wire_type == 2 then
            local length = data:byte(pos)
            pos = pos + 1
            response.data = decode_payload_message(data:sub(pos, pos + length - 1))
            pos = pos + length
        elseif field_number == 3 and wire_type == 0 then
            local dali_flag, new_pos = varint_decode(data, pos)
            response.dali_flag = dali_flag
            pos = new_pos
        elseif field_number == 4 and wire_type == 2 then
            local length = data:byte(pos)
            pos = pos + 1
            response.response_data = decode_payload_message(data:sub(pos, pos + length - 1))
            pos = pos + length
        else
            error("Unknown field number: " .. field_number)
        end
    end

    return response
end

-- Function to decode DMXMessage
local function decode_dmx_message(data)
    local pos = 1
    local dmx_message = {}

    while pos <= #data do
        local field_number, wire_type, new_pos = decode_field_key(data, pos)
        pos = new_pos

        if field_number == 1 and wire_type == 0 then  -- zone (uint32)
            dmx_message.zone, pos = varint_decode(data, pos)
        elseif field_number == 2 and wire_type == 0 then  -- universe_mask (uint32)
            dmx_message.universe_mask, pos = varint_decode(data, pos)
        elseif field_number == 3 and wire_type == 0 then  -- channel (uint32)
            dmx_message.channel, pos = varint_decode(data, pos)
        elseif field_number == 4 and wire_type == 0 then  -- repeat (uint32)
            dmx_message.repeat_count, pos = varint_decode(data, pos)
        elseif field_number == 5 and wire_type == 2 then  -- level (repeated uint32)
            local length
            length, pos = varint_decode(data, pos)
            local levels = {}
            local end_pos = pos + length
            while pos < end_pos do
                local level
                level, pos = varint_decode(data, pos)
                table.insert(levels, level)
            end
            dmx_message.levels = levels
        elseif field_number == 6 and wire_type == 0 then  -- fade_time_by_10ms (uint32)
            dmx_message.fade_time_by_10ms, pos = varint_decode(data, pos)
        else
            -- Skip unknown fields
            if wire_type == 0 then  -- varint
                _, pos = varint_decode(data, pos)
            elseif wire_type == 2 then  -- length-delimited
                local length
                length, pos = varint_decode(data, pos)
                pos = pos + length
            else
                error("Unsupported wire type: " .. wire_type)
            end
        end
    end

    return dmx_message
end

-- Function to decode TriggerMessage
local function decode_trigger_message(data)
    local pos = 1
    local trigger_message = {}

    while pos <= #data do
        local field_number, wire_type, new_pos = decode_field_key(data, pos)
        pos = new_pos

        if field_number == 1 and wire_type == 0 then  -- TriggerType (uint32)
            trigger_message.type, pos = varint_decode(data, pos)
        elseif field_number == 2 and wire_type == 0 then  -- zone (uint32)
            trigger_message.zone, pos = varint_decode(data, pos)
        elseif field_number == 3 and wire_type == 0 then  -- line_mask (uint32)
            trigger_message.line_mask, pos = varint_decode(data, pos)
        elseif field_number == 4 and wire_type == 0 then  -- target_index (uint32)
            trigger_message.target_index, pos = varint_decode(data, pos)
        elseif field_number == 5 and wire_type == 0 then  -- value (uint32)
            trigger_message.value, pos = varint_decode(data, pos)
        elseif field_number == 6 and wire_type == 0 then  -- query_index (uint32)
            trigger_message.query_index, pos = varint_decode(data, pos)
        else
            -- Skip unknown fields
            if wire_type == 0 then  -- varint
                _, pos = varint_decode(data, pos)
            elseif wire_type == 2 then  -- length-delimited
                local length
                length, pos = varint_decode(data, pos)
                pos = pos + length
            else
                error("Unsupported wire type: " .. wire_type)
            end
        end
    end

    return trigger_message
end

-- Function to decode ExternalTriggerMessage
local function decode_external_trigger_message(data)
    local pos = 1
    local external_trigger_message = {}

    while pos <= #data do
        local field_number, wire_type, new_pos = decode_field_key(data, pos)
        pos = new_pos

        if field_number == 1 and wire_type == 2 then  -- TriggerMessage (length-delimited)
            local message_data
            message_data, pos = decode_length_delimited(data, pos)
            external_trigger_message.trigger = decode_trigger_message(message_data)
        else
            -- Skip unknown fields
            if wire_type == 0 then  -- varint
                _, pos = varint_decode(data, pos)
            elseif wire_type == 2 then  -- length-delimited
                local length
                length, pos = varint_decode(data, pos)
                pos = pos + length
            else
                error("Unsupported wire type: " .. wire_type)
            end
        end
    end

    return external_trigger_message
end


-- Function to decode EdidioMessage
function Decode_edidio_message(data)
    local pos = 1
    local edidio_message = {}

    while pos <= #data do
        local field_number, wire_type, new_pos = decode_field_key(data, pos)
        pos = new_pos

        if field_number == 1 and wire_type == 0 then  -- message_id (uint32)
            edidio_message.message_id, pos = varint_decode(data, pos)
        
        elseif field_number == 2 and wire_type == 2 then  -- AckMessage (length-delimited)
            local message_data
            message_data, pos = decode_length_delimited(data, pos)
            edidio_message.payload = { ack = decode_ack_message(message_data) }

        elseif field_number == 18 and wire_type == 2 then  -- DALIMessage (length-delimited)
            local message_data
            message_data, pos = decode_length_delimited(data, pos)
            edidio_message.payload = { dali_message = decode_dali_message(message_data) }
      
        elseif field_number == 19 and wire_type == 2 then  -- DALIQuery (length-delimited)
            local message_data
            message_data, pos = decode_length_delimited(data, pos)
            edidio_message.payload = { dali_query = decode_dali_query_response(message_data) }
        
        elseif field_number == 20 and wire_type == 2 then  -- DMXMessage (length-delimited)
            local message_data
            message_data, pos = decode_length_delimited(data, pos)
            edidio_message.payload = { dmx_message = decode_dmx_message(message_data) }

        elseif field_number == 21 and wire_type == 2 then  -- ExternalTriggerMessage (length-delimited)
            local message_data
            message_data, pos = decode_length_delimited(data, pos)
            edidio_message.payload = { external_trigger = decode_external_trigger_message(message_data) }

        else
            -- Skip unknown fields
            if wire_type == 0 then  -- varint
                _, pos = varint_decode(data, pos)
            elseif wire_type == 2 then  -- length-delimited
                local length
                length, pos = varint_decode(data, pos)
                pos = pos + length
            else
                error("Unsupported wire type: " .. wire_type)
            end
        end
    end

    return edidio_message
end

function Unwrap_message(wrapped_message)
    -- Check if the wrapped_message is long enough to contain the start byte and length
    if #wrapped_message < 4 then
        error("Wrapped message is too short to be valid")
    end

    -- Extract the start byte
    local startbyte = string.byte(wrapped_message, 1)

    -- Validate the start byte
    if startbyte ~= 0xCD then
        error("Invalid start byte: " .. string.format("0x%X", startbyte))
    end

    -- Extract length MSB and LSB
    local length_msb = string.byte(wrapped_message, 2)
    local length_lsb = string.byte(wrapped_message, 3)

    -- Calculate the total length of the encoded message
    local expected_length = bit.lshift(length_msb, 8) + length_lsb

    -- Extract the encoded message
    local encoded_message = string.sub(wrapped_message, 4)

    -- Validate the length of the encoded message
    if #encoded_message ~= expected_length then
        error("Length mismatch: expected " .. expected_length .. ", got " .. #encoded_message)
    end

    return encoded_message
end


-- TOOLS
function PrintPairs(decoded_message)
    for k, v in pairs(decoded_message) do
        print(k, v)
    end
end

function PrintHex(data)
    for i = 1, #data do
        char = string.sub(data, i, i)
        io.write(string.format("%02x", string.byte(char)) .. " ")
    end
end

function print_bytes(data)
    -- Ensure the data is not nil
    if not data then
        log("No data to print")
        return
    end

    -- Iterate over each byte in the data
    for i = 1, #data do
        -- Get the byte and format it as a 2-digit hexadecimal value
        local byte = data:byte(i)
        log(string.format("%02X ", byte))

        -- Print a newline every 16 bytes for readability
        if i % 16 == 0 then
            log()
        end
    end

    -- Print a newline if the last line does not end with one
    if #data % 16 ~= 0 then
        log()
    end
end

function GetMessageID()
    return (MessageId + 1);
end

MessageId = 0

-- ENUMS/DEFINITIONS
--ENUMs
-- Lines
LINE_1 = 1
LINE_2 = 2
LINE_3 = 4
LINE_4 = 8

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

-- Fade Time
DALI_NO_FADE = 0
DALI_0_7s_FADE = 1
DALI_1_0s_FADE = 2
DALI_1_4s_FADE = 3
DALI_2_0s_FADE = 4
DALI_2_8s_FADE = 5
DALI_4_0s_FADE = 6
DALI_5_7s_FADE = 7
DALI_8_0s_FADE = 8
DALI_11_3s_FADE = 9
DALI_16_0s_FADE = 10
DALI_22_6s_FADE = 11
DALI_32_0s_FADE = 12
DALI_45_3s_FADE = 13
DALI_64_0s_FADE = 14
DALI_90_5s_FADE = 15

-- Type 8
SET_TEMP_X_COORD = 0
SET_TEMP_Y_COORD = 1
ACTIVATE = 2
SET_TEMP_COLOUR_TEMP = 7
COLOUR_TEMP_COOLER = 8
COLOUR_TEMP_WARMER = 9

-- ACK
DECODE_FAILED                  = 0  -- May indicate an issue with the protocol (e.g. a mismatch in expected fields between clients). Ensure both parties are using the latest version.
INDEX_OUT_OF_BOUNDS            = 1  -- A resource was requested beyond the amount available.
UNEXPECTED_TYPE                = 2  -- The provided message was not able to be handled or processed (likely due to a lack of enough information or incorrect values).
ENCODE_FAILED                  = 3  -- Not currently in use.
KEY_MISMATCH                   = 4  -- Not currently in use.
SUCCESS                        = 5  -- The message was decoded and handled successfully.
INVALID_PARAMS                 = 6  -- The message was decoded but had invalid data for the intended outcome.
UNEXPECTED_COMMAND             = 7  -- The message was decoded but the requested action was not valid for current the state of the device.
COMMUNICATION_FAILED           = 8  -- The message could not be received or sent due to an internal issue.
COMMUNICATION_TIMEOUT          = 9  -- May indicate contention for a shared resource or that an existing task is taking longer than expected and the latest request has timed-out.
DATA_TOO_LONG                  = 10 -- May indicate too much data was in the request or the required reply would be too big to handle.
UNEXPECTED_CASE                = 11 -- May indicate that the message is out of context (e.g. an "end" command for a process that is not running) or that the message requests a feature that is not yet implemented.
SLOTS_FULL                     = 12 -- Typically indicates that a request was valid, but the relevant content is "full" and thus elements must be removed before continuing.
UNAUTHORISED                   = 13 -- The message could not be actioned because the connection has not been authorised.
PARTIAL_SUCCESS                = 14 -- Can be returned in the case where some but not all Lines in a line_mask successfully sent
COMMAND_FAILED                 = 15 -- For whatever reason, the intended command did not complete
DEPRECATED                     = 16 -- For message which is no longer supported by this Firmware

-- DALI Query Response
WAITING                     = 0 -- Internal Idle State - Should not be received
RECEIVING_FRAME             = 1 -- DALI Frame being Received
NO_RECEIVED_FRAME           = 2 -- Frame was recorded - Empty Data
RECEIVED_8_BIT_FRAME        = 3 -- Frame was recorded - 8 Bit Reply
RECEIVED_16_BIT_FRAME       = 4 -- Frame was recorded - 16 Bit - Standard Message
RECEIVED_24_BIT_FRAME       = 5 -- Frame was recorded - 24 Bit - eDALI Message
RECEIVED_PARTIAL_FRAME    	= 6 -- Frame was recorded - Unusual Bit count
IDLE                        = 7 -- DALI System Idle
CALIBRATION                 = 8 -- Inhouse DALI Calibration
ERROR_WHILE_SENDING         = 254 -- Error while trying to Transmit DALI - Possibly no Bus Power
ERROR_WHILE_RECEIVING       = 255 -- Error while trying to Receive - Invalid Frame Data, or no response