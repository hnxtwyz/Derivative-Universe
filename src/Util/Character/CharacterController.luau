local CharacterController = {}
CharacterController.__index = CharacterController

function CharacterController.new(character: Model)
    local self = {}
    setmetatable(self, CharacterController)

    self._humanoid = character:FindFirstChild("Humanoid")
    self._humanoidRootPart = character:FindFirstChild("HumanoidRootPart")

    return self
end

-- ++++++++++++++++++++

function CharacterController:getWalkSpeed()
    return self._humanoid.WalkSpeed
end

function CharacterController:restrictMovement()
    self._humanoid.WalkSpeed = 0
end

function CharacterController:allowMovement(walkSpeed: number)
    self._humanoid.WalkSpeed = walkSpeed
end

-- ++++++++++++++++++++

function CharacterController:getJumpPower()
    return self._humanoid.JumpPower
end

function CharacterController:restrictJump()
    self._humanoid.JumpPower = 0
end

function CharacterController:allowJump(jumpPower: number)
    self._humanoid.JumpPower = jumpPower
end

-- ++++++++++++++++++++

return CharacterController
