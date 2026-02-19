local PathResolver = require(script.Parent.Parent.PathResolver)
local ValueSerializer = require(script.Parent.Parent.ValueSerializer)

local InstanceTools = {}

local SCRIPT_CLASSES = { Script = true, LocalScript = true, ModuleScript = true }

local function instanceToTable(inst: Instance, depth: number, maxDepth: number, counter: { n: number }, maxNodes: number): { [string]: any }?
	if counter.n >= maxNodes then
		return nil
	end
	counter.n += 1
	local t: { [string]: any } = {
		name = inst.Name,
		className = inst.ClassName,
		childCount = #inst:GetChildren(),
	}
	if depth < maxDepth then
		local children = {}
		local truncated = false
		for _, child in ipairs(inst:GetChildren()) do
			if counter.n >= maxNodes then
				truncated = true
				break
			end
			local child_t = instanceToTable(child, depth + 1, maxDepth, counter, maxNodes)
			if child_t then
				table.insert(children, child_t)
			else
				truncated = true
				break
			end
		end
		t.children = children
		if truncated then
			t.truncated = true
		end
	end
	return t
end

local function buildPath(inst: Instance): string
	local parts = {}
	local cur: Instance? = inst
	while cur and cur ~= game do
		table.insert(parts, 1, cur.Name)
		cur = cur.Parent
	end
	return table.concat(parts, ".")
end

function InstanceTools.get_place_info(_args: {}): any
	return {
		placeId = game.PlaceId,
		gameId = game.GameId,
		placeName = game.Name,
		placeVersion = game.PlaceVersion,
		creatorId = game.CreatorId,
		creatorType = tostring(game.CreatorType),
	}
end

function InstanceTools.get_services(_args: {}): any
	local services = {}
	for _, child in ipairs(game:GetChildren()) do
		table.insert(services, {
			name = child.Name,
			className = child.ClassName,
			childCount = #child:GetChildren(),
		})
	end
	return { services = services }
end

function InstanceTools.get_file_tree(args: { path: string?, depth: number?, limit: number? }): any
	local root: Instance = game
	if args.path and args.path ~= "" then
		local inst, err = PathResolver.resolve(args.path)
		if not inst then return { error = err } end
		root = inst
	end
	local maxDepth = math.min(args.depth or 3, 3)
	local maxNodes = args.limit or 200
	local counter = { n = 0 }
	local result = instanceToTable(root, 0, maxDepth, counter, maxNodes)
	if result and counter.n >= maxNodes then
		result.truncated = true
		result.note = "Result capped at " .. maxNodes .. " nodes. Use a scoped path or lower depth to see more."
	end
	return result
end

function InstanceTools.get_project_structure(args: { depth: number? }): any
	return InstanceTools.get_file_tree({ path = nil, depth = args.depth or 2 })
end

