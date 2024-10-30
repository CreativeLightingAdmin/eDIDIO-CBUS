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

-- Helper function to encode a float to bytes
function float_encode(value)

    local int = math.floor(value * 2^23 + 0.5)  -- Convert float to integer representation
    local bytes = {}

    -- Extract bytes from the integer representation
    for i = 1, 4 do
        bytes[i] = bit.band(int, 0xFF)  -- Get the last byte
        int = bit.rshift(int, 8)  -- Shift right
    end

    return string.char(unpack(bytes))  -- Convert to string
end

-- Function to encode AckMessage
local function encode_ack_message(ack_message)
    local encoded_message = {}

    -- Encode ack_id
    if ack_message.ack_id then
        table.insert(encoded_message, string.char(0x08)) -- field number 1, wire type 0 (varint)
        table.insert(encoded_message, encode_varint(ack_message.ack_id))
    end

    return table.concat(encoded_message)
end

local function encode_dtr_payload_message(dtr_values)
    -- It should be 0x52, length Right, 0x0A, length Dtr, dtr
    local dtr_data = ""
    for _, value in ipairs(dtr_values) do
        -- Each DTR value can be up to 3 bytes depending on the DALI version

        dtr_data = dtr_data .. encode_varint(value)
    end

    -- Calculate the length of the dtr_data
    local lengthDtr = #dtr_data
    --print("Encoded length:", lengthDtr)  -- Should print `3` for this example

    -- Encode the length as a varint
    local length_encoded = encode_varint(lengthDtr)

    -- Return the length-prefixed data
    return encode_varint(0x52) ..
        encode_varint(lengthDtr + 2) .. encode_varint(0x0A) .. encode_varint(lengthDtr) .. dtr_data
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
        table.insert(encoded_message, string.char(0x08)) -- field number 1, wire type 0
        table.insert(encoded_message, encode_varint(trigger_message.type))
    end

    if trigger_message.zone then
        table.insert(encoded_message, string.char(0x10)) -- field number 2, wire type 0
        table.insert(encoded_message, encode_varint(trigger_message.zone))
    end

    if trigger_message.line_mask then
        table.insert(encoded_message, string.char(0x18)) -- field number 3, wire type 0
        table.insert(encoded_message, encode_varint(trigger_message.line_mask))
    end

    if trigger_message.target_index then
        table.insert(encoded_message, string.char(0x20)) -- field number 4, wire type 0
        table.insert(encoded_message, encode_varint(trigger_message.target_index))
    end

    if trigger_message.value then
        table.insert(encoded_message, string.char(0x28)) -- field number 5, wire type 0
        table.insert(encoded_message, encode_varint(trigger_message.value))
    end

    if trigger_message.query_index then
        table.insert(encoded_message, string.char(0x30)) -- field number 6, wire type 0
        table.insert(encoded_message, encode_varint(trigger_message.query_index))
    end

    return table.concat(encoded_message)
end

-- Function to encode ExternalTriggerMessage
local function encode_external_trigger_message(external_trigger_message)
    local encoded_message = {}

    if external_trigger_message.trigger then
        table.insert(encoded_message, string.char(0x0A)) -- field number 1, wire type 2 (length-delimited)
        local encoded_trigger = encode_trigger_message(external_trigger_message.trigger)
        table.insert(encoded_message, encode_length_delimited(encoded_trigger))
    end

    return table.concat(encoded_message)
end

-- Function to encode DALICommandType
local function encode_dali_command_type(dali_command)
    local encoded_command = {}

    -- Check if the provided command is valid
    if dali_command >= 0 and dali_command <= 267 then
        -- Start with the field number (1) and wire type (0 - varint)
        table.insert(encoded_command, string.char(0x08))  -- Field number 1 (DALI Command Type), wire type 0 (varint)
        table.insert(encoded_command, encode_varint(dali_command)) -- Encode the command itself
    else
        error("Invalid DALI Command Type: " .. tostring(dali_command))
    end

    return table.concat(encoded_command)
end

-- Function to encode TriggerEvent
local function encode_trigger_event(trigger_event)
    local encoded_trigger = {}

    -- Encode type (TriggerType as varint)
    if trigger_event.type then
        table.insert(encoded_trigger, string.char(0x08))  -- field number 1, wire type 0 (varint)
        table.insert(encoded_trigger, encode_varint(trigger_event.type))
    end

    -- Encode payload based on its type (oneof)
    if trigger_event.payload then
        if trigger_event.payload.level then
            table.insert(encoded_trigger, string.char(0x10))  -- field number 2, wire type 0 (varint)
            table.insert(encoded_trigger, encode_varint(trigger_event.payload.level))
        elseif trigger_event.payload.dali_command then
            table.insert(encoded_trigger, string.char(0x1A))  -- field number 3, wire type 2 (length-delimited)
            local encoded_dali_command = encode_dali_command_type(trigger_event.payload.dali_command)
            table.insert(encoded_trigger, encode_length_delimited(encoded_dali_command))
        end
    end

    -- Encode target_address (as varint)
    if trigger_event.target_address then
        table.insert(encoded_trigger, string.char(0x20))  -- field number 4, wire type 0 (varint)
        table.insert(encoded_trigger, encode_varint(trigger_event.target_address))
    end

    -- Encode line_mask (as varint)
    if trigger_event.line_mask then
        table.insert(encoded_trigger, string.char(0x28))  -- field number 5, wire type 0 (varint)
        table.insert(encoded_trigger, encode_varint(trigger_event.line_mask))
    end

    -- Encode zone (as varint)
    if trigger_event.zone then
        table.insert(encoded_trigger, string.char(0x30))  -- field number 6, wire type 0 (varint)
        table.insert(encoded_trigger, encode_varint(trigger_event.zone))
    end

    -- Encode value (as varint)
    if trigger_event.value then
        table.insert(encoded_trigger, string.char(0x38))  -- field number 7, wire type 0 (varint)
        table.insert(encoded_trigger, encode_varint(trigger_event.value))
    end

    -- Encode query_index (as varint)
    if trigger_event.query_index then
        table.insert(encoded_trigger, string.char(0x40))  -- field number 8, wire type 0 (varint)
        table.insert(encoded_trigger, encode_varint(trigger_event.query_index))
    end

    -- Encode source (as varint)
    if trigger_event.source then
        table.insert(encoded_trigger, string.char(0x48))  -- field number 9, wire type 0 (varint)
        table.insert(encoded_trigger, encode_varint(trigger_event.source))
    end

    return table.concat(encoded_trigger)
