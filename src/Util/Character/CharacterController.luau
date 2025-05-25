local CharacterController = {}
CharacterController.__index = CharacterController

function CharacterController.new(character: Model)
    local self = {}
    setmetatable(self, CharacterController)

    self.humanoid = character:FindFirstChild("Humanoid")
    self.animator = self.humanoid:FindFirstChild("Animator")

    self.humanoidRootPart = character:FindFirstChild("HumanoidRootPart")

    return self
end

-- ++++++++++++++++++++

function CharacterController:restrictMovement()
    self.humanoid.WalkSpeed = 0
end

function CharacterController:allowMovement(walkSpeed: number)
    self.humanoid.WalkSpeed = walkSpeed
end

-- ++++++++++++++++++++

function CharacterController:restrictJump()
    self.humanoid.JumpPower = 0
end

function CharacterController:allowJump(jumpPower: number)
    self.humanoid.JumpPower = jumpPower
end

-- ++++++++++++++++++++

function CharacterController:cframeOffset(cframe: CFrame) : CFrame
    return self.humanoidRootPart.CFrame * cframe
end

-- ++++++++++++++++++++

return CharacterController
