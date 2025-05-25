local BattleObjectHandler = {}
BattleObjectHandler.__index = BattleObjectHandler

function BattleObjectHandler.new(battle)
    local self = {}
    setmetatable(self, BattleObjectHandler)

    self._battle = battle

    return self
end

function BattleObjectHandler:objectAttack(object: Instance, unitNo: number, attackFn: (table) -> ()) : RBXScriptConnection
    local hitRecord = {}
    local unitRecord = {}
    local connection = object.Touched:Connect(function(hit)
        if not hitRecord[hit] then
            hitRecord[hit] = true
            local attackingUnitNo = self._battle.findUnitCollection:getObjectTag(hit)
            if attackingUnitNo and self._battle:isEnemy(unitNo, attackingUnitNo) and not unitRecord[attackingUnitNo] then
                unitRecord[attackingUnitNo] = true
                local attackingUnitOperation = self._battle.unitOperationCollection[attackingUnitNo]
                attackFn(attackingUnitOperation)
            end
        end
    end)
    return connection
end

return BattleObjectHandler
