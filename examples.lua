require("user.eDIDIOCore")

-- Example Usage

-- Get Level
value1 = GetLightingLevel(0)
if (value1 == 255) then
  	value1 = 254
end

--sendDALIFadeMessage(1, 80, 3)
--sendDALIArcLevel(1, 0, value1)
--sendDALIArcLevel(1, 2, value1)
--sendDALIArcLevel(1, 64, value1)
--sendDALIArcLevel(1, 80, value1)
sendDMXLevel(2, 1, 20, 100, 2)



-- DEBUG Log event
--log("Data Sent " .. msg)

-- Get Receive
--while true do
  --  local s, status, partial = tcp:receive()
  --  log(s or partial)
  --  if status == "closed" then break end
--end
-- tcp:close()