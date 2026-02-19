local HttpService = game:GetService("HttpService")
local Executor = require(script.Parent.Executor)

local DAEMON_URL = "http://127.0.0.1:7766"
local POLL_ENDPOINT = DAEMON_URL .. "/poll"
local RESULT_ENDPOINT = DAEMON_URL .. "/result"

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
	while true do
		local ok, body = httpGet(POLL_ENDPOINT)

		if not ok then
			log("[Bridge] Poll failed: " .. body .. " — retrying in 2s")
			task.wait(2)
			continue
		end

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

		local t0 = os.clock()
		local result, err = Executor.dispatch(tool, args)
		local elapsedMs = math.round((os.clock() - t0) * 1000)

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
