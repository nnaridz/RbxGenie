import express from "express";
import { v4 as uuidv4 } from "uuid";
import * as readline from "readline";
import * as path from "path";
import { enqueue, dequeue, resolveCommand, rejectCommand, queueEvents } from "./bridge";
import { downloadSkillsContent } from "./skills-content";

const app = express();
app.use(express.json({ limit: "10mb" }));

app.use((err: any, _req: express.Request, res: express.Response, next: express.NextFunction) => {
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
const LONG_POLL_TIMEOUT_MS = 15_000;

app.post("/tool/:name", async (req, res) => {
    const tool = req.params.name;
    const args = req.body ?? {};
    const id = uuidv4();

    try {
        const result = await enqueue(id, tool, args);
        res.json({ ok: true, id, result });
    } catch (err: any) {
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
    const cmd = dequeue();
    if (cmd) {
        res.json({ hasCommand: true, ...cmd });
        return;
    }

    const deadline = Date.now() + LONG_POLL_TIMEOUT_MS;
    let resolved = false;

    const tryDequeue = () => {
        if (resolved) return;
        const cmd = dequeue();
        if (cmd) {
            resolved = true;
            queueEvents.removeListener("enqueued", tryDequeue);
            res.json({ hasCommand: true, ...cmd });
        }
    };

    queueEvents.on("enqueued", tryDequeue);

    const timer = setTimeout(() => {
        if (!resolved) {
            resolved = true;
            queueEvents.removeListener("enqueued", tryDequeue);
            res.json({ hasCommand: false });
        }
    }, LONG_POLL_TIMEOUT_MS);

    req.on("close", () => {
        resolved = true;
        clearTimeout(timer);
        queueEvents.removeListener("enqueued", tryDequeue);
    });
});

app.post("/result", (req, res) => {
    const { id, result, error } = req.body as {
        id: string;
        result?: unknown;
        error?: string;
    };

    if (!id) {
        res.status(400).json({ ok: false, error: "Missing id" });
        return;
    }

    if (error) {
        rejectCommand(id, error);
    } else {
        resolveCommand(id, result);
    }

    res.json({ ok: true });
});

app.get("/health", (_req, res) => {
    res.json({ ok: true, service: "RbxGenie", port: PORT });
});

function startServer(): void {
    app.listen(PORT, "127.0.0.1", () => {
        console.log(`[RbxGenie] Daemon listening on http://127.0.0.1:${PORT}`);
    });
}

async function createSkillsFile(dir: string): Promise<void> {
    const dest = path.resolve(dir, "SKILLS.md");
    try {
        await downloadSkillsContent(dest);
        console.log(`[RbxGenie] Created: ${dest}`);
    } catch (err: any) {
        console.error(`[RbxGenie] Failed to create SKILLS.md: ${err.message}`);
    }
}

function showMenu(): void {
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
            } else if (choice === "2") {
                rl.question("Path (default .): ", (p) => {
                    const dir = p.trim() || ".";
                    createSkillsFile(dir).then(() => prompt());
                });
            } else if (choice === "3") {
                rl.close();
                process.exit(0);
            } else {
                console.log("[RbxGenie] Invalid choice.");
                prompt();
            }
        });
    };

    prompt();
}

showMenu();
