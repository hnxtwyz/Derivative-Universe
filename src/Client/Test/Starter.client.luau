local UiManage = require(game.ReplicatedStorage.Util.Ui.UiManage)
local BattleJoin = require(game.ReplicatedStorage.ClientModule.BattleJoin)

UiManage:disableCoreGuiExceptHealth()

BattleJoin:initBattleJoinGui()
