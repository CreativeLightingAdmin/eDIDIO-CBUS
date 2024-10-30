require("user.eDIDIOCore")
require("user.eDIDIOConfig")

-- Example Usage
log("Script Running ")


-- Get Level
value1 = GetLightingLevel(0)
if (value1 == 255) then
  	value1 = 254
end

--local eDIDIOS10_1 = EDIDIO.new(eDIDIOS10_1)


--local flag = eDIDIOS10_1:sendDALIArcLevel(LINE_1, DALI_0, value1)
--

--local flag, level = eDIDIOS10_1:getDALILevel(LINE_1, DALI_0)

--log(flag)

local eDIDIOS10_2 = EDIDIO.new(eDIDIOS10_2)
--eDIDIOS10_2:sendDALIRGBDT8Message(LINE_1, DALI_0, 127, 100, 50, 100)
--eDIDIOS10_2:sendDALICCTDT8Message(LINE_1, DALI_0, 3000, 254)
--eDIDIOS10_2:sendDMXRGBW(LINE_2, 1, 0, 10, 20, 30, 100, 2)
--eDIDIOS10_2:sendTrigger(LINE_1, 0, DALI_ARC_OVERRIDE, DALI_1, value1, 0)	
eDIDIOS10_2:setEventFilter(true, true, true, true, true, true, true, true)

-- DEBUG Log event
--logHex(msg)

-- Get Receive
--while true do
  --  local s, status, partial = tcp:receive()
  --  log(s or partial)
  --  if status == "closed" then break end
--end
-- tcp:close()