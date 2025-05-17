local ModelComponent = {}
ModelComponent.__index = ModelComponent

function ModelComponent.new(model: Model)
    local self = {}
    setmetatable(self, ModelComponent)

    self.model = model

    return self
end

-- ++++++++++++++++++++

function ModelComponent:getChildParts() : { BasePart }
    local parts = {}
    for _, child in self.model:GetChildren() do
        if child:IsA("BasePart") then
            table.insert(parts, child)
        end
    end
    return parts
end

function ModelComponent:getDescendantParts() : { BasePart }
    local parts = {}
    for _, descendant in self.model:GetDescendants() do
        if descendant:IsA("BasePart") then
            table.insert(parts, descendant)
        end
    end
    return parts
end

-- ++++++++++++++++++++

return ModelComponent