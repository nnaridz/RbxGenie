local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local StudioTestService
pcall(function()
	StudioTestService = game:GetService("StudioTestService")
end)

local PlaytestTools = {}

local TEST_SCRIPT_NAME = "__RbxGenieTestRunner"

local function getStudioMode(): string
	if not RunService:IsRunning() then
		return "edit"
	end
	if RunService:IsServer() and not RunService:IsClient() then
		return "server"
	end
	return "play"
end

function PlaytestTools.start_play(_args: any): any
	if not StudioTestService then
		return { error = "StudioTestService not available" }
	end
	if RunService:IsRunning() then
		return { error = "Already running — stop first" }
	end
	task.spawn(function()
		StudioTestService:ExecutePlayModeAsync({})
	end)
	return { ok = true, mode = "play" }
end

function PlaytestTools.stop_play(_args: any): any
	if not RunService:IsRunning() then
		return { error = "Not running" }
	end
	pcall(function()
		local PluginGuiService = game:GetService("PluginGuiService")
		if PluginGuiService and (PluginGuiService :: any).StopAllPluginActivities then
			(PluginGuiService :: any):StopAllPluginActivities()
		end
	end)
	task.spawn(function()
		local ok, err = pcall(function()
			if StudioTestService then
				(StudioTestService :: any):Stop()
			end
		end)
		if not ok then
			warn("[RbxGenie] Stop error: " .. tostring(err))
		end
	end)
	return { ok = true, mode = "edit" }
end

function PlaytestTools.run_server(_args: any): any
	if not StudioTestService then
		return { error = "StudioTestService not available" }
	end
	if RunService:IsRunning() then
		return { error = "Already running — stop first" }
	end
	task.spawn(function()
		StudioTestService:ExecuteRunModeAsync({})
	end)
	return { ok = true, mode = "server" }
end

function PlaytestTools.get_studio_mode(_args: any): any
	return { ok = true, mode = getStudioMode() }
end

local function buildTestRunnerSource(userCode: string, timeout: number): string
	return [[
local LogService = game:GetService("LogService")
local RunService = game:GetService("RunService")
local StudioTestService = game:GetService("StudioTestService")

if not RunService:IsRunning() then return end

local logs = {}
local logConn = nil

local TYPE_MAP = {
	[Enum.MessageType.MessageOutput]  = "output",
	[Enum.MessageType.MessageInfo]    = "info",
	[Enum.MessageType.MessageWarning] = "warning",
	[Enum.MessageType.MessageError]   = "error",
}

logConn = LogService.MessageOut:Connect(function(message, msgType)
	if message:sub(1, 10) == "[RbxGenie]" then return end
	table.insert(logs, {
		level   = TYPE_MAP[msgType] or "output",
		message = message,
		ts      = os.clock(),
	})
end)

local t0 = os.clock()
local timedOut = false
local ok, result

task.spawn(function()
	wait(]] .. tostring(timeout) .. [[)
	timedOut = true
end)

ok, result = pcall(function()
]] .. userCode .. [[

end)

local duration = os.clock() - t0
task.wait(0.1)
if logConn then logConn:Disconnect() end

local errors = {}
for _, entry in ipairs(logs) do
	if entry.level == "error" or entry.level == "warning" then
		table.insert(errors, entry)
	end
end

StudioTestService:EndTest({
	success    = ok,
	value      = if ok then tostring(result) else nil,
	error      = if not ok then tostring(result) else nil,
	logs       = logs,
	errors     = errors,
	duration   = duration,
	isTimeout  = timedOut,
})
]]
end

local function removeTestScript()
	local s = ServerScriptService:FindFirstChild(TEST_SCRIPT_NAME)
	if s then s:Destroy() end
end

function PlaytestTools.run_script_in_play_mode(args: { code: string, timeout: number?, mode: string? }): any
	if not StudioTestService then
		return { error = "StudioTestService not available" }
	end
	if not args.code or args.code == "" then
		return { error = "No code provided" }
	end
	if RunService:IsRunning() then
		return { error = "Already running — stop first" }
	end

	removeTestScript()

	local timeout = args.timeout or 100
	local source = buildTestRunnerSource(args.code, timeout)
	local testScript = Instance.new("Script")
	testScript.Name = TEST_SCRIPT_NAME
	testScript.Source = source
	testScript.Parent = ServerScriptService

	local runMode = args.mode or "play"
	local done = false
	local playResult = nil
	local playOk = false

	local signal = Instance.new("BindableEvent")

	task.spawn(function()
		if runMode == "server" then
			playOk, playResult = pcall(function()
				return StudioTestService:ExecuteRunModeAsync({})
			end)
		else
			playOk, playResult = pcall(function()
				return StudioTestService:ExecutePlayModeAsync({})
			end)
		end
		if not done then
			done = true
			signal:Fire()
		end
	end)

	local watchdogFired = false
	task.delay(timeout + 5, function()
		if done then return end
		watchdogFired = true
		done = true
		pcall(function()
			if RunService:IsRunning() and StudioTestService then
				(StudioTestService :: any):Stop()
			end
		end)
		task.wait(1)
		signal:Fire()
	end)

	signal.Event:Wait()
	signal:Destroy()

	removeTestScript()

	if watchdogFired then
		return {
			success = false,
			error = "Timed out after " .. tostring(timeout) .. "s — force-stopped play mode",
			isTimeout = true,
			duration = timeout,
		}
	end

	if not playOk then
		return { error = "Failed to run: " .. tostring(playResult) }
	end

	local ok3, _ = pcall(function()
		return HttpService:JSONEncode(playResult)
	end)

	if ok3 then
		return playResult
	else
		return { ok = true, raw = tostring(playResult) }
	end
end

return PlaytestTools
