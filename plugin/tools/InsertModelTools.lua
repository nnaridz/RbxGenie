local InsertService = game:GetService("InsertService")

local InsertModelTools = {}

local MAX_RAY_DEPTH = 2048
local MAX_FALLBACK_DIST = 20

local function getInsertPosition(): Vector3
	local camera = workspace.CurrentCamera
	local vp = camera.ViewportSize / 2
	local unitRay = camera:ViewportPointToRay(vp.X, vp.Y, 0)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {}

	local result = workspace:Raycast(unitRay.Origin, unitRay.Direction * MAX_RAY_DEPTH, params)
	if result then
		return result.Position
	end
	return camera.CFrame.Position + unitRay.Direction * MAX_FALLBACK_DIST
end

local function collapseObjects(objects: { Instance }): Instance?
	if #objects == 0 then return nil end
	if #objects == 1 then return objects[1] end

	local hasPhysical = false
	for _, obj in objects do
		if obj:IsA("PVInstance") then
			hasPhysical = true
			break
		end
	end

	local container
	if hasPhysical then
		container = Instance.new("Model")
	else
		container = Instance.new("Folder")
	end

	for _, obj in objects do
		obj.Parent = container
	end
	return container
end

local function toTitleCase(str: string): string
	local result = str:gsub("(%a)([%w_']*)", function(first, rest)
		return first:upper() .. rest:lower()
	end)
	return result:gsub("%s+", "")
end

function InsertModelTools.insert_model(args: { query: string, parent: string? }): any
	if not args.query or args.query == "" then
		return { error = "No query provided" }
	end

	local ok1, searchResult = pcall(function()
		return InsertService:GetFreeModels(args.query, 0)
	end)
	if not ok1 or not searchResult or not searchResult[1] then
		return { error = "Marketplace search failed: " .. tostring(searchResult) }
	end

	local results = searchResult[1].Results
	if not results or #results == 0 then
		return { error = "No models found for: " .. args.query }
	end

	local assetId = results[1].AssetId
	local ok2, objects = pcall(function()
		return game:GetObjects("rbxassetid://" .. assetId)
	end)
	if not ok2 or not objects or #objects == 0 then
		return { error = "Failed to load asset: " .. tostring(assetId) }
	end

	local instance = collapseObjects(objects)
	if not instance then
		return { error = "No loadable objects in asset" }
	end

	local name = toTitleCase(args.query)
	local i = 1
	local parent = workspace
	if args.parent then
		local PathResolver = require(script.Parent.Parent.PathResolver)
		local resolved = PathResolver.resolve(args.parent)
		if resolved then
			parent = resolved
		end
	end

	while parent:FindFirstChild(name) do
		name = toTitleCase(args.query) .. i
		i += 1
	end

	instance.Name = name
	instance.Parent = parent

	if instance:IsA("Model") then
		instance:PivotTo(CFrame.new(getInsertPosition()))
	elseif instance:IsA("BasePart") then
		instance.Position = getInsertPosition()
	end

	return {
		ok = true,
		name = instance.Name,
		className = instance.ClassName,
		assetId = assetId,
		path = instance:GetFullName(),
	}
end

return InsertModelTools
