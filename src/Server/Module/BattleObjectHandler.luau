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
    self:handleWeapon(object, unitNo, lifeTime, damage)
    Debris:AddItem(object, lifeTime)
end

function BattleObjectHandler:handleWeapon(object: Instance, unitNo: number, lifeTime: number, damage: number)
    local hitRecord = {}
    local unitRecord = {}
    local connection = nil
    connection = object.Touched:Connect(function(hit)
        if not hitRecord[hit] then
            hitRecord[hit] = true
            local attackingUnitNo = self._battle.findUnitCollection:getObjectTag(hit)
            if attackingUnitNo and self._battle:isEnemy(unitNo, attackingUnitNo) and not unitRecord[attackingUnitNo] then
                unitRecord[attackingUnitNo] = true
                self._battle.unitOperationCollection[attackingUnitNo].normalAttack(damage)
            end
        end
    end)
    task.delay(lifeTime, function()
        if connection then
            connection:Disconnect()
        end
    end)
end

return BattleObjectHandler
