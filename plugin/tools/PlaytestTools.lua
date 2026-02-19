local PlaytestTools = {}

local outputBuffer: { { level: string, message: string, time: number } } = {}
local MAX_BUFFER = 200
local connection: RBXScriptConnection? = nil

local function startCapture()
	if connection then return end
	local logService = game:GetService("LogService")
	connection = logService.MessageOut:Connect(function(msg, msgType)
		local level = "print"
		if msgType == Enum.MessageType.MessageWarning then level = "warn"
		elseif msgType == Enum.MessageType.MessageError then level = "error"
		elseif msgType == Enum.MessageType.MessageInfo then level = "info"
		end
		table.insert(outputBuffer, { level = level, message = msg, time = os.clock() })
		if #outputBuffer > MAX_BUFFER then
			table.remove(outputBuffer, 1)
		end
	end)
end

local function stopCapture()
	if connection then
		connection:Disconnect()
		connection = nil
	end
end

function PlaytestTools.start_playtest(_args: {}): any
	local ok, err = pcall(function()
		game:GetService("TestService"):Run()
	end)
	if not ok then
		return { error = tostring(err) }
	end
	outputBuffer = {}
	startCapture()
	return { ok = true, status = "playtest_started" }
end

function PlaytestTools.stop_playtest(_args: {}): any
	stopCapture()
	local ok, err = pcall(function()
		game:GetService("TestService"):Stop()
	end)
	if not ok then
		return { ok = false, note = tostring(err) }
	end
	return { ok = true, status = "playtest_stopped" }
end

function PlaytestTools.get_playtest_output(args: { clear: boolean? }): any
	local copy = {}
	for _, entry in ipairs(outputBuffer) do
		table.insert(copy, entry)
	end
	if args.clear then
		outputBuffer = {}
	end
	return { output = copy, count = #copy }
end

return PlaytestTools
