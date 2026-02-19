-- Converts between JSON-serializable property tables and Roblox data types.
local HttpService = game:GetService("HttpService")
local ValueSerializer = {}

type JsonValue = { type: string, value: { number } } | string | number | boolean

local function toEnum(str: string): EnumItem?
	local parts = str:split(".")
	if #parts < 3 then return nil end
	local enumType: any = Enum[parts[2]]
	if not enumType then return nil end
	return enumType[parts[3]]
end

function ValueSerializer.fromJSON(v: any): any
	if type(v) == "table" and v.type then
		local t = v.type
		local val = v.value

		if t == "Vector3" then
			return Vector3.new(val[1], val[2], val[3])
		elseif t == "Vector2" then
			return Vector2.new(val[1], val[2])
		elseif t == "Color3" then
			return Color3.new(val[1], val[2], val[3])
		elseif t == "CFrame" then
			return CFrame.new(
				val[1], val[2], val[3],
				val[4], val[5], val[6],
				val[7], val[8], val[9],
				val[10], val[11], val[12]
			)
		elseif t == "UDim2" then
			return UDim2.new(val[1], val[2], val[3], val[4])
		elseif t == "UDim" then
			return UDim.new(val[1], val[2])
		elseif t == "Enum" then
			return toEnum(tostring(val))
		elseif t == "BrickColor" then
			return BrickColor.new(tostring(val))
		elseif t == "NumberSequence" then
			local kps = {}
			for _, kp in ipairs(val) do
				table.insert(kps, NumberSequenceKeypoint.new(kp[1], kp[2], kp[3] or 0))
			end
			return NumberSequence.new(kps)
		elseif t == "ColorSequence" then
			local kps = {}
			for _, kp in ipairs(val) do
				table.insert(kps, ColorSequenceKeypoint.new(kp[1], Color3.new(kp[2], kp[3], kp[4])))
			end
			return ColorSequence.new(kps)
		elseif t == "NumberRange" then
			return NumberRange.new(val[1], val[2])
		elseif t == "Rect" then
			return Rect.new(val[1], val[2], val[3], val[4])
		end
	end
	return v
end

function ValueSerializer.toJSON(v: any): any
	local dt = typeof(v)

	if dt == "Vector3" then
		return { type = "Vector3", value = { v.X, v.Y, v.Z } }
	elseif dt == "Vector2" then
		return { type = "Vector2", value = { v.X, v.Y } }
	elseif dt == "Color3" then
		return { type = "Color3", value = { v.R, v.G, v.B } }
	elseif dt == "CFrame" then
		local c = v
		return { type = "CFrame", value = {
			c.X, c.Y, c.Z,
			c.RightVector.X, c.RightVector.Y, c.RightVector.Z,
			c.UpVector.X, c.UpVector.Y, c.UpVector.Z,
			c.LookVector.X, c.LookVector.Y, c.LookVector.Z,
		}}
	elseif dt == "UDim2" then
		return { type = "UDim2", value = { v.X.Scale, v.X.Offset, v.Y.Scale, v.Y.Offset } }
	elseif dt == "UDim" then
		return { type = "UDim", value = { v.Scale, v.Offset } }
	elseif dt == "EnumItem" then
		return { type = "Enum", value = tostring(v) }
	elseif dt == "BrickColor" then
		return { type = "BrickColor", value = v.Name }
	elseif dt == "NumberSequence" then
		local kps = {}
		for _, kp in ipairs(v.Keypoints) do
			table.insert(kps, { kp.Time, kp.Value, kp.Envelope })
		end
		return { type = "NumberSequence", value = kps }
	elseif dt == "ColorSequence" then
		local kps = {}
		for _, kp in ipairs(v.Keypoints) do
			table.insert(kps, { kp.Time, kp.Value.R, kp.Value.G, kp.Value.B })
		end
		return { type = "ColorSequence", value = kps }
	elseif dt == "NumberRange" then
		return { type = "NumberRange", value = { v.Min, v.Max } }
	elseif dt == "Rect" then
		return { type = "Rect", value = { v.Min.X, v.Min.Y, v.Max.X, v.Max.Y } }
	elseif dt == "Instance" then
		local parts = {}
		local cur: Instance? = v
		while cur and cur ~= game do
			table.insert(parts, 1, cur.Name)
			cur = cur.Parent
		end
		return { type = "Instance", value = table.concat(parts, ".") }
	elseif dt == "boolean" or dt == "number" or dt == "string" then
		return v
	else
		return tostring(v)
	end
end

function ValueSerializer.serializeProperties(instance: Instance): { [string]: any }
	local props: { [string]: any } = {}
	local ok, apiProps = pcall(function()
		return (game :: any):GetService("StudioService"):GetClassProperties(instance.ClassName)
	end)

	if ok and apiProps then
		for _, prop in ipairs(apiProps) do
			local pok, pval = pcall(function()
				return (instance :: any)[prop.Name]
			end)
			if pok then
				props[prop.Name] = ValueSerializer.toJSON(pval)
			end
		end
	else
		-- Fallback: read common properties
		local common = { "Name", "Parent", "Archivable" }
		for _, name in ipairs(common) do
			local pok, pval = pcall(function() return (instance :: any)[name] end)
			if pok then props[name] = ValueSerializer.toJSON(pval) end
		end
	end
	return props
end

return ValueSerializer
