local RunService = game:GetService("RunService")

local RemotePortService = require(game.ReplicatedStorage.Util.Remote.RemotePortService)
local DataProcessing = require(game.ReplicatedStorage.Util.Data.DataProcessing)

-- ++++++++++++++++++++

-- 建立远程端口

-- ++++++++++++++++++++

local IS_SERVER = RunService:IsServer()

local REMOTE_PORT_COLLECTION_NAME = "ObjectTagService"
local DATA_REPLICATE_FUNCTION_NAME = "DataReplicateFunction"
local SERVICE_SYNC_EVENT_NAME = "ServiceSyncEvent"
local COLLECTION_SYNC_EVENT_NAME = "CollectionSyncEvent"

local _remotePortCollection
local _dataReplicateFunction
local _serviceSyncEvent
local _collectionSyncEvent

-- 服务器创建，客户端等待
if IS_SERVER then
    _remotePortCollection = RemotePortService:getOrCreateRemotePortCollection(REMOTE_PORT_COLLECTION_NAME)
    _dataReplicateFunction = _remotePortCollection:getOrCreateRemoteFunction(DATA_REPLICATE_FUNCTION_NAME)
    _serviceSyncEvent = _remotePortCollection:getOrCreateRemoteEvent(SERVICE_SYNC_EVENT_NAME)
    _collectionSyncEvent = _remotePortCollection:getOrCreateRemoteEvent(COLLECTION_SYNC_EVENT_NAME)
else
    _remotePortCollection = RemotePortService:waitRemotePortCollection(REMOTE_PORT_COLLECTION_NAME)
    _dataReplicateFunction = _remotePortCollection:waitRemotePort(DATA_REPLICATE_FUNCTION_NAME)
    _serviceSyncEvent = _remotePortCollection:waitRemotePort(SERVICE_SYNC_EVENT_NAME)
    _collectionSyncEvent = _remotePortCollection:waitRemotePort(COLLECTION_SYNC_EVENT_NAME)
end

-- ++++++++++++++++++++

-- SotCollection（单标签）

-- ++++++++++++++++++++

local SotCollection = {}
SotCollection.__index = SotCollection

function SotCollection.new(collectionName: string, collectionData)
    local self = {}
    setmetatable(self, SotCollection)

    self._collectionName = collectionName
    self._collectionData = collectionData
    
    return self
end

function SotCollection:_syncToClient(method: string, ...: any)
    if IS_SERVER then
        _collectionSyncEvent:FireAllClients("Sot", self._collectionName, method, ...)
    end
end

function SotCollection:setObjectTag(object: any, tag: any)
    local oldTag = self._collectionData.objectToTag[object]

    if tag == oldTag then return end

    -- 旧标签清除物体
    if oldTag then
        local objects = self._collectionData.tagToObjects[oldTag]
        DataProcessing:removeArrayElement(objects, object)
    end

    -- 设置新标签
    self._collectionData.objectToTag[object] = tag
    if tag then
        -- 获取/创建新标签的物体列表
        if not self._collectionData.tagToObjects[tag] then
            self._collectionData.tagToObjects[tag] = {}
        end
        local objects = self._collectionData.tagToObjects[tag]
        table.insert(objects, object)
    end
    
    self:_syncToClient("setObjectTag", object, tag)
end

function SotCollection:getObjectTag(object: any) : any
    return self._collectionData.objectToTag[object]
end

function SotCollection:getTaggedObjects(tag: any) : { any }
    return self._collectionData.tagToObjects[tag] or {}
end

-- ++++++++++++++++++++

-- MotCollection（多标签）

-- ++++++++++++++++++++

local MotCollection = {}
MotCollection.__index = MotCollection

function MotCollection.new(collectionName: string, collectionData)
    local self = {}
    setmetatable(self, MotCollection)

    self._collectionName = collectionName
    self._collectionData = collectionData

    return self
end

function MotCollection:_syncToClient(method: string, ...: any)
    if IS_SERVER then
        _collectionSyncEvent:FireAllClients("Mot", self._collectionName, method, ...)
    end
end

function MotCollection:addObjectTag(object: any, tag: any)
    -- 创建/获取对应标签/物体列表
    if not self._collectionData.objectToTags[object] then
        self._collectionData.objectToTags[object] = {}
    end
    if not self._collectionData.tagToObjects[tag] then
        self._collectionData.tagToObjects[tag] = {}
    end
    local objectToTags = self._collectionData.objectToTags
    local tagToObjects = self._collectionData.tagToObjects

    -- 标签关联物体
    if not table.find(objectToTags[object], tag) then
        table.insert(objectToTags[object], tag)
    end
    -- 物体关联标签
    if not table.find(tagToObjects[tag], object) then
        table.insert(tagToObjects[tag], object)
    end

    self:_syncToClient("addObjectTag", object, tag)
end

function MotCollection:removeObjectTag(object: any, tag: any)
    local objectToTags = self._collectionData.objectToTags
    local tagToObjects = self._collectionData.tagToObjects

    -- 移除物体关联标签
    local tags = objectToTags[object]
    if tags then
        DataProcessing:removeArrayElement(tags, tag)
    end

    -- 移除标签关联物体
    local objects = tagToObjects[tag]
    if objects then
        DataProcessing:removeArrayElement(objects, object)
    end

    self:_syncToClient("removeObjectTag", object, tag)
