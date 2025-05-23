local Debris = game:GetService("Debris")

local BattleObjectHandler = {}
BattleObjectHandler.__index = BattleObjectHandler

function BattleObjectHandler.new(context)
    local self = {}
    setmetatable(self, BattleObjectHandler)

    self._findUnitCollection = context.findUnitCollection
    self._unitTeamCollection = context.unitTeamCollection
    self._unitOperationCollection = context.unitOperationCollection

    return self
end

function BattleObjectHandler:handleObject(object: Instance, unitNo: number, lifeTime: number, damage: number)
    Debris:AddItem(object, lifeTime)

    local hitRecord = {}
    local unitRecord = {}
    object.Touched:Connect(function(hit)
        if not hitRecord[hit] then
            hitRecord[hit] = true
            local attackingUnitNo = self._findUnitCollection:getObjectTag(hit)
            if attackingUnitNo and not unitRecord[attackingUnitNo] then
                unitRecord[attackingUnitNo] = true
                self._unitOperationCollection[attackingUnitNo].normalAttack(damage)
            end
        end
    end)
end

return BattleObjectHandler
