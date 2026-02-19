local PathResolver = require(script.Parent.Parent.PathResolver)
local ValueSerializer = require(script.Parent.Parent.ValueSerializer)

local InstanceTools = {}

local function instanceToTable(inst: Instance, depth: number, maxDepth: number): { [string]: any }
	local t: { [string]: any } = {
		name = inst.Name,
		className = inst.ClassName,
		childCount = #inst:GetChildren(),
	}
	if depth < maxDepth then
		local children = {}
		for _, child in ipairs(inst:GetChildren()) do
			table.insert(children, instanceToTable(child, depth + 1, maxDepth))
		end
		t.children = children
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
	local info: { [string]: any } = {
		placeId = game.PlaceId,
		gameId = game.GameId,
		placeName = game.Name,
		placeVersion = game.PlaceVersion,
		creatorId = game.CreatorId,
		creatorType = tostring(game.CreatorType),
	}
	return info
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

function InstanceTools.get_file_tree(args: { path: string?, depth: number? }): any
	local root: Instance = game
	if args.path and args.path ~= "" then
		local inst, err = PathResolver.resolve(args.path)
		if not inst then return { error = err } end
		root = inst
	end
	local maxDepth = args.depth or 3
	return instanceToTable(root, 0, maxDepth)
end

function InstanceTools.get_project_structure(args: { depth: number? }): any
	return InstanceTools.get_file_tree({ path = nil, depth = args.depth or 2 })
end

function InstanceTools.search_files(args: { query: string, path: string? }): any
	local root: Instance = game
	if args.path and args.path ~= "" then
		local inst, err = PathResolver.resolve(args.path)
		if not inst then return { error = err } end
		root = inst
	end

	local query = args.query:lower()
	local results = {}

	local function scan(inst: Instance)
		if inst.Name:lower():find(query, 1, true) then
			table.insert(results, {
				path = buildPath(inst),
				name = inst.Name,
				className = inst.ClassName,
			})
		end
		for _, child in ipairs(inst:GetChildren()) do
			scan(child)
		end
	end

	scan(root)
	return { results = results, count = #results }
end

function InstanceTools.search_objects(args: { query: string, className: string?, path: string? }): any
	local root: Instance = game
	if args.path and args.path ~= "" then
		local inst, err = PathResolver.resolve(args.path)
		if not inst then return { error = err } end
		root = inst
	end

	local query = args.query and args.query:lower() or nil
	local className = args.className
	local results = {}

	local function scan(inst: Instance)
		local nameMatch = not query or inst.Name:lower():find(query, 1, true)
		local classMatch = not className or inst.ClassName == className
		if nameMatch and classMatch then
			table.insert(results, {
				path = buildPath(inst),
				name = inst.Name,
				className = inst.ClassName,
			})
		end
		for _, child in ipairs(inst:GetChildren()) do
			scan(child)
		end
	end

	scan(root)
	return { results = results, count = #results }
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

function InstanceTools.get_instance_children(args: { path: string, recursive: boolean? }): any
	local inst, err = PathResolver.resolve(args.path)
	if not inst then return { error = err } end

	if args.recursive then
		local results = {}
		local function scan(i: Instance)
			for _, child in ipairs(i:GetChildren()) do
				table.insert(results, {
					path = buildPath(child),
					name = child.Name,
					className = child.ClassName,
					childCount = #child:GetChildren(),
				})
				scan(child)
			end
		end
		scan(inst)
		return { children = results, count = #results }
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
}): any
	local root: Instance = game
	if args.path and args.path ~= "" then
		local inst, err = PathResolver.resolve(args.path)
		if not inst then return { error = err } end
		root = inst
	end

	local targetVal = ValueSerializer.fromJSON(args.value)
	local results = {}

	local function scan(inst: Instance)
		if not args.className or inst.ClassName == args.className then
			local ok, val = pcall(function() return (inst :: any)[args.property] end)
			if ok and val == targetVal then
				table.insert(results, {
					path = buildPath(inst),
					name = inst.Name,
					className = inst.ClassName,
				})
			end
		end
		for _, child in ipairs(inst:GetChildren()) do
			scan(child)
		end
	end

	scan(root)
	return { results = results, count = #results }
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

return InstanceTools
