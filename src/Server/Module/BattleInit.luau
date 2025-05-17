local Debris = game:GetService("Debris")

local RemotePortService = require(game.ReplicatedStorage.Util.Remote.RemotePortService)

local ObjectTagService = require(game.ReplicatedStorage.Util.Data.ObjectTagService)
local PropertyListService = require(game.ReplicatedStorage.Util.Data.PropertyListService)
local RemoteSignalService = require(game.ReplicatedStorage.Util.Data.RemoteSignalService)

local CharacterLoader = require(game.ReplicatedStorage.Util.Character.CharacterLoader)
local ModelComponent = require(game.ReplicatedStorage.Util.Model.ModelComponent)

local BattleInit = {}

-- ++++++++++++++++++++

-- 属性

-- ++++++++++++++++++++

local _battlePortCollection = RemotePortService:createRemotePortCollection("Battle")
local _battleJoinFunction = _battlePortCollection:createRemoteFunction("BattleJoinFunction")
local _championActionEvent = _battlePortCollection:createRemoteEvent("ChampionActionEvent")

local _findUnitSotCollection = ObjectTagService:getOrCreateSotCollection("Battle1_FindUnitSotCollection")

local _unitTeamSotCollection = ObjectTagService:getOrCreateSotCollection("Battle1_UnitTeamSotCollection")

local _unitAttributeListCollection = PropertyListService:getOrCreatePropertyListCollection("Battle1_UnitAttributeListCollection")

local _unitSignalListCollection = RemoteSignalService:getOrCreateSignalListCollection("Battle1_UnitSignalListCollection")

local _unitOperation = {}

-- ++++++++++++++++++++

-- 方法

-- ++++++++++++++++++++

function BattleInit:init()
    self:_listenPlayerJoin()
    self:_listenPlayerChampionAction()
end

local DEFAULT_TEAM_NAME = "Default"

-- 分配单位编号
local unitNo = 0

local function _getNextUnitNo() : number
    unitNo += 1
    return unitNo
end

function BattleInit:_listenPlayerJoin()
    _battleJoinFunction.OnServerInvoke = function(player, championNo)
        local playerUnitNo = _getNextUnitNo()
        -- 模型相关
        local championModel = workspace.C0:Clone()
        CharacterLoader:setPlayerCharacter(player, championModel)
        local characterParts = ModelComponent.new(championModel):getChildParts()
        for _, part in characterParts do
            _findUnitSotCollection:setObjectTag(part, playerUnitNo)
        end

        -- 队伍相关
        _unitTeamSotCollection:setObjectTag(playerUnitNo, DEFAULT_TEAM_NAME)

        -- 属性相关
        local playerUnitAttributeList = _unitAttributeListCollection:getOrCreatePropertyList(playerUnitNo)
        playerUnitAttributeList:setProperties({
            health = 100,
            dead = false,
        })

        -- 属性信号
        local playerUnitSignalList = _unitSignalListCollection:getOrCreateSignalList(playerUnitNo)
        local healthGainedSignal = playerUnitSignalList:getOrCreateSignal("HealthGained")
        local healthLostSignal = playerUnitSignalList:getOrCreateSignal("HealthLost")
        local diedSignal = playerUnitSignalList:getOrCreateSignal("Died")

        healthLostSignal:Connect(function(val)
            local currentHealth = playerUnitAttributeList:getProperty("health")
            if currentHealth <= 0 then
                diedSignal:Fire()
            end
        end)

        diedSignal:Connect(function()
            playerUnitAttributeList:setProperty("dead", true)
            championModel.Humanoid.Health = 0
        end)

        -- 意外死亡设置
        championModel.Humanoid.Died:Connect(function()
            local isDead = playerUnitAttributeList:getProperty("dead")
            if not isDead then
                diedSignal:Fire()
            end
        end)

        -- 单位操作相关
        _unitOperation[playerUnitNo] = {}

        _unitOperation[playerUnitNo].normalAttack = function(val: number)
            local currentHealth = playerUnitAttributeList:getProperty("health")
            local newHealth = math.clamp(currentHealth - val, 0, 100)
            playerUnitAttributeList:setProperty("health", newHealth)
            healthLostSignal:Fire(val)
        end

        -- 返回加入成功信息
        return true, "Successfully joined the battle!"
    end
end

function BattleInit:_listenPlayerChampionAction()
    _championActionEvent.OnServerEvent:Connect(function(player, actionName)
        if actionName == "R" then
            -- 释放一个火球
            local fireball = Instance.new("Part")
            fireball.Name = "Fireball"
            fireball.Parent = workspace
            fireball.Shape = Enum.PartType.Ball
            fireball.Size = Vector3.new(1, 1, 1)
            fireball.Position = player.Character.HumanoidRootPart.Position
            fireball.Color = Color3.fromRGB(255, 0, 0)
            fireball.Material = Enum.Material.Neon
            fireball.Anchored = true
            fireball.CanCollide = false
            fireball.CanTouch = true
            fireball.CanQuery = true

            Debris:AddItem(fireball, 5)

            local hitRecord = {}
            local unitRecord = {}
            fireball.Touched:Connect(function(hit)
                if not hitRecord[hit] then
                    hitRecord[hit] = false -- 暂时取消重复检测
                    local attackingUnitNo = _findUnitSotCollection:getObjectTag(hit)
                    if attackingUnitNo and not unitRecord[attackingUnitNo] then
                        unitRecord[attackingUnitNo] = false  -- 暂时取消重复检测
                        _unitOperation[attackingUnitNo].normalAttack(10)
                    end
                end
            end)
        end
    end)
end

return BattleInit
