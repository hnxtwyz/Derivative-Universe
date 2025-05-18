local Debris = game:GetService("Debris")

local ModelComponent = require(game.ReplicatedStorage.Util.Model.ModelComponent)
local CharacterController = require(game.ReplicatedStorage.Util.Character.CharacterController)

local UnitInitializer = {}
UnitInitializer.__index = UnitInitializer

function UnitInitializer.new(unitNo: number, unitModel: Model, context)
    local self = {}
    setmetatable(self, UnitInitializer)

    self._unitNo = unitNo
    self._unitModel = unitModel

    self._unitOperationCollection = context.unitOperationCollection
    self._unitOperation = context.unitOperationCollection[unitNo]

    self._findUnitCollection = context.findUnitCollection
    self._unitTeamCollection = context.unitTeamCollection
    self._unitAttributeList = context.unitAttributeList
    self._unitSignalList = context.unitSignalList

    return self
end

local DEFAULT_TEAM_NAME = "Default"

function UnitInitializer:initUnit()
    -- 模型相关
    local unitParts = ModelComponent:getChildParts(self._unitModel)
    for _, part in unitParts do
        self._findUnitCollection:setObjectTag(part, self._unitNo)
    end
    
    -- 队伍相关
    self._unitTeamCollection:setObjectTag(self._unitNo, DEFAULT_TEAM_NAME)

    -- 属性设置
    self._unitAttributeList:setProperties({
        health = 100,
        dead = false,
    })

    -- 属性信号
    local healthGainedSignal = self._unitSignalList:getOrCreateSignal("HealthGained")
    local healthLostSignal = self._unitSignalList:getOrCreateSignal("HealthLost")
    local diedSignal = self._unitSignalList:getOrCreateSignal("Died")

    healthLostSignal:Connect(function(val)
        local currentHealth = self._unitAttributeList:getProperty("health")
        if currentHealth <= 0 then
            diedSignal:Fire()
        end
    end)

    diedSignal:Connect(function()
        self._unitAttributeList:setProperty("dead", true)
        self._unitModel.Humanoid.Health = 0
    end)

    -- 意外死亡设置
    self._unitModel.Humanoid.Died:Connect(function()
        local isDead = self._unitAttributeList:getProperty("dead")
        if not isDead then
            diedSignal:Fire()
        end
    end)

    -- 单位操作相关
    self._unitOperation.normalAttack = function(val: number)
        local currentHealth = self._unitAttributeList:getProperty("health")
        local newHealth = math.clamp(currentHealth - val, 0, 100)
        self._unitAttributeList:setProperty("health", newHealth)
        healthLostSignal:Fire(val)
    end

    local characterController = CharacterController.new(self._unitModel)
    local isPause = false
    local cachedWalkSpeed = characterController:getWalkSpeed()
    local cachedJumpPower = characterController:getJumpPower()

    self._unitOperation.togglePause = function()
        if isPause then
            characterController:allowMovement(cachedWalkSpeed)
            characterController:allowJump(cachedJumpPower)
        else
            characterController:restrictMovement()
            characterController:restrictJump()
        end
        isPause = not isPause
    end

    self._unitOperation.R = function()
        -- 释放一个火球
        local fireball = Instance.new("Part")
        fireball.Name = "Fireball"
        fireball.Parent = workspace
        fireball.Shape = Enum.PartType.Ball
        fireball.Size = Vector3.new(1, 1, 1)
        fireball.Position = self._unitModel.HumanoidRootPart.Position + self._unitModel.HumanoidRootPart.CFrame.LookVector * 10
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
                local attackingUnitNo = self._findUnitCollection:getObjectTag(hit)
                if attackingUnitNo and not unitRecord[attackingUnitNo] then
                    unitRecord[attackingUnitNo] = false  -- 暂时取消重复检测
                    self._unitOperationCollection[attackingUnitNo].normalAttack(10)
                end
            end
        end)
    end

    self._unitOperation.F = function()
        print("技能F触发！")
        self._unitOperation.togglePause()
    end
end

return UnitInitializer

