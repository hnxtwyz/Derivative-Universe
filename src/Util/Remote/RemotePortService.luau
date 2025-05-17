local RunService = game:GetService("RunService")

-- ++++++++++++++++++++

-- RemotePortCollection

-- ++++++++++++++++++++

local RemotePortCollection = {}
RemotePortCollection.__index = RemotePortCollection

function RemotePortCollection.new(collectionFolder)
    local self = {}
    setmetatable(self, RemotePortCollection)

    self._collectionFolder = collectionFolder

    return self
end

function RemotePortCollection:getOrCreateRemoteEvent(portName: string)
    return self:_getOrCreateRemotePort(portName, "RemoteEvent")
end

function RemotePortCollection:getOrCreateRemoteFunction(portName: string)
    return self:_getOrCreateRemotePort(portName, "RemoteFunction")
end

function RemotePortCollection:_getOrCreateRemotePort(portName: string, portType: string)
    local remotePort = self._collectionFolder:FindFirstChild(portName)
    if not remotePort then
        remotePort = Instance.new(portType)
        remotePort.Name = portName
        remotePort.Parent = self._collectionFolder
    end
    return remotePort
end

function RemotePortCollection:waitRemotePort(portName: string)
    return self._collectionFolder:WaitForChild(portName)
end

-- ++++++++++++++++++++

-- RemotePortService

-- ++++++++++++++++++++

local RemotePortService = {}

local _remoteFolder
local IS_SERVER = RunService:IsServer()
if IS_SERVER then
    _remoteFolder = Instance.new("Folder")
    _remoteFolder.Name = "Remote"
    _remoteFolder.Parent = game.ReplicatedStorage
else
    _remoteFolder = game.ReplicatedStorage:WaitForChild("Remote")
end

function RemotePortService:getOrCreateRemotePortCollection(collectionName: string)
    local collectionFolder = _remoteFolder:FindFirstChild(collectionName)
    if not collectionFolder then
        collectionFolder = Instance.new("Folder")
        collectionFolder.Name = collectionName
        collectionFolder.Parent = _remoteFolder
    end
    return RemotePortCollection.new(collectionFolder)
end

function RemotePortService:waitRemotePortCollection(collectionName: string)
    return RemotePortCollection.new(_remoteFolder:WaitForChild(collectionName))
end

-- ++++++++++++++++++++

return RemotePortService