end

function MotCollection:getObjectTags(object: any) : { any }
    return self._collectionData.objectToTags[object] or {}
end

function MotCollection:getTaggedObjects(tag: any) : { any }
    return self._collectionData.tagToObjects[tag] or {}
end

-- 得到并集
function MotCollection:getObjectsInTags(tags: { any }) : { any }
    local result = {}
    local seen = {}

    for _, tag in tags do
        local objects = self._collectionData.tagToObjects[tag]
        if objects then
            -- 迭代每个标签物体列表中的物体，并记录唯一性
            for _, object in objects do
                if not seen[object] then
                    seen[object] = true
                    table.insert(result, object)
                end
            end
        end
    end

    return result
end

-- 得到交集
function MotCollection:getObjectsWithTags(tags: { any }) : { any }
    if #tags == 0 then
        return {}
    end

    local lastTag = table.remove(tags)
    local lastTagObjects = self._collectionData.tagToObjects[lastTag]

    if not lastTagObjects then
        return {}
    end

    local result = {}
    -- 选取最后一个标签关联的所有物体
    for _, object in lastTagObjects do
        local hasAllTags = true
        -- 检查物体是否具有其他标签
        for _, t in tags do
            -- 检查方法：在每个标签的物体列表中是否能找到
            local objects = self._collectionData.tagToObjects[t]
            if not objects or not table.find(objects, object) then
                -- 有一个没找到，则物体不满足条件
                hasAllTags = false
                break
            end
        end

        -- 满足条件时，插入结果
        if hasAllTags then
            table.insert(result, object)
        end
    end

    return result
end

-- ++++++++++++++++++++

-- ObjectTagService
-- Sot：Single Object Tag 一个对象一个标签
-- Mot：Multi Object Tags 一个对象多个标签

-- ++++++++++++++++++++

local ObjectTagService = {}

local _serviceData

function ObjectTagService:_syncToClient(method: string, ...: any)
    if IS_SERVER then
        _serviceSyncEvent:FireAllClients(method, ...)
    end
end

function ObjectTagService:getOrCreateSotCollection(collectionName: string)
    local collectionData = self:_getOrCreateSotCollectionData(collectionName)
    return SotCollection.new(collectionName, collectionData)
end

function ObjectTagService:_getOrCreateSotCollectionData(collectionName: string)
    if not _serviceData[collectionName] then
        _serviceData[collectionName] = {
            objectToTag = {},
            tagToObjects = {}
        }
    end
    return _serviceData[collectionName]
end

function ObjectTagService:getOrCreateMotCollection(collectionName: string)
    local collectionData = self:_getOrCreateMotCollectionData(collectionName)
    return MotCollection.new(collectionName, collectionData)
end

function ObjectTagService:_getOrCreateMotCollectionData(collectionName: string)
    if not _serviceData[collectionName] then
        _serviceData[collectionName] = {
            objectToTags = {},
            tagToObjects = {}
        }
    end
    return _serviceData[collectionName]
end

function ObjectTagService:clearCollection(collectionName: string)
    _serviceData[collectionName] = nil

    self:_syncToClient("clearCollection", collectionName)
end

-- ++++++++++++++++++++

-- 数据初始化和同步

-- ++++++++++++++++++++

-- 数据拆分，使其可以进行网络传输
local function _dataSplit()
    local splitServiceData = {}

    for collectionName, collectionData in _serviceData do
        splitServiceData[collectionName] = {}
        local splitCollectionData = splitServiceData[collectionName]

        for term, mapList in collectionData do
            splitCollectionData[term] = DataProcessing:splitDictionary(mapList)
        end
    end
    
    return splitServiceData
end

-- 数据还原
local function _dataRevert(splitServiceData)
    local originServiceData = {}

    for collectionName, splitCollectionData in splitServiceData do
        originServiceData[collectionName] = {}
        local originCollectionData = originServiceData[collectionName]

        for term, splitMapList in splitCollectionData do
            originCollectionData[term] = DataProcessing:revertDictionary(splitMapList)
        end
    end
    
    return originServiceData
end

-- 同步函数

local function _serviceSync(method: string, ...: any)
    ObjectTagService[method](ObjectTagService, ...)
end

local function _collectionSync(collectionType: string, collectionName: string, method: string, ...: any)
    local collection

    if collectionType == "Sot" then
        collection = ObjectTagService:getOrCreateSotCollection(collectionName)
    elseif collectionType == "Mot" then
        collection = ObjectTagService:getOrCreateMotCollection(collectionName)
    end

    collection[method](collection, ...)
end

-- 初始化数据，设置同步
if IS_SERVER then
    _serviceData = {}

    _dataReplicateFunction.OnServerInvoke = _dataSplit
else
    _serviceData = _dataRevert(_dataReplicateFunction:InvokeServer())

    _serviceSyncEvent.OnClientEvent:Connect(_serviceSync)
    _collectionSyncEvent.OnClientEvent:Connect(_collectionSync)
end

-- ++++++++++++++++++++

return ObjectTagService
