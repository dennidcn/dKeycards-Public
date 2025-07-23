// clearance levels + models
DKEYCARDS.ClearanceLevels = {
    [0] = {name = "No Clearance", color = Color(128, 128, 128), model = nil},
    [1] = {name = "Level 1", color = Color(0, 100, 255), model = "models/labskeycards/bluekeycard.mdl"},
    [2] = {name = "Level 2", color = Color(0, 255, 0), model = "models/labskeycards/greenkeycard.mdl"},
    [3] = {name = "Level 3", color = Color(255, 255, 0), model = "models/labskeycards/yellowkeycard.mdl"},
    [4] = {name = "Level 4", color = Color(255, 0, 0), model = "models/labskeycards/red.mdl"},
    [5] = {name = "Level 5", color = Color(255, 255, 255), model = "models/labskeycards/normalkeycard.mdl"}
}

if SERVER then
    util.AddNetworkString("DKeycards_AccessGranted")
    util.AddNetworkString("DKeycards_AccessDenied")
end

print("[" .. DKEYCARDS.Name .. "] Loaded version " .. DKEYCARDS.Version)