end

-- Function to encode InputStateResponse
local function encode_input_state_response(input_id, state)
    local encoded_response = {}

    -- Field number for input_id is 1 (varint)
    table.insert(encoded_response, string.char(0x08))  -- Field number 1
    table.insert(encoded_response, encode_varint(input_id))  -- Encode input_id

    -- Field number for state is 2 (varint)
    table.insert(encoded_response, string.char(0x10))  -- Field number 2
    table.insert(encoded_response, encode_varint(state))  -- Encode state

    return table.concat(encoded_response)
end

-- Function to encode DALI Sensor Event
local function encode_dali_sensor_event(sensor_id, value)
    local encoded_event = {}

    -- Field number for sensor_id is 1 (varint)
    table.insert(encoded_event, string.char(0x08))  -- Field number 1
    table.insert(encoded_event, encode_varint(sensor_id))  -- Encode sensor_id

    -- Field number for value is 2 (varint)
    table.insert(encoded_event, string.char(0x10))  -- Field number 2
    table.insert(encoded_event, encode_varint(value))  -- Encode value

    return table.concat(encoded_event)
end

-- Function to encode DALI 24 Input Event
local function encode_dali_24_input_event(input_id, value)
    local encoded_event = {}

    -- Field number for input_id is 1 (varint)
    table.insert(encoded_event, string.char(0x08))  -- Field number 1
    table.insert(encoded_event, encode_varint(input_id))  -- Encode input_id

    -- Field number for value is 2 (varint)
    table.insert(encoded_event, string.char(0x10))  -- Field number 2
    table.insert(encoded_event, encode_varint(value))  -- Encode value

    return table.concat(encoded_event)
end

local function encode_event_filter(event_filter)
    local encoded_message = {}

    -- Encode boolean fields
    if event_filter.input ~= nil then
        table.insert(encoded_message, string.char(0x08)) -- field number for input, wire type 0 (varint)
        table.insert(encoded_message, encode_varint(event_filter.input and 1 or 0)) -- Encode as 1 for true, 0 for false
    end

    if event_filter.dali_arc_level ~= nil then
        table.insert(encoded_message, string.char(0x10)) -- field number for dali_arc_level, wire type 0 (varint)
        table.insert(encoded_message, encode_varint(event_filter.dali_arc_level and 1 or 0)) -- Encode as 1 for true, 0 for false
    end

    if event_filter.dali_command ~= nil then
        table.insert(encoded_message, string.char(0x18)) -- field number for dali_command, wire type 0 (varint)
        table.insert(encoded_message, encode_varint(event_filter.dali_command and 1 or 0)) -- Encode as 1 for true, 0 for false
    end

    if event_filter.dali_sensor ~= nil then
        table.insert(encoded_message, string.char(0x20)) -- field number for dali_sensor, wire type 0 (varint)
        table.insert(encoded_message, encode_varint(event_filter.dali_sensor and 1 or 0)) -- Encode as 1 for true, 0 for false
    end

    if event_filter.dali_input ~= nil then
        table.insert(encoded_message, string.char(0x28)) -- field number for dali_input, wire type 0 (varint)
        table.insert(encoded_message, encode_varint(event_filter.dali_input and 1 or 0)) -- Encode as 1 for true, 0 for false
    end

    if event_filter.dmx_stream_changed ~= nil then
        table.insert(encoded_message, string.char(0x30)) -- field number for dmx_stream_changed, wire type 0 (varint)
        table.insert(encoded_message, encode_varint(event_filter.dmx_stream_changed and 1 or 0)) -- Encode as 1 for true, 0 for false
    end

    if event_filter.dali_24_frame ~= nil then
        table.insert(encoded_message, string.char(0x38)) -- field number for dali_24_frame, wire type 0 (varint)
        table.insert(encoded_message, encode_varint(event_filter.dali_24_frame and 1 or 0)) -- Encode as 1 for true, 0 for false
    end

    if event_filter.trigger_message ~= nil then
        table.insert(encoded_message, string.char(0x40)) -- field number for trigger_message, wire type 0 (varint)
        table.insert(encoded_message, encode_varint(event_filter.trigger_message and 1 or 0)) -- Encode as 1 for true, 0 for false
    end

    -- Return the concatenated encoded message
    return table.concat(encoded_message)
end

local function encode_dali_24_frame_event(dali_24_frame_event)
    local encoded_message = {}

    -- Encode line
    table.insert(encoded_message, string.char(0x08)) -- field number for line, wire type 0 (varint)
    table.insert(encoded_message, encode_varint(dali_24_frame_event.line)) -- Encode as varint

    -- Encode frame
    table.insert(encoded_message, string.char(0x10)) -- field number for frame, wire type 0 (varint)
    table.insert(encoded_message, encode_varint(dali_24_frame_event.frame)) -- Encode as varint

    -- Return the concatenated encoded message
    return table.concat(encoded_message)
end

-- Function to encode the EventMessage
local function encode_event_message(event_message)
    local encoded_message = {}

    -- Encode the event field (EventType as a varint)
    if event_message.event then
        table.insert(encoded_message, string.char(0x08))  -- field number 1, wire type 0 (varint)
        table.insert(encoded_message, encode_varint(event_message.event))
    end

    -- Encode the event_data based on the type of event_data
    if event_message.event_data then
        if event_message.event_data.trigger then
            table.insert(encoded_message, string.char(0x12))  -- field number 2, wire type 2 (length-delimited)
            local encoded_trigger = encode_trigger_event(event_message.event_data.trigger)
            table.insert(encoded_message, encode_length_delimited(encoded_trigger))
        elseif event_message.event_data.inputs then
            table.insert(encoded_message, string.char(0x1A))  -- field number 3, wire type 2 (length-delimited)
            local encoded_inputs = encode_input_state_response(event_message.event_data.inputs)
            table.insert(encoded_message, encode_length_delimited(encoded_inputs))
        elseif event_message.event_data.payload then
            table.insert(encoded_message, string.char(0x22))  -- field number 4, wire type 2 (length-delimited)
            local encoded_payload = encode_payload_message(event_message.event_data.payload)
            table.insert(encoded_message, encode_length_delimited(encoded_payload))
        elseif event_message.event_data.sensor then
            table.insert(encoded_message, string.char(0x32))  -- field number 6, wire type 2 (length-delimited)
            local encoded_sensor = encode_dali_sensor_event(event_message.event_data.sensor)
            table.insert(encoded_message, encode_length_delimited(encoded_sensor))
        elseif event_message.event_data.dali_24_input then
            table.insert(encoded_message, string.char(0x3A))  -- field number 7, wire type 2 (length-delimited)
            local encoded_dali_24_input = encode_dali_24_input_event(event_message.event_data.dali_24_input)
            table.insert(encoded_message, encode_length_delimited(encoded_dali_24_input))
        elseif event_message.event_data.filter then
            table.insert(encoded_message, string.char(0x42))  -- field number 8, wire type 2 (length-delimited)
            local encoded_filter = encode_event_filter(event_message.event_data.filter)
            table.insert(encoded_message, encode_length_delimited(encoded_filter))
        elseif event_message.event_data.dali_24_frame then
            table.insert(encoded_message, string.char(0x4A))  -- field number 9, wire type 2 (length-delimited)
            local encoded_dali_24_frame = encode_dali_24_frame_event(event_message.event_data.dali_24_frame)
            table.insert(encoded_message, encode_length_delimited(encoded_dali_24_frame))
        end
    end

    return table.concat(encoded_message)
