# RbxGenie

AI Vibe Code tool for Roblox Studio — daemon + plugin architecture with MCP support.

## Quick Start

### 1. Install & Run Daemon

```powershell
cd "E:\[Tools]\[Roblox_Tools]\RbxGenie"
npm install
npm run dev
```

Daemon starts on `http://127.0.0.1:7766`.

### 2. Build & Install Plugin

```powershell
npm run bundle:install
```

### 3. MCP Mode (Claude Desktop / Cursor)

The daemon must be running first (`npm run dev`), then:

```powershell
npm run build
npm run install-mcp
```

This auto-configures Claude Desktop and Cursor to use RbxGenie as an MCP server.

**Manual MCP config:**
```json
{
  "mcpServers": {
    "RbxGenie": {
      "command": "node",
      "args": ["E:/[Tools]/[Roblox_Tools]/RbxGenie/dist/mcp.js"]
    }
  }
}
```

### 4. Open Roblox Studio

- A **RbxGenie** toolbar button appears → click to open the dock widget.
- Status indicator turns **green** once the daemon is reachable.
- All AI changes are **undoable** via Ctrl+Z (ChangeHistoryService).

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

## Available Tools (53)

| Group | Tools |
|-------|-------|
| **Info/Read** | `get_file_tree`, `search_files`, `get_place_info`, `get_services`, `search_objects`, `get_instance_properties`, `get_instance_children`, `search_by_property`, `get_class_info`, `get_project_structure`, `summarize_game` |
| **Properties** | `set_property`, `mass_set_property`, `mass_get_property`, `set_calculated_property`, `set_relative_property` |
| **Objects** | `create_object`, `create_object_with_properties`, `mass_create_objects`, `mass_create_objects_with_properties`, `delete_object`, `smart_duplicate`, `mass_duplicate` |
| **Scripts** | `get_script_source`, `set_script_source`, `edit_script_lines`, `insert_script_lines`, `delete_script_lines` |
| **Attributes** | `get_attribute`, `set_attribute`, `get_attributes`, `delete_attribute` |
| **Tags** | `get_tags`, `add_tag`, `remove_tag`, `get_tagged` |
| **Selection** | `get_selection` |
| **Execute** | `execute_luau`, `get_console_output`, `clear_console_output` |
| **Playtest** | `start_play`, `stop_play`, `run_server`, `get_studio_mode`, `run_script_in_play_mode` |
| **Marketplace** | `insert_model` |

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

## Architecture

```
AI Agent / Claude Desktop / Cursor
   │
   ├─ MCP (stdio) ──→ mcp.ts ──→ REST proxy
   │                                │
   └─ POST /tool/:name ────────────┘
                                    │
                                    ▼
                          Daemon (Node.js :7766)
                             ├─ enqueue(id, tool, args) → Promise
                             │
                             │  ← GET /poll (event-driven, 15s timeout)
                             ▼
                          Plugin (Roblox Studio)
                             ├─ Executor.dispatch(tool, args)
                             ├─ ChangeHistoryService (undo support)
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
│   ├── server.ts        # Express HTTP server (event-driven polling)
│   ├── bridge.ts        # Command queue + EventEmitter bridge
│   ├── mcp.ts           # MCP protocol server (stdio transport)
│   ├── install.ts       # Auto-installer for Claude/Cursor
│   └── types.ts         # TypeScript types
├── scripts/
│   └── bundle.js        # Plugin bundler
└── plugin/
    ├── init.server.lua  # Bootstrap + toolbar + widget
    ├── Bridge.lua       # HTTP long-poll loop + ChangeHistoryService
    ├── Executor.lua     # Tool dispatch table (53 tools)
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
        ├── ExecuteTools.lua      # execute_luau + console capture
        ├── PlaytestTools.lua     # play/stop/run/mode/script-in-play
        └── InsertModelTools.lua  # marketplace model insertion
```
