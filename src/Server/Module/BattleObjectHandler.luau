local Debris = game:GetService("Debris")

local BattleObjectHandler = {}
BattleObjectHandler.__index = BattleObjectHandler

function BattleObjectHandler.new(battle)
    local self = {}
    setmetatable(self, BattleObjectHandler)

    self._battle = battle

    return self
end

function BattleObjectHandler:handleObject(object: Instance, unitNo: number, lifeTime: number, damage: number)
    Debris:AddItem(object, lifeTime)

    local hitRecord = {}
    local unitRecord = {}
    object.Touched:Connect(function(hit)
        if not hitRecord[hit] then
            hitRecord[hit] = true
            local attackingUnitNo = self._battle.findUnitCollection:getObjectTag(hit)
            if attackingUnitNo and self._battle:isEnemy(unitNo, attackingUnitNo) and not unitRecord[attackingUnitNo] then
                unitRecord[attackingUnitNo] = true
                self._battle.unitOperationCollection[attackingUnitNo].normalAttack(damage)
            end
        end
    end)
end

return BattleObjectHandler
