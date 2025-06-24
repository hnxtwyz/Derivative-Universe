local Debris = game:GetService("Debris")

local ModelComponent = require(game.ReplicatedStorage.Util.Model.ModelComponent)
local CharacterController = require(game.ReplicatedStorage.Util.Character.CharacterController)

local Promise = require(game.ReplicatedStorage.Util.Data.Promise)
local Signal = require(game.ReplicatedStorage.Util.Data.Signal)

local UnitInitializer = {}
UnitInitializer.__index = UnitInitializer

function UnitInitializer.new(unitModel: Model, battle)
    local self = {}
    setmetatable(self, UnitInitializer)

    self._unitModel = unitModel
    self._characterController = CharacterController.new(unitModel)
    self._battle = battle

    self._unitNo = nil
    self._unitOperation = nil

    self._unitAttributeList = nil
    self._unitSignalList = nil

    return self
end

-- ++++++++++++++++++++

-- 初始化和加载

-- ++++++++++++++++++++

function UnitInitializer:initUnit() : number
    self._unitNo = self._battle:getNextUnitNo()

    self._battle.unitOperationCollection[self._unitNo] = {}
    self._unitOperation = self._battle.unitOperationCollection[self._unitNo]

    self._unitAttributeList = self._battle.unitAttributeListCollection:getOrCreatePropertyList(self._unitNo)
    self._unitSignalList = self._battle.unitSignalListCollection:getOrCreateSignalList(self._unitNo)
    
    self:_initParts()
    self:_initTeam()

    self:_initHealthSystem()
    self:_initHumanoidHealthBehavior()
    self:_initStiffSystem()
    self:_initPauseSystem()
    self:_initStiffEffect()
    self:_initActionRestrictionSystem()
    self:_initDamageSystem()
    self:_initMovementSystem()
    self:_initSkillSystem()
    
    return self._unitNo
end

function UnitInitializer:_initParts()
    for _, part in ModelComponent:getChildParts(self._unitModel) do
        self._battle.findUnitCollection:setObjectTag(part, self._unitNo)
    end
end

function UnitInitializer:_initTeam()
    self._battle.unitTeamCollection:setObjectTag(self._unitNo, self._battle.DEFAULT_TEAM_NAME)
end

-- ++++++++++++++++++++

-- 生命值、生命值外在影响系统

-- ++++++++++++++++++++

function UnitInitializer:_initHealthSystem()
    self._unitAttributeList:setProperty("health", 100)
    self._unitAttributeList:setProperty("dead", false)

    local healthGainedSignal = self._unitSignalList:getOrCreateSignal("HealthGained")
    local healthLostSignal = self._unitSignalList:getOrCreateSignal("HealthLost")
    local diedSignal = self._unitSignalList:getOrCreateSignal("Died")

    local function die()
        self._unitAttributeList:setProperty("dead", true)
        diedSignal:Fire()
    end
    self._unitOperation.die = die

    self._unitOperation.healthGained = function(val: number)
        local currentHealth = self._unitAttributeList:getProperty("health")
        local newHealth = math.clamp(currentHealth + val, 0, 100)
        self._unitAttributeList:setProperty("health", newHealth)
        healthGainedSignal:Fire(val, newHealth)
    end

    self._unitOperation.healthLost = function(val: number)
        local currentHealth = self._unitAttributeList:getProperty("health")
        local newHealth = math.clamp(currentHealth - val, 0, 100)
        self._unitAttributeList:setProperty("health", newHealth)
        if newHealth <= 0 then
            die()
        end
        healthLostSignal:Fire(val, newHealth)
    end
end

function UnitInitializer:_initHumanoidHealthBehavior() 
    local healthGainedSignal = self._unitSignalList:getOrCreateSignal("HealthGained")
    local healthLostSignal = self._unitSignalList:getOrCreateSignal("HealthLost")
    local diedSignal = self._unitSignalList:getOrCreateSignal("Died")

    diedSignal:Connect(function()
        self._characterController.humanoid.Health = 0
    end)

    healthGainedSignal:Connect(function(val: number, newHealth: number)
        self._characterController.humanoid.Health = newHealth
    end)
    
    healthLostSignal:Connect(function(val: number, newHealth: number)
        if newHealth > 0 then
            self._characterController.humanoid.Health = newHealth
        end
    end)

    -- 意外死亡检测
    self._characterController.humanoid.Died:Connect(function()
        if not self._unitAttributeList:getProperty("dead") then
            self._unitOperation.die()
        end
    end)
end

