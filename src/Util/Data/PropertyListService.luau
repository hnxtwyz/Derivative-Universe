local RunService = game:GetService("RunService")

local RemotePortService = require(game.ReplicatedStorage.Util.Remote.RemotePortService)
local DataProcessing = require(game.ReplicatedStorage.Util.Data.DataProcessing)

-- ++++++++++++++++++++

-- 建立远程端口

-- ++++++++++++++++++++

local IS_SERVER = RunService:IsServer()

local REMOTE_PORT_COLLECTION_NAME = "PropertyListService"
local DATA_REPLICATE_FUNCTION_NAME = "DataReplicateFunction"
local SERVICE_SYNC_EVENT_NAME = "ServiceSyncEvent"
local COLLECTION_SYNC_EVENT_NAME = "CollectionSyncEvent"
local LIST_SYNC_EVENT_NAME = "ListSyncEvent"

local _remotePortCollection
local _dataReplicateFunction
local _serviceSyncEvent
local _collectionSyncEvent
local _listSyncEvent

if IS_SERVER then
    _remotePortCollection = RemotePortService:getOrCreateRemotePortCollection(REMOTE_PORT_COLLECTION_NAME)
    _dataReplicateFunction = _remotePortCollection:getOrCreateRemoteFunction(DATA_REPLICATE_FUNCTION_NAME)
    _serviceSyncEvent = _remotePortCollection:getOrCreateRemoteEvent(SERVICE_SYNC_EVENT_NAME)
    _collectionSyncEvent = _remotePortCollection:getOrCreateRemoteEvent(COLLECTION_SYNC_EVENT_NAME)
    _listSyncEvent = _remotePortCollection:getOrCreateRemoteEvent(LIST_SYNC_EVENT_NAME)
else
    _remotePortCollection = RemotePortService:waitRemotePortCollection(REMOTE_PORT_COLLECTION_NAME)
    _dataReplicateFunction = _remotePortCollection:waitRemotePort(DATA_REPLICATE_FUNCTION_NAME)
    _serviceSyncEvent = _remotePortCollection:waitRemotePort(SERVICE_SYNC_EVENT_NAME)
    _collectionSyncEvent = _remotePortCollection:waitRemotePort(COLLECTION_SYNC_EVENT_NAME)
    _listSyncEvent = _remotePortCollection:waitRemotePort(LIST_SYNC_EVENT_NAME)
end

-- ++++++++++++++++++++

-- PropertyList

-- ++++++++++++++++++++

local PropertyList = {}
PropertyList.__index = PropertyList

function PropertyList.new(listCollectionName: string, connectedObject: any, listStructure)
    local self = {}
    setmetatable(self, PropertyList)

    self._listCollectionName = listCollectionName
    self._connectedObject = connectedObject
    self._listStructure = listStructure
    
    return self
end

function PropertyList:_syncToClient(method: string, ...: any)
    if IS_SERVER then
        _listSyncEvent:FireAllClients(self._listCollectionName, self._connectedObject, method, ...)
    end
end

function PropertyList:setProperty(property: string, value: any)
    self._listStructure[property] = value

    self:_syncToClient("setProperty", property, value)
end

function PropertyList:setProperties(propertyList)
    for property, value in propertyList do
        self._listStructure[property] = value
    end

    self:_syncToClient("setProperties", propertyList)
end

function PropertyList:getProperty(property: string)
    return self._listStructure[property]
end

function PropertyList:getAllProperties()
    return self._listStructure
end

-- ++++++++++++++++++++

-- PropertyListCollection

-- ++++++++++++++++++++

local PropertyListCollection = {}
PropertyListCollection.__index = PropertyListCollection

function PropertyListCollection.new(collectionName: string, collectionData)
    local self = {}
    setmetatable(self, PropertyListCollection)

    self._listCollectionName = collectionName
    self._listCollectionData = collectionData
    
    return self
end

function PropertyListCollection:_syncToClient(method: string, ...: any)
    if IS_SERVER then
        _collectionSyncEvent:FireAllClients(self._listCollectionName, method, ...)
    end
end

function PropertyListCollection:getOrCreatePropertyList(connectedObject: any)
    return PropertyList.new(self._listCollectionName, connectedObject, self:_getOrCreatePropertyListStructure(connectedObject))
end

function PropertyListCollection:_getOrCreatePropertyListStructure(connectedObject: any)
    if not self._listCollectionData[connectedObject] then
        self._listCollectionData[connectedObject] = {}
    end
    return self._listCollectionData[connectedObject]
end

function PropertyListCollection:clearPropertyList(connectedObject: any)
    self._listCollectionData[connectedObject] = nil

    self:_syncToClient("clearPropertyList", connectedObject)
end

-- ++++++++++++++++++++

-- PropertyListService

-- ++++++++++++++++++++

local PropertyListService = {}

local _serviceData

function PropertyListService:_syncToClient(method: string, ...: any)
    if IS_SERVER then
        _serviceSyncEvent:FireAllClients(method, ...)
    end
end

function PropertyListService:getOrCreatePropertyListCollection(collectionName: string)
    local collectionData = self:_getOrCreatePropertyListCollectionData(collectionName)
    return PropertyListCollection.new(collectionName, collectionData)
end

function PropertyListService:_getOrCreatePropertyListCollectionData(collectionName: string)
    if not _serviceData[collectionName] then
        _serviceData[collectionName] = {}
    end
    return _serviceData[collectionName]
end

function PropertyListService:clearPropertyListCollection(collectionName: string)
    _serviceData[collectionName] = nil

    self:_syncToClient("clearPropertyListCollection", collectionName)
end

-- ++++++++++++++++++++

-- 数据初始化和同步

-- ++++++++++++++++++++

-- 数据拆分，使其可以进行网络传输
local function _dataSplit()
    local splitServiceData = {}

    for collectionName, collectionData in _serviceData do
        splitServiceData[collectionName] = DataProcessing:splitDictionary(collectionData)
    end

    return splitServiceData
end

-- 数据还原
local function _dataRevert(splitServiceData)
    local originServiceData = {}

    for collectionName, splitCollectionData in splitServiceData do
        originServiceData[collectionName] = DataProcessing:revertDictionary(splitCollectionData)
    end

    return originServiceData
end

-- 同步函数

local function _serviceSync(method: string, ...: any)
    PropertyListService[method](PropertyListService, ...)
end

local function _collectionSync(listCollectionName: string, method: string, ...: any)
    local listCollection = PropertyListService:getOrCreatePropertyListCollection(listCollectionName)
    listCollection[method](listCollection, ...)
end

local function _listSync(listCollectionName: string, connectedObject: any, method: string, ...: any)
    local listCollection = PropertyListService:getOrCreatePropertyListCollection(listCollectionName)
    local list = listCollection:getOrCreatePropertyList(connectedObject)
    list[method](list, ...)
end

-- 初始化数据，设置同步
if IS_SERVER then
    _serviceData = {}

    _dataReplicateFunction.OnServerInvoke = _dataSplit
else
    _serviceData = _dataRevert(_dataReplicateFunction:InvokeServer())

    _serviceSyncEvent.OnClientEvent:Connect(_serviceSync)
    _collectionSyncEvent.OnClientEvent:Connect(_collectionSync)
    _listSyncEvent.OnClientEvent:Connect(_listSync)
end

-- ++++++++++++++++++++

return PropertyListService