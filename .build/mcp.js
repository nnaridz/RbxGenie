"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const mcp_js_1 = require("@modelcontextprotocol/sdk/server/mcp.js");
const stdio_js_1 = require("@modelcontextprotocol/sdk/server/stdio.js");
const zod_1 = require("zod");
const DAEMON_URL = process.env.DAEMON_URL || "http://127.0.0.1:7766";
const TOOL_TIMEOUT_MS = 120000;
const TOOLS = [
    // Instance / Info
    { name: "get_file_tree", description: "Get the file/instance tree of the place. Args: { root?: string, depth?: number }", schema: { root: zod_1.z.string().optional(), depth: zod_1.z.number().optional() } },
    { name: "search_files", description: "Search for instances by name pattern. Args: { query: string, root?: string }", schema: { query: zod_1.z.string(), root: zod_1.z.string().optional() } },
    { name: "get_place_info", description: "Get current place info (PlaceId, name, etc).", schema: {} },
    { name: "get_services", description: "List all services in the game.", schema: {} },
    { name: "search_objects", description: "Search instances by name or class. Args: { query: string, className?: string, root?: string, maxResults?: number }", schema: { query: zod_1.z.string(), className: zod_1.z.string().optional(), root: zod_1.z.string().optional(), maxResults: zod_1.z.number().optional() } },
    { name: "get_instance_properties", description: "Get properties of an instance. Args: { path: string }", schema: { path: zod_1.z.string() } },
    { name: "get_instance_children", description: "Get children of an instance. Args: { path: string }", schema: { path: zod_1.z.string() } },
    { name: "search_by_property", description: "Search instances by property value. Args: { property: string, value: any, root?: string }", schema: { property: zod_1.z.string(), value: zod_1.z.any(), root: zod_1.z.string().optional() } },
    { name: "get_class_info", description: "Get info about a Roblox class. Args: { className: string }", schema: { className: zod_1.z.string() } },
    { name: "get_project_structure", description: "Get high-level project structure.", schema: {} },
    { name: "summarize_game", description: "Get a summary of the game's structure and contents.", schema: {} },
    // Properties
    { name: "set_property", description: "Set a property on an instance. Args: { path: string, property: string, value: any }", schema: { path: zod_1.z.string(), property: zod_1.z.string(), value: zod_1.z.any() } },
    { name: "mass_set_property", description: "Set a property on multiple instances. Args: { paths: string[], property: string, value: any }", schema: { paths: zod_1.z.array(zod_1.z.string()), property: zod_1.z.string(), value: zod_1.z.any() } },
    { name: "mass_get_property", description: "Get a property from multiple instances. Args: { paths: string[], property: string }", schema: { paths: zod_1.z.array(zod_1.z.string()), property: zod_1.z.string() } },
    { name: "set_calculated_property", description: "Set a property using a calculation expression. Args: { path: string, property: string, expression: string }", schema: { path: zod_1.z.string(), property: zod_1.z.string(), expression: zod_1.z.string() } },
    { name: "set_relative_property", description: "Set a property relative to its current value. Args: { path: string, property: string, delta: any }", schema: { path: zod_1.z.string(), property: zod_1.z.string(), delta: zod_1.z.any() } },
    // Objects
    { name: "create_object", description: "Create a new instance. Args: { path: string, className: string, name?: string }", schema: { path: zod_1.z.string(), className: zod_1.z.string(), name: zod_1.z.string().optional() } },
    { name: "create_object_with_properties", description: "Create an instance with properties. Args: { path: string, className: string, properties: Record<string, any> }", schema: { path: zod_1.z.string(), className: zod_1.z.string(), properties: zod_1.z.record(zod_1.z.any()) } },
    { name: "mass_create_objects", description: "Create multiple instances. Args: { items: Array<{ path: string, className: string, name?: string }> }", schema: { items: zod_1.z.array(zod_1.z.any()) } },
    { name: "mass_create_objects_with_properties", description: "Create multiple instances with properties. Args: { items: Array<{ path, className, properties }> }", schema: { items: zod_1.z.array(zod_1.z.any()) } },
    { name: "delete_object", description: "Delete an instance. Args: { path: string }", schema: { path: zod_1.z.string() } },
    { name: "smart_duplicate", description: "Duplicate an instance intelligently. Args: { path: string, count?: number }", schema: { path: zod_1.z.string(), count: zod_1.z.number().optional() } },
    { name: "mass_duplicate", description: "Duplicate multiple instances. Args: { paths: string[], count?: number }", schema: { paths: zod_1.z.array(zod_1.z.string()), count: zod_1.z.number().optional() } },
    // Scripts
    { name: "get_script_source", description: "Get source code of a script. Args: { path: string }", schema: { path: zod_1.z.string() } },
    { name: "set_script_source", description: "Set source code of a script. Args: { path: string, source: string }", schema: { path: zod_1.z.string(), source: zod_1.z.string() } },
    { name: "edit_script_lines", description: "Edit specific lines in a script. Args: { path: string, startLine: number, endLine: number, newText: string }", schema: { path: zod_1.z.string(), startLine: zod_1.z.number(), endLine: zod_1.z.number(), newText: zod_1.z.string() } },
    { name: "insert_script_lines", description: "Insert lines into a script. Args: { path: string, afterLine: number, text: string }", schema: { path: zod_1.z.string(), afterLine: zod_1.z.number(), text: zod_1.z.string() } },
    { name: "delete_script_lines", description: "Delete lines from a script. Args: { path: string, startLine: number, endLine: number }", schema: { path: zod_1.z.string(), startLine: zod_1.z.number(), endLine: zod_1.z.number() } },
    // Attributes
    { name: "get_attribute", description: "Get an attribute value. Args: { path: string, name: string }", schema: { path: zod_1.z.string(), name: zod_1.z.string() } },
    { name: "set_attribute", description: "Set an attribute value. Args: { path: string, name: string, value: any }", schema: { path: zod_1.z.string(), name: zod_1.z.string(), value: zod_1.z.any() } },
    { name: "get_attributes", description: "Get all attributes of an instance. Args: { path: string }", schema: { path: zod_1.z.string() } },
    { name: "delete_attribute", description: "Delete an attribute. Args: { path: string, name: string }", schema: { path: zod_1.z.string(), name: zod_1.z.string() } },
    // Tags
    { name: "get_tags", description: "Get tags on an instance. Args: { path: string }", schema: { path: zod_1.z.string() } },
    { name: "add_tag", description: "Add a tag to an instance. Args: { path: string, tag: string }", schema: { path: zod_1.z.string(), tag: zod_1.z.string() } },
    { name: "remove_tag", description: "Remove a tag from an instance. Args: { path: string, tag: string }", schema: { path: zod_1.z.string(), tag: zod_1.z.string() } },
    { name: "get_tagged", description: "Get all instances with a tag. Args: { tag: string }", schema: { tag: zod_1.z.string() } },
    // Selection
    { name: "get_selection", description: "Get currently selected instances in Studio.", schema: {} },
    // Execute
    { name: "execute_luau", description: "Execute Luau code in Studio (edit mode). Returns output and result. Args: { code: string }", schema: { code: zod_1.z.string() } },
    { name: "get_console_output", description: "Get captured Studio console output (LogService messages).", schema: {} },
    { name: "clear_console_output", description: "Clear the console output buffer.", schema: {} },
    // Playtest
    { name: "start_play", description: "Start play mode in Studio.", schema: {} },
    { name: "stop_play", description: "Stop play mode in Studio.", schema: {} },
    { name: "run_server", description: "Start server mode in Studio.", schema: {} },
    { name: "get_studio_mode", description: "Get current Studio mode (edit, play, or server).", schema: {} },
    { name: "run_script_in_play_mode", description: "Inject a test script, run in play mode, capture logs/errors/duration, auto-stop. Returns structured result. Args: { code: string, timeout?: number, mode?: string }", schema: { code: zod_1.z.string(), timeout: zod_1.z.number().optional(), mode: zod_1.z.string().optional() } },
    // Marketplace
    { name: "insert_model", description: "Search Roblox marketplace and insert a free model into Workspace. Args: { query: string, parent?: string }", schema: { query: zod_1.z.string(), parent: zod_1.z.string().optional() } },
];
async function callDaemonTool(name, args) {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), TOOL_TIMEOUT_MS);
    try {
        const res = await fetch(`${DAEMON_URL}/tool/${name}`, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify(args),
            signal: controller.signal,
        });
        const data = await res.json();
        if (!data.ok) {
            const msg = data.error || "Unknown error";
            return JSON.stringify({ error: msg, timeout: data.timeout });
        }
        return typeof data.result === "string" ? data.result : JSON.stringify(data.result);
    }
    catch (err) {
        if (err.name === "AbortError") {
            return JSON.stringify({ error: "MCP proxy timeout", timeout: true });
        }
        throw err;
    }
    finally {
        clearTimeout(timer);
    }
}
async function main() {
    const server = new mcp_js_1.McpServer({
        name: "RbxGenie",
        version: "1.0.0",
    });
    for (const def of TOOLS) {
        const shape = def.schema;
        server.tool(def.name, def.description, shape, async (args) => {
            try {
                const result = await callDaemonTool(def.name, args);
                return { content: [{ type: "text", text: result }] };
            }
            catch (err) {
                return {
                    content: [{ type: "text", text: `Error: ${String(err)}` }],
                    isError: true,
                };
            }
        });
    }
    const transport = new stdio_js_1.StdioServerTransport();
    await server.connect(transport);
    console.error("[RbxGenie MCP] Server started on stdio");
}
main().catch((err) => {
    console.error("[RbxGenie MCP] Fatal:", err);
    process.exit(1);
});
