local PathResolver = require(script.Parent.Parent.PathResolver)

local AttributeTools = {}

local function serializeAttr(v: any): any
	local dt = typeof(v)
	if dt == "Vector3" then return { type="Vector3", value={v.X,v.Y,v.Z} }
	elseif dt == "Vector2" then return { type="Vector2", value={v.X,v.Y} }
	elseif dt == "Color3" then return { type="Color3", value={v.R,v.G,v.B} }
	elseif dt == "UDim2" then return { type="UDim2", value={v.X.Scale,v.X.Offset,v.Y.Scale,v.Y.Offset} }
	elseif dt == "UDim" then return { type="UDim", value={v.Scale,v.Offset} }
	elseif dt == "NumberRange" then return { type="NumberRange", value={v.Min,v.Max} }
	elseif dt == "CFrame" then return { type="CFrame", value={
		v.X,v.Y,v.Z,
		v.RightVector.X,v.RightVector.Y,v.RightVector.Z,
		v.UpVector.X,v.UpVector.Y,v.UpVector.Z,
		v.LookVector.X,v.LookVector.Y,v.LookVector.Z,
	}} end
	return v
end

local function deserializeAttr(v: any): any
	if type(v) ~= "table" or not v.type then return v end
	local val = v.value
	if v.type == "Vector3" then return Vector3.new(val[1],val[2],val[3])
	elseif v.type == "Vector2" then return Vector2.new(val[1],val[2])
	elseif v.type == "Color3" then return Color3.new(val[1],val[2],val[3])
	elseif v.type == "UDim2" then return UDim2.new(val[1],val[2],val[3],val[4])
	elseif v.type == "UDim" then return UDim.new(val[1],val[2])
	elseif v.type == "NumberRange" then return NumberRange.new(val[1],val[2])
	elseif v.type == "CFrame" then return CFrame.new(val[1],val[2],val[3],val[4],val[5],val[6],val[7],val[8],val[9],val[10],val[11],val[12])
	end
	return v
end

function AttributeTools.get_attribute(args: { path: string, name: string }): any
	local inst, err = PathResolver.resolve(args.path)
	if not inst then return { error = err } end
	local val = inst:GetAttribute(args.name)
	return { value = serializeAttr(val) }
end

function AttributeTools.set_attribute(args: { path: string, name: string, value: any }): any
	local inst, err = PathResolver.resolve(args.path)
	if not inst then return { error = err } end
	inst:SetAttribute(args.name, deserializeAttr(args.value))
	return { ok = true }
end

function AttributeTools.get_attributes(args: { path: string }): any
	local inst, err = PathResolver.resolve(args.path)
	if not inst then return { error = err } end
	local attrs = inst:GetAttributes()
	local out: { [string]: any } = {}
	for k, v in pairs(attrs) do
		out[k] = serializeAttr(v)
	end
	return { attributes = out }
end

function AttributeTools.delete_attribute(args: { path: string, name: string }): any
	local inst, err = PathResolver.resolve(args.path)
	if not inst then return { error = err } end
	inst:SetAttribute(args.name, nil)
	return { ok = true }
end

return AttributeTools
