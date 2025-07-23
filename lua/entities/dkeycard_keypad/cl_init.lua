include("shared.lua")

DKEYCARDS = DKEYCARDS or {}
DKEYCARDS.ClearanceLevels = DKEYCARDS.ClearanceLevels or {
    [0] = {name = "No Clearance", color = Color(128, 128, 128), model = nil},
    [1] = {name = "Level 1", color = Color(0, 100, 255), model = "models/labskeycards/bluekeycard.mdl"},
    [2] = {name = "Level 2", color = Color(0, 255, 0), model = "models/labskeycards/greenkeycard.mdl"},
    [3] = {name = "Level 3", color = Color(255, 255, 0), model = "models/labskeycards/yellowkeycard.mdl"},
    [4] = {name = "Level 4", color = Color(255, 0, 0), model = "models/labskeycards/red.mdl"},
    [5] = {name = "Level 5", color = Color(255, 255, 255), model = "models/labskeycards/normalkeycard.mdl"}
}

function ENT:Initialize()
    self.DKeypad_ClearanceLevel = self:GetNWInt("ClearanceLevel", 1)
    self.PulseTime = 0
    self.ScanlineOffset = 0
    self.AccessGrantedTime = 0
    self.AccessDeniedTime = 0
    self.IdleGlowPhase = 0
end

