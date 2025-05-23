local ObjectTagService = require(game.ReplicatedStorage.Util.Data.ObjectTagService)
local PropertyListService = require(game.ReplicatedStorage.Util.Data.PropertyListService)
local RemoteSignalService = require(game.ReplicatedStorage.Util.Data.RemoteSignalService)

local UnitInitializer = require(script.Parent.UnitInitializer)
local BattleObjectHandler = require(script.Parent.BattleObjectHandler)

local Battle = {}
Battle.__index = Battle

function Battle.new(battleNo: number)
    local self = {}
    setmetatable(self, Battle)

    self.unitOperationCollection = {}

    self._battleNo = battleNo
    self._unitCount = 0

    self._findUnitCollection = ObjectTagService:getOrCreateSotCollection("Battle" .. battleNo .. "_FindUnitCollection")
    self._unitTeamCollection = ObjectTagService:getOrCreateSotCollection("Battle" .. battleNo .. "_UnitTeamCollection")
    self._unitAttributeListCollection = PropertyListService:getOrCreatePropertyListCollection("Battle" .. battleNo .. "_UnitAttributeListCollection")
    self._unitSignalListCollection = RemoteSignalService:getOrCreateSignalListCollection("Battle" .. battleNo .. "_UnitSignalListCollection")

    self._battleObjectHandler = BattleObjectHandler.new({
        findUnitCollection = self._findUnitCollection,
        unitTeamCollection = self._unitTeamCollection,
        unitOperationCollection = self.unitOperationCollection,
    })

    return self
end

function Battle:_getNextUnitNo() : number
    self._unitCount += 1
    return self._unitCount
end

function Battle:addUnit(unitModel: Model, isPlayer: boolean?) : number
    local unitNo = self:_getNextUnitNo()
    self.unitOperationCollection[unitNo] = {}
    local context = {
        unitOperationCollection = self.unitOperationCollection,
        findUnitCollection = self._findUnitCollection,
        unitTeamCollection = self._unitTeamCollection,
        unitAttributeList = self._unitAttributeListCollection:getOrCreatePropertyList(unitNo),
        unitSignalList = self._unitSignalListCollection:getOrCreateSignalList(unitNo),
        battleObjectHandler = self._battleObjectHandler,
    }
    local unitInitializer = UnitInitializer.new(unitNo, unitModel, context)
    unitInitializer:initUnit()
    if isPlayer then
        unitInitializer:initSkillA()
    end
    return unitNo
end

return Battle
