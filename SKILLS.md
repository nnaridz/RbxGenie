---
name: RbxGenie
description: AI tool for Roblox Studio. HTTP requests to daemon (port 7766) to read/modify/execute in an open Studio session. MANDATORY — read this entire file before any action. No HTTP requests until fully read.
---

> [!CAUTION]
> **MANDATORY: Read this ENTIRE file before calling any tool.**
> Verify you understand: Base URL, tool format, Property Encoding, Path Notation, and argument shapes.

## Base URL
```
http://127.0.0.1:7766
```

## Tool Call Format
```http
POST /tool/<tool_name>
Content-Type: application/json
{ ...args }
```
**Response:** `{ "ok": true, "id": "uuid", "result": { ... } }` or `{ "ok": false, "id": "uuid", "error": "message" }`

## Token Cost Rules

**ALWAYS call `summarize_game` first** to understand a game. NEVER call `get_file_tree` or `get_project_structure` without a scoped `path`.

| Tool | Rule |
|------|------|
| `get_file_tree` | Always set `"path"` to a specific service; never `"path": "game"` without `"depth": 1` |
| `get_instance_children` | Only `"recursive": true` with narrow `path`; max 200 |
| `search_files` / `search_objects` | Always supply `"path"`; max 50 |
| `search_by_property` | Always supply `"path"` and `"className"` |

## Property Value Encoding

All Roblox datatypes use tagged objects:

| Type | JSON |
|------|------|
| `string` | `"hello"` |
| `number` | `42` |
| `boolean` | `true` / `false` |
| `Vector3` | `{"type":"Vector3","value":[x,y,z]}` |
| `Vector2` | `{"type":"Vector2","value":[x,y]}` |
| `Color3` | `{"type":"Color3","value":[r,g,b]}` *(0–1)* |
| `CFrame` | `{"type":"CFrame","value":[x,y,z,r0,r1,r2,u0,u1,u2,l0,l1,l2]}` |
| `UDim2` | `{"type":"UDim2","value":[xScale,xOffset,yScale,yOffset]}` |
| `UDim` | `{"type":"UDim","value":[scale,offset]}` |
| `Enum` | `{"type":"Enum","value":"Enum.Material.Grass"}` |
| `BrickColor` | `{"type":"BrickColor","value":"Bright red"}` |
| `NumberRange` | `{"type":"NumberRange","value":[min,max]}` |

## Path Notation

Dot-separated names from service root:
```
"Workspace.BasePlate"
"ServerScriptService.GameManager"
"StarterGui.MyGui.Frame.Button"
```
Supported roots: `Workspace`, `Players`, `Lighting`, `ReplicatedStorage`, `ReplicatedFirst`, `ServerScriptService`, `ServerStorage`, `StarterGui`, `StarterPack`, `StarterPlayer`, `Teams`, `SoundService`, `TextChatService`, `CollectionService`, `Chat`, `LocalizationService`.

## Tools Reference

### Info / Read

**`summarize_game`** — Use this FIRST. Returns service overview with child/script counts.
```json
{}
```

**`get_file_tree`** — Instance tree from path. Always scope with `path`.
```json
{ "path": "StarterGui", "depth": 2 }
```

**`search_files`** — Search by name substring.
```json
{ "query": "Button", "path": "StarterGui" }
```

**`get_place_info`** — Returns placeId, gameId, placeName, placeVersion, creatorId.
```json
{}
```

**`get_services`** — List top-level services with child counts.
```json
{}
```

**`search_objects`** — Search by name and/or className.
```json
{ "query": "Enemy", "className": "Model", "path": "Workspace" }
```

**`get_instance_properties`** — Common properties of an instance.
```json
{ "path": "Workspace.Part" }
```

**`get_instance_children`** — Direct children or all descendants.
```json
{ "path": "StarterGui.MyGui", "recursive": false }
```

**`search_by_property`** — Find instances where property equals value.
```json
{ "property": "Anchored", "value": true, "path": "Workspace", "className": "Part" }
```

**`get_class_info`** — Property metadata for a class.
```json
{ "className": "Part" }
```

