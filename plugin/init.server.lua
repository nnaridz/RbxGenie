--!strict
local Bridge = require(script.Bridge)
local UI = require(script.UI)

local HttpService = game:GetService("HttpService")
local RunService  = game:GetService("RunService")

local HEALTH_URL     = "http://127.0.0.1:7766/health"
local RETRY_INTERVAL = 3

local widgetInfo = DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Right,
	false, false, 280, 420, 200, 150
)

local widget = plugin:CreateDockWidgetPluginGui("RbxGenie", widgetInfo)
widget.Title = "RbxGenie"

local ui = UI.build(widget)

-- Toolbar
local toolbar  = plugin:CreateToolbar("RbxGenie")
local toggleBtn = toolbar:CreateButton("RbxGenie", "Toggle RbxGenie panel", "rbxassetid://14978048685")
toggleBtn.ClickableWhenViewportHidden = true

toggleBtn.Click:Connect(function()
	widget.Enabled = not widget.Enabled
	toggleBtn:SetActive(widget.Enabled)
end)

widget:GetPropertyChangedSignal("Enabled"):Connect(function()
	toggleBtn:SetActive(widget.Enabled)
end)

-- State
local isConnected  = false
local bridgeRunning = false
local isPaused     = false   -- true while Studio is in play mode

local function tryConnect(): boolean
	local ok, res = pcall(function()
		return HttpService:RequestAsync({ Url = HEALTH_URL, Method = "GET" })
	end)
	return ok and res ~= nil and (res :: any).Success
end

local function startBridge()
	if bridgeRunning then return end
	bridgeRunning = true

	Bridge.onCommandStart = function(tool: string, _args: any)
		ui.setActive(tool)
	end

	Bridge.onCommandEnd = function(tool: string, ok: boolean, elapsedMs: number)
		ui.setActive(nil)
		ui.addEntry(tool, ok, elapsedMs, false)
	end

	Bridge.onStatus = function(msg: string)
		ui.addEntry(msg, true, nil, true)
	end

	Bridge.startLoop()
end

-- ── Play mode detection ────────────────────────────────────────────────────────
-- RunService:IsRunning() is true during Play Solo or Run. Poll every 0.5s to
-- detect transitions without an explicit signal.
task.spawn(function()
	local wasRunning = false
	while true do
		local running = RunService:IsRunning()
		if running and not wasRunning then
			-- Entered play mode
			wasRunning = true
			isPaused = true
			ui.setActive(nil)
			ui.setStatus(false)
			ui.addEntry("⏸ Play mode — paused", true, nil, true)
		elseif not running and wasRunning then
			-- Exited play mode
			wasRunning = false
			isPaused = false
			ui.addEntry("▶ Play mode ended — resuming", true, nil, true)
			-- Don't force reconnect here; the main loop will pick it up next cycle
		end
		task.wait(0.5)
	end
end)

-- ── Main connection loop ───────────────────────────────────────────────────────
task.spawn(function()
	ui.setStatus(false)

	while true do
		-- Deep sleep: widget closed, not connected, not playing
		if not widget.Enabled and not isConnected and not isPaused then
			task.wait(RETRY_INTERVAL)
			continue
		end

		-- Pause while in play mode
		if isPaused then
			task.wait(RETRY_INTERVAL)
			continue
		end

		local connected = tryConnect()

		if connected and not isConnected then
			isConnected = true
			ui.setStatus(true)
			ui.addEntry("Connected ✓", true, nil, true)
			startBridge()
		elseif not connected and isConnected then
			isConnected = false
			bridgeRunning = false
			ui.setStatus(false)
			ui.setActive(nil)
			ui.addEntry("Connection lost", false, nil, true)
		end

		task.wait(RETRY_INTERVAL)
	end
end)

-- On widget open while disconnected: immediate check
widget:GetPropertyChangedSignal("Enabled"):Connect(function()
	if widget.Enabled and not isConnected and not isPaused then
		task.spawn(function()
			if tryConnect() then
				isConnected = true
				ui.setStatus(true)
				ui.addEntry("Connected ✓", true, nil, true)
				startBridge()
			end
		end)
	end
end)
