local CharacterLoader = {}

-- ++++++++++++++++++++

function CharacterLoader:setPlayerCharacter(player: Player, character: Model)
    if player.Character then
        player.Character:Destroy()
    end

    character.Name = player.Name
    -- 名称一致后，先转回nil再回到workspace刷新视角
    character.Parent = nil
    player.Character = character
    character.Parent = workspace
end

-- ++++++++++++++++++++

return CharacterLoader