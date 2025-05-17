local RunService = game:GetService("RunService")

local RemotePortCollection = {}
RemotePortCollection.__index = RemotePortCollection

function RemotePortCollection.new(collectionFolder)
    local self = {}
    setmetatable(self, RemotePortCollection)

    self._collectionFolder = collectionFolder

    return self
end

function RemotePortCollection:createRemoteEvent(portName: string)
    return self:_createRemotePort(portName, "RemoteEvent")
end

function RemotePortCollection:createRemoteFunction(portName: string)
    return self:_createRemotePort(portName, "RemoteFunction")
end

function RemotePortCollection:_createRemotePort(portName: string, portType: string)
    local remotePort = Instance.new(portType)
    remotePort.Name = portName
    remotePort.Parent = self._collectionFolder
    return remotePort
end

function RemotePortCollection:waitRemotePort(portName: string)
    return self._collectionFolder:WaitForChild(portName)
end

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

function RemotePortService:createRemotePortCollection(collectionName: string)
    local collectionFolder = Instance.new("Folder")
    collectionFolder.Name = collectionName
    collectionFolder.Parent = _remoteFolder
    return RemotePortCollection.new(collectionFolder)
end

function RemotePortService:waitRemotePortCollection(collectionName: string)
    return RemotePortCollection.new(_remoteFolder:WaitForChild(collectionName))
end

-- ++++++++++++++++++++

return RemotePortService