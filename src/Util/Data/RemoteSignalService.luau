local RunService = game:GetService("RunService")

local RemotePortService = require(game.ReplicatedStorage.Util.Remote.RemotePortService)
local Signal = require(game.ReplicatedStorage.Util.Data.Signal)

-- ++++++++++++++++++++

-- 建立远程端口

-- ++++++++++++++++++++

local IS_SERVER = RunService:IsServer()
local IS_CLIENT = not IS_SERVER

local REMOTE_PORT_COLLECTION_NAME = "RemoteSignalService"
local SERVICE_SYNC_EVENT_NAME = "ServiceSyncEvent"
local COLLECTION_SYNC_EVENT_NAME = "CollectionSyncEvent"
local LIST_SYNC_EVENT_NAME = "ListSyncEvent"
local SIGNAL_SYNC_EVENT_NAME = "SignalSyncEvent"

local _remotePortCollection
local _serviceSyncEvent
local _collectionSyncEvent
local _listSyncEvent
local _signalSyncEvent

if IS_SERVER then
    _remotePortCollection = RemotePortService:createRemotePortCollection(REMOTE_PORT_COLLECTION_NAME)
    _serviceSyncEvent = _remotePortCollection:createRemoteEvent(SERVICE_SYNC_EVENT_NAME)
    _collectionSyncEvent = _remotePortCollection:createRemoteEvent(COLLECTION_SYNC_EVENT_NAME)
    _listSyncEvent = _remotePortCollection:createRemoteEvent(LIST_SYNC_EVENT_NAME)
    _signalSyncEvent = _remotePortCollection:createRemoteEvent(SIGNAL_SYNC_EVENT_NAME)
else
    _remotePortCollection = RemotePortService:waitRemotePortCollection(REMOTE_PORT_COLLECTION_NAME)
    _serviceSyncEvent = _remotePortCollection:waitRemotePort(SERVICE_SYNC_EVENT_NAME)
    _collectionSyncEvent = _remotePortCollection:waitRemotePort(COLLECTION_SYNC_EVENT_NAME)
    _listSyncEvent = _remotePortCollection:waitRemotePort(LIST_SYNC_EVENT_NAME)
    _signalSyncEvent = _remotePortCollection:waitRemotePort(SIGNAL_SYNC_EVENT_NAME)
end

-- ++++++++++++++++++++

-- RemoteSignal

-- ++++++++++++++++++++

local RemoteSignal = {}
RemoteSignal.__index = RemoteSignal

function RemoteSignal.new(objectCollectionName: string, connectedObject: any, signalName: string, realSignal)
    local self = {}
    setmetatable(self, RemoteSignal)

    self._objectCollectionName = objectCollectionName
    self._connectedObject = connectedObject
    self._signalName = signalName
    self._realSignal = realSignal
    
    return self
end

function RemoteSignal:_syncToClient(method: string, ...: any)
    if IS_SERVER then
        _signalSyncEvent:FireAllClients(self._objectCollectionName, self._connectedObject, self._signalName, method, ...)
    end
end

function RemoteSignal:Fire(...: any)
    self._realSignal:Fire(...)

    self:_syncToClient("Fire", ...)
end

function RemoteSignal:Connect(callback: (...any) -> ())
    return self._realSignal:Connect(callback)
end

function RemoteSignal:Wait()
    return self._realSignal:Wait()
end

function RemoteSignal:DisconnectAll()
    self._realSignal:DisconnectAll()

    self:_syncToClient("DisconnectAll")
end

-- ++++++++++++++++++++

-- SignalList

-- ++++++++++++++++++++

local SignalList = {}
SignalList.__index = SignalList

function SignalList.new(listCollectionName: string, connectedObject: any, listData)
    local self = {}
    setmetatable(self, SignalList)

    self._listCollectionName = listCollectionName
    self._connectedObject = connectedObject
    self._listData = listData
    
    return self
end

function SignalList:_syncToClient(method: string, ...: any)
    if IS_SERVER then
        _listSyncEvent:FireAllClients(self._listCollectionName, self._connectedObject, method, ...)
    end
end

