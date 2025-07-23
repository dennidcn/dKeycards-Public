// keycard system tool gun config

TOOL.Category = "SCP - Keycards"
TOOL.Name = "Keycard System"
TOOL.Command = nil
TOOL.ConfigName = ""

TOOL.ClientConVar["clearance_level"] = "1"
TOOL.ClientConVar["auto_close_time"] = "5"
TOOL.ClientConVar["password"] = ""
TOOL.ClientConVar["require_password"] = "0"

if CLIENT then
    language.Add("tool.dkeycard_config.name", "Keycard System")
    language.Add("tool.dkeycard_config.desc", "Configure keypads and doors for the keycard system")
    language.Add("tool.dkeycard_config.0", "Left click: Create/configure keypad | Right click: Select keypad then link door | Reload: Remove/unlink")
end

function TOOL:LeftClick(trace)
    local ent = trace.Entity
    if not IsValid(ent) then return false end
    
    if SERVER then
        local clearanceLevel = self:GetClientNumber("clearance_level")
        local password = self:GetClientInfo("password")
        local requirePassword = self:GetClientNumber("require_password") == 1
        
        if ent:GetClass() == "dkeycard_keypad" then
            // Configure keypad clearance level and password
            ent:SetClearanceLevel(clearanceLevel)
            ent:SetPassword(password, requirePassword)
            
            if requirePassword and password ~= "" then
                self:GetOwner():ChatPrint("Keypad set to Level " .. clearanceLevel .. " with password protection")
            else
                self:GetOwner():ChatPrint("Keypad clearance level set to " .. clearanceLevel .. " (no password)")
            end
            return true
        else
            // Create a new keypad based off trace hit and config
            local keypad = ents.Create("dkeycard_keypad")
            if IsValid(keypad) then
                keypad:SetPos(trace.HitPos)
                keypad:SetAngles(trace.HitNormal:Angle() + Angle(90, 0, 0))
                keypad:Spawn()
                keypad:Activate()
                keypad:SetClearanceLevel(clearanceLevel)
                keypad:SetPassword(password, requirePassword)
                
                undo.Create("DKeycard Keypad")
                undo.AddEntity(keypad)
                undo.SetPlayer(self:GetOwner())
                undo.Finish()
                
                if requirePassword and password ~= "" then
                    self:GetOwner():ChatPrint("Created Level " .. clearanceLevel .. " keypad with password protection")
                else
                    self:GetOwner():ChatPrint("Created Level " .. clearanceLevel .. " keypad")
                end
                return true
            end
        end
    end
    
    return false
end

