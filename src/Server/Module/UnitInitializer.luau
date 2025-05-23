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

    self._battleObjectHandler = context.battleObjectHandler

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

        self._battleObjectHandler:handleObject(fireball, self._unitNo, 5, 20)
    end

    self._unitOperation.F = function()
        print("技能F触发！")
        self._unitOperation.togglePause()
    end
end

function UnitInitializer:initSkillA()
    local animator = self._unitModel.Humanoid.Animator

    local A1 = Instance.new("Animation")
    A1.AnimationId = "rbxassetid://98920670395451"
    local A1Track = animator:LoadAnimation(A1)
    A1Track.Priority = Enum.AnimationPriority.Action

    self._unitOperation.A = function()
        print("技能A触发！")
        A1Track:Play()
        local attackBox = Instance.new("Part")
        attackBox.Name = "AttackBox"
        attackBox.Parent = workspace
        attackBox.Size = Vector3.new(5, 5, 5)
        attackBox.Anchored = true
        attackBox.CanCollide = false
        attackBox.CanTouch = true
        attackBox.CanQuery = true
        attackBox.Transparency = 0.7
        attackBox.CFrame = self._unitModel.HumanoidRootPart.CFrame + self._unitModel.HumanoidRootPart.CFrame.LookVector * 7

        self._battleObjectHandler:handleObject(attackBox, self._unitNo, 0.3, 20)
    end
end

return UnitInitializer

