---
name: RbxGenie
description: AI Vibe Code tool for Roblox Studio. Send HTTP requests to the daemon (port 7766) to read/modify/execute anything in an open Studio session. The plugin polls for commands and executes them via Luau Studio APIs. YOU MUST read this entire SKILLS.md file before taking any action. Sending any HTTP request without having fully read this file is a critical violation.
---

> [!CAUTION]
> ## ⛔ STOP — MANDATORY READING REQUIRED
>
> **You MUST read this entire file before calling any tool or sending any HTTP request.**
> Skipping or partially reading this file is a **critical protocol violation**.
>
> ### Pre-flight checklist — satisfy ALL before proceeding:
> - [ ] I have read every section of this file from top to bottom
> - [ ] I understand the Base URL, tool call format, and response shape
> - [ ] I understand Property Value Encoding for all Roblox datatypes
> - [ ] I understand Path Notation and all supported root services
> - [ ] I have identified which tools I will use and confirmed their correct argument shapes
>
> **Do NOT make any HTTP request until every checkbox above is checked.**
> Agents that skip this checklist produce incorrect API calls, malformed paths, and broken scripts.

# RbxGenie – AI Usage Guide

## Base URL
```
http://127.0.0.1:7766
```

---

## ⚠️ Token Cost — Read Before Exploring

Some tools return large payloads that can exhaust your token budget in a single call. **You MUST follow these rules:**

### High-cost tools (scope before calling)
| Tool | Risk | Mandatory Rule |
|------|------|---------------|
| `get_file_tree` | Dumps entire instance tree | Always set `"path"` to a specific service, never use `"path": "game"` without `"depth": 1` |
| `get_instance_children` | Dumps all descendants | Only use `"recursive": true` with a narrow `path`; max 200 results |
| `search_files` / `search_objects` | Can match 1000s of nodes | Always supply `"path"` to scope the search; max 50 results |
| `search_by_property` | Full game scan | Always supply `"path"` and `"className"` to narrow scope |

### Default caps (enforced server-side)
- Tree tools: **200 nodes max** — response will include `"truncated": true` when hit
- Search tools: **50 results max** — response will include `"truncated": true` when hit
- You can override with `"limit": N` but only when you have a good reason

### Correct workflow: "Understand this game"
**NEVER** call `get_file_tree` or `get_project_structure` to understand a game. Use this sequence instead:

```jsonc
// Step 1 — low-cost overview (~10 lines of JSON)
POST /tool/summarize_game
{}

// Step 2 — drill into one service if needed
POST /tool/get_file_tree
{ "path": "ServerScriptService", "depth": 2 }

// Step 3 — read a specific script
POST /tool/get_script_source
{ "path": "ServerScriptService.GameManager" }
```

> Calling `get_file_tree` or `get_project_structure` without scoping will consume **10–100× more tokens** than `summarize_game`.

---

## Calling a Tool
```http
POST /tool/<tool_name>
Content-Type: application/json

{ ...args }
```

### Response shape
```json
{ "ok": true, "id": "uuid", "result": { ... } }
{ "ok": false, "id": "uuid", "error": "message" }
```

---

## Property Value Encoding

All property arguments that are Roblox datatypes must be sent as tagged objects:

| Roblox Type | JSON encoding |
|-------------|--------------|
| `string` | `"hello"` |
| `number` | `42` or `3.14` |
| `boolean` | `true` / `false` |
| `Vector3` | `{"type":"Vector3","value":[x,y,z]}` |
| `Vector2` | `{"type":"Vector2","value":[x,y]}` |
| `Color3` | `{"type":"Color3","value":[r,g,b]}` *(0–1 range)* |
| `CFrame` | `{"type":"CFrame","value":[x,y,z, r0,r1,r2, u0,u1,u2, l0,l1,l2]}` |
| `UDim2` | `{"type":"UDim2","value":[xScale,xOffset,yScale,yOffset]}` |
| `UDim` | `{"type":"UDim","value":[scale,offset]}` |
| `Enum` | `{"type":"Enum","value":"Enum.Material.Grass"}` |
| `BrickColor` | `{"type":"BrickColor","value":"Bright red"}` |
| `NumberRange` | `{"type":"NumberRange","value":[min,max]}` |

---

## Path Notation

Instances are addressed by **dot-separated names** starting from a service:

```
"Workspace"
"Workspace.BasePlate"
"StarterGui.MyGui.Frame.Button"
"ServerScriptService.GameManager"
"ReplicatedStorage.Modules.Utils"
```

