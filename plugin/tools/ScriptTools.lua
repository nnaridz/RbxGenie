local PathResolver = require(script.Parent.Parent.PathResolver)

local ScriptTools = {}

local function getScriptSource(inst: Instance): (string?, string?)
	if inst:IsA("LuaSourceContainer") then
		local ok, src = pcall(function() return (inst :: Script).Source end)
		if ok then return src, nil end
		return nil, "Cannot read source (may require plugin permissions)"
	end
	return nil, inst.ClassName .. " is not a script"
end

function ScriptTools.get_script_source(args: { path: string }): any
	local inst, err = PathResolver.resolve(args.path)
	if not inst then return { error = err } end
	local src, serr = getScriptSource(inst)
	if not src then return { error = serr } end
	return { source = src, lineCount = select(2, src:gsub("\n", "")) + 1 }
end

function ScriptTools.set_script_source(args: { path: string, source: string }): any
	local inst, err = PathResolver.resolve(args.path)
	if not inst then return { error = err } end
	if not inst:IsA("LuaSourceContainer") then return { error = "Not a script" } end
	local ok, serr = pcall(function() (inst :: Script).Source = args.source end)
	if not ok then return { error = tostring(serr) } end
	return { ok = true }
end

function ScriptTools.edit_script_lines(args: { path: string, startLine: number, endLine: number, replacement: string }): any
	local inst, err = PathResolver.resolve(args.path)
	if not inst then return { error = err } end
	local src, serr = getScriptSource(inst)
	if not src then return { error = serr } end

	local lines = src:split("\n")
	local s = math.max(1, args.startLine)
	local e = math.min(#lines, args.endLine)

	local replLines = args.replacement:split("\n")
	local newLines = {}
	for i = 1, s - 1 do table.insert(newLines, lines[i]) end
	for _, l in ipairs(replLines) do table.insert(newLines, l) end
	for i = e + 1, #lines do table.insert(newLines, lines[i]) end

	local ok, setErr = pcall(function() (inst :: Script).Source = table.concat(newLines, "\n") end)
	if not ok then return { error = tostring(setErr) } end
	return { ok = true, lineCount = #newLines }
end

function ScriptTools.insert_script_lines(args: { path: string, afterLine: number, lines: string }): any
	local inst, err = PathResolver.resolve(args.path)
	if not inst then return { error = err } end
	local src, serr = getScriptSource(inst)
	if not src then return { error = serr } end

	local lines = src:split("\n")
	local insertLines = args.lines:split("\n")
	local pos = math.max(0, math.min(#lines, args.afterLine))

	for i, l in ipairs(insertLines) do
		table.insert(lines, pos + i, l)
	end

	local ok, setErr = pcall(function() (inst :: Script).Source = table.concat(lines, "\n") end)
	if not ok then return { error = tostring(setErr) } end
	return { ok = true, lineCount = #lines }
end

function ScriptTools.delete_script_lines(args: { path: string, startLine: number, endLine: number }): any
	local inst, err = PathResolver.resolve(args.path)
	if not inst then return { error = err } end
	local src, serr = getScriptSource(inst)
	if not src then return { error = serr } end

	local lines = src:split("\n")
	local s = math.max(1, args.startLine)
	local e = math.min(#lines, args.endLine)

	local newLines = {}
	for i = 1, s - 1 do table.insert(newLines, lines[i]) end
	for i = e + 1, #lines do table.insert(newLines, lines[i]) end

	local ok, setErr = pcall(function() (inst :: Script).Source = table.concat(newLines, "\n") end)
	if not ok then return { error = tostring(setErr) } end
	return { ok = true, lineCount = #newLines, deletedLines = e - s + 1 }
end

return ScriptTools
