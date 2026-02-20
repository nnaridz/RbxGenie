import * as fs from "fs";
import * as path from "path";
import * as os from "os";

const PLUGIN_FILENAME = "RbxGenie.lua";

function getClaudeConfigPath(): string | null {
    const appdata = process.env.APPDATA;
    if (!appdata) return null;
    return path.join(appdata, "Claude", "claude_desktop_config.json");
}

function getCursorConfigPath(): string | null {
    const home = os.homedir();
    return path.join(home, ".cursor", "mcp.json");
}

function getPluginSourcePath(): string {
    return path.join(__dirname, "..", "dist", "RbxGenie.plugin.lua");
}

function getPluginDestPath(): string | null {
    const localAppData = process.env.LOCALAPPDATA;
    if (!localAppData) return null;
    return path.join(localAppData, "Roblox", "Plugins", PLUGIN_FILENAME);
}

function getMcpCommand(): { command: string; args: string[] } {
    const mcpScript = path.join(__dirname, "mcp.js");
    return { command: "node", args: [mcpScript] };
}

function injectMcpConfig(configPath: string, label: string): boolean {
    let config: any = {};
    if (fs.existsSync(configPath)) {
        try {
            config = JSON.parse(fs.readFileSync(configPath, "utf-8"));
        } catch {
            console.log(`  [WARN] Could not parse ${label} config, creating new one`);
        }
    }

    if (!config.mcpServers) config.mcpServers = {};

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

function installPlugin(): boolean {
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
        if (injectMcpConfig(claudePath, "Claude Desktop")) installed++;
    } else {
        console.log("Claude Desktop: [SKIP] APPDATA not set");
    }

    // Cursor
    const cursorPath = getCursorConfigPath();
    if (cursorPath) {
        console.log("Cursor:");
        if (injectMcpConfig(cursorPath, "Cursor")) installed++;
    }

    // Plugin
    console.log("\nRoblox Studio Plugin:");
    if (installPlugin()) installed++;

    console.log(`\n✓ Done (${installed} items configured)`);
    if (installed > 0) {
        console.log("  Restart Claude Desktop / Cursor and Roblox Studio to apply changes.\n");
    }
}

main();
