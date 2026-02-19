local ExecuteTools = {}

local outputBuffer: { string } = {}
local MAX_BUFFER = 500

function ExecuteTools.execute_luau(args: { code: string }): any
	if not args.code or args.code == "" then
		return { error = "No code provided" }
	end

	local fn, compErr = loadstring(args.code)
	if not fn then
		return { error = "Compile error: " .. tostring(compErr) }
	end

	local ok, result = pcall(fn)
	if not ok then
		return { error = "Runtime error: " .. tostring(result) }
	end

	if result ~= nil then
		local HttpService = game:GetService("HttpService")
		local ok2, encoded = pcall(function() return HttpService:JSONEncode(result) end)
		return { ok = true, result = if ok2 then result else tostring(result) }
	end

	return { ok = true, result = nil }
end

function ExecuteTools.captureOutput(msg: string)
	table.insert(outputBuffer, msg)
	if #outputBuffer > MAX_BUFFER then
		table.remove(outputBuffer, 1)
	end
end

function ExecuteTools.clearOutput()
	outputBuffer = {}
end

function ExecuteTools.getOutput(): { string }
	return outputBuffer
end

return ExecuteTools