Supported roots: `Workspace`, `Players`, `Lighting`, `ReplicatedStorage`, `ReplicatedFirst`, `ServerScriptService`, `ServerStorage`, `StarterGui`, `StarterPack`, `StarterPlayer`, `Teams`, `SoundService`, `TextChatService`, `CollectionService`, `Chat`, `LocalizationService`.

---

## Tools Reference

### 🔍 Info / Read

#### `summarize_game` ✅ Token-safe — use this first
Get a high-level overview of the game: service names, child counts, script counts. **Use this instead of `get_file_tree` when you want to understand what a game is about.**
```json
{}
```
Returns:
```json
{
  "placeName": "My Game",
  "placeId": 123,
  "services": [
    { "name": "ServerScriptService", "className": "ServerScriptService", "directChildren": 4, "totalDescendants": 12, "scripts": 8 }
  ],
  "totalScripts": 11,
  "totalInstances": 247,
  "tip": "Use get_file_tree with a specific path and low depth to explore further."
}
```

---

#### `get_file_tree`
Get the instance tree starting from a path. **Always provide a scoped `path`.** Capped at 200 nodes; `"truncated": true` means results were cut off.
```json
{ "path": "StarterGui", "depth": 2 }
```
- `path` *(optional)* – root to start from (default: `game`)
- `depth` *(optional)* – max recursion depth (default: 3)

---

#### `search_files`
Search instances by name substring.
```json
{ "query": "Button", "path": "StarterGui" }
```

---

#### `get_place_info`
Returns `placeId`, `gameId`, `placeName`, `placeVersion`, `creatorId`.
```json
{}
```

---

#### `get_services`
List all top-level game services with child counts.
```json
{}
```

---

#### `search_objects`
Search instances by name and/or className.
```json
{ "query": "Enemy", "className": "Model", "path": "Workspace" }
```

---

#### `get_instance_properties`
Get common properties of a specific instance.
```json
{ "path": "Workspace.Part" }
```

---

#### `get_instance_children`
List direct children (or all descendants with `recursive: true`).
```json
{ "path": "StarterGui.MyGui", "recursive": false }
```

---

#### `search_by_property`
Find instances where a property equals a value.
```json
{ "property": "Anchored", "value": true, "path": "Workspace", "className": "Part" }
```

---

#### `get_class_info`
Get property metadata for a class name.
```json
{ "className": "Part" }
```

---

#### `get_project_structure`
Get the top-level game tree (convenience wrapper for `get_file_tree`).
```json
{ "depth": 2 }
```

---

### ⚙️ Properties

#### `set_property`
Set a property on an instance.
```json
{ "path": "Workspace.Part", "property": "Anchored", "value": true }
{ "path": "Workspace.Part", "property": "Color", "value": {"type":"Color3","value":[1,0,0]} }
```

---

#### `mass_set_property`
Set the same property on multiple instances.
```json
{ "paths": ["Workspace.A", "Workspace.B"], "property": "Transparency", "value": 0.5 }
```

---

#### `mass_get_property`
Get a property from multiple instances.
```json
{ "paths": ["Workspace.A", "Workspace.B"], "property": "Position" }
```

---

#### `set_calculated_property`
Set a property using a Lua expression. `current` holds the current value.
```json
{ "path": "Workspace.Part", "property": "Size", "expression": "current * 2" }
```

---

#### `set_relative_property`
Add a delta to a numeric/Vector3/UDim2 property.
```json
{
  "path": "Workspace.Part",
  "property": "Position",
  "delta": {"type":"Vector3","value":[0,5,0]}
}
```

---

### 🧱 Objects

#### `create_object`
Create an instance under a parent path.
```json
{ "path": "Workspace", "className": "Part" }
```

---

#### `create_object_with_properties`
Create an instance with properties, attributes, and optional script source.
```json
{
  "path": "StarterGui",
  "className": "ScreenGui",
  "properties": { "Name": "MyGui", "ResetOnSpawn": false },
  "attributes": { "Version": 1 },
  "source": null
}
```

---

#### `mass_create_objects`
Create multiple instances in one call.
```json
{
  "items": [
    { "path": "Workspace", "className": "Part" },
    { "path": "Workspace", "className": "SpawnLocation" }
  ]
}
```

---

#### `mass_create_objects_with_properties`
Create multiple instances with full property/attribute/source detail.
```json
{
  "items": [
    {
      "path": "StarterGui.MyGui",
      "className": "Frame",
      "properties": {
        "Name": "MainFrame",
        "Size": {"type":"UDim2","value":[0,400,0,300]},
        "BackgroundColor3": {"type":"Color3","value":[0.1,0.1,0.1]}
      }
    }
  ]
}
```

---

#### `delete_object`
Delete an instance. `force` is required for non-AI-created instances (both work currently).
```json
{ "path": "Workspace.OldPart", "force": true }
```

