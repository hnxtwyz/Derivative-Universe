local Debris = game:GetService("Debris")

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
    self._battle.unitTeamCollection:setObjectTag(self._unitNo, self._battle.DEFAULT_TEAM_NAME)

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

    local function canAddLvStiff(lv: number) : boolean
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

    local isPaused = false -- 攻击僵直

    local isBusy = false -- 不可释放技能
    -- 无需函数更新效果，直接修改此变量即可

    -- 是否可使用技能，限制第一段
    local function canUseSkill() : boolean
        return not(isPaused or isStiff or isBusy)
    end

    local function isPausedOrStiff() : boolean
        return isPaused or isStiff
    end

    -- 总僵直状态效果，不可移动、跳跃和释放技能
    local function updatePausedOrStiff()
        if isPausedOrStiff() then
            characterController:restrictMovement()
            characterController:restrictJump()
        else
            characterController:allowMovement(cachedWalkSpeed)
            characterController:allowJump(cachedJumpPower)
        end
    end

    local function pause()
        isPaused = true
        updatePausedOrStiff()
    end

    local function unpause()
        isPaused = false
        updatePausedOrStiff()
    end

    self._unitOperation.immune = function(immunityLv: number, immunityTime: number)
        immunityLvCount[immunityLv] = immunityLvCount[immunityLv] + 1
        task.wait(immunityTime)
        immunityLvCount[immunityLv] = immunityLvCount[immunityLv] - 1
    end

    self._unitOperation.manualImmune = function(immunityLv: number, clearBit: boolean)
        if clearBit then
            immunityLvCount[immunityLv] = immunityLvCount[immunityLv] - 1
        else
            immunityLvCount[immunityLv] = immunityLvCount[immunityLv] + 1
        end
    end

    self._unitOperation.stiff = function(stiffLv: number, stiffTime: number)
        if canAddLvStiff(stiffLv) then
            stiffLvCount[stiffLv] = stiffLvCount[stiffLv] + 1
            if not isStiff then
                isStiff = true
                interruptedSignal:Fire() -- 发送打断信号
                updatePausedOrStiff()
            end
            task.wait(stiffTime)
            stiffLvCount[stiffLv] = stiffLvCount[stiffLv] - 1
            if stiffLvCount[1] == 0 and stiffLvCount[2] == 0 and stiffLvCount[3] == 0 then
                isStiff = false
                updatePausedOrStiff()
            end
        end
    end

    local eStage = 0
    local e1InterruptedConnection = nil

    local function eCoolDown()
        task.delay(0.5, function()
            eStage = 0
        end)
    end

    local function e1Start()
        self._unitOperation.manualImmune(1)
        BA1Track:Play(nil, nil, 0.2)
        isBusy = true
    end

    local function e1End()
        isBusy = false
        BA1Track:Stop()
        self._unitOperation.manualImmune(1, true)
    end

    local function e2Start()
        self._unitOperation.manualImmune(2)
        BA2Track:Play()
        pause()
    end

    local function e2End()
        unpause()
        BA2Track:Stop()
        self._unitOperation.manualImmune(2, true)
    end

    self._unitOperation.E1 = function()
        if canUseSkill() and eStage == 0 then
            eStage = 1

            print("技能E1触发！")
            e1Start()

            e1InterruptedConnection = interruptedSignal:Once(function()
                eStage = 3
                e1End()
                eCoolDown()
            end)
        end
    end

    self._unitOperation.E2 = function()
        if eStage == 1 then
            eStage = 2

            e1InterruptedConnection:Disconnect()

            print("技能E2触发！")
            e2Start()
            e1End()

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

            self._battle.battleObjectHandler:objectAttack(attackBox, self._unitNo, function(attackingUnitOperation)
                attackingUnitOperation.normalAttack(20)
                attackingUnitOperation.stiff(2, 0.5)
            end)
            Debris:AddItem(attackBox, 0.3)

            -- e2暂无打断，不会提前e2End
            task.wait(0.3)
            e2End()

            eCoolDown()
        end
    end

    self._unitOperation.F = function()
        -- 测试外部僵直，不设置释放限制
        print("技能F触发！")
        self._unitOperation.stiff(3, 2)
    end

    self._unitOperation.Q = function()
        -- 测试霸体
        print("技能Q触发！")
        self._unitOperation.immune(3, 2)
    end

    -- 其他技能

    local aStage = 0
    local aConnection = nil
    local aInterruptedConnection = nil

    local function aCoolDown()
        task.delay(0.5, function()
            aStage = 0
        end)
    end

    local function aStart()
        self._unitOperation.manualImmune(1)
        aConnection = self._battle.battleObjectHandler:objectAttack(self._unitModel.Function.Weapon, self._unitNo, function(attackingUnitOperation)
            attackingUnitOperation.normalAttack(20)
            attackingUnitOperation.stiff(1, 0.5)
        end)
        ATrack:Play()
        pause()
    end

    local function aEnd()
        unpause()
        ATrack:Stop()
        aConnection:Disconnect()
        self._unitOperation.manualImmune(1, true)
    end

    self._unitOperation.A = function()
        if canUseSkill() and aStage == 0 then
            aStage = 1

            print("技能A触发！")
            aStart()

            aInterruptedConnection = interruptedSignal:Once(function()
                aStage = 2
                aEnd()
                aCoolDown()
            end)
            task.wait(0.375)
            aInterruptedConnection:Disconnect()

            if aStage == 1 then
                aEnd()
                aCoolDown()
            end
        end
    end

    local rStage = 0

    local function rCoolDown()
        task.delay(2, function()
            rStage = 0
        end)
    end

    self._unitOperation.R = function()
        if canUseSkill() and rStage == 0 then
            rStage = 1

            print("技能R触发！")
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
            self._battle.battleObjectHandler:objectAttack(fireball, self._unitNo, function(attackingUnitOperation)
                attackingUnitOperation.normalAttack(20)
            end)
            Debris:AddItem(fireball, 2)

            rCoolDown()
        end
    end
end

return UnitInitializer

