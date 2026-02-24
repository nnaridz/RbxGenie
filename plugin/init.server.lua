--!strict
local Bridge = require(script.Bridge)
local UI = require(script.UI)

local HttpService = game:GetService("HttpService")

local HEALTH_URL     = "http://127.0.0.1:7766/health"
local HEALTH_POLL    = 3

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
local isConnected   = false
local bridgeThread: thread? = nil
local userWantsConnect = false

local SETTING_KEY = "RbxGenieAutoConnect"

local function tryConnect(): boolean
	local ok, res = pcall(function()
		return HttpService:RequestAsync({ Url = HEALTH_URL, Method = "GET" })
	end)
	return ok and res ~= nil and (res :: any).Success
end

local function startBridge()
	if bridgeThread then return end

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

	bridgeThread = task.spawn(function()
		Bridge.startLoop()
	end)
end

local function stopBridge()
	if bridgeThread then
		task.cancel(bridgeThread)
		bridgeThread = nil
	end
	isConnected = false
	ui.setStatus(false)
	ui.setActive(nil)
end

local function connectionLoop()
	while userWantsConnect do
		local connected = tryConnect()

		if connected and not isConnected then
			isConnected = true
			ui.setStatus(true)
			ui.addEntry("Connected ✓", true, nil, true)
			startBridge()
		elseif not connected and isConnected then
			isConnected = false
			ui.setStatus(false)
			ui.setActive(nil)
			ui.addEntry("Connection lost", false, nil, true)
		end

		task.wait(HEALTH_POLL)
	end
end

local function setConnect(running: boolean)
	userWantsConnect = running
	ui.setConnectButton(running)
	pcall(function()
		plugin:SetSetting(SETTING_KEY, running)
	end)

	if running then
		ui.addEntry("Connecting...", true, nil, true)
		task.spawn(connectionLoop)
	else
		stopBridge()
		ui.addEntry("Stopped", true, nil, true)
	end
end

-- Wire up the Start/Stop button
ui.onConnectToggle = function(running: boolean)
	setConnect(running)
end

ui.setStatus(false)

-- Auto-reconnect if previously connected (survives play mode transitions)
task.defer(function()
	local saved = false
	pcall(function()
		saved = plugin:GetSetting(SETTING_KEY) == true
	end)
	if saved then
		setConnect(true)
	end
end)

