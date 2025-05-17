local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local ActiveToggleMode = require(game.ReplicatedStorage.Util.Control.ActiveToggleMode)
local InputActionService = require(game.ReplicatedStorage.Util.Input.InputActionService)

local CameraLock = {}
CameraLock.__index = CameraLock

-- 继承两级开关模式
setmetatable(CameraLock, ActiveToggleMode)

-- ++++++++++++++++++++

-- 常量

-- ++++++++++++++++++++

local DEFAULT_CONFIG = {
    sensitivityX = 0.4,
    sensitivityY = 0.4,
    minAngleY = -80,
    maxAngleY = 80,
    centerOffset = Vector3.new(0, 2, 0),
    cameraOffset = Vector3.new(1.5, 1.5, 12),
    shouldRotateCharacter = true,
}

-- ++++++++++++++++++++

-- 属性和状态
-- 实质为全局模块，将部分属性用对象包装以免去清理过程

-- ++++++++++++++++++++

local _inputActionCollection = InputActionService:getOrCreateInputActionCollection("CameraLock")

function CameraLock.new(character: Model, ...: Enum.KeyCode | Enum.UserInputType)
    local self = ActiveToggleMode.new()
    setmetatable(self, CameraLock)

    self:setTarget(character)

    self._config = table.clone(DEFAULT_CONFIG)

    -- self.mouseLockCenterConnection

    self._angleX = 0
    self._angleY = 0

    self:_setKey(...)

    return self
end

-- ++++++++++++++++++++

-- 配置方法&操作接口

-- + 继承自ActiveToggleMode：
-- activate()
-- deactivate()
-- toggle()

-- ++++++++++++++++++++

function CameraLock:setTarget(character: Model)
    self._rootPart = character:FindFirstChild("HumanoidRootPart")
    self._humanoid = character:FindFirstChild("Humanoid")
end

function CameraLock:changeConfig(config)
    for property, value in config do
        self._config[property] = value
    end
end

function CameraLock:_setKey(...: Enum.KeyCode | Enum.UserInputType)
    _inputActionCollection:addSinglePressInputAction("toggle", function()
        self:toggle()
    end, ...)
end

function CameraLock:remove()
    self:deactivate()
    _inputActionCollection:removeAllInputActions()
end

-- ++++++++++++++++++++

-- 条件和操作重写

-- ++++++++++++++++++++

function CameraLock:_enableToggle()
    workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
    UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
    self:_mouseLockCenterConnect()

    self:_initCameraAngle()

    _inputActionCollection:addChangeInputAction(
        "updateCameraAngleFromInput",
        function(inputObject)
            self:_updateCameraAngleFromInput(inputObject)
        end,
        Enum.UserInputType.MouseMovement)

    RunService:BindToRenderStep(
        "updateCameraFromAngle",
        Enum.RenderPriority.Camera.Value,
        function()
            self:_updateCameraFromAngle()
        end
    )

    RunService:BindToRenderStep(
        "updateCharacterFacing",
        Enum.RenderPriority.Character.Value,
        function()
            self:_updateCharacterFacing()
        end
    )

end

function CameraLock:_disableToggle()
    RunService:UnbindFromRenderStep("updateCharacterFacing")
    RunService:UnbindFromRenderStep("updateCameraFromAngle")
    _inputActionCollection:removeInputAction("updateCameraAngleFromInput")

    self:_mouseLockCenterDisconnect()
    UserInputService.MouseBehavior = Enum.MouseBehavior.Default
    workspace.CurrentCamera.CameraType = Enum.CameraType.Custom

    if self._humanoid then
        workspace.CurrentCamera.CameraSubject = self._humanoid
    end
end

-- ++++++++++++++++++++

-- 操作逻辑

-- ++++++++++++++++++++

function CameraLock:_initCameraAngle()
    local x, y = workspace.CurrentCamera.CFrame:ToOrientation()
    -- x, y为旋转轴向，对应旋转方向为y, x（左右）
    self._angleX = math.deg(y)
    self._angleY = math.deg(x)
end

function CameraLock:_mouseLockCenterConnect()
    self._mouseLockCenterConnection = UserInputService.WindowFocused:Connect(function()
        UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
    end)
end

function CameraLock:_mouseLockCenterDisconnect()
    if self._mouseLockCenterConnection then
        self._mouseLockCenterConnection:Disconnect()
    end
end

function CameraLock:_updateCameraAngleFromInput(inputObject: InputObject)
    self._angleX = self._angleX - inputObject.Delta.X * self._config.sensitivityX

    self._angleY = math.clamp(
        self._angleY - inputObject.Delta.Y * self._config.sensitivityY,
        self._config.minAngleY,
        self._config.maxAngleY
    )
end

function CameraLock:_updateCameraFromAngle()
    -- rootPart必须存在且尚未销毁
    if not self._rootPart or not self._rootPart.Parent then return end

    -- 确定中心点位置和旋转
    local position = self._rootPart.Position + self._config.centerOffset
    local orientation = CFrame.fromOrientation(
        math.rad(self._angleY),
        math.rad(self._angleX),
        0
    )

    -- 设置
    workspace.CurrentCamera.CFrame = CFrame.new(position) -- 位置
        :ToWorldSpace(orientation) -- 旋转
        :ToWorldSpace(CFrame.new(self._config.cameraOffset)) -- 偏移
end

function CameraLock:_updateCharacterFacing()
    if not self._rootPart or not self._rootPart.Parent then return end
    if not self._config.shouldRotateCharacter then return end

    local _, y = workspace.CurrentCamera.CFrame:ToOrientation()
    self._rootPart.CFrame = CFrame.new(self._rootPart.Position) * CFrame.fromOrientation(0, y, 0)
end

-- ++++++++++++++++++++

return CameraLock
