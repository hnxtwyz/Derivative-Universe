local DataProcessing = {}

-- 将字典的键值分别拆分为数组，使其可以进行网络传输
function DataProcessing:splitDictionary(dictionary)
    local kvArray = { _k = {}, _v = {} }
    for k, v in dictionary do
        table.insert(kvArray._k, k)
        table.insert(kvArray._v, v)
    end
    return kvArray
end

-- 对一个拆分字典进行还原
function DataProcessing:revertDictionary(kvArray)
    local dictionary = {}
    for i = 1, #kvArray._k do
        dictionary[kvArray._k[i]] = kvArray._v[i]
    end
    return dictionary
end

-- 添加数组元素
function DataProcessing:addArrayElement(array, element) : boolean
    if not table.find(array, element) then
        table.insert(array, element)
        return true
    end
    return false
end

-- 移除数组元素
function DataProcessing:removeArrayElement(array, element) : boolean
    local index = table.find(array, element)
    if index then
        table.remove(array, index)
        return true
    end
    return false
end

return DataProcessing