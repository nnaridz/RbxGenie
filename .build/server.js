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
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const uuid_1 = require("uuid");
const readline = __importStar(require("readline"));
const path = __importStar(require("path"));
const bridge_1 = require("./bridge");
const skills_content_1 = require("./skills-content");
const app = (0, express_1.default)();
app.use(express_1.default.json({ limit: "10mb" }));
app.use((err, _req, res, next) => {
    if (err.type === "entity.parse.failed") {
        res.status(400).json({
            ok: false,
            error: `Invalid JSON body: ${err.message}`,
        });
        return;
    }
    next(err);
});
const PORT = process.env.PORT ? parseInt(process.env.PORT) : 7766;
const LONG_POLL_TIMEOUT_MS = 15000;
app.post("/tool/:name", async (req, res) => {
    const tool = req.params.name;
    const args = req.body ?? {};
    const id = (0, uuid_1.v4)();
    try {
        const result = await (0, bridge_1.enqueue)(id, tool, args);
        res.json({ ok: true, id, result });
    }
    catch (err) {
        const isTimeout = err && typeof err === "object" && err.timeout;
        res.status(500).json({
            ok: false,
            id,
            error: isTimeout ? err.error : String(err),
            timeout: isTimeout ? true : undefined,
            timeoutMs: isTimeout ? err.timeoutMs : undefined,
        });
    }
});
app.get("/poll", (req, res) => {
    const cmd = (0, bridge_1.dequeue)();
    if (cmd) {
        res.json({ hasCommand: true, ...cmd });
        return;
    }
    const deadline = Date.now() + LONG_POLL_TIMEOUT_MS;
    let resolved = false;
    const tryDequeue = () => {
        if (resolved)
            return;
        const cmd = (0, bridge_1.dequeue)();
        if (cmd) {
            resolved = true;
            bridge_1.queueEvents.removeListener("enqueued", tryDequeue);
            res.json({ hasCommand: true, ...cmd });
        }
    };
    bridge_1.queueEvents.on("enqueued", tryDequeue);
    const timer = setTimeout(() => {
        if (!resolved) {
            resolved = true;
            bridge_1.queueEvents.removeListener("enqueued", tryDequeue);
            res.json({ hasCommand: false });
        }
    }, LONG_POLL_TIMEOUT_MS);
    req.on("close", () => {
        resolved = true;
        clearTimeout(timer);
        bridge_1.queueEvents.removeListener("enqueued", tryDequeue);
    });
});
app.post("/result", (req, res) => {
    const { id, result, error } = req.body;
    if (!id) {
        res.status(400).json({ ok: false, error: "Missing id" });
        return;
    }
    if (error) {
        (0, bridge_1.rejectCommand)(id, error);
    }
    else {
        (0, bridge_1.resolveCommand)(id, result);
    }
    res.json({ ok: true });
});
app.get("/health", (_req, res) => {
    res.json({ ok: true, service: "RbxGenie", port: PORT });
});
function startServer() {
    app.listen(PORT, "127.0.0.1", () => {
        console.log(`[RbxGenie] Daemon listening on http://127.0.0.1:${PORT}`);
    });
}
async function createSkillsFile(dir) {
    const dest = path.resolve(dir, "SKILLS.md");
    try {
        await (0, skills_content_1.downloadSkillsContent)(dest);
        console.log(`[RbxGenie] Created: ${dest}`);
    }
    catch (err) {
        console.error(`[RbxGenie] Failed to create SKILLS.md: ${err.message}`);
    }
}
function showMenu() {
    const rl = readline.createInterface({
        input: process.stdin,
        output: process.stdout,
    });
    const print = () => {
        console.log("");
        console.log("=== RbxGenie Daemon ===");
        console.log("");
        console.log("  1) Start Server");
        console.log("  2) Create SKILLS.md");
        console.log("  3) Exit");
        console.log("");
    };
    const prompt = () => {
        print();
        rl.question("Choose: ", (answer) => {
            const choice = answer.trim();
            if (choice === "1") {
                rl.close();
                startServer();
            }
            else if (choice === "2") {
                rl.question("Path (default .): ", (p) => {
                    const dir = p.trim() || ".";
                    createSkillsFile(dir).then(() => prompt());
                });
            }
            else if (choice === "3") {
                rl.close();
                process.exit(0);
            }
            else {
                console.log("[RbxGenie] Invalid choice.");
                prompt();
            }
        });
    };
    prompt();
}
showMenu();