---

#### `smart_duplicate`
Clone an instance with optional offset, rename, parent, and property overrides.
```json
{
  "path": "Workspace.Part",
  "newParent": "Workspace",
  "newName": "PartCopy",
  "offset": [10, 0, 0],
  "properties": { "BrickColor": {"type":"BrickColor","value":"Bright blue"} }
}
```

---

#### `mass_duplicate`
Duplicate multiple instances.
```json
{
  "paths": ["Workspace.A", "Workspace.B"],
  "newParent": "Workspace",
  "offset": [0, 0, 10]
}
```

---

### 📝 Scripts

#### `get_script_source`
Read the Luau source of a script.
```json
{ "path": "ServerScriptService.MyScript" }
```
Returns: `{ source: "...", lineCount: 42 }`

---

#### `set_script_source`
Overwrite the full source of a script.
```json
{ "path": "ServerScriptService.MyScript", "source": "print('hello')" }
```

---

#### `edit_script_lines`
Replace a line range with new content.
```json
{ "path": "ServerScriptService.MyScript", "startLine": 5, "endLine": 8, "replacement": "-- replaced\nprint('new')" }
```

---

#### `insert_script_lines`
Insert lines after a specific line number.
```json
{ "path": "ServerScriptService.MyScript", "afterLine": 10, "lines": "local x = 1\nprint(x)" }
```

---

#### `delete_script_lines`
Delete a range of lines.
```json
{ "path": "ServerScriptService.MyScript", "startLine": 3, "endLine": 5 }
```

---

### 🏷️ Attributes

#### `get_attribute`
```json
{ "path": "Workspace.Part", "name": "Health" }
```

#### `set_attribute`
```json
{ "path": "Workspace.Part", "name": "Health", "value": 100 }
```

#### `get_attributes`
Get all attributes on an instance.
```json
{ "path": "Workspace.Part" }
```

#### `delete_attribute`
```json
{ "path": "Workspace.Part", "name": "OldAttr" }
```

---

### 🔖 Tags (CollectionService)

#### `get_tags`
```json
{ "path": "Workspace.Part" }
```

#### `add_tag`
```json
{ "path": "Workspace.Part", "tag": "Enemy" }
```

#### `remove_tag`
```json
{ "path": "Workspace.Part", "tag": "Enemy" }
```

#### `get_tagged`
Get all instances with a given tag.
```json
{ "tag": "Enemy" }
```
Returns: `{ instances: [{ path, className }] }`

---

### 🖱️ Selection

#### `get_selection`
Get current Studio selection.
```json
{}
```
Returns: `{ selection: [{ path, className, name }], count: N }`

---

### ⚡ Execute

#### `execute_luau`
Execute arbitrary Lua code in Studio context. Return value is serialized.
```json
{ "code": "return game.PlaceId" }
{ "code": "workspace.Part.Transparency = 0.5" }
{ "code": "local p = Instance.new('Part'); p.Parent = workspace; return p.Name" }
```

---


## Common Workflows

### Create a GUI from scratch
```jsonc
// 1. Create ScreenGui
POST /tool/create_object_with_properties
{ "path": "StarterGui", "className": "ScreenGui", "properties": { "Name": "HUD" } }

// 2. Create Frame
POST /tool/create_object_with_properties
{
  "path": "StarterGui.HUD",
  "className": "Frame",
  "properties": {
    "Name": "Container",
    "Size": {"type":"UDim2","value":[1,0,1,0]},
    "BackgroundTransparency": 1
  }
}

// 3. Create TextLabel
POST /tool/create_object_with_properties
{
  "path": "StarterGui.HUD.Container",
  "className": "TextLabel",
  "properties": {
    "Name": "Title",
    "Text": "Hello World",
    "Size": {"type":"UDim2","value":[0,200,0,50]},
    "Position": {"type":"UDim2","value":[0.5,-100,0,20]},
    "TextColor3": {"type":"Color3","value":[1,1,1]},
    "BackgroundTransparency": 1
  }
}
```

### Batch-color all parts in Workspace
```json
POST /tool/search_objects
{ "className": "Part", "path": "Workspace" }

// → get list of paths, then:
POST /tool/mass_set_property
{ "paths": ["Workspace.A","Workspace.B",...], "property": "BrickColor", "value": {"type":"BrickColor","value":"Bright red"} }
```

### Modify a script
```json
POST /tool/get_script_source
{ "path": "ServerScriptService.GameScript" }

POST /tool/edit_script_lines
{ "path": "ServerScriptService.GameScript", "startLine": 1, "endLine": 1, "replacement": "-- Updated by AI" }
```
