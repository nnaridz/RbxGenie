--!strict
local Bridge = require(script.Bridge)
local UI = require(script.UI)

local HttpService = game:GetService("HttpService")
local HEALTH_URL = "http://127.0.0.1:7766/health"
local RETRY_INTERVAL = 3

local widgetInfo = DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Right,
	false, false, 280, 420, 200, 150
)

local widget = plugin:CreateDockWidgetPluginGui("RbxGenie", widgetInfo)
widget.Title = "RbxGenie"

local ui = UI.build(widget)

-- Toolbar
local toolbar = plugin:CreateToolbar("RbxGenie")
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
local isConnected = false
local bridgeRunning = false

local function tryConnect(): boolean
	local ok, res = pcall(function()
		return HttpService:RequestAsync({ Url = HEALTH_URL, Method = "GET" })
	end)
	return ok and res ~= nil and (res :: any).Success
end

local function startBridge()
	if bridgeRunning then return end
	bridgeRunning = true

	-- Wire UI callbacks onto Bridge
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

-- Infinite connection loop
task.spawn(function()
	ui.setStatus(false)

	while true do
		if not widget.Enabled and not isConnected then
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
	if widget.Enabled and not isConnected then
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
