if not SERVER then return end


function DKEYCARDS.GetPlayerClearanceLevel(ply)
    local highestLevel = 0
    
    for _, weapon in pairs(ply:GetWeapons()) do
        if weapon.DKeycard_Level then
            highestLevel = math.max(highestLevel, weapon.DKeycard_Level)
        end
    end
    
    return highestLevel
end

function DKEYCARDS.HasRequiredClearance(ply, requiredLevel)
    if requiredLevel == 0 then return true end
    return DKEYCARDS.GetPlayerClearanceLevel(ply) >= requiredLevel
end

concommand.Add("dkeycards_give", function(ply, cmd, args)
    if not ply:IsAdmin() then return end
    
    local target = ply
    local level = tonumber(args[1]) or 1
    
    if args[2] then
        target = player.GetByName(args[2])
        if not IsValid(target) then
            ply:ChatPrint("Player not found!")
            return
        end
    end
    
    if level < 1 or level > 5 then
        ply:ChatPrint("Invalid clearance level! Use 1-5")
        return
    end
    
    local className = "dkeycard_level" .. level
    target:Give(className)
    
    ply:ChatPrint("Gave Level " .. level .. " keycard to " .. target:Name())
    target:ChatPrint("You received a Level " .. level .. " keycard!")
end)