end


-- Function to encode the EdidioMessage
function Encode_edidio_message(edidio_message)
    local encoded_message = {}

    -- Encode message_id
    if edidio_message.message_id then
        table.insert(encoded_message, string.char(0x08)) -- field number 1, wire type 0 (varint)
        table.insert(encoded_message, encode_varint(edidio_message.message_id))
    end

    -- Encode the payload based on its type
    if edidio_message.payload then
        if edidio_message.payload.ack then
            table.insert(encoded_message, string.char(0x12)) -- field number 2, wire type 2 (length-delimited)
            -- Encode AckMessage (assuming an encode_ack_message function exists)
            local encoded_ack = encode_ack_message(edidio_message.payload.ack)
            table.insert(encoded_message, encode_length_delimited(encoded_ack))
        elseif edidio_message.payload.dali_message then
            table.insert(encoded_message, string.char(0x92, 0x01)) -- field number 18, wire type 2 (length-delimited)
            local encoded_dali = encode_dali_message(edidio_message.payload.dali_message)
            table.insert(encoded_message, encode_length_delimited(encoded_dali))
        elseif edidio_message.payload.dali_query_respose then
            table.insert(encoded_message, string.char(0xB2, 0x01)) -- field number 19, wire type 2 (length-delimited)
            local encoded_dali = encode_dali_query_response(edidio_message.payload.dali_query_response)
            table.insert(encoded_message, encode_length_delimited(encoded_dali))
        elseif edidio_message.payload.dmx_message then
            table.insert(encoded_message, string.char(0xA2, 0x01)) -- field number 20, wire type 2 (length-delimited)
            local encoded_dmx = encode_dmx_message(edidio_message.payload.dmx_message)
            table.insert(encoded_message, encode_length_delimited(encoded_dmx))
        elseif edidio_message.payload.external_trigger then
            table.insert(encoded_message, string.char(0xAA, 0x01)) -- field number 21, wire type 2 (length-delimited)
            local encoded_trigger = encode_external_trigger_message(edidio_message.payload.external_trigger)
            table.insert(encoded_message, encode_length_delimited(encoded_trigger))
        elseif edidio_message.payload.event_message then
            table.insert(encoded_message, string.char(0x92, 0x02))  -- field number 34, wire type 2 (length-delimited)
            local encoded_event = encode_event_message(edidio_message.payload.event_message)
            table.insert(encoded_message, encode_length_delimited(encoded_event))        
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

        if field_number == 1 and wire_type == 0 then -- ack_id (uint32)
            ack_message.ack_id, pos = varint_decode(data, pos)
        else
            -- Skip unknown fields
            if wire_type == 0 then -- varint
                _, pos = varint_decode(data, pos)
            elseif wire_type == 2 then -- length-delimited
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

        if field_number == 1 and wire_type == 0 then -- line_mask (uint32)
            dali_message.line_mask, pos = varint_decode(data, pos)
        elseif field_number == 2 and wire_type == 0 then -- address (uint32)
            dali_message.address, pos = varint_decode(data, pos)
        elseif field_number == 3 and wire_type == 0 then -- frame_25_bit (uint32)
            dali_message.action = dali_message.action or {}
            dali_message.action.frame_25_bit, pos = varint_decode(data, pos)
        elseif field_number == 4 and wire_type == 0 then -- frame_25_bit_reply (uint32)
            dali_message.action = dali_message.action or {}
            dali_message.action.frame_25_bit_reply, pos = varint_decode(data, pos)
        elseif field_number == 5 and wire_type == 0 then -- command (DALICommandType)
            dali_message.action = dali_message.action or {}
            dali_message.action.command, pos = varint_decode(data, pos)
        elseif field_number == 6 and wire_type == 0 then -- custom_command (CustomDALICommandType)
            dali_message.action = dali_message.action or {}
            dali_message.action.custom_command, pos = varint_decode(data, pos)
        elseif field_number == 7 and wire_type == 0 then -- query (DALIQueryType)
            dali_message.action = dali_message.action or {}
            dali_message.action.query, pos = varint_decode(data, pos)
        elseif field_number == 8 and wire_type == 0 then -- type8 (Type8CommandType)
            dali_message.action = dali_message.action or {}
            dali_message.action.type8, pos = varint_decode(data, pos)
        elseif field_number == 11 and wire_type == 0 then -- frame_16_bit (uint32)
            dali_message.action = dali_message.action or {}
            dali_message.action.frame_16_bit, pos = varint_decode(data, pos)
        elseif field_number == 12 and wire_type == 0 then -- frame_16_bit_reply (uint32)
            dali_message.action = dali_message.action or {}
            dali_message.action.frame_16_bit_reply, pos = varint_decode(data, pos)
        elseif field_number == 13 and wire_type == 0 then -- frame_24_bit (uint32)
            dali_message.action = dali_message.action or {}
            dali_message.action.frame_24_bit, pos = varint_decode(data, pos)
        elseif field_number == 14 and wire_type == 0 then -- frame_24_bit_reply (uint32)
            dali_message.action = dali_message.action or {}
            dali_message.action.frame_24_bit_reply, pos = varint_decode(data, pos)
        elseif field_number == 15 and wire_type == 0 then -- type8_reply (Type8QueryType)
            dali_message.action = dali_message.action or {}
            dali_message.action.type8_reply, pos = varint_decode(data, pos)
        elseif field_number == 16 and wire_type == 0 then -- device24_setting (DALI24DeviceSetting)
            dali_message.action = dali_message.action or {}
            dali_message.action.device24_setting, pos = varint_decode(data, pos)
        elseif field_number == 9 and wire_type == 0 then -- arg (uint32)
            dali_message.params = dali_message.params or {}
            dali_message.params.arg, pos = varint_decode(data, pos)
        elseif field_number == 10 and wire_type == 2 then -- dtr (DTRPayloadMessage)
            dali_message.params = dali_message.params or {}
            dali_message.params.dtr_value = dali_message.params.dtr_value or {}
            local dtr_value
            dtr_value, index = decode_uint32(encoded_message, index)
            table.insert(dali_message.params.dtr_value, dtr_value)
            table.insert(dali_message.dtr, dtr_value)
        elseif field_number == 17 and wire_type == 0 then -- instance_type (DALI24InstanceType)
            dali_message.instance_type, pos = varint_decode(data, pos)
        elseif field_number == 18 and wire_type == 0 then -- op_code (DALI24OpCode)
            dali_message.op_code, pos = varint_decode(data, pos)
        else
            -- Skip unknown fields
            if wire_type == 0 then -- varint
                _, pos = varint_decode(data, pos)
            elseif wire_type == 2 then -- length-delimited
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

        if field_number == 1 and wire_type == 0 then -- zone (uint32)
            dmx_message.zone, pos = varint_decode(data, pos)
        elseif field_number == 2 and wire_type == 0 then -- universe_mask (uint32)
            dmx_message.universe_mask, pos = varint_decode(data, pos)
        elseif field_number == 3 and wire_type == 0 then -- channel (uint32)
            dmx_message.channel, pos = varint_decode(data, pos)
        elseif field_number == 4 and wire_type == 0 then -- repeat (uint32)
            dmx_message.repeat_count, pos = varint_decode(data, pos)
        elseif field_number == 5 and wire_type == 2 then -- level (repeated uint32)
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
        elseif field_number == 6 and wire_type == 0 then -- fade_time_by_10ms (uint32)
            dmx_message.fade_time_by_10ms, pos = varint_decode(data, pos)
        else
            -- Skip unknown fields
            if wire_type == 0 then -- varint
                _, pos = varint_decode(data, pos)
            elseif wire_type == 2 then -- length-delimited
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

        if field_number == 1 and wire_type == 0 then -- TriggerType (uint32)
            trigger_message.type, pos = varint_decode(data, pos)
        elseif field_number == 2 and wire_type == 0 then -- zone (uint32)
            trigger_message.zone, pos = varint_decode(data, pos)
        elseif field_number == 3 and wire_type == 0 then -- line_mask (uint32)
            trigger_message.line_mask, pos = varint_decode(data, pos)
        elseif field_number == 4 and wire_type == 0 then -- target_index (uint32)
            trigger_message.target_index, pos = varint_decode(data, pos)
        elseif field_number == 5 and wire_type == 0 then -- value (uint32)
            trigger_message.value, pos = varint_decode(data, pos)
        elseif field_number == 6 and wire_type == 0 then -- query_index (uint32)
            trigger_message.query_index, pos = varint_decode(data, pos)
        else
            -- Skip unknown fields
            if wire_type == 0 then -- varint
                _, pos = varint_decode(data, pos)
            elseif wire_type == 2 then -- length-delimited
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

        if field_number == 1 and wire_type == 2 then -- TriggerMessage (length-delimited)
            local message_data
            message_data, pos = decode_length_delimited(data, pos)
            external_trigger_message.trigger = decode_trigger_message(message_data)
        else
            -- Skip unknown fields
            if wire_type == 0 then -- varint
                _, pos = varint_decode(data, pos)
            elseif wire_type == 2 then -- length-delimited
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

