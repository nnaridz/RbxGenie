local Selection = game:GetService("Selection")
local PathResolver = require(script.Parent.Parent.PathResolver)

local SelectionTools = {}

function SelectionTools.get_selection(_args: {}): any
	local items = {}
	for _, inst in ipairs(Selection:Get()) do
		local parts = {}
		local cur: Instance? = inst
		while cur and cur ~= game do
			table.insert(parts, 1, cur.Name)
			cur = cur.Parent
		end
		table.insert(items, {
			path = table.concat(parts, "."),
			className = inst.ClassName,
			name = inst.Name,
		})
	end
	return { selection = items, count = #items }
end

return SelectionTools
