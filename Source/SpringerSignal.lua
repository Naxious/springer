export type Connection = {
	Disconnect: (self: Connection) -> (),
	connected: boolean,
	_handler: (...any) -> (),
	signal: SpringerSignal
}

export type SpringerSignal = {
	new: () -> SpringerSignal,
	Connect: (self: SpringerSignal, handler: (...any) -> ()) -> Connection,
	Fire: (self: SpringerSignal, ...any) -> (),
	Wait: (self: SpringerSignal) -> ...any,
	_connections: {Connection},
	_threads: {thread}
}

local Connection = {}
Connection.__index = Connection

function Connection.new(signal, handler)
	return setmetatable({
		signal = signal,
		connected = true,
		_handler = handler,
	}, Connection)
end

function Connection:Disconnect()
	if self.connected then
		self.connected = false

		for index, connection in self.signal._connections do
			if connection == self then
				table.remove(self.signal._connections, index)
				return
			end
		end
	end
end

--[=[
	@class SpringerSignal
	@server
	@client

	SpringerSignals are a way to create a connection between two parts of your code. They are similar to events, but with a few key differences. Signals are not tied to any specific event, and can be fired at any time. They can also be waited on, which allows you to pause the execution of your code until the signal is fired.

	```lua
	local Signal = require(path.to.Signal)
	local signal = Signal.new()

	local connection = signal:Connect(function(...)
		print("Signal fired with arguments:", ...)
	end)

	signal:Fire("Hello, world!")
	connection:Disconnect()
	```

	SpringerSignals are useful for creating a decoupled system, where different parts of your code can communicate without needing to know about each other. They are also useful for creating a system where you can pause the execution of your code until a certain condition is met.

	```lua
	local Signal = require(path.to.Signal)
	local signal = Signal.new()

	local function waitForSignal()
		return signal:Wait()
	end

	task.spawn(function()
		waitForSignal()
		print("Signal received!")
	end)

	task.delay(1)
	signal:Fire()
	```
]=]

local SpringerSignal = {}
SpringerSignal.__index = SpringerSignal

function SpringerSignal.new()
	return setmetatable({
		_connections = {},
		_threads = {},
	}, SpringerSignal)
end

function SpringerSignal:Fire(...)
	for _, connection in self._connections do
		connection._handler(...)
	end

	for _, thread in self._threads do
		coroutine.resume(thread, ...)
	end

	self._threads = {}
end

function SpringerSignal:Connect(handler)
	local connection = Connection.new(self, handler)
	table.insert(self._connections, connection)
	return connection
end

function SpringerSignal:Wait()
	table.insert(self._threads, coroutine.running())
	return coroutine.yield()
end

return SpringerSignal
