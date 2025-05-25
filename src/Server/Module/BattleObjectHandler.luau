local BattleObjectHandler = {}
BattleObjectHandler.__index = BattleObjectHandler

function BattleObjectHandler.new(battle)
    local self = {}
    setmetatable(self, BattleObjectHandler)

    self._battle = battle

    return self
end

function BattleObjectHandler:objectTouch(object: Instance, fn: (number) -> ()) : RBXScriptConnection
    local hitRecord = {}
    local unitRecord = {}
    return object.Touched:Connect(function(hit)
        if not hitRecord[hit] then
            hitRecord[hit] = true
            local touchedUnitNo = self._battle.findUnitCollection:getObjectTag(hit)
            if touchedUnitNo and not unitRecord[touchedUnitNo] then
                unitRecord[touchedUnitNo] = true
                fn(touchedUnitNo)
            end
        end
    end)
end

return BattleObjectHandler
