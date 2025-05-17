local ModelComponent = {}

-- ++++++++++++++++++++

function ModelComponent:getChildParts(model: Model) : { BasePart }
    local parts = {}
    for _, child in model:GetChildren() do
        if child:IsA("BasePart") then
            table.insert(parts, child)
        end
    end
    return parts
end

function ModelComponent:getDescendantParts(model: Model) : { BasePart }
    local parts = {}
    for _, descendant in model:GetDescendants() do
        if descendant:IsA("BasePart") then
            table.insert(parts, descendant)
        end
    end
    return parts
end

-- ++++++++++++++++++++

return ModelComponent