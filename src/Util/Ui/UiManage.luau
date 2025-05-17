local StarterGui = game:GetService("StarterGui")

local UiManage = {}

function UiManage:disableCoreGuiExceptHealth()
    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, true)
end

return UiManage
