local RemotePortService = require(game.ReplicatedStorage.Util.Remote.RemotePortService)
local InputActionService = require(game.ReplicatedStorage.Util.Input.InputActionService)
local CameraLock = require(game.ReplicatedStorage.Util.Camera.CameraLock)

local BattleJoin = {}

local _player = game.Players.LocalPlayer
local _playerGui = _player:WaitForChild("PlayerGui")

local _battlePortCollection = RemotePortService:waitRemotePortCollection("Battle")
local _battleJoinFunction = _battlePortCollection:waitRemotePort("BattleJoinFunction")
local _championActionEvent = _battlePortCollection:waitRemotePort("ChampionActionEvent")

local _battleInputActionCollection = InputActionService:getOrCreateInputActionCollection("Battle")

local _cameraLock

function BattleJoin:initBattleJoinGui()
    local battleJoinButton = self:_createBattleJoinGui()
    battleJoinButton.MouseButton1Click:Connect(function()
        self:_joinBattle()
    end)
end

function BattleJoin:_createBattleJoinGui()
    -- 设置gui
    local gui = Instance.new("ScreenGui")
    gui.Parent = _playerGui
    -- 设置frame
    local frame = Instance.new("Frame")
    frame.Parent = gui

    -- 设置joinButton
    local joinButton = Instance.new("TextButton")
    joinButton.Parent = frame
    joinButton.Text = "加入战斗"
    joinButton.Size = UDim2.new(0, 100, 0, 50)
    joinButton.Position = UDim2.new(0, 0, 0, 0)

    return joinButton
end

-- 默认角色编号：1
local DEFAULT_CHAMPION_NUMBER = 1

function BattleJoin:_joinBattle()
    local success, message = _battleJoinFunction:InvokeServer(DEFAULT_CHAMPION_NUMBER)
    if success then
        print(message)
        self:_initBattleLocal()
    end
end

-- ++++++++++++++++++++

-- 初始化战斗：客户端

-- ++++++++++++++++++++

function BattleJoin:_initBattleLocal()
    _cameraLock = CameraLock.new(_player.Character, Enum.KeyCode.Tab)
    _cameraLock:activate()

    -- 设置R技能触发
    _battleInputActionCollection:addSinglePressInputAction("R", function()
        _championActionEvent:FireServer("R")
    end, false, Enum.KeyCode.R)

    -- 设置F技能触发
    _battleInputActionCollection:addSinglePressInputAction("F", function()
        _championActionEvent:FireServer("F")
    end, false, Enum.KeyCode.F)

    -- 设置A技能触发
    _battleInputActionCollection:addHoldInputAction("A", function()
        _championActionEvent:FireServer("A")
    end, 0.2, false, Enum.UserInputType.MouseButton1)

    -- 设置E技能触发
    _battleInputActionCollection:addLongPressInputAction("E", function()
        _championActionEvent:FireServer("E1")
    end, function()
        _championActionEvent:FireServer("E2")
    end, false, Enum.KeyCode.E)

    -- 设置Q技能触发
    _battleInputActionCollection:addSinglePressInputAction("Q", function()
        _championActionEvent:FireServer("Q")
    end, false, Enum.KeyCode.Q)

    -- 设置Shift技能触发
    _battleInputActionCollection:addSinglePressInputAction("Shift", function()
        _championActionEvent:FireServer("Shift")
    end, false, Enum.KeyCode.LeftShift)

    -- 设置Forward移动触发
    _battleInputActionCollection:addSinglePressInputAction("Forward", function()
        _championActionEvent:FireServer("Forward")
    end, true, Enum.KeyCode.W)

    -- 设置Left移动触发
    _battleInputActionCollection:addSinglePressInputAction("Left", function()
        _championActionEvent:FireServer("Left")
    end, true, Enum.KeyCode.A)

    -- 设置Backward移动触发
    _battleInputActionCollection:addSinglePressInputAction("Backward", function()
        _championActionEvent:FireServer("Backward")
    end, true, Enum.KeyCode.S)

    -- 设置Right移动触发
    _battleInputActionCollection:addSinglePressInputAction("Right", function()
        _championActionEvent:FireServer("Right")
    end, true, Enum.KeyCode.D)
end

-- ++++++++++++++++++++

return BattleJoin
