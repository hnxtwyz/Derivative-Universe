local ContextActionService = game:GetService("ContextActionService")

type InputActionCallback = (InputObject) -> ()

-- ++++++++++++++++++++

-- InputActionCollection

-- ++++++++++++++++++++

local InputActionCollection = {}
InputActionCollection.__index = InputActionCollection

function InputActionCollection.new(collectionName: string, collectionStructure)
    local self = {}
    setmetatable(self, InputActionCollection)
    
    self._collectionName = collectionName
    self._collectionStructure = collectionStructure

    return self
end

-- ++++++++++++++++++++

-- 接口：添加各种模式的输入行为
-- inputActionHandler内置：一对一处理，时间效率更高
-- 使用task库和线程来管理输入逻辑

-- ++++++++++++++++++++

-- 单按模式
function InputActionCollection:addSinglePressInputAction(inputActionName: string, callback: InputActionCallback, ...: Enum.KeyCode | Enum.UserInputType)
    local inputActionHandler = function(_, inputState: Enum.UserInputState, inputObject: InputObject)
        if inputState == Enum.UserInputState.Begin then
            callback(inputObject)
        end
    end
    
    self:_addInputAction(inputActionName, inputActionHandler, ...)
end

-- 释放模式
function InputActionCollection:addReleaseInputAction(inputActionName: string, callback: InputActionCallback, ...: Enum.KeyCode | Enum.UserInputType)  
    local inputActionHandler = function(_, inputState: Enum.UserInputState, inputObject: InputObject)
        if inputState == Enum.UserInputState.End then
            callback(inputObject)
        end
    end
    
    self:_addInputAction(inputActionName, inputActionHandler, ...)
end

-- 持续/变化模式
function InputActionCollection:addChangeInputAction(inputActionName: string, callback: InputActionCallback, ...: Enum.KeyCode | Enum.UserInputType)  
    local inputActionHandler = function(_, inputState: Enum.UserInputState, inputObject: InputObject)
        if inputState == Enum.UserInputState.Change then
            callback(inputObject)
        end
    end
    
    self:_addInputAction(inputActionName, inputActionHandler, ...)
end

-- 按住间隔模式
function InputActionCollection:addHoldInputAction(inputActionName: string, callback: InputActionCallback, interval: number, ...: Enum.KeyCode | Enum.UserInputType)
    local isHolding = false
    local lastTriggerTime = 0
    local thread = nil
    
    local function holdLoop(inputObject: InputObject)
        local elapsedTime = os.clock() - lastTriggerTime
        if elapsedTime < interval then
            local timeToWait = interval - elapsedTime
            task.wait(timeToWait)
        end

        repeat
            lastTriggerTime = os.clock()
            task.spawn(callback, inputObject)
        until not task.wait(interval)
    end
    
    local inputActionHandler = function(_, inputState: Enum.UserInputState, inputObject: InputObject)
        if inputState == Enum.UserInputState.Begin and not isHolding then
            isHolding = true
            thread = task.spawn(holdLoop, inputObject)
        elseif inputState == Enum.UserInputState.End and isHolding then
            isHolding = false
            if thread then
                task.cancel(thread)
            end
        end
    end
    
    self:_addInputAction(inputActionName, inputActionHandler, ...)
end

-- 按下抬起模式
function InputActionCollection:addLongPressInputAction(
    inputActionName: string, 
    pressCallback: InputActionCallback, 
    releaseCallback: InputActionCallback, 
    ...: Enum.KeyCode | Enum.UserInputType
)
    local inputActionHandler = function(_, inputState: Enum.UserInputState, inputObject: InputObject)
        if inputState == Enum.UserInputState.Begin then
            pressCallback(inputObject)
        elseif inputState == Enum.UserInputState.End then
            releaseCallback(inputObject)
        end
    end
    
    self:_addInputAction(inputActionName, inputActionHandler, ...)
end

-- 双按模式
function InputActionCollection:addDoublePressInputAction(inputActionName: string, callback: InputActionCallback, interval: number, ...: Enum.KeyCode | Enum.UserInputType)
    local pressCount = 0
    local resetThread = nil
    
    local function resetPressCount()
        task.wait(interval)
        pressCount = 0
    end
    
    local inputActionHandler = function(_, inputState: Enum.UserInputState, inputObject: InputObject)
        if inputState == Enum.UserInputState.Begin then
            pressCount += 1
            
            if resetThread then
                task.cancel(resetThread)
            end
            
            if pressCount >= 2 then
                pressCount = 0
                task.spawn(callback, inputObject)
            else
                resetThread = task.spawn(resetPressCount)
            end
        end
    end
    
    self:_addInputAction(inputActionName, inputActionHandler, ...)
end

-- ++++++++++++++++++++

-- 输入行为的底层绑定与解除

-- ++++++++++++++++++++

function InputActionCollection:_addInputAction(inputActionName: string, inputActionHandler, ...: Enum.KeyCode | Enum.UserInputType)
    self._collectionStructure[inputActionName] = true
    ContextActionService:BindAction(self:_getInputActionFullName(inputActionName), inputActionHandler, false, ...)
end

function InputActionCollection:removeInputAction(inputActionName: string)
    ContextActionService:UnbindAction(self:_getInputActionFullName(inputActionName))
    self._collectionStructure[inputActionName] = nil
end

function InputActionCollection:removeAllInputActions()
    self:_unbindAllInputActions()
    table.clear(self._collectionStructure)
end

function InputActionCollection:_unbindAllInputActions()
    for inputActionName, _ in self._collectionStructure do
        ContextActionService:UnbindAction(self:_getInputActionFullName(inputActionName))
    end
end

function InputActionCollection:_getInputActionFullName(inputActionName: string) : string
    return self._collectionName .. "_" .. inputActionName
end

-- ++++++++++++++++++++

-- InputActionService

-- ++++++++++++++++++++

local InputActionService = {}

local _inputActionNamesStore = {}

function InputActionService:getOrCreateInputActionCollection(collectionName: string) : table
    local collectionStructure = self:_getOrCreateInputActionCollectionStructure(collectionName)
    return InputActionCollection.new(collectionName, collectionStructure)
end

function InputActionService:_getOrCreateInputActionCollectionStructure(collectionName: string)
    if not _inputActionNamesStore[collectionName] then
        _inputActionNamesStore[collectionName] = {}
    end
    return _inputActionNamesStore[collectionName]
end

function InputActionService:removeInputActionCollection(collectionName: string)
    local inputActionCollection = self:getOrCreateInputActionCollection(collectionName)
    inputActionCollection:_unbindAllInputActions()
    _inputActionNamesStore[collectionName] = nil
end

-- ++++++++++++++++++++

return InputActionService
