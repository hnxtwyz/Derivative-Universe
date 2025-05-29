local TweenService = game:GetService("TweenService")

local CharacterController = {}
CharacterController.__index = CharacterController

function CharacterController.new(character: Model)
    local self = {}
    setmetatable(self, CharacterController)

    self.humanoid = character:FindFirstChild("Humanoid")

    self._animator = self.humanoid:FindFirstChild("Animator")
    self._animationTracks = {}

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
    if cframe then
        return self.humanoidRootPart.CFrame * cframe
    else
        return self.humanoidRootPart.CFrame
    end
end

function CharacterController:moveTo(cframe: CFrame, duration: number)
    local tweenInfo = TweenInfo.new(
        duration,
        Enum.EasingStyle.Linear,
        Enum.EasingDirection.Out
    )
    local tween = TweenService:Create(self.humanoidRootPart, tweenInfo, {CFrame = cframe})
    tween:Play()
end

-- ++++++++++++++++++++

function CharacterController:loadAnimation(animationName: string, animationId: string)
    if self._animator then
        local animation = Instance.new("Animation")
        animation.AnimationId = animationId
        local animationTrack = self._animator:LoadAnimation(animation)
        animationTrack.Priority = Enum.AnimationPriority.Action
        self._animationTracks[animationName] = animationTrack
    end
end

function CharacterController:playAnimation(animationName: string, ...: any)
    if self._animationTracks[animationName] then
        self._animationTracks[animationName]:Play(...)
    end
end

function CharacterController:stopAnimation(animationName: string)
    if self._animationTracks[animationName] then
        self._animationTracks[animationName]:Stop()
    end
end

-- ++++++++++++++++++++

return CharacterController
