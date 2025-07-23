AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

if SERVER then
    util.AddNetworkString("DKeycards_AccessGranted")
    util.AddNetworkString("DKeycards_AccessDenied")
    util.AddNetworkString("DKeycards_RequestPassword")
    util.AddNetworkString("DKeycards_SubmitPassword")
end

local function GetPlayerClearanceLevel(ply)
    local highestLevel = 0
    
    for _, weapon in pairs(ply:GetWeapons()) do
        if weapon.DKeycard_Level then
            highestLevel = math.max(highestLevel, weapon.DKeycard_Level)
        end
    end
    
    return highestLevel
end

local function HasRequiredClearance(ply, requiredLevel)
    if requiredLevel == 0 then return true end
    return GetPlayerClearanceLevel(ply) >= requiredLevel
end

function ENT:Initialize()
    self:SetModel("models/props/keycard_scanner_half_fd1.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)
    
    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
        phys:SetMass(50)
    end
    
    self.DKeypad_ClearanceLevel = 1
    self.DKeypad_Door = nil
    self.DKeypad_Password = ""
    self.DKeypad_RequirePassword = false
    
    self:SetNWInt("ClearanceLevel", self.DKeypad_ClearanceLevel)
    self:SetNWBool("RequirePassword", self.DKeypad_RequirePassword)
end

function ENT:Use(activator, caller, useType, value)
    if not IsValid(activator) or not activator:IsPlayer() then return end
    
    local requiredLevel = self.DKeypad_ClearanceLevel
    local playerLevel = GetPlayerClearanceLevel(activator)
    
    if HasRequiredClearance(activator, requiredLevel) then
        if self.DKeypad_RequirePassword and self.DKeypad_Password ~= "" then
            net.Start("DKeycards_RequestPassword")
            net.WriteEntity(self)
            net.Send(activator)
            return
        end
        
        self:GrantAccess(activator)
    else
        net.Start("DKeycards_AccessDenied")
        net.WriteEntity(self)
        net.WriteUInt(requiredLevel, 8)
        net.WriteUInt(playerLevel, 8)
        net.Send(activator)
        
        self:EmitSound("buttons/button10.wav", 75, 80)
        
        print("[DKeycards] " .. activator:Name() .. " denied access to Level " .. requiredLevel .. " keypad (has Level " .. playerLevel .. " clearance)")
    end
end

function ENT:SetClearanceLevel(level)
    level = math.Clamp(level, 0, 5)
    self.DKeypad_ClearanceLevel = level
    self:SetNWInt("ClearanceLevel", level)
end

function ENT:GetClearanceLevel()
    return self.DKeypad_ClearanceLevel or 1
end

function ENT:SetPassword(password, requirePassword)
    self.DKeypad_Password = password or ""
    self.DKeypad_RequirePassword = requirePassword or false
    self:SetNWBool("RequirePassword", self.DKeypad_RequirePassword)
end

function ENT:ValidatePassword(password)
    return self.DKeypad_Password == password
end

function ENT:GrantAccess(activator)
    net.Start("DKeycards_AccessGranted")
    net.WriteEntity(self)
    net.Send(activator)
    
    if IsValid(self.DKeypad_Door) then
        self.DKeypad_Door.DKeycard_TemporaryUnlock = true
        
        timer.Simple(0.05, function()
            if IsValid(self.DKeypad_Door) and IsValid(self) then
                self.DKeypad_Door:AcceptInput("Open", activator, self, "")
            end
        end)
        
        timer.Create("DKeypad_AutoClose_" .. self:EntIndex(), 5, 1, function()
            if IsValid(self.DKeypad_Door) and IsValid(self) then
                self.DKeypad_Door.DKeycard_TemporaryUnlock = false
                self.DKeypad_Door:AcceptInput("Close", activator, self, "")
            end
        end)
    end
    
    self:EmitSound("buttons/button14.wav", 75, 100)
    
    print("[DKeycards] " .. activator:Name() .. " accessed Level " .. self.DKeypad_ClearanceLevel .. " keypad")
end

net.Receive("DKeycards_SubmitPassword", function(len, ply)
    local keypad = net.ReadEntity()
    local password = net.ReadString()
    
    if IsValid(keypad) and keypad:GetClass() == "dkeycard_keypad" then
        if keypad:ValidatePassword(password) then
            keypad:GrantAccess(ply)
        else
            net.Start("DKeycards_AccessDenied")
            net.WriteEntity(keypad)
            net.WriteUInt(keypad:GetClearanceLevel(), 8)
            net.WriteUInt(GetPlayerClearanceLevel(ply), 8)
            net.Send(ply)
            
            keypad:EmitSound("buttons/button10.wav", 75, 80)
            print("[DKeycards] " .. ply:Name() .. " entered wrong password for Level " .. keypad:GetClearanceLevel() .. " keypad")
        end
    end
end)

function ENT:SetDoor(door)
    self.DKeypad_Door = door
end

function ENT:GetDoor()
    return self.DKeypad_Door
end

function ENT:OnTakeDamage(dmginfo)
    return 0
end

duplicator.RegisterEntityClass("dkeycard_keypad", function(ply, data)
    local ent = ents.Create("dkeycard_keypad")
    if IsValid(ent) then
        ent:SetPos(data.Pos)
        ent:SetAngles(data.Angle)
        ent:Spawn()
        ent:Activate()
        
        if data.ClearanceLevel then
            ent:SetClearanceLevel(data.ClearanceLevel)
        end
        
        if data.Password and data.RequirePassword then
            ent:SetPassword(data.Password, data.RequirePassword)
        end
        
        return ent
    end
end, "Pos", "Angle", "ClearanceLevel", "Password", "RequirePassword")

function ENT:PreEntityCopy()
    local dupeInfo = {}
    dupeInfo.ClearanceLevel = self:GetClearanceLevel()
    dupeInfo.Password = self.DKeypad_Password
    dupeInfo.RequirePassword = self.DKeypad_RequirePassword
    duplicator.StoreEntityModifier(self, "DKeycardData", dupeInfo)
end

function ENT:PostEntityPaste(ply, ent, createdEntities)
    local dupeInfo = ent.EntityMods and ent.EntityMods.DKeycardData
    if dupeInfo then
        if dupeInfo.ClearanceLevel then
            self:SetClearanceLevel(dupeInfo.ClearanceLevel)
        end
        if dupeInfo.Password and dupeInfo.RequirePassword then
            self:SetPassword(dupeInfo.Password, dupeInfo.RequirePassword)
        end
    end
end
