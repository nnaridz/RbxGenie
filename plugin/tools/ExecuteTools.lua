local LogService = game:GetService("LogService")
local HttpService = game:GetService("HttpService")

local ExecuteTools = {}

local consoleBuffer: { { level: string, message: string, ts: number } } = {}
local MAX_CONSOLE_BUFFER = 500
local listenerStarted = false

local function startConsoleListener()
	if listenerStarted then return end
	listenerStarted = true

	local TYPE_MAP = {
		[Enum.MessageType.MessageOutput]  = "output",
		[Enum.MessageType.MessageInfo]    = "info",
		[Enum.MessageType.MessageWarning] = "warning",
		[Enum.MessageType.MessageError]   = "error",
	}

	LogService.MessageOut:Connect(function(message: string, msgType: Enum.MessageType)
		if message:sub(1, 10) == "[RbxGenie]" then return end
		table.insert(consoleBuffer, {
			level   = TYPE_MAP[msgType] or "output",
			message = message,
			ts      = os.clock(),
		})
		if #consoleBuffer > MAX_CONSOLE_BUFFER then
			table.remove(consoleBuffer, 1)
		end
	end)
end

startConsoleListener()

local function serializeValue(val: any): any
	local t = typeof(val)
	if t == "table" then
		local out = {}
		for k, v in val do
			local key = if type(k) == "string" then k else tostring(k)
			out[key] = serializeValue(v)
		end
		return out
	elseif t == "string" or t == "number" or t == "boolean" then
		return val
	elseif t == "nil" then
		return nil
	else
		return tostring(val)
	end
end

function ExecuteTools.execute_luau(args: { code: string }): any
	if not args.code or args.code == "" then
		return { error = "No code provided" }
	end

	local fn, compErr = loadstring(args.code)
	if not fn then
		return { error = "Compile error: " .. tostring(compErr) }
	end

	local captured: { string } = {}

	local env = getfenv(fn)
	local origPrint = print
	local origWarn = warn
	local origError = error

	env.print = function(...)
		origPrint(...)
		local parts = {}
		for i = 1, select("#", ...) do
			parts[i] = tostring(select(i, ...))
		end
		table.insert(captured, "[OUTPUT] " .. table.concat(parts, "\t"))
	end

	env.warn = function(...)
		origWarn(...)
		local parts = {}
		for i = 1, select("#", ...) do
			parts[i] = tostring(select(i, ...))
		end
		table.insert(captured, "[WARNING] " .. table.concat(parts, "\t"))
	end

	env.error = function(msg, level)
		table.insert(captured, "[ERROR] " .. tostring(msg))
		origError(msg, level)
	end

	setfenv(fn, env)

	local ok, result = pcall(fn)

	if not ok then
		return {
			error = "Runtime error: " .. tostring(result),
			output = captured,
		}
	end

	local serialized = nil
	if result ~= nil then
		serialized = serializeValue(result)
	end

	return {
		ok     = true,
		result = serialized,
		output = captured,
	}
end

function ExecuteTools.get_console_output(_args: any): any
	return {
		ok     = true,
		count  = #consoleBuffer,
		output = consoleBuffer,
	}
end

function ExecuteTools.clear_console_output(_args: any): any
	consoleBuffer = {}
	return { ok = true }
end

return ExecuteTools
