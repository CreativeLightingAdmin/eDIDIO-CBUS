require("eDIDIOCore")

--sendDALIArcLevel(1, 0, 50)
sendDMXLevels(1, 1, {250, 127, 0}, 10, 4)
-- Assuming `encoded_message` is the result from the previous encoding process
-- local edidio_message = {
--     message_id = 12345,
--     payload = {
--         external_trigger = {
--             trigger = {
--                 type = 1,
--                 zone = 10,
--                 line_mask = 1,
--                 target_index = 5,
--                 value = 100,
--                 query_index = 2,
--             },
--         },
--     },
-- }

-- local edidio_message = {
--     message_id = 5,
--     payload = {
--         dali_message = {
--             line_mask = 0x01,
--             address = 0x20,
--             action = { frame_25_bit = 0x123456 },
--             params = { arg = 5 },
--             instance_type = 0x03,
--             op_code = 0x07
--         }
--     },
-- }

-- local edidio_message = {
--     message_id = 5,
--     payload = {
--         dmx_message = {
--             zone = 0x01,
--             universe_mask = 0x1,
--             channel = 1,
--             repeat_count = 2,
--             levels = {255, 127, 0},
--             fade_time_by_10ms = 10
--         }
--     },
-- }

-- -- Encode the EdidioMessage
-- local encoded_message = Encode_edidio_message(edidio_message)

-- -- Wrap the encoded message with the required format
-- local wrapped_message = Wrap_message(encoded_message)

-- -- Output the wrapped message bytes
-- print("Wrapped Message:", string.byte(wrapped_message, 1, #wrapped_message))

-- -- Unwrap the message to get the encoded_message
-- local unwrapped_message = Unwrap_message(wrapped_message)

-- local decoded_message = Decode_edidio_message(unwrapped_message)


-- -- Decode the eDIDIO Message as EdidioMessage
-- print("Message ID:", decoded_message.message_id)

-- if decoded_message.payload.dali_message then
--     print("DALI Message:", decoded_message.payload.dali_message)
--     PrintPairs(decoded_message.payload.dali_message);
-- elseif decoded_message.payload.dmx_message then
--     print("DMX Message:", decoded_message.payload.dmx_message)
--     PrintPairs(decoded_message.payload.dmx_message);
-- elseif decoded_message.payload.ack then
--     print("Ack Message:", decoded_message.payload.ack)
--     PrintPairs(decoded_message.payload.ack);
-- end