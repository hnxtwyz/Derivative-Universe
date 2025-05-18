local RemotePortService = require(game.ReplicatedStorage.Util.Remote.RemotePortService)
local Battle = require(game.ServerScriptService.ServerModule.Battle)
local CharacterLoader = require(game.ReplicatedStorage.Util.Character.CharacterLoader)

local BattleInit = {}

local _battlePortCollection = RemotePortService:getOrCreateRemotePortCollection("Battle")
local _battleJoinFunction = _battlePortCollection:getOrCreateRemoteFunction("BattleJoinFunction")
local _championActionEvent = _battlePortCollection:getOrCreateRemoteEvent("ChampionActionEvent")

local battle = Battle.new(1)

local _playerUnitNoCollection = {}

-- ++++++++++++++++++++

-- 战斗初始化

-- ++++++++++++++++++++

function BattleInit:init()
    self:_listenPlayerJoin()
    self:_addRobot()
    self:_listenPlayerChampionAction()
end

function BattleInit:_listenPlayerJoin()
    _battleJoinFunction.OnServerInvoke = function(player, championNo)
        local playerChampionModel = workspace.C0:Clone()
        local unitNo = battle:addUnit(playerChampionModel)
        CharacterLoader:setPlayerCharacter(player, playerChampionModel)
        _playerUnitNoCollection[player] = unitNo

        -- 返回加入成功信息
        return true, "Successfully joined the battle!"
    end
end

function BattleInit:_addRobot()
    local robotModel = workspace.Noob
    local unitNo = battle:addUnit(robotModel)
end

-- ++++++++++++++++++++

-- 监听动作和技能

-- ++++++++++++++++++++

function BattleInit:_listenPlayerChampionAction()
    _championActionEvent.OnServerEvent:Connect(function(player, actionName)
        local unitNo = _playerUnitNoCollection[player]
        if unitNo then
            if actionName == "R" then
                battle.unitOperationCollection[unitNo].R()
            elseif actionName == "F" then
                battle.unitOperationCollection[unitNo].F()
            end
        end
    end)
end

return BattleInit