function SignalList:getOrCreateSignal(signalName: string)
    local realSignal = self:_getOrCreateRealSignal(signalName)
    return RemoteSignal.new(self._listCollectionName, self._connectedObject, signalName, realSignal)
end

function SignalList:_getOrCreateRealSignal(signalName: string)
    if not self._listData[signalName] then
        self._listData[signalName] = Signal.new()
    end
    return self._listData[signalName]
end

function SignalList:clearSignal(signalName: string)
    self._listData[signalName] = nil

    self:_syncToClient("clearSignal", signalName)
end

-- ++++++++++++++++++++

-- SignalListCollection

-- ++++++++++++++++++++

local SignalListCollection = {}
SignalListCollection.__index = SignalListCollection

function SignalListCollection.new(collectionName: string, collectionData)
    local self = setmetatable({}, SignalListCollection)

    self._listCollectionName = collectionName
    self._listCollectionData = collectionData
    
    return self
end

function SignalListCollection:_syncToClient(method: string, ...: any)
    if IS_SERVER then
        _collectionSyncEvent:FireAllClients(self._listCollectionName, method, ...)
    end
end

function SignalListCollection:getOrCreateSignalList(connectedObject: any)
    local listData = self:_getOrCreateSignalListData(connectedObject)
    return SignalList.new(self._listCollectionName, connectedObject, listData)
end

function SignalListCollection:_getOrCreateSignalListData(connectedObject: any)
    if not self._listCollectionData[connectedObject] then
        self._listCollectionData[connectedObject] = {}
    end
    return self._listCollectionData[connectedObject]
end

function SignalListCollection:clearSignalList(connectedObject: any)
    self._listCollectionData[connectedObject] = nil

    self:_syncToClient("clearSignalList", connectedObject)
end

-- ++++++++++++++++++++

-- RemoteSignalService

-- ++++++++++++++++++++

local RemoteSignalService = {}

local _serviceData = {}

function RemoteSignalService:_syncToClient(method: string, ...: any)
    if IS_SERVER then
        _serviceSyncEvent:FireAllClients(method, ...)
    end
end

function RemoteSignalService:getOrCreateSignalListCollection(collectionName: string)
    local collectionData = self:_getOrCreateSignalListCollectionData(collectionName)
    return SignalListCollection.new(collectionName, collectionData)
end

function RemoteSignalService:_getOrCreateSignalListCollectionData(collectionName: string)
    if not _serviceData[collectionName] then
        _serviceData[collectionName] = {}
    end
    return _serviceData[collectionName]
end

function RemoteSignalService:clearSignalListCollection(collectionName: string)
    _serviceData[collectionName] = nil

    self:_syncToClient("clearSignalListCollection", collectionName)
end

-- ++++++++++++++++++++

-- 数据同步

-- ++++++++++++++++++++

local function serviceSync(method: string, ...: any)
    RemoteSignalService[method](RemoteSignalService, ...)
end

local function collectionSync(listCollectionName: string, method: string, ...: any)
    local listCollection = RemoteSignalService:getOrCreateSignalListCollection(listCollectionName)
    listCollection[method](listCollection, ...)
end

local function listSync(listCollectionName: string, connectedObject: any, method: string, ...: any)
    local listCollection = RemoteSignalService:getOrCreateSignalListCollection(listCollectionName)
    local list = listCollection:getOrCreateSignalList(connectedObject)
    list[method](list, ...)
end

local function signalSync(listCollectionName: string, connectedObject: any, signalName: string, method: string, ...: any)
    local listCollection = RemoteSignalService:getOrCreateSignalListCollection(listCollectionName)
    local list = listCollection:getOrCreateSignalList(connectedObject)
    local signal = list:getOrCreateSignal(signalName)
    signal[method](signal, ...)
end

-- 设置同步
if IS_CLIENT then
    _serviceSyncEvent.OnClientEvent:Connect(serviceSync)
    _collectionSyncEvent.OnClientEvent:Connect(collectionSync)
    _listSyncEvent.OnClientEvent:Connect(listSync)
    _signalSyncEvent.OnClientEvent:Connect(signalSync)
end

-- ++++++++++++++++++++

return RemoteSignalService