-- Function to decode TriggerEvent
local function decode_trigger_event(data)
    local pos = 1
    local trigger_event = {}

    while pos <= #data do
        local field_number, wire_type, new_pos = decode_field_key(data, pos)
        pos = new_pos

        if field_number == 1 and wire_type == 0 then -- TriggerType (varint)
            trigger_event.type, pos = varint_decode(data, pos)

        elseif field_number == 2 and wire_type == 0 then -- level (varint, oneof)
            trigger_event.payload = {level = varint_decode(data, pos)}

        elseif field_number == 3 and wire_type == 0 then -- dali_command (varint, oneof)
            trigger_event.payload = {dali_command = varint_decode(data, pos)}

        elseif field_number == 4 and wire_type == 0 then -- target_address (varint)
            trigger_event.target_address, pos = varint_decode(data, pos)

        elseif field_number == 5 and wire_type == 0 then -- line_mask (varint)
            trigger_event.line_mask, pos = varint_decode(data, pos)

        elseif field_number == 6 and wire_type == 0 then -- zone (varint)
            trigger_event.zone, pos = varint_decode(data, pos)

        elseif field_number == 7 and wire_type == 0 then -- value (varint)
            trigger_event.value, pos = varint_decode(data, pos)

        elseif field_number == 8 and wire_type == 0 then -- query_index (varint)
            trigger_event.query_index, pos = varint_decode(data, pos)

        elseif field_number == 9 and wire_type == 0 then -- source (varint)
            trigger_event.source, pos = varint_decode(data, pos)

        else
            -- Skip unknown fields
            if wire_type == 0 then -- varint
                _, pos = varint_decode(data, pos)
            elseif wire_type == 2 then -- length-delimited
                local length
                length, pos = varint_decode(data, pos)
                pos = pos + length
            else
                error("Unsupported wire type: " .. wire_type)
            end
        end
    end

    return trigger_event
end

-- Function to decode InputStateResponse
local function decode_input_state_response(data)
    local pos = 1
    local input_state_response = {}

    while pos <= #data do
        local field_number, wire_type, new_pos = decode_field_key(data, pos)
        pos = new_pos

        if field_number == 1 and wire_type == 0 then -- state_id (uint32)
            input_state_response.state_id, pos = varint_decode(data, pos)

        elseif field_number == 2 and wire_type == 0 then -- input_value (uint32)
            input_state_response.input_value, pos = varint_decode(data, pos)

        elseif field_number == 3 and wire_type == 0 then -- timestamp (uint32)
            input_state_response.timestamp, pos = varint_decode(data, pos)

        else
            -- Skip unknown fields
            if wire_type == 0 then -- varint
                _, pos = varint_decode(data, pos)
            elseif wire_type == 2 then -- length-delimited
                local length
                length, pos = varint_decode(data, pos)
                pos = pos + length
            else
                error("Unsupported wire type: " .. wire_type)
            end
        end
    end

    return input_state_response
