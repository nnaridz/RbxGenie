local PathResolver = require(script.Parent.Parent.PathResolver)
local ValueSerializer = require(script.Parent.Parent.ValueSerializer)

local ObjectTools = {}

local function buildPath(inst: Instance): string
	local parts = {}
	local cur: Instance? = inst
	while cur and cur ~= game do
		table.insert(parts, 1, cur.Name)
		cur = cur.Parent
	end
	return table.concat(parts, ".")
end

local function applyProperties(inst: Instance, properties: { [string]: any }?)
	if not properties then return end
	for key, val in pairs(properties) do
		pcall(function()
			(inst :: any)[key] = ValueSerializer.fromJSON(val)
		end)
	end
end

local function applyAttributes(inst: Instance, attributes: { [string]: any }?)
	if not attributes then return end
	for key, val in pairs(attributes) do
		local dt = type(val) == "table" and val.type or nil
		if dt then
			inst:SetAttribute(key, ValueSerializer.fromJSON(val))
		else
			inst:SetAttribute(key, val)
		end
	end
end

local function applySource(inst: Instance, source: string?)
	if not source then return end
	if inst:IsA("LuaSourceContainer") then
		pcall(function() (inst :: Script).Source = source end)
	end
end

function ObjectTools.create_object(args: { path: string, className: string }): any
	local parent, err = PathResolver.resolve(args.path)
	if not parent then return { error = err } end

	local ok, inst = pcall(function() return Instance.new(args.className) end)
	if not ok then return { error = "Invalid className: " .. args.className } end

	inst.Parent = parent
	return { ok = true, path = buildPath(inst), name = inst.Name }
end

function ObjectTools.create_object_with_properties(args: {
	path: string,
	className: string,
	properties: { [string]: any }?,
	attributes: { [string]: any }?,
	source: string?,
}): any
	local parent, err = PathResolver.resolve(args.path)
	if not parent then return { error = err } end

	local ok, inst = pcall(function() return Instance.new(args.className) end)
	if not ok then return { error = "Invalid className: " .. args.className } end

	applyProperties(inst, args.properties)
	applyAttributes(inst, args.attributes)
	applySource(inst, args.source)
	inst.Parent = parent

	return { ok = true, path = buildPath(inst), name = inst.Name }
end

function ObjectTools.mass_create_objects(args: { items: { { path: string, className: string } } }): any
	local results = {}
	for _, item in ipairs(args.items) do
		local res = ObjectTools.create_object(item)
		table.insert(results, res)
	end
	return { results = results }
end

function ObjectTools.mass_create_objects_with_properties(args: {
	items: { { path: string, className: string, properties: any?, attributes: any?, source: string? } }
}): any
	local results = {}
	for _, item in ipairs(args.items) do
		local res = ObjectTools.create_object_with_properties(item)
		table.insert(results, res)
	end
	return { results = results }
end

function ObjectTools.delete_object(args: { path: string, force: boolean? }): any
	local inst, err = PathResolver.resolve(args.path)
	if not inst then return { error = err } end
	if inst == game or inst == workspace then
		return { error = "Cannot delete root or Workspace" }
	end
	inst:Destroy()
	return { ok = true }
end

local function cloneInstance(inst: Instance, newParent: Instance?, offset: Vector3?): Instance
	local clone = inst:Clone()
	if offset then
		local ok, pos = pcall(function() return (clone :: any).Position end)
		if ok and typeof(pos) == "Vector3" then
			pcall(function() (clone :: any).Position = pos + offset end)
		end
		local okCF, cf = pcall(function() return (clone :: any).CFrame end)
		if okCF and typeof(cf) == "CFrame" then
			pcall(function() (clone :: any).CFrame = cf + offset end)
		end
	end
	clone.Parent = newParent or inst.Parent
	return clone
end

function ObjectTools.smart_duplicate(args: {
	path: string,
	newParent: string?,
	newName: string?,
	offset: { number }?,
	properties: { [string]: any }?,
}): any
	local inst, err = PathResolver.resolve(args.path)
	if not inst then return { error = err } end

	local parent = inst.Parent
	if args.newParent then
		local p, perr = PathResolver.resolve(args.newParent)
		if not p then return { error = perr } end
		parent = p
	end

	local offset: Vector3? = nil
	if args.offset then
		offset = Vector3.new(args.offset[1], args.offset[2], args.offset[3])
	end

	local clone = cloneInstance(inst, parent, offset)
	if args.newName then clone.Name = args.newName end
	if args.properties then applyProperties(clone, args.properties) end

	return { ok = true, path = buildPath(clone), name = clone.Name }
end

function ObjectTools.mass_duplicate(args: {
	paths: { string },
	newParent: string?,
	offset: { number }?,
}): any
	local results = {}
	for _, path in ipairs(args.paths) do
		local res = ObjectTools.smart_duplicate({
			path = path,
			newParent = args.newParent,
			offset = args.offset,
		})
		res.sourcePath = path
		table.insert(results, res)
	end
	return { results = results }
end

return ObjectTools
