SWEP.PrintName = "Keycard"
SWEP.Author = "Dennid"
SWEP.Purpose = "keycard for SCP clearance system"
SWEP.Category = "SCP - Keycards"

SWEP.Spawnable = false
SWEP.AdminOnly = false

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = 0
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = 0
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

SWEP.Weight = 1
SWEP.AutoSwitchTo = false
SWEP.AutoSwitchFrom = false

SWEP.Slot = 4
SWEP.SlotPos = 1

SWEP.DrawAmmo = false
SWEP.DrawCrosshair = false

SWEP.ViewModel = ""
SWEP.WorldModel = ""

SWEP.DKeycard_Level = 1
SWEP.DKeycard_Name = "Base Keycard"
SWEP.DKeycard_Color = Color(255, 255, 255)

function SWEP:Initialize()
    self:SetHoldType("slam")
    
    if self.KeycardModel then
        self:SetModel(self.KeycardModel)
    end
end

function SWEP:Deploy()
    if CLIENT then
        chat.AddText(Color(0, 150, 255), "[KEYCARD] ", color_white, "Equipped " .. self.DKeycard_Name .. " (Level " .. self.DKeycard_Level .. ")")
    end
    return true
end

function SWEP:PrimaryAttack()
    if CLIENT then
        chat.AddText(self.DKeycard_Color, "[" .. self.DKeycard_Name .. "] ", color_white, "Clearance Level: " .. self.DKeycard_Level)
    end
    
    self:SetNextPrimaryFire(CurTime() + 1)
end

function SWEP:SecondaryAttack()
    self:PrimaryAttack()
end

function SWEP:Reload()
    return false
end

function SWEP:CanBePickedUpByNPCs()
    return false
end

function SWEP:ShouldDropOnDie()
    return true
end

function SWEP:DrawWorldModel()
    local owner = self:GetOwner()
    
    if IsValid(owner) and self.KeycardModel then
        local hand = owner:LookupBone("ValveBiped.Bip01_R_Hand")
        if hand then
            local pos, ang = owner:GetBonePosition(hand)
            pos = pos + ang:Forward() * 3 + ang:Right() * 1 + ang:Up() * -2
            ang:RotateAroundAxis(ang:Right(), 90)
            ang:RotateAroundAxis(ang:Up(), 0)
            
            self:SetRenderOrigin(pos)
            self:SetRenderAngles(ang)
            self:DrawModel()
            self:SetRenderOrigin()
            self:SetRenderAngles()
        end
    else
        self:DrawModel()
    end
end

if CLIENT then
    function SWEP:ViewModelDrawn()
        if self.KeycardModel then
            local vm = LocalPlayer():GetViewModel()
            if IsValid(vm) then
                local pos = vm:GetPos() + vm:GetAngles():Forward() * 10 + vm:GetAngles():Right() * 5 + vm:GetAngles():Up() * -5
                local ang = vm:GetAngles()
                ang:RotateAroundAxis(ang:Right(), -90)
                
                local tempEnt = ClientsideModel(self.KeycardModel)
                if IsValid(tempEnt) then
                    tempEnt:SetPos(pos)
                    tempEnt:SetAngles(ang)
                    tempEnt:SetMaterial("")
                    tempEnt:DrawModel()
                    tempEnt:Remove()
                end
            end
        end
    end
end
