local UI = {}

-- ── Theme ─────────────────────────────────────────────────────────────────────
local C = {
	bg        = Color3.fromRGB(18,  18,  21),
	panel     = Color3.fromRGB(25,  26,  31),
	active    = Color3.fromRGB(21,  22,  27),
	accent    = Color3.fromRGB(20,  70,  255),
	text      = Color3.fromRGB(203, 203, 203),
	subtext   = Color3.fromRGB(100, 101, 112),
	separator = Color3.fromRGB(33,  34,  41),
	green     = Color3.fromRGB(52,  215, 133),
	red       = Color3.fromRGB(255, 80,  80),
	amber     = Color3.fromRGB(255, 180, 50),
	badge     = Color3.fromRGB(30,  31,  40),
}

local MAX_ENTRIES = 100

-- ── Rich text helpers ─────────────────────────────────────────────────────────
local function hex(c: Color3): string
	return ("#%02x%02x%02x"):format(
		math.round(c.R * 255), math.round(c.G * 255), math.round(c.B * 255)
	)
end

local function fc(text: string, c: Color3): string
	return ('<font color="%s">%s</font>'):format(hex(c), text)
end

local function bold(text: string): string
	return "<b>" .. text .. "</b>"
end

-- ── Layout helpers ────────────────────────────────────────────────────────────
local function corner(parent: GuiObject, r: number)
	local c2 = Instance.new("UICorner")
	c2.CornerRadius = UDim.new(0, r)
	c2.Parent = parent
end

local function pad(parent: GuiObject, t: number, r: number, b: number, l: number)
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0, t); p.PaddingRight = UDim.new(0, r)
	p.PaddingBottom = UDim.new(0, b); p.PaddingLeft = UDim.new(0, l)
	p.Parent = parent
end

local function frame(parent: GuiObject, size: UDim2, pos: UDim2, color: Color3, r: number?): Frame
	local f = Instance.new("Frame")
	f.Size = size; f.Position = pos
	f.BackgroundColor3 = color; f.BorderSizePixel = 0
	if r then corner(f, r) end
	f.Parent = parent
	return f
end

local function label(
	parent: GuiObject, text: string,
	size: UDim2, pos: UDim2,
	color: Color3, sz: number,
	font: Enum.Font?, xa: Enum.TextXAlignment?, ya: Enum.TextYAlignment?
): TextLabel
	local l2 = Instance.new("TextLabel")
	l2.Size = size; l2.Position = pos
	l2.BackgroundTransparency = 1
	l2.Text = text; l2.TextColor3 = color
	l2.Font = font or Enum.Font.Gotham; l2.TextSize = sz
	l2.TextXAlignment = xa or Enum.TextXAlignment.Left
	l2.TextYAlignment = ya or Enum.TextYAlignment.Center
	l2.RichText = true
	l2.Parent = parent
	return l2
end

local function hsep(parent: GuiObject, y: number)
	local s = Instance.new("Frame")
	s.Size = UDim2.new(1, 0, 0, 1)
	s.Position = UDim2.new(0, 0, 0, y)
	s.BackgroundColor3 = C.separator; s.BorderSizePixel = 0
	s.Parent = parent
end