end

-- Function to decode DALISensorEvent
local function decode_dali_sensor_event(data)
    local pos = 1
    local dali_sensor_event = {}

    while pos <= #data do
        local field_number, wire_type, new_pos = decode_field_key(data, pos)
        pos = new_pos

        if field_number == 1 and wire_type == 0 then -- line (uint32)
            dali_sensor_event.line, pos = varint_decode(data, pos)

        elseif field_number == 2 and wire_type == 0 then -- sensor_value (uint32)
            dali_sensor_event.sensor_value, pos = varint_decode(data, pos)

        elseif field_number == 3 and wire_type == 0 then -- timestamp (uint32)
            dali_sensor_event.timestamp, pos = varint_decode(data, pos)

        else
            -- Skip unknown fields
            if wire_type == 0 then -- varint
                _, pos = varint_decode(data, pos)
            elseif wire_type == 2 then -- length-delimited
                local length
                length, pos = varint_decode(data, pos)
                pos = pos + length
            else
                error("Unsupported wire type: " .. wire_type)
            end
        end
    end

    return dali_sensor_event
end

-- Function to decode DALI24InputEvent
local function decode_dali_24_input_event(data)
    local pos = 1
    local dali_24_input_event = {}

    while pos <= #data do
        local field_number, wire_type, new_pos = decode_field_key(data, pos)
        pos = new_pos

        if field_number == 1 and wire_type == 0 then -- line (uint32)
            dali_24_input_event.line, pos = varint_decode(data, pos)

        elseif field_number == 2 and wire_type == 0 then -- input_value (uint32)
            dali_24_input_event.input_value, pos = varint_decode(data, pos)

        elseif field_number == 3 and wire_type == 0 then -- timestamp (uint32)
            dali_24_input_event.timestamp, pos = varint_decode(data, pos)

        else
            -- Skip unknown fields
            if wire_type == 0 then -- varint
                _, pos = varint_decode(data, pos)
            elseif wire_type == 2 then -- length-delimited
                local length
                length, pos = varint_decode(data, pos)
                pos = pos + length
            else
                error("Unsupported wire type: " .. wire_type)
            end
        end
    end

    return dali_24_input_event
end

-- Function to decode EventFilter
local function decode_event_filter(data)
    local pos = 1
    local event_filter = {}

    while pos <= #data do
        local field_number, wire_type, new_pos = decode_field_key(data, pos)
        pos = new_pos

        if field_number == 1 and wire_type == 0 then -- filter_type (uint32)
            event_filter.filter_type, pos = varint_decode(data, pos)

        elseif field_number == 2 and wire_type == 0 then -- filter_value (uint32)
            event_filter.filter_value, pos = varint_decode(data, pos)

        elseif field_number == 3 and wire_type == 0 then -- timestamp (uint32)
            event_filter.timestamp, pos = varint_decode(data, pos)

        else
            -- Skip unknown fields
            if wire_type == 0 then -- varint
                _, pos = varint_decode(data, pos)
            elseif wire_type == 2 then -- length-delimited
                local length
                length, pos = varint_decode(data, pos)
                pos = pos + length
            else
                error("Unsupported wire type: " .. wire_type)
            end
        end
    end

    return event_filter
end

-- Function to decode DALI24FrameEvent
local function decode_dali_24_frame_event(data)
    local pos = 1
    local dali_24_frame_event = {}

    while pos <= #data do
        local field_number, wire_type, new_pos = decode_field_key(data, pos)
        pos = new_pos

        if field_number == 1 and wire_type == 0 then -- line (uint32)
            dali_24_frame_event.line, pos = varint_decode(data, pos)

        elseif field_number == 2 and wire_type == 0 then -- frame (uint32)
            dali_24_frame_event.frame, pos = varint_decode(data, pos)

        else
            -- Skip unknown fields
            if wire_type == 0 then -- varint
                _, pos = varint_decode(data, pos)
            elseif wire_type == 2 then -- length-delimited
                local length
                length, pos = varint_decode(data, pos)
                pos = pos + length
            else
                error("Unsupported wire type: " .. wire_type)
            end
        end
    end

    return dali_24_frame_event
end

-- Function to decode EventMessage
local function decode_event_message(data)
    local pos = 1
    local event_message = {}

    while pos <= #data do
        local field_number, wire_type, new_pos = decode_field_key(data, pos)
        pos = new_pos
    
        if field_number == 1 and wire_type == 0 then -- event (EventType)
            event_message.event, pos = varint_decode(data, pos)

        elseif field_number == 2 and wire_type == 2 then -- TriggerEvent (length-delimited)
            local message_data
            message_data, pos = decode_length_delimited(data, pos)
            event_message.event_data = {trigger = decode_trigger_event(message_data)}
				
        elseif field_number == 3 and wire_type == 2 then -- InputStateResponse (length-delimited)
            local message_data
            message_data, pos = decode_length_delimited(data, pos)
            event_message.event_data = {inputs = decode_input_state_response(message_data)}

        elseif field_number == 4 and wire_type == 2 then -- PayloadMessage (length-delimited)
            local message_data
            message_data, pos = decode_length_delimited(data, pos)
            event_message.event_data = {payload = decode_payload_message(message_data)}

        elseif field_number == 6 and wire_type == 2 then -- DALISensorEvent (length-delimited)
            local message_data
            message_data, pos = decode_length_delimited(data, pos)
            event_message.event_data = {sensor = decode_dali_sensor_event(message_data)}

        elseif field_number == 7 and wire_type == 2 then -- DALI24InputEvent (length-delimited)
            local message_data
            message_data, pos = decode_length_delimited(data, pos)
            event_message.event_data = {dali_24_input = decode_dali_24_input_event(message_data)}

        elseif field_number == 8 and wire_type == 2 then -- EventFilter (length-delimited)
            local message_data
            message_data, pos = decode_length_delimited(data, pos)
            event_message.event_data = {filter = decode_event_filter(message_data)}

        elseif field_number == 9 and wire_type == 2 then -- DALI24FrameEvent (length-delimited)
            local message_data
            message_data, pos = decode_length_delimited(data, pos)
            event_message.event_data = {dali_24_frame = decode_dali_24_frame_event(message_data)}

        else
            -- Skip unknown fields
            if wire_type == 0 then -- varint
                _, pos = varint_decode(data, pos)
            elseif wire_type == 2 then -- length-delimited
                local length
                length, pos = varint_decode(data, pos)
                pos = pos + length
            else
                log("Unsupported wire type: " .. wire_type)
            end
        end
    end

    return event_message
