if not CLIENT then return end

DKEYCARDS = DKEYCARDS or {}
DKEYCARDS.ClearanceLevels = DKEYCARDS.ClearanceLevels or {
    [0] = {name = "No Clearance", color = Color(128, 128, 128), model = nil},
    [1] = {name = "Level 1", color = Color(0, 100, 255), model = "models/labskeycards/bluekeycard.mdl"},
    [2] = {name = "Level 2", color = Color(0, 255, 0), model = "models/labskeycards/greenkeycard.mdl"},
    [3] = {name = "Level 3", color = Color(255, 255, 0), model = "models/labskeycards/yellowkeycard.mdl"},
    [4] = {name = "Level 4", color = Color(255, 0, 0), model = "models/labskeycards/red.mdl"},
    [5] = {name = "Level 5", color = Color(255, 255, 255), model = "models/labskeycards/normalkeycard.mdl"}
}

local COLOR_SUCCESS = Color(0, 255, 0)
local COLOR_DENIED = Color(255, 0, 0)
local COLOR_INFO = Color(0, 150, 255)

net.Receive("DKeycards_AccessGranted", function()
    local keypad = net.ReadEntity()
    
    chat.AddText(COLOR_SUCCESS, "[KEYCARD] ", color_white, "Access Granted")
    
    surface.PlaySound("buttons/button14.wav")
    
    if IsValid(keypad) then
        local effectdata = EffectData()
        effectdata:SetOrigin(keypad:GetPos())
        effectdata:SetEntity(keypad)
        util.Effect("dkeycard_success", effectdata)
    end
end)

net.Receive("DKeycards_AccessDenied", function()
    local keypad = net.ReadEntity()
    local requiredLevel = net.ReadUInt(8)
    local playerLevel = net.ReadUInt(8)
    
    chat.AddText(COLOR_DENIED, "[KEYCARD] ", color_white, "Access Denied - Requires Level " .. requiredLevel .. " (You have Level " .. playerLevel .. ")")
    
    surface.PlaySound("buttons/button10.wav")
    
    if IsValid(keypad) then
        local effectdata = EffectData()
        effectdata:SetOrigin(keypad:GetPos())
        effectdata:SetEntity(keypad)
        util.Effect("dkeycard_denied", effectdata)
    end
end)

local function DrawKeycardHUD()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    
    local tr = ply:GetEyeTrace()
    local ent = tr.Entity
    
    if not IsValid(ent) or ent:GetClass() ~= "dkeycard_keypad" then return end
    if tr.Fraction > 0.1 then return end
    
    local pos = ent:GetPos() + ent:GetUp() * 20
    local ang = ent:GetAngles()
    ang:RotateAroundAxis(ang:Up(), 90)
    ang:RotateAroundAxis(ang:Forward(), 90)
    
    cam.Start3D2D(pos, ang, 0.1)
        draw.RoundedBox(8, -100, -40, 200, 80, Color(0, 0, 0, 200))
        
        local requiredLevel = ent:GetNWInt("ClearanceLevel", 1)
        local levelData = DKEYCARDS.ClearanceLevels[requiredLevel]
        
        if not levelData then
            levelData = {name = "Unknown", color = Color(255, 255, 255)}
        end
        
        draw.SimpleText("CLEARANCE REQUIRED", "DermaLarge", 0, -20, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("LEVEL " .. requiredLevel .. " - " .. levelData.name, "DermaDefault", 0, 0, levelData.color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        
        local playerLevel = 0
        for _, weapon in pairs(ply:GetWeapons()) do
            if weapon.DKeycard_Level then
                playerLevel = math.max(playerLevel, weapon.DKeycard_Level)
            end
        end
        
        local statusColor = playerLevel >= requiredLevel and COLOR_SUCCESS or COLOR_DENIED
        draw.SimpleText("Your Level: " .. playerLevel, "DermaDefault", 0, 20, statusColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    cam.End3D2D()
end
hook.Add("PostDrawOpaqueRenderables", "DKeycards_DrawHUD", DrawKeycardHUD)

local function DrawDoorHUD()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    
    local tr = ply:GetEyeTrace()
    local ent = tr.Entity
    
    if not IsValid(ent) or not ent:GetNWBool("DKeycard_Controlled") then return end
    if tr.Fraction > 0.1 then return end
    
    local pos = ent:GetPos() + ent:GetUp() * 10
    local ang = ent:GetAngles()
    ang:RotateAroundAxis(ang:Up(), 90)
    
    local keypad = ent:GetNWEntity("DKeycard_Keypad")
    local requiredLevel = IsValid(keypad) and keypad:GetNWInt("ClearanceLevel", 1) or 1
    
    cam.Start3D2D(pos, ang, 0.1)
        draw.RoundedBox(8, -80, -25, 160, 50, Color(0, 0, 0, 200))
        
        draw.SimpleText("KEYCARD REQUIRED", "DermaLarge", 0, -10, Color(255, 150, 0), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("Level " .. requiredLevel .. " Access", "DermaDefault", 0, 10, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    cam.End3D2D()
end
hook.Add("PostDrawOpaqueRenderables", "DKeycards_DrawDoorHUD", DrawDoorHUD)

local function CreateSuccessEffect(data)
    local pos = data:GetOrigin()
    local emitter = ParticleEmitter(pos)
    
    for i = 1, 10 do
        local particle = emitter:Add("effects/yellowflare", pos + Vector(math.random(-10, 10), math.random(-10, 10), math.random(-10, 10)))
        if particle then
            particle:SetVelocity(Vector(math.random(-50, 50), math.random(-50, 50), math.random(50, 100)))
            particle:SetLifeTime(0)
            particle:SetDieTime(1)
            particle:SetStartAlpha(255)
            particle:SetEndAlpha(0)
            particle:SetStartSize(5)
            particle:SetEndSize(0)
            particle:SetColor(0, 255, 0)
        end
    end
    
    emitter:Finish()
end
effects.Register(CreateSuccessEffect, "dkeycard_success")

local function CreateDeniedEffect(data)
    local pos = data:GetOrigin()
    local emitter = ParticleEmitter(pos)
    
    for i = 1, 15 do
        local particle = emitter:Add("effects/yellowflare", pos + Vector(math.random(-15, 15), math.random(-15, 15), math.random(-15, 15)))
        if particle then
            particle:SetVelocity(Vector(math.random(-30, 30), math.random(-30, 30), math.random(-30, 30)))
            particle:SetLifeTime(0)
            particle:SetDieTime(0.5)
            particle:SetStartAlpha(255)
            particle:SetEndAlpha(0)
            particle:SetStartSize(3)
            particle:SetEndSize(0)
            particle:SetColor(255, 0, 0)
        end
    end
    
    emitter:Finish()
end
effects.Register(CreateDeniedEffect, "dkeycard_denied")