**`get_project_structure`** — Top-level game tree (wrapper for get_file_tree).
```json
{ "depth": 2 }
```

### Properties

**`set_property`**
```json
{ "path": "Workspace.Part", "property": "Anchored", "value": true }
```

**`mass_set_property`** — Same property on multiple instances.
```json
{ "paths": ["Workspace.A", "Workspace.B"], "property": "Transparency", "value": 0.5 }
```

**`mass_get_property`** — Get property from multiple instances.
```json
{ "paths": ["Workspace.A", "Workspace.B"], "property": "Position" }
```

**`set_calculated_property`** — Set via Lua expression. `current` = current value.
```json
{ "path": "Workspace.Part", "property": "Size", "expression": "current * 2" }
```

**`set_relative_property`** — Add delta to numeric/Vector3/UDim2 property.
```json
{ "path": "Workspace.Part", "property": "Position", "delta": {"type":"Vector3","value":[0,5,0]} }
```

### Objects

**`create_object`**
```json
{ "path": "Workspace", "className": "Part" }
```

**`create_object_with_properties`** — With properties, attributes, optional source.
```json
{ "path": "StarterGui", "className": "ScreenGui", "properties": { "Name": "MyGui", "ResetOnSpawn": false }, "attributes": { "Version": 1 } }
```

**`mass_create_objects`**
```json
{ "items": [{ "path": "Workspace", "className": "Part" }, { "path": "Workspace", "className": "SpawnLocation" }] }
```

**`mass_create_objects_with_properties`**
```json
{ "items": [{ "path": "StarterGui.MyGui", "className": "Frame", "properties": { "Name": "MainFrame", "Size": {"type":"UDim2","value":[0,400,0,300]} } }] }
```

**`delete_object`** — Use `"force": true` for non-AI-created instances.
```json
{ "path": "Workspace.OldPart", "force": true }
```

**`smart_duplicate`** — Clone with offset, rename, parent, property overrides.
```json
{ "path": "Workspace.Part", "newParent": "Workspace", "newName": "PartCopy", "offset": [10,0,0] }
```

**`mass_duplicate`**
```json
{ "paths": ["Workspace.A", "Workspace.B"], "newParent": "Workspace", "offset": [0,0,10] }
```

### Scripts

**`get_script_source`** — Returns `{ source, lineCount }`.
```json
{ "path": "ServerScriptService.MyScript" }
```

**`set_script_source`** — Overwrite full source.
```json
{ "path": "ServerScriptService.MyScript", "source": "print('hello')" }
```

**`edit_script_lines`** — Replace line range.
```json
{ "path": "ServerScriptService.MyScript", "startLine": 5, "endLine": 8, "replacement": "-- replaced\nprint('new')" }
```

**`insert_script_lines`** — Insert after line number.
```json
{ "path": "ServerScriptService.MyScript", "afterLine": 10, "lines": "local x = 1\nprint(x)" }
```

**`delete_script_lines`**
```json
{ "path": "ServerScriptService.MyScript", "startLine": 3, "endLine": 5 }
```

### Attributes

**`get_attribute`** `{ "path": "Workspace.Part", "name": "Health" }`

**`set_attribute`** `{ "path": "Workspace.Part", "name": "Health", "value": 100 }`

**`get_attributes`** `{ "path": "Workspace.Part" }`

**`delete_attribute`** `{ "path": "Workspace.Part", "name": "OldAttr" }`

### Tags (CollectionService)

**`get_tags`** `{ "path": "Workspace.Part" }`

**`add_tag`** `{ "path": "Workspace.Part", "tag": "Enemy" }`

**`remove_tag`** `{ "path": "Workspace.Part", "tag": "Enemy" }`

**`get_tagged`** — All instances with tag. Returns `{ instances: [{ path, className }] }`.
```json
{ "tag": "Enemy" }
```

### Selection

**`get_selection`** — Current Studio selection. Returns `{ selection: [{ path, className, name }], count }`.
```json
{}
```

### Execute

**`execute_luau`** — Run arbitrary Lua in Studio. Return value is serialized.
```json
{ "code": "return game.PlaceId" }
```
