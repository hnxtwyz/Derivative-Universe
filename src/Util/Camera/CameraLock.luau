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
-- 为全局，模块同一时刻将至多仅创建一个对象进行操作和管理

-- ++++++++++++++++++++

local _rootPart
local _humanoid

local _inputActionCollection = InputActionService:getOrCreateInputActionCollection("CameraLock")

local _config

local _angleX
local _angleY

local _mouseLockCenterConnection

-- ++++++++++++++++++++

-- 对象创建、配置方法&操作接口

-- + 继承自ActiveToggleMode：
-- activate()
-- deactivate()
-- toggle()

-- ++++++++++++++++++++

local _objectCreated = false

function CameraLock.new(character: Model, ...: Enum.KeyCode | Enum.UserInputType)
    if _objectCreated then return end

    local self = ActiveToggleMode.new()
    setmetatable(self, CameraLock)

    self:setTarget(character)
    self:setKey(...)

    _config = table.clone(DEFAULT_CONFIG)

    _objectCreated = true

    return self
end

function CameraLock:setTarget(character: Model)
    _rootPart = character:FindFirstChild("HumanoidRootPart")
    _humanoid = character:FindFirstChild("Humanoid")
end

function CameraLock:setKey(...: Enum.KeyCode | Enum.UserInputType)
    _inputActionCollection:addSinglePressInputAction("toggle", function()
        self:toggle()
    end, ...)
end

function CameraLock:changeConfig(config)
    for property, value in config do
        _config[property] = value
    end
end

function CameraLock:remove()
    if _objectCreated then
        _inputActionCollection:removeAllInputActions()
        self:deactivate()
        _objectCreated = false
    end
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

    if _humanoid then
        workspace.CurrentCamera.CameraSubject = _humanoid
    end
end

-- ++++++++++++++++++++

-- 操作逻辑

-- ++++++++++++++++++++

function CameraLock:_initCameraAngle()
    local x, y = workspace.CurrentCamera.CFrame:ToOrientation()
    -- x, y为旋转轴向，对应旋转方向为y, x（左右）
    _angleX = math.deg(y)
    _angleY = math.deg(x)
end

function CameraLock:_mouseLockCenterConnect()
    if not _mouseLockCenterConnection then
        _mouseLockCenterConnection = UserInputService.WindowFocused:Connect(function()
            UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
        end)
    end
end

function CameraLock:_mouseLockCenterDisconnect()
    if _mouseLockCenterConnection then
        _mouseLockCenterConnection:Disconnect()
    end
end

function CameraLock:_updateCameraAngleFromInput(inputObject: InputObject)
    _angleX = _angleX - inputObject.Delta.X * _config.sensitivityX

    _angleY = math.clamp(
        _angleY - inputObject.Delta.Y * _config.sensitivityY,
        _config.minAngleY,
        _config.maxAngleY
    )
end

function CameraLock:_updateCameraFromAngle()
    -- rootPart必须存在且尚未销毁
    if not _rootPart or not _rootPart.Parent then return end

    -- 确定中心点位置和旋转
    local position = _rootPart.Position + _config.centerOffset
    local orientation = CFrame.fromOrientation(
        math.rad(_angleY),
        math.rad(_angleX),
        0
    )

    -- 设置
    workspace.CurrentCamera.CFrame = CFrame.new(position) -- 位置
        :ToWorldSpace(orientation) -- 旋转
        :ToWorldSpace(CFrame.new(_config.cameraOffset)) -- 偏移
end

function CameraLock:_updateCharacterFacing()
    if not _rootPart or not _rootPart.Parent then return end
    if not _config.shouldRotateCharacter then return end

    local _, y = workspace.CurrentCamera.CFrame:ToOrientation()
    _rootPart.CFrame = CFrame.new(_rootPart.Position) * CFrame.fromOrientation(0, y, 0)
end

-- ++++++++++++++++++++

return CameraLock