-- ── Build ─────────────────────────────────────────────────────────────────────
function UI.build(widget: DockWidgetPluginGui): {
	setStatus: (connected: boolean) -> (),
	setActive: (tool: string?, detail: string?) -> (),
	addEntry: (tool: string, ok: boolean, elapsed: number?, isSystem: boolean?) -> (),
	clearLog: () -> (),
	setConnectButton: (running: boolean) -> (),
	onConnectToggle: ((running: boolean) -> ())?,
}
	local root = frame(widget :: any, UDim2.fromScale(1,1), UDim2.fromOffset(0,0), C.bg)

	local _api: any = {}

	-- ── 1. STATUS STRIP (28px) ─────────────────────────────────────────────────
	local strip = frame(root, UDim2.new(1,0,0,28), UDim2.fromOffset(0,0), C.panel)
	pad(strip, 0, 10, 0, 10)

	-- Left: dot + status text
	local statusDot = Instance.new("Frame")
	statusDot.Size = UDim2.fromOffset(7, 7)
	statusDot.Position = UDim2.new(0, 0, 0.5, -3)
	statusDot.BackgroundColor3 = C.subtext
	statusDot.BorderSizePixel = 0
	statusDot.Parent = strip
	corner(statusDot, 4)

	local statusTxt = label(strip, "Disconnected", UDim2.new(0,90,1,0), UDim2.new(0,14,0,0),
		C.subtext, 11, Enum.Font.GothamMedium)

	-- Right: connect toggle button
	local connectBtnRunning = false
	local connectBtn = Instance.new("TextButton")
	connectBtn.Size = UDim2.new(0, 44, 0, 18)
	connectBtn.Position = UDim2.new(1, -44, 0.5, -9)
	connectBtn.BackgroundColor3 = C.accent
	connectBtn.BorderSizePixel = 0
	connectBtn.Text = "Start"
	connectBtn.TextColor3 = Color3.new(1,1,1)
	connectBtn.Font = Enum.Font.GothamBold
	connectBtn.TextSize = 10
	connectBtn.Parent = strip
	corner(connectBtn, 4)

	connectBtn.MouseButton1Click:Connect(function()
		connectBtnRunning = not connectBtnRunning
		if _api.onConnectToggle then
			_api.onConnectToggle(connectBtnRunning)
		end
	end)

	-- Separator
	hsep(strip, 27)

	-- Accent strip line (left edge, shows when connected)
	local accentLine = frame(root, UDim2.new(0,2,0,28), UDim2.fromOffset(0,0), C.separator)

	-- ── 2. ACTIVE OP PANEL (52px) ──────────────────────────────────────────────
	local activePanel = frame(root, UDim2.new(1,0,0,52), UDim2.new(0,0,0,28), C.active)
	pad(activePanel, 8, 12, 8, 12)

	local activeTool = label(activePanel, "─  Idle", UDim2.new(1,0,0,18), UDim2.fromOffset(0,0),
		C.subtext, 13, Enum.Font.GothamBold)
	activeTool.TextTruncate = Enum.TextTruncate.AtEnd

	local activeDetail = label(activePanel, "", UDim2.new(1,0,0,14), UDim2.new(0,0,0,22),
		C.subtext, 11, Enum.Font.Code)
	activeDetail.TextTruncate = Enum.TextTruncate.AtEnd

	hsep(activePanel, 51)

	-- ── 3. SECTION HEADER (22px) ───────────────────────────────────────────────
	local sectionRow = frame(root, UDim2.new(1,0,0,22), UDim2.new(0,0,0,80), C.bg)
	pad(sectionRow, 0, 10, 0, 10)

	label(sectionRow, "ACTIVITY", UDim2.new(0,80,1,0), UDim2.fromOffset(0,0),
		C.subtext, 9, Enum.Font.GothamBold)

	local counterTxt = label(sectionRow, "0 ops", UDim2.new(1, -58, 1, 0), UDim2.fromOffset(0, 0),
		C.subtext, 9, Enum.Font.Gotham, Enum.TextXAlignment.Right)

	-- Clear button
	local clearBtn = Instance.new("TextButton")
	clearBtn.Size = UDim2.new(0, 44, 1, -4)
	clearBtn.Position = UDim2.new(1, -54, 0, 2)
	clearBtn.BackgroundColor3 = C.badge
	clearBtn.BorderSizePixel = 0
	clearBtn.Text = "Clear"
	clearBtn.TextColor3 = C.subtext
	clearBtn.Font = Enum.Font.Gotham
	clearBtn.TextSize = 9
	clearBtn.Parent = sectionRow
	corner(clearBtn, 4)

	-- ── 4. FEED ────────────────────────────────────────────────────────────────
	local feedOuter = frame(root,
		UDim2.new(1, -16, 1, -112),
		UDim2.new(0, 8, 0, 103),
		C.panel, 4
	)

	local feed = Instance.new("ScrollingFrame")
	feed.Size = UDim2.fromScale(1,1)
	feed.BackgroundTransparency = 1
	feed.BorderSizePixel = 0
	feed.ScrollBarThickness = 3
	feed.ScrollBarImageColor3 = C.accent
	feed.CanvasSize = UDim2.fromScale(1, 0)
	feed.AutomaticCanvasSize = Enum.AutomaticSize.Y
	feed.Parent = feedOuter
	pad(feed, 4, 6, 4, 6)

	local feedLayout = Instance.new("UIListLayout")
	feedLayout.SortOrder = Enum.SortOrder.LayoutOrder
	feedLayout.Padding = UDim.new(0, 0)
	feedLayout.Parent = feed

	local entries: { TextLabel } = {}
	local entryOrder = 0
	local opCount = 0

	local function scrollToTop()
		task.defer(function()
			feed.CanvasPosition = Vector2.new(0, 0)
		end)
	end

	local function addEntryRow(richText: string)
		entryOrder -= 1
		local row = Instance.new("TextLabel")
		row.Size = UDim2.new(1, -4, 0, 18)
		row.BackgroundTransparency = 1
		row.Text = richText
		row.Font = Enum.Font.Code
		row.TextSize = 11
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextYAlignment = Enum.TextYAlignment.Center
		row.TextTruncate = Enum.TextTruncate.AtEnd
		row.RichText = true
		row.LayoutOrder = entryOrder
		row.Parent = feed

		table.insert(entries, row)
		if #entries > MAX_ENTRIES then
			entries[#entries]:Destroy()
			table.remove(entries, #entries)
		end
		scrollToTop()
		return row
	end

	-- Clear button wiring
	clearBtn.MouseButton1Click:Connect(function()
		for _, e in ipairs(entries) do e:Destroy() end
		entries = {}
		entryOrder = 0
		opCount = 0
		counterTxt.Text = "0 ops"
	end)

	-- ── Bottom stat bar (18px) ─────────────────────────────────────────────────
	local statBar = frame(root, UDim2.new(1,0,0,18), UDim2.new(0,0,1,-18), C.panel)
	hsep(statBar, 0)
	pad(statBar, 0, 10, 0, 10)

	local statTxt = label(statBar, "○  Waiting for daemon", UDim2.new(1,0,1,0), UDim2.fromOffset(0,0),
		C.subtext, 10, Enum.Font.Code)

	-- ── API ────────────────────────────────────────────────────────────────────
	_api.setStatus = function(connected: boolean)
		statusDot.BackgroundColor3 = if connected then C.green    else C.subtext
		statusTxt.Text            = if connected then "Online"    else "Disconnected"
		statusTxt.TextColor3      = if connected then C.green     else C.subtext
		accentLine.BackgroundColor3 = if connected then C.accent  else C.separator
		statTxt.Text = if connected
			then "◉  http://127.0.0.1:7766"
			else "○  Disconnected"
		statTxt.TextColor3 = if connected then C.green else C.subtext
	end

	_api.setActive = function(tool: string?, detail: string?)
		if tool then
			activeTool.Text       = fc("⚡", C.accent) .. "  " .. bold(tool)
			activeTool.TextColor3 = C.text
			activeDetail.Text     = if detail then fc("→  ", C.subtext) .. detail else ""
		else
			activeTool.Text       = fc("─", C.subtext) .. "  Idle"
			activeTool.TextColor3 = C.subtext
			activeDetail.Text     = ""
		end
	end

	_api.addEntry = function(tool: string, ok: boolean, elapsed: number?, isSystem: boolean?)
		local icon: string
		local nameColor: Color3
		local right: string

		if isSystem then
			icon = fc("─", C.subtext)
			nameColor = C.subtext
			right = ""
		elseif ok then
			icon = fc("✓", C.green)
			nameColor = C.text
			right = if elapsed
				then fc(tostring(math.round(elapsed)) .. "ms", C.subtext)
				else ""
			opCount += 1
		else
			icon = fc("✗", C.red)
			nameColor = C.red
			right = fc("Error", C.red)
			opCount += 1
		end

		local ts = fc(os.date("%H:%M") :: string, C.subtext)
		local namePart = ('<font color="%s">%s</font>'):format(hex(nameColor), tool)
		addEntryRow(ts .. "  " .. icon .. "  " .. namePart .. "  " .. right)
		counterTxt.Text = opCount .. " ops"
	end

	_api.clearLog = function()
		for _, e in ipairs(entries) do e:Destroy() end
		entries = {}
		entryOrder = 0
		opCount = 0
		counterTxt.Text = "0 ops"
	end

	_api.setConnectButton = function(running: boolean)
		connectBtnRunning = running
		connectBtn.Text = if running then "Stop" else "Start"
		connectBtn.BackgroundColor3 = if running then C.red else C.accent
	end

	_api.onConnectToggle = nil :: ((running: boolean) -> ())?

	return _api
end

return UI
