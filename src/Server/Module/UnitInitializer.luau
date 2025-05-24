local ModelComponent = require(game.ReplicatedStorage.Util.Model.ModelComponent)
local CharacterController = require(game.ReplicatedStorage.Util.Character.CharacterController)

local UnitInitializer = {}
UnitInitializer.__index = UnitInitializer

function UnitInitializer.new(unitModel: Model, battle)
    local self = {}
    setmetatable(self, UnitInitializer)

    self._unitModel = unitModel
    self._battle = battle

    self._unitNo = nil
    self._unitOperation = nil

    self._unitAttributeList = nil
    self._unitSignalList = nil

    return self
end

local DEFAULT_TEAM_NAME = "Default"

function UnitInitializer:initUnit() : number
    -- 初始化属性
    self._unitNo = self._battle:getNextUnitNo()

    self._unitAttributeList = self._battle.unitAttributeListCollection:getOrCreatePropertyList(self._unitNo)
    self._unitSignalList = self._battle.unitSignalListCollection:getOrCreateSignalList(self._unitNo)

    -- 模型相关
    local unitParts = ModelComponent:getChildParts(self._unitModel)
    for _, part in unitParts do
        self._battle.findUnitCollection:setObjectTag(part, self._unitNo)
    end
    
    -- 队伍相关
    self._battle.unitTeamCollection:setObjectTag(self._unitNo, DEFAULT_TEAM_NAME)

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
        if currentHealth > 0 then
            self._unitModel.Humanoid.Health = currentHealth
        else
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

    -- 初始化操作
    self._battle.unitOperationCollection[self._unitNo] = {}
    self._unitOperation = self._battle.unitOperationCollection[self._unitNo]
    
    self._unitOperation.normalAttack = function(val: number)
        local currentHealth = self._unitAttributeList:getProperty("health")
        local newHealth = math.clamp(currentHealth - val, 0, 100)
        self._unitAttributeList:setProperty("health", newHealth)
        healthLostSignal:Fire(val)
    end

    return self._unitNo
end

function UnitInitializer:initSkill()
    local animator = self._unitModel.Humanoid.Animator

    -- 原平A动画：98920670395451

    local A = Instance.new("Animation")
    A.AnimationId = "rbxassetid://101674903217716"
    local ATrack = animator:LoadAnimation(A)
    ATrack.Priority = Enum.AnimationPriority.Action

    local BA1 = Instance.new("Animation")
    BA1.AnimationId = "rbxassetid://132898010483913"
    local BA1Track = animator:LoadAnimation(BA1)
    BA1Track.Priority = Enum.AnimationPriority.Action

    local BA2 = Instance.new("Animation")
    BA2.AnimationId = "rbxassetid://127017048362548"
    local BA2Track = animator:LoadAnimation(BA2)
    BA2Track.Priority = Enum.AnimationPriority.Action

    -- 控制系统

    local characterController = CharacterController.new(self._unitModel)
    local cachedWalkSpeed = characterController:getWalkSpeed()
    local cachedJumpPower = characterController:getJumpPower()

    -- 打断信号，僵直产生时触发
    local interruptedSignal = self._unitSignalList:getOrCreateSignal("Interrupted")

    local immunityLvCount = {
        [1] = 0,
        [2] = 0,
        [3] = 0,
    }

    local function canAddLvEffect(lv: number) : boolean
        for i = lv, 3 do
            if immunityLvCount[i] > 0 then
                return false
            end
        end
        return true
    end

    local isStiff = false -- 外源控制

    local stiffLvCount = {
        [1] = 0,
        [2] = 0,
        [3] = 0,
    }

    local isPaused = false -- 内源阻止技能

    -- 隔离不同技能，即限制第一段
    local function isBusy() : boolean
        return isPaused or isStiff
    end

    -- 不可移动、跳跃和释放技能（通过isBusy()约束）
    local function updateBusy()
        if isBusy() then
            characterController:restrictMovement()
            characterController:restrictJump()
        else
            characterController:allowMovement(cachedWalkSpeed)
            characterController:allowJump(cachedJumpPower)
        end
    end

    local function pause()
        isPaused = true
        updateBusy()
    end

    local function unpause()
        isPaused = false
        updateBusy()
    end

    self._unitOperation.immune = function(immunityLv: number, immunityTime: number)
        immunityLvCount[immunityLv] = immunityLvCount[immunityLv] + 1
        task.wait(immunityTime)
        immunityLvCount[immunityLv] = immunityLvCount[immunityLv] - 1
    end

    self._unitOperation.stiff = function(stiffLv: number, stiffTime: number)
        if canAddLvEffect(stiffLv) then
            stiffLvCount[stiffLv] = stiffLvCount[stiffLv] + 1
            if not isStiff then
                isStiff = true
                interruptedSignal:Fire() -- 发送打断信号
                updateBusy()
            end
            task.wait(stiffTime)
            stiffLvCount[stiffLv] = stiffLvCount[stiffLv] - 1
            if stiffLvCount[1] == 0 and stiffLvCount[2] == 0 and stiffLvCount[3] == 0 then
                isStiff = false
                updateBusy()
            end
        end
    end

    local e1Stage = 0
    local e1InterruptedConnection = nil
    
    self._unitOperation.E1 = function()
        if not isBusy() then
            if e1Stage == 0 then
                e1Stage = 1
                print("技能E1触发！")
                if e1InterruptedConnection then
                    e1InterruptedConnection:Disconnect()
                end
                pause()
                BA1Track:Play(nil, nil, 0.2)
                e1InterruptedConnection = interruptedSignal:Once(function()
                    BA1Track:Stop()
                    unpause()
                    e1Stage = 0
                end)
                e1Stage = 2
            end
        end
    end

    self._unitOperation.E2 = function()
        if e1Stage == 2 then
            e1Stage = 3
            print("技能E2触发！")
            if e1InterruptedConnection then
                e1InterruptedConnection:Disconnect()
            end
            BA1Track:Stop()
            unpause()
            BA2Track:Play()
            e1Stage = 0
        end
    end

    self._unitOperation.F = function()
        -- 特殊测试外部僵直，暂不计入
        print("技能F触发！")
        self._unitOperation.stiff(1, 2)
        if not isBusy() then
            
        end
    end

    self._unitOperation.Q = function()
        if not isBusy() then
            print("技能Q触发！")
            self._unitOperation.immune(1, 3)
        end
    end

    -- 其他技能

    self._unitOperation.A = function()
        if not isBusy() then
            print("技能A触发！")
            ATrack:Play()
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

            self._battle.battleObjectHandler:handleObject(attackBox, self._unitNo, 0.3, 20)
        end
    end

    self._unitOperation.R = function()
        if not isBusy() then
            print("技能R触发！")
            BA2Track:Play()
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

            self._battle.battleObjectHandler:handleObject(fireball, self._unitNo, 5, 20)
        end
    end
end

return UnitInitializer

