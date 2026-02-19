local PathResolver = require(script.Parent.Parent.PathResolver)
local ValueSerializer = require(script.Parent.Parent.ValueSerializer)

local PropertyTools = {}

local function setOnInstance(inst: Instance, key: string, rawVal: any): (boolean, string?)
	local converted = ValueSerializer.fromJSON(rawVal)
	local ok, err = pcall(function()
		(inst :: any)[key] = converted
	end)
	return ok, if ok then nil else tostring(err)
end

function PropertyTools.set_property(args: { path: string, property: string, value: any }): any
	local inst, err = PathResolver.resolve(args.path)
	if not inst then return { error = err } end
	local ok, serr = setOnInstance(inst, args.property, args.value)
	if not ok then return { error = serr } end
	return { ok = true }
end

function PropertyTools.mass_set_property(args: { paths: { string }, property: string, value: any }): any
	local results = {}
	for _, path in ipairs(args.paths) do
		local inst, err = PathResolver.resolve(path)
		if not inst then
			table.insert(results, { path = path, ok = false, error = err })
		else
			local ok, serr = setOnInstance(inst, args.property, args.value)
			table.insert(results, { path = path, ok = ok, error = serr })
		end
	end
	return { results = results }
end

function PropertyTools.mass_get_property(args: { paths: { string }, property: string }): any
	local results = {}
	for _, path in ipairs(args.paths) do
		local inst, err = PathResolver.resolve(path)
		if not inst then
			table.insert(results, { path = path, error = err })
		else
			local ok, val = pcall(function() return (inst :: any)[args.property] end)
			if ok then
				table.insert(results, { path = path, value = ValueSerializer.toJSON(val) })
			else
				table.insert(results, { path = path, error = tostring(val) })
			end
		end
	end
	return { results = results }
end

function PropertyTools.set_calculated_property(args: { path: string, property: string, expression: string }): any
	local inst, err = PathResolver.resolve(args.path)
	if not inst then return { error = err } end

	local ok, currentVal = pcall(function() return (inst :: any)[args.property] end)
	if not ok then return { error = "Cannot read property: " .. args.property } end

	local fn, compErr = loadstring("local current = ...; return " .. args.expression)
	if not fn then return { error = "Expression error: " .. tostring(compErr) } end

	local evalOk, newVal = pcall(fn, currentVal)
	if not evalOk then return { error = "Evaluation error: " .. tostring(newVal) } end

	local setOk, setErr = pcall(function() (inst :: any)[args.property] = newVal end)
	if not setOk then return { error = tostring(setErr) } end

	return { ok = true, newValue = ValueSerializer.toJSON(newVal) }
end

function PropertyTools.set_relative_property(args: {
	path: string,
	property: string,
	delta: any,
}): any
	local inst, err = PathResolver.resolve(args.path)
	if not inst then return { error = err } end

	local ok, currentVal = pcall(function() return (inst :: any)[args.property] end)
	if not ok then return { error = "Cannot read property" } end

	local delta = ValueSerializer.fromJSON(args.delta)
	local newVal
	local dt = typeof(currentVal)

	if dt == "number" then
		newVal = currentVal + (delta :: number)
	elseif dt == "Vector3" then
		newVal = (currentVal :: Vector3) + (delta :: Vector3)
	elseif dt == "Vector2" then
		newVal = (currentVal :: Vector2) + (delta :: Vector2)
	elseif dt == "UDim2" then
		newVal = (currentVal :: UDim2) + (delta :: UDim2)
	elseif dt == "CFrame" then
		newVal = (currentVal :: CFrame) * (delta :: CFrame)
	else
		return { error = "set_relative_property not supported for type: " .. dt }
	end

	local setOk, setErr = pcall(function() (inst :: any)[args.property] = newVal end)
	if not setOk then return { error = tostring(setErr) } end

	return { ok = true, newValue = ValueSerializer.toJSON(newVal) }
end

return PropertyTools
