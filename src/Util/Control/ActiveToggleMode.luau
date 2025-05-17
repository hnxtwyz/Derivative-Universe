local ActiveToggleMode = {}
ActiveToggleMode.__index = ActiveToggleMode

function ActiveToggleMode.new()
    local self = {}
    setmetatable(self, ActiveToggleMode)

    self._isActive = false
    self._isToggled = false

    return self
end

function ActiveToggleMode:activate()
    if self._isActive then return end
    if not self:_activateTest() then return end
    self._isActive = true

    if self._isToggled then
        self:_enableToggle()
    end
end

function ActiveToggleMode:deactivate()
    if not self._isActive then return end
    self._isActive = false

    if self._isToggled then
        self:_disableToggle()
    end
end

function ActiveToggleMode:toggle()
    self._isToggled = not self._isToggled

    if self._isActive then
        if self._isToggled then
            self:_enableToggle()
        else
            self:_disableToggle()
        end
    end
end

-- ++++++++++++++++++++

-- 重写区

-- ++++++++++++++++++++

function ActiveToggleMode:_activateTest()
    return true
end

function ActiveToggleMode:_enableToggle()

end

function ActiveToggleMode:_disableToggle()

end

return ActiveToggleMode