-- ++++++++++++++++++++

-- 僵直、攻击僵直和僵直外在影响系统

-- ++++++++++++++++++++

function UnitInitializer:_initStiffSystem()
    local immunityLvCount = {
        [1] = 0,
        [2] = 0,
        [3] = 0,
    }

    self._unitOperation.immune = function(immunityLv: number, immunityTime: number)
        immunityLvCount[immunityLv] = immunityLvCount[immunityLv] + 1
        task.wait(immunityTime)
        immunityLvCount[immunityLv] = immunityLvCount[immunityLv] - 1
    end

    self._unitOperation.manualImmune = function(immunityLv: number)
        immunityLvCount[immunityLv] = immunityLvCount[immunityLv] + 1
    end

    self._unitOperation.liftImmune = function(immunityLv: number)
        immunityLvCount[immunityLv] = immunityLvCount[immunityLv] - 1
    end

    local function canAddLvStiff(lv: number) : boolean
        -- 若有任何大于等于僵直等级的免疫等级，则不能施加僵直
        for i = lv, 3 do
            if immunityLvCount[i] > 0 then
                return false
            end
        end
        return true
    end
    
    self._unitAttributeList:setProperty("isStiff", false)

    local stiffInterruptedSignal = self._unitSignalList:getOrCreateSignal("StiffInterrupted")

    local stiffLvCount = {
        [1] = 0,
        [2] = 0,
        [3] = 0,
    }

    self._unitOperation.stiff = function(stiffLv: number, stiffTime: number)
        if canAddLvStiff(stiffLv) then
            stiffLvCount[stiffLv] = stiffLvCount[stiffLv] + 1
            if not self._unitAttributeList:getProperty("isStiff") then
                self._unitAttributeList:setProperty("isStiff", true)
                self._unitOperation.updateStiffEffect()
                stiffInterruptedSignal:Fire()
            end
            task.wait(stiffTime)
            stiffLvCount[stiffLv] = stiffLvCount[stiffLv] - 1
            if stiffLvCount[1] == 0 and stiffLvCount[2] == 0 and stiffLvCount[3] == 0 then
                self._unitAttributeList:setProperty("isStiff", false)
                self._unitOperation.updateStiffEffect()
            end
        end
    end
end

function UnitInitializer:_initPauseSystem() -- 攻击僵直
    self._unitAttributeList:setProperty("isPaused", false)

    self._unitOperation.pause = function()
        self._unitAttributeList:setProperty("isPaused", true)
        self._unitOperation.updateStiffEffect()
    end

    self._unitOperation.unpause = function()
        self._unitAttributeList:setProperty("isPaused", false)
        self._unitOperation.updateStiffEffect()
    end
end

function UnitInitializer:_initStiffEffect()
    local humanoidWalkSpeed = self._characterController.humanoid.WalkSpeed
    local humanoidJumpPower = self._characterController.humanoid.JumpPower

    -- 僵直外在影响：不可移动和跳跃
    self._unitOperation.updateStiffEffect = function()
        if self._unitAttributeList:getProperty("isPaused") or self._unitAttributeList:getProperty("isStiff") then
            self._characterController:restrictMovement()
            self._characterController:restrictJump()
        else
            self._characterController:allowMovement(humanoidWalkSpeed)
            self._characterController:allowJump(humanoidJumpPower)
        end
    end
end

-- ++++++++++++++++++++

-- 操作限制系统

-- ++++++++++++++++++++

function UnitInitializer:_initActionRestrictionSystem()
    self._unitAttributeList:setProperty("isBusy", false) -- 可直接修改的变量

    -- 是否可使用技能，主要限制第一段入口
    self._unitOperation.canUseSkill = function() : boolean
        return not(self._unitAttributeList:getProperty("isPaused") or self._unitAttributeList:getProperty("isStiff") or self._unitAttributeList:getProperty("isBusy") or self._unitAttributeList:getProperty("dead"))
    end
end

-- ++++++++++++++++++++

-- 伤害系统

-- ++++++++++++++++++++

function UnitInitializer:_initDamageSystem()
    self._unitAttributeList:setProperty("isBlocking", false) -- 格挡状态，可直接修改的变量

    local attackBlockedSignal = self._unitSignalList:getOrCreateSignal("AttackBlocked")

    self._unitOperation.normalDamage = function(damageSrcNo: number, val: number, exEffect: () -> ()?)
        if self._unitAttributeList:getProperty("isBlocking") then
            attackBlockedSignal:Fire(damageSrcNo)
        else
            self._unitOperation.healthLost(val)
            if exEffect then
                exEffect()
            end
        end
    end
