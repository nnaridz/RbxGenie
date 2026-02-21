"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
const fs = __importStar(require("fs"));
const path = __importStar(require("path"));
const os = __importStar(require("os"));
const PLUGIN_FILENAME = "RbxGenie.lua";
function getClaudeConfigPath() {
    const appdata = process.env.APPDATA;
    if (!appdata)
        return null;
    return path.join(appdata, "Claude", "claude_desktop_config.json");
}
function getCursorConfigPath() {
    const home = os.homedir();
    return path.join(home, ".cursor", "mcp.json");
}
function getPluginSourcePath() {
    return path.join(__dirname, "..", "dist", "RbxGenie.plugin.lua");
}
function getPluginDestPath() {
    const localAppData = process.env.LOCALAPPDATA;
    if (!localAppData)
        return null;
    return path.join(localAppData, "Roblox", "Plugins", PLUGIN_FILENAME);
}
function getMcpCommand() {
    const mcpScript = path.join(__dirname, "mcp.js");
    return { command: "node", args: [mcpScript] };
}
function injectMcpConfig(configPath, label) {
    let config = {};
    if (fs.existsSync(configPath)) {
        try {
            config = JSON.parse(fs.readFileSync(configPath, "utf-8"));
        }
        catch {
            console.log(`  [WARN] Could not parse ${label} config, creating new one`);
        }
    }
    if (!config.mcpServers)
        config.mcpServers = {};
    const mcp = getMcpCommand();
    config.mcpServers["RbxGenie"] = {
        command: mcp.command,
        args: mcp.args,
    };
    const dir = path.dirname(configPath);
    if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir, { recursive: true });
    }
    fs.writeFileSync(configPath, JSON.stringify(config, null, 2), "utf-8");
    console.log(`  ✓ ${label} config updated: ${configPath}`);
    return true;
}
function installPlugin() {
    const src = getPluginSourcePath();
    if (!fs.existsSync(src)) {
        console.log(`  [SKIP] Plugin bundle not found. Run 'npm run bundle' first.`);
        return false;
    }
    const dest = getPluginDestPath();
    if (!dest) {
        console.log(`  [SKIP] LOCALAPPDATA not set — cannot install plugin`);
        return false;
    }
    const dir = path.dirname(dest);
    if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir, { recursive: true });
    }
    fs.copyFileSync(src, dest);
    console.log(`  ✓ Plugin installed: ${dest}`);
    return true;
}
function main() {
    console.log("\n[RbxGenie Installer]\n");
    let installed = 0;
    // Claude Desktop
    const claudePath = getClaudeConfigPath();
    if (claudePath) {
        console.log("Claude Desktop:");
        if (injectMcpConfig(claudePath, "Claude Desktop"))
            installed++;
    }
    else {
        console.log("Claude Desktop: [SKIP] APPDATA not set");
    }
    // Cursor
    const cursorPath = getCursorConfigPath();
    if (cursorPath) {
        console.log("Cursor:");
        if (injectMcpConfig(cursorPath, "Cursor"))
            installed++;
    }
    // Plugin
    console.log("\nRoblox Studio Plugin:");
    if (installPlugin())
        installed++;
    console.log(`\n✓ Done (${installed} items configured)`);
    if (installed > 0) {
        console.log("  Restart Claude Desktop / Cursor and Roblox Studio to apply changes.\n");
    }
}
main();