end

-- Function to decode EdidioMessage
function Decode_edidio_message(data)
    local pos = 1
    local edidio_message = {}

    while pos <= #data do
        local field_number, wire_type, new_pos = decode_field_key(data, pos)
        pos = new_pos
    
        if field_number == 1 and wire_type == 0 then -- message_id (uint32)
            edidio_message.message_id, pos = varint_decode(data, pos)
        elseif field_number == 2 and wire_type == 2 then -- AckMessage (length-delimited)
            local message_data
            message_data, pos = decode_length_delimited(data, pos)
            edidio_message.payload = {ack = decode_ack_message(message_data)}
        elseif field_number == 18 and wire_type == 2 then -- DALIMessage (length-delimited)
            local message_data
            message_data, pos = decode_length_delimited(data, pos)
            edidio_message.payload = {dali_message = decode_dali_message(message_data)}
        elseif field_number == 19 and wire_type == 2 then -- DALIQuery (length-delimited)
            local message_data
            message_data, pos = decode_length_delimited(data, pos)
            edidio_message.payload = {dali_query = decode_dali_query_response(message_data)}
        elseif field_number == 20 and wire_type == 2 then -- DMXMessage (length-delimited)
            local message_data
            message_data, pos = decode_length_delimited(data, pos)
            edidio_message.payload = {dmx_message = decode_dmx_message(message_data)}
        elseif field_number == 21 and wire_type == 2 then -- ExternalTriggerMessage (length-delimited)
            local message_data
            message_data, pos = decode_length_delimited(data, pos)
            edidio_message.payload = {external_trigger = decode_external_trigger_message(message_data)}
        elseif field_number == 34 and wire_type == 2 then -- EventMessage (length-delimited)
            local message_data
            message_data, pos = decode_length_delimited(data, pos)
            edidio_message.payload = {event_message = decode_event_message(message_data)}
        else
            -- Skip unknown fields
            if wire_type == 0 then -- varint
                _, pos = varint_decode(data, pos)
            elseif wire_type == 2 then -- length-delimited
                local length
                length, pos = varint_decode(data, pos)
                pos = pos + length
            else
                log("Unsupported wire type: " .. wire_type)
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
        log("KEY " .. k .. " PAIR " .. v)
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
    return (MessageId + 1)
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

-- Standard DALI command
DALI_OFF                       = 0;
DALI_FADE_UP                   = 1;
DALI_FADE_DOWN                 = 2;
DALI_STEP_UP                   = 3;
DALI_STEP_DOWN                 = 4;
DALI_MAX_LEVEL                 = 5;
DALI_MIN_LEVEL                 = 6;
DALI_STEP_DOWN_OFF             = 7;
DALI_ON_STEP_UP                = 8;
DALI_ENABLE_DAPC_SEQ           = 9; 
DALI_RECALL_LAST_ACTIVE_LEVEL  = 10;
DALI_CONTINUOUS_UP             = 11;
DALI_CONTINUOUS_DOWN           = 12;
DALI_RECALL_SCENE_0            = 16;
DALI_RECALL_SCENE_1            = 17;
DALI_RECALL_SCENE_2            = 18;
DALI_RECALL_SCENE_3            = 19;
DALI_RECALL_SCENE_4            = 20;
DALI_RECALL_SCENE_5            = 21;
DALI_RECALL_SCENE_6            = 22;
DALI_RECALL_SCENE_7            = 23;
DALI_RECALL_SCENE_8            = 24;
DALI_RECALL_SCENE_9            = 25;
DALI_RECALL_SCENE_10           = 26;
DALI_RECALL_SCENE_11           = 27;
DALI_RECALL_SCENE_12           = 28;
DALI_RECALL_SCENE_13           = 29;
DALI_RECALL_SCENE_14           = 30;
DALI_RECALL_SCENE_15           = 31;
DALI_RESET                     = 32;
DALI_STORE_ACTUAL_LEVEL_DTR0   = 33;
DALI_SAVE_PERSISTENT_VARS      = 34;
DALI_SET_OPERATING_MODE        = 35;
DALI_RESET_MEMORY_BANK         = 36;
DALI_IDENTIFY_DEVICE           = 37;
DALI_SET_MAX_LEVEL             = 42;
DALI_SET_MIN_LEVEL             = 43;
DALI_SET_SYSTEM_FAILURE_LEVEL  = 44;
DALI_SET_POWER_ON_LEVEL        = 45;
DALI_SET_FADE_TIME             = 46;
DALI_SET_FADE_RATE             = 47;
DALI_SET_EXT_FADE_TIME         = 48;
DALI_SET_SCENE_0               = 64;
DALI_SET_SCENE_1               = 65;
DALI_SET_SCENE_2               = 66;
DALI_SET_SCENE_3               = 67;
DALI_SET_SCENE_4               = 68;
DALI_SET_SCENE_5               = 69;
DALI_SET_SCENE_6               = 70;
DALI_SET_SCENE_7               = 71;
DALI_SET_SCENE_8               = 72;
DALI_SET_SCENE_9               = 73;
DALI_SET_SCENE_10              = 74;
DALI_SET_SCENE_11              = 75;
DALI_SET_SCENE_12              = 76;
DALI_SET_SCENE_13              = 77;
DALI_SET_SCENE_14              = 78;
DALI_SET_SCENE_15              = 79;
DALI_REMOVE_FROM_SCENE_0       = 80;
DALI_REMOVE_FROM_SCENE_1       = 81;
DALI_REMOVE_FROM_SCENE_2       = 82;
DALI_REMOVE_FROM_SCENE_3       = 83;
DALI_REMOVE_FROM_SCENE_4       = 84;
DALI_REMOVE_FROM_SCENE_5       = 85;
DALI_REMOVE_FROM_SCENE_6       = 86;
DALI_REMOVE_FROM_SCENE_7       = 87;
DALI_REMOVE_FROM_SCENE_8       = 88;
DALI_REMOVE_FROM_SCENE_9       = 89;
DALI_REMOVE_FROM_SCENE_10      = 90;
DALI_REMOVE_FROM_SCENE_11      = 91;
DALI_REMOVE_FROM_SCENE_12      = 92;
DALI_REMOVE_FROM_SCENE_13      = 93;
DALI_REMOVE_FROM_SCENE_14      = 94;
DALI_REMOVE_FROM_SCENE_15      = 95;
DALI_ADD_TO_GROUP_0            = 96;
DALI_ADD_TO_GROUP_1            = 97;
DALI_ADD_TO_GROUP_2            = 98;
DALI_ADD_TO_GROUP_3            = 99;
DALI_ADD_TO_GROUP_4            = 100;
DALI_ADD_TO_GROUP_5            = 101;
DALI_ADD_TO_GROUP_6            = 102;
DALI_ADD_TO_GROUP_7            = 103;
DALI_ADD_TO_GROUP_8            = 104;
DALI_ADD_TO_GROUP_9            = 105;
DALI_ADD_TO_GROUP_10           = 106;
DALI_ADD_TO_GROUP_11           = 107;
DALI_ADD_TO_GROUP_12           = 108;
DALI_ADD_TO_GROUP_13           = 109;
DALI_ADD_TO_GROUP_14           = 110;
DALI_ADD_TO_GROUP_15           = 111;
DALI_REMOVE_FROM_GROUP_0       = 112;
DALI_REMOVE_FROM_GROUP_1       = 113;
DALI_REMOVE_FROM_GROUP_2       = 114;
DALI_REMOVE_FROM_GROUP_3       = 115;
DALI_REMOVE_FROM_GROUP_4       = 116;
DALI_REMOVE_FROM_GROUP_5       = 117;
DALI_REMOVE_FROM_GROUP_6       = 118;
DALI_REMOVE_FROM_GROUP_7       = 119;
DALI_REMOVE_FROM_GROUP_8       = 120;
DALI_REMOVE_FROM_GROUP_9       = 121;
DALI_REMOVE_FROM_GROUP_10      = 122;
DALI_REMOVE_FROM_GROUP_11      = 123;
DALI_REMOVE_FROM_GROUP_12      = 124;
DALI_REMOVE_FROM_GROUP_13      = 125;
DALI_REMOVE_FROM_GROUP_14      = 126;
DALI_REMOVE_FROM_GROUP_15      = 127;
DALI_SET_SHORT_ADDRESS         = 128;
DALI_ENABLE_WRITE_MEMORY       = 129;
DALI_TERMINATE                 = 255;
DALI_INITIALISE                = 258;
DALI_RANDOMISE                 = 259;
DALI_WITHDRAW                  = 261;
DALI_SEARCH_ADDR_H             = 264;
DALI_SEARCH_ADDR_M             = 265;
DALI_SEARCH_ADDR_L             = 266;
DALI_PROGRAM_SHORT_ADDRESS     = 267;

