local PlayerManage = require(game.ReplicatedStorage.Util.Player.PlayerManage)
local BattleInit = require(game.ServerScriptService.ServerModule.BattleInit)

PlayerManage:disableCharacterAutoLoad()

PlayerManage:restrictPlayerCameraZoom()

BattleInit:init()