function InstanceTools.search_files(args: { query: string, path: string?, limit: number? }): any
	local root: Instance = game
	if args.path and args.path ~= "" then
		local inst, err = PathResolver.resolve(args.path)
		if not inst then return { error = err } end
		root = inst
	end

	local query = args.query:lower()
	local limit = args.limit or 50
	local results = {}
	local truncated = false

	local function scan(inst: Instance)
		if truncated then return end
		if inst.Name:lower():find(query, 1, true) then
			table.insert(results, {
				path = buildPath(inst),
				name = inst.Name,
				className = inst.ClassName,
			})
			if #results >= limit then
				truncated = true
				return
			end
		end
		for _, child in ipairs(inst:GetChildren()) do
			scan(child)
		end
	end

	scan(root)
	return { results = results, count = #results, truncated = truncated }
end

function InstanceTools.search_objects(args: { query: string, className: string?, path: string?, limit: number? }): any
	local root: Instance = game
	if args.path and args.path ~= "" then
		local inst, err = PathResolver.resolve(args.path)
		if not inst then return { error = err } end
		root = inst
	end

	local query = args.query and args.query:lower() or nil
	local className = args.className
	local limit = args.limit or 50
	local results = {}
	local truncated = false

	local function scan(inst: Instance)
		if truncated then return end
		local nameMatch = not query or inst.Name:lower():find(query, 1, true)
		local classMatch = not className or inst.ClassName == className
		if nameMatch and classMatch then
			table.insert(results, {
				path = buildPath(inst),
				name = inst.Name,
				className = inst.ClassName,
			})
			if #results >= limit then
				truncated = true
				return
			end
		end
		for _, child in ipairs(inst:GetChildren()) do
			scan(child)
		end
	end

	scan(root)
	return { results = results, count = #results, truncated = truncated }
end

function InstanceTools.get_instance_properties(args: { path: string }): any
	local inst, err = PathResolver.resolve(args.path)
	if not inst then return { error = err } end

	local common = {
		"Name", "Parent", "ClassName", "Archivable",
		"Position", "Size", "CFrame", "Rotation", "Color", "BrickColor",
		"Material", "Transparency", "Anchored", "CanCollide",
		"BackgroundColor3", "TextColor3", "Text", "Font", "TextSize",
		"Visible", "ZIndex", "BorderSizePixel",
		"Source", "Disabled", "RunContext",
	}

	local props: { [string]: any } = {}
	for _, name in ipairs(common) do
		local ok, val = pcall(function() return (inst :: any)[name] end)
		if ok then
			props[name] = ValueSerializer.toJSON(val)
		end
	end

	return { path = args.path, className = inst.ClassName, properties = props }
end

function InstanceTools.get_instance_children(args: { path: string, recursive: boolean?, limit: number? }): any
	local inst, err = PathResolver.resolve(args.path)
	if not inst then return { error = err } end

	local limit = args.limit or 200

	if args.recursive then
		local results = {}
		local truncated = false
		local function scan(i: Instance)
			if truncated then return end
			for _, child in ipairs(i:GetChildren()) do
				table.insert(results, {
					path = buildPath(child),
					name = child.Name,
					className = child.ClassName,
					childCount = #child:GetChildren(),
				})
				if #results >= limit then
					truncated = true
					return
				end
				scan(child)
			end
		end
		scan(inst)
		return { children = results, count = #results, truncated = truncated }
	else
		local children = {}
		for _, child in ipairs(inst:GetChildren()) do
			table.insert(children, {
				path = buildPath(child),
				name = child.Name,
				className = child.ClassName,
				childCount = #child:GetChildren(),
			})
		end
		return { children = children, count = #children }
	end
end

function InstanceTools.search_by_property(args: {
	property: string,
	value: any,
	path: string?,
	className: string?,
	limit: number?,
}): any
	local root: Instance = game
	if args.path and args.path ~= "" then
		local inst, err = PathResolver.resolve(args.path)
		if not inst then return { error = err } end
		root = inst
	end

	local targetVal = ValueSerializer.fromJSON(args.value)
	local limit = args.limit or 50
	local results = {}
	local truncated = false

	local function scan(inst: Instance)
		if truncated then return end
		if not args.className or inst.ClassName == args.className then
			local ok, val = pcall(function() return (inst :: any)[args.property] end)
			if ok and val == targetVal then
				table.insert(results, {
					path = buildPath(inst),
					name = inst.Name,
					className = inst.ClassName,
				})
				if #results >= limit then
					truncated = true
					return
				end
			end
		end
		for _, child in ipairs(inst:GetChildren()) do
			scan(child)
		end
	end

	scan(root)
	return { results = results, count = #results, truncated = truncated }
end

function InstanceTools.get_class_info(args: { className: string }): any
	local ok, info = pcall(function()
		return (game :: any):GetService("StudioService"):GetClassProperties(args.className)
	end)
	if not ok then
		return { className = args.className, note = "StudioService API unavailable in this context" }
	end
	local props = {}
	for _, p in ipairs(info or {}) do
		table.insert(props, p)
	end
	return { className = args.className, properties = props }
end

local KNOWN_SERVICES = {
	Workspace = true,
	Players = true,
	Lighting = true,
	ReplicatedFirst = true,
	ReplicatedStorage = true,
	ServerScriptService = true,
	ServerStorage = true,
	StarterGui = true,
	StarterPack = true,
	StarterPlayer = true,
	Teams = true,
	SoundService = true,
	Chat = true,
	TextChatService = true,
	MaterialService = true,
	CollectionService = true,
	RunService = true,
	TweenService = true,
	UserInputService = true,
	ProximityPromptService = true,
	PathfindingService = true,
	PhysicsService = true,
	HttpService = true,
	DataStoreService = true,
	MessagingService = true,
	TeleportService = true,
	BadgeService = true,
	MarketplaceService = true,
	GroupService = true,
	LocalizationService = true,
	AnalyticsService = true,
	VoiceChatService = true,
	AvatarEditorService = true,
}

function InstanceTools.summarize_game(_args: {}): any
	local services = {}
	local totalScripts = 0
	local totalInstances = 0

	local function countAll(inst: Instance): (number, number)
		local instances = 0
		local scripts = 0
		for _, child in ipairs(inst:GetDescendants()) do
			instances += 1
			if SCRIPT_CLASSES[child.ClassName] then
				scripts += 1
			end
		end
		return instances, scripts
	end

	for _, svc in ipairs(game:GetChildren()) do
		local directChildren = #svc:GetChildren()
		if not KNOWN_SERVICES[svc.Name] and directChildren == 0 then
			continue
		end
		local inst_count, script_count = countAll(svc)
		totalScripts += script_count
		totalInstances += inst_count + 1
		table.insert(services, {
			name = svc.Name,
			className = svc.ClassName,
			directChildren = directChildren,
			totalDescendants = inst_count,
			scripts = script_count,
		})
	end

	return {
		placeName = game.Name,
		placeId = game.PlaceId,
		services = services,
		totalScripts = totalScripts,
		totalInstances = totalInstances,
		tip = "Use get_file_tree with a specific path and low depth to explore further.",
	}
end

return InstanceTools