-- ACK
DECODE_FAILED = 0 -- May indicate an issue with the protocol (e.g. a mismatch in expected fields between clients). Ensure both parties are using the latest version.
INDEX_OUT_OF_BOUNDS = 1 -- A resource was requested beyond the amount available.
UNEXPECTED_TYPE = 2 -- The provided message was not able to be handled or processed (likely due to a lack of enough information or incorrect values).
ENCODE_FAILED = 3 -- Not currently in use.
KEY_MISMATCH = 4 -- Not currently in use.
SUCCESS = 5 -- The message was decoded and handled successfully.
INVALID_PARAMS = 6 -- The message was decoded but had invalid data for the intended outcome.
UNEXPECTED_COMMAND = 7 -- The message was decoded but the requested action was not valid for current the state of the device.
COMMUNICATION_FAILED = 8 -- The message could not be received or sent due to an internal issue.
COMMUNICATION_TIMEOUT = 9 -- May indicate contention for a shared resource or that an existing task is taking longer than expected and the latest request has timed-out.
DATA_TOO_LONG = 10 -- May indicate too much data was in the request or the required reply would be too big to handle.
UNEXPECTED_CASE = 11 -- May indicate that the message is out of context (e.g. an "end" command for a process that is not running) or that the message requests a feature that is not yet implemented.
SLOTS_FULL = 12 -- Typically indicates that a request was valid, but the relevant content is "full" and thus elements must be removed before continuing.
UNAUTHORISED = 13 -- The message could not be actioned because the connection has not been authorised.
PARTIAL_SUCCESS = 14 -- Can be returned in the case where some but not all Lines in a line_mask successfully sent
COMMAND_FAILED = 15 -- For whatever reason, the intended command did not complete
DEPRECATED = 16 -- For message which is no longer supported by this Firmware

-- DALI Query Response
WAITING = 0 -- Internal Idle State - Should not be received
RECEIVING_FRAME = 1 -- DALI Frame being Received
NO_RECEIVED_FRAME = 2 -- Frame was recorded - Empty Data
RECEIVED_8_BIT_FRAME = 3 -- Frame was recorded - 8 Bit Reply
RECEIVED_16_BIT_FRAME = 4 -- Frame was recorded - 16 Bit - Standard Message
RECEIVED_24_BIT_FRAME = 5 -- Frame was recorded - 24 Bit - eDALI Message
RECEIVED_PARTIAL_FRAME = 6 -- Frame was recorded - Unusual Bit count
IDLE = 7 -- DALI System Idle
CALIBRATION = 8 -- Inhouse DALI Calibration
ERROR_WHILE_SENDING = 254 -- Error while trying to Transmit DALI - Possibly no Bus Power
ERROR_WHILE_RECEIVING = 255 -- Error while trying to Receive - Invalid Frame Data, or no response

