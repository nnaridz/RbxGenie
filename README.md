# RbxGenie

AI Vibe Code tool for Roblox Studio — daemon + plugin architecture.

## Quick Start

### 1. Install & Run Daemon

```powershell
cd "E:\[Tools]\[Roblox_Tools]\RbxGenie"
npm install
npm run dev
```

Daemon starts on `http://127.0.0.1:7766`.

### 2. Build & Install Plugin (single file)

```powershell
# Build the bundled plugin lua file
npm run bundle

# Then copy to Roblox Plugins folder (run as one command):
copy dist\RbxGenie.plugin.lua "%LOCALAPPDATA%\Roblox\Plugins\RbxGenie.lua"
```

Or do both in one step:
```powershell
npm run bundle:install
```

> **Why a bundle?** Roblox cloud-published plugins load all files as `Script` instances,
> which breaks `require()`. The bundler merges everything into one self-contained `.lua` file
> using an `_M[]` module table, which works in any context.

### 3. Open Roblox Studio

- A **RbxGenie** toolbar button appears → click to open the dock widget.
- Status indicator turns **green** once the daemon is reachable.

---

## API Usage

Any HTTP client (AI agent, curl, script) can call tools via:

```
POST http://127.0.0.1:7766/tool/<tool_name>
Content-Type: application/json

{ ...args }
```

Response:
```json
{ "ok": true, "id": "...", "result": { ... } }
```

---

## Available Tools (45)

| Group | Tools |
|-------|-------|
| **Info/Read** | `get_file_tree`, `search_files`, `get_place_info`, `get_services`, `search_objects`, `get_instance_properties`, `get_instance_children`, `search_by_property`, `get_class_info`, `get_project_structure` |
| **Properties** | `set_property`, `mass_set_property`, `mass_get_property`, `set_calculated_property`, `set_relative_property` |
| **Objects** | `create_object`, `create_object_with_properties`, `mass_create_objects`, `mass_create_objects_with_properties`, `delete_object`, `smart_duplicate`, `mass_duplicate` |
| **Scripts** | `get_script_source`, `set_script_source`, `edit_script_lines`, `insert_script_lines`, `delete_script_lines` |
| **Attributes** | `get_attribute`, `set_attribute`, `get_attributes`, `delete_attribute` |
| **Tags** | `get_tags`, `add_tag`, `remove_tag`, `get_tagged` |
| **Selection** | `get_selection` |
| **Execute** | `execute_luau` |
| **Playtest** | `start_playtest`, `stop_playtest`, `get_playtest_output` |

---

## Property Value Types

| Type | JSON |
|------|------|
| `string` | `"hello"` |
| `number` | `42` |
| `boolean` | `true` |
| `Vector3` | `{"type":"Vector3","value":[x,y,z]}` |
| `Vector2` | `{"type":"Vector2","value":[x,y]}` |
| `Color3` | `{"type":"Color3","value":[r,g,b]}` (0–1) |
| `CFrame` | `{"type":"CFrame","value":[12 components]}` |
| `UDim2` | `{"type":"UDim2","value":[xs,xo,ys,yo]}` |
| `UDim` | `{"type":"UDim","value":[scale,offset]}` |
| `Enum` | `{"type":"Enum","value":"Enum.Material.Grass"}` |

---

## Examples

### Create a Part in Workspace
```bash
curl -X POST http://127.0.0.1:7766/tool/create_object_with_properties \
  -H "Content-Type: application/json" \
  -d '{
    "path": "Workspace",
    "className": "Part",
    "properties": {
      "Name": "TestPart",
      "Position": {"type":"Vector3","value":[0,5,0]},
      "BrickColor": {"type":"BrickColor","value":"Bright red"},
      "Anchored": true
    }
  }'
```

### Create a ScreenGui
```bash
curl -X POST http://127.0.0.1:7766/tool/create_object_with_properties \
  -H "Content-Type: application/json" \
  -d '{
    "path": "StarterGui",
    "className": "ScreenGui",
    "properties": { "Name": "MyGui", "ResetOnSpawn": false }
  }'
```

### Read script source
```bash
curl -X POST http://127.0.0.1:7766/tool/get_script_source \
  -H "Content-Type: application/json" \
  -d '{"path": "ServerScriptService.MyScript"}'
```

### Execute Luau in Studio
```bash
curl -X POST http://127.0.0.1:7766/tool/execute_luau \
  -H "Content-Type: application/json" \
  -d '{"code": "return game.PlaceId"}'
```

---

## Architecture

```
AI Agent / curl
   │  POST /tool/:name  {args}
   ▼
Daemon (Node.js :7766)
   ├─ enqueue(id, tool, args) → Promise
   │
   │  ← GET /poll (long-poll, up to 15s)
   ▼
Plugin (Roblox Studio)
   ├─ Executor.dispatch(tool, args)
   └─ POST /result  {id, result}
   │
   ▼
Daemon resolves Promise → returns JSON to caller
```

## File Structure

```
RbxGenie/
├── package.json
├── tsconfig.json
├── src/
│   ├── server.ts        # Express HTTP server
│   ├── bridge.ts        # Command queue + promise bridge
│   └── types.ts         # TypeScript types
└── plugin/
    ├── init.server.lua  # Bootstrap + toolbar + widget
    ├── Bridge.lua       # HTTP long-poll loop
    ├── Executor.lua     # Tool dispatch table
    ├── UI.lua           # Dock widget UI
    ├── PathResolver.lua # "A.B.C" → Instance
    ├── ValueSerializer.lua  # JSON ↔ Roblox types
    └── tools/
        ├── InstanceTools.lua
        ├── PropertyTools.lua
        ├── ObjectTools.lua
        ├── ScriptTools.lua
        ├── AttributeTools.lua
        ├── TagTools.lua
        ├── SelectionTools.lua
        ├── ExecuteTools.lua
        └── PlaytestTools.lua
```
