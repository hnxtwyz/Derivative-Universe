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

local _findUnitCollection = ObjectTagService:getOrCreateSotCollection("Battle1_FindUnitSotCollection")

local _unitTeamCollection = ObjectTagService:getOrCreateSotCollection("Battle1_UnitTeamSotCollection")

local _unitAttributeListCollection = PropertyListService:getOrCreatePropertyListCollection("Battle1_UnitAttributeListCollection")

local _unitSignalListCollection = RemoteSignalService:getOrCreateSignalListCollection("Battle1_UnitSignalListCollection")

local _unitOperation = {}

-- ++++++++++++++++++++

-- 战斗初始化

-- ++++++++++++++++++++

function BattleInit:init()
    self:_listenPlayerJoin()
    self:_listenPlayerChampionAction()
    self:_addRobot()
end

function BattleInit:_listenPlayerJoin()
    _battleJoinFunction.OnServerInvoke = function(player, championNo)
        local playerChampionModel = workspace.C0:Clone()
        self:_initUnit(playerChampionModel)
        CharacterLoader:setPlayerCharacter(player, playerChampionModel)

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
            fireball.Position = player.Character.HumanoidRootPart.Position + player.Character.HumanoidRootPart.CFrame.LookVector * 10
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
                    local attackingUnitNo = _findUnitCollection:getObjectTag(hit)
                    if attackingUnitNo and not unitRecord[attackingUnitNo] then
                        unitRecord[attackingUnitNo] = false  -- 暂时取消重复检测
                        _unitOperation[attackingUnitNo].normalAttack(10)
                    end
                end
            end)
        end
    end)
end

function BattleInit:_addRobot()
    local robotModel = workspace.Noob
    self:_initUnit(robotModel)
end

-- ++++++++++++++++++++

-- 单位添加逻辑

-- ++++++++++++++++++++

local DEFAULT_TEAM_NAME = "Default"

-- 分配单位编号
local currentUnitNo = 0

local function _getNextUnitNo() : number
    currentUnitNo += 1
    return currentUnitNo
end

function BattleInit:_initUnit(unitModel: Model)
    local unitNo = _getNextUnitNo()

    -- 模型相关
    local unitParts = ModelComponent.new(unitModel):getChildParts()
    for _, part in unitParts do
        _findUnitCollection:setObjectTag(part, unitNo)
    end

    -- 队伍相关
    _unitTeamCollection:setObjectTag(unitNo, DEFAULT_TEAM_NAME)

    -- 属性设置
    local unitAttributeList = _unitAttributeListCollection:getOrCreatePropertyList(unitNo)
    unitAttributeList:setProperties({
        health = 100,
        dead = false,
    })

    -- 属性信号
    local unitSignalList = _unitSignalListCollection:getOrCreateSignalList(unitNo)
    local healthGainedSignal = unitSignalList:getOrCreateSignal("HealthGained")
    local healthLostSignal = unitSignalList:getOrCreateSignal("HealthLost")
    local diedSignal = unitSignalList:getOrCreateSignal("Died")

    healthLostSignal:Connect(function(val)
        local currentHealth = unitAttributeList:getProperty("health")
        if currentHealth <= 0 then
            diedSignal:Fire()
        end
    end)

    diedSignal:Connect(function()
        unitAttributeList:setProperty("dead", true)
        unitModel.Humanoid.Health = 0
    end)

    -- 意外死亡设置
    unitModel.Humanoid.Died:Connect(function()
        local isDead = unitAttributeList:getProperty("dead")
        if not isDead then
            diedSignal:Fire()
        end
    end)

    -- 单位操作相关
    _unitOperation[unitNo] = {}

    _unitOperation[unitNo].normalAttack = function(val: number)
        local currentHealth = unitAttributeList:getProperty("health")
        local newHealth = math.clamp(currentHealth - val, 0, 100)
        unitAttributeList:setProperty("health", newHealth)
        healthLostSignal:Fire(val)
    end
end

return BattleInit
