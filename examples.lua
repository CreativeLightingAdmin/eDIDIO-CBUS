require("user.eDIDIOCore")
require("user.eDIDIOConfig")

-- Example Usage

-- Get Level
value1 = GetLightingLevel(0)
if (value1 == 255) then
  	value1 = 254    -- DALI max level
end

-- Create new eDIDIO instance
local eDIDIOS10_1 = EDIDIO.new(eDIDIOS10_1)

-- Send an Arc Level
local flag = eDIDIOS10_1:sendDALIArcLevel(LINE_1, DALI_0, value1)
-- Example Logging
log(flag)

-- Create a second eDIDIO instance
local eDIDIOS10_2 = EDIDIO.new(eDIDIOS10_2)
eDIDIOS10_2:sendDALIRGBDT8Message(LINE_1, DALI_0, 127, 100, 50, 100)  
-- Send an RGBDT8 Message, {127, 100, 50}
eDIDIOS10_2:sendDALICCTDT8Message(LINE_1, DALI_0, 3000, 254)          
-- Send an CCTDT8 Message. 3000K, 100% output
eDIDIOS10_2:sendDMXLevels(LINE_2, 10, {255, 127, 0}, 100, 5)          
-- Send DMX Levels to Line 2, Address 10. Levels 255, 127, 0, fade over 1 second
eDIDIOS10_2:sendDMXRGBW(LINE_2, 1, 0, 10, 20, 30, 100, 2)             
-- Send DMX Levels to an RGBW fixture, 1 second fade, repeat over 2 fixtures
eDIDIOS10_2:sendTrigger(LINE_1, 0, DALI_ARC_OVERRIDE, DALI_1, 200, 0) 
-- Send DALI Arc level with sensor override to DALI_1, level 200, line 1



-- Working Sequence Start Below
local eDIDIOS10_3 = EDIDIO.new(eDIDIOS10_3)
--if (value1 ~= 0) then
--    eDIDIOS10_3:sendTrigger(0, 0, SPEKTRA_START_SEQ, 0, 0, 0) -- line, zone, type, target, value, query
--else
--    eDIDIOS10_3:sendTrigger(0, 0, SPEKTRA_STOP_SEQ, 0, 0, 0) -- line, zone, type, target, value, query
--end


-- Example DMX Sequence
local red = {255, 0, 0, 0}
local orange = {255, 127, 0, 0}
local yellow = {127, 255, 0, 0}
local blue = {0, 0, 255, 0}
local purple = {255, 0, 127, 0}
local green = {0, 255, 0, 0}
local white = {255, 255, 255, 0}
local off = {0, 0, 0, 0}


eDIDIOS10_3:sendDMXLevels(1, 1, red, 100, 2) -- line, channel, level, fadetime (100 = 1s, 1000 = 10s) , rpt
sleep(1)
eDIDIOS10_3:sendDMXLevels(1, 1, orange, 100, 2) -- line, channel, level, fadetime (100 = 1s, 1000 = 10s) , rpt
sleep(1)
eDIDIOS10_3:sendDMXLevels(1, 1, yellow, 100, 2) -- line, channel, level, fadetime (100 = 1s, 1000 = 10s) , rpt
sleep(1)
eDIDIOS10_3:sendDMXLevels(1, 1, blue, 100, 2) -- line, channel, level, fadetime (100 = 1s, 1000 = 10s) , rpt
sleep(1)
eDIDIOS10_3:sendDMXLevels(1, 1, purple, 100, 2) -- line, channel, level, fadetime (100 = 1s, 1000 = 10s) , rpt
sleep(1)
eDIDIOS10_3:sendDMXLevels(1, 1, green, 100, 2) -- line, channel, level, fadetime (100 = 1s, 1000 = 10s) , rpt
sleep(1)
eDIDIOS10_3:sendDMXLevels(1, 1, white, 100, 2) -- line, channel, level, fadetime (100 = 1s, 1000 = 10s) , rpt
sleep(1)
eDIDIOS10_3:sendDMXLevels(1, 1, off, 100, 2) -- line, channel, level, fadetime (100 = 1s, 1000 = 10s) , rpt

