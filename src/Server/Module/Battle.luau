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

    self.battleNo = battleNo
    self.unitCount = 0

    self.findUnitCollection = ObjectTagService:getOrCreateSotCollection("Battle" .. battleNo .. "_FindUnitCollection")
    self.unitTeamCollection = ObjectTagService:getOrCreateSotCollection("Battle" .. battleNo .. "_UnitTeamCollection")
    self.unitAttributeListCollection = PropertyListService:getOrCreatePropertyListCollection("Battle" .. battleNo .. "_UnitAttributeListCollection")
    self.unitSignalListCollection = RemoteSignalService:getOrCreateSignalListCollection("Battle" .. battleNo .. "_UnitSignalListCollection")

    self.battleObjectHandler = BattleObjectHandler.new(self)

    return self
end

function Battle:getNextUnitNo() : number
    self.unitCount += 1
    return self.unitCount
end

Battle.DEFAULT_TEAM_NAME = "Default"

function Battle:isEnemy(unitNo1: number, unitNo2: number) : boolean
    local team1 = self.unitTeamCollection:getObjectTag(unitNo1)
    local team2 = self.unitTeamCollection:getObjectTag(unitNo2)
    return team1 ~= team2 or team1 == Battle.DEFAULT_TEAM_NAME and unitNo1 ~= unitNo2
end

function Battle:addUnit(unitModel: Model, isPlayer: boolean?) : number
    local unitInitializer = UnitInitializer.new(unitModel, self)
    local unitNo = unitInitializer:initUnit()
    if isPlayer then
        unitInitializer:initSkill()
    end
    return unitNo
end

return Battle
