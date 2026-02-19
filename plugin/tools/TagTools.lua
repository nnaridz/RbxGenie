local CollectionService = game:GetService("CollectionService")
local PathResolver = require(script.Parent.Parent.PathResolver)

local TagTools = {}

function TagTools.get_tags(args: { path: string }): any
	local inst, err = PathResolver.resolve(args.path)
	if not inst then return { error = err } end
	return { tags = CollectionService:GetTags(inst) }
end

function TagTools.add_tag(args: { path: string, tag: string }): any
	local inst, err = PathResolver.resolve(args.path)
	if not inst then return { error = err } end
	CollectionService:AddTag(inst, args.tag)
	return { ok = true }
end

function TagTools.remove_tag(args: { path: string, tag: string }): any
	local inst, err = PathResolver.resolve(args.path)
	if not inst then return { error = err } end
	CollectionService:RemoveTag(inst, args.tag)
	return { ok = true }
end

function TagTools.get_tagged(args: { tag: string }): any
	local results = {}
	for _, inst in ipairs(CollectionService:GetTagged(args.tag)) do
		local parts = {}
		local cur: Instance? = inst
		while cur and cur ~= game do
			table.insert(parts, 1, cur.Name)
			cur = cur.Parent
		end
		table.insert(results, {
			path = table.concat(parts, "."),
			className = inst.ClassName,
		})
	end
	return { instances = results }
end

return TagTools