function ENT:Draw()
    self:DrawModel()
    
    self.PulseTime = self.PulseTime + FrameTime()
    self.ScanlineOffset = (self.ScanlineOffset + FrameTime() * 50) % 100
    self.IdleGlowPhase = self.IdleGlowPhase + FrameTime() * 2
    
    local pos = self:GetPos() + self:GetUp() * -0.95 + self:GetForward() * 5.2 + self:GetRight() * 3.85
    local ang = self:GetAngles()
    ang:RotateAroundAxis(ang:Up(), 90)
    ang:RotateAroundAxis(ang:Forward(), 60)

    
    local level = self:GetNWInt("ClearanceLevel", 1)
    local levelData = DKEYCARDS.ClearanceLevels[level]
    
    if not levelData then
        levelData = {name = "Unknown", color = Color(255, 255, 255)}
    end
    
    local ply = LocalPlayer()
    local dist = ply:GetPos():Distance(self:GetPos())
    local alpha = math.Clamp(255 - (dist - 100) * 2, 0, 255)
    
    if alpha > 0 then
        cam.Start3D2D(pos, ang, 0.067)
            local displayW, displayH = 78, 130
            
            local bgColor = Color(5, 15, 25, math.min(240, alpha))
            draw.RoundedBox(4, -displayW/2, -displayH/2, displayW, displayH, bgColor)
            
            local frameGlow = math.sin(self.IdleGlowPhase) * 0.3 + 0.7
            local frameColor = Color(levelData.color.r * frameGlow, levelData.color.g * frameGlow, levelData.color.b * frameGlow, math.min(200, alpha))
            draw.RoundedBox(4, -displayW/2 - 2, -displayH/2 - 2, displayW + 4, displayH + 4, frameColor)
            draw.RoundedBox(4, -displayW/2, -displayH/2, displayW, displayH, bgColor)
            
            draw.RoundedBox(2, -displayW/2 + 4, -displayH/2 + 4, displayW - 8, displayH - 8, Color(20, 30, 40, math.min(200, alpha)))
            
            local statusText = ""
            local statusColor = levelData.color
            local statusAlpha = alpha
            
            if CurTime() - self.AccessGrantedTime < 2 then
                statusText = "ACCESS\nGRANTED"
                statusColor = Color(0, 255, 0)
                statusAlpha = math.min(255, alpha + math.sin(self.PulseTime * 10) * 100)
            elseif CurTime() - self.AccessDeniedTime < 2 then
                statusText = "ACCESS\nDENIED"
                statusColor = Color(255, 0, 0)
                statusAlpha = math.min(255, alpha + math.sin(self.PulseTime * 15) * 100)
            else
                if not self:GetNWBool("RequirePassword", false) then
                    statusText = "READY"
                    statusAlpha = math.min(180, alpha)
                end
            end
            
            for i = 0, 6 do
                local lineY = -displayH/2 + 4 + ((self.ScanlineOffset + i * 12) % (displayH - 8))
                local lineAlpha = math.min(30, alpha * 0.3)
                local scanlineColor = Color(levelData.color.r, levelData.color.g, levelData.color.b, lineAlpha)
                draw.RoundedBox(0, -displayW/2 + 4, lineY, displayW - 8, 1, scanlineColor)
            end
            
            local levelText = "LEVEL " .. level
            local levelColor = Color(levelData.color.r, levelData.color.g, levelData.color.b, statusAlpha)
            
            surface.SetFont("DermaDefault")
            
            draw.SimpleText(levelText, "DermaDefault", 1, -displayH/2 + 18 + 1, Color(0, 0, 0, math.min(150, alpha)), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText(levelText, "DermaDefault", 0, -displayH/2 + 18, levelColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            
            if not self:GetNWBool("RequirePassword", false) then
                local nameColor = Color(200, 200, 200, math.min(200, alpha))
                surface.SetFont("DefaultFixedDropShadow")
                draw.SimpleText(levelData.name, "DefaultFixedDropShadow", 0, -displayH/2 + 35, nameColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
            
            if statusText ~= "" then
                local statusTextColor = Color(statusColor.r, statusColor.g, statusColor.b, statusAlpha)
                surface.SetFont("DermaDefault")
                local lines = string.Split(statusText, "\n")
                for i, line in ipairs(lines) do
                    local yOffset = -5 + (i - 1) * 15
                    draw.SimpleText(line, "DermaDefault", 0, yOffset, statusTextColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end
            end
            
            if self:GetNWBool("RequirePassword", false) and CurTime() - self.AccessGrantedTime >= 2 and CurTime() - self.AccessDeniedTime >= 2 then
                local padStartY = -25
                local buttonSize = 12
                local buttonSpacing = 14
                local padColor = Color(40, 50, 60, math.min(200, alpha))
                local textColor = Color(200, 200, 200, math.min(180, alpha))
                
                local keypadLayout = {
                    {"1", "2", "3"},
                    {"4", "5", "6"},
                    {"7", "8", "9"},
                    {"*", "0", "#"}
                }
                
                for row = 1, 4 do
                    for col = 1, 3 do
                        local x = -buttonSpacing + (col - 1) * buttonSpacing
                        local y = padStartY + (row - 1) * buttonSpacing
                        
                        draw.RoundedBox(1, x - buttonSize/2, y - buttonSize/2, buttonSize, buttonSize, padColor)
                        
                        surface.SetFont("DefaultFixedDropShadow")
                        draw.SimpleText(keypadLayout[row][col], "DefaultFixedDropShadow", x, y, textColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                    end
                end
            end            
            
            surface.SetFont("DefaultFixedDropShadow")
            local instructionColor = Color(150, 150, 150, math.min(180, alpha))
            
            if self:GetNWBool("RequirePassword", false) then
                draw.SimpleText("SWIPE CARD", "DefaultFixedDropShadow", 0, displayH/2 - 25, instructionColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                draw.SimpleText("ENTER CODE", "DefaultFixedDropShadow", 0, displayH/2 - 10, Color(255, 200, 100, math.min(160, alpha)), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            else
                draw.SimpleText("PRESS E", "DefaultFixedDropShadow", 0, displayH/2 - 15, instructionColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
            
            for i = 1, 4 do
                local cornerX = i <= 2 and -displayW/2 + 6 or displayW/2 - 6
                local cornerY = (i == 1 or i == 4) and -displayH/2 + 6 or displayH/2 - 6
                local cornerSize = 4
                local cornerColor = Color(levelData.color.r * 0.8, levelData.color.g * 0.8, levelData.color.b * 0.8, math.min(150, alpha))
                
                if i <= 2 then
                    draw.RoundedBox(0, cornerX, cornerY, cornerSize, 1, cornerColor)
                    draw.RoundedBox(0, cornerX, cornerY, 1, cornerSize, cornerColor)
                else
                    draw.RoundedBox(0, cornerX - cornerSize, cornerY, cornerSize, 1, cornerColor)
                    draw.RoundedBox(0, cornerX - 1, cornerY - cornerSize + 1, 1, cornerSize, cornerColor)
                end
            end
            
        cam.End3D2D()
    end
end

function ENT:Think()
    self.DKeypad_ClearanceLevel = self:GetNWInt("ClearanceLevel", 1)
end

net.Receive("DKeycards_AccessGranted", function()
    local keypad = net.ReadEntity()
    if IsValid(keypad) then
        keypad.AccessGrantedTime = CurTime()
        keypad.AccessDeniedTime = 0
    end
end)

net.Receive("DKeycards_AccessDenied", function()
    local keypad = net.ReadEntity()
    local requiredLevel = net.ReadUInt(8)
    local playerLevel = net.ReadUInt(8)
    
    if IsValid(keypad) then
        keypad.AccessDeniedTime = CurTime()
        keypad.AccessGrantedTime = 0
        
        local ply = LocalPlayer()
        if ply:GetPos():Distance(keypad:GetPos()) < 200 then
            chat.AddText(Color(255, 100, 100), "[KEYCARD] ", Color(255, 255, 255), "Access denied. Required: Level " .. requiredLevel .. " | Your Level: " .. playerLevel)
        end
    end
end)

net.Receive("DKeycards_RequestPassword", function()
    local keypad = net.ReadEntity()
    
    if IsValid(keypad) then
        local frame = vgui.Create("DFrame")
        frame:SetSize(300, 150)
        frame:SetTitle("Enter Keypad Password")
        frame:Center()
        frame:MakePopup()
        frame:SetDeleteOnClose(true)
        
        local label = vgui.Create("DLabel", frame)
        label:SetPos(20, 40)
        label:SetSize(260, 20)
        label:SetText("Enter password for Level " .. keypad:GetNWInt("ClearanceLevel", 1) .. " keypad:")
        
        local textEntry = vgui.Create("DTextEntry", frame)
        textEntry:SetPos(20, 65)
        textEntry:SetSize(260, 25)
        textEntry:SetPlaceholderText("Password...")
        textEntry:RequestFocus()
        
        local submitBtn = vgui.Create("DButton", frame)
        submitBtn:SetPos(20, 100)
        submitBtn:SetSize(120, 30)
        submitBtn:SetText("Submit")
        
        local cancelBtn = vgui.Create("DButton", frame)
        cancelBtn:SetPos(160, 100)
        cancelBtn:SetSize(120, 30)
        cancelBtn:SetText("Cancel")
        
        submitBtn.DoClick = function()
            local password = textEntry:GetValue()
            if password ~= "" then
                net.Start("DKeycards_SubmitPassword")
                net.WriteEntity(keypad)
                net.WriteString(password)
                net.SendToServer()
            end
            frame:Close()
        end
        
        cancelBtn.DoClick = function()
            frame:Close()
        end
        
        textEntry.OnEnter = function()
            submitBtn:DoClick()
        end
    end
end)