function TOOL:RightClick(trace)
    local ent = trace.Entity
    if not IsValid(ent) then return false end
    
    if SERVER then
        if ent:GetClass() == "dkeycard_keypad" then
            
            self:GetOwner().DKeycard_SelectedKeypad = ent
            self:GetOwner():ChatPrint("Keypad selected. Now right-click on a door to link them.")
            return true
        elseif self:GetOwner().DKeycard_SelectedKeypad and IsValid(self:GetOwner().DKeycard_SelectedKeypad) then
            local keypad = self:GetOwner().DKeycard_SelectedKeypad
            keypad:SetDoor(ent)
            
            // marks door as keycard/keypad controlled
            ent:SetNWBool("DKeycard_Controlled", true)
            
            
            if not ent.DKeycard_LinkedKeypads then
                ent.DKeycard_LinkedKeypads = {}
            end
            
            // Add keypad to the doors keypad list
            local keypadFound = false
            for _, linkedKeypad in pairs(ent.DKeycard_LinkedKeypads) do
                if linkedKeypad == keypad then
                    keypadFound = true
                    break
                end
            end
            
            if not keypadFound then
                table.insert(ent.DKeycard_LinkedKeypads, keypad)
            end
            
            
            ent:SetNWEntity("DKeycard_Keypad", keypad)
            
            
            if not ent.DKeycard_ControlsSetup then
                
                if not ent.DKeycard_OriginalUse then
                    ent.DKeycard_OriginalUse = ent.Use
                end
            if not ent.DKeycard_OriginalAcceptInput then
               
                if ent.AcceptInput and type(ent.AcceptInput) == "function" then
                    ent.DKeycard_OriginalAcceptInput = ent.AcceptInput
                else
                    print("[DKeycard Debug] Door has no AcceptInput method, using fallback")
                    ent.DKeycard_OriginalAcceptInput = nil
                end
            end
            if not ent.DKeycard_OriginalTouch then
                ent.DKeycard_OriginalTouch = ent.Touch
            end

            // Force door to close and lock
            ent:Fire("Close")
            ent:Fire("Lock")

            ent:SetKeyValue("spawnflags", "1024")
            ent:SetKeyValue("locked", "1")
        
            // overrides all door interaction
            ent.Use = function(self, activator, caller, useType, value)
                if IsValid(activator) and activator:IsPlayer() then
                    local linkedKeypad = self:GetNWEntity("DKeycard_Keypad")
                    if IsValid(linkedKeypad) then
                        activator:ChatPrint("This door requires keycard access. Use the keypad (Level " .. linkedKeypad:GetClearanceLevel() .. " required).")
                    else
                        activator:ChatPrint("This door is keycard controlled but no keypad is linked.")
                    end
                end
                return false
            end
            
            // too much to comment... cba maybe

            ent.AcceptInput = function(self, inputName, activator, caller, data)
                local callerIsKeypad = false
                if self.DKeycard_LinkedKeypads then
                    for _, linkedKeypad in pairs(self.DKeycard_LinkedKeypads) do
                        if IsValid(linkedKeypad) and caller == linkedKeypad then
                            callerIsKeypad = true
                            break
                        end
                    end
                end
                
                
                local primaryKeypad = self:GetNWEntity("DKeycard_Keypad")
                if IsValid(primaryKeypad) and caller == primaryKeypad then
                    callerIsKeypad = true
                end
                
                
                if inputName == "Open" or inputName == "Close" then
                    print("[DKeycard Debug] Door AcceptInput: " .. inputName .. " from caller: " .. tostring(caller) .. " (class: " .. (IsValid(caller) and caller:GetClass() or "N/A") .. ")")
                    print("[DKeycard Debug] Caller is keypad: " .. tostring(callerIsKeypad))
                end
                
               
                if callerIsKeypad then
                    print("[DKeycard Debug] Allowing " .. inputName .. " from keypad")
                    if inputName == "Open" then
                        
                        self.DKeycard_TemporaryUnlock = true
                        self:Fire("Unlock")
                    end
                    
                    
                    local result = true
                    if self.DKeycard_OriginalAcceptInput then
                        result = self.DKeycard_OriginalAcceptInput(self, inputName, activator, caller, data)
                    else
                        
                        self:Fire(inputName, data or "", 0)
                    end
                    
                    if inputName == "Close" then
                        
                        timer.Simple(0.1, function()
                            if IsValid(self) then
                                self:Fire("Lock")
                                self.DKeycard_TemporaryUnlock = false
                            end
                        end)
                    end
                    return result
                end
                
                
                if inputName == "Open" and self.DKeycard_TemporaryUnlock then
                    print("[DKeycard Debug] Allowing Open due to temporary unlock state")
                    local result = true
                    if self.DKeycard_OriginalAcceptInput then
                        result = self.DKeycard_OriginalAcceptInput(self, inputName, activator, caller, data)
                    else
                        
                        self:Fire(inputName, data or "", 0)
                    end
                    return result
                end
                
                
                if inputName == "Close" and (not caller or not caller:IsPlayer()) then
                    local result = true
                    if self.DKeycard_OriginalAcceptInput then
                        result = self.DKeycard_OriginalAcceptInput(self, inputName, activator, caller, data)
                    else
                        
                        self:Fire(inputName, data or "", 0)
                    end
                    timer.Simple(0.1, function()
                        if IsValid(self) then
                            self:Fire("Lock")
                        end
                    end)
                    return result
                end
                
                
                if inputName == "Open" or inputName == "Toggle" or inputName == "Unlock" or inputName == "Use" then
                    if IsValid(activator) and activator:IsPlayer() then
                        activator:ChatPrint("This door requires keycard access.")
                    elseif IsValid(caller) and caller:IsPlayer() then
                        caller:ChatPrint("This door requires keycard access.")
                    end
                    print("[DKeycard Debug] Blocking " .. inputName .. " from player/unauthorized source")
                    return false
                end
                
                
                if self.DKeycard_OriginalAcceptInput then
                    return self.DKeycard_OriginalAcceptInput(self, inputName, activator, caller, data)
                else
                   
                    return true
                end
            end
            
            
            ent.Touch = function(self, other)
                if IsValid(other) and other:IsPlayer() then
                    return
                end
                if self.DKeycard_OriginalTouch then
                    return self.DKeycard_OriginalTouch(self, other)
                end
            end
            
            ent.DKeycard_ControlsSetup = true
            end
            
            local thinkName = "DKeycard_EnforceLock_" .. ent:EntIndex()
            hook.Add("Think", thinkName, function()
                if not IsValid(ent) or not ent:GetNWBool("DKeycard_Controlled") then
                    hook.Remove("Think", thinkName)
                    return
                end
                

                if not ent.DKeycard_TemporaryUnlock then
                    ent:Fire("Lock")
                end
            end)
            
            self:GetOwner():ChatPrint("Keypad (Level " .. keypad:GetClearanceLevel() .. ") linked to door. Total keypads on this door: " .. (#ent.DKeycard_LinkedKeypads or 1))
            self:GetOwner().DKeycard_SelectedKeypad = nil
            return true
        end
    end
    
    return false
end

function TOOL:Reload(trace)
    local ent = trace.Entity
    if not IsValid(ent) then return false end
    
    if SERVER then
        if ent:GetClass() == "dkeycard_keypad" then
            local linkedDoor = ent:GetDoor()
            if IsValid(linkedDoor) then
                if linkedDoor.DKeycard_LinkedKeypads then
                    for i, keypad in ipairs(linkedDoor.DKeycard_LinkedKeypads) do
                        if keypad == ent then
                            table.remove(linkedDoor.DKeycard_LinkedKeypads, i)
                            break
                        end
                    end
                    
                    if #linkedDoor.DKeycard_LinkedKeypads == 0 then
                        local thinkName = "DKeycard_EnforceLock_" .. linkedDoor:EntIndex()
                        hook.Remove("Think", thinkName)
                        
                        linkedDoor:SetNWBool("DKeycard_Controlled", false)
                        linkedDoor:SetNWEntity("DKeycard_Keypad", NULL)
                        linkedDoor.DKeycard_LinkedKeypads = nil
                        linkedDoor.DKeycard_ControlsSetup = nil
                        
                        if linkedDoor.DKeycard_OriginalUse then
                            linkedDoor.Use = linkedDoor.DKeycard_OriginalUse
                            linkedDoor.DKeycard_OriginalUse = nil
                        end
                        
                        if linkedDoor.DKeycard_OriginalAcceptInput then
                            linkedDoor.AcceptInput = linkedDoor.DKeycard_OriginalAcceptInput
                            linkedDoor.DKeycard_OriginalAcceptInput = nil
                        end
                        
                        if linkedDoor.DKeycard_OriginalTouch then
                            linkedDoor.Touch = linkedDoor.DKeycard_OriginalTouch
                            linkedDoor.DKeycard_OriginalTouch = nil
                        end
                        
                        
                        linkedDoor:Fire("Unlock")
                        linkedDoor:SetKeyValue("spawnflags", "0")
                        linkedDoor:SetKeyValue("locked", "0")
                        
                        self:GetOwner():ChatPrint("Last keypad removed - door restored to normal function")
                    else
                        linkedDoor:SetNWEntity("DKeycard_Keypad", linkedDoor.DKeycard_LinkedKeypads[1])
                        self:GetOwner():ChatPrint("Keypad removed - " .. #linkedDoor.DKeycard_LinkedKeypads .. " keypad(s) remaining")
                    end
                else
                    local thinkName = "DKeycard_EnforceLock_" .. linkedDoor:EntIndex()
                    hook.Remove("Think", thinkName)
                    
                    linkedDoor:SetNWBool("DKeycard_Controlled", false)
                    linkedDoor:SetNWEntity("DKeycard_Keypad", NULL)
                    
                    if linkedDoor.DKeycard_OriginalUse then
                        linkedDoor.Use = linkedDoor.DKeycard_OriginalUse
                        linkedDoor.DKeycard_OriginalUse = nil
                    end
                    
                    if linkedDoor.DKeycard_OriginalAcceptInput then
                        linkedDoor.AcceptInput = linkedDoor.DKeycard_OriginalAcceptInput
                        linkedDoor.DKeycard_OriginalAcceptInput = nil
                    end
                    
                    if linkedDoor.DKeycard_OriginalTouch then
                        linkedDoor.Touch = linkedDoor.DKeycard_OriginalTouch
                        linkedDoor.DKeycard_OriginalTouch = nil
                    end
                    
                    linkedDoor:Fire("Unlock")
                    linkedDoor:SetKeyValue("spawnflags", "0")
                    linkedDoor:SetKeyValue("locked", "0")
                    
                    self:GetOwner():ChatPrint("Door unlinked and restored to normal function")
                end
            end
            
            ent:Remove()
            self:GetOwner():ChatPrint("Keypad removed")
            return true
        elseif ent:GetNWBool("DKeycard_Controlled") then
            local thinkName = "DKeycard_EnforceLock_" .. ent:EntIndex()
            hook.Remove("Think", thinkName)
            
            if ent.DKeycard_LinkedKeypads then
                for _, keypad in pairs(ent.DKeycard_LinkedKeypads) do
                    if IsValid(keypad) then
                        keypad:SetDoor(NULL)
                    end
                end
                ent.DKeycard_LinkedKeypads = nil
            end
            
            local linkedKeypad = ent:GetNWEntity("DKeycard_Keypad")
            if IsValid(linkedKeypad) then
                linkedKeypad:SetDoor(NULL)
            end
            
            ent:SetNWBool("DKeycard_Controlled", false)
            ent:SetNWEntity("DKeycard_Keypad", NULL)
            ent.DKeycard_ControlsSetup = nil
            
            if ent.DKeycard_OriginalUse then
                ent.Use = ent.DKeycard_OriginalUse
                ent.DKeycard_OriginalUse = nil
            end
            
            if ent.DKeycard_OriginalAcceptInput then
                ent.AcceptInput = ent.DKeycard_OriginalAcceptInput
                ent.DKeycard_OriginalAcceptInput = nil
            end
            
            if ent.DKeycard_OriginalTouch then
                ent.Touch = ent.DKeycard_OriginalTouch
                ent.DKeycard_OriginalTouch = nil
            end
            
            ent:Fire("Unlock")
            ent:SetKeyValue("spawnflags", "0")
            ent:SetKeyValue("locked", "0")
            
            self:GetOwner():ChatPrint("Door unlinked from all keypads and restored to normal function")
            return true
        end
    end
    
    return false
end

function TOOL.BuildCPanel(CPanel)
    CPanel:AddControl("Header", {Description = "Keycard System Configuration"})
    CPanel:AddControl("Label", {Text = "Left click: Set keypad clearance level or create new keypad"})
    CPanel:AddControl("Label", {Text = "Right click: Select keypad, then right-click door to link"})
    CPanel:AddControl("Label", {Text = "Reload: Remove keypad or unlink door from keycard system"})
    CPanel:AddControl("Label", {Text = ""})
    CPanel:AddControl("Label", {Text = "How to use:"})
    CPanel:AddControl("Label", {Text = "1. Left-click to create a keypad"})
    CPanel:AddControl("Label", {Text = "2. Right-click the keypad to select it"})
    CPanel:AddControl("Label", {Text = "3. Right-click a door to link it"})
    
    CPanel:AddControl("Slider", {
        Label = "Clearance Level",
        Type = "Integer",
        Min = "0",
        Max = "5",
        Command = "dkeycard_config_clearance_level"
    })
    
    CPanel:AddControl("CheckBox", {
        Label = "Require Password",
        Command = "dkeycard_config_require_password"
    })
    
    CPanel:AddControl("TextBox", {
        Label = "Password (leave empty for no password)",
        Command = "dkeycard_config_password",
        MaxLength = "20"
    })
    
    CPanel:AddControl("Slider", {
        Label = "Auto Close Time (seconds)",
        Type = "Integer",
        Min = "1",
        Max = "30",
        Command = "dkeycard_config_auto_close_time"
    })
    
    CPanel:AddControl("Label", {Text = "Clearance Levels:"})
    CPanel:AddControl("Label", {Text = "Level 0: No keycard required"})
    CPanel:AddControl("Label", {Text = "Level 1: Blue Keycard"})
    CPanel:AddControl("Label", {Text = "Level 2: Green Keycard"})
    CPanel:AddControl("Label", {Text = "Level 3: Yellow Keycard"})
    CPanel:AddControl("Label", {Text = "Level 4: Red Keycard"})
    CPanel:AddControl("Label", {Text = "Level 5: White Keycard"})
end
