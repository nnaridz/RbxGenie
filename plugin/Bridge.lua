local HttpService = game:GetService("HttpService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Executor = require(script.Parent.Executor)

local DAEMON_URL = "http://127.0.0.1:7766"
local POLL_ENDPOINT = DAEMON_URL .. "/poll"
local RESULT_ENDPOINT = DAEMON_URL .. "/result"

local BACKOFF_INITIAL = 2
local BACKOFF_MAX = 30
local BACKOFF_FACTOR = 1.5

local READ_ONLY_TOOLS = {
	get_file_tree = true, search_files = true, get_place_info = true,
	get_services = true, search_objects = true, get_instance_properties = true,
	get_instance_children = true, search_by_property = true, get_class_info = true,
	get_project_structure = true, summarize_game = true,
	mass_get_property = true,
	get_script_source = true,
	get_attribute = true, get_attributes = true,
	get_tags = true, get_tagged = true,
	get_selection = true,
	get_console_output = true, get_studio_mode = true,
}

local Bridge = {}
Bridge.onStatus       = nil :: ((msg: string) -> ())?
Bridge.onCommandStart = nil :: ((tool: string, args: any) -> ())?
Bridge.onCommandEnd   = nil :: ((tool: string, ok: boolean, elapsedMs: number) -> ())?

local function log(msg: string)
	if Bridge.onStatus then Bridge.onStatus(msg) end
end

local function httpGet(url: string): (boolean, string)
	local ok, res = pcall(function()
		return HttpService:RequestAsync({
			Url = url,
			Method = "GET",
			Headers = { ["Content-Type"] = "application/json" },
		})
	end)
	if not ok then return false, tostring(res) end
	if not res.Success then return false, ("HTTP " .. res.StatusCode) end
	return true, res.Body
end

local function httpPost(url: string, body: string): (boolean, string)
	local ok, res = pcall(function()
		return HttpService:RequestAsync({
			Url = url,
			Method = "POST",
			Headers = { ["Content-Type"] = "application/json" },
			Body = body,
		})
	end)
	if not ok then return false, tostring(res) end
	if not res.Success then return false, ("HTTP " .. res.StatusCode) end
	return true, res.Body
end

local function postResult(id: string, result: any?, err: string?)
	local payload: { [string]: any } = { id = id }
	if err then
		payload.error = err
	else
		payload.result = result
	end
	local body = HttpService:JSONEncode(payload)
	local ok, postErr = httpPost(RESULT_ENDPOINT, body)
	if not ok then
		log("[Bridge] Failed to post result: " .. postErr)
	end
end

function Bridge.startLoop()
	local backoff = BACKOFF_INITIAL

	while true do
		local ok, body = httpGet(POLL_ENDPOINT)

		if not ok then
			log("[Bridge] Poll failed: " .. body .. " — retry in " .. math.round(backoff) .. "s")
			task.wait(backoff)
			backoff = math.min(backoff * BACKOFF_FACTOR + math.random() * 0.5, BACKOFF_MAX)
			continue
		end

		backoff = BACKOFF_INITIAL

		local decoded: { hasCommand: boolean, id: string?, tool: string?, args: any? }?
		decoded = HttpService:JSONDecode(body)

		if not decoded or not decoded.hasCommand then
			task.wait(0.05)
			continue
		end

		local id = decoded.id :: string
		local tool = decoded.tool :: string
		local args = decoded.args :: any

		log("[Bridge] Received: " .. tool .. " (" .. id:sub(1, 8) .. ")")
		if Bridge.onCommandStart then Bridge.onCommandStart(tool, args) end

		local recording = nil
		if not READ_ONLY_TOOLS[tool] then
			recording = ChangeHistoryService:TryBeginRecording("RbxGenie: " .. tool)
		end

		local t0 = os.clock()
		local result, err = Executor.dispatch(tool, args)
		local elapsedMs = math.round((os.clock() - t0) * 1000)

		if recording then
			ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
		end

		if Bridge.onCommandEnd then Bridge.onCommandEnd(tool, err == nil, elapsedMs) end

		if err then
			postResult(id, nil, err)
		else
			postResult(id, result, nil)
		end

		task.wait(0.1)
	end
end

return Bridge
