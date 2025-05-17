local Players = game:GetService("Players")

local PlayerManage = {}

function PlayerManage:disableCharacterAutoLoad()
    Players.CharacterAutoLoads = false
    Players.PlayerAdded:Connect(function(player)
        player:LoadCharacter()
    end)
end

function PlayerManage:restrictPlayerCameraZoom()
    Players.PlayerAdded:Connect(function(player)
        player.CameraMaxZoomDistance = 12
        player.CameraMinZoomDistance = 12
    end)
end

return PlayerManage
