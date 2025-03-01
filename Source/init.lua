local RunService = game:GetService("RunService")

local SpringerSignal = require(script.SpringerSignal)

local VELOCITY_THRESHOLD = 0.001
local POSITION_THRESHOLD = 0.001
local EPSILON = 0.0001

--[=[
	@within Springer
	@interface Springer
	.value number | Vector2 | Vector3 -- The current value of the spring.
	.velocity number | Vector2 | Vector3 -- The current velocity of the spring.
	.target number | Vector2 | Vector3 -- The target value of the spring.
	.frequency number -- The frequency of the spring.
	.damping number -- The damping of the spring.
	.springType string -- The type of the spring value.
	.isActive boolean -- Whether the spring is active or not.

	.onComplete SpringerSignal -- The signal that fires when the spring reaches the target value.
	.onStep SpringerSignal -- The signal that fires every frame with the current value of the spring.
]=]

--[=[
	@within Springer
	@prop onComplete SpringerSignal -- The signal that fires when the spring reaches the target value.
	@tag Event -- This property is a signal that you can connect to with the `:Connect` method.

	Fired when the spring reaches the target value, and is no longer animating.

	```lua
	local springer = Springer.new(0, 5, .2)
	springer:SetTarget(1, 10, .8)
	springer.onComplete:Connect(function()
		print("Springer completed")
	end)
	```
]=]

--[=[
	@within Springer
	@prop onStep SpringerSignal -- The signal that fires every frame with the current value of the spring.
	@tag Event -- This property is a signal that you can connect to with the `:Connect` method.

	Fired every frame with the current value of the spring.
	(RenderStepped for client, Heartbeat for server) 

	```lua
	local springer = Springer.new(0, 5, .2)
	springer:SetTarget(1, 10, .8)
	springer.onStep:Connect(function(value)
		print(value)
	end)
	```
]=]

export type Springer = {
	value: number | Vector2 | Vector3,
	velocity: number | Vector2 | Vector3,
	target: number | Vector2 | Vector3,
	frequency: number,
	damping: number,
	springType: string,
	isActive: boolean,

	onComplete: SpringerSignal.SpringerSignal,
	onStep: SpringerSignal.SpringerSignal,

	SetTarget: (self: Springer, newTarget: number | Vector2 | Vector3, frequency: number?, damping: number?) -> Springer
}

--[=[
	@class Springer

	- Wally Package: [Springer](https://wally.run/package/naxious/springer)

	Springer is a class that allows you to animate values using a spring physics model.
	The values you can animate are numbers, Vector2, and Vector3.
	You can set the target value, frequency, and damping to customize the spring.
	You can also listen to the `onStep` SpringerSignal to get the current value of the spring.
	When the spring reaches the target value, the `onComplete` SpringerSignal will be fired.

	Here is an example of how to use the Springer class to animate a number from 0 to 1 in 1 second:
	```lua
	local springer = Springer.new(0, 5, .2)
	springer:SetTarget(1, 10, .8)
	springer.onStep:Connect(function(value)
		print(value)
	end)
	springer.onComplete:Connect(function()
		print("Springer completed")
	end)
	```

	You can access all of the properties directly from the Springer instance.
	It is recommended to use the `SetTarget` method to animate the spring.
	Setting the properties directly will not animate the spring.
	Here is the Springer Class:
	```lua
	export type Springer = {
		value: number | Vector2 | Vector3,
		velocity: number | Vector2 | Vector3,
		target: number | Vector2 | Vector3,
		frequency: number,
		damping: number,
		springType: string,
		isActive: boolean,

		onComplete: SpringerSignal.SpringerSignal,
		onStep: SpringerSignal.SpringerSignal,

		SetTarget: (self: Springer, newTarget: number | Vector2 | Vector3, frequency: number?, damping: number?) -> Springer
	}	
	```

	:::note
		When you call the `SetTarget` method, the spring will start animating towards the target value.
		If you set any of the properties directly, the spring animation will override them.
		Setting isActive to false will stop the spring animation.(It will then not call the onComplete signal)
		Setting isActive to true will NOT start the spring animation. You need to call the SetTarget method to start the animation.
	:::
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

	Here is an example of how to use the SetTarget method to bounce between two values every 3 seconds:
	```lua
	local springer = Springer.new(0, 4, .3)
	local switch = true
	while true do
		task.wait(3)
		if switch then
			springer:SetTarget(1, 6, .5)
		else
			springer:SetTarget(0, 2, .2)
		end
		switch = not switch
	end
	```

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

local constructor = {}
--[=[
	@within Springer
	@return Springer -- The Springer instance.
	constructs a new Springer instance.

	:::note
		The .new method is a constructor and should be called with a colon from the Springer ModuleScript.
		Springer instances themselves, will not contain the .new method.
	:::
]=]
function constructor.new(initialValue: number | Vector2 | Vector3, frequency: number?, damping: number?, initialGoal: (number | Vector2 | Vector3)?): Springer
	local springerInstance = setmetatable({
		value = initialValue or 0,
		velocity = zeroValue(initialValue or 0),
		target = initialValue or 0,
		frequency = frequency or 1,
		damping = damping or 1,
		springType = typeof(initialValue),
		isActive = false,
		onComplete = SpringerSignal.new(),
		onStep = SpringerSignal.new()
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
