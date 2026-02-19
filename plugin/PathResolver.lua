-- Resolves a dot-separated path string to a Roblox Instance.
-- Supports root service names (e.g. "Workspace", "StarterGui", etc.)
local PathResolver = {}

local ROOTS: { [string]: Instance } = {
	Workspace       = game:GetService("Workspace"),
	Players         = game:GetService("Players"),
	Lighting        = game:GetService("Lighting"),
	ReplicatedStorage = game:GetService("ReplicatedStorage"),
	ReplicatedFirst = game:GetService("ReplicatedFirst"),
	ServerScriptService = game:GetService("ServerScriptService"),
	ServerStorage   = game:GetService("ServerStorage"),
	StarterGui      = game:GetService("StarterGui"),
	StarterPack     = game:GetService("StarterPack"),
	StarterPlayer   = game:GetService("StarterPlayer"),
	Teams           = game:GetService("Teams"),
	SoundService    = game:GetService("SoundService"),
	TextChatService = game:GetService("TextChatService"),
	UserInputService = game:GetService("UserInputService"),
	RunService      = game:GetService("RunService"),
	TweenService    = game:GetService("TweenService"),
	CollectionService = game:GetService("CollectionService"),
	HttpService     = game:GetService("HttpService"),
	CoreGui         = game:GetService("CoreGui"),
	Chat            = game:GetService("Chat"),
	LocalizationService = game:GetService("LocalizationService"),
}

function PathResolver.resolve(path: string): (Instance?, string?)
	if not path or path == "" then
		return nil, "Empty path"
	end

	local parts = path:split(".")
	local root = ROOTS[parts[1]]

	if not root then
		-- Try game:GetService fallback
		local ok, svc = pcall(function() return game:GetService(parts[1]) end)
		if ok and svc then
			root = svc
		else
			return nil, "Unknown root service: " .. parts[1]
		end
	end

	local current: Instance = root
	for i = 2, #parts do
		local child = current:FindFirstChild(parts[i])
		if not child then
			return nil, ("Path not found at segment [%d] '%s' in '%s'"):format(i, parts[i], path)
		end
		current = child
	end

	return current, nil
end

function PathResolver.resolvePath(instance: Instance): string
	local parts: { string } = {}
	local current: Instance? = instance
	while current and current ~= game do
		table.insert(parts, 1, current.Name)
		current = current.Parent
	end
	return table.concat(parts, ".")
end

return PathResolver
