local RunService = game:GetService("RunService")

local Signal = require(script.Signal)

local VELOCITY_THRESHOLD = 0.001
local POSITION_THRESHOLD = 0.001
local EPSILON = 0.0001

export type Springer = {
	value: number | Vector2 | Vector3,
	velocity: number | Vector2 | Vector3,
	target: number | Vector2 | Vector3,
	frequency: number,
	damping: number,
	springType: string,
	isActive: boolean,

	onComplete: Signal.Signal,
	onStep: Signal.Signal,

	SetTarget: (self: Springer, newTarget: number | Vector2 | Vector3, frequency: number?, damping: number?) -> Springer
}

--[=[
	@within Springer
	@type new -> Springer
]=]
type new = (initialValue: number | Vector2 | Vector3, frequency: number?, damping: number?, initialGoal: (number | Vector2 | Vector3)?) -> Springer

--[=[
	@class Springer

	Springer is a class that allows you to animate values using a spring physics model.
	The values you can animate are numbers, Vector2, and Vector3.
	You can set the target value, frequency, and damping to customize the spring.
	You can also listen to the `onStep` signal to get the current value of the spring.
	When the spring reaches the target value, the `onComplete` signal will be fired.
]=]
local Springer = {}

local function getMagnitude(value)
	if type(value) == "number" then
		return math.abs(value)
	elseif typeof(value) == "Vector3" or typeof(value) == "Vector2" then
		return value.Magnitude
	else
		error("Unsupported type")
	end
end

local function zeroValue(value)
	if type(value) == "number" then
		return 0
	elseif typeof(value) == "Vector3" then
		return Vector3.new(0, 0, 0)
	elseif typeof(value) == "Vector2" then
		return Vector2.new(0, 0)
	else
		error("Unsupported type")
	end
end

local function stepSpringer(self: Springer, deltaTime: number): Springer
	if not self.isActive then
		return self
	end

	local damping = self.damping
	local angularFreq = self.frequency * 2 * math.pi
	local target = self.target
	local currentVel = self.velocity

	local displacement = self.value - target
	local decay = math.exp(-damping * angularFreq * deltaTime)
	local newVal, newVel

	if damping == 1 then
		newVal = target + (displacement + (currentVel + angularFreq * displacement) * deltaTime) * decay
		newVel = (currentVel - angularFreq * (currentVel + angularFreq * displacement) * deltaTime) * decay
	elseif damping < 1 then
		local coeff = math.sqrt(1 - damping * damping)
		local dtAngCoeff = angularFreq * coeff * deltaTime
		local cosTerm = math.cos(dtAngCoeff)
		local sinTerm = math.sin(dtAngCoeff)

		local velocityScaling
		if coeff > EPSILON then
			velocityScaling = sinTerm / coeff
		else
			local scalar = deltaTime * angularFreq
			velocityScaling = scalar + ((((scalar * scalar) * (coeff * coeff) * (coeff * coeff)) / 20) - (coeff * coeff)) * (scalar * scalar * scalar) / 6
		end

		newVal = target + ((displacement * (cosTerm + damping * velocityScaling)) + (currentVel * velocityScaling / angularFreq)) * decay
		newVel = (currentVel * (cosTerm - damping * velocityScaling) - displacement * (velocityScaling * angularFreq)) * decay
	else
		local coeff = math.sqrt(damping * damping - 1)
		local root1 = -angularFreq * (damping - coeff)
		local root2 = -angularFreq * (damping + coeff)
		local exp1 = math.exp(root1 * deltaTime)
		local exp2 = math.exp(root2 * deltaTime)
		local A = (currentVel - displacement * root2) / (root1 - root2)
		local B = displacement - A
		
		newVal = target + A * exp1 + B * exp2
		newVel = A * root1 * exp1 + B * root2 * exp2
	end

	if getMagnitude(newVel) < VELOCITY_THRESHOLD and getMagnitude(newVal - target) < POSITION_THRESHOLD then
		self.value = target
		self.velocity = zeroValue(newVel)
		if self.isActive then
			self.onComplete:Fire()
			self.isActive = false
		end
		return self
	end

	self.value = newVal
	self.velocity = newVel
	return self
end

--[=[
	Springer:SetTarget(newTarget: number | Vector2 | Vector3, frequency: number?, damping: number?): Springer

		Sets the target value of the spring. The spring will start animating towards the target value.
		You can also set the frequency and damping of the spring.
		If the frequency and damping are not provided, the spring will use the default values of 1.

		@param newTarget number | Vector2 | Vector3 -- The target value of the spring.
		@param frequency number? -- The frequency of the spring.
		@param damping number? -- The damping of the spring.

		@return Springer -- The Springer instance.
]=]
function Springer.SetTarget(self: Springer, newTarget: number | Vector2 | Vector3, frequency: number?, damping: number?): Springer
	if self.springType ~= typeof(newTarget) then
		error(`Invalid target type. This spring accepts {self.springType} NOT {typeof(newTarget)}`)
	end

	self.target = newTarget
	self.isActive = true
	
	local runConnection
	local function update(deltaTime: number)
		if self.isActive == false then
			runConnection:Disconnect()
			return
		end
		
		stepSpringer(self, deltaTime)
		self.onStep:Fire(self.value)
	end
	
	if frequency then
		self.frequency = frequency
	end
	if damping then
		self.damping = damping
	end
	
	if RunService:IsClient() then
		runConnection = RunService.RenderStepped:Connect(function(deltaTime: number)
			update(deltaTime)
		end)
	else
		runConnection = RunService.Heartbeat:Connect(function(deltaTime: number)
			update(deltaTime)
		end)
	end

	return self
end

--[=[
	Springer.new(initialValue: number | Vector2 | Vector3, frequency: number?, damping: number?, initialGoal: (number | Vector2 | Vector3)?): Springer

		Creates a new Springer instance with the provided initial value, frequency, and damping.
		You can also set the initial goal of the spring.

		@param initialValue number | Vector2 | Vector3 -- The initial value of the spring.
		@param frequency number? -- The frequency of the spring.
		@param damping number? -- The damping of the spring.
		@param initialGoal number | Vector2 | Vector3? -- The initial goal of the spring.

		@return Springer -- The Springer instance.
]=]

local constructor = {}

function constructor.new(initialValue: number | Vector2 | Vector3, frequency: number?, damping: number?, initialGoal: (number | Vector2 | Vector3)?): Springer
	local springerInstance = setmetatable({
		value = initialValue or 0,
		velocity = zeroValue(initialValue or 0),
		target = initialValue or 0,
		frequency = frequency or 1,
		damping = damping or 1,
		springType = typeof(initialValue),
		isActive = false,
		onComplete = Signal.new(),
		onStep = Signal.new()
	}, {
		__index = Springer
	})
	
	if initialGoal then
		task.defer(function()
			if RunService:IsClient() then
				RunService.RenderStepped:Wait()
			else
				RunService.Heartbeat:Wait()
			end
			springerInstance:SetTarget(initialGoal)
		end)
	end
	
	return springerInstance
end

return constructor
