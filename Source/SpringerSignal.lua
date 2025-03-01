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
