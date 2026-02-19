local InstanceTools  = require(script.Parent.tools.InstanceTools)
local PropertyTools  = require(script.Parent.tools.PropertyTools)
local ObjectTools    = require(script.Parent.tools.ObjectTools)
local ScriptTools    = require(script.Parent.tools.ScriptTools)
local AttributeTools = require(script.Parent.tools.AttributeTools)
local TagTools       = require(script.Parent.tools.TagTools)
local SelectionTools = require(script.Parent.tools.SelectionTools)
local ExecuteTools   = require(script.Parent.tools.ExecuteTools)

local Executor = {}

local DISPATCH: { [string]: (args: any) -> any } = {
	-- Instance / Info
	get_file_tree               = InstanceTools.get_file_tree,
	search_files                = InstanceTools.search_files,
	get_place_info              = InstanceTools.get_place_info,
	get_services                = InstanceTools.get_services,
	search_objects              = InstanceTools.search_objects,
	get_instance_properties     = InstanceTools.get_instance_properties,
	get_instance_children       = InstanceTools.get_instance_children,
	search_by_property          = InstanceTools.search_by_property,
	get_class_info              = InstanceTools.get_class_info,
	get_project_structure       = InstanceTools.get_project_structure,

	-- Properties
	set_property                = PropertyTools.set_property,
	mass_set_property           = PropertyTools.mass_set_property,
	mass_get_property           = PropertyTools.mass_get_property,
	set_calculated_property     = PropertyTools.set_calculated_property,
	set_relative_property       = PropertyTools.set_relative_property,

	-- Objects
	create_object               = ObjectTools.create_object,
	create_object_with_properties = ObjectTools.create_object_with_properties,
	mass_create_objects         = ObjectTools.mass_create_objects,
	mass_create_objects_with_properties = ObjectTools.mass_create_objects_with_properties,
	delete_object               = ObjectTools.delete_object,
	smart_duplicate             = ObjectTools.smart_duplicate,
	mass_duplicate              = ObjectTools.mass_duplicate,

	-- Scripts
	get_script_source           = ScriptTools.get_script_source,
	set_script_source           = ScriptTools.set_script_source,
	edit_script_lines           = ScriptTools.edit_script_lines,
	insert_script_lines         = ScriptTools.insert_script_lines,
	delete_script_lines         = ScriptTools.delete_script_lines,

	-- Attributes
	get_attribute               = AttributeTools.get_attribute,
	set_attribute               = AttributeTools.set_attribute,
	get_attributes              = AttributeTools.get_attributes,
	delete_attribute            = AttributeTools.delete_attribute,

	-- Tags
	get_tags                    = TagTools.get_tags,
	add_tag                     = TagTools.add_tag,
	remove_tag                  = TagTools.remove_tag,
	get_tagged                  = TagTools.get_tagged,

	-- Selection
	get_selection               = SelectionTools.get_selection,

	-- Execute
	execute_luau                = ExecuteTools.execute_luau,
}

function Executor.dispatch(tool: string, args: any): (any, string?)
	local handler = DISPATCH[tool]
	if not handler then
		return nil, "Unknown tool: " .. tostring(tool)
	end
	local ok, result = pcall(handler, args)
	if not ok then
		return nil, "Tool error [" .. tool .. "]: " .. tostring(result)
	end
	return result, nil
end

return Executor