-- Triggers
DALI_ARC = 0 -- For controlling DALI Arc Levels (0 to 254) and 255 for MASK
DALI_COMMAND = 1 -- See (https://en.wikipedia.org/wiki/Digital_Addressable_Lighting_Interface#Commands_for_control_gear) for a list of common DALI commands
DMX_CHANNELS_SPLIT_LOW = 2 -- NOTE: Expects the channel number (not zero-based)
DMX_CHANNELS_SPLIT_HIGH = 3 -- NOTE: Expects the channel number (not zero-based)
DMX_MULTICAST_CHANNELS_SPLIT_LOW = 4 -- NOTE: Expects the channel INDEX to start from, as it takes into account the start address set from Spektra
DMX_MULTICAST_CHANNELS_SPLIT_HIGH = 5 -- NOTE: Expects the channel INDEX to start from, as it takes into account the start address set from Spektra
DMX_BROADCAST = 6 -- Affects all DMX lights as per the Spektra Settings (number of lights and channels per light)
DIDIO = 7 -- DEPRECATED
FADE_UP_WITH_MIN = 8 -- DALI Fade Up Command - Query level and set Minimum if Off
LIST_START = 9 -- Start a List action once
LIST_START_CONTINUOUS = 10 -- Start a List action with repeat
LIST_STOP = 11 -- Stop a List
SPEKTRA_START_SEQ = 12 -- Start a Spektra Sequence
SPEKTRA_STOP_SEQ = 13 -- Stop a playing Spektra Sequence
SPEKTRA_THEME = 14 -- Apply a Spektra Theme
SPEKTRA_STATIC = 15 -- DEPRECATED
SPEKTRA_SCHEDULE = 16 -- Start the scheduled Spektra item
LINK_START = 17 -- Enables the UDP Link State - If Configured
LINK_STOP = 18 -- Temporarily disables the UDP Link State
DISABLE_BURN = 19 -- Disable Burn-In
ENABLE_BURN = 20 -- Enable Burn-In
ON_OFF_TOG = 21 -- Turn a Group/Addres On/Off based on query level. If DALI_GROUP_ALL, toggle based on flag
MIN_MAX_TOG = 22 -- On/Off Toggle replaced by Min/Max
ENABLE_INPUT = 23 -- Enable Input - If latching, Input will trigger immediatly
DISABLE_INPUT = 24 -- Disable Input
ENABLE_TOG_INPUT = 25 -- Toggle Enable/Disable Input
OUTPUT_TOG = 26 -- Toggle Output State between High (~22Vdc) and Low (0Vdc)
OUTPUT_HIGH = 27 -- Set Output HIGH
OUTPUT_LOW = 28 -- Set Output LOW
OUTPUT_TRIG = 29 -- Set Output to trigger momentarily based on configuration
PROFILE_CHANGE = 30 -- Change Profile - This action will reset sensor state
FADE_LONG_PRESS = 31 -- Long Press Fade based on Toggle Flag
SYNCRO = 32 -- Command sets clock to 11:59PM. Used for hardware time update by external Timeclock
PRESET_CODE = 33 -- Preset Code - See Configurator Description
CUSTOM_CODE = 34 -- Project Specific Custom Code - Talk to Creative Lighting for support
SPEKTRA_SLEEP = 35 -- Pause Spektra sequence
SPEKTRA_RESUME = 36 -- Resume Spektra sequence
DEVICE_RESET = 37 -- Admin Command for Hardware Reset
DEVICE_SAVE = 38 -- Admin Command for manual device memory save
USER_LEVEL_STORE_NEW = 39 -- Store Current Level to Variable
USER_LEVEL_SET_DEFAULT = 40 -- Reset User Level Variable
USER_LEVEL_RECALL = 41 -- Recall User Level Variable
ROOM_JOIN = 43 -- DEPRECATED
ROOM_UNJOIN = 44 -- DEPRECATED
TYPE8_TC_WARMER = 45 -- DALI Type 8 Warmer Command. 1 Mirek increments
TYPE8_TC_COOLER = 46 -- DALI Type 8 Cooler Command. 1 Mirek increments
TYPE8_TC_ACTUAL = 47 -- DALI Type 8 Set Colour to Mirek value
LOGIC_OPERATION = 48 -- Not Implemented
ALARM_ENABLE = 49 -- Enable Alarm at Index
ALARM_DISABLE = 50 -- Disable Alarm at Index
DALI_CONTROL_SENSOR_OVERRIDE = 51 -- Puts the DALI Sensor in 'override mode', which means it will no longer control the lighting until occupancy has timed-out or control is manually resumed
DALI_CONTROL_SENSOR_TEMP_DISABLE = 52 -- Sets the occupancy timer to zero and puts the DALI Sensor in a temporary 'disable mode' (duration depends on Sensor configuration: 'Disable Period')
DALI_CONTROL_SENSOR_RESUME = 53 -- Takes the DALI Sensor out of 'override mode'
DALI_ARC_OVERRIDE = 54 -- For controlling DALI Arc Levels (0 to 254) and 255 for MASK - Sets associated group to override mode
DALI_COMMAND_OVERRIDE = 55 -- For sending DALI commands - Sets associated group to override mode
FADE_UP_WITH_MIN_OVERRIDE = 56 -- Non-native DALI command override (sets associated group to override mode)
ON_OFF_TOG_OVERRIDE = 57 -- Non-native DALI command override (sets associated group to override mode)
MIN_MAX_TOG_OVERRIDE = 58 -- Non-native DALI command override (sets associated group to override mode)
MAX_OFF_TOG = 59 -- Not Implemented
MAX_OFF_TOG_OVERRIDE = 60 -- Not Implemented
FADE_LONG_PRESS_OVERRIDE = 61 -- Non-native DALI command override (sets associated group to override mode)
USER_LEVEL_RECALL_OVERRIDE = 62 -- Non-native DALI command override (sets associated group to override mode)
DMX_ZONE_FADE_UP = 63 -- DMX Spektra Zone Fade UP
DMX_ZONE_FADE_DOWN = 64 -- DMX Spektra Zone Fade DOWN
LOGGING_LEVEL = 65 -- Enable Logging to EEPROM to be read by configurator
SPEKTRA_SHOW_CONTROL = 66 -- DEPRECATED
CIRCADIAN_TEMPERATURE = 67 -- Selects Colour Temperature based on clock
DALI_CONTROL_SENSOR_MUTE = 68 -- Mute Sensor at Index (or all with Index 255)
DALI_CONTROL_SENSOR_UNMUTE = 69 -- Unmute to Sensor at Index (or all with Index 255)
SPEKTRA_INTENSITY = 70 -- Allow you to specify the maximum Spektra Sequence or Theme output intensity (10 to 100)%
ENABLE_INPUT_NO_ACTION = 71 -- Allow you to enable an input (Latching), but not trigger the action.
SET_DALI_FADE_TIME = 72 -- Sets the DALI Fade Time
NO_COMMAND = 254 -- This TriggerType should always be at the bottom of the list. Add any new TriggerTypes above it (up to 253).

-- EventType Messages
REGISTER                = 0; -- Sent by the client to register for events.
TRIGGER_EVENT           = 1; -- Emitted when trigger runs an action listed in TriggerType.
INPUT_EVENT             = 2; -- Emitted when a physical Input is triggered.
SENSOR_EVENT            = 3; -- Emitted when a Sensor (24-bit DALI or 25-bit) is triggered.
CONTROL_EVENT           = 4; -- Emitted when an DALI/DMX/phyiscal output type event is done. References an action in TriggerType.
ROOM_JOIN_EVENT         = 5; -- Emitted when rooms are joined/unjoined.
DALI_24_INPUT_EVENT     = 6; -- Emitted when a 24-bit DALI Input Device is triggered.
DALI_24_FRAME_EVENT     = 7; -- Emitted when a 24-bit DALI Frame is received.