end

-- ++++++++++++++++++++

-- 位移系统

-- ++++++++++++++++++++

function UnitInitializer:_initMovementSystem()
    -- 获取周邻位置
    self._unitOperation.cframeOffset = function(cframe: CFrame) : CFrame
        return self._characterController:cframeOffset(cframe)
    end

    -- 位移，速度为grid/s
    self._unitOperation.moveTo = function(cframe: CFrame, speed: number) : Tween
        local duration = (cframe.Position - self._characterController.humanoidRootPart.Position).Magnitude / speed
        return self._characterController:moveTo(cframe, duration)
    end
end

-- ++++++++++++++++++++

-- 技能系统

-- ++++++++++++++++++++

function UnitInitializer:_initSkillSystem()

    -- ++++++++++++++++++++

    -- 动画设置

    -- ++++++++++++++++++++

    -- 原平A动画：98920670395451
    self._characterController:loadAnimation("A", "rbxassetid://101674903217716")
    self._characterController:loadAnimation("BA1", "rbxassetid://132898010483913")
    self._characterController:loadAnimation("BA2", "rbxassetid://127017048362548")

    -- ++++++++++++++++++++

    -- 必需资源

    -- ++++++++++++++++++++

    local attackBlockedSignal = self._unitSignalList:getOrCreateSignal("AttackBlocked")
    local stiffInterruptedSignal = self._unitSignalList:getOrCreateSignal("StiffInterrupted")

    -- ++++++++++++++++++++

    -- E

    -- ++++++++++++++++++++

    local eStage = 0

    local e2PressedSignal = Signal.new()

    local function eCoolDown()
        task.delay(0.5, function()
            eStage = 0
        end)
    end

    local function e1Start()
        self._unitOperation.manualImmune(1) -- 1级霸体
        self._characterController:playAnimation("BA1", nil, nil, 0.2) -- 蓄力动画
        isBusy = true -- 不可释放技能
    end

    local function e1End()
        isBusy = false -- 可释放技能
        self._characterController:stopAnimation("BA1") -- 蓄力动画结束
        self._unitOperation.liftImmune(1) -- 取消霸体
    end

    local function e2Start()
        self._unitOperation.manualImmune(2)
        self._characterController:playAnimation("BA2")
        self._unitOperation.pause()
    end

    local function e2End()
        self._unitOperation.unpause()
        self._characterController:stopAnimation("BA2")
        self._unitOperation.liftImmune(2)
    end

    self._unitOperation.E1 = function()
        if self._unitOperation.canUseSkill() and eStage == 0 then
            eStage = 1

            print("技能E1触发！")
            e1Start() -- 蓄力开始

            -- 情况1：按下E2
            local e2Pressed = Promise.fromEvent(e2PressedSignal):andThen(function()
                eStage = 2
            end)
            -- 情况2：被僵直打断
            local e1StiffInterrupted = Promise.fromEvent(stiffInterruptedSignal):andThen(function()
                eStage = 3
            end)

            Promise.race({e1StiffInterrupted, e2Pressed}):expect()

            e1End() -- 蓄力结束

            if eStage == 2 then
                -- 情况1：按下E2
                print("技能E2触发！")
                e2Start()

                local attackBox = Instance.new("Part")
                attackBox.Name = "AttackBox"
                attackBox.Parent = workspace
                attackBox.Size = Vector3.new(5, 5, 5)
                attackBox.Anchored = true
                attackBox.CanCollide = false
                attackBox.CanTouch = true
                attackBox.CanQuery = true
                attackBox.Transparency = 0.7
                attackBox.CFrame = self._characterController:cframeOffset(CFrame.new(0, 0, -7))

                self:_attackingObjectBind(attackBox, function(attackingUnitOperation)
                    attackingUnitOperation.normalDamage(self._unitNo, 20, function()
                        attackingUnitOperation.stiff(2, 0.5)
                    end)
                end)
                Debris:AddItem(attackBox, 0.3)

                -- e2暂无打断，不会提前e2End
                task.wait(0.3)
                e2End()   
            end
            -- 情况2：被僵直打断（无后续操作）

            eCoolDown()
        end
    end

    -- 将按下E2转化为信号
    self._unitOperation.E2 = function()
        e2PressedSignal:Fire()
    end

    -- ++++++++++++++++++++

    -- F

    -- ++++++++++++++++++++

    self._unitOperation.F = function()
        -- 测试外部僵直，不设置释放限制
        print("技能F触发！")
        self._unitOperation.stiff(3, 2)
    end

    -- ++++++++++++++++++++

    -- Q

    -- ++++++++++++++++++++

    self._unitOperation.Q = function()
        -- 测试霸体
        print("技能Q触发！")
        self._unitOperation.immune(3, 2)
    end

    -- ++++++++++++++++++++

    -- A

    -- ++++++++++++++++++++

    local aStage = 0
    local aAttackingConnection = nil

    local function aCoolDown()
        task.delay(0.5, function()
            aStage = 0
        end)
    end

    local function aStart()
        self._unitOperation.manualImmune(1) -- 1级霸体
        -- 武器攻击效果
        aAttackingConnection = self:_attackingObjectBind(self._unitModel.Function.Weapon, function(attackingUnitOperation)
            attackingUnitOperation.normalDamage(self._unitNo, 20, function()
                -- 附加1级僵直
                attackingUnitOperation.stiff(1, 0.5)
            end)
        end)
        self._characterController:playAnimation("A") -- 攻击动画
        self._unitOperation.pause() -- 自身攻击僵直
    end

    local function aEnd()
        self._unitOperation.unpause() -- 自身攻击僵直结束
        self._characterController:stopAnimation("A") -- 攻击动画结束
        aAttackingConnection:Disconnect() -- 武器攻击效果结束
        self._unitOperation.liftImmune(1) -- 取消1级霸体
    end

    self._unitOperation.A = function()
        if self._unitOperation.canUseSkill() and aStage == 0 then
            aStage = 1

            print("技能A触发！")
            aStart() -- 攻击开始

            -- 情况1：完成攻击
            local aCompleted = Promise.delay(0.375):andThen(function()
                aStage = 2
            end)
            -- 情况2：被僵直打断
            local aStiffInterrupted = Promise.fromEvent(stiffInterruptedSignal):andThen(function()
                aStage = 3
            end)

            Promise.race({aCompleted, aStiffInterrupted}):expect()

            aEnd() -- 攻击结束
            aCoolDown()
        end
    end

    -- ++++++++++++++++++++

    -- R

    -- ++++++++++++++++++++

    local rStage = 0

    local blockedSrcNo = nil

    local function rCoolDown()
        task.delay(0.5, function()
            rStage = 0
        end)
    end

    local function r1Start()
        self._unitOperation.manualImmune(2) -- 2级霸体
        self._unitOperation.pause() -- 攻击僵直
    end

    local function r1End()
        self._unitOperation.unpause() -- 攻击僵直结束
        self._unitOperation.liftImmune(2) -- 取消2级霸体
    end

    self._unitOperation.R = function()
        if self._unitOperation.canUseSkill() and rStage == 0 then
            rStage = 1

            print("技能R触发！")
            r1Start() -- 挡刀前摇

            -- 情况1：完成前摇
            local r1Completed = Promise.delay(0.2):andThen(function()
                rStage = 2
            end)
            -- 情况2：被僵直打断
            local r1StiffInterrupted = Promise.fromEvent(stiffInterruptedSignal):andThen(function()
                rStage = 3
            end)

            Promise.race({r1Completed, r1StiffInterrupted}):expect()

            r1End() -- 挡刀前摇结束

            -- R2

            if rStage == 2 then
                print("开始挡刀！")
                r1Start()
                self._unitAttributeList:setProperty("isBlocking", true)

                -- 情况1：完成挡刀
                local blockingCompleted = Promise.delay(0.4):andThen(function()
                    rStage = 4
                end)
                -- 情况2：挡刀成功
                local blockingSuccess = Promise.fromEvent(attackBlockedSignal):andThen(function(damageSrcNo)
                    rStage = 5
                    blockedSrcNo = damageSrcNo
                end)

                Promise.race({blockingCompleted, blockingSuccess}):expect()

                self._unitAttributeList:setProperty("isBlocking", false)
                r1End()

                if rStage == 5 then
                    print("结束挡刀，反击成功！")
                    local targetCFrame = self._battle.unitOperationCollection[blockedSrcNo].cframeOffset(CFrame.new(0, 0, 5))
                    self._unitOperation.moveTo(targetCFrame, 100)
                    self._characterController:playAnimation("A")
                    -- 没有等待移动便造成伤害
                    self._battle.unitOperationCollection[blockedSrcNo].normalDamage(self._unitNo, 20)
                elseif rStage == 4 then
                    print("结束挡刀，反击失败！")
                    self._unitOperation.stiff(2, 0.4)
                end
            end

            rCoolDown()
        end
    end

    -- ++++++++++++++++++++

    -- 位移

    -- ++++++++++++++++++++

    local sprintDirection

    local function computeSprintDirection()
        -- 获取水平、单位化的面朝方向，且以此为基准定义四个方位
        local facingDirection = self._characterController.humanoidRootPart.CFrame.LookVector
        facingDirection = Vector3.new(facingDirection.X, 0, facingDirection.Z)
        facingDirection = facingDirection.Unit
        local forward = facingDirection
        local backward = -forward
        local left = Vector3.new(-forward.Z, 0, forward.X)
        local right = Vector3.new(forward.Z, 0, -forward.X)

        -- 获取移动方向，并确定其相对于面朝方向的方位
        local moveDirection = self._characterController.humanoid.MoveDirection
        if moveDirection.Magnitude == 0 then
            moveDirection = facingDirection
        end
        -- 计算方位
        local dotProduct = moveDirection:Dot(facingDirection)
        local crossProductY = moveDirection:Cross(facingDirection).Y
        local cos45 = math.cos(math.pi / 4)
        if dotProduct >= cos45 then
            -- 前
            sprintDirection = forward
        elseif dotProduct <= -cos45 then
            -- 后
            sprintDirection = backward
        elseif crossProductY > 0 then
            -- 左
            sprintDirection = left
        else
            -- 右
            sprintDirection = right
        end
    end

    local shiftStage = 0

    local shift2PressedSignal = Signal.new()

    local linearVelocity = nil

    local function shiftCoolDown()
        shiftStage = 0
    end

    local function sprintStart(v: number)
        self._unitOperation.pause()
        computeSprintDirection()
        linearVelocity = self._characterController:applyLinearVelocity(sprintDirection * v)
    end

    local function sprintEnd()
        linearVelocity:Destroy()
        self._unitOperation.unpause()
    end
    
    local function afterSprint()
        self._unitOperation.pause()
        task.wait(0.2)
        self._unitOperation.unpause()
    end

    self._unitOperation.Shift = function()
        if self._unitOperation.canUseSkill() and shiftStage == 0 then
            shiftStage = 1

            print("技能Shift触发！")
            sprintStart(100)
            
            -- 情况1：完成移动
            local shiftCompleted = Promise.delay(0.3):andThen(function()
                shiftStage = 2
            end)
            -- 情况2：被僵直打断
            local shiftStiffInterrupted = Promise.fromEvent(stiffInterruptedSignal):andThen(function()
                shiftStage = 3
            end)
            -- 情况3：按下Shift2，触发二段闪
            local shift2Pressed = Promise.fromEvent(shift2PressedSignal):andThen(function()
                shiftStage = 4
            end)

            Promise.race({shiftCompleted, shiftStiffInterrupted, shift2Pressed}):expect()

            sprintEnd()
            
            if shiftStage == 4 then
                print("技能Shift2触发！")
                sprintStart(150)

                -- 情况1：完成移动
                local shift2Completed = Promise.delay(0.4):andThen(function()
                    shiftStage = 5
                end)
                -- 情况2：被僵直打断
                local shift2StiffInterrupted = Promise.fromEvent(stiffInterruptedSignal):andThen(function()
                    shiftStage = 6
                end)

                Promise.race({shift2Completed, shift2StiffInterrupted}):expect()

                sprintEnd()

                if shiftStage == 5 then
                    afterSprint()
                end
            elseif shiftStage == 2 then
                afterSprint()
            end

            shiftCoolDown()
        elseif shiftStage == 1 then
            shift2PressedSignal:Fire()
        end
    end

    self._unitOperation.Forward = function()
    end

    self._unitOperation.Left = function()
    end

    self._unitOperation.Backward = function()
    end

    self._unitOperation.Right = function()
    end
end

function UnitInitializer:_attackingObjectBind(object: Instance, attackingFn: (table) -> ()) : RBXScriptConnection
    return self._battle.battleObjectHandler:objectTouch(object, function(touchedUnitNo)
        if self._battle:isEnemy(touchedUnitNo, self._unitNo) then
            local attackingUnitOperation = self._battle.unitOperationCollection[touchedUnitNo]
            attackingFn(attackingUnitOperation)
        end
    end)
end

function UnitInitializer:robotAutoAttack()
    task.spawn(function()
        while task.wait(2) do
            print("机器人自动攻击！")
            self._unitOperation.A()
        end
    end)
end

return UnitInitializer
