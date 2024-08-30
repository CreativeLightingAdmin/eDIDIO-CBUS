require("user.eDIDIOCore")
require("user.eDIDIOConfig")

-- Example Usage

-- Get Level
value1 = GetLightingLevel(0)
if (value1 == 255) then
  	value1 = 254
end

local eDIDIOS10_1 = EDIDIO.new(eDIDIOS10_1)

--eDIDIOS10_1sendDALIFadeMessage(1, 80, 3)
eDIDIOS10_1:sendDALIArcLevel(LINE_1, DALI_0, value1)
--eDIDIOS10_1sendDALIArcLevel(1, 2, value1)
--eDIDIOS10_1sendDALIArcLevel(1, 64, value1)
--eDIDIOS10_1sendDALIArcLevel(1, 80, value1)
--eDIDIOS10_1sendDALICCTMessage(1, 1, 2000, 254)



-- DEBUG Log event
--log("Data Sent " .. msg)

-- Get Receive
--while true do
  --  local s, status, partial = tcp:receive()
  --  log(s or partial)
  --  if status == "closed" then break end
--end
-- tcp:close()